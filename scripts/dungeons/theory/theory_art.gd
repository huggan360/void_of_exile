class_name TheoryArt
extends RefCounted
## Low resolution fairytale timber, brass and crystal sculpture. Data only: planned on the
## loading worker, published as spatial batches and simple collision boxes.
# Legacy palette names are shared with detail renderers; their finishes are timber and brass.
const STEEL := Color("70432c")
const DARK := Color("21191d")
const WHITE := Color("bd854e")
const TRIM := Color("c59950")
const CYAN := Color("89ef9b")
const GOLD := Color("ffcc61")
const PINK := Color("ee96be")
const AMBER := Color("ffd18a")
const RESIN := Color("100e19")
const BLOOD := Color("651526")
var modules: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var sparks: Array[Vector3] = []
var spark_jets: Array[Dictionary] = []
var fires: Array[Dictionary] = []
var cables: Array[Dictionary] = []
var curtains: Array[Dictionary] = []
var signs: Array[Dictionary] = []
var turrets: Array[Transform3D] = []
var vents: Array[Transform3D] = []
var server_only := false
var _part := {}
var _rng := RandomNumberGenerator.new()
var _ship_mode := false
var _wreck_mode := false
var _impact_enabled := true
var _detail_seed := 0

func build(layout: TheoryLayout) -> void:
	_rng.seed = layout.seed_value+71867
	_detail_seed = layout.seed_value+91703
	_ship(false)
	_ship(true)
	for path_index in layout.paths.size(): _ribbon(layout,path_index)
	# Keep the former lock platform, without a puzzle or a blocking door.
	_transit_platform()
	_arena()
	if not server_only: _space()
	_finish()

func _begin(id: String,frame: Transform3D,far := 190.0,sky := false) -> void:
	_finish()
	_part = {id=id,frame=frame,far=far,sky=sky,points=[],colors=[],glow=[],reacts=[],collision=[],bounds=AABB()}

func _finish() -> void:
	if _part.is_empty(): return
	var points: Array = _part.points
	if points.is_empty() and not _part.has("vertices") and _part.collision.is_empty() and not _part.has("glass"):
		_part = {}
		return
	var data := PackedFloat32Array()
	data.resize(points.size()*20)
	for i in points.size():
		var t: Transform3D = points[i]
		var c: Color = _part.colors[i]
		var o := i*20
		data[o] = t.basis.x.x
		data[o+1] = t.basis.y.x
		data[o+2] = t.basis.z.x
		data[o+3] = t.origin.x
		data[o+4] = t.basis.x.y
		data[o+5] = t.basis.y.y
		data[o+6] = t.basis.z.y
		data[o+7] = t.origin.y
		data[o+8] = t.basis.x.z
		data[o+9] = t.basis.y.z
		data[o+10] = t.basis.z.z
		data[o+11] = t.origin.z
		data[o+12] = c.r
		data[o+13] = c.g
		data[o+14] = c.b
		data[o+15] = c.a
		data[o+16] = _part.glow[i]
		data[o+17] = fposmod(sin(t.origin.dot(Vector3(12.98,78.23,35.71))+i*2.2)*43758.54,1.0)
		data[o+18] = _part.reacts[i]
		data[o+19] = 1.0 if _part.get("unstable",false) and (t.origin.y>3.5 or absf(t.origin.x)>7.0) else 0.0
	_part.data = data
	_part.erase("points")
	_part.erase("colors")
	_part.erase("glow")
	_part.erase("reacts")
	modules.append(_part)
	_part = {}

func _box(at: Vector3,size: Vector3,color: Color,glow := 0.0,solid := false) -> void:
	if server_only:
		if solid:
			_part.collision.append({at=at,size=size})
			_part.bounds = (_part.bounds as AABB).merge(AABB(at-size*0.5,size))
		return
	_part.points.append(Transform3D(Basis.from_scale(size),at))
	_part.colors.append(_patina(color))
	_part.glow.append(glow*(0.32 if _wreck_mode else 1.0))
	_part.reacts.append(1.0 if _impact_enabled else 0.0)
	var bounds := AABB(at-size*0.5,size)
	_part.bounds = bounds if _part.points.size()==1 else (_part.bounds as AABB).merge(bounds)
	if solid: _part.collision.append({at=at,size=size})

## Warm colours identify timber/brass; green and pink remain magical minerals.
## No extra custom-data channel is needed by the shared 20-float voxel layout.
func _patina(color: Color) -> Color:
	if not _wreck_mode: return color
	if color.g>color.r*1.08: return color.darkened(0.46).lerp(Color("52654b"),0.18)
	if color.b>color.g*1.08: return color.darkened(0.58)
	return color.darkened(0.54).lerp(Color("25251f"),0.18)

## Coordinate-only cosmetic variation, independent of structural RNG.
func _detail_hash(at: Vector3,salt := 0.0) -> float:
	return fposmod(sin(at.dot(Vector3(17.13,39.71,11.37))+float(_detail_seed)*0.013+salt*71.9)*43758.5453,1.0)

## Faceted growths and lanterns are decorative and never add collision or lights.
func _crystal(at: Vector3,height: float,color: Color,glow := 0.8) -> void:
	if server_only: return
	_box(at+Vector3.UP*height*0.22,Vector3(height*0.44,height*0.44,height*0.42),color.darkened(0.28),glow*0.4)
	_beam(at+Vector3(-height*0.09,height*0.25,0),at+Vector3(height*0.16,height*0.78,0.08),height*0.26,height*0.26,color,glow)
	_box(at+Vector3(height*0.16,height*0.81,0.08),Vector3.ONE*height*0.15,color.lightened(0.2),glow)
	if _wreck_mode:
		_beam(at+Vector3(-0.1,0.20,0.24)*height,at+Vector3(0.16,0.57,0.24)*height,0.035,0.035,RESIN)

func _lantern(at: Vector3,drop := 0.7) -> void:
	if server_only: return
	_beam(at,at+Vector3.DOWN*drop,0.045,0.045,TRIM)
	var center := at+Vector3.DOWN*(drop+0.30)
	_box(center,Vector3(0.38,0.55,0.38),AMBER,0.55 if _wreck_mode else 1.6)
	_box(center+Vector3(0,-0.04,0.23),Vector3(0.13,0.30,0.10),CYAN,0.4 if _wreck_mode else 1.1)
	for y in [-0.32,0.32]: _box(center+Vector3.UP*y,Vector3(0.53,0.10,0.53),TRIM)
	for x in [-0.22,0.22]: _box(center+Vector3(x,0,0),Vector3(0.045,0.58,0.48),TRIM)

## A connected rectangular beam, including sloped stair rails and braces.
func _beam(a: Vector3,b: Vector3,width: float,depth: float,color: Color,glow := 0.0) -> void:
	if server_only or a.is_equal_approx(b): return
	var axis := (b-a).normalized()
	var reference := Vector3.FORWARD if absf(axis.y)>0.98 else Vector3.UP
	var right := axis.cross(reference).normalized()
	var basis := Basis(right,axis.cross(right).normalized(),-axis)
	_box((a+b)*0.5,Vector3.ONE,color,glow)
	_part.points[-1] = Transform3D(basis.scaled_local(Vector3(width,depth,a.distance_to(b))),(a+b)*0.5)
	_part.bounds = (_part.bounds as AABB).merge(AABB(a,Vector3.ZERO).expand(b).grow(maxf(width,depth)))

## Shared endpoint frames make adjacent curved deck/rail sections watertight.
## Mesh colours retain the small voxel divisions; collision uses the same skin.
func _sweep(a: Transform3D,b: Transform3D,low: Vector3,high: Vector3,color: Color,glow := 0.0,solid := false,step := 0.65) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var nx := maxi(1,ceili((high.x-low.x)/step))
	var nz := maxi(1,ceili(a.origin.distance_to(b.origin)/step))
	var reverse := (b.origin-a.origin).dot(a.basis.z+b.basis.z)>0.0
	for end: Transform3D in [a,b]:
		for y in [low.y,high.y]:
			for x in [low.x,high.x]: _part.bounds = (_part.bounds as AABB).expand(end*Vector3(x,y,0))
	for z in nz:
		var t0 := float(z)/nz
		var t1 := float(z+1)/nz
		for x in nx:
			var x0 := lerpf(low.x,high.x,float(x)/nx)
			var x1 := lerpf(low.x,high.x,float(x+1)/nx)
			var corners := PackedVector3Array()
			for t in [t0,t1]:
				for y in [low.y,high.y]:
					for xx in [x0,x1]:
						corners.append((a*Vector3(xx,y,0)).lerp(b*Vector3(xx,y,0),t))
			var tint := _patina(color).lightened((fposmod(sin(corners[0].dot(Vector3(7.71,13.17,5.31)))*7312.13,1.0)-0.5)*0.07)
			# Alpha is unused by this opaque shader; it carries per-cell emission.
			tint.a = (0.45 if _impact_enabled else 0.0)+glow*(0.032 if _wreck_mode else 0.1)
			var triangles: Array[Vector3i] = [Vector3i(0,1,4),Vector3i(1,5,4),Vector3i(2,6,3),Vector3i(3,6,7)]
			if z==0: triangles.append_array([Vector3i(0,2,1),Vector3i(1,2,3)])
			if z==nz-1: triangles.append_array([Vector3i(4,5,6),Vector3i(5,7,6)])
			if x==0: triangles.append_array([Vector3i(0,4,2),Vector3i(2,4,6)])
			if x==nx-1: triangles.append_array([Vector3i(1,3,5),Vector3i(3,7,5)])
			for triangle: Vector3i in triangles:
				var p := corners[triangle.x]
				var q := corners[triangle.y]
				var r := corners[triangle.z]
				if reverse:
					var previous := q
					q = r
					r = previous
				vertices.append_array(PackedVector3Array([p,q,r]))
				if not server_only:
					var normal := (r-p).cross(q-p).normalized()
					normals.append_array(PackedVector3Array([normal,normal,normal]))
					colors.append_array(PackedColorArray([tint,tint,tint]))
	if solid: _part.collision.append({faces=vertices})
	if server_only: return
	_part.vertices = (_part.get("vertices",PackedVector3Array()) as PackedVector3Array)+vertices
	_part.normals = (_part.get("normals",PackedVector3Array()) as PackedVector3Array)+normals
	_part.vertex_colors = (_part.get("vertex_colors",PackedColorArray()) as PackedColorArray)+colors

