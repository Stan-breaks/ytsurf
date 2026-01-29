#!/usr/bin/env bash

set -u
#=============================================================================
# CONSTANTS AND DEFAULTS
#=============================================================================

readonly SCRIPT_VERSION="3.1.1"
readonly SCRIPT_NAME="ytsurf"

# Default configuration values
DEFAULT_LIMIT=15
DEFAULT_AUDIO_ONLY=false
DEFAULT_USE_ROFI=false
DEFAULT_USE_SENTAKU=false
DEFAULT_DOWNLOAD_MODE=false
DEFAULT_HISTORY_MODE=false
DEFAULT_SUB_MODE=false
DEFAULT_FEED_MODE=false
DEFAULT_FORMAT_SELECTION=false
DEFAULT_MAX_HISTORY_ENTRIES=100
DEFAULT_NOTIFY=true
DEFAULT_COPY_MODE=false

# System directories
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$SCRIPT_NAME"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$SCRIPT_NAME"
readonly CONFIG_FILE="$CONFIG_DIR/config"
readonly SUB_FILE="$CONFIG_DIR/sub.json"
readonly YTSURF_SOCKET="${TMPDIR:-/tmp}/ytsurf-mpv-$$.sock"

#=============================================================================
# GLOBAL VARIABLES
#=============================================================================

# Configuration variables (will be set from defaults, config file, and CLI args)
limit="$DEFAULT_LIMIT"
audio_only="$DEFAULT_AUDIO_ONLY"
use_rofi="$DEFAULT_USE_ROFI"
use_sentaku="$DEFAULT_USE_SENTAKU"
download_mode="$DEFAULT_DOWNLOAD_MODE"
history_mode="$DEFAULT_HISTORY_MODE"
sub_mode="$DEFAULT_SUB_MODE"
add_sub=false
remove_sub=false
import_subs=false
feed_mode="$DEFAULT_FEED_MODE"
format_selection="$DEFAULT_FORMAT_SELECTION"
download_dir="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
history_file="$CACHE_DIR/history.json"
max_history_entries="$DEFAULT_MAX_HISTORY_ENTRIES"
notify="$DEFAULT_NOTIFY"
editor="nvim"
player="mpv"
applications="$HOME/.local/share/applications/ytsurf/"
copy_mode="$DEFAULT_COPY_MODE"

# Runtime variables
query=""
TMPDIR=""

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

fetch_feed(){
   cacheFeed="$CACHE_DIR/feed.json"
   if [[ -f "$cacheFeed" ]] && jq -e 'length != 0' "$cacheFeed" && (( $(date +%s) - $(stat -c "%Y" "$cacheFeed") < 1800 )); then
     cat "$cacheFeed"
   else
     mapfile -t subs < <(jq -r '.[] | "\(.title),\(.channelName)"' "$SUB_FILE")
     jsonData=$(printf "%s\n" "${subs[@]}" \
     | shuf \
     | head -n 5 \
     | xargs -P 6 -I{} bash -c 'process_channel "$@"' _ {} 2>/dev/null \
     | jq -c '.[]'\
     | shuf \
     | head -n "$limit" \
     | jq -s '.')
     echo "$jsonData" > "$cacheFeed"
     echo "$jsonData"
   fi
}

process_channel(){
  IFS=',' read -r title channel <<< "$1"
  title=$(xargs <<< "$title")
  channel=$(xargs <<< "$channel" | jq -nr --arg str "$channel" '$str|@uri' )
  curl -s --compressed --http1.1 --keepalive-time 30 \
    "https://www.youtube.com/$channel/videos" |
    sed -n 's/.*var ytInitialData = \(.*\);<\/script>.*/\1/p' |
    jq --arg author "$title" '
      .contents.twoColumnBrowseResultsRenderer.tabs[1]
      .tabRenderer.content.richGridRenderer.contents
      | map(.richItemRenderer.content.videoRenderer?)
      | map(select(.videoId and .title.runs[0].text))
      | map({
          id: .videoId,
          title: .title.runs[0].text,
          duration: .lengthText.simpleText,
          views: .shortViewCountText.simpleText,
          author: $author,
          published: .publishedTimeText.simpleText,
          thumbnail: .thumbnail.thumbnails[0].url
      })
  ' 2>/dev/null
}
export -f process_channel

