# RCO pipeline — handoff notes for Claude Code

Build-ready draft of the Wave 5 Resource-Competition Overlay acquisition +
assembly pipeline. Scoped in `wave5_RCO_scope.md`. **Untested against the live
environment** — it was written without DB/web access, against the schema your
section-1/2/3 run confirmed plus documented catalog names. Expect to resolve the
`VERIFY` / `TODO(Code)` markers below before a clean run.

## Run order
```
source RCO_00_config.R      # config; sourced by the others
Rscript RCO_01_pull_substrate.R     # Layer A: fragility/cluster + foundations (pg-active, pg01)
Rscript RCO_02_acquire_external.R   # Layers B, C-water, C-land (web + manual)
#       RCO_03_gcd_pgma_coding.csv  # hand-coded fallback data (no run)
Rscript RCO_04_assemble.R           # channel-decomposed RCO + peer-set
```

## Environment
```
RCO_OUT=~/rco_overlay/output
RCO_PGACTIVE_HOST=...  RCO_PGACTIVE_DB=...   # VERIFY real host/db
RCO_PG01_HOST=...      RCO_PG01_DB=...       # for public SFI artifact
# password via ~/.pgpass or PGPASSWORD (never hardcode)
NASS_API_KEY=...                            # optional, land channel
RCO_TWDB_AQUIFER_URL= RCO_TWDB_GCD_URL= RCO_TWDB_PGMA_URL=   # optional, water layer
```

## Resolve-list

**RCO_01 (schema confirmation — quick `\d` then fix):**
- `national.efa_scores` join key + that `H,F1..F5` are the column names (section-3 confirmed values; confirm names).
- cluster table name `national.clustgeo_assignments` and its columns (`k6/k8/k10`, `rucc`).
- `acs.canonical_2024_county` key (`geoid` vs `fips`) and the subject-table elderly column (`pct_65_pluse`).
- `qcew` table name + that `agglvl_code`/`industry_code`/`month3_emplvl`/`area_fips` exist for 2024 annual.
- `bea.cainc30` line-code column (`linecode`?) and value column (`c_2024`), geo key (`geofips`).
- `pep.co_est2024` confirmed (TEXT cols, cast in place).
- `surface.tract_lean.harm_index` on pg01 — the public SFI; keep it separate from `efa_scores.H`.

**RCO_02 (acquisition):**
- `TODO`: populate `datacenter_sites_manual.csv` (schema in the script header) from Baxtel / DataCenterMap / local permits / news. This is the layer with no clean API; the queue is noisy until SB6 transparency rules (~Dec 2026).
- `TODO`: resolve TWDB GIS endpoints (aquifer / GCD / PGMA) and do the county spatial join with `sf`; else the hand-coded `RCO_03` table carries the TX working set.
- `TODO`: NASS Quick Stats key for county cropland share (land channel); QCEW+BEA cover it for a first pass.

**RCO_03 (verify the hand-coding):**
- Confirm GCD coverage/funding/PGMA for Hays, Hill, Van Zandt, Tarrant, Dallas against the TWDB GCD index / TAGD index (rows flagged `low`/`med`). Parker/Hood/Montague/Wise (Upper Trinity GCD) are `high` confidence.

## Two things not to get wrong
1. **Public vs analytical SFI.** Anything destined for Texas Crossroads uses `surface.tract_lean.harm_index` (pg01). The pulled `efa_scores.H` equals F1 (single-factor) and is analytical-only — never publish it.
2. **Channels stay separate.** The product is per-channel (water/power/land), not one composite. `rco_sum`/`rco_max` are conveniences; the multi-loci signal is in which channel dominates where.

## Expected first result
With no sites loaded, `D == 0` so the whole surface is 0 — correct (no facility, no competition). The overlay lights up only once `datacenter_sites_manual.csv` has rows. Start with the Parker/Hays/Hood peer set: a handful of known/announced sites is enough to produce the first channel attribution.
