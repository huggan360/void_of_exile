class_name AstralCampaign
extends RefCounted
## Server-owned campaign extension. Parts, route checkpoints and ship repairs
## live in the account book; boarding and the launch clock are ephemeral.
const ID := "theory_of_everything"
const PACK := "astral_frontier"  # Campaigns: the pack the Theory opens
const FLIGHT_SECONDS := 10.5
var campaigns: CampaignServer

func matches(run: Dictionary) -> bool:
	return run.get("id","")==ID

func data(run: Dictionary) -> Dictionary:
	if not run.has("astral"):
		run.astral={installed=[],boarded=[],resume_step=Campaigns.step_index(ID,"relays"),seed=hash(str(run.get("attempt","astral"))) & 0x7fffffff}
	return run.astral

func summary(party: Dictionary,run: Dictionary) -> Dictionary:
	if not matches(run): return {}
	var state := data(run)
	return {installed=state.installed,boarded=state.boarded,required=party.members.size(),flight=state.get("flight",{})}

func objective(party: Dictionary,run: Dictionary,step: Dictionary) -> Dictionary:
	if not matches(run): return {}
	if step.world=="dungeon": return {world=str(run.get("dungeon",""))}
	var world: GameWorld=campaigns._world_of(party.campaign.realm)
	if world==null: return {world=party.campaign.realm}
	var key := "boarding" if step.kind=="astral_board" else "mechanic"
	var at := Campaigns.resolve({astral=key},world)
	if step.kind=="astral_parts":
		var bag := GameServer.bag(int(run.get("chest",0)))
		var held: int = data(run).installed.size()
		for id: String in AstralStation.PARTS:
			if not id in data(run).installed and _carrier(party,id)!=0: held+=1
		if held<3 and not bag.is_empty(): at=bag.pos
	return {world=party.campaign.realm,pos=at}

func keep(party: Dictionary,run: Dictionary) -> void:
	if not matches(run): return
	var state := data(run)
	var realm: RealmInstance=campaigns.server.realms.get(str(run.get("dungeon","")))
	if realm and realm.world is TheoryWorld:
		state.ship=realm.world.state_wire().duplicate(true)
		# A saved open door stays open after a server restart, regardless of its old clock.
		for scene: Dictionary in state.ship.get("gates",{}).values(): scene.done=true
	if campaigns._step(run).world=="dungeon": state.resume_step=int(run.step)

func ending(party: Dictionary,run: Dictionary) -> void:
	if not matches(run): return
	keep(party,run)
	_cancel_flight(run)
	var state := data(run)
	state.boarded=[]
	var chest := GameServer.bag(int(state.get("parts_chest",0)))
	if not chest.is_empty() and chest.realm==party.campaign.realm: GameServer.remove_bag(int(chest.id))
	state.erase("parts_chest")
	if state.installed.size()==3:
		run.step=Campaigns.step_index(ID,"relaunch")
		run.count=0

func tick(party: Dictionary,run: Dictionary) -> void:
	if not matches(run) or run.status!="active": return
	var state := data(run)
	var step := campaigns._step(run)
	if step.kind=="astral_parts":
		_ensure_parts(party,run)
		_set_count(party,run,state.installed.size())
	if step.kind=="astral_board":
		var previous: Array=state.boarded.duplicate()
		state.boarded=state.boarded.filter(func(id: int) -> bool: return _at_hatch(party,id))
		if previous!=state.boarded:
			_cancel_flight(run)
			campaigns.server.social.broadcast(party)
		_set_count(party,run,state.boarded.size())
		if state.has("flight"):
			var flight: Dictionary=state.flight
			# Membership changes invalidate a launch, never silently leave someone behind.
			if flight.members!=party.members:
				_cancel_flight(run)
				campaigns.server.social.broadcast(party)
			elif Net.now()>=float(flight.end): _depart(party,run)
		elif state.boarded.size()==party.members.size() and not party.members.is_empty():
			_launch(party,run)
	if step.world!="dungeon": return
	if str(step.id)=="beyond":
		# Anyone of the party arriving in the Reach ends the tale, even after
		# the dungeon itself has closed behind them.
		for pid: int in party.members:
			if str(campaigns.server.social.record(pid).get("realm",""))==SpaceWorld.REALM:
				campaigns._advance(party,{})
				return
	var realm: RealmInstance=campaigns.server.realms.get(str(run.get("dungeon","")))
	if realm==null or not realm.world is TheoryWorld: return
	var world := realm.world as TheoryWorld
	match str(step.id):
		"relays":
			if world.ship_airlock_open: campaigns._advance(party,{})
		"expanse":
			if _party_reached(party,realm.realm_id,"wreck"): campaigns._advance(party,{})
		"repairs":
			_set_count(party,run,world.repaired_boxes.size())
			if world.repaired_boxes.size()==5: campaigns._advance(party,{})
		"unravelling":
			if _party_reached(party,realm.realm_id,"arena"): campaigns._advance(party,{})
		"convergence":
			if world.boss_defeated: campaigns._advance(party,{})

	# The tale itself continues past the Convergence in the space update.

