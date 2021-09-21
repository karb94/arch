#!/usr/bin/env bash

# read -p "Enter fullname: " username
username=carles

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

# get network interface name
net_interfaces=$(arch-chroot /mnt \
  find /sys/class/net -type l ! -name "lo" -printf "%f\n" |
  head -n1)
# enable network interface
ip link set "$net_interfaces" up

# update system
pacman -Syyu
# install packages
packages_url=https://raw.githubusercontent.com/karb94/arch/master/packages
curl "$packages_url" | pacman -S --needed --noconfirm -
