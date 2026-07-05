# Design proposal: quote-eval — forms, application, and the functional layer

Status: **PROPOSAL / awaiting decisions** (bd-5dd86f). Repurposes core sigils
(`'`, application) that touch everyone's moves → needs team +1s AND Harry's
greenlight before implementing.

## Motivation

Today nlir is a *transform pipeline*: operators consume operand values and
produce values. It cannot yet treat an expression as **data** — pass a
"recipe" around, bind it to a name, apply it to arguments, or repeat it. Harry's
ask: the core functional concepts — **quoted forms, application, do-something-N-times,
macros** — which together make nlir *programmable*, not just composable.

The substrate for all of them is **homoiconic quote-eval**: a quoted form is the
unevaluated AST as a first-class value; application binds arguments and evaluates
it. A quoted form with positional holes is, in effect, a **lambda**; everything
else (map, fold, do-N-times, macros) rides on top.

## Concepts

- **Quote** — `{FORM}` yields a *form value* (`Value::Form(Box<Expr>)`): the AST of
  `FORM`, unevaluated. `~{x}` distils the *literal* `x`; `~x` distils the *value* of
  `x`. `{a+b}` is the form; `(a+b)` is the evaluated value.
- **Form** — a `Value` variant carrying a `Box<Expr>`. Renders as its source (so it
  round-trips) and can be bound (`f = {…}`), passed, and applied.
- **Application** — `f % args`: evaluate `f` to a form, bind `args` positionally to
  `$0, $1, …`, evaluate the form's body under those bindings, yield the result.
  `f%x`, `f%[x,y]`, `f%(x,y)` are equivalent (single arg, list, tuple). Named forms
  are read back with `$`: `f={…}; $f%x`.
- **Parameters** — inside a form, `$0 $1 …` are the positional argument holes,
  bound at application time (reusing the existing `$N` positional read syntax).
- **Tuple/list** — `a,b,c ≡ [a,b,c]` (a top-level comma constructor), so
  `f%(x,y)` and `f%[x,y]` unify.

### What it unlocks
- **Lambda**: `sum = {$0 + $1}; $sum%(2,3)` → 5.
- **map / fold — the structural per-item map the string-ops CAN'T do** (aur-0's
  op-over-collection law): today `op[list]` is NOT a structural map — it folds the
  list to JOINED TEXT and applies `op` once (`:` is the one op that reliably maps
  per-item; `&` weaves; `#`/`~`/`<` fold; `@`/`>` are non-deterministic). Forms fill
  that gap via the **glyph-free `$map` / `$fold` builtins** (LANDED, bd-14af74):
  `$map%({$0*$0},[1,2,3])` → `[1,4,9]` (a form applied per item → a LIST);
  `$fold%({$0+$1},[1,2,3,4])` → `10` (reduce). They take a form + a list via the
  existing `%`, so no new sigil — they are just reserved forms. Works with llm forms
  too: `$map%({:$0},[…])` simplifies each item, `$map%({@$0},[…])` formalises each.
- **do-N-times** (LANDED): `({>$0}_3)%x` — compose a form N times (`_` lift; parens
  because `%` binds tighter than `_`).
- **Macros**: a form that *builds* a form (quote + splice + apply) — deferred to a
  follow-up once quote-eval is proven.

## Syntax decisions (the crux — each needs a call)

> **Team lean (aur-1 + aur-2 + msm-0 parser read):** take the *cheap path* —
> fresh sigils for form-quote and application, keeping `'`=string and
> `#`=subject. Near-zero migration (~275 `.sh` + ~96 doc exprs stay as-is) and
> fewer parser ambiguities than repurposing loaded sigils. The canonical
> Lisp path (`'`=quote, strings→`"`) is kept below as the alternative — Harry's
> aesthetic call.

### D1. Form-quote sigil  — DECIDED: `{…}` (Harry; keep `'`=string)
- **Today**: `'…'` is the raw string literal; `"…"` is the interpolating string.
  Both are used across ~275 `.sh` + ~96 doc exprs + config.
