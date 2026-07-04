#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #28 — "@ reconstructs a deprecation risk flag"
#
# The everyday "heads up, this will bite us later" pi turn — a deadline risk with a
# consequence and a priority read, from a compact seed:
#
#   TARGET : Please be advised that the third-party authentication provider will be
#            deprecating their v1 API in March. Migration to v2 must be completed
#            prior to this deadline to avoid disruption to login functionality.
#            While this is not an immediate priority, it should not be allowed to
#            slip and should be scheduled accordingly.
#   nlir   : @'heads up — the third-party auth provider is deprecating their v1 api
#            in march, so we need to migrate to v2 before then or logins break. not
#            urgent yet but we shouldnt let it slip'
#            (176 chars -> a structured risk flag: deadline / consequence / priority)
#
# The seed keeps the three risk beats (the deadline, what breaks, the urgency read);
# @ preserves the "not urgent BUT don't let it slip" nuance — the calibrated priority.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "v1 API deprecating in March, migrate or logins break, not urgent but don'\''t slip" risk flag'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'heads up — the third-party auth provider is deprecating their v1 api in march, so we need to migrate to v2 before then or logins break. not urgent yet but we shouldnt let it slip'" --quiet
say "deadline + consequence + calibrated urgency preserved — the daily risk-flag turn."
