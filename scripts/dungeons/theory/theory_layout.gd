class_name TheoryLayout
extends RefCounted
## Authored macro route; all local frames are shared by art, collision,
## gravity, puzzles, turrets and remote players. Forward is local -Z.
const SHIP_A_END := -112.0
const SHIP_B_START := -480.0
const SHIP_B_END := -664.0
const ARENA := Vector3(0,0,-1120)
const WIDTH := 12.0
# Nine cabinets sit in rooms; one remains beside the observation corridor.
const ELECTRICAL_POSITIONS := [Vector3(-26.9,1.45,-5.0),Vector3(26.9,1.45,-27.0),Vector3(-26.9,1.45,-49.0),
	Vector3(26.9,1.45,-71.0),Vector3(-6.45,1.45,-89.2),
	Vector3(-13.3,1.45,-490),Vector3(13.3,1.45,-512),Vector3(-13.3,1.45,-629),
	Vector3(13.3,1.45,-650),Vector3(-13.3,1.45,-652)]
const VENT_COLS := 7
const VENT_ROWS := 15
const VENT_TILE := 3.0
const VENT_TOP := -525.5
const VENT_BOTTOM := -618.5
var vent_cells := {}  # raster Vector2i -> open passage
var vent_route: Array[Vector2i] = []

const ELECTRICAL_NAMES := ["Observation lighting","Coolant pumps","Engine service power","Habitat circuits","Navigation supply",
	"Life support","Coolant circulation","Airlock hydraulics","Emergency lighting","Auxiliary reactor"]
const ELECTRICAL_HINTS := ["The lamp ballast hums behind the panel.","Cold coolant pipes run into this cabinet.",
	"Thick power cables disappear toward the engines.","The cabin supply is steady, but the breaker is raised.",
	"A navigation display blinks beside a raised isolator.","A cracked oxygen regulator spits sparks.",
	"The pump contactor is scorched and stuck open.","The airlock pressure circuit has lost power.",
	"A melted fuse keeps the emergency lights failing.","The reserve supply is disconnected behind a damaged contactor."]
var paths: Array[Dictionary] = []
var puzzles: Array[TheoryPuzzle] = []
var seed_value: int

func _init(value: int) -> void:
	seed_value = value
	_build_vent_maze()
	var points := PackedVector3Array()
	var rolls := PackedFloat32Array()
	for i in 13:
		points.append(Vector3(0,0,SHIP_A_END-i*3.0))
		rolls.append(0.0)
	for i in range(1,157):
		var t := float(i)/156.0
		# Settle position, tangent and roll before meeting the wreck's flat sill.
		var docking := 1.0-smoothstep(0.86,0.96,t)
		points.append(Vector3(62.0*sin(TAU*t)*docking,28.0*(1.0-cos(TAU*t))*docking, -148.0-332.0*t))
		rolls.append(lerpf(TAU,TAU*t+0.22*sin(TAU*t*3.0),docking))
	_add_path(points,rolls,0)
	points = PackedVector3Array()
	rolls = PackedFloat32Array()
	for i in 193:
		var t := float(i)/192.0
		var envelope := sin(PI*t)*smoothstep(0.025,0.10,t)*(1.0-smoothstep(0.90,0.98,t))
		points.append(Vector3(sin(TAU*t*1.5)*76.0*envelope,24.0*sin(TAU*t*2.0)*envelope,SHIP_B_END-404.0*t))
		rolls.append(TAU*1.5*envelope*sin(PI*t*1.5))
	for i in range(1,11):
		var t := float(i)/10.0
		var y := (3*t*t-2*t*t*t)*3.456-(t*t*t-t*t)*8.064+0.72*smoothstep(0.55,0.8,t)
		points.append(Vector3(0,y,-1068-i*2.8))
		rolls.append(0.0)
	_add_path(points,rolls,1)
	# Both former floor puzzles are now uninterrupted transit routes.

static func electrical_frame(index: int) -> Transform3D:
	var at: Vector3 = ELECTRICAL_POSITIONS[index]
	return Transform3D(Basis(Vector3.UP,-signf(at.x)*PI*0.5),at)

static func aurora_box_bay(row: int,side: float) -> bool:
	return row in [1,3,5,7,9] and side==(-1.0 if ((row-1)/2 as int)%2==0 else 1.0)

func puzzle_by_id(id: int) -> TheoryPuzzle:
	for puzzle: TheoryPuzzle in puzzles:
		if puzzle.id==id: return puzzle
	return null

