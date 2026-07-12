# nlir — natural-language IR

`nlir` transpiles a terse, sigil-laden **shorthand** into fluent **English**. The
shorthand is an intermediate representation: it is *tokenised*, *parsed* into a
DAG using a config-defined grammar, and *evaluated* over a small **stack machine**
with a **tiny type system**, where each operator is realised either
**deterministically** (mechanical string/number expansion) or via an **LLM** call
(a structured text-transformation).

Invocation — typically from a coding agent's prompt window:

```
nlir -e 'EXPR'
```

The engine ships only a tiny set of **builtins** (stack / context / indexing /
assignment / arithmetic / coercion / list plumbing). Everything else — the
operator vocabulary, their fixity/priority/arity/types, the models, the prompts,
the coercions, the tests — lives in `~/.config/nlir/config.yaml`. The binary is a
small VM; the language is config.

---

## Mental model

```
EXPR ──tokenise──▶ tokens ──parse──▶ DAG ──schedule/eval──▶ English
                             (grammar from config)   (stack machine; types+coercion; per-op det|llm; parallel)
```

- An expression is a sequence of **statements** separated by `;`.
- Evaluating a statement yields a **typed value** and pushes it onto the stack.
- **Atoms**: literal text (bare/quoted), numbers, list literals, dict literals,
  context accessors (`^` messages, `$` stack/context), and `.`/`..` accessors.
- **Operators** combine values; each operator declares the **types** it needs, and
  operands are **coerced** to those types first (deterministically, or via an LLM
  coercion call).
- Given no operands an operator **pops from the stack**.
- The parse is a **DAG**: independent subtrees run concurrently (see Parallelism),
  except where context is written or serial is forced.
- **Program result** = the final statement's value → stdout.

---

## Runtime state (two namespaces)

| Name | Owner | Lifetime | Access |
|---|---|---|---|
| **context** (`NLIR_CONTEXT` env, or a context file) | harness / scripts / `nlir set` / in-expr `=` | transient by default; persistent with a context file | read `$name` / `^`; write `LHS=RHS` (immediate) or `set`/`append-message` |
| **stack** | `nlir`, internal | one run | `;` pushes, `$` / `$N` peek, nullary-op pops |

- **context** is one JSON object. Default context file
  **`~/.config/nlir/context.json`** (beside `config.yaml`); `--context-file`
  overrides; else `NLIR_CONTEXT` env. A **one-shot `-e` eval does not auto-load
  the default file** (bd-85c49d): it uses only an explicit `--context-file` /
  `NLIR_CONTEXT` / `--session-file`, so `^` on a bare `-e` with no context fails
  loud instead of bleeding a shared node-global default across agents. The REPL
  and `set` / `get` / `append-message` keep default-file persistence.
- Messages live under **`_messages`** (`{role, content}` array); `^` indexes
  role-filtered views. `^` on an empty message set is a loud
  `no conversation context` error, not an empty read.
- System keys (`_`-prefixed): `_messages`, `_sep` (list/range → text separator,
  default `"\n"`), `_cache` (caching on/off, default `true`), `_precision`
  (final-display decimal places for numbers, default off = exact/round-tripping;
  display-only, never changes computation), `_seed` (integer reproducibility
  seed threaded into the llm request, unset by default — exported as
  `${NLIR_SEED}` and injected as the request body's top-level `seed`. Backend-dependent: reproducibility needs
  a backend that honors `seed`, and no currently-configured backend does (Anthropic
  Messages has no native `seed`; the reachable OpenAI-compatible model is
  non-deterministic even at a fixed seed) — so `_seed` is presently a no-op, ready
  for a seed-honoring backend).
- **Context writes happen immediately** (write-through to the context file when
  one is active).

---

## Types & coercion

Every value has a type: **`string`** (default), **`number`**, **`bool`**,
**`list`**, **`dict`** (an insertion-ordered `key=value` map — see Dictionaries &
accessors below), **`form`** (a quoted `{…}` expression — see metaprogramming below).

- Operators declare `operands:` / `result:` types (default `string`). `^` indices
  and arithmetic want `number`; `#`/`!`/`&` want `string`.
- A **`form`** coerces to `string` as its **inner source** (no braces), so an op over
  a form reads its code as text (`@{a+b}` → "a+b"); `%`-application takes `operands:[form]`.
- Before an operator runs, each operand is **coerced** to the required type:
  1. already that type → use as-is;
  2. **deterministic** parse — `"1"`↔`1`, `number→string`, `list→string` (join
     with `_sep`), `"true"→bool`;
  3. else an **LLM coercion** — "interpret the text as a value of type T" with a
     structured-output schema `{result: T}`, config-defined per type. This turns a
     vague `"ten to twenty"` into `15`.

Coercion that cannot produce the target type is a **loud error** (the LLM path is
constrained by its output JSON schema, so it returns a valid typed value or
fails). `list → number` is an error. A **`dict`** coerces to `string` as its
`key=value` pairs (joined with `_sep`); `dict → number`/`bool` is an error.

Coercion is part of the same expand/contract machinery as operators, and its
results honour `_cache`.

---

## Modes

`det` (no network) or `llm`. Default `defaults.mode`, override `--mode`.
Realisation resolution for an operator:

1. `command:` (subprocess, det) or `reduce:` (builtin numeric add/sub/mul/div/pow,
   det) → run it;
2. else mode `det` → `template:` / `join:`;
3. else mode `llm` → `model:` + `prompt:`.

`command`/`reduce`/coercion math are deterministic regardless of mode; only string
transformations differ by mode.

---

## Builtins (fixed engine layer, not config)

