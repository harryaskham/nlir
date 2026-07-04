#!/usr/bin/env bash
# nlir-golf · aur1 · #19 — "the length dial" (compression spectrum)
#
# One idea, two lengths — the tweet and the essay of the same sentence. Where #06
# was a TONE spectrum ([:c,@c], plain vs formal), this is a LENGTH spectrum: `<`
# shrinks to the headline, `>` grows to the full brief, from the identical seed.
#
#   LENGTH DIAL   [<c , >c]
#     <c   shorten → the punchy one-liner (a tweet / commit subject / headline)
#     >c   expand  → the fleshed-out paragraph (a brief / doc / explainer)
#
# "our new caching layer cut average API latency roughly in half" becomes, at one
# extreme, "our new caching layer roughly halved average API latency", and at the
# other, a full paragraph on what the cache does, why redundant work is avoided,
# and how response times improved. Same fact, dialled from headline to whitepaper
# — pick the altitude your reader needs.
#
# Run:  ./examples/golf-aur1-19-lengthdial.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='our new caching layer cut average API latency roughly in half'

say "LENGTH DIAL  [<c , >c]  — the same fact as a headline AND as a brief"
echo "  seed: $C"
echo -n "  <c (headline) => "; "$NLIR" -e "<'$C'" --quiet
echo   "  >c (brief) =>"
"$NLIR" -e ">'$C'" --quiet | fold -s -w 88 | sed 's/^/     /'

say "< shrinks to a tweet, > grows to a whitepaper — same seed, dial the altitude to the reader."
