//! TikZ renderings of nlir programs, for papers and reports (vector, typeset in the
//! document's own fonts).
//!
//! - [`outline_tikz`]: the statement graph (`nlir show --statements --tikz`) as a
//!   positioned `tikzpicture` — one node per statement, edges for the names read,
//!   model-call sites marked.
//! - [`graph_forest`]: each statement's expression tree (`nlir show --tikz`) as a
//!   `forest` tree, model-realised operators highlighted — for decomposing one
//!   statement (a part writer, a form body) into its operations.
//!
//! Colours are `\providecolor` names (`nlirform`, `nlirdata`, `nlirvalue`,
//! `nliroutput`, `nlirinput`, `nlirmodel`, `nliredge`), so a document can restyle
//! every figure at once. Requires `tikz` (and `forest` for expression trees).

use crate::graph::{EdgeKind, Graph, NodeKind};
use crate::outline::{Kind, Outline};
use std::collections::{HashMap, HashSet};
use std::fmt::Write as _;

/// LaTeX-escape text for use inside a node.
#[must_use]
pub fn tex(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\textbackslash{}"),
            '{' => out.push_str("\\{"),
            '}' => out.push_str("\\}"),
            '#' | '$' | '%' | '&' | '_' => {
                out.push('\\');
                out.push(c);
            }
            '~' => out.push_str("\\textasciitilde{}"),
            '^' => out.push_str("\\textasciicircum{}"),
            '\n' => out.push_str("\\textbackslash{}n"),
            '[' => out.push_str("{[}"),
            ']' => out.push_str("{]}"),
            _ => out.push(c),
        }
    }
    out
}

fn clip(s: &str, max: usize) -> String {
    let chars: Vec<char> = s.chars().collect();
    if chars.len() <= max {
        s.to_owned()
    } else {
        let mut t: String = chars[..max.saturating_sub(1)].iter().collect();
        t.push('…');
        t
    }
}

const PALETTE: &str = r"\providecolor{nlirform}{HTML}{5E81AC}
\providecolor{nlirdata}{HTML}{4C566A}
\providecolor{nlirvalue}{HTML}{4C566A}
\providecolor{nliroutput}{HTML}{B5762B}
\providecolor{nlirinput}{HTML}{81A1C1}
\providecolor{nlirmodel}{HTML}{C8892E}
\providecolor{nliredge}{HTML}{7B8394}
";

/// The statement graph as a positioned `tikzpicture` (with `\providecolor` lines).
#[must_use]
pub fn outline_tikz(outline: &Outline) -> String {
    const DX: f64 = 5.4; // cm between columns
    const DY: f64 = 2.05; // cm between rows
    let mut out = String::from(PALETTE);
    out.push_str("\\begin{tikzpicture}[\n");
    out.push_str("  stmt/.style={draw=#1, line width=0.7pt, rounded corners=3pt, fill=#1!6, text width=4.5cm, minimum height=1.45cm, inner sep=4pt, align=left, anchor=north west, font=\\small},\n");
    out.push_str("  input/.style={stmt=nlirinput, dashed, fill=white},\n");
    out.push_str("  flow/.style={-{Stealth[length=2mm]}, line width=0.6pt, draw=nliredge},\n");
    out.push_str("  modelflow/.style={flow, draw=nlirmodel},\n");
    out.push_str("  backref/.style={flow, dashed},\n");
    out.push_str("  badge/.style={draw=nlirmodel, fill=nlirmodel!12, text=nlirmodel!80!black, rounded corners=5pt, inner sep=1.5pt, font=\\scriptsize\\sffamily}]\n");
    for (i, s) in outline.statements.iter().enumerate() {
        let x = s.layer as f64 * DX;
        let y = -(s.row as f64) * DY;
        let colour = match s.kind {
            Kind::Input => "nlirinput",
            Kind::Form => "nlirform",
            Kind::Data => "nlirdata",
            Kind::Value | Kind::Step => "nlirvalue",
            Kind::Output => "nliroutput",
        };
        let style = if s.kind == Kind::Input {
            "input".to_owned()
        } else {
            format!("stmt={colour}")
        };
        let title = if s.kind == Kind::Input {
            format!("\\${}", tex(&s.name))
        } else {
            tex(&s.name)
        };
        let mut meta = match (&s.kind, &s.origin) {
            (Kind::Input, Some(origin)) => format!("input · {origin}"),
            (kind, _) => format!("{kind:?}").to_lowercase(),
        };
        if s.recursive {
            meta.push_str(" · recursive");
        }
        let body = if s.source.is_empty() {
            String::new()
        } else {
            format!(
                "\\\\[1pt]{{\\ttfamily\\scriptsize {}}}",
                tex(&clip(&s.source, 46))
            )
        };
        let _ = writeln!(
            out,
            "  \\node[{style}] (s{i}) at ({x:.2},{y:.2}) {{\\textbf{{{title}}}\\\\{{\\scriptsize\\color{{black!60}}{}}}{body}}};",
            tex(&meta)
        );
        if s.model_ops > 0 {
            let _ = writeln!(
                out,
                "  \\node[badge, anchor=north east] at ($(s{i}.north east)+(-0.08,-0.08)$) {{{} model}};",
                s.model_ops
            );
        }
    }
    for &(from, to) in &outline.edges {
        let (a, b) = (&outline.statements[from], &outline.statements[to]);
        let style = if b.model_ops > 0 { "modelflow" } else { "flow" };
        if b.layer > a.layer {
            let _ = writeln!(
                out,
                "  \\draw[{style}] (s{from}.east) to[out=0, in=180] (s{to}.west);"
            );
        } else {
            let _ = writeln!(
                out,
                "  \\draw[backref] (s{from}.south) to[out=-90, in=-90, looseness=0.6] (s{to}.south);"
            );
        }
    }
    out.push_str("\\end{tikzpicture}\n");
    out
}