func _panel(at: Vector3,size: Vector3,color: Color,solid := true,step := 0.75,glow := 0.0) -> void:
	if server_only:
		if solid:
			_part.collision.append({at=at,size=size})
			_part.bounds = (_part.bounds as AABB).merge(AABB(at-size*0.5,size))
		return
	var axis := size.min_axis_index()
	var u := (axis+1)%3
	var v := (axis+2)%3
	var nx := maxi(1,ceili(size[u]/step))
	var ny := maxi(1,ceili(size[v]/step))
	var piece := size
	piece[u] /= nx
	piece[v] /= ny
	for j in ny:
		for i in nx:
			var point := at
			point[u] += (i-(nx-1)*0.5)*piece[u]
			point[v] += (j-(ny-1)*0.5)*piece[v]
			_box(point,piece,color.lightened((fposmod(sin(point.dot(Vector3(7.71,13.17,5.31)))*7312.13,1.0)-0.5)*0.09),glow)
	if solid: _part.collision.append({at=at,size=size})

func _pipe(a: Vector3,b: Vector3,color: Color,radius := 0.18) -> void:
	if _ship_mode:
		if not server_only: _part.get_or_add("round_pipes",[]).append({a=a,b=b,color=_patina(color),radius=radius})
		return
	if server_only: return
	_beam(a,b,radius*2.0,radius*2.0,color)
	var count := maxi(1,ceili(a.distance_to(b)/1.5))
	for i in count+1:
		var p := a.lerp(b,float(i)/count)
		_box(p,Vector3.ONE*radius*2.5,TRIM)

func _cable(a: Vector3,b: Vector3,radius := 0.045,pin_end := false) -> void:
	var frame: Transform3D = _part.frame
	cables.append({frame=Transform3D(Basis.IDENTITY,frame*a),end=frame.basis*(b-a),radius=radius,pin_end=pin_end})

func _fitting(kind: String,at: Vector3,size: Vector3,color: Color,basis := Basis.IDENTITY) -> void:
	if server_only: return
	_part.get_or_add("fittings",[]).append({kind=kind,frame=Transform3D(basis.scaled_local(size),at),color=_patina(color)})

func _inlay(at: Vector3,size: Vector2,mode: int,color: Color,seed: float,basis := Basis.IDENTITY,fault := false) -> void:
	if server_only: return
	_part.get_or_add("inlays",[]).append({frame=Transform3D(basis.scaled_local(Vector3(size.x,size.y,1)),at),mode=mode,color=_patina(color),seed=seed,fault=1.0 if fault else 0.0})

func _ceiling_fixture(at: Vector3,size: Vector2,seed: float,fault: bool) -> void:
	_fitting("block",at+Vector3.DOWN*0.10,Vector3(size.x+0.18,0.20,size.y+0.18),STEEL)
	_inlay(at+Vector3.DOWN*0.21,size,6,Color("c39659") if fault else AMBER,seed,Basis(Vector3.RIGHT,PI*0.5),fault)
	for side in [-1.0,1.0]:
		_fitting("block",at+Vector3(side*(size.x*0.5+0.04),-0.17,0),Vector3(0.07,0.12,size.y),TRIM)

func _room_services(side: float,deck: float,ceiling: float,row: int,wreck: bool) -> void:
	var top := deck+ceiling-0.65
	var color := STEEL.lightened(0.12) if wreck else TRIM
	# Longitudinal room services meet the next bay; branches terminate on risers.
	for x in [side*13.0,side*25.8]:
		_pipe(Vector3(x,top,-5.5),Vector3(x,top,5.5),color,0.11)
	_pipe(Vector3(side*5,top,-4.6),Vector3(side*26.8,top,-4.6),color,0.13)
	var z: float = _part.frame.origin.z-4.6
	var stairs := (-552.0 if wreck else -38.0)-(38.0 if side<0 else 0.0)
	var on_stairs := z<stairs and z>stairs-20.0
	if not on_stairs:
		_pipe(Vector3(side*26.8,deck+0.35,-4.6),Vector3(side*26.8,top,-4.6),color,0.14)
		_pipe(Vector3(side*26.8,deck+0.35,-4.6),Vector3(side*26.8,deck+0.35,-5.15),color,0.14)
		for y in [deck+0.8,deck+2.5,top-0.5]:
			_pipe(Vector3(side*26.8,y,-4.6),Vector3(side*26.8,y,-5.12),TRIM,0.045)
			_fitting("bolt",Vector3(side*26.8,y,-5.13),Vector3(0.22,0.05,0.22),STEEL,Basis(Vector3.RIGHT,PI*0.5))
		# A real handwheel and dial on the pipe, with small round spokes.
		var valve := Vector3(side*26.8,deck+1.65,-4.13)
		_pipe(Vector3(valve.x,valve.y,-4.6),valve,TRIM,0.065)
		_fitting("ring",valve,Vector3.ONE*0.76,Color("bb7351") if wreck else Color("b15a48"),Basis(Vector3.RIGHT,PI*0.5))
		for k in 3:
			var angle := TAU*k/3.0
			_pipe(valve,valve+Vector3(cos(angle),sin(angle),0)*0.32,TRIM,0.025)
		var gauge := Vector3(side*26.8,deck+2.35,-4.34)
		_pipe(Vector3(gauge.x,gauge.y,-4.6),gauge,TRIM,0.05)
		_fitting("cylinder",gauge,Vector3(0.44,0.10,0.44),TRIM,Basis(Vector3.RIGHT,PI*0.5))
		_inlay(gauge+Vector3(0,0,0.057),Vector2.ONE*0.36,1,WHITE,row+side*2.3)
	# Perforated returns, cable junction boxes and technical safety plates.
	if not on_stairs:
		_inlay(Vector3(side*23.9,deck+4.4,-5.13),Vector2(2.7,0.9),0,TRIM,row+deck)
		_inlay(Vector3(side*26.0,deck+3.1,-5.12),Vector2(0.9,0.20),2,GOLD,row)
	_inlay(Vector3(side*10.8,deck+3.8,-5.13),Vector2(1.5,0.8),5,STEEL.lightened(0.12),row)
	_fitting("block",Vector3(side*13.9,deck+2.8,-5.04),Vector3(1.1,1.5,0.22),STEEL)
	_inlay(Vector3(side*13.9,deck+2.8,-4.91),Vector2(0.86,1.2),3,Color("a2b66b") if wreck else CYAN,row+deck)
	# Round sockets carry cables into the enclosure rather than ending in air.
	for y in [deck+2.5,deck+3.1]:
		_pipe(Vector3(side*13.9,y,-4.98),Vector3(side*15.1,y,-4.98),DARK,0.045)
	_pipe(Vector3(side*15.1,deck+2.5,-4.98),Vector3(side*15.1,top,-4.98),DARK,0.045)
	_ceiling_fixture(Vector3(side*18,deck+ceiling,0.3),Vector2(1.0,2.8),73+row*9.71+deck*2.31+side*0.72,wreck)

func _ship_lighting(wreck: bool,row: int,z: float) -> void:
	if not wreck: return
	for deck in [0.0,8.0]:
		var ceiling := 9.2 if deck>0 else 7.4
		if row%4==0:
			var seed: float = 13+row*1.73+deck*0.33
			var x := -18.0 if row==4 else 18.0 if row==12 else 0.0
			if x==0.0:
				_ceiling_fixture(Vector3(0,deck+ceiling,0),Vector2(1.15,3.7),seed,true)
			else:
				seed = 73+row*9.71+deck*2.31+signf(x)*0.72
			lights.append({at=Vector3(x,deck+ceiling-0.30,z+(0.3 if x!=0 else 0.0)),color=Color("bc8747"),energy=2.5,range=24.0,spot=true,fault=true,seed=seed})
		if row in [2,10]:
			lights.append({at=Vector3(0,deck+ceiling-0.5,z),color=Color("a97b42"),energy=0.7,range=19.0})

