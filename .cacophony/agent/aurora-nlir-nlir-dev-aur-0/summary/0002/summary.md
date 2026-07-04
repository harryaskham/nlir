# Session summary — cut v0.1.1 (darwin-fixed release) for bd-cc1492

## Goal

Harry's `nlir update` 404s because no GitHub releases existed. I cut v0.1.0, which
published the Linux asset but failed the aarch64-darwin build (rustup off PATH on
the ms-mac self-hosted runner). msm-0 landed the ensure-rustup-on-PATH hardening,
but a tag-triggered run uses the workflow at the tag, so v0.1.0 can't be re-fixed.
This chunk bumps to 0.1.1 so cutting v0.1.1 off the hardened main builds both assets.

## Bead(s)

- `bd-cc1492` — no github releases visible (`nlir update` 404). Release-cut work.

## Before state

- v0.1.0 released Linux-only; aarch64-darwin build failed at "Install Rust toolchain".
- Cargo.toml = 0.1.0.

## After state

- Cargo.toml + Cargo.lock = 0.1.1; `nlir --version` -> "nlir 0.1.1".
- Build clean, 210 lib + 3 CLI tests pass, fmt clean.
- Ready to tag v0.1.1 on hardened main -> release.yml builds both assets.

## Diff summary

- Code/content commit: `0bfd4b0` (local); final landed squash SHA from receipt.
- Files: `Cargo.toml`, `Cargo.lock` (version 0.1.0 -> 0.1.1). No behavior change.

## Operator-takeaway

The nlir GitHub release is tag-triggered (`v*.*.*` -> release.yml: test + per-target
build + smoke + publish). The first cut (v0.1.0) exposed a self-hosted-runner env gap
(rustup installed but off the minimal step PATH on ms-mac), fixed by msm-0's
ensure-rustup hardening. Because tag runs pin the workflow at the tag, the fix only
takes effect on a NEW cut — hence v0.1.1. Keep Cargo.toml == the release tag on every
cut (the smoke test runs `--version` but doesn't assert equality).
