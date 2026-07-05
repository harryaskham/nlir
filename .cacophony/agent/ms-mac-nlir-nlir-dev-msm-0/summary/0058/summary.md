# nlir-wasm P0 follow-up: step_async (bd-9dd22d)

## What
The async, serial counterpart to `eval::step_trace` for the wasm step view (P1 `step()` export / P2 workspace step button). Unblocks aur-1's P2 step view (they were mocking it).

## How (src/eval.rs)
- `pub async fn step_async<R: Realiser>(expr, &Config, &mut Context, mode, &R) -> Result<Vec<String>, EvalError>`: mirrors `step_trace` (the `render_step` reduction trace) but async — drives `step_once_async` in a `while let Step::Reduced` loop, returns each rendered step (reduced nodes as «text»), mapping 1:1 to the JS contract `step(...) -> {steps:[{expr}]}`.
- `Evaluator::step_once_async` + `reduce_async` (async mirrors of `step_once`/`reduce`): `await` the injected realiser only at the all-operands-value effectful `Expr::Apply` (via the existing `eval_apply_async`); pure reductions (reads, literals, assignment write-through) reuse sync `eval`; recursive cases recurse `reduce_async`. Deterministic step never awaits (P2's key-free step path works with a noop/absent realiser).

## Proof
219 lib tests (+1: step_async == step_trace in det mode via NativeRealiser/block_on_ready). clippy -D + fmt clean. Native `step_trace`/`nlir step`/`:step` untouched.

## For P1/P2
`step_async` + `evaluate_async` are the two async entries the wasm crate drives; both generic over `Realiser`, both need a realiser only for llm-mode (det never awaits). P2's step button: call `step_async` (noop realiser for det), render the Vec<String> as the step list.

## Held (separate, gated)
Δ + bare-views grammar still parked as /tmp/nlir-grammar-held.patch (SHA be7b545) — awaiting Harry's greenlight.
