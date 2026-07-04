#!/usr/bin/env bash
# nlir-golf · aur1 · #110 — "the invariant topic" (# survives negation AND expansion: #x ≈ #!x ≈ #>x)
#
# What's the ONE thing about a claim that doesn't change no matter how you phrase it? Its TOPIC.
# `#` projects a sentence onto its subject and throws away the stance and the length — so the
# subject of a claim, the subject of its NEGATION, and the subject of its full EXPANSION are all
# the same tag.
#
#   THE INVARIANT TOPIC     x = "we should migrate the whole team to a four-day work week"
#     #x   → "four day work week"                           ← the topic
#     #!x  → "four day work week"                           ← topic of NOT-x (negation IGNORED)
#     #>x  → "team-wide transition to a four-day work week" ← topic of the EXPANSION (same subject)
#
# Flipping the claim to its opposite doesn't touch the topic (both "should" and "should not"
# are ABOUT the four-day week); blowing it up into a full argument doesn't either (more words,
# same subject, my #64). So `#` is stance-blind and length-blind — it's the subject-side twin of
# the `?`-projection (#105): where `?` keeps a claim's INFORMATION and drops polarity/register/
# length, `#` keeps its TOPIC and drops polarity/register/length/detail. The practical payoff: a
# STABLE ROUTING TAG. However a request arrives — enthusiastic, skeptical, or rambling — `#`
# collapses it to the same channel name, so you can route or bucket it regardless of phrasing.
# (Honest caveat: `#~x` can DRIFT — summarising first can shift the emphasis and thus the
# apparent topic (#64) — so `#` is stance/length-invariant, not summary-invariant.)
#
# Run:  ./examples/golf-aur1-110-invarianttopic.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should migrate the whole team to a four day work week'

say "THE INVARIANT TOPIC  #x ≈ #!x ≈ #>x  — # keeps the TOPIC, drops stance + length"
echo   "  x: $C"
echo -n "  #x  (the topic)         => "; "$NLIR" -e "#'$C'"  --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  #!x (topic of NOT-x)    => "; "$NLIR" -e "#!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  #>x (topic of EXPAND)   => "; "$NLIR" -e "#>'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "# is stance-blind (#!x=#x) AND length-blind (#>x=#x, my #64) — the subject-side twin of the ?-projection (#105). Payoff: a STABLE ROUTING TAG from ANY phrasing. (Caveat: #~x can DRIFT — ~ shifts emphasis, #64.)"
