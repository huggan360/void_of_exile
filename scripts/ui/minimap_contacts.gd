class_name MinimapContacts
extends RefCounted
## Shared live contacts for every minimap. Discovery lasts for this world visit.
const ENEMY := Color("ff454f")
const PARTY := Color("65ed83")
const FRIEND := Color("8fdcff")
const INTERACT := Color("315bd4")
var discovered := {}  # instance id -> weak reference, avoiding reused ids
var enemies: Array[WeakRef] = []
var people: Array[WeakRef] = []
var targets: Array[WeakRef] = []
var refresh := 0.0
var source: GameWorld

func update(world: GameWorld, player: Player, social: SocialClient, delta: float, fog: FogOfWar = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(world) or not is_instance_valid(player): return result
	if source!=world:
		source = world
		discovered.clear()
		refresh = 0.0
	refresh -= delta
	var discover_now: bool = refresh<=0.0
	if discover_now:
		refresh = 0.5
		for id: int in discovered.keys():
			if discovered[id].get_ref()==null: discovered.erase(id)
		enemies.clear()
		people.clear()
		targets.clear()
		for node: Node in world.get_tree().get_nodes_in_group("realm_creatures"):
			if node is Enemy and world.is_ancestor_of(node): enemies.append(weakref(node))
		for node: Node in world.get_tree().get_nodes_in_group("remote_players"):
			if world.is_ancestor_of(node): people.append(weakref(node))
		for node: Node in world.get_tree().get_nodes_in_group("interaction_targets"):
			if node is InteractionTarget and world.is_ancestor_of(node): targets.append(weakref(node))
	for ref: WeakRef in enemies:
		var enemy := ref.get_ref() as Enemy
		if not is_instance_valid(enemy) or not enemy.is_alive() or not enemy.is_visible_in_tree() or not is_instance_valid(enemy.model) or not enemy.model.visible: continue
		var id: int = enemy.get_instance_id()
		var explored: bool = not is_instance_valid(fog) or not world.biome_at(enemy.global_position).fog_of_war_enabled or fog.explored_at(enemy.global_position)
		if explored and discover_now and not discovered.has(id) and enemy.global_position.distance_to(player.global_position)<32.0:
			var from: Vector3 = player.global_position+player.up_direction*1.0
			var to: Vector3 = enemy.global_position+enemy.up_direction*0.8
			var ray := PhysicsRayQueryParameters3D.create(from,to,Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
			if player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): discovered[id] = ref
		if discovered.has(id) and discovered[id].get_ref()==enemy:
			result.append({pos = enemy.global_position, color = ENEMY, kind = "contact"})
	for ref: WeakRef in people:
		var actor := ref.get_ref() as RemotePlayer
		if not is_instance_valid(actor) or not actor.is_visible_in_tree(): continue
		var color := Color.WHITE
		var same_party := false
		if is_instance_valid(social):
			for member: Dictionary in social.party.get("members", []):
				if int(member.get("player_id", 0))==actor.player_id:
					same_party = true
		var actor_name: String = actor.status_visuals.player_name
		if same_party: color = PARTY
		elif Account.is_friend(actor_name): color = FRIEND
		result.append({pos = actor.global_position, color = color, kind = "contact"})
	# Deduplicate interactions within a metre (NPCs can offer several actions).
	var occupied := {}
	for ref: WeakRef in targets:
		var target := ref.get_ref() as InteractionTarget
		if not is_instance_valid(target) or not target.enabled or not target.is_visible_in_tree(): continue
		if target.global_position.distance_to(player.global_position)>160.0: continue
		var cell := Vector3i(target.global_position.round())
		if occupied.has(cell): continue
		occupied[cell] = true
		result.append({pos = target.global_position, color = INTERACT, kind = "contact"})
	return result
