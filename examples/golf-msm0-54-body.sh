#!/usr/bin/env bash
# nlir-golf · msm0 · #54 — "the body" (a windowed range that drops the bookends)
#
# #53 took the EDGES of a conversation; this takes the MIDDLE. A windowed range addresses
# the SUBSTANCE — dropping the opening pleasantry and the sign-off:
#
#   ~1^*-2
#   │└──── 1^*-2   the range from index 1 to the SECOND-TO-LAST turn (negative N from end)
#   └───── ~        summarise that window
#
# So a thread wrapped in "Hey! Quick one before standup" … "Cool, thanks — talk later!"
# summarises to just the substance, the greeting and the sign-off excluded. This uses a
# windowed M^*N range DIRECTLY (verified across the fleet: reversed-N normalises,
# out-of-bounds clamps, negative N resolves from the end — thanks aur-0's reconcile), the
# complement of #53's edge-bookends.
#
# Real output (claude-sonnet-5) over a thread padded with a greeting + a sign-off:
#   ~1^*-2 => "The nightly export job has been silently truncating batches over 10k rows
#              for weeks; fix requires adding a row-count assertion and backfilling from
#              the WAL archive."   (the "hey!" and "thanks, talk later!" dropped)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"Hey! Quick one before standup."},
 {"role":"user","content":"The nightly export job silently dropped 300 rows last night."},
 {"role":"assistant","content":"That's the batch-size overflow — it truncates past 10k rows without erroring."},
 {"role":"user","content":"So we've probably been losing rows for weeks?"},
 {"role":"assistant","content":"Likely. Add a row-count assertion and backfill from the WAL archive."},
 {"role":"user","content":"Cool, thanks — talk later!"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a thread wrapped in 'Hey! Quick one…' and 'Cool, thanks — talk later!' is in the context"
say 'THE BODY   ~1^*-2   (summarise index 1 .. second-to-last: drop opening + sign-off)'
printf '  => '; "$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '~1^*-2' --quiet
say "the windowed range excludes the bookend chatter — the substance, minus the hello and goodbye."
