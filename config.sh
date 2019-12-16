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
pacman -S --noconfirm git man-db man-pages xorg-server xorg-init nodejs npm i3-gaps python

# Create the group "sudo"
groupadd sudo
# Activate superuser powers for the sudo group in /etc/sudoers
sed -i '/# %sudo\tALL=(ALL) ALL/s/# //' /etc/sudoers
# Add the main user and include it in the sudo group
useradd $username --base-dir /home --create-home -g sudo
# Set the password of the user
printf "\nSet the new password for $username:\n"
passwd $username

grep %sudo /etc/sudoers
# Download and build aurutils in $HOME/.builds
sudo -u $username -H bash << EOF
cd \$HOME
# Set up git bare repository of dotfiles
git clone --bare https://github.com/karb94/dotfiles.git \$HOME/.dotfiles
/usr/bin/git --git-dir=\$HOME/.dotfiles/ --work-tree=\$HOME checkout
# Download .bashrc
curl -L https://raw.githubusercontent.com/karb94/arch/master/.bashrc > .bashrc

# Create a hidden directory to store custom builds
mkdir \$HOME/.builds
# Download and aurutils
ps -e | grep dirmngr && kill $(ps -e | awk '/dirmngr/ {print $1}')
gpg --verbose --recv-keys DBE7D3DD8C81D58D0A13D0E76BC26A17B9B7018A
aurutils_url="https://aur.archlinux.org/cgit/aur.git/snapshot/aurutils.tar.gz"
curl \$aurutils_url | tar xvz --directory \$HOME/.builds
cd \$HOME/.builds/aurutils
echo "\$HOME"
whoami
groups
EOF
grep %sudo /etc/sudoers
cd /home/$username/.builds/aurutils
sudo -u $username makepkg -s

# Google
cp /home/$username/.bashrc /root/.bashrc
cp /home/$username/.inputrc /root/.inputrc
cp -r /home/$username/.vim /root/

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
sudo -u $username cp /etc/X11/xinit/xinitrc /home/$username/.xinitrc
