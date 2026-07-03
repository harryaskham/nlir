# Session summary — nlir: double-quote `"$name"` interpolation (quote-kind through lexer→parser→eval)

## Goal

Wire SPEC double-quote interpolation: `"…$name…"` interpolates bare `$name` at
eval time; raw `'…'` and bare literals do not. Requires the lexer to carry the
quote kind through the parser so eval knows which quoted nodes interpolate.

## Bead(s)

- `bd-2a1cb6` — Wire double-quote $name interpolation into eval (lexer must carry the quote kind)
- (cross-lane: lexer/parser mine, eval arm coordinated with aur-1 — done atomically to avoid a half-broken two-land state)

## Before state

- `Token::Quoted(String)` / `Expr::Quoted(String)` collapsed `"…"` and `'…'`; eval never interpolated, so `"v is $k"` yielded the literal `v is $k`.
- Failing tests: none. 186 unit tests.

## After state

- Failing tests: none. 191 unit tests pass; clippy `-D warnings` clean; `cargo fmt --check` clean. Verified end-to-end.
- `Token::Quoted { content, interpolate }` and `Expr::Quoted { content, interpolate }` carry the quote kind: `interpolate: true` for `"…"` (lex_escaped_quote), `false` for raw `'…'` (lex_raw_quote). The eval arm (per aur-1's spec) calls `self.context.interpolate(content)` when `interpolate`, else uses the content verbatim.
- `nlir -e 'k=world;"hello $k"'` → "hello world"; `'…'` raw → "hello $k"; unknown `$k` left literal.

## Diff summary

- Files touched: `src/lexer.rs` (Token variant + render/prev_is_value/lex_raw/lex_escaped + 5 tests), `src/parser.rs` (Expr variant + render/starts_expr/nud), `src/eval.rs` (Quoted arm calls Context::interpolate).
- Behavioural delta: SPEC greedy eval-time `"$name"` interpolation now works; raw quotes stay literal.

## Operator-takeaway

Double-quote interpolation is live end-to-end. This was a clean cross-lane
atomic land: I carried the quote kind through Token/Expr and dropped in aur-1's
eval arm in the same commit. Remaining modes/output beads (mine): `--quiet`
(bd-d52b78, core in place) and `--dry-run` (bd-e432fc). aur-1 is wiring the
Mode::Llm realisation arm (pending aur-2's llm helper); aur-2 on types/CI.
