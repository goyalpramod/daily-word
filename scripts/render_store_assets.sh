#!/usr/bin/env bash
# Renders App Store screenshots and previews into AppStore/ from the app's real SwiftUI views.
# Usage: scripts/render_store_assets.sh [--no-video]
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

BIN="$(mktemp -d)/render"
swiftc -O -suppress-warnings -parse-as-library -o "$BIN" \
  AppStore/Renderer/*.swift \
  Shared/Models/Entry.swift Shared/Logic/Theme.swift Shared/Logic/WordLibrary.swift Shared/Logic/Rotation.swift \
  App/Views/EntryPage.swift

"$BIN" Resources AppStore "$@"

# App Store Connect expects an audio track in previews; add a silent one.
if [[ " $* " != *" --no-video "* ]]; then
  for f in AppStore/Previews/*-raw.mp4; do
    out="${f%-raw.mp4}.mp4"
    ffmpeg -loglevel error -y -i "$f" -f lavfi -i anullsrc=r=44100:cl=stereo -shortest \
      -c:v copy -c:a aac -b:a 256k -movflags +faststart "$out"
    rm "$f"
    echo "  $out (with silent audio)"
  done
fi