### Sequencing & stack
- **`;`** — evaluate, push. `a;b;&` → "a and b".
- **`$`** — peek stack top; **`$N`** — peek by index (`$0` bottom, `$-1` top). No
  pop.
- **nullary-pop** — a config op with no operands pops the stack (arity-`k` pops
  `k`; variadic pops all).
- **nullary-fallback (parser)** — a prefix operator with **no available operand**
  (next token is a terminator `) , ] ;` / EOF, or an infix/postfix op that can't
  start an operand) parses as a **nullary Apply** instead of erroring, then uses
  nullary-pop to take its operand(s) from the stack. So the prefix-erroring ops
  (`? Δ ~>`) become stack-pullable. *Zero-regression:* this only converts a former
  parse **error** (op with no operand) — every operand-bearing prefix parse
  (`~foo`, `@(~x)`, trains) is byte-identical. **Loud** stack-underflow error if the
  stack lacks the operand (never silent-empty).
- **`$_stdin` on the stack** — when input is piped (`… | nlir`), the evaluator seeds
  the premise stack at position 0 with the piped `_stdin` value, so a bare operator
  pulls it: `echo "the login page is broken" | nlir -e '~'` → its summary,
  `| nlir -e '#'` → its subject, `| nlir -e '?'` → it turned into a question. A bare
  **form/train** is a first-class *value*, so it evaluates to itself (not
  auto-applied) — apply it to piped input explicitly with `%$_stdin`
  (`… | nlir -e '(: & #)%$_stdin'`). Nullary-fallback is scoped to *operators*; a
  form is a value, not an operator.

### Context: read & assign
- **`$name`** — read `context[name]` (typed; `$_messages` is the array). The `$` is
  **required** to reuse a binding: a **bare** `name` (no `$`) is a string *literal*, not
  the bound value — so a "reusable part" written `part..3` silently reads the literal
  `"part"` (garbage, no error), while `$part..3` reads the binding. Reusable-parts idiom:
  `p='the planets from the sun'; $p..3` → Earth (bd-6995d9).
- **`key=RHS`** — assign. `key` is a **literal key string** (identifier;
  `_`-prefixed = system key), `RHS` an expression. Yields the value; **writes
  immediately**. E.g. `_sep=\ `, `_cache=false`, `_seed=42`, `k=#^-1`.

### Message indexing (role-filtered views of `_messages`)
- **`^N`** — assistant; **`^_N`** — user; **`^*N`** — all; **`^/N`** — system.
- Indices are **expressions coerced to number**; negatives from the end.
- Ranges `M^N` (and `^_`/`^*`/`^/` variants): contents joined with `_sep`. `^`
  binds tightest. E.g. `(1+1)^(5+5)` = assistant messages 2..10.

### Structure
- **`[a,b,c]`** — list; spreads into a variadic op (`&[a,b,c]` ≡ `a&b&c`), or
  renders to text by joining with `_sep`.
- **`(…)`** — grouping; overrides precedence and is preserved in output
  (parens always win).
