#!/usr/bin/env Rscript
# RCO_05g_scenarios.R — September 2026 rebuild of the Phase 1 / Buildout sections.
#
# WHY THIS REPLACES RCO_05d/RCO_05f AS THE PUBLIC-FACING MODEL
# -----------------------------------------------------------
# The June 2026 model produced a single number ($30M Phase 1 → $364M buildout)
# from a single assumption: an 80% Chapter 312 abatement. Parker County
# Commissioners Court Resolution 26-25 declines abatements for data centers
# ("there will be zero tax abatements for data centers in Parker County" —
# county judge, 2026-06-30 special session). The baseline therefore inverts:
# the default is that the improvements are FULLY TAXABLE, and abatement is a
# contingency, not the forecast.
#
# Three further corrections carried in here:
#   1. Scale is unknown, so scale is an AXIS, not an assumption. Each row is
#      labelled with its evidence class (PERMIT / TESTIMONY / DISCLOSED /
#      INFERRED) and no single cell is presented as "the" number.
#   2. JETI (Gov't Code Ch. 403) EXCLUDES data centers by NAICS code, and
#      Tax Code 312.002 bars school districts from granting Ch. 312 abatements.
#      So Weatherford ISD's 1.0342% — the largest single rate in play — is not
#      abatable against the data hall at all. Dispatchable generation (the gas
#      turbines) IS JETI-eligible, so the plant and the data hall are modelled
#      as separate improvement pools.
#   3. Ag rollback stays at 3 years + 5% interest (HB 1743, 2019). RCO_05c and
#      RCO_05d still compute 5 years and must not be re-run for publication.
#
# Outputs:
#   scenario_grid_A.png        — scale x abatement grid, 10-year local revenue
#   who_collects_B.png         — baseline (unabated) collection by jurisdiction
#   water_ceiling_C.png        — UTGCD groundwater ceiling vs cooling demand
#   scenario_table.csv         — the grid as data, for the HTML sections

suppressPackageStartupMessages({ library(data.table) })

IN  <- "../parker_costs"
PAL <- list(water = "#2c7fb8", power = "#e6783c", land = "#5da75a",
            peer  = "#b91c1c", fwpc  = "#6d28d9", gcd  = "#475569",
            unlit = "#f0e9dd", border = "#7a7367", title = "#1f2937",
            muted = "#475569", amber = "#d97706", green = "#1a6b3a")

# ── Land already on the rolls (unchanged, still the firmest number here) ────
bm <- fread(file.path(IN, "bm_parcels_2026.csv"))
bm[, has_corrected := any(notice_type == "CORRECTED"), by = prop_id]
bm_live <- rbind(bm[notice_type == "CORRECTED"],
                 bm[!has_corrected & notice_type == "ORIGINAL"])
bm_live <- unique(bm_live, by = "prop_id")
BM_ACRES        <- sum(bm_live$acres, na.rm = TRUE)
BM_TAX_LIVE     <- sum(bm_live$tax_at_ly_rate, na.rm = TRUE)
BM_TAX_AG       <- sum(unique(bm[notice_type == "ORIGINAL"], by = "prop_id")$tax_at_ly_rate,
                       na.rm = TRUE)
BM_NEW_LAND_REV <- BM_TAX_LIVE - BM_TAX_AG
BM_ROLLBACK     <- BM_NEW_LAND_REV * 3      # HB 1743: 3 yrs principal, 5% interest on top

# ── Rates (2025 adopted, parker_jurisdictions_2025.csv) ────────────────────
LOCAL_RATES <- c(county = 0.002459, ltr = 0.000533, hos = 0.000895,
                 col    = 0.001061, esd1 = 0.001000)   # Chapter 312-abatable
LOCAL_LABEL <- c(county = "County", ltr = "Lateral road", hos = "Hospital district",
                 col    = "Junior college", esd1 = "ESD-1")
CW_RATE <- sum(LOCAL_RATES)     # 0.005948
WE_RATE <- 0.010342             # Weatherford ISD — NOT Ch.312-abatable
TAXABLE_IMP <- 0.85             # taxable share of improvements value
TERM_YRS    <- 10               # Chapter 312 maximum term

