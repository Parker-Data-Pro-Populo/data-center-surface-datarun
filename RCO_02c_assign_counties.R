#!/usr/bin/env Rscript
# RCO_02c_assign_counties.R — assign county_fips to the Comptroller scrape
# by pattern-matching facility/operator names. Conservative: only assigns
# where the name unambiguously implies a city/operator with a known TX site.
#
# Inputs:   output_local/datacenter_sites_comptroller.csv
# Outputs:  output_local/datacenter_sites_manual.csv      (canonical input for RCO_02)
#           output_local/datacenter_sites_unassigned.csv  (the still-ambiguous rows)
#
# Confidence after assignment:
#   high  — name contains a unique city (e.g. "Microsoft San Antonio SAT14")
#   med   — operator-or-prefix pattern (e.g. ALE-prefix = Amazon Allen)
#   low   — best-guess from operator/cluster (e.g. bare "DFW 1" -> Dallas)
#   NA    — left unassigned for manual augmentation

source("RCO_00_config.R")
suppressPackageStartupMessages(library(data.table))

infile  <- file.path(OUT, "datacenter_sites_comptroller.csv")
d <- fread(infile)
n0 <- nrow(d)
# fread infers all-NA columns as logical; force the ones we write into to character.
for (col in c("county_fips","confidence","assign_confidence","assign_pattern"))
  if (col %in% names(d)) set(d, j=col, value=as.character(d[[col]])) else
                         set(d, j=col, value=NA_character_)

