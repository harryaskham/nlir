#!/usr/bin/env python3
"""verify-spec-ops.py — assert the SPEC operator tables stay in sync with config.

The phrasebook and SPEC advertise that SPEC.md, `nlir help`, and
config.example.yaml "all derive from the same config, so they stay in sync." That
invariant was NOT actually enforced: the SPEC operator table silently drifted
incomplete as operators were added (bd-2e59bb had to add 11 missing rows by hand;
bd-4db4ce fixed a stale `..` name). `nlir help` and the wasm playground are
auto-derived from the config, but the SPEC operator tables are hand-maintained, so
they are the surface that drifts.

This guard closes that drift class. It parses the operator sigils + names from
SPEC.md's operator tables and from config.example.yaml's `operators:` block, and
fails (exit 1) on any disagreement:
  * an op in config missing from the SPEC tables,
  * a stale op in the SPEC tables that is not a config operator,
  * a name mismatch (SPEC's `name` column != the config operator key).

Dependency-free (no PyYAML) so it runs on the keyless CI runner next to
verify-showcase.py.

Usage: python3 scripts/verify-spec-ops.py [--spec PATH] [--config PATH]
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def parse_config_ops(config_path: pathlib.Path) -> dict[str, str]:
    """Return {op_key: sigil} for every ACTIVE operator under the top-level
    `operators:` block. Commented-out example ops (`#   square: ...`) and other
    top-level sections are skipped."""
    ops: dict[str, str] = {}
    in_operators = False
    cur_key: str | None = None
    for raw in config_path.read_text(encoding="utf-8").splitlines():
        if re.match(r"^operators:\s*(#.*)?$", raw):
            in_operators = True
            continue
        if in_operators and re.match(r"^\S", raw):
            break  # a new column-0 section ends the operators block
        if not in_operators:
            continue
        m = re.match(r"^  ([A-Za-z][\w-]*):\s*(#.*)?$", raw)  # 2-space op key
        if m:
            cur_key = m.group(1)
            continue
        m = re.match(r'^    op:\s*"(.+?)"', raw)  # its 4-space `op: "…"`
        if m and cur_key is not None:
            ops[cur_key] = m.group(1)
            cur_key = None
    return ops


def parse_spec_ops(spec_path: pathlib.Path) -> dict[str, str]:
    """Return {sigil: name} for every row in a SPEC operator table — a markdown
    table whose header is `| op | name | fixity · arity | what it does |`. Only
    those tables are parsed, so worked-example tables are ignored."""
    ops: dict[str, str] = {}
    lines = spec_path.read_text(encoding="utf-8").splitlines()
    header_re = re.compile(r"^\|\s*op\s*\|\s*name\s*\|\s*fixity")
    i = 0
    while i < len(lines):
        if header_re.match(lines[i]):
            i += 2  # skip the header row and the `|---|` separator
            while i < len(lines) and lines[i].lstrip().startswith("|"):
                # Protect markdown-escaped pipes (`\|`, used by the `|` operator's
                # own row) so they do not split cells, then restore them.
                row = lines[i].strip().strip("|").replace("\\|", "\x00")
                cells = [c.replace("\x00", "|").strip() for c in row.split("|")]
                if len(cells) >= 2 and cells[0]:
                    sigil = cells[0].strip("`")
                    if sigil:
                        ops[sigil] = cells[1]
                i += 1
        else:
            i += 1
    return ops


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--spec", type=pathlib.Path, default=ROOT / "SPEC.md")
    ap.add_argument("--config", type=pathlib.Path, default=ROOT / "config.example.yaml")
    args = ap.parse_args()

    config_ops = parse_config_ops(args.config)  # key -> sigil
    if not config_ops:
        print(f"verify-spec-ops: no operators parsed from {args.config}", file=sys.stderr)
        return 2
    sigil_to_key = {sigil: key for key, sigil in config_ops.items()}
    spec_ops = parse_spec_ops(args.spec)  # sigil -> name
    if not spec_ops:
        print(f"verify-spec-ops: no operator tables parsed from {args.spec}", file=sys.stderr)
        return 2

    config_sigils = set(config_ops.values())
    spec_sigils = set(spec_ops)
    problems: list[str] = []

    for s in sorted(config_sigils - spec_sigils):
        problems.append(f"MISSING from SPEC operator tables: `{s}` (config op `{sigil_to_key[s]}`)")
    for s in sorted(spec_sigils - config_sigils):
        problems.append(f"STALE in SPEC operator tables: `{s}` (not a config operator)")
    for s in sorted(config_sigils & spec_sigils):
        want, got = sigil_to_key[s], spec_ops[s]
        if got != want:
            problems.append(f"NAME MISMATCH for `{s}`: SPEC says '{got}', config key is '{want}'")

    if problems:
        print("verify-spec-ops: SPEC operator tables are OUT OF SYNC with config.example.yaml:",
              file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        print(f"\n{len(config_sigils)} config operators, {len(spec_sigils)} SPEC operator rows. "
              "Fix SPEC.md's operator tables to match config.example.yaml (and `nlir help`).",
              file=sys.stderr)
        return 1

    print(f"verify-spec-ops: OK — SPEC operator tables match config "
          f"({len(config_sigils)} operators, names in sync).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
