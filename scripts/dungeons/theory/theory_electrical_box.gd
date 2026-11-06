class_name TheoryElectricalBox
extends InteractionTarget
## Physical lever and concise, authoritative inspection/repair results.
const WRONG_RESULTS := ["Observation lamps are live. This is not the airlock relay.",
	"Coolant pumps engage. This box does not control the airlock.",
	"Engine service power is restored. No airlock relay here.",
	"Habitat circuits are on. This is not the airlock control.",
	"Navigation supply is live. The airlock relay is elsewhere."]
const REPAIR_RESULTS := ["The oxygen regulator holds pressure again.","The coolant pump starts turning.",
	"The pressure valves respond again.","The emergency lighting circuit is stable.","The reserve contactor locks into place."]
var world: TheoryWorld
var index := 0
var _lamp: StandardMaterial3D
var _sparks: TheorySparks
var _lever: Node3D
var _lever_tween: Tween
var _lever_on := false
var _visual_initialized := false
var _pending_until := 0
var _quest_badge: QuestMarker

func _ready() -> void:
	super._ready()
	reach = 3.2
	live_response = true
	if not world.server_build and not Net.is_server():
		_lamp = StandardMaterial3D.new()
		_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lamp.emission_enabled = true
		_lamp.emission_energy_multiplier = 1.2
		var indicator := _cube(self,Vector3(0.19,0.09,0.055),Vector3(-0.28,0.48,0.21),Color.WHITE)
		indicator.material_override = _lamp
		if index<5:
			var beacon := OmniLight3D.new()
			beacon.light_color = Color("69cce6")
			beacon.light_energy = 0.7
			beacon.omni_range = 2.4
			beacon.position = Vector3(0,0.25,0.45)
			beacon.distance_fade_enabled = true
			beacon.distance_fade_begin = 22
			add_child(beacon)
		_cube(self,Vector3(0.26,0.17,0.13),Vector3(0.29,0.0,0.30),TheoryArt.TRIM)
		var hinges: Array[Transform3D] = []
		for y in [-0.38,0.38]: hinges.append(TheoryRoundDetails.along(Vector3(-0.52,y-0.1,0.12),Vector3(-0.52,y+0.1,0.12),0.055))
		TheoryRoundDetails.batch(self,"CoverHinges",TheoryRoundDetails.mesh("cylinder"),hinges,[],TheoryArt.TRIM)
		var screws: Array[Transform3D] = []
		for x in [-0.43,0.43]:
			for y in [-0.59,0.59]: screws.append(TheoryRoundDetails.along(Vector3(x,y,0.17),Vector3(x,y,0.21),0.03))
		TheoryRoundDetails.batch(self,"CoverFasteners",TheoryRoundDetails.mesh("bolt"),screws,[],TheoryArt.STEEL)
		_lever = Node3D.new()
		_lever.position = Vector3(0.29,0.0,0.38)
		add_child(_lever)
		var stem: Array[Transform3D] = [TheoryRoundDetails.along(Vector3.ZERO,Vector3(0,0.44,0),0.045)]
		TheoryRoundDetails.batch(_lever,"LeverStem",TheoryRoundDetails.mesh("cylinder"),stem,[],TheoryArt.TRIM)
		var grip: Array[Transform3D] = [TheoryRoundDetails.along(Vector3(-0.13,0.47,0),Vector3(0.13,0.47,0),0.065)]
		TheoryRoundDetails.batch(_lever,"LeverGrip",TheoryRoundDetails.mesh("cylinder"),grip,[],Color("d48a40"))
		if index>=5:
			_sparks = TheorySparks.new()
			_sparks.position = Vector3(-0.24,0.08,0.30)
			_sparks.direction = Vector3(-0.35,-0.65,1.0)
			add_child(_sparks)
	if not world.server_build and not Net.is_server():
		_quest_badge = QuestMarker.new("main")
		add_child(_quest_badge)
		_quest_badge._material.no_depth_test = true
		var placard := Label3D.new()
		placard.text = TheoryLayout.ELECTRICAL_NAMES[index]
		placard.font = UIStyle.bold()
		placard.font_size = 30
		placard.pixel_size = 0.006
		placard.position = Vector3(0,1.0,0.14)
		placard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		placard.modulate = Color("ffce89") if index>=5 else Color("a6f7ff")
		add_child(placard)
		if index>=5:
			var task_lamp := OmniLight3D.new()
			task_lamp.position = Vector3(0,0.5,0.65)
			task_lamp.light_color = Color("f9bd70")
			task_lamp.light_energy = 1.1
			task_lamp.omni_range = 4.5
			add_child(task_lamp)
	refresh(null)

func _cube(parent: Node3D,size: Vector3,at: Vector3,color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.45
	material.roughness = 0.5
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh

func activate(actor: Node3D) -> bool:
	if not super.activate(actor): return false
	if actor is Player and not _done() and Time.get_ticks_msec()>=_pending_until:
		_pending_until = Time.get_ticks_msec()+3500
		world.request_electrical_box(index,actor)
	refresh(actor)
	return true

func _done() -> bool:
	return index in world.repaired_boxes if index>=5 else index in world.inspected_boxes

func refresh(_actor: Node3D) -> void:
	var repair := index>=5
	var done := _done()
	var found := world.airlock_relay_box==index
	if is_instance_valid(_quest_badge):
		_quest_badge.visible = not done and ((repair and world.electrical_quest in ["", "repairs"]) or (not repair and not world.ship_airlock_open and world.electrical_quest in ["", "relays"]))
	title = TheoryLayout.ELECTRICAL_NAMES[index]
	action_text = "Read status" if done else "Repair and engage" if repair else "Inspect and switch on"
	confirm_text = ""
	cancel_text = "Leave"
	if done:
		_pending_until = 0
		if repair:
			description = "Circuit restored - lever engaged."
			response = REPAIR_RESULTS[index-5]+(" All five circuits are restored. Escape airlock unlocked." if world.repaired_boxes.size()==5 else " %d/5 circuits restored." % world.repaired_boxes.size())
		else:
			description = "Airlock relay found - door unlocked." if found else "Checked - not the airlock relay."
			response = "This is the airlock relay. The forward airlock is now open." if found else WRONG_RESULTS[index]
	elif Time.get_ticks_msec()<_pending_until:
		description = "Working on the circuit..."
		response = "Reseating the fuse and engaging the lever..." if repair else "Switching on and checking the relay..."
	else:
		description = TheoryLayout.ELECTRICAL_HINTS[index]
		response = description
	if _lamp!=null:
		var color := Color("69e5a2") if done and (repair or found) else Color("e8b957") if done else Color("ee8c42") if repair else Color("64cde8")
		_lamp.albedo_color = color
		_lamp.emission = color
	if is_instance_valid(_sparks): _sparks.set_active(not done)
	if is_instance_valid(_lever):
		var angle := PI-0.55 if done else 0.55
		if not _visual_initialized:
			_lever.rotation.x = angle
		elif done!=_lever_on:
			if _lever_tween!=null: _lever_tween.kill()
			_lever_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			_lever_tween.tween_property(_lever,"rotation:x",angle,0.38)
		_lever_on = done
		_visual_initialized = true
