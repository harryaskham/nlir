# Session summary — bindings `$name`-reuse footgun note (bd-6995d9)

## Goal

Per Harry's "burn beads" nudge, convert a pyramid gap-find into a shipped bead. Building
his "pyramid of thought" (reusable-parts trains), I hit a silent footgun: a bare word that
coincides with a bound variable name reads as a LITERAL, not the binding — `p..3` → "5"
(garbage) instead of `$p..3` → "Earth". Documented it (fastest generic fix).

## Bead(s)

- `bd-6995d9` (mine, dogfood/bindings/dx) — filed from the finding, promoted draft → open →
  claimed → this reintegration. Resolved via the doc-note option (a bindings SPEC note);
  the heavier lint option ("did you mean $name?") left for a follow-up.

## Before state

- SPEC's `$name` bullet documented reading a binding but did NOT warn that a BARE `name`
  (no `$`) is a string literal — so the reusable-parts idiom `part..3` silently mis-reads
  the literal "part" with no error, the worst failure mode (silent-wrong-output).

## After state

- SPEC §Context read&assign `$name` bullet now states the `$` is REQUIRED to reuse a
  binding: a bare `name` is a string literal (garbage, no error), `$name` reads the value,
  with the reusable-parts idiom `p='…'; $p..3` → Earth. Doc-only; no operator-table change.
- verify-spec-ops OK (30 operators in sync — prose change doesn't touch the guard).

## Diff summary

- Files: SPEC.md (one bindings-note addition to the `$name` bullet).
- No code/operator change; documentation only.

## Operator-takeaway

The reusable-parts / pyramid idiom makes the bare-word-vs-`$name` collision common, and the
failure is silent-wrong-output (a "part" train produces nonsense, no error). The SPEC now
warns explicitly. A "did you mean `$name`?" eval-time lint (the higher-value catch-at-the-
mistake fix) is left as a follow-up on the bead. Golf/pyramid as gap-finder, converted to a
shipped doc fix per Harry's burn-beads nudge.
