{
  description = "Jupyter notebook kernel for SQLite3";

  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages.default = pkgs.callPackage ./package.nix {
          libclang = pkgs.pkgsBuildHost.rustc.llvmPackages.libclang;
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/sqlite-notebook";
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [self.packages.${system}.default];

          shellHook = ''
            export LIBCLANG_PATH=${self.packages.${system}.default.LIBCLANG_PATH}
          '';

          packages = [
            pkgs.cargo
            pkgs.rust-analyzer
            pkgs.rustfmt
          ];
        };
      }
    );
}
