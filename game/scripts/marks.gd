extends RefCounted

static var _cache := {}

static func icon(role: String) -> ImageTexture:
	var key = "bot" if role == "adc" or role == "support" else role
	if role == "adc":
		key = "bot"
	elif role == "support":
		key = "bot2"
	if _cache.has(key):
		return _cache[key]
	var tex = ImageTexture.create_from_image(_draw(key))
	_cache[key] = tex
	return tex

static func _draw(key: String) -> Image:
	var n := 72
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(36, 36)
	for y in n:
		for x in n:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d := p.distance_to(c)
			if d > 34.0:
				continue
			var col := Color(0.07, 0.09, 0.12, 1)
			if d > 30.0:
				col = Color(0.86, 0.74, 0.42, 1)
			elif d > 28.0:
				col = Color(0.04, 0.05, 0.07, 1)
			img.set_pixel(x, y, col)
	var ink := Color(0.93, 0.9, 0.82, 1)
	match key:
		"top":
			_lane(img, Vector2(18, 50), Vector2(52, 16), ink)
			_sword(img, Vector2(40, 28), ink)
		"jungle":
			_leaf(img, ink)
		"mid":
			_lane(img, Vector2(16, 54), Vector2(56, 18), ink)
			_diamond(img, Vector2(36, 34), 8, ink)
		"bot":
			_lane(img, Vector2(18, 20), Vector2(54, 54), ink)
			_dot(img, Vector2(30, 42), 4, ink)
			_dot(img, Vector2(44, 48), 4, Color(0.55, 0.78, 1, 1))
		"bot2":
			_lane(img, Vector2(18, 20), Vector2(54, 54), ink)
			_dot(img, Vector2(28, 46), 4, Color(0.55, 0.78, 1, 1))
			_ward(img, Vector2(46, 36), ink)
		_:
			_diamond(img, c, 10, ink)
	return img

static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if img.get_pixel(x, y).a < 0.2:
		return
	img.set_pixel(x, y, col)

static func _disc(img: Image, center: Vector2, r: float, col: Color) -> void:
	var x0 = int(center.x - r - 1)
	var y0 = int(center.y - r - 1)
	var x1 = int(center.x + r + 1)
	var y1 = int(center.y + r + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if Vector2(x, y).distance_to(center) <= r:
				_px(img, x, y, col)

static func _dot(img: Image, center: Vector2, r: float, col: Color) -> void:
	_disc(img, center, r, col)

static func _line(img: Image, a: Vector2, b: Vector2, thick: float, col: Color) -> void:
	var steps = int(a.distance_to(b) * 2.0) + 1
	for i in steps + 1:
		var p = a.lerp(b, float(i) / float(steps))
		_disc(img, p, thick, col)

static func _lane(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	_line(img, a, b, 2.2, Color(0.45, 0.38, 0.22, 1))
	_line(img, a, b, 1.1, col)

static func _diamond(img: Image, c: Vector2, r: float, col: Color) -> void:
	_line(img, c + Vector2(0, -r), c + Vector2(r, 0), 1.3, col)
	_line(img, c + Vector2(r, 0), c + Vector2(0, r), 1.3, col)
	_line(img, c + Vector2(0, r), c + Vector2(-r, 0), 1.3, col)
	_line(img, c + Vector2(-r, 0), c + Vector2(0, -r), 1.3, col)

static func _sword(img: Image, c: Vector2, col: Color) -> void:
	_line(img, c + Vector2(0, 10), c + Vector2(0, -12), 1.4, col)
	_line(img, c + Vector2(-6, 2), c + Vector2(6, 2), 1.3, col)

static func _leaf(img: Image, col: Color) -> void:
	_line(img, Vector2(24, 48), Vector2(46, 22), 1.2, col)
	_disc(img, Vector2(40, 30), 8, Color(0.35, 0.62, 0.32, 1))
	_line(img, Vector2(34, 36), Vector2(46, 24), 1.0, col)

static func _ward(img: Image, c: Vector2, col: Color) -> void:
	_disc(img, c, 5, Color(0.15, 0.45, 0.75, 1))
	_line(img, c + Vector2(0, 4), c + Vector2(0, 12), 1.2, col)
	_line(img, c + Vector2(-4, 8), c + Vector2(4, 8), 1.1, col)
