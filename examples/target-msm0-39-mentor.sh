#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #39 — "@ reconstructs a note of thanks to a mentor"
#
# A heartfelt everyday turn — thanking someone for a year of mentorship, specifically,
# from a compact seed:
#
#   TARGET : I wanted to express my sincere gratitude for your mentorship throughout
#            this year. Your code reviews, in particular your willingness to explain
#            the reasoning behind your suggestions, taught me more than any course
#            could have. I am a genuinely better engineer as a result.
#   nlir   : @'just wanted to thank you for all the mentorship this year. the code
#            reviews where u explained the why behind your suggestions taught me more
#            than any course could, and im a genuinely better engineer for it'
#            (203 chars -> a sincere, specific note of thanks)
#
# The seed keeps the WHAT (mentorship / code reviews), the WHY-it-mattered (explaining
# the reasoning), and the impact (a better engineer); @ raises the register but keeps
# the sincerity — a thank-you that names specifics is the only kind that lands.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "thank you for the mentorship — the code reviews taught me more than any course" note'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'just wanted to thank you for all the mentorship this year. the code reviews where u explained the why behind your suggestions taught me more than any course could, and im a genuinely better engineer for it'" --quiet
say "specific gratitude + the impact preserved — the kind of thanks that actually lands."
