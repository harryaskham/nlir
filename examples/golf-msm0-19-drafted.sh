#!/usr/bin/env bash
# nlir-golf · msm0 · #19 — "drafted email" (a 3-stage generative pipeline)
#
# The deepest chain yet — THREE LLM stages, each feeding the next, with
# interpolation on BOTH sides:
#
#   t=#~0^*-1 ; b=@"write a short follow-up asking for a status update on $t" ; s=#$b ; "Subject: $s\n\n$b"
#   │           │                                                                │       └ output-interp: subject + body
#   │           │                                                                └ s=#$b   DERIVE the subject FROM the generated body
#   │           └ b = @"…$t…"   GENERATE the body (input-interp of the topic)
#   └────────── t = #~0^*-1     the topic  (stage 0)
#
#   stage 1  topic       = #~0^*-1
#   stage 2  body        = generate a follow-up FROM the topic   (topic → text)
#   stage 3  subject     = extract the subject OF the body        (text → topic)
#   stage 4  email       = template subject + body                (output-interp)
#
# nlir composing a whole email: it writes the body from the conversation, then
# titles that body — a pipeline where stage 3 reads stage 2's own output.
#
# Real output (claude-sonnet-5) over a data-export handoff thread:
#   Subject: Data Export feature
#
#   Please provide an update on the status of the Data Export feature at your
#   earliest convenience.
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
 {"role":"user","content":"Can you take over the data-export feature while I'm on leave?"},
 {"role":"assistant","content":"Sure — I'll finish the CSV streaming and the S3 upload path."},
 {"role":"user","content":"Great, the tests are half-written in the export branch."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 3-turn data-export handoff thread is in the context"
say 'DRAFTED EMAIL   topic → GENERATE body → DERIVE subject → template   (3 chained LLM stages)'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~0^*-1;b=@"write a short follow-up asking for a status update on $t";s=#$b;"Subject: $s\n\n$b"' --quiet
say "stage 3 titles stage 2's own generated body — a pipeline that reads its own output."
