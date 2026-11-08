class_name PlanetStrongholds
extends StrongholdGates
## The boss strongholds on the Astral Reach's planets (SpaceLayout.FORTS): a
## walled voxel fortress on a level terrace, its two portcullises sealed until
## someone turns the fortress's key at one (dropped by the planet's god). The
## boss waits in the middle and the gates bar while it fights, like the realm's
## strongholds (same footprint, so StrongholdGates' locks, arena and opening
## shot all apply). Each world has its own look ("style").
const VOX := 1.0
const WALL_IN := 32
const WALL_OUT := 35
const WALL_TALL := 8
## [main gate half width, back gate half width] in cells, centred on x = 0.
const GATE_HALF := [5.5, 2.5]
## style -> colors: stone, dark, trim, glow, glow2, floor, floor2, and the gate bars' glow.
const LOOKS := {
	rose = {stone = "f0c8da", dark = "b07890", trim = "fff3f8", glow = "ff6eb4", glow2 = "7dffb0", floor = "e8b8cc", floor2 = "fff0f7", bars = "ff6eb4"},
	amber = {stone = "d9a85a", dark = "8a5a26", trim = "fff0c8", glow = "ffb84a", glow2 = "fff0a0", floor = "c89048", floor2 = "e8c078", bars = "ffb84a"},
	moon = {stone = "8a8e9a", dark = "4a4d58", trim = "b8b4a8", glow = "7dff6a", glow2 = "c8ffd0", floor = "5a5d68", floor2 = "7d818e", bars = "7dff6a"},
	hive = {stone = "5a3070", dark = "2a1530", trim = "8a4aa0", glow = "ff5fd2", glow2 = "7dff6a", floor = "3a2048", floor2 = "4a2a5a", bars = "ff5fd2"},
	storm = {stone = "2a2d3a", dark = "14161e", trim = "4a5266", glow = "9ab0ff", glow2 = "ff4a5a", floor = "1e2029", floor2 = "2a2d3a", bars = "9ab0ff"},
}
var world: SpaceWorld

## Every planet's fortress; `dedicated` builds only what the server needs.
func build_planets(p_world: SpaceWorld, dedicated: bool) -> void:
	world = p_world
	server_build = dedicated
	for id: String in SpaceLayout.FORTS:
		var p := SpaceLayout.planet(id)
		var spec: Dictionary = SpaceLayout.FORTS[id]
		var frame := SpaceLayout.fort_frame(p)
		var root := Node3D.new()
		root.name = "Fort_%s" % id
		root.transform = Transform3D(frame.basis, (p.center as Vector3)+frame.origin)
		add_child(root)
		var center := center_of(id)
		var look: Dictionary = LOOKS[spec.style]
		var gates: Array = []
		for spec_gate: Vector3 in [Vector3(11, 6, -33), Vector3(5, 4, 34)]:
			var body := StaticBody3D.new()
			body.position = Vector3(0, spec_gate.y*0.5, spec_gate.z)
			body.collision_layer = 0
			body.collision_mask = 0
			root.add_child(body)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(spec_gate.x, spec_gate.y, 4)
			shape.shape = box
			body.add_child(shape)
			var visual := Node3D.new()
			root.add_child(visual)
			visual.position = Vector3(0, spec_gate.y+0.6, spec_gate.z)
			if not dedicated: _portcullis(visual, spec_gate.x, spec_gate.y, Color(str(look.bars)))
			gates.append({body = body, visual = visual, height = spec_gate.y, box = AABB(body.position-box.size*0.5, box.size)})
		entries[center] = {root = root, fort = {display_name = spec.name, key = spec.key, style = spec.style, planet = id,
			biome_id = -1}, gates = gates, locked = true, requested = false, sealed = true, close_at = 0}
		for gate: Dictionary in gates:
			gate.body.collision_layer = Player.OBSTACLE_LAYER
			gate.visual.position.y = 0
		if not dedicated:
			FortArt.new(root, str(spec.style), look).build()
			for at: Vector3 in [Vector3(0, 0, -38), Vector3(0, 0, 39)]:
				var lock := GateLock.new()
				lock.gates = self
				lock.center = center
				lock.position = at
				lock.reach = 6.5
				root.add_child(lock)

## The key a fortress is found under (its centre, rounded): matches entries.
static func center_of(planet_id: String) -> Vector2i:
	var p := SpaceLayout.planet(planet_id)
	var at: Vector3 = (p.center as Vector3)+SpaceLayout.fort_frame(p).origin
	return Vector2i(roundi(at.x), roundi(at.z))

