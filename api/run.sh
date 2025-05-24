#!/usr/bin/env bash

set -euo pipefail

# Constants
PFX_FILE="cert.pfx"
CRT_FILE="cert.crt"
KEY_FILE="cert.key"

# Load environment variables
if [[ -f api.env ]]; then
    echo "Loading environment variables from api.env"
    set -o allexport
    source api.env
    set +o allexport
else
    echo "Error: api.env file not found. Please provide it with PFX_PASSWORD set."
    exit 1
fi

# Validate required variable
if [[ -z "${PFX_PASSWORD:-}" ]]; then
    echo "Error: PFX_PASSWORD is not set in api.env."
    exit 1
fi

# Helper function
install_package() {
    if ! command -v "$1" &> /dev/null; then
        echo "Installing missing dependency: $1"
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y "$2"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "$2"
        elif command -v pacman &> /dev/null; then
            sudo pacman -Sy --noconfirm "$2"
        else
            echo "Unsupported package manager. Please install $1 manually."
            exit 1
        fi
    fi
}

# Check required tools
install_package curl curl
install_package openssl openssl
install_package docker docker.io
install_package docker-compose docker-compose # fallback for systems without plugin

# Ensure docker compose is available as plugin or standalone
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Docker Compose not found. Please install it manually."
    exit 1
fi

# Argument check
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [install|update]"
    exit 1
fi

if [[ $1 == "install" ]]; then
    echo "Start installing Docker ..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    echo "Docker installed successfully."

    # Extract certs if needed
    if [[ ! -f "$CRT_FILE" || ! -f "$KEY_FILE" ]]; then
        if [[ -f "$PFX_FILE" ]]; then
            echo "Extracting certificate and key from $PFX_FILE ..."
            openssl pkcs12 -in "$PFX_FILE" -clcerts -nokeys -out "$CRT_FILE" -passin pass:"$PFX_PASSWORD"
            openssl pkcs12 -in "$PFX_FILE" -nocerts -nodes -out "$KEY_FILE" -passin pass:"$PFX_PASSWORD"
            echo "Certificate and key extracted."
        else
            echo "Error: $PFX_FILE not found, and $CRT_FILE / $KEY_FILE are missing."
            exit 1
        fi
    fi

    docker compose up -d
    echo "Installed and started ClassInsights API"

elif [[ $1 == "update" ]]; then
    docker compose pull
    docker compose up -d
    echo "Updated ClassInsights API"

else
    echo "Invalid argument. Usage: $0 [install|update]"
    exit 1
fi