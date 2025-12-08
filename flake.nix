{
  description = "ytsurf - YouTube terminal search and playback tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system}.default = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };

      # Allows `nix run .`
      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/ytsurf";
      };
    };
}
