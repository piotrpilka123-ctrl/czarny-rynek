extends RefCounted
## Detale miasta — to, co odróżnia jeden blok od drugiego: graffiti i plakaty (kalkomanie wtapiające się w mur),
## wejścia do klatek schodowych, rynny, anteny satelitarne, klimatyzatory, kraty w oknach parteru,
## pranie na balkonach, anteny na dachach, słupy ogłoszeniowe.
## Wszystko trzyma się siatki okien z shadera elewacji, więc nic nie ląduje na szybie.

const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")
const Signs = preload("res://scripts/signs.gd")
const Stations = preload("res://scripts/stations.gd")
const Interior = preload("res://scripts/interior.gd")
const GDIR := "res://assets/graffiti/"
const SC := 0.56
const INV := 1.0 / 0.56

static var _meta := {}
static var _by_kind := {}
static var _mm := {}           # nazwa siatki -> Array[Transform3D]
static var _mm_col := {}       # nazwa siatki -> Array[Color]
static var _next := {}


static func _load_meta() -> void:
	if not _meta.is_empty():
		return
	var f := FileAccess.open(GDIR + "graffiti.json", FileAccess.READ)
	if f == null:
		return
	_meta = JSON.parse_string(f.get_as_text())
	f.close()
	for n in _meta:
		var k := String(_meta[n].kind)
		if not _by_kind.has(k):
			_by_kind[k] = []
		_by_kind[k].append(n)
	for k in _by_kind:
		(_by_kind[k] as Array).sort()


## kolejna tekstura danego rodzaju (po kolei, żeby sąsiednie się nie powtarzały)
static func pick(kind: String, rng: RandomNumberGenerator = null) -> String:
	_load_meta()
	var arr: Array = _by_kind.get(kind, [])
	if arr.is_empty():
		return ""
	if rng != null:
		return arr[rng.randi_range(0, arr.size() - 1)]
	var i := int(_next.get(kind, 0))
	_next[kind] = i + 1
	return arr[i % arr.size()]


## Kalkomania na ścianie. `pos` w metrach świata (punkt na powierzchni muru), `rot_y` — w którą stronę patrzy ściana.
## [środek x, środek z, pół szerokości wzdłuż x, pół głębokości wzdłuż z] w metrach świata
const ART_FREE := [[58.24, 17.6, 2.6, 0.9]]


static func decal(W: Node3D, name: String, pos: Vector3, rot_y: float, width: float, alpha := 1.0, fade := 50.0) -> Decal:
	var path := GDIR + name + ".png"
	if name == "" or not ResourceLoader.exists(path):
		return null
	# miejsca bez malunków (np. witryna z modelu 3D — naklejka rzutowałaby się na towar za szybą)
	for box in ART_FREE:
		if absf(pos.x - float(box[0])) < float(box[2]) + width * 0.5 and absf(pos.z - float(box[1])) < float(box[3]):
			return null
	var t: Texture2D = load(path)
	var d := Decal.new()
	d.texture_albedo = t
	d.size = Vector3(width, 0.5, width * float(t.get_height()) / float(t.get_width()))
	var n := Vector3(sin(rot_y), 0.0, cos(rot_y))
	var xa := Vector3.UP.cross(n)
	d.transform = Transform3D(Basis(xa, n, xa.cross(n)), pos)
	d.albedo_mix = alpha
	d.normal_fade = 0.45
	d.upper_fade = 0.02
	d.lower_fade = 0.02
	d.cull_mask = 1
	d.distance_fade_enabled = true
	d.distance_fade_begin = fade
	d.distance_fade_length = fade * 0.3
	W.add_child(d)
	return d


## punkt na ścianie budynku: kod ściany (1 = +Z, 2 = -Z, 3 = +X, 4 = -X), `u` metrów od początku ściany, wysokość nad podstawą, odsunięcie od muru
static func face_pos(b: Dictionary, code: int, u: float, y: float, out := 0.0) -> Vector3:
	match code:
		1: return Vector3(float(b.x0) * SC + u, float(b.by) + y, float(b.z1) * SC + out)
		2: return Vector3(float(b.x0) * SC + u, float(b.by) + y, float(b.z0) * SC - out)
		3: return Vector3(float(b.x1) * SC + out, float(b.by) + y, float(b.z0) * SC + u)
	return Vector3(float(b.x0) * SC - out, float(b.by) + y, float(b.z0) * SC + u)


static func face_rot(code: int) -> float:
	return [0.0, PI, PI / 2.0, -PI / 2.0][code - 1]


static func face_len(b: Dictionary, code: int) -> float:
	return ((float(b.x1) - float(b.x0)) if code <= 2 else (float(b.z1) - float(b.z0))) * SC


static func is_blind(b: Dictionary, code: int) -> bool:
	return (int(b.blind) == 1 and code >= 3) or (int(b.blind) == 2 and code <= 2)


## pozycje wszystkich zakolejkowanych detali fasad (do testu: żaden nie może wisieć w powietrzu)
static var placed: Array = []


