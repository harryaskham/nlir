//! Statement-level dataflow of a program (v2 §G): one node per top-level
//! statement, an edge wherever a statement reads `$name` bound by another —
//! including reads inside form bodies, which is how libraries call each other —
//! and an input node for every name the program reads but never binds (bound
//! data, prelude forms, piped stdin).
//!
//! The expression graph (`crate::graph`) draws every operator and value, which is
//! the right view of one expression and unreadable for a forty-statement learned
//! program. The outline is the view a reviewer needs: which parts exist, what each
//! is (form, data, computed value, output), how they depend on each other, and
//! where the model calls are. [`Outline::to_text`] gives the same view as text for
//! prompts and logs; [`render_svg`] draws it.

use crate::config::Config;
use crate::parser::{Expr, Program};
use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fmt::Write as _;

/// What a statement is.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Kind {
    /// A name the program reads but never binds.
    Input,
    /// `name = {…}` — a reusable form.
    Form,
    /// `name = literal / list / dict` with no operators or reads.
    Data,
    /// `name = expr` — a computed value.
    Value,
    /// The final statement: the program's result.
    Output,
    /// A non-final statement that binds nothing (a computation for the stack).
    Step,
}

impl Kind {
    fn label(self) -> &'static str {
        match self {
            Kind::Input => "input",
            Kind::Form => "form",
            Kind::Data => "data",
            Kind::Value => "value",
            Kind::Output => "output",
            Kind::Step => "step",
        }
    }
}

/// One node of the outline.
#[derive(Debug, Clone, Serialize)]
pub struct Statement {
    /// The bound name, or `out` / `#N` for unbound statements.
    pub name: String,
    pub kind: Kind,
    /// The statement's right-hand side, rendered.
    pub source: String,
    /// Distinct operators applied, in first-use order.
    pub ops: Vec<String>,
    /// Operator applications realised by a model (counted once per site, so a
    /// form called many times still counts its body once).
    pub model_ops: usize,
    /// Names read (bound elsewhere or external), in first-read order.
    pub reads: Vec<String>,
    /// Whether the statement reads its own name (a recursive form).
    pub recursive: bool,
    /// For inputs: `prelude`, `data` or `external`.
    pub origin: Option<String>,
    /// Layout column (0 = inputs and leaves).
    pub layer: usize,
    /// Layout row within the column.
    pub row: usize,
}

/// The statement-level dataflow of a program.
#[derive(Debug, Clone, Serialize)]
pub struct Outline {
    pub statements: Vec<Statement>,
    /// `(from, to)` statement indices: `to` reads a name `from` binds.
    pub edges: Vec<(usize, usize)>,
}

