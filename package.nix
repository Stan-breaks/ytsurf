{
  lib,
  stdenvNoCC,
  yt-dlp,
  jq,
  curl,
  makeWrapper,
  mpv,
  fzf,
  chafa,
  ffmpeg,
}:
stdenvNoCC.mkDerivation {
  pname = "ytsurf";
  version = "3.0.2"; # update when you tag releases

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm777 ytsurf.sh $out/bin/ytsurf
    wrapProgram $out/bin/ytsurf \
      --prefix PATH : ${
        lib.makeBinPath [
          yt-dlp
          jq
          curl
          mpv
          fzf
          chafa
          ffmpeg
        ]
      }

    runHook postInstall
  '';

  meta.mainProgram = "ytsurf";
}
