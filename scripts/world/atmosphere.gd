class_name Atmosphere
extends Node
## Owns the sky, sun, fog, ambient particles and fog-of-war style, and blends
## them smoothly toward the biome the player is standing in.
##
## What tints the whole screen (sky, sun, ambient light, distance fog) only
## takes part of a biome's own look, mixed with plain daylight
## (Biomes.DAY, the Tavern's warm light), so moving between biomes shifts the
## mood gently instead of filtering everything. Biomes with a strong mood
## (BiomeDef.mood) take more of their own look: the Deep Dark takes all of it. The sun keeps one direction, so shadows never swing
## around. The fog of war is colored by region instead (see FogOfWar): from
## the forest you still see sandy fog over the desert.

const BLEND_SPEED := 0.8  # per second; ~1-2 s to settle into a new biome
const FLOATS := ["sun_energy", "sun_pitch", "sun_yaw", "ambient_energy", "fog_density",
		"volumetric_fog_density", "reveal_radius", "fog_of_war_opacity", "torch_energy",
		"particle_hue_variation"]
const COLORS := ["sky_top_color", "sky_horizon_color", "sun_color", "fog_color",
		"fog_of_war_color", "particle_color"]
const VECTORS := ["particle_velocity"]
## How much of a biome's own look reaches each screen-wide setting (the rest
## is plain daylight). Anything not listed takes the biome's look fully.
const SCREEN_INFLUENCE := {
	sky_top_color = 0.5, sky_horizon_color = 0.45, sun_color = 0.3, sun_energy = 0.4,
	ambient_energy = 0.4, fog_color = 0.3, fog_density = 0.4, volumetric_fog_density = 0.4,
	sun_pitch = 0.0, sun_yaw = 0.0,
}

var env := Environment.new()
var sun := DirectionalLight3D.new()
var particles := GPUParticles3D.new()
var fog_of_war: FogOfWar
## Debug: force fog of war off (F4).
var fog_of_war_hidden := false

var _current := BiomeDef.new()
var _settled := false
var _target: BiomeDef
var _sky_mat := ProceduralSkyMaterial.new()
var _neutral := Biomes.neutral()


func _ready() -> void:
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Keep the biome sky and horizon visible from ground-level camera views.
	env.fog_sky_affect = 0.25
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	# AgX keeps highlights soft but mutes colors: a gentle grade brings back
	# rich, vibrant color and a little depth.
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	# SDFGI, SSAO, SSIL, glow and shadows follow the quality settings
	# (_apply_graphics).
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.fog_enabled = true
	# Let glowing blocks and bounce light (from SDFGI) light up the volumetric
	# fog too, not just the lamps: lava and crystals get visible halos.
	env.volumetric_fog_gi_inject = 0.5
	env.volumetric_fog_length = 80.0

	add_child(sun)
	_setup_particles()
	AppSettings.graphics_changed.connect(_apply_graphics)
	_apply_graphics()


## The player's quality settings (GraphicsSettings): which effects run.
func _apply_graphics() -> void:
	GraphicsSettings.apply_atmosphere(env, sun, AppSettings.graphics)
	if _target:
		_apply()


## How strong the character's torch should be right now (blended).
func torch_energy() -> float:
	return _current.torch_energy


## Jump straight to a biome's look (used when arriving in a world).
func snap_to(biome: BiomeDef) -> void:
	_set_palette(biome)
	_target = biome
	_blend(1.0)


func blend_to(biome: BiomeDef, delta: float) -> void:
	if biome != _target:
		_settled = false
		_set_palette(biome)
	_target = biome
	if fog_of_war: fog_of_war.visible = _target.fog_of_war_enabled and not fog_of_war_hidden
	if _settled: return
	_blend(1.0 - exp(-BLEND_SPEED * delta * 3.0))


func _blend(t: float) -> void:
	var remaining := 0.0
	for prop in FLOATS:
		var goal: float = _goal(prop)
		_current.set(prop, lerpf(_current.get(prop), goal, t))
		remaining = maxf(remaining,absf(float(_current.get(prop))-goal))
	for prop in COLORS:
		var goal: Color = _goal(prop)
		_current.set(prop, (_current.get(prop) as Color).lerp(goal, t))
		var difference: Color = _current.get(prop)-goal
		remaining = maxf(remaining,maxf(absf(difference.r),maxf(absf(difference.g),absf(difference.b))))
	for prop in VECTORS:
		_current.set(prop, (_current.get(prop) as Vector3).lerp(_target.get(prop), t))
		remaining = maxf(remaining,(_current.get(prop) as Vector3).distance_to(_target.get(prop)))
	_apply()
	_settled = remaining<.0001


