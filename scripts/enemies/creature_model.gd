class_name CreatureModel
extends Node3D
## A voxel creature put together from creatures/<name>/ (body and limb .vox
## parts plus rig.json with the pivots). Gives every creature a waddling
## walk, an attack pose, a hit squash, and its own voxels for death bursts.
## It can also lose voxels off its outer shell as it takes damage.
##
## Each limb moves by its role (see tools/make_creatures.py): legs swing with
## the stride, arms swing against them (the throwing arm raises to attack),
## claws snap and lift, a tail cocks back while winding up and strikes
## forward when it fires, wings flap and dragon tails sway. Floating
## creatures hover and bob (some spin), glowing colors are drawn with the
## glow material, and bosses can switch to another look (set_variant) and
## light up (set_glow).
##
## Long tails (role "tail_chain", one limb per segment, each parented to the
## previous) are simulated: every segment springs toward a travelling wave,
## keeps some of its heading when the body turns so the tail drags and whips
## round, curls up over the back while winding up and lashes when it fires.
##
## Voxel lists (for death bursts and shedding) are only built when needed;
## big creatures (bosses) burst from points on their surface instead.

const STRIDE_SPEED := 14.0
const STRIDE_ANGLE := deg_to_rad(38.0)
const BOUNCE := 0.08
const ATTACK_TIME := 0.3
const STRIKE_TIME := 0.4
const TAIL_COCK := deg_to_rad(22.0)  # leans back while winding up
const TAIL_STRIKE := deg_to_rad(-30.0)  # whips forward when it fires
const GLITCH_TIME := 0.4
const GLITCH_COLOR_CHANCE := 0.25
const GLITCH_COLORS := [Color(0.2, 1.0, 1.0), Color(1.0, 0.2, 0.9), Color(1.0, 0.95, 0.2), Color(0.4, 1.0, 0.3)]
const NEIGHBORS: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]
const WING_IDLE := deg_to_rad(22.0)
const WING_FLAP := deg_to_rad(50.0)
const FLAP_TIME := 0.8
const TAIL_SWAY := deg_to_rad(12.0)
const BIG_VOXELS := 20000  # parts bigger than this burst from their surface

## name -> {rig, meshes: {part: [base Mesh or null, glow Mesh or null]},
## voxels: {part: [idx, colors]} (built when first needed),
## buffers: {part: [buf, palette]}}
static var _cache := {}
static var _glitch_palette: VoxelColorPalette
static var _glitch_material: ShaderMaterial

var creature := ""
var _rig: Node3D
var _limbs := {}  # "arm_l" -> pivot Node3D
var _moves: Array[Dictionary] = []  # {node, role, phase, axis, amount, yaw, throws}
var _chain: Array[Dictionary] = []  # tail_chain segments, root first: {node, t, yaw, pitch, yaw_v, pitch_v}
var _chain_heading := NAN
var _hand_limb: Node3D
var _waddle := 1.0
var _time := 0.0
var _windup := 0.0
var _windup_total := 0.0
var _strike := 0.0
var _parts: Array[MeshInstance3D] = []  # every mesh (base and glowing)
var _holders := {}  # part holder Node3D -> part name it shows
var _hover := 0.0
var _bob := 0.0
var _spin := 0.0
var _flap_rate := 8.0
var _flap := 0.0
var _glow_boost := 0.0
var _voxel_size := 0.1125
var _hand := Vector3.ZERO
var _phase := randf() * TAU
var _attack := 0.0
var _squash := 0.0
var _last_voxel_hit := -1000
var _hurt_arrays := {}
var _tyrant_animation := false
var _scarab_animation := false
var _pose_style := ""  # "dragon", "wraith", "prism": boss pose sets below
var _pose_rotations := {}
var _pose_sink := 0.0
var _halo_angle := 0.0
var _scarab_rotations := {}
var _scarab_sink := 0.0
var _boss_pose_name := "idle"
var _boss_pose_left := 0.0
var _boss_pose_duration := 1.0
var _tyrant_rotations := {}
var _tyrant_kneel := 0.0
var _live := {}  # part MeshInstance3D -> its own VoxelBuffer, once it has lost voxels
## Server: func(method: StringName, args: Array), told about every call that
## changes the look (flap, attacks, flinch, variant, shedding) so clients
## can replay it on their copy (see Net).
var recorder := Callable()


func _init(p_creature: String) -> void:
	creature = p_creature


func _ready() -> void:
	var data := _load(creature)
	var rig: Dictionary = data.rig
	_voxel_size = rig.voxel_size
	_hand = _vec(rig.hand) * _voxel_size
	_waddle = rig.get("waddle", 1.0)
	_hover = rig.get("hover", 0.0)
	_bob = rig.get("bob", 0.0)
	_spin = rig.get("spin", 0.0)
	_flap_rate = rig.get("flap_rate", 8.0)
	_tyrant_animation = rig.get("animation_style","") in ["tyrant", "knight"]
	_scarab_animation = rig.get("animation_style","")=="scarab"
	_pose_style = rig.get("animation_style","")
	_rig = Node3D.new()
	add_child(_rig)
	_add_part(_rig, data, "body")
	for limb in rig.limbs:
		var spec: Dictionary = rig.limbs[limb]
		var pivot := Node3D.new()
		pivot.position = _vec(spec.pivot) * _voxel_size
		var parent: Node3D = _limbs.get(spec.get("parent_limb",""),_rig)
		parent.add_child(pivot)
		_add_part(pivot, data, spec.part)
		_limbs[limb] = pivot
		_moves.append(_move_for(limb, spec, pivot))
	_hand_limb = _limbs.get(rig.get("hand_limb", ""))
	var segments := _moves.filter(func(m: Dictionary) -> bool: return m.role == "tail_chain")
	segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.segment < b.segment)
	for m in segments:
		_chain.append({node = m.node, t = float(m.segment) / maxf(1.0, m.segments - 1.0), yaw = 0.0, pitch = 0.0, yaw_v = 0.0, pitch_v = 0.0})


## How a limb moves; older rigs (goblins) get theirs from the limb name.
static func _move_for(limb: String, spec: Dictionary, pivot: Node3D) -> Dictionary:
	var role: String = spec.get("role", "leg" if limb.begins_with("leg") else "arm" if limb.begins_with("arm") else "")
	var right := limb.ends_with("_r")
	var yaw := deg_to_rad(spec.get("yaw", 0.0))
	pivot.rotation.y = yaw
	return {
		node = pivot, role = role, phase = spec.get("phase", -1.0 if right else 1.0),
		origin = pivot.position,
		axis = spec.get("axis", "x"), amount = spec.get("amount", 1.0), yaw = yaw,
		throws = spec.get("throws", role == "arm" and right),
		segment = int(spec.get("segment", 0)), segments = int(spec.get("segments", 1)),
	}


