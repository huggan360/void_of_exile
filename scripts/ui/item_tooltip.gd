class_name ItemTooltip
extends PanelContainer
## Hover card for an item: name (in its grade color), type and grade,
## weapon damage and shots, stat bonuses, abilities, and a line of lore.
## Follows the mouse.

var _text := RichTextLabel.new()
var stats: PlayerStats


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.popup_panel())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(360, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", UIStyle.SIZE_NORMAL)
	_text.add_theme_font_size_override("italics_font_size", UIStyle.SIZE_SMALL)
	_text.add_theme_font_size_override("bold_font_size", UIStyle.SIZE_NORMAL)
	_text.add_theme_constant_override("line_separation", 4)
	add_child(_text)
	hide()


func show_item(item: Item) -> void:
	if item == null:
		hide()
		return
	add_theme_stylebox_override("panel", UIStyle.popup_panel())
	var lines := PackedStringArray()
	lines.append("[font_size=24][b]%s[/b][/font_size]" % TextMarkup.color(item.item_name, UIStyle.grade_color(item)))
	lines.append(TextMarkup.color(item.grade_name(), UIStyle.DIVINE_COLOR if item.is_divine() else UIStyle.TEXT_DIM)
		+ TextMarkup.color("  -  " + item.kind, UIStyle.TEXT_DIM))
	var numbers := PackedStringArray()
	if item.is_weapon():
		numbers.append(TextMarkup.key_value("Damage", "%d–%d" % [item.damage_min, item.damage_max], UIStyle.DAMAGE))
		var shares := PackedStringArray()
		for i in item.shots:
			shares.append("%s%%" % String.num(item.shot_share(i) * 100.0, 1))
		numbers.append(TextMarkup.key_value("Shots", "%d - %s" % [item.shots, " / ".join(shares)], UIStyle.PROJECTILE))
		numbers.append(TextMarkup.key_value("Fire rate", "%s%% base" % String.num(item.fire_rate * 100.0, 0), UIStyle.PROJECTILE))
		numbers.append(TextMarkup.key_value("Range / speed", "%s m / %s m/s" % [
			String.num(item.projectile_range(), 1),
			String.num(float(item.projectile.get("speed", 24.0)), 1)], UIStyle.PROJECTILE))
		numbers.append(TextMarkup.key_value("Piercing", "Yes" if item.projectile.get("pierce", false) else "No", UIStyle.PROJECTILE))
		if item.windup > 0.0:
			numbers.append(TextMarkup.key_value("Windup", "%.2f s" % item.windup, UIStyle.PROJECTILE))
		if not item.charge.is_empty():
			var charge := item.charge
			numbers.append(TextMarkup.key_value("Charged shot", "%s - ×%.1f damage" % [
				str(charge.get("name", str(charge.get("style", "power")).capitalize())), float(charge.get("mult", 2.0))], UIStyle.PROJECTILE))
			numbers.append(TextMarkup.key_value("Hold right click", "1 s to full charge", UIStyle.PROJECTILE))
			var style := str(charge.get("style", "power"))
			var count := int(charge.get("count", 7 if style == "volley" else 6)) if style in ["volley", "stream", "burst", "serpent_fan"] else 2 if style == "helix" else 1 if style in ["arcane", "inferno", "singularity"] else item.shots
			numbers.append(TextMarkup.key_value("Charged shots", "%d%s" % [count, " - equal shares" if style in ["stream", "burst", "helix", "serpent_fan"] else ""], UIStyle.PROJECTILE))
	if not item.ring.is_empty():
		var peak := roundi(item.ring.damage * (stats.spell_multiplier(item) if stats else 1.0))
		numbers.append(TextMarkup.key_value("Warp ring", "%d–%d damage / pulse" % [roundi(peak * MagicRing.MIN_DAMAGE_SHARE), peak]))
		numbers.append(TextMarkup.key_value("Cost / range", "%d MP / %s m" % [item.ring.cost, item.ring.range], UIStyle.MP))
		numbers.append(TextMarkup.key_value("Pulses / cooldown", "%d / %.1f s" % [item.ring.get("pulses", 1), item.ring.get("cooldown", 0.6)], UIStyle.PROJECTILE))
	var bonuses := PackedStringArray()
	for stat: String in item.bonuses:
		bonuses.append("[b]%s[/b]" % UIStyle.stat_text(stat, int(item.bonuses[stat])))
	for start in range(0, bonuses.size(), 3):
		numbers.append("  -  ".join(bonuses.slice(start, start + 3)))
	var use := item.consumable
	for stat: String in ["hp", "mp"]:
		if use.has(stat):
			numbers.append(TextMarkup.key_value("Restore", "+%d %s" % [use[stat], UIStyle.stat_name(stat)], UIStyle.stat_color(stat)))
	if use.has("stat"):
		numbers.append("[b]Permanent[/b]  " + UIStyle.stat_text(str(use.stat), int(use.amount)))
	if use.has("backpack"):
		numbers.append(TextMarkup.key_value("Capacity", "+2 backpack rows", UIStyle.GOOD))
	lines.append_array(numbers)
	var abilities := PackedStringArray()
	abilities.append_array(_effect_lines(item.primary_effects, "On hit"))
	abilities.append_array(_effect_lines(item.secondary_effects, "Charged" if item.is_weapon() else "Warp ring"))
	if not item.ring.is_empty():
		abilities.append("- Double-tap Space: cast ring; scales with MAG")
	for ability: String in item.abilities:
		if ability.begins_with("Hold right click:") or ability.begins_with("Double-tap Space:"):
			continue
		if item.is_consumable() and (ability.begins_with("Restores ") or ability.begins_with("+") or "backpack rows" in ability):
			continue
		var short := ability.replace("Double-click or quickslot (F / G) to drink", "Use: double-click or quickslot").replace("Double-click to strap it on: ", "Use: ").replace(" for good, on this character", " permanently")
		abilities.append("- " + TextMarkup.escape(short))
	if item.soulbound():
		abilities.append("[b]%s[/b]" % TextMarkup.color("Soulbound", UIStyle.SOULBOUND))
	if stats and not item.is_consumable() and not item.usable_by(stats.class_id):
		abilities.append(TextMarkup.color("Cannot equip - " + PlayerClasses.display_name(stats.class_id), UIStyle.BAD))
	if not abilities.is_empty():
		lines.append("")
		lines.append_array(abilities)
	if item.lore != "" and numbers.size() + abilities.size() <= 12:
		var lore := item.lore.replace("\n", " ")
		if lore.length() > 110:
			lore = lore.left(107).rsplit(" ", true, 1)[0] + "…"
		lines.append("\n[i]%s[/i]" % TextMarkup.color(lore, UIStyle.TEXT_DIM))
	_text.text = "\n".join(lines)
	reset_size()
	show()


func _process(_delta: float) -> void:
	if not visible:
		return
	var mouse := get_global_mouse_position()
	var view: Vector2 = get_parent().size if get_parent() is Control else get_viewport_rect().size
	# Prefer left of the cursor (the slots sit on the right edge of the screen).
	var pos := mouse + Vector2(-size.x - 16, 16)
	pos.x = clampf(pos.x, 8, view.x - size.x - 8)
	pos.y = clampf(pos.y, 8, view.y - size.y - 8)
	global_position = pos


func _effect_lines(effects: Array[Dictionary], source: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for effect in effects:
		var id := StatusEffects.canonical(str(effect.id))
		var title: String = {"static": "Frozen", "speed": "Slowed"}.get(id, StatusEffects.NAMES.get(id, id))
		lines.append("- " + TextMarkup.key_value(source, "%s - %.1f s" % [title, float(effect.get("duration", 0))], UIStyle.EFFECT))
	if effects.any(func(e: Dictionary) -> bool: return StatusEffects.canonical(str(e.id)) in ["static", "quiet"]):
		lines.append(TextMarkup.color("  Boss control: ≤0.8 s; 4 s recovery", UIStyle.TEXT_DIM))
	return lines
