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

- **Quote** — `'FORM` yields a *form value* (`Value::Form(Expr)`): the AST of
  `FORM`, unevaluated. `~'x` distils the *literal* `x`; `~x` distils the
  *value* of `x`.
- **Form** — a new `Value` variant carrying a `Box<Expr>`. Renders as its source
  (so it round-trips) and can be bound (`f = '(...)`), passed, and applied.
- **Application** — `f APPLY args`: evaluate `f` to a form, bind `args`
  positionally to `$0, $1, …`, evaluate the form's body under those bindings,
  yield the result. `f.x`, `f.[x,y]`, `f.(x,y)` are equivalent (single arg,
  list, tuple).
- **Parameters** — inside a form, `$0 $1 …` are the positional argument holes,
  bound at application time (reusing the existing `$N` positional read syntax).
- **Tuple/list** — `a,b,c ≡ [a,b,c]` (a top-level comma constructor), so
  `f.(x,y)` and `f.[x,y]` unify.

### What it unlocks
- **Lambda**: `sum = {$0 + $1}; sum.(2,3)` → 5.
- **map — the structural per-item map the string-ops CAN'T do** (aur-0's
  op-over-collection law): today `op[list]` is NOT a structural map — it folds
  the list to JOINED TEXT and applies `op` once (`:` is the one op that reliably
  maps per-item; `&` weaves; `#`/`~`/`<` fold; `@`/`>` are non-deterministic).
  So there is **no general per-item map today**. `map.({:$0}, [a,b,c])` is
  precisely that: it returns a **LIST** of results (`[:a, :b, :c]`), not a join.
  Forms are what make a real `map`/`fold` expressible.
- **do-N-times** (see D5): `{>$0}_3` — apply a form N times (lift `_`).
- **Macros**: a form that *builds* a form (quote + splice + apply) — deferred to
  a follow-up once quote-eval is proven.

## Syntax decisions (the crux — each needs a call)

> **Team lean (aur-1 + aur-2 + msm-0 parser read):** take the *cheap path* —
> fresh sigils for form-quote and application, keeping `'`=string and
> `#`=subject. Near-zero migration (~275 `.sh` + ~96 doc exprs stay as-is) and
> fewer parser ambiguities than repurposing loaded sigils. The canonical
> Lisp path (`'`=quote, strings→`"`) is kept below as the alternative — Harry's
> aesthetic call.

### D1. Form-quote sigil  — RECOMMENDED: a fresh sigil (keep `'`=string)
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

### D2. Application sigil — RECOMMENDED: a fresh sigil (keep `#`=subject)
- `#` is the well-used **subject** operator (`#^-1`; central to the catalog), so
  overloading it for application is ambiguous (context-overload — `#` on a form =
  apply, on text = subject — is possible but adds a type-dependent parse).
