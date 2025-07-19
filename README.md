# ytsurf

A simple shell script to search YouTube videos from your terminal and play them with mpv.

## Demo

https://github.com/user-attachments/assets/8c0d4057-db7b-457d-88cf-39aa782a1c6c

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
# Basic search
ytsurf lofi hip hop study

# Search with 25 results instead of the default 10
ytsurf --limit 25 dnb mix

# Audio-only playback
ytsurf --audio npr tiny desk

# Download the selected video
ytsurf --download how to make ramen

# Select a specific video format before playback/download
ytsurf --format space video

# Search for a channel
ytsurf --channel the primetime

# View watch history
ytsurf --history

#use rofi instead of fzf
ytsurf --rofi

# interactive use
ytsurf

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

[![Star History Chart](https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date)](https://www.star-history.com/#Stan-breaks/ytsurf&Date)
