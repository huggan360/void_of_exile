class_name StoryReader
extends PanelContainer
## Reading a story item (double-click it): the torn map shows the pieces you
## hold fitted together, with their words (the missing ones blank); a card
## shows its art and what it says.

static var _layer: ResponsiveUILayer


static func open(item: Item) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not is_instance_valid(_layer):
		_layer = ResponsiveUILayer.new()
		_layer.layer = 60
		tree.root.add_child(_layer)
		_layer.make_ui_root()
	for child in _layer._ui_root.get_children():
		child.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer._ui_root.add_child(center)
	var reader := StoryReader.new()
	reader.item = item
	center.add_child(reader)
	reader.tree_exited.connect(center.queue_free)


var item: Item


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	custom_minimum_size = Vector2(520, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	column.add_child(UIStyle.heading(item.item_name, 26))
	if item.id == "story_clue":
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 0)
		grid.add_theme_constant_override("v_separation", 0)
		for k in 6:
			var piece := TextureRect.new()
			piece.custom_minimum_size = Vector2(96, 96)
			piece.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			piece.stretch_mode = TextureRect.STRETCH_SCALE
			piece.texture = load("res://items/textures/story_clue_%d.png" % (k + 1))
			piece.modulate = Color.WHITE if k < item.count else Color(0.15, 0.15, 0.2, 0.35)
			grid.add_child(piece)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(grid)
		for k in 6:
			var line: String = Items.CLUE_TEXT[k] if k < item.count else "......"
			column.add_child(_text("[i]%s[/i]" % line, UIStyle.TEXT if k < item.count else UIStyle.TEXT_DIM))
		column.add_child(_text("%d of 6 pieces" % item.count, UIStyle.TEXT_DIM))
	else:
		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(160, 160)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.texture = item.icon()
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(art)
		var words: String = Items.STORY_ITEMS.get(item.id, ["", "", "", ""])[3]
		for page in TextMarkup.pages(words if words != "" else item.lore):
			column.add_child(_text(page, UIStyle.TEXT))
	var close := UIStyle.button("Close")
	close.pressed.connect(queue_free)
	column.add_child(close)


func _text(bbcode: String, color: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_override("normal_font", UIStyle.font())
	label.add_theme_font_override("bold_font", UIStyle.bold())
	label.add_theme_font_override("italics_font", UIStyle.font())
	label.add_theme_color_override("default_color", color)
	label.text = TextMarkup.to_bbcode(bbcode).replace("[lb]i]", "[i]").replace("[lb]/i]", "[/i]")
	return label


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		queue_free()
		get_viewport().set_input_as_handled()
