#!/usr/bin/env bash
# nlir-golf · msm0 · #66 — "the ladder" (one thought at three register rungs)
#
# The register axis (#30 basis) rendered as a graded LADDER — one message flexed up and down
# the formality scale, side by side. Assign the computed rungs, then interpolate them into a
# labelled, line-broken list:
#
#   x="we really need to ship this by friday"
#   p=:$x        # : simplify  -> the plainest rung
#   f=@$x        # @ formal    -> the most formal rung
#   _sep="\n"    # one rung per line
#   ["plain:  $p", "as-is:  $x", "formal: $f"]
#
#   =>  plain:  We need to finish this and send it out before Friday.
#       as-is:  we really need to ship this by friday
#       formal: This project requires completion by Friday.
#
# Pick your register at a glance. Five features threaded through one expression: assignment
# (p, f), prefix ops (: and @), reuse ($x three times, plus $p/$f), a list, and a custom _sep for
# line breaks. Where #32's matrix was a 2-D grid (register × length), this is the register axis
# alone, read as a ladder.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE LADDER   x="…" ; p=:$x ; f=@$x ; _sep="\n" ; ["plain:  $p","as-is:  $x","formal: $f"]'
"$NLIR" --config "$CFG" --mode llm -e 'x="we really need to ship this by friday";p=:$x;f=@$x;_sep="\n";["plain:  $p","as-is:  $x","formal: $f"]' --quiet
say "one thought, three register rungs — assignment + : /@ + reuse + list + _sep, all in one line."
