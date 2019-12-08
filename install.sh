#!/usr/bin/env bash

device=$1

# Update the system clock
timedatectl set-ntp true

# Partition the disk
sfdisk -W always /dev/${device} < ptab

# Creating file systems
mkfs.ext4 /dev/${device}1
mkswap /dev/${device}2
swapon /dev/${device}2
mkfs.ext4 /dev/${device}3
mkfs.ext4 /dev/${device}4

# Mounting file systems
mount /dev/${device}1 /mnt
mount /dev/${device}3 /mnt/boot
mount /dev/${device}4 /mnt/home

# Create minimal syste in /mnt by bootstrapping
pacstrap /mnt base linux-zen linux-firmware

# Create fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Change root to /mnt
arch-chroot /mnt
