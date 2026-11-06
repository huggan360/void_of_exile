class_name CampaignClient
extends Node
## What your party's campaign puts into the world you're in (Main.campaign):
## a gold "!" over whoever the story wants you to talk to, a plain "!" over
## side quests, the things to search or take, quest markers on the minimap,
## the opening cinematic and the results at the end. The server decides
## everything (CampaignServer); this only shows it and passes on what you do.

var social: SocialClient
var main: Node  # Main: world, player, hud, fog_of_war
var cinematic := CampaignCinematic.new()
var astral_launch := AstralLaunchCinematic.new()
var _world: GameWorld
var _key := ""
var _spawned: Array[Node] = []
var _pending_fog := {}  # realm id -> [cells], until that world loads
var _pending_intro := {}  # the opening cinematic, once we're in the party's Tavern
var _dialog: SceneDialog
var _scene_speaker: TownNPC
var _route_badges := {}
var _route_timer := 0.0
var _chest_sync_timer := 0.0
var _asked := {}  # villagers already asked (key -> true)
var guide := QuestGuide.new()


func _ready() -> void:
	guide.routes_changed.connect(main.hud.minimap.set_routes)
	get_tree().node_added.connect(_villager_arrived)
	add_child(guide)
	add_child(cinematic)
	astral_launch.campaign = self
	add_child(astral_launch)
	cinematic.finished.connect(func() -> void:
		if is_instance_valid(main.hud) and not main._traveling:
			main.hud.visible = true)
	social.party_changed.connect(refresh)
	social.intro.connect(func(script: Dictionary) -> void: _pending_intro = script)
	social.campaign_done.connect(_results)
	social.pack_done.connect(_pack_card)
	social.fog.connect(_on_fog)
	social.scene.connect(_on_scene)


## A new world loaded (or the campaign changed): rebuild what it shows.
func set_world(world: GameWorld) -> void:
	astral_launch.cancel()
	_stop_scene_facing()
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	main.hud.interaction.suppressed = false
	for badge in _route_badges.values():
		if is_instance_valid(badge): badge.queue_free()
	_route_badges.clear()
	_world = world
	guide.configure(world, main.player, markers)
	_key = ""
	refresh()
	var cells: Array = _pending_fog.get(world.realm_id, [])
	_pending_fog.erase(world.realm_id)
	_on_fog(world.realm_id, cells)