# ── Scale scenarios ────────────────────────────────────────────────────────
# imp_dc  = data-hall improvements ($)   — JETI-ineligible, Ch.312-abatable
# imp_gen = generation improvements ($)  — JETI-eligible, Ch.312-abatable
# evidence: what class of record the scale rests on.
DC_CAPEX <- 8.0e6      # $/MW of IT load — industry planning figure, NOT a filing

scen <- data.table(
  sid      = c("gas", "phase1", "fw", "implied", "multi"),
  label    = c("Gas plant only\n5 turbines, no data hall",
               "Phase 1\n~75 MW of IT load + plant",
               "One Fort Worth-class campus\n187 ac, 4 bldgs, 2.2M sq ft",
               "1 GW, acreage-implied\n(the June 2026 assumption)",
               "Three FW-class campuses\nat 2,075-acre scale"),
  mw       = c(0, 75, NA, 1000, NA),
  imp_dc   = c(0, 75 * DC_CAPEX, 10.0e9, 1000 * DC_CAPEX, 30.0e9),
  imp_gen  = c(5 * 30e6, 5 * 30e6, 0, 5 * 200e6, 0),
  evidence = c("PERMIT", "TESTIMONY", "DISCLOSED", "INFERRED", "INFERRED"),
  note     = c("TCEQ Air New Source Reg. 179422 (RN112172408); turbine class assumed",
               "75 MW from Weatherford city manager testimony 2026-05-26, not the permit",
               "Developer's own Fort Worth project, $10B, site plan approved 7-4 on 2026-08-25",
               "Extrapolated from 2,075 acres; no filing supports it",
               "Upper bound: what the assembled acreage could physically hold")
)
scen[, imp_total := imp_dc + imp_gen]
scen[, taxable   := imp_total * TAXABLE_IMP]
scen[, local_yr  := taxable * CW_RATE]      # full non-school levy, unabated
scen[, school_yr := taxable * WE_RATE]      # WISD levy — not Ch.312-abatable

ABATES <- c(0.00, 0.50, 0.80)
ABATE_LAB <- c("NO ABATEMENT\n(Resolution 26-25 baseline)",
               "50% Ch.312\ncontingency",
               "80% Ch.312\n(June 2026 assumption)")

grid <- scen[rep(seq_len(.N), each = length(ABATES))]
grid[, abate := rep(ABATES, times = nrow(scen))]
grid[, local_collected_yr := local_yr * (1 - abate)]
grid[, local_foregone_yr  := local_yr * abate]
grid[, local_collected_term := local_collected_yr * TERM_YRS]
grid[, local_foregone_term  := local_foregone_yr  * TERM_YRS]
grid[, school_term := school_yr * TERM_YRS]      # unaffected by Ch.312
setorderv(grid, c("sid", "abate"))
fwrite(grid[, .(sid, label = gsub("\n", " ", label), evidence, mw,
                imp_total, abate, local_collected_yr, local_foregone_yr,
                local_collected_term, local_foregone_term, school_yr, school_term)],
       "scenario_table.csv")

fmtM <- function(x) {
  ifelse(is.na(x), "—",
    ifelse(abs(x) >= 1e9,  sprintf("$%.2fB", x / 1e9),
    ifelse(abs(x) >= 10e6, sprintf("$%.0fM", x / 1e6),
                           sprintf("$%.1fM", x / 1e6))))
}

# ════════════════════════════════════════════════════════════════════════
# CHART A — the scenario grid
# ════════════════════════════════════════════════════════════════════════
png("scenario_grid_A.png", width = 2600, height = 1580, res = 170)
par(mar = c(0, 0, 0, 0), family = "sans")
plot(NA, xlim = c(0, 100), ylim = c(0, 100), axes = FALSE, xlab = "", ylab = "")

text(2, 96.5, "What is actually at stake, by scale and by abatement",
     adj = 0, cex = 1.35, font = 2, col = PAL$title)
text(2, 92.6, paste("Ten-year local property tax on improvements — county, hospital district,",
                    "junior college, ESD-1 and lateral road only."),
     adj = 0, cex = 0.82, col = PAL$muted)
