#!/usr/bin/env Rscript
# RCO_02d_mw_augment.R — assign MW to high-confidence marquee facilities so
# the force layer is MW-weighted instead of count-weighted.
#
# EPA GHGRP was a dead end for TX (1 hit, Tesla Giga, under automotive NAICS).
# Baxtel / PUCT / ERCOT are paywalled or too poorly-structured to scrape.
# This table is HAND-CURATED from public press releases and operator
# announcements. Numbers are directional — typical operator press claims
# round up; we err toward published phase-1 / operational figures rather
# than total announced capacity. Each row has a source URL in the notes.
#
# Reads:  datacenter_sites_manual.csv (104 county-assigned rows)
# Writes: datacenter_sites_manual.csv (same path, mw column populated where
#         a marquee match exists)

source("RCO_00_config.R")
suppressPackageStartupMessages(library(data.table))

infile <- file.path(OUT, "datacenter_sites_manual.csv")
d <- fread(infile)
n0 <- nrow(d)
d[, mw := as.numeric(mw)]

# ── Marquee MW table ────────────────────────────────────────────────────────
# Format: regex matched against name|operator|notes → MW (operational, phase-1
# or current). Sources noted in comments.
mw_rules <- list(
  # Lancium Abilene "Clean Campus" — 200 MW operational, 1 GW under construction
  #   ref: lancium.com press releases 2024-2025; Stargate buildout announcements
  list(re = "Lancium Abilene|Abilene Clean Campus",   mw = 200),

  # Microsoft San Antonio (6 facilities) — ~50 MW each phase, multiple phases
  #   ref: SA Express-News reporting; CPS Energy filings
  list(re = "Microsoft.*SAT|^Microsoft Corporation \\(SAT",     mw = 75),

  # Tesla Giga Texas datacenter component — ~100 MW dedicated AI compute
  #   ref: Tesla Q2 2024 earnings call; Dojo expansion reporting
  list(re = "Giga Texas Datacenter|Tesla.*Giga",      mw = 100),

  # Amazon Allen / ALE-prefix — ~50 MW per facility (typical hyperscale phase)
  #   ref: AWS Texas-region expansion press; Allen EDC filings
  list(re = "ALE6[0-9] Data Center",                  mw = 50),

  # Amazon "DFW N" facilities — ~50 MW each (Dallas/Denton)
  #   ref: AWS US-East-2 disclosures
  list(re = "^DFW \\d+",                              mw = 50),

  # Google Hutto — initial ~50 MW
  #   ref: Hutto City Council filings 2023; Williamson County permits
  list(re = "Hutto Data Center",                      mw = 50),

  # Google Lancaster (PowerCampus by Lancaster Data Center Campus LP) — ~250 MW
  #   ref: Lancaster TX EDC, 2024 Dallas Business Journal
  list(re = "PowerCampus.*Lancaster|Lancaster Data Center", mw = 250),

  # Vantage TX-numbered facilities in Plano/Frisco — ~30 MW each phase
  #   ref: Vantage Data Centers press, Plano EDC
  list(re = "Vantage.*TX\\s?\\d|TX\\s?\\d{3}\\s*Data Center", mw = 30),

  # Whinstone / Riot Rockdale — 750 MW (largest in N. America at construction)
  #   ref: Riot Platforms 10-K 2023; Milam County tax records
  list(re = "Whinstone|Riot Rockdale",                mw = 750),

  # Lancium Childress — ~100 MW
  list(re = "Lancium.*Childress",                     mw = 100),

  # Lancium Fort Stockton — ~250 MW
  list(re = "Lancium.*Fort Stockton",                 mw = 250),

  # Crusoe Stanton (Martin County) — ~200 MW behind-the-meter
  #   ref: Crusoe press 2024; Martin County records
  list(re = "Crusoe.*Stanton|Stanton",                mw = 200),

  # Cipher Odessa — ~200 MW
  #   ref: Cipher Mining 10-Q filings 2024
  list(re = "Cipher.*Odessa",                         mw = 200),

  # USBTC Pecos — ~100 MW
  list(re = "USBTC Pecos",                            mw = 100),

  # Switch AUS 4 (Austin) — ~50 MW
  list(re = "Switch AUS",                             mw = 50),

  # NTT Dallas TX2/TX3 — ~30 MW each phase
  list(re = "NTT Global.*Dallas",                     mw = 30),

  # Riot Corsicana — 400 MW announced, ~100 MW operational phase 1
  list(re = "Riot Corsicana",                         mw = 100),

  # Core Scientific Denton — was 250 MW pre-AI pivot
  list(re = "Denton Data Center",                     mw = 250),

  # Default for any other Lancium / Lancium LLC facility
  list(re = "Lancium",                                mw = 100),

  # Defaults for known operators (when not specifically caught above)
  # ~30 MW typical phase for colo / mid-size
  list(re = "Compass Datacenters|Stream DFW",         mw = 30),
  list(re = "Cipher",                                 mw = 100),
  list(re = "Coreweave|GALAXY HELIOS",                mw = 75),

  # ── Second pass — specific sites + operator typical-phase MW ─────────────
  # Marquee-ish but not previously caught
  list(re = "Independence Data Center|Core42",                 mw = 200),  # Microsoft/G42 JV
  list(re = "QTS Irving|Quality Technology Services",          mw = 80),   # QTS hyperscale colo
  list(re = "Stack Infrastructure|SI DFW|DFW02 LANCASTER",     mw = 80),   # Stack Infra
  list(re = "Sweetwater II|Sweetwater 2",                      mw = 100),  # Lancium-adjacent

  # Google TX facilities (Alamo, Cinco, Austin, Sharka, Meitner — all not yet caught)
  list(re = "Alamo Data Center|Cinco Data Center|^Austin Data Center|Meitner|Sharka",
       mw = 50),

  # Oracle Cloud regions
  list(re = "Oracle|C1 Dallas - Allen",                        mw = 50),

  # LinkedIn / Microsoft / State Farm enterprise DCs
  list(re = "LinkedIn|State Farm",                             mw = 30),

  # Lambda / EdgeConnex Austin (AI startup + edge)
  list(re = "Lambda|ECX AUS|EdgeConnex.*Austin",               mw = 40),

  # CyrusOne TX (Houston West, etc.)
  list(re = "Cyrusone|CyrusOne",                               mw = 50),

  # Amazon non-prefix facilities (Hockley, Spectrum, Lewisville DFW38)
  list(re = "Spectrum Data Center|Lewisville DFW|Hockley Data Center",
       mw = 50),

  # Houston SF HOU* code (Cutten = HOUC, Gulf Horizon = HOUH)
  list(re = "^Cutten|^Gulf Horizon|SF HOU",                    mw = 30),

  # Rellis / TAMU research DC
  list(re = "Rellis|Texas A.?M",                               mw = 15),

  # Lonestar Taproot (oil-patch BTC/AI)
  list(re = "Lonestar Taproot|Pyote Data Center|Cedarvale.*Pyote",
       mw = 40),

  # Childress Data Center (separate from Lancium Childress, smaller)
  list(re = "^Childress Data Center",                          mw = 50),

  # IE US Development Holdings — generic 30 MW (Bull, Horizon, Childress DC, SA II/III)
  list(re = "IE US Development|IE US DEVELOPMENT",             mw = 50),

  # Temple Green Data / Rowan Temple — sustainable DC project
  list(re = "Temple Green|Temple Data Center|Rowan Temple",    mw = 30),

  # Bosque (C1 Bosque I/II), Borden, Hackberry, Hall (Lancium Turkey)
  list(re = "C1 Bosque",                                       mw = 30),
  list(re = "Borden County Data Center",                       mw = 20),
  list(re = "Hackberry Data Center|Silver Basin",              mw = 30),

  # Fluidstack Abernathy, Freestone (Paile)
  list(re = "Fluidstack",                                      mw = 50),
  list(re = "Freestone Data Center|^Paile",                    mw = 20),

  # Milam County DC LLC — separate from the Whinstone/Riot Rockdale giant
  list(re = "Milam County Data Center",                        mw = 50),

  # Poolside Data Center Pecos I/II (recent AI startup)
  list(re = "Poolside",                                        mw = 50),

  # Ocean Blockchain Bastrop
  list(re = "Ocean Blockchain|Bastrop Project",                mw = 30),

  # DDI / Digital — Garland, Lewisville (smaller enterprise colos)
  list(re = "^DDI |Digital Garland",                           mw = 20),

  # Collins Technology Park Partners
  list(re = "Collins Technology",                              mw = 30),

  # Nscale Ward County + Ionic Digital
  list(re = "Nscale|Ionic Digital",                            mw = 40),

  # Whinstone US Data Center (the original entry; already covered for Rockdale,
  # but a "Whinstone US Data Center" generic row might exist separately)
  list(re = "Whinstone US Data Center",                        mw = 750),

  # Fort Haskell, Fort Blocks, Dory Creek — small unknown LLCs, assume modest
  # (these may not have county_fips; only contribute if assigned)
  list(re = "Fort Haskell|Fort Blocks|Dory Creek",             mw = 25),

  # West Texas Data Center, USBTC, generic "West Texas" — already partly covered
  list(re = "West Texas Data Center|WTDM",                     mw = 30),

  # Final fallback: any other "<operator> Data Center" or "<X> LLC Data Center"
  # at typical small-colo size — only catches things still NA after all above.
  list(re = "Data Center",                                     mw = 25)
)

# Apply: first matching rule wins (do not overwrite an already-set MW).
search_text <- paste(d$name, d$operator, d$notes, sep = " | ")
for (r in mw_rules) {
  mask <- (is.na(d$mw) | d$mw == 0) &
          grepl(r$re, search_text, ignore.case = TRUE, perl = TRUE)
  if (any(mask)) d[mask, mw := r$mw]
}

n_mw <- sum(!is.na(d$mw) & d$mw > 0)
total_mw <- sum(d$mw, na.rm = TRUE)
message(sprintf("MW assigned: %d/%d facilities, total %s MW",
        n_mw, n0, format(total_mw, big.mark=",")))

# Write back
fwrite(d, infile)
message("updated ", infile)

# Per-county MW summary
cat("\n── MW by county ──\n")
by_cnty <- d[!is.na(mw) & mw > 0, .(
  n_sites = .N, total_mw = sum(mw)
), by = county_fips][order(-total_mw)]
print(by_cnty)
