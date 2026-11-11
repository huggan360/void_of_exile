class_name CityArt
## Vesperis's fairytale buildings, parks and lakes, as instanced parts in a
## CityPlanet.Batch (tower shader materials, see city_tower.gdshader): brown
## tree houses with pods and curling branches, crooked witch-hat towers,
## mushroom houses, onion-domed lantern towers, twisting spires, round
## cottages, and the tall lantern towers of the old skyline, rounded off.
## Each stands on a round footprint picked inside its block (pack()), so the
## streets decide where things go, not a grid.
##
## Parts are placed in a block's frame (the cell's tangent frame, metres);
## `solids` collects collision as [planet-space transform, size, "box"/"cyl"].
const PLASTER := ["303b46", "3b3549", "344449", "41404b", "39423e", "463a43"]
const ROOF := ["414b50", "4c5653", "665447", "55504a"]
const BARK := ["5a3a2a", "6b4630", "4a3024", "704a34", "5e4232"]
const LEAVES := ["3e6a46", "2f5a52", "54734b", "697456"]
const CAP := ["9a5f4e", "a07859", "79644d"]
const STONE := ["484c55", "514853", "3b4c51", "4b454d"]
const NEON := ["54d8d0", "c482ed", "efad64"]
const M_PLASTER := 0.0
const M_BARK := 0.1
const M_SHINGLE := 0.2
const M_LEAVES := 0.3
const M_STONE := 0.4
const M_WATER := 0.5
const M_PLANK := 0.6
const M_GRASS := 0.7
const M_CAP := 0.8
const M_GLOW := 1.0

var batch: CityPlanet.Batch
var frame: Transform3D
var solids: Array
var seed := 0.0
var _salt := 0

func _init(p_batch: CityPlanet.Batch, p_frame: Transform3D, p_solids: Array) -> void:
	batch = p_batch
	frame = p_frame
	solids = p_solids

func r() -> float:
	_salt += 1
	return CityLayout.rnd(seed, _salt)

func pick(list: Array) -> Color:
	return Color(str(list[int(r()*list.size()) % list.size()]))

## One part: `kind` mesh, local centre, rotation, size (m), colour, material,
## windows (0..1), round mapping, fine detail (only seen up close).
func part(kind: String, at: Vector3, basis: Basis, size: Vector3, color: Color, mat := M_PLASTER, windows := 0.0, round := true, detail := false) -> void:
	# Windows have their own geometry. Never paint a second window pattern on the wall.
	batch.add(kind, frame*Transform3D(basis*Basis.from_scale(Coplanar.grow(size)), at), color, Color(seed, 0.0, mat, 2.0 if round else 0.0), detail)
	if windows<=0.01 or size.y<2.5: return
	if kind=="box": _windows(at, basis, size, windows, detail)
	elif kind in ["cyl", "trunk", "sphere"]: _round_windows(kind, at, basis, size, windows, detail)
	if mat == M_PLASTER or mat == M_STONE:
		_neon_mark(kind, at, basis, size, detail)

## Raised, opaque neon strokes sit clear of the wall; no coplanar decals or
## extra point lights. Shared primitive batches keep these cheap to draw.
func _neon_mark(kind: String, at: Vector3, basis: Basis, size: Vector3, detail: bool) -> void:
	if size.x < 2.0 or size.y < 2.5: return
	var width := minf(1.25, size.x * 0.16)
	for facing: float in [0.0, PI]:
		var turn := Basis(Vector3.UP, facing)
		var wall := turn.z * (size.z * 0.5 + 0.12)
		wall.y = minf(size.y * 0.3, 3.0)
		if kind != "box":
			# Fit the sign to a cylinder facet, on both street-facing sides.
			var angle := facing + TAU * 0.25 / 14.0
			turn = Basis(Vector3.UP, angle)
			wall = Vector3(sin(angle) * size.x * 0.5, 0, cos(angle) * size.z * 0.5) + turn.z * 0.18
		neon_sign(at + basis * wall, basis * turn, width, detail)

func neon_sign(center: Vector3, pose: Basis, width := 1.25, detail := false) -> void:
	var ink := Color(NEON[absi(int(seed * 997.0)) % NEON.size()])
	for side: float in [-1.0, 1.0]:
		_window_piece("box", center + pose.x * side * width * 0.42, pose,
			Vector3(0.09, 0.65, 0.08), ink, M_GLOW, 0.0, false, detail)
	_window_piece("box", center + pose.y * 0.36, pose, Vector3(width, 0.09, 0.08), ink, M_GLOW, 0.0, false, detail)

