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

use std::collections::{BTreeMap, HashMap};
use std::fmt;
use std::process::Command;

use crate::config::{Config, ModelConfig, ModelFormat, ModelKind, PromptDef, TypeName};
use crate::value::{CoerceError, Value};

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
        ModelFormat::Text => Ok(strip_text_tags(raw).trim().to_owned()),
        ModelFormat::Json => {
            let field = result_field.unwrap_or(DEFAULT_RESULT_FIELD);
            let json: serde_json::Value = serde_json::from_str(raw.trim())
                .map_err(|error| ExtractError::InvalidJson(error.to_string()))?;
            let value = json
                .get(field)
                .ok_or_else(|| ExtractError::MissingResultField(field.to_owned()))?;
            match value {
                serde_json::Value::String(s) => Ok(strip_text_tags(s)),
                serde_json::Value::Number(n) => Ok(n.to_string()),
                serde_json::Value::Bool(b) => Ok(b.to_string()),
                _ => Err(ExtractError::NonScalarResult(field.to_owned())),
            }
        }
    }
}

/// Strip an outer `<text>…</text>` / `<text n=k>…</text>` delimiter wrapper a model echoed.
///
/// nlir wraps each operand in `<text>…</text>` as the *input* delimiter (see
/// [`substitute_operands`]), and the `system` prompt instructs the model to omit them from
/// its output — but models intermittently echo them anyway (bd-b1d501): e.g. `!'love'` comes
/// back as `<text>hate</text>`, which then leaks through an `&`/list join as
/// `"love and <text>hate</text>"`.
///
/// This runs at the per-call output seam (before any join), where a leaked wrapper is always
/// the WHOLE response, so it strips only an OUTER wrapper: a trimmed value that both opens with
/// a `<text>`/`<text n=DIGITS>` tag and ends with `</text>`. Mid-string `<text>` (e.g. a model
/// that echoes a prompt fragment) and look-alikes such as `<textarea>` are deliberately left
/// untouched — no false positives.
fn strip_text_tags(s: &str) -> String {
    let trimmed = s.trim();
    if let Some(open_len) = text_open_tag_len(trimmed) {
        if let Some(inner) = trimmed[open_len..].strip_suffix("</text>") {
            return inner.trim().to_owned();
        }
    }
    s.to_owned()
}

/// If `s` begins with a `<text>` or `<text n=DIGITS>` open tag, return its byte length.
fn text_open_tag_len(s: &str) -> Option<usize> {
    let body = s.strip_prefix("<text")?;
    if body.starts_with('>') {
        return Some("<text>".len());
    }
    let after_marker = body.strip_prefix(" n=")?;
    let digits = after_marker
        .chars()
        .take_while(char::is_ascii_digit)
        .count();
    if digits == 0 || !after_marker[digits..].starts_with('>') {
        return None;
    }
    Some("<text n=".len() + digits + ">".len())
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

/// Resolve the configured `prompts:` fragments into `name -> text` environment
/// variables (SPEC §Example config `prompts:`).
///
/// Each fragment names an env var (`env:`) and carries literal `text:`. A
/// fragment is exported under its `env:` name; the value is the process
/// environment's value for that name when set (an operator/script override),
/// otherwise the fragment's `text:` (or the empty string when neither is
/// present). Fragments without an `env:` name are skipped — there is no
/// `${NLIR_*}` handle to reference them by.
///
/// `lookup` resolves an env var name to its current value, mirroring the config
/// env-interpolation surface (and kept injectable for hermetic tests).
pub fn resolve_prompt_fragments(
    prompts: &BTreeMap<String, PromptDef>,
    lookup: impl Fn(&str) -> Option<String>,
) -> BTreeMap<String, String> {
    let mut vars = BTreeMap::new();
    for def in prompts.values() {
        let Some(env_name) = def.env.as_deref() else {
            continue;
        };
        let value = lookup(env_name)
            .or_else(|| def.text.clone())
            .unwrap_or_default();
        vars.insert(env_name.to_owned(), value);
    }
    vars
}

/// The env var carrying the `%`-filled operator/coercion prompt.
pub const NLIR_PROMPT_VAR: &str = "NLIR_PROMPT";

/// The bash array variable carrying the raw operands for `command` backends.
pub const NLIR_ARGS_VAR: &str = "NLIR_ARGS";

/// Assemble the scalar `${NLIR_*}` variable set for a realisation: the resolved
/// prompt `fragments` (bd-b9a977) plus [`NLIR_PROMPT_VAR`] set to the
/// `%`-filled prompt (bd-a47a02).
///
/// This is the variable environment the model's message / command templates
/// reference as `${NLIR_SYSTEM_PROMPT}`, `${NLIR_PROMPT}`, etc.
#[must_use]
pub fn assemble_nlir_vars(
    filled_prompt: &str,
    fragments: &BTreeMap<String, String>,
) -> BTreeMap<String, String> {
    let mut vars = fragments.clone();
    vars.insert(NLIR_PROMPT_VAR.to_owned(), filled_prompt.to_owned());
    vars
}

/// Substitute `${NAME}` references in a template with values from `vars`.
///
/// Used for the `anthropic_messages` backend, whose message templates are sent
/// over HTTP (not run through a shell), so `${NLIR_*}` must be expanded here. A
/// reference to a name not in `vars` is left literal (rather than emptied), and a
/// `${` with no closing `}` is emitted verbatim.
///
/// `command` backends do not use this: they run under bash, which expands
/// `${NLIR_*}` (including the `${NLIR_ARGS[k]}` array form) itself.
#[must_use]
pub fn substitute_nlir_vars(template: &str, vars: &BTreeMap<String, String>) -> String {
    let mut out = String::with_capacity(template.len());
    let mut rest = template;
    while let Some(idx) = rest.find("${") {
        out.push_str(&rest[..idx]);
        let after = &rest[idx + 2..];
        if let Some(end) = after.find('}') {
            let name = &after[..end];
            if let Some(value) = vars.get(name) {
                out.push_str(value);
            } else {
                // Unknown variable: leave the reference literal.
                out.push_str("${");
                out.push_str(name);
                out.push('}');
            }
            rest = &after[end + 1..];
        } else {
            // No closing brace: emit the remainder verbatim.
            out.push_str("${");
            rest = after;
        }
    }
    out.push_str(rest);
    out
}

/// Build the bash `NLIR_ARGS=(…)` array declaration for a `command` backend, so
/// its command can index operands as `${NLIR_ARGS[0]}` etc. (SPEC `echo`
/// operator). Operands are single-quoted for the shell; the declaration is meant
/// to be prepended to the command before it runs under bash.
#[must_use]
pub fn nlir_args_declaration(operands: &[String]) -> String {
    let quoted: Vec<String> = operands.iter().map(|o| shell_single_quote(o)).collect();
    format!("{NLIR_ARGS_VAR}=({})", quoted.join(" "))
}

/// Single-quote a string for safe use inside a bash command, escaping embedded
/// single quotes via the `'\''` idiom.
fn shell_single_quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', r"'\''"))
}

