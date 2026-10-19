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

## Next

- **Backward through the concept layer**: an edit to a sentence maps to an edit of a node (text,
  polarity, scope, a new node), and a node either rests on a packet passage (show it, or propose the
  passage edit) or is an addition the packet does not imply.
- **Consistency checks after every pass** — no overlap between MET and NOT MET, UNCERTAIN about facts
  only — reported, with the co-edit that would restore them.
- **An explainer page**: spec passages → rule model → profile parts in three lanes; a stepped
  forward pass with every model call shown as prompt (program text, data, examples) and response;
  edits animated backward to nodes and passages, then forward as diffs; flat and structured
  programs side by side.

Single judge, eight rules and one sample per edit: indicative, not yet a measured effect.
