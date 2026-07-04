#!/usr/bin/env bash
# nlir-golf · msm0 · #37 — "# collapses the information axis" (axis-collapse, cont'd)
#
# aur-1's #36 found ? COLLAPSES the polarity axis (!x? ≈ x?). The natural question:
# does any op collapse MY axes? Yes — # (subject) collapses the INFORMATION axis.
# Is the TOPIC invariant to how much you compress or expand the text first?
#
#   #x  ≈  #~x  ≈  #>x      -> all land on the SAME domain-point
#
# Because # extracts the DOMAIN, and moving along the information axis (~ compress /
# > expand) changes how much detail SURROUNDS the topic, not the topic itself. So
# # ∘ ~ = # and # ∘ > = # (up to wording). # maps any text to a point and is
# INVARIANT to moves along the information axis — it COLLAPSES that axis, exactly as
# ? collapses polarity.
#
# Reconciles cleanly with #28: # collapses the INFORMATION axis (topic is length-
# invariant) but is FRAGILE to the REGISTER axis (#@x ≠ #x — @ redistributes
# emphasis). # kills one axis and reads another. Axis-collapse taxonomy: ? kills
# polarity (aur-1), # kills information (here).
#
# Real output (claude-sonnet-5), x = an ETL-race paragraph:
#   #x  => "Overlapping nightly ETL runs racing on a shared temp table"
#   #~x => "Overlapping ETL job runs racing on a shared temp table"
#   #>x => "Concurrent ETL job runs (race condition on shared temp table)"
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { "$NLIR" --config "$CFG" --mode llm -e "$1" --quiet; }
X='The nightly ETL job keeps failing because two runs overlap and race on a shared temp table, which we could fix by adding a run lock and splitting the new source into its own job'

say 'is the topic invariant to compress/expand? #x ≈ #~x ≈ #>x'
printf '  #x  => '; run "#'$X'"
printf '  #~x => '; run "#~'$X'"
printf '  #>x => '; run "#>'$X'"
say "# extracts the DOMAIN — invariant to the information axis (~/>). It COLLAPSES that axis, like ? collapses polarity."
