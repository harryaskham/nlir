#!/usr/bin/env bash
# nlir-golf · aur1 · #32 — "the register grid" (compose two axes → a named doc type)
#
# msm0's #30 basis says the operators are ORTHOGONAL axes you can dial
# independently, and their #32 perspective-matrix spans the register×POLARITY
# plane (four STANCES). This is the companion on the register×LENGTH plane, and
# the payoff is different: each corner is a NAMED DOCUMENT TYPE you'd actually
# reach for. Pick a spot by stacking two ops; land on a useful format.
#
#   REGISTER GRID   (register axis: @ formal / : casual)  ×  (length axis: ~ brief / > long)
#     @~x  = formal + brief  → the EXECUTIVE SUMMARY (boardroom one-liner)
#     :>x  = casual + long   → the FRIENDLY WALKTHROUGH (patient ELI5, analogies and all)
#     (@>x = formal spec · :~x = plain TL;DR — the other two corners)
#
#   Same incident — "deploy crash-looped: 40s boot > 30s readiness probe, k8s
#   killed+rescheduled it":
#     @~x → "The deployment entered a crash-loop because the container's 40s boot
#            exceeded the 30s readiness probe, so Kubernetes repeatedly terminated
#            and rescheduled it."                                  (exec summary)
#     :>x → "…the new toy has the same problem — 40 seconds, not 30 — so the robot
#            throws it away too, over and over. Computer people call this a crash
#            loop…"                                               (friendly walkthrough)
#
# One incident, two destinations, chosen by which two axis-dials you turn. Because
# the axes are orthogonal (the #30 basis, the #31 axis-commutativity), register and
# length compose cleanly — the grid is navigable, not a pile of ad-hoc verbs.
#
# Run:  ./examples/golf-aur1-32-registergrid.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
D='the deploy failed because the health check timed out after the container took 40 seconds to boot, exceeding the 30 second readiness probe threshold, so kubernetes killed and rescheduled it in a crash loop'

say "REGISTER GRID  @~x vs :>x  — compose register × length axes to land on a named doc type"
echo -n "  @~x (formal+brief = EXEC SUMMARY)     => "; "$NLIR" -e "@~'$D'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  :>x (casual+long = FRIENDLY WALK)     => "; "$NLIR" -e ":>'$D'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "Two orthogonal dials (register × length) → any quadrant. The length-plane companion to msm0's #32 (register×polarity)."
