//! nlir context namespace store (SPEC §Runtime state: the `context` namespace).
//!
//! Context is a single JSON object holding all cross-run state: user keys plus
//! `_`-prefixed **system keys** (`_messages`, `_sep`, `_cache`). This module owns
//!
//! - **loading** that object with the SPEC source precedence
//!   (`--context-file` › `--session-file` merge › `NLIR_CONTEXT` env › default
//!   file) — bd-0909ab;
//! - **merging** updates into it (shallow, named-key replacement — SPEC
//!   `nlir set`: "each named key replaced (not deep-merged)") — bd-0909ab;
//! - resolving **system-key defaults** from config (`_sep` = `"\n"`,
//!   `_cache` = `true`) and exposing the `_messages` sub-namespace — bd-fdd3bc;
//! - **write-through**: mutations persist immediately to the active context file
//!   (SPEC: "context writes happen immediately").
//!
//! Scope boundary: `--session-file` *format parsing* (e.g. a Pi session → the
//! `_messages` array, honouring `keep_roles` / `drop_tool_messages`) lives in the
//! `sessions` epic (bd-720cdb / bd-000666). This store owns the precedence slot
//! and the [`Context::merge`] primitive that the sessions layer builds on: the
//! caller parses `--session-file` into a `Map` and hands it to
//! [`LoadSources::session`], which the store merges in the correct precedence
//! position. The store never interprets the session file format itself.

use std::ffi::OsStr;
use std::path::{Path, PathBuf};
use std::{fmt, fs, io};

use serde_json::{Map, Value};

use crate::config::ContextConfig;

// ---------------------------------------------------------------------------
// errors
// ---------------------------------------------------------------------------

/// A context load / write-through error, carrying the offending path for clear
/// operator-facing diagnostics (mirrors [`crate::config::ConfigError`]).
#[derive(Debug)]
pub enum ContextError {
    /// A context file could not be read (permissions, I/O — not a plain missing
    /// file, which loads as an empty object).
    Read { path: PathBuf, source: io::Error },
    /// A context source is malformed JSON. `path` is `None` for the inline
    /// `NLIR_CONTEXT` env source, which has no file.
    Parse {
        path: Option<PathBuf>,
        source: serde_json::Error,
    },
    /// A context source parsed as valid JSON but was not a top-level object
    /// (`{ … }`). Context is always one JSON object.
    NotObject { path: Option<PathBuf> },
    /// A write-through to the active context file failed.
    Write { path: PathBuf, source: io::Error },
}

impl fmt::Display for ContextError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ContextError::Read { path, source } => {
                write!(f, "failed to read context {}: {source}", path.display())
            }
            ContextError::Parse {
                path: Some(path),
                source,
            } => {
                write!(f, "failed to parse context {}: {source}", path.display())
            }
            ContextError::Parse { path: None, source } => {
                write!(f, "failed to parse NLIR_CONTEXT: {source}")
            }
            ContextError::NotObject { path: Some(path) } => {
                write!(f, "context {} is not a JSON object", path.display())
            }
            ContextError::NotObject { path: None } => {
                write!(f, "NLIR_CONTEXT is not a JSON object")
            }
            ContextError::Write { path, source } => {
                write!(f, "failed to write context {}: {source}", path.display())
            }
        }
    }
}

impl std::error::Error for ContextError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            ContextError::Read { source, .. } | ContextError::Write { source, .. } => Some(source),
            ContextError::Parse { source, .. } => Some(source),
            ContextError::NotObject { .. } => None,
        }
    }
}

// ---------------------------------------------------------------------------
// load sources (precedence inputs)
// ---------------------------------------------------------------------------

