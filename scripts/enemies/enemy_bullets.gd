class_name EnemyBullets
extends Node3D
## Every enemy projectile. Attacks (see EnemyDef.attacks) describe how they
## look and behave:
##   "pellet"  a small tumbling voxel (weak creatures)
##   "bolt"    a longer glowing shard
##   "orb"     a big glowing chunk (strong creatures)
##   "fireball" real voxel fire, like the game's campfires: a churning ball of
##             flame voxels cooling from white-hot through its color, leaving
##             a trail of rising, shrinking flames and bursting where it lands
## They fly straight, stop on terrain and obstacles, and hit any player they
## pass through. armor_piercing ignores defence (orange damage numbers);
## pierce_players keeps flying after a hit instead of stopping.
## Shots fired from above (a scorpion's stinger) drop to shot height over
## their first few meters. Magic shots are wrapped in warped space and, with
## a ripple, send out an EnemyRipple wherever they land.
##
## Boss attacks add (all optional):
##   radius      collision radius in meters (default 0.2 x size): the solid
##               core you see is what hits, glow and sparks are decoration
##   returns     meters out before a disc turns and flies back to where it was
##               thrown (not toward the player); a player can be hit once per
##               leg, at least RETURN_REHIT seconds apart
##   turn        radians per second the flight bends sideways: a constant
##               turn flies a loop of radius speed/turn (looping discs)
##   falling     keeps vertical flight, for falling branches instead of level shots
##   shared_hits an Array shared by every shot of one attack: whoever one
##               piece hits, the others skip
##   terminal    {delay, count, attack}: at the end of its flight it stops,
##               contracts for `delay` seconds, then releases `count` shots in
##               a ring; they skip whoever the parent already hit
## More styles: "needle" (thin blade), "disc" (spinning flat wheel), "crescent"
## (wide slab), "shard" (faceted crystal), "comet" (heavy pointed core).
## Boss art uses colored coarse voxel models and small matching trails.
## Optional half_extents gives a wide blade swept rectangular contact.
## Every shot remembers its source, so an encounter can retire its own shots
## (clear_from) the moment it dies or resets.

const PLAYER_RADIUS := 0.45
const PLAYER_HEIGHT := 1.7
const SETTLE_DISTANCE := 3.0  # shots from above reach shot height by here
const MAGIC_HALO := 0.5  # radius of the warped space around magic shots (x size)
const RETURN_REHIT := 0.6

## Players that can be hit: the local player. Online every client flies the
## enemies' shots itself and only checks its own player; the server sends
## each shot as an event instead of flying it (see Net).
var players: Array[Player] = []

static var _cleave_collision := {}

var _shots: Array[Dictionary] = []
var _meshes := {}  # "style/color" -> Mesh
var _halo_mesh: SphereMesh
var _halo_materials := {}  # color -> ShaderMaterial
var _fire_looks := {}  # "color/size" -> {core, trail, burst: ParticleProcessMaterial, voxel, ember: Mesh}