## detale, które nie stoją przy ścianie żadnego budynku (ściana = obrys budynku ±1,3 m, wysokość od podstawy do dachu)
static func audit(W: Node3D) -> Array:
	var bad: Array = []
	for e in placed:
		if e[0] == "antenna":
			continue                      # anteny stoją na dachach, ponad obrysem ściany
		var o: Vector3 = e[1]
		var ok := false
		for b in W.blds:
			if not b.has("key"):
				continue
			var x0: float = float(b.x0) * SC
			var x1: float = float(b.x1) * SC
			var z0: float = float(b.z0) * SC
			var z1: float = float(b.z1) * SC
			var by: float = b.by
			if o.y < by - 0.5 or o.y > by + float(b.h) + 0.5:
				continue
			var on_x: bool = o.z > z0 - 0.3 and o.z < z1 + 0.3 and (absf(o.x - x0) < 1.3 or absf(o.x - x1) < 1.3)
			var on_z: bool = o.x > x0 - 0.3 and o.x < x1 + 0.3 and (absf(o.z - z0) < 1.3 or absf(o.z - z1) < 1.3)
			if on_x or on_z:
				ok = true
				break
		if not ok:
			bad.append(e)
	return bad


static func _queue(mesh: String, xf: Transform3D, col := Color.WHITE) -> void:
	placed.append([mesh, xf.origin])
	if not _mm.has(mesh):
		_mm[mesh] = []
		_mm_col[mesh] = []
	_mm[mesh].append(xf)
	_mm_col[mesh].append(col)


static func _xf(pos: Vector3, rot_y: float, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(scl), pos)


