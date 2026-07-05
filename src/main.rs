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
    /// Run the config-defined test suite.
    Test,
    /// Print a config-derived reference of every operator + a one-line summary.
    #[command(visible_aliases = ["operators", "ops"])]
    Help,
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
struct ReplArgs {
    /// Raw mode: pipe shorthand straight in without the pretty prompt.
    #[arg(long)]
    raw: bool,
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
        Some(Command::Test) => run_test(&cli),
        Some(Command::Help) => run_help(&cli),
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
                    "nlir: pass -e 'EXPR' to evaluate, or a subcommand (parse|test|help|repl|set|get|append-message|mcp|self-update|feedback). See --help."
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
        let meta = dim(&format!("[arity {arity} · prio {prio}]"));
        println!(
            "  {:<sw$}  {:<nw$}  {}  {}",
            op.op,
            name,
            operator_summary(op),
            meta,
            sw = sig_w,
            nw = name_w,
        );
    }
    println!();
    println!(
        "{}",
        dim(
            "  sigil · name · what it does · [arity · priority].  Use in  nlir -e 'EXPR'  or the repl."
        )
    );
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

/// The one-line summary for an operator: its `description:` if set, else derived
/// from its deterministic realisation (reduce / join / template / command) or the
/// first line of its LLM prompt.
fn operator_summary(op: &nlir::config::OperatorConfig) -> String {
    use nlir::config::ReduceOp;
    if let Some(d) = op.description.as_deref() {
        let d = d.trim();
        if !d.is_empty() {
            return d.to_string();
        }
    }
    if let Some(reduce) = op.reduce {
        return match reduce {
            ReduceOp::Add => "sum of the numeric operands",
            ReduceOp::Sub => "difference, a − b",
            ReduceOp::Mul => "product of the numeric operands",
            ReduceOp::Div => "quotient, a ÷ b",
            ReduceOp::Pow => "a to the power b",
        }
        .to_string();
    }
    if let Some(join) = op.join.as_deref() {
        return format!("joins its operands with \"{}\"", join.trim());
    }
    if let Some(template) = op.template.as_deref() {
        return format!("deterministic template: {template}");
    }
    if op.command.is_some() {
        return "runs a configured shell command".to_string();
    }
    if let Some(prompt) = op.prompt.as_deref() {
        let first = prompt.split(['\n', '.']).next().unwrap_or("").trim();
        if !first.is_empty() {
            return format!("{first} (LLM)");
        }
    }
    "—".to_string()
}

/// `nlir -e 'EXPR'` — SKELETON identity passthrough (bd-57ad92).
fn run_eval(cli: &Cli, expr: &str) -> Result<(), i32> {
    let cfg = resolve_config(cli)?;
    let settings = nlir::config::resolve_defaults(&cfg, &cli_overrides(cli));
    // --dry-run: parse to the DAG and make NO calls (bd-e432fc).
    if cli.dry_run {
        return run_dry_run(cli, &cfg, expr, settings.mode);
    }
    let mut ctx = open_context(cli)?;
    // Evaluate against a MUTABLE context (assignments write through).
    let result = nlir::eval::evaluate(expr, &cfg, &mut ctx, settings.mode);
    // Read `_sep` AFTER eval so a `_sep=` assignment affects rendering.
    let sep = ctx.sep();
    match result {
        Ok(value) => {
            let rendered = value.render(&sep);
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

fn run_repl(cli: &Cli, args: &ReplArgs) -> Result<(), i32> {
    // Fail fast on a bad config before entering the loop.
    resolve_config(cli)?;
    let interactive = !args.raw;
    if interactive {
        eprintln!(
            "nlir repl — one expression per line; end a line with `\\` to continue; `:cmd` runs `nlir cmd` (`:set`/`:get`/`:append-message`/`:quit`); Ctrl-D to exit."
        );
    }
    let stdin = io::stdin();
    let mut input = stdin.lock();
    let mut pending = String::new();
    loop {
        if interactive {
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
                if interactive {
                    eprintln!();
                }
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
fn repl_meta_command(cli: &Cli, meta: &str) -> Result<(), i32> {
    let parts: Vec<&str> = meta.split_whitespace().collect();
    match parts.as_slice() {
        [] => Ok(()),
        ["quit" | "exit" | "q"] => std::process::exit(0),
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
        _ => {
            eprintln!(
                "nlir repl: unknown meta-command ':{meta}' (try :set KEY VALUE, :get KEY, :append-message [--role R] TEXT, :quit)"
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
