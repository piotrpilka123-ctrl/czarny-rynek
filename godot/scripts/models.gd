extends RefCounted
## Proceduralne modele: postacie ze stawami, samochody, drzewa, rekwizyty.
## Użycie: const Models = preload("res://scripts/models.gd")

const SKIN := ["f1c9a5", "e6b890", "d09a6e", "a8734b", "7d5236", "f6d8bf"]
const HAIRC := ["17130f", "33241a", "5e4126", "9a7040", "c8ae82", "7d7d7d", "8a3324", "222831"]
const TOPC := ["2f4a6d", "6d2f2f", "2f6d45", "3d3d42", "a8a39a", "7a5c2e", "4b3a6d", "8a2d52", "1f6f78", "c7b08a", "20242b", "b0492c", "d8d8d8"]
const BOTC := ["232a36", "2e3a52", "3b3630", "1b1b1e", "4a4f57", "5b4a3a", "283b2e"]
const SHOEC := ["151515", "3a2a1e", "e8e8e8", "5a1f1f", "22324a"]
const CARCOLS := ["8a1c1c", "1c3f8a", "d9dcdf", "15171a", "b08a1e", "1e6b3a", "5a6068", "5a2d8a", "9aa3ab", "6b1f2a", "28424f"]

static var _mats := {}
static var _meshes := {}


static func col(c) -> Color:
	if c is Color:
		return c
	return Color.html("#" + str(c).lstrip("#"))


## Żadnej idealnej czerni na modelach: najciemniejszy dozwolony kolor to ciemny grafit. Kolor ciemniejszy od progu
## jest podnoszony o stałą wartość (odcień zostaje), jaśniejszych funkcja nie rusza.
const BLACK_FLOOR := 0.105

static func no_vanta(c: Color) -> Color:
	var m := maxf(c.r, maxf(c.g, c.b))
	if m >= BLACK_FLOOR:
		return c
	var add := BLACK_FLOOR - m
	return Color(c.r + add, c.g + add, c.b + add, c.a)


