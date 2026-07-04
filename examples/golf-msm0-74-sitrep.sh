#!/usr/bin/env bash
# nlir-golf · msm0 · #74 — "the sitrep" (a status board + a real interpolation footgun)
#
# A deterministic incident status board with a computed elapsed time — and a genuine gotcha worth
# knowing about nlir interpolation.
#
#   sys="payments-api";sev=2;start=9;now=11;elapsed=$now-$start;_sep="\n";["🔴 INCIDENT: $sys","severity: SEV-$sev","elapsed: $elapsed h (mitigated)","next update: $now:30"]
#   =>  🔴 INCIDENT: payments-api
#       severity: SEV-2
#       elapsed: 2 h (mitigated)
#       next update: 11:30
#
# elapsed is COMPUTED ($now-$start = 2), each field interpolates, _sep lays it out as lines.
#
# THE GOTCHA (real, worth surfacing): interpolation is BARE $name only, NOT ${name} —
#   x=42;"braces: ${x}  bare: $x"   =>   "braces: ${x}  bare: 42"
# so ${x} prints literally. Put a NON-ALPHANUMERIC after the value instead of reaching for braces:
# "$elapsed h" (space) and "$now:30" (colon) both work because the name ends at the space/colon;
# "${elapsed}h" does not. A status board that doubles as a footgun map (#44 quotes, #51 escapes, this).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE SITREP — computed elapsed, line-separated status board:'
"$NLIR" --config "$CFG" --mode det --quiet -e 'sys="payments-api";sev=2;start=9;now=11;elapsed=$now-$start;_sep="\n";["🔴 INCIDENT: $sys","severity: SEV-$sev","elapsed: $elapsed h (mitigated)","next update: $now:30"]'
say 'the gotcha: interpolation is bare $name, NOT ${name}:'
printf '  '; "$NLIR" --config "$CFG" --mode det --quiet -e 'x=42;"braces: ${x}  bare: $x"'
say "end a \$name with a space or a non-alpha (\$elapsed h, \$now:30); \${braces} print literally."
