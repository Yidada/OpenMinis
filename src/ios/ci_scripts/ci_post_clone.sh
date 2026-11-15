#!/bin/bash
set -euo pipefail

# Xcode Cloud discovers this directory beside Minis.xcodeproj.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
cd "$REPOSITORY_ROOT"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
brew install ninja llvm lld libarchive pkg-config go python
BREW_PREFIX="$(brew --prefix)"
# Keep Xcode's compiler first; the guest VDSO separately uses Homebrew LLVM.
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/opt/lld/bin:$PATH"
export PKG_CONFIG_PATH="$BREW_PREFIX/opt/libarchive/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

python3 -m venv .venv
source .venv/bin/activate
python -m pip install meson==1.12.1 cryptography==50.0.0
python scripts/generate_localclaw_bootstrap.py
go version

git submodule update --init --recursive
if ! xcrun -sdk iphoneos metal --version; then
    xcodebuild -downloadComponent MetalToolchain
fi
xcrun -sdk iphoneos metal --version

CUSTOMIZATION=src/ios/Configs/ProviderCustomization.xcconfig
if [ ! -f "$CUSTOMIZATION" ]; then
    cp "$CUSTOMIZATION.example" "$CUSTOMIZATION"
fi

./deps/build_lame.sh
./deps/build_ffmpeg.sh
./deps/build_ish.sh
./deps/prepare_alpine_rootfs.sh
./deps/build_rclone_ios.sh

# build_ish.sh tolerates a missing VDSO; the app requires it to boot Linux.
test -s deps/resources/libvdso.so.elf
test -s deps/resources/alpine-rootfs.zip
test -s deps/libs/libish.a
test -d deps/frameworks/FFmpeg.framework
test -d deps/frameworks/Rclone.xcframework
echo "Minis iOS dependencies are ready."
