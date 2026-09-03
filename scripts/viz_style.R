#!/usr/bin/env Rscript
# viz_style.R — shared design system for the RCO + Black Mountain deck.
# Source this from any chart script; provides palette, basemap, layer helpers,
# and a halo-text function for legible labels over any background.

suppressPackageStartupMessages({
  library(sf); library(data.table); library(png)
})

# ── Palette (one definition reused everywhere) ─────────────────────────────
PAL <- list(
  water  = "#2c7fb8",
  power  = "#e6783c",
  land   = "#5da75a",
  peer   = "#b91c1c",
  fwpc   = "#6d28d9",
  gcd    = "#475569",
  unlit  = "#f0e9dd",
  border = "#7a7367",
  title  = "#1f2937",
  muted  = "#475569",
  source = "#7a7367"
)

# ── Basemap (CARTO Voyager tiles, Z=7, TX bbox in EPSG:3857) ─────────────────
# Look for the basemap where it actually lives (repo first), not only on the
# machine the June run happened on.
BASEMAP_PATH <- local({
  cand <- c(Sys.getenv("RCO_BASEMAP", unset = NA_character_),
            "scripts/basemap_carto_voyager_tx.png",
            "../scripts/basemap_carto_voyager_tx.png",
            "~/rco_run/basemap_carto_voyager_tx.png")
  cand <- cand[!is.na(cand)]
  hit  <- cand[file.exists(path.expand(cand))]
  if (!length(hit)) stop("basemap PNG not found; set RCO_BASEMAP")
  path.expand(hit[1])
})
# Web Mercator tile bbox for the assembled basemap
# Z=7, X=[26..30], Y=[50..54], extended by 1 to right & bottom (montage geometry)
.R_EARTH <- 6378137
.tile2x_mer <- function(x, z) (x / 2^z) * 2 * pi * .R_EARTH - pi * .R_EARTH
.tile2y_mer <- function(y, z) (1 - 2 * y / 2^z) * pi * .R_EARTH

BASEMAP_BBOX_3857 <- c(
  xmin = .tile2x_mer(26, 7),
  xmax = .tile2x_mer(31, 7),       # one past the last tile
  ymin = .tile2y_mer(55, 7),       # one past the bottom tile (smaller y_mer)
  ymax = .tile2y_mer(50, 7)
)

.basemap_cache <- NULL
get_basemap <- function() {
  if (is.null(.basemap_cache)) {
    img <- png::readPNG(BASEMAP_PATH)
    # img is array [H, W, 3]; build cache
    .basemap_cache <<- img
  }
  .basemap_cache
}

# Blend basemap toward white to soften it (alpha = how strongly the tile shows)
blend_basemap <- function(img, alpha = 0.30) {
  # img values are 0..1
  1 - (1 - img) * alpha
}

# ── Map canvas setup ────────────────────────────────────────────────────────
init_tx_map <- function(title, subtitle = NULL, source_text = NULL,
                        basemap_alpha = 0.32, margin = c(3.5, 1, 5.5, 1)) {
  par(mar = margin, family = "sans")
  bbox <- BASEMAP_BBOX_3857
  plot.new()
  plot.window(xlim = c(bbox["xmin"], bbox["xmax"]),
              ylim = c(bbox["ymin"], bbox["ymax"]),
              asp = 1, xaxs = "i", yaxs = "i")
  raster <- blend_basemap(get_basemap(), basemap_alpha)
  # rasterImage() takes (image, xleft, ybottom, xright, ytop). Until 2026-09-03 this
  # passed ymax as ybottom and ymin as ytop, which drew every basemap upside down —
  # mirrored place labels, Oklahoma at the bottom. The polygons were always correct.
  rasterImage(raster, bbox["xmin"], bbox["ymin"], bbox["xmax"], bbox["ymax"])
  # Title
  title(main = title, cex.main = 1.45, line = 3, col.main = PAL$title)
  if (!is.null(subtitle))
    mtext(subtitle, side = 3, line = 1.2, cex = 0.95, font = 3, col = PAL$muted)
  if (!is.null(source_text))
    mtext(source_text, side = 1, line = 2.5, cex = 0.7, col = PAL$source, font = 3)
}

