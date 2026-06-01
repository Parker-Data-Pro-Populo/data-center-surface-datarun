#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(data.table); library(sf); library(tigris); library(RColorBrewer)
})
options(tigris_use_cache = TRUE)

OUT  <- "~/rco_overlay/output"
VOUT <- "~/rco_overlay/viz"

nat  <- fread(file.path(OUT, "rco_surface_national.csv"),
              colClasses = list(character = "fips"))
nass <- fread(file.path(OUT, "rco_nass.csv"),
              colClasses = list(character = "fips"))

counties <- counties(cb=TRUE, resolution="20m", year=2023, progress_bar=FALSE)
counties <- st_transform(counties, 5070)
counties$fips <- paste0(counties$STATEFP, counties$COUNTYFP)
counties <- counties[!counties$STATEFP %in% c("02","15","60","66","69","72","78"), ]

m <- merge(counties, nat,  by="fips", all.x=TRUE)
m <- merge(m,        nass, by="fips", all.x=TRUE)

pal_greens <- colorRampPalette(brewer.pal(9,"YlGn"))(100)
pal_browns <- colorRampPalette(brewer.pal(9,"YlOrBr"))(100)
bin <- function(x, pal){
  i <- as.integer(pmin(99, pmax(0, floor(x*99)))+1); i[is.na(x)] <- NA; pal[i]
}

# --- (4) National LAND susceptibility (now with NASS) ----------------------
m$col_land <- bin(m$sus_land, pal_greens)
m$col_land[is.na(m$col_land)] <- "#eeeeee"

png(file.path(VOUT, "04_sus_land_national.png"),
    width=1800, height=1100, res=140)
par(mar=c(1,1,3,1))
plot(st_geometry(m), col=m$col_land, border=NA, lwd=0.05,
     main="Land-channel susceptibility — now includes NASS cropland share (2022 Census of Ag)")
mtext("Composite of ag-emp share (QCEW), farm-prop income share (BEA), rural % (CHR), cropland share of land (NASS).",
      side=1, line=0, cex=0.85)
usr <- par("usr"); xs <- seq(usr[1]+0.55*diff(usr[1:2]), usr[2]-0.05*diff(usr[1:2]), length.out=101)
rect(xs[-101], usr[3]+0.02*diff(usr[3:4]), xs[-1], usr[3]+0.05*diff(usr[3:4]),
     col=pal_greens, border=NA)
text(xs[c(1,51,101)], usr[3]+0.07*diff(usr[3:4]),
     labels=c("low","mid","high"), cex=0.8, pos=3)
dev.off()

# --- (5) Raw NASS cropland share of county land area ----------------------
m$col_crop <- bin(m$cropland_share_of_land, pal_browns)
m$col_crop[is.na(m$col_crop)] <- "#eeeeee"

png(file.path(VOUT, "05_cropland_share_national.png"),
    width=1800, height=1100, res=140)
par(mar=c(1,1,3,1))
plot(st_geometry(m), col=m$col_crop, border=NA, lwd=0.05,
     main="NASS cropland share of county land (2022) — the raw new input")
mtext("Cropland acres / total county land acres. Iowa-Illinois belt clearly visible; West / Appalachia low; TX moderate.",
      side=1, line=0, cex=0.85)
xs <- seq(usr[1]+0.55*diff(usr[1:2]), usr[2]-0.05*diff(usr[1:2]), length.out=101)
rect(xs[-101], usr[3]+0.02*diff(usr[3:4]), xs[-1], usr[3]+0.05*diff(usr[3:4]),
     col=pal_browns, border=NA)
text(xs[c(1,51,101)], usr[3]+0.07*diff(usr[3:4]),
     labels=c("0%","mid","100%"), cex=0.8, pos=3)
dev.off()

# --- (6) TX zoom: cropland share, peer set ---------------------------------
tx <- m[m$STATEFP=="48", ]
peer   <- c("48367","48209","48221")
extras <- c("48217","48467","48439","48113","48337","48497")
png(file.path(VOUT, "06_tx_cropland_share.png"),
    width=1600, height=1300, res=150)
par(mar=c(1,1,3,1))
plot(st_geometry(tx), col=tx$col_crop, border="white", lwd=0.2,
     main="Texas — NASS cropland share, with peer set highlighted")
peer_poly <- tx[tx$fips %in% peer, ]
plot(st_geometry(peer_poly), col=NA, border="#d7191c", lwd=3, add=TRUE)
extra_poly <- tx[tx$fips %in% extras, ]
plot(st_geometry(extra_poly), col=NA, border="#1a9850", lwd=2, add=TRUE)
for (f in c(peer, extras)) {
  p <- tx[tx$fips==f, ]
  if (nrow(p)) {
    ct <- suppressWarnings(st_centroid(st_geometry(p)))
    text(st_coordinates(ct)[1], st_coordinates(ct)[2], p$NAME, cex=0.7)
  }
}
legend("bottomleft",
       legend=c("Peer set (Parker/Hays/Hood)", "Comparison set"),
       col=c("#d7191c","#1a9850"), lwd=c(3,2), bty="n", cex=0.85)
mtext("Brown fill = cropland share of land. Red = peer set; green = comparison.",
      side=1, line=0, cex=0.8)
dev.off()

cat("\nWrote new PNGs:\n")
for (f in c("04_sus_land_national.png","05_cropland_share_national.png","06_tx_cropland_share.png"))
  cat("  ", file.path(VOUT, f), " ", file.info(file.path(VOUT, f))$size, "B\n", sep="")
