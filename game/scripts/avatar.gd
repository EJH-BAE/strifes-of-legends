extends Node3D

var kind_name = "wanderer"
var anim: AnimationPlayer
var motes: Array = []
var state = ""
var beast_legs: Array = []
var beast_phase = 0.0
var breath_parts: Array = []
var streak: MeshInstance3D
var ghost_cd := 0.0
var ghosts: Array = []
var step_mark := -1

func setup(kind: String, tint: Color = Color(1, 1, 1, 0), size: float = 1.0) -> void:
	kind_name = kind
	scale = Vector3.ONE * size
	match kind:
		"crab":
			_build_crab(tint)
			return
		"dragon", "boss":
			_build_dragon(tint, kind == "boss")
			return
		"beast":
			_build_beast(tint)
			return
		"golem":
			_build_golem(tint)
			return
	match kind:
		"bow":
			_build_ranger(tint)
		"assassin":
			_build_shade(tint)
		"spear":
			_build_lancer(tint)
		"axe":
			_build_reaver(tint)
		"tank":
			_build_bulwark(tint)
		"warlord":
			_build_warlord(tint, false)
			_blade(get_node("Root/Chest/ArmR"), _mat(Color(0.78, 0.8, 0.85), 0.2, 0.95, Color(0.8, 0.85, 0.9), 0.1))
		"staff", "burst", "enchanter":
			_build_wanderer(false, tint, "staff")
		_:
			_build_wanderer(false, tint, kind)
	_build_anims()
	_make_streak()

# ---------- materials ----------

static var _cloth_sh: Shader = null

func _cloth(color: Color, glow: Color, glow_e: float) -> ShaderMaterial:
	if _cloth_sh == null:
		var sh = Shader.new()
		sh.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform vec3 albedo : source_color = vec3(0.1, 0.14, 0.35);
