#!/usr/bin/env Rscript
# rco_viz_fwpc_v2.R — chart G, refit using the new design system.
# - CARTO Voyager basemap at 32% opacity as the canvas
# - Heavier county lines
# - FWPC counties as translucent purple fill (no dots — legend handles it)
# - Peer set as red outline (no on-map (PEER) labels — legend handles it)
# - Labels only for the storied non-redundant counties

suppressPackageStartupMessages({
  library(data.table); library(sf); library(tigris)
})
options(tigris_use_cache = TRUE)
source("~/rco_run/viz_style.R")

VOUT <- "~/rco_overlay/viz"
fwpc <- fread("~/rco_run/fwpc_sites.csv",
              colClasses = list(character = "county_fips"))
nat  <- fread("~/rco_overlay/output/rco_surface_national.csv",
              colClasses = list(character = "fips"))
gcd  <- fread("~/rco_run/RCO_03_gcd_pgma_coding.csv",
              colClasses = list(character = "fips"))

cnty <- counties(cb = TRUE, resolution = "20m", year = 2023,
                 progress_bar = FALSE)
cnty$fips <- paste0(cnty$STATEFP, cnty$COUNTYFP)
tx <- cnty[cnty$STATEFP == "48", ]
tx <- st_transform(tx, 3857)

m <- merge(tx, nat, by = "fips", all.x = TRUE)

fwpc_fips <- unique(fwpc$county_fips)
peer_fips <- c("48367","48221","48209","48217")

# Storied labels — only counties whose role isn't already conveyed by outline/fill
# Storied = high-MW operating counties + Williamson (organizing target callout)
storied <- data.table(
  fips  = c("48441","48331","48029","48201","48453","48085","48371",
            "48491","48027","48189","48425","48367","48221","48217","48209"),
  label = c("Taylor","Milam","Bexar","Harris","Travis","Collin","Pecos",
            "Williamson","Bell","Hale","Somervell","Parker","Hood","Hill","Hays"),
  bold  = c(FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,
            FALSE,FALSE,FALSE,FALSE,TRUE,TRUE,TRUE,TRUE),
  color = c(rep(PAL$title, 11), rep(PAL$peer, 4))
)

# ── Render ────────────────────────────────────────────────────────────────
png(file.path(VOUT, "G_fwpc_network.png"),
    width = 2200, height = 1900, res = 180)

init_tx_map(
  title    = "Fort Worth Power Core LLC — 14-site statewide gas-plant network",
  subtitle = "One operator, 11 counties, 14 sites. Parker is one of fourteen. Hill · Hood · Hays — conspicuously absent.",
  source_text = "Source: TCEQ Central Registry (Customer CN606278281), TX Comptroller franchise tax, pulled 2026-06-01. Basemap: CARTO Voyager.",
  basemap_alpha = 0.32
)

# Background: subtle unlit warm-cream tint on all counties so the basemap
# texture stays, but the political grid is clearly the substrate
draw_unlit(m, alpha = 0.18)

# County lines — heavier than before
draw_county_lines(m, lwd = 1.0, col = PAL$border)

# Fort Worth Power Core fill (the message of this chart)
draw_fwpc(m, fwpc_fips, fill_alpha = 0.30, lwd = 2.2)

# Peer-set outline (Parker/Hood/Hays/Hill in red)
draw_peer(m, peer_fips, lwd = 2.8)

# Labels for storied counties only — peer set bold red, FWPC counties plain
draw_storied_labels(m, storied, cex = 0.85)

# Legend (handles the categorical info — no on-map redundancy needed)
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

# Bottom-right callout text emphasizing the organizing message
usr <- par("usr")
halo_text(usr[1] + 0.62 * diff(usr[1:2]),
          usr[3] + 0.04 * diff(usr[3:4]),
          "Williamson (Jonah TX) — highest-leverage organizing target",
          cex = 0.92, font = 2, col = PAL$fwpc, halo_w = 1.5)

dev.off()
cat(sprintf("Wrote %s/G_fwpc_network.png\n", VOUT))