## move_ratio: 0 = standing still, 1 = full speed.
func animate(move_ratio: float, delta: float) -> void:
	_phase = fmod(_phase + delta * STRIDE_SPEED * clampf(move_ratio, 0.2, 1.0), TAU)
	var w := clampf(move_ratio, 0.0, 1.0)
	var stride := sin(_phase) * STRIDE_ANGLE * w
	_attack = maxf(0.0, _attack - delta)
	var raise := sin(_attack / ATTACK_TIME * PI)  # throw arm forward when attacking
	_time += delta
	_windup = maxf(0.0, _windup - delta)
	_strike = maxf(0.0, _strike - delta)
	for m in _moves:
		var node: Node3D = m.node
		match m.role:
			"leg":
				var swing: float = stride * m.phase * m.amount
				if m.axis == "y":
					node.rotation.y = m.yaw + swing
				else:
					node.rotation.x = swing
			"arm":
				var swing: float = -stride * 0.8 * m.phase
				node.rotation.x = lerpf(swing, deg_to_rad(110.0), raise) if m.throws else swing
			"claw":
				node.rotation.y = m.yaw + m.phase * deg_to_rad(6.0) * sin(_time * 3.0 + m.phase)
				node.rotation.x = stride * 0.2 - raise * deg_to_rad(25.0)
			"tail":
				node.rotation.x = _tail_angle()
			"wing":
				node.rotation.z = -m.phase * _wing_lift()
			"sway":
				node.rotation.y = sin(_time * 1.3) * TAIL_SWAY
	_squash = maxf(0.0, _squash - delta * 5.0)
	_flap = maxf(0.0, _flap - delta)
	var bob := absf(sin(_phase)) * BOUNCE * w * _waddle
	_rig.position.y = bob + _hover + sin(_time * 2.2) * _bob
	if _spin != 0.0:
		_rig.rotation.y += _spin * delta
	_rig.scale = Vector3(1.0 + _squash * 0.25, 1.0 - _squash * 0.3, 1.0 + _squash * 0.25)
	_rig.rotation.z = sin(_phase) * deg_to_rad(6.0) * w * _waddle
	if _tyrant_animation: _animate_tyrant(delta,w)
	elif _scarab_animation: _animate_scarab(delta,w)
	elif _pose_style=="goblin_king": _animate_goblin_king(delta,w)
	elif _pose_style=="dragon": _animate_dragon(delta,w)
	elif _pose_style=="wraith": _animate_wraith(delta)
	elif _pose_style=="prism": _animate_prism(delta)
	elif _pose_style=="serpent": _animate_serpent(w)
	elif _pose_style in ["cantor", "vizier", "warden", "death_knight", "xeno_queen"]: _animate_dungeon_boss(delta,w)
	if not _chain.is_empty(): _animate_tail_chain(delta, w)


## Floating coils stay compact; the neck leads a delayed head sway and bite.
## Uses the existing replicated windup/strike state, including remote mirrors.
func _animate_serpent(moving: float) -> void:
	var coil := clampf(1.0 - _windup / maxf(0.001, _windup_total), 0.0, 1.0) if _windup > 0.0 else 0.0
	var bite := sin((1.0 - _strike / STRIKE_TIME) * PI) if _strike > 0.0 else 0.0
	_rig.scale = Vector3.ONE
	_rig.rotation.x = sin(_time * 1.7 + _phase) * 0.025 - moving * 0.055
	_rig.rotation.z = sin(_time * 1.6 + _phase) * 0.045
	_rig.position.y += coil * 0.07 - bite * 0.08
	for m in _moves:
		var node: Node3D = m.node
		match m.role:
			"serpent_neck":
				node.rotation = Vector3(coil * 0.18 - bite * 0.26, sin(_time * 2.0 + _phase) * 0.08, sin(_time * 1.7 + _phase) * 0.07)
			"serpent_head":
				node.rotation = Vector3(-coil * 0.10 + bite * 0.16, -sin(_time * 2.0 + _phase - 0.55) * 0.10, -sin(_time * 1.7 + _phase - 0.4) * 0.06)
			"serpent_jaw":
				node.rotation.x = -0.06 - coil * 0.32 - bite * 0.20 - (sin(_time * 2.4) + 1.0) * 0.025


## Replicated attack poses for the heavy, planted Cinder Tyrant rig.
func boss_pose(pose: String, duration: float) -> void:
	if recorder.is_valid(): recorder.call(&"boss_pose",[pose,duration])
	_boss_pose_name = pose
	_boss_pose_duration = maxf(0.01,duration)
	_boss_pose_left = _boss_pose_duration


func uses_articulated_intro() -> bool:
	return _pose_style in ["cantor", "vizier", "warden", "death_knight"]


