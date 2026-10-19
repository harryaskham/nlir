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
  default `"\n"`), `_cache` (`eval` default · `persist` · `off`; `true`/`false`
  still mean `eval`/`off` — see Caching), `_cache_file` (the persistent
  realisation store), `_precision`
  (final-display decimal places for numbers, default off = exact/round-tripping;
  display-only, never changes computation), `_seed` (an integer **namespace** for
  realisations, unset by default: the same seed replays recorded calls, a new seed
  draws fresh samples. It is also exported as `${NLIR_SEED}` and sent as the
  request's top-level `seed`, but providers do not make that reproducible — measured
  Oct 2026, Claude ignores it and gpt-4.1 varies even at temperature 0 — so
  determinism comes from the store, and each model declares `seed: exact |
  best-effort | none`, shown by `--dry-run`).
- **Context writes happen immediately** (write-through to the context file when
  one is active).

---

## Types & coercion

Every value has a type: **`string`** (default), **`number`**, **`bool`**,
**`list`**, **`dict`** (an insertion-ordered `key=value` map — see Dictionaries &
accessors below), **`form`** (a quoted `{…}` expression — see metaprogramming below).

- Operators declare `operands:` / `result:` types (default `string`). `^` indices
  and arithmetic want `number`; `!`/`&`/`::` want `string`; `++` takes `any`.
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

- **Literal types:** a bare literal written as a canonical number (`12`, `2.5`, `-3` —
  it renders back to the same text) is a `number`, and bare `true` / `false` are
  `bool`s; anything else, including `007` and `1.50`, is text. Quoted literals are
  always text. So data built from literals stays typed (`$json%[1, true]` → `[1,true]`).

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
  nullary-pop to take its operand(s) from the stack. So infix ops (`Δ ~> ::`)
  become stack-pullable. *Zero-regression:* this only converts a former
  parse **error** (op with no operand) — every operand-bearing prefix parse
  (`!foo`, `=>(!x)`, trains) is byte-identical. **Loud** stack-underflow error if the
  stack lacks the operand (never silent-empty).
- **`$_stdin` on the stack** — when input is piped (`… | nlir`), the evaluator seeds
  the premise stack at position 0 with the piped `_stdin` value, so a bare operator
  pulls it: `echo "ship it Friday" | nlir -e '=>'` obeys it,
  `| nlir -e '!'` → its opposite. A bare **form/train** is a first-class *value*, so
  it evaluates to itself (not auto-applied) — apply it to piped input explicitly
  with `%$_stdin` (`… | nlir -e '($gist ∘ $plain)%$_stdin'`). Nullary-fallback is scoped to *operators*; a
  form is a value, not an operator.

### Context: read & assign
- **`$name`** — read `context[name]` (typed; `$_messages` is the array). The `$` is
  **required** to reuse a binding: a **bare** `name` (no `$`) is a string *literal*, not
  the bound value — so a "reusable part" written `part..3` silently reads the literal
  `"part"` (garbage, no error), while `$part..3` reads the binding. Reusable-parts idiom:
  `p='the planets from the sun'; $p..3` → Earth (bd-6995d9).
- **`key=RHS`** — assign. `key` is a **literal key string** (identifier;
  `_`-prefixed = system key), `RHS` an expression. Yields the value; **writes
  immediately**. E.g. `_sep=\ `, `_cache=off`, `_seed=42`, `k=$subject%^-1`.

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
- **Enclosing-form arguments `$$0 $$1 …`** — inside a nested form, each extra `$`
  steps one argument frame out: `$$0` is the *enclosing* form's `$0` (`$$$0` two
  frames out). This is how an inner form (a `$filter` predicate, a `↦` body) reads
  the outer form's arguments without clobbering global context — closures without
  a binding construct: `{$filter%({$gt%($0,$$0)}, [1,5,9])}%4` → `[5,9]`;
  `parent={$filter%({$elem%($$0, $0.kids)}, $nodes)}`. Loud when no such frame or
  argument exists.
- **Named macros** — assign a form to a name and call it by name (forms persist in
  context): `steelman={($0 :: 'its strongest, most charitable form') .. 'the gist'};
  $steelman%'we should rewrite it in Rust'`. The prelude (§Prelude) is exactly such a
  library, loaded into every run.
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
- **Precedence**: `.` (priority 19) binds tighter than `%` application (18), so a
  form stored in a dict applies like a method — `lib={dbl={$0*2}};$lib.dbl%21` → `42` —
  and `$f%$row.k` applies `$f` to `$row.k`. A parenthesised argument list closes the
  call, so `$get%($nodes, $id).title` reads `.title` of the result, as `f(x).k` would.
