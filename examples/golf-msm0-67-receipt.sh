#!/usr/bin/env bash
# nlir-golf · msm0 · #67 — "the receipt" (a computed structured record, no LLM)
#
# The whole deterministic substrate braided into one record: arithmetic, the literal-$ escape,
# a labelled list, and a line separator — a formatted report with a computed total.
#
#   item="coffee" ; qty=3 ; price=5 ; total=$qty*$price ; _sep="\n" ; ["Item:  $item","Qty:   $qty","Total: \$$total"]
#   │               │       │         │                   │           └ a labelled list, interpolating the fields
#   │               │       │         │                   └ _sep="\n"   one field per line
#   │               │       │         └ total = $qty*$price = 15        (arithmetic, exact)
#   │               │       └ price=5   \
#   │               └ qty=3            } stored fields
#   └────────────── item="coffee"     /
#
#   =>  Item:  coffee
#       Qty:   3
#       Total: $15
#
# `\$` is a LITERAL dollar-sign (the bd-65b737 fix, cf #51) sitting right next to the interpolated
# $total. Five stored/computed fields assembled into a formatted record — nlir as a deterministic
# report generator, no LLM in sight (#34/#36/#45/#61 substrate, at full stretch).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE RECEIPT   item="coffee";qty=3;price=5;total=$qty*$price;_sep="\n";["Item:  $item","Qty:   $qty","Total: \$$total"]'
"$NLIR" --config "$CFG" --mode det --quiet -e 'item="coffee";qty=3;price=5;total=$qty*$price;_sep="\n";["Item:  $item","Qty:   $qty","Total: \$$total"]'
say "a computed total, a literal \$, and interpolated fields laid out as lines — a deterministic report, no LLM."