- **Recommended:** application gets its **own fresh infix sigil**, `#` stays
  subject-only. `f<apply>x` ≡ `f<apply>[x,y]` ≡ `f<apply>(x,y)`. Candidate glyphs
  to pin in review (need one that's not already an operator): a call-dot or a
  fresh mark — pinned on Harry's aesthetic call. Application binds TIGHTER than
  `,` (so `f<apply>a,b` = `(f<apply>a),b`; use `f<apply>(a,b)` to pass a tuple).
- **DECISION NEEDED (Harry):** which apply glyph (or accept a proposed default).

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

### D5. do-N-times — lift `_` (aur-0's proposal)
`_` is already "repeat N times" for text (`x_2` = `"x x"`), so lifting it to forms
reads consistently: **`{>$0}_3`** = apply the form `{>$0}` three times
(text-repeat → form-repeat). Cleaner than overloading `*` (`{>$0}*3` collides with
arithmetic mul). Candidate for the repeat primitive once the quote/apply core
lands; `map`/`fold` over a LIST (not a count) layer on the same application
machinery.

## Migration plan (on greenlight)
1. Land the quote-eval **core** (Value::Form, Expr::Quote, application, `,`
   constructor, `$N` param binding) behind the settled sigils — additive where
   possible.
2. Coordinate the **`'`→`"` sweep** (D1) as one fleet-wide pass: every
   `'literal'` → `"literal"` across catalogs/`move-*.sh`/README/config, landed
   together so no move breaks. (Team +1 + a shared checklist.)
3. Layer the **functional primitives** (do-N-times / map / fold over forms), then
   **macros**, as follow-ups.

## Open questions for Harry / team
- **D1**: `'`→quote migration — go? (breaking, fleet-wide)
- **D2**: application sigil — which glyph?
- **D3/D4**: comma-list + `$N` params as proposed?
- Should forms be **hygienic** (params scoped per form) or dynamic? (Recommend
  hygienic — an explicit argument frame, not the shared stack.)

## Free-sigil map (aur-1, operator-consolidator lane)

**Full single-char ASCII census** (so we pick from the real free set):

- **Taken** (every glyph an operator or structural role): `# ! ~ @ : > < ? & | _ + - * /`
  (operators, plus multi-char `** ~> ~>? Δ`), and the structural chars `$` (context
  read), `^` (message views + suffixes `^_ ^* ^/ ^!`), `;` (statement sep), `=` (assign),
  `,` (list sep), `'` / `"` (raw / interpolating string), `( )` (group), `[ ]` (list),
  and `` ` `` (**serial** — backtick is TAKEN, confirmed).
- **Free** — the *only* unused single-char ASCII punctuation is **`{ }  %  .  \`** (five glyphs):
  - **`{ }`** — clean, zero lexer conflict; brackets pair naturally with `()`.
  - **`%`** — clean, zero conflict.
  - **`.`** — free as an operator, but the lexer must disambiguate it from the decimal
    point in numbers (`3.14`); usable with care.
  - **`\`** — free, but overlaps string-escape handling → more lexer edge cases.

### Recommendation — the functional layer costs just **2 fresh glyphs**
Macro *holes* reuse the existing positional `$N` reads (D4), so no third sigil is needed
until macros-that-build-forms (splice) land later. So:
- **form-quote = `{…}`** (+1 msm-0): `{a + b}` = the form, `(a + b)` = the value — the cleanest
  mnemonic (code-as-data braces vs grouping parens), zero lexer conflict.
- **form-apply** (infix) — two clean options, a genuine tradeoff (flagged by aur-2, template owner):
  - **`%`**: lexer-clean (zero `%` token in the expr lexer today), keeps `#` subject-only. *Wart:*
    `%` is already the config **`template:`** placeholder (`substitute_operands` in llm.rs: `%`=operand,
    `%%`=literal, `%0/%1`=positional). That is a DIFFERENT layer (realisation/template strings, not
    the expr lexer → **no parser collision**), but a config author would see `%` mean two things.
    Fine *if* the doc flags the layer split.
  - **`.`** (call-dot, `f.x`): familiar (method-call syntax everywhere), **no dual-meaning**, but the
    lexer must disambiguate the decimal point (`3.14` = number between digits; `f.x` = apply between
    non-digits — a standard lexer rule).
  Either keeps `#` subject-only (no overload). **Harry's aesthetic + msm-0's parseability call.**
  Consolidator lean: **`.`** now (zero dual-meaning, universally readable) *if* msm-0 confirms the
  decimal rule is clean; else **`%`** with the layer split documented.
- **holes = `$0 $1 …`** (reuse `$N`, D4) — no new sigil.
- **deferred: macro-splice** (forms that build forms) → a 3rd glyph from the remaining free
  set (`\` or `.`), pinned when macros land.

Net: the whole quote/eval/apply layer is **2 new glyphs (`{}` + `%`)**, both clean-free,
with **zero migration and zero overload** — backtick, `#`, and `'` all stay exactly as they are.
That is the concrete case for the FRESH path (D1/D2): it is not just cheaper, it is *nearly free*.
