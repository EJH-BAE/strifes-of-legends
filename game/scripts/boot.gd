extends Node

const MenuScript = preload("res://scripts/settings_menu.gd")
const Marks = preload("res://scripts/marks.gd")
const Legends = preload("res://scripts/legends.gd")

var cam: Camera3D
var spin := 0.0
var role_claim := false
var role_wait := 1.0
var taken_roles := {}
var role_nodes := {}

func _ready() -> void:
	if not SolNet.session_ready.is_connected(_on_session_ready):
		SolNet.session_ready.connect(_on_session_ready)
		SolNet.session_failed.connect(_on_session_failed)
	print("VITAL ", preload("res://scripts/health.gd").new().self_test())
	print("DISPLAY ", DisplayServer.get_name())
	Settings.apply_window()
	_apply_icon()
	var direct = DisplayServer.get_name() == "headless"
	var server = false
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shot="):
			direct = true
		if str(arg) == "--server":
			server = true
	if server:
		SolNet.begin_server()
		return
	if direct:
		get_tree().change_scene_to_file.call_deferred("res://match.tscn")
		return
	_world()
	if StrifeAcc.logged_in():
		_menu()
	else:
		_account()
	Settings.changed.connect(func(): Settings.apply_window())

func _world() -> void:
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.045, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.42, 0.36)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.16, 0.14)
	ground.material_override = mat
	world.add_child(ground)
	for i in 8:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 3.5 + float(i % 3), 1.2)
		box.mesh = bm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.16, 0.14, 0.12)
		box.material_override = sm
		var ang := float(i) / 8.0 * TAU
		box.position = Vector3(cos(ang) * 10.0, bm.size.y * 0.5, sin(ang) * 10.0)
		world.add_child(box)
	var crest := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.15
	cyl.height = 6.0
	crest.mesh = cyl
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.86, 0.72, 0.42)
	gold.emission_enabled = true
	gold.emission = Color(1, 0.86, 0.5)
	gold.emission_energy_multiplier = 0.6
	crest.material_override = gold
	crest.position = Vector3(0, 3, 0)
	world.add_child(crest)
	cam = Camera3D.new()
	cam.fov = 42
	cam.current = true
	world.add_child(cam)

func _process(delta: float) -> void:
	if cam != null:
		spin += delta * 0.15
		cam.position = Vector3(sin(spin) * 16.0, 9.0, cos(spin) * 16.0)
		cam.look_at(Vector3(0, 1.2, 0), Vector3.UP)
	if role_claim and Draft.mode != "duel":
		role_wait -= delta
		if role_wait <= 0.0:
			role_wait = 1.15
			_ai_take_role()
	if matching:
		match_secs += delta
		if match_clock:
			var secs := int(match_secs)
			match_clock.text = "%d:%02d" % [int(secs / 60.0), secs % 60]
		match_poll -= delta
		if match_poll <= 0.0:
			match_poll = 1.0
			_poll_match()
	elif linking:
		match_secs += delta
		if match_clock:
			var secs := int(match_secs)
			match_clock.text = "%d:%02d" % [int(secs / 60.0), secs % 60]
		link_wait -= delta
		if link_wait <= 0.0:
			_link_failed("서버에 연결하지 못했습니다.")

var home_mode := "normal"
var party_box: Control
var home_toast: Label
var match_layer: CanvasLayer
var match_title: Label
var match_clock: Label
var matching := false
var linking := false
var link_wait := 0.0
var match_secs := 0.0
var match_poll := 0.0

