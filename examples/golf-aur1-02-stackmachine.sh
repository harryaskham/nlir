#!/usr/bin/env bash
# nlir-golf · aur1 · #02 — "the stack IS the machine"
#
# Everyone's golfed the OPERATORS (aur-2 corpus-spread, msm0 whole-conversation
# range, aur1 single-turn cognition). Nobody's shown the STACK itself. nlir is a
# stack machine: `;` PUSHES a result, a NULLARY operator (empty operands) FOLDS
# the whole stack, and `$` PEEKS the top. That's a full postfix/RPN fold engine —
# and the exact same mechanic folds numbers AND meaning.
#
#   RPN ARITHMETIC   3;4;+;5;*        →  35     ( (3+4)*5, Reverse Polish )
#     push 3 · push 4 · + folds [3,4]=7 · push 5 · * folds [7,5]=35
#
#   SQUARE-BY-PEEK   n;$;*            →  n²     ( 10;$;* → 100 , 7;$;* → 49 )
#     push n · $ peeks n back onto the stack · * folds [n,n]=n²
#     (2 sigils `$;*` = "multiply a value by itself" — no variable needed)
#
#   LANGUAGE FOLD    #a;#b;#c;&       →  the three subjects, and-joined
#     push subject(a) · subject(b) · subject(c)  (3 concurrent LLM calls)
#     · & folds the WHOLE stack into one fluent phrase
#
# Same three-move machine (push ; / fold nullary-op / peek $) drives arithmetic
# reduction and LLM-result composition. The stack doesn't care what's on it.
#
# Run:  ./examples/golf-aur1-02-stackmachine.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "RPN ARITHMETIC  3;4;+;5;*  — the stack is a Reverse-Polish calculator"
echo -n "  (3+4)*5 => "; "$NLIR" -e '3;4;+;5;*' --quiet --mode det

say "SQUARE-BY-PEEK  n;\$;*  — \$ peeks the top back on, * folds [n,n]=n²"
echo -n "  10;\$;* => "; "$NLIR" -e '10;$;*' --quiet --mode det
echo -n "   7;\$;* => "; "$NLIR" -e '7;$;*' --quiet --mode det

say "LANGUAGE FOLD  #a;#b;#c;&  — same push/fold, over LLM results"
echo -n "  three reports -> "
"$NLIR" -e "#'the report on protected bike lanes';#'the report on local shop revenue';#'the report on traffic calming';&" --quiet

say "One machine: push ';' · fold nullary-op · peek '\$'. Numbers or meaning."
