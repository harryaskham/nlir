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

# bd-b15ff8: fail fast with a clear hint when run outside the nix dev shell on
# macOS. There the system toolchain lacks libiconv, so the cargo steps below
# fail at link time with a cryptic `ld: library not found for -liconv` after a
# full compile. The dev shell exports NLIR_DEV_SHELL=1 (flake.nix). Only enforced
# on Darwin; other platforms may have a working system toolchain outside nix.
if [ -z "${NLIR_DEV_SHELL:-}" ] && [ "$(uname -s)" = "Darwin" ]; then
  cat >&2 <<'HINT'
==> preflight: not inside the nix dev shell (NLIR_DEV_SHELL unset) on macOS.
    The system toolchain lacks libiconv, so cargo will fail at link time with
    `ld: library not found for -liconv`. Run preflight through the dev shell:

      nix run .#preflight
      # or, equivalently:
      nix develop --command bash scripts/preflight.sh
HINT
  exit 1
fi

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
