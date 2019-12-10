#!/usr/bin/env bash

if [[ $# -eq 0 ]]
then
    printf "Device name is required as a first argument"
    lsblk
    exit 0
fi

device=$1
log="install.log"


arch_install () {
    # Update the system clock
    printf "\nUpdating the system clock:"
    timedatectl set-ntp true

    # Partition the disk
    printf "\nPartitioning ${device} disk"
    sfdisk -W always /dev/${device}
    label: gpt
    name=root, size=15GiB, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
    name=swap, size=2GiB, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
    name=boot, size=300MiB, type=21686148-6449-6E6F-744E-656564454649
    name=home, type=933AC7E1-2EB4-4F13-B844-0E14E2AEF915
    EOF

    # Creating file systems
    # With gpt boot partition must not have a file system
    printf "\nCreating file systems:"
    mkfs.ext4 -L "root" /dev/${device}1
    mkswap -L "swap" /dev/${device}2
    swapon /dev/${device}2
    # mkfs.ext4 -L "boot" /dev/${device}3 >> $logfile 2>&1
    mkfs.ext4 -L "home" /dev/${device}4
    printf "\nDisk after partition:"
    sfdisk -l /dev/${device}

    # Mounting root file system
    printf "\nMounting file systems:"
    mount /dev/${device}1 /mnt
    # Creating mounting points on /mnt
    mkdir /mnt/boot >> $logfile
    mkdir /mnt/home >> $logfile
    # Mounting boot and home file systems
    mount /dev/${device}3 /mnt/boot
    mount /dev/${device}4 /mnt/home

    # Select only United Kingdom mirrors
    mirrors_url="https://www.archlinux.org/mirrorlist/?country=GB&protocol=https&use_mirror_status=on"
    curl -s $mirrors_url | sed -e 's/^#Server/Server/' -e '/^#/d' > /etc/pacman.d/mirrorlist

    # Create minimal system in /mnt by bootstrapping
    printf "Creating minimal system at /mnt"
    pacstrap /mnt base base-devel linux-zen linux-firmware grub

    # Create fstab
    printf "Creating fstab with labels:"
    genfstab -L /mnt >> /mnt/etc/fstab

    # Create new script inside the new root
    printf "Generating new script for chroot"
    cat <<EOF > /mnt/chroot.sh
    #!/usr/bin/env bash

    # Set time zone
    printf "\nTime configuration:"
    ln -sf /usr/share/zoneinfo/GB /etc/localtime
    hwclock --systohc

    # Set location
    printf "\nLocation configuration:"
    sed -i '/en_GB.UTF-8/s/#//' /etc/locale.gen
    #sed -i '/en_US.UTF-8/s/#//' /etc/locale.gen
    #sed -i '/es_ES.UTF-8/s/#//' /etc/locale.gen
    #sed -i '/ca_ES.UTF-8/s/#//' /etc/locale.gen
    locale-gen
    printf "LANG=en_GB.UTF-8" > /etc/locale.conf

    printf "Arch_VV" > /etc/hostname

    # Network configuration
    printf "\nNetwork configuration:"
    cat <<EOT > /etc/hosts
    127.0.0.1   localhost
    ::1         localhost
    127.0.1.1   Arch_VV.localdomain Arch_VV
    EOT
    net_interfaces=(\$(find /sys/class/net -type l ! -name "lo" -printf "%f\n"))
    printf "Nework interfaces:"
    find /sys/class/net -type l ! -name "lo" -printf "%f\n"
    ip link set \${net_interfaces[0]} up
    cat <<EOT > /etc/systemd/network/wired-DHCP.network
    [Match]
    Name=\${net_interfaces[0]} 

    [Network]
    DHCP=ipv4
    EOT
    printf "\nEnabling internet service:"
    systemctl enable systemd-networkd.service
    systemctl enable systemd-resolved.service
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

    printf "\ninstalling grub:"
    grub-install --target=i386-pc /dev/${device}
    grub-mkconfig -o /boot/grub/grub.cfg

    passwd

    exit
    EOF
    chmod u+x /mnt/chroot.sh

    # Change root to /mnt
    printf "Changing root to /mnt..."
    arch-chroot /mnt /chroot.sh

    rm /mnt/chroot.sh
}

printf "Start time $(date -u)" > $log
arch_install 2>&1 | tee -a $log
printf "End time $(date -u)" >> $log
mv $log /mnt/$log

curl "https://raw.githubusercontent.com/karb94/arch/master/config.sh" > /mnt/root/config.sh
umount -R /mnt
reboot


# cat $logfile /mnt/install2.log > /mnt/install.log

