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
