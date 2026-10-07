extends RefCounted

static var _rows: Array = []
static var _map: Dictionary = {}

static func all() -> Array:
	_ensure()
	return _rows

static func by_id(id: String) -> Dictionary:
	_ensure()
	if _map.has(id):
		return _map[id]
	return {}

static func by_name(uname: String) -> Dictionary:
	_ensure()
	for row in _rows:
		if str(row["name"]) == uname:
			return row
	return {}

static func by_role(role: String) -> Array:
	_ensure()
	if role == "" or role == "all":
		return _rows.duplicate()
	var out: Array = []
	for row in _rows:
		if str(row["role"]) == role:
			out.append(row)
	return out

static func search(text: String, role: String) -> Array:
	_ensure()
	var q = text.strip_edges()
	var out: Array = []
	for row in _rows:
		if role != "" and role != "all" and str(row["role"]) != role:
			continue
		if q != "" and not str(row["name"]).contains(q) and not str(row["title"]).contains(q) and not str(row["id"]).contains(q.to_lower()):
			continue
		out.append(row)
	return out

static func kit(name: String) -> Dictionary:
	match name:
		"enchanter":
			return {
				"q": {"kind": "bolt", "reach": 900.0, "cd": 8.0, "cost": 50, "dmg": 70.0, "stun": 0.0},
				"w": {"kind": "shield", "reach": 700.0, "cd": 10.0, "cost": 60, "heal": 110.0},
				"e": {"kind": "haste", "reach": 650.0, "cd": 12.0, "cost": 50},
				"r": {"kind": "aoe", "reach": 900.0, "cd": 100.0, "cost": 100, "dmg": 180.0, "stun": 1.5},
			}
		"warlord":
			return {
				"q": {"kind": "leap", "reach": 350.0, "cd": 8.0, "cost": 40, "dmg": 95.0},
				"w": {"kind": "shield", "reach": 0.0, "cd": 12.0, "cost": 50, "heal": 90.0},
				"e": {"kind": "smash", "reach": 260.0, "cd": 10.0, "cost": 40, "dmg": 85.0, "stun": 0.75},
				"r": {"kind": "execute", "reach": 420.0, "cd": 90.0, "cost": 100, "dmg": 220.0},
			}
		"spear":
			return {
				"q": {"kind": "snipe", "reach": 1100.0, "cd": 9.0, "cost": 50, "dmg": 105.0},
				"w": {"kind": "dash", "reach": 400.0, "cd": 10.0, "cost": 30},
				"e": {"kind": "cone", "reach": 500.0, "cd": 11.0, "cost": 45, "dmg": 90.0, "stun": 0.4},
				"r": {"kind": "charge", "reach": 800.0, "cd": 85.0, "cost": 100, "dmg": 200.0, "stun": 1.2},
			}
		"axe":
			return {
				"q": {"kind": "leap", "reach": 500.0, "cd": 8.0, "cost": 40, "dmg": 110.0},
				"w": {"kind": "smash", "reach": 220.0, "cd": 7.0, "cost": 35, "dmg": 75.0},
				"e": {"kind": "slowfield", "reach": 600.0, "cd": 12.0, "cost": 50, "dmg": 45.0},
				"r": {"kind": "leap", "reach": 700.0, "cd": 80.0, "cost": 100, "dmg": 250.0, "stun": 1.0},
			}
		"assassin":
			return {
				"q": {"kind": "dash", "reach": 450.0, "cd": 7.0, "cost": 40},
				"w": {"kind": "blink", "reach": 400.0, "cd": 14.0, "cost": 50},
				"e": {"kind": "mark", "reach": 550.0, "cd": 8.0, "cost": 40, "dmg": 95.0},
				"r": {"kind": "execute", "reach": 500.0, "cd": 80.0, "cost": 80, "dmg": 280.0},
			}
		"staff":
			return {
				"q": {"kind": "bolt", "reach": 900.0, "cd": 7.0, "cost": 55, "dmg": 115.0},
				"w": {"kind": "aoe", "reach": 850.0, "cd": 10.0, "cost": 70, "dmg": 95.0},
				"e": {"kind": "blink", "reach": 450.0, "cd": 16.0, "cost": 60},
				"r": {"kind": "rain", "reach": 1200.0, "cd": 90.0, "cost": 100, "dmg": 260.0},
			}
		"burst":
			return {
				"q": {"kind": "snipe", "reach": 1000.0, "cd": 6.0, "cost": 50, "dmg": 100.0},
				"w": {"kind": "aoe", "reach": 800.0, "cd": 8.0, "cost": 70, "dmg": 125.0, "stun": 0.6},
				"e": {"kind": "bolt", "reach": 700.0, "cd": 9.0, "cost": 60, "dmg": 85.0, "stun": 1.0},
				"r": {"kind": "rain", "reach": 1000.0, "cd": 80.0, "cost": 100, "dmg": 320.0},
			}
		"bow":
			return {
				"q": {"kind": "snipe", "reach": 1200.0, "cd": 8.0, "cost": 50, "dmg": 105.0},
				"w": {"kind": "volley", "reach": 800.0, "cd": 10.0, "cost": 60, "dmg": 42.0},
				"e": {"kind": "dash", "reach": 400.0, "cd": 12.0, "cost": 30},
				"r": {"kind": "rain", "reach": 1400.0, "cd": 85.0, "cost": 100, "dmg": 240.0},
			}
		"tank":
			return {
				"q": {"kind": "smash", "reach": 280.0, "cd": 8.0, "cost": 40, "dmg": 75.0, "stun": 0.8},
				"w": {"kind": "shield", "reach": 0.0, "cd": 14.0, "cost": 50, "heal": 150.0},
				"e": {"kind": "leap", "reach": 450.0, "cd": 11.0, "cost": 40, "dmg": 85.0},
				"r": {"kind": "aoe", "reach": 500.0, "cd": 90.0, "cost": 100, "dmg": 180.0, "stun": 1.4},
			}
		_:
			return {
				"q": {"kind": "bolt", "reach": 850.0, "cd": 10.0, "cost": 60, "dmg": 120.0, "stun": 1.2},
				"w": {"kind": "heal", "reach": 800.0, "cd": 0.0, "cost": 70, "heal": 90.0, "charges": 2, "recharge": 18.0},
				"e": {"kind": "dash", "reach": 480.0, "cd": 11.0, "cost": 30},
				"r": {"kind": "portal", "reach": 3400.0, "cd": 95.0, "cost": 100},
			}

