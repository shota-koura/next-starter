#!/usr/bin/env bash
set -euo pipefail

need_apt_update="0"

ensure_pkg() {
  local cmd="$1"
  local pkg="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$need_apt_update" == "0" ]]; then
    sudo apt-get update
    need_apt_update="1"
  fi

  sudo apt-get install -y "$pkg"
}

# tree is a standard repo-structure helper
ensure_pkg "tree" "tree"

# gh (GitHub CLI) install if missing
if command -v gh >/dev/null 2>&1; then
  gh --version
  tree --version
  exit 0
fi

# prerequisites for adding GitHub CLI apt repo
ensure_pkg "curl" "curl"
ensure_pkg "gpg" "gpg"

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

sudo apt-get update
sudo apt-get install -y gh

gh --version
tree --version
