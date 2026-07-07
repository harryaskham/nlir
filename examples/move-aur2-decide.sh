#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the fuzzy decision": classify a situation semantically,
# then route on it deterministically — det + fuzzy in ONE terse expression.
#
# WHY THIS IS nlir, not a prompt (sgu24-app's test): a plain LLM can give you a
# judgment OR you can hard-code a branch, but nlir does BOTH in one line — the
# FUZZY classification (~>) decides the DET branch ($if). The judgment is internal;
# the output is the exact action. You can't tell a model "classify this AND return
# only one of these two exact tokens, deterministically" as cleanly.
#
# THE MOVE (reusable — learn the shape, fill the slots):
#     $if%( '<SITUATION>' ~> '<CATEGORY>' , '<ACTION_IF>' , '<ACTION_ELSE>' )
#     │        │            │                 └ the two exact outcomes (det branch)
#     │        │            └ ~> = FUZZY: does the situation imply the category?
#     │        └ the thing to judge (a chat line, a $_stdin, a literal)
#     └ $if = DET branch on the fuzzy verdict
#
# Filled example:
#   $if%('the server keeps crashing'~>'urgent','escalate','queue')
#
# Real output (claude-sonnet-5, llm mode):
#   escalate
#
# Run the SAME expression in --mode det and it prints `queue` instead — because
# the det stub for ~> is exact keyword-match ("the server keeps crashing" has no
# literal "urgent"), while llm mode judges it semantically (crashing IS urgent).
# Same ~40 chars, and the difference between "queue" and "escalate" IS the fuzzy
# ~>. That is the whole point — a keyword grep can't see "crashing => urgent".
#
# The value: `~>` reaches a semantic verdict ("crashing" implies "urgent") and
# `$if` turns it into a CLEAN, exact action — no preamble, no essay, just the
# routed token. Swap the situation for `^_-1` (their last message) or `$_stdin`
# and it's a live triage in a few sigils. Compose it: the same shape scales to a
# list with $map/$fold (that's the pipe family) — this is the single-item, terse,
# talk-to-an-agent version.
#
# REUSE IT:  $if%( <thing> ~> '<category>' , '<do-if>' , '<do-else>' )
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
# ~> / $if are config.example.yaml operators; default there so the move is
# self-contained. Override NLIR_CONFIG to point the fuzzy `~>` at your backend.
NLIR_CONFIG="${NLIR_CONFIG:-config.example.yaml}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
echo '{"_messages":[]}' > "$CTX"

EXPR="\$if%('the server keeps crashing'~>'urgent','escalate','queue')"

echo "move:       the fuzzy decision -- \$if%('SITUATION'~>'CATEGORY','do-if','do-else')"
echo "why nlir:   FUZZY classify (~>) drives a DET branch (\$if) in one line — a clean routed token, not an essay"
echo "---"
"$NLIR" --config "$NLIR_CONFIG" --context-file "$CTX" --mode llm -e "$EXPR"
