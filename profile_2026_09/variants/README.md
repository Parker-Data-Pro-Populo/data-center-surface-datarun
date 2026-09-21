# Voice variants, and the build that keeps them honest

`STATEMENT.html` makes a promise in public:

> Both are built from the same repository, the same data and the same code.
> **Neither is permitted to carry a figure the other does not** — where they differ, they
> differ in voice, never in a number, a date, a citation or a source line. Both versions are
> in the public repository, so that commitment can be checked by anyone who cares to
> compare them.

`scripts/build_surfaces.py` is what makes that true rather than aspirational.

```
python3 scripts/build_surfaces.py          # build, then check
python3 scripts/build_surfaces.py build    # generate the campaign surfaces
python3 scripts/build_surfaces.py check    # verify the invariant only
```

Non-zero exit on any failure, so it can gate a push.

## Which file is canonical

The **neutral** files are the source of truth and are never written by the build:

| Neutral (canonical, edit this) | Campaign (generated, do not edit) |
|---|---|
| `slides/index.html` | `slides/campaign.html` |
| `STATEMENT.html` | `STATEMENT_campaign.html` |

To change a figure, change it in the neutral file and rebuild. Change it in a variant and
`check` will tell you.

## What lives here

| File | What it is |
|---|---|
| `manifest.json` | Drives the build. Add a variant by adding an entry here, not by editing the script. |
| `00_what_we_face.campaign.html` | §00, replacing *Purpose of this briefing* |
| `14_questions.campaign.html` | §14, replacing *Questions and participation* |
| `STATEMENT.campaign.html` / `.md` | The whole statement, campaign voice |
| `_shared_corrections.html` | The corrections log — **shared, not a variant** |

Chart G is not stored here; `../regen_chart_G_2026-09.R` builds either voice from
`RCO_VOICE=neutral` (default) or `RCO_VOICE=campaign`.

## Shared blocks

Some content is a matter of record rather than voice, and must be identical on both
surfaces. The corrections log is the case that matters: a campaign audience that does not
see the corrections is being told a different story about the work's reliability, which is
the opposite of what the statement promises.

A shared block is injected into the campaign output at `<!-- SHARED:corrections -->`, and
`check` asserts the same text is present in the neutral source, so neither copy can drift.

## Exceptions

`fact_exceptions` lets a figure appear on one surface and not the other, and every entry
needs a reason. The reason must be that the figure is rhetorical or incidental — a dateline,
a road name, typewriters in 1880 — **never** that the two surfaces disagree about the
project. If a project figure ever seems to need an exception, the fix is to correct a
surface. The deck carries no exceptions and should not acquire any.

## How the check works, and one trap to avoid

It extracts every number, statutory citation, agency identifier and URL from the visible
text of both surfaces and compares the sets. Numbers carry a preceding month name and a
following unit where there is one, so `December 10` and `December 12` are different facts
and `10 turbines` is not confused with `10 a month`.

**Do not reintroduce a magnitude filter.** The first version of this check discarded
integers below 16 as list-index noise. That silently threw away real figures — dates,
turbine counts, the three-year rollback, the 25-tons-per-year threshold — and a
deliberately corrupted date passed the check. The fix was context, not filtering.

Worth re-running that test after any change to the extractor: corrupt a figure in a
variant, confirm `check` fails, restore it. A check that never fails is worth nothing.
