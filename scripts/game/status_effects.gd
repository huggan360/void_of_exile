class_name StatusEffects
extends RefCounted
## Temporary effects only. The server grants them; clients mirror their remaining time.
## Same id + source refreshes. Different sources stack and expire independently.
signal changed
const IDS := ["speed", "attack", "dexterity", "defense", "magic", "hp", "mp",
	"regeneration", "mana_regeneration", "static", "quiet", "burning", "armour_broken", "loot_chance", "loot_tier", "immune", "invincible", "drunk"]
const NAMES := {"speed":"Speed", "attack":"Attack", "dexterity":"Dexterity", "defense":"Defence", "magic":"Magic",
	"hp":"Health", "mp":"Magic points", "regeneration":"Regeneration", "mana_regeneration":"Mana regeneration",
	"static":"Static", "quiet":"Quiet", "burning":"Burning", "armour_broken":"Armour broken", "loot_chance":"Loot chance", "loot_tier":"Loot tier", "immune":"Immune", "invincible":"Invincible", "drunk":"Drunk"}
const ALIASES := {stasis="static", frozen="static", freeze="static", silence="quiet", burn="burning", defence="defense",
	health="hp", magic_points="mp", armor_broken="armour_broken", armour_breaking="armour_broken",
	mp_regen="mana_regeneration", regen="regeneration", higher_loot_chance="loot_chance", higher_loot_tiers="loot_tier"}
const MAX_EFFECTS := 64
const MAX_DURATION := 86400.0
var entries: Dictionary = {}
var revision := 0
var burning_immune := false
var _burn_elapsed := 0.0

static func canonical(id: String) -> String:
	return ALIASES.get(id.to_lower(), id.to_lower())

static func seconds(value: Variant) -> float:
	var text := str(value).strip_edges().to_lower()
	var mult := 1.0
	if text.ends_with("ms"):
		mult = .001
		text = text.trim_suffix("ms")
	elif text.ends_with("s"): text = text.trim_suffix("s")
	elif text.ends_with("m"):
		mult = 60.0
		text = text.trim_suffix("m")
	elif text.ends_with("h"):
		mult = 3600.0
		text = text.trim_suffix("h")
	if not text.is_valid_float(): return 0.0
	var result := text.to_float()*mult
	return clampf(result,0.0,MAX_DURATION) if is_finite(result) else 0.0

static func normalize(id: String, amount: Variant) -> Variant:
	var text := str(amount).strip_edges().to_lower()
	if text in ["+max", "max", "-max"] and id in PlayerStats.STATS + ["hp","mp"]:
		return "-max" if text == "-max" else "+max"
	var percent := text.ends_with("%")
	text = text.trim_suffix("%")
	if not text.is_valid_float(): return null
	var number := text.to_float() / (100.0 if percent else 1.0)
	if not is_finite(number): return null
	if id in ["static","quiet","burning","armour_broken","immune","invincible"]: return 1.0
	if id in ["loot_chance","loot_tier"]: return clampf(number,0.0,10.0 if id == "loot_chance" else 1.0)
	if id in ["regeneration","mana_regeneration"]: return clampf(number,0.0,100.0)
	return clampf(roundf(number),-100000.0,100000.0)

func add(id: String, duration: Variant, amount: Variant = 1, source := "default") -> bool:
	id = canonical(id)
	if id == "burning" and burning_immune: return false
	var time := seconds(duration)
	if not id in IDS or time <= 0.0: return false
	var value: Variant = normalize(id,amount)
	if value == null: return false
	if id not in ["immune", "invincible"] and (has_effect("immune") or has_effect("invincible")): return false
	if id in ["immune", "invincible"]:
		for old_key in entries.keys():
			if harmful(entries[old_key]): entries.erase(old_key)
	source = source.left(96)
	var key := id+":"+source
	if id == "burning":
		# One fire per target. A small follow-up hit cannot shorten a heavy burn.
		key = "burning:fire"
		var previous: Dictionary = entries.get(key,{})
		if previous.is_empty() or float(previous.expires)<=Net.now(): _burn_elapsed = 0.0
		if not previous.is_empty() and float(previous.expires)>=Net.now()+time: return true
	if not entries.has(key) and entries.size() >= MAX_EFFECTS: return false
	entries[key] = {key=key,id=id,amount=value,expires=Net.now()+time,duration=time,source=source}
	_notify()
	return true

func remove(id: String, source := "") -> void:
	id = canonical(id)
	var dirty := false
	for key in entries.keys():
		if entries[key].id == id and (source == "" or entries[key].source == source):
			entries.erase(key)
			dirty = true
	if dirty:
		if id == "burning": _burn_elapsed = 0.0
		_notify()

func clear() -> void:
	_burn_elapsed = 0.0
	if entries.is_empty(): return
	entries.clear()
	_notify()

