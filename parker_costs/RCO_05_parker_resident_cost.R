#!/usr/bin/env Rscript
# RCO_05_parker_resident_cost.R — Parker County data-center scenario modeler.
#
# Inputs:  a hypothetical facility (MW, capex, ISD, abatement terms, cooling).
# Outputs: per-household per-year cost for a homestead in the chosen ISD,
#          plus total over the abatement lifetime, plus per-channel breakdown.
#
# Three channels, each with explicit assumptions documented inline:
#   1. Tax abatement      — sourced from pg01.parker.xent (2025 rates) +
#                           parker_property homestead counts per ISD
#   2. Power (Oncor/ERCOT) — literature-anchored coefficients with ranges
#   3. Water (UTGCD area)  — TWDB-survey-anchored gallons/MW + utility rate lift
#
# Run examples (from this directory):
#   Rscript RCO_05_parker_resident_cost.R                    # default 100 MW Aledo
#   Rscript RCO_05_parker_resident_cost.R --mw 250 --isd WE  # 250 MW Weatherford
#   Rscript RCO_05_parker_resident_cost.R --capex 5 --abate 0.5 --cooling closed
# Outputs to parker_costs/scenario_<isd>_<mw>MW.png and a text summary.

suppressPackageStartupMessages({
  library(data.table); library(optparse)
})

# ── CLI ────────────────────────────────────────────────────────────────────
opts <- OptionParser(option_list = list(
  make_option(c("--mw"),       type="numeric",   default=100,  help="Facility MW [default: %default]"),
  make_option(c("--capex"),    type="numeric",   default=10,   help="Capex per MW in $M [default: %default]"),
  make_option(c("--taxable"),  type="numeric",   default=0.80, help="Taxable share of capex [default: %default]"),
  make_option(c("--abate"),    type="numeric",   default=0.70, help="Abatement % (fraction abated) [default: %default]"),
  make_option(c("--years"),    type="integer",   default=10,   help="Abatement term [default: %default]"),
  make_option(c("--isd"),      type="character", default="AL", help="ISD code (AL/WE/SP/AZ/BR/PE/MI/PO/GA) [default: %default]"),
  make_option(c("--cooling"),  type="character", default="evap", help="Cooling: evap or closed [default: %default]"),
  make_option(c("--out"),      type="character", default=".", help="Output directory")
)) |> parse_args()

# ── Load jurisdictions ─────────────────────────────────────────────────────
juris <- fread("parker_jurisdictions_2025.csv")
juris[, rate := as.numeric(rate)]
juris[, n_homestead := as.integer(n_homestead)]
PARKER_TOTAL_HH <- 46404   # 2024 homesteads countywide

# Select the user's ISD
isd_row <- juris[code == opts$isd & type == "SCHOOL"]
if (!nrow(isd_row)) stop("Unknown ISD code: ", opts$isd)
isd_name <- isd_row$descr
isd_rate <- isd_row$rate
isd_hh   <- isd_row$n_homestead

# Countywide jurisdictions that apply to every Parker parcel
countywide_codes <- c("PAR","COL","HOS","LTR")    # County, JR College, Hospital, Lateral Road
countywide <- juris[code %in% countywide_codes]

# ── Channel 1: Tax abatement ───────────────────────────────────────────────
# Taxable value of the facility (in $M)
taxable_value_M <- opts$mw * opts$capex * opts$taxable
# Abated value — the share NOT taxed
abated_value_M  <- taxable_value_M * opts$abate

# Per-year foregone tax by jurisdiction ($/yr)
isd_foregone_per_yr <- abated_value_M * 1e6 * isd_rate
cw_foregone_per_yr  <- countywide[, sum(rate)] * abated_value_M * 1e6

# Allocate to a typical homestead in the selected ISD:
#   ISD-level cost spread over ISD HH; countywide spread over Parker HH.
cost_isd_per_hh_per_yr <- isd_foregone_per_yr / isd_hh
cost_cw_per_hh_per_yr  <- cw_foregone_per_yr  / PARKER_TOTAL_HH
tax_cost_per_hh_per_yr <- cost_isd_per_hh_per_yr + cost_cw_per_hh_per_yr
tax_cost_per_hh_lifetime <- tax_cost_per_hh_per_yr * opts$years

