//! Dataflow graph model for an nlir expression (graph-viz epic bd-8ac9ad, slice
//! G0 — the keystone). Walks a parsed [`crate::parser::Expr`] / [`Program`] into
//! a [`Graph`] of [`Node`]s + [`Edge`]s with:
//!
//! - **operand edges** — every child sub-expression feeds its parent (data flows
//!   operand → op), so the graph reads as a dataflow, not a bare syntax tree;
//! - **binding-reference edges** — every `key = …` assignment feeds each
//!   `$key` read that consumes it (references resolved, last-assignment-wins by
//!   eval order), which is the "resolve circularity/references" ask.
//!
//! Node identity is a stable PATH from the program root (statement index, then
//! child positions), so step frames (G2) can keep a consistent layout as
//! subtrees reduce to [`crate::parser::Expr::Value`] — a node keeps its path even
//! as its subtree collapses.
//!
//! Pure + cross-platform (no native deps) so it compiles into the wasm core.
//! This is the shared substrate G1 (SVG), G3 (CLI) and G5 (wasm) all render from.

use crate::parser::{Expr, Program};
use std::collections::HashMap;

/// A stable identity for a graph node: the path from the program root to the AST
/// node — the statement index, then a child position at each level. Stable
/// across step-frame reductions because a node keeps its path even as its
/// subtree collapses to a [`crate::parser::Expr::Value`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct NodeId(pub Vec<usize>);

impl NodeId {
    /// The root path for statement `index`.
    #[must_use]
    pub fn root(index: usize) -> Self {
        Self(vec![index])
    }

    /// The path of this node's `i`-th child.
    #[must_use]
    pub fn child(&self, i: usize) -> Self {
        let mut path = self.0.clone();
        path.push(i);
        Self(path)
    }

    /// A dotted rendering (`"0.1.2"`) for labels, tests and stable keys.
    #[must_use]
    pub fn dotted(&self) -> String {
        self.0
            .iter()
            .map(usize::to_string)
            .collect::<Vec<_>>()
            .join(".")
    }
}

/// What an AST node is — drives the shape/colour a renderer picks. Carries just
/// enough payload for a label (the op sigil, the bound key, the read name).
#[derive(Debug, Clone, PartialEq)]
pub enum NodeKind {
    /// An operator application; the sigil (`~`, `&`, `**`, …).
    Apply(String),
    /// A `key = …` assignment; the bound key.
    Assign(String),
    /// A `$name` context read; the name.
    ContextRead(String),
    /// `$` — peek the stack top.
    StackPeek,
    /// `$N` / `$-N` — index the stack.
    StackIndex(i64),
    /// A `^`/`^_`/`^*`/`^/` message index or `M^N` range (label carries the sigil).
    Message,
    /// A `[a, b, …]` list literal.
    List,
    /// A `( … )` group.
    Group,
    /// A `` ` `` forced-serial subtree.
    Serial,
    /// A bare literal.
    Bare,
    /// A numeric literal.
    Number,
    /// A quoted literal.
    Quoted,
    /// A `{…}` quoted form (bd-5dd86f): opaque data (a `Value::Form`), a leaf —
    /// its inner AST does not flow in the dataflow graph until applied.
    Quote,
    /// Form application `form % args` (bd-5dd86f): the form + args flow in.
    FormApply,
    /// A reduced value spliced in by the small-step evaluator (step frames, G2).
    Value,
}

/// A graph node: a stable [`NodeId`], its [`NodeKind`], and a display `label`
/// (already truncated via [`truncate_ends`] for long text).
#[derive(Debug, Clone, PartialEq)]
pub struct Node {
    /// Stable path identity.
    pub id: NodeId,
    /// What this node is.
    pub kind: NodeKind,
    /// Display label (truncated).
    pub label: String,
}

/// Why an edge exists. `from` produces data consumed by `to`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EdgeKind {
    /// A child sub-expression feeding its parent (operand → op).
    Operand,
    /// A `key = …` assignment feeding a `$key` read (assign → read).
    Binding,
}

/// A directed dataflow edge: data flows `from` → `to`.
#[derive(Debug, Clone, PartialEq)]
pub struct Edge {
    /// The producing node.
    pub from: NodeId,
    /// The consuming node.
    pub to: NodeId,
    /// Operand vs binding.
    pub kind: EdgeKind,
}

