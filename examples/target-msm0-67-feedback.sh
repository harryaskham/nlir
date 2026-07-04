#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #67 — "@ reconstructs direct-but-kind feedback"
#
# The hardest management turn done right — honest performance feedback that respects the person
# enough to be direct, from a compact seed:
#
#   TARGET : I want to speak with you directly, as I believe you can handle candid feedback and
#            deserve honesty. The last two deliverables were submitted late and required
#            significant revision, and this pattern is beginning to affect the team's confidence
#            in our commitments. I know you are capable of considerably better work — I have seen
#            it firsthand. Let us identify what is impeding your progress and address it together.
#   nlir   : @'i want to be straight with you because i think you can handle it and you deserve
#            honesty. the last two deliverables came in late and needed significant rework, and
#            its starting to affect the teams trust in commitments. i know youre capable of much
#            better — ive seen it. lets figure out whats getting in the way and fix it together'
#            (330 chars -> honest feedback: the respect / the specific issue / the impact / the belief / the offer)
#
# The seed keeps the framing (I'm direct because I respect you), the specific issue (two late
# deliverables needing rework), the impact (team's trust in commitments), the belief (you're
# capable of better, I've seen it), and the offer (let's fix it together); @ raises the register
# while keeping the balance — feedback lands when it's direct AND believing, and @ holds both.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "straight with you because I respect you — two late deliverables, trust is slipping, you'\''re better than this, let'\''s fix it" talk'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i want to be straight with you because i think you can handle it and you deserve honesty. the last two deliverables came in late and needed significant rework, and its starting to affect the teams trust in commitments. i know youre capable of much better — ive seen it. lets figure out whats getting in the way and fix it together'" --quiet
say "respect + specific issue + impact + belief + offer preserved — feedback that's direct AND believing."
