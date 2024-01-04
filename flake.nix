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
          overlays = [ self.overlays.cre2 ];
        };
      in
      {
        packages.default = pkgs.callPackage ./package.nix {};

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/sqlite-notebook";
        };

        checks.package = self.packages.${system}.default;

        devShells.default = pkgs.mkShell {
          inputsFrom = [self.packages.${system}.default];

          packages = [
            pkgs.cargo
            pkgs.rust-analyzer
            pkgs.rustfmt

            (pkgs.python3.withPackages (ps: [
              ps.notebook
              ps.jupyter_console
            ]))
          ] ++ pkgs.lib.lists.optional (builtins.elem system pkgs.valgrind.meta.platforms && !pkgs.valgrind.meta.broken or false) [
            pkgs.valgrind
          ];
        };

        jupyterWithModules.default = self.jupyterWithModules.${system}.sqlite-notebook;
        jupyterWithModules.sqlite-notebook = ({ lib, pkgs, config, ... }: let
          cfg = config.kernel.sqlite;

          sqliteKernelModule = ({ name, config, ... }: {
            options = {
              enable = lib.mkEnableOption "enable profile Sqlite Kernel `${name}`";

              package = lib.mkOption {
                type = lib.types.package;
                default = self.packages.${system}.default;
              };

              kernelJsonPath = lib.mkOption {
                type = lib.types.path;
                default = "/share/jupyter/kernels/sqlite-notebook/kernel.json";
              };

              build = lib.mkOption {
                type = lib.types.package;
                internal = true;
              };
            };

            config = lib.mkIf (config.enable) {
              build = pkgs.runCommand "${name}-jupyter-kernel"
                {
                  passthru = {
                    kernelInstance.language = "sqlite";
                    IS_JUPYTER_KERNEL = true;
                  };
                }
                (lib.concatStringsSep "\n" [
                  "mkdir -p $out/kernels/${name}"
                  "cp -R ${config.package + config.kernelJsonPath} $out/kernels/${name}/kernel.json"
                ]);
            };
          });
        in {
          options.kernel.sqlite = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule sqliteKernelModule);
          };

          # options.kernel.sqlite
        });
      }) // {
        # TODO(someday): Remove this once https://github.com/NixOS/nixpkgs/pull/252995
        # is merged upstream.
        overlays.cre2 = final: prev: {
          cre2 = prev.cre2.overrideAttrs (oldAttrs: {
            buildInputs = builtins.filter (input: input.pname != "re2") oldAttrs.buildInputs;
            propagatedBuildInputs = [ final.re2 ];
          });
        };
      };
}
