#!/usr/bin/env Rscript
# RCO_05d_phases.R — Phase 1 (75 MW, TCEQ-permitted) vs Buildout (1 GW, implied)
# side-by-side comparison. Anchored to:
#   - Parker CAD May-15-2026 corrected notices (18 parcels, 2,075 acres)
#   - Hotopp testimony (May 26 commissioners court): 75 MW "not enough"
#     for ultimate buildout
#
# Two outputs:
#   B  — 3-column reality flow: Today / Phase 1 / Buildout
#   C  — paired sensitivity: Phase 1 + Buildout at 50/80/100% abatement

suppressPackageStartupMessages({ library(data.table) })

# ── Anchored Parker CAD reality ────────────────────────────────────────────
bm <- fread("bm_parcels_2026.csv")
bm[, has_corrected := any(notice_type == "CORRECTED"), by = prop_id]
bm_live <- rbind(bm[notice_type == "CORRECTED"],
                 bm[!has_corrected & notice_type == "ORIGINAL"])
bm_live <- unique(bm_live, by="prop_id")

BM_PARCELS  <- nrow(bm_live)
BM_ACRES    <- sum(bm_live$acres, na.rm = TRUE)
BM_LAND_VAL <- sum(bm_live$ty_land, na.rm = TRUE)
BM_TAX_LIVE <- sum(bm_live$tax_at_ly_rate, na.rm = TRUE)
BM_TAX_AG   <- sum(unique(bm[notice_type == "ORIGINAL"],
                           by = "prop_id")$tax_at_ly_rate, na.rm = TRUE)
BM_NEW_LAND_REV <- BM_TAX_LIVE - BM_TAX_AG
BM_ROLLBACK     <- BM_NEW_LAND_REV * 5

# ── Tax rates + taxable bases ─────────────────────────────────────────────
RATES <- c(isd = 0.010342, county = 0.002459, ltr = 0.000533,
           hos = 0.000895, col = 0.001061, esd1 = 0.001000)
WE_RATE    <- RATES["isd"]
TOTAL_RATE <- sum(RATES)
CW_RATE    <- TOTAL_RATE - WE_RATE
WE_HH      <- 15902
PA_HH      <- 46404

tb <- fread("parker_taxable_base.csv")
WE_BASE  <- tb[code == "WE",  total_taxable_base]
PA_BASE  <- tb[code == "PAR", total_taxable_base]
ES1_BASE <- tb[code == "ES1", total_taxable_base]

TYP_ISD_TAXABLE   <- 181000
TYP_OTHER_TAXABLE <- 281000

ABATE_YRS  <- 10
TAXABLE_IMP <- 0.85

# ── Phase definitions ─────────────────────────────────────────────────────
phases <- list(
  phase1 = list(
    label    = "Phase 1\n(75 MW, TCEQ-permitted)",
    short    = "Phase 1",
    mw       = 75,
    dc_capex = 8.0,           # $M/MW
    turbines = 5,
    t_mw     = 15,
    t_cost   = 30,            # $M per LM2500-class
    color    = "#d97706"      # amber
  ),
  buildout = list(
    label    = "Buildout\n(1 GW, implied future)",
    short    = "Buildout",
    mw       = 1000,
    dc_capex = 8.0,
    turbines = 5,
    t_mw     = 200,
    t_cost   = 200,           # $M per M501-class frame
    color    = "#a50f15"      # red
  )
)

per_hh_cost <- function(phase, abate) {
  dc_val   <- phase$mw * phase$dc_capex * 1e6
  t_val    <- phase$turbines * phase$t_cost * 1e6
  imp_val  <- dc_val + t_val
  imp_tax  <- imp_val * TAXABLE_IMP

  full_we <- imp_tax * WE_RATE
  full_cw <- imp_tax * CW_RATE
  forg_we <- full_we * abate
  forg_cw <- full_cw * abate
  total_forgone_yr <- forg_we + forg_cw

  # Subsidy share
  land_gain_we <- BM_NEW_LAND_REV * (WE_RATE/TOTAL_RATE) / WE_HH
  land_gain_cw <- BM_NEW_LAND_REV * (CW_RATE/TOTAL_RATE) / PA_HH
  subsidy_share <- forg_we/WE_HH + forg_cw/PA_HH - land_gain_we - land_gain_cw

  # Rate backfill
  unabated_imp <- imp_tax * (1 - abate)
  new_we_base  <- WE_BASE  + unabated_imp + BM_LAND_VAL
  new_pa_base  <- PA_BASE  + unabated_imp + BM_LAND_VAL
  new_es1_base <- ES1_BASE + unabated_imp + BM_LAND_VAL
  forg_isd <- imp_tax * WE_RATE        * abate
  forg_par <- imp_tax * RATES["county"]* abate
  forg_col <- imp_tax * RATES["col"]   * abate
  forg_hos <- imp_tax * RATES["hos"]   * abate
  forg_ltr <- imp_tax * RATES["ltr"]   * abate
  forg_es1 <- imp_tax * RATES["esd1"]  * abate
  rate_backfill <-
    (forg_isd / new_we_base) * TYP_ISD_TAXABLE +
    ((forg_par + forg_col + forg_hos + forg_ltr) / new_pa_base) * TYP_OTHER_TAXABLE +
    (forg_es1 / new_es1_base) * TYP_OTHER_TAXABLE

  list(
    imp_value     = imp_val,
    forgone_yr    = total_forgone_yr,
    forgone_life  = total_forgone_yr * ABATE_YRS,
    subsidy_share = subsidy_share,
    subsidy_life  = subsidy_share * ABATE_YRS,
    rate_backfill = rate_backfill,
    rate_back_life= rate_backfill * ABATE_YRS
  )
}

