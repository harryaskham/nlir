#!/usr/bin/env bash
# nlir-golf · aur1 · #49 — "the two-reader memo" (write once, serve exec + engineer)
#
# One decision, two readers, one expression. `[@~x, >x]` emits the SAME fact at two
# depths tuned for two audiences: `@~x` (formal + brief) is the line an executive
# skims; `>x` (full detail) is the paragraph an engineer needs to actually build it.
# Write the thought once; nlir serves both the summary deck and the design doc.
#
#   TWO-READER MEMO   [ @~x , >x ]
#     fact  "moving the session store from in-memory to Redis so sessions survive a restart"
#     @~x → "The session store is being migrated from an in-memory implementation to
#            Redis to ensure sessions persist across server restarts."   ← EXEC skim
#     >x  → "We are migrating session storage away from the app server's own process
#            memory to Redis, a dedicated external in-memory store, so that session
#            state is no longer lost when a server process restarts or is redeployed…"
#                                                                          ← ENGINEER detail
#
# Two ops, two axes: `@` fixes the register (formal, for both) while `~` vs `>` sets the
# LENGTH per reader. It's the register-grid (#32) used for AUDIENCE-splitting rather than
# doc-type, and unlike #44 BLUF (one reader, answer-then-support) this is TWO readers,
# each handed exactly their altitude. One keystroke fewer meeting.
#
# Run:  ./examples/golf-aur1-49-tworeader.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we are moving the session store from in-memory to redis so sessions survive a server restart'

say "TWO-READER MEMO  [@~x, >x]  — same fact, exec one-liner (@~x) + engineer detail (>x)"
echo -n "  @~x (EXEC skim)      => "; "$NLIR" -e "@~'$C'" --quiet | fold -s -w 86 | sed '2,$s/^/       /'
echo    "  >x  (ENGINEER detail) =>"; "$NLIR" -e ">'$C'" --quiet | fold -s -w 86 | sed 's/^/     /'

say "@ fixes register (formal), ~ vs > sets length per reader. #32's grid used for AUDIENCE, not doc-type."
