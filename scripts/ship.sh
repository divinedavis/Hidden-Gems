#!/usr/bin/env bash
# Bumps CFBundleVersion, archives, exports, and uploads Hidden Gems
# to TestFlight. Meant to be run after every code change so the
# latest state is always testable on device.
#
# Requires scripts/asc-config.env to exist with real ASC credentials.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

if [[ ! -f scripts/asc-config.env ]]; then
    echo "error: scripts/asc-config.env missing. Copy from .example and fill in the Issuer ID." >&2
    exit 1
fi

# shellcheck disable=SC1091
source scripts/asc-config.env

PROJECT="Hidden Gems.xcodeproj"
SCHEME="Hidden Gems"
PBXPROJ="$PROJECT/project.pbxproj"
ARCHIVE="build/HiddenGems.xcarchive"
EXPORT_DIR="build/export"
IPA="$EXPORT_DIR/Hidden Gems.ipa"

# 1. Bump CURRENT_PROJECT_VERSION (build number). App Store Connect
#    rejects duplicates, so we always increment before shipping.
current=$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PBXPROJ" | awk -F'= ' '{print $2}' | tr -d ' ;')
next=$((current + 1))
echo "==> bumping build $current -> $next"
sed -i '' "s/CURRENT_PROJECT_VERSION = $current;/CURRENT_PROJECT_VERSION = $next;/g" "$PBXPROJ"

# 2. Archive.
echo "==> archiving"
rm -rf build
mkdir -p build
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    archive

# 3. Export the IPA.
echo "==> exporting IPA"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist ExportOptions.plist \
    -allowProvisioningUpdates

# 4. Upload to TestFlight.
echo "==> uploading to TestFlight"
xcrun altool \
    --upload-app \
    -f "$IPA" \
    -t ios \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

echo "==> done. build $next uploaded; processing takes a few minutes before it's available in TestFlight."