# ================================================================ graffiti, murale, plakaty
static func wall_art(W: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8612
	var ghosts_big := ["ghost_00", "ghost_01", "ghost_02"]
	var ghosts_wide := ["ghost_03", "ghost_04", "ghost_05", "ghost_06"]
	var gi := 0
	var wi := 0
	for b in W.blds:
		if not b.has("key"):
			continue
		var key: String = b.key
		if key == "urzad" or key == "klub":
			continue
		var cs: Vector2 = W.fac_cell[key]
		var h: float = b.h
		for code in range(1, 5):
			var ln := face_len(b, code)
			var rot := face_rot(code)
			if is_blind(b, code):
				# --- ściana szczytowa: numer bloku, wyblakły napis, duże graffiti przy ziemi
				if bool(b.plyta):
					if String(b.no) != "":
						decal(W, "num_" + String(b.no), face_pos(b, code, ln * 0.5, h - 2.4), rot, minf(2.8, ln * 0.45), 0.9, 90.0)
					if h > 11.0 and rng.randf() < 0.75:
						decal(W, ghosts_big[gi % ghosts_big.size()], face_pos(b, code, ln * 0.5, h * 0.52), rot, minf(4.6, ln - 1.2), 0.8, 80.0)
						gi += 1
					decal(W, pick("piece"), face_pos(b, code, ln * 0.5 + rng.randf_range(-0.5, 0.5), 1.75), rot, minf(5.0, ln - 0.8), 1.0, 60.0)
					if ln > 6.0:
						decal(W, pick("tag"), face_pos(b, code, 0.9, rng.randf_range(1.1, 1.6)), rot, 1.1)
				else:
					# ściana ogniowa kamienicy: stara reklama i coś świeższego na dole
					if h > 9.0:
						decal(W, ghosts_wide[wi % ghosts_wide.size()] if wi % 3 != 2 else ghosts_big[gi % ghosts_big.size()], face_pos(b, code, ln * 0.5, h * 0.6), rot, minf(6.5, ln - 1.5), 0.75, 80.0)
						wi += 1
					if rng.randf() < 0.7:
						decal(W, pick("piece") if rng.randf() < 0.5 else pick("throw"), face_pos(b, code, ln * rng.randf_range(0.3, 0.7), 1.6), rot, rng.randf_range(3.2, 4.6), 1.0, 60.0)
					for k in range(2):
						if rng.randf() < 0.7:
							decal(W, pick("tag"), face_pos(b, code, ln * rng.randf_range(0.08, 0.92), rng.randf_range(1.0, 1.8)), rot, rng.randf_range(0.8, 1.3))
				continue
			var g: Array = b.gx if code <= 2 else b.gz
			if key == "cegla":
				# hala: okna zaczynają się 2 m nad ziemią, więc cały dół to płótno
				var u := 2.5
				while u < ln - 2.5:
					var r := rng.randf()
					if r < 0.22:
						decal(W, pick("throw"), face_pos(b, code, u, 1.05), rot, rng.randf_range(2.0, 2.8))
					elif r < 0.36:
						decal(W, pick("slogan"), face_pos(b, code, u, 1.3), rot, rng.randf_range(2.6, 3.4))
					elif r < 0.5:
						decal(W, pick("tag"), face_pos(b, code, u, rng.randf_range(0.9, 1.5)), rot, rng.randf_range(0.9, 1.4))
					u += rng.randf_range(3.2, 6.0)
				continue
			# --- filary między oknami parteru: tagi i ogłoszenia (wejścia do klatek omijamy)
			var chance := 0.34 if bool(b.plyta) else 0.24
			for k in range(int(g[1]) + 1):
				if rng.randf() > chance:
					continue
				var u2 := float(g[0]) + k * cs.x
				if u2 < 0.5 or u2 > ln - 0.5:
					continue
				if int(b.stair) > 0 and code == int(b.front) and (posmod(k - int(b.st_off), int(b.stair)) == 0 or posmod(k - 1 - int(b.st_off), int(b.stair)) == 0):
					continue
				var r2 := rng.randf()
				if r2 < 0.5:
					decal(W, pick("tag"), face_pos(b, code, u2, rng.randf_range(1.2, 1.75)), rot, rng.randf_range(0.8, 1.15), 1.0, 40.0)
				elif r2 < 0.62:
					decal(W, pick("throw"), face_pos(b, code, u2, 1.35), rot, 1.3, 1.0, 40.0)
				else:
					decal(W, pick("poster", rng), face_pos(b, code, u2 + rng.randf_range(-0.2, 0.2), rng.randf_range(1.35, 1.7)), rot + rng.randf_range(-0.03, 0.03), rng.randf_range(0.5, 0.62), 1.0, 30.0)


## słup ogłoszeniowy oblepiony plakatami (x, z w jednostkach planu)
static func ad_pillar(W: Node3D, x: float, z: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var by: float = W.hd(x, z)
	var g := Node3D.new()
	g.position = Vector3(x * SC, by, z * SC)
	W.add_child(g)
	var conc := Props.pbr("concrete_wall_008", 0.5, Color(0.72, 0.7, 0.66))
	Models.cyl(g, 0.56, 0.56, 2.5, Vector3(0, 1.25, 0), conc, Vector3.ZERO, 20)
	Models.cyl(g, 0.66, 0.66, 0.14, Vector3(0, 0.07, 0), conc, Vector3.ZERO, 20)
	Models.cyl(g, 0.7, 0.62, 0.12, Vector3(0, 2.56, 0), Models.mat("3a2f2a", 0.8), Vector3.ZERO, 20)
	Models.cyl(g, 0.1, 0.62, 0.4, Vector3(0, 2.82, 0), Models.mat("4a3a32", 0.8), Vector3.ZERO, 20)
	var n := 7
	for i in range(n):
		var a := TAU * i / n + rng.randf_range(-0.2, 0.2)
		for row in range(2):
			if rng.randf() < 0.2:
				continue
			var p := g.position + Vector3(sin(a) * 0.56, 0.75 + row * 0.95 + rng.randf_range(-0.1, 0.1), cos(a) * 0.56)
			var d := decal(W, pick("poster", rng), p, a + rng.randf_range(-0.05, 0.05), rng.randf_range(0.55, 0.68), 1.0, 30.0)
			if d != null:
				d.size.y = 0.4
	W.add_col(x - 0.56 * INV, x + 0.56 * INV, z - 0.56 * INV, z + 0.56 * INV, 2.6)
	W.rects.pop_back()


# ================================================================ ławka osiedlowa
## betonowe nogi, drewniane szczeble — zamiast przypadkowego mebla z pokoju
static func bench(color := Color(0.2, 0.36, 0.26)) -> Node3D:
	var g := Node3D.new()
	var conc := Props.pbr("concrete_wall_008", 0.8, Color(0.7, 0.7, 0.68))
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = Props.tex("res://assets/tex/brown_planks_03_diff.jpg") if ResourceLoader.exists("res://assets/tex/brown_planks_03_diff.jpg") else null
	wood.albedo_color = color.lerp(Color(0.45, 0.33, 0.22), 0.35)
	wood.roughness = 0.85
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(0.9, 0.9, 0.9)
	for sx in [-0.72, 0.72]:
		Models.box(g, Vector3(0.09, 0.42, 0.44), Vector3(sx, 0.21, 0.0), conc)
		Models.box(g, Vector3(0.09, 0.5, 0.08), Vector3(sx, 0.64, -0.2), conc, Vector3(-0.2, 0, 0))
	for i in range(4):
		Models.box(g, Vector3(1.8, 0.035, 0.09), Vector3(0, 0.45, -0.15 + i * 0.105), wood)
	for i in range(3):
		Models.box(g, Vector3(1.8, 0.09, 0.03), Vector3(0, 0.6 + i * 0.12, -0.23 - i * 0.025), wood, Vector3(-0.2, 0, 0))
	return g


# ================================================================ wejścia do klatek
## Wejście do klatki bloku: drzwi we wnęce, daszek, schodki, ścianka z boku, domofon, światło.
## `pos`: punkt na murze u podstawy (metry świata), `rot_y`: kierunek ściany.
static func entrance(W: Node3D, pos: Vector3, rot_y: float, accent: Color, label: String, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	g.transform = Transform3D(Basis(Vector3.UP, rot_y), pos)
	W.add_child(g)
	var conc := Props.pbr("concrete_wall_008", 0.5, Color(0.72, 0.72, 0.7))
	var dark := Models.mat("121316", 0.7)
	var door_m := Props.pbr("rusty_painted_metal", 0.6, accent.lerp(Color(0.5, 0.52, 0.5), 0.5))
	# drzwi z szybą zbrojoną, daszek na wspornikach, stopień z wycieraczką, domofon i gablota — jeden model z Blendera
	var unit: Node3D = Stations.model("ul_wejscie")
	if unit != null:
		g.add_child(unit)
		Props.set_range(unit, 140.0)
		Interior._tint(unit, accent.lerp(Color(0.62, 0.64, 0.62), 0.6))
		var sw := Stations._find(unit, "Swiatlo") as MeshInstance3D
		if sw != null:
			sw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# skrzydło drzwi (z klamką) na własnym zawiasie: tenants.gd otwiera je przed wchodzącym i wychodzącym
		var leaf := Stations._find(unit, "TintSkrzydlo") as Node3D
		if leaf != null:
			var hinge: Vector3 = leaf.position + Vector3(-0.55, 0.0, 0.0)
			var piv := Node3D.new()
			unit.add_child(piv)
			piv.position = hinge
			for part in [leaf, Stations._find(unit, "Okucia") as Node3D]:
				if part != null and part.get_parent() == unit:
					var xf: Transform3D = part.transform
					unit.remove_child(part)
					piv.add_child(part)
					part.transform = Transform3D(xf.basis, xf.origin - hinge)
			g.set_meta("door", piv)
	else:
		Models.box(g, Vector3(1.7, 2.3, 0.12), Vector3(0, 1.15, 0.03), dark)
		Models.box(g, Vector3(0.98, 2.05, 0.08), Vector3(-0.2, 1.03, 0.1), door_m)
		Models.box(g, Vector3(2.5, 0.16, 1.5), Vector3(0, 0.08, 0.75), conc)
		Models.box(g, Vector3(2.7, 0.13, 1.7), Vector3(0, 2.52, 0.85), conc)
	# ścianka boczna (raz z lewej, raz z prawej) — malowana w kolorze bloku
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var wing := Props.pbr("grey_plaster_03", 0.5, accent.lerp(Color(0.8, 0.8, 0.76), 0.35))
	Models.box(g, Vector3(0.14, 2.46, 1.45), Vector3(side * 1.22, 1.23, 0.74), wing)
	Models.cyl(g, 0.035, 0.035, 2.46, Vector3(-side * 1.2, 1.23, 1.5), Models.mat("3a3d42", 0.5, 0.6), Vector3.ZERO, 6)
	# balustrady przy krawędziach stopnia, skrzynki pocztowe obok drzwi i (czasem) rower oparty o ścianę
	for bx in [-side * 1.28]:
		var rail: Node3D = Stations.model("ul_balustrada")
		if rail != null:
			rail.position = Vector3(bx, 0.16, 1.02)
			g.add_child(rail)
			Props.set_range(rail, 70.0)
	var mb: Node3D = Stations.model("ul_skrzynki")
	if mb != null:
		mb.position = Vector3(-side * 1.72, 0.0, 0.02)
		g.add_child(mb)
		Props.set_range(mb, 60.0)
	if rng.randf() < 0.5:
		var bike: Node3D = Stations.model("ul_rower")
		if bike != null:
			bike.position = Vector3(-side * 4.2, 0.0, 0.3 + rng.randf() * 0.1)
			bike.rotation.y = PI / 2.0 - side * (PI / 2.0 - 0.05) + rng.randf_range(-0.1, 0.1)
			g.add_child(bike)
			Props.set_range(bike, 50.0)
	# domofon i tabliczka
	var pl := Signs.plate(label, Color(0.9, 0.86, 0.7))
	pl.position = Vector3(0, 2.84, 1.69)
	g.add_child(pl)
	# lampa pod daszkiem (świeci nocą razem z latarniami)
	var li := OmniLight3D.new()
	li.position = Vector3(0, 2.2, 0.9)
	li.light_color = Color(1.0, 0.82, 0.55)
	li.omni_range = 5.5
	li.light_energy = 0.0
	li.visible = false
	li.distance_fade_enabled = true
	li.distance_fade_begin = 40.0
	li.distance_fade_length = 12.0
	if rng.randf() < 0.2:
		li.set_meta("flicker", rng.randf() * 10.0)
	li.set_meta("gain", 0.16)
	g.add_child(li)
	W.lamps.append(li)
	# kolizje: ścianka i podpora daszku
	var n := Vector3(sin(rot_y), 0.0, cos(rot_y))
	var t := Vector3(cos(rot_y), 0.0, -sin(rot_y))
	var wc := pos + t * side * 1.22 + n * 0.74
	var ex := absf(t.x) * 0.1 + absf(n.x) * 0.74
	var ez := absf(t.z) * 0.1 + absf(n.z) * 0.74
	W.add_col((wc.x - ex) * INV, (wc.x + ex) * INV, (wc.z - ez) * INV, (wc.z + ez) * INV, 2.5)
	W.rects.pop_back()
	# tablica ogłoszeń na ściance
	var bp := pos + t * side * 1.14 + n * 0.8 + Vector3(0, 1.45, 0)
	decal(W, pick("poster", rng), bp + Vector3(0, 0.0, 0) + n * 0.25, rot_y - side * PI / 2.0, 0.42, 1.0, 25.0)
	decal(W, pick("poster", rng), bp + n * -0.25, rot_y - side * PI / 2.0, 0.4, 1.0, 25.0)
	return g


static func entrances(W: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4407
	var letters := ["A", "B", "C", "D", "E", "F"]
	for b in W.blds:
		if not b.has("key") or not bool(b.plyta) or int(b.stair) <= 0:
			continue
		var code: int = b.front
		var cs: Vector2 = W.fac_cell[b.key]
		var g: Array = b.gx if code <= 2 else b.gz
		var k := 0
		for cx in range(int(g[1])):
			if posmod(cx - int(b.st_off), int(b.stair)) != 0:
				continue
			var u := float(g[0]) + (cx + 0.5) * cs.x
			var p := face_pos(b, code, u, 0.0)
			p.y = W.height(p.x, p.z)
			var lab := "BLOK %s — KLATKA %s" % [String(b.no), letters[k % letters.size()]] if String(b.no) != "" else "KLATKA %s" % letters[k % letters.size()]
			k += 1
			# prawdziwe drzwi (te, przez które się wchodzi) mają własny model
			var real := false
			for id in D.DOORS:
				if Vector2(float(D.DOORS[id].x) - p.x, float(D.DOORS[id].z) - p.z).length() < 3.0:
					real = true
			if real:
				continue
			var eg := entrance(W, p, face_rot(code), b.accent, lab, rng)
			W.entrance_spots.append({"p": p, "rot": face_rot(code), "label": lab, "door": eg.get_meta("door", null)})
			# ławka albo kosz przy co drugim wejściu
			var n := Vector3(sin(face_rot(code)), 0.0, cos(face_rot(code)))
			var t := Vector3(cos(face_rot(code)), 0.0, -sin(face_rot(code)))
			if rng.randf() < 0.6:
				var bp := p + t * (2.6 if rng.randf() < 0.5 else -2.6) + n * 0.5
				var be := bench(Color(0.2, 0.36, 0.26) if rng.randf() < 0.6 else Color(0.5, 0.28, 0.2))
				be.transform = Transform3D(Basis(Vector3.UP, face_rot(code)), Vector3(bp.x, W.height(bp.x, bp.z), bp.z))
				W.add_child(be)
				W.add_col((bp.x - 0.8) * INV, (bp.x + 0.8) * INV, (bp.z - 0.8) * INV, (bp.z + 0.8) * INV, 0.9)
				W.rects.pop_back()


# ================================================================ osprzęt elewacji (MultiMesh)
static func _mesh_dish() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# czasza: płytka misa z 10 segmentów, zwrócona w +Z i lekko w górę
	var seg := 10
	var r := 0.34
	var tilt := Basis(Vector3.RIGHT, -0.45)
	for i in range(seg):
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var c := tilt * Vector3(0, 0, -0.07)
		var p0 := tilt * Vector3(cos(a0) * r, sin(a0) * r, 0.0)
		var p1 := tilt * Vector3(cos(a1) * r, sin(a1) * r, 0.0)
		for tri in [[c, p1, p0], [c, p0, p1]]:
			st.set_normal((tilt * Vector3(0, 0, 1.0 if tri[1] == p1 else -1.0)))
			for v in tri:
				st.set_color(Color(0.82, 0.82, 0.8))
				st.add_vertex((v as Vector3) + Vector3(0, 0.1, 0.22))
	# ramię z konwerterem i uchwyt
	_box(st, Vector3(0, -0.06, 0.34), Vector3(0.025, 0.025, 0.42), Color(0.5, 0.5, 0.52), Basis(Vector3.RIGHT, -0.25))
	_box(st, Vector3(0, 0.03, 0.55), Vector3(0.05, 0.06, 0.08), Color(0.3, 0.3, 0.32))
	_box(st, Vector3(0, 0.0, 0.1), Vector3(0.03, 0.03, 0.22), Color(0.4, 0.4, 0.42))
	return st.commit()


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, rot := Basis.IDENTITY) -> void:
	var h := s * 0.5
	var faces := [
		[Vector3(0, 0, 1), Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		[Vector3(0, 0, -1), Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)],
		[Vector3(1, 0, 0), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)],
		[Vector3(-1, 0, 0), Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)],
		[Vector3(0, 1, 0), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)],
		[Vector3(0, -1, 0), Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)],
	]
	for f in faces:
		var nn: Vector3 = rot * (f[0] as Vector3)
		var q: Array = []
		for i in range(1, 5):
			q.append(c + rot * ((f[i] as Vector3) * h))
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(nn)
			st.set_color(col)
			st.add_vertex(q[idx])


