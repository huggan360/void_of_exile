#!/usr/bin/env python3
"""Draw the 30 surface-dungeon Divine icons from editable 8x8 character maps.

Run: python3 -B tools/make_surface_dungeon_icons.py
Requires Pillow. Writes only the eight new Divine source folders and the x16
contact sheet /tmp/codex_icons.png. Does not run the importer or Godot.

Each icon has its own reduced palette, selected from its set's colors. A dot
means transparent. PXO metadata and ZIP entries are cloned from the Frost wand,
including the single-byte indices placeholder used by these RGBA projects.
"""

from copy import deepcopy
from dataclasses import dataclass
from importlib.util import module_from_spec, spec_from_file_location
from io import BytesIO
import json
from pathlib import Path
import sys
import zipfile

from PIL import Image, ImageColor, ImageDraw, ImageFont


PROJECT = Path(__file__).resolve().parents[1]
DIVINE = Path.home() / "Documents/Voidrealm_textures/Divine"
TEMPLATE = DIVINE / "Frost/D_wand_offrost.pxo"
CONTACT_SHEET = Path("/tmp/codex_icons.png")


@dataclass(frozen=True)
class Icon:
    item_id: str
    name: str
    kind: str
    palette: dict[str, str]
    rows: tuple[str, ...]

    def draw(self):
        if len(self.rows) != 8 or any(len(row) != 8 for row in self.rows):
            raise ValueError(f"{self.item_id}: expected eight rows of eight pixels")
        colors = {key: ImageColor.getcolor(value, "RGBA")
                  for key, value in self.palette.items()}
        colors["."] = (0, 0, 0, 0)
        image = Image.new("RGBA", (8, 8))
        image.putdata([colors[pixel] for row in self.rows for pixel in row])
        return image


@dataclass(frozen=True)
class DivineSet:
    folder: str
    boss: str
    icons: tuple[Icon, ...]


def icon(item_id, name, kind, colors, *rows):
    """Keep only colors actually used by this icon's hand-authored map."""
    used = set("".join(rows)) - {"."}
    if used - colors.keys():
        raise ValueError(f"{item_id}: undefined palette keys {used - colors.keys()}")
    return Icon(item_id, name, kind,
                {key: value for key, value in colors.items() if key in used}, rows)


# Colored outlines, upper-left light, and a few high-contrast Divine accents.
MYCELIUM = dict(o="#31443f", a="#a45c2a", A="#e9a942", h="#ffe2a0",
                t="#278d86", T="#73d6bc", p="#f6edd1", s="#b9b69a")
SALTMOURN = dict(o="#172b3b", n="#293f59", t="#247d88", T="#60bcb9",
                w="#4c342c", b="#ac763e", g="#e5b969", s="#f3edd0")
JADE = dict(o="#18382f", e="#236444", j="#37a969", J="#84df8e",
            g="#b68132", G="#f3cd69", h="#fff1af")
AFTERLIFE = dict(o="#1d203d", i="#353564", v="#57517f", c="#379cb9",
                 C="#83e9f2", p="#f4efdf", m="#c685b1")
BARROW = dict(o="#1a293c", n="#304c6c", i="#5c6d7c", I="#a4b6bf",
              w="#f0f5ed", b="#776052", c="#489dd5", C="#a2e4ff")
PRISM = dict(o="#46596e", s="#7fa7c0", c="#b4e8f4", w="#f5ffff",
             g="#b78639", G="#f2ce78", r="#ee7f95", y="#ffe38b",
             e="#83d4a6", b="#74b8ee", v="#ba96de")
REQUIEM = dict(o="#211c30", k="#42344f", v="#65418c", V="#a478d2",
               r="#b74f83", R="#f29fb6", w="#faf0dc", g="#b58342", G="#efce83")
UNMADE = dict(o="#131522", k="#292d40", h="#4a5067", g="#b48332",
              G="#f6cf66", w="#f0f4ff")