# Per-jurisdiction breakdown (for the chart)
juris_breakdown <- data.table(
  channel = "tax",
  jurisdiction = c(isd_name, countywide$descr),
  rate         = c(isd_rate, countywide$rate),
  foregone_yr  = c(isd_foregone_per_yr, abated_value_M*1e6*countywide$rate),
  hh_pool      = c(isd_hh, rep(PARKER_TOTAL_HH, nrow(countywide))),
  cost_per_hh_yr = c(cost_isd_per_hh_per_yr,
                     abated_value_M*1e6*countywide$rate / PARKER_TOTAL_HH)
)

# ── Channel 2: Power (Oncor TDU + ERCOT wholesale) ─────────────────────────
# Assumptions documented inline. Coefficients from ERCOT load-zone studies and
# TDU rate-case analyses; treat as central-tendency estimates with ±50% range.
#
# Oncor pass-through (transmission upgrades to serve the new load):
#   ~1.5% of $5M/MW T&D capex spread over 30 years across ~12M Oncor meters.
#   Annual residential allocation ≈ ($5M/MW × 0.015 / 30) × MW / 12M = small.
ONCOR_METERS         <- 12e6
ONCOR_TD_CAPEX_PER_MW <- 5e6    # $ in transmission/distribution per MW served
ONCOR_PASSTHROUGH_PCT <- 0.015  # share recovered through rate cases
ONCOR_AMORT_YEARS    <- 30

oncor_annual_recovery <- opts$mw * ONCOR_TD_CAPEX_PER_MW *
                          ONCOR_PASSTHROUGH_PCT / ONCOR_AMORT_YEARS
oncor_per_hh_per_yr   <- oncor_annual_recovery / ONCOR_METERS

# ERCOT-wide wholesale lift: ~$1.50/MWh per GW of new load in a zone for 3-5 yr
# Convert to per-MW per-resident: small but multiplies fast at scale.
# Use 4-year horizon; residential share of zone draw ≈ 35%; ~12M MWh annual residential draw.
ZONE_WHOLESALE_LIFT_PER_GW_PER_MWH <- 1.50    # $/MWh
ZONE_RES_DRAW_MWH                  <- 12e6
ZONE_HORIZON_YEARS                 <- 4
wholesale_zone_total_yr <- (opts$mw / 1000) * ZONE_WHOLESALE_LIFT_PER_GW_PER_MWH *
                            ZONE_RES_DRAW_MWH / ZONE_HORIZON_YEARS
wholesale_per_hh_per_yr <- wholesale_zone_total_yr / ONCOR_METERS  # spread same pool

# Note: this is amortized — only counted for first ZONE_HORIZON_YEARS of life.
# For lifetime, we sum oncor (constant) + wholesale (4 of 10 years).
power_per_hh_per_yr     <- oncor_per_hh_per_yr + wholesale_per_hh_per_yr
power_per_hh_lifetime   <- oncor_per_hh_per_yr * opts$years +
                            wholesale_per_hh_per_yr * min(ZONE_HORIZON_YEARS, opts$years)

# ── Channel 3: Water (UTGCD area) ──────────────────────────────────────────
# Parker is in Upper Trinity GCD. UTGCD permits wells but is fee-only
# (no tax authority) per LBB SB1983. Water cost shows up as utility-rate
# lift in the local supply area (~30K households on groundwater in Parker).
WATER_GAL_PER_MW_YR    <- if (opts$cooling == "closed") 0.3e6 else 1.5e6
PARKER_WATER_HH        <- 30000   # estimate of Parker households on UTGCD-area supply
UTILITY_RATE_LIFT_PCT  <- 0.01    # 1% rate-lift to absorb the new draw (central estimate)
AVG_RESIDENTIAL_WATER_BILL <- 720 # $/HH/yr (Parker-area municipal water rates)
water_per_hh_per_yr   <- AVG_RESIDENTIAL_WATER_BILL * UTILITY_RATE_LIFT_PCT
water_per_hh_lifetime <- water_per_hh_per_yr * opts$years

# ── Combined ───────────────────────────────────────────────────────────────
total_per_yr  <- tax_cost_per_hh_per_yr + power_per_hh_per_yr + water_per_hh_per_yr
total_lifetime <- tax_cost_per_hh_lifetime + power_per_hh_lifetime + water_per_hh_lifetime

# Comparison: average homestead tax in the selected ISD (rough)
avg_hs_tax_in_isd <- isd_row$n_homestead  # placeholder; compute below
avg_hs_tax_in_isd <- median(
  c(1871, 4576, 1629, 2397, 4214, 2848, 1957, 1476, 1210, 2569, 1205, 523, 845)
)   # Will be replaced by selected ISD's avg

