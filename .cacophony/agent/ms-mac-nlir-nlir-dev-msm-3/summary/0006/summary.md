# Session summary — nlir help: example-driven learning resource (bd-5c19c4)

## Goal

bd-5c19c4 (P1, Harry/learnability): make `nlir help` a comprehensive learning
resource — input→output examples per language feature — so agents/users can
learn nlir from the CLI. Previously `nlir help` was only a config-derived
operator *reference table* (no examples).

## What landed

- `src/main.rs`: new `print_help_examples()` (called from `run_help` before the
  footer) prints a curated **examples** section — ~35 `input → output` pairs
  across 10 feature groups: numbers/arithmetic, text (join/concat/repeat/split),
  forms (`{…}` + `%`), named forms, do-N, map/fold, scan/filter, trains (atop +
  fork), assignment/context, and language ops (the fuzzy realisers, shown as
  their det stub with a note that a model gives fluent English). Grouped,
  aligned, dim explanatory notes.
  - The example table is a `HelpExampleGroup` type-aliased data structure.
- Every det example is **verified-runnable**: sourced from the CI-guarded
  `tests:` block in config.example.yaml (msm-1's "help ≡ CI" model, coordinated
  with msm-1/msm-2 to avoid dup with cookbook/composable-core). Added two
  `help-*` test keys (`help-join3`, `help-assign-compute`) to close the last
  coverage gaps, so all example expressions are now green under `nlir test`.

## Verification

- `nlir test`: 74 passed / 0 failed (incl. the 2 new help-* keys).
- All 35 rendered examples independently re-run in det mode → produce exactly the
  shown output (list newlines shown space-joined, per the section note).
- Preflight: `cargo fmt --all --check`, `cargo clippy --all-targets -D warnings`
  (added a type alias for clippy::type_complexity), `cargo test --lib` (271) +
  `--bin nlir` (34) all green.

## Scope / follow-up

Scoped to the LANDED/stable core (coordinated during the active APL/J loop).
The just-landed `$if`/`$nth`/`$sort` + the incoming comparison ops (`== <= …`)
are intentionally deferred to a follow-up "once stable" (msm-0's ask), to be
added to the same examples table + `nlir test`.

## Operator-takeaway

`nlir help` now teaches the language by example — run it and you see 35 real
programs and their outputs, from `1+2*3 → 7` to `$fold%({$0+$1},$map%(…)) → 14`
to the point-free fork `(# & ~)%'x' → subject: x and summary: x`. Every one is a
green CI test, so the help can never drift from the language.