static func spell(def: Dictionary, slot: String) -> Dictionary:
	var kit_name = str(def.get("kit", "wanderer"))
	var table = kit(kit_name)
	if table.has(slot):
		return table[slot]
	return {}

static func role_ko(role: String) -> String:
	return {"top": "탑", "jungle": "정글", "mid": "미드", "adc": "원딜", "support": "서폿"}.get(role, role)

static func kit_line(kind: String) -> String:
	match kind:
		"bolt":
			return "직선 투사체를 날립니다."
		"snipe":
			return "긴 사거리 투사체로 찌릅니다."
		"heal":
			return "성소를 두어 아군을 회복합니다."
		"shield":
			return "자신 또는 아군을 보호합니다."
		"dash":
			return "짧게 돌진합니다."
		"blink":
			return "짧은 거리를 순간이동합니다."
		"leap":
			return "뛰어올라 착지한 적을 가격합니다."
		"smash":
			return "주변 적을 가격합니다."
		"aoe":
			return "지정 지점에 범위 피해를 줍니다."
		"rain":
			return "하늘에서 떨어뜨려 넓은 폭발을 일으킵니다."
		"portal":
			return "먼 거리를 잇는 통로를 엽니다."
		"execute":
			return "돌진해 잃은 체력에 비례한 피해를 줍니다."
		"cone":
			return "부채꼴로 적을 베거나 밀어냅니다."
		"charge":
			return "돌진한 뒤 강하게 들이받습니다."
		"mark":
			return "대상에게 표식을 새기고 피해를 줍니다."
		"volley":
			return "화살을 부채꼴로 퍼뜨립니다."
		"slowfield":
			return "둔화 지대를 펼칩니다."
		"haste":
			return "아군의 발걸음을 빠르게 합니다."
		_:
			return "전장의 힘을 씁니다."

