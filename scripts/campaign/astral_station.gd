class_name AstralStation
extends Node3D
## A small woodland spaceport. Shared plan anchors keep actors, physics,
## quest markers and the launch camera on exactly the same foundation.
const PARTS := ["story_starcoil","story_spellsteel_nozzle","story_aether_heart"]
const OFFSETS := {mechanic=Vector3(-14,0,7),parts=Vector3(-17,0,13),boarding=Vector3(6,0,1.8)}
const HALF := Vector2(28,24)
const WHITE := Color("d6e4e4")
const STEEL := Color("334153")
const TRIM := Color("8198a2")
const GOLD := Color("d6a15b")
const CYAN := Color("60e9ef")
var world: IslandWorld
var rocket := Node3D.new()
var flight := {}
var _blocks := {}
var _pipes: Array = []
var _rocket_blocks := {}
var _rocket_pipes: Array = []
var _body: StaticBody3D
var _rocket_body: StaticBody3D
var _exhaust: Array[GPUParticles3D] = []
var _arms: Array[Node3D] = []
var _engine_light: OmniLight3D
var _board_target: InteractionTarget
var _board_badge: QuestMarker
var _parts_badge: QuestMarker
var _headless := false

static func plan(generator: IslandGenerator) -> Vector3:
	var best := Vector3.INF
	var best_score := INF
	# No towns, walls, roads or shore under this foundation. Prefer a level
	# clearing near the woodland heart, with a full ring of trees around it.
	for z in range(-180,181,12):
		for x in range(-180,181,12):
			if Vector2(x,z).length()<90 or Vector2(x,z).length()>185: continue
			var low := INF
			var high := -INF
			var clear := true
			for dz in [-28,0,28]:
				for dx in [-32,0,32]:
					var col := generator.column(x+dx,z+dz)
					if col.y!=Biomes.WOODS or generator.feature_at(x+dx,z+dz)!=null: clear=false
					low = minf(low,col.x+1)
					high = maxf(high,col.x+1)
			if not clear: continue
			var score := (high-low)*30.0+Vector2(x,z).length()*0.06
			if score<best_score:
				# Check the complete footprint: nine samples can miss a narrow
				# diagonal road, a small ruin or a creek between the corners.
				for dz in range(-28,29,2):
					if not clear: break
					for dx in range(-32,33,2):
						if generator.column(x+dx,z+dz).y!=Biomes.WOODS or generator.feature_at(x+dx,z+dz)!=null:
							clear=false
							break
				if not clear: continue
				best_score=score
				best=Vector3(x,high+0.18,z)
	if not best.is_finite():
		push_error("No clear woodland foundation for Starfall Launchworks")
		return best
	var high := best.y-0.18
	for z in range(-24,25,2):
		for x in range(-28,29,2): high=maxf(high,generator.column(floori(best.x+x),floori(best.z+z)).x+1.0)
	best.y=high+0.18
	return best

static func contains(center: Vector3,point: Vector3,margin := 0.0) -> bool:
	return absf(point.x-center.x)<HALF.x+margin and absf(point.z-center.z)<HALF.y+margin

func _ready() -> void:
	name = "StarfallLaunchworks"
	position = world.astral_site
	_headless = world.server_build or Net.is_server()
	_body = StaticBody3D.new()
	_body.collision_layer = Player.OBSTACLE_LAYER
	_body.collision_mask = 0
	add_child(_body)
	rocket.name="Starling"
	rocket.position=Vector3(6,0,-5)
	add_child(rocket)
	_rocket_body=StaticBody3D.new()
	_rocket_body.collision_layer=Player.OBSTACLE_LAYER
	_rocket_body.collision_mask=0
	rocket.add_child(_rocket_body)
	_build_station()
	_build_rocket()
	if not _headless:
		_publish(self,_blocks,_pipes)
		_publish(rocket,_rocket_blocks,_rocket_pipes)
		_effects()
		_interactions()

func _box(at: Vector3,size: Vector3,color: Color,solid := false,ship := false,glow := false) -> void:
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size=size
		shape.shape=box
		shape.position=at
		(_rocket_body if ship else _body).add_child(shape)
	if _headless: return
	var groups: Dictionary = _rocket_blocks if ship else _blocks
	var key := ("glow_" if glow else "metal_")+color.to_html()
	if not groups.has(key): groups[key]={color=color,glow=glow,transforms=[]}
	groups[key].transforms.append(Transform3D(Basis.from_scale(size),at))

func _pipe(a: Vector3,b: Vector3,radius: float,color: Color,ship := false) -> void:
	if _headless: return
	(_rocket_pipes if ship else _pipes).append({a=a,b=b,radius=radius,color=color})

