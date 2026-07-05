# nlir-wasm P0: the realiser seam (bd-bec201) — THE KEYSTONE

## What
Abstract the EFFECTFUL half of realisation behind an injectable async trait so ONE evaluator serves both the native CLI and the browser (WASM). Native behaviour + all tests unchanged. Unblocks the whole nlir-wasm epic (bd-360d0c).

## How
- llm.rs: split `realise_llm` -> pure `assemble_llm(...) -> LlmCall{model,vars,operands}` + effectful `run_llm(&LlmCall)`; `realise_llm` now a thin wrapper (identical). Unified operator `command:` bash into `run_operator_command` (+ `RealiseError::OperatorCommand`).
- realiser.rs (new): `trait Realiser { llm(&LlmCall)->RealiseFuture; command(&str,&[String])->RealiseFuture }` (the only new surface P1 wires JS into). `NativeRealiser` (native-gated) wraps run_llm/run_operator_command; `block_on_ready` (std Waker::noop, no executor dep).
- eval.rs: `pub async fn evaluate_async<R: Realiser>` — serial async counterpart to `evaluate`; awaits the injected realiser at the two effectful sites (`realise_async` + `coerce_operand_async`), pure leaves reuse sync `eval`. Native `evaluate` + thread::scope untouched (seam at realisation, not scheduling; aur-0's serial scheduler @352ca58 covers that half).

## Proof
217 lib tests (+3: block_on_ready, NativeRealiser.command, evaluate_async==sync det + async llm-coercion->10). clippy -D + fmt clean. det 18/18. Native identical.

## For P1/P2
Frozen seam: `Realiser` trait + `evaluate_async<R>` + `assemble_llm`/`LlmCall`. WASM cfg: native backends (process::Command+HTTP, under NativeRealiser + sync evaluate) need `#[cfg(not(wasm32))]`; evaluate_async + assemble_llm + det realise are cross-platform. Follow-ups: async realise cache, `step_async`, wasm env-lookup injection.

## Held (separate, gated)
Δ + bare-views grammar parked as /tmp/nlir-grammar-held.patch (SHA be7b545) — awaiting Harry's greenlight; orthogonal to P0.
