# nlir — natural-language IR

`nlir` is a small language for programs over **data and meaning**. Exact structure —
lists, dicts, folds, regexes, arithmetic — and model-realised semantics — recast,
project, change, entailment, similarity — share one expression language, evaluated
by a stack machine whose whole vocabulary lives in config.

```sh
nlir -e "'lmk if any Qs' :: formal"                                  # Please let me know if you have any questions.
nlir -e "'the planets from the sun' .. 3"                             # Earth
nlir -e "{\$0+\$1} ⊘ ['3 apples','5 oranges','2 pears']"               # 10 — the model reads, + adds
nlir -e "a='Ship on Friday.'; b='Ship on Friday, after the security review.'; \$a ▷ (\$a Δ \$b)"
                                                                      # Ship on Friday after the security review.
nlir --mode det -e "inc={\$0+1}; dbl={\$0*2}; (\$dbl ∘ \$inc) ↦ [1,2,3]"  # 4 6 8
```

The engine ships a tiny set of builtins (stack, context, indexing, assignment,
arithmetic, coercion, list and data plumbing). Everything else — operators, their
fixity / priority / arity / types, the prelude, models, prompts, coercions and tests —
lives in `~/.config/nlir/config.yaml`. **The binary is a small VM; the language is
config.** See [`SPEC.md`](./SPEC.md) for the normative contract and
[`docs/design/v2.md`](docs/design/v2.md) for where the language is heading.

## The core

Glyphs are reserved for **generic transforms** — operations you would recognise from
category theory or functional programming, polymorphic over what they act on.

**Semantic core** (model-realised; deterministic stubs in `--mode det`):

| op | name | meaning |
|---|---|---|
| `=>x` | obey | treat `x` as an instruction; return only the result |
| `x :: kind` | recast | `x` re-expressed as a kind of text — `formal`, `'a question'`, `'one sentence'`, `JSON` |
| `x .. aspect` | project | the part of `x` an aspect describes — `'its gist'`, `'the risks'`, `3`, `'the last item'` |
| `!x` | dual | the opposite; `!!x ≈ x` |
| `a & b` / `a \| b` | product / coproduct | both / either, as one statement |
| `a Δ b` | change | how `a` becomes `b` |
| `a ▷ d` | apply | `a` changed as `d` describes; `a ▷ (a Δ b) ≈ b` |
| `a ~> b` | entails | Bool: does `a` imply `b` |
| `a ≈ b` | similarity | Number in [0,1]: how fully `b` keeps the meaning of `a` |

**Structural core** (deterministic, polymorphic):

| op | class | meaning |
|---|---|---|
| `f ↦ xs` / `f <$> xs` | Functor | map a form over a list |
| `f ⊘ xs` | Foldable | fold a list with a binary form |
| `f ∘ g` | composition | `(f ∘ g)%x = f%(g%x)` |
| `a ++ b` | Monoid | append text, lists, or dicts (right-biased merge); `++[a,b,c]` mconcats |
| `x _ n` | Monoid power | `n` copies appended; a form composes with itself `n` times |
| `x . k` | lens get | index, key, or character |
| `#x` | length | items, keys, or characters |
| `∪ ∩ ∖ ∈` | lattice | set operations, membership |

Plus arithmetic (`+ - * / ** √`), comparisons (`== != < > <= >=`), booleans
(`∧ ∨ ¬`) and the `$…` builtins (`$map $fold $scan $filter $if $sort $keys $get
$join $match $sub $draw …`).

**The prelude** — the everyday vocabulary as named forms over the core, loaded into
every run and redefinable per project:

```
gist={$0 .. 'its gist, in one short sentence'};   formal={$0 :: 'a formal, professional register'};
subject={$0 .. 'its primary subject, …'};         plain={$0 :: 'plain language a child could follow'};
question={$0 :: 'a question with …'};             casual / expand / shorten / implies
```