## podnosi czerń we wszystkich nieteksturowanych materiałach modelu wczytanego z pliku (raz na plik)
static func lift_blacks(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for i in range(mesh.get_surface_count()):
			var m := mesh.surface_get_material(i)
			if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture == null and not (m as BaseMaterial3D).emission_enabled:
				(m as BaseMaterial3D).albedo_color = no_vanta((m as BaseMaterial3D).albedo_color)
	for ch in n.get_children():
		lift_blacks(ch)


## Ciemność w głębi otworu (tunel, szczelina, wnętrze za szybą): to nie „czarny przedmiot”, tylko brak światła,
## więc tu — i tylko tu — zostaje prawie czerń.
static var _void: StandardMaterial3D = null

static func void_mat() -> StandardMaterial3D:
	if _void == null:
		_void = StandardMaterial3D.new()
		_void.albedo_color = Color(0.02, 0.02, 0.022)
		_void.roughness = 1.0
	return _void


## materiał PBR z pamięcią podręczną
static func mat(c, rough := 0.8, metal := 0.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var cc := col(c)
	if emit <= 0.0:
		cc = no_vanta(cc)
	var key := "%s|%.2f|%.2f|%.2f|%.2f" % [cc.to_html(), rough, metal, emit, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cc.r, cc.g, cc.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = cc
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func _mesh(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("b%.3f_%.3f_%.3f" % [size.x, size.y, size.z], func():
		var b := BoxMesh.new()
		b.size = size
		return b)
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, rt: float, rb: float, h: float, pos: Vector3, material: Material, rot := Vector3.ZERO, seg := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("c%.3f_%.3f_%.3f_%d" % [rt, rb, h, seg], func():
		var c := CylinderMesh.new()
		c.top_radius = rt
		c.bottom_radius = rb
		c.height = h
		c.radial_segments = seg
		c.rings = 1
		return c)
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func capsule(parent: Node, r: float, h: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("k%.3f_%.3f" % [r, h], func():
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = h
		c.radial_segments = 12
		c.rings = 4
		return c)
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, r: float, pos: Vector3, material: Material, scl := Vector3.ONE, hemi := false, seg := 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("s%.3f_%s_%d" % [r, hemi, seg], func():
		var s := SphereMesh.new()
		s.radius = r
		s.height = r if hemi else r * 2.0
		s.is_hemisphere = hemi
		s.radial_segments = seg
		s.rings = max(4, int(seg / 2.0))
		return s)
	mi.material_override = material
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func pivot(parent: Node, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func label(text: String, color := Color(1, 0.9, 0.55), size := 44) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 10
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	l.fixed_size = false
	return l


# ---------------------------------------------------------------- POSTAĆ
## o: {female, skin, hair, top, bottom, shoes, kind, bald, cap, hat, beard, glasses, build, height, bag, earpiece}
## kind: tshirt | hoodie | jacket | suit | coat | uniform | dress
static func person(o := {}) -> Dictionary:
	var female: bool = o.get("female", randf() < 0.45)
	var skin_m := mat(o.get("skin", SKIN.pick_random()), 0.75)
	var hair_m := mat(o.get("hair", HAIRC.pick_random()), 0.9)
	var kind: String = o.get("kind", ["tshirt", "hoodie", "jacket", "tshirt", "jacket", "coat"].pick_random())
	var top_c := col(o.get("top", TOPC.pick_random()))
	var top_m := mat(top_c, 0.9)
	var bot_m := mat(o.get("bottom", BOTC.pick_random()), 0.9)
	var shoe_m := mat(o.get("shoes", SHOEC.pick_random()), 0.7)
	var dark_m := mat("15151a", 0.6)
	var build: float = o.get("build", randf_range(0.94, 1.12))
	var height: float = o.get("height", randf_range(1.6, 1.74) if female else randf_range(1.7, 1.88))
	var long_sleeve := kind != "tshirt" and kind != "dress"
	var sleeve_m: Material = top_m
	var fore_m: Material = top_m if long_sleeve else skin_m

	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var s := height / 1.86
	body.scale = Vector3(s * build * 1.12, s, s * build * 1.14)
	var pelvis := pivot(body, Vector3(0, 0.96, 0))

	# miednica
	var hips := capsule(pelvis, 0.155, 0.36, Vector3(0, -0.02, 0), mat(top_c, 0.9) if kind == "dress" else bot_m, Vector3(0, 0, PI / 2))
	hips.scale = Vector3(1, 0.62, 0.78)
	if kind == "dress":
		cyl(pelvis, 0.17, 0.27, 0.52, Vector3(0, -0.26, 0), top_m, Vector3.ZERO, 14).scale = Vector3(1, 1, 0.82)
	if kind == "coat":
		cyl(pelvis, 0.185, 0.21, 0.5, Vector3(0, -0.22, 0), top_m, Vector3.ZERO, 14).scale = Vector3(1, 1, 0.76)

	# nogi
	var legs := []
	var leg_skin := kind == "dress"
	for sd in [-1.0, 1.0]:
		var hip := pivot(pelvis, Vector3(sd * 0.088, -0.04, 0))
		capsule(hip, 0.086, 0.5, Vector3(0, -0.215, 0), skin_m if leg_skin else bot_m)
		var knee := pivot(hip, Vector3(0, -0.43, 0))
		capsule(knee, 0.062, 0.48, Vector3(0, -0.21, 0), skin_m if leg_skin else bot_m)
		box(knee, Vector3(0.1, 0.08, 0.25), Vector3(0, -0.452, 0.045), shoe_m)
		sphere(knee, 0.052, Vector3(0, -0.452, 0.165), shoe_m, Vector3(1, 0.78, 1), false, 8)
		box(knee, Vector3(0.105, 0.022, 0.265), Vector3(0, -0.485, 0.047), dark_m)
		legs.append({"hip": hip, "knee": knee})

	# tułów
	var spine := pivot(pelvis, Vector3(0, 0.06, 0))
	var torso := capsule(spine, 0.17 if female else 0.185, 0.62, Vector3(0, 0.27, 0), top_m)
	torso.scale = Vector3(1.12, 1.0, 0.7)
	cyl(spine, 0.05, 0.055, 0.1, Vector3(0, 0.575, 0), skin_m, Vector3.ZERO, 10)
	cyl(spine, 0.172, 0.172, 0.035, Vector3(0, 0.03, 0), dark_m, Vector3.ZERO, 14).scale = Vector3(1.1, 1, 0.72)
	if female:
		for sx in [-0.07, 0.07]:
			sphere(spine, 0.068, Vector3(sx, 0.37, 0.085), top_m, Vector3.ONE, false, 10)
	if kind == "jacket" or kind == "suit" or kind == "coat":
		var inner := mat(o.get("top2", "e8e8e8" if kind == "suit" else ["d9c9a8", "222222", "8a8f98", "e8e8e8"].pick_random()), 0.9)
		box(spine, Vector3(0.09, 0.4, 0.02), Vector3(0, 0.3, 0.125), inner)
		if kind == "suit":
			box(spine, Vector3(0.034, 0.27, 0.014), Vector3(0, 0.33, 0.138), mat(o.get("tie", "7a1f1f"), 0.7))
	if kind == "hoodie":
		sphere(spine, 0.11, Vector3(0, 0.5, -0.1), top_m, Vector3(1, 0.75, 1), false, 10)
		box(spine, Vector3(0.22, 0.09, 0.014), Vector3(0, 0.14, 0.128), mat(top_c.darkened(0.12), 0.9))
	if kind == "uniform":
		var vest := capsule(spine, 0.2, 0.5, Vector3(0, 0.3, 0), mat("16243f", 0.85))
		vest.scale = Vector3(1.14, 0.9, 0.74)
		box(spine, Vector3(0.32, 0.05, 0.014), Vector3(0, 0.36, 0.148), mat("d7dde6", 0.5, 0.0, 0.3))
		box(spine, Vector3(0.32, 0.05, 0.014), Vector3(0, 0.36, -0.148), mat("d7dde6", 0.5, 0.0, 0.3))
		box(spine, Vector3(0.05, 0.05, 0.014), Vector3(-0.1, 0.44, 0.15), mat("f2c21a", 0.4, 0.6))
		box(spine, Vector3(0.06, 0.1, 0.045), Vector3(0.15, 0.46, 0.11), dark_m)
		box(spine, Vector3(0.09, 0.11, 0.05), Vector3(0.2, 0.0, 0.02), dark_m)
	if o.has("bag"):
		var bag_m := mat(o.bag, 0.85)
		box(spine, Vector3(0.28, 0.32, 0.13), Vector3(0, 0.3, -0.19), bag_m)
		for sx in [-0.12, 0.12]:
			box(spine, Vector3(0.03, 0.42, 0.02), Vector3(sx, 0.34, 0.118), bag_m)

	# ręce
	var arms := []
	for sd in [-1.0, 1.0]:
		var sh := pivot(spine, Vector3(sd * 0.232, 0.47, 0))
		sh.rotation.z = sd * 0.05
		sphere(sh, 0.076, Vector3.ZERO, sleeve_m, Vector3.ONE, false, 10)
		capsule(sh, 0.054, 0.34, Vector3(0, -0.145, 0), sleeve_m)
		var el := pivot(sh, Vector3(0, -0.29, 0))
		capsule(el, 0.044, 0.3, Vector3(0, -0.13, 0), fore_m)
		sphere(el, 0.046, Vector3(0, -0.29, 0), skin_m, Vector3(0.8, 1.3, 1), false, 8)
		arms.append({"sh": sh, "el": el})

	# głowa
	var head := pivot(spine, Vector3(0, 0.62, 0))
	sphere(head, 0.113, Vector3(0, 0.11, 0), skin_m, Vector3(1, 1.18, 1.05), false, 18)
	for sx in [-1.0, 1.0]:
		sphere(head, 0.026, Vector3(sx * 0.108, 0.105, 0), skin_m, Vector3(0.5, 1.3, 1), false, 8)
		sphere(head, 0.021, Vector3(sx * 0.042, 0.128, 0.098), mat("f4f4f0", 0.3), Vector3(1.15, 0.8, 0.6), false, 8)
		sphere(head, 0.011, Vector3(sx * 0.042, 0.128, 0.111), mat("1a120c", 0.2), Vector3.ONE, false, 6)
		box(head, Vector3(0.042, 0.009, 0.01), Vector3(sx * 0.043, 0.154, 0.108), hair_m, Vector3(0, 0, -sx * (0.25 if o.get("stern", false) else 0.08)))
	sphere(head, 0.02, Vector3(0, 0.095, 0.118), skin_m, Vector3(1, 1.25, 1), false, 8)
	box(head, Vector3(0.05, 0.008, 0.01), Vector3(0, 0.05, 0.111), mat("7a3530", 0.6))
	var bald: bool = o.get("bald", (not female) and randf() < 0.12)
	if not bald:
		var cap_h := sphere(head, 0.121, Vector3(0, 0.118, -0.014), hair_m, Vector3(1.04, 1.14, 1.09), true, 16)
		cap_h.rotation.x = -0.38
		if female:
			var back := capsule(head, 0.11, 0.42, Vector3(0, 0.02, -0.07), hair_m)
			back.scale = Vector3(1.05, 1.0, 0.6)
	if o.get("beard", false):
		sphere(head, 0.1, Vector3(0, 0.045, 0.03), hair_m, Vector3(1.0, 0.75, 0.95), false, 10)
	if o.get("glasses", false):
		for sx in [-0.045, 0.045]:
			box(head, Vector3(0.07, 0.04, 0.008), Vector3(sx, 0.128, 0.118), mat("101014", 0.3, 0.0, 0.0, 0.55))
		box(head, Vector3(0.03, 0.008, 0.008), Vector3(0, 0.135, 0.118), dark_m)
	if o.get("cap", false):
		var cm := mat(o.get("cap_color", "20242b"), 0.85)
		cyl(head, 0.119, 0.123, 0.075, Vector3(0, 0.2, 0), cm, Vector3.ZERO, 16)
		box(head, Vector3(0.17, 0.014, 0.13), Vector3(0, 0.175, 0.14), cm)
	if kind == "uniform":
		var pm := mat("101a33", 0.8)
		cyl(head, 0.127, 0.119, 0.06, Vector3(0, 0.2, 0), pm, Vector3.ZERO, 18)
		cyl(head, 0.152, 0.136, 0.03, Vector3(0, 0.243, 0), pm, Vector3.ZERO, 18)
		box(head, Vector3(0.18, 0.012, 0.11), Vector3(0, 0.178, 0.135), dark_m, Vector3(0.15, 0, 0))
		box(head, Vector3(0.04, 0.035, 0.012), Vector3(0, 0.215, 0.124), mat("e9c21a", 0.4, 0.6))
	if o.get("hood", false):
		sphere(head, 0.14, Vector3(0, 0.11, -0.03), top_m, Vector3(1.0, 1.25, 1.05), false, 12)
	if o.get("earpiece", false):
		sphere(head, 0.016, Vector3(0.118, 0.1, 0), mat("e8e8e8", 0.4), Vector3.ONE, false, 6)

	return {"root": root, "body": body, "pelvis": pelvis, "spine": spine, "head": head, "legs": legs, "arms": arms,
		"phase": randf() * TAU, "base_y": 0.96, "height": height, "blend": 0.0, "idle_t": randf() * 10.0}


## animacja szkieletu; pose: "" | phone | talk | handsup | arms | lean | smoke
static func animate(p: Dictionary, dt: float, speed: float, pose := "") -> void:
	p.idle_t += dt
	var L: Array = p.legs
	var A: Array = p.arms
	var moving := speed > 0.05
	if moving:
		p.phase += dt * (2.2 + speed * 1.55)
	var amp: float = min(0.85, 0.22 + speed * 0.115) if moving else 0.0
	p.blend += ((1.0 if moving else 0.0) - p.blend) * min(1.0, dt * 8.0)
	var b: float = p.blend
	var sn := sin(p.phase)
	var cs := cos(p.phase)
	var run := 1.0 if speed > 4.6 else 0.0
	L[0].hip.rotation.x = -sn * amp * b
	L[1].hip.rotation.x = sn * amp * b
	L[0].knee.rotation.x = max(0.0, -cs) * amp * 1.5 * b + 0.04
	L[1].knee.rotation.x = max(0.0, cs) * amp * 1.5 * b + 0.04
	p.pelvis.position.y = p.base_y + absf(cs) * 0.035 * amp * b - 0.012 * b
	p.spine.rotation.y = sn * 0.1 * amp * b
	p.spine.rotation.x = run * 0.14 * b + sin(p.idle_t * 1.4) * 0.008
	p.head.rotation.y = -sn * 0.07 * amp * b
	var a_l: float = sn * amp * 0.8 * b
	var a_r: float = -sn * amp * 0.8 * b
	var e_l: float = -(0.12 + run * 1.1 + max(0.0, sn) * amp * 0.5) * b - 0.06
	var e_r: float = -(0.12 + run * 1.1 + max(0.0, -sn) * amp * 0.5) * b - 0.06
	var z_l := -0.05
	var z_r := 0.05
	var head_x := 0.0
	match pose:
		"phone":
			a_r = -0.95; e_r = -1.95; head_x = 0.28
		"talk":
			a_r = -0.55 + sin(p.idle_t * 3.1) * 0.2; e_r = -1.25 + sin(p.idle_t * 4.3) * 0.25; head_x = sin(p.idle_t * 2.0) * 0.04
		"handsup":
			a_l = -2.9; a_r = -2.9; e_l = -0.25; e_r = -0.25
		"arms":
			a_l = -0.32; a_r = -0.32; e_l = -0.75; e_r = -0.75; z_l = 0.3; z_r = -0.3
		"lean":
			a_l = 0.1; a_r = 0.1; e_l = -0.3; e_r = -0.3
		"smoke":
			var k: float = max(0.0, sin(p.idle_t * 0.7))
			a_r = -0.7 - k * 0.5; e_r = -1.6 - k * 0.5
	p.head.rotation.x = lerpf(p.head.rotation.x, head_x, min(1.0, dt * 5.0))
	A[0].sh.rotation.x = a_l
	A[1].sh.rotation.x = a_r
	A[0].el.rotation.x = e_l
	A[1].el.rotation.x = e_r
	A[0].sh.rotation.z = z_l
	A[1].sh.rotation.z = z_r


# ---------------------------------------------------------------- GEOMETRIA
## zaokrągla narożniki wielokąta
static func rounded(pts: Array, r: float, seg := 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in range(n):
		var p0: Vector2 = pts[(i - 1 + n) % n]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % n]
		var v1 := p0 - p1
		var v2 := p2 - p1
		var rr: float = min(r, min(v1.length(), v2.length()) * 0.45)
		var a := p1 + v1.normalized() * rr
		var c := p1 + v2.normalized() * rr
		for k in range(seg + 1):
			var t := float(k) / seg
			out.append(a.lerp(p1, t).lerp(p1.lerp(c, t), t))
	return out


## wyciąga wielokąt (XY) wzdłuż osi Z na głębokość depth (wyśrodkowany)
static func extrude(poly: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := depth * 0.5
	var tri := Geometry2D.triangulate_polygon(poly)
	for side in [1.0, -1.0]:
		for i in range(0, tri.size(), 3):
			var idx := [tri[i], tri[i + 1], tri[i + 2]] if side > 0 else [tri[i + 2], tri[i + 1], tri[i]]
			for j in idx:
				st.set_uv(poly[j])
				st.add_vertex(Vector3(poly[j].x, poly[j].y, hz * side))
	var n := poly.size()
	for i in range(n):
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var v := [Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3(b.x, b.y, -hz), Vector3(a.x, a.y, -hz)]
		for j in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(0, 0))
			st.add_vertex(v[j])
	# normalne z kolejności wierzchołków; materiał jest dwustronny, więc oświetlenie jest poprawne z obu stron
	st.generate_normals()
	return st.commit()


static func _extruded(parent: Node, key: String, pts: Array, r: float, depth: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(key, func(): return extrude(rounded(pts, r), depth))
	mi.material_override = material
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- SAMOCHODY
const Cars = preload("res://scripts/cars.gd")
const CAR_TYPES := Cars.TYPES


## zwraca Node3D; przód auta = +Z (nadwozia buduje cars.gd)
static func car(type := "", color = null, police := false) -> Node3D:
	return Cars.car(type, color if color != null else CARCOLS.pick_random(), police)


static func _pillar(g: Node, a: Vector2, b: Vector2, z: float, material: Material) -> void:
	var d := b - a
	var mi := box(g, Vector3(d.length(), 0.075, 0.035), Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z), material)
	mi.rotation.z = atan2(d.y, d.x)


# ---------------------------------------------------------------- DRZEWA I REKWIZYTY
static func tree(kind := "oak", s := 1.0) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bark := mat("d9d6cc" if kind == "birch" else "4b3524", 0.95)
	var greens := [mat("2c6332", 0.95), mat("3f7a3a", 0.95), mat("57913f", 0.95)] if kind != "birch" else [mat("6fa544", 0.95), mat("82b450", 0.95), mat("93bd58", 0.95)]
	if kind == "bush":
		for k in range(4):
			sphere(root, rng.randf_range(0.5, 0.8), Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.4, 0.7), rng.randf_range(-0.45, 0.45)), greens[k % 3], Vector3(1, 0.8, 1), false, 8)
	elif kind == "pine":
		cyl(root, 0.12, 0.2, 2.2, Vector3(0, 1.1, 0), bark, Vector3.ZERO, 7)
		for k in range(5):
			cyl(root, 0.02, 1.7 - k * 0.3, 1.5, Vector3(0, 2.0 + k * 0.9, 0), mat("1f4a2c" if k % 2 == 1 else "245533", 0.95), Vector3.ZERO, 9)
	else:
		var th := 4.2 if kind == "birch" else 2.6
		cyl(root, 0.09 if kind == "birch" else 0.2, 0.14 if kind == "birch" else 0.34, th, Vector3(0, th * 0.5, 0), bark, Vector3.ZERO, 8)
		var n := 7 if kind == "birch" else 9
		for k in range(n):
			var a := rng.randf() * TAU
			var d := rng.randf() * (0.9 if kind == "birch" else 1.5)
			var r := rng.randf_range(0.8, 1.3) if kind == "birch" else rng.randf_range(1.15, 1.85)
			sphere(root, r, Vector3(cos(a) * d, th + 0.9 + rng.randf() * 2.0, sin(a) * d), greens[k % 3], Vector3(1, 0.85, 1), false, 8)
	root.scale = Vector3(s, s, s)
	root.rotation.y = rng.randf() * TAU
	return root


static func bench() -> Node3D:
	var g := Node3D.new()
	var wood := mat("7a5330", 0.85)
	var iron := mat("1c1c1f", 0.5, 0.6)
	for k in range(4):
		box(g, Vector3(2.0, 0.04, 0.1), Vector3(0, 0.46, -0.18 + k * 0.12), wood)
	for k in range(3):
		box(g, Vector3(2.0, 0.1, 0.035), Vector3(0, 0.62 + k * 0.13, -0.27 - k * 0.03), wood, Vector3(-0.2, 0, 0))
	for x in [-0.85, 0.85]:
		box(g, Vector3(0.06, 0.46, 0.06), Vector3(x, 0.23, 0.14), iron)
		box(g, Vector3(0.06, 0.95, 0.06), Vector3(x, 0.47, -0.24), iron, Vector3(-0.12, 0, 0))
		box(g, Vector3(0.06, 0.05, 0.5), Vector3(x, 0.43, -0.05), iron)
	return g


static func bin() -> Node3D:
	var g := Node3D.new()
	cyl(g, 0.26, 0.22, 0.75, Vector3(0, 0.43, 0), mat("2f4f3a", 0.6, 0.3), Vector3.ZERO, 14)
	cyl(g, 0.29, 0.29, 0.05, Vector3(0, 0.82, 0), mat("1e2f25", 0.6, 0.3), Vector3.ZERO, 14)
	return g


static func hydrant() -> Node3D:
	var g := Node3D.new()
	var m := mat("b3261e", 0.5, 0.3)
	cyl(g, 0.1, 0.13, 0.55, Vector3(0, 0.28, 0), m, Vector3.ZERO, 10)
	sphere(g, 0.11, Vector3(0, 0.58, 0), m, Vector3.ONE, false, 8)
	cyl(g, 0.05, 0.05, 0.34, Vector3(0, 0.38, 0), mat("8f1d17", 0.5, 0.3), Vector3(0, 0, PI / 2), 8)
	return g


static func bollard() -> Node3D:
	var g := Node3D.new()
	cyl(g, 0.07, 0.08, 0.8, Vector3(0, 0.4, 0), mat("3a3d42", 0.5, 0.5), Vector3.ZERO, 8)
	cyl(g, 0.075, 0.075, 0.08, Vector3(0, 0.68, 0), mat("e3b93a", 0.5), Vector3.ZERO, 8)
	return g


static func dumpster() -> Node3D:
	var g := Node3D.new()
	box(g, Vector3(2.0, 1.1, 1.1), Vector3(0, 0.7, 0), mat("2f5d3a", 0.6, 0.3))
	box(g, Vector3(2.06, 0.08, 1.16), Vector3(0, 1.28, 0), mat("1f3f27", 0.6, 0.3), Vector3(0.08, 0, 0))
	return g


static func planter() -> Node3D:
	var g := Node3D.new()
	box(g, Vector3(1.6, 0.5, 0.6), Vector3(0, 0.25, 0), mat("6b6e75", 0.9))
	box(g, Vector3(1.44, 0.06, 0.44), Vector3(0, 0.5, 0), mat("3a2a1c", 1.0))
	var cols := ["3c8a3f", "4c9a44", "d6456b", "e2b23a", "3c8a3f"]
	for k in range(9):
		sphere(g, 0.14 + (k % 3) * 0.03, Vector3(-0.6 + k * 0.15, 0.62 + (k % 2) * 0.05, ((k * 7) % 5 - 2) * 0.05), mat(cols[k % 5], 0.9), Vector3.ONE, false, 6)
	return g


static func kiosk() -> Node3D:
	var g := Node3D.new()
	box(g, Vector3(2.6, 2.3, 2.0), Vector3(0, 1.15, 0), mat("2f6e5a", 0.7))
	box(g, Vector3(2.9, 0.12, 2.4), Vector3(0, 2.36, 0), mat("1d473a", 0.7))
	box(g, Vector3(2.0, 0.9, 0.05), Vector3(0, 1.5, 1.01), mat("10181c", 0.1, 0.5))
	box(g, Vector3(2.2, 0.06, 0.4), Vector3(0, 1.02, 1.15), mat("c9ced4", 0.4, 0.5))
	var cols := ["c0392b", "2980b9", "f1c40f", "27ae60", "8e44ad"]
	for k in range(5):
		box(g, Vector3(0.3, 0.4, 0.02), Vector3(-0.8 + k * 0.4, 0.6, 1.02), mat(cols[k], 0.8))
	return g
