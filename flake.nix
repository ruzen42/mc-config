{
  description = "mc-config — Minecraft Purpur server manager";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        haskell = pkgs.haskellPackages;

        mc-config = haskell.mkDerivation {
          pname   = "mc-config";
          version = "0.3.0.0";
          src     = ./.;

          isLibrary    = false;
          isExecutable = true;

          executableHaskellDepends = with haskell; [
            base
            aeson
            aeson-pretty
            bytestring
            wreq
            lens
            directory
            process
            optparse-applicative
          ];

          license     = pkgs.lib.licenses.mit;
          maintainers = [ "Ruzen42" ];
        };

      in {
        # nix build
        packages.default = mc-config;

        # nix run
        apps.default = flake-utils.lib.mkApp {
          drv = mc-config;
        };

        # nix develop
        devShells.default = pkgs.mkShell {
          name = "mc-config-dev";

          buildInputs = with pkgs; [
            # Haskell toolchain
            ghc
            cabal-install
            haskell-language-server
            hlint
            ormolu

            # Runtime deps (wreq needs OpenSSL/zlib at link time)
            zlib
            openssl

            # Useful in dev
            tmux
          ];

          # Let Cabal find system libs
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
            zlib
            openssl
          ]);
        };
      }
    );
}
