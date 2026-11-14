class_name FilmSet
extends Node3D
## Everything a film needs in the world while it plays (see Cutscenes):
## its shots turned into world positions, the stage (a scene loaded far from
## the world), the cast, looming shadows and fireworks. CampaignCinematic asks
## it whether a place has streamed in before a shot fades up, and keeps the
## camera out of the ground. Freed when the film ends.
var world: GameWorld
var player: Player
var stage: Node3D
var _cast: CutsceneActors
var _last_ready := Vector3.INF
var _by_shot: Array = []  # {nodes, shots, start}: actors only in some shots
var _crowns := {}  # shot index -> [[Vector2 centre, radius, bottom, top], ...]: tree crowns (no colliders)

## A resolved copy of `film`: every shot has from/to/look_from/look_to (and
## focus) in world space, or is a black title card.
func prepare(film: Dictionary, p_world: GameWorld, p_player: Player) -> Dictionary:
	world = p_world
	player = p_player
	var out := film.duplicate(true)
	_build_stage(out)
	for i in out.get("shots", []).size():
		var shot: Dictionary = out.shots[i]
		_resolve_shot(shot, out)
		_crowns[i] = _crowns_along(shot)
	_cast = CutsceneActors.new()
	add_child(_cast)
	for actor: Dictionary in out.get("actors", []):
		_add_actor(actor)
	return out

# --- Places -----------------------------------------------------------------

func _resolve_shot(shot: Dictionary, film: Dictionary) -> void:
	if shot.has("title") and not shot.has("from") and not _placed(shot): return  # a card on black
	var frame := Transform3D.IDENTITY
	var spec: Dictionary = shot
	if shot.has("village"):
		_village_shot(shot, film)
		return
	elif shot.has("from_marker"):
		shot.from = _marker(shot.from_marker)
		shot.to = _marker(shot.to_marker)
		shot.look_from = _marker(shot.look_marker)
		shot.look_to = shot.look_from
		shot.focus = shot.get("focus", shot.look_to)
		return
	elif shot.has("stage_at"):
		frame = Transform3D(Basis.IDENTITY, stage.global_position if stage else Vector3.ZERO)
		spec = shot.stage_at
	elif shot.has("space"):
		frame = space_frame(shot.space)
		spec = shot.space
	elif shot.has("place"):
		frame = surface_frame(shot.place, float(shot.get("turn", 0.0)))
	else:
		shot.look_from = shot.get("look_from", shot.get("from", Vector3.ZERO)+Vector3.FORWARD)
		shot.look_to = shot.get("look_to", shot.look_from)
		shot.to = shot.get("to", shot.get("from", Vector3.ZERO))
		shot.focus = shot.get("focus", shot.look_to)
		return
	# Read every offset before writing (for `place` the spec is the shot).
	var from: Vector3 = spec.from
	var to: Vector3 = spec.get("to", from)
	var look: Vector3 = spec.get("look", spec.get("look_from", Vector3.ZERO))
	var look_to: Vector3 = spec.get("look_to", look)
	var focus: Vector3 = spec.get("focus", look_to)
	shot.from = frame*from
	shot.to = frame*to
	shot.look_from = frame*look
	shot.look_to = frame*look_to
	shot.focus = frame*focus

func _placed(shot: Dictionary) -> bool:
	for key in ["place", "space", "stage_at", "from_marker", "village"]:
		if shot.has(key): return true
	return false

## A Surface place (any Campaigns.resolve anchor) as a frame on the ground,
## turned `turn` degrees: offsets are metres from it, heights above it.
func surface_frame(at: Variant, turn := 0.0) -> Transform3D:
	var spot := Campaigns.resolve(at, world) if world is IslandWorld else Vector3.INF
	if not spot.is_finite(): spot = player.global_position if is_instance_valid(player) else Vector3.ZERO
	elif world is IslandWorld: spot.y = world.ground_height(spot.x, spot.z)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), spot)