func _menu() -> void:
	StrifeAcc.load_progress()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _font()
	layer.add_child(root)
	var top := HBoxContainer.new()
	top.position = Vector2(28, 18)
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	top.add_child(_logo(48))
	var title_box := VBoxContainer.new()
	top.add_child(title_box)
	var kicker := Label.new()
	kicker.text = "STRIFES OF LEGENDS"
	kicker.add_theme_font_size_override("font_size", 26)
	kicker.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	title_box.add_child(kicker)
	var sub := Label.new()
	sub.text = "전설의 전장"
	sub.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	title_box.add_child(sub)
	var ident := Label.new()
	ident.text = "%s   Lv.%d   %s" % [StrifeAcc.current(), StrifeAcc.account_level, StrifeAcc.rank_text()]
	ident.position = Vector2(420, 28)
	ident.add_theme_font_size_override("font_size", 18)
	ident.add_theme_color_override("font_color", Color(0.9, 0.86, 0.74))
	root.add_child(ident)
	var foot := HBoxContainer.new()
	foot.position = Vector2(900, 22)
	foot.add_theme_constant_override("separation", 6)
	root.add_child(foot)
	for pair in [["친구", _open_friends], ["알림", _open_notes], ["설정", _open_settings], ["종료", func(): get_tree().quit()]]:
		var fb := _menu_button(pair[0], pair[1])
		fb.custom_minimum_size = Vector2(72, 32)
		foot.add_child(fb)
	home_toast = Label.new()
	home_toast.position = Vector2(36, 88)
	home_toast.add_theme_color_override("font_color", Color(0.8, 0.9, 0.65))
	if SolNet.notice != "":
		home_toast.text = SolNet.notice
		SolNet.notice = ""
	root.add_child(home_toast)
	var patch_label := Label.new()
	patch_label.text = ""
	patch_label.position = Vector2(36, 112)
	patch_label.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))
	root.add_child(patch_label)
	var patch := preload("res://scripts/patch.gd").new()
	add_child(patch)
	patch.start(self, patch_label)
	var dock := Panel.new()
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -250
	dock.offset_bottom = -16
	dock.offset_left = 24
	dock.offset_right = -24
	var dock_style := StyleBoxFlat.new()
	dock_style.bg_color = Color(0.03, 0.04, 0.07, 0.88)
	dock_style.border_color = Color(0.83, 0.71, 0.51, 0.7)
	dock_style.set_border_width_all(1)
	dock.add_theme_stylebox_override("panel", dock_style)
	root.add_child(dock)
	var play := Label.new()
	play.text = "플레이"
	play.position = Vector2(16, 8)
	play.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	dock.add_child(play)
	var scroller := ScrollContainer.new()
	scroller.position = Vector2(16, 36)
	scroller.size = Vector2(1100, 64)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock.add_child(scroller)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	scroller.add_child(modes)
	var mode_rows = [["duel", "일반", "AI 대전 1v1"], ["normal", "일반", "5v5"], ["ranked", "랭크", "5v5"], ["swift", "아케이드", "Swift Strike"]]
	for item in mode_rows:
		var mode_id: String = item[0]
		var card := Button.new()
		card.text = "%s\n%s" % [item[1], item[2]]
		card.custom_minimum_size = Vector2(180, 56)
		card.set_meta("mode_id", mode_id)
		card.pressed.connect(_pick_mode.bind(card, modes))
		modes.add_child(card)
	_paint_modes(modes)
	party_box = Control.new()
	party_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(party_box)
	var start := _menu_button("매치 시작", _start_match)
	start.position = Vector2(860, 168)
	start.custom_minimum_size = Vector2(220, 48)
	dock.add_child(start)
	_paint_party()

func _pick_mode(card: Button, modes: HBoxContainer) -> void:
	home_mode = str(card.get_meta("mode_id", "normal"))
	Sfx.play("click")
	_paint_modes(modes)

func _paint_modes(modes: HBoxContainer) -> void:
	for child in modes.get_children():
		if child is Button:
			var btn := child as Button
			var on := str(btn.get_meta("mode_id", "")) == home_mode
			btn.modulate = Color(1, 0.92, 0.7) if on else Color(0.7, 0.7, 0.7)

func _mode_title(mode_id: String) -> String:
	if mode_id == "ranked":
		return "랭크"
	if mode_id == "swift":
		return "아케이드"
	if mode_id == "duel":
		return "일반"
	return "일반"

func _mode_blurb(mode_id: String) -> String:
	if mode_id == "duel":
		return "AI 대전 1v1"
	if mode_id == "ranked":
		return "5v5"
	if mode_id == "swift":
		return "Swift Strike"
	return "5v5"

