# CATALOG — aur1's nlir lane (a navigable deep-dive index)

My lane is **cognition, composition, and the reply idioms** — what the sigils
*mean* when you compose them, and the reusable "moves" you can retype yourself.
Two layers:

- **The moves** (§0) — the showcase idioms: 13 reusable "moves" you retype
  yourself. The *reply family* (agree / decline / decide, sharing ~7 sigils) plus
  the *thinking moves* (one per operator: the stack, the role knob, OR, shorten,
  simplify, `#`-over-a-list). This is what the phrasebook
  ([`phrasebook.md`](./phrasebook.md)) links here for.
- **The operator algebra** (§1–§6) — the laws underneath: *why* the moves compose
  the way they do (repetition-dynamics, commutativity, the `?`-projection, the
  stack, the `?`-target palette, and the honest rejects).

Where msm0's lane charts SELECT (message ranges) and aur2's the coercion/types
substrate, mine TRANSFORMS. Every showcase card is a real, reproducible execution
— checked by [`scripts/verify-showcase.py`](../scripts/verify-showcase.py).
Run any example directly: `./examples/idiom-aur1-NN-*.sh` (or the older
`golf-aur1-NN-*.sh` algebra probes).

---

## 0. The moves — the showcase idioms

### 0a. The reply family — answer a live suggestion

A learnable vocabulary for replying to an agent's message (`^-1` = the agent's
last turn · `^_-1` = yours · `0^*-1` = the whole thread). Learn the pieces once,
recombine them forever.

| # | move | say it | what it does |
|---|---|---|---|
| 1 | considered reply | `@(^-1 & 'AMENDMENT')` | agree with their suggestion, folding in your amendment, made formal |
| 2 | decisive close | `@(~0^*-1 & 'DECISION')` | end a whole debate with your call, grounded in what was said |
| 3 | honest yes | `[@(^-1 & 'AMENDMENT'), ~(>!^-1)]` | your reply + an auto devil's-advocate on your own yes |
| 4 | reasoned no | `@(!^-1 & 'GROUNDS')` | decline, on your grounds, professionally |
| 5 | steelman reply | `[~(>@^-1), @(!^-1 & 'GROUNDS')]` | their case at its best, then your reasoned no |
| 6 | counter-offer | `[@(!^-1 & 'GROUNDS'), @'ALTERNATIVE']` | decline, then offer the concrete alternative you'd back |
| 7 | weighed decision | `[~(>@^-1), ~(>!^-1), @(^-1 & 'DECISION')]` | the case for, the case against, then your verdict |

**The family, by stance:**
- **Yes** — considered reply (yes + your amendment) · honest yes (yes + the doubt).
- **No** — reasoned no (no + grounds) · steelman (their best case, then no) · counter-offer (no + the path).
- **Decide** — decisive close (close a thread) · weighed decision (rule on a proposal).

**Two building blocks recur** (why 7 moves need only ~7 sigils): the *considered
reply* `@(^-1 & '…')` and its negation the *reasoned no* `@(!^-1 & '…')`. Wrap
either in `~(>…)` to argue it, pair them in a `[…]` list to weigh two beats, and
prefix `@`/`:`/`~` to set the register. Cards: `nlir-{considered-reply,
decisive-close, honest-yes, reasoned-no, steelman-reply, counter-offer,
weighed-decision}.png`. Runnable proofs: `examples/idiom-aur1-01..07-*.sh`.

### 0b. The thinking moves — one per operator

Beyond replying, a move for each core operator — so nearly the whole sigil set
(`@ ~ ! & | : > < # ^ ^_ $ ;`) is now something you can *type*, not look up.

