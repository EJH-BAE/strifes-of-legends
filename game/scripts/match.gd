extends Node3D

class Bolt:
	var pos = Vector3.ZERO
	var dir = Vector3.FORWARD
	var traveled = 0.0
	var extra = -1.0
	var first = null
	var hit = {}
	var dmg = 0.0
	var disable = 1.0
	var reach = 850.0
	var pierce = true
	var caster = null

class Shot:
	var node: MeshInstance3D
	var target
	var from
	var dmg = 0.0
	var meep = false
	var speed = 2100.0

class FeedLine:
	var node: Label
	var life = 4.8

class Shout:
	var text = ""
	var life = 2.3

class Chime:
	var pos = Vector3.ZERO
	var mesh: MeshInstance3D
	var life = 55.0

class Shrine:
	var pos = Vector3.ZERO
	var t = 0.0
	var mesh: MeshInstance3D

class Portal:
	var a = Vector3.ZERO
	var b = Vector3.ZERO
	var life = 10.0
	var mesh_a: MeshInstance3D
	var mesh_b: MeshInstance3D

class Gate:
	var a = Vector3.ZERO
	var b = Vector3.ZERO

class UltShot:
	var from = Vector3.ZERO
	var to = Vector3.ZERO
	var t = 0.0
	var dur = 1.0
	var node: MeshInstance3D
	var mode = "portal"
	var dmg = 0.0
	var stun = 0.0
	var radius = 260.0

class TimedMesh:
	var mesh: Node3D
	var life = 0.0
	var max_life = 4.0
	var label: Label
	var pos = Vector3.ZERO

class Floater:
	var node: Label
	var pos = Vector3.ZERO
	var life = 0.7

class BagItem:
	var id = ""
	var count = 1

const Rift = preload("res://scripts/rift.gd")
const Unit = preload("res://scripts/unit.gd")
const MenuScript = preload("res://scripts/settings_menu.gd")
const Legends = preload("res://scripts/legends.gd")
var WORLD = 14800.0
var FOUNTAIN = Vector3(2100, 0, 2000)
var FOUNTAIN_R = 1100.0
var SPAWN = Vector3(2900, 0, 2500)
var lanes = {}
var structure_defs: Array = []
var sun: DirectionalLight3D
var cam_pan = Vector3.ZERO
var dragging = false
var lock_before = true
var ended = false
var blue_kills = 0
var red_kills = 0

var camera: Camera3D
var environment: Environment
var player
var player_def: Dictionary = {}
var units: Array = []
var walls: Array = []
var bolts: Array = []
var shots: Array = []
var shrines: Array = []
var portals: Array = []
var wards: Array = []
var pings: Array = []
var floaters: Array = []
var aim = ""
var aim_pick = false
var rmb = false
var paused = false
var pause_open = false
var shop_open = false
var gold = 500
var cs = 0
var cd = {"q": 0.0, "e": 0.0, "r": 0.0, "d": 0.0, "f": 0.0, "ward": 0.0}
var w_charges = 2
var w_charge_t = 0.0
var skills = {"q": 3, "w": 1, "e": 1, "r": 1}
var meeps = 1
var meep_t = 0.0
var chime_count = 0
var chime_spawn = 4.0
var chimes: Array = []
var camp_timers: Array = []
var shot_path = ""
var shot_frames = 0
var cam_zoom = 1.0
var focus_unit = null
var score_held = false
var score_layer: CanvasLayer
var score_rows = {}
var nid_seq := 0
var net_label: Label
var peer_units := {}
var net_puppets := {}
var snap_acc := 0.0
var minimap: TextureRect
var minimap_dots: Control
var fps_label: Label
const CAM_OFF = Vector3(0, 1500, -1120)
var cam_lock = true
var space_held = false
var shake = 0.0
var ping_hold = false
var ping_from = Vector2.ZERO
var ping_cd = 0.0
var first_blood = true
var announce_life = 0.0
var shouts: Array = []
var kill_lines: Array = []
var kill_log: VBoxContainer
var announce: Label
var recall_ring: MeshInstance3D
var recall_column: MeshInstance3D
var wave_in = 30.0
var ult = null
var recall_bar: ColorRect
var hud_panel: Control
var hp_fill: ColorRect
var hp_ghost: ColorRect
var hp_label: Label
var mp_fill: ColorRect
var mp_label: Label
var ms_label: Label
var gold_label: Label
var top_blue: Label
var top_red: Label
var top_time: Label
var name_label: Label
var spell_buttons = {}
var item_buttons = {}
var inventory: Array = [null, null, null, null, null, null]
var bars_root: Control
var bar_nodes = {}
var float_root: Control
var aim_mesh: MeshInstance3D
var range_mesh: MeshInstance3D
var pause_layer: CanvasLayer
var shop_layer: CanvasLayer
var wheel: Control
var feed: Label
var death_label: Label
var clock = 0.0
var target_rings = {}
var order_ring: MeshInstance3D
var order_pulse: MeshInstance3D
var attack_ring: MeshInstance3D
var cursor_move: ImageTexture
var cursor_attack: ImageTexture
var cursor_cast: ImageTexture

func _ready() -> void:
	add_to_group("match")
	cam_lock = bool(Settings.camera_locked)
	if SolNet.remote_client():
		_world()
		_hud()
		_pause_ui()
		_score_ui()
		Settings.changed.connect(_on_settings)
		_on_settings()
		_make_cursors()
		_make_order_markers()
		return
	_world()
	_spawn_player()
	_spawn_structures()
	_spawn_enemy_hero()
	_spawn_camps()
	for lane_name in lanes.keys():
		_spawn_wave("blue", lane_name)
		_spawn_wave("red", lane_name)
	_hud()
	_pause_ui()
	_shop_ui()
	_score_ui()
	Settings.changed.connect(_on_settings)
	_on_settings()
	_make_cursors()
	_make_order_markers()
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shot="):
			shot_path = str(arg).substr(7)
		elif str(arg).begins_with("--zoom="):
			cam_zoom = float(str(arg).substr(7))
		elif str(arg).begins_with("--focus="):
			var want = str(arg).substr(8)
			for u in units:
				if u.unit_name == want:
					focus_unit = u
					break
	if Draft.mode == "swift":
		wave_in = 8.0
	if SolNet.serving():
		for peer in SolNet.owners.keys():
			var user: Dictionary = SolNet.owners[peer]
			bind_remote(int(peer), str(user.get("username", "")))
	if DisplayServer.get_name() == "headless" and not SolNet.serving():
		_run_headless_checks()

func _world() -> void:
	var envn = WorldEnvironment.new()
	environment = Environment.new()
	var sky = Sky.new()
	var psky = ProceduralSkyMaterial.new()
	psky.sky_top_color = Color(0.04, 0.07, 0.12)
	psky.sky_horizon_color = Color(0.22, 0.16, 0.12)
	psky.sky_curve = 0.12
	psky.ground_horizon_color = Color(0.3, 0.27, 0.2)
	psky.ground_bottom_color = Color(0.08, 0.1, 0.08)
	psky.sun_angle_max = 24.0
	psky.sun_curve = 0.08
	sky.sky_material = psky
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.16
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.55
	environment.tonemap_white = 4.0
	environment.glow_enabled = false
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.ssr_enabled = false
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.78
	environment.adjustment_contrast = 1.14
	environment.adjustment_saturation = 1.2
	environment.volumetric_fog_enabled = false
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_albedo = Color(0.9, 0.92, 1.0)
	environment.volumetric_fog_emission = Color(0.02, 0.025, 0.04)
	environment.volumetric_fog_length = 3200.0
	environment.volumetric_fog_detail_spread = 1.5
	environment.volumetric_fog_sky_affect = 0.2
	envn.environment = environment
	var attrs = CameraAttributesPractical.new()
	attrs.auto_exposure_enabled = false
	envn.camera_attributes = attrs
	add_child(envn)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 142, 0)
	sun.light_energy = 0.62
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_angular_distance = 0.0
	sun.light_volumetric_fog_energy = 0.0
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = false
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.4
	sun.directional_shadow_max_distance = 2200.0
	sun.directional_shadow_fade_start = 0.9
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, -40, 0)
	fill.light_energy = 0.08
	fill.light_color = Color(0.6, 0.74, 1.0)
	fill.shadow_enabled = false
	fill.light_specular = 0.2
	add_child(fill)
	var map = Rift.build(self)
	WORLD = map["size"]
	SPAWN = map["spawn"]
	FOUNTAIN = map["fountain"]
	FOUNTAIN_R = map["fountain_r"]
	lanes = map["lanes"]
	structure_defs = map["structures"]
	for rect in map["walls"]:
		walls.append(rect)
	camera = Camera3D.new()
	camera.fov = 34
	camera.current = true
	add_child(camera)
	aim_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	aim_mesh.mesh = box
	var amat = StandardMaterial3D.new()
	amat.albedo_color = Color(0.95, 0.84, 0.45, 0.45)
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	amat.emission_enabled = true
	amat.emission = Color(1, 0.9, 0.5)
	amat.emission_energy_multiplier = 0.4
	aim_mesh.material_override = amat
	aim_mesh.visible = false
	add_child(aim_mesh)
	range_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 496
	torus.outer_radius = 508
	torus.rings = 64
	torus.ring_segments = 8
	range_mesh.mesh = torus
	var tmat = StandardMaterial3D.new()
	tmat.albedo_color = Color(1, 0.4, 0.32, 0.55)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	range_mesh.material_override = tmat
	range_mesh.visible = false
	add_child(range_mesh)

func _add_wall(x: float, z: float, w: float, d: float) -> void:
	walls.append(Rect2(x, z, w, d))
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(w, 180, d)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.26, 0.23)
	mesh.material_override = mat
	mesh.position = Vector3(x + w * 0.5, 90, z + d * 0.5)
	add_child(mesh)

func _spawn_player() -> void:
	Draft.ensure()
	var slot = {}
	for row in Draft.blue:
		if bool(row.get("player", false)):
			slot = row
			break
	if slot.is_empty() and Draft.blue.size() > 0:
		slot = Draft.blue[4] if Draft.blue.size() > 4 else Draft.blue[0]
	var def = Legends.by_id(str(slot.get("legend", "orbel")))
	if def.is_empty():
		def = Legends.by_id("orbel")
	player_def = def
	var role_name = str(slot.get("role", def["role"]))
	var lane_pts = lanes["bot"]
	if role_name == "top":
		lane_pts = lanes["top"]
	elif role_name == "mid":
		lane_pts = lanes["mid"]
	elif role_name == "jungle":
		lane_pts = _jungle_path(false)
	player = _make_champ("blue", str(def["name"]), role_name, str(def["style"]), def["tint"], SPAWN, lane_pts, 0, float(def["ms"]), float(def["ad"]), float(def["reach"]), float(def["asp"]), float(def["hp"]), float(def["armor"]), float(def["mr"]))
	_apply_legend(player, def, str(slot.get("username", Draft.player_name())), true)
	_apply_level(player, slot)
	Sfx.set_voice(str(player.style))
	_sync_charges()

func _apply_legend(u, def: Dictionary, uname: String, is_player: bool) -> void:
	u.username = uname
	u.legend_id = str(def.get("id", ""))
	u.kit_name = str(def.get("kit", "wanderer"))
	u.model_scale = float(def.get("scale", 1.0))
	u.vital.max_mana = float(def.get("mana", 400))
	u.vital.mana = u.vital.max_mana
	u.vital.mana_regen = 1.15 if is_player else 0.9
	u.base_max_hp = float(def.get("hp", u.base_max_hp))
	u.build_visual()

func _sync_charges() -> void:
	var spec = _spec("w")
	w_charges = int(spec.get("charges", 0))
	w_charge_t = 0.0

func _spec(id: String) -> Dictionary:
	if player_def.is_empty():
		return {}
	return Legends.spell(player_def, id)

func _spawn_structures() -> void:
	for data in structure_defs:
		var radius = 128.0
		if data["kind"] == "nexus":
			radius = 240.0
		elif data["kind"] == "inhibitor":
			radius = 150.0
		var u = _make_unit(data["kind"], data["team"], data["name"], data["pos"], radius)
		u.hold = true
		u.ad = data["ad"]
		u.attack_range = data["range"]
		u.attack_speed = 0.75
		u.base_ms = 0
		u.setup(data["hp"], 40, 40, 0)
		u.build_visual()

func _spawn_enemy_hero() -> void:
	Draft.ensure()
	var blue_home = SPAWN
	var red_home = Vector3(11900, 0, 12300)
	var blue_off = [Vector3(-180, 0, 160), Vector3(200, 0, 180), Vector3(40, 0, 220), Vector3(220, 0, -40), Vector3(0, 0, 0)]
	var red_off = [Vector3(0, 0, 0), Vector3(180, 0, -80), Vector3(-80, 0, 160), Vector3(80, 0, 80), Vector3(-160, 0, -40)]
	for i in Draft.blue.size():
		var slot = Draft.blue[i]
		if bool(slot.get("player", false)) and player != null and str(slot.get("username", "")) == str(player.username):
			continue
		_spawn_slot("blue", slot, blue_home + blue_off[mini(i, 4)], false)
	for i in Draft.red.size():
		_spawn_slot("red", Draft.red[i], red_home + red_off[mini(i, 4)], true)

func _spawn_slot(team: String, slot: Dictionary, pos: Vector3, red: bool) -> void:
	var def = Legends.by_id(str(slot.get("legend", "")))
	if def.is_empty():
		return
	var role_name = str(slot.get("role", def["role"]))
	var lane_pts = lanes["bot"]
	if role_name == "top":
		lane_pts = lanes["top"]
	elif role_name == "mid":
		lane_pts = lanes["mid"]
	elif role_name == "jungle":
		lane_pts = _jungle_path(red)
	if red:
		if role_name == "top":
			lane_pts = _flipped(lanes["top"])
		elif role_name == "mid":
			lane_pts = _flipped(lanes["mid"])
		elif role_name == "adc" or role_name == "support":
			lane_pts = _flipped(lanes["bot"])
	var u = _make_champ(team, str(def["name"]), role_name, str(def["style"]), def["tint"], pos, lane_pts, 0, float(def["ms"]), float(def["ad"]), float(def["reach"]), float(def["asp"]), float(def["hp"]), float(def["armor"]), float(def["mr"]))
	_apply_legend(u, def, str(slot.get("username", def["name"])), false)
	_apply_level(u, slot)

func _apply_level(u, slot: Dictionary) -> void:
	var lv := maxi(1, int(slot.get("level", 1)))
	u.level = lv
	var mul := 1.0 + float(lv - 1) * 0.04
	u.ad = maxf(1.0, u.ad * mul)
	u.vital.max_hp = maxf(1.0, u.vital.max_hp * mul)
	u.vital.hp = u.vital.max_hp
	u.base_max_hp = u.vital.max_hp

func _flipped(pts: Array) -> Array:
	var copy = pts.duplicate()
	copy.reverse()
	return copy

func _jungle_path(red: bool) -> Array:
	var pts = [Vector3(3600, 0, 3600), Vector3(6400, 0, 5000), Vector3(5000, 0, 10200), Vector3(8000, 0, 8000)]
	if red:
		pts = [Vector3(11200, 0, 11200), Vector3(10400, 0, 6800), Vector3(8400, 0, 9800), Vector3(7000, 0, 7000)]
	return pts

func _make_champ(team: String, uname: String, role_name: String, style_name: String, color: Color, pos: Vector3, lane_pts: Array, index: int, ms: float, ad: float, reach: float, asp: float, hp: float, armor: float, mr: float):
	var u = _make_unit("champion", team, uname, pos, 42)
	u.role = role_name
	u.style = style_name
	u.tint = color
	u.base_ms = ms
	u.ad = ad
	u.attack_range = reach
	u.attack_speed = asp
	u.lane = lane_pts
	u.lane_i = index
	u.home = pos
	u.setup(hp, armor, mr, 1.4)
	u.base_max_hp = hp
	u.base_range = reach
	u.base_asp = asp
	if style_name == "warlord":
		u.vital.max_mana = 200
		u.vital.mana = 200
	return u

func _spawn_camps() -> void:
	for d in Rift.camp_defs():
		_spawn_camp(d)