- **`` ` ``** — a low-precedence prefix that forces the **whole of its right-hand
  subexpression** to evaluate **serially**; the marked subtree still runs in
  parallel with respect to its siblings.

### Forms, application & macros (metaprogramming)
- **`{EXPR}`** — a **quoted form**: `EXPR` as an unevaluated first-class value (a
  `Form`), *not* run. `{2+3}` → the form `{(2 + 3)}`, not `5`. Braces = code-as-data;
  parens `(…)` = the evaluated value.
- **`%`** — **application** (infix): applies a form to arguments, binding them to the
  positional holes `$0 $1 …` in a fresh **argument frame**, then evaluates the body.
  `{$0+$1}%(2,3)` → `5`; single arg `{$0+1}%5` → `6`. `%` binds **tighter than `,`**
  (`f%a,b` = `(f%a),b`; pass a tuple with `f%(a,b)`). `%` is **right-associative**, so
  a bare compose-chain `f%g%x` reads as `f%(g%x)` — apply `g` to `x`, then `f` to the
  result (`$sort%$map%({$0*$0},[3,1,2])` = `$sort%($map%(…))` → `[1,4,9]`), matching
  J/APL application order; the left-associative reading `(f%g)%x` is never intended
  (it was a silent-empty / unknown-key trap). Explicit parens/nesting still work as
  written; only bare `%`-chaining is affected.
- **Argument holes `$0 $1 …`** — positional parameters inside a form, bound at apply
  time. **Hygienic**: a form's `$0` is its *argument*, not the run stack (`9;{$0}%7` → `7`).
- **Named macros** — assign a form to a name and call it by name (forms persist in
  context): `steelman={~(>@$0)}; $steelman%'we should rewrite it in Rust'`. The whole
  idiom phrasebook becomes a named, reusable library.
- **Do-N composition `{form}_N`** — builds a form that applies `form` repeatedly,
  then `%` runs it: `({$0+1}_3)%5` → `8`. Runtime construction is capped at
  **64 applications**; larger counts error before allocating a deep AST. Evaluation
  independently bounds all recursive paths, including runtime-built form arguments,
  so malformed/generated trees fail cleanly instead of overflowing the native stack.
- Building/applying forms is deterministic (structural); only the realisation of the
  *expanded* body hits the model.

### Dictionaries & accessors
- **`{k=v, k2=v2}`** — a **dict literal**: an insertion-ordered `key=value` map. A
  `{…}` is a **dict** iff its body is a comma-list (or single) of ≥1 items that are
  **all** `key=value` assigns; a single non-assign expression is a **form** instead
  (`{2+3}` → the form `{(2 + 3)}`); empty `{}` is an empty dict. Keys are bare-name
  strings; values eval **eagerly** at construction (`{k=1+2}` → `{k=3}`), except an
  explicit form-literal value stays quoted (`{k={$0*2}}` → `k` ↦ a form — code-as-data).
  A `;` inside `{…}` is a **clear error**, never a form: a form-quote holds a *single*
  expression, so a multi-statement `{a; b}` block has no representation.
- **`.`** — the **polymorphic accessor** (deterministic, structural): `container.key`.
  `[a,b,c].1` → `b` (0-based list index; negative counts from the end, `.-1` → last),
  `{k=v}.k` → `v` (dict field), `"the".2` → `e` (char at index). Out-of-range or a
  missing key is a **loud error**, never a silent empty. Distinct from `$nth`.
- **`..`** — the **semantic accessor**, the LLM twin of `.`: reads element N from the
  sequence *described* by the text. `"the planets from the sun"..3` → "earth"; it
  generalizes past integers to descriptors ("the last", "the largest"). A deterministic
  stub (`item N of: …`) keeps det-total; the model realises llm mode. The `.`↔`..`
  duality (structural access ↔ semantic access) rhymes with `~>` and `@`↔`=>` — the
  det/llm pairing that recurs across the vocabulary.
  **Numeric range**: when *both* operands are integer literals (`a..b`), `..` short-circuits
  to a deterministic inclusive **range list** instead of semantic access — `1..5` →
  `[1,2,3,4,5]` (ascending), `5..1` → `[5,4,3,2,1]` (descending), `3..3` → `[3]`. This
  repurposes the otherwise-useless numeric case (indexing a number is nonsensical) into the
  range literal mathy programs need: `$fold%({$0+$1},1..100)` → 5050 (Gauss), `{$0*$1}⊘(1..5)`
  → 120 (5!). Text-LHS semantic access (`"primes"..5`) is untouched — only two integer
  operands trigger the range.
  **Seed reliability**: a terse descriptor can win on brevity (`sol..3` → "Earth", reading
  `sol` as the Sun) but terse meaning-tokens are often ambiguous — `sol` is also the solfège
  note, so higher indices drift (`sol..7` → "Si") — and llm realisation is non-deterministic.
  Prefer an unambiguous seed (`"the planets from the sun"..3`) for anything you'll re-run or ship.
  **Access kind**: an unambiguous seed is necessary but *not* sufficient. Reliability also
  depends on whether the addressed element is *recalled* as a distinctive fact or *enumerated*
  by counting. Distinctive named constants are stable across samples (`'perfect'..2` → 28 on
  every draw — the 2nd perfect number is a recalled fact); an ordinal index into a counting
  sequence can be flaky *within one transport* (`'primes'..5` measured 11, 7, 7 over three
  identical runs — the model sometimes miscounts the enumeration). So `..N` is dependable only
  when the element is a recallable fact, not a derived count. For anything asserted or shipped,
  prefer deterministic math (fold/map over explicit lists) over ordinal semantic access; reserve
  `..` for the "describe the math, the model supplies the sequence" demo, where the supply may
  vary or err. (Measured 2026-07-08, sonnet CLI; see bd-429d87.)
- **Limitation (v1)**: chained *numeric* access `list.1.0` lexes `1.0` as a float
  (numeric-literal lexing runs before operator matching — which is exactly what keeps
  `3.14` a number), so it is a clear "index must be an integer" error; use `(list.1).0`.
  Dict/string chaining (`.k.k2`, `.1.k`) is unaffected.

### Higher-order list builtins (`$map` / `$fold` / `$scan` / `$filter`)

Deterministic, model-free list combinators (bd-14af74): each takes a **form** as its
first argument and applies it structurally — the form's body only touches the model if
it *itself* contains an llm op. `$map` has a keyboard-typable alias (`<$>`) and a
visual alias (`↦`); `$fold` has `⊘` (see the operator table). `$scan` and `$filter`
are builtin-only. These aliases are ordinary `config.yaml` operators using `builtin:` —
the engine does not hardcode their spellings.

- **`$map%(f, list)`** — apply `f` to each element: `$map%({$0*$0},[1,2,3])` → `[1,4,9]`. Aliases `<$>` and `↦`: `{$0*$0}<$>[1,2,3]`.
- **`$fold%(f, list)`** — reduce `list` with the binary form `f` (`$0` = accumulator, `$1` = element), seeded by the first element: `$fold%({$0+$1},[1,2,3,4])` → `10`. Alias `⊘`. Pairs with the numeric range for exact aggregates: `$fold%({$0+$1},1..100)` → `5050` (Gauss).
- **`$scan%(f, list)`** — like `$fold` but returns every intermediate accumulator (the running reduction): `$scan%({$0+$1},[1,2,3,4])` → `[1,3,6,10]` (running sums); `$scan%({$0*$1},1..5)` → running factorials `[1,2,6,24,120]`.
- **`$filter%(f, list)`** — keep the elements for which `f` is truthy: `$filter%({$0>=5},[3,7,2,9])` → `[7,9]`; with a predicate builtin, `$filter%({$gt%($0,$m)},1..10)` selects those above a bound `$m`. Composes the whole trio: `$fold%({$0+$1},$map%({$0*$0},$filter%({$0},[1,2,3,0,4])))` → `30`.

Together these are the deterministic composable core — statistics (mean = `$fold%(…)/$len%…`), running series, and predicate-filtered aggregates — all exact, model-free, and CI-gateable.

### Set-notation builtins (`$elem` / `$union` / `$inter` / `$diff`)

Deterministic, total set algebra over values (bd-49d65a). Like `$sort`/`$contains`,
element identity is the **rendered value** (trimmed), so lists of numbers, strings,
or mixed values compare predictably. `$union`/`$inter`/`$diff` return a list;
results are **order-preserving** (first-occurrence order of the left operand) and
**deduped**. Coercion for the algebra ops: a **list** spreads to its items, a
**dict** spreads to its **keys** (set ops on a dict operate on its key set), and a
scalar is a one-element set.

- **`$elem%(item, coll)`** — membership `Bool`, the flip of `$contains`
  ("contained-in / element-of"). Polymorphic on `coll`: a **list** → exact element
  membership (`$elem%('b',[a,b,c])` → `true`); a **dict** → key membership
  (`$elem%('k',{k=1,j=2})` → `true`); a **string** → substring
  (`$elem%('broken','login page broken')` → `true`); a scalar → equality.
- **`$union%(a, b, …)`** — variadic union: `$union%([1,2],[2,3])` → `[1,2,3]`. A
  single list argument doubles as **unique/nub**: `$union%[a,b,a,c]` → `[a,b,c]`.
- **`$inter%(a, b)`** — intersection `a ∩ b`: items of `a` (a-order, deduped) also
  in `b`. `$inter%([1,2,3],[2,3,4])` → `[2,3]`; a disjoint pair → the empty list.
- **`$diff%(a, b)`** — difference `a ∖ b`: items of `a` (a-order, deduped) not in
  `b`. `$diff%([1,2,3],[2])` → `[1,3]`. (Distinct from the semantic `Δ` operator,
  which is an llm text-diff, not set subtraction.)

They compose with the rest of the value-builtin family:
`$if%($elem%('ERROR',$0),'page','ok')` gates on membership;
`$nth%(0,$sort%$union%(a,b))` = the least element of a merged set. Sigil aliases
(`∪ ∩ ∈ ∖`) are a planned follow-up (config-operator layer).

### Length builtin (`$len`)

**`$len%coll`** — the length/cardinality of `coll` as a `Number` (bd-b9b491):
a **list** → item count, a **dict** → key count, and anything else
(**string**/number/bool/form) → the Unicode character count of its rendered form
(so a string's length is its chars: `$len%'hello'` → 5, `$len%42` → 2). Total +
deterministic — the model-free counting primitive: `$len%[2,3,5,7,11]` → 5,
`$len%{a=1,b=2}` → 2, and set cardinality `$len%($inter%([2,3,5,7,11],[1,3,5,7,9]))`
→ 3. A spread list `$len%[a,b,c]` (3 args) counts 3; a single scalar in a
single-element list `$len%[x]` is indistinguishable from `$len%x` after the spread.

### Predicate builtins (`$gt` / `$lt` / `$not`)

**`$gt%(a,b)`** / **`$lt%(a,b)`** — STRICT numeric comparison (bd-89b3d0),
`a > b` / `a < b`, returning a `Bool`. They fill the strict-comparison gap: the
`>`/`<` sigils are taken (expand/shorten), and the `>=`/`<=` operators are
non-strict, so `$gt%(3,3)` → false where `3>=3` → true. Operands coerce to number
like `>=`/`<=`.

**`$not%(x)`** — boolean NOT: negates `x`'s truthiness and returns a `Bool`.
Unlike `!` (which is *textual* negation, e.g. `!(3>=5)` → the string "not (false)"),
`$not` inverts any Bool — including a fuzzy `~>` result — so it composes in
fold-fusion count-if-NOT. Since Bools coerce true→1 under `+`, map a predicate then
fold to count: `$fold%({$0+$1},$map%({$lt%($0,5)},0..10))` → 5. The sigil alias
`¬` (config operator, prefix) completes `∧ ∨ ¬` — see the operator table.

### Rounding builtins (`$floor` / `$ceil` / `$round`)

Fundamental numeric primitives (bd-9004bb): `$floor%x` → ⌊x⌋, `$ceil%x` → ⌈x⌉,
`$round%x` → nearest integer (half away from zero). Operand coerces to number.
They keep `$nth` strict (it rejects a fractional index) while letting **median** fall
out of sort + index — no special `$median` function: `$nth%($floor%($len%L/2),$sort%L)`
is the middle element for odd length. The two middle indices are `$floor` and `$ceil`
of `($len-1)/2`, so one expression gives the median for both parities (mean of the two
middles when even). Same principle as max = sort-then-last: composable primitives over
special-cased sugar. A sigil alias (⌊⌋) is a config-operator follow-up.

**`$sqrt%x`** (bd-92cbf0) — square root (`f64::sqrt`; negative operand → `NaN`). Same
unary-numeric family. It completes **stddev** — variance already composes from
`$fold`/`$map`/`$len`, so stddev = `$sqrt%variance` — and unlocks Pythagoras/hypotenuse
(`$sqrt%(3*3+4*4)` → 5), Euclidean distance, and geometric mean. A `√` sigil is a
config-operator follow-up.

### Modulo builtin (`$mod`)

**`$mod%(a,b)`** — mathematical modulo (mathy golf): the remainder of `a` divided
by `b` via `rem_euclid`, so the result is **non-negative** in `[0, |b|)` —
`$mod%(7,3)` → 1, `$mod%(0-1,3)` → 2 (not -1, unlike C-style `%`). Operands coerce
to number like `$gt`/`$lt`; a zero divisor is a loud error. The non-negative
convention is what makes number theory compose cleanly: even/odd (`$mod%(n,2)` →
0/1), divisibility (`$mod%(n,k)` → 0), cyclic indexing, and Euclid-style GCD. Count
evens in 1..10: `$len%($filter%({$not%($mod%($0,2))},1..10))` → 5.

Reserved builtin sigils: `; $ ^ = [ ] , ( ) { } % \` `` ` `` , the quote chars `" '`,
the escape `\`. Configured operator sigils (`# ! & | ? + - * / ** …`) add to this.
After `^`/`$`, `* _ /` are role modifiers and a leading `-` is a negative index.