/// The resolved inputs to [`Context::load`], one per SPEC precedence slot.
///
/// The caller resolves the ambient environment (CLI flags, `NLIR_CONTEXT`,
/// config `file_default`) into these fields so the load logic itself stays pure
/// and testable — env reads are `unsafe`-adjacent under this crate's
/// `unsafe_code = "forbid"` and are kept out of the core (mirrors
/// [`crate::config`]'s pure-core split).
#[derive(Debug, Default)]
pub struct LoadSources<'a> {
    /// `--context-file PATH` — highest precedence; also the write-through target.
    pub context_file: Option<&'a Path>,
    /// A pre-parsed `--session-file` import (the `sessions` epic parses the file
    /// into an object; the store merges it in the precedence slot below
    /// `--context-file`). Transient: no file-backed write-through.
    pub session: Option<Map<String, Value>>,
    /// The inline `NLIR_CONTEXT` env value (a JSON object). Transient.
    pub env_inline: Option<&'a str>,
    /// The default context file (`context.file_default`, tilde-expanded). Loaded
    /// only when the higher-precedence slots are empty; write-through target.
    pub default_file: Option<&'a Path>,
}

// ---------------------------------------------------------------------------
// context store
// ---------------------------------------------------------------------------

/// The context namespace: one JSON object plus the config-derived system-key
/// metadata (messages key, role/content field names, `_sep` / `_cache`
/// defaults) and the active write-through file, if any.
#[derive(Debug, Clone, PartialEq)]
pub struct Context {
    /// The single JSON object holding all context state (user + system keys).
    data: Map<String, Value>,
    /// Active context file for write-through, or `None` for a transient store
    /// (inline env / session import with no file backing).
    file: Option<PathBuf>,
    /// Context key holding the messages array (config `messages.key`).
    messages_key: String,
    /// Field naming a message's role (config `messages.role_field`).
    role_field: String,
    /// Field naming a message's content (config `messages.content_field`).
    content_field: String,
    /// `_sep` default when the key is absent (config `defaults._sep`).
    sep_default: String,
    /// `_cache` default when the key is absent (config `defaults._cache`).
    cache_default: bool,
}

impl Context {
    /// Build a store from an already-resolved object + optional write-through
    /// file, pulling system-key metadata/defaults from `cfg`.
    fn from_parts(data: Map<String, Value>, file: Option<PathBuf>, cfg: &ContextConfig) -> Self {
        Self {
            data,
            file,
            messages_key: cfg.messages.key.clone(),
            role_field: cfg.messages.role_field.clone(),
            content_field: cfg.messages.content_field.clone(),
            sep_default: cfg.defaults.sep.clone(),
            cache_default: cfg.defaults.cache,
        }
    }

    /// An empty transient store carrying only `cfg`'s system-key metadata.
    #[must_use]
    pub fn empty(cfg: &ContextConfig) -> Self {
        Self::from_parts(Map::new(), None, cfg)
    }

    /// Load the context object by SPEC source precedence (bd-0909ab):
    ///
    /// 1. `--context-file` — load that file (missing file → empty object;
    ///    write-through target).
    /// 2. `--session-file` — merge the pre-parsed session object (transient).
    /// 3. `NLIR_CONTEXT` env — parse the inline JSON object (transient).
    /// 4. default file — load if present (missing → empty; write-through target).
    /// 5. nothing configured — an empty transient store.
    ///
    /// A missing file is *not* an error (it becomes an empty object created on
    /// first write); unreadable files, malformed JSON, and non-object JSON are
    /// loud errors with the path attached.
    pub fn load(sources: LoadSources<'_>, cfg: &ContextConfig) -> Result<Self, ContextError> {
        if let Some(path) = sources.context_file {
            let data = read_object_or_empty(path)?;
            return Ok(Self::from_parts(data, Some(path.to_path_buf()), cfg));
        }
        if let Some(session) = sources.session {
            return Ok(Self::from_parts(session, None, cfg));
        }
        if let Some(inline) = sources.env_inline {
            let data = parse_object(inline, None)?;
            return Ok(Self::from_parts(data, None, cfg));
        }
        if let Some(path) = sources.default_file {
            let data = read_object_or_empty(path)?;
            return Ok(Self::from_parts(data, Some(path.to_path_buf()), cfg));
        }
        Ok(Self::from_parts(Map::new(), None, cfg))
    }

