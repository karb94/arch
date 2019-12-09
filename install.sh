#!/usr/bin/env bash

if [[ $# -eq 0 ]]
then
    echo "Device name is required as a first argument"
    lsblk
    exit 0
fi

device=$1

# Update the system clock
echo "Updating the system clock"
timedatectl set-ntp true

# Partition the disk
echo "Partitioning ${device} disk"
sfdisk -W always /dev/${device} << EOF > install.log 2>&1
label: gpt
name=root, size=15GiB, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
name=swap, size=2GiB, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
name=boot, size=300MiB, type=21686148-6449-6E6F-744E-656564454649
name=home, type=933AC7E1-2EB4-4F13-B844-0E14E2AEF915
EOF

# Creating file systems
echo "Creating file systems"
mkfs.ext4 -L "root" /dev/${device}1 >> install.log 2>&1
mkswap -L "swap" /dev/${device}2 >> install.log 2>&1
swapon /dev/${device}2 >> install.log 2>&1
# With gpt boot partition must not have a file system
# mkfs.ext4 -L "boot" /dev/${device}3 >> install.log 2>&1
mkfs.ext4 -L "home" /dev/${device}4 >> install.log 2>&1


# Mounting root file system
echo "Mounting file systems"
mount /dev/${device}1 /mnt >> install.log 2>&1
# Creating mounting points on /mnt
mkdir /mnt/boot >> install.log 2>&1
mkdir /mnt/home >> install.log 2>&1
# Mounting boot and home file systems
mount /dev/${device}3 /mnt/boot >> install.log 2>&1
mount /dev/${device}4 /mnt/home >> install.log 2>&1

# Select only United Kingdom mirrors
mirrors_url="https://www.archlinux.org/mirrorlist/?country=GB&protocol=https&use_mirror_status=on"
curl -s $mirrors_url | sed -e 's/^#Server/Server/' -e '/^#/d' > /etc/pacman.d/mirrorlist

# Create minimal system in /mnt by bootstrapping
echo "Creating minimal system at /mnt"
pacstrap /mnt base linux-zen linux-firmware grub>> install.log 2>&1

# Create fstab
genfstab -L /mnt >> /mnt/etc/fstab

# Create new script inside the new root
echo "Generating new script for chroot"
cat <<EOF > /mnt/chroot.sh
#!/usr/bin/env bash

# Set time zone
ln -sf /usr/share/zoneinfo/GB /etc/localtime
hwclock --systohc

# Set location
sed -i '/en_GB.UTF-8/s/#//' /etc/locale.gen
#sed -i '/en_US.UTF-8/s/#//' /etc/locale.gen
#sed -i '/es_ES.UTF-8/s/#//' /etc/locale.gen
#sed -i '/ca_ES.UTF-8/s/#//' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

echo "Arch_VV" > /etc/hostname

cat <<EOT > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   Arch_VV.localdomain Arch_VV
EOT

grub-install --target=i386-pc /dev/${device}
grub-mkconfig -o /boot/grub/grub.cfg

passwd

exit
EOF
chmod u+x /mnt/chroot.sh

# Change root to /mnt
echo "Changing root to /mnt"
echo "Configuring system"
arch-chroot /mnt /chroot.sh

rm /mnt/chroot.sh

umount -R /mnt

reboot
