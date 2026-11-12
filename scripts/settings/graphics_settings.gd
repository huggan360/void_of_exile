class_name GraphicsSettings
extends RefCounted
## Graphics quality: presets (Low / Medium / High) and one setting per
## rendering feature, so weaker PCs can drop the expensive parts. AppSettings
## keeps and saves the values ([graphics] in settings.cfg); this applies them
## to the window (render scale, anti-aliasing, shadow atlases), the renderer
## (quality knobs) and the Atmosphere (environment, sun, ambient particles).
## High is the game's original look.

const PRESETS := ["low", "medium", "high"]
## Every feature: [id, title, [[value, label], ...], hint].
const FEATURES := [
	["render_scale", "Render scale", [[50, "50%"], [67, "67%"], [75, "75%"], [85, "85%"], [100, "100%"]],
		"Renders the 3D world at fewer pixels; the interface stays sharp. The biggest win on weak GPUs."],
	["upscaler", "Upscaling", [["off", "Off (native)"], ["bilinear", "Bilinear"], ["fsr", "AMD FSR 1"], ["fsr2", "AMD FSR 2"]],
		"Off uses native window resolution and bypasses render scaling and reconstruction. Other modes resize a reduced 3D resolution."],
	["antialiasing", "Anti-aliasing", [["off", "Off"], ["fxaa", "FXAA"], ["msaa2", "MSAA 2×"], ["msaa4", "MSAA 4×"], ["taa", "TAA"]],
		"Smooths jagged voxel edges. FXAA is almost free; MSAA is sharper but costs more."],
	["shadows", "Shadows", [["off", "Off"], ["low", "Low"], ["medium", "Medium"], ["high", "High"]],
		"Sun and lamp shadows: resolution, softness and how far they reach."],
	["gi", "Global illumination", [["off", "Off"], ["low", "Low"], ["high", "High"]],
		"Bounce light from the sun, lava and crystals (SDFGI). Expensive."],
	["ambient_occlusion", "Ambient occlusion", [["off", "Off"], ["low", "Low"], ["high", "High"]],
		"Soft contact shadows in corners and under objects (SSAO)."],
	["indirect_light", "Screen-space indirect light", [["off", "Off"], ["low", "Low"], ["high", "High"]],
		"Colored light bouncing between nearby surfaces (SSIL)."],
	["volumetric_fog", "Volumetric fog", [["off", "Off"], ["low", "Low"], ["high", "High"]],
		"Light shafts and glowing haze in caves and dark biomes."],
	["glow", "Glow / bloom", [["off", "Off"], ["on", "On"]],
		"Bright magic, lava and loot beams bleed light."],
	["lights", "Dynamic lights", [["low", "Low"], ["high", "High"]],
		"Low: fewer glowing projectile lights and no shadows from small lamps."],
	["particles", "Ambient particles", [["off", "Off"], ["low", "Low"], ["high", "High"]],
		"Embers, snow, spores and dust drifting around you."],
	["depth_of_field", "Depth of field", [["off", "Off"], ["on", "On"]],
		"On the Surface and in the Tavern, the distance and things close to the camera go softly out of focus."],
]
const PRESET_VALUES := {
	high = {render_scale = 100, upscaler = "off", antialiasing = "msaa2", shadows = "high", gi = "high",
			ambient_occlusion = "high", indirect_light = "high", volumetric_fog = "high", glow = "on",
			lights = "high", particles = "high", depth_of_field = "on"},
	medium = {render_scale = 85, upscaler = "fsr", antialiasing = "fxaa", shadows = "medium", gi = "low",
			ambient_occlusion = "low", indirect_light = "off", volumetric_fog = "low", glow = "on",
			lights = "high", particles = "low", depth_of_field = "on"},
	low = {render_scale = 67, upscaler = "fsr", antialiasing = "fxaa", shadows = "low", gi = "off",
			ambient_occlusion = "off", indirect_light = "off", volumetric_fog = "off", glow = "off",
			lights = "low", particles = "low", depth_of_field = "off"},
}
## Ambient light is lifted a little without global illumination, so caves
## don't turn pitch black.
const NO_GI_AMBIENT := 1.25


