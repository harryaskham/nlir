# Session summary — CI: darwin release build via flake devShell + portable libiconv rewrite (bd-7e465a)

## Goal

Produce a PORTABLE aarch64-darwin release binary from the self-hosted nix runner,
whose job steps run in a restricted env that can reach neither the system Apple cc
nor the login rustup toolchain.

## Bead(s)

- `bd-7e465a` — CI ensure-step exit-code (78ac0b2) + dtolnay-skip (3d2a883) + darwin toolchain (this)

## Before state

- 8 darwin failures at the Build step. aur-0/aur-2 co-read the logs; the diagnostic echo showed `TARGET=aarch64-darwin lh=/var/empty cargo=/nix/store/..cargo-1.95 cc=none`. Root cause (confirmed on the runner): job steps run as a SERVICE user (HOME=/var/empty), `/usr/bin/cc` is unreachable in that context, and `/Users/harryaskham` is 0750 so the login toolchain is unreadable. Only the nix store is accessible; the ambient nix cargo's rustc-wrapper has no linker.

## After state

- Darwin build now runs inside the flake devShell: `nix develop --command cargo build --release --bin nlir` (devShell ships clang-wrapper-21 cc + cargo + libiconv). Because that links libiconv from the NIX STORE (non-portable), the step then rewrites just that dylib id to the ABI-compatible system `/usr/lib/libiconv.2.dylib` with `install_name_tool`, and FAILS if any `/nix/store` dep remains — so the shipped binary links only `/usr/lib/*`. Linux stays on native cargo/dtolnay (gated on `$TARGET`).
- Verified END-TO-END locally: `nix develop` release build (1m02s) → otool before = `/nix/store/..libiconv` + `/usr/lib/libSystem`; after rewrite = ONLY `/usr/lib/libiconv.2.dylib` + `/usr/lib/libSystem.B.dylib`; `nlir --version` → `nlir 0.1.1`. install_name_tool + otool are in the devShell (cctools).
- Pending: re-dispatch release.yml -f tag=v0.1.1.

## Diff summary

- Code/content commit: pending final squash SHA from reintegration receipt.
- Files touched: `.github/workflows/release.yml` (Build step only).
- Tests: none (CI YAML); verified via a full local nix-develop release build + otool linkage check + run.
- Behavioural delta: darwin release builds via the flake devShell and is post-linked to system libiconv for portability; Linux unchanged.

## Operator-takeaway

The self-hosted nix darwin runner's job env cannot reach the system Apple
toolchain (service user, /var/empty home, /usr/bin/cc unreachable, login home
0750), so a bare native cargo build is impossible there — but the nix devShell
toolchain IS reachable and builds fine; its only non-portable artifact is the
nix-store libiconv, which a one-line `install_name_tool` rewrite pins back to the
system dylib (verified portable). The `otool | grep /nix/store` guard makes the
build FAIL loudly rather than ship a nix-linked asset. If a future dep adds
another nix-linked dylib, that guard is the tripwire.
