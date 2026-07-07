set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

sync-install:
  #!/usr/bin/env bash
  git pull --rebase --autostash
  nix develop '.#devShells.aarch64-darwin.default' --command \
    cargo build --release --bin nlir && cp "${CARGO_TARGET_DIR:-target}/release/nlir" "${HOME}/.local/bin/nlir"

# Assert the SPEC operator tables stay in sync with config.example.yaml / `nlir help`
# (bd-be33ee) — fails on a missing op, a stale op, or a name mismatch.
verify-spec-ops:
  python3 scripts/verify-spec-ops.py
