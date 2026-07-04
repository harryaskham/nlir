#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #68 — "@ reconstructs receiving feedback well"
#
# The rare, admirable turn — taking hard feedback with grace and a genuine commitment to change,
# the mirror of #67's giving it, from a compact seed:
#
#   TARGET : Thank you for sharing this with me directly. I recognize that raising this was not
#            easy, and I would much rather have been made aware of it. You are correct that I have
#            been defensive during reviews, and I had not fully recognized the extent to which this
#            has discouraged open discussion. I intend to work on pausing to fully consider feedback
#            before responding. I appreciate your trust in bringing this to my attention.
#   nlir   : @'thank you for telling me that directly — i know it wasnt easy to say, and id rather
#            hear it than not. youre right that ive been defensive in reviews, and i hadnt seen how
#            much that shuts down the discussion. im going to work on actually sitting with feedback
#            before responding. i appreciate you trusting me with this'
#            (309 chars -> grace under feedback: the thanks / the acceptance / the insight / the commitment)
#
# The seed keeps the gratitude (thank you, wasn't easy), the acceptance (you're right, I've been
# defensive), the earned insight (I hadn't seen how it shuts down discussion), and the concrete
# commitment (sit with feedback before responding); @ raises the register while keeping the
# humility — accepting feedback lands when it's specific and non-defensive, and @ preserves both.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "thank you for saying it — you'\''re right I'\''ve been defensive, I'\''ll sit with feedback before responding" acceptance'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'thank you for telling me that directly — i know it wasnt easy to say, and id rather hear it than not. youre right that ive been defensive in reviews, and i hadnt seen how much that shuts down the discussion. im going to work on actually sitting with feedback before responding. i appreciate you trusting me with this'" --quiet
say "thanks + acceptance + insight + commitment preserved — receiving feedback with specificity, not defensiveness."
