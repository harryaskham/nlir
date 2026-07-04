#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #67) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a devops platform from a 22-char seed.
#
# TARGET (~187 chars):
#   "Kubernetes is a system that automatically runs, scales, and heals containerized
#    apps across a cluster of machines, so you describe what you want and it keeps
#    the containers in that state."
#
# EXPRESSION (22 chars):
#   ~>'what is kubernetes'
#
# Real output (claude-sonnet-5):
#   "Kubernetes is an open-source container orchestration platform, originating from
#    Google's Borg system, that automates the deployment, scaling, healing,
#    networking, and management of containerized applications across clusters of machines."
# Closeness: same core (automates deploy/scale/heal of containers across clusters),
# but ~> lands DEEP technical register (Borg origin, orchestration, networking) (high).
# 88% shorter -- 22 characters into a full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Kubernetes is a system that automatically runs, scales, and heals containerized apps across a cluster of machines, so you describe what you want and it keeps the containers in that state."
EXPR="~>'what is kubernetes'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
