#!/usr/bin/env bash
# nlir IDIOM · aur1 · 02 — "the decisive close"   @(~0^*-1 & 'decision: <your call>')
#
# A reusable MOVE for the pi plugin. A thread has been going back and forth — a
# real debate — and you want to CLOSE it: state your decision in a way that shows
# you weighed the whole discussion, professionally. One line:
#
#     @( ~0^*-1 & 'decision: <your call>' )
#      │   │        │
#      │   │        └─ &  fold your decision onto the debate
#      │   └─────────── ~0^*-1  the WHOLE thread, distilled (msm-0's catch-up select)
#      └─────────────── @  render the whole thing as one formal closing statement
#
# This is the SELECT ∘ TRANSFORM seam: `~0^*-1` SELECTS + distils the entire
# conversation (msm-0's lane), and `@(… & 'decision: …')` TRANSFORMS it into a
# grounded close (aur-1's lane). The result acknowledges the trade-offs that were
# actually raised AND lands the call — no "as discussed above" hand-waving.
#
# HOW TO REUSE IT (type this in chat) after any long thread:
#     |@(~0^*-1 & 'decision: ship Friday, revisit scope next sprint')
#     |@(~0^*-1 & 'decision: go with Postgres; migrate the analytics later')
#     |@(~0^*-1 & 'decision: defer — not worth it until we have real load')
#
# Run:  ./examples/idiom-aur1-02-decisive-close.sh
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
{"role":"user","content":"should we build our own auth or use Auth0?"},
{"role":"assistant","content":"Auth0 is faster to ship and handles compliance, but it's a recurring cost and some vendor lock-in."},
{"role":"user","content":"the cost adds up though, and we do have security expertise in-house"},
{"role":"assistant","content":"True — rolling our own gives full control but is a big ongoing security liability to own; a middle path is Auth0 now and migrate later only if the cost justifies it."}
]}
JSON

say "THE DECISIVE CLOSE   @(~0^*-1 & 'decision: <your call>')   — close a whole debate with your decision, grounded in the thread"
echo "  the thread: a 4-turn build-our-own-auth vs Auth0 debate"
echo "  your decision: 'decision: start with Auth0, reassess at 50k MAU'"
echo -n "  => "; "$NLIR" -e "@(~0^*-1 & 'decision: start with Auth0, reassess at 50k MAU')" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/     /'

say "SELECT ∘ TRANSFORM: ~0^*-1 distils the whole thread (msm-0's select), @(… & 'decision: …') closes it (aur-1's transform). Reuse after any long thread. (Stray leading '(' = cosmetic paren-echo; fix prototyped.)"
