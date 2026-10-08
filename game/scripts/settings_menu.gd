extends CanvasLayer

signal closed

const GROUPS := [
	["스킬", "q", "별빛의 결속"],
	["스킬", "w", "돌봄의 성소"],
	["스킬", "e", "벽 너머의 길"],
	["스킬", "r", "멈춘 운명"],
	["스킬", "d", "점멸"],
	["스킬", "f", "회복"],
	["스킬", "recall", "귀환"],
	["스킬", "shop", "상점"],
	["명령", "stop", "행동 중지"],
	["명령", "amove", "공격 이동"],
	["명령", "champs", "레전드만 공격"],
	["화면", "lock", "시점 고정 전환"],
	["화면", "center", "레전드에게 시점"],
	["아이템", "i1", "아이템 칸 1"],
	["아이템", "i2", "아이템 칸 2"],
	["아이템", "i3", "아이템 칸 3"],
	["아이템", "i4", "아이템 칸 4"],
	["아이템", "i5", "아이템 칸 5"],
	["아이템", "i6", "아이템 칸 6"],
	["아이템", "i7", "아이템 칸 7"],
]

var draft := {}
var snapshot := {}
var waiting := ""
var tab := "general"
var tab_buttons := {}
var content: VBoxContainer
var panel: Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	Settings.block_input = true
	snapshot = Settings.clone()
	draft = Settings.clone()
	Sfx.preview = draft
	_build()

