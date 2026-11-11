class_name LastLightDiner
extends Node3D
## A hidden roadside diner in the outer Gloam. No map marker by design.
## The building is one voxel model in the Vesperis style (tools/make_lastlight_diner.py,
## baked into CityHouses' catalogue): a rock under a steel deck, the 1950s diner
## with its Googie roof and neon, a DINER pylon and a chrome rocket; the two
## docking walks are a second model. Here: its meshes and colliders, and the
## working parts (taps, stools, booths, host, ship orders, lights, glass).
const Art = preload("res://scripts/space/art/ship_hull.gd").ArtBatch
## Where each detail level shows (metres from the camera).
const RANGES: Array[Vector2] = [Vector2(0, 320), Vector2(320, 1400), Vector2(1400, 24000)]
## The walks' middles (the berths' hatches line up with them).
const WALKS: Array[Vector3] = [Vector3(-29, 0, 0), Vector3(29, 0, 0)]
const COUNTER_Z := -15.0  # the counter's middle; its top is 1.25 m up
const BOOTH_X := 15.5
const BOOTH_Z: Array[float] = [-10.0, -5.0, 4.5, 9.0]
## Where the host stands behind the counter (diner space).
const HOST := Vector3(0, 0, -16.9)
var walkers: Array[CreatureModel] = []
var clock := 0.0

func build(server: bool) -> void:
	position = SpaceLayout.DINER
	var art := Art.new(self, server)
	_model(art, "lastlight_diner", Transform3D.IDENTITY, server)
	for at: Vector3 in WALKS: _model(art, "lastlight_walk", Transform3D(Basis.IDENTITY, at), server)
	# Ship orders on the front deck, under the canopy.
	art.box(Vector3(0, 0.5, 17.4), Vector3(1.2, 1.0, 0.7), Color("a5bdca"))
	art.box(Vector3(0, 1.05, 17.4), Vector3(1.0, 0.1, 0.5), Color("56fff1"), 1.6)
	art.solid(Vector3(0, 0.5, 17.4), Vector3(1.2, 1.0, 0.7))
	art.finish()
	# Working drinks and seats along the counter.
	var top := 1.25
	LeisureFurniture.tap(self, "lastlight:beer", Transform3D(Basis.IDENTITY, Vector3(-4, top, COUNTER_Z)), server)
	LeisureFurniture.tap(self, "lastlight:coffee", Transform3D(Basis.IDENTITY, Vector3(4, top, COUNTER_Z)), server, "coffee")
	for i in 6:
		var x := -10.0+i*4.0
		LeisureFurniture.chair(self, "lastlight:counter%d" % i, Transform3D(Basis.IDENTITY, Vector3(x, 0, COUNTER_Z+2.2)), server, true)
		LeisureFurniture.table_spot(self, "lastlight:cup%d" % i, Transform3D(Basis.IDENTITY, Vector3(x, top, COUNTER_Z+0.6)))
	# Booths along both windows: you sit on the bench nearer the door, a guest
	# sits across the table in half of them.
	for side: float in [-1.0, 1.0]:
		for row in BOOTH_Z.size():
			var cz: float = BOOTH_Z[row]
			LeisureFurniture.bench_targets(self, "lastlight:booth%d:%d" % [int(side), row], Transform3D(Basis.IDENTITY, Vector3(side*BOOTH_X, 0, cz+1.5)), 0.75)
			if server or (row+int(side>0)) % 2==0: continue
			var guest := CreatureModel.new("npc_traveler")
			guest.position = Vector3(side*BOOTH_X, 0.3, cz-1.5)
			guest.scale = Vector3.ONE*0.85
			guest.rotation.y = PI
			add_child(guest)
			for limb: String in ["leg_l", "leg_r"]:
				if guest._limbs.has(limb): guest._limbs[limb].rotation.x = -PI*0.5
	var terminal := SpaceInteraction.new()
	terminal.world = get_parent() as SpaceWorld
	terminal.kind = "table"
	terminal.position = Vector3(0, 1, 17.0)
	add_child(terminal)
	terminal.title = "Last Light ship orders"
	terminal.description = "Order a ship for one of the two diner ports."
	if server: return
	var terminal_sign := SignBoard.make("SHIP ORDERS", "brass", "", Color("56fff1"), 0.4)
	terminal_sign.position = Vector3(0, 2.0, 17.4)
	add_child(terminal_sign)
	_glass()
	for x: float in [-8.0, 8.0]:
		for z: float in [-12.0, -3.0, 6.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 4.6, z)
			lamp.light_color = Color("ffd49a")
			lamp.light_energy = 1.1
			lamp.omni_range = 11.0
			NearbyLightShadows.register_light(lamp)
			add_child(lamp)
	for spot: Array in [[Vector3(0, 7.5, 13.5), Color("ff53aa")], [Vector3(-21, 12, 25), Color("ff53aa")], [Vector3(18, 9, 25), Color("ffbe58")]]:
		var neon := OmniLight3D.new()
		neon.position = spot[0]
		neon.light_color = spot[1]
		neon.light_energy = 1.4
		neon.omni_range = 16.0
		add_child(neon)
	var host := CreatureModel.new("npc_baker")
	host.position = HOST
	host.rotation.y = PI  # models face -Z: turn to the counter
	add_child(host)
	# Wire the diner's host model to the campaign NPC (no second character).
	var host_target := InteractionTarget.new()
	host_target.title = str(Campaigns.NPCS.lastlight_host.name)
	host_target.description = str(Campaigns.NPCS.lastlight_host.greeting)
	host_target.response = str(Campaigns.NPCS.lastlight_host.greeting)
	host_target.action_text = "Talk"
	host_target.reach = 4.0
	host_target.position = Vector3.UP
	host.add_child(host_target)
	host_target.activated.connect(func(_actor: Node3D) -> void:
		if Net.is_client(): Net.client.send_action("camp", ["quest", "npc:lastlight_host"]))
	for i in 3:
		var npc := CreatureModel.new("npc_baker" if i==0 else "npc_traveler")
		add_child(npc)
		walkers.append(npc)

