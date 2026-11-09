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
		"Bell's shipwright sells battleships. Take yours out to a numbered berth, then board.")
	var berth := SpaceLayout.berth_frame(0).origin
	await _shot(camera, berth+Vector3(60, 30, 70), berth+Vector3(30, 18, 40), func() -> Vector3: return berth, 4.0,
		"Pilot, gunners and navigator: every seat aboard has its own view.")
	var pad: Transform3D = a.get("rocket_pad", Transform3D(Basis.IDENTITY, centre))
	await _shot(camera, pad.origin+Vector3(12, 6, 12), pad.origin+Vector3(8, 4, 9), func() -> Vector3: return pad.origin+Vector3.UP*3.0, 4.0,
		"Orin's rocket lands on the Surface. R returns you to the Tavern from anywhere in the Reach.")
	var far: Vector3 = SpaceLayout.planet("verdance").center
	await _shot(camera, centre+Vector3(0, 40, -80), centre+Vector3(0, 60, -140), func() -> Vector3: return far, 4.0,
		"Planets wait in the Haven. Beyond the Shardfield lies the Gloam. M opens the star map.")
	_caption.text = ""

## The battleship rises off its Surface pad, tips its nose up and races into
## the sky (the portal zoom follows, see SurfaceLaunchpad).
func battleship_launch(camera: Camera3D, ship: ShipHull, _caption_text: String) -> void:
	var fixed := camera.global_transform
	var base := ship.global_position
	var t := 0.0
	while t<5.0:
		t += get_process_delta_time()
		ship.global_position = base+Vector3.UP*maxf(0.0, t-1.0)*maxf(0.0, t-1.0)*20.0
		camera.global_transform = fixed
		await get_tree().process_frame

## The battleship comes down out of the sky and settles on `rest` (world space).
func battleship_landing(camera: Camera3D, ship: ShipHull, rest: Vector3, _caption_text: String) -> void:
	var fixed := camera.global_transform
	var t := 0.0
	while t<4.2:
		t += get_process_delta_time()
		ship.global_position = rest+Vector3.UP*160.0*pow(1.0-clampf(t/4.2, 0.0, 1.0), 3.0)
		camera.global_transform = fixed
		await get_tree().process_frame

## In Space: the ship noses down and dives toward the Surface far below.
func space_dive(camera: Camera3D, ship: Node3D, caption: String) -> void:
	var start := ship.global_transform
	var back := start.basis.z.normalized()
	var t := 0.0
	while t<3.0:
		var dt := get_process_delta_time()
		t += dt
		var forward := Vector3.DOWN.lerp(-back, 0.35).normalized()
		var up := Vector3.FORWARD if absf(forward.dot(Vector3.UP)) > 0.95 else Vector3.UP
		var dive := Basis.looking_at(forward, up)
		ship.global_transform = Transform3D(start.basis.slerp(dive, minf(1.0, t*0.8)), start.origin+Vector3.DOWN*(t*t*40.0))
		var eye := ship.global_position+Vector3.UP*30.0+back*55.0
		camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(ship.global_position, Vector3.UP if absf(back.y)<0.9 else Vector3.FORWARD)
		camera.fov = lerpf(camera.fov, 95.0, dt*0.8)
		_caption.text = caption
		await get_tree().process_frame

## In Space: the ship climbs up out of the Surface's air.
func space_rise(camera: Camera3D, ship: Node3D, caption: String) -> void:
	var end := ship.global_transform
	var back := end.basis.z.normalized()
	var t := 0.0
	while t<2.6:
		t += get_process_delta_time()
		var k := 1.0-pow(1.0-clampf(t/2.6, 0.0, 1.0), 3.0)
		ship.global_transform = Transform3D(end.basis, end.origin+Vector3.DOWN*(1.0-k)*420.0)
		var eye := end.origin+back*70.0+Vector3.UP*24.0
		camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(ship.global_position, Vector3.UP)
		_caption.text = caption
		await get_tree().process_frame
	ship.global_transform = end