So `($gist ∘ $formal)%notes`, `$plain ↦ items` and `$draw%({$question%$q}, 3)` are
ordinary programs, not special syntax.

## Mental model

```
EXPR ──tokenise──▶ tokens ──parse──▶ DAG ──schedule/eval──▶ English
                             (grammar from config)   (stack machine; types + coercion; per-op det|llm; parallel)
```

- An expression is a sequence of **statements** separated by `;`.
- Evaluating a statement yields a **typed value** and pushes it onto the stack.
- **Operators** combine values; each declares the **types** it needs, and operands
  are **coerced** to those types first (deterministically, or via an LLM coercion).
- Given no operands, an operator **pops from the stack**.
- The parse is a **DAG**: independent subtrees can run concurrently.
- The **program result** is the final statement's value → stdout.

## Install / build

nlir is a Rust CLI built on the harryaskham CLI stack (`mcp-cli`,
`updatable-cli`, `feedback-cli`). On Linux, build with the **system Rust
toolchain** (no nix dev shell required — glibc provides iconv):

```sh
cargo build --release        # binary at target/release/nlir
```

On macOS, either use the flake dev shell, or rustup with Apple's linker (a nix-profile
`cc`/`ld` on PATH links binaries whose panics cannot unwind):

```sh
nix develop --command cargo build --release
CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER=/usr/bin/cc cargo build --release
```

The ecosystem crate dependencies are public and fetched over https, so no tokens
or SSH keys are needed to build.

## Quick start

On first run, nlir writes a starter config to `~/.config/nlir/config.yaml`
(the shipped [`config.example.yaml`](./config.example.yaml)) if none exists, then
evaluates your expression:

```sh
# Deterministic mode needs no API key — the numeric / template / join / command
# operators run locally:
nlir --mode det -e '1+2+3'      # "6"
nlir --mode det -e 'a&b&c'      # "a and b and c"   (via the `and` operator's join)
nlir --mode det -e '!(a&b)'     # "not (a and b)"   (parens preserved)

# LLM mode calls the configured models (set ANTHROPIC_API_KEY for the `haiku`
# model in the example config):
nlir -e '$subject%^-1'          # the subject of the last assistant message
nlir -e "^-1 :: 'one line'"     # the last assistant message, recast as one line
```

## The config *is* the language

`~/.config/nlir/config.yaml` defines everything. The shipped example config has
these sections (see [`config.example.yaml`](./config.example.yaml) for the full,
validated file):

| Section | What it defines |
|---|---|
| `defaults` | default `mode` (`det`/`llm`), `model`, `parallelism` |
| `models` | named model backends — `anthropic_messages` (direct HTTP) or `command` (subprocess) |
| `prompts` | reusable prompt fragments exposed as `${NLIR_*}` env vars |
| `prelude` | named forms over the core (`$gist`, `$formal`, …), loaded into every run |
| `operators` | the operator vocabulary: `op` sigil, `arity`, `fixity`, `priority`, operand/result `types`, and a realisation (`template` / `join` / `command` / `reduce` for `det`, or `model` + `prompt` for `llm`) |
| `types` | coercion targets — how to interpret text as `number` / `bool` / … (deterministic parse first, LLM fallback) |
| `context` | the `context.json` store, `_messages` role views (`^`), and system-key defaults (`_sep`, `_cache`) |
| `sessions` | how to read external session files (e.g. a Pi session) as context |
| `tests` | `nlir test` cases: `{ mode, expr, expected }` |

A minimal operator, for example:

```yaml
operators:
  and: { op: "&", arity: ">0", fixity: mixfix, join: " and ", model: sonnet,
         prompt: "Combine the <text> items with an \"and\" connective ...\n\n%" }
  add: { op: "+", arity: ">0", fixity: mixfix, operands: number, result: number, reduce: add }
```

`&` joins its operands with `" and "` in `det` mode, or asks the `sonnet` model to
combine them in `llm` mode. `+` is always deterministic (`reduce: add`).

