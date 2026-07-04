#!/usr/bin/env bash
# nlir-golf · aur1 · #33 — "the conversation arc" (where you started ↔ where you ended)
#
# Message-reads plus the synthesis law. `~(^_0 & ^_-1)` grabs the FIRST user turn
# (^_0) and the LAST user turn (^_-1) and summarises them TOGETHER — so the one
# sentence you get back spans both poles of the conversation at once, quietly
# revealing how far it drifted.
#
#   ARC   ~(^_0 & ^_-1)     (^_0 = first user msg, ^_-1 = last user msg)
#     ^_0   "how do i center a div in css"
#     ^_-1  "should i just switch the whole project to tailwind at this point"
#     ~(^_0&^_-1) → "The user wants to center a div in CSS and is considering
#                    switching the whole project to Tailwind."
#
# That juxtaposition IS the story: a tiny CSS question ballooned into a
# whole-framework rewrite. Distinct from #10 topic-drift ([#^_0,#^_-1] = two bare
# TAGS); here the grouped ~ (synthesis law, #29) names both ends in one breath —
# a "catch me up on where this went" for any thread. `~(a&b)` reads ^_0,^_-1 as a
# relationship, not a list.
#
# Run:  ./examples/golf-aur1-33-arc.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# self-contained conversation context (5 turns that drift from CSS to frameworks)
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"user","content":"how do i center a div in css"},
{"role":"assistant","content":"Use display:flex with justify-content:center and align-items:center."},
{"role":"user","content":"ok that works but my whole stylesheet is getting really messy and hard to maintain"},
{"role":"assistant","content":"You might consider a utility-first approach or a component library to tame the sprawl."},
{"role":"user","content":"should i just switch the whole project to tailwind at this point"}
]}
JSON

say "CONVERSATION ARC  ~(^_0 & ^_-1)  — one sentence spanning the first and last user turns"
echo -n "  ^_0  (first user turn) => "; "$NLIR" -e "^_0"  --context-file "$CTX" --quiet
echo -n "  ^_-1 (last user turn)  => "; "$NLIR" -e "^_-1" --context-file "$CTX" --quiet
echo -n "  ~(^_0&^_-1) (the arc)  => "; "$NLIR" -e "~(^_0&^_-1)" --context-file "$CTX" --quiet | fold -s -w 86 | sed '2,$s/^/       /'

say "One sentence, both poles — reveals the drift (a div → a rewrite). vs #10's two bare tags."