## shot_y: the height it flies at; shots starting above it drop down to it.
## owner / boss_id: online clients pass the server's owner id and the boss
## that fired it (their source is null).
func fire(origin: Vector3, direction: Vector3, attack: Dictionary, source: Node = null, shot_y := NAN, skip: Array = [],
		owner := 0, boss_id := "") -> void:
	if Net.is_server():
		Net.server.enemy_shot(self, origin, direction, attack, source, shot_y)
		return
	if source is Enemy and (source as Enemy).def is BossDef:
		attack = _boss_attack(attack,(source as Enemy).def.id)
	elif boss_id != "":
		attack = _boss_attack(attack, boss_id)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_for(attack)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = origin
	mi.look_at(origin + direction, Vector3.FORWARD if absf(direction.y) > 0.99 else Vector3.UP)
	var magic: bool = attack.get("magic", false)
	if magic:
		mi.add_child(_halo(attack.get("size", 1.0), attack.get("color", Color.WHITE)))
	var fireball: bool = attack.get("style", "") == "fireball"
	var trail: GPUParticles3D = null
	if attack.get("pixel_projectile",false):
		trail = _pixel_trail(attack)
		mi.add_child(trail)
	elif fireball:
		var flames := _fire_particles(attack)
		mi.add_child(flames[0])
		trail = flames[1]
		mi.add_child(trail)
	# A bounded set of real moving lights makes patrol fire illuminate the floor.
	if float(attack.get("light_energy",0))>0 and get_tree().get_nodes_in_group("enemy_projectile_lights").size()<12:
		var light := OmniLight3D.new()
		light.name = "ProjectileLight"
		light.add_to_group("enemy_projectile_lights")
		light.light_color = attack.get("color",Color(1,.6,.3))
		light.light_energy = clampf(float(attack.light_energy),0,2)
		light.omni_range = clampf(float(attack.get("light_range",3)),1,5)
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = .15
		mi.add_child(light)
	_shots.append({
		node = mi, pos = origin, dir = direction, speed = attack.get("speed", 10.0),
		start_y = origin.y, shot_y = origin.y if is_nan(shot_y) else shot_y,
		magic = magic, ripple = attack.get("ripple", {}), color = attack.get("color", Color.WHITE),
		travelled = 0.0, range = attack.get("range", 10.0),
		damage = randi_range(attack.get("damage_min", 5), attack.get("damage_max", 10)),
		armor_piercing = attack.get("armor_piercing", false),
		pierce = attack.get("pierce_players", false),
		# Pieces of one attack (a cleave's two crescents) can share one hit list.
		hit = attack.shared_hits if attack.has("shared_hits") else skip.duplicate(),
		radius = attack.get("radius", 0.2 * attack.get("size", 1.0)),
		spin = attack.get("style", "pellet")=="disc" if attack.get("pixel_projectile",false) else attack.get("style", "pellet") in ["pellet", "disc"] or magic,
		half_extents = attack.get("half_extents",Vector3.ZERO)*float(attack.get("size",1.0)),
		collision_boxes = attack.get("collision_boxes",[]),
		trail = trail, attack = attack, owner = owner if owner != 0 else _owner_id(source), origin = origin,
		returns = attack.get("returns", 0.0), turn = attack.get("turn", 0.0), returned = false, hit_at = {}, contract = -1.0,
		blocked = false, clashed_waves = [],
	})


## Colored, low-resolution shot silhouettes for all five live bosses.
## Decoration copies attack data, preserving shared hit arrays and combat tuning.
static func _boss_attack(original: Dictionary, boss_id: String) -> Dictionary:
	if original.get("authored_projectile",false): return original
	var theme: String = {"blue_dragon":"blue","rimeheart_prism":"ice","vharok":"fire","scarab_regent":"gold","hollow_crown":"void"}.get(boss_id,"")
	if theme=="": return original
	var attack := original.duplicate()
	var style: String = attack.get("style","bolt")
	var form := "orb" if style in ["orb","fireball","comet"] else "bolt"
	if theme=="gold" and style=="disc": form = "disc"
	if theme=="fire" and style in ["crescent","flame_shard"]:
		form = "cleave"
		if _cleave_collision.is_empty():
			_cleave_collision = JSON.parse_string(FileAccess.get_file_as_string("res://creatures/boss_projectiles/fire_cleave/rig.json"))
		attack.half_extents = _collision_vector(_cleave_collision.collision_half_extents)
		attack.collision_boxes = _cleave_collision.collision_boxes
		if style=="flame_shard":
			form = "shard"
			attack.half_extents *= 0.32
			var boxes: Array = []
			for box: Dictionary in _cleave_collision.collision_boxes:
				var offset := _collision_vector(box.offset)*0.32
				var half := _collision_vector(box.half)*0.32
				boxes.append({offset=[offset.x,offset.y,offset.z],half=[half.x,half.y,half.z]})
			attack.collision_boxes = boxes
	attack.voxel_model = "boss_projectiles/"+theme+"_"+form
	attack.pixel_projectile = true
	attack.projectile_glow = .85 if theme=="fire" else .65
	attack.color = {"blue":Color(.13,.58,.91),"ice":Color(.19,.72,.84),"fire":Color(.93,.22,.045),"gold":Color(.91,.57,.13),"void":Color(.65,.14,.68)}[theme]
	attack.fire_brightness = .9
	if form=="cleave":
		attack.light_energy = .65
		attack.light_range = 3.0
	if attack.has("terminal"):
		attack.terminal = attack.terminal.duplicate()
		attack.terminal.attack = _boss_attack(attack.terminal.attack,boss_id)
	return attack