    // -- merge -------------------------------------------------------------

    /// Merge `other` into this context by **shallow named-key replacement**
    /// (SPEC `nlir set`: "each named key replaced (not deep-merged)"). This is
    /// the primitive `nlir set '{…}'` and the `sessions` epic build on. Does
    /// **not** write through — callers pair it with [`Context::save`] when they
    /// want the merge persisted.
    pub fn merge(&mut self, other: Map<String, Value>) {
        for (key, value) in other {
            self.data.insert(key, value);
        }
    }

    // -- system keys & defaults (bd-fdd3bc) --------------------------------

    /// The list/message-range text separator: `_sep` if set, else the config
    /// default (`"\n"`).
    #[must_use]
    pub fn sep(&self) -> String {
        self.data
            .get("_sep")
            .and_then(Value::as_str)
            .map_or_else(|| self.sep_default.clone(), str::to_owned)
    }

    /// Whether subcall/coercion caching is on: `_cache` if set, else the config
    /// default (`true`).
    ///
    /// Accepts either a JSON bool or the strings `"true"`/`"false"`, since an
    /// in-expression `_cache=false` assignment stores the bare literal as a
    /// string (SPEC bool coercion of `"true"`/`"false"`).
    #[must_use]
    pub fn cache(&self) -> bool {
        match self.data.get("_cache") {
            Some(Value::Bool(flag)) => *flag,
            Some(Value::String(text)) => match text.trim() {
                "true" => true,
                "false" => false,
                _ => self.cache_default,
            },
            _ => self.cache_default,
        }
    }

    /// The `_messages` array (empty when absent or not an array). The key is
    /// config-defined (`messages.key`, default `_messages`).
    #[must_use]
    pub fn messages(&self) -> &[Value] {
        self.data
            .get(&self.messages_key)
            .and_then(Value::as_array)
            .map_or(&[], Vec::as_slice)
    }

    /// The configured `_messages` key name.
    #[must_use]
    pub fn messages_key(&self) -> &str {
        &self.messages_key
    }

    /// Whether `key` is a system key (`_`-prefixed, e.g. `_messages`, `_sep`,
    /// `_cache`).
    #[must_use]
    pub fn is_system_key(key: &str) -> bool {
        key.starts_with('_')
    }

    // -- reads -------------------------------------------------------------

    /// Read a raw context value by key (`None` when absent). System keys read
    /// like any other; use [`Context::sep`] / [`Context::cache`] for the
    /// default-applying accessors.
    #[must_use]
    pub fn get(&self, key: &str) -> Option<&Value> {
        self.data.get(key)
    }

    /// Render a context key's value as `$name` interpolation would (a string is
    /// the raw text; a list joins its elements with `_sep`); `None` if the key
    /// is absent. Used by `nlir get` (bd-f60fac).
    #[must_use]
    pub fn render_key(&self, key: &str) -> Option<String> {
        let sep = self.sep();
        self.data.get(key).map(|value| render_json(value, &sep))
    }

    /// The whole context object (read-only).
    #[must_use]
    pub fn data(&self) -> &Map<String, Value> {
        &self.data
    }

    /// The active write-through file, if any.
    #[must_use]
    pub fn file(&self) -> Option<&Path> {
        self.file.as_deref()
    }

    /// Interpolate bare `$name` context reads in `text` (SPEC §Interpolation:
    /// only a bare `$name` interpolates inside `"…"` — not `${…}`, `$N`, `^…`).
    /// Each `$name` is replaced by the rendered context value (lists joined with
    /// `_sep`); an unknown name is left literal. This is the greedy eval-time
    /// resolution the evaluator applies to a `"…"` string node.
    #[must_use]
    pub fn interpolate(&self, text: &str) -> String {
        let sep = self.sep();
        interpolate(text, |name| {
            self.data.get(name).map(|value| render_json(value, &sep))
        })
    }