text(2, 89.8, paste("Weatherford ISD is shown separately: school districts cannot grant",
                    "Chapter 312 abatements and JETI excludes data centers, so that column does not move."),
     adj = 0, cex = 0.82, col = PAL$muted)

x_lab <- 2; x0 <- 34; col_w <- 17.5; x_sch <- x0 + 3 * col_w + 2.5
y_top <- 82; row_h <- 12.6

# column headers
for (j in seq_along(ABATES)) {
  cx <- x0 + (j - 1) * col_w + col_w / 2
  txt <- strsplit(ABATE_LAB[j], "\n")[[1]]
  text(cx, y_top + 4.6, txt[1], cex = 0.86, font = 2,
       col = if (j == 1) PAL$green else PAL$peer)
  text(cx, y_top + 1.9, txt[2], cex = 0.74, col = PAL$muted)
}
text(x_sch + col_w / 2 - 2, y_top + 4.6, "WEATHERFORD ISD", cex = 0.86, font = 2, col = PAL$water)
text(x_sch + col_w / 2 - 2, y_top + 1.9, "Ch.312 cannot reach it", cex = 0.74, col = PAL$muted)
segments(x_lab, y_top - 0.6, 98, y_top - 0.6, col = PAL$border, lwd = 1.2)

ev_col <- c(PERMIT = PAL$green, TESTIMONY = PAL$amber,
            DISCLOSED = PAL$water, INFERRED = PAL$peer)

for (i in seq_len(nrow(scen))) {
  s  <- scen[i]
  yc <- y_top - (i - 1) * row_h - row_h / 2
  if (i %% 2 == 0) rect(x_lab, yc - row_h / 2 + 0.4, 98, yc + row_h / 2 - 0.4,
                        col = "#faf9f6", border = NA)

  lab <- strsplit(s$label, "\n")[[1]]
  text(x_lab + 0.6, yc + 3.1, lab[1], adj = 0, cex = 0.92, font = 2, col = PAL$title)
  text(x_lab + 0.6, yc + 0.5, lab[2], adj = 0, cex = 0.76, col = PAL$muted)
  rect(x_lab + 0.6, yc - 4.2, x_lab + 0.6 + nchar(s$evidence) * 0.85 + 2, yc - 1.6,
       col = ev_col[[s$evidence]], border = NA)
  text(x_lab + 1.6, yc - 2.9, s$evidence, adj = 0, cex = 0.64, font = 2, col = "white")
  text(x_lab + 0.6 + nchar(s$evidence) * 0.85 + 3.5, yc - 2.9,
       sprintf("improvements %s", fmtM(s$imp_total)), adj = 0, cex = 0.72, col = PAL$muted)

  for (j in seq_along(ABATES)) {
    a  <- ABATES[j]
    cx <- x0 + (j - 1) * col_w
    g  <- grid[sid == s$sid & abs(abate - a) < 1e-9]
    if (j == 1) {
      rect(cx + 1, yc - 4.6, cx + col_w - 1, yc + 4.6, col = "#eef6ef", border = "#cfe3d2")
      text(cx + col_w / 2, yc + 1.7, fmtM(g$local_collected_term), cex = 1.22, font = 2,
           col = PAL$green)
      text(cx + col_w / 2, yc - 1.3, "collected over 10 yrs", cex = 0.68, col = PAL$muted)
      text(cx + col_w / 2, yc - 3.3, sprintf("%s/yr", fmtM(g$local_collected_yr)),
           cex = 0.72, col = PAL$muted)
    } else {
      rect(cx + 1, yc - 4.6, cx + col_w - 1, yc + 4.6, col = "#fdf1ef", border = "#f0d5d0")
      text(cx + col_w / 2, yc + 1.7, fmtM(g$local_foregone_term), cex = 1.22, font = 2,
           col = PAL$peer)
      text(cx + col_w / 2, yc - 1.3, "foregone over 10 yrs", cex = 0.68, col = PAL$muted)
      text(cx + col_w / 2, yc - 3.3, sprintf("%s still collected", fmtM(g$local_collected_term)),
           cex = 0.68, col = PAL$muted)
    }
  }
  g0 <- grid[sid == s$sid & abate == 0]
  rect(x_sch + 1, yc - 4.6, x_sch + col_w - 5, yc + 4.6, col = "#eef4f9", border = "#cfdeea")
  text(x_sch + (col_w - 4) / 2, yc + 1.7, fmtM(g0$school_term), cex = 1.22, font = 2,
       col = PAL$water)
  text(x_sch + (col_w - 4) / 2, yc - 1.3, "collected over 10 yrs", cex = 0.68, col = PAL$muted)
  text(x_sch + (col_w - 4) / 2, yc - 3.3, sprintf("%s/yr", fmtM(g0$school_yr)),
       cex = 0.72, col = PAL$muted)
}

