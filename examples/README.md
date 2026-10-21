# Examples

Small, canonical programs for the v2 core. Each script runs against the shipped
config (`config.example.yaml`); set `NLIR=/path/to/nlir` to choose a binary.

| script | needs a model | what it shows |
| --- | --- | --- |
| [`structure.sh`](structure.sh) | no | the structural core — Functor/Foldable, Monoid append and power, composition, lens get, data trees — with every output asserted |
| [`meaning.sh`](meaning.sh) | yes | the semantic core — `=>` `::` `..` `!` `&` `Δ` `▷` `~>` `≈` — and the prelude forms built from it |
| [`exact-over-fuzzy.sh`](exact-over-fuzzy.sh) | yes | the model reads, the evaluator counts: fuzzy extraction under exact folds and filters |
| [`spec-roundtrip.sh`](spec-roundtrip.sh) | no | a rule spec loaded as data, projected to prose and parsed back exactly (the spec lab's library) |
| [`lens.sh`](lens.sh) | no | backward passes: edit the prose a program wrote and recover the spec field (or program literal) that would produce it, with the lens laws checked |
| [`cards.sh`](cards.sh) | no | a reversible program on a card game: rules and state as data, which card is played and why — and `nlir put --alternatives` backwards: authored puts, the search for other explanations, frozen inputs, and an edit no input can produce |
| [`cards-explain.nlir`](cards-explain.nlir) | yes | the card program with a model writing the reason: `nlir put --mode llm --alternatives 3 --partial` on an edited reason — a large model proposes inputs (e.g. rule 2 says lowest, hand `[5, 6, 7, 8, 9]`), each verified by running forward |
| [`gapfill.sh`](gapfill.sh) | no | gap-filled specs with [`lib/gapfill.nlir`](../lib/gapfill.nlir): the coverage score, the pick, the pass-through for fields with no lists, and the writer's prompts, checked offline |
| [`gapfill-pipeline.sh`](gapfill-pipeline.sh) | yes | the gap-filled writer end to end on an invented code-review rule: read the two lists from the authored sections, then write, trim and pick every field |
| [`patch.sh`](patch.sh) | no | routed patch forward: an edit to a rule model reaches only the profile fields whose derivation reads what it changed (a fact → UNCERTAIN, an exception or condition → MET and NOT MET) — the deterministic routing and the gating instruction checked |
| [`replay.sh`](replay.sh) | yes | the realisation store: record once, replay deterministically, `--replay strict` audits |

The design these follow is [`docs/design/v2.md`](../docs/design/v2.md); the full
operator reference is `nlir help` or [SPEC.md](../SPEC.md#config-operators-the-language-proper).
