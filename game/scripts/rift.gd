extends RefCounted

const SIZE = 14800.0
const RIVER_DEPTH = -34.0
const PLAZA_H = 8.0

static var _rock_shader: Shader = null
static var _ground_sh: Shader = null
static var _water_sh: Shader = null
static var _leaf_sh: Shader = null

static func build(parent: Node3D) -> Dictionary:
	var walls: Array = []
	_terrain(parent)
	_river(parent)
	_border(parent, walls)
	_jungle(parent, walls)
	_flora(parent)
	_camps(parent)
	_base_plaza(parent, Vector3(1700, 0, 1700), Color(0.25, 0.45, 0.85))
	_base_plaza(parent, Vector3(13100, 0, 13100), Color(0.78, 0.26, 0.22))
	_lane_lamps(parent)
	var lanes = {
		"top": _top(),
		"mid": _mid(),
		"bot": _bot(),
	}
	var structures: Array = []
	_bases(structures)
	_lane_buildings(structures, lanes)
	return {
		"size": SIZE,
		"spawn": Vector3(2900, 0, 2500),
		"fountain": Vector3(2100, 0, 2000),
		"fountain_r": 1100.0,
		"lanes": lanes,
		"structures": structures,
		"walls": walls,
	}

# ---------- noise ----------

static func _hash(ix: int, iz: int) -> float:
	var h = ix * 374761393 + iz * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0

static func _vnoise(x: float, z: float) -> float:
	var ix = int(floor(x))
	var iz = int(floor(z))
	var fx = x - floor(x)
	var fz = z - floor(z)
	var ux = fx * fx * (3.0 - 2.0 * fx)
	var uz = fz * fz * (3.0 - 2.0 * fz)
	var a = _hash(ix, iz)
	var b = _hash(ix + 1, iz)
	var c = _hash(ix, iz + 1)
	var d = _hash(ix + 1, iz + 1)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uz)

static func _fbm(x: float, z: float, octaves: int) -> float:
	var sum = 0.0
	var amp = 0.5
	var freq = 1.0
	for _i in octaves:
		sum += _vnoise(x * freq, z * freq) * amp
		freq *= 2.05
		amp *= 0.5
	return sum

# ---------- masks ----------

static func _lane_d(x: float, z: float) -> float:
	var best = 1.0e9
	for pts in [_top(), _mid(), _bot()]:
		for i in range(pts.size() - 1):
			best = min(best, _dist_seg(x, z, pts[i], pts[i + 1]))
	return best

static func _lane_w(x: float, z: float) -> float:
	return 1.0 - smoothstep(330.0, 560.0, _lane_d(x, z))

static func _river_w(x: float, z: float) -> float:
	var dist = absf(x + z - SIZE) / sqrt(2.0)
	var edge = min(min(x, z), min(SIZE - x, SIZE - z))
	var fade = clampf((edge - 2500.0) / 700.0, 0.0, 1.0)
	var w = (1.0 - smoothstep(360.0, 640.0, dist)) * fade
	return w * (1.0 - _lane_w(x, z))

static func _base_w(x: float, z: float) -> float:
	var d1 = Vector2(x, z).distance_to(Vector2(1700, 1700))
	var d2 = Vector2(x, z).distance_to(Vector2(13100, 13100))
	return max(1.0 - smoothstep(1450.0, 1850.0, d1), 1.0 - smoothstep(1450.0, 1850.0, d2))

static func _near_lane(x: float, z: float) -> bool:
	return _lane_d(x, z) < 430.0

static func ground_y(x: float, z: float) -> float:
	var lane = _lane_w(x, z)
	var river = _river_w(x, z)
	var base = _base_w(x, z)
	var h = (_fbm(x * 0.00042, z * 0.00042, 4) - 0.5) * 70.0 + 12.0
	h += (_fbm(x * 0.0021 + 7.0, z * 0.0021 + 3.0, 2) - 0.5) * 10.0
	h = lerpf(h, 0.0, lane)
	h = lerpf(h, RIVER_DEPTH, river)
	h = lerpf(h, PLAZA_H, base)
	if lane > 0.985:
		h = 0.0
	return h

static func _dist_seg(x: float, z: float, a: Vector3, b: Vector3) -> float:
	var ab = Vector2(b.x - a.x, b.z - a.z)
	var ap = Vector2(x - a.x, z - a.z)
	var den = ab.length_squared()
	var t = 0.0 if den <= 0.001 else clampf(ap.dot(ab) / den, 0.0, 1.0)
	var q = Vector2(a.x, a.z) + ab * t
	return q.distance_to(Vector2(x, z))

# ---------- terrain ----------