y_foot <- y_top - nrow(scen) * row_h - 2
segments(x_lab, y_foot + 2.2, 98, y_foot + 2.2, col = PAL$border, lwd = 1.2)
text(x_lab, y_foot - 1.0, paste0(
  "Improvements taxed at ", TAXABLE_IMP * 100, "% of value; 2025 adopted rates ",
  "(county 0.2459, lateral road 0.0533, hospital 0.0895, junior college 0.1061, ESD-1 0.1000, WISD 1.0342 per $100). ",
  "No cell is a forecast."), adj = 0, cex = 0.72, col = PAL$muted)
text(x_lab, y_foot - 4.0, paste0(
  "Land already on the rolls, independent of any of this: $",
  format(round(BM_TAX_LIVE), big.mark = ","), "/yr after the May-15-2026 corrected notices ",
  "(was $", format(round(BM_TAX_AG), big.mark = ","), "/yr under ag), plus roughly $",
  format(round(BM_ROLLBACK), big.mark = ","), " of rollback tax — 3 years + 5% interest, Tax Code 23.55 as amended by HB 1743."),
  adj = 0, cex = 0.72, col = PAL$muted)
text(x_lab, y_foot - 7.0, paste0(
  "Evidence classes — PERMIT: in a filed public record. TESTIMONY: stated on the record by an official. ",
  "DISCLOSED: announced by the developer for another site. INFERRED: derived from acreage; no filing supports it."),
  adj = 0, cex = 0.72, font = 3, col = PAL$muted)
text(x_lab, y_foot - 10.0, paste0(
  "One exception to the ISD column: the five gas turbines are dispatchable generation and therefore JETI-eligible, so the ",
  "generation share of school M&O value could be limited. The data hall cannot be — JETI excludes data centers outright."),
  adj = 0, cex = 0.72, font = 3, col = PAL$muted)
dev.off()
cat("Wrote scenario_grid_A.png\n")

# ════════════════════════════════════════════════════════════════════════
# CHART B — who collects, unabated (the Resolution 26-25 baseline)
# ════════════════════════════════════════════════════════════════════════
png("who_collects_B.png", width = 2400, height = 1150, res = 170)
# One panel per scale, each on its own axis — the scenarios are three orders of
# magnitude apart, so a shared axis makes Phase 1 unreadable.
layout(matrix(1:3, nrow = 1))
par(oma = c(5.5, 1, 4.5, 1), family = "sans")

show      <- c("phase1", "fw", "implied")
show_lab  <- c("Phase 1 — ~75 MW", "One FW-class campus — $10B", "1 GW acreage-implied — $9B")
show_ev   <- c("TESTIMONY", "DISCLOSED", "INFERRED")
rates_all <- c(LOCAL_RATES, we = WE_RATE)
labs_all  <- c(LOCAL_LABEL, we = "Weatherford ISD")
cols <- c(county = PAL$power, ltr = "#f0b27a", hos = PAL$land,
          col = "#8fbf8c", esd1 = PAL$amber, we = PAL$water)

