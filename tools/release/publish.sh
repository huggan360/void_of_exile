#!/usr/bin/env bash
# Push Void of Exile to prod.
#
# Builds the committed HEAD in a clean worktree (uncommitted work is never
# shipped), packs only the exported game files, tags v<version> and publishes
# a GitHub release with release/release.json and release/cover.png. The Pi
# picks the release up within five minutes (void-release-sync.timer, from the
# void_of_exile_account repo) and refreshes the website wiki; pass --now to
# trigger it right away.
#
#   tools/release/publish.sh            # version from release/release.json
#   tools/release/publish.sh --now
#   tools/release/publish.sh --build-only
set -Eeuo pipefail

PROJECT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-$HOME/Godot/godot_voxel_editor}"
REPO="${REPO:-huggan360/void_of_exile}"
PI="${PI:-hugohansson@192.168.1.5}"
WORK="${WORK:-$HOME/tmp/void_release}"
NOW=0; BUILD_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --now) NOW=1 ;;
        --build-only) BUILD_ONLY=1 ;;
        *) echo "unknown option $arg" >&2; exit 2 ;;
    esac
done

info() { printf '\n==> %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

cd "$PROJECT"
VERSION="$(python3 -c 'import json;print(json.load(open("release/release.json"))["version"])')"
TAG="v$VERSION"
COMMIT="$(git rev-parse HEAD)"
[[ -f release/cover.png ]] || fail "release/cover.png is missing"
if [[ $BUILD_ONLY == 0 ]] && git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
    fail "$TAG is already released. Bump the version in release/release.json."
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

PLATFORM=linux-x86_64
STAGE="$WORK/stage/VoidOfExile"
mkdir -p "$STAGE"
"$GODOT" --headless --path "$TREE" --import >"$WORK/import.log" 2>&1 || true
"$GODOT" --headless --path "$TREE" --export-release Linux "$STAGE/VoidOfExile.x86_64" >"$WORK/export.log" 2>&1
[[ -s "$STAGE/VoidOfExile.x86_64" && -s "$STAGE/VoidOfExile.pck" ]] || fail "export failed, see $WORK/export.log"
chmod +x "$STAGE/VoidOfExile.x86_64"

ARCHIVE="VoidOfExile-$VERSION-$PLATFORM.tar.gz"
info "Packing $ARCHIVE"
tar -C "$WORK/stage" -czf "$WORK/$ARCHIVE" VoidOfExile
python3 - "$WORK/release.json" "$VERSION" "$ARCHIVE" "$COMMIT" <<'PY'
import json, sys
info = json.load(open("release/release.json"))
info["commit"] = sys.argv[4]
info["platforms"] = {"linux-x86_64": {"archive": sys.argv[3], "launch": "VoidOfExile.x86_64"}}
json.dump(info, open(sys.argv[1], "w"), indent=2)
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
ls -la "$WORK"/*.tar.gz
[[ $BUILD_ONLY == 1 ]] && { info "Build only: $WORK"; exit 0; }

TOKEN="${GITHUB_TOKEN:-$(sed -nE 's#https://[^:]+:([^@]+)@github.com.*#\1#p' ~/.git-credentials | head -1)}"
[[ -n "$TOKEN" ]] || fail "no GitHub token (set GITHUB_TOKEN)"
api() { curl -fsS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

info "Tagging $TAG and creating the GitHub release"
git tag -a "$TAG" "$COMMIT" -m "Void of Exile $VERSION"
git push origin "$TAG"
BODY="$(python3 -c '
import json; i = json.load(open("release/release.json"))
print(json.dumps({"tag_name": "v" + i["version"], "name": "Void of Exile " + i["version"],
    "body": "\n".join("- " + n for n in i.get("notes", [])), "prerelease": False, "make_latest": "true"}))')"
RELEASE="$(api -X POST "https://api.github.com/repos/$REPO/releases" -d "$BODY")"
UPLOAD="$(python3 -c 'import json,sys;print(json.load(sys.stdin)["upload_url"].split("{")[0])' <<<"$RELEASE")"
for f in "$ARCHIVE" release.json cover.png wiki.tar.gz; do
    case "$f" in *.gz) type=application/gzip ;; *.json) type=application/json ;; *) type=image/png ;; esac
    api -X POST -H "Content-Type: $type" --data-binary @"$WORK/$f" "$UPLOAD?name=$f" >/dev/null
    echo "  uploaded $f"
done
echo "  $(python3 -c 'import json,sys;print(json.load(sys.stdin)["html_url"])' <<<"$RELEASE")"

if [[ $NOW == 1 ]]; then
    info "Asking the Pi to sync now"
    ssh "$PI" 'sudo systemctl start void-release-sync.service && journalctl -u void-release-sync -n 6 --no-pager'
fi
info "Released $VERSION"
