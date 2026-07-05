#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the graceful decline": say no while keeping the relationship — the
# honest can't, the real why, and the door you leave open. Warm, not formal (that's the `:` tone).
#
# THE MOVE (reusable):
#     : & [ "I_CANT_DO_X" , "THE_HONEST_WHY" , "BUT_HERES_WHAT_I_CAN" ]
#       :&[…] = warm/plain tone + weave     (: keeps it human, not a cold corporate "no")
#     └──────── the decline, the reason, the alternative — one kind, clear message
#
# A good "no" has three parts: it's clear, it's honest about why, and it offers a path forward. The
# `:` leading tone makes it WARM (formal `@` would sound like an HR rejection); the weave braids all
# three so you decline without stinging. Distinct from the descope (which trims a PROJECT's scope).
#
# Filled example:
#   :&["I cannot take on the security audit this sprint",
#      "my plate is full with the release",
#      "but I can review your threat model doc on Thursday"]
#
# Real output (claude-sonnet-5):
#   "I can't do the whole security check this sprint because I'm busy getting the release ready. But I
#    can look at your threat model paper on Thursday."
#
# REUSE IT:  :&["<the no>", "<the honest reason>", "<the alternative you CAN offer>"]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

echo "move:       the graceful decline -- :&[\"CANT_DO_X\", \"HONEST_WHY\", \"WHAT_I_CAN_DO\"]  (a kind no)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm \
  -e ':&["I cannot take on the security audit this sprint","my plate is full with the release","but I can review your threat model doc on Thursday"]'