## Frames are four separate rails; panes and mullions have disjoint faces.
## Nothing depends on growing overlapping boxes by fractions of a centimetre.
func _window(at: Vector3, rotation: Basis, width: float, height: float, lit: bool, detail: bool) -> void:
	var trim := Color("504b42")
	var rail := 0.14
	for side: float in [-1.0, 1.0]:
		_window_piece("box", at+rotation*Vector3(side*(width+rail)*0.5, 0, 0.28), rotation, Vector3(rail, height+rail*2.0, 0.24), trim, M_PLASTER, 0.0, false, detail)
		_window_piece("box", at+rotation*Vector3(0, side*(height+rail)*0.5, 0.28), rotation, Vector3(width, rail, 0.24), trim, M_PLASTER, 0.0, false, detail)
	# Split panes around the centre mullion, with an actual gap at each rail.
	for side: float in [-1.0, 1.0]:
		_window_piece("box", at+rotation*Vector3(side*(width+0.10)*0.25, 0, 0.22), rotation, Vector3((width-0.10)*0.5, height, 0.08), Color("c3aa7f") if lit else Color("354345"), M_GLOW if lit else M_PLASTER, 0.0, false, detail)
	_window_piece("box", at+rotation*Vector3(0, 0, 0.28), rotation, Vector3(0.10, height, 0.24), trim, M_PLASTER, 0.0, false, detail)
	_window_piece("box", at+rotation*Vector3(0, -height*0.5-rail-0.10, 0.25), rotation, Vector3(width+rail*3.0, 0.18, 0.65), Color("b6aa92"), M_STONE, 0.0, false, detail)

func _window_piece(kind: String, at: Vector3, basis: Basis, size: Vector3, color: Color, mat: float, _windows: float, _round: bool, detail: bool) -> void:
	batch.add(kind, frame*Transform3D(basis*Basis.from_scale(size), at), color, Color(seed, 0.0, mat, 0.0), detail)

func _windows(at: Vector3, basis: Basis, size: Vector3, density: float, detail: bool) -> void:
	var style := int(CityLayout.rnd(seed, 801)*3.0)
	var floor_height: float = [4.4, 5.2, 6.0][style]
	var rows := clampi(int(size.y/floor_height), 1, 20)
	var wh := minf(2.5, size.y/rows*0.52)
	for side in 4:
		var turn := Basis(Vector3.UP, side*PI*0.5)
		var width := size.x if side % 2==0 else size.z
		var depth := size.z if side % 2==0 else size.x
		if width<2.0: continue
		var cols := clampi(int(width/(3.6 if style!=2 else 5.2)), 1, 10)
		var ww := minf(width/cols*0.50, 2.4 if style!=1 else 1.4)
		for row in rows:
			for col in cols:
				var center := Vector3((col+0.5)*width/cols-width*0.5, (row+0.5)*size.y/rows-size.y*0.5, depth*0.5)
				_window(at+basis*turn*center, basis*turn, ww, wh, CityLayout.rnd(seed, 900+side*1000+row*cols+col)<density, detail)

## On curved walls, each frame follows the local outward normal. Sphere windows
## stay around the equator; cylinder frames sit outside their faceted wall.
func _round_windows(kind: String, at: Vector3, basis: Basis, size: Vector3, density: float, detail: bool) -> void:
	if minf(size.x, size.z)<2.0: return
	var rows := 1 if kind=="sphere" else clampi(int(size.y/5.0), 1, 16)
	var sides := 7
	for row in rows:
		var y := 0.0 if kind=="sphere" else (row+0.5)*size.y/rows-size.y*0.5
		var taper := lerpf(1.0, 0.64, (y/size.y+0.5)) if kind=="trunk" else 1.0
		for side in sides:
			var angle := TAU*(side*2+0.5)/14.0
			var point := Vector3(sin(angle)*size.x*0.5*taper, y, cos(angle)*size.z*0.5*taper)
			var normal := Vector3(sin(angle)/size.x, 0, cos(angle)/size.z).normalized()
			var turn := Basis(Vector3.UP, atan2(normal.x, normal.z))
			var width := minf(1.4, minf(size.x, size.z)*taper*0.23)
			_window(at+basis*point, basis*turn, width, minf(2.0, size.y/rows*0.5), CityLayout.rnd(seed, 1900+row*sides+side)<density, detail)

## One of the realm's voxel obstacles (obstacles/*.vox: trees, bushes, flowers,
## grass tufts...) standing on its base at `at`, turned by `yaw`.
func obstacle(prefab: String, at: Vector3, yaw: float, scale := 1.0, detail := false) -> void:
	var box := CityPlanet.mesh("vox:"+prefab).get_aabb()
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE*ObstacleLibrary.get_prefab(prefab).voxel_size*scale)
	var offset := -Vector3(box.position.x+box.size.x*0.5, box.position.y, box.position.z+box.size.z*0.5)
	batch.add("vox:"+prefab, frame*Transform3D(basis, at+basis*offset), Color.WHITE, Color(), detail)

func solid(at: Vector3, size: Vector3, kind := "cyl") -> void:
	solids.append([frame*Transform3D(Basis.IDENTITY, at), size, kind])

## Ground height at a local spot (the planet curves away from the frame).
static func ground(at: Vector2) -> float:
	return CityRoads.drop(at)

# --- Footprints --------------------------------------------------------------------------------