func _paint_party() -> void:
	if party_box == null:
		return
	for child in party_box.get_children():
		party_box.remove_child(child)
		child.queue_free()
	var mine := StrifeAcc.current()
	var mine_row := {"username": mine, "role": "mid"}
	var others: Array = []
	var seen := {}
	var state: Dictionary = SolNet.party("state")
	var group = state.get("members", [])
	if group is Array:
		for item in group:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = item
			if str(row.get("member_status", "")) != "joined":
				continue
			var who := str(row.get("username", ""))
			if who == "" or seen.has(who):
				continue
			seen[who] = true
			if who == mine:
				mine_row = row
			else:
				others.append(row)
	var slots: Array = [null, null, mine_row, null, null]
	var order := [1, 3, 0, 4]
	for i in mini(others.size(), order.size()):
		slots[order[i]] = others[i]
	var view := get_viewport().get_visible_rect().size
	var gap := 16.0
	var card_w := minf(156.0, (view.x - 96.0 - gap * 4.0) / 5.0)
	var card_h := minf(360.0, view.y - 340.0)
	var total := card_w * 5.0 + gap * 4.0
	var x0 := (view.x - total) * 0.5
	var y0 := (view.y - 260.0 - card_h) * 0.5
	if y0 < 96.0:
		y0 = 96.0
	var card_size := Vector2(card_w, card_h)
	for i in 5:
		var card: Control
		if slots[i] == null:
			card = _party_empty(card_size)
		else:
			card = _party_banner(slots[i], card_size)
		card.position = Vector2(x0 + float(i) * (card_w + gap), y0)
		party_box.add_child(card)

func _party_banner(row: Dictionary, card_size: Vector2) -> Control:
	var who := str(row.get("username", ""))
	var role := str(row.get("role", "mid"))
	var mine := who == StrifeAcc.current()
	var card := Panel.new()
	card.custom_minimum_size = card_size
	card.size = card_size
	card.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.1, 0.14, 0.94)
	style.border_color = Color(0.96, 0.82, 0.34) if mine else Color(0.28, 0.4, 0.5, 0.8)
	style.set_border_width_all(3 if mine else 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)
	var roles := {"top": "탑", "jungle": "정글", "mid": "미드", "adc": "원딜", "support": "서폿"}
	var pool: Array = Legends.by_role(role if role != "" else "mid")
	if pool.is_empty():
		pool = Legends.all()
	var def: Dictionary = pool[absi(who.hash()) % pool.size()]
	var art := TextureRect.new()
	art.texture = Legends.portrait(def, 280)
	var art_h := card_size.y - 124.0
	art.position = Vector2(8, 8)
	art.size = Vector2(card_size.x - 16.0, art_h)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card.add_child(art)
	var name := Label.new()
	name.text = who
	name.position = Vector2(8, art_h + 12.0)
	name.size = Vector2(card_size.x - 16.0, 24)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", Color(0.96, 0.94, 0.9) if mine else Color(0.82, 0.86, 0.9))
	card.add_child(name)
	var sub := Label.new()
	sub.text = str(roles.get(role, "준비"))
	sub.position = Vector2(8, art_h + 36.0)
	sub.size = Vector2(card_size.x - 16.0, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.7, 0.78, 0.84))
	card.add_child(sub)
	var badge := TextureRect.new()
	badge.texture = Marks.icon(role if role != "" else "mid")
	badge.position = Vector2(card_size.x * 0.5 - 24.0, card_size.y - 56.0)
	badge.size = Vector2(48, 48)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(badge)
	return card

func _party_empty(card_size: Vector2) -> Control:
	var card := Button.new()
	card.text = "+"
	card.custom_minimum_size = card_size
	card.size = card_size
	card.add_theme_font_size_override("font_size", 48)
	card.add_theme_color_override("font_color", Color(0.55, 0.7, 0.78))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.72)
	style.border_color = Color(0.22, 0.34, 0.42, 0.7)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("normal", style)
	card.add_theme_stylebox_override("hover", style)
	card.pressed.connect(_invite_friend)
	return card

func _kick_member(_who: String) -> void:
	_open_friends()

func _invite_friend() -> void:
	_open_friends()

func _start_match() -> void:
	if home_mode == "ranked" and StrifeAcc.account_level < 55:
		home_toast.text = "랭크는 55레벨부터 가능합니다."
		Sfx.play("error")
		return
	var queued: Dictionary = StrifeAcc.function_call("strife-queue", {"op": "enqueue", "mode": home_mode})
	if str(queued.get("error", "")) != "":
		home_toast.text = str(queued.get("error", ""))
		Sfx.play("error")
		return
	home_toast.text = "매칭을 시작했습니다."
	matching = true
	match_secs = 0.0
	match_poll = 0.2
	_show_matching()

