//! nlir — shared command logic for the CLI and the MCP server.
//!
//! `nlir` transpiles a terse, sigil-laden **shorthand** into fluent **English**.
//! The shorthand is an intermediate representation: tokenised, parsed into a DAG
//! using a config-defined grammar, and evaluated over a small stack machine with
//! a tiny type system, where each operator is realised either deterministically
//! or via an LLM call. See `SPEC.md` at the repo root for the normative contract.
//!
//! This crate is the SKELETON established by bd-57ad92: the same typed command
//! contracts back both the clap CLI surface and the `mcp-cli` `ToolRouter`, so
//! `nlir mcp stdio` is a valid MCP server that exposes exactly the operations the
//! CLI performs. This mirrors the pattern every harryaskham ecosystem project
//! follows (see `omni-cli`).
//!
//! The `nlir` binary is built on the mcp-cli / updatable-cli / feedback-cli stack
//! (the `mcp` / `self-update` / `feedback` surfaces). The domain surfaces (`eval`,
//! `parse`, `repl`, context read/write, `test`) are wired as thin typed stubs
//! here; downstream beads fill in the tokeniser, parser, stack machine, type
//! system, and realisation layers described in `SPEC.md`.

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use feedback_cli::{FeedbackConfig, ReportStrategy, Reporter, WebhookConfig};
use mcp_cli::{ErrorCategory, StructuredError, ToolRouter};

pub mod config;
pub mod lexer;

/// GitHub `owner/repo` the self-updater pulls release assets from.
pub const UPDATE_REPO_SLUG: &str = "harryaskham/nlir";

/// Tool name on disk, used by the self-updater for `<tool>` / `<tool>_next`.
/// This is the binary name (`nlir`).
pub const TOOL_NAME: &str = "nlir";

/// Default scheduler parallelism (SPEC §Execution graph & parallelism).
pub const DEFAULT_PARALLELISM: usize = 8;

// ---------------------------------------------------------------------------
// Structured error shared by the command surface (CLI + MCP)
// ---------------------------------------------------------------------------

/// Shared, app-agnostic structured error for the command surface.
#[derive(Debug)]
pub struct AppError {
    category: ErrorCategory,
    code: String,
    message: String,
}

impl AppError {
    #[must_use]
    pub fn validation(code: &str, message: impl Into<String>) -> Self {
        Self {
            category: ErrorCategory::Validation,
            code: code.to_owned(),
            message: message.into(),
        }
    }

    #[must_use]
    pub fn internal(code: &str, message: impl Into<String>) -> Self {
        Self {
            category: ErrorCategory::ExecutionFailure,
            code: code.to_owned(),
            message: message.into(),
        }
    }

    /// A surface that is defined in `SPEC.md` but not yet implemented in this
    /// skeleton. Downstream beads replace the stub with real behaviour.
    #[must_use]
    pub fn not_implemented(code: &str, message: impl Into<String>) -> Self {
        Self {
            category: ErrorCategory::ExecutionFailure,
            code: code.to_owned(),
            message: message.into(),
        }
    }
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for AppError {}

impl StructuredError for AppError {
    fn category(&self) -> ErrorCategory {
        self.category
    }
    fn code(&self) -> String {
        self.code.clone()
    }
    fn message(&self) -> String {
        self.message.clone()
    }
}

// ---------------------------------------------------------------------------
// Evaluation mode (SPEC §Modes)
// ---------------------------------------------------------------------------

/// Evaluation mode: `det` (deterministic, no network) or `llm`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    /// Deterministic realisation only (`command:` / `reduce:` / `template:` /
    /// `join:`); no LLM calls.
    Det,
    /// LLM realisation for string transformations (`model:` + `prompt:`).
    #[default]
    Llm,
}

impl Mode {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Mode::Det => "det",
            Mode::Llm => "llm",
        }
    }
}

// ---------------------------------------------------------------------------
// status
// ---------------------------------------------------------------------------

/// Input for the `status` MCP tool.
#[derive(Debug, Clone, Default, Deserialize, JsonSchema)]
pub struct StatusInput {}