## A place of the Reach as a world frame (x right, y up from the ground):
## {planet, at = "town" | "fort" | "pad" | "dock" | "orbit" | "place" (with
## `place`, a SpaceLayout.PLACES name)}, {at = "nexus"} or {at = "diner"}.
## Orbit is the planet's centre with world axes.
static func space_frame(spec: Dictionary) -> Transform3D:
	match str(spec.get("at", "orbit")):
		"nexus": return Transform3D(Basis.IDENTITY, SpaceLayout.NEXUS)
		"diner": return Transform3D(Basis.IDENTITY, SpaceLayout.DINER)
	var p := SpaceLayout.planet(str(spec.get("planet", "")))
	var center: Vector3 = p.get("center", Vector3.ZERO)
	match str(spec.get("at", "orbit")):
		"town": return Transform3D(Basis.IDENTITY, center)*SpaceLayout.town_frame(p, str(spec.get("spot", "center")))
		"dock": return Transform3D(Basis.IDENTITY, center)*SpaceLayout.town_frame(p, "dock")
		"fort", "herald": return Transform3D(Basis.IDENTITY, center)*SpaceLayout.fort_frame(p)
		"pad": return SpaceLayout.pad_frame(p)
		"place":
			var index: int = SpaceLayout.PLACES.get(str(spec.planet), []).find(str(spec.get("place", "")))
			if index>=0: return Transform3D(Basis.IDENTITY, center)*SpaceLayout.place_frame(p, SpaceLayout.place_offset(p, index))
	return Transform3D(Basis.IDENTITY, center)

## Shots over towns ({village}): a slow glide down toward each town's heart.
func _village_shot(shot: Dictionary, film: Dictionary) -> void:
	var c := Campaigns.resolve({village = shot.village}, world) if world is IslandWorld else Vector3.INF
	if not c.is_finite(): c = player.global_position
	shot.from = c+Vector3(38, 28, 38)
	shot.to = c+Vector3(16, 14, 22)
	shot.look_from = c+Vector3.UP*3.0
	shot.look_to = shot.look_from
	shot.focus = shot.look_to
	if film.get("fireworks", false): _fireworks(c+Vector3.UP*16.0)

func _marker(marker_name: String) -> Vector3:
	var node := stage.find_child(marker_name, true, false) as Node3D if stage else null
	return node.global_position if node else (stage.global_position if stage else player.global_position)

# --- Stage, cast and effects -------------------------------------------------

## A stage scene loaded far from the world just for the film, with its own
## voxel viewer (the player's is far away) and warm light where films look.
func _build_stage(film: Dictionary) -> void:
	if not film.has("stage") or not ResourceLoader.exists(str(film.stage)): return
	stage = load(str(film.stage)).instantiate()
	stage.position = film.get("stage_offset", Vector3(0, -600, 0))
	add_child(stage)
	var viewer := VoxelViewer.new()
	viewer.view_distance = 240
	viewer.requires_collisions = false
	viewer.position = Vector3(0, 12, 0)
	stage.add_child(viewer)
	for spot: Vector3 in film.get("stage_lights", []):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ffd9a0")
		lamp.light_energy = 2.2
		lamp.omni_range = 45.0
		lamp.position = spot
		stage.add_child(lamp)

func _add_actor(actor: Dictionary) -> void:
	var frame: Transform3D
	if actor.has("stage"):
		frame = Transform3D(Basis.IDENTITY, (stage.global_position if stage else Vector3.ZERO)+(actor.stage as Vector3))
	elif actor.has("space"):
		var place := space_frame(actor.space)
		frame = Transform3D(place.basis, place*(actor.space.get("at_local", Vector3.ZERO) as Vector3))
	elif actor.has("place"):
		var base := surface_frame(actor.place, float(actor.get("turn", 0.0)))
		var at: Vector3 = base*(actor.get("at", Vector3.ZERO) as Vector3)
		if world is IslandWorld: at.y = world.ground_height(at.x, at.z)+(actor.get("at", Vector3.ZERO) as Vector3).y
		frame = Transform3D(base.basis, at)
	else:
		return
	if actor.has("shadow"):
		_looming(frame, actor)
		return
	var model := _cast.add(str(actor.model), frame, actor)
	if actor.has("pose"): model.boss_pose(str(actor.pose), 86400.0)
	if actor.has("shots"): _only_in(actor.shots, [model])

## Shows those nodes only during the shots listed (indexes into the film's
## shots); `start` runs the first time one of them begins.
func _only_in(shots: Array, nodes: Array, start := Callable()) -> void:
	for node: Node3D in nodes: node.visible = false
	_by_shot.append({nodes = nodes, shots = shots, start = start})