func _show_matching() -> void:
	if match_layer != null and is_instance_valid(match_layer):
		match_layer.queue_free()
	match_layer = CanvasLayer.new()
	match_layer.layer = 40
	add_child(match_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.theme = _font()
	match_layer.add_child(dim)
	match_title = Label.new()
	match_title.text = "매칭 찾는 중..."
	match_title.set_anchors_preset(Control.PRESET_CENTER)
	match_title.offset_left = -280
	match_title.offset_top = -40
	match_title.offset_right = 280
	match_title.offset_bottom = 0
	match_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_title.add_theme_font_size_override("font_size", 36)
	match_title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	match_layer.add_child(match_title)
	var dots := preload("res://scripts/load_dots.gd").new()
	dots.set_anchors_preset(Control.PRESET_CENTER)
	dots.offset_left = -120
	dots.offset_top = 8
	dots.offset_right = 120
	dots.offset_bottom = 88
	match_layer.add_child(dots)
	match_clock = Label.new()
	match_clock.set_anchors_preset(Control.PRESET_CENTER)
	match_clock.offset_left = -80
	match_clock.offset_top = 96
	match_clock.offset_right = 80
	match_clock.offset_bottom = 128
	match_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_clock.add_theme_font_size_override("font_size", 22)
	match_clock.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	match_clock.text = "0:00"
	match_layer.add_child(match_clock)
	var close := Button.new()
	close.text = "X"
	close.set_anchors_preset(Control.PRESET_CENTER)
	close.offset_left = 150
	close.offset_top = -48
	close.offset_right = 198
	close.offset_bottom = -8
	close.pressed.connect(_cancel_match)
	match_layer.add_child(close)

func _cancel_match() -> void:
	matching = false
	linking = false
	SolNet.abort_join()
	StrifeAcc.function_call("strife-queue", {"op": "cancel"})
	if match_layer != null and is_instance_valid(match_layer):
		match_layer.queue_free()
	match_layer = null
	match_title = null
	if home_toast:
		home_toast.text = "매칭을 취소했습니다."

func _poll_match() -> void:
	var res: Dictionary = StrifeAcc.function_call("strife-queue", {"op": "poll"})
	if str(res.get("error", "")) != "":
		_cancel_match()
		if home_toast:
			home_toast.text = str(res.get("error", ""))
		return
	if not bool(res.get("ready", false)):
		return
	matching = false
	_play_local(str(res.get("match_id", "")), home_mode)

func _play_local(match_id: String, mode_name: String) -> void:
	if match_title:
		match_title.text = "경기 준비 중..."
	SolNet.abort_join()
	var pack: Dictionary = StrifeAcc.match_pack(match_id)
	var mode := str(pack.get("mode", mode_name))
	var roster = pack.get("roster", [])
	if roster is Array and not roster.is_empty():
		Draft.install_roster(mode, roster)
	else:
		Draft.queue(mode_name)
		Draft.ensure()
	get_tree().change_scene_to_file("res://match.tscn")

func _connect_server(host: String, port: int) -> void:
	if match_layer == null or not is_instance_valid(match_layer):
		_show_matching()
	matching = false
	linking = true
	link_wait = 25.0
	if match_title:
		match_title.text = "서버 연결 중..."
	var err := SolNet.connect_match(host, port)
	if err != "":
		_link_failed(err)

func _on_session_ready() -> void:
	if not linking:
		return
	linking = false
	get_tree().change_scene_to_file("res://match.tscn")

func _on_session_failed() -> void:
	if not linking:
		return
	_link_failed("서버에 연결하지 못했습니다.")

func _link_failed(msg: String) -> void:
	linking = false
	matching = false
	SolNet.abort_join()
	if match_layer != null and is_instance_valid(match_layer):
		match_layer.queue_free()
	match_layer = null
	match_title = null
	if home_toast:
		home_toast.text = msg
	Sfx.play("error")

func _account() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Account"
	layer.layer = 6
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _font()
	layer.add_child(root)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -240
	center.offset_top = -260
	center.offset_right = 240
	center.offset_bottom = 220
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 8)
	root.add_child(center)
	center.add_child(_logo(84))
	var title := Label.new()
	title.text = "Strife Acc"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	center.add_child(title)
	var name_box := LineEdit.new()
	name_box.placeholder_text = "이름"
	name_box.custom_minimum_size = Vector2(320, 40)
	center.add_child(name_box)
	var pass_box := LineEdit.new()
	pass_box.placeholder_text = "비밀번호"
	pass_box.secret = true
	pass_box.custom_minimum_size = Vector2(320, 40)
	center.add_child(pass_box)
	var err := Label.new()
	err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	center.add_child(err)
	center.add_child(_menu_button("로그인", func():
		var msg = StrifeAcc.login(name_box.text, pass_box.text)
		if msg == "":
			layer.queue_free()
			_menu()
		else:
			err.text = msg
			Sfx.play("error")
	))
	center.add_child(_menu_button("계정 만들기", func():
		var msg = StrifeAcc.register(name_box.text, pass_box.text)
		if msg == "":
			layer.queue_free()
			_menu()
		else:
			err.text = msg
			Sfx.play("error")
	))

