extends Node
## Your Void Realms account on this computer (autoloaded as Account). You
## can be logged into several accounts and switch between them; one is the
## current one. Nothing can be played without it: Singleplayer and every
## server load the account's characters from the account service.
##
## Keeps the current account's characters, its level and XP (the account
## earns all the XP its characters earn, and part of what a fallen character
## earned and carried), the reward track, and which character you play.

signal changed
signal friends_changed
## Dots (the account currency) changed: the new total and how many just
## came in (0 = only a refresh), and from where ("forge", "campaign", ...).
signal dots_changed(total: int, gained: int, source: String)
## A request failed or was refused (message for the player).
signal problem(message: String)

const PROFILE := "user://online.cfg"
const DEFAULT_URL := "https://void.plainshow.se"

var api := AccountApi.new()
var profile := ConfigFile.new()
## /me: {account, progress, characters, max_characters, rewards, max_level, classes}
var data := {}
var friend_list: Array = []
var friend_requests: Array = []
var party_invites: Array = []
var social_error := ""
var _social_timer := 0.0
var _social_fetching := false
var busy := false


func _ready() -> void:
	add_child(api)
	profile.load(PROFILE)
	_launcher_session()
	api.base_url = url()
	api.token = token()


func _process(delta: float) -> void:
	_social_timer -= delta
	if _social_timer <= 0.0 and is_logged_in() and not _social_fetching:
		_social_timer = 4.0
		friends(true)


func url() -> String:
	return str(profile.get_value("account", "url", DEFAULT_URL))


func set_url(value: String) -> void:
	profile.set_value("account", "url", value.strip_edges().trim_suffix("/"))
	api.base_url = url()
	_set_friends([])
	_save()


## Saved logins: username -> token.
func saved() -> Dictionary:
	return profile.get_value("account", "saved", {})


func username() -> String:
	return str(profile.get_value("account", "username", ""))


func token() -> String:
	return str(saved().get(username(), ""))


func is_logged_in() -> bool:
	return token() != "" and not data.is_empty()


func progress() -> Dictionary:
	return data.get("progress", {xp = 0, level = 1, into = 0, needed = AccountLevels.xp_to_next(1), slots = 2})


func characters() -> Array:
	return data.get("characters", [])


func slots() -> int:
	return int(data.get("max_characters", progress().get("slots", 2)))


func rewards() -> Array:
	return data.get("rewards", [])


## The character you play (its summary from the account service), or {}.
func character() -> Dictionary:
	var chosen := int(profile.get_value("characters", username(), 0))
	for c: Dictionary in characters():
		if int(c.id) == chosen:
			return c
	return characters()[0] if not characters().is_empty() else {}


func character_id() -> int:
	return int(character().get("id", 0))


func choose(character_id_value: int) -> void:
	profile.set_value("characters", username(), character_id_value)
	_save()
	changed.emit()


## Loads the current account (at start, after switching). False if the saved
## login no longer works (then you're logged out of it).
func refresh() -> bool:
	if token() == "":
		data = {}
		_set_friends([])
		changed.emit()
		return false
	api.token = token()
	var r := await api.call_api("GET", "/me")
	if not r.ok:
		if r.status == 401:
			_forget(username())
		data = {}
		_set_friends([])
		changed.emit()
		if r.status != 401:
			problem.emit(r.error)
		return false
	var refreshed: Dictionary = r.data
	var fetched_progress: Dictionary = refreshed.get("progress", {})
	var total_xp := maxi(int(progress().get("xp", 0)), int(fetched_progress.get("xp", 0)))
	var current_progress := AccountLevels.progress(total_xp)
	current_progress.slots = fetched_progress.get("slots", 2)
	refreshed.progress = current_progress
	data = refreshed
	changed.emit()
	return true


func login(user: String, password: String) -> Dictionary:
	busy = true
	api.token = ""
	var r := await api.call_api("POST", "/login", {username = user.strip_edges(), password = password})
	busy = false
	if not r.ok:
		api.token = token()
		return r
	var logins := saved()
	logins[str(r.data.account.username)] = str(r.data.token)
	profile.set_value("account", "saved", logins)
	profile.set_value("account", "username", str(r.data.account.username))
	_save()
	api.token = str(r.data.token)
	data = r.data
	data.erase("token")
	_set_friends([])
	changed.emit()
	return r


## Switches to another saved login.
func switch_to(user: String) -> bool:
	if not saved().has(user):
		return false
	profile.set_value("account", "username", user)
	_set_friends([])
	_save()
	return await refresh()


func logout() -> void:
	if token() != "":
		api.call_api("POST", "/logout")
	_forget(username())
	var left := saved().keys()
	profile.set_value("account", "username", left[0] if not left.is_empty() else "")
	_save()
	data = {}
	_set_friends([])
	if not left.is_empty():
		await refresh()
	else:
		changed.emit()


## The launcher hands over its signed-in account as "username<TAB>token" in
## VOID_LAUNCHER_SESSION (an environment variable, so it stays out of the
## process list). It becomes the current saved login.
func _launcher_session() -> void:
	var parts := OS.get_environment("VOID_LAUNCHER_SESSION").split("\t")
	if parts.size() != 2 or parts[0] == "" or parts[1] == "":
		return
	var logins := saved()
	logins[parts[0]] = parts[1]
	profile.set_value("account", "saved", logins)
	profile.set_value("account", "username", parts[0])
	_save()


