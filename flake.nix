{
  description = "Tuxedo Control Center for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
