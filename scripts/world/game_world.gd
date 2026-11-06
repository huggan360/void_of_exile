class_name GameWorld
extends Node3D
## Base for a place the player can be in (the Hall, a realm). Owns its
## terrain, water, portals and obstacles; freeing the world frees all of it.

signal portal_entered(destination: String)
signal obstacle_broken(obstacle: Obstacle)

const WATER_COLOR := Color(0.16, 0.42, 0.58)

var display_name := ""
## Its id on the server ("hall" for the Tavern, "realm_1", ...).
var realm_id := ""
var terrain: VoxelTerrain
var spawn_point := Vector3.ZERO
## Distance from the center to the edge of the playable area, in blocks
## (sizes the fog-of-war map).
var half_extent := 64
var _water_surface := -INF
var _contact_fires := {}  # 8 m buckets of weak references, never character flames
var _load_steps: Array[Callable] = []

func queue_load_step(step: Callable) -> void:
	_load_steps.append(step)

func is_presentation_ready() -> bool:
	return _load_steps.is_empty()

func _process(_delta: float) -> void:
	var deadline := Time.get_ticks_usec()+2000
	while not _load_steps.is_empty() and Time.get_ticks_usec()<deadline:
		_load_steps.pop_front().call()


## The biome at a world position (drives atmosphere and fog of war).
func biome_at(_pos: Vector3) -> BiomeDef:
	return Biomes.get_biome(Biomes.HALL)


## Whether the player may walk onto this spot (e.g. not into deep water).
func is_walkable(_pos: Vector3) -> bool:
	return true


## Whether this spot is road or street (walking there is faster).
func is_road(_pos: Vector3) -> bool:
	return false


## Whether standing here hurts (lava pits).
func is_hazard(_pos: Vector3) -> bool:
	return false

func is_water(pos: Vector3) -> bool:
	return is_finite(_water_surface) and pos.y<=_water_surface+0.1

func register_contact_fire(fire: VoxelFire) -> void:
	var cell := Vector2i(floori(fire.global_position.x/8.0),floori(fire.global_position.z/8.0))
	if not _contact_fires.has(cell): _contact_fires[cell] = []
	_contact_fires[cell].append(weakref(fire))

## Physical ground fires only. Visual flames attached to a burning actor never
## enter this registry, so they cannot re-ignite themselves or spread by touch.
func touches_fire(pos: Vector3) -> bool:
	if is_hazard(pos) and absf(pos.y-ground_height(pos.x,pos.z))<0.8: return true
	var cell := Vector2i(floori(pos.x/8.0),floori(pos.z/8.0))
	for z in range(-1,2):
		for x in range(-1,2):
			var bucket: Array = _contact_fires.get(cell+Vector2i(x,z),[])
			for index in range(bucket.size()-1,-1,-1):
				var fire: VoxelFire = bucket[index].get_ref()
				if not is_instance_valid(fire):
					bucket.remove_at(index)
					continue
				var offset := pos-fire.global_position
				if absf(offset.y)>maxf(1.1,fire.size*0.8): continue
				if Vector2(offset.x,offset.z).length()<=0.35+fire.size*0.5: return true
	return false

func update_burning_contact(effects: StatusEffects, pos: Vector3) -> void:
	if is_water(pos): effects.remove("burning")
	elif not effects.burning_immune and touches_fire(pos): effects.add("burning",Burning.CONTACT_DURATION,1,"Firepit")


## Height of the ground surface (where feet stand) at x/z. Arrows fly at a
## fixed height above this so they follow slopes.
func ground_height(_x: float, _z: float) -> float:
	return 0.0


## Color of the column seen from above, for the minimap.
func map_color(_x: int, _z: int) -> Color:
	return WATER_COLOR


## Where the minimap should show this world's portals.
func portal_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for child in get_children():
		if child is Portal or (child is DungeonPortal and not child._closing):
			out.append(child.global_position)
	return out


## Lights a minimap color by height: higher ground lighter, a lit
## north-west edge on rises so slopes read as relief.
static func shade_for_map(color: Color, h: int, h_west: int, sea_level: int) -> Color:
	if h < sea_level:
		return color.lerp(WATER_COLOR, clampf(0.6 + (sea_level - h) * 0.08, 0.0, 0.9))
	var shade := 1.0 + clampf((h - h_west) * 0.18, -0.35, 0.35) + (h - sea_level) * 0.006
	return Color(color.r * shade, color.g * shade, color.b * shade)


## The named region or structure at this position ("" if none).
func region_at(_pos: Vector3) -> String:
	return ""


func _add_light(pos: Vector3, color: Color, energy := 1.5, light_range := 6.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.light_volumetric_fog_energy = 2.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 45.0
	light.distance_fade_length = 15.0
	add_child(light)
	return light


func _add_terrain(generator: VoxelGenerator, bounds: AABB) -> void:
	terrain = VoxelTerrain.new()
	terrain.generator = generator
	terrain.mesher = Blocks.mesher()
	terrain.gi_mode = GeometryInstance3D.GI_MODE_STATIC  # lets SDFGI bounce light off it
	terrain.bounds = bounds
	add_child(terrain)


func _add_water(surface_y: float, extent: float) -> void:
	_water_surface = surface_y
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * extent * 2.0
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.position.y = surface_y
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/water.gdshader")
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _add_portal(pos: Vector3, facing: Vector3, destination: String, color_a: Color, color_b: Color) -> Portal:
	var portal := Portal.new().setup(destination, color_a, color_b)
	portal.position = pos
	# The portal's front is -Z; turn it to face `facing`.
	portal.rotation.y = atan2(-facing.x, -facing.z)
	portal.entered.connect(func(dest: String) -> void: portal_entered.emit(dest))
	add_child(portal)
	return portal


## Test the whole collision capsule, not only a walkable ground column.
func enemy_spawn_clear(pos: Vector3, radius: float, height: float) -> bool:
	if not is_walkable(pos) or is_hazard(pos):
		return false
	var shape := CapsuleShape3D.new()
	shape.radius = radius + 0.08
	shape.height = maxf(height, shape.radius * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), pos + Vector3.UP * (shape.height * 0.5 + 0.12))
	query.collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