func _ship_detail(side: float,deck: float,ceiling: float,row: int,wreck: bool) -> void:
	var accent := Color("a3bc66") if wreck else (PINK if row%3==1 else CYAN)
	_room_services(side,deck,ceiling,row,wreck)
	# Door jambs and continuous skirting finish the cabin opening and seams.
	for z in [-2.25,2.25]:
		_box(Vector3(side*6.7,deck+2.8,z),Vector3(0.12,5.6,0.13),TRIM)
		_box(Vector3(side*6.61,deck+2.5,z),Vector3(0.06,0.9,0.055),accent,0.8)
	_box(Vector3(side*6.7,deck+5.6,0),Vector3(0.12,0.18,4.65),TRIM)
	for z in [-3.9,3.9]:
		_box(Vector3(side*6.69,deck+0.14,z),Vector3(0.12,0.28,3.2),STEEL)
		_box(Vector3(side*6.69,deck+5.1,z),Vector3(0.12,0.12,3.2),TRIM)
		for zz in [-0.95,0.95]:
			for y in [0.4,4.9]: _box(Vector3(side*6.61,deck+y,z+zz),Vector3(0.05,0.065,0.065),TRIM)
	# Cable ladders hang from actual ceiling mounts, on both decks.
	for z in [-4.8,-2.4,2.4,4.8]:
		_box(Vector3(side*4.4,deck+ceiling-0.83,z),Vector3(1.75,0.09,0.16),STEEL)
		for x in [side*3.58,side*5.22]:
			_box(Vector3(x,deck+ceiling-0.4,z),Vector3(0.075,0.8,0.075),TRIM)
	for x in [side*4.1,side*4.3,side*4.5]:
		_pipe(Vector3(x,deck+ceiling-0.72,-5.5),Vector3(x,deck+ceiling-0.72,5.5),accent.darkened(0.45),0.03)
	# A recessed control screen and fine switches on a solid wall bay.
	_box(Vector3(side*6.68,deck+2.2,-3.6),Vector3(0.18,1.15,1.4),STEEL)
	_box(Vector3(side*6.57,deck+2.33,-3.72),Vector3(0.06,0.66,0.93),DARK)
	for k in 5:
		_box(Vector3(side*6.53,deck+2.1+k*0.105,-3.8),Vector3(0.025,0.035,0.38+(k%3)*0.15),accent,0.4 if wreck else 1.1)
	for k in 4:
		_box(Vector3(side*6.55,deck+1.83,-4.05+k*0.24),Vector3(0.065,0.09,0.09),GOLD if k==0 else TRIM)
	# Floor drain inserts sit above the deck rather than sharing its face.
	_box(Vector3(side*3,deck+0.035,3.7),Vector3(1.2,0.05,1.5),DARK)
	for k in 10: _box(Vector3(side*3,deck+0.07,3.06+k*0.14),Vector3(1.1,0.035,0.06),TRIM)
	for x in [-0.57,0.57]: _box(Vector3(side*3+x,deck+0.075,3.7),Vector3(0.06,0.04,1.5),STEEL)
	# Room equipment leaves the doorways, stairs and duct spine clear.
	if wreck and row==11 and deck>0 and side>0: return
	var furniture := Vector3(side*11.4,deck,-1.2)
	if row%3==0:
		# A small galley and chart desk use the old workbench footprint.
		for x in [-1.2,1.2]:
			for z in [-0.45,0.45]: _box(furniture+Vector3(x,0.58,z),Vector3(0.14,1.16,0.14),STEEL)
		_box(furniture+Vector3(0,1.25,0),Vector3(2.8,0.18,1.3),WHITE)
		if side<0:
			_inlay(furniture+Vector3(0,1.35,0),Vector2(2.2,1.0),7,AMBER,row,Basis(Vector3.RIGHT,-PI*0.5))
			_box(furniture+Vector3(0.85,1.46,-0.3),Vector3(0.3,0.22,0.3),TRIM)
		else:
			_fitting("cylinder",furniture+Vector3(0,1.48,0),Vector3(0.7,0.35,0.7),TRIM)
			_fitting("ring",furniture+Vector3(0,1.68,0),Vector3(0.50,0.10,0.50),DARK)
			for k in 3: _box(furniture+Vector3(-0.95+k*0.24,1.40,0.3),Vector3(0.18,0.16,0.32),AMBER)
	elif row%3==1:
		# Keep the solid supply cabinet: a carved wardrobe with brass handles.
		_box(furniture+Vector3(0,1.6,0),Vector3(2.4,3.2,1.4),STEEL,0,true)
		for x in [-0.57,0.57]:
			_box(furniture+Vector3(x,1.6,0.73),Vector3(1.05,2.95,0.09),WHITE)
			_box(furniture+Vector3(x*0.3,1.5,0.82),Vector3(0.07,0.36,0.08),GOLD)
		_box(furniture+Vector3(0,3.25,0),Vector3(2.65,0.16,1.55),TRIM)
		_crystal(furniture+Vector3(-0.7,3.34,0),0.55,accent,0.55)
	else:
		# The solid cradle becomes the base of a narrow ship's bookcase.
		_box(furniture+Vector3(0,0.15,0),Vector3(2.8,0.3,1.6),DARK,0,true)
		for x in [-1.1,1.1]: _box(furniture+Vector3(x,1.4,0),Vector3(0.18,2.5,1.4),STEEL)
		for shelf in 3:
			var y := 0.35+shelf*0.85
			_box(furniture+Vector3(0,y,0),Vector3(2.1,0.12,1.1),WHITE)
			for k in 5:
				var h := 0.38+_detail_hash(furniture,float(k+shelf*7))*0.28
				_box(furniture+Vector3(-0.8+k*0.38,y+h*0.5+0.06,0.22),Vector3(0.25,h,0.65),[PINK,STEEL,CYAN,GOLD][(k+shelf)%4].darkened(0.22))
	_lantern(Vector3(side*9.2,deck+ceiling-0.15,3.6),0.6)
	if row%2==0: _crystal(Vector3(side*26.6,deck+1.25,2.9),1.1,accent,0.75)

func _machine(at: Vector3,type: int,broken: bool) -> void:
	var previous_impacts := _impact_enabled
	_impact_enabled = true
	var body := STEEL.darkened(0.25) if broken else STEEL
	_box(at+Vector3(0,0.3,0),Vector3(3.2,0.6,2.5),DARK,0,true)
	_panel(at+Vector3(0,1.7,0),Vector3(2.8,2.2,2.2),body,true,0.4)
	var kind := posmod(type+int(at.y)*2+int(at.x>0),6)
	_story_prop(at,4 if _ship_mode and not broken and _part.frame.origin.z>-10.0 else kind,broken)
	if broken:
		for i in 12:
			_box(at+Vector3(_rng.randf_range(-2.3,2.3),0.12,_rng.randf_range(-1.8,2.6)),Vector3(_rng.randf_range(0.12,0.5),0.2,_rng.randf_range(0.15,0.65)),STEEL)
		if _ship_mode: _cable(at+Vector3(-1.1,3.5,0),at+Vector3(-2.4,0.4,1.3),0.05)
		else: _pipe(at+Vector3(-1.1,3.5,0),at+Vector3(-2.4,0.4,1.3),DARK,0.08)
	_impact_enabled = previous_impacts

## The old solid machine cabinet remains behind these stories in each bay.
func _story_prop(at: Vector3,kind: int,broken: bool) -> void:
	if server_only: return
	var accent := PINK if kind%2 else CYAN
	var front := at+Vector3(0,0,1.16)
	if kind==0 or kind==4:
		# Recessed bunks with patchwork quilts, or a captain's chart cabinet.
		for y in [0.85,2.0]:
			_box(front+Vector3(0,y,0),Vector3(2.65,0.85,0.12),DARK)
			_box(front+Vector3(0,y-0.24,0.15),Vector3(2.6,0.18,0.40),AMBER)
			_box(front+Vector3(-0.94,y-0.05,0.14),Vector3(0.5,0.26,0.35),AMBER.lightened(0.25))
			for k in 6:
				_box(front+Vector3(-0.55+k*0.32,y-0.08,0.22),Vector3(0.30,0.28,0.12),accent if k%2 else GOLD.darkened(0.25))
		_box(at+Vector3(0,2.9,0),Vector3(3.1,0.18,2.5),TRIM)
		if kind==4:
			_inlay(at+Vector3(0,3.01,0),Vector2(2.6,1.9),7,AMBER,at.x+at.y,Basis(Vector3.RIGHT,-PI*0.5))
	elif kind==1:
		# A library: coloured spines break the machinery's repeated silhouette.
		for shelf in 3:
			var y := 0.65+shelf*0.79
			_box(front+Vector3(0,y+0.25,0),Vector3(2.6,0.65,0.10),DARK)
			_box(front+Vector3(0,y-0.1,0.12),Vector3(2.9,0.14,0.36),TRIM)
			for k in 7:
				var height := 0.42+_detail_hash(at,float(shelf*9+k))*0.20
				_box(front+Vector3(-1.1+k*0.36,y+height*0.5,0.13),Vector3(0.26,height,0.20),[PINK,CYAN,GOLD,WHITE][(shelf+k)%4].darkened(0.18))
	elif kind==2:
		# A crystal planter grows out of the carved wooden cabinet.
		_box(at+Vector3(0,2.9,0),Vector3(3.05,0.25,2.4),TRIM)
		for k in 4:
			var p := at+Vector3(-1.0+k*0.65,3.04,sin(k*2.1)*0.55)
			_fitting("cylinder",p+Vector3.UP*0.15,Vector3(0.50,0.30,0.50),STEEL)
			_crystal(p+Vector3.UP*0.30,0.65+_detail_hash(p)*0.6,CYAN,0.25 if broken else 0.8)
			if not broken:
				for side in [-1.0,1.0]:
					_beam(p+Vector3.UP*0.6,p+Vector3(side*0.35,0.85,0.12),0.16,0.08,CYAN.darkened(0.35),0.3)
		for x in [-0.95,0.95]:
			_beam(front+Vector3(x,0.65,0.06),front+Vector3(x*0.6,2.5,0.12),0.08,0.10,accent.darkened(0.35),0.12)
	elif kind==3:
		# Cargo: inset crates below and two brass-banded barrels above.
		for x in [-0.72,0.72]:
			_box(front+Vector3(x,1.65,0),Vector3(1.25,1.95,0.16),WHITE)
			_beam(front+Vector3(x-0.55,0.8,0.12),front+Vector3(x+0.55,2.5,0.12),0.12,0.10,TRIM)
			_fitting("cylinder",at+Vector3(x,3.32,0),Vector3(0.95,1.0,0.95),STEEL)
			for y in [2.93,3.7]: _fitting("ring",at+Vector3(x,y,0),Vector3(0.98,0.08,0.98),TRIM)
	else:
		# A galley dresser with crockery and a coiled rope on its roof.
		for k in 3:
			_box(front+Vector3(0,0.95+k*0.7,0),Vector3(2.65,0.55,0.12),WHITE)
			_box(front+Vector3(0,0.95+k*0.7,0.12),Vector3(0.42,0.07,0.09),TRIM)
		for k in 3: _fitting("ring",at+Vector3(0.65,2.93+k*0.08,0),Vector3(1.0-k*0.16,0.07,1.0-k*0.16),AMBER.darkened(0.3))
		_fitting("cylinder",at+Vector3(-0.7,3.2,0),Vector3(0.65,0.65,0.65),TRIM)
		_crystal(at+Vector3(-0.7,3.55,0),0.65,CYAN,0.4 if broken else 1.2)
	if broken:
		# Splinters, dead mineral tips and sticky brood resin cover the old stories.
		for k in 3:
			_beam(front+Vector3(-1.2+k*0.8,1.05,0.23),front+Vector3(-0.9+k*0.8,2.5,0.27),0.08,0.07,RESIN)
		_crystal(at+Vector3(0.8,2.85,-0.4),0.6,Color("63715b"),0.12)

