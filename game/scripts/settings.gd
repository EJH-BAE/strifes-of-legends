extends Node

signal changed

const PATH := "user://settings.cfg"

var player_name := "Bae"
var cast_mode := "normal"
var spell_q := "follow"
var spell_w := "follow"
var spell_e := "follow"
var spell_r := "follow"
var camera_locked := true
var damage_numbers := true
var shake := true
var show_range := false
var show_bars := true
var fog := false
var graphics_rev := 2
var fullscreen := false
var window_mode := "borderless"
var resolution := "1600x900"
var max_fps := 0
var aa_mode := "fxaa"
var render_scale := 1.0
var shadow_quality := "low"
var ao := false
var gi_mode := "off"
var reflections := false
var brightness := 1.0
var show_fps := false
var quality := "medium"
var vsync := true
var shadows := true
var aa := true
var auto_attack := false
var attack_left := true
var mouse_pan := 8.0
var invert_drag := false
var particles := "low"
var hud_scale := 1.0
var master := 0.8
var sfx := 0.85
var music := 0.35
var binds := {}
var block_input := false

func _ready() -> void:
	binds = _default_binds()
	load_all()

func _default_binds() -> Dictionary:
	return {
		"q": KEY_Q,
		"w": KEY_W,
		"e": KEY_E,
		"r": KEY_R,
		"d": KEY_D,
		"f": KEY_F,
		"recall": KEY_B,
		"shop": KEY_P,
		"stop": KEY_S,
		"amove": KEY_A,
		"ping": KEY_G,
		"lock": KEY_Y,
		"center": KEY_SPACE,
		"champs": KEY_C,
		"i1": KEY_1,
		"i2": KEY_2,
		"i3": KEY_3,
		"i4": KEY_4,
		"i5": KEY_5,
		"i6": KEY_6,
		"i7": KEY_7,
	}

func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	player_name = str(cfg.get_value("player", "name", player_name))
	cast_mode = str(cfg.get_value("player", "cast_mode", cast_mode))
	spell_q = str(cfg.get_value("spell", "q", spell_q))
	spell_w = str(cfg.get_value("spell", "w", spell_w))
	spell_e = str(cfg.get_value("spell", "e", spell_e))
	spell_r = str(cfg.get_value("spell", "r", spell_r))
	camera_locked = bool(cfg.get_value("game", "camera_locked", camera_locked))
	damage_numbers = bool(cfg.get_value("game", "damage_numbers", damage_numbers))
	shake = bool(cfg.get_value("game", "shake", shake))
	show_range = bool(cfg.get_value("game", "show_range", show_range))
	show_bars = bool(cfg.get_value("game", "show_bars", show_bars))
	auto_attack = bool(cfg.get_value("game", "auto_attack", auto_attack))
	attack_left = bool(cfg.get_value("mouse", "attack_left", attack_left))
	mouse_pan = float(cfg.get_value("mouse", "pan", mouse_pan))
	invert_drag = bool(cfg.get_value("mouse", "invert_drag", invert_drag))
	fog = bool(cfg.get_value("video", "fog", fog))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	window_mode = str(cfg.get_value("video", "window_mode", window_mode))
	resolution = str(cfg.get_value("video", "resolution", resolution))
	max_fps = int(cfg.get_value("video", "max_fps", max_fps))
	aa_mode = str(cfg.get_value("video", "aa_mode", aa_mode))
	render_scale = float(cfg.get_value("video", "render_scale", render_scale))
	shadow_quality = str(cfg.get_value("video", "shadow_quality", shadow_quality))
	ao = bool(cfg.get_value("video", "ao", ao))
	gi_mode = str(cfg.get_value("video", "gi_mode", gi_mode))
	reflections = bool(cfg.get_value("video", "reflections", reflections))
	brightness = float(cfg.get_value("video", "brightness", brightness))
	show_fps = bool(cfg.get_value("ui", "show_fps", show_fps))
	quality = str(cfg.get_value("video", "quality", quality))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	shadows = bool(cfg.get_value("video", "shadows", shadows))
	aa = bool(cfg.get_value("video", "aa", aa))
	particles = str(cfg.get_value("video", "particles", particles))
	hud_scale = float(cfg.get_value("ui", "hud_scale", hud_scale))
	graphics_rev = int(cfg.get_value("video", "graphics_rev", 0))
	master = float(cfg.get_value("audio", "master", master))
	sfx = float(cfg.get_value("audio", "sfx", sfx))
	music = float(cfg.get_value("audio", "music", music))
	for k in binds.keys():
		binds[k] = int(cfg.get_value("keys", k, binds[k]))
	if graphics_rev < 2:
		_playable_graphics()
		graphics_rev = 2
		save_all()

func _playable_graphics() -> void:
	quality = "medium"
	aa_mode = "fxaa"
	shadow_quality = "low"
	shadows = true
	ao = false
	gi_mode = "off"
	reflections = false
	fog = false
	particles = "low"
	render_scale = 1.0

