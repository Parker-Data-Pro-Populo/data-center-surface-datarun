# Balance pass — September 7, 2026

Disposition of the reviewer memo *"Tone and Framing Recommendations for the Parker County
Data-Center Briefing Draft."* The memo was written against the current published deck, not an
earlier draft: nine of its ten flagged phrases were live in `slides/index.html` when it arrived.

**No number changed in this pass.** Every edit is voice, sequence or addition. The model
(`RCO_05g_scenarios.R`), the scenario grid, the water accounting and the source citations are
untouched.

---

## Adopted

| Recommendation | What was done |
|---|---|
| Add a reader guide naming the evidence labels | New **How to read this briefing** card on the cover, below the contents. Four labels defined — Documented, Testimony, Scenario, Open question — plus an explicit statement that the briefing does not infer motive from contributions, corporate structure, ownership or permit timing. The labels already existed in the model; nothing announced them. |
| Drop the presupposition of net cost from the title | Cover h1 is now *"Black Mountain Power LLC — the record, the open questions, and what the county can decide."* Cover lead rewritten to match. |
| Replace §00 | *"00 · Purpose of this briefing."* The campaign-voice original is preserved verbatim at `variants/00_what_we_face.campaign.html`. |
| Separate the contributions from the permit timing | §03 split. Entities and roles stay at slot 3 under a neutral heading; the contribution table moves to a **new §05b, placed after the permit**, so a reader knows what the registration was before seeing what was given and when. The "what we are not claiming" language is now stated *up front* in that section rather than beneath the table. |
| Do not attribute intent | §02 lead: "deliberately pulled out of Weatherford's jurisdiction … so the people most affected have the least say" → the documented ETJ petition, then the participation question it raises. §03 subhead "a documented trail of political giving alongside a 2.5-week permit" removed. |
| Name the safeguard before the action | All seven asks in §11 re-led with the information or protection sought, then the instruction. Section renamed *Recommended next steps*. |
| Participation language over conflict language | §14 is now *Questions and participation*; "Coordinated pushback" → "Coordinated public engagement and information-sharing"; "the abatement fight is over" → "the abatement question is settled." Campaign original at `variants/14_questions.campaign.html`. |
| §07b water heading | "Count the whole system, or the water just moves where nobody is looking" → "Count the whole system: cooling water and generation water together." |

Also removed, though the memo did not raise it: the annotation **"Williamson (Jonah TX) —
highest-leverage organizing target"** baked into chart G, and "Hill · Hood · Hays — conspicuously
absent" in its subtitle. Both were campaign language inside a data graphic. `regen_chart_G_2026-09.R`
now takes `RCO_VOICE=neutral|campaign`; neutral is the default and is what both surfaces publish.

---

## Added — not in the memo

**§02b · The case for the project.** The memo is entirely subtractive: remove adjectives, soften
verbs, hedge claims. It never asks for the affirmative case, which is the larger credibility gain
and costs nothing, because the case survives being stated well.

Five points, put as a proponent would put them: full tax capture with no abatement and no local
money out the door; a lawful sale by a willing seller; a large load that arrives with its own
dispatchable generation under SB 6 curtailment terms; sales-tax exemptions granted by the
Legislature and not by this county; and agricultural land that was already fragmenting.

It closes by conceding that three of the five are simply correct and are treated as settled
throughout — and that the other two rest on facts not on the public record:

> The case for this project may well be right, and it cannot presently be checked.

That is the briefing's whole argument stated in the friendliest available terms, and it is a
stronger position than the one it replaces.

---

## Declined, with reasons

**1. The proposed central message.** *"Parker County can support responsible investment while asking
for clear, verifiable commitments…"* presupposes the project is good and merely needs conditioning.
The accurate neutral frame is narrower and harder to argue with: the public record is incomplete,
and decisions are proceeding anyway. That is more demanding *and* less partisan, because it makes no
claim about whether data centers are good. Neutrality is fidelity to the record, not the midpoint
between two positions.

**2. Uniform hedging.** The memo asks for calibrated language — "may," "could," "raises the
question" — *and* for four evidence labels. These fight each other. The point of labeling evidence is
that a documented fact no longer needs a hedge. The permit cleared in 2.5 weeks: that is date
arithmetic. $943,097 is printed on a corrected notice. Hedging those manufactures false uncertainty,
and a reader who checks finds the briefing understated itself, which costs more trust than
bluntness. **Adopted as: hedge the inferences, state the documented facts flat** — which is what the
reader guide now tells the reader to expect.

**3. The suggested titles.** All five call it a *proposal*. There is a TCEQ registration, an
~2,081-acre assembly, an agricultural exemption stripped across 18 parcels and $2.81M in rollback
tax owed. It is not a proposal; it is underway, and "proposal" understates the record. The specific
objection to *"what it will cost"* was correct and is fixed; the replacements were not adopted.

**4. Moving the contribution table to an appendix.** Out of slot 3, yes — done. Into an appendix, no.
It is verified public record with TEC report numbers, and the memo's own text says "retain the
underlying public records." It sits in the body, later, under a neutral heading, with the
disclaimer moved above it rather than below.

**5. Some wording swaps are euphemism creep.** "what worked, what got reversed, and what got sued" →
"the legal constraints they faced" is vaguer and less useful: communities were *actually sued*, under
Civil Practice & Remedies Code Ch. 102A, with waived immunity and asymmetric fees. A commissioner
deciding what is safe to attempt needs the specific fact. **Adopted as: drop the characterization,
keep the concrete verb** — the heading now reads *"The ledger: what held, what was reversed, and what
drew a lawsuit."*

**6. Renaming the siting-risk index.** That section was retracted in the September 3 audit — the
index saturated for 15 counties and two published ranks were not reproducible. Only the retraction
note remains. Nothing to rename.

---

## The fork

Most of this memo is, in effect, a specification for the **texascrossroads.net** reporting voice. Applied
wholesale to **henrylee.vote** it would neuter a campaign document that is entitled to argue.

`profile_2026_09/variants/` holds the campaign-voice originals of every passage replaced here, so the
split is a build step rather than a rewrite. Chart G already builds both ways from one script. The
numbers stay single-source in either case — that was the lesson of the June mirrors, and it is not
being relearned.