static func defaults(preset := "high") -> Dictionary:
	var values: Dictionary = PRESET_VALUES.get(preset, PRESET_VALUES.high).duplicate()
	values.preset = preset
	return values


## A starting preset for this computer: integrated or software GPUs start on
## Medium/Low; everything else on High (the original look).
static func suggested_preset() -> String:
	if DisplayServer.get_name() == "headless":
		return "high"
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			return "medium"
		RenderingDevice.DEVICE_TYPE_CPU, RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
			return "low"
	return "high"


static func feature(id: String) -> Array:
	for f: Array in FEATURES:
		if f[0] == id:
			return f
	return []


static func choices(id: String) -> Array:
	return feature(id)[2].map(func(c: Array) -> Variant: return c[0])


## Keeps only known keys and values; the preset becomes "custom" when the
## values no longer match it.
static func sanitize(value: Dictionary) -> Dictionary:
	var preset := str(value.get("preset", "high"))
	var result := defaults(preset if preset in PRESETS else "high")
	for f: Array in FEATURES:
		var id: String = f[0]
		if value.has(id) and value[id] in choices(id):
			result[id] = value[id]
	if result.upscaler=="off": result.render_scale = 100
	result.preset = matching_preset(result)
	return result


static func matching_preset(values: Dictionary) -> String:
	for preset: String in PRESETS:
		var same := true
		for id: String in PRESET_VALUES[preset]:
			if values.get(id) != PRESET_VALUES[preset][id]:
				same = false
				break
		if same:
			return preset
	return "custom"


static func level(values: Dictionary, id: String) -> int:
	## off / low / medium / high as 0..3 ("on" = 3), for the feature knobs.
	return {"off": 0, "low": 1, "medium": 2, "high": 3, "on": 3}.get(values.get(id, "high"), 3)


## Window and renderer-wide parts. `base_scale` is the fullscreen-resolution
## ratio AppSettings already works out.
static func apply_viewport(viewport: Viewport, values: Dictionary, base_scale: float) -> void:
	var scale := 1.0 if str(values.upscaler) == "off" else clampf(base_scale * float(values.render_scale) / 100.0, 0.25, 2.0)
	viewport.scaling_3d_scale = scale
	# Native resolution bypasses reconstruction, even if FSR remains selected.
	# FSR 2 at 1:1 still accumulates history and can trail moving voxel art.
	var temporal_upscale := str(values.upscaler) == "fsr2" and scale < 0.999
	match str(values.upscaler):
		"fsr2":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if temporal_upscale else Viewport.SCALING_3D_MODE_BILINEAR
		"fsr":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		_:
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var aa := str(values.antialiasing)
	viewport.msaa_3d = Viewport.MSAA_4X if aa == "msaa4" else Viewport.MSAA_2X if aa == "msaa2" else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED
	# FSR 2 brings its own temporal AA.
	viewport.use_taa = aa == "taa" and not temporal_upscale
	var shadows := level(values, "shadows")
	viewport.positional_shadow_atlas_size = [256, 1024, 2048, 2048][shadows]
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.directional_shadow_atlas_set_size([256, 1024, 2048, 4096][shadows], true)
	var soft: int = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_HARD,
			RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][shadows]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)
	# Depth of field: the default (Low) blurs at half resolution with few
	# samples, which shimmers on fine voxel detail while the camera moves.
	# Hexagon at High runs at full size with 24 samples; no jitter (it crawls without TAA).
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_HEXAGON)
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH, false)
	# High keeps the project's own renderer settings (the original look).
	var high_gi := level(values, "gi") >= 3
	RenderingServer.gi_set_use_half_resolution(not high_gi or _project("global_illumination/gi/use_half_resolution", false))
	RenderingServer.environment_set_sdfgi_ray_count(_project("global_illumination/sdfgi/probe_ray_count", 1) if high_gi
			else 0)  # 4 rays
	RenderingServer.environment_set_sdfgi_frames_to_converge(_project("global_illumination/sdfgi/frames_to_converge", 5)
			if high_gi else 5)  # 24 frames
	RenderingServer.environment_set_sdfgi_frames_to_update_light(
			_project("global_illumination/sdfgi/frames_to_update_lights", 2) if high_gi
			else 3)  # 8 frames
	var high_ao := level(values, "ambient_occlusion") >= 3
	RenderingServer.environment_set_ssao_quality(_project("environment/ssao/quality", 2) if high_ao
			else RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 2 if high_ao else 1, 50.0, 300.0)
	var high_ssil := level(values, "indirect_light") >= 3
	RenderingServer.environment_set_ssil_quality(_project("environment/ssil/quality", 2) if high_ssil
			else RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, true, 0.5, 4 if high_ssil else 2, 50.0, 300.0)
	var high_fog := level(values, "volumetric_fog") >= 3
	var fog_size: int = _project("environment/volumetric_fog/volume_size", 64)
	var fog_depth: int = _project("environment/volumetric_fog/volume_depth", 64)
	RenderingServer.environment_set_volumetric_fog_volume_size(fog_size if high_fog else fog_size * 5 / 8,
			fog_depth if high_fog else fog_depth * 5 / 8)
	RenderingServer.environment_set_volumetric_fog_filter_active(high_fog and _project("environment/volumetric_fog/use_filter", 1) != 0)


