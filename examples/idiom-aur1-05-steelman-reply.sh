#!/usr/bin/env bash
# nlir IDIOM · aur1 · 05 — "the steelman reply"   [~(>@^-1), @(!^-1 & '<grounds>')]
#
# A reusable MOVE for the pi plugin, and the fair-minded twin of #03's honest yes.
# You DISAGREE with a proposal — but the honest, persuasive way to say no is to
# first show you understood it at its strongest (steelman), THEN decline. Two
# beats, one line:
#
#     [ ~(>@^-1) ,  @(!^-1 & '<your grounds>') ]
#        │          │
#        │          └─ your reasoned no: negate their proposal (!^-1), on your grounds (&), argued (@)
#        └──────────── the STRONGEST one-line case FOR their idea:
#                      expand it (>), formalise (@), distil to the crux (~)
#
#   #03 honest-yes = doubt your own YES  (reply, then the case against it)
#   #05 steelman   = be fair before your NO (their best case, then your decline)
#   Together: the two honesties — never agree without a doubt, never refuse without charity.
#
# HOW TO REUSE IT (type this in chat) when you disagree but want to be fair:
#     |[~(>@^-1), @(!^-1 & 'we are 4 engineers; the ops overhead would swamp us')]
#     |[~(>@^-1), @(!^-1 & 'this optimizes a path that is under 1% of traffic')]
#     |[~(>@^-1), @(!^-1 & 'we already tried it in Q1 and it stalled on the same wall')]
#
# Run:  ./examples/idiom-aur1-05-steelman-reply.sh
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

say "THE STEELMAN REPLY   [~(>@^-1), @(!^-1 & '<grounds>')]   — their idea at its strongest, then your reasoned no"
echo "  the agent proposed: break the monolith into microservices"
echo "  your grounds:       'we are only 4 engineers — the ops overhead would swamp us before any gain'"
echo
"$NLIR" -e "[~(>@^-1), @(!^-1 & 'we are only 4 engineers — the ops overhead of microservices would swamp us before we saw any gain')]" --context-file "$CTX" --quiet | fold -s -w 84 | sed 's/^/    /'

say "Two beats: [their case, put fairly] + [your reasoned no]. Charity before dissent. The twin of the honest yes — the two honesties. (Stray leading '(' on beat 2 = cosmetic paren-echo; fix prototyped.)"