func _spawn_camp(d: Dictionary) -> void:
	var count = int(d["count"])
	for i in count:
		var off = Vector3.ZERO
		if count > 1:
			var ang = float(i) / float(count) * TAU
			off = Vector3(cos(ang) * 110.0, 0, sin(ang) * 110.0)
		var hp = float(d["hp"]) if i == 0 else float(d["hp"]) * 0.45
		var ad = float(d["ad"]) if i == 0 else float(d["ad"]) * 0.6
		var size = float(d["size"]) if i == 0 else float(d["size"]) * 0.7
		var u = _make_monster(d, d["pos"] + off, hp, ad, size)
		u.camp = d

func _make_monster(d: Dictionary, pos: Vector3, hp: float, ad: float, size: float):
	var style_name = str(d["style"])
	var radius = 40.0 * size
	if style_name == "dragon" or style_name == "boss":
		radius = 70.0 * size
	var u = _make_unit("monster", "neutral", str(d["name"]), pos, radius)
	u.style = style_name
	u.tint = d["tint"]
	u.model_scale = size
	u.base_ms = 330
	u.ad = ad
	u.attack_range = float(d["range"]) * size
	u.attack_speed = float(d["asp"])
	u.home = pos
	u.leash = 1100 if style_name != "boss" and style_name != "dragon" else 1500
	u.bounty = int(d["bounty"])
	u.setup(hp, 30 if style_name != "boss" else 60, 30 if style_name != "boss" else 60, 2)
	u.build_visual()
	return u

func _think_monster(u) -> void:
	var foe = u.last_attacker
	if foe != null and is_instance_valid(foe) and not foe.dead and _flat(foe.global_position, u.home) < u.leash and _flat(u.global_position, u.home) < u.leash:
		u.target = foe
		u.sticky = true
		if _flat(u.global_position, foe.global_position) > u.attack_range + foe.radius:
			u.dest = foe.global_position
			u.moving = true
		else:
			u.moving = false
		return
	u.last_attacker = null
	u.target = null
	u.sticky = false
	u.dest = u.home
	u.moving = _flat(u.global_position, u.home) > 40
	if u.vital.hp < u.vital.max_hp and not u.moving:
		u.vital.heal(u.vital.max_hp * 0.08 * 0.016)

func _tick_camps(delta: float) -> void:
	for i in range(camp_timers.size() - 1, -1, -1):
		camp_timers[i]["t"] -= delta
		if camp_timers[i]["t"] <= 0.0:
			var d = camp_timers[i]["def"]
			camp_timers.remove_at(i)
			_spawn_camp(d)

func _make_unit(kind: String, team: String, uname: String, pos: Vector3, radius: float):
	var u = Unit.new()
	u.kind = kind
	u.team = team
	u.unit_name = uname
	u.radius = radius
	u.home = pos
	u.position = pos
	add_child(u)
	nid_seq += 1
	u.set_meta("nid", nid_seq)
	u.basic_attack.connect(_on_basic.bind(u))
	units.append(u)
	return u

func _lane_points(lane_name: String, reverse: bool) -> Array:
	var pts = lanes[lane_name].duplicate()
	if reverse:
		pts.reverse()
	return pts

func _spawn_wave(team: String, lane_name: String = "") -> void:
	if lane_name == "":
		for key in lanes.keys():
			_spawn_wave(team, key)
		return
	var living = 0
	for u in units:
		if u.kind == "minion" and u.team == team and u.lane_name == lane_name and not u.dead:
			living += 1
	if living > 16:
		return
	var pts = _lane_points(lane_name, team == "red")
	var origin: Vector3 = pts[0]
	for i in 3:
		var m = _make_unit("minion", team, "전사 미니언", origin + Vector3(-30 * i, 0, 20), 30)
		m.role = "melee"
		m.base_ms = 325
		m.ad = 5
		m.attack_range = 100
		m.attack_speed = 0.5
		m.bounty = 21
		m.xp_value = 48
		m.lane = pts
		m.lane_name = lane_name
		m.lane_i = 1
		m.setup(280, 0, 0, 0)
		m.build_visual()
	for i in 2:
		var c = _make_unit("minion", team, "마법 미니언", origin + Vector3(-20, 0, 40 * i), 26)
		c.role = "caster"
		c.base_ms = 325
		c.ad = 7
		c.attack_range = 420
		c.attack_speed = 0.48
		c.bounty = 14
		c.xp_value = 30
		c.lane = pts
		c.lane_name = lane_name
		c.lane_i = 1
		c.setup(170, 0, 0, 0)
		c.build_visual()

func _hud() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	bars_root = Control.new()
	_fill(bars_root)
	bars_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars_root.theme = _font()
	layer.add_child(bars_root)
	float_root = Control.new()
	_fill(float_root)
	float_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(float_root)
	var ui = CanvasLayer.new()
	ui.layer = 12
	add_child(ui)
	var root = Control.new()
	_fill(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _font()
	ui.add_child(root)
	net_label = Label.new()
	net_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	net_label.offset_left = -220
	net_label.offset_top = -28
	net_label.offset_right = -12
	net_label.offset_bottom = -8
	net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	net_label.add_theme_font_size_override("font_size", 13)
	net_label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.72, 0.9))
	net_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(net_label)
	death_label = Label.new()
	death_label.visible = false
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 36)
	death_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	death_label.position = Vector2(500, 160)
	death_label.size = Vector2(600, 80)
	root.add_child(death_label)
	var topbar = Panel.new()
	topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topbar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	topbar.offset_left = -250
	topbar.offset_right = 250
	topbar.offset_top = 8
	topbar.offset_bottom = 58
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	top_style.border_color = Color(0.83, 0.71, 0.51, 0.85)
	top_style.set_border_width_all(1)
	topbar.add_theme_stylebox_override("panel", top_style)
	root.add_child(topbar)
	top_blue = Label.new()
	top_blue.text = "0"
	top_blue.anchor_left = 0.0
	top_blue.anchor_right = 0.0
	top_blue.offset_left = 8
	top_blue.offset_right = 78
	top_blue.offset_top = 8
	top_blue.offset_bottom = 50
	top_blue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_blue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_blue.add_theme_font_size_override("font_size", 28)
	top_blue.add_theme_color_override("font_color", Color(0.55, 0.75, 1))
	topbar.add_child(top_blue)
	top_time = Label.new()
	top_time.text = "0:00"
	top_time.anchor_left = 0.5
	top_time.anchor_right = 0.5
	top_time.offset_left = -70
	top_time.offset_right = 70
	top_time.offset_top = 4
	top_time.offset_bottom = 32
	top_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_time.add_theme_font_size_override("font_size", 22)
	top_time.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	topbar.add_child(top_time)
	var map_small = Label.new()
	map_small.text = "전설의 전장"
	map_small.anchor_left = 0.5
	map_small.anchor_right = 0.5
	map_small.offset_left = -80
	map_small.offset_right = 80
	map_small.offset_top = 32
	map_small.offset_bottom = 50
	map_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_small.add_theme_font_size_override("font_size", 12)
	map_small.add_theme_color_override("font_color", Color(0.72, 0.66, 0.5))
	topbar.add_child(map_small)
	top_red = Label.new()
	top_red.text = "0"
	top_red.anchor_left = 1.0
	top_red.anchor_right = 1.0
	top_red.offset_left = -78
	top_red.offset_right = -8
	top_red.offset_top = 8
	top_red.offset_bottom = 50
	top_red.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_red.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_red.add_theme_font_size_override("font_size", 28)
	top_red.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	topbar.add_child(top_red)
	kill_log = VBoxContainer.new()
	kill_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_log.set_anchors_preset(Control.PRESET_CENTER_TOP)
	kill_log.offset_left = -320
	kill_log.offset_right = 320
	kill_log.offset_top = 64
	kill_log.offset_bottom = 210
	kill_log.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(kill_log)
	announce = Label.new()
	announce.visible = false
	announce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce.set_anchors_preset(Control.PRESET_CENTER_TOP)
	announce.offset_left = -460
	announce.offset_right = 460
	announce.offset_top = 168
	announce.offset_bottom = 214
	announce.add_theme_font_size_override("font_size", 26)
	announce.add_theme_color_override("font_color", Color(0.98, 0.88, 0.5))
	root.add_child(announce)
	recall_bar = ColorRect.new()
	recall_bar.visible = false
	recall_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recall_bar.color = Color(0.55, 0.85, 1.0, 0.9)
	recall_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	recall_bar.offset_left = -120
	recall_bar.offset_top = 224
	recall_bar.offset_right = 120
	recall_bar.offset_bottom = 232
	root.add_child(recall_bar)
	feed = Label.new()
	feed.position = Vector2(24, 560)
	feed.size = Vector2(420, 120)
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	root.add_child(feed)
	hud_panel = Panel.new()
	hud_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_panel.size = Vector2(760, 132)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.05, 0.72)
	sb.border_color = Color(0.83, 0.71, 0.51, 0.7)
	sb.set_border_width_all(1)
	hud_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(hud_panel)
	name_label = Label.new()
	name_label.position = Vector2(16, 8)
	name_label.text = str(player_def.get("name", "오르벨")) if not player_def.is_empty() else "오르벨"
	hud_panel.add_child(name_label)
	ms_label = Label.new()
	ms_label.position = Vector2(520, 8)
	ms_label.size = Vector2(220, 24)
	hud_panel.add_child(ms_label)
	gold_label = Label.new()
	gold_label.position = Vector2(16, 104)
	hud_panel.add_child(gold_label)
	_bar_row(hud_panel, 36, true)
	_bar_row(hud_panel, 62, false)
	var spells = HBoxContainer.new()
	spells.position = Vector2(250, 86)
	spells.add_theme_constant_override("separation", 6)
	hud_panel.add_child(spells)
	for id in ["q", "w", "e", "r", "d", "f"]:
		var b = Button.new()
		b.custom_minimum_size = Vector2(46, 40)
		b.pressed.connect(_press_spell.bind(id))
		spells.add_child(b)
		spell_buttons[id] = b
	var items = HBoxContainer.new()
	items.position = Vector2(560, 86)
	hud_panel.add_child(items)
	for i in 7:
		var b = Button.new()
		b.custom_minimum_size = Vector2(26, 36)
		b.pressed.connect(_use_slot.bind(i))
		items.add_child(b)
		item_buttons[i] = b
	wheel = Control.new()
	wheel.visible = false
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel.size = Vector2(260, 260)
	root.add_child(wheel)
	var disc = TextureRect.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.texture = _wheel_disc()
	disc.size = wheel.size
	wheel.add_child(disc)
	for spec in [
		["up", "위험", Vector2(108, 28), Color(1.0, 0.35, 0.28)],
		["left", "적 사라짐", Vector2(18, 116), Color(0.95, 0.82, 0.3)],
		["down", "도와주세요", Vector2(86, 200), Color(0.4, 0.68, 1.0)],
		["right", "갑니다", Vector2(168, 116), Color(0.4, 0.95, 0.55)],
	]:
		var lab = Label.new()
		lab.name = spec[0]
		lab.text = spec[1]
		lab.position = spec[2]
		lab.add_theme_font_size_override("font_size", 16)
		lab.add_theme_color_override("font_color", spec[3])
		wheel.add_child(lab)
	minimap = TextureRect.new()
	minimap.texture = ImageTexture.create_from_image(Rift.minimap_image(220))
	minimap.size = Vector2(220, 220)
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.gui_input.connect(_minimap_input)
	root.add_child(minimap)
	var frame = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = Vector2(228, 228)
	frame.position = Vector2(-4, -4)
	var fsb = StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)
	fsb.border_color = Color(0.83, 0.71, 0.51, 0.9)
	fsb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fsb)
	minimap.add_child(frame)
	minimap_dots = Control.new()
	minimap_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_dots.size = minimap.size
	minimap.add_child(minimap_dots)
	fps_label = Label.new()
	fps_label.visible = false
	fps_label.position = Vector2(12, 8)
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.7))
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fps_label)
	_layout_hud()
	get_viewport().size_changed.connect(_layout_hud)
	_refresh_keys()

func _teammates() -> Array:
	var out = []
	for u in units:
		if u.kind == "champion" and u.team == player.team and u != player:
			out.append(u)
	return out

func _score_ui() -> void:
	score_layer = CanvasLayer.new()
	score_layer.layer = 30
	score_layer.visible = false
	add_child(score_layer)
	var root = Control.new()
	_fill(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _font()
	score_layer.add_child(root)
	var panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -320
	panel.offset_bottom = 320
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.045, 0.06, 0.94)
	sb.border_color = Color(0.83, 0.71, 0.51, 0.9)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var table := VBoxContainer.new()
	table.position = Vector2(16, 12)
	table.custom_minimum_size = Vector2(1088, 0)
	table.add_theme_constant_override("separation", 4)
	panel.add_child(table)
	var top := HBoxContainer.new()
	table.add_child(top)
	var title = Label.new()
	title.text = "전황"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	top.add_child(title)
	var clock_lab = Label.new()
	clock_lab.custom_minimum_size = Vector2(120, 0)
	clock_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_lab.add_theme_color_override("font_color", Color(0.8, 0.76, 0.66))
	top.add_child(clock_lab)
	score_rows["clock"] = clock_lab
	var headers = ["소환사", "레전드", "역할", "레벨", "처치", "죽음", "도움", "CS", "골드"]
	var widths = [170, 150, 80, 60, 70, 70, 70, 70, 90]
	for team in ["blue", "red"]:
		var head = Label.new()
		head.add_theme_font_size_override("font_size", 16)
		head.add_theme_color_override("font_color", Color(0.55, 0.75, 1) if team == "blue" else Color(1, 0.45, 0.4))
		table.add_child(head)
		score_rows["head_" + team] = head
		var grid := GridContainer.new()
		grid.columns = headers.size()
		table.add_child(grid)
		for i in headers.size():
			grid.add_child(_score_cell(headers[i], widths[i], Color(0.62, 0.58, 0.5), true))
		for r in 5:
			for c in headers.size():
				var cell := _score_cell("", widths[c], Color(0.9, 0.88, 0.8), false)
				grid.add_child(cell)
				score_rows["%s_%d_%d" % [team, r, c]] = cell

func _score_cell(text: String, width: int, color: Color, header: bool) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.custom_minimum_size = Vector2(width, 26 if header else 24)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if header else HORIZONTAL_ALIGNMENT_LEFT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 14 if header else 15)
	lab.add_theme_color_override("font_color", color)
	lab.clip_text = true
	return lab

func _refresh_scoreboard() -> void:
	if score_layer == null:
		return
	var secs = int(clock)
	score_rows["clock"].text = "%d:%02d" % [int(secs / 60.0), secs % 60]
	var roles = {"top": "탑", "jungle": "정글", "mid": "미드", "adc": "원딜", "support": "서폿"}
	for team in ["blue", "red"]:
		var members = []
		for u in units:
			if u.kind == "champion" and u.team == team:
				members.append(u)
		var tk = 0
		var tg = 0
		for u in members:
			tk += u.kills
			tg += gold if u == player else u.purse
		score_rows["head_" + team].text = "%s    처치 %d    골드 %d" % ["푸른 팀" if team == "blue" else "붉은 팀", tk, tg]
		for i in 5:
			var values = ["", "", "", "", "", "", "", "", ""]
			var tint = Color(0.45, 0.44, 0.42)
			if i < members.size():
				var u = members[i]
				var summoner = str(u.username) if str(u.username) != "" else u.unit_name
				if u == player:
					summoner = "%s (나)" % summoner
				var g = gold if u == player else u.purse
				var c = cs if u == player else u.cs
				values = [summoner, u.unit_name, str(roles.get(u.role, u.role)), str(u.level), str(u.kills), str(u.deaths), str(u.assists), str(c), str(g)]
				tint = Color(0.55, 0.5, 0.48) if u.dead else (Color(1, 0.96, 0.85) if u == player else Color(0.9, 0.88, 0.82))
			for c in values.size():
				var cell: Label = score_rows["%s_%d_%d" % [team, i, c]]
				cell.text = values[c]
				cell.add_theme_color_override("font_color", tint)