func _exit_tree() -> void:
	Sfx.preview = null
	Sfx.apply_bus()
	Settings.block_input = false

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.theme = _theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_right = 0
	dim.offset_bottom = 0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(980, 620)
	root.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.055, 0.07, 0.97)
	style.border_color = Color(0.83, 0.71, 0.51)
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_top = 14
	box.offset_right = -16
	box.offset_bottom = -14
	panel.add_child(box)
	var title := Label.new()
	title.text = "설정"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78))
	box.add_child(title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	box.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(180, 0)
	body.add_child(tabs)
	for pair in [["general", "일반"], ["game", "게임"], ["mouse", "마우스"], ["controls", "단축키"], ["spell", "주문"], ["video", "화질"], ["sound", "소리"], ["interface", "인터페이스"]]:
		var b := Button.new()
		b.text = pair[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_show_tab.bind(pair[0]))
		tabs.add_child(b)
		tab_buttons[pair[0]] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(footer)
	footer.add_child(_button("확인", _ok, true))
	footer.add_child(_button("적용", _apply, false))
	footer.add_child(_button("취소", _cancel, false))
	_layout()
	get_viewport().size_changed.connect(_layout)
	_show_tab("general")

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	panel.size = Vector2(min(1040.0, view.x - 32.0), min(680.0, view.y - 32.0))
	panel.position = (view - panel.size) * 0.5

func _show_tab(id: String) -> void:
	tab = id
	for k in tab_buttons.keys():
		tab_buttons[k].modulate = Color(1, 0.95, 0.8) if k == id else Color(0.65, 0.62, 0.55)
	for child in content.get_children():
		child.queue_free()
	match id:
		"general":
			_page_general()
		"game":
			_page_game()
		"mouse":
			_page_mouse()
		"controls":
			_page_controls()
		"spell":
			_page_spell()
		"video":
			_page_video()
		"sound":
			_page_sound()
		"interface":
			_page_interface()

func _page_general() -> void:
	_heading("일반")
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.text = "이름"
	lab.custom_minimum_size = Vector2(160, 0)
	row.add_child(lab)
	var edit := LineEdit.new()
	edit.text = str(draft["name"])
	edit.custom_minimum_size = Vector2(240, 36)
	edit.text_changed.connect(func(t): draft["name"] = t.left(16))
	row.add_child(edit)
	content.add_child(row)
	_note("설정은 이 기기에 저장된다. 인터넷 없이 그대로 남는다.")
	_note("시전 방식, 화면, 소리, 단축키는 옆 항목에서 바꾼다.")

func _page_controls() -> void:
	_heading("조작")
	var group := ButtonGroup.new()
	_radio(group, "normal", "일반 시전", "키를 누른 뒤 좌클릭으로 확정한다. 우클릭은 취소하고 이동한다.")
	_radio(group, "indicator", "표시 후 시전", "키를 누르고 있는 동안 범위를 보고, 손을 떼면 시전한다.")
	_radio(group, "quick", "빠른 시전", "키를 누르는 순간 커서 위치에 시전한다.")
	var last := ""
	for row in GROUPS:
		if row[0] != last:
			last = row[0]
			_heading(last)
		var line := Button.new()
		var code := int(draft["binds"][row[1]])
		var shown := "키 입력" if waiting == row[1] else Settings.key_label(code)
		line.text = "%s    %s" % [row[2], shown]
		line.alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.pressed.connect(_arm_rebind.bind(row[1]))
		content.add_child(line)
	_note("왼쪽 클릭은 스킬 확정과 상점을 고른다. 오른쪽 클릭은 이동과 공격이다.")
	_note("Shift+우클릭, 또는 A 후 좌클릭은 공격 이동이다.")
	_note("G를 짧게 누르면 주의. 길게 누르고 방향을 고르면 위험, 적 사라짐, 도와주세요, 갑니다.")

func _page_game() -> void:
	_heading("게임")
	_check("camera_locked", "시작할 때 시점 고정")
	_check("auto_attack", "자동 공격")
	_check("show_bars", "체력 바 표시")
	_check("damage_numbers", "피해·회복 수치")
	_check("shake", "화면 흔들림")
	_check("show_range", "기본 공격 사거리 표시")
	_note("C를 누르고 있는 동안에는 레전드만 공격 대상이 된다.")

func _page_mouse() -> void:
	_heading("마우스")
	_check("attack_left", "좌클릭을 공격 이동으로 사용")
	_check("invert_drag", "카메라 드래그 반전")
	_slider("mouse_pan", "카메라 이동 속도", 2.0, 18.0)
	_note("휠 버튼(가운데 버튼)을 누른 채 끌면 시점이 움직인다. 시점 고정 중에도 끄는 동안만 풀린다.")
	_note("우클릭은 이동, 적 우클릭은 공격이다. Shift+우클릭은 공격 이동이다.")

func _page_spell() -> void:
	_heading("주문")
	var group := ButtonGroup.new()
	_radio(group, "normal", "일반 시전", "키를 누른 뒤 좌클릭으로 확정한다.")
	_radio(group, "indicator", "표시 후 시전", "누르고 있는 동안 범위를 보고, 떼면 시전한다.")
	_radio(group, "quick", "빠른 시전", "누르는 즉시 커서 위치에 시전한다.")
	_heading("스킬별")
	_spell_row("spell_q", "Q 별빛의 결속")
	_spell_row("spell_w", "W 돌봄의 성소")
	_spell_row("spell_e", "E 벽 너머의 길")
	_spell_row("spell_r", "R 멈춘 운명")
	_note("개별 항목을 '전체 설정'으로 두면 위의 시전 방식을 따른다.")

func _spell_row(key: String, label: String) -> void:
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.text = label
	lab.custom_minimum_size = Vector2(180, 0)
	row.add_child(lab)
	var opt := OptionButton.new()
	opt.add_item("전체 설정", 0)
	opt.add_item("일반 시전", 1)
	opt.add_item("표시 후 시전", 2)
	opt.add_item("빠른 시전", 3)
	var cur := str(draft[key])
	opt.selected = {"follow": 0, "normal": 1, "indicator": 2, "quick": 3}.get(cur, 0)
	opt.item_selected.connect(func(i):
		draft[key] = ["follow", "normal", "indicator", "quick"][i]
	)
	row.add_child(opt)
	content.add_child(row)

func _option(key: String, label: String, items: Array) -> void:
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.custom_minimum_size = Vector2(160, 0)
	lab.text = label
	row.add_child(lab)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(260, 0)
	var current := str(draft[key])
	var sel := 0
	for i in items.size():
		opt.add_item(items[i][1])
		if str(items[i][0]) == current:
			sel = i
	opt.selected = sel
	opt.item_selected.connect(func(i):
		draft[key] = items[i][0]
	)
	row.add_child(opt)
	content.add_child(row)

func _page_video() -> void:
	_heading("화질")
	var quality := OptionButton.new()
	quality.add_item("낮음", 0)
	quality.add_item("보통", 1)
	quality.add_item("높음", 2)
	quality.add_item("매우 높음", 3)
	quality.selected = {"low": 0, "medium": 1, "high": 2, "ultra": 3}.get(str(draft["quality"]), 2)
	quality.item_selected.connect(func(i):
		draft["quality"] = ["low", "medium", "high", "ultra"][i]
		if i == 0:
			draft["shadows"] = false
			draft["aa_mode"] = "fxaa"
			draft["shadow_quality"] = "low"
			draft["ao"] = false
			draft["gi_mode"] = "off"
			draft["reflections"] = false
			draft["particles"] = "low"
			draft["fog"] = false
		elif i == 1:
			draft["shadows"] = true
			draft["aa_mode"] = "fxaa"
			draft["shadow_quality"] = "low"
			draft["ao"] = false
			draft["gi_mode"] = "off"
			draft["reflections"] = false
			draft["particles"] = "low"
			draft["fog"] = false
		elif i == 2:
			draft["shadows"] = true
			draft["aa_mode"] = "fxaa"
			draft["shadow_quality"] = "medium"
			draft["ao"] = false
			draft["gi_mode"] = "off"
			draft["reflections"] = false
			draft["particles"] = "low"
			draft["fog"] = false
		else:
			draft["shadows"] = true
			draft["aa_mode"] = "fxaa"
			draft["shadow_quality"] = "high"
			draft["ao"] = false
			draft["gi_mode"] = "off"
			draft["reflections"] = false
			draft["particles"] = "low"
			draft["fog"] = false
		_show_tab("video")
	)
	content.add_child(quality)
	_note("프리셋을 고르면 아래 항목이 함께 바뀐다. 개별 항목은 따로 조절할 수 있다.")
	_heading("표시")
	var window := OptionButton.new()
	window.add_item("창 모드", 0)
	window.add_item("테두리 없는 전체 화면", 1)
	window.add_item("전체 화면", 2)
	window.selected = {"window": 0, "borderless": 1, "fullscreen": 2}.get(str(draft["window_mode"]), 1)
	window.item_selected.connect(func(i):
		draft["window_mode"] = ["window", "borderless", "fullscreen"][i]
		draft["fullscreen"] = i == 2
	)
	content.add_child(window)
	var res := OptionButton.new()
	for item in ["1280x720", "1600x900", "1920x1080", "2560x1440"]:
		res.add_item(item)
	res.selected = ["1280x720", "1600x900", "1920x1080", "2560x1440"].find(str(draft["resolution"]))
	if res.selected < 0:
		res.selected = 1
	res.item_selected.connect(func(i):
		draft["resolution"] = ["1280x720", "1600x900", "1920x1080", "2560x1440"][i]
	)
	content.add_child(res)
	var fps := OptionButton.new()
	var fps_items = [["모니터 동기", 0], ["60 Hz", 60], ["120 Hz", 120], ["144 Hz", 144], ["165 Hz", 165], ["240 Hz", 240]]
	for item in fps_items:
		fps.add_item(item[0])
	var fps_index = 0
	for i in fps_items.size():
		if int(fps_items[i][1]) == int(draft["max_fps"]):
			fps_index = i
	fps.selected = fps_index
	fps.item_selected.connect(func(i):
		draft["max_fps"] = int(fps_items[i][1])
	)
	content.add_child(fps)
	_check("vsync", "수직 동기화")
	_slider("render_scale", "렌더 배율", 0.5, 2.0)
	_note("1.0이 화면 해상도 그대로다. 1.0보다 작으면 FSR 2로 업스케일하고, 크면 슈퍼샘플링한다.")
	_heading("렌더링")
	_option("aa_mode", "계단 현상 제거", [["off", "끄기"], ["fxaa", "FXAA"], ["taa", "TAA"], ["msaa2", "MSAA 2x"], ["msaa4", "MSAA 4x"], ["msaa8", "MSAA 8x"], ["taa_msaa", "TAA + MSAA 2x"]])
	_check("shadows", "그림자")
	_option("shadow_quality", "그림자 품질", [["low", "낮음 (2K)"], ["medium", "보통 (4K)"], ["high", "높음 (8K)"], ["ultra", "매우 높음 (16K)"]])
	_check("ao", "앰비언트 오클루전")
	_option("gi_mode", "간접광", [["off", "끄기"], ["ssil", "화면 공간 간접광"], ["sdfgi", "SDFGI 전역 조명"]])
	_check("reflections", "화면 공간 반사")
	_check("fog", "볼류메트릭 안개")
	_option("particles", "이펙트", [["off", "끄기"], ["low", "낮음"], ["high", "높음"]])
	_slider("brightness", "밝기", 0.6, 1.6)
	_note("SDFGI는 GPU 부하가 크다. RTX 급 GPU에서 매우 높음 프리셋으로 쓰기를 권한다.")

func _page_sound() -> void:
	_heading("소리")
	_slider("master", "마스터", 0.0, 1.0)
	_slider("sfx", "효과", 0.0, 1.0)
	_slider("music", "배경", 0.0, 1.0)
	var test := _button("효과 들어보기", func(): Sfx.play("q"), false)
	content.add_child(test)

func _page_interface() -> void:
	_heading("인터페이스")
	_slider("hud_scale", "HUD 크기", 0.8, 1.25)
	_check("show_fps", "FPS 표시")
	_note("하단 체력, 마나, 스킬, 이동 속도 숫자의 크기다.")
	_note("체력 바의 흰 잔상은 방금 잃은 피다. 숫자는 방어·마법 저항을 계산한 뒤의 값이다.")

func _heading(text: String) -> void:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 20)
	lab.add_theme_color_override("font_color", Color(0.83, 0.71, 0.51))
	content.add_child(lab)