func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "cast_mode", cast_mode)
	cfg.set_value("spell", "q", spell_q)
	cfg.set_value("spell", "w", spell_w)
	cfg.set_value("spell", "e", spell_e)
	cfg.set_value("spell", "r", spell_r)
	cfg.set_value("game", "camera_locked", camera_locked)
	cfg.set_value("game", "damage_numbers", damage_numbers)
	cfg.set_value("game", "shake", shake)
	cfg.set_value("game", "show_range", show_range)
	cfg.set_value("game", "show_bars", show_bars)
	cfg.set_value("game", "auto_attack", auto_attack)
	cfg.set_value("mouse", "attack_left", attack_left)
	cfg.set_value("mouse", "pan", mouse_pan)
	cfg.set_value("mouse", "invert_drag", invert_drag)
	cfg.set_value("video", "fog", fog)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "resolution", resolution)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("video", "aa_mode", aa_mode)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "shadow_quality", shadow_quality)
	cfg.set_value("video", "ao", ao)
	cfg.set_value("video", "gi_mode", gi_mode)
	cfg.set_value("video", "reflections", reflections)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("ui", "show_fps", show_fps)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "shadows", shadows)
	cfg.set_value("video", "aa", aa)
	cfg.set_value("video", "particles", particles)
	cfg.set_value("video", "graphics_rev", graphics_rev)
	cfg.set_value("ui", "hud_scale", hud_scale)
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "music", music)
	for k in binds.keys():
		cfg.set_value("keys", k, int(binds[k]))
	cfg.save(PATH)

func clone() -> Dictionary:
	return {
		"name": player_name,
		"cast_mode": cast_mode,
		"spell_q": spell_q,
		"spell_w": spell_w,
		"spell_e": spell_e,
		"spell_r": spell_r,
		"camera_locked": camera_locked,
		"damage_numbers": damage_numbers,
		"shake": shake,
		"show_range": show_range,
		"show_bars": show_bars,
		"auto_attack": auto_attack,
		"attack_left": attack_left,
		"mouse_pan": mouse_pan,
		"invert_drag": invert_drag,
		"fog": fog,
		"fullscreen": fullscreen,
		"window_mode": window_mode,
		"resolution": resolution,
		"max_fps": max_fps,
		"aa_mode": aa_mode,
		"render_scale": render_scale,
		"shadow_quality": shadow_quality,
		"ao": ao,
		"gi_mode": gi_mode,
		"reflections": reflections,
		"brightness": brightness,
		"show_fps": show_fps,
		"quality": quality,
		"vsync": vsync,
		"shadows": shadows,
		"aa": aa,
		"particles": particles,
		"hud_scale": hud_scale,
		"master": master,
		"sfx": sfx,
		"music": music,
		"binds": binds.duplicate(true),
	}

func replace(next: Dictionary) -> void:
	player_name = str(next["name"])
	cast_mode = str(next["cast_mode"])
	spell_q = str(next["spell_q"])
	spell_w = str(next["spell_w"])
	spell_e = str(next["spell_e"])
	spell_r = str(next["spell_r"])
	camera_locked = bool(next["camera_locked"])
	damage_numbers = bool(next["damage_numbers"])
	shake = bool(next["shake"])
	show_range = bool(next["show_range"])
	show_bars = bool(next["show_bars"])
	auto_attack = bool(next["auto_attack"])
	attack_left = bool(next["attack_left"])
	mouse_pan = float(next["mouse_pan"])
	invert_drag = bool(next["invert_drag"])
	fog = bool(next["fog"])
	fullscreen = bool(next["fullscreen"])
	window_mode = str(next["window_mode"])
	resolution = str(next["resolution"]) if next.has("resolution") else resolution
	max_fps = int(next["max_fps"]) if next.has("max_fps") else max_fps
	aa_mode = str(next.get("aa_mode", aa_mode))
	render_scale = float(next.get("render_scale", render_scale))
	shadow_quality = str(next.get("shadow_quality", shadow_quality))
	ao = bool(next.get("ao", ao))
	gi_mode = str(next.get("gi_mode", gi_mode))
	reflections = bool(next.get("reflections", reflections))
	brightness = float(next.get("brightness", brightness))
	show_fps = bool(next.get("show_fps", show_fps))
	quality = str(next["quality"])
	vsync = bool(next["vsync"])
	shadows = bool(next["shadows"])
	aa = bool(next["aa"])
	particles = str(next["particles"])
	hud_scale = float(next["hud_scale"])
	master = float(next["master"])
	sfx = float(next["sfx"])
	music = float(next["music"])
	binds = next["binds"].duplicate(true)
	save_all()
	changed.emit()

func key_of(action: String) -> int:
	return int(binds.get(action, 0))

func key_label(code: int) -> String:
	var text := OS.get_keycode_string(code)
	if text == "":
		return "?"
	return text

func spell_style(id: String) -> String:
	var specific := "follow"
	match id:
		"q":
			specific = spell_q
		"w":
			specific = spell_w
		"e":
			specific = spell_e
		"r":
			specific = spell_r
	if specific == "follow":
		return cast_mode
	return specific

func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var size = Vector2i(1600, 900)
	var bits = resolution.split("x")
	if bits.size() == 2:
		size = Vector2i(int(bits[0]), int(bits[1]))
	Engine.max_fps = max(max_fps, 0)
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			if size.x > 0:
				DisplayServer.window_set_size(size)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(size)
			var screen = DisplayServer.screen_get_size()
			DisplayServer.window_set_position(Vector2i((screen.x - size.x) / 2, (screen.y - size.y) / 2))
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