/// Anthropic Messages API version header value.
pub const ANTHROPIC_VERSION: &str = "2023-06-01";

/// Default `max_tokens` for an anthropic request when `output_config` does not
/// override it (the Anthropic Messages API requires the field).
const DEFAULT_MAX_TOKENS: u64 = 4096;

/// Why [`run_anthropic_backend`] failed.
#[derive(Debug)]
pub enum AnthropicError {
    /// The model config has no `base_url`.
    NoBaseUrl,
    /// The model config has no provider `model` id.
    NoModel,
    /// The HTTP request failed (transport error or non-2xx status).
    Http(String),
    /// The response envelope could not be parsed or carried no text content.
    BadResponse(String),
    /// The extracted model text could not be parsed ([`extract_result`]).
    Extract(ExtractError),
}

impl fmt::Display for AnthropicError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AnthropicError::NoBaseUrl => {
                f.write_str("anthropic_messages backend has no `base_url`")
            }
            AnthropicError::NoModel => {
                f.write_str("anthropic_messages backend has no provider `model` id")
            }
            AnthropicError::Http(detail) => write!(f, "anthropic request failed: {detail}"),
            AnthropicError::BadResponse(detail) => {
                write!(f, "anthropic response could not be read: {detail}")
            }
            AnthropicError::Extract(error) => write!(f, "anthropic response text: {error}"),
        }
    }
}

impl std::error::Error for AnthropicError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            AnthropicError::Extract(error) => Some(error),
            _ => None,
        }
    }
}

impl From<ExtractError> for AnthropicError {
    fn from(error: ExtractError) -> Self {
        AnthropicError::Extract(error)
    }
}

/// Run an `anthropic_messages` model backend.
///
/// Builds the Messages API request from the model config and the assembled
/// `${NLIR_*}` `vars` (substituted into the message templates), POSTs it to
/// `{base_url}/messages` with the `x-api-key` / `anthropic-version` headers, then
/// pulls the assistant text out of the response and extracts the result per the
/// model's `format` (json `result_field` / text).
///
/// Provider-specific request fields (structured-output schema, `max_tokens`
/// overrides, …) are supplied by the model's `output_config`, which is merged
/// into the request body — so the config author owns the exact API shape while
/// this backend owns the mechanics.
///
/// # Errors
/// - [`AnthropicError::NoBaseUrl`] / [`AnthropicError::NoModel`] on missing config.
/// - [`AnthropicError::Http`] on a transport error or non-2xx status.
/// - [`AnthropicError::BadResponse`] when the response has no readable text.
/// - [`AnthropicError::Extract`] when the text cannot be parsed.
pub fn run_anthropic_backend(
    model: &ModelConfig,
    vars: &BTreeMap<String, String>,
) -> Result<String, AnthropicError> {
    let base_url = model.base_url.as_deref().ok_or(AnthropicError::NoBaseUrl)?;
    let model_id = model.model.as_deref().ok_or(AnthropicError::NoModel)?;
    let body = build_anthropic_request(model, model_id, vars);
    let url = format!("{}/messages", base_url.trim_end_matches('/'));

    let mut request = ureq::post(&url)
        .set("anthropic-version", ANTHROPIC_VERSION)
        .set("content-type", "application/json");
    if let Some(key) = model.api_key.as_deref() {
        request = request.set("x-api-key", key);
    }

    let response = match request.send_json(body) {
        Ok(response) => response,
        Err(ureq::Error::Status(code, response)) => {
            let detail = response.into_string().unwrap_or_default();
            return Err(AnthropicError::Http(format!("status {code}: {detail}")));
        }
        Err(error) => return Err(AnthropicError::Http(error.to_string())),
    };

    let envelope: serde_json::Value = response
        .into_json()
        .map_err(|error| AnthropicError::BadResponse(error.to_string()))?;
    let text = anthropic_text(&envelope).ok_or_else(|| {
        AnthropicError::BadResponse("response carried no text content".to_owned())
    })?;
    extract_result(&text, model.format, model.result_field.as_deref())
        .map_err(AnthropicError::Extract)
}

/// Build the Anthropic Messages API request body from the model config.
///
/// `role: system` messages are hoisted into the top-level `system` field (as the
/// Anthropic API expects), the rest form the `messages` array, and each content
/// string has its `${NLIR_*}` references substituted. `output_config`'s top-level
/// object keys are merged in last, so config can supply/override any field.
fn build_anthropic_request(
    model: &ModelConfig,
    model_id: &str,
    vars: &BTreeMap<String, String>,
) -> serde_json::Value {
    let mut system = String::new();
    let mut messages = Vec::new();
    for message in &model.messages {
        let content = substitute_nlir_vars(&message.content, vars);
        if message.role == "system" {
            if !system.is_empty() {
                system.push('\n');
            }
            system.push_str(&content);
        } else {
            messages.push(serde_json::json!({ "role": message.role, "content": content }));
        }
    }

    let mut body = serde_json::json!({
        "model": model_id,
        "max_tokens": DEFAULT_MAX_TOKENS,
        "messages": messages,
    });
    if !system.is_empty() {
        body["system"] = serde_json::Value::String(system);
    }
    if let (Some(serde_json::Value::Object(extra)), serde_json::Value::Object(target)) =
        (&model.output_config, &mut body)
    {
        for (key, value) in extra {
            target.insert(key.clone(), value.clone());
        }
    }
    body
}

