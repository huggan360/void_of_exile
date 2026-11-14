class_name Cutscenes
## Every film in the game, by id. Films are plain dictionaries written in the
## files under scripts/cinematic/films/ (add a file to SOURCES, or a film to
## one of them); scripts/cinematic/README.md describes the format. The server
## only sends a film's id; each client looks it up here, so the films are
## shared data like Campaigns.
const SOURCES := [
	preload("res://scripts/cinematic/films/hidden_power_films.gd"),
	preload("res://scripts/cinematic/films/astral_films.gd"),
	preload("res://scripts/cinematic/films/realm_history.gd"),
]
const NUMBERS := ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]

static var _films := {}

static func all() -> Dictionary:
	if _films.is_empty():
		for source: GDScript in SOURCES:
			_films.merge(source.FILMS)
	return _films

static func has(id: String) -> bool:
	return all().has(id)

## A ready-to-play copy of a film: with its chapter card when it opens a tale.
## Takes an id or (from an older server) a film dictionary itself.
static func film(film_or_id: Variant) -> Dictionary:
	var out: Dictionary = (all().get(str(film_or_id), {}) if film_or_id is String else film_or_id).duplicate(true)
	if out.has("campaign") and not out.has("chapter"):
		out.chapter = chapter_card(str(out.campaign))
	return out

## "Chapter Three", then the tale's title over its pack's name.
static func chapter_card(campaign_id: String) -> Dictionary:
	var def := Campaigns.get_def(campaign_id)
	var pack: Dictionary = Campaigns.PACKS.get(str(def.get("pack", "")), {})
	var index: int = pack.get("campaigns", []).find(campaign_id)
	return {line = "Chapter %s" % (NUMBERS[index] if index>=0 and index<NUMBERS.size() else str(index+1)),
		title = str(def.get("title", "")), subtitle = str(pack.get("title", ""))}

## The opening film of a tale ("" when it has none).
static func intro_of(campaign_id: String) -> String:
	var intro: Variant = Campaigns.get_def(campaign_id).get("intro", "")
	return str(intro) if intro is String else ""

## Whether `film` can play in `world` now. Its `world`: "tavern", "surface",
## "space", "castle" or "any"; the client keeps it until the party is there.
static func plays_in(film: Dictionary, world: GameWorld) -> bool:
	if not is_instance_valid(world): return false
	match str(film.get("world", "any" if film.get("anywhere", false) else "tavern")):
		"tavern": return world.realm_id.begins_with("ctav_")  # the party's own Tavern
		"surface": return world is IslandWorld
		"space": return world is SpaceWorld
		"castle": return world is CastleWorld
	return true
