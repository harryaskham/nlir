#!/usr/bin/env bash
# nlir-golf · aur1 · #58 — "the catalog entry" (a filing title + a polished abstract)
#
# A knowledge-base entry has two parts: a title you file it under, and an abstract you
# read. `[#x, @~x]` builds both from one fact — `#x` gives the TITLE (the topic, as a
# clean noun-phrase heading) and `@~x` gives the ABSTRACT (the polished, formal one-line
# summary). Point it at a change, a decision, or an incident and you've drafted the wiki
# page header.
#
#   CATALOG ENTRY   [ #x , @~x ]
#     fact "we moved session storage to Redis so logins survive a restart, cutting
#           re-auth support tickets ~40%"
#     #x  → "Session storage migration to Redis"                         ← the TITLE
#     @~x → "Session storage was migrated to Redis, ensuring logins persist across
#            server restarts and reducing re-authentication support tickets by ~40%."
#                                                                        ← the ABSTRACT
#
# The `#` heads it (what to call it), the `@~` bodies it (formal + brief = the abstract).
# Distinct from my #54 triage (`[#^_-1, ~^_-1]` — on a live MESSAGE, plain gist for
# routing) and #24 zoom (three tiers over a doc): this is a CLAIM turned into a clean
# [title, formal abstract] pair — a catalog header you'd paste into a knowledge base.
#
# Run:  ./examples/golf-aur1-58-catalog.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we moved session storage to redis so logins survive a server restart, cutting re-auth support tickets by about forty percent'

say "CATALOG ENTRY  [#x, @~x]  — the filing TITLE (#x) + the polished formal ABSTRACT (@~x)"
echo   "  fact: $C"
echo -n "  #x  (TITLE)    => "; "$NLIR" -e "#'$C'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  @~x (ABSTRACT) => "; "$NLIR" -e "@~'$C'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "# heads it, @~ bodies it — a wiki/KB entry header from a fact. (vs #54 triage on a message, #24 zoom's 3 tiers.)"
