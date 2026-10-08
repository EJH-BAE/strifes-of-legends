extends Control

const PIX := 10
const CELLS := [
	".####.",
	"######",
	"######",
	"######",
	"######",
	".####.",
]

var _marks: Array = []
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := _blob()
	var blob_w := 6 * PIX
	var blob_h := 6 * PIX
	var gap := 3 * PIX
	var step := blob_w + gap
	custom_minimum_size = Vector2(step * 2 + blob_w, blob_h + PIX)
	size = custom_minimum_size
	for i in 3:
		var mark := TextureRect.new()
		mark.texture = tex
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_SCALE
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.size = Vector2(blob_w, blob_h)
		mark.position = Vector2(i * step, PIX)
		add_child(mark)
		_marks.append(mark)

func _process(delta: float) -> void:
	_time += delta
	var frame := int(_time / 0.13) % 3
	for i in _marks.size():
		_marks[i].position.y = 0.0 if i == frame else float(PIX)

func _blob() -> ImageTexture:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in CELLS.size():
		var row: String = CELLS[y]
		for x in row.length():
			if row[x] == "#":
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
