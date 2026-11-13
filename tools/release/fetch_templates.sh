#!/usr/bin/env bash
# Downloads the engine's Windows export template (Godot 4.7.2 + the voxel module, built by
# .github/workflows/engine_templates.yml) into ~/Godot/templates, where the Windows export preset and
# publish.sh look for it.
#   tools/release/fetch_templates.sh [engine tag]
set -Eeuo pipefail
REPO="${REPO:-huggan360/void_of_exile}"
TAG="${1:-$(sed -nE 's/^  ENGINE_TAG: (.*)$/\1/p' "$(dirname "$0")/../../.github/workflows/engine_templates.yml")}"
DEST="${DEST:-$HOME/Godot/templates}"
FILE=godot.windows.template_release.x86_64.exe
mkdir -p "$DEST"
curl -fL --progress-bar -o "$DEST/$FILE.part" "https://github.com/$REPO/releases/download/$TAG/$FILE"
mv "$DEST/$FILE.part" "$DEST/$FILE"
echo "$DEST/$FILE ($(du -h "$DEST/$FILE" | cut -f1)) from $TAG"
