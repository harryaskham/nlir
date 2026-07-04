#!/usr/bin/env bash
# nlir-golf · aur1 · #54 — "the triage card" (classify + summarise an incoming message)
#
# What a support desk does with every new ticket, in one expression. `[#^_-1, ~^_-1]`
# reads the LAST user turn and returns two things a dispatcher needs: `#^_-1` the TOPIC
# (the filing category — what queue this belongs in) and `~^_-1` the GIST (the
# actionable one-line summary — what actually needs doing). Classify, then summarise.
#
#   TRIAGE CARD   [ #^_-1 , ~^_-1 ]     (^_-1 = the last user turn)
#     incoming: "my payments are failing intermittently in production, 500s from the
#               gateway only under load, started after we bumped traffic yesterday…"
#     #^_-1 → "Intermittent payment gateway failures (500 errors) under load"   ← the CATEGORY
#     ~^_-1 → "Intermittent 500s from the payment gateway under load began after
#              yesterday's traffic increase, requiring urgent investigation."   ← the GIST
#
# It applies the #-vs-~ split (msm0: # extracts the stable DOMAIN, ~ the actionable
# CONTENT) to a live inbound turn — the # tells a router WHERE it goes, the ~ tells a
# human WHAT to do. Point it at every message hitting a queue and you've built an
# auto-triage front door.
#
# Run:  ./examples/golf-aur1-54-triage.sh
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
{"role":"user","content":"my payments are failing intermittently in production and i keep getting 500s from the gateway, only under load, and it started after we bumped the traffic yesterday — really need eyes on this"}
]}
JSON

say "TRIAGE CARD  [#^_-1, ~^_-1]  — TOPIC (the filing category) + GIST (the actionable summary) of a new turn"
echo -n "  #^_-1 (CATEGORY) => "; "$NLIR" -e "#^_-1" --context-file "$CTX" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  ~^_-1 (GIST)     => "; "$NLIR" -e "~^_-1" --context-file "$CTX" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "# routes it (WHERE), ~ actions it (WHAT) — the #-vs-~ split (msm0) turned into an auto-triage front door."
