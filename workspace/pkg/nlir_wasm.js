/* @ts-self-types="./nlir_wasm.d.ts" */

/**
 * Clear retained explicit-LLM preview results after config/model/endpoint
 * changes. Context edits need no blanket clear: rendered operands are in each
 * semantic cache key and invalidate dependants naturally.
 */
export function clearEvaluationCache() {
    wasm.clearEvaluationCache();
}

/**
 * `configJsonFromYaml(yaml) -> { ok, json | error }` — any YAML config to `configJson`,
 * through the CLI's loader (same validation, no environment interpolation).
 * @param {string} yaml
 * @returns {any}
 */
export function configJsonFromYaml(yaml) {
    const ptr0 = passStringToWasm0(yaml, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ret = wasm.configJsonFromYaml(ptr0, len0);
    return ret;
}

/**
 * `defaultConfigJson() -> String` — the shipped `config.example.yaml`, parsed by the
 * same Rust loader as the CLI (with no environment: `${NLIR_PROMPT}`-style templates are
 * kept literally) and serialised to the JSON every other export takes as `configJson`.
 * Pages no longer need a JavaScript YAML parser; empty string on a (never expected) error.
 * @returns {string}
 */
export function defaultConfigJson() {
    let deferred1_0;
    let deferred1_1;
    try {
        const ret = wasm.defaultConfigJson();
        deferred1_0 = ret[0];
        deferred1_1 = ret[1];
        return getStringFromWasm0(ret[0], ret[1]);
    } finally {
        wasm.__wbindgen_free(deferred1_0, deferred1_1, 1);
    }
}

/**
 * `defaultConfigYaml() -> String` — the canonical `config.example.yaml`, embedded
 * at build time via `nlir::config::EXAMPLE_CONFIG` (the same const the CLI writes
 * on first run). Lets the workspace seed `DEFAULT_CONFIG` from the REAL config so
 * the browser parser + operator set stay in lockstep with the shipped config — no
 * hand-maintained fallback to drift (bd-ca518b; the bd-799000 sigil-keyed lesson).
 * @returns {string}
 */
export function defaultConfigYaml() {
    let deferred1_0;
    let deferred1_1;
    try {
        const ret = wasm.defaultConfigYaml();
        deferred1_0 = ret[0];
        deferred1_1 = ret[1];
        return getStringFromWasm0(ret[0], ret[1]);
    } finally {
        wasm.__wbindgen_free(deferred1_0, deferred1_1, 1);
    }
}

/**
 * `evaluate(expr, configJson, contextJson, mode, realisers) -> Promise<{ ok, result|error }>`.
 * DET evaluates on the sync core (key-free); LLM drives `evaluate_async` with
 * the [`JsRealiser`] built from the `realisers` object.
 * @param {string} expr
 * @param {string} config_json
 * @param {string} context_json
 * @param {string} mode
 * @param {any} realisers
 * @returns {Promise<any>}
 */
export function evaluate(expr, config_json, context_json, mode, realisers) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ptr2 = passStringToWasm0(context_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len2 = WASM_VECTOR_LEN;
    const ptr3 = passStringToWasm0(mode, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len3 = WASM_VECTOR_LEN;
    const ret = wasm.evaluate(ptr0, len0, ptr1, len1, ptr2, len2, ptr3, len3, realisers);
    return ret;
}

/**
 * `graph(expr, configJson) -> { ok, svg | error }` — the whole program's
 * dataflow graph rendered to a self-contained SVG string (msm-0's
 * `Graph::from_program` + aur-1's `graph_svg::render`, graph-viz G5). Inject
 * `svg` straight into the DOM.
 * @param {string} expr
 * @param {string} config_json
 * @returns {any}
 */
export function graph(expr, config_json) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ret = wasm.graph(ptr0, len0, ptr1, len1);
    return ret;
}

/**
 * `graphFrames(expr, configJson, mode) -> { ok, frames:[{svg, reduced}] | error }`
 * — the step-through animation frames (msm-0's `step_frames`): each frame's
 * graph rendered, with `reduced` = the just-reduced NodeId as a dotted path
 * ("0.1.2", or null) for the panel's highlight/caption. DET-only for v1 (llm
 * animation would want a `step_frames_async` twin).
 * @param {string} expr
 * @param {string} config_json
 * @param {string} mode
 * @returns {any}
 */
export function graphFrames(expr, config_json, mode) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ptr2 = passStringToWasm0(mode, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len2 = WASM_VECTOR_LEN;
    const ret = wasm.graphFrames(ptr0, len0, ptr1, len1, ptr2, len2);
    return ret;
}

/**
 * `graphFramesAsync(expr, configJson, contextJson, mode, realisers) -> Promise<{ ok, frames:[{svg, reduced}] | error }>`
 * — the LLM twin of [`graph_frames`]: drives msm-0's `step_frames_async` with
 * the injected [`JsRealiser`], so the G5 Animate panel can watch an operator
 * realise as the dataflow graph evolves in llm mode (each realise = a frame).
 * DET mode works too (step_frames_async never awaits in det). Same
 * `Frame{graph, reduced}` output as the sync path, so aur-1's
 * `graph_svg::render` + the G5 scrubber/highlight are unchanged. Pairs with
 * `graphFrames` exactly as `step`/`evaluate` pair their async selves (bd-0f2ce2).
 * @param {string} expr
 * @param {string} config_json
 * @param {string} context_json
 * @param {string} mode
 * @param {any} realisers
 * @returns {Promise<any>}
 */
export function graphFramesAsync(expr, config_json, context_json, mode, realisers) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ptr2 = passStringToWasm0(context_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len2 = WASM_VECTOR_LEN;
    const ptr3 = passStringToWasm0(mode, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len3 = WASM_VECTOR_LEN;
    const ret = wasm.graphFramesAsync(ptr0, len0, ptr1, len1, ptr2, len2, ptr3, len3, realisers);
    return ret;
}

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
 * @param {string} expr
 * @param {string} config_json
 * @param {string} context_json
 * @param {string} mode
 * @param {any} realisers
 * @param {Function} on_frame
 * @returns {Promise<any>}
 */
export function graphFramesStreaming(expr, config_json, context_json, mode, realisers, on_frame) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ptr2 = passStringToWasm0(context_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len2 = WASM_VECTOR_LEN;
    const ptr3 = passStringToWasm0(mode, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len3 = WASM_VECTOR_LEN;
    const ret = wasm.graphFramesStreaming(ptr0, len0, ptr1, len1, ptr2, len2, ptr3, len3, realisers, on_frame);
    return ret;
}

/**
 * `operators(configJson) -> [{op,name,description,arity,priority,fixity,det}]`
 * — the config-derived operator reference, shared byte-for-byte with native
 * `nlir help` via `nlir::config::operator_reference` (anti-drift). Returns the
 * bare array on success; an `{ ok:false, error }` object on a config-parse
 * error (callers can `Array.isArray` to distinguish).
 * @param {string} config_json
 * @returns {any}
 */
export function operators(config_json) {
    const ptr0 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ret = wasm.operators(ptr0, len0);
    return ret;
}

/**
 * `outline(expr, configJson) -> { ok, svg, text, statements | error }` — the
 * statement-level graph (v2 §G): one node per top-level statement, edges for
 * `$name` reads, inputs for bound data and prelude forms. Legible for programs
 * of any size, where the expression graph is not.
 * @param {string} expr
 * @param {string} config_json
 * @returns {any}
 */
export function outline(expr, config_json) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ret = wasm.outline(ptr0, len0, ptr1, len1);
    return ret;
}

/**
 * `parse(expr, configJson) -> { ok, ast|error }` — tokenise + parse to the
 * structural AST render. The grammar (sigils/fixity/priority) is config-defined,
 * so `configJson` is required.
 * @param {string} expr
 * @param {string} config_json
 * @returns {any}
 */
export function parse(expr, config_json) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ret = wasm.parse(ptr0, len0, ptr1, len1);
    return ret;
}

/**
 * `put(expr, configJson, contextJson, edited) -> { ok, report | error }` — the
 * deterministic backward pass (lenses, v2 §E): given an edited output, the edits
 * to the context inputs and program literals that would produce it, with the lens
 * laws checked. Model operators report as stuck in the browser (they need the
 * CLI's llm-mode backward requests).
 * @param {string} expr
 * @param {string} config_json
 * @param {string} context_json
 * @param {string} edited
 * @returns {any}
 */
export function put(expr, config_json, context_json, edited) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ptr2 = passStringToWasm0(context_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len2 = WASM_VECTOR_LEN;
    const ptr3 = passStringToWasm0(edited, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len3 = WASM_VECTOR_LEN;
    const ret = wasm.put(ptr0, len0, ptr1, len1, ptr2, len2, ptr3, len3);
    return ret;
}

/**
 * `step(expr, configJson, contextJson, mode, realisers) -> Promise<{ ok, steps|error }>`.
 * DET replays `step_trace` (same engine as `nlir step` / the repl `:step`);
 * LLM drives `step_async` with the [`JsRealiser`] — so the step view unfolds
 * live for llm ops too (one realise per step).
 * @param {string} expr
 * @param {string} config_json
 * @param {string} context_json
 * @param {string} mode
 * @param {any} realisers
 * @returns {Promise<any>}
 */
export function step(expr, config_json, context_json, mode, realisers) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ptr2 = passStringToWasm0(context_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len2 = WASM_VECTOR_LEN;
    const ptr3 = passStringToWasm0(mode, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len3 = WASM_VECTOR_LEN;
    const ret = wasm.step(ptr0, len0, ptr1, len1, ptr2, len2, ptr3, len3, realisers);
    return ret;
}

/**
 * `stepStream(expr, configJson, contextJson, mode, realisers, onStep) -> Promise<{ ok, count | error }>`.
 * LIVE per-step streaming (bd-89eb89): `onStep(exprString)` fires the MOMENT each
 * reduction resolves — for llm mode that is right after that step's realisation
 * completes (true live streaming, not batch-at-end like [`step`]). Drives
 * `step_trace_streaming(_async)`, bridging each rendered step to the JS callback
 * per step. Resolves with the final step `count` so the caller can confirm the
 * stream finished (the steps themselves arrive via `onStep`, not the return).
 * @param {string} expr
 * @param {string} config_json
 * @param {string} context_json
 * @param {string} mode
 * @param {any} realisers
 * @param {Function} on_step
 * @returns {Promise<any>}
 */
export function stepStream(expr, config_json, context_json, mode, realisers, on_step) {
    const ptr0 = passStringToWasm0(expr, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len0 = WASM_VECTOR_LEN;
    const ptr1 = passStringToWasm0(config_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len1 = WASM_VECTOR_LEN;
    const ptr2 = passStringToWasm0(context_json, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len2 = WASM_VECTOR_LEN;
    const ptr3 = passStringToWasm0(mode, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
    const len3 = WASM_VECTOR_LEN;
    const ret = wasm.stepStream(ptr0, len0, ptr1, len1, ptr2, len2, ptr3, len3, realisers, on_step);
    return ret;
}

/**
 * `version() -> { crate, git }` — the co-build stamp (P7 sets `NLIR_WASM_GIT`).
 * @returns {any}
 */
export function version() {
    const ret = wasm.version();
    return ret;
}

function __wbg_get_imports() {
    const import0 = {
        __proto__: null,
        __wbg_Error_8c4e43fe74559d73: function(arg0, arg1) {
            const ret = Error(getStringFromWasm0(arg0, arg1));
            return ret;
        },
        __wbg_String_8f0eb39a4a4c2f66: function(arg0, arg1) {
            const ret = String(arg1);
            const ptr1 = passStringToWasm0(ret, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
            const len1 = WASM_VECTOR_LEN;
            getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
            getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
        },
        __wbg___wbindgen_is_function_0095a73b8b156f76: function(arg0) {
            const ret = typeof(arg0) === 'function';
            return ret;
        },
        __wbg___wbindgen_is_string_cd444516edc5b180: function(arg0) {
            const ret = typeof(arg0) === 'string';
            return ret;
        },
        __wbg___wbindgen_is_undefined_9e4d92534c42d778: function(arg0) {
            const ret = arg0 === undefined;
            return ret;
        },
        __wbg___wbindgen_string_get_72fb696202c56729: function(arg0, arg1) {
            const obj = arg1;
            const ret = typeof(obj) === 'string' ? obj : undefined;
            var ptr1 = isLikeNone(ret) ? 0 : passStringToWasm0(ret, wasm.__wbindgen_malloc, wasm.__wbindgen_realloc);
            var len1 = WASM_VECTOR_LEN;
            getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
            getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
        },
        __wbg___wbindgen_throw_be289d5034ed271b: function(arg0, arg1) {
            throw new Error(getStringFromWasm0(arg0, arg1));
        },
        __wbg__wbg_cb_unref_d9b87ff7982e3b21: function(arg0) {
            arg0._wbg_cb_unref();
        },
        __wbg_call_389efe28435a9388: function() { return handleError(function (arg0, arg1) {
            const ret = arg0.call(arg1);
            return ret;
        }, arguments); },
        __wbg_call_4708e0c13bdc8e95: function() { return handleError(function (arg0, arg1, arg2) {
            const ret = arg0.call(arg1, arg2);
            return ret;
        }, arguments); },
        __wbg_call_812d25f1510c13c8: function() { return handleError(function (arg0, arg1, arg2, arg3) {
            const ret = arg0.call(arg1, arg2, arg3);
            return ret;
        }, arguments); },
        __wbg_get_b3ed3ad4be2bc8ac: function() { return handleError(function (arg0, arg1) {
            const ret = Reflect.get(arg0, arg1);
            return ret;
        }, arguments); },
        __wbg_instanceof_Error_8573fe0b0b480f46: function(arg0) {
            let result;
            try {
                result = arg0 instanceof Error;
            } catch (_) {
                result = false;
            }
            const ret = result;
            return ret;
        },
        __wbg_message_9ddc4b9a62a7c379: function(arg0) {
            const ret = arg0.message;
            return ret;
        },
        __wbg_name_446e25ef2cfdab5a: function(arg0) {
            const ret = arg0.name;
            return ret;
        },
        __wbg_new_361308b2356cecd0: function() {
            const ret = new Object();
            return ret;
        },
        __wbg_new_3eb36ae241fe6f44: function() {
            const ret = new Array();
            return ret;
        },
        __wbg_new_b5d9e2fb389fef91: function(arg0, arg1) {
            try {
                var state0 = {a: arg0, b: arg1};
                var cb0 = (arg0, arg1) => {
                    const a = state0.a;
                    state0.a = 0;
                    try {
                        return wasm_bindgen__convert__closures_____invoke__h0d35f2fc21e938b7(a, state0.b, arg0, arg1);
                    } finally {
                        state0.a = a;
                    }
                };
                const ret = new Promise(cb0);
                return ret;
            } finally {
                state0.a = state0.b = 0;
            }
        },
        __wbg_new_dca287b076112a51: function() {
            const ret = new Map();
            return ret;
        },
        __wbg_new_no_args_1c7c842f08d00ebb: function(arg0, arg1) {
            const ret = new Function(getStringFromWasm0(arg0, arg1));
            return ret;
        },
        __wbg_queueMicrotask_0aa0a927f78f5d98: function(arg0) {
            const ret = arg0.queueMicrotask;
            return ret;
        },
        __wbg_queueMicrotask_5bb536982f78a56f: function(arg0) {
            queueMicrotask(arg0);
        },
        __wbg_resolve_002c4b7d9d8f6b64: function(arg0) {
            const ret = Promise.resolve(arg0);
            return ret;
        },
        __wbg_set_1eb0999cf5d27fc8: function(arg0, arg1, arg2) {
            const ret = arg0.set(arg1, arg2);
            return ret;
        },
        __wbg_set_3f1d0b984ed272ed: function(arg0, arg1, arg2) {
            arg0[arg1] = arg2;
        },
        __wbg_set_f43e577aea94465b: function(arg0, arg1, arg2) {
            arg0[arg1 >>> 0] = arg2;
        },
        __wbg_static_accessor_GLOBAL_12837167ad935116: function() {
            const ret = typeof global === 'undefined' ? null : global;
            return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
        },
        __wbg_static_accessor_GLOBAL_THIS_e628e89ab3b1c95f: function() {
            const ret = typeof globalThis === 'undefined' ? null : globalThis;
            return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
        },
        __wbg_static_accessor_SELF_a621d3dfbb60d0ce: function() {
            const ret = typeof self === 'undefined' ? null : self;
            return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
        },
        __wbg_static_accessor_WINDOW_f8727f0cf888e0bd: function() {
            const ret = typeof window === 'undefined' ? null : window;
            return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
        },
        __wbg_stringify_8d1cc6ff383e8bae: function() { return handleError(function (arg0) {
            const ret = JSON.stringify(arg0);
            return ret;
        }, arguments); },
        __wbg_then_0d9fe2c7b1857d32: function(arg0, arg1, arg2) {
            const ret = arg0.then(arg1, arg2);
            return ret;
        },
        __wbg_then_b9e7b3b5f1a9e1b5: function(arg0, arg1) {
            const ret = arg0.then(arg1);
            return ret;
        },
        __wbindgen_cast_0000000000000001: function(arg0, arg1) {
            // Cast intrinsic for `Closure(Closure { dtor_idx: 105, function: Function { arguments: [Externref], shim_idx: 106, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
            const ret = makeMutClosure(arg0, arg1, wasm.wasm_bindgen__closure__destroy__h81ee272d4a435a11, wasm_bindgen__convert__closures_____invoke__h823762d347a85e75);
            return ret;
        },
        __wbindgen_cast_0000000000000002: function(arg0) {
            // Cast intrinsic for `F64 -> Externref`.
            const ret = arg0;
            return ret;
        },
        __wbindgen_cast_0000000000000003: function(arg0) {
            // Cast intrinsic for `I64 -> Externref`.
            const ret = arg0;
            return ret;
        },
        __wbindgen_cast_0000000000000004: function(arg0, arg1) {
            // Cast intrinsic for `Ref(String) -> Externref`.
            const ret = getStringFromWasm0(arg0, arg1);
            return ret;
        },
        __wbindgen_cast_0000000000000005: function(arg0) {
            // Cast intrinsic for `U64 -> Externref`.
            const ret = BigInt.asUintN(64, arg0);
            return ret;
        },
        __wbindgen_init_externref_table: function() {
            const table = wasm.__wbindgen_externrefs;
            const offset = table.grow(4);
            table.set(0, undefined);
            table.set(offset + 0, undefined);
            table.set(offset + 1, null);
            table.set(offset + 2, true);
            table.set(offset + 3, false);
        },
    };
    return {
        __proto__: null,
        "./nlir_wasm_bg.js": import0,
    };
}

function wasm_bindgen__convert__closures_____invoke__h823762d347a85e75(arg0, arg1, arg2) {
    wasm.wasm_bindgen__convert__closures_____invoke__h823762d347a85e75(arg0, arg1, arg2);
}

function wasm_bindgen__convert__closures_____invoke__h0d35f2fc21e938b7(arg0, arg1, arg2, arg3) {
    wasm.wasm_bindgen__convert__closures_____invoke__h0d35f2fc21e938b7(arg0, arg1, arg2, arg3);
}

function addToExternrefTable0(obj) {
    const idx = wasm.__externref_table_alloc();
    wasm.__wbindgen_externrefs.set(idx, obj);
    return idx;
}

const CLOSURE_DTORS = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(state => state.dtor(state.a, state.b));

let cachedDataViewMemory0 = null;
function getDataViewMemory0() {
    if (cachedDataViewMemory0 === null || cachedDataViewMemory0.buffer.detached === true || (cachedDataViewMemory0.buffer.detached === undefined && cachedDataViewMemory0.buffer !== wasm.memory.buffer)) {
        cachedDataViewMemory0 = new DataView(wasm.memory.buffer);
    }
    return cachedDataViewMemory0;
}

function getStringFromWasm0(ptr, len) {
    ptr = ptr >>> 0;
    return decodeText(ptr, len);
}

let cachedUint8ArrayMemory0 = null;
function getUint8ArrayMemory0() {
    if (cachedUint8ArrayMemory0 === null || cachedUint8ArrayMemory0.byteLength === 0) {
        cachedUint8ArrayMemory0 = new Uint8Array(wasm.memory.buffer);
    }
    return cachedUint8ArrayMemory0;
}

function handleError(f, args) {
    try {
        return f.apply(this, args);
    } catch (e) {
        const idx = addToExternrefTable0(e);
        wasm.__wbindgen_exn_store(idx);
    }
}

function isLikeNone(x) {
    return x === undefined || x === null;
}

function makeMutClosure(arg0, arg1, dtor, f) {
    const state = { a: arg0, b: arg1, cnt: 1, dtor };
    const real = (...args) => {

        // First up with a closure we increment the internal reference
        // count. This ensures that the Rust closure environment won't
        // be deallocated while we're invoking it.
        state.cnt++;
        const a = state.a;
        state.a = 0;
        try {
            return f(a, state.b, ...args);
        } finally {
            state.a = a;
            real._wbg_cb_unref();
        }
    };
    real._wbg_cb_unref = () => {
        if (--state.cnt === 0) {
            state.dtor(state.a, state.b);
            state.a = 0;
            CLOSURE_DTORS.unregister(state);
        }
    };
    CLOSURE_DTORS.register(real, state, state);
    return real;
}

function passStringToWasm0(arg, malloc, realloc) {
    if (realloc === undefined) {
        const buf = cachedTextEncoder.encode(arg);
        const ptr = malloc(buf.length, 1) >>> 0;
        getUint8ArrayMemory0().subarray(ptr, ptr + buf.length).set(buf);
        WASM_VECTOR_LEN = buf.length;
        return ptr;
    }

    let len = arg.length;
    let ptr = malloc(len, 1) >>> 0;

    const mem = getUint8ArrayMemory0();

    let offset = 0;

    for (; offset < len; offset++) {
        const code = arg.charCodeAt(offset);
        if (code > 0x7F) break;
        mem[ptr + offset] = code;
    }
    if (offset !== len) {
        if (offset !== 0) {
            arg = arg.slice(offset);
        }
        ptr = realloc(ptr, len, len = offset + arg.length * 3, 1) >>> 0;
        const view = getUint8ArrayMemory0().subarray(ptr + offset, ptr + len);
        const ret = cachedTextEncoder.encodeInto(arg, view);

        offset += ret.written;
        ptr = realloc(ptr, len, offset, 1) >>> 0;
    }

    WASM_VECTOR_LEN = offset;
    return ptr;
}

let cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true, fatal: true });
cachedTextDecoder.decode();
const MAX_SAFARI_DECODE_BYTES = 2146435072;
let numBytesDecoded = 0;
function decodeText(ptr, len) {
    numBytesDecoded += len;
    if (numBytesDecoded >= MAX_SAFARI_DECODE_BYTES) {
        cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true, fatal: true });
        cachedTextDecoder.decode();
        numBytesDecoded = len;
    }
    return cachedTextDecoder.decode(getUint8ArrayMemory0().subarray(ptr, ptr + len));
}

const cachedTextEncoder = new TextEncoder();

if (!('encodeInto' in cachedTextEncoder)) {
    cachedTextEncoder.encodeInto = function (arg, view) {
        const buf = cachedTextEncoder.encode(arg);
        view.set(buf);
        return {
            read: arg.length,
            written: buf.length
        };
    };
}

let WASM_VECTOR_LEN = 0;

let wasmModule, wasm;
function __wbg_finalize_init(instance, module) {
    wasm = instance.exports;
    wasmModule = module;
    cachedDataViewMemory0 = null;
    cachedUint8ArrayMemory0 = null;
    wasm.__wbindgen_start();
    return wasm;
}

async function __wbg_load(module, imports) {
    if (typeof Response === 'function' && module instanceof Response) {
        if (typeof WebAssembly.instantiateStreaming === 'function') {
            try {
                return await WebAssembly.instantiateStreaming(module, imports);
            } catch (e) {
                const validResponse = module.ok && expectedResponseType(module.type);

                if (validResponse && module.headers.get('Content-Type') !== 'application/wasm') {
                    console.warn("`WebAssembly.instantiateStreaming` failed because your server does not serve Wasm with `application/wasm` MIME type. Falling back to `WebAssembly.instantiate` which is slower. Original error:\n", e);

                } else { throw e; }
            }
        }

        const bytes = await module.arrayBuffer();
        return await WebAssembly.instantiate(bytes, imports);
    } else {
        const instance = await WebAssembly.instantiate(module, imports);

        if (instance instanceof WebAssembly.Instance) {
            return { instance, module };
        } else {
            return instance;
        }
    }

    function expectedResponseType(type) {
        switch (type) {
            case 'basic': case 'cors': case 'default': return true;
        }
        return false;
    }
}

function initSync(module) {
    if (wasm !== undefined) return wasm;


    if (module !== undefined) {
        if (Object.getPrototypeOf(module) === Object.prototype) {
            ({module} = module)
        } else {
            console.warn('using deprecated parameters for `initSync()`; pass a single object instead')
        }
    }

    const imports = __wbg_get_imports();
    if (!(module instanceof WebAssembly.Module)) {
        module = new WebAssembly.Module(module);
    }
    const instance = new WebAssembly.Instance(module, imports);
    return __wbg_finalize_init(instance, module);
}

async function __wbg_init(module_or_path) {
    if (wasm !== undefined) return wasm;


    if (module_or_path !== undefined) {
        if (Object.getPrototypeOf(module_or_path) === Object.prototype) {
            ({module_or_path} = module_or_path)
        } else {
            console.warn('using deprecated parameters for the initialization function; pass a single object instead')
        }
    }

    if (module_or_path === undefined) {
        module_or_path = new URL('nlir_wasm_bg.wasm', import.meta.url);
    }
    const imports = __wbg_get_imports();

    if (typeof module_or_path === 'string' || (typeof Request === 'function' && module_or_path instanceof Request) || (typeof URL === 'function' && module_or_path instanceof URL)) {
        module_or_path = fetch(module_or_path);
    }

    const { instance, module } = await __wbg_load(await module_or_path, imports);

    return __wbg_finalize_init(instance, module);
}

export { initSync, __wbg_init as default };
