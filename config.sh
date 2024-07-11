#!/bin/bash
# Arch Linux Installation Script - Configuration

# Script and log paths
export LOG_FILE="${SCRIPT_DIR}/arch_install.log"
export LOG_MAX_SIZE=$((1024 * 1024)) # 1MB

# ANSI color codes for logging
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Default values
export DEFAULT_LOCALE="en_US.UTF-8"
export DEFAULT_KEYMAP="us"
export DEFAULT_TIMEZONE="UTC"
export DEFAULT_HOSTNAME="archlinux"
export DEFAULT_USERNAME="archuser"
export DEFAULT_DISK="sda"
export DEFAULT_SWAP_SIZE=2  # in GB
export DEFAULT_ROOT_SIZE=20 # in GB
export EFI_PARTITION_SIZE="500M"

# Installation target details (to be set during installation)
export target_disk=""
export username=""
export timezone=""
export hostname=""
export swap_size=""
export root_size=""
export home_size=""
export total_size=""

# System configuration
export UEFI_BOOT=true # Set this based on system detection in main.sh

# Package lists
export BASE_PACKAGES=(
  base
  linux
  linux-firmware
  btrfs-progs
  lvm2
  sudo
  networkmanager
  grub
  efibootmgr
  base-devel
  linux-headers
  ntp
  zram-generator
  micro
)
