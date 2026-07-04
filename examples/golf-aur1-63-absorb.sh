#!/usr/bin/env bash
# nlir-golf · aur1 · #63 — "the absorption law" (~ swallows a prior @ :  ~@x ≈ ~x)
#
# An algebra find in the composition strand. msm0's basis (#30) says ~ moves the INFO axis
# and COLLAPSES the register axis. So if you formalise first and summarise second, the
# summary throws the register work away — it comes out at the summary's own register,
# carrying the same facts at the same length as if the @ were never there. In short:
#
#     ~@x  ≈  ~x        (~ collapses register, so a prior @ is nearly a no-op)
#
#   claim "the quarterly numbers came in soft because two enterprise deals slipped into
#          next quarter, but the pipeline is actually healthier than it looks"
#     ~x  → "Quarterly numbers were soft due to slipped enterprise deals, but the
#            pipeline remains healthy."
#     ~@x → "Quarterly results missed expectations due to deferred deals, but the
#            pipeline remains strong."
#
# Same two facts, same length — only a faint formal word-choice ("results missed
# expectations" vs "numbers were soft") survives the collapse. This is the composition
# twin of my #36 (`?` absorbs a prior `!`: `!x? ≈ x?`): there the QUESTION projection
# swallows polarity, here the SUMMARY collapse swallows register. An operator that flattens
# an axis erases any earlier work done on that same axis.
#
# Run:  ./examples/golf-aur1-63-absorb.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='the quarterly numbers came in soft because two enterprise deals slipped into next quarter, but the pipeline is actually healthier than it looks'

say "ABSORPTION LAW  ~@x ≈ ~x  — ~ collapses register, so a prior @ is nearly a no-op"
echo   "  claim: $C"
echo -n "  ~x  (gist)          => "; "$NLIR" -e "~'$C'"  --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  ~@x (gist of formal) => "; "$NLIR" -e "~@'$C'" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "≈ equal (same facts, same length; only a faint formal word-choice survives). Twin of #36: an axis-flattener erases prior work on that axis."
