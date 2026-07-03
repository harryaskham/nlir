# Session summary — evaluator core: operand-first walk + realisation resolution + coercion

## Goal

Stand up the nlir evaluator — the operand-first walk over a parsed program that
turns an expression into a typed value, tying together everything landed so far
(lexer, parser AST, value model + coercion, and my context store / stack /
message-indexing / deterministic realisations). This is the integration linchpin:
with it, `EXPR → tokenise → parse → evaluate → English` works end-to-end for the
deterministic path.

## Bead(s)

- `bd-168ef8` — Eval: DAG evaluator (operand-first)
- `bd-d58371` — Eval: realisation resolution + mode
- `bd-dd7b5e` — Eval: operand type coercion before apply
- (parent epic: `bd-2b226d` — evaluator)

## Before state

- Failing tests: none (main green, 142 lib tests).
- No evaluator existed; `lib.rs eval()` was a bd-57ad92 identity stub. The parser
  produced a `Program` of `Expr` ASTs and all the leaf layers (value/coercion,
  context/stack/messages, reduce/template/join realisations) were landed but
  nothing composed them.

## After state

- Failing tests: none; 152 lib tests (+10).
- New `src/eval.rs` (registered in `src/lib.rs`):
  - `evaluate(expr, config, context, mode)` — full pipeline; `Evaluator` +
    `Evaluator::run(program)`.
  - Operand-first eval of every `Expr` node: atoms, `$name` context reads
    (JSON→Value), `$`/`$N` stack, `^` message index (via `MessageIndex`), groups,
    lists, serial marker, and operator `Apply`.
  - `Apply`: operand-first eval → coerce each operand to the operator's operand
    type (bd-dd7b5e) → realisation resolution (bd-d58371): `command`/`reduce`
    always det; `det` mode → `template`/`join`; `llm` mode → model+prompt.
  - Grouping `(…)` preserved in string output (SPEC: parens always win) while
    numeric groups keep their number.
- `cargo fmt --check` clean; `cargo clippy --all-targets` clean for `eval.rs`
  (one pre-existing `config.rs` warning is not in scope).

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files touched: `src/eval.rs` (new), `src/lib.rs` (+`pub mod eval;`).
- Tests: +10, incl. the SPEC det cases end-to-end — det-not (`!foo`→"not foo"),
  det-and (`a&b&c`), det-group (`!(a&b)`→"not (a and b)"), det-quote, num-add
  (`1+2+3`→"6"), num-index (`(1+1)**3`→"8"), msg (`^-1`, `#^-1`), `;` push/result,
  context read + missing-key error, div-by-zero, llm-unsupported.
- Behavioural delta: nlir now evaluates deterministic programs end-to-end.
  Deferred (own beads / clearly errored): `command:` realisation (bd-3c1e6d), the
  LLM realisation path, nullary-pop (bd-9aac32), list spread (bd-02a795), and
  `key=RHS` assignment (bd-c85dee, awaiting msm-0's parser `Assign` node).

## Embedded artefacts

- None this session.

## Operator-takeaway

The evaluator is the convergence point and it works for the whole deterministic
SPEC test surface. The remaining eval beads are additive leaves that slot into the
`Apply` realisation dispatch (`command`), the message/stack paths (nullary-pop),
or the coercion layer. msm-0 is wiring `nlir -e`/`test`/`repl` to `eval::evaluate`
in the CLI-surface epic and adding the parser `Assign` node that unblocks my
`key=RHS` context-write bead. Once assignment + `command:` land, det-echo,
det-assign, and det-sep close out the SPEC `tests:` block.
