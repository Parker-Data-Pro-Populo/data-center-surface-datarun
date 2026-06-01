#!/usr/bin/env Rscript
# RCO_05b_black_mountain_real.R — Parker County resident-cost model anchored
# to the REAL Black Mountain Power LLC 2026 footprint, including:
#   - Actual 18-parcel land footprint pulled from Parker CAD May 2026 corrected notices
#   - Land-tax revenue now flowing (ag exemption stripped)
#   - 5 gas turbines as separately-modeled tangible personal property
#   - Data-center improvements with Chapter 312 abatement
#   - Per-HH cost net of land-tax gain
#
# Inputs you can tweak (defaults reflect a defensible 1 GW gas-turbine DC):
#   --mw            Total DC load capacity (default 1000 MW)
#   --dcCapex      Data-center capex per MW in $M (default 8.0)
#   --turbines      Number of gas turbines (default 5)
#   --turbineMW    Capacity per turbine (default 200 — frame class)
#   --turbineCost  $M per turbine installed (default 200)
#   --abate         Chapter 312 abatement fraction (default 0.80)
#   --abateYrs     Term in years (default 10)
#   --taxableImp   Taxable share of improvements (default 0.85)

suppressPackageStartupMessages({
  library(data.table); library(optparse)
})

opts <- OptionParser(option_list = list(
  make_option("--mw",            type="numeric", default=1000),
  make_option("--dcCapex",      type="numeric", default=8.0),
  make_option("--turbines",      type="integer", default=5),
  make_option("--turbineMW",    type="numeric", default=200),
  make_option("--turbineCost",  type="numeric", default=200),
  make_option("--abate",         type="numeric", default=0.80),
  make_option("--abateYrs",     type="integer", default=10),
  make_option("--taxableImp",   type="numeric", default=0.85)
)) |> parse_args()

# ── Load real Black Mountain parcel data ───────────────────────────────────
bm <- fread("bm_parcels_2026.csv")
# Use CORRECTED notices where present, fall back to ORIGINAL
bm[, has_corrected := any(notice_type == "CORRECTED"), by = prop_id]
bm_live <- rbind(
  bm[notice_type == "CORRECTED"],
  bm[!has_corrected & notice_type == "ORIGINAL"]
)
bm_live <- unique(bm_live, by="prop_id")

BM_PARCELS  <- nrow(bm_live)
BM_ACRES    <- sum(bm_live$acres, na.rm=TRUE)
BM_LAND_VAL <- sum(bm_live$ty_land, na.rm=TRUE)
BM_TAX_LIVE <- sum(bm_live$tax_at_ly_rate, na.rm=TRUE)

# Also compute the ag-exempted view (what was being paid before correction)
bm_pre <- bm[notice_type == "ORIGINAL"]
bm_pre <- unique(bm_pre, by="prop_id")
BM_TAX_AG <- sum(bm_pre$tax_at_ly_rate, na.rm=TRUE)

# ── Tax rates (Parker 2025 — applied to last-year-rate calc on the notices) ─
# Weatherford ISD area: county + ISD + LTR + HOS + COL + ESD1
RATES <- list(
  isd     = 0.010342,   # Weatherford ISD M&O + I&S
  county  = 0.002459,   # Parker County
  ltr     = 0.000533,   # Lateral Road
  hos     = 0.000895,   # Hospital District
  col     = 0.001061,   # Junior College
  esd1    = 0.001000    # ESD 1 (most BM parcels) — note one parcel is ESD3
)
TOTAL_RATE <- sum(unlist(RATES))
WE_RATE    <- RATES$isd
CW_RATE    <- TOTAL_RATE - WE_RATE   # county + LTR + HOS + COL + ESD1

# Household counts
WE_HOMESTEADS    <- 15902
PARKER_HOMESTEADS<- 46404

# ── Build the cost model ───────────────────────────────────────────────────
# Improvements value:
turbine_value  <- opts$turbines * opts$turbineCost * 1e6       # $
dc_value       <- opts$mw * opts$dcCapex * 1e6              # $
imp_value      <- turbine_value + dc_value                     # total $
imp_taxable    <- imp_value * opts$taxableImp               # $

# Full-rate annual property tax on improvements (if no abatement)
imp_tax_full_yr <- imp_taxable * TOTAL_RATE
imp_tax_we_full <- imp_taxable * WE_RATE
imp_tax_cw_full <- imp_taxable * CW_RATE

# After Chapter 312 abatement: fraction collected = (1 - abate)
collected_fr   <- 1 - opts$abate
imp_tax_collected_yr <- imp_tax_full_yr * collected_fr
imp_tax_foregone_yr  <- imp_tax_full_yr * opts$abate
foregone_we_yr <- imp_tax_we_full * opts$abate
foregone_cw_yr <- imp_tax_cw_full * opts$abate

