extends Node

const PORT := 9090
const HOST_NAME := "solhost"
const HOST_PASS := "SolHost-0623"

var role := ""
var ping_ms := 0
var roster: Array = []
var match_mode := "normal"
var owners := {}
var host_token := ""
var host_id := ""
var started := false
var live := false
var match_id := ""
var _ping_sent := 0
var joining := false
var _closing := false
var alone := 0.0
var notice := ""

signal session_ready
signal session_failed

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_connection_failed)

func serving() -> bool:
	return role == "server"

func remote_client() -> bool:
	return role == "client"

func begin_server() -> void:
	role = "server"
	if live:
		started = false
		return
	live = true
	var logged := _host_login()
	print("SERVER LOGIN ", logged)
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(PORT, "127.0.0.1")
	if err != OK:
		err = peer.create_server(PORT)
	if err != OK:
		print("SERVER BIND FAIL ", err)
		return
	multiplayer.multiplayer_peer = peer
	print("SERVER ", _public_host())
	_beat()
	var beat := Timer.new()
	beat.wait_time = 5.0
	beat.timeout.connect(_beat)
	beat.autostart = true
	add_child(beat)
	var claim := Timer.new()
	claim.wait_time = 2.0
	claim.timeout.connect(_claim)
	claim.autostart = true
	add_child(claim)

func connect_match(host: String, port: int) -> String:
	abort_join()
	joining = true
	role = ""
	var url := host.strip_edges()
	if url.begins_with("https://"):
		url = "wss://" + url.substr(8)
	elif url.begins_with("http://"):
		url = "ws://" + url.substr(7)
	elif not url.begins_with("ws"):
		url = "ws://%s:%d" % [host, port]
	if url == "" or url == "ws://:0":
		joining = false
		return "서버에 연결하지 못했습니다."
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		joining = false
		return "서버에 연결하지 못했습니다."
	multiplayer.multiplayer_peer = peer
	print("CLIENT ", url)
	return ""

func abort_join() -> void:
	if role == "server":
		return
	joining = false
	role = ""
	_closing = true
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null
	_closing = false

func legend_choice(_username: String) -> String:
	return ""

func party(op: String, extra: Dictionary = {}) -> Dictionary:
	extra["op"] = op
	if not StrifeAcc.logged_in():
		return {"error": "먼저 로그인하세요."}
	return StrifeAcc.function_call("strife-party", extra)

func cmd(payload: Dictionary) -> void:
	if role != "client":
		return
	client_cmd.rpc_id(1, payload)

func say_text(text: String, team_only: bool) -> void:
	if role != "client":
		return
	talk.rpc_id(1, text.substr(0, 80), team_only)

func mark(kind: String, x: float, z: float) -> void:
	if role != "client":
		return
	place_mark.rpc_id(1, kind, x, z)

func push_state(rows: Array) -> void:
	if role != "server":
		return
	if multiplayer.get_peers().is_empty():
		return
	world_state.rpc(rows)

func _on_connected() -> void:
	if role == "server":
		return
	joining = false
	role = "client"
	if StrifeAcc.access != "":
		hello.rpc_id(1, StrifeAcc.access)
	_ping_sent = Time.get_ticks_msec()
	ping.rpc_id(1, _ping_sent)
	session_ready.emit()

func _on_connection_failed() -> void:
	if _closing or role == "server":
		return
	var waiting := joining or role == "client"
	joining = false
	role = ""
	_closing = true
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null
	_closing = false
	if waiting:
		session_failed.emit()

func _process(delta: float) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is WebSocketMultiplayerPeer:
		peer.poll()
	if role == "server":
		if started and multiplayer.get_peers().is_empty():
			alone += delta
			if alone >= 20.0:
				alone = 0.0
				finish_match()
		else:
			alone = 0.0
		return
	if role != "client":
		return
	if Time.get_ticks_msec() - _ping_sent < 1000:
		return
	_ping_sent = Time.get_ticks_msec()
	if multiplayer.multiplayer_peer != null:
		ping.rpc_id(1, _ping_sent)

func _match():
	return get_tree().get_first_node_in_group("match")

