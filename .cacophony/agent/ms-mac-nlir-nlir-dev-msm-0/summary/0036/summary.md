# Session summary — CI: make the aarch64-darwin release build work on the nix self-hosted runner (bd-7e465a)

## Goal

Get the aarch64-darwin release leg to build so aur-0 can attach
nlir-<v>-aarch64-darwin.tar.gz to v0.1.1 (no version churn). This follows the
first half of bd-7e465a (the ensure-step `set -e` exit-code fix, already landed
78ac0b2), which un-red main's Linux CI but exposed a deeper darwin-only failure.

## Bead(s)

- `bd-7e465a` — [broken-on-main] CI ensure-curl/rustup step (exit-code fix landed) + aarch64-darwin toolchain setup

## Before state

- Darwin release build failed at "Install Rust toolchain" (4th time) → `curl: command not found`, exit 127.
- Diagnosis (log + runner access): dtolnay's composite action runs its OWN `command -v rustup`, which on the nix darwin runner does NOT inherit the ensure-step's `$GITHUB_PATH` additions → rustup not found → curl fallback → curl not on the composite step's PATH → 127. The Linux job's identical step passes (curl IS visible there), masking it as darwin-specific. Compounding it, the runner SERVICE overrides HOME=/var/lib/github-runners/collective-ms-mac and CARGO_HOME=/var/lib/github-runner-workdirs/nlir/.cargo, hiding the real login-user rustup at /Users/harryaskham/.cargo/bin.
- The login user already has a complete, usable toolchain: rustup 1.29.0, stable-aarch64-apple-darwin (default), cargo/rustc 1.96.0, native target installed.

## After state

- `.github/workflows/release.yml` build matrix: aarch64-darwin now SKIPS dtolnay (`if: matrix.target != 'aarch64-darwin'`; safe in the non-matrix test job where matrix.target is null → stays true). The Build step surfaces the login user's stable toolchain directly (resolves the login home via `eval echo ~$(id -un)`, prepends `~/.cargo/bin`, sets `RUSTUP_HOME=~/.rustup`) instead of relying on dtolnay/GITHUB_PATH. cc/Package/Smoke steps prepend system dirs so cc/tar/shasum/awk are found without GITHUB_PATH; apt-get is gated to where it exists (Linux). All changes are no-ops on Linux (cargo already on PATH via dtolnay).
- Verified locally under the runner's exact overridden env (`env -i HOME=<service> CARGO_HOME=<workdir>`): the Build step resolves `/Users/harryaskham/.cargo/bin/cargo` (1.96.0), sets `RUSTUP_HOME=~/.rustup`, and finds `/usr/bin/cc`. release.yml parses cleanly (yq); both dtolnay steps carry the gate.
- Pending: a `release.yml -f tag=v0.1.1` dispatch to confirm the darwin leg builds + attaches the Mac asset, then hand to aur-0.

## Diff summary

- Code/content commit: pending final squash SHA from reintegration receipt.
- Files touched: `.github/workflows/release.yml` (workflow YAML only; no Rust change).
- Tests: none (CI YAML); verified via local runner-env simulation + `yq` parse.
- Behavioural delta: darwin release build uses the login toolchain (dtolnay skipped on darwin); Linux unchanged.

## Operator-takeaway

The nasty part was that dtolnay/rust-toolchain (a composite action) does its own
`command -v rustup` and, on this nix self-hosted darwin runner, does NOT see the
GITHUB_PATH a prior step exports — so no amount of ensure-step PATH tweaking could
fix it. The durable fix is to stop routing darwin through dtolnay and use the
runner's already-present login toolchain directly, resolving the login home
because the runner service HOME/CARGO_HOME overrides hide it. Watch for the same
composite-action-can't-see-GITHUB_PATH gotcha on other self-hosted runner steps.
