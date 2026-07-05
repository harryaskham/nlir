//! nlir — clap CLI entrypoint for the natural-language IR transpiler.
//!
//! `nlir -e 'EXPR'` transpiles a terse shorthand IR into fluent English. The CLI
//! and the MCP server share the same typed command contracts from the library
//! crate (`nlir` lib). See `SPEC.md` for the normative language contract.
//!
//! This is the SKELETON established by bd-57ad92. The command tree and global
//! flags from SPEC §CLI surface are all present; the template-stack surfaces
//! (`mcp` / `self-update` / `feedback`) are fully wired via mcp-cli /
//! updatable-cli / feedback-cli; the domain surfaces (`-e` / `parse` / `test` /
//! `repl` / `set` / `get` / `append-message`) are thin stubs that downstream
//! beads fill in with the tokeniser, parser, stack machine, and realisation
//! layers.

use std::io::{self, BufRead, Write};
use std::path::PathBuf;

use clap::{Args, Parser, Subcommand};

use feedback_cli::{FeedbackEvent, FeedbackKind, Reporter, Severity};
use mcp_cli::{McpServer, StdioServerConfig};
use nlir::{
    AppContext, ParseInput, TOOL_NAME, build_router, feedback_config, parse, updater_config,
};

#[derive(Debug, Parser)]
#[command(
    name = "nlir",
    version,
    about = "nlir — transpile a terse shorthand IR into fluent English (nlir -e 'EXPR').",
    arg_required_else_help = true,
    disable_help_subcommand = true
)]
struct Cli {
    /// Evaluate a shorthand expression and print the English result.
    ///
    /// `allow_hyphen_values` lets an expression that opens with `-` (e.g. a
    /// leading-negative range index like `-1^*0`) reach the evaluator instead of
    /// being rejected by clap as an unknown flag (bd-d2d23c).
    #[arg(
        short = 'e',
        long = "expr",
        value_name = "EXPR",
        allow_hyphen_values = true
    )]
    expr: Option<String>,

    /// Path to the nlir config file (default: ~/.config/nlir/config.yaml).
    #[arg(long, global = true, value_name = "PATH")]
    config: Option<PathBuf>,

    /// Context file overriding NLIR_CONTEXT / the default context.json.
    #[arg(long, global = true, value_name = "PATH")]
    context_file: Option<PathBuf>,

    /// Session file to hydrate context from (e.g. a Pi session; roles kept).
    #[arg(long, global = true, value_name = "PATH")]
    session_file: Option<PathBuf>,

    /// Evaluation mode: `det` (no network) or `llm` (default from config).
    #[arg(long, global = true, value_enum, value_name = "MODE")]
    mode: Option<CliMode>,

    /// Model name override for LLM realisation.
    #[arg(long, global = true, value_name = "MODEL")]
    model: Option<String>,

    /// Max concurrent LLM/subprocess calls in the DAG scheduler (default 8).
    #[arg(long, global = true, value_name = "N")]
    parallelism: Option<usize>,

    /// Print only the stdout result (suppress the stderr expansion trace).
    #[arg(long, global = true)]
    quiet: bool,

    /// Show the DAG + assembled prompts, make no calls.
    #[arg(long, global = true)]
    dry_run: bool,

    #[command(subcommand)]
    command: Option<Command>,
}

/// CLI-facing mirror of [`nlir::Mode`] so the library stays clap-agnostic.
#[derive(Debug, Clone, Copy, clap::ValueEnum)]
enum CliMode {
    Det,
    Llm,
}

impl From<CliMode> for nlir::Mode {
    fn from(m: CliMode) -> Self {
        match m {
            CliMode::Det => nlir::Mode::Det,
            CliMode::Llm => nlir::Mode::Llm,
        }
    }
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Tokenise/parse a shorthand expression and print the parse (no eval).
    Parse(ParseArgs),
    /// Step-through: print EXPR then each reduction, one redex at a time.
    Step(StepArgs),
    /// Run the config-defined test suite.
    Test,
    /// Print a config-derived reference of every operator + a one-line summary.
    #[command(visible_aliases = ["operators", "ops"])]
    Help,
    /// Render EXPR's computational dataflow graph (AST + resolved bindings) as SVG.
    Show(ShowArgs),
    /// Interactive REPL: one expression per submission (`:cmd` == `nlir cmd`).
    Repl(ReplArgs),
    /// Replace context keys: `set KEY VALUE` or `set '{"k":"v",...}'`.
    Set(SetArgs),
    /// Read a context key: `get KEY`.
    Get(GetArgs),
    /// Append a message to `_messages` (`--role`, default user).
    AppendMessage(AppendMessageArgs),
    /// Model Context Protocol surfaces.
    #[command(subcommand)]
    Mcp(McpCommand),
    /// Self-update from GitHub releases (updatable-cli). Also runs as `nlir update`.
    #[command(visible_alias = "update")]
    SelfUpdate,
    /// Feedback / error / perf reporting (feedback-cli).
    #[command(subcommand)]
    Feedback(FeedbackCommand),
}

#[derive(Debug, Args)]
struct ParseArgs {
    /// The shorthand expression to parse.
    #[arg(value_name = "EXPR", allow_hyphen_values = true)]
    expr: String,
}

#[derive(Debug, Args)]
struct StepArgs {
    /// The shorthand expression to step through.
    #[arg(value_name = "EXPR", allow_hyphen_values = true)]
    expr: String,
}

#[derive(Debug, Args)]
struct ShowArgs {
    /// The shorthand expression to render as a dataflow graph.
    #[arg(value_name = "EXPR", allow_hyphen_values = true)]
    expr: String,
    /// Write the SVG to a file instead of stdout.
    #[arg(long, value_name = "PATH")]
    out: Option<PathBuf>,
    /// Rasterise the graph SVG to a PNG file (via resvg).
    #[arg(long, value_name = "PATH")]
    png: Option<PathBuf>,
    /// Encode the per-step graph frames as an animated PNG (APNG) at this path.
    #[arg(long, value_name = "PATH")]
    save_animation: Option<PathBuf>,
    /// Display the graph in-terminal via the kitty graphics protocol (auto-on
    /// when a kitty terminal is detected; this forces it, e.g. through tmux).
    #[arg(long)]
    kitty: bool,
    /// Play the per-step graphs as a live kitty-terminal animation (requires a
    /// kitty terminal or --kitty; use --save-animation for a shareable file).
    #[arg(long)]
    animate: bool,
    /// Write one graph SVG per evaluation step (the animation frames) to a
    /// directory (--out DIR, default a temp dir) instead of the single static
    /// graph. The frame source G4's kitty animation / --save-animation consume.
    #[arg(long)]
    frames: bool,
}

#[derive(Debug, Args)]
struct ReplArgs {
    /// Raw mode: pipe shorthand straight in without the pretty prompt.
    #[arg(long)]
    raw: bool,

    /// Resume the most recent saved REPL session (restore its context +
    /// messages) before starting the loop (bd-ff485a).
    #[arg(long = "continue")]
    continue_session: bool,
}

#[derive(Debug, Args)]
struct SetArgs {
    /// Either `KEY VALUE` or a single `{...}` JSON object whose keys replace.
    #[arg(value_name = "ARG", num_args = 1..=2, required = true)]
    args: Vec<String>,
}

#[derive(Debug, Args)]
struct GetArgs {
    /// The context key to read.
    #[arg(value_name = "KEY")]
    key: String,
}

#[derive(Debug, Args)]
struct AppendMessageArgs {
    /// Message role (default: user).
    #[arg(long, default_value = "user", value_name = "ROLE")]
    role: String,
    /// Message content.
    #[arg(value_name = "TEXT")]
    text: String,
}

#[derive(Debug, Subcommand)]
enum McpCommand {
    /// Serve the MCP tool surface over stdio.
    Stdio,
    /// Print the MCP tool metadata as JSON (no server loop).
    Tools,
}

#[derive(Debug, Subcommand)]
enum FeedbackCommand {
    /// Report a feedback / error / perf event to the configured sink.
    Report(FeedbackArgs),
    /// Show the configured feedback sink (secret-free), without sending an event.
    Status,
}

#[derive(Debug, Args)]
struct FeedbackArgs {
    /// Event kind: error | exception | perf | info.
    #[arg(long, default_value = "info", value_name = "KIND")]
    kind: String,
    /// Component / subsystem (defaults to the CLI name).
    #[arg(long, value_name = "COMPONENT")]
    component: Option<String>,
    /// Short summary of the event.
    #[arg(long, value_name = "SUMMARY")]
    summary: String,
    /// Optional detail body.
    #[arg(long, value_name = "DETAIL")]
    detail: Option<String>,
    /// Optional severity: info | warning | error | critical.
    #[arg(long, value_name = "SEVERITY")]
    severity: Option<String>,
}

