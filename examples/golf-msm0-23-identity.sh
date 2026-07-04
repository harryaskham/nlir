#!/usr/bin/env bash
# nlir-golf · msm0 · #23 — "referential identity" (what assignment REALLY buys)
#
# A characterization of my signature feature (cf. aur-1's ~~~ / @@@ operator laws):
# assignment is NOT just shorthand — it changes the SEMANTICS of reuse.
#
#   WITHOUT  [ ~0^*-1 , ~0^*-1 ]      two INDEPENDENT summary calls
#   WITH     s=~0^*-1 ; [ $s , $s ]   ONE call, the value reused
#
# Two guarantees the WITH form provides that the WITHOUT form does NOT:
#   1. CALL-DEDUP: one LLM call instead of two (a DAG, not a tree).
#   2. REFERENTIAL IDENTITY: $s is byte-identical everywhere by construction.
#      The two independent ~ calls are two DICE ROLLS — on short inputs they
#      usually agree (as in the run below), but on ambiguous/long inputs they can
#      diverge. Assignment PINS the value, so identity is guaranteed, not lucky.
#
# So [~x, ~x] ≈ s=~x;[$s,$s] in MEANING, but only the assigned form guarantees
# they are the SAME string and costs one call. That is why every multi-use concept
# in my suite (fanout, digest, email, postmortem…) assigns first.
#
# Real output (claude-sonnet-5) over a slow-CI thread — here both agree, but only
# the assigned form is *guaranteed* to:
#   WITHOUT: "Speeding up a slow 40-minute CI pipeline by parallelizing tests by
#             package, caching dependencies, and running integration tests only on
#             changed modules."   (×2 — happened to match)
#   WITH:    "To cut CI time and boost merge velocity, parallelize tests by package,
#             cache dependencies, and only run integration tests on changed
#             modules."   (×2 — identical by construction)
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
 {"role":"user","content":"Our CI pipeline takes 40 minutes and it's killing our merge velocity."},
 {"role":"assistant","content":"Parallelize the test suite by package, cache the dependency layer, and only run integration tests on changed modules."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a slow-CI thread is in the context"
say 'WITHOUT assignment   [~0^*-1 , ~0^*-1]   — two independent calls (identity NOT guaranteed)'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '[~0^*-1,~0^*-1]' --quiet
say 'WITH assignment   s=~0^*-1 ; [$s , $s]   — one call, reused (identical by construction)'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 's=~0^*-1;[$s,$s]' --quiet
say "assignment = call-dedup + referential identity. That's why every multi-use concept assigns first."