func _forget(user: String) -> void:
	var logins := saved()
	logins.erase(user)
	profile.set_value("account", "saved", logins)
	_save()


## Makes a character of `class_id` and plays it. Returns the request result.
func create_character(class_id: String) -> Dictionary:
	var r := await api.call_api("POST", "/characters", {"class": class_id})
	if r.ok:
		data = r.data
		choose(int(r.data.id))
	else:
		problem.emit(r.error)
	return r


func delete_character(id: int) -> Dictionary:
	var r := await api.call_api("POST", "/characters/delete", {id = id})
	if r.ok:
		data = r.data
		changed.emit()
	else:
		problem.emit(r.error)
	return r


## Fallen characters, newest first, each with everything it had.
func graveyard() -> Array:
	var r := await api.call_api("GET", "/graveyard")
	return r.data.get("dead", []) if r.ok else []


func delete_dead(id: int) -> bool:
	var r := await api.call_api("POST", "/graveyard/delete", {id = id})
	if not r.ok:
		problem.emit(r.error)
	return r.ok


## Accepted friends, pending requests and party invitations, also in Singleplayer.
func friends(quiet := false) -> Array:
	if _social_fetching or not is_logged_in():
		return friend_list
	_social_fetching = true
	var session := token()
	var service := url()
	var r := await api.call_api("GET", "/friends")
	_social_fetching = false
	if token() != session or url() != service:
		return []
	if not r.ok:
		if social_error != str(r.error):
			social_error = str(r.error)
			friends_changed.emit()
		if not quiet:
			problem.emit(r.error)
		return friend_list
	var entries: Array = r.data.get("friends", [])
	var requests: Array = r.data.get("requests", [])
	var invitations: Array = r.data.get("party_invites", [])
	var different := friend_list != entries or friend_requests != requests or party_invites != invitations or social_error != ""
	friend_list = entries
	friend_requests = requests
	party_invites = invitations
	social_error = ""
	if different:
		friends_changed.emit()
	return friend_list


func add_friend(user: String) -> Dictionary:
	var r := await _social_action("/friends/add", {username = user.strip_edges()})
	return r.data.get("friend", {}) if r.ok else {}


func respond_friend(user: String, accept: bool) -> void:
	await _social_action("/friends/respond", {username = user, accept = accept})


func remove_friend(user: String) -> bool:
	var r := await _social_action("/friends/remove", {username = user.strip_edges()})
	return r.ok


func join_friend(user: String) -> Dictionary:
	var r := await _social_action("/friends/join", {username = user})
	return r.data if r.ok else {}


func respond_party(id: int, accept: bool) -> Dictionary:
	var r := await _social_action("/party/respond", {id = id, accept = accept})
	return r.data if r.ok else {}


func _social_action(path: String, body: Dictionary) -> Dictionary:
	var session := token()
	var service := url()
	var r := await api.call_api("POST", path, body)
	if token() != session or url() != service:
		return {ok = false, data = {}, error = "Account changed."}
	if not r.ok:
		problem.emit(r.error)
	else:
		_social_timer = 0.0
		await friends(true)
	if token() != session or url() != service:
		return {ok = false, data = {}, error = "Account changed."}
	return r


## The previous game server must finish saving before a social transfer claims again.
func wait_for_release(character_id_value: int, session: String) -> bool:
	var service := url()
	var until := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < until and token() == session and url() == service:
		var r := await api.call_api("GET", "/me")
		if token() != session or url() != service:
			return false
		if r.ok:
			for entry: Dictionary in r.data.get("characters", []):
				if int(entry.id) == character_id_value and not entry.get("online", false):
					return true
		await get_tree().create_timer(0.5).timeout
	return false


func search_players(query: String) -> Array:
	var session := token()
	var service := url()
	var r := await api.call_api("GET", "/players/search?q=" + query.strip_edges().uri_encode())
	if token() != session or url() != service:
		return []
	if not r.ok:
		problem.emit(r.error)
		return []
	return r.data.get("players", [])


func is_friend(user: String) -> bool:
	for entry: Dictionary in friend_list:
		if str(entry.username).nocasecmp_to(user.strip_edges()) == 0:
			return true
	return false


func _set_friends(entries: Array) -> void:
	friend_list = entries
	friend_requests = []
	party_invites = []
	social_error = ""
	_social_timer = 0.0
	friends_changed.emit()


## A key for running your own Singleplayer server ("" if refused).
func singleplayer_key() -> String:
	var r := await api.call_api("POST", "/singleplayer")
	if not r.ok:
		problem.emit(r.error)
		return ""
	return str(r.data.key)


## Live updates while playing (the server streams the account's XP).
func set_total_xp(total: int) -> void:
	if data.is_empty():
		return
	var p := AccountLevels.progress(maxi(total, int(progress().get("xp", 0))))
	p.slots = progress().get("slots", 2)
	var before := int(progress().get("level", 1))
	data.progress = p
	changed.emit()
	if p.level > before:
		refresh()  # new rewards (slots) come from the service


func dots() -> int:
	return int(data.get("account", {}).get("dots", 0))


func is_developer() -> bool:
	return bool(data.get("account", {}).get("developer", false))


## Live updates while playing (the server sends the account's Dots).
func set_dots(total: int, gained := 0, source := "") -> void:
	if data.is_empty():
		return
	if not data.has("account"):
		data.account = {}
	data.account.dots = total
	dots_changed.emit(total, gained, source)


func _save() -> void:
	profile.save(PROFILE)
