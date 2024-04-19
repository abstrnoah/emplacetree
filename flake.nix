{

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = inputs@{ ... }:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        upstreams = {
          inherit (inputs.nixpkgs.legacyPackages.${system})
            writeShellApplication coreutils-prefixed diffutils fd;
        };
      in {
        packages.emplacetree = upstreams.writeShellApplication {
          name = "emplacetree";
          text = builtins.readFile ./emplacetree.sh;
          runtimeInputs =
            [ upstreams.fd upstreams.coreutils-prefixed upstreams.diffutils ];
        };
        packages.default = inputs.self.packages.${system}.emplacetree;
      });

}
