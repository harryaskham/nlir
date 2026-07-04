#!/usr/bin/env bash
# nlir-golf · msm0 · #63 — "the rolling digest" (paginate, then summarise — detail survives)
#
# A single ~ of a whole thread is LOSSY: #58 showed it converges to a few core facts, dropping
# the specifics. The constructive fix — PAGINATE, then summarise each page. Each page has room
# to breathe, so detail survives that one big summary collapses:
#
#   [ ~0^*2 , ~3^*5 ]    two page-summaries instead of one whole-thread summary
#
# On a 6-turn sprint review:
#   ~0^*-1 (whole)      compresses "40% latency" -> "better latency" and blurs the CSV specifics
#   [~0^*2, ~3^*5]      KEEPS the 40% number AND the "scheduled job -> CSV -> bucket" detail
#
# So this is the counter to the fixed-point (#58): don't distil the WHOLE (lossy), distil the
# PAGES (lossless-er). Pair with the paginator (#62) to stride any-length thread:
# [~page0, ~page1, ~page2, …] — a rolling digest that scales to context that won't fit one summary.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"Sprint review: the payments refactor is done and deployed."},
 {"role":"assistant","content":"Nice — the latency dropped 40% and error rates are flat."},
 {"role":"user","content":"But we discovered the old fraud rules don't fire on the new code path."},
 {"role":"assistant","content":"That's serious — fraud checks are silently skipped for card payments now."},
 {"role":"user","content":"Also the finance team wants a monthly reconciliation export."},
 {"role":"assistant","content":"Straightforward — a scheduled job writing a CSV to their bucket."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "one big summary of the whole 6-turn thread (lossy — loses the 40% and the CSV specifics):"
printf '  ~0^*-1 => '; "$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '~0^*-1' --quiet
say "vs a rolling digest — summarise each page (keeps the 40% AND the scheduled-job/CSV/bucket detail):"
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '[~0^*2,~3^*5]' --quiet
say "distil the PAGES, not the WHOLE — the constructive counter to the fixed-point (#58). Scales via the paginator (#62)."