# Per-HH foregone (the resident-cost share)
foregone_we_per_hh <- foregone_we_yr / WE_HOMESTEADS
foregone_cw_per_hh <- foregone_cw_yr / PARKER_HOMESTEADS
foregone_total_per_hh <- foregone_we_per_hh + foregone_cw_per_hh

# Net of land-tax gain (the $943K/yr now flowing because ag was stripped)
land_gain_per_we_hh <- (BM_TAX_LIVE - BM_TAX_AG) * (WE_RATE/TOTAL_RATE) / WE_HOMESTEADS
land_gain_per_cw_hh <- (BM_TAX_LIVE - BM_TAX_AG) * (CW_RATE/TOTAL_RATE) / PARKER_HOMESTEADS
land_gain_total_per_hh <- land_gain_per_we_hh + land_gain_per_cw_hh

net_cost_per_hh_yr <- foregone_total_per_hh - land_gain_total_per_hh
net_cost_lifetime  <- net_cost_per_hh_yr * opts$abateYrs

# ── Summary output ─────────────────────────────────────────────────────────
cat("\n══════════════════════════════════════════════════════════════════\n")
cat("BLACK MOUNTAIN POWER LLC — Parker County resident-cost scenario\n")
cat("Anchored to REAL May-2026 Parker CAD corrected notices\n")
cat("══════════════════════════════════════════════════════════════════\n\n")

cat("ACTUAL FOOTPRINT (from CAD)\n")
cat(sprintf("  Parcels:           %d\n", BM_PARCELS))
cat(sprintf("  Total acres:       %s\n", format(round(BM_ACRES, 2), big.mark=",")))
cat(sprintf("  Total land value:  $%sM\n",
            format(round(BM_LAND_VAL/1e6, 1), big.mark=",")))
cat(sprintf("  Tax before ag-strip (ORIGINAL notices): $%s/yr\n",
            format(round(BM_TAX_AG), big.mark=",")))
cat(sprintf("  Tax after  ag-strip (CORRECTED notices): $%s/yr  ← happening NOW\n",
            format(round(BM_TAX_LIVE), big.mark=",")))
cat(sprintf("  New annual revenue from land conversion: $%s/yr\n",
            format(round(BM_TAX_LIVE - BM_TAX_AG), big.mark=",")))
cat(sprintf("  Rollback tax owed (5 yrs back-tax for ag loss, TX §23.55): ~$%s one-time\n\n",
            format(round((BM_TAX_LIVE - BM_TAX_AG) * 5), big.mark=",")))

cat("PROJECTED IMPROVEMENTS\n")
cat(sprintf("  Data center capex:    $%.1fB ($%.1fM/MW × %d MW)\n",
            dc_value/1e9, opts$dcCapex, opts$mw))
cat(sprintf("  Gas turbines:         $%.1fB (%d × $%dM × %d MW each)\n",
            turbine_value/1e9,
            opts$turbines, opts$turbineCost, opts$turbineMW))
cat(sprintf("  Total improvements:   $%.1fB\n", imp_value/1e9))
cat(sprintf("  Taxable share:        %.0f%%  ($%.1fB taxable)\n",
            opts$taxableImp*100, imp_taxable/1e9))
cat("\n")

cat(sprintf("UNDER %.0f%% CHAPTER 312 ABATEMENT × %d YEARS\n",
            opts$abate*100, opts$abateYrs))
cat(sprintf("  Annual tax IF no abatement:     $%.1fM/yr\n",
            imp_tax_full_yr/1e6))
cat(sprintf("  Annual tax actually collected:   $%.1fM/yr  (%.0f%% of full)\n",
            imp_tax_collected_yr/1e6, collected_fr*100))
cat(sprintf("  Annual tax FOREGONE (abated):    $%.1fM/yr\n",
            imp_tax_foregone_yr/1e6))
cat(sprintf("  Lifetime foregone (× %d yrs):    $%.2fB\n\n",
            opts$abateYrs, imp_tax_foregone_yr * opts$abateYrs/1e9))

cat("PER-HOMESTEAD COST (Weatherford ISD homestead)\n")
cat(sprintf("  Foregone Weatherford ISD share:  $%s/yr  (over 15,902 HH)\n",
            format(round(foregone_we_per_hh), big.mark=",")))
cat(sprintf("  Foregone county etc share:       $%s/yr  (over 46,404 HH)\n",
            format(round(foregone_cw_per_hh), big.mark=",")))
cat(sprintf("  Land-tax gain (offset):          -$%s/yr\n",
            format(round(land_gain_total_per_hh), big.mark=",")))
cat(sprintf("─────────────────────────────────────\n"))
cat(sprintf("  NET COST PER WE HOMESTEAD:       $%s/yr\n",
            format(round(net_cost_per_hh_yr), big.mark=",")))
cat(sprintf("  LIFETIME (%d years):              $%s\n\n",
            opts$abateYrs,
            format(round(net_cost_lifetime), big.mark=",")))

