# CATALOG-aur2.md — the aur-2 body of work (nlir dual-golf)

A curated, thematic deep-dive index of aur-2's whole corpus: **48 forward** (`golf-aur2-*.sh`)
+ **45 reverse/target** (`target-aur2-NN-*.sh`) examples. This complements — does not
replace — [`README.md`](README.md), which is the shared cross-agent gallery (a small
curated SAMPLE). Run `ls examples/golf-aur2-*.sh examples/target-aur2-*.sh` for the full list.

aur-2's lane: **config / types / llm**. The through-line of this corpus is the
**coercion layer** (nlir's deterministic type-reader that turns human-written numbers and
free text into typed values) and the **`:` / `~>` realisation operators** (turning terse
seeds into fluent English). Where aur-1 mapped the *operator algebra* and msm-0 mapped
*SELECT × TRANSFORM*, aur-2 mapped **what the values themselves can be**.

---

## 1. The coercion reader — number notations (forward)
The coercion layer reads numbers written any way a human would, then does exact arithmetic.
Every notation below is a real, verified example:

- **cardinals / worded** — `calc`, `tip`, `split`, `percent`, `cascade` (det+LLM mix `+['5','five','a handful']`=15)
- **ordinals** — `ordinal` (`'first'+'second'+'third'`=6, rank words → position)
- **quantities & collectives** — `archaic` (score/gross/baker's-dozen), `collective` (pair/trio/half-dozen), `gross` (`'a gross'/'a dozen'`=12, a gross is a dozen dozens)
- **noun-phrase counts** — `grocery` (`'a dozen eggs'+...`=20, reads past the noun)
- **fractions (words)** — `discount`/`winrate` (a fifth=.2, three-quarters=.75)
- **signed words** — `signed` (`'negative three'`=-3, crosses zero)
- **other bases / formats** — `roman` (MMXXIV), `hex`, `polyglot` (hex+bin+word), `scinot` (`1e3`=1000)
- **money & separators** — `money` (`'$19.99'`, `'1,000,000'`)
- **percent literals** — `percentlit` (`'50%'`=0.5)
- **worded ratings** — `ratings` (four stars=4)
- **surface-form INVARIANCE** — `faces` (`'a dozen'-'twelve'+'0xC'-'XII'`=0; four notations of 12 cancel)

## 2. Real formulas (coercion + precedence + the fixed right-assoc pow)
Coercion + operator precedence run genuine formulas over mixed word/digit inputs:

- `thermometer` — Fahrenheit→Celsius `('212'-'thirty two')*'five'/'nine'`=100
- `circle` — area πr² `'3.14'*'ten'**'2'`=314 (`**` binds tighter than `*`)
- `hypotenuse` — Pythagoras `('3'**'2'+'four'**'2')**'0.5'`=5 (`**` does square AND √ via `^0.5`)
- `triangle` — ½·base·height `'0.5'*'twelve'*'five'`=30
- `restaurant` — tip THEN split `('sixty'+'sixty'*'a fifth')/'four'`=18
- `tax` — subtotal + sales tax `('$19.99'+'$5.01')*(1+'8%')`=27 (currency + percent composed)
- `duration` — fortnight arithmetic

> Note: pow is right-associative (`2**3**2`=512) since the fleet fix **bd-df62f1** (aur-0 found,
> aur-2 blessed the `assoc` config field, msm-0 wrote the Pratt change). Some outputs carry f64
> display noise (e.g. compound interest `1157.6250000000002`) — the open **bd-50f84a** full-precision
> display question; showcases here deliberately pick clean-output values.

## 3. Type / coercion LAWS (aur-2's answer to the operator algebra)
- `typeguard` — `list → number` is a HARD ERROR (`1-[2,3]` errors "a list is never a number"), while `[1,2]+3`=6 SPREADS. nlir refuses to guess where a raw LLM would invent.
- `spreadlaw` — `+[xs]` == chained `+` (reduce == repeated application)
- `faces` — coercion is surface-form invariant (§1)

## 4. Corpus text-artifacts (LLM realisation over free text)
- `subject` — `#~'<email>'` → an email subject line (subject of the summary)
- `tweet` — `<~'<paragraph>'` → a tweet (shorten the summary)
- `changelog` — `<@~'ramble'` → a changelog line
- `brief`, `eli5`, `vibe`, `vibesum`, `theme`, `mission`, `discuss`

## 5. Nested logic / synthesis
- `syllogism` — `~&[premises]` DERIVES the conclusion
- `hierarch`, `matrix`, `counter`, `dilemma`, `veto`, `moral`, `rootcause`

---

## 6. The reverse game — aur-2's TARGET lane (`:` simplify, `~>` define)
Reconstruct a realistic pi chat sentence from the shortest nlir seed.

- **`:` on a bare TERM/ACRONYM → compresses hugely + reaches for an ANALOGY.**
  Tightest records: **`:'MVP'` = 6c**, `:'YAGNI'` = 8c, `:'an API'` = 9c (acronym → meaning).
  Analogy engine: `analogy`, `define`, `container` (lunchbox), `deadlock` (kids with toys).
- **`:` on a full JARGON sentence → trades length for CLARITY (register axis).** Domains covered:
  DNS, space/orbit, biology (mitochondria), cricket LBW, chess castling, music theory,
  legal (force majeure, habeas corpus), medical (heart attack), economics (inflation),
  chemistry (catalyst), meteorology (hurricane), psychology (cognitive dissonance),
  computing (deadlock). Some are compression wins (catalyst −32%, habeas −19%); some are
  register-only (~even length, jargon→plain).
- **`:~'dense'` → ELI5 gist** (the plain-language kernel).
- **`~>` (summary-of-expand) → a technical one-line DEFINITION** (for "what is X", not "how to X";
  `~>` overshoots for how-tos). Covered: firewall, encryption, vpn, vaccine, smart contract,
  quantum computing, dependency injection. Use `:~>` for a plainer register.

## 7. Honest rejects (documented, not shipped)
- `&[~&[…],~&[…]]` — double-`&` nesting leaks meta-referential "the text describes…" (lists are flat; msm-0 #43/aur-1 #41).
- `~&['a butterfly','a hurricane']` — items too disparate; `~` just restates instead of synthesising the link.
- `~>'how to stay focused'` — `~>` gives a meta-summary of a how-to, not the advice.

---

*Config/types/llm lane. Cross-refs: the operator algebra (CATALOG-aur1.md), SELECT × TRANSFORM
(CATALOG-msm0.md), the two real bugs found dogfooding (pow right-assoc bd-df62f1 fixed; `\$`-escape bd-65b737 filed).*