/// Output for the `status` MCP tool.
#[derive(Debug, Clone, Serialize, JsonSchema)]
pub struct StatusOutput {
    pub name: String,
    pub version: String,
    pub update_repo: String,
    pub feedback: bool,
    pub feedback_destination: String,
}

/// `status` implementation shared by the CLI and the MCP tool.
///
/// Resolves feedback configuration from the environment; see [`status_with`]
/// for the pure core that takes an explicit [`FeedbackConfig`].
#[must_use]
pub fn status(input: &StatusInput) -> StatusOutput {
    status_with(input, &feedback_config())
}

/// Pure core of [`status`], testable without depending on the ambient process
/// environment. Mirrors the `updater_config` / `updater_config_with` split,
/// which exists because env mutation is `unsafe` under `unsafe_code = forbid`.
#[must_use]
pub fn status_with(_input: &StatusInput, feedback_config: &FeedbackConfig) -> StatusOutput {
    let feedback = Reporter::from_config(feedback_config);
    StatusOutput {
        name: TOOL_NAME.to_owned(),
        version: env!("CARGO_PKG_VERSION").to_owned(),
        update_repo: UPDATE_REPO_SLUG.to_owned(),
        feedback: feedback.is_enabled(),
        feedback_destination: feedback.destination(),
    }
}

// ---------------------------------------------------------------------------
// eval (SPEC §Mental model) — skeleton stub
// ---------------------------------------------------------------------------

/// Input for the `eval` command (`nlir -e 'EXPR'`) / MCP tool.
#[derive(Debug, Clone, Deserialize, JsonSchema)]
pub struct EvalInput {
    /// The shorthand expression to transpile to English.
    pub expr: String,
    /// Evaluation mode override (`det` or `llm`); default resolves from config.
    #[serde(default)]
    pub mode: Option<Mode>,
    /// Model name override for LLM realisation.
    #[serde(default)]
    pub model: Option<String>,
    /// Show the DAG and assembled prompts without making any calls.
    #[serde(default)]
    pub dry_run: bool,
}

/// Output for the `eval` command / MCP tool.
#[derive(Debug, Clone, Serialize, JsonSchema)]
pub struct EvalOutput {
    /// The transpiled English result (program result → stdout).
    pub result: String,
    /// True while this is the skeleton identity stub (bd-57ad92), before the
    /// tokeniser / parser / stack machine land.
    pub stub: bool,
}

/// `eval` implementation shared by the CLI and the MCP tool.
///
/// SKELETON (bd-57ad92): this is an identity passthrough — it returns the input
/// expression unchanged and flags `stub: true`. Downstream beads replace it with
/// the real tokenise → parse → schedule/eval pipeline from `SPEC.md`.
pub fn eval(input: &EvalInput) -> Result<EvalOutput, AppError> {
    Ok(EvalOutput {
        result: input.expr.clone(),
        stub: true,
    })
}

// ---------------------------------------------------------------------------
// parse (SPEC §Grammar & parsing) — skeleton stub
// ---------------------------------------------------------------------------

/// Input for the `parse` command / MCP tool.
#[derive(Debug, Clone, Deserialize, JsonSchema)]
pub struct ParseInput {
    /// The shorthand expression to tokenise/parse.
    pub expr: String,
}

/// Output for the `parse` command / MCP tool.
#[derive(Debug, Clone, Serialize, JsonSchema)]
pub struct ParseOutput {
    /// The token stream (each token's literal text) from the [`lexer`] literal
    /// layer. Operator/sigil lexing and the AST/DAG parser land downstream.
    pub tokens: Vec<String>,
    /// True while `parse` returns only the token stream (no AST/DAG yet).
    pub stub: bool,
}

/// `parse` implementation shared by the CLI and the MCP tool.
///
/// Tokenises the expression via the [`lexer`] literal layer
/// (bd-a14b8a/5e6a92/80e0d1) and returns the token stream. `stub` stays true
/// until the AST/DAG parser lands (parser epic). An unlexable character (e.g. an
/// operator sigil, not yet in the lexer) is a validation error.
pub fn parse(input: &ParseInput) -> Result<ParseOutput, AppError> {
    let tokens = lexer::tokenize(&input.expr)
        .map_err(|error| AppError::validation("lex_error", error.to_string()))?;
    Ok(ParseOutput {
        tokens: tokens.iter().map(|t| t.text().to_owned()).collect(),
        stub: true,
    })
}

