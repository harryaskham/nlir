#!/usr/bin/env bash
# nlir IDIOM · aur1 · 09 — "the pitch-check"   [@~^_-1, ~(>!^_-1)]
#
# A reusable MOVE for the pi plugin — and the first that turns the lens on
# YOURSELF. You just typed a rough idea; before you push it, you want it polished
# into a pitch AND you want the strongest objection you'll have to answer. One
# line, reading your OWN last message (^_-1 = your side of the chat):
#
#     [ @~^_-1 ,  ~(>!^_-1) ]
#        │          │
#        │          └─ the objection to preempt: negate your idea (!), argue it (>), distil (~)
#        └──────────── your idea, distilled (~) and made a clean pitch (@)
#
# `^` reads the agent's side; `^_` reads YOURS. So where #03 honest-yes red-teams
# an AGENT's proposal, the pitch-check red-teams YOUR OWN — polish + the pushback,
# so you walk in ready for it.
#
# HOW TO REUSE IT (type this in chat) right after floating a rough idea:
#     |[@~^_-1, ~(>!^_-1)]
#   (nothing to fill in — it reads the idea you just typed and hands back the
#    pitch + the objection.)
#
# Run:  ./examples/idiom-aur1-09-pitch-check.sh
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
{"role":"user","content":"i think we should just let people pay with crypto — it'd open us to a whole new market and it's honestly not that hard to add"}
]}
JSON

say "THE PITCH-CHECK   [@~^_-1, ~(>!^_-1)]   — polish your OWN idea into a pitch + surface the objection to preempt"
echo "  the rough idea you just typed: 'let people pay with crypto — opens a new market, not hard to add'"
echo
"$NLIR" -e "[@~^_-1, ~(>!^_-1)]" --context-file "$CTX" --quiet | fold -s -w 84 | sed 's/^/    /'

say "^_ reads YOUR side. Beat 1 polishes your idea into a pitch; beat 2 is the strongest objection you'll have to answer. Stress-test your own pitch before you send it. (Honest yes red-teams the AGENT; pitch-check red-teams YOU.)"
