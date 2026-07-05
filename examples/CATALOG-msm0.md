# msm0 gallery catalog

A curated index of the **msm0** nlir-golf contributions — 46 forward concepts + 45
reverse targets — grouped by theme. (The workspace-wide sample lives in
`examples/README.md`; this file is a per-agent deep-dive. Run any entry with
`NLIR=./target/release/nlir bash examples/<name>.sh`, or set `NLIR_CONFIG`.)

**See any move as a graph.** Every expression here renders to its computational
*dataflow graph* — `nlir show 'EXPR' --png g.png` (or `--save-animation g.apng` to
watch it reduce step-by-step, or the live wasm workspace's Graph ◇ / Animate ▸).
Operand edges trace the transform chain; dashed edges resolve each `k=…` binding to
the `$k` reads it feeds. So a move is both a line you *type* and a graph you *see*
(graph-viz: G0 model + G2 frames mine · G1 SVG + G5 wasm aur-1 · G3/G4 CLI aur-2).

The organising idea, arrived at over the night: **nlir = SELECT × TRANSFORM** — a
message range *addresses* a conversation, and the operator basis *transforms* what you
address (see `golf-msm0-40-selection.sh`).

## Forward (max-concept) — `golf-msm0-*`

### Conversation ranges (the SELECT half — my signature)
*A bare view sigil = its whole channel: `^*` ≡ `0^*-1` (whole thread) · `^_` ≡ all user · `^` ≡ all assistant · `^/` ≡ all system. So every `~0^*-1` form below also writes as `~^*` — the range spelled out here for clarity, the bare form for speed.*
- `01-history`  crux `#~0^*-1` — auto-title a whole chat
- `03-arc`  `~(^_0&^-1)` — first user ask + last assistant answer = the takeaway
- `04-twosides`  `[~0^_-1,~0^-1]` — role-scoped ranges: their side | our side
- `06-topics`  `#0^*1&#2^*-1` — sub-range slices name each half's topic
- `16-catchup`  `p=~0^*-2;n=^*-1;…` — exclude-last background + latest verbatim
- `35-timeline`  `[~0^*1,~2^*3,~4^*-1]` — sequential windows = a narrative arc
- `40-selection`  `[~0^*-1,~0^_-1,~^*-1]` — one transform, three addresses (the capstone)

### Assignment / DAG-reuse
- `02-debate`  `c=~0^*-1;[@$c,:!$c]` — one summary, case for/against
- `05-digest` · `12-status` · `13-postmortem` · `15-fanout` (`s=~0^*-1;[#$s,$s,!$s]`) · `23-identity` (what assignment guarantees)

### Interpolation (output-side templates + input-side prompt construction)
- `07-subject` · `08-flcard` · `09-email` · `11-toc` — templated cards
- `17-followup` · `18-announce` · `19-drafted` — a computed value spliced INTO the prompt

### Document formats (one toolkit, many moulds)
- `21-faq` · `22-adr` · `33-commit` · `46-changelog`

### The algebra of nlir (operator laws — with aur-1 & aur-2)
- `30-basis` ops = orthogonal axes (register/information/polarity) · `31-commutativity` commute ⟺ orthogonal · `32-matrix` span the plane
- `24-associativity` `~(whole)≈~(~half&~half)` · `25-demorgan` half-holds · `26-and-algebra` `&` is a join, not `∧`
- `27-invariance`/`28-orthogonality`/`37-collapse`/`38-regcollapse`/`39-boundary` — `#`/`~` charted on {register,information}; where laws break
- `20-phrasing` · `29-joinblind`

### Deterministic substrate + robustness (dogfooding)
- `34-powertower` (the fleet pow right-assoc fix) · `36-calculator` nlir with the LLM off · `45-numedges` arithmetic boundaries
- `41-graceful` never panics · `42-session` nlir as memory · `43-grouping` load-bearing parens · `44-quotes` raw vs cooked (+ filed bd-65b737)

## Reverse (target) — `target-msm0-*`
All use `@` as a **formalise-decompressor** (terse seed → the full sentence).
- **Compression records:** `01-formalize`(15c) → `02-microcompress`(@'omw',5c) → `04-brb`(3c) → `05-onechar`(@'k',1c — the floor).
- **Realistic pi turns:** reviews (`09`,`22`,`43`), standup/status (`07`,`08`,`16`), escalation/blocker (`21`,`28`), decisions (`13`,`19`,`31`,`44`), personal notes (`20`,`32`,`38`,`39`,`40`,`45`), and more — each reconstructs a full professional message from a dashed-off seed, preserving the facts, the structure, and the *stance* (the "however", the hedge, the warmth).

## Two real bugs found dogfooding
- **pow right-associativity** (`2**3**2` was 64, should be 512) — caught, fixed three-lane, landed; celebrated in `34-powertower`.
- **`\$` escape defeated** in double-quote interpolation (bd-65b737) — root-caused, filed with a proposed patch; workaround documented in `44-quotes`.

---

## Showcase power-moves — multi-message digest/select (Harry's "language of thought")

My lane in the swarm's shared phrasebook (`nlir-power-moves`, per the aur-0/aur-1/aur-2/msm-0
lane split): moves that address a **range** of the conversation, not just the last turn.
Captures below are real `--mode llm` (copilot/claude) runs on a 5-turn billing-design thread
(*event-sourcing? → simpler ledger → "how do refunds work?"*).

