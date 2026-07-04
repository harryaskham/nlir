#!/usr/bin/env bash
# nlir-golf · msm0 · #33 — "commit message" (a conventional commit from a fix thread)
#
# Turn a debugging conversation into a git commit — a "fix:" subject over a
# cause-and-fix body:
#
#   t=#~^-1 ; b=~0^*-1 ; "fix: $t\n\n$b"
#   │         │           └ "…" : conventional-commit template (subject + body)
#   │         └ b = ~0^*-1   summary of the WHOLE thread = the body (cause + fix)
#   └──────── t = #~^-1    topic of the LAST answer (the fix) = the subject scope
#
# Reads two positions at two scopes: the fix's topic (last answer, narrow) for the
# subject, the whole thread (wide) for the body. Another document FORMAT from the
# same range+assignment+interpolation toolkit (cf email #09 / postmortem #13 / ADR #22).
#
# Real output (claude-sonnet-5) over an avatar-upload 413 thread:
#   fix: `client_max_body_size` server configuration
#
#   Avatar uploads over 1MB fail silently due to nginx's client_max_body_size limit
#   and unhandled 413 errors; fix by raising the limit to 10MB and displaying a
#   proper "file too large" message on the frontend.
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
 {"role":"user","content":"Users report the avatar upload silently fails for files over 2MB."},
 {"role":"assistant","content":"The nginx client_max_body_size defaults to 1MB, so larger uploads get a 413 the frontend swallows."},
 {"role":"user","content":"Ah, and we never surface the error."},
 {"role":"assistant","content":"Raise client_max_body_size to 10MB and have the frontend show the 413 as a 'file too large' message."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn avatar-upload-413 debugging thread is in the context"
say 'COMMIT MESSAGE   t=#~^-1 ; b=~0^*-1 ; "fix: $t\n\n$b"'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~^-1;b=~0^*-1;"fix: $t\n\n$b"' --quiet
say "fix-topic (narrow) as subject, whole-thread summary (wide) as body — a git commit from a chat."