static func _mesh_ac() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 0, 0.16), Vector3(0.82, 0.56, 0.3), Color(0.8, 0.8, 0.77))
	_box(st, Vector3(-0.12, 0.0, 0.315), Vector3(0.46, 0.46, 0.012), Color(0.1, 0.1, 0.11))
	_box(st, Vector3(0.3, 0.0, 0.315), Vector3(0.12, 0.4, 0.012), Color(0.55, 0.55, 0.53))
	for sx in [-0.3, 0.3]:
		_box(st, Vector3(sx, -0.32, 0.15), Vector3(0.04, 0.08, 0.34), Color(0.3, 0.3, 0.32))
	return st.commit()


static func _mesh_grate() -> ArrayMesh:
	# krata okienna 2,2 x 1,5 m: rama i pręty
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.16, 0.15, 0.14)
	var w := 2.16
	var h := 1.46
	for y in [-h * 0.5, h * 0.5, 0.0]:
		_box(st, Vector3(0, y, 0.05), Vector3(w, 0.03, 0.02), c)
	var n := 11
	for i in range(n):
		_box(st, Vector3(-w * 0.5 + w * i / (n - 1), 0, 0.05), Vector3(0.018, h, 0.018), c)
	return st.commit()


static func _mesh_antenna() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.25, 0.25, 0.27)
	_box(st, Vector3(0, 1.5, 0), Vector3(0.035, 3.0, 0.035), c)
	_box(st, Vector3(0, 2.75, 0), Vector3(1.1, 0.02, 0.02), c)
	for i in range(6):
		_box(st, Vector3(-0.5 + i * 0.2, 2.75, 0), Vector3(0.015, 0.015, 0.5 - i * 0.05), c)
	_box(st, Vector3(0, 2.3, 0), Vector3(0.02, 0.02, 0.8), c)
	return st.commit()


