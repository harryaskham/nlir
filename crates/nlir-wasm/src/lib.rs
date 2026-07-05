//! nlir-wasm — the nlir evaluator compiled to WebAssembly (nlir-wasm epic
//! bd-360d0c, P1). Thin wasm-bindgen exports over the **same** `nlir` library
//! the native binary uses, so the in-browser workspace can never drift from the
//! shipped evaluator.
//!
//! Boundary conventions (aur-1's JS API contract):
//! - config crosses as JSON (`configJson`): JS does YAML→JSON (js-yaml); the
//!   crate does `serde_json::from_str::<Config>` — `serde_yaml` never enters the
//!   wasm tree (guarded by the native `config_roundtrips_through_json_*` test).
//! - context crosses as JSON (`contextJson`): a `{}` object merged into a fresh
//!   context, or empty.
//! - results are `{ ok, result|error }` / `{ ok, steps }` objects (never JS
//!   rejections) so the workspace renders errors inline.
//!
//! DET mode is the KEY-FREE path (no realiser). LLM mode uses the injected
//! `Realiser` (P3): a JS `{ llm, command }` object of async callbacks (e.g.
//! `fetch(base_url)` — BYO key, keys never leave the user's endpoint) bridged
//! through msm-0's `Realiser` trait + `evaluate_async`/`step_async`.

use js_sys::{Function, Promise, Reflect};
use nlir::Mode;
use wasm_bindgen::JsCast;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;

/// Parse `configJson` into a [`nlir::config::Config`] at the wasm boundary.
fn parse_config(config_json: &str) -> Result<nlir::config::Config, String> {
    serde_json::from_str(config_json).map_err(|error| format!("config JSON: {error}"))
}

/// Build a context from `contextJson` (an object merged into a fresh context, or
/// empty when blank/`null`).
fn parse_context(
    context_json: &str,
    cfg: &nlir::config::Config,
) -> Result<nlir::context::Context, String> {
    let mut ctx = nlir::context::Context::empty(&cfg.context);
    let trimmed = context_json.trim();
    if !trimmed.is_empty() && trimmed != "null" {
        let value: serde_json::Value =
            serde_json::from_str(context_json).map_err(|error| format!("context JSON: {error}"))?;
        match value {
            serde_json::Value::Object(map) => ctx.merge(map),
            _ => return Err("context JSON must be an object".to_owned()),
        }
    }
    Ok(ctx)
}

/// Decode the mode string from the JS boundary.
fn parse_mode(mode: &str) -> Result<Mode, String> {
    match mode {
        "det" => Ok(Mode::Det),
        "llm" => Ok(Mode::Llm),
        other => Err(format!(
            "unknown mode {other:?} (expected \"det\" or \"llm\")"
        )),
    }
}

/// Serialise any value to a `JsValue` result payload.
fn payload<T: serde::Serialize>(value: &T) -> JsValue {
    serde_wasm_bindgen::to_value(value).unwrap_or(JsValue::NULL)
}

// --- P3: the JS-callback Realiser (bd-7482e6) -------------------------------

/// A JS view of an assembled [`nlir::llm::LlmCall`] passed to the JS `llm`
/// callback (LlmCall itself is not `Serialize`; its fields are). JS reads
/// `call.vars.NLIR_PROMPT` + `call.model.model` (the model id).
#[derive(serde::Serialize)]
struct CallView<'a> {
    vars: &'a std::collections::BTreeMap<String, String>,
    model: &'a nlir::config::ModelConfig,
    operands: &'a [String],
}

/// A [`nlir::realiser::Realiser`] backed by injected JS async callbacks: the
/// browser supplies `{ llm, command }` functions returning Promises (e.g.
/// `fetch(base_url + "/chat/completions")`). Keys never leave the user's
/// endpoint (static site, no proxy).
struct JsRealiser {
    llm: Option<Function>,
    command: Option<Function>,
}

impl JsRealiser {
    /// Extract the `llm` / `command` callbacks from the JS `realisers` object
    /// (missing/undefined → `None`, surfaced as a clear error if reached).
    fn from_js(realisers: &JsValue) -> Self {
        Self {
            llm: get_fn(realisers, "llm"),
            command: get_fn(realisers, "command"),
        }
    }
}

fn get_fn(obj: &JsValue, key: &str) -> Option<Function> {
    Reflect::get(obj, &JsValue::from_str(key))
        .ok()
        .and_then(|value| value.dyn_into::<Function>().ok())
}