func _animate_tyrant(delta: float, moving: float) -> void:
	_boss_pose_left = maxf(0.0,_boss_pose_left-delta)
	var progress := 1.0-_boss_pose_left/_boss_pose_duration
	var gather := smoothstep(0.0,0.7,progress)
	var release := 1.0-smoothstep(0.15,1.0,progress)
	var pose := _boss_pose_name if _boss_pose_left>0.0 else "idle"
	if _pose_style == "knight" and pose == "idle":
		if _windup > 0.0: pose = "cleave_windup"
		elif _strike > 0.0: pose = "cleave_release"
	var left_arm := Vector3(0.12,0.0,-0.14)
	var right_arm := Vector3(0.24,0.0,0.12)
	var lean := 0.035
	var twist := 0.0
	var wing_spread := 0.12
	var kneeling := 0.0
	var sitting := 0.0
	var sprint := _time*12.0
	match pose:
		"sit":
			sitting = 1.0
			lean = -0.08
			left_arm.x = 0.55
			right_arm.x = 0.65
		"cast":
			right_arm = Vector3(0.9, -0.2, 0.18)
			left_arm.x = 0.45
			wing_spread = 0.22
		"summon":
			left_arm = Vector3(1.2*gather,0.0,-0.6*gather)
			right_arm = Vector3(1.2*gather,0.0,0.6*gather)
			lean = -0.07*gather
			wing_spread = 0.45*gather
		"cleave_windup":
			right_arm = Vector3(-0.65*gather,0.65*gather,0.35*gather)
			left_arm.x = 0.35
			twist = -0.13*gather
		"cleave_release":
			right_arm = Vector3(1.3*release,-0.6*release,0.1)
			twist = 0.15*release
			lean = 0.12*release
		"charge_windup":
			lean = 0.12*gather
			left_arm.x = -0.45*gather
			right_arm.x = -0.55*gather
			wing_spread = 0.35*gather
		"charge":
			lean = 0.22
			left_arm.x = -sin(sprint)*0.65
			right_arm.x = sin(sprint)*0.65
			twist = sin(sprint)*0.035
			wing_spread = -0.08
		"charge_recover":
			lean = 0.18*release
			right_arm.x = 0.6*release
		"slam_windup":
			left_arm.x = 2.25*gather
			right_arm.x = 2.25*gather
			lean = -0.1*gather
			wing_spread = 0.4*gather
		"slam_release":
			left_arm.x = 0.85*release
			right_arm.x = 0.85*release
			lean = 0.2*release
		"kneel", "defeated", "stagger", "death":
			kneeling = 1.0
			lean = 0.17
			left_arm = Vector3(0.5,-0.1,-0.2)
			right_arm = Vector3(0.85,0.1,0.08)
			wing_spread = -0.12
		"rise":
			kneeling = 1.0-smoothstep(0.0,0.9,progress)
			lean = 0.17*kneeling
			left_arm.x = 0.5*kneeling
			right_arm.x = 0.85*kneeling
			wing_spread = 0.12-0.24*kneeling
	# No elastic scaling, hopping or idle wing flapping. Limbs settle with weight.
	var blend := 1.0-exp(-delta*(18.0 if pose.ends_with("release") else 7.0))
	_rig.scale = Vector3.ONE
	_tyrant_kneel = lerpf(_tyrant_kneel,kneeling,blend)
	_rig.position.y = _hover-0.95*_tyrant_kneel-1.1*sitting+sin(_time*1.4)*0.008*(1.0-_tyrant_kneel)
	_rig.position.z = 0.15*_tyrant_kneel
	_rig.rotation = _rig.rotation.lerp(Vector3(lean,twist,0.0),blend)
	for m in _moves:
		var node: Node3D = m.node
		var rest := Vector3(0.0,m.yaw,0.0)
		match m.role:
			"arm": rest = right_arm if m.phase<0.0 else left_arm
			"wing": rest = Vector3(0.0,m.yaw,-m.phase*wing_spread)
			"leg":
				var stride: float = sin(sprint)*m.phase if pose=="charge" else sin(_phase)*m.phase
				rest.x = stride*(0.82 if pose=="charge" else 0.25)*moving
				rest.x = lerpf(rest.x,0.75 if m.phase>0.0 else -0.65,_tyrant_kneel)
				rest.x = lerpf(rest.x, -1.45, sitting)
			"knee":
				var stride: float = sin(sprint+0.65)*m.phase if pose=="charge" else sin(_phase+0.65)*m.phase
				rest.x = -maxf(0.0,stride)*(1.35 if pose=="charge" else 0.4)*moving
				rest.x = lerpf(rest.x,-1.05 if m.phase>0.0 else 1.45,_tyrant_kneel)
				rest.x = lerpf(rest.x, 1.5, sitting)
			"sway": rest.y += sin(_time*0.9)*0.04
		var previous: Vector3 = _tyrant_rotations.get(node,Vector3.ZERO)
		var current := previous.lerp(rest,blend)
		_tyrant_rotations[node] = current
		node.rotation = current


## The Scarab Regent's replicated poses: rearing throws, a low scuttling
## charge, wings flung open to expose its heart, and a collapse onto splayed legs.
func _animate_scarab(delta: float, moving: float) -> void:
	_boss_pose_left = maxf(0.0,_boss_pose_left-delta)
	var progress := 1.0-_boss_pose_left/_boss_pose_duration
	var gather := smoothstep(0.0,0.6,progress)
	var release := 1.0-smoothstep(0.2,1.0,progress)
	var pose := _boss_pose_name if _boss_pose_left>0.0 else "idle"
	var rear := 0.0  # + lifts the head, - drives it down
	var wings := 0.08+sin(_time*1.4)*0.04
	var splay := 0.0
	var sink := 0.0
	var scuttle := 0.18*moving
	var scuttle_rate := 7.0
	var roll := 0.0
	match pose:
		"throw":
			rear = 0.32*gather*release+0.1*(1.0-release)
			wings = 0.9*gather*release+0.15
			splay = 0.15*gather
		"cast":
			rear = 0.12*gather
			wings = 0.45*gather
		"summon":
			rear = 0.45*gather
			wings = 1.25*gather
			splay = 0.3*gather
			roll = sin(_time*9.0)*0.02*gather
		"ray":
			rear = 0.2
			wings = 1.05+sin(_time*6.0)*0.05
			splay = 0.25
			sink = 0.25
		"charge_windup":
			rear = -0.16*gather
			wings = -0.12*gather
			sink = 0.45*gather
			splay = 0.2*gather
		"charge":
			rear = -0.12
			wings = -0.15
			sink = 0.3
			scuttle = 0.55
			scuttle_rate = 22.0
			roll = sin(_time*22.0)*0.03
		"expose":
			rear = 0.38*gather
			wings = 1.35*gather
			splay = 0.35*gather
			sink = 0.2*gather
		"kneel", "defeated", "death":
			rear = -0.22
			wings = -0.3
			splay = 0.85
			sink = 1.0
			roll = 0.06 if pose=="defeated" else 0.0
		"rise":
			var down := 1.0-smoothstep(0.0,0.9,progress)
			rear = -0.22*down+0.25*sin(progress*PI)
			wings = -0.3*down+0.9*sin(progress*PI)
			splay = 0.85*down
			sink = down
	var blend := 1.0-exp(-delta*(16.0 if pose in ["throw","charge"] else 6.0))
	_rig.scale = Vector3.ONE
	_scarab_sink = lerpf(_scarab_sink,sink,blend)
	_rig.position.y = _hover-1.1*_scarab_sink+sin(_time*1.6)*0.03*(1.0-_scarab_sink)
	_rig.rotation = _rig.rotation.lerp(Vector3(rear,0.0,roll),blend)
	for m in _moves:
		var node: Node3D = m.node
		var rest := Vector3(0.0,m.yaw,0.0)
		var side := -1.0 if node.position.x<0.0 else 1.0
		match m.role:
			"leg":
				rest.y = m.yaw+sin(_time*scuttle_rate+m.phase*1.6)*m.phase*scuttle
				rest.z = side*splay*0.9
			"wing":
				rest.z = -m.phase*wings
		var previous: Vector3 = _scarab_rotations.get(node,node.rotation)
		var current := previous.lerp(rest,blend)
		_scarab_rotations[node] = current
		node.rotation = current


## [pose, progress 0..1, gather (eases in early), release (eases out late)].
func _pose_state(delta: float) -> Array:
	_boss_pose_left = maxf(0.0,_boss_pose_left-delta)
	var progress := 1.0-_boss_pose_left/_boss_pose_duration
	var pose := _boss_pose_name if _boss_pose_left>0.0 else "idle"
	return [pose,progress,smoothstep(0.0,0.6,progress),1.0-smoothstep(0.2,1.0,progress)]


## Eases the rig and every listed limb toward their targets.
func _settle(delta: float, fast: bool, lean: Vector3, sink: float, sink_depth: float, targets: Dictionary) -> void:
	var blend := 1.0-exp(-delta*(16.0 if fast else 6.0))
	_rig.scale = Vector3.ONE
	_pose_sink = lerpf(_pose_sink,sink,blend)
	_rig.position.y = _hover-sink_depth*_pose_sink+sin(_time*1.5)*_bob*(1.0-_pose_sink)
	_rig.rotation = _rig.rotation.lerp(lean,blend)
	for node: Node3D in targets:
		var previous: Vector3 = _pose_rotations.get(node,node.rotation)
		var current: Vector3 = previous.lerp(targets[node],blend)
		_pose_rotations[node] = current
		node.rotation = current


