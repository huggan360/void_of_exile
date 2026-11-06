class_name Item
extends Resource
## A piece of gear. Slots: "weapon" (bows), "armor" (cloaks), "spell" (warp
## magic) and "bonus". Tier 1-8 are graded items (G1...G8); tier 0 means
## Divine: special, untiered items with their own abilities.
## Consumables (slot "consumable", e.g. elixirs) stack up to stack_max and
## can sit in the quickslots.
##
## Loot: every item drops in a bag of a certain color (bag_type()); items
## from personal bags (blue and up) are soulbound to whoever got them.
##
## Icons come from items/textures/<id>.png (drawn in Pixelorama, imported by
## tools/import_textures.py).

const DIVINE := 0

@export var id := ""  # icon file name, e.g. "G3_bow"
@export var item_name := ""
@export var slot := "weapon"
@export var kind := ""  # shown under the name, e.g. "Bow"
@export var tier := 1
@export_multiline var lore := ""
## Stat bonuses: speed, attack, dexterity, defense, magic, plus hp / mp (max
## health / magic points).
@export var bonuses := {}
## Lines describing special abilities, shown in the tooltip.
@export var abilities: PackedStringArray = []
## Special effects the player picks up while this is equipped, e.g.
## {lifesteal = 1, mp_regen = 1.5, shield_drain = 0.7,
##  shield_heal = 3.0, trail = "embers"}.
@export var effects := {}
## Consumables: what using one does, e.g. {hp = 100}, {mp = 100} or
## {backpack = true} (two more backpack rows).
@export var consumable := {}
@export var stack_max := 1
## Keys (slot "key"): the stronghold whose sealed gates it opens, once.
@export var opens := ""
## The bag it drops in, when not the usual one for its kind (see bag_type()):
## "blue" for permanent stat potions, "green" for the backpack.
@export var drop_bag := ""
## How many are in this stack (consumables).
var count := 1

@export_group("Weapon")
## Base damage range before Attack. Each shot receives its explicit share.
@export var damage_min := 0
@export var damage_max := 0
@export var shots := 1
@export var projectile_shares: Array[float] = []
## On-hit enemy effects, separate for primary and charged attacks.
@export var primary_effects: Array[Dictionary] = []
@export var secondary_effects: Array[Dictionary] = []
@export var spread_deg := 0.0  # angle between neighboring shots
@export var fire_rate := 1.0  # x shots per second
## How the projectile looks and flies: style ("arrow", "bolt", "orb"),
## color, color2, glow, trail, speed, range, size, wave_amp, wave_freq, pierce.
@export var projectile := {}

## Shared by local shots, remote allies and the item tooltip. Enemy attacks
## have their own definitions and do not use this multiplier.
const PLAYER_PROJECTILE_RANGE_MULTIPLIER := 0.6

## Seconds the archer draws the string before each shot (slow, heavy bows).
@export var windup := 0.0
## Right-click charged shot (G3+ and Divine bows). Empty = none.
## {style, mult, ...}: "power" (one big fast shot), "volley" (count, spread),
## "helix" (two big weaving shots), "serpent_fan" (piercing fan: count, spread),
## "burst" (count, interval),
## "singularity" (piercing arrow that collapses into a warp ring),
## "inferno" (fire bolt that bursts into flames on impact).
@export var charge := {}

@export_group("Spell")
@export var shield_tint := Color(0.65, 0.8, 1.0)
@export var shield_arcs := Color(0.85, 0.92, 1.0)
@export var shield_rainbow := 0.55  # how much the arcs shift through rainbow colors
@export var warp := 0.05  # how strongly it bends the world behind it
## Warped ring cast with a double tap of Space (tier 4+ and Divine spells):
## {damage, range, speed, cost, pulses, heal}. Empty = no ring.
@export var ring := {}

@export_group("Aura")
## Voxel particles drifting around the character while equipped.
@export var aura_color := Color(0, 0, 0, 0)
@export var aura_power := 0.0

var _icon: Texture2D
var _icon_variant := -1
var _silhouette: Texture2D
var _outline: Texture2D
var _glow: Texture2D
const OUTLINE_CORE_SIZE := 40.0
const OUTLINE_SAMPLES := 3
static var _outline_cache := {}  # source texture -> shared smooth mask across inventory snapshots


func projectile_range() -> float:
	return float(projectile.get("range", 22.0)) * PLAYER_PROJECTILE_RANGE_MULTIPLIER


func shot_share(index: int, count := -1) -> float:
	if count < 0: count = shots
	if count == shots and projectile_shares.size() == shots:
		return projectile_shares[clampi(index, 0, shots - 1)]
	if count == 1: return 1.0
	if count == 2: return 0.5
	return 0.7 if index == count / 2 else 0.8 / float(count - 1)


func attack_effects(secondary := false) -> Array[Dictionary]:
	return Burning.with_effect(secondary_effects if secondary else primary_effects, Burning.weapon_duration(self,secondary))