/// The dataflow graph of an nlir program: nodes (one per AST position) + edges
/// (operand + binding). Nodes are in eval order (children before parents).
#[derive(Debug, Clone, PartialEq, Default)]
pub struct Graph {
    /// All nodes, in eval order.
    pub nodes: Vec<Node>,
    /// All edges (operand + binding).
    pub edges: Vec<Edge>,
}

impl Graph {
    /// Build the dataflow graph of a whole [`Program`] (bindings resolve across
    /// `;`-separated statements, last-assignment-wins by eval order).
    #[must_use]
    pub fn from_program(program: &Program) -> Self {
        Self::from_statements(&program.statements)
    }

    /// Build the dataflow graph of a slice of statements — the form step frames
    /// (G2) rebuild from as the tree reduces (bindings resolve across the slice).
    #[must_use]
    pub fn from_statements(statements: &[Expr]) -> Self {
        let mut builder = Builder::default();
        for (index, statement) in statements.iter().enumerate() {
            builder.walk(statement, &NodeId::root(index));
        }
        Graph {
            nodes: builder.nodes,
            edges: builder.edges,
        }
    }

    /// Build the dataflow graph of a single [`Expr`] (statement `0`) — the entry
    /// step frames (G2) rebuild from as the tree reduces.
    #[must_use]
    pub fn from_expr(expr: &Expr) -> Self {
        let mut builder = Builder::default();
        builder.walk(expr, &NodeId::root(0));
        Graph {
            nodes: builder.nodes,
            edges: builder.edges,
        }
    }

    /// The node with `id`, if present.
    #[must_use]
    pub fn node(&self, id: &NodeId) -> Option<&Node> {
        self.nodes.iter().find(|node| &node.id == id)
    }

    /// The edges of a given [`EdgeKind`].
    pub fn edges_of(&self, kind: EdgeKind) -> impl Iterator<Item = &Edge> {
        self.edges.iter().filter(move |edge| edge.kind == kind)
    }

    /// This graph's binding edges (Assign → ContextRead), cloned. Step frames
    /// (G2) carry the ORIGINAL binding set: as an `Assign` reduces to a `Value`
    /// its key is lost, so the edges are re-applied per frame while their target
    /// read is still un-reduced (see [`Graph::frame`]).
    #[must_use]
    pub fn binding_edges(&self) -> Vec<Edge> {
        self.edges_of(EdgeKind::Binding).cloned().collect()
    }

    /// Build the frame graph for a partially-reduced `statements` slice (G2):
    /// nodes + operand edges from the CURRENT structure, but binding edges taken
    /// from `original_bindings` (stable [`NodeId`]s) and kept only while the
    /// target read is still an un-reduced [`NodeKind::ContextRead`] — so a
    /// variable visibly feeds its uses "until consumed", even after the
    /// assignment itself has collapsed to a `Value`.
    #[must_use]
    pub fn frame(statements: &[Expr], original_bindings: &[Edge]) -> Self {
        let mut graph = Graph::from_statements(statements);
        graph.edges.retain(|edge| edge.kind != EdgeKind::Binding);
        for edge in original_bindings {
            let target_is_unreduced_read = graph
                .node(&edge.to)
                .is_some_and(|node| matches!(node.kind, NodeKind::ContextRead(_)));
            if target_is_unreduced_read && graph.node(&edge.from).is_some() {
                graph.edges.push(edge.clone());
            }
        }
        graph
    }
}

/// One frame of a step-through animation (graph-viz G2, bd-c1710c): the dataflow
/// graph of the current partially-reduced program, plus the node that just
/// reduced to produce it (`None` for the initial frame). G4 (kitty) and G5
/// (wasm) render each frame via `graph_svg::render(&frame.graph)`; `reduced`
/// drives the just-reduced-node highlight / caption.
#[derive(Debug, Clone, PartialEq)]
pub struct Frame {
    /// The graph of the current reduction state.
    pub graph: Graph,
    /// The node that reduced to produce this frame (`None` = initial frame).
    pub reduced: Option<NodeId>,
}

/// The node that reduced between two consecutive frames: the id that is a
/// [`NodeKind::Value`] in `after` but was a non-Value node in `before` (its
/// redex collapsed). A small step reduces exactly one redex, so at most one such
/// node exists.
#[must_use]
pub fn reduced_between(before: &Graph, after: &Graph) -> Option<NodeId> {
    after
        .nodes
        .iter()
        .filter(|node| node.kind == NodeKind::Value)
        .map(|node| node.id.clone())
        .find(|id| before.node(id).is_some_and(|b| b.kind != NodeKind::Value))
}

