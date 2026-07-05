# Design: `nlir-wasm` — the in-browser evaluator + interactive workspace

**Status:** proposed · **Owner:** aur-1 (site/learnability) + cross-lane · **Epic:** bd (filed with this doc)

> Goal: a first-party, native-feeling **in-browser nlir** that *is* the real
> evaluator (compiled to WASM from the same `src/`), with a live REPL/workspace
> and a hero-widget on the site — so anyone can type an expression, watch it
> unfold step by step, edit the config/context, and run it, with everything
> persistent in their browser. It must **co-build** with the evaluator so it can
> never drift from the shipped behaviour.

---

## 1. Motivation

The site now looks native (the design pass). The next leap in "learnable,
playable" is to let visitors *run* nlir in the page — not a mock, the actual
evaluator. A `@'lmk if any Qs'` → English demo that a reader can edit and re-run,
a `nlir step`-style expansion they can watch live, a config they can tweak, a
context they can populate — all client-side, zero-install, private.

## 2. Goals / non-goals

**Goals**
- The WASM evaluator is the **same code** as the native binary (co-built), so
  parse/precedence/deterministic realisation/step semantics match exactly.
- A **workspace**: expression input, output, and step-through; a config editor
  seeded from `config.example.yaml`; a context/messages/KV manager. All
  **localStorage-persistent** so a session survives reloads.
- A **hero-widget**: a slim embed at the top of `index.html` with a keystone
  example prefilled and runnable.
- **In-browser LLM auth**: user supplies an OpenAI-compatible base URL + key, OR
  uses an **on-device** model (Chrome `window.ai` / WebLLM Gemma) for zero-key,
  zero-egress realisation.
- **`command:` operators** run via a warm, sandboxed wasm shell.
- Beautiful, in the card aesthetic; feels 1p and native.

**Non-goals (phase 1)**
- No server component (fully static site + client WASM).
- Not a CLI replacement; the binary remains canonical.
- Multi-thread WASM (SharedArrayBuffer) is out of scope — the widget evaluates
  serially/async (fine for interactive use).

## 3. Architecture

```
┌──────────────────────────── browser ────────────────────────────┐
│  Workspace widget (HTML/CSS/JS, card aesthetic)                   │
│   expr input · output · step view · config editor · context/KV   │
│   settings (LLM base-url/key | on-device) · localStorage store    │
│        │  calls                                   ▲ renders        │
│        ▼                                          │                │
│  nlir-wasm (wasm-bindgen)  ── evaluate/step/parse/operators ──────│
│        │   needs LLM + command realisation (async)                │
│        ▼  (injected JS realiser callbacks)                        │
│   ┌─ LLM realiser: fetch(base-url) | window.ai | WebLLM Gemma     │
│   └─ Command realiser: warm wasm-sh worker (busybox-style)        │
└───────────────────────────────────────────────────────────────────┘
        ▲ co-built from the SAME src/ on every push (CI)
        │
   nlir library (src/) — lexer · parser · eval · realise · config · …
```

### 3.1 The realiser seam (the central refactor)

Today `eval::realise_op` dispatches:
- **deterministic** (`reduce:`/`template:`/`join:`) → `realise.rs`, pure, **already WASM-safe**;
- **effectful** (`llm` model backend `prompt:`, and `command:`) → `llm::realise_llm`
  (HTTP backend / `bash` subprocess).

We abstract the effectful path behind a trait so the host supplies it:

```rust
// nlir::realise (new)
pub trait Realiser {
    // Realise an llm-mode operator: prompt already assembled from operands.
    fn llm(&self, model: &ModelConfig, prompt: &str) -> BoxFuture<Result<String, RealiseError>>;
    // Realise a command: operator: run the shell snippet with NLIR_ARGS.
    fn command(&self, command: &str, args: &[String]) -> BoxFuture<Result<String, RealiseError>>;
}
```

- **Native** impl = the existing `llm.rs` HTTP backend + `bash` subprocess (behind
  a thin blocking→future shim; unchanged behaviour).
- **WASM** impl = JS callbacks: `llm` → `fetch(base_url)` (or on-device);
  `command` → the warm wasm-sh worker.

The eval core calls `realiser.llm(...)` / `.command(...)` instead of `llm::` directly.
This is the seam that lets one evaluator serve both the CLI and the browser.

### 3.2 Async & scheduling in WASM

Browser I/O (`fetch`, worker messaging) is **async**; WASM has **no threads** here.
So:
- `nlir-wasm` exposes `evaluate(...)`/`step(...)` as **async** (returns a JS
  `Promise`), driven by `wasm-bindgen-futures`.
- The DAG scheduler runs **serially** (or with async concurrency via
  `futures::join_all`) instead of `thread::scope`. Node caching/dedup is preserved.
- The native path keeps its `thread::scope` parallelism unchanged (the seam is at
  realisation, not scheduling).

### 3.3 `nlir-wasm` crate

