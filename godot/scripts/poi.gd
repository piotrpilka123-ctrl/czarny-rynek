extends RefCounted
## Nowe miejsca na pustych polach mapy: złomowisko, skatepark z murami pod graffiti, opuszczona stacja benzynowa,
## nocny bazar i szklarnie pod folią. Każde ma kolizje, światło po zmroku i skrytkę z gotówką (raz na zapis).
## Wszystkie współrzędne w planie miasta (jak w world.gd); wymiary w metrach mnoży się przez INV.

const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")
const Stations = preload("res://scripts/stations.gd")
const Interior = preload("res://scripts/interior.gd")
const Fx = preload("res://scripts/fx.gd")
const Details = preload("res://scripts/details.gd")
const SC := 0.56
const INV := 1.0 / 0.56

const YARD := Vector2(-168.0, 213.0)      # złomowisko (środek)
const SKATE := Vector2(-136.0, -58.0)     # skatepark (środek)
const STATION := Vector2(186.0, 124.0)    # stacja benzynowa (środek)
const BAZAAR := Vector2(11.0, 209.0)      # bazar (środek)
const GREEN := Vector2(188.0, -140.0)     # szklarnie (środek)
## stoły pamiątek i skrytki: [id, x, z] — używane też przez test przejść
static var stashes: Array = []


## nawierzchnia pod nowymi miejscami (wołane na końcu _paint)
static func paint(W) -> void:
	W._pr(4, YARD.x - 30.0, YARD.y - 22.0, YARD.x + 30.0, YARD.y + 22.0)
	W._pr(2, SKATE.x - 17.0, SKATE.y - 13.0, SKATE.x + 17.0, SKATE.y + 13.0)
	W._pr(2, STATION.x - 13.0, STATION.y - 21.0, STATION.x + 13.0, STATION.y + 21.0)
	W._pr(2, STATION.x - 6.0, 88.0, STATION.x + 2.0, STATION.y - 20.0)
	W._pr(3, BAZAAR.x - 19.0, BAZAAR.y - 15.0, BAZAAR.x + 19.0, BAZAAR.y + 15.0)
	W._pr(4, GREEN.x - 16.0, GREEN.y - 21.0, GREEN.x + 16.0, GREEN.y + 21.0)
	W._pr(2, GREEN.x - 2.0, GREEN.y + 21.0, GREEN.x + 3.0, -112.0)


static func build(W) -> void:
	stashes.clear()
	var st: int = W.rng.state
	W.rng.seed = 20261014
	_yard(W)
	_skate(W)
	_station(W)
	_bazaar(W)
	_greenhouses(W)
	W.rng.state = st


# ---------------------------------------------------------------- pomocnicze
static func _p(c: Vector2, lx: float, lz: float) -> Vector2:
	return c + Vector2(lx, lz) * INV


## prostopadłościan o wymiarach w metrach; środek podstawy w planie (x, z); col >= 0 — kolizja o tej wysokości
static func _box(W, x: float, z: float, size: Vector3, mat: Material, y := 0.0, ry := 0.0, col := -1.0, shadow := true, tilt := Vector3.ZERO) -> MeshInstance3D:
	var by: float = W.hd(x, z) + y
	var mi := Models.box(W.city, Vector3(size.x * INV, size.y, size.z * INV), Vector3(x, by + size.y * 0.5, z), mat, Vector3(tilt.x, ry + tilt.y, tilt.z), shadow)
	if col >= 0.0:
		var ex := absf(cos(ry)) * size.x * 0.5 + absf(sin(ry)) * size.z * 0.5
		var ez := absf(sin(ry)) * size.x * 0.5 + absf(cos(ry)) * size.z * 0.5
		W.add_col(x - ex * INV, x + ex * INV, z - ez * INV, z + ez * INV, col if col > 0.0 else size.y + y)
		W.rects.pop_back()
	return mi


static func _cyl(W, x: float, z: float, r: float, h: float, mat: Material, y := 0.0, col := false) -> void:
	var by: float = W.hd(x, z) + y
	Models.cyl(W.city, r * INV, r * INV, h, Vector3(x, by + h * 0.5, z), mat, Vector3.ZERO, 10)
	if col:
		W.add_col(x - r * INV, x + r * INV, z - r * INV, z + r * INV, h + y)
		W.rects.pop_back()


## punktowe światło nocą (wspólny sterownik w env.gd: gain skaluje moc, flicker — migotanie)
static func _light(W, x: float, z: float, y: float, color: Color, gain: float, rng_m: float, flicker := false) -> void:
	var li := OmniLight3D.new()
	li.position = Vector3(x * SC, W.hd(x, z) + y, z * SC)
	li.light_color = color
	li.light_energy = 0.0
	li.omni_range = rng_m
	li.omni_attenuation = 1.1
	li.shadow_enabled = false
	li.visible = false
	li.distance_fade_enabled = true
	li.distance_fade_begin = 38.0
	li.distance_fade_length = 14.0
	li.set_meta("gain", gain)
	if flicker:
		li.set_meta("flicker", float(W.rng.randf() * 10.0))
	W.add_child(li)
	W.lamps.append(li)


## słup z lampą (własny, bez reflektora z cieniem — te nad jezdnią obsługuje world._lamp)
static func _pole(W, x: float, z: float, dead := false) -> void:
	var m: Material = Models.mat("5a5d62", 0.6, 0.6)
	_box(W, x, z, Vector3(0.14, 5.2, 0.14), m, 0.0, 0.0, 0.0)
	_box(W, x, z, Vector3(0.5, 0.1, 0.22), m, 5.2)
	if not dead:
		_box(W, x, z, Vector3(0.4, 0.03, 0.16), W.lamp_mat, 5.15, 0.0, -1.0, false)
		_light(W, x, z, 4.8, Color(1.0, 0.72, 0.42), 0.8, 12.0)