static func _terrain(parent: Node3D) -> void:
	var n = 170
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in n:
		for x in n:
			var px = float(x) / float(n - 1) * SIZE
			var pz = float(z) / float(n - 1) * SIZE
			var lane = _lane_w(px, pz)
			var river = _river_w(px, pz)
			var base = _base_w(px, pz)
			st.set_color(Color(lane, river, base, 1.0))
			st.set_uv(Vector2(px / SIZE, pz / SIZE))
			st.add_vertex(Vector3(px, ground_y(px, pz), pz))
	for z in n - 1:
		for x in n - 1:
			var i = z * n + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + n)
			st.add_index(i + 1)
			st.add_index(i + n + 1)
			st.add_index(i + n)
	st.generate_normals()
	st.generate_tangents()
	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = st.commit()
	var mat = ShaderMaterial.new()
	mat.shader = _ground_shader()
	mesh_node.material_override = mat
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_node)

static func _noise_glsl() -> String:
	return """
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p){
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		s += vnoise(p) * a;
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s;
}
"""

static func _ground_shader() -> Shader:
	if _ground_sh != null:
		return _ground_sh
	var sh = Shader.new()
	sh.code = "shader_type spatial;\nrender_mode diffuse_burley, specular_schlick_ggx;\nvarying vec4 wgt;\nvarying vec3 wpos;\n" + _noise_glsl() + """
void vertex(){
	wgt = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment(){
	vec2 p = wpos.xz;
	float macro = fbm(p * 0.0012);
	float meso = fbm(p * 0.009);
	float micro = fbm(p * 0.045);
	vec3 grassA = vec3(0.025, 0.07, 0.03);
	vec3 grassB = vec3(0.05, 0.12, 0.045);
	vec3 grassC = vec3(0.08, 0.14, 0.05);
	vec3 grass = mix(grassA, grassB, macro);
	grass = mix(grass, grassC, smoothstep(0.55, 0.85, meso) * 0.5);
	grass *= 0.86 + micro * 0.28;
	float blade = smoothstep(0.78, 0.92, vnoise(p * 0.32 + meso * 4.0));
	grass = mix(grass, grassB * 1.25, blade * 0.35);
	vec3 dirtA = vec3(0.22, 0.16, 0.09);
	vec3 dirtB = vec3(0.32, 0.24, 0.13);
	vec3 dirt = mix(dirtA, dirtB, smoothstep(0.3, 0.7, meso));
	float pebble = smoothstep(0.74, 0.8, vnoise(p * 0.35));
	dirt = mix(dirt, vec3(0.5, 0.48, 0.44), pebble * 0.4);
	float rut = smoothstep(0.35, 0.5, abs(fbm(p * 0.004) - 0.5)) ;
	dirt *= 0.9 + micro * 0.2 - rut * 0.08;
	vec3 bed = mix(vec3(0.14, 0.16, 0.16), vec3(0.28, 0.3, 0.3), meso);
	bed *= 0.8 + micro * 0.4;
	vec2 tile = fract(p / 64.0);
	float mortar = 1.0 - smoothstep(0.0, 0.08, min(min(tile.x, 1.0 - tile.x), min(tile.y, 1.0 - tile.y)));
	vec3 plaza = mix(vec3(0.3, 0.29, 0.27), vec3(0.4, 0.38, 0.34), vnoise(floor(p / 64.0)));
	plaza *= 0.9 + micro * 0.2;
	plaza = mix(plaza, vec3(0.18, 0.17, 0.16), mortar * 0.85);
	float laneEdge = smoothstep(0.25, 0.75, wgt.r + (meso - 0.5) * 0.5);
	float riverEdge = smoothstep(0.3, 0.8, wgt.g + (micro - 0.5) * 0.3);
	float baseEdge = smoothstep(0.35, 0.7, wgt.b + (meso - 0.5) * 0.25);
	vec3 albedo = grass;
	albedo = mix(albedo, dirt, laneEdge);
	albedo = mix(albedo, bed, riverEdge);
	albedo = mix(albedo, plaza, baseEdge);
	float rough = mix(0.92, 0.78, laneEdge);
	rough = mix(rough, 0.55, riverEdge);
	rough = mix(rough, 0.62, baseEdge);
	float e = 1.6;
	float hL = fbm((p + vec2(-e, 0.0)) * 0.045);
	float hR = fbm((p + vec2(e, 0.0)) * 0.045);
	float hD = fbm((p + vec2(0.0, -e)) * 0.045);
	float hU = fbm((p + vec2(0.0, e)) * 0.045);
	float strength = mix(2.2, 0.9, laneEdge);
	strength = mix(strength, 0.4, baseEdge);
	vec3 nm = normalize(vec3((hL - hR) * strength, (hD - hU) * strength, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.25;
	AO = 0.85 + macro * 0.15;
	AO_LIGHT_AFFECT = 0.4;
}
"""
	_ground_sh = sh
	return sh

# ---------- water ----------