## Modes

- **`det`** (no network): realise via `command:` / `reduce:` / `template:` /
  `join:` only.
- **`llm`**: string transformations go to `model:` + `prompt:`; `command` / `reduce`
  and coercion math stay deterministic regardless of mode.

Default from `defaults.mode`; override per run with `--mode det|llm`.

## Types & coercion

Every value is one of `string` (default), `number`, `bool`, `list`, `dict`, or
`form`; an operator may also declare `operands: any` to receive values uncoerced. Before an
operator runs, each operand is coerced to the required type:

1. already that type → used as-is;
2. **deterministic** parse — `"1"` ↔ `1`, `number`/`bool`/`list` → `string`
   (lists join with `_sep`), `"true"` → `bool`;
3. else an **LLM coercion** — "interpret this text as a value of type T" with a
   `{result: T}` schema, configured per type under `types:`. This turns a vague
   `"ten to twenty"` into `15`.

A coercion that cannot produce the target type is a loud error; `list → number`
is always an error.

## Forms & application — the programmable core

A `{…}` **form** is a quoted expression: `{2+3}` yields the expression *as data*
(`{(2 + 3)}`), not its value — quoting is **inert**. Forms are first-class
values: bind one to a name, pass it around, and **apply** it with `%`, binding
arguments positionally to the holes `$0`, `$1`, …:

```sh
nlir -e '{2+3}'               # → {(2 + 3)}   (a form — code as data, not run)
nlir -e '{$0+1}%5'            # → 6           (apply a form to an argument)
nlir -e '{$0+$1}%(2,3)'       # → 5           (tuple args; %(2,3) ≡ %[2,3])
nlir -e 'sq={$0*$0};$sq%5'    # → 25          (a named lambda: bind, then apply)
nlir -e '({$0+1}_3)%5'        # → 8           (do-N-times: compose a form N times)
```

The argument frame is **hygienic** — a form's `$0` is its argument, not whatever
is on the run stack (`9;{$0}%7` → `7`). Application binds tighter than `,` (pass a
tuple with `%(a,b)`) and tighter than `_` (parenthesise the compose: `({form}_N)%x`).
Do-N is bounded to 64 applications: larger runtime-built compositions fail cleanly
before allocating a deep AST, and an independent evaluator-depth guard protects every
recursive path. A **macro** is just a form whose body is a transform, applied to text,
so the same
quote+apply machinery gives you reusable moves. Together — quoted forms,
application, named lambdas/macros, and do-N-times — these are the programmable
layer map/fold over forms builds on.

**Build something with them:** the [cookbook](docs/cookbook.md) is a worked
catalogue of multi-layer programs — named functions, composition, nesting, and
do-N chains — every deterministic output verified end-to-end.

## Data trees — specs, configs and datasets as native values

Load a JSON or YAML file as a native value and navigate it with the same operators:
objects are dicts, arrays are lists, all the way down. Program files (`-f`) hold
libraries of named forms; `--` lines are comments.

```sh
cd site/spec-lab
nlir --bind spec=toy-spec.json -e '$len%($keys%$spec.nodes)'                      # → 10
nlir --bind spec=toy-spec.json -f spec.nlir -f profile.nlir -e '$packet%"CR V 2.2"'   # one rule, resolved
nlir --mode det -e 'orders=[{who=ada, total=12.5},{who=bo, total=40}];
                    $join%({$0.who}↦($filter%({$0.total>=10}, $orders)), ", ")'   # → ada, bo
```

