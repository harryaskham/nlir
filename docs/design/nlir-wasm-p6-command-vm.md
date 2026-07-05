# nlir-wasm P6 — command-VM spike (bd-89bcb7)

Epic: bd-360d0c. Parent design: `docs/design/nlir-wasm.md` §3.7. Resolves the §6
open question *"which wasm-sh for the command-VM (size vs coverage)."*

Goal: run `command:` operators (bash snippets) in the browser widget, sandboxed
(no host FS/network — only `NLIR_ARGS`), wired through the P0 `Realiser` trait's
`command()` callback (currently errors *"no command realiser set"* in
`crates/nlir-wasm/src/lib.rs`).

## 1. Coverage need — what actually ships

Only **one** `command:` *operator* ships in `config.example.yaml`: **`_` echo**.
(The `claude` / `pi` entries are LLM *model* commands — in the browser they route
through `realiser.llm` → BYO base-url, NOT the command-VM. So they are out of
scope here.)

`_` echo's snippet:

```bash
t="${NLIR_ARGS[0]}"; n="${NLIR_ARGS[1]}"; out="$t"
for i in $(seq 1 $((n-1))); do out="$out $t"; done
printf '%s' "$out"
```

Feature surface it exercises: **bash arrays** (`${NLIR_ARGS[k]}`), **arithmetic
expansion** (`$((n-1))`), **command substitution** (`$(seq …)` + the `seq`
coreutil), a **`for` loop**, string concat, and `printf`. That is a real bash
subset — not trivial, but bounded.

Two tiers of coverage:
- **MVP:** run the shipped `_` echo (the acceptance test: `x_2` → `x x`).
- **Stretch:** arbitrary *user-defined* `command:` ops (open-ended bash).

## 2. The hard constraint: bash arrays

`NLIR_ARGS` is passed as a **bash array** (`nlir_args_declaration` emits
`NLIR_ARGS=(arg0 arg1 …)` and the native backend runs `bash -c`). POSIX `sh`
(dash, busybox `ash`) has **no arrays**, so `${NLIR_ARGS[k]}` will not run
verbatim on a POSIX-only shell. Two ways out:

- **(keep the contract)** use a **bash-compatible** wasm shell → `_` echo runs
  unchanged, and native ↔ wasm stay identical (the anti-drift guarantee, §3.8).
- **(change the contract)** rewrite `NLIR_ARGS` to POSIX-friendly positional
  params / env vars so a lighter POSIX sh suffices. **Rejected here:** it is a
  SPEC/native-facing change (touches `nlir_args_declaration` + every user command
  op) and breaks the byte-for-byte native↔wasm parity — out of scope for a wasm
  spike. Keep the bash-array contract; make the wasm side meet it.

## 3. Sandboxing is free on `wasm32-unknown-unknown`

The strongest sandbox is the **target**: `wasm32-unknown-unknown` has **no
syscalls** — a shell compiled to it *cannot* touch host FS/network by
construction; it only sees what we inject (the snippet + `NLIR_ARGS`) and returns
captured stdout. A `wasm32-wasi` build instead needs an explicitly **empty
virtual FS + no network capabilities** (via a WASI shim). Prefer
`wasm32-unknown-unknown` for the sandbox guarantee; only fall to WASI if the
chosen shell can't build without syscalls.

## 4. Options (size vs coverage)

| option | coverage | bash arrays | sandbox | plumbing | size* |
|---|---|---|---|---|---|
| **A. brush** (Rust bash-compat shell → wasm) | high (bash-ish, arrays/arith/loops/`$( )`) | ✅ (targets bash) | `wasm32-unknown-unknown` if it builds w/o std::fs/process; else WASI+empty-FS | Rust — **integrates with the existing wasm-bindgen crate/toolchain**; warm in a Worker | ~moderate |
| **B. bash.wasm** (bash via emscripten/WASI) | full bash | ✅ | WASI + empty FS + virtual readline | heavy: WASI/emscripten runtime + Worker + FS shim; separate build pipeline | heavy |
| **C. busybox/dash.wasm** (POSIX ash) | POSIX sh + coreutils (incl `seq`) | ❌ (no arrays) | WASI + empty FS | Worker + WASI shim **+ requires the §2 contract change** | ~1 MB |
| **D. minimal Rust sh-subset** (hand-rolled) | just the shipped grammar (assign, `${arr[k]}`, `$(( ))`, `$(seq …)`, `for`, concat, `printf`) | ✅ (by construction) | `wasm32-unknown-unknown` (no deps) | tiny — compiled INTO the crate, optional Worker | tiny |

*sizes need CI measurement — the author node can't wasm-build (§3.9: build/smoke
runs in CI or the devshell, not here). Treat the size column as relative, not
absolute.

## 5. Recommendation

**Primary: A. brush**, compiled to `wasm32-unknown-unknown`, kept warm in a Worker
and invoked from `JsRealiser.command`. Rationale: it is **Rust** (same toolchain
as the nlir-wasm crate — no separate emscripten/WASI pipeline), **bash-compatible**
(runs `_` echo *verbatim*, no contract change, preserves native↔wasm parity), and
covers arbitrary user command ops (the stretch tier) for free.

**Verification gates before committing to brush** (the real spike work, runs in
CI/devshell):
1. brush builds to `wasm32-unknown-unknown` (or, if it hard-depends on
   `std::fs`/`std::process`, to `wasm32-wasi` with an empty FS).
2. It can execute a **script string** with injected env/args and **capture
   stdout** (no TTY/interactive assumptions).
3. It is genuinely sandboxed — FS/network/`exec` builtins are absent or no-ops in
   the wasm build (audit + restrict the builtin set).
4. Measured bundle size is acceptable for a static playground (`wasm-opt` trim).

**Fallback: D. minimal Rust sh-subset** if brush fails a gate (too heavy, won't
build no-syscall, or unsafe builtins). It ships the MVP (`_` echo + common
snippets) tiny and sandboxed-by-construction; unsupported bash features error
*clearly* ("command-VM: unsupported shell feature") rather than silently
mis-running. User command ops beyond the subset are the known limitation.

**Rejected: C (busybox/dash)** — POSIX-only forces the §2 native contract change;
**B (bash.wasm)** — full bash is disproportionate plumbing/size for a playground
whose only shipped command op is `_` echo.

## 6. Integration sketch

- `JsRealiser.command(command, args)` (currently the *"no command realiser set"*
  error) → post `{ script, NLIR_ARGS }` to a **warm command-VM Worker** →
  run in the wasm shell → resolve with captured stdout (or a structured error).
- The Worker loads the shell wasm once and stays warm (low latency, per §3.7).
- The native path is unchanged; this only fills the browser's `command` seam,
  keeping `_` (and future command ops) working in the widget — the same seam we
  deliberately left for P6 when we skipped the llm-fallback for command ops.

## 7. Lanes / next steps

- **msm-0 (wasm/eval):** the shell selection + the crate-side `command()` wiring
  (brush integration or the minimal interpreter) + the Worker protocol.
- **aur-2 (ci/build, P7):** add the command-VM wasm build to the co-build job so
  it ships from the same commit; measure size.
- **aur-1 (site):** load + keep the command-VM Worker warm; surface command-op
  results/errors in the widget.

MVP acceptance (from the bead): **`x_2` (echo repeat) runs in the browser widget.**