static func _river(parent: Node3D) -> void:
	var mesh_node = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(10400, 1180)
	plane.subdivide_width = 48
	plane.subdivide_depth = 6
	mesh_node.mesh = plane
	mesh_node.position = Vector3(SIZE * 0.5, RIVER_DEPTH + 18.0, SIZE * 0.5)
	mesh_node.rotation.y = PI * 0.25
	var mat = ShaderMaterial.new()
	mat.shader = _water_shader()
	mesh_node.material_override = mat
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_node)

static func _water_shader() -> Shader:
	if _water_sh != null:
		return _water_sh
	var sh = Shader.new()
	sh.code = "shader_type spatial;\nrender_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;\nvarying vec3 wpos;\n" + _noise_glsl() + """
void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.012 + TIME * 1.3) * 1.2 + cos(wpos.z * 0.015 - TIME * 0.9) * 1.0;
}
void fragment(){
	vec2 p = wpos.xz * 0.02;
	vec2 flow = vec2(TIME * 0.35, -TIME * 0.22);
	float e = 0.08;
	float h0 = fbm(p + flow) * 0.6 + fbm(p * 2.3 - flow * 1.4) * 0.4;
	float hx = fbm(p + vec2(e, 0.0) + flow) * 0.6 + fbm((p + vec2(e, 0.0)) * 2.3 - flow * 1.4) * 0.4;
	float hz = fbm(p + vec2(0.0, e) + flow) * 0.6 + fbm((p + vec2(0.0, e)) * 2.3 - flow * 1.4) * 0.4;
	vec3 nm = normalize(vec3((h0 - hx) * 3.5, (h0 - hz) * 3.5, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	float bank = smoothstep(0.30, 0.49, abs(UV.y - 0.5));
	float foam = smoothstep(0.55, 0.8, fbm(p * 3.0 + flow * 2.0)) * bank;
	vec3 deep = vec3(0.03, 0.12, 0.2);
	vec3 shallow = vec3(0.12, 0.38, 0.46);
	vec3 col = mix(deep, shallow, bank * 0.7 + h0 * 0.3);
	col = mix(col, vec3(0.82, 0.9, 0.92), foam * 0.8);
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	ALBEDO = col;
	ALPHA = clamp(0.72 + fres * 0.26 + foam * 0.2, 0.0, 0.98);
	ROUGHNESS = mix(0.04, 0.3, foam);
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = vec3(0.02, 0.08, 0.12) * (0.4 + h0 * 0.6);
}
"""
	_water_sh = sh
	return sh

# ---------- rock / walls ----------

static func _rock_material() -> ShaderMaterial:
	if _rock_shader == null:
		var sh = Shader.new()
		sh.code = "shader_type spatial;\nrender_mode diffuse_burley, specular_schlick_ggx;\nvarying vec3 wpos;\nvarying vec3 wnrm;\n" + _noise_glsl() + """
void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment(){
	vec3 ap = abs(wnrm);
	ap /= (ap.x + ap.y + ap.z);
	float nx = fbm(wpos.zy * 0.02);
	float ny = fbm(wpos.xz * 0.02);
	float nz = fbm(wpos.xy * 0.02);
	float n = nx * ap.x + ny * ap.y + nz * ap.z;
	float fine = vnoise(wpos.xz * 0.14 + wpos.y * 0.07);
	vec3 base = mix(vec3(0.22, 0.21, 0.2), vec3(0.42, 0.4, 0.37), n);
	base = mix(base, vec3(0.5, 0.46, 0.4), smoothstep(0.7, 0.9, fine) * 0.4);
	float up = clamp(wnrm.y, 0.0, 1.0);
	float moss = smoothstep(0.45, 0.85, up) * smoothstep(0.35, 0.7, fbm(wpos.xz * 0.01 + 3.0));
	base = mix(base, vec3(0.16, 0.3, 0.14), moss);
	float e = 1.5;
	float hL = vnoise((wpos.xz + vec2(-e, 0.0)) * 0.14);
	float hR = vnoise((wpos.xz + vec2(e, 0.0)) * 0.14);
	float hD = vnoise((wpos.xz + vec2(0.0, -e)) * 0.14);
	float hU = vnoise((wpos.xz + vec2(0.0, e)) * 0.14);
	NORMAL_MAP = normalize(vec3((hL - hR) * 2.5, (hD - hU) * 2.5, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = base;
	ROUGHNESS = mix(0.95, 0.75, n);
	METALLIC = 0.0;
	SPECULAR = 0.2;
}
"""
		_rock_shader = sh
	var mat = ShaderMaterial.new()
	mat.shader = _rock_shader
	return mat

static func _border(parent: Node3D, walls: Array) -> void:
	_wall(parent, walls, 0, 0, SIZE, 240, 420)
	_wall(parent, walls, 0, SIZE - 240, SIZE, 240, 420)
	_wall(parent, walls, 0, 0, 240, SIZE, 420)
	_wall(parent, walls, SIZE - 240, 0, 240, SIZE, 420)

