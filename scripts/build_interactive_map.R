#!/usr/bin/env Rscript
# build_interactive_map.R — interactive HTML map of the Texas RCO + Black
# Mountain + Fort Worth Power Core landscape. Self-contained leaflet widget.
#
# Layers (toggleable in the upper-right control):
#   • Resource-Competition Overlay (dominant channel × intensity)
#   • Operating MW concentration  (Comptroller-registered fleet)
#   • Fort Worth Power Core network (14 sites)
#   • Groundwater Conservation District coverage
#   • Peer set (Parker · Hood · Hays · Hill) — always on outline
#
# Basemaps available (top-right):
#   • CARTO Voyager (default)
#   • CARTO Positron (clean light)
#   • OpenTopoMap (terrain)
#
# Click any county → popup with: FIPS, name, RCO water/power/land,
# dominant channel, GCD info, operating MW, # of facilities.

.libPaths(c("~/R/library", .libPaths()))
suppressPackageStartupMessages({
  library(sf); library(data.table); library(leaflet); library(htmlwidgets)
})

OUT  <- "~/rco_overlay/output"
nat  <- fread(file.path(OUT, "rco_surface_national.csv"),
              colClasses = list(character = "fips"))
sites<- fread(file.path(OUT, "datacenter_sites_manual.csv"),
              colClasses = list(character = "county_fips"))
gcd  <- fread("~/rco_run/RCO_03_gcd_pgma_coding.csv",
              colClasses = list(character = "fips"))
fwpc <- fread("~/rco_run/fwpc_sites.csv",
              colClasses = list(character = "county_fips"))

# County polygons (cb_20m for browser-friendly file size)
cnty <- suppressWarnings(tigris::counties(cb = TRUE, resolution = "20m",
                                          year = 2023, progress_bar = FALSE))
cnty$fips <- paste0(cnty$STATEFP, cnty$COUNTYFP)
tx <- cnty[cnty$STATEFP == "48", ]
tx <- st_transform(tx, 4326)   # leaflet needs WGS84

# Merge in derived data
tx <- merge(tx, nat,  by = "fips", all.x = TRUE)
tx <- merge(tx, gcd[, .(fips, gcd_name, gcd_funding, pgma)],
            by = "fips", all.x = TRUE)

# MW + facility count per county
site_agg <- sites[!is.na(county_fips), .(
  n_facilities = .N,
  total_mw    = sum(mw, na.rm = TRUE),
  facility_list = paste0(sprintf("&bull; %s (%s MW)",
                                  substr(name, 1, 40),
                                  ifelse(is.na(mw), "?", mw)),
                          collapse = "<br/>")
), by = .(fips = county_fips)]
tx <- merge(tx, site_agg, by = "fips", all.x = TRUE)

# FWPC presence
fwpc_fips <- unique(fwpc$county_fips)
tx$is_fwpc <- tx$fips %in% fwpc_fips
fwpc_per_county <- fwpc[, .(fwpc_sites = paste0(site_name, collapse = " · ")),
                        by = .(fips = county_fips)]
tx <- merge(tx, fwpc_per_county, by = "fips", all.x = TRUE)

# Peer set
peer_fips <- c("48367","48221","48209","48217")
tx$is_peer <- tx$fips %in% peer_fips

# ── Palette ─────────────────────────────────────────────────────────────────
PAL <- list(
  water  = "#2c7fb8", power = "#e6783c", land = "#5da75a",
  peer   = "#b91c1c", fwpc  = "#6d28d9", gcd  = "#475569",
  unlit  = "#f0e9dd", border = "#7a7367"
)

# RCO color by dominant channel; opacity by rco_max
rco_fill <- function(ch, v, max_v) {
  base <- switch(ch %||% "x",
                 water = PAL$water, power = PAL$power, land = PAL$land,
                 "#cccccc")
  base
}
`%||%` <- function(a, b) if (length(a) && !is.na(a)) a else b
rco_alpha <- function(v, max_v, min_a = 0.35, max_a = 0.78) {
  if (is.na(v) || v == 0) return(0)
  min_a + (max_a - min_a) * (v / max_v)
}

