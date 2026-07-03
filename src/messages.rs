//! nlir message indexing over the context `_messages` array (SPEC §Builtins:
//! Message indexing).
//!
//! `^`/`^_`/`^*`/`^/` select a role-filtered **view** of `_messages`; an
//! **index** (an expression the evaluator coerces to a number) picks a message,
//! negatives counting from the end; a **range** `M^N` joins the slice's contents
//! with `_sep`.
//!
//! The entry point is [`MessageIndex`], a thin resolver bundling the messages
//! array with the config-derived naming (role/content field) and role views.
//! It carries no evaluator state: the evaluator (bd-2b226d) resolves the
//! `Expr::Message { role, index }` index expression to an integer, builds a
//! `MessageIndex` from the [`crate::context::Context`] `_messages` +
//! [`crate::config::ContextConfig`], and calls [`MessageIndex::at`] /
//! [`MessageIndex::content_at`]; the `M^N` range form (its parser node is still
//! deferred in the parser epic) calls [`MessageIndex::range`].
//!
//! - bd-f9809a: role-filtered views ([`effective_roles`], [`MessageIndex::view`]).
//! - bd-e8064e: index resolution, negatives from the end ([`resolve_index`],
//!   [`MessageIndex::at`], [`MessageIndex::content_at`]).
//! - bd-43ac5e: range `M^N` joined with `_sep` ([`MessageIndex::range`]).

use serde_json::Value;

use crate::config::MessageViews;
pub use crate::index::resolve_index;
use crate::lexer::MessageRole;

/// The role set for a `^` view, read straight from the configured
/// [`MessageViews`] (bd-127396). The SPEC canonical defaults live in
/// [`MessageViews::default`] (config), so a config that omits `views:` already
/// carries `^`=assistant, `^_`=user, etc.; an explicitly-empty view means "no
/// roles".
#[must_use]
pub fn effective_roles(views: &MessageViews, role: MessageRole) -> Vec<String> {
    match role {
        MessageRole::Assistant => views.default.clone(),
        MessageRole::User => views.user.clone(),
        MessageRole::All => views.all.clone(),
        MessageRole::System => views.system.clone(),
    }
}

/// Resolve a range endpoint, clamping into `[0, len - 1]` after negative-from-end
/// resolution. `None` only when `len == 0`.
fn clamp_index(len: usize, index: i64) -> Option<usize> {
    let len_i = i64::try_from(len).ok().filter(|len| *len > 0)?;
    let resolved = if index < 0 { len_i + index } else { index };
    usize::try_from(resolved.clamp(0, len_i - 1)).ok()
}

/// A message-indexing resolver: the `_messages` array plus the config-derived
/// naming (`role_field` / `content_field`) and role [`MessageViews`].
///
/// Constructed once per evaluation of an `^` node (from a
/// [`crate::context::Context`] + [`crate::config::ContextConfig`]) and then
/// queried for role views, single indices, and ranges. Holds only borrows, so
/// it is cheap to build.
#[derive(Debug, Clone, Copy)]
pub struct MessageIndex<'a> {
    messages: &'a [Value],
    views: &'a MessageViews,
    role_field: &'a str,
    content_field: &'a str,
}

impl<'a> MessageIndex<'a> {
    /// Build a resolver over `messages`, using `views` for role selection and
    /// `role_field` / `content_field` (config `messages.role_field` /
    /// `messages.content_field`, defaults `role` / `content`) for field access.
    #[must_use]
    pub fn new(
        messages: &'a [Value],
        views: &'a MessageViews,
        role_field: &'a str,
        content_field: &'a str,
    ) -> Self {
        Self {
            messages,
            views,
            role_field,
            content_field,
        }
    }