fn js_err_string(error: &JsValue) -> String {
    // 1. A thrown string.
    if let Some(text) = error.as_string() {
        return text;
    }
    // 2. A JS Error (or subclass: TypeError, RangeError, …). Its `name`/`message`
    //    are NON-ENUMERABLE own properties, so `JSON.stringify` silently drops
    //    them and yields "{}" — the historical cause of the useless
    //    "js realiser rejected: {}" (the workspace `llm` realiser throws
    //    `new Error('llm endpoint 401')`, and a failed `fetch` throws
    //    `TypeError: Failed to fetch`; both stringify to "{}"). Read the Error's
    //    own `name`/`message` so the real cause survives.
    if let Some(err) = error.dyn_ref::<js_sys::Error>() {
        let name = String::from(err.name());
        let message = String::from(err.message());
        return match (name.is_empty(), message.is_empty()) {
            (false, false) => format!("{name}: {message}"),
            (true, false) => message,
            (false, true) => name,
            (true, true) => "unknown JS error".to_owned(),
        };
    }
    // 3. An Error-like object that is not `instanceof Error` (some DOMException
    //    implementations): read `.message` directly.
    if let Ok(message) = Reflect::get(error, &JsValue::from_str("message")) {
        if let Some(message) = message.as_string() {
            if !message.is_empty() {
                return message;
            }
        }
    }
    // 4. A plain object/value carrying data: JSON.stringify, but ignore an empty
    //    "{}"/"null" (which conveys nothing).
    if let Ok(json) = js_sys::JSON::stringify(error) {
        if let Some(json) = json.as_string() {
            if json != "{}" && json != "null" && !json.is_empty() {
                return json;
            }
        }
    }
    "unknown JS error".to_owned()
}

/// Wrap a realiser-side message as a [`nlir::llm::RealiseError`] via the
/// dedicated `Realiser(String)` variant, so a JS-realiser failure renders as
/// "realisation via realiser: …" instead of the misleading "operator command"
/// framing (bd — wasm llm error legibility).
fn realise_err(message: impl Into<String>) -> nlir::llm::RealiseError {
    nlir::llm::RealiseError::Realiser(message.into())
}

/// Call a JS async realiser callback and await its Promise to a string.
async fn call_js_realiser(
    func: &Function,
    args: Vec<JsValue>,
) -> Result<String, nlir::llm::RealiseError> {
    let this = JsValue::NULL;
    let returned = match args.as_slice() {
        [a] => func.call1(&this, a),
        [a, b] => func.call2(&this, a, b),
        _ => func.call0(&this),
    }
    .map_err(|e| realise_err(format!("js realiser threw: {}", js_err_string(&e))))?;
    let resolved = JsFuture::from(Promise::from(returned))
        .await
        .map_err(|e| realise_err(format!("js realiser rejected: {}", js_err_string(&e))))?;
    resolved
        .as_string()
        .ok_or_else(|| realise_err("js realiser did not resolve to a string"))
}

impl nlir::realiser::Realiser for JsRealiser {
    fn llm<'a>(&'a self, call: &'a nlir::llm::LlmCall) -> nlir::realiser::RealiseFuture<'a> {
        Box::pin(async move {
            let func = self.llm.as_ref().ok_or_else(|| {
                realise_err("no llm realiser set — provide an API base-url + key for llm mode")
            })?;
            let view = CallView {
                vars: &call.vars,
                model: &call.model,
                operands: &call.operands,
            };
            let call_js = serde_wasm_bindgen::to_value(&view)
                .map_err(|e| realise_err(format!("serialize LlmCall: {e}")))?;
            call_js_realiser(func, vec![call_js]).await
        })
    }

    fn command<'a>(
        &'a self,
        command: &'a str,
        operands: &'a [String],
    ) -> nlir::realiser::RealiseFuture<'a> {
        Box::pin(async move {
            let func = self
                .command
                .as_ref()
                .ok_or_else(|| realise_err("no command realiser set for this endpoint"))?;
            let cmd_js = JsValue::from_str(command);
            let ops_js = serde_wasm_bindgen::to_value(operands)
                .map_err(|e| realise_err(format!("serialize operands: {e}")))?;
            call_js_realiser(func, vec![cmd_js, ops_js]).await
        })
    }
}

/// `version() -> { crate, git }` — the co-build stamp (P7 sets `NLIR_WASM_GIT`).
#[wasm_bindgen]
pub fn version() -> JsValue {
    payload(&serde_json::json!({
        "crate": env!("CARGO_PKG_VERSION"),
        "git": option_env!("NLIR_WASM_GIT").unwrap_or("unknown"),
    }))
}

