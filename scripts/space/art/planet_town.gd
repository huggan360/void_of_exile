class_name PlanetTown
extends Node3D
## A planet's town (SpaceLayout.TOWNS), clients only: a stone plaza on the
## flattened ground, a ring of buildings facing it, a centrepiece, lanterns,
## wandering townsfolk, the smith (sells your items for Dots at the forge)
## and the shipwright by the shipyard pad (buys you a ship). Village towns use
## the realm's voxel houses; alien towns are built from its voxel obstacles,
## grown big and recoloured for their world.
const RING := 27.0
const FOLK := 7
var world: SpaceWorld
var planet: Dictionary
var _folk: Array = []  # {model, at (Vector2 town offset), goal, speed, wait}
var _rng := RandomNumberGenerator.new()

func build(p: Dictionary) -> void:
	planet = p
	var town: Dictionary = SpaceLayout.TOWNS[p.id]
	_rng.seed = absi(String(p.id).hash())+5
	var center := SpaceLayout.town_frame(p, "center")
	var plaza := Node3D.new()
	plaza.transform = center
	add_child(plaza)
	var art := NexusStation.Brush.new(plaza, false, 1400.0)
	var colors: Array = PlanetFlora.SETS[p.id].colors
	var stone := Color(str(colors[0]))
	art.round_part(Vector3(0, -0.15, 0), 19.0, 0.4, stone.darkened(0.15), true)
	art.round_part(Vector3(0, 0.06, 0), 19.6, 0.04, Color("d3a34e"))
	art.round_part(Vector3(0, 0.08, 0), 18.6, 0.04, stone)
	for i in 12:
		var a := TAU*i/12.0
		art.box(Vector3(cos(a)*15.5, 0.12, sin(a)*15.5), Vector3(2.4, 0.04, 0.5), stone.lightened(0.15), false, 0.0)
	_centrepiece(art, str(town.style), Color(str(colors[6])))
	for i in 10:
		var a := TAU*(i+0.5)/10.0
		art.lantern(Vector3(cos(a)*20.5, 0, sin(a)*20.5), 4.0)
	art.finish()
	# Buildings in a ring, doors toward the plaza; a gap toward the shipyard.
	var houses: Array = town.houses
	for i in 9:
		var a := TAU*i/9.0+0.35
		var local := Vector2(cos(a), sin(a))*RING
		if local.y>16.0 and absf(local.x)<12.0: continue
		var frame := SpaceLayout.place_frame(p, SpaceLayout.TOWN_OFFSET+local)
		var facing := Basis(Vector3.UP, atan2(local.x, local.y))
		_building(str(houses[i % houses.size()]), Transform3D(frame.basis*facing, frame.origin), str(town.style))
	_shipyard(p)
	# The two traders and the townsfolk.
	_trader(p, "smith", str(town.smith), "%s's smith" % town.name, "Lay anything on the anvil and the forge turns it into Dots.")
	_trader(p, "wright", str(town.wright), "%s shipwright" % town.name, "A sound little sky-galleon, fitted and waiting on the shipyard pad.")
	var folk: Array = town.folk
	for i in FOLK:
		var model := CreatureModel.new(str(folk[i % folk.size()]))
		add_child(model)
		var at := Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-14, 14))
		_folk.append({model = model, at = at, goal = at, wait = _rng.randf_range(0.0, 4.0)})
		_place(model, at, 0.0)

func _centrepiece(art: NexusStation.Brush, style: String, glow: Color) -> void:
	match style:
		"village":
			art.round_part(Vector3(0, 0.5, 0), 3.4, 1.0, Color("8a8676"), true)
			art.round_part(Vector3(0, 1.02, 0), 2.9, 0.06, Color("5ab8e8"), false, 0.4)
			art.round_part(Vector3(0, 2.0, 0), 0.5, 2.0, Color("8a8676"), true)
			art.part("sphere", Transform3D(Basis.IDENTITY, Vector3(0, 3.3, 0)), Vector3.ONE*1.0, glow, false, 2.0)
		_:
			for j in 6:
				var a := TAU*j/6.0
				art.crystal(Vector3(cos(a)*1.6, 0.0, sin(a)*1.6), 4.0+j % 3*1.5, glow, true)
			art.crystal(Vector3.ZERO, 8.0, glow.lightened(0.2), true)

func _building(kind: String, frame: Transform3D, style: String) -> void:
	if style=="village":
		var house := VillageHouse.new().setup({asset = kind, pos = Vector3.ZERO, yaw = 0.0, solid_size = Vector3(7.5, 6.0, 7.5)})
		var holder := Node3D.new()
		holder.transform = frame
		add_child(holder)
		holder.add_child(house)
		return
	# Alien halls: one of the realm's obstacles, grown to a building, recoloured.
	var prefab := ObstacleLibrary.get_prefab(kind)
	var size := 4.2 if kind in ["crystal_cluster", "glowshroom", "boulder"] else 2.6
	var meshes := prefab.meshes_for(PlanetFlora.biome_for(planet))
	var holder := Node3D.new()
	holder.transform = frame
	add_child(holder)
	for slot in 2:
		if meshes[slot]==null: continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = meshes[slot]
		mesh.material_override = _soft_glow() if slot==1 else VoxModel.material()
		mesh.position = prefab.mesh_offset()*size
		mesh.scale = Vector3.ONE*prefab.voxel_size*size
		holder.add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = Player.OBSTACLE_LAYER
	body.collision_mask = 0
	holder.add_child(body)
	for box: AABB in prefab.collision_boxes:
		var shape := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		solid.size = Vector3(box.size.x, maxf(box.size.y, prefab.height), box.size.z)*size
		shape.shape = solid
		shape.position = box.get_center()*size
		body.add_child(shape)
	var light := OmniLight3D.new()
	light.light_color = Color(str(PlanetFlora.SETS[planet.id].colors[6]))
	light.light_energy = 0.8
	light.omni_range = 12.0
	light.position.y = prefab.height*size*0.6
	light.distance_fade_enabled = true
	light.distance_fade_begin = 160.0
	light.distance_fade_length = 40.0
	holder.add_child(light)