# ── Halo text — readable over any fill ─────────────────────────────────────
halo_text <- function(x, y, labels, cex = 0.88, col = PAL$title,
                      font = 1, halo_col = "white", halo_w = 1.2) {
  # halo_w is in CHARACTER units; we use offsets in user coords by converting
  usr <- par("usr"); pin <- par("pin")
  # 8-direction halo
  dx <- halo_w / pin[1] * diff(usr[1:2]) * 0.0015
  dy <- halo_w / pin[2] * diff(usr[3:4]) * 0.0015
  for (theta in seq(0, 2*pi, length.out = 9)[-1]) {
    text(x + dx * cos(theta), y + dy * sin(theta), labels,
         cex = cex, col = halo_col, font = font)
  }
  text(x, y, labels, cex = cex, col = col, font = font)
}

# ── Layer helpers (always called AFTER init_tx_map) ────────────────────────
draw_unlit <- function(tx_3857, alpha = 0.25) {
  # Tile a translucent warm cream over all counties so the basemap doesn't
  # punch through the political-boundary message
  col <- paste0(PAL$unlit, sprintf("%02X", round(alpha * 255)))
  plot(st_geometry(tx_3857), col = col, border = NA, add = TRUE)
}

draw_lit <- function(tx_3857,
                     value_col = "rco_max",
                     channel_col = "dominant_channel",
                     min_alpha = 0.40, max_alpha = 0.75) {
  if (!value_col %in% names(tx_3857)) return(invisible())
  v <- tx_3857[[value_col]]
  lit_idx <- which(!is.na(v) & v > 0)
  if (!length(lit_idx)) return(invisible())
  rng <- range(v[lit_idx], na.rm = TRUE)
  for (i in lit_idx) {
    ch <- tx_3857[[channel_col]][i]
    base <- switch(ch %||% "x",
                   water = PAL$water, power = PAL$power, land = PAL$land,
                   PAL$unlit)
    frac <- if (diff(rng) > 0) (v[i] - rng[1]) / diff(rng) else 1
    a <- min_alpha + (max_alpha - min_alpha) * frac
    col <- paste0(base, sprintf("%02X", round(a * 255)))
    plot(st_geometry(tx_3857[i, ]), col = col, border = NA, add = TRUE)
  }
}
`%||%` <- function(a, b) if (length(a) && !is.na(a)) a else b

draw_county_lines <- function(tx_3857, lwd = 0.9, col = PAL$border) {
  plot(st_geometry(tx_3857), col = NA, border = col, lwd = lwd, add = TRUE)
}

draw_peer <- function(tx_3857, peer_fips, lwd = 2.8) {
  p <- tx_3857[tx_3857$fips %in% peer_fips, ]
  if (nrow(p))
    plot(st_geometry(p), col = NA, border = PAL$peer, lwd = lwd, add = TRUE)
}

draw_fwpc <- function(tx_3857, fwpc_fips, fill_alpha = 0.22, lwd = 2.0) {
  f <- tx_3857[tx_3857$fips %in% fwpc_fips, ]
  if (!nrow(f)) return(invisible())
  fill <- paste0(PAL$fwpc, sprintf("%02X", round(fill_alpha * 255)))
  plot(st_geometry(f), col = fill, border = PAL$fwpc, lwd = lwd, add = TRUE)
}

draw_gcd_outline <- function(tx_3857, gcd_dt, lwd = 0.9) {
  covered <- tx_3857[tx_3857$fips %in% gcd_dt[gcd_funding >= 1, fips], ]
  if (!nrow(covered)) return(invisible())
  plot(st_geometry(covered), col = NA, border = PAL$gcd,
       lwd = lwd, lty = 3, add = TRUE)
}

# Label storied counties with halo for legibility
draw_storied_labels <- function(tx_3857, label_dt, cex = 0.85) {
  for (i in seq_len(nrow(label_dt))) {
    p <- tx_3857[tx_3857$fips == label_dt$fips[i], ]
    if (!nrow(p)) next
    ct <- suppressWarnings(st_centroid(st_geometry(p)))
    xy <- st_coordinates(ct)
    halo_text(xy[1], xy[2], label_dt$label[i], cex = cex,
              font = ifelse(!is.null(label_dt$bold) && label_dt$bold[i], 2, 1),
              col = ifelse(!is.null(label_dt$color) && !is.na(label_dt$color[i]),
                           label_dt$color[i], PAL$title))
  }
}

# Categorical legend (consistent style — bottom-left, no box)
draw_legend <- function(items, position = "bottomleft", cex = 0.88,
                        title = NULL, inset = c(0.02, 0.02)) {
  legend(position,
         legend = items$legend,
         fill   = items$fill,
         border = items$border,
         pch    = items$pch,
         pt.bg  = items$pt_bg,
         lwd    = items$lwd,
         lty    = items$lty,
         density= items$density,
         angle  = items$angle,
         bty    = "n",
         cex    = cex,
         title  = title,
         inset  = inset)
}
