#!/usr/bin/env bash
# Push Void of Exile to prod: the game and its dedicated server, same version.
#
# Builds the committed HEAD in a clean worktree (uncommitted work is never
# shipped), packs only the exported game files, tags v<version> and publishes
# a GitHub release with release/release.json and release/cover.png. The same
# export, renamed VoidOfExileServer (it starts as a locked dedicated server),
# goes out as a release of the server repo (SERVER_REPO). The Pi
# picks the release up within five minutes (void-release-sync.timer, from the
# void_of_exile_account repo) and refreshes the website wiki; pass --now to
# trigger it right away.
#
#   tools/release/publish.sh            # version from release/release.json
#   tools/release/publish.sh --now
#   tools/release/publish.sh --build-only
#   tools/release/publish.sh --replace      # publish the same version again (new build)
set -Eeuo pipefail

PROJECT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-$HOME/Godot/godot_voxel_editor}"
REPO="${REPO:-huggan360/void_of_exile}"
SERVER_REPO="${SERVER_REPO:-huggan360/void_of_exile_server}"
PI="${PI:-hugohansson@192.168.1.5}"
WORK="${WORK:-$HOME/tmp/void_release}"
NOW=0; BUILD_ONLY=0; REPLACE=0
for arg in "$@"; do
    case "$arg" in
        --now) NOW=1 ;;
        --build-only) BUILD_ONLY=1 ;;
        --replace) REPLACE=1 ;;
        *) echo "unknown option $arg" >&2; exit 2 ;;
    esac
done

