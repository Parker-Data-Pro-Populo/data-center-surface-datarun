#!/usr/bin/env Rscript
# RCO_siting_risk_2026-09.R — re-run of the developer-attractiveness index with
# regulatory status current to September 2026.
#
# The model is unchanged from rco_overlay_local/scripts/rco_viz_siting_risk.R:
#   siting_risk = 0.35*land + 0.35*permissive + 0.30*infra,  normalized to [0,1]
#   permissive  = (1 - 0.5*gcd_funding) * (1 - 0.5*pgma) * (1 - 0.5*moratorium)
#
# WHAT CHANGED: only the moratorium input. The June run hard-coded
#   moratorium_fips <- c("48217")   # Hill
# Hill County rescinded its moratorium within weeks of adopting it, after a
# developer sued for more than $100M. Current county-level status:
#   - Hill (48217)      RESCINDED May 2026        -> no longer counted
#   - Austin (48015)    ADOPTED July 2026         -> now counted
#   - Tom Green (48451) abandoned before adoption -> not counted
#   - Hood (48221), Hays (48209) considered Feb 2026, never adopted -> not counted
# San Marcos's zoning ban is municipal, not county-level, so it does not enter a
# county index. Hood's Ch. 231 zoning authority is a real regulatory difference
# the model has no term for — noted, not silently encoded.

suppressPackageStartupMessages({ library(data.table) })

IN  <- "../rco_overlay_local/output/rco_siting_risk.csv"
d   <- fread(IN, colClasses = list(character = "fips"))

MORATORIUM_2026_09 <- c("48015")            # Austin County
d[, moratorium_june := moratorium]
d[, moratorium := fifelse(fips %in% MORATORIUM_2026_09, 1L, 0L)]

recompute <- function(dt, mor_col) {
  perm <- (1 - 0.5 * dt$gcd_funding) * (1 - 0.5 * dt$pgma) * (1 - 0.5 * dt[[mor_col]])
  perm <- pmin(1, pmax(0, perm))
  raw  <- 0.35 * dt$land_score + 0.35 * perm + 0.30 * dt$infra_score
  (raw - min(raw, na.rm = TRUE)) / (max(raw, na.rm = TRUE) - min(raw, na.rm = TRUE))
}

d[, risk_june := recompute(d, "moratorium_june")]
d[, risk_sept := recompute(d, "moratorium")]
d[, rank_june := frank(-risk_june, ties.method = "min")]
d[, rank_sept := frank(-risk_sept, ties.method = "min")]
d[, rank_delta := rank_june - rank_sept]          # positive = became MORE attractive

setorder(d, -risk_sept)
fwrite(d[, .(fips, name, gcd_funding, pgma, moratorium_june, moratorium,
             land_score, infra_score, risk_june, risk_sept,
             rank_june, rank_sept, rank_delta, is_lit, is_peer)],
       "siting_risk_2026-09.csv")

show <- function(f) {
  r <- d[fips == f]
  cat(sprintf("  %-12s rank %3d -> %3d   (index %.4f -> %.4f)%s\n",
              r$name, r$rank_june, r$rank_sept, r$risk_june, r$risk_sept,
              if (r$rank_delta != 0) sprintf("   moved %+d", r$rank_delta) else ""))
}
cat("\n== Counties named in the briefing ==\n(rank 1 = most attractive to a developer, of 254)\n\n")
for (f in c("48367","48217","48221","48209","48015","48451")) show(f)

cat("\n== Parker's components ==\n")
p <- d[fips == "48367"]
cat(sprintf("  land %.3f · permissive %.3f (GCD-funded=%d, PGMA=%d, moratorium=%d) · infra %.3f\n",
            p$land_score, (1-0.5*p$gcd_funding)*(1-0.5*p$pgma)*(1-0.5*p$moratorium),
            p$gcd_funding, p$pgma, p$moratorium, p$infra_score))
cat(sprintf("\n  Counties whose rank moved at all: %d\n", d[rank_delta != 0, .N]))
cat(sprintf("  Parker's rank unchanged by Hill's rescission: %s\n",
            if (d[fips=="48367", rank_delta] == 0) "yes" else "no"))
