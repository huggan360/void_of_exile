class_name TheoryPuzzle
extends RefCounted
## Generated physical puzzles. The seed determines clues AND solution;
## progression is evaluated by the server from actual player positions.
var id: int
var frame: Transform3D
var kind: String
var size := 6
var cell_size := 1.65
var sequence: Array[Vector2i] = []
var active_cells: Array[Vector2i] = []
var masks: Array[int] = []
var target := 0
var bits := 0
var solved := false
var progress := 0
var _players := {}
var _last := {}

func _init(index: int,seed_value: int,transform: Transform3D,type: String) -> void:
	id = index
	frame = transform
	kind = type
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match kind:
		"algorithm":
			var current := Vector2i(rng.randi_range(1,4),5)
			sequence.append(current)
			# A random monotone route cannot deadlock or generate an unsolvable board.
			while current.y>0:
				var shift := rng.randi_range(-1,1)
				if shift!=0 and current.x+shift>=0 and current.x+shift<size:
					current += Vector2i(shift,0)
					sequence.append(current)
				current += Vector2i(0,-1)
				sequence.append(current)
			active_cells = sequence.duplicate()
		"parity":
			size = 4
			active_cells = [Vector2i(0,3),Vector2i(3,3),Vector2i(0,0),Vector2i(3,0)]
			# Invertible triangular circuit, randomized through row operations.
			masks = [1,3,6,12]
			for i in 12:
				var a := rng.randi_range(0,3)
				var b := (a+rng.randi_range(1,3))%4
				masks[a] = masks[a]^masks[b]
			var solution := rng.randi_range(1,15)
			for i in 4:
				if (solution & (1<<i))!=0: target = target^masks[i]

func clue() -> String:
	match kind:
		"algorithm":
			var instructions: Array[String] = []
			for i in range(1,sequence.size()):
				var d := sequence[i]-sequence[i-1]
				instructions.append("N" if d.y<0 else "E" if d.x>0 else "W")
			return "PATHFINDER / Start %s%d. Follow the program one tile at a time: %s. North points toward the gate. A wrong tile resets your path." % [char(65+sequence[0].x),sequence[0].y+1,"  ".join(instructions)]
		"parity":
			var text := "PARITY ENGINE / Match target %s. A lit lamp is 1. Each plate flips the lamps in its circuit. " % binary(target)
			for i in 4: text += "%s flips %s. " % [char(65+i),binary(masks[i])]
			return text+"Step off a plate before pressing it again."
	return ""

static func binary(value: int) -> String:
	var result := ""
	for bit in range(3,-1,-1): result += "1" if (value & (1<<bit))!=0 else "0"
	return result

func cell_at(position: Vector3) -> Vector2i:
	var p := frame.affine_inverse()*position
	if absf(p.y)>1.8: return Vector2i(-1,-1)
	return Vector2i(floori(p.x/cell_size+size*0.5),floori(p.z/cell_size+size*0.5))

func step(player_id: int,position: Vector3) -> bool:
	if solved: return false
	var cell := cell_at(position)
	if _last.get(player_id,Vector2i(-999,-999))==cell: return false
	_last[player_id] = cell
	if cell.x<0 or cell.y<0 or cell.x>=size or cell.y>=size:
		if kind=="algorithm" and int(_players.get(player_id,0))>0:
			_players[player_id] = 0
			progress = 0
			return true
		return false
	if kind=="parity":
		var index := active_cells.find(cell)
		if index<0: return false
		bits = bits^masks[index]
		solved = bits==target
		return true
	var at := int(_players.get(player_id,0))
	if cell==sequence[at]: at += 1
	else: at = 1 if cell==sequence[0] else 0
	_players[player_id] = at
	progress = at
	solved = at>=sequence.size()
	return true

func state() -> Dictionary:
	return {id=id,solved=solved,progress=progress,bits=bits}

func apply(data: Dictionary) -> void:
	solved = bool(data.get("solved",false))
	progress = int(data.get("progress",0))
	bits = int(data.get("bits",0))
