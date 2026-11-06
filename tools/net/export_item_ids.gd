extends SceneTree
## Prints every item id except story items, one per line (for
## `void_accounts.py fill-vault NAME FILE`):
##   godot --headless --path . -s res://tools/net/export_item_ids.gd > ids.txt
func _init() -> void:
	for item in Items.all():
		if not item.is_story():
			print(item.id)
	quit()
