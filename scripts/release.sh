#!/bin/zsh
# Builds a universal Space2Moon.app and packs it into a drag-to-install DMG.
#   ./scripts/release.sh 0.1.0      → dist/Space2Moon-0.1.0.dmg
set -euo pipefail
cd "${0:A:h}/.."
version="${1:?usage: release.sh <version>}"

UNIVERSAL=1 VERSION="$version" ./scripts/bundle.sh

stage="$(mktemp -d)/Space2Moon"
mkdir -p "$stage"
cp -R "dist/Space2Moon.app" "$stage/"
ln -s /Applications "$stage/Applications"

dmg="dist/Space2Moon-$version.dmg"
rm -f "$dmg"
hdiutil create -volname "Space2Moon $version" -srcfolder "$stage" -ov -format UDZO -fs HFS+ "$dmg" >/dev/null
rm -rf "${stage:h}"
shasum -a 256 "$dmg"
echo "Built $dmg"