# Per-county popup HTML
mk_popup <- function(row) {
  rco_w <- round(row$rco_water %||% 0, 3)
  rco_p <- round(row$rco_power %||% 0, 3)
  rco_l <- round(row$rco_land  %||% 0, 3)
  dom   <- row$dominant_channel %||% "(no operating facility)"
  mw    <- ifelse(is.na(row$total_mw), 0, row$total_mw)
  n_fac <- ifelse(is.na(row$n_facilities), 0, row$n_facilities)
  gcd_n <- ifelse(is.na(row$gcd_name) || row$gcd_name == "no GCD",
                  "no GCD coverage", row$gcd_name)
  fwpc_note <- if (row$is_fwpc) {
    sprintf("<br/><b style='color:%s'>Fort Worth Power Core site:</b> %s",
            PAL$fwpc, row$fwpc_sites %||% "")
  } else ""
  peer_note <- if (row$is_peer)
    sprintf("<br/><b style='color:%s'>PEER COUNTY</b>", PAL$peer) else ""

  sprintf(paste0(
    "<div style='font:13px sans-serif;line-height:1.45'>",
    "<b style='font-size:14px'>%s County</b> &nbsp;<span style='color:#888'>(FIPS %s)</span>%s%s<hr style='margin:5px 0'/>",
    "<b>RCO surface</b><br/>",
    "&nbsp;&nbsp;Water: %.3f &nbsp;&middot;&nbsp; Power: %.3f &nbsp;&middot;&nbsp; Land: %.3f<br/>",
    "&nbsp;&nbsp;Dominant: <b>%s</b><br/>",
    "<b>Operating fleet</b><br/>",
    "&nbsp;&nbsp;Facilities: %d &nbsp;&middot;&nbsp; MW: %s<br/>",
    "<b>Water mediator</b><br/>",
    "&nbsp;&nbsp;GCD: %s<br/>",
    "</div>"),
    row$NAME, row$fips, peer_note, fwpc_note,
    rco_w, rco_p, rco_l, dom,
    n_fac, format(round(mw), big.mark = ","),
    gcd_n
  )
}
tx$popup <- sapply(seq_len(nrow(tx)), function(i) mk_popup(tx[i, ]))

# RCO surface fill colors
max_rco <- max(tx$rco_max, na.rm = TRUE)
tx$rco_color   <- sapply(tx$dominant_channel, function(ch) rco_fill(ch))
tx$rco_opacity <- sapply(tx$rco_max, function(v) rco_alpha(v, max_rco))

# MW concentration (log scale, single hue Reds)
mw_breaks <- c(-Inf, 0, 50, 100, 250, 500, 1000, Inf)
mw_palette <- c("#f0e9dd", "#fee5d9","#fcae91","#fb6a4a","#de2d26",
                "#a50f15","#67000d")
tx$mw_color <- mw_palette[as.integer(cut(
  ifelse(is.na(tx$total_mw), 0, tx$total_mw),
  mw_breaks, right = TRUE))]

