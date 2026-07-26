{
  description = "Tuxedo Control Center for NixOS";

  inputs = {
    # Pinned to a fixed rev (not the moving nixos-unstable branch) so that a
    # blanket `nix flake update` in a consuming flake does not re-lock this
    # input and force a full source rebuild of TCC's node/electron closure.
    # Bump deliberately when updating TCC.
    nixpkgs.url = "github:NixOS/nixpkgs/0bb7ec54c8483066ec9d7720e780a5caa71f8612";
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-compat,
    }:
    let
      system = "x86_64-linux";
      tcc-pkgs =
        (import nixpkgs {
          currentSystem = system;
          localSystem = system;
        }).pkgs;
      tuxedo-control-center = tcc-pkgs.callPackage ./pkgs/tuxedo-control-center { };
      tccOverlay = final: prev: {
        inherit tuxedo-control-center;
      };
    in
    {
      packages.x86_64-linux.default = tuxedo-control-center;
      overlays.default = tccOverlay;
      nixosModules.default = import ./modules { inherit tccOverlay; };
    };
}
