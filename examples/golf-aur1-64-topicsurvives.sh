#!/usr/bin/env bash
# nlir-golf · aur1 · #64 — "the topic survives expansion" (#>x ≈ #x, but #~x can drift)
#
# A follow-on to #63's absorption law, and it comes with an honest twist. msm0's basis says
# `#` (subject) reads the topic and COLLAPSES the length axis — so you'd expect `#` to absorb
# ANY prior length op. It half-does. Expanding a claim doesn't move its topic:
#
#     #>x  ≈  #x        (the subject of a claim = the subject of its full elaboration)
#
# because `>` is emphasis-PRESERVING: it adds detail around the same center. But `~` is
# emphasis-SHIFTING — it concentrates on the crux and can foreground a sub-point — so `#`
# then names THAT, and `#~x` can DRIFT away from `#x`:
#
#   claim "our onboarding flow has a 40% drop-off at the email verification step, mostly on
#          mobile, and we think an SMS fallback would fix it"
#     #x  → "Email verification drop-off in onboarding"        ┐ same topic —
#     #>x → "Onboarding email verification drop-off"           ┘ > preserved the center
#     #~x → "SMS fallback for email verification"     ← DRIFTED: ~ foregrounded the fix
#
# So the absorption family caps out cleanly only for the emphasis-preserving length op:
# `#` absorbs `>` (topic is expansion-invariant), but not `~` (summary can re-aim it). The
# real find is the asymmetry — > elaborates, ~ editorialises.
#
# Run:  ./examples/golf-aur1-64-topicsurvives.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='our onboarding flow has a forty percent drop-off at the email verification step, mostly on mobile, and we think an sms fallback would fix it'

say "#>x ≈ #x (topic survives expansion), but #~x can DRIFT — > preserves emphasis, ~ shifts it"
echo   "  claim: $C"
echo -n "  #x   (topic)          => "; "$NLIR" -e "#'$C'"  --quiet
echo -n "  #>x  (topic of essay) => "; "$NLIR" -e "#>'$C'" --quiet
echo -n "  #~x  (topic of gist)  => "; "$NLIR" -e "#~'$C'" --quiet

say "# absorbs > (expansion-invariant topic) but not ~ (summary re-aims emphasis). The asymmetry: > elaborates, ~ editorialises."
