class_name LeisureFurniture
extends RefCounted
## Small reusable furniture pieces. Add these beneath any GameWorld using
## deterministic keys: chair(), tap() and table_spot() supply interactions.
const Art = preload("res://scripts/space/art/ship_hull.gd").ArtBatch

static func world_of(node: Node) -> GameWorld:
	var cursor := node
	while cursor!=null:
		if cursor is GameWorld: return cursor
		cursor = cursor.get_parent()
	return null

static func target(parent: Node3D, id: String, kind: String, frame: Transform3D, drink := "beer") -> LeisureTarget:
	var point := LeisureTarget.new()
	point.key = id
	point.kind = kind
	point.drink = drink
	point.place = world_of(parent)
	point.transform = frame
	parent.add_child(point)
	return point

static func chair(parent: Node3D, id: String, frame: Transform3D, server: bool, stool := false, interactive := true) -> LeisureTarget:
	var root := Node3D.new()
	root.transform = frame
	parent.add_child(root)
	var art := Art.new(root, server)
	var height := 0.74 if stool else 0.45
	var wood := Color("75503a")
	var cloth := Color("6d4356")
	for x: float in [-0.25, 0.25]:
		for z: float in [-0.24, 0.24]:
			art.box(Vector3(x, height*0.5, z), Vector3(0.09, height, 0.09), wood)
			art.solid(Vector3(x, height*0.5, z), Vector3(0.09, height, 0.09))
	art.box(Vector3(0, height, 0), Vector3(0.67, 0.13, 0.65), wood)
	art.box(Vector3(0, height+0.08, 0), Vector3(0.58, 0.07, 0.57), cloth)
	art.solid(Vector3(0, height*0.5, 0), Vector3(0.66, height, 0.64))
	for x: float in [-0.27, 0.27]: art.box(Vector3(x, height+0.34, 0.29), Vector3(0.08, 0.7, 0.08), wood)
	for y: float in [height+0.3, height+0.55]: art.box(Vector3(0, y, 0.29), Vector3(0.6, 0.13, 0.08), wood)
	art.solid(Vector3(0, height+0.35, 0.29), Vector3(0.66, 0.7, 0.09))
	if stool:
		art.box(Vector3(0, 0.25, -0.27), Vector3(0.6, 0.07, 0.07), Color("c39b61"))
	art.finish()
	if not interactive: return null
	var point := target(root, id, "seat", Transform3D.IDENTITY)
	point.stand = Vector3(0.85, 0.05, 0.1)
	point.seat_height = height
	return point

static func table_spot(parent: Node3D, id: String, frame: Transform3D) -> LeisureTarget:
	return target(parent, id, "table", frame)

static func tap(parent: Node3D, id: String, frame: Transform3D, server: bool, drink := "beer") -> LeisureTarget:
	var root := Node3D.new()
	root.transform = frame
	parent.add_child(root)
	var art := Art.new(root, server)
	var brass := Color("c49b60")
	var dark := Color("3e3b3a")
	if drink=="coffee":
		art.box(Vector3(0, 0.17, 0), Vector3(0.32, 0.34, 0.28), Color("897b65"))
		art.box(Vector3(0, 0.36, 0), Vector3(0.39, 0.04, 0.32), dark)
		art.box(Vector3(0, 0.22, 0.19), Vector3(0.08, 0.06, 0.19), dark)
		art.box(Vector3(0.22, 0.18, 0), Vector3(0.08, 0.23, 0.12), dark)
	else:
		art.box(Vector3(0, 0.04, 0), Vector3(0.45, 0.08, 0.32), dark)
		art.box(Vector3(0, 0.3, 0), Vector3(0.12, 0.55, 0.12), brass)
		art.box(Vector3(0, 0.53, 0.13), Vector3(0.12, 0.12, 0.35), brass)
		art.box(Vector3(0, 0.45, 0.27), Vector3(0.1, 0.2, 0.1), brass)
		art.box(Vector3(0, 0.7, 0.07), Vector3(0.07, 0.32, 0.07), dark)
		art.box(Vector3(0, 0.86, 0.07), Vector3(0.15, 0.13, 0.12), Color("7d4450"))
	art.finish()
	return target(root, id, "tap", Transform3D.IDENTITY, drink)

static func ship(place: SpaceWorld, room: Node3D, slot: int, server: bool) -> void:
	var vessel := place.ship_in_slot(slot)
	if vessel==null: return
	var id := vessel.fleet_id if vessel.fleet_id>0 else vessel.id
	var prefix := "ship:%d:" % id
	var furniture := Node3D.new()
	furniture.name = "LeisureFurniture"
	room.add_child(furniture)
	tap(furniture, prefix+"beer", Transform3D(Basis.IDENTITY, Vector3(6.2, 1.22, 7.6)), server)
	tap(furniture, prefix+"coffee", Transform3D(Basis.IDENTITY, Vector3(6.2, 1.22, 5.5)), server, "coffee")
	for i in room.anchors.get("glasses", []).size():
		table_spot(furniture, prefix+"table%d" % i, Transform3D(Basis.IDENTITY, room.anchors.glasses[i]+Vector3.UP*0.02))
