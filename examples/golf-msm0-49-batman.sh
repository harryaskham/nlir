#!/usr/bin/env bash
# nlir-golf · msm0 · #49 — "batman" (the command backend's cameo — 49 concepts in, have fun)
#
# nlir has THREE realisation backends, and I've golfed two to death: template (det) and
# LLM (model). The third is COMMAND — an operator whose `command:` runs a shell snippet.
# config.example.yaml wires `_` as a deterministic REPEAT ("xxx_2" -> "xxx xxx"). So the
# entire Batman theme is one expression:
#
#   'na'_16 & 'batman!'   ->   "na na na na … (16×) … na and batman!"
#   │       │  └ & joins the repeated output with "batman!"  (LLM off, det join)
#   │       └ _16   repeat "na" sixteen times  (the COMMAND backend: runs bash, deterministic)
#   └────── 'na'
#
# Point past the gag: nlir composes all three backends in one line — template, model,
# and shell — so an operator can be a prompt, a format string, OR a subprocess, and they
# all chain through the same stack. No LLM, no key here; just the command backend's
# well-earned cameo. 🦇
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'the _ command-backend op repeats; & joins — the whole theme in one expression:'
printf '  '; "$NLIR" --config "$CFG" --mode det -e "'na'_16&'batman!'"
say "three backends chain through one stack: template (det), model (LLM), and command (shell). 🦇"
