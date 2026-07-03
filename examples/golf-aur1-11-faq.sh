#!/usr/bin/env bash
# nlir-golf · aur1 · #11 — "the FAQ entry"
#
# Turn a raw document into a complete Q&A entry — the question it answers AND the
# answer — pushing the doc ONCE and reading it twice off the stack.
#
#   FAQ ENTRY   '<doc>' ; [#$? , ~$]
#     '<doc>'   push the document onto the stack
#     #$?       subject of the peeked doc, then `?` → the FAQ QUESTION ("What is X?")
#     ~$        summary of the peeked doc          → the ANSWER
#     [ … , … ] emit both as two lines
#
# `$` peeks the doc for BOTH reads, so the source appears once, not twice — my
# stack-reuse lane meeting the auto-FAQ composition (#…? = question-the-subject).
# A knowledge-base row from any paragraph: give it a rate-limiting blurb and it
# writes "What is API rate limiting?" over a one-line definition.
#
# Run:  ./examples/golf-aur1-11-faq.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
DOC='API rate limiting caps how many requests a client can make in a time window, protecting a service from being overwhelmed and ensuring fair use across clients'

say "FAQ ENTRY  '<doc>';[#\$?,~\$]  — push doc once, peek twice: [ QUESTION , ANSWER ]"
echo "  (source: a rate-limiting blurb)"
echo "  Q | A =>"
"$NLIR" -e "'$DOC';[#\$?,~\$]" --quiet | sed 's/^/    /'

say "#\$? questions the doc's subject, ~\$ answers it — a knowledge-base row from one paragraph."