func _beam(a: Vector3,b: Vector3,width: float,color: Color) -> void:
	if _headless: return
	var direction := b-a
	var key := "metal_"+color.to_html()
	if not _blocks.has(key): _blocks[key]={color=color,glow=false,transforms=[]}
	_blocks[key].transforms.append(TheoryRoundDetails.along(a,b,width*0.5))

func _build_station() -> void:
	# Raised modular foundation clears the highest terrain column. Posts run
	# into the soil rather than hovering over uneven woodland ground.
	for z in range(-22,24,4):
		for x in range(-26,28,4):
			_box(Vector3(x,-0.22,z),Vector3(3.96,0.44,3.96),STEEL,true)
			for dx in [-1.6,1.6]: _box(Vector3(x+dx,0.012,z),Vector3(0.035,0.025,3.7),TRIM)
	for x in [-25.0,25.0]:
		for z in [-20.0,0.0,20.0]:
			var ground := world.generator.column(floori(position.x+x),floori(position.z+z)).x+1.0-position.y
			_box(Vector3(x,(ground-0.3)*0.5,z),Vector3(1.1,0.3-ground,1.1),STEEL,true)
	# Broad stepped approach reaches the terrain from the front of the plaza.
	for i in 12:
		var z := 24.3+i*0.58
		var ground := world.generator.column(floori(position.x),floori(position.z+z)).x+1.0-position.y
		var top := lerpf(0.0,ground,float(i+1)/12.0)
		_box(Vector3(0,(top+ground-0.25)*0.5,z),Vector3(7,maxf(0.25,top-ground+0.25),0.64),TRIM,true)
	# Workshop and mission-control prefab cabins face the common plaza.
	for cabin in [Vector3(-19,0,-3),Vector3(-19,0,-15)]:
		_box(cabin+Vector3(0,0.12,0),Vector3(12,0.24,8),TRIM,true)
		_box(cabin+Vector3(0,5.2,0),Vector3(12.5,0.4,8.5),WHITE,true)
		_box(cabin+Vector3(-5.8,2.6,0),Vector3(0.4,5.2,8),WHITE,true)
		for z in [-3.8,3.8]: _box(cabin+Vector3(0,2.6,z),Vector3(12,5.2,0.4),WHITE,true)
		for z in [-3.0,3.0]: _box(cabin+Vector3(5.8,2.5,z),Vector3(0.4,5,1.6),STEEL,true)
		_box(cabin+Vector3(5.8,4.55,0),Vector3(0.4,1.3,4.5),WHITE,true)
		for z in [-2.1,2.1]: _pipe(cabin+Vector3(5.9,0,z),cabin+Vector3(5.9,4,z),0.08,GOLD)
		for z in [-2.8,2.8]:
			_pipe(cabin+Vector3(-5.3,4.6,z),cabin+Vector3(5.6,4.6,z),0.12,STEEL)
			for x in [-4.0,0.0,4.0]: _box(cabin+Vector3(x,4.82,z),Vector3(0.28,0.35,0.45),TRIM)
		for x in [-3.0,1.0]:
			_box(cabin+Vector3(x,1.1,-2.5),Vector3(3.1,0.2,1.6),STEEL,true)
			for dx in [-1.3,1.3]: _box(cabin+Vector3(x+dx,0.5,-2.5),Vector3(0.15,1,1.4),TRIM,true)
			_box(cabin+Vector3(x,1.8,-2.95),Vector3(1.4,1,0.16),STEEL)
			_box(cabin+Vector3(x,1.8,-2.84),Vector3(1.18,0.75,0.07),CYAN,false,false,true)
			for k in 5: _box(cabin+Vector3(x-0.5+k*0.23,1.23,-2.1),Vector3(0.13,0.05,0.15),GOLD)
		for k in 7:
			_box(cabin+Vector3(-5.5,1.0+k*0.48,0),Vector3(0.1,0.12,2.8),STEEL)
		_box(cabin+Vector3(0,5.52,0),Vector3(8,0.16,3),STEEL)
	# The actual story chest is spawned here by the server.
	# Grounded fuel tanks, braided feed lines and a visible connection to the pad.
	for z in [-14.0,-8.0]:
		_box(Vector3(19,0.35,z),Vector3(5,0.7,4),STEEL,true)
		for y in range(1,7): _box(Vector3(19,y*0.6,z),Vector3(3.2,0.59,3.2),WHITE,true)
		for y in [0.7,3.6]: _box(Vector3(19,y,z),Vector3(3.6,0.2,3.6),GOLD)
		_pipe(Vector3(19,3.9,z),Vector3(19,4.8,z),0.18,TRIM)
		_pipe(Vector3(19,0.8,z),Vector3(14,0.8,z),0.22,TRIM)
	_pipe(Vector3(14,0.8,-14),Vector3(14,0.8,-5),0.22,TRIM)
	_pipe(Vector3(14,0.8,-5),Vector3(8.75,0.8,-5),0.22,TRIM)
	_pipe(Vector3(8.75,0.8,-5),Vector3(8.75,3,-5),0.18,GOLD)
	# Launch gantry has real corner posts, crossed braces and landing plates.
	for y in range(0,24,3):
		for x in [-1.5,1.5]:
			for z in [-1.5,1.5]: _box(Vector3(x-3,y+1.5,z-8),Vector3(0.45,3,0.45),STEEL,true)
		for z in [-1.5,1.5]:
			_beam(Vector3(-4.5,y,z-8),Vector3(-1.5,y+3,z-8),0.22,TRIM)
			_beam(Vector3(-1.5,y,z-8),Vector3(-4.5,y+3,z-8),0.22,TRIM)
		for x in [-4.5,-1.5]:
			_beam(Vector3(x,y,-9.5),Vector3(x,y+3,-6.5),0.22,TRIM)
		_box(Vector3(-3,y+0.1,-8),Vector3(3.4,0.2,3.4),TRIM)
		for k in 8: _box(Vector3(-4.8,y+k*0.36,-8),Vector3(0.18,0.09,1.1),GOLD)
	if not _headless:
		for y in [6.0,10.0,14.0]:
			var arm := Node3D.new()
			arm.position=Vector3(-1.5,y,-6)
			add_child(arm)
			_arms.append(arm)
			var reach := 4.88 if y<12 else 5.75
			var struts: Array[Transform3D]=[]
			for z in [-0.35,0.35]:
				struts.append(TheoryRoundDetails.along(Vector3(0,0,z),Vector3(reach,0,z),0.12))
				struts.append(TheoryRoundDetails.along(Vector3(0,-0.8,z),Vector3(reach-0.2,0,z),0.065))
			TheoryRoundDetails.batch(arm,"RetractingUmbilical",TheoryRoundDetails.mesh("cylinder"),struts,[],TRIM)
			var grips: Array[Transform3D]=[Transform3D(Basis.from_scale(Vector3(0.25,0.45,1.1)),Vector3(reach,0,0))]
			TheoryRoundDetails.batch(arm,"Coupler",TheoryRoundDetails.mesh("block"),grips,[],GOLD)
	# Landing circle is built from blocks, with fine native pipes outside it.
	for i in 48:
		var angle := TAU*i/48.0
		_box(Vector3(6+cos(angle)*7,0.045,-5+sin(angle)*7),Vector3(0.58,0.07,0.58),GOLD)
		if i%4==0: _box(Vector3(6+cos(angle)*8,0.065,-5+sin(angle)*8),Vector3(0.45,0.09,0.45),CYAN,false,false,true)
	for side in [-1.0,1.0]:
		for z in range(-22,23,4):
			_box(Vector3(side*27,1,z),Vector3(0.16,2,0.16),STEEL,true)
		_pipe(Vector3(side*27,1.7,-22),Vector3(side*27,1.7,22),0.06,TRIM)
	for x in [-23.0,23.0]:
		_box(Vector3(x,3.2,19),Vector3(0.25,6.4,0.25),STEEL,true)
		_box(Vector3(x,6.4,19),Vector3(2.4,0.3,0.7),WHITE)
		_box(Vector3(x,6.2,19),Vector3(2.0,0.08,0.5),CYAN,false,false,true)
	if not _headless:
		_sign("STARFALL LAUNCHWORKS",Vector3(-18,6,-2),0.015)
		_sign("STARLING / AETHER DRIVE",Vector3(6,0.35,5.1),0.008)
		_sign("SPARES & STARCOILS",Vector3(-17,2.3,13),0.008)
		for at in [Vector3(-14,4,4),Vector3(-19,4,-3),Vector3(-19,4,-15),Vector3(7,6,-5)]:
			var lamp := OmniLight3D.new()
			lamp.position=at
			lamp.light_color=CYAN
			lamp.light_energy=1.7
			lamp.omni_range=10
			add_child(lamp)