func refresh() -> void:
	if not is_instance_valid(_world):
		return
	# Keep the speaker alive until all local conversation pages have been read.
	if main.hud.interaction.opened:
		if not main.hud.interaction.conversation_closed.is_connected(refresh):
			main.hud.interaction.conversation_closed.connect(refresh, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
		return
	if is_instance_valid(_dialog) and not _dialog.is_queued_for_deletion():
		if not _dialog.tree_exited.is_connected(refresh):
			_dialog.tree_exited.connect(refresh, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
		return
	var camp := social.campaign_state()
	var key := "%s|%s" % [_world.get_instance_id(), JSON.stringify([camp.get("id"), camp.get("step"), camp.get("side_step"),
			camp.get("side_done"), camp.get("done_objects"), camp.get("realm"), camp.get("status"), camp.get("npcs"), camp.get("home_progress"), camp.get("astral")])]
	if key == _key:
		return
	_key = key
	for node in _spawned:
		if is_instance_valid(node):
			if node.get_parent(): node.get_parent().remove_child(node)
			node.queue_free()
	_spawned.clear()
	_hook_gerald()
	_hook_chronicler()
	# The Chronicle Gate in the shared Tavern swirls only during an active campaign.
	if _world is HallWorld and is_instance_valid((_world as HallWorld).campaign_portal):
		(_world as HallWorld).campaign_portal.set_active(camp.get("status", "") == "active")
	if _world is CastleWorld and not camp.is_empty():
		_spawn_castle_exit(camp)
	# Gerald is available in both the public and private Tavern.
	if camp.is_empty() or not Campaigns.is_tavern(_world.realm_id) and _world.realm_id != str(camp.realm):
		_mark_npcs({}, {}, {})
		main.hud.refresh_markers()
		return
	var here_campaign: bool = _world.realm_id == str(camp.realm)
	var main_step := Campaigns.step_def(camp.id, int(camp.step))
	var side_step := Campaigns.step_def(camp.id, int(camp.side_step), true) if not camp.side_done else {}
	# The story's people in the realm, once the story has found them.
	if here_campaign:
		for npc: String in Campaigns.NPCS:
			if camp.get("npcs", {}).has(npc) if Net.is_client() else _npc_here(npc, camp):
				_spawn_npc(npc, camp)
		if camp.id == "frozen_whisper" and int(camp.step) >= Campaigns.step_index(camp.id, "halvard"):
			_spawn_cabin()
		if camp.id == "hollow_castle" and int(camp.step) >= Campaigns.step_index(camp.id, "castle"):
			_spawn_white_portal()
		if main_step.get("kind", "") == "ask_around":
			_mark_villagers(main_step)
	# Things to search or take only ever lie in the campaign realm.
	for pair: Array in [[main_step, false], [side_step, true]]:
		var step: Dictionary = pair[0]
		if here_campaign and step.get("kind", "") in ["interact", "collect"]:
			for o: Dictionary in step.objects:
				if not o.id in camp.done_objects:
					_spawn_object(o, step, pair[1])
	_mark_npcs(camp, main_step, side_step)
	main.hud.refresh_markers()


## Minimap markers for the objectives here: {pos, color, kind}.
func markers() -> Array:
	var out := []
	if is_instance_valid(_world) and Dungeons.is_dungeon(_world.realm_id): return out
	var camp := social.campaign_state()
	if camp.is_empty() or camp.get("status", "") != "active" or not is_instance_valid(_world) or not _world.is_inside_tree():
		return out  # (the old world, while a new one loads)
	var here_campaign: bool = _world.realm_id == str(camp.realm)
	for pair: Array in [[Campaigns.step_def(camp.id, int(camp.step)), "quest"],
			[Campaigns.step_def(camp.id, int(camp.side_step), true) if not camp.side_done else {}, "side"]]:
		var step: Dictionary = pair[0]
		if step.is_empty():
			continue
		var color := QuestGuide.MAIN_COLOR if pair[1] == "quest" else QuestGuide.SIDE_COLOR
		for pos: Vector3 in _objective_points(step, camp, here_campaign, pair[1] == "side"):
			if pos.is_finite(): out.append({pos = pos, color = color, kind = pair[1]})
	return out


func _objective_points(step: Dictionary, camp: Dictionary, here_campaign: bool, side := false) -> Array:
	var goal: Dictionary = camp.get("side_objective" if side else "objective", {})
	var destination := str(goal.get("world", camp.get("realm", "") if step.world == "campaign" else ("hall" if step.world == "hall" else camp.get("castle", ""))))
	if destination != "" and _route_world(destination) != _route_world(_world.realm_id):
		return _route_points(destination, camp)
	if goal.has("pos") and (goal.pos as Vector3).is_finite():
		return [goal.pos]
	var in_hall := Campaigns.is_tavern(_world.realm_id)
	if step.world == "campaign" and in_hall:
		return [_chronicle_gate()]  # it all starts through the gate
	if step.world == "hall" and not in_hall or step.world == "campaign" and not here_campaign:
		return []
	match str(step.kind):
		"talk":
			var at: Vector3 = camp.get("npcs", {}).get(step.npc, {}).get("pos", Campaigns.npc_position(step.npc, _world.realm_id, _world))
			return [at] if at != Vector3.INF else []
		"interact", "collect":
			var out := []
			for o: Dictionary in step.objects:
				if not o.id in camp.done_objects:
					out.append(Campaigns.resolve(o.at, _world))
			return out
		"kill":
			if step.has("at"): return [Campaigns.resolve(step.at, _world)]
			# Castle encounters are staged actors, without island anchors.
			var out := []
			if _world is CastleWorld:
				for enemy in _world.enemy_director.get_children():
					if enemy is Enemy and enemy.def.id in step.enemies and enemy.is_alive():
						out.append(enemy.global_position)
			return out
		"hand_over":
			var at: Vector3 = camp.get("npcs", {}).get(step.npc, {}).get("pos", Campaigns.npc_position(step.npc, _world.realm_id, _world))
			return [at] if at != Vector3.INF else []
		"set_home":
			if Net.is_client() and int(Net.client.info.get("player_id", 0)) in camp.get("home_progress", {}).get("ready", []): return []
			return [Campaigns.resolve({village = step.village}, _world)]
		"ask_around":
			return [Campaigns.resolve({village = step.village}, _world)]
		"chest":
			return [] if step.at is String else [Campaigns.resolve(step.at, _world)]
	return []


func _route_world(id: String) -> String:
	return "hall" if Campaigns.is_tavern(id) else id


## Follow the world graph one exit at a time, using server portal instances.
func _route_points(destination: String, camp: Dictionary) -> Array:
	var here := _route_world(_world.realm_id)
	var goal := _route_world(destination)
	var realm := str(camp.get("realm", ""))
	var castle := str(camp.get("castle", Campaigns.castle_id(int(camp.get("owner", 0)), str(camp.get("id", "")))))
	var links: Array = camp.get("links", []).duplicate()
	links.append_array([{from = "hall", to = realm}, {from = realm, to = "hall"}, {from = realm, to = castle}, {from = castle, to = realm}])
	if _world is DungeonWorld:
		var origin := str((_world as DungeonWorld).record.get("origin", "hall"))
		links.append({from = here, to = origin, pos = _world.spawn_point + Vector3(0, 0, 4)})
		if origin != realm and not Campaigns.is_tavern(origin): links.append({from = origin, to = "hall"})
	# An unrelated world still has its ordinary exit to the Tavern.
	if here != realm and here != castle and not Dungeons.is_dungeon(here): links.append({from = here, to = "hall"})
	var queue := [here]
	var first := {here: ""}
	while not queue.is_empty():
		var at: String = queue.pop_front()
		for edge: Dictionary in links:
			if _route_world(str(edge.from)) != at: continue
			var next := _route_world(str(edge.to))
			if first.has(next): continue
			first[next] = next if at == here else first[at]
			queue.append(next)
	var hop := str(first.get(goal, "hall"))
	var out := []
	for edge: Dictionary in links:
		if _route_world(str(edge.from)) == here and _route_world(str(edge.to)) == hop and edge.has("pos"):
			out.append(edge.pos)
	for node in _world.get_children():
		if node is Portal and node.active:
			var to := str(node.destination)
			if to == "campaign": to = realm
			if to == "castle": to = castle
			if _route_world(to) == hop: out.append(node.global_position)
	return out


func _spawn_castle_exit(camp: Dictionary) -> void:
	var at := Campaigns.open_spot(_world.spawn_point + Vector3(4, 0, 0), _world)
	if at == Vector3.INF: return
	var portal: Portal = _world._add_portal(at, Vector3.BACK, str(camp.realm), Color("aabbee"), Color.WHITE)
	_spawned.append(portal)


## Portal badges follow the same route as the minimap, including newly opened holes.
func _update_route_badges(delta: float) -> void:
	_route_timer -= delta
	if _route_timer > 0.0 or not is_instance_valid(_world): return
	_route_timer = 0.5
	var points := markers()
	for node in _world.get_children():
		if not node is Portal and not node is DungeonPortal: continue
		var marked := points.any(func(point: Dictionary) -> bool: return (point.pos as Vector3).distance_to(node.global_position) < 0.5)
		if marked and not is_instance_valid(_route_badges.get(node)):
			var badge := QuestMarker.new()
			node.add_child(badge)
			_route_badges[node] = badge
		elif not marked and is_instance_valid(_route_badges.get(node)):
			_route_badges[node].queue_free()
			_route_badges.erase(node)
	main.hud.refresh_markers()


func _npc_here(npc: String, camp: Dictionary) -> bool:
	var info: Dictionary = Campaigns.NPCS[npc]
	if info.world != "campaign" or info.get("campaign", camp.id) != camp.id:
		return false
	return not info.has("from") or int(camp.step) >= Campaigns.step_index(camp.id, info.from) or npc in camp.get("revealed", [])


## Aurelian's door to the Hollow Castle: a tall portal of white light beside him.
func _spawn_white_portal() -> void:
	var at := Campaigns.resolve({village = "Hearthwick", offset = Vector3(-6, 0, 14)}, _world)
	if at == Vector3.INF:
		return
	var portal: Portal = _world._add_portal(at, Vector3.BACK, "castle", Color(1, 1, 1), Color(0.82, 0.88, 1.0))
	portal.scale = Vector3.ONE * 1.6
	var light := OmniLight3D.new()
	light.light_color = Color(0.9, 0.94, 1.0)
	light.light_energy = 3.0
	light.omni_range = 14.0
	light.position.y = 3.0
	portal.add_child(light)
	_spawned.append(portal)


## Halvard's cabin at the foot of the mountain: log walls, a roof, a door.
func _spawn_cabin() -> void:
	var at := Campaigns.resolve({cabin = "Snowbell"}, _world)
	if at == Vector3.INF:
		return
	var cabin := Node3D.new()
	cabin.position = at
	if cabin.position == Vector3.INF:
		cabin.free()
		return
	var log := StandardMaterial3D.new()
	log.albedo_color = Color(0.42, 0.28, 0.17)
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.85, 0.9, 0.95)
	for spec: Array in [[Vector3(0, 1.2, 0), Vector3(5, 2.4, 4), log], [Vector3(0, 2.9, 0), Vector3(5.8, 1.0, 4.8), roof],
			[Vector3(0, 3.6, 0), Vector3(4.2, 0.6, 3.6), roof], [Vector3(0, 0.9, 2.02), Vector3(1.0, 1.8, 0.1), roof]]:
		var mesh := BoxMesh.new()
		mesh.size = spec[1]
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = spec[2]
		part.position = spec[0]
		cabin.add_child(part)
	_world.add_child(cabin)
	_spawned.append(cabin)


## Every villager of the town wears a "?": any member can ask (once each).
func _mark_villagers(step: Dictionary) -> void:
	for node in _world.find_children("*", "InteractionTarget", true, false):
		_mark_villager(node as InteractionTarget, step)


## Villagers stream in with their chunk: mark them as they arrive too.
func _villager_arrived(node: Node) -> void:
	if not node is InteractionTarget or not is_instance_valid(_world) or not _world.is_ancestor_of(node): return
	var camp := social.campaign_state()
	if camp.is_empty(): return
	var step := Campaigns.step_def(camp.id, int(camp.step))
	if step.get("kind", "") == "ask_around":
		_mark_villager.call_deferred(node, step)  # the TownNPC parent is set up by then


func _mark_villager(target: InteractionTarget, step: Dictionary) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree(): return
	if not target.title.ends_with(" of %s" % step.village) or target.title.begins_with("Steward") or not target.get_parent() is TownNPC:
		return
	var key := _villager_key(target)
	if _asked.has(key) or target.get_parent().get_children().any(func(c: Node) -> bool: return c is QuestMarker and not c.is_queued_for_deletion()):
		return
	var marker := QuestMarker.new("turn_in")
	target.get_parent().add_child(marker)
	_spawned.append(marker)
	target.response = "Hm?"
	if not target.has_meta(&"ask_hooked"):
		target.set_meta(&"ask_hooked", true)
		target.activated.connect(func(_p: Node3D) -> void:
			var camp := social.campaign_state()
			if not camp.is_empty() and Campaigns.step_def(camp.id, int(camp.step)).get("kind", "") == "ask_around" and not _asked.has(key):
				_asked[key] = true
				social.quest("ask:" + key))


static func _villager_key(target: InteractionTarget) -> String:
	var npc := target.get_parent() as TownNPC
	return "%s@%d,%d" % [target.title, int(npc.spec.pos.x), int(npc.spec.pos.z)]


func _chronicle_gate() -> Vector3:
	for child in _world.get_children():
		if child is Portal and (child as Portal).destination == "campaign":
			return child.global_position
	return Vector3.ZERO


# --- In the world ------------------------------------------------------------------------

## Gerald (in the Tavern) tells his part of the story when it's his turn.
func _hook_gerald() -> void:
	var target := _npc_target("Gerald the Gardener")
	if target == null or target.has_meta(&"quest_hooked"):
		return
	target.set_meta(&"quest_hooked", true)
	target.set_meta(&"greeting", target.response)
	target.activated.connect(func(_p: Node3D) -> void: _talked("gerald"))


## The Chronicler by the Grand Tavern opens the book of campaigns.
func _hook_chronicler() -> void:
	var target := _npc_target("Aldous the Chronicler")
	if target == null or target.has_meta(&"quest_hooked"):
		return
	target.set_meta(&"quest_hooked", true)
	target.activated.connect(func(_p: Node3D) -> void:
		if Net.is_client():
			_open_from_conversation(CampaignBrowser.new(social))
		else:
			main.hud.toasts.push("Tales are told online: play Singleplayer or join a server.", UIStyle.TEXT_DIM, 3.0))


## The book of campaigns from any other board (the Nexus campaign board).
func open_book() -> void:
	if Net.is_client(): _open_from_conversation(CampaignBrowser.new(social))
	else: main.hud.toasts.push("Tales are told online: play Singleplayer or join a server.", UIStyle.TEXT_DIM, 3.0)


## A panel an npc opens lives as long as the conversation, both ways.
func _open_from_conversation(panel: Control) -> void:
	var card: InteractionCard = main.hud.interaction
	main.hud.add_centered(panel)
	card.hide()  # the book/shop supplies its own close action
	var end := func() -> void:
		if is_instance_valid(panel): panel.queue_free()
	card.conversation_closed.connect(end, CONNECT_ONE_SHOT)
	panel.tree_exiting.connect(func() -> void:
		if card.conversation_closed.is_connected(end): card.conversation_closed.disconnect(end)
		if card.opened: card.close())


func _npc_target(title: String) -> InteractionTarget:
	for node in _world.find_children("*", "InteractionTarget", true, false):
		if (node as InteractionTarget).title == title:
			return node
	return null


## Puts the right "!" over the npcs here, and their lines for this step.
func _mark_npcs(camp: Dictionary, main_step: Dictionary, side_step: Dictionary) -> void:
	for npc: String in Campaigns.NPCS:
		var info: Dictionary = Campaigns.NPCS[npc]
		var target := _npc_target(info.name)
		if target == null:
			continue
		var kind := ""
		var say := ""
		if camp.is_empty():
			pass
		elif main_step.get("kind", "") in ["talk", "hand_over", "astral_parts"] and main_step.npc == npc:
			kind = "turn_in" if main_step.kind == "hand_over" else "main"
			say = "Let me check the parts you brought." if main_step.kind=="astral_parts" else main_step.say
			# Only whoever carries it can hand it over; the others hear a sigh.
			if main_step.kind == "hand_over" and main.stats.find_item(main_step.item).is_empty():
				say = main_step.lack
			elif main_step.get("shared", false):
				say = "..."  # the party hears it together
		elif side_step.get("kind", "") == "talk" and side_step.npc == npc:
			kind = "side"
			say = side_step.say
		target.response = say if say != "" else str(target.get_meta(&"greeting", target.response))
		if kind != "":
			var marker := QuestMarker.new(kind)
			target.get_parent().add_child(marker)
			_spawned.append(marker)


func _talked(npc: String) -> void:
	var camp := social.campaign_state()
	if camp.is_empty():
		return
	for step: Dictionary in [Campaigns.step_def(camp.id, int(camp.step)),
			Campaigns.step_def(camp.id, int(camp.side_step), true) if not camp.side_done else {}]:
		if step.get("kind", "") in ["talk", "hand_over", "astral_parts"] and step.npc == npc:
			social.quest("npc:" + npc)
			return


func _spawn_npc(npc: String, camp: Dictionary) -> void:
	var info: Dictionary = Campaigns.NPCS[npc]
	var state: Dictionary = camp.get("npcs", {}).get(npc, {})
	if Net.is_client() and state.is_empty():
		return
	var at: Vector3 = state.get("pos", Campaigns.resolve(info.at, _world) if not Net.is_client() else Vector3.INF)
	var island := _world as IslandWorld
	if at == Vector3.INF or island == null:
		return
	var navigation: TownNavigation = island._town_navigation.get(str(info.at.get("village", info.at.get("cabin", ""))))
	if navigation == null and not island._town_navigation.is_empty():
		navigation = island._town_navigation.values()[0]
	var model := str(info.get("model", "npc_gardener"))
	var toward := _world.spawn_point - at
	if navigation:
		toward = Vector3(navigation.town.center.x + 0.5, at.y, navigation.town.center.y + 0.5) - at
	var person := TownNPC.new().setup({role = model.trim_prefix("npc_"), pos = at, stationary = true, seed = hash(npc), route = [at],
		yaw = state.get("yaw", atan2(-toward.x, -toward.z)), title = info.name, story = true, mirror = Net.is_client(), ground = _world.ground_height}, navigation)
	_world.add_child(person)
	_spawned.append(person)
	var target := InteractionTarget.new()
	target.title = info.name
	target.description = "Talk to %s" % info.name.split(" ")[0]
	target.action_text = "Talk"
	target.response = str(info.get("greeting","Bless the gate, more visitors. Mind the hoppers."))
	target.portrait = load("res://creatures/%s/portrait.png" % model)
	target.set_meta(&"greeting", target.response)
	target.activated.connect(func(_p: Node3D) -> void: _talked(npc))
	person.add_child(target)


## Something to search or take: it glows, wears a "!", and goes once used.
func _spawn_object(o: Dictionary, step: Dictionary, side: bool) -> void:
	var at := Campaigns.resolve(o.at, _world)
	if at == Vector3.INF:
		return
	var root := Node3D.new()
	root.position = at
	_world.add_child(root)
	_spawned.append(root)
	if str(o.get("look", "")) == "bell":  # a green-bronze bell hung on a post
		for spec: Array in [[Vector3(0, 1.2, 0), Vector3(0.2, 2.4, 0.2), Color("3a2a22")], [Vector3(0, 1.9, 0), Vector3(0.9, 0.9, 0.9), Color("4f8f7a")]]:
			var part := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = spec[1]
			part.mesh = box
			var paint := StandardMaterial3D.new()
			paint.albedo_color = spec[2]
			part.material_override = paint
			part.position = spec[0]
			root.add_child(part)
	elif str(o.get("look", "")) == "stone":  # a black monolith with a faint violet breath
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 2.6, 0.6)
		slab.mesh = box
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("0c0a10")
		paint.emission_enabled = true
		paint.emission = Color("3a1a55")
		paint.emission_energy_multiplier = 0.4
		slab.material_override = paint
		slab.position.y = 1.3
		root.add_child(slab)
	elif str(o.id).begins_with("brazier"):  # a cold stone bowl, waiting to be relit
		for spec: Array in [[Vector3(0, 0.4, 0), Vector3(0.5, 0.8, 0.5)], [Vector3(0, 0.9, 0), Vector3(1.1, 0.3, 1.1)]]:
			var part := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = spec[1]
			part.mesh = box
			part.position = spec[0]
			root.add_child(part)
	elif step.kind == "interact":
		var flowers := Obstacle.new().setup("", ObstacleLibrary.get_prefab("decor_flowers"), _world.biome_at(at), true)
		flowers.scale = Vector3.ONE * 1.6
		root.add_child(flowers)
	else:
		var item := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 0.32
		item.mesh = mesh
		var glow := StandardMaterial3D.new()
		var tint := Color(1.0, 0.85, 0.95) if o.id == "last_bulb" else Color(1.0, 0.8, 0.3)
		glow.albedo_color = tint
		glow.emission_enabled = true
		glow.emission = tint
		glow.emission_energy_multiplier = 1.4
		item.material_override = glow
		item.position.y = 0.7
		item.rotation = Vector3(0.6, 0.0, 0.6)
		root.add_child(item)
		item.create_tween().set_loops().tween_property(item, "rotation:y", TAU, 3.0).as_relative()
		var light := OmniLight3D.new()
		light.light_color = tint
		light.light_energy = 0.9
		light.omni_range = 3.5
		light.position.y = 0.9
		root.add_child(light)
	var marker := QuestMarker.new("side" if side else "main")
	root.add_child(marker)
	var target := InteractionTarget.new()
	target.title = str(o.name)
	target.description = Campaigns.objective_text(step, 0).split(" (")[0]
	target.action_text = str(step.get("verb", "Use"))
	target.response = str(o.get("found", "")).replace("%s", "You").replace("You took", "You take").replace("You found", "You find")
	target.reach = 3.0
	target.activated.connect(func(_p: Node3D) -> void: social.quest("obj:" + str(o.id)))
	root.add_child(target)


