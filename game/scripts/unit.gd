extends Node3D

const Vital = preload("res://scripts/health.gd")

var team = "blue"
var unit_name = ""
var kind = "minion"
var radius = 36.0
var vital = null
var base_ms = 325.0
var base_max_hp = 0.0
var role = ""
var bonus_ms = 0.0
var ad = 0.0
var attack_range = 0.0
var attack_speed = 0.65
var slow = 0.0
var slow_t = 0.0
var stun = 0.0
var stasis = 0.0
var dead = false
var death_t = 0.0
var moving = false
var dest = Vector3.ZERO
var target = null
var sticky = false
var attack_moving = false
var attack_move_point = Vector3.ZERO
var atk_cd = 0.0
var windup = 0.0
var windup_full = 0.0
var windup_locked = false
var last_attacker = null
var streak = 0
var multi = 0
var multi_t = 0.0
var passive_ms = 0.0
var in_fight = 20.0
var meep_count = 0
var step_charges: Array = []
var step_dash = Vector3.ZERO
var step_dash_on = false
var base_range = -1.0
var base_asp = -1.0
var face_yaw = 0.0
var has_face = false
var home = Vector3.ZERO
var hold = false
var recall = 0.0
var potion_t = 0.0
var potion_left = 0.0
var ms_buff = 0.0
var ms_buff_t = 0.0
var ms_buff_max = 1.0
var hit_flash = 0.0
var lane: Array = []
var lane_name = ""
var lane_i = 1
var bounty = 0
var payable = 0
var streak_pending = 0
var purse = 0
var farm_life = 0
var farm_subsidy = 0
var gold_bucket = 0
var last_champ_hit = -100.0
var last_champion = null
var hit_tags: Array = []
var penta_blocked = false
var vision = 0
var xp_value = 0
var style = ""
var tint = Color(0.2, 0.35, 0.7)
var username = ""
var legend_id = ""
var kit_name = ""
var dash_to = Vector3.ZERO
var dash_from = Vector3.ZERO
var dash_left = 0.0
var dash_full = 0.36
var scored = false
var chase = false
var cast_pose = ""
var cast_left = 0.0
var avatar = null
var aggro = 0.0
var leash = 0.0
var body_mat: Material
var meep: MeshInstance3D
var spin = 0.0
var limbs = {}
var walk_phase = 0.0
var gem_mat: StandardMaterial3D

signal basic_attack(who)

func setup(max_hp: float, armor_v: float, mr_v: float, regen_v: float) -> void:
	vital = Vital.new()
	vital.max_hp = max_hp
	vital.hp = max_hp
	vital.shown = max_hp
	vital.armor = armor_v
	vital.mr = mr_v
	vital.regen = regen_v

class HitTag:
	var who = null
	var at = 0.0

func _note_champ_hit(attacker) -> void:
	if attacker == null or attacker.kind != "champion":
		return
	last_champion = attacker
	last_champ_hit = Time.get_ticks_msec() / 1000.0
	for tag in hit_tags:
		if tag.who == attacker:
			tag.at = last_champ_hit
			return
	var tag = HitTag.new()
	tag.who = attacker
	tag.at = last_champ_hit
	hit_tags.append(tag)

func assisters(killer, now: float) -> Array:
	var found = []
	for tag in hit_tags:
		if tag.who == null or not is_instance_valid(tag.who):
			continue
		if tag.who == killer or tag.who.kind != "champion":
			continue
		if now - tag.at > 10.0:
			continue
		found.append(tag.who)
	return found

func speed() -> float:
	var ms = base_ms + bonus_ms
	if slow_t > 0.0:
		ms *= 1.0 - slow
	if ms_buff_t > 0.0 and ms_buff_max > 0.0:
		ms *= 1.0 + ms_buff * (ms_buff_t / ms_buff_max)
	if passive_ms > 0.0:
		ms *= 1.0 + passive_ms
	return ms