## skrytka z gotówką: raz na zapis, podpowiedź wraca do „pusto”
static func _stash(W, id: String, x: float, z: float, label: String, cash: int, msg: String, y := 0.0) -> void:
	var flag := "poi_" + id
	var gy: float = W.hd(x, z) + y
	stashes.append([flag, x, z])
	W.inter.append({"loc": "out", "x": x * SC, "z": z * SC, "y0": gy - 0.3, "y1": gy + 1.4, "r": 0.7, "reach": 2.5, "id": flag,
		"label": func(): return (label + " — pusto") if G.flag(flag) else label,
		"act": func():
			if G.flag(flag) or G.busy or G.ui == null or G.ui.mode != "":
				return
			G.S.flags[flag] = true
			G.S.cash += float(cash)
			Sfx.play("good")
			G.notify("%s (+%s)" % [msg, G.money(cash)], "good")})


## kontener/stos do przeszukania: raz na dobę, jak zwykły śmietnik
static func _dump(W, id: String, x: float, z: float, label: String, source := "dumpster", y := 0.0) -> void:
	var gy: float = W.hd(x, z) + y
	W.inter.append({"loc": "out", "x": x * SC, "z": z * SC, "y0": gy - 0.3, "y1": gy + 1.6, "r": 0.9, "reach": 2.6, "id": id,
		"label": func(): return (label + " — już przeszukane") if G.bin_used(id) else label,
		"act": func(): G.main.search_bin(id, source)})


static func _wreck(W, x: float, z: float, ry: float, type: String, color: String, y := 0.0, tilt := Vector3.ZERO) -> Node3D:
	var car: Node3D = Models.car(type, color, false)
	car.position = Vector3(x, W.hd(x, z) + y, z)
	car.rotation = Vector3(tilt.x, ry, tilt.z)
	car.scale = Vector3(INV, 1.0, INV)
	W.city.add_child(car)
	Props.set_range(car, 120.0)
	var L: float = Models.CAR_TYPES[type].L * 0.5 * INV
	var Wd: float = Models.CAR_TYPES[type].W * 0.5 * INV
	var ex := absf(sin(ry)) * L + absf(cos(ry)) * Wd
	var ez := absf(cos(ry)) * L + absf(sin(ry)) * Wd
	W.add_col(x - ex, x + ex, z - ez, z + ez, 1.5 + y)
	W.rects.pop_back()
	return car


static func _scatter(W, c: Vector2, items: Array) -> void:
	for e in items:
		var p := _p(c, float(e[1]), float(e[2]))
		W._prop(String(e[0]), p.x, p.y, float(e[3]), float(e[4]), 0.0, false, float(e[5]) if e.size() > 5 else 0.0)