static var _glow: ShaderMaterial

## Building-sized glow is gentler than a lantern's, or it blooms to white.
static func _soft_glow() -> ShaderMaterial:
	if _glow==null:
		_glow = VoxModel.glow_material().duplicate() as ShaderMaterial
		_glow.set_shader_parameter("glow_strength", 0.9)
	return _glow

func _shipyard(p: Dictionary) -> void:
	var dock := Node3D.new()
	dock.transform = SpaceLayout.town_frame(p, "dock")
	add_child(dock)
	var art := NexusStation.Brush.new(dock, false, 1400.0)
	var stone := Color(str(PlanetFlora.SETS[p.id].colors[1]))
	art.round_part(Vector3(0, -0.2, 0), 27.0, 0.5, stone, true)
	art.round_part(Vector3(0, 0.07, 0), 27.6, 0.04, Color("d3a34e"))
	for i in 24:
		var a := TAU*i/24.0
		art.box(Vector3(cos(a)*25.8, 0.12, sin(a)*25.8), Vector3(0.6, 0.08, 0.6), Color("85efac"), false, 1.2)
	for side in [-1.0, 1.0]:
		art.box(Vector3(-22.0, 2.5, side*3.0), Vector3(0.4, 5.0, 0.4), Color("6d4839"), true)
	art.box(Vector3(-22.0, 4.6, 0), Vector3(0.3, 1.4, 6.8), Color("e8c48a"))
	art.finish()
	# Painted on the board between the two posts, both faces.
	for k in 2:
		var sign := SignBoard.make("SHIPYARD", "paint", "", Color("4a3024"), 1.6)
		sign.position = Vector3(-22.0+(0.16 if k==0 else -0.16), 4.6, 0)
		sign.rotation.y = PI*0.5 if k==0 else -PI*0.5
		dock.add_child(sign)

func _trader(p: Dictionary, which: String, model_id: String, title: String, line: String) -> void:
	var frame := SpaceLayout.town_frame(p, which)
	var holder := Node3D.new()
	holder.transform = frame
	add_child(holder)
	var model := CreatureModel.new(model_id)
	holder.add_child(model)
	_folk.append({model = model, fixed = true})
	if which=="smith":
		var art := NexusStation.Brush.new(holder, false, 600.0)
		art.box(Vector3(0, 0.45, -1.6), Vector3(1.2, 0.9, 0.6), Color("3a3a40"), true)
		art.box(Vector3(0, 0.95, -1.6), Vector3(1.5, 0.15, 0.7), Color("55555f"))
		art.round_part(Vector3(-1.8, 0.6, -2.0), 0.7, 1.2, Color("6a3a2a"), true)
		art.part("sphere", Transform3D(Basis.IDENTITY, Vector3(-1.8, 1.3, -2.0)), Vector3.ONE*0.6, Color("ff8a3a"), false, 3.0)
		art.finish()
		var target := InteractionTarget.new()
		target.title = title
		target.description = line
		target.response = line
		target.action_text = "Sell items"
		target.reach = 4.0
		target.position = Vector3.UP
		holder.add_child(target)
		target.activated.connect(func(_actor: Node3D) -> void: get_tree().call_group("forge_panels", "open_for", target, holder))
	else:
		var shop := SpaceInteraction.new()
		shop.world = world
		shop.kind = "wright"
		shop.part = str(p.id)
		shop.title = title
		shop.description = line
		shop.position = Vector3.UP
		holder.add_child(shop)

func _place(model: Node3D, at: Vector2, yaw: float) -> void:
	var frame := SpaceLayout.place_frame(planet, SpaceLayout.TOWN_OFFSET+at)
	model.transform = Transform3D(frame.basis*Basis(Vector3.UP, yaw), frame.origin)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera==null or camera.global_position.distance_to(global_transform*SpaceLayout.town_frame(planet, "center").origin)>500.0: return
	# Townsfolk stroll between spots around the plaza.
	for folk: Dictionary in _folk:
		var model: CreatureModel = folk.model
		if folk.get("fixed", false):
			model.animate(0.0, delta)
			continue
		folk.wait = float(folk.wait)-delta
		var at: Vector2 = folk.at
		var goal: Vector2 = folk.goal
		if at.distance_to(goal)<0.3:
			model.animate(0.0, delta)
			if float(folk.wait)<=0.0:
				folk.goal = Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(4.0, 17.0)
				folk.wait = _rng.randf_range(2.0, 6.0)
			continue
		var step := (goal-at).normalized()*1.4*delta
		folk.at = at+step
		_place(model, folk.at, atan2(-step.x, -step.y))
		model.animate(1.0, delta)
