extends Node

const HOST := "sagrimdeoxfhvrtjllrm.supabase.co"
const KEY := "sb_publishable_yhM8PP1ZK7ToF51XKeUhdQ_5pRkE5Uc"
const SESSION := "user://session.cfg"

var username := ""
var user_id := ""
var access := ""
var refresh := ""
var account_level := 1
var account_elo := 1000
var account_ranked := 0
var account_rank := ""
var session_path := SESSION

func current() -> String:
	return username

func logged_in() -> bool:
	return username != "" and access != ""

func _ready() -> void:
	_load_session()
	if DisplayServer.get_name() == "headless":
		return
	if logged_in() and _access_expired():
		if not _refresh_session():
			logout()

func register(name: String, password: String) -> String:
	name = name.strip_edges()
	if name.length() < 3:
		return "아이디는 3글자 이상이어야 합니다."
	if password.length() < 6:
		return "비밀번호는 6글자 이상이어야 합니다."
	var res := _auth("register", name, password)
	if res != "":
		return res
	_rest(HTTPClient.METHOD_POST, "/rest/v1/notes", JSON.stringify({
		"user_id": user_id,
		"kind": "reward",
		"from_name": "",
		"body": "환영 보상  ·  첫 경기 준비금이 지급되었습니다.",
	}))
	return ""

func login(name: String, password: String) -> String:
	name = name.strip_edges()
	if name == "" or password == "":
		return "아이디와 비밀번호를 입력하세요."
	return _auth("login", name, password)

func function_call(fn: String, body: Dictionary) -> Dictionary:
	if not logged_in():
		return {"error": "먼저 로그인하세요."}
	if _access_expired() and not _refresh_session():
		logout()
		return {"error": "로그인이 만료되었습니다. 다시 로그인하세요."}
	var res := _http(HTTPClient.METHOD_POST, "/functions/v1/" + fn, JSON.stringify(body), access)
	if int(res.get("_code", 0)) == 401 and _refresh_session():
		res = _http(HTTPClient.METHOD_POST, "/functions/v1/" + fn, JSON.stringify(body), access)
	if int(res.get("_code", 0)) == 401:
		logout()
		return {"error": "로그인이 만료되었습니다. 다시 로그인하세요."}
	return res

func load_progress() -> void:
	account_level = 1
	account_elo = 1000
	account_ranked = 0
	account_rank = ""
	if not logged_in():
		return
	var res := _http(HTTPClient.METHOD_GET, "/rest/v1/profiles?id=eq.%s&select=level,elo,ranked_games,rank_tier" % user_id, "", access)
	for item in _list(res):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		account_level = maxi(1, int(row.get("level", 1)))
		account_elo = int(row.get("elo", 1000))
		account_ranked = int(row.get("ranked_games", 0))
		account_rank = str(row.get("rank_tier", ""))
		return

func rank_text() -> String:
	if account_level < 55:
		return "랭크 잠김"
	if account_ranked < 10:
		return "배치고사 %d/10" % account_ranked
	if account_rank == "":
		return "언랭크"
	return account_rank

func logout() -> void:
	username = ""
	user_id = ""
	access = ""
	refresh = ""
	var cfg := ConfigFile.new()
	cfg.save(session_path)

func request_friend(name: String) -> String:
	if not logged_in():
		return "먼저 로그인하세요."
	var target := _profile(name)
	if target.is_empty():
		return "없는 Strife Acc 입니다."
	var target_id := str(target.get("id", ""))
	var target_name := str(target.get("username", name))
	if target_id == user_id:
		return "본인에게는 보낼 수 없습니다."
	if _linked("/rest/v1/friendships?user_id=eq.%s&friend_id=eq.%s&select=user_id" % [user_id, target_id]):
		return "이미 친구입니다."
	if _linked("/rest/v1/friend_requests?to_id=eq.%s&from_id=eq.%s&select=from_id" % [user_id, target_id]):
		var accepted := accept_friend(target_name)
		return "친구가 되었습니다." if accepted == "" else accepted
	if _linked("/rest/v1/friend_requests?from_id=eq.%s&to_id=eq.%s&select=from_id" % [user_id, target_id]):
		return "이미 친구 요청을 보냈습니다."
	var sent := _rest(HTTPClient.METHOD_POST, "/rest/v1/friend_requests", JSON.stringify({
		"from_id": user_id,
		"to_id": target_id,
	}))
	if sent != "":
		return sent
	_rest(HTTPClient.METHOD_POST, "/rest/v1/notes", JSON.stringify({
		"user_id": target_id,
		"kind": "friend",
		"from_name": username,
		"body": "%s 님이 친구 요청을 보냈습니다." % username,
	}))
	_rest(HTTPClient.METHOD_POST, "/rest/v1/notes", JSON.stringify({
		"user_id": user_id,
		"kind": "sent",
		"from_name": target_name,
		"body": "%s 님에게 친구 요청을 보냈습니다." % target_name,
	}))
	return ""

