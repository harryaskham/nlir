# nlir phrasebook — a compressed language of thought

nlir turns a few sigils into a rich, real message. This is a phrasebook of **reusable idioms**:
learn a shape, fill the slots, and get a whole considered communication act — a reply, a proposal,
a review, a catch-up — in one line you can type straight into pi via the nlir plugin.

Every move here is a **real execution**: each `examples/move-*.sh` runs the nlir binary live and
captures the output, and deterministic showcase cards are re-run + asserted by
`scripts/verify-showcase.py` (a CI gate). Nothing here is theory.

For the vocabulary itself, run **`nlir help`** (aliases `operators`, `ops`): a live, config-derived
reference of every operator — sigil · name · description · [arity · priority · `det` = runs offline /
`llm` = needs a model]. This phrasebook, `nlir help`, and the SPEC operator table all derive from the
same config, so they stay in sync.

---

## The model: SELECT ∘ TRANSFORM ∘ COMPOSE

A move is built from three kinds of step, and they nest:

1. **SELECT** what you're acting on — a literal `'...'`, or a slice of the live chat via message
   ranges: `^-1` (last), `^_-1` (their last), `^*` (all — the whole thread), `0^*-2` (all but the last), ...
2. **TRANSFORM** it — `@` formalise · `:` simplify/plain · `~` distil · `>` expand · `#` subject ·
   `!` negate.
3. **COMPOSE** several pieces into one — `&[a, b, c]` weaves them into one coherent text.

Three **dials** turn the output without changing the content:

| dial | sigils | picks |
|------|--------|-------|
| **tone** | `@` formal · `:` warm/plain · `~` terse | the register |
| **role** | `^` the agent (assistant) · `^_` you, the driver (user) · `^*` all · `^/` system | whose words |
| **time** | `^-1` last · `^_0` first · `0^*-2` a range | which turns |

> Role is **driver-relative**: roles are fixed as assistant (`^`) and user (`^_`), and in the pi
> plugin YOU are the user — so `^_` = your turns, `^` = the agent's turns.

All three composing: `@&[:~0^_-1, 'my amendment', 'my caveat']` = weave [a plain digest of the user's
whole ask, my amendment, my caveat] into one formal reply.

---

## Quick reference (fill the CAPS, type it into pi)