---

## Whitespace, escapes & quoting

- **Whitespace between tokens is non-semantic** (spaces/tabs/newlines stripped) —
  expressions can be written as multi-line programs.
- **Bare literal** = `[a-zA-Z0-9]+`; numbers are numeric literals in numeric
  positions. For spaces/sigils use escapes or quotes.
- **POSIX escapes** → literal chars incl. whitespace: `\ ` `\t` `\n` `\\` `\"`
  `\'`.
- **Quotes** preserve internal whitespace:
  - `'…'` — raw (no escapes, no interpolation);
  - `"…"` — escapes processed **and** bare `$name` interpolated (see below);
  - `'one two'` → "one two".

---

## Interpolation & evaluation timing

- Context reads (`$name`, `$N`, `^…`) and `"…"` interpolation are resolved
  **greedily at evaluation time**, not parse time — context may change mid-run
  (appended messages, `=` writes), so late resolution reflects current state.
- Only bare `$name` interpolates inside `"…"` — not `${…}`, `$N`, `^…`, or nested
  expressions. `"the subject is $k"` interpolates `$k` when that node evaluates.

---

## Execution graph & parallelism

- The program is a **DAG**; independent LLM calls / `command:` subprocesses run
  **concurrently**, bounded by `--parallelism` (default `8`).
