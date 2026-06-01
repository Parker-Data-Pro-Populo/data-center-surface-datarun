#!/usr/bin/env Rscript
# RCO_02_acquire_external.R — Layers the catalog does not carry.
# These require live web access + (for siting) some manual curation. Run under
# Claude Code on worker-active. Each block writes a CSV to OUT/ and degrades
# gracefully to the hand-coded fallback (RCO_03) if a source can't be resolved.

source("RCO_00_config.R")
suppressPackageStartupMessages({
  library(httr2); library(jsonlite)
  has_sf <- requireNamespace("sf", quietly = TRUE)
})

# ============================================================================
# LAYER B — Data-center siting / demand (force D)
# ============================================================================
# There is no clean county-level API. The ERCOT large-load queue is regional
# and noisy ("phantom" multi-filings; no standardized transparency until the
# SB6 / PUC Project 58481 rules land ~Dec 2026). Strategy = triangulate:
#   (1) operating + permitted facilities from a curated manual CSV, and
#   (2) queued MW from ERCOT regional data, confidence-flagged.
#
# TODO(Code): populate datacenter_sites_manual.csv from Baxtel / DataCenterMap
# / local permit filings / news. Schema:
#   name, status{operating|permitted|announced|queued}, lat, lon,
#   county_fips (optional if lat/lon given), mw, cooling{evap|closed|air|unknown},
#   source_url, confidence{high|med|low}
manual_path <- file.path(OUT, "datacenter_sites_manual.csv")
if (!file.exists(manual_path)) {
  fwrite(data.table(name=character(), status=character(), lat=numeric(),
                    lon=numeric(), county_fips=character(), mw=numeric(),
                    cooling=character(), source_url=character(),
                    confidence=character()), manual_path)
  message("WROTE EMPTY ", manual_path, " — Code must populate it.")
}
sites <- fread(manual_path)

# Geocode lat/lon -> county FIPS where county not supplied (needs a county
# polygon set; TIGER counties). TODO(Code): point-in-polygon with sf if needed.
if (has_sf && nrow(sites) && "lat" %in% names(sites)) {
  # placeholder: leave county_fips as-is; implement TIGER join under Code.
  message("sf available — implement point-in-polygon county assignment if lat/lon used.")
}

# Roll up to county-level force series.
D <- sites[!is.na(county_fips) & county_fips != "", .(
  dc_count_operating = sum(status %in% c("operating","permitted")),
  dc_mw_operating    = sum(mw[status %in% c("operating","permitted")], na.rm=TRUE),
  dc_mw_queued       = sum(mw[status %in% c("queued","announced")],   na.rm=TRUE)
), by = .(fips = county_fips)]
fwrite(D, file.path(OUT, "rco_force_D.csv"))
message("force D rolled up for ", nrow(D), " counties (from manual sites).")

# ============================================================================
# LAYER C-water — Aquifer, PGMA, GCD boundaries (TWDB)
# ============================================================================
# Authoritative: Texas Water Development Board GIS + TAGD GCD index.
# TODO(Code) resolve current endpoints (TWDB ArcGIS REST / download portal):
#   - Major & Minor Aquifers (polygons)
#   - Groundwater Conservation District boundaries
#   - Priority Groundwater Management Areas (PGMA)
# Then spatial-join TX county centroids (or area-weighted) to each.
# Until resolved, RCO_03 hand-coded table is the fallback for the working set.
twdb_aquifer_url <- Sys.getenv("RCO_TWDB_AQUIFER_URL", "")  # VERIFY/TODO
twdb_gcd_url     <- Sys.getenv("RCO_TWDB_GCD_URL", "")      # VERIFY/TODO
twdb_pgma_url    <- Sys.getenv("RCO_TWDB_PGMA_URL", "")     # VERIFY/TODO

water_ctx <- NULL
if (has_sf && nzchar(twdb_gcd_url)) {
  message("sf + TWDB URLs present — implement download + county spatial join.")
  # water_ctx <- <sf pipeline writing fips, aquifer, pgma, gcd_name>
}
if (is.null(water_ctx)) {
  message("TWDB live pull not run; using hand-coded RCO_03 fallback downstream.")
}

# ============================================================================
# LAYER C-land — Ag-land conversion exposure (USDA NASS Quick Stats)
# ============================================================================
# Complements QCEW ag-employment + BEA farm-proprietor share already pulled.
# TODO(Code): set NASS_API_KEY (free, quickstats.nass.usda.gov). County-level
# cropland / farmland-acreage share is the target.
nass_key <- Sys.getenv("NASS_API_KEY", "")
if (nzchar(nass_key)) {
  message("NASS key present — implement Quick Stats county cropland pull.")
  # request("https://quickstats.nass.usda.gov/api/api_GET/") |> ...
} else {
  message("NASS key absent — land channel uses QCEW+BEA only for first pass.")
}

message("RCO_02 done. Resolve TODOs marked above under Code for full layers.")