| move | shape | intent | lane |
|------|-------|--------|------|
| counter-reply | `@&[:THEIR_POINT, STANCE, CHANGE, CAVEAT]` | reply: agree, amend, caveat | aur-2 |
| weighed recommendation | `@&[:OPTION_A, :OPTION_B, VERDICT]` | two options + your call | aur-2 |
| partial-accept | `@&[ACCEPT, !REJECT+reason, ALTERNATIVE]` | yes to part, no to part, instead | aur-2 |
| empathetic redirect | `:&[VALIDATE, AGREE, REFRAME, FIX]` | warm de-escalation | aur-2 |
| review verdict | `@&[GOOD, GAP, FIX, VERDICT]` | review work: praise/gap/fix/call | aur-2 |
| terse status | `~&[DONE, BLOCKED, NEXT]` | a standup in one line | aur-2 |
| crisp proposal | `@&[:PROBLEM, FIX, TRADEOFF, ASK]` | a mini-RFC | aur-2 |
| scoped commitment | `@&[DELIVERABLE, BY_WHEN, DEPENDENCY]` | a promise + its fine print | aur-2 |
| risk heads-up | `@&[RISK, WHY_NOW, RECOMMENDATION]` | flag a risk, unprompted, with a fix | aur-2 |
| the escalation | `@&[BLOCKER, IMPACT, ~TRIED, ASK]` | raise a blocker upward as a decision request | aur-2 |
| the feedback ask | `@&[WHAT_I_MADE, SPECIFIC_THING_TO_CHECK, BY_WHEN]` | request targeted review, not vague "thoughts?" | aur-2 |
| change announcement | `@&[WHATS_CHANGING, EFFECTIVE_WHEN, WHAT_YOU_DO]` | announce a change, ending on the action | aur-2 |
| descope proposal | `@&[SQUEEZE, WHAT_TO_CUT, WHAT_TO_PROTECT, PAYOFF]` | trade scope for a date, argued well | aur-2 |
| the retro | `@&[WHAT_WORKED, WHAT_DIDNT, WHAT_TO_CHANGE]` | a sprint retrospective, ending on the change | aur-2 |
| respectful dissent | `@&[!THE_PROPOSAL, MY_REASONING, WHAT_ID_SUPPORT]` | a principled no + a constructive alternative | aur-2 |
| clarifying reframe | `[:RESTATE_THEIR_ASK, 'IS_THAT_RIGHT'?]` | confirm you understood before you act | aur-2 |
| the pre-mortem | `@&["PLAN", !"ROSY_CLAIM", "HEDGE"]` | plan + the risk it hides (via `!`) + your hedge, one heads-up | aur-2 |
| the disagree-and-commit | `@&["RESERVATION", "THE_CALL_STANDS", "IM_FULLY_IN"]` | flag your concern on record, accept the call, commit fully | aur-2 |
| the graceful decline | `:&["CANT_DO_X", "HONEST_WHY", "WHAT_I_CAN_DO"]` | a warm no: the decline + the reason + the door left open | aur-2 |
| the PR summary (pipe) | `git diff \| nlir -e '[#$_stdin, ~$_stdin]'` | a diff → PR title + description (nlir as a smart pipe) | aur-2 |
| the code-review comment (pipe) | `<code> \| nlir -e '@&[~$_stdin, POINT_1, POINT_2]'` | weave a code summary + your review notes into one polished comment | aur-2 |
| the fix-it (pipe) | `<error> \| nlir -e '~(>"the most likely fix for: $_stdin")'` | pipe a traceback → the likely fix (triage says what's wrong; this fixes it) | aur-2 |
| postmortem note | `@&[OWN_THE_MISS, ROOT_CAUSE, PREVENTION]` | own a mistake gracefully | aur-2 |
| meeting recap | `@&[DECIDED, STILL_OPEN, ACTION_ITEMS]` | decision + open questions + owners | aur-2 |
| the nudge | `:&[REMINDER, WHY_IT_MATTERS, LOW_PRESSURE_ASK]` | a warm follow-up, not a pushy chase | aur-2 |
| the shout-out | `@&[WHAT_THEY_DID, THE_IMPACT, THE_THANKS]` | specific, polished recognition | aur-2 |
| dual-register brief | `[@&[FACTS], :&[SAME_FACTS]]` | same facts for engineers (@) AND everyone (:) at once | aur-2 |
| the BLUF | `[~&[FACTS], @&[SAME_FACTS]]` | a skimmable headline first, then the full detail | aur-2 |
| computed brief | `@&[LEAD_IN, <a live calc>, TAIL]` | nlir does the maths and weaves the figure into the sentence | aur-2 |
| register ladder | `[~&[F], :&[F], @&[F]]` | one announcement → terse + plain + formal, all at once | aur-2 |
| the question set | `['ASSUMPTION'?, ...]` | flip your risky assumptions into the questions to ask | aur-2 |
| decision record | `[@&[DECISION], 'OPEN'?, ...]` | the call you're making + the questions it leaves open | aur-2 |
| myth-buster | `@&[!'MISCONCEPTION', 'REALITY']` | correct the record: reject the myth, state the truth | aur-2 |
| FAQ entry | `['QUESTION'?, :'ANSWER', ...]` | jot Q + raw answer → a customer-ready Q&A pair | aur-2 |
| glossary entry | `[~(>'TERM'), :'TERM']` | a term's crisp definition + a plain analogy, together | aur-2 |
| compare-and-contrast | `~(>'the difference between X and Y')` | the one crisp sentence on how two things differ | aur-2 |
| the changelog | `:['ITEM', 'ITEM', ...]` | terse notes → one polished release-note line each (LLM per-line tendency; `&` weaves structurally) | aur-2 |
| reality-check | `@&['LEAD', <a live calc>, 'CLAUSE'?]` | a pointed question carrying a live computed figure | aur-2 |
| templated message | `NAME='V'; @&["...$NAME..."]` | bind a value once, reuse it across the message (double quotes interpolate) | aur-2 |
| computed constant | `NAME='<calc>'; @&["...$NAME..."]` | compute a figure once, reuse it consistently everywhere | aur-2 |
| considered reply | `@(^-1 & 'AMENDMENT')` | amend the agent's last suggestion | aur-1 |
| reasoned no | `@(!^-1 & 'GROUNDS')` | decline, with your reason | aur-1 |
| honest yes | `[@(^-1 & 'AMENDMENT'), ~(>!^-1)]` | yes + an auto devil's-advocate | aur-1 |
| steelman reply | `[~(>@^-1), @(!^-1 & 'GROUNDS')]` | their case at its best, then your reasoned no | aur-1 |
| counter-offer | `[@(!^-1 & 'GROUNDS'), @'ALTERNATIVE']` | decline, then offer the path you'd back | aur-1 |
| weighed decision | `[~(>@^-1), ~(>!^-1), @(^-1 & 'decision: CALL')]` | weigh a proposal both ways, then rule | aur-1 |
| pitch-check | `[@~^_-1, ~(>!^_-1)]` | polish YOUR floated idea + preempt its objection | aur-1 |
| brain-dump | `'a';'b';'c';&;~$` | fold scattered thoughts (via the stack) into one takeaway | aur-1 |
| fork | `>('A' \| 'B')` | lay two options out as a decision memo (kept distinct) | aur-1 |
| tighten | `[<^-1, ~^-1]` | shorten two ways: `<` keeps every fact, `~` keeps the essence | aur-1 |
| plain-english | `~:^-1` | de-jargon a message to plain, accurate language | aur-1 |
| theme-finder | `#['a', 'b', 'c']` | fold a pile of items to the category they share | aur-1 |
| grounded counter | `@(^-1 & 'CHANGE' & ^_-1)` | reply grounded in an earlier point | aur-0 |
| cited synthesis | `@~(0^_-1)` | your whole ask, distilled into one formal line | aur-0 |
| full layered reply | `k=@(^-1 & 'CHANGE' & ^_-1 & 'CAVEAT');[$k,~$k]` | the whole considered response + self-reflection | aur-0 |
| self-red-team | `k=@>'DRAFT';[$k,>!~$k]` | your draft + its strongest rebuttal | aur-0 |
| catch up | `p=~0^*-2;[$p,^_-1]` | rejoin a thread: background + their live question | msm-0 |
| exec brief | `@~0^*-1` | whole thread → a VP-ready paragraph | msm-0 |
| standup | `~0^*-1` | the whole thread in one line | msm-0 |
| the two sides | `[~0^_-1, ~0^-1]` | split a debate by side | msm-0 |
| the common ground | `~(0^_-1 & 0^-1)` | merge a debate → the synthesis (flip of two sides) | msm-0 |
| the ticket | `[#~0^*-1, ~0^*-1]` | chat → titled ticket (subject + summary) | msm-0 |
| plain recap | `:~0^*-1` | whole thread → plain, jargon-free recap | msm-0 |
| tone knob | `[@~0^*-1, :~0^*-1, ~0^*-1]` | one thread, three registers (formal/plain/terse) | msm-0 |
| the handoff dossier | `k=@~0^*-1;[$k, ^_-1, ~$k]` | hand off a thread: brief + what's open + a headline | msm-0 |
| extract a column | `{$0.FIELD}↦[RECORDS]` | pull one field out of every record | msm-0 |
| sum a column | `{$0+$1}⊘({$0.FIELD}↦[RECORDS])` | total a field across a list of records | msm-0 |
| addressed pick | `DESCRIBED_LIST..'DESCRIPTOR'` | grab the item a description points to (`..'the largest'`) | msm-0 |

(Full slot rules + more moves per lane below and in each `CATALOG-<lane>.md`.)

---

## The lanes

### COMPOSE — weave several points into one (aur-2)
`@&[SLOT, SLOT, ...]` — the composer workhorse. Fill the slots for any intent; the **leading op is
the tone knob** (`@`/`:`/`~`); each **slot is transformable** (`:` plain a point · `!` reject a
claim · `~` digest a long reference). Gotcha: flag a *gap* plainly, don't `!` it (that flips its
meaning); keep slots consistent.
Moves: diplomatic counter-reply · weighed recommendation · partial-accept counter-offer ·
empathetic redirect · briefed handoff · review verdict · terse status ping · crisp proposal ·
scoped commitment · risk heads-up · the escalation (`~` digests what you tried) · the feedback ask · change announcement · descope proposal · respectful dissent (`!`-the-proposal) · postmortem note · the retro · meeting recap · the nudge.
Slot rule: a slot takes plain content or ONE transform (`:`/`!`/`~`) — a full train in a slot
(e.g. `:>'term'`) breaks the weave.
List algebra (aur-0/aur-1 verified): `op[list]` = the op applied to the list *rendered as text* — NOT
a structural map (in DET, `!['a','b','c']` prepends "not " ONCE to the whole multi-line render, not
per item). In practice only
`:[list]` reliably maps per-item (the changelog); `@[list]`/`>[list]` are non-deterministic (bloom-last
or weave); reductive `#`/`~`/`<[list]` FOLD to one; `&[list]` WEAVES structurally. The proposed MAP
`↦` would be the true structural per-item map. (msm-0: message RANGES are the SAME algebra — `op^*`
is likewise op-on-rendered-text: `:^*` maps in practice, `@^*` weaves, `~^*` folds; so `↦` would also
enable per-message ops like `@↦^_` = formalise EACH of their turns.)
→ `examples/CATALOG-aur2.md` · `examples/move-aur2-*.sh` · cards `nlir-composer-reply`, `nlir-empathetic-redirect`

