#!/usr/bin/env Rscript
# rco_viz.R — first-cut visuals from the RCO substrate (D=0 yet, so this is
# the "latent surface" map: where the country is exposed before any force).
suppressPackageStartupMessages({
  library(data.table); library(sf); library(tigris); library(RColorBrewer)
})
options(tigris_use_cache = TRUE)

OUT  <- "~/rco_overlay/output"
VOUT <- "~/rco_overlay/viz"; dir.create(VOUT, recursive=TRUE, showWarnings=FALSE)

nat  <- fread(file.path(OUT, "rco_surface_national.csv"),
              colClasses = list(character = "fips"))
gcd  <- fread("~/rco_run/RCO_03_gcd_pgma_coding.csv",
              colClasses = list(character = "fips"))

# County polygons (CONUS) and a separate TX subset for the focus inset.
counties <- counties(cb = TRUE, resolution = "20m", year = 2023, progress_bar = FALSE)
counties <- st_transform(counties, 5070)                              # CONUS Albers
counties$fips <- paste0(counties$STATEFP, counties$COUNTYFP)
counties <- counties[!counties$STATEFP %in% c("02","15","60","66","69","72","78"), ]

m_nat <- merge(counties, nat, by = "fips", all.x = TRUE)

# --- (1) National water susceptibility ----------------------------------------
pal_blues <- colorRampPalette(brewer.pal(9, "Blues"))(100)
bin_color <- function(x, pal){
  i <- as.integer(pmin(99, pmax(0, floor(x * 99))) + 1); i[is.na(x)] <- NA
  pal[i]
}
m_nat$col_water <- bin_color(m_nat$sus_water, pal_blues)
m_nat$col_water[is.na(m_nat$col_water)] <- "#eeeeee"

png(file.path(VOUT, "01_sus_water_national.png"),
    width = 1800, height = 1100, res = 140)
par(mar = c(1,1,3,1))
plot(st_geometry(m_nat), col = m_nat$col_water, border = NA, lwd = 0.05,
     main = "Water-channel susceptibility (county) — RCO substrate, pre-force")
mtext("Composite of rural %, drinking-water-violation flag, severe-housing-problems (CHR 2025). National z-score → [0,1].",
      side = 1, line = 0, cex = 0.85)
# Color bar
usr <- par("usr"); xs <- seq(usr[1]+0.55*diff(usr[1:2]), usr[2]-0.05*diff(usr[1:2]), length.out=101)
rect(xs[-101], usr[3]+0.02*diff(usr[3:4]), xs[-1], usr[3]+0.05*diff(usr[3:4]),
     col = pal_blues, border = NA)
text(xs[c(1,51,101)], usr[3]+0.07*diff(usr[3:4]),
     labels=c("low","mid","high"), cex=0.8, pos=3)
dev.off()

# --- (2) Texas zoom: water susceptibility + GCD mediator + peer set -----------
tx <- m_nat[m_nat$STATEFP == "48", ]
tx <- merge(tx, gcd[, .(fips, gcd_present, gcd_funding, pgma)],
            by = "fips", all.x = TRUE)
peer <- c("48367","48209","48221")                # Parker / Hays / Hood
extras <- c("48217","48467","48439","48113","48337","48497")  # comparison

png(file.path(VOUT, "02_tx_sus_water_peerset.png"),
    width = 1600, height = 1300, res = 150)
par(mar = c(1,1,3,1))
plot(st_geometry(tx), col = tx$col_water, border = "white", lwd = 0.2,
     main = "Texas — water susceptibility, GCD coverage, and the peer set")

# Overlay GCD-covered counties with a hatched outline
gcd_hi <- tx[!is.na(tx$gcd_funding) & tx$gcd_funding >= 1, ]
plot(st_geometry(gcd_hi), col = NA, border = "#2c7fb8",
     lwd = 1.8, add = TRUE)

# Highlight peer set (Parker / Hays / Hood) in red outline
peer_poly <- tx[tx$fips %in% peer, ]
plot(st_geometry(peer_poly), col = NA, border = "#d7191c",
     lwd = 3, add = TRUE)
# Highlight the extras (Hill / Van Zandt / Tarrant / Dallas / Montague / Wise)
extra_poly <- tx[tx$fips %in% extras, ]
plot(st_geometry(extra_poly), col = NA, border = "#fdae61",
     lwd = 2, add = TRUE)
# Labels
for (f in c(peer, extras)) {
  p <- tx[tx$fips == f, ]
  if (nrow(p)) {
    ct <- suppressWarnings(st_centroid(st_geometry(p)))
    text(st_coordinates(ct)[1], st_coordinates(ct)[2], p$NAME, cex = 0.7)
  }
}
legend("bottomleft",
       legend = c("Peer set (Parker/Hays/Hood)", "Comparison set",
                  "GCD coverage (mediator > 0)", "no GCD / unknown"),
       col    = c("#d7191c", "#fdae61", "#2c7fb8", "grey60"),
       lwd    = c(3, 2, 1.8, 0.4), bty = "n", cex = 0.85)
mtext("Blue fill = water susceptibility. Blue outline = GCD coverage from RCO_03 hand-code. Red = peer set; orange = comparison.",
      side = 1, line = 0, cex = 0.8)
dev.off()

# --- (3) Dominant-channel map (TX) -- shows what the surface WILL look like ---
chan_col <- c(water = "#1f77b4", power = "#ff7f0e", land = "#2ca02c")
tx$col_chan <- chan_col[tx$dominant_channel]
tx$col_chan[is.na(tx$col_chan)] <- "#eeeeee"
png(file.path(VOUT, "03_tx_dominant_channel.png"),
    width = 1600, height = 1300, res = 150)
par(mar = c(1,1,3,1))
plot(st_geometry(tx), col = tx$col_chan, border = "white", lwd = 0.2,
     main = "Texas — dominant channel by substrate (which channel wins where, if force lands)")
legend("bottomleft", legend = names(chan_col), fill = chan_col, bty = "n",
       cex = 1, title = "dominant channel")
mtext("Per-county arg-max over (sus_water, sus_power, sus_land). D=0 still, so this is the LATENT pattern.",
      side = 1, line = 0, cex = 0.8)
dev.off()

# --- Summary numbers --------------------------------------------------------
cat("\nWrote PNGs:\n")
for (f in list.files(VOUT, full.names = TRUE)) cat("  ", f, " ",
   file.info(f)$size, "B\n", sep="")
