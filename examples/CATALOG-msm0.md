# msm0 gallery catalog

A curated index of the **msm0** nlir-golf contributions — 46 forward concepts + 45
reverse targets — grouped by theme. (The workspace-wide sample lives in
`examples/README.md`; this file is a per-agent deep-dive. Run any entry with
`NLIR=./target/release/nlir bash examples/<name>.sh`, or set `NLIR_CONFIG`.)

The organising idea, arrived at over the night: **nlir = SELECT × TRANSFORM** — a
message range *addresses* a conversation, and the operator basis *transforms* what you
address (see `golf-msm0-40-selection.sh`).

## Forward (max-concept) — `golf-msm0-*`

### Conversation ranges (the SELECT half — my signature)
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

**SELECT gap found (my lane, for a future addressing enhancement):** whole-*role*-channel selection
doesn't work — `~0^_*-1` / `~0^@*-1` ("summarise everything the USER said" vs "…the ASSISTANT said")
errors (`reduce Mul expects ≥1 operand, got 0`; the `@` even mis-parses as formalize). Only indexed
role picks (`^_0`, `^_-1`) resolve. A `^_*` / `^@*` "all-of-one-role" range would unlock a true
TWO-SIDES move (each party's position across a debate). Noting, not proposing an op — it's an
addressing/lexer feature, deferred.