## ćwierćrura: łuk od podłogi (x = 0) do pionowej ścianki (x = r), szerokość w, wzdłuż osi z; kolizja schodkami
static func _quarter(W, x: float, z: float, ry: float, w: float, r: float, mat: Material) -> void:
	var n := 8
	var prof: Array = []
	for i in range(n + 1):
		var a := float(i) / float(n) * PI * 0.5
		prof.append(Vector2(r * sin(a), r - r * cos(a)))
	var stt := SurfaceTool.new()
	stt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w * 0.5
	for i in range(n):
		var a0: Vector2 = prof[i]
		var a1: Vector2 = prof[i + 1]
		var n0 := Vector3(-a0.x / r + 0.0, 1.0 - a0.y / r, 0.0).normalized() if i > 0 else Vector3(0, 1, 0)
		var m0 := float(i) / float(n) * PI * 0.5
		var m1 := float(i + 1) / float(n) * PI * 0.5
		n0 = Vector3(-sin(m0), cos(m0), 0.0)
		var n1 := Vector3(-sin(m1), cos(m1), 0.0)
		for q in [[a0, -hw, n0], [a1, -hw, n1], [a1, hw, n1], [a0, -hw, n0], [a1, hw, n1], [a0, hw, n0]]:
			stt.set_normal(q[2])
			stt.add_vertex(Vector3(q[0].x, q[0].y, q[1]))
	# ścianka tylna i boki
	for q in [[Vector3(r, 0, -hw), Vector3(r, r, -hw), Vector3(r, r, hw)], [Vector3(r, 0, -hw), Vector3(r, r, hw), Vector3(r, 0, hw)]]:
		for v in q:
			stt.set_normal(Vector3(1, 0, 0))
			stt.add_vertex(v)
	for side in [-1.0, 1.0]:
		for i in range(n):
			var b0: Vector2 = prof[i]
			var b1: Vector2 = prof[i + 1]
			for v in [Vector3(r, 0, side * hw), Vector3(b0.x, b0.y, side * hw), Vector3(b1.x, b1.y, side * hw)]:
				stt.set_normal(Vector3(0, 0, side))
				stt.add_vertex(v)
	var mesh := stt.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m2: Material = mat.duplicate()
	(m2 as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m2
	mi.position = Vector3(x, W.hd(x, z), z)
	mi.rotation.y = ry
	mi.scale = Vector3(INV, 1.0, INV)
	W.city.add_child(mi)
	Props.set_range(mi, 110.0)
	# kolizja: 4 schodki po łuku (wysokość z początku odcinka — nie ma niewidzialnej ściany nad pochyłością)
	var steps := 4
	for i in range(steps):
		var x0 := r * float(i) / float(steps)
		var x1 := r * float(i + 1) / float(steps)
		var ang := asin(clampf(x0 / r, 0.0, 1.0))
		var hh := r - r * cos(ang)
		if hh < 0.25:
			continue
		var cx := x + (cos(ry) * ((x0 + x1) * 0.5)) * INV
		var cz := z - (sin(ry) * ((x0 + x1) * 0.5)) * INV
		var ex := (absf(cos(ry)) * (x1 - x0) * 0.5 + absf(sin(ry)) * hw) * INV
		var ez := (absf(sin(ry)) * (x1 - x0) * 0.5 + absf(cos(ry)) * hw) * INV
		W.add_col(cx - ex, cx + ex, cz - ez, cz + ez, hh)
		W.rects.pop_back()


# ---------------------------------------------------------------- złomowisko
static func _yard(W) -> void:
	var c := YARD
	var corr: Material = Props.pbr("rusty_corrugated_iron", 0.5)
	var rust: Material = Props.pbr("rusty_painted_metal", 0.5, Color(0.8, 0.7, 0.62))
	# płot z blachy, brama od północy (od strony osiedla), tylna dziura od południa
	var x0 := c.x - 30.0
	var x1 := c.x + 30.0
	var z0 := c.y - 22.0
	var z1 := c.y + 22.0
	W._fence_run(x0, z0, x1, z0, "sheet", 2.4, [], [], [c.x + 4.0])
	W._fence_run(x0, z1, x1, z1, "sheet", 2.4, [c.x + 16.0], [], [])
	W._fence_run(x0, z0, x0, z1, "sheet", 2.4, [], [], [])
	W._fence_run(x1, z0, x1, z1, "sheet", 2.4, [], [c.y - 4.0], [])
	# brama: dwa słupy, belka i szyld
	for sx in [-1.7, 1.7]:
		_box(W, c.x + 4.0 + sx * INV, z0, Vector3(0.3, 3.4, 0.3), rust, 0.0, 0.0, 0.0)
	_box(W, c.x + 4.0, z0, Vector3(3.9, 0.35, 0.3), rust, 3.2)
	W._sign("ZŁOMOWISKO HEŃKA", Vector3(c.x + 4.0, W.hd(c.x + 4.0, z0) + 3.9, z0 - 0.9), Color(0.95, 0.75, 0.3), 56, PI, 0.006, 10)
	W._sign("SKUP ZŁOMU · METALE · AKUMULATORY", Vector3(c.x + 4.0, W.hd(c.x + 4.0, z0) + 3.55, z0 - 0.9), Color(0.85, 0.85, 0.8), 26, PI, 0.005, 8)
	# biuro z dwóch kontenerów + wiata, waga przy bramie
	var o := _p(c, -9.0, -6.0)
	W._prop("container_green", o.x, o.y, 0.08, 2.6, 0.0)
	var o2 := _p(c, -9.0, -2.0)
	W._prop("container_red", o2.x, o2.y, -0.05, 2.6, 0.0)
	W._prop("container_red", o2.x, o2.y, 0.1, 2.6, 0.0, true, 2.6)
	_box(W, o.x + 3.4, o.y + 1.0, Vector3(2.6, 0.12, 3.6), corr, 2.35, 0.0, -1.0)
	W._prop("metal_office_desk", o.x + 6.0, o.y, 0.0, 0.9, 0.0, false)
	W._prop("plastic_monobloc_chair_01", o.x + 8.6, o.y + 1.2, 2.4, 0.86, 0.0, false)
	W._prop("hand_truck", o.x + 7.5, o.y - 3.0, 0.7, 1.3, 0.0, false)
	# sprasowane kostki złomu: stosy 2 + 1
	for e in [[-2.0, -9.0, 0.12], [-0.6, -9.2, -0.05], [-1.4, -9.1, 0.3]]:
		var p := _p(c, float(e[0]) + 14.0, float(e[1]))
		var up: bool = float(e[2]) > 0.2
		_box(W, p.x, p.y, Vector3(1.3, 1.1, 1.0), rust, 1.1 if up else 0.0, float(e[2]), 0.0 if not up else -1.0)
	# wraki: jeden na drugim, jeden przechylony na oponach, jeden bez kół w rogu
	_wreck(W, c.x + 2.0 * INV, c.y + 2.0 * INV, 0.35, "sedan", "6b3a2a")
	_wreck(W, c.x + 2.2 * INV, c.y + 2.0 * INV, 0.3, "hatch", "4a4f55", 1.15, Vector3(0.0, 0.0, 0.08))
	_wreck(W, c.x + 12.0 * INV, c.y + 5.0 * INV, -0.7, "kombi", "5a5a40", 0.0, Vector3(0.05, 0.0, -0.07))
	_wreck(W, c.x - 3.0 * INV, c.y + 9.0 * INV, 1.9, "maluch", "7a6a3a")
	_wreck(W, c.x + 15.0 * INV, c.y - 7.0 * INV, 0.1, "van", "4d5a64")
	W._prop("covered_car", c.x - 12.0 * INV, c.y + 9.0 * INV, 0.5, 0.0, 0.0)
	# hałdy opon i obręczy
	var tp := _p(c, 9.0, 11.0)
	for i in range(14):
		var a := float(i) * 0.9
		var rr := 1.0 + float(i % 3) * 0.9
		W._prop("old_tyre", tp.x + cos(a) * rr * INV * 0.5, tp.y + sin(a) * rr * INV * 0.5, a, 0.16, 0.0, false, 0.16 * float(i % 3))
	W._prop("wheels_stack", tp.x + 3.5 * INV, tp.y - 1.0 * INV, 0.4, 0.95, 0.0)
	W._prop("wheels_stack", tp.x - 3.0 * INV, tp.y + 2.5 * INV, 1.1, 0.8, 0.0)
	W._prop("rusted_wheel_rim_01", tp.x + 1.0 * INV, tp.y + 3.2 * INV, 0.0, 0.5, 0.0, false)
	# beczki, rury, palety, pralka z pieca, kanapa — to, co ludzie zostawiają za bramą
	_scatter(W, c, [["barrel_01", 11.0, -2.0, 0.0, 0.9], ["barrel_01", 11.9, -1.4, 1.0, 0.9], ["barrel_01", 11.2, -0.4, 2.0, 0.9], ["pipes", -14.0, 6.0, 0.4, 0.8],
		["pipes", -13.4, 8.0, -0.2, 0.8], ["pallet", -4.0, -9.0, 0.5, 0.16], ["pallet_broken", -6.0, 8.0, 1.0, 0.2], ["electric_stove", 4.0, 8.0, 0.6, 0.9],
		["couch", 6.0, 6.0, 2.2, 0.85], ["old_bed_frame", -7.0, 4.0, 0.3, 0.9], ["television_01", 6.4, 6.3, 0.2, 0.5, 0.45], ["propane_tank", 13.0, 2.0, 0.0, 0.7],
		["cinderblock", 13.8, 3.2, 0.5, 0.2], ["trashbag", 0.0, -3.0, 0.7, 0.5], ["can_rusted", 5.0, -5.0, 0.2, 0.13], ["drawer_cabinet", -2.0, 4.5, 0.4, 0.9]])
	# żuraw z magnesem: słup, wysięgnik, łańcuch — widoczny z daleka
	var cr := _p(c, 6.0, -3.0)
	var steel: Material = Props.pbr("rusty_painted_metal", 0.4, Color(0.95, 0.75, 0.3))
	_box(W, cr.x, cr.y, Vector3(0.7, 7.5, 0.7), steel, 0.0, 0.0, 0.0)
	_box(W, cr.x + 3.4 * INV, cr.y, Vector3(8.0, 0.5, 0.5), steel, 7.0, 0.0)
	_cyl(W, cr.x + 6.8 * INV, cr.y, 0.04, 3.4, Models.mat("2a2c30", 0.6, 0.6), 3.7)
	_cyl(W, cr.x + 6.8 * INV, cr.y, 0.55, 0.35, Models.mat("3a3d42", 0.5, 0.7), 3.4)
	# ognisko w beczce i reflektor nad biurem: łuna po zmroku
	var fb := _p(c, 8.5, -6.0)
	_cyl(W, fb.x, fb.y, 0.32, 0.8, Props.pbr("rusty_painted_metal", 0.3, Color(0.7, 0.55, 0.45)), 0.0, true)
	Fx.fire(W, Vector3(fb.x * SC, W.hd(fb.x, fb.y) + 0.85, fb.y * SC), 0.22, W.lamps)
	_pole(W, c.x - 4.0, z0 + 5.0)
	_pole(W, c.x + 14.0, c.y + 12.0)
	_light(W, o.x + 3.0, o.y + 4.5, 3.6, Color(1.0, 0.68, 0.38), 0.45, 11.0, true)
	# skrytki
	var tr := _p(c, 12.0 - 0.0, 5.0)
	_stash(W, "zlom_bagaznik", c.x + 12.0 * INV, c.y + 5.0 * INV - 3.2 * INV, "Zajrzyj do bagażnika wraka", 110, "W bagażniku kombi leżała zwinięta w szmatę koperta z kasą", 0.7)
	_stash(W, "zlom_puszka", o.x + 6.0, o.y + 0.9, "Zajrzyj do puszki po kawie", 45, "Heniek chował pod biurkiem puszkę z drobnymi", 0.4)
	_dump(W, "poi_zlom_stos", c.x + 4.0 * INV, c.y + 7.0 * INV, "Przeszukaj stos złomu")
	_dump(W, "poi_zlom_kontener", c.x - 16.0 * INV, c.y + 2.0 * INV, "Przeszukaj sterty drutu i kabli")
	_box(W, c.x - 16.0 * INV, c.y + 2.0 * INV, Vector3(2.2, 1.0, 1.6), corr, 0.0, 0.3, 0.0)
	_box(W, c.x + 4.0 * INV, c.y + 7.0 * INV, Vector3(1.8, 0.7, 1.4), rust, 0.0, 0.2, 0.0)
	var dog := Props.make("dog", 0.75, 0.0, true)
	dog.position = Vector3(c.x + 6.5, W.hd(c.x + 6.5, z0 + 5.0), z0 + 5.0)
	dog.rotation.y = PI
	dog.scale = Vector3(INV, 1.0, INV)
	W.city.add_child(dog)
	Props.set_range(dog, 70.0)
	W._tree(c.x - 34.0, c.y - 15.0, 1.1, 0.3)


# ---------------------------------------------------------------- skatepark
static func _skate(W) -> void:
	var c := SKATE
	var conc: Material = Props.pbr("concrete_floor_worn_001", 0.4, Color(0.78, 0.78, 0.76))
	var dark: Material = Models.mat("3a3d42", 0.5, 0.7)
	var wood: Material = Models.mat("8a6a3a", 0.8)
	# mur z graffiti: długi, betonowy, od północy — za nim ćwierćrury
	var wz := c.y - 13.0
	for i in range(5):
		var wx := c.x - 11.0 + float(i) * 5.6
		_box(W, wx, wz, Vector3(5.6, 2.6, 0.3), conc, 0.0, 0.0, 0.0)
		var d = Details.decal(W, Details.pick("piece") if i % 2 == 0 else Details.pick("slogan"), Vector3(wx * SC, W.hd(wx, wz) + 1.3, (wz + 0.2 * INV) * SC), 0.0, 3.4, 1.0, 60.0)
		if i == 2:
			Details.decal(W, Details.pick("tag"), Vector3(wx * SC + 1.2, W.hd(wx, wz) + 0.7, (wz + 0.2 * INV) * SC), 0.0, 1.4, 1.0, 40.0)
	_quarter(W, c.x - 7.0, wz + 2.0 * INV, 0.0, 4.8, 1.5, conc)
	_quarter(W, c.x + 2.0, wz + 2.0 * INV, 0.0, 4.8, 1.5, conc)
	# prawy bok: dwie ćwierćrury twarzą do siebie, między nimi „bank”
	_quarter(W, c.x + 12.0, c.y - 4.0, PI, 4.4, 1.2, conc)
	_quarter(W, c.x + 12.0, c.y + 3.0, PI, 4.4, 1.2, conc)
	# funbox: ławka z krawędziami i rail przy schodkach, rampka pod rail
	_box(W, c.x - 3.0, c.y + 2.0, Vector3(3.6, 0.5, 1.6), conc, 0.0, 0.0, 0.0)
	_box(W, c.x - 3.0, c.y + 2.0, Vector3(3.8, 0.06, 1.8), Models.mat("c9b8a0", 0.7), 0.5, 0.0, -1.0, false)
	_box(W, c.x + 4.0, c.y + 4.0, Vector3(2.0, 0.28, 1.4), conc, 0.0, 0.0, 0.0)
	_box(W, c.x + 4.0 + 1.0 * INV, c.y + 4.0, Vector3(1.0, 0.56, 1.4), conc, 0.0, 0.0, 0.0)
	_box(W, c.x + 4.0 + 2.0 * INV, c.y + 4.0, Vector3(1.0, 0.84, 1.4), conc, 0.0, 0.0, 0.0)
	_box(W, c.x + 4.0 + 3.0 * INV, c.y + 4.0, Vector3(1.0, 1.1, 1.4), conc, 0.0, 0.0, 0.0)
	_box(W, c.x + 1.0, c.y - 3.0, Vector3(5.0, 0.07, 0.07), dark, 0.62)
	for sx in [-2.3, 2.3]:
		_box(W, c.x + 1.0 + sx * INV, c.y - 3.0, Vector3(0.07, 0.62, 0.07), dark, 0.0, 0.0, 0.0)
	_box(W, c.x - 10.0, c.y + 3.0, Vector3(6.0, 0.09, 0.09), dark, 0.9)
	_box(W, c.x - 12.5, c.y + 3.0, Vector3(0.09, 0.9, 0.09), dark, 0.0, 0.0, 0.0)
	_box(W, c.x - 7.5, c.y + 3.0, Vector3(0.09, 0.9, 0.09), dark, 0.0, 0.0, 0.0)
	# wokół: ławki, kosz, kolorowe pachołki, deskorolka, puszki po farbie, boombox na murku
	W._bench(c.x - 1.0, c.y + 11.0, PI)
	W._bench(c.x + 8.0, c.y + 11.0, PI)
	W._bin(c.x + 14.0, c.y + 10.0, 0.0)
	_scatter(W, c, [["pacholek", -6.0, 0.0, 0.0, 0.5], ["pacholek", -5.0, 0.8, 0.5, 0.5], ["spray_paint_bottles", 3.0, -7.4, 0.4, 0.22], ["can_rusted", 9.0, 5.0, 0.3, 0.13],
		["boombox", -3.0, 2.0, 0.6, 0.3, 0.5], ["dirty_football", 6.0, 8.5, 0.0, 0.22], ["trashbag", 15.0, 4.0, 0.9, 0.5], ["plastic_bottle_gallon", 11.0, 8.0, 0.0, 0.3]])
	var deck := _p(c, -1.5, 6.0)
	_box(W, deck.x, deck.y, Vector3(0.8, 0.03, 0.2), wood, 0.1, 0.5, -1.0, false)
	for wx2 in [-0.28, 0.28]:
		_box(W, deck.x + wx2 * INV, deck.y, Vector3(0.1, 0.06, 0.1), Models.mat("d9d9d9", 0.5), 0.03, 0.5, -1.0, false)
	_pole(W, c.x - 14.0, c.y + 12.0)
	_pole(W, c.x + 15.0, c.y - 8.0)
	_stash(W, "skate_tablica", c.x - 12.0, wz + 2.5 * INV, "Odsuń luźną płytę pod murem", 55, "Skaterzy chowali za płytą zrzutkę na nową deskę", 0.3)
	_dump(W, "poi_skate_kosz", c.x + 14.0, c.y + 10.0, "Pogrzeb w koszu przy skateparku", "bin")


# ---------------------------------------------------------------- opuszczona stacja benzynowa
static func _station(W) -> void:
	var c := STATION
	var rust: Material = Props.pbr("rusty_painted_metal", 0.5, Color(0.85, 0.7, 0.6))
	var conc: Material = Props.pbr("concrete_wall_008", 0.35, Color(0.7, 0.7, 0.68))
	var red: Material = Models.mat("8a2a24", 0.7, 0.3)
	var white: Material = Models.mat("c9c9c4", 0.7, 0.1)
	# modele z Blendera (make_stacja.py): wiata, dystrybutory, kiosk, słup z cennikiem
	var wc := _p(c, 0.0, 2.0)
	var wm: Node3D = Stations.model("stacja_wiata")
	if wm != null:
		W._place(wm, wc.x, wc.y, 0.0)
		Props.set_range(wm, 150.0)
		var lens := Stations._find(wm, "Swiatlo") as MeshInstance3D
		if lens != null:
			lens.material_override = W.lamp_mat
			lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-5.4, 5.4]:
		for sz in [-2.6, 2.6]:
			W.add_col(wc.x + (sx - 0.3) * INV, wc.x + (sx + 0.3) * INV, wc.y + (sz - 0.3) * INV, wc.y + (sz + 0.3) * INV, 4.6)
			W.rects.pop_back()
	for sx in [-2.8, 2.8]:
		var dm: Node3D = Stations.model("stacja_dystrybutor")
		if dm != null:
			Props.set_range(W._place(dm, wc.x + sx * INV, wc.y, 0.0, 0.5, 0.35, 2.0), 110.0)
	var kc := _p(c, 0.0, -14.0)
	var km: Node3D = Stations.model("stacja_kiosk")
	if km != null:
		Props.set_range(W._place(km, kc.x, kc.y, 0.0, 4.1, 2.6, 2.9), 150.0)
	var pyl := _p(c, 10.0, 2.0)
	var pm: Node3D = Stations.model("stacja_slup")
	if pm != null:
		Props.set_range(W._place(pm, pyl.x, pyl.y, 0.0, 0.3, 0.3, 2.9), 160.0)
	# spalony samochód, opony, bariery, plama po paliwie na betonie
	_wreck(W, c.x - 7.0 * INV, c.y + 11.0 * INV, 2.6, "sedan", "1e1c1a")
	_scatter(W, c, [["old_tyre", -9.5, 8.0, 0.0, 0.16], ["old_tyre", -9.0, 8.8, 0.0, 0.16, 0.16], ["trafficbarrier_1", 6.0, 13.0, 0.4, 0.9], ["trafficcone_1", -2.0, 12.0, 0.0, 0.6],
		["trafficcone_2", 3.0, 11.0, 0.0, 0.6], ["barrel_01", -7.0, -6.0, 0.0, 0.9], ["barrel_01", -6.2, -6.4, 0.7, 0.9], ["utility_box_01", 8.0, -8.0, 0.0, 1.0],
		["plastic_crate_01", 5.0, -9.0, 0.6, 0.3], ["trashbag", -5.0, -11.0, 0.4, 0.5], ["propane_tank", -8.5, -9.0, 0.0, 0.7]])
	# latarnia pod wiatą migocze — „ktoś jeszcze tu płaci rachunki”
	_light(W, wc.x, wc.y, 4.0, Color(1.0, 0.82, 0.5), 0.5, 14.0, true)
	_light(W, pyl.x, pyl.y + 1.0, 5.6, Color(1.0, 0.3, 0.25), 0.18, 8.0, true)
	_pole(W, c.x - 12.0, c.y + 16.0, true)
	_pole(W, c.x + 12.0, c.y + 16.0)
	# skrytki: kasa w kiosku (przez wybitą szybę) i klapa zbiornika
	_stash(W, "stacja_kasa", kc.x + 2.4 * INV, kc.y + 2.9 * INV, "Zajrzyj przez wybitą szybę kiosku", 120, "Za kratką kasy została kaseta z utargiem sprzed zamknięcia", 0.9)
	_stash(W, "stacja_klapa", c.x + 3.5, c.y + 14.0, "Podważ klapę zbiornika", 65, "Pod klapą zbiornika ktoś zostawił zawiniątko z gotówką", 0.1)
	_box(W, c.x + 3.5, c.y + 14.0, Vector3(0.8, 0.05, 0.8), Models.mat("3a3d42", 0.5, 0.7), 0.0, 0.2, -1.0, false)
	_dump(W, "poi_stacja_beczki", c.x - 6.6, c.y - 6.2 * INV + 0.0, "Przeszukaj beczki za kioskiem")
	W._tree(c.x - 20.0, c.y + 12.0, 1.0, 0.3)


