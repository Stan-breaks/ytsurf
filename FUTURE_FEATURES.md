# Future Feature Ideas

This document lists potential features for future development.

### 1. Playlist Support
- **Idea:** Add a `--playlist` flag to search for and select YouTube playlists.
- **Implementation:** When a playlist is selected, the script could either play the entire playlist sequentially in `mpv` or open a second `fzf` menu to allow the user to pick a specific video from it.
- **Benefit:** Expands the script's capability from single videos to entire series or music albums.

### 2. Video Queueing
- **Idea:** Allow the user to select multiple videos in `fzf` to create a temporary playback queue.
- **Implementation:** Use `fzf`'s multi-select feature (e.g., by pressing `Tab` on multiple entries). The script would gather the selected video URLs and pass them to `mpv` to be played sequentially.
- **Benefit:** Ideal for creating on-the-fly music playlists or watching several short videos without interruption.