static func _mesh_laundry() -> ArrayMesh:
	# sznurek i trzy płachty prania (kolor z instancji mnoży biel)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 0.0, 0), Vector3(2.6, 0.008, 0.008), Color(0.25, 0.25, 0.25))
	var x := -1.1
	for i in range(4):
		var w = [0.5, 0.36, 0.62, 0.3][i]
		var h = [0.62, 0.46, 0.5, 0.7][i]
		var tint = [Color(1, 1, 1), Color(0.82, 0.86, 1.0), Color(1.0, 0.9, 0.82), Color(0.9, 1.0, 0.9)][i]
		_box(st, Vector3(x + w * 0.5, -h * 0.5, 0), Vector3(w, h, 0.012), tint, Basis(Vector3.RIGHT, 0.06 * (i - 1.5)))
		x += w + 0.1
	return st.commit()


static func _mesh_pipe() -> ArrayMesh:
	# metrowy odcinek rynny spustowej (skalowany w pionie)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.055
	cm.bottom_radius = 0.055
	cm.height = 1.0
	cm.radial_segments = 7
	cm.rings = 1
	var st := SurfaceTool.new()
	st.create_from(cm, 0)
	var am := st.commit()
	return am


static func _mesh_flowers() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 0, 0), Vector3(0.9, 0.16, 0.2), Color(0.42, 0.3, 0.22))
	for i in range(7):
		var cc = [Color(0.85, 0.2, 0.25), Color(0.95, 0.75, 0.2), Color(0.9, 0.4, 0.7), Color(0.25, 0.5, 0.2)][i % 4]
		_box(st, Vector3(-0.38 + i * 0.125, 0.15 + 0.03 * (i % 3), 0.02 * ((i % 3) - 1)), Vector3(0.12, 0.14, 0.14), cc if i % 2 == 0 else Color(0.2, 0.42, 0.18))
	return st.commit()


