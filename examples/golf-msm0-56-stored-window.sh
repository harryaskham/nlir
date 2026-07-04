#!/usr/bin/env bash
# nlir-golf · msm0 · #56 — "the stored window" (context-driven dynamic windowing)
#
# Credit aur-0's reconcile: a range BOUND can be a CONTEXT READ ($k), so a window is DATA
# you can store, compute, and replay — not just a literal you hard-code.
#
#   s=1 ; e=3 ; ~$s^*$e
#   │     │     └ ~( $s^*$e )   summarise the window whose bounds are READ from $s and $e
#   │     └ e=3   store the END index in context
#   └────── s=1   store the START index in context
#
# So you compute/store a window once (s, e) and address it later — CONTEXT-DRIVEN windowing.
# `$start^*$end` reads BOTH bounds from context; `^*$k` reads a single index via a stored
# value. #55 showed bounds are arithmetic; this shows they're also $-resolvable, so the
# window becomes first-class data (store it, pass it, replay it).
#
# CORRECTION to #55's boundary line: a BARE identifier in index position (k^*…) is a string
# literal and errors — but `$k` IS a context read that coerces to the index. Only the
# "...$k..." STRING-interpolation form is non-resolving in index position, not `$k` itself.
#
# Real output (claude-sonnet-5), search-feature thread, stored window 1..3:
#   s=1;e=3;~$s^*$e => "Typeahead search needs to evolve into a full search engine (e.g.
#                       OpenSearch) to support typo tolerance and synonyms."
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
 {"role":"user","content":"Kickoff: let's scope the search feature."},
 {"role":"assistant","content":"Start with typeahead over the existing index."},
 {"role":"user","content":"Users also want typo tolerance and synonyms."},
 {"role":"assistant","content":"That means a real search engine — consider OpenSearch."},
 {"role":"user","content":"Great, let's timebox a spike next sprint."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "det — store a window (s=1,e=3), then read it back as range bounds:"
printf '  s=1;e=3;$s^*$e   => '; "$NLIR" --context-file "$CTX" --config "$CFG" --mode det --quiet -e 's=1;e=3;$s^*$e' | tr '\n' ' '; echo
say 'llm — summarise the STORED window   s=1;e=3;~$s^*$e'
printf '  => '; "$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 's=1;e=3;~$s^*$e' --quiet
say "the window is DATA — store it, replay it. \$k in index position is a context read (not the string form)."