func _add_path(points: PackedVector3Array,rolls: PackedFloat32Array,zone: int) -> void:
	var frames: Array[Transform3D] = []
	var length := 0.0
	for i in points.size():
		var forward := (points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var up := Vector3.UP.slide(forward).normalized().rotated(forward,rolls[i])
		frames.append(Transform3D(Basis(forward.cross(up).normalized(),up,-forward),points[i]))
		if i>0: length += points[i].distance_to(points[i-1])
	paths.append({points=points,frames=frames,zone=zone,length=length})

func frame_on_path(index: int,weight: float) -> Transform3D:
	var frames: Array = paths[index].frames
	var at := clampf(weight,0.0,1.0)*(frames.size()-1)
	var i := mini(floori(at),frames.size()-2)
	return (frames[i] as Transform3D).interpolate_with(frames[i+1],at-i)

func sample(position: Vector3) -> Dictionary:
	# The observation vessel has two decks; hostile ships and vents share a flat floor.
	if position.z>SHIP_A_END-0.2:
		return {frame=Transform3D(Basis.IDENTITY,Vector3(position.x,ship_floor(position,false),position.z)),zone="ship",distance=0.0}
	if position.z<SHIP_B_START+0.2 and position.z>SHIP_B_END-0.2:
		return {frame=Transform3D(Basis.IDENTITY,Vector3(position.x,0,position.z)),zone="wreck",distance=0.0}
	if position.z<-1068.0:
		var local := position-ARENA
		var radius := Vector2(local.x,local.z).length()
		if radius<30.0:
			var up := Vector3(-local.x*0.012,1.0,-local.z*0.012).normalized()
			var right := Vector3.RIGHT.slide(up).normalized()
			return {frame=Transform3D(Basis(right,up,right.cross(up)),Vector3(position.x,radius*radius*0.006,position.z)),zone="arena",distance=0.0}
	for puzzle: TheoryPuzzle in puzzles:
		if puzzle.id==2: continue
		var local := puzzle.frame.affine_inverse()*position
		if absf(local.x)<10.0 and absf(local.z)<11.0 and absf(local.y)<5.0:
			return {frame=Transform3D(puzzle.frame.basis,puzzle.frame*Vector3(local.x,0,local.z)),zone="space",distance=absf(local.y)}
	# Both paths run steadily toward -Z, so a segment's z gap is a lower bound on its
	# distance: start at the segment level with the position and walk outward.
	var best := INF
	var chosen := -1
	var segment := 0
	for path_index in paths.size():
		var points: PackedVector3Array = paths[path_index].points
		var count := points.size()-1
		var lo := 0
		var hi := count
		while lo<hi:
			var mid := (lo+hi)/2
			if points[mid+1].z>position.z: lo = mid+1
			else: hi = mid
		var start := mini(lo,count-1)
		for step: int in [-1,1]:
			var i := start if step==1 else start-1
			while i>=0 and i<count:
				var gap := maxf(0.0,maxf(points[i+1].z-position.z,position.z-points[i].z))
				if gap*gap>=best: break
				var d := Geometry3D.get_closest_point_to_segment(position,points[i],points[i+1]).distance_squared_to(position)
				if d<best:
					best = d
					chosen = path_index
					segment = i
				i += step
	var frame := Transform3D.IDENTITY
	if chosen>=0:
		var path: Dictionary = paths[chosen]
		var a: Vector3 = path.points[segment]
		var b: Vector3 = path.points[segment+1]
		var point := Geometry3D.get_closest_point_to_segment(position,a,b)
		frame = (path.frames[segment] as Transform3D).interpolate_with(path.frames[segment+1],a.distance_to(point)/maxf(0.001,a.distance_to(b)))
		frame.origin = point
	return {frame=frame,zone="fracture" if chosen==1 else "space",distance=sqrt(best)}

static func ship_floor(position: Vector3,wreck: bool) -> float:
	# Two staircases in each hull. The upper floor only captures characters
	# already on it; walking underneath it remains on the lower deck.
	var start := -552.0 if wreck else -38.0
	if position.x>20.0 and position.z<start and position.z>start-20.0:
		return clampf((start-position.z)*0.4,0.0,8.0)
	if position.x<-20.0 and position.z<start-38.0 and position.z>start-58.0:
		return clampf((position.z-(start-58.0))*0.4,0.0,8.0)
	return 8.0 if position.y>6.0 else 0.0

func validate_position(position: Vector3) -> bool:
	if not position.is_finite(): return false
	var state := sample(position)
	if state.zone=="ship": return absf(position.x)<34.0 and position.y>-3.0 and position.y<23.0
	if state.zone=="wreck":
		if position.z<VENT_TOP and position.z>VENT_BOTTOM:
			return vent_open(position) and position.y>-1.0 and position.y<3.0
		return absf(position.x)<14.5 and position.y>-1.0 and position.y<6.1
	if state.zone=="arena": return position.distance_to(ARENA)<38.0
	return state.distance<20.0

## Randomized depth-first carving creates a connected labyrinth with dead ends.
## There is exactly one traversable route between the two ships.
func _build_vent_maze() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5A17D
	var entry := Vector2i(VENT_COLS/2, 0)
	var visited := {entry: true}
	var stack: Array[Vector2i] = [entry]
	var parents := {}
	vent_cells[entry*2+Vector2i.ONE] = true
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var choices: Array[Vector2i] = []
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := current+direction
			if next.x>=0 and next.x<VENT_COLS and next.y>=0 and next.y<VENT_ROWS and not visited.has(next): choices.append(next)
		if choices.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = choices[rng.randi_range(0, choices.size()-1)]
		visited[next] = true
		parents[next] = current
		vent_cells[current+next+Vector2i.ONE] = true
		vent_cells[next*2+Vector2i.ONE] = true
		stack.append(next)
	vent_cells[Vector2i(VENT_COLS, 0)] = true
	vent_cells[Vector2i(VENT_COLS, VENT_ROWS*2)] = true
	var cursor := Vector2i(VENT_COLS/2, VENT_ROWS-1)
	while true:
		vent_route.push_front(cursor*2+Vector2i.ONE)
		if cursor==entry: break
		cursor = parents[cursor]

static func vent_point(cell: Vector2i) -> Vector3:
	return Vector3((cell.x-VENT_COLS)*VENT_TILE, 0, -527.0-cell.y*VENT_TILE)

func vent_open(at: Vector3) -> bool:
	var cell := Vector2i(roundi(at.x/VENT_TILE)+VENT_COLS, roundi((-527.0-at.z)/VENT_TILE))
	return vent_cells.has(cell)

func nearest_vent(at: Vector3) -> Vector3:
	var nearest := Vector3.ZERO
	var distance := INF
	for cell: Vector2i in vent_cells:
		var point := vent_point(cell)
		var d := point.distance_squared_to(at)
		if d<distance:
			distance = d
			nearest = point
	return nearest