# Standard 80% abatement, both phases
p1_80 <- per_hh_cost(phases$phase1,   0.80)
bo_80 <- per_hh_cost(phases$buildout, 0.80)

# ── PANEL B — three-column temporal flow ──────────────────────────────────
png_path_B <- "scenario_BM_phases_B.png"
png(png_path_B, width = 2400, height = 1300, res = 170)
layout(matrix(c(1, 2, 3), nrow = 1), widths = c(1, 1, 1))

# ── COLUMN 1 — TODAY (what's already on the rolls) ────────────────────────
par(mar = c(4, 2, 5, 1), family = "sans")
plot(NA, xlim = c(0, 10), ylim = c(0, 10), axes = FALSE, xlab = "", ylab = "",
     main = "TODAY — May-15-2026 corrected notices",
     cex.main = 1.05, font.main = 2, col.main = "#1a6b3a")

text(5, 9.0, "Parker CAD stripped the ag exemption",
     cex = 0.92, col = "#333333")
text(5, 8.5, "from all 18 Black Mountain parcels (2,075 ac)",
     cex = 0.92, col = "#333333")

text(5, 7.4, sprintf("$%s/yr", format(round(BM_TAX_AG), big.mark = ",")),
     cex = 1.5, col = "#999999")
text(5, 6.9, "land tax BEFORE the correction", cex = 0.78, col = "#666666")

polygon(c(4.6, 5.4, 5.0), c(6.2, 6.2, 5.6), col = "#1a6b3a", border = NA)

text(5, 4.7, sprintf("$%s/yr",
                     format(round(BM_TAX_LIVE), big.mark = ",")),
     cex = 2.4, font = 2, col = "#1a6b3a")
text(5, 4.0, "land tax NOW flowing — to schools,",
     cex = 0.85, col = "#333333")
text(5, 3.5, "county, hospital, college, ESD-1",
     cex = 0.85, col = "#333333")

text(5, 2.2, sprintf("Plus $%s",
                     format(round(BM_ROLLBACK), big.mark = ",")),
     cex = 0.92, font = 2, col = "#a50f15")
text(5, 1.7, "one-time rollback tax owed",
     cex = 0.82, col = "#a50f15")
text(5, 1.2, "(TX §23.55, 5 years back-tax)",
     cex = 0.78, col = "#666666")

# ── COLUMN 2 — PHASE 1 (already permitted) ────────────────────────────────
par(mar = c(4, 2, 5, 1))
plot(NA, xlim = c(0, 10), ylim = c(0, 10), axes = FALSE, xlab = "", ylab = "",
     main = "PHASE 1 — TCEQ-permitted (75 MW)",
     cex.main = 1.05, font.main = 2, col.main = phases$phase1$color)

text(5, 9.0, "5 gas turbines (~15 MW each)",
     cex = 0.92, col = "#333333")
text(5, 8.5, sprintf("Improvements value: $%.2fB",
                     p1_80$imp_value / 1e9),
     cex = 0.92, col = "#333333")
text(5, 8.0, "Approved in 2.5 weeks, no public process",
     cex = 0.85, font = 3, col = "#a50f15")

text(5, 6.8, sprintf("$%.1fM/yr",
                     p1_80$forgone_yr / 1e6),
     cex = 2.0, font = 2, col = phases$phase1$color)
text(5, 6.2, "withheld from local jurisdictions",
     cex = 0.82, col = "#333333")
text(5, 5.7, "(under 80% Ch.312 abatement)",
     cex = 0.78, col = "#666666")

polygon(c(4.6, 5.4, 5.0), c(4.9, 4.9, 4.3), col = phases$phase1$color, border = NA)

