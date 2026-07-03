#!/usr/bin/env bash
# nlir-golf · msm0 · #01 — "conversation intelligence"
#
# Nobody's golfed the CONVERSATION dimension yet (aur-2 did a corpus spread,
# aur-1 did single-turn cognitive ops). nlir can read + reason over an ENTIRE
# chat via the all-roles message range `0^*-1` — index 0 .. -1, where `^*` is the
# all-roles view (my M^N range, bd-c3fc30). Apply a cognitive op to that range
# and you get "understand this whole conversation" in a handful of sigils:
#
#   TL;DR   ~0^*-1    (5 sigils: ~ 0 ^ * -1)   summary( <the entire conversation> )
#   CRUX    #~0^*-1   (7 sigils)   subject( summary( <the entire conversation> ) )
#            │ │ └── 0^*-1  the whole chat, all roles, first..last  (M^N range)
#            │ └──── ~      summarise it to one line                (1 LLM call)
#            └────── #      extract the core topic = an auto-title  (1 LLM call)
#
# Depth-3 recursion that bottoms out in the conversation store. 7 chars turn a
# 4-turn debate into its title — auto-summarise + auto-title for any chat.
#
# Real output (claude-sonnet-5) over a monolith-vs-microservices debate:
#   TL;DR : Given 40 engineers straining a single deploy pipeline, team-scoped
#           microservices make sense, but only after investing in observability and CI.
#   CRUX  : Microservices adoption for team scaling
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
# Canonical operator set (#/~ + all-roles range); the sonnet=claude-CLI backend
# needs no key. Override with NLIR_CONFIG=~/.config/nlir/config.yaml if you like.
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"Should we migrate our monolith to microservices?"},
 {"role":"assistant","content":"It depends on scaling pain; microservices add operational complexity."},
 {"role":"user","content":"We have 40 engineers stepping on each other in one deploy pipeline."},
 {"role":"assistant","content":"Then team-scoped services help, but invest in observability and CI first."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { "$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e "$1" --quiet; }

say "a 4-turn monolith-vs-microservices debate is in the context (all roles)"

say "TL;DR   ~0^*-1   — summarise the ENTIRE conversation to one line"
printf '  => '; run '~0^*-1'

say "CRUX    #~0^*-1  — the topic (subject of the TL;DR) = an auto-title"
printf '  => '; run '#~0^*-1'

say "7 chars (#~0^*-1) turn a whole chat into its title. M^N ranges FTW."
