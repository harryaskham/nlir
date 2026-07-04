#!/usr/bin/env bash
# nlir-golf · msm0 · #48 — "the four role views" (the SELECT dimension's alphabet)
#
# A conversation isn't ONE array — it's FOUR interleaved role-channels, and each is
# independently addressable. This is the addressing ALPHABET behind every range
# concept (the SELECT half of nlir = SELECT × TRANSFORM, #40):
#
#   ^/  system channel      ^/0   => "You are a database performance expert."
#   ^_  user channel        ^_0   => "My dashboard query takes 8 seconds."
#   ^   assistant channel   ^-1   => "Add a covering index…"   (last ASSISTANT)
#   ^*  all / any channel   ^*-1  => "Still slow after the index."  (last of ANY role)
#
# Note the crucial pair: ^-1 (the last ASSISTANT turn) and ^*-1 (the last turn of ANY
# role) point at DIFFERENT messages — the distinction that made #16 catch-up work. So
# the range syntax `<role>START^<role>END` is just these four channels plus an index
# range; every concept in the catalog is built from this alphabet.
#
# Real output (claude-sonnet-5? no — DET reads, no LLM) over a db-perf thread — see above.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic reads — no key needed

CTX="$(mktemp "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"system","content":"You are a database performance expert."},
 {"role":"user","content":"My dashboard query takes 8 seconds."},
 {"role":"assistant","content":"Add a covering index on the filtered columns and paginate the results."},
 {"role":"user","content":"Still slow after the index."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
r() { "$NLIR" --context-file "$CTX" --config "$CFG" --mode det -e "$1" 2>&1 | head -1 | sed 's/nlir \[det\]: [^ ]* -> //'; }

say "a 4-turn thread with system / user / assistant / user is in the context"
printf '  ^/0  (system)      => '; r '^/0'
printf '  ^_0  (first user)  => '; r '^_0'
printf '  ^-1  (last asst)   => '; r '^-1'
printf '  ^*-1 (last, ANY)   => '; r '^*-1'
say "four role channels — ^/ system, ^_ user, ^ assistant, ^* any. The addressing alphabet of every range."
