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
const HEART := ["..o.o..", ".oRoRo.", "oRWRRRo", "oRRRRRo", ".oRRRo.", "..oRo..", "...o..."]
const STAR := ["...o...", "..oYo..", "ooYWYoo", "oYYYYYo", ".oYYYo.", "oYo.oYo", "oo...oo"]

var stats: PlayerStats
var player: Player
var toasts := ToastFeed.new()
var minimap := Minimap.new()
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
	_fps_readout.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_readout.position = Vector2(MARGIN,-42)
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
	_boss_bar.position.y = MARGIN + 58
	var boss_width := BossBar.BAR_SIZE.x + BossBar.PORTRAIT + 14
	_boss_bar.offset_left = -boss_width * 0.5
	_boss_bar.offset_right = boss_width * 0.5
	root.add_child(_boss_bar)

	# Bottom center: health and magic.
	var bars := VBoxContainer.new()
	_bars = bars
	bars.add_theme_constant_override("separation", 6)
	bars.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bars.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bars.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hp_bar.set_icon(PackedStringArray(HEART), {"o": UIStyle.OUTLINE, "R": UIStyle.HP, "W": Color(1, 0.8, 0.8)})
	_mp_bar.set_icon(PackedStringArray(STAR), {"o": UIStyle.OUTLINE, "Y": UIStyle.MAGIC, "W": Color(1, 1, 0.85)})
	var bars_size := _hp_bar.custom_minimum_size + Vector2(0, _mp_bar.custom_minimum_size.y + 6)
	bars.offset_top = -MARGIN - bars_size.y
	bars.offset_bottom = -MARGIN
	bars.offset_left = -bars_size.x * 0.5
	bars.offset_right = bars_size.x * 0.5
	bars.add_child(_hp_bar)
	bars.add_child(_mp_bar)
	root.add_child(bars)


	# Bottom right: minimap.
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimap.offset_left = -MARGIN - minimap.custom_minimum_size.x
	minimap.offset_top = -MARGIN - minimap.custom_minimum_size.y
	minimap.offset_right = -MARGIN
	minimap.offset_bottom = -MARGIN
	minimap.player = player
	root.add_child(minimap)
	buff_strip.effects = stats.buffs
	root.add_child(buff_strip)

	# Top right: stats button, XP ring, gear.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.offset_left = -MARGIN - 280
	column.offset_right = -MARGIN
	column.offset_top = MARGIN
	root.add_child(column)
	var stats_button := UIStyle.button("Stats")
	stats_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	stats_button.pressed.connect(toggle_stats)
	column.add_child(stats_button)
	_xp_ring.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_xp_ring)
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

	# Top center: the account's XP bar, level and reward drawer.
	account_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	account_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var bar_width := AccountBar.BAR_SIZE.x + 60
	account_bar.offset_left = -bar_width * 0.5
	account_bar.offset_right = bar_width * 0.5
	account_bar.offset_top = MARGIN
	root.add_child(account_bar)
	# Top left: who you play.
	picker = CharacterPicker.new(stats)
	picker.position = Vector2(MARGIN, MARGIN)
	root.add_child(picker)

	_tooltip.stats = stats
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


func toggle_stats() -> void:
	_stats_panel.visible = not _stats_panel.visible
	if _stats_panel.visible:
		account_bar.close_rewards()
		_stats_panel.refresh()
		_stats_panel.modulate.a = 0.0
		_stats_panel.create_tween().tween_property(_stats_panel, "modulate:a", 1.0, 0.15)


## Debug: shows a slot's tooltip as if hovered.
func debug_show_tooltip(slot_id: String) -> void:
	_tooltip.show_item(stats.gear.get(slot_id))


func set_world(world: GameWorld, fog_of_war: FogOfWar) -> void:
	interaction.set_world(world)
	minimap.fog_of_war = fog_of_war
	minimap.setup(world)
	_world = world
	refresh_markers()


