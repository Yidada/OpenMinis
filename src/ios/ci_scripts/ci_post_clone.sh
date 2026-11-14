#!/bin/bash
# Xcode Cloud: build the native dependencies before the archive starts.
#
# Xcode Cloud discovers this directory beside Minis.xcodeproj. The steps and
# their order mirror BUILDING.md; skipping one produces link errors much later
# (FFmpeg links LAME, the app links libish + the Alpine rootfs).
#
# Everything here is loud on purpose: each phase prints a "▸" marker. When a
# cloud build dies, the App Store Connect log shows which marker it never got
# past. The two steps that used to be able to kill the build for reasons
# unrelated to the code - a Homebrew formula that refuses to install, and the
# optional Metal toolchain download - now warn instead of aborting, and their
# real requirements are asserted directly.

set -euo pipefail

step() { echo ""; echo "▸ $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
cd "$REPOSITORY_ROOT"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1

step "environment"
sw_vers
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
echo "CI_BUILD_NUMBER=${CI_BUILD_NUMBER:-<unset>}"
git rev-parse HEAD

step "homebrew packages"
if command -v brew >/dev/null 2>&1; then
    for formula in ninja llvm lld libarchive pkg-config go python; do
        echo "  brew install $formula"
        brew install "$formula" || echo "  warning: brew install $formula failed; continuing"
    done
    BREW_PREFIX="$(brew --prefix)"
    export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/opt/lld/bin:$PATH"
    export PKG_CONFIG_PATH="$BREW_PREFIX/opt/libarchive/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
else
    echo "  warning: Homebrew is not available on this builder; using the image toolchain"
fi

step "tool check"
missing=""
for tool in ninja python3 git; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  $tool: $(command -v "$tool")"
    else
        echo "  $tool: MISSING"
        missing="$missing $tool"
    fi
done
if [ -n "$missing" ]; then
    echo "error: required build tools are missing:$missing" >&2
    exit 1
fi

step "go toolchain (1.25, not the image default)"
GO_DIR=/tmp/go1.25
if [ ! -x "$GO_DIR/bin/go" ]; then
    GO_FILE=$(curl -fsSL "https://go.dev/dl/?mode=json&include=all" | python3 -c '
import json, sys
for release in json.load(sys.stdin):
    if not release["version"].startswith("go1.25."):
        continue
    for f in release["files"]:
        if f["os"] == "darwin" and f["arch"] == "arm64" and f["kind"] == "archive":
            print(f["filename"]); sys.exit(0)
sys.exit(1)
')
    echo "  downloading $GO_FILE"
    curl -fsSL "https://go.dev/dl/$GO_FILE" -o /tmp/go.tar.gz
    mkdir -p "$GO_DIR"
    tar -xzf /tmp/go.tar.gz -C "$GO_DIR" --strip-components=1
fi
export GOROOT="$GO_DIR"
export PATH="$GO_DIR/bin:$PATH"
go version

step "python build tooling"
python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --disable-pip-version-check --quiet meson==1.12.1
python -m mesonbuild.mesonmain --version || meson --version

step "metal toolchain"
if ! xcrun -sdk iphoneos metal --version >/dev/null 2>&1; then
    xcodebuild -downloadComponent MetalToolchain \
        || echo "  warning: Metal toolchain download failed; FFmpeg will silently drop the Metal filters"
fi
xcrun -sdk iphoneos metal --version || echo "  warning: metal compiler still unavailable"

step "git submodules"
git submodule update --init --recursive
git submodule status

step "build-time configuration"
CUSTOMIZATION=src/ios/Configs/ProviderCustomization.xcconfig
if [ ! -f "$CUSTOMIZATION" ]; then
    cp "$CUSTOMIZATION.example" "$CUSTOMIZATION"
fi

step "native dependency: LAME"
./deps/build_lame.sh

step "native dependency: FFmpeg"
./deps/build_ffmpeg.sh

step "native dependency: iSH"
./deps/build_ish.sh

step "native dependency: Alpine rootfs"
./deps/prepare_alpine_rootfs.sh

step "native dependency: rclone"
./deps/build_rclone_ios.sh

step "artifacts"
# build_ish.sh tolerates a missing VDSO; the app requires it to boot Linux.
test -s deps/resources/libvdso.so.elf
test -s deps/resources/alpine-rootfs.zip
test -s deps/libs/libish.a
test -d deps/frameworks/FFmpeg.framework
test -d deps/frameworks/Rclone.xcframework
echo "Minis iOS dependencies are ready."
