extends RefCounted
## Realistyczne materiały PBR (Poly Haven, CC0) i rekwizyty z plików glTF
## (Poly Haven oraz Quaternius, CC0) z automatycznym dopasowaniem skali.

const Models = preload("res://scripts/models.gd")

static var _pbr := {}
static var _scene := {}
static var _aabb := {}
static var _tex := {}


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## materiał PBR z tekstur assets/tex/<name>_{diff,nor,rough}.jpg; mapowanie trójpłaszczyznowe w przestrzeni świata
static func pbr(name: String, scale := 0.5, tint := Color.WHITE, triplanar := true, rough_mul := 1.0) -> StandardMaterial3D:
	var key := "%s|%.3f|%s|%s|%.2f" % [name, scale, tint.to_html(), triplanar, rough_mul]
	if _pbr.has(key):
		return _pbr[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("res://assets/tex/%s_diff.jpg" % name)
	m.albedo_color = tint
	var n := tex("res://assets/tex/%s_nor.jpg" % name)
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
	var r := tex("res://assets/tex/%s_rough.jpg" % name)
	if r != null:
		m.roughness_texture = r
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = rough_mul
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3(scale, scale, scale)
	_pbr[key] = m
	return m


static func _path(name: String) -> String:
	var a := "res://assets/props/%s/%s.gltf" % [name, name]
	if ResourceLoader.exists(a):
		return a
	var n := "res://assets/nature/%s.gltf" % name
	if ResourceLoader.exists(n):
		return n
	return "res://assets/props/%s.gltf" % name


static func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(t * (n as MeshInstance3D).mesh.get_aabb())
	for c in n.get_children():
		_collect(c, t, out)


static func exists(name: String) -> bool:
	return ResourceLoader.exists(_path(name))


## Rekwizyt ustawiony podstawą na (0,0,0). height > 0 skaluje model do zadanej wysokości,
## fit > 0 skaluje do największego wymiaru poziomego.
## modele, które w pliku „stoją” na sztorc, a w świecie mają leżeć (opona, felga); nazwa z „^” na końcu = zostaw na stojąco
const LAID := ["old_tyre", "rusted_wheel_rim_01"]

static func make(name: String, height := 0.0, fit := 0.0, shadows := true) -> Node3D:
	var lay := name in LAID
	if name.ends_with("^"):
		name = name.trim_suffix("^")
	var path := _path(name)
	if not _scene.has(path):
		_scene[path] = load(path) if ResourceLoader.exists(path) else null
	var root := Node3D.new()
	var ps: PackedScene = _scene[path]
	if ps == null:
		Models.box(root, Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), Models.mat("7a7a7a", 0.9))
		root.set_meta("size", Vector3(0.5, 0.5, 0.5))
		return root
	var inst: Node3D = ps.instantiate()
	if lay:
		inst.rotation.x = -PI / 2.0
	var akey := path + ("|lay" if lay else "")
	if not _aabb.has(akey):
		var boxes: Array = []
		_collect(inst, Transform3D.IDENTITY, boxes)
		var bb := AABB()
		for i in range(boxes.size()):
			bb = boxes[i] if i == 0 else bb.merge(boxes[i])
		_aabb[akey] = bb
	var ab: AABB = _aabb[akey]
	var s := 1.0
	if height > 0.0 and ab.size.y > 0.0001:
		s = height / ab.size.y
	elif fit > 0.0:
		s = fit / maxf(0.0001, maxf(ab.size.x, ab.size.z))
	inst.scale = Vector3(s, s, s) * inst.scale
	inst.position = -Vector3(ab.position.x + ab.size.x * 0.5, ab.position.y, ab.position.z + ab.size.z * 0.5) * s
	root.add_child(inst)
	root.set_meta("size", ab.size * s)
	if not shadows:
		_no_shadow(inst)
	return root


static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


