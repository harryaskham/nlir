#!/usr/bin/env bash
# nlir-golf · aur1 · #45 — "the loop closer" (opening question ⋈ closing answer)
#
# The "here's what we figured out" recap. `~(^_0 & ^-1)` grabs the FIRST user turn
# (^_0, the question that started it all) and the LAST assistant turn (^-1, the
# answer we landed on) and summarises them TOGETHER — so the synthesis law ties the
# opening problem straight to the closing solution, dropping all the diagnostic
# back-and-forth in between.
#
#   LOOP CLOSER   ~(^_0 & ^-1)   (^_0 = first USER turn, ^-1 = last ASSISTANT turn)
#     ^_0  "why is my app suddenly so slow on the orders page"
#     ^-1  "That's a classic N+1 query… add eager loading so orders + line items
#           load in a single query."
#     ~(^_0&^-1) → "The orders page is slow due to an N+1 query problem that can be
#                   fixed with eager loading."
#
# A problem→solution capsule: it answers the question you STARTED with, using the
# conclusion you ENDED with, and throws away the middle. Distinct from #33's arc
# (~(^_0 & ^_-1) = first + last USER turns = the drift/trajectory); here we cross
# ROLES — the user's opening ask meets the assistant's final word. The "so, what
# did we conclude?" button.
#
# Run:  ./examples/golf-aur1-45-loopcloser.sh
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
{"role":"user","content":"why is my app suddenly so slow on the orders page"},
{"role":"assistant","content":"Let's check — is it slow on every load or only with lots of orders?"},
{"role":"user","content":"only when a customer has hundreds of orders"},
{"role":"assistant","content":"That's a classic N+1 query: you're firing one query per order. Add eager loading so the orders and their line items load in a single query."}
]}
JSON

say "LOOP CLOSER  ~(^_0 & ^-1)  — synthesise the FIRST user question with the LAST assistant answer"
echo -n "  ^_0  (first user Q)  => "; "$NLIR" -e "^_0" --context-file "$CTX" --quiet
echo -n "  ^-1  (last asst A)   => "; "$NLIR" -e "^-1" --context-file "$CTX" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  ~(^_0&^-1) (closed)  => "; "$NLIR" -e "~(^_0&^-1)" --context-file "$CTX" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "Problem→solution capsule: answers what you ASKED with what you CONCLUDED, drops the middle. (vs #33 arc = two USER turns.)"
