#!/usr/bin/env Rscript
# RCO_05f_local_net.R — CORRECTED cost model.
# Separates the NET LOCAL loss (county + special districts, Chapter 312, no
# state backfill) from the SCHOOL portion (Weatherford ISD), which is a
# separate Chapter 313/JETI matter and is largely backfilled by the state
# school-finance formula — therefore NOT a net local loss and NOT this court's
# decision.
#
# Verified basis (TEA / Comptroller / Tax Code):
#   - Tax Code 312.002: school districts CANNOT grant Chapter 312 abatements.
#   - School M&O value limitations (313/JETI) are substantially replaced by
#     state funds via the Foundation School Program. School I&S is not limited.
#   - County, hospital district, ESD, junior college, lateral road (Chapter 312)
#     have NO state backfill — pure local loss.
#
# Outputs (overwrite the briefing's figures):
#   scenario_BM_phases_B.png  — Today / Phase 1 / Buildout, NET LOCAL figures
#   scenario_BM_phases_C.png  — sensitivity: net local loss, Phase 1 vs Buildout

suppressPackageStartupMessages({ library(data.table) })

# ── Anchored Parker CAD reality (land already on the rolls) ────────────────
bm <- fread("bm_parcels_2026.csv")
bm[, has_corrected := any(notice_type == "CORRECTED"), by = prop_id]
bm_live <- rbind(bm[notice_type == "CORRECTED"],
                 bm[!has_corrected & notice_type == "ORIGINAL"])
bm_live <- unique(bm_live, by = "prop_id")
BM_LAND_VAL     <- sum(bm_live$ty_land, na.rm = TRUE)
BM_TAX_LIVE     <- sum(bm_live$tax_at_ly_rate, na.rm = TRUE)
BM_TAX_AG       <- sum(unique(bm[notice_type == "ORIGINAL"], by = "prop_id")$tax_at_ly_rate, na.rm = TRUE)
BM_NEW_LAND_REV <- BM_TAX_LIVE - BM_TAX_AG
# Ag rollback: HB 1743 (eff. 2019-09-01) cut the recapture period from 5 to 3
# years and interest from 7% to 5%. Principal = 3 yrs of the market-vs-ag tax
# difference; 5% statutory interest applies on top (not included in principal).
BM_ROLLBACK     <- BM_NEW_LAND_REV * 3

# ── Rates ──────────────────────────────────────────────────────────────────
# Non-school LOCAL jurisdictions (Chapter 312, NO backfill):
LOCAL_RATES <- c(county = 0.002459, ltr = 0.000533, hos = 0.000895,
                 col = 0.001061, esd1 = 0.001000)
CW_RATE  <- sum(LOCAL_RATES)        # 0.005948  — net local
WE_RATE  <- 0.010342                # Weatherford ISD (school; backfilled M&O)
PA_HH    <- 46404                   # county-wide households (county/hosp/col/ltr/esd)

ABATE_YRS   <- 10
TAXABLE_IMP <- 0.85

phases <- list(
  phase1   = list(short = "Phase 1",  mw = 75,   t_cost = 30,  color = "#d97706"),
  buildout = list(short = "Buildout", mw = 1000, t_cost = 200, color = "#a50f15")
)
DC_CAPEX <- 8.0   # $M/MW
TURBINES <- 5

calc <- function(phase, abate) {
  imp_val  <- (phase$mw * DC_CAPEX + TURBINES * phase$t_cost) * 1e6
  imp_tax  <- imp_val * TAXABLE_IMP
  net_local_yr <- imp_tax * CW_RATE * abate          # no backfill — real local loss
  school_yr    <- imp_tax * WE_RATE * abate          # school: separate / state-backfilled
  # net out the non-school share of the new land revenue already flowing
  land_local_yr <- BM_NEW_LAND_REV * (CW_RATE / (CW_RATE + WE_RATE))
  list(
    imp_val        = imp_val,
    net_local_yr   = net_local_yr,
    net_local_life = net_local_yr * ABATE_YRS,
    net_local_hh   = net_local_yr / PA_HH,
    net_local_hh_life = (net_local_yr / PA_HH) * ABATE_YRS,
    school_yr      = school_yr,
    school_life    = school_yr * ABATE_YRS,
    land_local_yr  = land_local_yr
  )
}

p1 <- calc(phases$phase1,   0.80)
bo <- calc(phases$buildout, 0.80)

# ════════════════════════════════════════════════════════════════════════
# CHART B — Today / Phase 1 / Buildout, NET LOCAL figures
# ════════════════════════════════════════════════════════════════════════
png("scenario_BM_phases_B.png", width = 2400, height = 1300, res = 170)
layout(matrix(c(1, 2, 3), nrow = 1))
par(family = "sans")

