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
use std::ffi::OsStr;
use std::path::{Path, PathBuf};
use std::{fmt, fs, io};

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
    /// Default model name (a key into `models`), or size tiers.
    pub model: Option<DefaultModel>,
    /// Default DAG scheduler parallelism.
    pub parallelism: usize,
}

/// The default model configuration: either a single alias (back-compat) or a set
/// of size tiers that an operator's `model: small|medium|large` resolves through.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum DefaultModel {
    /// A single default model alias, a key into `models` (`defaults.model: haiku`).
    Alias(String),
    /// Size tiers (`defaults.model: { small: haiku, medium: sonnet, large: opus }`).
    /// An operator or `--model` may name a tier instead of a concrete alias.
    Tiers(ModelTiers),
}

/// The `small` / `medium` / `large` model tiers under `defaults.model`.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ModelTiers {
    pub small: Option<String>,
    pub medium: Option<String>,
    pub large: Option<String>,
}

impl DefaultModel {
    /// The concrete alias a tier name (`small`/`medium`/`large`) maps to, if this
    /// is a tier config and that tier is set. `None` for a single-alias default or
    /// an unknown tier name.
    #[must_use]
    pub fn tier(&self, name: &str) -> Option<&str> {
        match self {
            DefaultModel::Tiers(t) => match name {
                "small" => t.small.as_deref(),
                "medium" => t.medium.as_deref(),
                "large" => t.large.as_deref(),
                _ => None,
            },
            DefaultModel::Alias(_) => None,
        }
    }

    /// The default alias when nothing else selects a model: the single alias, or
    /// the `medium` tier (the sensible middle default).
    #[must_use]
    pub fn default_alias(&self) -> Option<&str> {
        match self {
            DefaultModel::Alias(a) => Some(a),
            DefaultModel::Tiers(t) => t.medium.as_deref(),
        }
    }

    /// Every concrete alias this default references (the single alias, or all set
    /// tiers) — validation checks they all name defined `models`.
    fn referenced_aliases(&self) -> Vec<&str> {
        match self {
            DefaultModel::Alias(a) => vec![a.as_str()],
            DefaultModel::Tiers(t) => [&t.small, &t.medium, &t.large]
                .into_iter()
                .filter_map(Option::as_deref)
                .collect(),
        }
    }
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
    /// Associativity for equal-precedence `infix` chains (default `left`).
    /// `right` makes `a op b op c` group as `a op (b op c)` — used by `**` so
    /// `2**3**2` == `2**(3**2)` == 512, matching normal math / Python (bd-df62f1).
    pub assoc: Assoc,
    /// Required operand type (each operand is coerced to this first).
    pub operands: TypeName,
    /// Result type.
    pub result: TypeName,
    /// Human-readable one-line description of what the operator does and when to
    /// reach for it, surfaced by `nlir help`. When absent, `nlir help` derives a
    /// summary from the template / reduce / join / prompt (bd-a4096b).
    pub description: Option<String>,
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
    /// A FORM this operator is realised by (bd-44c294): the operator applies the
    /// form to its operands (`$0`, `$1`, …) — sugar for `{form}%(operands)`. Turns
    /// any form into a first-class glyph/word operator, an alt to command/prompt.
    pub form: Option<String>,
    /// A BUILTIN this operator is realised by (bd-44c294): `map` or `fold`, so a
    /// glyph can be bound to the higher-order engine (`{$0*$0}↦[1,2,3]`).
    pub builtin: Option<String>,
    /// A DET-MODE-ONLY realisation FORM (bd-6f9c1d): applied like `form:` but ONLY
    /// in `Mode::Det`, so an otherwise-llm operator (`~>`) gets a meaningful
    /// COMPUTED det stub (`{$contains%($0,$1)}` → a real `Value::Bool`) while its
    /// `model:` still realises in llm mode. Parallel to how `template:` is
    /// det-only, but computed (a template can only interpolate, not compute).
    pub det: Option<String>,
    /// A VALUE-BUILTIN this operator aliases to when it appears at operand-START
    /// (prefix position), applied via `%(…)` (bd-2f4d5e `?`→if, Harry's call): the
    /// op keeps its own realisation for its normal fixity (`?` stays the postfix
    /// question after an operand), but `?%(cond,then,else)` at operand-start
    /// dispatches to the named value-builtin (`if`), reusing its engine (so it
    /// short-circuits for free). A bare operand-start `?` with no `%` application
    /// is a clear parse error, never a silent incomplete form.
    pub prefix_builtin: Option<String>,
}

impl OperatorConfig {
    /// A one-line human summary of what this operator does: its `description:`
    /// if set, else derived from its realisation (reduce / join / template /
    /// command) or the first line of its LLM prompt. Shared by `nlir help` (the
    /// native CLI) and the wasm `operators()` export so they never drift.
    #[must_use]
    pub fn summary(&self) -> String {
        if let Some(d) = self.description.as_deref() {
            let d = d.trim();
            if !d.is_empty() {
                return d.to_string();
            }
        }
        if let Some(reduce) = self.reduce {
            return match reduce {
                ReduceOp::Add => "sum of the numeric operands",
                ReduceOp::Sub => "difference, a − b",
                ReduceOp::Mul => "product of the numeric operands",
                ReduceOp::Div => "quotient, a ÷ b",
                ReduceOp::Pow => "a to the power b",
                ReduceOp::Concat => "concatenation of the string operands",
                ReduceOp::Split => "split a string by a separator into a list",
                ReduceOp::Eq => "true if the two operands are equal",
                ReduceOp::Ne => "true if the two operands differ",
                ReduceOp::Le => "true if the first is ≤ the second (numeric)",
                ReduceOp::Ge => "true if the first is ≥ the second (numeric)",
            }
            .to_string();
        }
        if let Some(join) = self.join.as_deref() {
            return format!("joins its operands with \"{}\"", join.trim());
        }
        if let Some(template) = self.template.as_deref() {
            return format!("deterministic template: {template}");
        }
        if self.command.is_some() {
            return "runs a configured shell command".to_string();
        }
        if let Some(prompt) = self.prompt.as_deref() {
            let first = prompt.split(['\n', '.']).next().unwrap_or("").trim();
            if !first.is_empty() {
                return format!("{first} (LLM)");
            }
        }
        "—".to_string()
    }

