#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p "$ROOT/.cache/clang" "$ROOT/.cache/swiftpm" "$ROOT/.cache/config" "$ROOT/.cache/security"
SWIFT_BUILD_FLAGS=(
  --configuration release \
  --cache-path "$ROOT/.cache/swiftpm" \
  --config-path "$ROOT/.cache/config" \
  --security-path "$ROOT/.cache/security" \
  --scratch-path "$ROOT/.build" \
  --manifest-cache local \
  --disable-dependency-cache \
  -debug-info-format none \
  -Xswiftc -module-cache-path -Xswiftc "$ROOT/.cache/clang" \
  -Xcc "-fmodules-cache-path=$ROOT/.cache/clang"
)
if [[ "${CODEPAD_ALLOW_UNSANDBOXED_BUILD:-0}" == "1" ]]; then
  SWIFT_BUILD_FLAGS+=(--disable-sandbox)
fi
CLANG_MODULE_CACHE_PATH="$ROOT/.cache/clang" swift build "${SWIFT_BUILD_FLAGS[@]}"
APP="$ROOT/dist/CodePad16.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/CodePad16" "$APP/Contents/MacOS/CodePad16"
cp "$ROOT/Resources/CodePad16.icns" "$APP/Contents/Resources/CodePad16.icns"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"

# Copy every language folder. Adding a language means adding a .lproj folder;
# no script or source change is needed.
for lproj in "$ROOT"/Resources/Localization/*.lproj; do
  [[ -d "$lproj" ]] || continue
  cp -R "$lproj" "$APP/Contents/Resources/"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Text Document</string>
      <key>CFBundleTypeRole</key><string>Editor</string>
      <key>LSHandlerRank</key><string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.text</string>
        <string>public.plain-text</string>
        <string>public.source-code</string>
        <string>public.json</string>
        <string>public.xml</string>
        <string>public.html</string>
        <string>public.css</string>
      </array>
    </dict>
  </array>
  <key>CFBundleExecutable</key><string>CodePad16</string>
  <key>CFBundleIconFile</key><string>CodePad16</string>
  <key>CFBundleIdentifier</key><string>org.mpschahal16.codepad16</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>CodePad16</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleSignature</key><string>????</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>CFBundleShortVersionString</key><string>0.0.6</string>
  <key>CFBundleVersion</key><string>6</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key><string>org.mpschahal16.codepad16.tab</string>
      <key>UTTypeDescription</key><string>CodePad16 Tab</string>
      <key>UTTypeConformsTo</key><array><string>public.data</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST

# Tell macOS which languages the bundle provides. The app's own language menu
# reads the same folders, so both stay in sync automatically.
/usr/libexec/PlistBuddy -c "Delete :CFBundleLocalizations" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations array" "$APP/Contents/Info.plist"
for lproj in "$ROOT"/Resources/Localization/*.lproj; do
  [[ -d "$lproj" ]] || continue
  code="$(basename "$lproj" .lproj)"
  /usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations: string $code" "$APP/Contents/Info.plist"
done

printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --deep --sign - --timestamp=none "$APP"
printf 'Built %s\n' "$APP"
