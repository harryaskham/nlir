#!/usr/bin/env bash
# nlir-golf · aur1 · #84 — "the glossary card" (name the concept, then define it: [#x, >#x])
#
# The auto-glossary. `[#x, >#x]` turns any sentence that MENTIONS a concept into a two-part
# dictionary entry: `#x` is the TERM (the concept, as a clean heading) and `>#x` is the
# DEFINITION (that concept, expanded into an explanation). Front and back of a flashcard,
# lifted straight out of a bug report or a Slack message.
#
#   THE GLOSSARY CARD   [ #x , >#x ]
#     x "the retry storm happened because our clients all back off with the same fixed delay
#        and hammer the server in sync"
#     #x  → "Synchronized fixed-delay retry storm"                      ← the TERM
#     >#x → "Synchronized fixed-delay retries describes a strategy where a client waits the
#            exact same constant interval before every retry — rather than progressively
#            backing off — so all clients retry in lockstep and overwhelm the server…"
#                                                                        ← the DEFINITION
#
# `#` names it (heading), `>#` (my #82 define-topic) explains it (body). Read together it's a
# wiki glossary entry or a study flashcard for whatever concept a message was really about.
#
# HONEST REJECT: I first tried `[#x?, >#x]` to make it a Q&A card — but `#x?` doesn't ask
# "what is X?"; it poses a topical yes/no ("Can a thundering herd result from synchronized
# retries?"), which doesn't line up with the definition. So the clean card is heading + body,
# `[#x, >#x]`, not question + answer.
#
# Run:  ./examples/golf-aur1-84-glossary.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='the retry storm happened because our clients all back off with the same fixed delay and hammer the server in sync'

say "THE GLOSSARY CARD  [#x, >#x]  — the TERM (#x, a heading) + the DEFINITION (>#x, the body)"
echo   "  x: $C"
echo -n "  #x  (the TERM)       => "; "$NLIR" -e "#'$C'"  --quiet | fold -s -w 80 | sed '2,$s/^/                        /'
echo -n "  >#x (the DEFINITION) => "; "$NLIR" -e ">#'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/                        /'

say "# heads it, >#  (my #82) bodies it — a wiki glossary entry / flashcard from any concept-mention. (#x? gives a topical yes/no, not 'what is X?'.)"
