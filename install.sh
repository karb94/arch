#!/usr/bin/env bash

if [[ $# -eq 0 ]]
then
    echo "Device name is required as a first argument"
    lsblk
    exit 0
fi

device=$1

# Update the system clock
timedatectl set-ntp true

# Partition the disk
sfdisk -W always /dev/${device} << EOF
label: gpt
name=root, size=15GiB, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
name=swap, size=2GiB, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
name=boot, size=300MiB, type=21686148-6449-6E6F-744E-656564454649
name=home, type=933AC7E1-2EB4-4F13-B844-0E14E2AEF915
EOF

# Creating file systems
mkfs.ext4 /dev/${device}1
mkswap /dev/${device}2
swapon /dev/${device}2
mkfs.ext4 /dev/${device}3
mkfs.ext4 /dev/${device}4


# Mounting root file system
mount /dev/${device}1 /mnt
# Creating mounting points on /mnt
mkdir /mnt/boot
mkdir /mnt/home
# Mounting boot and home file systems
mount /dev/${device}3 /mnt/boot
mount /dev/${device}4 /mnt/home

# Create minimal syste in /mnt by bootstrapping
pacstrap /mnt base linux-zen linux-firmware

# Create fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Change root to /mnt
arch-chroot /mnt