func _note(text: String) -> void:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_color_override("font_color", Color(0.70, 0.66, 0.58))
	lab.custom_minimum_size = Vector2(560, 0)
	content.add_child(lab)

func _check(key: String, label: String) -> void:
	var box := CheckBox.new()
	box.text = label
	box.button_pressed = bool(draft[key])
	box.toggled.connect(func(on): draft[key] = on)
	content.add_child(box)

func _slider(key: String, label: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.custom_minimum_size = Vector2(120, 0)
	var value := float(draft[key])
	lab.text = "%s  %.2f" % [label, value]
	row.add_child(lab)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(280, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v):
		draft[key] = v
		lab.text = "%s  %.2f" % [label, v]
		Sfx.preview = draft
		Sfx.apply_bus()
	)
	row.add_child(slider)
	content.add_child(row)

func _radio(group: ButtonGroup, id: String, title: String, desc: String) -> void:
	var box := CheckBox.new()
	box.text = "%s — %s" % [title, desc]
	box.button_group = group
	box.button_pressed = str(draft["cast_mode"]) == id
	box.toggled.connect(func(on):
		if on:
			draft["cast_mode"] = id
	)
	content.add_child(box)

func _button(text: String, cb: Callable, gold: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(108, 36)
	if gold:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.78, 0.62, 0.32)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color(0.1, 0.07, 0.03))
	b.pressed.connect(cb)
	return b

func _arm_rebind(action: String) -> void:
	waiting = action
	_show_tab("controls")

func _ok() -> void:
	_apply()
	_close()

func _apply() -> void:
	Settings.replace(draft)
	snapshot = Settings.clone()
	draft = Settings.clone()
	Sfx.preview = draft
	Sfx.apply_bus()
	Settings.apply_window()
	Sfx.play("click")

func _cancel() -> void:
	Sfx.preview = null
	Sfx.apply_bus()
	Settings.apply_window()
	_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if waiting != "" and event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode != KEY_ESCAPE and key.keycode != KEY_TAB:
			for k in draft["binds"].keys():
				if k != waiting and int(draft["binds"][k]) == key.keycode:
					draft["binds"][k] = draft["binds"][waiting]
			draft["binds"][waiting] = key.keycode
		waiting = ""
		_show_tab("controls")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()

func _theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	theme.default_font = font
	theme.default_font_size = 16
	return theme
