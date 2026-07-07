# Minimal nlir for coding-agent instructions

**Status:** design / vocabulary exploration (Harry, 2026-07-05:
*"look at the kinds of things one says to a coding agent, and work out how, in
context, one could minimally express them"*).

Goal: take the things people actually say to a coding agent and find the
**tersest faithful nlir** for each — then surface the **new concepts** the
current operator set is missing. This is the language-design counterpart to the
[cookbook](../cookbook.md) (which shows what the forms can already do).

---

## 1. What you operate *on* — the context handles

nlir instructions are terse because the **subject is usually implicit** — it's
already in context. Three handles supply it:

| handle | is | example |
|---|---|---|
| `^-1` | the last assistant message; `^_-1` last user, `^*` all, ranges `(a)^(b)` | `~^-1` — gist the last reply |
| `$_stdin` | stdin — a diff, a file, an error paste (piped in) | `~$_stdin` — gist the piped diff |
| `$k` | a named value read back from context | `$err` — the error you stored |

So "summarise **this**" is just `~^-1` or `~$_stdin` — the operator, pointed at the
ambient subject. That implicit-subject economy is the whole reason a coding-agent
instruction can collapse to one or two glyphs.

---

## 2. Catalogue — common asks → tersest nlir

Deterministic where marked; the rest are single-model-call lenses (`--mode llm`).

| You say… | nlir | how |
|---|---|---|
| "summarise this / TL;DR" | `~^-1` | gist |
| "give me the point, keep the numbers" | `<^-1` | tighten (lossless, vs `~` lossy) |
| "explain / expand on this" | `>^-1` | expand |
| "explain it simply / de-jargon" | `:^-1` | simplify |
| "make it formal / professional" | `@^-1` | formal |
| "what's this about? (one label)" | `#^-1` | subject |
| "what changed from A to B" | `A Δ B` | directional diff |
| "turn this into a question" | `^-1?` | question |
| "what does this imply / what follows" | `~>?^-1` | derive the implication |
| "does A imply B? (yes/no)" | `A~>B` | implication check |
| "combine these into one statement" | `&[a,b,c]` | weave |
| "give me the options / alternatives" | `\|[a,b,c]` | or-choice |
| "summarise then make it formal" | `@(~^-1)` | compose lenses |
| "steelman this" | `~(>@^-1)` | expand→formalise→distil (a form) |
| "summarise each of these" | `$map%({~$0}, [<list>])` | map a lens per item |
| "distil these views to a consensus" | `$fold%({~($0&$1)}, [<views>])` | fold weave+gist |
| "count the yeses" | `$fold%({$0+$1}, $map%({$0~>'affirmative'}, [<answers>]))` | classify-then-count |

Named/glyph macros (once **bd-44c294** lands `form:`/`builtin:` operators) turn
the frequent ones into your own vocabulary: `⇑ = {~(>@$0)}` (steelman),
`↦ = builtin map`, so `~↦[notes]` summarises each note in three glyphs.

### 2b. Coding-pipe idioms (via `$_stdin`)

Where the subject is piped in (a diff, code, an error), the same lenses apply to
`$_stdin`. Verified terse forms from the coding-pipe lane (aur-0/aur-2/aur-1):

| You say… | nlir | how |
|---|---|---|
| "summarise this PR / diff" | `git diff \| nlir -e '[#$_stdin,~$_stdin]'` | subject + gist of the diff |
| "review this code" | `<code> \| nlir -e '@&[~$_stdin,‹points›]'` | formal weave of gist + review points |
| "what's the likely fix?" | `<err> \| nlir -e '~(>"the most likely fix for: $_stdin")'` | expand a fix hypothesis, then distil |

**Tacit stdin (post-`@a74f6d4`):** a bare *operator* with nothing left to consume
now pulls stdin off the stack, so explicit `$_stdin` is optional for the simple
case — `git diff | nlir -e '~'` gists the piped diff, `… | nlir -e '#'` names it,
`… | nlir -e '?'` poses it as a yes/no question, and adjacent prefix ops compose
(`… | nlir -e '@~'` = formal∘gist of stdin).

**Form application on a pipe (post-`@7d173e6`, tacit form application):** a bare
*form/train* over piped input now auto-applies to the seed —
`echo notes | nlir -e '(: & #)'` runs the simplify&subject fork on stdin (no
explicit `%$_stdin` needed). When there is NO piped seed, a bare form is still a
first-class VALUE and evaluates to *itself* (`nlir -e '{:$0}'` → `{(: $0)}`), so
you can still emit a form as output — *forms-are-values* holds, scoped by
seed-depth. Explicit `… | nlir -e '(: & #)%$_stdin'` also still works. An operator
with an empty stack errors **loudly** (`stack error: needs N value(s)`), never
silent-empty.

**Gotcha — hyphenated bare words:** bare `-` is subtraction, so `on-call` lexes as
`on - call` (→ `cannot coerce string \`on\` to number`). Quote hyphenated words:
`'on-call'`, `'fix-the-bug'`. (Not a gap — `-` is a real operator; quoting is the
fix, same as any word you want kept literal.)

The exhaustive coding-idiom catalogue + showcase cards live in the coding-pipe
lane (aur-0 cards/cookbook, aur-2 phrasebook); this doc keeps a representative
set and focuses on the *design gaps* below.

---

## 3. The gaps — new concepts we need

The catalogue above stops where the operator set does. The instructions that
*don't* yet have a minimal form point at the primitives to add.

### 3a. Multi-concept extraction — a `#` that returns a **list** (Harry's flag)

`#` gives **one** subject. But a huge fraction of coding-agent asks are
"pull out the **several** things here":

- "list the risks / edge cases / TODOs in this"
- "what are the key concepts in this design?"
- "break this error down into the distinct failures"

There is no operator for *text → list of concepts*. It's the structural inverse
of `#` (which folds a list → one category), and it's the **missing feeder for
map/fold** — once you can extract a list, the whole functional layer applies:

```
concepts^-1                       -> [concept1, concept2, concept3]   (NEW)
$map%({>$0}, concepts^-1)         -> expand each concept
$map%({:$0}, concepts^-1)         -> plain-language each risk
$fold%({~($0&$1)}, concepts^-1)   -> distil the concepts to a theme
```

Proposal: a prefix operator (name `concepts` / word-builtin `$concepts`) that
realises to a **list** of short, salience-ordered, de-duped noun phrases. Arity
1, `result: list`. It pairs with map/fold so cleanly that it's arguably the
single highest-leverage addition on this page. **Sigil + semantics settled in
§6:** `#*` (the plural of `#`), with a model-chosen count (no `_N` cap — that
would collide with do-N `({f}_3)`).

### 3b. Assess / critique — a judgement lens

"is this correct?", "what's wrong with this?", "review this" have no faithful
minimal form. `~>` gives a boolean implication and `?` makes a question, but
there's no "evaluate and tell me the problems" lens. Candidate: a `critique` /
`assess` operator (text → the salient objections/issues), which composes with
3a — `concepts` the issues, then map a fix-suggestion form over each.

### 3c. Code-shaped transforms

"refactor for clarity", "add a test", "make it robust" are code→code, not
text→text. These likely stay as `command:`/`prompt:` operators (or forms bound to
those via bd-44c294) rather than core lenses — noting the boundary so the core
vocabulary stays about *thought*, and code-mutation rides the operator table's
existing escape hatches.

### 3d. Generation / instruction-following — the missing *generative direction*

Every lens in §2 **transforms text that already exists** — gist it, tighten it,
formalise it, expand it. That is the *reading* direction. The gap Harry's
*"generate your agent replies AS nlir programs"* directive surfaces (aur-0,
dogfood lane — **bd-d18743**) is the **generative** direction: **no operator
treats its operand as an *instruction to obey and produce new text*.**

- **Proof:** `>"Write the single word: acknowledged"` → a whole paragraph
  *about* writing one word. `>` (and the `<(>…)` shorten-of-expand idiom)
  **elaborate / describe** the instruction; they never **obey** it. So there is
  no faithful minimal form for "compose a fresh, concise, first-person reply" —
  the one generative move an agent most needs to answer a teammate.

The missing primitive is an **instruction-following op** (a *realise* / *respond*
lens): operand = a prompt, semantics = *"follow the instruction in `<text>` and
return ONLY the result."* It is the raw-prompt escape hatch that lets nlir
express **new** thoughts (answers, replies, drafts, "do X"), not just reshape
existing ones — exactly Harry's *"only generic help needed to express serious
thoughts."* It is the general case behind §3c's "code→code rides `prompt:` ops":
a *produce-new-text* primitive.

**Proven, config-only, live model** (prototype + evidence in bd-d18743):

```
⟨gen⟩"Write the single word: acknowledged"        -> acknowledged        (OBEYS, not a paragraph)
t=^-1;⟨gen⟩"one sentence, first person, reply agreeing …: $t"
                                                 -> a real reply that folds in the teammate's actual message
(⟨gen⟩"warm ack") & (⟨gen⟩"gentle counter")       -> the two generated moves weave into one fluent line
```

Two things fall out of dogfooding it as the *agent-reply* path:

- **Context interpolation is the whole point.** Double-quoted operands
  interpolate context (`$t`, `$_stdin`, an assigned `$k`); single-quoted are
  literal. So `t=^-1;⟨gen⟩"…: $t"` reads the last message off the stack and
  generates a reply *to it* — the exact loop Harry asked for, in one call
  instead of the two-call `<(>…)` that fights the tools.
- **Generated moves compose.** Because the op returns a plain value, `&` / `|` /
  the lenses apply on top, so a layered reply (ack **and** counter, then `@` to
  formalise) stays expressible in the generative direction — not just the
  reading one.

**Sigil / core-bless deferred (per §6 policy).** The op is user-config either
way; a word-name (`respond` / `realise`) or a free multibyte glyph is the
grammar owners' call — do **not** spend a scarce ASCII single-char on it. The
open decisions (sigil, bless-into-core vs documented opt-in config example, det
stub for the det-total test bar) live on **bd-d18743** with the proven prototype.

---

## 4. The UX half — partial results while you iterate

Harry: *"better partial result display in e.g. pi would let us quickly iterate on
chains of thought."* The vocabulary only pays off if you can **watch a chain
resolve**. Status across the three surfaces:

- **CLI** — `nlir step` streams each reduction live (**bd-89eb89**, landed): you
  see `~(>@^-1)` unfold one realisation at a time.
- **TUI workbench** — live det-preview **landed** (**bd-970e05** slice 1,
  @e38868b): type an expression and ~350ms after you pause, the det
  result-so-far appears italic in the Output pane; Enter commits.
- **pi plugin** — live det-preview **landed** (**bd-970e05** slice 2): as you
  type a `|`-prefixed nlir line, the det result-so-far shows in a widget above
  the editor (debounced ~350ms, cleared on send). Closes the surface Harry named.

### The shared partial-display contract

All three surfaces follow the same rules, so the UX is consistent:

1. **Debounce, don't eval per-keystroke** (~350ms after the last edit) — a
   speculative preview, not a running eval.
2. **Deterministic mode is the safe default** — det is instant, offline, and
   **free**, so debounced det preview needs no cost gating. A mid-edit /
   unparseable / non-det expression shows **no** preview rather than flickering
   an error.
3. **Speculative ≠ committed** — the preview is styled distinctly (italic / dim
   / a "live" marker) and never persists context writes; only an explicit
   submit/Enter commits.
4. **The llm tier is gated + cached** — live-previewing an `~`/`@`/`>` chain
   means paid model calls, so it is opt-in and rides **msm-0's incremental
   cache** (subexpr-identity memoization + AST-diff invalidation): a small edit
   only re-fires the edited node, reusing cached realisations for the rest. That
   is what makes iterating on an llm chain of thought affordable.

The streaming step API (`step_trace_streaming`) is the shared engine for the llm
tier: each realisation resolves live so a long chain paints incrementally instead
of blocking.

---

## 5. Summary — the shortlist

1. **Multi-concept extraction** (`concepts`, text → list) — the highest-leverage
   gap; unlocks map/fold over extracted ideas (3a).
2. **Assess/critique lens** — the missing "what's wrong here" (3b).
3. **Generation / instruction-following op** (**bd-d18743**, proven config-only)
   — the *generative direction*: obey a prompt and return only the result, so an
   agent can compose a fresh, concise, first-person reply (and interpolate the
   message it is replying to) rather than only reshape existing text (3d).
4. **Glyph/form operators** (bd-44c294) — let frequent chains become a personal
   terse vocabulary.
5. **Partial-result display in pi** — makes iterating on chains-of-thought fast
   (4).

Items 4–5 are already moving (bd-44c294, bd-89eb89, bd-970e05 — TUI + pi det
previews landed). Items 1–3 are the new language concepts this exploration
surfaces.

---

## 6. Sigil & grammar design for the new operator kinds (aur-1)

The three additions above (multi-extract, `form:` ops, `builtin:` ops) all touch
the **operator sigil namespace**, which is nearly full — `{}`, `%`, and every lens
are taken; `\` is the one free ASCII single-char (earmarked for macro-splice). One
coherent allocation, so the grammar doesn't fork:

### Multi-extract → `#*` (resolves 3a's glyph Q)

Recommend **`#*`** for text→list-of-concepts, not a fresh glyph:

- `*` is already the **"all"** modifier (`^*` = all messages; `(a)^(b)` ranges), so
  `#*` reads as "**all** the subjects" — the plural of `#` (one subject) — learnable
  from a pattern users already know. **Zero new glyph spent.**
- A word-builtin **`$concepts`** can co-exist as the spelled-out form (like `$map`/
  `$fold` alongside a future glyph), for configs/users who prefer words.
- Rejected: `##` (doubling reads as "subject-of-subject", wrong sense); a Unicode
  glyph (spends novelty for no readability gain over `#*`).

**Count / dedupe (msm-1's open Q):** default **model-chosen** — the common ask
("the risks", "the concepts") has no fixed N. Do **not** overload `_N` for a cap:
`_N` already means form-compose / do-N (`({f}_3)`), so a `#*_3` cap would collide.
If a cap is later wanted, pass it as an explicit operand form rather than a suffix;
defer until there's real demand. Ordering: salience-first, de-duplicated, plain
noun-phrase list, so `$map`/`$fold` over it stays clean.

### `form:` / `builtin:` operator sigils (bd-44c294)

The **mechanism needs no reserved glyph** — an `op:` is whatever the *user's config*
names it:

- **Word-names** are the baseline (`steelman`, `mapop`) — same class as `$map`, no
  ASCII pressure.
- **Multibyte glyphs** are free to spend (`⇑`, `↦`, `⊘`) — they don't touch the
  ASCII single-char scarcity (`Δ` already lexes this way).
- Keep **`\`** unspent (macro-splice reserve).

**Collision rule (the one hard constraint):** the config validator must reject an
`op:` that shadows a built-in operator or another config op — one flat namespace,
first-definition-or-error, so a user glyph can't silently reassign `~` or `%`.
Arity is inferrable from the form's max `$N` (`{$0+$1}` ⇒ arity 2); `form:`/`builtin:`
validation should cross-check that against any declared `arity:`.

**Net:** one new ASCII sigil across all three (`#*`, itself a *reuse* of `*`), plus
user-config word/multibyte ops that stay off the scarce core set. The grammar stays
coherent and the `\` splice reserve is preserved.
