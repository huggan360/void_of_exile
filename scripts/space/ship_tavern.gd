class_name ShipTavern
extends Node3D
## The crew table's live side in a ship room (clients): four glasses whose
## beer level follows the ship's state and sloshes as the ship speeds up and
## turns, and cigar smoke rising from whoever is smoking in an armchair.
var world: SpaceWorld
var slot := 0
var anchors := {}
var _glasses: Array = []  # [liquid material, tilt, tilt speed]
var _smoke := {}  # pid -> GPUParticles3D
var _last_origin := Vector3.INF
var _last_velocity := Vector3.ZERO
var _last_basis := Basis.IDENTITY
static var _glass_material: StandardMaterial3D
static var _glass_mesh: CylinderMesh
static var _liquid_mesh: CylinderMesh
const HEIGHT := 0.3

func _ready() -> void:
	if _glass_material==null:
		_glass_material = StandardMaterial3D.new()
		_glass_material.albedo_color = Color(0.85, 0.95, 1.0, 0.22)
		_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_material.roughness = 0.04
		_glass_material.metallic_specular = 1.0
		_glass_material.rim_enabled = true
		_glass_material.rim = 0.6
		_glass_mesh = CylinderMesh.new()
		_glass_mesh.top_radius = 0.1
		_glass_mesh.bottom_radius = 0.085
		_glass_mesh.height = HEIGHT+0.04
		_glass_mesh.cap_top = false
		_liquid_mesh = CylinderMesh.new()
		_liquid_mesh.top_radius = 0.092
		_liquid_mesh.bottom_radius = 0.078
		_liquid_mesh.height = HEIGHT
	var candle := OmniLight3D.new()
	candle.position = Vector3(-4.7, 1.5, 6.2)
	candle.light_color = Color("ffb36a")
	candle.light_energy = 0.9
	candle.omni_range = 4.5
	candle.shadow_enabled = false
	add_child(candle)
	for at: Vector3 in anchors.get("glasses", []):
		var glass := MeshInstance3D.new()
		glass.mesh = _glass_mesh
		glass.material_override = _glass_material
		glass.position = at+Vector3.UP*(HEIGHT*0.5+0.02)
		glass.sorting_offset = 1.0
		add_child(glass)
		var liquid := MeshInstance3D.new()
		liquid.mesh = _liquid_mesh
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/beer_liquid.gdshader")
		material.set_shader_parameter("height", HEIGHT)
		liquid.material_override = material
		liquid.position = at+Vector3.UP*(HEIGHT*0.5+0.03)
		add_child(liquid)
		var handle := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.05
		ring.outer_radius = 0.075
		handle.mesh = ring
		handle.material_override = _glass_material
		handle.position = at+Vector3(0.12, HEIGHT*0.55, 0)
		handle.rotation.x = PI*0.5
		add_child(handle)
		_glasses.append([material, Vector2.ZERO, Vector2.ZERO])

func _process(delta: float) -> void:
	var ship := world.ship_in_slot(slot)
	if ship==null or delta<=0.0: return
	# Slosh: the ship's acceleration and turning, felt in the room's frame.
	var view: SpaceShipView = world.ship_views.get(ship.id)
	var pose := view.global_transform if view else ship.xform
	var push := Vector2.ZERO
	if _last_origin.is_finite():
		var velocity := (pose.origin-_last_origin)/delta
		var accel := pose.basis.inverse()*(velocity-_last_velocity)/delta
		var turn := (_last_basis.inverse()*pose.basis).get_euler()/delta
		push = Vector2(accel.x, accel.z).limit_length(400.0)*0.0006+Vector2(turn.z, -turn.x)*0.05
		_last_velocity = velocity
	_last_origin = pose.origin
	_last_basis = pose.basis
	var t := Time.get_ticks_msec()/1000.0
	for i in _glasses.size():
		var entry: Array = _glasses[i]
		var tilt: Vector2 = entry[1]
		var speed: Vector2 = entry[2]
		# A spring: pushed by the ship, pulled level again, a tiny idle wobble.
		speed += (-tilt*60.0-speed*3.2)*delta-push
		tilt += speed*delta
		tilt = tilt.limit_length(0.9)
		entry[1] = tilt
		entry[2] = speed
		var material: ShaderMaterial = entry[0]
		material.set_shader_parameter("tilt", tilt+Vector2(sin(t*2.1+i), cos(t*1.7+i))*0.02)
		material.set_shader_parameter("fill", clampf(float(ship.glasses[i]) if i<ship.glasses.size() else 0.0, 0.0, 1.0)*0.85)
	_update_smoke(ship)

func _update_smoke(ship: SpaceShip) -> void:
	for pid: int in _smoke.keys():
		if not ship.smoking.has(pid):
			(_smoke[pid] as GPUParticles3D).emitting = false
			_smoke[pid].get_tree().create_timer(4.0).timeout.connect(_smoke[pid].queue_free)
			_smoke.erase(pid)
	for pid: int in ship.smoking:
		if _smoke.has(pid): continue
		var seat := ship.seat_of(pid)
		var spec: Dictionary = anchors.get("seats", {}).get(seat, {})
		if spec.is_empty(): continue
		_smoke[pid] = _puffs((spec.pos as Vector3)+Basis(Vector3.UP, float(spec.yaw))*Vector3(0.18, 1.32, -0.35))

## Soft grey puffs rising from a cigar, with its glowing tip.
func _puffs(at: Vector3) -> GPUParticles3D:
	var puffs := GPUParticles3D.new()
	puffs.position = at
	puffs.amount = 26
	puffs.lifetime = 3.5
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 18.0
	process.initial_velocity_min = 0.15
	process.initial_velocity_max = 0.35
	process.gravity = Vector3(0, 0.12, 0)
	process.scale_min = 0.6
	process.scale_max = 1.6
	process.damping_min = 0.2
	process.damping_max = 0.4
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(1, 1.6))
	var curve := CurveTexture.new()
	curve.curve = grow
	process.scale_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.85, 0.9, 0.5))
	fade.set_color(1, Color(0.85, 0.85, 0.9, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	puffs.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*0.18
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = SpaceBackdrop._soft_dot()
	quad.material = mat
	puffs.draw_pass_1 = quad
	add_child(puffs)
	var ember := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	ember.mesh = dot
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ff7a3a")
	glow.emission_enabled = true
	glow.emission = Color("ff7a3a")
	glow.emission_energy_multiplier = 4.0
	ember.material_override = glow
	puffs.add_child(ember)
	return puffs