func accept_friend(name: String) -> String:
	if not logged_in():
		return "먼저 로그인하세요."
	var target := _profile(name)
	if target.is_empty():
		return "없는 Strife Acc 입니다."
	var target_id := str(target.get("id", ""))
	var target_name := str(target.get("username", name))
	if not _linked("/rest/v1/friend_requests?to_id=eq.%s&from_id=eq.%s&select=from_id" % [user_id, target_id]):
		return "요청이 없습니다."
	var one := _rest(HTTPClient.METHOD_POST, "/rest/v1/friendships", JSON.stringify({
		"user_id": user_id,
		"friend_id": target_id,
	}))
	if one != "":
		return one
	var two := _rest(HTTPClient.METHOD_POST, "/rest/v1/friendships", JSON.stringify({
		"user_id": target_id,
		"friend_id": user_id,
	}))
	if two != "":
		return two
	_rest(HTTPClient.METHOD_DELETE, "/rest/v1/friend_requests?from_id=eq.%s&to_id=eq.%s" % [target_id, user_id], "")
	_rest(HTTPClient.METHOD_POST, "/rest/v1/notes", JSON.stringify({
		"user_id": target_id,
		"kind": "friend",
		"from_name": username,
		"body": "%s 님이 친구 요청을 수락했습니다." % username,
	}))
	_rest(HTTPClient.METHOD_POST, "/rest/v1/notes", JSON.stringify({
		"user_id": user_id,
		"kind": "friend",
		"from_name": target_name,
		"body": "%s 님과 친구가 되었습니다." % target_name,
	}))
	return ""

func decline_friend(name: String) -> String:
	if not logged_in():
		return "먼저 로그인하세요."
	var target := _profile(name)
	if target.is_empty():
		return "요청이 없습니다."
	return _rest(HTTPClient.METHOD_DELETE, "/rest/v1/friend_requests?from_id=eq.%s&to_id=eq.%s" % [str(target.get("id", "")), user_id], "")

func friend_names() -> PackedStringArray:
	return _name_rows("/rest/v1/friendships?user_id=eq.%s&select=profiles!friendships_friend_id_fkey(username)" % user_id)

func request_names() -> PackedStringArray:
	return _name_rows("/rest/v1/friend_requests?to_id=eq.%s&select=profiles!friend_requests_from_id_fkey(username)" % user_id)

func outgoing_names() -> PackedStringArray:
	return _name_rows("/rest/v1/friend_requests?from_id=eq.%s&select=profiles!friend_requests_to_id_fkey(username)" % user_id)

func notes() -> PackedStringArray:
	var out := PackedStringArray()
	if not logged_in():
		return out
	var res := _http(HTTPClient.METHOD_GET, "/rest/v1/notes?user_id=eq.%s&select=kind,from_name,body&order=created_at.desc" % user_id, "", access)
	for item in _list(res):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		out.append("%s|%s|%s" % [str(row.get("kind", "")), str(row.get("from_name", "")), str(row.get("body", ""))])
	return out

func unread() -> int:
	return notes().size() + request_names().size()

func _auth(op: String, name: String, password: String) -> String:
	var res := _http(HTTPClient.METHOD_POST, "/functions/v1/strife-acc", JSON.stringify({
		"op": op,
		"username": name,
		"password": password,
	}), KEY)
	if int(res.get("_code", 0)) < 200 or int(res.get("_code", 0)) >= 300:
		return str(res.get("_err", "계정 서버에 연결하지 못했습니다."))
	username = str(res.get("username", name))
	user_id = str(res.get("user_id", ""))
	access = str(res.get("access_token", ""))
	refresh = str(res.get("refresh_token", ""))
	if access == "" or user_id == "":
		return "계정 서버 응답이 비어 있습니다."
	_save_session()
	return ""