static func portrait(def: Dictionary, size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var tint: Color = def.get("tint", Color(0.3, 0.3, 0.4))
	var style := str(def.get("style", "wanderer"))
	var skin := Color(0.93, 0.78, 0.66)
	var metal := Color(0.78, 0.8, 0.84)
	var gold := Color(0.9, 0.74, 0.36)
	var cloth := tint
	if style == "warlord" or style == "tank" or style == "axe" or style == "spear":
		skin = Color(0.62, 0.44, 0.32)
	for y in size:
		for x in size:
			var v := float(y) / float(size)
			var u := float(x) / float(size)
			var bg := tint.darkened(0.55).lerp(tint.darkened(0.25), v)
			var edge := min(min(u, 1.0 - u), min(v, 1.0 - v))
			if edge < 0.06:
				bg = Color(0.83, 0.71, 0.42).lerp(bg, edge / 0.06)
			img.set_pixel(x, y, bg)
	var s := float(size)
	_oval(img, s * 0.5, s * 0.78, s * 0.34, s * 0.22, cloth.darkened(0.15))
	_oval(img, s * 0.5, s * 0.62, s * 0.16, s * 0.1, cloth)
	_oval(img, s * 0.5, s * 0.4, s * 0.16, s * 0.2, skin)
	var hue := float(absi(str(def.get("id", "x")).hash()) % 360) / 360.0
	var hair := Color.from_hsv(hue, 0.42, 0.28)
	_oval(img, s * 0.5, s * 0.3, s * 0.17, s * 0.1, hair)
	_oval(img, s * 0.5, s * 0.46, s * 0.018, s * 0.028, skin.darkened(0.25))
	_oval(img, s * 0.5, s * 0.52, s * 0.03, s * 0.01, Color(0.45, 0.22, 0.22))
	match style:
		"wanderer", "staff":
			_hood(img, s, cloth, gold)
			_eyes(img, s, Color(0.45, 0.9, 1.0))
			_staff_tip(img, s, gold)
		"bow":
			_hood(img, s, cloth.darkened(0.1), gold)
			_eyes(img, s, Color(0.95, 0.85, 0.4))
			_bow_arc(img, s, Color(0.45, 0.28, 0.14))
		"assassin":
			_hood(img, s, cloth.darkened(0.35), metal)
			_eyes(img, s, Color(0.8, 0.2, 0.25))
			_daggers(img, s, metal)
		"warlord", "tank":
			_helm(img, s, metal, cloth)
			_eyes(img, s, Color(1.0, 0.35, 0.25))
			_pauldron(img, s, metal)
			if style == "warlord":
				_blade_tip(img, s, metal)
		"spear":
			_helm(img, s, metal, cloth)
			_eyes(img, s, Color(0.7, 0.85, 1.0))
			_spear_tip(img, s, metal)
		"axe":
			_helm(img, s, metal, cloth)
			_eyes(img, s, Color(1.0, 0.55, 0.2))
			_axe_head(img, s, metal)
		_:
			_hood(img, s, cloth, gold)
			_eyes(img, s, gold)
	return ImageTexture.create_from_image(img)

static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, col)

static func _oval(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var x0 := int(cx - rx - 1.0)
	var y0 := int(cy - ry - 1.0)
	var x1 := int(cx + rx + 1.0)
	var y1 := int(cy + ry + 1.0)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var nx: float = (float(x) - cx) / maxf(rx, 0.1)
			var ny: float = (float(y) - cy) / maxf(ry, 0.1)
			if nx * nx + ny * ny <= 1.0:
				_px(img, x, y, col)

static func _line(img: Image, a: Vector2, b: Vector2, thick: float, col: Color) -> void:
	var steps := int(a.distance_to(b) * 2.0) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(maxi(steps, 1)))
		_oval(img, p.x, p.y, thick, thick, col)

static func _hood(img: Image, s: float, cloth: Color, gold: Color) -> void:
	_oval(img, s * 0.5, s * 0.34, s * 0.2, s * 0.24, cloth.darkened(0.2))
	_oval(img, s * 0.5, s * 0.42, s * 0.1, s * 0.12, Color(0.12, 0.1, 0.1))
	_oval(img, s * 0.5, s * 0.18, s * 0.05, s * 0.05, gold)

static func _helm(img: Image, s: float, metal: Color, cloth: Color) -> void:
	_oval(img, s * 0.5, s * 0.32, s * 0.18, s * 0.16, metal.darkened(0.15))
	_oval(img, s * 0.5, s * 0.46, s * 0.12, s * 0.06, Color(0.08, 0.08, 0.08))
	_line(img, Vector2(s * 0.38, s * 0.2), Vector2(s * 0.5, s * 0.08), s * 0.015, metal)
	_line(img, Vector2(s * 0.62, s * 0.2), Vector2(s * 0.5, s * 0.08), s * 0.015, metal)
	_oval(img, s * 0.22, s * 0.58, s * 0.1, s * 0.06, cloth)
	_oval(img, s * 0.78, s * 0.58, s * 0.1, s * 0.06, cloth)

