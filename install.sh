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
printf "\n\npartitioning ${device} device...\n\n"
if ls /sys/firmware/efi/efivars >/dev/null 2>&1
then
  sfdisk -W always /dev/${device} <<EOF
label: gpt
name=root, size="$ROOT_SIZE", type="$ROOT_UUID"
name=swap, size="$SWAP_SIZE", type="$SWAP_UUID"
name=efi, size="$EFI_SIZE", type="$EFI_UUID"
name=home, type="$HOME_UUID"
EOF
  EFI_DEVICE=$(blkid --list-one --output device --match-token PARTLABEL="home")
  mkfs.fat -n "efi" -F32 "$EFI_DEVICE"
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
ROOT_DEVICE=$(blkid --list-one --output device --match-token PARTLABEL="root")
HOME_DEVICE=$(blkid --list-one --output device --match-token PARTLABEL="home")
SWAP_DEVICE=$(blkid --list-one --output device --match-token PARTLABEL="swap")


printf "\n\nNEW PARTITION TABLE\n\n"
sfdisk -l /dev/${device}

printf "\n\nFORMATING FILE SYSTEMS\n"
printf "\nFormating root partition:\n"
mkfs.ext4 -L "root" "$ROOT_DEVICE"
printf "\nFormating home partition:\n"
mkfs.ext4 -L "home" "$HOME_DEVICE"
printf "\nFormating swap partition:\n"
mkswap -L "swap" "$SWAP_DEVICE"
printf "\nEnabling swap partition:\n"
swapon "$SWAP_DEVICE"

# mounting file systems
printf "\n\nMOUNTING FILE SYSTEMS:\n"
printf "\nMounting \"root\" at /mnt...\n"
mount "$ROOT_DEVICE" /mnt
printf "\nMounting \"home\" at /mnt/home...:\n"
mkdir /mnt/home
mount "$HOME_DEVICE" /mnt/home

# if UEFI
ls /sys/firmware/efi/efivars >/dev/null 2>&1 &&
  printf "\nMounting \"efi\" at /mnt/efi:\n" &&
  mkdir /mnt/efi && # make dir to mount efi on
  mount "$EFI_DEVICE" /mnt/efi # Mounting efi file system

printf "\n\n\nDownloading and setting mirror list...\n"
# Select only United Kingdom mirrors
mirrors_url="https://archlinux.org/mirrorlist/?country=GB&protocol=https&use_mirror_status=on"
curl -s $mirrors_url | sed -e 's/^#Server/Server/' -e '/^#/d' > /etc/pacman.d/mirrorlist

# Create minimal system in /mnt by bootstrapping
printf "\n\nCreating minimal system at /mnt\n"
pacstrap /mnt base base-devel linux-zen linux-firmware grub

# Create fstab
printf "\n\nCreating fstab with labels...\n"
genfstab -L /mnt >> /mnt/etc/fstab

# Create new script inside the new root
printf "GENERATING NEW SCRIPT FOR CHROOT\n"
cat << EOF > /mnt/chroot.sh
#!/usr/bin/env bash

# Set time zone
printf "\nSetting time configuration...\n"
ln -sf /usr/share/zoneinfo/GB /etc/localtime
hwclock --systohc

# Set location
printf "\nLocation configuration:\n"
sed -i '/en_GB.UTF-8/s/#//' /etc/locale.gen
sed -i '/en_US.UTF-8/s/#//' /etc/locale.gen
sed -i '/es_ES.UTF-8/s/#//' /etc/locale.gen
sed -i '/ca_ES.UTF-8/s/#//' /etc/locale.gen
locale-gen
localectl set-locale LANG=en_GB.UTF-8

printf "Arch_VV" > /etc/hostname

# Network configuration
printf "\nNetwork configuration:\n"
cat <<EOT > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   Arch_VV.localdomain Arch_VV
EOT

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
# umount -R /mnt
# reboot
