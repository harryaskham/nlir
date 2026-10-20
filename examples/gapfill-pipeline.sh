#!/usr/bin/env bash
# The gap-filled writer end to end (needs a model): read the two lists from an authored text, then write
# every field from the spec plus its lists — K drafts each, trimmed to what states a listed item — and keep
# the draft that covers the lists best. Data: an invented code-review rule from the spec lab.
# Env: NLIR (binary), NLIR_CONFIG (config with a model; default config.example.yaml), NLIR_MODEL, K (default 2).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR=${NLIR:-nlir}
K=${K:-2}
"$NLIR" --config "${NLIR_CONFIG:-config.example.yaml}" ${NLIR_MODEL:+--model "$NLIR_MODEL"} --mode llm --quiet \
  -f lib/gapfill.nlir --bind d=examples/data/code-review-rule.json \
  -e "lists=\$gf_extract%(\$d.spec, \$d.authored, \$d.fields); \$json%{lists=\$lists, document=\$gf_document%(\$d.spec, \$lists, \$d.fields, $K)}"