func _pixel_trail(attack: Dictionary) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 35
	process.initial_velocity_min = .1
	process.initial_velocity_max = .4
	process.gravity = Vector3(0,.5,0)
	process.color = attack.get("color",Color(.3,.6,1))
	process.scale_min = .5
	process.scale_max = 1.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0,1))
	shrink.add_point(Vector2(1,0))
	var texture := CurveTexture.new()
	texture.curve = shrink
	process.scale_curve = texture
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE*.055*minf(float(attack.get("size",1.0)),1.5)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/fire_voxel.gdshader")
	material.set_shader_parameter("brightness",.9)
	cube.material = material
	var particles := GPUParticles3D.new()
	particles.process_material = process
	particles.draw_pass_1 = cube
	particles.amount = 12
	particles.lifetime = .3
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-4,-2,-4),Vector3(8,5,8))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## A broad blade uses its oriented rectangular silhouette for swept contact.
func _box_contact(center: Vector3, from: Vector3, to: Vector3, direction: Vector3, half: Vector3) -> float:
	var forward := Vector3(direction.x,0,direction.z).normalized()
	var right := forward.cross(Vector3.UP)
	var offset := from-center
	var motion := to-from
	var start := Vector3(offset.dot(right),offset.y,offset.dot(forward))
	var step := Vector3(motion.dot(right),motion.y,motion.dot(forward))
	var enter := 0.0
	var leave := 1.0
	for axis in 3:
		if absf(step[axis])<.000001:
			if absf(start[axis])>half[axis]: return -1.0
		else:
			var a := (-half[axis]-start[axis])/step[axis]
			var b := (half[axis]-start[axis])/step[axis]
			enter = maxf(enter,minf(a,b))
			leave = minf(leave,maxf(a,b))
			if enter>leave: return -1.0
	return enter


func _shot_shield_contact(player: Player, from: Vector3, to: Vector3, shot: Dictionary) -> float:
	if shot.half_extents==Vector3.ZERO: return _shield_contact(player,from,to,shot.radius)
	return _profile_contact(player.global_position+Vector3.UP*.95,from,to,shot,Vector3.ONE*MagicShield.RADIUS)


func _shot_hits_player(player: Player, from: Vector3, to: Vector3, shot: Dictionary) -> bool:
	if shot.half_extents==Vector3.ZERO: return _hits_player(player,from,to,shot.radius)
	return _profile_contact(player.global_position+Vector3.UP*(PLAYER_HEIGHT*.5),from,to,shot,Vector3(PLAYER_RADIUS,PLAYER_HEIGHT*.5,PLAYER_RADIUS))>=0


static func _collision_vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])


## Follow the curved ribbon rather than filling its empty concave interior.
func _profile_contact(center: Vector3, from: Vector3, to: Vector3, shot: Dictionary, padding: Vector3) -> float:
	if shot.collision_boxes.is_empty(): return _box_contact(center,from,to,shot.dir,shot.half_extents+padding)
	var orientation := Basis.looking_at(shot.dir)
	var scale: float = shot.attack.get("size",1.0)
	var first := -1.0
	for box: Dictionary in shot.collision_boxes:
		var offset := orientation*(_collision_vector(box.offset)*scale)
		var t := _box_contact(center,from+offset,to+offset,shot.dir,_collision_vector(box.half)*scale+padding)
		if t>=0 and (first<0 or t<first): first = t
	return first


