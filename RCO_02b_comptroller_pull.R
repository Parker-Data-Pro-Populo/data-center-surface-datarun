#!/usr/bin/env Rscript
# RCO_02b_comptroller_pull.R — fetch the Texas Comptroller's public roster of
# Registered Qualifying Data Centers + Large Data Center Projects and emit rows
# in the datacenter_sites_manual template schema.
#
# Free, official OPERATING spine (~121 facilities as of 2026-04). MISSES:
# announced/queued projects, Chapter-313 facilities, sub-threshold sites.
#
# REWRITTEN to use only base R + jsonlite + data.table (no rvest/httr2/xml2).
# Reason: R 4.6 on macOS arm64 has no CRAN binaries yet and Homebrew libxml2
# v16 breaks the xml2 source build. Base R regex is sufficient — the
# Comptroller HTML tables are stable and well-structured (<th scope="row">
# for the DC name followed by 8 <td> cells).

source("RCO_00_config.R")
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

URL <- "https://comptroller.texas.gov/taxes/data-centers/data-center-lists.php"

# ── 1. Fetch + parse the HTML tables (base R) ───────────────────────────────
html_path <- file.path(tempdir(), "comptroller.html")
download.file(URL, html_path, quiet = TRUE)
html <- paste(readLines(html_path, warn = FALSE), collapse = "\n")

# Extract every <table class="data-left scroll"> ... </table> block.
table_blocks <- regmatches(html, gregexpr(
  '(?s)<table class="data-left scroll">.*?</table>', html, perl = TRUE))[[1]]
message("table blocks found: ", length(table_blocks))

# Strip a single HTML tag/entity from cell text.
clean_cell <- function(s) {
  s <- gsub("<[^>]+>", "", s)            # drop tags
  s <- gsub("&amp;",  "&", s, fixed = TRUE)
  s <- gsub("&nbsp;", " ", s, fixed = TRUE)
  s <- gsub("&#039;", "'", s, fixed = TRUE)
  s <- gsub("&quot;", '"', s, fixed = TRUE)
  s <- gsub("\\s+", " ", s)
  trimws(s)
}

parse_row <- function(tr) {
  # First column comes from <th scope="row">…</th>, rest from <td>…</td>.
  th <- regmatches(tr, regexpr('(?s)<th[^>]*>.*?</th>', tr, perl = TRUE))
  th <- if (length(th)) clean_cell(th) else ""
  tds <- regmatches(tr, gregexpr('(?s)<td[^>]*>.*?</td>', tr, perl = TRUE))[[1]]
  tds <- vapply(tds, clean_cell, character(1))
  c(th, tds)
}

parse_table <- function(tbl) {
  rows <- regmatches(tbl, gregexpr('(?s)<tr>.*?</tr>', tbl, perl = TRUE))[[1]]
  parsed <- lapply(rows, parse_row)
  ncols  <- max(lengths(parsed))
  parsed <- lapply(parsed, function(r) { length(r) <- ncols; r })
  m <- do.call(rbind, parsed)
  as.data.table(m)
}

raw_list <- lapply(table_blocks, parse_table)
raw <- rbindlist(raw_list, fill = TRUE, use.names = FALSE)

# Column scheme on the live page (verified 2026-05-31):
#   Data Center | Effective Date | Owner Name | Owner Reg # |
#   Occupant Name | Occupant Reg # | Operator Name | Operator Reg # | Exemption End Date
cols9 <- c("dc_name","eff_date","owner","owner_reg","occupant","occupant_reg",
           "operator","operator_reg","exempt_end")
setnames(raw, names(raw), cols9[seq_len(ncol(raw))])

# Drop header rows (parser will have caught the <thead> <tr> too) and blanks.
raw <- raw[!is.na(dc_name) & dc_name != "" & dc_name != "Data Center"]
message("comptroller rows parsed: ", nrow(raw))

# ── 2. Geocode the address embedded in the name -> county FIPS (base R) ─────
# Census one-line geocoder, free + keyless. We hit it serially with a brief
# politeness pause; ~120 calls so ~30-60s total.
geocode_county <- function(addr) {
  if (is.na(addr) || !nzchar(addr)) return(NA_character_)
  q <- paste0("https://geocoding.geo.census.gov/geocoder/geographies/onelineaddress",
              "?address=", URLencode(addr, reserved = TRUE),
              "&benchmark=Public_AR_Current",
              "&vintage=Current_Current&format=json")
  resp <- tryCatch(fromJSON(q, simplifyVector = FALSE), error = function(e) NULL)
  m <- tryCatch(resp$result$addressMatches[[1]]$geographies$Counties[[1]],
                error = function(e) NULL)
  if (is.null(m)) return(NA_character_)
  paste0(m$STATE, m$COUNTY)
}

# Heuristic: many DC names start with a street address ("3301 Hibbetts Road ...").
raw[, addr_guess := regmatches(dc_name,
       regexpr("^\\d+\\s+[A-Za-z0-9 .]+", dc_name))[
       match(seq_len(.N), seq_len(.N))]]
# Robust per-row extraction (regmatches loses NA positions on vector input).
addr_extract <- function(s) {
  m <- regexpr("^\\d+\\s+[A-Za-z0-9 .]+", s)
  if (m == -1L) NA_character_ else regmatches(s, m)
}
raw[, addr_guess := vapply(dc_name, addr_extract, character(1))]

message("addresses to geocode: ", sum(!is.na(raw$addr_guess)))
raw[, county_fips := vapply(addr_guess, function(a) {
  v <- geocode_county(a); Sys.sleep(0.25); v
}, character(1))]
n_geo <- raw[!is.na(county_fips), .N]
message("geocoded to county: ", n_geo, "/", nrow(raw),
        " (rest need CAD lookup or manual)")

# ── 3. Map to the manual template schema ────────────────────────────────────
out <- raw[, .(
  site_id      = sprintf("COMP-%03d", .I),
  name         = dc_name,
  operator     = fifelse(!is.na(operator) & operator != "", operator, owner),
  county_fips  = county_fips,
  lat          = NA_real_, lon = NA_real_,
  status       = "operating",            # certified ⇒ committed; verify vs construction
  status_date  = eff_date,
  mw           = NA_real_,
  cooling      = "unknown",
  water_source = "unknown",
  power_source = "unknown",
  confidence   = "high",                 # official registry
  source_url   = URL,
  notes        = sprintf("owner=%s; occupant=%s; operator=%s; addr_guess=%s; verify county/MW",
                         owner, occupant, operator, addr_guess)
)]

fwrite(out, file.path(OUT, "datacenter_sites_comptroller.csv"))
message("wrote ", file.path(OUT, "datacenter_sites_comptroller.csv"),
        " (", nrow(out), " rows). Merge with announced/queued rows from agendas+press,",
        " then feed RCO_02 as datacenter_sites_manual.csv.")
