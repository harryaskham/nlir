set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

sync-install:
  #!/usr/bin/env bash
  git pull --rebase --autostash
  cargo build --release --bin nlir && cp "${CARGO_TARGET_DIR:-target}/release/nlir" "$root/nlir"
