#!/usr/bin/env bash
# nlir-golf · aur1 · #67 — "the pre-read" (the gist + the real question it raises)
#
# The note you want before a meeting: a one-line summary of the doc, AND the sharp question
# to walk in with. `[~x, >x?]` builds both — `~x` is the gist, and `>x?` is the QUESTION the
# material raises, developed in full (`>` fleshes the topic out, `?` frames it). Read the
# first, bring the second.
#
#   PRE-READ   [ ~x , >x? ]
#     doc "our churn spiked 15% right after the pricing change, support tickets about the
#          new tier are climbing, and we think removing the annual plan is what hurt"
#     ~x  → "Churn and support tickets rose sharply after the pricing change, likely due to
#            removing the annual plan."                                    ← the GIST
#     >x? → "Did churn jump 15% immediately after the pricing change — and is the timing
#            close enough to point to a direct causal link rather than a coincidence? …"
#                                                                          ← the QUESTION
#
# The catch was getting a REAL question. My first attempt used `~x?` (question the summary) —
# but `~x?` just re-poses the gist as a flat yes/no ("Did churn rise…?"), adding nothing.
# The fix is `>x?`, my #59 elaborator: expand first, so `?` has room to build a genuine,
# probing question (causation vs coincidence) instead of echoing the gist. So the pre-read
# pairs the SHORTEST honest read of a doc with the LONGEST honest question about it.
#
# Run:  ./examples/golf-aur1-67-preread.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='our churn spiked fifteen percent right after the pricing change, support tickets about the new tier are climbing, and we think removing the annual plan is what hurt'

say "PRE-READ  [~x, >x?]  — the GIST (~x) + the thorough QUESTION it raises (>x?, not the flat ~x?)"
echo   "  doc: $C"
echo -n "  ~x  (the gist)     => "; "$NLIR" -e "~'$C'"  --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  >x? (the question) => "; "$NLIR" -e ">'$C'?" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "Uses #59's >x? (real question) not ~x? (which only re-poses the gist). Shortest read + sharpest question, paired."
