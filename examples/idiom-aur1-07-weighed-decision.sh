#!/usr/bin/env bash
# nlir IDIOM · aur1 · 07 — "the weighed decision"
#   [~(>@^-1), ~(>!^-1), @(^-1 & 'decision: <your call>')]
#
# A reusable MOVE for the pi plugin, and the fullest of the reply-stance moves.
# An agent proposes something you have to RULE on. Don't just react — weigh it
# both ways, in the open, then land your call. Three beats, one line:
#
#     [ ~(>@^-1) ,  ~(>!^-1) ,  @(^-1 & 'decision: <your call>') ]
#        │          │          │
#        │          │          └─ your verdict: their proposal + your decision, made formal
#        │          └───────────── the crisp case AGAINST it   (~ distil, > argue, ! negate)
#        └──────────────────────── the crisp case FOR it        (~ distil, > argue, @ formalise)
#
# It steelmans BOTH sides of the agent's actual proposal (beat 1 = #05's steelman,
# beat 2 = its mirror) and then commits (beat 3 = #01's considered reply carrying
# your call). Everything is generated from the live proposal except your decision.
#
#   #03 honest-yes    = yes, and the doubt      (2 beats)
#   #05 steelman      = their best case, my no  (2 beats)
#   #07 weighed       = for, against, my call   (3 beats)  <- the full deliberation
#
# HOW TO REUSE IT (type this in chat) on any proposal you must rule on:
#     |[~(>@^-1), ~(>!^-1), @(^-1 & 'decision: pilot it on one team for a month first')]
#     |[~(>@^-1), ~(>!^-1), @(^-1 & 'decision: no — revisit after the Q3 audit')]
#
# Run:  ./examples/idiom-aur1-07-weighed-decision.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"user","content":"how do we handle our scaling problems?"},
{"role":"assistant","content":"We should break the monolith into microservices — it'll let each team deploy independently and scale the hot paths separately."}
]}
JSON

say "THE WEIGHED DECISION   [~(>@^-1), ~(>!^-1), @(^-1 & 'decision: …')]   — case for, case against, then your verdict"
echo "  the agent proposed: break the monolith into microservices"
echo "  your call:          'extract only the two hottest services, keep the rest a monolith for now'"
echo
"$NLIR" -e "[~(>@^-1), ~(>!^-1), @(^-1 & 'decision: extract only the two hottest services and keep the rest a monolith for now')]" --context-file "$CTX" --quiet | fold -s -w 84 | sed 's/^/    /'

say "Three beats: [the case for] + [the case against] + [your grounded verdict]. Steelman both sides, then decide — the whole arc in one line. Reusable on any proposal you must rule on."
