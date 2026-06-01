#!/usr/bin/env Rscript
# RCO_01_pull_substrate.R — Layer A: pull fragility/cluster + foundation
# indicators that feed the three channel susceptibilities.
# Builds on the queries confirmed working in the section-1/2/3 run.
# Writes one CSV per pull to OUT/.

source("RCO_00_config.R")

con <- rco_connect(PG_ACTIVE)

# ── A1. Fragility + cluster (national) ──────────────────────────────────────
# Confirmed columns from section-3: efa_scores has H, F1..F5; a clustgeo table
# has k=6/8/10 assignments + RUCC. VERIFY exact table/column names below.
substrate <- setDT(dbGetQuery(con, "
  SELECT s.fips,
         s.H, s.F1, s.F2, s.F3, s.F4, s.F5,
         c.k6, c.k8, c.k10,          -- VERIFY column names (k=6/8/10)
         c.rucc                       -- VERIFY
  FROM national.efa_scores s
  JOIN national.clustgeo_assignments c USING (fips)   -- VERIFY table/join key
"))
fwrite(substrate, file.path(OUT, "rco_substrate.csv"))
message("substrate: ", nrow(substrate), " counties")

# Resolve the national cluster-1 set (k=10 == 1) for the β population.
cluster1_fips <- substrate[k10 == 1L, fips]
fwrite(data.table(fips = cluster1_fips), file.path(OUT, "rco_cluster1_fips.csv"))
message("cluster-1 (k10): ", length(cluster1_fips), " counties")

# ── A2. CHR channel indicators (national) ───────────────────────────────────
# Confirmed working: chr.measures keyed by fipscode; *_raw_value columns.
chr <- setDT(dbGetQuery(con, "
  SELECT fipscode AS fips,
         rural_raw_value,
         drinking_water_violations_raw_value,
         severe_housing_problems_raw_value,
         severe_housing_cost_burden_raw_value
  FROM chr.measures
  WHERE length(fipscode) = 5 AND fipscode NOT LIKE '%000'  -- county rows only
"))
fwrite(chr, file.path(OUT, "rco_chr.csv"))

# ── A3. ACS channel indicators (national) ───────────────────────────────────
# VERIFY join key (geoid vs fips) and the subject-table elderly column.
acs <- setDT(dbGetQuery(con, "
  SELECT c.geoid AS fips,
         c.poverty_rate_pct,
         c.median_hh_income,
         sub.pct_65_pluse
  FROM acs.canonical_2024_county c
  LEFT JOIN acs.subject_2024_county_5y sub ON sub.geoid = c.geoid  -- VERIFY
"))
fwrite(acs, file.path(OUT, "rco_acs.csv"))

# ── A4. QCEW land-channel sector shares (national) ──────────────────────────
# Agriculture (NAICS 11) employment share. agglvl=70 total, agglvl=74 by sector.
# VERIFY table name and that 2024 annual avg is available.
qcew <- setDT(dbGetQuery(con, "
  WITH tot AS (
    SELECT area_fips AS fips, month3_emplvl::numeric AS total_emp
    FROM qcew WHERE agglvl_code = 70 AND industry_code = '10'      -- total
  ),
  ag AS (
    SELECT area_fips AS fips, month3_emplvl::numeric AS ag_emp
    FROM qcew WHERE agglvl_code = 74 AND industry_code = '11'      -- NAICS 11
  )
  SELECT tot.fips,
         COALESCE(ag.ag_emp,0) / NULLIF(tot.total_emp,0) AS ag_emp_share
  FROM tot LEFT JOIN ag USING (fips)
"))
fwrite(qcew, file.path(OUT, "rco_qcew.csv"))

# ── A5. BEA farm-proprietor income share (land channel) ─────────────────────
# cainc30 wide format: lc 220 (farm proprietors' income) / lc 10 (personal income).
# VERIFY table/column layout (line-code column name, c_2024 value column).
bea <- setDT(dbGetQuery(con, "
  WITH pi AS (SELECT geofips AS fips, c_2024::numeric AS v
              FROM bea.cainc30 WHERE linecode = 10),
       fp AS (SELECT geofips AS fips, c_2024::numeric AS v
              FROM bea.cainc30 WHERE linecode = 220)
  SELECT pi.fips, fp.v / NULLIF(pi.v,0) AS farm_prop_income_share
  FROM pi LEFT JOIN fp USING (fips)
"))
fwrite(bea, file.path(OUT, "rco_bea.csv"))

# ── A6. PEP growth / in-migration (force-attractant context) ────────────────
# Confirmed: pep.co_est2024, TEXT columns — cast.
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

dbDisconnect(con)

# ── A7. PUBLIC SFI artifact (pg01) — for register-safe public products ──────
# Do NOT mix this with efa_scores.H. Tract-grain; roll to county for joins.
tryCatch({
  con01 <- rco_connect(PG01)
  pub <- setDT(dbGetQuery(con01, "
    SELECT geoid AS tract_fips, harm_index
    FROM surface.tract_lean            -- public-facing SFI (per PROJECT_BRIEF)
  "))
  pub[, county_fips := substr(tract_fips, 1, 5)]
  fwrite(pub, file.path(OUT, "rco_public_sfi_tract.csv"))
  dbDisconnect(con01)
  message("public SFI artifact pulled (", nrow(pub), " tracts)")
}, error = function(e)
  message("pg01 public SFI pull skipped (resolve host/creds): ", conditionMessage(e)))

message("RCO_01 done.")
