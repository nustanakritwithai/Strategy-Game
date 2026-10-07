#!/usr/bin/env bash
# Install pinned Godot 4.7.2 and the official export templates.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${GODOT_SDK:-$ROOT/.godot-sdk}"
BIN="$SDK/bin/godot"
CACHED="$SDK/export_templates/${GODOT_VERSION}.stable"
LINK="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

mkdir -p "$SDK/bin" "$CACHED" "$(dirname "$LINK")"
if [[ -e "$LINK" && ! -L "$LINK" ]]; then
  if [[ ! -f "$CACHED/web_nothreads_release.zip" && -f "$LINK/web_nothreads_release.zip" ]]; then
    cp -a "$LINK/." "$CACHED/"
  fi
else
  ln -sfn "$CACHED" "$LINK"
fi

if [[ ! -x "$BIN" ]]; then
  curl -fL --retry 3 -o "$SDK/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip -o "$SDK/godot.zip" -d "$SDK/bin"
  mv "$SDK/bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$BIN"
  chmod +x "$BIN"
  rm -f "$SDK/godot.zip"
fi

if [[ ! -f "$CACHED/web_nothreads_release.zip" ]]; then
  curl -fL --retry 3 -o "$SDK/templates.tpz" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  rm -rf "$SDK/tpl"
  mkdir -p "$SDK/tpl"
  unzip -q -o "$SDK/templates.tpz" -d "$SDK/tpl"
  cp -a "$SDK/tpl/templates/." "$CACHED/"
  rm -rf "$SDK/tpl" "$SDK/templates.tpz"
fi

"$BIN" --version
echo "templates: $CACHED"
