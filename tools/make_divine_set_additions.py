#!/usr/bin/env python3
"""Author the new Divine pieces as editable 8x8 pixel grids and game icons.

Uses the same Pixelorama format as make_surface_dungeon_icons.py. Existing
art stays untouched. Run with python3 -B tools/make_divine_set_additions.py.
"""
from pathlib import Path
import re
from PIL import Image, ImageColor, ImageDraw
from make_surface_dungeon_icons import load_template, write_pxo
from import_textures import flatten

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path.home() / "Documents/Voidrealm_textures/Divine"

# Outline, shadow, main cloth/metal, highlights and the set's signature accent.
PALETTES = {
    "Spirit": ("25112e", "65275e", "a453a0", "f2c9e9", "f01cde"),
    "Silver": ("253344", "4f667a", "8fa9bd", "edf7ff", "bbddf4"),
    "Dragon_Fire": ("381e22", "77322b", "cc5730", "ffe4a2", "ff9a36"),
    "Fallenwood": ("26352d", "46573a", "70965a", "d9e6a4", "a7df80"),
    "Satan": ("2e111c", "6d1f2a", "b93237", "ffcb96", "f76336"),
    "Holy_Divine": ("483427", "9b7740", "d5b569", "fff6d5", "ffe377"),
    "Void": ("141322", "302940", "695078", "d8c3ec", "a874e8"),
    "Blood": ("32121f", "6d1d2b", "ab3341", "ffb5b8", "ed5b68"),
    "Madness": ("302039", "693274", "b04dba", "ffbbec", "88ef75"),
    "Cindrella": ("362a39", "7a456a", "ba6996", "ffdecd", "f4a3c7"),
    "Goldslinger": ("3a2c25", "79572d", "bb873c", "ffe2a0", "f0b030"),
    "Mycelium": ("31443f", "a45c2a", "e9a942", "ffe2a0", "73d6bc"),
    "Saltmourn": ("172b3b", "293f59", "247d88", "f3edd0", "60bcb9"),
    "Jade": ("18382f", "236444", "37a969", "fff1af", "84df8e"),
    "Afterlife": ("1d203d", "353564", "57517f", "f4efdf", "83e9f2"),
    "Barrow": ("1a293c", "304c6c", "5c6d7c", "f0f5ed", "a2e4ff"),
    "Prism": ("46596e", "7fa7c0", "b4e8f4", "f5ffff", "ee7f95"),
    "Requiem": ("211c30", "42344f", "65418c", "faf0dc", "efce83"),
    "Unmade": ("131522", "292d40", "4a5067", "f0f4ff", "f6cf66"),
}

GRIDS = {
    "cloak": ("..shhs..", ".hhaahh.", ".saooas.", "..smms..", ".smhams.", ".smamsm.", "smhaamhm", "osmmmsso"),
    "robe": ("..smms..", ".shhhhs.", "shmssmhs", "sammasas", "o.sams.o", ".smaams.", "shammash", "osmmmsso"),
    "talisman": ("..shhs..", "..s..s..", "...hh...", "..hahh..", ".hasmah.", ".hamsah.", "..hhhs..", "...so..."),
    "crucifix": ("...hh...", "...am...", ".hhamhh.", ".ammaas.", "...am...", "...am...", "..hhhs..", "...so..."),
    "crystal": ("...hh...", "..hhaa..", ".hhamaa.", ".hammam.", ".sammms.", "..samso.", "...ss...", "...o...."),
    "seal": ("..shhs..", ".hhaahs.", "hhammaah", "hamsamah", "samhasas", "sammamas", ".smaams.", "..osso.."),
    "flame": ("....h...", "..hha...", "..hmaa..", ".hamams.", ".hammhs.", "..haha..", ".shhhhs.", "..osso.."),
    "gyre": ("..shhs..", ".ha..ah.", "ha..a.ah", "ha.ah..a", "a..ha.ah", "sa.a..as", ".sa..as.", "..osso.."),
    "rune": ("...hh...", "..hhaa..", ".hamaah.", "hamhamaa", ".samhms.", "..samso.", "...ss...", "...o...."),
}

SPELL_SHAPES = {
    "Spirit": "gyre", "Silver": "seal", "Dragon_Fire": "flame", "Fallenwood": "rune",
    "Satan": "flame", "Void": "gyre", "Blood": "seal", "Madness": "gyre",
    "Cindrella": "rune", "Goldslinger": "seal", "Mycelium": "rune", "Saltmourn": "gyre",
    "Jade": "gyre", "Afterlife": "flame", "Barrow": "rune", "Unmade": "seal",
}


def set_members():
    text = (ROOT / "scripts/game/items.gd").read_text()
    block = text.split("const DIVINE_SETS := {", 1)[1].split("\n}", 1)[0]
    return {item: name for name, body in re.findall(r"(\w+)\s*=\s*\[(.*?)\]", block, re.S)
            for item in re.findall(r'"(D_[^"]+)"', body)}


def draw(kind, set_name):
    shape = SPELL_SHAPES[set_name] if kind == "spell" else kind
    colors = dict(zip("osmha", (ImageColor.getcolor("#" + c, "RGBA") for c in PALETTES[set_name])))
    colors["."] = (0, 0, 0, 0)
    rows = GRIDS[shape]
    assert len(rows) == 8 and all(len(row) == 8 for row in rows)
    image = Image.new("RGBA", (8, 8))
    image.putdata([colors[p] for row in rows for p in row])
    return image


def main():
    members = set_members()
    definitions = (ROOT / "scripts/game/divine_set_additions.gd").read_text()
    entries, metadata = load_template()
    previews = []
    for item_id, name in re.findall(r'_(?:armor|relic|spell)\(out, "([^"]+)", "([^"]+)"', definitions):
        set_name = members[item_id]
        parts = item_id.split("_")
        kind = parts[2] if parts[1] == "bonus" else parts[1]
        image = draw(kind, set_name)
        folder = SOURCE / set_name
        folder.mkdir(parents=True, exist_ok=True)
        image.save(folder / (item_id + ".png"))
        write_pxo(folder / (item_id + ".pxo"), image, name, entries, metadata)
        assert flatten(folder / (item_id + ".pxo")).tobytes() == image.tobytes()
        image.save(ROOT / "items/textures" / (item_id + ".png"))
        previews.append((item_id, image))
    # A readable contact sheet for checking silhouette and set palettes.
    sheet = Image.new("RGB", (6 * 220, ((len(previews) + 5) // 6) * 160), "#141b2b")
    ink = ImageDraw.Draw(sheet)
    for i, (name, image) in enumerate(previews):
        x, y = i % 6 * 220, i // 6 * 160
        sheet.paste(image.resize((112, 112), Image.Resampling.NEAREST), (x + 50, y + 8),
                    image.resize((112, 112), Image.Resampling.NEAREST))
        ink.text((x + 4, y + 128), name.removeprefix("D_"), fill="#f6ead3")
    sheet.save("/home/hugo/tmp/divine_set_additions.png")
    print(f"Authored and verified {len(previews)} new 8x8 icons and Pixelorama sources")


if __name__ == "__main__":
    main()
