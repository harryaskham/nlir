# graph-viz G0: dataflow graph model (bd-10cf87, KEYSTONE)

## What
The keystone of the graph-viz epic (bd-8ac9ad, Harry's ask): a pure core module that turns a parsed nlir expression into a dataflow graph, so G1 (SVG) / G3 (CLI kitty) / G5 (wasm panel) all render the SAME graph. Unblocks aur-1's G1 + G5 and my G2.

## How (src/graph.rs, pure/cross-platform -> compiles into the wasm core)
- Graph{nodes,edges}. Node = {id, kind, label}. NodeKind covers every Expr variant (Apply/Assign/ContextRead/Stack/Message/List/Group/Serial/Bare/Number/Quoted/Value).
- NodeId = stable PATH from the program root (statement index, then child positions), so G2's stable layout works as subtrees reduce to Expr::Value (a node keeps its path). dotted() renders "0.1.2".
- OPERAND edges: every child sub-expression -> its parent (data flows operand->op), so it reads as a dataflow, not a syntax tree.
- BINDING edges (the key ask): each Assign{key} node -> EVERY ContextRead(key) that consumes it. Resolved in EVAL ORDER (walk children-first, statements left-to-right), last-assignment-wins (shadowing). External context reads (no in-expr assign) correctly get no binding edge.
- truncate_ends(s, head, tail) -> "first few words ... last few words", the shared long-text/Value eliding helper.
- Graph::from_program (bindings resolve across `;`) + from_expr (single, for G2) + node()/edges_of() accessors.

## Proof (direct exit-code gating -- the lesson)
6 graph unit tests (operand edges on 2**3**2, Assign->both reads on k='x';[$k,~$k], last-wins shadowing, stable path ids, truncation, external-read-no-binding). Full suite 226 native, --no-default-features --lib compiles clean (wasm core), clippy -D both feature sets, fmt --check exit=0.

## Note learned
A plain integer `2` lexes as an all-digit Bare (coerces to number at eval), not Expr::Number -- the graph is faithful to the AST. Expr::Number is floats/scientific/caret-negatives.

## Next
Post the frozen Graph/Node/Edge/NodeId types to aur-1 (G1 builds against them) + aur-2. Then G2 (step frames) once G1 lands (blocked on G0+G1). Grammar (Delta+bare-views) still parked awaiting Harry.