func _ship(wreck: bool) -> void:
	_ship_mode = true
	_wreck_mode = wreck
	_impact_enabled = false
	var prefix := "wreck" if wreck else "aurora"
	var count := 17 if wreck else 11
	var first := -485.5 if wreck else 6.0
	var base := STEEL.darkened(0.35) if wreck else WHITE
	for row in count:
		var z := first-row*11.0
		_begin(prefix+"_"+str(row),Transform3D(Basis.IDENTITY,Vector3(0,0,z)),550.0)
		_panel(Vector3(0,-0.3,0),Vector3(56,0.6,11.0),base)
		# Upper deck: leave genuine stair wells in the outer walkways.
		_panel(Vector3(0,7.7,0),Vector3(42,0.6,11.0),base.darkened(0.13))
		var stair_start := -552.0 if wreck else -38.0
		for side in [-1.0,1.0]:
			var hole_start := stair_start if side>0 else stair_start-38.0
			var lo := z-5.5
			var hi := z+5.5
			# Cut the exact stair opening, leaving solid landings at both ends.
			for interval: Vector2 in [Vector2(lo,minf(hi,hole_start-20.0)),Vector2(maxf(lo,hole_start),hi)]:
				if interval.y<=interval.x: continue
				_panel(Vector3(side*24.5,7.7,(interval.x+interval.y)*0.5-z),Vector3(7,0.6,interval.y-interval.x),base)
		_panel(Vector3(0,17.5,0),Vector3(56,0.6,11.0),base.darkened(0.2))
		for side in [-1.0,1.0]:
			# Actual openings: no opaque wall or sky texture behind the windows.
			for deck in [0.0,8.0]:
				var ceiling := 9.2 if deck>0 else 7.4
				_panel(Vector3(side*28,deck+0.6,0),Vector3(0.6,1.2,11.0),base)
				_panel(Vector3(side*28,deck+(5.6+ceiling)*0.5,0),Vector3(0.6,ceiling-5.6,11.0),base)
				for zz in [-5.0,0.0,5.0]:
					_box(Vector3(side*28,deck+3.4,zz),Vector3(0.85,4.4,0.28),TRIM,0,true)
				_box(Vector3(side*27.6,deck+1.17,0),Vector3(0.25,0.12,10.8),PINK.darkened(0.65) if wreck else PINK,1.0)
				# Thin clear glass; wooden frames and brass sills reveal actual space.
				_part.get_or_add("glass",[]).append({at=Vector3(side*28,deck+3.4,0),size=Vector3(0.08,4.4,11.0)})
				# Cabins on either side of a wide central spine, with real door gaps.
				for zz in [-3.875,3.875]:
					_panel(Vector3(side*7,deck+2.8,zz),Vector3(0.5,5.6,3.25),base.darkened(0.14))
				_panel(Vector3(side*7,deck+(5.6+ceiling)*0.5,0),Vector3(0.5,ceiling-5.6,11.0),base.darkened(0.14))
				for xx in [side*11.625,side*23.85]:
					var hole := stair_start if side>0 else stair_start-38.0
					if absf(xx)>20.0 and z-5.45<hole and z-5.45>hole-20.0: continue
					_panel(Vector3(xx,deck+ceiling*0.5,-5.325),Vector3(8.75 if absf(xx)<20 else 7.7,ceiling,0.35),base.darkened(0.1))
				_box(Vector3(side*18,deck+(5.6+ceiling)*0.5,-5.325),Vector3(4.0,ceiling-5.6,0.35),TRIM)
				if not (wreck and row==11 and deck>0 and side>0):
					_machine(Vector3(-12 if wreck and side<0 and deck==0 else side*18,deck,-2.5 if wreck and side<0 and deck==0 else 1.0),row+int(side),wreck)
				# Cable trays, suspended conduits, ceiling luminaires and louvres.
				for xx in [side*3.8,side*5.0]: _pipe(Vector3(xx,deck+ceiling-0.5,-5.5),Vector3(xx,deck+ceiling-0.5,5.5),GOLD.darkened(0.5) if wreck else TRIM,0.16)
				if wreck or deck>0 or not TheoryLayout.aurora_box_bay(row,side):
					for k in 8: _box(Vector3(side*6.65,deck+1.0+k*0.18,3.6),Vector3(0.08,0.07,2.5),DARK)
				_box(Vector3(side*4,deck+ceiling-0.16,0),Vector3(1.5,0.32,3.7),Color("826037") if wreck else AMBER,0.2 if wreck else 2.1)
				for k in 6: _box(Vector3(side*5.8,deck+0.04,-2.5+k*0.75),Vector3(0.7,0.04,0.32),GOLD if k%2 else DARK)
				_ship_detail(side,deck,ceiling,row,wreck)
				if row in ([1,4,7,10,13,15] if wreck else [2,4,6,8]):
					curtains.append({frame=Transform3D(Basis(Vector3.UP,-side*PI*0.5),Vector3(side*7,deck,z)),torn=wreck,seed=row*17+int(deck)+int(side)})
				if not wreck and row in [3,7] and deck==0:
					_cable(Vector3(side*5.7,ceiling-0.35,-3.8),Vector3(side*5.3,2.4,-3.2),0.035)
			if not wreck and row%2==0:
				lights.append({at=Vector3(side*4,5.8,z),color=AMBER,energy=1.8,range=14.0})
			if not wreck and row%4==0:
				lights.append({at=Vector3(side*16,15.6,z),color=AMBER,energy=1.8,range=17.0})
			# Hull buttresses and raised external fins visible outside the ship.
			_box(Vector3(side*30,8.5,0),Vector3(3.0,19.0,1.0),STEEL)
			_box(Vector3(side*32,15.0,0),Vector3(7,0.7,2.0),TRIM)
			for y in [0.3,8.3,17.1]: _box(Vector3(side*29,y,0),Vector3(2.0,0.55,1.3),STEEL)
		if not server_only:
			for side in [-1.0,1.0]:
				if row%2==0:
					_crystal(Vector3(side*30.6,17.8,1.4),1.9,CYAN,0.9)
					_crystal(Vector3(side*32.5,15.4,0),1.0,PINK,0.6)
		_ship_lighting(wreck,row,z)
		if row in [0,count-1]:
			for side in [-1.0,1.0]: _panel(Vector3(side*17.5,8.5,5.5 if row==0 else -5.5),Vector3(21,17,0.6),base)
		if wreck:
			for i in 24:
				var p := Vector3(_rng.randf_range(-25,25),0.025,_rng.randf_range(-5,5))
				_box(p,Vector3(_rng.randf_range(0.12,1.0),0.035,_rng.randf_range(0.15,1.8)),BLOOD.lightened(_rng.randf()*0.12))
			if row==12:
				var body := Vector3(14,0.2,-1)
				_box(body,Vector3(0.9,0.35,1.4),Color("4b5768"))
				_box(body+Vector3(0,0.2,-0.9),Vector3(0.7,0.6,0.7),Color("a2adb7"))
				_box(body+Vector3(0,0.25,-1.26),Vector3(0.5,0.25,0.05),DARK)
				for side in [-1.0,1.0]:
					_box(body+Vector3(side*0.7,0,0),Vector3(0.5,0.3,0.9),STEEL)
					_box(body+Vector3(side*0.3,0,1.1),Vector3(0.4,0.3,1.1),STEEL)
			if row%2==0: sparks.append(Vector3(_rng.randf_range(-6,6),_rng.randf_range(3,6),z))
			for i in 3:
				var xx := -4.8+i*4.8
				_pipe(Vector3(xx,7.4,-2),Vector3(xx,6.7,-2),TRIM,0.075)
				_cable(Vector3(xx,6.7,-2),Vector3(xx+0.4,2.3,-1),0.045)
			if row in [6,9]:
				_panel(Vector3(0,2.7,-4.6),Vector3(12.8,5.4,1.0),STEEL)
				for i in 18: _box(Vector3(_rng.randf_range(-6,6),_rng.randf_range(0.2,1.5),_rng.randf_range(-3,1)),Vector3(1.0,0.5,0.8),DARK,0,true)
			_wreck_damage(row,z)
		if row%3==0: signs.append({at=Vector3(0,5.7,z+4.8),text=("VESSEL 02 / " if wreck else "AURORA / ")+["STAR GALLERY","CRYSTAL GARDEN","CREW QUARTERS","HEARTH"][row%4],color=PINK.darkened(0.3) if wreck else GOLD})
	_ship_hull(wreck)
	_stairs(wreck)
	if wreck: _ducts()
	var join := first-(count-1)*11.0-5.5
	var exit := -670.0 if wreck else -118.0
	var throat := join-exit
	_begin(prefix+"_airlock",Transform3D(Basis.IDENTITY,Vector3(0,0,(join+exit)*0.5)),160)
	_panel(Vector3(0,-0.25,0),Vector3(14,0.5,throat),STEEL)
	for side in [-1.0,1.0]:
		_panel(Vector3(side*7,3,0),Vector3(0.6,6,throat),STEEL)
		_box(Vector3(side*6.65,2.4,0),Vector3(0.15,0.14,throat),PINK.darkened(0.55) if wreck else CYAN,1.5)
	_panel(Vector3(0,6.2,0),Vector3(14,0.5,throat),STEEL)
	_panel(Vector3(0,11.825,throat*0.5),Vector3(14,10.75,0.35),base)
	if wreck: _wreck_dock()
	_ship_mode = false
	_wreck_mode = false
	_impact_enabled = true

