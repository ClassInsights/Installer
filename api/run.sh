#!/usr/bin/env bash

set -euo pipefail

# Constants
PFX_FILE="cert.pfx"
CRT_FILE="cert.crt"
KEY_FILE="cert.key"
ENV_FILE="api.env"

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    echo "Loading environment variables from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
    # Trim whitespace from PFX_PASSWORD
    PFX_PASSWORD="${PFX_PASSWORD#${PFX_PASSWORD%%[![:space:]]*}}"
    PFX_PASSWORD="${PFX_PASSWORD%%${PFX_PASSWORD##*[![:space:]]}}"
else
    echo "Error: $ENV_FILE not found. Please provide it with PFX_PASSWORD set."
    exit 1
fi

# Validate required variable
if [[ -z "${PFX_PASSWORD:-}" ]]; then
    echo "Error: PFX_PASSWORD is not set in $ENV_FILE."
    exit 1
fi

# Detect distro
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)

# Install Docker packages via OS-native or Docker repo
install_docker_packages() {
    case "$DISTRO" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg lsb-release
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg \
                | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
              https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" \
              | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        centos|rhel|fedora)
            sudo dnf -y install yum-utils device-mapper-persistent-data lvm2
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        arch)
            sudo pacman -Sy --noconfirm docker docker-compose
            ;;

        *)
            echo "Unsupported distro: $DISTRO. Please install Docker manually."
            exit 1
            ;;
    esac
}

# Ensure Docker service is enabled and running
enable_docker_service() {
    sudo systemctl enable docker
    sudo systemctl start docker
}

# Extract certificates
extract_certs() {
    if [[ ! -f "$CRT_FILE" || ! -f "$KEY_FILE" ]]; then
        if [[ -f "$PFX_FILE" ]]; then
            echo "Extracting certificate and key from $PFX_FILE"
            openssl pkcs12 -in "$PFX_FILE" -clcerts -nokeys -out "$CRT_FILE" -passin pass:"$PFX_PASSWORD"
            openssl pkcs12 -in "$PFX_FILE" -nocerts -nodes -out "$KEY_FILE" -passin pass:"$PFX_PASSWORD"
            echo "Extraction complete."
        else
            echo "Error: $PFX_FILE not found and no existing certs present."
            exit 1
        fi
    else
        echo "Certificates already exist. Skipping extraction."
    fi
}

# Ensure Docker is installed before attempting install
ensure_docker_installed() {
    if ! command -v docker &> /dev/null; then
        echo "Docker not found. Proceeding with installation."
        install_docker_packages
        enable_docker_service
    else
        echo "Docker is already installed. Skipping installation."
    fi
}

# Ensure OpenSSL available
ensure_openssl_installed() {
    if ! command -v openssl &> /dev/null; then
        echo "OpenSSL not found. Installing prerequisites."
        install_docker_packages # shares curl and gnupg for repo setup
    fi
}

# Main logic
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 [install|update]"
    exit 1
fi

case "$1" in
    install)
        echo "=== Checking Docker installation ==="
        ensure_docker_installed
        echo "=== Extracting certificates ==="
        ensure_openssl_installed
        extract_certs
        echo "=== Starting services with Docker Compose ==="
        docker compose up -d
        echo "Installation complete."
        ;;

    update)
        echo "=== Pulling latest images ==="
        docker compose pull
        echo "=== Restarting services ==="
        docker compose up -d
        echo "Update complete."
        ;;

    *)
        echo "Invalid argument. Usage: $0 [install|update]"
        exit 1
        ;;

esac