static func _project(setting: String, fallback: Variant) -> Variant:
	return ProjectSettings.get_setting("rendering/" + setting, fallback)


## The world's look: environment effects, the sun's shadows, particles.
static func apply_atmosphere(env: Environment, sun: DirectionalLight3D, values: Dictionary) -> void:
	var gi := level(values, "gi")
	env.sdfgi_enabled = gi > 0
	env.sdfgi_cascades = 6 if gi >= 3 else 4
	# Thin procedural walls need leak prevention at both GI quality levels.
	env.sdfgi_use_occlusion = gi > 0
	# Keep bounce subordinate to the authored lighting. Large-radius SSIL can
	# paint visible patches across flat floors as objects enter/leave the view.
	env.sdfgi_energy = 0.7
	env.ssao_radius = 0.55
	env.ssao_intensity = 0.65
	env.ssao_power = 1.0
	env.ssao_light_affect = 0.0
	env.ssil_intensity = 0.2
	env.ssil_radius = 1.0
	env.ssao_enabled = level(values, "ambient_occlusion") > 0
	env.ssil_enabled = level(values, "indirect_light") > 0
	env.glow_enabled = values.glow == "on"
	# A small sun disc: soft contact-hardening edges without the grain a wide
	# penumbra gets over large outdoor scenes at these filter sample counts.
	sun.light_angular_distance = 0.5
	sun.shadow_blur = 1.0
	var shadows := level(values, "shadows")
	sun.shadow_enabled = shadows > 0
	sun.directional_shadow_max_distance = [40.0, 45.0, 60.0, 80.0][shadows]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if shadows >= 2 \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# Cross-fade the cascades so there is no visible seam where one ends.
	sun.directional_shadow_blend_splits = shadows >= 2


static func volumetric_fog_allowed(values: Dictionary) -> bool:
	return level(values, "volumetric_fog") > 0


static func ambient_factor(values: Dictionary) -> float:
	return 1.0 if level(values, "gi") > 0 else NO_GI_AMBIENT


static func particle_ratio(values: Dictionary) -> float:
	return [0.0, 0.35, 0.35, 1.0][level(values, "particles")]


## How many enemy projectiles may carry a real light at once.
static func projectile_lights(values: Dictionary) -> int:
	return 12 if values.get("lights", "high") == "high" else 3


static func lamp_shadows(values: Dictionary) -> bool:
	return values.get("lights", "high") == "high" and level(values, "shadows") >= 2
