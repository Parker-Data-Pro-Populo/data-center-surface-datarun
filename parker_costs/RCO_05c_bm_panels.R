#!/usr/bin/env Rscript
# RCO_05c_bm_panels.R — two Black Mountain visuals:
#   B: side-by-side reality comparison (today vs post-abatement)
#   C: 3-scenario sensitivity sweep at 50% / 80% / 100% abatement
#
# Anchored to the same real Parker CAD May-2026 data as RCO_05b.

suppressPackageStartupMessages({ library(data.table) })

bm <- fread("bm_parcels_2026.csv")
bm[, has_corrected := any(notice_type == "CORRECTED"), by = prop_id]
bm_live <- rbind(bm[notice_type=="CORRECTED"],
                 bm[!has_corrected & notice_type=="ORIGINAL"])
bm_live <- unique(bm_live, by="prop_id")

BM_PARCELS  <- nrow(bm_live)
BM_ACRES    <- sum(bm_live$acres, na.rm=TRUE)
BM_LAND_VAL <- sum(bm_live$ty_land, na.rm=TRUE)
BM_TAX_LIVE <- sum(bm_live$tax_at_ly_rate, na.rm=TRUE)
BM_TAX_AG   <- sum(unique(bm[notice_type=="ORIGINAL"],
                           by="prop_id")$tax_at_ly_rate, na.rm=TRUE)
BM_NEW_LAND_REV <- BM_TAX_LIVE - BM_TAX_AG
BM_ROLLBACK     <- BM_NEW_LAND_REV * 5    # TX §23.55, 5-year back-tax

# Tax rates (Weatherford ISD area)
RATES <- c(isd=0.010342, county=0.002459, ltr=0.000533,
           hos=0.000895, col=0.001061, esd1=0.001000)
WE_RATE    <- RATES["isd"]
TOTAL_RATE <- sum(RATES)
CW_RATE    <- TOTAL_RATE - WE_RATE
WE_HH <- 15902
PA_HH <- 46404

# ── Taxable bases for rate-backfill calc ─────────────────────────────────────
tb <- fread("parker_taxable_base.csv")
WE_BASE  <- tb[code == "WE",  total_taxable_base]   # $8.51B  Weatherford ISD
PA_BASE  <- tb[code == "PAR", total_taxable_base]   # $30.54B Parker County (≈ COL,HOS,LTR)
ES1_BASE <- tb[code == "ES1", total_taxable_base]   # $13.40B ESD-1

# Typical Weatherford ISD homestead — derived from avg WE tax $1,871 at rate 1.0342%
# implies ~$181k ISD-taxable value (post $100k homestead exemption)
TYP_MARKET_VAL    <- 281000   # market value of avg Weatherford homestead
TYP_ISD_TAXABLE   <- 181000   # ISD-taxable after $100k homestead exemption
TYP_OTHER_TAXABLE <- 281000   # county / HOS / COL / LTR / ESD have no general exemption

# Scenario base — 1 GW gas-turbine DC
MW            <- 1000
DC_CAPEX_PER  <- 8.0
TURBINES      <- 5
TURBINE_COST  <- 200
TAXABLE_IMP   <- 0.85
ABATE_YRS     <- 10

dc_value      <- MW * DC_CAPEX_PER * 1e6
turbine_value <- TURBINES * TURBINE_COST * 1e6
imp_value     <- dc_value + turbine_value
imp_taxable   <- imp_value * TAXABLE_IMP

