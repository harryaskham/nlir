# Session summary — CI guard for SPEC operator-table drift (bd-be33ee)

## Goal

The phrasebook and SPEC advertise that SPEC.md, `nlir help`, and
config.example.yaml "all derive from the same config, so they stay in sync" — but
the invariant was unenforced. `nlir help` and the wasm playground are
auto-derived from config, but the SPEC operator tables are hand-maintained, so
they are the surface that silently drifts (bd-2e59bb had to add 11 missing rows by
hand; bd-4db4ce fixed a stale `..` name). This adds a deterministic CI guard that
fails on any SPEC-vs-config operator drift, closing the class.

## Bead(s)

- `bd-be33ee` — CI guard: assert SPEC operator-table op set ≡ `nlir help` / config.
  Filed during the bd-2e59bb session and implemented here as a supporting CI script
  (self-improvement-mixin: "supporting scripts / test harnesses in scripts/").

## Before state

- Failing tests: none (det suite 120/120).
- No guard: the SPEC operator tables could drift out of sync with config/help
  silently, caught only by manual audit. CI ran rustfmt / clippy / build /
  verify-showcase / test, but nothing checked SPEC ≡ config for the operator set.

## After state

- Failing tests: none (det suite 120/120).
- `scripts/verify-spec-ops.py`: a dependency-free guard (no PyYAML — the keyless
  runner lacks it) that parses operator sigils + names from SPEC.md's operator
  tables and from config.example.yaml's `operators:` block, and fails (exit 1) on
  a missing op, a stale op, or a name mismatch. It parses only operator tables (by
  their `| op | name | fixity · arity |` header, ignoring worked-example tables)
  and handles the markdown-escaped-pipe `|`-operator row.
- Wired into `ci.yml` (a keyless step next to verify-showcase) and the justfile
  (`just verify-spec-ops`).
- Fixed a name drift the guard immediately caught in my own bd-2e59bb rows: SPEC
  `↦`/`⊘` said map/fold; corrected to `mapop`/`foldop` (the config keys).
- Verified: passes clean (30 operators in sync); fails correctly on a removed op
  row and on a mangled name.

## Diff summary

- Code/content commit: pending final squash SHA from the reintegration receipt.
- Files touched: `scripts/verify-spec-ops.py` (new), `.github/workflows/ci.yml`
  (+1 step), `justfile` (+1 target), `SPEC.md` (mapop/foldop name fix).
- Tests: +1 CI gate (the guard); det suite unchanged (120/120).
- Behavioural delta: CI now fails on SPEC operator-table drift.

## Operator-takeaway

The "SPEC/help/config stay in sync" invariant is now enforced by construction: a
new operator can't land in config without its SPEC row (and a matching name),
because CI fails. This closes the drift class that previously required two manual
fixes (bd-2e59bb, bd-4db4ce). The guard is dependency-free so it runs on the
secretless CI pool, and it earned its keep on day one by catching a name drift in
my own just-landed SPEC work.
