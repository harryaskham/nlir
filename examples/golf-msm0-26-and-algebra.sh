#!/usr/bin/env bash
# nlir-golf · msm0 · #26 — "the algebra of &" (it's a JOIN, not a logical AND)
#
# The De Morgan asymmetry in #25 begged a question: is nlir's & even a boolean AND?
# Tested — and no, it's a syntactic and-JOIN. Two set-theoretic properties, both
# revealing:
#
#   IDEMPOTENCE   a&a ?= a    ->  NO.  a&a = "a and a" — & keeps DUPLICATES (multiset,
#                                     not set; a logical ∧ would absorb: a∧a = a)
#   COMMUTATIVITY a&b ?= b&a   ->  in MEANING yes (both facts asserted), but & is
#                                     ORDER-PRESERVING: the surface keeps input order,
#                                     so a&b ≈ b&a but a&b ≠ b&a as a STRING.
#
# Conclusion: & is an ORDERED, MULTIPLICITY-KEEPING text join — "combine with 'and'"
# — NOT set-theoretic ∧. That is exactly WHY De Morgan's AND-form failed (#25): the
# operator was never boolean to begin with. (Slots into our algebra-of-nlir.)
#
# Real output (claude-sonnet-5):
#   a&a  'the deploy is blocked'&'the deploy is blocked'
#     => "the deploy is blocked and the deploy is blocked"     (NOT idempotent)
#   a&b  'the tests pass'&'the build is green'
#     => "the tests pass and the build is green"
#   b&a  'the build is green'&'the tests pass'
#     => "the build is green and the tests pass"               (order preserved; same meaning)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { "$NLIR" --config "$CFG" --mode llm -e "$1" --quiet; }

say 'IDEMPOTENCE (fails): a&a  should NOT reduce to a'
printf '  a&a => '; run "'the deploy is blocked'&'the deploy is blocked'"
say 'COMMUTATIVITY (holds in meaning, order preserved): a&b vs b&a'
printf '  a&b => '; run "'the tests pass'&'the build is green'"
printf '  b&a => '; run "'the build is green'&'the tests pass'"
say "& is an ordered, duplicate-keeping and-JOIN — not boolean ∧. (Why #25 De Morgan's AND failed.)"
