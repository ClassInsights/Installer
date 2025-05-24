#!/usr/bin/env bash

set -euo pipefail

# 1) Ensure curl is present; install if needed
if ! command -v curl >/dev/null 2>&1; then
  echo "curl not found. Installing…" >&2
  if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y curl
  elif command -v yum     >/dev/null 2>&1; then sudo yum install -y curl
  elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y curl
  elif command -v pacman  >/dev/null 2>&1; then sudo pacman -Sy --noconfirm curl
  elif command -v brew    >/dev/null 2>&1; then brew install curl
  else
    echo "Error: no supported package manager found to install curl." >&2
    exit 1
  fi
  echo "curl installed successfully." >&2
fi

# 2) Validate mode argument
if [ $# -ne 1 ] || { [ "$1" != "install" ] && [ "$1" != "update" ]; }; then
  cat >&2 <<EOF
Usage: $0 <install|update>
  install   — perform a fresh installation
  update    — update the existing install
EOF
  exit 2
fi
MODE="$1"

# 3) Fetch & execute, forwarding the mode
echo "Running mode: $MODE"
curl -sSL https://raw.githubusercontent.com/classinsights/installer/refs/heads/main/api/run.sh | bash -s -- "$MODE"
