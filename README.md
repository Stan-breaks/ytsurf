# ytsurf

A lightweight terminal tool to **search, stream, and download YouTube videos** with `mpv`, `yt-dlp`, and a fuzzy finder.

<p align="center">
  <img width="720" alt="demo" src="https://github.com/user-attachments/assets/0771f53b-ad16-41a2-9938-9aaaf0eaa1ae" />
</p>



## ✨ Features

* 🔍 Search YouTube directly from your terminal
* 🎬 Play instantly with `mpv`
* 👥 **Syncplay support** – watch videos together with friends in sync (instead of solo playback in `mpv`)
* 🎧 Audio-only playback & downloads
* 📥 Download videos or audio
* 🎚 **Interactive format/quality selection** – choose resolution or audio format when playing *or* downloading
* 🎨 Interactive menus with `fzf` (thumbnail previews via `chafa`), `rofi`, or `sentaku`
* ⚙️ External config file for default options
* 📜 10-minute search result caching
* 🕘 Playback history and re-run support
* 🔢 Adjustable search result limit
* 📂 Custom download directory
* ⬆️ Self-update (`--update`) **for manual installations only**
* 🔗 Copy and share **short YouTube URLs** directly to your clipboard or print them in the terminal  



| Selector          | Features                                        | Best For                          |
| ----------------- |  ----------------------------------------------- | --------------------------------- |
| **fzf** (default) |Terminal-based, thumbnail previews, lightweight | Most users (fast + previews)      |
| **rofi**          | GUI menu, keyboard-driven, clean look           | Users who prefer a graphical menu |
| **sentaku**       | Very minimal, no previews                       | Systems without Go/`fzf` support  |



## 📦 Installation

### Arch Linux (AUR)

```bash
yay -S ytsurf
# or
paru -S ytsurf
```

### Manual Installation

```bash
mkdir -p ~/.local/bin
curl -o ~/.local/bin/ytsurf https://raw.githubusercontent.com/Stan-breaks/ytsurf/main/ytsurf.sh
chmod +x ~/.local/bin/ytsurf
```

Make sure `~/.local/bin` is in your **PATH**.


## 🔧 Dependencies

* **Required:** `bash`, `yt-dlp`, `jq`, `curl`, `mpv`, `fzf`, `chafa`, `ffmpeg`
* **Optional:** `rofi`, `sentaku`, `syncplay`

Arch Linux install:

```bash
sudo pacman -S yt-dlp jq curl mpv fzf chafa rofi ffmpeg
```


## 🚀 Usage

```bash
USAGE:
  ytsurf [OPTIONS] [QUERY]

OPTIONS:
  -h, --help        Show help message
  -V, --version     Show version info
  --rofi            Use rofi for menus instead of fzf
  --sentaku         Use sentaku instead of fzf/rofi (for systems without Go)
  --audio           Play/download audio-only version
  --download, -d    Download instead of playing
  --syncplay        Use syncplay instead of mpv
  --format, -f      Interactively choose format/resolution
  --history         Show and replay from viewing history
  --limit, -l <N>   Limit number of search results (default: from config)
  --edit, -e        Edit the configuration file
  --copy-url      Copy or display the video link
  --update, -u      Update the script to the latest version

EXAMPLES:
  ytsurf lo-fi study mix
  ytsurf --audio orchestral soundtrack
  ytsurf --download --format jazz piano
  ytsurf --history
```

Run `ytsurf` without arguments to enter interactive mode.


## ⚙️ Configuration

Defaults can be set in `~/.config/ytsurf/config`.
CLI flags always override config values.

**Example config:**

```bash
# ~/.config/ytsurf/config

# Set a higher default search limit
limit=25

# Always use audio-only mode
audio_only=true

# Set a custom download directory
download_dir="$HOME/Videos/YouTube"
```


## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md).
Check out [FUTURE_FEATURES.md](FUTURE_FEATURES.md) for upcoming ideas.


## 📜 License

Released under the [GNU General Public License v3.0](LICENSE).


## ⭐ Star History

<a href="https://www.star-history.com/#Stan-breaks/ytsurf&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date" />
 </picture>
</a>  

