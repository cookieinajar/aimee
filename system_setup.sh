#!/bin/bash
# Arch Linux Installation Script - System Setup Functions

# Declare variables used in this script but defined elsewhere
declare timezone
declare locale
declare keymap
declare hostname
declare username
declare target_disk

# Install base packages
install_base_packages() {
  log "INFO" "Installing base system and essential packages"

  # Detect CPU type
  if grep -q "GenuineIntel" /proc/cpuinfo; then
    log "INFO" "Intel CPU detected"
    ucode="intel-ucode"
  elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    log "INFO" "AMD CPU detected"
    ucode="amd-ucode"
  else
    log "WARN" "Unable to determine CPU type. Installing both Intel and AMD microcode."
    ucode="intel-ucode amd-ucode"
  fi

  if pacstrap -c -j "$(nproc)" /mnt "${BASE_PACKAGES[@]}" "$ucode"; then
    log "INFO" "Base packages installed successfully"
  else
    log "ERROR" "Failed to install base packages"
    return 1
  fi
}

# Generate fstab
generate_fstab() {
  log "INFO" "Generating fstab"
  if genfstab -U /mnt >>/mnt/etc/fstab; then
    log "INFO" "fstab generated successfully"
  else
    log "ERROR" "Failed to generate fstab"
    return 1
  fi
}

# Helper function to run commands in chroot
run_in_chroot() {
  local command="$1"
  local error_message="Failed to execute: $command"
  if ! arch-chroot /mnt /bin/bash -c "$command"; then
    log "ERROR" "$error_message"
    return 1
  fi
}

# Set timezone
set_timezone() {
  log "INFO" "Setting timezone to $timezone"
  run_in_chroot "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime && hwclock --systohc" || return 1
}

# Set locale
set_locale() {
  log "INFO" "Setting locale to $locale"
  run_in_chroot "echo '$locale UTF-8' >> /etc/locale.gen && locale-gen && echo 'LANG=$locale' > /etc/locale.conf" || return 1
}

# Set keymap
set_keymap() {
  log "INFO" "Setting keymap to $keymap"
  run_in_chroot "echo 'KEYMAP=$keymap' > /etc/vconsole.conf" || return 1
}

# Set hostname
set_hostname() {
  log "INFO" "Setting hostname to $hostname"
  run_in_chroot "echo '$hostname' > /etc/hostname" || return 1
  run_in_chroot "echo '127.0.0.1 localhost' >> /etc/hosts" || return 1
  run_in_chroot "echo '::1       localhost' >> /etc/hosts" || return 1
  run_in_chroot "echo '127.0.1.1 $hostname.localdomain $hostname' >> /etc/hosts" || return 1
}

# Create user
create_user() {
  log "INFO" "Creating user $username"
  run_in_chroot "useradd -m -G wheel $username" || return 1
  run_in_chroot "echo '$username ALL=(ALL) ALL' >> /etc/sudoers.d/$username" || return 1
}

# Configure sudo
configure_sudo() {
  log "INFO" "Configuring sudo"
  run_in_chroot "sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers" || return 1
}

# Disable root login
disable_root() {
  log "INFO" "Disabling root login"
  run_in_chroot "passwd -l root" || return 1
}

# Install and configure bootloader
setup_bootloader() {
  log "INFO" "Setting up bootloader"
  run_in_chroot "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB" || return 1
  if [ "$UEFI_BOOT" = true ]; then
    run_in_chroot "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB" || return 1
  else
    run_in_chroot "grub-install --target=i386-pc /dev/$target_disk" || return 1
  fi
  run_in_chroot "sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet resume=\/dev\/vg0\/swap\"/' /etc/default/grub" || return 1
  run_in_chroot "sed -i 's/MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf" || return 1
  run_in_chroot "sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block lvm2 filesystems keyboard resume fsck)/' /etc/mkinitcpio.conf" || return 1
  run_in_chroot "mkinitcpio -P" || return 1
  run_in_chroot "grub-mkconfig -o /boot/grub/grub.cfg" || return 1
}

# Enable services
enable_services() {
  log "INFO" "Enabling services"
  run_in_chroot "systemctl enable NetworkManager" || return 1
  run_in_chroot "systemctl enable ntpd" || return 1
}

# Configure zram
configure_zram() {
  log "INFO" "Configuring zram"
  run_in_chroot "echo -e '[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd\nswap-priority = 100\nfs-type = swap' > /etc/systemd/zram-generator.conf" || return 1
  run_in_chroot "echo '/dev/vg0/swap none swap defaults,pri=0 0 0' >> /etc/fstab" || return 1
}

# Configure system
configure_system() {
  log "INFO" "Configuring system"
  set_timezone || return 1
  set_locale || return 1
  set_keymap || return 1
  set_hostname || return 1
  create_user || return 1
  configure_sudo || return 1
  disable_root || return 1
  setup_bootloader || return 1
  enable_services || return 1
  configure_zram || return 1
  log "INFO" "System configuration completed successfully"
}

# Set user password
set_user_password() {
  log "INFO" "Setting password for $username"
  local password_set=false
  local attempts=0
  while ! $password_set && [ $attempts -lt 3 ]; do
    if run_in_chroot "passwd $username"; then
      password_set=true
      log "INFO" "User password set successfully"
    else
      attempts=$((attempts + 1))
      log "WARN" "Password setting failed. Attempt $attempts of 3."
    fi
  done
  if ! $password_set; then
    log "ERROR" "Failed to set user password after 3 attempts"
    return 1
  fi
}