func _minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var local = minimap.get_local_mouse_position()
		var wx = clampf(local.x / minimap.size.x, 0.0, 1.0) * WORLD
		var wz = (1.0 - clampf(local.y / minimap.size.y, 0.0, 1.0)) * WORLD
		var world = Vector3(wx, 0, wz)
		if event.button_index == MOUSE_BUTTON_RIGHT and _can_act():
			player.command_move(world)
			_show_move_marker(world)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			cam_lock = false
			cam_pan = world - player.global_position

func _update_minimap() -> void:
	if minimap_dots == null:
		return
	var want = 0
	for u in units:
		if u.dead or u.kind == "minion" and false:
			continue
		want += 1
	while minimap_dots.get_child_count() < want:
		var dot = ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minimap_dots.add_child(dot)
	var i = 0
	for u in units:
		if u.dead:
			continue
		var dot: ColorRect = minimap_dots.get_child(i)
		i += 1
		dot.visible = true
		var sz = 4.0
		if u.kind == "champion":
			sz = 9.0
		elif u.kind == "tower" or u.kind == "inhibitor":
			sz = 7.0
		elif u.kind == "nexus":
			sz = 11.0
		elif u.kind == "monster":
			sz = 6.0
		var col = Color(0.4, 0.65, 1.0) if u.team == "blue" else Color(1.0, 0.4, 0.35)
		if u.team == "neutral":
			col = Color(0.85, 0.75, 0.4)
		if u == player:
			col = Color(1.0, 1.0, 1.0)
		dot.color = col
		dot.size = Vector2(sz, sz)
		dot.position = Vector2(u.global_position.x / WORLD * minimap.size.x - sz * 0.5, (1.0 - u.global_position.z / WORLD) * minimap.size.y - sz * 0.5)
	for k in range(i, minimap_dots.get_child_count()):
		minimap_dots.get_child(k).visible = false

func _bar_row(parent: Control, y: float, is_hp: bool) -> void:
	var frame = ColorRect.new()
	frame.position = Vector2(13, y - 3)
	frame.size = Vector2(366, 24)
	frame.color = Color(0.02, 0.02, 0.02, 0.92)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var rim = ColorRect.new()
	rim.position = Vector2(15, y - 1)
	rim.size = Vector2(362, 20)
	rim.color = Color(0.78, 0.66, 0.38, 0.95) if is_hp else Color(0.35, 0.55, 0.85, 0.95)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rim)
	var bg = ColorRect.new()
	bg.position = Vector2(16, y)
	bg.size = Vector2(360, 18)
	bg.color = Color(0.05, 0.05, 0.05)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var ghost = ColorRect.new()
	ghost.position = Vector2(16, y)
	ghost.size = Vector2(360, 18)
	ghost.color = Color(0.95, 0.93, 0.86)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ghost)
	var fill = ColorRect.new()
	fill.position = Vector2(16, y)
	fill.size = Vector2(360, 18)
	fill.color = Color(0.2, 0.78, 0.32) if is_hp else Color(0.25, 0.55, 0.95)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	var lab = Label.new()
	lab.position = Vector2(16, y - 1)
	lab.size = Vector2(360, 20)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lab)
	if is_hp:
		hp_fill = fill
		hp_ghost = ghost
		hp_label = lab
	else:
		mp_fill = fill
		mp_label = lab
		ghost.visible = false

func _pause_ui() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 30
	pause_layer.visible = false
	add_child(pause_layer)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	_fill(dim)
	pause_layer.add_child(dim)
	var box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -140
	box.offset_top = -140
	box.offset_right = 140
	box.offset_bottom = 160
	box.theme = _font()
	pause_layer.add_child(box)
	var title = Label.new()
	title.text = "일시 정지"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_plain_button("계속하기", func(): _set_pause(false)))
	box.add_child(_plain_button("설정", _open_settings))
	box.add_child(_plain_button("나가기", func(): get_tree().change_scene_to_file("res://main.tscn")))

func _shop_ui() -> void:
	shop_layer = CanvasLayer.new()
	shop_layer.layer = 20
	shop_layer.visible = false
	add_child(shop_layer)
	var panel = Panel.new()
	panel.position = Vector2(40, 40)
	panel.size = Vector2(420, 460)
	panel.theme = _font()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	sb.border_color = Color(0.83, 0.71, 0.51)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	shop_layer.add_child(panel)
	var title = Label.new()
	title.text = "상점"
	title.position = Vector2(16, 12)
	panel.add_child(title)
	var close = Button.new()
	close.text = "닫기"
	close.position = Vector2(320, 8)
	close.pressed.connect(func(): shop_open = false; shop_layer.visible = false)
	panel.add_child(close)
	var note = Label.new()
	note.text = "기지 안에서만 연다. 숫자 키로 물약을 쓴다."
	note.position = Vector2(16, 44)
	note.size = Vector2(380, 40)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)
	var catalog = [
		["potion", "체력 물약", 50, "15초 동안 체력 150."],
		["boots", "속도의 장화", 300, "이동 속도 +25."],
		["ruby", "루비 결정", 400, "최대 체력 +150."],
	]
	var y = 100.0
	for item in catalog:
		var b = Button.new()
		b.text = "%s  %d" % [item[1], item[2]]
		b.position = Vector2(16, y)
		b.size = Vector2(380, 42)
		b.pressed.connect(_buy.bind(item[0], item[2]))
		panel.add_child(b)
		var d = Label.new()
		d.text = item[3]
		d.position = Vector2(16, y + 40)
		d.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
		panel.add_child(d)
		y += 78

func _plain_button(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 36)
	b.pressed.connect(cb)
	return b