# ── City / phrase → (county_fips, confidence, county_name) ──────────────────
# Order matters: more specific patterns first.
rules <- list(
  # FOCUS / PEER SET (project priority — none expected in registry but check)
  list(re = "Weatherford|Aledo|Annetta|Springtown|Hudson Oaks|Willow Park",
       fips = "48367", cnty = "Parker",     conf = "high"),
  list(re = "Granbury",
       fips = "48221", cnty = "Hood",       conf = "high"),
  list(re = "Kyle|San Marcos|Buda|Wimberley|Dripping Springs",
       fips = "48209", cnty = "Hays",       conf = "high"),

  # Lancium clusters (specific city in name)
  list(re = "Lancium Abilene|Abilene Clean Campus|Abilene Data Center",
       fips = "48441", cnty = "Taylor",     conf = "high"),
  list(re = "Lancium Childress|Childress",
       fips = "48075", cnty = "Childress",  conf = "high"),
  list(re = "Fort Stockton",
       fips = "48371", cnty = "Pecos",      conf = "high"),
  list(re = "Sweetwater|Stargate",
       fips = "48353", cnty = "Nolan",      conf = "high"),

  # Lonestar Taproot LLC — West Texas oil-patch sites
  list(re = "Pyote",
       fips = "48475", cnty = "Ward",       conf = "high"),
  list(re = "Tarbush|Wickett|Monahans",
       fips = "48475", cnty = "Ward",       conf = "high"),
  list(re = "Crusoe.*Stanton|Stanton",
       fips = "48317", cnty = "Martin",     conf = "high"),

  # Major metro cities — explicit
  list(re = "San Antonio|SAT\\d+|Microsoft.*Texas|Schertz|Selma|Universal City",
       fips = "48029", cnty = "Bexar",      conf = "high"),
  list(re = "Austin Data Center|AUS\\d+|Tesla|Giga Texas|Pflugerville",
       fips = "48453", cnty = "Travis",     conf = "high"),
  list(re = "Round Rock|Cedar Park|Williamson",
       fips = "48491", cnty = "Williamson", conf = "high"),
  list(re = "Houston|Hockley|Katy|Cinco|Spring|Tomball|IAH\\d*",
       fips = "48201", cnty = "Harris",     conf = "high"),
  list(re = "Sugar Land|Fort Bend",
       fips = "48157", cnty = "Fort Bend",  conf = "high"),
  list(re = "Fort Worth|Arlington|Mansfield|Grand Prairie|Haltom",
       fips = "48439", cnty = "Tarrant",    conf = "high"),
  list(re = "Lewisville|Flower Mound|Lake Dallas|Argyle",
       fips = "48121", cnty = "Denton",     conf = "high"),
  list(re = "Plano|Frisco|McKinney|Allen|Richardson|ALE\\d+",
       fips = "48085", cnty = "Collin",     conf = "high"),
  list(re = "Garland|Carrollton|Mesquite|Irving|Cedar Hill|Duncanville",
       fips = "48113", cnty = "Dallas",     conf = "high"),
  list(re = "Red Oak|Ennis|Waxahachie|Midlothian|Ellis County",
       fips = "48139", cnty = "Ellis",      conf = "high"),
  list(re = "Cleburne|Burleson|Joshua|Johnson County",
       fips = "48251", cnty = "Johnson",    conf = "high"),
  list(re = "Waco|McLennan",
       fips = "48309", cnty = "McLennan",   conf = "high"),
  list(re = "Temple|Belton|Killeen|Bell County",
       fips = "48027", cnty = "Bell",       conf = "high"),
  list(re = "Sherman|Denison|Grayson",
       fips = "48181", cnty = "Grayson",    conf = "high"),
  list(re = "Bastrop",
       fips = "48021", cnty = "Bastrop",    conf = "high"),
  list(re = "Bryan|College Station|Brazos County",
       fips = "48041", cnty = "Brazos",     conf = "high"),
  list(re = "El Paso",
       fips = "48141", cnty = "El Paso",    conf = "high"),
  list(re = "Lubbock",
       fips = "48303", cnty = "Lubbock",    conf = "high"),
  list(re = "Corpus|Nueces",
       fips = "48355", cnty = "Nueces",     conf = "high"),
  list(re = "Midland",
       fips = "48329", cnty = "Midland",    conf = "high"),
  list(re = "Odessa",
       fips = "48135", cnty = "Ector",      conf = "high"),
  list(re = "Amarillo|Potter County",
       fips = "48375", cnty = "Potter",     conf = "high"),

  # Operator-pattern fallbacks
  list(re = "DFW\\s*\\d+|DFW\\s*[IVX]+|Stream DFW",  # "DFW 9", "DFW VIII"
       fips = "48113", cnty = "Dallas",     conf = "low"),
  list(re = "Cipher Black Pearl|Gulf Horizon|^SF HOU|Cutten",
       fips = "48201", cnty = "Harris",     conf = "med"),
  list(re = "Compass Datacenters",
       fips = "48085", cnty = "Collin",     conf = "low"),
  list(re = "NTT Global.*Dallas",
       fips = "48113", cnty = "Dallas",     conf = "high"),

  # ── Second-pass additions (from unassigned-list review 2026-05-31) ────
  # Broader SAT/AUS patterns (catches "(SAT 15-17)", "Switch AUS 4")
  list(re = "\\bSAT\\s*\\d",
       fips = "48029", cnty = "Bexar",      conf = "high"),
  list(re = "\\bAUS\\s*\\d",
       fips = "48453", cnty = "Travis",     conf = "high"),

  # Explicit county/city catches from unassigned set
  list(re = "Rellis|Texas A.?M",
       fips = "48041", cnty = "Brazos",     conf = "high"),
  list(re = "Hutto",
       fips = "48491", cnty = "Williamson", conf = "high"),
  list(re = "Denton Data Center|Denton County|Hackberry",
       fips = "48121", cnty = "Denton",     conf = "high"),
  list(re = "Borden County",
       fips = "48033", cnty = "Borden",     conf = "high"),
  list(re = "Milam County|Rockdale|Whinstone",
       fips = "48331", cnty = "Milam",      conf = "high"),
  list(re = "Pecos County|USBTC Pecos|Poolside.*Pecos",
       fips = "48371", cnty = "Pecos",      conf = "high"),
  list(re = "Barber Lake",
       fips = "48335", cnty = "Mitchell",   conf = "high"),
  list(re = "Lancium.*Turkey|Clean Campus.*Turkey",
       fips = "48191", cnty = "Hall",       conf = "high"),
  list(re = "Abernathy",
       fips = "48189", cnty = "Hale",       conf = "high"),
  list(re = "Corsicana|Navarro County",
       fips = "48349", cnty = "Navarro",    conf = "high"),
  list(re = "Alamo Data Center",                   # Google Alamo = San Antonio
       fips = "48029", cnty = "Bexar",      conf = "high"),
  list(re = "Lancaster",                           # Lancaster TX = Dallas Co
       fips = "48113", cnty = "Dallas",     conf = "high"),
  list(re = "Freestone Data Center|Freestone County",
       fips = "48161", cnty = "Freestone",  conf = "med"),

  # Vantage TX-numbered facilities — Plano/Frisco campus complex
  list(re = "Vantage.*TX\\s*\\d|TX\\s?\\d+\\s*Data Center|TX\\s?\\d{3}\\s*Data Center",
       fips = "48085", cnty = "Collin",     conf = "low"),

  # Independence DC (Core42 = MS/G42 JV) — public reporting puts it in San Antonio
  list(re = "Independence Data Center|Core42",
       fips = "48029", cnty = "Bexar",      conf = "med"),

  # Final third-pass catches
  list(re = "\\bAustin\\b",                        # "SDC - Austin Tandem"
       fips = "48453", cnty = "Travis",     conf = "med"),
  list(re = "Bosque",                              # C1 Bosque I/II
       fips = "48035", cnty = "Bosque",     conf = "high"),
  list(re = "Fort Haskell|\\bHaskell\\b",
       fips = "48207", cnty = "Haskell",    conf = "med")
)

