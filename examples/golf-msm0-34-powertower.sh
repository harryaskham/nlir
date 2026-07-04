#!/usr/bin/env bash
# nlir-golf · msm0 · #34 — "the power tower" (right-associativity, bd-df62f1 fixed)
#
# Celebrating a real dogfooded bug the three of us fixed together: aur-0 found that
# ** parsed LEFT-associative, aur-2 blessed a per-operator `assoc` config field, and
# I supplied the Pratt-loop change. ** is now RIGHT-associative — "normal math":
#
#   2**3**2  => 512   = 2^(3^2) = 2^9     (right-assoc; was 64 = (2^3)^2 before the fix!)
#   4**2**2  => 256   = 4^(2^2) = 4^4
#
# ...while - and / STAY left-associative (the regression guards I asked for):
#
#   2-3-4    => -5    = (2-3)-4
#   8/4/2    => 1     = (8/4)/2
#
# ...and it composes with coercion (aur-2's types axis): 'two'**'three' => 8.
#
# The fix in one line: bp() already DOUBLED priority "so left-associativity has room"
# — that room is exactly a 2p-1 right-binding-power branch. `assoc: right` on pow flips
# the Infix arm from `l_bp + 1` (left) to `l_bp.saturating_sub(1)` (right). Now nlir's
# arithmetic matches normal math on BOTH associativity and precedence.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
det() { "$NLIR" --config "$CFG" --mode det -e "$1"; }

say 'RIGHT-assoc ** (fixed): 2**3**2 = 2^(3^2) = 512  (was 64 before bd-df62f1)'
printf '  2**3**2 => '; det '2**3**2'
printf '  4**2**2 => '; det '4**2**2'
say 'LEFT-assoc - and / preserved (regression guards):'
printf '  2-3-4   => '; det '2-3-4'
printf '  8/4/2   => '; det '8/4/2'
say 'composes with worded-number coercion:'
printf "  'two'**'three' => "; "$NLIR" --config "$CFG" --mode llm -e "'two'**'three'" --quiet
say "nlir arithmetic now matches normal math — associativity AND precedence. A fleet fix."
