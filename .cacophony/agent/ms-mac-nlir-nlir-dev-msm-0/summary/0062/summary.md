# step_frames_async — llm-mode graph animation source (graph-viz G2 + realiser seam)

## What
The async twin of step_frames: the step-frame animation source driven through the injected Realiser, so LLM-mode graph animation works (watch an operator realise as the dataflow graph evolves) in the browser (G5 graphFrames_async) or --save-animation (G4). Completes the frames pair (det step_frames + llm step_frames_async), mirroring step_trace/step_async.

## How (src/eval.rs)
- pub async fn step_frames_async<R: Realiser>(expr, config, ctx, mode, realiser) -> Result<Vec<Frame>, EvalError>: identical to step_frames but drives step_once_async (awaits the realiser at effectful redexes; det never awaits). Same Frame{graph, reduced} output → G4/G5 render(&frame.graph) unchanged.

## Proof (exit-code gated)
+1 test: step_frames_async == step_frames in det mode (block_on_ready + NativeRealiser) over 2**3**2 + k=2;[$k,$k]. Full suite 236, clippy -D both feature sets, fmt — all exit=0. Pure/cross-platform (compiles into the wasm core).

## For the team
aur-0: wire a graphFrames_async wasm export (JsRealiser) when llm-mode in-browser graph animation is wanted — mirrors how step_async backs the wasm step() view. Not blocking (G5's det animation uses sync step_frames). My graph-viz + realiser-seam lanes are now complete (G0 model, G2 frames det+async, P0 seam, step_async). Grammar (Delta+bare-views) still parked awaiting Harry.
