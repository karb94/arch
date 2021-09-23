#!/usr/bin/env bash

# interface=$1
# event=$2
# echo "interface: $interface" >> /root/dispatcher.log
# echo "event: $event" >> /root/dispatcher.log
# echo "CONNECTION_ID: $CONNECTION_ID" >> /root/dispatcher.log
# echo "DEVICE_IP_IFACE: $DEVICE_IP_IFACE" >> /root/dispatcher.log
# echo "DEVICE_IP_IFACE: $DEVICE_IP_IFACE" >> /root/dispatcher.log
# echo "CONNECTIVITY_STATE: $CONNECTIVITY_STATE" >> /root/dispatcher.log
# run the script only when online connection is active (interface is up)
[ "$CONNECTIVITY_STATE" != "FULL" ] && exit 0

# read -p "Enter fullname: " username
username=carles

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

main () {
  # get network interface name
  # net_interfaces=$(arch-chroot /mnt \
  #   find /sys/class/net -type l ! -name "lo" -printf "%f\n" |
  #   head -n1)
  # # enable network interface
  # ip link set "$net_interfaces" up


  # update system
  pacman -Syu --noconfirm

  # install packages
  packages_url=https://raw.githubusercontent.com/karb94/arch/master/packages
  curl "$packages_url" | pacman -S --needed --noconfirm -

  mkdir -pv /etc/pacman.d/hooks
  # add pacman hooks to remove excess cache
  tee /etc/pacman.d/hooks/remove_old_cache.hook <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = Only keep cache from previous and current version
When = PostTransaction
Exec = /usr/bin/paccache -rvk2
EOF

  tee /etc/pacman.d/hooks/remove_uninstalled_cache.hook <<EOF
[Trigger]
Operation = Remove
Type = Package
Target = *

[Action]
Description = Remove cache of uninstalled packages
When = PostTransaction
Exec = /usr/bin/paccache -rvuk0
EOF

  tee /etc/doas.conf <<EOF
permit nopass root as nobody cmd makepkg
EOF

  # AURUTILS INSTALLATION
  # install aurutils dependencies
  printf "\n\nAFTER AURUTILS DEPS\n\n"
  pacman -S --asdeps --needed --noconfirm fakeroot binutils signify pacutils
  printf "\n\nAFTER AURUTILS DEPS\n\n"
  # download and extract package
  aurutils_url="https://aur.archlinux.org/cgit/aur.git/snapshot/aurutils.tar.gz"
  curl $aurutils_url | tar xvz --directory /tmp/
  # make "nobody" user the owner of the folder
  chown -R nobody /tmp/aurutils
  # build aurutils
  cd /tmp/aurutils
  doas -u nobody makepkg
  # install aurutils
  pacman -U --noconfirm aurutils*.pkg.tar.zst
  # clean up
  cd /root
  rm -r /tmp/aurutils
  pacman -Rsn --noconfirm $(pacman -Qqtd)
  pacman -Sc --noconfirm

  tee /etc/doas.conf <<EOF
permit :wheel as root
permit nopass :wheel as root cmd pacman args -Syu
permit nopass :wheel as root cmd pacman args -S
EOF

  cat <<EOF >> /etc/pacman.conf
[aur]
SigLevel = Optional TrustAll
Server = file:///var/cache/pacman/aur_pkg
EOF

sed -in '/\[options\]/a \
CacheDir = /var/cache/pacman/pkg\
CacheDir = /var/cache/pacman/aur_pkg\
CleanMethod = KeepCurrent' /etc/pacman.conf

clean up
systemctl disable first-boot.service
rm /etc/systemd/system/first-boot.service"
}

main >> /root/dispatcher.log
