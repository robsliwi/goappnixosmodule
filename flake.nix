{
  description = "A basic gomod2nix flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.gomod2nix.url = "github:nix-community/gomod2nix";

  outputs = { self, nixpkgs, flake-utils, gomod2nix }:
    (flake-utils.lib.eachDefaultSystem
      (system:
        let
          # Generate a user-friendly version number.
          version = builtins.substring 0 8 self.lastModifiedDate;

          pkgs = import nixpkgs {
            inherit system;
            overlays = [ gomod2nix.overlays.default ];
          };

        in
        {
          packages = {
            default = pkgs.buildGoModule {
              pname = "goappnixosmodule";
              inherit version;
              # In 'nix develop', we don't need a copy of the source tree
              # in the Nix store.
              src = ./.;

              modules = ./gomod2nix.toml;

              vendorSha256 = null;
            };

            docker =
              let
                app = self.packages.${system}.default;
              in
              pkgs.dockerTools.buildLayeredImage {
                name = app.pname;
                tag = app.version;
                contents = [ app ];

                config = {
                  Cmd = [ "/bin/goappnixosmodule" ];
                  WorkingDir = "/";
                };
              };

            goappnixosmodule-service = pkgs.substituteAll {
              name = "goappnixosmodule-server.service";
              src = ./systemd/goappnixosmodule.service.in;
              goappnixosmodule = self.packages.${system}.default;
            };

            portable =
              let
                goappnixosmodule = self.packages.${system}.default;
              in
              pkgs.portableService {
                inherit (goappnixosmodule) version;
                pname = goappnixosmodule.pname;
                description = "A goappnixosmodule server";
                units = [ self.packages.${system}.goappnixosmodule-service ];
              };

          };
          devShells.default = import ./shell.nix { inherit pkgs; };
        })
    );
}