# Per-HH cost at a given abatement rate
# Computes TWO numbers:
#   subsidy_share  = each household's allocated share of the foregone public
#                    revenue (what's being transferred to the developer)
#   rate_backfill  = literal $ added to your tax bill IF jurisdictions raise
#                    rates to fully backfill the foregone amount
per_hh_cost <- function(abate) {
  # Total foregone tax per year
  full_we_yr <- imp_taxable * WE_RATE
  full_cw_yr <- imp_taxable * CW_RATE
  forg_we <- full_we_yr * abate
  forg_cw <- full_cw_yr * abate
  total_yr_forgone <- forg_we + forg_cw

  # (1) Subsidy share — foregone divided by household count
  land_gain_we <- BM_NEW_LAND_REV * (WE_RATE/TOTAL_RATE) / WE_HH
  land_gain_cw <- BM_NEW_LAND_REV * (CW_RATE/TOTAL_RATE) / PA_HH
  subsidy_share <- forg_we/WE_HH + forg_cw/PA_HH - land_gain_we - land_gain_cw

  # (2) Rate-backfill direct impact — implied rate increase × homestead taxable
  # Post-abatement tax base adds the un-abated portion of improvements + land
  unabated_imp_taxable <- imp_taxable * (1 - abate)
  new_we_base  <- WE_BASE  + unabated_imp_taxable + BM_LAND_VAL
  new_pa_base  <- PA_BASE  + unabated_imp_taxable + BM_LAND_VAL
  new_es1_base <- ES1_BASE + unabated_imp_taxable + BM_LAND_VAL
  # Per-jurisdiction implied rate hike to backfill that jurisdiction's foregone share
  forg_isd <- imp_taxable * WE_RATE        * abate
  forg_par <- imp_taxable * RATES["county"]* abate
  forg_col <- imp_taxable * RATES["col"]   * abate
  forg_hos <- imp_taxable * RATES["hos"]   * abate
  forg_ltr <- imp_taxable * RATES["ltr"]   * abate
  forg_es1 <- imp_taxable * RATES["esd1"]  * abate
  dr_isd <- forg_isd / new_we_base
  dr_par <- forg_par / new_pa_base
  dr_col <- forg_col / new_pa_base
  dr_hos <- forg_hos / new_pa_base
  dr_ltr <- forg_ltr / new_pa_base
  dr_es1 <- forg_es1 / new_es1_base
  rate_backfill_per_hh <-
      dr_isd * TYP_ISD_TAXABLE +
      (dr_par + dr_col + dr_hos + dr_ltr + dr_es1) * TYP_OTHER_TAXABLE

  list(
    we_per_hh         = forg_we / WE_HH,
    cw_per_hh         = forg_cw / PA_HH,
    land_gain_we      = land_gain_we,
    land_gain_cw      = land_gain_cw,
    subsidy_share     = subsidy_share,
    rate_backfill     = rate_backfill_per_hh,
    net_per_hh        = subsidy_share,        # kept as alias for back-compat
    total_yr_forgone  = total_yr_forgone
  )
}

# ── PANEL B — TODAY vs. POST-ABATEMENT (side-by-side reality) ──────────────
png_path_B <- "scenario_BM_panelB_reality.png"
png(png_path_B, width=2300, height=1200, res=170)
layout(matrix(c(1,2,3), nrow=1), widths=c(1, 1, 0.9))

# LEFT PANEL — what's already happening
par(mar=c(4,2,4,1), family="sans")
plot(NA, xlim=c(0,10), ylim=c(0,10), axes=FALSE, xlab="", ylab="",
     main="WHAT JUST HAPPENED  (May-15-2026 corrected notices)",
     cex.main=1.0, font.main=2, col.main="#1a6b3a")

text(5, 9.0, "Parker CAD stripped the agricultural", cex=0.95, col="#333333")
text(5, 8.4, "exemption from all 18 Black Mountain parcels",  cex=0.95, col="#333333")

text(5, 7.0, sprintf("$%s/yr", format(round(BM_TAX_AG), big.mark=",")),
     cex=1.6, font=1, col="#999999")
text(5, 6.5, "land tax BEFORE the correction", cex=0.8, col="#666666")

polygon(c(4.6, 5.4, 5.0), c(5.6, 5.6, 5.0), col="#1a6b3a", border=NA)

text(5, 4.2, sprintf("$%s/yr", format(round(BM_TAX_LIVE), big.mark=",")),
     cex=2.6, font=2, col="#1a6b3a")
text(5, 3.5, "land tax NOW flowing to Weatherford schools,", cex=0.92, col="#333333")
text(5, 3.0, "Parker County, hospital, junior college, ESD-1",   cex=0.92, col="#333333")

text(5, 1.7, sprintf("Plus $%s ONE-TIME rollback tax owed",
                     format(round(BM_ROLLBACK), big.mark=",")),
     cex=0.92, font=2, col="#a50f15")
text(5, 1.2, "(TX Tax Code §23.55 — 5 years of back-tax",
     cex=0.82, col="#666666")
text(5, 0.8, "for losing agricultural valuation)",
     cex=0.82, col="#666666")

# MIDDLE PANEL — what's about to happen
par(mar=c(4,2,4,1))
plot(NA, xlim=c(0,10), ylim=c(0,10), axes=FALSE, xlab="", ylab="",
     main="WHAT'S BEING ASKED  (standard 80% Ch.312 abatement)",
     cex.main=1.0, font.main=2, col.main="#a50f15")

text(5, 9.0, "Foregone tax on $9.0B in improvements", cex=0.95, col="#333333")
text(5, 8.4, "(1 GW data center + 5 gas turbines)",   cex=0.95, col="#333333")