func _build_rocket() -> void:
	# Coarse sculpted hull with narrow tile seams. Each ring shares edges;
	# fins, engine plumbing and collar supports attach directly to the hull.
	for layer in 42:
		var y := 1.5+layer*0.4
		var radius := 2.8 if y<12.7 else maxf(0.25,2.8-(y-12.7)*0.60)
		for x in range(-8,9):
			for z in range(-8,9):
				var r := Vector2(x*0.4,z*0.4).length()
				if r>radius or r<radius-0.6: continue
				var tint := WHITE if layer%11 not in [0,1] else STEEL
				if z>0 and abs(x)<3 and layer in range(22,29): tint=CYAN.darkened(0.35)
				_box(Vector3(x*0.4,y,z*0.4),Vector3(0.395,0.395,0.395),tint,false,true)
	for y in [2.2,5.6,10.0,13.1]:
		for i in 40:
			var a := TAU*i/40
			_box(Vector3(cos(a)*2.85,y,sin(a)*2.85),Vector3(0.38,0.18,0.38),GOLD,false,true)
	# Collision stays inside the sculpted hull.
	_box(Vector3(0,7,0),Vector3(3.6,10,3.6),STEEL,true,true)
	for side in [-1.0,1.0]:
		for turn in [false,true]:
			for i in 10:
				var outward := 2.1+i*0.24
				var top := 5.6-i*0.42
				var at := Vector3(side*outward,top*0.5+0.25,0) if not turn else Vector3(0,top*0.5+0.25,side*outward)
				_box(at,Vector3(0.25,top,1.1) if not turn else Vector3(1.1,top,0.25),STEEL,false,true)
				_box(at+Vector3.UP*(top*0.5),Vector3(0.27,0.13,1.13) if not turn else Vector3(1.13,0.13,0.27),CYAN,false,true,true)
			var foot := Vector3(side*4.2,0.25,0) if not turn else Vector3(0,0.25,side*4.2)
			_box(foot,Vector3(1.2,0.45,1.2),TRIM,true,true)
	# Copper circulation traces, emissive runes and prism crown.
	for x in [-1.5,1.5]:
		_pipe(Vector3(x,3,-2.5),Vector3(x,12,-2.5),0.08,GOLD,true)
		for y in range(4,13,2): _box(Vector3(x,y,-2.67),Vector3(0.32,0.25,0.16),CYAN,false,true,true)
	for i in 8:
		var a := TAU*i/8
		_box(Vector3(cos(a)*1.1,18.5,sin(a)*1.1),Vector3(0.3,1.7,0.3),CYAN,false,true,true)
	_box(Vector3(0,18.8,0),Vector3(0.7,2.3,0.7),CYAN,false,true,true)
	# Low boarding hatch, landing steps and two service handles.
	_box(Vector3(0,2.9,2.86),Vector3(1.7,2.8,0.22),STEEL,false,true)
	_box(Vector3(0,3.2,3.0),Vector3(1.35,1.65,0.09),CYAN.darkened(0.55),false,true)
	for x in [-0.95,0.95]: _pipe(Vector3(x,1.3,3),Vector3(x,4.2,3),0.055,GOLD,true)
	for i in 6: _box(Vector3(0,0.12+i*0.23,5.7-i*0.45),Vector3(2,0.24,0.48),TRIM,true,true)
	if not _headless:
		for x in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				var bell := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius=0.35
				mesh.bottom_radius=0.8
				mesh.height=1.2
				mesh.radial_segments=12
				bell.mesh=mesh
				bell.material_override=TheoryRoundDetails.metal()
				bell.position=Vector3(x,1,z)
				rocket.add_child(bell)

