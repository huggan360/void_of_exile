#!/usr/bin/env python3
"""Void of Exile release store: split game builds into content-addressed chunks.

The launcher keeps the last installed manifest. On an update it rebuilds each
changed file from chunks it already has on disk and downloads only the rest,
so a patch costs about as much as the resources that changed.

Chunks follow PCK entry boundaries (a resource that did not change keeps the
same bytes, and so the same hash). Big entries and other files are cut into
fixed 8 MiB pieces.

  void_release.py chunk <build_dir> <store> --version 26.0-beta --platform linux-x86_64
  void_release.py sync  --store /srv/void/files/game --game /srv/void/game --repo owner/name
  void_release.py gc    <store> [--keep 4]

Store layout:
  latest.json                      newest release, read by the launcher and website
  releases.json                    every release, newest first
  manifests/<version>-<platform>.json
  chunks/<aa>/<sha256>.gz
  media/<version>/cover.png
"""
import argparse, gzip, hashlib, json, os, shutil, struct, sys, tarfile, tempfile, time, urllib.request
from pathlib import Path

PIECE = 8 << 20          # most bytes in one chunk
GROUP_BREAK = 24         # about one small PCK entry in GROUP_BREAK ends a chunk
USER_AGENT = "void-release/1"


def pck_cuts(path):
    """Byte offsets where chunks may start: every PCK entry start, header and directory."""
    with open(path, "rb") as f:
        head = f.read(40)
        if len(head) < 40 or head[:4] != b"GDPC":
            return None
        fmt, _ma, _mi, _pa, flags = struct.unpack("<5I", head[4:24])
        base, directory = struct.unpack("<2Q", head[24:40])
        if fmt < 3 or flags & 1:  # encrypted directories can't be read
            return None
        f.seek(directory)
        count, = struct.unpack("<I", f.read(4))
        entries = []
        for _ in range(count):
            length, = struct.unpack("<I", f.read(4))
            name = f.read(length).rstrip(b"\0")
            offset, size = struct.unpack("<2Q", f.read(16))
            f.read(20)  # md5 + flags
            entries.append((offset + (base if flags & 2 else 0), size, name))
    entries.sort()
    cuts, group = [0], 0
    for offset, size, name in entries:
        # A path hash decides where small entries are grouped, so one changed
        # resource doesn't shift the chunks after it.
        brk = int.from_bytes(hashlib.sha1(name).digest()[:4], "little") % GROUP_BREAK == 0
        if size >= PIECE // 4 or brk or group >= PIECE or cuts[-1] == 0:
            cuts.append(offset)
            group = 0
        group += size
        if size >= PIECE // 4:
            cuts.extend(range(offset + PIECE, offset + size, PIECE))
            cuts.append(offset + size)
            group = 0
    cuts.append(directory)
    return sorted(set(c for c in cuts if 0 <= c))


def file_chunks(path, store):
    size = path.stat().st_size
    cuts = pck_cuts(path) if path.suffix == ".pck" else None
    if not cuts:
        cuts = list(range(0, size, PIECE))
    cuts = sorted(set(c for c in cuts if c < size)) + [size]
    out, whole = [], hashlib.sha256()
    with open(path, "rb") as f:
        for start, end in zip(cuts, cuts[1:]):
            f.seek(start)
            data = f.read(end - start)
            whole.update(data)
            digest = hashlib.sha256(data).hexdigest()
            target = store / "chunks" / digest[:2] / (digest + ".gz")
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                tmp = target.with_suffix(".tmp")
                tmp.write_bytes(gzip.compress(data, 6, mtime=0))
                tmp.replace(target)
            out.append({"h": digest, "s": len(data), "z": target.stat().st_size})
    return whole.hexdigest(), out


def chunk(build, store, version, platform, launch):
    build, store = Path(build), Path(store)
    files = []
    for path in sorted(p for p in build.rglob("*") if p.is_file()):
        rel = path.relative_to(build).as_posix()
        digest, chunks = file_chunks(path, store)
        files.append({"path": rel, "size": path.stat().st_size, "sha256": digest,
                      "exec": os.access(path, os.X_OK), "chunks": chunks})
        print("  %-28s %8.1f MB  %d chunks" % (rel, path.stat().st_size / 1e6, len(chunks)))
    manifest = {"version": version, "platform": platform, "launch": launch, "created": int(time.time()),
                "size": sum(f["size"] for f in files),
                "download": sum(c["z"] for f in files for c in f["chunks"]), "files": files}
    out = store / "manifests" / ("%s-%s.json" % (version, platform))
    out.parent.mkdir(parents=True, exist_ok=True)
    write_json(out, manifest)
    return manifest


def write_json(path, data):
    path = Path(path)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, separators=(",", ":")))
    tmp.replace(path)


