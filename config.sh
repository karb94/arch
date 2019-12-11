#!/usr/bin/env bash

pacman -S --asdeps git jq expac diffstat pacutils parallel wget
curl "https://aur.archlinux.org/cgit/aur.git/snapshot/aurutils.tar.gz" > /tmp/aurutils.tar.gz
cd aurutils
sudo -u nobody tar xvzf /tmp/aurutils.tar.gz
sudo -u nobody HOME=/tmp/aurutils GNUPGHOME=/tmp/aurutils/.gnupg gpg --recv-keys DBE7D3DD8C81D58D0A13D0E76BC26A17B9B7018A
sudo -u nobody HOME=/tmp/aurutils GNUPGHOME=/tmp/aurutils/.gnupg makepkg
makepkg --install

# chmod g+ws /home/build
# setfacl -m u::rwx,g::rwx /home/build
# setfacl -d --set u::rwx,g::rwx,o::- /home/build

# mkdir /tmp/aurutils