func _wreck_dock() -> void:
	_begin("wreck_docking_collar",Transform3D(Basis.IDENTITY,Vector3(0,0,TheoryLayout.SHIP_B_START)),240)
	# The road owns the deck outside. Brackets and rails meet it at the sill,
	# without adding a second floor over the approach.
	for side in [-1.0,1.0]:
		_panel(Vector3(side*6.65,3.5,0),Vector3(1.1,7,1.2),STEEL,true,0.4)
		_panel(Vector3(side*6.65,8.0,0),Vector3(1.1,2.0,1.2),DARK,true,0.4)
		_beam(Vector3(side*5.9,1.25,0),Vector3(side*6.65,1.25,0),0.20,0.20,TRIM)
		_beam(Vector3(side*6.65,0,0),Vector3(side*6.65,8,0),0.24,0.24,TRIM)
		_beam(Vector3(side*6.65,7.5,0),Vector3(side*6.65,5,4.2),0.28,0.4,STEEL)
		for k in 8: _box(Vector3(side*6.03,0.5+k*0.7,0.65),Vector3(0.13,0.32,0.08),GOLD if k%2 else DARK)
		_pipe(Vector3(side*7.6,6.5,-1),Vector3(side*7.6,6.5,0.7),TRIM,0.14)
		_pipe(Vector3(side*7.6,6.5,0.7),Vector3(side*7.0,3.7,1.0),DARK,0.11)
	_panel(Vector3(0,7.65,0),Vector3(14.4,1.3,1.2),STEEL,true,0.4)
	_panel(Vector3(0,12.7,0),Vector3(14.4,9,0.6),DARK,true,0.65)
	for x in [-4.8,0.0,4.8]: _box(Vector3(x,7.65,0.67),Vector3(1.4,0.10,0.12),Color("9ea86b"),0.6)
	signs.append({at=Vector3(0,6.0,TheoryLayout.SHIP_B_START+0.8),text="VESSEL 02 / EMERGENCY ACCESS",color=Color("e29d65")})
	spark_jets.append({at=Vector3(7,3.7,TheoryLayout.SHIP_B_START+1),direction=Vector3(-0.8,-1,0.2),interval=Vector2(0.7,2.8)})

func _wreck_damage(row: int,z: float) -> void:
	for deck in [0.0,8.0]:
		var ceiling := 9.2 if deck>0 else 7.4
		var side := -1.0 if (row+int(deck))%3==0 else 1.0
		if not server_only:
			_inlay(Vector3(side*6.70,deck+6.1,0),Vector2(1.6,3.6),8,Color("887b77"),row+deck,Basis(Vector3.UP,-side*PI*0.5))
			_inlay(Vector3(side*6.70,deck+3.3,3.6),Vector2(1.4,1.8),9,RESIN,row+deck,Basis(Vector3.UP,-side*PI*0.5))
			for k in 3:
				_beam(Vector3(side*6.69,deck+0.2,2.7+k*0.3),Vector3(side*6.67,deck+2.8+k*0.4,3.0+k*0.3),0.09,0.10,RESIN)
			_crystal(Vector3(side*6.5,deck+0.12,4.6),0.7,Color("799c56"),0.25)
		# Burned service panels and exposed cables remain attached to the hull.
		_box(Vector3(side*6.70,deck+3.9,-3.9),Vector3(0.065,2.2,1.8),DARK)
		for k in 5:
			_box(Vector3(side*6.65,deck+3.3+k*0.25,-4.5+k*0.13),Vector3(0.04,0.16,0.45),BLOOD.darkened(0.5))
		_pipe(Vector3(side*5,deck+ceiling-0.5,-2.2),Vector3(side*5.6,deck+ceiling-0.5,-2.2),TRIM,0.12)
		_cable(Vector3(side*5.6,deck+ceiling-0.5,-2.2),Vector3(side*5.3,deck+ceiling-1.6,-1.9),0.035)
		spark_jets.append({at=Vector3(side*5.3,deck+ceiling-1.6,z-1.9),direction=Vector3(-side*0.3,-1,0.4),interval=Vector2(0.7,4.8)})
		for k in 5:
			var fragment := Vector3(0.3+0.1*(k%3),0.12+0.035*(k%2),0.45)
			_box(Vector3(side*(4.4+k*0.30),deck+fragment.y*0.5,2.8-sin(k*1.9)*0.6),fragment,STEEL if k%2 else TRIM)
		if row%4==2:
			# A fallen light hangs from its cable, with a clear central passage.
			_cable(Vector3(side*4,deck+ceiling-0.25,0),Vector3(side*5.6,deck+2.5,0.7),0.035,true)
			_beam(Vector3(side*5.6,deck+1.3,0.7),Vector3(side*5.6,deck+2.5,0.7),0.22,0.28,TRIM)
			_box(Vector3(side*5.6,deck+1.9,0.88),Vector3(0.10,0.85,0.08),Color("b58e50"),0.45)
		if (deck==0 and row in [1,4,7,10,13,15]) or (deck>0 and row in [2,6,11,14]):
			var fuel_rng := RandomNumberGenerator.new()
			fuel_rng.seed = _detail_seed+row*719+int(deck)*137
			var fire_side := -1.0 if fuel_rng.randf()<0.5 else 1.0
			var local_z := fuel_rng.randf_range(-3.0,3.0)
			var at := Vector3(fire_side*fuel_rng.randf_range(4.2,5.15),deck+0.08,z+local_z)
			var size := snappedf(fuel_rng.randf_range(1.65,2.35),0.1)
			var height := fuel_rng.randf_range(2.8,3.9 if deck==0 else 4.4)
			var seed := fuel_rng.randi_range(1,100000)
			fires.append({at=at,size=size,height=height,seed=seed,style=fuel_rng.randi_range(0,2)})
			_inlay(Vector3(at.x,deck+0.018,local_z),Vector2(size*2.4,size*2.7),4,DARK,seed,Basis(Vector3.RIGHT,-PI*0.5))
			# The varying spill footprints contain charred fragments and a torn tray.
			for k in fuel_rng.randi_range(4,7):
				var fragment := Vector3(fuel_rng.randf_range(0.18,0.50),fuel_rng.randf_range(0.10,0.25),fuel_rng.randf_range(0.25,0.65))
				_box(Vector3(at.x+fuel_rng.randf_range(-0.55,0.55)*size,deck+fragment.y*0.5,local_z+fuel_rng.randf_range(-0.45,0.45)*size),fragment,STEEL.darkened(0.25))
			_box(Vector3(at.x+fire_side*0.55,deck+0.15,local_z),Vector3(0.18,0.3,size*1.5),TRIM.darkened(0.4))

	_impact_enabled = true
	_wreck_setpiece(row,z)
	_impact_enabled = false

func _wreck_setpiece(row: int,z: float) -> void:
	if row==2:
		# Collapsed cargo cradle; shelving rests on the deck at its broken end.
		var at := Vector3(23,0,1.5)
		for x in [-1.5,1.5]:
			_box(at+Vector3(x,1.6,-0.8),Vector3(0.18,3.2,0.18),TRIM)
			_beam(at+Vector3(x,3.1,-0.8),at+Vector3(x,0.12,2.1),0.16,0.20,STEEL)
		_beam(at+Vector3(-1.5,3.1,-0.8),at+Vector3(1.5,3.1,-0.8),0.18,0.2,TRIM)
		for k in 4:
			var item := at+Vector3(-1.2+k*0.8,0.35,1.0+sin(k*2.1)*0.5)
			_box(item,Vector3(0.65,0.7,0.65),STEEL,0,true)
			_box(item+Vector3(0,0.36,0),Vector3(0.45,0.04,0.45),CYAN,0.5)
	elif row==4:
		# Abandoned medical station and bloodied stretcher in the outer cabin.
		var at := Vector3(-23,0,0.3)
		for x in [-0.7,0.7]:
			for zz in [-1.2,1.2]: _box(at+Vector3(x,0.42,zz),Vector3(0.12,0.84,0.12),TRIM)
		_box(at+Vector3(0,0.9,0),Vector3(1.7,0.24,3.1),STEEL,0,true)
		_box(at+Vector3(0,1.07,0),Vector3(1.45,0.10,2.8),WHITE.darkened(0.45))
		for k in 6: _box(at+Vector3(sin(k*1.9)*0.35,1.13,-1.1+k*0.4),Vector3(0.35,0.035,0.45),BLOOD)
		_box(at+Vector3(1.3,1.5,-1.2),Vector3(0.12,3,0.12),TRIM)
		_box(at+Vector3(1.3,2.7,-1.1),Vector3(0.9,0.55,0.10),DARK)
		for k in 4: _box(at+Vector3(1.05+k*0.15,2.65,-1.03),Vector3(0.06,0.035,0.04),Color("db594f"),0.35)
	elif row==10:
		# Open server rack on the upper deck with a door torn onto the floor.
		var at := Vector3(23,8,0.5)
		_box(at+Vector3(0,0.15,0),Vector3(3.3,0.3,1.8),DARK,0,true)
		for x in [-1.5,1.5]: _box(at+Vector3(x,1.8,0),Vector3(0.18,3.6,1.6),STEEL)
		_box(at+Vector3(0,3.6,0),Vector3(3.1,0.18,1.6),TRIM)
		for k in 7:
			_box(at+Vector3(0,0.5+k*0.42,-0.2),Vector3(2.7,0.28,0.95),STEEL)
			for x in [-0.9,-0.5,0.6]: _box(at+Vector3(x,0.5+k*0.42,0.30),Vector3(0.09,0.07,0.05),GOLD if k%3==0 else CYAN,0.6)
		_beam(at+Vector3(-1.5,3.5,0.85),at+Vector3(-0.8,0.1,2.5),0.7,0.09,TRIM)
	elif row==15:
		# Ruptured reserve fuel equipment near the final upper-deck search area.
		var at := Vector3(23,8,0.4)
		_box(at+Vector3(0,0.2,0),Vector3(3.8,0.4,2.8),DARK,0,true)
		for x in [-1.1,1.1]:
			_box(at+Vector3(x,1.5,0),Vector3(0.95,2.6,1.4),STEEL,0,true)
			for y in [0.6,1.5,2.4]: _box(at+Vector3(x,y,0),Vector3(1.1,0.10,1.55),TRIM)
		_pipe(at+Vector3(-1.1,2.5,0.7),at+Vector3(-0.35,2.5,0.7),TRIM,0.12)
		spark_jets.append({at=Vector3(22.65,10.5,z+1.1),direction=Vector3(0.7,-1,0.6),interval=Vector2(0.6,2.0)})
		fires.append({at=Vector3(23,8.1,z+2.5),size=2.4,height=4.8,seed=_detail_seed+1731,style=2})