func _open_friends() -> void:
	if not StrifeAcc.logged_in():
		return
	var layer := _overlay("친구")
	var box: VBoxContainer = layer.get_node("Root/Box")
	var mine := Label.new()
	mine.text = "내 계정  %s" % StrifeAcc.current()
	mine.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))
	box.add_child(mine)
	var name_box := LineEdit.new()
	name_box.placeholder_text = "추가할 Strife Acc 아이디"
	name_box.custom_minimum_size = Vector2(420, 40)
	box.add_child(name_box)
	var err := Label.new()
	err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err.custom_minimum_size = Vector2(420, 0)
	box.add_child(err)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 240)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var send := func() -> void:
		var msg := StrifeAcc.request_friend(name_box.text)
		var ok := msg == ""
		_fill_friends(list, err, "친구 요청을 보냈습니다." if ok else msg, ok)
		if not ok:
			Sfx.play("error")
	name_box.text_submitted.connect(func(_t): send.call())
	box.add_child(_menu_button("친구 요청", send))
	_fill_friends(list, err, "", true)

func _fill_friends(list: VBoxContainer, err: Label, message: String, ok: bool) -> void:
	err.text = message
	err.add_theme_color_override("font_color", Color(0.65, 0.9, 0.55) if ok else Color(1, 0.45, 0.35))
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_friend_heading(list, "받은 요청")
	var incoming := StrifeAcc.request_names()
	if incoming.is_empty():
		_friend_heading(list, "받은 요청 없음")
	for who in incoming:
		var from_name := str(who)
		list.add_child(_friend_action("%s 수락" % from_name, from_name, "accept", list, err))
		list.add_child(_friend_action("%s 거절" % from_name, from_name, "decline", list, err))
	_friend_heading(list, "친구")
	var friends := StrifeAcc.friend_names()
	if friends.is_empty():
		_friend_heading(list, "친구 없음")
	for who in friends:
		var fname := str(who)
		list.add_child(_friend_action("%s  파티 초대" % fname, fname, "party", list, err))
	var waiting := StrifeAcc.outgoing_names()
	if not waiting.is_empty():
		_friend_heading(list, "응답 대기  %s" % ", ".join(waiting))

func _friend_heading(list: VBoxContainer, text: String) -> void:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))
	list.add_child(lab)

func _friend_action(text: String, who: String, action: String, list: VBoxContainer, err: Label) -> Button:
	var id := who
	var act := action
	return _menu_button(text, func():
		var msg := ""
		if act == "accept":
			msg = StrifeAcc.accept_friend(id)
		elif act == "party":
			var state: Dictionary = SolNet.party("state")
			if state.get("party") == null:
				state = SolNet.party("create", {"mode": "normal"})
			if str(state.get("error", "")) != "":
				msg = str(state.get("error", ""))
			else:
				var invited: Dictionary = SolNet.party("invite", {"username": id})
				msg = str(invited.get("error", ""))
				if msg == "":
					_paint_party()
		else:
			msg = StrifeAcc.decline_friend(id)
		var ok := msg == ""
		_fill_friends(list, err, "처리했습니다." if ok else msg, ok)
		if not ok:
			Sfx.play("error")
	)

