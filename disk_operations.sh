#!/bin/bash
# Arch Linux Installation Script - Disk Operations

# Declare variables used in this script but defined elsewhere
declare target_disk
declare swap_size
declare root_size

# Partition the disk
disk_partition() {

  log "INFO" "Partitioning the disk"
  log "DEBUG" "Currently mounted partitions:"
  lsblk_output=$(lsblk -o NAME,MOUNTPOINT)
  log "DEBUG" "$lsblk_output"
  log "DEBUG" "About to partition disk. target_disk=$target_disk"
  if mountpoint -q "/dev/$target_disk"; then
    log "ERROR" "Target disk is currently mounted. Please unmount it before proceeding."
    return 1
  fi
  sgdisk -Z /dev/"$target_disk" || log "ERROR" "Failed to zero out the disk"
  if [ "$UEFI_BOOT" = true ]; then
    # UEFI partitioning
    sgdisk -n 1:0:+"${EFI_PARTITION_SIZE}" -t 1:ef00 -c 1:"EFI System Partition" /dev/"$target_disk"
    # ... rest of UEFI partitioning
  else
    # BIOS partitioning
    sgdisk -n 1:0:+1M -t 1:ef02 -c 1:"BIOS boot partition" /dev/"$target_disk"
    # ... rest of BIOS partitioning
  fi
  sgdisk -n 2:0:0 -t 2:8e00 -c 2:"Linux LVM" /dev/"$target_disk"
}

# Set up LVM
lvm_setup() {
  log "INFO" "Setting up LVM"
  local total_size
  total_size=$(vgs --noheadings -o vg_size --units g vg0 | sed 's/G//')
  if (($(echo "$swap_size + $root_size > $total_size" | bc -l))); then
    log "ERROR" "Not enough space for swap and root partitions"
    return 1
  fi
  pvcreate /dev/"${target_disk}"2
  vgcreate vg0 /dev/"${target_disk}"2
  lvcreate -L "${swap_size}"G vg0 -n swap
  lvcreate -L "${root_size}"G vg0 -n root
  lvcreate -l 100%FREE vg0 -n home
}

# Format partitions
disk_formatting() {
  log "INFO" "Formatting partitions"
  mkfs.fat -F32 /dev/"${target_disk}"1
  mkswap /dev/vg0/swap
  mkfs.btrfs /dev/vg0/root
  mkfs.btrfs /dev/vg0/home
}

# Set up BTRFS subvolumes
btrfs_setup() {
  log "INFO" "Creating and mounting BTRFS subvolumes"
  mount /dev/vg0/root /mnt
  btrfs subvolume create /mnt/@
  umount /mnt
  mount /dev/vg0/home /mnt
  btrfs subvolume create /mnt/@home
  umount /mnt
}

# Mount filesystems
mount_fs() {
  log "INFO" "Mounting filesystems"
  mount -o subvol=@ /dev/vg0/root /mnt || log "ERROR" "Failed to mount root partition"
  mkdir /mnt/home
  mount -o subvol=@home /dev/vg0/home /mnt/home || log "ERROR" "Failed to mount home partition"
  mkdir -p /mnt/boot/efi
  mount /dev/"${target_disk}"1 /mnt/boot/efi || log "ERROR" "Failed to mount efi partition"
  swapon /dev/vg0/swap
}
