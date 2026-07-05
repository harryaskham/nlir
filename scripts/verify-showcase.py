#!/usr/bin/env python3
"""verify-showcase.py — prove the showcase cards are REAL nlir executions.

Harry's bar: "make sure we are really executing the nlir expressions — not theory
only." This re-runs each showcase card's expression against the actual `nlir`
binary and checks the stored output is real:

  * det · exact cards      -> re-run in --mode det, assert output matches EXACTLY.
  * llm coercion · exact   -> re-run in --mode llm, assert output matches EXACTLY
                             (coercion arithmetic is deterministic).
  * other llm cards        -> re-run in --mode llm, assert output is non-empty.
  * cards that read chat    -> expr contains ^, needs message context; SKIPPED here
    (^, ^_, ^*)              and proven instead by their runnable examples/*.sh.

Any EXACT mismatch fails the run (exit 1) — so a fabricated/hand-edited output
can never silently ship. LLM checks need LITELLM_MASTER_KEY; without it (e.g. a
keyless CI runner) they are skipped and only the offline det cards are enforced.

Usage:
  python3 scripts/verify-showcase.py [--det-only] [--nlir PATH] [--timeout SECS]
"""
from __future__ import annotations
import argparse, importlib.util, os, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BS_PATH = ROOT / "scripts" / "build-showcase.py"


def load_cards():
    spec = importlib.util.spec_from_file_location("_bs", BS_PATH)
    bs = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bs)  # __name__ == "_bs", so main() does not run
    return list(getattr(bs, "SIMPLE", [])), list(getattr(bs, "GRID", []))


def run(nlir: str, expr: str, mode: str, timeout: int) -> tuple[bool, str]:
    cmd = [nlir, "-e", expr, "--mode", mode, "--quiet"]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return False, "<timeout>"
    if p.returncode != 0:
        return False, (p.stderr or p.stdout).strip().splitlines()[-1] if (p.stderr or p.stdout).strip() else "<nonzero exit>"
    # last non-empty stdout line is the realised value
    lines = [l for l in p.stdout.splitlines() if l.strip()]
    return True, (lines[-1] if lines else "")


def norm(s: str) -> str:
    # exact match, tolerant only of surrounding whitespace + a cosmetic paren-echo wrap
    s = s.strip()
    if len(s) >= 2 and s[0] == "(" and s[-1] == ")":
        s = s[1:-1].strip()
    return s


def needs_input(expr: str) -> str | None:
    """Return a reason string if this card's expr depends on external input that a
    bare `nlir -e` cannot supply (message context ^, or a claim/src bound to `x`),
    else None. Such cards are proven by their runnable examples/*.sh instead."""
    if "^" in expr:
        return "reads chat context (^)"
    # strip quoted literals, then look for a standalone x (the claim/src placeholder)
    stripped, i, q = [], 0, None
    for ch in expr:
        if q:
            if ch == q:
                q = None
        elif ch in "'\"":
            q = ch
        else:
            stripped.append(ch)
    bare = "".join(stripped)
    if any(
        c == "x" and (j == 0 or not bare[j - 1].isalnum()) and (j + 1 == len(bare) or not bare[j + 1].isalnum())
        for j, c in enumerate(bare)
    ):
        return "claim/src bound to x"
    return None


def run_examples(patterns, timeout):
    """Actually EXECUTE the example proof scripts (idiom-*.sh / move-*.sh) end to end.
    They carry the message context the ^-cards need, so running them closes the gap
    where verify only *deferred* those cards. Each script uses `set -euo pipefail`, so
    a non-zero exit means its nlir execution failed. Returns (ran_ok, [failures])."""
    ex_dir = ROOT / "examples"
    scripts = sorted({p for pat in patterns for p in ex_dir.glob(pat.strip())})
    ran_ok, fails = 0, []
    for s in scripts:
        try:
            p = subprocess.run(["bash", str(s)], capture_output=True, text=True,
                               timeout=timeout, cwd=str(ROOT), env=os.environ.copy())
        except subprocess.TimeoutExpired:
            fails.append(s.name); print(f"  ✗ FAIL  {s.name:34s} <timeout>"); continue
        if p.returncode == 0 and p.stdout.strip():
            ran_ok += 1
            print(f"  ✓ RAN   {s.name:34s} exit 0")
        else:
            fails.append(s.name)
            tail = ((p.stderr or p.stdout).strip().splitlines() or ["<empty>"])[-1]
            print(f"  ✗ FAIL  {s.name:34s} exit {p.returncode}: {tail[:60]}")
    return ran_ok, fails