| move | say it | what it does |
|---|---|---|
| brain-dump | `'a'; 'b'; 'c'; &; ~$` | jot scattered thoughts onto the **stack**, fold (`&`), distil to the takeaway (`~$`) |
| pitch-check | `[@~^_-1, ~(>!^_-1)]` | **role knob** `^_` — polish your OWN floated idea + surface the objection to preempt |
| fork | `>('A' \| 'B')` | **OR** `\|` — two options in an either/or, expanded into a decision memo (paths kept distinct) |
| tighten | `[<^-1, ~^-1]` | **shorten** `<` — two ways to compress: `<` keeps every fact, `~` keeps the gist |
| plain-english | `~:^-1` | **simplify** `:` — de-jargon an answer to crisp plain English (order: `~:` pro, `:~` ELI5) |
| theme-finder | `#['a','b','c']` | `#` **over a list** — fold several scattered items to the one category/theme they share |

Each mines a different feature (the stack `; & $` · the role knob `^_` · OR `|` ·
shorten `<` · simplify `:` · `#`-over-a-list), and several teach a law: the
tighten shows `<` vs `~` (info-floor vs essence), the plain-english shows
non-commutativity (`~:` ≠ `:~`), the fork shows `>` FORKS over `|`. Cards:
`nlir-{brain-dump, pitch-check, fork, tighten, plain-english, theme-finder}.png`.
Runnable proofs: `examples/idiom-aur1-08..13-*.sh`.

---

## 1. The algebra of nlir (operator laws) — my central theme

The operators aren't a bag of tricks; they obey **laws**. Discovered collaboratively
with msm0's semantic basis (#30: ops = orthogonal axes — `@` register / `~`
information / `!` polarity / length). My contributions:

### Repetition-dynamics — what happens when you repeat one operator (COMPLETE)
- `golf-aur1-05-recursion` — `~/~~/~~~` **intensifies** (distils harder each pass).
- `golf-aur1-23-fixpoint` — `@@@x` **register ceiling**: `@` saturates after one pass, then rewords.
- `golf-aur1-25-involution` — `!!x = x`: negation is an **involution** (period 2).
- `golf-aur1-35-floor` — `<<<x` asymptotes to an **information floor** (keeps ALL facts, tightens wording).
- `golf-aur1-43-kernel` — `~` converges to an **essence kernel** (sheds facts to the ONE core).
  → The floor pair: `<` = tightest COMPLETE statement; `~` = the single ESSENTIAL point.

### Composition laws — how two operators interact
- `golf-aur1-26-noncommute` — `@:x ≠ :@x`: composition **doesn't commute** (the outer op wins the register).
- `golf-aur1-27-distributivity` — `@a&@b ≈ @(a&b)`: `@` **distributes** over the join (pointwise).
- `golf-aur1-29-synthesis` — `~(a&b) ≠ ~a&~b`: `~` does NOT — grouping = **synthesis** (finds the relationship).
- `golf-aur1-28-roundtrip` — `<>x ≠ x`: `<`/`>` are **relative**, not inverses (a negative result).

### The `?`-projection — the cleanest object in the algebra
- `golf-aur1-36-absorb` — `!x? ≈ x?`: `?` **absorbs polarity** (a yes/no question is polarity-neutral).
- `golf-aur1-37-factor` — `?` **factors through content**: strips register (`@x?≈x?`), respects info (`>x?≠x?`).
- `golf-aur1-39-projection` — `x?? ≈ x?`: `?` is **idempotent** ⇒ with #36/#37, a genuine **projection** (P²=P).

### Structure
- `golf-aur1-41-flatlist` — `[[a,b],[c,d]] == [a,b,c,d]`: **lists flatten** (construction is associative).

---

## 2. The cognitive FORMATS toolkit — reusable thinking-tools

### Dialectic / debate
- `01-cognition` `~(x&!x)` (hold a contradiction) · `08-steelman` `[>@c,<:c]` · `09-panel` `~[@c,!c,:c]`
- `13-tempered` `~(x&>@!x)` (the balanced take) · `31-procon` `[>x,>!x]` (symmetric) · `34-fairhearing` `[>@!x,@x]` (steelman the OTHER side)

### Perspective / zoom / register
- `06-perspective` `[:c,@c]` · `24-zoom` `'<doc>';[#$,~$,>$]` (three altitudes) · `32-registergrid` `@~x`=exec-summary / `:>x`=friendly-walk
- `40-fivelenses` `[#x,~x,!x,x?,@x]` (one claim, five independent views) · `44-bluf` `[~x,>x]` (bottom line up front)

### Distillation / focus
- `19-lengthdial` `[<c,>c]` · `22-telephone` `~(>~x)` · `30-focusfinder` `ramble?` (a wall of worry → one question)

### Other tools
- `07-consensus` `~[o1,o2,o3]` · `12-counterfactual` `>!x` · `15-merge` / `16-diff` (the `~(a&b)` polymorphism)
- `20-redteam` `!^-1` · `21-reviewkit` `^-1;[!$,$?]` · `42-fork` `>(a|b)` (a binary choice → a decision memo)

---

## 3. Message-reads — conversation-aware expressions

- `04-alignment` `~(#^_-1&#^-1)` · `10-drift` `[#^_0,#^_-1]` · `14-followup` `^-1?`
- `33-arc` `~(^_0&^_-1)` (first + last USER turns = the drift/trajectory)
- `38-clarifier` `~^_-1?` (a vague ask → the confirm-the-intent question)
- `45-loopcloser` `~(^_0&^-1)` (first user QUESTION ⋈ last assistant ANSWER = problem→solution capsule)

---

## 4. The stack as working memory — the premise-stack's THREE exits

- `02-stackmachine` `3;4;+;5;*` (RPN) · `03-workingmem` `$-2` · `18-compare` `'A';'B';~($-2&$)`
- **Premise-stack, three exits** (push bullets, `&`-fold, then):
  - `17-accumulator` `&;~$` → compress to **the point**
  - `46-briefbuilder` `&;>$` → inflate to **prose**
  - `47-assumecheck` `&;$?` → interrogate into a **verification checklist**

---

## 5. The `?` target palette (reverse golf) — 34 question shapes

`?` infers the wh-word / modal / auxiliary from the seed's grammar. Shapes charted:
how-do-I · what-is · why · should-I · how-much · when · where · who · yes/no-"Did" ·
how-long · which · best-way · do-you · can-I · 3-way-should-you · difference ·
worth-it · how-does-work · consequences · safe-to · how-often · is-X-Y-faster ·
do-i-need · whats-wrong · what-to-do-if · downsides · how-to-choose ·
when-to-use-X-vs-Y · how-to-tell-if · is-X-overkill · is-X-ready · whats-causing ·
standard-way · is-it-normal · getting-started. Plus register/nesting targets:
tradeoff, polite-`@`, `@∘?`, `@&[]`, `|∘?`, diplomatic-pushback `@!`, tight-17c.
(See `target-aur1-NN-*.sh`.)

---

## 6. Honest rejects (negative results are results)

Documented dead-ends so nobody re-treads them:
- **nested-list 2×2 matrix** — lists FLATTEN (#41), no nesting.
- **dialectic-triad** `[x,!x,~(x&!x)]` — the synthesis slot degenerates to "this contradicts itself" (bare negation doesn't sublate).
- **cost-of-inaction** `[x,>!x]` — `>!x` is the case AGAINST the plan, not the consequences of skipping it (= pro/con's 2nd element).
- **`_` as a prefix op** — only exists inside `^_` user-message syntax.
- **`#~x` robust-subject** — no visible contrast when `#` already picks the right topic.
- **two-one-liners** `@<x ≈ @~x` — the info-floor vs essence-kernel split only shows under REPEATED `~`/`<`, not one pass.
- **abstraction-ladder** `[#x,##x]` — `#` is idempotent.

---

*Unifying idea (with the fleet): nlir = **SELECT × TRANSFORM** — msm0's ranges
ADDRESS which text; these operators TRANSFORM it. The whole corpus lives in the
product of those two spaces.*