func _publish(parent: Node3D,groups: Dictionary,pipes: Array) -> void:
	for key: String in groups:
		var group: Dictionary=groups[key]
		var multi := MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=TheoryRoundDetails.mesh("block")
		multi.instance_count=group.transforms.size()
		for i in multi.instance_count: multi.set_instance_transform(i,group.transforms[i])
		var model := MultiMeshInstance3D.new()
		model.multimesh=multi
		var material := StandardMaterial3D.new()
		material.albedo_color=group.color
		material.metallic=0.45
		material.roughness=0.65
		if group.glow:
			material.emission_enabled=true
			material.emission=group.color
			material.emission_energy_multiplier=2.2
		model.material_override=material
		parent.add_child(model)
	TheoryRoundDetails.attach(parent,pipes)

func _sign(text: String,at: Vector3,pixel: float) -> void:
	var sign := SignBoard.pair(text,"slate","",Color("e4f3e7"),pixel/0.012)
	sign.position=at
	add_child(sign)

func _effects() -> void:
	for smoke in [false,true]:
		var emitter := GPUParticles3D.new()
		emitter.amount=150 if smoke else 100
		emitter.lifetime=4.5 if smoke else 0.65
		emitter.explosiveness=0
		emitter.emitting=false
		emitter.visibility_aabb=AABB(Vector3(-45,-60,-45),Vector3(90,180,90))
		var particles := ParticleProcessMaterial.new()
		particles.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
		particles.emission_box_extents=Vector3(1.2,0.08,1.2)
		particles.direction=Vector3.DOWN
		particles.spread=58 if smoke else 15
		particles.initial_velocity_min=3 if smoke else 12
		particles.initial_velocity_max=7 if smoke else 20
		particles.gravity=Vector3(0,1.8,0) if smoke else Vector3.ZERO
		particles.scale_min=1.4 if smoke else 0.2
		particles.scale_max=3.2 if smoke else 0.65
		particles.color=Color(0.63,0.69,0.72,0.65) if smoke else Color("8cefff")
		var gradient := Gradient.new()
		gradient.set_color(0,Color(1,1,1,0))
		gradient.add_point(0.12,Color(1,1,1,0.8))
		gradient.set_color(gradient.get_point_count()-1,Color(1,1,1,0))
		var ramp := GradientTexture1D.new();ramp.gradient=gradient
		particles.color_ramp=ramp
		var curve := Curve.new()
		curve.add_point(Vector2(0,0.15));curve.add_point(Vector2(0.3,0.75));curve.add_point(Vector2(1,0))
		var texture := CurveTexture.new();texture.curve=curve
		particles.scale_curve=texture
		emitter.process_material=particles
		var cube := BoxMesh.new();cube.size=Vector3.ONE
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo=true
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		if not smoke:
			material.emission_enabled=true;material.emission=CYAN;material.emission_energy_multiplier=4
		cube.material=material
		if smoke:
			# Soft billboards make expanding clouds, while the flame keeps its voxels.
			var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
			for y in 32:
				for x in 32:
					var r := Vector2(x-15.5,y-15.5).length()/15.5
					var cloud := clampf(1.0-r,0,1)
					image.set_pixel(x,y,Color(1,1,1,cloud*cloud*(3.0-2.0*cloud)))
			material.albedo_texture=ImageTexture.create_from_image(image)
			material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
			material.cull_mode=BaseMaterial3D.CULL_DISABLED
			material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			var quad := QuadMesh.new();quad.size=Vector2.ONE*3.0;quad.material=material
			emitter.draw_pass_1=quad
		else: emitter.draw_pass_1=cube
		emitter.position=Vector3(0,0.6,0) if not smoke else Vector3(6,0.3,-5)
		(rocket if not smoke else self).add_child(emitter)
		_exhaust.append(emitter)
	_engine_light=OmniLight3D.new()
	_engine_light.light_color=CYAN
	_engine_light.omni_range=22
	_engine_light.light_energy=0
	_engine_light.position=Vector3(0,1.2,0)
	rocket.add_child(_engine_light)

