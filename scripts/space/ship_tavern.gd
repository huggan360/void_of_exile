class_name ShipTavern
extends Node3D
## Warm crew-table light. Held and placed drinks are owned by Leisure.
var world: SpaceWorld
var slot := 0
var anchors := {}
func _ready() -> void:
	var candle := OmniLight3D.new()
	candle.position = Vector3(-4.7, 1.5, 6.2)
	candle.light_color = Color("ffb36a")
	candle.light_energy = 0.9
	candle.omni_range = 4.5
	NearbyLightShadows.register_light(candle)
	add_child(candle)