static func _blue_walls() -> Array:
	return [
		[2600, 7000, 900, 500, 240],
		[3300, 8600, 1400, 450, 240],
		[4100, 5600, 450, 1400, 230],
		[2300, 4400, 1200, 500, 230],
		[4900, 7200, 700, 900, 220],
		[2400, 5700, 500, 900, 200],
		[7000, 2600, 500, 900, 240],
		[8600, 3300, 450, 1400, 240],
		[5600, 4100, 1400, 450, 230],
		[4400, 2300, 500, 1200, 230],
		[7200, 4900, 900, 700, 220],
		[5700, 2400, 900, 500, 200],
		[3900, 9200, 400, 1500, 260],
		[4000, 10300, 1600, 500, 260],
	]

static func _jungle(parent: Node3D, walls: Array) -> void:
	for w in _blue_walls():
		_wall(parent, walls, w[0], w[1], w[2], w[3], w[4])
		_wall(parent, walls, SIZE - w[0] - w[2], SIZE - w[1] - w[3], w[2], w[3], w[4])
	_rock(parent, Vector3(5600, 0, 6400), 90)
	_rock(parent, Vector3(9200, 0, 8400), 90)
	_rock(parent, Vector3(3000, 0, 9800), 70)
	_rock(parent, Vector3(11800, 0, 5000), 70)

static func _in_wall(x: float, z: float, pad: float) -> bool:
	for w in _blue_walls():
		if x >= w[0] - pad and x <= w[0] + w[2] + pad and z >= w[1] - pad and z <= w[1] + w[3] + pad:
			return true
		var mx = SIZE - w[0] - w[2]
		var mz = SIZE - w[1] - w[3]
		if x >= mx - pad and x <= mx + w[2] + pad and z >= mz - pad and z <= mz + w[3] + pad:
			return true
	return false

static func camp_defs() -> Array:
	var blue = [
		{"name": "푸른 파수꾼", "style": "golem", "pos": Vector3(3800, 0, 7900), "hp": 2100, "ad": 82, "range": 150, "asp": 0.55, "size": 1.5, "tint": Color(0.3, 0.5, 0.95), "bounty": 90, "respawn": 300.0, "count": 1},
		{"name": "늪두꺼비", "style": "beast", "pos": Vector3(2100, 0, 8400), "hp": 1800, "ad": 70, "range": 170, "asp": 0.5, "size": 1.35, "tint": Color(0.3, 0.45, 0.25), "bounty": 80, "respawn": 135.0, "count": 1},
		{"name": "회색늑대", "style": "beast", "pos": Vector3(3800, 0, 6500), "hp": 1300, "ad": 42, "range": 120, "asp": 0.75, "size": 1.0, "tint": Color(0.42, 0.42, 0.46), "bounty": 55, "respawn": 135.0, "count": 3},
		{"name": "칼날부리", "style": "beast", "pos": Vector3(7000, 0, 5400), "hp": 1100, "ad": 36, "range": 110, "asp": 0.9, "size": 0.75, "tint": Color(0.6, 0.3, 0.2), "bounty": 50, "respawn": 135.0, "count": 4},
		{"name": "붉은 가시등", "style": "beast", "pos": Vector3(7800, 0, 4100), "hp": 2100, "ad": 88, "range": 160, "asp": 0.55, "size": 1.55, "tint": Color(0.75, 0.22, 0.14), "bounty": 90, "respawn": 300.0, "count": 1},
		{"name": "바위게르", "style": "golem", "pos": Vector3(8400, 0, 2700), "hp": 1400, "ad": 50, "range": 130, "asp": 0.6, "size": 1.0, "tint": Color(0.5, 0.42, 0.32), "bounty": 60, "respawn": 135.0, "count": 2},
	]
	var out = []
	for d in blue:
		out.append(d)
		var m = d.duplicate()
		m["pos"] = Vector3(SIZE - d["pos"].x, 0, SIZE - d["pos"].z)
		out.append(m)
	out.append({"name": "균열게", "style": "crab", "pos": Vector3(5900, 0, 8900), "hp": 1600, "ad": 60, "range": 140, "asp": 0.7, "size": 1.0, "tint": Color(0.45, 0.2, 0.65), "bounty": 70, "respawn": 180.0, "count": 1})
	out.append({"name": "균열게", "style": "crab", "pos": Vector3(8900, 0, 5900), "hp": 1600, "ad": 60, "range": 140, "asp": 0.7, "size": 1.0, "tint": Color(0.45, 0.2, 0.65), "bounty": 70, "respawn": 180.0, "count": 1})
	out.append({"name": "골짜기룡", "style": "dragon", "pos": Vector3(9900, 0, 4900), "hp": 5200, "ad": 160, "range": 280, "asp": 0.5, "size": 1.4, "tint": Color(0.68, 0.34, 0.12), "bounty": 150, "respawn": 300.0, "count": 1})
	out.append({"name": "균열의 거수", "style": "boss", "pos": Vector3(4900, 0, 9900), "hp": 9000, "ad": 240, "range": 320, "asp": 0.45, "size": 1.9, "tint": Color(0.36, 0.22, 0.5), "bounty": 300, "respawn": 360.0, "count": 1})
	return out

