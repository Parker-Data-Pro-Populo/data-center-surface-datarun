#!/usr/bin/env Rscript
# RCO_05e_ceilings.R — HB 3 / SB 2 rate-ceiling refinement to the cost model.
#
# What this adds: a THIRD per-family number alongside subsidy_share and
# rate_backfill. It splits the rate-backfill into:
#   (a) legally backfillable WITHOUT election (within HB 3 / SB 2 caps)
#   (b) forced into service cuts / deferred infrastructure / VATR election
#
# Statutory anchors used:
#   - SB 2 (2019, TX Property Tax Reform): cities, counties, and special districts
#     are capped at 3.5% revenue growth above the no-new-revenue M&O rate
#     without a voter-approval election.
#   - HB 3 (2019, school finance): ISDs use a "voter-approval tax rate" (VATR)
#     mechanism; M&O compression is mandated, and any revenue growth above the
#     state-formula threshold requires a VATR election. For modeling purposes
#     we treat 2.5% revenue growth as the auto-allowable max — slightly tighter
#     than the county side because the M&O compression typically eats some of
#     the allowable growth before any abatement scenario is even considered.
#
# Output: scenario_BM_ceilings.png + console table

suppressPackageStartupMessages({ library(data.table) })

# ── Anchor data ───────────────────────────────────────────────────────────
bm <- fread("bm_parcels_2026.csv")
bm[, has_corrected := any(notice_type == "CORRECTED"), by = prop_id]
bm_live <- rbind(bm[notice_type == "CORRECTED"],
                 bm[!has_corrected & notice_type == "ORIGINAL"])
bm_live <- unique(bm_live, by="prop_id")
BM_LAND_VAL <- sum(bm_live$ty_land, na.rm=TRUE)
BM_TAX_LIVE <- sum(bm_live$tax_at_ly_rate, na.rm=TRUE)
BM_TAX_AG   <- sum(unique(bm[notice_type=="ORIGINAL"], by="prop_id")$tax_at_ly_rate, na.rm=TRUE)
BM_NEW_LAND_REV <- BM_TAX_LIVE - BM_TAX_AG

RATES_NAMED <- c(isd=0.010342, county=0.002459, ltr=0.000533,
                 hos=0.000895, col=0.001061, esd1=0.001000)
# Strip names — named-numeric inheritance causes data.table display oddities
ISD_R    <- unname(RATES_NAMED["isd"])
COUNTY_R <- unname(RATES_NAMED["county"])
LTR_R    <- unname(RATES_NAMED["ltr"])
HOS_R    <- unname(RATES_NAMED["hos"])
COL_R    <- unname(RATES_NAMED["col"])
ES1_R    <- unname(RATES_NAMED["esd1"])
WE_RATE    <- ISD_R
TOTAL_RATE <- sum(RATES_NAMED)
CW_RATE    <- TOTAL_RATE - WE_RATE
WE_HH <- 15902
PA_HH <- 46404

tb <- fread("parker_taxable_base.csv")
# total_taxable_base is parsed as integer64 (values exceed 32-bit int max);
# cast to numeric so arithmetic produces correct doubles.
WE_BASE  <- as.numeric(tb[code=="WE",  total_taxable_base])
PA_BASE  <- as.numeric(tb[code=="PAR", total_taxable_base])
ES1_BASE <- as.numeric(tb[code=="ES1", total_taxable_base])

TYP_ISD_TAXABLE   <- 181000
TYP_OTHER_TAXABLE <- 281000
TAXABLE_IMP       <- 0.85
ABATE_YRS         <- 10

# Statutory rate-growth ceilings (annual, without voter election)
ISD_CEILING    <- 0.025    # HB 3 — VATR threshold (modeled as 2.5%)
COUNTY_CEILING <- 0.035    # SB 2 — county/city/special-district cap
ES1_CEILING    <- 0.035    # ESDs follow SB 2

# Current annual revenue per jurisdiction (used as the % cap base)
WE_REV_CURR  <- WE_BASE  * ISD_R
PA_REV_CURR  <- PA_BASE  * COUNTY_R
COL_REV_CURR <- PA_BASE  * COL_R
HOS_REV_CURR <- PA_BASE  * HOS_R
LTR_REV_CURR <- PA_BASE  * LTR_R
ES1_REV_CURR <- ES1_BASE * ES1_R