# ── Apply rules ─────────────────────────────────────────────────────────────
search_text <- paste(d$name, d$operator, d$notes, sep = " | ")
for (r in rules) {
  mask <- is.na(d$county_fips) & grepl(r$re, search_text, ignore.case = TRUE,
                                       perl = TRUE)
  if (any(mask)) {
    d[mask, `:=`(county_fips        = r$fips,
                 assign_confidence  = r$conf,
                 assign_pattern     = r$re,
                 confidence         = r$conf)]
  }
}

n_assigned   <- sum(!is.na(d$county_fips))
n_unassigned <- n0 - n_assigned
message(sprintf("Assigned %d/%d (%d unassigned, %.1f%% coverage)",
        n_assigned, n0, n_unassigned, 100*n_assigned/n0))

# ── Write outputs ───────────────────────────────────────────────────────────
# (a) the manual-template CSV the rest of the pipeline expects, with the
#     assigned subset only — RCO_02 doesn't choke on rows without county_fips,
#     it just drops them in the roll-up, but the unassigned file is the
#     manual-augmentation queue.
manual_cols <- c("site_id","name","operator","county_fips","lat","lon",
                 "status","status_date","mw","cooling","water_source",
                 "power_source","confidence","source_url","notes",
                 "assign_pattern")
manual <- d[!is.na(county_fips), ..manual_cols]
fwrite(manual, file.path(OUT, "datacenter_sites_manual.csv"))
message("wrote ", file.path(OUT, "datacenter_sites_manual.csv"),
        " (", nrow(manual), " assigned rows)")

unassigned <- d[is.na(county_fips), ..manual_cols]
fwrite(unassigned, file.path(OUT, "datacenter_sites_unassigned.csv"))
message("wrote ", file.path(OUT, "datacenter_sites_unassigned.csv"),
        " (", nrow(unassigned), " rows needing manual county assignment)")

# ── Quick report: assigned-by-county count ──────────────────────────────────
cat("\n── Assigned counties by site count ──\n")
by_cnty <- d[!is.na(county_fips), .N, by = county_fips][order(-N)]
# Pull county names back in
cnty_names <- rbindlist(lapply(rules, function(r) data.table(fips = r$fips, cnty = r$cnty)))
cnty_names <- unique(cnty_names, by="fips")
by_cnty <- merge(by_cnty, cnty_names, by.x = "county_fips", by.y = "fips", all.x = TRUE)
print(by_cnty[order(-N)])

cat("\n── Confidence breakdown ──\n")
print(d[!is.na(county_fips), .N, by = assign_confidence])

cat("\n── First 15 unassigned (for manual augmentation) ──\n")
print(unassigned[1:min(15, .N), .(site_id, name, operator)])