def main() -> int:
    ap = argparse.ArgumentParser(description="Verify showcase cards are real nlir executions.")
    ap.add_argument("--nlir", default=os.environ.get("NLIR", str(ROOT / "target" / "release" / "nlir")))
    ap.add_argument("--det-only", action="store_true", help="skip LLM cards even if a key is present")
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--examples", action="store_true",
                    help="also execute the example proof scripts end-to-end (verifies ^-context cards)")
    ap.add_argument("--examples-glob", default="idiom-*.sh,move-*.sh",
                    help="comma-separated globs under examples/ for --examples (default idiom-*.sh,move-*.sh)")
    args = ap.parse_args()

    if not pathlib.Path(args.nlir).exists():
        print(f"nlir binary not found: {args.nlir}\n  build first: cargo build --release", file=sys.stderr)
        return 2
    have_key = bool(os.environ.get("LITELLM_MASTER_KEY"))
    do_llm = have_key and not args.det_only

    simple, grid = load_cards()
    fails, exact_ok, ran_ok, skipped = [], 0, 0, 0
    print(f"verifying {len(simple)} simple cards against {args.nlir}"
          f"  (llm={'on' if do_llm else 'off'})\n")

    for c in simple:
        name, expr, pill = c["name"], c["expr"], c.get("pill", "")
        out = c.get("out", "")
        if c.get("config_op"):
            print(f"  ~ SKIP  {name:22s} (user-config glyph-op — proven by config.example.yaml demos)")
            skipped += 1
            continue
        reason = needs_input(expr)
        if reason:
            print(f"  ~ SKIP  {name:22s} ({reason} — proven by examples/*.sh)")
            skipped += 1
            continue
        mode = "det" if pill.startswith("det") else "llm"
        exact = "exact" in pill
        if mode == "llm" and not do_llm:
            print(f"  ~ SKIP  {name:22s} (llm card; {'no --det-only' if have_key else 'no LITELLM_MASTER_KEY'})")
            skipped += 1
            continue
        ok, got = run(args.nlir, expr, mode, args.timeout)
        if not ok:
            fails.append((name, expr, "run failed", got))
            print(f"  ✗ FAIL  {name:22s} run error: {got}")
            continue
        if exact:
            if norm(got) == norm(out):
                exact_ok += 1
                print(f"  ✓ EXACT {name:22s} {mode} → {got!r}")
            else:
                fails.append((name, expr, out, got))
                print(f"  ✗ FAIL  {name:22s} {mode}\n           expected: {out!r}\n           got:      {got!r}")
        else:
            if norm(got):
                ran_ok += 1
                print(f"  ✓ RAN   {name:22s} {mode} → {got[:60]!r}{'…' if len(got) > 60 else ''}")
            else:
                fails.append((name, expr, "<non-empty>", got))
                print(f"  ✗ FAIL  {name:22s} {mode} produced empty output")

    print(f"\n  {exact_ok} exact-verified · {ran_ok} ran-non-empty · {skipped} skipped · {len(fails)} failed")
    if grid:
        print(f"  ({len(grid)} grid cards not auto-verified — multi-cell llm; see examples/)")

    ex_fails = []
    if args.examples:
        if not do_llm:
            why = "no LITELLM_MASTER_KEY" if not have_key else "--det-only set"
            print(f"\n  --examples skipped ({why}): the proof scripts call the model")
        else:
            pats = [g for g in args.examples_glob.split(",") if g.strip()]
            print(f"\nexecuting example proof scripts ({', '.join(pats)}) — the ^-context cards run end to end:")
            ex_ran, ex_fails = run_examples(pats, args.timeout)
            print(f"  {ex_ran} scripts ran clean · {len(ex_fails)} failed")

    if fails or ex_fails:
        if fails:
            print("\nFAILURES (fabricated or stale card outputs must be fixed):", file=sys.stderr)
            for name, expr, exp, got in fails:
                print(f"  · {name}: {expr}", file=sys.stderr)
        if ex_fails:
            print("\nEXAMPLE SCRIPT FAILURES (a ^-context card's execution broke):", file=sys.stderr)
            for n in ex_fails:
                print(f"  · examples/{n}", file=sys.stderr)
        return 1
    print("\n✓ every checked showcase card is a real, reproducible nlir execution.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