text(5, 3.4, sprintf("$%sM",
                     format(round(p1_80$forgone_life / 1e6, 1), big.mark = ",")),
     cex = 2.5, font = 2, col = phases$phase1$color)
text(5, 2.7, sprintf("over the %d-year abatement", ABATE_YRS),
     cex = 0.92, col = "#333333")

text(5, 1.4, sprintf("Per family: $%s/yr ($%s over 10 yrs)",
                     format(round(p1_80$subsidy_share), big.mark = ","),
                     format(round(p1_80$subsidy_life),  big.mark = ",")),
     cex = 0.82, font = 2, col = "#333333")

# ── COLUMN 3 — BUILDOUT (implied future) ──────────────────────────────────
par(mar = c(4, 2, 5, 1))
plot(NA, xlim = c(0, 10), ylim = c(0, 10), axes = FALSE, xlab = "", ylab = "",
     main = "BUILDOUT — implied at 2,075-ac scale (1 GW)",
     cex.main = 1.05, font.main = 2, col.main = phases$buildout$color)

text(5, 9.0, "5 gas turbines @ ~200 MW each (frame class)",
     cex = 0.92, col = "#333333")
text(5, 8.5, sprintf("Improvements value: $%.1fB",
                     bo_80$imp_value / 1e9),
     cex = 0.92, col = "#333333")
text(5, 8.0, "Per Hotopp: Phase 1 'not enough' for ultimate buildout",
     cex = 0.82, font = 3, col = "#666666")

text(5, 6.8, sprintf("$%.1fM/yr",
                     bo_80$forgone_yr / 1e6),
     cex = 2.0, font = 2, col = phases$buildout$color)
text(5, 6.2, "withheld from local jurisdictions",
     cex = 0.82, col = "#333333")
text(5, 5.7, "(under 80% Ch.312 abatement)",
     cex = 0.78, col = "#666666")

polygon(c(4.6, 5.4, 5.0), c(4.9, 4.9, 4.3), col = phases$buildout$color, border = NA)

text(5, 3.4, sprintf("$%.2fB",
                     bo_80$forgone_life / 1e9),
     cex = 2.5, font = 2, col = phases$buildout$color)
text(5, 2.7, sprintf("over the %d-year abatement", ABATE_YRS),
     cex = 0.92, col = "#333333")

text(5, 1.4, sprintf("Per family: $%s/yr ($%s over 10 yrs)",
                     format(round(bo_80$subsidy_share), big.mark = ","),
                     format(round(bo_80$subsidy_life),  big.mark = ",")),
     cex = 0.82, font = 2, col = "#333333")

mtext("Sources: Parker CAD May-15-2026 corrected notices · James Hotopp testimony May-26-2026 commissioners court · WE-ISD 2025 rates · 80% Ch.312 abatement assumption",
      side = 1, line = 0.5, cex = 0.7, col = "#666666", outer = TRUE)
dev.off()
cat(sprintf("Wrote %s\n", png_path_B))

# ── PANEL C — sensitivity sweep, paired per phase ─────────────────────────
abates <- c(0.50, 0.80, 1.00)
abate_lbl <- c("50%\nabatement", "80%\nabatement\n(standard)", "100%\nabatement\n(AI-priority)")

# Build matrices: [phase, abatement]
p1_results <- lapply(abates, function(a) per_hh_cost(phases$phase1, a))
bo_results <- lapply(abates, function(a) per_hh_cost(phases$buildout, a))

p1_subsidy   <- sapply(p1_results, function(r) r$subsidy_share)
bo_subsidy   <- sapply(bo_results, function(r) r$subsidy_share)
p1_back      <- sapply(p1_results, function(r) r$rate_backfill)
bo_back      <- sapply(bo_results, function(r) r$rate_backfill)
p1_agg_life  <- sapply(p1_results, function(r) r$forgone_life)
bo_agg_life  <- sapply(bo_results, function(r) r$forgone_life)

png_path_C <- "scenario_BM_phases_C.png"
png(png_path_C, width = 2400, height = 1400, res = 170)
layout(matrix(c(1, 2, 3), nrow = 1), widths = c(1.1, 1.1, 1))

col_p1 <- phases$phase1$color
col_bo <- phases$buildout$color

# PANEL 1 — per-family annual subsidy share (paired Phase 1 vs Buildout)
par(mar = c(5, 5, 4, 1), family = "sans")
mat <- rbind(p1_subsidy, bo_subsidy)
bp <- barplot(mat, beside = TRUE, names.arg = abate_lbl,
              col = c(col_p1, col_bo), border = "white",
              ylim = c(0, max(mat) * 1.22),
              main = "Per-family annual subsidy share\n(Weatherford ISD homestead)",
              ylab = "$ per homestead per year",
              cex.main = 1.0, cex.names = 0.82, cex.lab = 0.92)
