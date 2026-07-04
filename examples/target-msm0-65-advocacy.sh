#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #65 — "@ reconstructs a user-advocacy pushback"
#
# The turn that protects users from a short-sighted business call — arguing for the customer
# with a concrete risk, from a compact seed:
#
#   TARGET : I would like to raise an objection to charging for the export feature. While I
#            understand the revenue rationale, export functionality is the mechanism by which
#            users retrieve their own data — placing it behind a paywall risks the perception of
#            holding customer data hostage, and is precisely the type of decision that tends to
#            generate negative public criticism. Could we consider keeping a basic CSV export
#            available at no cost?
#   nlir   : @'i want to push back on charging for the export feature. i get the revenue
#            argument, but export is how users get their data OUT — putting it behind a paywall
#            feels like holding their own data hostage, and its exactly the kind of thing that
#            shows up in angry blog posts. can we at least keep a basic csv export free?'
#            (321 chars -> a user-advocacy case: the objection / the steelman / the risk / the ask)
#
# The seed keeps the objection (don't charge for export), the steelman (I get the revenue
# argument), the core reason (export = users' own data, paywall = hostage-taking, PR risk), and
# the compromise ask (keep basic CSV free); @ raises the register while keeping the edge — user
# advocacy lands when it names the concrete risk, and @ keeps that risk sharp.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "don'\''t paywall export — it'\''s users'\'' own data, that'\''s hostage-taking + a PR risk; keep basic CSV free" pushback'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i want to push back on charging for the export feature. i get the revenue argument, but export is how users get their data OUT — putting it behind a paywall feels like holding their own data hostage, and its exactly the kind of thing that shows up in angry blog posts. can we at least keep a basic csv export free?'" --quiet
say "objection + steelman + concrete risk + compromise ask preserved — advocacy that names the risk."