info() { printf '\n==> %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

cd "$PROJECT"
VERSION="$(python3 -c 'import json;print(json.load(open("release/release.json"))["version"])')"
TAG="v$VERSION"
NET_VERSION="$(sed -nE 's/^const VERSION := "([^"]+)".*/\1/p' scripts/net/net.gd)"
[[ "$NET_VERSION" == "$VERSION" ]] || fail "Net.VERSION ($NET_VERSION) must match release/release.json ($VERSION)"
COMMIT="$(git rev-parse HEAD)"
[[ -f release/cover.png ]] || fail "release/cover.png is missing"
if [[ $BUILD_ONLY == 0 && $REPLACE == 0 ]] && git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
    fail "$TAG is already released. Bump the version in release/release.json, or pass --replace."
fi
git ls-files --error-unmatch release/release.json release/cover.png >/dev/null 2>&1 || fail "commit release/ first"
git diff --quiet HEAD -- release/ || fail "release/ has uncommitted changes; commit them first"

info "Building $VERSION from $(git log -1 --format='%h %s')"
TREE="$WORK/tree"
rm -rf "$WORK"; mkdir -p "$WORK"
git worktree prune
git worktree add --detach "$TREE" "$COMMIT" >/dev/null
trap 'git -C "$PROJECT" worktree remove --force "$TREE" >/dev/null 2>&1 || true' EXIT
# The editor's import cache makes the clean import take seconds, not minutes.
[[ -d .godot ]] && cp -a .godot "$TREE/"

"$GODOT" --headless --path "$TREE" --import >"$WORK/import.log" 2>&1 || true

# Windows executables are signed when a certificate is set up (VOID_SIGN_PFX: a .pfx file,
# VOID_SIGN_PASS: its password; needs osslsigncode). Without one they ship unsigned.
sign_exe() {
    [[ "$1" == *.exe && -n "${VOID_SIGN_PFX:-}" ]] || return 0
    command -v osslsigncode >/dev/null || fail "VOID_SIGN_PFX is set but osslsigncode is missing"
    osslsigncode sign -pkcs12 "$VOID_SIGN_PFX" -pass "${VOID_SIGN_PASS:-}" -n "Void of Exile" -i https://void.plainshow.se \
        -h sha256 -t http://timestamp.digicert.com -in "$1" -out "$1.signed" >/dev/null && mv "$1.signed" "$1"
}

# Every platform with a template: "<platform> <export preset> <executable suffix>".
WIN_TEMPLATE="${WIN_TEMPLATE:-$HOME/Godot/templates/godot.windows.template_release.x86_64.exe}"
TARGETS=("linux-x86_64 Linux .x86_64")
if [[ -f "$WIN_TEMPLATE" ]]; then
    TARGETS+=("windows-x86_64 Windows .exe")
else
    echo "No Windows template at $WIN_TEMPLATE (tools/release/fetch_templates.sh): Linux only."
fi
ARCHIVES=()
SERVER_ARCHIVES=()
mkdir -p "$WORK/server"
: >"$WORK/game_platforms.txt"
: >"$WORK/server_platforms.txt"
for target in "${TARGETS[@]}"; do
    read -r PLATFORM PRESET EXT <<<"$target"
    STAGE="$WORK/stage-$PLATFORM/VoidOfExile"
    mkdir -p "$STAGE"
    info "Exporting $PRESET"
    "$GODOT" --headless --path "$TREE" --export-release "$PRESET" "$STAGE/VoidOfExile$EXT" >"$WORK/export-$PLATFORM.log" 2>&1
    [[ -s "$STAGE/VoidOfExile$EXT" && -s "$STAGE/VoidOfExile.pck" ]] || fail "$PRESET export failed, see $WORK/export-$PLATFORM.log"
    if [[ "$EXT" != .exe ]]; then chmod +x "$STAGE/VoidOfExile$EXT"; fi
    sign_exe "$STAGE/VoidOfExile$EXT"
    ARCHIVE="VoidOfExile-$VERSION-$PLATFORM.tar.gz"
    info "Packing $ARCHIVE"
    tar -C "$(dirname "$STAGE")" -czf "$WORK/$ARCHIVE" VoidOfExile
    ARCHIVES+=("$ARCHIVE")
    echo "$PLATFORM $ARCHIVE VoidOfExile$EXT" >>"$WORK/game_platforms.txt"

    # The server: the same files under the server's name (a pck follows its
    # executable's name), so the launcher's chunks are shared with the game.
    SSTAGE="$WORK/server_stage-$PLATFORM/VoidOfExileServer"
    mkdir -p "$SSTAGE"
    cp "$STAGE/VoidOfExile$EXT" "$SSTAGE/VoidOfExileServer$EXT"
    cp "$STAGE/VoidOfExile.pck" "$SSTAGE/VoidOfExileServer.pck"
    SERVER_ARCHIVE="VoidOfExileServer-$VERSION-$PLATFORM.tar.gz"
    info "Packing $SERVER_ARCHIVE"
    tar -C "$(dirname "$SSTAGE")" -czf "$WORK/server/$SERVER_ARCHIVE" VoidOfExileServer
    SERVER_ARCHIVES+=("$SERVER_ARCHIVE")
    echo "$PLATFORM $SERVER_ARCHIVE VoidOfExileServer$EXT" >>"$WORK/server_platforms.txt"
done
python3 - "$WORK" "$VERSION" "$COMMIT" <<'PY'
import json, sys
work, version, commit = sys.argv[1:4]
def platforms(name):
    out = {}
    for line in open("%s/%s" % (work, name)):
        platform, archive, launch = line.split()
        out[platform] = {"archive": archive, "launch": launch}
    return out
info = json.load(open("release/release.json"))
info["commit"] = commit
info["platforms"] = platforms("game_platforms.txt")
json.dump(info, open(work + "/release.json", "w"), indent=2)
server = {"version": version, "kind": "server", "date": info.get("date", ""), "commit": commit,
          "title": "Void of Exile server " + version, "notes": ["The dedicated server for Void of Exile " + version],
          "platforms": platforms("server_platforms.txt")}
json.dump(server, open(work + "/server/release.json", "w"), indent=2)
PY
cp release/cover.png "$WORK/cover.png"

info "Website wiki data (catalog, renders, wiki.json)"
rm -rf "$HOME/tmp/void_wiki/media"; mkdir -p "$HOME/tmp/void_wiki/media"
env XDG_DATA_HOME="$WORK/userdata" "$GODOT" --headless --path "$TREE" tools/export_review_catalog.tscn >"$WORK/wiki.log" 2>&1
python3 "$TREE/tools/enrich_review_catalog.py" >>"$WORK/wiki.log" 2>&1
# Renders need the graphical renderer: a window opens for a few seconds.
env XDG_DATA_HOME="$WORK/userdata" "$GODOT" --path "$TREE" tools/export_wiki_media.tscn >>"$WORK/wiki.log" 2>&1
python3 "$TREE/tools/web/build_site_data.py" "$WORK/wiki" --version "$VERSION"
tar -C "$WORK/wiki" -czf "$WORK/wiki.tar.gz" .
ls -la "$WORK"/*.tar.gz "$WORK"/server/*.tar.gz
[[ $BUILD_ONLY == 1 ]] && { info "Build only: $WORK"; exit 0; }

TOKEN="${GITHUB_TOKEN:-$(sed -nE 's#https://[^:]+:([^@]+)@github.com.*#\1#p' ~/.git-credentials | head -1)}"
[[ -n "$TOKEN" ]] || fail "no GitHub token (set GITHUB_TOKEN)"
api() { curl -fsS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

# Removes a published release of `repo` with this tag (and the tag).
drop_release() {
    local repo="$1" old
    old="$(curl -fsS -H "Authorization: Bearer $TOKEN" "https://api.github.com/repos/$repo/releases/tags/$TAG" 2>/dev/null \
        | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])' || true)"
    [[ -n "$old" ]] && api -X DELETE "https://api.github.com/repos/$repo/releases/$old" >/dev/null
    api -X DELETE "https://api.github.com/repos/$repo/git/refs/tags/$TAG" >/dev/null 2>&1 || true
}
if [[ $REPLACE == 1 ]]; then
    info "Replacing the published $TAG"
    drop_release "$REPO"
    drop_release "$SERVER_REPO"
    git push -q origin ":refs/tags/$TAG" 2>/dev/null || true
    git tag -d "$TAG" >/dev/null 2>&1 || true
fi

info "Tagging $TAG and creating the GitHub release"
git tag -a "$TAG" "$COMMIT" -m "Void of Exile $VERSION"
git push origin "$TAG"
BODY="$(python3 -c '
import json; i = json.load(open("release/release.json"))
print(json.dumps({"tag_name": "v" + i["version"], "name": "Void of Exile " + i["version"],
    "body": "\n".join("- " + n for n in i.get("notes", [])), "prerelease": False, "make_latest": "true"}))')"
RELEASE="$(api -X POST "https://api.github.com/repos/$REPO/releases" -d "$BODY")"
UPLOAD="$(python3 -c 'import json,sys;print(json.load(sys.stdin)["upload_url"].split("{")[0])' <<<"$RELEASE")"
for f in "${ARCHIVES[@]}" release.json cover.png wiki.tar.gz; do
    case "$f" in *.gz) type=application/gzip ;; *.json) type=application/json ;; *) type=image/png ;; esac
    api -X POST -H "Content-Type: $type" --data-binary @"$WORK/$f" "$UPLOAD?name=$f" >/dev/null
    echo "  uploaded $f"
done
echo "  $(python3 -c 'import json,sys;print(json.load(sys.stdin)["html_url"])' <<<"$RELEASE")"

info "Server release $TAG in $SERVER_REPO"
SERVER_HEAD="$(api "https://api.github.com/repos/$SERVER_REPO/commits/main" | python3 -c 'import json,sys;print(json.load(sys.stdin)["sha"])')"
BODY="$(python3 -c '
import json, sys; v = sys.argv[1]
print(json.dumps({"tag_name": "v" + v, "target_commitish": sys.argv[2], "name": "Void of Exile server " + v,
    "body": "The dedicated server for Void of Exile " + v + ". Run it from the launcher (Server), or see the README.",
    "prerelease": False, "make_latest": "true"}))' "$VERSION" "$SERVER_HEAD")"
RELEASE="$(api -X POST "https://api.github.com/repos/$SERVER_REPO/releases" -d "$BODY")"
UPLOAD="$(python3 -c 'import json,sys;print(json.load(sys.stdin)["upload_url"].split("{")[0])' <<<"$RELEASE")"
for f in "${SERVER_ARCHIVES[@]}" release.json; do
    case "$f" in *.gz) type=application/gzip ;; *) type=application/json ;; esac
    api -X POST -H "Content-Type: $type" --data-binary @"$WORK/server/$f" "$UPLOAD?name=$f" >/dev/null
    echo "  uploaded $f"
done
echo "  $(python3 -c 'import json,sys;print(json.load(sys.stdin)["html_url"])' <<<"$RELEASE")"

if [[ $NOW == 1 ]]; then
    info "Asking the Pi to sync now"
    ssh "$PI" 'sudo systemctl start void-release-sync.service && journalctl -u void-release-sync -n 6 --no-pager'
fi
info "Released $VERSION"
