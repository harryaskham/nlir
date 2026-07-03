#!/usr/bin/env bash
# Build nlir via nix and smoke-exercise the CLI surface. Run with:
#   nix run .#test
#
# This is the project's end-to-end smoke test: it builds the package and drives
# each user-facing surface (eval / parse / set / get / append-message / mcp /
# status via mcp / --help) against the real binary, asserting on output where it
# is cheap. It must NOT start any blocking server; only `mcp stdio` is exercised
# via `mcp tools` (no loop).
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

echo "==> nlir set/get/append-message context round-trip (bd-bf6faf/bd-f60fac/bd-6cfd88/bd-f6ba99)"
ctx="$(mktemp -u "${TMPDIR:-/tmp}/nlir-it-XXXXXX.json")"
"$bin" set greeting hello --context-file "$ctx" --quiet || fail "set KEY VALUE exited non-zero"
got="$("$bin" get greeting --context-file "$ctx" --quiet)" || fail "get exited non-zero"
[ "$got" = "hello" ] || fail "get mismatch: '$got'"
"$bin" set '{"a":"1","b":"two"}' --context-file "$ctx" --quiet || fail "set JSON object exited non-zero"
[ "$("$bin" get b --context-file "$ctx" --quiet)" = "two" ] || fail "JSON-merge get mismatch"
"$bin" append-message --role user "hi" --context-file "$ctx" --quiet || fail "append-message exited non-zero"
grep -q '"role": "user"' "$ctx" || fail "append-message did not persist a message"
if "$bin" get missing --context-file "$ctx" --quiet 2>/dev/null; then fail "get of a missing key should exit non-zero"; fi
rm -f "$ctx"

echo "==> integration smoke OK"
