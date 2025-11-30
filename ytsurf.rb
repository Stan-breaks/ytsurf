class Ytsurf < Formula
  desc "YouTube in your terminal. Clean and distraction-free"
  homepage ""
  url "https://github.com/Stan-breaks/ytsurf/archive/refs/tags/v3.0.0.zip"
  sha256 "bd2a5f1ffeb496276c89c74332661a131e99894e36fc95e598fcef71dac5a611"
  version "3.0.0"
  license "GPL-3.0"
  
  depends_on "bash"
  depends_on "yt-dlp"
  depends_on "jq"
  depends_on "curl"
  depends_on "mpv"
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
