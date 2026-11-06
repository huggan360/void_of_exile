# Content review wiki

The desktop artifact is `/home/hugo/Desktop/Void-of-Exile-Wiki.html`. It embeds all data, images and its heading font and works offline.

Regenerate from the project directory:

```bash
env XDG_DATA_HOME=/home/hugo/tmp/void_wiki_userdata /home/hugo/Godot/godot_voxel_editor --headless --path "$PWD" tools/export_review_catalog.tscn
python3 tools/enrich_review_catalog.py
env XDG_DATA_HOME=/home/hugo/tmp/void_wiki_userdata /home/hugo/Godot/godot_voxel_editor --path "$PWD" tools/export_wiki_media.tscn
python3 tools/build_review_wiki.py
```

Media export needs the graphical renderer. Remove the generated PNGs in `/home/hugo/tmp/void_wiki/media` before regenerating after art changes: renders are cached by model or attack key. The exporter uses the real CreatureModel, Arrows and EnemyBullets mesh builders. Still images do not simulate moving trails and particles.

The catalog export evaluates defaults and checked-in config in an isolated process. It does not load a world, modify balance or import source art into the game. Temporary files use `/home/hugo/tmp/void_wiki`. The builder reads the external Pixelorama artwork from `/home/hugo/Documents/Voidrealm_textures` with the existing texture importer flatten function.

Boss shot analysis preserves source expressions. Local-variable and conditional values are not presented as fixed stats. The full actor source remains accessible in boss details, including hazards and movement which are not conventional projectiles. Loot and spawn links are static audit results, with probability terms and contextual multipliers preserved.

Open the HTML with `?selftest=1` to run the built-in detail-render checks. The body exposes `data-selftest`, `data-test-errors` and `data-test-count` for browser automation.