**▶ Every capture here is a live execution, not theory.** Reproduce any of them:
```sh
cd <checkout> && printf '%s' '{"_messages":[{"role":"user","content":"..."}, ...]}' > /tmp/ctx.json
target/release/nlir --mode llm --config config.example.yaml --context-file /tmp/ctx.json --quiet -e 'EXPR'
```
The showcase cards carry the same real outputs (their `llm · reads your whole thread` pill marks the live backend).

### ★ CATCH-UP — `p=~0^*-2;[$p,^_-1]`
Rejoin any conversation in one glance: the thread-so-far **distilled**, then their **live
question verbatim**. (Bind the all-but-last background as a summary `p`, then emit
`[background, latest-ask-raw]`.) The one I'd actually reach for stepping back into a chat.
> The team debated event-sourcing versus a simpler append-only ledger for the new billing
> service, settling on the ledger approach given team size.
>
> ok but how do we handle refunds and corrections in an append-only model?

### STANDUP — `~0^*-1`
The whole thread in one line — a status you could paste into a standup.
> The team debates whether to use event-sourcing or a simpler append-only ledger for a new
> billing service, and how to handle refunds/corrections under the latter approach.

### ARC — `~(^_0 & ^_-1)`
Where we started + where we are, synthesised into the through-line. (Honest note: `~(a&b)`
**merges** the endpoints into a resolution rather than **contrasting** them — a true
trajectory/"drift" read wants a directional DIFF op `Δ`, still unbuilt. As-is it reads as
the through-line, which is itself useful.)
> The billing service should use an append-only model, handling refunds and corrections as
> new compensating entries rather than modifying past records.

**Why this is my lane:** each move is `TRANSFORM(range)` — the range (`0^*-2`, `^_0`, `^*-1`)
*selects* which slice of the conversation you mean; the operator (`~`, `#`, `[]`) *transforms*
it. Single-message reply/amend moves (aur-1) and composer slots (aur-2) compose ON TOP of
whatever these select.

### ★ EXEC BRIEF — `@~0^*-1`
"Brief the VP in 10 minutes." A messy multi-turn incident thread → one formal, forwardable
paragraph. `~0^*-1` distills the whole thread; `@` lifts it to a professional register. The
formal-register companion to CATCH-UP (catch *yourself* up vs brief *someone else* up). Real
capture on a 5-turn incident thread (500s after deploy → 2026-expiry bug → rollback? → hotfix):
> The 2:00 PM deployment introduced a defect in the checkout process, causing valid cards with
> a 2026 expiration date to be incorrectly rejected. As the deployment also included a live
> fraud-rule migration, reverting it was considered too risky. Consequently, the team will
> implement an expedited hotfix to the expiration date validation logic ahead of the upcoming
> VP briefing.

### THE TICKET — `[#~0^*-1, ~0^*-1]`
Turn a messy chat into a titled ticket: a subject line + a one-line summary, ready to file as
an issue/PR/doc header. `#~0^*-1` names the thread (title); `~0^*-1` summarizes it. Real capture
on a 5-turn scoping thread (fuzzy matching? → latency tradeoff → fallback → "cap at edit-distance 2"):
> **Fuzzy matching fallback**
> The team decided to add fuzzy matching only as a fallback when exact search returns no
> results, capped at edit-distance 2.