# Maximum legally backfillable revenue per year (above no-new-revenue)
ISD_MAX_BACKFILL <- WE_REV_CURR  * ISD_CEILING
PAR_MAX_BACKFILL <- PA_REV_CURR  * COUNTY_CEILING
COL_MAX_BACKFILL <- COL_REV_CURR * COUNTY_CEILING
HOS_MAX_BACKFILL <- HOS_REV_CURR * COUNTY_CEILING
LTR_MAX_BACKFILL <- LTR_REV_CURR * COUNTY_CEILING
ES1_MAX_BACKFILL <- ES1_REV_CURR * ES1_CEILING

# ── Phase definitions ─────────────────────────────────────────────────────
phases <- list(
  phase1 = list(label="Phase 1\n(75 MW TCEQ-permitted)", short="Phase 1",
                mw=75, dc_capex=8.0, turbines=5, t_mw=15, t_cost=30,
                color="#d97706"),
  buildout = list(label="Buildout\n(1 GW implied future)", short="Buildout",
                  mw=1000, dc_capex=8.0, turbines=5, t_mw=200, t_cost=200,
                  color="#a50f15")
)

per_hh_full <- function(phase, abate) {
  dc_val   <- phase$mw * phase$dc_capex * 1e6
  t_val    <- phase$turbines * phase$t_cost * 1e6
  imp_val  <- dc_val + t_val
  imp_tax  <- imp_val * TAXABLE_IMP

  # Foregone tax per jurisdiction (all unnamed scalars)
  forg_isd <- imp_tax * ISD_R    * abate
  forg_par <- imp_tax * COUNTY_R * abate
  forg_col <- imp_tax * COL_R    * abate
  forg_hos <- imp_tax * HOS_R    * abate
  forg_ltr <- imp_tax * LTR_R    * abate
  forg_es1 <- imp_tax * ES1_R    * abate
  total_forgone_yr <- forg_isd + forg_par + forg_col + forg_hos + forg_ltr + forg_es1

  # (1) Subsidy share
  forg_we_total <- forg_isd
  forg_cw_total <- forg_par + forg_col + forg_hos + forg_ltr + forg_es1
  land_gain_we <- BM_NEW_LAND_REV * (ISD_R/TOTAL_RATE) / WE_HH
  land_gain_cw <- BM_NEW_LAND_REV * ((TOTAL_RATE-ISD_R)/TOTAL_RATE) / PA_HH
  subsidy_share <- forg_we_total/WE_HH + forg_cw_total/PA_HH -
                   land_gain_we - land_gain_cw

  # (2) Unconstrained backfill (if jurisdictions could raise rates freely)
  unabated_imp <- imp_tax * (1 - abate)
  new_we_base  <- WE_BASE  + unabated_imp + BM_LAND_VAL
  new_pa_base  <- PA_BASE  + unabated_imp + BM_LAND_VAL
  new_es1_base <- ES1_BASE + unabated_imp + BM_LAND_VAL
  rate_backfill_unc <-
    (forg_isd / new_we_base) * TYP_ISD_TAXABLE +
    ((forg_par + forg_col + forg_hos + forg_ltr) / new_pa_base) * TYP_OTHER_TAXABLE +
    (forg_es1 / new_es1_base) * TYP_OTHER_TAXABLE

  # (3) HB 3 / SB 2 constrained backfill — cap each jurisdiction
  legal_isd <- min(forg_isd, ISD_MAX_BACKFILL)
  legal_par <- min(forg_par, PAR_MAX_BACKFILL)
  legal_col <- min(forg_col, COL_MAX_BACKFILL)
  legal_hos <- min(forg_hos, HOS_MAX_BACKFILL)
  legal_ltr <- min(forg_ltr, LTR_MAX_BACKFILL)
  legal_es1 <- min(forg_es1, ES1_MAX_BACKFILL)
  rate_backfill_legal <-
    (legal_isd / new_we_base) * TYP_ISD_TAXABLE +
    ((legal_par + legal_col + legal_hos + legal_ltr) / new_pa_base) * TYP_OTHER_TAXABLE +
    (legal_es1 / new_es1_base) * TYP_OTHER_TAXABLE

  # (4) Service cuts = excess foregone allocated per-HH by jurisdiction location
  excess_isd <- max(0, forg_isd - ISD_MAX_BACKFILL)
  excess_par <- max(0, forg_par - PAR_MAX_BACKFILL)
  excess_col <- max(0, forg_col - COL_MAX_BACKFILL)
  excess_hos <- max(0, forg_hos - HOS_MAX_BACKFILL)
  excess_ltr <- max(0, forg_ltr - LTR_MAX_BACKFILL)
  excess_es1 <- max(0, forg_es1 - ES1_MAX_BACKFILL)
  service_cuts_per_hh <- (excess_isd / WE_HH) +
    ((excess_par + excess_col + excess_hos + excess_ltr + excess_es1) / PA_HH)

  list(
    imp_value           = imp_val,
    forgone_yr          = total_forgone_yr,
    forgone_life        = total_forgone_yr * ABATE_YRS,
    subsidy_share       = subsidy_share,
    rate_backfill_unc   = rate_backfill_unc,
    rate_backfill_legal = rate_backfill_legal,
    service_cuts_per_hh = service_cuts_per_hh,
    isd_forg_yr         = forg_isd,
    isd_max_backfill    = ISD_MAX_BACKFILL,
    isd_election_needed = forg_isd > ISD_MAX_BACKFILL
  )
}

