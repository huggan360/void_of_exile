extends Node3D
## Yard conversations, nest ceremony and the account's free-roaming pets.
const WANDERER := preload("res://scripts/world/pet_yard_wanderer.gd")
var _world: PetYardWorld
var _main: Node
var _caretaker: CreatureModel
var _nest: NestTarget
var _following: InteractionTarget
var _wanderers := {}
var _known := {}
var _hatch_ids := {}
var _hatch_pet := {}
var _egg: Node3D
var _hatching := false
var _hatch_time := 0.0
var _cracked := false
var _account_changed: Signal


func setup(world: PetYardWorld) -> void:
	_world = world
	_main = world.get_parent()
	_caretaker = CreatureModel.new(_npc_model("caretaker", "npc_traveler"))
	_caretaker.position = PetYardWorld.CARETAKER_POS
	_caretaker.rotation.y = PI
	add_child(_caretaker)
	var talk := InteractionTarget.new()
	talk.title = "Caretaker"
	talk.description = "Care for your pets."
	talk.response = "A full bowl and a little care go a long way."
	talk.action_text = "Care for pets"
	talk.position = Vector3.UP
	_caretaker.add_child(talk)
	talk.activated.connect(func(_actor: Node3D) -> void:
		PetPanel.open_for(_main))
	var keeper := ShopKeeper.place(self, "pets", Transform3D(Basis(Vector3.UP, PI), PetYardWorld.STORE_POS), _npc_model("pet_storekeeper", "npc_magician"))
	keeper.target.title = "Pet Store"
	keeper.target.description = "Pet Eggs"
	keeper.target.response = "Every egg holds a new friend. Take yours to the Hatching Nest."
	_nest = NestTarget.new()
	_nest.yard = self
	_nest.title = "Hatching Nest"
	_nest.description = "Hatch a Pet Egg here."
	_nest.response = "Something is stirring in the straw."
	_nest.action_text = "Hatch an egg"
	_nest.reach = 3.5
	_nest.position = PetYardWorld.NEST_POS + Vector3.UP * 0.4
	add_child(_nest)
	_nest.activated.connect(func(_actor: Node3D) -> void: _hatch())
	_following = InteractionTarget.new()
	_following.reach = 2.8
	_following.enabled = false
	add_child(_following)
	_following.activated.connect(func(_actor: Node3D) -> void: PetsClient.equip(0))
	PetsClient.changed.connect(_changed)
	# A Script also has Resource.changed. Bridge the core's event facade when
	# that built-in signal hides its static changed field on this engine.
	_account_changed = PetsClient._events.changed
	if _account_changed != PetsClient.changed: _account_changed.connect(_forward_changed)
	_changed()


func _exit_tree() -> void:
	if PetsClient.changed.is_connected(_changed): PetsClient.changed.disconnect(_changed)
	if not _account_changed.is_null() and _account_changed.is_connected(_forward_changed): _account_changed.disconnect(_forward_changed)


func _forward_changed() -> void:
	PetsClient.changed.emit()


func _npc_model(id: String, fallback: String) -> String:
	for candidate in [id, "npc_" + id]:
		if FileAccess.file_exists("res://creatures/" + candidate + "/rig.json"): return candidate
	return fallback


func _changed() -> void:
	if _hatching and _hatch_pet.is_empty():
		for pet: Dictionary in PetsClient.state.get("pets", []):
			if not _hatch_ids.has(int(pet.id)):
				_hatch_pet = pet.duplicate(true)
				break
	var present := {}
	for pet: Dictionary in PetsClient.state.get("pets", []):
		var id := int(pet.id)
		_known[id] = true
		if id == int(PetsClient.state.get("equipped", 0)) or id == int(_hatch_pet.get("id", 0)): continue
		present[id] = true
		if not _wanderers.has(id):
			var wanderer := WANDERER.new().setup(pet, _world)
			add_child(wanderer)
			_wanderers[id] = wanderer
	for id: int in _wanderers.keys():
		if not present.has(id):
			var wanderer: Node3D = _wanderers[id]
			wanderer.get("target").enabled = false
			wanderer.queue_free()
			_wanderers.erase(id)