func _fill(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0

func _font() -> Theme:
	var theme = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	theme.default_font = font
	theme.default_font_size = 15
	return theme

func _layout_hud() -> void:
	var view = get_viewport().get_visible_rect().size
	var scale = float(Settings.hud_scale)
	hud_panel.scale = Vector2.ONE * scale
	hud_panel.position = Vector2(view.x * 0.5 - 380 * scale, view.y - 150 * scale)
	if minimap:
		minimap.position = Vector2(view.x - 236, view.y - 236)

func _on_settings() -> void:
	cam_lock = bool(Settings.camera_locked) if not pause_open else cam_lock
	_layout_hud()
	_refresh_keys()
	Settings.apply_window()
	_apply_graphics()
	if bars_root:
		bars_root.visible = Settings.show_bars
	if player == null or name_label == null:
		return
	var legend_name = str(player_def.get("name", player.unit_name)) if not player_def.is_empty() else player.unit_name
	name_label.text = "%s  ·  %s" % [legend_name, player.username if player.username != "" else Settings.player_name]

func _apply_graphics() -> void:
	if environment == null or sun == null:
		return
	var vp = get_viewport()
	match Settings.aa_mode:
		"off":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
		"fxaa":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_taa = false
		"msaa2":
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
		"msaa4":
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
		"msaa8":
			vp.msaa_3d = Viewport.MSAA_8X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
		"taa_msaa":
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = true
		_:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = true
	vp.scaling_3d_scale = clampf(float(Settings.render_scale), 0.5, 2.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if Settings.render_scale >= 1.0 else Viewport.SCALING_3D_MODE_FSR2
	var shadow_sizes = {"low": 2048, "medium": 2048, "high": 4096, "ultra": 4096}
	RenderingServer.directional_shadow_atlas_set_size(int(shadow_sizes.get(Settings.shadow_quality, 2048)), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	sun.shadow_enabled = Settings.shadows
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 2200.0
	environment.glow_enabled = false
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.sdfgi_enabled = false
	environment.ssr_enabled = false
	environment.volumetric_fog_enabled = false
	environment.adjustment_brightness = clampf(float(Settings.brightness), 0.6, 1.6)
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.12
	if fps_label:
		fps_label.visible = Settings.show_fps

func _refresh_keys() -> void:
	for id in spell_buttons.keys():
		spell_buttons[id].text = Settings.key_label(Settings.key_of(id))
	for i in 7:
		item_buttons[i].text = Settings.key_label(Settings.key_of("i%d" % (i + 1)))

func _process(delta: float) -> void:
	if net_label:
		net_label.text = "%d ms    %d FPS" % [SolNet.ping_ms, Engine.get_frames_per_second()]
	if SolNet.remote_client():
		if player == null:
			return
		_follow_camera(delta)
		_update_hud()
		_update_bars()
		if score_held and score_layer:
			score_layer.visible = true
			_refresh_scoreboard()
		return
	if DisplayServer.get_name() == "headless":
		return
	_follow_camera(delta)
	_update_hud()
	_update_bars()
	_update_floaters(delta)
	_update_aim()
	_tick_feed(delta)
	_tick_recall_visual()
	_update_minimap()
	if score_held and score_layer and score_layer.visible:
		_refresh_scoreboard()
	if fps_label and fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if shot_path != "":
		shot_frames += 1
		if shot_frames == 150:
			var img = get_viewport().get_texture().get_image()
			img.save_png(shot_path)
			print("SHOT ", shot_path)
			get_tree().quit()

func _physics_process(delta: float) -> void:
	if SolNet.remote_client():
		return
	if paused:
		return
	clock += delta
	ping_cd = max(0.0, ping_cd - delta)
	for u in units:
		if u.kind != "champion" or u.dead:
			continue
		u.in_fight += delta
		if u.in_fight >= 15.0 and u.payable >= 0 and u.streak > u.payable:
			u.payable = u.streak
	_tick_player(delta)
	for u in units:
		if u == player:
			continue
		_think(u)
	_acquire_attack_moves()
	for u in units:
		u.step(delta, Callable(self, "blocked"))
		if u.kind != "tower" and u.kind != "nexus" and u.kind != "inhibitor":
			u.global_position.y = Rift.ground_y(u.global_position.x, u.global_position.z)
	_projectiles(delta)
	_shrines(delta)
	_deaths()
	_tick_camps(delta)
	wave_in -= delta
	if wave_in <= 0.0:
		wave_in = 14.0 if Draft.mode == "swift" else 30.0
		_spawn_wave("blue")
		_spawn_wave("red")
	if SolNet.serving():
		snap_acc += delta
		if snap_acc >= 0.1:
			snap_acc = 0.0
			SolNet.push_state(_pack_state())

func _tick_player(delta: float) -> void:
	for k in cd.keys():
		if cd[k] > 0.0:
			cd[k] = max(0.0, cd[k] - delta)
	var max_charges = int(_spec("w").get("charges", 0))
	if max_charges > 0 and w_charges < max_charges:
		w_charge_t += delta
		if w_charge_t >= float(_spec("w").get("recharge", 18.0)):
			w_charges += 1
			w_charge_t = 0.0
	if meeps < 1:
		meep_t += delta
		if meep_t >= 8.0:
			meeps = 1
			meep_t = 0.0
	if player.recall > 0.0 and not player.dead:
		player.recall -= delta
		if player.recall <= 0.0:
			player.global_position = SPAWN
			_say("기지로 돌아왔습니다.")
			Sfx.play("flash")
	if not player.dead and player.stasis <= 0.0 and _flat(player.global_position, FOUNTAIN) <= FOUNTAIN_R:
		player.vital.hp = min(player.vital.max_hp, player.vital.hp + player.vital.max_hp * 0.35 * delta)
		player.vital.mana = min(player.vital.max_mana, player.vital.mana + player.vital.max_mana * 0.35 * delta)
		player.vital.shown = max(player.vital.shown, player.vital.hp)
	if ult != null:
		ult.t += delta
		var t = clampf(ult.t / ult.dur, 0.0, 1.0)
		ult.node.global_position = Vector3(lerpf(ult.from.x, ult.to.x, t), sin(t * PI) * 180.0, lerpf(ult.from.z, ult.to.z, t))
		if ult.t >= ult.dur:
			_impact_ult(ult.to)
			ult.node.queue_free()
			ult = null

func _think(u) -> void:
	if u.dead or bool(u.get_meta("remote", false)):
		return
	if u.kind == "minion":
		var foe = _minion_focus(u)
		if foe:
			u.target = foe
			u.sticky = true
		else:
			u.target = null
			var idx = mini(u.lane_i, u.lane.size() - 1)
			var wp: Vector3 = u.lane[idx]
			if _flat(u.global_position, wp) < 50 and u.lane_i < u.lane.size() - 1:
				u.lane_i += 1
				wp = u.lane[u.lane_i]
			if u.target == null:
				u.dest = wp
				u.moving = true
	elif u.kind == "dummy" and u.chase:
		var home_d = _flat(u.global_position, u.home)
		var pd = _flat(u.global_position, player.global_position)
		if player.dead or home_d > u.leash:
			u.target = null
			u.dest = u.home
			u.moving = home_d > 30
			if u.vital.hp < u.vital.max_hp:
				u.vital.heal(40 * 0.016)
		elif pd < u.aggro:
			u.target = player
			u.sticky = true
	elif u.kind == "champion":
		_think_champion(u)
	elif u.kind == "monster":
		_think_monster(u)
	elif u.kind == "tower":
		u.target = _nearest_foe(u, u.attack_range, false)
		u.sticky = u.target != null

func _think_champion(u) -> void:
	if u.lane.size() == 0:
		return
	var idx = mini(u.lane_i, u.lane.size() - 1)
	var anchor: Vector3 = u.lane[idx]
	var hp_pct = 1.0 if u.vital.max_hp <= 0.0 else u.vital.hp / u.vital.max_hp
	if hp_pct < 0.32:
		u.target = null
		u.sticky = false
		u.dest = u.lane[maxi(0, idx - 1)]
		u.moving = true
		return
	var threat = _nearest_enemy_tower(u)
	if threat != null and _flat(u.global_position, threat.global_position) < 820.0 and hp_pct < 0.72:
		u.target = null
		u.sticky = false
		u.dest = anchor
		u.moving = _flat(u.global_position, anchor) > 80.0
		return
	var bite = _low_minion(u)
	if bite != null:
		u.target = bite
		u.sticky = true
		if _flat(u.global_position, bite.global_position) > u.attack_range + bite.radius:
			u.dest = bite.global_position
			u.moving = true
		else:
			u.moving = false
		return
	var foe = _nearest_foe(u, 720, false)
	if foe != null and foe.kind == "champion" and _flat(foe.global_position, anchor) < 900.0 and hp_pct > 0.45:
		if _flat(u.global_position, foe.global_position) <= u.attack_range + foe.radius:
			u.target = foe
			u.sticky = true
			u.moving = false
		else:
			u.target = null
			u.sticky = false
			u.dest = foe.global_position
			u.moving = true
		return
	u.target = null
	u.sticky = false
	if _flat(u.global_position, anchor) < 110 and u.lane_i < u.lane.size() - 1:
		u.lane_i += 1
		anchor = u.lane[u.lane_i]
	if u.role == "support" and u.lane_i > 2:
		u.lane_i = mini(u.lane_i, 4)
	u.dest = anchor
	u.moving = true

func _low_minion(u):
	var best = null
	var best_hp = 99999.0
	for o in units:
		if o.dead or o.team == u.team or o.kind != "minion":
			continue
		if _flat(o.global_position, u.global_position) > u.attack_range + 140.0:
			continue
		if o.vital.hp < best_hp and o.vital.hp <= u.ad * 2.4:
			best = o
			best_hp = o.vital.hp
	return best

func _nearest_enemy_tower(u):
	var best = null
	var best_d = 900.0
	for o in units:
		if o.dead or o.team == u.team or o.kind != "tower":
			continue
		var d = _flat(u.global_position, o.global_position)
		if d < best_d:
			best = o
			best_d = d
	return best

func _follow_camera(delta: float) -> void:
	shake = max(0.0, shake - delta * 28.0)
	var focus = player.global_position
	if focus_unit != null and is_instance_valid(focus_unit):
		focus = focus_unit.global_position
	var off = CAM_OFF * cam_zoom
	var desired = focus + off + cam_pan
	if cam_lock or space_held:
		cam_pan = Vector3.ZERO
		desired = focus + off
		camera.global_position = desired
	elif camera.global_position == Vector3.ZERO:
		camera.global_position = desired
	else:
		camera.global_position = focus + off + cam_pan
	if shake > 0.0:
		camera.global_position += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake
	camera.look_at(focus + cam_pan + Vector3(0, 40, 0), Vector3.UP)

func _update_hud() -> void:
	var v = player.vital
	var pct = 0.0 if v.max_hp <= 0 else v.hp / v.max_hp
	var ghost = 0.0 if v.max_hp <= 0 else v.shown / v.max_hp
	hp_fill.size.x = 360.0 * clampf(pct, 0, 1)
	hp_ghost.size.x = 360.0 * clampf(ghost, 0, 1)
	hp_fill.color = v.bar_color(player.team)
	hp_label.text = v.hp_text()
	var mp = 0.0 if v.max_mana <= 0 else v.mana / v.max_mana
	mp_fill.size.x = 360.0 * clampf(mp, 0, 1)
	mp_label.text = v.mana_text()
	ms_label.text = "이동 %d   방어 %d   마방 %d" % [int(round(player.speed())), int(round(v.armor)), int(round(v.mr))]
	gold_label.text = "%d 골드   CS %d   시야 %d" % [gold, cs, player.vision]
	if top_time:
		var secs = int(clock)
		top_time.text = "%d:%02d" % [int(secs / 60.0), secs % 60]
		top_blue.text = str(blue_kills)
		top_red.text = str(red_kills)
	death_label.visible = player.dead
	if player.dead:
		death_label.text = "전사했습니다  %d" % int(ceil(player.death_t))
	for id in spell_buttons.keys():
		var left = _spell_cd(id)
		var key = Settings.key_label(Settings.key_of(id))
		if id == "w" and int(_spec("w").get("charges", 0)) > 0:
			spell_buttons[id].text = "%s\n%d" % [key, w_charges]
		elif left > 0.05:
			spell_buttons[id].text = "%s\n%d" % [key, int(ceil(left))]
		else:
			spell_buttons[id].text = key
	for i in 6:
		var item = inventory[i]
		item_buttons[i].text = item.id.substr(0, 1) if item else Settings.key_label(Settings.key_of("i%d" % (i + 1)))
	item_buttons[6].text = "와" if cd["ward"] <= 0 else str(int(ceil(cd["ward"])))
	range_mesh.visible = bool(Settings.show_range) or aim == "amove"
	if range_mesh.visible:
		range_mesh.global_position = player.global_position + Vector3(0, 3, 0)

func _spell_cd(id: String) -> float:
	if id == "w" and int(_spec("w").get("charges", 0)) > 0:
		return 0.0 if w_charges > 0 else float(_spec("w").get("recharge", 18.0)) - w_charge_t
	if cd.has(id):
		return float(cd[id])
	return 0.0

func _update_bars() -> void:
	var alive = {}
	for u in units:
		alive[u.get_instance_id()] = u
		if not bar_nodes.has(u.get_instance_id()):
			bar_nodes[u.get_instance_id()] = _make_bar()
		var node: Control = bar_nodes[u.get_instance_id()]
		if u.dead and u.kind != "tower":
			node.visible = false
			continue
		if camera.is_position_behind(u.global_position):
			node.visible = false
			continue
		node.visible = true
		var lift = 70.0
		if u.kind == "champion":
			lift = 135.0
		elif u.kind == "monster":
			lift = 90.0 + u.radius * 1.4
		elif u.kind == "tower":
			lift = 280.0
		elif u.kind == "nexus":
			lift = 340.0
		elif u.kind == "inhibitor":
			lift = 210.0
		var screen = camera.unproject_position(u.global_position + Vector3(0, lift, 0))
		node.position = screen - Vector2(40, 14)
		var pct = 0.0 if u.vital.max_hp <= 0 else u.vital.hp / u.vital.max_hp
		var ghost = 0.0 if u.vital.max_hp <= 0 else u.vital.shown / u.vital.max_hp
		node.get_node("ghost").size.x = 74.0 * clampf(ghost, 0, 1)
		node.get_node("fill").size.x = 74.0 * clampf(pct, 0, 1)
		node.get_node("fill").color = u.vital.bar_color(u.team)
		var chunk = 100.0
		var pieces = int(u.vital.max_hp / chunk)
		for i in 8:
			var tick = node.get_node_or_null("tick%d" % i)
			if tick == null:
				continue
			var show = i > 0 and i < pieces
			tick.visible = show
			if show:
				tick.position.x = 3.0 + 74.0 * (float(i) * chunk / u.vital.max_hp)
		var bounty_lab = node.get_node_or_null("bounty")
		if bounty_lab:
			var extra = _shown_bounty(u)
			bounty_lab.visible = u.kind == "champion" and extra >= 150
			bounty_lab.text = str(extra)
		var uname = node.get_node_or_null("uname")
		if uname:
			if u.kind == "champion" and str(u.username) != "":
				uname.visible = true
				uname.text = u.username
			else:
				uname.visible = false
	var stale = []
	for id in bar_nodes.keys():
		if not alive.has(id):
			bar_nodes[id].queue_free()
			stale.append(id)
	for id in stale:
		bar_nodes.erase(id)

func _make_bar() -> Control:
	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(80, 14)
	var frame = ColorRect.new()
	frame.size = Vector2(80, 14)
	frame.color = Color(0.02, 0.02, 0.02, 0.95)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	var rim = ColorRect.new()
	rim.position = Vector2(1, 1)
	rim.size = Vector2(78, 12)
	rim.color = Color(0.72, 0.62, 0.38, 0.95)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rim)
	var bg = ColorRect.new()
	bg.position = Vector2(3, 3)
	bg.size = Vector2(74, 8)
	bg.color = Color(0.05, 0.05, 0.05, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var ghost = ColorRect.new()
	ghost.name = "ghost"
	ghost.position = Vector2(3, 3)
	ghost.size = Vector2(74, 8)
	ghost.color = Color(0.95, 0.92, 0.84)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ghost)
	var fill = ColorRect.new()
	fill.name = "fill"
	fill.position = Vector2(3, 3)
	fill.size = Vector2(74, 8)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	for i in 8:
		var tick = ColorRect.new()
		tick.name = "tick%d" % i
		tick.visible = false
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.color = Color(0, 0, 0, 0.55)
		tick.position = Vector2(3, 3)
		tick.size = Vector2(2, 8)
		root.add_child(tick)
	var uname = Label.new()
	uname.name = "uname"
	uname.visible = false
	uname.position = Vector2(-34, -18)
	uname.size = Vector2(140, 16)
	uname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uname.add_theme_font_size_override("font_size", 12)
	uname.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	uname.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	uname.add_theme_constant_override("outline_size", 4)
	uname.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(uname)
	var bounty_lab = Label.new()
	bounty_lab.name = "bounty"
	bounty_lab.visible = false
	bounty_lab.position = Vector2(76, -4)
	bounty_lab.size = Vector2(48, 16)
	bounty_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bounty_lab.add_theme_font_size_override("font_size", 12)
	bounty_lab.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	bounty_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bounty_lab)
	bars_root.add_child(root)
	return root

func _update_floaters(delta: float) -> void:
	for i in range(floaters.size() - 1, -1, -1):
		var f = floaters[i]
		f.life -= delta
		f.pos.y += 30.0 * delta
		if f.life <= 0 or camera.is_position_behind(f.pos):
			f.node.queue_free()
			floaters.remove_at(i)
			continue
		f.node.position = camera.unproject_position(f.pos)
		f.node.modulate.a = clampf(f.life / 0.7, 0, 1)

func _update_aim() -> void:
	aim_mesh.visible = aim != "" and aim != "amove" and not aim_pick
	if aim_mesh.visible:
		var ground = _mouse_ground()
		var origin = player.global_position + Vector3(0, 30, 0)
		var to = ground - origin
		to.y = 0
		var dist = to.length()
		if dist < 1:
			aim_mesh.visible = false
		else:
			var length = min(_spell_reach(aim), dist)
			var dir = to / dist
			var end = origin + dir * length
			aim_mesh.global_position = (origin + end) * 0.5
			aim_mesh.look_at(end, Vector3.UP)
			aim_mesh.scale = Vector3(18 if aim == "q" else 8, 6, length)
	_sync_target_rings()
	_update_cursor()
	_update_order_markers()

func _unhandled_input(event: InputEvent) -> void:
	if Settings.block_input:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if shop_open:
			shop_open = false
			shop_layer.visible = false
		elif aim != "":
			aim = ""
			aim_pick = false
		else:
			_set_pause(not pause_open)
		return
	if paused:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			rmb = true
			aim = ""
			aim_pick = false
			_issue_right(_mouse_ground())
		else:
			rmb = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if aim == "amove":
			player.command_attack_move(_mouse_ground())
			aim = ""
			aim_pick = false
		elif aim != "" and aim_pick:
			var who = _pick_unit(get_viewport().get_mouse_position())
			if who != null and _spell_target(who):
				if _flat(player.global_position, who.global_position) <= _spell_reach(aim) + who.radius:
					_begin_cast(aim, who.global_position)
					aim = ""
					aim_pick = false
				else:
					_say("사거리 밖입니다.")
					Sfx.play("error")
		elif aim != "":
			_begin_cast(aim, _point_at_range(aim))
			aim = ""
			aim_pick = false
		elif _can_act():
			var who = _pick_unit(get_viewport().get_mouse_position())
			if SolNet.remote_client():
				if who != null and _attackable(who):
					SolNet.cmd({"op": "attack", "id": int(who.get_meta("nid", -1))})
					_show_attack_marker(who)
				else:
					var spot = _mouse_ground()
					SolNet.cmd({"op": "amove", "x": spot.x, "z": spot.z})
			elif who != null and _attackable(who):
				player.command_attack(who)
				_show_attack_marker(who)
			else:
				player.command_attack_move(_mouse_ground())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		dragging = true
		lock_before = cam_lock
		cam_lock = false
	elif event is InputEventMouseMotion and dragging:
		var scale = Settings.mouse_pan * (-1.0 if Settings.invert_drag else 1.0)
		var right = camera.global_transform.basis.x
		right.y = 0
		var fwd = camera.global_transform.basis.z
		fwd.y = 0
		if right.length() > 0.01:
			right = right.normalized()
		if fwd.length() > 0.01:
			fwd = fwd.normalized()
		cam_pan -= right * event.relative.x * scale
		cam_pan += fwd * event.relative.y * scale
	elif event is InputEventKey and event.pressed and not event.echo:
		_key_down(event.keycode, event.shift_pressed)
	elif event is InputEventKey and not event.pressed:
		_key_up(event.keycode)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and not Settings.block_input:
		var slot = -1
		match event.keycode:
			KEY_F1:
				slot = 0
			KEY_F2:
				slot = 1
			KEY_F3:
				slot = 2
			KEY_F4:
				slot = 3
		if slot >= 0:
			if event.pressed:
				var mates = _teammates()
				focus_unit = mates[slot] if slot < mates.size() else null
			else:
				focus_unit = null
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB:
			score_held = event.pressed
			if score_layer:
				score_layer.visible = score_held
				if score_held:
					_refresh_scoreboard()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		rmb = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		dragging = false
		if lock_before:
			cam_lock = true
			cam_pan = Vector3.ZERO

func _key_down(code: int, shifted: bool = false) -> void:
	if code == Settings.key_of("center"):
		space_held = true
	elif code == Settings.key_of("q"):
		_arm("q", shifted)
	elif code == Settings.key_of("w"):
		_arm("w", shifted)
	elif code == Settings.key_of("e"):
		_arm("e", shifted)
	elif code == Settings.key_of("r"):
		_arm("r", shifted)
	elif code == Settings.key_of("d"):
		_flash()
	elif code == Settings.key_of("f"):
		_heal_summoner()
	elif code == Settings.key_of("recall"):
		_recall()
	elif code == Settings.key_of("shop"):
		_toggle_shop()
	elif code == Settings.key_of("stop"):
		player.stop_all()
		aim = ""
		aim_pick = false
	elif code == Settings.key_of("amove"):
		aim = "" if aim == "amove" else "amove"
	elif code == Settings.key_of("ping"):
		if ping_cd > 0.0:
			return
		ping_hold = true
		ping_from = get_viewport().get_mouse_position()
		wheel.visible = true
		wheel.position = ping_from - Vector2(130, 130)
	elif code == Settings.key_of("lock"):
		cam_lock = not cam_lock
		_say("시점을 고정했습니다." if cam_lock else "시점 고정을 해제했습니다.")
	elif code == Settings.key_of("i1"):
		_use_slot(0)
	elif code == Settings.key_of("i2"):
		_use_slot(1)
	elif code == Settings.key_of("i3"):
		_use_slot(2)
	elif code == Settings.key_of("i4"):
		_use_slot(3)
	elif code == Settings.key_of("i5"):
		_use_slot(4)
	elif code == Settings.key_of("i6"):
		_use_slot(5)
	elif code == Settings.key_of("i7"):
		_use_slot(6)

func _key_up(code: int) -> void:
	if code == Settings.key_of("center"):
		space_held = false
	if code == Settings.key_of("ping") and ping_hold:
		_release_ping()

func _arm(id: String, shifted: bool = false) -> void:
	if not _can_act():
		return
	var spec = _spec(id)
	var kind = str(spec.get("kind", "bolt"))
	var reach = float(spec.get("reach", 500.0))
	if kind == "smash" or (kind == "shield" and reach < 10.0):
		aim = ""
		aim_pick = false
		_begin_cast(id, player.global_position)
		return
	if shifted:
		aim = ""
		aim_pick = false
		_begin_cast(id, _point_at_range(id))
	else:
		aim = id
		aim_pick = true
		_say("적을 클릭하면 그 대상에게 사용합니다.")

func _spell_reach(id: String) -> float:
	var spec = _spec(id)
	if spec.has("reach"):
		return float(spec["reach"])
	match id:
		"q":
			return 850.0
		"w":
			return 800.0
		"e":
			return 480.0
		"r":
			return 3400.0
		_:
			return 500.0

func _point_at_range(id: String) -> Vector3:
	var ground = _mouse_ground()
	var origin = player.global_position
	var to = ground - origin
	to.y = 0
	var reach = _spell_reach(id)
	if to.length() < 8.0:
		var forward = -player.global_transform.basis.z
		forward.y = 0
		if forward.length() < 0.1:
			forward = Vector3(0, 0, -1)
		return origin + forward.normalized() * reach
	return origin + to.normalized() * min(reach, to.length())

func _spell_target(who) -> bool:
	if who == null or who.dead or who.team == player.team:
		return false
	return who.kind == "minion" or who.kind == "champion" or who.kind == "monster" or _structure(who)

func _sync_target_rings() -> void:
	var show = aim_pick and aim != "" and aim != "amove"
	var color = Color(1.0, 0.28, 0.22) if player.team == "blue" else Color(0.35, 0.62, 1.0)
	var pulse = 1.0 + sin(clock * 6.0) * 0.08
	for u in units:
		var id = u.get_instance_id()
		var want = show and _spell_target(u)
		if want and not target_rings.has(id):
			var ring = MeshInstance3D.new()
			var tor = TorusMesh.new()
			tor.inner_radius = u.radius * 0.85
			tor.outer_radius = u.radius * 1.15
			tor.rings = 24
			tor.ring_segments = 6
			ring.mesh = tor
			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			ring.material_override = mat
			add_child(ring)
			target_rings[id] = ring
		if not target_rings.has(id):
			continue
		var node = target_rings[id]
		node.visible = want and not u.dead
		if not node.visible:
			continue
		var in_range = _flat(player.global_position, u.global_position) <= _spell_reach(aim) + u.radius
		var mat = node.material_override
		mat.albedo_color = Color(color.r, color.g, color.b, 0.95 if in_range else 0.28)
		mat.emission = color
		mat.emission_energy_multiplier = 1.4 if in_range else 0.2
		node.global_position = u.global_position + Vector3(0, 8, 0)
		node.scale = Vector3.ONE * pulse
	var stale = []
	for id in target_rings.keys():
		var alive = false
		for u in units:
			if u.get_instance_id() == id:
				alive = true
				break
		if not alive:
			target_rings[id].queue_free()
			stale.append(id)
	for id in stale:
		target_rings.erase(id)

func _press_spell(id: String) -> void:
	if paused or Settings.block_input:
		return
	if id == "d":
		_flash()
	elif id == "f":
		_heal_summoner()
	else:
		_arm(id)

func _attackable(who) -> bool:
	if who == null or who.dead or who.team == player.team:
		return false
	if _champs_only() and who.kind != "champion":
		return false
	return true

func _champs_only() -> bool:
	return Input.is_key_pressed(Settings.key_of("champs"))

func _issue_right(ground: Vector3) -> void:
	if SolNet.remote_client():
		SolNet.cmd({"op": "move", "x": ground.x, "z": ground.z})
		_show_move_marker(ground)
		return
	var portal = _portal_at(ground)
	if portal != null and _flat(player.global_position, portal.a) < 220:
		_enter_portal(player, portal)
		return
	player.command_move(ground)
	_show_move_marker(ground)

func _begin_cast(id: String, ground: Vector3) -> void:
	if SolNet.remote_client():
		SolNet.cmd({"op": "cast", "slot": id, "x": ground.x, "z": ground.z})
		return
	if not _can_act():
		return
	if skills[id] <= 0:
		_say("아직 배우지 않은 스킬입니다.")
		return
	var spec = _spec(id)
	var cost = int(spec.get("cost", {"q": 60, "w": 70, "e": 30, "r": 100}.get(id, 50)))
	var charged = int(spec.get("charges", 0)) > 0
	if charged and w_charges <= 0:
		Sfx.play("error")
		return
	if not charged and cd.has(id) and float(cd[id]) > 0.0:
		Sfx.play("error")
		return
	if player.vital.mana < cost:
		_say("마나가 부족합니다.")
		Sfx.play("error")
		return
	player.vital.mana -= cost
	player.recall = 0.0
	player.cast_pose = id
	player.cast_left = 0.85
	player.face_point(ground)
	if charged:
		w_charges -= 1
		if w_charges < int(spec.get("charges", 2)) and w_charge_t <= 0.0:
			w_charge_t = 0.001
	else:
		cd[id] = float(spec.get("cd", 8.0))
	_cast_kind(str(spec.get("kind", "bolt")), ground, spec, id)

func _cast_kind(kind: String, ground: Vector3, spec: Dictionary, _id: String) -> void:
	match kind:
		"heal":
			_spell_heal(ground, spec)
		"shield":
			_spell_shield(ground, spec)
		"dash":
			_spell_dash(ground, float(spec.get("reach", 480.0)), 0.0)
		"blink":
			_spell_blink(ground, float(spec.get("reach", 400.0)))
		"leap":
			_spell_leap(ground, spec)
		"smash":
			_hit_area(player.global_position, float(spec.get("reach", 260.0)), float(spec.get("dmg", 80.0)), float(spec.get("stun", 0.0)), 0.0)
			_burst(player.global_position, float(spec.get("reach", 260.0)), Color(0.9, 0.55, 0.25))
			Sfx.play("q")
		"aoe":
			_spell_aoe(ground, spec, 180.0, 0.05)
		"rain":
			_spell_aoe(ground, spec, 260.0, 0.45)
		"portal":
			_spell_portal(ground, spec)
		"execute":
			_spell_execute(ground, spec)
		"cone":
			_spell_cone(ground, spec)
		"charge":
			_spell_charge(ground, spec)
		"mark":
			_spell_mark(ground, spec)
		"volley":
			_spell_volley(ground, spec)
		"slowfield":
			_spell_aoe(ground, spec, 200.0, 0.1)
			_slow_area(ground, 200.0, 0.45, 2.2)
		"haste":
			_spell_haste(ground, spec)
		"snipe":
			_spell_bolt(ground, spec, false)
		_:
			_spell_bolt(ground, spec, str(player.kit_name) == "wanderer")

func _dir_to(ground: Vector3) -> Vector3:
	var to = ground - player.global_position
	to.y = 0
	if to.length() < 1.0:
		to = -player.global_transform.basis.z
		to.y = 0
		if to.length() < 0.1:
			to = Vector3(0, 0, -1)
	return to.normalized()

func _clamp_point(ground: Vector3, reach: float) -> Vector3:
	var origin = player.global_position
	var to = ground - origin
	to.y = 0
	if to.length() > reach:
		to = to.normalized() * reach
	return origin + Vector3(to.x, 0, to.z)

func _spell_bolt(ground: Vector3, spec: Dictionary, pierce: bool) -> void:
	var bolt = Bolt.new()
	bolt.pos = player.global_position
	bolt.dir = _dir_to(ground)
	bolt.dmg = float(spec.get("dmg", 100.0))
	bolt.disable = float(spec.get("stun", 0.0))
	bolt.reach = float(spec.get("reach", 850.0))
	bolt.pierce = pierce
	bolt.caster = player
	bolts.append(bolt)
	Sfx.play("q")

func _spell_heal(ground: Vector3, spec: Dictionary) -> void:
	var point = _clamp_point(ground, float(spec.get("reach", 800.0)))
	for u in units:
		if u.dead or u.team != player.team:
			continue
		if u.kind != "champion" and u.kind != "ally":
			continue
		if _flat(point, u.global_position) < 150:
			_consume_shrine(u, 1.0)
			Sfx.play("w")
			return
	if shrines.size() >= 3:
		shrines.pop_front().mesh.queue_free()
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 28
	cyl.bottom_radius = 36
	cyl.height = 20
	mesh.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.95, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 1, 0.7)
	mat.emission_energy_multiplier = 0.5
	mesh.material_override = mat
	mesh.position = point + Vector3(0, 12, 0)
	add_child(mesh)
	var shrine = Shrine.new()
	shrine.pos = point
	shrine.mesh = mesh
	shrines.append(shrine)
	Sfx.play("w")

