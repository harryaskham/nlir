#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the PR summary": pipe a diff, get a title + a description.
#
# THE MOVE (reusable, as a PIPE):
#     git diff | nlir -e '[#$_stdin, ~$_stdin]'
#       $_stdin = whatever you pipe in   # = its subject (the title)   ~ = its gist (the body)
#     └──────── a two-element list: the PR title, then the PR description
#
# nlir is a smart pipe: `$_stdin` is whatever you pipe in. `#$_stdin` extracts the SUBJECT of the
# change (a title); `~$_stdin` distils the whole diff to a summary (the body). Two list elements →
# a ready-to-paste PR title + description, straight from `git diff`. (aur-0's commit-pipe `~$_stdin`
# gives the one-line commit message; this pairs it with a `#`-title for the fuller PR write-up.)
#
# Filled example (a sample diff piped in — in real use: `git diff | nlir -e '[#$_stdin, ~$_stdin]'`):
#
# Real output (claude-sonnet-5):
#   "Token verification logic in `verify_token`
#    The diff updates `verify_token` to reject `None` tokens and also check for expiration, instead of
#    only checking session membership."
#
# REUSE IT:  git diff | nlir -e '[#$_stdin, ~$_stdin]'   (or `git diff main...` for a whole branch)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

DIFF="$(printf '%s\n' \
  'diff --git a/auth.py b/auth.py' \
  '+def verify_token(tok):' \
  '+    if tok is None: return False' \
  '+    return tok in ACTIVE_SESSIONS and not is_expired(tok)' \
  '-def verify_token(tok):' \
  '-    return tok in ACTIVE_SESSIONS')"

echo "move:       the PR summary -- git diff | nlir -e '[#\$_stdin, ~\$_stdin]'  (title, then description)"
echo "---"
printf '%s\n' "$DIFF" | "$NLIR" --context-file "$CTX" --mode llm -e '[#$_stdin,~$_stdin]'