static func _eyes(img: Image, s: float, glow: Color) -> void:
	_oval(img, s * 0.42, s * 0.42, s * 0.035, s * 0.012, glow)
	_oval(img, s * 0.58, s * 0.42, s * 0.035, s * 0.012, glow)

static func _pauldron(img: Image, s: float, metal: Color) -> void:
	_oval(img, s * 0.24, s * 0.66, s * 0.1, s * 0.06, metal)
	_oval(img, s * 0.76, s * 0.66, s * 0.1, s * 0.06, metal)

static func _staff_tip(img: Image, s: float, gold: Color) -> void:
	_line(img, Vector2(s * 0.78, s * 0.86), Vector2(s * 0.86, s * 0.22), s * 0.012, Color(0.35, 0.22, 0.12))
	_oval(img, s * 0.86, s * 0.18, s * 0.045, s * 0.045, gold)

static func _bow_arc(img: Image, s: float, wood: Color) -> void:
	_line(img, Vector2(s * 0.72, s * 0.28), Vector2(s * 0.86, s * 0.5), s * 0.012, wood)
	_line(img, Vector2(s * 0.86, s * 0.5), Vector2(s * 0.72, s * 0.74), s * 0.012, wood)

static func _daggers(img: Image, s: float, metal: Color) -> void:
	_line(img, Vector2(s * 0.18, s * 0.7), Vector2(s * 0.1, s * 0.9), s * 0.012, metal)
	_line(img, Vector2(s * 0.82, s * 0.7), Vector2(s * 0.9, s * 0.9), s * 0.012, metal)

static func _blade_tip(img: Image, s: float, metal: Color) -> void:
	_line(img, Vector2(s * 0.7, s * 0.9), Vector2(s * 0.78, s * 0.48), s * 0.016, metal)

static func _spear_tip(img: Image, s: float, metal: Color) -> void:
	_line(img, Vector2(s * 0.82, s * 0.92), Vector2(s * 0.88, s * 0.2), s * 0.01, Color(0.4, 0.26, 0.14))
	_oval(img, s * 0.88, s * 0.16, s * 0.03, s * 0.06, metal)

static func _axe_head(img: Image, s: float, metal: Color) -> void:
	_line(img, Vector2(s * 0.8, s * 0.9), Vector2(s * 0.8, s * 0.28), s * 0.012, Color(0.4, 0.26, 0.14))
	_oval(img, s * 0.88, s * 0.32, s * 0.07, s * 0.045, metal)

