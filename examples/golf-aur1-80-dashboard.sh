#!/usr/bin/env bash
# nlir-golf · aur1 · #80 — "the conversation dashboard" (a whole thread, at a glance) · MILESTONE
#
# Eightieth example — the capstone of everything I've learned about READING a conversation.
# Across the run I built pieces: the clarifier, triage, escalation, the minute, the mirror-
# back, the thread header. This assembles the essentials into one panel — point it at any
# live thread and get a catch-up dashboard: what it's about, what was last said, what's open.
#
#   THE CONVERSATION DASHBOARD   [ #^_0 , ~^-1 , ~^_-1 ]
#     …a 5-turn thread that started "why is our API slow?" and narrowed to a caching choice…
#     #^_0  → "API response times"                                    ← TOPIC   (opening ask)
#     ~^-1  → "An uncached per-request org-settings lookup is serializing requests under load;
#              a short-TTL cache should sharply cut p99 latency."      ← LAST ANSWER (assistant)
#     ~^_-1 → "The user is asking whether to cache with Redis or an in-process LRU."
#                                                                       ← OPEN ASK (user)
#
# Three reads, three positions, three jobs. `#^_0` names the thread from its FIRST user turn
# (stable heading). `~^-1` distils the LAST assistant turn (what was decided). `~^_-1` distils
# the LAST user turn (what's on the table now). Read top to bottom it's a complete resume-here
# card — the header (#79) plus the answer, the whole conversation compressed onto one screen,
# for whoever picks the thread up next. The conversation lane, in a single expression.
#
# Run:  ./examples/golf-aur1-80-dashboard.sh
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
{"role":"user","content":"our API response times have gotten really slow over the last month, can you help me figure out why?"},
{"role":"assistant","content":"Likely suspects: an N+1 query, a missing index, or connection-pool exhaustion. Which endpoints are slowest, and does it correlate with traffic?"},
{"role":"user","content":"the /dashboard endpoint is the worst, and yeah worse under load. we're not caching the org-settings lookup that every request does"},
{"role":"assistant","content":"That's almost certainly it — an uncached per-request lookup serializes under load. Cache org-settings with a short TTL and the p99 should drop sharply."},
{"role":"user","content":"great, ill add the cache. should i use redis or just an in-process LRU?"}
]}
JSON

say "THE CONVERSATION DASHBOARD  [#^_0, ~^-1, ~^_-1]  — TOPIC (opening) / LAST ANSWER (assistant) / OPEN ASK (user)"
echo -n "  #^_0  (TOPIC)       => "; "$NLIR" -e "#^_0"  --context-file "$CTX" --quiet | fold -s -w 80 | sed '2,$s/^/                       /'
echo -n "  ~^-1  (LAST ANSWER) => "; "$NLIR" -e "~^-1"  --context-file "$CTX" --quiet | fold -s -w 80 | sed '2,$s/^/                       /'
echo -n "  ~^_-1 (OPEN ASK)    => "; "$NLIR" -e "~^_-1" --context-file "$CTX" --quiet | fold -s -w 80 | sed '2,$s/^/                       /'

say "Three positions, three jobs: #^_0 titles (first user turn), ~^-1 = last decided (assistant), ~^_-1 = open now (user). The whole thread, one screen."
