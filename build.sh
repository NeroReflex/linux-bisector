#!/bin/sh
basedir=$(pwd)
sudo rm -rf src pkg *.tar.zst *.tar.gz
cd "$basedir/linux"
git log -1 --pretty=format:"%H%n" | tee -a "$basedir/built_commits.txt"
git rev-parse --short HEAD > .bisector_commit
cd "$basedir"
tar --exclude-vcs -czvf linux.tar.gz ./linux/
makepkg -sf
