#!/usr/bin/env bash
# nlir IDIOM · aur1 · 11 — "the tighten"   [<^-1, ~^-1]   (the two ways to shorten)
#
# A reusable MOVE for the pi plugin, built on `<` — the shorten operator no other
# move uses. An agent just dumped a dense, number-heavy update and you want it
# shorter — but there are TWO kinds of shorter, and the difference matters:
#
#     [ <^-1 ,  ~^-1 ]
#        │        │
#        │        └─ ~ drops to the ESSENCE: the narrative, minus the specifics
#        └────────── < drops to the INFORMATION FLOOR: sheds words, keeps EVERY fact & figure
#
# Reach for `<` when the numbers matter (a metrics update, a spec, a config) —
# it keeps all of them and just tightens the prose. Reach for `~` when you want
# the story, not the digits. Same input, two different compressions.
#
# HOW TO REUSE IT (type this in chat) on any bloated message:
#     |<^-1        (tighten it, keep every fact)
#     |~^-1        (just the gist)
#     |[<^-1, ~^-1]  (see both at once)
#
# Run:  ./examples/idiom-aur1-11-tighten.sh
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
{"role":"assistant","content":"The Q3 report shows revenue up 23% to $4.2M, but churn rose from 5% to 8%, driven mainly by the enterprise segment where we lost 3 of our top 10 accounts, though we did add 47 new SMB customers and cut support response time from 12 hours to 4."}
]}
JSON

say "THE TIGHTEN   [<^-1, ~^-1]   — two ways to shorten: keep every fact (<) vs keep the gist (~)"
echo "  the agent's dense update: Q3 revenue, churn, accounts lost/gained, support times…"
echo
"$NLIR" -e "[<^-1, ~^-1]" --context-file "$CTX" --quiet | fold -s -w 84 | sed 's/^/    /'

say "< = the information floor: sheds words, KEEPS every figure (the whole update, tightened). ~ = the essence: the narrative, minus the numbers. Reach for < when the numbers matter."
