class_name EconomyServer
extends Node
## What an account owns beyond its characters, on the dedicated server:
##   * the Chambers: the account vault (ChambersWorld). Its chests are vault
##     bags in GameServer (so dragging, reach checks and replication work as
##     for loot chests), spawned while their owner is in the Chambers. Every
##     change is saved with the character's data in one go
##     (/server/vault/save), so an item is never in both places, nor lost.
##   * Dots, the account currency: dismantling at the forge
##     (/server/dismantle pays and saves the character together), first
##     campaign completions and packs (/server/dots/award).
##   * developer accounts: /give.
## Player records (NetServer.peers) carry: dots, developer, vault
## ({items, chests, dirty, bags} once loaded).

const SAVE_DELAY := 1.5  # seconds after a vault change before it is saved

var server: NetServer


func _ready() -> void:
	GameServer.bag_changed.connect(_on_bag_changed)


## A character was claimed (joined or switched): the account's part of it.
func take_account(p: Dictionary, account: Dictionary) -> void:
	p.dots = int(account.get("dots", 0))
	p.developer = bool(account.get("developer", false))
	p.chests = int(account.get("chests", 4))


func send_dots(p: Dictionary, gained := 0, source := "") -> void:
	server.social.send(p.player_id, ["dots", int(p.get("dots", 0)), gained, source])


# --- Chambers ------------------------------------------------------------------------

## The Chambers' record for the client, or {error}. Loads the vault the
## first time (it stays with the player record while they're online).
func enter(p: Dictionary) -> Dictionary:
	if p.get("vault", {}).is_empty():
		var r := await server.api.call_api("POST", "/server/vault/load", {character_id = p.character_id})
		if not r.ok:
			return {error = "Your Chambers are locked right now (%s)." % r.error}
		var items: Array = Net.decode_items(r.data.get("items", []))
		var chests := maxi(1, int(r.data.get("chests", 4)))
		items.resize(chests * LootBag.SLOTS)
		p.vault = {items = items, chests = chests, dirty = false, revision = 0, bags = []}
		p.chests = chests
	return {id = ChambersWorld.id_for(p.account_id), chambers = true, chests = int(p.vault.chests)}


## Puts the vault chests in the Chambers (call once the player is in it).
func spawn_chests(p: Dictionary) -> void:
	var vault: Dictionary = p.get("vault", {})
	if vault.is_empty() or not vault.bags.is_empty():
		return
	var layout := ChambersWorld.chest_layout(vault.chests)
	for i in vault.chests:
		var items: Array = vault.items.slice(i * LootBag.SLOTS, (i + 1) * LootBag.SLOTS)
		var id := GameServer.spawn_fixed_bag(p.realm, items, layout[i][0], p.player_id, "vault",
				{yaw = layout[i][1], vault_of = p.player_id, vault_index = i, label = "Chambers chest %d" % (i + 1)})
		vault.bags.append(id)


## They leave the Chambers: the chests go (their items stay in the vault).
func leave(p: Dictionary) -> void:
	var vault: Dictionary = p.get("vault", {})
	if vault.is_empty():
		return
	for id: int in vault.bags:
		_sync(vault, GameServer.bag(id))
		GameServer.remove_bag(id)
	vault.bags.clear()


func _on_bag_changed(bag_id: int) -> void:
	var record := GameServer.bag(bag_id)
	if not record.has("vault_of"):
		return
	var p := server.social.record(int(record.vault_of))
	var vault: Dictionary = p.get("vault", {})
	if vault.is_empty():
		return
	_sync(vault, record)
	vault.dirty = true
	# Saves cross an await while the player can keep moving items. A newer
	# chest update must remain dirty when an older snapshot finishes saving.
	vault.revision = int(vault.get("revision", 0)) + 1
	if not p.get("vault_save_queued", false):
		p.vault_save_queued = true
		get_tree().create_timer(SAVE_DELAY).timeout.connect(func() -> void:
			p.vault_save_queued = false
			if server.peers.has(p.peer_id) and p.joined and not p.dead:
				server.save_record(p))


func _sync(vault: Dictionary, record: Dictionary) -> void:
	if record.is_empty():
		return
	var start := int(record.vault_index) * LootBag.SLOTS
	for k in LootBag.SLOTS:
		vault.items[start + k] = record.items[k]


## For NetServer's save: the vault's items for the wire, when it changed.
func pending_vault(p: Dictionary) -> Variant:
	var vault: Dictionary = p.get("vault", {})
	if vault.is_empty() or not vault.dirty:
		return null
	for id: int in vault.bags:
		_sync(vault, GameServer.bag(id))
	return Net.encode_items(vault.items)


# --- Dots ----------------------------------------------------------------------------

