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
//! DET mode is the KEY-FREE path (no realiser): `evaluate`/`step`/`parse`/
//! `operators`/`version` all work with zero network + zero key. LLM mode needs
//! the injected `Realiser` (P3: a JS `fetch`/on-device callback) + msm-0's
//! `evaluate_async`/`step_async`; those branches return a clear "needs a key"
//! error until P3 wires the JsRealiser.

use nlir::Mode;
use wasm_bindgen::prelude::*;

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
        other => Err(format!("unknown mode {other:?} (expected \"det\" or \"llm\")")),
    }
}

/// Serialise any value to a `JsValue` result payload.
fn payload<T: serde::Serialize>(value: &T) -> JsValue {
    serde_wasm_bindgen::to_value(value).unwrap_or(JsValue::NULL)
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
        let program =
            nlir::parser::parse_program(&tokens, &cfg.operators).map_err(|error| error.to_string())?;
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

/// `evaluate(expr, configJson, contextJson, mode) -> Promise<{ ok, result|error }>`.
/// DET evaluates fully (key-free); LLM awaits the injected realiser (P3).
#[wasm_bindgen]
pub async fn evaluate(
    expr: String,
    config_json: String,
    context_json: String,
    mode: String,
) -> JsValue {
    let result = (|| -> Result<String, String> {
        let cfg = parse_config(&config_json)?;
        let parsed_mode = parse_mode(&mode)?;
        let mut ctx = parse_context(&context_json, &cfg)?;
        match parsed_mode {
            Mode::Det => {
                let value = nlir::eval::evaluate(&expr, &cfg, &mut ctx, Mode::Det)
                    .map_err(|error| error.to_string())?;
                Ok(value.render(&ctx.sep()))
            }
            Mode::Llm => Err(
                "llm mode needs a realiser (an API key or on-device model) — wired in P3; \
                 det mode is key-free"
                    .to_owned(),
            ),
        }
    })();
    match result {
        Ok(rendered) => payload(&serde_json::json!({ "ok": true, "result": rendered })),
        Err(error) => payload(&serde_json::json!({ "ok": false, "error": error })),
    }
}

/// `step(expr, configJson, contextJson, mode) -> Promise<{ ok, steps|error }>`.
/// DET replays the real small-step reduction (the same engine as `nlir step` /
/// the repl `:step`); LLM step awaits msm-0's `step_async` follow-up.
#[wasm_bindgen]
pub async fn step(
    expr: String,
    config_json: String,
    context_json: String,
    mode: String,
) -> JsValue {
    let result = (|| -> Result<Vec<String>, String> {
        let cfg = parse_config(&config_json)?;
        let parsed_mode = parse_mode(&mode)?;
        if let Mode::Llm = parsed_mode {
            return Err(
                "llm step needs step_async (a follow-up); det step is key-free".to_owned(),
            );
        }
        let mut ctx = parse_context(&context_json, &cfg)?;
        nlir::eval::step_trace(&expr, &cfg, &mut ctx, Mode::Det).map_err(|error| error.to_string())
    })();
    match result {
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