## World-space centre of a planet's fortress floor.
static func floor_center(planet_id: String) -> Vector3:
	var p := SpaceLayout.planet(planet_id)
	return (p.center as Vector3)+SpaceLayout.fort_frame(p).origin

func key_for(center: Vector2i) -> String:
	return str(entries[center].fort.key) if entries.has(center) else ""

func center_for(pos: Vector3) -> Vector2i:
	for center: Vector2i in entries:
		if Vector2(pos.x-center.x, pos.z-center.y).length()<40.0: return center
	return Vector2i(1 << 29, 1 << 29)

## Planet enemies never cross a fortress wall (the server has no planet collision).
func blocks_enemy(pos: Vector3) -> bool:
	for entry: Dictionary in entries.values():
		var local: Vector3 = (entry.root as Node3D).global_transform.affine_inverse()*pos
		var edge := maxf(absf(local.x), absf(local.z))
		if edge>WALL_IN-0.8 and edge<WALL_OUT+1.2: return true
	return false

func _unsealed(center: Vector2i) -> void:
	var entry: Dictionary = entries[center]
	var player: Player = world.local_player as Player if is_instance_valid(world) else null
	for gate: Dictionary in entry.gates:
		var at: Vector3 = entry.root.to_global(gate.body.position)
		Boss.flash_light(self, at, Color(str(LOOKS[entry.fort.style].bars)), 2.0, 10.0, 1.4)
		CameraShake.shake_at(at, 0.35, 30.0)
	GameAudio.play("combat.boss_rumble", entry.root.global_position, {cooldown = 1.0})
	if not is_instance_valid(player) or player.frozen or not near_lock(center, player.global_position): return
	_end_shot()
	var camera := Camera3D.new()
	add_child(camera)
	var previous := get_viewport().get_camera_3d()
	camera.fov = player.camera.fov
	camera.global_transform = previous.global_transform if previous else player.camera.global_transform
	camera.make_current()
	player.cinematic_locked = true
	player.begin_interaction(get_instance_id())
	player._cancel_weapon_actions()
	var back: bool = entry.root.to_local(player.global_position).z>0.0
	_shot = {camera = camera, previous = previous, player = player, center = center, back = back, t = 0.0,
		start = camera.global_transform, bars = _letterbox()}

func _occupied(entry: Dictionary) -> bool:
	if not is_instance_valid(world): return false
	for player: Node3D in world.enemy_director.players:
		if not is_instance_valid(player): continue
		var local: Vector3 = entry.root.to_local(player.global_position+Vector3.UP*0.85)
		for gate: Dictionary in entry.gates:
			if gate.box.grow(0.6).has_point(local): return true
	return false

## Iron bars in the fortress's colors, with a glowing crest.
func _portcullis(parent: Node3D, width: float, height: float, tint: Color) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.12, 0.16)
	metal.roughness = 0.8
	var glow := StandardMaterial3D.new()
	glow.albedo_color = tint
	glow.emission_enabled = true
	glow.emission = tint
	glow.emission_energy_multiplier = 0.9
	for x in int(width)+1:
		_box(parent, Vector3(x-width*0.5, height*0.5, 0), Vector3(0.24, height, 0.45), metal)
	for y in range(1, int(height), 2):
		_box(parent, Vector3(0, y, 0), Vector3(width, 0.28, 0.5), metal)
	_box(parent, Vector3(0, height-0.5, -0.28), Vector3(0.8, 0.8, 0.28), glow)
	for x: float in [-width*0.5+0.6, width*0.5-0.6]:
		_box(parent, Vector3(x, 0.4, -0.28), Vector3(0.4, 0.4, 0.2), glow)


