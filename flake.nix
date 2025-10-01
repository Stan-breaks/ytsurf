{
  description = "ytsurf - YouTube terminal search and playback tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "ytsurf";
        version = "2.0.2"; # update when you tag releases

        src = ./.;

        buildInputs = [
          pkgs.bash
          pkgs.yt-dlp
          pkgs.jq
          pkgs.curl
          pkgs.mpv
          pkgs.fzf
          pkgs.chafa
          pkgs.ffmpeg
        ];

        installPhase = ''
          mkdir -p $out/bin
          cp ytsurf.sh $out/bin/ytsurf
          chmod +x $out/bin/ytsurf
        '';
      };

      # Allows `nix run .`
      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/ytsurf";
      };
    };
}
