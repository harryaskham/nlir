//! nlir configuration schema (SPEC §Modes, §Types & coercion, §Example config).
//!
//! `~/.config/nlir/config.yaml` is where the whole language lives: the binary is
//! a small VM; the language is config. This module defines the serde types for
//! the full config tree — `defaults`, `models`, `prompts`, `operators`,
//! `context`, `sessions`, `types`, `tests` — that the rest of config (discovery,
//! load, env-interpolation, validation, defaults-resolution) and the engine build
//! on. It is intentionally schema-only (bd-a82cb7): no discovery, load,
//! interpolation, validation, or defaults-resolution logic lives here yet.
//!
//! Every section carries `#[serde(default)]` so a partial `config.yaml`
//! deserializes cleanly (a missing section becomes an empty default) — the
//! validation/defaults beads decide which fields are ultimately required.

use std::collections::BTreeMap;

use serde::de::{self, Visitor};
use serde::{Deserialize, Deserializer, Serialize, Serializer};

use crate::Mode;

/// The root config tree, mirroring `~/.config/nlir/config.yaml`.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Config {
    /// Global run defaults (mode / model / parallelism).
    pub defaults: Defaults,
    /// Named model backends (`type: anthropic_messages | command`).
    pub models: BTreeMap<String, ModelConfig>,
    /// Named reusable prompt fragments (system / structured / unstructured …).
    pub prompts: BTreeMap<String, PromptDef>,
    /// The operator vocabulary — the language proper.
    pub operators: BTreeMap<String, OperatorConfig>,
    /// Context namespace configuration (env var, file, messages, defaults).
    pub context: ContextConfig,
    /// Named session importers (e.g. a Pi session → context messages).
    pub sessions: BTreeMap<String, SessionConfig>,
    /// Coercion targets — how to interpret text as `number` / `bool` / … .
    pub types: BTreeMap<String, CoercionType>,
    /// Config-defined test cases (`nlir test`).
    pub tests: BTreeMap<String, TestCase>,
}

// ---------------------------------------------------------------------------
// defaults
// ---------------------------------------------------------------------------

/// Global run defaults (SPEC §Modes; §Execution graph & parallelism).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Defaults {
    /// Default evaluation mode (`det` | `llm`).
    pub mode: Mode,
    /// Default model name (a key into `models`).
    pub model: Option<String>,
    /// Default DAG scheduler parallelism.
    pub parallelism: usize,
}

impl Default for Defaults {
    fn default() -> Self {
        Self {
            mode: Mode::default(),
            model: None,
            parallelism: crate::DEFAULT_PARALLELISM,
        }
    }
}

// ---------------------------------------------------------------------------
// models
// ---------------------------------------------------------------------------

/// A named model backend.
///
/// `anthropic_messages` posts to a base URL directly; `command` shells out to a
/// subprocess (e.g. `claude …` / `pi …`). Provider-specific and prompt-assembly
/// fields are optional so both shapes deserialize from the one struct.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ModelConfig {
    /// Backend kind.
    #[serde(rename = "type")]
    pub kind: ModelKind,
    /// Response wire format (`json` | `text`).
    pub format: ModelFormat,
    /// For `type: anthropic_messages` — API base URL.
    pub base_url: Option<String>,
    /// For `type: anthropic_messages` — API key (often a `$ENV` reference,
    /// resolved by the env-interpolation bead).
    pub api_key: Option<String>,
    /// Underlying provider model id (e.g. `claude-haiku-4-5`).
    pub model: Option<String>,
    /// For `format: json` — the JSON field holding the result string.
    pub result_field: Option<String>,
    /// For `type: command` — the subprocess command template.
    pub command: Option<String>,
    /// For `type: anthropic_messages` — the message template array.
    pub messages: Vec<ModelMessage>,
    /// Provider-specific structured-output config (arbitrary JSON schema shape).
    pub output_config: Option<serde_json::Value>,
}

/// Model backend kind.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelKind {
    /// POST to an Anthropic-messages-shaped endpoint.
    #[default]
    AnthropicMessages,
    /// Shell out to a subprocess.
    Command,
}

/// Model response wire format.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ModelFormat {
    /// Structured JSON with a `result_field`.
    #[default]
    Json,
    /// Plain text (the whole stdout is the result).
    Text,
}

/// One templated message in an `anthropic_messages` model.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ModelMessage {
    pub role: String,
    pub content: String,
}

// ---------------------------------------------------------------------------
// prompts
// ---------------------------------------------------------------------------