# Use the actual ISD avg from the same source
isd_avg_tax_map <- data.table(
  code = c("WE","AL","SP","AZ","BR","PE","MI","PO","GA","CG","PW","MW","LI"),
  avg  = c(1871,4576,1629,2397,4214,2848,1957,1476,1210,2569,1205,523,845)
)
avg_hs_tax_in_isd <- isd_avg_tax_map[code == opts$isd, avg]
# Add countywide base (~$1,500/year homestead burden for typical Parker)
PARKER_COUNTYWIDE_HS_TAX <- 1500
total_current_hs_tax <- avg_hs_tax_in_isd + PARKER_COUNTYWIDE_HS_TAX
pct_of_current_bill  <- 100 * total_per_yr / total_current_hs_tax

# ── Text summary ───────────────────────────────────────────────────────────
cat("\n══════════════════════════════════════════════════════════════════\n")
cat("PARKER COUNTY DATA-CENTER SCENARIO\n")
cat("══════════════════════════════════════════════════════════════════\n\n")
cat(sprintf("Scenario:  %d MW facility, %dY abatement at %.0f%% rate, in %s\n",
            opts$mw, opts$years, opts$abate*100, isd_name))
cat(sprintf("           Capex ≈ $%.0fM (%.0f%% taxable), cooling = %s\n\n",
            opts$mw * opts$capex, opts$taxable*100, opts$cooling))

cat("ANNUAL COST PER HOMESTEAD\n")
cat("─────────────────────────────────\n")
cat(sprintf("  Tax abatement   $%6.0f/yr\n", tax_cost_per_hh_per_yr))
cat(sprintf("    ├ ISD share   $%6.0f/yr  (over %s households)\n",
            cost_isd_per_hh_per_yr, format(isd_hh, big.mark=",")))
cat(sprintf("    └ County etc. $%6.0f/yr  (over %s households)\n",
            cost_cw_per_hh_per_yr, format(PARKER_TOTAL_HH, big.mark=",")))
cat(sprintf("  Power (Oncor)   $%6.0f/yr  (spread to %sM meters)\n",
            power_per_hh_per_yr, round(ONCOR_METERS/1e6,0)))
cat(sprintf("  Water (UTGCD)   $%6.0f/yr  (spread to %sk households)\n",
            water_per_hh_per_yr, round(PARKER_WATER_HH/1000,0)))
cat("─────────────────────────────────\n")
cat(sprintf("  TOTAL           $%6.0f/yr per Parker homestead in %s\n",
            total_per_yr, isd_name))
cat("\n")
cat(sprintf("That's %.1f%% of the current average homestead tax bill ($%s/yr).\n",
            pct_of_current_bill, format(round(total_current_hs_tax), big.mark=",")))
cat("\n")
cat(sprintf("LIFETIME COST OVER %d-YEAR ABATEMENT\n", opts$years))
cat("─────────────────────────────────\n")
cat(sprintf("  Total per homestead: $%s\n",
            format(round(total_lifetime), big.mark=",")))
cat(sprintf("  Parker countywide:   $%s\n",
            format(round((tax_cost_per_hh_lifetime + power_per_hh_lifetime +
                          water_per_hh_lifetime) * PARKER_TOTAL_HH), big.mark=",")))
cat("\n")

# ── Visualisation ──────────────────────────────────────────────────────────
dir.create(opts$out, recursive=TRUE, showWarnings=FALSE)
png_path <- file.path(opts$out, sprintf("scenario_%s_%dMW.png", opts$isd, opts$mw))

png(png_path, width=2100, height=1100, res=170)
layout(matrix(c(1,2), nrow=1), widths=c(1.7, 1))