# ── Run all scenarios ──────────────────────────────────────────────────────
abates <- c(0.50, 0.80, 1.00)
abate_lbl <- c("50% abatement",
               "80% abatement (standard)",
               "100% abatement (AI-priority)")

cat("\n══════════════════════════════════════════════════════════════════\n")
cat("HB 3 / SB 2 RATE-CEILING REFINEMENT — PER-FAMILY COST DECOMPOSITION\n")
cat("══════════════════════════════════════════════════════════════════\n\n")
cat(sprintf("Per-jurisdiction max legally backfillable per year (without election):\n"))
cat(sprintf("  Weatherford ISD (HB 3, 2.5%% VATR):  $%s/yr\n",
            format(round(ISD_MAX_BACKFILL), big.mark=",")))
cat(sprintf("  Parker County  (SB 2, 3.5%%):       $%s/yr\n",
            format(round(PAR_MAX_BACKFILL), big.mark=",")))
cat(sprintf("  Hospital Dist  (SB 2, 3.5%%):       $%s/yr\n",
            format(round(HOS_MAX_BACKFILL), big.mark=",")))
cat(sprintf("  Jr College     (SB 2, 3.5%%):       $%s/yr\n",
            format(round(COL_MAX_BACKFILL), big.mark=",")))
cat(sprintf("  Lateral Road   (SB 2, 3.5%%):       $%s/yr\n",
            format(round(LTR_MAX_BACKFILL), big.mark=",")))
cat(sprintf("  ESD-1          (SB 2, 3.5%%):       $%s/yr\n",
            format(round(ES1_MAX_BACKFILL), big.mark=",")))
cat("\n")

scenario_grid <- expand.grid(
  phase  = names(phases),
  abate  = abates,
  stringsAsFactors = FALSE
)

results <- list()
for (k in seq_len(nrow(scenario_grid))) {
  ph <- phases[[scenario_grid$phase[k]]]
  ab <- scenario_grid$abate[k]
  r <- per_hh_full(ph, ab)
  results[[k]] <- data.table(
    phase = ph$short,
    abate_pct = sprintf("%.0f%%", ab*100),
    subsidy_share          = r$subsidy_share,
    rate_backfill_unc      = r$rate_backfill_unc,
    rate_backfill_legal    = r$rate_backfill_legal,
    service_cuts_per_hh    = r$service_cuts_per_hh,
    isd_forg_yr            = r$isd_forg_yr,
    isd_election_needed    = r$isd_election_needed
  )
}
all_results <- rbindlist(results)

# Print compact table
cat("══ Per-family decomposition (Weatherford ISD homestead) ══\n\n")
cat(sprintf("%-10s %-8s | %-12s %-12s %-12s %-12s %-12s\n",
            "Phase", "Abate",
            "Subsidy/yr", "Backfill-LegalCAP", "Service-cuts/yr",
            "ISD>cap?", "Backfill-uncapped"))
cat(strrep("─", 100), "\n", sep="")
for (k in seq_len(nrow(all_results))) {
  r <- all_results[k]
  cat(sprintf("%-10s %-8s | $%10s   $%10s    $%10s    %-12s $%10s\n",
              r$phase, r$abate_pct,
              format(round(r$subsidy_share), big.mark=","),
              format(round(r$rate_backfill_legal), big.mark=","),
              format(round(r$service_cuts_per_hh), big.mark=","),
              ifelse(r$isd_election_needed, "YES (election)", "no"),
              format(round(r$rate_backfill_unc), big.mark=",")))
}