# --- Scenes the party shares -------------------------------------------------------------

func _stop_scene_facing() -> void:
	if is_instance_valid(_scene_speaker):
		_scene_speaker.listen_to(null)
	_scene_speaker = null


## Shared scenes also face the listener on each client, without changing server yaw.
func _face_scene_speaker() -> void:
	if not is_instance_valid(_dialog) or _dialog.is_queued_for_deletion():
		_stop_scene_facing()
		return
	if not is_instance_valid(_world) or not _dialog.focus_camera or _dialog.scene.get("kind", "") != "talk":
		return
	if not is_instance_valid(_scene_speaker):
		var target := _npc_target(str(_dialog.scene.get("title", "")))
		if target and target.get_parent() is TownNPC:
			_scene_speaker = target.get_parent() as TownNPC
	if is_instance_valid(_scene_speaker):
		_scene_speaker.listen_to(main.player)


func _on_scene(ev: Array) -> void:
	match str(ev[0]):
		"camp_scene":
			_stop_scene_facing()
			if is_instance_valid(_dialog):
				_dialog.queue_free()
			main.hud.interaction.close()
			main.hud.interaction.suppressed = true
			_dialog = SceneDialog.new()
			_dialog.social = social
			_dialog.player = main.player
			_dialog.my_id = main.player.player_id
			_dialog.scene = ev[1]
			_dialog.focus_camera = is_instance_valid(_world) and str(_dialog.scene.get("world", _world.realm_id)) == _world.realm_id
			main.hud.add_dialog(_dialog)
		"camp_scene_page":
			if is_instance_valid(_dialog):
				_dialog.show_page(int(ev[1]))
		"camp_scene_end":
			_stop_scene_facing()
			main.hud.interaction.suppressed = false
			if is_instance_valid(_dialog):
				_dialog.queue_free()
		"camp_answer":  # a villager answered (or ran off)
			for node in _world.find_children("*", "InteractionTarget", true, false):
				if _villager_key(node) == str(ev[1]) if node.get_parent() is TownNPC else false:
					var npc := node.get_parent() as TownNPC
					SpeechBubble.say(npc, TextMarkup.plain(str(ev[2])), "say", 2.2)
					social.add_line("npc", (node as InteractionTarget).title.split(" of ")[0], 0, str(ev[2]))
					if bool(ev[3]):
						npc.flee_from(main.player.global_position)
					_asked[str(ev[1])] = true
					_key = ""
					refresh()
					return