## siatka z modelu GLB (rupiecie balkonowe z Blendera) do MultiMesh
static func _glb_mesh(name: String) -> ArrayMesh:
	var n: Node3D = Stations.model(name)
	if n == null:
		return null
	var found: Array = []
	_collect_meshes(n, found)
	n.free()
	return found[0] if not found.is_empty() else null


static func _collect_meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
		out.append((n as MeshInstance3D).mesh)
	for c in n.get_children():
		_collect_meshes(c, out)


static func _mesh_blind() -> ArrayMesh:
	# roleta z lamelami: płat z teksturą (12 lameli na metr, cień pod każdą), listwa dolna i sznurek; kolor z instancji
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 1.9
	var quad := [[Vector3(-w * 0.5, 0.0, 0.012), Vector2(0, 0)], [Vector3(w * 0.5, 0.0, 0.012), Vector2(1, 0)], [Vector3(w * 0.5, -1.0, 0.012), Vector2(1, 12)], [Vector3(-w * 0.5, -1.0, 0.012), Vector2(0, 12)]]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for k in tri:
			st.set_normal(Vector3(0, 0, 1))
			st.set_color(Color(1, 1, 1))
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	_box(st, Vector3(0, -1.0, 0.02), Vector3(1.94, 0.03, 0.03), Color(0.62, 0.6, 0.56))
	_box(st, Vector3(0, 0.02, 0.025), Vector3(1.94, 0.05, 0.05), Color(0.6, 0.58, 0.54))
	_box(st, Vector3(0.75, -0.5, 0.025), Vector3(0.008, 1.0, 0.008), Color(0.7, 0.7, 0.66))
	return st.commit()


static var _slat_tex: ImageTexture = null


static func _slat_texture() -> ImageTexture:
	if _slat_tex == null:
		var img := Image.create(8, 16, true, Image.FORMAT_RGB8)
		for y in range(16):
			var v := 0.92
			if y < 2:
				v = 1.0
			elif y > 12:
				v = 0.55 - (y - 13) * 0.1
			for x in range(8):
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		_slat_tex = ImageTexture.create_from_image(img)
	return _slat_tex