SETS = (
    DivineSet("Mycelium", "Mother Mycora", (
        icon("D_wand_ofmycelium", "Puffcap Scepter", "Wand", MYCELIUM,
             "....hAA.",
             "...hAAAo",
             "...Aaaao",
             "....Tto.",
             "...ps...",
             "..ps....",
             ".ps.....",
             "so......"),
        icon("D_bonus_talisman_ofmycelium", "Mycelium Heart", "Talisman", MYCELIUM,
             "..pssp..",
             "..s..s..",
             "...ps...",
             "..pTps..",
             ".pTsTps.",
             ".sTTpso.",
             "..pspp..",
             "...so..."),
    )),
    DivineSet("Saltmourn", "Captain Saltmourn", (
        icon("D_bow_ofsaltmourn", "Broadside Longbow", "Bow", SALTMOURN,
             "...bggb.",
             "..bw..s.",
             ".bw..s..",
             "bw..s...",
             "go.s....",
             "w.s.....",
             "ws......",
             "gb......"),
        icon("D_trident_ofsaltmourn", "Saltmourn's Harpoon", "Trident", SALTMOURN,
             ".g.g..g.",
             ".b.gs.b.",
             ".bgbgbb.",
             "..bgbb..",
             "...ws...",
             "...sw...",
             "..sws...",
             "..swo..."),
        icon("D_cloak_ofsaltmourn", "Captain's Stormcoat", "Cloak", SALTMOURN,
             "..nttn..",
             ".tTssTt.",
             ".ntootn.",
             "..ngnn..",
             ".ntnntn.",
             ".ntgntn.",
             "ntTnnTtn",
             "ottnntto"),
    )),
    DivineSet("Jade", "Ixalith", (
        icon("D_wand_ofjade", "Coil of Ixalith", "Wand", JADE,
             "....JJh.",
             "....Joj.",
             "...Gje..",
             "..JGj...",
             "..ejG...",
             "..Gj....",
             ".Gge....",
             "go......"),
        icon("D_cloak_ofjade", "Quetzal Mantle", "Cloak", JADE,
             "..eJJe..",
             ".JGhhGJ.",
             ".eGooGe.",
             "..jGGj..",
             ".JjejJJ.",
             ".ejGJje.",
             "JejGJjeJ",
             "oGoeoGo."),
        icon("D_bonus_eye_ofjade", "Eye of the Coil", "Eye", JADE,
             "........",
             "..gGGg..",
             ".GhJJhG.",
             "GhJoJJgG",
             "gJjojjjg",
             ".gjeejg.",
             "..oggo..",
             "........"),
    )),
    DivineSet("Afterlife", "Elegy, the Lantern Shepherd", (
        icon("D_wand_oftheafterlife", "Wand of the Last Breath", "Wand", AFTERLIFE,
             "......C.",
             "....cCp.",
             "....CpCc",
             "....cmc.",
             "...pv...",
             "..pv....",
             ".pv.....",
             "vo......"),
        icon("D_cloak_oftheafterlife", "Shroud of the Ferryman", "Cloak", AFTERLIFE,
             "..ivvi..",
             ".vCppCv.",
             ".icooci.",
             "..viiv..",
             ".ivmivi.",
             ".iviiio.",
             "vcCccCcv",
             "oicCCcio"),
        icon("D_bonus_talisman_oftheafterlife", "Lantern of the Shepherd", "Talisman", AFTERLIFE,
             "..vppv..",
             "..v..v..",
             "...mm...",
             ".vppppv.",
             ".vpCpCv.",
             ".vpcpcv.",
             ".vppppv.",
             "...vo..."),
    )),
    DivineSet("Barrow", "Jarl Hrimvald", (
        icon("D_trident_ofthebarrow", "Hrimvald's Oathspear", "Trident", BARROW,
             ".w.C..w.",
             ".C.wC.C.",
             ".cICcIc.",
             "..cICi..",
             "...iI...",
             "...bc...",
             "...iI...",
             "..oio..."),
        icon("D_cloak_ofthebarrow", "Wolfpelt of the Jarl", "Cloak", BARROW,
             ".I.II.I.",
             ".wwwwww.",
             ".wIooIw.",
             "..wIIw..",
             ".bIiiIb.",
             ".bIiibb.",
             "bIIiiIib",
             "obIbbIbo"),
        icon("D_robe_ofthebarrow", "Shroud of the Barrow-Seer", "Robe", BARROW,
             "..ioon..",
             ".iIccii.",
             "iInnnnIi",
             "icnCCnci",
             "o.nCnn.o",
             ".icCnci.",
             "iCnnnnCi",
             "onCCCCno"),
        icon("D_bonus_crucifix_ofthebarrow", "Barrow Rune", "Crucifix", BARROW,
             "...Iw...",
             "...IC...",
             ".IIIwII.",
             ".wCCCiI.",
             "...cI...",
             "...IC...",
             "...ii...",
             "...io..."),
    )),
    DivineSet("Prism", "Solenne, the Prism Oracle", (
        icon("D_bow_ofprism", "Refraction", "Bow", PRISM,
             "...cwwc.",
             "..wso.r.",
             ".wc..y..",
             "cs..e...",
             "wo.b....",
             "s.v.....",
             "cv......",
             "sc......"),
        icon("D_spell_ofprism", "Spell of the Prism", "Spell", PRISM,
             "...w....",
             "..wc....",
             "..wscrrr",
             "ywccoyyy",
             "ywcsceee",
             "wccs.bbb",
             "wssso.vv",
             "........"),
        icon("D_robe_ofprism", "Robe of Refracted Light", "Robe", PRISM,
             "..gGGg..",
             ".GwwwwG.",
             "GwcwwcwG",
             "GwrwwrwG",
             "o.cywc.o",
             ".GweewG.",
             "GwcbbcwG",
             "ogwvvwgo"),
        icon("D_bonus_crystal_ofprism", "Heart of the Labyrinth", "Crystal", PRISM,
             "...w....",
             "..wcw...",
             ".wwrcs..",
             ".wcycso.",
             ".cwecso.",
             "..cbso..",
             "..svs...",
             "...o...."),
    )),
    DivineSet("Requiem", "The Choirless Seraph", (
        icon("D_wand_ofrequiem", "Scepter of the Last Hymn", "Wand", REQUIEM,
             "......V.",
             ".....Vwv",
             "....kVvo",
             "...wGkg.",
             "..wkgk..",
             "..kgk...",
             ".kgk....",
             "go......"),
        icon("D_bow_ofrequiem", "Bow of Stained Glass", "Bow", REQUIEM,
             "...kRRk.",
             "..Rok.G.",
             ".Rk..g..",
             "ko..G...",
             "Vo.g....",
             "k.G.....",
             "Vg......",
             "ok......"),
        icon("D_robe_ofrequiem", "Vestment of the Choirless", "Robe", REQUIEM,
             "..kGGk..",
             ".gVVVVg.",
             "gVvGGvVg",
             "gVvgGvVg",
             "o.vGgv.o",
             ".gvgGvg.",
             "gVvgGvVg",
             "okGGGGko"),
        icon("D_spell_ofrequiem", "Hymn of Silence", "Spell", REQUIEM,
             "..gGGg..",
             ".gRkVVg.",
             "gRRkVVVg",
             "GkkwkkkG",
             "GvVkRRrG",
             "gVVkRRRg",
             ".gVkRRg.",
             "..gGGg.."),
        icon("D_bonus_flame_ofrequiem", "The Unlit Candle", "Flame", REQUIEM,
             "....v...",
             "...vok..",
             "...kok..",
             "....k...",
             "...wwg..",
             "...wGg..",
             "...wGg..",
             "..gGGgo."),
    )),
    DivineSet("Unmade", "Oblivara, the Unmade God", (
        icon("D_bow_oftheunmade", "Bow of the Mended Sky", "Bow", UNMADE,
             "...hGhk.",
             "..Gko.w.",
             ".hk..w..",
             "Gg..w...",
             "ko.w....",
             "h.w.....",
             "Gw......",
             "gk......"),
        icon("D_wand_oftheunmade", "Wand of the Golden Seam", "Wand", UNMADE,
             ".....w..",
             "....wGw.",
             ".....w..",
             "....Gk..",
             "...hGo..",
             "..hGk...",
             ".hGk....",
             "go......"),
        icon("D_trident_oftheunmade", "Trident of Broken Stars", "Trident", UNMADE,
             ".w.w..w.",
             ".h.Gh.h.",
             ".GkhGkG.",
             "..GhGk..",
             "...kG...",
             "...Gk...",
             "...hG...",
             "..okg..."),
        icon("D_cloak_oftheunmade", "Mantle of Kintsugi", "Cloak", UNMADE,
             "..hGGh..",
             ".hGhhGh.",
             ".hkookh.",
             "..Gkhk..",
             ".hkGGkh.",
             ".hGkkGk.",
             "hGkkhkGh",
             "okGhhGko"),
        icon("D_robe_oftheunmade", "Robe of the Unmade", "Robe", UNMADE,
             "..hGGh..",
             ".GhhhhG.",
             "hGkhhkGh",
             "hkGhkGkh",
             "o.kGGk.o",
             ".hGkhkh.",
             "wGkhG.w.",
             ".w.k.w.."),
        icon("D_bonus_eye_oftheunmade", "Eye of Oblivara", "Eye", UNMADE,
             "........",
             "..hGhh..",
             ".hhGkhh.",
             "hoGhhGoh",
             "hkooookh",
             ".hGGGhh.",
             "..okko..",
             "........"),
    )),
)