## The Blue Dragon: a crouched, mantled battle stance; wing beats sweep
## forward toward its target; rearing breath, roars, sweeps and a collapse.
## Forward is -Z: a positive lean here tips the head down (rig x = -lean);
## wing tips sweep forward with +yaw on their own side and pitch forward with -x.
func _animate_dragon(delta: float, _moving: float) -> void:
	var st := _pose_state(delta)
	var pose: String = st[0]
	var progress: float = st[1]
	var gather: float = st[2]
	var release: float = st[3]
	var lean := 0.1+sin(_time*1.3)*0.015
	var twist := 0.0
	var sink := 0.0  # legs are part of the body mesh: only collapses sink
	var raise := 0.2+sin(_time*1.3)*0.05  # wings half-mantled, spread and menacing
	var forward := 0.15
	var tail := sin(_time*1.1)*0.25
	match pose:
		"breath":
			lean = lerpf(-0.22*gather,0.28,smoothstep(0.55,0.75,progress))*(1.0 if progress<0.9 else release*4.0)
			raise = 0.6*gather
			forward = -0.2*gather
		"roar", "summon":
			lean = -0.3*gather
			raise = 1.15*gather
			forward = 0.0
			sink = 0.0
			tail = sin(_time*6.0)*0.4
		"sweep":
			twist = sin(progress*PI*2.0-PI*0.5)*0.4
			lean = 0.18
			raise = 0.55
		"dive":
			lean = 0.3*gather
			raise = -0.1
			forward = -0.5
		"kneel", "defeated", "death":
			lean = 0.32
			raise = -0.45
			forward = -0.25
			sink = 1.0
			tail = 0.0
		"rise":
			var down := 1.0-smoothstep(0.0,0.9,progress)
			lean = 0.32*down-0.2*sin(progress*PI)
			raise = -0.45*down+1.0*sin(progress*PI)
			sink = down
	if _flap>0.0:
		# The beat: wings lift and drive forward and down toward the target.
		var k := 1.0-_flap/FLAP_TIME
		var drive := smoothstep(0.3,0.7,k)*(1.0-smoothstep(0.75,1.0,k))
		# + raise closes the wings up over the back; - spreads them down and out.
		raise = lerpf(0.5,-0.75,drive)
		forward = lerpf(-0.25,0.8,drive)
		lean += 0.12*drive
	var targets := {}
	for m in _moves:
		var node: Node3D = m.node
		var side := -1.0 if node.position.x<0.0 else 1.0
		match m.role:
			"wing": targets[node] = Vector3(-forward*0.45,m.yaw+side*forward,-m.phase*raise)
			"sway": targets[node] = Vector3(0.0,m.yaw+tail,0.0)
	_settle(delta,_flap>0.0 or pose=="breath",Vector3(-lean,twist,0.0),sink,0.5,targets)


## The Hollow Crown: a floating monarch whose arms conduct its spells and
## whose halo turns faster as it channels.
## Dungeon sculpts have real backs, weapon grips, jaws and nested appendages.
## All action poses come from the existing replicated boss_pose stream; the
## low amplitude secondary motion follows the joints, never scales the voxels.
func _animate_dungeon_boss(delta: float, moving: float) -> void:
	var st := _pose_state(delta)
	var pose: String = st[0]
	var progress: float = st[1]
	var gather: float = st[2]
	var release: float = st[3]
	var knight := _pose_style == "death_knight"
	var furnace := _pose_style == "warden"
	if knight and pose == "idle":
		if _windup > 0.0: pose = "cleave_windup"
		elif _strike > 0.0: pose = "cleave_release"
	var left := Vector3(0.15,0.0,-0.12)
	var right := Vector3(0.1,0.0,0.08)
	var lean := Vector3(-0.025 if not knight else 0.025,0.0,0.0)
	var jaw := 0.04
	var flare := 0.0
	var sink := 0.0
	var sitting := 0.0
	var head_bow := 0.0
	var drive := moving
	match pose:
		"awaken":
			var unfold := smoothstep(0.1,0.75,progress)
			var cry := sin(smoothstep(0.2,0.95,progress)*PI)
			sink = (1.0-unfold)*(0.9 if knight else 0.65)
			left = Vector3(0.15+cry*1.3,0.0,-0.12-cry*0.25)
			right = Vector3(0.1+cry*0.4,0.0,0.08+cry*0.15)
			lean.x = (1.0-unfold)*0.16-cry*0.08
			head_bow = (1.0-unfold)*0.4-cry*0.15
			jaw = cry*0.4
			flare = cry*0.35
			sitting = 1.0-unfold if knight else 0.0
		"sit":
			sitting = 1.0
			sink = 0.9
			lean.x = 0.0
			left.x = 0.6
			right.x = 0.35
			head_bow = 0.16
		"rise":
			var down := 1.0-smoothstep(0.0,0.9,progress)
			sitting = down if knight else 0.0
			sink = down*0.9
			left.x = 0.6*down
			right.x = 0.35*down
			flare = sin(progress*PI)*0.25
			head_bow = 0.16*down
		"cast":
			left = Vector3(1.05*gather,-0.18,-0.3)
			right = Vector3(0.4*gather,-0.12,0.18)
			lean.x = -0.08*gather
			jaw = 0.22*gather
			flare = 0.2*gather
		"summon":
			left = Vector3(1.65*gather,-0.1,-0.45*gather)
			right = Vector3(0.65*gather,0.15,0.36*gather)
			lean.x = -0.13*gather
			jaw = 0.36*gather
			flare = 0.4*gather
		"channel":
			left = Vector3(0.5,-0.15,-0.65*gather)
			right = Vector3(0.22,0.1,0.35*gather)
			jaw = (0.32+sin(_time*5.0)*0.08)*gather
			flare = 0.3*gather
			head_bow = -0.14
		"slam_windup":
			left = Vector3(1.8*gather,0.0,-0.3)
			right = Vector3(-0.65*gather,-0.2,0.28)
			lean.x = -0.16*gather
			flare = 0.35*gather
			head_bow = -0.18*gather
		"slam_release":
			left = Vector3(0.8*release,0.0,-0.15)
			right = Vector3(0.85*release,0.1,0.13)
			lean.x = 0.18*release
			jaw = 0.4*release
			head_bow = 0.2*release
		"cleave_windup":
			right = Vector3(-0.75*gather,-0.6*gather,0.18)
			left.x = 0.45
			lean = Vector3(-0.04,-0.15*gather,0.0)
			flare = 0.28*gather
		"cleave_release":
			right = Vector3(1.25*release,0.5*release,0.12)
			lean = Vector3(0.12*release,0.16*release,0.0)
			left.x = 0.35
			flare = 0.45*release
		"charge_windup":
			lean.x = 0.16*gather
			left.x = -0.4*gather
			right.x = -0.35*gather
			sink = 0.16*gather
			flare = 0.3*gather
		"charge":
			drive = 1.0
			lean.x = 0.2
			left.x = -0.4
			right.x = -0.25
			flare = 0.5
			jaw = 0.3
		"charge_recover":
			lean.x = 0.13*release
			sink = 0.18*release
			flare = 0.15
		"kneel", "defeated", "stagger", "death":
			sink = 1.0
			left = Vector3(0.25,0.0,-0.08)
			right = Vector3(0.5,0.0,0.08)
			lean.x = 0.24
			head_bow = 0.4
			jaw = 0.2
			drive = 0.0
	var targets := {}
	var gait := _time*11.0 if pose == "charge" else _phase
	for m in _moves:
		var node: Node3D = m.node
		var rest := Vector3(0.0,m.yaw,0.0)
		if m.role == "tail_chain": continue
		match m.role:
			"arm":
				rest = left if m.phase>0.0 else right
				if pose == "idle": rest.x -= sin(gait)*m.phase*drive*0.18
			"head":
				rest = Vector3(head_bow,sin(_time*0.7)*0.035*(1.0-sink),0.0)
			"jaw": rest.x = -jaw
			"hood": rest = Vector3(-flare*0.1,sin(_time*0.65)*0.045,0.0)
			"carapace": rest.x = -flare*0.15+sin(_time*1.4)*0.012
			"leg":
				rest.x = sin(gait)*m.phase*drive*(0.36 if furnace else 0.3)
				rest.x = lerpf(rest.x,0.7 if m.phase>0.0 else -0.65,sink*(1.0-sitting))
				# +X raises a downward thigh toward -Z, the model's front.
				rest.x = lerpf(rest.x,1.15,sitting)
			"knee":
				rest.x = -maxf(0.0,sin(gait+0.6)*m.phase)*drive*0.5
				rest.x = lerpf(rest.x,-0.8 if m.phase>0.0 else 1.1,sink*(1.0-sitting))
				rest.x = lerpf(rest.x,-1.15,sitting)
			"tail", "tail_tip":
				var tip: bool = m.role == "tail_tip"
				var weight := 0.55 if furnace else 1.0
				rest.y += sin(_time*1.15+(1.1 if tip else 0.0)+m.phase)*0.1*weight*(1.0-sink)
				rest.x = sin(_time*1.05+(1.5 if tip else 0.0))*0.04+flare*0.12
			"cape":
				rest.x = 0.08+sin(_time*1.6+m.phase)*0.035+drive*0.2+flare*0.5
				rest.z = -m.phase*(0.04+flare*0.25)
				rest.x *= 1.0-sitting*0.8
				# Fold the cloak forward of the backrest instead of through it.
				rest.x += sitting*0.25
				node.position = node.position.lerp(m.origin+Vector3(0,0,-0.3*sitting),1.0-exp(-delta*6.0))
			"cloth":
				rest = Vector3(sin(_time*1.3+m.phase)*0.045+drive*0.12+flare*0.2,0.0,-m.phase*0.04)
				rest.x = lerpf(rest.x,1.15,sitting)
		targets[node] = rest
	_settle(delta,pose.ends_with("release"),lean,sink,1.2 if knight else 0.8,targets)