### THE PLAIN RECAP — `:~0^*-1`
Explain the whole thread like someone just walked in: `~0^*-1` distills it, `:` drops the jargon
into plain language. The **tone-knob sibling** of EXEC BRIEF (`@~0^*-1`, formal) — same whole-thread
SELECT, different register (aur-2's tone-knob: `@` formal for an exec, `:` plain for a newcomer,
`~` terse for a ping). Real capture on a 4-turn API-freeze debate:
> Some computers are having big problems, and the people fixing them need extra time. But another
> team already told everyone a big launch would be ready by a certain day. So now there's a hard
> choice: fix the problems first and be a little late, or keep the promise and launch on time.

**Role-channel SELECT — CORRECTION (I was wrong last tick):** role selection is NOT a gap; I
had the syntax wrong. The role *views* already exist: `^` = assistant (our side), `^_` = user
(their side), `^*` = all roles, `^/` = system (config.rs `views:`). "All of one role" is just a
*range over a view*: `0^_-1` = every user message, `0^-1` = every assistant message. My failed
`^_*` mixed two view markers (`_` and `*`) — invalid, hence the empty-reduce error. No feature is
missing; TWO-SIDES works today (below).

**Role is DRIVER-RELATIVE (pin this for the pi plugin):** `^`/`^_` mean different sides depending
on who's at the keyboard. When an AGENT drives nlir (my cards' context), `^_` = the user = "their
side", `^` = the assistant = "our side". When HARRY drives nlir via the plugin, HE is the user, so
`^_` = HIS own messages and `^` = the agent's (what he's replying to). Same sigils, mirrored by
seat. (This makes aur-0's grounded-counter read exactly right: `^-1` = the agent's suggestion,
`^_-1` = Harry's own constraint.)

### THE TWO-SIDES — `[~0^_-1, ~0^-1]`
Split a debate/negotiation by ROLE: `^_` selects every USER turn (their side), `^` every ASSISTANT
turn (our side); `~` distills each channel to its position. The role-channel SELECT (vs the
time-based ranges of CATCH-UP/EXEC-BRIEF). Real capture on a 4-turn negotiation (ship-by-Friday vs
needs-two-weeks):
> **Their side** — The team needs the payments feature shipped by Friday, with a proposal to release
> a beta Friday and general availability two weeks later.
>
> **Our side** — Engineering wants two weeks for testing and a security review, but a flagged beta
> could ship Friday if limited to internal users first.

### THE COMMON GROUND — `~(0^_-1 & 0^-1)`
The flip-side of TWO-SIDES: instead of splitting the debate, MERGE both role channels (`^_` their
whole side & `^` ours) and distil → where the discussion actually LANDS. Honest — if the thread
hasn't converged it says "still debating…", so it doubles as a "have we reached agreement?" check.
Real capture on the same 4-turn negotiation (ship-by-Friday vs needs-two-weeks):
> The team agrees to ship a flagged internal beta by Friday, with GA in two weeks pending full
> testing and security review.

**The role-channel pair:** `[~0^_-1, ~0^-1]` SPLIT (each side apart) · `~(0^_-1 & 0^-1)` MERGE (the
synthesis). Same two channels, list vs join — the SELECT structure choosing contrast vs consensus.

### THE HANDOFF DOSSIER — `k=@~0^*-1;[$k, ^_-1, ~$k]`
The fullest msm-0 move: hand a whole thread to a successor as a three-part dossier — bind a formal
brief (`k=@~0^*-1`), then emit **the brief** (`$k`) + **what's still open** (`^_-1`, the live ask
verbatim) + **a one-line headline** (`~$k`, a self-reflection on the brief). This is my SELECT lane
composed with aur-0's self-reflection primitive (`k=X;…~$k`) — SELECT ∘ REFLECT. Real capture on the
5-turn incident thread:
> **the brief** — The 2:00 PM deployment introduced a defect that rejected cards with a 2026 expiry
> date. Rather than a risky rollback (which would also revert an already-deployed fraud-rule
> migration), the team is implementing an expedited hotfix.
>
> **what's still open** — ok do the hotfix but i need to brief the VP in 10 minutes
>
> **the headline** — The 2pm deploy broke checkout by rejecting valid 2026-expiry cards; the team is
> pushing a targeted hotfix instead of rolling back, to avoid reverting the fraud-rule migration.

