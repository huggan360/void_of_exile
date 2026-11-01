class_name StrongholdGates
extends Node3D
## Dynamic portcullises. Terrain plans stay immutable for voxel worker threads.
## The server decides closure; clients replay it and receive state on entry.
## Every fortress starts sealed: its gates stay shut until someone uses the
## fortress's key there (consumed). A boss attempt that resets seals it again.
## Separately, a running encounter bars the gates (request) until it ends.
signal changed(center: Vector2i, locked: bool, sealed: bool)
const KEYS := {Biomes.BLUELAY: "key_azure_crucible", Biomes.FOSEN: "key_crown_of_the_rime",
	Biomes.DOOM: "key_cinder_bastion", Biomes.DESERT: "key_court_of_the_sun", Biomes.DEEP_DARK: "key_hollow_throne"}
const KEY_REACH := 9.0  # how far from a gate's middle the lock can be reached
const OPEN_SPEED := 2.4  # the bars grind up slowly (m/s); they drop at 10
const CINEMATIC := 4.6  # seconds the opening shot lasts
var entries := {}
var server_build := false
var _shot := {}  # the running opening shot: {camera, previous, player, center, back, t, start, bars}

## `opened`: fortress centers already unsealed in this realm (saved).
func build(forts: Array[StrongholdFeature], dedicated: bool, opened: Array = []) -> void:
	server_build = dedicated
	for fort in forts:
		var root := Node3D.new()
		root.name = "Gate_%d_%d" % [fort.center.x,fort.center.y]
		root.position = Vector3(fort.center.x,fort.base_height+1,fort.center.y)
		root.rotation.y = -fort.turn*PI*.5
		add_child(root)
		var gates: Array = []
		for spec: Vector3 in [Vector3(11,6,-33),Vector3(5,4,34)]:
			var body := StaticBody3D.new()
			body.position = Vector3(.5,spec.y*.5,spec.z)
			body.collision_layer = 0
			body.collision_mask = 0
			root.add_child(body)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(spec.x,spec.y,4)
			shape.shape = box
			body.add_child(shape)
			var visual := Node3D.new()
			root.add_child(visual)
			visual.position = Vector3(.5,spec.y+.6,spec.z)
			if not dedicated: _bars(visual,spec.x,spec.y,fort.biome_id)
			gates.append({body=body,visual=visual,height=spec.y,box=AABB(body.position-box.size*.5,box.size)})
		var sealed := not opened.has(fort.center)
		entries[fort.center] = {root=root,fort=fort,gates=gates,locked=sealed,requested=false,sealed=sealed,close_at=0}
		for gate: Dictionary in gates:
			gate.body.collision_layer = Player.OBSTACLE_LAYER if sealed else 0
			gate.visual.position.y = 0 if sealed else gate.height+.6
		if not dedicated:
			for spec: Vector3 in [Vector3(0,0,-38),Vector3(0,0,39)]:
				var target := GateLock.new()
				target.gates = self
				target.center = fort.center
				target.position = spec
				target.reach = 6.5
				root.add_child(target)

func request(center: Vector2i, locked: bool) -> void:
	if not entries.has(center): return
	var entry: Dictionary = entries[center]
	entry.requested = locked
	if locked: entry.close_at = Time.get_ticks_msec()+1500
	elif not entry.sealed: _commit(center,false)

## Shut and locked again until another key is used (the boss reset).
## Fortresses a campaign opened for good in this world (never sealed again).
var forced_open: Array = []


func seal(center: Vector2i) -> void:
	if not entries.has(center) or entries[center].sealed or center in forced_open: return
	var entry: Dictionary = entries[center]
	entry.sealed = true
	entry.close_at = Time.get_ticks_msec()+1500
	changed.emit(center,entry.locked,true)

func is_sealed(center: Vector2i) -> bool:
	return entries.has(center) and entries[center].sealed

func key_for(center: Vector2i) -> String:
	return KEYS.get(entries[center].fort.biome_id,"") if entries.has(center) else ""

## Server side (or offline): `stats` uses its key on the gate at `center`
## from `pos`. The key is consumed and both gates open.
func try_open(center: Vector2i, stats: PlayerStats, pos: Vector3) -> bool:
	if stats == null or not is_sealed(center) or not near_lock(center,pos): return false
	var place := stats.find_item(key_for(center))
	if place.is_empty(): return false
	stats.take(place)
	var entry: Dictionary = entries[center]
	entry.sealed = false
	if not server_build: _unsealed(center)
	if entry.requested: changed.emit(center,entry.locked,false)
	else:
		if not entry.locked: changed.emit(center,false,false)
		_commit(center,false)
	return true

