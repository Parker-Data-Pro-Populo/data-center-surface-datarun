#!/usr/bin/env Rscript
# RCO_01_pull_substrate.R — PATCHED for the live pg-active schema as confirmed
# by the section-1/2/3 run + RCO verify step.
# Changes from the original draft:
#   A1  efa_scores cols are case-sensitive ("H","F1"..); clustgeo has rucc_2023
#       (not rucc). Join on fips.
#   A2  chr.measures -> chr.analytic_data_2025; measures is JSONB; key is
#       fips_5digit. severe_housing_problems is a real catalog key, kept.
#   A3  acs.canonical_2024_county keys on `fips` (not geoid); subject table on
#       `geoid` -- 5-digit county FIPS in both, joined directly.
#   A4  qcew table is qcew.qtrly_2024 (quarterly, all-text columns). Use the
#       4-qtr avg of month3_emplvl for 2024.
#   A5  bea.cainc30 confirmed: linecode is text ('10','220'), value col c_2024.
#   A7  pg01 absent on this worker — pull skipped via tryCatch (as designed).

source("RCO_00_config.R")
con <- rco_connect(PG_ACTIVE)

# ── A1. Fragility + cluster (national) ──────────────────────────────────────
substrate <- setDT(dbGetQuery(con, '
  SELECT s.fips,
         s."H"  AS H,
         s."F1" AS f1, s."F2" AS f2, s."F3" AS f3, s."F4" AS f4, s."F5" AS f5,
         c.k6, c.k8, c.k10,
         c.rucc_2023 AS rucc
  FROM national.efa_scores s
  JOIN national.clustgeo_assignments c USING (fips)
'))
fwrite(substrate, file.path(OUT, "rco_substrate.csv"))
message("substrate: ", nrow(substrate), " counties")

cluster1_fips <- substrate[k10 == 1L, fips]
fwrite(data.table(fips = cluster1_fips), file.path(OUT, "rco_cluster1_fips.csv"))
message("cluster-1 (k10): ", length(cluster1_fips), " counties")

# ── A2. CHR channel indicators (national) — JSONB extract ───────────────────
chr <- setDT(dbGetQuery(con, "
  SELECT fips_5digit AS fips,
         NULLIF(measures->>'rural_raw_value','')::numeric                     AS rural_raw_value,
         NULLIF(measures->>'drinking_water_violations_raw_value','')::numeric AS drinking_water_violations_raw_value,
         NULLIF(measures->>'severe_housing_problems_raw_value','')::numeric   AS severe_housing_problems_raw_value,
         NULLIF(measures->>'severe_housing_cost_burden_raw_value','')::numeric AS severe_housing_cost_burden_raw_value
  FROM chr.analytic_data_2025
  WHERE length(fips_5digit) = 5 AND fips_5digit NOT LIKE '%000'
"))
fwrite(chr, file.path(OUT, "rco_chr.csv"))
message("chr: ", nrow(chr), " counties")

# ── A3. ACS channel indicators (national) ───────────────────────────────────
acs <- setDT(dbGetQuery(con, "
  SELECT c.fips,
         c.poverty_rate_pct,
         c.median_hh_income,
         sub.pct_65_pluse
  FROM acs.canonical_2024_county c
  LEFT JOIN acs.subject_2024_county_5y sub ON sub.geoid = c.fips
"))
fwrite(acs, file.path(OUT, "rco_acs.csv"))
message("acs: ", nrow(acs), " counties")

# ── A4. QCEW land-channel sector shares (national) ──────────────────────────
# qtrly_2024 is quarterly + text; average month3 emp across 4 qtrs.
qcew <- setDT(dbGetQuery(con, "
  WITH tot AS (
    SELECT area_fips AS fips,
           AVG(NULLIF(month3_emplvl,'')::numeric) AS total_emp
    FROM qcew.qtrly_2024
    WHERE agglvl_code='70' AND industry_code='10' AND own_code='0'
    GROUP BY area_fips
  ),
  ag AS (
    SELECT area_fips AS fips,
           AVG(NULLIF(month3_emplvl,'')::numeric) AS ag_emp
    FROM qcew.qtrly_2024
    WHERE agglvl_code='74' AND industry_code='11'
    GROUP BY area_fips
  )
  SELECT tot.fips,
         COALESCE(ag.ag_emp,0)/NULLIF(tot.total_emp,0) AS ag_emp_share
  FROM tot LEFT JOIN ag USING (fips)
  WHERE length(tot.fips)=5
"))
fwrite(qcew, file.path(OUT, "rco_qcew.csv"))
message("qcew: ", nrow(qcew), " counties")

# ── A5. BEA farm-proprietor income share (land channel) ─────────────────────
bea <- setDT(dbGetQuery(con, "
  WITH pi AS (
    SELECT lpad(geofips,5,'0') AS fips,
           NULLIF(c_2024,'(NA)')::numeric AS v
    FROM bea.cainc30 WHERE linecode='10'
  ),
  fp AS (
    SELECT lpad(geofips,5,'0') AS fips,
           NULLIF(c_2024,'(NA)')::numeric AS v
    FROM bea.cainc30 WHERE linecode='220'
  )
  SELECT pi.fips, fp.v / NULLIF(pi.v,0) AS farm_prop_income_share
  FROM pi LEFT JOIN fp USING (fips)
  WHERE length(pi.fips)=5 AND right(pi.fips,3) <> '000'
"))
fwrite(bea, file.path(OUT, "rco_bea.csv"))
message("bea: ", nrow(bea), " counties")

# ── A6. PEP growth / in-migration ───────────────────────────────────────────
pep <- setDT(dbGetQuery(con, "
  SELECT lpad(state::text,2,'0') || lpad(county::text,3,'0') AS fips,
         popestimate2020::numeric AS pop2020,
         popestimate2024::numeric AS pop2024,
         domesticmig2024::numeric AS dom_mig_2024
  FROM pep.co_est2024
  WHERE county <> '000'
"))
pep[, pct_growth_2020_24 := round(100*(pop2024/pop2020 - 1), 1)]
fwrite(pep, file.path(OUT, "rco_pep.csv"))
message("pep: ", nrow(pep), " counties")

dbDisconnect(con)

# ── A7. PUBLIC SFI artifact (pg01) — skipped on worker-active (no creds) ────
tryCatch({
  con01 <- rco_connect(PG01)
  pub <- setDT(dbGetQuery(con01,
    "SELECT geoid AS tract_fips, harm_index FROM surface.tract_lean"))
  pub[, county_fips := substr(tract_fips, 1, 5)]
  fwrite(pub, file.path(OUT, "rco_public_sfi_tract.csv"))
  dbDisconnect(con01)
  message("public SFI artifact pulled (", nrow(pub), " tracts)")
}, error = function(e)
  message("pg01 public SFI pull skipped: ", conditionMessage(e)))

message("RCO_01 done.")