func _spell_shield(ground: Vector3, spec: Dictionary) -> void:
	var who = player
	var best = 99999.0
	for u in units:
		if u.dead or u.team != player.team:
			continue
		if u.kind != "champion" and u.kind != "ally":
			continue
		var d = _flat(ground, u.global_position)
		if d < best and d < 180.0:
			best = d
			who = u
	var heal = float(spec.get("heal", 90.0))
	var got: int = who.restore(heal)
	who.ms_buff = 0.2
	who.ms_buff_t = 2.0
	who.ms_buff_max = 2.0
	_float(who, "+%d" % got, Color(0.7, 0.9, 1.0))
	_burst(who.global_position, 90.0, Color(0.55, 0.75, 1.0))
	Sfx.play("w")

func _spell_dash(ground: Vector3, travel: float, dmg: float) -> Vector3:
	var origin = player.global_position
	var to = ground - origin
	to.y = 0
	var dir = Vector3.ZERO
	if to.length() < 16.0:
		dir = _dir_to(ground)
	else:
		dir = to.normalized()
		travel = min(travel, to.length())
	var dest = origin + dir * travel
	if blocked(dest.x, dest.z, player.radius):
		var lo = 0.0
		var hi = travel
		for _i in 12:
			var mid = (lo + hi) * 0.5
			var p = origin + dir * mid
			if blocked(p.x, p.z, player.radius):
				hi = mid
			else:
				lo = mid
		dest = origin + dir * lo
	player.begin_dash(dest, 0.36)
	player.cast_pose = ""
	player.cast_left = 0.0
	if dmg > 0.0:
		_hit_area(dest, 140.0, dmg, 0.0, 0.0)
	Sfx.play("dash")
	return dest

func _spell_blink(ground: Vector3, reach: float) -> void:
	var dest = _clamp_point(ground, reach)
	if blocked(dest.x, dest.z, player.radius):
		dest = _spell_dash(ground, reach, 0.0)
		return
	player.global_position = Vector3(dest.x, player.global_position.y, dest.z)
	player.moving = false
	player.dest = dest
	_burst(dest, 80.0, Color(0.55, 0.4, 0.95))
	Sfx.play("flash")

func _spell_leap(ground: Vector3, spec: Dictionary) -> void:
	var dest = _spell_dash(ground, float(spec.get("reach", 450.0)), 0.0)
	_hit_area(dest, 160.0, float(spec.get("dmg", 100.0)), float(spec.get("stun", 0.0)), 0.0)
	_burst(dest, 160.0, Color(0.9, 0.4, 0.18))

func _spell_aoe(ground: Vector3, spec: Dictionary, radius: float, delay: float) -> void:
	var point = _clamp_point(ground, float(spec.get("reach", 800.0)))
	_burst(point, radius, Color(0.75, 0.45, 1.0) if delay > 0.2 else Color(0.4, 0.7, 1.0))
	if delay <= 0.08:
		_hit_area(point, radius, float(spec.get("dmg", 100.0)), float(spec.get("stun", 0.0)), 0.0)
		Sfx.play("q")
		return
	var node = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 16
	sphere.height = 32
	node.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.9, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.85, 0.4)
	mat.emission_energy_multiplier = 1.1
	node.material_override = mat
	add_child(node)
	var shot = UltShot.new()
	shot.from = player.global_position + Vector3(0, 80, 0)
	shot.to = point + Vector3(0, 20, 0)
	shot.dur = max(0.35, delay)
	shot.node = node
	shot.mode = "rain"
	shot.dmg = float(spec.get("dmg", 200.0))
	shot.stun = float(spec.get("stun", 0.0))
	shot.radius = radius
	ult = shot
	Sfx.play("r")

func _spell_portal(ground: Vector3, spec: Dictionary) -> void:
	var origin = player.global_position
	var to = ground - origin
	to.y = 0
	var dist = to.length()
	var reach = min(float(spec.get("reach", 3400.0)), dist)
	var dir = to.normalized() if dist > 1 else Vector3(0, 0, -1)
	var dest = origin + dir * reach
	var ratio = clampf(reach / 3400.0, 0, 1)
	var node = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 18
	sphere.height = 36
	node.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.95, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.9, 0.6)
	mat.emission_energy_multiplier = 1.2
	node.material_override = mat
	add_child(node)
	var shot = UltShot.new()
	shot.from = origin
	shot.to = dest
	shot.dur = lerpf(0.65, 1.8, ratio)
	shot.node = node
	ult = shot
	Sfx.play("r")

func _spell_execute(ground: Vector3, spec: Dictionary) -> void:
	var dest = _spell_dash(ground, min(float(spec.get("reach", 420.0)), _flat(player.global_position, ground)), 0.0)
	var who = _nearest_enemy(dest, 180.0)
	if who == null:
		return
	var missing = 0.0
	if who.vital.max_hp > 0.0:
		missing = 1.0 - who.vital.hp / who.vital.max_hp
	var dmg = float(spec.get("dmg", 200.0)) * (1.0 + missing * 0.6)
	var dealt: int = who.hurt(dmg, "physical", player)
	_float(who, str(dealt), Color(1.0, 0.45, 0.3))
	if who.vital.hp <= 0.0:
		_reward(who)
	Sfx.play("slash")

func _spell_cone(ground: Vector3, spec: Dictionary) -> void:
	var dir = _dir_to(ground)
	var reach = float(spec.get("reach", 500.0))
	var dmg = float(spec.get("dmg", 90.0))
	var stun = float(spec.get("stun", 0.0))
	for u in units:
		if not _foe(u):
			continue
		var to = u.global_position - player.global_position
		to.y = 0
		var dist = to.length()
		if dist > reach + u.radius:
			continue
		if dir.dot(to.normalized()) < 0.55:
			continue
		var dealt: int = u.hurt(dmg, "physical", player)
		_float(u, str(dealt), Color(0.95, 0.85, 0.6))
		if stun > 0.0 and not _structure(u):
			_stun(u, stun)
		if u.vital.hp <= 0.0:
			_reward(u)
	_burst(player.global_position + dir * reach * 0.45, reach * 0.4, Color(0.85, 0.75, 0.4))
	Sfx.play("q")

func _spell_charge(ground: Vector3, spec: Dictionary) -> void:
	var dest = _spell_dash(ground, float(spec.get("reach", 800.0)), 0.0)
	_hit_area(dest, 180.0, float(spec.get("dmg", 200.0)), float(spec.get("stun", 1.0)), 0.0)
	_burst(dest, 180.0, Color(0.95, 0.7, 0.25))

func _spell_mark(ground: Vector3, spec: Dictionary) -> void:
	var who = _nearest_enemy(ground, 160.0)
	if who == null:
		who = _nearest_enemy(player.global_position + _dir_to(ground) * 200.0, 220.0)
	if who == null:
		Sfx.play("error")
		return
	var dealt: int = who.hurt(float(spec.get("dmg", 90.0)), "magic", player)
	who.slow = 0.35
	who.slow_t = 1.4
	_float(who, str(dealt), Color(0.85, 0.45, 1.0))
	if who.vital.hp <= 0.0:
		_reward(who)
	Sfx.play("q")

func _spell_volley(ground: Vector3, spec: Dictionary) -> void:
	var base = _dir_to(ground)
	for i in 3:
		var ang = deg_to_rad(float(i - 1) * 14.0)
		var dir = base.rotated(Vector3.UP, ang)
		var bolt = Bolt.new()
		bolt.pos = player.global_position
		bolt.dir = dir
		bolt.dmg = float(spec.get("dmg", 40.0))
		bolt.disable = 0.0
		bolt.reach = float(spec.get("reach", 800.0))
		bolt.pierce = false
		bolts.append(bolt)
	Sfx.play("q")

func _spell_haste(ground: Vector3, spec: Dictionary) -> void:
	var who = player
	var best = 99999.0
	for u in units:
		if u.dead or u.team != player.team:
			continue
		if u.kind != "champion" and u.kind != "ally":
			continue
		var d = _flat(ground, u.global_position)
		if d < best:
			best = d
			who = u
	who.ms_buff = 0.45
	who.ms_buff_t = 3.0
	who.ms_buff_max = 3.0
	_float(who, "가속", Color(0.7, 1.0, 0.75))
	_burst(who.global_position, 70.0, Color(0.55, 1.0, 0.65))
	Sfx.play("w")

func _hit_area(point: Vector3, radius: float, dmg: float, stun: float, slow: float) -> void:
	for u in units:
		if not _foe(u):
			continue
		if _flat(point, u.global_position) > radius + u.radius:
			continue
		var dealt: int = u.hurt(dmg, "magic", player)
		_float(u, str(dealt), Color(0.95, 0.75, 0.45))
		if not _structure(u):
			if stun > 0.0:
				_stun(u, stun)
			if slow > 0.0:
				u.slow = max(u.slow, slow)
				u.slow_t = max(u.slow_t, 1.6)
		if u.vital.hp <= 0.0:
			_reward(u)

func _slow_area(point: Vector3, radius: float, amount: float, dur: float) -> void:
	for u in units:
		if not _foe(u):
			continue
		if _flat(point, u.global_position) > radius + u.radius:
			continue
		u.slow = max(u.slow, amount)
		u.slow_t = max(u.slow_t, dur)

func _foe(u) -> bool:
	if u == null or u.dead or u.team == player.team:
		return false
	return u.kind == "champion" or u.kind == "minion" or u.kind == "monster" or _structure(u)

func _structure(u) -> bool:
	return u != null and (u.kind == "tower" or u.kind == "nexus" or u.kind == "inhibitor")

func _nearest_enemy(point: Vector3, radius: float):
	var best = null
	var dist = radius
	for u in units:
		if not _foe(u):
			continue
		var d = _flat(point, u.global_position)
		if d < dist:
			dist = d
			best = u
	return best

