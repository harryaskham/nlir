# Session summary — Make the WASM LLM realiser error legible ("js realiser rejected: {}")

## Goal

Harry hit `llm realisation failed: realisation via operator command: js realiser
rejected: {}` on the latest WASM build. The `{}` made the failure undiagnosable
and the "operator command" wording was misleading for an LLM-endpoint failure.
Surface the real underlying error and label it correctly so the true cause
(endpoint status / CORS / model-id) is visible.

## Bead(s)

- `bd-1ec624` — wasm llm realiser errors collapse to "{}" and mislabel as
  "operator command" — surface the real JS error (P1 bug, nlir-wasm/llm)

## Before state

- `llm realisation failed: realisation via operator command: js realiser
  rejected: {}` — opaque.
- Root cause 1: `crates/nlir-wasm/src/lib.rs::js_err_string` fell back to
  `JSON.stringify(error)`, which returns `"{}"` for any JS `Error` because
  `name`/`message`/`stack` are non-enumerable own properties. The workspace
  `llm` realiser throws real messages (`new Error('llm endpoint 401')`; a failed
  `fetch` throws `TypeError: Failed to fetch`) — all collapsed to `"{}"`.
- Root cause 2: the wasm `realise_err` wrapped every realiser failure (incl. the
  `llm` path) as `RealiseError::OperatorCommand` → "realisation via operator
  command: …", confusing for an endpoint failure.
- Tests: 240 lib tests green pre-change.

## After state

- `js_err_string` now: (1) uses a thrown string as-is; (2) reads a JS `Error`'s
  `name`/`message` via `dyn_ref::<js_sys::Error>()` → "Error: llm endpoint 401",
  "TypeError: Failed to fetch"; (3) reads `.message` off non-`Error` error-likes
  (DOMException); (4) JSON.stringify only for plain data objects, ignoring an
  empty `"{}"`/`"null"`; else "unknown JS error".
- New `RealiseError::Realiser(String)` variant → "realisation via realiser: …";
  the wasm `realise_err` uses it, so llm failures no longer say "operator
  command".
- Net: Harry's message now renders e.g. "…realisation via realiser: js realiser
  rejected: Error: llm endpoint 401" — actionable. The rejection itself is
  environmental (endpoint/key/CORS/model-id), now diagnosable.
- Tests: 240 lib tests green; native clippy -D warnings clean; nlir-wasm
  `cargo check` + `clippy` for `wasm32-unknown-unknown` clean.

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Summary artefact commit: intentionally omitted (no self-reference).
- Files touched:
  - `crates/nlir-wasm/src/lib.rs` — rewrite `js_err_string` (Error name/message
    extraction); `realise_err` now builds `RealiseError::Realiser`.
  - `src/llm.rs` — add `RealiseError::Realiser(String)` variant + its `Display`
    ("realisation via realiser: …") and `Error::source` (None) arms.
- Tests: +0 / -0 (the fix is a wasm-boundary error formatter — inherently JS-
  coupled; validated via native + wasm32 typecheck/clippy and the 240-test lib
  suite; full .wasm bundle build is CI wasm.yml).
- Behavioural delta: WASM llm-mode realiser failures now show the real JS error
  and a correct "realisation via realiser" prefix instead of an opaque
  "operator command: … {}".

## Operator-takeaway

The WASM LLM playground error was a diagnostics bug, not a routing bug: the real
endpoint error (401 / Failed to fetch / bad model-id) was being swallowed into
`{}` because `JSON.stringify` can't see a JS `Error`'s non-enumerable `message`.
It now surfaces the true cause, so when llm mode still fails, the message tells
you whether it's auth, CORS/network, or model-id. The remaining failure itself
is environmental (your endpoint/key/model), not an nlir bug — the fix makes that
visible. The full .wasm bundle rebuilds via CI + the P7 pages deploy, so allow a
minute after land for a.skh.am/nlir/workspace to pick it up.
