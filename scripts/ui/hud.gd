class_name Hud
extends ResponsiveUILayer
## The game's on-screen interface, built from the reusable pieces in
## scripts/ui (UIStyle, StatBar, XpRing, ItemSlot, ItemTooltip, ToastFeed,
## StatsPanel, InventoryPanel, Minimap):
##   top left      the character you play (CharacterPicker: in the Tavern
##                 it opens to change, make or delete characters, and the
##                 fallen ones' records); toasts under it
##   top center    the account's XP bar and level, with the reward drawer
##                 (AccountBar); under it the health bar of a boss you're
##                 fighting (BossBar)
##   top right     Stats button, XP ring with level, gear slots, and the two
##                 quickslots (F and G) for elixirs
##   bottom center health bar with the magic bar under it
##   anywhere      drag an item out of your inventory onto the world to drop it
##   bottom right  round minimap (mouse wheel zooms it)
##   left half     backpack while Tab is held or you stand on a loot bag, with
##                 the bag under it (drag items around or double-click them)

const SLOTS := [["weapon", "Bow"], ["armor", "Cloak"], ["spell", "Spell"], ["bonus", "Bonus"]]
const MARGIN := 18
## Large map: screen height kept free (top bar, health bars, hint) and the downward nudge.
const MAP_RESERVED := 290.0
const MAP_SHIFT := 6.0
const HEART := ["..o.o..", ".oRoRo.", "oRWRRRo", "oRRRRRo", ".oRRRo.", "..oRo..", "...o..."]
const STAR := ["...o...", "..oYo..", "ooYWYoo", "oYYYYYo", ".oYYYo.", "oYo.oYo", "oo...oo"]

var stats: PlayerStats
var player: Player
var toasts := ToastFeed.new()
var minimap := Minimap.new()
var _map_backdrop := ColorRect.new()
var _drunk_overlay := ColorRect.new()
var _drunk := 0.0
## While aboard or out on a spacewalk the bars show other things (set each
## frame by SpaceTraversal): {hp = [value, max, caption, color, light], mp = [...]}.
var bar_override := {}
var _bars_restyled := false
var _map_hint: Label
var buff_strip := BuffStrip.new()
var _bars: Control

var account_bar := AccountBar.new()
var _world: GameWorld
var _home := ""
var picker: CharacterPicker
var _where := ""
var _hp_bar := StatBar.new(UIStyle.HP, UIStyle.HP_LIGHT, 7)
var _mp_bar := StatBar.new(UIStyle.MAGIC, UIStyle.MAGIC_LIGHT, 5)
var _xp_ring := XpRing.new()
var _stats_panel: StatsPanel
var _tooltip := ItemTooltip.new()
var _slots := {}  # slot id -> ItemSlot
var _inventory: InventoryPanel
var _bag_panel: BagPanel
## Bram's forge, under the backpack while you talk to the smith.
var forge: ForgePanel
## A shopkeeper's wares, on the right while you talk to them.
var shop: ShopPanel
var fleet: FleetPanel
var _center := CenterContainer.new()
var _stack := VBoxContainer.new()  # backpack, and the loot bag under it
var _quick: Array[ItemSlot] = []
var _drop_zone := DropZone.new()
var _boss_bar := BossBar.new()
var interaction := InteractionCard.new()
var chat: ChatPanel
var social_panel: SocialPanel
var quest_banner := QuestBanner.new()
## Minimap markers for the campaign's objectives (CampaignClient.markers).
var quest_markers := Callable()
var _fps_readout := Label.new()
var _fps_timer := 0.0
var _stats_button: Button
var _equipment_column: VBoxContainer
var _hud_reveal_left := 0.0
const WORLD_UI_ALPHA := 0.60
## Loot bags of the current world (set by Main).
var loot: LootBags


## Covers the screen while dragging: letting go of an item over the world
## (not over a slot) drops it on the ground.
class DropZone extends Control:
	var hud: Hud

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("from") and data.from.kind != "bag"

	func _drop_data(_at: Vector2, data: Variant) -> void:
		hud.drop_to_ground(data.from)