for (j in seq_along(show)) {
  v <- scen[sid == show[j], taxable] * rates_all / 1e6
  par(mar = c(4.5, 5.0, 3.2, 1))
  bp <- barplot(v, col = cols[names(rates_all)], border = "white",
                names.arg = rep("", length(v)), ylim = c(0, max(v) * 1.20),
                ylab = if (j == 1) "$ millions per year, unabated" else "",
                main = show_lab[j], cex.main = 1.0, cex.lab = 0.92, las = 1)
  text(bp, v, sprintf("$%.1fM", v), pos = 3, cex = 0.68, font = 2, col = PAL$title)
  text(bp, par("usr")[3] - max(v) * 0.055, labs_all[names(rates_all)],
       srt = 32, adj = 1, xpd = NA, cex = 0.74, col = PAL$muted)
  mtext(show_ev[j], side = 3, line = -0.1, cex = 0.6, font = 2,
        col = c(TESTIMONY = PAL$amber, DISCLOSED = PAL$water, INFERRED = PAL$peer)[show_ev[j]])
}
mtext("If it is built and not abated, this is who collects — every year",
      outer = TRUE, side = 3, line = 1.4, cex = 1.12, font = 2, col = PAL$title)
mtext(paste("Weatherford ISD is the largest recipient at every scale and the one a county abatement cannot touch:",
            "Tax Code 312.002 bars school districts from Chapter 312, and JETI (Gov't Code Ch. 403) excludes data centers."),
      outer = TRUE, side = 1, line = 1.9, cex = 0.72, col = PAL$muted)
mtext(paste("The five gas turbines are the one JETI-eligible asset on the site — dispatchable generation, not the data hall.",
            "Note the axes differ: these scenarios are orders of magnitude apart."),
      outer = TRUE, side = 1, line = 3.0, cex = 0.72, font = 3, col = PAL$muted)
dev.off()
cat("Wrote who_collects_B.png\n")

# ════════════════════════════════════════════════════════════════════════
# CHART C — the groundwater ceiling (UTGCD rules adopted 2026-08-27)
# ════════════════════════════════════════════════════════════════════════
# Rule 5.2: Trinity allocation = 500 gal/acre x lesser of (well depth, average
# aquifer thickness on the property), capped at 250,000 gal/acre/yr, floor
# 25,000. Rule 2.10-2.12: an operating permit of 25,000,000 gal/yr or more in
# the Trinity is a High-Volume Permit Application — hydrogeologic investigation,
# aquifer testing, enhanced notice, and a contestable hearing.
# Allocation is 500 gal/acre x aquifer thickness (ft), so the thickness at the
# tract is what sets the ceiling. Shown across the plausible Trinity range.
THICK <- c(50, 120, 250, 500)                       # ft of Trinity section
ALLOC <- pmin(pmax(500 * THICK, 25000), 250000)     # gal/acre/yr after floor + cap
ceiling_mgal <- BM_ACRES * ALLOC / 1e6

# ── TOTAL-SYSTEM water, not just the cooling tower ─────────────────────────
# A closed-loop design moves water off the site; it does not remove it from the
# system. Two things have to be counted together:
#   DIRECT    — makeup water at the data hall (WUE, gal per kWh of IT load)
#   INDIRECT  — water consumed generating the electricity the facility draws,
#               which is total facility energy (IT load x PUE), not IT load
# Closed-loop rejection also costs efficiency, so PUE rises and the indirect
# term grows exactly as the direct term shrinks.
#
# Generation factors (gal per kWh generated), Texas-specific where available:
#   gas turbine, WET NOx control (water injection) .... 0.05   TWDB, Power
#   gas turbine, DRY NOx control (e.g. SCR) .......... ~0      Generation Water
#   combined cycle, cooling tower .................... 0.23    Use in Texas
#   combined cycle, once-through ..................... 0.15    (TWDB report)
# Cross-check: Macknick et al. (NREL/TP-6A20-50900) medians — NGCC with tower
# 205 gal/MWh (0.205), once-through 100 (0.100), dry cooling 2 (0.002).
#
# Direct factors (gal per kWh of IT load):
#   open-loop evaporative ............................ 0.10-0.50
#   closed-loop / direct-to-chip ..................... 0.005-0.02
# Real-world anchor: Vantage's closed-loop Wisconsin campus reports ~22,000
# gal/day peak against ~5,000,000 gal/day for an evaporative campus of similar
# scale — about 0.4%.
gal_per_mw_yr <- function(gal_kwh) gal_kwh * 8760 * 1000

IT_MW <- 75      # IT load for the configuration comparison; everything scales linearly

