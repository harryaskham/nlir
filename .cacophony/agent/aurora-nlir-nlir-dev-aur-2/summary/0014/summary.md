# Session summary — ship example config + first-run scaffolding (bd-8523df)

## Goal

Make nlir usable out of the box: ship a complete working `config.yaml` (the whole
language lives in config, so an empty install can't do anything) and write it to
`~/.config/nlir/config.yaml` automatically on first run.

## Bead(s)

- `bd-8523df` — Docs: ship example/default config + first-run scaffolding; parent
  docs epic `bd-285b4e`

## Before state

- Failing tests: none. No shippable config existed; `config::load(None)` returned
  builtins-only `Config::default()` (no operators), so a fresh install could not
  evaluate anything.

## After state

- Failing tests: none. Full CI gate green (fmt, clippy `-D warnings`, test).
- `config.example.yaml` (the full SPEC example) is embedded and scaffolded on
  first run; verified end-to-end (first run writes + notes the path, second run
  preserves the existing config).

## Diff summary

- Code/content commit: `a0a8c8f` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `config.example.yaml` (new), `src/config.rs`
  (`EXAMPLE_CONFIG` + `scaffold_default_config` + `scaffold_config_at` + 2 tests),
  `src/main.rs` (best-effort scaffold call at the `run()` preamble).
- Tests: +2 (the shipped example parses **and** validates — a permanent
  schema-drift guard; scaffold writes-when-missing / preserves-existing).
- Behavioural delta: first run of any command writes the starter config if none
  exists (noting the path on stderr); existing configs are never overwritten.

## Operator-takeaway

The most durable win is the `example_config_parses_and_validates` test: the
shipped `config.example.yaml` is now checked against the real serde schema +
semantic validator on every CI run, so it can never silently drift out of sync
with the config types (the classic "the example in the docs no longer parses"
rot). Scaffolding lives at the `run()` preamble and is best-effort/idempotent —
it never overwrites a user's config and a write failure never blocks the command,
so it's safe even for `nlir mcp stdio`. Coordinated the ~3-line main.rs touch with
msm-0 (who owns the CLI) to avoid a `run()` collision.
