extends Node
## Validates the live stronghold boss art (creatures/realm_boss_manifest.json,
## made by tools/make_realm_bosses.py) and its registration as encounters.
const MANIFEST := "res://creatures/realm_boss_manifest.json"
const BOSS_MODELS := {rimeheart_prism = "rimeheart_prism", vharok = "vharok_cinder_tyrant",
	scarab_regent = "aureate_scarab_regent", hollow_crown = "hollow_crown", blue_dragon = "blue_dragon"}
const SHELLS := {blue_dragon = "egg_blue_dragon", rimeheart_prism = "egg_rimeheart", vharok = "egg_vharok",
	scarab_regent = "egg_scarab", hollow_crown = "egg_hollow_crown"}
const FORMS := {rimeheart_prism = ["conduit", "tempest"], vharok_cinder_tyrant = ["infernal", "heart_unbound"],
	aureate_scarab_regent = ["sunwings", "sunheart"], hollow_crown = ["fractured_court", "unbound"]}
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(manifest.size() == 15, "Five bosses, five shells and five support models")
	for entry: Dictionary in manifest:
		var folder := "res://creatures/%s/" % entry.id
		var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "rig.json"))
		for part: String in rig.parts:
			var info: Dictionary = rig.parts[part]
			for dim in info.frame_size:
				check(dim <= 256 and dim > 0, "VOX frame fits the 256-voxel format: %s/%s" % [entry.id, part])
			for suffix: String in ["", "_glow"]:
				if not FileAccess.file_exists(folder + part + suffix + ".vox"):
					continue
				var data := VoxModel.load_vox(folder + part + suffix + ".vox")
				check(data.size() == 2, "Native VOX loader accepts " + part)
				if not data.is_empty():
					var size: Vector3i = data[0].get_size()
					check(size == Vector3i(info.frame_size[0], info.frame_size[1], info.frame_size[2]), "Loader dimensions agree with frame")
		for swaps: Dictionary in rig.variants.values():
			for base: String in swaps:
				check(rig.parts[base].frame_min == rig.parts[swaps[base]].frame_min and rig.parts[base].frame_size == rig.parts[swaps[base]].frame_size,
						"Variant shares its holder frame: " + swaps[base])
		for form in FORMS.get(entry.id, []):
			check(rig.variants.has(form), "%s has its %s form" % [entry.id, form])
		if str(entry.id).begins_with("egg_"):
			for k in [1, 2, 3]:
				check(rig.variants.has("crack%d" % k), "%s has crack stage %d" % [entry.id, k])
		var model := CreatureModel.new(entry.id)
		add_child(model)
		for i in 3:
			model.animate(.5, .1)
		for variant: String in rig.variants:
			model.set_variant(variant)
			var swapped := false
			for mesh in model._parts:
				if mesh.get_meta("part") in rig.variants[variant].values():
					swapped = true
			check(swapped, "%s shows its %s geometry" % [entry.id, variant])
		model.free()
		for form: String in entry.poses:
			var pose: Dictionary = entry.poses[form]
			check(pose.size[0] * entry.voxel_size < 16 and pose.size[2] * entry.voxel_size < 16, "Fits a 16 m stronghold: " + entry.id)
	for boss_id: String in BOSS_MODELS:
		var def := Enemies.get_def(boss_id) as BossDef
		check(def != null and def.model == BOSS_MODELS[boss_id], "Live boss: " + boss_id)
		check(def.wake_on == "shell" and def.shell_model == SHELLS[boss_id] and def.shell_hp > 0, "Sleeps in its shell: " + boss_id)
		check(boss_id == "blue_dragon" or ResourceLoader.exists(def.actor_script), "Has its own fight script: " + boss_id)
		var divine := 0
		for drop: Dictionary in def.loot:
			if drop.get("item", "") in Items.divine_ids_for(boss_id):
				divine += 1
				check(is_equal_approx(drop.chance, 0.03), "Independent 3% divine roll")
		check(divine == Items.divine_ids_for(boss_id).size(), "Every set item rolls for " + boss_id)
	var assignments: Array = JSON.parse_string(FileAccess.get_file_as_string("res://creatures/staging/realm_bosses_01/divine_set_assignments.json"))
	var live := 0
	for set_info: Dictionary in assignments:
		var is_live: bool = set_info.status == "LIVE"
		live += 1 if is_live else 0
		for item: Dictionary in set_info.items:
			check(item.live_chance == (.03 if is_live else 0.0), "Documentation matches live drops: " + str(item.source_file))
			if is_live:
				check(item.runtime_id in Items.DIVINE_SETS[set_info.set], "Live item registered: " + str(item.runtime_id))
	check(live == 5, "Five live sets, the rest unassigned")
	print("REALM BOSS ART: ", checks, " checks; ", failures, " failures")
	get_tree().quit(1 if failures else 0)