fn main() {
    // Mirror caco's startup hook: if a staged `nlir_next` exists, promote and
    // re-exec it before doing anything else. No-op when nothing is staged.
    if let Err(error) = updatable_cli::maybe_apply_staged_update(TOOL_NAME) {
        eprintln!("warning: staged-update check failed: {error}");
    }

    let cli = Cli::parse();
    if let Err(code) = run(cli) {
        std::process::exit(code);
    }
}

fn run(cli: Cli) -> Result<(), i32> {
    // First-run convenience (bd-8523df): write a starter ~/.config/nlir/config.yaml
    // if none exists yet. Best-effort — a write failure must not block the command,
    // and an existing config is never overwritten.
    if let Ok(Some(path)) = nlir::config::scaffold_default_config() {
        eprintln!("nlir: wrote a starter config to {}", path.display());
    }
    match cli.command {
        Some(Command::Parse(ref args)) => run_parse(&cli, args),
        Some(Command::Step(ref args)) => run_step(&cli, args),
        Some(Command::Test) => run_test(&cli),
        Some(Command::Help) => run_help(&cli),
        Some(Command::Show(ref args)) => run_show(&cli, args),
        Some(Command::Repl(ref args)) => run_repl(&cli, args),
        Some(Command::Set(ref args)) => run_set(&cli, args),
        Some(Command::Get(ref args)) => run_get(&cli, args),
        Some(Command::AppendMessage(ref args)) => run_append_message(&cli, args),
        Some(Command::Mcp(ref mcp)) => run_mcp(mcp),
        Some(Command::SelfUpdate) => run_self_update(),
        Some(Command::Feedback(ref cmd)) => run_feedback(cmd),
        None => match cli.expr {
            Some(ref expr) => run_eval(&cli, expr),
            None => {
                eprintln!(
                    "nlir: pass -e 'EXPR' to evaluate, or a subcommand (parse|step|test|help|repl|set|get|append-message|mcp|self-update|feedback). See --help."
                );
                Err(2)
            }
        },
    }
}

/// Load the nlir config (SPEC §CLI: `--config PATH` else the default path),
/// mapping a discovery/parse failure to a clear diagnostic + exit code 2.
fn resolve_config(cli: &Cli) -> Result<nlir::config::Config, i32> {
    let mut cfg = nlir::config::load(cli.config.as_deref()).map_err(|error| {
        eprintln!("nlir: {error}");
        2
    })?;
    // Apply the `--parallelism N` override onto the config the DAG scheduler
    // reads. The eval API takes `mode` per call but the Evaluator reads its
    // parallelism from `config.defaults.parallelism`, so a CLI override must be
    // written back here or it is resolved-then-silently-dropped (bd-149949).
    if let Some(parallelism) = cli.parallelism {
        cfg.defaults.parallelism = parallelism.max(1);
    }
    Ok(cfg)
}

/// Build the resolvable-defaults overrides from the global CLI flags.
fn cli_overrides(cli: &Cli) -> nlir::config::DefaultOverrides {
    nlir::config::DefaultOverrides {
        mode: cli.mode.map(Into::into),
        model: cli.model.clone(),
        parallelism: cli.parallelism,
    }
}