    /// Whether this operator has a DETERMINISTIC realisation — i.e. it runs
    /// offline in `--mode det` (a `reduce` / `command` / `join` / `template`),
    /// versus model-only (only a `prompt`). Shared by `nlir help` + the wasm
    /// `operators()` export.
    #[must_use]
    pub fn is_deterministic(&self) -> bool {
        // Display semantics (nlir help det/llm tag + operator_reference `det`): an
        // op is "deterministic" only if its PRIMARY realisation is offline — it has
        // an offline realisation AND is not llm-primary. A det-only STUB (`template:`
        // interpolation or a `det:` COMPUTED form) on an llm op is a test-mode
        // det-coverage fallback, NOT the op's identity: an op carrying a `model:`
        // shows "llm" even with a det stub (e.g. `~>` = det: {$contains...} + model).
        // `builtin:` (map/fold/access) and `form:` are offline structural dispatch,
        // so they are det (bd-a51c62 follow-up: `.`/↦/⊘ were mis-tagged llm).
        self.model.is_none()
            && (self.reduce.is_some()
                || self.command.is_some()
                || self.join.is_some()
                || self.template.is_some()
                || self.form.is_some()
                || self.builtin.is_some()
                || self.det.is_some())
    }
}

/// A flat, serialisable row describing one operator for a reference / grammar
/// surface. The native `nlir help` table AND the wasm `operators()` export both
/// build from [`operator_reference`], so they share ONE source of truth and never
/// drift (nlir-wasm epic bd-360d0c; matches the P1 operators() JS contract
/// {op, name, description, arity, priority, fixity, det}).
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct OperatorRef {
    /// The operator sigil (e.g. `#`, `&`, `**`).
    pub op: String,
    /// The operator's config name (e.g. `subject`, `and`, `pow`).
    pub name: String,
    /// One-line summary ([`OperatorConfig::summary`]).
    pub description: String,
    /// Operand count, stringified: `"1"`, `"2"`, or `">0"` (variadic).
    pub arity: String,
    /// Fixity class: `"prefix"` / `"infix"` / `"postfix"` / `"mixfix"`.
    pub fixity: String,
    /// Binding priority, or `None` (JS `null`) when the config leaves it default.
    pub priority: Option<i64>,
    /// Whether the operator runs offline in `--mode det`
    /// ([`OperatorConfig::is_deterministic`]).
    pub det: bool,
}

/// Build the operator reference — one [`OperatorRef`] per configured operator, in
/// config order. Consumed by both `nlir help` (native CLI) and the wasm
/// `operators()` export, so the reference is the anti-drift shared source of the
/// operator vocabulary (nlir-wasm epic bd-360d0c).
#[must_use]
pub fn operator_reference(config: &Config) -> Vec<OperatorRef> {
    config
        .operators
        .iter()
        .map(|(name, op)| OperatorRef {
            op: op.op.clone(),
            name: name.clone(),
            description: op.summary(),
            arity: match op.arity {
                Arity::Exact(n) => n.to_string(),
                Arity::Variadic => ">0".to_string(),
            },
            fixity: op.fixity.as_str().to_string(),
            priority: op.priority,
            det: op.is_deterministic(),
        })
        .collect()
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

impl Fixity {
    /// The lowercase name of this fixity class (`"prefix"` / `"infix"` /
    /// `"postfix"` / `"mixfix"`) — the string form surfaced by
    /// [`operator_reference`] and `nlir help`.
    #[must_use]
    pub fn as_str(&self) -> &'static str {
        match self {
            Fixity::Prefix => "prefix",
            Fixity::Postfix => "postfix",
            Fixity::Infix => "infix",
            Fixity::Mixfix => "mixfix",
        }
    }
}

/// Operator associativity for equal-precedence binary chains (SPEC §Grammar &
/// parsing). Only meaningful for `infix` operators. `left` groups `a-b-c` as
/// `(a-b)-c` (the default, matching normal math for `- /`); `right` groups
/// `a**b**c` as `a**(b**c)` (matching normal math and Python for exponentiation).
/// Mixfix operators flatten same-op chains into one n-ary node, so associativity
/// does not change their parse.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Assoc {
    /// Left-associative: `a op b op c` == `(a op b) op c` (default).
    #[default]
    Left,
    /// Right-associative: `a op b op c` == `a op (b op c)` (e.g. `**`).
    Right,
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
    /// An insertion-ordered dictionary/record: string-keyed `key=value` pairs
    /// (`{k=v, k2=v2}`). A new Value variant (bd-27739b); the polymorphic `.`
    /// accessor reads a key. Coerces to string as its rendered pairs; `→ number`
    /// and `→ bool` are loud errors (a dict is never a number/bool), the same
    /// discipline as `list → number`.
    Dict,
    /// A quoted form value (`{…}`) — an unevaluated expression carried as data
    /// (code-as-data). Only the application operator (`%`) consumes a form as
    /// *callable*; every other operator sees its rendered inner source (op×Form).
    Form,
}

impl TypeName {
    /// The lowercase config/SPEC spelling of this type (`string` / `number` /
    /// `bool` / `list`), matching the `#[serde(rename_all = "lowercase")]`
    /// wire form. Handy for error messages in the value/coercion layers.
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            TypeName::String => "string",
            TypeName::Number => "number",
            TypeName::Bool => "bool",
            TypeName::List => "list",
            TypeName::Dict => "dict",
            TypeName::Form => "form",
        }
    }
}

impl fmt::Display for TypeName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
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
    /// String concatenation (`++`, variadic).
    Concat,
    /// Split a string by a separator into a list (`//`, binary).
    Split,
    /// Value equality (`==`, binary): true when the two operands render equal.
    Eq,
    /// Value inequality (`!=`, binary): true when the two operands render unequal.
    Ne,
    /// Numeric less-than-or-equal (`<=`, binary) → bool.
    Le,
    /// Numeric greater-than-or-equal (`>=`, binary) → bool.
    Ge,
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
///
/// Defaults to the SPEC canonical role mapping (SPEC §Example config `views:`):
/// `^`=[assistant], `^_`=[user], `^*`=[user, assistant, system], `^/`=[system].
/// A config that omits `views:` (or an individual view) gets these; an
/// explicitly-empty view means "no roles" (matches nothing). This is the single
/// source of the built-in view defaults (bd-127396) — the messages layer reads
/// them straight through, no fallback.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
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
    /// `^!` — roles for the tool/code view (tool-call results + code messages).
    pub tool: Vec<String>,
}

