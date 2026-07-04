#!/usr/bin/env bash
# nlir-golf · aur1 · #78 — "the mirror-back" (restate what they said, so they know you heard)
#
# Reflective listening in one operator. `~^_-1` reads the user's last turn — often a long,
# frustrated ramble — and hands back a crisp restatement of it: the "so what I'm hearing is…"
# you'd lead with before answering, to prove you caught the whole thing. `~` keeps the arc
# and the specifics; nothing is answered yet, just reflected.
#
#   THE MIRROR-BACK   ~ ^_-1        (^_-1 = the last user turn)
#     ^_-1  "ok so the thing is ive been trying to get this integration working for like
#            three days now and every time i think ive got it something else breaks, first
#            it was auth, then the webhooks werent firing, now the datas coming through
#            malformed and honestly im starting to wonder if we even picked the right vendor"
#     ~^_-1 → "After three days of fixing one integration issue after another (auth, webhooks,
#             and now malformed data), the user is questioning whether they chose the right
#             vendor."
#
# It caught the three-day arc, named all three failures in order, AND surfaced the real
# worry underneath (the vendor). It's the DECLARATIVE twin of my #38 clarifier: the clarifier
# asks a question (`~^_-1?`), the mirror-back makes a statement (`~^_-1`) — confirm, then
# clarify. And it's the plain-spoken cousin of #62's escalation (`@~^_-1`): same read, but no
# `@`, so it stays conversational ("here's what I hear") rather than formal ("for the record").
#
# Run:  ./examples/golf-aur1-78-mirror.sh
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
{"role":"user","content":"ok so the thing is ive been trying to get this integration working for like three days now and every time i think ive got it something else breaks, first it was auth, then the webhooks werent firing, now the datas coming through malformed and honestly im starting to wonder if we even picked the right vendor"}
]}
JSON

say "THE MIRROR-BACK  ~^_-1  — restate the user's rambling last turn as a crisp 'here's what I'm hearing'"
echo -n "  ^_-1   (raw ramble)   => "; "$NLIR" -e "^_-1"  --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  ~^_-1  (mirror-back)  => "; "$NLIR" -e "~^_-1" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "Declarative twin of #38 clarifier (~^_-1? asks; ~^_-1 states); plain cousin of #62 escalation (@~^_-1 formal). Confirm, then answer."