/// `nlir help` (aliases `operators`, `ops`) — print a reference of every operator
/// configured in the loaded config: sigil, name, arity/priority, and a one-line
/// summary (the operator's `description:`, else derived from its realisation).
/// Pure config read, so the reference is always in sync with the config (bd-a4096b).
fn run_help(cli: &Cli) -> Result<(), i32> {
    use nlir::config::{Arity, Fixity};
    use std::io::IsTerminal;

    let cfg = resolve_config(cli)?;
    let color = std::io::stdout().is_terminal();
    let bold = |s: &str| {
        if color {
            format!("\x1b[1m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    };
    let dim = |s: &str| {
        if color {
            format!("\x1b[2m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    };

    // Group by fixity (prefix, infix, postfix, mixfix); within a group, tighter
    // binding (higher priority) first, then by sigil.
    let rank = |f: Fixity| match f {
        Fixity::Prefix => 0u8,
        Fixity::Infix => 1,
        Fixity::Postfix => 2,
        Fixity::Mixfix => 3,
    };
    let mut ops: Vec<(&String, &nlir::config::OperatorConfig)> = cfg.operators.iter().collect();
    ops.sort_by(|(na, a), (nb, b)| {
        rank(a.fixity)
            .cmp(&rank(b.fixity))
            .then_with(|| b.priority.unwrap_or(9).cmp(&a.priority.unwrap_or(9)))
            .then_with(|| a.op.cmp(&b.op))
            .then_with(|| na.cmp(nb))
    });

    let sig_w = ops
        .iter()
        .map(|(_, o)| o.op.chars().count())
        .max()
        .unwrap_or(3)
        .max(3);
    let name_w = ops
        .iter()
        .map(|(n, _)| n.chars().count())
        .max()
        .unwrap_or(4)
        .max(4);

    println!(
        "{}",
        bold(&format!(
            "nlir — {} operators (derived from your config)",
            ops.len()
        ))
    );
    let mut current: Option<Fixity> = None;
    let mut any_fallback = false;
    for (name, op) in &ops {
        if current != Some(op.fixity) {
            current = Some(op.fixity);
            println!();
            println!("{}", bold(fixity_label(op.fixity)));
        }
        let arity = match op.arity {
            Arity::Exact(n) => n.to_string(),
            Arity::Variadic => ">0".to_string(),
        };
        let prio = op
            .priority
            .map_or_else(|| "-".to_string(), |p| p.to_string());
        // Realisation: `det` = runs offline in `--mode det`; `llm` = model-only.
        // Shared with the wasm operators() export via OperatorConfig (bd-a4096b).
        let realisation = if op.is_deterministic() { "det" } else { "llm" };
        if op
            .description
            .as_deref()
            .is_none_or(|d| d.trim().is_empty())
        {
            any_fallback = true;
        }
        let meta = dim(&format!("[arity {arity} · prio {prio} · {realisation}]"));
        println!(
            "  {:<sw$}  {:<nw$}  {}  {}",
            op.op,
            name,
            op.summary(),
            meta,
            sw = sig_w,
            nw = name_w,
        );
    }
    println!();
    // Special forms: grammar-level sigils that are NOT config `operators:` (message
    // addressing, stack/interpolation, binding, sequence, grouping, strings). Curated
    // because they live in the lexer/parser, not the config, so they can't be derived.
    println!("{}", bold("special forms — grammar, not config operators:"));
    let special: &[(&str, &str)] = &[
        (
            "$name",
            "read a bound value; $0 $1 … are positional operands. Interpolates inside \"double-quoted\" strings.",
        ),
        (
            "=",
            "bind a value to a name (k = 'x'), then reuse it as $k. The RHS may compute (k = 2+3).",
        ),
        (
            ";",
            "sequence: run statements left-to-right; the value is the LAST statement.",
        ),
        (
            "^",
            "message addressing: ^ all assistant · ^_ all user · ^* whole thread · ^/ system.",
        ),
        (
            "^-1",
            "one message or a range: ^-1 last assistant · ^_-1 your last · ^_-2..^_-1 your last two.",
        ),
        (
            "`",
            "serial: force a subtree to run one-at-a-time (no parallelism).",
        ),
        (
            "( )",
            "grouping — evaluate first (precedence). [ ] is a list: [a, b, c].",
        ),
        (
            "\" \" / ' '",
            "strings: \"double\" interpolates $name; 'single' is literal.",
        ),
    ];
    let sw2 = special
        .iter()
        .map(|(s, _)| s.chars().count())
        .max()
        .unwrap_or(6);
    for (sig, desc) in special {
        println!("  {:<w$}  {}", sig, dim(desc), w = sw2);
    }
    println!();
    println!(
        "{}",
        dim(
            "  sigil · name · what it does · [arity · priority · det=offline / llm=needs a model].  Use in  nlir -e 'EXPR'  or the repl."
        )
    );
    if any_fallback {
        println!(
            "{}",
            dim(
                "  note: some operators have no description: set — showing a derived summary. Refresh your config (or copy the operators: block from config.example.yaml) for the authoritative text."
            )
        );
    }
    Ok(())
}

/// A human-readable group header for a fixity class.
fn fixity_label(fixity: nlir::config::Fixity) -> &'static str {
    use nlir::config::Fixity;
    match fixity {
        Fixity::Prefix => "prefix — the sigil goes before its operand (op x):",
        Fixity::Infix => "infix — the sigil goes between two operands (a op b):",
        Fixity::Postfix => "postfix — the sigil goes after its operand (x op):",
        Fixity::Mixfix => "mixfix — chains / lists (a op b op c, or op[list]):",
    }
}

/// `nlir -e 'EXPR'` — SKELETON identity passthrough (bd-57ad92).
/// Smart-pipe support (Harry's agentic-coding direction): when stdin is piped
/// (not a TTY), read it into the reserved `_stdin` context key so nlir works in
/// a pipeline — `cat foo.rs | nlir -e '<expr using $_stdin>'`. Returns whether
/// stdin was injected (so the caller drops it before write-through). A no-op on a
/// terminal stdin or empty input; set in memory only (never persisted).
fn read_stdin_into_context(ctx: &mut nlir::context::Context) -> bool {
    use std::io::{IsTerminal, Read};
    if std::io::stdin().is_terminal() {
        return false;
    }
    let mut buf = String::new();
    if std::io::stdin().read_to_string(&mut buf).is_ok() && !buf.is_empty() {
        let content = buf.strip_suffix('\n').unwrap_or(&buf).to_string();
        ctx.set_transient("_stdin", serde_json::Value::String(content));
        return true;
    }
    false
}

fn run_eval(cli: &Cli, expr: &str) -> Result<(), i32> {
    let cfg = resolve_config(cli)?;
    let settings = nlir::config::resolve_defaults(&cfg, &cli_overrides(cli));
    // --dry-run: parse to the DAG and make NO calls (bd-e432fc).
    if cli.dry_run {
        return run_dry_run(cli, &cfg, expr, settings.mode);
    }
    let mut ctx = open_context(cli)?;
    // Smart-pipe: expose piped stdin as the reserved `$_stdin` context key so
    // `cat foo.rs | nlir -e '<expr>'` works (Harry's agentic-coding direction).
    let piped_stdin = read_stdin_into_context(&mut ctx);
    // Evaluate against a MUTABLE context (assignments write through).
    let result = nlir::eval::evaluate(expr, &cfg, &mut ctx, settings.mode);
    // Read `_sep` AFTER eval so a `_sep=` assignment affects rendering.
    let sep = ctx.sep();
    match result {
        Ok(value) => {
            let rendered = value.render(&sep);
            // Never persist the transient piped `_stdin` to the store.
            if piped_stdin {
                ctx.remove("_stdin");
            }
            // Persist context writes from this run (SPEC: writes are
            // write-through; a transient store saves as a no-op).
            if let Err(error) = ctx.save() {
                eprintln!("nlir: context write-through: {error}");
                return Err(1);
            }
            // Pretty expansion trace -> stderr, default on; suppressed by --quiet
            // (bd-1d63dc). Mode is selected by --mode / defaults.mode (bd-28dbd4).
            if !cli.quiet {
                eprintln!("nlir [{}]: {expr} -> {rendered}", settings.mode.as_str());
            }
            // Result -> stdout.
            println!("{rendered}");
            Ok(())
        }
        Err(error) => {
            eprintln!("nlir: {error}");
            Err(1)
        }
    }
}

/// `--dry-run`: tokenise + parse `expr` into the DAG and print it, making NO
/// calls (no LLM request, no `command:` subprocess) (bd-e432fc). In llm mode it
/// also previews the assembled prompts that WOULD be sent, per operator (bd-256baa).
fn run_dry_run(
    cli: &Cli,
    cfg: &nlir::config::Config,
    expr: &str,
    mode: nlir::Mode,
) -> Result<(), i32> {
    let out = match parse(
        &ParseInput {
            expr: expr.to_owned(),
        },
        &cfg.operators,
    ) {
        Ok(out) => out,
        Err(error) => {
            eprintln!("nlir: {error}");
            return Err(1);
        }
    };
    if let Some(err) = &out.parse_error {
        eprintln!("nlir --dry-run: parse error: {err}");
        return Err(1);
    }
    if !cli.quiet {
        eprintln!(
            "nlir --dry-run [{}]: DAG below; no calls made.",
            mode.as_str()
        );
    }
    if let Some(ast) = &out.ast {
        println!("{ast}");
    }
    // llm mode: preview the assembled prompts that WOULD be sent (bd-256baa).
    if matches!(mode, nlir::Mode::Llm) {
        preview_llm_prompts(cli, cfg, expr);
    }
    Ok(())
}

/// `--dry-run` llm preview (bd-256baa): for each llm-realised operator in `expr`,
/// print the model + the prompt that WOULD be sent, making NO call. Operands are
/// shown as their source form — exact for literals; a nested subcall is rendered
/// as its (unevaluated) source expression in «…», since its real value is the
/// child's result at eval time.
fn preview_llm_prompts(cli: &Cli, cfg: &nlir::config::Config, expr: &str) {
    let sigils = nlir::config::operator_sigils(cfg);
    let Ok(tokens) = nlir::lexer::tokenize(expr, &sigils) else {
        return;
    };
    let Ok(program) = nlir::parser::parse_program(&tokens, &cfg.operators) else {
        return;
    };
    let mut previews = Vec::new();
    for statement in &program.statements {
        collect_llm_previews(cli, cfg, statement, &mut previews);
    }
    if previews.is_empty() {
        if !cli.quiet {
            eprintln!("nlir --dry-run: no llm-realised operators in this expression.");
        }
        return;
    }
    println!("--- assembled prompts (no calls) ---");
    for preview in previews {
        println!("{preview}");
    }
}

/// Recursively collect assembled-prompt previews for llm-realised operators
/// (no deterministic `command:`/`reduce:`, but a `prompt:`).
fn collect_llm_previews(
    cli: &Cli,
    cfg: &nlir::config::Config,
    expr: &nlir::parser::Expr,
    out: &mut Vec<String>,
) {
    use nlir::parser::Expr;
    match expr {
        Expr::Apply { op, operands, .. } => {
            if let Some(op_cfg) = cfg.operators.values().find(|o| &o.op == op) {
                if op_cfg.command.is_none() && op_cfg.reduce.is_none() {
                    if let Some(prompt) = op_cfg.prompt.as_deref() {
                        let args: Vec<String> = operands.iter().map(operand_preview).collect();
                        let rendered = nlir::llm::realise_llm_preview(
                            op_cfg.model.as_deref(),
                            prompt,
                            &args,
                            cfg,
                            cli.model.as_deref(),
                            |name| std::env::var(name).ok(),
                        );
                        match rendered {
                            Ok(text) => out.push(format!("`{op}` -> {text}")),
                            Err(error) => {
                                out.push(format!("`{op}` -> (cannot preview: {error})"));
                            }
                        }
                    }
                }
            }
            for operand in operands {
                collect_llm_previews(cli, cfg, operand, out);
            }
        }
        Expr::Group(inner) | Expr::Serial(inner) => collect_llm_previews(cli, cfg, inner, out),
        Expr::Message { index, .. } => collect_llm_previews(cli, cfg, index, out),
        Expr::Assign { value, .. } => collect_llm_previews(cli, cfg, value, out),
        Expr::List(items) => {
            for item in items {
                collect_llm_previews(cli, cfg, item, out);
            }
        }
        _ => {}
    }
}

/// Render one operand for the preview: literals exactly; any other sub-expression
/// as its source form wrapped in «…» to signal it is not yet evaluated.
fn operand_preview(expr: &nlir::parser::Expr) -> String {
    use nlir::parser::Expr;
    match expr {
        Expr::Bare(_) | Expr::Number(_) | Expr::Quoted { .. } => expr.render(),
        other => format!("«{}»", other.render()),
    }
}

fn run_parse(cli: &Cli, args: &ParseArgs) -> Result<(), i32> {
    let cfg = resolve_config(cli)?;
    let out = match parse(
        &ParseInput {
            expr: args.expr.clone(),
        },
        &cfg.operators,
    ) {
        Ok(out) => out,
        Err(error) => {
            eprintln!("nlir parse: {error}");
            return Err(1);
        }
    };
    let stdout = io::stdout();
    serde_json::to_writer_pretty(stdout.lock(), &out).map_err(|_| 1)?;
    println!();
    if !cli.quiet {
        eprintln!(
            "nlir parse: skeleton tokeniser ({} configured operator(s)); the grammar-driven tokeniser/DAG parser land downstream.",
            cfg.operators.len()
        );
    }
    Ok(())
}

/// Rasterise an SVG document string to a tiny-skia pixmap via resvg (graph-viz
/// G4, native-only). System fonts are loaded so the SVG's 'Fira Code' labels
/// render (falling back to a monospace face if Fira Code is not installed).
fn svg_to_pixmap(svg: &str) -> Result<resvg::tiny_skia::Pixmap, String> {
    use resvg::{tiny_skia, usvg};
    let mut opt = usvg::Options::default();
    opt.fontdb_mut().load_system_fonts();
    let tree = usvg::Tree::from_str(svg, &opt).map_err(|error| format!("rasterise: {error}"))?;
    let size = tree.size().to_int_size();
    let mut pixmap = tiny_skia::Pixmap::new(size.width(), size.height())
        .ok_or_else(|| "rasterise: could not allocate the pixmap".to_string())?;
    resvg::render(&tree, tiny_skia::Transform::default(), &mut pixmap.as_mut());
    Ok(pixmap)
}

/// Rasterise an SVG document string to PNG bytes (graph-viz G4). `nlir show
/// --png` uses this; the browser (G5) renders the SAME SVG directly, so PNG and
/// DOM stay identical.
fn svg_to_png(svg: &str) -> Result<Vec<u8>, String> {
    svg_to_pixmap(svg)?
        .encode_png()
        .map_err(|error| format!("encode png: {error}"))
}

/// Encode a sequence of graph-frame SVGs as an animated PNG (APNG) for
/// `nlir show --save-animation` (graph-viz G4). Frames shrink as the graph
/// collapses, so each is composited top-left onto a fixed max-size transparent
/// canvas — the animation never resizes. Pixels are demultiplied (tiny-skia is
/// premultiplied) so colours are correct in the PNG.
fn save_animation_apng(
    svgs: &[String],
    path: &std::path::Path,
    delay_ms: u16,
) -> Result<(), String> {
    use resvg::tiny_skia;
    if svgs.is_empty() {
        return Err("no frames to animate".to_string());
    }
    let frames: Vec<tiny_skia::Pixmap> = svgs
        .iter()
        .map(|svg| svg_to_pixmap(svg))
        .collect::<Result<_, _>>()?;
    let max_w = frames
        .iter()
        .map(tiny_skia::Pixmap::width)
        .max()
        .unwrap_or(1);
    let max_h = frames
        .iter()
        .map(tiny_skia::Pixmap::height)
        .max()
        .unwrap_or(1);
    let file = std::fs::File::create(path)
        .map_err(|error| format!("create {}: {error}", path.display()))?;
    let mut encoder = png::Encoder::new(std::io::BufWriter::new(file), max_w, max_h);
    encoder.set_color(png::ColorType::Rgba);
    encoder.set_depth(png::BitDepth::Eight);
    encoder
        .set_animated(frames.len() as u32, 0)
        .map_err(|error| format!("apng: {error}"))?;
    let mut writer = encoder
        .write_header()
        .map_err(|error| format!("apng header: {error}"))?;
    for frame in &frames {
        let mut canvas = tiny_skia::Pixmap::new(max_w, max_h)
            .ok_or_else(|| "apng: could not allocate the canvas".to_string())?;
        canvas.draw_pixmap(
            0,
            0,
            frame.as_ref(),
            &tiny_skia::PixmapPaint::default(),
            tiny_skia::Transform::identity(),
            None,
        );
        let mut rgba = Vec::with_capacity((max_w * max_h * 4) as usize);
        for px in canvas.pixels() {
            let c = px.demultiply();
            rgba.extend_from_slice(&[c.red(), c.green(), c.blue(), c.alpha()]);
        }
        writer
            .set_frame_delay(delay_ms, 1000)
            .map_err(|error| format!("apng delay: {error}"))?;
        writer
            .write_image_data(&rgba)
            .map_err(|error| format!("apng frame: {error}"))?;
    }
    writer
        .finish()
        .map_err(|error| format!("apng finish: {error}"))?;
    Ok(())
}

/// Play the step-frame graphs as a live kitty-terminal animation (graph-viz G4,
/// `nlir show --animate`): draw each frame's PNG, pause, delete it, draw the
/// next. Requires a kitty terminal (or --kitty); --save-animation writes a file.
fn animate_kitty(svgs: &[String], delay_ms: u64) -> Result<(), String> {
    use std::io::Write;
    let tmux = std::env::var_os("TMUX").is_some();
    for (i, svg) in svgs.iter().enumerate() {
        let png = svg_to_png(svg)?;
        if i > 0 {
            // Delete the previous frame's image before drawing the next one.
            let del = "\x1b_Ga=d\x1b\\";
            let seq = if tmux {
                format!("\x1bPtmux;{}\x1b\\", del.replace('\x1b', "\x1b\x1b"))
            } else {
                del.to_string()
            };
            let stdout = std::io::stdout();
            let mut out = stdout.lock();
            let _ = out.write_all(seq.as_bytes());
            let _ = out.flush();
        }
        emit_kitty_png(&png).map_err(|error| error.to_string())?;
        std::thread::sleep(std::time::Duration::from_millis(delay_ms));
    }
    Ok(())
}

/// Whether stdout is a TTY (kitty display only makes sense to a terminal).
fn stdout_is_tty() -> bool {
    use std::io::IsTerminal;
    std::io::stdout().is_terminal()
}

/// Whether the terminal is (or is very likely) kitty, from the environment.
/// Under tmux this is usually false even inside kitty, so `--kitty` forces it.
fn kitty_supported() -> bool {
    std::env::var_os("KITTY_WINDOW_ID").is_some()
        || std::env::var("TERM")
            .map(|t| t.contains("kitty"))
            .unwrap_or(false)
}

/// Emit a PNG to the terminal via the kitty graphics protocol (graph-viz G4):
/// chunked base64 direct transmission (`a=T,f=100`). Inside tmux the escape is
/// wrapped in a DCS passthrough (every ESC doubled) so the image reaches the
/// outer terminal (requires tmux `allow-passthrough on`).
fn emit_kitty_png(png: &[u8]) -> std::io::Result<()> {
    use base64::Engine;
    use std::io::Write;
    let b64 = base64::engine::general_purpose::STANDARD.encode(png);
    let tmux = std::env::var_os("TMUX").is_some();
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    let chunk = 4096usize;
    let n = b64.len().div_ceil(chunk).max(1);
    for i in 0..n {
        let start = i * chunk;
        let end = (start + chunk).min(b64.len());
        let piece = &b64[start..end];
        let m = u8::from(i + 1 < n);
        let ctrl = if i == 0 {
            format!("a=T,f=100,m={m}")
        } else {
            format!("m={m}")
        };
        let esc = format!("\x1b_G{ctrl};{piece}\x1b\\");
        if tmux {
            // tmux passthrough: DCS-wrap and double every ESC in the payload.
            let escaped = esc.replace('\x1b', "\x1b\x1b");
            write!(out, "\x1bPtmux;{escaped}\x1b\\")?;
        } else {
            write!(out, "{esc}")?;
        }
    }
    writeln!(out)?;
    out.flush()
}

/// `nlir show 'EXPR'` — render EXPR's computational dataflow graph as a
/// self-contained SVG (graph-viz epic bd-8ac9ad, G3). The graph is the AST with
/// variable-binding references RESOLVED into edges (an `Assign` node feeds every
/// `$key` read that consumes it). Uses the SAME `nlir::graph` model +
/// `nlir::graph_svg` renderer the wasm workspace uses, so the CLI and the browser
/// draw byte-identical graphs. Prints the SVG to stdout, or `--out FILE` writes it.
fn run_show(cli: &Cli, args: &ShowArgs) -> Result<(), i32> {
    let cfg = resolve_config(cli)?;
    if args.frames || args.save_animation.is_some() || args.animate {
        // --frames / --save-animation: one graph per small-step reduction
        // (nlir::eval::step_frames, the same engine as `nlir step`). Frame 0 is the
        // initial graph; each next frame is one reduction; binding edges persist
        // until each $key read reduces. --frames writes the SVGs; --save-animation
        // rasterises them into one animated PNG.
        let settings = nlir::config::resolve_defaults(&cfg, &cli_overrides(cli));
        let mut ctx = open_context(cli)?;
        let frames = match nlir::eval::step_frames(&args.expr, &cfg, &mut ctx, settings.mode) {
            Ok(frames) => frames,
            Err(error) => {
                eprintln!("nlir show: {error}");
                return Err(1);
            }
        };
        // Assignments write through during stepping; persist them (as `nlir step` does).
        if let Err(error) = ctx.save() {
            eprintln!("nlir: context write-through: {error}");
        }
        let svgs: Vec<String> = frames
            .iter()
            .map(|frame| nlir::graph_svg::render(&frame.graph))
            .collect();
        if let Some(anim) = &args.save_animation {
            if let Err(error) = save_animation_apng(&svgs, anim, 700) {
                eprintln!("nlir show: {error}");
                return Err(1);
            }
            if !cli.quiet {
                eprintln!(
                    "nlir show: wrote a {}-frame animation to {}",
                    svgs.len(),
                    anim.display()
                );
            }
        }
        if args.frames {
            let dir = args
                .out
                .clone()
                .unwrap_or_else(|| std::env::temp_dir().join("nlir-graph-frames"));
            if let Err(error) = std::fs::create_dir_all(&dir) {
                eprintln!("nlir show: creating {}: {error}", dir.display());
                return Err(1);
            }
            for (i, svg) in svgs.iter().enumerate() {
                let path = dir.join(format!("frame-{i:03}.svg"));
                if let Err(error) = std::fs::write(&path, svg) {
                    eprintln!("nlir show: writing {}: {error}", path.display());
                    return Err(1);
                }
            }
            if !cli.quiet {
                eprintln!(
                    "nlir show: wrote {} animation frame(s) to {}",
                    svgs.len(),
                    dir.display()
                );
            }
        }
        if args.animate {
            if !(args.kitty || (kitty_supported() && stdout_is_tty())) {
                eprintln!(
                    "nlir show --animate: no kitty terminal detected (use --kitty to force it, or --save-animation for a shareable file)"
                );
                return Err(1);
            }
            if let Err(error) = animate_kitty(&svgs, 700) {
                eprintln!("nlir show: kitty: {error}");
                return Err(1);
            }
        }
        return Ok(());
    }
    let sigils = nlir::config::operator_sigils(&cfg);
    let tokens = match nlir::lexer::tokenize(&args.expr, &sigils) {
        Ok(t) => t,
        Err(error) => {
            eprintln!("nlir show: {error}");
            return Err(1);
        }
    };
    let program = match nlir::parser::parse_program(&tokens, &cfg.operators) {
        Ok(p) => p,
        Err(error) => {
            eprintln!("nlir show: {error}");
            return Err(1);
        }
    };
    let graph = nlir::graph::Graph::from_program(&program);
    let svg = nlir::graph_svg::render(&graph);
    if let Some(path) = &args.png {
        let png = match svg_to_png(&svg) {
            Ok(png) => png,
            Err(error) => {
                eprintln!("nlir show: {error}");
                return Err(1);
            }
        };
        if let Err(error) = std::fs::write(path, &png) {
            eprintln!("nlir show: writing {}: {error}", path.display());
            return Err(1);
        }
        if !cli.quiet {
            eprintln!(
                "nlir show: wrote {} bytes of PNG to {}",
                png.len(),
                path.display()
            );
        }
        return Ok(());
    }
    if let Some(path) = &args.out {
        if let Err(error) = std::fs::write(path, &svg) {
            eprintln!("nlir show: writing {}: {error}", path.display());
            return Err(1);
        }
        if !cli.quiet {
            eprintln!(
                "nlir show: wrote {} bytes of SVG to {}",
                svg.len(),
                path.display()
            );
        }
        return Ok(());
    }
    // No file output: display in the terminal via the kitty graphics protocol
    // when kitty is detected (or forced with --kitty), else print the SVG.
    if args.kitty || (kitty_supported() && stdout_is_tty()) {
        let png = match svg_to_png(&svg) {
            Ok(png) => png,
            Err(error) => {
                eprintln!("nlir show: {error}");
                return Err(1);
            }
        };
        if let Err(error) = emit_kitty_png(&png) {
            eprintln!("nlir show: kitty: {error}");
            return Err(1);
        }
        return Ok(());
    }
    println!("{svg}");
    Ok(())
}

/// `nlir step 'EXPR'` — small-step "step-through": print the initial expression,
/// then each reduction one redex at a time, ending at the final value
/// (bd-9c366d, Harry's learn-the-language ask). The non-interactive companion to
/// the REPL Tab step-through. Deterministic ops reduce instantly; each LLM op is
/// one step (one realisation) under `--mode llm`.
fn run_step(cli: &Cli, args: &StepArgs) -> Result<(), i32> {
    let cfg = resolve_config(cli)?;
    let settings = nlir::config::resolve_defaults(&cfg, &cli_overrides(cli));
    let mut ctx = open_context(cli)?;
    match nlir::eval::step_trace(&args.expr, &cfg, &mut ctx, settings.mode) {
        Ok(steps) => {
            // Assignments write through during stepping; persist them.
            if let Err(error) = ctx.save() {
                eprintln!("nlir: context write-through: {error}");
                return Err(1);
            }
            // The initial expression, then each reduction, arrow-led so the
            // expansion reads top-to-bottom.
            for (i, step) in steps.iter().enumerate() {
                if i == 0 {
                    println!("    {step}");
                } else {
                    println!("  \u{2192} {step}");
                }
            }
            Ok(())
        }
        Err(error) => {
            eprintln!("nlir step: {error}");
            Err(1)
        }
    }
}

fn run_test(cli: &Cli) -> Result<(), i32> {
    let cfg = resolve_config(cli)?;
    if cfg.tests.is_empty() {
        eprintln!("nlir test: no config-defined tests found");
        return Ok(());
    }
    let mut passed = 0usize;
    let mut failed = 0usize;
    for (name, tc) in &cfg.tests {
        // Seed a fresh transient context with the test's optional context object.
        let mut ctx = nlir::context::Context::empty(&cfg.context);
        if let Some(serde_json::Value::Object(seed)) = &tc.context {
            ctx.merge(seed.clone());
        }
        let result = nlir::eval::evaluate(&tc.expr, &cfg, &mut ctx, tc.mode);
        let sep = ctx.sep();
        match result {
            Ok(value) => {
                let got = value.render(&sep);
                if got == tc.expected {
                    passed += 1;
                    if !cli.quiet {
                        eprintln!("  ok    {name}: {:?} -> {got:?}", tc.expr);
                    }
                } else {
                    failed += 1;
                    eprintln!(
                        "  FAIL  {name}: {:?} -> {got:?} (expected {:?})",
                        tc.expr, tc.expected
                    );
                }
            }
            Err(error) => {
                failed += 1;
                eprintln!("  FAIL  {name}: {:?} -> error: {error}", tc.expr);
            }
        }
    }
    eprintln!(
        "nlir test: {passed} passed, {failed} failed ({} total)",
        cfg.tests.len()
    );
    if failed > 0 { Err(1) } else { Ok(()) }
}

// ---------------------------------------------------------------------------
// REPL session archive / restore (bd-ff485a `--continue`; bd-2275f6 `--resume`
// + bd-414aee `:resume` layer on top). A "session" is a timestamped snapshot of
// the context store, saved beside it under `sessions/<unix-ts>.json`. The live
// store is unchanged — sessions are archived on REPL exit and restored on
// demand, so this is additive over the default REPL persistence.
// ---------------------------------------------------------------------------

/// The effective context store path (`--context-file`, else the config default).
fn effective_context_path(cli: &Cli, cfg: &nlir::config::Config) -> Option<std::path::PathBuf> {
    if let Some(path) = cli.context_file.as_ref() {
        return Some(path.clone());
    }
    let home = std::env::var_os("HOME");
    nlir::context::default_context_path(&cfg.context, home.as_deref())
}

/// The REPL session archive directory: `<context-dir>/sessions/`.
fn sessions_dir(context_path: &std::path::Path) -> std::path::PathBuf {
    context_path
        .parent()
        .unwrap_or_else(|| std::path::Path::new("."))
        .join("sessions")
}

/// Sort key for a session file: its `<ts>.json` stem, falling back to mtime.
fn session_ts(path: &std::path::Path) -> u64 {
    path.file_stem()
        .and_then(|stem| stem.to_str())
        .and_then(|stem| stem.parse::<u64>().ok())
        .or_else(|| {
            std::fs::metadata(path)
                .and_then(|meta| meta.modified())
                .ok()
                .and_then(|time| time.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|dur| dur.as_secs())
        })
        .unwrap_or(0)
}

/// Saved sessions in `dir`, most-recent first.
fn list_sessions(dir: &std::path::Path) -> Vec<std::path::PathBuf> {
    let mut sessions: Vec<std::path::PathBuf> = std::fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| path.extension().and_then(|ext| ext.to_str()) == Some("json"))
        .collect();
    sessions.sort_by_key(|path| std::cmp::Reverse(session_ts(path)));
    sessions
}

/// The most recent saved session, if any.
fn most_recent_session(dir: &std::path::Path) -> Option<std::path::PathBuf> {
    list_sessions(dir).into_iter().next()
}

/// Archive the current context store to `sessions/<ts>.json`. Skips an empty
/// store, and skips when byte-identical to the most-recent archive (no dupes).
/// Returns the archive path when one was written.
fn archive_session(context_path: &std::path::Path) -> Option<std::path::PathBuf> {
    let bytes = std::fs::read(context_path).ok()?;
    let trimmed = std::str::from_utf8(&bytes).unwrap_or("").trim();
    if trimmed.is_empty() || trimmed == "{}" {
        return None;
    }
    let dir = sessions_dir(context_path);
    if let Some(recent) = most_recent_session(&dir) {
        if std::fs::read(&recent).ok().as_deref() == Some(bytes.as_slice()) {
            return None;
        }
    }
    std::fs::create_dir_all(&dir).ok()?;
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|dur| dur.as_secs())
        .unwrap_or(0);
    let dest = dir.join(format!("{ts}.json"));
    std::fs::copy(context_path, &dest).ok()?;
    Some(dest)
}

/// Archive the REPL's context store on exit (best-effort; notes to stderr).
fn archive_repl_session(cli: &Cli) {
    let Ok(cfg) = resolve_config(cli) else {
        return;
    };
    let Some(path) = effective_context_path(cli, &cfg) else {
        return;
    };
    if let Some(dest) = archive_session(&path) {
        eprintln!("nlir: session saved \u{2192} {}", dest.display());
    }
}

/// Restore a saved session by copying it over the active context store.
fn restore_session(cli: &Cli, session: &std::path::Path) -> Result<(), i32> {
    let Ok(cfg) = resolve_config(cli) else {
        return Err(1);
    };
    let Some(path) = effective_context_path(cli, &cfg) else {
        eprintln!("nlir: no context store configured to restore a session into");
        return Err(1);
    };
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    std::fs::copy(session, &path).map_err(|error| {
        eprintln!("nlir: restore session {}: {error}", session.display());
        1
    })?;
    eprintln!("nlir: resumed session {}", session.display());
    Ok(())
}

fn run_repl(cli: &Cli, args: &ReplArgs) -> Result<(), i32> {
    use std::io::IsTerminal;

    // Fail fast on a bad config before entering the loop.
    resolve_config(cli)?;

    // Use the rich rustyline line editor (history, arrow-key line editing,
    // Ctrl-A/Ctrl-E, Ctrl-C/Ctrl-D) only on a real interactive TTY. `--raw` and
    // any non-terminal stdin/stdout (pipes, tests, `nlir repl < file`) keep the
    // plain line-reader path so scripted/piped REPL use is byte-identical
    // (bd-9d2d46).
    if !args.raw && io::stdin().is_terminal() && io::stdout().is_terminal() {
        run_repl_interactive(cli)
    } else {
        run_repl_plain(cli, !args.raw)
    }
}

/// Plain line-reader REPL: reads submissions from stdin with no line editing.
/// This is the scripted/piped path (`nlir repl --raw`, pipes, tests). `prompts`
/// controls whether the `nlir> ` / `  ... ` prompts are echoed to stderr.
fn run_repl_plain(cli: &Cli, prompts: bool) -> Result<(), i32> {
    if prompts {
        eprintln!(
            "nlir repl — one expression per line; end a line with `\\` to continue; `:cmd` runs `nlir cmd` (`:new`/`:set`/`:get`/`:append-message`/`:quit`); Ctrl-D to exit."
        );
    }
    // --continue: restore the most recent saved session before the loop (bd-ff485a).
    if args.continue_session {
        if let Ok(cfg) = resolve_config(cli) {
            if let Some(path) = effective_context_path(cli, &cfg) {
                match most_recent_session(&sessions_dir(&path)) {
                    Some(session) => {
                        let _ = restore_session(cli, &session);
                    }
                    None => eprintln!("nlir: no saved sessions to --continue"),
                }
            }
        }
    }
    let stdin = io::stdin();
    let mut input = stdin.lock();
    let mut pending = String::new();
    loop {
        if prompts {
            eprint!(
                "{}",
                if pending.is_empty() {
                    "nlir> "
                } else {
                    "  ... "
                }
            );
            let _ = io::stderr().flush();
        }
        let mut line = String::new();
        match input.read_line(&mut line) {
            Ok(0) => {
                if prompts {
                    eprintln!();
                }
                archive_repl_session(cli);
                break;
            }
            Ok(_) => {}
            Err(error) => {
                eprintln!("nlir repl: read error: {error}");
                return Err(1);
            }
        }
        let trimmed = line.trim_end_matches(['\n', '\r']);
        // A trailing backslash continues onto the next line (bd-6a0ca8).
        if let Some(head) = trimmed.strip_suffix('\\') {
            pending.push_str(head);
            pending.push('\n');
            continue;
        }
        pending.push_str(trimmed);
        let submission = std::mem::take(&mut pending);
        let submission = submission.trim();
        if submission.is_empty() {
            continue;
        }
        // `:cmd` meta-command == `nlir cmd` (bd-c2ac59).
        if let Some(meta) = submission.strip_prefix(':') {
            let _ = repl_meta_command(cli, meta.trim());
        } else {
            // Evaluate; context is re-opened each time so writes/reloads reflect.
            repl_eval(cli, submission);
        }
    }
    Ok(())
}

/// Rich interactive REPL backed by rustyline (bd-9d2d46): command history
/// (persisted across sessions), full line editing (arrow keys, Ctrl-A/Ctrl-E,
/// word/kill bindings), and interrupt handling — Ctrl-C abandons the current
/// (possibly multi-line) input without exiting, Ctrl-D exits cleanly. Line
/// semantics (`\` continuation, `:cmd` meta-commands, empty-line skip) match the
/// plain path exactly so only the input surface changes.
fn run_repl_interactive(cli: &Cli) -> Result<(), i32> {
    use rustyline::error::ReadlineError;

    let mut editor = match rustyline::DefaultEditor::new() {
        Ok(editor) => editor,
        Err(error) => {
            // Fall back to the plain reader if the terminal can't host rustyline.
            eprintln!("nlir repl: line editor unavailable ({error}); using plain input.");
            return run_repl_plain(cli, true);
        }
    };

    // Persist command history across sessions (best-effort; a missing file on
    // first run is expected and ignored).
    let history_path = repl_history_path(cli);
    if let Some(path) = history_path.as_deref() {
        let _ = editor.load_history(path);
    }

    eprintln!(
        "nlir repl — one expression per line; end a line with `\\` to continue; `:cmd` runs `nlir cmd` (`:set`/`:get`/`:append-message`/`:quit`); ↑/↓ history, Ctrl-A/Ctrl-E line edit, Ctrl-C cancels the line, Ctrl-D exits."
    );

    let mut pending = String::new();
    let result = loop {
        let prompt = if pending.is_empty() {
            "nlir> "
        } else {
            "  ... "
        };
        match editor.readline(prompt) {
            Ok(line) => {
                let trimmed = line.trim_end_matches(['\n', '\r']);
                // A trailing backslash continues onto the next line (bd-6a0ca8).
                if let Some(head) = trimmed.strip_suffix('\\') {
                    pending.push_str(head);
                    pending.push('\n');
                    continue;
                }
                pending.push_str(trimmed);
                let submission = std::mem::take(&mut pending);
                let submission = submission.trim();
                if submission.is_empty() {
                    continue;
                }
                // Record the full submission (multi-line included) in history
                // before dispatch so ↑ recalls it even if evaluation exits.
                let _ = editor.add_history_entry(submission);
                // `:cmd` meta-command == `nlir cmd` (bd-c2ac59). Intercept the
                // quit aliases here so history is flushed on the way out instead
                // of `repl_meta_command`'s bare `std::process::exit(0)`.
                if let Some(meta) = submission.strip_prefix(':') {
                    let meta = meta.trim();
                    if matches!(meta, "quit" | "exit" | "q") {
                        break Ok(());
                    }
                    let _ = repl_meta_command(cli, meta);
                } else {
                    // Context is re-opened each time so writes/reloads reflect.
                    repl_eval(cli, submission);
                }
            }
            // Ctrl-C: abandon the current input, keep the REPL alive.
            Err(ReadlineError::Interrupted) => {
                pending.clear();
                continue;
            }
            // Ctrl-D on an empty line: exit cleanly.
            Err(ReadlineError::Eof) => break Ok(()),
            Err(error) => {
                eprintln!("nlir repl: read error: {error}");
                break Err(1);
            }
        }
    };

    if let Some(path) = history_path.as_deref() {
        // Ensure the parent dir exists before saving (best-effort).
        if let Some(dir) = path.parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        let _ = editor.save_history(path);
    }
    result
}

/// Resolve the REPL command-history file. Co-locates with the configured context
/// store directory when one is set (e.g. `~/.config/nlir/repl_history.txt`),
/// otherwise falls back to `~/.config/nlir/repl_history.txt`. Returns `None` only
/// when no home directory is available and no context path is configured.
fn repl_history_path(cli: &Cli) -> Option<PathBuf> {
    let home = std::env::var_os("HOME");
    if let Ok(cfg) = resolve_config(cli) {
        if let Some(ctx_path) = nlir::context::default_context_path(&cfg.context, home.as_deref()) {
            if let Some(dir) = ctx_path.parent() {
                return Some(dir.join("repl_history.txt"));
            }
        }
    }
    home.map(|home| PathBuf::from(home).join(".config/nlir/repl_history.txt"))
}

/// Evaluate one REPL submission, re-reading config + context each time (context
/// reload, bd-6a0ca8). Prints the result to stdout; an error goes to stderr and
/// does not end the loop.
fn repl_eval(cli: &Cli, expr: &str) {
    let Ok(cfg) = resolve_config(cli) else {
        return;
    };
    let Ok(mut ctx) = open_context(cli) else {
        return;
    };
    let settings = nlir::config::resolve_defaults(&cfg, &cli_overrides(cli));
    let result = nlir::eval::evaluate(expr, &cfg, &mut ctx, settings.mode);
    let sep = ctx.sep();
    match result {
        Ok(value) => {
            let _ = ctx.save();
            println!("{}", value.render(&sep));
        }
        Err(error) => eprintln!("nlir: {error}"),
    }
}

/// Run a REPL `:cmd` meta-command as the matching `nlir` subcommand (bd-c2ac59).
/// Interactive step-through of an expression's evaluation (`:step EXPR`, Harry
/// ask #1 — "press Tab to expand the next eval step"). On a TTY it enters raw
/// mode, shows the parsed expression, and lets the user drive: Tab/Space reduces
/// one step, Enter runs to completion, q/Esc/Ctrl-C cancels. On a non-TTY (pipes,
/// tests) it degrades to a single full evaluation so scripted REPL use is
/// unchanged.
///
/// Engine (bd-9c366d): the per-step reducer is msm-0's `Evaluator::step_once`
/// (`Step::Reduced(Expr)` / `Done(Value)`), driven by ONE `Evaluator` so the
/// run-scoped stack + realise cache persist across steps and `key=RHS` writes
/// land in ctx. Each partially-reduced tree is reprinted via the
/// precedence-aware `Expr::render_step()` (reduced nodes shown as «…»).
fn run_step_view(cli: &Cli, expr_str: &str) -> Result<(), i32> {
    use std::io::{IsTerminal, Write};

    let cfg = resolve_config(cli)?;
    let Ok(mut ctx) = open_context(cli) else {
        return Err(1);
    };
    let settings = nlir::config::resolve_defaults(&cfg, &cli_overrides(cli));
    let mode = settings.mode;
    let sep = ctx.sep();

    // Parse to a single-statement Expr (MVP; multi-statement stepping arrives
    // with the engine).
    let sigils = nlir::config::operator_sigils(&cfg);
    let tokens = match nlir::lexer::tokenize(expr_str, &sigils) {
        Ok(t) => t,
        Err(error) => {
            eprintln!("nlir step: {error}");
            return Err(1);
        }
    };
    let program = match nlir::parser::parse_program(&tokens, &cfg.operators) {
        Ok(p) => p,
        Err(error) => {
            eprintln!("nlir step: {error}");
            return Err(1);
        }
    };
    let Some(cur) = program.statements.into_iter().next() else {
        return Ok(());
    };

    // Non-TTY (pipes/tests): degrade to a single full evaluation so scripted REPL
    // use is unchanged.
    if !std::io::stdin().is_terminal() || !std::io::stdout().is_terminal() {
        match nlir::eval::evaluate(expr_str, &cfg, &mut ctx, mode) {
            Ok(value) => {
                let _ = ctx.save();
                println!("{}", value.render(&sep));
            }
            Err(error) => eprintln!("nlir step: {error}"),
        }
        return Ok(());
    }

    eprintln!("nlir step — Tab/Space: next step · Enter: run to completion · q/Esc: cancel");
    if crossterm::terminal::enable_raw_mode().is_err() {
        match nlir::eval::evaluate(expr_str, &cfg, &mut ctx, mode) {
            Ok(value) => println!("{}", value.render(&sep)),
            Err(error) => eprintln!("nlir step: {error}"),
        }
        return Ok(());
    }
    // Restore cooked mode on ANY exit from here (incl. a panic) so a broken step
    // never leaves the operator's terminal in raw mode.
    let _raw = RawModeGuard;
    // Drive the small-step engine: build ONE evaluator so the stack + realise
    // cache persist across steps and `key=RHS` writes land in ctx. Each Tab
    // reduces one redex and reprints the tree; Enter drains to the final value.
    let outcome = {
        let mut ev = nlir::eval::Evaluator::new(&cfg, &mut ctx, mode);
        let mut cur = cur;
        loop {
            let _ = write!(std::io::stdout(), "\r\n  {}\r\n", cur.render_step());
            let _ = std::io::stdout().flush();
            match read_step_key() {
                StepKey::Step => match ev.step_once(&cur) {
                    Ok(nlir::eval::Step::Reduced(next)) => cur = next,
                    Ok(nlir::eval::Step::Done(value)) => break Some(value.render(&sep)),
                    Err(error) => break Some(format!("error: {error}")),
                },
                StepKey::Run => {
                    break loop {
                        match ev.step_once(&cur) {
                            Ok(nlir::eval::Step::Reduced(next)) => cur = next,
                            Ok(nlir::eval::Step::Done(value)) => break Some(value.render(&sep)),
                            Err(error) => break Some(format!("error: {error}")),
                        }
                    };
                }
                StepKey::Cancel => break None,
            }
        }
    };

    let _ = crossterm::terminal::disable_raw_mode();
    let _ = writeln!(std::io::stdout());
    match outcome {
        Some(value) => {
            let _ = ctx.save();
            println!("{value}");
        }
        None => eprintln!("nlir step: cancelled"),
    }
    Ok(())
}

/// RAII guard: leaves raw mode when dropped, so any early return or panic in the
/// step view restores the terminal.
struct RawModeGuard;
impl Drop for RawModeGuard {
    fn drop(&mut self) {
        let _ = crossterm::terminal::disable_raw_mode();
    }
}

/// One step-view control action, decoded from a raw-mode key press.
enum StepKey {
    Step,
    Run,
    Cancel,
}

/// Block in raw mode until the user presses a step-view control key. Non-key and
/// non-press events are ignored; a read error is treated as cancel.
fn read_step_key() -> StepKey {
    use crossterm::event::{Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers, read};
    loop {
        match read() {
            Ok(Event::Key(KeyEvent {
                code,
                modifiers,
                kind: KeyEventKind::Press,
                ..
            })) => match code {
                KeyCode::Tab | KeyCode::Char(' ') => return StepKey::Step,
                KeyCode::Enter => return StepKey::Run,
                KeyCode::Char('q') | KeyCode::Esc => return StepKey::Cancel,
                KeyCode::Char('c') if modifiers.contains(KeyModifiers::CONTROL) => {
                    return StepKey::Cancel;
                }
                _ => {}
            },
            Ok(_) => {}
            Err(_) => return StepKey::Cancel,
        }
    }
}

/// `:new` — clear user context (all non-system keys + `_messages`) for a fresh
/// start within the same REPL session, then persist (bd-56e593). Save is a
/// no-op for a transient store. Confirmation goes to stderr so stdout stays
/// clean for eval results.
fn run_new(cli: &Cli) -> Result<(), i32> {
    let mut ctx = open_context(cli)?;
    ctx.clear_user();
    if let Err(error) = ctx.save() {
        eprintln!("nlir: context: {error}");
        return Err(1);
    }
    eprintln!("nlir: context cleared — fresh start (keys + messages)");
    Ok(())
}

fn repl_meta_command(cli: &Cli, meta: &str) -> Result<(), i32> {
    let parts: Vec<&str> = meta.split_whitespace().collect();
    match parts.as_slice() {
        [] => Ok(()),
        ["quit" | "exit" | "q"] => {
            archive_repl_session(cli);
            std::process::exit(0)
        }
        ["new"] => run_new(cli),
        ["set", tail @ ..] if !tail.is_empty() => run_set(
            cli,
            &SetArgs {
                args: tail.iter().map(|s| (*s).to_owned()).collect(),
            },
        ),
        ["get", key] => run_get(
            cli,
            &GetArgs {
                key: (*key).to_owned(),
            },
        ),
        ["append-message", "--role", role, tail @ ..] if !tail.is_empty() => run_append_message(
            cli,
            &AppendMessageArgs {
                role: (*role).to_owned(),
                text: tail.join(" "),
            },
        ),
        ["append-message", tail @ ..] if !tail.is_empty() => run_append_message(
            cli,
            &AppendMessageArgs {
                role: "user".to_owned(),
                text: tail.join(" "),
            },
        ),
        ["step", tail @ ..] if !tail.is_empty() => run_step_view(cli, &tail.join(" ")),
        _ => {
            eprintln!(
                "nlir repl: unknown meta-command ':{meta}' (try :new, :step EXPR, :set KEY VALUE, :get KEY, :append-message [--role R] TEXT, :quit)"
            );
            Err(2)
        }
    }
}

/// Open the context store, then optionally overlay a `--session-file` import.
///
/// Base context follows SPEC source precedence (bd-f6ba99): `--context-file` >
/// `NLIR_CONTEXT` env > the config default file (strict first-present-wins in
/// [`nlir::context::Context::load`]). `--session-file` is then applied as an
/// ADDITIVE `_messages` overlay (bd-000666): its parsed messages are appended to
/// the effective context, so it is combinable with `--context-file` rather than
/// a mutually-exclusive precedence slot.
///
/// NOTE (SPEC ambiguity, flagged for the author): SPEC §CLI lists
/// `--session-file` inside the read precedence chain, which reads as
/// strict-precedence; bd-000666 says "merge … combinable with --context-file".
/// This wiring implements the combinable/additive reading.
fn open_context(cli: &Cli) -> Result<nlir::context::Context, i32> {
    let cfg = resolve_config(cli)?;
    let env_inline = std::env::var("NLIR_CONTEXT").ok();
    let home = std::env::var_os("HOME");
    let default_file = nlir::context::default_context_path(&cfg.context, home.as_deref());
    let sources = nlir::context::LoadSources {
        context_file: cli.context_file.as_deref(),
        session: None,
        env_inline: env_inline.as_deref(),
        default_file: default_file.as_deref(),
    };
    let mut ctx = nlir::context::Context::load(sources, &cfg.context).map_err(|error| {
        eprintln!("nlir: context: {error}");
        1
    })?;
    if let Some(path) = cli.session_file.as_deref() {
        let text = std::fs::read_to_string(path).map_err(|error| {
            eprintln!("nlir: session file {}: {error}", path.display());
            1
        })?;
        let session_cfg = select_session_config(&cfg);
        let messages = nlir::session::parse_pi_session(&text, &session_cfg).map_err(|error| {
            eprintln!("nlir: session parse: {error}");
            1
        })?;
        for (role, content) in messages {
            ctx.append_message(&role, &content).map_err(|error| {
                eprintln!("nlir: session import: {error}");
                1
            })?;
        }
    }
    Ok(ctx)
}

/// Pick the session importer config: prefer a `pi` entry, else the first
/// configured session, else a built-in Pi default (keep user/assistant, drop
/// tool turns).
fn select_session_config(cfg: &nlir::config::Config) -> nlir::config::SessionConfig {
    cfg.sessions
        .get("pi")
        .or_else(|| cfg.sessions.values().next())
        .cloned()
        .unwrap_or_else(|| nlir::config::SessionConfig {
            format: "pi".to_owned(),
            keep_roles: vec!["user".to_owned(), "assistant".to_owned()],
            drop_tool_messages: true,
            ..Default::default()
        })
}

/// Warn (unless `--quiet`) when a mutation targets a transient store with no
/// write-through file, so a `set`/`append-message` that cannot persist is not
/// silently lost (SPEC: `NLIR_CONTEXT` env / session imports are transient).
fn warn_if_transient(cli: &Cli, ctx: &nlir::context::Context) {
    if !cli.quiet && ctx.file().is_none() {
        eprintln!(
            "nlir: warning: no write-through context file (transient store); the change will not persist. Set `--context-file PATH` or `context.file_default`."
        );
    }
}

fn run_set(cli: &Cli, args: &SetArgs) -> Result<(), i32> {
    let mut ctx = open_context(cli)?;
    match args.args.as_slice() {
        // `set '{...}'` — a JSON object whose named keys replace (not deep-merge).
        [single] if single.trim_start().starts_with('{') => {
            match serde_json::from_str::<serde_json::Value>(single) {
                Ok(serde_json::Value::Object(map)) => ctx.merge(map),
                Ok(_) => {
                    eprintln!("nlir set: the single-argument form must be a JSON object `{{...}}`");
                    return Err(2);
                }
                Err(error) => {
                    eprintln!("nlir set: invalid JSON object: {error}");
                    return Err(2);
                }
            }
        }
        // `set KEY VALUE` — replace one key with a string value.
        [key, value] => {
            ctx.set(key.clone(), serde_json::Value::String(value.clone()))
                .map_err(|error| {
                    eprintln!("nlir set: {error}");
                    1
                })?;
        }
        _ => {
            eprintln!("nlir set: expected `set KEY VALUE` or `set '{{...}}'`");
            return Err(2);
        }
    }
    warn_if_transient(cli, &ctx);
    ctx.save().map_err(|error| {
        eprintln!("nlir set: write-through: {error}");
        1
    })
}

fn run_get(cli: &Cli, args: &GetArgs) -> Result<(), i32> {
    let ctx = open_context(cli)?;
    match ctx.render_key(&args.key) {
        Some(text) => {
            println!("{text}");
            Ok(())
        }
        None => {
            eprintln!("nlir get: no such context key {:?}", args.key);
            Err(1)
        }
    }
}

fn run_append_message(cli: &Cli, args: &AppendMessageArgs) -> Result<(), i32> {
    let mut ctx = open_context(cli)?;
    ctx.append_message(&args.role, &args.text)
        .map_err(|error| {
            eprintln!("nlir append-message: {error}");
            1
        })?;
    warn_if_transient(cli, &ctx);
    ctx.save().map_err(|error| {
        eprintln!("nlir append-message: write-through: {error}");
        1
    })
}

fn run_mcp(mcp: &McpCommand) -> Result<(), i32> {
    let router = build_router();
    let server = McpServer::new(
        StdioServerConfig {
            server_name: TOOL_NAME.to_owned(),
            server_version: env!("CARGO_PKG_VERSION").to_owned(),
        },
        router,
    );
    match mcp {
        McpCommand::Tools => {
            let stdout = io::stdout();
            serde_json::to_writer_pretty(stdout.lock(), &server.tool_metadata()).map_err(|_| 1)?;
            println!();
            Ok(())
        }
        McpCommand::Stdio => server.serve_stdio(&AppContext).map_err(|error| {
            eprintln!("mcp error: {error}");
            1
        }),
    }
}

fn run_self_update() -> Result<(), i32> {
    let updater = updatable_cli::Updater::new(updater_config());
    match updater.run_update() {
        Ok(outcome) => {
            if outcome.promoted {
                println!(
                    "nlir updated {} -> {} ({})",
                    outcome.current_version, outcome.latest_version, outcome.installed_path
                );
            } else if outcome.staged {
                println!(
                    "nlir staged {} at {} (promotes on the next run)",
                    outcome.latest_version, outcome.next_path
                );
            } else if let Some(note) = &outcome.note {
                println!(
                    "nlir self-update: {note} (current {})",
                    outcome.current_version
                );
            } else {
                println!(
                    "nlir self-update: already at the latest version ({})",
                    outcome.current_version
                );
            }
            Ok(())
        }
        Err(error) => {
            eprintln!("nlir self-update error: {error:#}");
            Err(1)
        }
    }
}

fn run_feedback(cmd: &FeedbackCommand) -> Result<(), i32> {
    match cmd {
        FeedbackCommand::Report(args) => run_feedback_report(args),
        FeedbackCommand::Status => run_feedback_status(),
    }
}

/// `nlir feedback status`: report the configured sink without sending an event.
/// The destination is secret-free (feedback-cli never renders tokens into it).
fn run_feedback_status() -> Result<(), i32> {
    let reporter = Reporter::from_config(&feedback_config());
    let state = if reporter.is_enabled() {
        "enabled"
    } else {
        "disabled (events print to stderr)"
    };
    println!("feedback: {state}");
    println!("destination: {}", reporter.destination());
    Ok(())
}

fn run_feedback_report(args: &FeedbackArgs) -> Result<(), i32> {
    let kind = match args.kind.to_ascii_lowercase().as_str() {
        "error" => FeedbackKind::Error,
        "exception" => FeedbackKind::Exception,
        "perf" => FeedbackKind::Perf,
        "info" => FeedbackKind::Info,
        other => {
            eprintln!("nlir feedback: unknown --kind '{other}' (want error|exception|perf|info)");
            return Err(2);
        }
    };
    let component = args
        .component
        .clone()
        .unwrap_or_else(|| TOOL_NAME.to_owned());
    let mut event = FeedbackEvent::new(kind, component, args.summary.clone());
    event.detail = args.detail.clone();
    if let Some(sev) = &args.severity {
        event.severity = Some(match sev.to_ascii_lowercase().as_str() {
            "info" => Severity::Info,
            "warning" => Severity::Warning,
            "error" => Severity::Error,
            "critical" => Severity::Critical,
            other => {
                eprintln!(
                    "nlir feedback: unknown --severity '{other}' (want info|warning|error|critical)"
                );
                return Err(2);
            }
        });
    }

    let reporter = Reporter::from_config(&feedback_config());
    match reporter.report(&event) {
        Ok(()) => {
            let mut stderr = io::stderr();
            let _ = writeln!(
                stderr,
                "nlir feedback: reported to {}",
                reporter.destination()
            );
            Ok(())
        }
        Err(error) => {
            eprintln!("nlir feedback: {error}");
            Err(1)
        }
    }
}

#[cfg(test)]
mod cli_tests {
    use super::*;

    // bd-d2d23c: an expression that opens with `-` (e.g. a leading-negative range
    // index) must be parsed as the EXPR value, not rejected by clap as an unknown
    // flag. `allow_hyphen_values` on the expr args guards this.
    #[test]
    fn expr_flag_accepts_leading_hyphen_value() {
        let cli = Cli::try_parse_from(["nlir", "-e", "-1^*0"])
            .expect("leading-hyphen expr must parse as a value");
        assert_eq!(cli.expr.as_deref(), Some("-1^*0"));

        let cli = Cli::try_parse_from(["nlir", "--expr", "-5+3"])
            .expect("leading-hyphen --expr must parse as a value");
        assert_eq!(cli.expr.as_deref(), Some("-5+3"));
    }

    #[test]
    fn parse_subcommand_accepts_leading_hyphen_value() {
        let cli = Cli::try_parse_from(["nlir", "parse", "-1^*0"])
            .expect("parse subcommand must accept a leading-hyphen expr");
        assert!(matches!(cli.command, Some(Command::Parse(_))));
    }

    // Guard against the fix over-reaching: a genuinely unknown flag must still error.
    #[test]
    fn unknown_flag_still_rejected() {
        assert!(Cli::try_parse_from(["nlir", "--definitely-not-a-flag"]).is_err());
    }
}