- **snake_case keys**: directly after `.`, a key run includes `_`
  (`$node.rule_policy_exact`), and an identifier containing `_` that is followed by an
  assignment `=` is one key (`first_name=ada`, `{row_id=1}`). Elsewhere `x_2` still
  splits for the `_` echo operator.
- **Limitation (v1)**: chained *numeric* access `list.1.0` lexes `1.0` as a float
  (numeric-literal lexing runs before operator matching — which is exactly what keeps
  `3.14` a number), so it is a clear "index must be an integer" error; use `(list.1).0`.
  Dict/string chaining (`.k.k2`, `.1.k`) is unaffected.

### Data trees: loading and navigating structured data

Context values keep their JSON structure: objects are insertion-ordered **dicts**,
arrays are **lists**, all the way down (a context file, `NLIR_CONTEXT`, the wasm
`contextJson`, and assigned dicts round-tripping through context). Load a whole file
as a native value with **`--bind NAME=PATH`** (`.json` and `.yaml`/`.yml` load as
data; any other file — Markdown, text — binds as one string; repeatable; transient —
never written to a context file):

```
nlir --bind spec=spec.json -f lib.nlir -e '$join%({$0.id}↦$spec.items, ", ")'
```

**`-f PATH`** runs a program file (repeatable; files then any `-e` are joined as
`;`-separated statements, so a library file can define named forms used later).
In program files, lines whose first non-blank characters are `--` are comments.

Deterministic data builtins (all loud on bad input; a context key of the same name
shadows them):

| builtin | result |
|---|---|
| `$keys%d` / `$values%d` | a dict's keys / values (a list's indices / items) |
| `$entries%d` | `[{key=k, value=v}, …]` — map a dict like a list of records |
| `$dict%pairs` | a dict from `[key, value]` pairs or `{key, value}` records — the inverse of `$entries`, and the way to build a dict with computed keys |
| `$get%(c, k)` / `$get%(c, k, default)` | dynamic `.`: dict key or list/string index (`$get%($nodes, $id)` for keys with spaces); missing → default, else loud |
| `$has%(c, k)` | Bool: is `k` a key / valid index |
| `$omit%(d, keys)` / `$pick%(d, keys)` | the dict without / with only those keys (one key or a list), in its own order — e.g. keep reserved packet keys out of a prompt: `$json%($omit%($p, [_pin, _concepts]))` |
| `$join%(list, sep)` | items rendered and joined with `sep` |
| `$flat%list` | flatten one level — the concat recursive tree walks need (and list append: `$flat%[$xs, [x]]`) |
| `$zip%(a, b, …)` | `[[a0, b0], [a1, b1], …]`, truncated to the shortest — pair parallel results with their inputs |
| `$slice%(c, start[, end])` | sub-list / substring, end-exclusive, negatives from the end, clamped |
| `$json%v` / `$json%(v, indent)` | the value as JSON text (dicts stay ordered) |
| `$parse%text` | JSON text as a value — the inverse of `$json`; tolerates a code fence or prose around the JSON (model replies), loud when there is none |
| `$type%v` | `string` · `number` · `bool` · `list` · `dict` · `form` |
| `$trim%s` · `$lower%s` · `$upper%s` · `$lines%s` | text plumbing (`$lines` splits on newlines) |
| `$replace%(s, from, to)` | literal replace-all |
| `$match%(s, re)` | first regex match — the whole match, its one group, or a list of groups; `''` if none |
| `$matches%(s, re)` | every match (same shape per match) |
| `$sub%(s, re, repl)` | regex replace-all (`$1`, `${name}` refer to groups) |