## Whether `pos` stands at one of the fortress's gates, inside or out.
func near_lock(center: Vector2i, pos: Vector3) -> bool:
	if not entries.has(center): return false
	var local: Vector3 = entries[center].root.to_local(pos)
	for z in [-33.0,34.0]:
		if Vector2(local.x-.5,local.z-z).length()<KEY_REACH: return true
	return false

func apply_state(center: Vector2i, locked: bool, sealed := locked) -> void:
	if not entries.has(center): return
	var entry: Dictionary = entries[center]
	if entry.sealed and not sealed: _unsealed(center)
	entry.requested = locked and not sealed
	entry.sealed = sealed
	_commit(center,locked,true)

func states() -> Array:
	var out: Array = []
	for center: Vector2i in entries:
		out.append([center,entries[center].locked,entries[center].sealed])
	return out

## Unsealed fortress centers, for the realm record.
func opened() -> Array:
	return entries.keys().filter(func(c: Vector2i) -> bool: return not entries[c].sealed)

func _commit(center: Vector2i, locked: bool, announce_seal := false) -> void:
	var entry: Dictionary = entries[center]
	if entry.locked==locked and not announce_seal: return
	entry.locked = locked
	for gate: Dictionary in entry.gates:
		gate.body.set_deferred("collision_layer",Player.OBSTACLE_LAYER if locked else 0)
	changed.emit(center,locked,entry.sealed)

func _process(delta: float) -> void:
	for center: Vector2i in entries:
		var entry: Dictionary = entries[center]
		if not Net.is_client() and (entry.requested or entry.sealed) and not entry.locked and Time.get_ticks_msec()>=entry.close_at and not _occupied(entry):
			_commit(center,true)
		for gate: Dictionary in entry.gates:
			var target: float = 0 if entry.locked else gate.height+.6
			gate.visual.position.y = move_toward(gate.visual.position.y,target,delta*(10 if entry.locked else OPEN_SPEED))
			gate.visual.visible = gate.visual.position.y<gate.height+.5

	if not _shot.is_empty(): _film(delta)

## The local player turns their key: online the server checks and spends it.
func use_key(center: Vector2i, player: Node3D) -> void:
	if not player is Player: return
	if Net.is_client():
		Net.client.send_action("gate",[center])
	else:
		try_open(center,GameServer.character((player as Player).player_id),player.global_position)

## A gate was unsealed: a rumble, and the opening shot for a player close by.
func _unsealed(center: Vector2i) -> void:
	var entry: Dictionary = entries[center]
	var world := get_parent() as IslandWorld
	var player: Player = world.enemy_director.player if world else null
	for gate: Dictionary in entry.gates:
		var at: Vector3 = entry.root.to_global(gate.body.position)
		Boss.flash_light(self,at,Color(1.0,0.85,0.55),2.0,10.0,1.4)
		CameraShake.shake_at(at,0.35,30.0)
	if not is_instance_valid(player) or player.frozen or not near_lock(center,player.global_position) and \
			Vector2(player.global_position.x-center.x,player.global_position.z-center.y).length()>45.0:
		return
	_end_shot()
	var camera := Camera3D.new()
	add_child(camera)
	var previous := get_viewport().get_camera_3d()
	camera.fov = player.camera.fov
	camera.global_transform = previous.global_transform if previous else player.camera.global_transform
	camera.make_current()
	player.cinematic_locked = true
	player._cancel_weapon_actions()
	# Film the gate the player stood at (main or back), from outside the walls.
	var back: bool = entry.root.to_local(player.global_position).z>0.0
	_shot = {camera=camera,previous=previous,player=player,center=center,back=back,t=0.0,start=camera.global_transform,
		bars=_letterbox()}