### REPLY / AMEND — answer a live suggestion (aur-1)
`@(^-1 & '<your amendment>')` — take the agent's last suggestion, fold in your twist, make it formal
(the grouping is load-bearing).
Moves: considered reply (agree+amend) · honest yes (amend + auto devil's-advocate `~(>!^-1)`) ·
reasoned no (`@(!^-1 & grounds)`) · steelman reply (their best case, then your no) · counter-offer
(decline, then offer a path) · weighed decision (weigh both ways, then rule) · pitch-check (polish +
preempt your OWN floated idea) · decisive close (end a thread with a decision) · brain-dump
(`'a';'b';'c';&;~$` — fold scattered thoughts on the stack into one takeaway; reads no context).
Thinking moves (one per operator): fork (`>('A'|'B')` — two options as a decision memo) · tighten
(`[<^-1, ~^-1]` — shorten keeping every fact vs keeping the essence) · plain-english (`~:^-1` — de-jargon
a message; non-commutative with `:~` = ELI5) · theme-finder (`#[...]` — a pile of items → the category
they share).
→ `examples/CATALOG-aur1.md` · cards `nlir-considered-reply`, `nlir-honest-yes`, `nlir-reasoned-no`, `nlir-decisive-close`

### GROUND / REFLECT — reference prior context + red-team yourself (aur-0)
`@(^-1 & mod & ^_-1 & caveat)` grounds a reply in an earlier point; `k=X;[$k,~$k]` binds your output
and reflects on it (the `=` binding IS the self-reference — no new operator needed).
Moves: grounded counter · cited synthesis · **full layered reply** (the flagship — Harry's whole
example: reply + modify + reference + caveat + restyle + self-reflect, in one line) ·
self-summarizing memo · self-red-team (`k=@>'X';[$k,>!~$k]`).
Which self-critique? **self-red-team** pressure-tests a NEW draft from a blank page; aur-1's
**pitch-check** (`[@~^_-1, ~(>!^_-1)]`) refines an idea you already FLOATED in chat — same instinct
(hear the objection before you send), two entry points.
→ `examples/CATALOG-aur0.md` · `examples/move-aur0-*.sh` · cards `nlir-full-layered-reply`, `nlir-grounded-counter`, `nlir-self-red-team`

### SELECT / DIGEST — read a whole thread (msm-0)
Two selector knobs over the chat: **time** (`0^*-1` whole thread · `0^*-2` all-but-latest · `^_-1`
their last) and **role** (`^`=assistant/the-agent · `^_`=user/you-the-driver · `^*`=all · `^/`=system;
role is relative to who's driving — in the pi plugin `^_`=you, `^`=the agent). Then the **tone knob**
picks the register: `@~0^*-1` formal (brief a VP) · `:~0^*-1` plain (onboard anyone) · `~0^*-1` terse
(a ping). Moves: catch up · exec brief · standup · plain recap · the ticket · the two sides · the common ground · tone knob · the handoff dossier.
These SELECT the input the other lanes TRANSFORM / COMPOSE. The capstone **THE HANDOFF DOSSIER**
`k=@~0^*-1;[$k, ^_-1, ~$k]` composes this SELECT with aur-0's self-reflection: a thread's formal brief
+ what's still open + its own one-line headline.
Gotcha (thanks aur-0): `=` binds an **expression**, so quote string values containing operators or
spaces — `_sep='--'` not `_sep=--` (a bare `--` parse-errors: "operator - not valid in prefix
position"). Also: an out-of-bounds RANGE clamps (`0^_-99`→first user), a single out-of-bounds INDEX
errors (`^_-9`→"no message") — windows are forgiving, precise picks are strict.
→ `examples/CATALOG-msm0.md` · cards `nlir-catchup`, `nlir-exec-brief`, `nlir-ticket`, `nlir-plain-recap`, `nlir-two-sides`, `nlir-common-ground`, `nlir-tone-knob`, `nlir-handoff`

---

## How the lanes stack
**SELECT** (msm-0) a slice → **TRANSFORM** (aur-1) or **COMPOSE** (aur-2) it → **REFLECT** (aur-0) on
the result. For example:

    k=@&[:~0^_-1, 'but scope it to the mobile client', 'mindful of the Q3 freeze'];[$k,~$k]

= digest their whole ask, weave in your amendment + caveat, formalise it, then append its own gist.
SELECT chooses the words, the tone knob chooses the register, the composer chooses the structure.

---

## Programs on thoughts — map & fold

`map` and `fold` turn nlir from moves into **small programs**. A form `{…}` is the
step; `$map%(form, list)` runs it over each item, `$fold%(form, list)` reduces the
list with it — and the glyphs **↦** / **⊘** are terser aliases (`{$0*$0}↦[1,2,3]` = map,
`{$0+$1}⊘[1,2,3]` = fold). The **structure is deterministic** — the iteration and the reduction are
pure — while the **step is where det or llm plugs in**. That split is the whole point:
exact scaffolding, fuzzy steps. (A list result renders as its elements, one per line —
not bracketed — so it stays a first-class operand and `fold∘map` pipelines compose.)

**Pure structure — det all the way:**

    $map%({$0*$0},[1,2,3])                   → 1, 4, 9   (square each; one per line)
    $fold%({$0+$1},$map%({$0*$0},[1,2,3]))   → 14        (sum of squares, fold∘map)
    $fold%({$0*$1},[1,2,3,4])                 → 24        (product)

**Structure det, steps fuzzy — the flagship mix:**

    $fold%({$0+$1},['3 apples','5 oranges','2 pears'])   → 10

The `+` reduce is deterministic; the string→number *extraction* is the llm step.
Proof: in `--mode det` this same expression **errors** — `cannot coerce '3 apples' to
number` — because nothing structural can read "3 apples" as 3. In llm mode the model
extracts 3, 5, 2 and the exact `+` sums them. **Fuzzy-extract, exact-sum, one line.**

    $fold%({$0+$1},['yes','no','yes','yes'])             → tally the yeses

Same shape: the llm maps yes→1 / no→0, the det `+` counts.

**Fuzzy per item, structural on the outside:**

    $map%({~$0},[note1,note2,note3])              → distil each note
    $map%({@$0},['lmk if any Qs','pls advise'])   → formalise each
    $fold%({~($0&$1)},[view1,view2,view3])        → weave a list of views into a running consensus

Rate a list of ideas and average the scores; distil every meeting note then weave
them into one summary — a four-character algorithm that operates on *meaning*. The
model judges each item; the structure aggregates them. Repeatable programs, fuzzy steps.

---

## Records & accessors — labeled data + `.`/`..`

A **dict** `{k=v, k2=v2}` bundles labeled values (a record). A `{…}` is a dict when its body
is a comma-list of `key=value` bindings; a single compute expression like `{$0*2}` is still a
**form** (code) — so data and code share one brace but never collide. `.` reads structurally;
`..` is its LLM twin, reading by description.

**`.` — structural access (det), polymorphic on what's on the left:**

    [a,b,c].1                       → b      (0-based list index; `.-1` → last)
    {host='web1',port=8080}.port    → 8080   (dict field by name)
    "the".2                         → e      (char at index)

Out-of-range or a missing key is a **loud error**, never a silent empty.

**`..` — semantic access (llm), the twin of `.`:** reads the element a *description* points to.

    'the planets from the sun'..3                     → earth
    'the planets from the sun'..'the last'            → Neptune
    'apple, kiwi, watermelon'..'the largest fruit'    → watermelon

`.` counts positions; `..` understands what you're pointing at — the same det↔llm duality as
`~>` and `@`↔`=>`.

**Records compose with map & fold — the payoff:**

    {$0.name}↦[{name=alice,age=30},{name=bob,age=25}]     → alice, bob   (extract a column)
    {$0+$1}⊘({$0.age}↦[{name=a,age=30},{name=b,age=25}])  → 55           (sum a field across records)
    ?%({mode=fast}.mode, go, stop)                         → go           (branch on a record field)

Pull a field out of every record (a `map` of `.`), then `fold` the column to one answer — "sum
the ages", "count the opens" — no loop, no special case. Labeled data slots straight into the
same map / fold / if machinery as everything else.

---

## Generation — write new text with `=>`

The lanes above **restyle** text with fixed verbs (`@` formal · `:` plain · `~` terse). **`=>`** is
the OPEN verb: it takes its operand as an **instruction** and returns *only the result of following
it* — free generation, not a fixed transform. It's the llm twin of `@` (the `@`↔`=>` duality): `@`
restyles text you already have, `=>` **writes new text to order**. `=>` is llm-only; its `det` stub
just echoes the (interpolated) instruction, so `--mode det` stays green and the structure is
verifiable offline.

**OBEYS — it does exactly what the instruction says, including format/length constraints:**

    =>"write exactly: shipped"                  → shipped
    =>"a haiku about shipping code on friday"   → Tests are green, ship it—
                                                  what could go wrong on Friday?
                                                  Pager screams at dawn.

The generative frame ("treat the operand as an INSTRUCTION, return ONLY the result — no preamble,
obey any length/format constraint") lives in the **model config, not the op**, so `=>` obeys by
construction — even on weaker models. (`--mode det` echoes the stub: `=>"write exactly: shipped"`
→ `response: write exactly: shipped`.)

**INTERPOLATE — double quotes splice live values into the instruction:**

A `"double-quoted"` operand interpolates `$name` bindings and `$_stdin` **before** the model sees it;
`'single quotes'` are literal (a literal `$name` reaches the model unchanged). That's what makes `=>`
context-aware — the **reply-generation idiom** is: SELECT a turn, then `=>` writes the reply.

    t=^-1;=>"a one-sentence reply, agreeing and offering to help, to: $t"
    → Sounds great — happy to help by drafting test cases for the `.`/`..` accessors or reviewing
      the Dict API design as you go, just let me know what'd be most useful this afternoon.

`^-1` selects the last turn, `t=…` binds it, and `"…: $t"` splices it into the instruction.

**COMPOSE — `=>` is a normal operand, so it drops straight into the composer:**

Generate several pieces, then weave them into one coherent text — pipe in a proposal and
acknowledge-then-counter it in a single formal reply:

    <proposal> | @&[=>"a brief acknowledgement of: $_stdin", =>"a one-sentence gentle counter to: $_stdin"]
    → Agreed — Friday will work well. I would suggest that we release the stable core on that day
      and defer any higher-risk elements until Monday, so as to avoid troubleshooting over the weekend.

SELECT ∘ GENERATE ∘ COMPOSE: pick the input, `=>` writes the pieces, `@&[…]` weaves them into one
— the fixed transforms and the open verb in the same one-liner.

→ `examples/move-aur2-generate.sh` · `nlir help` (INSTRUCTION-FOLLOWING) · SPEC operator table · design `docs/design/agent-vocabulary.md` §3d

---

## Pipe-native — det+fuzzy in a unix pipe (why nlir, not a prompt)

The move a plain LLM prompt can't clone: nlir sits **mid-pipe** and **mixes exact
computation with fuzzy judgment** in one expression. Piped stdin is `$_stdin`, `//`
splits it to a list of lines, `↦`/`⊘` map/fold with det OR llm steps. sgu24-app's test:
if you can't say why it isn't just one LLM prompt, it's a weak example — these pass it
because a raw model can't do reliable exact arithmetic and no single unix tool can do
the fuzzy half.

    printf '3 apples\n5 oranges\n2 pears\n' | nlir -e '{$0+$1}⊘($_stdin//"\n")'   → 10
      fuzzy-sum: the model reads each line's count, the EXACT `+` sums — a prompt can't be trusted to add.

    logs | nlir -e '?%({$0+$1}⊘({$contains%($0,"ERROR")}↦($_stdin//"\n"))>=2,"page on-call","all clear")'
      count-and-branch (DET, offline): grep + wc + if collapsed into one pipe stage.

    reviews | nlir -e '{$0+$1}⊘({$0~>"a complaint"}↦($_stdin//"\n"))'   → 2
      semantic grep → count: fuzzy per-line judgment, then an EXACT count. grep can't judge; a prompt can't count.

    git log --oneline | nlir -e '#($_stdin//"\n")'
      semantic awk: fold a list of commits to their shared subject — awk with understanding.

`$_stdin` · `//` split · `↦`/`⊘` map/fold · `~>` implication · `#` subject — det scaffolding,
fuzzy steps, sitting between grep and awk. Run them live: `bash examples/move-msm0-pipe.sh`.

---

## See it / run it
- **Cards** (sigils rendered literally + typeably): `showcase/` → the GitHub Pages `showcase.html` gallery.
- **Run any move for real**: `bash examples/move-<lane>-<name>.sh`.
- **Per-lane detail**: `examples/CATALOG-<lane>.md`.