cfg <- data.table(
  lab      = c("Evaporative\n+ dry NOx",
               "Evaporative\n+ wet NOx",
               "Closed-loop\n+ dry NOx",
               "Closed-loop\n+ wet NOx",
               "Closed-loop\n+ grid / CC"),
  pue      = c(1.15, 1.15, 1.30, 1.30, 1.30),
  dir_lo   = c(0.10, 0.10, 0.005, 0.005, 0.005),
  dir_hi   = c(0.50, 0.50, 0.020, 0.020, 0.020),
  gen      = c(0.00, 0.05, 0.000, 0.050, 0.230),
  col      = c(PAL$peer, PAL$peer, PAL$land, PAL$amber, PAL$power))
cfg[, dir_mid  := (dir_lo + dir_hi) / 2]
cfg[, direct   := IT_MW * gal_per_mw_yr(dir_mid) / 1e6]                 # Mgal/yr
cfg[, dir_lo_m := IT_MW * gal_per_mw_yr(dir_lo) / 1e6]
cfg[, dir_hi_m := IT_MW * gal_per_mw_yr(dir_hi) / 1e6]
cfg[, indirect := IT_MW * pue * gal_per_mw_yr(gen) / 1e6]               # Mgal/yr
cfg[, total    := direct + indirect]
fwrite(cfg, "water_system_configs.csv")

png("water_ceiling_C.png", width = 2500, height = 1250, res = 170)
layout(matrix(1:2, nrow = 1), widths = c(0.85, 1.15))
par(oma = c(7.2, 1, 4.4, 1), family = "sans")
ymax <- max(c(ceiling_mgal, cfg$total, cfg$dir_hi_m)) * 1.14

# LEFT — what the tract may legally produce
par(mar = c(4.2, 5.2, 2.6, 1))
bp <- barplot(ceiling_mgal, col = PAL$water, border = "white", ylim = c(0, ymax),
              names.arg = sprintf("%d ft\n%s gal/ac", THICK,
                                  format(ALLOC, big.mark = ",", trim = TRUE)),
              ylab = "million gallons per year", las = 1,
              main = sprintf("SUPPLY — what %s acres may legally produce",
                             format(round(BM_ACRES), big.mark = ",")),
              cex.main = 0.98, cex.names = 0.74, cex.lab = 0.9)
text(bp, ceiling_mgal, sprintf("%.0f", ceiling_mgal), pos = 3, cex = 0.76, font = 2, col = PAL$water)
abline(h = 25, lty = 3, col = PAL$peer, lwd = 1.6)
text(mean(bp), ymax * 0.92, "25 Mgal/yr — High-Volume Permit threshold",
     cex = 0.68, col = PAL$peer)
mtext("Trinity thickness at the tract (UTGCD Rule 5.2: 500 gal/acre x thickness, floor 25,000, cap 250,000)",
      side = 1, line = 3.4, cex = 0.68, col = PAL$muted)

# RIGHT — total system demand: cooling PLUS the water behind the power
par(mar = c(4.2, 5.2, 2.6, 1))
plot(NA, xlim = c(0.35, nrow(cfg) + 0.65), ylim = c(0, ymax), axes = FALSE,
     xlab = "", ylab = "",
     main = sprintf("DEMAND — the whole system, at %d MW of IT load", IT_MW),
     cex.main = 0.98)
axis(2, las = 1, cex.axis = 0.9)
for (i in seq_len(nrow(cfg))) {
  d <- cfg$direct[i]; g <- cfg$indirect[i]
  rect(i - 0.34, 0, i + 0.34, d, col = adjustcolor(PAL$water, 0.85), border = "white")
  rect(i - 0.34, d, i + 0.34, d + g, col = adjustcolor(PAL$power, 0.85), border = "white")
  segments(i, cfg$dir_lo_m[i], i, cfg$dir_hi_m[i], col = PAL$title, lwd = 1.4)
  segments(i - 0.10, cfg$dir_lo_m[i], i + 0.10, cfg$dir_lo_m[i], col = PAL$title, lwd = 1.4)
  segments(i - 0.10, cfg$dir_hi_m[i], i + 0.10, cfg$dir_hi_m[i], col = PAL$title, lwd = 1.4)
  text(i, d + g, sprintf("%.0f", d + g), pos = 3, cex = 0.78, font = 2, col = cfg$col[i])
  text(i, par("usr")[3] - ymax * 0.06, cfg$lab[i], xpd = NA, cex = 0.68, col = PAL$muted)
}
abline(h = 25, lty = 3, col = PAL$peer, lwd = 1.6)
legend("topright", bty = "n", cex = 0.74,
       fill = c(adjustcolor(PAL$water, 0.85), adjustcolor(PAL$power, 0.85)),
       legend = c("Direct — makeup water at the data hall",
                  "Indirect — water consumed making its electricity"))
