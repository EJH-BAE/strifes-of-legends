extends Node

const ACC := "user://session.cfg"
const AUTH_HOST := "sagrimdeoxfhvrtjllrm.supabase.co"
const AUTH_KEY := "sb_publishable_yhM8PP1ZK7ToF51XKeUhdQ_5pRkE5Uc"
const SETTINGS := "user://settings.cfg"
const VERSION := "0.6.4"
const FEED := "https://raw.githubusercontent.com/EJH-BAE/strifes-of-legends/main/update.json"

var username := ""
var resolution := "1920x1080"
var max_fps := 0
var window_mode := "borderless"
var status: Label
var patch_http: HTTPRequest
var next_game := ""
var account_box: VBoxContainer
var home_box: VBoxContainer
var name_label: Label

func _ready() -> void:
	_load_session()
	_load_video()
	_apply_icon()
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _font()
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.012, 0.035, 0.09)
	root.add_child(bg)
	var column := VBoxContainer.new()
	column.position = Vector2(48, 28)
	column.add_theme_constant_override("separation", 18)
	root.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var mark := TextureRect.new()
	mark.texture = load("res://art/mark.png")
	mark.custom_minimum_size = Vector2(84, 132)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.clip_contents = true
	header.add_child(mark)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(titles)
	var title := Label.new()
	title.text = "STRIFE MANAGER"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	titles.add_child(title)
	var sub := Label.new()
	sub.text = "Strife Acc  ·  Strifes of Legends"
	sub.add_theme_color_override("font_color", Color(0.72, 0.66, 0.52))
	titles.add_child(sub)
	account_box = _column(column)
	home_box = _column(column)
	_build_account()
	_build_home()
	status = Label.new()
	status.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(420, 28)
	column.add_child(status)
	_show_gate()
	_check_update()

func _column(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	parent.add_child(box)
	return box

func _build_account() -> void:
	var name_box := LineEdit.new()
	name_box.placeholder_text = "Strife Acc 이름"
	name_box.custom_minimum_size = Vector2(420, 42)
	account_box.add_child(name_box)
	var pass_box := LineEdit.new()
	pass_box.placeholder_text = "비밀번호"
	pass_box.secret = true
	pass_box.custom_minimum_size = Vector2(420, 42)
	account_box.add_child(pass_box)
	account_box.add_child(_button("로그인", func():
		var msg = _login(name_box.text, pass_box.text)
		_say(msg if msg != "" else "", msg != "")
		if msg == "":
			_show_gate()
	))
	account_box.add_child(_button("계정 만들기", func():
		var msg = _register(name_box.text, pass_box.text)
		_say(msg if msg != "" else "", msg != "")
		if msg == "":
			_show_gate()
	))

func _build_home() -> void:
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.74))
	home_box.add_child(name_label)
	var res := OptionButton.new()
	for item in ["1280x720", "1600x900", "1920x1080", "2560x1440"]:
		res.add_item(item)
	res.selected = max(0, ["1280x720", "1600x900", "1920x1080", "2560x1440"].find(resolution))
	res.item_selected.connect(func(i):
		resolution = ["1280x720", "1600x900", "1920x1080", "2560x1440"][i]
		_save_video()
	)
	home_box.add_child(res)
	var fps := OptionButton.new()
	var fps_items = [["모니터 동기", 0], ["60 Hz", 60], ["120 Hz", 120], ["144 Hz", 144], ["165 Hz", 165], ["240 Hz", 240]]
	for item in fps_items:
		fps.add_item(item[0])
	for i in fps_items.size():
		if int(fps_items[i][1]) == max_fps:
			fps.selected = i
	fps.item_selected.connect(func(i):
		max_fps = int(fps_items[i][1])
		_save_video()
	)
	home_box.add_child(fps)
	var window := OptionButton.new()
	window.add_item("창 모드", 0)
	window.add_item("테두리 없는 전체 화면", 1)
	window.add_item("전체 화면", 2)
	window.selected = {"window": 0, "borderless": 1, "fullscreen": 2}.get(window_mode, 1)
	window.item_selected.connect(func(i):
		window_mode = ["window", "borderless", "fullscreen"][i]
		_save_video()
	)
	home_box.add_child(window)
	home_box.add_child(_button("Strifes of Legends 실행", _play))
	home_box.add_child(_button("계정 전환", func():
		username = ""
		var cfg := ConfigFile.new()
		cfg.save(ACC)
		_show_gate()
	))
	home_box.add_child(_button("종료", func(): get_tree().quit()))

func _say(text: String, bad: bool) -> void:
	status.text = text
	status.add_theme_color_override("font_color", Color(1, 0.55, 0.4) if bad else Color(0.78, 0.7, 0.55))

func _show_gate() -> void:
	var logged = username != ""
	account_box.visible = not logged
	home_box.visible = logged
	if logged:
		name_label.text = username

func _play() -> void:
	_save_video()
	var folder := OS.get_executable_path().get_base_dir()
	var names = ["Strifes of Legends.new.exe", "Strifes of Legends.exe"]
	var game := ""
	for file_name in names:
		var beside := folder.path_join(file_name)
		if FileAccess.file_exists(beside):
			game = beside
			break
	if game == "":
		for file_name in names:
			var fixed := "C:/Strifes of Legends/%s" % file_name
			if FileAccess.file_exists(fixed):
				game = fixed
				break
	if game == "":
		status.text = "Strifes of Legends.exe 를 찾을 수 없습니다."
		return
	OS.create_process(game, [])
	status.text = "게임을 실행했습니다."