func _cast_box(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, orientation: Basis, half: Vector3, excluded: Array[RID] = []) -> float:
	var shape := BoxShape3D.new()
	shape.size = half*2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(orientation,from)
	query.motion = to-from
	query.exclude = excluded
	query.collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER
	var fractions := space.cast_motion(query)
	return fractions[0] if fractions.size()==2 else 1.0


func _wide_wall_fraction(space: PhysicsDirectSpaceState3D, shot: Dictionary, from: Vector3, to: Vector3, excluded: Array[RID] = []) -> float:
	var orientation := Basis.looking_at(shot.dir)
	var broad := _cast_box(space,from,to,orientation,shot.half_extents,excluded)
	if broad>=1 or shot.collision_boxes.is_empty(): return broad
	var scale: float = shot.attack.get("size",1.0)
	var first := 1.0
	for box: Dictionary in shot.collision_boxes:
		var offset := orientation*(_collision_vector(box.offset)*scale)
		first = minf(first,_cast_box(space,from+offset,to+offset,orientation,_collision_vector(box.half)*scale,excluded))
	return first


## A boss and everything it summoned share one owner id (its encounter).
static func _owner_id(source: Node) -> int:
	if source is Enemy and (source as Enemy).encounter_id != 0:
		return (source as Enemy).encounter_id
	return source.get_instance_id() if source != null else 0


## Removes every shot an encounter fired (a boss and its summons).
func clear_owner(owner: int) -> void:
	if Net.is_server():
		Net.server.fx(self, Vector3.INF, ["bclr", owner])
		return
	for i in range(_shots.size() - 1, -1, -1):
		var s: Dictionary = _shots[i]
		if owner == 0 or s.owner != owner:
			continue
		if s.trail:
			_burn_out(s)
		s.node.queue_free()
		_shots.remove_at(i)


