#!/usr/bin/env bash
# Builds the engine's export templates on this PC: Godot with the voxel module, at the commits pinned in
# .github/workflows/engine_templates.yml (the same as the editor). Needs scons and, for Windows, MinGW
# (Arch: sudo pacman -S scons mingw-w64-gcc). The GitHub workflow does the same thing when this PC can't.
#   tools/release/build_templates.sh              # Windows
#   tools/release/build_templates.sh windows linux
# Sources go to ~/Godot/engine_src (reused next time), templates to ~/Godot/templates (the old one is kept
# as <name>.old).
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$HERE/.github/workflows/engine_templates.yml"
pin() { sed -nE "s/^  $1: ([0-9a-f]+).*/\\1/p" "$WORKFLOW"; }
GODOT_COMMIT="$(pin GODOT_COMMIT)"
VOXEL_COMMIT="$(pin VOXEL_COMMIT)"
SRC="${SRC:-$HOME/Godot/engine_src}"
DEST="${DEST:-$HOME/Godot/templates}"
PLATFORMS=("${@:-windows}")
JOBS="${JOBS:-$(nproc)}"

checkout() {  # <dir> <repo url> <commit>
    mkdir -p "$1"
    git -C "$1" init -q
    if [[ "$(git -C "$1" rev-parse -q --verify HEAD 2>/dev/null)" != "$3" ]]; then
        git -C "$1" fetch -q --depth 1 "$2" "$3"
        git -C "$1" checkout -q --force FETCH_HEAD
    fi
}

echo "Godot $GODOT_COMMIT, voxel $VOXEL_COMMIT -> $SRC"
checkout "$SRC" https://github.com/godotengine/godot.git "$GODOT_COMMIT"
checkout "$SRC/modules/voxel" https://github.com/Zylann/godot_voxel.git "$VOXEL_COMMIT"
mkdir -p "$DEST"
cd "$SRC"
for platform in "${PLATFORMS[@]}"; do
    case "$platform" in
        windows)
            scons platform=windows target=template_release arch=x86_64 use_mingw=yes production=yes lto=none \
                accesskit=no d3d12=no -j"$JOBS"
            out=godot.windows.template_release.x86_64.exe ;;
        linux)
            scons platform=linuxbsd target=template_release arch=x86_64 production=yes lto=none accesskit=no -j"$JOBS"
            out=godot.linuxbsd.template_release.x86_64 ;;
        *) echo "unknown platform $platform (windows, linux)" >&2; exit 2 ;;
    esac
    [[ -f "$DEST/$out" ]] && cp -p "$DEST/$out" "$DEST/$out.old"
    cp "bin/$out" "$DEST/$out"
    echo "built $DEST/$out ($(du -h "$DEST/$out" | cut -f1))"
done