/// A named prompt fragment: literal `text`, optionally overridable from `env`.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct PromptDef {
    /// Environment variable that overrides `text` when set.
    pub env: Option<String>,
    /// Literal prompt text.
    pub text: Option<String>,
}

// ---------------------------------------------------------------------------
// operators
// ---------------------------------------------------------------------------

/// A single configured operator — the unit of the language vocabulary
/// (SPEC §Config operators, §Grammar & parsing).
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct OperatorConfig {
    /// The operator sigil (e.g. `#`, `&`, `**`).
    pub op: String,
    /// Operand count: a fixed number, or `>0` (variadic).
    pub arity: Arity,
    /// Where the operator sits relative to its operands.
    pub fixity: Fixity,
    /// Binding strength; higher binds tighter (SPEC default 9). `None` lets the
    /// defaults-resolution bead apply the default.
    pub priority: Option<i64>,
    /// Required operand type (each operand is coerced to this first).
    pub operands: TypeName,
    /// Result type.
    pub result: TypeName,
    // --- realisation (SPEC §Modes) ---
    /// Deterministic template (`det`), e.g. `"not %"`.
    pub template: Option<String>,
    /// Deterministic variadic join separator (`det`), e.g. `" and "`.
    pub join: Option<String>,
    /// Deterministic subprocess command (`command:`), always det.
    pub command: Option<String>,
    /// Deterministic numeric reduction (`reduce:`), always det.
    pub reduce: Option<ReduceOp>,
    /// LLM model name for the `llm` realisation.
    pub model: Option<String>,
    /// LLM prompt template (`%` = operand under replacement; `%%` = literal `%`).
    pub prompt: Option<String>,
}

/// Operator fixity (SPEC §Grammar & parsing).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Fixity {
    /// One right operand (e.g. `#`, `!`).
    #[default]
    Prefix,
    /// Leftward to its priority (e.g. `?`).
    Postfix,
    /// Binary infix (e.g. `-`, `/`).
    Infix,
    /// Unifies infix / list / nullary (e.g. `&`, `+`).
    Mixfix,
}

/// A value type in the tiny type system (SPEC §Types & coercion).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum TypeName {
    /// Default type.
    #[default]
    String,
    Number,
    Bool,
    List,
}

/// Built-in numeric reduction for `reduce:` operators.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ReduceOp {
    Add,
    Sub,
    Mul,
    Div,
    Pow,
}

/// Operator arity: a fixed count, or `>0` (one-or-more, variadic).
///
/// Deserializes from either an integer (`arity: 2`) or the string `">0"`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Arity {
    /// Exactly `n` operands.
    Exact(u32),
    /// One or more operands (`>0`, variadic).
    #[default]
    Variadic,
}

impl Serialize for Arity {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        match self {
            Arity::Exact(n) => serializer.serialize_u32(*n),
            Arity::Variadic => serializer.serialize_str(">0"),
        }
    }
}

impl<'de> Deserialize<'de> for Arity {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        struct ArityVisitor;

        impl Visitor<'_> for ArityVisitor {
            type Value = Arity;

            fn expecting(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
                f.write_str("a non-negative integer or the string \">0\"")
            }

            fn visit_u64<E: de::Error>(self, v: u64) -> Result<Arity, E> {
                u32::try_from(v)
                    .map(Arity::Exact)
                    .map_err(|_| E::custom(format!("arity {v} is too large")))
            }

            fn visit_i64<E: de::Error>(self, v: i64) -> Result<Arity, E> {
                u32::try_from(v)
                    .map(Arity::Exact)
                    .map_err(|_| E::custom(format!("arity {v} must be a non-negative integer")))
            }

            fn visit_str<E: de::Error>(self, v: &str) -> Result<Arity, E> {
                let t = v.trim();
                if t == ">0" {
                    return Ok(Arity::Variadic);
                }
                t.parse::<u32>().map(Arity::Exact).map_err(|_| {
                    E::custom(format!("invalid arity {v:?}: want an integer or \">0\""))
                })
            }
        }

        deserializer.deserialize_any(ArityVisitor)
    }
}

// ---------------------------------------------------------------------------
// context
// ---------------------------------------------------------------------------

/// Context namespace configuration (SPEC §Runtime state).
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ContextConfig {
    /// Env var holding an inline context JSON object (default `NLIR_CONTEXT`).
    pub env: Option<String>,
    /// Default context file path (default `~/.config/nlir/context.json`).
    pub file_default: Option<String>,
    /// Messages sub-namespace (`_messages` + role-filtered views).
    pub messages: MessagesConfig,
    /// System-key defaults (`_sep`, `_cache`).
    pub defaults: ContextDefaults,
}

