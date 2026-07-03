#!/usr/bin/env bash
# nlir-golf · aur1 · #10 — "topic drift"
#
# Temporal, without ranges: compare the FIRST and LAST user turn's subjects and
# you see how a conversation MOVED — where it started vs where it ended up.
# `^_N` is the user channel, so `^_0` is their opening turn and `^_-1` their
# latest; `#` pulls the topic of each; the list shows the drift as two lines.
#
#   DRIFT   [#^_0 , #^_-1]     (subject of first user turn | subject of last)
#     #^_0   what they opened with
#     #^_-1  what they're on now
#
# A real support thread that opened on "set up CI for a Rust project" and wandered
# to "shrink my release binaries" reports exactly that migration — the before and
# after of attention, in six characters per point. Point reads (not M^N ranges)
# make this the temporal cousin of msm0's range work.
#
# Run:  ./examples/golf-aur1-10-drift.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-aur1-10-XXXXXX.json")"
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"How do I set up a CI pipeline for my Rust project on GitHub Actions?"},
 {"role":"assistant","content":"Add a workflow with cargo test and cargo clippy steps."},
 {"role":"user","content":"Now the CI passes but my release binaries are huge — how do I shrink them?"},
 {"role":"assistant","content":"Enable strip and LTO, and set opt-level=z in the release profile."}
]}
JSON

say "TOPIC DRIFT  [#^_0 , #^_-1]  — subject of the FIRST vs LAST user turn"
echo "  (a thread that opened on CI setup and wandered to binary size)"
echo "  started | now =>"
"$NLIR" --context-file "$CTX" -e "[#^_0,#^_-1]" --quiet | sed 's/^/    /'
rm -f "$CTX"

say "^_0 = opening user turn, ^_-1 = latest — the before/after of attention, point reads not ranges."
