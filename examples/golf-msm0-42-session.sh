#!/usr/bin/env bash
# nlir-golf · msm0 · #42 — "the stateful session" (nlir as conversational MEMORY)
#
# Every other msm0 concept is a SINGLE shot over a fixed context. This one accrues
# STATE across calls: `append-message --context-file` builds up a conversation (and
# auto-creates the file on the first append), then range reads RECALL and TRANSFORM
# what accumulated. nlir isn't only a stateless transformer — it's a little
# conversation store you can grow and query:
#
#   nlir --context-file C append-message --role user      "Can we add SSO with Okta?"
#   nlir --context-file C append-message --role assistant "SAML via Okta, SCIM provisioning, behind an enterprise flag."
#   nlir --context-file C append-message --role user      "How long to build?"
#   nlir --context-file C -e '~0^*-1'
#     => "Okta SSO (SAML + SCIM, enterprise-flagged) is feasible; timeline still to be estimated."
#
# Two file flags, cleanly separated (a doc point worth knowing):
#   --context-file  = the READ-WRITE `{"_messages":[...]}` store; append-message writes
#                     it and CREATES it if missing. This is where state lives.
#   --session-file  = a READ-ONLY import of a Pi JSONL transcript (type-tagged lines),
#                     flattened into context. Import, not storage.
#
# So the SELECT dimension (#40) has a live, growing array behind it here — you append
# turns, then address+transform them.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

C="$(mktemp -u "${TMPDIR:-/tmp}/nlir-session-XXXXXX.json")"
trap 'rm -f "$C"' EXIT

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "grow a conversation across calls (append-message auto-creates --context-file):"
"$NLIR" --context-file "$C" append-message --role user      "Can we add SSO with Okta?" >/dev/null
"$NLIR" --context-file "$C" append-message --role assistant "SAML via Okta, SCIM provisioning, behind an enterprise flag." >/dev/null
"$NLIR" --context-file "$C" append-message --role user      "How long to build?" >/dev/null
printf '  3 turns appended; recall with ~0^*-1 => '
"$NLIR" --context-file "$C" --config "$CFG" --mode llm -e '~0^*-1' --quiet
say "state accrues in --context-file, then you address + transform it. nlir as memory, not just a filter."
