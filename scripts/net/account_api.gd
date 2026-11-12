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

## e.g. "https://void.plainshow.se"
var base_url := ""
## Client: the login token (sent as a Bearer token).
var token := ""
## Server: its key (sent as X-Server-Key).
var server_key := ""


## Returns {ok: bool, status: int, data: Dictionary, error: String}.
func call_api(method: String, path: String, body: Dictionary = {}) -> Dictionary:
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
		return {ok = false, status = status, data = data, error = str(data.get("error", "Account server error %d." % status))}
	return {ok = true, status = status, data = data, error = ""}
