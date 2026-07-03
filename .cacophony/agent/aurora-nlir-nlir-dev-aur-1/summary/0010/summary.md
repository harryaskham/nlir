# Session summary — dedup negative-index resolver (src/index.rs)

## Goal

Remove the duplicated negative-index-from-end resolver: `Stack::resolve_index`
(src/stack.rs) and `messages::resolve_index` (src/messages.rs) were byte-identical.
Extract one shared implementation so the SPEC index semantics (`$N` stack, `^N`
message) live in one place. (My own reflect-session draft, handed back by msm-0.)

## Bead(s)

- `bd-410f4d` — Dedup negative-index-from-end resolver (stack + messages resolve_index)

## Before state

- Failing tests: none.
- Two identical `resolve_index(len/self.len, index) -> Option<usize>` — one a
  private `Stack` method, one a pub `messages` free fn — plus their own tests.

## After state

- Failing tests: none; 197 lib tests (net 0: one resolve_index test moved to the
  new module).
- New `src/index.rs`: canonical `pub fn resolve_index(len, index) -> Option<usize>`
  + its unit test (registered `pub mod index;`).
- `src/messages.rs`: `pub use crate::index::resolve_index;` (re-export keeps its
  public API + `[resolve_index]` doc links + tests intact); duplicate fn + test
  removed.
- `src/stack.rs`: `Stack::peek_index` calls `crate::index::resolve_index(...)`
  directly; the private duplicate method removed.
- `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, full test all
  clean (CI parity).

## Diff summary

- Code/content commits: pending final squash SHA from the reintegration receipt.
- Files touched: `src/index.rs` (new), `src/lib.rs` (+`pub mod index;`),
  `src/messages.rs` (re-export, drop dup fn+test), `src/stack.rs` (call shared,
  drop dup method).
- Tests: net 0 (resolve_index test relocated to index.rs).
- Behavioural delta: none (pure refactor); the two index resolvers are now one.

## Embedded artefacts

- None this session.

## Operator-takeaway

Small, clean, non-gated refactor done while the parallelism-approach choice is
pending with the operator — and done BEFORE resuming parallelism so it doesn't
conflict with that work (per msm-0's flag). Shared helper lives in a neutral
`src/index.rs`; messages keeps its API via `pub use`. Next in my lane: my other
reflect draft bd-127396 (MessageViews defaults placement — a design call), then
the parallelism epic once Harry rules on std::thread::scope vs rayon vs defer.