# COLUMN 1 — TODAY
par(mar = c(4, 2, 5, 1))
plot(NA, xlim = c(0, 10), ylim = c(0, 10), axes = FALSE, xlab = "", ylab = "",
     main = "TODAY — May-15-2026 corrected notices",
     cex.main = 1.05, font.main = 2, col.main = "#1a6b3a")
text(5, 9.0, "Parker CAD stripped the ag exemption", cex = 0.92, col = "#333333")
text(5, 8.5, "from all 18 Black Mountain parcels (2,075 ac)", cex = 0.92, col = "#333333")
text(5, 7.3, sprintf("$%s/yr", format(round(BM_TAX_AG), big.mark = ",")), cex = 1.4, col = "#999999")
text(5, 6.8, "land tax BEFORE the correction", cex = 0.78, col = "#666666")
polygon(c(4.6, 5.4, 5.0), c(6.1, 6.1, 5.5), col = "#1a6b3a", border = NA)
text(5, 4.6, sprintf("$%s/yr", format(round(BM_TAX_LIVE), big.mark = ",")),
     cex = 2.3, font = 2, col = "#1a6b3a")
text(5, 3.9, "land tax NOW flowing — to schools,", cex = 0.85, col = "#333333")
text(5, 3.4, "county, hospital, college, ESD-1", cex = 0.85, col = "#333333")
text(5, 2.1, sprintf("Plus $%s", format(round(BM_ROLLBACK), big.mark = ",")),
     cex = 0.92, font = 2, col = "#a50f15")
text(5, 1.6, "rollback tax — 3 yrs + 5% int. (TX §23.55, 2019)", cex = 0.75, col = "#a50f15")

# COLUMN 2 — PHASE 1
draw_phase <- function(p, label, sub, color) {
  par(mar = c(4, 2, 5, 1))
  plot(NA, xlim = c(0, 10), ylim = c(0, 10), axes = FALSE, xlab = "", ylab = "",
       main = label, cex.main = 1.05, font.main = 2, col.main = color)
  text(5, 9.0, sub, cex = 0.9, col = "#333333")
  text(5, 8.5, sprintf("Improvements value: $%.2fB", p$imp_val / 1e9), cex = 0.9, col = "#333333")
  text(5, 8.0, "if the county grants an 80% Ch.312 abatement", cex = 0.8, font = 3, col = "#666666")
  text(5, 6.7, sprintf("$%.1fM/yr", p$net_local_yr / 1e6), cex = 2.0, font = 2, col = color)
  text(5, 6.1, "NET LOCAL revenue lost", cex = 0.85, font = 2, col = "#333333")
  text(5, 5.6, "county · hospital · college · ESD · roads", cex = 0.74, col = "#666666")
  text(5, 5.1, "(no state backfill — gone)", cex = 0.74, font = 3, col = "#666666")
  polygon(c(4.6, 5.4, 5.0), c(4.4, 4.4, 3.8), col = color, border = NA)
  text(5, 3.0, sprintf("$%sM", format(round(p$net_local_life / 1e6, 1), big.mark = ",")),
       cex = 2.4, font = 2, col = color)
  text(5, 2.4, sprintf("net local, over the %d-year abatement", ABATE_YRS), cex = 0.9, col = "#333333")
  text(5, 1.4, sprintf("≈ $%s/yr per county household", format(round(p$net_local_hh), big.mark = ",")),
       cex = 0.82, font = 2, col = "#333333")
  text(5, 0.9, "School portion is separate (state-backfilled)", cex = 0.72, font = 3, col = "#888888")
}
draw_phase(p1, "PHASE 1 — TCEQ-permitted (75 MW)", "5 gas turbines (~15 MW each)", phases$phase1$color)
draw_phase(bo, "BUILDOUT — implied at 2,075-ac scale (1 GW)", "5 frame turbines (~200 MW each)", phases$buildout$color)

mtext("NET LOCAL = county + hospital + junior college + ESD + lateral road (Chapter 312, no state backfill). School district (Weatherford ISD) is a separate Chapter 313/JETI matter, largely backfilled by the state — not counted here. Sources: Parker CAD May-15-2026 · WE-area 2025 rates · 80% abatement assumption.",
      side = 1, line = 0.4, cex = 0.62, col = "#666666", outer = TRUE)
dev.off()
cat("Wrote scenario_BM_phases_B.png\n")

# ════════════════════════════════════════════════════════════════════════
# CHART C — sensitivity: NET LOCAL loss, Phase 1 vs Buildout
# ════════════════════════════════════════════════════════════════════════
abates    <- c(0.50, 0.80, 1.00)
abate_lbl <- c("50%", "80%\n(standard)", "100%")
p1s <- lapply(abates, function(a) calc(phases$phase1, a))
bos <- lapply(abates, function(a) calc(phases$buildout, a))

