#!/usr/bin/env Rscript
# build_county_gcd_join.R — spatial-join TX counties to the TWDB Nov-2019 GCD
# layer, producing a complete county→GCD coverage table for all 254 TX counties.
# Output: county_gcd_join_2019.csv (replaces the hand-coded RCO_03 entries)

suppressPackageStartupMessages({
  library(sf); library(data.table)
})

SF_DIR <- "/Users/clbutler/Desktop/Parker County Exploration/R-server_analysis/water_data/shapefiles/twdb_layers"

gcd <- st_read(file.path(SF_DIR, "TWDB_GCD_NOV2019.shp"), quiet = TRUE)
# Some districts may have invalid geometry — fix
gcd <- st_make_valid(gcd)

# ── TX county polygons via TIGER (already locally cached by tigris) ─────────
# We don't have tigris on the laptop; pull from cached output instead.
# Build TX county set from the RCO surface CSV (FIPS list) + a TIGER cache if available
# Alternative: use the geographic-extent approach — get TX boundary then sliver per county.
# For now, use the parcel_panel-style county FIPS via a TX-only TIGER cb_20m file.
#
# Easiest path: use the rco_overlay_local outputs that already have all TX FIPS,
# and reproject the GCD to compute area fractions per FIPS in a separate step.
#
# But for the FIRST cut, we just need: for each county, list the GCDs that intersect.
# To do that we need county polygons. Let me use the tigris cache directory if available.

# Try the laptop's cached tigris files
tigris_cache <- Sys.getenv("TIGRIS_CACHE_DIR", "~/Library/Application Support/tigris")
tigris_cache <- normalizePath(tigris_cache, mustWork = FALSE)
cb_files <- list.files(tigris_cache, pattern = "cb_.*us_county_20m\\.shp$",
                       recursive = TRUE, full.names = TRUE)
if (length(cb_files) == 0) {
  # Fall back: try to download minimally via raw URL
  cat("No tigris cache found locally. Skipping spatial join until counties available.\n")
  cat("Re-running this from worker-active (where tigris is cached) instead.\n")
  quit(status = 1)
}

cty <- st_read(cb_files[1], quiet = TRUE)
tx  <- cty[cty$STATEFP == "48", ]
tx$fips <- paste0(tx$STATEFP, tx$COUNTYFP)

# Reproject both to a common metric CRS for accurate area
crs_tx <- 3081  # Texas Centric Lambert (NAD83)
tx_p  <- st_transform(tx,  crs_tx)
gcd_p <- st_transform(gcd, crs_tx)

# ── Spatial intersection ───────────────────────────────────────────────────
# For each county, find intersecting GCDs and the area of intersection.
cat("Computing county × GCD intersections (", nrow(tx_p), " counties × ",
    nrow(gcd_p), " districts)...\n", sep="")

ix <- st_intersects(tx_p, gcd_p)
results <- vector("list", nrow(tx_p))
for (i in seq_len(nrow(tx_p))) {
  hits <- ix[[i]]
  if (length(hits) == 0) {
    results[[i]] <- data.table(
      fips = tx_p$fips[i], county = tx_p$NAME[i],
      gcd_name = NA_character_, gcd_short = NA_character_,
      gcd_enabling = NA_character_, gcd_est_date = NA_character_,
      county_area_km2 = as.numeric(st_area(tx_p[i,]))/1e6,
      coverage_km2 = 0, coverage_pct = 0
    )
    next
  }
  # Compute intersection area per overlapping GCD
  county_geom <- st_geometry(tx_p[i,])
  county_area <- as.numeric(st_area(tx_p[i,]))/1e6
  rows <- list()
  for (j in hits) {
    inter <- suppressWarnings(st_intersection(county_geom, st_geometry(gcd_p[j,])))
    area_km2 <- as.numeric(sum(st_area(inter)))/1e6
    if (area_km2 > 0.5) {  # ignore slivers <0.5 km²
      rows[[length(rows)+1]] <- data.table(
        fips = tx_p$fips[i], county = tx_p$NAME[i],
        gcd_name     = gcd_p$DISTNAME[j],
        gcd_short    = gcd_p$SHORTNAM[j],
        gcd_enabling = gcd_p$ENABLACT[j],
        gcd_est_date = as.character(gcd_p$EST_DATE[j]),
        county_area_km2 = county_area,
        coverage_km2 = area_km2,
        coverage_pct = 100 * area_km2 / county_area
      )
    }
  }
  results[[i]] <- if (length(rows)) rbindlist(rows) else
    data.table(fips = tx_p$fips[i], county = tx_p$NAME[i],
               gcd_name = NA_character_, gcd_short = NA_character_,
               gcd_enabling = NA_character_, gcd_est_date = NA_character_,
               county_area_km2 = county_area, coverage_km2 = 0, coverage_pct = 0)
}

j <- rbindlist(results, fill = TRUE)
fwrite(j, "county_gcd_join_2019.csv")

cat("\n=== Summary ===\n")
covered <- j[!is.na(gcd_name), .(any_gcd = TRUE), by = fips]
cat("TX counties:", uniqueN(j$fips), "\n")
cat("Counties with at least one GCD: ", nrow(covered), "\n")
cat("Counties uncovered:             ", uniqueN(j$fips) - nrow(covered), "\n")

cat("\n=== Counties without ANY GCD coverage (uncovered) ===\n")
print(j[is.na(gcd_name), .(fips, county)])

cat("\n=== Counties with multiple GCDs (overlap regions) ===\n")
multi <- j[!is.na(gcd_name), .N, by = fips][N > 1]
print(merge(multi, unique(j[!is.na(gcd_name), .(fips, county)]), by = "fips"))
