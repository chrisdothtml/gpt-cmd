#!/usr/bin/env bash

set -e

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
else
  OS="unknown"
fi

ansi_blue='\033[94m'
ansi_green='\033[92m'
ansi_red='\033[91m'
ansi_yellow='\033[93m'
ansi_reset='\033[0m'

function print_blue() {
  printf "${ansi_blue}%b${ansi_reset}" "$1"
}
function print_green() {
  printf "${ansi_green}%b${ansi_reset}" "$1"
}
function print_red() {
  printf "${ansi_red}%b${ansi_reset}" "$1"
}
function print_yellow() {
  printf "${ansi_yellow}%b${ansi_reset}" "$1"
}

function log_error() {
  print_red "ERROR: ${1}\n"
}
function log_warning() {
  print_yellow "WARNING: ${1}\n"
}

function fetch_latest_binary() {
  local github_repo="$1"
  local dir_path="$2"
  local binary_name="$3"

  # detect which fetch tool is available on the machine
  local fetch_tool
  if command -v curl >/dev/null; then
    fetch_tool="curl"
  elif command -v wget >/dev/null; then
    fetch_tool="wget"
  else
    log_error "No suitable download tool found (curl, wget)"
    exit 1
  fi

  # get list of latest releases from GitHub
  local releases_url="https://api.github.com/repos/$github_repo/releases"
  local releases_res
  case $fetch_tool in
    curl)
      releases_res="$(curl -s "$releases_url")";;
    wget)
      releases_res="$(wget -qO- "$releases_url")";;
  esac

  # get binary url from latest release for this OS
  local latest_version="$( \
    echo "$releases_res" \
      | grep '"tag_name"' \
      | sed -E 's/.*"tag_name": "(.*)",/\1/' \
      | head -1 \
  )"
  local binary_urls="$( \
    echo "$releases_res" \
      | grep "releases/download/$latest_version/gpt_cmd-" \
      | sed -E 's/[ \t]+"browser_download_url": "([^"]+)",?/\1/' \
  )"
  local latest_binary_url=""
  for url in $binary_urls; do
    os="$(echo "$url" | sed -E 's|.*/gpt_cmd-([^.]*).*|\1|')"
    if [ "$os" = "$OS" ]; then
      latest_binary_url="$url"
      break
    fi
  done
  if [ -z "$latest_binary_url" ]; then
    local error_file_name="gpt_cmd_install-error_$(date +"%Y-%m-%d_%H-%M-%S").log"
    echo -e "ERROR: unable to find release binary\n" >> "$error_file_name"
    echo -e "GitHub releases response body:\n$releases_res" >> "$error_file_name"

    log_error "unable to find release binary; see $error_file_name for more info"
    exit 1
  fi

  # fetch the binary
  local file_name="$(basename "$latest_binary_url")"
  local file_path="$dir_path/$file_name"
  case $fetch_tool in
    curl)
      curl -L -s -S -o "$file_path" "$latest_binary_url";;
    wget)
      wget -q -O "$file_path" "$latest_binary_url";;
  esac
  if [ ! -e "$file_path" ]; then
    log_error "failed to fetch latest release tarball ($latest_binary_url)"
    exit 1
  fi

  # rename binary file
  mv "$file_path" "$dir_path/$binary_name"
}

function make_binary_executable() {
  local file_path="$1"

  chmod +x "$file_path"

  # try to make MacOS trust the binary file
  if [ "$OS" = "macos" ]; then
    if command -v xattr >/dev/null; then
      if xattr -p com.apple.quarantine "$file_path" &>/dev/null; then
        xattr -d com.apple.quarantine "$file_path"
      fi
    else
      log_warning "Unable to update MacOS to trust binary. You may need to manually do so"
      echo "(right click and click open on the binary file: $file_path)"
    fi
  fi
}

function get_profile_file() {
  local files=".zshrc .bash_profile .bashrc .profile"

  local full_path
  for file in $files; do
    full_path="$HOME/$file"

    # use .profile as default if none others exist
    if [ -e "$full_path" ] || [ $file = ".profile" ]; then
      echo "$full_path"
      return 0
    fi
  done
}

function run_install() {
  if [ "$OS" = "unknown" ]; then
    log_error "OS type '$OSTYPE' not recognized as a supported OS"
    exit 1
  fi

  local install_dir="$HOME/.gpt_cmd"
  echo "Installing to ${install_dir}"

  print_blue "Attempting to fetch latest binary..."
  local repo_name="chrisdothtml/gpt-cmd"
  local binary_dir_path="$install_dir/bin"
  local binary_name="gpt_cmd"
  mkdir -p "$binary_dir_path"
  fetch_latest_binary "$repo_name" "$binary_dir_path" "$binary_name"
  echo "✅"

  print_blue "Making binary executable on your system..."
  local binary_file_path="$binary_dir_path/$binary_name"
  make_binary_executable "$binary_file_path"
  echo "✅"

  local path_update_str="export PATH=\"${binary_dir_path}:\$PATH\""
  local profile_file
  if ! command -v gpt_cmd >/dev/null; then
    profile_file="$(get_profile_file)"
    print_blue "Exposing binary to PATH..."
    echo -e "\n$path_update_str" >> "$profile_file"
    echo "✅"
  fi

  print_green "\n✅ gpt_cmd installed successfully!\n"
  if [ -n "$profile_file" ]; then
    print_yellow "\nYour PATH was updated via ${profile_file}. Open a new terminal and run 'gpt_cmd --help' to make sure it worked.\n"
  fi
  print_yellow "\nIf \`gpt_cmd\` isn't found, add this to a profile file your terminal recognizes:\n"
  echo -e "\n  $path_update_str\n"
}

# if either executed directly, or executed directly from GitHub URL
# (this is so that the utils in this file can be imported by the other bash scripts)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [ -z "${BASH_SOURCE[0]}" ]; then
  run_install
fi
