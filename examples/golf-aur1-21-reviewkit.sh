#!/usr/bin/env bash
# nlir-golf · aur1 · #21 — "the review kit" (stack × message × two lenses)
#
# Push the assistant's last answer once, then look at it through two opposed
# lenses in a list — the skeptic's counter AND the curious follow-up — both
# reading the same pushed value. It stitches together three of my earlier moves:
# the stack ($ peek), red-team (#20 !^-1), and follow-up (#14 ^-1?).
#
#   REVIEW KIT   ^-1 ; [!$ , $?]
#     ^-1    push the latest answer onto the stack
#     !$     negate the peeked answer → the OBJECTION ("don't …")
#     $?     question the peeked answer → the FOLLOW-UP ("How can you …?")
#     [ , ]  emit both lines — a two-sided review of a single reply
#
# After "store sessions in Redis with a sliding 30-minute expiry", it returns the
# pushback ("don't store sessions in Redis with a sliding 30-minute expiry…") over
# the follow-up ("How can you store sessions in Redis…?"). The answer is read from
# the stack twice, so it appears once — a challenge-and-dig-deeper card in six
# sigils of body.
#
# Run:  ./examples/golf-aur1-21-reviewkit.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-aur1-21-XXXXXX.json")"
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"how should we store user sessions?"},
 {"role":"assistant","content":"store sessions in Redis with a sliding 30-minute expiry so idle users are logged out automatically"}
]}
JSON

say "REVIEW KIT  ^-1;[!\$,\$?]  — push the answer once, view it as [objection, follow-up]"
echo "  answer: store sessions in Redis with a sliding 30-minute expiry"
echo "  [objection | follow-up] =>"
"$NLIR" --context-file "$CTX" -e "^-1;[!\$,\$?]" --quiet | sed 's/^/    /'
rm -f "$CTX"

say "One push, two lenses via \$: ! objects, ? digs deeper — a challenge-and-clarify card (#14 + #20)."
