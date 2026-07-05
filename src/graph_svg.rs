//! Shared SVG renderer for the nlir dataflow graph (graph-viz epic bd-8ac9ad,
//! slice G1). Pure + cross-platform (no native deps) so it compiles into the
//! wasm core and renders the **same** SVG for the CLI/kitty PNG path (G3/G4) and
//! the in-browser DOM panel (G5) — identical graphs everywhere.
//!
//! Layout is a layered dataflow tree: operand edges form the tree (leaves at the
//! bottom, the final operator at the top, data flowing upward), binding edges
//! (`key = …` → each `$key` read) are drawn as dashed teal cross-links on top.
//! Styling is the nlir card aesthetic (deep-violet panel, Fira Code labels, node
//! colours keyed by [`NodeKind`]).

use crate::graph::{EdgeKind, Graph, NodeId, NodeKind};
use std::collections::HashMap;
use std::fmt::Write as _;

const COL_W: f64 = 170.0;
const ROW_H: f64 = 94.0;
const NODE_H: f64 = 42.0;
const PAD: f64 = 30.0;
const FONT: f64 = 13.0;
const CHAR_W: f64 = 7.9;
const MAX_LABEL: usize = 16;

/// Render `graph` to a standalone, self-contained SVG document (card aesthetic).
#[must_use]
pub fn render(graph: &Graph) -> String {
    if graph.nodes.is_empty() {
        return empty_svg();
    }

    // Index nodes and collect operand children (data flows child → parent).
    let index: HashMap<&NodeId, usize> = graph
        .nodes
        .iter()
        .enumerate()
        .map(|(i, n)| (&n.id, i))
        .collect();
    let n = graph.nodes.len();
    let mut op_children: Vec<Vec<usize>> = vec![Vec::new(); n];
    for edge in graph.edges_of(EdgeKind::Operand) {
        if let (Some(&to), Some(&from)) = (index.get(&edge.to), index.get(&edge.from)) {
            op_children[to].push(from);
        }
    }

    // Layer (leaves = 0, parent = 1 + max child layer) and x-slot (leaves take
    // sequential slots, parents centre over their children). Nodes are in eval
    // order (children before parents), so a single forward pass suffices.
    let mut layer = vec![0usize; n];
    let mut slot = vec![0.0f64; n];
    let mut next = 0.0f64;
    for i in 0..n {
        if op_children[i].is_empty() {
            slot[i] = next;
            next += 1.0;
        } else {
            layer[i] = op_children[i]
                .iter()
                .map(|&c| layer[c] + 1)
                .max()
                .unwrap_or(0);
            let sum: f64 = op_children[i].iter().map(|&c| slot[c]).sum();
            slot[i] = sum / op_children[i].len() as f64;
        }
    }
    let max_layer = layer.iter().copied().max().unwrap_or(0);
    let leaves = next.max(1.0);

    // Pixel geometry.
    let width = PAD * 2.0 + leaves * COL_W;
    let height = PAD * 2.0 + NODE_H + max_layer as f64 * ROW_H;
    let cx = |i: usize| PAD + COL_W / 2.0 + slot[i] * COL_W;
    let cy = |i: usize| PAD + NODE_H / 2.0 + (max_layer - layer[i]) as f64 * ROW_H;
    let node_w = |i: usize| {
        let len = fit(&graph.nodes[i].label).chars().count() as f64;
        (len * CHAR_W + 22.0).clamp(46.0, COL_W - 14.0)
    };

    let mut svg = String::new();
    let _ = write!(
        svg,
        r##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.0} {height:.0}" font-family="'Fira Code',ui-monospace,monospace" font-size="{FONT}">"##,
    );
    svg.push_str(DEFS);
    let _ = write!(
        svg,
        r##"<rect x="1" y="1" width="{:.0}" height="{:.0}" rx="18" fill="#100a24" stroke="rgba(168,85,247,.28)"/>"##,
        width - 2.0,
        height - 2.0,
    );

    // Operand edges (solid) then binding edges (dashed teal), under the nodes.
    for edge in graph.edges_of(EdgeKind::Operand) {
        if let (Some(&f), Some(&t)) = (index.get(&edge.from), index.get(&edge.to)) {
            let _ = write!(
                svg,
                r##"<line x1="{:.1}" y1="{:.1}" x2="{:.1}" y2="{:.1}" stroke="rgba(168,85,247,.5)" stroke-width="1.6" marker-end="url(#op)"/>"##,
                cx(f),
                cy(f) - NODE_H / 2.0,
                cx(t),
                cy(t) + NODE_H / 2.0 + 3.0,
            );
        }
    }
    for edge in graph.edges_of(EdgeKind::Binding) {
        if let (Some(&f), Some(&t)) = (index.get(&edge.from), index.get(&edge.to)) {
            let (x1, y1, x2, y2) = (cx(f), cy(f), cx(t), cy(t));
            let bow = ((x2 - x1).abs() * 0.3 + 40.0).min(120.0);
            let _ = write!(
                svg,
                r##"<path d="M {x1:.1} {y1:.1} C {:.1} {:.1} {:.1} {:.1} {x2:.1} {y2:.1}" fill="none" stroke="#7dd3fc" stroke-width="1.4" stroke-dasharray="4 3" opacity=".85" marker-end="url(#bind)"/>"##,
                x1 + bow,
                y1,
                x2 + bow,
                y2,
            );
        }
    }

    // Nodes: each wrapped in a `<g data-id="<dotted NodeId>">` so a panel can
    // target/highlight a node by identity — G5 animation keys on this together
    // with G2's `reduced` NodeId to light up the just-reduced node per frame.
    for (i, node) in graph.nodes.iter().enumerate() {
        let (fill, stroke, text) = palette(&node.kind);
        let w = node_w(i);
        let (x, y) = (cx(i) - w / 2.0, cy(i) - NODE_H / 2.0);
        let _ = write!(
            svg,
            r##"<g data-id="{}"><rect x="{x:.1}" y="{y:.1}" width="{w:.1}" height="{NODE_H}" rx="10" fill="{fill}" stroke="{stroke}" stroke-width="1.3"/><text x="{:.1}" y="{:.1}" fill="{text}" text-anchor="middle" dominant-baseline="central">{}</text></g>"##,
            node.id.dotted(),
            cx(i),
            cy(i),
            esc(&fit(&node.label)),
        );
    }
    svg.push_str("</svg>");
    svg
}

