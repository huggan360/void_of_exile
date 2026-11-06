extends Node
## Account-free authority check for the new route. No network or account saves.
class MemoryCampaign extends CampaignServer:
	func flush() -> void: pass
class CaptureSocial extends SocialServer:
	var events: Array=[]
	func send(id: int,event: Array) -> void: events.append([id,event])
var checks := 0
var failures := 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		push_error("ASTRAL FAILED: "+message)
		failures+=1

func _ready() -> void:
	if "--preview" in OS.get_cmdline_user_args():
		await _preview()
		return
	var server := NetServer.new()
	server.config=ServerConfig.new()
	server.set_process(false);server.set_physics_process(false)
	server.social.free();server.campaigns.free()
	var social := CaptureSocial.new()
	var campaigns := MemoryCampaign.new()
	server.social=social;server.campaigns=campaigns
	social.server=server;campaigns.server=server;server.dungeons.server=server
	campaigns.set_process(false)
	add_child(server);server.add_child(social);server.add_child(campaigns)
	server.set_process(false);server.set_physics_process(false)
	social.set_process(false);campaigns.set_process(false)
	var a := GameServer.add_player(PlayerStats.new())
	var b := GameServer.add_player(PlayerStats.new())
	var p := {player_id=a,account_id=900001,peer_id=20,name="Crew A",realm="hall",joined=true,dead=false,pos=Vector3.ZERO}
	var q := {player_id=b,account_id=900002,peer_id=30,name="Crew B",realm="hall",joined=true,dead=false,pos=Vector3.ZERO}
	server.peers={20:p,30:q};server.by_player={a:20,b:30}
	var party := social.ensure_party(p)
	party.members.append(b);social.party_of[b]=party.id
	campaigns.start(p,AstralCampaign.ID)
	var run := campaigns._run_of(party)
	check(run.step==0 and Campaigns.world_key(run.id)=="astral_frontier","independent campaign pack begins at Realm 1")
	var realm := campaigns.open_realm(party)
	var island: IslandWorld=realm.world
	check(island.astral_site.is_finite() and island.biome_at(island.astral_site).id==Biomes.WOODS,"launch station has a woodland clearing")
	print("[astral] station=",island.astral_site)
	p.realm=realm.realm_id;q.realm=realm.realm_id
	GameServer.enter_realm(a,p.realm);GameServer.enter_realm(b,q.realm)
	campaigns.on_entered(p)
	check(campaigns._step(run).id=="mechanic","Chronicle Gate advances to mechanic")
	p.pos=island.astral_anchor("mechanic");q.pos=p.pos
	campaigns.quest(p,"npc:astral_mechanic")
	campaigns._scene_done(party)
	check(campaigns._step(run).id=="parts","mechanic requests three parts")
	var chest := GameServer.bag(run.chest)
	check(chest.items.filter(func(item: Item) -> bool: return item!=null).size()==3,"one shared chest contains all three distinct rocket parts")
	GameServer.character(a).give([Items.make(AstralStation.PARTS[0]),Items.make(AstralStation.PARTS[1])])
	GameServer.character(b).give([Items.make(AstralStation.PARTS[2])])
	campaigns.quest(p,"npc:astral_mechanic");campaigns._scene_done(party)
	check(campaigns.astral.data(run).installed.size()==2 and campaigns._step(run).id=="parts","partial deliveries persist without advancing")
	campaigns.quest(q,"npc:astral_mechanic");campaigns._scene_done(party)
	check(campaigns._step(run).id=="board","both party members can contribute parts")
	p.pos=island.astral_anchor("boarding");q.pos=p.pos
	campaigns.quest(p,"astral:board");campaigns.astral.tick(party,run)
	check(not campaigns.astral.data(run).has("flight"),"one boarded member cannot launch without the other")
	campaigns.quest(q,"astral:board");campaigns.astral.tick(party,run)
	var state := campaigns.astral.data(run)
	check(state.has("flight") and state.flight.members==party.members,"everyone aboard starts a shared future launch clock")
	check(GameServer.intro_protected(a) and GameServer.character(a).buffs.has_effect("immune"),"launch protects the crew from damage and debuffs")
	state.flight.end=Net.now()-0.01
	campaigns.astral.tick(party,run)
	check(server.dungeons.grants[a]==run.dungeon and server.dungeons.grants[b]==run.dungeon,"both crew members receive travel grants")
	check(campaigns._step(run).id=="relays","launch arrives at the Aurora relay quest")
	var space: TheoryWorld=server.realms[run.dungeon].world
	p.realm=run.dungeon;q.realm=run.dungeon
	GameServer.enter_realm(a,p.realm);GameServer.enter_realm(b,q.realm)
	campaigns.on_entered(p);campaigns.on_entered(q)
	check(space.layout.puzzles.is_empty() and not space.surfaces.has("gate_0"),"both remaining minigames and the blocking floor-lock door are removed")
	space._operate_electrical_box(space._ship_relay,a,TheoryLayout.ELECTRICAL_POSITIONS[space._ship_relay])
	campaigns.astral.tick(party,run)
	check(campaigns._step(run).id=="expanse","airlock relay advances the shared campaign")
	p.pos=Vector3(0,0,-486)
	campaigns.astral.tick(party,run)
	check(campaigns._step(run).id=="repairs","reaching wreck starts all five repair objectives")
	for index in range(5,10):
		var at: Vector3=TheoryLayout.ELECTRICAL_POSITIONS[index]
		check(at.y<2 and absf(at.x)<7,"wreck cabinet is visible from the lower central corridor")
		space._operate_electrical_box(index,a,at)
	campaigns.astral.tick(party,run)
	check(campaigns._step(run).id=="unravelling","all five shared repairs unlock the final crossing")
	p.pos=TheoryLayout.ARENA
	campaigns.astral.tick(party,run)
	check(campaigns._step(run).id=="convergence" and run.status=="active","arena arrival waits for future boss content rather than awarding a false victory")
	var original_dungeon: String=run.dungeon
	campaigns._pause(party,"fixture pause")
	check(run.status=="paused" and campaigns._step(run).id=="relaunch" and party.campaign.is_empty(),"pause saves the checkpoint and requires a fresh launch")
	check(run.astral.installed.size()==3 and run.astral.ship.electrical.repaired.size()==5,"installed parts and every repaired circuit survive pause")
	check(not server.realms.has(original_dungeon) and social.events.any(func(ev: Array) -> bool: return ev[0]==a and ev[1][0]=="goto" and ev[1][1]=="hall"),"pause evicts the party and closes the space instance")
	campaigns.start(p,AstralCampaign.ID)
	check(campaigns._step(run).id=="relaunch" and run.astral.boarded.is_empty(),"resume returns to the mechanic without recollecting parts")
	var restored := TheoryWorld.new(Dungeons.record("dng_restore",AstralCampaign.ID,run.astral.seed))
	restored.apply_state(JSON.parse_string(JSON.stringify(run.astral.ship)))
	check(restored.repaired_boxes.size()==5 and restored.ship_airlock_open,"saved ship state survives the account JSON format")
	restored.enemy_director.free()
	restored.free()
	print("[astral] ",checks," checks, failures=",failures)
	GameServer.remove_player(a);GameServer.remove_player(b)
	server.api.free();server.dungeons.free();server.economy.free()
	server.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func _preview() -> void:
	var record := {id="camp_preview_astral_frontier",seed=WorldServer.MAP_SEED,destroyed=[],astral_station=true}
	var world := IslandWorld.new(record)
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-30,0)
	light.light_energy=1.4
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("233842")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("a5c2cf")
	environment.environment.ambient_light_energy=0.65
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled=true
	add_child(environment)
	var viewer := VoxelViewer.new()
	viewer.position=world.astral_site
	viewer.view_distance=160
	add_child(viewer)
	var camera := Camera3D.new()
	camera.far=800
	add_child(camera)
	var sky := Sky.new()
	sky.process_mode=Sky.PROCESS_MODE_REALTIME
	var sky_material := ShaderMaterial.new()
	sky_material.shader=preload("res://shaders/astral_launch_sky.gdshader")
	sky.sky_material=sky_material
	environment.environment.background_mode=Environment.BG_SKY
	environment.environment.sky=sky
	camera.position=world.astral_site+Vector3(48,28,48)
	camera.look_at(world.astral_site+Vector3(0,6,-3))
	camera.make_current()
	world.update_streaming(world.astral_site)
	for i in 120:
		world.update_streaming(world.astral_site)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/void_astral_station.png")
	world.astral_station.flight={start=Net.now()-4.8}
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/void_astral_liftoff.png")
	get_tree().quit()
