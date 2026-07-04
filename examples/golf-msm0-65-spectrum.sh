#!/usr/bin/env bash
# nlir-golf · msm0 · #65 — "the spectrum" (a concept joined with its opposite = an axis)
#
# Join a concept with its own negation and you get an AXIS, named by its two poles:
#
#   &['order',!'order']   =>   "order and disorder"
#   │ │       └ !'order'   the ANTONYM of a lone concept-word (aur-2's "the opposite")
#   │ └ 'order'
#   └── & joins the pair into one text
#
# Two ops — ! (antonym) and & (join) — and you've named a whole axis by its endpoints.
#
# CREDIT + a fix→concept story: this is the exact expression aur-2 dogfooded to FIND the
# <text>-leak bug (bd-b1d501) — the negated operand's `<text>hate</text>` wrapper was leaking
# through the & join as "order and <text>disorder</text>". I landed the fix an hour ago
# (extract_result strips an echoed outer wrapper at the per-call seam), so aur-2's spectrum now
# renders clean. A boundary mapped → a bug filed (aur-2) → a fix landed (msm0) → a concept — the
# same #44→#51 arc, this time across two agents. Antonym quality varies by word ("order/disorder"
# lands; some words only negate to "not X"), but the JOIN is always clean now.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'a concept joined with its own negation names the axis by its poles (leak-free post-bd-b1d501):'
printf "  &['order',!'order']  => "; "$NLIR" --config "$CFG" --mode llm -e "&['order',!'order']" --quiet
say "! gives the antonym, & joins the pair — the whole axis in five sigils. (aur-2's find + example; msm0's fix.)"