/// Each top-level statement's expression tree as a `forest` tree (with `\providecolor`
/// lines). `model_ops` are the operator sigils realised by a model.
#[must_use]
pub fn graph_forest(graph: &Graph, model_ops: &HashSet<String>) -> String {
    let index: HashMap<_, usize> = graph
        .nodes
        .iter()
        .enumerate()
        .map(|(i, n)| (&n.id, i))
        .collect();
    let mut children: Vec<Vec<usize>> = vec![Vec::new(); graph.nodes.len()];
    let mut has_parent = vec![false; graph.nodes.len()];
    for edge in graph.edges.iter().filter(|e| e.kind == EdgeKind::Operand) {
        if let (Some(&to), Some(&from)) = (index.get(&edge.to), index.get(&edge.from)) {
            children[to].push(from);
            has_parent[from] = true;
        }
    }
    fn node(
        graph: &Graph,
        children: &[Vec<usize>],
        model_ops: &HashSet<String>,
        i: usize,
        out: &mut String,
    ) {
        let n = &graph.nodes[i];
        let (label, style) = match &n.kind {
            NodeKind::Apply(op) if model_ops.contains(op) => (tex(op), "model"),
            NodeKind::Apply(op) => (tex(op), "op"),
            NodeKind::FormApply => ("\\%".to_owned(), "op"),
            NodeKind::Assign(k) => (format!("{} =", tex(k)), "bind"),
            NodeKind::ContextRead(k) => (format!("\\${}", tex(k)), "read"),
            NodeKind::Quoted => {
                let inner = n.label.trim_matches(|c| c == '\'' || c == '"');
                (format!("``{}''", tex(&clip(inner, 34))), "lit")
            }
            NodeKind::Quote => (format!("\\{{{}\\}}", tex(&clip(&n.label, 30))), "form"),
            _ => (tex(&clip(&n.label, 30)), "lit"),
        };
        let _ = write!(out, "[{{{label}}}, {style}");
        for &c in &children[i] {
            out.push(' ');
            node(graph, children, model_ops, c, out);
        }
        out.push(']');
    }
    let mut out = String::from(PALETTE);
    for (i, _) in graph
        .nodes
        .iter()
        .enumerate()
        .filter(|(i, _)| !has_parent[*i])
    {
        out.push_str("\\begin{forest}\n  for tree={draw=nliredge, rounded corners=2pt, font=\\ttfamily\\scriptsize, inner sep=2.5pt, l sep=3.5mm, s sep=1.6mm, edge={nliredge, line width=0.5pt}, parent anchor=south, child anchor=north},\n");
        out.push_str("  model/.style={draw=nlirmodel, fill=nlirmodel!14, line width=0.8pt},\n  op/.style={fill=black!4},\n  bind/.style={draw=nlirform, fill=nlirform!8},\n  read/.style={draw=nlirinput, fill=nlirinput!8},\n  form/.style={draw=nlirform, dashed},\n  lit/.style={draw=black!25}\n  ");
        node(graph, &children, model_ops, i, &mut out);
        out.push_str("\n\\end{forest}\n");
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn program(src: &str) -> (crate::parser::Program, crate::config::Config) {
        let cfg: crate::config::Config =
            serde_yaml::from_str(crate::config::EXAMPLE_CONFIG).expect("config");
        let sigils = crate::config::operator_sigils(&cfg);
        let tokens = crate::lexer::tokenize(src, &sigils).expect("lex");
        (
            crate::parser::parse_program(&tokens, &cfg.operators).expect("parse"),
            cfg,
        )
    }

    #[test]
    fn escapes_latex_specials() {
        assert_eq!(
            tex("$p.id_1 & 50% {x} #a ~^\\"),
            "\\$p.id\\_1 \\& 50\\% \\{x\\} \\#a \\textasciitilde{}\\textasciicircum{}\\textbackslash{}"
        );
        assert_eq!(tex("[a]"), "{[}a{]}");
    }

    #[test]
    fn outline_and_forest_render_balanced_tikz() {
        let (prog, cfg) = program(
            "guide='Write: ' ++ $json%$p; parts=[=>($guide ++ 'MET'), =>($guide ++ 'NOT MET')]; $render%{a=$parts.0}",
        );
        let o = crate::outline::outline(&prog, &cfg, &["p".to_owned()]);
        let t = outline_tikz(&o);
        assert!(t.contains("\\begin{tikzpicture}") && t.trim_end().ends_with("\\end{tikzpicture}"));
        assert!(t.contains("2 model"), "{t}");
        assert_eq!(
            t.matches('{').count(),
            t.matches('}').count(),
            "balanced braces:\n{t}"
        );
        let model: HashSet<String> = cfg
            .operators
            .values()
            .filter(|o| !o.is_deterministic())
            .map(|o| o.op.clone())
            .collect();
        let f = graph_forest(&crate::graph::Graph::from_program(&prog), &model);
        assert_eq!(
            f.matches("\\begin{forest}").count(),
            3,
            "one tree per statement"
        );
        assert!(f.contains("{=>}, model"), "{f}");
        assert_eq!(
            f.matches('[').count(),
            f.matches(']').count(),
            "balanced brackets:\n{f}"
        );
    }
}