uniform vec3 glow : source_color = vec3(0.0);
uniform float glow_e = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p){
	float s = 0.0; float a = 0.5;
	for (int k = 0; k < 4; k++) { s += vnoise(p) * a; p = p * 2.1 + vec2(13.0, 7.0); a *= 0.5; }
	return s;
}
void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment(){
	vec3 ap = abs(wnrm);
	ap /= (ap.x + ap.y + ap.z + 0.0001);
	vec2 px = wpos.zy; vec2 py = wpos.xz; vec2 pz = wpos.xy;
	float weave = (vnoise(px * 0.9) * ap.x + vnoise(py * 0.9) * ap.y + vnoise(pz * 0.9) * ap.z);
	float fold = (fbm(px * 0.06) * ap.x + fbm(py * 0.06) * ap.y + fbm(pz * 0.06) * ap.z);
	vec3 col = albedo * (0.82 + fold * 0.36) * (0.94 + weave * 0.12);
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 2.5);
	float e = 0.6;
	float hL = fbm((px + vec2(-e, 0.0)) * 0.06); float hR = fbm((px + vec2(e, 0.0)) * 0.06);
	float hD = fbm((px + vec2(0.0, -e)) * 0.06); float hU = fbm((px + vec2(0.0, e)) * 0.06);
	NORMAL_MAP = normalize(vec3((hL - hR) * 1.6, (hD - hU) * 1.6, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = col;
	ROUGHNESS = 0.78 - weave * 0.1;
	SPECULAR = 0.3;
	METALLIC = 0.0;
	EMISSION = glow * glow_e + albedo * fres * 0.12;
}
"""
		_cloth_sh = sh
	var mat = ShaderMaterial.new()
	mat.shader = _cloth_sh
	mat.set_shader_parameter("albedo", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("glow", Vector3(glow.r, glow.g, glow.b))
	mat.set_shader_parameter("glow_e", glow_e)
	return mat

func _mat(color: Color, rough: float, metal: float, glow: Color, glow_e: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	mat.rim_enabled = true
	mat.rim = 0.55 if metal < 0.5 else 0.28
	mat.rim_tint = 0.55
	if metal >= 0.5:
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.45
		mat.clearcoat_roughness = 0.25
	if glow_e > 0.0:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = glow_e
	return mat

func _skin_mat(color: Color) -> StandardMaterial3D:
	var mat = _mat(color, 0.6, 0.0, Color(0, 0, 0), 0.0)
	mat.subsurf_scatter_enabled = true
	mat.subsurf_scatter_strength = 0.35
	return mat

# ---------- skeleton helpers ----------

func _bone(bname: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.name = bname
	n.position = pos
	if parent == null:
		add_child(n)
	else:
		parent.add_child(n)
	return n

func _lathe(profile: Array, segs: int, closed: bool = true, arc: float = 2.45) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings = []
	var cols = segs if closed else segs
	for row in profile:
		var ring = []
		for i in cols + 1:
			var a = 0.0
			if closed:
				a = float(i) / float(cols) * TAU
			else:
				a = lerpf(-arc, arc, float(i) / float(cols))
			ring.append(Vector3(sin(a) * row[1], row[0], cos(a) * row[1]))
		rings.append(ring)
	for r in rings.size() - 1:
		for i in cols:
			var a = rings[r][i]
			var b = rings[r][i + 1]
			var c = rings[r + 1][i]
			var d = rings[r + 1][i + 1]
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(d)
	st.index()
	st.generate_normals()
	return st.commit()

func _piece(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scale_v: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = scale_v
	node.rotation = rot
	parent.add_child(node)
	return node

func _sphere(r: float, segs: int = 24) -> SphereMesh:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = int(segs / 2)
	return s

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c = CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 20
	c.rings = 10
	return c

func _box(size: Vector3) -> BoxMesh:
	var b = BoxMesh.new()
	b.size = size
	return b

func _prism(size: Vector3) -> PrismMesh:
	var p = PrismMesh.new()
	p.size = size
	return p

func _strip(parent: Node3D, mesh: ArrayMesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _piece(parent, mesh, mat, pos)

func _build_ranger(tint: Color) -> void:
	var base = tint if tint.a > 0.01 else Color(0.28, 0.36, 0.18)
	var leather: Material = _cloth(base.darkened(0.1), base, 0.04)
	var skin = _skin_mat(Color(0.9, 0.76, 0.62))
	var root = _bone("Root", null, Vector3(0, 0, 0))
	var chest = _bone("Chest", root, Vector3(0, 62, 0))
	var head = _bone("Head", chest, Vector3(0, 28, 0))
	var arm_l = _bone("ArmL", chest, Vector3(-16, 18, 0))
	var arm_r = _bone("ArmR", chest, Vector3(16, 18, 0))
	var hem = _bone("Hem", root, Vector3(0, 48, 8))
	var leg_l = _bone("LegL", root, Vector3(-7, 48, 0))
	var leg_r = _bone("LegR", root, Vector3(7, 48, 0))
	_strip(chest, _lathe([[18.0, 8.0], [8.0, 12.0], [-4.0, 11.0], [-12.0, 13.0]], 24), leather)
	_piece(head, _sphere(9.0, 18), skin, Vector3(0, 8, -2))
	_piece(head, _capsule(3.2, 22), leather, Vector3(0, 16, 4), Vector3.ONE, Vector3(0.6, 0, 0))
	_arm(arm_l, leather, skin, false)
	_arm(arm_r, leather, skin, true)
	_bow(arm_l)
	for leg in [leg_l, leg_r]:
		_piece(leg, _capsule(4.2, 28), leather, Vector3(0, -16, 0))
		_piece(leg, _capsule(3.6, 26), leather, Vector3(0, -40, 2))
		_piece(leg, _box(Vector3(8, 4, 14)), leather, Vector3(0, -54, 2))
	_strip(hem, _lathe([[4.0, 10.0], [-16.0, 16.0], [-28.0, 12.0]], 12, false, 1.1), leather)
	_piece(chest, _box(Vector3(8, 22, 6)), leather, Vector3(0, 6, 12))
	_glow(base.lightened(0.3), 0.35, 140)

func _build_shade(tint: Color) -> void:
	var base = tint if tint.a > 0.01 else Color(0.12, 0.1, 0.14)
	var cloth: Material = _cloth(base.darkened(0.2), base, 0.05)
	var skin = _skin_mat(Color(0.82, 0.7, 0.6))
	var root = _bone("Root", null, Vector3(0, 0, 0))
	var chest = _bone("Chest", root, Vector3(0, 54, 0))
	var head = _bone("Head", chest, Vector3(0, 26, -2))
	var arm_l = _bone("ArmL", chest, Vector3(-14, 16, 0))
	var arm_r = _bone("ArmR", chest, Vector3(14, 16, 0))
	var hem = _bone("Hem", root, Vector3(0, 40, 6))
	var leg_l = _bone("LegL", root, Vector3(-6, 42, 0))
	var leg_r = _bone("LegR", root, Vector3(6, 42, 0))
	_strip(chest, _lathe([[16.0, 6.0], [6.0, 9.0], [-8.0, 8.0]], 20), cloth)
	_piece(head, _sphere(8.0, 16), skin, Vector3(0, 6, -4), Vector3(0.9, 1.05, 0.85))
	_piece(head, _box(Vector3(14, 3, 2)), _mat(Color(0.9, 0.15, 0.2), 0.2, 0.1, Color(1, 0.2, 0.25), 1.4), Vector3(0, 6, -12))
	_arm(arm_l, cloth, skin, false)
	_arm(arm_r, cloth, skin, true)
	_daggers(arm_l, arm_r)
	for leg in [leg_l, leg_r]:
		_piece(leg, _capsule(3.4, 24), cloth, Vector3(0, -14, 0))
		_piece(leg, _capsule(3.0, 22), cloth, Vector3(0, -34, 1))
	_strip(hem, _lathe([[2.0, 8.0], [-18.0, 14.0], [-30.0, 8.0]], 10, false, 0.9), cloth)
	scale *= Vector3(0.92, 1.05, 0.92)
	_glow(Color(0.6, 0.1, 0.15), 0.25, 120)

func _build_lancer(tint: Color) -> void:
	var base = tint if tint.a > 0.01 else Color(0.22, 0.32, 0.48)
	_build_warlord(base, false)
	scale *= Vector3(0.86, 1.12, 0.86)
	_polearm(get_node("Root/Chest/ArmR"), false)
	_glow(base.lightened(0.25), 0.3, 150)

func _build_reaver(tint: Color) -> void:
	var base = tint if tint.a > 0.01 else Color(0.4, 0.18, 0.1)
	_build_warlord(base, true)
	scale *= Vector3(1.15, 0.92, 1.15)
	_polearm(get_node("Root/Chest/ArmR"), true)
	_glow(base, 0.25, 140)

func _build_bulwark(tint: Color) -> void:
	var base = tint if tint.a > 0.01 else Color(0.28, 0.26, 0.22)
	_build_warlord(base, true)
	scale *= Vector3(1.22, 1.05, 1.22)
	var plate = _mat(base.darkened(0.15), 0.4, 0.7, base, 0.05)
	var arm_l = get_node("Root/Chest/ArmL")
	_piece(arm_l, _box(Vector3(6, 36, 28)), plate, Vector3(-6, -20, -6))
	_glow(base.lightened(0.15), 0.2, 120)

# ---------- 오르벨 (wanderer) ----------

func _build_wanderer(ranger: bool, tint: Color = Color(0, 0, 0, 0), kind: String = "wanderer") -> void:
	var base = Color(0.13, 0.18, 0.42)
	if tint.a > 0.01:
		base = tint
	var cloth: Material = _cloth(base, base.lightened(0.35), 0.08)
	var inner: Material = _cloth(base.lightened(0.22), base.lightened(0.4), 0.14)
	var gold = _mat(Color(0.9, 0.74, 0.36), 0.28, 0.9, Color(1, 0.84, 0.45), 0.35)
	var mask = _skin_mat(Color(0.95, 0.9, 0.8))
	if ranger:
		cloth = _cloth(base if tint.a > 0.01 else Color(0.22, 0.34, 0.18), Color(0.3, 0.45, 0.2), 0.05)
		inner = _cloth(Color(0.4, 0.32, 0.2), Color(0, 0, 0), 0.0)
	elif kind == "assassin":
		cloth = _cloth(base.darkened(0.15), base, 0.04)
		inner = _cloth(base.darkened(0.35), Color(0, 0, 0), 0.0)
	var root = _bone("Root", null, Vector3(0, 10, 0))
	var chest = _bone("Chest", root, Vector3(0, 48, 0))
	var head = _bone("Head", chest, Vector3(0, 36, -2))
	var arm_l = _bone("ArmL", chest, Vector3(-19, 22, 0))
	var arm_r = _bone("ArmR", chest, Vector3(19, 22, -2))
	var hem = _bone("Hem", root, Vector3(0, 20, 2))
	_bone("LegL", root, Vector3(-8, 10, 0))
	_bone("LegR", root, Vector3(8, 10, 0))
	_strip(chest, _lathe([[42.0, 6.0], [36.0, 15.0], [28.0, 25.0], [20.0, 24.0], [8.0, 20.0], [-2.0, 17.0], [-14.0, 20.0], [-22.0, 24.0]], 32), cloth)
	_strip(chest, _lathe([[30.0, 26.5], [20.0, 29.0], [8.0, 30.0], [-6.0, 27.0]], 32, false, 1.35), inner, Vector3(0, 0, 0))
	_piece(chest, _lathe([[32.0, 20.0], [34.0, 28.0], [30.0, 32.0], [24.0, 30.0]], 32), gold, Vector3(0, 0, 0))
	_strip(hem, _lathe([[10.0, 20.0], [-2.0, 25.0], [-18.0, 31.0], [-34.0, 37.0], [-46.0, 41.0], [-54.0, 42.0], [-58.0, 38.0], [-56.0, 33.0]], 36), cloth)
	_piece(hem, _lathe([[-47.0, 41.5], [-51.0, 43.0], [-54.0, 40.0]], 36), gold, Vector3.ZERO)
	for i in 6:
		var ang = float(i) / 6.0 * TAU
		_piece(hem, _sphere(3.6, 12), gold, Vector3(sin(ang) * 36.0, -38.0, cos(ang) * 36.0))
	_strip(hem, _lathe([[8.0, 14.0], [-6.0, 24.0], [-16.0, 30.0]], 24, false, 1.6), inner, Vector3(0, 0, -2))
	_hood(head, cloth, inner, gold)
	_mask(head, mask, gold)
	_arm(arm_l, cloth, inner, false)
	_arm(arm_r, cloth, inner, true)
	if not ranger and kind != "assassin":
		_staff(arm_r, gold)
		for i in 3:
			motes.append(_mote(gold, i))
	var glow_c = base.lightened(0.4) if tint.a > 0.01 else Color(0.7, 0.85, 1.0)
	_glow(glow_c, 0.9, 260)

func _hood(head: Node3D, cloth: Material, inner: Material, gold: Material) -> void:
	_strip(head, _lathe([[-10.0, 16.0], [-2.0, 22.0], [8.0, 23.0], [18.0, 18.0], [26.0, 10.0], [31.0, 3.0]], 28), cloth, Vector3(0, 6, 4))
	_strip(head, _lathe([[-8.0, 14.0], [0.0, 18.0], [10.0, 17.5], [18.0, 12.0]], 28, false, 1.2), inner, Vector3(0, 4, 0))
	_piece(head, _lathe([[6.0, 22.5], [9.0, 24.0], [12.0, 22.0]], 28), gold, Vector3(0, 6, 4))
	_piece(head, _lathe([[20.0, 17.0], [22.5, 18.5], [25.0, 15.0]], 28), gold, Vector3(0, 6, 4))
	_piece(head, _sphere(4.5, 14), _mat(Color(0.3, 0.9, 1.0), 0.1, 0.1, Color(0.45, 0.9, 1.0), 2.2), Vector3(0, 37, 4))
	for side in [-1.0, 1.0]:
		var ear = _piece(head, _capsule(3.5, 30), cloth, Vector3(side * 18.0, 14.0, 6.0), Vector3.ONE, Vector3(0.4, 0, side * 1.1))
		ear.name = "Ear%s" % ("L" if side < 0 else "R")
		_piece(head, _sphere(4.2, 12), gold, Vector3(side * 29.0, 24.0, 2.0))

func _mask(head: Node3D, mask: Material, gold: Material) -> void:
	_piece(head, _sphere(12.0, 24), mask, Vector3(0, 4, -11), Vector3(1.0, 1.25, 0.55))
	var eye = _mat(Color(0.3, 0.9, 1.0), 0.15, 0.1, Color(0.45, 0.9, 1.0), 2.6)
	for side in [-1.0, 1.0]:
		_piece(head, _box(Vector3(6.5, 1.8, 1.2)), eye, Vector3(side * 4.4, 6.5, -17.2), Vector3.ONE, Vector3(0, 0, side * 0.25))
	_piece(head, _prism(Vector3(7, 16, 4)), gold, Vector3(0, 20, -6))
	_piece(head, _sphere(2.4, 10), gold, Vector3(0, 0, -17.5))

func _arm(pivot: Node3D, cloth: Material, inner: Material, right: bool) -> void:
	_piece(pivot, _sphere(9.0, 18), cloth, Vector3(0, 2, 0), Vector3(1.15, 0.85, 1.05))
	_piece(pivot, _capsule(5.0, 26), cloth, Vector3(0, -13, 0))
	_piece(pivot, _sphere(5.2, 14), inner, Vector3(0, -27, 0))
	_piece(pivot, _capsule(4.4, 22), inner, Vector3(0, -39, -1), Vector3.ONE, Vector3(0.12, 0, 0))
	_piece(pivot, _sphere(5.4, 14), inner, Vector3(0, -51, -3 if right else -1), Vector3(1.0, 1.15, 1.0))

func _staff(arm: Node3D, gold: Material) -> void:
	var wood = _mat(Color(0.36, 0.22, 0.12), 0.7, 0.05, Color(0, 0, 0), 0.0)
	_piece(arm, _capsule(2.4, 126), wood, Vector3(6, -4, -8), Vector3.ONE, Vector3(0.15, 0, 0))
	_piece(arm, _sphere(7.5, 20), gold, Vector3(6, 56, -12))
	var ring = _piece(arm, TorusMesh.new(), gold, Vector3(6, 56, -12), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	(ring.mesh as TorusMesh).inner_radius = 9.0
	(ring.mesh as TorusMesh).outer_radius = 11.5
	var halo = _piece(arm, TorusMesh.new(), gold, Vector3(6, 56, -12), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	(halo.mesh as TorusMesh).inner_radius = 13.0
	(halo.mesh as TorusMesh).outer_radius = 14.5
	_piece(arm, _sphere(3.0, 10), gold, Vector3(6, -62, -8))

func _mote(gold: Material, index: int) -> MeshInstance3D:
	var mote = MeshInstance3D.new()
	mote.mesh = _sphere(5.0, 14)
	mote.material_override = gold
	mote.set_meta("index", index)
	add_child(mote)
	var light = OmniLight3D.new()
	light.light_color = Color(1, 0.86, 0.45)
	light.light_energy = 0.4
	light.omni_range = 110
	mote.add_child(light)
	return mote

# ---------- 카엘라 (warlord) ----------

func _build_warlord(tint: Color = Color(0, 0, 0, 0), bulky: bool = false) -> void:
	var plate_c = Color(0.26, 0.2, 0.18)
	var cape_c = Color(0.55, 0.1, 0.12)
	if tint.a > 0.01:
		plate_c = tint.darkened(0.25)
		cape_c = tint
	var plate = _mat(plate_c, 0.34, 0.8, plate_c.lightened(0.2), 0.08)
	var steel = _mat(Color(0.8, 0.82, 0.86), 0.18, 0.96, Color(0.8, 0.85, 0.9), 0.08)
	var cape: Material = _cloth(cape_c, cape_c.lightened(0.2), 0.05)
	var cloth: Material = _cloth(plate_c.darkened(0.2), Color(0, 0, 0), 0.0)
	var skin = _skin_mat(Color(0.56, 0.4, 0.3))
	var root = _bone("Root", null, Vector3(0, 0, 0))
	var chest = _bone("Chest", root, Vector3(0, 54, 0))
	var head = _bone("Head", chest, Vector3(0, 34, 0))
	var arm_l = _bone("ArmL", chest, Vector3(-21, 22, 0))
	var arm_r = _bone("ArmR", chest, Vector3(21, 22, 0))
	var hem = _bone("Hem", root, Vector3(0, 40, 6))
	var leg_l = _bone("LegL", root, Vector3(-9, 44, 0))
	var leg_r = _bone("LegR", root, Vector3(9, 44, 0))
	_strip(chest, _lathe([[34.0, 7.0], [30.0, 15.0], [24.0, 22.0], [14.0, 22.5], [4.0, 19.0], [-6.0, 16.0], [-14.0, 19.0], [-18.0, 20.0]], 32), plate)
	_strip(chest, _lathe([[26.0, 23.5], [16.0, 24.5], [6.0, 21.0]], 32, false, 1.25), steel)
	var belt = _piece(chest, TorusMesh.new(), steel, Vector3(0, -8, 0), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	(belt.mesh as TorusMesh).inner_radius = 15.5
	(belt.mesh as TorusMesh).outer_radius = 19.0
	_piece(chest, _box(Vector3(10, 10, 4)), steel, Vector3(0, -8, -18))
	for side in [-1.0, 1.0]:
		_piece(chest, _sphere(10.0, 20), plate, Vector3(side * 22.0, 25.0, 0), Vector3(1.3, 0.7, 1.05))
		_piece(chest, _lathe([[4.0, 9.0], [6.5, 11.0], [9.0, 8.0]], 16), steel, Vector3(side * 22.0, 25.0, 0))
		_piece(chest, _prism(Vector3(5, 12, 5)), steel, Vector3(side * 29.0, 34.0, 0), Vector3.ONE, Vector3(0, 0, side * -0.5))
	for i in 7:
		var ang = -1.1 + 2.2 * float(i) / 6.0
		_piece(hem, _box(Vector3(11, 26, 3)), plate, Vector3(sin(ang) * 20.0, -14.0, -cos(ang) * 20.0 - 6.0), Vector3.ONE, Vector3(0.15, ang, 0))
	_strip(hem, _lathe([[6.0, 20.0], [-10.0, 28.0], [-26.0, 33.0], [-40.0, 30.0], [-46.0, 24.0]], 16, false, 1.0), cape, Vector3(0, 0, 0))
	for leg in [leg_l, leg_r]:
		_piece(leg, _sphere(8.5, 16), plate, Vector3(0, -1, 0))
		_piece(leg, _capsule(6.6, 20), cloth, Vector3(0, -11, 0))
		_piece(leg, _sphere(6.8, 14), steel, Vector3(0, -22, 0))
		_piece(leg, _capsule(6.0, 18), plate, Vector3(0, -32, 0))
		_piece(leg, _box(Vector3(11, 8, 18)), steel, Vector3(0, -41, -4))
	_arm_plate(arm_l, plate, steel, false)
	_arm_plate(arm_r, plate, steel, true)
	_war_head(head, skin, steel, cape)
	if bulky:
		scale *= 1.08
	var glow_c = cape_c.lightened(0.15) if tint.a > 0.01 else Color(0.85, 0.25, 0.18)
	_glow(glow_c, 0.55, 180)

func _arm_plate(pivot: Node3D, plate: Material, steel: Material, right: bool) -> void:
	_piece(pivot, _capsule(5.6, 24), plate, Vector3(0, -12, 0))
	_piece(pivot, _sphere(6.0, 14), steel, Vector3(0, -25, 0))
	_piece(pivot, _capsule(5.0, 22), plate, Vector3(0, -37, -1), Vector3.ONE, Vector3(0.1, 0, 0))
	_piece(pivot, _box(Vector3(12, 14, 12)), steel, Vector3(0, -42, -2))
	_piece(pivot, _sphere(5.4, 12), steel, Vector3(0, -52, -4 if right else -2))

func _war_head(head: Node3D, skin: Material, steel: Material, cape: Material) -> void:
	_piece(head, _sphere(10.0, 20), skin, Vector3(0, 6, -2), Vector3(0.95, 1.1, 1.0))
	_strip(head, _lathe([[-4.0, 11.5], [4.0, 12.5], [12.0, 11.0], [17.0, 6.0], [19.0, 0.0]], 24), steel, Vector3(0, 6, -2))
	_piece(head, _box(Vector3(18, 2.2, 6)), _mat(Color(0.05, 0.05, 0.06), 0.4, 0.4, Color(1.0, 0.3, 0.2), 1.6), Vector3(0, 5, -13))
	_piece(head, _box(Vector3(4, 10, 4)), steel, Vector3(0, 2, -13.5))
	for side in [-1.0, 1.0]:
		_piece(head, _prism(Vector3(4, 10, 6)), steel, Vector3(side * 12.0, 16.0, -2.0), Vector3.ONE, Vector3(0, 0, side * -0.6))
	_piece(head, _prism(Vector3(5, 22, 12)), cape, Vector3(0, 26, 2))
	_piece(head, _capsule(3.0, 28), cape, Vector3(0, 22, 12), Vector3.ONE, Vector3(-1.1, 0, 0))

func _blade(arm: Node3D, steel: Material) -> void:
	var dark = _mat(Color(0.35, 0.33, 0.36), 0.3, 0.9, Color(0, 0, 0), 0.0)
	_piece(arm, _box(Vector3(7, 84, 2.4)), steel, Vector3(4, -90, -8))
	_piece(arm, _prism(Vector3(7, 14, 2.4)), steel, Vector3(4, -139, -8), Vector3.ONE, Vector3(0, 0, PI))
	_piece(arm, _box(Vector3(2, 70, 1.0)), dark, Vector3(4, -86, -9.4))
	_piece(arm, _box(Vector3(22, 4, 5)), dark, Vector3(4, -47, -8))
	_piece(arm, _capsule(2.6, 12), dark, Vector3(4, -40, -8))
	_piece(arm, _sphere(3.4, 10), steel, Vector3(4, -33, -8))

func _polearm(arm: Node3D, axe: bool) -> void:
	var metal = _mat(Color(0.78, 0.8, 0.84), 0.26, 0.85, Color(0.8, 0.85, 0.9), 0.1)
	var wood = _mat(Color(0.38, 0.24, 0.13), 0.7, 0.05, Color(0, 0, 0), 0.0)
	_piece(arm, _capsule(2.2, 100), wood, Vector3(4, -22, -8))
	if axe:
		_piece(arm, _box(Vector3(30, 18, 4)), metal, Vector3(4, 24, -8))
		_piece(arm, _prism(Vector3(8, 10, 4)), metal, Vector3(4, 38, -8))
	else:
		_piece(arm, _prism(Vector3(9, 30, 6)), metal, Vector3(4, 40, -8))
		_piece(arm, _sphere(3.4, 10), metal, Vector3(4, 24, -8))

func _daggers(arm_l: Node3D, arm_r: Node3D) -> void:
	var steel = _mat(Color(0.72, 0.74, 0.8), 0.22, 0.9, Color(0.8, 0.85, 0.9), 0.12)
	var dark = _mat(Color(0.18, 0.16, 0.16), 0.45, 0.4, Color(0, 0, 0), 0.0)
	_piece(arm_r, _box(Vector3(3.2, 32, 1.1)), steel, Vector3(4, -58, -6))
	_piece(arm_r, _prism(Vector3(3.2, 8, 1.1)), steel, Vector3(4, -76, -6), Vector3.ONE, Vector3(0, 0, PI))
	_piece(arm_r, _box(Vector3(8, 3, 2.4)), dark, Vector3(4, -42, -6))
	_piece(arm_l, _box(Vector3(3.2, 28, 1.1)), steel, Vector3(-4, -54, -6))
	_piece(arm_l, _prism(Vector3(3.2, 7, 1.1)), steel, Vector3(-4, -70, -6), Vector3.ONE, Vector3(0, 0, PI))
	_piece(arm_l, _box(Vector3(8, 3, 2.4)), dark, Vector3(-4, -40, -6))

func _bow(arm: Node3D) -> void:
	var wood = _mat(Color(0.42, 0.26, 0.14), 0.6, 0.05, Color(0, 0, 0), 0.0)
	var bow = _piece(arm, TorusMesh.new(), wood, Vector3(0, -24, -8), Vector3(1.0, 1.6, 1.0), Vector3(0, PI * 0.5, 0))
	(bow.mesh as TorusMesh).inner_radius = 16.0
	(bow.mesh as TorusMesh).outer_radius = 18.5
	_piece(arm, _box(Vector3(0.6, 56, 0.6)), _mat(Color(0.9, 0.9, 0.85), 0.5, 0.0, Color(0, 0, 0), 0.0), Vector3(0, -24, 10))

func _glow(color: Color, energy: float, reach: float) -> void:
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.position = Vector3(0, 70, 0)
	add_child(light)

# ---------- 중립 개체 ----------

func _build_crab(tint: Color) -> void:
	var shell_c = Color(0.45, 0.18, 0.62) if tint.a <= 0.01 else tint
	var shell = _mat(shell_c, 0.4, 0.3, shell_c.lightened(0.25), 0.25)
	var under = _mat(shell_c.darkened(0.35), 0.7, 0.1, Color(0, 0, 0), 0.0)
	var body = _piece(self, _sphere(30.0, 24), shell, Vector3(0, 26, 0), Vector3(1.4, 0.55, 1.1))
	breath_parts.append(body)
	for i in 5:
		var ang = -1.0 + 2.0 * float(i) / 4.0
		_piece(self, _prism(Vector3(8, 10, 6)), shell, Vector3(sin(ang) * 30.0, 40.0, -cos(ang) * 14.0), Vector3.ONE, Vector3(0, ang, 0))
	for i in 6:
		var side = -1.0 if i < 3 else 1.0
		var z = -16.0 + float(i % 3) * 16.0
		var hip = Node3D.new()
		hip.position = Vector3(side * 28.0, 18.0, z)
		add_child(hip)
		_piece(hip, _capsule(3.4, 26), under, Vector3(side * 12.0, 4.0, 0), Vector3.ONE, Vector3(0, 0, side * 1.1))
		_piece(hip, _capsule(2.8, 22), under, Vector3(side * 24.0, -6.0, 0), Vector3.ONE, Vector3(0, 0, side * 0.3))
		beast_legs.append(hip)
	for side in [-1.0, 1.0]:
		var claw = Node3D.new()
		claw.position = Vector3(side * 30.0, 20.0, -26.0)
		add_child(claw)
		_piece(claw, _sphere(10.0, 14), shell, Vector3(side * 6.0, 2.0, -6.0), Vector3(1.3, 0.9, 1.4))
		_piece(claw, _prism(Vector3(6, 12, 8)), under, Vector3(side * 8.0, 4.0, -20.0), Vector3.ONE, Vector3(-PI * 0.5, 0, 0))
	var eye = _mat(Color(1.0, 0.85, 0.3), 0.2, 0.0, Color(1.0, 0.8, 0.3), 2.0)
	for side in [-1.0, 1.0]:
		_piece(self, _sphere(3.0, 10), eye, Vector3(side * 10.0, 38.0, -28.0))

func _build_dragon(tint: Color, boss: bool) -> void:
	var hide_c = Color(0.55, 0.28, 0.1) if tint.a <= 0.01 else tint
	var hide = _mat(hide_c, 0.45, 0.25, hide_c.lightened(0.3), 0.15)
	var belly = _mat(hide_c.lightened(0.35), 0.6, 0.05, Color(0, 0, 0), 0.0)
	var horn = _mat(Color(0.85, 0.8, 0.7), 0.5, 0.1, Color(0, 0, 0), 0.0)
	var body = _strip(self, _lathe([[60.0, 8.0], [44.0, 22.0], [20.0, 30.0], [-10.0, 28.0], [-40.0, 18.0], [-70.0, 10.0], [-100.0, 5.0]], 24), hide, Vector3(0, 52, 10))
	body.rotation.x = PI * 0.5
	breath_parts.append(body)
	_piece(self, _capsule(18.0, 60), belly, Vector3(0, 40, 10), Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0, 0))
	var neck = _strip(self, _lathe([[0.0, 12.0], [26.0, 10.0], [52.0, 9.0]], 18), hide, Vector3(0, 62, -42))
	neck.rotation.x = -0.9
	var head = Node3D.new()
	head.position = Vector3(0, 90, -74)
	head.name = "Head"
	add_child(head)
	_strip(head, _lathe([[0.0, 14.0], [-14.0, 15.0], [-30.0, 10.0], [-44.0, 5.0]], 18), hide, Vector3(0, 0, 0)).rotation.x = -PI * 0.5
	_piece(head, _box(Vector3(14, 4, 26)), belly, Vector3(0, -8, -22))
	for side in [-1.0, 1.0]:
		_piece(head, _prism(Vector3(5, 22, 6)), horn, Vector3(side * 9.0, 14.0, 8.0), Vector3.ONE, Vector3(-0.5, 0, side * -0.4))
		_piece(head, _sphere(3.2, 10), _mat(Color(1.0, 0.6, 0.2), 0.2, 0.0, Color(1.0, 0.5, 0.1), 2.5), Vector3(side * 8.0, 4.0, -10.0))
	for side in [-1.0, 1.0]:
		var wing = Node3D.new()
		wing.position = Vector3(side * 20.0, 72.0, -6.0)
		add_child(wing)
		_piece(wing, _capsule(4.0, 80), hide, Vector3(side * 40.0, 10.0, 0), Vector3.ONE, Vector3(0, 0, side * 1.25))
		_piece(wing, _capsule(3.0, 70), hide, Vector3(side * 78.0, 36.0, -10.0), Vector3.ONE, Vector3(0.3, 0, side * 0.6))
		var membrane = _piece(wing, _prism(Vector3(90, 70, 2)), _mat(hide_c.darkened(0.2), 0.7, 0.0, hide_c, 0.1), Vector3(side * 52.0, 10.0, -8.0), Vector3.ONE, Vector3(PI * 0.5, 0, side * 0.25))
		membrane.rotation = Vector3(0, 0, side * -0.2)
		beast_legs.append(wing)
	for i in 4:
		var side = -1.0 if i % 2 == 0 else 1.0
		var z = -16.0 if i < 2 else 36.0
		var leg = Node3D.new()
		leg.position = Vector3(side * 22.0, 40.0, z)
		add_child(leg)
		_piece(leg, _capsule(7.0, 26), hide, Vector3(side * 4.0, -12.0, 0), Vector3.ONE, Vector3(0, 0, side * 0.25))
		_piece(leg, _sphere(7.0, 12), hide, Vector3(side * 7.0, -26.0, 0))
		_piece(leg, _capsule(5.5, 22), hide, Vector3(side * 8.0, -36.0, 0))
		_piece(leg, _box(Vector3(14, 6, 20)), horn, Vector3(side * 8.0, -47.0, -4.0))
	for i in 7:
		_piece(self, _prism(Vector3(6, 12, 6)), horn, Vector3(0, 82.0 - i * 2.0, -20.0 + i * 14.0), Vector3.ONE, Vector3(0.3, 0, 0))
	if boss:
		var crown = _mat(Color(0.5, 0.2, 0.7), 0.3, 0.4, Color(0.7, 0.3, 1.0), 1.4)
		for i in 5:
			var ang = float(i) / 5.0 * TAU
			_piece(head, _prism(Vector3(6, 26, 6)), crown, Vector3(cos(ang) * 12.0, 18.0, sin(ang) * 10.0 + 4.0), Vector3.ONE, Vector3(0, 0, -cos(ang) * 0.5))
		_piece(self, _sphere(14.0, 18), crown, Vector3(0, 70, 30))
		var light = OmniLight3D.new()
		light.light_color = Color(0.7, 0.35, 1.0)
		light.light_energy = 1.4
		light.omni_range = 420
		light.position = Vector3(0, 90, 0)
		add_child(light)
	else:
		var light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.2)
		light.light_energy = 1.0
		light.omni_range = 360
		light.position = Vector3(0, 80, -40)
		add_child(light)

func _build_beast(tint: Color) -> void:
	var fur_c = Color(0.38, 0.33, 0.28) if tint.a <= 0.01 else tint
	var fur = _mat(fur_c, 0.85, 0.0, Color(0, 0, 0), 0.0)
	var dark = _mat(fur_c.darkened(0.4), 0.9, 0.0, Color(0, 0, 0), 0.0)
	var body = _strip(self, _lathe([[34.0, 6.0], [24.0, 16.0], [8.0, 19.0], [-12.0, 18.0], [-30.0, 14.0], [-40.0, 6.0]], 20), fur, Vector3(0, 36, 4))
	body.rotation.x = PI * 0.5
	breath_parts.append(body)
	var head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 48, -36)
	add_child(head)
	_piece(head, _sphere(12.0, 18), fur, Vector3(0, 0, 0), Vector3(1.0, 0.95, 1.15))
	_piece(head, _box(Vector3(10, 8, 16)), dark, Vector3(0, -4, -14))
	_piece(head, _sphere(2.6, 8), dark, Vector3(0, -2, -22))
	for side in [-1.0, 1.0]:
		_piece(head, _prism(Vector3(5, 10, 4)), fur, Vector3(side * 8.0, 12.0, 2.0), Vector3.ONE, Vector3(0, 0, side * -0.3))
		_piece(head, _sphere(2.4, 8), _mat(Color(1.0, 0.75, 0.2), 0.2, 0.0, Color(1.0, 0.7, 0.2), 2.0), Vector3(side * 5.5, 3.0, -9.0))
	for i in 4:
		var side = -1.0 if i % 2 == 0 else 1.0
		var z = -22.0 if i < 2 else 22.0
		var leg = Node3D.new()
		leg.position = Vector3(side * 12.0, 30.0, z)
		add_child(leg)
		_piece(leg, _capsule(4.4, 20), fur, Vector3(0, -9, 0))
		_piece(leg, _sphere(4.4, 10), fur, Vector3(0, -19, 0))
		_piece(leg, _capsule(3.6, 16), dark, Vector3(0, -26, 2), Vector3.ONE, Vector3(-0.2, 0, 0))
		_piece(leg, _box(Vector3(7, 4, 10)), dark, Vector3(0, -32, -1))
		beast_legs.append(leg)
	_piece(self, _capsule(3.0, 30), fur, Vector3(0, 40, 40), Vector3.ONE, Vector3(1.0, 0, 0))

func _build_golem(tint: Color) -> void:
	var rock_c = Color(0.4, 0.38, 0.35) if tint.a <= 0.01 else tint
	var rock = _mat(rock_c, 0.95, 0.0, Color(0, 0, 0), 0.0)
	var vein = _mat(rock_c.lightened(0.3), 0.3, 0.2, rock_c.lightened(0.5), 1.4)
	var body = _piece(self, _sphere(26.0, 18), rock, Vector3(0, 44, 0), Vector3(1.1, 1.0, 0.9))
	breath_parts.append(body)
	_piece(self, _sphere(12.0, 14), rock, Vector3(0, 74, -6), Vector3(1.0, 0.8, 1.0))
	_piece(self, _prism(Vector3(14, 26, 10)), vein, Vector3(0, 70, 12), Vector3.ONE, Vector3(0.6, 0, 0))
	for side in [-1.0, 1.0]:
		var arm = Node3D.new()
		arm.position = Vector3(side * 28.0, 56.0, 0)
		add_child(arm)
		_piece(arm, _sphere(11.0, 12), rock, Vector3(side * 4.0, -4.0, 0))
		_piece(arm, _sphere(13.0, 12), rock, Vector3(side * 10.0, -30.0, -4.0), Vector3(1.0, 1.2, 1.0))
		beast_legs.append(arm)
		_piece(self, _sphere(10.0, 12), rock, Vector3(side * 12.0, 12.0, 0), Vector3(1.1, 1.0, 1.2))
	for side in [-1.0, 1.0]:
		_piece(self, _sphere(2.6, 8), vein, Vector3(side * 5.0, 76.0, -16.0))

# ---------- animation ----------

func _build_anims() -> void:
	anim = AnimationPlayer.new()
	add_child(anim)
	var lib = AnimationLibrary.new()
	lib.add_animation("idle", _clip(2.2, true, {
		"Root": [Vector3(0, 0, 0), Vector3(0, 7, 0), Vector3(0, 0, 0)],
		"Root:rot": [Vector3(0, 0, 0), Vector3(0.04, 0, 0.03), Vector3(0, 0, 0)],
		"Chest": [Vector3(0, 0, 0), Vector3(0.06, 0.04, 0), Vector3(0, 0, 0)],
		"Hem": [Vector3(0, 0, -0.06), Vector3(0, 0, 0.06), Vector3(0, 0, -0.06)],
		"Head": [Vector3(0, 0.05, 0), Vector3(0, -0.05, 0), Vector3(0, 0.05, 0)],
		"ArmL": [Vector3(0.2, 0, 0.15), Vector3(0.28, 0, 0.15), Vector3(0.2, 0, 0.15)],
		"ArmR": [Vector3(0.2, 0, -0.15), Vector3(0.28, 0, -0.15), Vector3(0.2, 0, -0.15)],
	}))
	lib.add_animation("walk_glide", _clip(0.9, true, {
		"Root": [Vector3(0, 0, 0), Vector3(0, 2, 0), Vector3(0, 0, 0), Vector3(0, 2, 0), Vector3(0, 0, 0)],
		"Hem": [Vector3(0.35, 0.45, 0), Vector3(-0.2, -0.5, 0.1), Vector3(0.35, 0.45, 0), Vector3(-0.2, -0.5, -0.1), Vector3(0.35, 0.45, 0)],
		"Chest": [Vector3(0.02, 0.08, 0), Vector3(0.02, -0.08, 0), Vector3(0.02, 0.08, 0), Vector3(0.02, -0.08, 0), Vector3(0.02, 0.08, 0)],
		"ArmL": [Vector3(0.15, 0, 0.2), Vector3(0.05, 0, 0.05), Vector3(-0.1, 0, 0.05), Vector3(0.05, 0, 0.05), Vector3(0.15, 0, 0.2)],
		"ArmR": [Vector3(-0.1, 0, -0.05), Vector3(0.05, 0, -0.05), Vector3(0.15, 0, -0.2), Vector3(0.05, 0, -0.05), Vector3(-0.1, 0, -0.05)],
		"LegL": [Vector3(-0.15, 0, 0), Vector3(0, 0, 0), Vector3(0.18, 0, 0), Vector3(0, 0, 0), Vector3(-0.15, 0, 0)],
		"LegR": [Vector3(0.18, 0, 0), Vector3(0, 0, 0), Vector3(-0.15, 0, 0), Vector3(0, 0, 0), Vector3(0.18, 0, 0)],
	}))
	lib.add_animation("walk_heavy", _clip(0.7, true, {
		"Root": [Vector3(0, 0, 0), Vector3(0, 2.2, 0), Vector3(0, 0, 0), Vector3(0, 2.2, 0), Vector3(0, 0, 0)],
		"Root:rot": [Vector3(0.1, 0, 0), Vector3(0.12, 0, 0.03), Vector3(0.1, 0, 0), Vector3(0.12, 0, -0.03), Vector3(0.1, 0, 0)],
		"Chest": [Vector3(0.1, 0.08, 0), Vector3(0.12, -0.06, 0), Vector3(0.1, 0.08, 0), Vector3(0.12, -0.06, 0), Vector3(0.1, 0.08, 0)],
		"Hem": [Vector3(0.12, 0.08, 0), Vector3(0.02, -0.1, 0), Vector3(0.12, 0.08, 0), Vector3(0.02, -0.1, 0), Vector3(0.12, 0.08, 0)],
		"Head": [Vector3(0.04, 0, 0), Vector3(-0.02, 0, 0), Vector3(0.04, 0, 0), Vector3(-0.02, 0, 0), Vector3(0.04, 0, 0)],
		"ArmL": [Vector3(0.45, 0, 0.18), Vector3(0.12, 0, 0.1), Vector3(-0.35, 0, 0.12), Vector3(0.12, 0, 0.1), Vector3(0.45, 0, 0.18)],
		"ArmR": [Vector3(-0.35, 0, -0.12), Vector3(0.12, 0, -0.1), Vector3(0.45, 0, -0.18), Vector3(0.12, 0, -0.1), Vector3(-0.35, 0, -0.12)],
		"LegL": [Vector3(-1.15, 0, 0), Vector3(0.15, 0, 0), Vector3(1.2, 0, 0), Vector3(0.15, 0, 0), Vector3(-1.15, 0, 0)],
		"LegR": [Vector3(1.2, 0, 0), Vector3(0.15, 0, 0), Vector3(-1.15, 0, 0), Vector3(0.15, 0, 0), Vector3(1.2, 0, 0)],
	}))
	lib.add_animation("walk_lumber", _clip(0.86, true, {
		"Root": [Vector3(0, 0, 0), Vector3(0, 8, 0), Vector3(0, 1, 0), Vector3(0, 8, 0), Vector3(0, 0, 0)],
		"Root:rot": [Vector3(0.2, 0, 0.12), Vector3(0.28, 0, -0.12), Vector3(0.2, 0, 0.12), Vector3(0.28, 0, -0.12), Vector3(0.2, 0, 0.12)],
		"Chest": [Vector3(0.2, 0.2, 0), Vector3(0.25, -0.2, 0), Vector3(0.2, 0.2, 0), Vector3(0.25, -0.2, 0), Vector3(0.2, 0.2, 0)],
		"ArmL": [Vector3(0.3, 0, 0.4), Vector3(0.2, 0, 0.35), Vector3(0.3, 0, 0.4), Vector3(0.2, 0, 0.35), Vector3(0.3, 0, 0.4)],
		"ArmR": [Vector3(-0.4, 0, -0.5), Vector3(0.8, 0, -0.2), Vector3(-0.4, 0, -0.5), Vector3(0.8, 0, -0.2), Vector3(-0.4, 0, -0.5)],
		"LegL": [Vector3(-0.9, 0, 0.15), Vector3(0.2, 0, 0), Vector3(0.95, 0, -0.1), Vector3(0.2, 0, 0), Vector3(-0.9, 0, 0.15)],
		"LegR": [Vector3(0.95, 0, -0.1), Vector3(0.2, 0, 0), Vector3(-0.9, 0, 0.15), Vector3(0.2, 0, 0), Vector3(0.95, 0, -0.1)],
	}))
	lib.add_animation("walk_stride", _clip(0.62, true, {
		"Root": [Vector3(0, 0, 0), Vector3(0, 1.8, 0), Vector3(0, 0, 0), Vector3(0, 1.8, 0), Vector3(0, 0, 0)],
		"Root:rot": [Vector3(0.08, 0, 0), Vector3(0.08, 0, 0), Vector3(0.08, 0, 0), Vector3(0.08, 0, 0), Vector3(0.08, 0, 0)],
		"Chest": [Vector3(0.06, 0.04, 0), Vector3(0.06, -0.04, 0), Vector3(0.06, 0.04, 0), Vector3(0.06, -0.04, 0), Vector3(0.06, 0.04, 0)],
		"Hem": [Vector3(0.08, 0.12, 0), Vector3(0, -0.12, 0), Vector3(0.08, 0.12, 0), Vector3(0, -0.12, 0), Vector3(0.08, 0.12, 0)],
		"Head": [Vector3(0, 0.02, 0), Vector3(0, -0.02, 0), Vector3(0, 0.02, 0), Vector3(0, -0.02, 0), Vector3(0, 0.02, 0)],
		"ArmL": [Vector3(0.22, 0, 0.2), Vector3(0.18, 0, 0.16), Vector3(0.14, 0, 0.18), Vector3(0.18, 0, 0.16), Vector3(0.22, 0, 0.2)],
		"ArmR": [Vector3(0.55, 0, -0.15), Vector3(0.1, 0, -0.1), Vector3(-0.45, 0, -0.12), Vector3(0.1, 0, -0.1), Vector3(0.55, 0, -0.15)],
		"LegL": [Vector3(-0.95, 0, 0), Vector3(0.05, 0, 0), Vector3(1.05, 0, 0), Vector3(0.05, 0, 0), Vector3(-0.95, 0, 0)],
		"LegR": [Vector3(1.05, 0, 0), Vector3(0.05, 0, 0), Vector3(-0.95, 0, 0), Vector3(0.05, 0, 0), Vector3(1.05, 0, 0)],
	}))
	lib.add_animation("walk_quick", _clip(0.4, true, {
		"Root": [Vector3(0, 0, 0), Vector3(0, 1.1, 0), Vector3(0, 0, 0), Vector3(0, 1.1, 0), Vector3(0, 0, 0)],
		"Root:rot": [Vector3(0.16, 0, 0), Vector3(0.16, 0, 0), Vector3(0.16, 0, 0), Vector3(0.16, 0, 0), Vector3(0.16, 0, 0)],
		"Chest": [Vector3(0.12, 0.1, 0), Vector3(0.12, -0.1, 0), Vector3(0.12, 0.1, 0), Vector3(0.12, -0.1, 0), Vector3(0.12, 0.1, 0)],
		"Hem": [Vector3(0.16, 0.14, 0), Vector3(-0.08, -0.14, 0), Vector3(0.16, 0.14, 0), Vector3(-0.08, -0.14, 0), Vector3(0.16, 0.14, 0)],
		"Head": [Vector3(0.06, 0, 0), Vector3(0, 0, 0), Vector3(0.06, 0, 0), Vector3(0, 0, 0), Vector3(0.06, 0, 0)],
		"ArmL": [Vector3(0.7, 0, 0.25), Vector3(0.05, 0, 0.1), Vector3(-0.65, 0, 0.15), Vector3(0.05, 0, 0.1), Vector3(0.7, 0, 0.25)],
		"ArmR": [Vector3(-0.65, 0, -0.15), Vector3(0.05, 0, -0.1), Vector3(0.7, 0, -0.25), Vector3(0.05, 0, -0.1), Vector3(-0.65, 0, -0.15)],
		"LegL": [Vector3(-0.85, 0, 0), Vector3(0, 0, 0), Vector3(0.9, 0, 0), Vector3(0, 0, 0), Vector3(-0.85, 0, 0)],
		"LegR": [Vector3(0.9, 0, 0), Vector3(0, 0, 0), Vector3(-0.85, 0, 0), Vector3(0, 0, 0), Vector3(0.9, 0, 0)],
	}))
	lib.add_animation("walk_light", _clip(0.52, true, {
		"Root": [Vector3(0, 0, 0), Vector3(0, 1.6, 0), Vector3(0, 0, 0), Vector3(0, 1.6, 0), Vector3(0, 0, 0)],
		"Root:rot": [Vector3(0.06, 0, 0), Vector3(0.06, 0, 0), Vector3(0.06, 0, 0), Vector3(0.06, 0, 0), Vector3(0.06, 0, 0)],
		"Chest": [Vector3(0.05, 0.06, 0), Vector3(0.05, -0.06, 0), Vector3(0.05, 0.06, 0), Vector3(0.05, -0.06, 0), Vector3(0.05, 0.06, 0)],
		"Hem": [Vector3(0.06, 0.1, 0), Vector3(0, -0.1, 0), Vector3(0.06, 0.1, 0), Vector3(0, -0.1, 0), Vector3(0.06, 0.1, 0)],
		"Head": [Vector3(0, 0.02, 0), Vector3(0, -0.02, 0), Vector3(0, 0.02, 0), Vector3(0, -0.02, 0), Vector3(0, 0.02, 0)],
		"ArmL": [Vector3(0.18, 0, 0.35), Vector3(0.16, 0, 0.32), Vector3(0.14, 0, 0.3), Vector3(0.16, 0, 0.32), Vector3(0.18, 0, 0.35)],
		"ArmR": [Vector3(0.5, 0, -0.12), Vector3(0.08, 0, -0.08), Vector3(-0.4, 0, -0.1), Vector3(0.08, 0, -0.08), Vector3(0.5, 0, -0.12)],
		"LegL": [Vector3(-0.6, 0, 0), Vector3(0.04, 0, 0), Vector3(0.7, 0, 0), Vector3(0.04, 0, 0), Vector3(-0.6, 0, 0)],
		"LegR": [Vector3(0.7, 0, 0), Vector3(0.04, 0, 0), Vector3(-0.6, 0, 0), Vector3(0.04, 0, 0), Vector3(0.7, 0, 0)],
	}))
	lib.add_animation("attack", _clip(0.2, false, {
		"Root:rot": [Vector3(-0.12, 0, 0), Vector3(0.22, 0, 0), Vector3(0, 0, 0)],
		"Chest": [Vector3(-0.25, 0, 0), Vector3(0.4, 0, 0), Vector3(0.05, 0, 0)],
		"ArmR": [Vector3(1.05, 0.15, -0.2), Vector3(-1.85, 0.05, 0), Vector3(0.2, 0, 0)],
		"ArmL": [Vector3(0.15, 0, 0.2), Vector3(-0.35, 0, 0.1), Vector3(0.15, 0, 0)],
		"Hem": [Vector3(-0.08, 0, 0), Vector3(0.2, 0, 0.08), Vector3(0, 0, 0)],
	}))
	lib.add_animation("cast_q", _clip(0.45, false, {
		"Chest": [Vector3(0, 0, 0), Vector3(0.15, 0, 0), Vector3(0, 0, 0)],
		"ArmL": [Vector3(0.2, 0, 0), Vector3(-1.1, 0.3, 0), Vector3(0.2, 0, 0)],
		"ArmR": [Vector3(0.2, 0, 0), Vector3(-1.15, -0.3, 0), Vector3(0.2, 0, 0)],
	}))
	lib.add_animation("cast_w", _clip(0.5, false, {
		"Root": [Vector3(0, 0, 0), Vector3(0, 4, 0), Vector3(0, 0, 0)],
		"ArmL": [Vector3(0.2, 0, 0), Vector3(0.9, 0, 0.5), Vector3(0.2, 0, 0)],
		"ArmR": [Vector3(0.2, 0, 0), Vector3(0.9, 0, -0.5), Vector3(0.2, 0, 0)],
		"Head": [Vector3(0, 0, 0), Vector3(0.2, 0, 0), Vector3(0, 0, 0)],
	}))
	lib.add_animation("cast_e", _clip(0.45, false, {
		"Chest": [Vector3(0, -0.4, 0), Vector3(0, 0.6, 0), Vector3(0, 0, 0)],
		"ArmR": [Vector3(0, -0.8, 0), Vector3(-0.4, 1.0, 0), Vector3(0.2, 0, 0)],
		"Hem": [Vector3(0, -0.2, 0), Vector3(0, 0.25, 0), Vector3(0, 0, 0)],
	}))
	lib.add_animation("cast_r", _clip(0.7, false, {
		"Root": [Vector3(0, 0, 0), Vector3(0, 14, 0), Vector3(0, 2, 0)],
		"Chest": [Vector3(0.1, 0, 0), Vector3(-0.35, 0, 0), Vector3(0, 0, 0)],
		"ArmL": [Vector3(0.2, 0, 0), Vector3(-2.3, 0.2, 0), Vector3(0.2, 0, 0)],
		"ArmR": [Vector3(0.2, 0, 0), Vector3(-2.3, -0.2, 0), Vector3(0.2, 0, 0)],
		"Head": [Vector3(0, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0, 0)],
	}))
	lib.add_animation("dash", _clip(0.42, false, {
		"Root": [Vector3(0, -6, 0), Vector3(0, -2, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)],
		"Root:rot": [Vector3(-0.18, 0, 0), Vector3(0.72, 0, 0), Vector3(0.58, 0, 0), Vector3(0.08, 0, 0)],
		"Chest": [Vector3(-0.25, 0, 0), Vector3(0.62, 0, 0), Vector3(0.55, 0, 0), Vector3(0.06, 0, 0)],
		"Head": [Vector3(0.2, 0, 0), Vector3(0.35, 0, 0), Vector3(0.22, 0, 0), Vector3(0, 0, 0)],
		"ArmL": [Vector3(0.35, 0.2, 0.4), Vector3(-0.15, 1.15, 0.15), Vector3(-0.05, 1.25, 0.05), Vector3(0.15, 0.1, 0)],
		"ArmR": [Vector3(0.35, -0.2, -0.4), Vector3(-0.15, -1.15, -0.15), Vector3(-0.05, -1.25, -0.05), Vector3(0.15, -0.1, 0)],
		"Hem": [Vector3(0.15, 0, 0), Vector3(-0.85, 0, 0), Vector3(-0.65, 0, 0.08), Vector3(0, 0, 0)],
		"LegL": [Vector3(0.85, 0, 0), Vector3(-1.15, 0, 0), Vector3(-0.85, 0, 0), Vector3(0.05, 0, 0)],
		"LegR": [Vector3(-0.95, 0, 0), Vector3(0.75, 0, 0), Vector3(0.55, 0, 0), Vector3(0, 0, 0)],
	}))
	lib.add_animation("recall", _clip(8.0, false, {
		"Root": [Vector3(0, 0, 0), Vector3(0, -3, 0), Vector3(0, -3, 0), Vector3(0, 26, 0)],
		"Root:rot": [Vector3(0, 0, 0), Vector3(0.08, 0, 0), Vector3(0.08, 0, 0), Vector3(-0.05, 0, 0)],
		"Chest": [Vector3(0.05, 0, 0), Vector3(-0.28, 0, 0), Vector3(-0.28, 0, 0), Vector3(-0.12, 0, 0)],
		"Head": [Vector3(0.1, 0, 0), Vector3(-0.35, 0, 0), Vector3(-0.32, 0, 0), Vector3(-0.45, 0, 0)],
		"ArmL": [Vector3(0.25, 0, 0.1), Vector3(-1.35, 0.35, 0.2), Vector3(-1.28, 0.28, 0.16), Vector3(-1.7, 0.2, 0.1)],
		"ArmR": [Vector3(0.25, 0, -0.1), Vector3(-1.35, -0.35, -0.2), Vector3(-1.28, -0.28, -0.16), Vector3(-1.7, -0.2, -0.1)],
		"Hem": [Vector3(0, 0, 0), Vector3(0.12, 0, 0), Vector3(0.08, 0.04, 0), Vector3(-0.2, 0, 0)],
		"LegL": [Vector3(0, 0, 0), Vector3(0.42, 0, 0.05), Vector3(0.42, 0, 0.05), Vector3(0.15, 0, 0)],
		"LegR": [Vector3(0, 0, 0), Vector3(0.42, 0, -0.05), Vector3(0.42, 0, -0.05), Vector3(0.15, 0, 0)],
	}))
	lib.add_animation("death", _clip(0.9, false, {
		"Root:rot": [Vector3(0, 0, 0), Vector3(1.15, 0, 0.1), Vector3(1.25, 0, 0)],
		"Root": [Vector3(0, 4, 0), Vector3(0, -6, 0), Vector3(0, -16, 0)],
		"Hem": [Vector3(0, 0, 0), Vector3(0.4, 0, 0.2), Vector3(0.5, 0, 0)],
		"ArmL": [Vector3(0.2, 0, 0), Vector3(0.6, 0, 0.4), Vector3(0.8, 0, 0.2)],
		"ArmR": [Vector3(0.2, 0, 0), Vector3(0.5, 0, -0.3), Vector3(0.7, 0, -0.1)],
	}))
	anim.root_node = NodePath("..")
	anim.add_animation_library("", lib)
	anim.play("idle")
	state = "idle"

func _clip(length: float, looping: bool, tracks: Dictionary) -> Animation:
	var animation = Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	for key in tracks.keys():
		var frames: Array = tracks[key]
		var rot = str(key).ends_with(":rot")
		var node = "Root" if rot else str(key)
		var path = _bone_path(node)
		if rot or node != "Root":
			var ti = animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(ti, path)
			for i in frames.size():
				var t = length * float(i) / float(maxi(frames.size() - 1, 1))
				animation.rotation_track_insert_key(ti, t, Quaternion.from_euler(frames[i]))
		else:
			var base = _root_rest()
			var ti = animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(ti, path)
			for i in frames.size():
				var t = length * float(i) / float(maxi(frames.size() - 1, 1))
				animation.position_track_insert_key(ti, t, base + frames[i])
	return animation

func _root_rest() -> Vector3:
	var root = get_node_or_null("Root")
	if root == null:
		return Vector3.ZERO
	return Vector3(0, root.position.y, 0) if kind_name != "warlord" and kind_name != "spear" and kind_name != "axe" else Vector3.ZERO

func _bone_path(node: String) -> NodePath:
	match node:
		"Root":
			return NodePath("Root")
		"Chest":
			return NodePath("Root/Chest")
		"Head":
			return NodePath("Root/Chest/Head")
		"ArmL":
			return NodePath("Root/Chest/ArmL")
		"ArmR":
			return NodePath("Root/Chest/ArmR")
		"Hem":
			return NodePath("Root/Hem")
		"LegL":
			return NodePath("Root/LegL")
		"LegR":
			return NodePath("Root/LegR")
		_:
			return NodePath(node)

func _process(delta: float) -> void:
	var unit = get_parent()
	if unit == null:
		return
	if anim == null:
		beast_phase += delta * (9.0 if unit.moving else 1.6)
		for i in beast_legs.size():
			var leg: Node3D = beast_legs[i]
			var sgn = 1.0 if i % 2 == 0 else -1.0
			if kind_name == "dragon" or kind_name == "boss":
				leg.rotation.z = sin(beast_phase * 0.6) * 0.35 * (1.0 if i == 0 else -1.0)
			elif unit.moving:
				leg.rotation.x = sin(beast_phase + float(i) * 1.5) * 0.55 * sgn
			else:
				leg.rotation.x = lerpf(leg.rotation.x, 0.0, 0.15)
		for part in breath_parts:
			if not part.has_meta("rest"):
				part.set_meta("rest", part.scale)
			var rest: Vector3 = part.get_meta("rest")
			part.scale = rest * (1.0 + sin(beast_phase * 0.8) * 0.025)
		if unit.windup > 0.0:
			var head = get_node_or_null("Head")
			if head:
				head.rotation.x = -0.5 + (1.0 - unit.windup / max(unit.windup_full, 0.01)) * 0.5
		return
	var next = "idle"
	if unit.dead:
		next = "death"
	elif unit.dash_left > 0.0:
		next = "dash"
	elif unit.windup > 0.0:
		next = "attack"
	elif unit.recall > 0.0:
		next = "recall"
	elif unit.cast_left > 0.05 and unit.cast_pose != "":
		next = "cast_" + str(unit.cast_pose)
	elif unit.moving:
		next = "walk_" + _gait()
	if next != state:
		state = next
		if anim.has_animation(next):
			anim.play(next, 0.08)
	if state == "attack" and unit.windup_full > 0.05:
		anim.speed_scale = 0.2 / unit.windup_full
	elif state.begins_with("walk"):
		anim.speed_scale = clampf(unit.speed() / 330.0, 0.86, 1.22)
		_footstep(unit)
	elif state == "dash":
		anim.speed_scale = 0.42 / maxf(unit.dash_full, 0.18)
	elif state == "recall":
		anim.speed_scale = 1.0
	else:
		anim.speed_scale = 1.0
	_tick_dash_fx(delta, unit)
	for mote in motes:
		var index = int(mote.get_meta("index"))
		var ang = Time.get_ticks_msec() / 380.0 + index * TAU / 3.0
		var reach = 34.0
		var height = 78.0
		if state == "attack" and index == 0:
			reach = 70.0
			height = 60.0
		mote.position = Vector3(cos(ang) * reach, height + sin(ang * 2.0) * 6.0, sin(ang) * 16.0)

func _gait() -> String:
	match kind_name:
		"warlord", "tank":
			return "heavy"
		"axe":
			return "lumber"
		"spear":
			return "stride"
		"assassin":
			return "quick"
		"bow":
			return "light"
		_:
			return "glide"

func _footstep(unit) -> void:
	if anim == null or anim.current_animation_length <= 0.01:
		return
	var phase = anim.current_animation_position / anim.current_animation_length
	var mark = 0 if phase < 0.5 else 1
	if mark == step_mark:
		return
	step_mark = mark
	var host = unit.get_parent()
	if host != null and host.get("player") == unit:
		Sfx.play("step")

func _make_streak() -> void:
	streak = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(16, 6, 64)
	streak.mesh = box
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.72, 0.86, 1.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(0.62, 0.84, 1.0)
	mat.emission_energy_multiplier = 1.6
	streak.material_override = mat
	streak.position = Vector3(0, 40, 26)
	streak.visible = false
	add_child(streak)

func _tick_dash_fx(delta: float, unit) -> void:
	var dashing = unit.dash_left > 0.0 and not unit.dead
	if streak:
		streak.visible = dashing
		if dashing:
			var u = 1.0 - clampf(unit.dash_left / maxf(unit.dash_full, 0.01), 0.0, 1.0)
			var punch = sin(clampf(u, 0.0, 1.0) * PI)
			streak.scale = Vector3(0.45 + punch * 0.55, 0.3 + punch * 0.2, 0.45 + punch * 1.7)
			var mat := streak.material_override as StandardMaterial3D
			mat.albedo_color.a = 0.08 + punch * 0.28
	if dashing:
		ghost_cd -= delta
		if ghost_cd <= 0.0:
			ghost_cd = 0.04
			_drop_ghost(unit)
	else:
		ghost_cd = 0.0
	for i in range(ghosts.size() - 1, -1, -1):
		var g = ghosts[i]
		g["life"] = float(g["life"]) - delta
		var mesh: MeshInstance3D = g["mesh"]
		var mat := mesh.material_override as StandardMaterial3D
		var a = clampf(float(g["life"]) / 0.26, 0.0, 1.0)
		mat.albedo_color.a = a * 0.38
		mesh.scale = Vector3.ONE * (1.0 + (1.0 - a) * 0.15)
		if float(g["life"]) <= 0.0:
			mesh.queue_free()
			ghosts.remove_at(i)

func _drop_ghost(unit) -> void:
	var host = unit.get_parent()
	if host == null:
		return
	var mesh = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 11
	cap.height = 52
	mesh.mesh = cap
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tint = Color(0.58, 0.82, 1.0, 0.36)
	if str(unit.team) == "red":
		tint = Color(1.0, 0.48, 0.36, 0.36)
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = Color(tint.r, tint.g, tint.b)
	mat.emission_energy_multiplier = 1.2
	mesh.material_override = mat
	host.add_child(mesh)
	mesh.global_position = unit.global_position + Vector3(0, 34, 0)
	mesh.rotation = unit.rotation
	ghosts.append({"mesh": mesh, "life": 0.26})