# --- Fog shared by the party ------------------------------------------------------------

func _on_fog(realm_id: String, cells: Array) -> void:
	if cells.is_empty():
		return
	if not is_instance_valid(_world) or _world.realm_id != realm_id:
		_pending_fog[realm_id] = _pending_fog.get(realm_id, []) + cells
		return
	for cell in cells:
		var at := SocialServer.fog_point(int(cell))
		main.fog_of_war.reveal_at(at)
		main.hud.minimap.reveal_at(at)


# --- The story's bookends -----------------------------------------------------------------

## The opening plays once everyone has arrived in the party's Tavern.
func _process(_delta: float) -> void:
	astral_launch.update(social.campaign_state(),_world)
	if _world is TheoryWorld:
		var camp := social.campaign_state()
		var key := str(Campaigns.step_def(str(camp.get("id","")),int(camp.get("step",0))).get("id",""))
		if (_world as TheoryWorld).electrical_quest!=key:
			(_world as TheoryWorld).electrical_quest=key
			(_world as TheoryWorld)._update_electrical_visuals(false)
	_face_scene_speaker()
	_update_route_badges(_delta)
	_chest_sync_timer -= _delta
	if Net.is_client() and _chest_sync_timer <= 0.0 and is_instance_valid(_world):
		_chest_sync_timer = 2.0
		var camp := social.campaign_state()
		var chest := int(camp.get("chest", 0))
		if chest > 0 and camp.get("objective", {}).get("world", "") == _world.realm_id and GameServer.bag(chest).is_empty():
			social.campaign(["sync_chest"])
	if _pending_intro.is_empty() or main._traveling or main._dead or main.player.frozen or not is_instance_valid(_world):
		return
	if not _world.realm_id.begins_with("ctav_") and not _pending_intro.get("anywhere", false):
		return
	var script := _pending_intro
	_pending_intro = {}
	main.hud.visible = false
	if script.get("show_map", false):
		await _show_full_map()
	cinematic.play(main.player, _staged(script))