func _open_party() -> void:
	if not StrifeAcc.logged_in():
		return
	var layer := _overlay("파티")
	var box: VBoxContainer = layer.get_node("Root/Box")
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(460, 0)
	box.add_child(info)
	var roles := HBoxContainer.new()
	box.add_child(roles)
	for role_name in ["top", "jungle", "mid", "adc", "support"]:
		var picked: String = role_name
		var btn := _menu_button(picked, func():
			var res: Dictionary = SolNet.party("role", {"role": picked})
			info.text = str(res.get("error", "포지션을 골랐습니다."))
		)
		btn.custom_minimum_size = Vector2(84, 36)
		roles.add_child(btn)
	var members := Label.new()
	members.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(members)
	var refresh := func() -> void:
		var state: Dictionary = SolNet.party("state")
		if str(state.get("error", "")) != "":
			info.text = str(state.get("error", ""))
			return
		var party = state.get("party")
		if party == null:
			info.text = "파티가 없습니다. 모드를 고르면 파티가 만들어집니다."
			members.text = ""
			return
		var party_row: Dictionary = party
		var lines: PackedStringArray = []
		var group = state.get("members", [])
		if group is Array:
			for item in group:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = item
				lines.append("%s  %s  %s" % [str(row.get("username", "")), str(row.get("role", "")), str(row.get("member_status", ""))])
		members.text = "\n".join(lines)
		info.text = "모드 %s  ·  %s" % [str(party_row.get("mode", "")), str(party_row.get("status", ""))]
		var live = state.get("match")
		if live is Dictionary and str(live.get("host", "")) != "":
			_enter_match(str(live.get("host", "")), int(live.get("port", 7777)))
			layer.queue_free()
	for mode_name in ["duel", "ranked", "normal", "swift"]:
		var mode_pick: String = mode_name
		box.add_child(_menu_button(mode_pick, func():
			var res: Dictionary = SolNet.party("create", {"mode": mode_pick})
			info.text = str(res.get("error", "파티를 만들었습니다."))
			refresh.call()
		))
	box.add_child(_menu_button("경기 시작", func():
		var res: Dictionary = SolNet.party("start")
		if str(res.get("error", "")) != "":
			info.text = str(res.get("error", ""))
			Sfx.play("error")
			return
		_enter_match(str(res.get("host", "")), int(res.get("port", 7777)))
		layer.queue_free()
	))
	box.add_child(_menu_button("파티 나가기", func():
		SolNet.party("leave")
		refresh.call()
	))
	refresh.call()

func _enter_match(host: String, port: int) -> void:
	_connect_server(host, port)

func _open_notes() -> void:
	if not StrifeAcc.logged_in():
		return
	var layer := _overlay("알림")
	var box: VBoxContainer = layer.get_node("Root/Box")
	var notes = StrifeAcc.notes()
	var asks = StrifeAcc.request_names()
	if notes.is_empty() and asks.is_empty():
		var empty := Label.new()
		empty.text = "새 알림이 없습니다."
		box.add_child(empty)
		return
	for line in notes:
		var parts = str(line).split("|", false, 2)
		var kind = parts[0] if parts.size() > 0 else ""
		var text = parts[2] if parts.size() > 2 else str(line)
		if kind == "party":
			var party_id: String = text
			var from_name: String = parts[1] if parts.size() > 1 else ""
			box.add_child(_menu_button("%s 파티 참가" % from_name, func():
				SolNet.party("join", {"party_id": party_id})
				layer.queue_free()
				_open_party()
			))
			continue
		var lab := Label.new()
		lab.text = text
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(lab)
	for who in asks:
		var from_name := str(who)
		box.add_child(_menu_button("%s 친구 수락" % from_name, func():
			StrifeAcc.accept_friend(from_name)
			Sfx.play("click")
			layer.queue_free()
			_open_notes()
		))

