#!/usr/bin/env bash
# nlir-golf · aur1 · #30 — "the focus finder" (ramble → the question, at two altitudes)
#
# Milestone #30, and a genuinely handy one. Rubber-duck debugging in a single
# sigil: dump a messy, meandering problem and let `?` distil it into the one
# crisp question actually worth answering. And it works at TWO altitudes —
# plain `?` gives the concrete "how do I" question; `~?` tends to return a
# sharper, more-analysed question that names the crux (exact phrasing floats
# run-to-run — the constant is: wall-of-worry in, one focused question out).
#
#   FOCUS FINDER   ramble ? / ~ramble ?
#     x?   → the CONCRETE question, first-person, specifics intact, e.g.:
#            "How can I schedule a nightly report to deliver at 9am LOCAL across
#             three timezones, when a fixed UTC cron breaks the west-coast promise?"
#     ~x?  → a SHARPER question that surfaces the crux, e.g.:
#            "Can a single fixed-UTC cron deliver 9am-local across timezones, or does
#             the schedule need to be timezone-aware (per-timezone jobs) instead?"
#
# `?` isn't just for tiny seeds — pointed at a wall of worried text it finds the
# focus. Reach for x? to sharpen the exact ask; ~x? to ask what family of answer
# you're really after. The messy-thought-to-sharp-question move, for free.
#
# Run:  ./examples/golf-aur1-30-focusfinder.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
S='so ive got users in three timezones and the nightly report keeps running at the wrong local time for some of them, i tried setting a fixed UTC cron but then the 9am local delivery promise breaks for the west coast folks and i cant figure out the right way to schedule this'

say "FOCUS FINDER  x? / ~x?  — a rambling problem dump distilled to the ONE question (two altitudes)"
echo "  ramble: $S" | fold -s -w 92 | sed '2,$s/^/          /'
echo -n "  x?  (concrete question)  => "; "$NLIR" -e "'$S'?" --quiet | fold -s -w 88 | sed '2,$s/^/       /'
echo -n "  ~x? (abstracted question)=> "; "$NLIR" -e "~'$S'?" --quiet | fold -s -w 88 | sed '2,$s/^/       /'

say "? pointed at a wall of text finds the focus. x? sharpens the exact ask; ~x? surfaces the crux (phrasing varies)."