/// The `_messages` sub-namespace configuration (SPEC §Message indexing).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct MessagesConfig {
    /// Context key holding the messages array (default `_messages`).
    pub key: String,
    /// Field naming the message role.
    pub role_field: String,
    /// Field naming the message content.
    pub content_field: String,
    /// Role views selected by `^` / `^_` / `^*` / `^/`.
    pub views: MessageViews,
}

impl Default for MessagesConfig {
    fn default() -> Self {
        Self {
            key: "_messages".to_owned(),
            role_field: "role".to_owned(),
            content_field: "content".to_owned(),
            views: MessageViews::default(),
        }
    }
}

/// Role-filtered message views: `^` default, `^_` user, `^*` all, `^/` system.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct MessageViews {
    /// `^` — roles for the default (assistant) view.
    pub default: Vec<String>,
    /// `^_` — roles for the user view.
    pub user: Vec<String>,
    /// `^*` — roles for the all view.
    pub all: Vec<String>,
    /// `^/` — roles for the system view.
    pub system: Vec<String>,
}

/// Context system-key defaults (SPEC §Runtime state: `_sep`, `_cache`).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ContextDefaults {
    /// List / message-range → text separator (default `"\n"`).
    #[serde(rename = "_sep")]
    pub sep: String,
    /// Whether identical subcalls / coercions are cached (default `true`).
    #[serde(rename = "_cache")]
    pub cache: bool,
}

impl Default for ContextDefaults {
    fn default() -> Self {
        Self {
            sep: "\n".to_owned(),
            cache: true,
        }
    }
}

// ---------------------------------------------------------------------------
// sessions
// ---------------------------------------------------------------------------

/// A named session importer (SPEC §CLI: `--session-file`).
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct SessionConfig {
    /// Session format label (e.g. `pi`).
    pub format: String,
    /// Roles to keep when importing.
    pub keep_roles: Vec<String>,
    /// Drop tool-call messages on import.
    pub drop_tool_messages: bool,
    /// Field naming the message role in the session file.
    pub role_field: Option<String>,
    /// Field naming the message content in the session file.
    pub content_field: Option<String>,
}

// ---------------------------------------------------------------------------
// types (coercion targets)
// ---------------------------------------------------------------------------

/// A coercion target: how to interpret text as a value of this type when the
/// deterministic parse fails and an LLM coercion is needed (SPEC §Types).
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct CoercionType {
    /// Model used for the LLM coercion path.
    pub model: Option<String>,
    /// Coercion prompt (`%` = the text under interpretation).
    pub prompt: Option<String>,
    /// Structured-output JSON schema constraining `{result: T}`.
    pub schema: Option<serde_json::Value>,
}

// ---------------------------------------------------------------------------
// tests
// ---------------------------------------------------------------------------

/// A config-defined test case (SPEC §Example config `tests:`), run by `nlir test`.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct TestCase {
    /// Mode to evaluate under.
    pub mode: Mode,
    /// The shorthand expression to evaluate.
    pub expr: String,
    /// The expected English result.
    pub expected: String,
    /// Optional context seed (e.g. `_messages`) for the test run.
    pub context: Option<serde_json::Value>,
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A representative subset of the SPEC §Example config.yaml.
    const SAMPLE: &str = r##"
defaults:
  mode: llm
  model: haiku
  parallelism: 8

context:
  env: NLIR_CONTEXT
  file_default: ~/.config/nlir/context.json
  messages:
    key: _messages
    role_field: role
    content_field: content
    views:
      default: [assistant]
      user: [user]
      all: [user, assistant, system]
      system: [system]
  defaults:
    _sep: "\n"
    _cache: true

models:
  haiku:
    type: anthropic_messages
    base_url: https://api.anthropic.com/v1
    api_key: $ANTHROPIC_API_KEY
    model: claude-haiku-4-5
    format: json
    result_field: result
  sonnet:
    type: command
    format: json
    result_field: result
    command: claude --model claude-sonnet-5

prompts:
  system: { env: NLIR_SYSTEM_PROMPT, text: "Perform the transformation." }

operators:
  subject: { op: "#", arity: 1, fixity: prefix, model: haiku, prompt: "Extract the subject.\n\n%" }
  and:     { op: "&", arity: ">0", fixity: mixfix, join: " and ", model: sonnet }
  question: { op: "?", arity: 1, fixity: postfix, priority: 0, template: "is it the case that %?" }
  add:     { op: "+", arity: ">0", fixity: mixfix, operands: number, result: number, reduce: add }
  sub:     { op: "-", arity: 2, fixity: infix, operands: number, result: number, reduce: sub }