# ---------------------------------------------------------------- nocny bazar
static func _bazaar(W) -> void:
	var c := BAZAAR
	var pole: Material = Models.mat("7a6a50", 0.8)
	var table: Material = Models.mat("6b5a42", 0.9)
	var tarps := ["b8442c", "2c6ab8", "3a8a4a", "c9a02c", "8a3a8a", "d9d4c4", "b86a2c", "2c8a8a"]
	# dwa rzędy stoisk po cztery, szeroka alejka w środku
	var k := 0
	for row in [-1, 1]:
		for i in range(4):
			var sx: float = c.x - 13.5 + float(i) * 8.6 + (W.rng.randf() - 0.5) * 0.8
			var sz := c.y + float(row) * 8.0
			var ry := 0.0 if row < 0 else PI
			var tarp: Material = Models.mat(tarps[k % tarps.size()], 0.95)
			# słupki, daszek z plandeki (lekko pochylony), lada z towarem
			for dx in [-1.8, 1.8]:
				_box(W, sx + dx * INV, sz - float(row) * 1.0 * INV, Vector3(0.08, 2.5, 0.08), pole, 0.0, 0.0, 0.0)
				_box(W, sx + dx * INV, sz + float(row) * 1.0 * INV, Vector3(0.08, 2.1, 0.08), pole, 0.0, 0.0, 0.0)
			_box(W, sx, sz, Vector3(4.2, 0.06, 2.6), tarp, 2.2, 0.0, -1.0, true, Vector3(0.07 * float(row), 0.0, 0.0))
			_box(W, sx, sz - float(row) * 0.2 * INV, Vector3(3.4, 0.85, 0.9), table, 0.0, ry, 0.0)
			_box(W, sx, sz - float(row) * 0.2 * INV, Vector3(3.5, 0.05, 1.0), Models.mat(tarps[(k + 3) % tarps.size()], 0.95), 0.85, ry, -1.0, false)
			# towar: stos ciuchów, skrzynki, sprzęt
			match k % 4:
				0:
					for j in range(4):
						var cl: Node3D = Stations.model("ciuch_zlozony")
						if cl != null:
							cl.position = Vector3(sx + (float(j) - 1.5) * 0.7 * INV, W.hd(sx, sz) + 0.9, sz - float(row) * 0.2 * INV)
							cl.scale = Vector3(INV, 1.0, INV)
							W.city.add_child(cl)
							Props.set_range(cl, 50.0)
				1:
					W._prop("television_02", sx - 1.0 * INV, sz, 0.1, 0.4, 0.0, false, 0.9)
					W._prop("boombox", sx + 0.4 * INV, sz, 0.3, 0.28, 0.0, false, 0.9)
					W._prop("classic_laptop", sx + 1.3 * INV, sz, 0.0, 0.05, 0.0, false, 0.9)
				2:
					W._prop("plastic_crate_01", sx - 1.0 * INV, sz, 0.2, 0.3, 0.0, false, 0.9)
					W._prop("plastic_crate_01", sx + 0.6 * INV, sz, -0.2, 0.3, 0.0, false, 0.9)
					W._prop("vintage_suitcase", sx + 1.3 * INV, sz, 0.4, 0.28, 0.0, false, 0.9)
				3:
					W._prop("radio", sx - 0.8 * INV, sz, 0.1, 0.3, 0.0, false, 0.9)
					W._prop("cigarette_pack", sx + 0.5 * INV, sz, 0.1, 0.05, 0.0, false, 0.9)
					W._prop("dom_butelka", sx + 1.2 * INV, sz, 0.0, 0.3, 0.0, false, 0.9)
			k += 1
	# girlanda żarówek nad alejką: trzy sznury na słupach, żarówki świecą wspólnym materiałem latarni
	for gz in [-3.0, 3.0]:
		var px0 := c.x - 17.0
		var px1 := c.x + 17.0
		for pxx in [px0, px1]:
			_box(W, pxx, c.y + gz * INV, Vector3(0.12, 3.6, 0.12), pole, 0.0, 0.0, 0.0)
		var n := 22
		for i in range(n):
			var t := float(i) / float(n - 1)
			var bx := lerpf(px0, px1, t)
			var sag := 0.5 * (1.0 - pow(2.0 * t - 1.0, 2.0))
			Models.sphere(W.city, 0.09 * INV, Vector3(bx, W.hd(bx, c.y + gz * INV) + 3.3 - sag, c.y + gz * INV), W.lamp_mat, Vector3(1, 1, 1), false, 6)
	_light(W, c.x - 8.0, c.y, 3.1, Color(1.0, 0.78, 0.5), 0.55, 13.0)
	_light(W, c.x + 8.0, c.y, 3.1, Color(1.0, 0.78, 0.5), 0.55, 13.0)
	W._sign("NOCNY BAZAR", Vector3(c.x, W.hd(c.x, c.y - 16.0) + 4.0, c.y - 16.7), Color(1.0, 0.82, 0.4), 64, PI, 0.007, 12)
	_box(W, c.x - 3.2 * INV, c.y - 16.0, Vector3(0.18, 4.2, 0.18), pole, 0.0, 0.0, 0.0)
	_box(W, c.x + 3.2 * INV, c.y - 16.0, Vector3(0.18, 4.2, 0.18), pole, 0.0, 0.0, 0.0)
	_box(W, c.x, c.y - 16.0, Vector3(7.0, 1.0, 0.1), Models.mat("1c1c1e", 0.9), 3.55, 0.0, -1.0, false)
	# na tyłach: beczka-ognisko, skrzynki do siedzenia, stos kartonów
	_scatter(W, c, [["wooden_crate_02", -17.0, 13.5, 0.3, 0.42], ["wooden_crate_02", -16.0, 14.4, 1.2, 0.42], ["cardboard_box_01", -14.5, 14.0, 0.5, 0.34], ["cardboard_box_01", -14.2, 14.8, 1.5, 0.34],
		["plastic_monobloc_chair_01", 15.0, 13.0, 2.4, 0.86], ["plastic_monobloc_chair_01", 16.4, 13.5, 3.9, 0.86], ["trashbag", 17.0, -13.0, 0.5, 0.5], ["pallet", 14.0, -14.0, 0.3, 0.16]])
	var fb := _p(c, 15.7, 14.6)
	_cyl(W, fb.x, fb.y, 0.32, 0.8, Props.pbr("rusty_painted_metal", 0.3, Color(0.7, 0.55, 0.45)), 0.0, true)
	Fx.fire(W, Vector3(fb.x * SC, W.hd(fb.x, fb.y) + 0.85, fb.y * SC), 0.2, W.lamps)
	W._bin(c.x + 18.0, c.y + 11.0, 0.0)
	# skrytki: kasetka pod stołem handlarza i stos skrzynek (jak śmietnik, resetuje się co dobę)
	var tbl := _p(c, -13.5, 8.0)
	_stash(W, "bazar_kasetka", tbl.x + 0.8, tbl.y + 0.6, "Zajrzyj pod ladę stoiska", 75, "Pod ladą stała kasetka, którą handlarz zapomniał zabrać", 0.15)
	_dump(W, "poi_bazar_skrzynki", c.x - 15.0 * INV + 0.0, c.y + 14.5 * INV, "Przeszukaj skrzynki za stoiskami")
	W._tree(c.x + 20.0, c.y + 4.0, 1.0, 0.5)


