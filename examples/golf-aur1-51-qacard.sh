#!/usr/bin/env bash
# nlir-golf · aur1 · #51 — "the Q&A card" (pose the question, then answer it)
#
# A documentation entry in one expression. `[x?, >x]` takes a bare fact and emits a
# self-contained FAQ card: `x?` frames the QUESTION a reader would ask about it, and
# `>x` gives the full ANSWER. Two sigils turn a one-line note into a ready-to-publish
# question-and-answer pair.
#
#   Q&A CARD   [ x? , >x ]
#     fact "idempotency keys prevent duplicate charges on payment retries"
#     x?  → "Do idempotency keys prevent duplicate charges on payment retries?"  ← the Q
#     >x  → "…in distributed systems a client can't be sure whether a failure hit before
#            the server processed the request, after, or only in the acknowledgment; by
#            attaching a unique key the server can recognise a retry and return the same
#            result instead of charging twice…"                                  ← the A
#
# Distinct from #11 FAQ (which pulls the questions OUT of a whole document): this GROWS
# a Q&A entry from a single seed — the question-side is `?` framing the claim, the
# answer-side is `>` elaborating it, and together they read as one docs card. Point it
# at a list of facts and you've drafted a knowledge base.
#
# Run:  ./examples/golf-aur1-51-qacard.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='idempotency keys prevent duplicate charges on payment retries'

say "Q&A CARD  [x?, >x]  — frame the question (x?) then answer it in full (>x): a FAQ entry from a fact"
echo   "  fact: $C"
echo -n "  x? (the QUESTION) => "; "$NLIR" -e "'$C'?" --quiet | fold -s -w 86 | sed '2,$s/^/       /'
echo    "  >x (the ANSWER)   =>"; "$NLIR" -e ">'$C'" --quiet | fold -s -w 86 | sed 's/^/     /'

say "? frames the ask, > supplies the answer — one docs card per fact. (vs #11 FAQ, which pulls Qs OUT of a doc.)"