impl Default for MessageViews {
    fn default() -> Self {
        Self {
            default: vec!["assistant".to_owned()],
            user: vec!["user".to_owned()],
            all: vec![
                "user".to_owned(),
                "assistant".to_owned(),
                "system".to_owned(),
            ],
            system: vec!["system".to_owned()],
            tool: vec![
                "tool".to_owned(),
                "tool_result".to_owned(),
                "function".to_owned(),
            ],
        }
    }
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

// ---------------------------------------------------------------------------
// discovery & load (bd-a1501f)
// ---------------------------------------------------------------------------

/// The config directory name under the user config root (`~/.config/<dir>`).
pub const CONFIG_DIR_NAME: &str = "nlir";
/// The config file name (`~/.config/nlir/<file>`).
pub const CONFIG_FILE_NAME: &str = "config.yaml";

/// The default config path: `$XDG_CONFIG_HOME/nlir/config.yaml`, else
/// `~/.config/nlir/config.yaml` (SPEC §CLI surface). `None` when neither
/// `XDG_CONFIG_HOME` nor `HOME` is set.
#[must_use]
pub fn default_config_path() -> Option<PathBuf> {
    config_path_from_env(
        std::env::var_os("XDG_CONFIG_HOME").as_deref(),
        std::env::var_os("HOME").as_deref(),
    )
}

/// Pure core of [`default_config_path`], taking the env values explicitly so it
/// is testable without env mutation (which is `unsafe` under
/// `unsafe_code = "forbid"`).
#[must_use]
fn config_path_from_env(xdg_config_home: Option<&OsStr>, home: Option<&OsStr>) -> Option<PathBuf> {
    if let Some(xdg) = xdg_config_home {
        if !xdg.is_empty() {
            return Some(
                PathBuf::from(xdg)
                    .join(CONFIG_DIR_NAME)
                    .join(CONFIG_FILE_NAME),
            );
        }
    }
    let home = home.filter(|h| !h.is_empty())?;
    Some(
        PathBuf::from(home)
            .join(".config")
            .join(CONFIG_DIR_NAME)
            .join(CONFIG_FILE_NAME),
    )
}

/// Resolve the config path: an explicit `--config PATH` wins; otherwise the
/// default path (which may be `None` if no home is discoverable).
#[must_use]
pub fn resolve_config_path(explicit: Option<&Path>) -> Option<PathBuf> {
    match explicit {
        Some(p) => Some(p.to_path_buf()),
        None => default_config_path(),
    }
}

/// The starter config nlir writes on first run: the shipped `config.example.yaml`
/// (the full SPEC example — operators, models, prompts, coercions, and tests).
pub const EXAMPLE_CONFIG: &str = include_str!("../config.example.yaml");

/// Scaffold the default config on first run: when [`default_config_path`]
/// resolves and no file exists there yet, create the parent directory and write
/// [`EXAMPLE_CONFIG`]. Returns the written path, or `None` when a config already
/// exists (never overwritten) or no home is discoverable.
///
/// # Errors
/// Propagates directory-create / write I/O errors.
pub fn scaffold_default_config() -> io::Result<Option<PathBuf>> {
    match default_config_path() {
        Some(path) => scaffold_config_at(&path).map(|written| written.then_some(path)),
        None => Ok(None),
    }
}

/// Testable core of [`scaffold_default_config`]: write [`EXAMPLE_CONFIG`] to
/// `path` if it does not already exist, creating parent directories. Returns
/// whether a file was written (`false` when one already existed).
fn scaffold_config_at(path: &Path) -> io::Result<bool> {
    if path.exists() {
        return Ok(false);
    }
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, EXAMPLE_CONFIG)?;
    Ok(true)
}

/// A config discovery / load error, carrying the offending path for clear
/// operator-facing diagnostics.
#[derive(Debug)]
pub enum ConfigError {
    /// An explicitly requested config file does not exist.
    NotFound(PathBuf),
    /// The config file could not be read (permissions, I/O, …).
    Read { path: PathBuf, source: io::Error },
    /// The config file is malformed YAML / fails the schema.
    Parse {
        path: PathBuf,
        source: serde_yaml::Error,
    },
    /// The config parsed but failed semantic validation (bd-cef403).
    Invalid {
        path: PathBuf,
        issues: Vec<ValidationError>,
    },
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConfigError::NotFound(path) => {
                write!(f, "config file not found: {}", path.display())
            }
            ConfigError::Read { path, source } => {
                write!(f, "failed to read config {}: {source}", path.display())
            }
            ConfigError::Parse { path, source } => {
                write!(f, "failed to parse config {}: {source}", path.display())?;
                // A `deny_unknown_fields` rejection almost always means the
                // running nlir binary is OLDER than this config: the field
                // exists in a newer schema this build predates, so one additive
                // config field looks like a totally broken config. Surface the
                // real cause + remedy instead of a bare serde "unknown field"
                // (bd-1b95db; aur-1 addendum: the opaque error misleads agents
                // into a confidently-wrong "the config is broken" diagnosis).
                if source.to_string().contains("unknown field") {
                    write!(
                        f,
                        "\n  hint: this field is unknown to THIS nlir build — your binary is likely older than the config schema (an additive field landed after it was built). Rebuild/update nlir (e.g. `just sync-install`), or remove the field if it is a typo."
                    )?;
                }
                Ok(())
            }
            ConfigError::Invalid { path, issues } => {
                writeln!(
                    f,
                    "invalid config {} ({} issue(s)):",
                    path.display(),
                    issues.len()
                )?;
                for issue in issues {
                    writeln!(f, "  - {issue}")?;
                }
                Ok(())
            }
        }
    }
}

impl std::error::Error for ConfigError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            ConfigError::NotFound(_) => None,
            ConfigError::Read { source, .. } => Some(source),
            ConfigError::Parse { source, .. } => Some(source),
            ConfigError::Invalid { .. } => None,
        }
    }
}

/// Load the config: an explicit `--config PATH` is required-to-exist; the
/// default path is optional (a missing default yields [`Config::default`], i.e.
/// builtins-only, since the whole language otherwise lives in config). Missing
/// explicit paths and malformed configs are loud errors with the path attached.
pub fn load(explicit: Option<&Path>) -> Result<Config, ConfigError> {
    match explicit {
        Some(path) => load_file(path),
        None => match default_config_path() {
            Some(path) if path.is_file() => load_file(&path),
            _ => Ok(Config::default()),
        },
    }
}

/// Read and parse a config file, then run semantic [`validate`] (bd-cef403),
/// mapping I/O, parse, and validation failures to [`ConfigError`] with the path
/// attached.
pub fn load_file(path: &Path) -> Result<Config, ConfigError> {
    let text = fs::read_to_string(path).map_err(|source| {
        if source.kind() == io::ErrorKind::NotFound {
            ConfigError::NotFound(path.to_path_buf())
        } else {
            ConfigError::Read {
                path: path.to_path_buf(),
                source,
            }
        }
    })?;
    let config = parse_str(&text, path)?;
    let issues = validate(&config);
    if issues.is_empty() {
        Ok(config)
    } else {
        Err(ConfigError::Invalid {
            path: path.to_path_buf(),
            issues,
        })
    }
}

/// Parse config from a YAML string, interpolating OS-env references at load
/// (SPEC §Prompt templating layer 1). `path` is only used for error context.
pub fn parse_str(yaml: &str, path: &Path) -> Result<Config, ConfigError> {
    parse_str_with_env(yaml, path, &|name| std::env::var(name).ok())
}

