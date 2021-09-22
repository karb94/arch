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
  pacman -Syu

  # install aurutils dependencies
  pacman -S --asdeps --needed --noconfirm fakeroot binutils
  # install packages
  packages_url=https://raw.githubusercontent.com/karb94/arch/master/packages
  curl "$packages_url" | pacman -S --needed --noconfirm -

  aurutils_url="https://aur.archlinux.org/cgit/aur.git/snapshot/aurutils.tar.gz"
  curl $aurutils_url | tar xvz --directory /tmp/

  cat <<EOF >> /etc/pacman.conf
permit nopass root cmd
EOF
  # cat <<EOF >> /etc/pacman.conf

  # [aur]
  # SigLevel = Optional TrustAll
  # Server = file:///var/cache/pacman/aurpkg
  # EOF

  # sed -in '/\[options\]/a \
  # CacheDir = /var/cache/pacman/pkg\
  # CacheDir = /var/cache/pacman/custom\
  # CleanMethod = KeepCurrent' /etc/pacman.conf

  # clean up
  # systemctl disable first-boot.service
  # rm /etc/systemd/system/first-boot.service"
}

main >> /root/dispatcher.log