func hurt(raw: float, kind_name: String, attacker = null) -> int:
	if dead or stasis > 0.0:
		return 0
	if attacker != null and is_instance_valid(attacker) and attacker != self:
		last_attacker = attacker
		attacker.in_fight = 0.0
		_note_champ_hit(attacker)
	in_fight = 0.0
	var amount: int = vital.damage(raw, kind_name)
	if amount > 0:
		hit_flash = 0.1
		recall = 0.0
		if body_mat is StandardMaterial3D:
			(body_mat as StandardMaterial3D).emission_energy_multiplier = 1.4
	if vital.hp <= 0.0:
		die()
	return amount

func restore(amount: float) -> int:
	if dead or stasis > 0.0:
		return 0
	return vital.heal(amount)

func die() -> void:
	dead = true
	vital.hp = 0.0
	if kind == "minion":
		death_t = 0.4
	elif kind == "monster":
		death_t = 2.2
	elif kind == "tower" or kind == "nexus" or kind == "inhibitor":
		death_t = 99999.0
	else:
		death_t = 8.0
	moving = false
	target = null
	attack_moving = false
	windup = 0.0
	recall = 0.0
	visible = true
	if body_mat is StandardMaterial3D and (kind == "tower" or kind == "nexus" or kind == "inhibitor"):
		(body_mat as StandardMaterial3D).albedo_color = Color(0.18, 0.16, 0.15)
		(body_mat as StandardMaterial3D).emission_energy_multiplier = 0.0
	elif body_mat is ShaderMaterial and (kind == "tower" or kind == "nexus" or kind == "inhibitor"):
		(body_mat as ShaderMaterial).set_shader_parameter("stone", Vector3(0.18, 0.16, 0.15))

func revive(point: Vector3) -> void:
	dead = false
	visible = true
	stun = 0.0
	stasis = 0.0
	slow_t = 0.0
	vital.hp = vital.max_hp
	vital.shown = vital.max_hp
	if vital.max_mana > 0.0:
		vital.mana = vital.max_mana
	global_position = point
	home = point

func command_move(point: Vector3) -> void:
	target = null
	sticky = false
	attack_moving = false
	dest = point
	moving = true
	recall = 0.0
	dash_left = 0.0
	face_point(point)

func command_attack(who) -> void:
	target = who
	sticky = true
	attack_moving = false
	moving = false
	recall = 0.0
	dash_left = 0.0
	if who != null:
		face_point(who.global_position)
	if who != null and attack_range > 0.0 and atk_cd <= 0.0 and ad > 0.0:
		var reach = _hit_reach(who)
		if flat(global_position, who.global_position) <= reach:
			_begin_swing()
			face_point(who.global_position)

func command_attack_move(point: Vector3) -> void:
	target = null
	sticky = false
	attack_moving = true
	attack_move_point = point
	dest = point
	moving = true
	recall = 0.0
	face_point(point)

func stop_all() -> void:
	moving = false
	target = null
	sticky = false
	attack_moving = false
	windup = 0.0
	recall = 0.0

