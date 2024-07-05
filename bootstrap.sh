#!/bin/bash
# AIMEE Bootstrap Script

set -euo pipefail
[[ "${TRACE:-0}" == "1" ]] && set -x

readonly AIMEE_DIR="/tmp/aimee_installer"
readonly LOGS_DIR="${AIMEE_DIR}/logs"
readonly LOG_FILE="${LOGS_DIR}/aimee_bootstrap.log"
readonly REPO_URL="https://github.com/yourusername/aimee.git"

# ANSI color codes
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log() {
    local level="$1"
    local message="$2"
    local color=""
    local prefix=""

    case "$level" in
        DEBUG) color="$BLUE"; prefix="[DEBUG]" ;;
        INFO)  color="$GREEN"; prefix="[INFO]" ;;
        WARN)  color="$YELLOW"; prefix="[WARN]" ;;
        ERROR) color="$RED"; prefix="[ERROR]" ;;
        FATAL) color="$RED"; prefix="[FATAL]" ;;
        *)     color="$NC"; prefix="[$level]" ;;
    esac

    printf "%s %s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$prefix" "$message" >> "$LOG_FILE"
    printf "%b%s %s%b\n" "$color" "$prefix" "$message" "$NC" >&2
}

error() {
    log "ERROR" "$1"
    exit 1
}

check_dependencies() {
    if ! command -v git &> /dev/null; then
        log "WARN" "git is not installed. Attempting to install..."
        if pacman -Sy --noconfirm git; then
            log "INFO" "git has been successfully installed."
        else
            error "Failed to install git. Please check your internet connection and try again."
        fi
    else
        log "DEBUG" "git is already installed."
    fi
}

setup_aimee_directory() {
    if [[ -d "$AIMEE_DIR" ]]; then
        log "INFO" "AIMEE directory already exists. Updating..."
        cd "$AIMEE_DIR"
        git pull origin main || error "Failed to update AIMEE repository"
    else
        log "INFO" "Creating AIMEE directory and cloning repository..."
        mkdir -p "$AIMEE_DIR"
        git clone "$REPO_URL" "$AIMEE_DIR" || error "Failed to clone AIMEE repository"
        cd "$AIMEE_DIR"
    fi
}

run_aimee() {
    log "INFO" "Starting AIMEE installation..."
    chmod +x src/main.sh
    if ./src/main.sh; then
        log "INFO" "AIMEE installation completed successfully."
    else
        error "AIMEE installation failed. Check the log file at $LOG_FILE for details."
    fi
}

main() {
    mkdir -p "$LOGS_DIR"
    log "INFO" "AIMEE bootstrap script started"
    check_dependencies
    setup_aimee_directory
    run_aimee
    log "INFO" "AIMEE bootstrap script completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi