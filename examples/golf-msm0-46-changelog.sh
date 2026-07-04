#!/usr/bin/env bash
# nlir-golf · msm0 · #46 — "changelog section" (a Keep-a-Changelog block from a thread)
#
# Turn a debugging conversation into a markdown CHANGELOG "### Fixed" section — one
# full-sentence bullet per fix the assistant gave:
#
#   a=~^0 ; b=~^-1 ; "### Fixed\n- $a\n- $b"
#   │       │         └ markdown template (\n newlines, $a/$b as bullets)
#   │       └ b = ~^-1   summary of the LAST assistant answer  = the second fix
#   └────── a = ~^0     summary of the FIRST assistant answer   = the first fix
#
# Distinct from #33 commit (a git commit subject+body); this is a user-facing
# CHANGELOG.md block. Design note worth its own line: use ~ (a SENTENCE) for the
# bullets, NOT # (a TOPIC) — # collapses to a terse noun phrase ("UTF-8 BOM") that's
# too thin for a changelog entry (exactly the #-is-terse behavior from my #37/#39).
#
# Real output (claude-sonnet-5) over a CSV-export debugging thread:
#   ### Fixed
#   - CSV values containing commas, quotes, or newlines must be wrapped in double
#     quotes with inner quotes escaped.
#   - Prepend a UTF-8 BOM so Excel correctly detects the file's encoding.
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
 {"role":"user","content":"CSV export drops rows with commas in a field."},
 {"role":"assistant","content":"You're not quoting fields; wrap any value containing a comma, quote, or newline in double quotes and escape inner quotes."},
 {"role":"user","content":"Right, and Excel mangles UTF-8 too."},
 {"role":"assistant","content":"Prepend a UTF-8 BOM so Excel detects the encoding correctly."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn CSV-export debugging thread (two fixes) is in the context"
say 'CHANGELOG SECTION   a=~^0 ; b=~^-1 ; "### Fixed\n- $a\n- $b"'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'a=~^0;b=~^-1;"### Fixed\n- $a\n- $b"' --quiet
say "one ~ bullet per assistant fix -> a CHANGELOG block. (~ for bullets, not # — # is too terse.)"
