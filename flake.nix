{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            pkg-config
            stack
            cabal-install
            git
          ];

          buildInputs = with pkgs; [
            zlib 
            haskell.compiler.native-bignum.ghc9103
          ];

          shellHook = ''
            export PKG_CONFIG_PATH="${pkgs.zlib.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
            export CPATH="${pkgs.zlib.dev}/include:$CPATH"
            export LIBRARY_PATH="${pkgs.zlib}/lib:$LIBRARY_PATH"
          '';
        };

        packages.default = pkgs.haskellPackages.callCabal2nix "mc-config" ./. {};
      });
}
