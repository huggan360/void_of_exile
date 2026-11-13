class_name AccountApi
extends Node
## Talks to the account service (void_of_exile_account repo, server/void_accounts.py, running
## at void.plainshow.se): JSON over HTTPS. The game client logs in and lists
## characters and servers with it; the dedicated server loads, saves and
## buries characters with its server key.
##
##     var r := await api.call_api("POST", "/login", {username = "p1", password = "..."})
##     if r.ok: ...r.data...  else: ...r.error...

const TIMEOUT := 10.0
const BUSY_RETRIES := 2

## e.g. "https://void.plainshow.se"
var base_url := ""
## Client: the login token (sent as a Bearer token).
var token := ""
## Server: its key (sent as X-Server-Key).
var server_key := ""


## Returns {ok: bool, status: int, data: Dictionary, error: String}.
## A busy account service (503 busy: its database was locked and nothing was
## kept) is asked again a couple of times before giving up.
func call_api(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	var r := await _call_once(method, path, body)
	for attempt in BUSY_RETRIES:
		if r.status != 503 or not r.data.get("busy", false) or not is_inside_tree():
			break
		await get_tree().create_timer(1.0 + attempt).timeout
		r = await _call_once(method, path, body)
	return r


func _call_once(method: String, path: String, body: Dictionary) -> Dictionary:
	if base_url == "":
		return {ok = false, status = 0, data = {}, error = "No account server is set."}
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json",
			"User-Agent: VoidRealms/%s" % Net.VERSION])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	if server_key != "":
		headers.append("X-Server-Key: " + server_key)
	var url := base_url.trim_suffix("/") + "/api" + path
	var err := http.request(url, headers, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET,
			JSON.stringify(body) if method == "POST" else "")
	if err != OK:
		http.queue_free()
		return {ok = false, status = 0, data = {}, error = "Couldn't reach the account server (%s)." % error_string(err)}
	var result: Array = await http.request_completed
	http.queue_free()
	var status: int = result[1]
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {ok = false, status = 0, data = {}, error = "Couldn't reach the account server."}
	if status < 200 or status >= 300:
		var fallback := "The account server had a problem (%d). Please try again." % status if status >= 500 else "Account server error %d." % status
		return {ok = false, status = status, data = data, error = str(data.get("error", fallback))}
	return {ok = true, status = status, data = data, error = ""}