### THE DUAL-REGISTER BRIEF — `(@~^-1)&(:~^-1)`
One message, two audiences. Take the proposal just made (`^-1`, last assistant), reduce it to its
gist (`~`), and emit that gist in BOTH registers at once — formal (`@`, for the senior reader) AND
plain (`:`, for the newcomer) — `&`-joined into one text. The FORK-JOIN shape: one source `~^-1`,
two register transforms, joined (the shared `~^-1` realises once, cache-deduped). Real capture on a
wasm-gating proposal:
> (Native-only crates and effectful backend functions are gated behind a default-on `native` Cargo
> feature, with error-returning stubs provided otherwise. This allows the synchronous path to continue
> linking successfully while WebAssembly drives the asynchronous evaluator via JavaScript callbacks.)
> **and** (Some parts of the code only work on a regular computer, not inside a web browser. Those
> parts are switched on by default. But when the code runs in a web browser instead, it uses pretend
> stand-in pieces that just say "sorry, can't do that here" — so everything still fits together and
> nothing breaks. This way, the regular computer version keeps working the normal, step-by-step way,
> while the web browser version waits and lets JavaScript tell it when things are ready.)

The register axis (`@`↔`:`) applied as a FORK, not a dial (cf. `20-phrasing`): don't *pick* a
register — ship both, the same fact for two readers in a single send. SELECT one turn, TRANSFORM it
two ways, JOIN.

### THE GRADUATED EXPLAINER — `[~^-1, ^-1, >^-1]`
The DEPTH dial (sibling of the register dial): the same turn at three zoom levels in ONE message —
gist (`~`) · verbatim (`^-1`) · deep-dive (`>`) — so the reader picks how far to read. SELECT one turn,
TRANSFORM it three ways along the information axis, list. Real capture on the realiser-seam turn:
> [gist] The nlir evaluator uses an injectable async realiser trait to separate its pure evaluation
> core from platform-specific effects, letting the same evaluator run against both native (HTTP/bash)
> and browser (JS callback) backends.
>
> [verbatim] The realiser seam abstracts the effectful half of nlir evaluation behind an injectable
> async trait, so one evaluator serves both the native CLI (which calls HTTP and bash directly) and
> the browser (which calls JavaScript callbacks), without the pure evaluation core ever depending on
> either backend.
>
> [deep-dive] The realiser seam is the architectural boundary that cleanly separates the effectful
> half of nlir evaluation — the portions that must reach out and perform side effects, such as issuing
> network requests or executing shell processes — from the pure, deterministic core … all the messy,
> environment-dependent effect-handling is pushed out to the edges of the system. [3 paragraphs]

Where the dual-register brief forks on REGISTER (`@`↔`:`, *who* reads), this forks on DEPTH
(`~`↔verbatim↔`>`, *how much* they read) — the two independent axes of "one message, many readers".

## Gotchas (verified with aur-0's QA)
- **`=` binds an EXPRESSION, so quote string values with operators or spaces.** `_sep=--`
  parse-errors ("operator - not valid in prefix position"); write `_sep='--'` (or escape: `_sep=\-\-`).
  Same for spaces/special chars in any bound value. Bindings of nlir sub-expressions (`p=~0^*-2`,
  `k=@~0^*-1`) are fine — it's *literal string* values needing the quotes.
- **Range clamps, index errors.** An out-of-bounds RANGE clamps to what exists (`0^_-99` → the first
  user turn); a single out-of-bounds INDEX errors (`^_-9` → "no message"). Windows are forgiving;
  precise picks are strict — so `0^_-1` safely means "all their turns however many there are".
- **`.sh` proofs renamed `move-msm0-*.sh`** so verify-showcase.py `--examples` (default glob
  `idiom-*.sh,move-*.sh`) runs them end-to-end — every msm-0 card is executed live in the audit, not just deferred.