/// Build the outline of `program` under `config` (for operator realisations and
/// the prelude). `bound` names external data the caller binds (e.g. `--bind`).
#[must_use]
pub fn outline(program: &Program, config: &Config, bound: &[String]) -> Outline {
    let model_ops: HashMap<&str, bool> = config
        .operators
        .values()
        .map(|op| (op.op.as_str(), !op.is_deterministic()))
        .collect();
    let prelude_names = prelude_names(config);
    let count = program.statements.len();
    let mut statements = Vec::with_capacity(count);
    let mut binders: BTreeMap<String, Vec<usize>> = BTreeMap::new();
    for (i, statement) in program.statements.iter().enumerate() {
        let (name, rhs, assigned) = match statement {
            Expr::Assign { key, value } => (key.clone(), value.as_ref(), true),
            other if i + 1 == count => ("out".to_owned(), other, false),
            other => (format!("#{}", i + 1), other, false),
        };
        let mut acc = Acc::default();
        walk(rhs, &model_ops, &mut acc);
        let kind = if !assigned {
            if i + 1 == count {
                Kind::Output
            } else {
                Kind::Step
            }
        } else if matches!(rhs, Expr::Quote(_)) {
            Kind::Form
        } else if acc.ops.is_empty() && acc.reads.is_empty() && acc.applies == 0 {
            Kind::Data
        } else {
            Kind::Value
        };
        if assigned {
            binders.entry(name.clone()).or_default().push(i);
        }
        let recursive = assigned && acc.reads.contains(&name);
        statements.push(Statement {
            name,
            kind,
            source: compact(&rhs.render()),
            ops: acc.ops,
            model_ops: acc.model_ops,
            reads: acc.reads,
            recursive,
            origin: None,
            layer: 0,
            row: 0,
        });
    }
    // Resolve reads to binders: the latest binding before the read, else the first
    // after it (a forward reference from a form body), else an input node.
    let mut edges = BTreeSet::new();
    let mut inputs: BTreeMap<String, usize> = BTreeMap::new();
    for i in 0..count {
        for name in statements[i].reads.clone() {
            if crate::eval::BUILTIN_NAMES.contains(&name.as_str()) && !binders.contains_key(&name) {
                continue;
            }
            if binders.get(&name).is_some_and(|at| at.contains(&i)) {
                continue; // a recursive self-read (flagged on the statement)
            }
            let from = match binders.get(&name) {
                Some(at) => at
                    .iter()
                    .rev()
                    .find(|&&j| j < i)
                    .or_else(|| at.iter().find(|&&j| j > i))
                    .copied(),
                None => None,
            };
            let from = match from {
                Some(j) => j,
                None => *inputs.entry(name.clone()).or_insert_with(|| {
                    let origin = if prelude_names.contains(&name) {
                        "prelude"
                    } else if bound.contains(&name) {
                        "data"
                    } else {
                        "external"
                    };
                    statements.push(Statement {
                        name: name.clone(),
                        kind: Kind::Input,
                        source: String::new(),
                        ops: Vec::new(),
                        model_ops: 0,
                        reads: Vec::new(),
                        recursive: false,
                        origin: Some(origin.to_owned()),
                        layer: 0,
                        row: 0,
                    });
                    statements.len() - 1
                }),
            };
            edges.insert((from, i));
        }
    }
    let mut out = Outline {
        statements,
        edges: edges.into_iter().collect(),
    };
    out.layout();
    out
}

#[derive(Default)]
struct Acc {
    ops: Vec<String>,
    reads: Vec<String>,
    model_ops: usize,
    applies: usize,
}

fn walk(expr: &Expr, model_ops: &HashMap<&str, bool>, acc: &mut Acc) {
    match expr {
        Expr::ContextRead(name) => push_unique(&mut acc.reads, name),
        Expr::Quoted {
            content,
            interpolate: true,
        } => {
            for name in interpolated_names(content) {
                push_unique(&mut acc.reads, &name);
            }
        }
        Expr::Message { index, .. } => walk(index, model_ops, acc),
        Expr::MessageRange { start, end, .. } => {
            walk(start, model_ops, acc);
            walk(end, model_ops, acc);
        }
        Expr::Group(inner) | Expr::Quote(inner) | Expr::Serial(inner) => {
            walk(inner, model_ops, acc)
        }
        Expr::FormApply { form, args } => {
            acc.applies += 1;
            walk(form, model_ops, acc);
            for arg in args {
                walk(arg, model_ops, acc);
            }
        }
        Expr::List(items) => items.iter().for_each(|item| walk(item, model_ops, acc)),
        Expr::Assign { value, .. } => walk(value, model_ops, acc),
        Expr::Dict(pairs) => pairs
            .iter()
            .for_each(|(_, value)| walk(value, model_ops, acc)),
        Expr::Apply { op, operands, .. } => {
            push_unique(&mut acc.ops, op);
            if model_ops.get(op.as_str()).copied().unwrap_or(false) {
                acc.model_ops += 1;
            }
            operands
                .iter()
                .for_each(|operand| walk(operand, model_ops, acc));
        }
        _ => {}
    }
}

fn push_unique(list: &mut Vec<String>, item: &str) {
    if !list.iter().any(|x| x == item) {
        list.push(item.to_owned());
    }
}

/// `$name` references interpolated into a double-quoted string.
fn interpolated_names(content: &str) -> Vec<String> {
    let mut names = Vec::new();
    let chars: Vec<char> = content.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        if chars[i] == '\\' {
            i += 2;
            continue;
        }
        if chars[i] == '$' {
            let start = i + 1;
            let mut end = start;
            while end < chars.len() && (chars[end].is_alphanumeric() || chars[end] == '_') {
                end += 1;
            }
            if end > start && !chars[start].is_ascii_digit() {
                names.push(chars[start..end].iter().collect());
            }
            i = end.max(i + 1);
            continue;
        }
        i += 1;
    }
    names
}

