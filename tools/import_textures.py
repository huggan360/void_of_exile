#!/usr/bin/env python3
"""Import regular gear recursively and the divine sets assigned to bosses.
Default: ~/Documents/Voidrealm_textures. Unassigned divine sets stay art-only.
"""
import json,sys,zipfile
from pathlib import Path
from PIL import Image
# Boss-assigned sets (keep in step with Items.DIVINE_SETS). Every set is live now.
LIVE_SETS = {"Spirit", "Iron", "The_Blue", "Frost", "Satan", "Holy_Divine", "Void", "Fallenwood", "Silver", "Dragon_Fire",
             "Storm", "Venom", "Eclipse", "Blood", "Madness", "Cindrella", "Goldslinger", "Ash"}
# Legacy source filenames -> runtime item ids.
ALIASES = {"crucefix of thalao": "D_bonus_crucifix_ofthalao",
           "flame of the broken": "D_bonus_flame_ofthebroken","crucefix of the blue": "D_bonus_crucifix_oftheblue",
           "croucefix of satan": "D_bonus_crucifix_ofsatan",
           "flame of the divine": "D_bonus_flame_ofthedivine",
           "crucefix of blood": "D_bonus_crucifix_ofblood", "croucefix of madness": "D_bonus_crucifix_ofmadness",
           "flame of the cindrella": "D_bonus_flame_ofcindrella"}
def flatten(path, size=(8,8)):
    with zipfile.ZipFile(path) as z:
        data=json.loads(z.read("data.json")); w,h=data["size_x"],data["size_y"]
        image=Image.new("RGBA",(w,h))
        for i,layer in enumerate(data["layers"]):
            entry=f"image_data/frames/1/layer_{i+1}"
            if not layer.get("visible",True) or entry not in z.namelist(): continue
            pixels=Image.frombytes("RGBA",(w,h),z.read(entry))
            opacity=layer.get("opacity",1)*data["frames"][0]["cels"][i].get("opacity",1)
            if opacity<1: pixels.putalpha(pixels.getchannel("A").point(lambda v:int(v*opacity)))
            image=Image.alpha_composite(image,pixels)
        assert image.size==size,path
        return image

def main():
    args=[arg for arg in sys.argv[1:] if arg!="--buffs-only"]
    src=Path(args[0]).expanduser() if args else Path.home()/"Documents/Voidrealm_textures"
    import_buffs(src)
    if "--buffs-only" in sys.argv: return
    out=Path(__file__).resolve().parents[1]/"items/textures";out.mkdir(parents=True,exist_ok=True)
    count=0;seen=set()
    for path in sorted(src.rglob("*.pxo")):
        divine="Divine" in path.relative_to(src).parts
        if divine and path.parent.name not in LIVE_SETS:continue
        if not divine and not (path.stem.startswith(("G","key_","story_")) or path.stem=="backpack"):continue
        name=ALIASES.get(path.stem,path.stem)
        assert name not in seen,f"Duplicate icon id: {name}"
        seen.add(name);flatten(path).save(out/(name+".png"));count+=1
    print(f"Imported {count} regular and boss-set icons into {out}")
def import_buffs(src):
    out=Path(__file__).resolve().parents[1]/"buffs"
    count=0
    for category,size in [("icons",(8,8)),("banners",(16,16))]:
        target=out/category;target.mkdir(parents=True,exist_ok=True)
        for path in sorted((src/"buffs"/category).glob("*.pxo")):
            name=path.stem.removeprefix("Buff_") if category=="banners" else path.stem
            flatten(path,size).save(target/(name+".png"));count+=1
    print(f"Imported {count} buff icons and banners into {out}")

if __name__=="__main__": main()