search_channel(){
cacheKey=$(echo -n "$query channel" | sha256sum | cut -d' ' -f1)
cacheFile="$CACHE_DIR/$cacheKey"

if [[ -f "$cacheFile" ]] && (( $(date +%s) - $(stat -c "%Y" "$cacheFile") < 600 )); then
    cat "$cacheFile"
else
    local jsonData
    encodedQuery=$(jq -rn --arg q "$query" '$q|@uri')
    jsonData=$(curl -s --compressed --http1.1 --keepalive-time 30 "https://www.youtube.com/results?search_query=${encodedQuery}&sp=EgIQAg%3D%3D&hl=en&gl=US" \
      | sed -n 's/.*var ytInitialData = \(.*\);<\/script>.*/\1/p' \
      | jq -r '.contents.twoColumnSearchResultsRenderer.primaryContents.sectionListRenderer.contents[0].itemSectionRenderer.contents
      | map(.channelRenderer)
      | map({
              channelId: .channelId,
              channelName: .subscriberCountText.simpleText,
              title:.title.simpleText,
              thumbnail:("https:"+.thumbnail.thumbnails[0].url),
              subscribers:.videoCountText.simpleText,
           })
          |.[0:5]
          | map(select(.channelName != null and .subscribers != null))'\
          2>/dev/null \
    )
    echo "$jsonData" > "$cacheFile"
    echo "$jsonData"
fi
}



command -v notify-send >/dev/null 2>&1 && notify="true" || notify="false" # check if notify-send is installed
# Send notications
send_notification() {
  if [ "$use_rofi" = false ] && [ "$use_sentaku" = false ]; then
    [ -z "$2" ] && printf "\33[2K\r\033[1;34m%s\n\033[0m" "$1" && return
    [ -n "$2" ] && printf "\33[2K\r\033[1;34m%s - %s\n\033[0m" "$1" "$2" && return
  fi
  timeout=5000
  if [ "$notify" = "true" ]; then
    [ -z "${3:-}" ] && notify-send "$1" "$2" -t "$timeout"
    [ -n "${3:-}" ] && notify-send "$1" "$2" -t "$timeout" -i "$3"
  fi
}

#Send to clipboard
clip() {
  local url
  url="${*//www.youtube.com\/watch?v=/youtu.be/}"
  if command -v wl-copy &>/dev/null; then
    printf "%s" "$url" | wl-copy
  elif command -v xclip &>/dev/null; then
    printf "%s" "$url" | xclip -selection clipboard
  elif command -v xsel &>/dev/null; then
    printf "%s" "$url" | xsel --clipboard --input
  elif command -v pbcopy &>/dev/null; then
    printf "%s" "$url" | pbcopy
  elif [[ "$(uname -o 2>/dev/null)" == "Msys" ]] || [[ "$(uname -o 2>/dev/null)" == "Cygwin" ]]; then
    printf "%s" "$url" >/dev/clipboard
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    printf "%s" "$url" | powershell.exe Set-Clipboard
  else
    send_notification "Link" "$url"
  fi
  exit 0
}

create_desktop_entries_channel() {

  mkdir -p "$TMPDIR/applications"
  mkdir -p "$applications"
  [ ! -L "$applications" ] && ln -sf "$TMPDIR/applications/" "$applications"

  # Loop through results
  echo "$jsonData" | jq -c '.[]' | while read -r item; do
    local title id thumbnail img_path desktop_file
    if ! jq -e . >/dev/null 2>&1 <<<"$item"; then
      echo "Skipping invalid JSON item" >&2
      break
    fi
    # Check if required fields exist and aren't null
    title=$(jq -r '.title' <<<"$item")
    id=$(jq -r '.channelId' <<<"$item")
    thumbnail=$(jq -r '.thumbnail' <<<"$item")

    image_path="$TMPDIR/$id.jpg"
    desktop_file="$TMPDIR/applications/ytsurf-$id.desktop"

    # Fetch thumbnail if missing
    [[ ! -f "$image_path" ]] && curl -fsSL "$thumbnail" -o "$image_path" 2>/dev/null

    cat >"$desktop_file" <<EOF
[Desktop Entry]
Name=$title
Exec=echo $title
Icon=$image_path
Type=Application
Categories=ytsurf;
EOF
  done
}

create_preview_script_fzf_channel() {
  cat <<'EOF'
idx=$(($1))
id=$(echo "$jsonData" | jq -r ".[$idx].channelId" 2>/dev/null)
title=$(echo "$jsonData" | jq -r ".[$idx].title" 2>/dev/null)
channelName=$(echo "$jsonData" | jq -r ".[$idx].channelName" 2>/dev/null)
subscribers=$(echo "$jsonData" | jq -r ".[$idx].subscribers" 2>/dev/null)
thumbnail=$(echo "$jsonData" | jq -r ".[$idx].thumbnail" 2>/dev/null)
EOF

  cat <<'EOF'
    echo -e "\033[1;36mTitle:\033[0m \033[1m$title\033[0m"
    echo -e "\033[1;33mChannel Name:\033[0m $channelName"
    echo -e "\033[1;32mSubscribers:\033[0m $subscribers"
    echo
    echo
    
    if command -v chafa &>/dev/null; then
        img_path="$TMPDIR/$id.jpg"
        [[ ! -f "$img_path" ]] && curl -fsSL --compressed --http1.1 --keepalive-time 30  "$thumbnail" -o "$img_path" 2>/dev/null
        img_h=$((FZF_PREVIEW_LINES - 10))
        img_w=$((FZF_PREVIEW_COLUMNS - 4))
        img_h=$(( img_h < 10 ? 10 : img_h ))
        img_w=$(( img_w < 20 ? 20 : img_w ))
        chafa --symbols=block --size="${img_w}x${img_h}" "$img_path" 2>/dev/null || echo "(failed to render thumbnail)"
    else
        echo "(chafa not available - no thumbnail preview)"
    fi
    echo
EOF
}


create_desktop_entries() {
  local json_data="$1"

  mkdir -p "$TMPDIR/applications"
  mkdir -p "$applications"
  [ ! -L "$applications" ] && ln -sf "$TMPDIR/applications/" "$applications"

  # Loop through results
  echo "$json_data" | jq -c '.[]' | while read -r item; do
    local title id thumbnail img_path desktop_file
    if ! jq -e . >/dev/null 2>&1 <<<"$item"; then
      echo "Skipping invalid JSON item" >&2
      break
    fi
    # Check if required fields exist and aren't null
    title=$(jq -r '.title' <<<"$item")
    id=$(jq -r '.id' <<<"$item")
    thumbnail=$(jq -r '.thumbnail' <<<"$item")

    image_path="$TMPDIR/thumb_$id.jpg"
    desktop_file="$TMPDIR/applications/ytsurf-$id.desktop"

    # Fetch thumbnail if missing
    [[ ! -f "$image_path" ]] && curl -fsSL --compressed --http1.1 --keepalive-time 30 "$thumbnail" -o "$image_path" 2>/dev/null

    cat >"$desktop_file" <<EOF
[Desktop Entry]
Name=$title
Exec=echo $title
Icon=$image_path
Type=Application
Categories=ytsurf;

EOF
  done
}

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
  --syncplay      Watch youtube with friend from the terminal
  --subscribe, -s Add a channel to subscriptions locally
  --unsubscribe   Remove a channel to subscriptions locally
  --import-subs   Import subscriptions from youtube
  --feed,-F       View videos from your feed
  --sentaku       Use sentaku instead of fzf or rofi(for system that can't compile go)
  --history       Show and replay from viewing history
  --limit <N>     Limit number of search results (default: $DEFAULT_LIMIT)
  --edit, -e      edit the configuration file
  --help, -h      Show this help message
  --version       Show version info
  --copy-url      Copy or display the video link

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

update_script() {
  which_ytsurf="$(command -v ytsurf)"
  [ -z "$which_ytsurf" ] && send_notification "Can't find lobster in PATH"
  [ -z "$which_ytsurf" ] && exit 1
  update=$(curl -s "https://raw.githubusercontent.com/Stan-breaks/ytsurf/main/ytsurf.sh" || exit 1)
  update="$(printf '%s\n' "$update" | diff -u "$which_ytsurf" -)"
  if [ -z "$update" ]; then
    send_notification "Script is up to date :)"
  else
    if printf '%s\n' "$update" | patch "$which_ytsurf" -; then
      send_notification "Script has been updated!"
    else
      send_notification "Can't update for some reason! update with Paru or yay if on archlinux"
    fi
  fi
  exit 0
}

# Print version information
print_version() {
  echo "$SCRIPT_NAME v$SCRIPT_VERSION"
}

edit_config() {
  command -v "$editor" >/dev/null 2>&1 || editor="nano"
  "$editor" "$CONFIG_FILE"
  exit 0
}

# configuration
configuration() {
  mkdir -p "$CACHE_DIR" "$CONFIG_DIR"

  [ -f "$SUB_FILE" ] || echo "[]" > "$SUB_FILE"

  # shellcheck source=/home/stan/.config/ytsurf/config

  if [ ! -f "$CONFIG_FILE" ]; then
    cat >"$CONFIG_FILE" <<'EOF'
#limit=10
#audio_only=false
#use_rofi=false
#use_sentaku=false
#download_mode=false
#history_mode=false
#format_selection=false
#download_dir="$HOME/Downloads"
#history_file=="$HOME/.cache/ytsurf/history.json"
#max_history_entries=20
#notify=true
#editor="nvim"
#player="mpv"
EOF
  fi
  # shellcheck disable=SC1090
  [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
  [ -f "$history_file" ] || echo "[]" >"$history_file"
}

# Setup cleanup trap
setup_cleanup() {
  TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t ytsurf.XXXXXX)
  trap 'rm -rf "$TMPDIR"' EXIT
}

# Validate required dependencies
check_dependencies() {
  local missing_deps=()

  # Required dependencies

  local required_deps=("yt-dlp" "mpv" "jq" "curl" "perl")
  [ "$player" == "syncplay" ] && required_deps+=("syncplay")

  for dep in "${required_deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing_deps+=("$dep")
    fi
  done

  # Menu system dependency (at least one required)
  if ! command -v "fzf" &>/dev/null && ! command -v "rofi" &>/dev/null && ! command -v "sentaku" &>/dev/null; then
    missing_deps+=("fzf or rofi or sentaku")
  fi

  # Thumbnail dependency (optional but recommended)
  if ! command -v "chafa" &>/dev/null; then
    send_notification "Warning" "chafa not found - thumbnails will not be displayed"
  fi

  if [[ ${#missing_deps[@]} -ne 0 ]]; then
    send_notification "Error" "Missing required dependencies: ${missing_deps[*]}"
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
    --version | -V)
      send_notification "Ytsurf" "$SCRIPT_VERSION"
      exit 0
      ;;
    --rofi)
      use_rofi=true
      shift
      ;;
    --sentaku)
      use_sentaku=true
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
    --download | -d)
      download_mode=true
      shift
      ;;
    --syncplay)
      player="syncplay"
      shift
      ;;
    --format | -f)
      format_selection=true
      shift
      ;;
    --feed | -F)
      feed_mode=true 
      shift 
      ;;
    --subscribe| -S)
      sub_mode=true
      add_sub=true
      shift 
      ;;
     --unsubscribe)
      sub_mode=true
      remove_sub=true
      shift 
      ;;   
    --import-subs)
      sub_mode=true
      import_subs=true
      shift 
      ;;
    --copy-url)
      copy_mode=true
      shift
      ;;
    --limit | -l)
      shift
      if [[ -n "${1:-}" && "$1" =~ ^[0-9]+$ ]]; then
        limit="$1"
        shift
      else
        send_notification "Error" "--limit requires a number"
        exit 1
      fi
      ;;
    --edit | -e)
      edit_config
      ;;
    --update | -u)
      update_script
      ;;
    *)
      query="$*"
      break
      ;;
    esac
  done
}