A new crate (`crates/nlir-wasm` or a `wasm` feature) depending on the nlir lib:
- `#[wasm_bindgen]` exports: `evaluate(expr, config_yaml, context_json, mode) → Promise<Result>`,
  `step(expr, …) → Promise<Step[]>` (mirrors `nlir step`), `parse(expr) → Ast`,
  `operators(config_yaml) → Op[]` (the `nlir help` data for a live grammar panel),
  `version() → {crate, git}` (the co-build stamp).
- Accepts JS realiser callbacks (LLM + command) wired through the `Realiser` trait.
- Built with `wasm-pack build --target web`.

### 3.4 The workspace widget (site, aur-1 lane)

A self-contained component (`site/workspace/`), styled in the card aesthetic:
- **Expr bar** — input + Run + Step. Output area shows the realised English; Step
  shows expr → each reduction inline (the learnability payoff).
- **Config editor** — editable YAML (seeded from `config.example.yaml`), validated
  live via `operators()`/parse; "reset to default" re-injects the shipped config.
- **Context/messages/KV** — add user/assistant/system messages (feeds `^`/`^_`/`^*`),
  set `$name` KV values; drives message-reading idioms live.
- **Settings** — LLM base-url + key, or an "on-device" toggle; mode (det/llm).
- **Persistence** — one `localStorage` document `{config, context, kv, settings}`;
  survives reloads. (Keys never leave the browser except to the user's endpoint.)

### 3.5 Hero-widget

A slim embed at the top of `index.html`: a keystone example prefilled
(e.g. `@~'…the mobile team is blocked on us…'` → an exec summary, or a reply
idiom), with Run + Step. In `det` mode it runs with **zero setup**; llm examples
prompt for a key or on-device once. Replaces the static hero demo with a live one.

### 3.6 LLM auth in-browser

- **BYO endpoint**: base-url + key textboxes → the WASM LLM realiser does
  `fetch(base_url + '/chat/completions', {Authorization: key, …})`
  (OpenAI/LiteLLM-compatible). Stored in localStorage; sent only to that endpoint.
- **On-device (zero-key, zero-egress)**: detect Chrome `window.ai` (built-in
  Gemini Nano) or load a small model via **WebLLM**/**transformers.js** (Gemma).
  Ideal for the hero (no setup, private). Slower/lower-quality — surfaced honestly.
- **det mode needs neither** — the numeric/template/join/`_` ops + the whole
  algebra of precedence/parsing run offline, so a lot is playable key-free.

### 3.7 Command VM (`command:` operators)

`command:` ops (e.g. `_` echo's bash snippet) run shell. In-browser: a **warm,
sandboxed wasm shell** (busybox-style / a minimal POSIX `sh` in WASM, e.g. a
`wasi` build) kept alive in a Worker for low latency, invoked with `NLIR_ARGS`.
Phased — det+llm ops ship first; the command-VM follows so `_` and custom command
ops work too.

### 3.8 Co-build & sync (the anti-drift guarantee)

- CI (a `wasm` job, or extend `pages.yml`) runs `wasm-pack build` from the **same
  commit** as the native binary on every push, emitting `pkg/` into the site.
- `nlir-wasm::version()` embeds the crate version + git sha; the widget shows it.
  Site build fails if the WASM commit ≠ the site commit.
- Result: the in-page evaluator is byte-for-byte the shipped evaluator.

## 4. Security

- API keys live only in `localStorage`; requests go **only** to the user's chosen
  base-url. Never proxied through us (static site).
- On-device path is fully offline (zero egress).
- The command-VM is a sandboxed WASM shell (no host FS/network); it only sees
  `NLIR_ARGS`.

## 5. Milestones / phasing

| P | deliverable | lane |
|---|---|---|
| P0 | **realiser seam** — trait + native impl (behaviour-unchanged) + async eval path | eval |
| P1 | **`nlir-wasm` crate** — wasm-bindgen exports (evaluate/step/parse/operators/version), det-mode working | wasm/build |
| P2 | **workspace widget** — expr/output/step + config editor + context/KV + localStorage, det-mode live | site (aur-1) |
| P3 | **LLM realiser** — BYO base-url/key fetch; llm-mode live | js/llm |
| P4 | **hero-widget** — keystone example live at top of index.html | site (aur-1) |
| P5 | **on-device LLM** — window.ai / WebLLM Gemma realiser | js/llm |
| P6 | **command-VM** — warm wasm-sh worker for `command:` ops | wasm/commands |
| P7 | **CI co-build + version stamp** — wasm built from same src every push, embedded | ci (aur-2) |

P0→P2 already gives a genuinely useful key-free det-mode playground + hero. LLM +
on-device + commands layer on without reworking the seam.

## 6. Open questions

- WASM binary size (the lib + serde + yaml) — measure; `wasm-opt`/feature-trim if heavy.
- `serde_yaml` in WASM (config editor parses YAML) — confirm it compiles to wasm32; else a JS YAML parse → JSON bridge.
- On-device model availability is browser-gated (Chrome flags) — treat as progressive enhancement, det + BYO-key as the baseline.
- Which wasm-sh for the command-VM (size vs coverage) — spike in P6.

## 7. Bead breakdown

Filed as an epic + one bead per milestone (P0–P7) with the lanes above, plus this
design doc. P0 (the realiser seam) is the keystone dependency; P1/P2 unlock the
first playable widget.
