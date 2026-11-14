# Engine modules

C++ built into the game's custom Godot (4.7.2 + the voxel module), never loaded
by the project itself (`.gdignore`).

- `modules/voxel_surface`: `SurfaceVoxelGenerator`, the Surface's terrain
  generator. A port of `IslandGenerator._generate_block` (and the SurfaceMap
  lookups it uses); IslandGenerator configures it with the baked map and every
  feature-shaped column (`native_config`) and uses it when the engine has it
  (`terrain_generator`), else the GDScript generator. Both must make the same
  voxels: `godot --headless --path . res://tools/check_surface_generator.tscn`.
  Change the GDScript and the C++ together, then run that check.

Build (editor and templates, the commits pinned in .github/workflows/engine_templates.yml):
`tools/release/build_templates.sh editor linux windows`. The workflow builds the
Windows template with these modules too; bump its ENGINE_TAG when they change.
