#!/usr/bin/env bash
# VoidRealms: export a Linux x86_64 client build and package it as a .tar.gz.
# Put this file beside project.godot and run: ./build_linux.sh
# Optional overrides:
#   GODOT=/path/to/custom/godot_editor PRESET='Linux' OUT_DIR="$HOME/Downloads" ./build_linux.sh
#   ALLOW_STOCK_TEMPLATE=1 ./build_linux.sh  # only if a stock template really supports your project
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-$HOME/Downloads}"
PACKAGE_NAME="VoidRealms-Linux-x86_64"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '\n==> %s\n' "$*"; }

[[ -f "$PROJECT_DIR/project.godot" ]] || fail "Put build_linux.sh in your Godot project root (beside project.godot)."
[[ -f "$PROJECT_DIR/export_presets.cfg" ]] || fail "No export_presets.cfg. Open Godot > Project > Export, add a Linux x86_64 preset, and save."
command -v python3 >/dev/null || fail "python3 is required to read the export preset."
command -v tar >/dev/null || fail "tar is required."
command -v sha256sum >/dev/null || fail "sha256sum is required."

if [[ -n "${GODOT:-}" ]]; then
    GODOT_BIN="$GODOT"
elif [[ -x "$HOME/godot/engine/godot_voxel_editor" ]]; then
    GODOT_BIN="$HOME/godot/engine/godot_voxel_editor"
elif [[ -x "$HOME/Godot/godot.sh" ]]; then
    GODOT_BIN="$HOME/Godot/godot.sh"
elif [[ -x "$HOME/Godot/godot_voxel_editor" ]]; then
    GODOT_BIN="$HOME/Godot/godot_voxel_editor"
elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
else
    fail "Godot editor not found. Set GODOT=/absolute/path/to/your/custom/Godot/editor."
fi
[[ -x "$GODOT_BIN" ]] || fail "Not executable: $GODOT_BIN"