mtext(paste("Cooling choice + how the power is made. \"dry/wet NOx\" = the on-site turbines' NOx control;",
            "\"grid / CC\" = grid supply or an on-site combined cycle."),
      side = 1, line = 3.2, cex = 0.66, col = PAL$muted)
mtext("Whisker = the direct-cooling range; the stack uses its midpoint. Indirect is charged on IT load x PUE.",
      side = 1, line = 4.2, cex = 0.66, col = PAL$muted)

mtext("Closed-loop moves the water; it does not remove it from the system",
      outer = TRUE, side = 3, line = 1.3, cex = 1.14, font = 2, col = PAL$title)
mtext(paste("Direct: 0.10-0.50 gal/kWh evaporative, 0.005-0.02 closed-loop. Indirect: 0.05 gal/kWh for a gas turbine with wet NOx control,",
            "~0 with dry control, 0.23 for combined cycle with a cooling tower (TWDB, Power Generation Water Use in Texas;"),
      outer = TRUE, side = 1, line = 2.3, cex = 0.7, col = PAL$muted)
mtext(paste("cross-checked against Macknick et al., NREL/TP-6A20-50900). PUE 1.15 evaporative, 1.30 closed-loop — the efficiency penalty is",
            "why the indirect bar grows as the direct bar shrinks. Everything scales linearly with IT load: multiply by 6.7 for 500 MW."),
      outer = TRUE, side = 1, line = 3.3, cex = 0.7, col = PAL$muted)
mtext(paste("If the power is made on this tract, both bars draw on the same aquifer and count against the same allocation.",
            "The 5-acre minimum-tract rule adopted 2026-08-27 governs the district's WESTERN thin-aquifer edge, not this tract."),
      outer = TRUE, side = 1, line = 4.4, cex = 0.7, font = 3, col = PAL$muted)
dev.off()
cat("Wrote water_ceiling_C.png\n")

# ── Console summary ────────────────────────────────────────────────────────
cat("\n== Scenario grid: 10-year local revenue (county + districts) ==\n\n")
cat(sprintf("%-34s %-10s %14s %14s %14s %14s\n", "Scenario", "Evidence",
            "Improvements", "Collected 0%", "Foregone 50%", "Foregone 80%"))
cat(strrep("-", 106), "\n")
for (k in scen$sid) {
  s <- scen[sid == k]
  g <- function(a, col) grid[sid == k & abs(abate - a) < 1e-9][[col]]
  cat(sprintf("%-34s %-10s %14s %14s %14s %14s\n",
              gsub("\n", " / ", s$label), s$evidence, fmtM(s$imp_total),
              fmtM(g(0.00, "local_collected_term")),
              fmtM(g(0.50, "local_foregone_term")),
              fmtM(g(0.80, "local_foregone_term"))))
}
cat("\nWeatherford ISD, 10 yrs, not abatable:\n")
for (k in scen$sid) cat(sprintf("  %-34s %s\n", gsub("\n", " / ", scen[sid == k]$label),
                                fmtM(grid[sid == k & abate == 0]$school_term)))
cat(sprintf("\nGroundwater ceiling on %s ac: %.0f-%.0f Mgal/yr (%.2f-%.2f MGD)\n",
            format(round(BM_ACRES), big.mark = ","), min(ceiling_mgal), max(ceiling_mgal),
            min(ceiling_mgal) * 1e6 / 365 / 1e6, max(ceiling_mgal) * 1e6 / 365 / 1e6))