## The six map pieces fitted together, held up for a few seconds.
func _show_full_map() -> void:
	var map := Items.make("story_clue")
	map.count = 6
	StoryReader.open(map)
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(StoryReader._layer):
		for child in StoryReader._layer._ui_root.get_children():
			child.queue_free()


## A cutscene with a stage: its scene is loaded far below this world for the
## shots (named by its markers) and freed when it ends.
func _staged(script: Dictionary) -> Dictionary:
	if not script.has("stage") or not ResourceLoader.exists(str(script.stage)):
		var plain := script.duplicate(true)
		_village_shots(plain)
		return plain
	var stage: Node3D = load(str(script.stage)).instantiate()
	stage.position = script.get("stage_offset", Vector3(0, -600, 0))
	main.add_child(stage)
	cinematic.finished.connect(stage.queue_free, CONNECT_ONE_SHOT)
	var out := script.duplicate(true)
	_village_shots(out)
	var mark := func(name: String) -> Vector3:
		var node := stage.find_child(name, true, false) as Node3D
		return node.global_position if node else stage.global_position
	for shot: Dictionary in out.shots:
		if shot.has("from_marker"):
			shot.from = mark.call(shot.from_marker)
			shot.to = mark.call(shot.to_marker)
			shot.look_from = mark.call(shot.look_marker)
			shot.look_to = shot.look_from
	return out