func step(delta: float, is_blocked: Callable) -> void:
	if dead:
		death_t -= delta
		return
	if hit_flash > 0.0:
		hit_flash -= delta
		if body_mat is StandardMaterial3D and hit_flash <= 0.0:
			(body_mat as StandardMaterial3D).emission_energy_multiplier = 0.15 if kind == "champion" else 0.0
	if potion_t > 0.0 and potion_left > 0.0:
		var bite = min(potion_left, 10.0 * delta)
		potion_left -= bite
		potion_t -= delta
		vital.heal(bite)
	if ms_buff_t > 0.0:
		ms_buff_t -= delta
	if stasis <= 0.0:
		vital.tick(delta)
	if stasis > 0.0:
		stasis -= delta
		moving = false
		return
	if stun > 0.0:
		stun -= delta
		moving = false
		windup = 0.0
		dash_left = 0.0
		return
	if dash_left > 0.0:
		_step_dash(delta, is_blocked)
		return
	if slow_t > 0.0:
		slow_t -= delta
	if atk_cd > 0.0:
		atk_cd -= delta
	if multi_t > 0.0:
		multi_t -= delta
		if multi_t <= 0.0:
			multi = 0
	if recall > 0.0:
		moving = false
		return
	if target != null and (not is_instance_valid(target) or target.dead or target.stasis > 0.0):
		target = null
	if target != null and attack_range > 0.0:
		var reach = _hit_reach(target)
		var dist = flat(global_position, target.global_position)
		if dist <= reach:
			moving = false
			face_point(target.global_position)
			if windup <= 0.0 and atk_cd <= 0.0 and ad > 0.0:
				_begin_swing()
		elif sticky and not hold:
			dest = target.global_position
			moving = true
		elif not sticky:
			target = null
	if moving:
		var to = dest - global_position
		to.y = 0.0
		var dist2 = to.length()
		var ms = speed()
		var step_len = ms * delta
		if dist2 <= step_len or dist2 < 8.0:
			if not is_blocked.call(dest.x, dest.z, radius):
				global_position = Vector3(dest.x, 0.0, dest.z)
			moving = false
			if windup > 0.0 and not windup_locked:
				windup = 0.0
		else:
			var dir = to / dist2
			var nx = global_position.x + dir.x * step_len
			var nz = global_position.z + dir.z * step_len
			if not is_blocked.call(nx, nz, radius):
				global_position = Vector3(nx, 0.0, nz)
			elif not is_blocked.call(nx, global_position.z, radius):
				global_position.x = nx
			elif not is_blocked.call(global_position.x, nz, radius):
				global_position.z = nz
			else:
				moving = false
			if windup > 0.0 and not windup_locked:
				windup = 0.0
			face_point(global_position + dir)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0 and target != null and is_instance_valid(target) and not target.dead:
			var reach = _hit_reach(target) + 24.0
			if flat(global_position, target.global_position) <= reach:
				atk_cd = 1.0 / attack_speed
				face_point(target.global_position)
				basic_attack.emit(target)
				windup_locked = false
			else:
				atk_cd = 0.05

func _hit_reach(who) -> float:
	if who.kind == "tower" or who.kind == "nexus" or who.kind == "inhibitor":
		return attack_range + who.radius + 48.0
	return attack_range + who.radius * 0.25

func _begin_swing() -> void:
	windup_full = clampf(0.025 / max(attack_speed, 0.25), 0.016, 0.035)
	windup = windup_full
	windup_locked = style == "warlord" and step_charges.size() > 0

func is_melee() -> bool:
	return attack_range < 300.0

func begin_dash(dest: Vector3, dur: float = 0.36) -> void:
	dash_from = global_position
	dash_to = dest
	dash_full = maxf(dur, 0.18)
	dash_left = dash_full
	moving = false
	target = null
	sticky = false
	windup = 0.0
	recall = 0.0
	var aim = dest - global_position
	aim.y = 0.0
	if aim.length() > 8.0:
		face_point(dest)
		rotation.y = face_yaw

func _step_dash(delta: float, is_blocked: Callable) -> void:
	dash_left -= delta
	var span = maxf(dash_full, 0.01)
	var u = clampf(1.0 - dash_left / span, 0.0, 1.0)
	var e = u * u * (3.0 - 2.0 * u)
	var next = dash_from.lerp(dash_to, e)
	next.y = 0.0
	if is_blocked.call(next.x, next.z, radius):
		dash_left = 0.0
		return
	var dir = next - global_position
	dir.y = 0.0
	global_position = Vector3(next.x, 0.0, next.z)
	if dir.length() > 4.0:
		face_point(global_position + dir)
		rotation.y = face_yaw
	if dash_left <= 0.0:
		if not is_blocked.call(dash_to.x, dash_to.z, radius):
			global_position = Vector3(dash_to.x, 0.0, dash_to.z)
		dash_left = 0.0

func face_point(point: Vector3) -> void:
	var aim = Vector3(point.x, global_position.y, point.z)
	if aim.distance_squared_to(global_position) < 9.0:
		return
	var keep = rotation
	look_at(aim, Vector3.UP)
	face_yaw = rotation.y
	rotation = keep
	has_face = true