## The fortress itself: voxel walls with crenels, corner towers, a gatehouse,
## a paved arena and each world's own touches. Collision boxes for the walls
## and towers (obstacle layer: they stop players and bullets).
class FortArt extends RefCounted:
	var root: Node3D
	var style: String
	var look: Dictionary
	var cells := {}  # Vector3i -> Color (alpha = glow)
	var rng := RandomNumberGenerator.new()
	var noise := FastNoiseLite.new()
	var body: StaticBody3D
	var lights: Array = []  # [local position, color, range, energy]

	func _init(p_root: Node3D, p_style: String, p_look: Dictionary) -> void:
		root = p_root
		style = p_style
		look = p_look
		rng.seed = absi(style.hash())
		noise.seed = rng.seed
		noise.frequency = 0.13

	func c(key: String, glow := 0.0) -> Color:
		var color := Color(str(look[key]))
		color.a = glow
		return color

	func put(x: int, y: int, z: int, color: Color) -> void:
		cells[Vector3i(x, y, z)] = color

	func build() -> void:
		body = StaticBody3D.new()
		body.collision_layer = Player.OBSTACLE_LAYER
		body.collision_mask = 0
		root.add_child(body)
		_floor()
		_walls()
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_tower(Vector2i(sx*(WALL_IN+2), sz*(WALL_IN+2)), 0)
		# The gatehouse: two towers flanking the main gate, a lower pair at the back.
		_tower(Vector2i(-9, -(WALL_IN+2)), 1)
		_tower(Vector2i(9, -(WALL_IN+2)), 1)
		_tower(Vector2i(-6, WALL_IN+2), 2)
		_tower(Vector2i(6, WALL_IN+2), 2)
		_decor()
		_mesh()
		for light: Array in lights:
			var omni := OmniLight3D.new()
			omni.position = light[0]
			omni.light_color = light[1]
			omni.omni_range = light[2]
			omni.light_energy = light[3]
			omni.shadow_enabled = false
			root.add_child(omni)

	## A paved arena (one cell, its top a hair above the terrace) and a ring of glowing runes.
	func _floor() -> void:
		for x in range(-WALL_OUT-3, WALL_OUT+4):
			for z in range(-WALL_OUT-3, WALL_OUT+4):
				var edge := maxi(absi(x), absi(z))
				var color := c("floor") if (x+z) % 2==0 else c("floor2")
				color = color.lightened(noise.get_noise_2d(x*3.0, z*3.0)*0.06)
				color.a = 0.0
				var ring := Vector2(x, z).length()
				match style:
					"rose":
						if absf(ring-14.0)<0.6 or absf(ring-22.0)<0.5: color = c("glow", 0.5)
						elif ring<6.0 and int(ring*2.0) % 3==0: color = c("trim")
					"amber":
						# Honeycomb-like tiles: offset rows of hexes, the seams glowing.
						var hx := posmod(x+(3 if posmod(z, 6)>=3 else 0), 6)
						if hx==0 or posmod(z, 3)==0 and hx==3: color = c("dark")
						if absf(ring-18.0)<0.6: color = c("glow", 0.45)
					"moon":
						if absf(ring-20.0)<0.6: color = c("glow", 0.5)
						elif ring<20.0 and absf(ring-12.0)<0.5: color = c("trim")
						# The phases: eight discs around the ring.
						for k in 8:
							var a := TAU*k/8.0
							if Vector2(x-cos(a)*20.0, z-sin(a)*20.0).length()<1.8: color = c("glow2", 0.3) if k % 2 else c("trim")
					"hive":
						if absf(noise.get_noise_2d(x*1.5, z*1.5))<0.04: color = c("glow2", 0.5)
					"storm":
						if x==0 or z==0 or absi(x)==absi(z):
							if ring>5.0 and ring<27.0: color = c("glow", 0.55)
						if absf(ring-26.0)<0.5: color = c("glow2", 0.4)
				if edge>WALL_OUT: color = c("dark")
				put(x, -1, z, color)

	func _gap(x: int, z: int) -> bool:
		return absf(x)<float(GATE_HALF[0] if z<0 else GATE_HALF[1])

	## The curtain wall: WALL_IN..WALL_OUT thick, crenels on top, gaps at the gates.
	func _walls() -> void:
		for x in range(-WALL_OUT, WALL_OUT+1):
			for z in range(-WALL_OUT, WALL_OUT+1):
				var edge := maxi(absi(x), absi(z))
				if edge<WALL_IN or edge>WALL_OUT: continue
				var on_gate_wall := absi(z)>=WALL_IN and absi(x)<WALL_IN
				if on_gate_wall and _gap(x, z): continue
				var tall := WALL_TALL
				if style=="hive": tall += int(noise.get_noise_2d(x*0.8, z*0.8)*3.0)
				if style=="moon" and noise.get_noise_2d(x*0.6, z*0.6)>0.35: tall -= 2  # crumbled
				for y in tall:
					var color := c("stone") if y>0 else c("dark")
					if posmod(y, 3)==0 and style!="hive": color = c("stone").darkened(0.12)
					color = color.lightened(noise.get_noise_3d(x*4.0, y*4.0, z*4.0)*0.07)
					color.a = 0.0
					if style=="hive" and noise.get_noise_3d(x*2.0, y*2.0, z*2.0)>0.42: color = c("glow2", 0.6)
					if style=="storm" and absf(noise.get_noise_3d(x*1.2, y*1.6, z*1.2))<0.03: color = c("glow", 0.7)
					put(x, y, z, color)
				# Crenels on the outer rim.
				if edge==WALL_OUT and posmod(x+z, 2)==0:
					put(x, tall, z, c("trim"))
		# Collision: four runs of wall, split around the gates.
		var t := float(WALL_OUT-WALL_IN+1)
		var mid := (WALL_IN+WALL_OUT)*0.5
		_solid(Vector3(-mid, WALL_TALL*0.5, 0), Vector3(t, WALL_TALL, WALL_OUT*2+1))
		_solid(Vector3(mid, WALL_TALL*0.5, 0), Vector3(t, WALL_TALL, WALL_OUT*2+1))
		for side in [-1, 1]:
			var half: float = GATE_HALF[0] if side<0 else GATE_HALF[1]
			var z: float = side*mid
			var run := WALL_IN-0.5-half
			_solid(Vector3(-half-run*0.5, WALL_TALL*0.5, z), Vector3(run, WALL_TALL, t))
			_solid(Vector3(half+run*0.5, WALL_TALL*0.5, z), Vector3(run, WALL_TALL, t))

	func _solid(at: Vector3, size: Vector3) -> void:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = at
		body.add_child(shape)

	## A tower (kind 0 corner, 1 gatehouse, 2 back gate), each world its own crown.
	func _tower(at: Vector2i, kind: int) -> void:
		var half := 4 if kind==0 else 3
		var tall := 14 if kind==0 else 12 if kind==1 else 10
		for y in tall:
			for x in range(-half, half+1):
				for z in range(-half, half+1):
					var round := style in ["moon", "hive"] and Vector2(x, z).length()>half+0.3
					if round: continue
					var shell := absi(x)==half or absi(z)==half or round or y==0
					if not shell and y<tall-1: continue
					var color := c("stone").lightened(noise.get_noise_3d((at.x+x)*4.0, y*4.0, (at.y+z)*4.0)*0.07)
					color.a = 0.0
					# Windows: glowing slits on the tower faces.
					if y>3 and posmod(y, 4)==1 and (x==0 or z==0) and (absi(x)==half or absi(z)==half): color = c("glow", 0.9)
					put(at.x+x, y, at.y+z, color)
		_solid(Vector3(at.x, tall*0.5, at.y), Vector3(half*2+1, tall, half*2+1))
		var top := tall
		match style:
			"rose":
				# A pink crystal spire on a white crown, roses round the rim.
				for x in range(-half, half+1):
					for z in range(-half, half+1):
						if (absi(x)==half or absi(z)==half) and posmod(x+z, 2)==0: put(at.x+x, top, at.y+z, c("trim"))
				for k in 7:
					var w := maxi(0, 2-k/3)
					for x in range(-w, w+1):
						for z in range(-w, w+1): put(at.x+x, top+k, at.y+z, c("glow", 0.7) if k>1 else c("trim"))
				for k in 8:
					var a := TAU*k/8.0
					put(at.x+roundi(cos(a)*(half+0.6)), top-2, at.y+roundi(sin(a)*(half+0.6)), c("glow", 0.8) if k % 2 else c("glow2", 0.5))
				lights.append([Vector3(at.x, top+5, at.y), c("glow"), 16.0, 1.2])
			"amber":
				# A stepped ziggurat cap with a honey lantern.
				for step in 4:
					var w := half-step
					for x in range(-w, w+1):
						for z in range(-w, w+1): put(at.x+x, top+step, at.y+z, Color(c("stone").darkened(0.06*step), 0.0))
				put(at.x, top+4, at.y, c("glow", 1.2))
				put(at.x, top+5, at.y, c("glow2", 1.0))
				lights.append([Vector3(at.x, top+5, at.y), c("glow"), 18.0, 1.3])
			"moon":
				# A cracked observatory dome with a ghost-light inside.
				for x in range(-half, half+1):
					for y in range(0, half+1):
						for z in range(-half, half+1):
							var d := Vector3(x, y*1.2, z).length()
							if d>half+0.4 or d<half-0.9: continue
							if noise.get_noise_3d((at.x+x)*1.5, y*1.5, (at.y+z)*1.5)>0.3: continue  # broken
							put(at.x+x, top+y, at.y+z, c("trim") if y % 2 else c("stone"))
				put(at.x, top+1, at.y, c("glow", 1.4))
				lights.append([Vector3(at.x, top+2, at.y), c("glow"), 16.0, 1.4])
			"hive":
				# A fungal cap: a stalk and a wide dome, glowing gills underneath.
				for y in 4: put(at.x, top+y, at.y, c("trim"))
				var cap := half+2
				for x in range(-cap, cap+1):
					for z in range(-cap, cap+1):
						var r := Vector2(x, z).length()
						if r>cap+0.3: continue
						var h := int((1.0-r/cap)*3.0)
						for y in h+1: put(at.x+x, top+4+y, at.y+z, c("stone").lightened(0.1) if y==h else c("dark"))
						if r>1.5: put(at.x+x, top+3, at.y+z, c("glow2", 0.7) if posmod(x*7+z*3, 3)==0 else c("glow", 0.6))
				lights.append([Vector3(at.x, top+2, at.y), c("glow"), 16.0, 1.3])
			"storm":
				# A tall obsidian spire with a crackling crystal at the tip.
				for k in 12:
					var w := maxi(0, 2-k/4)
					for x in range(-w, w+1):
						for z in range(-w, w+1): put(at.x+x, top+k, at.y+z, c("dark"))
				for k in 3: put(at.x, top+12+k, at.y, c("glow", 1.4))
				lights.append([Vector3(at.x, top+13, at.y), c("glow"), 20.0, 1.4])

	## Each world's touches along the walls and around the arena's rim.
	func _decor() -> void:
		for k in 16:
			var a := TAU*(k+0.5)/16.0
			var at := Vector2(cos(a), sin(a))*27.0
			var x := roundi(at.x)
			var z := roundi(at.y)
			if absi(x)<8 and z<0 or absi(x)<5 and z>0: continue  # keep the gate approaches clear
			match style:
				"rose":
					# Rose bushes: a green mound with glowing blooms.
					for dx in range(-1, 2):
						for dz in range(-1, 2):
							put(x+dx, 0, z+dz, Color("3f8a4a"))
							if (dx+dz) % 2==0: put(x+dx, 1, z+dz, c("glow", 0.9) if k % 2 else c("glow2", 0.6))
				"amber":
					# Lantern posts with honey lamps.
					for y in 4: put(x, y, z, c("dark"))
					put(x, 4, z, c("glow", 1.4))
					if k % 4==0: lights.append([Vector3(x, 5, z), c("glow"), 10.0, 0.9])
				"moon":
					# Ghost-light braziers on bone stands.
					for y in 2: put(x, y, z, c("trim"))
					for dx in range(-1, 2):
						for dz in range(-1, 2): put(x+dx, 2, z+dz, c("dark"))
					put(x, 3, z, c("glow", 1.6))
					if k % 4==0: lights.append([Vector3(x, 4, z), c("glow"), 10.0, 1.0])
				"hive":
					# Egg sacs, pulsing pink.
					for dx in range(-1, 2):
						for dz in range(-1, 2):
							for y in 2:
								if absi(dx)+absi(dz)+y<3: put(x+dx, y, z+dz, c("glow", 0.8))
					if k % 4==0: lights.append([Vector3(x, 2, z), c("glow"), 9.0, 0.8])
				"storm":
					# Storm crystals leaning out of the floor.
					for y in 5: put(x+(1 if y>2 else 0), y, z, c("glow", 1.0) if y>1 else c("dark"))
					if k % 4==0: lights.append([Vector3(x, 4, z), c("glow"), 10.0, 0.9])
		# Banners/glows over both gates.
		for z: int in [-WALL_OUT-1, WALL_OUT+1]:
			var half: int = int(GATE_HALF[0] if z<0 else GATE_HALF[1])+1
			for x in range(-half, half+1):
				put(x, WALL_TALL-1, z, c("trim"))
				put(x, WALL_TALL, z, c("trim") if posmod(x, 2) else c("glow", 0.9))

	## One mesh of the exposed faces (alpha = glow), shaded per face for the voxel look.
	func _mesh() -> void:
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
		for cell: Vector3i in cells:
			var color: Color = cells[cell]
			# Cell (x, y, z) is centred on x/z and spans y..y+1 (a hair above the terrace).
			var center := Vector3(cell.x, cell.y+0.5+0.06, cell.z)*VOX
			for d in dirs:
				if cells.has(cell+d): continue
				var n := Vector3(d)
				var u := Vector3(n.y, n.z, n.x)
				var v := n.cross(u)
				var face := center+n*VOX*0.5
				var h := VOX*0.5
				var tone := color
				if d.y<0: tone = Color(color.darkened(0.3), color.a)
				elif d.y==0: tone = Color(color.darkened(0.12 if d.x!=0 else 0.06), color.a)
				for corner: Vector3 in [face-u*h-v*h, face+u*h+v*h, face+u*h-v*h, face-u*h-v*h, face-u*h+v*h, face+u*h+v*h]:
					verts.append(corner)
					normals.append(n)
					colors.append(tone)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.name = "FortVoxels"
		node.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/voxel_glow.gdshader")
		node.material_override = material
		node.visibility_range_end = 1600.0
		root.add_child(node)
