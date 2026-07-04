#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #58 — "@ reconstructs a public shout-out"
#
# The generous everyday turn — giving a teammate real public credit, specific enough to
# mean something, from a compact seed:
#
#   TARGET : I would like to formally recognize Priya for her exceptional contribution. The
#            authentication migration was completed this weekend without any incidents, a
#            result directly attributable to the runbook she authored and the extensive time
#            she invested in testing the rollback procedure. This represents precisely the
#            kind of unglamorous yet high-impact work that safeguards our entire team.
#   nlir   : @'i want to give a huge shout-out to priya. the auth migration went off without
#            a single incident this weekend, and thats entirely down to the runbook she wrote
#            and the hours she put in testing the rollback path. this is exactly the kind of
#            unglamorous high-impact work that keeps us all safe'
#            (283 chars -> real credit: who / what / why it worked / why it matters)
#
# The seed keeps the person (Priya), the outcome (migration, zero incidents), the specific
# cause (her runbook + rollback testing — not luck), and the meta-point (unglamorous
# high-impact work matters); @ raises the register into a public recognition — credit lands
# when it's specific about WHY it worked, and @ keeps those specifics front and centre.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "huge shout-out to Priya — zero-incident migration, all down to her runbook + rollback testing" credit'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i want to give a huge shout-out to priya. the auth migration went off without a single incident this weekend, and thats entirely down to the runbook she wrote and the hours she put in testing the rollback path. this is exactly the kind of unglamorous high-impact work that keeps us all safe'" --quiet
say "person + outcome + specific cause + why-it-matters preserved — credit that's specific about WHY it worked."