/// Concatenate the `text` of every text block in an Anthropic response's
/// `content` array. Returns `None` when there is no text content.
fn anthropic_text(envelope: &serde_json::Value) -> Option<String> {
    let content = envelope.get("content")?.as_array()?;
    let mut text = String::new();
    for block in content {
        if let Some(part) = block.get("text").and_then(serde_json::Value::as_str) {
            text.push_str(part);
        }
    }
    (!text.is_empty()).then_some(text)
}

/// Why [`coerce_with_llm`] failed.
#[derive(Debug)]
pub enum LlmCoerceError {
    /// A deterministic-layer error that the LLM path does not recover, i.e.
    /// `list → number` (SPEC: always an error).
    Coerce(CoerceError),
    /// No `types:` coercion config exists for the target type.
    NoCoercionConfig(TypeName),
    /// The coercion model could not be resolved.
    Model(ModelResolveError),
    /// The `command` backend failed.
    Command(CommandError),
    /// The `anthropic_messages` backend failed.
    Anthropic(AnthropicError),
    /// The LLM returned text that is not a valid value of the target type.
    UnparseableResult {
        /// The type the value was being coerced to.
        target: TypeName,
        /// The raw text the model returned.
        raw: String,
    },
}

impl fmt::Display for LlmCoerceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            LlmCoerceError::Coerce(error) => write!(f, "{error}"),
            LlmCoerceError::NoCoercionConfig(target) => {
                write!(f, "no `types:` coercion config for {target}")
            }
            LlmCoerceError::Model(error) => write!(f, "coercion model: {error}"),
            LlmCoerceError::Command(error) => write!(f, "coercion via command backend: {error}"),
            LlmCoerceError::Anthropic(error) => {
                write!(f, "coercion via anthropic backend: {error}")
            }
            LlmCoerceError::UnparseableResult { target, raw } => write!(
                f,
                "LLM coercion to {target} returned an invalid value: {raw:?}"
            ),
        }
    }
}

impl std::error::Error for LlmCoerceError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            LlmCoerceError::Coerce(error) => Some(error),
            LlmCoerceError::Model(error) => Some(error),
            LlmCoerceError::Command(error) => Some(error),
            LlmCoerceError::Anthropic(error) => Some(error),
            _ => None,
        }
    }
}

/// Coerce a value to `target` using the `llm`-mode fallback (SPEC §Types &
/// coercion): deterministic parses first, then — when none apply and the
/// conversion is not the always-invalid `list → number` — the configured per-type
/// LLM coercion (`types:` model + prompt + `{result: T}` schema), whose textual
/// result is parsed back into a typed [`Value`].
///
/// This is the `llm`-mode coercion entry point; `det` mode uses the
/// deterministic-only [`Value::coerce`]. `env_lookup` resolves `${NLIR_*}`
/// prompt-fragment overrides; `cli_model` is the optional `--model` override
/// applied when resolving the coercion model.
///
/// # Errors
/// See [`LlmCoerceError`].
pub fn coerce_with_llm(
    value: &Value,
    target: TypeName,
    config: &Config,
    sep: &str,
    env_lookup: impl Fn(&str) -> Option<String>,
    cli_model: Option<&str>,
) -> Result<Value, LlmCoerceError> {
    // 1. Deterministic coercion (SPEC steps 1–2).
    if let Some(coerced) = value.coerce_deterministic(target, sep) {
        return Ok(coerced);
    }
    // 2. `list → number` is always an error and is never routed to the LLM.
    if matches!((value, target), (Value::List(_), TypeName::Number)) {
        return Err(LlmCoerceError::Coerce(CoerceError::list_to_number(
            value, sep,
        )));
    }
    // 3. Per-type LLM coercion from `types:`.
    let coercion = config
        .types
        .get(target.as_str())
        .ok_or(LlmCoerceError::NoCoercionConfig(target))?;
    let (_, model) = resolve_model(config, coercion.model.as_deref(), cli_model)
        .map_err(LlmCoerceError::Model)?;
    let filled = substitute_operands(
        coercion.prompt.as_deref().unwrap_or_default(),
        &[value.render(sep)],
    );
    let fragments = resolve_prompt_fragments(&config.prompts, &env_lookup);
    let vars = assemble_nlir_vars(&filled, &fragments);
    let raw = call_coercion_backend(model, &vars)?;
    // 4. Parse the model's textual result into the target type.
    Value::String(raw.clone())
        .coerce_deterministic(target, sep)
        .ok_or(LlmCoerceError::UnparseableResult { target, raw })
}

/// Dispatch a coercion call to the resolved model's backend.
fn call_coercion_backend(
    model: &ModelConfig,
    vars: &BTreeMap<String, String>,
) -> Result<String, LlmCoerceError> {
    match model.kind {
        ModelKind::Command => {
            let env: Vec<(&str, &str)> =
                vars.iter().map(|(k, v)| (k.as_str(), v.as_str())).collect();
            run_command_backend(model, &env).map_err(LlmCoerceError::Command)
        }
        ModelKind::AnthropicMessages => {
            run_anthropic_backend(model, vars).map_err(LlmCoerceError::Anthropic)
        }
    }
}

/// A memoization cache for `llm`-mode coercions (SPEC §Caching): identical
/// coercions are deduped keyed on `(text, target-type, model)` when `_cache` is
/// enabled (default). A deterministic coercion is cheap but still served from a
/// cache hit (its result is stable), so a caller can route every `llm`-mode
/// coercion through one path.
#[derive(Debug, Default)]
pub struct CoercionCache {
    enabled: bool,
    entries: HashMap<(String, String, String), Value>,
}

impl CoercionCache {
    /// Create a cache. `enabled` mirrors the `_cache` context key (default true);
    /// when false, [`CoercionCache::coerce`] neither stores nor serves cached
    /// results and simply delegates to [`coerce_with_llm`].
    #[must_use]
    pub fn new(enabled: bool) -> Self {
        Self {
            enabled,
            entries: HashMap::new(),
        }
    }

