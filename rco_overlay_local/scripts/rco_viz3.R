#!/usr/bin/env Rscript
# rco_viz3.R — render the NOW-LIT surface: RCO_max + dominant-channel maps,
# both national and TX, with site dots overlayed.
suppressPackageStartupMessages({
  library(data.table); library(sf); library(tigris); library(RColorBrewer)
})
options(tigris_use_cache = TRUE)

OUT  <- "~/rco_overlay/output"
VOUT <- "~/rco_overlay/viz"

nat   <- fread(file.path(OUT, "rco_surface_national.csv"),
               colClasses=list(character="fips"))
sites <- fread(file.path(OUT, "datacenter_sites_manual.csv"),
               colClasses=list(character="county_fips"))
gcd   <- fread("~/rco_run/RCO_03_gcd_pgma_coding.csv",
               colClasses=list(character="fips"))

counties <- counties(cb=TRUE, resolution="20m", year=2023, progress_bar=FALSE)
counties <- st_transform(counties, 5070)
counties$fips <- paste0(counties$STATEFP, counties$COUNTYFP)
counties <- counties[!counties$STATEFP %in% c("02","15","60","66","69","72","78"), ]
m <- merge(counties, nat, by="fips", all.x=TRUE)

# Sites: aggregate to counties so we can pinpoint with marker size
site_ct <- sites[!is.na(county_fips), .N, by=.(fips=county_fips)]
m <- merge(m, site_ct, by="fips", all.x=TRUE)

# Build county-centroid sf for site markers
site_pts <- m[!is.na(m$N), ]
if (nrow(site_pts)) site_pts$centroid <- suppressWarnings(st_centroid(st_geometry(site_pts)))

# --- (7) National RCO_max ---------------------------------------------------
pal_rco <- colorRampPalette(c("#f7fbff","#fdae61","#d73027"))(100)
bin <- function(x, pal, maxv=NULL){
  rng <- if (is.null(maxv)) max(x, na.rm=TRUE) else maxv
  i <- as.integer(pmin(99, pmax(0, floor((x/rng)*99)))+1); i[is.na(x)] <- NA
  pal[i]
}
maxv <- max(nat$rco_max, na.rm=TRUE)
m$col_rco <- bin(m$rco_max, pal_rco, maxv)
m$col_rco[is.na(m$col_rco)] <- "#eeeeee"

png(file.path(VOUT, "07_rco_max_national.png"),
    width=1800, height=1100, res=140)
par(mar=c(1,1,3,1))
plot(st_geometry(m), col=m$col_rco, border=NA, lwd=0.05,
     main="Resource-Competition Overlay (RCO max channel) — 104 operating facilities lit")
mtext("Force-D from Comptroller-registered facility COUNT (MW unavailable); RCO = D × susceptibility × (1 - mediator). Dark = highest competition.",
      side=1, line=0, cex=0.8)

# Marker for site-bearing counties
if (nrow(site_pts)) {
  coords <- st_coordinates(site_pts$centroid)
  points(coords, pch=21, bg="#1a1a1a", col="white",
         cex=0.5 + 1.2*sqrt(site_pts$N))
}

usr <- par("usr"); xs <- seq(usr[1]+0.55*diff(usr[1:2]), usr[2]-0.05*diff(usr[1:2]), length.out=101)
rect(xs[-101], usr[3]+0.02*diff(usr[3:4]), xs[-1], usr[3]+0.05*diff(usr[3:4]),
     col=pal_rco, border=NA)
text(xs[c(1,51,101)], usr[3]+0.07*diff(usr[3:4]),
     labels=c("0", sprintf("%.2f", maxv/2), sprintf("%.2f", maxv)),
     cex=0.8, pos=3)
legend("bottomleft", legend=c("1 facility","5","20"),
       pch=21, pt.bg="#1a1a1a", col="white",
       pt.cex=c(0.5+1.2*sqrt(1), 0.5+1.2*sqrt(5), 0.5+1.2*sqrt(20)),
       bty="n", cex=0.85, title="Operating facilities")