func _burst(point: Vector3, radius: float, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 8
	mesh.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.8
	mesh.material_override = mat
	mesh.position = point + Vector3(0, 6, 0)
	add_child(mesh)
	var timed = TimedMesh.new()
	timed.mesh = mesh
	timed.life = 0.35
	timed.max_life = 0.35
	pings.append(timed)

func _flash() -> void:
	if not _can_act() or cd["d"] > 0.0:
		Sfx.play("error")
		return
	var ground = _mouse_ground()
	var to = ground - player.global_position
	to.y = 0
	var dist = to.length()
	var dir = to.normalized() if dist > 12 else -player.global_transform.basis.z
	dir.y = 0
	dir = dir.normalized()
	var travel = min(400.0, dist if dist > 12 else 400.0)
	var dest = player.global_position + dir * travel
	if blocked(dest.x, dest.z, player.radius):
		var lo = 0.0
		var hi = travel
		for _i in 12:
			var mid = (lo + hi) * 0.5
			var p = player.global_position + dir * mid
			if blocked(p.x, p.z, player.radius):
				hi = mid
			else:
				lo = mid
		dest = player.global_position + dir * lo
	player.global_position = Vector3(dest.x, 0, dest.z)
	player.recall = 0.0
	player.windup = 0.0
	cd["d"] = 300
	Sfx.play("flash")

func _heal_summoner() -> void:
	if not _can_act() or cd["f"] > 0.0:
		Sfx.play("error")
		return
	var amount = 80.0 + 14.0 * 5.0
	var got: int = player.restore(amount)
	_float(player, "+%d" % got, Color(0.6, 0.95, 0.55))
	var ally = null
	var best = 2.0
	for u in units:
		if u == player or u.team != "blue" or u.dead:
			continue
		if u.kind != "ally" and u.kind != "champion":
			continue
		if _flat(player.global_position, u.global_position) > 800:
			continue
		var pct = u.vital.hp / u.vital.max_hp
		if pct < best:
			best = pct
			ally = u
	if ally:
		var n: int = ally.restore(amount)
		_float(ally, "+%d" % n, Color(0.6, 0.95, 0.55))
		ally.ms_buff = 0.3
		ally.ms_buff_t = 1.0
		ally.ms_buff_max = 1.0
	player.ms_buff = 0.3
	player.ms_buff_t = 1.0
	player.ms_buff_max = 1.0
	cd["f"] = 240
	player.recall = 0.0
	Sfx.play("heal")

func _recall() -> void:
	if not _can_act():
		return
	if _flat(player.global_position, FOUNTAIN) < 80:
		_say("이미 기지 한가운데 있습니다.")
		return
	player.stop_all()
	player.cast_pose = ""
	player.cast_left = 0.0
	player.windup = 0.0
	player.recall = 8.0
	_say("귀환을 시작합니다.")
	Sfx.play("recall")

func _toggle_shop() -> void:
	if shop_open:
		shop_open = false
		shop_layer.visible = false
		return
	if _flat(player.global_position, FOUNTAIN) > FOUNTAIN_R:
		_say("상점 범위 밖에 있습니다.")
		Sfx.play("error")
		return
	shop_open = true
	shop_layer.visible = true

func _buy(id: String, cost: int) -> void:
	if gold < cost:
		_say("골드가 부족합니다.")
		Sfx.play("error")
		return
	var slot = -1
	for i in 6:
		if inventory[i] == null:
			slot = i
			break
	if slot < 0:
		_say("가방이 가득 찼습니다.")
		return
	gold -= cost
	var bag = BagItem.new()
	bag.id = id
	bag.count = 1
	inventory[slot] = bag
	_recalc()
	Sfx.play("coin")

func _use_slot(index: int) -> void:
	if not _can_act():
		return
	if index == 6:
		if cd["ward"] > 0.0:
			Sfx.play("error")
			return
		var spot = _mouse_ground()
		var mesh = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 4
		cone.bottom_radius = 10
		cone.height = 28
		mesh.mesh = cone
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.8, 0.4)
		mesh.material_override = mat
		mesh.position = spot + Vector3(0, 14, 0)
		add_child(mesh)
		var ward = TimedMesh.new()
		ward.mesh = mesh
		ward.life = 90.0
		wards.append(ward)
		cd["ward"] = 90
		player.vision += 1
		return
	var item = inventory[index]
	if item == null or item.id != "potion":
		return
	if player.potion_t > 0.0:
		_say("이미 물약을 마시고 있습니다.")
		return
	if player.vital.hp >= player.vital.max_hp:
		_say("체력이 가득 찼습니다.")
		return
	item.count -= 1
	if item.count <= 0:
		inventory[index] = null
	player.potion_t = 15
	player.potion_left = 150
	Sfx.play("heal")

func _recalc() -> void:
	var bonus_ms = 0.0
	var bonus_hp = 0.0
	for item in inventory:
		if item == null:
			continue
		if item.id == "boots":
			bonus_ms += 25
		elif item.id == "ruby":
			bonus_hp += 150
	player.bonus_ms = bonus_ms
	var new_max = player.base_max_hp + bonus_hp
	var delta = new_max - player.vital.max_hp
	player.vital.max_hp = new_max
	player.vital.hp = clampf(player.vital.hp + max(delta, 0.0), 1, new_max)
	if delta < 0:
		player.vital.hp = min(player.vital.hp, new_max)
	player.vital.shown = max(player.vital.shown, player.vital.hp)

func _projectiles(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s = shots[i]
		if s.target == null or not is_instance_valid(s.target) or s.target.dead or s.target.stasis > 0.0:
			s.node.queue_free()
			shots.remove_at(i)
			continue
		var goal = s.target.global_position + Vector3(0, 40, 0)
		var to = goal - s.node.global_position
		var step = s.speed * delta
		var hull = _solid_radius(s.target)
		var arrive = to.length() <= step + 18.0 or (hull > 0.0 and to.length() <= hull + 16.0)
		if arrive:
			var dealt: int = s.target.hurt(s.dmg, "physical", s.from)
			if s.meep and s.target.stasis <= 0.0 and not s.target.dead:
				var extra: int = s.target.hurt(30, "magic", s.from)
				_float(s.target, str(extra), Color(0.85, 0.75, 1))
			if dealt > 0:
				_float(s.target, str(dealt), Color(0.95, 0.93, 0.88))
			Sfx.play("hit")
			if s.from != player and s.from.kind == "champion" and s.target.kind == "minion" and s.target.vital.hp <= 0.0:
				s.from.cs += 1
				s.from.purse += s.target.bounty
				s.from.farm_life += s.target.bounty
			if s.from == player and s.target.vital.hp <= 0.0:
				_reward(s.target)
			s.node.queue_free()
			shots.remove_at(i)
		else:
			var step_dir = to.normalized()
			var next = s.node.global_position + step_dir * step
			if blocked(next.x, next.z, 6.0):
				s.node.queue_free()
				shots.remove_at(i)
				continue
			s.node.global_position = next
			if to.length() > 1.0:
				s.node.look_at(s.node.global_position + to, Vector3.UP)
	for i in range(bolts.size() - 1, -1, -1):
		var b = bolts[i]
		var step = 1500.0 * delta
		b.pos += b.dir * step
		b.traveled += step
		if b.extra >= 0.0:
			b.extra += step
		var done = false
		if blocked(b.pos.x, b.pos.z, 8):
			var wall = _structure_at(b.pos.x, b.pos.z, 8.0)
			if wall != null and wall.team != player.team and not b.hit.has(wall.get_instance_id()):
				b.hit[wall.get_instance_id()] = true
				var dealt: int = wall.hurt(b.dmg, "magic", b.caster if b.caster != null else player)
				_float(wall, str(dealt), Color(0.82, 0.72, 1))
				if wall.vital.hp <= 0.0:
					_reward(wall)
			elif b.first != null and is_instance_valid(b.first):
				_stun(b.first, b.disable)
			done = true
		if not done:
			for u in units:
				if u.dead or u.team == player.team:
					continue
				if b.hit.has(u.get_instance_id()):
					continue
				var reach = _solid_radius(u) + 36.0 if _structure(u) else 60.0 + u.radius * 0.45
				if _flat(b.pos, u.global_position) > reach:
					continue
				b.hit[u.get_instance_id()] = true
				var dealt: int = u.hurt(b.dmg, "magic", b.caster if b.caster != null else player)
				_float(u, str(dealt), Color(0.82, 0.72, 1))
				if u.vital.hp <= 0.0:
					_reward(u)
				if _structure(u):
					done = true
					break
				if b.first == null:
					b.first = u
					b.extra = 0.0
					u.slow = 0.6
					u.slow_t = b.disable
				else:
					_stun(b.first, b.disable)
					_stun(u, b.disable)
					done = true
					break
		if not b.pierce and b.first != null:
			done = true
		if b.first != null and b.extra >= 300.0:
			done = true
		if b.first == null and b.traveled >= b.reach:
			done = true
		if done:
			bolts.remove_at(i)

func _shrines(delta: float) -> void:
	for i in range(shrines.size() - 1, -1, -1):
		var s = shrines[i]
		s.t += delta
		var used = false
		for u in units:
			if u.dead or u.stasis > 0.0:
				continue
			if u.kind != "champion" and u.kind != "ally" and u.kind != "dummy":
				continue
			if _flat(u.global_position, s.pos) > 72:
				continue
			if u.team != "blue":
				used = true
				break
			_consume_shrine(u, clampf(s.t / 5.0, 0, 1))
			used = true
			break
		if used:
			s.mesh.queue_free()
			shrines.remove_at(i)
	for i in range(portals.size() - 1, -1, -1):
		portals[i].life -= delta
		if portals[i].life <= 0:
			portals[i].mesh_a.queue_free()
			portals[i].mesh_b.queue_free()
			portals.remove_at(i)
	for i in range(wards.size() - 1, -1, -1):
		wards[i].life -= delta
		if wards[i].life <= 0:
			wards[i].mesh.queue_free()
			wards.remove_at(i)
	for i in range(pings.size() - 1, -1, -1):
		pings[i].life -= delta
		var alpha = clampf(pings[i].life / pings[i].max_life, 0.0, 1.0)
		if pings[i].label:
			if camera and not camera.is_position_behind(pings[i].pos):
				pings[i].label.visible = true
				pings[i].label.position = camera.unproject_position(pings[i].pos)
				pings[i].label.modulate.a = alpha
			else:
				pings[i].label.visible = false
		if pings[i].life <= 0:
			if pings[i].label:
				pings[i].label.queue_free()
			pings[i].mesh.queue_free()
			pings.remove_at(i)

func _acquire_attack_moves() -> void:
	for u in units:
		if u.dead or not u.attack_moving:
			continue
		if u.target != null and is_instance_valid(u.target) and not u.target.dead:
			continue
		var foe = _nearest_foe(u, u.attack_range + 36.0, true)
		if foe != null:
			u.target = foe
			u.sticky = true
			u.moving = false
		else:
			u.sticky = false
			u.dest = u.attack_move_point
			u.moving = _flat(u.global_position, u.attack_move_point) > 16.0
			if not u.moving:
				u.attack_moving = false

func _deaths() -> void:
	var remove = []
	for u in units:
		if not u.dead:
			continue
		if u.kind == "champion" and not u.scored:
			u.scored = true
			Sfx.play("death")
			if u.kind != "minion":
				_note_kill(u)
		if u.kind == "nexus" and not ended:
			ended = true
			Sfx.play("nexus")
			var winner := "red" if u.team == "blue" else "blue"
			_say("%s 넥서스가 파괴되었습니다." % ("붉은" if u.team == "red" else "푸른"))
			if StrifeAcc.logged_in() and player != null:
				StrifeAcc.function_call("strife-queue", {"op": "result", "won": player.team == winner, "mode": Draft.mode})
				StrifeAcc.load_progress()
			paused = true
		if u.death_t > 0.0:
			continue
		if u.kind == "tower" or u.kind == "nexus" or u.kind == "inhibitor":
			continue
		if u.kind == "minion" or u.kind == "monster":
			if u.kind == "monster":
				if u.last_attacker == player:
					gold += u.bounty
					_float(u, "+%d" % u.bounty, Color(0.95, 0.84, 0.45))
					Sfx.play("coin")
					if u.style == "boss":
						_banner("균열의 거수를 쓰러뜨렸습니다!")
					elif u.style == "dragon":
						_banner("골짜기룡을 쓰러뜨렸습니다!")
				if u.camp != null:
					var alive_mates = false
					for o in units:
						if o != u and o.camp == u.camp and not o.dead:
							alive_mates = true
							break
					if not alive_mates:
						camp_timers.append({"def": u.camp, "t": float(u.camp["respawn"])})
			remove.append(u)
		elif u.kind == "champion":
			var side = u.team
			u.revive(u.home if u != player else SPAWN)
			u.lane_i = 0
			u.scored = false
			u.hit_tags.clear()
			_close_penta(side)
			if u == player:
				_say("기지에서 다시 깨어났습니다.")
	for u in remove:
		units.erase(u)
		u.queue_free()

func _basic_power(source, target) -> float:
	var power = source.ad
	if source.kind == "champion":
		power *= 1.85
	elif source.kind == "minion" and target.kind == "champion":
		power *= 0.35
	return power

func _on_basic(target, source) -> void:
	if source == null or target == null:
		return
	if source.is_melee():
		var dealt: int = target.hurt(_basic_power(source, target), "physical", source)
		if dealt > 0:
			_float(target, str(dealt), Color(0.95, 0.93, 0.88))
		if source.kind == "tower":
			Sfx.play("tower")
		elif source.kind == "champion":
			Sfx.play_as(str(source.style), "slash" if source.is_melee() else "hit")
		elif source.attack_range < 220.0:
			Sfx.play("slash")
		else:
			Sfx.play("hit")
		if source != player and source.kind == "champion" and target.kind == "minion" and target.vital.hp <= 0.0:
			source.cs += 1
			source.purse += target.bounty
			source.farm_life += target.bounty
		if source == player and target.vital.hp <= 0.0:
			_reward(target)
		_melee_flash(target.global_position, source.team)
		return
	if source.kind == "tower":
		Sfx.play("tower")
	elif source.kind == "champion":
		Sfx.play_as(str(source.style), "attack")
	var mesh = MeshInstance3D.new()
	var bolt = BoxMesh.new()
	bolt.size = Vector3(5, 5, 34)
	mesh.mesh = bolt
	var tint = Color(0.75, 0.9, 1.0) if source.team == "blue" else Color(1.0, 0.55, 0.4)
	mesh.material_override = _glow_mat(tint)
	mesh.position = source.global_position + Vector3(0, 62, 0)
	add_child(mesh)
	var meep = false
	if source == player and meeps > 0 and target.kind != "tower" and target.kind != "nexus" and target.kind != "inhibitor":
		meeps = 0
		meep_t = 0
		meep = true
		bolt.size = Vector3(8, 8, 40)
	var shot = Shot.new()
	shot.node = mesh
	shot.target = target
	shot.from = source
	shot.dmg = _basic_power(source, target)
	shot.meep = meep
	shot.speed = 2200.0 if source.kind == "champion" else 1650.0
	shots.append(shot)

func _melee_flash(point: Vector3, team: String) -> void:
	var mesh = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 18
	tor.outer_radius = 28
	mesh.mesh = tor
	var tint = Color(0.9, 0.95, 1.0) if team == "blue" else Color(1.0, 0.6, 0.45)
	mesh.material_override = _glow_mat(tint)
	mesh.position = point + Vector3(0, 36, 0)
	add_child(mesh)
	var ping = TimedMesh.new()
	ping.mesh = mesh
	ping.life = 0.16
	ping.max_life = 0.16
	pings.append(ping)

func _consume_shrine(u, power: float) -> void:
	var rank = skills["w"] - 1
	var min_h = [25, 50, 75, 100, 125][rank]
	var max_h = [50, 87.5, 125, 162.5, 200][rank]
	var amount = lerpf(min_h, max_h, power)
	var got: int = u.restore(amount)
	_float(u, "+%d" % got, Color(0.65, 0.95, 0.55))
	var ms = [0.20, 0.225, 0.25, 0.275, 0.30][rank]
	u.ms_buff = ms
	u.ms_buff_t = 1.5
	u.ms_buff_max = 1.5
	Sfx.play("heal")

func _impact_ult(point: Vector3) -> void:
	if ult != null and ult.mode == "rain":
		_hit_area(point, ult.radius, ult.dmg, ult.stun, 0.0)
		_burst(point, ult.radius, Color(1.0, 0.7, 0.3))
		if Settings.shake:
			shake = 24.0
		Sfx.play("r")
		return
	for u in units:
		if u.dead:
			continue
		if _flat(u.global_position, point) <= 350.0 + u.radius * 0.25:
			u.stasis = 2.5
			u.moving = false
			u.windup = 0.0
			u.target = null
			u.recall = 0.0
	if Settings.shake:
		shake = 36.0
	Sfx.play("r")

func _stun(u, dur: float) -> void:
	if u == null or not is_instance_valid(u) or u.dead or u.kind == "tower" or u.stasis > 0.0:
		return
	u.stun = max(u.stun, dur)
	u.slow_t = 0.0
	u.moving = false
	u.windup = 0.0
	u.recall = 0.0

func _reward(u) -> void:
	if u.kind != "minion":
		return
	if _flat(player.global_position, u.global_position) > 1100:
		return
	gold += u.bounty
	cs += 1
	player.cs = cs
	player.farm_life += u.bounty
	_raise_idle_stage(player, u.bounty)
	_float(u, "+%d" % u.bounty, Color(0.95, 0.84, 0.45))
	Sfx.play("coin")

func _float(u, text: String, color: Color) -> void:
	if not Settings.damage_numbers or text == "0" or text == "+0":
		return
	var lab = Label.new()
	lab.text = text
	lab.add_theme_color_override("font_color", color)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_root.add_child(lab)
	var floater = Floater.new()
	floater.node = lab
	floater.pos = u.global_position + Vector3(randf_range(-10, 10), 120, 0)
	floaters.append(floater)

func _say(text: String) -> void:
	feed.text = text

func _release_ping() -> void:
	ping_hold = false
	wheel.visible = false
	var now = get_viewport().get_mouse_position()
	var delta = now - ping_from
	var kind = "alert"
	if delta.length() > 28:
		var deg = rad_to_deg(atan2(delta.y, delta.x))
		if deg < -45 and deg >= -135:
			kind = "danger"
		elif deg >= 45 and deg < 135:
			kind = "help"
		elif abs(deg) > 135:
			kind = "missing"
		else:
			kind = "omw"
	var names = {"alert": "주의", "danger": "위험!", "missing": "적 사라짐!", "help": "도와주세요!", "omw": "갑니다!"}
	_say(names[kind])
	var ground = _mouse_ground()
	var colors = {
		"alert": Color(0.95, 0.86, 0.45),
		"danger": Color(1.0, 0.28, 0.22),
		"missing": Color(0.95, 0.82, 0.25),
		"help": Color(0.35, 0.62, 1.0),
		"omw": Color(0.35, 0.9, 0.5),
	}
	var tint = colors[kind]
	var holder = Node3D.new()
	holder.position = ground
	add_child(holder)
	var ring = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 46
	tor.outer_radius = 58
	tor.rings = 28
	tor.ring_segments = 6
	ring.mesh = tor
	ring.position = Vector3(0, 6, 0)
	ring.material_override = _glow_mat(tint)
	holder.add_child(ring)
	var beam = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 5
	cyl.bottom_radius = 5
	cyl.height = 160
	beam.mesh = cyl
	beam.position = Vector3(0, 86, 0)
	beam.material_override = _glow_mat(tint)
	holder.add_child(beam)
	var lab = Label.new()
	lab.text = names[kind]
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", tint)
	float_root.add_child(lab)
	var ping = TimedMesh.new()
	ping.mesh = holder
	ping.life = 3.2
	ping.max_life = 3.2
	ping.label = lab
	ping.pos = ground + Vector3(0, 150, 0)
	pings.append(ping)
	Sfx.play("ping")
	ping_cd = 0.4

func _set_pause(open: bool) -> void:
	pause_open = open
	paused = open
	pause_layer.visible = open
	if open:
		shop_open = false
		shop_layer.visible = false

func _open_settings() -> void:
	var menu = MenuScript.new()
	add_child(menu)
	paused = true
	menu.closed.connect(func():
		paused = pause_open
	)

func _reset_cooldowns() -> void:
	for k in cd.keys():
		cd[k] = 0.0
	_sync_charges()
	if not player.dead:
		player.vital.mana = player.vital.max_mana
		player.vital.hp = player.vital.max_hp
		player.vital.shown = player.vital.max_hp
	_say("스킬과 자원을 되돌렸습니다.")

func _can_act() -> bool:
	return not player.dead and player.stun <= 0.0 and player.stasis <= 0.0

func _mouse_ground() -> Vector3:
	var mouse = get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mouse)
	var dir = camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.00001:
		return player.global_position
	var t = -origin.y / dir.y
	if t < 0.0:
		return player.global_position
	var hit = origin + dir * t
	hit.y = 0
	return hit

