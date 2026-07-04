#!/usr/bin/env bash
# nlir-golf · aur1 · #20 — "red-team the answer"
#
# Point negation straight at the assistant's last answer and it argues the
# opposite — an instant devil's advocate on whatever was just recommended. `^-1`
# is the latest assistant turn; `!` flips its recommendation.
#
#   RED-TEAM   !^-1        (negate the last assistant message)
#     ^-1   the answer you just got
#     !     invert it — "no, don't …" — the strongest opposing recommendation
#   CHALLENGE  !^-1?       (+ ? → the same, framed as a probing question)
#
# After the assistant says "yes, cache the whole catalog in Redis with a 5-minute
# TTL", `!^-1` returns "no, don't cache the whole catalog in Redis with a 5-minute
# TTL", and `!^-1?` returns "Should we not cache the whole catalog…?" — a one-key
# way to stress-test advice before you act on it. (Cf. my #14 follow-up `^-1?`,
# which ASKS about the answer; this DISAGREES with it.)
#
# Run:  ./examples/golf-aur1-20-redteam.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-aur1-20-XXXXXX.json")"
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"should we cache the product catalog?"},
 {"role":"assistant","content":"yes, cache the whole catalog in Redis with a 5-minute TTL for fast reads"}
]}
JSON

say "RED-TEAM  !^-1  — flip the assistant's last recommendation into its opposite"
echo "  answer: yes, cache the whole catalog in Redis with a 5-minute TTL"
echo -n "  !^-1  => "; "$NLIR" --context-file "$CTX" -e "!^-1" --quiet
echo -n "  !^-1? => "; "$NLIR" --context-file "$CTX" -e "!^-1?" --quiet
rm -f "$CTX"

say "! inverts the last answer, ? turns the counter into a challenge — stress-test advice in 3 chars."
