#!/usr/bin/env Rscript
# regen_chart_G_2026-09.R — regenerate chart G (the 14-site FWPC network map)
# after fixing the upside-down basemap.
#
# THE BUG. scripts/viz_style.R called
#   rasterImage(raster, xmin, ymax, xmax, ymin)
# but rasterImage() takes (image, xleft, ybottom, xright, ytop). Passing ymax as
# ybottom and ymin as ytop drew the basemap vertically mirrored — place labels
# reversed, Oklahoma City at the bottom, Monterrey at the top — behind correctly
# drawn county polygons. Present since the June 2026 design-system pass and
# published on section 04 of the briefing. Fixed in viz_style.R.
#
# WHY THIS FILE EXISTS. scripts/rco_viz_fwpc_v2.R is kept as the June artifact.
# It reads from ~/rco_run and ~/rco_overlay, which exist only on the machine that
# first ran it, and needs `tigris` to fetch county geometry. This re-run reads
# everything from the repository and takes geometry from the Census cartographic
# boundary file, so it reproduces anywhere.
#
# Geometry: cb_2023_us_county_20m from
#   https://www2.census.gov/geo/tiger/GENZ2023/shp/cb_2023_us_county_20m.zip
# Point GEO_DIR at the unzipped shapefile, or set RCO_GEO.

suppressPackageStartupMessages({ library(data.table); library(sf) })

REPO    <- normalizePath("..", mustWork = TRUE)
GEO_DIR <- Sys.getenv("RCO_GEO", unset = file.path(
  "/private/tmp/claude-501/-Users-clbutler-Desktop-Parker-County-Exploration",
  "05641893-acf3-47a2-8708-155bebe8737d/scratchpad/geo"))
SHP     <- file.path(GEO_DIR, "cb_2023_us_county_20m.shp")
stopifnot(file.exists(SHP))

Sys.setenv(RCO_BASEMAP = file.path(REPO, "scripts", "basemap_carto_voyager_tx.png"))
source(file.path(REPO, "scripts", "viz_style.R"))

fwpc <- fread(file.path(REPO, "parker_costs", "fwpc_sites.csv"),
              colClasses = list(character = "county_fips"))
nat  <- fread(file.path(REPO, "rco_overlay_local", "output", "rco_surface_national.csv"),
              colClasses = list(character = "fips"))

cnty <- st_read(SHP, quiet = TRUE)
cnty$fips <- paste0(cnty$STATEFP, cnty$COUNTYFP)
tx <- cnty[cnty$STATEFP == "48", ]
tx <- st_transform(tx, 3857)
m  <- merge(tx, nat, by = "fips", all.x = TRUE)

fwpc_fips <- unique(fwpc$county_fips)
peer_fips <- c("48367", "48221", "48209", "48217")

storied <- data.table(
  fips  = c("48441","48331","48029","48201","48453","48085","48371",
            "48491","48027","48189","48425","48367","48221","48217","48209"),
  label = c("Taylor","Milam","Bexar","Harris","Travis","Collin","Pecos",
            "Williamson","Bell","Hale","Somervell","Parker","Hood","Hill","Hays"),
  bold  = c(rep(FALSE, 11), rep(TRUE, 4)),
  color = c(rep(PAL$title, 11), rep(PAL$peer, 4))
)

OUT <- file.path(REPO, "slides", "img", "G_fwpc_network.png")
png(OUT, width = 2200, height = 1900, res = 180)

init_tx_map(
  title    = "Fort Worth Power Core LLC — 14-site statewide gas-plant network",
  subtitle = "One operator, 11 counties, 14 sites. Parker is one of fourteen. Hill · Hood · Hays — conspicuously absent.",
  source_text = paste("Source: TCEQ Central Registry (Customer CN606278281), TX Comptroller franchise tax,",
                      "pulled 2026-06-01. Basemap: CARTO Voyager. Chart regenerated 2026-09-03."),
  basemap_alpha = 0.32
)
draw_unlit(m, alpha = 0.18)
draw_county_lines(m, lwd = 1.0, col = PAL$border)
draw_fwpc(m, fwpc_fips, fill_alpha = 0.30, lwd = 2.2)
draw_peer(m, peer_fips, lwd = 2.8)
draw_storied_labels(m, storied, cex = 0.85)
draw_legend(list(
  legend = c("Fort Worth Power Core LLC affected county",
             "Peer set (Parker · Hood · Hays · Hill)",
             "Other county"),
  fill   = c(paste0(PAL$fwpc, "55"), NA, paste0(PAL$unlit, "B0")),
  border = c(PAL$fwpc, PAL$peer, PAL$border),
  lwd    = c(2.2, 2.8, 1.0),
  lty    = c(1, 1, 1),
  pch    = c(NA, NA, NA),
  pt_bg  = c(NA, NA, NA),
  density= c(NA, NA, NA),
  angle  = c(NA, NA, NA)
))
usr <- par("usr")
halo_text(usr[1] + 0.62 * diff(usr[1:2]),
          usr[3] + 0.04 * diff(usr[3:4]),
          "Williamson (Jonah TX) — highest-leverage organizing target",
          cex = 0.92, font = 2, col = PAL$fwpc, halo_w = 1.5)
dev.off()
cat("Wrote", OUT, "\n")
