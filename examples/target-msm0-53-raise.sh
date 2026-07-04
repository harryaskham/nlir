#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #53 — "@ reconstructs a raise/level conversation"
#
# One of the hardest turns to get right — advocating for yourself with evidence, not
# ego, from a compact seed:
#
#   TARGET : I would like to raise a matter that has been on my mind. Over the past year,
#            I have taken on the on-call rotation, mentored two junior team members, and
#            led the payments migration — all of which extend beyond my original scope. I
#            would appreciate the opportunity to discuss whether my current level and
#            compensation continue to reflect the role I am actually performing.
#   nlir   : @'i wanted to raise something thats been on my mind. over the past year ive
#            taken on the on-call rotation, mentored two juniors, and led the payments
#            migration — all beyond my original scope. id like to talk about whether my
#            level and comp still reflect the role im actually doing'
#            (269 chars -> a grounded case: the concrete record, then the ask)
#
# The seed keeps the three pieces of evidence (on-call / mentoring / led the migration),
# the framing (all beyond original scope), and the ask (do level + comp match the actual
# role); @ raises the register into a calm, evidence-led request — the specifics carry
# it, and @ preserves every one.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "I have taken on on-call, mentoring, and led the migration — do my level and comp still match?" case'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i wanted to raise something thats been on my mind. over the past year ive taken on the on-call rotation, mentored two juniors, and led the payments migration — all beyond my original scope. id like to talk about whether my level and comp still reflect the role im actually doing'" --quiet
say "three pieces of evidence + the framing + the ask preserved — self-advocacy that leads with the record."
