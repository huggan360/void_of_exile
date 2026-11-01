class_name ItemTooltip
extends PanelContainer
## Hover card for an item: name (in its grade color), type and grade,
## weapon damage and shots, stat bonuses, abilities, and a line of lore.
## Follows the mouse.

var _text := RichTextLabel.new()
var stats: PlayerStats


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(300, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", UIStyle.SIZE_NORMAL)
	_text.add_theme_font_size_override("italics_font_size", UIStyle.SIZE_SMALL)
	_text.add_theme_font_size_override("bold_font_size", UIStyle.SIZE_LARGE)
	_text.add_theme_constant_override("line_separation", 4)
	add_child(_text)
	hide()


func show_item(item: Item) -> void:
	if item == null:
		hide()
		return
	var good := UIStyle.GOOD.to_html(false)
	var bad := UIStyle.HP_LIGHT.to_html(false)
	var lines := PackedStringArray()
	lines.append("[b][color=#%s]%s[/color][/b]" % [UIStyle.grade_color(item).to_html(false), item.item_name])
	if item.is_consumable():
		lines.append("[color=#%s]%s  ·  [/color][color=#%s]Consumable[/color]" % [
				UIStyle.TEXT_DIM.to_html(false), item.kind, UIStyle.ACCENT.to_html(false)])
	else:
		lines.append("[color=#%s]%s  ·  %s[/color]" % [UIStyle.TEXT_DIM.to_html(false), item.kind, item.grade_name()])
	var class_id := stats.class_id if stats else "archer"
	if not item.is_consumable() and not item.usable_by(class_id):
		lines.append("[color=#%s]Cannot be equipped by %s[/color]" % [bad, PlayerClasses.display_name(class_id)])
	if item.is_weapon():
		lines.append("[b]Primary attack[/b] · Left click")
		lines.append("Base damage  [b]%d–%d[/b]" % [item.damage_min, item.damage_max])
		lines.append("Projectiles: %d" % item.shots)
		for i in item.shots:
			lines.append("Projectile %d: %s%%" % [i + 1, String.num(item.shot_share(i) * 100.0, 1)])
		if item.shots > 1: lines.append("[font_size=16]Listed left to right; shares use base damage.[/font_size]")
		if item.kind == "Wand" and item.shots == 2: lines.append("Mirrored waves, traveling in the aimed direction")
		if item.kind == "Trident": lines.append("Tridents stick into walls and terrain")
		lines.append_array(_effect_lines(item.primary_effects))
		if item.fire_rate != 1.0: lines.append("Rate of fire  %d%%" % int(item.fire_rate * 100))
		lines.append("[b]Secondary attack[/b] · Hold right click")
		if item.charge.is_empty():
			lines.append("No charged ability")
		else:
			var charge: Dictionary = item.charge
			var style := str(charge.get("style", "power"))
			lines.append(str(charge.get("name", style.capitalize())))
			lines.append("Charge 1s · 100%% charge: ×%.1f damage" % float(charge.get("mult", 2.0)))
			if style == "arcane":
				lines.append("8° growing magic shot with spiraling particles")
				lines.append("Projectiles: 1 · 100% base damage before charge")
			elif style in ["stream", "burst"]:
				var count := int(charge.get("count", 6))
				lines.append("%d %s · %.1f%% base damage each before charge" % [count,
					"voxel stream pulses" if style == "stream" else "rapid shots", 100.0 / count])
			else:
				var count: int = int(charge.get("count", 7)) if style == "volley" else 2 if style == "helix" else 1 if style in ["inferno", "singularity"] else item.shots
				lines.append("Projectiles: %d" % count)
				for i in count:
					lines.append("Projectile %d: %s%% before charge" % [i + 1, String.num(item.shot_share(i, count) * 100.0, 1)])
			lines.append_array(_effect_lines(item.secondary_effects))
	if not item.ring.is_empty():
		lines.append("[b]Spell attack[/b] · Double-tap Space")
		var multiplier := stats.spell_multiplier(item) if stats else 1.0
		var peak := roundi(item.ring.damage * multiplier)
		lines.append("Warp ring  [b]%d–%d damage per pulse[/b]" % [roundi(peak * MagicRing.MIN_DAMAGE_SHARE), peak])
		lines.append("%d MP · %d m · %d pulse(s) · %.1f s cooldown" % [item.ring.cost, item.ring.range,
			item.ring.get("pulses", 1), item.ring.get("cooldown", 0.6)])
		lines.append("Damage scales with Magic; range falloff and enemy defence apply")
		lines.append_array(_effect_lines(item.secondary_effects))
	for stat in item.bonuses:
		var v: int = item.bonuses[stat]
		lines.append("[color=#%s]%+d %s[/color]" % [good if v >= 0 else bad, v, PlayerStats.STAT_NAMES.get(stat, stat)])
	for line in item.abilities:
		lines.append("[color=#%s]· %s[/color]" % [UIStyle.ACCENT.to_html(false), line])
	if item.lore != "":
		lines.append("[i][color=#%s]%s[/color][/i]" % [Color(0.75, 0.7, 0.9).to_html(false), item.lore])
	_text.clear()
	for i in lines.size():
		if i > 0: _text.append_text("\n")
		var line := lines[i]
		if line.begins_with("@effect|"):
			var fields := line.split("|")
			var effect := {id=fields[1], amount=float(fields[3])}
			var badge := BuffArt.badge(effect)
			if badge: _text.add_image(badge, 20, 20)
			var title: String = {"static":"Frozen", "speed":"Slowed"}.get(fields[1], StatusEffects.NAMES.get(fields[1], fields[1]))
			_text.append_text(" %s %.1fs" % [title, float(fields[2])])
		else:
			_text.append_text(line)
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


func _effect_lines(effects: Array[Dictionary]) -> PackedStringArray:
	var lines := PackedStringArray()
	for effect in effects:
		lines.append("@effect|%s|%s|%s" % [StatusEffects.canonical(str(effect.id)),
			effect.get("duration", 0), effect.get("amount", 1)])
	if effects.any(func(e: Dictionary) -> bool: return StatusEffects.canonical(str(e.id)) in ["static", "quiet"]):
		lines.append("[font_size=14]Boss control: up to 0.8s, with a 4s recovery.[/font_size]")
	return lines
