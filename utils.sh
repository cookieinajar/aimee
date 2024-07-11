#!/bin/bash
# Arch Linux Installation Script - Utility Functions

# Logging function
log() {
  local level="$1"
  local message="$2"
  local line_no="${BASH_LINENO[0]}"
  local file_name="$(basename "${BASH_SOURCE[1]}")"
  local color=""
  local prefix=""

  case "$level" in
  DEBUG)
    color="$BLUE"
    prefix="[DEBUG]"
    ;;
  INFO)
    color="$GREEN"
    prefix="[INFO]"
    ;;
  WARN)
    color="$YELLOW"
    prefix="[WARN]"
    ;;
  ERROR)
    color="$RED"
    prefix="[ERROR]"
    ;;
  FATAL)
    color="$RED"
    prefix="[FATAL]"
    ;;
  *)
    color="$NC"
    prefix="[$level]"
    ;;
  esac

  # Log to file with timestamp, filename, and line number
  local log_message
  log_message="$(date '+%Y-%m-%d %H:%M:%S') $prefix $message (File: $file_name, Line: $line_no)"

  # Append to log file
  if ! echo "$log_message" >>"$LOG_FILE"; then
    echo "Failed to write to log file: $LOG_FILE" >&2
  fi

  # Print to console without timestamp
  local console_message="$prefix $message"
  if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
    console_message+=" (File: $file_name, Line: $line_no)"
  fi
  printf "%b%s%b\n" "${color}" "${console_message}" "${NC}" >&2

  if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
    cleanup
    exit 1
  fi
}

# Error handler
error_handler() {
  local err_code="$1"
  local line_no="$2"
  log "ERROR" "An error occurred with exit code $err_code" "$line_no"
}

# Cleanup function
cleanup() {
  log "INFO" "Performing cleanup..."
  if mountpoint -q /mnt; then
    umount -R /mnt || log "WARN" "Failed to unmount /mnt"
  fi
  if vgdisplay vg0 &>/dev/null; then
    vgchange -an vg0 || log "WARN" "Failed to deactivate LVM"
  fi
  log "INFO" "Cleanup completed"
}

# Log rotation
rotate_log() {
  if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt $LOG_MAX_SIZE ]]; then
    local i=1
    while [[ -f "${LOG_FILE}.${i}" ]]; do
      ((i++))
    done
    mv "$LOG_FILE" "${LOG_FILE}.${i}"
    touch "$LOG_FILE"
    log "INFO" "Log file rotated to ${LOG_FILE}.${i}"
  fi
}

# Input validation
validate_input() {
  local input_type="$1"
  local value="$2"
  local extra_param="${3:-}"

  case "$input_type" in
  disk)
    [[ -b "/dev/$value" ]] || {
      echo "Invalid disk: /dev/$value does not exist"
      return 1
    }
    ;;
  username)
    [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]] || {
      echo "Invalid username format"
      return 1
    }
    ;;
  timezone)
    [[ -f "/usr/share/zoneinfo/$value" ]] || {
      echo "Invalid timezone: $value"
      return 1
    }
    ;;
  hostname)
    [[ "$value" =~ ^[a-zA-Z0-9-]+$ ]] || {
      echo "Invalid hostname format"
      return 1
    }
    ;;
  partition_size)
    [[ "$value" =~ ^[0-9]+$ ]] || {
      echo "Invalid partition size: must be a number"
      return 1
    }
    ((value > 0 && value <= extra_param)) || {
      echo "Invalid partition size: must be between 1 and $extra_param"
      return 1
    }
    ;;
  locale)
    locale -a | grep -q "^$value" || {
      echo "Invalid locale: $value"
      return 1
    }
    ;;
  keymap)
    if ! compgen -G "/usr/share/kbd/keymaps/**/$value.map.gz" >/dev/null; then
      echo "Invalid keymap: $value"
      return 1
    fi
    ;;
  *)
    echo "Unknown input type: $input_type"
    return 1
    ;;
  esac
  return 0
}

# User input prompt
prompt_user() {
  local prompt="$1"
  local input_type="$2"
  local default="$3"
  local extra_param="${4:-}"

  while true; do
    read -r -p "$prompt [$default]: " response
    response=${response:-$default}
    if validate_input "$input_type" "$response" "$extra_param"; then
      echo "$response"
      return 0
    fi
    log "WARN" "Invalid input. Please try again."
  done
}
