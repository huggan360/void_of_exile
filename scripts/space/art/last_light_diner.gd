class_name LastLightDiner
extends Node3D
## A hidden roadside diner in the outer Gloam. No map marker by design.
const Art = preload("res://scripts/space/art/ship_hull.gd").ArtBatch
var walkers: Array[CreatureModel] = []
var clock := 0.0

func build(server: bool) -> void:
	position = SpaceLayout.DINER
	var art := Art.new(self, server)
	var cream := Color("fff0cd")
	var red := Color("a83249")
	var chrome := Color("a5bdca")
	# Voxel stone cone, broad at the deck and tapering down into space.
	for layer in 24:
		var half: int = 28-layer
		for x in range(-half, half+1, 4):
			for z in range(-half, half+1, 4):
				if Vector2(x, z).length()>half: continue
				art.box(Vector3(x, -1.0-layer*1.4, z), Vector3(4, 1.5, 4), Color("424859").lightened(float(posmod(x+z+layer, 4))*0.025))
	art.box(Vector3(0,-0.5,0),Vector3(48,1,44),chrome)
	art.solid(Vector3(0,-0.5,0),Vector3(48,1,44))
	for x in range(-14,14):
		for z in range(-10,11):
			art.box(Vector3(x+0.5,0.025,z+0.5),Vector3(1,0.05,1),cream if posmod(x+z,2)==0 else Color("252633"))
	for side in [-1,1]:
		var at := Vector3(side*14,1.0,0)
		art.box(at,Vector3(0.4,2,22),red)
		art.solid(at,Vector3(0.4,2,22))
		art.box(Vector3(side*14,4.8,0),Vector3(0.5,0.6,22),chrome)
		for z in range(-10,12,4):
			art.box(Vector3(side*14,3.2,z),Vector3(0.4,2.4,0.25),chrome)
		art.solid(Vector3(side*14,3.1,0),Vector3(0.2,2.2,22))
		for y in [0.3,4.5,5.3]:
			art.box(Vector3(side*14.3,y,0),Vector3(0.15,0.15,22.5),Color("35e6e1"),1.8)
	art.box(Vector3(0,2.5,-11),Vector3(28,5,0.4),cream)
	art.solid(Vector3(0,2.5,-11),Vector3(28,5,0.4))
	for side in [-1,1]:
		art.box(Vector3(side*8,2.5,11),Vector3(12,5,0.4),red)
		art.solid(Vector3(side*8,2.5,11),Vector3(12,5,0.4))
	art.box(Vector3(0,5.5,0),Vector3(29,0.5,23),chrome)
	art.solid(Vector3(0,5.5,0),Vector3(29,0.5,23))
	art.box(Vector3(0,5.8,11.7),Vector3(29,0.2,0.2),Color("ff53aa"),2.0)
	# Counter, booths and working drinks.
	art.box(Vector3(0,0.55,-7),Vector3(20,1.1,1.5),red)
	art.solid(Vector3(0,0.55,-7),Vector3(20,1.1,1.5))
	art.box(Vector3(0,1.15,-7),Vector3(20.4,0.15,1.8),chrome)
	LeisureFurniture.tap(self,"lastlight:beer",Transform3D(Basis.IDENTITY,Vector3(-4,1.25,-7)),server)
	LeisureFurniture.tap(self,"lastlight:coffee",Transform3D(Basis.IDENTITY,Vector3(4,1.25,-7)),server,"coffee")
	for i in 4:
		LeisureFurniture.chair(self,"lastlight:counter%d" % i,Transform3D(Basis.IDENTITY,Vector3(-6+i*4,0,-4.8)),server,true)
		LeisureFurniture.table_spot(self,"lastlight:cup%d" % i,Transform3D(Basis.IDENTITY,Vector3(-6+i*4,1.25,-6.4)))
	for side in [-1,1]:
		for row in 2:
			var at := Vector3(side*9,0,1+row*5)
			art.box(at+Vector3.UP*0.95,Vector3(3,0.15,1.7),cream)
			art.solid(at+Vector3.UP*0.5,Vector3(0.3,1,0.3))
			for end in [-1,1]:
				var seat := at+Vector3(0,0,end*1.5)
				art.box(seat+Vector3.UP*0.45,Vector3(3,0.6,0.8),red)
				art.box(seat+Vector3(0,1,end*0.35),Vector3(3,1.3,0.25),red)
				art.solid(seat+Vector3.UP*0.5,Vector3(3,1,0.8))
				if end==1:
					LeisureFurniture.bench_targets(self,"lastlight:booth%d:%d" % [side,row],Transform3D(Basis.IDENTITY,seat),0.75)
				elif not server:
					var guest := CreatureModel.new("npc_traveler")
					guest.position = seat+Vector3.UP*0.3
					guest.scale = Vector3.ONE*0.85
					guest.rotation.y = PI
					add_child(guest)
					for limb: String in ["leg_l", "leg_r"]:
						if guest._limbs.has(limb): guest._limbs[limb].rotation.x = -PI*0.5
	# Two radial walks use the same hatch alignment as the Nexus.
	for berth in range(6,8):
		var side: float = -1.0 if berth==6 else 1.0
		art.box(Vector3(side*29, -0.35,0),Vector3(14,0.7,5),chrome)
		art.solid(Vector3(side*29,-0.35,0),Vector3(14,0.7,5))
		for z in [-2.4,2.4]:
			art.box(Vector3(side*29,0.7,z),Vector3(14,0.12,0.12),Color("35e6e1"),1.4)
	# Chrome jukebox with glowing stacked voxel bands.
	art.box(Vector3(11,1.1,-8.5),Vector3(1.6,2.2,1),chrome)
	art.solid(Vector3(11,1.1,-8.5),Vector3(1.6,2.2,1))
	for band in 7:
		art.box(Vector3(11,0.5+band*0.23,-7.94),Vector3(1.25,0.1,0.1),Color("ff53aa") if band%2==0 else Color("35e6e1"),1.5)
	# Deck railings leave the entrance and both docking walks open.
	for z in [-21,21]:
		for x in range(-24,25,4):
			art.box(Vector3(x,0.6,z),Vector3(0.15,1.2,0.15),chrome)
		art.box(Vector3(0,1.2,z),Vector3(48,0.12,0.12),chrome)
	art.finish()
	var terminal := SpaceInteraction.new()
	terminal.world = get_parent() as SpaceWorld
	terminal.kind = "table"
	terminal.position = Vector3(0,1,15)
	add_child(terminal)
	terminal.title = "Last Light ship orders"
	terminal.description = "Order a ship for one of the two diner ports."
	if server: return
	var sign := SignBoard.make("LAST LIGHT DINER", "brass", "", Color("ff72bb"), 1.0)
	sign.position = Vector3(0,7.1,11.8)
	add_child(sign)
	var terminal_sign := SignBoard.make("SHIP ORDERS", "brass", "", Color("56fff1"), 0.4)
	terminal_sign.position = Vector3(0,2.0,15)
	add_child(terminal_sign)
	for x in [-9,0,9]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x,3.7,0)
		lamp.light_color = Color("ffd49a")
		lamp.light_energy = 1.0
		lamp.omni_range = 13
		add_child(lamp)
	var host := CreatureModel.new("npc_baker")
	host.position = Vector3(0,0,-9)
	add_child(host)
	for i in 3:
		var npc := CreatureModel.new("npc_baker" if i==0 else "npc_traveler")
		add_child(npc)
		walkers.append(npc)

func _process(delta: float) -> void:
	clock += delta
	for i in walkers.size():
		var npc: CreatureModel = walkers[i]
		var t: float = clock*0.22+i*2.1
		npc.position = Vector3(sin(t)*4,0,-1+cos(t)*3)
		npc.rotation.y = atan2(cos(t)*4,-sin(t)*3)
		npc.animate(0.35,delta)
