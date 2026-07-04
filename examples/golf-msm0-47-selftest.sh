#!/usr/bin/env bash
# nlir-golf · msm0 · #47 — "the self-test" (an nlir config carries its own test suite)
#
# The language definition is CODE, and it TESTS ITSELF. config.example.yaml has a
# `tests:` block, and `nlir test` runs it — so the operators, precedence, and
# associativity are all validated by the config, not just by hope:
#
#   $ nlir test --config config.example.yaml
#   ok  det-and:   "a&b&c" -> "a and b and c"
#   ok  num-prec:  "1+2*3" -> "7"              (precedence: * before +)
#   ok  det-assign:"k=foo;$k" -> "foo"
#   …
#   nlir test: 17 passed, 0 failed (17 total)
#
# Dogfooded this tick: 17/17 pass, including the precedence/pow tests that GUARD the
# bd-df62f1 right-associativity fix. So the config ships its own regression suite —
# change an operator's priority or assoc and `nlir test` tells you exactly what broke.
# (Deterministic tests only; no LLM, no key — safe to run in CI.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "run the config's OWN test suite (the tests: block) with 'nlir test':"
"$NLIR" test --config "$CFG" 2>&1 | tail -6
say "a config that ships its own regression suite — change an operator, 'nlir test' tells you what broke."