static func _mesh_stain() -> ArrayMesh:
	# zaciek pod parapetem: pionowy pas, na górze ciemny, ku dołowi zanika (kanał alfa wierzchołków)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 1.0
	var pts := [Vector3(-0.5 * w, 0.0, 0), Vector3(0.5 * w, 0.0, 0), Vector3(0.28 * w, -1.0, 0), Vector3(-0.3 * w, -1.0, 0)]
	var cols := [Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for i in tri:
			st.set_normal(Vector3(0, 0, 1))
			st.set_color(cols[i])
			st.add_vertex(pts[i])
	return st.commit()


static func facade_props(W: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2231
	for b in W.blds:
		if not b.has("key"):
			continue
		var key: String = b.key
		var cs: Vector2 = W.fac_cell[key]
		var h: float = b.h
		var floors := int(floor((h + 0.3) / cs.y))
		# --- rynny spustowe na narożnikach i co kilka okien
		if key != "klub":
			for code in range(1, 5):
				var ln := face_len(b, code)
				var us := [0.14, ln - 0.14]
				if not is_blind(b, code) and ln > 14.0:
					var g0: Array = b.gx if code <= 2 else b.gz
					var mid := int(int(g0[1]) / 2)
					us.append(float(g0[0]) + mid * cs.x)
				for u in us:
					var pp := face_pos(b, code, u, h * 0.5 - 0.1, 0.07)
					var rust := rng.randf_range(0.0, 1.0)
					_queue("pipe", _xf(pp, 0.0, Vector3(1.0, h - 0.1, 1.0)), Color(0.42, 0.4, 0.38).lerp(Color(0.42, 0.26, 0.16), rust * 0.7))
		# --- emaliowana tabliczka z nazwą ulicy i numerem domu przy narożniku kamienicy (granat, biały napis, biała ramka)
		if bool(b.get("old", false)) and not is_blind(b, 1 if float(b.z0) <= 0.0 else 2):
			var pc: int = 2 if float(b.z0) > 0.0 else 1      # strona od ulicy Hutniczej (oś z ≈ 0)
			var pn := Node3D.new()
			var no := int(absf(float(b.x0) * 3.0 + float(b.z0) * 5.0)) % 40 + 2
			var street := "HUTNICZA"
			var pp := face_pos(b, pc, 1.3, 2.7, 0.03)
			pn.transform = Transform3D(Basis(Vector3.UP, face_rot(pc)), pp)
			W.add_child(pn)
			Models.box(pn, Vector3(0.62, 0.34, 0.02), Vector3.ZERO, Models.mat("f0eee6", 0.4, 0.2), Vector3.ZERO, false)
			Models.box(pn, Vector3(0.58, 0.3, 0.025), Vector3(0, 0, 0.004), Models.mat("1c3f7a", 0.35, 0.3), Vector3.ZERO, false)
			var tl := Signs.text("%s\n%d" % [street, no], "barlowc", 34, Color(0.95, 0.95, 0.92), 0.0042)
			tl.position = Vector3(0, 0.0, 0.02)
			pn.add_child(tl)
			Props.set_range(pn, 35.0)
		# --- anteny i wywietrzniki na dachu
		if bool(b.get("plyta", false)) or bool(b.get("old", false)):
			var cnt := int(face_len(b, 1) / 7.0) + 1
			for i in range(cnt):
				var ax := lerpf(float(b.x0), float(b.x1), rng.randf_range(0.1, 0.9)) * SC
				var az := lerpf(float(b.z0), float(b.z1), rng.randf_range(0.2, 0.8)) * SC
				var top := float(b.by) + h + (0.3 if bool(b.plyta) else 2.6)
				_queue("antenna", _xf(Vector3(ax, top, az), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.7, 1.1)))
		if not bool(b.get("plyta", false)) and not bool(b.get("old", false)):
			continue
		for code in range(1, 5):
			if is_blind(b, code):
				continue
			var g: Array = b.gx if code <= 2 else b.gz
			var rot := face_rot(code)
			for cx in range(int(g[1])):
				var stair: bool = int(b.stair) > 0 and posmod(cx - int(b.st_off), int(b.stair)) == 0
				if stair:
					continue
				var u := float(g[0]) + (cx + 0.5) * cs.x
				var loggia: bool = bool(b.plyta) and cx % 2 == 1
				for fl in range(floors):
					var r := rng.randf()
					var y0 := fl * cs.y
					if fl == 0 and bool(b.old) and float(b.dead) < 0.5:
						# parter kamienic: piwniczne okienko z kratą pod co drugim oknem, skrzynka gazowa i elektryczna rzadziej
						if rng.randf() < 0.45:
							_queue("par_piwnica", _xf(face_pos(b, code, u, 0.0, 0.0), rot, Vector3.ONE * 1.5))
						elif rng.randf() < 0.14:
							_queue("par_gaz", _xf(face_pos(b, code, u + 1.1, 0.0, 0.0), rot))
						elif rng.randf() < 0.1:
							_queue("par_prad", _xf(face_pos(b, code, u - 1.1, 0.0, 0.0), rot))
					if not (loggia and fl > 0):
						# zacieki pod parapetem i rolety w części okien (lekkie instancje, bez cieni)
						var win_c := y0 + 0.56 * cs.y
						if rng.randf() < 0.6:
							_queue("stain", _xf(face_pos(b, code, u, win_c - 0.74, 0.014), rot, Vector3(1.7 + rng.randf() * 0.3, 0.55 + rng.randf() * 0.6, 1.0)), Color(0.09, 0.07, 0.05))
						if (fl > 0 or not bool(b.plyta)) and rng.randf() < 0.2:
							var bl := rng.randf_range(0.3, 1.15)
							_queue("blind", _xf(face_pos(b, code, u, win_c + 0.68, 0.02), rot, Vector3(1.0, bl, 1.0)), [Color(0.86, 0.82, 0.72), Color(0.7, 0.72, 0.66), Color(0.55, 0.62, 0.55), Color(0.78, 0.7, 0.58)][rng.randi() % 4])
					if bool(b.plyta) and fl == 0:
						# kraty w oknach parteru
						if r < 0.55 and float(b.dead) < 0.5:
							_queue("grate", _xf(face_pos(b, code, u, y0 + 0.56 * cs.y, 0.0), rot))
						continue
					if loggia and fl > 0:
						# balkon: każde piętro inne — rower, rupiecie, suszarka z praniem, donice, antena, sznurek z praniem albo pusto
						var jx := rng.randf_range(-0.45, 0.45)
						if r < 0.14:
							pass
						elif r < 0.27:
							_queue("rower", _xf(face_pos(b, code, u + jx, y0 + 0.5, 0.5), rot + PI / 2.0 + (0.0 if rng.randf() < 0.5 else PI), Vector3.ONE * 0.95))
						elif r < 0.42:
							_queue("rup_a", _xf(face_pos(b, code, u + jx, y0 + 0.5, 0.45), rot + rng.randf_range(-0.2, 0.2), Vector3.ONE * 1.15))
						elif r < 0.56:
							_queue("rup_b", _xf(face_pos(b, code, u + jx, y0 + 0.5, 0.45), rot + rng.randf_range(-0.2, 0.2), Vector3.ONE * 1.15))
						elif r < 0.7:
							_queue("suszarka", _xf(face_pos(b, code, u + jx * 0.6, y0 + 0.5, 0.45), rot + rng.randf_range(-0.15, 0.15), Vector3.ONE * 1.1))
						elif r < 0.82:
							_queue("donice", _xf(face_pos(b, code, u + jx, y0 + 0.97, 0.74), rot))
						elif r < 0.9:
							_queue("dish", _xf(face_pos(b, code, u + rng.randf_range(-1.1, 1.1), y0 + 1.25, 0.76), rot + rng.randf_range(-0.5, 0.5)))
						else:
							_queue("laundry", _xf(face_pos(b, code, u, y0 + 1.75 + rng.randf_range(0.0, 0.25), 0.45), rot), Color.from_hsv(rng.randf(), rng.randf_range(0.0, 0.35), rng.randf_range(0.7, 1.0)))
					elif fl > 0:
						if r < 0.07:
							_queue("ac", _xf(face_pos(b, code, u + rng.randf_range(-0.5, 0.5), y0 + 0.5, 0.0), rot))
						elif r < 0.15:
							_queue("dish", _xf(face_pos(b, code, u + 1.25, y0 + cs.y * 0.45, 0.02), rot + rng.randf_range(-0.4, 0.4)))
						elif r < 0.22 and bool(b.old):
							_queue("flowers", _xf(face_pos(b, code, u, y0 + cs.y * 0.2 + 0.02, 0.12), rot))


## zamienia zebrane pozycje w kilka obiektów MultiMesh (jeden na rodzaj detalu)
static func flush(W: Node3D) -> void:
	var makers := {"dish": _mesh_dish, "ac": _mesh_ac, "grate": _mesh_grate, "antenna": _mesh_antenna, "laundry": _mesh_laundry, "pipe": _mesh_pipe, "flowers": _mesh_flowers,
		"blind": _mesh_blind, "stain": _mesh_stain,
		"rower": func(): return _glb_mesh("ul_rower"), "rup_a": func(): return _glb_mesh("fas_rupiecie_a"), "rup_b": func(): return _glb_mesh("fas_rupiecie_b"),
		"suszarka": func(): return _glb_mesh("fas_suszarka"), "donice": func(): return _glb_mesh("fas_donice"),
		"par_piwnica": func(): return _glb_mesh("par_piwnica"), "par_gaz": func(): return _glb_mesh("par_gaz"), "par_prad": func(): return _glb_mesh("par_prad")}
	var glb_kinds := ["rower", "rup_a", "rup_b", "suszarka", "donice", "par_piwnica", "par_gaz", "par_prad"]
	var ranges := {"dish": 70.0, "ac": 80.0, "grate": 45.0, "antenna": 150.0, "laundry": 80.0, "pipe": 110.0, "flowers": 45.0, "blind": 60.0, "stain": 70.0,
		"rower": 40.0, "rup_a": 45.0, "rup_b": 45.0, "suszarka": 50.0, "donice": 45.0, "par_piwnica": 45.0, "par_gaz": 40.0, "par_prad": 40.0}
	for name in _mm:
		var xfs: Array = _mm[name]
		if xfs.is_empty() or not makers.has(name):
			continue
		var mesh: ArrayMesh = (makers[name] as Callable).call()
		if mesh == null:
			continue
		if not (name in glb_kinds):
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.75
			mat.metallic = 0.25 if name in ["antenna", "grate", "pipe"] else 0.0
			if name == "laundry" or name == "blind":
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			if name == "blind":
				mat.albedo_texture = _slat_texture()
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if name == "stain":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.surface_set_material(0, mat)
		# dzielimy na kafle 60 x 60 m, żeby odległe detale w ogóle nie trafiały do rysowania
		var tiles := {}
		for i in range(xfs.size()):
			var o: Vector3 = (xfs[i] as Transform3D).origin
			var tk := Vector2i(int(floor(o.x / 60.0)), int(floor(o.z / 60.0)))
			if not tiles.has(tk):
				tiles[tk] = []
			tiles[tk].append(i)
		for tk in tiles:
			var ids: Array = tiles[tk]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = ids.size()
			for j in range(ids.size()):
				mm.set_instance_transform(j, xfs[ids[j]])
				mm.set_instance_color(j, _mm_col[name][ids[j]])
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = float(ranges.get(name, 80.0)) + 45.0
			mi.visibility_range_end_margin = 10.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			W.add_child(mi)
	_mm.clear()
	_mm_col.clear()