## Round footprints in a block, clear of the streets by `offset`, of each other
## and of `avoid` ([centre, half size, angle] boxes): the largest first, then
## a few more in what is left. [[centre, radius]].
static func pack(block: Dictionary, offset: float, block_seed: float, count: int, min_r: float, max_r: float, avoid: Array = [], taken: Array = []) -> Array:
	var out: Array = []
	var others := taken
	var seed_at: Vector2 = block.seed
	var corners: Array = block.corners
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for c: Vector2 in corners:
		lo = lo.min(c)
		hi = hi.max(c)
	var free := func(p: Vector2) -> float:
		var room := CityRoads.field(block, p)-offset
		for c: Array in out: room = minf(room, p.distance_to(c[0])-float(c[1])-1.2)
		for c: Array in others: room = minf(room, p.distance_to(c[0])-float(c[1])-1.0)
		for a: Array in avoid:
			var local := (p-(a[0] as Vector2)).rotated(-float(a[2]))
			var half: Vector2 = a[1]
			room = minf(room, (local.abs()-half).max(Vector2.ZERO).length()-0.8)
		return room
	for k in count:
		var best := Vector2.INF
		var best_r := min_r
		var tries := 18 if k>0 else 10
		for t in tries:
			var p: Vector2
			if k==0 and t==0: p = seed_at
			else: p = Vector2(lerpf(lo.x, hi.x, CityLayout.rnd(block_seed, k*50+t*2)), lerpf(lo.y, hi.y, CityLayout.rnd(block_seed, k*50+t*2+1)))
			var room: float = free.call(p)
			if room>best_r:
				best_r = room
				best = p
		if not best.is_finite(): break
		out.append([best, minf(best_r, max_r)])
	return out

# --- Buildings ---------------------------------------------------------------------------------

## A building on a round footprint (local centre, radius) about `tall` high.
## `style` "" picks one by the seed; `glow` is the district's neon.
func building(at: Vector2, radius: float, tall: float, p_seed: float, style := "", glow := Color("ff6eb4"), lift := 0.0) -> void:
	seed = p_seed
	_salt = 0
	if style=="":
		var roll := r()
		if radius<5.0: style = ["mushroom", "cottage", "cottage", "teapot", "lighthouse"][int(roll*5.0) % 5]
		elif tall<34.0: style = ["mushroom", "cottage_ring", "tree", "crooked", "teapot", "stack", "stack"][int(roll*7.0) % 7]
		elif roll<0.22: style = "tree"
		elif roll<0.4: style = "crooked"
		elif roll<0.5: style = "onion"
		elif roll<0.58: style = "twist"
		elif roll<0.7: style = "stack"
		elif roll<0.78: style = "lighthouse"
		elif roll<0.86: style = "mushroom_tower"
		else: style = "lantern"
	var base := Vector3(at.x, ground(at)-0.4+lift, at.y)
	match style:
		"tree": _tree_house(base, radius, tall)
		"crooked": _crooked(base, radius, tall)
		"onion": _onion(base, radius, tall, glow)
		"twist": _twist(base, radius, tall, glow)
		"mushroom": _mushroom(base, radius, minf(tall, 22.0))
		"mushroom_tower": _mushroom(base, radius, tall)
		"cottage": _cottage(base, radius)
		"teapot": _teapot(base, radius)
		"stack": _stack(base, radius, tall)
		"lighthouse": _lighthouse(base, radius, tall, glow)
		"cottage_ring":
			_cottage(base, radius*0.55)
			for k in 3:
				var a := TAU*k/3.0+r()
				var p := at+Vector2(cos(a), sin(a))*radius*0.62
				_cottage(Vector3(p.x, ground(p)-0.4, p.y), radius*0.36)
		_: _lantern(base, radius, tall, glow)

## A great brown tree with rooms in it: a fat trunk on flaring roots, round
## pods with windows and pointed caps, curling branches and a leafy crown.
func _tree_house(base: Vector3, radius: float, tall: float) -> void:
	var bark := pick(BARK)
	var leaf := pick(LEAVES)
	var trunk := radius*1.05
	var height := tall*0.78
	part("trunk", base+Vector3.UP*height*0.5, Basis.IDENTITY, Vector3(trunk, height, trunk), bark, M_BARK, 0.35)
	solid(base+Vector3.UP*height*0.5, Vector3(trunk*0.8, height, trunk*0.8))
	for k in 5:
		var a := TAU*k/5.0+r()
		var out := Vector3(cos(a), 0, sin(a))
		part("sphere", base+out*trunk*0.42+Vector3.UP*0.6, Basis(Vector3.UP, -a), Vector3(trunk*0.5, trunk*0.32, trunk*0.3), bark.darkened(0.08), M_BARK, 0.0, true, true)
	# Pods with windows and caps, round the trunk at different heights.
	var pods := 2+int(r()*3.0)
	var walls := pick(PLASTER)
	var roof := pick(ROOF)
	for k in pods:
		var a := TAU*(k+r()*0.5)/pods
		var h := height*lerpf(0.3, 0.85, float(k)/maxf(1, pods-1))
		var size := radius*lerpf(0.42, 0.62, r())
		var at := base+Vector3(cos(a), 0, sin(a))*trunk*0.5+Vector3.UP*h
		part("sphere", at, Basis.IDENTITY, Vector3(size*2.0, size*1.6, size*2.0), walls if r()<0.6 else bark.lightened(0.2), M_PLANK if r()<0.5 else M_PLASTER, 0.5)
		part("cone", at+Vector3.UP*size*1.3, Basis(Vector3.FORWARD, (r()-0.5)*0.3), Vector3(size*2.2, size*1.4, size*2.2), roof, M_SHINGLE)
		part("sphere", at+Vector3.UP*size*2.05, Basis.IDENTITY, Vector3.ONE*0.5, Color(str(NEON[k % NEON.size()])), M_GLOW, 0.0, true, true)
	# Curling branches: rings stood on end, each ending in a tuft of leaves.
	for k in 2+int(r()*2.0):
		var a := TAU*r()
		var out := Vector3(cos(a), 0, sin(a))
		var size := radius*lerpf(0.5, 0.8, r())
		var at := base+out*(trunk*0.5+size*0.7)+Vector3.UP*height*lerpf(0.55, 0.9, r())
		var stood := Basis(Vector3.UP, -a+PI*0.5)*Basis(Vector3.RIGHT, PI*0.5)
		part("torus", at, stood, Vector3(size, size*0.5, size), bark, M_BARK, 0.0, true, true)
		part("sphere", at+out*size*0.55+Vector3.UP*size*0.45, Basis.IDENTITY, Vector3.ONE*size*0.75, leaf, M_LEAVES, 0.0, true, true)
	# The crown: a cluster of leafy balls.
	var crown := base+Vector3.UP*height
	for k in 4+int(r()*3.0):
		var a := TAU*r()
		var off := Vector3(cos(a), 0, sin(a))*radius*lerpf(0.2, 0.8, r())+Vector3.UP*radius*lerpf(0.0, 0.9, r())
		var size := radius*lerpf(0.9, 1.5, r())
		part("sphere", crown+off, Basis.IDENTITY, Vector3(size, size*0.85, size), leaf.lerp(leaf.lightened(0.2), r()), M_LEAVES)
	part("sphere", crown+Vector3.UP*radius*0.7, Basis.IDENTITY, Vector3.ONE*radius*1.8, leaf, M_LEAVES)

