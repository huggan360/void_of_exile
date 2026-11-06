class_name SpaceNPC
extends Node3D
## One of the Reach's people (Campaigns.NPCS with world "astral"): standing
## on the station or a planet, greeting visitors and taking the party's tale.
var world: SpaceWorld
var npc_id := ""
var model: CreatureModel
var target: InteractionTarget

func place(at: Vector3, basis: Basis) -> void:
	var info: Dictionary = Campaigns.NPCS[npc_id]
	global_transform = Transform3D(basis, at)
	model = CreatureModel.new(str(info.get("model", "npc_villager")))
	add_child(model)
	# Face the open deck or the landing pad side.
	model.rotation.y = PI
	target = InteractionTarget.new()
	target.title = str(info.name)
	target.description = str(info.get("greeting", ""))
	target.response = str(info.get("greeting", ""))
	target.action_text = "Talk"
	target.reach = 4.0
	target.position = Vector3.UP*1.0
	add_child(target)
	target.activated.connect(func(_player: Node3D) -> void:
		if Net.is_client(): Net.client.send_action("camp", ["quest", "npc:"+npc_id]))

func _process(delta: float) -> void:
	if is_instance_valid(model): model.animate(0.0, delta)
