#!/usr/bin/env bash
# nlir IDIOM · aur1 · 06 — "the counter-offer"   [@(!^-1 & '<grounds>'), @'<alternative>']
#
# A reusable MOVE for the pi plugin, and the CONSTRUCTIVE member of the reasoned-no
# family. Don't just block a proposal — decline it on your grounds AND put a
# concrete alternative you'd back on the table. "Not that, because Y — here's what
# I'd do instead." Two beats, one line:
#
#     [ @(!^-1 & '<your grounds>') ,  @'<the alternative you would back>' ]
#        │                             │
#        │                             └─ @'…'  your alternative, stated formally as a proposal
#        └──────────────────────────────  the reasoned no (idiom #04): decline their idea, on your grounds
#
# The reply stance family, complete:
#   #01 considered-reply  yes + your amendment
#   #03 honest-yes        yes + the case against your own yes
#   #04 reasoned-no       no + your grounds
#   #05 steelman-reply    their best case + your no
#   #06 counter-offer     no + the alternative you'd back    <- constructive
#
# HOW TO REUSE IT (type this in chat) to redirect, not just block:
#     |[@(!^-1 & 'a rewrite freezes features for months'), @'migrate incrementally behind a flag']
#     |[@(!^-1 & 'we cannot own another service'), @'extend the existing job runner instead']
#     |[@(!^-1 & "that doubles on-call"), @'put it behind a nightly batch, not a live endpoint']
#
# Run:  ./examples/idiom-aur1-06-counter-offer.sh
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
{"role":"user","content":"the frontend is getting hard to maintain"},
{"role":"assistant","content":"Let's rewrite the whole frontend in the new framework — clean slate, modern tooling, no legacy baggage."}
]}
JSON

say "THE COUNTER-OFFER   [@(!^-1 & '<grounds>'), @'<alternative>']   — decline on your grounds, then offer a concrete path"
echo "  the agent proposed: rewrite the whole frontend in the new framework"
echo "  your grounds:       'a full rewrite freezes feature work for months and reintroduces fixed bugs'"
echo "  your alternative:   'migrate incrementally, one route at a time, behind a feature flag'"
echo
"$NLIR" -e "[@(!^-1 & 'a full rewrite freezes all feature work for months and re-introduces bugs we already fixed'), @'migrate incrementally, one route at a time behind a feature flag, so features keep shipping']" --context-file "$CTX" --quiet | fold -s -w 84 | sed 's/^/    /'

say "Two beats: [the reasoned decline] + [the alternative you'd back]. The constructive no — redirect instead of just blocking. (Stray leading '(' on beat 1 = cosmetic paren-echo; fix prototyped.)"