text(5, 7.0,
     sprintf("$%.1fM/yr", per_hh_cost(0.80)$total_yr_forgone/1e6),
     cex=2.6, font=2, col="#a50f15")
text(5, 6.3, "withheld from local jurisdictions", cex=0.92, col="#333333")

polygon(c(4.6, 5.4, 5.0), c(5.3, 5.3, 4.7), col="#a50f15", border=NA)

text(5, 4.0,
     sprintf("$%.2fB", per_hh_cost(0.80)$total_yr_forgone * ABATE_YRS/1e9),
     cex=2.8, font=2, col="#a50f15")
text(5, 3.3, sprintf("over the %d-year abatement period", ABATE_YRS),
     cex=0.92, col="#333333")

text(5, 1.7,
     sprintf("That's %.0fx the land-tax gain",
             (per_hh_cost(0.80)$total_yr_forgone) / BM_NEW_LAND_REV),
     cex=0.95, font=2, col="#a50f15")
text(5, 1.2,
     "every year the abatement runs.",
     cex=0.92, col="#333333")

# RIGHT PANEL — per-family bottom line (TWO numbers, both real)
par(mar=c(4,2,4,1))
plot(NA, xlim=c(0,10), ylim=c(0,10), axes=FALSE, xlab="", ylab="",
     main="THE FAMILY-LEVEL COST",
     cex.main=1.0, font.main=2, col.main="#222222")

c80 <- per_hh_cost(0.80)

text(5, 9.3, "For one Weatherford ISD homestead:", cex=0.92, col="#333333")

# Subsidy share — what's being given to the developer per HH
text(5, 8.2, sprintf("$%s",
                     format(round(c80$subsidy_share), big.mark=",")),
     cex=2.3, font=2, col="#222222")
text(5, 7.5, "per year — subsidy transferred", cex=0.82, col="#444444")
text(5, 7.1, "to Black Mountain on your behalf", cex=0.82, col="#444444")
text(5, 6.4, sprintf("($%s over 10 years)",
                     format(round(c80$subsidy_share*ABATE_YRS), big.mark=",")),
     cex=0.82, col="#666666")

# Divider
segments(1.5, 5.7, 8.5, 5.7, col="#cccccc", lwd=1)

# Direct rate impact — what literally hits your tax bill
text(5, 5.0, sprintf("$%s",
                     format(round(c80$rate_backfill), big.mark=",")),
     cex=2.3, font=2, col="#a50f15")
text(5, 4.3, "per year — direct tax-bill increase", cex=0.82, col="#a50f15")
text(5, 3.9, "if jurisdictions fully backfill", cex=0.82, col="#a50f15")
text(5, 3.2, sprintf("($%s over 10 years)",
                     format(round(c80$rate_backfill*ABATE_YRS), big.mark=",")),
     cex=0.82, col="#a50f15")

# Context
text(5, 2.0, sprintf("Current avg Weatherford homestead bill: $%s/yr",
                     format(round(1871+1500), big.mark=",")),
     cex=0.80, col="#666666")
text(5, 1.5, sprintf("Rate backfill = +%.0f%% on top of current bill",
                     100*c80$rate_backfill/(1871+1500)),
     cex=0.85, font=2, col="#222222")
text(5, 0.9, "The rest of the subsidy lands as service cuts / deferred infra.",
     cex=0.75, font=3, col="#666666")

# Footer below both panels
mtext(sprintf("Source: Parker CAD May-15-2026 corrected notices (18 parcels, %.0f acres) · WE-ISD 2025 rates · 1 GW DC + 5×200MW turbines · $9.0B improvements · 85%% taxable",
              BM_ACRES),
      side=1, line=0.5, cex=0.7, col="#666666", outer=TRUE)
dev.off()
cat(sprintf("Wrote %s\n", png_path_B))

# ── PANEL C — sensitivity sweep at 50% / 80% / 100% abatement ─────────────
abates  <- c(0.50, 0.80, 1.00)
abate_lbl <- c("50%\nabatement", "80%\nabatement\n(standard)", "100%\nabatement\n(AI-priority)")
res <- lapply(abates, per_hh_cost)
subsidy_vec  <- sapply(res, function(r) r$subsidy_share)
backfill_vec <- sapply(res, function(r) r$rate_backfill)
subsidy_lt   <- subsidy_vec  * ABATE_YRS
backfill_lt  <- backfill_vec * ABATE_YRS
total_yr_vec <- sapply(res, function(r) r$total_yr_forgone)
total_lif_vec<- total_yr_vec * ABATE_YRS