func _turn_toward(delta: float) -> void:
	if not has_face:
		return
	var diff = wrapf(face_yaw - rotation.y, -PI, PI)
	var step = 12.0 * delta
	if absf(diff) <= step:
		rotation.y = face_yaw
	else:
		rotation.y += signf(diff) * step

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

var model_scale = 1.0
var camp = null
var kills = 0
var deaths = 0
var assists = 0
var cs = 0
var level = 1

func build_visual() -> void:
	if kind == "champion" or kind == "monster":
		avatar = preload("res://scripts/avatar.gd").new()
		avatar.setup(style if style != "" else "wanderer", tint, model_scale)
		add_child(avatar)
		return
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.55
	mat.metallic = 0.08
	mat.emission_enabled = true
	mat.emission = Color(1, 0.95, 0.8)
	mat.emission_energy_multiplier = 0.0
	body_mat = mat
	if kind == "champion":
		_build_humanoid(mat, 1.0)
	elif kind == "minion":
		_build_humanoid(mat, 0.62)
	elif kind == "tower":
		_build_tower()
	elif kind == "inhibitor":
		_build_inhibitor()
	elif kind == "nexus":
		_build_nexus()
	elif kind == "ally":
		mat.albedo_color = Color(0.16, 0.32, 0.55)
		_build_humanoid(mat, 0.9)
	else:
		mat.albedo_color = Color(0.42, 0.24, 0.16)
		_build_humanoid(mat, 0.85)
	var shadow = StandardMaterial3D.new()
	shadow.albedo_color = Color(0, 0, 0, 0.4)
	shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc = CylinderMesh.new()
	disc.top_radius = radius * 0.85
	disc.bottom_radius = radius * 0.85
	disc.height = 2.0
	var sm = MeshInstance3D.new()
	sm.mesh = disc
	sm.material_override = shadow
	sm.position = Vector3(0, 1, 0)
	add_child(sm)

func _team_color() -> Color:
	if team == "blue":
		return Color(0.25, 0.48, 0.95)
	return Color(0.9, 0.28, 0.22)

func _build_humanoid(mat: StandardMaterial3D, scale_v: float) -> void:
	if kind == "champion":
		mat.albedo_color = tint
		mat.emission = tint.lightened(0.35)
		mat.emission_energy_multiplier = 0.22
	elif team == "blue":
		mat.albedo_color = Color(0.18, 0.32, 0.62)
	else:
		mat.albedo_color = Color(0.55, 0.16, 0.14)
	var hip = 52.0 * scale_v
	var shoulder = 78.0 * scale_v
	limbs["leg_l"] = _limb(Vector3(-10 * scale_v, hip, 0), Vector3(8 * scale_v, 36 * scale_v, 8 * scale_v), mat)
	limbs["leg_r"] = _limb(Vector3(10 * scale_v, hip, 0), Vector3(8 * scale_v, 36 * scale_v, 8 * scale_v), mat)
	var torso = _mesh(CapsuleMesh.new(), mat, Vector3(0, 70 * scale_v, 0), Vector3(28 * scale_v, 46 * scale_v, 18 * scale_v))
	limbs["torso"] = torso
	limbs["arm_l"] = _limb(Vector3(-18 * scale_v, shoulder, -4), Vector3(7 * scale_v, 32 * scale_v, 7 * scale_v), mat)
	limbs["arm_r"] = _limb(Vector3(18 * scale_v, shoulder, -4), Vector3(7 * scale_v, 32 * scale_v, 7 * scale_v), mat)
	var face = StandardMaterial3D.new()
	face.albedo_color = Color(0.95, 0.9, 0.82)
	face.roughness = 0.45
	_mesh(SphereMesh.new(), face, Vector3(0, 102 * scale_v, -6 * scale_v), Vector3(14 * scale_v, 16 * scale_v, 14 * scale_v))
	if kind == "champion":
		var trim = StandardMaterial3D.new()
		trim.albedo_color = Color(0.9, 0.76, 0.42)
		trim.emission_enabled = true
		trim.emission = Color(1, 0.86, 0.45)
		trim.emission_energy_multiplier = 0.8
		trim.metallic = 0.6
		meep = _mesh(SphereMesh.new(), trim, Vector3(30, 96, 0), Vector3(9, 11, 9))
		var light = OmniLight3D.new()
		light.light_color = trim.emission
		light.light_energy = 0.8
		light.omni_range = 220
		light.position = Vector3(0, 90, 0)
		add_child(light)
		_weapon(scale_v)