func clear() -> void:
	for s in _shots:
		s.node.queue_free()
	_shots.clear()


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	# Player bodies share a terrain layer locally; resolve them only through
	# the swept player/shield tests below, never as a wall that eats the shot.
	var excluded: Array[RID] = []
	for player in players:
		if is_instance_valid(player): excluded.append(player.get_rid())
	var now := Time.get_ticks_msec() / 1000.0
	for s in _shots:
		if s.contract >= 0.0:
			s.contract += delta
			var delay: float = s.attack.terminal.get("delay", 0.4)
			s.node.scale = Vector3.ONE * maxf(0.2, 1.0 - s.contract / delay * 0.8)
			continue
		var from: Vector3 = s.pos
		if s.turn != 0.0:
			s.dir = s.dir.rotated(Vector3.UP, s.turn * delta)
		var step: float = s.speed * delta
		s.travelled += step
		var to: Vector3 = from + s.dir * step
		var drop := maxf(0.0, 1.0 - s.travelled / SETTLE_DISTANCE)
		if not s.attack.get("falling", false):
			to.y = s.shot_y + (s.start_y - s.shot_y) * drop * drop
		var query := PhysicsRayQueryParameters3D.create(from, to, Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER)
		query.exclude = excluded
		var wall: Dictionary = space.intersect_ray(query) if s.collision_boxes.is_empty() else {}
		if s.half_extents!=Vector3.ZERO:
			var fraction := _wide_wall_fraction(space,s,from,to,excluded)
			if fraction<1:
				to = from.lerp(to,fraction)
				s.travelled = s.range
		if not wall.is_empty():
			if from.distance_squared_to(wall.position)<from.distance_squared_to(to): to = wall.position
			s.travelled = s.range
		# A player's expanding magic can tear apart enemy magic before it arrives.
		if s.magic and _interfere(s,from,to):
			s.blocked = true
			s.travelled = s.range
		if not s.blocked:
			for p in players:
				if not is_instance_valid(p) or p in s.hit or p.frozen:
					continue
				if s.returned and now - float(s.hit_at.get(p, -10.0)) < RETURN_REHIT:
					continue
				var contact := _shot_shield_contact(p,from,to,s) if p.shield.active else -1.0
				if contact>=0.0:
					var impact := from.lerp(to,contact)
					p.shield.impact(s.dir)
					_scatter_projectile(s,impact,p.global_position.y)
					p.last_hit_by = s.attack.get("by", "")
					if p.take_damage(float(s.damage),s.armor_piercing,s.magic):
						p.receive_attack_effects(s.attack)
					s.hit.append(p)
					s.hit_at[p] = now
					if s.pierce and s.attack.get("pierce_shields",false):
						continue  # massive shards keep their path; shield still absorbs damage
					to = impact
					s.blocked = true
					s.travelled = s.range
					break
				if _shot_hits_player(p,from,to,s):
					p.last_hit_by = s.attack.get("by", "")
					if p.take_damage(float(s.damage), s.armor_piercing, s.magic):
						p.receive_attack_effects(s.attack)
					s.hit.append(p)
					s.hit_at[p] = now
					if not s.pierce: s.travelled = s.range

		s.pos = to
		s.node.global_position = to
		if s.spin:
			if s.attack.get("style", "") == "disc":
				s.node.rotate_object_local(Vector3.UP, delta * 16.0)
			else:
				s.node.rotate_object_local(Vector3(1, 1, 0).normalized(), delta * 14.0)
		if not s.blocked and s.returns > 0.0 and not s.returned and s.travelled >= s.returns:
			# A thrown disc turns at the end of its line and flies home.
			s.returned = true
			var back: Vector3 = s.origin - s.pos
			back.y = 0.0
			s.dir = back.normalized()
			s.hit = []
			s.travelled = s.range - back.length()
		if not s.blocked and s.travelled >= s.range and s.attack.has("terminal"):
			s.contract = 0.0
	for i in range(_shots.size() - 1, -1, -1):
		var s: Dictionary = _shots[i]
		if s.contract >= 0.0:
			if s.contract >= s.attack.terminal.get("delay", 0.4):
				_release(s)
				s.node.queue_free()
				_shots.remove_at(i)
			continue
		if s.travelled >= s.range:
			if not s.blocked and not s.ripple.is_empty():
				EnemyRipple.spawn(self, s.pos - Vector3.UP * Player.SHOT_HEIGHT, s.ripple, s.color, players, s.hit)
			if s.trail:
				_burn_out(s)
			s.node.queue_free()
			_shots.remove_at(i)


## Swept sphere contact with the visible shield, including fast projectiles.
## Return the first contact fraction, or -1 when the segment misses.
func _shield_contact(p: Player, from: Vector3, to: Vector3, radius: float) -> float:
	var offset := from-(p.global_position+Vector3.UP*.95)
	var direction := to-from
	var reach := MagicShield.RADIUS+radius
	var c := offset.length_squared()-reach*reach
	if c<=0: return 0.0
	var a := direction.length_squared()
	if a<.000001: return -1.0
	var b := offset.dot(direction)
	var discriminant := b*b-a*c
	if discriminant<0: return -1.0
	var t := (-b-sqrt(discriminant))/a
	return t if t>=0 and t<=1 else -1.0


