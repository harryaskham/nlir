/* tslint:disable */
/* eslint-disable */

/**
 * Clear retained explicit-LLM preview results after config/model/endpoint
 * changes. Context edits need no blanket clear: rendered operands are in each
 * semantic cache key and invalidate dependants naturally.
 */
export function clearEvaluationCache(): void;

/**
 * `configJsonFromYaml(yaml) -> { ok, json | error }` — any YAML config to `configJson`,
 * through the CLI's loader (same validation, no environment interpolation).
 */
export function configJsonFromYaml(yaml: string): any;

/**
 * `defaultConfigJson() -> String` — the shipped `config.example.yaml`, parsed by the
 * same Rust loader as the CLI (with no environment: `${NLIR_PROMPT}`-style templates are
 * kept literally) and serialised to the JSON every other export takes as `configJson`.
 * Pages no longer need a JavaScript YAML parser; empty string on a (never expected) error.
 */
export function defaultConfigJson(): string;

/**
 * `defaultConfigYaml() -> String` — the canonical `config.example.yaml`, embedded
 * at build time via `nlir::config::EXAMPLE_CONFIG` (the same const the CLI writes
 * on first run). Lets the workspace seed `DEFAULT_CONFIG` from the REAL config so
 * the browser parser + operator set stay in lockstep with the shipped config — no
 * hand-maintained fallback to drift (bd-ca518b; the bd-799000 sigil-keyed lesson).
 */
export function defaultConfigYaml(): string;

/**
 * `evaluate(expr, configJson, contextJson, mode, realisers) -> Promise<{ ok, result|error }>`.
 * DET evaluates on the sync core (key-free); LLM drives `evaluate_async` with
 * the [`JsRealiser`] built from the `realisers` object.
 */
export function evaluate(expr: string, config_json: string, context_json: string, mode: string, realisers: any): Promise<any>;

/**
 * `graph(expr, configJson) -> { ok, svg | error }` — the whole program's
 * dataflow graph rendered to a self-contained SVG string (msm-0's
 * `Graph::from_program` + aur-1's `graph_svg::render`, graph-viz G5). Inject
 * `svg` straight into the DOM.
 */
export function graph(expr: string, config_json: string): any;

/**
 * `graphFrames(expr, configJson, mode) -> { ok, frames:[{svg, reduced}] | error }`
 * — the step-through animation frames (msm-0's `step_frames`): each frame's
 * graph rendered, with `reduced` = the just-reduced NodeId as a dotted path
 * ("0.1.2", or null) for the panel's highlight/caption. DET-only for v1 (llm
 * animation would want a `step_frames_async` twin).
 */
export function graphFrames(expr: string, config_json: string, mode: string): any;

/**
 * `graphFramesAsync(expr, configJson, contextJson, mode, realisers) -> Promise<{ ok, frames:[{svg, reduced}] | error }>`
 * — the LLM twin of [`graph_frames`]: drives msm-0's `step_frames_async` with
 * the injected [`JsRealiser`], so the G5 Animate panel can watch an operator
 * realise as the dataflow graph evolves in llm mode (each realise = a frame).
 * DET mode works too (step_frames_async never awaits in det). Same
 * `Frame{graph, reduced}` output as the sync path, so aur-1's
 * `graph_svg::render` + the G5 scrubber/highlight are unchanged. Pairs with
 * `graphFrames` exactly as `step`/`evaluate` pair their async selves (bd-0f2ce2).
 */
export function graphFramesAsync(expr: string, config_json: string, context_json: string, mode: string, realisers: any): Promise<any>;

/**
 * `graphFramesStreaming(expr, configJson, contextJson, mode, realisers, onFrame)
 * -> Promise<{ ok, count | error }>` — the STREAMING twin of [`graph_frames_async`]:
 * drives msm-0's `step_frames_streaming_async` and fires `onFrame({svg, reduced})`
 * the moment each frame's realisation resolves (live llm graph animation), instead
 * of collecting the whole Vec first. Frames go through the shared [`frame_json`], so
 * they're byte-for-byte identical to `graphFrames`/`graphFramesAsync` — aur-1's G5
 * scrubber/animate() consumes streamed and batched frames the same way. The frames
 * arrive via `onFrame`, not the return (which reports the total count). Mirrors
 * aur-2's `stepStream` shape for the graph path (bd-89eb89).
 */
export function graphFramesStreaming(expr: string, config_json: string, context_json: string, mode: string, realisers: any, on_frame: Function): Promise<any>;

