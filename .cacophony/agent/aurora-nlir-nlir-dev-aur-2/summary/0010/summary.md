# Session summary — LLM coercion fallback (bd-ecb930)

## Goal

Close the loop on the types vertical: when deterministic coercion cannot produce
the target type, fall back to the configured per-type LLM coercion — resolve the
`types:` model + prompt, call the model, and parse its `{result: T}` answer back
into a typed value. This is the piece that turns vague text (e.g. "ten to
twenty") into a real number/bool, and it composes every LLM-pipeline function
landed earlier this session.

## Bead(s)

- `bd-ecb930` — Types: LLM coercion fallback
- parent: `bd-957ff4` — Types epic (label `types`)
- composes: resolve_model, substitute_operands, resolve_prompt_fragments,
  assemble_nlir_vars, the command + anthropic backends, extract_result, and
  Value::coerce_deterministic

## Before state

- Failing tests: none. Deterministic coercion + loud errors existed; both LLM
  backends + the full prompt pipeline existed; but nothing wired them into a
  coercion fallback.
- 152 lib tests green.

## After state

- Failing tests: none. 158 lib tests green (`cargo test --lib`), fmt/clippy clean.
- `llm::coerce_with_llm(value, target, config, sep, env_lookup, cli_model)
  -> Result<Value, LlmCoerceError>` is the `llm`-mode coercion entry point.

## Diff summary

- Code/content commit: `d7e0817` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `src/llm.rs` only (coercer + dispatch + LlmCoerceError + 6 tests;
  imports `Value`/`CoerceError`/`TypeName`/`ModelKind`).
- Tests: +6 (deterministic short-circuit skips the LLM; `list → number` errors
  without an LLM call; command-backend text + json coercion; unparseable result
  errors; missing `types:` config errors).
- Behavioural delta: `llm`-mode coercion now works end to end — deterministic
  first, then the per-type LLM coercion via the resolved backend, with the result
  re-parsed into the target type; `det` mode still uses `Value::coerce`.

## Operator-takeaway

The full round-trip is the interesting part: the LLM is asked for a `{result: T}`
but its answer comes back as text through `extract_result`, so `coerce_with_llm`
runs that text through `coerce_deterministic` once more to land a *typed*
`Value` — a model that returns "5" for a number coercion yields `Number(5)`, and
one that returns junk yields a loud `UnparseableResult` rather than a silently
wrong value. This completes the types/coercion epic bd-957ff4 (value model →
deterministic → loud errors → LLM fallback) and the LLM realisation pipeline;
only the P3 coercion-cache (`_cache`, bd-876367) remains in the types lane. The
evaluator (aur-1/msm-0) can now coerce operands in both modes.