func update_flight(party: Dictionary,run: Dictionary) -> void:
	if not matches(run) or run.get("status","")!="active": return
	var flight: Dictionary=data(run).get("flight",{})
	if not flight.is_empty() and not flight.get("sent",false) and Net.now()>=float(flight.end):
		# Revalidate at the exact departure frame as well as at the boarding tick.
		if flight.members==party.members and party.members.all(func(id: int) -> bool: return _at_hatch(party,id)):
			_depart(party,run)
		else:
			_cancel_flight(run)
			campaigns.server.social.broadcast(party)

func _set_count(party: Dictionary,run: Dictionary,value: int) -> void:
	if int(run.count)==value: return
	run.count=value
	campaigns._touch(party.campaign.account)
	campaigns.server.social.broadcast(party)

func _party_reached(party: Dictionary,realm_id: String,zone: String) -> bool:
	var world: TheoryWorld=campaigns.server.realms[realm_id].world
	for id: int in party.members:
		var p := campaigns.server.social.record(id)
		if p.get("realm","")==realm_id and not p.get("dead",true) and world.zone_at(p.pos)==zone: return true
	return false

func _carrier(party: Dictionary,item: String) -> int:
	for id: int in party.members:
		var stats := GameServer.character(id)
		if stats and not stats.find_item(item).is_empty(): return id
	return 0

func _ensure_parts(party: Dictionary,run: Dictionary) -> void:
	var realm: RealmInstance=campaigns.server.realms.get(party.campaign.realm)
	if realm==null or not realm.world is IslandWorld: return
	var existing := GameServer.bag(int(run.get("chest",0)))
	var missing: Array[Item]=[]
	for id: String in AstralStation.PARTS:
		if id in data(run).installed or _carrier(party,id)!=0: continue
		if not existing.is_empty() and existing.items.any(func(item: Variant) -> bool: return item!=null and item.id==id): continue
		missing.append(Items.make(id))
	if missing.is_empty(): return
	if not existing.is_empty():
		# Refill only a genuinely missing component (for example, a departed
		# carrier). Keep the one chest instead of littering duplicate chests.
		for item: Item in missing:
			var slot: int=existing.items.find(null)
			if slot>=0: existing.items[slot]=item
		GameServer.bag_changed.emit(int(existing.id))
	else:
		var at: Vector3=realm.world.astral_anchor("parts")+Vector3(0,0,2.2)
		run.chest=GameServer.spawn_bag(party.campaign.realm,missing,at,GameServer.PUBLIC,"story")
		data(run).parts_chest=run.chest
	campaigns._touch(party.campaign.account)
	campaigns.server.social.broadcast(party)

func action(party: Dictionary,run: Dictionary,p: Dictionary,objective_id: String) -> bool:
	if not matches(run): return false
	var step := campaigns._step(run)
	if step.kind=="astral_parts" and objective_id=="npc:astral_mechanic":
		var world: GameWorld=campaigns._world_of(party.campaign.realm)
		if world==null or p.realm!=party.campaign.realm or p.pos.distance_to(Campaigns.resolve({astral="mechanic"},world))>CampaignServer.REACH: return true
		var stats := GameServer.character(p.player_id)
		if stats==null or p.dead: return true
		var state := data(run)
		for id: String in AstralStation.PARTS:
			var place := stats.find_item(id)
			if not id in state.installed and not place.is_empty():
				stats.take(place)
				state.installed.append(id)
		campaigns._keep_items(party)
		campaigns._touch(party.campaign.account)
		run.count=state.installed.size()
		if state.installed.size()==3:
			campaigns._start_scene(party,p,step,world.astral_anchor("mechanic"))
		else:
			campaigns._start_scene(party,p,{npc="astral_mechanic",advance=false,say="I've installed %d of the three parts. Check the supply chest beside my workshop, and have whoever carries the rest bring them to me." % state.installed.size()},world.astral_anchor("mechanic"))
		campaigns.flush()
		campaigns.server.social.broadcast(party)
		return true
	if objective_id=="astral:board":
		if step.kind!="astral_board" or not _at_hatch(party,p.player_id): return true
		var state := data(run)
		if not p.player_id in state.boarded: state.boarded.append(p.player_id)
		campaigns.server.social.system(p.player_id,"Aboard the Starling. Waiting for every party member at the hatch.")
		campaigns.server.social.broadcast(party)
		return true
	return false