    /// Number of cached coercion results.
    #[must_use]
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Whether the cache holds no entries.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Coerce `value` to `target`, serving or storing the result in the cache
    /// when enabled. See [`coerce_with_llm`] for the coercion semantics; a hit
    /// returns the previously computed value without re-invoking the model.
    ///
    /// # Errors
    /// Propagates [`LlmCoerceError`]; failures are never cached.
    pub fn coerce(
        &mut self,
        value: &Value,
        target: TypeName,
        config: &Config,
        sep: &str,
        env_lookup: impl Fn(&str) -> Option<String>,
        cli_model: Option<&str>,
    ) -> Result<Value, LlmCoerceError> {
        if !self.enabled {
            return coerce_with_llm(value, target, config, sep, env_lookup, cli_model);
        }
        let key = (
            value.render(sep),
            target.as_str().to_owned(),
            coercion_model_key(config, target, cli_model),
        );
        if let Some(cached) = self.entries.get(&key) {
            return Ok(cached.clone());
        }
        let result = coerce_with_llm(value, target, config, sep, env_lookup, cli_model)?;
        self.entries.insert(key, result.clone());
        Ok(result)
    }
}

/// The model alias identifying a coercion in the cache key, matching
/// [`resolve_model`]'s precedence for a coercion: the per-type `types:` model,
/// else the `--model` override, else `defaults.model`.
fn coercion_model_key(config: &Config, target: TypeName, cli_model: Option<&str>) -> String {
    config
        .types
        .get(target.as_str())
        .and_then(|coercion| coercion.model.clone())
        .or_else(|| cli_model.map(str::to_owned))
        .or_else(|| config.defaults.model.clone())
        .unwrap_or_default()
}

/// Why [`realise_llm`] failed.
#[derive(Debug)]
pub enum RealiseError {
    /// The realisation model could not be resolved.
    Model(ModelResolveError),
    /// The `command` model backend failed.
    Command(CommandError),
    /// The `anthropic_messages` backend failed.
    Anthropic(AnthropicError),
    /// An operator `command:` snippet failed to spawn or exited non-zero.
    OperatorCommand(String),
}

impl fmt::Display for RealiseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RealiseError::Model(error) => write!(f, "realisation model: {error}"),
            RealiseError::Command(error) => write!(f, "realisation via command backend: {error}"),
            RealiseError::Anthropic(error) => {
                write!(f, "realisation via anthropic backend: {error}")
            }
            RealiseError::OperatorCommand(message) => {
                write!(f, "realisation via operator command: {message}")
            }
        }
    }
}

impl std::error::Error for RealiseError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            RealiseError::Model(error) => Some(error),
            RealiseError::Command(error) => Some(error),
            RealiseError::Anthropic(error) => Some(error),
            RealiseError::OperatorCommand(_) => None,
        }
    }
}

/// Realise an `llm`-mode operator: resolve its model, assemble the prompt from
/// `prompt_template` + `operands`, call the resolved backend, and return the
/// extracted result text. This is the single seam the evaluator's `Mode::Llm`
/// realisation calls; it composes the whole LLM pipeline
/// ([`resolve_model`] → [`substitute_operands`] → [`resolve_prompt_fragments`] →
/// [`assemble_nlir_vars`] → backend → [`extract_result`]).
///
/// `model_alias` is the operator's `model:` (or `None` to fall back to
/// `cli_model` then `defaults.model` via [`resolve_model`]'s precedence).
/// `env_lookup` resolves `${NLIR_*}` prompt-fragment overrides.
///
/// For a `command` backend the operator's `command:` is prefixed with the
/// [`nlir_args_declaration`] bash array so it can index `${NLIR_ARGS[k]}`; for an
/// `anthropic_messages` backend the `${NLIR_*}` vars are substituted into the
/// message templates. The result is returned as a raw `String` (the caller wraps
/// it in a [`Value`]).
///
/// # Errors
/// See [`RealiseError`].
/// Assemble (but do NOT send) the llm request for `--dry-run` previews
/// (bd-256baa): resolve the model and fill the prompt / NLIR_* vars exactly as
/// [`realise_llm`] does, then render a human-readable view of the model and the
/// prompt / messages that WOULD be sent. Makes no network or subprocess call.
///
/// # Errors
/// Returns [`RealiseError`] if the model cannot be resolved.
pub fn realise_llm_preview(
    model_alias: Option<&str>,
    prompt_template: &str,
    operands: &[String],
    config: &Config,
    cli_model: Option<&str>,
    env_lookup: impl Fn(&str) -> Option<String>,
) -> Result<String, RealiseError> {
    let (name, model) =
        resolve_model(config, model_alias, cli_model).map_err(RealiseError::Model)?;
    let filled = substitute_operands(prompt_template, operands);
    let fragments = resolve_prompt_fragments(&config.prompts, &env_lookup);
    let vars = assemble_nlir_vars(&filled, &fragments);
    let mut out = String::new();
    match model.kind {
        ModelKind::Command => {
            out.push_str(&format!("model `{name}` (command)"));
            if let Some(prompt) = vars.get(NLIR_PROMPT_VAR) {
                out.push_str(&format!(
                    "\n    {NLIR_PROMPT_VAR}={}",
                    prompt.replace('\n', "\n      ")
                ));
            }
            if let Some(command) = model.command.as_deref() {
                out.push_str("\n    $ ");
                out.push_str(&command.replace('\n', "\n      "));
            }
        }
        ModelKind::AnthropicMessages => {
            let id = model.model.as_deref().unwrap_or("<no model id>");
            out.push_str(&format!("model `{name}` (anthropic_messages: {id})"));
            for message in &model.messages {
                let content = substitute_nlir_vars(&message.content, &vars);
                out.push_str(&format!(
                    "\n    [{}] {}",
                    message.role,
                    content.replace('\n', "\n      ")
                ));
            }
        }
    }
    Ok(out)
}

/// The assembled, backend-ready form of an llm-mode realisation: the resolved
/// [`ModelConfig`], the `NLIR_*` variable map (filled prompt + prompt
/// fragments), and the operand strings (for the `command` backend's
/// `NLIR_ARGS`). Produced by [`assemble_llm`] (pure — no I/O) and consumed by
/// [`run_llm`] (effectful). This split IS the realiser seam (bd-bec201): a host
/// (e.g. the WASM build) can run its OWN backend from an `LlmCall` (reading
/// `vars[NLIR_PROMPT]` + the model id) instead of the native HTTP/subprocess one.
#[derive(Debug, Clone)]
pub struct LlmCall {
    /// The resolved model backend (operator alias > cli override > defaults).
    pub model: ModelConfig,
    /// `NLIR_*` variables: the filled prompt (`NLIR_PROMPT`) plus fragments.
    pub vars: BTreeMap<String, String>,
    /// The rendered operand strings, for the `command` backend's `NLIR_ARGS`.
    pub operands: Vec<String>,
}

