#!/usr/bin/env bash
# nlir showcase · msm0 · RECORDS & ACCESSORS — labeled data + . / .. (deterministic)
#
#   {k=v, k2=v2}     a dict (record): a brace whose body is all key=value bindings
#   x.k              structural access (det): list index / dict field / string char
#   {$0.f}↦[recs]    extract a COLUMN: map the accessor over a list of records
#   {$0+$1}⊘( … )    then FOLD the column → one answer (sum a field across records)
#   ?%(d.k, a, b)    branch on a record field (if over a dict lookup)
#
# The composable-core payoff: labeled data slots into the SAME map/fold/if machinery
# as everything else — no loop, no special case. All DET (no model, no network),
# so it runs under verify-showcase --det-only. Proves the phrasebook
# "Records & accessors" idioms are real executions, not theory.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"

D()   { "$NLIR" --config "$CFG" --mode det --quiet -e "$1"; }
run() { printf '  %-44s => ' "$1"; D "$2"; }
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "structural access  x.k  — polymorphic on what's on the left"
run '[a,b,c].1'                      '[a,b,c].1'
run "{host='web1',port=8080}.port"   "{host='web1',port=8080}.port"
run '"the".2'                        '"the".2'

say "extract a COLUMN — map the . accessor over a list of records"
run '{$0.name}↦[{name=alice,..},..]' '{$0.name}↦[{name=alice,age=30},{name=bob,age=25}]'

say "sum a field ACROSS records — extract-column then fold (the payoff)"
run '{$0+$1}⊘({$0.age}↦[..])'        '{$0+$1}⊘({$0.age}↦[{name=a,age=30},{name=b,age=25}])'

say "branch on a record field — if over a dict lookup"
run '?%({mode=fast}.mode,go,stop)'   '?%({mode=fast}.mode,go,stop)'

say "labeled data → the SAME map/fold/if machinery as everything else. All DET."