func _animate_wraith(delta: float) -> void:
	var st := _pose_state(delta)
	var pose: String = st[0]
	var progress: float = st[1]
	var gather: float = st[2]
	var raise := 0.25  # arms forward
	var spread := 0.15  # arms outward
	var lean := 0.0
	var sink := 0.0
	var halo := 0.6
	match pose:
		"cast":
			raise = 1.4*gather
			spread = 0.1
			lean = 0.08*gather
			halo = 2.5
		"summon":
			raise = 2.6*gather
			spread = 0.7*gather
			lean = -0.15*gather
			halo = 4.0
		"channel":
			raise = 0.3
			spread = 1.35*gather
			lean = -0.08
			halo = 7.0
		"implode":
			raise = lerpf(0.4,1.6,smoothstep(0.5,0.8,progress))
			spread = lerpf(1.4,-0.35,smoothstep(0.5,0.8,progress))
			lean = 0.15*smoothstep(0.5,0.8,progress)
			halo = 9.0
		"vanish":
			raise = 1.0
			spread = -0.5*gather
			lean = 0.1
			halo = 6.0
		"kneel", "defeated", "death":
			raise = -0.25
			spread = 0.05
			lean = 0.4
			sink = 1.0
			halo = 0.2
		"rise":
			var down := 1.0-smoothstep(0.0,0.9,progress)
			raise = -0.25*down+2.2*sin(progress*PI)
			spread = 0.6*sin(progress*PI)
			lean = 0.4*down
			sink = down
			halo = 5.0
	_halo_angle = wrapf(_halo_angle+halo*delta,0.0,TAU)
	var targets := {}
	for m in _moves:
		var node: Node3D = m.node
		var side := -1.0 if node.position.x<0.0 else 1.0
		if m.role=="arm":
			targets[node] = Vector3(raise,m.yaw,side*spread)
		elif m.role=="":
			node.rotation.y = m.yaw+_halo_angle
	_settle(delta,pose=="implode",Vector3(-lean,0.0,0.0),sink,0.9,targets)


## The Rimeheart Prism: its six petals open to cast, fan wide for the
## storm, and fall slack when it is stunned or broken.
func _animate_prism(delta: float) -> void:
	var st := _pose_state(delta)
	var pose: String = st[0]
	var progress: float = st[1]
	var gather: float = st[2]
	var release: float = st[3]
	var open := 0.08+sin(_time*1.6)*0.05
	var sink := 0.0
	var wobble := 0.0
	match pose:
		"cast": open = 0.15+0.4*gather*release
		"bloom": open = 0.95*gather
		"storm": open = 0.6+sin(_time*12.0)*0.06
		"summon":
			open = 0.75*gather
			wobble = 0.15*gather
		"kneel", "stun":
			open = 1.15
			sink = 0.8
			wobble = 0.05
		"defeated", "death":
			open = 1.45
			sink = 1.0
		"rise":
			var down := 1.0-smoothstep(0.0,0.9,progress)
			open = 1.15*down+0.5*sin(progress*PI)
			sink = 0.8*down
	var targets := {}
	var i := 0
	for m in _moves:
		var node: Node3D = m.node
		if m.role=="":
			targets[node] = Vector3(open+sin(_time*5.0+i)*wobble,m.yaw,0.0)
			i += 1
	_settle(delta,false,Vector3.ZERO,sink,1.2,targets)


