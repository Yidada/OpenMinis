#!/bin/bash
#
# Xcode Cloud: keep CFBundleVersion in step with the build counter.
#
# Minis has no CFBundleVersion literal in any Info.plist - the value is
# injected from CURRENT_PROJECT_VERSION, so that build setting is the single
# lever. Without this script every TestFlight upload reuses the same number and
# App Store Connect rejects the second one as a redundant binary.
#
# Runs before xcodebuild (Xcode Cloud executes ci_pre_xcodebuild.sh from the
# ci_scripts directory next to Minis.xcodeproj).

set -uo pipefail

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
    echo "CI_BUILD_NUMBER is not set (local build) - leaving versions untouched."
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PBXPROJ="$PROJECT_DIR/Minis.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
    echo "warning: $PBXPROJ not found; build number not updated" >&2
    exit 0
fi

echo "Setting CURRENT_PROJECT_VERSION to CI_BUILD_NUMBER=$CI_BUILD_NUMBER"
before=$(grep -c "CURRENT_PROJECT_VERSION = " "$PBXPROJ" || true)
/usr/bin/sed -i '' -E \
    "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" \
    "$PBXPROJ"
after=$(grep -c "CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};" "$PBXPROJ" || true)
echo "Updated $after of $before CURRENT_PROJECT_VERSION settings"

if [ "$after" -eq 0 ]; then
    echo "warning: no build setting was rewritten; the upload may collide with an earlier build" >&2
fi

exit 0
