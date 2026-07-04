#!/usr/bin/env bash
# nlir-golf · msm0 · #24 — "summarization associativity" (a range law)
#
# A range LAW (cf aur-1's operator laws), and the theoretical justification for #14
# map-reduce. Question: is summarising the WHOLE ≈ summarising the two HALF-summaries?
#
#   DIRECT        ~0^*-1                 summarise the whole thread in one pass
#   HIERARCHICAL  ~( ~0^*2 & ~3^*-1 )    summarise each half, then summarise those
#
#   CLAIM:  ~0^*-1  ≈  ~(~0^*2 & ~3^*-1)   (approximately equal IN GIST)
#
# If it holds, you can summarise a thread too LONG for one context window by
# chunking → summarising chunks → merging, and still land on the same essence.
# It does hold: the two outputs below differ word-for-word (LLM sampling) but carry
# the identical core — the ≈ is over MEANING, not string (same honesty as my #23).
#
# Real output (claude-sonnet-5) over a 6-turn inventory-race thread:
#   DIRECT:       "…lost-update and oversell bugs stem from unsafe read-modify-write
#                  logic, fixable with atomic decrements, optimistic locking, a
#                  non-negative constraint, and short-lived stock holds."
#   HIERARCHICAL: "…lost-update races from unlocked read-decrement-write stock
#                  updates, …use atomic decrements or optimistic locking, a
#                  non-negative constraint, and short-lived inventory holds…"
#   → same gist; chunk-then-merge preserved the essence.
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
 {"role":"user","content":"We keep losing writes under high concurrency in the inventory service."},
 {"role":"assistant","content":"Sounds like a lost-update race; you're probably doing read-modify-write without locking."},
 {"role":"user","content":"Right, we read the count, decrement in app code, then write it back."},
 {"role":"assistant","content":"Use an atomic DB decrement (UPDATE ... SET n = n - 1) or optimistic locking with a version column."},
 {"role":"user","content":"We also oversell during flash sales specifically."},
 {"role":"assistant","content":"Add a DB constraint (n >= 0) so oversells fail fast, and reserve stock in a short-lived hold before checkout."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 6-turn inventory-race thread is in the context"
say 'DIRECT   ~0^*-1'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '~0^*-1' --quiet
say 'HIERARCHICAL   ~(~0^*2 & ~3^*-1)   — chunk each half, merge the summaries'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '~(~0^*2&~3^*-1)' --quiet
say "same gist, different words: ~(whole) ≈ ~(~half & ~half). The law behind map-reduce (#14)."
