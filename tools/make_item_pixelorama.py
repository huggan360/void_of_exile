#!/usr/bin/env python3
"""Create lossless Pixelorama 1.2.4 projects next to every item PNG.

Requires Pillow. Existing projects are preserved unless --overwrite is given.
Format: Orama-Interactive/Pixelorama v1.2.4, Project.gd and Palette.gd.
"""
import argparse
from io import BytesIO
import json
from pathlib import Path
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def source_image(path):
    with Image.open(path) as image:
        return image.convert("RGBA")


def image_colors(image):
    return sorted(set(image.get_flattened_data()), key=lambda c: (c[3], sum(c[:3]), c))


def palette_for(image):
    colors = image_colors(image)
    width = min(8, len(colors))
    return {
        "comment": "Exact colors from the matching Void of Exile item PNG, including alpha.",
        "width": width, "height": (len(colors) + width - 1) // width,
        "colors": [
            {"index": i, "color": "(" + ", ".join(format(v / 255, ".17g") for v in color) + ")"}
            for i, color in enumerate(colors)
        ],
    }


def write_project(source, destination):
    image = source_image(source)
    width, height = image.size
    palette_name = source.stem + " palette"
    metadata = {
        "pixelorama_version": "v1.2.4-stable", "pxo_version": 8,
        "size_x": width, "size_y": height,
        "color_mode": 5,  # Godot Image.FORMAT_RGBA8
        "tile_mode_x_basis_x": width, "tile_mode_x_basis_y": 0,
        "tile_mode_y_basis_x": 0, "tile_mode_y_basis_y": height,
        "layers": [{
            "name": source.stem, "type": 0, "visible": True,
            "locked": False, "opacity": 1.0, "blend_mode": 0,
            "parent": -1, "new_cels_linked": False,
        }],
        "frames": [{"duration": 1.0, "cels": [{
            "opacity": 1.0, "z_index": 0, "offset": "(0, 0)",
            "image_size": f"Vector2i({width}, {height})",
        }]}],
        "current_frame": 0, "current_layer": 0, "fps": 6.0,
        "palettes": [{palette_name: json.dumps(palette_for(image))}],
        "project_current_palette_name": palette_name,
        "include_blended_images": True,
        "export_profile": {
            "directory_path": json.dumps(str(source.parent.resolve())),
            "file_name": json.dumps(source.stem),
            "file_format": "0", "current_tab": "0", "resize": "100",
            "interpolation": "0", "export_layers": "0", "crop_mode": "0",
        },
    }
    preview = BytesIO()
    image.resize((256, 256), Image.Resampling.NEAREST).save(preview, format="PNG")
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("mimetype", "application/x-pixelorama", compress_type=zipfile.ZIP_STORED)
        archive.writestr("data.json", json.dumps(metadata, separators=(",", ":")))
        archive.writestr("image_data/frames/1/layer_1", image.tobytes())
        archive.writestr("image_data/frames/1/indices_layer_1", b"\0")
        archive.writestr("image_data/final_images/1", image.tobytes())
        archive.writestr("preview.png", preview.getvalue())


def verify_project(source, destination):
    image = source_image(source)
    with zipfile.ZipFile(destination) as archive:
        assert archive.testzip() is None, destination
        assert archive.read("mimetype") == b"application/x-pixelorama", destination
        metadata = json.loads(archive.read("data.json"))
        assert (metadata["size_x"], metadata["size_y"]) == image.size, destination
        assert archive.read("image_data/frames/1/layer_1") == image.tobytes(), destination
        assert archive.read("image_data/final_images/1") == image.tobytes(), destination
        palette_name = metadata["project_current_palette_name"]
        palette = json.loads(metadata["palettes"][0][palette_name])
        actual = {
            tuple(round(float(v.strip()) * 255) for v in c["color"].strip("()").split(","))
            for c in palette["colors"]
        }
        assert actual == set(image_colors(image)), destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify projects without writing")
    parser.add_argument("--overwrite", action="store_true", help="Replace projects from PNGs, losing PXO edits")
    args = parser.parse_args()
    if args.check and args.overwrite:
        parser.error("--check and --overwrite cannot be combined")
    created = checked = skipped = 0
    sources = sorted((ROOT / "items").rglob("*.png"))
    if not sources:
        parser.error("No item PNGs found")
    for source in sources:
        destination = source.with_suffix(".pxo")
        if args.check:
            verify_project(source, destination)
            checked += 1
        elif destination.exists() and not args.overwrite:
            skipped += 1
        else:
            write_project(source, destination)
            verify_project(source, destination)
            created += 1
    print(f"Created {created}, verified {checked or created}, preserved {skipped} existing projects.")


if __name__ == "__main__":
    main()
