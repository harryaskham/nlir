# Design: nlir quote / eval / macros / iterate — the metaprogramming layer

**Status:** proposed · **Owner:** aur-1 (SPEC/design) · **Bead:** bd-5dd86f (blocked on bd-2b226d, the det-eval epic — effectively complete, needs closing to unblock) · **Impl divvy:** aur-2 (Value::Form + config wiring) · msm-0 (parser/eval core) · aur-0 (iterate/map semantics + showcase dogfood)

> Goal: give nlir a **metaprogramming layer** — quote an expression as a first-class
> *form*, evaluate it, parameterise it (macros), and apply/iterate it. This turns
> nlir from "a pipe of transforms" into "a language you build with": every idiom
> we've carded (considered-reply, steelman, the drift, …) becomes a **named,
> reusable macro in a library**, not a retyped string. It also unlocks the one
> thing the operator algebra can't currently express — a **structural map** over a
> collection (see §6).

---

## 1. Motivation

Harry: *"we are still missing some core functional concepts — do something N times,
work with quoted forms, macros, etc, will let us do really powerful things."*

Today nlir has **value-binding** (`k = 'text'; $k`) but no **form-binding**: you
can name a *result*, not a *computation*. So the phrasebook is copy-paste strings.
The metaprogramming layer adds the missing half:

- **quoted forms** — a parsed expr as a value you can store/pass/run;
- **eval** — run a form;
- **macros** — a form with a hole (a parameter): the idiom, named and reusable;
- **iterate / N-times** — apply a form repeatedly (fold) or over a collection (map).

## 2. The four primitives (one system)

| primitive | what it does | example (sigils illustrative, §5) |
|---|---|---|
| **quote** | expr → an unevaluated **Form** value | `f = \(@(^-1 & 'GROUNDS'))` |
| **eval** | run a Form | `%f` |
| **macro** | a Form with a **hole**; apply fills it + evals | `steelman = \(~(>@%)); steelman ^-1` → `~(>@^-1)` |
| **iterate** | apply a Form N times (fold) or over a list (map) | `\(~) *3 x` (distil 3×) · `\(:%) map xs` (simplify each) |

## 3. Value model — `Value::Form` (aur-2 to co-spec)

A new variant `Value::Form(Expr)` holding an **unevaluated parsed `parser::Expr`**.
aur-2 owns this in `value.rs`; open sub-questions for that section:
- **render/print:** a Form prints as its *source* (round-trippable), e.g. `\(@^-1)`,
  not its result. (So `$_` of a form shows the code.)
- **det vs llm:** quote/eval/apply are **structural/deterministic** (no model call) —
  building + expanding forms is pure; only the *realisation of the expanded expr*
  hits the model. So a macro library works offline; running it costs what the
  underlying ops cost.
- **how apply/eval consume it:** eval walks the `Expr`; apply substitutes the hole
  node(s) then evals; both are eval-core operations (msm-0).
- **equality / nesting:** forms can nest (`\(\(x))`); a form is a first-class Value
  so it can be bound, listed, passed to ops.

## 4. Quote / eval / macro semantics

- **Quote** captures the expr **without evaluating** it. `\(EXPR)` → `Value::Form(EXPR)`.
  Inside a quote, `$k` / `^-1` / etc. are **not** resolved until eval.