- **Safety:** greedy interpolation + context writes make blind parallelism unsafe.
  Any subtree that **writes context** (`=`) is serialised against readers; when in
  doubt the scheduler forces serial.
- **`` ` `` prefix** forces serial evaluation of the whole of its RHS for ordering
  automatic detection can't infer — but the marked subtree stays parallel with its
  siblings. In `` a+`(a+b) `` the outer operands `a` and `` `(a+b) `` run in
  parallel, while `a` then `b` inside the backtick run serially.
- **Caching:** identical subcalls `(op, mode, model, grouping, operand-texts, seed)`
  are deduped when `_cache` is true (default); `_cache=false` disables it. A normal
  evaluation owns a run-local cache. Incremental/speculative hosts may retain an
  `EvaluationCache` across edits via `evaluate_with_cache`,
  `evaluate_async_with_cache`, or the cached async step/streaming variants:
  unchanged call keys hit, while an edited operand
  changes its key and naturally invalidates that node and every dependent parent.
  Cache locks are never held across an async realiser await; retention is bounded
  to 1024 completed calls, and hosts clear the cache when config/model policy
  changes incompatibly.

---

## Output & tracing

- **Default:** result → **stdout**; a pretty, real-time trace of the expansion
  (ops / LLM calls resolving) → **stderr**.
- **`--quiet`** — stdout result only.
- **`--dry-run`** — DAG + assembled prompts, no calls.

---

## Config operators (the language proper)

The **canonical operator vocabulary** — each realised via `template` / `reduce` /
`command` (det) or `prompt` (llm). These descriptions are the authoritative
semantics, mirrored by `nlir help` and the
[phrasebook](examples/phrasebook.md).

**String / text operators** (llm-realised unless a `template`/`command` is given):

| op | name | fixity · arity | what it does |
|---|---|---|---|
| `#` | subject | prefix · 1 | The text's primary subject as a short noun phrase — a topic label, not a definition. Over a list, folds to the common category when the items share one; otherwise lists them per-item. |
| `!` | not | prefix · 1 | Negates the claim, clause-wise (`!(a&b)` = neither); on a lone concept-word, its antonym. Involution: `!!x ≈ x`. |
| `~` | summary | prefix · 1 | The essence in one short sentence — drops specifics for the gist. Saturates (`~~x ≈ ~x`); folds a list to its consensus. |
| `@` | formal | prefix · 1 | Rewrites in a formal, professional register, meaning preserved. Saturates after one pass; distributes over `&`. |
| `:` | simplify | prefix · 1 | Rewrites in plain, simple language (strips jargon). The one op that reliably maps per-item over a list. |
| `>` | expand | prefix · 1 | Adds detail and explanation (lengthens). Forks over `or` (keeps paths distinct), integrates over `&`. |
| `<` | shorten | prefix · 1 | Tightens to the information floor — fewest words, but keeps every fact and figure (vs `~` = the gist). |
| `?` | question | postfix · 1 | Turns the text into a question. A yes/no question is polarity-neutral (`!x? ≈ x?`). |
| `&` | and | mixfix · >0 | Joins operands into one "X and Y" statement (a plan, not boolean ∧); nullary `&` folds the premise stack. |
| `\|` | or | mixfix · >0 | Joins operands into one "X or Y" choice, kept as genuine alternatives. |
| `_` | echo | infix · 2 | Repeats the text N times, space-joined (`x_2` = "x x"). The one shell-`command`-realised op. |
| `.` | access | infix · 2 | Polymorphic structural accessor (deterministic): `[a,b,c].1`→`b` (0-based, negative from end), `{k=v}.k`→`v`, `"the".2`→`e`. Loud on out-of-range / missing key. |
| `..` | access-semantic | infix · 2 | The LLM twin of `.`: reads element N from the sequence *described* by the text (`"planets from the sun"..3`→"earth"), generalizing to descriptors. det-stub keeps det-total. **Numeric `a..b`** (both integer operands) short-circuits to a deterministic inclusive range list: `1..5`→`[1,2,3,4,5]`, `5..1`→`[5,4,3,2,1]` (descending), repurposing the useless numeric-index case. |
| `++` | concat | mixfix · >0 | Concatenate the string operands (deterministic): `"foo"++"bar"` → "foobar". |
| `//` | split | infix · 2 | Split a string by a separator into a list (deterministic): `"a,b,c"//","` → `[a,b,c]`. |
| `Δ` | diff | infix · 2 | Directional diff — what changed from the first text to the second (added / removed / shifted). Non-commutative (`aΔb ≠ bΔa`); powers before/after, drift, changelog. |
| `~>` | implication-check | infix · 2 | Does the LHS imply the RHS? Integrates over `&`. |
| `~>?` | implication-infer | mixfix · >0 | Infers the implication (the consequent) of its arguments. Integrates over `&`. |