`$keys` `$get` `$join` `$flat` `$zip` `$json` `$match` `$sub` and friends do the exact
structural work; `=>`, `::`, `..`, `≈` and the other model operators do the semantic work; a
nested form reads its enclosing form's arguments as `$$0`. The
[spec lab](https://a.skh.am/nlir/spec-lab/) runs this in the browser: a
spec tree projected into prose and parsed back exactly, with edits to the prose
turned into the spec changes they imply.

## Determinism — a content-addressed record of every call

Model and command calls are nlir's only effects. Each realisation is keyed by the
operator's full definition (prompt, frame, resolved model), its operands and `_seed`,
so a recorded call replays exactly and identical calls cost nothing:

```sh
nlir --cache-file runs/store.jsonl -e "=>'Name a lighthouse keeper''s cat'"   # 3.9 s, recorded
nlir --cache-file runs/store.jsonl -e "=>'Name a lighthouse keeper''s cat'"   # 0.03 s, replayed
nlir --cache-file runs/store.jsonl --replay strict -f program.nlir            # fail on any unrecorded call
nlir -e "\$draw%({=>'Name a cat'}, 3)"                                         # three explicit samples
```

The store is JSON lines that only grow, shared across runs, evaluations and
hill-climb rounds; `_seed` is the namespace (a new seed draws fresh samples) and
`$draw%(form, n)` asks for `n` samples explicitly. `_cache=off` restores the old,
nondeterministic behaviour. Hosted models do not honour seeds reproducibly, so each
model declares `seed: exact | best-effort | none` and the store does the work.

## The composable core — adverbs, trains, basics

Forms unlock a small **composable core**: a handful of primitives that compose
into real programs (APL/J-style), rather than a built-in function for every task.

**The adverb family** — higher-order builtins applied with `%`, taking a form and
a list (lists render separator-joined; shown here as `[…]` for clarity):

```sh
nlir -e '$map%({$0*$0},[1,2,3])'                     # [1,4,9]      transform each
nlir -e '$fold%({$0+$1},[1,2,3,4])'                  # → 10         reduce
nlir -e '$scan%({$0+$1},[1,2,3,4])'                  # [1,3,6,10]   running fold
nlir -e '$filter%({$0>=5},[3,7,2,9])'                # [7,9]        keep-if
```

**Basics** — `$if` (branch), `$nth` (index; negatives count from the end),
`$sort`, and comparison `== != <= >=` (deterministic, `→ Bool`):

```sh
nlir -e '$sort%[3,1,2]'                               # [1,2,3]
nlir -e '$nth%(-1,$sort%[3,1,2])'                     # → 3          max, composed from sort+index
nlir -e '$if%(3<=5,"yes","no")'                       # → yes
nlir -e '$fold%({$0+$1},$map%({$0>=5},[3,7,2,9]))'   # → 2          count how many ≥5, no loop
```

**Composition** — `∘` builds pipelines from named forms, and a parenthesised group
of prefix operators is a **train** (atop or fork):

```sh
nlir -e "(\$gist ∘ \$formal)%'hey can u take a look thx'"   # formalise, then distil
nlir -e "(! & =>)%'ship it Friday'"                         # fork: the opposite AND the obeyed
```

Mix in the semantic core and the structural core becomes a language for
**algorithms on meaning**: `$if%('prod is down'~>'an incident','page on-call','all clear')`
routes by a model judgment with deterministic control flow. Because a bare operator
pulls its input from the stack, nlir is **pipeline-native** — `echo "ship it Friday" |
nlir -e '!'` gives the opposite, `| nlir -e "(\$gist ∘ \$plain)%\$_stdin"` the plain gist.

## Learning programs — spec ⇄ prose

nlir programs are small enough to search over. The [spec lab](https://a.skh.am/nlir/spec-lab/)
loads an invented rule spec as native data, projects each rule into prose with an nlir
library, parses the prose back exactly, and replays a hill-climb in which a large model
rewrites the projection program while a fast model runs it and a judge scores the
output with `≈`, while a program judge reviews every version against a meta-policy
(no reference text pasted into the program, no keying on rule ids, no "reproduce the
published answer" pointers) and the selection score prefers the shorter of two equal
programs. On the toy spec the learned program goes from 0.00 to 0.67 held-out
similarity with GPT-6 Luna writing and 0.78 when GPT-6.1 Sol runs the same program;
every version reviews clean at under 2 kB. The design is in
[`docs/design/v2.md`](docs/design/v2.md).

## Editing backwards — lenses

A program maps inputs to output; `nlir put` runs it backwards. Edit the prose a
program produced and it reports which input field — or which literal in the program —
would have to change, and checks the lens laws by re-running:

```sh
cd site/spec-lab
nlir --mode det --bind spec=toy-spec.json -f spec.nlir -f profile.nlir \
     -e '$render%(($node%"CR V 1.1").profile)' > profile.md
$EDITOR profile.md                       # change a sentence of the MET criterion
nlir put --edited profile.md --bind spec=toy-spec.json -f spec.nlir -f profile.nlir \
     '$render%(($node%"CR V 1.1").profile)'
# → data spec nodes/CR V 1.1/profile/decision_boundary/1 … put_get: true
```

Concatenation, joins, field access, maps and form calls each carry a backward pass;
a library declares isomorphisms (`_inverses={quote=unquote}`) for the rest. Editing a
heading instead lands in the program literal that wrote it.

With `--mode llm`, model operators run backwards too: a large model proposes minimal
patches to each `=>` instruction, and the exact rules carry them back to the data the
instruction was built from. On a learned spec→prose program, adding a clause to one
generated MET paragraph comes back as a one-sentence edit to the rule's text; re-running
forward keeps the edit's meaning (≈ 0.95). Two edits that disagree come back as edits
to two fields plus a named **tension** between them. The
[spec lab](https://a.skh.am/nlir/spec-lab/)'s *Backward pass* tab replays that session.

## Seeing programs

**`nlir help`** prints every operator from your config; **`nlir step '<expr>'`** walks
an expression one reduction at a time; **`nlir show '<expr>'`** draws its dataflow
graph — every value and operation a node, bindings resolved into edges — as SVG, PNG,
an animated PNG of the reduction, or live in a kitty terminal. For whole programs,
**`nlir show --statements -f lib.nlir -f program.nlir`** draws one node per statement
instead — forms, data, computed values and the output, linked by the names they read
(including inside form bodies), with model-call sites marked and bound data and
prelude forms as inputs; `--text` prints the same outline for logs and prompts. The
browser [workspace](https://a.skh.am/nlir/workspace/) uses the same renderers (Graph
and Statements, with pan and zoom).

## CLI surface

```sh
nlir -e 'EXPR' [--quiet] [--mode det|llm] [--model haiku] [--parallelism N] [--dry-run]
nlir -f lib.nlir -f program.nlir                 # program files (`--` comments)
nlir --bind spec=spec.json -e '$len%$spec.nodes'  # load JSON/YAML as data, other files as text
nlir --model 'small=luna,large=sol' -e '…'        # remap model tiers (or one name for all)

# realisation store: deterministic replay of model/command calls
nlir --cache-file store.jsonl -e '…'             # record, then replay identical calls
nlir --cache-file store.jsonl --replay strict …  # fail on any unrecorded call

# context read (precedence: --context-file › --session-file › NLIR_CONTEXT env › default file)
nlir … --context-file PATH
nlir … --session-file PATH        # e.g. a Pi session: roles kept, tool calls dropped

# context write (immediate; set = key replacement)
nlir set KEY VALUE
nlir set '{"k":"v","_messages":[…]}'
nlir get KEY
nlir append-message [--role user] "text"

# interactive REPL (one expr per submission; trailing `\` continues; :cmd == nlir cmd)
# on a TTY: command history (persisted to ~/.config/nlir/repl_history.txt), arrow-key
# line editing (Ctrl-A/Ctrl-E, ↑/↓ history), Ctrl-C cancels a line, Ctrl-D exits.
nlir repl [--context-file F] [--raw]

# computational dataflow graph (the AST with variable bindings resolved into edges)
nlir show 'EXPR'                          # print the graph as SVG (in a kitty terminal: the image)
nlir show 'EXPR' --png g.png              # rasterise the graph to a PNG
nlir show 'EXPR' --frames DIR             # one graph SVG per evaluation step
nlir show 'EXPR' --save-animation g.apng  # animated PNG of the step-by-step reduction
nlir show 'EXPR' --kitty                  # force the in-terminal kitty display (e.g. through tmux)
nlir show --statements -f lib.nlir -f prog.nlir --png g.png   # statement-level graph of a program
nlir show --statements --text -f prog.nlir                   # the same outline as text (or --json)
nlir show 'EXPR' --animate --kitty        # live kitty animation of the reduction

# plumbing
nlir put --edited out.md -f prog.nlir --bind d=data.json   # backward pass (lenses): edits + law checks
nlir parse 'EXPR'     # tokenise / inspect the parse
nlir test             # run the config `tests:` cases
nlir mcp stdio        # expose the surface as an MCP server (mcp-cli)
nlir self-update …    # updatable-cli
nlir feedback …       # feedback-cli
```

## Worked examples

These are the deterministic `tests:` from the example config (run with
`nlir test`):

| Expression | Result |
|---|---|
| `1+2+3` | `6` |
| `(1+1)**3` | `8` |
| `a&b&c` | `a and b and c` |
| `!(a&b)` | `not (a and b)` |
| `'one two'` | `one two` |
| `_sep=\ ;[a,b]` | `a b` |
| `k=foo;$k` | `foo` |
| `^-1` (with `_messages`) | the last assistant message |

## Sessions

Expressions can read prior conversation from `_messages`: `^-1` is the last
message (the assistant channel), and `$name` reads a context key. Point nlir at
an existing transcript with `--session-file` (a Pi session's roles are kept and
tool-call turns dropped), or accumulate turns yourself with `append-message`.

`scripts/pi-dropin.sh` is a Pi drop-in filter over a shared context: a line
beginning with `|` is expanded as an nlir expression, and every other turn is
appended to `_messages`, so later `|` expansions can read the conversation.

```sh
printf '%s\n' 'the answer is 42' '|^-1' \
  | NLIR=./target/debug/nlir scripts/pi-dropin.sh --role assistant
# → the answer is 42        (the `|^-1` expression read the appended turn)
```

## Pi package

nlir ships a [pi](https://github.com/earendil-works/pi) package so you can expand
nlir shorthand inline while chatting. Install it into pi:

```json
{ "packages": ["git:github.com/harryaskham/nlir"] }
```

(in `~/.pi/agent/settings.json`) or `pi install git:github.com/harryaskham/nlir`.
It requires the `nlir` binary on your PATH (build/install separately; set `$NLIR`
to override the path).

- **`|EXPR`** — prefix a message with `|` and the rest is expanded as an nlir
  expression before it reaches the model: `|1+2*3` → `7`, `|a&b&c` → `a and b and
  c`, `|'the meeting is at 3' :: formal` → a formal rewrite (llm mode).
- **`/nlir EXPR`** — preview an expansion inline without sending it.

The expression evaluates against your `~/.config/nlir/config.yaml` (det or llm
mode per your defaults). The extension is `extensions/nlir.js`.

## Development

```sh
cargo test --all                      # unit + integration tests
cargo clippy --all-targets -- -D warnings
cargo fmt --all --check
```

CI (`.github/workflows/ci.yml`) runs on the self-hosted nix runners inside
`nix develop`: fmt, clippy (deny-warnings), build, the SPEC↔config check, `nlir test`
over the example config, the offline examples (`structure.sh`, `lens.sh`), and
`cargo test`. Pull requests also build the
site (`.github/workflows/site.yml`); pushes to `main` publish it through the shared
`harryaskham.github.io` Pages workflow (`.github/workflows/pages.yml`), building with
`nix develop .#site --command bash scripts/build-site.sh _site`. Build it locally the
same way. A `v*` tag triggers `.github/workflows/release.yml`.