/**
 * `operators(configJson) -> [{op,name,description,arity,priority,fixity,det}]`
 * — the config-derived operator reference, shared byte-for-byte with native
 * `nlir help` via `nlir::config::operator_reference` (anti-drift). Returns the
 * bare array on success; an `{ ok:false, error }` object on a config-parse
 * error (callers can `Array.isArray` to distinguish).
 */
export function operators(config_json: string): any;

/**
 * `outline(expr, configJson) -> { ok, svg, text, statements | error }` — the
 * statement-level graph (v2 §G): one node per top-level statement, edges for
 * `$name` reads, inputs for bound data and prelude forms. Legible for programs
 * of any size, where the expression graph is not.
 */
export function outline(expr: string, config_json: string): any;

/**
 * `parse(expr, configJson) -> { ok, ast|error }` — tokenise + parse to the
 * structural AST render. The grammar (sigils/fixity/priority) is config-defined,
 * so `configJson` is required.
 */
export function parse(expr: string, config_json: string): any;

/**
 * `put(expr, configJson, contextJson, edited) -> { ok, report | error }` — the
 * deterministic backward pass (lenses, v2 §E): given an edited output, the edits
 * to the context inputs and program literals that would produce it, with the lens
 * laws checked. Model operators report as stuck in the browser (they need the
 * CLI's llm-mode backward requests).
 */
export function put(expr: string, config_json: string, context_json: string, edited: string): any;

/**
 * `putAsync(expr, configJson, contextJson, edited, realisers) -> Promise<{ ok, report | error }>`
 * — the backward pass in llm mode: model operators get model-backed backward requests
 * (minimal find/replace patches to their inputs), the edits are pushed on to the bound
 * inputs, and PutGet is re-run and judged. Calls are made through the JS `llm` realiser
 * by suspend-and-resume over the page's shared cache, so forward calls the page already
 * made replay and a repeated request costs nothing.
 */
export function putAsync(expr: string, config_json: string, context_json: string, edited: string, realisers: any): Promise<any>;

/**
 * `step(expr, configJson, contextJson, mode, realisers) -> Promise<{ ok, steps|error }>`.
 * DET replays `step_trace` (same engine as `nlir step` / the repl `:step`);
 * LLM drives `step_async` with the [`JsRealiser`] — so the step view unfolds
 * live for llm ops too (one realise per step).
 */
export function step(expr: string, config_json: string, context_json: string, mode: string, realisers: any): Promise<any>;

/**
 * `stepStream(expr, configJson, contextJson, mode, realisers, onStep) -> Promise<{ ok, count | error }>`.
 * LIVE per-step streaming (bd-89eb89): `onStep(exprString)` fires the MOMENT each
 * reduction resolves — for llm mode that is right after that step's realisation
 * completes (true live streaming, not batch-at-end like [`step`]). Drives
 * `step_trace_streaming(_async)`, bridging each rendered step to the JS callback
 * per step. Resolves with the final step `count` so the caller can confirm the
 * stream finished (the steps themselves arrive via `onStep`, not the return).
 */
export function stepStream(expr: string, config_json: string, context_json: string, mode: string, realisers: any, on_step: Function): Promise<any>;

/**
 * `version() -> { crate, git }` — the co-build stamp (P7 sets `NLIR_WASM_GIT`).
 */
export function version(): any;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly configJsonFromYaml: (a: number, b: number) => any;
    readonly defaultConfigJson: () => [number, number];
    readonly defaultConfigYaml: () => [number, number];
    readonly evaluate: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: any) => any;
    readonly graph: (a: number, b: number, c: number, d: number) => any;
    readonly graphFrames: (a: number, b: number, c: number, d: number, e: number, f: number) => any;
    readonly graphFramesAsync: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: any) => any;
    readonly graphFramesStreaming: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: any, j: any) => any;
    readonly operators: (a: number, b: number) => any;
    readonly outline: (a: number, b: number, c: number, d: number) => any;
    readonly parse: (a: number, b: number, c: number, d: number) => any;
    readonly put: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number) => any;
    readonly putAsync: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: any) => any;
    readonly step: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: any) => any;
    readonly stepStream: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: any, j: any) => any;
    readonly version: () => any;
    readonly clearEvaluationCache: () => void;
    readonly wasm_bindgen__closure__destroy__h81ee272d4a435a11: (a: number, b: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h0d35f2fc21e938b7: (a: number, b: number, c: any, d: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h823762d347a85e75: (a: number, b: number, c: any) => void;
    readonly __wbindgen_malloc: (a: number, b: number) => number;
    readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_free: (a: number, b: number, c: number) => void;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
