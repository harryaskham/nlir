# Session summary — nlir lexer: `_` echo operator vs `_`-prefixed keys (regression fix)

## Goal

Fix the det-echo regression: my earlier `_`-prefixed-key change (bd-4c3498) made
`lex_bare` consume `_` mid-token, so the configured `_` echo operator could no
longer split `xxx_2` — the whole thing lexed as one `Bare("xxx_2")`. Disambiguate
so BOTH `_sep=` (system key) and `xxx_2` (echo operator) lex correctly.

## Bead(s)

- `bd-ebf385` — Lexer: `_` echo operator can't tokenise (lex_bare consumes `_` mid-token)
- (filed by aur-1 from the eval SPEC-completion batch; blocks SPEC det-echo)

## Before state

- `xxx_2` → `Bare("xxx_2")` (the `_` operator never split it); det-echo blocked.
- Failing tests: none (with `out` unset). 183 unit tests.

## After state

- Failing tests: none. 184 unit tests pass; clippy `-D warnings` clean; `cargo fmt --check` clean.
- Position-aware `_`: a new `prev_is_value` flag (threaded like `after_caret`, preserved across whitespace) marks when the previous token ended a value. A `_` in operand position (start / after an operator / after `;`,`(`,`[`,`,`,`=`) followed by an identifier begins a `_`-prefixed key; a `_` after a value is the configured `_` operator sigil (via `match_operator`). `lex_bare` now accepts only a single LEADING `_` (system-key prefix), not a mid-token continuation, so `xxx_2` splits at `_`.
- `xxx_2` → `[Bare("xxx"), Operator("_"), Bare("2")]`; `a_b` → `a _ b`; `_sep=x` → `[Bare("_sep"), Equals, Bare("x")]` (even with `_` configured); `_cache` → `Bare("_cache")` with no `_` operator.

## Diff summary

- Files touched: `src/lexer.rs` (`prev_is_value` state, split `_` dispatch, `lex_bare` leading-only `_`, test).
- Tests: +1 `underscore_key_vs_echo_operator` (echo-op split, key in operand position, no-op-configured key).
- Behavioural delta: SPEC det-echo (`xxx_2` → "xxx xxx") and det-sep (`_sep=\ `) both lex; unblocks aur-1's det tests: surface.

## Operator-takeaway

The `_` echo-op regression is fixed with nud/led-position tracking in the lexer.
Remaining lexer-lane work (mine): bd-2a1cb6 — carry the `"` vs `'` quote kind on
`Token::Quoted` so aur-1 can wire `Context::interpolate` for `"$name"` in eval.
Then back to the modes/output wiring (run_eval/run_test/-e against `&mut Context`).
