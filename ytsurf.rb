class Ytsurf < Formula
  desc "YouTube in your terminal. Clean and distraction-free"
  homepage ""
  url "https://github.com/Stan-breaks/ytsurf/archive/refs/tags/v3.1.2.zip"
  sha256 "7dfa675fa4b0479587b1c9dee11165f7739387a68fc2a9b7a4e854c963bd4ff1"
  version "3.1.2"
  license "GPL-3.0"
  
  depends_on "bash"
  depends_on "yt-dlp"
  depends_on "jq"
  depends_on "curl"
  depends_on "mpv"
  depends_on "perl"
  depends_on "fzf"
  depends_on "chafa"
  depends_on "ffmpeg"

  def install
    system "mv ytsurf.sh ytsurf"
    bin.install "ytsurf"
  end

  test do
    system "ytsurf"
  end
end
