# Session summary — darwin CI: build local to this Mac (--builders '') (bd-099010)

## Goal
Make the aarch64-darwin release build produce a portable Mac asset from CI, on the self-hosted darwin runner.

## Bead(s)
- `bd-099010` — darwin CI runner can't produce a portable native build

## Before state
- Explicit `.#devShells.aarch64-darwin.default` (adcf099) surfaced the real blocker: the runner's nix failed to BUILD the darwin flake (`Cannot build feedback-cli-patched.drv / nlir-src.drv`, `__impureHostDeps of nix-shell`, `failed dependency`) — the darwin derivation was being delegated to a builder that can't provide darwin host deps.

## After state
- Harry's guidance: azure-ephemeral = all Linux; self-hosted = mixed macos+linux builders; macos must build only on this Mac. The runner nix has `builders=@/etc/nix/machines`. Verified with the runner's OWN nix 2.34.7: `nix develop '.#devShells.aarch64-darwin.default' --builders '' --command …` builds the darwin devShell LOCALLY → sys=aarch64-darwin, cc=clang-wrapper-21, otool=cctools.
- Fix: added `--builders ''` to the darwin build step so the darwin build stays local to this Mac (no delegation). In-repo, no system rebuild.
- Pending: re-dispatch to confirm the CI job builds + attaches the Mac asset. If the restricted CI env still fails, the durable fix is runner-level (git.nix builders/system-features + darwin-rebuild) — Harry's infra lane.

## Diff summary
- Code/content commit: pending final squash SHA from reintegration receipt.
- Files touched: `.github/workflows/release.yml` (darwin Build step: `--builders ''`).
- Tests: verified the runner's nix builds the darwin devShell locally with `--builders ''`.
- Behavioural delta: darwin build forced local; Linux path unchanged.

## Operator-takeaway
On a self-hosted Mac runner whose nix has remote (Linux) builders configured, a darwin nix build can be delegated to a builder that can't satisfy darwin `__impureHostDeps` and fails. Force darwin builds local with `--builders ''` (or fix the runner's builders/system-features at the git.nix level + rebuild).
