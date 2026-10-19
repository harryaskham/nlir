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
| [`gapfill.sh`](gapfill.sh) | no | gap-filled specs: per-field lists of the points a spec implies and the decisions it leaves open, and the list-guided trim that keeps only what states them — the branch logic and the trim prompt checked |
| [`replay.sh`](replay.sh) | yes | the realisation store: record once, replay deterministically, `--replay strict` audits |

The design these follow is [`docs/design/v2.md`](../docs/design/v2.md); the full
operator reference is `nlir help` or [SPEC.md](../SPEC.md#config-operators-the-language-proper).