def gc(store, keep):
    store = Path(store)
    releases = json.loads((store / "releases.json").read_text()) if (store / "releases.json").exists() else []
    live = set()
    kept = {r["version"] for r in releases[:keep]}
    for m in (store / "manifests").glob("*.json"):
        data = json.loads(m.read_text())
        if data["version"] not in kept:
            m.unlink()
            continue
        live.update(c["h"] for f in data["files"] for c in f["chunks"])
    removed = 0
    for c in (store / "chunks").glob("*/*.gz"):
        if c.name[:-3] not in live:
            c.unlink()
            removed += 1
    print("gc: kept %d releases, removed %d chunks" % (len(kept), removed))


# --- GitHub sync (runs on the server) -------------------------------------------------

def http_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def download(url, target):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/octet-stream"})
    with urllib.request.urlopen(req, timeout=60) as r, open(target, "wb") as f:
        shutil.copyfileobj(r, f, 1 << 20)


def sync(store, game, repo, force=False):
    """Mirror the newest GitHub release that carries a release.json into the store."""
    store, game = Path(store), Path(game)
    store.mkdir(parents=True, exist_ok=True)
    releases = [r for r in http_json("https://api.github.com/repos/%s/releases?per_page=10" % repo)
                if not r["draft"] and any(a["name"] == "release.json" for a in r["assets"])]
    if not releases:
        print("sync: no game releases on GitHub yet")
        return
    rel = releases[0]
    assets = {a["name"]: a["browser_download_url"] for a in rel["assets"]}
    known = json.loads((store / "releases.json").read_text()) if (store / "releases.json").exists() else []
    tag = rel["tag_name"]
    if not force and known and known[0].get("tag") == tag:
        return
    print("sync: new release", tag)
    with tempfile.TemporaryDirectory(dir=store) as tmp:
        tmp = Path(tmp)
        download(assets["release.json"], tmp / "release.json")
        info = json.loads((tmp / "release.json").read_text())
        version = info["version"]
        platforms = {}
        for platform, spec in info.get("platforms", {}).items():
            if spec["archive"] not in assets:
                print("sync: missing asset", spec["archive"])
                continue
            archive = tmp / spec["archive"]
            download(assets[spec["archive"]], archive)
            unpacked = tmp / ("unpacked-" + platform)
            with tarfile.open(archive) as t:
                t.extractall(unpacked, filter="data")
            roots = [p for p in unpacked.iterdir()]
            root = roots[0] if len(roots) == 1 and roots[0].is_dir() else unpacked
            manifest = chunk(root, store, version, platform, spec["launch"])
            # The server's own copy of the game, updated in place.
            target = game / platform
            target.mkdir(parents=True, exist_ok=True)
            names = {f["path"] for f in manifest["files"]}
            for f in manifest["files"]:
                dst = target / f["path"]
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(root / f["path"], dst)
            for old in target.rglob("*"):
                if old.is_file() and old.relative_to(target).as_posix() not in names:
                    old.unlink()
            (target / "VERSION").write_text(version + "\n")
            platforms[platform] = {"manifest": "manifests/%s-%s.json" % (version, platform),
                                   "size": manifest["size"], "download": manifest["download"],
                                   "launch": spec["launch"]}
        media = store / "media" / version
        media.mkdir(parents=True, exist_ok=True)
        cover = ""
        if "cover.png" in assets:
            download(assets["cover.png"], media / "cover.png")
            cover = "media/%s/cover.png" % version
        entry = {"version": version, "tag": tag, "title": info.get("title", version),
                 "date": info.get("date") or rel.get("published_at", "")[:10], "notes": info.get("notes", []),
                 "cover": cover, "url": rel["html_url"], "platforms": platforms}
    known = [entry] + [k for k in known if k["version"] != version]
    write_json(store / "releases.json", known)
    write_json(store / "latest.json", entry)
    gc(store, 4)
    print("sync: %s is live" % version)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("chunk")
    c.add_argument("build"); c.add_argument("store")
    c.add_argument("--version", required=True); c.add_argument("--platform", required=True)
    c.add_argument("--launch", required=True)
    s = sub.add_parser("sync")
    s.add_argument("--store", required=True); s.add_argument("--game", required=True)
    s.add_argument("--repo", default="huggan360/void_of_exile"); s.add_argument("--force", action="store_true")
    g = sub.add_parser("gc")
    g.add_argument("store"); g.add_argument("--keep", type=int, default=4)
    a = ap.parse_args()
    if a.cmd == "chunk":
        chunk(a.build, a.store, a.version, a.platform, a.launch)
    elif a.cmd == "sync":
        sync(a.store, a.game, a.repo, a.force)
    else:
        gc(a.store, a.keep)


if __name__ == "__main__":
    sys.exit(main())
