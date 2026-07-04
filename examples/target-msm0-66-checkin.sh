#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #66 — "@ reconstructs a peer check-in"
#
# The quietly important turn — noticing a teammate is struggling and reaching out with care and
# zero pressure, from a compact seed:
#
#   TARGET : I've noticed that you've seemed quite stretched over the past couple of weeks —
#            you've been quieter in standups, and a few things have slipped that normally
#            wouldn't. This isn't a criticism; I simply wanted to check in, see how you're doing,
#            and find out whether there's anything I can take off your plate. Please don't feel
#            any pressure to discuss this if you'd prefer not to.
#   nlir   : @'hey, ive noticed youve seemed pretty stretched the last couple weeks — quieter in
#            standups, and a few things slipping that normally wouldnt. no judgment at all, i just
#            wanted to check in and see how youre doing, and whether theres anything i can take off
#            your plate. genuinely no pressure to get into it if youd rather not'
#            (327 chars -> a caring check-in: the observation / the no-judgment / the offer / the out)
#
# The seed keeps the gentle observation (stretched, quieter, things slipping), the reassurance
# (no judgment), the offer (anything I can take off your plate), and the out (no pressure to talk);
# @ raises the register while keeping the warmth — a check-in lands when it's caring AND gives an
# easy exit, and @ preserves both the care and the no-pressure.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "you'\''ve seemed stretched — no judgment, can I take anything off your plate, no pressure to talk" check-in'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'hey, ive noticed youve seemed pretty stretched the last couple weeks — quieter in standups, and a few things slipping that normally wouldnt. no judgment at all, i just wanted to check in and see how youre doing, and whether theres anything i can take off your plate. genuinely no pressure to get into it if youd rather not'" --quiet
say "observation + no-judgment + offer + easy out preserved — a check-in that's caring and low-pressure."
