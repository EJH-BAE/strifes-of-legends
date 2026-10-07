extends Control

const Legends = preload("res://scripts/legends.gd")
const Marks = preload("res://scripts/marks.gd")

const GOLD := Color(0.83, 0.71, 0.42)
const GOLD_DIM := Color(0.55, 0.46, 0.28)
const NAVY := Color(0.05, 0.07, 0.10, 0.96)
const BLUE := Color(0.18, 0.55, 0.86)
const RED := Color(0.86, 0.28, 0.24)

enum Phase { BAN, PICK, LOCKED }

var phase: int = Phase.BAN
var timer := 18.0
var role_filter := "all"
var query := ""
var hover_id := ""
var pick_id := ""
var player_ban := ""
var bans: Array = []
var chosen_id := ""
var ai_wait := 8.0
const TURN_LIMIT := 30.0
var grid: GridContainer
var search_box: LineEdit
var timer_lab: Label
var phase_lab: Label
var lock_btn: Button
var splash_name: Label
var splash_title: Label
var splash_role: Label
var splash_art: ColorRect
var splash_face: TextureRect
var skill_labs: Array = []
var portraits: Dictionary = {}
var cards: Dictionary = {}
var blue_slots: Array = []
var red_slots: Array = []
var ban_slots: Array = []
var chat_lab: Label
var ticking := true

func _ready() -> void:
	Draft.begin_series()
	set_anchors_preset(PRESET_FULL_RECT)
	theme = _font()
	_build()
	_refresh_grid()
	_refresh_preview()
	_sync_turn(false)
	Sfx.play("chime")

func _font() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	theme.default_font = font
	theme.default_font_size = 15
	return theme

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.07)
	add_child(bg)
	var veil := ColorRect.new()
	veil.set_anchors_preset(PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.03, 0.05, 0.35)
	add_child(veil)
	_team_column(true)
	_team_column(false)
	_center()
	_bottom()
	chat_lab = Label.new()
	chat_lab.position = Vector2(24, 820)
	chat_lab.size = Vector2(360, 64)
	chat_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat_lab.add_theme_color_override("font_color", Color(0.72, 0.7, 0.62))
	chat_lab.add_theme_font_size_override("font_size", 13)
	chat_lab.text = "팀 채팅  ·  레전드를 고르고 선택 확정을 누르세요."
	add_child(chat_lab)

func _panel(pos: Vector2, size: Vector2, fill: Color) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p

func _team_column(is_blue: bool) -> void:
	var x := 16.0 if is_blue else 1288.0
	var accent := BLUE if is_blue else RED
	var panel := _panel(Vector2(x, 16), Vector2(296, 690), NAVY)
	var head := Label.new()
	head.text = "푸른 팀" if is_blue else "붉은 팀"
	head.position = Vector2(14, 8)
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", accent)
	panel.add_child(head)
	var ban_row := HBoxContainer.new()
	ban_row.position = Vector2(12, 40)
	ban_row.add_theme_constant_override("separation", 6)
	panel.add_child(ban_row)
	for i in 5:
		var cell := _mini_portrait()
		cell.set_meta("team", "blue" if is_blue else "red")
		cell.set_meta("ban", i)
		ban_row.add_child(cell)
		ban_slots.append(cell)
	var y := 96.0
	var roles = ["탑", "정글", "미드", "원딜", "서폿"]
	for i in 5:
		var slot := _summoner_slot(is_blue, i, roles[i])
		slot.position = Vector2(10, y)
		panel.add_child(slot)
		if is_blue:
			blue_slots.append(slot)
		else:
			red_slots.append(slot)
		y += 112.0

func _mini_portrait() -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(48, 48)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.modulate = Color(0.18, 0.18, 0.2)
	return t