cat(sprintf("PARKER COUNTY AGGREGATE LOSS\n"))
cat(sprintf("  Net annual foregone: $%s million/yr\n",
            format(round((imp_tax_foregone_yr - (BM_TAX_LIVE - BM_TAX_AG))/1e6, 1),
                   big.mark=",")))
cat(sprintf("  Lifetime aggregate:  $%s billion over %d years\n\n",
            format(round((imp_tax_foregone_yr - (BM_TAX_LIVE - BM_TAX_AG)) *
                          opts$abateYrs/1e9, 2), big.mark=","),
            opts$abateYrs))

# ── Plot ───────────────────────────────────────────────────────────────────
png_path <- "scenario_BM_real.png"
png(png_path, width=2300, height=1300, res=170)
layout(matrix(c(1,2), nrow=1), widths=c(1.9, 1))

# Panel 1: stacked breakdown
par(mar=c(5, 15, 4, 1), family="sans")    # wider left margin for full labels
items <- data.table(
  label = c(
    "Land tax — Weatherford ISD share",
    "Land tax — County etc share",
    "DC building tax foregone — WE ISD",
    "DC building tax foregone — county etc",
    "Gas turbine tax foregone — WE ISD",
    "Gas turbine tax foregone — county etc"
  ),
  amount = c(
    -((BM_TAX_LIVE - BM_TAX_AG) * (WE_RATE/TOTAL_RATE) / WE_HOMESTEADS),
    -((BM_TAX_LIVE - BM_TAX_AG) * (CW_RATE/TOTAL_RATE) / PARKER_HOMESTEADS),
    (dc_value * opts$taxableImp * WE_RATE * opts$abate) / WE_HOMESTEADS,
    (dc_value * opts$taxableImp * CW_RATE * opts$abate) / PARKER_HOMESTEADS,
    (turbine_value * opts$taxableImp * WE_RATE * opts$abate) / WE_HOMESTEADS,
    (turbine_value * opts$taxableImp * CW_RATE * opts$abate) / PARKER_HOMESTEADS
  ),
  color = c("#5da75a","#5da75a","#2c7fb8","#2c7fb8","#e6783c","#e6783c")
)

bp <- barplot(items$amount, horiz=TRUE, las=1,
              col=items$color, border="white",
              names.arg=items$label, cex.names=0.85,
              xlim=c(min(items$amount)*1.1, max(items$amount)*1.20),
              main=sprintf("Black Mountain %.1f GW scenario — annual cost per Weatherford homestead",
                            opts$mw/1000),
              xlab="$ per household per year   (negative = revenue gain, positive = cost)",
              cex.main=1.0, font.main=1)
for (i in seq_along(bp)) {
  v <- items$amount[i]
  text(v, bp[i], sprintf("%s$%.0f", ifelse(v<0,"+",""), abs(v)),
       pos=ifelse(v>0, 4, 2), cex=0.82, col="#222222")
}
abline(v=0, col="#444444", lwd=1)
legend("topright",
       legend=c("Land tax revenue (gain)", "DC building tax foregone (cost)",
                "Gas turbine tax foregone (cost)"),
       fill=c("#5da75a","#2c7fb8","#e6783c"),
       bty="o", bg="white", box.col="#dddddd", cex=0.85)

# Panel 2: callout
par(mar=c(2,2,4,2), family="sans")
plot(NA, xlim=c(0,10), ylim=c(0,10), axes=FALSE, xlab="", ylab="",
     main="Net cost to one Weatherford homestead",
     cex.main=1.1, font.main=1)
text(5, 9.0, sprintf("$%s", format(round(net_cost_per_hh_yr), big.mark=",")),
     cex=2.8, font=2, col="#222222")
text(5, 8.2, "per homestead per year", cex=1.0, col="#444444")
text(5, 6.6, sprintf("$%s", format(round(net_cost_lifetime), big.mark=",")),
     cex=2.8, font=2, col="#a50f15")
text(5, 5.8, sprintf("over the %d-year abatement",
                     opts$abateYrs),
     cex=1.0, col="#a50f15")

# Context lines
text(5, 4.0,
     sprintf("That's %.0f%% of the current\nWeatherford homestead tax bill",
             100 * net_cost_per_hh_yr / (1871 + 1500)),
     cex=0.95, col="#444444")
text(5, 2.2,
     sprintf("Parker County aggregate loss:\n$%s billion over %d years",
             format(round((imp_tax_foregone_yr - (BM_TAX_LIVE - BM_TAX_AG)) *
                          opts$abateYrs/1e9, 2), big.mark=","),
             opts$abateYrs),
     cex=0.9, col="#666666")
mtext(sprintf("%d MW · 5 gas turbines · $%.1fB total improvements · %s land · WE-ISD · %.0f%% abate × %d yr · TWDB GCD: UTGCD (fee-only)",
              opts$mw, imp_value/1e9,
              sprintf("%.1fk acres", BM_ACRES/1000),
              opts$abate*100, opts$abateYrs),
      side=1, line=0, cex=0.72, col="#666666")

dev.off()
cat(sprintf("Wrote %s\n", png_path))