def load_template():
    with zipfile.ZipFile(TEMPLATE) as archive:
        entries = [(info, archive.read(info)) for info in archive.infolist()]
    metadata = json.loads(dict((info.filename, data) for info, data in entries)["data.json"])
    if (metadata["size_x"], metadata["size_y"]) != (8, 8):
        raise ValueError("The Frost template must be 8x8")
    if len(metadata["layers"]) != 1 or len(metadata["frames"]) != 1:
        raise ValueError("The Frost template must have one frame and one layer")
    return entries, metadata


def write_pxo(path, image, name, entries, template_metadata):
    metadata = deepcopy(template_metadata)
    metadata["layers"][0]["name"] = name
    profile = metadata["export_profile"]
    # Pixelorama stores these two strings as JSON strings within the JSON.
    profile["directory_path"] = json.dumps(str(path.parent))
    profile["file_name"] = json.dumps(path.stem)
    preview = BytesIO()
    image.resize((256, 256), Image.Resampling.NEAREST).save(preview, format="PNG")
    replacements = {
        "data.json": json.dumps(metadata, separators=(",", ":")).encode("utf-8"),
        "preview.png": preview.getvalue(),
        "image_data/frames/1/layer_1": image.tobytes(),
        "image_data/frames/1/indices_layer_1": b"\x00",
    }
    # Preserve every member name, ZIP attribute, and compression type.
    with zipfile.ZipFile(path, "w") as archive:
        for info, original in entries:
            archive.writestr(deepcopy(info), replacements.get(info.filename, original))


