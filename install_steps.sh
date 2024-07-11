#!/bin/bash
# Arch Linux Installation Script - Installation Steps

# Display warnings and get user confirmation
display_warnings() {
  log "WARN" "This script will partition and format the target disk."
  log "WARN" "ALL DATA ON THE TARGET DISK WILL BE LOST!"
  log "WARN" "Make sure you have backed up any important data before proceeding."
}

get_user_confirmation() {
  read -r -p "Do you understand and wish to proceed? (y/N): " confirm
  [[ $confirm =~ ^[Yy]$ ]]
}

# Gather system information
check_info() {
  local confirmed=false

  while [[ ! $confirmed ]]; do
    locale=$(prompt_user "Enter desired locale" "locale" "$DEFAULT_LOCALE")
    keymap=$(prompt_user "Enter desired keymap" "keymap" "$DEFAULT_KEYMAP")
    log "INFO" "Displaying available disks"
    lsblk

    target_disk=$(prompt_user "Enter the target disk" "disk" "$DEFAULT_DISK")
    username=$(prompt_user "Enter desired username" "username" "$DEFAULT_USERNAME")
    timezone=$(prompt_user "Enter your timezone" "timezone" "$DEFAULT_TIMEZONE")
    hostname=$(prompt_user "Enter desired hostname" "hostname" "$DEFAULT_HOSTNAME")

    total_size=$(lsblk -bdno SIZE /dev/"$target_disk" | awk '{print int($1/1024/1024/1024)}')
    ram_size=$(free -g | awk '/^Mem:/{print $2}')
    swap_size=$(prompt_user "Enter size for swap partition in GB" "partition_size" "$((ram_size + 2))" "$total_size")
    root_size=$(prompt_user "Enter size for root partition in GB" "partition_size" "$DEFAULT_ROOT_SIZE" "$((total_size - swap_size))")
    home_size=$((total_size - swap_size - root_size))

    log "INFO" "Please confirm your selections:"
    log "INFO" "Locale: $locale"
    log "INFO" "Keyboard layout: $keymap"
    log "INFO" "Target disk: /dev/$target_disk (${total_size}GB)"
    log "INFO" "Username: $username"
    log "INFO" "Timezone: $timezone"
    log "INFO" "Hostname: $hostname"
    log "INFO" "Swap size: ${swap_size}GB"
    log "INFO" "Root size: ${root_size}GB"
    log "INFO" "Home size: ${home_size}GB (remaining space)"

    read -r -p "Are these correct? (y/n/q): " confirm
    case "$confirm" in
    y) confirmed=true ;;
    n) log "INFO" "Please review and enter the correct information" ;;
    *)
      log "ERROR" "Exiting script by user input."
      exit 1
      ;;
    esac
  done
}

# Prepare the installation
prepare_installation() {
  disk_partition
  lvm_setup
  disk_formatting
  btrfs_setup
  mount_fs
}

# Install the base system
install_base_system() {
  install_base_packages
  generate_fstab
}

# Finalize the installation
finalize_installation() {
  configure_system
  set_user_password
}