**Numeric operators** (`operands: number`, `result: number`, `reduce:`):

| op | name | fixity · arity | what it does |
|---|---|---|---|
| `+` | add | mixfix · >0 | Sum of the operands (words / units / bases coerce to numbers first). |
| `*` | mul | mixfix · >0 | Product of the operands. |
| `-` | sub | infix · 2 | Difference, a − b (left-associative). |
| `/` | div | infix · 2 | Quotient, a ÷ b (guards divide-by-zero). |
| `**` | pow | infix · 2 | a to the power b — right-associative, so `2**3**2` = `2**(3**2)` = 512 (matches math / Python). |

**Comparison operators** (`result: bool`, `reduce:`-realised, deterministic):

| op | name | fixity · arity | what it does |
|---|---|---|---|
| `==` | equals | infix · 2 | True when the operands are equal (by rendered value): `5==5` → true, `3==4` → false. |
| `!=` | not-equals | infix · 2 | True when the operands differ: `3!=4` → true. |
| `<=` | at-most | infix · 2 | True when the first operand is numerically ≤ the second: `3<=5` → true. |
| `>=` | at-least | infix · 2 | True when the first operand is numerically ≥ the second: `5>=3` → true. |

**Higher-order (list) operators** (deterministic; configured aliases for the `$map` / `$fold` builtins):

| op | name | fixity · arity | what it does |
|---|---|---|---|
| `<$>` | mapascii | infix · 2 | Keyboard-typable map: apply the left form to each item of the right list: `{$0*$0}<$>[1,2,3]` → `[1,4,9]`. Alias for `$map%`; `↦` is its visual twin. |
| `↦` | mapop | infix · 2 | Visual map alias with the same configured `builtin: map` semantics as `<$>`. |
| `⊘` | foldop | infix · 2 | Reduce the right list with the left binary form: `{$0+$1}⊘[1,2,3,4]` → `10`. Alias for `$fold%`. |
| `∪` | setunion | infix · 2 | Set union: `a ∪ b` — order-preserving, deduped. Deterministic alias for `$union%` (binary case). Dict operands → their keys. |
| `∩` | setinter | infix · 2 | Set intersection: `a ∩ b` — items of `a` also in `b` (deduped, a-order). Alias for `$inter%`. Binds tighter than `∪`/`∖`. |
| `∖` | setdiff | infix · 2 | Set difference: `a ∖ b` — items of `a` not in `b` (deduped, a-order). Alias for `$diff%`. (`∖` = U+2216 SET MINUS.) |
| `∈` | setelem | infix · 2 | Membership: `x ∈ coll` → Bool — list element, dict key, or string substring. Alias for `$elem%` (`item ∈ collection`). |
| `∧` | booland | infix · 2 | Logical AND: `a ∧ b` → Bool, true iff both operands are truthy. First-class conjunction, distinct from compose-`&` (string weave). Binds tighter than `∨`; evaluates both operands (use `$if` for short-circuit). |
| `∨` | boolor | infix · 2 | Logical OR: `a ∨ b` → Bool, true iff either operand is truthy. Distinct from compose-`\|` (string choice). |
| `¬` | boolnot | prefix · 1 | Logical NOT: `¬a` → Bool, true iff `a` is falsy. Negates any Bool (incl. a fuzzy `~>` result); the boolean twin of `!` (textual negation). Binds tighter than `∧ ∨`; composes in fold-fusion count-if-NOT. Glyph alias for `$not`. |
| `√` | sqrtop | prefix · 1 | Square root: `√x` → the non-negative square root as a Number (deterministic). Enables terse stddev (`√variance`), Pythagoras `√(3*3+4*4)`→5, Euclidean distance, geometric mean. Glyph alias for `$sqrt`. |

**Instruction-following (generation)** — the third category. Here the operand is
an *instruction to obey*, not text to reshape. This is the generative direction of
the language: it expresses *new* thoughts — replies, drafts, answers, "do X" —
rather than transforming existing text, and because it composes under `&`/`|` like
any string op it can *build* structured generated thoughts, not just emit a single
prompt (`(=>a)&(=>b)` joins two generated sentences). It carries its own generative
system frame (operand = instruction), so it obeys instead of describing, even on
weaker models — the reason `>"write one word"` merely expands the request while
`=>"write one word"` writes the word.

| op | name | fixity · arity | what it does |
|---|---|---|---|
| `=>` | respond | prefix · 1 | Obeys the instruction in the operand and returns only the result (length/format constraints included). Generative, not transformative; composes under `&`/`\|`; a bare `=>` on a pipe obeys the piped text as the instruction. |

Operands follow the usual quoting rule (§Interpolation): double-quoted operands
interpolate context, so `=>"one-sentence reply to: $_stdin"` folds a piped message
into the instruction; single-quoted operands stay literal. This is the
reply-generation idiom — pipe a message in, `=>` writes the reply — and because
`=>` composes, `(=>"warm ack: $_stdin") & (=>"gentle counter: $_stdin")` joins two
generated sentences.