## Sways gently, leans back while winding up, then whips forward and eases back.
## Root segments are stiff and follow quickly; the tip is loose and lags,
## which gives the whip. Angles are local to the parent segment.
func _animate_tail_chain(delta: float, moving: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	var forward := global_basis.z
	var heading := atan2(forward.x, forward.z)
	var turned := 0.0 if is_nan(_chain_heading) else wrapf(heading - _chain_heading, -PI, PI)
	_chain_heading = heading
	var limp := _boss_pose_name in ["death", "defeated", "kneel", "stagger"] and _boss_pose_left > 0.0
	var coil := 0.0  # 0 rest, 1 raised over the back
	if _windup > 0.0 and _windup_total > 0.0: coil = smoothstep(0.0, 1.0, 1.0 - _windup / _windup_total)
	var lash := 0.0
	if _strike > 0.0: lash = sin((1.0 - _strike / STRIKE_TIME) * PI)
	var rate := lerpf(1.5, 4.2, moving)
	var sway := lerpf(0.16, 0.09, moving) * (1.0 - coil * 0.6)
	# Rotation of the parent this frame, in the world: a segment keeps most of
	# its old heading, then its spring pulls it back in line.
	var carried := turned
	for s in _chain:
		var t: float = s.t
		var before: float = s.yaw
		s.yaw -= carried * lerpf(0.55, 0.85, t)
		var wave := sin(_time * rate - t * 4.2 + _phase) * sway * (0.35 + t)
		var yaw_target := 0.0 if limp else wave + lash * sin(_time * 9.0) * 0.25 * t
		# Rest: droops from the body and curls back up toward the tip.
		var pitch_target := lerpf(0.32, -0.16, t) - moving * 0.12
		pitch_target = lerpf(pitch_target, lerpf(-0.75, -0.32, t), coil)
		pitch_target = lerpf(pitch_target, lerpf(-0.2, 0.55, t), lash)
		if limp: pitch_target = 0.18
		var stiff := lerpf(90.0, 30.0, t)
		var damp := lerpf(14.0, 4.5, t)
		s.yaw_v += ((yaw_target - s.yaw) * stiff - s.yaw_v * damp) * dt
		s.pitch_v += ((pitch_target - s.pitch) * stiff - s.pitch_v * damp) * dt
		s.yaw = clampf(s.yaw + s.yaw_v * dt, -0.95, 0.95)
		s.pitch = clampf(s.pitch + s.pitch_v * dt, -1.1, 1.0)
		carried += s.yaw - before
		var node: Node3D = s.node
		node.rotation = Vector3(s.pitch, s.yaw, 0.0)


func _tail_angle() -> float:
	var sway := sin(_time * 1.7) * deg_to_rad(4.0)
	if _strike > 0.0:
		var k := 1.0 - _strike / STRIKE_TIME
		var forward := k / 0.2 if k < 0.2 else 1.0 - (k - 0.2) / 0.8
		return sway + TAIL_COCK * maxf(0.0, 1.0 - k / 0.2) + TAIL_STRIKE * forward
	if _windup > 0.0 and _windup_total > 0.0:
		return sway + TAIL_COCK * (1.0 - _windup / _windup_total)
	return sway


## Wings beat slowly while hovering; a big flap (flap()) sweeps them down
## hard and back up.
func _wing_lift() -> float:
	var lift := sin(_time * _flap_rate) * WING_IDLE
	if _flap > 0.0:
		var k := 1.0 - _flap / FLAP_TIME
		lift += sin(k * TAU) * WING_FLAP * -1.0 + (1.0 - k) * WING_FLAP * 0.3
	return lift


## One mighty wing beat.
func flap() -> void:
	if recorder.is_valid(): recorder.call(&"flap", [])
	_flap = FLAP_TIME


## Starts an attack that fires after `windup` seconds (see strike()).
func play_attack(windup := 0.0) -> void:
	if recorder.is_valid(): recorder.call(&"play_attack", [windup])
	_attack = ATTACK_TIME
	_windup = windup
	_windup_total = windup


## The moment an attack fires (whips the tail forward).
func strike() -> void:
	if recorder.is_valid(): recorder.call(&"strike", [])
	_strike = STRIKE_TIME
	_windup = 0.0


## A quick squash when hit.
func flinch() -> void:
	if recorder.is_valid(): recorder.call(&"flinch", [])
	_squash = 1.0


## Boss hurt feedback: reuse the existing white/color glitch and flying voxels,
## without scaling the figure or permanently eroding its high-resolution mesh.
func hit_voxels(at := Vector3.INF, direction := Vector3.ZERO) -> void:
	_squash = 0.0
	if is_instance_valid(_rig): _rig.scale = Vector3.ONE
	var now := Time.get_ticks_msec()
	if now-_last_voxel_hit<90: return
	_last_voxel_hit = now
	if recorder.is_valid(): recorder.call(&"hit_voxels",[at,direction])
	if Net.is_server(): return  # clients render their own bounded particle bursts
	var step := 8.0 if _load(creature).rig.get("pixel_art",false) else 1.0
	var impact := at if at!=Vector3.INF else global_position+Vector3.UP
	var candidates: Array[Dictionary] = []
	var seen := {}
	for mi: MeshInstance3D in _parts:
		if mi.mesh==null or mi.get_meta("glow",false) or not mi.is_visible_in_tree(): continue
		var id := mi.mesh.get_instance_id()
		if not _hurt_arrays.has(id): _hurt_arrays[id] = mi.mesh.surface_get_arrays(0)
		var arrays: Array = _hurt_arrays[id]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if vertices.is_empty(): continue
		for sample in 24:
			var index := randi_range(0,vertices.size()-1)
			var surface_point: Vector3 = vertices[index]
			if indices.size()>=3:
				var triangle := randi_range(0,int(indices.size()/3)-1)*3
				index = indices[triangle]
				# Sample inside a face so flashes never grow beyond silhouette edges.
				var u := sqrt(randf())
				var v := randf()
				surface_point = vertices[index]*(1.0-u)+vertices[indices[triangle+1]]*(u*(1.0-v))+vertices[indices[triangle+2]]*(u*v)
			var normal: Vector3 = normals[index] if index<normals.size() else Vector3.UP
			var cell: Vector3 = ((surface_point-normal*.5)/step).floor()*step+Vector3.ONE*step*.5
			var key := "%d/%s" % [mi.get_instance_id(),cell]
			if seen.has(key): continue
			seen[key] = true
			var point: Vector3 = mi.global_transform*cell
			candidates.append({node=mi,cell=cell,point=point,color=colors[index] if index<colors.size() else Color.WHITE,distance=point.distance_squared_to(impact)})
	if candidates.is_empty(): return
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.distance<b.distance)
	var points := PackedVector3Array()
	var palette := PackedColorArray()
	var patches := {}
	for i in mini(64,candidates.size()):
		var index: int = i if i<32 else randi_range(32,candidates.size()-1)
		var sample: Dictionary = candidates[index]
		points.append(sample.point)
		palette.append(sample.color)
		if i<24 or i%4==0:
			if not patches.has(sample.node): patches[sample.node] = []
			patches[sample.node].append(sample.cell)
	for mi: MeshInstance3D in patches:
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE*step
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = cube
		multi.instance_count = patches[mi].size()
		for i in multi.instance_count:
			multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,patches[mi][i]))
			multi.set_instance_color(i,Color.WHITE if randf()>GLITCH_COLOR_CHANCE else GLITCH_COLORS[randi()%GLITCH_COLORS.size()])
		var overlay := MultiMeshInstance3D.new()
		overlay.multimesh = multi
		overlay.material_override = _glitch_shader()
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(overlay)
		var tween := overlay.create_tween()
		tween.tween_method(func(fade: float) -> void: overlay.set_instance_shader_parameter("fade",fade),1.0,0.0,GLITCH_TIME)
		tween.tween_callback(overlay.queue_free)
	Debris.burst_flash(self,points,palette,clampf(voxel_size()*step*.5,.1,.24),points.size(),impact-direction*.2,global_position.y,.45)


