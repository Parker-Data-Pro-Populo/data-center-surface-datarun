#!/usr/bin/env Rscript
# rco_viz_siting_risk.R — siting-risk surface: where is a data center most
# likely to land next? This is the DEVELOPER-attractiveness surface, distinct
# from the resource-competition surface (which measures IMPACT given a facility).
#
# siting_risk = 0.35*land + 0.35*permissive + 0.30*infra
# Each component in [0,1]. Final index also normalized to [0,1].

suppressPackageStartupMessages({
  library(data.table); library(sf); library(tigris); library(RColorBrewer)
})
options(tigris_use_cache = TRUE)

OUT  <- "~/rco_overlay/output"
VOUT <- "~/rco_overlay/viz"

nat   <- fread(file.path(OUT, "rco_surface_national.csv"),
               colClasses=list(character="fips"))
chr   <- fread(file.path(OUT, "rco_chr.csv"),
               colClasses=list(character="fips"))
nass  <- fread(file.path(OUT, "rco_nass.csv"),
               colClasses=list(character="fips"))
gcd   <- fread("~/rco_run/RCO_03_gcd_pgma_coding.csv",
               colClasses=list(character="fips"))
sites <- fread(file.path(OUT, "datacenter_sites_manual.csv"),
               colClasses=list(character="county_fips"))

# Counties + reproject
cnty <- counties(cb=TRUE, resolution="20m", year=2023, progress_bar=FALSE)
cnty <- st_transform(cnty, 3081)   # Texas Centric Lambert
cnty$fips <- paste0(cnty$STATEFP, cnty$COUNTYFP)
tx <- cnty[cnty$STATEFP == "48", ]

# ── Build the county-level data frame for the index ────────────────────────
d <- as.data.table(st_drop_geometry(tx))[, .(fips, name=NAME)]

# CHR rural_raw_value
d <- merge(d, chr[, .(fips, rural_raw_value)], by="fips", all.x=TRUE)

# NASS cropland share
d <- merge(d, nass[, .(fips, cropland_share_of_land)], by="fips", all.x=TRUE)

# GCD codings
d <- merge(d, gcd[, .(fips, gcd_funding, pgma)], by="fips", all.x=TRUE)
d[, gcd_funding := fifelse(is.na(gcd_funding), 0L, as.integer(gcd_funding))]
d[, pgma        := fifelse(is.na(pgma),        0L, as.integer(pgma))]

# Moratorium status (currently: Hill confirmed; others unknown)
moratorium_fips <- c("48217")            # Hill
d[, moratorium := fifelse(fips %in% moratorium_fips, 1L, 0L)]

# Distance to nearest county that already hosts an operating facility
lit_fips <- unique(sites[!is.na(county_fips) & county_fips != "", county_fips])
tx_lit   <- tx[tx$fips %in% lit_fips, ]
tx_cent  <- suppressWarnings(st_centroid(tx))
lit_cent <- suppressWarnings(st_centroid(tx_lit))

# Distance matrix in metres → minimum to any lit centroid
dist_mat <- st_distance(tx_cent, lit_cent)
d_min_km <- apply(dist_mat, 1, min) / 1000           # to km
d_min <- data.table(fips = tx$fips, dist_km = d_min_km)
d <- merge(d, d_min, by="fips", all.x=TRUE)

# ── Compute the three score components ─────────────────────────────────────
d[, rural_raw_value := fifelse(is.na(rural_raw_value), 0, rural_raw_value)]
d[, cropland_share_of_land := fifelse(is.na(cropland_share_of_land), 0,
                                       cropland_share_of_land)]

# Land availability — high rural, but not high cropland (subdivision penalty)
d[, land_score := rural_raw_value * (1 - 0.5*cropland_share_of_land)]
d[, land_score := pmin(1, pmax(0, land_score))]

# Permissive — uncovered + no PGMA + no moratorium
d[, permissive_score := (1 - 0.5*gcd_funding) *
                        (1 - 0.5*pgma) *
                        (1 - 0.5*moratorium)]
d[, permissive_score := pmin(1, pmax(0, permissive_score))]

# Infrastructure — exponential proximity decay (100 km characteristic length).
# Operating counties themselves get the maximum (already proven attractive).
d[, infra_score := exp(-dist_km / 100)]
d[, infra_score := pmin(1, pmax(0, infra_score))]

# ── Composite siting-risk index ────────────────────────────────────────────
d[, siting_risk := 0.35*land_score + 0.35*permissive_score + 0.30*infra_score]
# Normalize to [0,1]
d[, siting_risk := (siting_risk - min(siting_risk, na.rm=TRUE)) /
                   (max(siting_risk, na.rm=TRUE) - min(siting_risk, na.rm=TRUE))]

# Annotate: already lit, peer set membership
d[, is_lit := fips %in% lit_fips]
d[, is_peer := fips %in% c("48367","48209","48221","48217")]

fwrite(d, file.path(OUT, "rco_siting_risk.csv"))

# ── Render the map ─────────────────────────────────────────────────────────
m <- merge(tx, d, by="fips", all.x=TRUE)

# Palette: white→yellow→orange→red→dark red, mapping low-to-high risk
pal_risk <- colorRampPalette(c("#f9f7f4","#fee391","#fec44f","#fe9929",
                                "#ec7014","#cc4c02","#8c2d04"))(100)
