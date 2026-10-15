#!/usr/bin/env bash
# Deterministic replay: model calls are recorded by content address and replayed.
set -euo pipefail
NLIR=${NLIR:-nlir}
store=$(mktemp -t nlir-store.XXXXXX)
trap 'rm -f "$store"' EXIT
expr="=>'Invent a name for a lighthouse keeper''s cat'"
time "$NLIR" --quiet --cache-file "$store" -e "$expr"      # recorded
time "$NLIR" --quiet --cache-file "$store" -e "$expr"      # replayed: identical, instant
"$NLIR" --quiet --cache-file "$store" --replay strict -e "$expr"
"$NLIR" --quiet --cache-file "$store" -e "_seed=1; $expr"  # a new seed draws a fresh sample
"$NLIR" --quiet --cache-file "$store" -e "_sep=' | '; \$draw%({$expr}, 3)"