/// `parse(expr, configJson) -> { ok, ast|error }` — tokenise + parse to the
/// structural AST render. The grammar (sigils/fixity/priority) is config-defined,
/// so `configJson` is required.
#[wasm_bindgen]
pub fn parse(expr: &str, config_json: &str) -> JsValue {
    let result = (|| -> Result<String, String> {
        let cfg = parse_config(config_json)?;
        let sigils = nlir::config::operator_sigils(&cfg);
        let tokens = nlir::lexer::tokenize(expr, &sigils).map_err(|error| error.to_string())?;
        let program = nlir::parser::parse_program(&tokens, &cfg.operators)
            .map_err(|error| error.to_string())?;
        Ok(program.render())
    })();
    match result {
        Ok(ast) => payload(&serde_json::json!({ "ok": true, "ast": ast })),
        Err(error) => payload(&serde_json::json!({ "ok": false, "error": error })),
    }
}

/// `operators(configJson) -> [{op,name,description,arity,priority,fixity,det}]`
/// — the config-derived operator reference, shared byte-for-byte with native
/// `nlir help` via `nlir::config::operator_reference` (anti-drift). Returns the
/// bare array on success; an `{ ok:false, error }` object on a config-parse
/// error (callers can `Array.isArray` to distinguish).
#[wasm_bindgen]
pub fn operators(config_json: &str) -> JsValue {
    match parse_config(config_json) {
        Ok(cfg) => payload(&nlir::config::operator_reference(&cfg)),
        Err(error) => payload(&serde_json::json!({ "ok": false, "error": error })),
    }
}

/// `evaluate(expr, configJson, contextJson, mode, realisers) -> Promise<{ ok, result|error }>`.
/// DET evaluates on the sync core (key-free); LLM drives `evaluate_async` with
/// the [`JsRealiser`] built from the `realisers` object.
#[wasm_bindgen]
pub async fn evaluate(
    expr: String,
    config_json: String,
    context_json: String,
    mode: String,
    realisers: JsValue,
) -> JsValue {
    match evaluate_inner(&expr, &config_json, &context_json, &mode, &realisers).await {
        Ok(rendered) => payload(&serde_json::json!({ "ok": true, "result": rendered })),
        Err(error) => payload(&serde_json::json!({ "ok": false, "error": error })),
    }
}

async fn evaluate_inner(
    expr: &str,
    config_json: &str,
    context_json: &str,
    mode: &str,
    realisers: &JsValue,
) -> Result<String, String> {
    let cfg = parse_config(config_json)?;
    let parsed_mode = parse_mode(mode)?;
    let mut ctx = parse_context(context_json, &cfg)?;
    let sep = ctx.sep();
    let value = match parsed_mode {
        Mode::Det => {
            nlir::eval::evaluate(expr, &cfg, &mut ctx, Mode::Det).map_err(|e| e.to_string())?
        }
        Mode::Llm => {
            let realiser = JsRealiser::from_js(realisers);
            nlir::eval::evaluate_async(expr, &cfg, &mut ctx, Mode::Llm, &realiser)
                .await
                .map_err(|e| e.to_string())?
        }
    };
    Ok(value.render(&sep))
}

/// `step(expr, configJson, contextJson, mode, realisers) -> Promise<{ ok, steps|error }>`.
/// DET replays `step_trace` (same engine as `nlir step` / the repl `:step`);
/// LLM drives `step_async` with the [`JsRealiser`] — so the step view unfolds
/// live for llm ops too (one realise per step).
#[wasm_bindgen]
pub async fn step(
    expr: String,
    config_json: String,
    context_json: String,
    mode: String,
    realisers: JsValue,
) -> JsValue {
    match step_inner(&expr, &config_json, &context_json, &mode, &realisers).await {
        Ok(steps) => {
            let rows: Vec<serde_json::Value> = steps
                .into_iter()
                .map(|expr| serde_json::json!({ "expr": expr }))
                .collect();
            payload(&serde_json::json!({ "ok": true, "steps": rows }))
        }
        Err(error) => payload(&serde_json::json!({ "ok": false, "error": error })),
    }
}

async fn step_inner(
    expr: &str,
    config_json: &str,
    context_json: &str,
    mode: &str,
    realisers: &JsValue,
) -> Result<Vec<String>, String> {
    let cfg = parse_config(config_json)?;
    let parsed_mode = parse_mode(mode)?;
    let mut ctx = parse_context(context_json, &cfg)?;
    match parsed_mode {
        Mode::Det => {
            nlir::eval::step_trace(expr, &cfg, &mut ctx, Mode::Det).map_err(|e| e.to_string())
        }
        Mode::Llm => {
            let realiser = JsRealiser::from_js(realisers);
            nlir::eval::step_async(expr, &cfg, &mut ctx, Mode::Llm, &realiser)
                .await
                .map_err(|e| e.to_string())
        }
    }
}

