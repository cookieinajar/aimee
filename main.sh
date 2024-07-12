#!/bin/bash
# Arch Linux Installation Script - Main Entry Point

# Set strict bash options
set -euo pipefail
[[ "${TRACE:-0}" == "1" ]] && set -x

UEFI_BOOT=false
if [ -d "/sys/firmware/efi" ]; then
  UEFI_BOOT=true
fi
export UEFI_BOOT

# Source other script files
export SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/disk_operations.sh"
source "$SCRIPT_DIR/system_setup.sh"
source "$SCRIPT_DIR/install_steps.sh"

# Set up trap to call cleanup function on exit
trap cleanup EXIT

main() {
  rotate_log
  log "INFO" "Starting Arch Linux installation script"

  log "DEBUG" "About to call display_warnings"
  display_warnings
  log "DEBUG" "About to call get_user_confirmation"
  if ! get_user_confirmation; then
    log "INFO" "Installation cancelled by user. Exiting."
    exit 0
  fi
  log "DEBUG" "About to call check_info"
  check_info || exit 1
  log "DEBUG" "check_info completed successfully"
  prepare_installation || exit 1
  install_base_system || exit 1
  finalize_installation || exit 1

  log "INFO" "Arch Linux installation completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
