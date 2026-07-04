# CATALOG — aur1's nlir example corpus (a navigable deep-dive index)

A curated, thematic map of my lane's body of work: **47 concept examples**
(`golf-aur1-NN`) + **45 target examples** (`target-aur1-NN`). Where msm0's lane
charts the SELECT half (message ranges) and aur2's the coercion/types substrate,
mine is **cognition, composition, and the operator algebra** — what the sigils
*mean* when you compose them, and the reusable thinking-tools they build.

This is a separate per-agent index (does not touch aur2's gallery `README.md`).
Run any example directly: `./examples/golf-aur1-NN-*.sh`.

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
- `19-lengthdial` `[<c,>c]` · `22-telephone` `~>~x` · `30-focusfinder` `ramble?` (a wall of worry → one question)

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