/// `graph(expr, configJson) -> { ok, svg | error }` — the whole program's
/// dataflow graph rendered to a self-contained SVG string (msm-0's
/// `Graph::from_program` + aur-1's `graph_svg::render`, graph-viz G5). Inject
/// `svg` straight into the DOM.
#[wasm_bindgen]
pub fn graph(expr: &str, config_json: &str) -> JsValue {
    let result = (|| -> Result<String, String> {
        let cfg = parse_config(config_json)?;
        let sigils = nlir::config::operator_sigils(&cfg);
        let tokens = nlir::lexer::tokenize(expr, &sigils).map_err(|e| e.to_string())?;
        let program =
            nlir::parser::parse_program(&tokens, &cfg.operators).map_err(|e| e.to_string())?;
        let graph = nlir::graph::Graph::from_program(&program);
        Ok(nlir::graph_svg::render(&graph))
    })();
    match result {
        Ok(svg) => payload(&serde_json::json!({ "ok": true, "svg": svg })),
        Err(error) => payload(&serde_json::json!({ "ok": false, "error": error })),
    }
}

/// `graphFrames(expr, configJson, mode) -> { ok, frames:[{svg, reduced}] | error }`
/// — the step-through animation frames (msm-0's `step_frames`): each frame's
/// graph rendered, with `reduced` = the just-reduced NodeId as a dotted path
/// ("0.1.2", or null) for the panel's highlight/caption. DET-only for v1 (llm
/// animation would want a `step_frames_async` twin).
#[wasm_bindgen(js_name = graphFrames)]
pub fn graph_frames(expr: &str, config_json: &str, mode: &str) -> JsValue {
    let result = (|| -> Result<Vec<serde_json::Value>, String> {
        let cfg = parse_config(config_json)?;
        if let Mode::Llm = parse_mode(mode)? {
            return Err(
                "llm graph animation needs step_frames_async — det-only for now".to_owned(),
            );
        }
        let mut ctx = nlir::context::Context::empty(&cfg.context);
        let frames =
            nlir::eval::step_frames(expr, &cfg, &mut ctx, Mode::Det).map_err(|e| e.to_string())?;
        Ok(frames
            .iter()
            .map(|frame| {
                serde_json::json!({
                    "svg": nlir::graph_svg::render(&frame.graph),
                    "reduced": frame.reduced.as_ref().map(nlir::graph::NodeId::dotted),
                })
            })
            .collect())
    })();
    match result {
        Ok(frames) => payload(&serde_json::json!({ "ok": true, "frames": frames })),
        Err(error) => payload(&serde_json::json!({ "ok": false, "error": error })),
    }
}

/// `graphFramesAsync(expr, configJson, contextJson, mode, realisers) -> Promise<{ ok, frames:[{svg, reduced}] | error }>`
/// — the LLM twin of [`graph_frames`]: drives msm-0's `step_frames_async` with
/// the injected [`JsRealiser`], so the G5 Animate panel can watch an operator
/// realise as the dataflow graph evolves in llm mode (each realise = a frame).
/// DET mode works too (step_frames_async never awaits in det). Same
/// `Frame{graph, reduced}` output as the sync path, so aur-1's
/// `graph_svg::render` + the G5 scrubber/highlight are unchanged. Pairs with
/// `graphFrames` exactly as `step`/`evaluate` pair their async selves (bd-0f2ce2).
#[wasm_bindgen(js_name = graphFramesAsync)]
pub async fn graph_frames_async(
    expr: String,
    config_json: String,
    context_json: String,
    mode: String,
    realisers: JsValue,
) -> JsValue {
    match graph_frames_async_inner(&expr, &config_json, &context_json, &mode, &realisers).await {
        Ok(frames) => payload(&serde_json::json!({ "ok": true, "frames": frames })),
        Err(error) => payload(&serde_json::json!({ "ok": false, "error": error })),
    }
}

async fn graph_frames_async_inner(
    expr: &str,
    config_json: &str,
    context_json: &str,
    mode: &str,
    realisers: &JsValue,
) -> Result<Vec<serde_json::Value>, String> {
    let cfg = parse_config(config_json)?;
    let parsed_mode = parse_mode(mode)?;
    let mut ctx = parse_context(context_json, &cfg)?;
    let realiser = JsRealiser::from_js(realisers);
    let frames = nlir::eval::step_frames_async(expr, &cfg, &mut ctx, parsed_mode, &realiser)
        .await
        .map_err(|e| e.to_string())?;
    Ok(frames
        .iter()
        .map(|frame| {
            serde_json::json!({
                "svg": nlir::graph_svg::render(&frame.graph),
                "reduced": frame.reduced.as_ref().map(nlir::graph::NodeId::dotted),
            })
        })
        .collect())
}