## The forge: [place, item id]. The item goes, its Dots come, together.
func dismantle(p: Dictionary, place: Variant, item_id: String) -> void:
	var stats := GameServer.character(p.player_id)
	if stats == null or not place is Dictionary or str(place.get("kind", "")) == "bag" or not (Campaigns.is_tavern(p.realm) or _by_reach_smith(p)):
		return
	if not str(place.kind) in ["pack", "gear", "quick"] or not _valid_key(stats, place):
		return
	var item := stats.item_at(place)
	if item == null or item.id != item_id:
		server.social.system(p.player_id, "That item isn't there any more.")
		return
	var value := Dots.dismantle_value(item)
	if value <= 0:
		server.social.system(p.player_id, "Bram shakes his head: that can't go in the forge.")
		return
	stats.take(place)
	if server.config.test_mode:  # nothing is saved in test mode
		p.dots = int(p.get("dots", 0)) + value
		send_dots(p, value, "forge")
		return
	var r: Dictionary = await server.save_record(p, {kind = "dismantle", item_id = item.id, count = item.count})
	if r.get("ok", false):
		p.dots = int(r.data.get("dots", p.dots))
		send_dots(p, int(r.data.get("gained", value)), "forge")
		server.social.system(p.player_id, "The forge roars: [b]%s[/b] became %s Dots." % [item.item_name, Dots.format(value)])
	else:
		if stats.item_at(place) == null:
			stats._put(place, item)
		else:
			stats.give([item])
		stats.changed.emit()
		server.social.system(p.player_id, "The forge sputters out (%s). You keep your item." % r.get("error", "no answer"))


func _valid_key(stats: PlayerStats, place: Dictionary) -> bool:
	match str(place.kind):
		"gear":
			return stats.gear.has(place.key)
		"quick":
			return place.key is int and place.key >= 0 and place.key < stats.quick.size()
	return place.key is int and place.key >= 0 and place.key < stats.backpack.size()


## Standing by one of the Astral Reach's town smiths.
func _by_reach_smith(p: Dictionary) -> bool:
	var realm: RealmInstance = server.realms.get(p.get("realm", ""))
	return realm != null and realm.world is SpaceWorld and (realm.world as SpaceWorld).near_smith(p.pos)


## Spends Dots on the server's word (a ship...): false when they can't afford
## it. The balance changes at once; the account follows (award of -amount).
func spend(p: Dictionary, amount: int, source: String) -> bool:
	if amount <= 0 or int(p.get("dots", 0)) < amount:
		return false
	p.dots = int(p.dots) - amount
	send_dots(p, -amount, source)
	_persist_spend(p, amount, source)
	return true


func _persist_spend(p: Dictionary, amount: int, source: String) -> void:
	var r := await server.api.call_api("POST", "/server/dots/award", {character_id = p.character_id, amount = -amount})
	if r.ok:
		p.dots = int(r.data.get("dots", p.dots))
		send_dots(p, 0, source)
	else:
		push_warning("Couldn't take %d Dots from %s for %s: %s" % [amount, p.name, source, r.error])


## Dots for a first campaign completion, a pack...
func award(p: Dictionary, amount: int, source: String) -> void:
	if amount <= 0 or p.is_empty():
		return
	if server.config.test_mode:
		p.dots = int(p.get("dots", 0)) + amount
		send_dots(p, amount, source)
		return
	var r := await server.api.call_api("POST", "/server/dots/award", {character_id = p.character_id, amount = amount})
	if r.ok:
		p.dots = int(r.data.get("dots", p.dots))
		send_dots(p, int(r.data.get("gained", amount)), source)
	else:
		push_warning("Couldn't award %d Dots to %s: %s" % [amount, p.name, r.error])


# --- Developers ----------------------------------------------------------------------

## /give <player> <item id> [count]
func give(p: Dictionary, args: String) -> void:
	if not p.get("developer", false):
		server.social.system(p.player_id, "Only developers can use /give.")
		return
	var parts := args.split(" ", false)
	if parts.size() < 2:
		server.social.system(p.player_id, "Write /give <player> <item id> [count], e.g. /give p2 G5_bow.")
		return
	var o := server.social.find(parts[0])
	var item := Items.make(parts[1])
	if o.is_empty():
		server.social.system(p.player_id, "%s isn't on this server." % parts[0])
		return
	if item == null:
		server.social.system(p.player_id, "There's no item called %s." % parts[1])
		return
	var stats := GameServer.character(o.player_id)
	if stats == null or o.dead:
		server.social.system(p.player_id, "%s can't take items right now." % o.name)
		return
	var count := clampi(int(parts[2]) if parts.size() > 2 and parts[2].is_valid_int() else 1, 1, 99)
	var items: Array = []
	if item.stack_max > 1:
		item.count = mini(count, item.stack_max)
		items.append(item)
	else:
		for i in mini(count, 20):
			items.append(Items.make(parts[1]))
	var given := stats.give(items)
	if given < items.size():
		var rest := items.slice(given)
		GameServer.spawn_bag(o.realm, rest, o.pos, o.player_id, (rest[0] as Item).bag_type())
	server.social.system(p.player_id, "Gave %s ×%d to %s." % [item.item_name, items.size() if item.stack_max <= 1 else item.count, o.name])
	if o != p:
		server.social.system(o.player_id, "A developer gave you [b]%s[/b]." % item.item_name)