## A shot begins: actors that belong to other shots step out of frame.
func on_shot(index: int) -> void:
	for entry: Dictionary in _by_shot:
		var here: bool = index in entry.shots
		for node: Node3D in entry.nodes:
			if is_instance_valid(node): node.visible = here
		if here and (entry.start as Callable).is_valid():
			(entry.start as Callable).call()
			entry.start = Callable()

## Something enormous that never comes into frame: only its shadow does,
## thrown by a cold light behind it across whoever it walks toward
## (`march`, a world offset over `seconds`).
func _looming(frame: Transform3D, actor: Dictionary) -> void:
	var body := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	var size: Vector3 = actor.shadow.get("size", Vector3(5, 16, 5))
	shape.radius = size.x*0.5
	shape.height = size.y
	body.mesh = shape
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(body)
	body.global_position = frame.origin+Vector3.UP*size.y*0.5
	var lamp := SpotLight3D.new()
	lamp.light_color = actor.shadow.get("color", Color("cfd8ff"))
	lamp.light_energy = float(actor.shadow.get("energy", 9.0))
	lamp.spot_range = 90.0
	lamp.spot_angle = 38.0
	lamp.shadow_enabled = true
	add_child(lamp)
	var light_at: Vector3 = frame.origin+(actor.shadow.get("light", Vector3(0, 10, 14)) as Vector3)
	var aim: Vector3 = frame.origin+(actor.shadow.get("toward", Vector3(0, 0, -20)) as Vector3)
	lamp.look_at_from_position(light_at, aim, Vector3.UP)
	var march: Vector3 = actor.get("march", Vector3.ZERO)
	var walk := func() -> void:
		if march==Vector3.ZERO: return
		var tween := create_tween()
		tween.tween_interval(float(actor.get("delay", 0.0)))
		tween.tween_property(body, "global_position", body.global_position+march, float(actor.get("seconds", 6.0))).set_trans(Tween.TRANS_SINE)
	if actor.has("shots"): _only_in(actor.shots, [body, lamp], walk)
	else: walk.call()

func _fireworks(at: Vector3) -> void:
	for color: Color in [Color("ffd35a"), Color("ff6a8a"), Color("7ee0ff"), Color("b58cff")]:
		var burst := CPUParticles3D.new()
		burst.amount = 60
		burst.lifetime = 1.6
		burst.explosiveness = 0.95
		burst.direction = Vector3.UP
		burst.spread = 180.0
		burst.initial_velocity_min = 6.0
		burst.initial_velocity_max = 11.0
		burst.gravity = Vector3(0, -4, 0)
		var dot := BoxMesh.new()
		dot.size = Vector3.ONE*0.25
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = color
		dot.material = glow
		burst.mesh = dot
		add_child(burst)
		burst.global_position = at+Vector3(randf_range(-8, 8), randf_range(-3, 4), randf_range(-8, 8))

# --- Streaming and safety -----------------------------------------------------

## Whether the place round `point` has streamed in enough to fade up on, after
## `waited` seconds of black there. Space builds round the camera, so a long
## jump gets a moment; the Surface and the stage report their own progress.
func ready_at(point: Vector3, waited: float) -> bool:
	if waited<0.25: return false
	if waited>7.0: return true
	var jumped := not _last_ready.is_finite() or _last_ready.distance_to(point)>300.0
	var ok := true
	if is_instance_valid(stage) and stage.global_position.distance_to(point)<260.0:
		ok = _meshed(stage.get("terrain"), point)
	elif world is IslandWorld:
		ok = world.is_presentation_ready() and _meshed(world.terrain, point)
	elif world is SpaceWorld:
		ok = world.is_presentation_ready() and waited>=(2.4 if jumped else 0.4)
	if ok: _last_ready = point
	return ok

func _meshed(terrain: Variant, point: Vector3) -> bool:
	if not terrain is VoxelTerrain or not is_instance_valid(terrain): return true
	var voxel: VoxelTerrain = terrain
	var center := voxel.to_local(point)
	var reach := (voxel.global_basis.inverse()*Vector3(24, 10, 24)).abs()
	return voxel.is_area_meshed(AABB(center-reach, reach*2.0))