    // -- writes (write-through) --------------------------------------------

    /// Assign `key = value` and write through immediately (SPEC: "context writes
    /// happen immediately"). A transient store (no active file) mutates in
    /// memory only.
    pub fn set(&mut self, key: impl Into<String>, value: Value) -> Result<(), ContextError> {
        self.data.insert(key.into(), value);
        self.save()
    }

    /// Append a `{role, content}` entry to the `_messages` array (creating it if
    /// absent), then write through. Field names honour config
    /// `messages.role_field` / `messages.content_field`.
    pub fn append_message(&mut self, role: &str, content: &str) -> Result<(), ContextError> {
        let mut entry = Map::new();
        entry.insert(self.role_field.clone(), Value::String(role.to_owned()));
        entry.insert(
            self.content_field.clone(),
            Value::String(content.to_owned()),
        );
        let entry = Value::Object(entry);
        match self.data.get_mut(&self.messages_key) {
            Some(Value::Array(messages)) => messages.push(entry),
            _ => {
                self.data
                    .insert(self.messages_key.clone(), Value::Array(vec![entry]));
            }
        }
        self.save()
    }

    /// Persist the context object to the active file (pretty JSON), creating
    /// parent directories as needed. A no-op for a transient store.
    pub fn save(&self) -> Result<(), ContextError> {
        let Some(path) = self.file.as_ref() else {
            return Ok(());
        };
        if let Some(parent) = path.parent() {
            if !parent.as_os_str().is_empty() {
                fs::create_dir_all(parent).map_err(|source| ContextError::Write {
                    path: path.clone(),
                    source,
                })?;
            }
        }
        let text =
            serde_json::to_string_pretty(&self.data).map_err(|source| ContextError::Parse {
                path: Some(path.clone()),
                source,
            })?;
        fs::write(path, text).map_err(|source| ContextError::Write {
            path: path.clone(),
            source,
        })
    }
}

// ---------------------------------------------------------------------------
// path resolution helpers
// ---------------------------------------------------------------------------

/// Expand a leading `~` / `~/` in a config path using an explicit `HOME` (kept
/// pure/testable — no ambient env reads under `unsafe_code = "forbid"`). A path
/// with no leading tilde, or an empty/absent `HOME`, is returned unchanged.
#[must_use]
pub fn expand_tilde(path: &str, home: Option<&OsStr>) -> PathBuf {
    let home = home.filter(|h| !h.is_empty());
    if path == "~" {
        if let Some(home) = home {
            return PathBuf::from(home);
        }
    } else if let Some(rest) = path.strip_prefix("~/") {
        if let Some(home) = home {
            return PathBuf::from(home).join(rest);
        }
    }
    PathBuf::from(path)
}

/// Resolve the default context file from config `file_default`, tilde-expanded
/// with an explicit `HOME`. `None` when no `file_default` is configured.
#[must_use]
pub fn default_context_path(cfg: &ContextConfig, home: Option<&OsStr>) -> Option<PathBuf> {
    cfg.file_default
        .as_deref()
        .map(|raw| expand_tilde(raw, home))
}

// ---------------------------------------------------------------------------
// interpolation (bd-22fa7e)
// ---------------------------------------------------------------------------

