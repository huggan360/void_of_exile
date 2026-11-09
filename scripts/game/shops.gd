class_name Shops
## Shops: keepers who sell items for Dots. What every shop sells, its prices
## and its offers come from the account service (SHOPS in
## account_service/void_accounts.py), so they are the same on every server and
## in Singleplayer; this file names the shops, picks their keepers and words
## their speech bubbles. Keep the shop ids in step with the account service.
##
## Place a shop anywhere with ShopKeeper.place(parent, "wizard", frame).
## The game server fetches the shops' state (EconomyServer.refresh_shops) and
## sends it to every player; `state` holds the latest copy on the client:
## {now, ends, offers: [{shop ("*" = all), family, percent, ends}],
##  shops: {id: {stock: [{id, base, price, off, left (-1 = plenty)}]}}, families: {family: name}}

const DEFS := {
	wizard = {name = "The Wizard", title = "Wands, spells and robes", model = "npc_magician", color = "9a8aff",
		hello = ["Wands that hum, spells that sing.", "Mind the robes, they bite.", "Magic for every pocket!"]},
	priest = {name = "The Priest", title = "Crucifixes, robes and blessings", model = "city_elder", color = "fff0c8",
		hello = ["Blessings, child. And crucifixes.", "Holy wares, fairly priced.", "Light a candle, buy a cross."]},
	bowyer = {name = "The Bowyer", title = "Bows, cloaks and eyes", model = "npc_traveler", color = "8dff9a",
		hello = ["Straight arrows, true bows!", "A good cloak keeps the rain off.", "Feel the draw on this one."]},
	tidecaller = {name = "The Tidecaller", title = "Tridents and sea charms", model = "city_alien_squid", color = "6af0e0",
		hello = ["Tridents from the deep!", "Salt-forged, tide-tested.", "Talismans that smell of the sea."]},
	alchemist = {name = "The Alchemist", title = "Flames and elixirs", model = "city_alien_frog", color = "ff8a5a",
		hello = ["Bubbles! Elixirs! Mild explosions!", "Drink responsibly. Or don't.", "Flames in a jar, fresh today."]},
	general = {name = "Bits and Bobs", title = "A bit of everything, cheap", model = "city_alien_fourarm", color = "ffcf6a",
		hello = ["Come in, come in! Bargains for every pocket!", "Cheap and cheerful, that's us!", "Four hands, half the price!"]},
	premium = {name = "The Silver Spire", title = "Fine gear, finer prices", model = "city_noble", color = "e8e8ff",
		hello = ["Only the finest in Vesperis.", "Polished, enchanted, guaranteed.", "Quality has a price, darling."]},
	curio = {name = "Curios of the Void", title = "Charms, talismans, oddities", model = "city_alien_moth", color = "ff8ad8",
		hello = ["Oddities from beyond the Reach...", "Everything here has a story.", "Touch nothing that hums."]},
	relic = {name = "The Relic Keeper", title = "Divine relics, rarely", model = "city_alien_crystal", color = "ffd84a",
		hello = ["Relics come and go...", "Divine things find their own way here.", "Patience. The gods restock slowly."]},
}
const OFFER_COLOR := "c8245a"  # deep enough to read on the cream bubble
const ITEM_COLOR := "1d64a8"
static var state := {}
static var received_at := 0.0  # Time when `state` came (its clock may differ from ours)

static func set_state(data: Dictionary) -> void:
	state = data
	received_at = Time.get_unix_time_from_system()

## The account service's clock now, from the last state.
static func now() -> float:
	return float(state.get("now", 0.0))+Time.get_unix_time_from_system()-received_at

static func stock(shop: String) -> Array:
	return state.get("shops", {}).get(shop, {}).get("stock", [])

## Offers that touch this shop (its own and those everywhere), still running.
static func offers(shop: String) -> Array:
	var t := now()
	return state.get("offers", []).filter(func(o: Dictionary) -> bool:
		return (str(o.shop)==shop or str(o.shop)=="*") and float(o.ends)>t)

static func family_name(family: String) -> String:
	return str(state.get("families", {}).get(family, family.replace("bonus_", "")+"s"))

static func time_left(ends: float) -> String:
	var left := maxi(0, int(ends-now()))
	if left>=3600: return "%dh %dm" % [left/3600, (left % 3600)/60]
	return "%dm" % maxi(1, left/60)

## What a keeper says right now: a bold, coloured offer when there is one,
## the rare stock, or (for the relic keeper) whether there is anything at all.
## BBCode for SpeechBubble.say(..., "shop").
static func pitch(shop: String, beat: int) -> String:
	var def: Dictionary = DEFS.get(shop, {})
	var list := offers(shop)
	var lines: Array[String] = []
	for o: Dictionary in list:
		var what := "[b][color=#%s]%s[/color][/b]" % [ITEM_COLOR, family_name(str(o.family))]
		var cut := "[b][color=#%s]%d%% off[/color][/b]" % [OFFER_COLOR, int(o.percent)]
		if str(o.shop)=="*":
			lines.append("City-wide sale! %s %s in every shop, [b]%s[/b] left!" % [cut, what, time_left(float(o.ends))])
		else:
			lines.append("%s on %s for the next [b]%s[/b]!" % [cut, what, time_left(float(o.ends))])
	var rare := stock(shop).filter(func(e: Dictionary) -> bool: return int(e.left)>0)
	if shop=="relic":
		if rare.is_empty(): lines.append("Nothing today. The gods are stingy. Come back in [b]%s[/b]." % time_left(float(state.get("ends", 0))))
		else:
			for e: Dictionary in rare:
				var item := Items.make(str(e.id))
				if item: lines.append("Behold: [b][color=#%s]%s[/color][/b]. Only one." % [OFFER_COLOR, item.item_name])
	else:
		for e: Dictionary in rare:
			var item := Items.make(str(e.id))
			if item: lines.append("Just in: [b][color=#%s]%s[/color][/b]! Only one." % [ITEM_COLOR, item.item_name])
	for line: String in def.get("hello", []): lines.append(line)
	if lines.is_empty(): return ""
	# Offers first and most often.
	if not list.is_empty() and beat % 2==0: return lines[(beat/2) % list.size()]
	return lines[beat % lines.size()]

## A stand-in state when no account service answers:
## every shop's plain grades at their base price, no offers, no rare pieces.
static func fallback() -> Dictionary:
	var base := [0, 20, 50, 90, 150, 240, 1000, 1800, 2600]
	var families := {wizard = ["wand", "spell", "robe", "bonus_crystal"], priest = ["bonus_crucifix", "robe", "spell"],
		bowyer = ["bow", "cloak", "bonus_eye"], tidecaller = ["trident", "cloak", "bonus_talisman"], alchemist = ["bonus_flame"],
		general = ["bow", "cloak", "wand", "trident", "robe", "spell"], premium = ["bow", "cloak", "wand", "trident", "robe"],
		curio = ["bonus_crucifix", "bonus_flame", "bonus_eye", "bonus_crystal", "bonus_talisman"], relic = []}
	var shops := {}
	for shop: String in families:
		var list: Array = []
		for family: String in families[shop]:
			for tier in range(2, 6):
				list.append({id = "G%d_%s" % [tier, family], base = base[tier], price = base[tier], off = 0, left = -1})
		shops[shop] = {stock = list}
	var t := Time.get_unix_time_from_system()
	return {now = t, ends = t+7200.0, offers = [], shops = shops, families = {}}