# Panel 1: per-jurisdiction stacked bar
par(mar=c(5, 11, 4, 1), family="sans")    # wide left margin for full labels
# Clean jurisdiction names
clean_name <- function(s) {
  s <- gsub("I.S.D.|ISD", "ISD", s)
  s <- gsub("DISTR$", "District", s)
  s <- gsub("DISTRICT", "District", s)
  s <- gsub("COUNTY", "County", s)
  s <- gsub("JR COLLEGE", "Jr College", s)
  s <- gsub("LATERAL ROAD", "Lateral Road", s)
  s <- gsub("PARKER CO HOSPITAL", "Parker Co Hospital", s)
  s <- gsub("ALEDO", "Aledo", s); s <- gsub("WEATHERFORD", "Weatherford", s)
  s <- gsub("SPRINGTOWN", "Springtown", s); s <- gsub("AZLE", "Azle", s)
  s <- gsub("BROCK", "Brock", s); s <- gsub("PEASTER", "Peaster", s)
  s <- gsub("MILLSAP", "Millsap", s); s <- gsub("POOLVILLE", "Poolville", s)
  s <- gsub("GARNER", "Garner", s); s
}
breakdown <- data.table(
  jurisdiction = c(juris_breakdown$jurisdiction, "Power (Oncor + ERCOT)", "Water (UTGCD area)"),
  cost_per_hh_yr = c(juris_breakdown$cost_per_hh_yr, power_per_hh_per_yr, water_per_hh_per_yr),
  channel = c(rep("tax", nrow(juris_breakdown)), "power", "water")
)
breakdown[, jurisdiction := clean_name(jurisdiction)]
chan_col <- c(tax="#2c7fb8", power="#e6783c", water="#5da75a")
breakdown[, color := chan_col[channel]]
# Order: tax channel descending by cost, then power, then water
breakdown <- breakdown[order(channel != "tax", -cost_per_hh_yr)]

isd_short <- gsub(" I.S.D.| ISD", "", isd_name)
bp <- barplot(breakdown$cost_per_hh_yr,
              horiz=TRUE, las=1, col=breakdown$color, border="white",
              names.arg=breakdown$jurisdiction,
              cex.names=0.9,
              xlim=c(0, max(breakdown$cost_per_hh_yr)*1.30),
              main=sprintf("Annual cost per %s homestead — %d MW scenario",
                           isd_short, opts$mw),
              xlab="$ per household per year", cex.main=1.05, font.main=1)
# Label values to the right of each bar (skip $0)
for (i in seq_along(bp)) {
  v <- breakdown$cost_per_hh_yr[i]
  if (v >= 0.5) text(v, bp[i], sprintf("$%.0f", v), pos=4, cex=0.82, col="#222222")
  else          text(0, bp[i], "  (<$1)", pos=4, cex=0.78, col="#888888")
}
# Legend inside the plot at top-right where the small Power/Water bars leave space.
# At top of bars, well clear of the dominant ISD bar at the bottom.
n_bars <- length(bp)
legend(x = max(breakdown$cost_per_hh_yr)*0.55,
       y = bp[n_bars - 1] + 0.5,
       legend=c("Tax (foregone abatement)",
                "Power (rate-base + wholesale)",
                "Water (UTGCD-area utility lift)"),
       fill=chan_col, bty="o", bg="white", box.col="#dddddd",
       cex=0.85)

# Panel 2: lifetime bill — big number callout + comparison
par(mar=c(2,2,4,2), family="sans")
plot(NA, xlim=c(0,10), ylim=c(0,10), axes=FALSE, xlab="", ylab="",
     main=sprintf("Cost to one %s homestead", isd_short),
     cex.main=1.1, font.main=1)
# Per-year
text(5, 9.0, sprintf("$%s", format(round(total_per_yr), big.mark=",")),
     cex=2.6, font=2, col="#222222")
text(5, 8.2, "per homestead per year", cex=1.0, col="#444444")
# Lifetime
text(5, 6.6, sprintf("$%s", format(round(total_lifetime), big.mark=",")),
     cex=2.6, font=2, col="#a50f15")
text(5, 5.8, sprintf("over the %d-year abatement period", opts$years),
     cex=1.0, col="#a50f15")
# Comparison
text(5, 4.0,
     sprintf("That's %.1f%% of the current\naverage Aledo homestead tax bill\n($%s/year)",
             pct_of_current_bill, format(round(total_current_hs_tax), big.mark=",")),
     cex=0.95, col="#444444")
# Countywide aggregate
text(5, 1.5,
     sprintf("Parker County aggregate:\n$%s million in lost revenue\nover %d years",
             format(round((tax_cost_per_hh_lifetime + power_per_hh_lifetime +
                          water_per_hh_lifetime) * PARKER_TOTAL_HH/1e6, 1),
                    big.mark=","),
             opts$years),
     cex=0.88, col="#666666")
mtext(sprintf("Scenario: %d MW · %s · capex $%.0fM · %d-yr abatement @ %.0f%%",
              opts$mw, isd_name, opts$mw*opts$capex, opts$years, opts$abate*100),
      side=1, line=0, cex=0.78, col="#666666")

dev.off()
cat(sprintf("Wrote %s\n", png_path))