func _limb(pos: Vector3, scale_v: Vector3, mat: Material) -> Node3D:
	var pivot = Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var cap = CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 1.3
	var node = MeshInstance3D.new()
	node.mesh = cap
	node.material_override = mat
	node.position = Vector3(0, -scale_v.y * 0.45, 0)
	node.scale = scale_v
	pivot.add_child(node)
	return pivot

func _weapon(scale_v: float) -> void:
	var metal = StandardMaterial3D.new()
	metal.albedo_color = Color(0.82, 0.78, 0.7)
	metal.metallic = 0.85
	metal.roughness = 0.25
	var grip = limbs["arm_r"]
	var piece = MeshInstance3D.new()
	if style == "bow":
		var bow = TorusMesh.new()
		bow.inner_radius = 8 * scale_v
		bow.outer_radius = 11 * scale_v
		piece.mesh = bow
		piece.rotation.y = PI * 0.5
	elif style == "staff":
		var staff = CylinderMesh.new()
		staff.top_radius = 2.2 * scale_v
		staff.bottom_radius = 2.2 * scale_v
		staff.height = 70 * scale_v
		piece.mesh = staff
		piece.position = Vector3(0, 10 * scale_v, -8 * scale_v)
	elif style == "axe":
		var head = BoxMesh.new()
		head.size = Vector3(22, 16, 6) * scale_v
		piece.mesh = head
		piece.position = Vector3(0, -28 * scale_v, -6)
	else:
		var blade = BoxMesh.new()
		blade.size = Vector3(4, 42, 3) * scale_v
		piece.mesh = blade
		piece.position = Vector3(0, -30 * scale_v, -4)
	piece.material_override = metal
	grip.add_child(piece)

func _stone_mat() -> StandardMaterial3D:
	var stone = StandardMaterial3D.new()
	stone.albedo_color = Color(0.46, 0.44, 0.4) if team == "blue" else Color(0.42, 0.36, 0.34)
	stone.roughness = 0.72
	stone.metallic = 0.05
	stone.clearcoat_enabled = true
	stone.clearcoat = 0.12
	stone.rim_enabled = true
	stone.rim = 0.25
	stone.rim_tint = 0.6
	stone.emission_enabled = true
	stone.emission = _team_color()
	stone.emission_energy_multiplier = 0.0
	return stone

func _trim_mat() -> StandardMaterial3D:
	var trim = StandardMaterial3D.new()
	trim.albedo_color = Color(0.86, 0.72, 0.42)
	trim.metallic = 0.85
	trim.roughness = 0.28
	trim.emission_enabled = true
	trim.emission = Color(1, 0.85, 0.5)
	trim.emission_energy_multiplier = 0.2
	return trim

func _crystal_mat(energy: float) -> StandardMaterial3D:
	var gem = StandardMaterial3D.new()
	gem.albedo_color = _team_color().lightened(0.15)
	gem.emission_enabled = true
	gem.emission = _team_color()
	gem.emission_energy_multiplier = energy
	gem.metallic = 0.2
	gem.roughness = 0.12
	gem.clearcoat_enabled = true
	gem.clearcoat = 0.8
	gem.rim_enabled = true
	gem.rim = 0.6
	return gem

