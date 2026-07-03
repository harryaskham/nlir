# nlir — library of working cases

A curated library of nlir invocations that work end-to-end, used both as
documentation and as a dogfooding checklist. It pairs with the deterministic
`tests:` block in [`../config.example.yaml`](../config.example.yaml) (run them
with `nlir test`) and the `SPEC.md` contract.

Setup: these assume the shipped `config.example.yaml` (scaffolded to
`~/.config/nlir/config.yaml` on first run), which wires the `claude` and pi
(`copilot`) command backends. Deterministic (`det`) cases need no API key or
network; LLM (`llm`) cases call the configured models, so their outputs are
illustrative (model-dependent), not exact.

## Deterministic cases (offline, exact)

These are exact and reproducible — they are the `nlir test` regression suite.

| Expression | Result | Notes |
|---|---|---|
| `nlir --mode det -e '1+2+3'` | `6` | numeric reduce (`+`) |
| `nlir --mode det -e '2*3*4'` | `24` | numeric reduce (`*`) |
| `nlir --mode det -e '10-4'` | `6` | numeric reduce (`-`) |
| `nlir --mode det -e '12/3'` | `4` | numeric reduce (`/`) |
| `nlir --mode det -e '(1+1)**3'` | `8` | grouping + power |
| `nlir --mode det -e '!foo'` | `not foo` | template realisation |
| `nlir --mode det -e 'a&b&c'` | `a and b and c` | join realisation |
| `nlir --mode det -e 'a\|b'` | `a or b` | join realisation |
| `nlir --mode det -e '!(a&b)'` | `not (a and b)` | grouping preserved |
| `nlir --mode det -e 'xxx_2'` | `xxx xxx` | command operator (`_`) with `${NLIR_ARGS[k]}` |
| `nlir --mode det -e "'one two'"` | `one two` | quoted multi-word literal |
| `nlir --mode det -e 'k=foo;$k'` | `foo` | assignment + `$name` read |
| `nlir --mode det -e '_sep=\ ;[a,b]'` | `a b` | `_sep` + list render |
| `nlir --mode det -e '1+2*3'` | `7` | precedence ladder (`*` binds before `+`) |
| `nlir --mode det -e '(1+2)*(3+4)'` | `21` | grouping + precedence |
| `nlir --mode det -e '2**10'` | `1024` | power |
| `nlir --mode det -e '1+2;3+4'` | `7` | program result = final statement |
| `nlir --mode det -e 'x=5;y=10;$x+$y'` | `15` | multi-statement, two reads |
| `nlir --mode det -e '1/0'` | *(error)* `division by zero` | loud arithmetic error |

## Lists & spread

A `[a,b,c]` list **spreads** into a variadic operator, and stringifies by
joining its elements with `_sep`.

| Expression | Result | Notes |
|---|---|---|
| `&[1,2,3]` | `1 and 2 and 3` | list spreads into variadic `&` |
| `+[1,2,3,4]` | `10` | list spreads into variadic `+` |
| `[1,2]+3` | `6` | spread ≡ `1+2+3` (NOT a list→number coercion) |
| `[2,3]*4` | `24` | spread ≡ `2*3*4` |
| `1-[2,3]` | *(error)* `a list is never a number` | arity-2 `-` does not spread |
| `'a';'b';&` | `a and b` | nullary `&` pops the statement stack |
| `[a,b,c]` (fresh ctx) | `a`⏎`b`⏎`c` | bare list joins with `_sep` (default `\n`) |
| `_sep=', ';[a,b,c]` | `a, b, c` | explicit `_sep` overrides the default |

Interpolation and messages (with a context):

```sh
nlir --mode det -e 'k=world;"hello $k"'      # -> hello world   (double-quote interpolates)
nlir --mode det -e "'k=world;'\''hello $k'\''"  # -> hello $k   (single-quote is literal)
# with _messages [{user,"hi"},{assistant,"in rust"}]:
nlir --mode det -e '^-1'                      # -> in rust      (last assistant message)
```