    /// The role-filtered view: the `_messages` entries whose role field is in the
    /// effective role set for `role`, in original order. Non-object messages and
    /// messages without a string role are skipped.
    #[must_use]
    pub fn view(&self, role: MessageRole) -> Vec<&'a Value> {
        let roles = effective_roles(self.views, role);
        self.messages
            .iter()
            .filter(|message| {
                message
                    .get(self.role_field)
                    .and_then(Value::as_str)
                    .is_some_and(|actual| roles.iter().any(|want| want == actual))
            })
            .collect()
    }

    /// The message at `index` in the `role` view (negatives from the end), or
    /// `None` when the view is empty / the index is out of range.
    #[must_use]
    pub fn at(&self, role: MessageRole, index: i64) -> Option<&'a Value> {
        let selected = self.view(role);
        resolve_index(selected.len(), index).map(|i| selected[i])
    }

    /// The content string of the message at `index` in the `role` view (SPEC:
    /// `^-1` = the last assistant message's content). `None` when the index is
    /// out of range or the message has no string content.
    #[must_use]
    pub fn content_at(&self, role: MessageRole, index: i64) -> Option<String> {
        self.at(role, index)
            .and_then(|message| message.get(self.content_field))
            .and_then(Value::as_str)
            .map(str::to_owned)
    }

    /// The contents of the range between `start` and `end` in the `role` view,
    /// joined with `sep` (SPEC: `(1+1)^(5+5)` = assistant messages 2..10 joined
    /// with `_sep`).
    ///
    /// Both endpoints resolve like [`resolve_index`] (negatives from the end) and
    /// are then clamped into the view, so an out-of-range endpoint saturates at
    /// the nearest edge rather than dropping the whole range. The slice runs in
    /// ascending index order between the two resolved/clamped endpoints
    /// (inclusive). An empty view yields the empty string.
    #[must_use]
    pub fn range(&self, role: MessageRole, start: i64, end: i64, sep: &str) -> String {
        let selected = self.view(role);
        let (Some(a), Some(b)) = (
            clamp_index(selected.len(), start),
            clamp_index(selected.len(), end),
        ) else {
            return String::new();
        };
        let (lo, hi) = if a <= b { (a, b) } else { (b, a) };
        selected[lo..=hi]
            .iter()
            .filter_map(|message| message.get(self.content_field).and_then(Value::as_str))
            .collect::<Vec<_>>()
            .join(sep)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    /// A five-message fixture spanning all roles, in insertion order.
    fn fixture() -> Vec<Value> {
        vec![
            json!({"role": "system", "content": "sys0"}),
            json!({"role": "user", "content": "u0"}),
            json!({"role": "assistant", "content": "a0"}),
            json!({"role": "user", "content": "u1"}),
            json!({"role": "assistant", "content": "a1"}),
        ]
    }

    fn views() -> MessageViews {
        MessageViews::default()
    }

    /// A resolver over `messages` with default views + field names.
    fn index<'a>(messages: &'a [Value], views: &'a MessageViews) -> MessageIndex<'a> {
        MessageIndex::new(messages, views, "role", "content")
    }

    // -- role views (bd-f9809a) --------------------------------------------

    #[test]
    fn effective_roles_come_from_the_config_defaults() {
        // The SPEC canonical view roles now live in MessageViews::default()
        // (config), read straight through — no messages-layer fallback (bd-127396).
        let v = views();
        assert_eq!(effective_roles(&v, MessageRole::Assistant), ["assistant"]);
        assert_eq!(effective_roles(&v, MessageRole::User), ["user"]);
        assert_eq!(
            effective_roles(&v, MessageRole::All),
            ["user", "assistant", "system"]
        );
        assert_eq!(effective_roles(&v, MessageRole::System), ["system"]);
        // An explicitly-empty view means "no roles" (matches nothing).
        let empty = MessageViews {
            default: vec![],
            user: vec![],
            all: vec![],
            system: vec![],
        };
        assert!(effective_roles(&empty, MessageRole::Assistant).is_empty());
    }

    #[test]
    fn configured_view_overrides_the_default() {
        let mut v = views();
        v.default = vec!["user".to_owned()]; // remap `^` to user messages
        assert_eq!(effective_roles(&v, MessageRole::Assistant), ["user"]);
        let msgs = fixture();
        let selected = index(&msgs, &v).view(MessageRole::Assistant);
        let contents: Vec<&str> = selected
            .iter()
            .map(|m| m["content"].as_str().unwrap())
            .collect();
        assert_eq!(contents, ["u0", "u1"]);
    }

    #[test]
    fn view_filters_by_role_preserving_order() {
        let msgs = fixture();
        let v = views();
        let idx = index(&msgs, &v);
        let contents = |role| -> Vec<String> {
            idx.view(role)
                .iter()
                .map(|m| m["content"].as_str().unwrap().to_owned())
                .collect()
        };
        assert_eq!(contents(MessageRole::Assistant), ["a0", "a1"]);
        assert_eq!(contents(MessageRole::User), ["u0", "u1"]);
        assert_eq!(contents(MessageRole::System), ["sys0"]);
        // `^*` all view keeps every message in original order.
        assert_eq!(contents(MessageRole::All), ["sys0", "u0", "a0", "u1", "a1"]);
    }

    #[test]
    fn view_skips_non_object_and_roleless_messages() {
        let msgs = vec![
            json!("not an object"),
            json!({"content": "no role"}),
            json!({"role": "assistant", "content": "a0"}),
        ];
        let v = views();
        let selected = index(&msgs, &v).view(MessageRole::Assistant);
        assert_eq!(selected.len(), 1);
        assert_eq!(selected[0]["content"].as_str(), Some("a0"));
    }

    // -- index resolution (bd-e8064e) --------------------------------------

    #[test]
    fn at_and_content_at_resolve_over_the_view() {
        let msgs = fixture();
        let v = views();
        let idx = index(&msgs, &v);
        // `^-1` — last assistant message content.
        assert_eq!(
            idx.content_at(MessageRole::Assistant, -1),
            Some("a1".to_owned())
        );
        // `^0` — first assistant.
        assert_eq!(
            idx.content_at(MessageRole::Assistant, 0),
            Some("a0".to_owned())
        );
        // `^_-1` — last user.
        assert_eq!(idx.content_at(MessageRole::User, -1), Some("u1".to_owned()));
        // Out of range → None.
        assert_eq!(idx.content_at(MessageRole::Assistant, 9), None);
        // `at` yields the whole message object.
        let last = idx.at(MessageRole::Assistant, -1).unwrap();
        assert_eq!(last["role"].as_str(), Some("assistant"));
    }

    #[test]
    fn spec_msg_test_last_assistant_is_in_rust() {
        // Mirrors the SPEC `tests.msg` case: user "hi" + assistant "in rust",
        // `^-1` → "in rust".
        let msgs = vec![
            json!({"role": "user", "content": "hi"}),
            json!({"role": "assistant", "content": "in rust"}),
        ];
        let v = views();
        assert_eq!(
            index(&msgs, &v).content_at(MessageRole::Assistant, -1),
            Some("in rust".to_owned())
        );
    }

    // -- range (bd-43ac5e) -------------------------------------------------

    #[test]
    fn range_joins_view_slice_with_sep() {
        let msgs = fixture();
        let v = views();
        let idx = index(&msgs, &v);
        // assistant view = [a0, a1]; 0..1 joined with " ".
        assert_eq!(idx.range(MessageRole::Assistant, 0, 1, " "), "a0 a1");
        // `^*` all view range across everything, joined with "\n".
        assert_eq!(
            idx.range(MessageRole::All, 0, -1, "\n"),
            "sys0\nu0\na0\nu1\na1"
        );
    }

    #[test]
    fn range_clamps_out_of_range_endpoints() {
        let msgs = fixture();
        let v = views();
        let idx = index(&msgs, &v);
        // end past the view saturates at the last assistant message.
        assert_eq!(idx.range(MessageRole::Assistant, 0, 10, "|"), "a0|a1");
        // descending endpoints still produce ascending slice order.
        assert_eq!(idx.range(MessageRole::All, -1, 0, ","), "sys0,u0,a0,u1,a1");
    }

    #[test]
    fn range_over_empty_view_is_empty_string() {
        // No system messages present → system range is empty.
        let msgs = vec![json!({"role": "user", "content": "u0"})];
        let v = views();
        assert_eq!(index(&msgs, &v).range(MessageRole::System, 0, 3, " "), "");
    }
}