## Where projectiles leave from (the throwing hand or the stinger), in world space.
func hand_position() -> Vector3:
	if _hand_limb:
		return _hand_limb.global_transform * _hand
	return global_transform * _hand


## The creature's voxels in world space, for death bursts: [positions, colors].
## Big creatures give points on their surface instead (up to `limit`).
func voxel_points(limit := 1500) -> Array:
	if is_big():
		return surface_points(limit)
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	var data := _load(creature)
	for mi in _parts:
		if mi.mesh == null:
			continue
		var vox: Array = _voxels_of(mi, data)
		var idx: PackedVector3Array = vox[0]
		var cols: PackedColorArray = vox[1]
		for i in idx.size():
			positions.append(mi.global_transform * (idx[i] + Vector3(0.5, 0.5, 0.5)))
			colors.append(cols[i])
	return [positions, colors]


## Removes `share` of the voxels on the outside of every part, flashes the
## voxels left exposed underneath, and returns the removed ones in world
## space for a debris burst: [positions, colors].
func shed_outer_voxels(share: float) -> Array:
	if recorder.is_valid(): recorder.call(&"shed_outer_voxels", [share])
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	var data := _load(creature)
	if is_big():
		return [positions, colors]  # far too many voxels to pick through
	for mi in _parts:
		if mi.get_meta("glow", false) or mi.mesh == null:
			continue  # only the solid shell breaks off
		var palette: VoxelColorPalette = data.buffers[mi.get_meta("part")][1]
		var buf := _live_buffer(mi, data)
		var outer := _outer_voxels(buf)
		var n := mini(int(round(outer.size() * share)), outer.size() - 1)
		if n <= 0:
			continue
		outer.shuffle()
		var removed := outer.slice(0, n)
		for v: Vector3i in removed:
			positions.append(mi.global_transform * (Vector3(v) + Vector3(0.5, 0.5, 0.5)))
			colors.append(palette.get_color(buf.get_voxel(v.x, v.y, v.z, VoxelBuffer.CHANNEL_COLOR)))
			buf.set_voxel(0, v.x, v.y, v.z, VoxelBuffer.CHANNEL_COLOR)
		mi.mesh = VoxModel.mesh_from_buffer(buf, palette)
		mi.set_instance_shader_parameter("glow_boost", _glow_boost)
		_glitch(mi, buf, removed)
	return [positions, colors]


## Solid voxels with at least one empty side.
func _outer_voxels(buf: VoxelBuffer) -> Array:
	var out := []
	var s := buf.get_size()
	for y in s.y:
		for z in s.z:
			for x in s.x:
				if buf.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR) == 0:
					continue
				for d in NEIGHBORS:
					if not _solid(buf, Vector3i(x, y, z) + d):
						out.append(Vector3i(x, y, z))
						break
	return out


func _solid(buf: VoxelBuffer, v: Vector3i) -> bool:
	var s := buf.get_size()
	if v.x < 0 or v.y < 0 or v.z < 0 or v.x >= s.x or v.y >= s.y or v.z >= s.z:
		return false
	return buf.get_voxel(v.x, v.y, v.z, VoxelBuffer.CHANNEL_COLOR) != 0


## Flashes the voxels next to the removed ones white (some colored), fading
## back to their own colors quickly.
func _glitch(mi: MeshInstance3D, buf: VoxelBuffer, removed: Array) -> void:
	var s := buf.get_size()
	var flash := VoxelBuffer.new()
	flash.create(s.x, s.y, s.z)
	var any := false
	for v: Vector3i in removed:
		for d in NEIGHBORS:
			var n := v + d
			if _solid(buf, n):
				var c := 1 if randf() > GLITCH_COLOR_CHANCE else 2 + randi() % GLITCH_COLORS.size()
				flash.set_voxel(c, n.x, n.y, n.z, VoxelBuffer.CHANNEL_COLOR)
				any = true
	if not any:
		return
	var overlay := MeshInstance3D.new()
	overlay.mesh = VoxModel.mesh_from_buffer(flash, _glitch_colors())
	overlay.material_override = _glitch_shader()
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(overlay)
	var tw := overlay.create_tween()
	tw.tween_method(func(f: float) -> void: overlay.set_instance_shader_parameter("fade", f), 1.0, 0.0, GLITCH_TIME)
	tw.tween_callback(overlay.queue_free)


## This part's own copy of its voxels (made the first time it loses some).
func _live_buffer(mi: MeshInstance3D, data: Dictionary) -> VoxelBuffer:
	if not _live.has(mi):
		var src: VoxelBuffer = data.buffers[mi.get_meta("part")][0]
		var s := src.get_size()
		var buf := VoxelBuffer.new()
		buf.create(s.x, s.y, s.z)
		buf.copy_channel_from(src, VoxelBuffer.CHANNEL_COLOR)
		_live[mi] = buf
	return _live[mi]


## A mesh's current voxels: [indices, colors].
func _voxels_of(mi: MeshInstance3D, data: Dictionary) -> Array:
	var key: String = mi.get_meta("part") + ("_glow" if mi.get_meta("glow", false) else "")
	if _live.has(mi):
		return _list_voxels(_live[mi], data.buffers[key][1])
	if not data.voxels.has(key):
		data.voxels[key] = _list_voxels(data.buffers[key][0], data.buffers[key][1])
	return data.voxels[key]


## Up to `count` points spread over the creature's surface (mesh corners),
## with their colors: [positions, colors].
func surface_points(count: int) -> Array:
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	var per := maxi(1, count / maxi(1, _parts.size()))
	for mi in _parts:
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var arrays := mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if verts.is_empty():
			continue
		var weight := clampi(per * verts.size() / 4000 + 1, 1, per * 3)
		for i in mini(weight, verts.size()):
			var k := randi() % verts.size()
			positions.append(mi.global_transform * verts[k])
			colors.append(cols[k] if k < cols.size() else Color.WHITE)
	return [positions, colors]


## Bosses: too many voxels to handle one by one.
func is_big() -> bool:
	var data := _load(creature)
	for key in data.buffers:
		var size: Vector3i = data.buffers[key][0].get_size()
		if size.x * size.y * size.z > BIG_VOXELS * 8:
			return true
	return false


