class_name SunShafts
extends CompositorEffect
## Light shafts from the sun across the screen (crepuscular rays): the open
## sky is masked at a quarter (High: half) of the screen, blurred along lines
## toward the sun, then added onto the scene before glow and tone mapping.
## Shafts reach as far as the sky does, so they carry the far distance that
## the volumetric fog (VolumetricLight, near the camera) cannot. They fade
## out when the camera looks away from the sun, and cost nothing then.
##
## VolumetricLight sets the statics below every frame from the sun in use
## (the Atmosphere's, or the Haven sun in space).

## Toward the sun, world space.
static var sun_direction := Vector3.UP
## Sunlight colour; alpha is the strength (0 = off).
static var tint := Color(1, 1, 1, 0)
## 0 off, 1 low, 2 medium, 3 high (GraphicsSettings "volumetric_fog").
static var quality := 0

const GLOW_RADIUS := 0.32  # radians round the sun where the sky counts fully
const REACH := 1.9  # radians: sky further from the sun gives no rays
const BRIGHTEST := 6.0  # the sun disc is clamped, so it streaks smoothly
## Per quality (1..3): mask divisor, [taps, share of the way, decay] per pass.
const PASSES := {
	1: [4, [[20, 0.85, 0.965]]],
	2: [4, [[14, 0.9, 0.97], [10, 0.065, 1.0]]],
	3: [2, [[18, 0.9, 0.975], [12, 0.05, 1.0]]],
}

var _rd: RenderingDevice
var _mask_shader: RID
var _mask_pipeline: RID
var _blur_shader: RID
var _blur_pipeline: RID
var _nearest: RID
var _linear: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true
	RenderingServer.call_on_render_thread(_setup)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		for rid: RID in [_mask_shader, _blur_shader, _nearest, _linear]:
			if rid.is_valid():
				_rd.free_rid(rid)  # pipelines go with their shaders


func _setup() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	_mask_shader = _rd.shader_create_from_spirv(
			(load("res://shaders/sun_shafts_mask.glsl") as RDShaderFile).get_spirv())
	_mask_pipeline = _rd.compute_pipeline_create(_mask_shader)
	_blur_shader = _rd.shader_create_from_spirv(
			(load("res://shaders/sun_shafts.glsl") as RDShaderFile).get_spirv())
	_blur_pipeline = _rd.compute_pipeline_create(_blur_shader)
	var sampler := RDSamplerState.new()
	sampler.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest = _rd.sampler_create(sampler)
	sampler.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	_linear = _rd.sampler_create(sampler)


func _render_callback(_type: int, render_data: RenderData) -> void:
	if _rd == null or not _blur_pipeline.is_valid() or quality <= 0 or tint.a <= 0.001:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene := render_data.get_render_scene_data()
	if buffers == null or scene == null or buffers.get_view_count() != 1:
		return
	var full := buffers.get_internal_size()
	if full.x < 8 or full.y < 8:
		return
	var eye := scene.get_cam_transform()
	var projection := scene.get_cam_projection()
	var facing := -eye.basis.z.normalized().dot(sun_direction)
	var strength := tint.a * smoothstep(0.02, 0.4, facing)
	if strength <= 0.002:
		return
	var toward := eye.basis.orthonormalized().inverse() * sun_direction
	var clip := projection * Vector4(toward.x, toward.y, toward.z, 0.0)
	if clip.w <= 0.01:
		return
	var sun_uv := Vector2(clip.x / clip.w * 0.5 + 0.5, 0.5 - clip.y / clip.w * 0.5)
	var tan_scale := Vector2(2.0 / projection.x.x, 2.0 / projection.y.y)

	var setup: Array = PASSES[clampi(quality, 1, 3)]
	var divisor: int = setup[0]
	var size := Vector2i(maxi(full.x / divisor, 1), maxi(full.y / divisor, 1))
	var usage := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	var textures: Array[RID] = []
	for name: String in ["a", "b"]:
		textures.append(buffers.create_texture(&"sun_shafts", StringName(name + str(divisor)),
				RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage, RenderingDevice.TEXTURE_SAMPLES_1,
				size, 1, 1, true, false))
	var color := buffers.get_color_layer(0)
	var depth := buffers.get_depth_layer(0)

	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _mask_pipeline)
	_rd.compute_list_bind_uniform_set(list, UniformSetCacheRD.get_cache(_mask_shader, 0, [
			_sampled(0, _nearest, depth), _image(1, color), _image(2, textures[0])]), 0)
	_push(list, [sun_uv.x, sun_uv.y, tan_scale.x, tan_scale.y, size.x, size.y, full.x, full.y,
			GLOW_RADIUS, BRIGHTEST, REACH, 0.0, 0.0, 0.0, 0.0, 0.0])
	_rd.compute_list_dispatch(list, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	var source := 0
	_rd.compute_list_bind_compute_pipeline(list, _blur_pipeline)
	for pass_setup: Array in setup[1]:
		_rd.compute_list_add_barrier(list)
		_rd.compute_list_bind_uniform_set(list, UniformSetCacheRD.get_cache(_blur_shader, 0, [
				_sampled(0, _linear, textures[source]), _image(1, textures[1 - source])]), 0)
		_push(list, [sun_uv.x, sun_uv.y, size.x, size.y, pass_setup[1], pass_setup[2], pass_setup[0], 0.0,
				0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
		_rd.compute_list_dispatch(list, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
		source = 1 - source
	_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_uniform_set(list, UniformSetCacheRD.get_cache(_blur_shader, 0, [
			_sampled(0, _linear, textures[source]), _image(1, color)]), 0)
	_push(list, [sun_uv.x, sun_uv.y, full.x, full.y, 0.0, 0.0, 0.0, 1.0,
			tint.r, tint.g, tint.b, strength, 0.0, 0.0, 0.0, 0.0])
	_rd.compute_list_dispatch(list, ceili(full.x / 8.0), ceili(full.y / 8.0), 1)
	_rd.compute_list_end()


func _push(list: int, values: Array) -> void:
	var bytes := PackedFloat32Array(values).to_byte_array()
	_rd.compute_list_set_push_constant(list, bytes, bytes.size())


static func _sampled(binding: int, sampler: RID, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler)
	uniform.add_id(texture)
	return uniform


static func _image(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture)
	return uniform
