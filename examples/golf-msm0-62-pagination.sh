#!/usr/bin/env bash
# nlir-golf · msm0 · #62 — "the pagination" (stride a conversation in fixed-size pages)
#
# The real payoff of #55 (range bounds are arithmetic) + #61 ($ reads a value in any value
# position): walk a long conversation in fixed-size PAGES, each addressed by computed bounds.
#
#   page=1 ; size=2 ; s=$page*$size ; e=$s+$size-1 ; $s^*$e
#   │        │        │               │              └ read the window [s .. e]
#   │        │        │               └ e = page*size + size-1     (the page's LAST index)
#   │        │        └ s = page*size                              (the page's FIRST index)
#   │        └ size=2   the page size
#   └──────── page=1    which page to read
#
#   page 0 => [msg0, msg1]     page 1 => [msg2, msg3]     page 2 => [msg4, msg5]
#
# Increment `page` to stride through the whole thread K messages at a time — dynamic windowing
# driven entirely by arithmetic over stored values. #53's edges and #54's body are fixed pages;
# this is the general paginator. Wrap ~ around it (~$s^*$e) to summarise each page in turn.
# Deterministic, no LLM — the markers make the strides legible.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

CTX="$(mktemp "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"P0-alpha"},{"role":"assistant","content":"P1-bravo"},
 {"role":"user","content":"P2-charlie"},{"role":"assistant","content":"P3-delta"},
 {"role":"user","content":"P4-echo"},{"role":"assistant","content":"P5-foxtrot"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
pg() { printf '  page %s (size %s) => ' "$1" "$2"; "$NLIR" --context-file "$CTX" --config "$CFG" --mode det --quiet -e "page=$1;size=$2;s=\$page*\$size;e=\$s+\$size-1;\$s^*\$e" | tr '\n' ' '; echo; }
say "6 markers P0..P5 — stride through them in size-2 pages via computed bounds \$page*\$size .. +size-1:"
pg 0 2; pg 1 2; pg 2 2
say "increment page to walk the whole thread K at a time — dynamic windowing from arithmetic alone."
