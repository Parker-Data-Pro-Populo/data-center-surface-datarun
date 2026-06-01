#!/usr/bin/env Rscript
# rco_viz_refined.R — refined visuals after MW augmentation:
#   10  Texas RCO_max with MW-weighted force, DFW inset, peer-set highlighted
#   11  Per-channel split: top 10 counties per channel
#   12  Time-series of Comptroller registrations 2013-2026 (the AI boom)
#   13  Susceptibility vs Force scatter (which kind of county lit up?)
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

# Sites aggregated by county with MW totals
site_ct <- sites[!is.na(county_fips),
                 .(n=.N, mw=sum(mw,na.rm=TRUE)), by=.(fips=county_fips)]
m <- merge(m, site_ct, by="fips", all.x=TRUE)
site_pts <- m[!is.na(m$n), ]
if (nrow(site_pts)) site_pts$centroid <- suppressWarnings(st_centroid(st_geometry(site_pts)))

pal_rco <- colorRampPalette(c("#f7fbff","#fdae61","#d73027","#7f0000"))(100)
bin <- function(x, pal, maxv=NULL){
  rng <- if (is.null(maxv)) max(x, na.rm=TRUE) else maxv
  i <- as.integer(pmin(99, pmax(0, floor((x/rng)*99)))+1); i[is.na(x)] <- NA
  pal[i]
}
maxv <- max(nat$rco_max, na.rm=TRUE)
m$col_rco <- bin(m$rco_max, pal_rco, maxv)
m$col_rco[is.na(m$col_rco)] <- "#eeeeee"

# ── (10) Texas with DFW inset ─────────────────────────────────────────────
tx <- m[m$STATEFP=="48", ]
tx <- merge(tx, gcd[, .(fips,gcd_funding,pgma)], by="fips", all.x=TRUE)
tx_pts <- site_pts[site_pts$STATEFP=="48", ]
peer   <- c("48367","48209","48221")
extras <- c("48217","48467","48439","48113","48337","48497")

# Bounding box for DFW inset (centroid of Dallas + ~80km radius)
dfw_counties <- c("48085","48113","48121","48139","48251","48257","48367","48397",
                  "48439","48497","48337","48143","48181")
dfw <- tx[tx$fips %in% dfw_counties, ]
dfw_bbox <- st_bbox(dfw)

png(file.path(VOUT, "10_tx_rco_max_with_inset.png"),
    width=2000, height=1500, res=160)
layout(matrix(c(1,1,1,2,
                1,1,1,2,
                1,1,1,2), nrow=3, byrow=TRUE), widths=c(1,1,1,0.7))
par(mar=c(1,1,3,1))
plot(st_geometry(tx), col=tx$col_rco, border="white", lwd=0.2,
     main="Texas RCO_max — MW-weighted force, 104 operating facilities, 7.4 GW")
gcd_hi <- tx[!is.na(tx$gcd_funding) & tx$gcd_funding >= 1, ]
plot(st_geometry(gcd_hi), col=NA, border="#2c7fb8", lwd=1.3, add=TRUE)
peer_poly  <- tx[tx$fips %in% peer, ]
extra_poly <- tx[tx$fips %in% extras, ]
plot(st_geometry(extra_poly), col=NA, border="#fdae61", lwd=2, add=TRUE)
plot(st_geometry(peer_poly),  col=NA, border="#d7191c", lwd=3, add=TRUE)
if (nrow(tx_pts)) {
  coords <- st_coordinates(tx_pts$centroid)
  points(coords, pch=21, bg="black", col="white",
         cex=0.5 + 1.3*sqrt(tx_pts$mw/100))   # size ∝ √MW
}
# Outline DFW box on main map
rect(dfw_bbox$xmin, dfw_bbox$ymin, dfw_bbox$xmax, dfw_bbox$ymax,
     border="#444444", lwd=1.5, lty=2)
text(dfw_bbox$xmin, dfw_bbox$ymax + 30000, "DFW inset →",
     cex=0.8, pos=4, col="#444444")
