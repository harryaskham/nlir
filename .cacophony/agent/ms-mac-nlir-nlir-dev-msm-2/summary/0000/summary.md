# Session summary — nlir tui workbench, slice 1 (bd-ae1730)

## Goal

bd-ae1730 originally asked for a ratatui REPL line editor, but msm-3 landed
equivalent line editing via rustyline (bd-9d2d46) mid-session. Per Harry's
reconciliation (choice-019f3285), the bead was repurposed: keep rustyline as the
lean one-off REPL, and turn this bead into a full-screen `nlir tui` **workbench**
— a session browser + context viewer + live deterministic expression eval, the
terminal sibling of the browser workspace. Slice 1 lands that workbench skeleton,
sharing the REPL's on-disk session pool so both surfaces see each other's work.

## Bead(s)

- `bd-ae1730` — nlir tui — full-screen workbench (session browser + context manager + live expression eval) (P1)
  - superseded-for-REPL-scope by `bd-9d2d46` (rustyline), then repurposed to the TUI workbench.

## Before state

- `nlir` had no `tui` subcommand; the interactive surface was `nlir repl`
  (rustyline line editor + the shared session pool: `sessions_dir`/`list_sessions`/
  `restore_session`/`archive_session`/`session_summary`, owned by aur-0).
- Failing tests: none. Bin tests: 3 cli_tests.

## After state

- New `nlir tui` full-screen workbench (ratatui, alternate screen):
  - **Sessions pane** — browses the shared pool (`list_sessions` + `session_summary`);
    Enter restores the selected session into the active context.
  - **Context pane** — lists the current context: a synthetic `_messages` count
    plus each non-system key with a one-line rendered-value preview.
  - **Expression pane** — a full line editor (the pure `LineEditor`: arrow/word
    motion, Ctrl-A/E/K/U/W, Up/Down history); Enter evaluates in deterministic
    `Mode::Det` (instant, offline, no key) and shows the result in the Output
    pane (errors in red). `key=RHS` writes persist and refresh the Context pane.
  - Tab / Shift-Tab cycle panes; Esc / Ctrl-D(empty) / Ctrl-C(empty) quit;
    Ctrl-C on a non-empty expr clears the line (shell-style). On exit the TUI
    archives the context into the SAME `sessions/` pool, so `nlir repl`
    `:resume`/`--continue` and the workbench are mutually resumable.
- Editing/navigation logic is a pure, side-effect-free `Workbench` + `LineEditor`
  (unit tested); ratatui only renders and the eval/session IO lives in `main.rs`.
- Failing tests: none. Bin tests: 24 (3 cli_tests + 14 line_editor + 7 tui).

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files: `src/tui.rs` (new — Workbench state + ratatui render + 7 tests),
  `src/line_editor.rs` (new — pure line editor + 14 tests, reused from the
  original ratatui exploration), `src/main.rs` (`tui` subcommand + run_tui event
  loop + eval/session-pool wiring; `mod line_editor` / `mod tui`),
  `Cargo.toml`/`Cargo.lock` (+`ratatui` 0.29, optional, `native` feature; reuses
  the crossterm already in the tree, no second backend, wasm build untouched).
- Tests: +21 (14 LineEditor + 7 Workbench). Behavioural delta: new `nlir tui`
  surface; REPL and everything else unchanged. rustyline REPL left fully intact.
- Validation: full `cargo test` (24 bin + lib), `cargo clippy --all-targets
  -D warnings`, `cargo fmt --check`; and a real-pty smoke driving `nlir tui`
  (sized winsize + DSR-answered) confirming all four panes render, a det-mode
  eval shows its result, Tab cycles panes, and Ctrl-C tears down cleanly.

## Embedded artefacts

- None this slice (a terminal.cast of the workbench is a good slice-2 add).

## Operator-takeaway

`nlir tui` is now a real terminal workbench: browse saved sessions, inspect the
live context, and evaluate expressions with instant deterministic output — and it
shares the exact session pool as `nlir repl`, so work flows between the two. This
is slice 1 (skeleton); natural next slices are in-pane context editing, session
delete/prune (aur-0 offered `delete_session`/`prune_sessions`), multiline + live
keystroke preview, and an opt-in llm-mode eval. The editing core is a pure,
unit-tested `LineEditor`/`Workbench`, so future panes build on tested logic
rather than terminal-coupled code.