func _at_hatch(party: Dictionary,id: int) -> bool:
	var p := campaigns.server.social.record(id)
	var world: GameWorld=campaigns._world_of(party.campaign.realm)
	return world!=null and not p.is_empty() and p.get("joined",false) and not p.get("dead",true) and p.get("realm","")==party.campaign.realm and (p.pos as Vector3).distance_to(Campaigns.resolve({astral="boarding"},world))<7.0

func _launch(party: Dictionary,run: Dictionary) -> void:
	var state := data(run)
	var realm_id := "dng_theory_campaign_%d_%s" % [party.campaign.account,str(run.attempt)]
	var record := Dungeons.record(realm_id,ID,int(state.seed),party.campaign.realm)
	var origin: IslandWorld=campaigns.server.realms[party.campaign.realm].world
	record.origin_pos=origin.astral_anchor("boarding")+Vector3(0,0,3)
	if state.has("ship"): record.theory_state=state.ship.duplicate(true)
	if not campaigns.server.realms.has(realm_id): campaigns.server.open_realm_record(realm_id,record)
	run.dungeon=realm_id
	var start := Net.now()+1.4
	var token := hash(realm_id+str(start))
	state.flight={start=start,end=start+FLIGHT_SECONDS,token=token,members=party.members.duplicate()}
	var duration := FLIGHT_SECONDS+5
	for id: int in party.members:
		var stats := GameServer.character(id)
		if stats:
			stats.buffs.add("invincible",duration,1,"astral_launch")
			stats.buffs.add("immune",duration,1,"astral_launch")
	GameServer.begin_boss_intro(token,party.campaign.realm,party.members,duration)
	campaigns.server.social.broadcast(party)

func _cancel_flight(run: Dictionary) -> void:
	var state := data(run)
	if state.has("flight"): GameServer.cancel_boss_intro(int(state.flight.token))
	var admitted: Array=state.get("flight",{}).get("members",state.boarded)
	for id: int in admitted:
		var stats := GameServer.character(id)
		if stats:
			stats.buffs.remove("invincible","astral_launch")
			stats.buffs.remove("immune","astral_launch")
	state.erase("flight")

func _depart(party: Dictionary,run: Dictionary) -> void:
	var state := data(run)
	var flight: Dictionary=state.flight
	if flight.get("sent",false): return
	flight.sent=true
	run.step=clampi(int(state.resume_step),Campaigns.step_index(ID,"relays"),Campaigns.step_index(ID,"convergence"))
	run.count=0
	for id: int in party.members:
		var p := campaigns.server.social.record(id)
		p.dungeon_returns=p.get("dungeon_returns",{})
		p.dungeon_returns[run.dungeon]={realm=party.campaign.realm,pos=campaigns.server.realms[party.campaign.realm].world.astral_anchor("boarding")+Vector3(0,0,3)}
		campaigns.server.dungeons.grants[id]=run.dungeon
		campaigns.server.social.send_to(id,run.dungeon)
	campaigns._touch(party.campaign.account)
	campaigns.server.social.broadcast(party)

func entered(party: Dictionary,run: Dictionary,p: Dictionary) -> void:
	if not matches(run): return
	var state := data(run)
	if p.realm==run.get("dungeon",""):
		var all_arrived := true
		for id: int in party.members:
			if campaigns.server.social.record(id).get("realm","")!=p.realm: all_arrived=false
		if all_arrived:
			_cancel_flight(run)
			state.boarded=[]
	elif p.realm==party.campaign.realm and campaigns._step(run).world=="dungeon":
		keep(party,run)
		_cancel_flight(run)
		state.boarded=[]
		run.step=Campaigns.step_index(ID,"relaunch")
		run.count=0
		campaigns._touch(party.campaign.account)