func _load_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ACC) != OK:
		return
	var last := str(cfg.get_value("session", "user", ""))
	var token := str(cfg.get_value("session", "access", ""))
	if last != "" and token != "":
		username = last

func _load_video() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return
	resolution = str(cfg.get_value("video", "resolution", resolution))
	max_fps = int(cfg.get_value("video", "max_fps", max_fps))
	window_mode = str(cfg.get_value("video", "window_mode", window_mode))

func _save_video() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("video", "resolution", resolution)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.save(SETTINGS)

func _register(acc_name: String, password: String) -> String:
	acc_name = acc_name.strip_edges()
	if acc_name.length() < 3:
		return "이름은 3글자 이상이어야 합니다."
	if password.length() < 6:
		return "비밀번호는 6글자 이상이어야 합니다."
	return _auth("register", acc_name, password)

func _login(acc_name: String, password: String) -> String:
	acc_name = acc_name.strip_edges()
	if acc_name == "" or password == "":
		return "아이디와 비밀번호를 입력하세요."
	return _auth("login", acc_name, password)

func _auth(op: String, acc_name: String, password: String) -> String:
	var client := HTTPClient.new()
	if client.connect_to_host(AUTH_HOST, 443, TLSOptions.client()) != OK:
		return "계정 서버에 연결하지 못했습니다."
	var started := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		if Time.get_ticks_msec() - started > 8000:
			return "서버 응답이 없습니다."
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return "계정 서버에 연결하지 못했습니다."
	var payload := JSON.stringify({"op": op, "username": acc_name, "password": password})
	var headers := PackedStringArray([
		"apikey: " + AUTH_KEY,
		"Authorization: Bearer " + AUTH_KEY,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if client.request(HTTPClient.METHOD_POST, "/functions/v1/strife-acc", headers, payload) != OK:
		return "요청을 보내지 못했습니다."
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() - started > 8000:
			return "서버 응답이 없습니다."
		OS.delay_msec(10)
	if not client.has_response():
		return "서버 응답이 없습니다."
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
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return "계정 서버 응답을 읽지 못했습니다."
	var data: Dictionary = parsed
	if code < 200 or code >= 300:
		return str(data.get("error", "계정 서버에 연결하지 못했습니다."))
	username = str(data.get("username", acc_name))
	var cfg := ConfigFile.new()
	cfg.set_value("session", "user", username)
	cfg.set_value("session", "user_id", str(data.get("user_id", "")))
	cfg.set_value("session", "access", str(data.get("access_token", "")))
	cfg.set_value("session", "refresh", str(data.get("refresh_token", "")))
	cfg.save(ACC)
	return ""

func _apply_icon() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tex = load("res://art/mark.png")
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	img = img.duplicate()
	if img.get_width() != 128:
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	DisplayServer.set_icon(img)

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.78, 0.62, 0.32)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", Color(0.12, 0.08, 0.03))
	b.pressed.connect(cb)
	return b

func _check_update() -> void:
	var name := OS.get_executable_path().get_file().to_lower()
	if not name.begins_with("strife manager"):
		status.text = "버전 %s" % VERSION
		return
	patch_http = HTTPRequest.new()
	add_child(patch_http)
	patch_http.request_completed.connect(_on_feed)
	status.text = "업데이트 확인 중"
	if patch_http.request(FEED) != OK:
		status.text = "버전 %s" % VERSION

func _on_feed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status.text = "버전 %s" % VERSION
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		status.text = "업데이트 정보를 읽지 못했습니다."
		return
	var remote := str(data.get("version", ""))
	if _newer(remote, VERSION) <= 0:
		_say("최신 버전 %s" % VERSION, false)
		return
	var url := str(data.get("installer", ""))
	if url == "":
		status.text = "새 버전 %s 설치 파일이 없습니다." % remote
		return
	next_game = OS.get_executable_path().get_base_dir().path_join("SoLSetup.exe")
	status.text = "설치 파일 %s 받는 중" % remote
	patch_http.request_completed.disconnect(_on_feed)
	patch_http.request_completed.connect(_on_download)
	patch_http.download_file = next_game
	if patch_http.request(url) != OK:
		status.text = "설치 파일을 받지 못했습니다."

func _on_download(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(next_game):
		status.text = "설치 파일을 받지 못했습니다."
		return
	status.text = "매니저와 게임을 설치합니다."
	OS.create_process(next_game, [])
	get_tree().quit()

func _game_path() -> String:
	var folder := OS.get_executable_path().get_base_dir()
	for file_name in ["Strifes of Legends.exe", "Strifes of Legends.new.exe"]:
		var beside := folder.path_join(file_name)
		if FileAccess.file_exists(beside):
			return beside
		var fixed := "C:/Strifes of Legends/%s" % file_name
		if FileAccess.file_exists(fixed):
			return fixed
	return ""

func _newer(remote: String, local: String) -> int:
	var aa := remote.split(".")
	var bb := local.split(".")
	for i in 3:
		var av := int(aa[i]) if i < aa.size() else 0
		var bv := int(bb[i]) if i < bb.size() else 0
		if av != bv:
			return 1 if av > bv else -1
	return 0

func _font() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	theme.default_font = font
	theme.default_font_size = 18
	return theme