const ICON_SIZE := 8


func is_divine() -> bool:
	return tier == DIVINE


## Only the Archer is playable in this pass. Other gear is collectible for future classes.
func usable_by(class_id: String) -> bool:
	return PlayerClasses.allows(class_id, self)


func is_weapon() -> bool:
	return damage_max > 0


func is_key() -> bool:
	return slot == "key"


## Story items (campaigns): carried, read, handed over; never dropped or sold.
func is_story() -> bool:
	return slot == "story"


func is_consumable() -> bool:
	return not consumable.is_empty()


## Elixirs: they only ever go in gray bags.
func is_elixir() -> bool:
	return consumable.has("hp") or consumable.has("mp")


## The bag it drops in: gray (elixirs), green (G1-G4), red (G5),
## purple (G6-G8); blue is reserved for stat potions, white or black (Divine). See LootBag.
func bag_type() -> String:
	if drop_bag != "":
		return drop_bag
	if is_consumable():
		return "gray"
	if is_divine():
		return "white"
	return ["green", "green", "green", "green", "red", "purple", "purple", "purple"][clampi(tier - 1, 0, 7)]


## Bound to its owner: can't be traded or put in bags others can see.
func soulbound() -> bool:
	return LootBag.is_personal(bag_type())


## "G3", "D" for Divine, nothing for consumables and keys.
func badge() -> String:
	if is_consumable() or is_key() or is_story():
		return ""
	return "D" if is_divine() else "G%d" % tier


func grade_name() -> String:
	if is_consumable():
		return "Consumable"
	if is_key():
		return "Key"
	if is_story():
		return "Story item"
	return "Divine" if is_divine() else "Grade %d" % tier


## The item's 8 x 8 pixel art.
func icon() -> Texture2D:
	if id == "story_clue":  # retain the texture used by CanvasItem draw commands
		var variant := clampi(count, 1, 6)
		if _icon == null or _icon_variant != variant:
			_icon = load("res://items/textures/story_clue_%d.png" % variant)
			_icon_variant = variant
			_silhouette = null
			_outline = null
			_glow = null
		return _icon
	if _icon == null:
		_icon = load("res://items/textures/%s.png" % id)
	return _icon


## The icon's shape in plain white. Slots draw it a screen pixel off in each
## direction behind the icon, giving a hairline outline (a fraction of an
## art pixel).
func silhouette() -> Texture2D:
	var source := icon()  # may invalidate the shape when map pieces change
	if _silhouette == null:
		var img: Image = source.get_image().duplicate()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var a := img.get_pixel(x, y).a
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if a > 0.1 else 0.0))
		_silhouette = ImageTexture.create_from_image(img)
	return _silhouette

## A three-times oversampled one-pixel outline for a 40-pixel icon. Native
## image blits build the dilation; mipmaps keep it stable when the UI shrinks.
## Draw behind a nearest-filtered icon so smoothing never blurs the item art.
func outline_mask() -> Texture2D:
	var source := icon()
	if _outline_cache.has(source):
		_outline = _outline_cache[source]
		return _outline
	if _outline == null:
		var core := int(OUTLINE_CORE_SIZE)*OUTLINE_SAMPLES
		var src: Image = silhouette().get_image().duplicate()
		src.resize(core,core,Image.INTERPOLATE_NEAREST)
		var image := Image.create_empty(core+OUTLINE_SAMPLES*2,core+OUTLINE_SAMPLES*2,false,Image.FORMAT_RGBA8)
		for dy in range(-OUTLINE_SAMPLES,OUTLINE_SAMPLES+1):
			for dx in range(-OUTLINE_SAMPLES,OUTLINE_SAMPLES+1):
				if dx*dx+dy*dy>OUTLINE_SAMPLES*OUTLINE_SAMPLES: continue
				image.blend_rect(src,Rect2i(0,0,core,core),Vector2i(OUTLINE_SAMPLES+dx,OUTLINE_SAMPLES+dy))
		image.generate_mipmaps()
		_outline = ImageTexture.create_from_image(image)
		_outline_cache[source] = _outline
	return _outline


## A soft silhouette one art pixel bigger all round (10 x 10), drawn tinted
## and shimmering behind Divine items.
func glow_mask() -> Texture2D:
	icon()  # keep masks in step with a changing map-shard stack
	if _glow == null:
		var src: Image = silhouette().get_image()
		var img := Image.create_empty(ICON_SIZE + 2, ICON_SIZE + 2, false, Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var best := 0.0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var p := Vector2i(x - 1 + dx, y - 1 + dy)
						if p.x < 0 or p.y < 0 or p.x >= ICON_SIZE or p.y >= ICON_SIZE or src.get_pixelv(p).a < 0.1:
							continue
						best = maxf(best, 1.0 if absi(dx) + absi(dy) <= 1 else 0.5)
				if best > 0.0:
					img.set_pixel(x, y, Color(1, 1, 1, best))
		_glow = ImageTexture.create_from_image(img)
	return _glow
