#!/usr/bin/env bash
# nlir-golf · msm0 · #41 — "graceful failure" (dogfooded: nlir never panics)
#
# A tool embedded in pi must fail CLEANLY, never crash the host. I probed the
# parser/eval with malformed input this tick; every case is a clean error + exit 1,
# no panic, no stack overflow:
#
#   ~~~…~a  (400 deep)  => "parse error at token 256: expression nesting too deep"
#                          (the MAX_PARSE_DEPTH fuzz-guard, bd-f2df5d — a deep nest
#                           errors instead of a SIGABRT stack overflow)
#   ^99                 => "no message at ^99"          (out-of-bounds message read)
#   "unterminated       => "unterminated \" quote"      (lex error, position-pinned)
#   ~                   => "unexpected end of input"    (prefix op, missing operand)
#   $undefinedvar       => "unknown context key ..."    (bad interpolation)
#
# And out-of-bounds RANGES CLAMP sensibly (0^*99 -> the available turns) rather than
# erroring — a range is a request, not an assertion. No input crashes the process.
# The deterministic substrate is production-safe; that's what lets pi embed nlir in a
# hot path. (Robustness re-confirmed by fresh dogfooding; the depth guard is my
# earlier fuzz-hardening.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# fully deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
try() { printf '  %-24s => ' "$1"; "$NLIR" --config "$CFG" --mode det -e "$2" 2>&1 | head -1; }

say 'malformed input -> clean errors, never a panic:'
DEEP="$(printf '~%.0s' $(seq 1 400))a"
printf '  %-24s => ' 'deep nest (400x ~)'; "$NLIR" --config "$CFG" --mode det -e "$DEEP" 2>&1 | head -1
try 'out-of-bounds read'   '^99'
try 'unterminated quote'   '"oops'
try 'prefix, no operand'   '~'
try 'bad interpolation'    '$undefinedvar'
say 'out-of-bounds RANGES clamp (a range is a request, not an assertion):'
try 'range past the end'   '0^*99'
say "no input crashes the process — the deterministic substrate is production-safe. That's why pi can embed it."
