class_name NexusBar
extends Node3D
## A standing-scale public bar assembled from the reusable social furniture.
const Art = preload("res://scripts/space/art/ship_hull.gd").ArtBatch
var _bartender: CreatureModel

func _block(art: Art, at: Vector3, size: Vector3, color: Color, solid := true) -> void:
	art.box(at, size, color)
	if solid: art.solid(at, size)

func build(server: bool) -> void:
	var art := Art.new(self, server)
	var wood := Color("77513b")
	var dark := Color("3c2c28")
	var brass := Color("c79e62")
	_block(art, Vector3(0, 1.9, -35), Vector3(29, 3.8, 0.3), dark)
	# Waist-high sills and framed windows keep the bar open to the stars.
	for side: float in [-1.0, 1.0]:
		_block(art, Vector3(side*14.5, 0.55, -27), Vector3(0.3, 1.1, 16), wood)
		_block(art, Vector3(side*14.5, 3.25, -27), Vector3(0.3, 1.1, 16), dark)
		for z: float in [-34.5, -31, -27, -23, -19.5]:
			_block(art, Vector3(side*14.5, 1.9, z), Vector3(0.4, 3.8, 0.22), wood)
		for z: float in [-32.75, -29, -25, -21.25]:
			art.solid(Vector3(side*14.5, 1.9, z), Vector3(0.15, 1.6, 3.2))
		for x: float in [side*8.0]:
			_block(art, Vector3(x, 0.5, -19), Vector3(12.8, 1.0, 0.3), wood)
			_block(art, Vector3(x, 3.3, -19), Vector3(12.8, 1.0, 0.3), dark)
		for x: float in [side*1.65, side*6.0, side*10.5, side*14.4]:
			_block(art, Vector3(x, 1.9, -19), Vector3(0.22, 3.8, 0.3), wood)
		# Layered roof planks form two pitched slopes with a timber ridge.
		for strip in 10:
			var x := side*(strip+0.5)*1.5
			var at := Vector3(x, 5.4-float(strip)*0.16, -27)
			var basis := Basis(Vector3.FORWARD, side*0.106)
			art.box(at, Vector3(1.55, 0.2, 17.4), Color("4c655f").lightened((strip%3)*0.025), 0, basis)
			art.solid(at, Vector3(1.55, 0.2, 17.4), basis)
	_block(art, Vector3(0, 5.48, -27), Vector3(0.28, 0.25, 17.6), dark)
	for z: float in [-34.5, -27, -19.5]:
		art.box(Vector3(0, 3.8, z), Vector3(29, 0.16, 0.2), wood)
	# The serving counter is below standing eye height, with a brass foot rail.
	_block(art, Vector3(-3, 0.53, -30), Vector3(17, 1.06, 1.2), wood)
	_block(art, Vector3(-3, 1.1, -30), Vector3(17.3, 0.14, 1.45), dark)
	art.box(Vector3(-3, 0.25, -29.15), Vector3(16.8, 0.06, 0.06), brass)
	LeisureFurniture.tap(self, "nexus:beer", Transform3D(Basis.IDENTITY, Vector3(-6, 1.18, -29.8)), server)
	LeisureFurniture.tap(self, "nexus:coffee", Transform3D(Basis.IDENTITY, Vector3(0, 1.18, -29.8)), server, "coffee")
	for i in 5:
		var x := -9.0+i*3.0
		LeisureFurniture.chair(self, "nexus:stool%d" % i, Transform3D(Basis.IDENTITY, Vector3(x, 0, -27.5)), server, true)
		LeisureFurniture.table_spot(self, "nexus:counter%d" % i, Transform3D(Basis.IDENTITY, Vector3(x, 1.18, -29.4)))
	# Two small tables, each with four proper backed chairs and drink spots.
	for index in 2:
		var at := Vector3(-7 if index==0 else 7, 0, -23)
		_block(art, at+Vector3.UP*0.43, Vector3(0.22, 0.86, 0.22), dark)
		_block(art, at+Vector3.UP*0.9, Vector3(1.8, 0.14, 1.6), wood)
		for k in 4:
			var angle := k*PI*0.5
			var out := Vector3(sin(angle), 0, cos(angle))
			LeisureFurniture.chair(self, "nexus:table%d:chair%d" % [index, k], Transform3D(Basis(Vector3.UP, angle), at+out*1.45), server)
			LeisureFurniture.table_spot(self, "nexus:table%d:cup%d" % [index, k], Transform3D(Basis.IDENTITY, at+out*0.58+Vector3.UP*0.98))
	# Bottles, cups and a cigar box belong on shelves and the counter.
	for shelf in 3:
		art.box(Vector3(-3, 1.3+shelf*0.7, -34.55), Vector3(18, 0.09, 0.55), wood)
		for bottle in 14:
			var at := Vector3(-10+bottle*1.1, 1.5+shelf*0.7, -34.5)
			art.box(at, Vector3(0.16, 0.3, 0.16), Color("5c8072") if bottle%2 else Color("a77c4b"))
			art.box(at+Vector3.UP*0.21, Vector3(0.08, 0.12, 0.08), brass)
	art.box(Vector3(4.2, 1.23, -29.5), Vector3(0.55, 0.12, 0.35), Color("6a422e"))
	LeisureFurniture.target(self, "nexus:cigars", "cigar", Transform3D(Basis.IDENTITY, Vector3(4.2, 1.3, -29.5)))
	for x: float in [-8, 0, 8]:
		art.box(Vector3(x, 3.6, -26), Vector3(0.05, 0.65, 0.05), brass)
		art.box(Vector3(x, 3.18, -26), Vector3(0.56, 0.12, 0.56), dark)
		art.box(Vector3(x, 2.96, -26), Vector3(0.35, 0.32, 0.35), Color("ffd091"), 0.8)
		if not server:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 2.7, -26)
			lamp.light_color = Color("ffca8b")
			lamp.light_energy = 0.8
			lamp.omni_range = 8.0
			lamp.shadow_enabled = false
			add_child(lamp)
	art.finish()
	if server: return
	var sign := SignBoard.make("THE LANTERN BAR", "plank", "beer", Color("ffe4b0"), 0.65)
	sign.position = Vector3(0, 3.3, -18.8)
	add_child(sign)
	for entry: Array in [["BEER", -6.0], ["COFFEE", 0.0]]:
		var label := SignBoard.make(str(entry[0]), "brass", "", Color("ffe0b0"), 0.35)
		label.position = Vector3(float(entry[1]), 1.6, -30.2)
		add_child(label)
	_bartender = CreatureModel.new("npc_baker")
	_bartender.position = Vector3(-3, 0, -32)
	_bartender.rotation.y = PI
	add_child(_bartender)

func _process(delta: float) -> void:
	if is_instance_valid(_bartender): _bartender.animate(0.0, delta)