/// Accumulates nodes/edges while walking, tracking the live binding scope
/// (`key` → the id of the most-recent [`Expr::Assign`] node for it, in eval
/// order).
#[derive(Default)]
struct Builder {
    nodes: Vec<Node>,
    edges: Vec<Edge>,
    scope: HashMap<String, NodeId>,
}

/// Default head/tail word budgets for node labels (long literals + model-output
/// Values render as "first few words … last few words").
const LABEL_HEAD_WORDS: usize = 6;
const LABEL_TAIL_WORDS: usize = 4;

impl Builder {
    /// Walk `expr` at `path` in EVAL ORDER (children first, then the node), so a
    /// `$key` read resolves against the most-recent prior assignment and a node
    /// is added after the subtree it consumes.
    fn walk(&mut self, expr: &Expr, path: &NodeId) {
        match expr {
            Expr::Apply { op, operands, .. } => {
                self.walk_children(operands, path);
                self.push(path, NodeKind::Apply(op.clone()), op.clone());
            }
            Expr::FormApply { form, args } => {
                // The form (child 0) + each arg (children 1..) flow into the
                // application node (operand edges) — bd-5dd86f.
                let form_child = path.child(0);
                self.walk(form, &form_child);
                let arg_children: Vec<NodeId> = args
                    .iter()
                    .enumerate()
                    .map(|(i, arg)| {
                        let child = path.child(i + 1);
                        self.walk(arg, &child);
                        child
                    })
                    .collect();
                self.push(path, NodeKind::FormApply, "%".to_owned());
                self.edge(&form_child, path, EdgeKind::Operand);
                for child in &arg_children {
                    self.edge(child, path, EdgeKind::Operand);
                }
            }
            Expr::Assign { key, value } => {
                let child = path.child(0);
                self.walk(value, &child);
                self.push(path, NodeKind::Assign(key.clone()), format!("{key} ="));
                self.edge(&child, path, EdgeKind::Operand);
                // Record the binding AFTER its RHS (eval order); last write wins.
                self.scope.insert(key.clone(), path.clone());
            }
            Expr::ContextRead(name) => {
                self.push(
                    path,
                    NodeKind::ContextRead(name.clone()),
                    format!("${name}"),
                );
                if let Some(source) = self.scope.get(name) {
                    self.edges.push(Edge {
                        from: source.clone(),
                        to: path.clone(),
                        kind: EdgeKind::Binding,
                    });
                }
            }
            Expr::List(items) => {
                self.walk_children(items, path);
                self.push(path, NodeKind::List, "[ ]".to_owned());
            }
            Expr::Dict(pairs) => {
                let values: Vec<Expr> = pairs.iter().map(|(_, v)| v.clone()).collect();
                self.walk_children(&values, path);
                self.push(path, NodeKind::List, "{ }".to_owned());
            }
            Expr::Group(inner) => {
                let child = path.child(0);
                self.walk(inner, &child);
                self.push(path, NodeKind::Group, "( )".to_owned());
                self.edge(&child, path, EdgeKind::Operand);
            }
            Expr::Serial(inner) => {
                let child = path.child(0);
                self.walk(inner, &child);
                self.push(path, NodeKind::Serial, "`".to_owned());
                self.edge(&child, path, EdgeKind::Operand);
            }
            Expr::Message { role, index } => {
                let child = path.child(0);
                self.walk(index, &child);
                self.push(path, NodeKind::Message, format!("^{}", role.suffix()));
                self.edge(&child, path, EdgeKind::Operand);
            }
            Expr::MessageRange { role, start, end } => {
                let (c0, c1) = (path.child(0), path.child(1));
                self.walk(start, &c0);
                self.walk(end, &c1);
                self.push(path, NodeKind::Message, format!("^{}…^", role.suffix()));
                self.edge(&c0, path, EdgeKind::Operand);
                self.edge(&c1, path, EdgeKind::Operand);
            }
            Expr::StackPeek => self.push(path, NodeKind::StackPeek, "$".to_owned()),
            Expr::StackIndex(n) => self.push(path, NodeKind::StackIndex(*n), format!("${n}")),
            Expr::Bare(text) => {
                self.push(
                    path,
                    NodeKind::Bare,
                    truncate_ends(text, LABEL_HEAD_WORDS, LABEL_TAIL_WORDS),
                );
            }
            Expr::Number(n) => self.push(path, NodeKind::Number, render_number(*n)),
            Expr::Quoted { content, .. } => {
                let label = truncate_ends(content, LABEL_HEAD_WORDS, LABEL_TAIL_WORDS);
                self.push(path, NodeKind::Quoted, format!("'{label}'"));
            }
            Expr::Quote(inner) => {
                // A quoted form is opaque data (its inner is NOT evaluated), so
                // it renders as a single leaf labelled with the form source — no
                // operand edges into it (bd-5dd86f).
                let label = truncate_ends(&inner.render(), LABEL_HEAD_WORDS, LABEL_TAIL_WORDS);
                self.push(path, NodeKind::Quote, format!("{{{label}}}"));
            }
            Expr::Value(value) => {
                let label = truncate_ends(&value.to_string(), LABEL_HEAD_WORDS, LABEL_TAIL_WORDS);
                self.push(path, NodeKind::Value, label);
            }
        }
    }