/// The SVG `<defs>` (arrow markers for operand + binding edges).
const DEFS: &str = concat!(
    r##"<defs>"##,
    r##"<marker id="op" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="rgba(168,85,247,.7)"/></marker>"##,
    r##"<marker id="bind" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#7dd3fc"/></marker>"##,
    r##"</defs>"##,
);

/// An empty-graph placeholder SVG.
fn empty_svg() -> String {
    r##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 60"><rect width="240" height="60" rx="12" fill="#100a24" stroke="rgba(168,85,247,.28)"/><text x="120" y="34" fill="#8b7bbf" text-anchor="middle" font-family="'Fira Code',monospace" font-size="13">(empty)</text></svg>"##.to_owned()
}

/// Node fill/stroke/text colours keyed by [`NodeKind`] (card aesthetic).
fn palette(kind: &NodeKind) -> (&'static str, &'static str, &'static str) {
    match kind {
        NodeKind::Apply(_) => ("#241a45", "#a855f7", "#e879f9"),
        NodeKind::FormApply => ("#241a45", "#a855f7", "#e879f9"),
        NodeKind::Assign(_) | NodeKind::ContextRead(_) => ("#2c2210", "#e0b23a", "#fde68a"),
        NodeKind::Message => ("#0e2420", "#34d399", "#a7f3d0"),
        NodeKind::Number => ("#1c0f2a", "#6a3a5a", "#fca5a5"),
        NodeKind::Quoted => ("#0e1a26", "#3a6a8a", "#7dd3fc"),
        NodeKind::Quote => ("#181233", "#8b5cf6", "#c4b5fd"),
        NodeKind::Bare => ("#170f2c", "#4a3a6a", "#cbb9f5"),
        NodeKind::Value => ("#0e2414", "#4ade80", "#86efac"),
        NodeKind::StackPeek | NodeKind::StackIndex(_) => ("#1a1030", "#8b5cf6", "#c4b5fd"),
        NodeKind::List | NodeKind::Group | NodeKind::Serial => ("#16112e", "#4a3a6a", "#b9a8e6"),
    }
}

/// Char-ellipsise a (word-truncated) label so a node box stays compact.
fn fit(label: &str) -> String {
    let chars: Vec<char> = label.chars().collect();
    if chars.len() <= MAX_LABEL {
        return label.to_owned();
    }
    let head: String = chars[..MAX_LABEL.saturating_sub(1)].iter().collect();
    format!("{head}…")
}

/// Minimal XML text escaping for labels.
fn esc(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::graph::Graph;
    use crate::{config, lexer, parser};

    fn graph(src: &str) -> Graph {
        let cfg = config::parse_str(
            config::EXAMPLE_CONFIG,
            std::path::Path::new("config.example.yaml"),
        )
        .expect("config");
        let sigils = config::operator_sigils(&cfg);
        let tokens = lexer::tokenize(src, &sigils).expect("tokenize");
        let program = parser::parse_program(&tokens, &cfg.operators).expect("parse");
        Graph::from_program(&program)
    }

    #[test]
    fn renders_wellformed_svg() {
        let svg = render(&graph("2**3**2"));
        assert!(svg.starts_with("<svg"));
        assert!(svg.ends_with("</svg>"));
        assert!(svg.contains("viewBox"));
        // Two ** ops + three leaves = 5 node rects (plus the 1 background rect).
        assert_eq!(svg.matches("<rect").count(), 6);
        // Four operand edges, no binding edges.
        assert_eq!(svg.matches("marker-end=\"url(#op)\"").count(), 4);
        assert_eq!(svg.matches("marker-end=\"url(#bind)\"").count(), 0);
    }

    #[test]
    fn binding_edges_render_dashed() {
        let svg = render(&graph("k='x';[$k,~$k]"));
        // Two binding edges (Assign(k) → both $k reads).
        assert_eq!(svg.matches("marker-end=\"url(#bind)\"").count(), 2);
        assert!(svg.contains("stroke-dasharray"));
    }

    #[test]
    fn nodes_carry_stable_data_id() {
        // Each node group is tagged with its dotted NodeId so a panel can
        // highlight by identity (G5 + G2 `reduced`).
        let svg = render(&graph("2**3**2"));
        assert!(svg.contains(r#"<g data-id="0">"#), "root node id 0");
        assert!(svg.contains(r#"<g data-id="0.1">"#), "inner ** id 0.1");
    }

    #[test]
    fn empty_graph_is_placeholder() {
        let svg = render(&Graph::default());
        assert!(svg.contains("(empty)"));
        assert!(svg.starts_with("<svg"));
    }

    #[test]
    fn labels_are_escaped() {
        // '<' shorten op sigil must be XML-escaped in the label.
        let svg = render(&graph("<'hello world this is'"));
        assert!(!svg.contains("><'"));
        assert!(svg.contains("&lt;"));
    }
}