/// Assemble an llm realisation WITHOUT running any backend (pure): resolve the
/// model, fill the prompt from the operands, gather prompt fragments, and build
/// the `NLIR_*` vars. The effectful half is [`run_llm`].
///
/// # Errors
/// Returns [`RealiseError`] if the model cannot be resolved.
pub fn assemble_llm(
    model_alias: Option<&str>,
    prompt_template: &str,
    operands: &[String],
    config: &Config,
    cli_model: Option<&str>,
    env_lookup: impl Fn(&str) -> Option<String>,
) -> Result<LlmCall, RealiseError> {
    let (_, model) = resolve_model(config, model_alias, cli_model).map_err(RealiseError::Model)?;
    let filled = substitute_operands(prompt_template, operands);
    let fragments = resolve_prompt_fragments(&config.prompts, &env_lookup);
    let vars = assemble_nlir_vars(&filled, &fragments);
    Ok(LlmCall {
        model: model.clone(),
        vars,
        operands: operands.to_vec(),
    })
}

/// Run an assembled [`LlmCall`] against the NATIVE backend (effectful): the
/// `command` model kind shells out; `anthropic_messages` calls HTTP. This is the
/// native realiser body — behaviour is identical to the pre-split [`realise_llm`].
/// A WASM host supplies its own equivalent from the same [`LlmCall`].
///
/// # Errors
/// Returns [`RealiseError`] if the backend call fails.
pub fn run_llm(call: &LlmCall) -> Result<String, RealiseError> {
    match call.model.kind {
        ModelKind::Command => {
            let env: Vec<(&str, &str)> = call
                .vars
                .iter()
                .map(|(k, v)| (k.as_str(), v.as_str()))
                .collect();
            // Prepend the NLIR_ARGS bash array so command operators (e.g. the
            // SPEC `echo`) can index `${NLIR_ARGS[k]}`.
            let mut command_model = call.model.clone();
            if let Some(command) = command_model.command.as_deref() {
                command_model.command = Some(format!(
                    "{}\n{command}",
                    nlir_args_declaration(&call.operands)
                ));
            }
            run_command_backend(&command_model, &env).map_err(RealiseError::Command)
        }
        ModelKind::AnthropicMessages => {
            run_anthropic_backend(&call.model, &call.vars).map_err(RealiseError::Anthropic)
        }
    }
}

pub fn realise_llm(
    model_alias: Option<&str>,
    prompt_template: &str,
    operands: &[String],
    config: &Config,
    cli_model: Option<&str>,
    env_lookup: impl Fn(&str) -> Option<String>,
) -> Result<String, RealiseError> {
    let call = assemble_llm(
        model_alias,
        prompt_template,
        operands,
        config,
        cli_model,
        env_lookup,
    )?;
    run_llm(&call)
}

