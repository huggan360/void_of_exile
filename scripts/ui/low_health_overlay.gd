class_name LowHealthOverlay
extends CanvasLayer
## Low health on screen, kept to the edges so you can still play:
##   * pixel-art blood slashes creep in from the corners: a few big ones at
##     15% health, more at 10%, many at 5%, and a lot when you die
##   * under 15% the screen's edges pulse red, harder and faster toward 0
## Stains fade in as you get hurt and out again as you heal.

const STAGES := [0.15, 0.10, 0.05]  # health shares where more stains appear
const PIXEL := 6  # screen pixels per stain pixel
const LAYOUT_SEED := 7331

var stats: PlayerStats
## Our character died (the most blood, steady red).
var dead := false

var _vignette := ColorRect.new()
var _stains: Array[Dictionary] = []  # {node, stage, corner, offset}
var _root := Control.new()
var _shown := 0.0  # 0..4, eased toward the stage
var _time := 0.0
var _last_size := Vector2.ZERO


func _ready() -> void:
	layer = 70  # over the HUD and its dialogs, under the menus
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float edge = min(d.x * 1.7, d.y);
	float v = 1.0 - smoothstep(0.0, 0.16 + strength * 0.14, edge);
	COLOR = vec4(0.7, 0.02, 0.03, v * v * strength);
}"""
	_vignette.material = mat
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)
	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT_SEED
	# Stage 1: big stains in the four corners; later stages add smaller ones.
	var plan := [[1, 4, 20, 26], [2, 6, 14, 19], [3, 12, 9, 15], [4, 26, 7, 18]]
	for spec: Array in plan:
		for i in spec[1]:
			var corner: int = i % 4 if spec[0] < 4 or i < 16 else 4
			var size_px: int = rng.randi_range(spec[2], spec[3])
			var tex := _splat(rng, size_px)
			var node := TextureRect.new()
			node.texture = tex
			node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.size = Vector2(tex.get_width(), tex.get_height()) * PIXEL
			node.pivot_offset = node.size * 0.5
			node.flip_h = corner in [1, 3] or rng.randf() < 0.3
			node.flip_v = false  # drips always run down
			node.modulate.a = 0.0
			_root.add_child(node)
			# How far in from the corner (0..1 of the screen), more inward at later stages.
			var reach: float = 0.04 + 0.05 * spec[0]
			_stains.append({node = node, stage = spec[0], corner = corner,
				offset = Vector2(rng.randf_range(-0.04, reach), rng.randf_range(-0.04, reach * 1.2)),
				edge = rng.randf(), side = rng.randi() % 4})


func _process(delta: float) -> void:
	_time += delta
	var share := 1.0 if stats == null else stats.hp / maxf(1.0, stats.max_hp)
	var stage := 4.0 if dead else (3.0 if share <= STAGES[2] else 2.0 if share <= STAGES[1] else 1.0 if share <= STAGES[0] else 0.0)
	_shown = move_toward(_shown, stage, delta * (3.0 if stage > _shown else 0.8))
	var size := _root.size
	if size != _last_size:
		_last_size = size
		_place(size)
	for s: Dictionary in _stains:
		(s.node as TextureRect).modulate.a = clampf(_shown - (s.stage - 1), 0.0, 1.0) * 0.92
	# The red pulse: from 15% down, stronger and quicker toward 0.
	var danger := 1.0 if dead else clampf((STAGES[0] - share) / STAGES[0], 0.0, 1.0) if share <= STAGES[0] else 0.0
	var rate := lerpf(1.3, 3.2, danger)
	var pulse := 0.5 + 0.5 * sin(_time * TAU * rate * 0.5)
	var strength := 0.0
	if danger > 0.0:
		strength = (0.18 + 0.5 * danger) * (0.55 + 0.45 * pulse) if not dead else 0.45
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", strength)


func _place(size: Vector2) -> void:
	for s: Dictionary in _stains:
		var node: TextureRect = s.node
		var o: Vector2 = s.offset * size
		var p := Vector2.ZERO
		match s.corner:
			0: p = o
			1: p = Vector2(size.x - node.size.x - o.x, o.y)
			2: p = Vector2(o.x, size.y - node.size.y - o.y)
			3: p = size - node.size - o
			_:  # along an edge, toward the middle (death)
				var t: float = 0.2 + 0.6 * s.edge
				match s.side:
					0: p = Vector2(size.x * t, -node.size.y * 0.3)
					1: p = Vector2(size.x * t, size.y - node.size.y * 0.7)
					2: p = Vector2(-node.size.x * 0.3, size.y * t)
					_: p = Vector2(size.x - node.size.x * 0.7, size.y * t)
		node.position = p


## A blood slash in pixel art: one to three tapered horizontal streaks at a
## slight angle (thick in the middle, thin at the ends), darker at their
## edges, with drips hanging off them and spatter flung past their ends.
## n: its height scale; the slash is about 3x as wide as it is tall.
static func _splat(rng: RandomNumberGenerator, n: int) -> ImageTexture:
	var w := n * 3
	var h := maxi(8, int(n * 1.1))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(0.32, 0.01, 0.02)
	var mid := Color(0.55, 0.03, 0.05)
	var light := Color(0.78, 0.09, 0.08)
	var strokes := rng.randi_range(1, 3)
	var slope := rng.randf_range(-0.18, 0.18)
	for k in strokes:
		var thick := h * rng.randf_range(0.12, 0.24) * (1.0 if k == 0 else 0.6)
		var y0 := h * 0.38 + (k - (strokes - 1) * 0.5) * thick * 2.2 - slope * w * 0.5
		var start := int(w * rng.randf_range(0.0, 0.12))
		var stop := int(w * rng.randf_range(0.82, 1.0))
		var phase := rng.randf() * TAU
		for x in range(start, stop):
			var t := float(x - start) / maxf(1.0, stop - start)
			# Heavy where the blade bit in (the first third), thinning to a tail.
			var taper := pow(sin(PI * t), 0.6) * (1.25 - 0.5 * t)
			var half := thick * taper * (0.85 + 0.3 * sin(x * 0.7 + phase))
			var cy := y0 + slope * x + sin(x * 0.23 + phase) * 0.6
			for y in range(int(cy - half), int(cy + half) + 1):
				if y < 0 or y >= h:
					continue
				var edge := absf(y - cy) / maxf(0.5, half)
				var c := dark if edge > 0.7 else (light if edge < 0.25 and rng.randf() < 0.3 else mid)
				img.set_pixel(x, y, c)
			# Drips running down from the underside.
			if rng.randf() < 0.035 and half > 1.0:
				var length := rng.randi_range(2, int(h * 0.45))
				var top := int(cy + half)
				for y in range(top, mini(h, top + length)):
					img.set_pixel(x, y, mid if y < top + length - 1 else dark)
		# Spatter thrown past the tail of the slash.
		for i in rng.randi_range(3, 7):
			var x := stop + rng.randi_range(0, int(w * 0.1))
			var y := int(y0 + slope * x + rng.randf_range(-thick, thick) * 2.0)
			if x >= 0 and x < w and y >= 0 and y < h:
				img.set_pixel(x, y, mid if rng.randf() < 0.6 else dark)
	return ImageTexture.create_from_image(img)
