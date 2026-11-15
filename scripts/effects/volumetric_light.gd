class_name VolumetricLight
extends Node
## Volumetric light, in two layers (Options -> Graphics -> Volumetric light):
##
## - Near the camera, a thin sun haze (a FogVolume round the player, see
##   sun_haze.gdshader) in the engine's volumetric fog. The sun's shadows
##   cut it into beams through trees, roofs and windows, and lamps glow in
##   it; it works from the overhead camera too. On the Surface, in the
##   Tavern and on planet ground.
## - Into the distance, SunShafts on screen: rays streaming past anything
##   standing against the sky, as far as the sky reaches. Over the shoulder,
##   in films and in space (past planets, asteroids and ships).
##
## The Atmosphere owns this node and puts `compositor` on its WorldEnvironment;
## SpaceBackdrop reports the Haven sun while the Reach is loaded.

const HAZE_DENSITY := [0.0, 0.008, 0.011, 0.013]  # per quality
const HAZE_HEIGHT := 8.0
const SHAFTS := 0.45  # strength under a full sun
const SPACE_SHAFTS := 0.7  # the Haven sun over the dark of space
const FULL_SUN := 1.35  # the Tavern's and daylight's sun energy

var compositor := Compositor.new()
## The Atmosphere's sun (the Surface, the Tavern, dungeons).
var sun: DirectionalLight3D
## Where the haze gathers (the player).
var anchor: Node3D

var _haze := FogVolume.new()
var _material := ShaderMaterial.new()

static var _space_frame := -10
static var _space_sun := Vector3.UP
static var _space_color := Color.WHITE
static var _space_ground := 0.0


## Called every frame by SpaceBackdrop: the Haven sun, and how far the camera
## is down in a planet's air (0 in orbit, 1 on the ground).
static func use_space_sun(direction: Vector3, color: Color, ground: float) -> void:
	_space_frame = Engine.get_process_frames()
	_space_sun = direction.normalized()
	_space_color = color
	_space_ground = ground


static func in_space() -> bool:
	return Engine.get_process_frames() - _space_frame <= 2


## Whether the haze runs: the engine's volumetric fog must be on for it.
static func haze_allowed(values: Dictionary) -> bool:
	return GraphicsSettings.volumetric_fog_allowed(values) and DisplayServer.get_name() != "headless"


func _ready() -> void:
	compositor.compositor_effects = [SunShafts.new()]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 2
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 128
	noise_tex.height = 128
	noise_tex.seamless = true
	_material.shader = preload("res://shaders/sun_haze.gdshader")
	_material.set_shader_parameter("noise_map", noise_tex)
	_material.set_shader_parameter("height", HAZE_HEIGHT)
	_haze.size = Vector3(220, 90, 220)
	_haze.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_haze.material = _material
	add_child(_haze)
	AppSettings.graphics_changed.connect(_apply_graphics)
	_apply_graphics()


func _apply_graphics() -> void:
	var values := AppSettings.graphics
	SunShafts.quality = GraphicsSettings.level(values, "volumetric_fog") if haze_allowed(values) else 0


func _process(_delta: float) -> void:
	var quality := SunShafts.quality
	var direction := Vector3.UP
	var color := Color.BLACK
	var haze := 0.0
	if in_space():
		direction = _space_sun
		color = _space_color
		SunShafts.tint = Color(color, SPACE_SHAFTS)
		haze = _space_ground
	elif is_instance_valid(sun) and sun.visible:
		direction = sun.global_basis.z.normalized()
		var energy := clampf(sun.light_energy / FULL_SUN, 0.0, 1.2)
		color = sun.light_color
		SunShafts.tint = Color(color, SHAFTS * energy)
		haze = energy
	else:
		SunShafts.tint = Color(0, 0, 0, 0)
	SunShafts.sun_direction = direction
	_haze.visible = quality > 0 and haze > 0.02 and is_instance_valid(anchor)
	if not _haze.visible:
		return
	var up := Vector3.UP
	if anchor is CharacterBody3D:
		up = (anchor as CharacterBody3D).up_direction.normalized()
	var feet := anchor.global_position
	# On a planet the box stands on the local ground.
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	_haze.global_transform = Transform3D(Basis(side, up, side.cross(up)), feet + up * 25.0)
	_material.set_shader_parameter("anchor", feet)
	_material.set_shader_parameter("up", up)
	_material.set_shader_parameter("density", HAZE_DENSITY[quality] * minf(haze, 1.0))
	_material.set_shader_parameter("tint", Color(1.0, 0.97, 0.92).lerp(color, 0.15))
