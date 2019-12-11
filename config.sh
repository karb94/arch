#!/usr/bin/env bash

pacman -Syyu
pacman -S --asdeps git jq expac diffstat pacutils parallel wget
aurutils_url="https://aur.archlinux.org/cgit/aur.git/snapshot/aurutils.tar.gz"
curl $aurutils_url | sudo -u nobody tar xvz --directory /tmp/
chmod 777 /tmp/aurutils
HOME=/tmp/aurutils GNUPGHOME=/tmp/aurutils sudo -u nobody gpg --recv-keys DBE7D3DD8C81D58D0A13D0E76BC26A17B9B7018A
cd /tmp/aurutils
HOME=/tmp/aurutils GNUPGHOME=/tmp/aurutils sudo -u nobody makepkg
sudo -u nobody makepkg --install

# chmod g+ws /home/build
# setfacl -m u::rwx,g::rwx /home/build
# setfacl -d --set u::rwx,g::rwx,o::- /home/build

# mkdir /tmp/aurutils
