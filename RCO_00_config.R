#!/usr/bin/env Rscript
# RCO_00_config.R — Resource-Competition Overlay: shared config.
# Source this at the top of every RCO_* script: source("RCO_00_config.R")
#
# Scope: see wave5_RCO_scope.md. This is the analytical (research-register)
# build. Public-facing SFI must come from pg01.surface.tract_lean.harm_index,
# NOT the pg-active efa_scores.H pulled here (that scalar == F1, single-factor).

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(RPostgres)
})

# ── Connection ─────────────────────────────────────────────────────────────
# Substrate lives on pg-active (per section-3 note). Public SFI artifact lives
# on pg01. Set these via ~/.Renviron or the env; values below are fallbacks.
PG_ACTIVE <- list(
  host   = Sys.getenv("RCO_PGACTIVE_HOST", "pg-active"),   # VERIFY hostname
  dbname = Sys.getenv("RCO_PGACTIVE_DB",   "sfi_wave5_production"), # VERIFY
  user   = Sys.getenv("RCO_PGACTIVE_USER", Sys.getenv("USER")),
  port   = as.integer(Sys.getenv("RCO_PGACTIVE_PORT", "5432"))
)
PG01 <- list(
  host   = Sys.getenv("RCO_PG01_HOST", "pg01"),            # VERIFY hostname
  dbname = Sys.getenv("RCO_PG01_DB",   "sfi_production"),  # VERIFY
  user   = Sys.getenv("RCO_PG01_USER", Sys.getenv("USER")),
  port   = as.integer(Sys.getenv("RCO_PG01_PORT", "5432"))
)

rco_connect <- function(cfg) {
  dbConnect(RPostgres::Postgres(),
            host = cfg$host, dbname = cfg$dbname,
            user = cfg$user, port = cfg$port)
  # password expected via ~/.pgpass or PGPASSWORD env — do not hardcode.
}

# ── Output ─────────────────────────────────────────────────────────────────
OUT <- Sys.getenv("RCO_OUT", "~/rco_overlay/output")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
OUT <- normalizePath(OUT)

# ── County sets ──────────────────────────────────────────────────────────--
# TX working set: focus + active-moratorium comparison + metro reference.
# VERIFY these FIPS against your data (they matched in the section-1/2/3 run).
TX_SET <- data.table(
  fips = c("48367","48221","48217","48209","48467","48439","48113",
           "48337","48497"),                       # + Montague, Wise (UTGCD peers)
  name = c("Parker","Hood","Hill","Hays","Van Zandt","Tarrant","Dallas",
           "Montague","Wise")
)
FOCUS <- "48367"                                   # Parker
# Peer set redefined 2026-05-31: Hill added per political-action criterion
# (Hill passed a moratorium). Original EFA cluster-1 set preserved as
# PEER_STRUCTURAL for cross-county statistical comparisons.
PEER_STRUCTURAL <- c("48367","48209","48221")           # EFA cluster 1 (statistical)
PEER_CLUSTER1   <- c("48367","48209","48221","48217")   # + Hill (political — passed moratorium)
PEER_POLITICAL  <- PEER_CLUSTER1                         # alias

# National cluster-1 set is resolved at runtime in RCO_01 from clustgeo (k=10==1).

# ── Channel → indicator map ──────────────────────────────────────────────--
# Each entry: source column (as confirmed/derived) and direction:
#   +1  higher value => MORE susceptible
#   -1  higher value => LESS susceptible (flipped during normalization)
# IDs reference indicator_catalog_v3_LOCKED.md.
CHANNELS <- list(
  water = list(
    rural_raw_value                    = +1,  # BLT-023 well-dependence proxy
    drinking_water_violations_raw_value= +1,  # BLT-013 (0/1 FLAG, not count — caveat)
    severe_housing_problems_raw_value  = +1   # BLT-005 (incomplete-plumbing component)
    # GAP: no direct % households on private wells in v3 — flag for α add.
  ),
  power = list(                                # "who can't absorb a rate hike"
    severe_housing_cost_burden_raw_value = +1, # BLT-006
    poverty_rate_pct                     = +1, # ECON-026 (acs)
    median_hh_income                     = -1, # ECON-001 (acs)  [flip]
    pct_65_pluse                         = +1  # DEMO-002 (acs subject) fixed income
  ),
  land = list(                                 # ag-land conversion exposure
    ag_emp_share                         = +1, # EXTR-002 (qcew NAICS 11)
    farm_prop_income_share               = +1, # EXTR-004 (bea cainc30 lc220/lc10)
    rural_raw_value                      = +1  # shared with water
  )
)

# ── RCO parameters (tunable) ─────────────────────────────────────────────--
RCO_PARAMS <- list(
  susceptibility_norm = "z_then_minmax",  # z-score nationally, rescale to [0,1]
  d_norm              = "minmax_nonzero", # scale force among DC-bearing counties
  pgma_penalty        = 0.5,              # PGMA halves effective GCD capacity
  # mediator_water capacity from GCD funding code {0,1,2} -> {0, .33, .67}, then
  # multiplied by (1 - pgma_penalty*pgma). Tune in RCO_04.
  gcd_capacity_scale  = c("0"=0, "1"=0.34, "2"=0.67)
)

message("RCO config loaded. OUT = ", OUT)