## Bottom left: the chat with its friends and party panel. Top: the quest
## banner under the account bar.
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
	chat.offset_top = -56
	chat.offset_bottom = -56
	_ui_root.add_child(chat)
	# Over the chat log, sitting right on its buttons (see _process).
	_ui_root.add_child(social_panel)
	chat.panel_requested.connect(social_panel.show_tab)
	quest_banner.social = social
	quest_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	quest_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	quest_banner.offset_left = -240
	quest_banner.offset_right = 240
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
	_fps_readout.visible = AppSettings.video.show_fps
	_fps_timer -= _delta
	if _fps_readout.visible and _fps_timer<=0:
		_fps_timer = .25
		_fps_readout.text = "%d FPS" % Engine.get_frames_per_second()
	var start_x := _bars.position.x+_bars.size.x+16.0
	var end_x := minimap.position.x-16.0
	if end_x-start_x<120.0:
		start_x = minimap.position.x+minimap.size.x-240.0
		buff_strip.position = Vector2(start_x,minimap.position.y-12.0)
		buff_strip.fit_gap(240.0)
	else:
		buff_strip.position = Vector2(start_x,_ui_root.size.y-MARGIN)
		buff_strip.fit_gap(end_x-start_x)
	_hp_bar.set_values(stats.hp, stats.max_hp)
	_mp_bar.set_values(stats.mp, stats.max_mp)
	# The backpack shows while Tab is held or you stand on a loot bag (with
	# the bag under it), and stays open during a drag.
	var dragging := get_viewport().gui_is_dragging()
	var bag: LootBag = loot.bag_at(player) if loot else null
	if bag != _bag_panel.bag or (bag == null and _bag_panel.visible):
		_bag_panel.show_bag(bag)
	var tab := not player.controls_locked() and (Input.is_action_pressed("inventory") or (_inventory.visible and dragging and bag == null))
	var open := tab or bag != null
	if open != _inventory.visible:
		_inventory.visible = open
		if not open:
			_tooltip.hide()
	interaction.update_prompt(player, open or dragging)
	# Reward details are secondary to all other HUD tabs and dialogs.
	if account_bar.is_open() and ((_stats_panel and _stats_panel.visible) or (social_panel and social_panel.visible) or (picker and picker.visible and picker.has_method("is_open") and picker.is_open())):
		account_bar.close_rewards()
	if social_panel and social_panel.visible:
		social_panel.reset_size()
		social_panel.global_position = Vector2(chat.button_row.global_position.x,
				chat.button_row.global_position.y - social_panel.size.y - 4.0)
	# Boss health takes priority over campaign objectives so neither blocks the fight.
	_boss_bar.track(Boss.nearest_active(player.global_position))
	quest_banner.hidden_by_boss = _boss_bar.visible
	quest_banner.offset_top = MARGIN + 64.0

	player.ui_blocked = tab or interaction.opened
	# Only catch drops while something is being dragged (so clicks still shoot).
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP if dragging else Control.MOUSE_FILTER_IGNORE
	if not player.frozen and not player.controls_locked():
		if Input.is_action_just_pressed("quick_1"):
			GameServer.request_use(player.player_id, {kind = "quick", key = 0})
		if Input.is_action_just_pressed("quick_2"):
			GameServer.request_use(player.player_id, {kind = "quick", key = 1})


## Debug: opens the backpack as if Tab were held.
func debug_open_inventory() -> void:
	Input.action_press("inventory")


func _input(event: InputEvent) -> void:
	if chat and not player.frozen and not player.input_locked and not player.cinematic_locked and chat.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if player.controls_locked() or player.frozen: return
	if interaction.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("minimap_zoom_in"):
		minimap.zoom(-1)
	elif event.is_action_pressed("minimap_zoom_out"):
		minimap.zoom(1)
	elif event.is_action_pressed("stats"):
		toggle_stats()
