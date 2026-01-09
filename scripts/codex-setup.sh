#!/usr/bin/env bash
set -euo pipefail

if command -v gh >/dev/null 2>&1; then
  gh --version
  exit 0
fi

sudo apt-get update
sudo apt-get install -y curl gpg

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

sudo apt-get update
sudo apt-get install -y gh

gh --version