## A crooked tower: round storeys each a little off the last, timber bands, a
## witch's hat whose tip curls over, a glowing finial.
func _crooked(base: Vector3, radius: float, tall: float) -> void:
	var walls := pick(PLASTER)
	var stone := pick(STONE)
	var roof := pick(ROOF)
	var levels := 3+int(r()*3.0)
	var lean := Vector2.from_angle(r()*TAU)
	var y := 0.0
	var off := Vector2.ZERO
	var size := radius*2.0
	var body := tall*0.72
	for k in levels:
		var h := body/levels
		var at := base+Vector3(off.x, y+h*0.5, off.y)
		var tilt := Basis(Vector3(lean.y, 0, -lean.x), (r()-0.5)*0.08)
		part("cyl", at, tilt, Vector3(size, h, size), stone if k==0 else walls.darkened(k*0.04), M_STONE if k==0 else M_PLASTER, 0.0 if k==0 else 0.55)
		solid(at, Vector3(size*0.92, h, size*0.92))
		part("cyl", at+Vector3.UP*h*0.5, Basis.IDENTITY, Vector3(size*1.06, 0.6, size*1.06), pick(BARK), M_PLANK, 0.0, true, true)
		y += h
		off += lean*radius*lerpf(0.08, 0.18, r())
		size *= lerpf(0.84, 0.95, r())
	var top := base+Vector3(off.x, y, off.y)
	var hat := tall*0.28
	part("cone", top+Vector3.UP*hat*0.35, Basis.IDENTITY, Vector3(size*1.25, hat*0.7, size*1.25), roof, M_SHINGLE)
	# The tip bends over in three steps.
	var tip := top+Vector3.UP*hat*0.7
	var bend := 0.0
	var w := size*0.5
	for k in 3:
		bend += 0.35
		var dir := Vector3(lean.x, 0, lean.y)
		var basis := Basis(Vector3(lean.y, 0, -lean.x).normalized(), bend)
		part("cone", tip+basis.y*hat*0.08, basis, Vector3(w, hat*0.2, w), roof, M_SHINGLE)
		tip += basis.y*hat*0.15+dir*0.0
		w *= 0.65
	part("sphere", tip, Basis.IDENTITY, Vector3.ONE*0.9, Color(str(NEON[int(r()*NEON.size()) % NEON.size()])), M_GLOW)
	if r()<0.6:
		part("torus", base+Vector3.UP*body*0.55, Basis.IDENTITY, Vector3(radius*2.6, 0.8, radius*2.6), pick(BARK), M_PLANK, 0.0, true, true)

