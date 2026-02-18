class Ytsurf < Formula
  desc "YouTube in your terminal. Clean and distraction-free"
  homepage ""
  url "https://github.com/Stan-breaks/ytsurf/archive/refs/tags/v3.1.4.zip"
  sha256 "50bb0af907bf77f34c845aaa3e8b1107ca3cee38765aa30ee562e6877c6dcc3f"
  version "3.1.4"
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
