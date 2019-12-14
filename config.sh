#!/usr/bin/env bash

# read -p "Enter fullname: " username
username=carles

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

# Symlink DNS configuration (for networkd network manager)
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

pacman -Syyu
pacman -S --noconfirm git man-db man-pages asp

# Create the group "sudo"
groupadd sudo
# Activate superuser powers for the sudo group in /etc/sudoers
sed -i '/# %sudo\tALL=(ALL) ALL/s/# //' /etc/sudoers
# Add the main user and include it in the sudo group
useradd $username --base-dir /home --create-home -g sudo
# Set the password of the user
printf "\nSet the new password for $username:"
passwd $username

# Download and build aurutils in $HOME/.builds
sudo -i -u $username << EOF
# Create a hidden directory to store custom builds
mkdir \$HOME/.builds

# Build and install aurutils
aurutils_url="https://aur.archlinux.org/cgit/aur.git/snapshot/aurutils.tar.gz"
curl \$aurutils_url | tar xvz --directory \$HOME/.builds
gpg --recv-keys DBE7D3DD8C81D58D0A13D0E76BC26A17B9B7018A
cd \$HOME/.builds/aurutils
EOF
cd /home/$username/.builds/aurutils
sudo -u $username makepkg -si --noconfirm

# Set up a new repository for aurutils called "aur"
cat <<EOF >> /etc/pacman.conf

[aur]
SigLevel = Optional TrustAll
Server = file:///var/cache/pacman/aurpkg

[herecura]
Server = https://repo.herecura.be/herecura/x86_64
EOF

# Change cache options to work well with aurutils
sed -in '/\[options\]/a \
    CacheDir = /var/cache/pacman/pkg\
    CacheDir = /var/cache/pacman/custom\
    CleanMethod = KeepCurrent' /etc/pacman.conf

# Create the directory for the aur database and packages
sudo install --directory /var/cache/pacman/aurpkg --group=sudo

# Move the .xz file to the custom aur repository that we just created
mv aurutils*pkg.tar.xz /var/cache/pacman/aurpkg

# Create the "aur" database and add all packages in that directory to it
repo-add /var/cache/pacman/aurpkg/aur.db.tar /var/cache/pacman/aurpkg/*.pkg.tar.xz

# Synchronize database with pacman
pacman -Syu
pacman -S aurutils vim-cli --noconfirm