risk_to_color <- function(v) {
  i <- as.integer(pmin(99, pmax(0, floor(v*99)))+1)
  i[is.na(v)] <- NA
  pal_risk[i]
}
m$col_risk <- risk_to_color(m$siting_risk)
m$col_risk[is.na(m$col_risk)] <- "#eeeeee"

# Top-15 highest-risk NOT-YET-LIT counties for callout
top_unlit <- d[is_lit == FALSE][order(-siting_risk)][1:15]
top_label <- data.table(fips = top_unlit$fips, short = top_unlit$name)
peer_label <- data.table(
  fips  = c("48367","48209","48221","48217"),
  short = c("Parker","Hays","Hood","Hill")
)

peer_col <- "#c0282d"
draw_lbl <- function(set, m, cex=0.95, col="#222222", font=1) {
  for (i in seq_len(nrow(set))) {
    p <- m[m$fips == set$fips[i], ]
    if (!nrow(p)) next
    ct <- suppressWarnings(st_centroid(st_geometry(p)))
    xy <- st_coordinates(ct)
    text(xy[1], xy[2], set$short[i], cex=cex, col=col, font=font)
  }
}

png(file.path(VOUT, "F_tx_siting_risk.png"),
    width=1700, height=1500, res=170)
par(mar=c(6,1,5,1), family="sans")    # extra room for header (2-line) + footer (3-line)
plot(st_geometry(m), col=m$col_risk, border="#c8c8c8", lwd=0.25,
     main="Where data centers are most likely to land next",
     cex.main=1.3, line=3)
mtext("Siting-risk index = land availability × regulatory permissiveness × infrastructure proximity.",
      side=3, line=1.5, cex=0.9, col="#444444")
mtext("Of TX's 254 counties, the four peer counties rank among the least attractive — GCDs and moratoriums measurably reduce developer interest.",
      side=3, line=0.3, cex=0.85, col="#666666", font=3)

# Already-lit counties — subtle dashed dark border
lit_poly <- m[!is.na(m$is_lit) & m$is_lit, ]
plot(st_geometry(lit_poly), col=NA, border="#444444", lwd=0.6,
     lty=2, add=TRUE)

# Peer set on top
peer_poly <- m[m$fips %in% c("48367","48209","48221","48217"), ]
plot(st_geometry(peer_poly), col=NA, border=peer_col, lwd=2.5, add=TRUE)
# Hill hatched for moratorium
hill <- m[m$fips == "48217", ]
plot(st_geometry(hill), col=NA, border=peer_col, lwd=2.5,
     density=15, angle=45, add=TRUE)

# Labels: top-5 unlit-high-risk + peer set
draw_lbl(top_label[1:5], m, cex=0.82)
draw_lbl(peer_label, m, cex=0.95, col=peer_col, font=2)

# Compact legend in lower-left
legend("bottomleft",
       legend=c("low siting risk",
                "high siting risk",
                "already hosts a facility (dashed)",
                "Peer set (Parker · Hood · Hays · Hill)",
                "Hill — passed moratorium (hatched)"),
       fill=c(pal_risk[10], pal_risk[95], NA, NA, NA),
       border=c(NA, NA, "#444444", peer_col, peer_col),
       lwd=c(NA, NA, 0.6, 2.5, 2.5),
       lty=c(NA, NA, 2, 1, 1),
       density=c(NA, NA, NA, NA, 15),
       angle=c(NA, NA, NA, NA, 45),
       bty="n", cex=0.82,
       inset=c(0.02, -0.02))

# Footer: ranks + sources
mtext("Peer-set siting-risk ranks (out of 254 TX counties): Hill 191  ·  Parker 237  ·  Hood 245  ·  Hays 252.",
      side=1, line=2.0, cex=0.9, col="#222222", font=2)
mtext("Index = 0.35·land + 0.35·permissive + 0.30·infra-proximity. Sources: CHR + NASS + TWDB GCD map (2019-11) + Comptroller-registered facility distances.",
      side=1, line=3.5, cex=0.72, col="#666666")
dev.off()

# ── Print top-20 table ─────────────────────────────────────────────────────
cat("\n══ Top 20 highest siting-risk Texas counties ══\n\n")
top20 <- d[order(-siting_risk)][1:20]
print(top20[, .(
  fips, name,
  risk = round(siting_risk, 3),
  land = round(land_score, 2),
  permissive = round(permissive_score, 2),
  infra = round(infra_score, 2),
  dist_km = round(dist_km, 0),
  lit = fifelse(is_lit, "■", "·"),
  peer = fifelse(is_peer, "PEER", "")
)])

cat("\n══ Peer-set siting risk ══\n\n")
print(d[fips %in% c("48367","48209","48221","48217")][, .(
  fips, name,
  risk = round(siting_risk, 3),
  land = round(land_score, 2),
  permissive = round(permissive_score, 2),
  infra = round(infra_score, 2),
  dist_km = round(dist_km, 0),
  rank = sapply(siting_risk, function(v) sum(d$siting_risk >= v))
)])

cat("\nWrote ", file.path(VOUT, "F_tx_siting_risk.png"), "\n", sep="")
