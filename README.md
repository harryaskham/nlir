# nlir — natural-language IR

`nlir` transpiles a terse, sigil-laden **shorthand** into fluent **English**. The
shorthand is an intermediate representation: it is *tokenised*, *parsed* into a
DAG using a config-defined grammar, and *evaluated* over a small **stack machine**
with a **tiny type system**, where each operator is realised either
**deterministically** (mechanical string/number expansion) or via an **LLM** call
(a structured text transformation).

Typically invoked from a coding agent's prompt window:

```sh
nlir -e '#^-1'        # "the subject of the last assistant message"
```

The engine ships only a tiny set of **builtins** (stack / context / indexing /
assignment / arithmetic / coercion / list plumbing). Everything else — the
operator vocabulary, their fixity / priority / arity / types, the models, the
prompts, the coercions, the tests — lives in `~/.config/nlir/config.yaml`. **The
binary is a small VM; the language is config.**

See [`SPEC.md`](./SPEC.md) for the full normative contract; this README is the
usage-oriented tour.

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

On macOS, the flake dev shell provides `libiconv`:

```sh
nix develop --command cargo build --release
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
nlir -e '#^-1'                  # extract the subject of the last assistant message
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

Every value is one of `string` (default), `number`, `bool`, or `list`. Before an
operator runs, each operand is coerced to the required type:

1. already that type → used as-is;
2. **deterministic** parse — `"1"` ↔ `1`, `number`/`bool`/`list` → `string`
   (lists join with `_sep`), `"true"` → `bool`;
3. else an **LLM coercion** — "interpret this text as a value of type T" with a
   `{result: T}` schema, configured per type under `types:`. This turns a vague
   `"ten to twenty"` into `15`.

A coercion that cannot produce the target type is a loud error; `list → number`
is always an error.

## CLI surface

```sh
nlir -e 'EXPR' [--quiet] [--mode det|llm] [--model haiku] [--parallelism N] [--dry-run]

# context read (precedence: --context-file › --session-file › NLIR_CONTEXT env › default file)
nlir … --context-file PATH
nlir … --session-file PATH        # e.g. a Pi session: roles kept, tool calls dropped

# context write (immediate; set = key replacement)
nlir set KEY VALUE
nlir set '{"k":"v","_messages":[…]}'
nlir get KEY
nlir append-message [--role user] "text"

# interactive REPL (one expr per submission; trailing `\` continues; :cmd == nlir cmd)
nlir repl [--context-file F] [--raw]

# plumbing
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

## Development

```sh
cargo test --all                      # unit + integration tests
cargo clippy --all-targets -- -D warnings
cargo fmt --all --check
```

CI (`.github/workflows/ci.yml`) runs fmt, clippy (deny-warnings), build, and test
on every push/PR; a `v*` tag triggers `.github/workflows/release.yml` to build and
publish per-target binaries. Both use the system Rust toolchain.
