# Session summary — CI: darwin release build — $TARGET-gate the login toolchain (bd-7e465a)

## Goal

Actually make the aarch64-darwin release build use the login user's stable
toolchain. The prior prepend fix (3639dd6) gated on `uname`, which silently
no-op'd on the runner, so the build still used the ambient nix cargo and failed.

## Bead(s)

- `bd-7e465a` — CI ensure-step exit-code (78ac0b2) + dtolnay-skip (3d2a883) + darwin toolchain (this)

## Before state

- Darwin build (run 28707332822, on 3639dd6) still failed at "Build the release binary" with `error: linker cc not found`. The diagnostic echo I added revealed WHY: `cargo=/nix/store/...cargo-1.95.0 cc=none rustc=/nix/store/...rustc-wrapper-1.95.0` — my `if [ "$(uname -s)" = "Darwin" ]` gate never fired because the nix runner's minimal step PATH lacks /usr/bin, so `uname` itself wasn't found (`$(uname -s)` empty → gate false). The ambient nix cargo was used; its rustc-wrapper's linker is absent → cc not found.

## After state

- Build step now gates on `${TARGET}` (matrix env `${{ matrix.target }}`, always present) instead of `uname`, and prepends `/usr/bin:/bin` FIRST (a literal, needs no command) so `id`/`cc` resolve, THEN prepends the login `~/.cargo/bin` (resolved via `eval echo ~$(id -un)` since the runner service overrides HOME) so the login cargo wins over the nix cargo; sets `RUSTUP_HOME=~/.rustup`. No-op on Linux.
- Verified by simulating the exact broken runner state (minimal PATH with a stub nix cargo, no /usr/bin, TARGET=aarch64-darwin): resolves cargo=~/.cargo/bin/cargo, cc=/usr/bin/cc, rustc=~/.cargo/bin/rustc, RUSTUP_HOME=~/.rustup — the same combo that already built nlir release locally in 2m49s.
- Pending: re-dispatch release.yml -f tag=v0.1.1 to confirm on the runner + attach the Mac asset.

## Diff summary

- Code/content commit: pending final squash SHA from reintegration receipt.
- Files touched: `.github/workflows/release.yml` (Build step only this commit; adds `env: TARGET`).
- Tests: none (CI YAML); verified via minimal-PATH runner-state simulation.
- Behavioural delta: darwin build deterministically uses the login stable toolchain + system clang; Linux unchanged.

## Operator-takeaway

The trap: gating on `uname`/`command -v` fails on a runner whose minimal step
PATH lacks /usr/bin — the gate tool itself is missing, so the branch silently
no-ops. Gate on the workflow's own `matrix.target` env (always present) and
prepend /usr/bin before invoking any external command. The added diagnostic
`echo build toolchain: cargo/cc/rustc` is what turned a guessing game into a
one-look fix; keep such echoes in fragile self-hosted steps.