p1_hh   <- sapply(p1s, function(r) r$net_local_hh)
bo_hh   <- sapply(bos, function(r) r$net_local_hh)
p1_life <- sapply(p1s, function(r) r$net_local_life)
bo_life <- sapply(bos, function(r) r$net_local_life)

png("scenario_BM_phases_C.png", width = 2400, height = 1300, res = 170)
layout(matrix(c(1, 2), nrow = 1), widths = c(1, 1))
col_p1 <- phases$phase1$color; col_bo <- phases$buildout$color
par(family = "sans")

# PANEL 1 — net local loss per county household per year
par(mar = c(5, 5, 5, 1))
mat <- rbind(p1_hh, bo_hh)
bp <- barplot(mat, beside = TRUE, names.arg = abate_lbl,
              col = c(col_p1, col_bo), border = "white",
              ylim = c(0, max(mat) * 1.25),
              main = "Net LOCAL revenue lost\nper county household, per year",
              ylab = "$ per county household / year", cex.main = 1.0, cex.names = 0.85, cex.lab = 0.9)
text(bp[1, ], p1_hh, sprintf("$%s", format(round(p1_hh), big.mark = ",")), pos = 3, cex = 0.78, font = 2, col = col_p1)
text(bp[2, ], bo_hh, sprintf("$%s", format(round(bo_hh), big.mark = ",")), pos = 3, cex = 0.78, font = 2, col = col_bo)
legend("topleft", legend = c("Phase 1 (75 MW permitted)", "Buildout (1 GW implied)"),
       fill = c(col_p1, col_bo), bty = "n", cex = 0.82)

# PANEL 2 — aggregate net local loss, 10-year
par(mar = c(5, 5, 5, 1))
mat <- rbind(p1_life / 1e6, bo_life / 1e6)
bp <- barplot(mat, beside = TRUE, names.arg = abate_lbl,
              col = c(col_p1, col_bo), border = "white",
              ylim = c(0, max(mat) * 1.25),
              main = "Net LOCAL revenue lost\nParker County total, 10-year abatement",
              ylab = "$ million total (net local)", cex.main = 1.0, cex.names = 0.85, cex.lab = 0.9)
text(bp[1, ], p1_life / 1e6, sprintf("$%.0fM", p1_life / 1e6), pos = 3, cex = 0.78, font = 2, col = col_p1)
text(bp[2, ], bo_life / 1e6, sprintf("$%.0fM", bo_life / 1e6), pos = 3, cex = 0.78, font = 2, col = col_bo)

mtext("Net local loss = county + hospital + junior college + ESD + lateral road foregone revenue (Chapter 312, no state backfill). Excludes the school-district portion, which is a separate state-backfilled JETI matter. Phase 1 = 75 MW permitted; Buildout = 1 GW implied at 2,075-ac scale.",
      side = 1, line = 0.4, cex = 0.62, col = "#666666", outer = TRUE)
dev.off()
cat("Wrote scenario_BM_phases_C.png\n")

# ── Print the numbers for the briefing ─────────────────────────────────────
cat(sprintf("\nAg rollback (3 yrs, principal, +5%% interest on top): $%s\n",
            format(round(BM_ROLLBACK), big.mark = ",")))
cat("\n══ CORRECTED — NET LOCAL loss (county + special districts, 80% abatement) ══\n")
cat(sprintf("Phase 1   : $%.2fM/yr  |  $%.1fM over 10yr  |  $%.0f/yr per county HH  ($%s/10yr)\n",
            p1$net_local_yr/1e6, p1$net_local_life/1e6, p1$net_local_hh,
            format(round(p1$net_local_hh_life), big.mark=",")))
cat(sprintf("Buildout  : $%.2fM/yr  |  $%.0fM over 10yr  |  $%.0f/yr per county HH  ($%s/10yr)\n",
            bo$net_local_yr/1e6, bo$net_local_life/1e6, bo$net_local_hh,
            format(round(bo$net_local_hh_life), big.mark=",")))
cat(sprintf("\nSchool portion (separate, state-backfilled, NOT local loss):\n"))
cat(sprintf("Phase 1 school ~$%.1fM/10yr  |  Buildout school ~$%.0fM/10yr\n",
            p1$school_life/1e6, bo$school_life/1e6))
cat(sprintf("\nCheck: total (local+school) Buildout 10yr = $%.0fM  (prior model said ~$1.0B)\n",
            (bo$net_local_life + bo$school_life)/1e6))