func _ship_hull(wreck: bool) -> void:
	var prefix := "wreck" if wreck else "aurora"
	var end := TheoryLayout.SHIP_B_END if wreck else TheoryLayout.SHIP_A_END
	_begin(prefix+"_engines",Transform3D(Basis.IDENTITY,Vector3(0,0,end)),650)
	for side in [-1.0,1.0]:
		for ring in 11:
			for x in range(-5,6):
				for y in range(-5,6):
					var radius := maxi(absi(x),absi(y))
					if radius!=4: continue
					_box(Vector3(side*18+x*0.8,-4+y*0.8,-ring*0.85),Vector3(0.8,0.8,0.9),STEEL if ring%3 else TRIM)
		for x in range(-3,4):
			for y in range(-3,4):
				_box(Vector3(side*18+x*0.7,-4+y*0.7,-8.8),Vector3(0.6,0.6,0.3),Color("619467") if wreck else CYAN,0.2 if wreck else 2.0)
		if not wreck:
			for k in 16:
				var r := (1.0-float(k)/18.0)*2.0
				for x in [-1.0,0.0,1.0]:
					_box(Vector3(side*18+x*r,-4+sin(k*1.7)*0.4,-9-k*0.7),Vector3(0.65,0.65,0.7),Color("50c98b") if k>6 else Color("c6ffb4"),1.5)
		# Diagonal stepped stabilizers, landing struts and service trusses.
		_box(Vector3(side*28,-0.3,11),Vector3(4,0.6,9),STEEL)
		_beam(Vector3(side*26,8.5,14),Vector3(side*30,10.4,14),0.8,1.0,STEEL)
		for i in 12:
			_box(Vector3(side*(28+i*0.9),-1+i*0.4,8+i*0.5),Vector3(1.1,0.55,6.0),TRIM)
			_box(Vector3(side*(29+i*0.5),9+i*0.7,14),Vector3(0.65,0.8,4.0),STEEL)
	if wreck: return
	_begin("aurora_observation_bow",Transform3D.IDENTITY,650)
	for row in 14:
		var z := 11.5+row*1.5
		var width_a := lerpf(56.0,27.0,float(row)/14.0)
		var width_b := lerpf(56.0,27.0,float(row+1)/14.0)
		for deck in [0.0,8.0]:
			var ceiling := 9.2 if deck>0 else 7.4
			# The bow is tapered, with continuous glass, hull and floor edges.
			var a := Transform3D(Basis.from_scale(Vector3(width_a/56.0,1,1)),Vector3(0,deck,z))
			var b := Transform3D(Basis.from_scale(Vector3(width_b/56.0,1,1)),Vector3(0,deck,z+1.5))
			_sweep(a,b,Vector3(-28,-0.6,0),Vector3(28,0,0),WHITE,0.0,true)
			for side in [-1.0,1.0]:
				_sweep(a,b,Vector3(side*28-0.3,0,0),Vector3(side*28+0.3,1.2,0),WHITE,0.0,true)
				_sweep(a,b,Vector3(side*28-0.3,5.6,0),Vector3(side*28+0.3,ceiling,0),WHITE,0.0,true)
				var p := Vector3(side*width_a*0.5,deck+3.4,z)
				var q := Vector3(side*width_b*0.5,deck+3.4,z+1.5)
				var orientation := Basis.looking_at((q-p).normalized())
				_part.get_or_add("glass",[]).append({at=(p+q)*0.5,size=Vector3(0.08,4.4,p.distance_to(q)),basis=orientation})
				if row%2==0: _box(p,Vector3(0.22,4.4,0.22),TRIM,0,true)
				_beam(Vector3(p.x,deck+1.23,z),Vector3(q.x,deck+1.23,z+1.5),0.12,0.06,CYAN,1.0)
		var roof_a := Transform3D(Basis.from_scale(Vector3(width_a/56.0,1,1)),Vector3(0,0,z))
		var roof_b := Transform3D(Basis.from_scale(Vector3(width_b/56.0,1,1)),Vector3(0,0,z+1.5))
		_sweep(roof_a,roof_b,Vector3(-28,17.2,0),Vector3(28,17.8,0),WHITE,0.0,true)
	for deck in [0.0,8.0]:
		var ceiling := 9.2 if deck>0 else 7.4
		_panel(Vector3(0,deck+0.6,32.5),Vector3(27,1.2,0.5),WHITE)
		_panel(Vector3(0,deck+(5.6+ceiling)*0.5,32.5),Vector3(27,ceiling-5.6,0.5),WHITE)
		_part.get_or_add("glass",[]).append({at=Vector3(0,deck+3.4,32.5),size=Vector3(27,4.4,0.1)})
		for x in range(-12,13,3): _box(Vector3(x,deck+3.4,32.5),Vector3(0.16,4.4,0.3),TRIM,0,true)
		for x in [-9.0,0.0,9.0]:
			_box(Vector3(x,deck+0.65,29),Vector3(2.8,1.3,1.0),STEEL,0,true)
			_box(Vector3(x,deck+1.39,29),Vector3(2.3,0.18,0.9),CYAN,1.2)
			for k in 12: _box(Vector3(x-0.9+k*0.16,deck+1.5,29.2),Vector3(0.08,0.035,0.12),GOLD if k%4==0 else DARK)
	if not server_only:
		for deck in [0.0,8.0]:
			for side in [-1.0,1.0]:
				var desk := Vector3(side*16.5,deck,19)
				for x in [-1.1,1.1]:
					for z in [-0.65,0.65]: _box(desk+Vector3(x,0.65,z),Vector3(0.14,1.3,0.14),STEEL)
				_box(desk+Vector3.UP*1.35,Vector3(2.8,0.18,1.8),WHITE)
				_inlay(desk+Vector3.UP*1.45,Vector2(2.4,1.5),7,AMBER,deck+side,Basis(Vector3.RIGHT,-PI*0.5))
				_lantern(desk+Vector3(0,(9.2 if deck>0 else 7.4)-0.2,-0.4),0.8)
				_crystal(Vector3(side*19.3,deck+0.1,16),1.2,CYAN,0.9)
	_observation_services()
	signs.append({at=Vector3(0,5,26),text="AURORA / OBSERVATION",color=CYAN})

func _observation_services() -> void:
	for deck in [0.0,8.0]:
		var ceiling: float = deck+(9.2 if deck>0 else 7.4)
		for side in [-1.0,1.0]:
			# Follow the tapered bow instead of ending pipes at the straight hull.
			var a := Vector3(side*26,ceiling-0.65,12)
			var b := Vector3(side*12.7,ceiling-0.65,32)
			_pipe(Vector3(side*25.8,ceiling-0.65,11.5),a,TRIM,0.12)
			_pipe(a,b,TRIM,0.12)
			for i in 6:
				var at := a.lerp(b,float(i)/5)
				_pipe(at,Vector3(at.x,ceiling-0.05,at.z),STEEL,0.035)
				_fitting("bolt",Vector3(at.x,ceiling-0.025,at.z),Vector3(0.24,0.05,0.24),TRIM)
			_pipe(Vector3(side*12.7,ceiling-0.65,32),Vector3(side*12.7,deck+5.8,32),TRIM,0.12)
		_pipe(Vector3(-12.7,deck+5.8,32),Vector3(12.7,deck+5.8,32),TRIM,0.12)
		_pipe(Vector3(-12.7,deck+1.27,32.2),Vector3(12.7,deck+1.27,32.2),TRIM,0.05)
		for z in [17.5,25.0]: _ceiling_fixture(Vector3(0,ceiling,z),Vector2(1.2,3.8),z+deck,false)
		lights.append({at=Vector3(0,ceiling-1.0,25),color=AMBER,energy=2.2,range=19.0})
		for x in [-9.0,0.0,9.0]:
			# Actual inset screens, keyboard plates and round control encoders.
			_pipe(Vector3(x,deck+1.4,29),Vector3(x,deck+2.0,29.25),STEEL,0.06)
			_fitting("block",Vector3(x,deck+2.05,29.27),Vector3(1.55,0.85,0.16),STEEL)
			_inlay(Vector3(x,deck+2.05,29.17),Vector2(1.35,0.65),3,CYAN,x+deck,Basis(Vector3.UP,PI))
			_inlay(Vector3(x,deck+1.50,28.9),Vector2(1.25,0.42),5,TRIM,x,Basis(Vector3.RIGHT,-PI*0.5))
			for dx in [-0.94,0.94]:
				_fitting("cylinder",Vector3(x+dx,deck+1.53,28.95),Vector3(0.16,0.08,0.16),TRIM)
			# Operator seat with a pedestal and supported back, clear of walkways.
			_fitting("cylinder",Vector3(x,deck+0.05,26.6),Vector3(0.9,0.10,0.9),STEEL)
			_pipe(Vector3(x,deck+0.1,26.6),Vector3(x,deck+0.62,26.6),TRIM,0.065)
			_fitting("cylinder",Vector3(x,deck+0.69,26.6),Vector3(0.88,0.15,0.88),DARK)
			_fitting("block",Vector3(x,deck+1.13,26.26),Vector3(0.80,0.85,0.12),DARK)
			_part.collision.append({at=Vector3(x,deck+0.70,26.6),size=Vector3(0.85,1.4,0.75)})
			for side in [-1.0,1.0]:
				_pipe(Vector3(x+side*0.30,deck+0.6,26.6),Vector3(x+side*0.30,deck+1.4,26.24),TRIM,0.035)

func _stairs(wreck: bool) -> void:
	var z0 := -552.0 if wreck else -38.0
	for side in [-1.0,1.0]:
		_begin(("wreck" if wreck else "aurora")+"_stair_"+str(side),Transform3D.IDENTITY,120)
		signs.append({at=Vector3(side*24.5,2.5,z0+2 if side>0 else z0-60),text="UPPER DECK" if side>0 else "LOWER DECK",color=CYAN})
		for i in 20:
			var z := z0-i-0.5 if side>0 else z0-58+i+0.5
			var height := (i+1)*0.4
			_panel(Vector3(side*24.5,height-0.2,z),Vector3(6.2,0.4,1.0),TRIM,true,0.5)
			_box(Vector3(side*24.5,height+0.045,z-0.46 if side>0 else z+0.46),Vector3(6.1,0.05,0.08),GOLD,0.5)
			for x in [side*21.3,side*27.7]:
				if i%3==0 or i==19: _box(Vector3(x,height+0.65,z),Vector3(0.13,1.3,0.13),STEEL)
		for x in [side*21.3,side*27.7]:
			var bottom := Vector3(x,0.2,z0 if side>0 else z0-58)
			var top := Vector3(x,8.2,z0-20 if side>0 else z0-38)
			for y in [0.6,1.25]: _beam(bottom+Vector3.UP*y,top+Vector3.UP*y,0.16,0.16,TRIM)
			_beam(bottom-Vector3.UP*0.55,top-Vector3.UP*0.55,0.3,0.6,STEEL)
			# Level returns make the handrail meet each landing.
			var forward := Vector3(0,0,-1 if side>0 else 1)
			_beam(bottom+Vector3.UP*1.25-forward, bottom+Vector3.UP*1.25,0.16,0.16,TRIM)
			_beam(top+Vector3.UP*1.25,top+Vector3.UP*1.25+forward,0.16,0.16,TRIM)