## Called only by authoritative combat, before expired entries are removed.
## Integrate the last fraction of an expiring fire, and keep its cadence when
## new projectiles refresh it. Damage never stacks with the number of sources.
func burning_damage(delta: float) -> int:
	var until := 0.0
	for e: Dictionary in entries.values():
		if e.id == "burning": until = maxf(until,float(e.expires))
	var covered := clampf(until-(Net.now()-delta),0.0,delta)
	if burning_immune or covered<=0.0:
		_burn_elapsed = 0.0
		return 0
	_burn_elapsed += covered
	var damage := 0
	while _burn_elapsed>=1.0-0.00001:
		_burn_elapsed = maxf(0.0,_burn_elapsed-1.0)
		damage += randi_range(Burning.MIN_DAMAGE,Burning.MAX_DAMAGE)
	return damage

func tick() -> void:
	var dirty := false
	for key in entries.keys():
		if float(entries[key].expires) <= Net.now():
			entries.erase(key)
			dirty = true
	if dirty: _notify()

func active() -> Array:
	return entries.values().filter(func(e: Dictionary) -> bool: return float(e.expires)>Net.now())

func has_effect(id: String) -> bool:
	id = canonical(id)
	for e: Dictionary in entries.values():
		if e.id == id and float(e.expires)>Net.now(): return true
	return false

## How many separate doses of `id` are active (drinks stack this way).
func count(id: String) -> int:
	id = canonical(id)
	var n := 0
	for e: Dictionary in entries.values():
		if e.id == id and float(e.expires)>Net.now(): n += 1
	return n

func additive(id: String, unbuffed: float) -> float:
	var value := 0.0
	for e: Dictionary in entries.values():
		if e.id != id or float(e.expires)<=Net.now(): continue
		if e.amount is String: value += -unbuffed if e.amount == "-max" else unbuffed
		else: value += float(e.amount)
	return value

func multiplier(id: String) -> float:
	var value := 1.0
	for e: Dictionary in entries.values():
		if e.id == id and float(e.expires)>Net.now(): value *= float(e.amount)
	return value

func probability(id: String) -> float:
	return clampf(additive(id,0.0),0.0,1.0 if id == "loot_tier" else 10.0)

func wire() -> Array:
	var out: Array = []
	for e: Dictionary in active():
		out.append([e.key,e.id,e.amount,maxf(0.0,float(e.expires)-Net.now()),e.duration,e.source])
	return out

func replace_wire(data: Array, age := 0.0) -> void:
	entries.clear()
	for row: Array in data.slice(0,MAX_EFFECTS):
		if row.size()<6 or not str(row[1]) in IDS: continue
		if burning_immune and str(row[1]) == "burning": continue
		var left := maxf(0.0,float(row[3])-maxf(0.0,age))
		if left<=0.0: continue
		entries[str(row[0])] = {key=str(row[0]),id=str(row[1]),amount=row[2],expires=Net.now()+left,duration=float(row[4]),source=str(row[5])}
	_notify()

func _notify() -> void:
	revision += 1
	changed.emit()

static func harmful(e: Dictionary) -> bool:
	if e.id in ["static", "quiet", "burning", "armour_broken"]: return true
	if e.amount is String: return e.amount == "-max"
	return float(e.amount) < (1.0 if e.id in ["regeneration", "mana_regeneration"] else 0.0)

static func banner(e: Dictionary) -> String:
	if e.id == "invincible": return "yellow"
	if e.id == "immune": return "blue"
	if e.id in ["static","quiet"]: return "blue"
	if e.id == "armour_broken": return "purple"
	if e.id == "burning": return "red"
	if e.id in ["loot_chance","loot_tier"]: return "yellow"
	if e.id == "drunk": return "purple"
	var negative: bool = str(e.amount) == "-max"
	if not e.amount is String:
		negative = float(e.amount)<(1.0 if e.id in ["regeneration","mana_regeneration"] else 0.0)
	return "red" if negative else "green"

static func icon(id: String) -> String:
	return {hp="health",mp="magic_points",defense="defence",mana_regeneration="magic_points",immune="magic",invincible="defence"}.get(id,id)

static func time_text(left: float) -> String:
	if left>=3600: return "%dh" % ceili(left/3600.0)
	if left>=60: return "%dm" % ceili(left/60.0)
	return "%ds" % maxi(1,ceili(left))

static func description(e: Dictionary) -> String:
	if e.id == "burning": return "Burning: 10-15 HP/s, ignores armour. Water extinguishes it."
	if e.id == "drunk": return "Drunk: the world sways a little. Every drink adds to it."
	var amount := str(e.amount)
	if not e.amount is String:
		if e.id in ["loot_chance","loot_tier"]: amount = "+%s%%" % String.num(float(e.amount)*100.0,1)
		elif e.id in ["regeneration","mana_regeneration"]: amount = "%s%%" % String.num(float(e.amount)*100.0,1)
		elif e.id in ["static","quiet","armour_broken","immune","invincible","drunk"]: amount = ""
		else: amount = "%+d" % int(e.amount)
	return (str(NAMES.get(e.id,e.id))+" "+amount).strip_edges()
