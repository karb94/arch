#!/usr/bin/env bash

cd /tmp
sudo -u nobody curl "https://aur.archlinux.org/cgit/aur.git/snapshot/aurutils.tar.gz" > aurutils.tar.gz
sudo -u nobody tar xvzf aurutils.tar.gz

chgrp nobody aurutils
# chmod g+ws /home/build
# setfacl -m u::rwx,g::rwx /home/build
# setfacl -d --set u::rwx,g::rwx,o::- /home/build

# mkdir /tmp/aurutils
