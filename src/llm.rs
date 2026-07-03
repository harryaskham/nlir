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
use std::process::Command;

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

/// The shell used to run `type: command` backends. The SPEC command examples use
/// bash features (`${NLIR_ARGS[0]}` array indexing, `$((…))`), so command
/// realisations run under bash rather than POSIX `sh`.
const COMMAND_SHELL: &str = "bash";

/// Why [`run_command_backend`] failed.
#[derive(Debug)]
pub enum CommandError {
    /// The model is a `type: command` backend but carries no `command:`.
    NoCommand,
    /// The backend shell subprocess could not be spawned (e.g. no `bash`).
    Spawn(std::io::Error),
    /// The subprocess ran but exited non-zero.
    NonZeroExit {
        /// Exit status code, when the process exited normally.
        code: Option<i32>,
        /// Captured standard error (trimmed), for diagnostics.
        stderr: String,
    },
    /// The subprocess succeeded but its output could not be parsed
    /// ([`extract_result`]).
    Extract(ExtractError),
}

impl fmt::Display for CommandError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CommandError::NoCommand => f.write_str("command backend has no `command:` to run"),
            CommandError::Spawn(error) => {
                write!(f, "failed to spawn command backend shell: {error}")
            }
            CommandError::NonZeroExit { code, stderr } => {
                let code = code.map_or_else(|| "signal".to_owned(), |c| c.to_string());
                if stderr.is_empty() {
                    write!(f, "command backend exited with status {code}")
                } else {
                    write!(f, "command backend exited with status {code}: {stderr}")
                }
            }
            CommandError::Extract(error) => write!(f, "command backend output: {error}"),
        }
    }
}

impl std::error::Error for CommandError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            CommandError::Spawn(error) => Some(error),
            CommandError::Extract(error) => Some(error),
            _ => None,
        }
    }
}

impl From<ExtractError> for CommandError {
    fn from(error: ExtractError) -> Self {
        CommandError::Extract(error)
    }
}

/// Run a `type: command` model backend.
///
/// Executes the model's `command:` template under bash with `env` exported (the
/// assembled `${NLIR_*}` prompt variables), then extracts the result per the
/// model's `format` (json `result_field` or raw text). The parent process
/// environment is inherited so the command can find its tools and credentials,
/// and `env` is layered on top.
///
/// Prompt / `${NLIR_*}` assembly is the caller's job (bd-e9983b); this backend
/// only runs the assembled command and extracts the result.
///
/// # Errors
/// - [`CommandError::NoCommand`] when the model has no `command:`.
/// - [`CommandError::Spawn`] when the backend shell cannot be launched.
/// - [`CommandError::NonZeroExit`] when the command exits non-zero.
/// - [`CommandError::Extract`] when the output cannot be parsed.
pub fn run_command_backend(
    model: &ModelConfig,
    env: &[(&str, &str)],
) -> Result<String, CommandError> {
    let command = model.command.as_deref().ok_or(CommandError::NoCommand)?;
    let output = Command::new(COMMAND_SHELL)
        .arg("-c")
        .arg(command)
        .envs(env.iter().copied())
        .output()
        .map_err(CommandError::Spawn)?;
    if !output.status.success() {
        return Err(CommandError::NonZeroExit {
            code: output.status.code(),
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_owned(),
        });
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    extract_result(&stdout, model.format, model.result_field.as_deref())
        .map_err(CommandError::Extract)
}

/// Fill an LLM prompt template's `%` placeholder(s) with the operand text(s)
/// (SPEC §Prompt templating). `%%` is a literal `%`; a lone `%` expands to the
/// operand block:
/// - a single operand → `<text>OPERAND</text>`;
/// - multiple operands → one `<text n=k>OPERAND_k</text>` per operand
///   (0-indexed), joined with newlines;
/// - no operands → the empty string.
///
/// Operand text is inserted verbatim (the model is instructed to ignore the
/// `<text>` tags via the `system` prompt fragment). Every lone `%` in the
/// template expands to the same operand block.
#[must_use]
pub fn substitute_operands(template: &str, operands: &[String]) -> String {
    let block = operand_block(operands);
    let mut out = String::with_capacity(template.len());
    let mut chars = template.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '%' {
            if chars.peek() == Some(&'%') {
                chars.next();
                out.push('%');
            } else {
                out.push_str(&block);
            }
        } else {
            out.push(c);
        }
    }
    out
}