static func minimap_image(size: int) -> Image:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for py in size:
		for px in size:
			var x = (float(px) + 0.5) / float(size) * SIZE
			var z = (1.0 - (float(py) + 0.5) / float(size)) * SIZE
			var lane = _lane_w(x, z)
			var river = _river_w(x, z)
			var base = _base_w(x, z)
			var g = _fbm(x * 0.0012, z * 0.0012, 3)
			var col = Color(0.1, 0.26, 0.12).lerp(Color(0.2, 0.38, 0.16), g)
			col = col.lerp(Color(0.6, 0.5, 0.32), lane)
			col = col.lerp(Color(0.14, 0.36, 0.5), river)
			col = col.lerp(Color(0.5, 0.48, 0.44), base)
			for w in _blue_walls():
				var inside = (x >= w[0] and x <= w[0] + w[2] and z >= w[1] and z <= w[1] + w[3])
				var mx = SIZE - w[0] - w[2]
				var mz = SIZE - w[1] - w[3]
				inside = inside or (x >= mx and x <= mx + w[2] and z >= mz and z <= mz + w[3])
				if inside:
					col = Color(0.3, 0.3, 0.28)
			if x < 260 or z < 260 or x > SIZE - 260 or z > SIZE - 260:
				col = Color(0.2, 0.2, 0.18)
			img.set_pixel(px, py, col)
	return img

static func _wall(parent: Node3D, walls: Array, x: float, z: float, w: float, d: float, h: float) -> void:
	walls.append(Rect2(x, z, w, d))
	var rng = RandomNumberGenerator.new()
	rng.seed = int(x * 7 + z * 13 + w)
	var mat = _rock_material()
	var core = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(w - 40, h * 0.62, d - 40)
	core.mesh = box
	core.material_override = mat
	core.position = Vector3(x + w * 0.5, h * 0.31 + ground_y(x + w * 0.5, z + d * 0.5) - 6.0, z + d * 0.5)
	parent.add_child(core)
	var perimeter = 2.0 * (w + d)
	var count = int(clampf(perimeter / 210.0, 8.0, 180.0))
	for i in count:
		var t = float(i) / float(count) * perimeter
		var px = x
		var pz = z
		if t < w:
			px = x + t
			pz = z
		elif t < w + d:
			px = x + w
			pz = z + (t - w)
		elif t < 2.0 * w + d:
			px = x + w - (t - w - d)
			pz = z + d
		else:
			px = x
			pz = z + d - (t - 2.0 * w - d)
		px += rng.randf_range(-40, 40)
		pz += rng.randf_range(-40, 40)
		_boulder(parent, mat, Vector3(px, ground_y(px, pz), pz), rng.randf_range(70, 130) * (h / 260.0), rng)
	var tops = int(clampf((w * d) / 240000.0, 3.0, 40.0))
	for _i in tops:
		var px = rng.randf_range(x + 80, x + w - 80)
		var pz = rng.randf_range(z + 80, z + d - 80)
		_boulder(parent, mat, Vector3(px, h * 0.6, pz), rng.randf_range(60, 120) * (h / 260.0), rng)

static func _boulder(parent: Node3D, mat: Material, pos: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var mesh = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = size
	sph.height = size * 2.0
	sph.radial_segments = 14
	sph.rings = 8
	mesh.mesh = sph
	mesh.material_override = mat
	mesh.position = pos + Vector3(0, size * 0.55, 0)
	mesh.scale = Vector3(rng.randf_range(0.8, 1.35), rng.randf_range(0.6, 1.0), rng.randf_range(0.8, 1.35))
	mesh.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3))
	parent.add_child(mesh)

static func _rock(parent: Node3D, pos: Vector3, size: float) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(pos.x + pos.z * 3.0)
	var mat = _rock_material()
	_boulder(parent, mat, pos + Vector3(0, ground_y(pos.x, pos.z), 0), size, rng)
	for _i in 4:
		var off = Vector3(rng.randf_range(-size * 1.3, size * 1.3), 0, rng.randf_range(-size * 1.3, size * 1.3))
		var p = pos + off
		_boulder(parent, mat, Vector3(p.x, ground_y(p.x, p.z), p.z), size * rng.randf_range(0.35, 0.6), rng)

# ---------- plants ----------

