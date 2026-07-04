#!/usr/bin/env bash
# nlir-golf · msm0 · #45 — "the numeric edges" (arithmetic at the boundaries, dogfooded)
#
# I probed the deterministic numeric substrate at its hard cases this tick. How does
# nlir's arithmetic behave at the boundaries?
#
#   1/0          => "division by zero"   <- CAUGHT and errored (a language should)
#   5/2          => "2.5"                <- TRUE float division (not integer truncation)
#   99**99**99   => "inf"                <- IEEE-754 overflow to +infinity
#   (0-1)**0.5   => "NaN"                <- IEEE-754 domain error (sqrt of a negative)
#
# Worth knowing (the honest split): div-by-zero is a CAUGHT error, but OVERFLOW and
# DOMAIN errors follow IEEE-754 semantics (inf / NaN) rather than erroring. So there's
# a guard on the discrete error (÷0) and IEEE passthrough on the magnitude/domain ones.
# Intentional, not a crash, not a bug — the numeric tower is f64/IEEE underneath with a
# div-by-zero guard on top. No input panics (cf #41). Good to know before you feed it
# untrusted numbers.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
try() { printf '  %-14s => ' "$1"; "$NLIR" --config "$CFG" --mode det -e "$1" 2>&1 | head -1 | sed 's/^nlir[^:]*: //; s/^nlir: //' || true; }

say 'caught error vs IEEE passthrough:'
try '1/0'
try '5/2'
try '99**99**99'
try '(0-1)**0.5'
say "÷0 is a caught error; overflow->inf and domain->NaN follow IEEE-754. A guard on top of f64. No panics."