# Read the preset whose name equals PRESET (if specified), otherwise choose
# the first export preset for the Linux or Linux/X11 platform. Never assume
# that the preset is literally called 'Linux'.
mapfile -t PRESET_DETAILS < <(python3 - "$PROJECT_DIR/export_presets.cfg" "${PRESET:-}" <<'PY'
import json, re, sys
from pathlib import Path
entries = {}
section = None
for raw in Path(sys.argv[1]).read_text(encoding="utf-8-sig").splitlines():
    line = raw.strip()
    m = re.fullmatch(r"\[preset\.(\d+)(\.options)?\]", line)
    if m:
        section = (m.group(1), bool(m.group(2)))
        entries.setdefault(m.group(1), {"data": {}, "options": {}})
        continue
    if line.startswith('['):
        section = None
    if section is None or '=' not in line:
        continue
    key, val = line.split('=', 1)
    val = val.strip()
    try:
        val = json.loads(val)
    except (json.JSONDecodeError, TypeError):
        pass
    entries[section[0]]["options" if section[1] else "data"][key.strip()] = val
wanted = sys.argv[2]
match = None
for entry in entries.values():
    name = entry["data"].get("name", "")
    platform = entry["data"].get("platform", "")
    if (name == wanted if wanted else platform in ("Linux", "Linux/X11")):
        match = entry
        break
if match:
    print(match["data"].get("name", ""))
    print(match["data"].get("platform", ""))
    print(match["options"].get("custom_template/release", ""))
    print(match["options"].get("binary_format/architecture", "x86_64"))
PY
)
[[ ${#PRESET_DETAILS[@]} -eq 4 ]] || fail "No matching export preset. Add Linux x86_64 in Godot's Project > Export dialog, or set PRESET='your preset name'."
PRESET_NAME="${PRESET_DETAILS[0]}"
PLATFORM="${PRESET_DETAILS[1]}"
TEMPLATE="${PRESET_DETAILS[2]}"
ARCH="${PRESET_DETAILS[3]}"
[[ "$PLATFORM" == 'Linux' || "$PLATFORM" == 'Linux/X11' ]] || fail "Preset '$PRESET_NAME' is for $PLATFORM, not Linux."
[[ "$ARCH" == x86_64 ]] || fail "Preset '$PRESET_NAME' is $ARCH, not x86_64; change its architecture in Godot."

GODOT_VERSION="$("$GODOT_BIN" --version 2>&1)" || fail "Couldn't execute the Godot editor: $GODOT_BIN"
info "Project: $PROJECT_DIR"
printf 'Godot: %s (%s)\nPreset: %s [%s]\n' "$GODOT_BIN" "$GODOT_VERSION" "$PRESET_NAME" "$ARCH"

# VoxelRealms previously used a custom_build of Godot. If voxel classes were
# compiled as a module, the stock template can export successfully but then
# fail to launch. Require an explicit opt-out if no custom release template.
if [[ -n "$TEMPLATE" ]]; then
    case "$TEMPLATE" in
        res://*) TEMPLATE_FILE="$PROJECT_DIR/${TEMPLATE#res://}" ;;
        /*)     TEMPLATE_FILE="$TEMPLATE" ;;
        *)      TEMPLATE_FILE="$PROJECT_DIR/$TEMPLATE" ;;
    esac
    [[ -f "$TEMPLATE_FILE" ]] || fail "Custom release template does not exist: $TEMPLATE_FILE"
elif [[ "$GODOT_VERSION" == *custom_build* && "${ALLOW_STOCK_TEMPLATE:-0}" != '1' ]]; then
    fail "Custom Godot detected, but Linux preset has no custom_template/release. Set its matching custom Linux template under Project > Export > Linux > Advanced Options, OR explicitly set ALLOW_STOCK_TEMPLATE=1 if stock templates are safe for your project."
fi

if [[ -f "$PROJECT_DIR/server_config/server.cfg" ]]; then
    printf '\nWARNING: Found server_config/server.cfg. Check your Linux preset excludes server_config/*\n' >&2
    printf '         (and all credentials/databases). This is a CLIENT archive, not a server archive.\n' >&2
fi

mkdir -p -- "$OUT_DIR"
OUT_DIR="$(cd -- "$OUT_DIR" && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/voidrealms-linux.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
STAGE="$TMP/$PACKAGE_NAME"
mkdir -p -- "$STAGE"
LOG="$OUT_DIR/${PACKAGE_NAME}-build.log"

info "Importing project resources..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import 2>&1 | tee "$LOG"

info "Exporting Linux release..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "$PRESET_NAME" "$STAGE/game.x86_64" 2>&1 | tee -a "$LOG"
[[ -s "$STAGE/game.x86_64" ]] || fail "Godot returned without producing the game executable. See $LOG"
if command -v file >/dev/null 2>&1; then
    BINARY_INFO="$(file -b "$STAGE/game.x86_64")"
    [[ "$BINARY_INFO" == *"ELF 64-bit"* && "$BINARY_INFO" == *"x86-64"* ]] || \
        fail "Exported binary is not Linux x86_64: $BINARY_INFO"
fi
chmod +x -- "$STAGE/game.x86_64"

cat > "$STAGE/play.sh" <<'LAUNCH'
#!/usr/bin/env bash
set -e
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "$HERE"
exec "$HERE/game.x86_64" "$@"
LAUNCH
chmod +x -- "$STAGE/play.sh"

cat > "$STAGE/README.txt" <<'README'
VoidRealms - Linux x86_64 client

Extract the .tar.gz archive, then open a terminal in its directory and run:
    ./play.sh

Alternatively, double-click play.sh if your desktop is configured to execute scripts.
This package contains the game client, not the dedicated multiplayer server.
README

info "Packaging and checksumming..."
ARCHIVE="$OUT_DIR/$PACKAGE_NAME.tar.gz"
PARTIAL="$OUT_DIR/.$PACKAGE_NAME.tar.gz.partial"
trap 'rm -rf -- "$TMP"; rm -f -- "$PARTIAL"' EXIT
tar -C "$TMP" -czf "$PARTIAL" "$PACKAGE_NAME"
mv -f -- "$PARTIAL" "$ARCHIVE"
(
    cd -- "$OUT_DIR"
    sha256sum "$(basename -- "$ARCHIVE")" > "$(basename -- "$ARCHIVE").sha256"
)
info "Done"
printf 'Archive: %s\nChecksum: %s.sha256\nBuild log: %s\n' "$ARCHIVE" "$ARCHIVE" "$LOG"
printf 'Contents:\n'
tar -tzf "$ARCHIVE" | head -30
printf '\nNote: Export succeeded; you still need to launch play.sh and test Singleplayer/multiplayer.\n'