func _ducts() -> void:
	var segments: Array = [[Vector3(-10,0,-548),Vector3(-16.3,0,-548)],
		[Vector3(-18,0,-546.3),Vector3(-18,0,-619)],
		[Vector3(-16.3,0,-573.5),Vector3(-9,0,-573.5)],
		[Vector3(-16.3,0,-606.5),Vector3(-9,0,-606.5)]]
	for index in segments.size():
		var a: Vector3 = segments[index][0]
		var b: Vector3 = segments[index][1]
		var forward := (b-a).normalized()
		var frame := Transform3D(Basis(forward.cross(Vector3.UP),Vector3.UP,-forward),(a+b)*0.5)
		_begin("duct_"+str(index),frame,100)
		var length := a.distance_to(b)
		# Raised grating replaces duplicate deck faces; branches butt into the
		# trunk without drawing another floor or roof across the junction.
		_panel(Vector3(0,0.055,0),Vector3(3.4,0.09,length),DARK)
		_panel(Vector3(0,3.0,0),Vector3(3.4,0.25,length),STEEL)
		for side in [-1.0,1.0]:
			if index==1 and side>0:
				var cursor := -619.0
				for branch in [-606.5,-573.5,-548.0]:
					var end: float = branch-1.8
					if end>cursor:
						var center := frame.affine_inverse()*Vector3(-16.3,1.5,(cursor+end)*0.5)
						_panel(center,Vector3(0.2,3.0,end-cursor),STEEL)
					cursor = branch+1.8
			else:
				_panel(Vector3(side*1.7,1.5,0),Vector3(0.2,3.0,length),STEEL)
		if index==1:
			for end in [-1.0,1.0]: _panel(Vector3(0,1.5,end*length*0.5),Vector3(3.4,3,0.2),STEEL)
		for i in ceili(length/2.5):
			var z := -length*0.5+(i+0.5)*length/ceili(length/2.5)
			_box(Vector3(0,2.8,z),Vector3(3.4,0.2,0.14),TRIM)
			_box(Vector3(-1.56,0.35,z),Vector3(0.06,0.1,0.7),Color("ba6694"),0.6)
			for x in [-1.3,1.3]: _box(Vector3(x,0.12,z),Vector3(0.08,0.035,0.1),TRIM)
		_pipe(Vector3(1.45,2.65,-length*0.5),Vector3(1.45,2.65,length*0.5),DARK,0.1)
		if index!=1: vents.append(Transform3D(frame.basis,a if index==0 else b))
	signs.append({at=Vector3(-17,1.3,-613),text="IT FOLLOWED THE SIGNAL",color=Color("a13240")})

func _ribbon(layout: TheoryLayout,index: int) -> void:
	var frames: Array = layout.paths[index].frames
	for i in frames.size()-1:
		var a: Transform3D = frames[i]
		var b: Transform3D = frames[i+1]
		# Ship throat floors own their full length; the ribbon starts at the sill.
		var exit_z := -670.0 if index==1 else -118.0
		if a.origin.z>exit_z:
			if b.origin.z>=exit_z: continue
			a = a.interpolate_with(b,(exit_z-a.origin.z)/(b.origin.z-a.origin.z))
		var middle := a.interpolate_with(b,0.5)
		_begin("ribbon_%d_%d" % [index,i],middle,520)
		var tint := Color.from_hsv(fmod(float(i)*0.013+index*0.28,1.0),0.72,0.6)
		var pieces: Array[Array] = [[a,b]]
		# The transit platform owns its footprint. Clip the connecting road at
		# its exact front/back edges, instead of drawing two floors at y=0.
		if index==0 and a.origin.z>-151.0 and b.origin.z<-122.0:
			pieces.clear()
			if a.origin.z>-125.0:
				pieces.append([a,a.interpolate_with(b,clampf((-125.0-a.origin.z)/(b.origin.z-a.origin.z),0.0,1.0))])
			if b.origin.z<-147.0:
				pieces.append([a.interpolate_with(b,clampf((-147.0-a.origin.z)/(b.origin.z-a.origin.z),0.0,1.0)),b])
		for piece: Array in pieces:
			var start: Transform3D = piece[0]
			var finish: Transform3D = piece[1]
			if start.origin.distance_to(finish.origin)<0.001: continue
			var local_a := middle.affine_inverse()*start
			var local_b := middle.affine_inverse()*finish
			# Taper the road into the wider transit platform with shared edges.
			if index==0:
				local_a.basis.x *= _ribbon_width(start.origin.z)
				local_b.basis.x *= _ribbon_width(finish.origin.z)
			_sweep(local_a,local_b,Vector3(-6,-0.7,0),Vector3(6,0,0),STEEL.lerp(tint,0.55),0.0,true)
			for side in [-1.0,1.0]:
				_sweep(local_a,local_b,Vector3(side*5.8-0.1,0.015,0),Vector3(side*5.8+0.1,0.12,0),tint.lightened(0.4),1.4)
				_sweep(local_a,local_b,Vector3(side*5.5-0.5,-1.0,0),Vector3(side*5.5+0.5,-0.7,0),DARK)
				# Every section owns its rail, with endpoints taken from the next.
				for y in [0.6,1.25]:
					_sweep(local_a,local_b,Vector3(side*5.9-0.10,y-0.09,0),Vector3(side*5.9+0.10,y+0.09,0),TRIM,0.0,y>1.0,2.0)
				_sweep(local_a,local_b,Vector3(side*5.9-0.1,0.02,0),Vector3(side*5.9+0.1,0.21,0),STEEL)
				# Posts attach to the true frame at the joint, not the chord centre.
				_beam(local_a*Vector3(side*5.9,0,0),local_a*Vector3(side*5.9,1.3,0),0.16,0.16,TRIM)
				if i%4==0:
					# World frames roll with the bridge, including the hanging lantern.
					_crystal_frame(local_a,Vector3(side*5.9,1.32,0),0.7,PINK if i%8==0 else CYAN)
					_lantern_frame(local_a,Vector3(side*5.9,2.6,0.85))
		if pieces.is_empty(): continue
		if i%7==0:
			for side in [-1.0,1.0]:
				_beam(Vector3(side*5.2,-0.9,0),Vector3(side*7,-2.8,0),0.5,0.5,TRIM)
				_beam(Vector3(side*7,-2.8,0),Vector3(side*7,6.4,0),0.6,0.6,STEEL)
				_box(Vector3(side*7,6.6,0),Vector3(1.0,0.4,1.0),tint.lightened(0.5),2)
		if i%6==0:
			for x in range(-4,5):
				_box(Vector3(x*1.05,0.06,0),Vector3(0.7,0.06,0.5),Color.from_hsv(fmod(i*0.013+x*0.06+1.0,1.0),0.7,1.0),0.8)
			for side in [-1.0,1.0]:
				_beam(Vector3(side*5.5,-0.8,0),Vector3(side*10,-5.5,0),0.45,0.55,STEEL)
				_beam(Vector3(side*10,-5.5,0),Vector3(side*13.5,1.0,0),0.55,0.8,TRIM)
				for k in 7:
					var at := Vector3(side*(10+k*0.58),-5.5+k*1.08,0)
					_box(at,Vector3(0.7,0.28,1.05),tint.lightened(k*0.03),0.4)
		if i%14==0:
			_service_pod(8.7,3.7,tint,middle.affine_inverse()*a,middle.affine_inverse()*b)
			_machine(Vector3(8.7,0,0),i,index==1)
			lights.append({at=middle*Vector3(0,3,0),color=tint.lightened(0.4),energy=1.1,range=18.0})
		if i%19==3:
			_service_pod(13.5,8.5,tint,middle.affine_inverse()*a,middle.affine_inverse()*b)
			# Closed antenna hoop and attached pedestal, with no missing arcs.
			for k in 40:
				var angle := TAU*k/40.0
				var next := TAU*(k+1)/40.0
				_beam(Vector3(14+cos(angle)*6.5,7+sin(angle)*6.5,0),Vector3(14+cos(next)*6.5,7+sin(next)*6.5,0),0.6,0.9,Color.from_hsv(fmod(k/40.0+i*0.01,1.0),0.8,0.9),0.9)
			_box(Vector3(14,0.4,0),Vector3(3.2,0.8,2),STEEL)
			for x in [10.0,18.0]:
				_beam(Vector3(x,0,0),Vector3(x,1.9,0),0.4,0.5,TRIM)
		if i%22==0:
			for x in range(-9,9):
				_beam(Vector3(x*0.75,7.0+sin(x*0.16)*1.6,0),Vector3((x+1)*0.75,7.0+sin((x+1)*0.16)*1.6,0),0.55,0.8,tint,0.8)
			for side in [-1.0,1.0]:
				_beam(Vector3(side*5.5,-0.5,0),Vector3(side*6.75,-0.5,0),0.7,0.7,STEEL)
				_beam(Vector3(side*6.75,-0.5,0),Vector3(side*6.75,7.0+sin(side*9*0.16)*1.6,0),0.55,0.65,TRIM)
		if index==1:
			if i%17==5:
				_box(Vector3(5.1,0.65,0),Vector3(1.2,1.3,1.2),STEEL)
				turrets.append(Transform3D(middle.basis,middle*Vector3(5.1,2.0,0)))
			if i%9==0:
				# Only detached wreckage drifts; intact machinery stays assembled.
				_begin("fracture_debris_"+str(i),middle,520)
				_part.unstable = true
				for k in 7:
					_box(Vector3(_rng.randf_range(-19,19),_rng.randf_range(4,13),_rng.randf_range(-5,5)),Vector3.ONE*_rng.randf_range(0.35,1.7),tint,0.4)