def write_usage(divine_set, directory):
    lines = [f"DIVINE SET: {divine_set.folder}", "STATUS: AVAILABLE / ASSIGNED",
             f"Dropped by: {divine_set.boss}", ""]
    for item in sorted(divine_set.icons, key=lambda item: item.item_id):
        lines.append(f"{item.item_id}.pxo | AVAILABLE / ASSIGNED | runtime id {item.item_id}")
        lines.append(f"  {item.name} - {item.kind}")
    lines.extend(["", "AVAILABLE: Editable 8x8 Pixelorama sources and matching PNG exports.",
                  f"ASSIGNED: All items in this set are assigned to {divine_set.boss}.", ""])
    (directory / "USAGE_AND_DROPS.txt").write_text("\n".join(lines), encoding="utf-8")


def load_flatten():
    # Import only flatten(); never invoke import_textures.main() or write pyc files.
    sys.dont_write_bytecode = True
    spec = spec_from_file_location("surface_icon_importer", PROJECT / "tools/import_textures.py")
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.flatten


def verify(path, expected, flatten, entries):
    with Image.open(path.with_suffix(".png")) as export:
        if export.mode != "RGBA" or export.size != (8, 8) or export.tobytes() != expected.tobytes():
            raise ValueError(f"PNG differs from the authored grid: {path}")
    actual = flatten(path)
    if actual.mode != "RGBA" or actual.size != (8, 8) or actual.tobytes() != expected.tobytes():
        raise ValueError(f"Importer round trip differs from the authored grid: {path}")
    with zipfile.ZipFile(path) as archive:
        if archive.namelist() != [info.filename for info, _ in entries]:
            raise ValueError(f"PXO member layout differs from the template: {path}")
        if archive.read("mimetype") != b"application/x-pixelorama":
            raise ValueError(f"Invalid Pixelorama mimetype: {path}")
        if archive.read("image_data/frames/1/indices_layer_1") != b"\x00":
            raise ValueError(f"Invalid RGBA indices placeholder: {path}")
        with Image.open(BytesIO(archive.read("preview.png"))) as preview:
            enlarged = expected.resize((256, 256), Image.Resampling.NEAREST)
            if preview.size != enlarged.size or preview.tobytes() != enlarged.tobytes():
                raise ValueError(f"PXO preview differs from the authored grid: {path}")


