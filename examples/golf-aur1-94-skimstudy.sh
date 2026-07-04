#!/usr/bin/env bash
# nlir-golf · aur1 · #94 — "the skim-or-study" (the one-liner and the focused deep-dive, [~x, >~x])
#
# Two readers, one source. `[~x, >~x]` serves both: `~x` is the SKIM — a single line for the
# person who just needs the gist — and `>~x` is the STUDY — a full treatment for the person who
# wants the depth. The trick is that BOTH derive from the same essence (`~`): `>~x` doesn't
# elaborate everything in the input, it distils to the core FIRST and then expands THAT, so the
# deep-dive stays on-point instead of sprawling.
#
#   THE SKIM-OR-STUDY   [ ~x , >~x ]
#     x = a rambling incident-culture complaint (alerts unwatched, no on-call owner, festering)
#     ~x  → "Incident response is slow because alerts go unmonitored and there's no clear
#            on-call owner, so issues fester until customers complain."          ← the SKIM
#     >~x → "Incident response is significantly slower than it should be, and this stems from
#            two compounding structural problems. First, alerts are routed to a channel nobody
#            watches… Second, with no named on-call owner…"                       ← the STUDY
#
# The `>~x` half organised itself around the CORE — the two structural causes — rather than
# re-narrating every phrase. That's the difference from my #44 BLUF (`[~x, >x]`): there the
# second half is `>x`, which expands the WHOLE input (everything, in order); here it's `>~x`,
# which expands the DISTILLED core (the point, in depth). Skim the top line, or study the
# focused body — same idea, two altitudes, and the body never wanders.
#
# Run:  ./examples/golf-aur1-94-skimstudy.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='our incident response is slow because alerts go to a channel nobody watches and theres no clear on-call owner, so problems fester until a customer complains'

say "THE SKIM-OR-STUDY  [~x, >~x]  — the SKIM (~x, one line) + the STUDY (>~x, a focused deep-dive)"
echo   "  x: $C"
echo -n "  ~x  (the SKIM)  => "; "$NLIR" -e "~'$C'"  --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  >~x (the STUDY) => "; "$NLIR" -e ">~'$C'" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say ">~x expands the DISTILLED core (stays on-point), vs #44 BLUF's >x which expands the WHOLE input. Skim the line, or study the focused body."
