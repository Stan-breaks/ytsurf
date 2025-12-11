{
  description = "ytsurf - YouTube terminal search and playback tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    {
      overlays.default = final: _: {
        ytsurf = final.callPackage ./package.nix { };
      };

      packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: {
        default = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
      });
    };
}