static func _leaf_material(tint: Color) -> ShaderMaterial:
	if _leaf_sh == null:
		var sh = Shader.new()
		sh.code = "shader_type spatial;\nrender_mode diffuse_burley, specular_schlick_ggx, cull_disabled;\nuniform vec3 tint : source_color = vec3(0.15, 0.35, 0.16);\nvarying vec3 wpos;\nvarying vec3 lpos;\n" + _noise_glsl() + """
void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX;
	VERTEX += NORMAL * (sin(TIME * 1.3 + wpos.x * 0.02 + wpos.z * 0.015) * 0.8);
}
void fragment(){
	float n = fbm(wpos.xz * 0.05 + wpos.y * 0.03);
	float up = clamp(lpos.y / 60.0 + 0.5, 0.0, 1.0);
	vec3 col = tint * (0.55 + up * 0.6) * (0.8 + n * 0.4);
	col = mix(col, tint * 1.5, smoothstep(0.75, 0.95, n) * 0.4);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	BACKLIGHT = tint * 0.35;
}
"""
		_leaf_sh = sh
	var mat = ShaderMaterial.new()
	mat.shader = _leaf_sh
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	return mat

static func _flora(parent: Node3D) -> void:
	var trunk_mat = _rock_material()
	var bark = StandardMaterial3D.new()
	bark.albedo_color = Color(0.3, 0.2, 0.12)
	bark.roughness = 0.95
	var leaf_mats = [
		_leaf_material(Color(0.13, 0.34, 0.15)),
		_leaf_material(Color(0.2, 0.42, 0.18)),
		_leaf_material(Color(0.28, 0.38, 0.12)),
		_leaf_material(Color(0.1, 0.3, 0.2)),
	]
	var rng = RandomNumberGenerator.new()
	rng.seed = 1408
	var placed = 0
	var tries = 0
	while placed < 190 and tries < 1600:
		tries += 1
		var x = rng.randf_range(600, SIZE - 600)
		var z = rng.randf_range(600, SIZE - 600)
		if _lane_d(x, z) < 520:
			continue
		if _river_w(x, z) > 0.05:
			continue
		if _base_w(x, z) > 0.02:
			continue
		if x < 400 or z < 400:
			continue
		if _in_wall(x, z, 140.0):
			continue
		var near_camp = false
		for d in camp_defs():
			if Vector2(x, z).distance_to(Vector2(d["pos"].x, d["pos"].z)) < 520.0:
				near_camp = true
				break
		if near_camp:
			continue
		var pine = rng.randf() < 0.35
		var tree = Node3D.new()
		tree.position = Vector3(x, ground_y(x, z), z)
		var height = rng.randf_range(110, 190)
		var trunk = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 9
		cyl.bottom_radius = 22
		cyl.height = height
		cyl.radial_segments = 10
		trunk.mesh = cyl
		trunk.material_override = bark
		trunk.position = Vector3(0, height * 0.5, 0)
		tree.add_child(trunk)
		var flare = MeshInstance3D.new()
		var fc = CylinderMesh.new()
		fc.top_radius = 20
		fc.bottom_radius = 40
		fc.height = 18
		flare.mesh = fc
		flare.material_override = trunk_mat
		flare.position = Vector3(0, 9, 0)
		tree.add_child(flare)
		var leaf = leaf_mats[rng.randi_range(0, leaf_mats.size() - 1)]
		if pine:
			for k in 3:
				var cone = MeshInstance3D.new()
				var cm = CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 70.0 - k * 16.0
				cm.height = 90.0 - k * 10.0
				cm.radial_segments = 12
				cone.mesh = cm
				cone.material_override = leaf
				cone.position = Vector3(0, height * 0.55 + k * 46.0, 0)
				tree.add_child(cone)
		else:
			for k in 4:
				var crown = MeshInstance3D.new()
				var ball = SphereMesh.new()
				ball.radius = rng.randf_range(44, 70)
				ball.height = ball.radius * 1.7
				ball.radial_segments = 16
				ball.rings = 9
				crown.mesh = ball
				crown.material_override = leaf
				var ang = float(k) / 4.0 * TAU + rng.randf()
				crown.position = Vector3(cos(ang) * 28.0, height + 10.0 + rng.randf_range(-16, 26), sin(ang) * 28.0)
				tree.add_child(crown)
			var cap = MeshInstance3D.new()
			var top = SphereMesh.new()
			top.radius = rng.randf_range(40, 56)
			top.height = top.radius * 1.6
			cap.mesh = top
			cap.material_override = leaf
			cap.position = Vector3(0, height + 56, 0)
			tree.add_child(cap)
		tree.rotation.y = rng.randf() * TAU
		parent.add_child(tree)
		placed += 1
	var grass = _leaf_material(Color(0.12, 0.3, 0.12))
	for spot in [Vector3(4800, 0, 2200), Vector3(2400, 0, 5200), Vector3(7000, 0, 5600), Vector3(9800, 0, 6200), Vector3(11800, 0, 9000), Vector3(8600, 0, 11200), Vector3(5000, 0, 8800), Vector3(9600, 0, 4400)]:
		var bush = Node3D.new()
		bush.position = Vector3(spot.x, ground_y(spot.x, spot.z), spot.z)
		for k in 18:
			var blade = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 2.0
			cm.bottom_radius = 16.0
			cm.height = rng.randf_range(70, 110)
			cm.radial_segments = 6
			blade.mesh = cm
			blade.material_override = grass
			var ang = float(k) / 18.0 * TAU
			var rad = 60.0 + rng.randf_range(0, 110)
			blade.position = Vector3(cos(ang) * rad, cm.height * 0.5, sin(ang) * rad)
			blade.rotation = Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
			bush.add_child(blade)
		parent.add_child(bush)