# Big-county labels
for (f in c(peer, "48441","48331","48371","48029","48201","48453")) {
  p <- tx[tx$fips==f, ]
  if (nrow(p)) {
    ct <- suppressWarnings(st_centroid(st_geometry(p)))
    text(st_coordinates(ct)[1], st_coordinates(ct)[2], p$NAME, cex=0.7)
  }
}
legend("bottomleft",
       legend=c("Peer set (Parker/Hood/Hays) — D=0",
                "Comparison set",
                "GCD coverage (mediator)",
                "Operating facility (size ∝ √MW)"),
       col=c("#d7191c","#fdae61","#2c7fb8","black"),
       lwd=c(3,2,1.3,NA), pch=c(NA,NA,NA,21),
       pt.bg=c(NA,NA,NA,"black"), bty="n", cex=0.85)
mtext("Color = RCO_max (water/power/land highest). 0–0.66 scale. Source: TX Comptroller Registered DCs 2026-04 + curated MW (press).",
      side=1, line=0, cex=0.85)

# DFW inset
par(mar=c(2,1,2,1))
plot(st_geometry(dfw), col=dfw$col_rco, border="white", lwd=0.3, main="DFW inset")
dfw_pts <- tx_pts[tx_pts$fips %in% dfw_counties, ]
if (nrow(dfw_pts)) {
  coords <- st_coordinates(dfw_pts$centroid)
  points(coords, pch=21, bg="black", col="white",
         cex=0.6 + 1.5*sqrt(dfw_pts$mw/100))
}
gcd_dfw <- dfw[!is.na(dfw$gcd_funding) & dfw$gcd_funding >= 1, ]
plot(st_geometry(gcd_dfw), col=NA, border="#2c7fb8", lwd=1.3, add=TRUE)
peer_dfw  <- dfw[dfw$fips %in% peer, ]
extra_dfw <- dfw[dfw$fips %in% extras, ]
plot(st_geometry(extra_dfw), col=NA, border="#fdae61", lwd=2, add=TRUE)
plot(st_geometry(peer_dfw),  col=NA, border="#d7191c", lwd=3, add=TRUE)
for (f in unique(c(dfw$fips, peer, extras))) {
  p <- dfw[dfw$fips==f, ]
  if (nrow(p)) {
    ct <- suppressWarnings(st_centroid(st_geometry(p)))
    text(st_coordinates(ct)[1], st_coordinates(ct)[2], p$NAME, cex=0.65)
  }
}
dev.off()

# ── (11) Top counties per channel (3-panel bar chart) ─────────────────────
chan_data <- nat[D > 0]
png(file.path(VOUT, "11_top_counties_per_channel.png"),
    width=1800, height=900, res=150)
par(mfrow=c(1,3), mar=c(4,7,3,1))
for (ch in c("water","power","land")) {
  col <- paste0("rco_", ch)
  top <- chan_data[order(-get(col))][1:10]
  top[, fips_lbl := paste0(fips, " (", substr(c("48029","48085","48113","48121",
                          "48139","48201","48331","48349","48371","48441","48453")
                          [match(fips,c("48029","48085","48113","48121","48139",
                                        "48201","48331","48349","48371","48441","48453"))],
                          1, 5))]
  # Use a name lookup
  cnty_names <- c("48029"="Bexar","48085"="Collin","48113"="Dallas",
                   "48121"="Denton","48135"="Ector","48139"="Ellis",
                   "48201"="Harris","48331"="Milam","48335"="Mitchell",
                   "48349"="Navarro","48371"="Pecos","48441"="Taylor",
                   "48453"="Travis","48191"="Hall","48075"="Childress",
                   "48027"="Bell","48041"="Brazos","48491"="Williamson")
  top[, nm := paste(cnty_names[fips], fips, sep="\n")]
  bp_col <- c(water="#1f77b4", power="#ff7f0e", land="#2ca02c")[ch]
  bar_vals <- top[[col]]
  bp <- barplot(rev(bar_vals), horiz=TRUE, names.arg=rev(top$nm),
                col=bp_col, las=1, main=paste0("RCO_", ch),
                xlim=c(0, max(bar_vals)*1.15), cex.names=0.75, border=NA)
  text(rev(bar_vals), bp, sprintf("%.3f", rev(bar_vals)), pos=4, cex=0.7)
}
title("Top 10 counties per channel (D > 0 only) — MW-weighted force",
      outer=TRUE, line=-2, cex.main=1.15)