func _lathe_mesh(profile: Array, segs: int, mat: Material, pos: Vector3) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(profile.size() - 1):
		for i in segs:
			var a0 = float(i) / float(segs) * TAU
			var a1 = float(i + 1) / float(segs) * TAU
			var y0 = profile[r][0]
			var r0 = profile[r][1]
			var y1 = profile[r + 1][0]
			var r1 = profile[r + 1][1]
			var p00 = Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p01 = Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p10 = Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11 = Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p10)
			st.add_vertex(p01)
			st.add_vertex(p11)
			st.add_vertex(p10)
	st.index()
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node

func _build_tower() -> void:
	var stone = _masonry()
	body_mat = stone
	var trim = _trim_mat()
	var dark = _mat_stone_dark()
	_lathe_mesh([[0.0, 128.0], [10.0, 124.0], [16.0, 112.0], [28.0, 108.0]], 32, dark, Vector3.ZERO)
	_lathe_mesh([[28.0, 96.0], [46.0, 90.0], [78.0, 72.0], [120.0, 58.0], [156.0, 52.0], [188.0, 64.0], [206.0, 60.0], [214.0, 46.0]], 28, stone, Vector3.ZERO)
	for band_y in [40.0, 96.0, 168.0]:
		var band = _mesh(TorusMesh.new(), trim, Vector3(0, band_y, 0), Vector3.ONE)
		(band.mesh as TorusMesh).inner_radius = 58.0 if band_y > 80.0 else 86.0
		(band.mesh as TorusMesh).outer_radius = (band.mesh as TorusMesh).inner_radius + 5.0
	for k in 10:
		var ang = float(k) / 10.0 * TAU
		var merlon = _mesh(BoxMesh.new(), stone, Vector3(cos(ang) * 58.0, 232.0, sin(ang) * 58.0), Vector3(16, 28, 12))
		merlon.rotation.y = -ang
		if k % 2 == 0:
			_mesh(BoxMesh.new(), trim, Vector3(cos(ang) * 58.0, 248.0, sin(ang) * 58.0), Vector3(8, 6, 8))
	_mesh(BoxMesh.new(), dark, Vector3(0, 36, -96), Vector3(28, 48, 16))
	_mesh(PrismMesh.new(), dark, Vector3(0, 68, -96), Vector3(28, 18, 16))
	var gem = _crystal_mat(1.8)
	gem_mat = gem
	limbs["gem"] = _mesh(PrismMesh.new(), gem, Vector3(0, 268, 0), Vector3(26, 64, 26))
	var cage = _mesh(TorusMesh.new(), trim, Vector3(0, 268, 0), Vector3.ONE)
	(cage.mesh as TorusMesh).inner_radius = 22.0
	(cage.mesh as TorusMesh).outer_radius = 26.0
	var light = OmniLight3D.new()
	light.light_color = _team_color()
	light.light_energy = 1.6
	light.omni_range = 420
	light.position = Vector3(0, 260, 0)
	add_child(light)
	limbs["light"] = light