static func _camps(parent: Node3D) -> void:
	var mat = _rock_material()
	var ember = StandardMaterial3D.new()
	ember.albedo_color = Color(0.9, 0.5, 0.2)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.45, 0.1)
	ember.emission_energy_multiplier = 1.6
	var spots = []
	for d in camp_defs():
		spots.append(d["pos"])
	for spot in spots:
		var rng = RandomNumberGenerator.new()
		rng.seed = int(spot.x + spot.z)
		var y = ground_y(spot.x, spot.z)
		var big = spot.distance_to(Vector3(9900, 0, 4900)) < 10 or spot.distance_to(Vector3(4900, 0, 9900)) < 10
		if _river_w(spot.x, spot.z) > 0.3 and not big:
			continue
		var ring = 420.0 if big else 230.0
		for k in 10:
			var ang = float(k) / 10.0 * TAU
			if big and ang > 2.2 and ang < 4.1:
				continue
			var p = spot + Vector3(cos(ang) * ring, 0, sin(ang) * ring)
			_boulder(parent, mat, Vector3(p.x, ground_y(p.x, p.z), p.z), rng.randf_range(30, 52) * (1.6 if big else 1.0), rng)
		var pit = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 90
		cyl.bottom_radius = 110
		cyl.height = 10
		pit.mesh = cyl
		pit.material_override = ember
		pit.position = Vector3(spot.x, y + 4, spot.z)
		parent.add_child(pit)
		var light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.2)
		light.light_energy = 1.4
		light.omni_range = 520
		light.position = Vector3(spot.x, y + 60, spot.z)
		parent.add_child(light)

# ---------- bases ----------

static func _base_plaza(parent: Node3D, pos: Vector3, color: Color) -> void:
	var stone = _rock_material()
	var trim = StandardMaterial3D.new()
	trim.albedo_color = Color(0.86, 0.74, 0.46)
	trim.metallic = 0.7
	trim.roughness = 0.3
	trim.emission_enabled = true
	trim.emission = Color(1, 0.86, 0.5)
	trim.emission_energy_multiplier = 0.25
	var glow = StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 1.4
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color.a = 0.55
	var pool = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 340
	cyl.bottom_radius = 360
	cyl.height = 14
	cyl.radial_segments = 40
	pool.mesh = cyl
	pool.material_override = stone
	pool.position = pos + Vector3(0, PLAZA_H + 6, 0)
	parent.add_child(pool)
	var water = MeshInstance3D.new()
	var wc = CylinderMesh.new()
	wc.top_radius = 300
	wc.bottom_radius = 300
	wc.height = 4
	wc.radial_segments = 40
	water.mesh = wc
	var wmat = ShaderMaterial.new()
	wmat.shader = _water_shader()
	water.material_override = wmat
	water.position = pos + Vector3(0, PLAZA_H + 13, 0)
	parent.add_child(water)
	var beam = MeshInstance3D.new()
	var bc = CylinderMesh.new()
	bc.top_radius = 26
	bc.bottom_radius = 60
	bc.height = 420
	beam.mesh = bc
	beam.material_override = glow
	beam.position = pos + Vector3(0, PLAZA_H + 220, 0)
	parent.add_child(beam)
	for k in 10:
		var ang = float(k) / 10.0 * TAU
		var p = pos + Vector3(cos(ang) * 760.0, 0, sin(ang) * 760.0)
		var col = MeshInstance3D.new()
		var cc = CylinderMesh.new()
		cc.top_radius = 26
		cc.bottom_radius = 34
		cc.height = 260
		cc.radial_segments = 12
		col.mesh = cc
		col.material_override = stone
		col.position = Vector3(p.x, PLAZA_H + 130, p.z)
		parent.add_child(col)
		var cap = MeshInstance3D.new()
		var cb = BoxMesh.new()
		cb.size = Vector3(80, 18, 80)
		cap.mesh = cb
		cap.material_override = trim
		cap.position = Vector3(p.x, PLAZA_H + 268, p.z)
		parent.add_child(cap)
		var orb = MeshInstance3D.new()
		var ob = SphereMesh.new()
		ob.radius = 18
		ob.height = 36
		orb.mesh = ob
		orb.material_override = glow
		orb.position = Vector3(p.x, PLAZA_H + 300, p.z)
		parent.add_child(orb)
	var light = OmniLight3D.new()
	light.position = pos + Vector3(0, 260, 0)
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 1600
	light.shadow_enabled = true
	parent.add_child(light)

