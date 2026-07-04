#!/usr/bin/env bash
# nlir-golf · msm0 · #25 — "De Morgan" (a logic law the LLM only HALF-respects)
#
# aur-1 showed !!x ≈ x (involution holds). Do nlir's !, &, | obey the OTHER classic
# negation law — De Morgan? Tested both directions; the result is a genuine finding:
#
#   OR  form:  !(a|b) ≈ !a & !b     ->  HOLDS   ✓
#   AND form:  !(a&b) ≈ !a | !b     ->  FAILS   ✗
#
# Why the asymmetry: "not (A and B)" is classically "!a OR !b" (at least one false),
# but the LLM reads it as "neither A nor B" = "!a AND !b" (BOTH false) — it
# over-negates, collapsing "not both" into "both false". Meanwhile "not (A or B)"
# = "neither...nor" is already natural English, so that direction lands correctly.
#
# So negation distributes faithfully over OR but NOT over AND — a boundary between
# classical logic and LLM interpretation. (Complements the operator-dynamics laws:
# ! involution, @ saturation, ~ intensification, and my assignment/range laws.)
#
# Real output (claude-sonnet-5):
#   !(A&B)   !('the tests pass'&'the build is green')
#     => "the tests don't pass AND the build is not green"     <- WRONG: that's !a&!b
#   !A|!B    !'the tests pass'|!'the build is green'
#     => "the tests don't pass OR the build is not green"      <- the CORRECT De Morgan RHS
#   !(A|B)   !('it compiles'|'it runs')
#     => "it neither compiles nor runs"                        == !A&!B: "doesn't compile
#        and doesn't run"                                      <- HOLDS
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { "$NLIR" --config "$CFG" --mode llm -e "$1" --quiet; }

say 'AND form (FAILS): !(a&b) should equal !a|!b'
printf '  !(A&B) => '; run "!('the tests pass'&'the build is green')"
printf '  !A|!B  => '; run "!'the tests pass'|!'the build is green'"
say 'OR form (HOLDS): !(a|b) should equal !a&!b'
printf '  !(A|B) => '; run "!('it compiles'|'it runs')"
printf '  !A&!B  => '; run "!'it compiles'&!'it runs'"
say 'negation distributes over OR but over-negates AND ("not both" -> "both false"). A logic/LLM boundary.'
