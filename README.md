# ytsurf

YouTube in your terminal. Clean and distraction-free.

<p align="center">
  <img width="720" alt="demo" src="https://github.com/user-attachments/assets/0771f53b-ad16-41a2-9938-9aaaf0eaa1ae" />
</p>



## ✨ Features

- Syncplay support – watch videos together in sync
- Audio-only playback & downloads
- Download videos or audio
- Interactive format/quality selection when playing or downloading
- External config file
- Playback history and quick re-play
- Adjustable search result limit
- Custom download directory
- Self-update (--update) for manual installations only
- Copy short YouTube URLs to clipboard or print them
- Channel subscriptions with a personalized feed


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

### Homebrew

```bash
brew tap stan-breaks/ytsurf https://github.com/stan-breaks/ytsurf
brew install stan-breaks/ytsurf/ytsurf
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
  --audio         Play/download audio-only version
  --download      Download instead of playing
  --format        Interactively choose format/resolution
  --rofi          Use rofi instead of fzf for menus
  --syncplay      Watch youtube with friend from the terminal
  --subscribe, -S Add a channel to the subs.txt
  --feed,-F       View videos from your feed
  --sentaku       Use sentaku instead of fzf or rofi(for system that can't compile go)
  --history       Show and replay from viewing history
  --limit <N>     Limit number of search results (default: in the config)
  --edit, -e      edit the configuration file
  --help, -h      Show this help message
  --version       Show version info
  --copy-url      Copy or display the video link

EXAMPLES:
  ytsurf lo-fi study mix
  ytsurf --audio orchestral soundtrack
  ytsurf --download --format jazz piano
  ytsurf --history
```

Run `ytsurf` without arguments to enter interactive mode.


## ⚙️ Configuration

Defaults check for default config in `~/.config/ytsurf/config`.
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