func _init(p_stats: PlayerStats, p_player: Player) -> void:
	stats = p_stats
	player = p_player


func _ready() -> void:
	var root := make_ui_root()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel frames stay crisp
	_fps_readout.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fps_readout.position = Vector2(8, 4)
	_fps_readout.z_index = 100
	_fps_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.text(_fps_readout,16,UIStyle.TEXT_DIM)
	root.add_child(_fps_readout)
	root.add_child(interaction)
	interaction.set_meta("player", player)

	# Top left: toasts, under the character picker (added last, so its
	# dropdown draws over the rest).
	toasts.position = Vector2(MARGIN, MARGIN + 100)
	toasts.custom_minimum_size = Vector2(320, 0)
	root.add_child(toasts)

	# Behind everything else, so slots get drops first.
	_drop_zone.hud = self
	_drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_drop_zone)

	# Under the account bar: the bar of the boss you're fighting.
	_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_bar.position.y = MARGIN + AccountBar.HEADER_HEIGHT + 8
	var boss_width := BossBar.BAR_SIZE.x + BossBar.PORTRAIT + 14
	_boss_bar.offset_left = -boss_width * 0.5
	_boss_bar.offset_right = boss_width * 0.5
	root.add_child(_boss_bar)

	# Bottom center: health and magic.
	var bars := VBoxContainer.new()
	_bars = bars
	bars.add_theme_constant_override("separation", 10)
	bars.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bars.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bars.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hp_bar.set_icon(PackedStringArray(HEART), {"o": UIStyle.OUTLINE, "R": UIStyle.HP, "W": Color(1, 0.8, 0.8)})
	_mp_bar.set_icon(PackedStringArray(STAR), {"o": UIStyle.OUTLINE, "Y": UIStyle.MAGIC, "W": Color(1, 1, 0.85)})
	var bars_size := _hp_bar.custom_minimum_size + Vector2(0, _mp_bar.custom_minimum_size.y + 10)
	bars.offset_top = -MARGIN - bars_size.y
	bars.offset_bottom = -MARGIN
	bars.offset_left = -bars_size.x * 0.5
	bars.offset_right = bars_size.x * 0.5
	bars.add_child(_hp_bar)
	bars.add_child(_mp_bar)
	root.add_child(bars)
	UIStyle.add_shadow(_hp_bar)
	UIStyle.add_shadow(_mp_bar)


	# Bottom right: minimap. The large map (M) dims the world behind it.
	_map_backdrop.color = Color(0.02, 0.02, 0.05, 0.62)
	_map_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_backdrop.hide()
	root.add_child(_map_backdrop)
	root.move_child(_map_backdrop, 0)  # under every HUD element, over the world
	# Drunk: a swirl over the world only, under the HUD.
	_drunk_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drunk_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swirl := ShaderMaterial.new()
	swirl.shader = preload("res://shaders/drunk_swirl.gdshader")
	_drunk_overlay.material = swirl
	_drunk_overlay.hide()
	root.add_child(_drunk_overlay)
	root.move_child(_drunk_overlay, 0)
	_map_hint = UIStyle.label("M: close map  -  mouse wheel: zoom", 16, UIStyle.TEXT)
	_map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_hint.hide()
	_map_backdrop.add_child(_map_hint)
	_place_minimap()
	minimap.player = player
	root.add_child(minimap)
	UIStyle.add_shadow(minimap, true)
	buff_strip.effects = stats.buffs
	root.add_child(buff_strip)

	# Top right: Dots and stats button, then XP ring and gear.
	var column := VBoxContainer.new()
	_equipment_column = column
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.offset_left = -MARGIN - 280
	column.offset_right = -MARGIN
	column.offset_top = MARGIN
	root.add_child(column)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer)
	top_row.add_child(account_bar.dots)
	var stats_button := UIStyle.button("Stats")
	_stats_button = stats_button
	stats_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	stats_button.pressed.connect(toggle_stats)
	top_row.add_child(stats_button)
	column.add_child(top_row)
	_xp_ring.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_xp_ring)
	UIStyle.add_shadow(_xp_ring, true)
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 6)
	slot_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(slot_row)
	for entry in SLOTS:
		var slot := ItemSlot.new(entry[1], stats, {kind = "gear", key = entry[0]})
		slot.hovered.connect(func(_s: ItemSlot, item: Item) -> void: _tooltip.show_item(item))
		slot.unhovered.connect(_tooltip.hide)
		slot_row.add_child(slot)
		_slots[entry[0]] = slot
	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 6)
	quick_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(quick_row)
	for i in PlayerStats.QUICKSLOTS:
		var slot := ItemSlot.new("Quickslot", stats, {kind = "quick", key = i})
		slot.key_hint = ["F", "G"][i]
		slot.hovered.connect(func(_s: ItemSlot, item: Item) -> void: _tooltip.show_item(item))
		slot.unhovered.connect(_tooltip.hide)
		quick_row.add_child(slot)
		_quick.append(slot)

	# Stats tab: hangs to the left of the right-hand column.
	_stats_panel = StatsPanel.new(stats)
	_stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stats_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stats_panel.offset_right = -MARGIN - 290
	_stats_panel.offset_top = MARGIN
	_stats_panel.z_index = 30
	_stats_panel.hide()
	root.add_child(_stats_panel)

	# Middle: backpack (Tab, or standing on a bag) with the bag under it.
	# Centered in the left half, so your character (mid-screen) stays in view.
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.anchor_right = 0.5
	_center.offset_right = 0.0
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_center)
	_stack.add_theme_constant_override("separation", 10)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_stack)
	_inventory = InventoryPanel.new(stats)
	_inventory.item_hovered.connect(_tooltip.show_item)
	_inventory.item_unhovered.connect(_tooltip.hide)
	_inventory.hide()
	_stack.add_child(_inventory)
	_bag_panel = BagPanel.new(stats)
	_bag_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bag_panel.item_hovered.connect(_tooltip.show_item)
	_bag_panel.item_unhovered.connect(_tooltip.hide)
	_bag_panel.hide()
	_stack.add_child(_bag_panel)
	forge = ForgePanel.new(stats)
	forge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	forge.interaction = interaction
	forge.dots = account_bar.dots
	forge.item_hovered.connect(_tooltip.show_item)
	forge.item_unhovered.connect(_tooltip.hide)
	_stack.add_child(forge)
	shop = ShopPanel.new(stats)
	shop.interaction = interaction
	shop.item_hovered.connect(_tooltip.show_item)
	shop.item_unhovered.connect(_tooltip.hide)
	var right := CenterContainer.new()
	right.set_anchors_preset(Control.PRESET_FULL_RECT)
	right.anchor_left = 0.5
	right.offset_left = 0.0
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	right.add_child(shop)
	fleet = FleetPanel.new()
	fleet.interaction = interaction
	right.add_child(fleet)

	# Top center: the account's XP bar, level and reward drawer.
	account_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	account_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var bar_width := AccountBar.BAR_SIZE.x
	account_bar.offset_left = -bar_width * 0.5
	account_bar.offset_right = bar_width * 0.5
	account_bar.offset_top = MARGIN
	root.add_child(account_bar)
	# Top left: who you play.
	picker = CharacterPicker.new(stats)
	picker.position = Vector2(MARGIN, MARGIN)
	root.add_child(picker)

	_tooltip.stats = stats
	_tooltip.z_index = 60
	root.add_child(_tooltip)  # last, so it draws over everything
	stats.changed.connect(_refresh)
	AppSettings.bindings_changed.connect(_update_binding_hints)
	_update_binding_hints()
	_refresh()


