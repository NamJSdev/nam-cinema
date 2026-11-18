#!/bin/bash
cd "$(dirname "$0")" || exit 1
echo "===================================================="
echo "  CAI DAT NAM CINEMA 4K CHO MACBOOK (macOS)"
echo "===================================================="
rm -rf "/Applications/NamCinema.app"
cp -R "NamCinema.app" "/Applications/NamCinema.app"
chmod +x "/Applications/NamCinema.app/Contents/MacOS/NamCinema"
xattr -cr "/Applications/NamCinema.app" 2>/dev/null || true
echo "? Da cai dat NamCinema.app vao thu muc /Applications!"
open "/Applications/NamCinema.app"