/// Testable core of [`parse_str`]: parse the YAML, interpolate `$FOO`/`${FOO}`
/// OS-env references (using `lookup`) in every string scalar, then deserialize
/// into [`Config`]. Taking `lookup` explicitly keeps tests hermetic without env
/// mutation (which is `unsafe` under `unsafe_code = "forbid"`).
///
/// Interpolation rules (bd-7b1dd4):
/// - `$NAME` and `${NAME}` are replaced with the OS-env value of `NAME`.
/// - `NLIR_`-prefixed names are ENGINE-INTERNAL and are left literal here
///   (they are resolved later during prompt/command assembly).
/// - An unset (non-`NLIR_`) variable is left literal, so a missing secret is a
///   visible `$NAME` for the validation layer rather than a silent empty.
/// - `$` not starting a valid name (e.g. `$(`, `$5`, `$((`) is left literal, so
///   embedded bash in `command:` scripts survives to run-time.
pub fn parse_str_with_env(
    yaml: &str,
    path: &Path,
    lookup: &dyn Fn(&str) -> Option<String>,
) -> Result<Config, ConfigError> {
    let mut value: serde_yaml::Value =
        serde_yaml::from_str(yaml).map_err(|source| ConfigError::Parse {
            path: path.to_path_buf(),
            source,
        })?;
    interpolate_value(&mut value, lookup);
    serde_yaml::from_value(value).map_err(|source| ConfigError::Parse {
        path: path.to_path_buf(),
        source,
    })
}

/// Recursively interpolate OS-env references in every string scalar of a YAML
/// value tree. Mapping KEYS are left untouched (they are fixed identifiers).
fn interpolate_value(value: &mut serde_yaml::Value, lookup: &dyn Fn(&str) -> Option<String>) {
    match value {
        serde_yaml::Value::String(s) if s.contains('$') => {
            *s = interpolate_str(s, lookup);
        }
        serde_yaml::Value::Sequence(seq) => {
            for item in seq.iter_mut() {
                interpolate_value(item, lookup);
            }
        }
        serde_yaml::Value::Mapping(map) => {
            for (key, val) in map.iter_mut() {
                // `command:` values are bash scripts (SPEC command realisation);
                // bash does its own `$var` expansion, so config env-interp must
                // NOT touch them — otherwise a bare shell `$out`/`$PWD`-style var
                // that collides with a SET env var is clobbered (bd-a31ff7).
                if key.as_str() == Some("command") {
                    continue;
                }
                interpolate_value(val, lookup);
            }
        }
        _ => {}
    }
}

/// True when `name` is a valid POSIX-ish env var name: `[A-Za-z_][A-Za-z0-9_]*`.
fn is_valid_env_name(name: &str) -> bool {
    let mut chars = name.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

/// Resolve a single reference: `NLIR_`-prefixed and unset names fall back to the
/// original literal text (`original`), otherwise the OS-env value is used.
fn substitute(name: &str, original: &str, lookup: &dyn Fn(&str) -> Option<String>) -> String {
    if name.starts_with("NLIR_") {
        return original.to_owned();
    }
    lookup(name).unwrap_or_else(|| original.to_owned())
}

/// Interpolate `$NAME` / `${NAME}` references in one string (see
/// [`parse_str_with_env`] for the rules).
fn interpolate_str(input: &str, lookup: &dyn Fn(&str) -> Option<String>) -> String {
    let mut out = String::with_capacity(input.len());
    let mut chars = input.chars().peekable();
    while let Some(c) = chars.next() {
        if c != '$' {
            out.push(c);
            continue;
        }
        match chars.peek().copied() {
            // ${NAME}
            Some('{') => {
                chars.next(); // consume '{'
                let mut name = String::new();
                let mut closed = false;
                while let Some(&nc) = chars.peek() {
                    if nc == '}' {
                        chars.next();
                        closed = true;
                        break;
                    }
                    name.push(nc);
                    chars.next();
                }
                if closed && is_valid_env_name(&name) {
                    out.push_str(&substitute(&name, &format!("${{{name}}}"), lookup));
                } else {
                    out.push_str("${");
                    out.push_str(&name);
                    if closed {
                        out.push('}');
                    }
                }
            }
            // $NAME
            Some(nc) if nc.is_ascii_alphabetic() || nc == '_' => {
                let mut name = String::new();
                while let Some(&nc) = chars.peek() {
                    if nc.is_ascii_alphanumeric() || nc == '_' {
                        name.push(nc);
                        chars.next();
                    } else {
                        break;
                    }
                }
                out.push_str(&substitute(&name, &format!("${name}"), lookup));
            }
            // bare '$' not starting a name (e.g. `$(`, `$5`, end of string)
            _ => out.push('$'),
        }
    }
    out
}

// ---------------------------------------------------------------------------
// validation (bd-cef403)
// ---------------------------------------------------------------------------

/// Builtin sigils reserved by the engine (SPEC §Builtins). A configured operator
/// `op` may not contain any of these, or it would shadow a builtin.
pub const RESERVED_SIGILS: &[char] = &[
    ';', '$', '^', '=', '[', ']', ',', '(', ')', '`', '"', '\'', '\\',
];

/// One semantic validation problem, with a dotted `location` into the config.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ValidationError {
    /// Dotted config location, e.g. `operators.subject` or `defaults.model`.
    pub location: String,
    /// Human-readable description of the problem.
    pub message: String,
}

impl ValidationError {
    fn new(location: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            location: location.into(),
            message: message.into(),
        }
    }
}

impl fmt::Display for ValidationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.location, self.message)
    }
}

/// Semantically validate a parsed [`Config`] (bd-cef403). Returns every problem
/// found (an empty vec means the config is valid). Structural/unknown-key errors
/// are already rejected at parse time by `deny_unknown_fields`; this layer adds
/// cross-field and referential checks: operator op/arity/fixity sanity,
/// reserved-sigil collisions, duplicate ops, realisation presence, model-kind
/// required fields, model-reference integrity, and `parallelism >= 1`.
/// Whether `alias` names a defined model, or a tier (`small`/`medium`/`large`)
/// set in `defaults.model` — used to validate an operator/type `model:` field,
/// which may reference a tier rather than a concrete model.
fn model_alias_is_valid(config: &Config, alias: &str) -> bool {
    config.models.contains_key(alias)
        || config
            .defaults
            .model
            .as_ref()
            .and_then(|d| d.tier(alias))
            .is_some()
}