func _overlay(title_text: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _font()
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -270
	box.offset_top = -300
	box.offset_right = 270
	box.offset_bottom = 300
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	box.add_child(title)
	box.add_child(_menu_button("닫기", func(): layer.queue_free()))
	return layer

func _switch_account() -> void:
	StrifeAcc.logout()
	for child in get_children():
		if child is CanvasLayer:
			child.queue_free()
	_account()

func _apply_icon() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tex = load("res://art/icon.png")
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	img = img.duplicate()
	if img.get_width() != 128:
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	DisplayServer.set_icon(img)

func _logo(size: float) -> TextureRect:
	var mark := TextureRect.new()
	mark.texture = load("res://art/icon.png")
	mark.custom_minimum_size = Vector2(size, size)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return mark

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.78, 0.62, 0.32)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", Color(0.12, 0.08, 0.03))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call()
	)
	return b

func _mode_button(title: String, blurb: String, mode_name: String) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [title, blurb]
	b.custom_minimum_size = Vector2(280, 44)
	b.pressed.connect(func():
		Sfx.play("click")
		var mode_pick := mode_name
		var res: Dictionary = SolNet.party("create", {"mode": mode_pick})
		if str(res.get("error", "")) != "":
			return
		_open_party()
	)
	return b

func _open_roles(mode_name: String) -> void:
	Draft.queue(mode_name)
	role_claim = mode_name != "duel"
	role_wait = 1.1
	taken_roles.clear()
	role_nodes.clear()
	var layer := CanvasLayer.new()
	layer.name = "Roles"
	layer.layer = 7
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _font()
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.06, 0.94)
	root.add_child(dim)
	var title := Label.new()
	title.text = "포지션"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 48
	title.offset_left = -200
	title.offset_right = 200
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	root.add_child(title)
	var hint := Label.new()
	hint.text = "팀이 먼저 고른 자리는 흐려집니다." if mode_name != "duel" else "1대1 라인을 고르세요."
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_top = 100
	hint.offset_left = -280
	hint.offset_right = 280
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.offset_left = -420
	row.offset_right = 420
	row.offset_top = -80
	row.offset_bottom = 80
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	root.add_child(row)
	for item in [["top", "탑"], ["jungle", "정글"], ["mid", "미드"], ["adc", "바텀"], ["support", "바텀"]]:
		var role: String = item[0]
		var hold := Control.new()
		hold.custom_minimum_size = Vector2(120, 150)
		var mark := TextureRect.new()
		mark.name = "mark"
		mark.texture = Marks.icon(role)
		mark.custom_minimum_size = Vector2(96, 96)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold.add_child(mark)
		var cap := Label.new()
		cap.name = "cap"
		cap.text = item[1]
		cap.position = Vector2(0, 104)
		cap.size = Vector2(110, 28)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold.add_child(cap)
		var b := Button.new()
		b.flat = true
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.pressed.connect(_claim_role.bind(role, layer))
		hold.add_child(b)
		row.add_child(hold)
		role_nodes[role] = hold
	root.add_child(_menu_button("뒤로", func():
		role_claim = false
		layer.queue_free()
	))

func _ai_take_role() -> void:
	var open: Array = []
	for role in ["top", "jungle", "mid", "adc", "support"]:
		if not taken_roles.has(role):
			open.append(role)
	if open.size() <= 1:
		role_claim = false
		return
	open.shuffle()
	_fade_role(str(open[0]), "팀원")

func _fade_role(role: String, who: String) -> void:
	taken_roles[role] = who
	var hold: Control = role_nodes.get(role)
	if hold == null:
		return
	hold.modulate = Color(0.35, 0.35, 0.35, 0.55)
	var cap: Label = hold.get_node("cap")
	cap.text = "마감"

func _claim_role(role: String, layer: CanvasLayer) -> void:
	if taken_roles.has(role):
		Sfx.play("error")
		return
	Sfx.play("click")
	role_claim = false
	Draft.set_role(role)
	layer.queue_free()
	get_tree().change_scene_to_file("res://select.tscn")

func _role_name(role: String) -> String:
	return {"top": "탑", "jungle": "정글", "mid": "미드", "adc": "바텀 · 원딜", "support": "바텀 · 서폿"}.get(role, "미드")

func _play() -> void:
	get_tree().change_scene_to_file("res://select.tscn")

func _open_settings() -> void:
	var menu = MenuScript.new()
	add_child(menu)
	menu.closed.connect(func(): Settings.apply_window())

func _font() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	theme.default_font = font
	theme.default_font_size = 18
	return theme
