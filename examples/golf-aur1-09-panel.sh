#!/usr/bin/env bash
# nlir-golf · aur1 · #09 — "the panel"
#
# Hand ONE claim to three different operators, then summarise the bundle: you get
# a balanced verdict that has already heard the formal case, the objection, and
# the plain reading — a one-line panel discussion of your own statement.
#
#   PANEL   ~[@c , !c , :c]     (summarise a list of three takes on c)
#     @c  the formal, professional case          (the advocate)
#     !c  the negation / objection               (the skeptic)
#     :c  the plain-language reading              (the layperson)
#     ~   distil all three into the balanced position
#
# Same seed enters three ways; the summariser weighs them and reports where the
# debate actually sits ("opinions are split, though…"). It's the roundtable
# cousin of #07's consensus (which took INDEPENDENT opinions) — here the three
# views are all DERIVED from one claim by different operators.
#
# Run:  ./examples/golf-aur1-09-panel.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should require code review for every merge'

say "PANEL  ~[@c , !c , :c]  — advocate, skeptic, layperson takes on ONE claim, then a verdict"
echo "  claim: $C"
echo -n "  verdict => "
"$NLIR" -e "~[@'$C',!'$C',:'$C']" --quiet

say "Three operators, one claim, one balanced line — the derived-views cousin of #07 consensus."
