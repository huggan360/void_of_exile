class_name ShopKeeper
extends Node3D
## A shopkeeper you can put anywhere: their model, a "Trade" interaction that
## opens the shop panel (your backpack on the left, their wares on the right),
## and speech bubbles that call out the shop's current offers and rare pieces.
##   ShopKeeper.place(parent, "wizard", transform)   # or add one in a scene and set shop_id
## What they sell comes from the account service (Shops); they work in any world.
const BUBBLE_EVERY := 11.0
const BUBBLE_RANGE := 26.0
@export var shop_id := "general"
## Optional: another creature than the shop's own keeper.
@export var model_id := ""
var model: CreatureModel
var target: InteractionTarget
var _beat := 0
var _timer := 0.0

static func place(parent: Node, shop: String, at: Transform3D, model_override := "") -> ShopKeeper:
	var keeper := ShopKeeper.new()
	keeper.shop_id = shop
	keeper.model_id = model_override
	keeper.transform = at
	parent.add_child(keeper)
	return keeper

func _ready() -> void:
	add_to_group("shop_keepers")
	var def: Dictionary = Shops.DEFS.get(shop_id, Shops.DEFS.general)
	model = CreatureModel.new(model_id if model_id!="" else str(def.model))
	add_child(model)
	target = InteractionTarget.new()
	target.title = str(def.name)
	target.description = str(def.title)
	target.response = str(def.hello[0])
	target.action_text = "Trade"
	target.reach = 4.0
	target.position = Vector3.UP
	add_child(target)
	target.activated.connect(func(_actor: Node3D) -> void: get_tree().call_group("shop_panels", "open_for", target, shop_id))
	_timer = randf_range(1.0, BUBBLE_EVERY)
	_beat = randi() % 7

func _process(delta: float) -> void:
	if is_instance_valid(model): model.animate(0.0, delta)
	_timer -= delta
	if _timer>0.0: return
	_timer = BUBBLE_EVERY+randf_range(-2.0, 2.0)
	var camera := get_viewport().get_camera_3d()
	if camera==null or camera.global_position.distance_to(global_position)>BUBBLE_RANGE: return
	var text := Shops.pitch(shop_id, _beat)
	_beat += 1
	if text!="": SpeechBubble.say(self, text, "shop", 2.4)