#[must_use]
pub fn validate(config: &Config) -> Vec<ValidationError> {
    let mut errs = Vec::new();

    if config.defaults.parallelism == 0 {
        errs.push(ValidationError::new("defaults.parallelism", "must be >= 1"));
    }
    if let Some(default_model) = &config.defaults.model {
        for alias in default_model.referenced_aliases() {
            if !config.models.contains_key(alias) {
                errs.push(ValidationError::new(
                    "defaults.model",
                    format!("references unknown model {alias:?}"),
                ));
            }
        }
    }

    for (name, model) in &config.models {
        let loc = format!("models.{name}");
        match model.kind {
            ModelKind::Command => {
                if model.command.as_deref().is_none_or(str::is_empty) {
                    errs.push(ValidationError::new(
                        &loc,
                        "type: command requires a non-empty `command`",
                    ));
                }
            }
            ModelKind::AnthropicMessages => {
                if model.base_url.as_deref().is_none_or(str::is_empty) {
                    errs.push(ValidationError::new(
                        &loc,
                        "type: anthropic_messages requires `base_url`",
                    ));
                }
                if model.model.as_deref().is_none_or(str::is_empty) {
                    errs.push(ValidationError::new(
                        &loc,
                        "type: anthropic_messages requires `model`",
                    ));
                }
            }
        }
    }

    let mut seen_ops: BTreeMap<&str, &str> = BTreeMap::new();
    for (name, op) in &config.operators {
        let loc = format!("operators.{name}");
        if op.op.is_empty() {
            errs.push(ValidationError::new(&loc, "`op` must not be empty"));
        } else {
            // The lexer dispatches on the FIRST char: a hardcoded builtin sigil is
            // intercepted before operator longest-match, so an op that STARTS with
            // one cannot lex and is rejected — EXCEPT a multi-char op starting with
            // `=`, which the lexer longest-matches (`==`) while keeping a lone `=`
            // as assignment (msm-0 @3b9a291). A reserved char in a LATER position
            // (`>=`, `<=`, `!=` extending `>` `<` `!`) is fine: longest-match
            // consumes the whole sigil from its non-reserved first char.
            let first = op.op.chars().next();
            let single = op.op.chars().count() == 1;
            if first.is_some_and(|c| RESERVED_SIGILS.contains(&c) && (c != '=' || single)) {
                errs.push(ValidationError::new(
                    &loc,
                    format!("op {:?} collides with a reserved builtin sigil", op.op),
                ));
            }
            if let Some(prev) = seen_ops.get(op.op.as_str()) {
                errs.push(ValidationError::new(
                    &loc,
                    format!("op {:?} duplicates operator {prev:?}", op.op),
                ));
            } else {
                seen_ops.insert(op.op.as_str(), name.as_str());
            }
        }

        match op.fixity {
            Fixity::Prefix | Fixity::Postfix => {
                if op.arity != Arity::Exact(1) {
                    errs.push(ValidationError::new(
                        &loc,
                        format!("{:?} operator must have arity 1", op.fixity),
                    ));
                }
            }
            Fixity::Infix => {
                if op.arity != Arity::Exact(2) {
                    errs.push(ValidationError::new(
                        &loc,
                        "infix operator must have arity 2",
                    ));
                }
            }
            Fixity::Mixfix => {
                if op.arity != Arity::Variadic {
                    errs.push(ValidationError::new(
                        &loc,
                        "mixfix operator must have arity \">0\"",
                    ));
                }
            }
        }

        // Associativity only changes the parse of equal-precedence `infix`
        // chains; mixfix operators flatten same-op chains, and prefix/postfix
        // are unary, so `assoc: right` there is a config mistake (bd-df62f1).
        if op.assoc == Assoc::Right && op.fixity != Fixity::Infix {
            errs.push(ValidationError::new(
                &loc,
                "assoc: right is only meaningful for infix operators",
            ));
        }

        let has_realisation = op.command.is_some()
            || op.reduce.is_some()
            || op.template.is_some()
            || op.join.is_some()
            || op.model.is_some()
            || op.prompt.is_some()
            || op.form.is_some()
            || op.builtin.is_some()
            || op.det.is_some();
        if !has_realisation {
            errs.push(ValidationError::new(
                &loc,
                "operator has no realisation (need command/reduce/template/join/form/builtin or model+prompt)",
            ));
        }
        // A `builtin:` operator (bd-44c294) must name a known higher-order builtin.
        if let Some(builtin) = &op.builtin {
            if !matches!(
                builtin.as_str(),
                "map" | "fold" | "access" | "union" | "inter" | "diff" | "elem" | "and" | "or"
            ) {
                errs.push(ValidationError::new(
                    &loc,
                    format!("builtin {builtin:?} is unknown (expected `map`, `fold`, `access`, `union`, `inter`, `diff`, `elem`, `and`, or `or`)"),
                ));
            }
        }

        if let Some(model) = &op.model {
            if !model_alias_is_valid(config, model) {
                errs.push(ValidationError::new(
                    &loc,
                    format!("model {model:?} is not defined in `models` (or a configured tier)"),
                ));
            }
        }
    }

    for (name, ty) in &config.types {
        if let Some(model) = &ty.model {
            if !model_alias_is_valid(config, model) {
                errs.push(ValidationError::new(
                    format!("types.{name}"),
                    format!("model {model:?} is not defined in `models` (or a configured tier)"),
                ));
            }
        }
    }

    errs
}

// ---------------------------------------------------------------------------
// defaults resolution (bd-d0db40)
// ---------------------------------------------------------------------------

/// Caller (CLI) overrides for the resolvable run defaults. Each `Some` wins over
/// the corresponding config value.
#[derive(Debug, Clone, Default)]
pub struct DefaultOverrides {
    /// `--mode det|llm`.
    pub mode: Option<Mode>,
    /// `--model NAME`.
    pub model: Option<String>,
    /// `--parallelism N`.
    pub parallelism: Option<usize>,
}

/// The effective run settings after merging CLI overrides over config defaults
/// (SPEC §Modes; §Execution graph & parallelism; §Runtime state).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResolvedDefaults {
    /// Effective evaluation mode.
    pub mode: Mode,
    /// Effective default model name (a key into `models`), if any.
    pub model: Option<String>,
    /// Effective DAG scheduler parallelism.
    pub parallelism: usize,
    /// Effective list / message-range separator (context `_sep`).
    pub sep: String,
    /// Effective caching flag (context `_cache`).
    pub cache: bool,
}

/// Resolve the effective run settings. Precedence is CLI override →
/// `config.defaults` / `config.context.defaults` → built-in defaults (the latter
/// two already carry the built-ins: `mode: llm`, `parallelism: 8`, `_sep: "\n"`,
/// `_cache: true`, via [`Defaults`] / [`ContextDefaults`]). `_sep`/`_cache` have
/// no CLI flags — they come from config and may be further overridden at runtime
/// by context `=` writes (the context epic).
#[must_use]
pub fn resolve_defaults(config: &Config, overrides: &DefaultOverrides) -> ResolvedDefaults {
    ResolvedDefaults {
        mode: overrides.mode.unwrap_or(config.defaults.mode),
        model: overrides.model.clone().or_else(|| {
            config
                .defaults
                .model
                .as_ref()
                .and_then(DefaultModel::default_alias)
                .map(str::to_owned)
        }),
        parallelism: overrides.parallelism.unwrap_or(config.defaults.parallelism),
        sep: config.context.defaults.sep.clone(),
        cache: config.context.defaults.cache,
    }
}

