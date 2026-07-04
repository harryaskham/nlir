#!/usr/bin/env bash
# nlir-golf · aur1 · #44 — "the BLUF" (bottom line up front, then the working)
#
# Answer-first communication in two sigils. `[~x, >x]` leads with the SUMMARY —
# the one-line bottom line a busy reader needs — then follows with the EXPANSION,
# the full reasoning for anyone who wants it. The inverted pyramid: conclusion,
# then support. Same claim, read top-down, gives you an exit point after line one.
#
#   BLUF   [ ~x , >x ]
#     ~x  (bottom line) → "Use a connection pool to prevent database connection
#                          exhaustion under load."                    ← the answer
#     >x  (the working) → "Rather than opening a brand-new connection every time
#                          your app runs a query, use a managed set of pre-established,
#                          reusable connections handed out to requests and returned…"
#                                                                     ← the why/how
#
# Distinct from #24 three-way-zoom ([#$,~$,>$] = topic/gist/detail, a browsing tool
# over ONE doc): BLUF is a reading ORDER for a single claim — the take-away first,
# the justification second, so the reader can stop as soon as they've got it. The
# summary and the expansion are the same fact at two depths, deliberately sequenced
# answer-then-explanation.
#
# Run:  ./examples/golf-aur1-44-bluf.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='use a connection pool to avoid exhausting database connections under load'

say "BLUF  [~x, >x]  — bottom line up front (~x), then the working (>x): answer-first communication"
echo -n "  ~x (bottom line) => "; "$NLIR" -e "~'$C'" --quiet | fold -s -w 86 | sed '2,$s/^/       /'
echo    "  >x (the working) =>"; "$NLIR" -e ">'$C'" --quiet | fold -s -w 86 | sed 's/^/     /'

say "Take-away first, justification second — stop reading once you've got it. (vs #24 zoom's 3 doc-altitudes.)"
