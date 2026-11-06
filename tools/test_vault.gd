extends Node

class BlockingApi extends AccountApi:
	signal request_started
	signal continue_request
	var called := false

	func call_api(_method: String, _path: String, _body: Dictionary = {}) -> Dictionary:
		called = true
		request_started.emit()
		await continue_request
		return {ok = true, data = {}}


func _ready() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("[vault-regression] " + message)
	get_tree().quit(1)
	return false


func _run() -> void:
	var stats := PlayerStats.new()
	var player_id := GameServer.add_player(stats)
	GameServer.report_position(player_id, "chm_regression", Vector3.ZERO)
	var item := Items.all()[0] as Item
	var chest_id := GameServer.spawn_fixed_bag("chm_regression", [item], Vector3.ZERO, player_id, "vault",
		{vault_of = player_id, vault_index = 0, label = "Regression chest"})
	var chest_place := {kind = "bag", key = 0, bag = chest_id}

	GameServer.report_position(player_id, "chm_regression", Vector3(4, 0, 0))
	if not _expect(not GameServer.request_activate(player_id, chest_place), "A chest outside reach must refuse activation"): return
	GameServer.report_position(player_id, "chm_regression", Vector3(1.7, 0, 0))
	if not _expect(GameServer.request_activate(player_id, chest_place),
		"A fresh local bag UI must tolerate a slightly stale server position packet"): return
	if not _expect(GameServer.bag(chest_id).items[0] == null, "The item should withdraw within the network movement slack"): return
	# Put the item back to test the ordinary nearby withdrawal below.
	var nearby_slot := stats.backpack.find_custom(func(value: Variant) -> bool: return value != null and value.id == item.id)
	if not _expect(nearby_slot >= 0, "The withdrawn item should be in the backpack"): return
	GameServer.report_position(player_id, "chm_regression", Vector3.ZERO)
	if not _expect(GameServer.request_move(player_id, {kind = "pack", key = nearby_slot}, chest_place),
		"The withdrawn item should return to the vault"): return
	if not _expect(not GameServer.request_activate(player_id, {kind = "bag", key = 0, bag = -999}),
		"A missing chest must refuse activation"): return
	if not _expect(GameServer.request_activate(player_id, chest_place), "Double-click activation should withdraw a reachable item"): return
	if not _expect(GameServer.bag(chest_id).items[0] == null, "The withdrawn item should leave the chest"): return
	var held := stats.backpack.find_custom(func(value: Variant) -> bool: return value != null and value.id == item.id)
	if not _expect(held >= 0, "The withdrawn item should arrive in the backpack"): return

	var server := NetServer.new()
	server.config = ServerConfig.new()
	server.config.test_mode = false
	var vault_items: Array = []
	vault_items.resize(LootBag.SLOTS)
	server.peers[1] = {peer_id = 1, character_id = 42, name = "Vault regression", joined = true,
		dead = false, player_id = player_id, dirty = false, acct_pending = 0, saving = false,
		vault = {items = vault_items, chests = 1, dirty = true, revision = 1, bags = [chest_id]}}
	server.by_player[player_id] = 1
	server.social.server = server
	var api := BlockingApi.new()
	var unused_api: AccountApi = server.api
	server.api = api
	server.economy.server = server
	add_child(server.economy)
	var peer_record: Dictionary = server.peers[1]

	# Begin a save and change the chest while the account service is still
	# handling the earlier snapshot. The newer revision must remain dirty.
	server.save_record(peer_record)
	while not api.called:
		await get_tree().process_frame
	if not _expect(GameServer.request_move(player_id, {kind = "pack", key = held}, chest_place),
		"The item should be movable back into the reachable vault chest"): return
	var changed_revision := int(peer_record.vault.revision)
	api.continue_request.emit()
	while peer_record.saving:
		await get_tree().process_frame
	if not _expect(int(peer_record.vault.revision) == changed_revision,
		"A completed save must not rewrite the newer revision"): return
	if not _expect(peer_record.vault.dirty,
		"A newer chest change during an in-flight save must stay queued for persistence"): return

	print("[vault-regression] withdrawal, reach validation, and in-flight save race passed")
	GameServer.remove_bag(chest_id)
	GameServer.remove_player(player_id)
	server.economy.queue_free()
	server.social.free()
	server.dungeons.free()
	server.campaigns.free()
	unused_api.free()
	server.free()
	api.free()
	await get_tree().process_frame
	get_tree().quit(0)
