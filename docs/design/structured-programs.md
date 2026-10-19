# Structured spec ⇄ prose programs: crosstalk, a concept layer and consistent edits

*Design note and first results on the spec lab's invented code-review spec (public data only).*

## The problem

Learned program B is a shared context string (instructions, worked examples, the packet as JSON)
and five **independent** model calls, one per profile part, concatenated by `$render`. No part
reads another, and nothing in the program says that MET, NOT MET and UNCERTAIN partition the
cases or share an action, conditions and permissions. Its graph is a star: packet → five prompts
→ five paragraphs. Two consequences:

- **Nothing to see.** A visualiser of the forward pass can only show five prompts being assembled.
- **No crosstalk.** The lens inverts deterministic steps exactly, but an edit that reaches a model
  call is inverted by a model asked for the smallest edit to that call's inputs — usually a
  find/replace in the packet text. An edit to MET reaches only MET's inputs; nothing requires NOT
  MET to stay its contrast, so a negation added to MET leaves the profile inconsistent.

The search found the star because it could only find it: it edits prompt wording, scores each part
independently and penalises extra statements; nothing in the objective rewards coherence.

## Two structured programs

Both are B·clean with the same instructions and worked examples (`site/spec-lab/`):

- **`program-b-chained.nlir`** — NOT MET is written from the MET paragraph and UNCERTAIN from
  both. Any part can be *pinned* through the packet key `_pin` (`{"_pin": {"MET": "…"}}`): a
  pinned part makes no model call and the parts after it are re-derived from it. The key never
  reaches a prompt; with nothing pinned the first three calls are B·clean's exactly. A first test
  showed the later parts siding with the packet against an edited MET, so the earlier paragraphs are
  declared authoritative where they narrow or extend the packet.
- **`program-b-concepts.nlir`** — one call extracts a small **rule model**: the action under
  judgement, the conditions that must all hold, the permissions any one of which avoids the
  violation, and the facts a verdict turns on, each with an id and the packet passage it rests on.
  Every part is written from that model, with its derivation stated: MET is the action with every
  condition and no permission, NOT MET its exact complement, UNCERTAIN the facts that decide. Pin
  `_pin.model` and editing one node re-derives every part from the same nodes.

## Results (8 toy rules not used in training)

**Meaning, no edits** (four samples per rule; strict F1 against the authored profiles, Sol judge):

| program | strict F1 | style | combined | words per part |
|---|---|---|---|---|
| flat B·clean | 0.346 | 0.873 | 0.544 | 26 |
| chained | 0.349 | 0.875 | 0.546 | 26 |
| concept layer | 0.317 | 0.862 | 0.515 | 27 |

Chained against flat: strict F1 +0.003 [-0.021, +0.034] — the structure is free. Concept
layer against flat: -0.030 [-0.076, +0.011] — a possible small cost, not significant on
eight rules; the model keeps at most four conditions, three permissions and three facts, so some
packet detail can be lost on the way through it.

**Coherence under an edit** (one sample per rule): Sol proposes one plausible exception per rule that
its packet does not contain; each program receives it as an edit and Sol judges the result.

| program and edit | MET excludes the case | NOT MET covers it | MET and NOT MET overlap |
|---|---|---|---|
| flat — the exception appended to MET (nothing else can reach NOT MET) | 7/8 | 1/8 | 1/8 |
| chained — MET pinned with the exception | 7/8 | 8/8 | 2/8 |
| concept layer — the exception added as a permission node | 8/8 | 8/8 | 0/8 |

An edit to a flat profile stays where it was made. Chaining carries it to every later part, with
occasional overlap; the concept layer carries it everywhere and keeps the parts a partition.

## Backward through the concept layer

`site/spec-lab/lens-concepts.nlir` pushes an edited sentence back to the rule model: one model call reads
the model, the packet and the part before and after the edit, and returns node edits — change a node, add
one, remove one — each with the packet passage it rests on, or none. Applying them is deterministic; the
forward pass then re-derives every part from the edited model.

Closed loop on the eight rules, the same exceptions made as sentence edits to MET: the backward pass
returned a new exception node for 7/8 (the eighth narrowed an existing exception instead),
each marked as not in the packet; after re-derivation MET excludes the case 8/8, NOT MET covers it
8/8 and the two overlap 0/8 — the same as editing the node directly. A sentence edit travels
as coherently as a model edit.

## When an edit contradicts the spec

Reversing MET on one rule ("does not approve" where the rule makes approving the violation) is pushed back
correctly — the action and its condition are negated, with no packet passage behind them — but the re-derived
NOT MET follows the packet, not the edited model, and now overlaps MET. Structure alone does not settle an
edit that contradicts its source, so `site/spec-lab/lens-check.nlir` checks every pass: do MET and NOT MET
overlap, does a case fall between them, and is each node the spec does not state an **addition** (the spec
is silent) or a **contradiction** (the spec says otherwise, with the passage)? On the reversal it reports the
overlap, with a concrete case, and the contradiction, quoting the rule. On the eight exception edits it finds
no overlap (0/8); it reads exceptions added to absolute "must not" rules as contradicting them
(5 nodes) and finds 4/8 cases the re-derived NOT MET does not cover — a reason to derive
NOT MET as an explicit disjunction over the nodes. It warns; it never edits.

## How strict is the check?

Run on the eight **authored** toy profiles (with an empty model, so only the overlap and gap questions apply),
the check reports a gap for 5/8 and an overlap between MET and NOT MET for 6/8. It is strict: its gap
cases are plausible but pedantic (an approval with no conditions and no out-of-scope ideas, say). Its flags are
prompts for review, not defects — and by the same check the concept layer's unedited profiles overlap less often
than the authors' (1/8 against 6/8). Deriving NOT MET as an explicit disjunction over the model's nodes
(`program-b-concepts-or.nlir`) did not close the gaps: 3/8 against 4/8 for the concept layer, at
31 words against 27 for NOT MET. Not carried.

## The explainer page

`site/explain/` steps through recorded passes of the three programs on the eight rules: spec passages, the
rule model and the profile in three lanes, arrows for the active step, every model call's exact prompt
coloured by provenance, plain-language narration, the author's exception added as a node, a sentence edit
pushed back to the model, the reversal, and the checks. `scripts/export-explain-traces.py` builds its data.

**Live mode** runs the same loop in the browser on your own endpoint (the spec lab's saved endpoint is
shared): the concept layer forward, part by part, with every prompt captured as it is sent; your edits to
the rule model (as JSON) re-derived and checked; or a sentence edit pushed back through
`lens-concepts.nlir`, re-derived and checked. `scripts/check-explain-live.js` exercises it against a mock
endpoint; it was also run once against real models.

## Next

- **Inline editing** in the explainer: edit a node or a sentence where it is shown, not as JSON.
- **The health lab**: the same page over the private rules, embedded like the Run tab.
- **Measure** the concept layer against the flat program on the private validation rules, behind the
  carry rule, with consistency under edits as a second criterion.

Single judge, eight rules and one sample per edit: indicative, not yet a measured effect.