func _pick_unit(screen: Vector2):
	var origin = camera.project_ray_origin(screen)
	var dir = camera.project_ray_normal(screen)
	var best = null
	var best_t = 1.0e12
	for u in units:
		if u.dead:
			continue
		var center = u.global_position + Vector3(0, 50, 0)
		var oc = origin - center
		var b = oc.dot(dir)
		var c = oc.dot(oc) - pow(u.radius + 24.0, 2)
		var h = b * b - c
		if h < 0.0:
			continue
		var t = -b - sqrt(h)
		if t > 0.0 and t < best_t:
			best_t = t
			best = u
	return best

func _portal_at(ground: Vector3):
	for portal in portals:
		if _flat(ground, portal.a) < 90:
			return portal
	return null

func _enter_portal(u, portal) -> void:
	if u.dead or u.stun > 0.0 or u.stasis > 0.0:
		return
	u.global_position = Vector3(portal.b.x, 0, portal.b.z)
	u.moving = false
	u.recall = 0.0

func _find_portal(from: Vector3, toward: Vector3):
	var to = toward - from
	to.y = 0
	if to.length() < 1:
		return null
	var dir = to.normalized()
	var seen = false
	var entrance = Vector3.ZERO
	for i in range(1, 91):
		var p = from + dir * float(i * 10)
		if _point_in_wall(p.x, p.z):
			if not seen:
				seen = true
				entrance = from + dir * float((i - 1) * 10)
			if float(i * 10) > 900 and not seen:
				return null
		elif seen:
			var gate = Gate.new()
			gate.a = entrance
			gate.b = p
			return gate
		elif float(i * 10) > 900:
			return null
	return null

func _portal_marker(point: Vector3) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 26
	torus.outer_radius = 40
	mesh.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 1, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 1, 0.9)
	mat.emission_energy_multiplier = 0.7
	mesh.material_override = mat
	mesh.position = point + Vector3(0, 8, 0)
	add_child(mesh)
	return mesh

func _minion_focus(u):
	var revenge = u.last_attacker
	if revenge != null and is_instance_valid(revenge) and not revenge.dead and revenge.team != u.team and revenge.kind == "champion":
		if _flat(u.global_position, revenge.global_position) < 360:
			return revenge
	var creep = _nearest_of(u, 420, "minion")
	if creep != null:
		return creep
	var building = _nearest_of(u, 480, "tower")
	if building == null:
		building = _nearest_of(u, 480, "inhibitor")
	if building == null:
		building = _nearest_of(u, 520, "nexus")
	return building

func _nearest_of(u, radius: float, kind_name: String):
	var best = null
	var best_d = radius
	for o in units:
		if o.dead or o.team == u.team or o.kind != kind_name:
			continue
		var d = _flat(u.global_position, o.global_position)
		if d < best_d:
			best = o
			best_d = d
	return best

func _nearest_foe(u, radius: float, structures: bool = true):
	var best = null
	var best_d = radius
	for o in units:
		if o.dead or o.team == u.team or o.stasis > 0.0:
			continue
		if o.kind == "monster":
			continue
		if not structures and (o.kind == "tower" or o.kind == "nexus" or o.kind == "inhibitor"):
			continue
		if u == player and _champs_only() and o.kind != "champion":
			continue
		var d = _flat(u.global_position, o.global_position)
		if d < best_d:
			best = o
			best_d = d
	return best

func blocked(x: float, z: float, r: float) -> bool:
	if x < r or z < r or x > WORLD - r or z > WORLD - r:
		return true
	if _point_near_wall(x, z, r):
		return true
	return _hits_solid(x, z, r)

func _solid_radius(u) -> float:
	if u == null or u.dead:
		return 0.0
	if u.kind == "tower" or u.kind == "inhibitor" or u.kind == "nexus":
		return u.radius
	return 0.0

func _structure_at(x: float, z: float, r: float):
	for u in units:
		var body = _solid_radius(u)
		if body <= 0.0:
			continue
		if Vector2(x - u.global_position.x, z - u.global_position.z).length() < body + r * 0.9:
			return u
	return null

func _hits_solid(x: float, z: float, r: float) -> bool:
	for u in units:
		var body = _solid_radius(u)
		if body <= 0.0:
			continue
		if Vector2(x - u.global_position.x, z - u.global_position.z).length() < body + r * 0.9:
			return true
	return false

func _point_in_wall(x: float, z: float) -> bool:
	for w in walls:
		if x >= w.position.x and x <= w.position.x + w.size.x and z >= w.position.y and z <= w.position.y + w.size.y:
			return true
	return false

func _point_near_wall(x: float, z: float, r: float) -> bool:
	for w in walls:
		var cx = clampf(x, w.position.x, w.position.x + w.size.x)
		var cz = clampf(z, w.position.y, w.position.y + w.size.y)
		if Vector2(x - cx, z - cz).length() < r:
			return true
	return false

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _pointer_on_ui() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE

func _wheel_disc() -> ImageTexture:
	var img = Image.create(260, 260, false, Image.FORMAT_RGBA8)
	var c = Vector2(130, 130)
	for y in 260:
		for x in 260:
			var d = Vector2(float(x), float(y)).distance_to(c)
			if d < 118.0:
				img.set_pixel(x, y, Color(0.04, 0.05, 0.08, 0.72))
			elif d < 124.0:
				img.set_pixel(x, y, Color(0.85, 0.74, 0.42, 0.9))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _glow_mat(tint: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _make_cursors() -> void:
	cursor_move = _cursor_image("move")
	cursor_attack = _cursor_image("attack")
	cursor_cast = _cursor_image("cast")

func _cursor_image(kind: String) -> ImageTexture:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if kind == "move":
		_paint_arrow(img)
	else:
		var tint = Color(0.95, 0.18, 0.14) if kind == "attack" else Color(0.45, 0.88, 1.0)
		_paint_reticle(img, tint, kind == "attack")
	return ImageTexture.create_from_image(img)

func _stamp(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var prev = img.get_pixel(x, y)
	var a = color.a + prev.a * (1.0 - color.a)
	if a <= 0.001:
		return
	var rgb = (color * color.a + prev * prev.a * (1.0 - color.a)) / a
	img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, a))

func _paint_arrow(img: Image) -> void:
	var outline = Color(0.28, 0.16, 0.02, 1.0)
	var fill = Color(1.0, 0.86, 0.18, 1.0)
	var edge = Color(1.0, 0.72, 0.08, 1.0)
	for y in 64:
		for x in 64:
			var p = Vector2(float(x) + 0.5, float(y) + 0.5)
			var body = _arrow_dist(p)
			if body > 1.6:
				continue
			var col = outline
			if body < -1.15:
				col = fill
			elif body < -0.2:
				col = edge
			var alpha = clampf(1.15 - body, 0.0, 1.0)
			col.a = alpha
			_stamp(img, x, y, col)

func _arrow_dist(p: Vector2) -> float:
	var tip = Vector2(8, 6)
	var heel = Vector2(8, 46)
	var notch = Vector2(18, 34)
	var tail = Vector2(34, 50)
	var side = Vector2(22, 28)
	var d1 = _seg_dist(p, tip, side)
	var d2 = _seg_dist(p, side, tail)
	var d3 = _seg_dist(p, tail, notch)
	var d4 = _seg_dist(p, notch, heel)
	var d5 = _seg_dist(p, heel, tip)
	var edge = min(d1, min(d2, min(d3, min(d4, d5))))
	if _in_arrow(p):
		return -edge
	return edge

func _in_arrow(p: Vector2) -> bool:
	var poly = PackedVector2Array([
		Vector2(8, 6), Vector2(22, 28), Vector2(34, 50), Vector2(18, 34), Vector2(8, 46)
	])
	var inside = false
	var j = poly.size() - 1
	for i in poly.size():
		var a = poly[i]
		var b = poly[j]
		if ((a.y > p.y) != (b.y > p.y)) and (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x):
			inside = not inside
		j = i
	return inside

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var den = ab.length_squared()
	var t = 0.0 if den <= 0.001 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _paint_reticle(img: Image, tint: Color, attack: bool) -> void:
	var c = Vector2(32, 32)
	var ink = Color(0.05, 0.04, 0.04, 1.0)
	for y in 64:
		for x in 64:
			var p = Vector2(float(x) + 0.5, float(y) + 0.5)
			var d = p.distance_to(c)
			var ring = absf(d - 16.0)
			var tick = 99.0
			if absf(p.x - 32.0) < 1.15 and (p.y < 12.0 or p.y > 52.0):
				tick = absf(p.x - 32.0)
			if absf(p.y - 32.0) < 1.15 and (p.x < 12.0 or p.x > 52.0):
				tick = min(tick, absf(p.y - 32.0))
			var mark = min(ring, tick)
			if attack and d < 3.2:
				mark = min(mark, 3.2 - d)
			if mark > 1.5:
				continue
			var col = ink if mark > 0.55 else tint
			col.a = clampf(1.2 - mark, 0.0, 1.0)
			_stamp(img, x, y, col)

func _update_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hot = Vector2(8, 6)
	var tex = cursor_move
	if aim_pick:
		tex = cursor_cast
		hot = Vector2(32, 32)
	else:
		var who = _pick_unit(get_viewport().get_mouse_position())
		if who != null and _attackable(who):
			tex = cursor_attack
			hot = Vector2(32, 32)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hot)

func _make_order_markers() -> void:
	order_ring = _flat_ring(Color(1.0, 0.82, 0.16), 34, 46)
	order_pulse = _flat_ring(Color(1.0, 0.9, 0.35), 20, 28)
	attack_ring = _flat_ring(Color(1.0, 0.35, 0.28), 40, 52)
	order_ring.visible = false
	order_pulse.visible = false
	attack_ring.visible = false
	recall_ring = _flat_ring(Color(0.45, 0.82, 1.0), 40, 54)
	recall_ring.visible = false
	recall_column = MeshInstance3D.new()
	var beam = CylinderMesh.new()
	beam.top_radius = 10
	beam.bottom_radius = 34
	beam.height = 160
	recall_column.mesh = beam
	recall_column.material_override = _glow_mat(Color(0.55, 0.86, 1.0))
	recall_column.visible = false
	add_child(recall_column)

func _flat_ring(tint: Color, inner: float, outer: float) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = inner
	tor.outer_radius = outer
	tor.rings = 32
	tor.ring_segments = 6
	mesh.mesh = tor
	mesh.material_override = _glow_mat(tint)
	add_child(mesh)
	return mesh

func _show_move_marker(ground: Vector3) -> void:
	attack_ring.visible = false
	order_ring.visible = true
	order_ring.global_position = ground + Vector3(0, 6, 0)
	order_pulse.visible = true
	order_pulse.global_position = ground + Vector3(0, 7, 0)
	order_pulse.scale = Vector3.ONE
	var pulse_mat = order_pulse.material_override as StandardMaterial3D
	if pulse_mat:
		pulse_mat.albedo_color.a = 1.0

func _show_attack_marker(who) -> void:
	order_ring.visible = false
	order_pulse.visible = false
	attack_ring.visible = true
	attack_ring.global_position = who.global_position + Vector3(0, 6, 0)

func _update_order_markers() -> void:
	if order_pulse.visible:
		order_pulse.scale += Vector3.ONE * 4.0 * get_process_delta_time()
		var mat = order_pulse.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = max(0.0, 1.0 - (order_pulse.scale.x - 1.0) / 3.0)
		if order_pulse.scale.x > 4.0:
			order_pulse.visible = false
	if order_ring.visible and player:
		if not player.moving or _flat(player.global_position, order_ring.global_position) < 40.0:
			order_ring.visible = false
	if attack_ring.visible and player and player.target and is_instance_valid(player.target) and not player.target.dead:
		attack_ring.global_position = player.target.global_position + Vector3(0, 6, 0)
	else:
		attack_ring.visible = false