func _update_binding_hints() -> void:
	for i in _quick.size():
		_quick[i].key_hint = AppSettings.binding_text("quick_%d" % (i+1))
		_quick[i].tooltip_text = _quick[i].key_hint
		_quick[i].queue_redraw()


## Bottom right normally; large and centred while the map is open.
func _place_minimap() -> void:
	var span := minimap.custom_minimum_size
	_map_backdrop.visible = minimap.expanded
	_map_hint.visible = minimap.expanded
	if minimap.expanded:
		# Centred in the band between the top bar and the health bars.
		minimap.set_anchors_preset(Control.PRESET_CENTER)
		minimap.grow_horizontal = Control.GROW_DIRECTION_BOTH
		minimap.grow_vertical = Control.GROW_DIRECTION_BOTH
		minimap.offset_left = -span.x * 0.5
		minimap.offset_top = -span.y * 0.5 + MAP_SHIFT
		minimap.offset_right = span.x * 0.5
		minimap.offset_bottom = span.y * 0.5 + MAP_SHIFT
		_map_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_map_hint.offset_left = -300
		_map_hint.offset_right = 300
		_map_hint.offset_top = span.y * 0.5 + MAP_SHIFT + 10
		_map_hint.offset_bottom = span.y * 0.5 + MAP_SHIFT + 34
		return
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimap.offset_left = -MARGIN - span.x
	minimap.offset_top = -MARGIN - span.y
	minimap.offset_right = -MARGIN
	minimap.offset_bottom = -MARGIN