@rpc("any_peer", "reliable")
func hello(token: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var user := _user_from_token(token)
	if user.is_empty():
		return
	owners[peer] = user
	var game = _match()
	if game:
		game.bind_remote(peer, str(user.get("username", "")))

@rpc("any_peer", "reliable")
func client_cmd(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var game = _match()
	if game:
		game.apply_remote(peer, payload)

@rpc("authority", "unreliable")
func world_state(rows: Array) -> void:
	var game = _match()
	if game:
		game.apply_net_state(rows)

@rpc("any_peer", "reliable")
func talk(text: String, team_only: bool) -> void:
	if not multiplayer.is_server():
		return
	var clean := text.strip_edges().substr(0, 80)
	if clean == "":
		return
	var peer := multiplayer.get_remote_sender_id()
	var user: Dictionary = owners.get(peer, {})
	var username := str(user.get("username", "소환사"))
	var team := ""
	if team_only:
		var game = _match()
		if game:
			team = str(game.team_of(username))
	hear.rpc(username, clean, team)

@rpc("authority", "reliable")
func hear(username: String, text: String, team: String) -> void:
	var game = _match()
	if game:
		game.show_chat(username, text, team)

@rpc("any_peer", "reliable")
func place_mark(kind: String, x: float, z: float) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var user: Dictionary = owners.get(peer, {})
	var username := str(user.get("username", "소환사"))
	show_mark.rpc(username, kind, x, z)

@rpc("authority", "reliable")
func show_mark(username: String, kind: String, x: float, z: float) -> void:
	var game = _match()
	if game:
		game.show_mark(username, kind, x, z)

@rpc("authority", "reliable")
func match_over() -> void:
	if role != "client":
		return
	role = ""
	get_tree().change_scene_to_file("res://main.tscn")

func finish_match() -> void:
	if role != "server":
		return
	if match_id != "" and host_token != "":
		_patch("/rest/v1/matches?id=eq.%s" % match_id, {"status": "done"}, host_token)
	match_id = ""
	started = false
	if not multiplayer.get_peers().is_empty():
		match_over.rpc()
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")

@rpc("any_peer", "unreliable")
func ping(sent: int) -> void:
	if not multiplayer.is_server():
		return
	pong.rpc_id(multiplayer.get_remote_sender_id(), sent)

@rpc("authority", "unreliable")
func pong(sent: int) -> void:
	ping_ms = maxi(0, Time.get_ticks_msec() - sent)

func _public_host() -> String:
	var pub := OS.get_environment("SOL_PUBLIC_URL").strip_edges()
	if pub != "":
		return pub
	return "ws://%s:%d" % [_lan(), PORT]

func _stamp() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"

func _lan() -> String:
	for raw in IP.get_local_addresses():
		var ip := str(raw)
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"

func _host_login() -> String:
	var res := _post("/functions/v1/strife-acc", {"op": "login", "username": HOST_NAME, "password": HOST_PASS}, "")
	if int(res.get("_code", 0)) >= 300:
		res = _post("/functions/v1/strife-acc", {"op": "register", "username": HOST_NAME, "password": HOST_PASS}, "")
	if int(res.get("_code", 0)) >= 300:
		return str(res.get("_err", "host login"))
	host_token = str(res.get("access_token", ""))
	host_id = str(res.get("user_id", ""))
	return ""

func _beat() -> void:
	if host_token == "" or host_id == "":
		_host_login()
	if host_token == "":
		return
	_post("/rest/v1/game_servers?on_conflict=owner_id", {
		"owner_id": host_id,
		"host": _public_host(),
		"port": 443,
		"heartbeat": _stamp(),
	}, host_token, true)

func _claim() -> void:
	if started or host_token == "":
		return
	var rows := _fetch("/rest/v1/matches?status=eq.open&select=id,mode,roster,host,port&order=created_at.asc&limit=1", host_token)
	var list = rows.get("_list", [])
	if not (list is Array) or list.is_empty():
		return
	var row: Dictionary = list[0]
	var id := str(row.get("id", ""))
	var patched := _patch("/rest/v1/matches?id=eq.%s" % id, {"status": "running"}, host_token)
	if int(patched.get("_code", 0)) >= 300:
		return
	match_id = id
	match_mode = str(row.get("mode", "normal"))
	roster = row.get("roster", [])
	if not (roster is Array):
		roster = []
	started = true
	Draft.install_roster(match_mode, roster)
	get_tree().change_scene_to_file("res://match.tscn")

func _user_from_token(token: String) -> Dictionary:
	var res := _fetch("/auth/v1/user", token)
	if int(res.get("_code", 0)) >= 300:
		return {}
	var uid := str(res.get("id", ""))
	var prof := _fetch("/rest/v1/profiles?id=eq.%s&select=id,username" % uid, token)
	var list = prof.get("_list", [])
	if list is Array and not list.is_empty():
		return list[0]
	return {}

func _post(path: String, body: Dictionary, token: String, upsert := false) -> Dictionary:
	return _send(HTTPClient.METHOD_POST, path, JSON.stringify(body), token, upsert)

func _patch(path: String, body: Dictionary, token: String) -> Dictionary:
	return _send(HTTPClient.METHOD_PATCH, path, JSON.stringify(body), token, false)

func _fetch(path: String, token: String) -> Dictionary:
	return _send(HTTPClient.METHOD_GET, path, "", token, false)

func _send(method: int, path: String, payload: String, token: String, upsert: bool) -> Dictionary:
	var client := HTTPClient.new()
	if client.connect_to_host(StrifeAcc.HOST, 443, TLSOptions.client()) != OK:
		return {"_code": 0, "_err": "서버에 연결하지 못했습니다."}
	var started := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		if Time.get_ticks_msec() - started > 8000:
			return {"_code": 0, "_err": "서버 응답이 없습니다."}
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"_code": 0, "_err": "서버에 연결하지 못했습니다."}
	var headers := PackedStringArray([
		"apikey: " + StrifeAcc.KEY,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	if upsert:
		headers.append("Prefer: resolution=merge-duplicates,return=minimal")
	if client.request(method, path, headers, payload) != OK:
		return {"_code": 0, "_err": "요청을 보내지 못했습니다."}
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() - started > 8000:
			return {"_code": 0, "_err": "서버 응답이 없습니다."}
		OS.delay_msec(10)
	if not client.has_response():
		return {"_code": 0, "_err": "서버 응답이 없습니다."}
	var code := client.get_response_code()
	var raw := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			if Time.get_ticks_msec() - started > 8000:
				break
			OS.delay_msec(10)
		else:
			raw.append_array(chunk)
	client.close()
	var text := raw.get_string_from_utf8().strip_edges()
	var parsed = JSON.parse_string(text) if text != "" else null
	var out := {"_code": code}
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = parsed
		for key in data.keys():
			out[str(key)] = data[key]
	elif typeof(parsed) == TYPE_ARRAY:
		out["_list"] = parsed
	if code < 200 or code >= 300:
		out["_err"] = str(out.get("error", out.get("message", "요청이 거절되었습니다.")))
	return out