sessions:
  pi:
    format: pi
    keep_roles: [user, assistant]
    drop_tool_messages: true

types:
  number:
    model: haiku
    prompt: "Interpret as a number.\n\n%"
    schema: { type: object, properties: { result: { type: number } }, required: [result] }

tests:
  det-and: { mode: det, expr: "a&b&c", expected: "a and b and c" }
  msg:
    mode: det
    context:
      _messages:
        - { role: user, content: "hi" }
        - { role: assistant, content: "in rust" }
    expr: "^-1"
    expected: "in rust"
"##;

    #[test]
    fn full_sample_config_deserialises() {
        let cfg: Config = serde_yaml::from_str(SAMPLE).expect("sample config deserialises");

        assert_eq!(cfg.defaults.mode, Mode::Llm);
        assert_eq!(cfg.defaults.model.as_deref(), Some("haiku"));
        assert_eq!(cfg.defaults.parallelism, 8);

        // models
        assert_eq!(cfg.models["haiku"].kind, ModelKind::AnthropicMessages);
        assert_eq!(cfg.models["haiku"].format, ModelFormat::Json);
        assert_eq!(cfg.models["sonnet"].kind, ModelKind::Command);
        assert_eq!(
            cfg.models["sonnet"].command.as_deref(),
            Some("claude --model claude-sonnet-5")
        );

        // operators: arity int vs ">0", fixity, reduce, priority
        assert_eq!(cfg.operators["subject"].op, "#");
        assert_eq!(cfg.operators["subject"].arity, Arity::Exact(1));
        assert_eq!(cfg.operators["subject"].fixity, Fixity::Prefix);
        assert_eq!(cfg.operators["and"].arity, Arity::Variadic);
        assert_eq!(cfg.operators["and"].fixity, Fixity::Mixfix);
        assert_eq!(cfg.operators["question"].priority, Some(0));
        assert_eq!(cfg.operators["add"].reduce, Some(ReduceOp::Add));
        assert_eq!(cfg.operators["add"].operands, TypeName::Number);
        assert_eq!(cfg.operators["add"].result, TypeName::Number);
        assert_eq!(cfg.operators["sub"].arity, Arity::Exact(2));

        // context
        assert_eq!(cfg.context.messages.key, "_messages");
        assert_eq!(cfg.context.messages.views.default, vec!["assistant"]);
        assert_eq!(cfg.context.defaults.sep, "\n");
        assert!(cfg.context.defaults.cache);

        // sessions / types / prompts / tests
        assert!(cfg.sessions["pi"].drop_tool_messages);
        assert_eq!(cfg.sessions["pi"].keep_roles, vec!["user", "assistant"]);
        assert!(cfg.types["number"].schema.is_some());
        assert_eq!(
            cfg.prompts["system"].env.as_deref(),
            Some("NLIR_SYSTEM_PROMPT")
        );
        assert_eq!(cfg.tests["det-and"].mode, Mode::Det);
        assert_eq!(cfg.tests["det-and"].expected, "a and b and c");
        assert!(cfg.tests["msg"].context.is_some());
    }

    #[test]
    fn empty_config_uses_defaults() {
        let cfg: Config = serde_yaml::from_str("{}").expect("empty config deserialises");
        assert_eq!(cfg.defaults.mode, Mode::default());
        assert_eq!(cfg.defaults.parallelism, crate::DEFAULT_PARALLELISM);
        assert_eq!(cfg.context.messages.key, "_messages");
        assert_eq!(cfg.context.defaults.sep, "\n");
        assert!(cfg.context.defaults.cache);
        assert!(cfg.operators.is_empty());
    }

    #[test]
    fn arity_round_trips() {
        assert_eq!(serde_yaml::from_str::<Arity>("3").unwrap(), Arity::Exact(3));
        assert_eq!(
            serde_yaml::from_str::<Arity>("\">0\"").unwrap(),
            Arity::Variadic
        );
        assert!(serde_yaml::from_str::<Arity>("\"nope\"").is_err());
    }

    #[test]
    fn unknown_top_level_key_is_rejected() {
        let err = serde_yaml::from_str::<Config>("bogus: 1").unwrap_err();
        assert!(
            err.to_string().contains("bogus") || err.to_string().contains("unknown"),
            "expected unknown-field rejection, got: {err}"
        );
    }
}
