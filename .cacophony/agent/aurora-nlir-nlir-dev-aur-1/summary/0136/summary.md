# Session summary — complete the SPEC operator table (bd-2e59bb)

## Goal

bd-2e59bb ("expand operators list schema with complete operator definitions")
had been triaged as satisfied-by-later-work, but a grammar-owner consistency
audit — comparing the operator set across SPEC.md, `nlir help`, and
config.example.yaml (the "these all derive from the same config and stay in sync"
invariant the phrasebook relies on) — found the SPEC operator table was actually
INCOMPLETE: it documented 18 of ~30 config operators. This session completes the
SPEC operator vocabulary so the normative contract matches config/help.

## Bead(s)

- `bd-2e59bb` — Expand operators list schema with complete operator definitions
  (Harry-created; claimed by me after the audit surfaced the concrete remaining
  gap that the earlier triage missed).

## Before state

- Failing tests: none (det suite 120/120).
- SPEC operator tables documented only 18 of ~30 config operators. Missing from
  the SPEC tables: `Δ` diff, `~>` implication-check, `~>?` implication-infer,
  `++` concat, `//` split, `==`/`!=`/`<=`/`>=` (comparisons), `↦`/`⊘` (map/fold
  glyphs) — only 1 occurrence of any of those sigils across all of SPEC.
- Precedence prose listed the key tiers but omitted the newer ops' priorities.

## After state

- Failing tests: none (docs-only; det suite still 120/120).
- SPEC operator tables document all ~30 config operators: 5 text ops added to the
  string/text table (`Δ`, `~>`, `~>?`, `++`, `//`), a new **Comparison operators**
  subsection (`==` `!=` `<=` `>=`), and a new **Higher-order (list) operators**
  subsection (`↦` map, `⊘` fold).
- Precedence prose extended with the newer ops' tiers (`. ..` 16, `//` 13, `++` 10,
  `↦ ⊘` 8, comparisons 5) + a note that `nlir help` has the exhaustive per-op
  priority (the always-in-sync source).
- Audit passes: SPEC ≡ `nlir help` ≡ config for the full operator set.

## Diff summary

- Code/content commit: pending final squash SHA from the reintegration receipt.
- Files touched: `SPEC.md` (11 operator rows + 2 subsection headers + precedence
  extension).
- Tests: unchanged (docs-only).
- Behavioural delta: none — documentation completeness.

## Operator-takeaway

The SPEC operator table had silently drifted incomplete as operators were added
over time (comparisons, the `↦`/`⊘` glyphs, `.`/`..` accessors, diff/implication) —
the "SPEC/help/config stay in sync" invariant the phrasebook advertises was not
actually holding for the SPEC surface. A grammar-owner consistency audit across
the three surfaces is the checkpoint that catches this, and is worth running after
operator additions. bd-2e59bb is now genuinely satisfied for the SPEC surface.
Follow-up worth doing: a CI check asserting the SPEC-table operator set ≡ the
`nlir help` op set, so this drift class can't silently recur.