static func _ensure() -> void:
	if not _rows.is_empty():
		return
	_add("kaela", "카엘라", "핏빛 전쟁군주", "top", "warlord", "warlord", 0.42, 0.16, 0.16, 345, 68, 175, 0.68, 1120, 42, 32, 200, "열혈의 돌진", "강철 심장", "파쇄", "제압", "전장의 숨")
	_add("changkeut", "창끝", "창끝의 맹세", "top", "spear", "spear", 0.22, 0.32, 0.48, 345, 66, 175, 0.70, 1100, 40, 32, 280, "꿰뚫기", "도약", "창벽", "돌격", "창술")
	_add("dunga", "둔가", "움직이는 성벽", "top", "tank", "tank", 0.28, 0.26, 0.22, 330, 62, 150, 0.62, 1280, 48, 36, 320, "방패치기", "철벽", "들이받기", "성벽 붕괴", "굳은 살")
	_add("sherdan", "셰르단", "서리 창기병", "top", "spear", "spear", 0.55, 0.72, 0.86, 340, 64, 180, 0.69, 1080, 38, 34, 300, "서리창", "미끄러짐", "냉기 부채", "빙하 돌격", "한기")
	_add("molgrin", "몰그린", "산등성이의 도끼", "top", "axe", "axe", 0.36, 0.28, 0.16, 340, 72, 165, 0.66, 1140, 40, 30, 240, "찍어내리기", "회전 도끼", "균열", "산사태", "벌목")
	_add("teila", "테일라", "붉은 깃발", "top", "warlord", "warlord", 0.62, 0.18, 0.22, 350, 70, 175, 0.70, 1090, 39, 31, 220, "깃발 돌진", "전열", "무릎 꺾기", "전장의 함성", "사기")
	_add("okrin", "오크린", "검은 창", "top", "spear", "spear", 0.12, 0.12, 0.16, 335, 67, 185, 0.68, 1060, 37, 33, 290, "그림자 찌르기", "잠행", "어둠 부채", "종막", "침묵의 창")
	_add("hamel", "하멜", "바위주먹", "top", "tank", "tank", 0.48, 0.40, 0.30, 325, 64, 155, 0.60, 1300, 50, 34, 340, "주먹질", "암석 피부", "지진 도약", "봉우리", "암석화")
	_add("barkan", "바르칸", "낙인의 검", "top", "warlord", "warlord", 0.50, 0.22, 0.10, 340, 71, 170, 0.67, 1110, 41, 30, 210, "낙인", "피의 갑옷", "분쇄", "처형", "검의 갈증")
	_add("grova", "그로바", "황무지 학살자", "top", "axe", "axe", 0.40, 0.18, 0.10, 335, 74, 160, 0.64, 1160, 39, 28, 230, "가르기", "도끼춤", "피바다", "최후의 일격", "학살 본능")
	_add("soopgil", "숲길", "숲길의 추적자", "jungle", "axe", "axe", 0.16, 0.34, 0.22, 340, 70, 175, 0.72, 1060, 38, 32, 260, "추적", "발톱", "올가미", "숲의 심판", "야생")
	_add("noxir", "녹시르", "가시덤불", "jungle", "axe", "axe", 0.18, 0.42, 0.16, 345, 69, 170, 0.71, 1040, 36, 30, 250, "가시 도약", "가시 피부", "뿌리", "만개", "가시")
	_add("garnt", "가른트", "뼈를 가르는 자", "jungle", "axe", "axe", 0.32, 0.14, 0.10, 338, 73, 165, 0.68, 1100, 37, 28, 240, "뼈가르기", "포식", "피 안개", "포효", "포식자")
	_add("silva", "실바", "달그림자 창", "jungle", "spear", "spear", 0.20, 0.28, 0.38, 350, 65, 185, 0.73, 1000, 34, 32, 280, "달창", "은신 도약", "달빛 부채", "만월", "달그림자")
	_add("pera", "페라", "칼날 바람", "jungle", "assassin", "assassin", 0.22, 0.20, 0.28, 355, 68, 150, 0.78, 960, 30, 32, 220, "칼바람", "잔상", "표식", "숨통", "잔상")
	_add("wormlock", "웜록", "벌레굴의 왕", "jungle", "axe", "axe", 0.30, 0.22, 0.12, 330, 71, 160, 0.66, 1180, 42, 30, 260, "굴파기", "껍질", "산성", "군체", "껍질")
	_add("nesira", "네시라", "이끼 창", "jungle", "spear", "spear", 0.24, 0.40, 0.22, 342, 64, 180, 0.70, 1020, 35, 34, 290, "이끼창", "미끄럼", "포자", "만연", "이끼")
	_add("dorn", "도른", "검은 멧돼지", "jungle", "axe", "axe", 0.28, 0.16, 0.12, 335, 75, 155, 0.65, 1200, 40, 28, 230, "돌진", "가죽", "흙먼지", "뿔받이", "야수")
	_add("azel", "아젤", "균열 주술사", "jungle", "staff", "staff", 0.36, 0.16, 0.44, 335, 58, 550, 0.66, 980, 28, 36, 480, "균열구", "균열장", "틈새", "붕괴", "균열")
	_add("velha", "벨하", "밤의 발톱", "jungle", "assassin", "assassin", 0.14, 0.10, 0.18, 360, 70, 145, 0.80, 940, 28, 30, 210, "할퀴기", "밤걸음", "피표식", "숨결 끊기", "밤눈")
	_add("byeolbul", "별불", "별불의 현자", "mid", "staff", "staff", 0.28, 0.20, 0.48, 335, 58, 550, 0.66, 900, 28, 34, 520, "별불", "성운", "유성 걸음", "초신성", "별가루")
	_add("rais", "라이스", "수정 마도사", "mid", "staff", "staff", 0.45, 0.62, 0.78, 330, 56, 560, 0.65, 880, 26, 36, 540, "수정창", "결정장", "굴절", "결정 폭풍", "수정")
	_add("orin", "오린", "서고의 방랑자", "mid", "wanderer", "wanderer", 0.18, 0.16, 0.32, 335, 60, 520, 0.64, 920, 30, 35, 500, "봉인", "서고", "책장 너머", "금서", "기록")
	_add("kasiel", "카시엘", "폭풍의 눈", "mid", "staff", "staff", 0.20, 0.36, 0.62, 335, 57, 555, 0.67, 890, 27, 35, 530, "번개", "뇌운", "섬광", "낙뢰", "정전기")
	_add("veind", "베인드", "그림자 칼날", "mid", "assassin", "assassin", 0.16, 0.14, 0.22, 355, 66, 160, 0.79, 930, 29, 32, 230, "베기", "연막", "숨통 표식", "암살", "그림자")
	_add("lumen", "루멘", "빛의 직조자", "mid", "staff", "staff", 0.78, 0.72, 0.42, 330, 55, 560, 0.66, 870, 25, 36, 550, "광속", "광막", "점멸광", "일식", "광휘")
	_add("skael", "스카엘", "파열의 마녀", "mid", "staff", "burst", 0.52, 0.14, 0.36, 330, 54, 575, 0.64, 860, 24, 38, 560, "파열탄", "붕괴장", "속박구", "파멸", "파열")
	_add("mir", "미르", "거울 너머", "mid", "wanderer", "burst", 0.40, 0.48, 0.62, 335, 56, 540, 0.65, 900, 27, 36, 520, "거울창", "굴절장", "거울 속박", "무한 반사", "거울")
	_add("zephyr", "제피르", "바람의 학자", "mid", "staff", "burst", 0.55, 0.78, 0.70, 340, 55, 580, 0.68, 850, 24, 35, 540, "돌풍", "회오리", "바람 속박", "태풍", "미풍")
	_add("anon", "아논", "이름 없는 칼", "mid", "assassin", "assassin", 0.22, 0.22, 0.24, 360, 69, 150, 0.81, 920, 28, 30, 200, "무명참", "소실", "각인", "종언", "무명")
	_add("hwasal", "화살", "황금 시선", "adc", "bow", "bow", 0.45, 0.36, 0.18, 330, 64, 550, 0.70, 920, 30, 30, 300, "조준", "연사", "구르기", "금화살비", "정확한 눈")
	_add("dokhwasal", "독화살", "독침의 사냥꾼", "adc", "bow", "bow", 0.50, 0.22, 0.16, 330, 66, 550, 0.69, 900, 28, 30, 290, "독침", "독안개", "미끄러짐", "맹독비", "맹독")
	_add("sila", "실라", "은빛 활시위", "adc", "bow", "bow", 0.70, 0.74, 0.80, 335, 63, 560, 0.72, 900, 28, 32, 310, "은시위", "흩뿌리기", "후퇴", "은빛 소나기", "은시위")
	_add("eri", "에리", "바람꽃 사수", "adc", "bow", "bow", 0.72, 0.48, 0.62, 335, 62, 555, 0.74, 880, 26, 31, 320, "꽃화살", "꽃비", "꽃걸음", "만개비", "꽃가루")
	_add("tarsi", "타르시", "기계 석궁", "adc", "bow", "bow", 0.38, 0.40, 0.36, 325, 68, 540, 0.66, 960, 32, 28, 280, "볼트", "산탄", "후진", "포화", "장전")
	_add("lunar", "루나르", "달빛 사냥꾼", "adc", "bow", "bow", 0.30, 0.38, 0.62, 335, 64, 565, 0.71, 910, 28, 32, 300, "달화살", "초승달", "달걸음", "보름달", "달눈")
	_add("felin", "펠린", "검은 깃털", "adc", "bow", "bow", 0.16, 0.16, 0.18, 340, 65, 550, 0.73, 890, 27, 30, 290, "깃털침", "깃털비", "날갯짓", "검은 하늘", "깃털")
	_add("arien", "아리엔", "노을의 명사수", "adc", "bow", "bow", 0.78, 0.42, 0.22, 330, 67, 560, 0.70, 930, 29, 30, 300, "노을살", "잔광", "미끄럼", "황혼우", "노을")
	_add("grail", "그레일", "성배의 화살", "adc", "bow", "bow", 0.82, 0.74, 0.42, 328, 63, 570, 0.68, 940, 30, 32, 330, "성시", "축복탄", "도약", "성배의 비", "축복")
	_add("kinra", "킨라", "푸른 활시위", "adc", "bow", "bow", 0.22, 0.42, 0.58, 332, 65, 555, 0.72, 910, 28, 31, 300, "청시", "파도살", "물결 걸음", "해일비", "조류")
	_add("orbel", "오르벨", "길 위의 음유시인", "support", "wanderer", "wanderer", 0.12, 0.14, 0.24, 330, 67, 500, 0.625, 1020, 56.5, 36.5, 600, "우주의 속박", "수호의 성소", "신비한 걸음", "운명의 소용돌이", "방랑자의 부름")
	_add("suho", "수호", "성소의 파수꾼", "support", "staff", "enchanter", 0.36, 0.14, 0.20, 330, 54, 500, 0.62, 980, 32, 34, 480, "수호탄", "방벽", "전령", "수호의 종", "파수")
	_add("ellen", "엘렌", "이슬의 치유사", "support", "wanderer", "enchanter", 0.42, 0.68, 0.58, 335, 52, 520, 0.64, 960, 30, 36, 500, "이슬침", "이슬막", "이슬걸음", "단비", "이슬")
	_add("mira", "미라", "거울 성녀", "support", "staff", "enchanter", 0.62, 0.70, 0.82, 330, 53, 530, 0.63, 970, 31, 36, 510, "거울빛", "반사막", "잔상 걸음", "거울의 심판", "반사")
	_add("korin", "코린", "종소리 방랑자", "support", "wanderer", "wanderer", 0.20, 0.18, 0.36, 330, 58, 510, 0.63, 1000, 34, 35, 560, "종울림", "성소종", "종걸음", "대종", "여운")
	_add("sepia", "세피아", "잉크의 수호자", "support", "staff", "enchanter", 0.28, 0.20, 0.18, 328, 54, 515, 0.62, 990, 33, 34, 490, "잉크탄", "먹물막", "번짐", "흑서", "잉크")
	_add("aira", "아이라", "별길 안내자", "support", "wanderer", "wanderer", 0.24, 0.22, 0.48, 335, 56, 505, 0.64, 1010, 33, 36, 580, "별길", "별우물", "별걸음", "은하", "길잡이")
	_add("toon", "툰", "온기의 방패", "support", "tank", "tank", 0.62, 0.46, 0.28, 325, 58, 175, 0.60, 1180, 44, 34, 400, "온기 강타", "온기막", "어깨받기", "난로", "온기")
	_add("velora", "벨로라", "자정의 노래", "support", "wanderer", "enchanter", 0.18, 0.12, 0.32, 335, 52, 525, 0.65, 950, 29, 37, 520, "자정탄", "밤안개", "자정 걸음", "자장가", "자정")
	_add("harin", "하린", "흰여우 무당", "support", "wanderer", "wanderer", 0.86, 0.82, 0.74, 332, 55, 500, 0.64, 990, 32, 35, 540, "여우불", "부적", "여우걸음", "혼불", "여우령")
	for row in _rows:
		_map[str(row["id"])] = row

