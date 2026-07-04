#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #56 — "@ reconstructs a wellbeing / capacity flag"
#
# A sensitive, important turn — flagging you're running low before it becomes a crisis,
# honestly but without drama, from a compact seed:
#
#   TARGET : I would like to be candid that I have been operating at capacity over the past
#            several weeks. The combination of on-call responsibilities and the ongoing
#            migration has been unrelenting, and I have not had a genuine opportunity to
#            rest. I am not seeking to offload my responsibilities entirely, but I would
#            appreciate assistance in redistributing some of the workload before it leads to
#            burnout.
#   nlir   : @'i want to be honest that ive been running on empty the last few weeks. the
#            on-call load on top of the migration has been relentless and i havent had a real
#            break. im not looking to drop anything, but i could use help redistributing some
#            of it before i burn out for real'
#            (264 chars -> a candid flag: the state / the cause / the boundary / the ask)
#
# The seed keeps the honest state (running on empty), the cause (on-call + migration, no
# break), the reassurance (not looking to drop anything), and the ask (help redistributing
# before burnout); @ raises the register while keeping the vulnerability measured — a
# wellbeing flag lands when it's honest and specific, not when it's polished into a
# non-statement, and @ holds that line.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: an "I have been running on empty — on-call plus the migration — help redistributing before burnout" flag'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i want to be honest that ive been running on empty the last few weeks. the on-call load on top of the migration has been relentless and i havent had a real break. im not looking to drop anything, but i could use help redistributing some of it before i burn out for real'" --quiet
say "state + cause + boundary + ask preserved — a wellbeing flag that's honest and specific, not polished away."