func _interactions() -> void:
	_board_target=InteractionTarget.new()
	_board_target.position=OFFSETS.boarding
	_board_target.title="Starling boarding hatch"
	_board_target.action_text="Board"
	_board_target.reach=4.0
	_board_target.response="Boarding the Starling. Waiting for every member of your party."
	_board_target.activated.connect(func(_actor: Node3D) -> void:
		if Net.is_client(): Net.client.send_action("camp",["quest","astral:board"]))
	add_child(_board_target)
	_board_badge=QuestMarker.new("main");_board_target.add_child(_board_badge)
	_parts_badge=QuestMarker.new("main");_parts_badge.position=OFFSETS.parts;add_child(_parts_badge)

func update_campaign(camp: Dictionary) -> void:
	var step := Campaigns.step_def(str(camp.get("id","")),int(camp.get("step",0)))
	flight=camp.get("astral",{}).get("flight",{})
	if is_instance_valid(_board_target):
		_board_target.enabled=step.get("kind","")=="astral_board" and flight.is_empty()
		_board_badge.visible=_board_target.enabled
		_parts_badge.visible=step.get("kind","")=="astral_parts"

func _process(_delta: float) -> void:
	var now := Net.client.server_time() if Net.is_client() else Net.now()
	var age := now-float(flight.get("start",now+1))
	var active := not flight.is_empty() and age>=0
	var lift := maxf(0,age-3.2)
	rocket.position=Vector3(6,lift*lift*2.2,-5)
	rocket.rotation.z=sin(age*35)*0.002*clampf(age,0,1) if active else 0
	for arm: Node3D in _arms: arm.rotation.y=-PI*0.5*smoothstep(0.4,2.4,age) if active else 0.0
	for emitter: GPUParticles3D in _exhaust: emitter.emitting=active
	if is_instance_valid(_engine_light): _engine_light.light_energy=(4+sin(age*31)*0.6)*clampf(age,0,1) if active else 0