## Where a setting is heading: the biome's look, or for screen-wide settings
## outdoors, its look mixed with plain daylight.
func _goal(prop: String) -> Variant:
	var own: Variant = _target.get(prop)
	if _target.indoor or not SCREEN_INFLUENCE.has(prop):
		return own
	var k: float = SCREEN_INFLUENCE[prop]
	k = 1.0 - (1.0 - k) * (1.0 - _target.mood)
	if own is Color:
		return (_neutral.get(prop) as Color).lerp(own, k)
	var value := lerpf(_neutral.get(prop), own, k)
	# Keep realm colors readable at the farther camera distance. Indoor
	# atmospheres (including the Tavern) and fog of war retain their style.
	if prop in ["fog_density", "volumetric_fog_density"]:
		value *= 0.5
	return value


func _apply() -> void:
	var c := _current
	_sky_mat.sky_top_color = c.sky_top_color
	_sky_mat.sky_horizon_color = c.sky_horizon_color
	_sky_mat.ground_horizon_color = c.sky_horizon_color
	_sky_mat.ground_bottom_color = c.fog_color.darkened(0.5)
	var graphics := AppSettings.graphics
	env.ambient_light_energy = c.ambient_energy * GraphicsSettings.ambient_factor(graphics)
	env.fog_light_color = c.fog_color
	env.fog_density = c.fog_density
	env.volumetric_fog_enabled = c.volumetric_fog_density > 0.001 and GraphicsSettings.volumetric_fog_allowed(graphics)
	env.volumetric_fog_density = c.volumetric_fog_density
	env.volumetric_fog_albedo = c.fog_color.lightened(0.4)
	sun.light_color = c.sun_color
	sun.light_energy = c.sun_energy
	sun.rotation_degrees = Vector3(-c.sun_pitch, c.sun_yaw, 0)

	var pm := particles.process_material as ParticleProcessMaterial
	pm.direction = c.particle_velocity.normalized()
	pm.initial_velocity_min = c.particle_velocity.length() * 0.6
	pm.initial_velocity_max = c.particle_velocity.length() * 1.2
	particles.amount_ratio = c.particle_color.a * GraphicsSettings.particle_ratio(graphics)
	particles.emitting = particles.amount_ratio > 0.0
	pm.color = Color(c.particle_color, 1.0)
	pm.hue_variation_min = -c.particle_hue_variation
	pm.hue_variation_max = c.particle_hue_variation

	if fog_of_war:
		fog_of_war.visible = _target.fog_of_war_enabled and not fog_of_war_hidden
		fog_of_war.set_style(c.fog_of_war_color, c.reveal_radius, c.fog_of_war_opacity)


## A biome's particle palette: each new particle picks one of its colors at
## random (rare colors get a thin slice). Old particles keep theirs and fade
## out over their lifetime, so the change is gradual.
func _set_palette(biome: BiomeDef) -> void:
	var pm := particles.process_material as ParticleProcessMaterial
	if biome.particle_palette.is_empty():
		pm.color_initial_ramp = null
		return
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array()
	ramp.colors = PackedColorArray()
	for stop: Array in biome.particle_palette:
		ramp.add_point(stop[0], stop[1])
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_initial_ramp = tex


## Embers / snow / spores / dust drifting around the player.
func _setup_particles() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20, 6, 20)
	pm.spread = 25.0
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	particles.process_material = pm
	particles.amount = 800
	particles.lifetime = 6.0
	particles.preprocess = 6.0
	particles.visibility_aabb = AABB(Vector3(-30, -15, -30), Vector3(60, 30, 60))
	particles.position.y = 4.0

	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true  # each particle's own (possibly rainbow) color
	quad.material = mat
	particles.draw_pass_1 = quad


## Particles follow this node (the player).
func attach_particles(to: Node3D) -> void:
	if particles.get_parent():
		particles.reparent(to, false)
	else:
		to.add_child(particles)
