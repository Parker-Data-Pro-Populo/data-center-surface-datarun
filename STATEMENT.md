# Standards, methods, and disclosures

*How this research is made, checked, and corrected — revised September 7, 2026*

## What this publication is

This is citizen research: analysis built from public records, published together with the records,
the code and the methodology, so that any reader can check the work or redo it differently and
reach their own conclusion.

The current subject is a data-center and power-generation development near FM 730 and Pearson Ranch
Road in Parker County, and the statewide network of gas-plant registrations held by the same
operator.

> **This publication has a position on process. It has no position on data centers.**

That distinction does most of the work here, and it is easy to lose, so it is set out explicitly
below rather than left to be inferred.

### What it takes a position on

- Public records should be *practically* accessible, not merely technically public.
- Decisions of consequence should be reviewable before they become irreversible.
- Where a capacity figure, a permit file or a resource allocation does not appear on any public
  surface, that absence is itself a finding and should be reported as one.
- A community should be able to read the terms before it is bound by them.

### What it takes no position on

- Whether data centers are good or bad — in general, in Texas, or here.
- Whether this project should be built.
- Whether any official or company has acted improperly. Where filings, dates and amounts are
  reported, they are reported as filings, dates and amounts, and the briefing says so at the point
  of contact.
- Any candidate, party or election. See the disclosure below.

A community that wants a data center, with its eyes open, should be free to have one. A community
that does not should be free not to. The argument made here is narrower than either: that the
choice should be made with the facts in hand, and that at present several of them are missing.

## The evidence standard

Every claim in the briefing carries one of four labels, used in the headings, the captions and the
scenario grid:

- **Documented** — in an official filing, adopted resolution, agency record or appraisal notice.
- **Testimony** — said on the record in a public meeting, but not yet confirmed in a filed
  technical document.
- **Scenario** — an illustrative calculation from stated assumptions. Not a prediction, and not a
  forecast of what any party will do.
- **Open question** — information that appears on no public surface and should be requested before
  decisions are made.

Two rules follow, and they are worth stating because they are routinely confused with each other:

- **A documented fact is stated flat, without hedging.** Softening a fact that can be checked
  understates the record, and a reader who goes and checks will find that it was understated. That
  costs more trust than plain statement ever does.
- **An inference is labeled as an inference** and hedged accordingly. It is never quietly promoted
  to a fact because the promotion would be convenient.

This publication does not infer motive from campaign contributions, corporate structure, property
ownership or permit timing. Where the record is incomplete, it names the missing document and the
body that can produce it.

## Corrections

The willingness to correct is the price of being trusted, and it is worth more when the corrections
are visible than when they are quiet. Errors are fixed in place, dated, and described — not
deleted. Superseded versions stay online.

The record so far, all of it public:

- **The June 2026 briefing was substantially wrong about cost, and is preserved unchanged.** Its
  headline figures assumed an 80% Chapter 312 abatement. Parker County then adopted Resolution
  26-25, declining abatements for data centers — so the briefing was describing a scenario the
  county had formally refused. It was rebuilt around a scenario grid. The original is still
  published, with its original numbers, at `archive/2026-06/`, so anyone who read it, cited it or
  argued against it can see exactly what it said.
- **An entire section was retracted.** A siting-risk index published in June was re-run in
  September and found to be defective: the score saturated for fifteen counties, and two of the
  published ranks could not be reproduced. The section was withdrawn and the retraction published
  in its place rather than the section being silently removed.
- **The site acreage was corrected** from 2,075.28 to about 2,081, after a nineteenth adjacent
  parcel of 6.53 acres — bought from the same seller, but never issued a corrected notice — was
  traced in the appraisal records.
- **A rollback-tax figure was corrected** from five years to three, following the 2019 amendment of
  Tax Code §23.55 by HB 1743.
- **A published map was upside down for three months.** An argument-order bug in the plotting code
  mirrored the basemap vertically behind correctly drawn county boundaries. It was fixed, the chart
  regenerated, and the cause written into the source file.

If a figure here is wrong, the correction is wanted more than the appearance of having been right.
Corrections and challenges: henry.lee@henrylee.vote.

## Disclosures

### Who produces this

This research is produced by **Henry Lee Butler**, working independently. There is no commercial
affiliation, no client, no sponsor, and no funding from any party with an interest in the outcome —
no developer, no landowner, no utility, no trade association, and no opposing group.

**Political activity.** The author is a candidate for **Parker County Commissioner, Precinct 2**,
running as a Democrat, and publishes campaign material at henrylee.vote. That is stated here rather
than left to be discovered, because a reader is entitled to know it before deciding how much weight
to give anything on this page.

What follows from it, concretely. The campaign version of this briefing argues a case; this version
does not, and the two are kept on separate domains for exactly that reason. Both are built from the
same repository, the same data and the same code. **Neither is permitted to carry a figure the other
does not** — where they differ, they differ in voice, never in a number, a date, a citation or a
source line. Both versions are in the public repository, so that commitment can be checked by anyone
who cares to compare them.

### The use of AI

The data assembly, statistical models, cartographic rendering and much of the drafting were produced
with the assistance of Anthropic's Claude. That is disclosed here, on the landing page, and in the
repository.

**What that means in practice:** parsing eighteen PDFs of tax notices; joining 254 county polygons
to 101 groundwater-district boundaries; querying public databases through their documented
interfaces; running a cost model whose formulas are traceable in published source code; drafting
narrative passages that are then checked against the cited sources line by line.

**What it does not mean.** No quote is generated; every quotation from a public official traces to a
published meeting record or a filed document. No statistic is invented; every numerical claim is
reproducible from source code in the repository. Nothing is represented as primary research that has
not been verified against a primary source. No legal opinion is offered. No individual is identified
who is not already on the public record.

A human reviewed every output before publication and is responsible for all of it, including the
errors listed above. The tool does not dilute that responsibility, and citing it would not be an
excuse.

## What citizen research looks like, done well

- **Source every factual claim.** If a claim cannot be traced to a public record, it does not get made.
- **Publish the underlying data.** Other people may want to verify, or extend, or disagree. None of
  those is possible if the data is held back.
- **Publish the methodology.** Any reader should be able to reproduce any number from the published
  code and data.
- **Disclose your tools.** What software, what AI assistance, what databases. Tools are not the
  work, but concealing them is bad practice.
- **Invite correction.** Wrong facts get corrected with a dated note, in public.
- **Do not hide behind credentials.** This is citizen work. The alternative — that only credentialed
  experts may analyze public records — is its own kind of closed door.
- **Label the difference between fact, inference and opinion,** and never let one drift into another.
- **State the other side's best case, not its worst.** A brief that only assembles one side should be
  read with suspicion, including by the person who wrote it.

## Challenging this work

Disagreement is welcome and is easier here than in most places, because the inputs are published.
The most useful challenge names a specific figure, points to the record that contradicts it, and
says what the corrected number should be. That kind of challenge gets a correction and a dated note.

The standard this publication tries to hold — and the one it would ask of anyone contesting its
findings — is that every claim should survive a hostile reading by someone who has the underlying
documents.

---

This statement may be cited, quoted or republished freely with attribution. The source code, data
and methodology are at github.com/Parker-Data-Pro-Populo/data-center-surface-datarun.
Corrections and questions: henry.lee@henrylee.vote.
