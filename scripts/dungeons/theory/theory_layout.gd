class_name TheoryLayout
extends RefCounted
## Authored macro route; all local frames are shared by art, collision,
## gravity, puzzles, turrets and remote players. Forward is local -Z.
const SHIP_A_END := -112.0
const SHIP_B_START := -480.0
const SHIP_B_END := -664.0
const ARENA := Vector3(0,0,-1120)
const WIDTH := 12.0
# Wreck cabinets face the central passage from five open service bays.
const ELECTRICAL_POSITIONS := [Vector3(-6.45,1.45,-1.2),Vector3(6.45,1.45,-23.2),Vector3(-6.45,1.45,-45.2),
	Vector3(6.45,1.45,-67.2),Vector3(-6.45,1.45,-89.2),
	Vector3(-6.45,1.45,-485.5),Vector3(6.45,1.45,-518.5),Vector3(-6.45,1.45,-551.5),
	Vector3(6.45,1.45,-595.5),Vector3(-6.45,1.45,-639.5)]
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
		var envelope := sin(PI*t)
		points.append(Vector3(sin(TAU*t*1.5)*76.0*envelope,24.0*sin(TAU*t*2.0)*envelope,SHIP_B_END-404.0*t))
		rolls.append(TAU*1.5*sin(PI*t)*sin(PI*t*1.5))
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
	# Both ships have conventional gravity, with continuous stairs between decks.
	if position.z>SHIP_A_END-0.2:
		return {frame=Transform3D(Basis.IDENTITY,Vector3(position.x,ship_floor(position,false),position.z)),zone="ship",distance=0.0}
	if position.z<SHIP_B_START+0.2 and position.z>SHIP_B_END-0.2:
		return {frame=Transform3D(Basis.IDENTITY,Vector3(position.x,ship_floor(position,true),position.z)),zone="wreck",distance=0.0}
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
	var best := INF
	var frame := Transform3D.IDENTITY
	var chosen := 0
	for path_index in paths.size():
		var path: Dictionary = paths[path_index]
		var points: PackedVector3Array = path.points
		for i in points.size()-1:
			var point := Geometry3D.get_closest_point_to_segment(position,points[i],points[i+1])
			var d := point.distance_squared_to(position)
			if d>=best: continue
			best = d
			var t := points[i].distance_to(point)/maxf(0.001,points[i].distance_to(points[i+1]))
			frame = (path.frames[i] as Transform3D).interpolate_with(path.frames[i+1],t)
			frame.origin = point
			chosen = path_index
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
	if state.zone in ["ship","wreck"]: return absf(position.x)<34.0 and position.y>-3.0 and position.y<23.0
	if state.zone=="arena": return position.distance_to(ARENA)<38.0
	return state.distance<20.0