/// Render the operand block a lone `%` expands to (see [`substitute_operands`]).
fn operand_block(operands: &[String]) -> String {
    match operands {
        [] => String::new(),
        [single] => format!("<text>{single}</text>"),
        many => many
            .iter()
            .enumerate()
            .map(|(k, operand)| format!("<text n={k}>{operand}</text>"))
            .collect::<Vec<_>>()
            .join("\n"),
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

    // --- command backend (bd-f5e007) ---

    fn command_model(command: &str, format: ModelFormat) -> ModelConfig {
        ModelConfig {
            kind: ModelKind::Command,
            format,
            command: Some(command.to_owned()),
            ..ModelConfig::default()
        }
    }

    #[test]
    fn command_text_backend_returns_stdout() {
        let model = command_model("printf 'hello world'", ModelFormat::Text);
        assert_eq!(run_command_backend(&model, &[]).unwrap(), "hello world");
    }

    #[test]
    fn command_json_backend_extracts_result_field() {
        let model = command_model(r#"printf '{"result":"hi"}'"#, ModelFormat::Json);
        assert_eq!(run_command_backend(&model, &[]).unwrap(), "hi");

        let mut custom = command_model(r#"printf '{"answer":"42"}'"#, ModelFormat::Json);
        custom.result_field = Some("answer".to_owned());
        assert_eq!(run_command_backend(&custom, &[]).unwrap(), "42");
    }

    #[test]
    fn command_backend_exports_env_vars() {
        // The assembled ${NLIR_*} vars reach the command via the environment.
        let model = command_model(r#"printf '%s' "$NLIR_PROMPT""#, ModelFormat::Text);
        assert_eq!(
            run_command_backend(&model, &[("NLIR_PROMPT", "hey there")]).unwrap(),
            "hey there"
        );
    }

    #[test]
    fn command_backend_non_zero_exit_is_an_error() {
        let model = command_model("printf 'boom' >&2; exit 3", ModelFormat::Text);
        match run_command_backend(&model, &[]) {
            Err(CommandError::NonZeroExit { code, stderr }) => {
                assert_eq!(code, Some(3));
                assert_eq!(stderr, "boom");
            }
            other => panic!("expected NonZeroExit, got {other:?}"),
        }
    }

    #[test]
    fn command_backend_missing_command_is_an_error() {
        let model = ModelConfig {
            kind: ModelKind::Command,
            ..ModelConfig::default()
        };
        assert!(matches!(
            run_command_backend(&model, &[]),
            Err(CommandError::NoCommand)
        ));
    }

    #[test]
    fn command_backend_unparseable_output_is_an_extract_error() {
        let model = command_model("printf 'not json'", ModelFormat::Json);
        assert!(matches!(
            run_command_backend(&model, &[]),
            Err(CommandError::Extract(ExtractError::InvalidJson(_)))
        ));
    }

    // --- % operand substitution (bd-a47a02) ---

    #[test]
    fn percent_double_is_a_literal_percent() {
        assert_eq!(
            substitute_operands("100%% done", &["x".to_owned()]),
            "100% done"
        );
    }

    #[test]
    fn single_operand_wraps_in_bare_text_tag() {
        assert_eq!(
            substitute_operands("do it:\n\n%", &["hello world".to_owned()]),
            "do it:\n\n<text>hello world</text>"
        );
    }

    #[test]
    fn multiple_operands_use_indexed_text_tags() {
        assert_eq!(
            substitute_operands("%", &["a".to_owned(), "b".to_owned(), "c".to_owned()]),
            "<text n=0>a</text>\n<text n=1>b</text>\n<text n=2>c</text>"
        );
    }

    #[test]
    fn no_operands_expand_to_empty() {
        assert_eq!(substitute_operands("x%y", &[]), "xy");
    }

    #[test]
    fn every_lone_percent_expands_and_double_is_preserved() {
        // Mixed literal `%%` and two expanding `%`.
        assert_eq!(
            substitute_operands("50%% of %|%", &["z".to_owned()]),
            "50% of <text>z</text>|<text>z</text>"
        );
    }

    #[test]
    fn operand_text_is_inserted_verbatim() {
        // No XML-escaping: the operand is placed inside the tags as-is.
        assert_eq!(
            substitute_operands("%", &["a<b>&c".to_owned()]),
            "<text>a<b>&c</text>"
        );
    }
}
