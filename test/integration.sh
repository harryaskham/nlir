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

echo "==> nlir -e evaluates end-to-end (bd-55de93 flags + bd-28dbd4/bd-1d63dc)"
# A bare literal evaluates to itself with no operators configured.
out="$("$bin" -e 'hello' --quiet)" || fail "eval of a bare literal exited non-zero"
[ "$out" = "hello" ] || fail "eval of a bare literal mismatch: '$out'"
# With a config, operators + --mode det transpile deterministically.
ecfg="$(mktemp -u "${TMPDIR:-/tmp}/nlir-ecfg-XXXXXX.yaml")"
cat > "$ecfg" <<'YAML'
defaults: { mode: det }
operators:
  and: { op: "&", arity: ">0", fixity: mixfix, join: " and " }
  add: { op: "+", arity: ">0", fixity: mixfix, operands: number, result: number, reduce: add }
YAML
[ "$("$bin" -e 'a&b&c' --config "$ecfg" --quiet)" = "a and b and c" ] || fail "eval a&b&c mismatch"
[ "$("$bin" -e '1+2+3' --config "$ecfg" --mode det --quiet)" = "6" ] || fail "eval 1+2+3 mismatch"
# --dry-run makes no calls and prints the DAG (bd-e432fc).
[ "$("$bin" -e 'a&b&c' --config "$ecfg" --dry-run --quiet)" = "(a & b & c)" ] || fail "dry-run DAG mismatch"
rm -f "$ecfg"

echo "==> nlir parse 'one two' (token preview JSON)"
"$bin" parse 'one two' | grep -q '"tokens"' || fail "parse did not emit tokens"

echo "==> nlir mcp tools (bd-b0327c) — mcp/self-update (bd-1b0283)/feedback (bd-d83ea2) stack is wired"
tools="$("$bin" mcp tools)"
echo "$tools" | grep -q '"status"' || fail "mcp tools missing the status tool"
echo "$tools" | grep -q '"eval"' || fail "mcp tools missing the eval tool"
echo "$tools" | grep -q '"parse"' || fail "mcp tools missing the parse tool"
echo "$tools" | grep -q 'self_update' || fail "mcp tools missing the self_update tools (updatable-cli)"
echo "$tools" | grep -q 'feedback' || fail "mcp tools missing the feedback tools (feedback-cli)"

echo "==> nlir test runs the config tests: block, offline det gate (bd-6b10fd)"
tcfg="$(mktemp -u "${TMPDIR:-/tmp}/nlir-tcfg-XXXXXX.yaml")"
cat > "$tcfg" <<'YAML'
defaults: { mode: det }
operators:
  not: { op: "!", arity: 1, fixity: prefix, template: "not %" }
tests:
  t-ok: { mode: det, expr: "!foo", expected: "not foo" }
YAML
"$bin" test --config "$tcfg" >/dev/null 2>&1 || fail "nlir test should exit 0 when all cases pass"
cat >> "$tcfg" <<'YAML'
  t-bad: { mode: det, expr: "!x", expected: "WRONG" }
YAML
if "$bin" test --config "$tcfg" >/dev/null 2>&1; then fail "nlir test should exit non-zero on a failing case"; fi
rm -f "$tcfg"

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

echo "==> nlir --session-file import -> _messages (bd-720cdb/bd-000666)"
sess="$(mktemp -u "${TMPDIR:-/tmp}/nlir-sess-XXXXXX.jsonl")"
{
  printf '%s\n' '{"type":"message","message":{"role":"user","content":[{"type":"text","text":"hello"}]}}'
  printf '%s\n' '{"type":"message","message":{"role":"assistant","content":[{"type":"toolCall"}]}}'
  printf '%s\n' '{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"hi"}]}}'
} > "$sess"
msgs="$("$bin" get _messages --session-file "$sess" --quiet)" || fail "session import exited non-zero"
echo "$msgs" | grep -q 'hello' || fail "session import missing the user message"
echo "$msgs" | grep -q 'hi' || fail "session import missing the assistant message"
rm -f "$sess"

echo "==> integration smoke OK"
