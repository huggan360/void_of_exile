class_name BiomeDef
extends Resource
## Everything that makes a biome look and feel different: its blocks, which
## obstacles grow there (and in what colors), and its atmosphere. When the
## player crosses into a biome, the atmosphere values blend over smoothly.

@export var id := 0
@export var biome_name := ""

@export_group("Blocks")
@export var top_block := Blocks.GRASS
@export var under_block := Blocks.DIRT
@export var stone_block := Blocks.STONE
## Sprinkled into the top layer (glowing ground spots); AIR = none.
@export var glow_block := Blocks.AIR
@export var glow_chance := 0.0

@export_group("Obstacles")
## Chance that an obstacle spawns in each placement cell.
@export var obstacle_density := 0.0
## Prefab name -> relative weight.
@export var obstacles := {}
## Colors for the prefab palette slots, index 1..7:
## stone, stone dark, foliage, wood, accent, foliage dark, glow.
@export var obstacle_colors := PackedColorArray()

## Scattered small ground clutter (decor_* prefab -> weight), drawn in bulk.
@export var decor := {}
## Chance per 2 x 2 block cell of a decor piece.
@export var decor_density := 0.0

@export_group("Enemies")
## Packs living here: [{pack (see Enemies.PACKS), density}], density =
## chance of a pack in each 36 x 36 block cell.
@export var enemy_packs: Array = []
## Signature permanent stat potion for god encounters originating in this biome.
@export var god_stat := "magic"
@export var god_stats: Array = []

@export_group("Features")
## Wall block for ruins built in this biome.
@export var ruin_block := Blocks.RUIN_BRICK
## Whether roads through this biome get lampposts.
@export var lampposts := true
## Special regions and structures (see RealmFeature.TYPES), e.g.
## {type = "lava_scar", required = 2, optional = 2, chance = 0.5}:
## `required` always generate; each of the `optional` ones has `chance`.
## packs = [{pack, chance, offset}]: enemies that live at the structure
## (one pack per structure at most, picked by chance; offset in blocks from
## its center).
@export var features: Array[Dictionary] = []

@export_group("Atmosphere")
@export var sky_top_color := Color(0.25, 0.45, 0.8)
@export var sky_horizon_color := Color(0.75, 0.85, 0.95)
@export var sun_color := Color.WHITE
@export var sun_energy := 1.2
@export var sun_pitch := 45.0
@export var sun_yaw := 40.0
@export var ambient_energy := 0.8
@export var fog_color := Color(0.7, 0.8, 0.9)
## Distance fog; 0 = none.
@export var fog_density := 0.0
## Light-catching volumetric fog; 0 = none.
@export var volumetric_fog_density := 0.0

## Its own world (the Tavern): the atmosphere takes its whole look instead of
## mixing it with plain daylight.
@export var indoor := false
## Outdoors, how strongly this biome's own sky, light and fog override plain
## daylight (0 = the gentle default mix, 1 = its whole look: the Deep Dark).
@export_range(0.0, 1.0) var mood := 0.0

## Strength of the character's torch here: 0 in bright places, up in dark ones.
@export var torch_energy := 0.0

@export_group("Fog of war")
@export var fog_of_war_enabled := true
## Radius (in blocks) the player can see and uncover around them.
@export var reveal_radius := 14.0
@export var fog_of_war_color := Color(0.1, 0.1, 0.12)
@export_range(0.0, 1.0) var fog_of_war_opacity := 1.0

@export_group("Particles")
@export var particle_color := Color(1, 1, 1, 0.0)
@export var particle_velocity := Vector3(0, 0.2, 0)
## 0 = all particles particle_color; 1 = every hue (rainbow).
@export var particle_hue_variation := 0.0
## Optional: each particle picks its color from these stops at random
## ([[offset 0..1, Color], ...], held flat until the next stop), so a palette
## can make some colors rare. Multiplied with particle_color.
@export var particle_palette: Array = []
