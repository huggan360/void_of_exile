#!/usr/bin/env python3
"""Website wiki data: items, creatures, projectiles and classes as one JSON plus images.

Reads the review catalog and its renders (see tools/REVIEW_WIKI.md), keys the
flat render background out to transparency and writes WebP images.

  python3 tools/web/build_site_data.py <out_dir> [--version 26.0-beta]

<out_dir>/wiki.json, <out_dir>/items/*.webp, creatures/*.webp, shots/*.webp
"""
import argparse, ast, json, sys, time
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = Path.home() / "tmp/void_wiki"
RENDER_BG = (20, 35, 52)  # flat background of tools/export_wiki_media.gd renders


def color(value):
    if isinstance(value, dict) and "hex" in value:
        return "#" + value["hex"][:6]
    if isinstance(value, str) and value.startswith("("):
        try:
            r, g, b, *_ = ast.literal_eval(value)
            return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))
        except (ValueError, SyntaxError):
            pass
    return None


def keyed(src, dst, size=None):
    """Render PNG -> transparent WebP, cropped to its content."""
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im).astype(np.int16)
    d = np.abs(a[..., :3] - np.array(RENDER_BG, np.int16)).sum(axis=2)
    alpha = np.clip((d - 10) * 255 // 16, 0, 255).astype(np.uint8)
    out = a.astype(np.uint8)
    out[..., 3] = alpha
    im = Image.fromarray(out, "RGBA")
    w, h = im.size
    box = im.getbbox()
    if box:
        pad = 12
        im = im.crop((max(0, box[0] - pad), max(0, box[1] - pad), min(w, box[2] + pad), min(h, box[3] + pad)))
    if size:
        im.thumbnail((size, size), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "WEBP", quality=88, method=4)


def icon(src, dst):
    im = Image.open(src).convert("RGBA")
    scale = max(1, 128 // max(im.size))
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "WEBP", lossless=True)


def grade(item):
    tier = int(item.get("tier", 0) or 0)
    if item["id"].startswith("D_"):
        return "Divine"
    if item.get("slot") in ("weapon", "armor", "spell", "bonus") and tier > 0:
        return "G%d" % tier
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--version", default="")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    c = json.loads((WORK / "catalog.json").read_text())
    media = json.loads((WORK / "media/index.json").read_text())

    sets = {name.replace("_", " "): ids for name, ids in c["divine_sets"].items()}
    set_of = {i: name for name, ids in sets.items() for i in ids}
    boss_sets = {b: s.replace("_", " ") for b, s in c["boss_divine_sets"].items()}

    items = {}
    for raw in c["items"] + c["authored_items"]:
        if raw["id"] in items:
            continue
        i = raw
        png = ROOT / "items/textures" / (i["id"] + ".png")
        if not png.exists():
            continue
        icon(png, out / "items" / (i["id"] + ".webp"))
        shot = None
        if i["id"] in media["items"]:
            keyed(WORK / "media" / media["items"][i["id"]], out / "shots" / ("item_" + i["id"] + ".webp"), 320)
            shot = "shots/item_%s.webp" % i["id"]
        proj = i.get("projectile") or {}
        items[i["id"]] = {
            "id": i["id"], "name": i.get("item_name", i["id"]), "kind": i.get("kind", ""), "slot": i.get("slot", ""),
            "tier": i.get("tier", 0), "grade": grade(i), "set": set_of.get(i["id"], ""), "lore": i.get("lore", ""),
            "bonuses": {k: v for k, v in (i.get("bonuses") or {}).items() if v},
            "abilities": list(i.get("abilities") or []),
            "damage": [i.get("damage_min", 0), i.get("damage_max", 0)] if i.get("damage_max") else None,
            "shots": i.get("shots", 1), "rate": i.get("fire_rate"),
            "range": round(float(proj["range"]) * 0.6, 1) if proj.get("range") else None,
            "projectile": {"style": proj.get("style"), "color": color(proj.get("color"))} if proj else None,
            "consumable": i.get("consumable") or None, "bag": i.get("bag_type", ""),
            "icon": "items/%s.webp" % i["id"], "shot": shot}

    where = {}
    for b in c["biomes"]:
        for pack in b.get("enemy_packs") or []:
            pid = pack.get("pack") if isinstance(pack, dict) else pack
            p = c["packs"].get(pid, {})
            for m in ([p["leader"]] if p.get("leader") else []) + p.get("members", []):
                if "enemy" in m:
                    where.setdefault(m["enemy"], set()).add(b["biome_name"])
    for d in c["dungeons"].values() if isinstance(c["dungeons"], dict) else c["dungeons"]:
        for key in ("boss", "miniboss"):
            if d.get(key):
                where.setdefault(d[key], set()).add(d["name"])
        for e in d.get("low_enemies", []) + d.get("mid_enemies", []):
            where.setdefault(e, set()).add(d["name"])

    creatures = []
    for e in c["enemies"]:
        cid = e["id"]
        render = None
        if cid in media["enemies"]:
            keyed(WORK / "media" / media["enemies"][cid], out / "creatures" / (cid + ".webp"), 480)
            render = "creatures/%s.webp" % cid
        attacks, seen = [], set()
        for n, att in enumerate(media["attacks"].get(cid, [])):
            spec, img = att["attack"], att.get("image")
            image = None
            if img and (WORK / "media" / img).exists():
                name = img.rsplit(".", 1)[0] + ".webp"
                if name not in seen:
                    keyed(WORK / "media" / img, out / "shots" / name, 200)
                    seen.add(name)
                image = "shots/" + name
            dmg = [spec.get("damage_min"), spec.get("damage_max")]
            attacks.append({"style": spec.get("style", ""), "damage": [int(x) for x in dmg] if None not in dmg else None,
                            "speed": spec.get("speed"), "range": spec.get("range"), "count": spec.get("count"),
                            "pattern": spec.get("pattern"), "color": color(spec.get("color")),
                            "effects": [x.get("id") for x in spec.get("effects", []) if isinstance(x, dict)],
                            "image": image})
        # The wiki shows what drops, never how often.
        divine = boss_sets.get(cid, "")
        drops = [{"item": i} for i in sets.get(divine, []) if i in items]
        for i in c.get("boss_divine_extras", {}).get(cid, []):
            if i in items and not any(d["item"] == i for d in drops):
                drops.append({"item": i})
        for loot in e.get("loot") or []:
            if isinstance(loot, dict) and loot.get("item") in items and not any(d["item"] == loot["item"] for d in drops):
                drops.append({"item": loot["item"]})
        creatures.append({
            "id": cid, "name": e.get("enemy_name", cid), "boss": bool(e.get("is_boss")), "god": bool(e.get("is_god")),
            "hp": int(e.get("hp", 0)), "defense": int(e.get("defense", 0)), "xp": int(e.get("xp", 0)),
            "speed": e.get("move_speed"), "where": sorted(where.get(cid, [])), "set": divine,
            "render": render, "attacks": attacks, "drops": drops})

    classes = []
    for cid, k in c["player_classes"].items():
        classes.append({"id": cid, "name": k["name"], "about": k.get("about", ""), "weapon": k.get("weapon", ""),
                        "armor": k.get("armor", ""), "hp": k.get("hp"), "mp": k.get("mp"),
                        "max": k.get("maximum", {}), "color": color(k.get("color"))})
        art = ROOT / "characters" / (cid + ".png")
        if art.exists():
            keyed(art, out / "classes" / (cid + ".webp"), 320)

    data = {"version": a.version, "generated": int(time.time()), "items": list(items.values()),
            "creatures": creatures, "classes": classes, "sets": sets}
    (out / "wiki.json").write_text(json.dumps(data, separators=(",", ":")))
    print("wiki: %d items, %d creatures (%d bosses), %d classes -> %s" % (
        len(items), len(creatures), sum(x["boss"] for x in creatures), len(classes), out))


if __name__ == "__main__":
    sys.exit(main())
