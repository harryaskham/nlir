#!/usr/bin/env bash
# nlir IDIOM · aur1 · 03 — "the honest yes"   [@(^-1 & '<amendment>'), ~>!^-1]
#
# A reusable MOVE for the pi plugin. An agent proposes something you're INCLINED
# to accept. The honest move is to say yes with your amendment AND, in the same
# breath, surface the strongest case against it — so you're not fooling yourself.
# Two beats, one line:
#
#     [ @(^-1 & '<your amendment>') ,  ~>!^-1 ]
#        │                             │
#        │                             └─ ~>!^-1  the crux case AGAINST their idea:
#        │                                negate it (!), argue it out (>), distil (~)
#        └─ your considered reply: their suggestion (^-1) + your amendment (&), formal (@)
#
# It reads the conversation TWICE — once to reply, once to red-team — and the
# second beat is generated, not typed: nlir builds the best counter-argument to
# the very thing you just agreed to. That's the honesty: an automatic devil's
# advocate on your own yes.
#
# HOW TO REUSE IT (type this in chat) after any tempting proposal:
#     |[@(^-1 & 'but let''s pilot it on one team first'), ~>!^-1]
#     |[@(^-1 & 'and cap the budget at 20k'), ~>!^-1]
#     |[@(^-1 & 'yes, ship it behind a flag'), ~>!^-1]
#
# Run:  ./examples/idiom-aur1-03-honest-yes.sh
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

say "THE HONEST YES   [@(^-1 & '<amendment>'), ~>!^-1]   — accept + amend, then auto-surface the strongest case AGAINST"
echo "  the agent suggested: rewrite the auth service in Rust for memory-safety"
echo "  your amendment:      'phase it over two quarters, aligned to our Q3 roadmap'"
echo
"$NLIR" -e "[@(^-1 & 'phase it over two quarters, aligned to our Q3 roadmap'), ~>!^-1]" --context-file "$CTX" --quiet | fold -s -w 84 | sed 's/^/    /'

say "Two beats: [your considered reply] + [the crux counter-case nlir builds against it]. A devil's advocate on your own yes. Reusable after any tempting proposal. (Beat 2 is generated from context — real red-teaming, not a canned line.)"