func _profile(name: String) -> Dictionary:
	var key := name.strip_edges().to_lower().uri_encode()
	if key == "":
		return {}
	var res := _http(HTTPClient.METHOD_GET, "/rest/v1/profiles?username_key=eq.%s&select=id,username" % key, "", access)
	for item in _list(res):
		if typeof(item) == TYPE_DICTIONARY:
			return item
	return {}

func _linked(path: String) -> bool:
	return not _list(_http(HTTPClient.METHOD_GET, path, "", access)).is_empty()

func _name_rows(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not logged_in():
		return out
	for item in _list(_http(HTTPClient.METHOD_GET, path, "", access)):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var profile = row.get("profiles", {})
		if typeof(profile) == TYPE_DICTIONARY:
			var nested: Dictionary = profile
			var id := str(nested.get("username", ""))
			if id != "":
				out.append(id)
	return out

func _rest(method: int, path: String, payload: String) -> String:
	var res := _http(method, path, payload, access)
	var code := int(res.get("_code", 0))
	if code >= 200 and code < 300:
		return ""
	return str(res.get("_err", "계정 서버에 연결하지 못했습니다."))

func _list(res: Dictionary) -> Array:
	var raw = res.get("_list", [])
	if raw is Array:
		return raw
	return []

func _load_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(session_path) != OK:
		return
	username = str(cfg.get_value("session", "user", ""))
	user_id = str(cfg.get_value("session", "user_id", ""))
	access = str(cfg.get_value("session", "access", ""))
	refresh = str(cfg.get_value("session", "refresh", ""))
	if access == "":
		username = ""
		user_id = ""

func _access_expired() -> bool:
	var parts := access.split(".")
	if parts.size() < 2:
		return true
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	var extra := b64.length() % 4
	if extra > 0:
		b64 += "=".repeat(4 - extra)
	var raw := Marshalls.base64_to_raw(b64)
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return true
	var data: Dictionary = parsed
	return int(data.get("exp", 0)) <= int(Time.get_unix_time_from_system()) + 60

func _refresh_session() -> bool:
	if refresh == "":
		return false
	var res := _http(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", JSON.stringify({
		"refresh_token": refresh,
	}), KEY)
	var code := int(res.get("_code", 0))
	if code < 200 or code >= 300:
		return false
	var next_access := str(res.get("access_token", ""))
	if next_access == "":
		return false
	access = next_access
	var next_refresh := str(res.get("refresh_token", ""))
	if next_refresh != "":
		refresh = next_refresh
	_save_session()
	return true

func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "user", username)
	cfg.set_value("session", "user_id", user_id)
	cfg.set_value("session", "access", access)
	cfg.set_value("session", "refresh", refresh)
	cfg.save(session_path)

func _http(method: int, path: String, payload: String, token: String) -> Dictionary:
	var client := HTTPClient.new()
	var err := client.connect_to_host(HOST, 443, TLSOptions.client())
	if err != OK:
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
		"apikey: " + KEY,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	err = client.request(method, path, headers, payload)
	if err != OK:
		return {"_code": 0, "_err": "요청을 보내지 못했습니다."}
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() - started > 8000:
			return {"_code": 0, "_err": "서버 응답이 없습니다."}
		OS.delay_msec(10)
	if not client.has_response():
		return {"_code": 0, "_err": "서버 응답이 없습니다."}
	var code := client.get_response_code()
	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			if Time.get_ticks_msec() - started > 8000:
				break
			OS.delay_msec(10)
		else:
			body.append_array(chunk)
	client.close()
	var text := body.get_string_from_utf8().strip_edges()
	var parsed = JSON.parse_string(text) if text != "" else null
	var out := {"_code": code}
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = parsed
		for key in data.keys():
			out[str(key)] = data[key]
	elif typeof(parsed) == TYPE_ARRAY:
		out["_list"] = parsed
	if code < 200 or code >= 300:
		var msg := str(out.get("error", out.get("msg", out.get("message", ""))))
		if msg == "":
			msg = "요청이 거절되었습니다."
		out["_err"] = msg
	return out
