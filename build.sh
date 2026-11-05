#!/bin/sh
set -eu
cd "$(dirname "$0")"
app='.build/Colemak-DH-Installer.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -o "$app/Contents/MacOS/Colemak-DH-Installer" Sources/*.swift -framework AppKit -framework Carbon -framework ServiceManagement
cp Info.plist "$app/Contents/Info.plist"
cp -R 'Vendor/Colemak DH.bundle' "$app/Contents/Resources/"
codesign --force --deep --sign - "$app"
printf 'Built %s\n' "$app"
