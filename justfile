set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

sync-install:
  #!/usr/bin/env bash
  git pull --rebase --autostash
  nix develop '.#devShells.aarch64-darwin.default' --command \
    cargo build --release --bin nlir && cp "${CARGO_TARGET_DIR:-target}/release/nlir" "${HOME}/.local/bin/nlir"
