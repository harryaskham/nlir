#!/usr/bin/env bash
# nlir-golf · msm2 · #01 — "Earth in six characters" (semantic access `..`)
#
# Harry's golf rally, Round 1 target: produce the output "Earth". The winning
# program mixes ZERO string lookup — it's pure meaning, read through the semantic
# accessor `..` (the LLM twin of the deterministic `.`):
#
#   sol..3
#   │  │ └ 3        the position: the third element
#   │  └── ..       SEMANTIC access — read item N from the sequence the LHS DESCRIBES
#   └───── sol      "sol" = the sun; the model infers *the third planet from the sun*
#                    => "Earth"
#
# THE GOLF (why 6 chars, and the language-pinpoint it exposes):
#   aur-0's opener   'the planets from the sun'..3   (28c)  -> Earth   (robust)
#   shrinking the LHS 'sol'..3                        ( 8c)  -> Earth   (aur-0 leader)
#   shed the quotes   sol..3                          ( 6c)  -> Earth   (msm-2 winner)
#
# `sol` is a BARE LITERAL ([a-zA-Z0-9]+), so the quotes on 'sol' are dead weight:
# `sol..3` parses to the IDENTICAL ast `(sol .. 3)` and the identical det stub
# `item 3 of: sol` as the quoted form, so it feeds the realiser byte-for-byte the
# same. General principle for golfers: ANY single-token quoted operand sheds its
# quotes for a free 2-char save ('sol'..3 -> sol..3, 'planets'..3 -> planets..3).
#
# Real captures (claude-family via helsinki; verified live by msm-0 AND aur-0 the
# referee, 2026-07-07):
#   sol..3                          -> Earth
#   'the planets from the sun'..3   -> Earth   (the unambiguous SITE card — no drift)
#
# Why it's a "why nlir, not a prompt" example: it reaches a precise semantic
# target in six characters, with no exact-string lookup — the model INFERS the
# ordered collection from the phrase and returns one element. That composition of
# terse + semantic is exactly what a plain prompt can't do cleanly.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
# `..` resolves via model `medium` (= sonnet, the claude CLI) — gate on the keys
# config.example.yaml's models actually use, so a keyless local run stays clean.
has_creds() { [ -n "${LITELLM_MASTER_KEY:-}" ] || [ -n "${ANTHROPIC_API_KEY:-}" ]; }

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
det() { "$NLIR" --config "$CFG" --mode det --quiet -e "$1"; }
llm() { "$NLIR" --config "$CFG" --mode llm --quiet -e "$1"; }

say 'TARGET: "Earth"  —  Round 1, the semantic-access golf'

say 'det — the quote-shed is structural (bare literal sol == quoted "sol"):'
printf "  sol..3     (6c) => "; det 'sol..3'
printf "  'sol'..3   (8c) => "; det "'sol'..3"
echo "  ^ identical det stub 'item 3 of: sol' — the quotes were dead weight."

if has_creds; then
  say 'llm — the six-char wow and the robust site card both land "Earth":'
  printf "  sol..3                          (6c)  => "; llm 'sol..3'
  printf "  'the planets from the sun'..3   (28c) => "; llm "'the planets from the sun'..3"
else
  say 'llm — skipped (no model credentials); captures verified live by msm-0 + aur-0:'
  echo "  sol..3                          => Earth"
  echo "  'the planets from the sun'..3   => Earth"
fi

say 'nlir `..` = semantic access: index the collection a phrase DESCRIBES, no lookup.'
echo "Golf principle: any single-token quoted operand sheds its quotes (free 2 chars)."
