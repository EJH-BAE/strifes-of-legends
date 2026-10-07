extends Node

const MenuScript = preload("res://scripts/settings_menu.gd")
const Marks = preload("res://scripts/marks.gd")

var cam: Camera3D
var spin := 0.0
var role_claim := false
var role_wait := 1.0
var taken_roles := {}
var role_nodes := {}

func _ready() -> void:
	print("VITAL ", preload("res://scripts/health.gd").new().self_test())
	print("DISPLAY ", DisplayServer.get_name())
	Settings.apply_window()
	_apply_icon()
	var direct = DisplayServer.get_name() == "headless"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shot="):
			direct = true
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

func _menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_right = 0
	root.offset_bottom = 0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _font()
	layer.add_child(root)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 48
	center.offset_top = 28
	center.offset_right = -48
	center.offset_bottom = -28
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	center.add_theme_constant_override("separation", 8)
	root.add_child(center)
	center.add_child(_logo(64))
	var kicker := Label.new()
	kicker.text = "STRIFES OF LEGENDS"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	kicker.add_theme_font_size_override("font_size", 32)
	kicker.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	center.add_child(kicker)
	var sub := Label.new()
	sub.text = "분쟁의 전설"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	center.add_child(sub)
	var name_label := Label.new()
	name_label.text = StrifeAcc.current() if StrifeAcc.logged_in() else Settings.player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(name_label)
	Settings.changed.connect(func(): name_label.text = Settings.player_name)
	var mode := Label.new()
	mode.text = "The Legends' Battleground  ·  전설의 전장"
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))
	center.add_child(mode)
	var patch_label := Label.new()
	patch_label.text = "버전 확인"
	patch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	patch_label.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))
	center.add_child(patch_label)
	var patch := preload("res://scripts/patch.gd").new()
	add_child(patch)
	patch.start(self, patch_label)
	var group := Label.new()
	group.text = "일반"
	group.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))
	center.add_child(group)
	center.add_child(_mode_button("AI 대전  1v1", "혼자 상대 한 명", "duel"))
	center.add_child(_mode_button("랭크  5v5", "금지 후 선택", "ranked"))
	center.add_child(_mode_button("일반  5v5", "금지 없이 바로 선택", "normal"))
	var arcade := Label.new()
	arcade.text = "아케이드"
	arcade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arcade.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))
	center.add_child(arcade)
	center.add_child(_mode_button("Swift Strike", "빠른 진행", "swift"))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	center.add_child(foot)
	for pair in [["친구", _open_friends], ["알림", _open_notes], ["설정", _open_settings], ["계정 전환", _switch_account]]:
		var fb := _menu_button(pair[0], pair[1])
		fb.custom_minimum_size = Vector2(120, 36)
		foot.add_child(fb)
	var quit_b := _menu_button("종료", func(): get_tree().quit())
	quit_b.custom_minimum_size = Vector2(90, 36)
	foot.add_child(quit_b)

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
		_friend_heading(list, str(who))
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
		var msg := StrifeAcc.accept_friend(id) if act == "accept" else StrifeAcc.decline_friend(id)
		var ok := msg == ""
		_fill_friends(list, err, "처리했습니다." if ok else msg, ok)
		if not ok:
			Sfx.play("error")
	)

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
		var text = parts[2] if parts.size() > 2 else str(line)
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
		_open_roles(mode_name)
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