static func _ribbon_width(z: float) -> float:
	if z>=-125.0: return 1.0+clampf((-122.0-z)/3.0,0.0,1.0)*2.0/3.0
	if z<=-147.0: return 1.0+clampf((z+151.0)/4.0,0.0,1.0)*2.0/3.0
	return 5.0/3.0

func _service_pod(x: float,half_width: float,tint: Color,a: Transform3D,b: Transform3D) -> void:
	var far_edge := x+half_width
	_sweep(a,b,Vector3(6,-0.7,0),Vector3(far_edge,0,0),STEEL,0.0,true)
	_sweep(a,b,Vector3(x-1.75,-0.3,0),Vector3(x+1.75,0.05,0),STEEL)
	for end: Transform3D in [a,b]:
		_beam(end*Vector3(5.1,-0.9,0),end*Vector3(far_edge,-0.7,0),0.5,0.5,TRIM)
		_beam(end*Vector3(5.1,-0.9,0),end*Vector3(5.1,-2.7,0),0.4,0.4,STEEL)
		_beam(end*Vector3(5.1,-2.7,0),end*Vector3(far_edge,-0.7,0),0.4,0.4,STEEL)
		for y in [0.6,1.25]: _beam(end*Vector3(6.1,y,0),end*Vector3(far_edge,y,0),0.14,0.14,TRIM)
		for xx in [6.1,far_edge]: _beam(end*Vector3(xx,0,0),end*Vector3(xx,1.3,0),0.14,0.14,TRIM)
	for y in [0.6,1.25]: _sweep(a,b,Vector3(far_edge-0.07,y-0.07,0),Vector3(far_edge+0.07,y+0.07,0),TRIM,0.0,false,2.0)
	_sweep(a,b,Vector3(far_edge-0.18,0.02,0),Vector3(far_edge-0.06,0.14,0),tint.lightened(0.4),1.0)

func _transit_platform() -> void:
	_begin("transit_platform",Transform3D(Basis.IDENTITY,Vector3(0,0,-136)),150)
	_panel(Vector3(0,-0.65,0),Vector3(20,1.3,22),STEEL,true,0.65)
	for side in [-1.0,1.0]:
		for y in [0.6,1.25]: _beam(Vector3(side*9.833333,y,-11),Vector3(side*9.833333,y,11),0.2,0.18,TRIM)
		for z in range(-11,12,2): _box(Vector3(side*9.833333,0.65,z),Vector3(0.16,1.3,0.16),TRIM)
		_part.collision.append({at=Vector3(side*9.833333,0.65,0),size=Vector3(0.2,1.3,22)})
	for side in [-1.0,1.0]:
		for z in [-8.0,8.0]:
			_panel(Vector3(side*8,1.7,z),Vector3(0.8,3.4,0.8),TRIM)
			_box(Vector3(side*8,3.5,z),Vector3(1.2,0.3,1.2),CYAN,1.8)
	_machine(Vector3(-7.6,0,7.8),0,false)

func _arena() -> void:
	for ring in 4:
		_begin("arena_"+str(ring),Transform3D(Basis.IDENTITY,TheoryLayout.ARENA),250)
		var outer := 27.0-ring*5.5
		var inner := -0.1 if ring==3 else outer-5.5
		for z in range(-27,28):
			for x in range(-27,28):
				var r := Vector2(x,z).length()
				if r>outer or r<=inner: continue
				var y := r*r*0.006
				_box(Vector3(x,y-0.25,z),Vector3(1.0,0.5,1.0),STEEL.lerp(Color("518b70"),0.35 if ring%2 else 0.0),0.1,true)
				if absf(r-(outer-0.7))<0.38 or (x+z)%11==0: _box(Vector3(x,y+0.02,z),Vector3(0.8,0.045,0.8),(PINK if ring%2 else CYAN),0.85)
	_begin("convergence_engine",Transform3D(Basis.IDENTITY,TheoryLayout.ARENA),320)
	for i in 40:
		var a := TAU*i/40.0
		var at := Vector3(cos(a)*31,4,sin(a)*31)
		if absf(at.x)<3.0 and at.z>25.0: continue  # unobstructed bridge entrance
		_panel(at,Vector3(1.8,8.0,1.8),STEEL,true,0.6)
		_box(at+Vector3.UP*4.5,Vector3(2.5,0.5,2.5),(PINK if i%2 else CYAN),1.5)
		_crystal(at+Vector3.UP*4.8,1.8,PINK if i%2 else CYAN,1.0)
		_beam(Vector3(cos(a)*25,3.1,sin(a)*25),Vector3(cos(a)*31,0,sin(a)*31),0.65,0.8,STEEL)
		_beam(Vector3(cos(a)*31,0,sin(a)*31),Vector3(cos(a+TAU/40)*31,0,sin(a+TAU/40)*31),1.2,1.0,TRIM)
		_box(Vector3(cos(a)*31,12,sin(a)*31),Vector3(0.5,8,0.5),DARK)
		for y in 3: _box(Vector3(cos(a)*31,11+y*2,sin(a)*31),Vector3(1,1,1),(PINK if i%2 else CYAN),1.2)
		if i%5==0:
			_beam(Vector3(cos(a)*31,16,sin(a)*31),Vector3(cos(a)*23,23+sin(a*3)*4,sin(a)*23),0.4,0.55,TRIM)
	for i in 100:
		var a := TAU*i/100.0
		var b := TAU*(i+1)/100.0
		_beam(Vector3(cos(a)*23,23+sin(a*3)*4,sin(a)*23),Vector3(cos(b)*23,23+sin(b*3)*4,sin(b)*23),0.65,0.7,(PINK if i%2 else CYAN),1.2)
	lights.append({at=TheoryLayout.ARENA+Vector3(0,9,0),color=Color("c9d9a3"),energy=2.0,range=45.0})
	signs.append({at=TheoryLayout.ARENA+Vector3(0,5,-12),text="CONVERGENCE\nTHE BROOD THRONE",color=CYAN})

func _space() -> void:
	var dust_rng := RandomNumberGenerator.new()
	dust_rng.seed = _detail_seed+781
	var planets: Array = [[Vector3(-520,110,-130),160.0,Color("875dba"),false],
		[Vector3(620,-100,-410),220.0,Color("49c796"),false],
		[Vector3(-720,320,-1050),130.0,Color("ee7c69"),false],
		[Vector3(400,370,-1100),165.0,Color("e66ca7"),false],
		[Vector3(-350,480,-470),65.0,Color("a8c699"),false],
		[Vector3(250,240,100),95.0,Color("ffba51"),true],
		[Vector3(-280,-260,-1250),125.0,Color("ef545d"),true]]
	for index in planets.size():
		var spec: Array = planets[index]
		var radius: float = spec[1]
		var step := radius/13.0
		_begin("celestial_"+str(index),Transform3D(Basis.IDENTITY,spec[0]),0,true)
		for z in range(-14,15):
			for y in range(-14,15):
				for x in range(-14,15):
					var p := Vector3(x,y,z)*step
					if absf(p.length()-radius)>step*0.7: continue
					var band := 0.5+0.5*sin(y*0.48+sin(x*0.35)*0.9)
					var color: Color = spec[2]
					color = color.lightened(band*0.32).darkened(dust_rng.randf()*0.18)
					_box(p,Vector3.ONE*step*1.03,color,2.0 if spec[3] else 0.18)
		if index in [0,1,3]:
			for i in 260:
				var a := TAU*i/260.0
				var r := radius*dust_rng.randf_range(1.35,1.8)
				_box(Vector3(cos(a)*r,sin(a)*r*0.18,sin(a)*r),Vector3.ONE*step*0.55,(spec[2] as Color).lightened(0.25),0.5)
	_begin("starfield",Transform3D(Basis.IDENTITY,Vector3(0,0,-500)),0,true)
	for i in 2200:
		var direction := Vector3(dust_rng.randf_range(-1,1),dust_rng.randf_range(-1,1),dust_rng.randf_range(-1,1)).normalized()
		var p := direction*dust_rng.randf_range(1700,2400)
		var s := dust_rng.randf_range(0.7,2.5)
		_box(p,Vector3.ONE*s,Color("b3dcff").lerp(Color("ffcedb"),dust_rng.randf()),1.7)
	# Three-dimensional voxel dust ribbons behind the walkable architecture.
	for i in 950:
		var t := dust_rng.randf()*TAU
		var r := dust_rng.randf_range(850,1300)
		var p := Vector3(cos(t)*r,sin(t*2.0)*240+dust_rng.randf_range(-75,75),sin(t)*r)
		_box(p,Vector3.ONE*dust_rng.randf_range(3,11),Color("38b27e").lerp(Color("d45b9d"),0.5+0.5*sin(t*2.0)).darkened(0.30 if p.z<-700.0 else 0.0),0.65)

## Rotate whole decorations with the rail at rolled ribbon joints.
func _crystal_frame(frame: Transform3D,at: Vector3,height: float,color: Color) -> void:
	if server_only: return
	var first: int = _part.points.size()
	_crystal(at,height,color,0.95)
	_transform_decoration(first,frame)

func _lantern_frame(frame: Transform3D,at: Vector3) -> void:
	if server_only: return
	var first: int = _part.points.size()
	_beam(at+Vector3(0,-1.3,-0.3),at+Vector3(0,0,-0.3),0.08,0.08,TRIM)
	_beam(at+Vector3(0,0,-0.3),at,0.08,0.08,TRIM)
	_lantern(at,0.35)
	_transform_decoration(first,frame)

func _transform_decoration(first: int,frame: Transform3D) -> void:
	for index in range(first,_part.points.size()):
		var transformed: Transform3D = frame*_part.points[index]
		_part.points[index] = transformed
		_part.bounds = (_part.bounds as AABB).merge(transformed*AABB(Vector3.ONE*-0.5,Vector3.ONE))
