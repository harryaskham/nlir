# parser fuzz stack-overflow fix (aur-0/aur-2's CI-flake find)

## What
`parser::tests::fuzz_tokenize_and_parse_never_panic` deterministically stack-overflowed (SIGABRT) on aurora + at forced-small stacks on ms-mac. Root cause: the fuzz corpus includes deeply-nested inputs (`"(".repeat(500)`, `"[a,".repeat(500)`), and the parser recursed to MAX_PARSE_DEPTH=256 before erroring — 256 x the parser frame (~4KB) exceeds a small (~2MB default test-thread) stack, so it overflowed BEFORE the depth guard fired. Env-dependent (aurora x86 frames overflow 2MB; ms-mac aarch64 default passes) → CI-flake risk. My bare-view/Δ additions likely enlarged the frame enough to tip it.

## How
- Lowered MAX_PARSE_DEPTH 256 -> 96 (parser.rs): so max recursion (96 x ~4KB ~ 384KB) fits a conservative stack — a 256-paren input now ERRORS cleanly on small-stack callers (wasm / spawned threads), not just the 8MB CLI. Real nlir never nests near this deep.
- Ran the deep-recursion fuzz loop on an explicit 16MB-stack thread (std::thread::Builder::stack_size): the corpus intentionally probes deep nesting, so give it headroom → deterministic across runners regardless of RUST_MIN_STACK / default test-thread stack.

## Proof
Fuzz now passes at RUST_MIN_STACK 256KB / 1MB / 2MB (was overflowing <=1MB). Full suite 237, clippy -D both feature sets, fmt — all exit=0 (checked directly).

## Note
Not from aur-0's config reformat or aur-2's $_stdin — pre-existing, exposed by frame-size growth. Two-pronged: cap protects real callers, big-stack test kills the flake.