func _summoner_slot(is_blue: bool, index: int, role: String) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(276, 104)
	var frame := ColorRect.new()
	frame.name = "plate"
	frame.size = Vector2(276, 104)
	frame.color = Color(0.08, 0.10, 0.14, 0.9)
	box.add_child(frame)
	var accent := ColorRect.new()
	accent.size = Vector2(4, 104)
	accent.color = BLUE if is_blue else RED
	box.add_child(accent)
	var art := TextureRect.new()
	art.name = "art"
	art.position = Vector2(12, 18)
	art.size = Vector2(68, 68)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(art)
	var user := Label.new()
	user.name = "user"
	user.position = Vector2(90, 16)
	user.size = Vector2(176, 22)
	user.add_theme_font_size_override("font_size", 15)
	user.add_theme_color_override("font_color", Color(0.92, 0.9, 0.82))
	if is_blue and index == 4:
		user.text = Draft.player_name()
	else:
		user.text = "대기 중"
	box.add_child(user)
	var legend := Label.new()
	legend.name = "legend"
	legend.position = Vector2(90, 40)
	legend.size = Vector2(176, 22)
	legend.add_theme_color_override("font_color", GOLD)
	legend.text = role
	box.add_child(legend)
	var spell := Label.new()
	spell.name = "spell"
	spell.position = Vector2(90, 66)
	spell.size = Vector2(176, 22)
	spell.add_theme_font_size_override("font_size", 12)
	spell.add_theme_color_override("font_color", Color(0.62, 0.6, 0.52))
	spell.text = "점멸  ·  회복"
	box.add_child(spell)
	return box

func _center() -> void:
	var panel := _panel(Vector2(328, 16), Vector2(944, 690), Color(0.06, 0.07, 0.10, 0.94))
	phase_lab = Label.new()
	phase_lab.position = Vector2(24, 10)
	phase_lab.size = Vector2(400, 28)
	phase_lab.add_theme_font_size_override("font_size", 22)
	phase_lab.add_theme_color_override("font_color", GOLD)
	phase_lab.text = "금지 단계"
	panel.add_child(phase_lab)
	timer_lab = Label.new()
	timer_lab.position = Vector2(820, 6)
	timer_lab.size = Vector2(100, 40)
	timer_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_lab.add_theme_font_size_override("font_size", 34)
	timer_lab.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62))
	timer_lab.text = "18"
	panel.add_child(timer_lab)
	var hint := Label.new()
	hint.position = Vector2(24, 40)
	hint.size = Vector2(700, 20)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.55))
	hint.text = "푸른 팀과 붉은 팀이 한 명씩 번갈아 금지하고, 이어서 한 명씩 고릅니다."
	hint.name = "hint"
	panel.add_child(hint)
	var filters := HBoxContainer.new()
	filters.position = Vector2(20, 68)
	filters.add_theme_constant_override("separation", 6)
	panel.add_child(filters)
	for item in [["all", "전체"], ["top", "탑"], ["jungle", "정글"], ["mid", "미드"], ["adc", "원딜"], ["support", "서폿"]]:
		var b := Button.new()
		b.text = item[1]
		b.custom_minimum_size = Vector2(72, 30)
		_gold_btn(b, false)
		b.pressed.connect(_set_role.bind(item[0]))
		filters.add_child(b)
	search_box = LineEdit.new()
	search_box.placeholder_text = "레전드 검색"
	search_box.position = Vector2(700, 68)
	search_box.size = Vector2(220, 30)
	search_box.text_changed.connect(func(t):
		query = t
		_refresh_grid()
	)
	panel.add_child(search_box)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 108)
	scroll.size = Vector2(912, 560)
	panel.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