# ── Build the map ──────────────────────────────────────────────────────────
m <- leaflet(tx,
             options = leafletOptions(minZoom = 5, maxZoom = 12)) |>
  # Basemaps
  addProviderTiles("CartoDB.Voyager",
                   group = "Voyager",
                   options = providerTileOptions(opacity = 0.85)) |>
  addProviderTiles("CartoDB.Positron",
                   group = "Positron (light)",
                   options = providerTileOptions(opacity = 0.85)) |>
  addProviderTiles("OpenTopoMap",
                   group = "Topo (terrain)",
                   options = providerTileOptions(opacity = 0.85)) |>

  # Base county outlines (always on, thin)
  addPolygons(weight = 0.8,
              color = PAL$border,
              fillColor = PAL$unlit,
              fillOpacity = 0.20,
              smoothFactor = 0.5,
              label = ~NAME,
              popup = ~popup,
              group = "County boundaries") |>

  # State border — heavy dark outline, always on, drawn above county lines
  # but below peer/FWPC overlays so categorical layers still pop
  addPolylines(data = st_cast(st_union(tx), "MULTILINESTRING"),
               color = "#0f172a",
               weight = 2.6,
               opacity = 0.95,
               smoothFactor = 0.5,
               group = "State border") |>

  # RCO surface layer
  addPolygons(weight = 0.5,
              color = "#ffffff",
              fillColor = ~rco_color,
              fillOpacity = ~rco_opacity,
              smoothFactor = 0.5,
              label = ~paste0(NAME, " — RCO_max ",
                              ifelse(is.na(rco_max), "0",
                                     sprintf("%.3f", rco_max))),
              popup = ~popup,
              group = "RCO surface") |>

  # MW concentration layer
  addPolygons(weight = 0.5,
              color = "#ffffff",
              fillColor = ~mw_color,
              fillOpacity = 0.72,
              smoothFactor = 0.5,
              label = ~paste0(NAME, " — ",
                              ifelse(is.na(total_mw) | total_mw == 0,
                                     "no operating facility",
                                     paste(format(round(total_mw), big.mark=","), "MW"))),
              popup = ~popup,
              group = "MW concentration") |>

  # Fort Worth Power Core overlay (translucent purple, on top)
  addPolygons(data = tx[tx$is_fwpc, ],
              weight = 2.0,
              color = PAL$fwpc,
              fillColor = PAL$fwpc,
              fillOpacity = 0.28,
              smoothFactor = 0.5,
              label = ~paste0(NAME, " — Fort Worth Power Core site"),
              popup = ~popup,
              group = "Fort Worth Power Core network") |>

  # GCD-covered counties (subtle outline)
  addPolygons(data = tx[!is.na(tx$gcd_funding) & tx$gcd_funding >= 1, ],
              weight = 1.4,
              color = PAL$gcd,
              fillColor = NA,
              fillOpacity = 0,
              dashArray = "4 4",
              label = ~paste0(NAME, " — ", gcd_name),
              popup = ~popup,
              group = "GCD coverage") |>

  # Peer set (always on, heavy red outline — visible boundary)
  addPolygons(data = tx[tx$is_peer, ],
              weight = 3.2,
              color = PAL$peer,
              fillColor = NA,
              fillOpacity = 0,
              label = ~paste0(NAME, " (peer set)"),
              popup = ~popup,
              group = "Peer set (Parker · Hood · Hays · Hill)") |>

  # Layer controls
  addLayersControl(
    baseGroups = c("Voyager", "Positron (light)", "Topo (terrain)"),
    overlayGroups = c("RCO surface", "MW concentration",
                      "Fort Worth Power Core network", "GCD coverage",
                      "Peer set (Parker · Hood · Hays · Hill)",
                      "County boundaries"),
    options = layersControlOptions(collapsed = FALSE)
  ) |>
  # Default visibility — show RCO + peer set; hide rest
  hideGroup(c("MW concentration", "Fort Worth Power Core network",
              "GCD coverage", "County boundaries")) |>

  # Color legend
  addLegend(position = "bottomright",
            colors = c(PAL$water, PAL$power, PAL$land, PAL$peer, PAL$fwpc, PAL$gcd),
            labels = c("Water-dominant", "Power-dominant", "Land-dominant",
                       "Peer set", "Fort Worth Power Core site", "GCD coverage"),
            title = "Layers / channels",
            opacity = 0.8) |>

  # Fit view to TX
  setView(lng = -99.5, lat = 31.0, zoom = 6)

# Add page-level header/source attribution via prepended HTML
m <- htmlwidgets::prependContent(
  m,
  htmltools::div(
    style = "background:#1f2937;color:white;padding:14px 18px;font:600 18px/1.3 sans-serif",
    "Texas Data-Center Resource-Competition Overlay",
    htmltools::tags$div(
      style = "font:400 13px/1.4 sans-serif;color:#cbd5e1;margin-top:4px",
      "Interactive map. Toggle layers in the upper-right. Click any county for detail. ",
      htmltools::tags$span(style = "color:#94a3b8;font-style:italic",
        "Sources: TX Comptroller registered DCs (2026-04), Parker CAD May-2026, TCEQ Central Registry (FWPC), TWDB Nov-2019 GCD shapefile, USDA NASS 2022. Pulled 2026-06-01.")
    )
  )
)

# Save standalone HTML
OUT_HTML <- "~/rco_overlay/viz/tx_rco_interactive.html"
htmlwidgets::saveWidget(m, OUT_HTML,
                        selfcontained = TRUE,
                        title = "TX RCO — Interactive")
cat(sprintf("Wrote %s (%s)\n", OUT_HTML,
            format(file.info(path.expand(OUT_HTML))$size / 1024^2, digits=2)))
