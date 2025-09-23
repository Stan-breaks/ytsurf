# ytsurf

A simple shell script to search YouTube videos from your terminal and play them with mpv or download them.

## Demo
<img width="1366" height="768" alt="250814_13h56m36s_screenshot" src="https://github.com/user-attachments/assets/0771f53b-ad16-41a2-9938-9aaaf0eaa1ae" />


## Features

- Search YouTube from your terminal
- Interactive selection with `fzf` (thumbnail previews) or `rofi`
- Download videos or audio
- Select video format/quality
- External config file for default options
- 10-minute result caching
- Playback history
- Audio-only mode
- Channel search
- limit search results

## Installation

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

Add `~/.local/bin` to your PATH if it's not already there.

## Dependencies

- **Required:** `bash`, `yt-dlp`, `jq`, `curl`, `mpv`, `fzf`, `chafa`,`ffmpeg` (for fzf thumbnails)
- **Optional:** `rofi`

Install on Arch Linux:
`sudo pacman -S yt-dlp jq curl mpv fzf chafa rofi ffmpeg`

## Usage

```bash
USAGE:
  $SCRIPT_NAME [OPTIONS] [QUERY]

OPTIONS:
  --audio         Play/download audio-only version
  --download      Download instead of playing
  --format        Interactively choose format/resolution
  --rofi          Use rofi instead of fzf for menus
  --sentaku       Use sentaku instead of fzf or rofi(for system that can't compile go)
  --history       Show and replay from viewing history
  --limit <N>     Limit number of search results (default: $DEFAULT_LIMIT)
  --edit, -e      edit the configuration file
  --help, -h      Show this help message
  --version       Show version info

CONFIG:
  $CONFIG_FILE can contain default options like:
    limit=5
    audio_only=true
    use_rofi=true

EXAMPLES:
  $SCRIPT_NAME lo-fi study mix
  $SCRIPT_NAME --audio orchestral soundtrack
  $SCRIPT_NAME --download --format jazz piano
  $SCRIPT_NAME --history
EOF
}
```

You can also run `ytsurf` without arguments to enter interactive search mode. All flags can be combined.

## Configuration

You can set default options by creating a config file at `~/.config/ytsurf/config`. Command-line flags will always override the config file.

**Example Config:**
```bash
# ~/.config/ytsurf/config

# Set a higher default search limit
limit=25

# Always use audio-only mode by default
audio_only=true

# Set a custom download directory
download_dir="$HOME/Videos/YouTube"
```

## Contributing

Contributions are welcome! Please read the [Contributing Guidelines](CONTRIBUTING.md) to get started. You can also check out the [Future Features](FUTURE_FEATURES.md) list for ideas.

## License

This script is released under the [GNU General Public License v3.0](LICENSE).

## Star History

<a href="https://www.star-history.com/#Stan-breaks/ytsurf&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date" />
 </picture>
</a>
