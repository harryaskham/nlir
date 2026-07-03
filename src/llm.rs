//! nlir LLM model backends & prompt pipeline (SPEC §Modes, §Example config).
//!
//! Parent epic bd-b71b0b. This module is the `llm`-mode realisation surface:
//! given an operator (or a coercion) that must be realised via an LLM, it
//! resolves which configured model backend to call, assembles the prompt,
//! invokes the backend (`anthropic_messages` HTTP or a `command` subprocess),
//! and extracts the result.
//!
//! bd-f0d357 lands the first, network-free piece — **model resolution**: mapping
//! an operator's `model:` alias (or the `--model` override / `defaults.model`)
//! to a concrete [`ModelConfig`]. The backend calls, prompt assembly, and result
//! extraction land in the sibling `llm` beads.

use std::fmt;

use crate::config::{Config, ModelConfig, ModelFormat};

/// Why [`resolve_model`] could not select a model backend.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ModelResolveError {
    /// No model alias was available from the operator's `model:`, the `--model`
    /// override, or `defaults.model` — an `llm`-mode realisation needs one.
    NoModel,
    /// A model alias was selected but does not name an entry in `models:`.
    UnknownModel(String),
}

impl fmt::Display for ModelResolveError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ModelResolveError::NoModel => f.write_str(
                "no model configured: set an operator `model:`, pass `--model`, or set `defaults.model`",
            ),
            ModelResolveError::UnknownModel(alias) => {
                write!(f, "unknown model `{alias}`: not defined under `models:`")
            }
        }
    }
}

impl std::error::Error for ModelResolveError {}

/// Resolve the model backend for an `llm`-mode realisation.
///
/// Precedence for the model **alias**:
/// 1. the operator's (or coercion's) explicit `model:` alias, when set;
/// 2. otherwise the `--model` CLI override, when set;
/// 3. otherwise `defaults.model`.
///
/// The `--model` override and `defaults.model` share the "default model" slot —
/// `--model` overrides the configured default — while an operator's own `model:`
/// always wins over that default (so `--model` re-points the default without
/// clobbering operators that deliberately pin a specific model).
///
/// The resolved alias must name an entry in `config.models`. Returns the
/// resolved alias (borrowed from the config map key) together with its
/// [`ModelConfig`].
///
/// # Errors
/// - [`ModelResolveError::NoModel`] when no alias is available at all.
/// - [`ModelResolveError::UnknownModel`] when the alias is not defined under
///   `models:`.
pub fn resolve_model<'c>(
    config: &'c Config,
    operator_model: Option<&str>,
    cli_model: Option<&str>,
) -> Result<(&'c str, &'c ModelConfig), ModelResolveError> {
    let alias = operator_model
        .or(cli_model)
        .or(config.defaults.model.as_deref())
        .ok_or(ModelResolveError::NoModel)?;
    config
        .models
        .get_key_value(alias)
        .map(|(name, model)| (name.as_str(), model))
        .ok_or_else(|| ModelResolveError::UnknownModel(alias.to_owned()))
}

/// The JSON field a `format: json` backend response carries its result under,
/// when the model config does not name one.
pub const DEFAULT_RESULT_FIELD: &str = "result";

/// Why [`extract_result`] could not pull a scalar result out of a backend
/// response.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ExtractError {
    /// A `format: json` response body was not valid JSON.
    InvalidJson(String),
    /// The JSON response had no `result_field` (or was not a JSON object).
    MissingResultField(String),
    /// The `result_field` held a non-scalar (array / object / null) value that
    /// cannot be rendered to a single result string.
    NonScalarResult(String),
}

impl fmt::Display for ExtractError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ExtractError::InvalidJson(detail) => {
                write!(f, "backend response was not valid JSON: {detail}")
            }
            ExtractError::MissingResultField(field) => {
                write!(f, "backend JSON response had no `{field}` field")
            }
            ExtractError::NonScalarResult(field) => write!(
                f,
                "backend JSON `{field}` field was not a string, number, or bool"
            ),
        }
    }
}

impl std::error::Error for ExtractError {}

