# REPL step-through engine + `nlir step` (bd-9c366d, Harry ask #1 of 2)

## What
Small-step "step-through" evaluation so you can watch an nlir expression unfold one redex at a time and learn the language. Engine + non-interactive `nlir step` CLI; aur-0 builds the interactive REPL Tab UX against this seam.

## How
- `Expr::Value(Value)` — a reduced value spliced back into the AST (parser.rs; parser never emits it, only the stepper does). Handled in eval + the two parallel-eval matches; renders as «text».
- `Evaluator::step_once(&Expr) -> Step{Reduced(Expr),Done(Value)}` (eval.rs) — leftmost-innermost redex: recurse to the first non-value child, reduce it; once all children are values, evaluate this node → `Expr::Value`. Literals are already values (no wasted step); reads (`$`/`^`), interpolating quotes, and ops each take a step. Deterministic ops reduce instantly; each LLM op is one realisation per step (carries the run stack + realise cache across steps).
- `eval::step_trace(expr, cfg, ctx, mode) -> Vec<String>` — non-interactive all-steps helper; keyless CI hook.
- `Expr::render_step()` — reader-friendly render (strips the redundant outer parens of the AST dump; inner structure kept).
- `nlir step 'EXPR'` subcommand (main.rs).

## Proof
- det `2+3*4` → `2 + (3 * 4)` → `2 + «12»` → `«14»`; `!'raining' & 'cold'` → `(! raining) & cold` → `«not raining» & cold` → `«not raining and cold»`.
- llm `~[@'a', @'b']` unfolds one realise/step → `«summary»`.
- 215 lib tests green (2 new step tests: innermost-first + literal-is-one-step).

## Notes
- Landed INDEPENDENTLY of the held Δ+bare-views grammar (step engine is orthogonal); grammar stays held for Harry's greenlight. `^*` shorthand in step demos needs bare-views (use `0^*-1` until it lands).
- Follow-up: aur-0's crossterm raw-mode `:step` REPL (Tab=next · Enter=run · q/Esc=cancel · TTY-gated) against `Evaluator::step_once`.
