#!/usr/bin/env Rscript
# Build OG social-share card. 1200x630 (Facebook/Twitter recommended).
# Self-contained — no dependencies beyond base R.
# Headline figure = NET LOCAL revenue lost at full buildout (county + special
# districts, Chapter 312, no state backfill). The school-district share is a
# separate state-backfilled JETI matter and is NOT counted as a local loss.

png_path <- "/Users/clbutler/Desktop/social_manifold/data_center_surface_datarun/og_card.png"
png(png_path, width = 1200, height = 630, res = 100)
par(mar = c(0,0,0,0), bg = "#fafaf7", family = "sans")
plot.new()
plot.window(xlim = c(0, 1200), ylim = c(0, 630), asp = NA, xaxs = "i", yaxs = "i")

rect(0, 0, 1200, 630, col = "#fafaf7", border = NA)

# Red accent bar on the left (signature element from the design system)
rect(0, 0, 16, 630, col = "#b91c1c", border = NA)

# Title
text(60, 530, "Parker Data", adj = c(0, 1), cex = 4.2, font = 2, col = "#1f2937")
text(60, 480, "Pro Populo",  adj = c(0, 1), cex = 2.6, font = 3, col = "#475569")

segments(60, 420, 1140, 420, col = "#d6d3d1", lwd = 1)

# Headline finding
text(60, 380, "Citizen research on the Black Mountain Power LLC",
     adj = c(0, 1), cex = 1.9, col = "#1f2937")
text(60, 340, "data-center project at FM 730 + Pearson Ranch Rd.",
     adj = c(0, 1), cex = 1.9, col = "#1f2937")

# Big number — net local revenue lost at full buildout
text(60, 285, "$364M", adj = c(0, 1), cex = 4.8, font = 2, col = "#b91c1c")
text(60, 175, "in local revenue lost to a full data-center buildout —",
     adj = c(0, 1), cex = 1.45, col = "#475569")
text(60, 147, "money the state does not replace",
     adj = c(0, 1), cex = 1.45, col = "#475569")

# Caption
text(60, 100, "Public records · sourced methodology · reproducible code",
     adj = c(0, 1), cex = 1.35, font = 3, col = "#475569")

# URL on the right
text(1140, 70, "parker-data-pro-populo.github.io",
     adj = c(1, 0), cex = 1.5, font = 2, col = "#2c7fb8")
text(1140, 38, "/data-center-surface-datarun",
     adj = c(1, 0), cex = 1.2, col = "#2c7fb8")

dev.off()
cat(sprintf("Wrote %s (%dx%d)\n", png_path, 1200, 630))
