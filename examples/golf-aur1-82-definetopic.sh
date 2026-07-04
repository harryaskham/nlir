#!/usr/bin/env bash
# nlir-golf · aur1 · #82 — "define the topic" (>#x : from a sentence USING a concept to one ABOUT it)
#
# A pivot in two sigils. `#x` pulls the SUBJECT out of a sentence — the concept it's really
# about — and `>` then expands THAT into a full explanation. So a message that merely USES a
# concept (often while complaining about it) becomes a clear write-up OF the concept itself:
#
#   DEFINE THE TOPIC   > # x
#     x "our closures keep capturing the loop variable and every callback ends up seeing the
#        last value"                                                     (a symptom, in passing)
#     #x  → "Closure capturing the loop variable"                        ← the CONCEPT named
#     >#x → "Closures capturing the loop variable refers to a common, surprising pitfall—
#            especially in JavaScript—where a function defined inside a loop shares a single
#            reference to the loop's control variable instead of the value it held each
#            iteration, so every closure ends up seeing the final value…"  ← the CONCEPT explained
#
# The order is the whole trick. `#` runs FIRST and collapses the sentence to its topic (a
# noun phrase), discarding the specific complaint; `>` runs SECOND and elaborates that topic
# into a definition. Contrast my #55 deep-dive (`>~x`), which expands the CONTENT of what was
# said — this expands the SUBJECT of it. One deepens the message; this looks up the idea
# behind the message. Perfect for turning "X is broken again" into "here's what X actually is."
#
# Run:  ./examples/golf-aur1-82-definetopic.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='our closures keep capturing the loop variable and every callback ends up seeing the last value'

say "DEFINE THE TOPIC  >#x  — # names the SUBJECT of a sentence, > expands THAT into an explanation"
echo   "  x: $C"
echo -n "  #x  (the concept)       => "; "$NLIR" -e "#'$C'"  --quiet | fold -s -w 80 | sed '2,$s/^/                            /'
echo -n "  >#x (the concept, explained) => "; "$NLIR" -e ">#'$C'" --quiet | fold -s -w 78 | sed '2,$s/^/                            /'

say "# FIRST collapses to the topic (drops the complaint); > SECOND defines it. vs #55 deep-dive >~x (expands the CONTENT); this expands the SUBJECT."
