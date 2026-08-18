{
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
          version = "1.2.0.0";
          src     = ./.;

          isLibrary    = false;
          isExecutable = true;

          executableHaskellDepends = with haskell; [
            base
            aeson
            bytestring
            wreq
            lens
            directory
            process
            optparse-applicative
            rainbow
            toml-parser
            containers
          ];

          license     = pkgs.lib.licenses.mit;
          maintainers = [ "Ruzen42" ];
        };

      in {
        packages.default = mc-config;

        apps.default = flake-utils.lib.mkApp {
          drv = mc-config;
        };

        devShells.default = pkgs.mkShell {
          name = "mc-config-dev";

          buildInputs = with pkgs; [
            ghc
            cabal-install
            zlib
            openssl
          ];

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
            zlib
            openssl
          ]);
        };
      }
    );
}