func _bottom() -> void:
	var panel := _panel(Vector2(16, 716), Vector2(1568, 96), Color(0.05, 0.06, 0.09, 0.96))
	splash_art = ColorRect.new()
	splash_art.position = Vector2(12, 12)
	splash_art.size = Vector2(72, 72)
	splash_art.color = Color(0.2, 0.22, 0.28)
	panel.add_child(splash_art)
	splash_face = TextureRect.new()
	splash_face.position = Vector2(12, 12)
	splash_face.size = Vector2(72, 72)
	splash_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(splash_face)
	splash_name = Label.new()
	splash_name.position = Vector2(96, 8)
	splash_name.size = Vector2(360, 28)
	splash_name.add_theme_font_size_override("font_size", 22)
	splash_name.add_theme_color_override("font_color", GOLD)
	panel.add_child(splash_name)
	splash_title = Label.new()
	splash_title.position = Vector2(96, 36)
	splash_title.size = Vector2(420, 20)
	splash_title.add_theme_color_override("font_color", Color(0.78, 0.74, 0.62))
	panel.add_child(splash_title)
	splash_role = Label.new()
	splash_role.position = Vector2(96, 58)
	splash_role.size = Vector2(300, 20)
	splash_role.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82))
	panel.add_child(splash_role)
	var skills := HBoxContainer.new()
	skills.position = Vector2(540, 16)
	skills.add_theme_constant_override("separation", 10)
	panel.add_child(skills)
	for i in 5:
		var lab := Label.new()
		lab.custom_minimum_size = Vector2(150, 64)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 12)
		lab.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))
		skills.add_child(lab)
		skill_labs.append(lab)
	lock_btn = Button.new()
	lock_btn.text = "금지"
	lock_btn.position = Vector2(1360, 22)
	lock_btn.size = Vector2(190, 52)
	_gold_btn(lock_btn, true)
	lock_btn.pressed.connect(_lock)
	panel.add_child(lock_btn)

func _gold_btn(b: Button, big: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.78, 0.62, 0.28) if big else Color(0.16, 0.15, 0.12)
	sb.border_color = GOLD
	sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color(0.9, 0.74, 0.36) if big else Color(0.24, 0.22, 0.16)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_color_override("font_color", Color(0.10, 0.07, 0.03) if big else GOLD)

func _set_role(role: String) -> void:
	role_filter = role
	Sfx.play("click")
	if role != "all" and role != Draft.player_role and Draft.turn_i == 0:
		Draft.set_role(role)
		Draft.begin_series()
		chosen_id = ""
		_sync_turn(false)
		chat_lab.text = "내 포지션  ·  %s" % Legends.role_ko(role)
	elif role != "all" and role != Draft.player_role:
		chat_lab.text = "이번 경기는 이미 %s으로 시작했습니다." % Legends.role_ko(Draft.player_role)
	_refresh_grid()

func _tex(def: Dictionary) -> Texture2D:
	var id = str(def["id"])
	if not portraits.has(id):
		portraits[id] = Legends.portrait(def, 72)
	return portraits[id]

func _refresh_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	cards.clear()
	var rows = Legends.search(query, role_filter)
	for def in rows:
		var id = str(def["id"])
		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(84, 100)
		var btn := TextureButton.new()
		btn.texture_normal = _tex(def)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		btn.size = Vector2(84, 76)
		btn.pressed.connect(_click_card.bind(id))
		btn.mouse_entered.connect(func():
			hover_id = id
			_refresh_preview()
			_paint_slots()
		)
		wrap.add_child(btn)
		var name_lab := Label.new()
		name_lab.name = "name"
		name_lab.text = str(def["name"])
		name_lab.position = Vector2(0, 76)
		name_lab.size = Vector2(84, 22)
		name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lab.add_theme_font_size_override("font_size", 11)
		name_lab.add_theme_color_override("font_color", Color(0.9, 0.86, 0.74))
		name_lab.visible = false
		wrap.add_child(name_lab)
		var mark := ColorRect.new()
		mark.name = "mark"
		mark.size = Vector2(84, 4)
		mark.color = GOLD
		mark.visible = false
		wrap.add_child(mark)
		grid.add_child(wrap)
		cards[id] = wrap
	_paint_cards()

func _paint_cards() -> void:
	var used = Draft.taken_ids()
	for id in cards.keys():
		var wrap: Control = cards[id]
		var mark = wrap.get_node_or_null("mark")
		var taken = used.has(id)
		wrap.modulate = Color(0.28, 0.28, 0.3) if taken else Color.WHITE
		if mark:
			mark.visible = (id == hover_id or id == chosen_id) and not taken
		var name_lab = wrap.get_node_or_null("name")
		if name_lab:
			name_lab.visible = (id == hover_id or id == chosen_id) and not taken

