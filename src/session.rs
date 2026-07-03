//! Session-file import (SPEC §CLI: `--session-file`).
//!
//! Parse a Pi coding-agent session transcript (JSONL) into `(role, content)`
//! message pairs per a `sessions.<name>` config (bd-720cdb). The CLI appends
//! these to the effective context's `_messages` (bd-000666), so a shorthand
//! program can index the imported conversation (`^N` / `$_messages`).
//!
//! Pi session shape: one JSON object per line, `type`-tagged. Only
//! `type == "message"` lines carry a `message: { role, content }`; `content` is
//! a list of typed parts (`text` / `thinking` / `toolCall` / …). We keep the
//! configured roles, flatten the `text` parts into a single string, and drop
//! turns with no text (pure tool calls) — honouring `drop_tool_messages`.

use std::fmt;

use serde_json::Value;

use crate::config::SessionConfig;

/// A failure importing a session file.
#[derive(Debug)]
pub enum SessionError {
    /// The configured `format` is not one this build can parse.
    UnsupportedFormat(String),
    /// A line was not valid JSON.
    Json {
        /// 1-based line number of the offending line.
        line: usize,
        /// The underlying parse error.
        source: serde_json::Error,
    },
}

impl fmt::Display for SessionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UnsupportedFormat(fmt_name) => write!(
                f,
                "unsupported session format {fmt_name:?} (only \"pi\" is supported)"
            ),
            Self::Json { line, source } => {
                write!(f, "invalid JSON on session line {line}: {source}")
            }
        }
    }
}

impl std::error::Error for SessionError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Json { source, .. } => Some(source),
            Self::UnsupportedFormat(_) => None,
        }
    }
}

/// Parse a Pi session JSONL transcript into `(role, content)` pairs (bd-720cdb).
///
/// Keeps only `cfg.keep_roles` (all roles when empty), reads role/content via
/// `cfg.role_field`/`cfg.content_field` (default `role`/`content`), flattens the
/// structured `content` list into text, and drops turns with empty text (pure
/// tool calls) — the deterministic effect of `drop_tool_messages` for Pi.
///
/// # Errors
/// Returns [`SessionError::UnsupportedFormat`] for a non-`pi` format and
/// [`SessionError::Json`] for a malformed line.
pub fn parse_pi_session(
    input: &str,
    cfg: &SessionConfig,
) -> Result<Vec<(String, String)>, SessionError> {
    if !cfg.format.is_empty() && cfg.format != "pi" {
        return Err(SessionError::UnsupportedFormat(cfg.format.clone()));
    }
    let role_field = cfg.role_field.as_deref().unwrap_or("role");
    let content_field = cfg.content_field.as_deref().unwrap_or("content");

    let mut out = Vec::new();
    for (idx, raw) in input.lines().enumerate() {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        let entry: Value = serde_json::from_str(line).map_err(|source| SessionError::Json {
            line: idx + 1,
            source,
        })?;
        // Only `type: message` lines carry a role/content payload.
        if entry.get("type").and_then(Value::as_str) != Some("message") {
            continue;
        }
        let Some(message) = entry.get("message").and_then(Value::as_object) else {
            continue;
        };
        let Some(role) = message.get(role_field).and_then(Value::as_str) else {
            continue;
        };
        if !cfg.keep_roles.is_empty() && !cfg.keep_roles.iter().any(|r| r == role) {
            continue;
        }
        let text = flatten_content(message.get(content_field));
        // A turn with no text is a pure tool call / result; drop it.
        if text.is_empty() {
            continue;
        }
        out.push((role.to_owned(), text));
    }
    Ok(out)
}

/// Flatten a Pi message `content` into text: a plain string is taken as-is; a
/// list of parts contributes the `text` of each `type: text` part (thinking and
/// tool-call parts are ignored).
fn flatten_content(content: Option<&Value>) -> String {
    match content {
        Some(Value::String(text)) => text.clone(),
        Some(Value::Array(parts)) => {
            let mut buf = String::new();
            for part in parts {
                let Some(obj) = part.as_object() else {
                    continue;
                };
                if obj.get("type").and_then(Value::as_str) == Some("text") {
                    if let Some(text) = obj.get("text").and_then(Value::as_str) {
                        buf.push_str(text);
                    }
                }
            }
            buf
        }
        _ => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pi_cfg() -> SessionConfig {
        SessionConfig {
            format: "pi".to_owned(),
            keep_roles: vec!["user".to_owned(), "assistant".to_owned()],
            drop_tool_messages: true,
            role_field: None,
            content_field: None,
        }
    }

    const SAMPLE: &str = r#"{"type":"session","cwd":"/x","version":1}
{"type":"model_change","modelId":"m"}
{"type":"message","message":{"role":"user","content":[{"type":"text","text":"hello"}]}}
{"type":"message","message":{"role":"assistant","content":[{"type":"thinking","text":"hmm"},{"type":"text","text":"hi there"}]}}
{"type":"message","message":{"role":"assistant","content":[{"type":"toolCall","id":"t1"}]}}
{"type":"message","message":{"role":"toolResult","content":[{"type":"text","text":"42"}]}}
"#;

    #[test]
    fn parses_pi_messages_keeping_roles_and_flattening_text() {
        let msgs = parse_pi_session(SAMPLE, &pi_cfg()).expect("parses");
        // Kept: user "hello", assistant "hi there". Dropped: non-message lines,
        // the tool-call-only assistant turn (no text), and the toolResult role.
        assert_eq!(
            msgs,
            vec![
                ("user".to_owned(), "hello".to_owned()),
                ("assistant".to_owned(), "hi there".to_owned()),
            ]
        );
    }

    #[test]
    fn keep_roles_filter_and_plain_string_content() {
        let cfg = SessionConfig {
            keep_roles: vec!["user".to_owned()],
            ..pi_cfg()
        };
        let input = concat!(
            "{\"type\":\"message\",\"message\":{\"role\":\"user\",\"content\":\"plain\"}}\n",
            "{\"type\":\"message\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"x\"}]}}\n"
        );
        let msgs = parse_pi_session(input, &cfg).expect("parses");
        assert_eq!(msgs, vec![("user".to_owned(), "plain".to_owned())]);
    }

    #[test]
    fn unsupported_format_errors() {
        let cfg = SessionConfig {
            format: "acme".to_owned(),
            ..pi_cfg()
        };
        assert!(matches!(
            parse_pi_session("", &cfg),
            Err(SessionError::UnsupportedFormat(_))
        ));
    }

    #[test]
    fn malformed_line_errors_with_location() {
        let input =
            "{\"type\":\"message\",\"message\":{\"role\":\"user\",\"content\":\"ok\"}}\nnot json";
        match parse_pi_session(input, &pi_cfg()) {
            Err(SessionError::Json { line, .. }) => assert_eq!(line, 2),
            other => panic!("expected a line-2 JSON error, got {other:?}"),
        }
    }
}
