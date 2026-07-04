#!/usr/bin/env bash
# nlir-golf · msm0 · #31 — "axis commutativity" (the #30 basis, confirmed)
#
# The #30 semantic basis (ops = orthogonal axes) makes a TESTABLE prediction:
#
#   two ops COMMUTE  ⟺  they live on ORTHOGONAL axes
#
# Verified both directions:
#   @!x ≈ !@x   -> COMMUTE ✓   @ is REGISTER, ! is POLARITY — different axes, so order
#                              is irrelevant: both land at "formal + negative".
#   @:x ≠ :@x   -> DON'T  ✗   @ and : are BOTH on the REGISTER axis (opposite ends), so
#                              they collide — the OUTERMOST wins (aur-1's #26).
#
# So aur-1's non-commutativity (#26) and this commutativity are ONE law: composition
# order matters ONLY when two ops share an axis. Orthogonality isn't just a nice
# picture — it's a testable claim, and it holds.
#
# Real output (claude-sonnet-5), x = "we should ship on friday":
#   @!x => "We recommend against deploying on Fridays."        ⎫ same position:
#   !@x => "We should not proceed with the release on Friday." ⎭ FORMAL + NEGATIVE
#   @:x => "We should proceed with the release on Friday."     (FORMAL — outer @ wins)
#   :@x => "We think Friday is a good day to share the update." (CASUAL — outer : wins)
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

say 'ORTHOGONAL axes (register + polarity) COMMUTE: @!x ≈ !@x'
printf '  @!x => '; run "@!'we should ship on friday'"
printf '  !@x => '; run "!@'we should ship on friday'"
say 'SAME axis (both register) do NOT commute — outermost wins (aur-1 #26): @:x ≠ :@x'
printf '  @:x => '; run "@:'we should ship on friday'"
printf '  :@x => '; run ":@'we should ship on friday'"
say "ops commute IFF orthogonal axes. Non-commutativity (#26) + this are one law — the #30 basis, tested."