func _click_card(id: String) -> void:
	if phase == Phase.LOCKED or not Draft.player_turn():
		if phase != Phase.LOCKED:
			chat_lab.text = "지금은 상대 차례입니다." if str(Draft.current_turn().get("team", "")) == "red" else "지금은 다른 소환사 차례입니다."
		return
	if Draft.taken_ids().has(id):
		Sfx.play("error")
		return
	Sfx.play("click")
	chosen_id = id
	hover_id = id
	if str(Draft.current_turn().get("phase", "")) == "ban":
		player_ban = id
	else:
		pick_id = id
	_paint_cards()
	_refresh_preview()
	_paint_slots()

func _paint_slots() -> void:
	_paint_side(blue_slots, Draft.blue, "blue")
	_paint_side(red_slots, Draft.red, "red")
	_paint_bans()
	var turn = Draft.current_turn()
	for i in blue_slots.size():
		_mark_turn(blue_slots[i], turn.get("team", "") == "blue" and int(turn.get("index", -1)) == i)
	for i in red_slots.size():
		_mark_turn(red_slots[i], turn.get("team", "") == "red" and int(turn.get("index", -1)) == i)

func _paint_side(slots: Array, rows: Array, _team: String) -> void:
	for i in slots.size():
		if i >= rows.size():
			continue
		var data = rows[i]
		var slot: Control = slots[i]
		slot.get_node("user").text = str(data["username"])
		var locked = str(data.get("legend", ""))
		var ours = bool(data.get("player", false)) and Draft.player_turn()
		var face_id = locked
		var show_name = locked != ""
		if face_id == "" and ours and hover_id != "":
			face_id = hover_id
			show_name = true
		elif face_id == "" and ours and chosen_id != "":
			face_id = chosen_id
			show_name = true
		var role_name = Legends.role_ko(str(data["role"]))
		if face_id == "":
			slot.get_node("art").texture = Marks.icon(str(data["role"]))
			slot.get_node("legend").text = role_name
		else:
			var def = Legends.by_id(face_id)
			slot.get_node("art").texture = _tex(def) if not def.is_empty() else Marks.icon(str(data["role"]))
			if show_name and not def.is_empty():
				slot.get_node("legend").text = str(def["name"])
			else:
				slot.get_node("legend").text = role_name

func _mark_turn(slot: Control, active: bool) -> void:
	var plate = slot.get_node_or_null("plate")
	if plate == null:
		return
	plate.color = Color(0.22, 0.18, 0.08, 0.95) if active else Color(0.08, 0.10, 0.14, 0.9)

func _refresh_preview() -> void:
	var id = hover_id
	if id == "":
		id = pick_id if pick_id != "" else player_ban
	if id == "":
		splash_name.text = ""
		splash_title.text = ""
		splash_role.text = ""
		if splash_face:
			splash_face.texture = null
		return
	var def = Legends.by_id(id)
	if def.is_empty():
		return
	if splash_face:
		splash_face.texture = _tex(def)
	var tint: Color = def["tint"]
	splash_art.color = tint
	splash_name.text = str(def["name"])
	splash_title.text = str(def["title"])
	splash_role.text = "%s  ·  %s" % [Legends.role_ko(str(def["role"])), str(def["p_name"])]
	var keys = ["p", "q", "w", "e", "r"]
	var labels = ["P", "Q", "W", "E", "R"]
	for i in 5:
		var key = keys[i]
		skill_labs[i].text = "%s  %s\n%s" % [labels[i], str(def[key + "_name"]), str(def[key + "_desc"])]

func _process(delta: float) -> void:
	if not ticking:
		return
	timer -= delta
	if timer_lab:
		timer_lab.text = str(maxi(0, int(ceil(timer))))
	if not Draft.player_turn() and Draft.turn_limit - timer >= ai_wait:
		_timeout()
	elif timer <= 0.0:
		_timeout()

