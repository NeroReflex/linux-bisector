#!/bin/sh
set -eu
basedir=$(cd "$(dirname "$0")" && pwd)
cd "$basedir"

case "${1:-install}" in
install)
    if [ ! -s linux/.bisector_commit ]; then
        echo "linux/.bisector_commit missing — run ./build.sh first" >&2
        exit 1
    fi
    pkgs=$(ls linux-bisector-*.pkg.tar.zst 2>/dev/null || true)
    if [ -z "$pkgs" ]; then
        echo "no linux-bisector-*.pkg.tar.zst found — run ./build.sh first" >&2
        exit 1
    fi

    sudo pacman -U --overwrite='*' linux-bisector-*.pkg.tar.zst

    cp linux/.bisector_commit .expected_commit
    expected_kver=$(cat linux/usr/lib/modules/*/pkgbase 2>/dev/null >/dev/null; \
        ls -1d /usr/lib/modules/*-g"$(cat .expected_commit)"-* 2>/dev/null | head -n1 | xargs -r basename)

    echo
    echo "Installed commit: $(cat .expected_commit)"
    if [ -n "${expected_kver:-}" ]; then
        echo "Expected uname -r after reboot: $expected_kver"
    else
        echo "Expected uname -r ends with: -g$(cat .expected_commit)-1"
    fi
    echo "Reboot, then run: ./install.sh verify"
    ;;

verify)
    if [ ! -s .expected_commit ]; then
        echo ".expected_commit missing — run ./install.sh first" >&2
        exit 1
    fi
    expected=$(cat .expected_commit)
    running=$(uname -r)
    case "$running" in
    *-g"$expected"-*)
        echo "OK: running $running matches commit $expected"
        echo "Safe to mark this commit good/bad."
        ;;
    *)
        echo "MISMATCH" >&2
        echo "  running:  $running" >&2
        echo "  expected: ...-g${expected}-..." >&2
        echo "Do NOT git bisect good/bad — wrong kernel is booted." >&2
        exit 1
        ;;
    esac
    ;;

*)
    echo "usage: $0 [install|verify]" >&2
    exit 2
    ;;
esac
