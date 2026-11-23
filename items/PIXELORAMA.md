# Editing item artwork

Every PNG in `textures/` has a matching Pixelorama `.pxo` project alongside it.
Open the `.pxo` in Pixelorama 1.2.4 or later. Its project palette is selected
automatically and contains the exact colors of that item, including transparency.
Canvas sizes match the PNGs; no resizing or palette reduction was applied.

These projects were reconstructed from the current PNGs, with one editable layer
per item. They do not recover layers from the original artwork sources.

Save the `.pxo` to keep your editable source. Export as PNG at 100% scale to the
matching filename in `items/textures/` to update the game. These export settings
are already configured for this checkout. If the repository moves to another
folder or computer, select the new `items/textures/` export directory first.
Godot imports the updated PNG automatically.

To create sources for newly added PNGs, install Pillow in your Python environment
and run `python tools/make_item_pixelorama.py` from the repository root. Existing
projects are preserved. `--check` verifies that all project pixels and palettes
still match the PNGs. After editing, export your PNG before running this check.
`--overwrite` rebuilds projects from PNGs and discards edits inside existing PXOs.
