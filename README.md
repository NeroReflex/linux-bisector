# Archlinux kernel bisector

This is a bisect that will allow loading dkms modules and play nice with archlinux in general.

Setup the build script by cloning this repository.

## ChimeraOS
If you are using ChimeraOS it is necessary to move to a branch with a refactored frzr:

```sh
sudo frzr-deploy neroreflex/chimeraos:unstable
```

If frzr-deploy command does not work you are already on a frzr-refactored branch.

__NOTE:__ after installing it make sure to reboot!

```sh
sudo frzr unlock
```

Allows modifications to the deployment be made. Reboot after doing this.

## EOS

If you are using EndeavourOS you don't need to do anything more.

## Other arch-based distros

If you use systemd-boot or refind install [sbctl-dracut-conf](https://aur.archlinux.org/packages/sbctl-dracut-conf) from AUR, removing mkinitcpio.

Remember to copy your kernel cmdline from /proc/cmdline into /etc/dracut.conf.d/01-cmdline.conf and run

```sh
sudo sbctl create-keys
sudo dracut-regen
```

After this every time the kernel is installed a new initramfs will be generated.

## Setting up the build environment

This is common for every archlinux derivative:

```sh
sudo pacman -S base-devel gcc ccache bc flex bison make
```

## Setting up ccache
To speed up compilation of code that is very similar (it will be increasingly important as you reach the end of the bisect) ccache is used.

Install ccache:
```sh
sudo pacman -S ccache
```

Then assign ccache a lot of space to work:

```sh
ccache -M 100G # 100 GB, feel free to lower this
```

When you will have completed the bisect remember to clean that used space:

```sh
ccache -C
```

## Bisecting

To initialize the linux kernel sources and start the bisect you use the script initialize.sh

```sh
./initialize.sh
```

After this git will await for a known good and known bad commit, so assume you know 6.11.4 works and 6.11.5 does not,
you need to confirm this is what you see while bisecting, otherwise the problem might be elsewhere or the configuration
in use is unsuitable to reproduce the bug.

Head over the linux directory and checkout the known broken version:

```sh
cd linux
# replace v6.11.5 with whatever is the known broken version
git checkout v6.11.5
```

Then proceed compiling the kernel:

```sh
./build.sh
```

Once that is done you can install the compiled version doing

```sh
./install.sh
```

This installs the package and records the bisected commit in `.expected_commit` so you can verify after reboot that the right kernel actually booted (see Suggestions below).

If you are using ChimeraOS you can reboot and spam arrow down or arrow up and select the entry with (linux-bisector).

Once boot is completed, **first confirm you actually booted into the kernel you just built**:

```sh
./install.sh verify
```

This compares the running `uname -r` against `.expected_commit` (written by `./install.sh` at install time) and exits non-zero if they don't match — i.e. if you booted your normal kernel by accident, or the bootloader entry is stale. Do NOT skip this; marking `git bisect good`/`bad` against the wrong running kernel poisons the entire bisect.

Once verify says OK, check if the bug is in there. If it is:

```sh
cd linux
git bisect bad
```

Then do the same thing with v6.11.4, so:

```sh
cd linux
git checkout v6.11.4
cd ..
./build.sh
./install.sh
```

Reboot again into linux-bisector, run `./install.sh verify` again, and if the bug is not there you can start your git bisect marking the first good commit:

```sh
cd linux
git bisect good
```

From this moment until the end of the bisect each time you do git bisect bad or git bisect good, git will change the 
current commit on the linux directory giving you something new to try until the bisect will be over.

Repeat this step as many times as needed:

```sh
cd linux
git bisect (good|bad)  # good or bad depends if on the current reboot of linux-bisector you could reproduce the bug or not
# git has moved to a new commit
cd ..
./build.sh             # build that new commit
./install.sh           # install the newly compiled kernel
reboot                 # and remember to pick linux-bisector
# after reboot:
./install.sh verify    # confirm uname -r matches .expected_commit before marking good/bad
```

At the end git will tell you the first commit that has caused the bug you are attempting to have fixed.

## Suggestions

Screwing up is easy, very easy and it will cost you hours of work.

You know you have screwed up when the bisect ends in a commit that is totally unrelated to what you are looking for,
say you are looking for a bug in amdgpu and you end up in a bcachefs commit (bcachefs is not even compiled):
this is an example of a major screwup! *just for reference, every reference is purely random and is surely never happened to me*.

Common reasons for screwing up are:
1) you booted your normal kernel instead of linux-bisector, because the bootloader is not properly configured and you can only find good or bad commits.
2) you booted your normal kernel because you forgot to spam arrow down during boot.
3) you wrote bad instead of good or the other way around

Problems 1 and 2 are exactly what the `./install.sh verify` step in the bisect loop above is for. Mechanically:

- `build.sh` writes the short SHA of the currently checked-out commit into `linux/.bisector_commit`. The PKGBUILD reads this and bakes it into the kernel's localversion, so the resulting `uname -r` ends with `-g<sha>-1` (e.g. `6.19.0-bisector-g89b831ebdaca-1`). Every bisect step produces a uniquely-named kernel.
- `./install.sh` runs `pacman -U` on the freshly built `*.pkg.tar.zst` and copies `linux/.bisector_commit` to `.expected_commit` at the repo root, so it persists across reboots.
- After reboot, `./install.sh verify` reads `.expected_commit`, reads the running `uname -r`, and exits non-zero unless `uname -r` contains `-g<expected>-`. Use it as a hard gate: if verify fails, **do not** run `git bisect good`/`bad` — fix the bootloader / re-pick the linux-bisector entry / rebuild, then verify again.

`build.sh` also appends every built commit's full SHA to `built_commits.txt`, giving you a running log of what was actually compiled across the bisect — useful if you ever lose track of which step you're on, or want to retroactively check whether a step really got rebuilt.