func _film(delta: float) -> void:
	var player: Player = _shot.player if is_instance_valid(_shot.player) else null
	if not is_instance_valid(player) or not entries.has(_shot.center):
		_end_shot()
		return
	_shot.t += delta
	var t: float = _shot.t
	var entry: Dictionary = entries[_shot.center]
	var gate_z := 34.0 if _shot.back else -33.0
	var out := 1.0 if _shot.back else -1.0
	# A slow push in on the rising bars, drifting across the gate's face.
	var k := smoothstep(0.0,1.0,t/CINEMATIC)
	var look: Vector3 = entry.root.to_global(Vector3(.5,3.2+k*.8,gate_z))
	var eye: Vector3 = entry.root.to_global(Vector3(lerpf(-7.0,5.0,k),lerpf(5.5,3.8,k),gate_z+out*lerpf(17.0,11.0,k)))
	var shot := Transform3D(Basis.IDENTITY,eye).looking_at(look)
	var blend_in := smoothstep(0.0,1.0,clampf(t/1.0,0.0,1.0))
	var transform: Transform3D = (_shot.start as Transform3D).interpolate_with(shot,blend_in)
	var left := CINEMATIC-t
	if left<1.0: transform = transform.interpolate_with(player.camera.global_transform,smoothstep(0.0,1.0,1.0-left))
	(_shot.camera as Camera3D).global_transform = transform
	for bar: ColorRect in (_shot.bars as CanvasLayer).get_children():
		bar.modulate.a = minf(clampf(t/0.6,0,1),clampf(left/0.6,0,1))
	if left<=0.0: _end_shot()

func _letterbox() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 72
	add_child(layer)
	for bottom in [false,true]:
		var bar := ColorRect.new()
		bar.color = Color(0,0,0,.94)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top = -64 if bottom else 0
		bar.offset_bottom = 0 if bottom else 64
		bar.modulate.a = 0.0
		layer.add_child(bar)
	return layer

func _end_shot() -> void:
	if _shot.is_empty(): return
	var player: Player = _shot.player if is_instance_valid(_shot.player) else null
	var camera: Camera3D = _shot.camera if is_instance_valid(_shot.camera) else null
	if is_instance_valid(player): player.cinematic_locked = false
	if is_instance_valid(camera) and camera.current:
		if is_instance_valid(_shot.previous): (_shot.previous as Camera3D).make_current()
		elif is_instance_valid(player): player.camera.make_current()
	if is_instance_valid(camera): camera.queue_free()
	if is_instance_valid(_shot.bars): (_shot.bars as Node).queue_free()
	_shot = {}

func _exit_tree() -> void:
	_end_shot()

func _occupied(entry: Dictionary) -> bool:
	var world := get_parent() as IslandWorld
	if world==null: return false
	for player: Node3D in world.enemy_director.players:
		if not is_instance_valid(player): continue
		var local: Vector3 = entry.root.to_local(player.global_position+Vector3.UP*.85)
		for gate: Dictionary in entry.gates:
			if gate.box.grow(.6).has_point(local): return true
	return false

## Client movement prediction is backed by the same segment check on the server.
func blocks_segment(from: Vector3, to: Vector3) -> bool:
	for entry: Dictionary in entries.values():
		if not entry.locked: continue
		var a: Vector3 = entry.root.to_local(from+Vector3.UP*.85)
		var b: Vector3 = entry.root.to_local(to+Vector3.UP*.85)
		for gate: Dictionary in entry.gates:
			if gate.box.grow(.3).intersects_segment(a,b): return true
	return false

func center_for(pos: Vector3) -> Vector2i:
	var nearest := Vector2i(1<<29,1<<29)
	var distance := 4.0
	for center: Vector2i in entries:
		var d := Vector2(pos.x-center.x,pos.z-center.y).length()
		if d<distance: nearest = center; distance = d
	return nearest

func inside_arena(center: Vector2i, pos: Vector3) -> bool:
	if not entries.has(center): return true
	var local: Vector3 = entries[center].root.to_local(pos)
	return absf(local.x)<31 and absf(local.z)<31

func _bars(parent: Node3D, width: float, height: float, biome: int) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(.12,.14,.20)
	metal.roughness = .8
	var glow := StandardMaterial3D.new()
	var tint: Color = {Biomes.DOOM:Color(1,.23,.055),Biomes.DESERT:Color(1,.68,.2),Biomes.DEEP_DARK:Color(.7,.22,.9)}.get(biome,Color(.25,.6,1))
	glow.albedo_color = tint
	glow.emission_enabled = true
	glow.emission = tint
	glow.emission_energy_multiplier = .7
	for x in int(width)+1:
		_box(parent,Vector3(x-width*.5,height*.5,0),Vector3(.24,height,.45),metal)
	for y in range(1,int(height),2):
		_box(parent,Vector3(0,y,0),Vector3(width,.28,.5),metal)
	_box(parent,Vector3(0,height-.5,-.28),Vector3(.5,.5,.28),glow)

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
