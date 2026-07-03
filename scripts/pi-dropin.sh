#!/usr/bin/env bash
# nlir Pi drop-in — treat a chat stream as an nlir session (SPEC §Sessions, bd-684213).
#
# Reads conversation lines on stdin and, over a shared context file:
#   - a line beginning with `|` is an nlir shorthand EXPRESSION: the rest is
#     expanded via `nlir -e` and the English result is printed to stdout;
#   - any other non-blank line is a plain conversation TURN, appended to the
#     context's `_messages` so later `|` expansions can read it (`^-1` = last
#     message, `#^-1` = its subject, `$name` = a context key).
#
# This is the "pipe your turns through `nlir repl --raw`" pattern with per-turn
# message accumulation, usable as a drop-in in a Pi-style chat loop.
#
# Usage:
#   scripts/pi-dropin.sh [--context-file F] [--role R] [nlir-args...]
#   printf '%s\n' 'the answer is 42' '|^-1' | scripts/pi-dropin.sh --role assistant
#
# Env:
#   NLIR   path to the nlir binary (default: `nlir` on PATH)
set -euo pipefail

nlir_bin="${NLIR:-nlir}"
ctx=""
role="user"
extra=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --context-file) ctx="${2:?--context-file needs a path}"; shift 2 ;;
    --role)         role="${2:?--role needs a value}"; shift 2 ;;
    *)              extra+=("$1"); shift ;;   # forward unknown flags to nlir (e.g. --config)
  esac
done

# Default to a throwaway per-session context so turns accumulate within a run.
if [ -z "$ctx" ]; then
  ctx="$(mktemp -u "${TMPDIR:-/tmp}/nlir-pi-XXXXXX.json")"
fi

# Run nlir with the shared context + any caller-supplied args (e.g. --config).
run() { "$nlir_bin" --context-file "$ctx" ${extra[@]+"${extra[@]}"} "$@"; }

while IFS= read -r line; do
  case "$line" in
    '|'*) run -e "${line#|}" --quiet ;;                        # expand nlir shorthand → English
    '')   : ;;                                                 # skip blank lines
    *)    run append-message --role "$role" "$line" >/dev/null ;;  # accumulate this turn
  esac
done
