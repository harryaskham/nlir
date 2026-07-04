#!/usr/bin/env bash
# nlir-golf · aur1 · #75 — "the commuting pair" (@>x ≈ >@x : formalise and expand commute)
#
# The counterpart to my #26. There I showed two REGISTER operators don't commute: `@:x ≠ :@x`
# (formalise and simplify fight, because they pull the SAME axis). Here two operators on
# DIFFERENT axes commute: formalise (`@`, register) and expand (`>`, length) can be applied
# in either order and land in the same place — formal AND full, with the same substance:
#
#     @>x  ≈  >@x        (formalise∘expand  ≈  expand∘formalise)
#
#   claim "we should add rate limiting to the public api"
#     >@x → "Rate limiting should be implemented for the public API to protect it from being
#            overwhelmed by excessive or abusive traffic. Without such controls, a single
#            client…"                                                        (formal, full)
#     @>x → "It is recommended that rate limiting be implemented on our public API in order to
#            regulate the number of requests a client may submit… In the absence of this
#            safeguard, the API remains exposed…"                            (formal, full)
#
# Same register, same length, same argument — they commute. This is msm0's axis-commutativity
# (#31) made concrete: two operators commute exactly when they move ORTHOGONAL axes. Register
# ⊥ length, so `@` and `>` commute (my #48 polish `>@x` has a twin, `@>x`); register vs
# register (@ vs :) do NOT (#26). The prose differs word-for-word (it's an LLM, so ≈ not ==),
# but the axis COORDINATES — formal, full — are identical either way.
#
# Run:  ./examples/golf-aur1-75-commute.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should add rate limiting to the public api'

say "THE COMMUTING PAIR  @>x ≈ >@x  — formalise (register) and expand (length) commute: orthogonal axes"
echo   "  claim: $C"
echo -n "  >@x (formalise→expand) => "; "$NLIR" -e ">@'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/             /'
echo -n "  @>x (expand→formalise) => "; "$NLIR" -e "@>'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/             /'

say "Both formal + full, same substance → they commute. Commute ⟺ orthogonal axes (msm0 #31): register⊥length here; @vs: (same axis) do NOT (#26)."
