# Session summary — nlir project skeleton (Nix flake + Rust CLI + template stack)

## Goal

Stand up the foundational scaffolding for the brand-new `nlir` project so every
downstream bead has somewhere to land. `nlir` transpiles a terse, sigil-laden
shorthand IR into fluent English (see `SPEC.md`). This session creates the Nix
flake, the Rust `nlir` binary + library crate with the full SPEC §CLI-surface
command tree, and wires the three harryaskham template crates (mcp-cli,
updatable-cli, feedback-cli) so later beads only fill in engine behaviour.

## Bead(s)

- `bd-57ad92` — Project skeleton: Nix flake + Rust `nlir` CLI with crate deps wired (foundation/skeleton, P1)

## Before state

- Repo contained only `SPEC.md`, `README.md`, `.gitignore` (no build system, no code).
- Failing tests: none (no crate yet).
- No `nlir` binary; nothing on the queue depended on a compilable tree.

## After state

- Failing tests: none. `cargo test --lib` = 6/6 pass; `cargo clippy --all-targets -- -D warnings` clean; `cargo fmt --all --check` clean (all run in the nix dev shell).
- `nlir --help` lists the full command tree; `nlir -e 'a&b&c' --quiet` → `a&b&c` (skeleton identity passthrough); `nlir parse 'one two'` emits a token preview; `nlir mcp tools` exposes `status, eval, parse, self_update_status, self_update_check, self_update_run, feedback_report, feedback_status`.
- Debug binary installed to `~/.local/bin/nlir` for Harry's testing (per operator request; final install will be via Nix).
- `nix build`/`nix flake check` deferred per operator: the flake is written and locked, but the sandboxed rustPlatform build is slow; cargo build in the dev shell is the verified path for now.

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files touched: `Cargo.toml`, `Cargo.lock`, `flake.nix`, `flake.lock`, `.envrc`, `.gitignore`, `rustfmt.toml`, `src/lib.rs`, `src/main.rs`, `test/integration.sh`, `scripts/preflight.sh`.
- Structure mirrors `omni-cli` (primary reference): a lib crate holding the shared typed command contracts + the mcp-cli `ToolRouter`, and a thin clap `main.rs`.
- Template stack: `updatable_cli::register_update_tool` + `feedback_cli::register_feedback_tools` on the MCP router; `nlir self-update` (updatable-cli) and `nlir feedback` (feedback-cli) CLI subcommands; `maybe_apply_staged_update` at process entry.
- Global flags from SPEC (`--config`, `--context-file`, `--session-file`, `--mode`, `--model`, `--parallelism`, `--quiet`, `--dry-run`) + `-e/--expr`; subcommands `parse`, `test`, `repl`, `set`, `get`, `append-message`, `mcp stdio|tools`, `self-update`, `feedback`.
- Domain surfaces (`eval`, `parse`, `test`, `repl`, `set`, `get`, `append-message`) are intentionally thin stubs flagged `stub: true` / "skeleton (bd-57ad92)"; the tokeniser, DAG parser, stack machine, type/coercion system, and realisation layers are downstream beads.
- nixpkgs pinned to the SAME rev as `~/collective/flake.lock` (flakehub pinned tarball rev `0590cd39`, narHash `sha256-BHoB/...`) so the toolchain is reused from the store — no fresh nixpkgs pull.
- Tests: +6 (`status`, `eval` identity stub, `parse` split stub, `Mode` serialisation, router tool presence, updater config).

## Operator-takeaway

The skeleton compiles, lints, tests, and runs, with the mcp/self-update/feedback
stack fully wired — downstream engine beads (tokeniser → parser → stack machine →
types/coercion → deterministic/LLM realisation, plus config loading, context
read/write, REPL, and the config-defined test runner) can now be built and
parallelised independently against this tree. macOS libiconv comes from the nix
dev shell (like tendril/cacophony), so build via `nix develop --command cargo build`;
the raw system `cargo build` fails only at the `-liconv` link step.
