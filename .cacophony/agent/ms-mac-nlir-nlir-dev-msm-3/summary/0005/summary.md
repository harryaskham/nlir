# Session summary — REPL live det-preview (bd-970e05 REPL slice)

## Goal

Harry's cross-surface "live partial result display" feature (bd-970e05): show the
result-so-far as you compose an nlir expression. My assigned slice is the REPL
(rustyline). msm-2 had landed the TUI + Pi-plugin slices with a shared contract
(debounce, det=safe-free-default, speculative≠committed, non-persisting).

## What landed

- `src/main.rs`: a rustyline `ReplHelper` (Hinter/Highlighter/Completer/Validator)
  attached to `nlir repl`. As you type, it shows the current line's DETERMINISTIC
  result-so-far as a dim ` → <result>` hint after the cursor.
  - **Side-effect-free**: evaluates a CLONE of the context in `Mode::Det` and
    never saves (speculative, non-persisting per msm-2's contract).
  - **Command-op guard (the key safety call)**: because the hint fires
    synchronously per keystroke (no debounce, unlike the TUI), it SKIPS any
    expression that uses a shell-`command:` operator (e.g. `_` echo) — det eval
    would shell out. Command sigils are collected from config
    (`op.command.is_some()`); a conservative substring check suppresses those
    previews. So typing never triggers a side effect.
  - **Unobtrusive guards**: empty / `:meta` / over-long (>160) lines and any
    parse/eval error (incl. an llm op in det mode) show no hint, so a mid-edit
    line doesn't flicker. Only shown when the cursor is at end of line.
  - **Context refresh**: after each submission (`k=v`, `:set`, `:new`/`:resume`)
    the helper's context snapshot is refreshed so later previews reflect writes.
  - Graceful: if config/context can't load, plain line-editing still works; the
    `DefaultEditor` fallback to `run_repl_plain` is preserved.

## Verification

- Preflight green: `cargo fmt --all --check`, `cargo clippy --all-targets -D
  warnings`, `cargo test --lib` (269) + `--bin nlir` (34, incl. the new test).
- New regression test `repl_preview_hints_pure_det_and_skips_command_ops`:
  pure det (`2*21`→`  → 42`, `1+2+3`→`  → 6`), command-op skipped (`'hi'_2`→None),
  and meta/blank/parse-error → None.
- Real-TTY tmux run of `nlir repl`: `2*21`→` → 42`; the flagship
  `$fold%({$0+$1},$map%({$0*$0},[1,2,3]))`→` → 14`; `$map%({$0*$0},[1,2,3])`→
  ` → 1 4 9`; `'hi'_2` (command) → no hint; `#'draft'` (llm in det) → no hint.

## Operator-takeaway

`nlir repl` now previews the deterministic result as you type — you see `2*21`
become 42, or a fold∘map program become its number, before pressing Enter. It's
purely speculative (never persists, never runs shell-command ops), so it's safe
to leave on. This completes the REPL leg of Harry's live-preview feature
(bd-970e05 stays open as the cross-surface tracker; llm-tier preview waits on
msm-0's incremental cache). Consistent dim ` → …` styling with the TUS/Pi slices.
