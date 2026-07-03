#!/usr/bin/env bash
# nlir-golf · msm0 · #02 — "debate framer" (assignment = DAG value-reuse)
#
# The stack machine can COMPUTE A VALUE ONCE and reuse it. `c=~0^*-1` summarises
# the whole conversation (all-roles M^N range) into `c` with a single LLM call;
# then both branches read `$c`, so the expensive summary is SHARED across the DAG
# rather than recomputed:
#
#   c = ~0^*-1 ; [ @$c , :!$c ]
#   │              │      │
#   │              │      └ :!$c  simplify( negate($c) )  = the plain case AGAINST
#   │              └─────── @$c   formalise($c)           = the formal case FOR
#   └────────────────────── c = ~0^*-1  summarise the ENTIRE conversation, store once
#
# The list `[ , ]` renders the two registers as two lines (joined with _sep). One
# terse program turns any conversation into a balanced "here's the case, here's
# the catch" debate card — and shows `=`/`$name` value-reuse (complementary to the
# `;`/`$` stack reuse aur-1 golfs).
#
# Real output (claude-sonnet-5) over a 4-day-work-week debate:
#   FOR     : Stagger employees' days off to realize the benefits of a four-day
#             work week while maintaining five-day support coverage.
#   AGAINST : Don't spread out people's days off — you lose the good parts of a
#             4-day week and still don't get help 5 days a week.
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
 {"role":"user","content":"Should we adopt a 4-day work week?"},
 {"role":"assistant","content":"Trials show maintained output and higher morale, but coordination and client coverage suffer."},
 {"role":"user","content":"Our support team needs 5-day coverage though."},
 {"role":"assistant","content":"Stagger days off so coverage holds while most staff still get the shorter week."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "a 4-turn 4-day-work-week debate is in the context (all roles)"
say "DEBATE FRAMER   c=~0^*-1 ; [@\$c , :!\$c]"
echo "  (summarise the whole chat into c ONCE; then case FOR / case AGAINST, 2 lines)"
echo "  --- [ formal case FOR , plain case AGAINST ] ---"
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'c=~0^*-1;[@$c,:!$c]' --quiet

say "One LLM summary, reused twice via =/\$name. Assignment = DAG value-sharing."