Write regexes in single quotes (`'\d+'`): double-quoted strings process `\` escapes.
A recursive named form walks a tree:
`ids={$flat%[[$0.id], $flat%({$ids%$0}↦$0.children)]}; $ids%$tree`.

### Higher-order list builtins (`$map` / `$fold` / `$scan` / `$filter`)

Deterministic, model-free list combinators (bd-14af74): each takes a **form** as its
first argument and applies it structurally — the form's body only touches the model if
it *itself* contains an llm op. `$map` has a keyboard-typable alias (`<$>`) and a
visual alias (`↦`); `$fold` has `⊘` (see the operator table). `$scan` and `$filter`
are builtin-only. These aliases are ordinary `config.yaml` operators using `builtin:` —
the engine does not hardcode their spellings.

- **`$map%(f, list)`** — apply `f` to each element: `$map%({$0*$0},[1,2,3])` → `[1,4,9]`. Aliases `<$>` and `↦`: `{$0*$0}<$>[1,2,3]`.
- **`$fold%(f, list)`** / **`$fold%(f, list, seed)`** — reduce `list` with the binary form `f` (`$0` = accumulator, `$1` = element), seeded by the first element, or by `seed` when given (so the accumulator may differ in type from the items and an empty list folds to `seed`; `$scan` takes the same optional seed): `$fold%({$0+$1},[1,2,3,4])` → `10`. Alias `⊘`. Pairs with the numeric range for exact aggregates: `$fold%({$0+$1},1..100)` → `5050` (Gauss).
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
the escape `\`. Configured operator sigils (`# ! & | :: .. + - * / ** …`) add to this.
After `^`/`$`, `* _ /` are role modifiers and a leading `-` is a negative index.

---

## Lenses: backward passes (`nlir put`)

A program is a *get*: inputs (bound data, its own literals) → output. `nlir put
--edited FILE [-f …] [--bind …] [EXPR]` is its *put*: it runs the program forward
(det), pushes the edited output back through it, and prints JSON — the edits to bound
inputs (`kind: data`, with `/`-separated leaf paths), the edits to program literals
(`kind: program`, with the statement and AST path), edits that could not be pushed
further (`stuck`, naming the expression and why), and clashing edits (`conflicts`).
Both lens laws are checked by re-evaluation: **GetPut** (the unedited output implies
no edits) and **PutGet** (the edited inputs and program reproduce the edited output).

Each deterministic construct carries its own put: `.` and `$get` set the field they
read; `++` aligns the edited text with its old parts by a character diff (an edit at a
boundary between a literal and a computed part goes to the computed part — content
belongs in data); `$join` splits on its separator; `$trim` restores whitespace; `↦` /
`$map` put each item through the mapped form; `$if` puts into the branch it took;
list and dict literals put element-wise. A form application puts through the form's
body (a program-defined form through the body as written), and edits to `$0 $1 …`
become edits to the call's arguments, merged three-way so separate field edits to one
record combine. A name bound by an earlier statement puts into that statement.

`_inverses` declares isomorphisms: `_inverses={quote=unquote}` makes a call to either
form put through the other, which is how a regex-built layout (`$sub` has no general
inverse) inverts exactly. `$json` puts by parsing the edited text back into a value.

