# graph-viz G2: step-through graph frames (bd-c1710c)

## What
The animation source for the graph-viz epic: the sequence of dataflow-graph frames an nlir expression passes through as it reduces, so G4 (kitty PNG animation) + G5 (wasm panel) can show the computation evolving. Built on G0 (graph model, mine) + G1 (SVG renderer, aur-1); both now on main.

## How
- src/graph.rs: refactor from_program -> from_statements(&[Expr]) (frames rebuild from a partially-reduced statement slice). Frame{graph: Graph, reduced: Option<NodeId>}. Graph::binding_edges() + Graph::frame(statements, original_bindings): nodes/operand edges from the CURRENT structure, but binding edges taken from the ORIGINAL set (stable NodeIds) and kept only while their target read is still an un-reduced ContextRead -> a variable visibly feeds its uses "until consumed", even after the Assign itself collapses to a Value. reduced_between(before, after): the node that became a Value this step (for highlight/caption).
- src/eval.rs: pub fn step_frames(expr, config, ctx, mode) -> Result<Vec<Frame>, EvalError> — mirrors step_trace (drives step_once per statement, pushes finished values to the stack) but captures a Graph per step. Frame 0 = initial; each step records the reduced node. Pure/cross-platform (compiles into the wasm core; det never awaits). G4/G5 call graph_svg::render(&frame.graph) per frame — render() is frame-agnostic so it just composes.

## Proof (exit-code gated)
2 tests: 2**3**2 -> 3 frames ending in a single Value node (reduced set on every non-initial frame); k=2;[$k,$k] -> binding edges persist past the assign's own reduction (2), drop to 0 as the reads are consumed. Full suite 234, --no-default-features --lib compiles clean (wasm core), clippy -D both sets, fmt (all exit=0 directly).

## Next
Post Frame/step_frames to aur-2 (G3/G4) + aur-1 (G5). Optional follow-up: step_frames_async for wasm LLM-mode graph animation (mirrors step_async). Grammar (Delta+bare-views) still parked awaiting Harry.
