#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the code-review comment": weave a summary of the code + YOUR review
# points into one polished review comment. You bring the judgment; nlir folds in the context + prose.
#
# THE MOVE (reusable, as a PIPE):
#     <the code> | nlir -e '@&[~$_stdin, YOUR_POINT_1, YOUR_POINT_2]'
#       $_stdin = the piped code   ~$_stdin = a summary of it   @&[...] = formalize + WEAVE into one comment
#     └──────── your review points get woven together WITH a summary of what the code does
#
# review-pipe (aur-0) DIAGNOSES the code for you; this is the opposite hand — YOU supply the review
# points (the human judgment), and nlir folds in a summary of what the code does and weaves it all
# into one professional review comment. A "help me write the review" tool, not a "find the bugs" tool.
#
# Filled example (a config-loader with a bare except, piped in):
#   ... | nlir -e "@&[~\$_stdin,'the bare except silently swallows real errors','the file handle is never closed']"
#
# Real output (claude-sonnet-5):
#   "The `load_config` function reads a JSON file and returns its contents; however, in the event of
#    any error, it returns an empty dictionary rather than surfacing the issue. This design is
#    problematic: the bare `except` clause silently suppresses legitimate errors, such as a missing
#    file, and the file handle is never properly closed."
#
# REUSE IT:  <code> | nlir -e '@&[~$_stdin, YOUR_POINT_1, YOUR_POINT_2, ...]'
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

CODE="$(printf '%s\n' \
  'def load_config(path):' \
  '    try:' \
  '        return json.load(open(path))' \
  '    except:' \
  '        return {}')"

echo "move:       the code-review comment -- <code> | nlir -e '@&[~\$_stdin, POINT_1, POINT_2]'"
echo "---"
printf '%s\n' "$CODE" | "$NLIR" --context-file "$CTX" --mode llm \
  -e "@&[~\$_stdin,'the bare except silently swallows real errors like a missing file','the file handle is never closed']"