/// Extract the final result string from a backend's raw output.
///
/// - [`ModelFormat::Text`]: the whole stdout is the result, with trailing
///   newlines stripped (the shell `$(…)` command-substitution convention).
/// - [`ModelFormat::Json`]: parse the output as JSON and read `result_field`
///   (defaulting to [`DEFAULT_RESULT_FIELD`]). A JSON string is used verbatim; a
///   number or bool is stringified (so a coercion's `{"result": 5}` yields `"5"`
///   for the type layer to parse). Arrays / objects / null are an error.
///
/// Shared by the `command` and `anthropic_messages` backends (bd-f5e007 /
/// bd-d1a328), which produce the raw output this parses.
///
/// # Errors
/// Returns [`ExtractError`] when a JSON response is malformed, lacks the result
/// field, or holds a non-scalar result.
pub fn extract_result(
    raw: &str,
    format: ModelFormat,
    result_field: Option<&str>,
) -> Result<String, ExtractError> {
    match format {
        ModelFormat::Text => Ok(raw.trim_end_matches(['\n', '\r']).to_owned()),
        ModelFormat::Json => {
            let field = result_field.unwrap_or(DEFAULT_RESULT_FIELD);
            let json: serde_json::Value = serde_json::from_str(raw.trim())
                .map_err(|error| ExtractError::InvalidJson(error.to_string()))?;
            let value = json
                .get(field)
                .ok_or_else(|| ExtractError::MissingResultField(field.to_owned()))?;
            match value {
                serde_json::Value::String(s) => Ok(s.clone()),
                serde_json::Value::Number(n) => Ok(n.to_string()),
                serde_json::Value::Bool(b) => Ok(b.to_string()),
                _ => Err(ExtractError::NonScalarResult(field.to_owned())),
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::{ModelConfig, ModelKind};

    /// A config with two model backends and `defaults.model = haiku`.
    fn config_with_models() -> Config {
        let mut config = Config::default();
        config.defaults.model = Some("haiku".to_owned());
        config.models.insert(
            "haiku".to_owned(),
            ModelConfig {
                model: Some("claude-haiku-4-5".to_owned()),
                ..ModelConfig::default()
            },
        );
        config.models.insert(
            "sonnet".to_owned(),
            ModelConfig {
                kind: ModelKind::Command,
                ..ModelConfig::default()
            },
        );
        config
    }

    #[test]
    fn operator_model_wins_over_cli_and_defaults() {
        let config = config_with_models();
        let (alias, model) =
            resolve_model(&config, Some("sonnet"), Some("haiku")).expect("operator alias resolves");
        assert_eq!(alias, "sonnet");
        assert_eq!(model.kind, ModelKind::Command);
    }

    #[test]
    fn cli_model_overrides_defaults_when_operator_unset() {
        let config = config_with_models();
        let (alias, _) =
            resolve_model(&config, None, Some("sonnet")).expect("cli override resolves");
        assert_eq!(alias, "sonnet");
    }

    #[test]
    fn defaults_model_used_when_operator_and_cli_unset() {
        let config = config_with_models();
        let (alias, model) = resolve_model(&config, None, None).expect("defaults.model resolves");
        assert_eq!(alias, "haiku");
        assert_eq!(model.model.as_deref(), Some("claude-haiku-4-5"));
    }

    #[test]
    fn no_model_anywhere_is_an_error() {
        let mut config = config_with_models();
        config.defaults.model = None;
        assert_eq!(
            resolve_model(&config, None, None),
            Err(ModelResolveError::NoModel)
        );
    }

    #[test]
    fn unknown_alias_is_an_error() {
        let config = config_with_models();
        assert_eq!(
            resolve_model(&config, Some("gpt-9"), None),
            Err(ModelResolveError::UnknownModel("gpt-9".to_owned()))
        );
        // An unknown alias sourced from the CLI override errors the same way.
        assert_eq!(
            resolve_model(&config, None, Some("gpt-9")),
            Err(ModelResolveError::UnknownModel("gpt-9".to_owned()))
        );
    }

    #[test]
    fn error_messages_name_the_problem() {
        assert!(
            ModelResolveError::NoModel
                .to_string()
                .contains("no model configured")
        );
        assert!(
            ModelResolveError::UnknownModel("x".to_owned())
                .to_string()
                .contains("unknown model `x`")
        );
    }

    // --- result extraction (bd-275d8b) ---

    #[test]
    fn text_format_returns_stdout_without_trailing_newlines() {
        assert_eq!(
            extract_result("hello\n", ModelFormat::Text, None),
            Ok("hello".to_owned())
        );
        // Multiple trailing newlines are stripped; internal text is preserved.
        assert_eq!(
            extract_result("a b\nc\n\n", ModelFormat::Text, None),
            Ok("a b\nc".to_owned())
        );
        // No trailing newline: verbatim.
        assert_eq!(
            extract_result("x y z", ModelFormat::Text, None),
            Ok("x y z".to_owned())
        );
    }

    #[test]
    fn json_format_reads_the_default_result_field() {
        assert_eq!(
            extract_result(r#"{"result": "hi there"}"#, ModelFormat::Json, None),
            Ok("hi there".to_owned())
        );
        // Surrounding whitespace around the JSON body is tolerated.
        assert_eq!(
            extract_result("  {\"result\":\"ok\"}\n", ModelFormat::Json, None),
            Ok("ok".to_owned())
        );
    }

    #[test]
    fn json_format_honours_a_custom_result_field() {
        assert_eq!(
            extract_result(r#"{"answer": "42"}"#, ModelFormat::Json, Some("answer")),
            Ok("42".to_owned())
        );
    }

    #[test]
    fn json_number_and_bool_results_stringify() {
        // A coercion's {result: T} with a number/bool becomes a string for the
        // type layer to parse.
        assert_eq!(
            extract_result(r#"{"result": 5}"#, ModelFormat::Json, None),
            Ok("5".to_owned())
        );
        assert_eq!(
            extract_result(r#"{"result": true}"#, ModelFormat::Json, None),
            Ok("true".to_owned())
        );
    }

    #[test]
    fn json_extraction_errors_are_loud() {
        // Not valid JSON.
        assert!(matches!(
            extract_result("not json", ModelFormat::Json, None),
            Err(ExtractError::InvalidJson(_))
        ));
        // Missing the result field.
        assert_eq!(
            extract_result(r#"{"other": "x"}"#, ModelFormat::Json, None),
            Err(ExtractError::MissingResultField("result".to_owned()))
        );
        // Non-scalar result value.
        assert_eq!(
            extract_result(r#"{"result": [1, 2]}"#, ModelFormat::Json, None),
            Err(ExtractError::NonScalarResult("result".to_owned()))
        );
        assert_eq!(
            extract_result(r#"{"result": null}"#, ModelFormat::Json, None),
            Err(ExtractError::NonScalarResult("result".to_owned()))
        );
    }

    #[test]
    fn extract_error_messages_name_the_problem() {
        assert!(
            ExtractError::MissingResultField("result".to_owned())
                .to_string()
                .contains("no `result` field")
        );
        assert!(
            ExtractError::InvalidJson("eof".to_owned())
                .to_string()
                .contains("not valid JSON")
        );
    }
}
