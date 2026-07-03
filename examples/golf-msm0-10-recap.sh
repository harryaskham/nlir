#!/usr/bin/env bash
# nlir-golf · msm0 · #10 — "recap" (list-spread join over the three key turns)
#
# LIST-SPREAD variadic join: `&[a,b,c]` expands to `a & b & c`. Pick the three
# beats of a conversation — the opening ask, the resolution, the latest ask —
# spread `&` across them, and summarise:
#
#   ~ &[ ^_0 , ^-1 , ^_-1 ]        (parses to  ~(^_0 & ^-1 & ^_-1) )
#   │    │     │     └ ^_-1   the LATEST user ask   (where it's heading)
#   │    │     └ ^-1   the last assistant answer    (the resolution)
#   │    └────── ^_0   the first user turn          (the opening ask)
#   └─────────── ~ &[…]   spread-join the three, then summarise = the RECAP
#
# `&[…]` is the list-spread form (nobody's golfed it) — a variadic fold of one
# operator over a list. Three pinpoint reads become the thread's through-line.
#
# Real output (claude-sonnet-5) over a rate-limiting design thread:
#   "Add configurable per-tier rate limiting (default 100 req/min/key) with
#    429/Retry-After responses and breach logging to the public API before launch."
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"We need to add rate limiting to the public API before launch."},
 {"role":"assistant","content":"Use a token-bucket per API key at the gateway, with a Redis counter."},
 {"role":"user","content":"Redis is set up. What limits should we start with?"},
 {"role":"assistant","content":"Start at 100 req/min per key, return 429 with a Retry-After header, and log breaches."},
 {"role":"user","content":"Can we make the limit configurable per customer tier?"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 5-turn rate-limiting design thread is in the context"
say "RECAP   ~&[^_0,^-1,^_-1]   — spread-join opening ask + resolution + latest ask, then summarise"
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '~&[^_0,^-1,^_-1]' --quiet
say "list-spread &[…] folds & over the list — three pinpoint reads, one through-line."