## An onion-domed lantern tower: storeys with windows and neon balconies.
func _onion(base: Vector3, radius: float, tall: float, glow: Color) -> void:
	var walls := pick(PLASTER)
	var roof := pick(ROOF)
	var body := tall*0.75
	part("cyl", base+Vector3.UP*body*0.5, Basis.IDENTITY, Vector3(radius*2.0, body, radius*2.0), walls, M_PLASTER, 0.6)
	solid(base+Vector3.UP*body*0.5, Vector3(radius*1.9, body, radius*1.9))
	for k in 3:
		var h := body*(0.3+k*0.25)
		part("torus", base+Vector3.UP*h, Basis.IDENTITY, Vector3(radius*2.5, 0.6, radius*2.5), glow if k==1 else pick(STONE), M_GLOW if k==1 else M_STONE, 0.0, true, k!=1)
	var dome := base+Vector3.UP*(body+radius*0.9)
	part("sphere", dome, Basis.IDENTITY, Vector3(radius*2.4, radius*2.6, radius*2.4), roof, M_SHINGLE)
	part("cone", dome+Vector3.UP*radius*1.9, Basis.IDENTITY, Vector3(radius*0.6, radius*1.6, radius*0.6), roof.lightened(0.15), M_SHINGLE)
	part("sphere", dome+Vector3.UP*radius*2.8, Basis.IDENTITY, Vector3.ONE*1.2, glow, M_GLOW)
	for k in 2:
		var a := TAU*r()
		var at := base+Vector3(cos(a), 0, sin(a))*radius*0.95+Vector3.UP*body*lerpf(0.3, 0.7, r())
		part("sphere", at, Basis.IDENTITY, Vector3(radius*0.9, radius*0.9, radius*0.9), walls.lightened(0.08), M_PLASTER, 0.5, true, true)
		part("cone", at+Vector3.UP*radius*0.75, Basis.IDENTITY, Vector3(radius*1.0, radius*0.8, radius*1.0), roof, M_SHINGLE, 0.0, true, true)

## A spire of storeys each turned a little more than the one below.
func _twist(base: Vector3, radius: float, tall: float, glow: Color) -> void:
	var walls := pick(PLASTER)
	var levels := 7+int(r()*6.0)
	var h := tall/levels
	var size := radius*1.5
	var turn := lerpf(0.12, 0.3, r())*(1.0 if r()<0.5 else -1.0)
	for k in levels:
		var at := base+Vector3.UP*(k*h+h*0.5)
		part("box", at, Basis(Vector3.UP, k*turn), Vector3(size, h*0.92, size), walls.darkened(k*0.02), M_PLASTER, 0.55, false)
		part("box", at+Vector3.UP*h*0.48, Basis(Vector3.UP, k*turn), Vector3(size*1.08, 0.3, size*1.08), glow if k % 3==2 else pick(STONE), M_GLOW if k % 3==2 else M_STONE, 0.0, false, true)
		if k<2: solid(at, Vector3(size, h, size), "box")
		size *= 0.94
	part("cone", base+Vector3.UP*(tall+radius*0.8), Basis.IDENTITY, Vector3(size*1.1, radius*2.0, size*1.1), pick(ROOF), M_SHINGLE)

## A mushroom house: a fat stem with windows under a spotted cap.
func _mushroom(base: Vector3, radius: float, p_tall: float) -> void:
	var cap_h := minf(p_tall*0.42, radius*1.6)
	var tall := p_tall
	var stem := radius*1.2
	var height := tall-cap_h*0.75
	part("cyl", base+Vector3.UP*height*0.5, Basis.IDENTITY, Vector3(stem, height, stem), pick(PLASTER), M_PLASTER, 0.45)
	solid(base+Vector3.UP*height*0.5, Vector3(stem*0.95, height, stem*0.95))
	var cap := pick(CAP)
	var top := base+Vector3.UP*height
	part("dome", top-Vector3.UP*0.6, Basis.IDENTITY, Vector3(radius*2.6, cap_h, radius*2.6), cap, M_CAP)
	part("cyl", top-Vector3.UP*0.5, Basis.IDENTITY, Vector3(radius*2.5, 0.5, radius*2.5), Color("e8d8c0"), M_PLASTER, 0.0, true, true)
	for k in 7:
		var a := TAU*r()
		var u := lerpf(0.15, 0.8, r())
		var at := top+Vector3(cos(a)*radius*1.3*u, cap_h*sqrt(1.0-u*u)*0.95-0.6, sin(a)*radius*1.3*u)
		part("sphere", at, Basis.IDENTITY, Vector3(radius*0.35, radius*0.12, radius*0.35), Color("f4ece0"), M_PLASTER, 0.0, true, true)
	part("box", base+Vector3(0, 1.4, -stem*0.5), Basis.IDENTITY, Vector3(1.4, 2.6, 0.5), pick(BARK), M_PLANK, 0.0, false, true)

## A small round cottage with a pointed or domed roof and a chimney.
func _cottage(base: Vector3, radius: float) -> void:
	var walls := pick(PLASTER)
	var roof := pick(ROOF)
	var h := lerpf(3.5, 6.0, r())
	part("cyl", base+Vector3.UP*h*0.5, Basis.IDENTITY, Vector3(radius*2.0, h, radius*2.0), walls, M_PLASTER if r()<0.6 else M_STONE, 0.4)
	solid(base+Vector3.UP*h*0.5, Vector3(radius*2.0, h, radius*2.0))
	if r()<0.65:
		part("cone", base+Vector3.UP*(h+radius*0.7), Basis.IDENTITY, Vector3(radius*2.5, radius*1.6, radius*2.5), roof, M_SHINGLE)
	else:
		part("dome", base+Vector3.UP*h, Basis.IDENTITY, Vector3(radius*2.3, radius*1.3, radius*2.3), roof, M_SHINGLE)
	part("box", base+Vector3(radius*0.45, h+radius*0.9, 0), Basis.IDENTITY, Vector3(0.7, radius*1.2, 0.7), pick(STONE), M_STONE, 0.0, false, true)

