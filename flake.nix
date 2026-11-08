{
  description = "mvtt workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nix-darwin, ... }:
    {
      # One config for every Mac, whatever its hostname: always switch with `--flake .#mac --impure` (the user comes from $SUDO_USER).
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        modules = [ ./nix/darwin.nix ];
      };
    };
}