## Localized ring/orb clashes use the same power tradeoff as ring/ring clashes.
## Each wave can affect a shot once; ordinary physical shots pass through.
func _interfere(s: Dictionary, from: Vector3, to: Vector3) -> bool:
	for wave: WarpWave in WarpWave._waves:
		if wave.team!="players" or not wave._active() or wave.get_instance_id() in s.clashed_waves: continue
		var center := Vector3(wave.global_position.x,from.y,wave.global_position.z)
		if absf(from.y-(wave.global_position.y+.9))>1.5+s.radius: continue
		var closest := Geometry3D.get_closest_point_to_segment(center,from,to)
		var near := Vector2(closest.x-center.x,closest.z-center.z).length()
		var far := maxf(Vector2(from.x-center.x,from.z-center.z).length(),Vector2(to.x-center.x,to.z-center.z).length())
		var padding: float = wave.band*.5+s.radius
		if far<minf(wave.previous_radius,wave.radius)-padding or near>maxf(wave.previous_radius,wave.radius)+padding: continue
		# Place the clash on the annulus entry, rather than at the path's center.
		var path := to-from
		path.y = 0
		var relative := from-center
		var from_distance := relative.length()
		var contact_radius := clampf(from_distance,minf(wave.previous_radius,wave.radius),maxf(wave.previous_radius,wave.radius))
		var a := path.length_squared()
		var b := relative.dot(path)
		var discriminant := b*b-a*(relative.length_squared()-contact_radius*contact_radius)
		if a>.000001 and discriminant>=0:
			for t in [(-b-sqrt(discriminant))/a,(-b+sqrt(discriminant))/a]:
				if t>=0 and t<=1:
					closest = from.lerp(to,t)
					break
		var segment := wave._segment_at(closest)
		var strength: float = wave.segments[segment]
		var power := wave.power()*strength
		if power<=.01: continue
		s.clashed_waves.append(wave.get_instance_id())
		var damage: float = s.damage
		var even := absf(power-damage)<=WarpWave.EVEN*maxf(power,damage)
		if even or power<damage:
			wave.segments[segment] = 0.0
		else: wave.segments[segment] *= 1.0-damage/power
		if wave._material: wave._material.set_shader_parameter("arc_strength",wave.segments)
		_scatter_projectile(s,closest,from.y-Player.SHOT_HEIGHT)
		wave._spark(closest,s.color.lerp(wave.color,.5))
		if even or power>=damage: return true
		s.damage = maxf(1.0,damage-power)
	return false


## Sample the actual projectile mesh: its colored voxels break off at contact.
func _scatter_projectile(s: Dictionary, at: Vector3, floor_y: float) -> void:
	var mesh: Mesh = s.node.mesh
	if mesh.get_surface_count()==0: return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var palette: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
	if vertices.is_empty(): return
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var transform: Transform3D = s.node.global_transform
	transform.origin = at
	for i in 28:
		var vertex := randi_range(0,vertices.size()-1)
		points.append(transform*vertices[vertex])
		colors.append(palette[vertex] if palette.size()==vertices.size() else s.color)
	Debris.burst_points(self,points,colors,.09*clampf(float(s.attack.get("size",1.0)),.7,2.0),28,at-s.dir*.35,floor_y,.45)


## An orb that has finished contracting releases its ring of needles; they
## skip anyone the orb itself already hit.
func _release(s: Dictionary) -> void:
	var terminal: Dictionary = s.attack.terminal
	var count: int = terminal.get("count", 8)
	var spin := randf() * TAU
	for k in count:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, spin + TAU * k / count)
		_shots.append(_child_shot(s, dir, terminal.attack))


func _child_shot(parent: Dictionary, dir: Vector3, attack: Dictionary) -> Dictionary:
	fire(parent.pos, dir, attack, null, parent.shot_y, parent.hit)
	var child: Dictionary = _shots.pop_back()
	child.owner = parent.owner
	return child


## Does the segment from..to pass through the player's body (an upright capsule)?
func _hits_player(p: Player, from: Vector3, to: Vector3, radius: float) -> bool:
	var base := p.global_position
	var closest := Geometry3D.get_closest_point_to_segment(Vector3(base.x, clampf(from.y, base.y, base.y + PLAYER_HEIGHT), base.z), from, to)
	var flat := Vector2(closest.x - base.x, closest.z - base.z).length()
	return flat < PLAYER_RADIUS + radius and closest.y > base.y - 0.2 and closest.y < base.y + PLAYER_HEIGHT