png_path_C <- "scenario_BM_panelC_sensitivity.png"
png(png_path_C, width=2300, height=1300, res=170)
layout(matrix(c(1,2,3), nrow=1), widths=c(1.1, 1.1, 1))

col_subsidy  <- "#7f7f7f"   # neutral grey — the "share" framing
col_backfill <- "#a50f15"   # red — what literally hits the bill

# Per-HH per-year — paired bars
par(mar=c(5,5,4,1), family="sans")
mat <- rbind(subsidy_vec, backfill_vec)
bp <- barplot(mat, beside=TRUE, names.arg=abate_lbl,
              col=c(col_subsidy, col_backfill), border="white",
              ylim=c(0, max(mat)*1.22),
              main="Per-family annual cost\n(Weatherford ISD homestead)",
              ylab="$ per homestead per year",
              cex.main=1.0, cex.names=0.82, cex.lab=0.9)
text(bp[1,], subsidy_vec,
     sprintf("$%s", format(round(subsidy_vec), big.mark=",")),
     pos=3, cex=0.85, font=2, col=col_subsidy)
text(bp[2,], backfill_vec,
     sprintf("$%s", format(round(backfill_vec), big.mark=",")),
     pos=3, cex=0.85, font=2, col=col_backfill)
abline(h=1871+1500, lty=2, col="#999999")
text(bp[2, 1] + 0.5, 1871+1500, "current avg bill",
     pos=3, cex=0.7, col="#666666")
legend("topleft",
       legend=c("subsidy share (allocation)", "rate backfill (literal bill increase)"),
       fill=c(col_subsidy, col_backfill), bty="n", cex=0.78)

# Per-HH lifetime — paired bars
par(mar=c(5,5,4,1))
mat <- rbind(subsidy_lt, backfill_lt)
bp <- barplot(mat, beside=TRUE, names.arg=abate_lbl,
              col=c(col_subsidy, col_backfill), border="white",
              ylim=c(0, max(mat)*1.22),
              main="Per-family lifetime cost\n(10-year abatement)",
              ylab="$ per homestead total",
              cex.main=1.0, cex.names=0.82, cex.lab=0.9)
text(bp[1,], subsidy_lt,
     sprintf("$%s", format(round(subsidy_lt), big.mark=",")),
     pos=3, cex=0.85, font=2, col=col_subsidy)
text(bp[2,], backfill_lt,
     sprintf("$%s", format(round(backfill_lt), big.mark=",")),
     pos=3, cex=0.85, font=2, col=col_backfill)

# Aggregate Parker (still a single bar — same value for both framings, it's the gross subsidy)
par(mar=c(5,5,4,1))
bp <- barplot(total_lif_vec/1e9, names.arg=abate_lbl, col="#444444", border="white",
              ylim=c(0, max(total_lif_vec/1e9)*1.20),
              main="Parker County aggregate loss\n(10-year abatement, $B)",
              ylab="$ billion total foregone", cex.main=1.0, cex.names=0.82,
              cex.lab=0.9)
text(bp, total_lif_vec/1e9,
     sprintf("$%.2fB", total_lif_vec/1e9),
     pos=3, cex=0.92, font=2, col="#222222")

mtext("Subsidy share = per-HH allocation of foregone public revenue. Rate backfill = direct tax-bill increase if jurisdictions raise rates to recover the loss. The gap is what becomes service cuts / deferred infra.",
      side=1, line=0.5, cex=0.7, col="#666666", outer=TRUE)
dev.off()
cat(sprintf("Wrote %s\n", png_path_C))

# Print sensitivity table — both metrics
cat("\n══ Sensitivity: per-family cost across the abatement range ══\n\n")
cat(sprintf("%-24s  %-22s  %-22s  %s\n",
            "Abatement scenario",
            "Subsidy share /yr",
            "Rate backfill /yr",
            "Parker aggregate (10yr)"))
cat("───────────────────────────────────────────────────────────────────────────────────────\n")
for (i in seq_along(abates)) {
  cat(sprintf("%-24s  $%-9s (lifetime $%-7s)  $%-9s (lifetime $%-7s)  $%.2fB\n",
              gsub("\n", " ", abate_lbl[i]),
              format(round(subsidy_vec[i]), big.mark=","),
              format(round(subsidy_lt[i]),  big.mark=","),
              format(round(backfill_vec[i]), big.mark=","),
              format(round(backfill_lt[i]),  big.mark=","),
              total_lif_vec[i]/1e9))
}