/// Interpolate bare `$name` occurrences in `text`, resolving each name through
/// `lookup` (SPEC §Interpolation & evaluation timing).
///
/// Only a bare `$name` — starting with a letter or `_`, continuing with
/// alphanumerics/`_` — interpolates. `${…}`, `$N` (a stack index, digit-led),
/// and a bare `$` not starting a name are left verbatim; an unresolved name
/// (`lookup` returns `None`) is left literal. This is the pure core the
/// evaluator drives with a context-backed `lookup`; see [`Context::interpolate`]
/// for the context-store convenience.
#[must_use]
pub fn interpolate(text: &str, lookup: impl Fn(&str) -> Option<String>) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();
    while let Some(c) = chars.next() {
        if c != '$' {
            out.push(c);
            continue;
        }
        match chars.peek().copied() {
            // `$name` — a context read (name-start letter or `_`).
            Some(next) if next.is_ascii_alphabetic() || next == '_' => {
                let mut name = String::new();
                while let Some(&nc) = chars.peek() {
                    if nc.is_ascii_alphanumeric() || nc == '_' {
                        name.push(nc);
                        chars.next();
                    } else {
                        break;
                    }
                }
                match lookup(&name) {
                    Some(value) => out.push_str(&value),
                    None => {
                        // Unresolved — leave `$name` literal.
                        out.push('$');
                        out.push_str(&name);
                    }
                }
            }
            // `${…}`, `$N` (digits), or a trailing `$` — left verbatim.
            _ => out.push('$'),
        }
    }
    out
}

/// Render a context JSON value to its interpolated string form: strings
/// verbatim, numbers without a trailing `.0` (via [`crate::value::format_number`]),
/// bools as `true`/`false`, lists joined with `sep` (SPEC list → text), null as
/// empty, and objects as compact JSON.
fn render_json(value: &Value, sep: &str) -> String {
    match value {
        Value::String(text) => text.clone(),
        Value::Number(number) => number
            .as_f64()
            .map_or_else(|| number.to_string(), crate::value::format_number),
        Value::Bool(flag) => if *flag { "true" } else { "false" }.to_owned(),
        Value::Array(items) => items
            .iter()
            .map(|item| render_json(item, sep))
            .collect::<Vec<_>>()
            .join(sep),
        Value::Null => String::new(),
        Value::Object(_) => value.to_string(),
    }
}

// ---------------------------------------------------------------------------
// internal load helpers
// ---------------------------------------------------------------------------

/// Read + parse a context object from `path`; a missing file yields an empty
/// object (created on first write), any other I/O error is a [`ContextError`].
fn read_object_or_empty(path: &Path) -> Result<Map<String, Value>, ContextError> {
    match fs::read_to_string(path) {
        Ok(text) => parse_object(&text, Some(path.to_path_buf())),
        Err(source) if source.kind() == io::ErrorKind::NotFound => Ok(Map::new()),
        Err(source) => Err(ContextError::Read {
            path: path.to_path_buf(),
            source,
        }),
    }
}