## How far from `subject` toward `eye` the lens can stand with nothing in
## between (`eye`'s distance when the view is clear): houses, rocks, trunks and
## walls (colliders), hills (the Surface's ground) and tree crowns (shot
## `index`'s, which have no colliders). The film camera comes in to there,
## like a spring arm, so nothing covers what the shot looks at.
func clear_reach(index: int, subject: Vector3, eye: Vector3) -> float:
	var length := subject.distance_to(eye)
	if length < 0.5: return length
	var reach := length
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(subject, eye, Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty(): reach = subject.distance_to(hit.position)
	if world is IslandWorld and not (is_instance_valid(stage) and stage.global_position.distance_to(eye) < 400.0):
		var step := 1.5
		var t := 2.0
		while t < reach:
			var p := subject.lerp(eye, t / length)
			if p.y < world.ground_height(p.x, p.z) + 0.4:
				reach = t
				break
			t += step
	for crown: Array in _crowns.get(index, []):
		reach = minf(reach, _enters_crown(subject, eye, crown))
	return length if reach >= length else maxf(reach - 0.8, minf(2.5, length))

## Where the segment subject -> eye first enters a tree's crown (a vertical
## cylinder), as a distance from the subject; INF if it misses.
static func _enters_crown(subject: Vector3, eye: Vector3, crown: Array) -> float:
	var a := Vector2(subject.x, subject.z)
	var d := Vector2(eye.x, eye.z) - a
	var f := a - (crown[0] as Vector2)
	var r: float = crown[1]
	var qa := d.dot(d)
	if qa < 0.0001: return INF
	var qb := 2.0 * f.dot(d)
	var qc := f.dot(f) - r * r
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0: return INF
	var root := sqrt(disc)
	for t: float in [(-qb - root) / (2.0 * qa), (-qb + root) / (2.0 * qa)]:
		if t < 0.0 or t > 1.0: continue
		var y := lerpf(subject.y, eye.y, t)
		if y >= float(crown[2]) and y <= float(crown[3]): return t * subject.distance_to(eye)
	# Starting inside the crown (the subject stands under the tree): not a blocker.
	return INF

## The trees a Surface shot passes near (forest and town trees): crowns as
## cylinders from a little above the ground to the top of the model.
func _crowns_along(shot: Dictionary) -> Array:
	if not world is IslandWorld or not shot.has("from") or not shot.has("look_from"): return []
	var island := world as IslandWorld
	var box := AABB(shot.from, Vector3.ZERO)
	for key in ["to", "look_from", "look_to"]:
		if shot.has(key): box = box.expand(shot[key])
	var area := Rect2i(floori(box.position.x) - 8, floori(box.position.z) - 8, ceili(box.size.x) + 16, ceili(box.size.z) + 16)
	if area.size.x * area.size.y > 400 * 400: return []  # orbit-wide shots: crowns don't matter
	var out: Array = []
	var trees: Array = island.generator.tree_sites(area, island._keep_clear, IslandWorld.KEEP_CLEAR_RADIUS)
	for v: VillageFeature in island.generator.villages:
		for tree: Dictionary in v.trees:
			if area.has_point(Vector2i(floori(tree.pos.x), floori(tree.pos.z))): trees.append(tree)
	for tree: Dictionary in trees:
		var prefab := ObstacleLibrary.get_prefab(str(tree.prefab))
		var scale_value := float(tree.get("scale", 1.0))
		var pos: Vector3 = tree.pos
		out.append([Vector2(pos.x, pos.z), maxf(prefab.footprint.x, prefab.footprint.y) * 0.45 * scale_value,
			pos.y + 1.6, pos.y + prefab.height * scale_value])
	return out

## Keeps the camera out of the ground: above the Surface's terrain, above a
## planet's surface.
func clamp_camera(pos: Vector3) -> Vector3:
	if is_instance_valid(stage) and stage.global_position.distance_to(pos)<400.0: return pos
	if world is IslandWorld:
		return Vector3(pos.x, maxf(pos.y, world.ground_height(pos.x, pos.z)+1.6), pos.z)
	if world is SpaceWorld:
		var p := SpaceLayout.planet_near(pos, 400.0)
		if not p.is_empty():
			var ground := SpaceLayout.surface_point(p, pos)
			var center: Vector3 = p.center
			var least := center.distance_to(ground)+1.8
			if center.distance_to(pos)<least: return center+(pos-center).normalized()*least
	return pos
