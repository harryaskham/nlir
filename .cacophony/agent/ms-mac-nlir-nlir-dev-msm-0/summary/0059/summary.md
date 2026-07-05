# nlir-wasm: llm.rs backend twins + realiser flip + flake fix (my half of bd-02b801)

## What
Completes the lib "make it wasm-buildable" split. aur-0 landed the Cargo.toml `native` feature + lib.rs command-surface gating (@864cfb3); this is the seam-owner half: gate llm.rs's native backends behind `native` with non-native twins so the still-compiled sync eval path keeps LINKING on wasm, and fix the nix flake that aur-0's optional-deps change broke. Result: `cargo build --no-default-features --lib` compiles the core clean (no ureq/process/native deps) — nlir-wasm can now depend default-features=false.

## How
- **llm.rs**: `#[cfg(feature="native")]` real + `#[cfg(not(feature="native"))]` twin (Err stub) for the 3 LEAF backends that directly touch ureq/process: run_command_backend (→CommandError::Spawn), run_anthropic_backend (→AnthropicError::Http, the only ureq user), run_operator_command (→RealiseError::OperatorCommand). run_llm/realise_llm/call_coercion_backend/assemble_llm STAY ALWAYS-ON — they link via the leaf stubs (run_llm needed no twin: its body only calls the stubbed leaves + pure helpers). Also gated the native-only helpers now dead off-native: `use std::process::Command`, COMMAND_SHELL, DEFAULT_MAX_TOKENS, build_anthropic_request, anthropic_text.
- **realiser.rs**: NativeRealiser struct+impl+test-module `#[cfg(not(target_arch="wasm32"))]`→`#[cfg(feature="native")]`. block_on_ready stays always-on (pure std).
- **flake.nix**: aur-0's `optional = true` on the 3 git deps broke the nlirSrc `substituteInPlace --replace-fail` patterns (exact-match), breaking ALL nix builds (package/release/CI/devshell — the gate uses bare cargo so it stayed green, but nix builds were red). Updated the 3 patterns to match+preserve `, optional = true`.

## Proof (both feature sets)
- default=native: 220 lib tests, clippy -D, fmt clean, nix build restored. Real bodies unchanged → CLI byte-identical.
- --no-default-features --lib: COMPILES clean (0 warnings), clippy -D clean. This is the wasm-relevant core.

## Next
aur-0 pushes crates/nlir-wasm (default-features=false → core only) → aur-2's CI wasm build is the final verifier. Doc-cosmetic note: on native the 3 real backends are undocumented (their doc attaches to the cfg-excluded twin); no missing_docs lint (not denied). Grammar (Δ+bare-views) still parked, awaiting Harry.