func _timeout() -> void:
	if Draft.current_turn().is_empty():
		_finish_pick()
		return
	var id = chosen_id if Draft.player_turn() and chosen_id != "" and not Draft.taken_ids().has(chosen_id) else Draft.choose_auto()
	_commit(id)

func _lock() -> void:
	if not Draft.player_turn():
		Sfx.play("error")
		chat_lab.text = "당신의 차례가 아닙니다."
		return
	if chosen_id == "" or Draft.taken_ids().has(chosen_id):
		Sfx.play("error")
		chat_lab.text = "레전드를 먼저 고르세요."
		return
	_commit(chosen_id)

func _commit(legend_id: String) -> void:
	if not Draft.commit_turn(legend_id):
		Sfx.play("error")
		return
	chosen_id = ""
	bans = Draft.bans.duplicate()
	Sfx.play("click")
	_paint_cards()
	_sync_turn(true)
	if Draft.roster_ready:
		_finish_pick()

func _sync_turn(announce: bool) -> void:
	var turn = Draft.current_turn()
	if turn.is_empty():
		return
	var picking = str(turn["phase"]) == "pick"
	phase = Phase.PICK if picking else Phase.BAN
	var who = Draft.turn_slot()
	var side = "푸른 팀" if str(turn["team"]) == "blue" else "붉은 팀"
	var role = Legends.role_ko(str(who.get("role", "")))
	var act = "선택" if picking else "금지"
	phase_lab.text = "%s 단계  ·  %s %s" % [act, side, role]
	lock_btn.text = "선택 확정" if picking else "금지"
	lock_btn.disabled = not Draft.player_turn()
	if Draft.player_turn():
		timer = Draft.turn_limit
		chat_lab.text = "당신의 차례입니다. %d초 안에 %s하세요." % [int(Draft.turn_limit), act]
		if announce:
			Sfx.play("chime")
	else:
		timer = Draft.turn_limit
		ai_wait = randf_range(4.0, 8.0) if Draft.mode == "swift" else randf_range(6.0, 12.0)
		chat_lab.text = "%s %s  ·  %d초" % [side, str(who.get("username", "")), int(Draft.turn_limit)]
	_paint_slots()

func _paint_bans() -> void:
	for i in 5:
		var blue_ban = ""
		var red_ban = ""
		if i < Draft.blue.size():
			blue_ban = str(Draft.blue[i].get("ban", ""))
		if i < Draft.red.size():
			red_ban = str(Draft.red[i].get("ban", ""))
		_show_ban(ban_slots[i], blue_ban)
		_show_ban(ban_slots[i + 5], red_ban)

func _show_ban(cell: TextureRect, legend_id: String) -> void:
	var def = Legends.by_id(legend_id)
	if def.is_empty():
		cell.texture = null
		cell.modulate = Color(0.18, 0.18, 0.2)
		return
	cell.texture = _tex(def)
	cell.modulate = Color(0.45, 0.45, 0.48)

func _finish_pick() -> void:
	phase = Phase.LOCKED
	ticking = false
	lock_btn.disabled = true
	lock_btn.text = "준비 중"
	phase_lab.text = "대열 구성"
	timer_lab.text = "0"
	_paint_slots()
	chat_lab.text = "양 팀 레전드가 확정되었습니다. 전장으로 이동합니다."
	Sfx.play("r")
	await get_tree().create_timer(1.6).timeout
	get_tree().change_scene_to_file("res://match.tscn")

func _reveal_teams() -> void:
	for i in 5:
		_fill_slot(blue_slots[i], Draft.blue[i])
		_fill_slot(red_slots[i], Draft.red[i])

func _fill_slot(slot: Control, data: Dictionary) -> void:
	var def = Legends.by_id(str(data["legend"]))
	slot.get_node("user").text = str(data["username"])
	if def.is_empty():
		return
	slot.get_node("legend").text = "%s  ·  %s" % [str(def["name"]), Legends.role_ko(str(data["role"]))]
	slot.get_node("art").texture = _tex(def)
