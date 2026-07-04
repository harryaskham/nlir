#!/usr/bin/env bash
# nlir-golf · msm0 · #30 (MILESTONE) — "the semantic basis" (the algebra unified)
#
# The capstone of the algebra-of-nlir: the operators factor semantic space into
# ORTHOGONAL AXES. Take one claim, reuse it once (referential identity, #23), and
# move it along three independent axes at the same time:
#
#   x='…' ; [ @$x , ~$x , !$x ]
#            │      │      └ !$x  POLARITY axis     assert <-> negate   (involution, aur-1 #25)
#            │      └ ~$x  INFORMATION axis  compress <-> expand (synthesising/join-blind, #29)
#            └ @$x  REGISTER axis     formal <-> plain    (content-preserving, #28)
#
# Each op is a BASIS VECTOR: it moves the claim on ONE axis and leaves the others
# fixed. That orthogonality is precisely what every law we mapped established —
# @ doesn't touch content (#28), ~ doesn't touch polarity, ! doesn't touch register.
# So the "algebra of nlir" isn't a pile of tricks: the ops are a small set of
# independent semantic dimensions you compose. The whole theory, in one list.
#
# Real output (claude-sonnet-5), x = "the migration will probably slip past the deadline":
#   @$x => "The migration is likely to extend beyond the deadline."   (REGISTER: formal)
#   ~$x => "The migration will likely miss its deadline."             (INFORMATION: compressed)
#   !$x => "the migration will probably not slip past the deadline"   (POLARITY: flipped)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE SEMANTIC BASIS   x=... ; [@$x , ~$x , !$x]   — register / information / polarity axes'
"$NLIR" --config "$CFG" --mode llm -e "x='the migration will probably slip past the deadline';[@\$x,~\$x,!\$x]" --quiet
say "one claim, three orthogonal axes — @ register / ~ information / ! polarity. The algebra, unified."
