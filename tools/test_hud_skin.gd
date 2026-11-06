extends Node

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HUD SKIN FAILED: " + label)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var transition := Transition.new()
	add_child(transition)
	var stats := PlayerStats.new()
	var hp := StatBar.new(UIStyle.HP, UIStyle.HP_LIGHT, 7)
	var mana := StatBar.new(UIStyle.MAGIC, UIStyle.MAGIC_LIGHT, 5)
	var xp := XpRing.new()
	var slot := ItemSlot.new("Bow", stats, {kind = "gear", key = "weapon"})
	var backpack := InventoryPanel.new(stats)
	var effects := StatusEffects.new()
	var buffs := BuffStrip.new()
	buffs.effects = effects
	add_child(hp)
	add_child(mana)
	add_child(xp)
	add_child(slot)
	add_child(backpack)
	add_child(buffs)
	effects.add("speed", "45s", 10, "preview")
	await get_tree().process_frame
	await get_tree().process_frame

	hp.set_values(42, 80)
	mana.set_values(18, 100)
	xp.set_values(12, 0.64)
	buffs._process(0.0)
	check(hp._label.text == "42/80" and mana._label.text == "18/100",
		"Health and mana pills retain readable numeric values")
	check(hp._value_pill.get_theme_stylebox("panel") is StyleBoxTexture
		and mana._value_pill.get_theme_stylebox("panel") is StyleBoxTexture,
		"Resource values use opaque blue-stone pills")
	check(hp._label.get_theme_color("font_color") == UIStyle.TEXT
		and mana._label.get_theme_color("font_color") == UIStyle.TEXT,
		"Resource numbers keep a bright text contrast")
	check(xp.level == 12 and xp._level_label.text == "12" and xp.size == xp.custom_minimum_size,
		"XP ring keeps the level number legible and preserves its footprint")
	check(backpack.get_theme_stylebox("panel").texture == UIStyle.ornament_panel().texture,
		"Backpack uses the shared illustrated panel skin")
	check(slot.custom_minimum_size == Vector2(20, 20) * PixelArt.SCALE
		and slot._frame_style(false).texture == UIStyle.slot().texture
		and slot._frame_style(false).texture != UIStyle.panel().texture,
		"Item slots retain their size and use their dedicated texture")
	check(UIStyle.panel().axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		and UIStyle.panel().axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_TILE,
		"Expandable panel surfaces tile at a fixed detail size")
	check(buffs._badges.has("speed:preview"), "Active buffs produce a badge")
	var badge: Control = buffs._badges.get("speed:preview")
	check(badge.get_node("Stone").get_theme_stylebox("panel").texture == UIStyle.panel().texture
		and badge.get_node("TimerPill").get_theme_stylebox("panel").texture == UIStyle.panel_outlined(UIStyle.ACCENT).texture,
		"Buff badges and timers use the shared stone skin")

	var loading = transition._loading
	loading.set_destination("The Ember Bastion")
	loading.show()
	await get_tree().process_frame
	check(transition.is_loading() and loading._where.text == "The Ember Bastion",
		"Loading screen remains visible and names its destination")
	check(loading.find_child("PixelLoader", true, false) != null,
		"Loading animation retains the pixel tunnel loader")
	check(loading.find_children("*", "ProgressBar", true, false).is_empty(),
		"Ambient rune animation does not imply false loading progress")
	check(loading.get_child(0) is ColorRect and loading.get_child(0).material is ShaderMaterial,
		"Loading backdrop remains a full-screen dark shader layer")

	print("HUD SKIN: %d checks, %d failures" % [checks, failures])
	transition.queue_free()
	hp.queue_free()
	mana.queue_free()
	xp.queue_free()
	slot.queue_free()
	backpack.queue_free()
	buffs.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
