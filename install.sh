#!/usr/bin/env bash

set -e

ansi_blue='\033[94m'
ansi_green='\033[92m'
ansi_red='\033[91m'
ansi_reset='\033[0m'

function log_blue() {
  echo -e "${ansi_blue}$1${ansi_reset}"
}

function log_green() {
  echo -e "${ansi_green}$1${ansi_reset}"
}

function log_red() {
  echo -e "${ansi_red}$1${ansi_reset}"
}

function fetch_latest_tarball() {
  local github_repo="$1"
  local file_path="$2"

  # detect which fetch tool is available on the machine
  local fetch_tool
  if command -v curl >/dev/null; then
    fetch_tool="curl"
  elif command -v wget >/dev/null; then
    fetch_tool="wget"
  else
    log_red "ERROR: No suitable download tool found (curl, wget)" >&2
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

  # parse out the latest release's tarball url
  local latest_tarball_url="$( \
    echo "$releases_res" \
      | grep '"tarball_url"' \
      | sed -E 's/.*"tarball_url": "(.*)",/\1/' \
      | head -1 \
  )"
  if [ -z "$latest_tarball_url" ]; then
    local error_file_name="gpt_cmd_install-error_$(date +"%Y-%m-%d_%H-%M-%S").log"
    echo -e "ERROR: unable to find release tarball\n" >> "$error_file_name"
    echo -e "GitHub releases response body:\n$releases_res" >> "$error_file_name"

    log_red "ERROR: unable to find release tarball; see $error_file_name for more info" >&2
    exit 1
  fi

  # fetch the tarball
  case $fetch_tool in
    curl)
      curl -L -o "$file_path" "$latest_tarball_url";;
    wget)
      wget -O "$file_path" "$latest_tarball_url";;
  esac
  if [ ! -e "$file_path" ]; then
    log_red "ERROR: failed to fetch latest release tarball ($latest_tarball_url)" >&2
    exit 1
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
  local base_install_dir="${GPT_CMD_INSTALL_DIR:-$HOME}"
  local install_dir="$base_install_dir/gpt_cmd"
  log_blue "Installing gpt_cmd to ${base_install_dir}..."

  # check for previous installation
  local prev_install_exists="false"
  local convos_dir_path="$install_dir/.convos"
  local convos_backup_dir_path="$base_install_dir/.convos-backup"
  if [ -e "$install_dir" ]; then
    prev_install_exists="true"

    # backup convos dir
    if [ -e "$convos_dir_path" ]; then
      echo ""
      log_blue "Existing installation detected; preserving convos dir..."
      mv "$convos_dir_path" "$convos_backup_dir_path"
    fi

    rm -rf "$install_dir"
  fi

  mkdir -p "$install_dir"
  cd "$install_dir"

  echo ""
  log_blue "Attempting to fetch latest release..."
  local tarball_file_name="gpt_cmd.tar.gz"
  fetch_latest_tarball "chrisdothtml/gpt-cmd" "$tarball_file_name"

  echo ""
  log_blue "Expanding tarballs..."
  # untar repo
  tar -xzf "$tarball_file_name" --strip-components=1
  rm -rf "$tarball_file_name"
  # untar vendored dependencies
  tar -xzf vendor.tar.gz
  rm -rf vendor.tar.gz

  if [ -e "$convos_backup_dir_path" ]; then
    echo ""
    log_blue "Restoring backed-up convos dir..."
    mv "$convos_backup_dir_path" "$convos_dir_path"
  fi

  local path_update_str="export PATH=\"${install_dir}/bin:\$PATH\""
  local profile_file
  if ! command -v gpt_cmd >/dev/null; then
    profile_file="$(get_profile_file)"
    echo ""
    log_blue "Updating ${profile_file}..."
    echo -e "\n$path_update_str" >> "$profile_file"
  fi

  echo ""
  log_green "✅ Done!"

  if [ -n "$profile_file" ]; then
    echo ""
    log_blue "\$PATH was updated via ${profile_file}. Open a new terminal and run 'gpt_cmd --help' to make sure it worked."
  fi
  echo ""
  log_blue "If \`gpt_cmd\` isn't found, add this to a profile file your terminal recognizes:"
  echo -e "\n  $path_update_str\n"
}

# if either executed directly, or executed directly from GitHub URL
# (this is so that the utils in this file can be imported by the other bash scripts)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [ -z "${BASH_SOURCE[0]}" ]; then
  run_install
fi
