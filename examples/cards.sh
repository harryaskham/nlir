#!/usr/bin/env bash
# A reversible program on a toy card game, offline: the rules and the state are data, the program says
# which card the player plays and why — and `nlir put --alternatives` runs it backwards. Every check is
# asserted. Selections like "the highest card" have many preimages: the program's author says how to go
# back (`_puts`), and the search finds the other consistent explanations, each verified by re-running.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR=${NLIR:-nlir}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
run() { "$NLIR" --config config.example.yaml --mode det --quiet --bind game="$1" -f examples/cards.nlir; }
back() { local data=$1 edited=$2; shift 2; printf '%s' "$edited" > "$TMP/edited.json"
  "$NLIR" --config config.example.yaml --mode det put --bind game="$data" -f examples/cards.nlir --edited "$TMP/edited.json" --alternatives 3 --partial --depth 5 "$@" || true; }
check() { python3 -c "$2" "$1" || { echo "FAIL  $3"; exit 1; }; echo "ok    $3"; }
GAME=examples/data/cards.json
python3 -c "import json;d=json.load(open('$GAME'));d['state']['turn']=1;json.dump(d,open('$TMP/later.json','w'))"

# forward
check "$(run $GAME)" 'import sys,json; assert json.loads(sys.argv[1])=={"played_card":5,"reason":"It is the player'"'"'s first turn and 5 is their highest card"}' \
  "forward: first turn, highest card 5"
check "$(run $TMP/later.json)" 'import sys,json; assert json.loads(sys.argv[1])["played_card"]==1' "forward: a later turn, lowest card 1"

# (a) the card becomes 3: the authored put clamps the hand; the search adds other explanations
OUT=$(back $GAME '{"played_card":3,"reason":"It is the player'"'"'s first turn and 5 is their highest card"}')
check "$OUT" 'import sys,json; r=json.loads(sys.argv[1]); a=r["alternatives"][0]
assert a["source"]=="structural" and [(c["path"],c["new"]) for c in a["changes"]]==[("game/state/hand/3",3),("game/state/hand/4",3)], a
assert json.loads(a["output"])["reason"].endswith("3 is their highest card")' "card 5→3: hand [1,2,3,3,3] (authored put), reason follows"

# (b) the reason says lowest: the rule and the hand both have to change
OUT=$(back $GAME '{"played_card":5,"reason":"It is the player'"'"'s first turn and 5 is their lowest card"}')
check "$OUT" 'import sys,json; r=json.loads(sys.argv[1]); a=r["alternatives"][0]; ch={c["path"]:c["new"] for c in a["changes"]}
assert ch["game/rules/1"].endswith("their lowest card.") and all(ch[f"game/state/hand/{i}"]==5 for i in range(4)), ch' \
  "reason says lowest: rule 2 says lowest and the hand becomes [5,5,5,5,5]"

# (c) on a later turn, the card becomes 5: three different explanations
OUT=$(back $TMP/later.json '{"played_card":5,"reason":"It is a later turn and 1 is their lowest card"}')
check "$OUT" 'import sys,json; r=json.loads(sys.argv[1]); ps=[sorted(c["path"] for c in a["changes"]) for a in r["alternatives"]]
assert ["game/rules/2"] in ps and ["game/state/turn"] in ps and any(len(p)==4 and all(x.startswith("game/state/hand/") for x in p) for p in ps), ps' \
  "later turn, card 1→5: rule 3 says highest, OR turn 0, OR hand [5,5,5,5,5]"
OUT=$(back $TMP/later.json '{"played_card":5,"reason":"It is a later turn and 1 is their lowest card"}' --freeze game/rules --freeze game/state/turn)
check "$OUT" 'import sys,json; r=json.loads(sys.argv[1]); assert r["alternatives"] and all(c["path"].startswith("game/state/hand/") for a in r["alternatives"] for c in a["changes"]), r["alternatives"]' \
  "…with the rules and the turn frozen, only the hand can explain it"

# (d) an action the program never outputs: no input can produce it
OUT=$(back $GAME '{"action":"call_uno","reason":"player has one card left"}')
check "$OUT" 'import sys,json; r=json.loads(sys.argv[1]); assert not r["alternatives"] and "never outputs (action)" in r["note"], r["note"]' \
  "call uno: outside what the program can produce — the program itself must change"
echo "cards: all checks passed"
