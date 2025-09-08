#!/usr/bin/env bash
set -euo pipefail

#=============================================================================
# ytsurf - search, stream, or download YouTube videos from your terminal 🎵📺
# Version: 1.8.0
#=============================================================================

# Exit if not running in bash
if [[ -z "$BASH_VERSION" ]]; then
	echo "This script requires Bash." >&2
	exit 1
fi

#=============================================================================
# CONSTANTS AND DEFAULTS
#=============================================================================

readonly SCRIPT_VERSION="1.8.0"
readonly SCRIPT_NAME="ytsurf"

# Default configuration values
DEFAULT_LIMIT=10
DEFAULT_AUDIO_ONLY=false
DEFAULT_USE_ROFI=false
DEFAULT_DOWNLOAD_MODE=false
DEFAULT_HISTORY_MODE=false
DEFAULT_FORMAT_SELECTION=false
DEFAULT_MAX_HISTORY_ENTRIES=100

# System directories
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$SCRIPT_NAME"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$SCRIPT_NAME"
readonly HISTORY_FILE="$CACHE_DIR/history.json"
readonly CONFIG_FILE="$CONFIG_DIR/config"

#=============================================================================
# GLOBAL VARIABLES
#=============================================================================

# Configuration variables (will be set from defaults, config file, and CLI args)
limit="$DEFAULT_LIMIT"
audio_only="$DEFAULT_AUDIO_ONLY"
use_rofi="$DEFAULT_USE_ROFI"
download_mode="$DEFAULT_DOWNLOAD_MODE"
history_mode="$DEFAULT_HISTORY_MODE"
format_selection="$DEFAULT_FORMAT_SELECTION"
download_dir="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
max_history_entries="$DEFAULT_MAX_HISTORY_ENTRIES"

# Runtime variables
query=""
TMPDIR=""

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

# Print help message
print_help() {
	cat <<EOF
$SCRIPT_NAME - search, stream, or download YouTube videos from your terminal 🎵📺

USAGE:
  $SCRIPT_NAME [OPTIONS] [QUERY]

OPTIONS:
  --audio         Play/download audio-only version
  --download      Download instead of playing
  --format        Interactively choose format/resolution
  --rofi          Use rofi instead of fzf for menus
  --history       Show and replay from viewing history
  --limit <N>     Limit number of search results (default: $DEFAULT_LIMIT)
  --help, -h      Show this help message
  --version       Show version info

CONFIG:
  $CONFIG_FILE can contain default options like:
    limit=15
    audio_only=true
    use_rofi=true

EXAMPLES:
  $SCRIPT_NAME lo-fi study mix
  $SCRIPT_NAME --audio orchestral soundtrack
  $SCRIPT_NAME --download --format jazz piano
  $SCRIPT_NAME --history
EOF
}

# Print version information
print_version() {
	echo "$SCRIPT_NAME v$SCRIPT_VERSION"
}

# Initialize directories and files
init_directories() {
	mkdir -p "$CACHE_DIR" "$CONFIG_DIR"

	if [[ ! -f "$HISTORY_FILE" ]]; then
		echo "[]" >"$HISTORY_FILE"
	fi
}

# Load configuration from file
load_config() {
	if [[ -f "$CONFIG_FILE" ]]; then
		# shellcheck source=/dev/null
		source "$CONFIG_FILE"
	fi
}

# Setup cleanup trap
setup_cleanup() {
	TMPDIR=$(mktemp -d)
	trap 'rm -rf "$TMPDIR"' EXIT
}

# Validate required dependencies
check_dependencies() {
	local missing_deps=()

	# Required dependencies
	local required_deps=("yt-dlp" "mpv" "jq" "xh")
	for dep in "${required_deps[@]}"; do
		if ! command -v "$dep" &>/dev/null; then
			missing_deps+=("$dep")
		fi
	done

	# Menu system dependency (at least one required)
	if ! command -v "fzf" &>/dev/null && ! command -v "rofi" &>/dev/null; then
		missing_deps+=("fzf or rofi")
	fi

	# Thumbnail dependency (optional but recommended)
	if ! command -v "chafa" &>/dev/null; then
		echo "Warning: chafa not found - thumbnails will not be displayed" >&2
	fi

	if [[ ${#missing_deps[@]} -ne 0 ]]; then
		echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
		echo "Please install the missing packages and try again." >&2
		exit 1
	fi
}

#=============================================================================
# ARGUMENT PARSING
#=============================================================================

parse_arguments() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			print_help
			exit 0
			;;
		--version | -v)
			print_version
			exit 0
			;;
		--rofi)
			use_rofi=true
			shift
			;;
		--audio)
			audio_only=true
			shift
			;;
		--history)
			history_mode=true
			shift
			;;
		--download)
			download_mode=true
			shift
			;;
		--format)
			format_selection=true
			shift
			;;
		--limit)
			shift
			if [[ -n "${1:-}" && "$1" =~ ^[0-9]+$ ]]; then
				limit="$1"
				shift
			else
				echo "Error: --limit requires a number" >&2
				exit 1
			fi
			;;
		*)
			query="$*"
			break
			;;
		esac
	done
}

