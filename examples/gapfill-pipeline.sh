#!/usr/bin/env bash
# The gap-filled writer end to end (needs a model): read the two lists from an authored text, then write
# every field from the spec plus its lists — K drafts each, trimmed to what states a listed item — and keep
# the draft that covers the lists best. Data: an invented code-review rule from the spec lab, and the guidance
# for its profile format (GUIDE; what each field means — without it, a generic writer scores no better than the
# spec alone).
# Env: NLIR (binary), NLIR_CONFIG (config with a model; default config.example.yaml), NLIR_MODEL, K (default 2),
# GUIDE (default examples/data/code-review-guide.json; empty for none).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR=${NLIR:-nlir}
K=${K:-2}
GUIDE=${GUIDE-examples/data/code-review-guide.json}
if [ -n "$GUIDE" ]; then G=(--bind "g=$GUIDE"); PRE='gf_guide=$g.guide; gf_field_guides=$g.fields; '; else G=(); PRE=''; fi
"$NLIR" --config "${NLIR_CONFIG:-config.example.yaml}" ${NLIR_MODEL:+--model "$NLIR_MODEL"} --mode llm --quiet \
  -f lib/gapfill.nlir --bind d=examples/data/code-review-rule.json ${G[@]+"${G[@]}"} \
  -e "$PRE""lists=\$gf_extract%(\$d.spec, \$d.authored, \$d.fields); \$json%{lists=\$lists, document=\$gf_document%(\$d.spec, \$lists, \$d.fields, $K)}"