func toggle_map() -> void:
	if is_instance_valid(player) and player.spatial_controller is SpaceTraversal:
		(player.spatial_controller as SpaceTraversal).toggle_map()
		return
	if not minimap.expanded and not minimap.visible: return  # worlds without a planar map
	var screen := minimap.get_parent_control().size if minimap.get_parent_control() else get_viewport().get_visible_rect().size
	# Leave room for the account bar above and the health bars and hint below.
	var art := floorf(minf(screen.x * 0.8, screen.y - MAP_RESERVED) / PixelArt.SCALE)
	minimap.set_expanded(not minimap.expanded, maxf(Minimap.ART_PIXELS, art))
	_place_minimap()


## Top-left corner of the small minimap (the buff strip lines up with it).
func _minimap_corner() -> Vector2:
	var span := Vector2(Minimap.ART_PIXELS, Minimap.ART_PIXELS) * PixelArt.SCALE
	return _ui_root.size - Vector2(MARGIN, MARGIN) - span


func toggle_stats() -> void:
	_stats_panel.visible = not _stats_panel.visible
	if _stats_panel.visible:
		_stats_panel.refresh()
		_hud_reveal_left = 1.0


## Debug: shows a slot's tooltip as if hovered.
func debug_show_tooltip(slot_id: String) -> void:
	_tooltip.show_item(stats.gear.get(slot_id))


func set_world(world: GameWorld, fog_of_war: FogOfWar) -> void:
	interaction.set_world(world)
	minimap.fog_of_war = fog_of_war
	if minimap.expanded:
		minimap.set_expanded(false)
		_place_minimap()
	minimap.setup(world)
	_world = world
	refresh_markers()


## Bottom left: chat with its friends and party panel. The quest tracker
## sits at the left edge below the character picker, with notices below it.
func add_social(social: SocialClient, body_of: Callable) -> void:
	chat = ChatPanel.new()
	chat.social = social
	chat.player = player
	chat.body_of = body_of
	social_panel = SocialPanel.new()
	social_panel.social = social
	social_panel.chat = chat
	chat.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chat.offset_left = MARGIN
	chat.offset_top = -MARGIN
	chat.offset_bottom = -MARGIN
	_ui_root.add_child(chat)
	# Over the chat log, sitting right on its buttons (see _process).
	_ui_root.add_child(social_panel)
	chat.panel_requested.connect(social_panel.show_tab)
	quest_banner.social = social
	quest_banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quest_banner.offset_left = MARGIN
	quest_banner.offset_right = MARGIN + 380
	quest_banner.offset_top = MARGIN + 116
	_ui_root.add_child(quest_banner)
	_ui_root.move_child(_tooltip, -1)