func _hatch() -> void:
	if _hatching: return
	_hatching = true
	_hatch_time = 0
	_cracked = false
	_hatch_pet = {}
	_hatch_ids = _known.duplicate()
	_egg = Node3D.new()
	_egg.position = PetYardWorld.NEST_POS + Vector3.UP * 0.55
	add_child(_egg)
	for layer in 5:
		var width: float = [0.42, 0.6, 0.62, 0.5, 0.3][layer]
		_cube(_egg, Vector3(0, layer * 0.15, 0), Vector3(width, 0.15, width), Color("fff1c9"))
	for at in [Vector3(-0.18, 0.2, -0.31), Vector3(0.18, 0.4, -0.26), Vector3(0, 0.6, -0.2)]:
		_cube(_egg, at, Vector3.ONE * 0.12, Color("9c9a7f"))
	PetsClient.hatch()


func _process(delta: float) -> void:
	if not is_instance_valid(_world): return
	if is_instance_valid(_caretaker): _caretaker.animate(0, delta)
	_follow_target()
	if not _hatching: return
	_hatch_time += delta
	if is_instance_valid(_egg):
		_egg.rotation.z = sin(_hatch_time * 18) * minf(0.24, _hatch_time * 0.1)
		_egg.position.y = PetYardWorld.NEST_POS.y + 0.55 + absf(sin(_hatch_time * 11)) * 0.08
	if _hatch_time > 1.0 and not _hatch_pet.is_empty():
		if not _cracked:
			_cracked = true
			# Square dark seams split the shell before it bursts.
			for i in 5:
				_cube(_egg, Vector3(0.06 if i % 2 else -0.04, i * 0.13, -0.32), Vector3(0.08, 0.16, 0.025), Color("806e55"))
		if _hatch_time > 1.55: _finish_hatch()
	elif _hatch_time > 10:
		# No new account pet means the request was refused or timed out.
		if is_instance_valid(_egg): _egg.queue_free()
		_hatching = false
		_changed()


func _follow_target() -> void:
	_following.enabled = false
	var pet := PetDefs.find(PetsClient.state, int(PetsClient.state.get("equipped", 0)))
	if pet.is_empty(): return
	# The core's local follower lives on NetClient. Only the owner's pet offers this action.
	var follower: Node3D = null
	if Net.is_client(): follower = Net.client._pet_followers.get(int(Net.client.info.get("player_id", 0))) as Node3D
	if not is_instance_valid(follower): return
	_following.global_position = follower.global_position + Vector3.UP * 0.4
	_following.title = str(pet.name)
	_following.action_text = "Let %s play" % str(pet.name)
	_following.description = "Let your companion play in the meadow."
	_following.response = "%s is off to play." % str(pet.name)
	_following.enabled = true


func _finish_hatch() -> void:
	var at := PetYardWorld.NEST_POS + Vector3.UP * 0.8
	if is_instance_valid(_egg): _egg.queue_free()
	for i in 20:
		var mote := _cube(self, at, Vector3.ONE * (0.07 if i % 2 else 0.12), Color("ffe6a2"))
		mote.material_override = PetFollower.light_material(Color("ffe6a2"))
		var angle := TAU * i / 20
		var end := at + Vector3(cos(angle) * 2, randf_range(0.3, 2), sin(angle) * 2)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(mote, "position", end, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mote, "scale", Vector3.ZERO, 0.65)
		tween.chain().tween_callback(mote.queue_free)
	# Start on the walkable rim, then jump clear of the straw.
	var start := PetYardWorld.NEST_POS + Vector3(0, 0, 2.25)
	start.y = _world.ground_height(start.x, start.z)
	var wanderer := WANDERER.new().setup(_hatch_pet, _world, start)
	add_child(wanderer)
	wanderer.pop_out()
	_wanderers[int(_hatch_pet.id)] = wanderer
	_hatching = false
	_hatch_pet = {}
	_changed()


func _cube(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	node.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node


class NestTarget:
	extends InteractionTarget
	var yard: Node3D

	func available(player: Node3D) -> bool:
		if not super.available(player) or yard._hatching: return false
		var stats: PlayerStats = player.get("stats")
		return stats != null and not stats.find_item("pet_egg").is_empty()
