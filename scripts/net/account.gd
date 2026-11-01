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
## A request failed or was refused (message for the player).
signal problem(message: String)

const PROFILE := "user://online.cfg"
const DEFAULT_URL := "https://void.plainshow.se"

var api := AccountApi.new()
var profile := ConfigFile.new()
## /me: {account, progress, characters, max_characters, rewards, max_level, classes}
var data := {}
var friend_list: Array = []
var busy := false


func _ready() -> void:
	add_child(api)
	profile.load(PROFILE)
	api.base_url = url()
	api.token = token()


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
	data = r.data
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


## One-way friends, online first. An empty list also means the request failed.
func friends() -> Array:
	var session := token()
	var r := await api.call_api("GET", "/friends")
	if not r.ok:
		problem.emit(r.error)
		return []
	var entries: Array = r.data.get("friends", [])
	if token() == session:
		_set_friends(entries)
	return entries


func add_friend(user: String) -> Dictionary:
	var session := token()
	var r := await api.call_api("POST", "/friends/add", {username = user.strip_edges()})
	if not r.ok:
		problem.emit(r.error)
		return {}
	var entry: Dictionary = r.data.get("friend", {})
	if token() == session:
		var entries := friend_list.duplicate()
		for i in range(entries.size() - 1, -1, -1):
			if str(entries[i].username).nocasecmp_to(str(entry.username)) == 0:
				entries.remove_at(i)
		entries.append(entry)
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if bool(a.online) != bool(b.online):
				return bool(a.online)
			return str(a.username).nocasecmp_to(str(b.username)) < 0)
		_set_friends(entries)
	return entry


func remove_friend(user: String) -> bool:
	var session := token()
	var r := await api.call_api("POST", "/friends/remove", {username = user.strip_edges()})
	if not r.ok:
		problem.emit(r.error)
		return false
	if token() == session:
		var entries := friend_list.duplicate()
		for i in range(entries.size() - 1, -1, -1):
			if str(entries[i].username).nocasecmp_to(user.strip_edges()) == 0:
				entries.remove_at(i)
		_set_friends(entries)
	return true


func search_players(query: String) -> Array:
	var r := await api.call_api("GET", "/players/search?q=" + query.strip_edges().uri_encode())
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
	if friend_list != entries:
		friend_list = entries
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
	var p := AccountLevels.progress(total)
	p.slots = progress().get("slots", 2)
	var before := int(progress().get("level", 1))
	data.progress = p
	changed.emit()
	if p.level > before:
		refresh()  # new rewards (slots) come from the service


func _save() -> void:
	profile.save(PROFILE)
