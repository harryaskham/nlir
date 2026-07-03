#!/usr/bin/env bash
# Local pre-reintegration gate for nlir.
#
# Runs the SAME fast checks as CI — rustfmt, clippy with -D warnings, and the
# unit tests — so a worker can self-verify a clean merge BEFORE
# `caco agent reintegrate` and not land broken-on-main.
#
# Run it through the dev shell so the toolchain matches CI exactly:
#
#   nix run .#preflight
#   # or, equivalently, inside the dev shell:
#   nix develop --command bash scripts/preflight.sh
#
# Exit code is non-zero (and the offending step is named) if any check fails.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

step() { printf '\n==> [%s] %s\n' "$1" "$2"; }

echo "==> nlir preflight: rustfmt + clippy + unit tests ($root)"

step "1/3" "cargo fmt --all --check"
cargo fmt --all --check

step "2/3" "cargo clippy --all-targets -- -D warnings"
cargo clippy --all-targets -- -D warnings

step "3/3" "cargo test --lib"
cargo test --lib

echo
echo "==> preflight: all checks passed — safe to reintegrate"