// ---------------------------------------------------------------------------
// MCP router + template-stack config
// ---------------------------------------------------------------------------

/// The MCP tool context. Stateless for now; downstream beads may thread config
/// / engine state through it.
pub struct AppContext;

/// Build the [`ToolRouter`] exposing the CLI's command surface as MCP tools.
///
/// Wires the domain surfaces (`status` / `eval` / `parse`) plus the
/// updatable-cli (`self_update_*`) and feedback-cli (`feedback_*`) tool families,
/// so `nlir mcp stdio` is a valid MCP server for the whole surface.
#[must_use]
pub fn build_router() -> ToolRouter<AppContext> {
    let mut router = ToolRouter::new();

    router.add_typed_tool(
        "status",
        "Report this CLI's name, version, update repo, and capabilities.",
        |_ctx: &AppContext, input: StatusInput| Ok::<_, AppError>(status(&input)),
    );

    router.add_typed_tool(
        "eval",
        "Transpile an nlir shorthand expression to English (nlir -e 'EXPR'). SKELETON: currently an identity passthrough until the tokeniser/parser/stack machine land.",
        |_ctx: &AppContext, input: EvalInput| eval(&input),
    );

    router.add_typed_tool(
        "parse",
        "Tokenise an nlir shorthand expression (literal layer: whitespace/bare/numeric/quoted). Operator/sigil lexing and the AST/DAG parser land downstream.",
        |_ctx: &AppContext, input: ParseInput| parse(&input),
    );

    // updatable-cli contributes self_update_status / self_update_check /
    // self_update_run, so `nlir self-update` works end-to-end.
    updatable_cli::register_update_tool(&mut router, |_ctx: &AppContext| updater_config());

    // feedback-cli contributes feedback_report / feedback_status, so command
    // failures, perf observations, or operator feedback can be routed back to a
    // project webhook, caco logging, or stderr.
    feedback_cli::register_feedback_tools(&mut router, |_ctx: &AppContext| feedback_config());

    router
}

/// The self-updater configuration.
///
/// Source a bearer token from `GITHUB_TOKEN` if set, otherwise fall back to the
/// local `gh` CLI (`gh auth token`). Harmless for a public repo (the header is
/// just ignored), so this is correct whether or not the release repo is private.
#[must_use]
pub fn updater_config() -> updatable_cli::UpdaterConfig {
    updater_config_with(std::env::var("GITHUB_TOKEN").ok())
}

/// Pure core of [`updater_config`], testable without env mutation (which is
/// `unsafe` under this crate's `unsafe_code = "forbid"`).
#[must_use]
pub fn updater_config_with(github_token: Option<String>) -> updatable_cli::UpdaterConfig {
    let cfg =
        updatable_cli::UpdaterConfig::new(TOOL_NAME, env!("CARGO_PKG_VERSION"), UPDATE_REPO_SLUG)
            .with_gh_token_fallback(true);
    match github_token {
        Some(token) if !token.trim().is_empty() => cfg.with_github_token(token),
        _ => cfg,
    }
}

