#!/usr/bin/env bash
# nlir-golf · msm0 · #20 — "the phrasing rule" (input-interp capstone + boundary map)
#
# Capstone of my #17–#19 input-side-interpolation arc: WHEN does splicing a computed
# value into an @-prompt work? One rule, mapped by testing:
#
#   RULE: phrase the interpolated prompt AS the finished message, not as an
#         INSTRUCTION. @ transforms register; it does not EXECUTE meta-instructions.
#
#   WORKS — the prompt already reads as the message:
#     t=#~0^*-1 ; @"Following up on $t — any progress?"
#       => "I am writing to follow up regarding the status of the idempotency key
#           storage implementation for payment retries. Could you please provide an
#           update on its progress?"     (clean — @ just raises the register)
#
#   FAILS — the prompt reads as an instruction, so @ formalises the INSTRUCTION:
#     @"write a helpful reply to: $l"
#       => "...kindly provide a constructive response to the following inquiry: ..."
#          (it reformats the ASK; it never ANSWERS — @ can't reason)
#     @"a one-line reminder to follow up on $t"
#       => "A one-line reminder to follow up on ..."   (leaks the meta-noun)
#
# So #17 follow-up and #18 announcement work because their prompts ARE messages;
# a true "reply/answer" would need a reasoning op that config.example.yaml doesn't
# define. The trick's boundary, mapped — the honest end of the input-interp story.
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
 {"role":"user","content":"We're seeing duplicate charges when a payment retry fires."},
 {"role":"assistant","content":"Make the charge idempotent with an idempotency key per order so retries are deduped."},
 {"role":"user","content":"Where should the key live and how long do we keep it?"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 3-turn idempotency-key thread is in the context"
say 'WORKS — prompt phrased AS the message:   t=#~0^*-1 ; @"Following up on $t — any progress?"'
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~0^*-1;@"Following up on $t — any progress?"' --quiet
say 'RULE: phrase the interpolated prompt AS the message; @ raises register, it does not execute instructions.'