## Switches parts to another look from the rig's "variants" (e.g. a boss's
## enraged form). "" goes back to the normal look.
func set_variant(variant: String) -> void:
	if recorder.is_valid(): recorder.call(&"set_variant", [variant])
	var data := _load(creature)
	var swaps: Dictionary = data.rig.get("variants", {}).get(variant, {})
	for holder: Node3D in _holders:
		var part: String = holder.get_meta("base_part")
		var show_part: String = swaps.get(part, part)
		if show_part == _holders[holder]:
			continue
		_holders[holder] = show_part
		_ensure_part(data, show_part)
		for mi: MeshInstance3D in holder.get_children():
			var glow: bool = mi.get_meta("glow", false)
			mi.mesh = data.meshes[show_part][1 if glow else 0]
			mi.visible = mi.mesh != null
			mi.set_meta("part", show_part)
			_live.erase(mi)


func glow() -> float:
	return _glow_boost


## Extra glow over the whole creature (0 = normal), e.g. a boss about to burst.
func set_glow(boost: float) -> void:
	if boost == _glow_boost:
		return
	_glow_boost = boost
	for mi in _parts:
		mi.set_instance_shader_parameter("glow_boost", boost)


static func _list_voxels(buf: VoxelBuffer, palette: VoxelColorPalette) -> Array:
	var idx := PackedVector3Array()
	var cols := PackedColorArray()
	var s := buf.get_size()
	for y in s.y:
		for z in s.z:
			for x in s.x:
				var v := buf.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR)
				if v != 0:
					idx.append(Vector3(x, y, z))
					cols.append(palette.get_color(v))
	return [idx, cols]


static func _glitch_colors() -> VoxelColorPalette:
	if _glitch_palette == null:
		_glitch_palette = VoxelColorPalette.new()
		_glitch_palette.set_color(1, Color.WHITE)
		for i in GLITCH_COLORS.size():
			_glitch_palette.set_color(2 + i, GLITCH_COLORS[i])
	return _glitch_palette


static func _glitch_shader() -> ShaderMaterial:
	if _glitch_material == null:
		_glitch_material = ShaderMaterial.new()
		_glitch_material.shader = preload("res://shaders/glitch_voxel.gdshader")
	return _glitch_material


func voxel_size() -> float:
	return _voxel_size * scale.x


## A part: its solid mesh and its glowing mesh, in a holder placed at the
## part's frame (variants of a part share its frame).
func _add_part(parent: Node3D, data: Dictionary, part: String) -> void:
	var holder := Node3D.new()
	holder.position = _vec(data.rig.parts[part].frame_min) * _voxel_size
	holder.scale = Vector3.ONE * _voxel_size
	holder.set_meta("base_part", part)
	parent.add_child(holder)
	_holders[holder] = part
	for glow in [false, true]:
		var mi := MeshInstance3D.new()
		mi.mesh = data.meshes[part][1 if glow else 0]
		mi.visible = mi.mesh != null
		mi.material_override = _part_material(data,glow)
		mi.set_meta("part", part)
		mi.set_meta("glow", glow)
		holder.add_child(mi)
		_parts.append(mi)


## Large pixel-art bosses keep clean 8-voxel color blocks and restrained glow.
static func _part_material(data: Dictionary, glow: bool) -> ShaderMaterial:
	if not data.rig.get("pixel_art",false):
		return VoxModel.glow_material() if glow else VoxModel.material()
	if not data.has("pixel_materials"):
		data.pixel_materials = []
		for emissive in [false,true]:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/voxel_model.gdshader")
			material.set_shader_parameter("jitter",float(data.rig.get("material_jitter",0.0)))
			material.set_shader_parameter("glow_strength",float(data.rig.get("glow_strength",1.1)) if emissive else 0.0)
			data.pixel_materials.append(material)
	return data.pixel_materials[1 if glow else 0]


static func _vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## Loads (once) a creature's rig and the meshes of its parts (variant parts
## load when first shown). Call during loading screens to avoid hitches.
static func preload_creature(p_creature: String, include_variants := false) -> void:
	var data := _load(p_creature)
	if include_variants:
		for variant in data.rig.get("variants",{}).values():
			for part in variant.values(): _ensure_part(data,str(part))


static func _load(p_creature: String) -> Dictionary:
	if _cache.has(p_creature):
		return _cache[p_creature]
	var dir := "res://creatures/%s/" % p_creature
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "rig.json"))
	var data := {rig = rig, meshes = {}, voxels = {}, buffers = {}, dir = dir}
	var variant_parts := []
	for variant in rig.get("variants", {}).values():
		variant_parts.append_array(variant.values())
	for part in rig.parts:
		if not part in variant_parts:
			_ensure_part(data, part)
	_cache[p_creature] = data
	return data


## Loads one part's meshes: [solid, glowing] (either may be null).
static func _ensure_part(data: Dictionary, part: String) -> void:
	if data.meshes.has(part):
		return
	var info: Dictionary = data.rig.parts[part]
	var meshes := [null, null]
	if info.get("solid", true):
		var loaded := VoxModel.load_vox(data.dir + part + ".vox")
		meshes[0] = VoxModel.mesh_from_buffer(loaded[0], loaded[1])
		data.buffers[part] = loaded
	if info.get("glow", false):
		var loaded := VoxModel.load_vox(data.dir + part + "_glow.vox")
		meshes[1] = VoxModel.mesh_from_buffer(loaded[0], loaded[1])
		data.buffers[part + "_glow"] = loaded
	data.meshes[part] = meshes


func _animate_goblin_king(delta: float, moving: float) -> void:
	var st := _pose_state(delta)
	var pose: String = st[0]
	var progress: float = st[1]
	var lift := 0.0
	var lean := 0.0
	var sink := 0.0
	match pose:
		"cast", "summon": lift = -1.5 * sin(progress * PI)
		"throw":
			lift = -2.2 * sin(progress * PI)
			lean = -0.18 * sin(progress * TAU)
		"pound":
			lift = -2.5 * sin(progress * PI)
			lean = 0.25 * smoothstep(0.65, 0.85, progress)
			if progress > 0.75: lift = 0.6
		"charge_windup": lean = -0.2; lift = -0.6
		"charge": lean = 0.28; lift = -0.9
		"kneel", "death", "defeated": sink = 0.7; lean = 0.25
		"rise": sink = 0.7 * (1.0 - progress)
	var targets := {}
	for m in _moves:
		var node: Node3D = m.node
		var swing: float = sin(_time * 6.0) * moving * 0.25 * m.phase
		targets[node] = Vector3(lift + swing if m.role == "arm" else swing, 0, -0.12 * m.phase if m.role == "arm" else 0.0)
	_settle(delta, pose == "pound", Vector3(lean, 0, sin(_time * 2.0) * 0.015), sink, 1.1, targets)