- **Recommended (cheap):** give **form-quote its own fresh sigil**, leave strings
  on `'`/`"` untouched → **zero migration**. Parser-lead read on candidates:
  - `` `… `` **is TAKEN** — backtick is already the *serial* marker
    (`Expr::Serial`). Not available.
  - **`{FORM}` / `{…}`** — currently **unused**; brace reads as "a form/block";
    unambiguous (no existing prefix/infix use). **My recommendation.**
  - `\(…)` — usable but backslash overlaps escape handling; more lexer edge
    cases than braces.
  So: **`{a + b}` = the quoted form `a + b`** (a `Value::Form`), vs `(a + b)` =
  the evaluated group. Clean visual: `{}` = code-as-data, `()` = grouping.
- **Alternative (canonical, EXPENSIVE):** Harry's original — `'` becomes Lisp
  quote and `"…"` becomes *the* string form. More idiomatic, but a fleet-wide
  mechanical migration of every `'literal'` (~275 `.sh` + ~96 doc + 2 config),
  landed as one coordinated sweep (aur-2 owns it if chosen).
- **DECISION NEEDED (Harry, aesthetic):** cheap fresh sigil (`{…}`) vs canonical
  `'`→quote migration.

### D2. Application sigil — DECIDED: `%` (Harry reserved `.`)
- `#` is the well-used **subject** operator (`#^-1`; central to the catalog), so it stays
  subject-only (no application overload).
- **DECIDED (Harry ruling + msm-0 parser-lead + team consensus): apply/eval = `%`.**
  `f%x` ≡ `f%[x,y]` ≡ `f%(x,y)`. `%` is lexer-clean (zero `%` in the expr lexer today). Harry
  **reserved `.`** for future use, so the call-dot is out. Application binds TIGHTER than `,`
  (so `f%a,b` = `(f%a),b`; use `f%(a,b)` to pass a tuple).
- **Doc note (the one caveat):** `%` is also the config `template:` placeholder
  (`substitute_operands` in llm.rs: `%`/`%%`/`%0`) — but that is the *realisation/template-string*
  layer, NOT the expression lexer, so there is **no parser collision**. One glyph, two layers,
  documented so config authors aren't surprised. (`\` is the one-token fallback if it ever bites.)

### D3. Comma as list/tuple — `a,b,c ≡ [a,b,c]`
- Additive: `,` currently only separates items *inside* `[…]`; a top-level comma
  list is new surface with low conflict. Adopt. (Ambiguity to design: `f#a,b`
  — precedence of `,` vs application; resolved by making application bind tighter
  than `,`, or requiring `f#(a,b)`.)

### D4. `$0/$1` as form parameters
- Reuse the existing positional `$N` reads as the form's argument holes, bound at
  application time from an argument frame (distinct from the run stack). Clean:
  no new sigil, and it reads naturally (`'($0 & $1)`).

## Semantics sketch (once D1/D2 settle)
- `Value::Form(Box<Expr>)` new variant; renders as its source; not coercible to
  other types except by application.
- `Expr::Quote(Box<Expr>)` new node: `eval` returns `Value::Form(inner.clone())`
  **without** evaluating `inner`.
- Application: `eval` the callee → `Form(body)`; evaluate `args`; push an
  argument frame `{$0: a0, $1: a1, …}`; `eval(body)` under it; pop; yield.
  `$N` reads consult the argument frame first, then the run stack (back-compat).
