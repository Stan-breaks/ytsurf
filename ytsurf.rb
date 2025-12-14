class Ytsurf < Formula
  desc "YouTube in your terminal. Clean and distraction-free"
  homepage ""
  url "https://github.com/Stan-breaks/ytsurf/archive/refs/tags/v3.0.3.zip"
  sha256 "5714196c2b6f48f496181a9cde334feb3d7585df4bc5ddb02770ac715b5acb66"
  version "3.0.3"
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