func _masonry() -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 stone : source_color = vec3(0.34, 0.32, 0.29);
uniform vec3 mortar : source_color = vec3(0.16, 0.15, 0.13);
uniform vec3 team_col : source_color = vec3(0.3, 0.5, 0.9);
varying vec3 wpos;
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 cell = vec2(floor(wpos.y / 18.0), floor(atan(wpos.z, wpos.x) * 4.0 + floor(wpos.y / 18.0) * 0.5));
	float brick = hash(cell);
	float seam_y = smoothstep(0.08, 0.0, abs(fract(wpos.y / 18.0) - 0.5) - 0.42);
	float seam_x = smoothstep(0.12, 0.0, abs(fract(atan(wpos.z, wpos.x) * 4.0) - 0.5) - 0.4);
	vec3 col = mix(stone * (0.82 + brick * 0.28), mortar, clamp(seam_y + seam_x, 0.0, 1.0));
	float moss = smoothstep(40.0, 8.0, wpos.y) * 0.25;
	col = mix(col, vec3(0.12, 0.18, 0.1), moss);
	ALBEDO = col;
	ROUGHNESS = 0.86;
	METALLIC = 0.02;
	EMISSION = team_col * 0.04;
}
"""
	mat.shader = sh
	var stone_col = Color(0.34, 0.33, 0.3) if team == "blue" else Color(0.36, 0.28, 0.26)
	mat.set_shader_parameter("stone", Vector3(stone_col.r, stone_col.g, stone_col.b))
	mat.set_shader_parameter("team_col", Vector3(_team_color().r, _team_color().g, _team_color().b))
	return mat

func _mat_stone_dark() -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.15, 0.14)
	m.roughness = 0.9
	return m

func _build_inhibitor() -> void:
	var stone = _stone_mat()
	body_mat = stone
	var trim = _trim_mat()
	_lathe_mesh([[0.0, 130.0], [16.0, 126.0], [22.0, 100.0], [44.0, 92.0], [56.0, 70.0]], 8, stone, Vector3.ZERO)
	for k in 4:
		var ang = float(k) / 4.0 * TAU + PI * 0.25
		var pillar = _lathe_mesh([[0.0, 16.0], [120.0, 12.0], [132.0, 20.0], [140.0, 14.0]], 10, stone, Vector3(cos(ang) * 78.0, 44.0, sin(ang) * 78.0))
		pillar.rotation.z = -cos(ang) * 0.18
		pillar.rotation.x = sin(ang) * 0.18
		_mesh(SphereMesh.new(), trim, Vector3(cos(ang) * 60.0, 190.0, sin(ang) * 60.0), Vector3(14, 14, 14))
	var core = _crystal_mat(1.4)
	gem_mat = core
	limbs["gem"] = _mesh(SphereMesh.new(), core, Vector3(0, 130, 0), Vector3(56, 72, 56))
	var halo = _mesh(TorusMesh.new(), trim, Vector3(0, 130, 0), Vector3(1, 1, 1))
	(halo.mesh as TorusMesh).inner_radius = 40
	(halo.mesh as TorusMesh).outer_radius = 46
	halo.rotation.x = 0.4
	limbs["ring"] = halo
	var light = OmniLight3D.new()
	light.light_color = _team_color()
	light.light_energy = 2.4
	light.omni_range = 600
	light.position = Vector3(0, 150, 0)
	add_child(light)

func _build_nexus() -> void:
	var stone = _masonry()
	body_mat = stone
	var trim = _trim_mat()
	var dark = _mat_stone_dark()
	_lathe_mesh([[0.0, 248.0], [22.0, 240.0], [34.0, 200.0], [52.0, 188.0], [70.0, 150.0], [96.0, 132.0], [118.0, 96.0]], 16, stone, Vector3.ZERO)
	_lathe_mesh([[18.0, 210.0], [28.0, 218.0], [38.0, 206.0]], 24, trim, Vector3.ZERO)
	_lathe_mesh([[78.0, 150.0], [86.0, 156.0], [94.0, 146.0]], 24, trim, Vector3.ZERO)
	for k in 8:
		var ang = float(k) / 8.0 * TAU
		var butt = _lathe_mesh([[0.0, 22.0], [150.0, 16.0], [210.0, 28.0], [228.0, 14.0]], 12, dark, Vector3(cos(ang) * 168.0, 40.0, sin(ang) * 168.0))
		butt.rotation.z = -cos(ang) * 0.12
		butt.rotation.x = sin(ang) * 0.12
		_mesh(SphereMesh.new(), trim, Vector3(cos(ang) * 168.0, 280.0, sin(ang) * 168.0), Vector3(16, 16, 16))
		if k % 2 == 0:
			_mesh(BoxMesh.new(), stone, Vector3(cos(ang) * 120.0, 70.0, sin(ang) * 120.0), Vector3(36, 90, 18))
	var core = _crystal_mat(1.6)
	gem_mat = core
	limbs["gem"] = _mesh(PrismMesh.new(), core, Vector3(0, 250, 0), Vector3(54, 160, 54))
	var cage = _mesh(TorusMesh.new(), trim, Vector3(0, 250, 0), Vector3.ONE)
	(cage.mesh as TorusMesh).inner_radius = 70.0
	(cage.mesh as TorusMesh).outer_radius = 78.0
	limbs["ring"] = cage
	var crown = _mesh(TorusMesh.new(), trim, Vector3(0, 330, 0), Vector3.ONE)
	(crown.mesh as TorusMesh).inner_radius = 40.0
	(crown.mesh as TorusMesh).outer_radius = 48.0
	limbs["ring2"] = crown
	var light = OmniLight3D.new()
	light.light_color = _team_color()
	light.light_energy = 2.2
	light.omni_range = 700
	light.shadow_enabled = false
	light.position = Vector3(0, 250, 0)
	add_child(light)

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, scale_v: Vector3) -> MeshInstance3D:
	if mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radius = 0.5
		(mesh as CapsuleMesh).height = 1.4
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = 0.5
		(mesh as SphereMesh).height = 1.0
	elif mesh is BoxMesh:
		(mesh as BoxMesh).size = Vector3.ONE
	elif mesh is PrismMesh:
		(mesh as PrismMesh).size = Vector3.ONE
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = scale_v
	add_child(node)
	return node

func _process(delta: float) -> void:
	if cast_left > 0.0:
		cast_left = max(0.0, cast_left - delta)
	_turn_toward(delta)
	if avatar != null:
		return
	spin += delta
	if dead:
		rotation.x = lerpf(rotation.x, 1.15, delta * 3.0)
		if kind != "tower" and kind != "nexus" and kind != "inhibitor":
			global_position.y = lerpf(global_position.y, -18.0, delta * 2.0)
		return
	global_position.y = lerpf(global_position.y, 0.0, 0.4)
	if meep != null:
		meep.position = Vector3(cos(spin * 1.6) * 38.0, 100.0 + sin(spin * 3.0) * 6.0, sin(spin * 1.6) * 18.0)
	if limbs.has("gem") and gem_mat:
		limbs["gem"].position.y = limbs["gem"].position.y
		gem_mat.emission_energy_multiplier = 1.1 + sin(spin * 3.0) * 0.45
	if limbs.has("ring"):
		limbs["ring"].rotation.y += delta * 0.8
	if limbs.has("gem") and kind == "tower":
		limbs["gem"].position.y = 175.0 + sin(spin * 2.0) * 8.0
	if not limbs.has("leg_l"):
		return
	if windup > 0.0:
		limbs["arm_r"].rotation.x = -1.25
		limbs["arm_l"].rotation.x = -0.4
		limbs["torso"].rotation.x = -0.2
	elif moving:
		walk_phase += delta * clampf(speed() / 80.0, 2.0, 8.0)
		var swing = sin(walk_phase)
		limbs["leg_l"].rotation.x = swing * 0.75
		limbs["leg_r"].rotation.x = -swing * 0.75
		limbs["arm_l"].rotation.x = -swing * 0.55
		limbs["arm_r"].rotation.x = swing * 0.55
		limbs["torso"].rotation.x = 0.08
		if kind == "champion":
			limbs["torso"].position.y = 70.0 + absf(swing) * 2.0
	else:
		var breathe = sin(spin * 1.6)
		limbs["leg_l"].rotation.x = lerpf(limbs["leg_l"].rotation.x, 0.0, 0.2)
		limbs["leg_r"].rotation.x = lerpf(limbs["leg_r"].rotation.x, 0.0, 0.2)
		limbs["arm_l"].rotation.x = lerpf(limbs["arm_l"].rotation.x, breathe * 0.05, 0.15)
		limbs["arm_r"].rotation.x = lerpf(limbs["arm_r"].rotation.x, -breathe * 0.05, 0.15)
		limbs["torso"].rotation.x = lerpf(limbs["torso"].rotation.x, 0.0, 0.15)
		if kind == "champion":
			limbs["torso"].position.y = lerpf(limbs["torso"].position.y, 70.0 + breathe * 1.2, 0.2)
