#!/usr/bin/env bash
# nlir-golf · msm0 · #38 — "~ collapses the register axis" (the ?/#/~ trio, completed)
#
# ? collapses register+polarity (aur-1), # collapses information (#37). What about
# ~? Is the summary invariant to whether you FORMALISE or SIMPLIFY first?
#
#   ~x  ≈  ~@x  ≈  ~:x      at the CONTENT level — same gist every time
#
# with only a FAINT register bleed (~@x reads a touch more formal, ~:x a touch
# plainer). So ~ collapses the register axis in MEANING — the gist is register-blind;
# a slight surface tint inherits from the input, ≈ not ==.
#
# That COMPLETES the {register, information} characterization of the three
# content-adjacent operators:
#   ?  collapses register + polarity, RESPECTS information   (aur-1)
#   #  collapses information,          READS register (fragile, #28)
#   ~  collapses register,            MOVES information (its own axis)
# So ~ and ? are both register-robust content ops; # is the outlier that reads
# register. Two collapse register, one reads it — a clean 3-way split.
#
# Real output (claude-sonnet-5), x = a casual "migrate auth off the old store before March":
#   ~x  => "The auth service must be migrated off the old session store before its
#           March deprecation to avoid breaking all logins."
#   ~@x => "The authentication service must migrate off the legacy session store
#           before its March discontinuation to avoid a total login outage."
#   ~:x => "We must migrate our login system before the old provider shuts down in
#           March, or users will be unable to log in."
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
X='we gotta migrate the auth service off the old session store before the vendor kills it in march, otherwise every login breaks'

say 'is the summary invariant to formalise/simplify first? ~x ≈ ~@x ≈ ~:x (content-level)'
printf '  ~x  => '; run "~'$X'"
printf '  ~@x => '; run "~@'$X'"
printf '  ~:x => '; run "~:'$X'"
say "same gist, faint register bleed — ~ collapses register, moves info. Trio: ?/~ collapse register, # reads it."
