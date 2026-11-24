#!/bin/zsh
# Builds Space2Moon and wraps it into dist/Space2Moon.app.
#   ./scripts/bundle.sh            release build into dist/
#   ./scripts/bundle.sh --install  also copies the app to /Applications
set -euo pipefail
cd "${0:A:h}/.."

# UNIVERSAL=1 builds for Apple silicon and Intel (used by release.sh).
arch_flags=()
[[ -n "${UNIVERSAL:-}" ]] && arch_flags=(--arch arm64 --arch x86_64)
swift build -c release "${arch_flags[@]}"
bin="$(swift build -c release "${arch_flags[@]}" --show-bin-path)/Space2Moon"

app="dist/Space2Moon.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Space2Moon"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$app/Contents/Resources/"
[[ -d Resources/Art ]] && cp -R Resources/Art "$app/Contents/Resources/"
[[ -d Resources/Brand ]] && cp -R Resources/Brand "$app/Contents/Resources/"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Space2Moon</string>
  <key>CFBundleDisplayName</key><string>Space2Moon</string>
  <key>CFBundleIdentifier</key><string>com.siri2moon.space2moon</string>
  <key>CFBundleExecutable</key><string>Space2Moon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION:-0.1.0}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSHumanReadableCopyright</key><string>Crafted by siri2moon · siri2moon.com</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Space2Moon asks for your password only to thin Time Machine snapshots.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature. Full Disk Access is tied to it, so after a rebuild
# macOS may ask you to grant access again.
codesign --force --deep --sign - "$app"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/Space2Moon.app"
  cp -R "$app" /Applications/
  echo "Installed to /Applications/Space2Moon.app"
fi
