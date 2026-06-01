#!/usr/bin/env Rscript
# RCO_02b_nass.R — NASS QuickStats county cropland pull (land channel).
# Adds `cropland_share_of_land` (cropland_acres / county_land_acres) to the
# land-channel composite. Reads NASS_API_KEY from .Renviron.

source("RCO_00_config.R")
suppressPackageStartupMessages({
  library(httr2); library(jsonlite); library(sf); library(tigris)
})
options(tigris_use_cache = TRUE)

key <- Sys.getenv("NASS_API_KEY")
if (!nzchar(key)) stop("NASS_API_KEY missing")

# Census of Ag 2022, county-level cropland acres. Pull state-by-state to stay
# under the 50k-records ceiling and to keep responses small.
state_alphas <- c("AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID",
  "IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE",
  "NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN",
  "TX","UT","VT","VA","WA","WV","WI","WY")

pull_state <- function(sa) {
  q <- list(key=key, source_desc="CENSUS", year="2022",
            agg_level_desc="COUNTY", state_alpha=sa,
            commodity_desc="AG LAND",
            short_desc="AG LAND, CROPLAND - ACRES",
            domain_desc="TOTAL", format="JSON")
  r <- tryCatch(
    request("https://quickstats.nass.usda.gov/api/api_GET/") |>
      req_url_query(!!!q) |> req_timeout(60) |> req_perform(),
    error = function(e) { message(sa, ": ", conditionMessage(e)); NULL })
  if (is.null(r) || resp_status(r) >= 400) return(NULL)
  d <- tryCatch(fromJSON(resp_body_string(r))$data, error = function(e) NULL)
  if (is.null(d) || !length(d)) return(NULL)
  setDT(d)
  d[, fips := paste0(state_fips_code, county_code)]
  d[, cropland_acres := as.numeric(gsub(",|\\(D\\)|\\(Z\\)", "", Value))]
  d[, .(fips, cropland_acres)]
}

message("Pulling NASS cropland for ", length(state_alphas), " states ...")
parts <- lapply(state_alphas, function(sa){ x <- pull_state(sa)
  if (!is.null(x)) message("  ", sa, ": ", nrow(x), " counties"); x })
nass <- rbindlist(Filter(Negate(is.null), parts))
message("NASS cropland total: ", nrow(nass), " county rows")

# Denominator: county land area in acres from TIGER (ALAND is in m^2).
cnty <- counties(cb=TRUE, resolution="20m", year=2023, progress_bar=FALSE)
cnty_dt <- as.data.table(st_drop_geometry(cnty))[
  , .(fips = paste0(STATEFP, COUNTYFP),
      land_area_acres = as.numeric(ALAND) * 0.000247105381)]

land_extras <- merge(nass, cnty_dt, by="fips", all.x=TRUE)
land_extras[, cropland_share_of_land :=
              ifelse(!is.na(land_area_acres) & land_area_acres > 0,
                     cropland_acres / land_area_acres, NA_real_)]
land_extras[!is.na(cropland_share_of_land) & cropland_share_of_land > 1,
            cropland_share_of_land := 1]

fwrite(land_extras, file.path(OUT, "rco_nass.csv"))
message("Wrote ", file.path(OUT, "rco_nass.csv"),
        "  (", nrow(land_extras), " counties, ",
        sum(!is.na(land_extras$cropland_share_of_land)), " with share)")
