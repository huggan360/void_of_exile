class_name DialogueVoice
extends Node
## Short NPC phrases accompany revealing text. Each dialog owns its voice;
## shared scene/page events start the same phrase on every party client.

var _label: RichTextLabel
var _handle := {}
var _event := ""
var _seed := 0
var _phrase := 0
var _remaining := 0.0


func _ready() -> void:
	set_process(false)


func start(label: RichTextLabel, speaker: String, mood := "") -> void:
	stop()
	if Net.is_server() or label.get_parsed_text().strip_edges().is_empty():
		return
	_label = label
	var text := label.get_parsed_text()
	_event = "voice.minion." + (mood if not mood.is_empty() else mood_for(text))
	if not GameAudio.events.has(_event): _event = "voice.minion.curious"
	_seed = hash(speaker + ":" + text)
	_phrase = 0
	_remaining = 0.0
	set_process(true)


func stop() -> void:
	GameAudio.stop(_handle, 0.06)
	_handle = {}
	_label = null
	set_process(false)


func _process(delta: float) -> void:
	if not is_instance_valid(_label) or not _label.is_visible_in_tree() \
			or _label.visible_characters < 0 or _label.visible_characters >= _label.get_total_character_count():
		stop()
		return
	# Play whole phrases rather than retriggering on every word. Fade the
	# current phrase as soon as text finishes, is skipped, or the page closes.
	_remaining -= delta
	if _remaining > 0.0 or _label.visible_characters == 0:
		return
	_handle = GameAudio.play(_event, Vector3.INF, {
		bus = "SFX", priority = 3, fixed_pitch = true, cooldown = 0,
		source_id = get_instance_id(), variant = _seed + _phrase,
	})
	_phrase += 1
	_remaining = float(_handle.get("length", 0.4)) + 0.12


static func mood_for(text: String) -> String:
	if text.to_lower().contains("help!") or text.to_lower().contains("run!"): return "scream"
	var words := " " + text.to_lower().replace(".", " ").replace(",", " ").replace("!", " ").replace("?", " ") + " "
	for entry in [
		["scream", ["aah", "aaah", "scream"]],
		["gasp", ["gasp", "impossible"]],
		["angry", ["angry", "furious", "hate", "thief", "stole"]],
		["sad", ["sorry", "sad", "dead", "died", "miss", "lost"]],
		["cheering", ["hooray", "hurray", "victory", "congratulations"]],
		["laugh", ["haha", "hahaha", "laugh"]],
		["joking", ["joke", "joking", "kidding"]],
		["surprised", ["wow", "surprised", "unbelievable"]],
	]:
		for word: String in entry[1]:
			if words.contains(" " + word + " "): return str(entry[0])
	if text.contains("?"): return "curious"
	if text.contains("!"): return "excited"
	return "curious"


func _exit_tree() -> void:
	stop()
