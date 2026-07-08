{
  description = "nlir — natural-language IR: transpile a terse, sigil-laden shorthand into fluent English via a config-defined stack machine (deterministic or LLM per operator). Built on the harryaskham CLI stack (mcp-cli, updatable-cli, feedback-cli).";

  inputs = {
    # Pinned to the SAME nixpkgs as ~/collective/flake.lock (flakehub pinned
    # immutable tarball, rev 0590cd39). Using collective's exact source tarball
    # means the whole toolchain is already in the store — no fresh nixpkgs pull.
    # Bump in lockstep with collective.
    nixpkgs.url = "https://api.flakehub.com/f/pinned/NixOS/nixpkgs/0.2511.909248%2Brev-0590cd39f728e129122770c029970378a79d076a/019ce32b-8ace-7339-b129-cceaa8dd10c6/source.tar.gz";
    flake-utils.url = "github:numtide/flake-utils/11707dc2f618dd54ca8739b309ec4fc024de578b";

    # Ecosystem crates pulled in directly from github:harryaskham/* — NOT
    # vendored. `nix flake update` moves them in lockstep. We consume the sources
    # (flake = false) and wire them into the cargo build so the build is fully
    # offline/reproducible in the nix sandbox. Fetched over SSH (git+ssh://) using
    # the host's git/SSH key at flake-eval time.
    mcp-cli = {
      url = "git+ssh://git@github.com/harryaskham/mcp-cli?ref=main";
      flake = false;
    };
    updatable-cli = {
      url = "git+ssh://git@github.com/harryaskham/updatable-cli?ref=main";
      flake = false;
    };
    feedback-cli = {
      url = "git+ssh://git@github.com/harryaskham/feedback-cli?ref=main&shallow=1";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      mcp-cli,
      updatable-cli,
      feedback-cli,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        # macOS links libiconv transitively (via the ureq/rustls TLS stack used
        # by feedback-cli / updatable-cli). Provide it on Darwin so both the nix
        # build and `nix develop` link cleanly.
        darwinLibs = lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];

        # updatable-cli / feedback-cli still carry a legacy https mcp-cli git
        # dependency in their own Cargo.toml. For Nix/offline builds, patch that
        # to the pinned mcp-cli flake input before using them as path patches.
        updatableCliPatched = pkgs.runCommand "updatable-cli-patched" { } ''
          cp -R ${updatable-cli} "$out"
          chmod -R u+w "$out"
          substituteInPlace "$out/Cargo.toml" \
            --replace-fail 'mcp-cli = { git = "https://github.com/harryaskham/mcp-cli", branch = "main" }' \
                           'mcp-cli = { path = "${mcp-cli}" }'
        '';

        feedbackCliPatched = pkgs.runCommand "feedback-cli-patched" { } ''
          cp -R ${feedback-cli} "$out"
          chmod -R u+w "$out"
          substituteInPlace "$out/Cargo.toml" \
            --replace-fail 'mcp-cli = { git = "https://github.com/harryaskham/mcp-cli", branch = "main" }' \
                           'mcp-cli = { path = "${mcp-cli}" }'
        '';

        # Vendor the 3 private git crates as PATH deps to the pre-fetched
        # flake-input store paths, so importCargoLock fetches NOTHING at build
        # time. The flake inputs are fetched once at flake-eval (as the user with
        # SSH); the build itself needs no SSH and no binary cache.
        nlirSrc = pkgs.runCommand "nlir-src" { } ''
          cp -R ${lib.cleanSource ./.} "$out"
          chmod -R u+w "$out"
          # Cargo.toml: the 3 git deps -> path deps to the flake-input sources.
          substituteInPlace "$out/Cargo.toml" \
            --replace-fail 'mcp-cli = { git = "ssh://git@github.com/harryaskham/mcp-cli", branch = "main", optional = true }' \
                           'mcp-cli = { path = "${mcp-cli}", optional = true }' \
            --replace-fail 'updatable-cli = { git = "ssh://git@github.com/harryaskham/updatable-cli", branch = "main", optional = true }' \
                           'updatable-cli = { path = "${updatableCliPatched}", optional = true }' \
            --replace-fail 'feedback-cli = { git = "ssh://git@github.com/harryaskham/feedback-cli", branch = "main", optional = true }' \
                           'feedback-cli = { path = "${feedbackCliPatched}", optional = true }'
          # Drop the now-unused top-level [patch] table (deps are direct paths).
          ${pkgs.gnused}/bin/sed -i '\#^\[patch\.#,$d' "$out/Cargo.toml"
          # Strip the 3 git source lines from Cargo.lock so importCargoLock sees
          # path deps (no fetch). Cargo treats unsourced lock entries as local.
          ${pkgs.gnused}/bin/sed -i '\#^source = "git+ssh://git@github.com/harryaskham/#d' "$out/Cargo.lock"
        '';

        nlir = pkgs.rustPlatform.buildRustPackage {
          pname = "nlir";
          version = "0.1.0";
          src = nlirSrc;

          cargoLock = {
            lockFile = "${nlirSrc}/Cargo.lock";
          };

          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = darwinLibs;

          meta = {
            description = "natural-language IR transpiler CLI";
            mainProgram = "nlir";
          };
        };
      in
      {
        packages = {
          default = nlir;
          nlir = nlir;
        };

        apps = {
          default = {
            type = "app";
            program = "${nlir}/bin/nlir";
          };

          # `nix run .#test` builds the package and smoke-exercises the CLI.
          test = {
            type = "app";
            program = "${pkgs.writeShellScript "nlir-integration" ''
              exec ${pkgs.bash}/bin/bash ${./test/integration.sh} "$@"
            ''}";
          };

          # `nix run .#preflight` runs the same fast gate as CI (rustfmt + clippy
          # -D warnings + unit tests) inside the dev shell, so a worker can
          # self-verify a clean merge before `caco agent reintegrate`.
          preflight = {
            type = "app";
            program = "${pkgs.writeShellScript "nlir-preflight" ''
              export PATH="${
                lib.makeBinPath [
                  pkgs.git
                  pkgs.nix
                  pkgs.bash
                  pkgs.coreutils
                ]
              }:$PATH"
              root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
              cd "$root"
              exec nix develop --command bash ${./scripts/preflight.sh} "$@"
            ''}";
          };
        };

        # Sandbox-pure check: the package builds.
        checks.build = nlir;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ nlir ];
          # Marker so scripts/preflight.sh can detect it is running inside the dev
          # shell (bd-b15ff8): outside it, the macOS system toolchain lacks
          # libiconv and cargo fails at link with `ld: library not found for
          # -liconv`. `nix develop` / `nix run .#preflight` run this shellHook.
          shellHook = ''
            export NLIR_DEV_SHELL=1
          '';
          packages =
            with pkgs;
            [
              cargo
              rustc
              rustfmt
              clippy
              rust-analyzer
              pkg-config
              git
              openssh
            ]
            ++ darwinLibs;
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