dev.off()

# --- (8) Dominant channel where D > 0 ---------------------------------------
chan_col <- c(water="#1f77b4", power="#ff7f0e", land="#2ca02c")
m$col_chan <- ifelse(!is.na(m$D) & m$D > 0,
                     chan_col[m$dominant_channel], "#eeeeee")
png(file.path(VOUT, "08_dominant_lit_national.png"),
    width=1800, height=1100, res=140)
par(mar=c(1,1,3,1))
plot(st_geometry(m), col=m$col_chan, border=NA, lwd=0.05,
     main="Dominant RCO channel — only where operating facilities are sited")
mtext("Each lit county = at least one Comptroller-registered facility. Colour = which channel (water/power/land) carries the highest competition value.",
      side=1, line=0, cex=0.8)
legend("bottomleft", legend=names(chan_col), fill=chan_col, bty="n", cex=0.9,
       title="Dominant channel")
dev.off()

# --- (9) Texas zoom: RCO_max + sites + peer set + GCD outline ---------------
tx <- m[m$STATEFP=="48", ]
tx <- merge(tx, gcd[, .(fips, gcd_funding, pgma)], by="fips", all.x=TRUE)
tx_site_pts <- site_pts[site_pts$STATEFP=="48", ]
peer   <- c("48367","48209","48221")
extras <- c("48217","48467","48439","48113","48337","48497")

png(file.path(VOUT, "09_tx_rco_max.png"),
    width=1600, height=1300, res=150)
par(mar=c(1,1,3,1))
plot(st_geometry(tx), col=tx$col_rco, border="white", lwd=0.2,
     main="Texas RCO_max — operating Comptroller-registered facilities only")

# GCD-covered outline
gcd_hi <- tx[!is.na(tx$gcd_funding) & tx$gcd_funding >= 1, ]
plot(st_geometry(gcd_hi), col=NA, border="#2c7fb8", lwd=1.5, add=TRUE)

# Peer set in red, extras in lighter
peer_poly  <- tx[tx$fips %in% peer, ]
extra_poly <- tx[tx$fips %in% extras, ]
plot(st_geometry(peer_poly),  col=NA, border="#d7191c", lwd=3, add=TRUE)
plot(st_geometry(extra_poly), col=NA, border="#fdae61", lwd=2, add=TRUE)

# Site markers
if (nrow(tx_site_pts)) {
  coords <- st_coordinates(tx_site_pts$centroid)
  points(coords, pch=21, bg="#000000", col="white",
         cex=0.6 + 1.4*sqrt(tx_site_pts$N))
}

# Labels for peer & extras
for (f in c(peer, extras)) {
  p <- tx[tx$fips==f, ]
  if (nrow(p)) {
    ct <- suppressWarnings(st_centroid(st_geometry(p)))
    text(st_coordinates(ct)[1], st_coordinates(ct)[2], p$NAME, cex=0.7)
  }
}

legend("bottomleft",
       legend=c("Peer set (Parker/Hays/Hood) — D=0 (no operating facility)",
                "Comparison set",
                "GCD coverage (mediator > 0)",
                "Operating facility cluster (size = count)"),
       col   =c("#d7191c","#fdae61","#2c7fb8","#000000"),
       lwd   =c(3,2,1.5,NA),
       pch   =c(NA,NA,NA,21),
       pt.bg =c(NA,NA,NA,"#000000"),
       bty="n", cex=0.78)
mtext("Fill = RCO_max. Peer set has zero operating facilities; the moratorium fight is over PROPOSED sites not in this dataset.",
      side=1, line=0, cex=0.8)
dev.off()

cat("\nWrote new PNGs:\n")
for (f in c("07_rco_max_national.png","08_dominant_lit_national.png","09_tx_rco_max.png"))
  cat("  ", file.path(VOUT, f), "  ", file.info(file.path(VOUT, f))$size, "B\n", sep="")