/// Feedback reporting configuration. Loaded from the environment convention:
///
/// - `FEEDBACK_WEBHOOK_URL` selects webhook reporting with an explicit full URL,
/// - `FEEDBACK_WEBHOOK_BASE_URL` (Harry's canonical global-hook namespace) routes
///   to `<base>/<project>` — e.g. `.../hooks/global/nlir` — so nlir feedback lands
///   on its OWN hook sub-path, not a shared one. An explicit `FEEDBACK_WEBHOOK_URL`
///   wins over the base URL.
/// - `FEEDBACK_WEBHOOK_TOKEN_ENV` points at the bearer-token env var,
/// - `FEEDBACK_COMPONENT` / `FEEDBACK_PROJECT` override the defaults,
/// - unset means JSON lines to stderr (safe local default).
#[must_use]
pub fn feedback_config() -> FeedbackConfig {
    let mut config = FeedbackConfig::from_env();
    config.component.get_or_insert_with(|| TOOL_NAME.to_owned());
    config.project.get_or_insert_with(|| {
        std::env::var("CACOPHONY_PROJECT").unwrap_or_else(|_| TOOL_NAME.to_owned())
    });
    // feedback-cli's from_env only understands a full FEEDBACK_WEBHOOK_URL. Under
    // Harry's canonical global-hook design the shell exports only
    // FEEDBACK_WEBHOOK_BASE_URL + one shared token, and each project POSTs to
    // <base>/<project>. So when no explicit URL was set but a base URL is present,
    // target this project's own sub-path — keeping nlir / omni-cli / tendril / ...
    // feedback on separate hooks instead of spamming one shared board.
    if matches!(config.strategy, ReportStrategy::Stderr) {
        if let Ok(base) = std::env::var("FEEDBACK_WEBHOOK_BASE_URL") {
            let base = base.trim();
            if !base.is_empty() {
                let sub_path = config.project.as_deref().unwrap_or(TOOL_NAME).to_owned();
                config.strategy = ReportStrategy::Webhook(WebhookConfig {
                    url: feedback_webhook_url(base, &sub_path),
                    token_env: std::env::var("FEEDBACK_WEBHOOK_TOKEN_ENV").ok(),
                    ..WebhookConfig::default()
                });
            }
        }
    }
    config
}

/// Join a feedback webhook base URL and a project sub-path into the full
/// endpoint, tolerating a trailing `/` on the base and a leading `/` on the
/// sub-path.
#[must_use]
fn feedback_webhook_url(base: &str, sub_path: &str) -> String {
    format!(
        "{}/{}",
        base.trim_end_matches('/'),
        sub_path.trim_start_matches('/')
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_reports_tool_metadata() {
        // Explicit default FeedbackConfig so the test is hermetic and does not
        // read the ambient process env.
        let s = status_with(&StatusInput::default(), &FeedbackConfig::default());
        assert_eq!(s.name, TOOL_NAME);
        assert_eq!(s.update_repo, UPDATE_REPO_SLUG);
        assert_eq!(s.version, env!("CARGO_PKG_VERSION"));
    }

    #[test]
    fn eval_is_identity_stub_for_now() {
        let out = eval(&EvalInput {
            expr: "a&b&c".to_owned(),
            mode: Some(Mode::Det),
            model: None,
            dry_run: false,
        })
        .expect("eval stub is infallible");
        assert_eq!(out.result, "a&b&c");
        assert!(out.stub);
    }

    #[test]
    fn parse_tokenises_literal_layer() {
        let out = parse(&ParseInput {
            expr: "one two three".to_owned(),
        })
        .expect("literals tokenise");
        assert_eq!(out.tokens, vec!["one", "two", "three"]);
        assert!(out.stub);
        // A quoted literal collapses to its content.
        let out = parse(&ParseInput {
            expr: "'a b' c".to_owned(),
        })
        .expect("quoted tokenises");
        assert_eq!(out.tokens, vec!["a b", "c"]);
        // An operator sigil is not lexed yet -> validation error.
        assert!(
            parse(&ParseInput {
                expr: "a&b".to_owned(),
            })
            .is_err()
        );
    }

    #[test]
    fn mode_serialises_lowercase() {
        assert_eq!(Mode::Det.as_str(), "det");
        assert_eq!(Mode::Llm.as_str(), "llm");
        assert_eq!(Mode::default(), Mode::Llm);
    }

    #[test]
    fn router_exposes_domain_and_stack_tools() {
        let router = build_router();
        let names: Vec<String> = router.tool_metadata().into_iter().map(|t| t.name).collect();
        for expected in ["status", "eval", "parse"] {
            assert!(
                names.iter().any(|n| n == expected),
                "router missing tool {expected}; has {names:?}"
            );
        }
    }

    #[test]
    fn updater_config_enables_gh_fallback() {
        let c = updater_config_with(None);
        assert_eq!(c.tool_name, TOOL_NAME);
    }
}