The algebraic laws above (involution, saturation, `?`-absorption, list-folds) are
**realised-semantics**: they hold in llm realisation — the user-facing output —
while det mode applies the literal template (`!!a` → "not not a").

---

## Grammar & parsing

**Tokens:** bare literal `[a-zA-Z0-9]+`; numeric literal; quoted literal
(`'…'`/`"…"`); operator (longest configured `op:`, so `**` before `*` and `<$>`
as one token); builtin sigils `; $ ^ = [ ] , ( )` `` ` `` (with `$name`/`$N`,
`^`/`^_`/`^*`/`^/`, `LHS=` sub-forms); escapes `\x`. A builtin sigil may appear
later in a configured punctuation operator — `<$>` is config, not a lexer special
case. At a leading `$`, configured punctuation operators such as `$>`/`$(` longest-match
before the fallback; `$name`, `$_key`, `$N`, `$-N`, and bare `$` remain reserved
stack/context forms and cannot be shadowed by config.

**Operator attributes (config):** `op`, `arity` (`1`,`2`,…,`>0`), `fixity`
(`prefix`/`postfix`/`infix`/`mixfix`), `priority` (higher binds tighter,
default `9`), `assoc` (`left`/`right`, default `left`; only meaningful for
`infix`), `operands`/`result` types.

**Precedence (config-tunable):** `^` indexing is tightest; **prefix unary**
(`# ! ¬ √`) binds above **all binary**; binary follows normal math — `**` > `* /` >
`+ -` — then string `& |`; the postfix `?` is the deliberate loose exception
(binds everything to its left); `=` is loosest. Concretely: `^` 20 · `. ..` 16 · `# ! ¬ √` 14 ·
`** //` 13 · `* /` 12 · `+ -` 11 · `++` 10 · `& |` 9 · `<$> ↦ ⊘` 8 · `∩` 7 · `∪ ∖` 6 · `∈ == != <= >=` 5 · `∧` 4 · `∨` 3 · `?` 1 · `=` 0
(`nlir help` lists the exhaustive per-op priority; this prose summarises the tiers). prefix takes one right
operand; postfix takes leftward to its priority; variadic flattens; mixfix unifies
infix/list/nullary; ties → prefix > infix > postfix. **Associativity:** infix
operators are **left-associative** by default (`a-b-c` = `(a-b)-c`, `16/4/2` =
`(16/4)/2`); `**` sets `assoc: right`, so exponentiation is **right-associative**
(`2**3**2` = `2**(3**2)` = 512), matching normal math and Python. Mixfix operators
flatten same-op chains into one n-ary node, so associativity does not affect them.
`(…)` overrides and is
preserved in output.

---

## Worked examples

Assume the last assistant message (`^-1`) is about *a rust-rewrite*.

| Expression | Reading |
|---|---|
| `^-1` | last assistant message |
| `^_-1` / `^/-1` | last user / last system message |
| `(1+1)^(5+5)` | assistant messages 2..10, joined with `_sep` |
| `1+1` | "2" (number, stringified on output) |
| `#^-1` | "a rust-rewrite" |
| `!#^-1` | "not a rust-rewrite" |
| `#0^3;#^-1;&` | "subject(0..3), and a rust-rewrite" |
| `&[a,b,c]` | "a, b, and c" |
| `!(a&b)` | "not (a and b)" — parens preserved |
| `'one two'` | "one two" |
| `"the subject is $k"` | interpolates `$k` at eval time |
| `_sep=\ ;[a,b]` | "a b" |
| `` `k=#^-1;$k `` | serial: store subject as `k`, then read it |

---

## CLI surface

```
nlir -e 'EXPR' [--quiet] [--mode det|llm] [--model haiku] [--parallelism 8] [--dry-run]

# context read (precedence: --context-file › --session-file › NLIR_CONTEXT env › default file)
# (default file loads for the REPL / set / get; a one-shot `-e` skips it — bd-85c49d)
nlir … --context-file PATH
nlir … --session-file PATH        # e.g. Pi session: roles kept, tool calls dropped

# context write (immediate; on active/default context file); set = key replacement
nlir set KEY VALUE
nlir set '{"k":"v","_messages":[…]}'   # each named key replaced (not deep-merged)
nlir get KEY
nlir append-message [--role user] "text"

# interactive: one expr per submission, trailing `\` continues; :cmd == `nlir cmd`
nlir repl [--context-file F] [--raw]     # :set/:get/:append-message inside repl

# plumbing (CLI template stack)
nlir parse 'EXPR'
nlir test
nlir mcp stdio        # mcp-cli
nlir self-update …    # updatable-cli
nlir feedback …       # feedback-cli
```

**Pi plugin:** a prompt starting with `|` → the remainder is expanded as nlir
first; the plugin `append-message`s each turn and pipes shorthand into a long-lived
`nlir repl --raw`.

---

## Example `~/.config/nlir/config.yaml`

```yaml
defaults:
  mode: llm
  model: haiku
  parallelism: 8

context:
  env: NLIR_CONTEXT
  file_default: ~/.config/nlir/context.json
  messages:
    key: _messages
    role_field: role
    content_field: content
    views:                      # ^ / ^_ / ^* / ^/
      default: [assistant]
      user:    [user]
      all:     [user, assistant, system]
      system:  [system]
  defaults:
    _sep: "\n"                  # list & message-range → text separator
    _cache: true

types:                          # coercion targets (deterministic parse first, LLM fallback)
  number:
    model: haiku
    prompt: |
      Interpret the text inside <text> as a single number. Return only the number.

      %
    schema: { type: object, properties: { result: { type: number } }, required: [result] }
  bool:
    model: haiku
    prompt: |
      Interpret the text inside <text> as true or false.

      %
    schema: { type: object, properties: { result: { type: boolean } }, required: [result] }
  # string: numbers/bools/lists stringify deterministically (lists join with _sep)

sessions:
  pi:
    format: pi
    keep_roles: [user, assistant]
    drop_tool_messages: true
    role_field: role
    content_field: content

models:
  haiku:
    type: anthropic_messages
    base_url: https://api.anthropic.com/v1
    api_key: $ANTHROPIC_API_KEY
    model: claude-haiku-4-5
    format: json
    result_field: result
    messages:
      - role: system
        content: |
          ${NLIR_SYSTEM_PROMPT}
          ${NLIR_STRUCTURED_PROMPT}
      - role: user
        content: |
          ${NLIR_PROMPT}
    output_config:
      format:
        type: json_schema
        schema:
          type: object
          properties: { result: { type: string } }
          required: [result]
          additionalProperties: false
  sonnet:
    type: command
    format: json
    result_field: result
    command: >
      claude --model claude-sonnet-5
        --system-prompt "${NLIR_SYSTEM_PROMPT}"
        --append-system-prompt "${NLIR_STRUCTURED_PROMPT}"
        --output-format json --json-schema '{"result": "string"}'
        --print "${NLIR_PROMPT}"
  gpt-5.5:
    type: command
    format: text
    command: >
      pi --no-extensions --no-session --model github_copilot/gpt-5.5
        --system-prompt "${NLIR_SYSTEM_PROMPT}"
        --append-system-prompt "${NLIR_UNSTRUCTURED_PROMPT}"
        --print "${NLIR_PROMPT}"

prompts:
  system:      { env: NLIR_SYSTEM_PROMPT, text: "Perform the following text transformation task.\nRespond with the transformed text in plain language.\nDo not include <text> tags in your output." }
  structured:  { env: NLIR_STRUCTURED_PROMPT, text: "Format your response as JSON containing only a \"result\" field with the transformation, no preamble." }
  unstructured:{ env: NLIR_UNSTRUCTURED_PROMPT, text: "Output only the text result of your transformation with no preamble." }

operators:  # `%` = operand under replacement; `%%` = literal %
  subject:  { op: "#", arity: 1,   fixity: prefix,  model: haiku, prompt: "Extract the primary subject of the text inside <text> as a short noun phrase. Return only that noun phrase.\n\n%" }
  not:      { op: "!", arity: 1,   fixity: prefix,  template: "not %", model: haiku, prompt: "Negate the text inside <text>...</text>, changing nothing else.\n\n%" }
  and:      { op: "&", arity: ">0", fixity: mixfix, join: " and ", model: sonnet, prompt: "Combine the <text> items with an \"and\" connective into one text meaning \"t_0 and t_1 and ...\".\n\n%" }
  or:       { op: "|", arity: ">0", fixity: mixfix, join: " or ",  model: sonnet, prompt: "Combine the <text> items with an \"or\" connective into one text meaning \"t_0 or t_1 or ...\".\n\n%" }
  question: { op: "?", arity: 1,   fixity: postfix, priority: 0, template: "is it the case that %?", model: gpt-5.5, prompt: "Convert the text inside <text> into a question, preserving subject and meaning.\n\n%" }
  echo:
    op: "_"
    arity: 2
    fixity: infix
    command: |
      t="${NLIR_ARGS[0]}"; n="${NLIR_ARGS[1]}"; out="$t"
      for i in $(seq 1 $((n-1))); do out="$out $t"; done
      printf '%s' "$out"
  add: { op: "+",  arity: ">0", fixity: mixfix, priority: 11, operands: number, result: number, reduce: add }
  mul: { op: "*",  arity: ">0", fixity: mixfix, priority: 12, operands: number, result: number, reduce: mul }
  sub: { op: "-",  arity: 2,   fixity: infix,  priority: 11, operands: number, result: number, reduce: sub }
  div: { op: "/",  arity: 2,   fixity: infix,  priority: 12, operands: number, result: number, reduce: div }
  pow: { op: "**", arity: 2,   fixity: infix,  priority: 13, assoc: right, operands: number, result: number, reduce: pow }

tests:
  det-echo:   { mode: det, expr: "xxx_2",         expected: "xxx xxx" }
  det-not:    { mode: det, expr: "!foo",           expected: "not foo" }
  det-and:    { mode: det, expr: "a&b&c",          expected: "a and b and c" }
  det-group:  { mode: det, expr: "!(a&b)",         expected: "not (a and b)" }
  det-quote:  { mode: det, expr: "'one two'",      expected: "one two" }
  det-sep:    { mode: det, expr: "_sep=\\ ;[a,b]", expected: "a b" }
  det-assign: { mode: det, expr: "k=foo;$k",       expected: "foo" }
  num-add:    { mode: det, expr: "1+2+3",          expected: "6" }
  num-index:  { mode: det, expr: "(1+1)**3",       expected: "8" }
  num-powassoc:{ mode: det, expr: "2**3**2",        expected: "512" }
  msg:
    mode: det
    context:
      _messages:
        - { role: user,      content: "hi" }
        - { role: assistant, content: "in rust" }
    expr: "^-1"
    expected: "in rust"
```

---

## Implementation / project shape

Rust, Nix-flake-managed, on the harryaskham CLI template stack (mature examples
under `~/.cacophony/daemon/checkouts/…`): **mcp-cli** (`nlir mcp stdio` — the whole
surface is agent-callable), **updatable-cli** (`nlir self-update`), **feedback-cli**
(`nlir feedback`). Behaviour above is the spec; this is the scaffolding pattern.
```
