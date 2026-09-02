# Black Mountain / Parker County data centers — state of the issue
### Research brief for the September 2026 rebuild of the Pro Populo profile
Compiled 2026-09-01. Every claim below carries a source. Items marked **[UNVERIFIED]** are
things the June 2026 site asserted that I could not re-source, and that must be re-sourced,
re-framed, or dropped before publication.

---

## 0. Why the June site now reads as misleading

The June 2026 site is built on one load-bearing assumption: that the project proceeds
**under an 80% Chapter 312 tax abatement**. Everything headline-facing — "$30M (Phase 1) to
$364M (buildout) in local revenue," the per-family figures, the social card — is a
consequence of that assumption.

That assumption is now contradicted by the record:

- **Parker County Commissioners Court Resolution 26-25** does not support the use of
  abatements for data centers. On 2026-06-30 the court stated on the record: *"there will be
  zero tax abatements for data centers in Parker County. We can assure you of that. We've
  already taken a resolution on that. That has already passed."*
  Source: local transcript `2026-06-30__392498__Special_Commissioners_Court.txt`
  (also referenced by a speaker as "commissioners court resolution 26-25").
- **JETI (Gov't Code Ch. 403) explicitly excludes data centers** from eligibility by NAICS
  code, so the school-district M&O value limitation the site treated as a separate
  state-backfilled matter is not even available to the data center. It *is* available to
  dispatchable generation — i.e. to the gas plant, not the computing hall.
  Source: Texas Comptroller JETI program materials; Public Citizen Texas Data Center Policy Guide.

Net: the site's central number describes a scenario the county has formally refused to grant.
A hostile reader gets to say the headline is a hypothetical presented as a forecast. That is
the fair version of the criticism, and the rebuild has to answer it directly rather than
quietly restate it.

Two further weak points found while auditing the repo:

- **The "75 MW, TCEQ-permitted" anchor is not traceable to the permit.** The archived TCEQ
  material in `evidence_snapshots/` is Central Registry lookup output (~1.5 KB of text; no
  capacity data). The 75 MW figure appears as an annotation in `parker_costs/fwpc_sites.csv`
  ("~75 MW; this project") and in the Weatherford City Manager's 2026-05-26 testimony that
  75 MW "is not sufficient for the ultimate buildout." It should be cited as testimony, not
  as a permit term, unless the permit itself is pulled and archived. **[UNVERIFIED]**
- **The 1 GW buildout is an inference from acreage**, not a disclosure. `RCO_05d_phases.R`
  documents it honestly in code ("implied"), but the public surfaces present the resulting
  $364M as if the scale were known. **[UNVERIFIED]**
- Superseded scripts still carry the pre-correction math: `RCO_05c_bm_panels.R` and
  `RCO_05d_phases.R` still compute the ag rollback at 5 years (`BM_ROLLBACK <- ... * 5`)
  after commit `a4b1988` corrected it to 3 years + 5% interest in `RCO_05f_local_net.R` only.
  Anyone re-running the old scripts reproduces the retracted number.

---

## 1. What the State has done since June

### 1.1 The Abbott audit — the single biggest change
- **2026-08-03**: Governor Abbott directed the PUCT and ERCOT to conduct a *"comprehensive
  verification and audit of all data centers advancing through ERCOT's interconnection
  process"* before any additional data centers may move forward. Trigger cited: failure of
  some data centers to comply with the PUC's water-and-power survey under the General
  Appropriations Act.
- **Scale**: roughly **250–300 projects** under audit. ERCOT is weighing about **474 GW** of
  interconnection requests — more than five times ERCOT's record peak demand — of which
  roughly **90% is data centers**.
- **What projects must file** (RFI, five categories): reliance on tax breaks/grants/
  abatements vs. self-funding; power sourcing (grid vs. own generation, projected annual and
  peak load, progress on on-site generation); water (projected annual and peak use, source,
  cooling technology); community-impact mitigation (noise, lighting, setbacks, traffic,
  emergency coordination); ownership and controlling interests.
- **Consequences**: projects that submit materially false information or fail to respond are
  classified ineligible for Batch Zero; projects found in violation "must be denied
  connection to the Texas grid."
- **Timing**: ERCOT's 2026-08-07 large-load classification deadline was waived; ERCOT aims to
  complete the audit by **2026-12-10**; Batch Zero study results remain due **2027-04-09**.
- **Legally, it is not a moratorium** — it is a pause on advancement through interconnection.
  Sources: Gibson Dunn (Batch Zero analysis); Texas Tribune 2026-08-03 and 2026-08-14;
  Utility Dive (ERCOT December target); Akin; Troutman Pepper Locke.

### 1.2 The statutory frame under it — SB 6 (2025)
- Signed 2025-06-20 (passed 2025-05-29). Defines **large load at ≥75 MW**, with PUCT
  authority to lower the threshold.
- Requires curtailment capability for large loads interconnected after **2025-12-31**,
  including equipment allowing ERCOT to directly curtail during firm load shed; pairs
  mandatory curtailment with a voluntary demand-response program for 75 MW+ loads.
- **The Parker site's 75 MW gas plant sits exactly on the large-load threshold.** Any
  grid-connected load at that site is squarely inside the SB 6 / Batch Zero regime.
- PUCT approved the initial Batch Zero interconnection rules **2026-06-18**.
  Sources: McGuireWoods; Bracewell; Baker Botts; Sidley; Utility Dive.

### 1.3 Abbott's stated policy direction (not yet law)
- **2026-06-10**: letter to state agencies laying out a regulatory framework — data centers
  should fund their own generation and infrastructure, reuse their own water, accept
  setbacks, and lose tax breaks.
- **2026-06-30** (Bullard, campaign stop): *"We must prohibit them from building AI data
  centers in rural Texas neighborhoods."*
- **No special session was called.** Abbott has said he will take it up in the **2027 regular
  session** (ending tax breaks, limiting water and energy use, protecting ratepayers from
  interconnection costs), over Democratic and some Republican calls for a special session.
  Sources: Texas Tribune 2026-06-30; KERA/Houston Public Media 2026-08-04/05; CBS Texas.

### 1.4 State incentives that survive a county saying "no abatements"
This is the part the county cannot control, and the rebuild should say so plainly:
- **Tax Code §151.359** — qualifying data center: exemption from the **state** 6.25% sales
  and use tax on servers, cooling, electrical systems, generators, and **electricity** used
  by the equipment. Requires ≥100,000 sq ft single-occupant space, ≥20 qualifying jobs,
  ≥$200M invested within 5 years. 10 years at $200–250M; 15 years at ≥$250M. Local sales tax
  still due.
- **Tax Code §151.3595** — large data center project: ≥$500M investment, 40 jobs, contracted
  **20 MW** of transmission capacity → **20-year exemption from state *and local* sales tax**.
- **JETI (Gov't Code Ch. 403)** — **data centers are excluded**; dispatchable generation is
  eligible. The gas plant, not the data hall, is the JETI-eligible asset.
- Texas Enterprise Fund remains available at the state's discretion.
  Sources: Texas Comptroller (data center exemption pages); Justia (§151.3595); JETI materials.

---

## 2. What Parker County and its neighbors have actually done

### 2.1 Parker County
- **Resolution 26-25** — no support for tax abatements for data centers (adopted June 2026;
  restated flatly by the court on 2026-06-30).
- **2026-06-09 resolution** — formal opposition to **open-loop evaporative cooling** and other
  high-volume potable-water technologies in large-scale data centers in Parker County and
  other water-constrained regions; encourages statewide standards including water-efficient /
  closed-loop cooling, reclaimed / recycled / non-potable sources where feasible, and demand-
  response participation. Source: local transcript `2026-06-09__390467__*.txt`.
- **No county permit application had been filed** for a data center as of the 2026-06-30
  session (county judge, on the record).
- **Chapter 391 track**: your Parker–Hood draft resolution (`391 Commission/Draft Resolution
  Parker-Hood Consortium.pdf`, 2026-07-08) proposes a **sub-regional** commission scoped
  narrowly to data centers and their direct impacts. On 2026-07-13 the court reported NCTCOG's
  preference that Parker work **through the existing NCTCOG 391** (regionalized) rather than
  stand up a new Parker–Hood body, with the caveat stated in open court that a 391 is
  "perception of doing something without actually accomplishing the main goal" — it adds
  hurdles and delay, it does not stop a project.
- **Weatherford**: data centers "remain NOT ALLOWED" in the city (January 2026 statement);
  the site is ~7 miles northeast of downtown, outside city limits.

### 2.2 The comparison set — what other Texas communities did, and what happened to them
| Community | Action | Date | Outcome |
|---|---|---|---|
| San Marcos | First Texas city to **ban** data centers via zoning definition | June 2026 | Challenged by Sen. Bettencourt under HB 2559 (2025) and HB 2127 ("Death Star"); land-use experts counter that HB 2559 reaches moratoriums, not zoning |
| Hill County | 1-year moratorium on data center construction in unincorporated areas | May 2026 | **Rescinded weeks later** after a developer sued for >$100M; replaced with developer requirements |
| Tom Green County | Moratorium planned | 2026 | **Abandoned** after Hill County's suit |
| Hood & Hays Counties | Moratoriums considered | Feb 2026 | Not adopted under threat of litigation; Hood has instead **denied plats** and is now in litigation |
| Austin County | Countywide moratorium on new AI data centers and BESS | July 2026 | In effect |
| Hood County | Uses **Ch. 231 county zoning** authority (one of the few counties that has it) | ongoing | Enforced regulations on data centers and gas plants |
| El Paso | ≥**300 ft** separation from residential, noise mitigation, special-use permit | July 2026 | Adopted |
| Forney | Data centers limited to light industrial, **1,000 ft** residential buffer | April 2026 | Adopted |
| Lewisville | Special-use permit + two mandatory public hearings | June 2026 | Adopted |
| Mesquite | Dedicated data center / BESS regulatory framework | July 2026 | Adopted |
| Milam County | Resolution urging stricter **statewide** standards | 2026 | Adopted |
| Delta County | **Ch. 391 commission** by interlocal agreement (county + City of Cooper + City of Pecan Gap + Soil & Water Conservation District) | 2026 | Operating; publishes a public FAQ |
| Erath–Somervell; Hood–Somervell | Ch. 391 sub-regional planning commissions | 2026 | Formed |
| Fort Worth | Zoning Commission recommended approval (April); council delayed June 23 → **approved the 187-acre Black Mountain site plan 7–4 on 2026-08-25** | 2026 | Approved despite moratorium calls; FW zoning commission separately voted **against** the city's own proposed data center regulations |

At least **100 local ordinances** on data centers have been considered in Texas since
2025-07-01. Source: MultiState, "The Local Fight Over Data Centers: A Texas Case Study,"
2026-08-19; Texas Tribune; Fort Worth Report; The Real Deal.

**The lesson the table teaches** — and the honest framing for Parker: moratoria and bans by
counties without zoning authority draw suits and get reversed; what survives is (a) cities
using zoning, (b) counties using the authorities they actually have, (c) groundwater
districts using permit conditions, and (d) conditions attached to things the developer wants.

### 2.3 What Parker County can and cannot do (statutory reality)
**Can**: withhold Ch. 312 abatements (done); withhold Ch. 381 loans/grants; require county
flood-hazard permits in the floodplain; act through the subdivision/plat process; road-use
and infrastructure agreements; ESD/emergency-response coordination; TCEQ comment, public
meeting, and contested-case requests; participate in UTGCD proceedings; form or join a
Ch. 391 commission to force state-agency coordination (LGC §§391.004, 391.008, 391.009,
391.0091).
**Cannot**: zone (absent a Ch. 231 grant); impose a development moratorium without explicit
authorization; force TCEQ to deny an air permit (the agency reads Health & Safety Code
§382.0518(b) "shall grant" as mandatory if the application is complete); stop water sourced
from outside the county and piped in.
Source: Public Citizen, *Texas Data Center Policy Guide*; Tex. Loc. Gov't Code Ch. 391.

---

## 3. Water — the strongest and most defensible section to rebuild

The June site barely used the groundwater record. It is now the best-documented constraint,
and it replaces the rhetorical "5 million gallons a day" claims heard in public comment.

**Upper Trinity GCD (Hood, Montague, Parker, Wise) — amendments heard and adopted 2026-08-27:**
- **Minimum tract size** for a new or substantially altered well rises from **2 acres to
  5 acres** where the total average thickness of all Trinity Aquifer layers is **≤60 feet**
  per the TWDB-approved Northern Trinity / Woodbine GAM, and for any tract **west of the line
  defined by that thickness criterion**. Effective **2027-01-01**, applying to property
  subdivided after 2026-12-31; already-platted lots keep their well rights unless boundaries
  are altered. (Rule 4.3(h), proposed-rules PDF in the podcast research folder.)
- **Annual production allocation per contiguous controlled acre — Trinity Group**:
  500 gal/acre × the lesser of (well depth, average aquifer thickness on the property),
  **capped at 250,000 gal/acre/yr**, floor 25,000. **Cross Timbers**: 150 gal/acre × depth,
  cap 100,000, floor 25,000. (Rule 5.2.)
- **High-Volume Permit Application** (threshold effective 2026-02-19): any operating permit
  totalling **≥25,000,000 gal/yr** (Trinity) or **≥10,000,000 gal/yr** (Cross Timbers),
  including future amendments — triggers hydrogeologic investigation, aquifer testing, and
  enhanced notice (Rules 2.10–2.12).
- Contested-case rights at SOAH are available to any person in the district; production
  aggregates across a well system (Rule 2.13), so a campus cannot be split into small permits.

**Why this matters for the profile, stated precisely:**
1. Any data center of consequence is a **High-Volume** applicant many times over, which forces
   a hydrogeologic study, aquifer testing, public notice, and a contestable hearing — the
   public process the TCEQ air permit never provided.
2. Groundwater from the tract itself is **capped by acreage × allocation**. On 2,075 contiguous
   acres the ceiling ranges from about **52 Mgal/yr** (at the 25,000 gal/acre floor) to about
   **519 Mgal/yr** (at the 250,000 gal/acre cap) — i.e. roughly **0.14 to 1.4 million gallons
   per day**, before any thickness-specific calculation. **The site-specific number requires
   the GAM thickness at the tract and the completed well depth — pull it before publishing.**
3. **Do not attach the 5-acre rule to Black Mountain.** The thin-aquifer trigger is the
   **western** edge of the district; the Black Mountain tract is northeast of Weatherford.
   The 5-acre change is context about district-wide tightening and about rural landowners,
   not a constraint on this tract. Getting this wrong is exactly the sort of thing the
   critics are pointing at.

---

## 4. How Phase 1 and Buildout should be rebuilt

### 4.1 Stop presenting one number as the forecast
Replace the single-line "$30M → $364M" with an explicit **scenario grid** whose axes are the
two things genuinely unknown: **scale** and **abatement status**. Label every cell as a
scenario, and label the evidence class of each input (permit / testimony / filing /
inference).

### 4.2 Revised Phase 1
- Anchor: five gas turbines permitted by TCEQ at 501 Pearson Ranch Rd (RN112172408, Air New
  Source Registration 179422), plus city-manager testimony of continuous 24/7 operation and
  that this capacity is not sufficient for the ultimate buildout.
- State the capacity as **"approximately 75 MW, per testimony"** unless the permit is pulled
  and archived — or pull it and cite the permit terms directly.
- New material fact: at ~75 MW the project sits **on** the SB 6 large-load threshold and
  inside ERCOT's Batch Zero and the Abbott audit, with curtailment obligations for anything
  interconnected after 2025-12-31.

### 4.3 Revised Buildout
- Drop "1 GW implied at 2,075-acre scale" as a headline. Keep it, if at all, as one labelled
  scenario among several, with the acreage-inference method shown.
- Better anchors now available: the developer's **own** Fort Worth project — $10B, 187-acre
  site plan, four buildings at 68 ft, 2.2M sq ft enclosed, approved 7–4 on 2026-08-25 — is a
  disclosed, comparable unit of development by the same company. Scale Parker scenarios in
  units of that, not in units of raw acreage.
- Report **what is not known** as a finding in itself: no county permit application, no
  disclosed Parker capacity, no announced ERCOT queue position. The Abbott audit exists
  precisely because the state does not have these numbers either.

### 4.4 Revised fiscal framing
- **Baseline is now "no county abatement"** (Res. 26-25): show what the county, hospital
  district, junior college, ESD-1 and lateral road **collect** if it is built unabated, net of
  the service costs it imposes — the opposite arithmetic from the June site.
- Show the abatement case as the **contingency** it is, with the honest caveats: a resolution
  binds neither a future court nor the other taxing units, and Ch. 312 never reached school
  districts anyway.
- Add the **state-level** subsidy the county cannot refuse: §151.359 / §151.3595 sales-tax
  exemptions (including on electricity), and JETI eligibility for the **generation** asset
  while the data center itself is statutorily excluded.
- Keep the ag-rollback number at 3 years + 5% interest (HB 1743) and **fix or retire
  `RCO_05c` / `RCO_05d`**, which still compute 5 years.

### 4.5 Code to reuse
- Reuse: `RCO_05f_local_net.R` (current, corrected net-local-loss engine), `parker_taxable_base.csv`,
  `parker_jurisdictions_2025.csv`, `bm_parcels_2026.csv` + `parse_bm.py`, `scripts/viz_style.R`
  (design system), `build_og_card.R`, the slides shell, and `court_records/`.
- Retire or rewrite: `RCO_05c_bm_panels.R`, `RCO_05d_phases.R` (stale rollback math and the
  single-point buildout), plus every public surface carrying the $47,199 per-family headline.
- New: a scenario-grid script (working name `RCO_05g_scenarios.R`) that takes scale and
  abatement as parameters and emits the grid rather than a point estimate; and a water-ceiling
  calculator driven by the UTGCD allocation formula.

---

## 5. Open items to resolve before publication
1. **Attempted 2026-09-01 — blocked, and the block is now documented on the site.** TCEQ's
   Central Registry entry for Registration 179422 carries status, holder and address but no
   capacity; the Central File Room returns zero public documents for that number. The terms
   need a records request to TCEQ Air Permitting (airperm@tceq.texas.gov). Meanwhile the same
   operator's **Bowie County plant (RN112380654)**, filed February 2026 under the same standard
   permit for electric generating units, discloses roughly **446 MW** — so these registrations
   do state capacity, and 75 MW should not be treated as a ceiling either.
2. **Attempted 2026-09-01 — partially blocked.** The district publishes a "District Tract Size
   Requirements Map" (the artifact that draws the 60-foot / western line) but does not expose a
   URL for it; contact is the district GIS analyst, jacob@uppertrinitygcd.com, 817-523-5200.
   Note also that UTGCD's August 27 agenda included a work order with EKI Environment and Water
   to build and calibrate a **local numerical groundwater flow model**, which will eventually
   supersede the GAM for thickness determinations at a specific tract.
3. The district's posted rules PDF is still the **February 22, 2021** version as of
   2026-09-01, so the adopted amendment text is quoted from the proposed-amendments document
   read together with the signed August 27 agenda ("possible action on adopting proposed
   amendments to District Rules"). Re-pull once the adopted version is posted.
4. Obtain the **text of Resolution 26-25** and the 2026-06-09 water resolution from the county
   clerk for direct citation (currently sourced to meeting transcripts).
5. Confirm where the **391 track** landed after 2026-07-15 (Parker–Hood consortium vs.
   NCTCOG regionalization) — the local transcript corpus stops there.
6. ~~Decide whether the site keeps any per-family figure.~~ **Decided 2026-09-01: retired.**
   It divided a scenario by households and read as a bill. The rebuilt Phase 1, Buildout and
   water sections use no per-household figure at all. If you want it back in any form, say so —
   it is a one-line change in `RCO_05g_scenarios.R`.

## 6. What was rebuilt on 2026-09-01
- `profile_2026_09/RCO_05g_scenarios.R` — scenario-grid model (scale x abatement), replaces
  `RCO_05d` and supersedes `RCO_05f` for public surfaces. Emits `scenario_table.csv` and three
  figures: `scenario_grid_A.png`, `who_collects_B.png`, `water_ceiling_C.png`.
- `slides/index.html` — sections 06 (Phase 1) and 07 (Buildout) rewritten; new section 07b
  (what the land can legally yield); jump-nav updated. Original saved as
  `profile_2026_09/slides_index.html.bak`.
- `index.html` and all four `mirrors/` pages — the "$30M to $364M" bullet and the OG/Twitter
  descriptions replaced with the Resolution 26-25 baseline framing; footer date updated.
- `build_og_card.R` / `og_card.png` — headline changed from "$364M" to "No number filed."
- `SOCIAL_POSTS.md` — all three drafts rewritten to the scenario-grid framing (no $364M
  headline remains anywhere on a public surface).
- `RCO_05b` / `RCO_05c` / `RCO_05d` — ag-rollback corrected from 5 years to 3 + 5% interest,
  and `05c` / `05d` carry a DEPRECATED banner pointing at `RCO_05g_scenarios.R`. Both still
  parse, so nothing silently breaks.
- `slides/index.html`, second pass — section 05 subhead no longer states 75 MW as a permit
  term; section 10 rebuilt as the full mitigation ledger with the Ch. 102A mechanism; new
  section 10b on Chapter 391; section 11 rebuilt around what the court has already done;
  the Sources & methodology slide rewritten (grid method, JETI, per-household retired) and its
  unarchived turbine-ratings spreadsheet flagged as a correction.
- A turbine-class tension worth carrying forward: 5 turbines at 75 MW implies ~15 MW units, but
  three of this operator's Tarrant registrations are named **Siemens SGT-800** — a 45-62 MW
  machine. Five of those would be 250 MW+. Not asserted on the site; flagged as the reason the
  permit file matters.
- **Verified 2026-09-01:** SB 2858 (89R) — the bill that would have added AG enforcement and
  sales-tax withholding to Ch. 102A — **died in House Calendars**. The [VERIFY] flag in
  `Campaign Materials/statutory_reference_391_102A_WC36.md` can be resolved: not law.
- Still stale and deliberately left alone: the slide "Six specific actions for the June 9
  session." The ask needs your call, not mine.
- One provenance find worth flagging: `parker_costs/court_records/TCEQ_inquiry_draft.md` (an
  untracked June draft letter) describes Registration 179422 as five **Siemens SGT-400** units at
  15 MW — the apparent origin of "75 MW" — but carries no citation, and nothing else in the repo
  corroborates it. The deck now presents both readings (SGT-400 at 15 MW vs the operator's
  SGT-800 registrations at 45-62 MW) and asserts neither. That letter is also worth sending as
  drafted: its NOx question is strong — Parker is in the DFW **Severe** ozone nonattainment area,
  where the major-source threshold is 25 tpy (30 TAC §116.12), and a plant permitted as
  "backup/bridge power" but testified to run 24/7 may not belong on the standard-permit pathway.

### Campaign finance — verified 2026-09-01 against the TEC bulk data
Queried `tec_finance.contributions_raw` (35.9M rows, current through the 2026-07-15 filing
deadline). Query and extract archived at `profile_2026_09/tec_black_mountain_query.sql` and
`tec_black_mountain_contributions.csv`. All three figures check out:

| Recipient | Total | Detail |
|---|---|---|
| Texans for Greg Abbott | **$1,036,750** | $500,000 Black Mountain Power LLC 2025-11-14 (#101029815); **$500,000 Bennett 2026-03-06 (#101055764)**; $36,750 Bennett 2024-10-23 (#100987892) |
| Sen. Phil King (SD-10) | **$20,000** | $10,000 Bennett 2024-09-26 (#100970637); $10,000 Bennett 2025-09-30 (#101026985) |
| Rep. Ken King (HD-88) | **$30,000** | $10,000 Black Mountain Power LLC 2025-11-06 (#101028141); $10,000 Bennett 2026-01-09 (#101035143); $10,000 Black Mountain Power LLC 2026-06-25 (#101058003) |

**The name question, resolved.** The $20K and $30K only add up because the CEO files under two
name forms — "Rhett Bennett" and "John Bennett" — both Fort Worth, both Black Mountain
employers, both Founder/CEO or Chairman. A 2018-04-23 filing under **"John Rhett Miles Bennett"**
(Black Mountain Oil & Gas, CEO, Fort Worth 76102) ties them to one person. The site now discloses
this in a name note so the arithmetic is checkable.

**One limit to state when using these numbers.** TEC data covers contributions through
2026-06-30. Anything given after that date is not reportable until the January 2027 semiannual,
so the absence of a later gift is not evidence there wasn't one.

**Also carried onto the site:** an explicit no-inference line. Nothing in the record shows a
contribution bought a decision, and the fact cutting hardest against that reading is that the
same Governor froze data-center interconnections statewide on 2026-08-03.

**And verified in the other direction:** the deck's claim of no contributions to any member of
this Commissioners Court now cites the work behind it — 234 county filings for 25 officials,
2021-2026, OCR'd and searched against 30 entity patterns, zero donor-field matches
(`State_Budget/99_analysis/parker_local_cf/findings.md`).


### Water, counted whole — added 2026-09-01
The first pass modelled only makeup water at the data hall, which is the framing that lets a
closed-loop project be called water-neutral. Corrected: total water = **direct** (cooling makeup,
charged on IT load) + **indirect** (water consumed generating the power, charged on IT load x PUE).
Closed-loop rejection is less efficient, so PUE rises and the indirect term grows exactly as the
direct term shrinks.

Generation factors, Texas-specific: gas turbine with **wet NOx control 0.05 gal/kWh**, dry control
~0, combined cycle with tower **0.23**, once-through 0.15 (TWDB, *Power Generation Water Use in
Texas*). Cross-checked against Macknick et al. (NREL/TP-6A20-50900) medians: NGCC tower 205
gal/MWh, once-through 100, dry cooling 2. Direct factors: 0.10-0.50 gal/kWh evaporative,
0.005-0.02 closed-loop; PUE 1.15 vs 1.30.

At 75 MW of IT load (Mgal/yr, `water_system_configs.csv`):

| Configuration | Direct | Indirect | **Total** |
|---|---|---|---|
| Evaporative + dry-NOx on-site turbines | 197 | 0 | **197** |
| Evaporative + wet-NOx turbines | 197 | 38 | **235** |
| Closed-loop + dry-NOx turbines | 8 | 0 | **8** |
| Closed-loop + wet-NOx turbines | 8 | 43 | **51** |
| Closed-loop + grid or combined cycle | 8 | 196 | **205** |

The headline: **closed-loop on grid/combined-cycle power totals about the same as evaporative** —
the water moved, it did not leave. Only the closed-loop + dry-NOx configuration is genuinely small,
and that is a choice made in an air permit, not a water permit.

**The local sting:** this project proposes to generate on the tract. If it does, the indirect water
is also district water, drawn from the same aquifer against the same allocation — which means the
turbines' NOx control method is a groundwater decision buried inside an air registration that was
issued in 2.5 weeks with no public process.


### The ask slide, rewritten 2026-09-01
Old asks 1, 2 and 5 (refuse abatements, use the Ch. 381 framework, keep it in open session) are
adopted and were removed rather than repeated. Old asks 3, 4 and 6 were undone and are folded
into the new list. The six current asks:
1. Send the drafted TCEQ letter (DFW Severe nonattainment / 25 tpy NOx question) **plus** a
   records request for the registration file — the capacity number missing from every surface.
2. Amend the June 9 water resolution from "no open-loop cooling" to a **total-system water**
   standard, so a project cannot comply by moving the water upstream.
3. Put the county on the record with UTGCD: standing notice request, stated contested-case
   intent, and a request that high-volume applications disclose cooling **and** generation water.
4. File with PUCT/ERCOT before the audit closes 2026-12-10: publish results county-by-county,
   and report water whole rather than in two separate boxes.
5. Settle the 391 route with a date certain, and open contact with the other 11 named counties.
6. Ask the hospital district, junior college, ESD-1 and lateral road fund to match Resolution
   26-25, and adopt a road-use/financial-assurance policy before construction traffic.

7. **Decommissioning bond**, with parameters specified — see below.

Deliberately absent: any moratorium, plat denial or land-use prohibition — the routes that drew
the Hill and Hood County litigation under Ch. 102A. The closing resident slide was also updated:
its "the abatement vote is the citizens' lever" line is obsolete, replaced by the GCD
contested-case right and the audit comment window.


### Ask 7 — decommissioning, and why it is written the way it is
**The precedent argument:** Texas already requires removal obligations and financial assurance for
other energy infrastructure through the landowner agreement — Util. Code Ch. 301 (wind, HB 2845
2019), Ch. 302 (solar, SB 760 2021), Ch. 303 (battery storage, HB 3809 2025), with HB 3228 adding
recycling and disposal costs to the assurance formula for agreements signed on or after
2025-09-01. The storage standard: equipment, transformers, substations and cables removed to at
least 3 ft below grade, holes filled with like soil, roads removed, land restored to tillable
condition and reseeded, cost set by an independent Texas-licensed engineer. **Data centers and
their on-site generation fall under none of it.** The ask is parity, not novelty.

**The mechanism, given preemption:** the county cannot impose this by ordinance without inviting a
Ch. 102A suit. So the ask is to adopt the terms as policy and require them in every instrument the
county does execute (road-use agreement, utility or right-of-way consent, any future incentive
agreement), ask UTGCD to carry the well-plugging piece, and ask the delegation to close the
statutory gap in 2027.

**Two places the parameters deliberately exceed the state statutes**, because both are how these
funds fail in practice:
- **No salvage-value credit.** Chs. 301-303 let the assurance be reduced by salvage less
  debt-pledged value. When scrap prices fall, the fund is short exactly when it is needed.
- **Posted before ground disturbance, per phase** — not at year 10 or year 15, as Ch. 303 allows.
  Assurance that arrives after the risk period is not assurance.

**And the piece nobody writes down:** "return to pre-data-center state" is unenforceable without a
**baseline** — a pre-construction condition survey (topography, drainage, soil profile and
compaction, ag classification, vegetation, every water well with static level and water quality,
dated photographs) filed and escrowed before the first ground disturbance. The bond restores the
property to that document. Removal depth is set at **4 ft** rather than the statutory 3 ft to clear
tillage and root zone; restoration adds decompaction to 18-24 in, 12 in of certified topsoil,
reseeding with 3 growing seasons of weed control; security is cash, an irrevocable standby LOC, or
a Circular 570 surety bond, with no parent guarantees and no self-bonding; triggers at 12 months
non-operation, abandonment, bankruptcy or lapse of the air registration, with 18 months to
complete; recorded as a covenant running with the land, transfer conditioned on replacement
security, released only after county-verified restoration and two growing seasons of vegetation.

- Nothing has been committed or pushed.

## Sources
State/regulatory: Gibson Dunn (Batch Zero); Texas Tribune 2026-06-30, 2026-08-03, 2026-08-14;
KERA / Houston Public Media 2026-08-04/05; Utility Dive; Akin; Troutman Pepper Locke;
McGuireWoods, Bracewell, Baker Botts, Sidley (SB 6); Texas Comptroller (JETI; qualifying data
center sales-tax exemption); Justia (Tax Code §151.3595).
Local: MultiState 2026-08-19; Public Citizen *Texas Data Center Policy Guide*; Fort Worth
Report; The Real Deal 2026-08-28; Weatherford city statement (Jan 2026); Fort Worth
Star-Telegram / Yahoo 2026-05-20 and 2026-05-21.
Primary local records: Parker County Commissioners Court transcripts 2026-05-26, 06-09, 06-22,
06-30, 07-13 (`commissioners court studies/video_meetings/transcripts/`); Parker–Hood 391 draft
resolution; UTGCD proposed rules amendments for the 2026-08-27 hearing.
