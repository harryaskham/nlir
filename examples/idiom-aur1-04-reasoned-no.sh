#!/usr/bin/env bash
# nlir IDIOM · aur1 · 04 — "the reasoned no"   @(!^-1 & '<your grounds>')
#
# A reusable MOVE for the pi plugin, and the honest counterpart to #03's yes.
# An agent proposes something you should push back on. You want to decline —
# clearly, professionally, and WITH your reason — not just "no". One line:
#
#     @( !^-1 & '<your grounds>' )
#      │   │        │
#      │   │        └─ &  the grounds you're declining ON
#      │   └─────────── !^-1  negate their proposal (turn their yes into a no)
#      └─────────────── @  argue it as one formal, professional statement
#
# The `!` is clause-wise: it flips ONLY their proposal, leaving your grounds
# standing — so `!^-1 & 'grounds'` reads as "we should NOT do X, because <grounds>",
# never "not X and not your grounds". (Use >@(!^-1 & '…') if you want the same no
# expanded into a full argued rebuttal instead of one crisp line.)
#
# HOW TO REUSE IT (type this in chat) to push back on any suggestion:
#     |@(!^-1 & 'it doubles our on-call burden')
#     |@(!^-1 & 'we already tried this in Q1 and it stalled')
#     |@(!^-1 & 'this optimizes for a case that is under 1% of traffic')
#
# Run:  ./examples/idiom-aur1-04-reasoned-no.sh
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
{"role":"user","content":"the prototype is due friday and we're behind"},
{"role":"assistant","content":"Let's skip writing tests for the prototype so we can move faster and hit the Friday deadline."}
]}
JSON

say "THE REASONED NO   @(!^-1 & '<your grounds>')   — decline a proposal, on your grounds, professionally"
echo "  the agent proposed: skip tests for the prototype to hit Friday"
echo "  your grounds:       'the prototype always becomes the product'"
echo -n "  => "; "$NLIR" -e "@(!^-1 & 'the prototype always becomes the product')" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/     /'

say "! flips only their proposal; your grounds stay standing → 'we should NOT do X, because <grounds>'. The honest counterpart to the yes. Want it argued out? >@(!^-1 & '…'). (Stray leading '(' = cosmetic paren-echo; fix prototyped.)"
