#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "generate a reply": => follows an instruction and writes NEW text.
#
# THE MOVE (reusable — learn the shape, fill the slots):
#     t=^-1; =>"<INSTRUCTION about the last turn>: $t"
#     │      │  └ a "double-quoted" instruction — $t (and $_stdin) interpolate live values in
#     │      └ => = the OPEN verb: obey the instruction, return ONLY the result (free generation)
#     └ SELECT a turn (^-1 = last message) and bind it, so the instruction can reference it
#
# => is the llm TWIN of @ (the @<->=> duality): where @ RESTYLES text you already have
# (formal / plain / terse), => WRITES NEW text to order — a reply, a summary, a haiku — obeying any
# format/length constraint. The generative frame ("treat the operand as an INSTRUCTION, return ONLY
# the result") lives in the model config, not the op, so => obeys by construction. Double quotes
# interpolate $name/$_stdin; 'single quotes' are literal (a literal $name reaches the model).
#
# OBEYS (tight constraints, verbatim):
#   =>"write exactly: shipped"                 -> shipped
#   =>"a haiku about shipping code on friday"  -> Tests are green, ship it— / what could go wrong
#                                                 on Friday? / Pager screams at dawn.
#
# Filled example (the reply idiom, against the chat below):
#   t=^-1;=>"a one-sentence reply, agreeing and offering to help, to: $t"
#
# Real output (claude-sonnet-5):
#   "Sounds great — happy to help by drafting test cases for the ./.. accessors or reviewing the
#    Dict API design as you go, just let me know what'd be most useful this afternoon."
#
# COMPOSE (=> is a normal operand — generate several pieces, weave into one):
#   <proposal> | @&[=>"a brief acknowledgement of: $_stdin", =>"a one-sentence gentle counter to: $_stdin"]
#   -> "Agreed — Friday will work well. I would suggest that we release the stable core on that day
#       and defer any higher-risk elements until Monday, ..."
#
# Offline too: --mode det echoes the (interpolated) instruction via the => det stub
#   (=>"write exactly: shipped" -> "response: write exactly: shipped"), so the structure is
#   verifiable without a model; llm mode does the real generation.
#
# REUSE IT:  t=^-1; =>"<what kind of reply>: $t"     (or)     <text> | =>"<instruction>: $_stdin"
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
# => is a config.example.yaml operator; default there so the move is self-contained. Override
# NLIR_CONFIG to point => at your own generative backend (any medium-tier model + the generative frame).
NLIR_CONFIG="${NLIR_CONFIG:-config.example.yaml}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"user","content":"can you take the dictionaries bead next?"},
{"role":"assistant","content":"yes, I'll start on the Value::Dict foundation and the . and .. accessors this afternoon"}
]}
JSON

EXPR='t=^-1;=>"a one-sentence reply, agreeing and offering to help, to: $t"'

echo "move:       generate a reply -- t=^-1; =>\"<instruction>: \$t\""
echo "chat:       agent: 'yes, I'll start on the Value::Dict foundation and the . and .. accessors this afternoon'"
echo "---"
"$NLIR" --config "$NLIR_CONFIG" --context-file "$CTX" --mode llm -e "$EXPR"
