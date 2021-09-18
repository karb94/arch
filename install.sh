#!/usr/bin/env bash

ROOT_UUID=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
SWAP_UUID=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
HOME_UUID=933AC7E1-2EB4-4F13-B844-0E14E2AEF915
EFI_UUID=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
BOOT_UUID=21686148-6449-6E6F-744E-656564454649

ROOT_SIZE=5GiB
SWAP_SIZE=200MiB
EFI_SIZE=300MiB
BOOT_SIZE=300MiB

if [[ $# -eq 0 ]]
then
    printf "Device name is required as a first argument\n"
    lsblk
    exit 0
fi

# exit when any command fails
set -E

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

device=$1
log="install.log"


arch_install () {
# Update the system clock
printf "\nUpdating the system clock:\n"
timedatectl set-ntp true

# Partition the disk
printf "\nPartitioning ${device} disk\n"
if ls /sys/firmware/efi/efivars >/dev/null 2>&1
then
  sfdisk -W always /dev/${device} <<EOF
label: gpt
name=root, size="$ROOT_SIZE", type="$ROOT_UUID"
name=swap, size="$SWAP_SIZE", type="$SWAP_UUID"
name=efi, size="$EFI_SIZE", type="$EFI_UUID"
name=home, type="$HOME_UUID"
EOF
  mkfs.fat -n "efi" -F32 $(blkid --uuid "$EFI_UUID")
else
  # With gpt boot partition must not have a file system
  # https://wiki.archlinux.org/title/Partitioning#Example_layouts
  sfdisk -W always /dev/${device} <<EOF
label: gpt
name=root, size="$ROOT_SIZE", type="$ROOT_UUID"
name=swap, size="$SWAP_SIZE", type="$SWAP_UUID"
name=boot, size="$BOOT_SIZE", type="$BOOT_UUID"
name=home, type="$HOME_UUID"
EOF
fi

# Formatting file systems
printf "\nCreating file systems:\n"
mkfs.ext4 -L "root" $(blkid --uuid "$ROOT_UUID")
mkfs.ext4 -L "home" $(blkid --uuid "$HOME_UUID")
mkswap -L "swap" $(blkid --uuid "$SWAP_UUID")
swapon $(blkid --label "$SWAP_UUID")

printf "\nDisk after partition:\n"
sfdisk -l /dev/${device}

# Mounting root file system
printf "\nMounting file systems:\n"
mount /dev/${device}1 /mnt
# Creating mounting points on /mnt
mkdir /mnt/boot
mkdir /mnt/home
# Mounting boot and home file systems
mount /dev/${device}3 /mnt/boot
mount /dev/${device}4 /mnt/home

# Select only United Kingdom mirrors
mirrors_url="https://www.archlinux.org/mirrorlist/?country=GB&protocol=https&use_mirror_status=on"
curl -s $mirrors_url | sed -e 's/^#Server/Server/' -e '/^#/d' > /etc/pacman.d/mirrorlist

# Create minimal system in /mnt by bootstrapping
printf "Creating minimal system at /mnt\n"
pacstrap /mnt base base-devel linux-zen linux-firmware grub

# Create fstab
printf "Creating fstab with labels:\n"
genfstab -L /mnt >> /mnt/etc/fstab

# Create new script inside the new root
printf "Generating new script for chroot\n"
cat << EOF > /mnt/chroot.sh
#!/usr/bin/env bash

# Set time zone
printf "\nTime configuration:\n"
ln -sf /usr/share/zoneinfo/GB /etc/localtime
hwclock --systohc

# Set location
printf "\nLocation configuration:\n"
sed -i '/en_GB.UTF-8/s/#//' /etc/locale.gen
#sed -i '/en_US.UTF-8/s/#//' /etc/locale.gen
#sed -i '/es_ES.UTF-8/s/#//' /etc/locale.gen
#sed -i '/ca_ES.UTF-8/s/#//' /etc/locale.gen
locale-gen
printf "LANG=en_GB.UTF-8\n" > /etc/locale.conf

printf "Arch_VV\n" > /etc/hostname

# Network configuration
printf "\nNetwork configuration:\n"
cat <<EOT > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   Arch_VV.localdomain Arch_VV
EOT
net_interfaces=(\$(find /sys/class/net -type l ! -name "lo" -printf "%f\n\n"))
printf "Nework interfaces:\n"
find /sys/class/net -type l ! -name "lo" -printf "%f\n\n"
ip link set \${net_interfaces[0]} up
cat <<EOT > /etc/systemd/network/wired-DHCP.network
[Match]
Name=\${net_interfaces[0]} 

[Network]
DHCP=ipv4
EOT
printf "\nEnabling internet service:\n"
# Can't link at this stage. Probably because we have a working connection through the iso.
# Remember to link after install
# ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

printf "\ninstalling grub:\n"
grub-install --target=i386-pc /dev/${device}
grub-mkconfig -o /boot/grub/grub.cfg

printf "\nSet the root password\n\n"
passwd

exit
EOF
chmod u+x /mnt/chroot.sh

# Change root to /mnt
printf "Changing root to /mnt...\n"
arch-chroot /mnt /chroot.sh

rm /mnt/chroot.sh
}

start=$(date +%s)
printf "Start time $(date -u)\n" > $log
arch_install 2>&1 | tee -a $log
printf "\nEnd time $(date -u)\n" >> $log
elapsed=$(($(date +%s)-$start))
printf "Installation time: $(($elapsed / 60)) min $(($elapsed % 60))s\n" >> $log

mv $log /mnt/$log

curl "https://raw.githubusercontent.com/karb94/arch/master/config.sh" > /mnt/root/config.sh
umount -R /mnt
reboot
