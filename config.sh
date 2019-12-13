#!/usr/bin/env bash

# Symlink DNS configuration (for networkd network manager)
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

pacman -Syyu
pacman -S --noconfirm git
pacman -S --noconfirm --asdeps jq expac diffstat pacutils parallel wget

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

# Change cache options to work well with aurutils
sed -in '/\[options\]/a \
CacheDir = /var/cache/pacman/pkg\
CacheDir = /var/cache/pacman/custom\
CleanMethod = KeepCurrent' /etc/pacman.conf

# Set up a new repository for aurutils called "aur"
cat <<EOF >> /etc/pacman.conf

[aur]
SigLevel = Optional TrustAll
Server = file:///var/cache/pacman/aurpkg
EOF

# Create the group "sudo". You will need to give
# superuser powers to the sudo group by using visudo
groupadd sudo
# Create the directory for the aur database and packages
sudo install --directory /var/cache/pacman/aurpkg --group=sudo

# Make aurutils package in /tmp directory
aurutils_url="https://aur.archlinux.org/cgit/aur.git/snapshot/aurutils.tar.gz"
curl $aurutils_url | sudo -u nobody tar xvz --directory /tmp/
sudo -u nobody HOME=/tmp/aurutils GNUPGHOME=/tmp/aurutils gpg --recv-keys DBE7D3DD8C81D58D0A13D0E76BC26A17B9B7018A
cd /tmp/aurutils
sudo -u nobody HOME=/tmp/aurutils GNUPGHOME=/tmp/aurutils makepkg
# Move the .xz file to the custom aur repository that we just created
mv aurutils*pkg.tar.xz /var/cache/pacman/aurpkg
# pacman -U aurutils*.xz

# Create the "aur" database and add all packages in that directory to it
repo-add /var/cache/pacman/aurpkg/aur.db.tar /var/cache/pacman/aurpkg/*.pkg.tar.xz

# Synchronize database with pacman
pacman -Syu
