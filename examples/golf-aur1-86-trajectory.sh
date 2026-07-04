#!/usr/bin/env bash
# nlir-golf · aur1 · #86 — "the trajectory" (where the user's thinking has moved, last two turns)
#
# A conversation isn't static — the user's thinking travels. `~(^_-2 & ^_-1)` reads the user's
# last TWO turns and summarises where their reasoning has arrived: `^_-2` and `^_-1` are the
# two most recent USER turns, `&` joins them, and `~` fuses the pair into the recent arc — the
# "they'd settled X, and now they're onto Y" of the discussion.
#
#   THE TRAJECTORY   ~ ( ^_-2 & ^_-1 )
#     …a DB thread where the user commits to Postgres, then backs up…
#     ^_-2  → "let's go postgres. how do we handle migrating the data from the old sqlite db?"
#     ^_-1  → "actually before that — do we even need to migrate, or can we run both in
#             parallel during the transition?"
#     ~(^_-2 & ^_-1) → "The team has chosen Postgres but is debating whether to migrate the
#                       existing SQLite data or run both databases in parallel during the
#                       transition."
#
# It caught both moves: the settled decision (Postgres) AND the fresh doubt (migrate vs run
# in parallel). This completes my trio of two-turn reads, each anchored differently: #33 arc
# (`^_0 & ^_-1`, FIRST vs latest user — the whole-conversation drift), #68 minute (`^_-1 & ^-1`,
# latest user vs latest assistant — one Q→A exchange), and this (`^_-2 & ^_-1`, the two latest
# USER turns — the recent trajectory of their thinking). Same `~(a&b)`, three windows.
#
# Run:  ./examples/golf-aur1-86-trajectory.sh
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
{"role":"user","content":"should we use postgres or mongo for the new service?"},
{"role":"assistant","content":"For relational data with transactions, Postgres. Mongo fits flexible, denormalized documents."},
{"role":"user","content":"lets go postgres. how do we handle migrating the data from the old sqlite db?"},
{"role":"assistant","content":"Export to CSV or use pgloader, which reads SQLite directly and maps types."},
{"role":"user","content":"actually before that — do we even need to migrate, or can we run both in parallel during the transition?"}
]}
JSON

say "THE TRAJECTORY  ~(^_-2 & ^_-1)  — fuse the user's last TWO turns into where their thinking has moved"
echo -n "  ^_-2  (2nd-last user) => "; "$NLIR" -e "^_-2" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  ^_-1  (last user)     => "; "$NLIR" -e "^_-1" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  ~(^_-2 & ^_-1) TRAJECTORY => "; "$NLIR" -e "~(^_-2 & ^_-1)" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "Completes my two-turn-read trio: #33 arc (^_0&^_-1, whole drift) / #68 minute (^_-1&^-1, one exchange) / this (^_-2&^_-1, recent trajectory)."