## Shots over towns ({village}): a slow glide down toward each town's heart,
## with fireworks over it when the cutscene asks for them.
func _village_shots(script: Dictionary) -> void:
	for shot: Dictionary in script.get("shots", []):
		if not shot.has("village"):
			continue
		var c := Campaigns.resolve({village = shot.village}, _world)
		if c == Vector3.INF:
			c = main.player.global_position
		shot.from = c + Vector3(38, 28, 38)
		shot.to = c + Vector3(16, 14, 22)
		shot.look_from = c + Vector3.UP * 3.0
		shot.look_to = shot.look_from
		if script.get("fireworks", false):
			_fireworks(c + Vector3.UP * 16.0)


func _fireworks(at: Vector3) -> void:
	for color: Color in [Color("ffd35a"), Color("ff6a8a"), Color("7ee0ff"), Color("b58cff")]:
		var burst := CPUParticles3D.new()
		burst.amount = 60
		burst.lifetime = 1.6
		burst.explosiveness = 0.95
		burst.direction = Vector3.UP
		burst.spread = 180.0
		burst.initial_velocity_min = 6.0
		burst.initial_velocity_max = 11.0
		burst.gravity = Vector3(0, -4, 0)
		var dot := BoxMesh.new()
		dot.size = Vector3.ONE * 0.25
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = color
		dot.material = glow
		burst.mesh = dot
		burst.position = at + Vector3(randf_range(-8, 8), randf_range(-3, 4), randf_range(-8, 8))
		main.add_child(burst)
		cinematic.finished.connect(burst.queue_free, CONNECT_ONE_SHOT)


