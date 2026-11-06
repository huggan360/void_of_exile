extends Node3D
## Short regression check for anvil snapshots, drag presentation and throne fit.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	GameServer.set_physics_process(false)
	var pid := GameServer.join(false)
	var stats := GameServer.character(pid)
	stats.backpack[0] = Items.make("G5_bow")
	var source_place := {kind="pack",key=0}
	var source := ItemSlot.new("",stats,source_place)
	source.set_item(stats.item_at(source_place))
	add_child(source)
	var anvil := ForgePanel.ForgeSlot.new(stats)
	anvil.position.x = 100
	add_child(anvil)
	var data := {from=source_place}
	check(anvil._can_drop_data(Vector2.ZERO,data),"Anvil accepts gear from the backpack")
	anvil._drop_data(Vector2.ZERO,data)
	check(anvil.item!=null and source.artwork_held(),"Staged item appears on the anvil and its source artwork is held")
	var original := anvil.item
	stats.load_data(stats.to_data())
	source.set_item(stats.item_at(source_place))
	anvil.validate()
	check(anvil.item!=null and anvil.item!=original and anvil.item.id==original.id,"Anvil survives reconstructed inventory resources")
	check(source.artwork_held(),"Snapshot does not duplicate staged source artwork")
	anvil.clear()
	check(not source.artwork_held() and stats.item_at(source_place)!=null,"Cancelling restores artwork without moving or losing the item")
	anvil._drop_data(Vector2.ZERO,data)
	stats.backpack[0] = Items.make("G4_bow")
	anvil.validate()
	source.set_item(stats.item_at(source_place))
	check(anvil.item==null and not source.artwork_held(),"Anvil clears when the source item actually changes")
	ItemSlot._drag_source = {player_id=pid,place=source_place,item_id=source.item.id}
	var preview := ItemIcon.new()
	preview.show_item(source.item)
	preview.size = Vector2(40,40)
	source.force_drag(data,preview)
	check(get_viewport().gui_is_dragging() and source.artwork_hidden(),"Dragging hides the source artwork")
	if get_viewport().has_method("gui_cancel_drag"):
		get_viewport().call("gui_cancel_drag")
	else:
		source._notification(NOTIFICATION_DRAG_END)
	check(not source.artwork_hidden(),"Cancelled drag restores the source artwork")
	var pixels := source.item.icon().get_image().get_data()
	var mask := source.item.outline_mask()
	check(mask.get_image().has_mipmaps(),"Oversampled outline includes mipmaps")
	check(source.item.icon().get_image().get_data()==pixels,"Smoothing leaves original item pixels unchanged")
	check(Items.make(source.item.id).outline_mask()==mask,"Inventory copies reuse the same smooth outline")
	var chambers := ChambersWorld.new()
	check(chambers.spawn_point==Vector3.ZERO and chambers.is_walkable(chambers.spawn_point),"Chambers spawn is in the clear middle aisle")
	check(chambers.is_walkable(ChambersWorld.RETURN_PORTAL),"Relocated portal has a clear approach")
	chambers.free()
	var smith := load("res://scenes/home/prefabs/smithy.tscn").instantiate() as Node3D
	check(smith.get_node("CarvedVoxels").position.y>-0.125,"Smithy artwork is raised clear of terrain")
	smith.free()
	var king := CreatureModel.new("hollow_king")
	king.scale = Vector3.ONE*0.85
	king.position = CastleWorld.THRONE_SEAT
	king.rotation.y = PI
	add_child(king)
	king.boss_pose("sit",100)
	king.animate(0.0,2.0)
	var knee: Node3D = king._limbs.knee_l
	var foot := knee.to_global(Vector3(0,-64,0)*king._voxel_size)
	var pelvis := king._rig.to_global(Vector3(0,96,0)*king._voxel_size)
	check(foot.z>king.position.z+0.5,"Seated knees and boots face the front of the throne")
	check(absf(foot.y-CastleWorld.THRONE_SEAT.y)<0.12,"Seated boots rest on the dais")
	check(absf(pelvis.y-3.95)<0.08,"Seated robe meets the throne cushion")
	king.queue_free()
	anvil.queue_free()
	source.queue_free()
	await get_tree().process_frame
	print("FORGE/DRAG/SEATING: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
