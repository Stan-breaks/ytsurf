{
  chafa,
  curl,
  ffmpeg,
  fzf,
  jq,
  lib,
  makeWrapper,
  mpv,
  perl,
  stdenvNoCC,
  yt-dlp,
}:
stdenvNoCC.mkDerivation {
  pname = "ytsurf";
  version = "3.1.0"; # update when you tag releases

  nativeBuildInputs = [makeWrapper];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm777 ${./ytsurf.sh} $out/bin/ytsurf
    wrapProgram $out/bin/ytsurf \
      --prefix PATH : ${
      lib.makeBinPath [
        chafa
        curl
        ffmpeg
        fzf
        jq
        mpv
        perl
        yt-dlp
      ]
    }

    runHook postInstall
  '';

  meta.mainProgram = "ytsurf";
}
