extends Node3D
## Boss-only signatures, mixed chests, bounded damage patterns, local/remote
## projectile lifetimes and actual equippable appearances.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	GameAudio._disabled = true
	GameAudio.set_process(false)
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	_catalog()
	_chests()
	await _shots()
	await _fireworks()
	_appearances()
	_remote_appearance()
	await get_tree().process_frame
	print("SIGNATURE ITEMS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _catalog() -> void:
	check(Items.BOSS_LEGENDARY_ITEMS.size() == 29, "Legendary gear covers 29 bosses")
	for boss_id: String in Items.BOSS_LEGENDARY_ITEMS:
		var boss := Enemies.get_def(boss_id)
		check(boss is BossDef, "Legendary source is a boss: " + boss_id)
		var ids := Items.legendary_ids_for(boss_id)
		check(ids.size() >= 1 and ids.size() <= 2, "One or two Legendary items: " + boss_id)
		for id: String in ids: check(Loot._allowed(boss, Items.make(id)), "Boss may drop its signature: " + id)
	for row: Dictionary in SignatureItems.definitions():
		var item := Items.make(row.id)
		check(item != null and item.badge() == row.rarity, "Signature identity: " + str(row.id))
		check(item.soulbound() and item.bag_type() == "black", "Black and soulbound: " + item.id)
		check(is_equal_approx(Items.signature_chance(item), float(row.chance)), "Item-specific drop chance: " + item.id)
		check(not Loot._allowed(Enemies.get_def("goblin_treasure"), item) and not Loot._allowed(Enemies.get_def("spirit_purple"), item), "Ordinary cache and god cannot drop signature: " + item.id)
		if item.is_artifact():
			check(item.slot in ["weapon", "armor"], "Artifact is never a spell or bonus item")
			check(UIStyle.grade_color(item) == UIStyle.ARTIFACT_COLOR and is_equal_approx(float(row.chance), 0.01), "Artifact is green and rolls at 1%")
		else:
			check(float(row.chance) >= 0.015 and float(row.chance) <= 0.03, "Legendary chance stays below ordinary Divine rolls")
			for divine_id: String in Items.divine_ids_for(row.boss):
				check(float(row.chance) < Items.divine_chance(Items.make(divine_id), row.boss), "Legendary is rarer than this boss's Divine pieces: " + item.id)
		if item.slot != "weapon": continue
		var shares := 0.0
		for i in item.shots: shares += item.shot_share(i)
		check(is_equal_approx(shares, 1.0), "Primary's total damage is shared across its projectiles: " + item.id)
		if row.has("balance"):
			var primary := (item.damage_min + item.damage_max) * 0.5 * item.fire_rate * shares
			var graded := Items.make("G8_" + item.kind.to_lower())
			var graded_shares := 0.0
			for shot in graded.shots: graded_shares += graded.shot_share(shot)
			var reference := (graded.damage_min + graded.damage_max) * 0.5 * graded.fire_rate * graded_shares
			var ratio := primary / reference
			check(absf(ratio - float(row.balance.g8_ratio)) < 0.01, "Legendary follows its individual damage budget: " + item.id)
			check(ratio >= 0.55 and ratio <= 1.18, "Standalone damage varies around G8 without a rarity floor: " + item.id)
			check(item.projectile.style != "shard", "Legendary's cut-glass shape differs from Refraction: " + item.id)
		elif item.is_artifact():
			var combat := 0.0
			for id: String in Items.legendary_ids_for(row.boss):
				var reference := Items.make(id)
				if reference.is_weapon(): combat = maxf(combat, (reference.damage_min + reference.damage_max) * 0.5 * reference.fire_rate)
			check((item.damage_min + item.damage_max) * 0.5 * item.fire_rate * shares < combat * 0.4, "Artifact display has much lower primary combat output than its boss's Legendary gear")
	for item: Item in Items.divine():
		check(item.bag_type() == "white", "Every Divine item uses white: " + item.id)
	var legacy := Items.make("D_bow_Blood")
	legacy.drop_bag = "black"
	check(legacy.bag_type() == "white", "Old black Divine override cannot bypass rarity rule")

func _chests() -> void:
	var divine := Items.make("D_bow_Blood")
	var legendary := Items.make("L_bow_heartwoodengine")
	var artifact := Items.make("A_bow_midsummer")
	check(LootBag.rank("black") == LootBag.rank("white") + 1, "Black is one chest tier above white")
	for contents in [[divine], [divine, legendary], [legendary, divine], [divine, artifact], [divine, legendary, artifact]]:
		var kept := Loot.rarest_per_kind(contents)
		check(kept.size() == contents.size(), "Different special bows are never discarded on co-drop")
		var bags: Array[Dictionary] = []
		Loot._pack(bags, kept, 42)
		check(bags.size() == 1 and bags[0].items.size() == contents.size(), "One personal chest preserves all mixed special loot")
		check(bags[0].type == ("white" if contents.size() == 1 else "black") and bags[0].viewer == 42, "Highest rarity chooses personal chest color")
	var kept := Loot.rarest_per_kind([Items.bow(6), divine, legendary, artifact, legendary])
	check(kept.size() == 3, "Duplicate special rolls and lower graded bow do not inflate rewards")
	check(Loot.rarest_per_kind([Items.bow(8), artifact]).size() == 2, "Collectible Artifact never consumes a useful graded weapon drop")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1043
	var boss := Enemies.get_def("queen_briarrose")
	var guaranteed := Loot.roll(boss, {42: boss.hp, 43: 1}, rng, "magic", boss.hp, {42: {chance = 1000.0}})
	var found := {}
	for bag: Dictionary in guaranteed:
		check(bag.viewer == 42 and bag.type == "black", "Real mixed boss loot is a black contributor chest")
		for item: Item in bag.items: found[item.id] = true
	check(found.has(divine.id) and found.has(legendary.id) and found.has(artifact.id), "Real boss roll preserves Divine, Legendary and Artifact bows together")
	var artifacts := 0
	for n in 10000:
		for bag: Dictionary in Loot.roll(boss, {42: boss.hp}, rng):
			for item: Item in bag.items:
				if item.id == artifact.id: artifacts += 1
	check(artifacts >= 65 and artifacts <= 140, "Artifact rate stays near 1%% (%d/10000)" % artifacts)
	print("Artifact Midsummer: ", artifacts, " / 10000 kills")

func _shots() -> void:
	var player := Player.new()
	player.stats = PlayerStats.new()
	add_child(player)
	player.add_child(player.aim_marker)
	player.set_physics_process(false)
	player.set_process(false)
	player.frozen = false
	player._aim_point = Vector3(0, 1, -30)
	var arrows := Arrows.new()
	add_child(arrows)
	arrows.set_physics_process(false)
	arrows.exclude = [player.get_rid()]
	var fired: Array[Dictionary] = []
	player.shot.connect(func(at: Vector3, direction: Vector3, damage: int, weapon: Item, phase: float, mods: Dictionary) -> void:
		fired.append({direction = direction, damage = damage, mods = mods.duplicate()})
		arrows.spawn(at, direction, damage, weapon, phase, "", mods))
	await get_tree().physics_frame
	for row: Dictionary in SignatureItems.definitions():
		if row.slot != "weapon": continue
		var weapon := Items.make(row.id)
		player.stats.gear.weapon = weapon
		fired.clear()
		player._fire()
		check(fired.size() == weapon.shots, "Real primary fires authored count: " + weapon.id)
		check(arrows._meshes_for(weapon, weapon.projectile.style)[1] != null, "Dedicated luminous projectile mesh: " + weapon.id)
		for shot: Dictionary in arrows._shots:
			check(arrows._position_at(shot, 4.0).is_finite(), "Curved flight is finite: " + weapon.id)
			check(shot.node.find_children("*", "GPUParticles3D", true, false).size() > 0, "Projectile has real particle trail: " + weapon.id)
		arrows.clear()
		fired.clear()
		player._release_charge(weapon, 1.0)
		check(not fired.is_empty(), "Real charged attack fires: " + weapon.id)
		for shot: Dictionary in fired:
			check(shot.mods.get("secondary", false) and shot.direction.is_finite() and is_equal_approx(shot.direction.length(), 1.0), "Charged shot carries valid secondary/network data")
		arrows.clear()
	var canopy := Items.make("A_wand_pocketplanetarium")
	var display := SignaturePatterns.primary(Vector3.FORWARD, Vector3.UP, canopy)
	check(display.all(func(s: Dictionary) -> bool: return (s.direction as Vector3).y > 0.0), "Planetarium display rises above the player")
	check(display.any(func(s: Dictionary) -> bool: return (s.direction as Vector3).z > 0.0) and display.any(func(s: Dictionary) -> bool: return (s.direction as Vector3).z < 0.0), "Planetarium surrounds the player")
	var tilted := SignaturePatterns.primary(Vector3.UP, Vector3.RIGHT, canopy)
	check(tilted.all(func(s: Dictionary) -> bool: return (s.direction as Vector3).x > 0.0), "Display follows local gravity on a planet")
	var vertical := SignaturePatterns.primary(Vector3.RIGHT, Vector3.RIGHT, canopy)
	check(vertical.all(func(s: Dictionary) -> bool: return is_equal_approx((s.direction as Vector3).length(), 1.0)), "Looking straight up under sideways gravity keeps every display direction valid")
	var firework := Items.make("A_wand_lastfirework")
	player.stats.gear.weapon = firework
	player.stats.base.dexterity = 0
	check(Player.BASE_FIRE_COOLDOWN / player.stats.shots_per_second_multiplier() > 5.0, "Firework has a deliberately very low base fire rate")
	player.queue_free()
	arrows.queue_free()
	await get_tree().process_frame

func _fireworks() -> void:
	var arrows := Arrows.new()
	add_child(arrows)
	arrows.set_physics_process(false)
	var weapon := Items.make("A_wand_lastfirework")
	var ended: Array = []
	arrows.ended.connect(func(at: Vector3, burst: String, item: Item, _hit: bool) -> void:
		ended.append(burst)
		for shot: Dictionary in SignaturePatterns.burst(item, Vector3.UP, burst == "signature"):
			arrows.spawn(at + shot.direction * 0.3, shot.direction, 1, item, shot.phase, "", shot.mods))
	arrows.spawn(Vector3(0, 4, 0), Vector3.FORWARD, 10, weapon, 0, "", {burst = "signature_primary"})
	for n in 100: arrows._physics_step(0.15)
	check(ended.size() == 1 and arrows._shots.is_empty(), "Firework splits once and all child projectiles expire")
	ended.clear()
	arrows.spawn(Vector3(0, 4, 0), Vector3.FORWARD, 0, weapon, 0, "", {burst = "signature_primary", visual = true})
	for n in 100: arrows._physics_step(0.15)
	check(ended.is_empty() and arrows._shots.is_empty(), "Remote visual firework never creates duplicate damaging children")
	arrows.queue_free()
	await get_tree().process_frame

func _appearances() -> void:
	for row: Dictionary in SignatureItems.definitions():
		if row.slot not in ["weapon", "armor"]: continue
		var item := Items.make(row.id)
		var class_id := "archer" if item.kind in ["Bow", "Cloak"] else "merrow" if item.kind == "Trident" else "wizard"
		var model := PlayerClasses.make_model(class_id)
		add_child(model)
		var weapon := item if item.slot == "weapon" else PlayerClasses.gear_item(class_id, "weapon", 1)
		var armor := item if item.slot == "armor" else PlayerClasses.gear_item(class_id, "armor", 1)
		model.set_equipment(weapon, armor)
		check(model.get_meta("equipment_key") == weapon.id + "|" + armor.id, "Actual figure applies signature appearance: " + item.id)
		if item.slot == "weapon":
			var socket := model.find_child("Bow" if item.kind == "Bow" else "Staff", true, false)
			var rendered := false
			for part: MeshInstance3D in socket.find_children("*", "MeshInstance3D", true, false):
				if part.has_meta("equipped_art"): rendered = rendered or (part.mesh != null and part.is_visible_in_tree())
			check(rendered, "Signature weapon has visible worn geometry: " + item.id)
		elif item.is_artifact():
			var cloth := model.get_meta("garment_mesh") as MeshInstance3D
			check(float(cloth.get_instance_shader_parameter("garment_glow")) > 0.0, "Artifact cloth really emits light: " + item.id)
			model.set_equipment(weapon, PlayerClasses.gear_item(class_id, "armor", 1))
			check(float(cloth.get_instance_shader_parameter("garment_glow")) == 0.0, "Unequipping restores non-luminous cloth")
		model.free()

func _remote_appearance() -> void:
	var remote := RemotePlayer.new()
	add_child(remote)
	remote.set_look("Artifact wearer", "wizard|A_wand_lastfirework,A_robe_impossiblemorning,,")
	check(remote.aura._showoff and remote.aura._crown.visible and remote.aura._showoff_light.visible, "Other players see Artifact crown and light")
	var cloth := remote.model.get_meta("garment_mesh") as MeshInstance3D
	check(float(cloth.get_instance_shader_parameter("garment_glow")) > 0, "Remote Artifact outfit really glows")
	remote.set_look("Artifact wearer", "wizard|G1_wand,G1_robe,,")
	check(not remote.aura._showoff and not remote.aura._crown.visible and not remote.aura._showoff_light.visible, "Remote Artifact effects stop when unequipped")
	check(float(cloth.get_instance_shader_parameter("garment_glow")) == 0.0, "Remote cloth glow resets after changing gear")
	remote.free()
