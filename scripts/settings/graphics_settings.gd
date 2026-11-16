class_name GraphicsSettings
extends RefCounted
## Graphics quality: presets (Low / Medium / High) and one setting per
## rendering feature, so weaker PCs can drop the expensive parts. AppSettings
## keeps and saves the values ([graphics] in settings.cfg); this applies them
## to the window (render scale, anti-aliasing, shadow atlases), the renderer
## (quality knobs) and the Atmosphere (environment, sun, ambient particles).
## High is the game's original look.

const PRESETS := ["low", "medium", "high"]
## Every feature: [id, title, [[value, label], ...], hint]. A slider has
## {min, max, step} in place of the choices.
const FEATURES := [
	["upscaler", "Upscaling", [["off", "Off (native)"], ["bilinear", "Bilinear"], ["fsr", "AMD FSR 1"], ["fsr2", "AMD FSR 2"]],
		"Renders the 3D world at fewer pixels and scales it up to the window; the interface stays sharp. FSR 2 rebuilds detail over several frames and smooths edges itself. Off draws at native resolution."],
	["render_scale", "Render scale", [[50, "50%"], [67, "67%"], [75, "75%"], [85, "85%"], [100, "100%"]],
		"How many pixels the upscaler starts from. The biggest win on weak GPUs."],
	["supersampling", "Supersampling", [[100, "Off"], [150, "1.5x (2.25 samples)"], [200, "2x (4 samples)"]],
		"Renders more pixels than the window has and shrinks them down: the cleanest edges, at a high cost (2x draws four times the pixels)."],
	["sharpness", "Sharpening", {min = 0, max = 100, step = 5},
		"How much the AMD FSR sharpening pass brings back crisp edges after upscaling or FSR 2 smoothing."],
	["antialiasing", "Anti-aliasing", [["off", "Off"], ["fxaa", "FXAA"], ["smaa", "SMAA"], ["taa", "TAA"], ["native", "FSR 2 Native AA"]],
		"Smooths edges after the frame is drawn, including edges against depth of field blur. FXAA is almost free, SMAA is cleaner, TAA blends frames over time. FSR 2 Native AA runs FSR 2 at full resolution (AMD's counterpart of DLAA): the smoothest result, with slight trails on fast movement."],
	["msaa", "MSAA", [["off", "Off"], ["2x", "2x"], ["4x", "4x"], ["8x", "8x"]],
		"Multisampling on the edges of voxels and models. Sharp and stable; works together with the anti-aliasing above. 8x is the most the renderer offers."],
	["shadows", "Shadows", [["off", "Off"], ["low", "Low"], ["medium", "Medium"], ["high", "High"]],
		"Sun and lamp shadows: resolution, softness and how far they reach."],
	["gi", "Global illumination", [["off", "Off"], ["low", "Low"], ["high", "High"]],
		"Bounce light from the sun, lava and crystals (SDFGI). Expensive."],
	["ambient_occlusion", "Ambient occlusion", [["off", "Off"], ["low", "Low"], ["high", "High"]],
		"Soft contact shadows in corners and under objects (SSAO)."],
	["indirect_light", "Screen-space indirect light", [["off", "Off"], ["low", "Low"], ["high", "High"]],
		"Colored light bouncing between nearby surfaces (SSIL)."],
	["volumetric_fog", "Volumetric light", [["off", "Off"], ["low", "Low"], ["medium", "Medium"], ["high", "High"]],
		"Sunbeams through trees and windows, rays across the sky, glowing haze round lamps and in dark biomes. Low costs little; High is sharpest."],
	["lights", "Dynamic lights", [["low", "Low"], ["high", "High"]],
		"Low: fewer glowing projectile lights and no shadows from small lamps."],
	["glow", "Glow / bloom", [["off", "Off"], ["on", "On"]],
		"Bright magic, lava and loot beams bleed light."],
	["depth_of_field", "Depth of field", [["off", "Off"], ["on", "On"]],
		"On the Surface and in the Tavern, the distance and things close to the camera go softly out of focus. Pair it with an anti-aliasing method (SMAA, TAA or FSR 2) so the edges in front of the blur stay smooth."],
	["particles", "Ambient particles", [["off", "Off"], ["low", "Low"], ["high", "High"]],
		"Embers, snow, spores and dust drifting around you."],
	["view_distance", "View distance", [["short", "Short"], ["medium", "Medium"], ["far", "Far"]],
		"How far terrain, trees, plants, rocks and planet towns are drawn on the Surface and on planets. Short helps weaker PCs the most. Takes full effect on the next load."],
]
## How the Options page groups them.
const SECTIONS := [
	["Resolution and scaling", ["upscaler", "render_scale", "supersampling", "sharpness"]],
	["Anti-aliasing", ["antialiasing", "msaa"]],
	["Lighting and shadows", ["shadows", "gi", "ambient_occlusion", "indirect_light", "volumetric_fog", "lights"]],
	["Effects", ["glow", "depth_of_field", "particles"]],
	["World", ["view_distance"]],
]
const PRESET_VALUES := {
	high = {upscaler = "off", render_scale = 100, supersampling = 100, sharpness = 80, antialiasing = "smaa", msaa = "2x",
			shadows = "high", gi = "high", ambient_occlusion = "high", indirect_light = "high", volumetric_fog = "high",
			glow = "on", lights = "high", particles = "high", depth_of_field = "on", view_distance = "far"},
	medium = {upscaler = "fsr", render_scale = 85, supersampling = 100, sharpness = 80, antialiasing = "fxaa", msaa = "off",
			shadows = "medium", gi = "low", ambient_occlusion = "low", indirect_light = "off", volumetric_fog = "medium",
			glow = "on", lights = "high", particles = "low", depth_of_field = "on", view_distance = "medium"},
	low = {upscaler = "fsr", render_scale = 67, supersampling = 100, sharpness = 80, antialiasing = "fxaa", msaa = "off",
			shadows = "low", gi = "off", ambient_occlusion = "off", indirect_light = "off", volumetric_fog = "off",
			glow = "off", lights = "low", particles = "low", depth_of_field = "off", view_distance = "short"},
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


static func is_slider(id: String) -> bool:
	return feature(id)[2] is Dictionary


## Keeps only known keys and values; the preset becomes "custom" when the
## values no longer match it.
static func sanitize(value: Dictionary) -> Dictionary:
	var preset := str(value.get("preset", "high"))
	var result := defaults(preset if preset in PRESETS else "high")
	value = value.duplicate()
	# Before 26.4 MSAA was one of the anti-aliasing choices; it now pairs with SMAA,
	# which also smooths the edges depth of field leaves jagged.
	if str(value.get("antialiasing", "")) in ["msaa2", "msaa4"]:
		value.msaa = str(value.antialiasing).trim_prefix("msaa") + "x"
		value.antialiasing = "smaa"
	for f: Array in FEATURES:
		var id: String = f[0]
		if not value.has(id): continue
		if is_slider(id):
			var limits: Dictionary = f[2]
			result[id] = clampi(int(value[id]), int(limits.min), int(limits.max))
		elif value[id] in choices(id):
			result[id] = value[id]
	if result.upscaler=="off": result.render_scale = 100
	else: result.supersampling = 100
	result.preset = matching_preset(result)
	return result


## Why a feature does nothing with these values ("" when it is in use): the
## Options page hides or greys its row, as games do for settings another overrides.
static func overridden(values: Dictionary, id: String) -> String:
	var upscaler := str(values.get("upscaler", "off"))
	match id:
		"render_scale":
			if upscaler=="off": return "hide"
		"supersampling":
			if upscaler!="off" or str(values.get("antialiasing", ""))=="native": return "hide"
		"sharpness":
			if not (upscaler in ["fsr", "fsr2"] or str(values.get("antialiasing", ""))=="native"): return "hide"
		"antialiasing":
			if upscaler=="fsr2": return "AMD FSR 2 upscaling already smooths edges."
	return ""


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
	var upscaler := str(values.upscaler)
	var aa := str(values.antialiasing)
	var native := aa=="native" and upscaler!="fsr2"
	var scale := base_scale*float(values.supersampling)/100.0 if upscaler=="off" else base_scale*float(values.render_scale)/100.0
	scale = clampf(scale, 0.25, 1.0 if native else 2.0)  # FSR 2 never renders above the window
	viewport.scaling_3d_scale = scale
	# FSR 2 upscales from fewer pixels, or (Native AA) runs at full size just to smooth.
	var temporal := native or (upscaler=="fsr2" and scale<0.999)
	if temporal: viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	elif upscaler=="fsr" and scale<1.0: viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	else: viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.fsr_sharpness = (100.0-float(values.sharpness))/50.0  # 0 is sharpest, 2 softest
	viewport.msaa_3d = {"2x": Viewport.MSAA_2X, "4x": Viewport.MSAA_4X, "8x": Viewport.MSAA_8X}.get(str(values.msaa), Viewport.MSAA_DISABLED)
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if aa=="smaa" else Viewport.SCREEN_SPACE_AA_FXAA if aa=="fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = aa=="taa" and not temporal
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
	# Hexagon at High runs at full size with 24 samples. Jittered samples hide
	# the last sampling lines, but only a frame-blending method (TAA, FSR 2)
	# settles their noise; without one the jitter crawls.
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_HEXAGON)
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH, temporal or viewport.use_taa)
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
	# Froxel grid per quality: Low 40 x 40 x 40, Medium 48, High 64 (filtered).
	var fog := level(values, "volumetric_fog")
	var fog_size: int = _project("environment/volumetric_fog/volume_size", 64)
	var fog_depth: int = _project("environment/volumetric_fog/volume_depth", 64)
	var fog_share: float = [0.625, 0.625, 0.75, 1.0][fog]
	RenderingServer.environment_set_volumetric_fog_volume_size(int(fog_size * fog_share), int(fog_depth * fog_share))
	RenderingServer.environment_set_volumetric_fog_filter_active(fog >= 2 and _project("environment/volumetric_fog/use_filter", 1) != 0)


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
	# Volumetric light: a little forward scattering, so beams glow when you
	# look toward the sun but still read from the overhead camera; distance
	# fog picks up the sky's colour and a warm glow toward the sun, layering
	# the far land (free, and off with the setting for a fair comparison).
	var volumetric := volumetric_fog_allowed(values)
	env.volumetric_fog_anisotropy = 0.3
	env.volumetric_fog_length = volumetric_length(values)
	env.fog_aerial_perspective = 0.35 if volumetric else 0.0
	env.fog_sun_scatter = 0.25 if volumetric else 0.0
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


## How far from the camera volumetric fog is drawn (the froxels thin out
## with distance, so more reach costs detail near by, not time).
static func volumetric_length(values: Dictionary) -> float:
	return [64.0, 64.0, 96.0, 128.0][level(values, "volumetric_fog")]


static func ambient_factor(values: Dictionary) -> float:
	return 1.0 if level(values, "gi") > 0 else NO_GI_AMBIENT


static func particle_ratio(values: Dictionary) -> float:
	return [0.0, 0.35, 0.35, 1.0][level(values, "particles")]


## Multiplier for draw and streaming distances (Surface and planets). The
## headless server always streams at full range.
static func view_scale(values: Dictionary = {}) -> float:
	if DisplayServer.get_name() == "headless":
		return 1.0
	var v: Dictionary = values if not values.is_empty() else AppSettings.graphics
	return {"short": 0.6, "medium": 0.8}.get(str(v.get("view_distance", "far")), 1.0)


## How many enemy projectiles may carry a real light at once.
static func projectile_lights(values: Dictionary) -> int:
	return 12 if values.get("lights", "high") == "high" else 3


static func lamp_shadows(values: Dictionary) -> bool:
	return values.get("lights", "high") == "high" and level(values, "shadows") >= 2
