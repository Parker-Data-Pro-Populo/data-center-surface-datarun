# Texas Data-Center Resource-Competition Overlay

A research pipeline producing two related artifacts:

1. **The Texas-wide RCO (Resource-Competition Overlay)** — a county-level surface measuring where operating data-center load intersects water / power / land vulnerability, mediated by groundwater-conservation-district (GCD) coverage. Covers all 254 TX counties; built on 9.3 GW of Comptroller-registered operating capacity across 24 lit counties.

2. **The Parker County resident-cost model** — a scenario engine anchored to Parker CAD May-15-2026 corrected notices showing the per-household dollar impact of Black Mountain Power LLC's 2,075-acre data-center assembly at 501 Pearson Ranch Rd.

## Quick tour

```
.
├── RCO_00_config.R … RCO_04_assemble.R   ← TX-wide pipeline (5 stages)
├── RCO_README.md                          ← pipeline operator notes
├── rco_overlay_local/
│   ├── output/                            ← derived CSVs (substrate, susceptibility, RCO surface)
│   ├── viz/                               ← 19 published charts (A-F + 01-13 series)
│   └── scripts/                           ← pipeline scripts cached from worker-active
├── parker_costs/
│   ├── RCO_05*_*.R                        ← Parker scenario engines
│   ├── bm_parcels_2026.csv                ← 18 Black Mountain parcels (parsed from CAD)
│   ├── parker_jurisdictions_2025.csv      ← Parker tax rates + HH counts
│   ├── parker_taxable_base.csv            ← jurisdiction taxable bases
│   ├── scenario_*.png                     ← the cost-model charts
│   └── court_records/
│       ├── 2026-05-26_parker_commissioners_court.md
│       └── black_mountain_corporate_structure.md
├── black_mountain_holdings/               ← 18 original CAD PDFs (Parker tax notices)
├── tceq_sos_cache/                        ← raw TCEQ + TX Comptroller queries (HTML/JSON)
├── twdb_gcds_2019-11.pdf                  ← source TWDB GCD map (Nov 2019)
└── viz/                                   ← copy of latest renders for quick access
```

## Two findings worth reading first

- `parker_costs/court_records/black_mountain_corporate_structure.md` — the 14-site statewide Fort Worth Power Core LLC gas-plant network mapped via TCEQ, with the Rhett M. Bennett / Black Mountain corporate-structure link
- `parker_costs/court_records/2026-05-26_parker_commissioners_court.md` — facts established on the record at the Parker commissioners court session

## Reproducing the pipeline

### Off-network (local-only)
Anything in `rco_overlay_local/scripts/RCO_04_assemble.R` and the `rco_viz*.R` scripts is fully reproducible against the cached `rco_overlay_local/output/*.csv`. Requires R with `data.table`, `sf`, `tigris`, `RColorBrewer`.

### On-network (requires pg-active and worker-active access)
`RCO_01_pull_substrate.R` pulls from pg-active (`sfi_wave5_production`). `RCO_02b_nass.R` requires a NASS QuickStats API key. See `RCO_README.md`.

## Sources of record

- **Parker County Appraisal District** — May-15-2026 corrected notices (`black_mountain_holdings/`)
- **Texas Commission on Environmental Quality (TCEQ) Central Registry** — pulled 2026-06-01 (`tceq_sos_cache/`)
- **Texas Comptroller franchise-tax API** — pulled 2026-06-01 (`tceq_sos_cache/comptroller_*.json`)
- **TWDB Groundwater Conservation Districts of Texas, Nov-2019** (`twdb_gcds_2019-11.pdf`)
- **Parker County Commissioners Court, May-26-2026** (transcript in `parker_costs/court_records/`)
- **pg01.parker.parker_property** — Parker CAD certified roll (queried via SSH)
- **pg-active01.sfi_wave5_production** — Wave 5 RCO substrate (queried via SSH)
- **TX Comptroller Registered Qualifying Data Centers** — pulled 2026-04 (`rco_overlay_local/output/datacenter_sites_*.csv`)
- **USDA NASS QuickStats Census of Ag 2022** — county cropland share (`rco_overlay_local/output/rco_nass.csv`)

## License / Attribution

Research artifact; not licensed for redistribution. Underlying source data are public records.