static func _lane_lamps(parent: Node3D) -> void:
	var stone = _rock_material()
	var flame = StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.8, 0.45)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.75, 0.35)
	flame.emission_energy_multiplier = 2.0
	for pts in [_top(), _mid(), _bot()]:
		for i in range(1, pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var dir = (b - a)
			dir.y = 0
			if dir.length() < 1:
				continue
			dir = dir.normalized()
			var side = Vector3(-dir.z, 0, dir.x)
			for s in [-1.0, 1.0]:
				var p = a + side * s * 470.0
				var y = ground_y(p.x, p.z)
				var post = MeshInstance3D.new()
				var cyl = CylinderMesh.new()
				cyl.top_radius = 8
				cyl.bottom_radius = 14
				cyl.height = 150
				cyl.radial_segments = 8
				post.mesh = cyl
				post.material_override = stone
				post.position = Vector3(p.x, y + 75, p.z)
				parent.add_child(post)
				var fire = MeshInstance3D.new()
				var sph = SphereMesh.new()
				sph.radius = 12
				sph.height = 24
				fire.mesh = sph
				fire.material_override = flame
				fire.position = Vector3(p.x, y + 162, p.z)
				parent.add_child(fire)
				var light = OmniLight3D.new()
				light.light_color = Color(1.0, 0.78, 0.4)
				light.light_energy = 0.9
				light.omni_range = 380
				light.position = Vector3(p.x, y + 170, p.z)
				parent.add_child(light)

# ---------- structures ----------

static func _bases(structures: Array) -> void:
	structures.append(_struct("nexus", "blue", "푸른 넥서스", Vector3(1600, 0, 1600), 5500, 0, 0))
	structures.append(_struct("tower", "blue", "넥서스 포탑", Vector3(2350, 0, 1500), 4550, 210, 775))
	structures.append(_struct("tower", "blue", "넥서스 포탑", Vector3(1500, 0, 2350), 4550, 210, 775))
	structures.append(_struct("nexus", "red", "붉은 넥서스", Vector3(13200, 0, 13200), 5500, 0, 0))
	structures.append(_struct("tower", "red", "넥서스 포탑", Vector3(12450, 0, 13300), 4550, 210, 775))
	structures.append(_struct("tower", "red", "넥서스 포탑", Vector3(13300, 0, 12450), 4550, 210, 775))

static func _lane_buildings(structures: Array, lanes: Dictionary) -> void:
	for key in lanes.keys():
		var pts: Array = lanes[key]
		var n = pts.size()
		structures.append(_struct("inhibitor", "blue", "억제기", pts[0], 4000, 0, 0))
		structures.append(_struct("tower", "blue", "3차 포탑", pts[1], 4000, 190, 775))
		structures.append(_struct("tower", "blue", "2차 포탑", pts[2], 3600, 170, 775))
		structures.append(_struct("tower", "blue", "1차 포탑", pts[3], 3500, 152, 775))
		structures.append(_struct("tower", "red", "1차 포탑", pts[n - 4], 3500, 152, 775))
		structures.append(_struct("tower", "red", "2차 포탑", pts[n - 3], 3600, 170, 775))
		structures.append(_struct("tower", "red", "3차 포탑", pts[n - 2], 4000, 190, 775))
		structures.append(_struct("inhibitor", "red", "억제기", pts[n - 1], 4000, 0, 0))

static func _struct(kind: String, team: String, uname: String, pos: Vector3, hp: float, ad: float, reach: float) -> Dictionary:
	return {"kind": kind, "team": team, "name": uname, "pos": pos, "hp": hp, "ad": ad, "range": reach}

# ---------- lanes ----------

static func _top() -> Array:
	return [
		Vector3(1650, 0, 3000),
		Vector3(1550, 0, 4300),
		Vector3(1480, 0, 6200),
		Vector3(1500, 0, 8400),
		Vector3(1900, 0, 10600),
		Vector3(3400, 0, 12200),
		Vector3(5600, 0, 13000),
		Vector3(8200, 0, 13300),
		Vector3(10600, 0, 13250),
		Vector3(12200, 0, 13100),
	]

static func _mid() -> Array:
	return [
		Vector3(2700, 0, 2700),
		Vector3(3900, 0, 3900),
		Vector3(5200, 0, 5200),
		Vector3(6800, 0, 6800),
		Vector3(8000, 0, 8000),
		Vector3(9600, 0, 9600),
		Vector3(10900, 0, 10900),
		Vector3(12100, 0, 12100),
	]

static func _bot() -> Array:
	return [
		Vector3(3000, 0, 1650),
		Vector3(4300, 0, 1550),
		Vector3(6200, 0, 1480),
		Vector3(8400, 0, 1500),
		Vector3(10600, 0, 1900),
		Vector3(12200, 0, 3400),
		Vector3(13000, 0, 5600),
		Vector3(13300, 0, 8200),
		Vector3(13250, 0, 10600),
		Vector3(13100, 0, 12200),
	]