## The first time a whole pack is told: its own card, after the tale's.
func _pack_card(bonus: Dictionary) -> void:
	await get_tree().create_timer(1.0).timeout
	while is_instance_valid(main.hud) and main.hud.get_child(0).get_children().any(func(c: Node) -> bool: return c.has_meta(&"campaign_splash")):
		await get_tree().create_timer(0.5).timeout
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.ACCENT))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	for line: Array in [["CAMPAIGN PACK COMPLETE", 40, UIStyle.ACCENT], [str(bonus.title), 30, UIStyle.GOLD],
			["+%d XP" % int(bonus.xp), UIStyle.SIZE_LARGE, UIStyle.XP],
			["+%s Dots" % Dots.format(int(bonus.dots)) if int(bonus.get("dots", 0)) > 0 else "", UIStyle.SIZE_LARGE, Dots.COLOR],
			["Reward: %s (in your backpack)" % bonus.item if str(bonus.item) != "" else "", UIStyle.SIZE_NORMAL, UIStyle.TEXT],
			["A reward for telling the whole story, given only once.", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM]]:
		if str(line[0]) == "":
			continue
		var label := UIStyle.label(str(line[0]), int(line[1]), line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	var ok := UIStyle.button("Wonderful")
	column.add_child(ok)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	ok.pressed.connect(center.queue_free)
	main.hud.add_dialog(center)


## The end: the five stars, which were earned, and the time (after any cutscene).
func _results(result: Dictionary) -> void:
	await get_tree().process_frame
	while cinematic.is_playing() or not _pending_intro.is_empty():
		await get_tree().create_timer(0.5).timeout
	var def := Campaigns.get_def(str(result.id))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	GameAudio.play("campaign_complete",Vector3.INF,{priority=3})
	var banner := UIStyle.heading("CAMPAIGN COMPLETE", 44)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(banner)
	var title := UIStyle.heading(str(result.title), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	if int(result.get("xp", 0)) > 0:
		var xp := UIStyle.label("+%d XP" % int(result.xp), UIStyle.SIZE_LARGE, UIStyle.XP)
		xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(xp)
	var sub := UIStyle.label("The tale is told  -  %d:%02d" % [int(result.elapsed) / 60, int(result.elapsed) % 60], UIStyle.SIZE_NORMAL, UIStyle.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	var stars := StarRow.new(5.0)
	stars.set_stars(result.stars)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(stars)
	var defs: Array = def.get("stars", [])
	for i in defs.size():
		var got: bool = result.stars[i] if i < result.stars.size() else false
		column.add_child(UIStyle.label(("Earned:  " if got else "Missed:  ") + str(defs[i].text), UIStyle.SIZE_SMALL,
				UIStyle.GOLD if got else UIStyle.TEXT_DIM))
	column.add_child(UIStyle.label("Your loot waits where you left it.", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
	var close := UIStyle.button("Continue")
	column.add_child(close)
	# A full-screen splash: the world dims, gold motes rise behind the card.
	var splash := Control.new()
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.add_child(dim)
	var motes := CPUParticles2D.new()
	motes.amount = 90
	motes.lifetime = 4.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(900, 10)
	motes.position = Vector2(960, 1100)
	motes.direction = Vector2.UP
	motes.spread = 25.0
	motes.initial_velocity_min = 120.0
	motes.initial_velocity_max = 260.0
	motes.gravity = Vector2.ZERO
	motes.scale_amount_min = 4.0
	motes.scale_amount_max = 9.0
	motes.color = UIStyle.GOLD
	splash.add_child(motes)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	splash.add_child(center)
	splash.modulate.a = 0.0
	splash.create_tween().tween_property(splash, "modulate:a", 1.0, 0.6)
	close.pressed.connect(splash.queue_free)
	splash.set_meta(&"campaign_splash", true)
	main.hud.add_dialog(splash)
