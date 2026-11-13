class_name Obstacle
extends StaticBody3D
## A prefab placed in the world. Arrows chip voxels off it; when its hp runs
## out it bursts into its own voxels, which scatter and fade. Props (like
## lampposts) are indestructible: arrows just stop on them.

signal destroyed(obstacle: Obstacle)

const SHAKE_TIME := 0.15
const SHAKE_AMOUNT := 0.06
const CHIPS_PER_HIT := 6
const BURST_MAX := 260
const HP_PER_SIZE := 10  # prefab.hp is a size rating; health = rating x this
## Obstacles further than this from the camera aren't drawn.
const DRAW_DISTANCE := 110.0

var obstacle_id := ""
var prefab: ObstacleLibrary.Prefab
var biome: BiomeDef
var hp := 1
var indestructible := false
## Online: true while applying another player's hit (it isn't sent back).
var net_remote := false

var _visual := Node3D.new()  # holds the meshes, so a hit can shake them
var _shake := 0.0


func setup(p_id: String, p_prefab: ObstacleLibrary.Prefab, p_biome: BiomeDef,
		p_indestructible := false) -> Obstacle:
	obstacle_id = p_id
	prefab = p_prefab
	biome = p_biome
	hp = prefab.hp * HP_PER_SIZE
	indestructible = p_indestructible
	return self


func _ready() -> void:
	collision_layer = Player.OBSTACLE_LAYER  # so the camera doesn't dodge trees
	add_child(_visual)
	# The dedicated server never draws: collision only, no meshes or lights.
	var drawn := not Net.is_server()
	var meshes: Array = prefab.meshes_for(biome) if drawn else [null, null]
	for i in 2:
		if meshes[i] == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i]
		mi.material_override = VoxModel.glow_material() if i == 1 else VoxModel.material()
		mi.position = prefab.mesh_offset()
		mi.scale = Vector3.ONE * prefab.voxel_size
		mi.visibility_range_end = DRAW_DISTANCE * GraphicsSettings.view_scale()
		mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		_visual.add_child(mi)
	if prefab.has_glow and drawn:
		var light := OmniLight3D.new()
		light.light_color = biome.obstacle_colors[ObstacleLibrary.GLOW_SLOT]
		light.light_energy = 1.6
		light.omni_range = 6.0
		light.light_volumetric_fog_energy = 1.0
		light.position.y = prefab.height * 0.7
		light.distance_fade_enabled = true
		light.distance_fade_begin = 40.0
		light.distance_fade_length = 12.0
		add_child(light)
	for box in prefab.collision_boxes:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box.size
		shape.shape = box_shape
		shape.position = box.get_center()
		add_child(shape)
	set_process(false)


## Sets this obstacle on fire; nearby ground flames can ignite passing actors.
func ignite(height := -1.0, fire_size := 1.0) -> void:
	var fire := VoxelFire.new(fire_size)
	fire.position.y = prefab.height * 0.55 if height < 0.0 else height
	add_child(fire)


func take_hit(hit_position: Vector3, _direction: Vector3, damage := 10) -> void:
	if hp <= 0 or indestructible:
		return
	if Net.is_client() and not net_remote and obstacle_id != "":
		Net.client.obstacle_hit(self, damage, hit_position)  # the others see it too
	hp -= damage
	if hp <= 0:
		_break_apart()
		return
	Debris.burst(get_parent(), self, CHIPS_PER_HIT, hit_position)
	_shake = SHAKE_TIME
	set_process(true)


func _process(delta: float) -> void:
	_shake -= delta
	if _shake <= 0.0:
		_visual.position = Vector3.ZERO
		set_process(false)
		return
	_visual.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * SHAKE_AMOUNT * (_shake / SHAKE_TIME)


func _break_apart() -> void:
	Debris.burst(get_parent(), self, BURST_MAX, global_position + Vector3.UP * prefab.height * 0.4)
	destroyed.emit(self)
	queue_free()