## The Lantern City's own skyscraper, rounded: setbacks of round storeys with
## brass trims and a dome, spire or neon rings on top.
func _lantern(base: Vector3, radius: float, tall: float, glow: Color) -> void:
	var walls := pick(PLASTER).darkened(0.25)
	var levels := 1+int(r()*3.0)
	var y := 0.0
	var size := radius*2.0
	for level in levels:
		var h := tall*(0.62 if level==0 and levels>1 else 0.38/maxf(1, levels-1)) if levels>1 else tall
		var at := base+Vector3.UP*(y+h*0.5)
		part("cyl", at, Basis.IDENTITY, Vector3(size, h, size), walls.lightened(level*0.06), M_PLASTER)
		_neon_mark("cyl", at, Basis.IDENTITY, Vector3(size, h, size), false)
		solid(at, Vector3(size*0.95, h, size*0.95))
		part("torus", base+Vector3.UP*(y+h), Basis.IDENTITY, Vector3(size*1.04, 0.5, size*1.04), glow, M_GLOW, 0.0, true, true)
		y += h
		size *= lerpf(0.6, 0.8, r())
	var top := base+Vector3.UP*y
	var crown := r()
	if crown<0.4:
		part("dome", top, Basis.IDENTITY, Vector3(size, size*0.9, size), walls.lightened(0.25), M_SHINGLE)
		part("cyl", top+Vector3.UP*(size*0.45+3.0), Basis.IDENTITY, Vector3(0.4, 6.0, 0.4), Color("d9ac60"), M_PLASTER)
		part("sphere", top+Vector3.UP*(size*0.45+6.0), Basis.IDENTITY, Vector3.ONE*1.4, glow, M_GLOW)
	elif crown<0.75:
		part("cone", top+Vector3.UP*tall*0.11, Basis.IDENTITY, Vector3(size*0.7, tall*0.22, size*0.7), walls.lightened(0.15), M_SHINGLE)
		part("sphere", top+Vector3.UP*tall*0.22, Basis.IDENTITY, Vector3.ONE*0.9, glow, M_GLOW)
	else:
		for k in 3:
			part("torus", top+Vector3.UP*(1.5+k*2.4), Basis.IDENTITY, Vector3(size*(1.1-k*0.25), 0.6, size*(1.1-k*0.25)), glow, M_GLOW)

## A teapot house: a round belly, a spout, a handle, a lid with a knob.
func _teapot(base: Vector3, radius: float) -> void:
	var body := pick(PLASTER).lightened(0.05)
	var size := radius*2.0
	part("sphere", base+Vector3.UP*size*0.42, Basis.IDENTITY, Vector3(size, size*0.85, size), body, M_PLASTER, 0.45)
	solid(base+Vector3.UP*size*0.4, Vector3(size*0.9, size*0.8, size*0.9))
	var a := r()*TAU
	var out := Vector3(cos(a), 0, sin(a))
	part("cyl", base+out*size*0.55+Vector3.UP*size*0.55, Basis(out.cross(Vector3.UP).normalized(), -0.8), Vector3(size*0.16, size*0.55, size*0.16), body.darkened(0.1), M_PLASTER, 0.0, true, true)
	part("torus", base-out*size*0.5+Vector3.UP*size*0.45, Basis(Vector3.UP, -a)*Basis(Vector3.RIGHT, PI*0.5), Vector3(size*0.4, size*0.3, size*0.4), body.darkened(0.1), M_PLASTER, 0.0, true, true)
	part("dome", base+Vector3.UP*size*0.8, Basis.IDENTITY, Vector3(size*0.6, size*0.25, size*0.6), pick(ROOF), M_SHINGLE)
	part("sphere", base+Vector3.UP*size*0.98, Basis.IDENTITY, Vector3.ONE*size*0.12, Color("d9ac60"), M_PLASTER)

## Round houses piled up like stones, each a little off and turned, with
## little roofs peeking out and a pointed hat on top.
func _stack(base: Vector3, radius: float, tall: float) -> void:
	var y := 0.0
	var off := Vector2.ZERO
	var size := radius*2.0
	var levels := clampi(int(tall/7.0), 2, 7)
	var h := tall/levels
	for k in levels:
		var at := base+Vector3(off.x, y+h*0.5, off.y)
		var walls := pick(PLASTER)
		part("cyl" if r()<0.7 else "box", at, Basis(Vector3.UP, r()*TAU), Vector3(size, h, size), walls, M_PLASTER if r()<0.6 else M_PLANK, 0.5)
		if k==0: solid(at, Vector3(size, h, size))
		part("cyl", at+Vector3.UP*h*0.5, Basis.IDENTITY, Vector3(size*1.12, 0.45, size*1.12), pick(BARK), M_PLANK, 0.0, true, true)
		if r()<0.5:
			var a := r()*TAU
			part("cone", at+Vector3(cos(a)*size*0.45, h*0.5+0.9, sin(a)*size*0.45), Basis.IDENTITY, Vector3(size*0.35, 1.8, size*0.35), pick(ROOF), M_SHINGLE, 0.0, true, true)
		y += h
		var step := Vector2.from_angle(r()*TAU)*radius*lerpf(0.1, 0.25, r())
		off += step
		size *= lerpf(0.82, 0.98, r())
	part("cone", base+Vector3(off.x, y+size*0.6, off.y), Basis.IDENTITY, Vector3(size*1.2, size*1.2, size*1.2), pick(ROOF), M_SHINGLE)