## A fireball's flames: [core, trail]. The core churns around the shot (local
## particles); the trail is left behind in the world as it flies.
func _fire_particles(attack: Dictionary) -> Array:
	var look := _fire_look(attack)
	var size: float = attack.get("size", 1.0)
	var core := GPUParticles3D.new()
	core.process_material = look.core
	core.draw_pass_1 = look.voxel
	core.amount = int(28 * size) + 8
	core.lifetime = 0.32
	core.preprocess = 0.32
	core.local_coords = true
	core.visibility_aabb = AABB(Vector3.ONE * -size, Vector3.ONE * size * 2.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var trail := GPUParticles3D.new()
	trail.process_material = look.trail
	trail.draw_pass_1 = look.ember
	trail.amount = int(34 * size) + 10
	trail.lifetime = 0.55
	trail.local_coords = false
	trail.visibility_aabb = AABB(Vector3(-8, -2, -8) * maxf(1.0, size), Vector3(16, 6, 16) * maxf(1.0, size))
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return [core, trail]


## The fire's look for a color and size, made once: voxels that start
## white-hot, burn in the shot's color and cool to dark as they shrink away,
## like VoxelFire (campfires, the Dragonbreath bow).
func _fire_look(attack: Dictionary) -> Dictionary:
	var color: Color = attack.get("color", Color(1.0, 0.5, 0.12))
	var size: float = attack.get("size", 1.0)
	var key := "%s/%.2f/%.2f" % [color.to_html(),size,float(attack.get("fire_brightness",2.4))]
	if _fire_looks.has(key):
		return _fire_looks[key]
	# Hot voxels lean toward a lighter, warmer hue (orange fire burns yellow);
	# cooling ones darken and shift the other way (orange fire goes red).
	var hot := Color.from_hsv(wrapf(color.h + 0.05, 0.0, 1.0), color.s * 0.8, 1.0)
	var cool := Color.from_hsv(wrapf(color.h - 0.05, 0.0, 1.0), minf(1.0, color.s * 1.1), color.v * 0.45, 0.0)
	# (The fire shader works in linear color: convert so the hues stay rich.)
	var ramp := Gradient.new()
	ramp.set_color(0, hot.srgb_to_linear())
	ramp.set_color(1, cool.srgb_to_linear())
	ramp.add_point(0.25, color.lerp(hot, 0.3).srgb_to_linear())
	ramp.add_point(0.65, color.darkened(0.15).srgb_to_linear())
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink

	var core := ParticleProcessMaterial.new()
	core.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	core.emission_sphere_radius = 0.2 * size
	core.direction = Vector3.UP
	core.spread = 180.0
	core.initial_velocity_min = 0.3 * size
	core.initial_velocity_max = 0.9 * size
	core.gravity = Vector3.ZERO
	core.scale_min = 0.7
	core.scale_max = 1.4
	core.scale_curve = shrink_tex
	core.color_ramp = ramp_tex

	var trail := ParticleProcessMaterial.new()
	trail.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.2 * size
	trail.direction = Vector3.UP
	trail.spread = 60.0
	trail.initial_velocity_min = 0.3
	trail.initial_velocity_max = 1.0
	trail.gravity = Vector3(0, 1.2, 0)  # hot air: the flames left behind rise
	trail.scale_min = 0.6
	trail.scale_max = 1.2
	trail.scale_curve = shrink_tex
	trail.color_ramp = ramp_tex

	var burst := trail.duplicate() as ParticleProcessMaterial
	burst.spread = 180.0
	burst.initial_velocity_min = 1.5 * size
	burst.initial_velocity_max = 3.5 * size
	burst.gravity = Vector3(0, -2.0, 0)

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	mat.set_shader_parameter("brightness",float(attack.get("fire_brightness",2.4)))
	var voxel := BoxMesh.new()
	voxel.size = Vector3.ONE * 0.12 * size
	voxel.material = mat
	var ember := BoxMesh.new()
	ember.size = Vector3.ONE * 0.1 * size
	ember.material = mat
	_fire_looks[key] = {core = core, trail = trail, burst = burst, voxel = voxel, ember = ember}
	return _fire_looks[key]


## Where a fireball ends: a burst of flame voxels, and its trail is left to
## burn out instead of vanishing with it.
func _burn_out(s: Dictionary) -> void:
	var trail: GPUParticles3D = s.trail
	var pos: Vector3 = s.node.global_position
	trail.emitting = false
	trail.reparent(self)
	get_tree().create_timer(trail.lifetime + 0.1).timeout.connect(trail.queue_free)
	var look := _fire_look(s.attack)
	var size: float = s.attack.get("size", 1.0)
	var burst := GPUParticles3D.new()
	burst.process_material = look.burst
	burst.draw_pass_1 = look.voxel
	burst.amount = 10 if s.attack.get("pixel_projectile",false) else int(24 * size) + 8
	burst.lifetime = 0.45
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.local_coords = false
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(burst)
	burst.global_position = pos
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


## A small ball of warped space around a magic shot (the same look as the warp shield).
func _halo(size: float, color: Color) -> MeshInstance3D:
	if _halo_mesh == null:
		_halo_mesh = SphereMesh.new()
		_halo_mesh.radius = MAGIC_HALO
		_halo_mesh.height = MAGIC_HALO * 2.0
		_halo_mesh.radial_segments = 16
		_halo_mesh.rings = 8
	if not _halo_materials.has(color):
		_halo_materials[color] = EnemyRipple.warp_material(color, 0.12)
	var mi := MeshInstance3D.new()
	mi.mesh = _halo_mesh
	mi.material_override = _halo_materials[color]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * size
	return mi


func _mesh_for(attack: Dictionary) -> Mesh:
	if attack.has("voxel_model"):
		return _voxel_projectile(attack)
	var style: String = attack.get("style", "pellet")
	var color: Color = attack.get("color", Color.WHITE)
	var size: float = attack.get("size", 1.0)
	var key := "%s/%s/%.2f" % [style, color.to_html(), size]
	if _meshes.has(key):
		return _meshes[key]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	mat.set_shader_parameter("brightness", 2.2)
	var mesh := BoxMesh.new()
	if style == "fireball":
		color = color.lerp(Color.WHITE, 0.45)  # the white-hot heart of the flames
	match style:
		"fireball":
			mesh.size = Vector3.ONE * 0.16 * size
		"bolt":
			mesh.size = Vector3(0.22, 0.22, 0.62) * size
		"needle":
			mesh.size = Vector3(0.1, 0.16, 0.8) * size
		"disc":
			mesh.size = Vector3(0.7, 0.12, 0.7) * size
		"crescent":
			mesh.size = Vector3(1.3, 0.35, 0.3) * size
		"shard":
			mesh.size = Vector3(0.2, 0.3, 0.72) * size
		"comet":
			mesh.size = Vector3(0.4, 0.4, 0.9) * size
		"orb":
			mesh.size = Vector3.ONE * 0.5 * size
		_:
			mesh.size = Vector3.ONE * 0.3 * size
	mesh.material = mat
	# Vertex colors carry the projectile color into the fire_voxel shader.
	var arrays := mesh.get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(0, mat)
	_meshes[key] = out
	return out


## Authored creature and boss projectile models, centered at the shot origin.
## Boss art keeps its palette blocks clean and its emission below whiteout.
func _voxel_projectile(attack: Dictionary) -> Mesh:
	var folder: String = attack.voxel_model
	var size: float = attack.get("size", 1.0)
	var key := "%s/%.2f/%.2f" % [folder,size,float(attack.get("projectile_glow",1.5))]
	if _meshes.has(key):
		return _meshes[key]
	var source := VoxModel.load_mesh("res://creatures/" + folder + "/model.vox")
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var center := source.get_aabb().get_center()
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://creatures/" + folder + "/rig.json"))
	var voxel_size: float = rig.voxel_size * size
	for i in vertices.size():
		vertices[i] = (vertices[i] - center) * voxel_size
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/voxel_model.gdshader")
	material.set_shader_parameter("glow_strength",float(attack.get("projectile_glow",0.6 if attack.get("style", "pellet") == "pellet" else 1.5)))
	if attack.get("pixel_projectile",false): material.set_shader_parameter("jitter",0.0)
	mesh.surface_set_material(0, material)
	_meshes[key] = mesh
	return mesh
