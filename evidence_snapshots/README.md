# Evidence snapshots

Timestamped local snapshots of the primary public-record sources cited in the
[Parker Data — Pro Populo](https://parker-data-pro-populo.github.io/data-center-surface-datarun/)
publication and the
[June 8 commissioners court presentation](https://parker-data-pro-populo.github.io/data-center-surface-datarun/slides/).

## What's here

| File | Source | Captured |
|---|---|---|
| `*_tceq_rn112172408_parker_plant.pdf` | TCEQ Central Registry — Regulated Entity record for "PARKER PLANT" at 501 Pearson Ranch Rd | 2026-06-01 |
| `*_tceq_cust_cn606278281_fwpc.pdf` | TCEQ Central Registry — Customer record for Fort Worth Power Core LLC, listing all 14 affiliated regulated entities | 2026-06-01 |
| `*_tceq_permit_179422.pdf` | TCEQ Air New Source Registration #179422 | 2026-06-01 |
| `*_tceq_re_*.pdf` | TCEQ search-result pages used to discover the records above | 2026-06-01 |
| `*_comptroller_fwpc.{json,pdf}` | TX Comptroller franchise-tax registry — Fort Worth Power Core LLC (Taxpayer 32094460238) | 2026-06-01 |
| `*_comptroller_black_mountain_*.{json,pdf}` | TX Comptroller franchise-tax registry — Black Mountain Power LLC, Land Company LP, Royalty LP | 2026-06-01 |
| `*_comptroller_jeti_full_api_*.json` | TX Comptroller JETI (Ch.313 successor) full applications API response | 2026-06-01 |
| `*_comptroller_ch312_2025_exhibits_*.xlsx` | TX Comptroller 2025 Chapter 312 exhibits spreadsheet | 2026-06-01 |
| `sha256.txt` | SHA-256 integrity hashes of every file above | 2026-06-02 |
| `CD_RESPONSE_TEMPLATE.md` | Template response if a cease-and-desist or demand letter arrives | 2026-06-02 |

## Wayback Machine snapshots

Snapshotted to the Internet Archive on 2026-06-02:

- https://web.archive.org/web/2026/https://parker-data-pro-populo.github.io/data-center-surface-datarun/
- https://web.archive.org/web/2026/https://parker-data-pro-populo.github.io/data-center-surface-datarun/viz/tx_rco_interactive.html
- https://web.archive.org/web/2026/https://parker-data-pro-populo.github.io/data-center-surface-datarun/slides/
- https://web.archive.org/web/2026/https://github.com/Parker-Data-Pro-Populo/data-center-surface-datarun
- https://web.archive.org/web/2026/https://github.com/Parker-Data-Pro-Populo
- https://web.archive.org/web/2026/https://comptroller.texas.gov/taxes/franchise/account-status/search/32094460238
- https://web.archive.org/web/2026/https://comptroller.texas.gov/taxes/franchise/account-status/search/32099722830
- https://web.archive.org/web/2026/https://comptroller.texas.gov/taxes/franchise/account-status/search/32047817641
- https://web.archive.org/web/2026/https://comptroller.texas.gov/taxes/franchise/account-status/search/32035294829

TCEQ Central Registry blocks Wayback Machine scraping (HTTP 520). The TCEQ
records here are local-only snapshots taken via authenticated session on
2026-06-01 and rendered to PDF on 2026-06-02. Hashes in `sha256.txt`
establish integrity.

## Why this exists

Every dollar figure, every entity name, every permit reference in the
published deck traces to one of these source documents. If any source URL
later changes, redirects, is taken down, or the underlying record is
modified, these timestamped artifacts preserve what was published and when.

The SHA-256 hashes are a tamper-evidence chain — any modification to the
files in this directory after 2026-06-02 will show up as a hash mismatch.

## Verifying a hash

```sh
shasum -a 256 -c sha256.txt
```

Any line that prints anything other than "OK" indicates that file has been
modified since 2026-06-02.

## Not stored here

- Parker County Appraisal District corrected notices for the 18 Black Mountain
  parcels — stored separately in `../black_mountain_holdings/` (original PDFs
  delivered to the property owner)
- Parker County Commissioners Court May-26-2026 transcript — stored in
  `../parker_costs/court_records/`
- TWDB Nov-2019 GCD shapefile — stored in `../scripts/twdb_gcds_2019-11.pdf`
- Source code for all derived figures — `../scripts/` and `../parker_costs/`