#=============================================================================
# Subscribe
#=============================================================================


manage_subscriptions(){
  if [[ "$import_subs" == true ]];then
    sync_subs
  elif [[ "$add_sub" == true  ]];then
    subscribe
  elif [[ "$remove_sub" == true ]]; then
    unsubscribe
  else
    local chosen_action
    local prompt="Select Action:"
    local header="Available Actions"
    local items=("Sync_Subscriptions" "Add_Subscription" "Remove_Subscription")

    if [[ "$use_rofi" == true ]]; then
      chosen_action=$(printf "%s\n" "${items[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
    elif [[ "$use_sentaku" == true ]]; then
      chosen_action=$(printf "%s\n" "${items[@]}" | sentaku)
    else
      chosen_action=$(printf "%s\n" "${items[@]}" | fzf --prompt="$prompt" --header="$header")
    fi

    if [[ "$chosen_action" == "Sync_Subscriptions" ]];then
      sync_subs
    elif [[ "$chosen_action" == "Add_Subscription" ]];then
      subscribe
    else
      unsubscribe
    fi
  fi

  STATE=EXIT;
}

sync_subs(){
  local chosen_action
  local prompt="Select Action:"
  local header="This is gonna overwrite your existing subs. Continue?"
  local items=("Yes" "No")
  if [[ "$use_rofi" == true ]]; then
    chosen_action=$(printf "%s\n" "${items[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
  elif [[ "$use_sentaku" == true ]]; then
    chosen_action=$(printf "%s\n" "${items[@]}" | sentaku)
  else
    chosen_action=$(printf "%s\n" "${items[@]}" | fzf --prompt="$prompt" --header="$header")
  fi

  if [[ "$chosen_action" == "Yes" ]]; then
    prompt="Select Broswer:"
    header="Select a broswer where your youtube has be logged in"
    items=("brave" "chrome" "chromium" "edge" "firefox" "opera" "safari" "vivaldi" "whale")
    if [[ "$use_rofi" == true ]]; then
      chosen_action=$(printf "%s\n" "${items[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
    elif [[ "$use_sentaku" == true ]]; then
      chosen_action=$(printf "%s\n" "${items[@]}" | sentaku)
    else
      chosen_action=$(printf "%s\n" "${items[@]}" | fzf --prompt="$prompt" --header="$header")
    fi
    if  json_data=$(yt-dlp --cookies-from-browser "$chosen_action" --flat-playlist  https://www.youtube.com/feed/channels -J);then
      echo "$json_data" | jq -r '.entries
      | map({
             channelId:.channel_id,
             channelName:.uploader_id,
             title:.title,
             thumbnail:("https:" + .thumbnails[0].url),
             subscribers: (
                 .channel_follower_count
                 | if . >= 1000000 then (. / 1000000 | tostring + "M")
                   elif . >= 1000 then (. / 1000 | tostring + "K")
                   else tostring
                   end
                  )
           })' > "$SUB_FILE"
      send_notification "ytsurf" "Subs synced"
    else
      send_notification "Error" "Syncing failed"
    fi
  else 
    send_notification "Error" "Syncing cancel"
  fi

  exit 0

}

subscribe(){
 get_search_query
  jsonData=$(search_channel)
  export jsonData TMPDIR
  menuList=()
  mapfile -t menuList < <(echo "$jsonData" | jq -r '.[].title' 2>/dev/null)

  if [[ "$use_rofi" == true ]];then
    create_desktop_entries_channel 
    selected_item=$(select_with_rofi_drun)
    rm -rf "$TMPDIR/applications"
  elif [[ "$use_sentaku" == true ]];then
    selected_item=$(printf "%s\n" "${menu_items[@]}" | sed 's/ /␣/g' | sentaku)
    selected_item=${selected_item//␣/ }
  else
    previewScript=$(create_preview_script_fzf_channel)
    selected_item=$(printf "%s\n" "${menuList[@]}" | fzf \
          --prompt="search channel" \
          --preview="bash -c '$previewScript' -- {n}")
  fi
  [ -n "$selected_item" ] || {
    send_notification "Error" "No selection made."
    exit 1
  }
  idx=-1
  for i in "${!menuList[@]}"; do
      if [[ "${menuList[$i]}" == "$selected_item" ]]; then
          idx=$i
          break
      fi
  done
  [[ "$idx" -eq -1 ]] && exit 0

  local tmp_sub
  tmp_sub="$(mktemp)"

  if ! jq empty "$SUB_FILE" 2>/dev/null; then
     echo "[]" >"$SUB_FILE"
  fi
  
  entry=$(echo "$jsonData" | jq -r ".[$idx]")
  channelId=$(echo "$entry" | jq -r '.channelId')

  jq -n \
    --argjson new_entry "$entry" \
    --slurpfile existing "$SUB_FILE" \
    --arg channelId "$channelId" \
    '
      [$new_entry] +
      ($existing[0] | map(select(.channelId != $channelId)))
    ' >"$tmp_sub"

  mv "$tmp_sub" "$SUB_FILE"

  query=""
}

unsubscribe(){

  if ! jq empty "$SUB_FILE" 2>/dev/null; then
    send_notification "Error" "No subscriptions found."
    exit 1
  fi
  if jq -e 'length == 0' "$SUB_FILE" >/dev/null 2>&1; then
    send_notification "Error" "No subscriptions to unsubscribe."
    exit 0
  fi

  jsonData=$(cat "$SUB_FILE")

  export jsonData TMPDIR
  menuList=()
  mapfile -t menuList < <(echo "$jsonData" | jq -r '.[].title' 2>/dev/null)

  if [[ "$use_rofi" == true ]];then
    create_desktop_entries_channel 
    selected_item=$(select_with_rofi_drun)
    rm -rf "$TMPDIR/applications"
  elif [[ "$use_sentaku" == true ]];then
    selected_item=$(printf "%s\n" "${menu_items[@]}" | sed 's/ /␣/g' | sentaku)
    selected_item=${selected_item//␣/ }
  else
    previewScript=$(create_preview_script_fzf_channel)
    selected_item=$(printf "%s\n" "${menuList[@]}" | fzf \
          --prompt="search channel" \
          --preview="bash -c '$previewScript' -- {n}")
  fi
  [ -n "$selected_item" ] || {
    send_notification "Error" "No selection made."
    exit 1
  }
  idx=-1
  for i in "${!menuList[@]}"; do
      if [[ "${menuList[$i]}" == "$selected_item" ]]; then
          idx=$i
          break
      fi
  done
  [[ "$idx" -eq -1 ]] && exit 0
  local tmp_sub
  tmp_sub="$(mktemp)"

  entry=$(echo "$jsonData" | jq -r ".[$idx]")
  channelId=$(echo "$entry" | jq -r ".channelId")
  jq -n --arg channelId "$channelId"\
     --slurpfile existing "$SUB_FILE" \
    '
    ($existing[0] | map(select(.channelId != $channelId)))
    ' >"$tmp_sub"

  mv "$tmp_sub" "$SUB_FILE"

}
#=============================================================================
# ACTION SELECTION
#=============================================================================

select_action() {
  local chosen_action
  local prompt="Select Action:"
  local header="Available Actions"
  local items=("watch" "download" "watch_with_friends")

  if [[ "$use_rofi" == true ]]; then
    chosen_action=$(printf "%s\n" "${items[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
  elif [[ "$use_sentaku" == true ]]; then
    chosen_action=$(printf "%s\n" "${items[@]}" | sentaku)
  else
    chosen_action=$(printf "%s\n" "${items[@]}" | fzf --prompt="$prompt" --header="$header")
  fi

  if [[ "$chosen_action" == "watch" ]]; then
    echo false
  elif [[ "$chosen_action" == "watch_with_friends" ]];then
    player="syncplay"
    echo false

  elif [[ -z "$chosen_action" ]]; then
    return 1
  else
    echo true
  fi
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
  elif [[ "$use_sentaku" == true ]]; then
    chosen_res=$(printf "%s\n" "${format_options[@]}" | sentaku)
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
  # Get format if format selection is enabled
  [ "$download_mode" == false ] && {
    local selection
    selection="$(select_action)" || {
      send_notification "Error" "Action selection cancelled"
      return 1
    }
    download_mode="$selection"
  }

  if [[ "$format_selection" = true ]]; then
    if ! format_code=$(select_format "$video_url"); then
      send_notification "Format selection cancelled."
      return 1
    fi
  fi

  if [[ "$download_mode" = true ]]; then
    send_notification "Ytsurf" "Downloading to $selected_title" "$img_path"
    download_video "$video_url" "$format_code"
  else
    send_notification "Ytsurf" "Playing $selected_title" "$img_path"
    play_video "$video_url" "$format_code"
  fi

  [ "$history_mode" == "true" ] && STATE="HISTORY"
  [ "$history_mode" == "true" ] || {
    STATE="SEARCH"
    query=""
  }
}

download_video() {
  local video_url="$1"
  local format_code="$2"

  mkdir -p "$download_dir"
  send_notification "Ytsurf" "Downloading to $download_dir..."

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

  case "$player" in
  mpv)
    player="$player --keep-open=no --really-quiet --input-ipc-server=$YTSURF_SOCKET"
    [ "$audio_only" == "true" ] && player="$player --no-video"
    [ -n "$format_code" ] && player="$player --ytdl-format=\"$format_code\""
  
    player="$player $video_url"
    eval "$player"
    player="mpv"
    ;;
  syncplay)
    [ "$audio_only" == "true" ] && {
      send_notification "Error" "no support for audio only for syncplay for now"
      exit 1
    }
    "$player" "$video_url"
    exit 0
    ;;
  esac
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
  if ! jq empty "$history_file" 2>/dev/null; then
    echo "[]" >"$history_file"
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
    --slurpfile existing "$history_file" \
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
  mv "$tmp_history" "$history_file"
}

handle_history() {
  [ -z "$history_file" ] && {
    send_notification "Error" "No viewing history found."
    exit 1
  }

  local json_data
  if ! json_data=$(cat "$history_file" 2>/dev/null); then
    send_notification "Error" "Could not read history file." >&2
    exit 1
  fi

  local history_titles=()
  local history_ids=()

  mapfile -t history_ids < <(echo "$json_data" | jq -r '.[].id' 2>/dev/null)
  mapfile -t history_titles < <(echo "$json_data" | jq -r '.[].title' 2>/dev/null)

  if [[ ${#history_titles[@]} -eq 0 ]]; then
    send_notification "Error" "History is empty or corrupted."
    exit 1
  fi

  # Select from history
  if [[ "$use_rofi" == true ]]; then
    create_desktop_entries "$json_data"
    selected_title=$(select_with_rofi_drun)
    rm -rf "$TMPDIR/applications"

  else
      selected_title=$(select_from_menu "${history_titles[@]}" "Watch history:" "$json_data" true)
  fi

  [ -z "$selected_title" ] && {
    send_notification "Error" "No selection made."
    exit 1
  }

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
  local video_id
  video_id="${history_ids[$selected_index]}"
  video_url="https://www.youtube.com/watch?v=$video_id"

  [ "$copy_mode" == "true" ] && {
    clip "$video_url"
  }

  local video_duration video_author video_views video_published video_thumbnail
  video_duration=$(echo "$json_data" | jq -r ".[$selected_index].duration")
  video_author=$(echo "$json_data" | jq -r ".[$selected_index].author")
  video_views=$(echo "$json_data" | jq -r ".[$selected_index].views")
  video_published=$(echo "$json_data" | jq -r ".[$selected_index].published")
  video_thumbnail=$(echo "$json_data" | jq -r ".[$selected_index].thumbnail")

  img_path="$TMPDIR/thumb_$video_id.jpg"

  # Update history and perform action
  add_to_history "$video_id" "$selected_title" "$video_duration" "$video_author" "$video_views" "$video_published" "$video_thumbnail"
  STATE="PLAY"
}

#=============================================================================
# SEARCH AND SELECTION
#=============================================================================

get_search_query() {
  if [[ -z "$query" ]]; then
    if [[ "$use_rofi" = true ]]; then
      query=$(rofi -dmenu -p "Enter YouTube search:")
    else
      read -rp "Enter YouTube search(empty to exit): " query
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

  json_data=$(curl -s --compressed --http1.1 --keepalive-time 30 "https://www.youtube.com/results?search_query=${encoded_query}&sp=EgIQAQ%253D%253D&hl=en&gl=US" \
    | perl -0777 -ne 'print $1 if /var ytInitialData = (.*?);\s*<\/script>/s'\
    | jq -r --argjson limit "$limit" "
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
      ] | .[:$limit]
      " 2>/dev/null)

  echo "$json_data" >"$cache_file"
  echo "$json_data"

}

create_preview_script_fzf() {
  local is_history="${1:-false}"

  cat <<'EOF'
printf "\033[H\033[J"
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
    printf 'echo -e "\033[1;35mFrom History\033[0m" \n'
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
        [[ ! -f "$img_path" ]] && curl -fsSL --compressed --http1.1 --keepalive-time 30 "$thumbnail" -o "$img_path" 2>/dev/null
        img_h=$((FZF_PREVIEW_LINES - 10))
        img_w=$((FZF_PREVIEW_COLUMNS - 4))
        img_h=$(( img_h < 10 ? 10 : img_h ))
        img_w=$(( img_w < 20 ? 20 : img_w ))
        chafa --symbols=block --size="${img_w}x${img_h}" "$img_path" 2>/dev/null || echo "(failed to render thumbnail)"

    else
        echo "(chafa not available - no thumbnail preview)"
    fi
    echo
else
    echo "No preview available"
fi
EOF
}

select_with_rofi_drun() {
  rofi_out=$(rofi -show drun -drun-categories ytsurf -filter "" -show-icons)
  echo "$rofi_out"
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
  if [[ "$use_sentaku" == true ]] && command -v sentaku &>/dev/null; then
    selected_item=$(printf "%s\n" "${menu_items[@]}" | sed 's/ /␣/g' | sentaku)
    selected_item=${selected_item//␣/ }

  elif command -v fzf &>/dev/null; then
    local preview_script
    preview_script=$(create_preview_script_fzf "$is_history")

    selected_item=$(printf "%s\n" "${menu_items[@]}" | fzf \
      --prompt="$prompt" \
      --preview="bash -c '$preview_script' -- {n}")
  fi
  echo "$selected_item"
}

handle_selection() {
  [[ "$feed_mode" == "true" ]] && {
    json_data=$(fetch_feed)
    [[ "$json_data" == "[]" ]] && {
      send_notification "Error" "Failed to fetch your feed"
      exit 1
    }
  }
  [[ "$feed_mode" == "true" ]] || {
     get_search_query
     json_data=$(fetch_search_results "$query") || {
        send_notification "Error" "Failed to fetch search results for '$query'"
        exit 1
     }
  } 

  local menu_list=()
  mapfile -t menu_list < <(echo "$json_data" | jq -r '.[].title' 2>/dev/null)

  if [[ "$use_rofi" == true ]]; then
    create_desktop_entries "$json_data"
    selected_title=$(select_with_rofi_drun)
    rm -rf "$TMPDIR/applications"

  else
      [ ${#menu_list[@]} -eq 0 ] && {
      send_notification "Error" "No results found for '$query'"
      exit 0
    }
    selected_title=$(select_from_menu "${menu_list[@]}" "Search YouTube:" "$json_data" false)
  fi

  [ -n "$selected_title" ] || {
    send_notification "Error" "No selection made."
    exit 1
  }

  local selected_index=-1
  for i in "${!menu_list[@]}"; do
    [ "${menu_list[$i]}" == "$selected_title" ] && {
      selected_index=$i
      break
    }
  done

  [ "$selected_index" -lt 0 ] && {
    send_notification "Error" " could not resolve selected video."
    exit 1
  }

  # Extract video details
  local video_id video_author video_duration video_views video_published video_thumbnail
  video_id=$(echo "$json_data" | jq -r ".[$selected_index].id")
  video_url="https://www.youtube.com/watch?v=$video_id"
  video_author=$(echo "$json_data" | jq -r ".[$selected_index].author")
  video_duration=$(echo "$json_data" | jq -r ".[$selected_index].duration")
  video_views=$(echo "$json_data" | jq -r ".[$selected_index].views")
  video_published=$(echo "$json_data" | jq -r ".[$selected_index].published")
  video_thumbnail=$(echo "$json_data" | jq -r ".[$selected_index].thumbnail")

  [ "$copy_mode" == "true" ] && {
    clip "$video_url"
  }

  img_path="$TMPDIR/thumb_$video_id.jpg"
  # Add to history and perform action
  add_to_history "$video_id" "$selected_title" "$video_duration" "$video_author" "$video_views" "$video_published" "$video_thumbnail"
  STATE="PLAY"
}

select_init(){
  local chosen_action
  local prompt="Select Action:"
  local header="Available Actions"
  local items=("Search_youtube" "Manage_subscriptions" "Open_your_feed" "View_your_history")

  if [[ "$use_rofi" == true ]]; then
    chosen_action=$(printf "%s\n" "${items[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
  elif [[ "$use_sentaku" == true ]]; then
    chosen_action=$(printf "%s\n" "${items[@]}" | sentaku)
  else
    chosen_action=$(printf "%s\n" "${items[@]}" | fzf --prompt="$prompt" --header="$header")
  fi

  if [[ "$chosen_action" == "Manage_subscriptions" ]]; then
    sub_mode="true"
  elif [[ "$chosen_action" == "Open_your_feed" ]]; then
    feed_mode="true"
  elif [[ "$chosen_action" == "View_your_history" ]]; then
    history_mode="true"
  elif [[ "$chosen_action" == "Search_youtube" ]]; then
    STATE="SEARCH"
  else
    send_notification "Error" "no selection made"
    exit 1
  fi
}

# MAIN EXECUTION
main() {
  STATE="SEARCH"
  [[ "$history_mode" != "true" && "$sub_mode" != "true" && "$feed_mode" != "true" && -z "$query" ]] && select_init
  [ "$history_mode" == "true" ] && STATE="HISTORY"
  [ "$sub_mode" == "true" ] && STATE="SUB"
  while :; do
    case "$STATE" in
    SEARCH) handle_selection ;;
    SUB) manage_subscriptions ;;
    PLAY) perform_action ;;
    HISTORY) handle_history ;;
    EXIT) break ;;
    *) break ;;
    esac
  done
}

# Run main function with all arguments
configuration
setup_cleanup
check_dependencies
parse_arguments "$@"
main