    /// Walk each of `children` at `path.child(i)` and add an operand edge from it
    /// to `path` (data flows child → parent).
    fn walk_children(&mut self, children: &[Expr], path: &NodeId) {
        for (i, child_expr) in children.iter().enumerate() {
            let child = path.child(i);
            self.walk(child_expr, &child);
            self.edge(&child, path, EdgeKind::Operand);
        }
    }

    /// Add a node.
    fn push(&mut self, path: &NodeId, kind: NodeKind, label: String) {
        self.nodes.push(Node {
            id: path.clone(),
            kind,
            label,
        });
    }

    /// Add an edge `from` → `to`.
    fn edge(&mut self, from: &NodeId, to: &NodeId, kind: EdgeKind) {
        self.edges.push(Edge {
            from: from.clone(),
            to: to.clone(),
            kind,
        });
    }
}

/// Render a float label the way the reader expects: integral values without a
/// fractional part, otherwise the shortest round-tripping form.
fn render_number(n: f64) -> String {
    if n.fract() == 0.0 && n.is_finite() {
        format!("{n:.0}")
    } else {
        let mut s = format!("{n}");
        if s.is_empty() {
            s.push('0');
        }
        s
    }
}

/// Truncate `s` to `"first HEAD words … last TAIL words"` when it has more than
/// `head_words + tail_words` whitespace-separated words; otherwise return it
/// unchanged (trimmed). Keeps long literals and model-output Values rendering
/// consistently across a diagram. Shared by every renderer.
#[must_use]
pub fn truncate_ends(s: &str, head_words: usize, tail_words: usize) -> String {
    let words: Vec<&str> = s.split_whitespace().collect();
    if words.len() <= head_words + tail_words || head_words + tail_words == 0 {
        return s.trim().to_owned();
    }
    let head = words[..head_words].join(" ");
    let tail = words[words.len() - tail_words..].join(" ");
    format!("{head} … {tail}")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{lexer, parser};

    /// Parse `src` to a program using the shipped example operator set.
    fn program(src: &str) -> parser::Program {
        let config = crate::config::parse_str(
            crate::config::EXAMPLE_CONFIG,
            std::path::Path::new("config.example.yaml"),
        )
        .expect("example config");
        let sigils = crate::config::operator_sigils(&config);
        let tokens = lexer::tokenize(src, &sigils).expect("tokenize");
        parser::parse_program(&tokens, &config.operators).expect("parse")
    }

    fn graph(src: &str) -> Graph {
        Graph::from_program(&program(src))
    }

    #[test]
    fn operand_edges_follow_nesting_for_right_assoc_pow() {
        // 2**3**2 = 2**(3**2): outer ** has operands {2, inner **}; inner ** has
        // operands {3, 2}. Four operand edges, no bindings.
        let g = graph("2**3**2");
        assert_eq!(g.edges_of(EdgeKind::Operand).count(), 4);
        assert_eq!(g.edges_of(EdgeKind::Binding).count(), 0);
        // Two Apply(**) nodes + three numeric leaves. Note: a plain integer
        // like `2` lexes as an all-digit Bare (it coerces to a number at eval),
        // not Expr::Number (which is for floats/scientific/caret-negatives) — the
        // graph is faithful to the AST.
        let applies = g
            .nodes
            .iter()
            .filter(|n| matches!(&n.kind, NodeKind::Apply(op) if op == "**"))
            .count();
        let leaves = g
            .nodes
            .iter()
            .filter(|n| matches!(n.kind, NodeKind::Bare | NodeKind::Number))
            .count();
        assert_eq!(applies, 2);
        assert_eq!(leaves, 3);
        // Every operand edge points at an Apply node (data flows into the op).
        for edge in g.edges_of(EdgeKind::Operand) {
            assert!(matches!(g.node(&edge.to).unwrap().kind, NodeKind::Apply(_)));
        }
    }

    #[test]
    fn binding_edges_link_assign_to_every_read() {
        // k='x';[$k,~$k]: the Assign(k) node feeds BOTH $k reads (one bare in the
        // list, one under ~). Two binding edges, both from the same source.
        let g = graph("k='x';[$k,~$k]");
        let bindings: Vec<&Edge> = g.edges_of(EdgeKind::Binding).collect();
        assert_eq!(bindings.len(), 2, "Assign(k) should feed both reads");
        let assign = g
            .nodes
            .iter()
            .find(|n| n.kind == NodeKind::Assign("k".to_owned()))
            .expect("assign node");
        for edge in &bindings {
            assert_eq!(edge.from, assign.id, "binding edge starts at the assign");
            assert_eq!(
                g.node(&edge.to).unwrap().kind,
                NodeKind::ContextRead("k".to_owned())
            );
        }
    }

    #[test]
    fn last_assignment_wins_by_eval_order() {
        // k='a';k='b';$k — the read binds to the SECOND assign (shadowing).
        let g = graph("k='a';k='b';$k");
        let binding = g
            .edges_of(EdgeKind::Binding)
            .next()
            .expect("one binding edge");
        // The second assign is statement 1 → path [1]; the first is [0].
        assert_eq!(binding.from, NodeId(vec![1]), "binds to the latest assign");
    }

    #[test]
    fn node_ids_are_stable_paths() {
        // Outer op is the root of statement 0; its second operand is [0.1].
        let g = graph("2**3**2");
        assert!(g.node(&NodeId::root(0)).is_some());
        let inner = g.node(&NodeId(vec![0, 1])).expect("second operand node");
        assert!(matches!(&inner.kind, NodeKind::Apply(op) if op == "**"));
        assert_eq!(inner.id.dotted(), "0.1");
    }

    #[test]
    fn truncate_ends_keeps_short_text_and_elides_long() {
        assert_eq!(truncate_ends("a short label", 6, 4), "a short label");
        let long = "one two three four five six seven eight nine ten eleven twelve";
        assert_eq!(truncate_ends(long, 3, 2), "one two three … eleven twelve");
        // Degenerate budgets return the text unchanged.
        assert_eq!(truncate_ends("x y z", 0, 0), "x y z");
    }

    #[test]
    fn external_context_read_has_no_binding_edge() {
        // $user with no in-expression assignment (comes from the context file) →
        // a source node, no binding edge.
        let g = graph("~$user");
        assert_eq!(g.edges_of(EdgeKind::Binding).count(), 0);
        assert!(
            g.nodes
                .iter()
                .any(|n| n.kind == NodeKind::ContextRead("user".to_owned()))
        );
    }

    #[test]
    fn handles_message_ranges_without_panicking() {
        // A whole-thread summary ~0^*-1: Apply(~) over a MessageRange node, whose
        // start/end indices are child nodes (real showcase move shape).
        let g = graph("~0^*-1");
        assert!(g.nodes.iter().any(|n| n.kind == NodeKind::Message));
        assert!(
            g.nodes
                .iter()
                .any(|n| matches!(&n.kind, NodeKind::Apply(op) if op == "~"))
        );
        assert!(g.edges_of(EdgeKind::Operand).count() >= 1);
    }

    #[test]
    fn handoff_dossier_resolves_reused_binding_across_statements() {
        // The fullest move — k=@~0^*-1;[$k,^_-1,~$k]: bind a formal brief, then a
        // list reusing $k twice + the live ask. Assign(k) feeds BOTH $k reads
        // across the ;-statement boundary; message nodes for the range + ^_-1.
        let g = graph("k=@~0^*-1;[$k,^_-1,~$k]");
        let bindings: Vec<&Edge> = g.edges_of(EdgeKind::Binding).collect();
        assert_eq!(bindings.len(), 2, "$k reused twice -> two binding edges");
        let assign = g
            .nodes
            .iter()
            .find(|n| n.kind == NodeKind::Assign("k".to_owned()))
            .expect("assign node");
        for edge in &bindings {
            assert_eq!(edge.from, assign.id);
        }
        assert!(
            g.nodes
                .iter()
                .filter(|n| n.kind == NodeKind::Message)
                .count()
                >= 2,
            "the range brief + the ^_-1 live ask are message nodes"
        );
    }
}