/// Run an operator `command:` snippet (effectful): prepend the `NLIR_ARGS` bash
/// array so the snippet can index `${NLIR_ARGS[k]}`, execute under `bash -c`,
/// and return stdout with a single trailing newline dropped (SPEC: stdout is the
/// result). The native realiser body for operator commands; a WASM host runs the
/// wasm-sh worker instead. `operands` are already rendered to strings.
///
/// # Errors
/// Returns [`RealiseError::OperatorCommand`] on spawn failure or a non-zero exit.
pub fn run_operator_command(command: &str, operands: &[String]) -> Result<String, RealiseError> {
    let script = format!("{}\n{command}", nlir_args_declaration(operands));
    let output = std::process::Command::new("bash")
        .arg("-c")
        .arg(&script)
        .output()
        .map_err(|error| RealiseError::OperatorCommand(format!("failed to spawn bash: {error}")))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(RealiseError::OperatorCommand(format!(
            "`{command}` exited with {}: {}",
            output.status,
            stderr.trim()
        )));
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    Ok(stdout.strip_suffix('\n').unwrap_or(&stdout).to_owned())
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
    fn realise_llm_preview_assembles_without_calling() {
        // The `--dry-run` preview resolves the model + assembles the prompt/
        // NLIR_* vars, making NO call (bd-256baa).
        let mut config = config_with_models();
        config.models.get_mut("sonnet").unwrap().command =
            Some("printf %s \"$NLIR_PROMPT\"".to_owned());
        let out = realise_llm_preview(
            Some("sonnet"),
            "Answer: %",
            &["foo".to_owned()],
            &config,
            None,
            |_| None,
        )
        .expect("preview assembles");
        assert!(out.contains("model `sonnet` (command)"), "out={out}");
        assert!(
            out.contains("Answer: <text>foo</text>"),
            "prompt not assembled: {out}"
        );
        assert!(out.contains("printf %s"), "command not shown: {out}");
    }

    #[test]
    fn realise_llm_preview_errors_when_model_unresolved() {
        let mut config = config_with_models();
        config.defaults.model = None;
        assert!(
            realise_llm_preview(None, "p: %", &["x".to_owned()], &config, None, |_| None).is_err()
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
    fn text_format_strips_echoed_text_delimiter_tags() {
        // bd-b1d501: the model intermittently echoes the <text> input-delimiter as an OUTER
        // wrapper around its whole answer; strip it at the per-call seam so it never leaks
        // through a later &/list join.
        assert_eq!(
            extract_result("<text>hate</text>", ModelFormat::Text, None),
            Ok("hate".to_owned())
        );
        // The numbered multi-operand form `<text n=k>`.
        assert_eq!(
            extract_result("<text n=0>a</text>", ModelFormat::Text, None),
            Ok("a".to_owned())
        );
        // Whitespace from a newline-wrapped echo is trimmed away.
        assert_eq!(
            extract_result("<text>\nok\n</text>", ModelFormat::Text, None),
            Ok("ok".to_owned())
        );
        // Only an OUTER wrapper is stripped: a mid-string tag (e.g. a prompt-echo fixture)
        // is left intact, so we never mangle genuine content around a stray tag.
        assert_eq!(
            extract_result("negate: <text>foo</text>", ModelFormat::Text, None),
            Ok("negate: <text>foo</text>".to_owned())
        );
        // Look-alikes in legitimate output are NOT stripped (no false positives).
        assert_eq!(
            extract_result("use a <textarea> element", ModelFormat::Text, None),
            Ok("use a <textarea> element".to_owned())
        );
        // Clean output is unchanged.
        assert_eq!(
            extract_result("just fine", ModelFormat::Text, None),
            Ok("just fine".to_owned())
        );
        // JSON string results are defended too.
        assert_eq!(
            extract_result(r#"{"result":"<text>done</text>"}"#, ModelFormat::Json, None),
            Ok("done".to_owned())
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

    // --- prompt fragments (bd-b9a977) ---

    fn prompt_def(env: Option<&str>, text: Option<&str>) -> PromptDef {
        PromptDef {
            env: env.map(str::to_owned),
            text: text.map(str::to_owned),
        }
    }

    #[test]
    fn prompt_fragments_export_env_named_text() {
        let mut prompts = BTreeMap::new();
        prompts.insert(
            "system".to_owned(),
            prompt_def(Some("NLIR_SYSTEM_PROMPT"), Some("sys text")),
        );
        prompts.insert(
            "structured".to_owned(),
            prompt_def(Some("NLIR_STRUCTURED_PROMPT"), Some("json only")),
        );
        let vars = resolve_prompt_fragments(&prompts, |_| None);
        assert_eq!(
            vars.get("NLIR_SYSTEM_PROMPT").map(String::as_str),
            Some("sys text")
        );
        assert_eq!(
            vars.get("NLIR_STRUCTURED_PROMPT").map(String::as_str),
            Some("json only")
        );
    }

    #[test]
    fn prompt_fragment_env_override_wins_over_text() {
        let mut prompts = BTreeMap::new();
        prompts.insert(
            "system".to_owned(),
            prompt_def(Some("NLIR_SYSTEM_PROMPT"), Some("default")),
        );
        let vars = resolve_prompt_fragments(&prompts, |name| {
            (name == "NLIR_SYSTEM_PROMPT").then(|| "overridden".to_owned())
        });
        assert_eq!(
            vars.get("NLIR_SYSTEM_PROMPT").map(String::as_str),
            Some("overridden")
        );
    }

    #[test]
    fn prompt_fragment_without_text_or_env_value_is_empty() {
        let mut prompts = BTreeMap::new();
        prompts.insert("bare".to_owned(), prompt_def(Some("NLIR_BARE"), None));
        let vars = resolve_prompt_fragments(&prompts, |_| None);
        assert_eq!(vars.get("NLIR_BARE").map(String::as_str), Some(""));
    }

    #[test]
    fn prompt_fragment_without_env_name_is_skipped() {
        let mut prompts = BTreeMap::new();
        prompts.insert("nameless".to_owned(), prompt_def(None, Some("text")));
        let vars = resolve_prompt_fragments(&prompts, |_| None);
        assert!(vars.is_empty());
    }

    // --- ${NLIR_*} assembly (bd-e9983b) ---

    fn vars_of(pairs: &[(&str, &str)]) -> BTreeMap<String, String> {
        pairs
            .iter()
            .map(|(k, v)| ((*k).to_owned(), (*v).to_owned()))
            .collect()
    }

    #[test]
    fn assemble_nlir_vars_adds_filled_prompt_to_fragments() {
        let fragments = vars_of(&[("NLIR_SYSTEM_PROMPT", "be terse")]);
        let vars = assemble_nlir_vars("do the thing", &fragments);
        assert_eq!(
            vars.get("NLIR_PROMPT").map(String::as_str),
            Some("do the thing")
        );
        assert_eq!(
            vars.get("NLIR_SYSTEM_PROMPT").map(String::as_str),
            Some("be terse")
        );
    }

    #[test]
    fn substitute_nlir_vars_expands_known_references() {
        let vars = vars_of(&[("NLIR_SYSTEM_PROMPT", "SYS"), ("NLIR_PROMPT", "PROMPT")]);
        assert_eq!(
            substitute_nlir_vars("sys=${NLIR_SYSTEM_PROMPT}; body=${NLIR_PROMPT}!", &vars),
            "sys=SYS; body=PROMPT!"
        );
    }

    #[test]
    fn substitute_nlir_vars_leaves_unknown_and_unterminated_literal() {
        let vars = vars_of(&[("NLIR_PROMPT", "P")]);
        // Unknown variable stays literal (not emptied).
        assert_eq!(
            substitute_nlir_vars("${NLIR_MISSING}-${NLIR_PROMPT}", &vars),
            "${NLIR_MISSING}-P"
        );
        // Unterminated ${ is emitted verbatim.
        assert_eq!(
            substitute_nlir_vars("tail ${NLIR_PROMPT", &vars),
            "tail ${NLIR_PROMPT"
        );
    }

    #[test]
    fn nlir_args_declaration_quotes_operands_for_bash() {
        assert_eq!(
            nlir_args_declaration(&["a".to_owned(), "b c".to_owned()]),
            "NLIR_ARGS=('a' 'b c')"
        );
        assert_eq!(nlir_args_declaration(&[]), "NLIR_ARGS=()");
        // Embedded single quote is escaped via the '\'' idiom.
        assert_eq!(
            nlir_args_declaration(&["it's".to_owned()]),
            "NLIR_ARGS=('it'\\''s')"
        );
    }

    // --- anthropic_messages backend (bd-d1a328) ---

    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::thread::JoinHandle;

    fn anthropic_model(base_url: &str, format: ModelFormat) -> ModelConfig {
        ModelConfig {
            kind: ModelKind::AnthropicMessages,
            format,
            base_url: Some(base_url.to_owned()),
            api_key: Some("test-key".to_owned()),
            model: Some("claude-test".to_owned()),
            result_field: None,
            messages: vec![
                crate::config::ModelMessage {
                    role: "system".to_owned(),
                    content: "${NLIR_SYSTEM_PROMPT}".to_owned(),
                },
                crate::config::ModelMessage {
                    role: "user".to_owned(),
                    content: "${NLIR_PROMPT}".to_owned(),
                },
            ],
            ..ModelConfig::default()
        }
    }

    /// A one-shot HTTP server that captures the request and returns a canned
    /// response. Returns the base URL and a handle yielding the raw request.
    fn spawn_mock(status_line: &'static str, body: &'static str) -> (String, JoinHandle<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind mock");
        let addr = listener.local_addr().expect("addr");
        let handle = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().expect("accept");
            let mut buf = Vec::new();
            let mut tmp = [0u8; 1024];
            // Read headers, then the body per content-length.
            let mut header_end = None;
            while header_end.is_none() {
                let n = stream.read(&mut tmp).expect("read");
                if n == 0 {
                    break;
                }
                buf.extend_from_slice(&tmp[..n]);
                header_end = find_subslice(&buf, b"\r\n\r\n");
            }
            let headers = String::from_utf8_lossy(&buf).to_string();
            let content_length = parse_content_length(&headers);
            let body_start = header_end.map_or(buf.len(), |p| p + 4);
            while buf.len() - body_start < content_length {
                let n = stream.read(&mut tmp).expect("read body");
                if n == 0 {
                    break;
                }
                buf.extend_from_slice(&tmp[..n]);
            }
            let response = format!(
                "HTTP/1.1 {status_line}\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{body}",
                body.len()
            );
            stream.write_all(response.as_bytes()).expect("write");
            stream.flush().expect("flush");
            String::from_utf8_lossy(&buf).to_string()
        });
        (format!("http://{addr}"), handle)
    }

    fn find_subslice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
        haystack.windows(needle.len()).position(|w| w == needle)
    }

    fn parse_content_length(headers: &str) -> usize {
        headers
            .lines()
            .find_map(|line| {
                let (name, value) = line.split_once(':')?;
                name.trim()
                    .eq_ignore_ascii_case("content-length")
                    .then(|| value.trim().parse().ok())
                    .flatten()
            })
            .unwrap_or(0)
    }

    fn nlir_vars() -> BTreeMap<String, String> {
        vars_of(&[
            ("NLIR_SYSTEM_PROMPT", "be terse"),
            ("NLIR_PROMPT", "transform this"),
        ])
    }

    #[test]
    fn anthropic_text_backend_extracts_text_and_sends_expected_request() {
        let (base_url, handle) = spawn_mock(
            "200 OK",
            r#"{"content":[{"type":"text","text":"hello world"}]}"#,
        );
        let model = anthropic_model(&base_url, ModelFormat::Text);
        let result = run_anthropic_backend(&model, &nlir_vars()).expect("backend succeeds");
        assert_eq!(result, "hello world");

        let request = handle.join().expect("mock thread");
        // POST to /messages with the version header and substituted prompt.
        assert!(
            request.starts_with("POST /messages "),
            "request line: {request}"
        );
        assert!(request.contains("anthropic-version: 2023-06-01"));
        assert!(request.contains("x-api-key: test-key"));
        assert!(request.contains("claude-test"));
        assert!(
            request.contains("transform this"),
            "substituted prompt missing"
        );
        assert!(request.contains("be terse"), "system prompt missing");
    }

    #[test]
    fn anthropic_json_backend_extracts_result_field() {
        let (base_url, handle) = spawn_mock(
            "200 OK",
            r#"{"content":[{"type":"text","text":"{\"result\":\"hi\"}"}]}"#,
        );
        let model = anthropic_model(&base_url, ModelFormat::Json);
        let result = run_anthropic_backend(&model, &nlir_vars()).expect("backend succeeds");
        assert_eq!(result, "hi");
        handle.join().expect("mock thread");
    }

    #[test]
    fn anthropic_http_error_status_is_reported() {
        let (base_url, handle) = spawn_mock("400 Bad Request", r#"{"error":"nope"}"#);
        let model = anthropic_model(&base_url, ModelFormat::Text);
        match run_anthropic_backend(&model, &nlir_vars()) {
            Err(AnthropicError::Http(detail)) => assert!(detail.contains("400"), "{detail}"),
            other => panic!("expected Http error, got {other:?}"),
        }
        handle.join().expect("mock thread");
    }

    #[test]
    fn anthropic_response_without_text_is_a_bad_response() {
        let (base_url, handle) = spawn_mock("200 OK", r#"{"content":[]}"#);
        let model = anthropic_model(&base_url, ModelFormat::Text);
        assert!(matches!(
            run_anthropic_backend(&model, &nlir_vars()),
            Err(AnthropicError::BadResponse(_))
        ));
        handle.join().expect("mock thread");
    }

    #[test]
    fn anthropic_missing_config_errors_before_any_request() {
        let mut model = anthropic_model("http://127.0.0.1:1", ModelFormat::Text);
        model.base_url = None;
        assert!(matches!(
            run_anthropic_backend(&model, &nlir_vars()),
            Err(AnthropicError::NoBaseUrl)
        ));

        let mut model = anthropic_model("http://127.0.0.1:1", ModelFormat::Text);
        model.model = None;
        assert!(matches!(
            run_anthropic_backend(&model, &nlir_vars()),
            Err(AnthropicError::NoModel)
        ));
    }

    // --- LLM coercion fallback (bd-ecb930) ---

    fn coercion_config(command: &str, format: ModelFormat) -> Config {
        let mut config = Config::default();
        config.models.insert(
            "cmd".to_owned(),
            ModelConfig {
                kind: ModelKind::Command,
                format,
                command: Some(command.to_owned()),
                ..ModelConfig::default()
            },
        );
        for ty in ["number", "bool"] {
            config.types.insert(
                ty.to_owned(),
                crate::config::CoercionType {
                    model: Some("cmd".to_owned()),
                    prompt: Some(format!("as {ty}: %")),
                    schema: None,
                },
            );
        }
        config
    }

    #[test]
    fn deterministic_coercion_short_circuits_without_calling_the_llm() {
        // The command would yield a non-number, but a deterministic parse of "1"
        // wins first, so the LLM is never invoked.
        let config = coercion_config("printf 'nope'", ModelFormat::Text);
        assert_eq!(
            coerce_with_llm(
                &Value::string("1"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None
            )
            .expect("deterministic coercion succeeds"),
            Value::number(1.0)
        );
    }

    #[test]
    fn list_to_number_is_an_error_and_never_calls_the_llm() {
        let config = coercion_config("printf '5'", ModelFormat::Text);
        let list = Value::list(vec![Value::number(1.0)]);
        match coerce_with_llm(&list, TypeName::Number, &config, "\n", |_| None, None) {
            Err(LlmCoerceError::Coerce(error)) => {
                assert_eq!(error.kind, crate::value::CoerceErrorKind::ListToNumber);
            }
            other => panic!("expected list->number Coerce error, got {other:?}"),
        }
    }

    #[test]
    fn llm_command_backend_coerces_text_result() {
        let config = coercion_config("printf '5'", ModelFormat::Text);
        assert_eq!(
            coerce_with_llm(
                &Value::string("five"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None
            )
            .expect("llm text coercion succeeds"),
            Value::number(5.0)
        );
    }

    #[test]
    fn llm_command_backend_coerces_json_result() {
        let config = coercion_config(r#"printf '{"result":"7"}'"#, ModelFormat::Json);
        assert_eq!(
            coerce_with_llm(
                &Value::string("seven"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None
            )
            .expect("llm json coercion succeeds"),
            Value::number(7.0)
        );
    }

    #[test]
    fn llm_result_that_is_not_the_target_type_is_an_error() {
        let config = coercion_config("printf 'notnum'", ModelFormat::Text);
        match coerce_with_llm(
            &Value::string("x"),
            TypeName::Number,
            &config,
            "\n",
            |_| None,
            None,
        ) {
            Err(LlmCoerceError::UnparseableResult { target, raw }) => {
                assert_eq!(target, TypeName::Number);
                assert_eq!(raw, "notnum");
            }
            other => panic!("expected UnparseableResult, got {other:?}"),
        }
    }

    #[test]
    fn missing_coercion_config_for_target_is_an_error() {
        let config = Config::default(); // no `types:` entries
        assert!(matches!(
            coerce_with_llm(
                &Value::string("x"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None
            ),
            Err(LlmCoerceError::NoCoercionConfig(TypeName::Number))
        ));
    }

    // --- coercion caching under _cache (bd-876367) ---

    #[test]
    fn cache_serves_repeated_coercions_without_recomputing() {
        let mut config = coercion_config("printf '5'", ModelFormat::Text);
        let mut cache = CoercionCache::new(true);
        let first = cache
            .coerce(
                &Value::string("five"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None,
            )
            .expect("first coercion");
        assert_eq!(first, Value::number(5.0));
        assert_eq!(cache.len(), 1);

        // Change the backend so a recompute would differ; the cache must ignore it.
        config.models.get_mut("cmd").unwrap().command = Some("printf '9'".to_owned());
        let second = cache
            .coerce(
                &Value::string("five"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None,
            )
            .expect("second coercion");
        assert_eq!(
            second,
            Value::number(5.0),
            "cache hit returns the first result"
        );
    }

    #[test]
    fn disabled_cache_always_recomputes() {
        let mut config = coercion_config("printf '5'", ModelFormat::Text);
        let mut cache = CoercionCache::new(false);
        let first = cache
            .coerce(
                &Value::string("five"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None,
            )
            .expect("first coercion");
        assert_eq!(first, Value::number(5.0));
        assert!(cache.is_empty());

        config.models.get_mut("cmd").unwrap().command = Some("printf '9'".to_owned());
        let second = cache
            .coerce(
                &Value::string("five"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None,
            )
            .expect("second coercion");
        assert_eq!(second, Value::number(9.0), "disabled cache recomputes");
    }

    #[test]
    fn different_inputs_use_separate_cache_entries() {
        let mut config = coercion_config("printf '5'", ModelFormat::Text);
        let mut cache = CoercionCache::new(true);
        cache
            .coerce(
                &Value::string("five"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None,
            )
            .expect("first coercion");
        // A different source text is a different key, so it recomputes with the
        // new backend output.
        config.models.get_mut("cmd").unwrap().command = Some("printf '9'".to_owned());
        let other = cache
            .coerce(
                &Value::string("nine"),
                TypeName::Number,
                &config,
                "\n",
                |_| None,
                None,
            )
            .expect("second coercion");
        assert_eq!(other, Value::number(9.0));
        assert_eq!(cache.len(), 2);
    }

    // --- realise_llm (bd-dc3c72) ---

    #[test]
    fn realise_llm_command_fills_prompt_and_reaches_backend() {
        let mut config = Config::default();
        config.models.insert(
            "cmd".to_owned(),
            command_model(r#"printf '%s' "$NLIR_PROMPT""#, ModelFormat::Text),
        );
        let out = realise_llm(
            Some("cmd"),
            "combine: %",
            &["a".to_owned(), "b".to_owned()],
            &config,
            None,
            |_| None,
        )
        .expect("command realisation");
        assert_eq!(out, "combine: <text n=0>a</text>\n<text n=1>b</text>");
    }

    #[test]
    fn realise_llm_command_gets_nlir_args_array() {
        let mut config = Config::default();
        config.models.insert(
            "cmd".to_owned(),
            command_model(r#"printf '%s' "${NLIR_ARGS[1]}""#, ModelFormat::Text),
        );
        let out = realise_llm(
            Some("cmd"),
            "%",
            &["x".to_owned(), "y".to_owned()],
            &config,
            None,
            |_| None,
        )
        .expect("nlir_args realisation");
        assert_eq!(out, "y");
    }

    #[test]
    fn realise_llm_falls_back_to_defaults_model() {
        let mut config = Config::default();
        config.defaults.model = Some("cmd".to_owned());
        config.models.insert(
            "cmd".to_owned(),
            command_model("printf 'ok'", ModelFormat::Text),
        );
        let out = realise_llm(None, "%", &["a".to_owned()], &config, None, |_| None)
            .expect("defaults realisation");
        assert_eq!(out, "ok");
    }

    #[test]
    fn realise_llm_unknown_model_errors() {
        let config = Config::default();
        assert!(matches!(
            realise_llm(Some("nope"), "%", &[], &config, None, |_| None),
            Err(RealiseError::Model(ModelResolveError::UnknownModel(_)))
        ));
    }

    #[test]
    fn realise_llm_dispatches_to_anthropic() {
        let (base_url, handle) =
            spawn_mock("200 OK", r#"{"content":[{"type":"text","text":"done"}]}"#);
        let mut config = Config::default();
        config.models.insert(
            "claude".to_owned(),
            anthropic_model(&base_url, ModelFormat::Text),
        );
        let out = realise_llm(
            Some("claude"),
            "do: %",
            &["z".to_owned()],
            &config,
            None,
            |_| None,
        )
        .expect("anthropic realisation");
        assert_eq!(out, "done");
        let request = handle.join().expect("mock thread");
        assert!(
            request.contains("do:"),
            "prompt reached the request: {request}"
        );
        assert!(
            request.contains("<text>z</text>"),
            "operand reached the request"
        );
    }
}
