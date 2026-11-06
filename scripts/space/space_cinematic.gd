class_name SpaceCinematic
extends Node
## Camera shots for the Reach: the rocket's launch and the Nexus tour.
var _caption: Label
var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 96
	add_child(_layer)
	for bottom in [false, true]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top = -70 if bottom else 0
		bar.offset_bottom = 0 if bottom else 70
		_layer.add_child(bar)
	_caption = UIStyle.label("", 24, UIStyle.GOLD)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -60
	_caption.offset_bottom = -14
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(_caption)

## Moves `camera` from one pose to another over `time`, looking at `look`.
func _shot(camera: Camera3D, from: Vector3, to: Vector3, look: Callable, time: float, caption := "") -> void:
	_caption.text = caption
	var t := 0.0
	while t<time:
		t += get_process_delta_time()
		var k := smoothstep(0.0, 1.0, t/time)
		var at := from.lerp(to, k)
		var target: Vector3 = look.call()
		if at.distance_to(target)>0.1: camera.global_transform = Transform3D(Basis.IDENTITY, at).looking_at(target, Vector3.UP)
		await get_tree().process_frame

func rocket_launch(camera: Camera3D, rocket: SmallRocket, caption: String) -> void:
	var base := rocket.global_position
	var up := rocket.global_basis.y
	var side := rocket.global_basis.x
	var look := func() -> Vector3: return rocket.global_position+up*3.0
	rocket.set_flame(0.4)
	await _shot(camera, base+side*16.0+up*4.0, base+side*12.0+up*3.0, look, 1.6, caption)
	rocket.set_flame(1.0)
	var t := 0.0
	var start := rocket.global_position
	while t<3.2:
		t += get_process_delta_time()
		rocket.global_position = start+up*(t*t*9.0)
		rocket.rotate(up, get_process_delta_time()*1.4)
		var eye := base+side*12.0+up*(3.0+t*6.0)
		camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(rocket.global_position+up*3.0, Vector3.UP)
		await get_tree().process_frame

func nexus_intro(camera: Camera3D, world: SpaceWorld) -> void:
	var a: Dictionary = world.station.anchors
	var centre := SpaceLayout.NEXUS
	await _shot(camera, centre+Vector3(0, 160, 260), centre+Vector3(60, 70, 120), func() -> Vector3: return centre, 5.0,
		"The Nexus - a tavern among the stars, past the Convergence.")
	var board: Vector3 = a.get("campaign_board", centre)
	await _shot(camera, board+Vector3(10, 7, 12), board+Vector3(6, 4, 8), func() -> Vector3: return board+Vector3.UP*1.5, 4.0,
		"Captain Isolde's board holds the tales of the Reach. Start a tale from here or from the Tavern.")
	var table: Vector3 = a.get("command_table", centre)
	await _shot(camera, table+Vector3(-10, 8, 10), table+Vector3(-6, 5, 7), func() -> Vector3: return table+Vector3.UP, 4.0,
		"At the command table you launch a battleship. Your whole party can crew it.")
	var berth := SpaceLayout.berth_frame(0).origin
	await _shot(camera, berth+Vector3(60, 30, 70), berth+Vector3(30, 18, 40), func() -> Vector3: return berth, 4.0,
		"Pilot, gunners and navigator: every seat aboard has its own view.")
	var pad: Transform3D = a.get("rocket_pad", Transform3D(Basis.IDENTITY, centre))
	await _shot(camera, pad.origin+Vector3(12, 6, 12), pad.origin+Vector3(8, 4, 9), func() -> Vector3: return pad.origin+Vector3.UP*3.0, 4.0,
		"Orin's rocket flies home to the Tavern. R brings you back here from anywhere in the Reach.")
	var far: Vector3 = SpaceLayout.planet("verdance").center
	await _shot(camera, centre+Vector3(0, 40, -80), centre+Vector3(0, 60, -140), func() -> Vector3: return far, 4.0,
		"Planets wait in the Haven. Beyond the Shardfield lies the Gloam. M opens the star map.")
	_caption.text = ""