/// Parse `text` as a top-level JSON object, attributing errors to `path`
/// (`None` = the inline `NLIR_CONTEXT` source).
fn parse_object(text: &str, path: Option<PathBuf>) -> Result<Map<String, Value>, ContextError> {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return Ok(Map::new());
    }
    let value: Value = serde_json::from_str(trimmed).map_err(|source| ContextError::Parse {
        path: path.clone(),
        source,
    })?;
    match value {
        Value::Object(map) => Ok(map),
        _ => Err(ContextError::NotObject { path }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// A config whose context section carries the SPEC defaults.
    fn cfg() -> ContextConfig {
        ContextConfig::default()
    }

    fn temp_path(tag: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!(
            "nlir-ctx-{tag}-{}-{nanos}.json",
            std::process::id()
        ))
    }

    // -- tilde expansion ---------------------------------------------------

    #[test]
    fn expand_tilde_uses_home_for_leading_tilde() {
        let home = OsStr::new("/home/tester");
        assert_eq!(
            expand_tilde("~/.config/nlir/context.json", Some(home)),
            PathBuf::from("/home/tester/.config/nlir/context.json")
        );
        assert_eq!(expand_tilde("~", Some(home)), PathBuf::from("/home/tester"));
        // Non-tilde and mid-string tilde are untouched.
        assert_eq!(
            expand_tilde("/abs/path", Some(home)),
            PathBuf::from("/abs/path")
        );
        assert_eq!(expand_tilde("a/~/b", Some(home)), PathBuf::from("a/~/b"));
        // Absent HOME leaves the tilde literal rather than guessing.
        assert_eq!(expand_tilde("~/x", None), PathBuf::from("~/x"));
        assert_eq!(
            expand_tilde("~/x", Some(OsStr::new(""))),
            PathBuf::from("~/x")
        );
    }

    #[test]
    fn default_context_path_expands_config_default() {
        let mut c = cfg();
        c.file_default = Some("~/.config/nlir/context.json".to_owned());
        assert_eq!(
            default_context_path(&c, Some(OsStr::new("/home/t"))),
            Some(PathBuf::from("/home/t/.config/nlir/context.json"))
        );
        c.file_default = None;
        assert_eq!(default_context_path(&c, Some(OsStr::new("/home/t"))), None);
    }

    // -- load precedence ---------------------------------------------------

    #[test]
    fn load_prefers_context_file_over_env_and_default() {
        let ctx_file = temp_path("ctxfile");
        fs::write(&ctx_file, r#"{"who":"context-file"}"#).unwrap();
        let default_file = temp_path("default");
        fs::write(&default_file, r#"{"who":"default-file"}"#).unwrap();

        let store = Context::load(
            LoadSources {
                context_file: Some(&ctx_file),
                env_inline: Some(r#"{"who":"env"}"#),
                default_file: Some(&default_file),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .expect("load");
        assert_eq!(
            store.get("who").and_then(Value::as_str),
            Some("context-file")
        );
        assert_eq!(store.file(), Some(ctx_file.as_path()));

        let _ = fs::remove_file(&ctx_file);
        let _ = fs::remove_file(&default_file);
    }

    #[test]
    fn load_session_beats_env_and_default_and_is_transient() {
        let default_file = temp_path("default2");
        fs::write(&default_file, r#"{"who":"default-file"}"#).unwrap();
        let mut session = Map::new();
        session.insert("who".to_owned(), Value::String("session".to_owned()));

        let store = Context::load(
            LoadSources {
                session: Some(session),
                env_inline: Some(r#"{"who":"env"}"#),
                default_file: Some(&default_file),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .expect("load");
        assert_eq!(store.get("who").and_then(Value::as_str), Some("session"));
        // Session import is transient — no file-backed write-through.
        assert_eq!(store.file(), None);

        let _ = fs::remove_file(&default_file);
    }

    #[test]
    fn load_env_beats_default_and_is_transient() {
        let default_file = temp_path("default3");
        fs::write(&default_file, r#"{"who":"default-file"}"#).unwrap();
        let store = Context::load(
            LoadSources {
                env_inline: Some(r#"{"who":"env"}"#),
                default_file: Some(&default_file),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .expect("load");
        assert_eq!(store.get("who").and_then(Value::as_str), Some("env"));
        assert_eq!(store.file(), None);
        let _ = fs::remove_file(&default_file);
    }

    #[test]
    fn load_falls_back_to_default_file_as_write_target() {
        let default_file = temp_path("default4");
        fs::write(&default_file, r#"{"who":"default-file"}"#).unwrap();
        let store = Context::load(
            LoadSources {
                default_file: Some(&default_file),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .expect("load");
        assert_eq!(
            store.get("who").and_then(Value::as_str),
            Some("default-file")
        );
        assert_eq!(store.file(), Some(default_file.as_path()));
        let _ = fs::remove_file(&default_file);
    }

    #[test]
    fn load_missing_file_is_empty_not_an_error() {
        let missing = temp_path("missing");
        let store = Context::load(
            LoadSources {
                context_file: Some(&missing),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .expect("missing file loads empty");
        assert!(store.data().is_empty());
        // Still the write-through target — created on first write.
        assert_eq!(store.file(), Some(missing.as_path()));
    }

    #[test]
    fn load_empty_sources_is_empty_transient() {
        let store = Context::load(LoadSources::default(), &cfg()).expect("load");
        assert!(store.data().is_empty());
        assert_eq!(store.file(), None);
    }

    #[test]
    fn load_rejects_non_object_and_malformed_json() {
        let arr = temp_path("array");
        fs::write(&arr, "[1,2,3]").unwrap();
        let err = Context::load(
            LoadSources {
                context_file: Some(&arr),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .unwrap_err();
        assert!(matches!(err, ContextError::NotObject { .. }));
        let _ = fs::remove_file(&arr);

        let bad = temp_path("bad");
        fs::write(&bad, "{not json").unwrap();
        let err = Context::load(
            LoadSources {
                context_file: Some(&bad),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .unwrap_err();
        assert!(matches!(err, ContextError::Parse { .. }));
        let _ = fs::remove_file(&bad);

        // Inline env errors attribute to no path.
        let err = Context::load(
            LoadSources {
                env_inline: Some("42"),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .unwrap_err();
        assert!(matches!(err, ContextError::NotObject { path: None }));
    }

    // -- merge -------------------------------------------------------------

    #[test]
    fn merge_is_shallow_named_key_replacement() {
        let mut store = Context::empty(&cfg());
        store.merge(object(&[("a", Value::from(1)), ("b", Value::from(2))]));
        let mut update = Map::new();
        update.insert("b".to_owned(), Value::from(99));
        update.insert("c".to_owned(), Value::from(3));
        store.merge(update);
        assert_eq!(store.get("a").and_then(Value::as_i64), Some(1));
        assert_eq!(store.get("b").and_then(Value::as_i64), Some(99)); // replaced
        assert_eq!(store.get("c").and_then(Value::as_i64), Some(3));
    }

    #[test]
    fn render_key_renders_like_interpolation() {
        let mut store = Context::empty(&cfg());
        store.merge(object(&[
            ("greeting", Value::from("hello")),
            (
                "items",
                Value::Array(vec![Value::from("a"), Value::from("b")]),
            ),
            ("_sep", Value::from(",")),
        ]));
        // A string renders raw; a list joins with `_sep`; a missing key is None.
        assert_eq!(store.render_key("greeting").as_deref(), Some("hello"));
        assert_eq!(store.render_key("items").as_deref(), Some("a,b"));
        assert_eq!(store.render_key("missing"), None);
    }

    // -- system keys & defaults (bd-fdd3bc) --------------------------------

    #[test]
    fn system_key_defaults_apply_when_absent() {
        let store = Context::empty(&cfg());
        assert_eq!(store.sep(), "\n");
        assert!(store.cache());
        assert!(store.messages().is_empty());
        assert_eq!(store.messages_key(), "_messages");
        assert!(Context::is_system_key("_messages"));
        assert!(Context::is_system_key("_sep"));
        assert!(!Context::is_system_key("subject"));
    }

    #[test]
    fn system_keys_override_defaults_when_present() {
        let mut store = Context::empty(&cfg());
        store.merge(object(&[
            ("_sep", Value::from(" ")),
            ("_cache", Value::from(false)),
        ]));
        assert_eq!(store.sep(), " ");
        assert!(!store.cache());
    }

    #[test]
    fn messages_reads_the_configured_array() {
        let mut store = Context::empty(&cfg());
        store
            .append_message("user", "hi")
            .expect("transient append is infallible");
        store.append_message("assistant", "in rust").unwrap();
        let msgs = store.messages();
        assert_eq!(msgs.len(), 2);
        assert_eq!(msgs[1]["role"].as_str(), Some("assistant"));
        assert_eq!(msgs[1]["content"].as_str(), Some("in rust"));
    }

    // -- write-through -----------------------------------------------------

    #[test]
    fn set_and_append_write_through_and_round_trip() {
        let path = temp_path("writethrough");
        let mut store = Context::load(
            LoadSources {
                context_file: Some(&path),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .expect("load empty");
        store
            .set("k", Value::String("foo".to_owned()))
            .expect("set");
        store.append_message("user", "hello").expect("append");

        // Reload from disk: the write-through persisted both mutations.
        let reloaded = Context::load(
            LoadSources {
                context_file: Some(&path),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .expect("reload");
        assert_eq!(reloaded.get("k").and_then(Value::as_str), Some("foo"));
        assert_eq!(reloaded.messages().len(), 1);
        assert_eq!(reloaded.messages()[0]["content"].as_str(), Some("hello"));

        let _ = fs::remove_file(&path);
    }

    #[test]
    fn transient_store_writes_do_not_touch_disk() {
        let mut store = Context::empty(&cfg());
        // No active file → save is a no-op, mutations stay in memory.
        store.set("k", Value::from(1)).expect("transient set");
        assert_eq!(store.get("k").and_then(Value::as_i64), Some(1));
        assert_eq!(store.file(), None);
    }

    #[test]
    fn save_creates_missing_parent_directories() {
        let dir = temp_path("nested-dir").with_extension("");
        let path = dir.join("deep").join("context.json");
        let mut store = Context::load(
            LoadSources {
                context_file: Some(&path),
                ..LoadSources::default()
            },
            &cfg(),
        )
        .expect("load");
        store.set("k", Value::from(true)).expect("set creates dirs");
        assert!(path.is_file());
        let _ = fs::remove_file(&path);
        let _ = fs::remove_dir_all(&dir);
    }

    // -- interpolation (bd-22fa7e) -----------------------------------------

    #[test]
    fn interpolate_replaces_bare_names_only() {
        let lookup = |name: &str| match name {
            "k" => Some("rust".to_owned()),
            "_sep" => Some("SEP".to_owned()),
            _ => None,
        };
        // A bare `$name` interpolates (SPEC worked example).
        assert_eq!(
            interpolate("the subject is $k", lookup),
            "the subject is rust"
        );
        // System-key name (`_`-led) interpolates too.
        assert_eq!(interpolate("$_sep here", lookup), "SEP here");
        // `${k}` is NOT interpolated (only bare `$name`).
        assert_eq!(interpolate("a ${k} b", lookup), "a ${k} b");
        // `$N` (a stack index) is left literal.
        assert_eq!(interpolate("x$5y", lookup), "x$5y");
        // A trailing bare `$` stays literal.
        assert_eq!(interpolate("cost $", lookup), "cost $");
        // An unresolved name is left literal.
        assert_eq!(interpolate("$missing tail", lookup), "$missing tail");
        // Adjacent interpolations.
        assert_eq!(interpolate("$k$k", lookup), "rustrust");
    }

    #[test]
    fn context_interpolate_renders_stored_values() {
        let mut store = Context::empty(&cfg());
        store.merge(object(&[
            ("k", Value::from("foo")),
            ("n", Value::from(3)), // number renders without a trailing .0
            ("flag", Value::from(true)),
            (
                "items",
                Value::Array(vec![Value::from("a"), Value::from("b")]),
            ),
            ("_sep", Value::from("-")), // list join uses _sep
        ]));
        assert_eq!(store.interpolate("$k/$n/$flag"), "foo/3/true");
        // List renders joined with the active `_sep`.
        assert_eq!(store.interpolate("[$items]"), "[a-b]");
        // Unknown key left literal.
        assert_eq!(store.interpolate("$k and $nope"), "foo and $nope");
    }

    /// Build a JSON object from `(key, value)` pairs for terse test fixtures.
    fn object(pairs: &[(&str, Value)]) -> Map<String, Value> {
        pairs
            .iter()
            .map(|(k, v)| ((*k).to_owned(), v.clone()))
            .collect()
    }
}
