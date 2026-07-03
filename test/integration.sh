#!/usr/bin/env bash
# Build nlir via nix and smoke-exercise the CLI surface. Run with:
#   nix run .#test
#
# This is the project's end-to-end smoke test: it builds the package and drives
# each user-facing surface (eval / parse / mcp / status via mcp / --help) against
# the real binary, asserting on output where it is cheap. It must NOT start any
# blocking server; only `mcp stdio` is exercised via `mcp tools` (no loop).
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

echo "==> nix build .#nlir"
nix build .#nlir --no-write-lock-file
bin="./result/bin/nlir"

echo "==> nlir --help"
"$bin" --help >/dev/null || fail "--help exited non-zero"

echo "==> nlir -e 'a&b&c' (skeleton identity passthrough on stdout)"
out="$("$bin" -e 'a&b&c' --quiet)" || fail "eval exited non-zero"
[ "$out" = "a&b&c" ] || fail "eval identity stub mismatch: '$out'"

echo "==> nlir parse 'one two' (token preview JSON)"
"$bin" parse 'one two' | grep -q '"tokens"' || fail "parse did not emit tokens"

echo "==> nlir mcp tools (names) — the mcp/self-update/feedback stack is wired"
tools="$("$bin" mcp tools)"
echo "$tools" | grep -q '"status"' || fail "mcp tools missing the status tool"
echo "$tools" | grep -q '"eval"' || fail "mcp tools missing the eval tool"
echo "$tools" | grep -q '"parse"' || fail "mcp tools missing the parse tool"
echo "$tools" | grep -q 'self_update' || fail "mcp tools missing the self_update tools (updatable-cli)"
echo "$tools" | grep -q 'feedback' || fail "mcp tools missing the feedback tools (feedback-cli)"

echo "==> nlir test (skeleton no-op, exit 0)"
"$bin" test || fail "test exited non-zero"

echo "==> integration smoke OK"