def render_sheet(images):
    font_path = str(PROJECT / "fonts/BreeSerif.ttf")
    title = ImageFont.truetype(font_path, 25)
    heading = ImageFont.truetype(font_path, 21)
    label = ImageFont.truetype(font_path, 15)
    small = ImageFont.truetype(font_path, 11)
    cell_width, row_height, margin, top = 248, 232, 20, 72
    sheet = Image.new("RGB", (6 * cell_width + margin * 2, top + len(SETS) * row_height + margin), "#161c29")
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, 10), "Void of Exile - Surface Dungeon Divine Sets", font=title, fill="#fff1d5", stroke_width=1)
    draw.text((margin, 44), "30 icons - 8x8 RGBA - nearest-neighbor x16 - names and runtime ids", font=label, fill="#aebbd0")
    for row, divine_set in enumerate(SETS):
        y = top + row * row_height
        draw.rounded_rectangle((margin - 4, y, sheet.width - margin + 4, y + row_height - 8), radius=4, fill="#222a3a")
        draw.text((margin + 8, y + 3), divine_set.folder, font=heading, fill="#fff1d5", stroke_width=1)
        title_width = draw.textlength(divine_set.folder, font=heading)
        draw.text((margin + title_width + 34, y + 10), divine_set.boss, font=label, fill="#bdcad9")
        for col, item in enumerate(divine_set.icons):
            x = margin + col * cell_width
            icon_x, icon_y = x + (cell_width - 128) // 2, y + 36
            for py in range(8):
                for px in range(8):
                    shade = "#343d4d" if (px + py) % 2 else "#3c4555"
                    draw.rectangle((icon_x + px * 16, icon_y + py * 16,
                                    icon_x + px * 16 + 15, icon_y + py * 16 + 15), fill=shade)
            sprite = images[item.item_id].resize((128, 128), Image.Resampling.NEAREST)
            sheet.paste(sprite, (icon_x, icon_y), sprite)
            for offset, text, font, color in ((174, item.name, label, "#f6eddd"),
                                               (195, item.item_id, small, "#b2c4d5")):
                width = draw.textlength(text, font=font)
                draw.text((x + (cell_width - width) / 2, y + offset), text, font=font, fill=color)
    sheet.save(CONTACT_SHEET)


def main():
    entries, metadata = load_template()
    flatten = load_flatten()
    images = {}
    # Validate every palette and grid before writing any assets.
    for divine_set in SETS:
        for item in divine_set.icons:
            if item.item_id in images:
                raise ValueError(f"Duplicate item id: {item.item_id}")
            images[item.item_id] = item.draw()
    for divine_set in SETS:
        directory = DIVINE / divine_set.folder
        directory.mkdir(parents=True, exist_ok=True)
        for item in divine_set.icons:
            image = images[item.item_id]
            path = directory / f"{item.item_id}.pxo"
            image.save(path.with_suffix(".png"))
            write_pxo(path, image, item.name, entries, metadata)
            verify(path, image, flatten, entries)
        write_usage(divine_set, directory)
        print(f"{divine_set.folder}: wrote and verified {len(divine_set.icons)} PXO/PNG pairs")
    render_sheet(images)
    print(f"Verified {len(images)} exact 8x8 importer round trips; wrote {len(SETS)} usage files.")
    print(f"Contact sheet (x16): {CONTACT_SHEET}")


if __name__ == "__main__":
    main()