#=============================================================================
# ACTION SELECTION
#=============================================================================

select_action() {
	local chosen_action
	local prompt="Select Action:"
	local header="Available Actions"
	local items=("watch" "download")

	if [[ "$use_rofi" == true ]]; then
		chosen_action=$(printf "%s\n" "${items[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
	elif [[ "$use_rofi" == false ]]; then
		chosen_action=$(printf "%s\n" "${items[@]}" | fzf --prompt="$prompt" --header="$header")
	fi

	if [[ "$chosen_action" == "watch" ]]; then
		echo false
	else
		echo true
	fi
	return 0
}

#=============================================================================
# CONTENT TYPE SELECTION
#=============================================================================

select_content() {
	echo "action"
	local chosen_action
	local prompt="Select Action:"
	local header="Available Actions"
	local items=("watch" "download")

	if [[ "$use_rofi" == true ]]; then
		chosen_action=$(printf "%s\n" "${items[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
	elif [[ "$use_rofi" == false ]]; then
		chosen_action=$(printf "%s\n" "${items[@]}" | fzf --prompt="$prompt" --header="$header")
	fi
	echo "$chosen_action"
	return 0
}
#=============================================================================
# FORMAT SELECTION
#=============================================================================

select_format() {
	local video_url="$1"

	# If --audio is passed with --format, non-interactively select bestaudio
	if [[ "$audio_only" = true ]]; then
		echo "bestaudio"
		return 0
	fi

	# Get available formats
	local format_list
	if ! format_list=$(yt-dlp -F "$video_url" 2>/dev/null); then
		echo "Error: Could not retrieve formats for the selected video." >&2
		return 1
	fi

	# Extract resolution options
	local format_options=()
	mapfile -t format_options < <(echo "$format_list" | grep -oE '[0-9]+p[0-9]*' | sort -rn | uniq)

	if [[ ${#format_options[@]} -eq 0 ]]; then
		echo "Error: No video formats found." >&2
		return 1
	fi

	# Present options to user
	local chosen_res
	local prompt="Select video quality:"
	local header="Available Resolutions"

	if [[ "$use_rofi" = true ]]; then
		chosen_res=$(printf "%s\n" "${format_options[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
	else
		chosen_res=$(printf "%s\n" "${format_options[@]}" | fzf --prompt="$prompt" --header="$header")
	fi

	# Process selection
	if [[ -z "$chosen_res" ]]; then
		return 1 # User cancelled
	fi

	local chosen_format
	if [[ "$chosen_res" == "best" || "$chosen_res" == "worst" ]]; then
		chosen_format="$chosen_res"
	else
		local height=${chosen_res%p*}
		chosen_format="bestvideo[height<=${height}]+bestaudio/best"
	fi

	echo "$chosen_format"
	return 0
}

#=============================================================================
# VIDEO ACTIONS
#=============================================================================

perform_action() {
	local video_url="$1"
	local video_title="$2"
	local img_path="$3"

	# Get format if format selection is enabled

	if [[ "$download_mode" == false ]]; then
		local selection
		if ! selection="$(select_action)"; then
			echo "Action selection cancelled" >&2
			return 1
		fi
		download_mode="$selection"
	fi

	local format_code=""
	if [[ "$format_selection" = true ]]; then
		if ! format_code=$(select_format "$video_url"); then
			echo "Format selection cancelled." >&2
			return 1
		fi
	fi

	echo "▶ Performing action on: $video_title"

	if [[ "$download_mode" = true ]]; then
		notify-send -t 5000 -i "$img_path" "Ytsurf" "Downloading to $video_title"
		download_video "$video_url" "$format_code"
	else
		notify-send -t 5000 -i "$img_path" "Ytsurf" "Playing $video_title"
		play_video "$video_url" "$format_code"
	fi
}

download_video() {
	local video_url="$1"
	local format_code="$2"

	mkdir -p "$download_dir"
	echo "Downloading to $download_dir..."

	local yt_dlp_args=(
		-o "$download_dir/%(title)s [%(id)s].%(ext)s"
		--audio-quality 0
	)

	if [[ "$audio_only" = true ]]; then
		yt_dlp_args+=(-x --audio-format mp3)
	else
		yt_dlp_args+=(--remux-video mp4)
		if [[ -n "$format_code" ]]; then
			yt_dlp_args+=(--format "$format_code")
		fi
	fi

	yt-dlp "${yt_dlp_args[@]}" "$video_url"
}

play_video() {
	local video_url="$1"
	local format_code="$2"

	local mpv_args=(--really-quiet)

	if [[ "$audio_only" = true ]]; then
		mpv_args+=(--no-video)
	fi

	if [[ -n "$format_code" ]]; then
		mpv_args+=(--ytdl-format="$format_code")
	fi

	mpv "${mpv_args[@]}" "$video_url"
}

#=============================================================================
# HISTORY MANAGEMENT
#=============================================================================

add_to_history() {
	local video_id="$1"
	local video_title="$2"
	local video_duration="$3"
	local video_author="$4"
	local video_views="$5"
	local video_published="$6"
	local video_thumbnail="$7"

	local tmp_history
	tmp_history="$(mktemp)"

	# Validate existing JSON
	if ! jq empty "$HISTORY_FILE" 2>/dev/null; then
		echo "[]" >"$HISTORY_FILE"
	fi

	# Create new entry and merge with existing history
	jq -n \
		--arg title "$video_title" \
		--arg id "$video_id" \
		--arg duration "$video_duration" \
		--arg author "$video_author" \
		--arg views "$video_views" \
		--arg published "$video_published" \
		--arg thumbnail "$video_thumbnail" \
		--argjson max_entries "$max_history_entries" \
		--slurpfile existing "$HISTORY_FILE" \
		'
        {
            title: $title,
            id: $id,
            duration: $duration,
            author: $author,
            views: $views,
            published: $published,
            thumbnail: $thumbnail,
            timestamp: now
        } as $new_entry |
        ([$new_entry] + ($existing[0] | map(select(.id != $id)))) |
        .[0:$max_entries]
        ' >"$tmp_history"

	# Atomic move
	mv "$tmp_history" "$HISTORY_FILE"
}

handle_history_mode() {
	if [[ ! -s "$HISTORY_FILE" ]]; then
		echo "No viewing history found."
		exit 0
	fi

	local json_data
	if ! json_data=$(cat "$HISTORY_FILE" 2>/dev/null); then
		echo "Error: Could not read history file." >&2
		exit 1
	fi

	local history_titles=()
	local history_ids=()

	mapfile -t history_ids < <(echo "$json_data" | jq -r '.[].id' 2>/dev/null)
	mapfile -t history_titles < <(echo "$json_data" | jq -r '.[].title' 2>/dev/null)

	if [[ ${#history_titles[@]} -eq 0 ]]; then
		echo "History is empty or corrupted."
		exit 0
	fi

	# Select from history
	local selected_title
	selected_title=$(select_from_menu "${history_titles[@]}" "Watch history:" "$json_data" true)

	if [[ -z "$selected_title" ]]; then
		echo "No selection made."
		exit 1
	fi

	# Find selected video
	local selected_index=-1
	for i in "${!history_titles[@]}"; do
		if [[ "${history_titles[$i]}" == "$selected_title" ]]; then
			selected_index=$i
			break
		fi
	done

	if [[ $selected_index -lt 0 ]]; then
		echo "Error: Could not resolve selected video." >&2
		exit 1
	fi

	# Extract video details
	local video_id video_url
	video_id="${history_ids[$selected_index]}"
	video_url="https://www.youtube.com/watch?v=$video_id"

	local video_duration video_author video_views video_published video_thumbnail img_path
	video_duration=$(echo "$json_data" | jq -r ".[$selected_index].duration")
	video_author=$(echo "$json_data" | jq -r ".[$selected_index].author")
	video_views=$(echo "$json_data" | jq -r ".[$selected_index].views")
	video_published=$(echo "$json_data" | jq -r ".[$selected_index].published")
	video_thumbnail=$(echo "$json_data" | jq -r ".[$selected_index].thumbnail")

	img_path="$TMPDIR/thumb_$video_id.jpg"

	# Update history and perform action
	add_to_history "$video_id" "$selected_title" "$video_duration" "$video_author" "$video_views" "$video_published" "$video_thumbnail"
	perform_action "$video_url" "$selected_title" "$img_path"
}

#=============================================================================
# SEARCH AND SELECTION
#=============================================================================

get_search_query() {
	if [[ -z "$query" ]]; then
		if [[ "$use_rofi" = true ]]; then
			query=$(rofi -dmenu -p "Enter YouTube search:")
		else
			read -rp "Enter YouTube search: " query
		fi
	fi

	if [[ -z "$query" ]]; then
		echo "No query entered. Exiting."
		exit 1
	fi
}

fetch_search_results() {
	local search_query="$1"
	local cache_key cache_file json_data

	# Setup caching
	cache_key=$(echo -n "$search_query" | sha256sum | cut -d' ' -f1)
	cache_file="$CACHE_DIR/$cache_key.json"

	# Check cache (10 minute expiry)
	if [[ -f "$cache_file" && $(find "$cache_file" -mmin -10 2>/dev/null) ]]; then
		cat "$cache_file"
		return 0
	fi

	# Fetch new results
	local encoded_query
	encoded_query=$(printf '%s' "$search_query" | jq -sRr @uri)

	if ! json_data=$(xh "https://www.youtube.com/results?search_query=${encoded_query}&sp=EgIQAQ%253D%253D&hl=en&gl=US" 2>/dev/null); then
		echo "Error: Failed to fetch search results." >&2
		return 1
	fi

	# Parse results
  local parsed_data
  parsed_data=$(echo "$json_data" |
      sed -n '/var ytInitialData = {/,/};$/p' |
      sed '1s/^.*var ytInitialData = //' |
      sed '$s/;$//' |
      jq -r "
      [
        .. | objects |
        select(has(\"videoRenderer\")) |
        .videoRenderer | {
          title: .title.runs[0].text,
          id: .videoId,
          author: .longBylineText.runs[0].text,
          published: .publishedTimeText.simpleText,
          duration: .lengthText.simpleText,
          views: .viewCountText.simpleText,
          thumbnail: (.thumbnail.thumbnails | sort_by(.width) | last.url)
        }
      ] | .[:${limit}]
      " 2>/dev/null)

	if [[ -z "$parsed_data" || "$parsed_data" == "null" ]]; then
		echo "Error: Failed to parse search results." >&2
		return 1
	fi

	# Cache results
	echo "$parsed_data" >"$cache_file"
	echo "$parsed_data"
}

create_preview_script_fzf() {
	local is_history="${1:-false}"

	cat <<'EOF'
idx=$(($1))
id=$(echo "$json_data" | jq -r ".[$idx].id" 2>/dev/null)
title=$(echo "$json_data" | jq -r ".[$idx].title" 2>/dev/null)
duration=$(echo "$json_data" | jq -r ".[$idx].duration" 2>/dev/null)
views=$(echo "$json_data" | jq -r ".[$idx].views" 2>/dev/null)
author=$(echo "$json_data" | jq -r ".[$idx].author" 2>/dev/null)
published=$(echo "$json_data" | jq -r ".[$idx].published" 2>/dev/null)
thumbnail=$(echo "$json_data" | jq -r ".[$idx].thumbnail" 2>/dev/null)

if [[ -n "$id" && "$id" != "null" ]]; then
    echo
    echo
EOF

	if [[ "$is_history" = true ]]; then
		printf 'echo -e "\033[1;35mFrom History\033[0m"'
	fi

	cat <<'EOF'
    echo -e "\033[1;36mTitle:\033[0m \033[1m$title\033[0m"
    echo -e "\033[1;33mDuration:\033[0m $duration"
    echo -e "\033[1;32mViews:\033[0m $views"
    echo -e "\033[1;35mAuthor:\033[0m $author"
    echo -e "\033[1;34mUploaded:\033[0m $published"
    echo
    echo
    
    if command -v chafa &>/dev/null; then
        img_path="$TMPDIR/thumb_$id.jpg"
        [[ ! -f "$img_path" ]] && curl -fsSL "$thumbnail" -o "$img_path" 2>/dev/null
        chafa --symbols=block --size=80x40 "$img_path" 2>/dev/null || echo "(failed to render thumbnail)"
    else
        echo "(chafa not available - no thumbnail preview)"
    fi
    echo
else
    echo "No preview available"
fi
EOF
}

create_preview_script_rofi() {
	local menu=""

	while read -r item; do
		title=$(jq -r '.title' <<<"$item")
		id=$(jq -r '.id' <<<"$item")
		thumbnail=$(jq -r '.thumbnail' <<<"$item")
		img_path="$TMPDIR/thumb_$id.jpg"

		[[ ! -f "$img_path" ]] && curl -fsSL "$thumbnail" -o "$img_path" 2>/dev/null

		menu+="$title\0icon\x1fthumbnail://$img_path\n"
	done < <(jq -c ".[:$limit][]" <<<"$json_data")

	printf "%b" "$menu"
}

select_from_menu() {
	local menu_items=("$@")
	local prompt="${menu_items[-3]}"
	local json_data="${menu_items[-2]}"
	local is_history="${menu_items[-1]:-false}"

	# Remove the last 3 items (prompt, json_data, is_history) from menu_items
	unset 'menu_items[-1]' 'menu_items[-1]' 'menu_items[-1]'

	if [[ ${#menu_items[@]} -eq 0 ]]; then
		echo "No items to select from." >&2
		return 1
	fi

	# Export data for preview script
	export json_data TMPDIR

	local selected_item=""
	if [[ "$use_rofi" = true ]] && command -v rofi &>/dev/null; then
		selected_item=$(create_preview_script_rofi | rofi -dmenu -show-icons)
	elif command -v fzf &>/dev/null; then
		local preview_script
		preview_script=$(create_preview_script_fzf "$is_history")

		selected_item=$(printf "%s\n" "${menu_items[@]}" | fzf \
			--prompt="$prompt" \
			--preview="bash -c '$preview_script' -- {n}")
	else
		echo "Error: Neither fzf nor rofi is available for the interactive menu." >&2
		return 1
	fi

	echo "$selected_item"
}

handle_search_mode() {
	get_search_query

	local json_data
	if ! json_data=$(fetch_search_results "$query"); then
		echo "Failed to fetch search results for '$query'"
		exit 1
	fi

	# Build menu list
	local menu_list=()
	mapfile -t menu_list < <(echo "$json_data" | jq -r '.[].title' 2>/dev/null)

	if [[ ${#menu_list[@]} -eq 0 ]]; then
		echo "No results found for '$query'"
		exit 0
	fi

	# Select video
	local selected_title
	selected_title=$(select_from_menu "${menu_list[@]}" "Search YouTube:" "$json_data" false)

	if [[ -z "$selected_title" ]]; then
		echo "No selection made."
		exit 1
	fi

	# Find selected video index
	local selected_index=-1
	for i in "${!menu_list[@]}"; do
		if [[ "${menu_list[$i]}" == "$selected_title" ]]; then
			selected_index=$i
			break
		fi
	done

	if [[ $selected_index -lt 0 ]]; then
		echo "Error: Could not resolve selected video." >&2
		exit 1
	fi

	# Extract video details
	local video_id video_url video_author video_duration video_views video_published video_thumbnail img_path
	video_id=$(echo "$json_data" | jq -r ".[$selected_index].id")
	video_url="https://www.youtube.com/watch?v=$video_id"
	video_author=$(echo "$json_data" | jq -r ".[$selected_index].author")
	video_duration=$(echo "$json_data" | jq -r ".[$selected_index].duration")
	video_views=$(echo "$json_data" | jq -r ".[$selected_index].views")
	video_published=$(echo "$json_data" | jq -r ".[$selected_index].published")
	video_thumbnail=$(echo "$json_data" | jq -r ".[$selected_index].thumbnail")

	img_path="$TMPDIR/thumb_$video_id.jpg"
	# Add to history and perform action
	add_to_history "$video_id" "$selected_title" "$video_duration" "$video_author" "$video_views" "$video_published" "$video_thumbnail"
	perform_action "$video_url" "$selected_title" "$img_path"
}

#=============================================================================
# MAIN EXECUTION
#=============================================================================

main() {
	# Initialize environment
	init_directories
	load_config
	setup_cleanup
	check_dependencies

	# Parse command line arguments
	parse_arguments "$@"

	# Execute appropriate mode
	if [[ "$history_mode" = true ]]; then
		handle_history_mode
	else
		handle_search_mode
	fi
}

# Run main function with all arguments
main "$@"