**Model operators** (`=>`, `::`, `..`, `!`, …) get a model-backed put in llm mode
(`nlir put --mode llm`): a request on the `large` tier asks for minimal find/replace
patches to the operator's inputs that would turn its output into the edited output
(preferring the subject matter over the operation's directions). The patches apply
exactly and each changed input puts further back with the exact rules — so a patch to
an instruction built with `++` lands in the data it was built from, e.g. a field of a
packet rendered with `$json`. An operator may carry an authored backward instruction
(`put:` in its config), folded into the request. The request is an ordinary
content-addressed realisation, so it replays from the store. In llm mode PutGet is
judged: `put_get_similarity` is `≈` between the edited output and the re-run; and
`tensions` lists input changes that contradict each other — across fields, or within
one edited text (edits can merge textually — text edits to one value merge three-way
when their regions do not overlap — and still contradict each other).

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
  **concurrently**, bounded by `--parallelism` (default `8`). Fan-out points: an
  operator's operands, the items of a list literal (`[!a, !b, !c]`), the values of a
  dict literal, and `$map`/`↦` over a list — each item is bound into the form body
  (`$0` → the item) and the bound bodies run side by side when parallel-safe. A body
  that writes context, reads the stack or applies a named form runs item by item.
- **Safety:** greedy interpolation + context writes make blind parallelism unsafe.
  Any subtree that **writes context** (`=`) is serialised against readers; when in
  doubt the scheduler forces serial.
- **`` ` `` prefix** forces serial evaluation of the whole of its RHS for ordering
  automatic detection can't infer — but the marked subtree stays parallel with its
  siblings. In `` a+`(a+b) `` the outer operands `a` and `` `(a+b) `` run in
  parallel, while `a` then `b` inside the backtick run serially.
- **Caching (content-addressed realisations):** every realisation is keyed by a
  SHA-256 of the operator's full definition (its config, the resolved model backend,
  the prompt fragments), the typed operands, grouping, separator and `_seed`. Model
  and command calls are nlir's only effects, so a hit returns exactly what the call
  produced: identical calls are free and replays are deterministic. Scopes: one
  evaluation (default); a host-held cache across runs (below); or a **store file**
  (`--cache-file PATH`, `NLIR_CACHE_FILE`, or `_cache_file` with `_cache=persist`)
  of JSON lines shared across runs, evals and hill-climb rounds — it only grows,
  records effectful realisations only, and never evicts. The first record of a key wins: writers
  sharing a store take a file lock, adopt a value another process recorded for the same call
  meanwhile instead of appending their own, and loads keep the first of any duplicates, so
  concurrent identical calls converge and replays agree. `--replay strict` turns an
  unrecorded model/command call into an error, and `--cache-stats` prints
  `nlir cache-stats {"replayed":N,"fresh":M}` to stderr after evaluation (effectful
  calls only; shown with `--quiet` and on errors). `_cache=off` disables caching (the
  old, nondeterministic behaviour). Editing an operator's prompt or model changes
  its keys, so a store never replays a stale definition.
- **Explicit randomness:** `$draw%(form, n)` evaluates `form` `n` times (0–64) under
  seeds `_seed, _seed+1, …` (from 0 when unset), passing the draw index as `$0`, and
  restores `_seed` afterwards. Fresh samples are always an explicit request. `$medoid%(list)` picks the
  item whose words agree most with the others' (mean word-sequence similarity: longest
  common subsequence over the longer length; ties to the earliest), so
  `$medoid%($draw%({=>prompt}, 8))` is consensus selection over eight samples.
- **Shadowing builtins:** a statement may bind a builtin's name (`trim = {…}`); the binding then
  replaces the builtin everywhere, including in library forms, so the CLI warns on stderr for
  each such name before evaluating. A normal
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

The **canonical operator vocabulary** — each realised via `template` / `det` /
`reduce` / `builtin` / `command` (deterministic) or `prompt` (llm). These
descriptions are the authoritative semantics, mirrored by `nlir help`.

Glyphs are reserved for **generic transforms**: operations recognisable from
category theory and functional programming, polymorphic over the values they act on.
Task-specific rewrites (formal, plain, question, gist, …) are not glyphs; they are
**prelude** forms built from the core (§Prelude), readable and overridable.

**Semantic core** (model-realised; each has a deterministic stub for `--mode det`).
Values are texts read as concepts.

| op | name | fixity · arity | what it does |
|---|---|---|---|
| `=>` | respond | prefix · 1 | Obey: treat the operand as an INSTRUCTION and return only the result of following it (length/format constraints included). Generative rather than transformative; carries the `generative` system frame, so it obeys on any tier. A bare `=>` on a pipe obeys the piped text. |
| `::` | recast | infix · 2 | `x :: kind` re-expresses x as the kind of text named on the right — a register, form, genre, format or length (`'formal'`, `'a question'`, `'plain language'`, `'a haiku'`, `'JSON'`) — keeping its meaning. Saturates: `x::k::k ≈ x::k`. |
| `..` | project | infix · 2 | `x .. aspect` returns the part of x the right operand describes — an aspect (`'its subject'`, `'the gist'`, `'the risks'`) or a position (`3`, `'the last item'`). The semantic twin of `.`; two integers give the deterministic range `a..b`. |
| `!` | dual | prefix · 1 | The opposite: a claim negated clause-wise (`!(a&b)` = neither), a concept-word's antonym. An involution: `!!x ≈ x`. |
| `&` | and | mixfix · >0 | Product: joins operands into one "X and Y" statement (not boolean ∧); nullary `&` folds the premise stack. |
| `\|` | or | mixfix · >0 | Coproduct: joins operands into one "X or Y" choice, kept as genuine alternatives. |
| `Δ` | change | infix · 2 | How the first text becomes the second — added, removed, shifted. Directional (`aΔb ≠ bΔa`). |
| `▷` | apply | infix · 2 | `x ▷ change` returns x changed as described, and nothing else. The partner of `Δ`: `a ▷ (a Δ b) ≈ b`. |
| `~>` | entails | infix · 2 | Bool: does the first text imply the second? The preorder on meanings. det = substring containment. |
| `≈` | similarity | infix · 2 | Number in [0,1]: how fully the second text keeps the *meaning* of the first (reference). det = word-set Jaccard; llm = judged equivalence of claims, conditions and criteria (`$gen ≈ $gold >= 0.8`). |

**Structural core** (deterministic, polymorphic — the typeclass-shaped layer):

| op | name | fixity · arity | what it does |
|---|---|---|---|
| `.` | access | infix · 2 | Lens get: `[a,b,c].1`→`b` (0-based, negative from end), `{k=v}.k`→`v`, `"the".2`→`e`. Missing → loud error. Binds above `%`. |
| `++` | concat | mixfix · >0 | Monoid append: text concatenates, lists concatenate, dicts merge right-biased (`{a=1}++{a=2,b=3}` → `{a=2,b=3}`). A lone list operand mconcats its items (`++[a,b,c]` → `abc`). |
| `_` | mtimes | infix · 2 | Monoid power: `x _ n` = n copies appended — `'ab'_3` → `ababab`, a list repeats its items, and a `{form}` composes with itself n times (`{$0+1}_3 % 5` → 8). |
| `∘` | compose | mixfix · >0 | Composition: `(f ∘ g) % x` = `f % (g % x)`; variadic, right to left. Builds pipelines from named forms: `($gist ∘ $formal) % notes`. |
| `#` | length | prefix · 1 | Foldable length: list items, dict keys, text characters. Alias for `$len`. |
| `//` | split | infix · 2 | Split text by a separator into a list: `"a,b,c"//","` → `[a,b,c]`. |
| `<$>` | mapascii | infix · 2 | Functor map: apply the left form to each item of the right list: `{$0*$0}<$>[1,2,3]` → `[1,4,9]`. Alias for `$map%`. |
| `↦` | mapop | infix · 2 | Visual map alias with the same `builtin: map` semantics as `<$>`. |
| `⊘` | foldop | infix · 2 | Fold the right list with the left binary form: `{$0+$1}⊘[1,2,3,4]` → `10`. Alias for `$fold%`. |
| `∪` | setunion | infix · 2 | Set union — order-preserving, deduped; dict operands → their keys. Alias for `$union%`. |
| `∩` | setinter | infix · 2 | Set intersection — items of `a` also in `b`. Alias for `$inter%`; binds tighter than `∪`/`∖`. |
| `∖` | setdiff | infix · 2 | Set difference — items of `a` not in `b`. Alias for `$diff%` (U+2216). |
| `∈` | setelem | infix · 2 | Membership → Bool: list element, dict key, or substring. Alias for `$elem%`. |

**Numeric operators** (`operands: number`, `result: number`, `reduce:`):

| op | name | fixity · arity | what it does |
|---|---|---|---|
| `+` | add | mixfix · >0 | Sum of the operands (words / units / bases coerce to numbers first). |
| `*` | mul | mixfix · >0 | Product of the operands. |
| `-` | sub | infix · 2 | Difference, a − b (left-associative). |
| `/` | div | infix · 2 | Quotient, a ÷ b (guards divide-by-zero). |
| `**` | pow | infix · 2 | a to the power b — right-associative (`2**3**2` = 512). |
| `√` | sqrtop | prefix · 1 | Non-negative square root. |

**Comparison and boolean operators** (`result: bool`, deterministic):

| op | name | fixity · arity | what it does |
|---|---|---|---|
| `==` | equals | infix · 2 | Equal by rendered value: `5==5` → true. |
| `!=` | not-equals | infix · 2 | The operands differ. |
| `<` | less | infix · 2 | Numeric less-than: `3<5` → true. |
| `>` | greater | infix · 2 | Numeric greater-than. |
| `<=` | at-most | infix · 2 | Numeric ≤. |
| `>=` | at-least | infix · 2 | Numeric ≥. |
| `∧` | booland | infix · 2 | Logical AND (truthiness) — distinct from the semantic product `&`. |
| `∨` | boolor | infix · 2 | Logical OR — distinct from the semantic coproduct `\|`. |
| `¬` | boolnot | prefix · 1 | Logical NOT; negates any Bool, including a fuzzy `~>` result. The boolean twin of `!`. |

### Prelude

Config `prelude:` is nlir source evaluated into every run before the program: `name={…}`
named forms (and literals), `--` comment lines. Bindings are transient (never written
to the context file), and a context binding of the same name wins, so a project can
redefine or extend the vocabulary. The shipped prelude:

| form | definition |
|---|---|
| `$gist` | `{$0 .. 'its gist, in one short sentence'}` |
| `$subject` | `{$0 .. 'its primary subject, as a short noun phrase'}` |
| `$formal` / `$casual` | `{$0 :: 'a formal, professional register'}` / `… 'a casual, conversational register'` |
| `$plain` | `{$0 :: 'plain language a child could follow'}` |
| `$question` | `{$0 :: 'a question with the same subject and meaning'}` |
| `$expand` / `$shorten` | `{$0 :: 'a fuller version …'}` / `{$0 :: 'the fewest words that keep every fact and figure'}` |
| `$implies` | `{=>('State, in one sentence, what follows from: ' ++ $0)}` |

Prelude forms compose like any form: `($gist ∘ $formal) % notes`,
`$formal ↦ [a, b]`, `$draw%({$question%$q}, 3)`.

The algebraic laws (`!!x ≈ x`, `x::k::k ≈ x::k`, `a ▷ (a Δ b) ≈ b`) are
**realised-semantics**: they hold in llm realisation — the user-facing output —
while det mode applies the literal stubs (`!!a` → "not not a").

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
`+ -` — then string `& |`; `=` is loosest. Concretely: `^` 20 · `.` 19 · `%` 18 ·
`∘ _` 17 · `..` 16 · `::` 15 · `# ! ¬ √` 14 · `** //` 13 · `* /` 12 · `+ -` 11 · `++` 10 ·
`& | Δ ▷` 9 · `<$> ↦ ⊘` 8 · `∩` 7 · `∪ ∖` 6 · `∈ == != < > <= >= ≈` 5 · `∧` 4 · `∨` 3 · `=` 0
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
| `$subject%^-1` | "a rust-rewrite" |
| `!($subject%^-1)` | "not a rust-rewrite" |
| `^-1 :: 'one line'` | the last message, recast as one line |
| `#(0^*-1 // "\n")` | how many lines the whole thread spans |
| `&[a,b,c]` | "a, b, and c" |
| `!(a&b)` | "not (a and b)" — parens preserved |
| `'one two'` | "one two" |
| `"the subject is $k"` | interpolates `$k` at eval time |
| `_sep=\ ;[a,b]` | "a b" |
| `` `k=$subject%^-1;$k `` | serial: store the subject as `k`, then read it |

---

## CLI surface

```
nlir -e 'EXPR' [--quiet] [--mode det|llm] [--model haiku | --model medium=haiku,large=opus] [--parallelism 8] [--dry-run]
nlir -f lib.nlir [-f prog.nlir] [-e 'EXPR']   # program files (`--` comment lines)
nlir … --bind NAME=PATH           # JSON/YAML → native dict/list `$NAME`; other files → string (transient)
nlir … --cache-file PATH [--replay strict] [--cache-stats]   # realisation store (§Execution graph: Caching)

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

# graphs: the expression DAG, or one node per top-level statement
nlir show 'EXPR' [--png F | --out F | --kitty | --frames | --save-animation F | --animate]
nlir show --statements [-f FILE…] ['EXPR'] [--png F | --out F | --text | --json | --tikz]
nlir show --tikz [-f FILE…] ['EXPR']   # each statement's expression tree as a LaTeX forest tree

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

The shipped [`config.example.yaml`](config.example.yaml) is the reference config: the
v2 operator set (§Config operators), the prelude, models, prompts, types, sessions and
the `tests:` suite `nlir test` runs. nlir writes it to `~/.config/nlir/config.yaml` on
first run; `include_str!` embeds the same file in the binary and the browser build,
so the CLI, the docs and the workspace never drift apart.

## Implementation / project shape

Rust, Nix-flake-managed, on the harryaskham CLI template stack (mature examples
under `~/.cacophony/daemon/checkouts/…`): **mcp-cli** (`nlir mcp stdio` — the whole
surface is agent-callable), **updatable-cli** (`nlir self-update`), **feedback-cli**
(`nlir feedback`). Behaviour above is the spec; this is the scaffolding pattern.
```