## One of the baked models at `xform` (diner space): its detail levels (the
## client) and its wall colliders (everyone).
func _model(art: Art, name: String, xform: Transform3D, server: bool) -> void:
	var info := CityHouses.info(name)
	if info.is_empty(): return
	for c: Dictionary in info.get("colliders", []):
		art.solid(xform*Vector3(c.offset[0], c.offset[1], c.offset[2]), Vector3(c.size[0], c.size[1], c.size[2]))
	if server: return
	var lods: Array = info.lods
	for k in lods.size():
		var lod: Dictionary = lods[k]
		var at := xform*Transform3D(Basis.from_scale(Vector3.ONE*float(lod.scale)), Vector3(lod.offset[0], lod.offset[1], lod.offset[2]))
		var meshes: Array = [[str(lod.mesh), false]]
		if lod.has("glow"): meshes.append([str(lod.glow), true])
		for entry: Array in meshes:
			var node := MeshInstance3D.new()
			node.mesh = load(str(entry[0]))
			node.transform = at
			node.material_override = VoxModel.glow_material() if entry[1] else VoxModel.material()
			node.visibility_range_begin = RANGES[k].x
			node.visibility_range_end = RANGES[k].y
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if k==0 and not entry[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)

## Faint glass in the big window frames (front and both sides; the doors stay open).
func _glass() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.12)
	mat.metallic = 0.4
	mat.roughness = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var panes: Array = [
		[Vector3(-10.0, 3.12, 11.75), Vector3(14.0, 3.25, 0.04)], [Vector3(10.0, 3.12, 11.75), Vector3(14.0, 3.25, 0.04)],
	]
	for side: float in [-1.0, 1.0]:
		panes.append([Vector3(side*17.75, 3.12, -10.25), Vector3(0.04, 3.25, 16.5)])
		panes.append([Vector3(side*17.75, 3.12, 6.5), Vector3(0.04, 3.25, 9.0)])
	for pane: Array in panes:
		var mesh := BoxMesh.new()
		mesh.size = pane[1]
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = mat
		node.position = pane[0]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

func _process(delta: float) -> void:
	clock += delta
	for i in walkers.size():
		var npc: CreatureModel = walkers[i]
		var t: float = clock*0.22+i*2.1
		npc.position = Vector3(sin(t)*5.0, 0, -2.0+cos(t)*3.5)
		npc.rotation.y = atan2(cos(t)*5.0, -sin(t)*3.5)
		npc.animate(0.35, delta)