- **op × Form (aur-0's note — removes ambiguity for the 16 ops):** a
  *non-application* operator on a Form operates on its **rendered source** —
  `@{a+b}` formalises the text "a + b", `~{...}` distils the source. Only the
  application sigil treats a Form as *callable*. (One rule, no per-op special
  cases.)
- Native + wasm identical (pure eval-core; no new effectful surface).

### D5. do-N-times — `_` lifted to forms (LANDED)
`_` is "repeat N times" for text (`x_2` = `"x x"`); lifted to forms it COMPOSES:
`{form}_N` composes the form N times, and `({form}_N)%x` applies the composition
(parens required — `%` binds tighter than `_`, so bare `{$0+1}_3%5` parses as
`{$0+1}_(3%5)`; use `({$0+1}_3)%5` → 8). Named: `g=({form}_N); $g%x`. Chosen over
overloading `*` (`{form}*3` collides with arithmetic mul). Sibling primitives
`$map`/`$fold` (over a LIST, not a count) ride the same `%` application machinery
(bd-14af74): `$map%({$0*$0},[1,2,3])`→`[1,4,9]`, and they compose —
`$fold%({$0+$1},$map%({$0*$0},[1,2,3]))`→`14` (sum-of-squares via fold∘map).

## Migration plan (on greenlight)
1. Land the quote-eval **core** (Value::Form, Expr::Quote, application, `,`
   constructor, `$N` param binding) behind the settled sigils — additive where
   possible.
2. Coordinate the **`'`→`"` sweep** (D1) as one fleet-wide pass: every
   `'literal'` → `"literal"` across catalogs/`move-*.sh`/README/config, landed
   together so no move breaks. (Team +1 + a shared checklist.)
3. Layer the **functional primitives** (do-N-times / map / fold over forms), then
   **macros**, as follow-ups.

## Resolved / open questions
- **D1**: form-quote sigil — **RESOLVED: `{…}`** (Harry). The `'`→quote migration is moot (fresh sigil).
- **D2**: application sigil — **RESOLVED: `%`** (Harry reserved `.`; msm-0 parser-lead + team consensus).
- **D3/D4**: comma-list + `$N` params — as proposed (macro holes reuse `$N`).
- Should forms be **hygienic** (params scoped per form) or dynamic? (Recommend
  hygienic — an explicit argument frame, not the shared stack.)

## Free-sigil map (aur-1, operator-consolidator lane)

**Full single-char ASCII census** (so we pick from the real free set):

- **Taken** (every glyph an operator or structural role): `# ! ~ @ : > < ? & | _ + - * /`
  (operators, plus multi-char `** ~> ~>? Δ`), and the structural chars `$` (context
  read), `^` (message views + suffixes `^_ ^* ^/ ^!`), `;` (statement sep), `=` (assign),
  `,` (list sep), `'` / `"` (raw / interpolating string), `( )` (group), `[ ]` (list),
  and `` ` `` (**serial** — backtick is TAKEN, confirmed).
- **Free** — the *only* unused single-char ASCII punctuation is **`{ }  %  .  \`** (five glyphs).
  **FINAL assignment** (Harry's ruling + msm-0 parser-lead):
  - **`{ }`** → **form-quote** (LOCKED): `{a+b}` = the form, `(a+b)` = the value.
  - **`%`** → **apply/eval** (PINNED): `f%x`. Lexer-clean; the template-string `%` is a separate
    layer (doc note below), no parser collision.
  - **`.`** → **RESERVED** by Harry (future use) — NOT apply.
  - **`\`** → still free; earmarked for the deferred **macro-splice** glyph.

### SETTLED — the functional layer costs just **2 fresh glyphs**
Macro *holes* reuse the existing positional `$N` reads (D4), so no third sigil is needed
until macros-that-build-forms (splice) land later. Final:
- **form-quote = `{…}`** (LOCKED, Harry): `{a + b}` = the form, `(a + b)` = the value — code-as-data
  braces vs grouping parens, zero lexer conflict.
- **form-apply/eval = `%`** (PINNED — Harry reserved `.`; msm-0 parser-lead + team consensus):
  `f%x` ≡ `f%[x,y]` ≡ `f%(x,y)`, infix, binds tighter than `,`. Lexer-clean (zero `%` expr token).
  **Doc note:** `%` is also the config `template:` placeholder — a *different layer* (realisation
  strings, not the expr lexer) → no parser collision; one glyph, two layers, documented so config
  authors aren't surprised. (`\` is the one-token fallback if the dual-meaning ever bites.)
- **holes = `$0 $1 …`** (reuse `$N`, D4) — no new sigil.
- **deferred: macro-splice** (forms that build forms) → a 3rd glyph from the remaining free
  set (`\`, now that `.` is reserved), pinned when macros land.

Net: the whole quote/eval/apply layer is **2 new glyphs (`{}` + `%`)**, both clean-free,
with **zero migration and zero overload** — backtick, `#`, and `'` all stay exactly as they are.
That is the concrete case for the FRESH path (D1/D2): it is not just cheaper, it is *nearly free*.