- **Eval** resolves a Form against the current context: `%f` evaluates `f`'s expr now.
- **Macro = quote + a hole.** A hole marks the parameter slot(s). Applying the macro
  to an argument **substitutes the hole with the argument's form** (or value), then
  evals. Holes may repeat (`\(@% & !%)` uses the arg twice) and nest.
  - **hygiene:** substitution is by AST node, positionally — no variable capture
    (macros are expr-templates, **not** lambdas: no free-variable environment, which
    keeps them simple + safe, matching nlir's no-lambda stance).

## 5. Sigils — THE decision (Harry's call)

Three **new** sigils are needed: **form-quote**, **form-apply/eval**, and the
**macro-hole** marker (plus an **iterate** operator, which may reuse `*`). Two framings,
same shape as the `~>` and `#` questions:

**(a) Reuse loaded sigils** — canonical/Lisp-idiomatic, but a large migration:
- `'` → form-quote, **strings move to `"`**. Blast radius (aur-2 + aur-0 sized): ~275
  example `.sh` + ~96 doc exprs + **all of build-showcase.py (every card expr + caption)
  + every baked-in `'…'` inside the showcase PNGs (re-render) + the README Showreel** —
  a **~370+ file mechanical sweep, larger than the `~>` one we just did**.
- `#` → form-apply (overload: `#` on a Form = apply, on text = subject) — context overload.

**(b) Fresh sigils** — near-zero migration, no overload (my strong lean, +1 aur-2 + aur-0):
- keep `'…'` = string, `#` = subject.
- pick fresh sigils from the **free set**: `\  {  }  %` (and 2-char combos). Load-bearing,
  **do not use:** `$ ^ ; , ( ) [ ] = ` `` (serial) `~ @ : # ! & | > < ? _ + - * / Δ ~> ~>?`.

**Proposed fresh set (illustrative — Harry finalises):**
- form-quote: **`\(…)`** — `\(@^-1)` is the form. (backslash reads as "quote"; note ``` ` ``` is taken by Serial.)
- form-apply/eval: **`%`** prefix — `%f` evals a Form; `f % arg` applies with an argument.
- macro-hole: **`%`** inside a quote as the arg slot — `\(@(% & 'GROUNDS'))`. (Or positional `%1 %2`.)
- iterate: reuse **`*`** — `\(~) *3 x` (N-times fold); a `map` keyword/sigil for the collection map (§6).

> Recommendation: **fresh sigils (b).** The `'`→`"` migration is the single biggest
> blast radius in the project and buys only aesthetics; forms are a *new* capability
> that doesn't need to disturb existing strings. If Harry prefers the canonical `'`
> for quote, aur-2 owns the string sweep + aur-0 owns the showcase side.

## 6. Iterate / map / N-times — the structural-map unlock (aur-0)

This ties to the **op-over-collection law** the swarm converged on: today `op[list]`
applies `op` to the **joined text** of the list (a fold-to-text), **not** a per-item
map — only `:` reliably maps in practice; `& ` weaves; `# ~ <` fold; `@ >` are
non-deterministic. **There is no general structural map.** Quoted forms fill exactly
that gap:

- **map:** `apply \form over list` → a **LIST of results** (structural, one per item),
  the map the string-ops can't do. e.g. `map \(:%) ['idempotent','mutex','semaphore']`
  → `[plain-english, plain-english, plain-english]` (three items, not one joined blob).
- **fold / N-times:** `\form *N x` → apply `form` N times, feeding output→input.
  e.g. `\(~) *3 x` = distil three times (the telephone game); `\(refine) *N draft` =
  iterate toward a fixpoint.

The doc's iterate semantics should state this explicitly: **forms are what make a true
structural map + a real N-fold expressible** — the third tier above the string-level
fold/weave. (aur-0 has the receipts on how ops degrade over collections + will
co-author/dogfood this section.)

## 7. Design tensions (resolved by fresh sigils)

- **`#` collision** (subject vs form-apply): fresh apply sigil → `#` stays subject-only.
- **`'` string-quote** (vs Lisp-quote): fresh quote sigil → `'…'` stays strings, no
  ~370-file migration.
- Both are the "reuse-loaded vs fresh" call in §5; fresh dissolves them.

## 8. Phasing

1. **Forms** — `Value::Form`, quote + eval (aur-2 value.rs + msm-0 eval). The foundation.
2. **Macros** — the hole + apply/substitute (msm-0 eval, config wiring aur-2).
3. **Iterate** — N-times fold + the structural map over a collection (aur-0 + msm-0).
4. **A macro library** — the carded idioms re-expressed as named macros (aur-1 showcase
   + aur-0 dogfood): the phrasebook becomes a shipped library.

## 9. Impl divvy

- **aur-1** (me): this design doc + sigil/semantics spec + the macro-library showcase.
- **aur-2:** `Value::Form` in `value.rs` (co-specs §3) + config-side operator wiring +
  (only if Harry rules reuse) the `'`→`"` string sweep.
- **msm-0:** parser + eval core (quote captures unevaluated, eval walks, apply
  substitutes) — the P0-seam-style keystone everything builds on.
- **aur-0:** the iterate/map semantics (§6) + dogfood/showcase once the shape freezes.

## 10. Open questions

- Final sigils (§5) — **Harry's call** (reuse-vs-fresh; the concrete fresh chars).
- msm-0 (parser lead): which is cleaner to parse + fewer ambiguities — a prefix quote
  `\(…)` vs a bracket `{…}`; apply as prefix `%f` vs infix `f % arg`.
- Hole syntax: single `%` (one arg) vs positional `%1 %2` (multi-arg macros).
- Does `bd-2b226d` (det-eval) need to close first, or can forms land against current eval?
- Interaction with `$_stdin` / `^!` (a form over piped code / the tool stream).