/// The configured operator sigils (SPEC §Config operators), for the lexer's
/// longest-match tokenising (bd-16d8fc).
#[must_use]
pub fn operator_sigils(config: &Config) -> Vec<String> {
    config.operators.values().map(|op| op.op.clone()).collect()
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
        assert_eq!(
            cfg.defaults
                .model
                .as_ref()
                .and_then(DefaultModel::default_alias),
            Some("haiku")
        );
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

    #[test]
    fn config_path_prefers_xdg_then_home() {
        // XDG_CONFIG_HOME wins when set.
        let p = config_path_from_env(Some(OsStr::new("/x/cfg")), Some(OsStr::new("/home/u")))
            .expect("xdg path");
        assert!(p.ends_with("nlir/config.yaml"));
        assert!(p.starts_with("/x/cfg"));

        // Falls back to ~/.config when XDG unset/empty.
        let p = config_path_from_env(None, Some(OsStr::new("/home/u"))).expect("home path");
        assert_eq!(p, PathBuf::from("/home/u/.config/nlir/config.yaml"));
        let p = config_path_from_env(Some(OsStr::new("")), Some(OsStr::new("/home/u")))
            .expect("empty xdg falls back to home");
        assert_eq!(p, PathBuf::from("/home/u/.config/nlir/config.yaml"));

        // No home discoverable → None.
        assert!(config_path_from_env(None, None).is_none());
        assert!(config_path_from_env(Some(OsStr::new("")), Some(OsStr::new(""))).is_none());
    }

    #[test]
    fn resolve_config_path_prefers_explicit() {
        let explicit = Path::new("/tmp/explicit-nlir.yaml");
        assert_eq!(
            resolve_config_path(Some(explicit)),
            Some(explicit.to_path_buf())
        );
    }

    #[test]
    fn explicit_missing_config_is_not_found() {
        let missing = Path::new("/nonexistent/nlir-does-not-exist-xyz.yaml");
        match load(Some(missing)) {
            Err(ConfigError::NotFound(p)) => assert_eq!(p, missing.to_path_buf()),
            other => panic!("expected NotFound, got {other:?}"),
        }
    }

    #[test]
    fn malformed_config_is_a_parse_error_with_path() {
        let path = Path::new("/some/where/config.yaml");
        let err = parse_str("operators: [not, a, map]", path).unwrap_err();
        match &err {
            ConfigError::Parse { path: p, .. } => assert_eq!(p, path),
            other => panic!("expected Parse, got {other:?}"),
        }
        // Diagnostic carries the path for the operator.
        assert!(err.to_string().contains("config.yaml"));
    }

    #[test]
    fn unknown_field_parse_error_hints_at_binary_drift() {
        // A field the running build does not know (deny_unknown_fields) — the
        // exact symptom of a stale binary vs a newer config schema (bd-1b95db).
        let path = Path::new("/some/where/config.yaml");
        let err = parse_str("bogus_new_field: 1\n", path).unwrap_err();
        let msg = err.to_string();
        // Still surfaces the underlying serde "unknown field" diagnosis...
        assert!(msg.contains("unknown field"), "message: {msg}");
        // ...plus the actionable binary-drift hint + remedy, so an agent does
        // not misdiagnose a stale binary as "the config is broken".
        assert!(
            msg.contains("older than the config schema"),
            "expected binary-drift hint, got: {msg}"
        );
        assert!(msg.contains("Rebuild/update nlir"), "message: {msg}");
    }

    #[test]
    fn load_file_round_trips_a_real_file() {
        let tmp = crate::test_support::TempPath::new("nlir-cfg", "yaml");
        let path = tmp.path();
        fs::write(path, "defaults:\n  mode: det\n  parallelism: 4\n").expect("write temp config");

        let cfg = load(Some(path)).expect("load temp config");
        assert_eq!(cfg.defaults.mode, Mode::Det);
        assert_eq!(cfg.defaults.parallelism, 4);
    }

    #[test]
    fn env_interpolation_resolves_os_vars_but_protects_nlir_and_unset() {
        let env = |name: &str| -> Option<String> {
            match name {
                "ANTHROPIC_API_KEY" => Some("sk-secret".to_owned()),
                "BASE" => Some("https://api.example.com".to_owned()),
                _ => None,
            }
        };
        let yaml = r##"
models:
  haiku:
    type: anthropic_messages
    base_url: ${BASE}/v1
    api_key: $ANTHROPIC_API_KEY
    messages:
      - role: system
        content: "${NLIR_SYSTEM_PROMPT} then $NLIR_PROMPT"
  echo:
    type: command
    command: 't="${NLIR_ARGS[0]}"; n=$UNSET_LOCAL; for i in $(seq 1 $((n-1))); do :; done'
"##;
        let cfg =
            parse_str_with_env(yaml, Path::new("cfg.yaml"), &env).expect("interpolates + parses");

        // Real OS vars resolve (both `${X}` and `$X`).
        assert_eq!(
            cfg.models["haiku"].base_url.as_deref(),
            Some("https://api.example.com/v1")
        );
        assert_eq!(cfg.models["haiku"].api_key.as_deref(), Some("sk-secret"));

        // NLIR_-prefixed engine-internal refs are left literal.
        assert_eq!(
            cfg.models["haiku"].messages[0].content,
            "${NLIR_SYSTEM_PROMPT} then $NLIR_PROMPT"
        );

        // command: NLIR arg + unset local + bash $(...) / $((...)) all survive.
        let cmd = cfg.models["echo"].command.as_deref().unwrap();
        assert!(cmd.contains("${NLIR_ARGS[0]}"), "cmd={cmd}");
        assert!(cmd.contains("$UNSET_LOCAL"), "cmd={cmd}");
        assert!(cmd.contains("$(seq 1 $((n-1)))"), "cmd={cmd}");
    }

    #[test]
    fn command_blocks_are_not_env_interpolated() {
        // A bash `$out` in a command: block must survive config interp even when
        // `out` is a SET env var (the nix dev-shell exports it) — bd-a31ff7.
        let env = |name: &str| -> Option<String> {
            match name {
                "out" => Some("/nix/store/xxx/outputs/out".to_owned()),
                "ANTHROPIC_API_KEY" => Some("sk-secret".to_owned()),
                _ => None,
            }
        };
        let yaml = r##"
operators:
  echo:
    op: "_"
    arity: 2
    fixity: infix
    command: 'out="$t"; printf "%s" "$out"'
models:
  m:
    type: command
    command: 'run $out'
    api_key: $ANTHROPIC_API_KEY
"##;
        let cfg = parse_str_with_env(yaml, Path::new("cfg.yaml"), &env).expect("parses");
        // `$out` in command: blocks stays literal (bash owns it) for both the
        // operator and model command realisations.
        assert_eq!(
            cfg.operators["echo"].command.as_deref(),
            Some(r#"out="$t"; printf "%s" "$out""#)
        );
        assert_eq!(cfg.models["m"].command.as_deref(), Some("run $out"));
        // Non-command fields still interpolate SET os-env vars.
        assert_eq!(cfg.models["m"].api_key.as_deref(), Some("sk-secret"));
    }

    #[test]
    fn interpolate_str_edge_cases() {
        let env = |name: &str| -> Option<String> {
            match name {
                "FOO" => Some("bar".to_owned()),
                _ => None,
            }
        };
        assert_eq!(interpolate_str("a $FOO b", &env), "a bar b");
        assert_eq!(interpolate_str("pre${FOO}post", &env), "prebarpost");
        assert_eq!(interpolate_str("cost is $5", &env), "cost is $5");
        assert_eq!(interpolate_str("trailing $", &env), "trailing $");
        assert_eq!(interpolate_str("$MISSING kept", &env), "$MISSING kept");
        assert_eq!(interpolate_str("${NLIR_X}", &env), "${NLIR_X}");
        assert_eq!(interpolate_str("${unclosed", &env), "${unclosed");
        assert!(is_valid_env_name("FOO_1"));
        assert!(!is_valid_env_name("1FOO"));
        assert!(!is_valid_env_name(""));
    }

    #[test]
    fn sample_config_validates_clean() {
        let cfg: Config = serde_yaml::from_str(SAMPLE).unwrap();
        let issues = validate(&cfg);
        assert!(issues.is_empty(), "sample should be valid, got: {issues:?}");
    }

    #[test]
    fn reserved_sigil_and_duplicate_ops_are_rejected() {
        let cfg: Config = serde_yaml::from_str(
            r##"
operators:
  semi: { op: ";", arity: 1, fixity: prefix, template: "x" }
  a:    { op: "&", arity: ">0", fixity: mixfix, join: " and " }
  b:    { op: "&", arity: ">0", fixity: mixfix, join: " et " }
"##,
        )
        .unwrap();
        let issues = validate(&cfg);
        assert!(
            issues
                .iter()
                .any(|e| e.location == "operators.semi"
                    && e.message.contains("reserved builtin sigil")),
            "{issues:?}"
        );
        assert!(
            issues
                .iter()
                .any(|e| e.message.contains("duplicates operator")),
            "{issues:?}"
        );
    }

    #[test]
    fn fixity_arity_mismatches_are_rejected() {
        let cfg: Config = serde_yaml::from_str(
            r##"
operators:
  badinfix:  { op: "-", arity: 1, fixity: infix, reduce: sub }
  badmixfix: { op: "+", arity: 2, fixity: mixfix, reduce: add }
  badprefix: { op: "#", arity: 2, fixity: prefix, template: "x" }
"##,
        )
        .unwrap();
        let issues = validate(&cfg);
        assert!(
            issues
                .iter()
                .any(|e| e.location == "operators.badinfix" && e.message.contains("arity 2")),
            "{issues:?}"
        );
        assert!(
            issues
                .iter()
                .any(|e| e.location == "operators.badmixfix" && e.message.contains(">0")),
            "{issues:?}"
        );
        assert!(
            issues
                .iter()
                .any(|e| e.location == "operators.badprefix" && e.message.contains("arity 1")),
            "{issues:?}"
        );
    }

    #[test]
    fn assoc_right_only_on_infix_is_rejected() {
        // bd-df62f1: `assoc: right` only changes equal-precedence infix chains;
        // on prefix/postfix/mixfix it is a config mistake and must be rejected,
        // while a right-associative infix operator (like `**`) is valid.
        let cfg: Config = serde_yaml::from_str(
            r##"
operators:
  badprefixassoc: { op: "#", arity: 1, fixity: prefix, assoc: right, template: "x" }
  okpow:          { op: "**", arity: 2, fixity: infix, assoc: right, reduce: pow }
"##,
        )
        .unwrap();
        let issues = validate(&cfg);
        assert!(
            issues
                .iter()
                .any(|e| e.location == "operators.badprefixassoc"
                    && e.message
                        .contains("assoc: right is only meaningful for infix")),
            "{issues:?}"
        );
        assert!(
            !issues
                .iter()
                .any(|e| e.location == "operators.okpow" && e.message.contains("assoc")),
            "{issues:?}"
        );
    }

    #[test]
    fn missing_realisation_and_unknown_model_ref_rejected() {
        let cfg: Config = serde_yaml::from_str(
            r##"
operators:
  empty: { op: "@", arity: 1, fixity: prefix }
  refs:  { op: "~", arity: 1, fixity: prefix, model: nope, prompt: "%" }
"##,
        )
        .unwrap();
        let issues = validate(&cfg);
        assert!(
            issues
                .iter()
                .any(|e| e.location == "operators.empty" && e.message.contains("no realisation")),
            "{issues:?}"
        );
        assert!(
            issues
                .iter()
                .any(|e| e.location == "operators.refs"
                    && e.message.contains("not defined in `models`")),
            "{issues:?}"
        );
    }

    #[test]
    fn model_kind_required_fields_and_parallelism() {
        let cfg: Config = serde_yaml::from_str(
            r##"
defaults:
  parallelism: 0
models:
  cmd:  { type: command }
  http: { type: anthropic_messages }
"##,
        )
        .unwrap();
        let issues = validate(&cfg);
        assert!(
            issues.iter().any(|e| e.location == "defaults.parallelism"),
            "{issues:?}"
        );
        assert!(
            issues
                .iter()
                .any(|e| e.location == "models.cmd" && e.message.contains("command")),
            "{issues:?}"
        );
        assert!(
            issues
                .iter()
                .any(|e| e.location == "models.http" && e.message.contains("base_url")),
            "{issues:?}"
        );
        assert!(
            issues
                .iter()
                .any(|e| e.location == "models.http" && e.message.contains("model")),
            "{issues:?}"
        );
    }

    #[test]
    fn load_file_rejects_invalid_config() {
        let tmp = crate::test_support::TempPath::new("nlir-invalid", "yaml");
        let path = tmp.path();
        fs::write(
            path,
            "operators:\n  bad: { op: \";\", arity: 1, fixity: prefix, template: x }\n",
        )
        .expect("write temp config");
        match load(Some(path)) {
            Err(ConfigError::Invalid { issues, .. }) => assert!(!issues.is_empty()),
            other => panic!("expected Invalid, got {other:?}"),
        }
    }

    #[test]
    fn resolve_defaults_precedence() {
        // Empty config, no overrides -> built-in defaults.
        let cfg = Config::default();
        let r = resolve_defaults(&cfg, &DefaultOverrides::default());
        assert_eq!(r.mode, Mode::Llm);
        assert_eq!(r.model, None);
        assert_eq!(r.parallelism, crate::DEFAULT_PARALLELISM);
        assert_eq!(r.sep, "\n");
        assert!(r.cache);

        // Config values, no overrides.
        let cfg: Config = serde_yaml::from_str(
            r##"
defaults: { mode: det, model: haiku, parallelism: 4 }
context:
  defaults: { _sep: "|", _cache: false }
"##,
        )
        .unwrap();
        let r = resolve_defaults(&cfg, &DefaultOverrides::default());
        assert_eq!(r.mode, Mode::Det);
        assert_eq!(r.model.as_deref(), Some("haiku"));
        assert_eq!(r.parallelism, 4);
        assert_eq!(r.sep, "|");
        assert!(!r.cache);

        // CLI overrides win over config; sep/cache have no CLI flag so stay from config.
        let over = DefaultOverrides {
            mode: Some(Mode::Llm),
            model: Some("sonnet".to_owned()),
            parallelism: Some(16),
        };
        let r = resolve_defaults(&cfg, &over);
        assert_eq!(r.mode, Mode::Llm);
        assert_eq!(r.model.as_deref(), Some("sonnet"));
        assert_eq!(r.parallelism, 16);
        assert_eq!(r.sep, "|");
        assert!(!r.cache);
    }

    // --- example config + first-run scaffolding (bd-8523df) ---

    #[test]
    fn example_config_parses_and_validates() {
        // The shipped starter config must always deserialize and validate — this
        // guards config.example.yaml against schema drift (and CI enforces it).
        let cfg: Config =
            serde_yaml::from_str(EXAMPLE_CONFIG).expect("config.example.yaml must deserialize");
        let issues = validate(&cfg);
        assert!(
            issues.is_empty(),
            "shipped example config should validate, got: {issues:?}"
        );
    }

    #[test]
    fn example_config_is_the_complete_browser_fallback() {
        // The browser seeds DEFAULT_CONFIG from `default_config_yaml()` = this
        // EXAMPLE_CONFIG (nlir-wasm, bd-ca518b) — the REAL config, single source of
        // truth. Lock that it carries the COMPLETE operator set: the bd-799000 drift
        // dropped Δ / ~> / ~>? from the hand-written workspace fallback; the embedded
        // config must never, or the browser parser silently loses operators.
        let cfg: Config =
            serde_yaml::from_str(EXAMPLE_CONFIG).expect("example config must deserialize");
        let refs = operator_reference(&cfg);
        assert!(
            refs.len() >= 19,
            "browser fallback must carry the full operator set, got {}",
            refs.len()
        );
        for sig in ["\u{0394}", "~>", "~>?"] {
            assert!(
                refs.iter().any(|r| r.op == sig),
                "operator {sig} must be present in the browser fallback config"
            );
        }
    }

    #[test]
    fn operator_reference_matches_config_and_serializes() {
        // operator_reference() is the anti-drift shared source for `nlir help` and
        // the wasm operators() export (nlir-wasm bd-360d0c). Verify it derives the
        // contract shape {op, name, description, arity, priority, fixity, det}
        // correctly and serialises to JSON (JS reads the array).
        let cfg: Config =
            serde_yaml::from_str(EXAMPLE_CONFIG).expect("example config must deserialize");
        let refs = operator_reference(&cfg);
        assert_eq!(refs.len(), cfg.operators.len(), "one row per operator");

        let pow = refs.iter().find(|r| r.name == "pow").expect("pow present");
        assert_eq!(pow.op, "**");
        assert_eq!(pow.fixity, "infix");
        assert_eq!(pow.priority, Some(13));
        assert!(pow.det, "pow has a reduce realisation -> offline in det");
        assert!(!pow.description.is_empty());

        let subject = refs
            .iter()
            .find(|r| r.name == "subject")
            .expect("subject present");
        assert_eq!(subject.op, "#");
        assert_eq!(subject.fixity, "prefix");
        assert!(
            !subject.det,
            "subject is llm-PRIMARY (model+prompt); its det template is a test-mode stub for \
             det-coverage, not its identity, so it displays llm (det = has_det && model.is_none())"
        );

        let and = refs.iter().find(|r| r.name == "and").expect("and present");
        assert_eq!(and.arity, ">0", "variadic arity stringifies to >0");

        // Serialises to JSON (the wasm operators() path via serde_wasm_bindgen).
        let json = serde_json::to_string(&refs).expect("OperatorRef list must serialize to JSON");
        assert!(
            json.contains("\"det\""),
            "the det flag is in the JSON contract"
        );
    }

    #[test]
    fn config_roundtrips_through_json_for_wasm_boundary() {
        // nlir-wasm (epic bd-360d0c) takes config as JSON at the wasm boundary
        // (JS does YAML->JSON via js-yaml), then `serde_json::from_str::<Config>`.
        // serde_yaml lives only in the native loader, never in the `Config` type,
        // so `Config` must round-trip through JSON. This guards the boundary: a
        // serde_yaml-only field added to `Config` would silently break wasm.
        let cfg: Config =
            serde_yaml::from_str(EXAMPLE_CONFIG).expect("example config must deserialize");
        let json = serde_json::to_string(&cfg).expect("Config must serialize to JSON");
        let from_json: Config = serde_json::from_str(&json)
            .expect("Config must deserialize from JSON (nlir-wasm config-as-JSON boundary)");
        assert_eq!(
            cfg, from_json,
            "Config must round-trip through JSON so the nlir-wasm config-as-JSON boundary holds"
        );
        // A JSON-loaded config still evaluates deterministically (no realiser).
        let mut ctx = crate::context::Context::empty(&from_json.context);
        let value = crate::eval::evaluate("2+3*4", &from_json, &mut ctx, Mode::Det)
            .expect("det eval over a JSON-loaded config");
        assert_eq!(value.render(&ctx.sep()), "14");
    }

    #[test]
    fn scaffold_writes_when_missing_and_preserves_existing() {
        let tmp = crate::test_support::TempPath::new("nlir-scaffold", "");
        let dir = tmp.path();
        let path = dir.join("nlir").join("config.yaml");

        // First run: writes the example config and creates parent dirs.
        assert!(scaffold_config_at(&path).expect("scaffold write"));
        assert!(path.is_file());
        assert_eq!(fs::read_to_string(&path).unwrap(), EXAMPLE_CONFIG);

        // Second run: an existing config is preserved, never overwritten.
        fs::write(&path, "user: edits").unwrap();
        assert!(!scaffold_config_at(&path).expect("scaffold noop"));
        assert_eq!(fs::read_to_string(&path).unwrap(), "user: edits");
    }
}