fn prelude_names(config: &Config) -> BTreeSet<String> {
    config
        .prelude
        .as_deref()
        .unwrap_or("")
        .split(';')
        .filter_map(|part| {
            let part = part
                .lines()
                .filter(|line| !line.trim_start().starts_with("--"))
                .collect::<Vec<_>>()
                .join(" ");
            let (name, _) = part.split_once('=')?;
            let name = name.trim();
            (!name.is_empty() && name.chars().all(|c| c.is_alphanumeric() || c == '_'))
                .then(|| name.to_owned())
        })
        .collect()
}

/// Collapse a structural render for display: drop one outer paren pair.
fn compact(rendered: &str) -> String {
    let trimmed = rendered.trim();
    let inner = trimmed
        .strip_prefix('(')
        .and_then(|s| s.strip_suffix(')'))
        .filter(|s| balanced(s))
        .unwrap_or(trimmed);
    inner
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .replace(" % ", "%")
        .replace(" . ", ".")
}

fn balanced(s: &str) -> bool {
    let mut depth = 0i32;
    for c in s.chars() {
        match c {
            '(' => depth += 1,
            ')' => {
                depth -= 1;
                if depth < 0 {
                    return false;
                }
            }
            _ => {}
        }
    }
    depth == 0
}

impl Outline {
    /// Total model-realised operator sites in the program.
    #[must_use]
    pub fn model_ops(&self) -> usize {
        self.statements.iter().map(|s| s.model_ops).sum()
    }

    fn preds(&self, i: usize) -> impl Iterator<Item = usize> + '_ {
        self.edges.iter().filter(move |e| e.1 == i).map(|e| e.0)
    }

    /// Layered layout: a statement sits one column right of its furthest
    /// dependency (forward references from form bodies are ignored for layering,
    /// so mutual recursion cannot loop); rows are ordered by the mean row of their
    /// dependencies, two sweeps, to keep edges short and uncrossed.
    fn layout(&mut self) {
        let n = self.statements.len();
        let mut layer = vec![0usize; n];
        for i in 0..n {
            if self.statements[i].kind == Kind::Input {
                continue;
            }
            let deepest = self
                .preds(i)
                .filter(|&p| p < i || self.statements[p].kind == Kind::Input)
                .map(|p| layer[p] + 1)
                .max()
                .unwrap_or(0);
            layer[i] = deepest;
        }
        // Statements with no dependencies sit in column 0 beside the inputs only
        // when something reads them; an isolated final output still goes right.
        let max_layer = layer.iter().copied().max().unwrap_or(0);
        let mut columns: Vec<Vec<usize>> = vec![Vec::new(); max_layer + 1];
        for i in 0..n {
            columns[layer[i]].push(i);
        }
        // Inputs first in column 0, then statements in source order.
        columns[0].sort_by_key(|&i| (self.statements[i].kind != Kind::Input, i));
        let mut row = vec![0f64; n];
        for column in &columns {
            for (r, &i) in column.iter().enumerate() {
                row[i] = r as f64;
            }
        }
        for _ in 0..2 {
            for column in columns.iter_mut().skip(1) {
                let mut keyed: Vec<(f64, usize)> = column
                    .iter()
                    .map(|&i| {
                        let preds: Vec<f64> = self
                            .edges
                            .iter()
                            .filter(|e| e.1 == i && layer[e.0] < layer[i])
                            .map(|e| row[e.0])
                            .collect();
                        let key = if preds.is_empty() {
                            row[i]
                        } else {
                            preds.iter().sum::<f64>() / preds.len() as f64
                        };
                        (key, i)
                    })
                    .collect();
                keyed.sort_by(|a, b| a.0.total_cmp(&b.0).then(a.1.cmp(&b.1)));
                *column = keyed.iter().map(|&(_, i)| i).collect();
                for (r, &i) in column.iter().enumerate() {
                    row[i] = r as f64;
                }
            }
        }
        for (l, column) in columns.iter().enumerate() {
            for (r, &i) in column.iter().enumerate() {
                self.statements[i].layer = l;
                self.statements[i].row = r;
            }
        }
    }

    /// The outline as text: inputs, then one line per statement in source order.
    #[must_use]
    pub fn to_text(&self) -> String {
        let mut out = String::new();
        let inputs: Vec<String> = self
            .statements
            .iter()
            .filter(|s| s.kind == Kind::Input)
            .map(|s| {
                format!(
                    "${} ({})",
                    s.name,
                    s.origin.as_deref().unwrap_or("external")
                )
            })
            .collect();
        if !inputs.is_empty() {
            let _ = writeln!(out, "inputs: {}", inputs.join(", "));
        }
        let width = self
            .statements
            .iter()
            .filter(|s| s.kind != Kind::Input)
            .map(|s| s.name.chars().count())
            .max()
            .unwrap_or(4);
        for (i, s) in self.statements.iter().enumerate() {
            if s.kind == Kind::Input {
                continue;
            }
            let deps: Vec<String> = self
                .edges
                .iter()
                .filter(|e| e.1 == i)
                .map(|e| self.statements[e.0].name.clone())
                .collect();
            let mut meta = vec![s.kind.label().to_owned()];
            if s.model_ops > 0 {
                meta.push(format!("{} model", s.model_ops));
            }
            if s.recursive {
                meta.push("recursive".to_owned());
            }
            if !deps.is_empty() {
                meta.push(format!("reads {}", deps.join(", ")));
            }
            let _ = writeln!(
                out,
                "{:width$}  [{}]  {}",
                s.name,
                meta.join(" · "),
                truncate(&s.source, 100),
                width = width
            );
        }
        out
    }
}

fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        s.to_owned()
    } else {
        let mut t: String = s.chars().take(max - 1).collect();
        t.push('…');
        t
    }
}

fn esc(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

const NODE_W: f64 = 236.0;
const NODE_H: f64 = 74.0;
const COL_GAP: f64 = 70.0;
const ROW_GAP: f64 = 16.0;
const PAD: f64 = 28.0;
const HEADER: f64 = 44.0;

/// Draw the outline as a standalone SVG (graphite palette, like the expression graph).
#[must_use]
pub fn render_svg(outline: &Outline) -> String {
    let columns = outline
        .statements
        .iter()
        .map(|s| s.layer)
        .max()
        .map_or(1, |m| m + 1);
    let rows = outline
        .statements
        .iter()
        .map(|s| s.row)
        .max()
        .map_or(1, |m| m + 1);
    let width = PAD * 2.0 + columns as f64 * NODE_W + (columns.saturating_sub(1)) as f64 * COL_GAP;
    let height =
        HEADER + PAD + rows as f64 * NODE_H + (rows.saturating_sub(1)) as f64 * ROW_GAP + PAD;
    let pos = |s: &Statement| {
        (
            PAD + s.layer as f64 * (NODE_W + COL_GAP),
            HEADER + PAD + s.row as f64 * (NODE_H + ROW_GAP),
        )
    };
    let real = outline
        .statements
        .iter()
        .filter(|s| s.kind != Kind::Input)
        .count();
    let mut svg = String::new();
    let _ = write!(
        svg,
        r##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.0} {height:.0}" width="{width:.0}" height="{height:.0}" font-family="'JetBrains Mono','Fira Code',ui-monospace,monospace">"##
    );
    svg.push_str(r##"<defs><marker id="oa" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="rgba(160,170,190,.7)"/></marker><marker id="ob" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#e0a458"/></marker></defs>"##);
    let _ = write!(
        svg,
        r##"<rect x="1" y="1" width="{:.0}" height="{:.0}" rx="14" fill="#111318" stroke="#262a33"/>"##,
        width - 2.0,
        height - 2.0
    );
    let _ = write!(
        svg,
        r##"<text x="{PAD}" y="30" fill="#c8ccd4" font-size="13" font-weight="600">statement graph</text><text x="{:.0}" y="30" fill="#7d8494" font-size="12">{real} statements · {} model sites · {} edges</text>"##,
        PAD + 150.0,
        outline.model_ops(),
        outline.edges.len()
    );
    // Edges under nodes.
    for &(from, to) in &outline.edges {
        let (a, b) = (&outline.statements[from], &outline.statements[to]);
        let (ax, ay) = pos(a);
        let (bx, by) = pos(b);
        let forward = b.layer > a.layer;
        let (x1, y1, x2, y2) = if forward {
            (ax + NODE_W, ay + NODE_H / 2.0, bx - 4.0, by + NODE_H / 2.0)
        } else {
            // A reference to a later or same-column statement (a form calling a
            // helper defined after it): loop under the nodes.
            (
                ax + NODE_W / 2.0,
                ay + NODE_H,
                bx + NODE_W / 2.0,
                by + NODE_H + 4.0,
            )
        };
        let model = b.model_ops > 0;
        let (stroke, marker) = if model {
            ("rgba(224,164,88,.55)", "ob")
        } else {
            ("rgba(160,170,190,.38)", "oa")
        };
        if forward {
            let dx = (x2 - x1) * 0.5;
            let _ = write!(
                svg,
                r##"<path d="M {x1:.1} {y1:.1} C {:.1} {y1:.1} {:.1} {y2:.1} {x2:.1} {y2:.1}" fill="none" stroke="{stroke}" stroke-width="1.4" marker-end="url(#{marker})"/>"##,
                x1 + dx,
                x2 - dx
            );
        } else {
            let drop = 26.0;
            let _ = write!(
                svg,
                r##"<path d="M {x1:.1} {y1:.1} C {x1:.1} {:.1} {x2:.1} {:.1} {x2:.1} {y2:.1}" fill="none" stroke="{stroke}" stroke-width="1.2" stroke-dasharray="4 4" marker-end="url(#{marker})"/>"##,
                y1 + drop,
                y2 + drop
            );
        }
    }
    for s in &outline.statements {
        let (x, y) = pos(s);
        let (stroke, fill, dash) = match s.kind {
            Kind::Input => ("#4b5263", "#14161c", r#" stroke-dasharray="5 4""#),
            Kind::Form => ("#5f7fb8", "#161b26", ""),
            Kind::Data => ("#6b7280", "#16181e", ""),
            Kind::Value | Kind::Step => ("#7d8494", "#171a21", ""),
            Kind::Output => ("#e0a458", "#1d1a14", ""),
        };
        let stroke = if s.model_ops > 0 && s.kind != Kind::Output {
            "#c8955a"
        } else {
            stroke
        };
        let title = if s.source.is_empty() {
            format!("${}", s.name)
        } else {
            format!("{} = {}", s.name, s.source)
        };
        let _ = write!(
            svg,
            r##"<g data-name="{}"><title>{}</title><rect x="{x:.1}" y="{y:.1}" width="{NODE_W}" height="{NODE_H}" rx="10" fill="{fill}" stroke="{stroke}" stroke-width="1.4"{dash}/>"##,
            esc(&s.name),
            esc(&truncate(&title, 600))
        );
        let shown = if s.kind == Kind::Input {
            format!("${}", s.name)
        } else {
            s.name.clone()
        };
        let _ = write!(
            svg,
            r##"<text x="{:.1}" y="{:.1}" fill="#e6e9ef" font-size="13" font-weight="600">{}</text>"##,
            x + 12.0,
            y + 21.0,
            esc(&truncate(&shown, 24))
        );
        let mut meta = s.kind.label().to_owned();
        if let Some(origin) = &s.origin {
            meta = format!("input · {origin}");
        }
        if s.recursive {
            meta.push_str(" · recursive");
        }
        let _ = write!(
            svg,
            r##"<text x="{:.1}" y="{:.1}" fill="#7d8494" font-size="10.5">{}</text>"##,
            x + 12.0,
            y + 37.0,
            esc(&meta)
        );
        if s.model_ops > 0 {
            let _ = write!(
                svg,
                r##"<rect x="{:.1}" y="{:.1}" width="62" height="18" rx="9" fill="#2a2116" stroke="#c8955a"/><text x="{:.1}" y="{:.1}" fill="#e0a458" font-size="10.5" text-anchor="middle">{} model</text>"##,
                x + NODE_W - 72.0,
                y + 9.0,
                x + NODE_W - 41.0,
                y + 22.0,
                s.model_ops
            );
        }
        if !s.source.is_empty() {
            let line = truncate(&s.source, 34);
            let _ = write!(
                svg,
                r##"<text x="{:.1}" y="{:.1}" fill="#a9b1c3" font-size="10.5">{}</text>"##,
                x + 12.0,
                y + 57.0,
                esc(&line)
            );
        }
        svg.push_str("</g>");
    }
    svg.push_str("</svg>");
    svg
}

#[cfg(test)]
mod tests {
    use super::*;

    fn outline_of(src: &str, bound: &[&str]) -> Outline {
        let cfg: Config =
            serde_yaml::from_str(crate::config::EXAMPLE_CONFIG).expect("example config");
        let sigils = crate::config::operator_sigils(&cfg);
        let tokens = crate::lexer::tokenize(src, &sigils).expect("lex");
        let program = crate::parser::parse_program(&tokens, &cfg.operators).expect("parse");
        let bound: Vec<String> = bound.iter().map(|s| (*s).to_owned()).collect();
        outline(&program, &cfg, &bound)
    }

    fn named<'a>(o: &'a Outline, name: &str) -> (usize, &'a Statement) {
        o.statements
            .iter()
            .enumerate()
            .find(|(_, s)| s.name == name)
            .expect(name)
    }

    #[test]
    fn statements_link_through_reads_including_form_bodies_and_interpolation() {
        let o = outline_of(
            "quote={$sub%($trim%$0,'^','> ')}; render={$join%($quote↦$0.items, \"\\n\")}; \
             tone={$0 :: formal}; notes=\"for $who\"; $render%($tone%$spec)",
            &["spec"],
        );
        let (quote, q) = named(&o, "quote");
        let (render, _) = named(&o, "render");
        let (out, out_s) = named(&o, "out");
        let (spec, s) = named(&o, "spec");
        let (who, w) = named(&o, "who");
        assert_eq!(q.kind, Kind::Form);
        assert_eq!(out_s.kind, Kind::Output);
        assert_eq!((s.kind, s.origin.as_deref()), (Kind::Input, Some("data")));
        assert_eq!(
            w.origin.as_deref(),
            Some("external"),
            "interpolated $who is a read"
        );
        assert!(
            o.edges.contains(&(quote, render)),
            "form body reads become edges"
        );
        assert!(o.edges.contains(&(render, out)));
        assert!(o.edges.contains(&(spec, out)));
        assert!(o.edges.iter().any(|&(f, _)| f == who));
        // Builtins ($sub, $trim, $join) are not inputs.
        assert!(
            o.statements
                .iter()
                .all(|s| !matches!(s.name.as_str(), "sub" | "trim" | "join"))
        );
        // `::` is model-realised; the tone form carries one model site.
        assert_eq!(named(&o, "tone").1.model_ops, 1);
        assert!(named(&o, "render").1.layer > q.layer);
    }

    #[test]
    fn prelude_names_are_inputs_and_recursion_and_forward_refs_resolve() {
        let o = outline_of(
            "walk={$flat%[[$0.id], $flat%({$walk%$0}↦$0.kids)]}; a={$b%$0}; b={$0}; $gist%($a%($walk%$t))",
            &[],
        );
        let (_, walk) = named(&o, "walk");
        assert!(walk.recursive);
        let (a, _) = named(&o, "a");
        let (b, _) = named(&o, "b");
        assert!(
            o.edges.contains(&(b, a)),
            "a form may call a helper defined after it"
        );
        assert_eq!(named(&o, "gist").1.origin.as_deref(), Some("prelude"));
        let text = o.to_text();
        assert!(text.contains("inputs: "), "{text}");
        assert!(text.contains("walk"), "{text}");
        let svg = render_svg(&o);
        assert!(svg.starts_with("<svg") && svg.ends_with("</svg>"));
        assert!(svg.contains("statement graph"));
    }
}