## A lighthouse: a striped round tower, a lamp room and a dome.
func _lighthouse(base: Vector3, radius: float, tall: float, glow: Color) -> void:
	var a := pick(PLASTER).lightened(0.15)
	var b := pick(ROOF)
	var bands := clampi(int(tall/5.0), 4, 14)
	var h := tall*0.85/bands
	var size := radius*1.6
	for k in bands:
		var w := size*(1.0-k*0.03)
		part("cyl", base+Vector3.UP*(k*h+h*0.5), Basis.IDENTITY, Vector3(w, h, w), a if k % 2==0 else b, M_PLASTER, 0.25 if k % 2==0 else 0.0)
	solid(base+Vector3.UP*tall*0.4, Vector3(size, tall*0.8, size))
	var top := base+Vector3.UP*tall*0.85
	part("cyl", top+Vector3.UP*1.2, Basis.IDENTITY, Vector3(size*0.8, 2.4, size*0.8), glow, M_GLOW)
	part("torus", top+Vector3.UP*0.2, Basis.IDENTITY, Vector3(size*1.25, 0.6, size*1.25), pick(STONE), M_STONE, 0.0, true, true)
	part("dome", top+Vector3.UP*2.4, Basis.IDENTITY, Vector3(size*0.95, size*0.7, size*0.95), b, M_SHINGLE)

## Small gardens in what the houses leave: a lawn with a tree, a flower bed,
## a hedge ring, a well or a statue.
func gardens(block: Dictionary, offset: float, p_seed: float, taken: Array) -> void:
	var spots := pack(block, offset, p_seed+0.37, 7, 1.6, 4.5, [], taken)
	for k in spots.size():
		seed = p_seed+k*0.071
		_salt = 0
		var at: Vector2 = spots[k][0]
		var rr := float(spots[k][1])
		var y := ground(at)
		part("cyl", Vector3(at.x, y+0.05, at.y), Basis.IDENTITY, Vector3(rr*2.0, 0.25, rr*2.0), Color("3a6a42"), M_GRASS, 0.0, true, true)
		match int(r()*5.0) % 5:
			0, 1: tree(at, lerpf(1.6, minf(rr, 3.4), r()), seed+0.11)
			2:
				# A flower bed: voxel flowers and tufts round a bush.
				obstacle("bush", Vector3(at.x, y+0.15, at.y), r()*TAU, 0.8)
				for b in 7:
					var p := at+Vector2.from_angle(TAU*b/7.0+r())*rr*lerpf(0.45, 0.8, r())
					obstacle("decor_flowers" if b % 3!=2 else "decor_tuft", Vector3(p.x, ground(p)+0.35, p.y), r()*TAU, 1.0, true)
			3:
				# A ring of hedge bushes.
				for b in 6:
					var p := at+Vector2.from_angle(TAU*b/6.0)*rr*0.7
					obstacle("bush", Vector3(p.x, ground(p)+0.15, p.y), r()*TAU, lerpf(0.7, 0.95, r()))
				obstacle("decor_fern", Vector3(at.x, y+0.15, at.y), r()*TAU, 1.2, true)
			_:
				part("cyl", Vector3(at.x, y+0.6, at.y), Basis.IDENTITY, Vector3(1.6, 1.2, 1.6), pick(STONE), M_STONE)
				if r()<0.5:
					part("dome", Vector3(at.x, y+2.2, at.y), Basis.IDENTITY, Vector3(2.2, 1.0, 2.2), pick(ROOF), M_SHINGLE, 0.0, true, true)
					for s in 2: part("cyl", Vector3(at.x+(s*2-1)*0.9, y+1.6, at.y), Basis.IDENTITY, Vector3(0.18, 2.0, 0.18), Color("6b4630"), M_PLANK, 0.0, true, true)
				else:
					part("sphere", Vector3(at.x, y+1.9, at.y), Basis.IDENTITY, Vector3(0.9, 1.6, 0.9), Color("b8b0c0"), M_STONE)
					part("sphere", Vector3(at.x, y+2.9, at.y), Basis.IDENTITY, Vector3.ONE*0.7, Color("b8b0c0"), M_STONE)

# --- Green ---------------------------------------------------------------------------------------

## A tree: one of the realm's voxel trees, `size` about its crown's width
## (parks, gardens, roundabouts, farms and roadsides), with a few tufts at its foot.
func tree(at: Vector2, size: float, p_seed: float) -> void:
	seed = p_seed
	_salt = 0
	var base := Vector3(at.x, ground(at)-0.05, at.y)
	var kind: String = ["tree_round", "tree_small", "tree_tall", "tree_round", "pine"][int(r()*5.0) % 5]
	var scale := clampf(size/3.0, 0.6, 1.5)
	obstacle(kind, base, r()*TAU, scale)
	solid(base+Vector3.UP*1.5, Vector3(0.6*scale, 3.0, 0.6*scale))
	for k in 2:
		var p := at+Vector2.from_angle(r()*TAU)*size*lerpf(0.4, 0.8, r())
		obstacle("decor_tuft", Vector3(p.x, ground(p), p.y), r()*TAU, 1.0, true)

