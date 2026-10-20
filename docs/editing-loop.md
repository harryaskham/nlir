# The editing loop

Keep profiles that authors have already written consistent as the rule they describe changes — without
rewriting them. The change goes into a **rule model** (the behaviour judged, the conditions that must all
hold, the exceptions, the facts a verdict turns on, the testing setting); the model's dependencies decide
which profile fields read what changed; only those fields get the smallest consistent edit, and every
other field is returned exactly as written.

```
author edits a sentence ─┐                      ┌─ patch-route.nlir: which fields read what changed
                         ├─▶ model edit ─────────┤
specification changes ───┘  (lens-concepts /    └─ patch.nlir: smallest edit to those fields, then $tidy
                             lens-packet, typed
                             by lens-typed)
```

## Programs (`site/spec-lab/`)

| Program | Binds | Does |
|---|---|---|
| `lens-profile.nlir` | `$model $p $profile` | pushes a whole authored profile into the model the packet gives (the "round-trip" model the profile is consistent with) |
| `lens-concepts.nlir` | `$model $p $part $old $new` | an edited field → node edits (a requirement is always a condition, never an exception) |
| `lens-packet.nlir` | `$model $before $after` | a changed packet → node edits, each quoting the new passage |
| `lens-typed.nlir` | `$edits $part` (+ `patch-route.nlir`) | keeps only node edits in groups the edited field reads; the rest become warnings |
| `patch-route.nlir` | `$model $after` | deterministic: `$changed`, `$route`, `$gate` (scope instructions), `$tidy` |
| `patch.nlir` | `$model $after $profile $note` (+ `patch-route.nlir`) | patches only the routed fields; returns the profile as JSON |
| `lens-redundant.nlir` | `$model` | each exception: a genuine carve-out, or a restatement of a boundary a condition draws |
| `lens-check.nlir` | `$p $model $profile` | overlap / gap between MET and NOT MET, with a concrete case; warns, never edits |
| `patch-repair.nlir` | `$model $profile $finding` | proposes the smallest repair of a finding (`finding.narrow` to move only cases like it) |

`examples/patch.sh` checks the deterministic parts (routing, gates, tidy, typing) in `--mode det`.

## The harness: `scripts/edit-loop.py`

Every model call goes through nlir and its cache; Python only applies node edits and counts. Inputs: a
dataset (`[{id, packet, gold}]`) and the concept layer's rule models (`{id: model}`); the endpoint and key
come from the nlir config.

```sh
L="--data DATASET.json --models MODELS.json --config CFG --judge2 opus"
scripts/edit-loop.py $L --out a.json --typed                 # three author edits per rule
scripts/edit-loop.py $L --out b.json --source packet         # the change starts in the specification
scripts/edit-loop.py $L --out c.json --sequence              # three edits in turn: do they compose?
scripts/edit-loop.py $L --out d.json --undo                  # add an exception, then delete it
scripts/edit-loop.py $L --out e.json --typed --kinds removal # delete an exception the model has
scripts/edit-loop.py $L --out f.json --repair [--narrow]     # propose repairs of the authors' own overlaps and gaps
scripts/edit-loop.py $L --out g.json --typed --seed-base 100 # an independent second sample of every call
scripts/edit-loop.py $L --out h.json --convention "SENTENCE"  # append a profile-wide convention to every DECISION BOUNDARY
scripts/edit-loop.py $L --out i.json --questions OPEN.json      # answer each open question both ways: is it settled?
scripts/edit-loop.py $L --out n.json --merge AUTHOR.json        # two authors at once: merge exception + requirement through the model (and as text)
scripts/edit-loop.py $L --out o.json --conflicts AUTHOR.json    # ... and does merge-check.nlir flag a requirement that contradicts the exception?
scripts/edit-loop.py $L --out p.json --impact D-1,D-2 --impact-models AUTHOR.json   # which rules does a changed definition touch?
scripts/edit-loop.py $L --out q.json --impact-apply p.json --impact-models AUTHOR.json   # ... patch the rules the check selects, ask again
scripts/edit-loop.py $L --out l.json --fixpoint AUTHOR.json     # settle each model to a fixed point of its authored profile
scripts/edit-loop.py $L --out k.json --roundtrip AUTHOR.json    # read every patched profile back into the model: is the edit recovered?
scripts/edit-loop.py $L --out m.json --roundtrip AUTHOR.json --anchor l.json   # ... read back from the fixed point
(--anchor l.json on an author run maintains from the fixed points instead of m0: same results, not carried — settle for the check, not the edit)
scripts/edit-loop.py $L --out j.json --consolidate SEQ.json    # tighten what a --sequence run added, judge every edit again (not carried)
```

Useful options: `--rules-file` (one id per line; ids may contain spaces), `--editor opus` (another model
writes the model edits and patches), `--workers`. Each output holds, per rule, the authored profile, the
model edits and warnings, the routing, the patched fields and both judges' readings before and after, plus
a `summary`. `scripts/test_edit_loop.py` tests the deterministic parts without a model.

## The explainer

`scripts/export-explain-patches.py RUN.json [RUN.json ...] site/explain/traces.json` turns runs into the
explainer's patch view (word diffs against the authors' text, the routing drawn as the program's graph,
warnings, specification passages, repair proposals with the adjacent case they would move);
`scripts/export-explain-lint.py` marks each exception as a carve-out or a restatement.

## What the experiments added to the programs

- Route by the model's dependencies, not by trusting the patch to leave fields alone.
- A changed condition or exception governs every way MET can be met (`$gate`).
- A sentence changes only what its field reads (`lens-typed.nlir`); anything else is a warning.
- A requirement and an exception work in opposite directions (`lens-concepts.nlir`).
- Most exceptions authors state restate a boundary; removing one changes no verdict — check with
  `lens-redundant.nlir` first.
- Repairs of the authors' own inconsistencies are proposals: a broad repair settles a class of cases and
  moves its neighbours, a narrow one settles the case and leaves the class open.