dev.off()

# ── (12) Time series of Comptroller registrations 2013-2026 ────────────────
sites[, eff_year := as.integer(substr(status_date, 7, 10))]
yr_summary <- sites[!is.na(eff_year), .(n=.N, mw=sum(mw, na.rm=TRUE)),
                    by=eff_year][order(eff_year)]
png(file.path(VOUT, "12_registration_timeseries.png"),
    width=1500, height=900, res=150)
par(mar=c(4,4,3,4))
bp <- barplot(yr_summary$n, names.arg=yr_summary$eff_year,
              col="#377eb8", border=NA, las=1, ylim=c(0, max(yr_summary$n)*1.1),
              main="Texas data-center registrations by year (Comptroller registry)",
              ylab="New registrations", cex.names=0.9)
text(bp, yr_summary$n, yr_summary$n, pos=3, cex=0.8, col="#222222")
# Annotate the AI boom shoulder
abline(v=mean(bp[which(yr_summary$eff_year == 2024)] +
              bp[which(yr_summary$eff_year == 2023)])/2,
       col="#d7191c", lwd=2, lty=2)
text(bp[which(yr_summary$eff_year == 2024)], par("usr")[4]*0.92,
     "AI buildout begins", col="#d7191c", cex=0.9, pos=4)
mtext("Bar height = number of newly-registered facilities. 75 of 130 (58%) registered in the past 30 months. 2026 figure is YTD through May.",
      side=1, line=2.5, cex=0.85)
dev.off()

# ── (13) Susceptibility vs Force scatter for lit counties ──────────────────
lit <- nat[D > 0]
lit <- merge(lit, site_ct, by="fips", all.x=TRUE)
lit[, cnty_lbl := c("48029"="Bexar","48085"="Collin","48113"="Dallas",
                     "48121"="Denton","48135"="Ector","48139"="Ellis",
                     "48201"="Harris","48331"="Milam","48335"="Mitchell",
                     "48349"="Navarro","48371"="Pecos","48441"="Taylor",
                     "48453"="Travis","48191"="Hall","48075"="Childress")[fips]]

png(file.path(VOUT, "13_sus_vs_force_scatter.png"),
    width=1500, height=1100, res=150)
par(mar=c(4,4,3,2))
plot(lit$D, lit$sus_water,
     xlab="Force-D (MW-weighted, [0,1])", ylab="Water susceptibility",
     main="What kind of county lit up? Force × water susceptibility",
     xlim=c(0,1.1), ylim=c(0,1), pch=21, cex=2,
     bg=ifelse(lit$dominant_channel == "water", "#1f77b4",
        ifelse(lit$dominant_channel == "power", "#ff7f0e", "#2ca02c")),
     col="white")
text(lit$D, lit$sus_water, lit$cnty_lbl,
     pos=ifelse(lit$D > 0.5, 2, 4), cex=0.85)
abline(h=0.5, lty=3, col="grey60"); abline(v=0.5, lty=3, col="grey60")
text(0.95, 0.95, "high D × high susceptibility\n(real crisis zone)",
     col="#d7191c", cex=0.8, pos=2)
text(0.05, 0.05, "low D × low susceptibility\n(facility doesn't matter much here)",
     col="grey40", cex=0.8, pos=4)
legend("bottomright", legend=c("water","power","land"),
       pch=21, pt.bg=c("#1f77b4","#ff7f0e","#2ca02c"), col="white",
       title="Dominant channel", bty="n", pt.cex=1.7)
dev.off()

cat("\nWrote refined visuals:\n")
for (f in c("10_tx_rco_max_with_inset.png","11_top_counties_per_channel.png",
            "12_registration_timeseries.png","13_sus_vs_force_scatter.png"))
  cat("  ", file.path(VOUT, f), "  ", file.info(file.path(VOUT, f))$size, "B\n", sep="")
