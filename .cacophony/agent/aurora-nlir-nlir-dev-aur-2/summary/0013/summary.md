# Session summary — self-hosted release workflow (bd-36de00)

## Goal

Give nlir a release pipeline: on a pushed `v*` tag, build the `nlir` binary per
target, package update-compatible assets with checksums, verify each binary
runs, and attach them to the GitHub Release — so `nlir self-update` has assets to
pull.

## Bead(s)

- `bd-36de00` — CI: self-hosted release workflow on v* tag push; parent release
  epic `bd-e0a557`

## Before state

- Failing tests: none. `.github/workflows/` had only `ci.yml`; no release
  automation existed. `nlir --version` works (clap `#[command(version)]`).

## After state

- Failing tests: none (this bead adds a workflow file; no Rust change).
- `.github/workflows/release.yml` added, mirroring omni-cli's release.yml.

## Diff summary

- Code/content commit: `9451789` (final landed squash SHA from the reintegration
  receipt).
- Files touched: `.github/workflows/release.yml` (new).
- Tests: none (infra); the workflow's own `test` job runs `cargo test --all`.
- Behavioural delta: a `v*.*.*` tag now triggers resolve → test → per-target
  native build (x86_64-linux + aarch64-darwin) → `nlir-<version>-<target>.tar.gz`
  + `.sha256` → smoke (`nlir --version`) → upload to the Release.

## Operator-takeaway

The one meaningful deviation from the bead text: the bead said "build via the
flake", but I mirrored omni-cli's SYSTEM-toolchain native-per-target pattern
instead. That is deliberate and safer — nlir is intentionally rust-not-nix on
Linux (bd-aa78ee's nix dev-shell segfault), so a native `cargo build --release`
avoids the nix path entirely, and it matches the named reference sibling
(omni-cli) exactly. Targets are omni-cli's proven runner-label set (x86_64-linux
+ aarch64-darwin); aarch64-linux was omitted because no such runner label exists
in the pool (it would hang the matrix). The per-target smoke run is the
pre-publish inspection gate: a broken binary fails the release before the asset
is attached. This closes the release-workflow half of the `bd-e0a557` release
epic alongside the CI gate landed earlier.