## mocniejsze upraszczanie siatki z odległością (drzewa mają po kilka tysięcy trójkątów)
static func set_lod(n: Node, bias: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).lod_bias = bias
	for c in n.get_children():
		set_lod(c, bias)


static func set_range(n: Node, dist: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visibility_range_end = dist
		(n as GeometryInstance3D).visibility_range_end_margin = 6.0
		(n as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for c in n.get_children():
		set_range(c, dist)


# ---------------------------------------------------------------- zieleń (Quaternius „Stylized Nature MegaKit”, CC0)
static var _leaf_mat := {}

static var _bark_mat: StandardMaterial3D = null

static func _first_mesh_of(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _first_mesh_of(c)
		if r != null:
			return r
	return null


## realistyczna kora (Poly Haven) zamiast malowanej tekstury z paczki drzew
static func bark_material() -> StandardMaterial3D:
	if _bark_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex("res://assets/tex/bark_willow_02_diff.jpg")
		m.albedo_color = Color(0.62, 0.58, 0.54)
		m.normal_enabled = true
		m.normal_texture = tex("res://assets/tex/bark_willow_02_nor.jpg")
		m.normal_scale = 1.4
		m.roughness_texture = tex("res://assets/tex/bark_willow_02_rough.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.6, 0.35, 0.6)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_bark_mat = m
	return _bark_mat


const SH_GRASS := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float tall = 1.0;
uniform float far0 = 24.0;
uniform float far1 = 40.0;
varying float hh;
varying float tone;
void vertex() {
	hh = clamp(VERTEX.y / tall, 0.0, 1.0);
	vec3 o = MODEL_MATRIX[3].xyz;
	tone = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float sway = sin(TIME * 1.5 + o.x * 0.9 + o.z * 1.3) + sin(TIME * 2.7 + o.z * 0.6) * 0.5;
	VERTEX.x += sway * 0.04 * hh * hh * tall;
	// kępy płynnie maleją z odległością, zamiast znikać skokowo
	float dcam = distance(CAMERA_POSITION_WORLD, o);
	VERTEX *= 1.0 - smoothstep(far0, far1, dcam);
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	vec4 c = texture(tex, UV);
	ALPHA = texture(tex, UV, -1.0).a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	vec3 col = c.rgb * mix(0.55, 1.0, hh) * mix(vec3(0.82, 0.86, 0.7), vec3(1.05, 0.98, 0.78), tone);
	ALBEDO = col * 0.8;
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	BACKLIGHT = col * 0.25;
}
"""


## kępa trawy: trzy skrzyżowane karty z teksturą źdźbeł (szerokość i wysokość 1 — skaluje się przy rozstawianiu)
static var _tuft: ArrayMesh = null

static func grass_mesh() -> ArrayMesh:
	if _tuft != null:
		return _tuft
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for k in range(3):
		var a := PI * k / 3.0 + 0.3
		var d := Vector3(cos(a), 0.0, sin(a)) * 0.5
		var i0 := verts.size()
		for p in [[-1.0, 0.0], [1.0, 0.0], [1.0, 1.0], [-1.0, 1.0]]:
			verts.append(d * float(p[0]) + Vector3(0, float(p[1]), 0))
			norms.append(Vector3.UP)
			uvs.append(Vector2(float(p[0]) * 0.5 + 0.5, 1.0 - float(p[1])))
		for t in [0, 1, 2, 0, 2, 3]:
			idx.append(i0 + t)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	_tuft = ArrayMesh.new()
	_tuft.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _tuft


static var _grass_mats := {}

## materiał kępy trawy; `seeds` = wysoka trawa z kłosami
static func grass_material(tall: float, seeds := false) -> Material:
	var key := "%.2f|%s" % [tall, seeds]
	if _grass_mats.has(key):
		return _grass_mats[key]
	var sh := Shader.new()
	sh.code = SH_GRASS
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tall", tall)
	m.set_shader_parameter("tex", tex("res://assets/nature/%s.png" % ("gen_grass_b" if seeds else "gen_grass_a")))
	_grass_mats[key] = m
	return m


## Liście: karty z kępami drobnych liści (tekstury z tools/make_foliage.py). Shader pilnuje, żeby korona
## nie „łysiała” z odległości, podświetla liście pod słońce, przyciemnia środek korony i kołysze nią na wietrze.
const SH_LEAF := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float cutoff = 0.4;
uniform float crown_y = 4.0;
instance uniform vec3 tint : source_color = vec3(1.0);
varying vec3 opos;
void vertex() {
	opos = VERTEX;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = clamp(VERTEX.y * 0.12, 0.0, 1.0);
	float sway = sin(TIME * 1.1 + wp.x * 0.5 + wp.z * 0.7) * 0.6 + sin(TIME * 2.6 + wp.x * 1.9 + wp.y * 1.3) * 0.25;
	VERTEX.x += sway * 0.05 * k;
	VERTEX.z += cos(TIME * 0.9 + wp.z * 0.6) * 0.03 * k;
	// „kuliste” normalne: korona łapie światło jak bryła, a nie jak stos kartek
	vec3 from_c = normalize(VERTEX - vec3(0.0, crown_y, 0.0));
	NORMAL = normalize(mix(NORMAL, from_c, 0.8));
}
void fragment() {
	vec4 c = texture(tex, UV);
	// przezroczystość z ostrzejszego poziomu mipmapy — z daleka liście nie znikają
	float a = texture(tex, UV, -1.2).a;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	float inner = smoothstep(0.2, 2.4, length(opos - vec3(0.0, crown_y, 0.0)));
	vec3 col = c.rgb * tint * mix(0.5, 1.08, inner);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.6;
}
"""

static var _leaf_sh: Shader = null

static func leaf_material(tex_name: String, crown_y := 4.0) -> ShaderMaterial:
	var key := "%s|%.1f" % [tex_name, crown_y]
	if _leaf_mat.has(key):
		return _leaf_mat[key]
	if _leaf_sh == null:
		_leaf_sh = Shader.new()
		_leaf_sh.code = SH_LEAF
	var m := ShaderMaterial.new()
	m.shader = _leaf_sh
	m.set_shader_parameter("tex", tex("res://assets/nature/%s.png" % tex_name))
	m.set_shader_parameter("crown_y", crown_y)
	_leaf_mat[key] = m
	return m


## podmienia materiały drzewa: kora realistyczna, liście z wybranej tekstury i w wybranym odcieniu
static func _tint_leaves(n: Node, tint: Color, leaf_tex := "gen_leaves_autumn") -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var top := mi.mesh.get_aabb().end.y
		for i in range(mi.mesh.get_surface_count()):
			var m: Material = mi.mesh.surface_get_material(i)
			if m != null and String(m.resource_name).contains("Bark"):
				mi.set_surface_override_material(i, bark_material())
				continue
			if m is BaseMaterial3D and (String(m.resource_name).contains("Leaves") or String(m.resource_name).contains("Grass")):
				mi.set_surface_override_material(i, leaf_material(leaf_tex, snappedf(top * 0.66, 0.5)))
				mi.set_instance_shader_parameter("tint", tint)
	for c in n.get_children():
		_tint_leaves(c, tint, leaf_tex)


## Cień drzewa z osobnej, rzadszej siatki. Korona to setki nakładających się kart z wycinaną
## przezroczystością (w modelu ~1000 m² kart w koronie o średnicy 4 m); rysowanie ich wszystkich
## do mapy cieni kosztowało kilka milisekund na klatkę. Co któraś karta daje taki sam, gęsty cień.
static var _shadow_mesh := {}
static var shadow_proxy_on := true   # wyłączane tylko w testach porównawczych

static func _bark_lod(mesh: Mesh, surf: int, max_tris: int, full: PackedInt32Array) -> PackedInt32Array:
	if int(full.size() / 3.0) <= max_tris:
		return full
	var d: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), surf)
	var wide := int(d.get("vertex_count", 0)) > 65536
	for l in d.get("lods", []):
		var raw: PackedByteArray = l.index_data
		var n := int(raw.size() / (4.0 if wide else 2.0))
		if int(n / 3.0) > max_tris:
			continue
		var out := PackedInt32Array()
		out.resize(n)
		for i in range(n):
			out[i] = raw.decode_u32(i * 4) if wide else raw.decode_u16(i * 2)
		return out
	return full


static func _build_shadow_mesh(mi: MeshInstance3D) -> ArrayMesh:
	var src := mi.mesh
	var out := ArrayMesh.new()
	for i in range(src.get_surface_count()):
		var mat: Material = mi.get_surface_override_material(i)
		if mat == null:
			mat = src.surface_get_material(i)
		var full: Array = src.surface_get_arrays(i)
		var idx: PackedInt32Array = full[Mesh.ARRAY_INDEX]
		if mat is ShaderMaterial:
			# liście: karty to osobne czworokąty (po 6 indeksów) — zostaje około 120, wybranych równomiernie
			var quads := int(idx.size() / 6.0)
			var every := maxi(1, int(round(quads / 120.0)))
			var keep := PackedInt32Array()
			for q in range(quads):
				if int((q * 2654435761) >> 7) % every == 0:
					for k in range(6):
						keep.append(idx[q * 6 + k])
			idx = keep
		else:
			idx = _bark_lod(src, i, 1300, idx)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = full[Mesh.ARRAY_VERTEX]
		arr[Mesh.ARRAY_NORMAL] = full[Mesh.ARRAY_NORMAL]
		arr[Mesh.ARRAY_TEX_UV] = full[Mesh.ARRAY_TEX_UV]
		arr[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


static func _shadow_proxy(n: Node) -> void:
	var mi := _first_mesh_of(n)
	if mi == null or mi.mesh == null or not shadow_proxy_on:
		return
	var key := "%s|%d" % [mi.mesh.resource_path, mi.get_surface_override_material(mi.mesh.get_surface_count() - 1).get_instance_id() if mi.get_surface_override_material(mi.mesh.get_surface_count() - 1) != null else 0]
	if not _shadow_mesh.has(key):
		_shadow_mesh[key] = _build_shadow_mesh(mi)
	var px := MeshInstance3D.new()
	px.name = "cien"
	px.mesh = _shadow_mesh[key]
	px.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mi.add_child(px)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## drzewo: `leaves` = szansa na liście (reszta to gołe, jesienne drzewa)
static func tree(seed_v: int, s := 1.0, leaves := 0.5) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var bare := rng.randf() > leaves
	var n: Node3D
	if bare:
		n = make("deadtree_%d" % rng.randi_range(1, 5), rng.randf_range(6.5, 9.5) * s)
		_tint_leaves(n, Color.WHITE)
	else:
		n = make("commontree_%d" % rng.randi_range(1, 5), rng.randf_range(6.0, 9.0) * s)
		# późna jesień: złoto, rdza, trochę zieleni, czasem prawie gołe gałęzie
		var r := rng.randf()
		var tx := "gen_leaves_autumn" if r < 0.45 else ("gen_leaves_rust" if r < 0.7 else ("gen_leaves_green" if r < 0.88 else "gen_leaves_sparse"))
		var k := rng.randf_range(0.82, 1.1)
		_tint_leaves(n, Color(k, k * rng.randf_range(0.9, 1.0), k * rng.randf_range(0.8, 1.0)), tx)
		_shadow_proxy(n)
	n.rotation.y = rng.randf() * TAU
	set_range(n, 170.0)
	set_lod(n, 0.45)
	return n


static func big_tree(seed_v: int, h := 13.0) -> Node3D:
	var n := make("twistedtree_%d" % (1 + seed_v % 2), h)
	_tint_leaves(n, Color(0.95, 0.9, 0.8), "gen_leaves_autumn" if seed_v % 3 != 0 else "gen_leaves_rust")
	_shadow_proxy(n)
	set_range(n, 200.0)
	set_lod(n, 0.5)
	return n


static func bush(seed_v: int, s := 1.0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := make("bush_common", rng.randf_range(1.0, 1.5) * s, 0.0, false)
	var k := rng.randf_range(0.7, 1.0)
	_tint_leaves(n, Color(k, k, k * 0.9), ["gen_leaves_green", "gen_leaves_rust", "gen_leaves_green"][rng.randi_range(0, 2)])
	n.rotation.y = rng.randf() * TAU
	set_range(n, 80.0)
	return n


## kępa chwastów / wysokiej trawy z kłosami (te same karty co trawa, tylko wyższe)
static func weeds(seed_v: int, s := 1.0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = grass_mesh()
	mi.material_override = grass_material(1.0, rng.randf() < 0.6)
	var h := rng.randf_range(0.5, 0.95) * s
	mi.scale = Vector3(h * rng.randf_range(0.9, 1.3), h, h * rng.randf_range(0.9, 1.3))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	n.rotation.y = rng.randf() * TAU
	set_range(n, 45.0)
	return n


# ---------------------------------------------------------------- ogień
static var _fire_tex: GradientTexture2D = null

static func _soft_tex() -> GradientTexture2D:
	if _fire_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_fire_tex = GradientTexture2D.new()
		_fire_tex.gradient = g
		_fire_tex.fill = GradientTexture2D.FILL_RADIAL
		_fire_tex.fill_from = Vector2(0.5, 0.5)
		_fire_tex.fill_to = Vector2(0.5, 0.0)
		_fire_tex.width = 64
		_fire_tex.height = 64
	return _fire_tex


static func _particles(amount: int, life: float, size: float, additive: bool, ramp: Array, vel: Vector2, spread_r: float, grow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 7, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = spread_r
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 14.0
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = Vector3(0.15, 0.6, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.4 if grow else 1.0))
	sc.add_point(Vector2(1.0, 1.8 if grow else 0.15))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	gr.colors = PackedColorArray(ramp)
	var grt := GradientTexture1D.new()
	grt.gradient = gr
	pm.color_ramp = grt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## płonąca beczka: ogień, dym i migoczące światło (światło trafia do listy `lights`)
static func fire_barrel(lights: Array) -> Node3D:
	var g := Node3D.new()
	g.add_child(make("barrel_01", 0.9))
	var fire := _particles(26, 0.7, 0.42, true, [Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.7, 0.2, 0.9), Color(1.0, 0.3, 0.05, 0.6), Color(0.4, 0.05, 0.0, 0.0)], Vector2(0.9, 1.7), 0.14, false)
	fire.position = Vector3(0, 0.9, 0)
	g.add_child(fire)
	var smoke := _particles(14, 3.2, 0.7, false, [Color(0.1, 0.1, 0.1, 0.0), Color(0.12, 0.12, 0.12, 0.35), Color(0.2, 0.2, 0.2, 0.18), Color(0.3, 0.3, 0.3, 0.0)], Vector2(0.7, 1.2), 0.1, true)
	smoke.position = Vector3(0, 1.4, 0)
	g.add_child(smoke)
	var li := OmniLight3D.new()
	li.position = Vector3(0, 1.3, 0)
	li.light_color = Color(1.0, 0.55, 0.2)
	li.light_energy = 2.4
	li.omni_range = 8.0
	li.omni_attenuation = 1.4
	li.shadow_enabled = true
	li.distance_fade_enabled = true
	li.distance_fade_begin = 40.0
	li.distance_fade_shadow = 18.0
	li.set_meta("fire", lights.size() * 1.7)
	g.add_child(li)
	lights.append(li)
	var glow := Models.cyl(g, 0.24, 0.24, 0.03, Vector3(0, 0.86, 0), Models.mat("ff7a20", 0.5, 0.0, 6.0), Vector3.ZERO, 10)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


## trzepak — obowiązkowy element polskiego podwórka
static func trzepak() -> Node3D:
	var g := Node3D.new()
	var m := Models.mat("3d5a48", 0.6, 0.5)
	for x in [-1.2, 1.2]:
		Models.cyl(g, 0.035, 0.035, 2.0, Vector3(x, 1.0, 0), m, Vector3.ZERO, 8)
	Models.cyl(g, 0.03, 0.03, 2.4, Vector3(0, 2.0, 0), m, Vector3(0, 0, PI / 2.0), 8)
	Models.cyl(g, 0.03, 0.03, 2.4, Vector3(0, 1.35, 0), m, Vector3(0, 0, PI / 2.0), 8)
	return g


static func swing() -> Node3D:
	var g := Node3D.new()
	var m := Models.mat("7a2f24", 0.6, 0.5)
	for x in [-1.5, 1.5]:
		for z in [-0.7, 0.7]:
			Models.cyl(g, 0.04, 0.04, 2.5, Vector3(x, 1.2, z * 0.5), m, Vector3(z * 0.42, 0, 0), 8)
	Models.cyl(g, 0.04, 0.04, 3.1, Vector3(0, 2.36, 0), m, Vector3(0, 0, PI / 2.0), 8)
	var ch := Models.mat("1c1c1f", 0.5, 0.7)
	for sx in [-0.7, 0.7]:
		for d in [-0.2, 0.2]:
			Models.cyl(g, 0.008, 0.008, 1.75, Vector3(sx + d, 1.48, 0), ch, Vector3.ZERO, 4)
		Models.box(g, Vector3(0.48, 0.04, 0.2), Vector3(sx, 0.6, 0), Models.mat("2a2420", 0.9))
	return g


static func slide() -> Node3D:
	var g := Node3D.new()
	var m := Models.mat("5a6a7a", 0.5, 0.6)
	Models.box(g, Vector3(0.9, 0.06, 0.9), Vector3(0, 1.6, 0), m)
	for x in [-0.4, 0.4]:
		for z in [-0.4, 0.4]:
			Models.cyl(g, 0.035, 0.035, 1.6, Vector3(x, 0.8, z), m, Vector3.ZERO, 6)
	Models.box(g, Vector3(0.6, 0.04, 2.6), Vector3(0, 0.85, 1.55), Models.mat("9aa3ab", 0.3, 0.8), Vector3(0.62, 0, 0))
	for k in range(5):
		Models.cyl(g, 0.02, 0.02, 0.6, Vector3(0, 0.3 + k * 0.3, -0.5 - k * 0.08), m, Vector3(0, 0, PI / 2.0), 5)
	return g


## altanka śmietnikowa z kontenerami
static func trash_shed() -> Node3D:
	var g := Node3D.new()
	var wall := pbr("concrete_wall_008", 0.4, Color(0.8, 0.8, 0.78))
	Models.box(g, Vector3(5.0, 1.9, 0.18), Vector3(0, 0.95, -1.6), wall)
	Models.box(g, Vector3(0.18, 1.9, 3.2), Vector3(-2.5, 0.95, 0), wall)
	Models.box(g, Vector3(0.18, 1.9, 3.2), Vector3(2.5, 0.95, 0), wall)
	Models.box(g, Vector3(5.4, 0.08, 3.6), Vector3(0, 2.05, 0), pbr("asbestos_sheet", 0.6))
	var cols := ["2d5a3a", "2f4a6a", "6a5a2a"]
	for k in range(3):
		var c := Node3D.new()
		c.position = Vector3(-1.6 + k * 1.6, 0, -0.5)
		g.add_child(c)
		Models.box(c, Vector3(1.3, 1.05, 0.95), Vector3(0, 0.68, 0), Models.mat(cols[k], 0.65, 0.2))
		Models.box(c, Vector3(1.36, 0.07, 1.0), Vector3(0, 1.24, 0.0), Models.mat("1c1f22", 0.6, 0.2), Vector3(0.06 * (k - 1), 0, 0))
		for wx in [-0.5, 0.5]:
			Models.cyl(c, 0.08, 0.08, 0.06, Vector3(wx, 0.08, 0.38), Models.mat("111111", 0.9), Vector3(0, 0, PI / 2.0), 8)
	return g


static func bus_stop() -> Node3D:
	var g := Node3D.new()
	var fr := Models.mat("3a4048", 0.5, 0.6)
	for x in [-1.9, 1.9]:
		Models.box(g, Vector3(0.08, 2.4, 0.08), Vector3(x, 1.2, -0.7), fr)
		Models.box(g, Vector3(0.08, 2.4, 0.08), Vector3(x, 1.2, 0.5), fr)
	Models.box(g, Vector3(4.2, 0.08, 1.7), Vector3(0, 2.44, -0.1), Models.mat("2a2f36", 0.6, 0.4))
	Models.box(g, Vector3(3.8, 1.9, 0.03), Vector3(0, 1.3, -0.72), Models.mat("8fa3b0", 0.1, 0.2, 0.0, 0.35))
	Models.box(g, Vector3(0.03, 1.9, 1.2), Vector3(-1.92, 1.3, -0.1), Models.mat("8fa3b0", 0.1, 0.2, 0.0, 0.35))
	Models.box(g, Vector3(3.0, 0.06, 0.4), Vector3(0, 0.5, -0.45), Models.mat("6b4a2e", 0.8))
	for x in [-1.3, 1.3]:
		Models.box(g, Vector3(0.06, 0.5, 0.06), Vector3(x, 0.25, -0.45), fr)
	Models.cyl(g, 0.03, 0.03, 2.8, Vector3(2.6, 1.4, 0.4), fr, Vector3.ZERO, 6)
	Models.box(g, Vector3(0.5, 0.5, 0.04), Vector3(2.6, 2.6, 0.4), Models.mat("c9a020", 0.5))
	return g


## sam płat ogrodzenia (bez słupków), dolna krawędź na wysokości 0
static func fence_panel(length: float, h: float, kind := "mesh") -> Node3D:
	var g := Node3D.new()
	if kind == "mesh":
		var p := Models.box(g, Vector3(length, h, 0.012), Vector3(0, h * 0.5, 0), mesh_fence_material(), Vector3.ZERO, false)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		Models.box(g, Vector3(length, h, 0.06), Vector3(0, h * 0.5, 0), pbr("rusty_corrugated_iron", 0.5))
	return g


static var _mesh_fence_mat: StandardMaterial3D = null

static func mesh_fence_material() -> StandardMaterial3D:
	if _mesh_fence_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.48, 0.45, 0.42)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.6
		m.metallic = 0.4
		_mesh_fence_mat = m
	return _mesh_fence_mat


static func fence(length: float, h := 1.6, kind := "mesh") -> Node3D:
	var g := Node3D.new()
	var post := Models.mat("4a4f4a", 0.6, 0.5)
	var n: int = max(1, int(round(length / 2.5)))
	for i in range(n + 1):
		Models.cyl(g, 0.03, 0.03, h, Vector3(-length * 0.5 + i * length / n, h * 0.5, 0), post, Vector3.ZERO, 5)
	if kind == "mesh":
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.48, 0.45, 0.42)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.6
		m.metallic = 0.4
		var p := Models.box(g, Vector3(length, h - 0.1, 0.01), Vector3(0, h * 0.5, 0), m, Vector3.ZERO, false)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		Models.box(g, Vector3(length, h - 0.15, 0.06), Vector3(0, h * 0.5 + 0.05, 0), pbr("rusty_corrugated_iron", 0.5))
	Models.cyl(g, 0.02, 0.02, length, Vector3(0, h, 0), post, Vector3(0, 0, PI / 2.0), 5)
	return g
