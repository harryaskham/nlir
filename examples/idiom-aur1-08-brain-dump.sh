#!/usr/bin/env bash
# nlir IDIOM · aur1 · 08 — "the brain-dump"   'a'; 'b'; 'c'; &; ~$
#
# A reusable MOVE for the pi plugin, and the first that uses the STACK — nlir's
# working memory. You're thinking out loud: you have several half-formed thoughts
# and want the ONE takeaway they add up to. Push each thought, fold, distil:
#
#     'thought a' ;  'thought b' ;  'thought c' ;   &  ;   ~$
#        │             │             │              │       │
#        └── push ─────┴─────────────┘              │       └─ distil the top to the takeaway
#          each `;` pushes one thought onto the stack │
#                                          `&` folds the whole stack into one
#
# `$` is the top of the stack (your working memory); `&` with no operands folds
# everything you've pushed into a single combined thought; `~$` distils that to
# its essence. No message context needed — you supply the raw material.
#
# Swap the last step to change the exit:
#     …; &; ~$   → the crisp takeaway        (distil)
#     …; &; >$   → the fleshed-out prose      (expand)
#     …; &; $?   → a verification checklist   (question)
#
# HOW TO REUSE IT (type this in chat) whenever you're thinking out loud:
#     |'the api is slow'; 'cache is cold on deploy'; 'traffic spikes at 9am'; &; ~$
#     |'ship friday'; 'qa is thin'; 'enterprise not validated'; &; ~$
#
# Run:  ./examples/idiom-aur1-08-brain-dump.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "THE BRAIN-DUMP   'a'; 'b'; 'c'; &; \$~   — push scattered thoughts onto the stack, fold, distil to the point"
echo "  your thoughts: onboarding has too many steps · users drop off at email verification · but we need it for security"
echo -n "  ~\$  (the takeaway) => "
"$NLIR" -e "'onboarding has too many steps'; 'users drop off at email verification'; 'but we need verification for security'; &; ~\$" --quiet | fold -s -w 82 | sed '2,$s/^/     /'

say "The stack is your working memory: each ; pushes a thought, & folds them, ~\$ distils. Change the last op for a different exit: ~\$ takeaway · >\$ prose · \$? checklist. Reusable any time you think out loud."