# ---------------------------------------------------------------- szklarnie pod folią
static func _greenhouses(W) -> void:
	var c := GREEN
	var foil := StandardMaterial3D.new()
	foil.albedo_color = Color(0.8, 0.88, 0.8, 0.28)
	foil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foil.roughness = 0.2
	foil.cull_mode = BaseMaterial3D.CULL_DISABLED
	foil.emission_enabled = true
	foil.emission = Color(0.6, 0.2, 0.8)
	foil.emission_energy_multiplier = 0.0
	var rib: Material = Models.mat("b8b8b0", 0.5, 0.6)
	var soil: Material = Models.mat("3a2a1e", 1.0)
	# trzy tunele foliowe równolegle do osi z; środkiem przebiega ścieżka od bramki
	var i := 0
	for tx in [-8.0, 0.0, 8.0]:
		var p := _p(c, tx, 0.0)
		var ln := 11.0
		var arc := _half_tunnel(1.55 * INV, 2.0, ln * INV, foil)
		arc.position = Vector3(p.x, W.hd(p.x, p.y), p.y)
		W.city.add_child(arc)
		Props.set_range(arc, 130.0)
		for rz in range(-5, 6):
			var rp := Vector2(p.x, p.y + float(rz) * INV)
			_box(W, rp.x - 1.45 * INV, rp.y, Vector3(0.06, 1.2, 0.06), rib, 0.0, 0.0, -1.0, false)
			_box(W, rp.x + 1.45 * INV, rp.y, Vector3(0.06, 1.2, 0.06), rib, 0.0, 0.0, -1.0, false)
		# kolizja: ściana tunelu z przejściem na wprost ścieżki
		W.add_col(p.x - 1.7 * INV, p.x + 1.7 * INV, p.y - ln * 0.5 * INV, p.y - 1.2 * INV, 1.8)
		W.rects.pop_back()
		W.add_col(p.x - 1.7 * INV, p.x + 1.7 * INV, p.y + 1.2 * INV, p.y + ln * 0.5 * INV, 1.8)
		W.rects.pop_back()
		# środek tunelu: grządki i rośliny, fioletowa lampa
		for gz in [-4.0, 4.0]:
			_box(W, p.x, p.y + gz * INV, Vector3(1.1, 0.25, 2.6), soil, 0.0, 0.0, -1.0, false)
			for rj in range(3):
				var pl: Node3D = Stations.model("roslina_%d" % (1 + (i + rj) % 3))
				if pl != null:
					pl.position = Vector3(p.x, W.hd(p.x, p.y) + 0.25, p.y + (gz + float(rj - 1) * 0.8) * INV)
					pl.scale = Vector3(INV, 1.0, INV) * 1.2
					W.city.add_child(pl)
					Props.set_range(pl, 55.0)
		_light(W, p.x, p.y, 1.3, Color(0.78, 0.35, 1.0), 0.5, 7.0)
		i += 1
	# bramka, szopa z kranem, beczki na deszczówkę, taczka — i szyld, który niczego nie obiecuje
	W._fence_run(c.x - 16.0, c.y - 21.0, c.x + 16.0, c.y - 21.0, "siatka", 1.9, [], [], [])
	W._fence_run(c.x - 16.0, c.y + 21.0, c.x + 16.0, c.y + 21.0, "siatka", 1.9, [], [], [c.x + 0.5])
	W._fence_run(c.x - 16.0, c.y - 21.0, c.x - 16.0, c.y + 21.0, "siatka", 1.9, [], [], [])
	W._fence_run(c.x + 16.0, c.y - 21.0, c.x + 16.0, c.y + 21.0, "siatka", 1.9, [], [c.y], [])
	W._sign("WARZYWA OD MIETKA\nNIE DOTYKAĆ", Vector3(c.x + 0.5, W.hd(c.x, c.y + 21.0) + 2.4, c.y + 21.3), Color(0.8, 0.9, 0.6), 40, 0.0, 0.006, 8)
	var hut := Stations.model("altanka")
	if hut != null:
		Interior._tint(hut, Color(0.45, 0.55, 0.4))
		var hp := _p(c, 11.0, -13.0)
		W._place(hut, hp.x, hp.y, PI * 0.5, 2.4, 1.9, 2.4)
		Props.set_range(hut, 120.0)
	_scatter(W, c, [["barrel_01", -13.0, -15.0, 0.0, 0.9], ["barrel_01", -12.0, -15.2, 0.6, 0.9], ["wooden_crate_02", -3.0, -14.0, 0.4, 0.42], ["konewka", -4.4, -13.0, 0.6, 0.3],
		["nawoz", 5.0, -14.5, 0.3, 0.6], ["nawoz", 6.0, -14.0, 1.0, 0.6], ["hand_truck", 9.0, -9.0, 2.2, 1.3], ["plastic_crate_01", 13.0, 12.0, 0.4, 0.3], ["plastic_crate_01", 13.6, 12.6, 1.1, 0.3]])
	_light(W, c.x + 11.0 * INV, c.y - 11.0 * INV, 2.6, Color(0.95, 0.9, 0.6), 0.4, 8.0, true)
	_stash(W, "szklarnie_termos", c.x + 4.0 * INV, c.y - 14.0 * INV, "Zajrzyj do termosu za workami", 95, "W termosie, zamiast herbaty, zwitek banknotów od odbiorców Mietka", 0.3)
	_dump(W, "poi_szklarnie_kompost", c.x - 9.0 * INV, c.y + 14.0 * INV, "Przekop kompost", "bin")
	_box(W, c.x - 9.0 * INV, c.y + 14.0 * INV, Vector3(2.0, 0.8, 1.4), soil, 0.0, 0.2, 0.0)


## półłukowy tunel: łuk o promieniu r (plan), długości l (plan) wzdłuż osi z; zwraca MeshInstance3D
static func _half_tunnel(r: float, h: float, l: float, mat: Material) -> MeshInstance3D:
	var stt := SurfaceTool.new()
	stt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	var hl := l * 0.5
	for i in range(n):
		var a0 := PI * float(i) / float(n)
		var a1 := PI * float(i + 1) / float(n)
		var p0 := Vector2(cos(a0), sin(a0))
		var p1 := Vector2(cos(a1), sin(a1))
		for q in [[p0, -hl], [p1, -hl], [p1, hl], [p0, -hl], [p1, hl], [p0, hl]]:
			var pp: Vector2 = q[0]
			stt.set_normal(Vector3(pp.x, pp.y, 0.0))
			stt.add_vertex(Vector3(pp.x * r, pp.y * h, float(q[1])))
	var mi := MeshInstance3D.new()
	mi.mesh = stt.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
