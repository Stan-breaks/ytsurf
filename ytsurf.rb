class Ytsurf < Formula
  desc "YouTube in your terminal. Clean and distraction-free"
  homepage ""
  url "https://github.com/Stan-breaks/ytsurf/archive/refs/tags/v3.1.3.zip"
  sha256 "ab7f508b073bdf3c6507522e6c2a497b4b626cbb5742ceb8bee661263462543e"
  version "3.1.3"
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