## Portals, the towns (each in its own color) and your home.
func refresh_markers() -> void:
	minimap.markers.clear()
	if not is_instance_valid(_world):
		return
	for pos in _world.portal_positions():
		minimap.markers.append({pos = pos, color = Color(0.75, 0.55, 1.0)})
	if _world is IslandWorld:
		for v in (_world as IslandWorld).generator.villages:
			var home: bool = v.display_name == stats.home
			minimap.markers.append({pos = Vector3(v.center.x, 0, v.center.y), color = v.map_color,
				kind = "home" if home else "town"})
	if quest_markers.is_valid():
		for m: Dictionary in quest_markers.call():
			minimap.markers.append(m)
	minimap.queue_redraw()


## A dialog or full-screen view over the HUD (death records, new character).
func add_dialog(dialog: Control) -> void:
	if account_bar.is_open(): account_bar.toggle()
	get_child(0).add_child(dialog)


## A panel in the middle of the screen (an npc's book, a campaign's results).
func add_centered(panel: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	panel.tree_exited.connect(center.queue_free)
	_ui_root.add_child(center)


## Where you are (kept for debugging; the top of the screen shows the account bar).
func _update_bars() -> void:
	if bar_override.is_empty():
		if _bars_restyled:
			_bars_restyled = false
			_hp_bar.restyle(UIStyle.HP, UIStyle.HP_LIGHT, "")
			_mp_bar.restyle(UIStyle.MAGIC, UIStyle.MAGIC_LIGHT, "")
		_hp_bar.set_values(stats.hp, stats.max_hp)
		_mp_bar.set_values(stats.mp, stats.max_mp)
		return
	_bars_restyled = true
	for pair: Array in [[_hp_bar, bar_override.get("hp", [])], [_mp_bar, bar_override.get("mp", [])]]:
		var bar: StatBar = pair[0]
		var spec: Array = pair[1]
		if spec.size()<5: continue
		bar.restyle(spec[3], spec[4], str(spec[2]))
		bar.set_values(float(spec[0]), float(spec[1]))

func set_location(text: String) -> void:
	_where = text


func _refresh() -> void:
	if stats.home != _home:
		_home = stats.home
		refresh_markers()
	_xp_ring.set_values(stats.level, float(stats.xp) / stats.xp_to_next())
	var class_def := PlayerClasses.get_def(stats.class_id)
	_slots.weapon.slot_name = class_def.weapon
	_slots.armor.slot_name = class_def.armor
	for id in _slots:
		_slots[id].set_item(stats.gear.get(id))
	for i in _quick.size():
		_quick[i].set_item(stats.quick[i])


## An item dragged out onto the world: it drops at the player's feet.
func drop_to_ground(from: Dictionary) -> void:
	GameServer.request_drop(player.player_id, from)


func _process(_delta: float) -> void:
	if not FrameTrace.enabled: _profile_process(_delta); return
	var started := Time.get_ticks_usec()
	_profile_process(_delta)
	FrameTrace.record("ui/hud",started)

func _profile_process(_delta: float) -> void:
	_update_world_ui_fade(_delta, _ui_root.get_global_mouse_position())
	_fps_readout.visible = AppSettings.video.show_fps
	_fps_timer -= _delta
	if _fps_readout.visible and _fps_timer<=0:
		_fps_timer = .25
		_fps_readout.text = "%d FPS" % Engine.get_frames_per_second()
	var start_x := _bars.position.x+_bars.size.x+16.0
	var corner := _minimap_corner()
	var end_x := corner.x-16.0
	if end_x-start_x<120.0:
		start_x = corner.x+Minimap.ART_PIXELS*PixelArt.SCALE-240.0
		buff_strip.position = Vector2(start_x,corner.y-12.0)
		buff_strip.fit_gap(240.0)
	else:
		buff_strip.position = Vector2(start_x,_ui_root.size.y-MARGIN)
		buff_strip.fit_gap(end_x-start_x)
	_drunk = move_toward(_drunk, minf(stats.buffs.count("drunk"), 6.0)/3.0, _delta*0.4)
	_drunk_overlay.visible = _drunk>0.01
	if _drunk_overlay.visible: (_drunk_overlay.material as ShaderMaterial).set_shader_parameter("strength", _drunk)
	_update_bars()
	# The backpack shows while Tab is held or you stand on a loot bag (with
	# the bag under it), and stays open during a drag.
	var dragging := get_viewport().gui_is_dragging()
	var bag: LootBag = loot.bag_at(player) if loot else null
	if bag != _bag_panel.bag or (bag == null and _bag_panel.visible):
		_bag_panel.show_bag(bag)
	var tab := not player.controls_locked() and (Input.is_action_pressed("inventory") or (_inventory.visible and dragging and bag == null))
	var open := tab or bag != null or forge.visible or shop.visible
	if open != _inventory.visible:
		_inventory.visible = open
		if not open:
			_tooltip.hide()
	interaction.update_prompt(player, account_bar.is_open() or (open or dragging) and not forge.visible and not shop.visible)
	if social_panel and social_panel.visible:
		social_panel.reset_size()
		social_panel.global_position = Vector2(chat.button_row.global_position.x,
				chat.button_row.global_position.y - social_panel.size.y - 4.0)
	player.ui_blocked = tab or interaction.opened or account_bar.is_open()
	_boss_bar.track(Boss.nearest_active(player.global_position))
	quest_banner.boss_visible = _boss_bar.visible
	toasts.position.y = quest_banner.position.y + quest_banner.size.y + 10.0 if quest_banner.visible else MARGIN + 116
	# Only catch drops while something is being dragged (so clicks still shoot).
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP if dragging else Control.MOUSE_FILTER_IGNORE
	if not player.frozen and not player.controls_locked():
		if Input.is_action_just_pressed("quick_1"):
			GameServer.request_use(player.player_id, {kind = "quick", key = 0})
		if Input.is_action_just_pressed("quick_2"):
			GameServer.request_use(player.player_id, {kind = "quick", key = 1})


## Keep peripheral controls readable on hover without dimming combat bars/map.
func _update_world_ui_fade(delta: float, pointer: Vector2) -> void:
	var in_tavern := not is_instance_valid(_world) or Campaigns.is_tavern(_world.realm_id)
	var controls: Array[Control] = [account_bar, picker, _equipment_column, _stats_panel, quest_banner, toasts, buff_strip]
	if chat: controls.append(chat)
	if social_panel: controls.append(social_panel)
	var inventory_open := Input.is_action_pressed("inventory") or (is_instance_valid(_inventory) and _inventory.visible)
	var hovered := false
	for control in controls:
		if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(pointer):
			hovered = true
			break
	if inventory_open or hovered or account_bar.is_open(): _hud_reveal_left = 0.8
	else: _hud_reveal_left = maxf(0.0, _hud_reveal_left - delta)
	var target := 1.0 if in_tavern or _hud_reveal_left > 0.0 else WORLD_UI_ALPHA
	for control in controls:
		if not is_instance_valid(control): continue
		var blend := 1.0 - exp(-delta * (14.0 if target > control.modulate.a else 3.5))
		control.modulate.a = lerpf(control.modulate.a, target, blend)


## Debug: opens the backpack as if Tab were held.
func debug_open_inventory() -> void:
	Input.action_press("inventory")


func _input(event: InputEvent) -> void:
	if account_bar.is_open():
		_tooltip.hide()
		if event.is_action_pressed("menu") or event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			account_bar.toggle()
			get_viewport().set_input_as_handled()
		elif account_bar.handle_scroll(event):
			get_viewport().set_input_as_handled()
		return
	if account_bar.handle_scroll(event):
		get_viewport().set_input_as_handled()
		return
	if chat and not player.frozen and not player.input_locked and not player.cinematic_locked and chat.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if player.controls_locked() or player.frozen: return
	if interaction.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	# Wheel events reach _input before Godot scroll containers handle them.
	# Leave UI scrolling alone; only world/minimap wheel input changes zoom.
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != null and hovered != minimap and not minimap.is_ancestor_of(hovered):
			return
	if event.is_action_pressed("minimap_zoom_in"):
		minimap.zoom(-1)
	elif event.is_action_pressed("minimap_zoom_out"):
		minimap.zoom(1)
	elif event.is_action_pressed("stats"):
		toggle_stats()
	elif event.is_action_pressed("map"):
		toggle_map()