## A park on a block: a lawn (the lot's largest circle and a few more),
## trees, a gazebo and maybe a pond. `lot` is how far from the streets.
func park(block: Dictionary, lot: float, p_seed: float, pond: bool) -> Array:
	seed = p_seed
	_salt = 0
	var lawns := pack(block, lot, p_seed, 4, 5.0, 40.0)
	for c: Array in lawns:
		var at: Vector2 = c[0]
		var rr := float(c[1])*0.96
		part("cyl", Vector3(at.x, ground(at)+0.06, at.y), Basis.IDENTITY, Vector3(rr*2.0, 0.3, rr*2.0), Color("3a6a42"), M_GRASS)
	var spots: Array = []
	if pond and not lawns.is_empty():
		var c: Array = lawns[0]
		spots.append(lake_pool(c[0], float(c[1])*0.6))
	var trees := 0
	for k in 40:
		if trees>=10: break
		var at := (block.seed as Vector2)+Vector2.from_angle(r()*TAU)*r()*30.0
		var room := CityRoads.field(block, at)-lot-1.0
		var clear := true
		for s: Array in spots:
			if at.distance_to(s[0])<float(s[1])+2.5: clear = false
		if room<1.5 or not clear: continue
		tree(at, lerpf(2.2, 4.2, CityLayout.rnd(p_seed, 900+k)), p_seed+k*0.017)
		seed = p_seed
		trees += 1
	if lawns.size()>1 and not pond:
		_gazebo(lawns[1][0], minf(float(lawns[1][1]), 4.5))
	return lawns

## A round pool with a stone rim: [centre, radius].
func lake_pool(at: Vector2, radius: float) -> Array:
	var y := ground(at)
	part("cyl", Vector3(at.x, y+0.1, at.y), Basis.IDENTITY, Vector3(radius*2.0+1.2, 0.5, radius*2.0+1.2), pick(STONE), M_STONE)
	part("cyl", Vector3(at.x, y+0.2, at.y), Basis.IDENTITY, Vector3(radius*2.0, 0.5, radius*2.0), Color("2a6a8a"), M_WATER)
	return [at, radius]

## A lake filling a block: water, a pebble shore, a little island with a tree,
## a jetty and trees round about.
func lake(block: Dictionary, lot: float, p_seed: float) -> Array:
	seed = p_seed
	_salt = 0
	var pools := pack(block, lot+1.5, p_seed, 3, 6.0, 60.0)
	for k in pools.size():
		var c: Array = pools[k]
		var at: Vector2 = c[0]
		var rr := float(c[1])+1.5
		var y := ground(at)
		part("cyl", Vector3(at.x, y+0.03, at.y), Basis.IDENTITY, Vector3(rr*2.0+5.0, 0.3, rr*2.0+5.0), Color("3a6a42"), M_GRASS)
		part("cyl", Vector3(at.x, y+0.08, at.y), Basis.IDENTITY, Vector3(rr*2.0+1.6, 0.35, rr*2.0+1.6), Color("8a7a6a"), M_STONE)
		part("cyl", Vector3(at.x, y+0.12, at.y), Basis.IDENTITY, Vector3(rr*2.0, 0.35, rr*2.0), Color("23607e"), M_WATER)
		if k==0 and rr>9.0:
			var isle := at+Vector2.from_angle(r()*TAU)*rr*0.35
			part("dome", Vector3(isle.x, y, isle.y), Basis.IDENTITY, Vector3(5.0, 1.4, 5.0), Color("4a7a4a"), M_GRASS)
			tree(isle, 2.6, p_seed+0.5)
			seed = p_seed
			var a := r()*TAU
			var edge := at+Vector2.from_angle(a)*(rr-2.0)
			part("box", Vector3(edge.x, y+0.5, edge.y), Basis(Vector3.UP, -a+PI*0.5), Vector3(1.6, 0.2, 6.0), Color("8a5a3a"), M_PLANK, 0.0, false)
	for k in 30:
		var at := (block.seed as Vector2)+Vector2.from_angle(r()*TAU)*r()*32.0
		var room := CityRoads.field(block, at)-lot-1.0
		var clear := room>1.2
		for c: Array in pools:
			if at.distance_to(c[0])<float(c[1])+4.5: clear = false
		if clear: tree(at, lerpf(2.0, 3.6, CityLayout.rnd(p_seed, 800+k)), p_seed+k*0.023)
		seed = p_seed
	return pools

## An open pavilion: posts and a dome.
func _gazebo(at: Vector2, radius: float) -> void:
	var base := Vector3(at.x, ground(at), at.y)
	part("cyl", base+Vector3.UP*0.15, Basis.IDENTITY, Vector3(radius*2.0, 0.3, radius*2.0), pick(STONE), M_STONE)
	for k in 6:
		var a := TAU*k/6.0
		part("cyl", base+Vector3(cos(a)*radius*0.85, 1.6, sin(a)*radius*0.85), Basis.IDENTITY, Vector3(0.35, 3.0, 0.35), Color("e8dcc8"), M_PLASTER, 0.0, true, true)
	part("dome", base+Vector3.UP*3.0, Basis.IDENTITY, Vector3(radius*2.2, radius*1.1, radius*2.2), pick(ROOF), M_SHINGLE)
