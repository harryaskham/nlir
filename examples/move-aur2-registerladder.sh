#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the register ladder": one announcement, all THREE channels at once — a
# terse status line, a plain-language note, and a formal write-up. Write the facts once, post everywhere.
#
# THE MOVE (reusable):
#     [ ~&[ FACTS ] , :&[ FACTS ] , @&[ FACTS ] ]
#       └ terse         └ warm/plain      └ formal
#     └───────────── a 3-element list: the same facts in all three registers
#
# nlir prints three renderings, one per line:
#   ~&[...]  the Slack/standup one-liner (distilled, just the signal)
#   :&[...]  the friendly DM / customer note (jargon rewritten into plain words)
#   @&[...]  the formal email / changelog entry (polished, keeps the technical terms)
#
# THE CAPSTONE of the tone-list family: dual-register brief splits by WHO reads (@ vs :);
# the BLUF splits by HOW MUCH they read (~ vs @); the register ladder gives the WHOLE tone trio at
# once — the three surfaces you'd otherwise write three times. The leading op is the channel dial.
#
# Filled example (FACTS repeated in each slot):
#   [~&['db migration tonight','~30min read-only window','rollback ready'],
#    :&['db migration tonight','~30min read-only window','rollback ready'],
#    @&['db migration tonight','~30min read-only window','rollback ready']]
#
# Real output (claude-sonnet-5), three lines:
#   [terse]  "Database migration tonight includes a ~30-minute read-only window, with rollback prepared."
#   [plain]  "Tonight we're going to update the database. While we do this, for about 30 minutes, people
#            will only be able to look at things, not change them. And if something goes wrong, we have a
#            plan ready to undo it and go back to how things were."
#   [formal] "A database migration is scheduled for tonight. There will be an approximately 30-minute
#            read-only window, and a rollback plan is ready in case it is needed."
#
# REUSE IT:  [~&[<facts>], :&[<same facts>], @&[<same facts>]]   (drop a rung for any two channels)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

FACTS="'db migration tonight','~30min read-only window','rollback ready'"
EXPR="[~&[$FACTS],:&[$FACTS],@&[$FACTS]]"

echo "move:       the register ladder -- [~&[F], :&[F], @&[F]]  (line 1 = terse, line 2 = plain, line 3 = formal)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
