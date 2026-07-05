#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the fix-it": pipe an error or stack trace, get the likely FIX.
#
# THE MOVE (reusable, as a PIPE):
#     <the error> | nlir -e '~(>"the most likely fix for: $_stdin")'
#       $_stdin = the piped error   "...: $_stdin" = the error folded into a fix-instruction
#       >(...) = expand it into the fix   ~(...) = reined to one crisp, actionable paragraph
#
# aur-0's error-triage (`~$_stdin`) tells you WHAT went wrong; this is the next step — it derives
# HOW TO FIX it. Pipe a traceback straight from your terminal and get a concrete, actionable fix
# (the safe lookup, the missing check, the root cause to chase), reined to one paragraph.
#
# Filled example (a Python KeyError traceback piped in):
#   ... | nlir -e '~(>"the most likely fix for: $_stdin")'
#
# Real output (claude-sonnet-5):
#   "The `KeyError: 'session_id'` occurs because the code accesses `cache[session_id]` without
#    checking if the key exists, so the fix is to use a safe lookup (e.g., `cache.get()`) while also
#    verifying `session_id` is correctly populated upstream rather than accidentally holding the
#    literal string \"session_id\"."
#
# REUSE IT:  <error> | nlir -e '~(>"the most likely fix for: $_stdin")'   (any language, any traceback)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TRACE="$(printf '%s\n' \
  'Traceback (most recent call last):' \
  '  File "app.py", line 42, in handle' \
  '    user = cache[session_id]' \
  "KeyError: 'session_id'")"

echo "move:       the fix-it -- <error> | nlir -e '~(>\"the most likely fix for: \$_stdin\")'"
echo "---"
printf '%s\n' "$TRACE" | "$NLIR" --context-file "$CTX" --mode llm -e '~(>"the most likely fix for: $_stdin")'