static func _add(id: String, uname: String, title: String, role: String, style: String, kit_name: String, r: float, g: float, b: float, ms: float, ad: float, reach: float, asp: float, hp: float, armor: float, mr: float, mana: float, qn: String, wn: String, en: String, rn: String, pn: String) -> void:
	var tint = Color(r, g, b)
	var spells = kit(kit_name)
	var row = {
		"id": id,
		"name": uname,
		"title": title,
		"role": role,
		"style": style,
		"kit": kit_name,
		"tint": tint,
		"ms": ms,
		"ad": ad,
		"reach": reach,
		"asp": asp,
		"hp": hp,
		"armor": armor,
		"mr": mr,
		"mana": mana,
		"q_name": qn,
		"w_name": wn,
		"e_name": en,
		"r_name": rn,
		"p_name": pn,
		"q_desc": "%s. %s" % [qn, kit_line(str(spells["q"]["kind"]))],
		"w_desc": "%s. %s" % [wn, kit_line(str(spells["w"]["kind"]))],
		"e_desc": "%s. %s" % [en, kit_line(str(spells["e"]["kind"]))],
		"r_desc": "%s. %s" % [rn, kit_line(str(spells["r"]["kind"]))],
		"p_desc": "%s. 전투가 길수록 이 레전드의 숨이 살아납니다." % pn,
		"scale": 1.12 if style == "tank" else (0.95 if style == "assassin" else 1.0),
	}
	_rows.append(row)
