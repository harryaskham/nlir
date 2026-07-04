#!/usr/bin/env bash
# nlir IDIOM · aur1 · 01 — "the considered reply"   @(^-1 & '<your amendment>')
#
# A reusable MOVE for the pi plugin, not a one-off. An agent just suggested
# something; you want to reply — keeping their reasoning — but folding in YOUR
# amendment/constraint, and sending it in a professional register. That whole
# intent is a few sigils:
#
#     @( ^-1 & '<your amendment>' )
#      │   │        │
#      │   │        └─ &  join your twist onto their message
#      │   └─────────── ^-1  the agent's last message (their suggestion)
#      └─────────────── @  formalise the combined thing into a clean reply
#
# The grouping is load-bearing: `@(^-1 & '…')` formalises the WHOLE (their idea +
# your amendment) as one considered statement — whereas `@^-1 & '…'` would only
# formalise their message and tack your raw amendment on beside it.
#
# HOW TO REUSE IT (type this in chat): after any agent proposal, reply with
#     |@(^-1 & 'but scope it to just the mobile client')
#     |@(^-1 & 'and let's ship behind a feature flag')
#     |@(^-1 & 'only after the security audit ships')
#
# Run:  ./examples/idiom-aur1-01-considered-reply.sh
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
{"role":"user","content":"should we rewrite the auth service?"},
{"role":"assistant","content":"Yes — I'd rewrite the auth service in Rust for the memory-safety guarantees and to kill the class of bugs we keep hitting."}
]}
JSON

say "THE CONSIDERED REPLY   @(^-1 & '<your amendment>')   — reply to an agent's suggestion, with your twist, made formal"
echo "  the agent just said: \"…rewrite the auth service in Rust for the memory-safety guarantees…\""
echo "  your amendment:      'phase it over two quarters, aligned to our Q3 roadmap'"
echo -n "  => "; "$NLIR" -e "@(^-1 & 'phase it over two quarters, aligned to our Q3 roadmap')" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/     /'

say "One move: keep their reasoning, fold in your constraint, send it professionally. Reusable after ANY agent proposal. (A stray leading '(' is the cosmetic paren-echo — fix prototyped.)"