func _note_kill(victim) -> void:
	if victim.kind != "champion":
		return
	var now = Time.get_ticks_msec() / 1000.0
	var killer = victim.last_attacker
	var executed = true
	var credited = null
	if killer != null and is_instance_valid(killer) and killer.kind == "champion":
		executed = false
		credited = killer
	elif victim.last_champion != null and is_instance_valid(victim.last_champion) and now - victim.last_champ_hit <= 15.0:
		executed = false
		credited = victim.last_champion
	if executed:
		_banner("처형되었습니다!")
		_push_kill("%s님이 처형되었습니다" % _who(victim))
		return
	if victim.team == "blue":
		red_kills += 1
	else:
		blue_kills += 1
	var ally = credited.team == player.team
	var was_streak = victim.streak
	var was_fb = first_blood
	var next_multi = 1
	if credited.multi_t > 0.0 and not (credited.multi >= 4 and credited.penta_blocked):
		next_multi = credited.multi + 1
	else:
		credited.penta_blocked = false
	if was_fb:
		first_blood = false
		_banner("선취점!")
		_push_kill("%s님이 선취점 달성!" % _who(credited))
	elif next_multi < 2:
		if victim == player:
			_banner("적에게 당했습니다!")
		elif victim.team == player.team:
			_banner("아군이 당했습니다!")
		else:
			_banner("적을 처치했습니다!")
	_push_kill("%s님이 %s님을 처치했습니다" % [_who(credited), _who(victim)])
	_pay_kill(victim, credited, was_fb)
	if credited.payable < 0:
		credited.payable = 0
	credited.multi = next_multi
	if credited.multi >= 4 and not credited.penta_blocked:
		credited.multi_t = 30.0
	else:
		credited.multi_t = 10.0
	credited.streak += 1
	if credited.multi >= 2:
		_banner(_multi_line(credited, ally))
	if credited.streak >= 3:
		_banner(_spree_line(credited, ally))
	if was_streak >= 3:
		_banner("제압되었습니다!")
		_push_kill("%s님이 %s님의 연속 킬을 차단했습니다!" % [_who(credited), _who(victim)])
	_settle_death_bounty(victim)
	if _team_wiped(victim.team):
		_banner("마무리!")
		_push_kill("마지막 적 처치!")

func _pay_kill(victim, credited, was_fb: bool) -> void:
	var stage = victim.payable
	var amount = _kill_gold(stage) + _farm_bounty(victim)
	amount = int(round(float(amount) * _bounty_scale(victim, credited)))
	var paid = amount
	if paid > 1000:
		paid = 1000
	if was_fb:
		paid = max(paid, 400)
	_give_gold(credited, paid)
	credited.kills += 1
	victim.deaths += 1
	var pool = _assist_pool(stage, was_fb)
	var helpers = victim.assisters(credited, Time.get_ticks_msec() / 1000.0)
	if helpers.size() > 0 and pool > 0:
		var each = max(1, int(pool / helpers.size()))
		for helper in helpers:
			_give_gold(helper, each)
			helper.assists += 1

func _settle_death_bounty(victim) -> void:
	var fresh = max(0, victim.streak - max(victim.payable, 0))
	if victim.payable >= 8:
		var remain = _kill_gold(victim.payable) - 1000
		victim.payable = _stage_for_gold(remain)
		victim.streak = 0
		victim.streak_pending = fresh
	elif fresh > 0:
		victim.payable = fresh
		victim.streak = 0
	elif victim.payable > 0:
		victim.payable = 0
		victim.streak = 0
	else:
		victim.payable = max(-6, victim.payable - 1)
		victim.streak = 0
	victim.multi = 0
	victim.multi_t = 0.0
	victim.penta_blocked = false
	var avg = _enemy_farm(victim.team)
	if victim.farm_life < avg:
		victim.farm_subsidy = avg - victim.farm_life
	else:
		victim.farm_subsidy = 0
	victim.farm_life = 0

func _kill_gold(stage: int) -> int:
	if stage >= 8:
		return 1000 + 100 * (stage - 7)
	match stage:
		7:
			return 1000
		6:
			return 900
		5:
			return 800
		4:
			return 700
		3:
			return 600
		2:
			return 450
		1:
			return 300
		0:
			return 300
		-1:
			return 274
		-2:
			return 220
		-3:
			return 176
		-4:
			return 140
		-5:
			return 112
		_:
			return 100

func _assist_base(stage: int) -> int:
	if stage >= 1:
		return 150
	match stage:
		0:
			return 150
		-1:
			return 137
		-2:
			return 110
		-3:
			return 88
		-4:
			return 70
		-5:
			return 56
		_:
			return 50

func _assist_pool(stage: int, was_fb: bool) -> int:
	var t = 1.0 if clock >= 210.0 else clampf(clock / 210.0, 0.0, 1.0)
	if was_fb:
		return int(round(lerpf(100.0, 200.0, t)))
	var full = float(_assist_base(stage))
	var early = lerpf(50.0, full, t) if stage >= 0 else lerpf(full * 0.5, full, t)
	return int(round(early if clock < 210.0 else full))

func _farm_bounty(victim) -> int:
	var counted = max(0, victim.farm_life - victim.farm_subsidy)
	var avg = _enemy_farm(victim.team)
	var over = counted - avg - 250
	if over < 0:
		return 0
	return 50 + 50 * int(over / 200.0)

func _enemy_farm(team: String) -> int:
	var sum = 0
	var n = 0
	for u in units:
		if u.kind == "champion" and u.team != team:
			sum += u.farm_life
			n += 1
	if n == 0:
		return 0
	return int(sum / n)

func _team_purse(team: String) -> int:
	var sum = 0
	for u in units:
		if u.kind != "champion" or u.team != team:
			continue
		sum += gold if u == player else u.purse
	return sum

func _bounty_scale(victim, credited) -> float:
	var theirs = _team_purse(victim.team)
	var ours = _team_purse(credited.team)
	if ours <= 0 or theirs >= ours:
		return 1.0
	return clampf(float(theirs) / float(ours), 0.2, 1.0)

func _shown_bounty(u) -> int:
	if u.kind != "champion":
		return 0
	var extra = _kill_gold(u.payable) - 300
	extra += _farm_bounty(u)
	return max(0, extra)

func _stage_for_gold(remain: int) -> int:
	if remain >= 1000:
		return 7 + int((remain - 1000) / 100.0)
	if remain >= 900:
		return 6
	if remain >= 800:
		return 5
	if remain >= 700:
		return 4
	if remain >= 600:
		return 3
	if remain >= 450:
		return 2
	if remain >= 300:
		return 1
	return 0

func _give_gold(u, amount: int) -> void:
	if u == null or amount <= 0:
		return
	if u == player:
		gold += amount
	else:
		u.purse += amount
	_raise_idle_stage(u, amount)
	_float(u, "+%d" % amount, Color(0.95, 0.84, 0.45))

func _raise_idle_stage(u, amount: int) -> void:
	if u.payable > 0:
		return
	u.gold_bucket += amount
	while u.gold_bucket >= 1000 and u.payable <= 0:
		u.gold_bucket -= 1000
		u.payable += 1

func _who(u) -> String:
	var nick = str(u.username)
	if nick == "":
		if u == player:
			nick = StrifeAcc.current() if StrifeAcc.logged_in() else Settings.player_name
		else:
			nick = u.unit_name
	if nick == u.unit_name:
		return u.unit_name
	return "%s(%s)" % [nick, u.unit_name]

func _team_wiped(team: String) -> bool:
	var any = false
	for u in units:
		if u.kind != "champion" or u.team != team:
			continue
		any = true
		if not u.dead:
			return false
	return any

func _close_penta(revived_team: String) -> void:
	for u in units:
		if u.kind == "champion" and u.team != revived_team and u.multi >= 4:
			u.penta_blocked = true
			u.multi_t = min(u.multi_t, 10.0)

func _spree_line(killer, ally: bool) -> String:
	match killer.streak:
		3:
			return "학살 중입니다!" if ally else "적이 학살 중입니다!"
		4:
			return "미쳐 날뛰고 있습니다!" if ally else "적이 미쳐 날뛰고 있습니다!"
		5:
			return "도저히 막을 수 없습니다!" if ally else "적을 도저히 막을 수 없습니다!"
		6:
			return "전장의 지배자!" if ally else "적이 전장을 지배하고 있습니다!"
		7:
			return "전장의 화신!" if ally else "적은 전장의 화신입니다!"
		_:
			return "전설의 출현!" if ally else "적은 전설적입니다!"

func _multi_line(killer, ally: bool) -> String:
	match killer.multi:
		2:
			return "더블 킬!" if ally else "적, 더블 킬!"
		3:
			return "트리플 킬!" if ally else "적, 트리플 킬!"
		4:
			return "쿼드라 킬!" if ally else "적, 쿼드라 킬!"
		5:
			return "펜타 킬!" if ally else "적, 펜타 킬!"
		_:
			return "헥사 킬!" if ally else "적, 헥사 킬!"

func _batchim(text: String) -> bool:
	if text.is_empty():
		return false
	var code = text.unicode_at(text.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return false
	return (code - 0xAC00) % 28 != 0

func _ga(text: String) -> String:
	return text + ("이" if _batchim(text) else "가")

func _eul(text: String) -> String:
	return text + ("을" if _batchim(text) else "를")

func _push_kill(text: String) -> void:
	if kill_log == null:
		_say(text)
		return
	var lab = Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	kill_log.add_child(lab)
	var line = FeedLine.new()
	line.node = lab
	line.life = 5.0
	kill_lines.append(line)
	while kill_lines.size() > 5:
		var old = kill_lines.pop_front()
		if old.node:
			old.node.queue_free()

func _banner(text: String) -> void:
	var shout = Shout.new()
	shout.text = text
	shouts.append(shout)
	Sfx.play("chime")

func _tick_feed(delta: float) -> void:
	if announce:
		if shouts.size() > 0:
			var shout = shouts[0]
			announce.visible = true
			announce.text = shout.text
			shout.life -= delta
			announce.modulate.a = clampf(shout.life / 0.45, 0.0, 1.0)
			if shout.life <= 0.0:
				shouts.pop_front()
				if shouts.is_empty():
					announce.visible = false
		else:
			announce.visible = false
	for i in range(kill_lines.size() - 1, -1, -1):
		kill_lines[i].life -= delta
		if kill_lines[i].node:
			kill_lines[i].node.modulate.a = clampf(kill_lines[i].life / 0.8, 0.0, 1.0)
		if kill_lines[i].life <= 0.0:
			if kill_lines[i].node:
				kill_lines[i].node.queue_free()
			kill_lines.remove_at(i)

func _tick_recall_visual() -> void:
	var channeling = player != null and player.recall > 0.0 and not player.dead
	if recall_bar:
		recall_bar.visible = channeling
		if channeling:
			var pct = clampf(1.0 - player.recall / 8.0, 0.0, 1.0)
			recall_bar.offset_left = -140
			recall_bar.offset_right = -140 + 280.0 * pct
	if recall_ring:
		recall_ring.visible = channeling
		if channeling:
			recall_ring.global_position = player.global_position + Vector3(0, 8, 0)
			var grow = 1.0 + (1.0 - player.recall / 8.0) * 0.65
			recall_ring.scale = Vector3(grow, 1, grow)
	if recall_column:
		recall_column.visible = channeling
		if channeling:
			var pct = clampf(1.0 - player.recall / 8.0, 0.05, 1.0)
			recall_column.global_position = player.global_position + Vector3(0, 40 + 80.0 * pct, 0)
			recall_column.scale = Vector3(1, pct, 1)

func bind_remote(peer: int, username: String) -> void:
	for u in units:
		if u.kind == "champion" and str(u.username) == username:
			u.set_meta("remote", true)
			u.target = null
			u.moving = false
			peer_units[peer] = u
			return

func apply_remote(peer: int, cmd: Dictionary) -> void:
	var u = peer_units.get(peer)
	if u == null or u.dead:
		return
	var op := str(cmd.get("op", ""))
	if op == "move":
		u.command_move(Vector3(float(cmd.get("x", 0.0)), 0, float(cmd.get("z", 0.0))))
	elif op == "amove":
		u.command_attack_move(Vector3(float(cmd.get("x", 0.0)), 0, float(cmd.get("z", 0.0))))
	elif op == "attack":
		var target = _unit_by_nid(int(cmd.get("id", -1)))
		if target != null:
			u.command_attack(target)
	elif op == "cast":
		var prev = player
		var prev_def = player_def
		player = u
		player_def = Legends.by_name(u.unit_name)
		_begin_cast(str(cmd.get("slot", "q")), Vector3(float(cmd.get("x", 0.0)), 0, float(cmd.get("z", 0.0))))
		player = prev
		player_def = prev_def

func _unit_by_nid(id: int):
	for u in units:
		if int(u.get_meta("nid", -1)) == id:
			return u
	return null

func _pack_state() -> Array:
	var rows: Array = []
	for u in units:
		if u.kind == "minion" and u.dead:
			continue
		rows.append({
			"id": int(u.get_meta("nid", 0)),
			"k": u.kind,
			"t": u.team,
			"x": u.global_position.x,
			"z": u.global_position.z,
			"yaw": u.rotation.y,
			"hp": u.vital.hp,
			"mh": u.vital.max_hp,
			"d": u.dead,
			"n": u.unit_name,
			"un": u.username,
			"r": u.role,
			"st": u.style,
			"kk": u.kills,
			"dd": u.deaths,
			"aa": u.assists,
			"cs": cs if u == player else u.cs,
			"g": gold if u == player else u.purse,
			"lv": u.level,
			"mv": u.moving,
		})
	rows.append({"id": -1, "clock": clock})
	return rows

func apply_net_state(rows: Array) -> void:
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var id := int(row.get("id", -1))
		if id < 0:
			clock = float(row.get("clock", clock))
			continue
		var u = net_puppets.get(id, null)
		if u == null:
			u = _spawn_puppet(row)
			net_puppets[id] = u
		var x := float(row.get("x", 0.0))
		var z := float(row.get("z", 0.0))
		u.global_position = Vector3(x, Rift.ground_y(x, z), z)
		u.rotation.y = float(row.get("yaw", 0.0))
		u.vital.max_hp = maxf(1.0, float(row.get("mh", 1.0)))
		u.vital.hp = float(row.get("hp", u.vital.hp))
		u.vital.shown = u.vital.hp
		u.dead = bool(row.get("d", false))
		u.moving = bool(row.get("mv", false))
		u.kills = int(row.get("kk", 0))
		u.deaths = int(row.get("dd", 0))
		u.assists = int(row.get("aa", 0))
		u.cs = int(row.get("cs", 0))
		u.purse = int(row.get("g", 0))
		u.level = int(row.get("lv", 1))
		if str(u.username) == StrifeAcc.current():
			player = u
			gold = u.purse
			cs = u.cs
			if name_label:
				name_label.text = "%s  ·  %s" % [u.unit_name, u.username]

func _spawn_puppet(row: Dictionary):
	var kind := str(row.get("k", "minion"))
	var u = _make_unit(kind, str(row.get("t", "blue")), str(row.get("n", "")), Vector3.ZERO, 36.0 if kind == "champion" else 30.0)
	u.set_meta("nid", int(row.get("id", 0)))
	u.username = str(row.get("un", ""))
	u.role = str(row.get("r", ""))
	u.style = str(row.get("st", ""))
	if kind == "champion":
		var def = Legends.by_name(u.unit_name)
		if def.is_empty():
			u.build_visual()
		else:
			_apply_legend(u, def, u.username, false)
	else:
		u.build_visual()
	return u

func _run_headless_checks() -> void:
	var origin = player.global_position
	var goal = origin + Vector3(5000, 0, 0)
	for _i in 60:
		player.command_move(goal)
		player.step(1.0 / 60.0, Callable(self, "blocked"))
	var traveled = player.global_position.x - origin.x
	var dummy = Unit.new()
	dummy.team = "red"
	dummy.kind = "dummy"
	dummy.setup(1600, 30, 30, 0)
	var dealt: int = dummy.hurt(160, "magic")
	var hp_left = dummy.vital.hp
	var speed_ok = abs(traveled - 330.0) < 1.0
	var hp_ok = dealt == 123 and is_equal_approx(hp_left, 1477)
	print("SPEED %.2f %s" % [traveled, "PASS" if speed_ok else "FAIL"])
	print("HP %d %.0f %s" % [dealt, hp_left, "PASS" if hp_ok else "FAIL"])
	get_tree().quit(0 if speed_ok and hp_ok else 1)