## LLM operator cases (illustrative)

Run with `--mode llm` (or `defaults.mode: llm`). Outputs shown are real samples
from claude-sonnet-5 / copilot; exact wording varies by model.

| Expression | Sample output |
|---|---|
| `#'the quick brown fox jumps over the lazy dog'` | `fox` (subject) |
| `~'The mitochondria is the powerhouse of the cell, generating ATP through cellular respiration.'` | `Mitochondria generate ATP through cellular respiration, powering the cell.` (summary) |
| `!'the sky is blue'` | `the sky is not blue` (semantic negation) |
| `'apples'&'oranges'&'bananas'` | `apples, oranges, and bananas` (and-join) |
| `'tea'\|'coffee'` | `tea or coffee` (or-join) |
| `'you enjoy hiking on weekends'?` | `Do you enjoy hiking on weekends?` (question, postfix) |
| `@'hey can u send me that thing asap'` | `Could you please send me that item at your earliest convenience?` (formalize) |
| `:'Quantum entanglement is a physical phenomenon ...'` | plain-language rewrite (simplify) |

## Compositions

Operators nest and chain; independent LLM subtrees run concurrently.

| Expression | Sample output | Notes |
|---|---|---|
| `~#'The annual shareholder meeting discussed quarterly earnings and strategic growth initiatives.'` | `Annual shareholder meeting.` | nested: summary of subject |
| `#'a treatise on functional programming'&#'a guide to systems engineering'` | `functional programming and systems engineering` | two subjects joined (concurrent LLM subcalls) |

## LLM coercion

When an operand is not already the required type, deterministic parsing is tried
first, then (in `llm` mode) the per-type LLM coercion from the `types:` map.

| Expression | Result | Notes |
|---|---|---|
| `2+'three'` | `5` | `'three'` → 3 via the `number` coercion, then reduce |
| `'ten'*'two'` | `20` | both operands LLM-coerced to numbers |

## Model backends

In `llm` mode, `model`/`prompt` operators realise via the configured `models:`.
Three transports are all verified end-to-end; the concurrent DAG scheduler
parallelises independent subtrees across every backend:

- **command** — `sonnet` (`claude` → claude-sonnet-5), `copilot`
  (`pi` → github-copilot/claude-sonnet-4.6).
- **HTTP** — `direct` (`anthropic_messages` → a LiteLLM proxy at `:4000/v1`,
  `x-api-key` auth). See the `direct:` block's comment in `config.example.yaml`
  for the URL/port and the `LITELLM_MASTER_KEY` env caveat.

Point an operator at a specific model via its `model:` field; an unset `model:`
falls back to `defaults.model`.

## Gotchas

- **Bare literals are single words.** `#the quick brown fox` is a parse error
  (`the`, `quick`, … are separate tokens). Quote multi-word operands:
  `#'the quick brown fox'`.
- **Operator position follows fixity.** `?` is postfix, so use
  `'...'?`, not `?'...'`. Prefix operators (`#`, `!`, `~`, `@`, `:`) lead;
  mixfix/infix (`&`, `|`, `+`, `-`, `*`, `/`) sit between operands.
- **`det` vs `llm`.** `command`/`reduce` realisations and coercion math are
  deterministic in both modes; `template`/`join` realise deterministically in
  `det` mode, while `model`/`prompt` realise via the LLM in `llm` mode.
- **Unresolved `$name`.** In a double-quoted string an undefined `$name` is left
  literal (forgiving templating); a bare `$name` read of an undefined name is a
  loud error (a value must resolve). This asymmetry is intentional.
- **The context file persists.** Assignments and `_sep=`/`_cache=` write through
  to the active context file (`context.file_default`), so they persist across
  runs and can silently pollute later invocations. Use `--context-file <temp>`
  for clean, reproducible runs.