# ── Plot — three-bar comparison per scenario ──────────────────────────────
png_path <- "scenario_BM_ceilings.png"
png(png_path, width=2400, height=1300, res=170)
layout(matrix(c(1,2), nrow=1), widths=c(1,1))

col_subsidy <- "#7f7f7f"
col_legal   <- "#d97706"   # amber: what hits the bill literally
col_cuts    <- "#a50f15"   # red:   what becomes service cuts

# PANEL 1 — Phase 1 sensitivity
par(mar=c(5,5,4,1), family="sans")
p1 <- all_results[phase == "Phase 1"]
mat <- rbind(p1$subsidy_share, p1$rate_backfill_legal, p1$service_cuts_per_hh)
bp <- barplot(mat, beside=TRUE,
              names.arg=c("50% abatement", "80% (standard)", "100% (AI-priority)"),
              col=c(col_subsidy, col_legal, col_cuts), border="white",
              ylim=c(0, max(mat)*1.30),
              main="Phase 1 — 75 MW TCEQ-permitted\nPer-family annual cost decomposition",
              ylab="$ per homestead per year", cex.main=1.0,
              cex.names=0.85, cex.lab=0.92)
for (col_i in 1:3) {
  text(bp[1, col_i], mat[1, col_i],
       sprintf("$%s", format(round(mat[1, col_i]), big.mark=",")),
       pos=3, cex=0.80, font=2, col=col_subsidy)
  text(bp[2, col_i], mat[2, col_i],
       sprintf("$%s", format(round(mat[2, col_i]), big.mark=",")),
       pos=3, cex=0.80, font=2, col=col_legal)
  text(bp[3, col_i], mat[3, col_i],
       sprintf("$%s", format(round(mat[3, col_i]), big.mark=",")),
       pos=3, cex=0.80, font=2, col=col_cuts)
}
legend("topleft",
       legend=c("Total subsidy share (allocated)",
                "Backfill capped by HB 3 / SB 2 (literal tax bill)",
                "Forced service cuts (unfillable gap)"),
       fill=c(col_subsidy, col_legal, col_cuts), bty="n", cex=0.78)

# PANEL 2 — Buildout sensitivity
par(mar=c(5,5,4,1))
bo <- all_results[phase == "Buildout"]
mat <- rbind(bo$subsidy_share, bo$rate_backfill_legal, bo$service_cuts_per_hh)
bp <- barplot(mat, beside=TRUE,
              names.arg=c("50% abatement", "80% (standard)", "100% (AI-priority)"),
              col=c(col_subsidy, col_legal, col_cuts), border="white",
              ylim=c(0, max(mat)*1.30),
              main="Buildout — 1 GW implied future\nPer-family annual cost decomposition",
              ylab="$ per homestead per year", cex.main=1.0,
              cex.names=0.85, cex.lab=0.92)
for (col_i in 1:3) {
  text(bp[1, col_i], mat[1, col_i],
       sprintf("$%s", format(round(mat[1, col_i]), big.mark=",")),
       pos=3, cex=0.80, font=2, col=col_subsidy)
  text(bp[2, col_i], mat[2, col_i],
       sprintf("$%s", format(round(mat[2, col_i]), big.mark=",")),
       pos=3, cex=0.80, font=2, col=col_legal)
  text(bp[3, col_i], mat[3, col_i],
       sprintf("$%s", format(round(mat[3, col_i]), big.mark=",")),
       pos=3, cex=0.80, font=2, col=col_cuts)
}
abline(h=1871+1500, lty=2, col="#999999")
text(par("usr")[1]+0.3, 1871+1500, "current avg WE homestead bill",
     pos=4, cex=0.7, col="#666666")

mtext("HB 3 (2019) caps ISD revenue growth at the VATR threshold (~2.5%) without a voter-approval election. SB 2 (2019) caps county/special-district rates at 3.5%. The amber bar = what can hit your tax bill legally. The red bar = what MUST become service cuts.",
      side=1, line=0.5, cex=0.7, col="#666666", outer=TRUE)
dev.off()
cat(sprintf("\nWrote %s\n", png_path))