text(bp[1, ], p1_subsidy, sprintf("$%s",
     format(round(p1_subsidy), big.mark = ",")),
     pos = 3, cex = 0.78, font = 2, col = col_p1)
text(bp[2, ], bo_subsidy, sprintf("$%s",
     format(round(bo_subsidy), big.mark = ",")),
     pos = 3, cex = 0.78, font = 2, col = col_bo)
abline(h = 1871 + 1500, lty = 2, col = "#999999")
text(bp[2, 1] + 0.5, 1871 + 1500, "current avg WE homestead bill",
     pos = 3, cex = 0.7, col = "#666666")
legend("topleft",
       legend = c("Phase 1 (75 MW permitted)",
                  "Buildout (1 GW implied)"),
       fill = c(col_p1, col_bo), bty = "n", cex = 0.82)

# PANEL 2 — rate backfill (direct tax-bill increase)
par(mar = c(5, 5, 4, 1))
mat <- rbind(p1_back, bo_back)
bp <- barplot(mat, beside = TRUE, names.arg = abate_lbl,
              col = c(col_p1, col_bo), border = "white",
              ylim = c(0, max(mat) * 1.22),
              main = "Direct tax-bill increase\n(rate-backfill scenario)",
              ylab = "$ per homestead per year",
              cex.main = 1.0, cex.names = 0.82, cex.lab = 0.92)
text(bp[1, ], p1_back, sprintf("$%s",
     format(round(p1_back), big.mark = ",")),
     pos = 3, cex = 0.78, font = 2, col = col_p1)
text(bp[2, ], bo_back, sprintf("$%s",
     format(round(bo_back), big.mark = ",")),
     pos = 3, cex = 0.78, font = 2, col = col_bo)

# PANEL 3 — Parker aggregate (lifetime)
par(mar = c(5, 5, 4, 1))
mat <- rbind(p1_agg_life / 1e9, bo_agg_life / 1e9)
bp <- barplot(mat, beside = TRUE, names.arg = abate_lbl,
              col = c(col_p1, col_bo), border = "white",
              ylim = c(0, max(mat) * 1.22),
              main = "Parker County aggregate loss\n(10-year abatement, $B)",
              ylab = "$ billion total foregone",
              cex.main = 1.0, cex.names = 0.82, cex.lab = 0.92)
text(bp[1, ], p1_agg_life / 1e9,
     sprintf("$%.2fB", p1_agg_life / 1e9),
     pos = 3, cex = 0.78, font = 2, col = col_p1)
text(bp[2, ], bo_agg_life / 1e9,
     sprintf("$%.2fB", bo_agg_life / 1e9),
     pos = 3, cex = 0.78, font = 2, col = col_bo)

mtext("Subsidy share = per-HH allocation of foregone public revenue. Rate backfill = direct tax-bill increase if jurisdictions raise rates to recover the loss. Phase 1 = 75 MW TCEQ-permitted; Buildout = 1 GW implied at 2,075-ac scale.",
      side = 1, line = 0.5, cex = 0.7, col = "#666666", outer = TRUE)
dev.off()
cat(sprintf("Wrote %s\n", png_path_C))

# ── Print combined sensitivity table ──────────────────────────────────────
cat("\n══ Phase 1 vs Buildout — full sensitivity ══\n\n")
cat(sprintf("%-10s %-22s %-22s %-22s %s\n",
            "Abate", "Phase 1 subsidy/yr", "Phase 1 backfill/yr",
            "Buildout subsidy/yr", "Parker aggregate (10yr)"))
cat("─────────────────────────────────────────────────────────────────────────────────────────────\n")
for (i in seq_along(abates)) {
  cat(sprintf("%-10s $%-7s (LT $%-7s)  $%-7s (LT $%-7s)  $%-7s (LT $%-7s)  P1 $%-7s  Buildout $%.2fB\n",
              sprintf("%.0f%%", abates[i] * 100),
              format(round(p1_subsidy[i]),  big.mark = ","),
              format(round(p1_subsidy[i] * ABATE_YRS), big.mark = ","),
              format(round(p1_back[i]),     big.mark = ","),
              format(round(p1_back[i] * ABATE_YRS),    big.mark = ","),
              format(round(bo_subsidy[i]),  big.mark = ","),
              format(round(bo_subsidy[i] * ABATE_YRS), big.mark = ","),
              format(round(p1_agg_life[i] / 1e6), big.mark = ","),
              bo_agg_life[i] / 1e9))
}
