extends RefCounted
## Nowe miejsca na pustych polach mapy: złomowisko, skatepark z murami pod graffiti, opuszczona stacja benzynowa,
## nocny bazar i szklarnie pod folią. Każde ma kolizje, światło po zmroku i skrytkę z gotówką (raz na zapis).
## Wszystkie współrzędne w planie miasta (jak w world.gd); wymiary w metrach mnoży się przez INV.

const Models = preload("res://scripts/models.gd")
const Cars = preload("res://scripts/cars.gd")
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
	W._pr(4, 154.0, 197.0, 202.0, 233.0)
	W._pr(3, 184.0, 146.0, 190.0, 197.0)
	W._pr(1, -4.5, -150.0, -1.5, -136.0)
	W._pr(1, -14.0, -147.0, 8.0, -143.5)
	W._pr(1, -58.0, 144.0, -31.0, 167.0)
	W._pr(1, -31.0, 151.5, -20.0, 154.5)
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
	_podworko(W)
	_obozowisko(W)
	_kebab(W)
	_blaszaki(W)
	_trawnik11(W)
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
	li.omni_attenuation = 1.7
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


## girlanda: kabel zwisający między punktami a, b (plan) na wysokości y (m) z zwisem sag, z żarówkami co kilka punktów
static func _garland(W, a: Vector2, b: Vector2, y: float, sag: float, n: int) -> void:
	var cable: Material = Models.mat("1c1c1e", 0.8)
	var prev := Vector3.ZERO
	for i in range(n + 1):
		var t := float(i) / float(n)
		var q := a.lerp(b, t)
		var pt := Vector3(q.x, W.hd(q.x, q.y) + y - sag * (1.0 - pow(2.0 * t - 1.0, 2.0)), q.y)
		if i > 0:
			var d := pt - prev
			var mid := (pt + prev) * 0.5
			var quat := Quaternion(Vector3.UP, d.normalized())
			Models.cyl(W.city, 0.012 * INV, 0.012 * INV, d.length(), mid, cable, quat.get_euler(), 4)
		if i > 0 and i < n and i % 2 == 0:
			Models.sphere(W.city, 0.08 * INV, pt - Vector3(0, 0.1, 0), W.lamp_mat, Vector3(1, 1, 1), false, 6)
		prev = pt


## krawężnik z klocków o równej długości (bez szpar na łączeniach): długość odcinka zaokrąglona do całkowitej liczby klocków
static func _curb_run(W, ax: float, az: float, bx: float, bz: float) -> void:
	var seg := 2.0 * INV
	var a := Vector2(ax, az)
	var b := Vector2(bx, bz)
	var n := maxi(1, int(round(a.distance_to(b) / seg)))
	W._curb(ax, az, a.x + (b.x - a.x) / a.distance_to(b) * seg * n, a.y + (b.y - a.y) / a.distance_to(b) * seg * n)


## słup z lampą (własny, bez reflektora z cieniem — te nad jezdnią obsługuje world._lamp)
static func _pole(W, x: float, z: float, dead := false, gain := 0.5, rng_m := 13.0) -> void:
	var m: Material = Models.mat("5a5d62", 0.6, 0.6)
	_box(W, x, z, Vector3(0.14, 5.2, 0.14), m, 0.0, 0.0, 0.0)
	_box(W, x, z, Vector3(0.5, 0.1, 0.22), m, 5.2)
	if not dead:
		_box(W, x, z, Vector3(0.26, 0.02, 0.1), W.lamp_mat, 5.17, 0.0, -1.0, false)
		_light(W, x, z, 5.8, Color(1.0, 0.72, 0.42), gain, rng_m)


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


## ze lśniącego auta robi wrak: matowa, zardzewiała blacha w kolorze lakieru, brudne szyby; wear 2 = bez kół i szyb, 3 = dodatkowo zgnieciony dach
static func _ruin(car: Node3D, color: String, wear: int) -> void:
	var c := Color.html("#" + color)
	var tint := c.lerp(Color(0.55, 0.34, 0.24), 0.4) * 1.6
	var body := Cars._find(car, "TintKaroseria") as MeshInstance3D
	if body != null:
		var m := Props.pbr("rusty_painted_metal", 0.4, tint).duplicate() as StandardMaterial3D
		m.metallic = 0.1
		m.roughness = 1.0
		m.clearcoat_enabled = false
		body.material_override = m
	var det := Cars._find(car, "Detale") as MeshInstance3D
	if det != null and det.mesh != null:
		for i in range(det.mesh.get_surface_count()):
			var sm := det.mesh.surface_get_material(i) as StandardMaterial3D
			if sm != null and sm.resource_name == "szyba":
				var dm := sm.duplicate() as StandardMaterial3D
				dm.albedo_color = Color(0.1, 0.11, 0.1, 1.0) if wear >= 2 else Color(0.2, 0.22, 0.2, 0.85)
				dm.roughness = 0.75
				dm.metallic = 0.0
				det.set_surface_override_material(i, dm)
	if wear >= 2:
		for i in range(1, 5):
			var w := Cars._find(car, "Kolo%d" % i)
			if w != null:
				w.visible = false
		car.position.y -= 0.2
	if wear >= 3:
		car.scale.y = 0.78


static func _wreck(W, x: float, z: float, ry: float, type: String, color: String, y := 0.0, tilt := Vector3.ZERO, wear := 1) -> Node3D:
	var car: Node3D = Models.car(type, color, false)
	_ruin(car, color, wear)
	car.position = Vector3(x, W.hd(x, z) + y + car.position.y, z)
	car.rotation = Vector3(tilt.x, ry, tilt.z)
	car.scale = Vector3(INV, car.scale.y, INV)
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
static func _quarter(W, x: float, z: float, ry: float, w: float, r: float) -> void:
	var qm: Node3D = Stations.model("skate_cwiartka")
	if qm != null:
		qm.position = Vector3(x, W.hd(x, z), z)
		qm.rotation.y = ry
		qm.scale = Vector3(INV * w / 4.4, r / 1.3, INV * r / 1.3)
		W.city.add_child(qm)
		Props.set_range(qm, 110.0)
	# kolizja: 4 schodki po łuku (wysokość z początku odcinka — nie ma niewidzialnej ściany nad pochyłością); rampa wznosi się w kierunku −z modelu
	var d := Vector2(-sin(ry), -cos(ry))
	var hw := w * 0.5
	var steps := 4
	for i in range(steps):
		var x0 := r * float(i) / float(steps)
		var x1 := r * float(i + 1) / float(steps)
		var hh := r - r * cos(asin(clampf(x0 / r, 0.0, 1.0)))
		if hh < 0.25:
			continue
		var mid := (x0 + x1) * 0.5
		var cx := x + d.x * mid * INV
		var cz := z + d.y * mid * INV
		var al := (x1 - x0) * 0.5
		var ex := (absf(d.x) * al + absf(d.y) * hw) * INV
		var ez := (absf(d.y) * al + absf(d.x) * hw) * INV
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
	# brama z szyldem (model z Blendera, make_zlom.py), patrzy na zewnątrz (na północ)
	var gm: Node3D = Stations.model("zlom_brama")
	if gm != null:
		Props.set_range(W._place(gm, c.x + 4.0, z0, PI), 150.0)
		for sx in [-2.1, 2.1]:
			W.add_col(c.x + 4.0 + (sx - 0.2) * INV, c.x + 4.0 + (sx + 0.2) * INV, z0 - 0.2 * INV, z0 + 0.2 * INV, 3.6)
			W.rects.pop_back()
	# biuro z dwóch kontenerów (model), drzwi na plac
	var o := _p(c, -9.0, -6.0)
	var bm: Node3D = Stations.model("zlom_biuro")
	if bm != null:
		Props.set_range(W._place(bm, o.x, o.y, PI, 1.4, 3.1, 2.9), 150.0)
	W._prop("metal_office_desk", o.x + 6.0, o.y, 0.0, 0.9, 0.0, false)
	W._prop("plastic_monobloc_chair_01", o.x + 8.6, o.y + 1.2, 2.4, 0.86, 0.0, false)
	W._prop("hand_truck", o.x + 7.5, o.y - 3.0, 0.7, 1.3, 0.0, false)
	# sprasowane kostki złomu (model)
	for e in [[12.0, -9.0, 0.12, 0.0], [13.5, -9.4, -0.3, 0.0], [12.8, -9.2, 0.5, 1.1]]:
		var kp := _p(c, float(e[0]), float(e[1]))
		var kmd: Node3D = Stations.model("zlom_kostka")
		if kmd != null:
			var kn: Node3D = W._place(kmd, kp.x, kp.y, float(e[2]), 0.62, 0.52, 1.2) if float(e[3]) == 0.0 else W._place(kmd, kp.x, kp.y, float(e[2]))
			kn.position.y += float(e[3])
			Props.set_range(kn, 110.0)
	# wraki: jeden na drugim, jeden przechylony na oponach, jeden bez kół w rogu
	_wreck(W, c.x + 2.0 * INV, c.y + 2.0 * INV, 0.35, "sedan", "6b3a2a", 0.0, Vector3.ZERO, 3)
	_wreck(W, c.x + 2.2 * INV, c.y + 2.0 * INV, 0.3, "hatch", "4a4f55", 1.15, Vector3(0.0, 0.0, 0.08))
	_wreck(W, c.x + 12.0 * INV, c.y + 5.0 * INV, -0.7, "kombi", "5a5a40", 0.0, Vector3(0.05, 0.0, -0.07))
	_wreck(W, c.x - 3.0 * INV, c.y + 9.0 * INV, 1.9, "maluch", "7a6a3a", 0.0, Vector3.ZERO, 2)
	_wreck(W, c.x + 15.0 * INV, c.y - 7.0 * INV, 0.1, "van", "4d5a64")
	_wreck(W, c.x - 6.0 * INV, c.y - 2.0 * INV, 2.0, "hatch", "5a4a3a", 0.0, Vector3(0.0, 0.0, 0.05))
	_wreck(W, c.x + 20.0 * INV, c.y + 3.0 * INV, 1.4, "sedan", "3f4a3a")
	_wreck(W, c.x + 20.5 * INV, c.y + 3.2 * INV, 1.5, "maluch", "7a3a2a", 1.15, Vector3(0.0, 0.0, -0.06))
	_wreck(W, c.x - 18.0 * INV, c.y - 8.0 * INV, 0.2, "kombi", "6a6a60", 0.0, Vector3(0.04, 0.0, 0.0), 2)
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
	# żuraw z magnesem (model) — widoczny z daleka
	var cr := _p(c, 6.0, -3.0)
	var zm: Node3D = Stations.model("zlom_zuraw")
	if zm != null:
		Props.set_range(W._place(zm, cr.x, cr.y, 0.0, 0.5, 0.5, 2.9), 200.0)
	# ognisko w beczce i reflektor nad biurem: łuna po zmroku
	var fb := _p(c, 8.5, -6.0)
	_cyl(W, fb.x, fb.y, 0.32, 0.8, Props.pbr("rusty_painted_metal", 0.3, Color(0.7, 0.55, 0.45)), 0.0, true)
	Fx.fire(W, Vector3(fb.x * SC, W.hd(fb.x, fb.y) + 0.85, fb.y * SC), 0.22, W.lamps)
	# złomowisko nocą: dwa słupy z mocniejszym reflektorem, żeby w ogóle było coś widać
	_pole(W, c.x - 4.0, z0 + 5.0, false, 1.5, 19.0)
	_pole(W, c.x + 14.0, c.y + 12.0, false, 1.5, 19.0)
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
	# mur z graffiti (model), trzy segmenty; za nim ćwierćrury
	var wz := c.y - 13.0
	var mm: Node3D
	for i in range(3):
		var wx := c.x - 10.0 + float(i) * 10.0
		mm = Stations.model("skate_mur")
		if mm != null:
			Props.set_range(W._place(mm, wx, wz, 0.0, 2.8, 0.25, 2.7), 130.0)
		for dx in [-1.4, 1.4]:
			Details.decal(W, Details.pick("piece") if (i + int(dx)) % 2 == 0 else Details.pick("slogan"), Vector3(wx * SC + dx, W.hd(wx, wz) + 1.3, wz * SC + 0.17), 0.0, 2.2, 1.0, 60.0)
		if i == 1:
			Details.decal(W, Details.pick("tag"), Vector3(wx * SC + 0.1, W.hd(wx, wz) + 0.6, wz * SC + 0.17), 0.0, 1.2, 1.0, 40.0)
	_quarter(W, c.x - 7.0, wz + 2.0 * INV, 0.0, 4.4, 1.3)
	_quarter(W, c.x + 2.0, wz + 2.0 * INV, 0.0, 4.4, 1.3)
	_quarter(W, c.x + 15.0 - 1.3 * INV, c.y - 4.0, -PI / 2.0, 4.4, 1.3)
	_quarter(W, c.x + 15.0 - 1.3 * INV, c.y + 3.0, -PI / 2.0, 4.4, 1.3)
	var fb: Node3D = Stations.model("skate_funbox")
	if fb != null:
		Props.set_range(W._place(fb, c.x - 3.0, c.y + 2.0, 0.0, 1.8, 0.95, 0.55), 110.0)
	var rl: Node3D = Stations.model("skate_rail")
	if rl != null:
		Props.set_range(W._place(rl, c.x + 4.0, c.y - 3.0, 0.0, 2.5, 0.1, 0.65), 110.0)
	var rl2: Node3D = Stations.model("skate_rail")
	if rl2 != null:
		Props.set_range(W._place(rl2, c.x - 10.0, c.y + 3.0, 0.0, 2.5, 0.1, 0.65), 110.0)
	# wokół: ławki, kosz, kolorowe pachołki, deskorolka, puszki po farbie, boombox na murku
	W._bench(c.x - 1.0, c.y + 11.0, PI)
	W._bench(c.x + 8.0, c.y + 11.0, PI)
	W._bin(c.x + 14.0, c.y + 10.0, 0.0)
	_scatter(W, c, [["trafficcone_1", -6.0, 0.0, 0.0, 0.6], ["trafficcone_2", -5.0, 0.8, 0.5, 0.6], ["spray_paint_bottles", 3.0, -7.4, 0.4, 0.22], ["can_rusted", 9.0, 5.0, 0.3, 0.13],
		["boombox", -3.0, 2.0, 0.6, 0.3, 0.5], ["dirty_football", 6.0, 8.5, 0.0, 0.22], ["trashbag", 15.0, 4.0, 0.9, 0.5], ["plastic_bottle_gallon", 11.0, 8.0, 0.0, 0.3]])
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
	# dwa rzędy stoisk po cztery (modele, cztery warianty towaru), szeroka alejka w środku
	var k := 0
	for row in [-1, 1]:
		for i in range(4):
			var sx: float = c.x - 13.5 + float(i) * 8.6 + (W.rng.randf() - 0.5) * 0.8
			var sz: float = c.y + float(row) * 8.0
			var sm: Node3D = Stations.model("bazar_stoisko_%d" % ((k + (3 if row > 0 else 0)) % 4))
			if sm != null:
				var ry := 0.0 if row < 0 else PI
				Props.set_range(W._place(sm, sx, sz, ry, 1.8, 0.7, 0.9), 130.0)
			k += 1
	# girlanda żarówek nad alejką: trzy sznury na słupach, żarówki świecą wspólnym materiałem latarni
	for gz in [-3.0, 3.0]:
		var px0 := c.x - 17.0
		var px1 := c.x + 17.0
		for pxx in [px0, px1]:
			_box(W, pxx, c.y + gz * INV, Vector3(0.12, 3.6, 0.12), pole, 0.0, 0.0, 0.0)
		_garland(W, Vector2(px0, c.y + gz * INV), Vector2(px1, c.y + gz * INV), 3.3, 0.5, 22)
	_light(W, c.x - 8.0, c.y, 3.1, Color(1.0, 0.78, 0.5), 0.55, 13.0)
	_light(W, c.x + 8.0, c.y, 3.1, Color(1.0, 0.78, 0.5), 0.55, 13.0)
	var bg: Node3D = Stations.model("bazar_brama")
	if bg != null:
		Props.set_range(W._place(bg, c.x, c.y - 16.0, PI), 150.0)
		for sx in [-3.4, 3.4]:
			W.add_col(c.x + (sx - 0.15) * INV, c.x + (sx + 0.15) * INV, c.y - 16.0 - 0.15 * INV, c.y - 16.0 + 0.15 * INV, 3.0)
			W.rects.pop_back()
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
	var soil: Material = Models.mat("3a2a1e", 1.0)
	# trzy tunele foliowe równolegle do osi z; środkiem przebiega ścieżka od bramki
	var i := 0
	for tx in [-8.0, 0.0, 8.0]:
		var p := _p(c, tx, 0.0)
		var ln := 11.0
		var tm: Node3D = Stations.model("szkl_tunel")
		if tm != null:
			tm.position = Vector3(p.x, W.hd(p.x, p.y), p.y)
			tm.scale = Vector3(INV, 1.0, INV)
			W.city.add_child(tm)
			Props.set_range(tm, 130.0)
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
	_scatter(W, c, [["barrel_01", -13.0, -15.0, 0.0, 0.9], ["barrel_01", -12.0, -15.2, 0.6, 0.9], ["wooden_crate_02", -3.0, -14.0, 0.4, 0.42], ["plastic_bottle_gallon", -4.4, -13.0, 0.6, 0.3],
		["cement_bag", 5.0, -14.5, 0.3, 0.2], ["cement_bag", 6.0, -14.0, 1.0, 0.2], ["hand_truck", 9.0, -9.0, 2.2, 1.3], ["plastic_crate_01", 13.0, 12.0, 0.4, 0.3], ["plastic_crate_01", 13.6, 12.6, 1.1, 0.3]])
	_light(W, c.x + 11.0 * INV, c.y - 11.0 * INV, 2.6, Color(0.95, 0.9, 0.6), 0.4, 8.0, true)
	_stash(W, "szklarnie_termos", c.x + 4.0 * INV, c.y - 14.0 * INV, "Zajrzyj do termosu za workami", 95, "W termosie, zamiast herbaty, zwitek banknotów od odbiorców Mietka", 0.3)
	_dump(W, "poi_szklarnie_kompost", c.x - 9.0 * INV, c.y + 14.0 * INV, "Przekop kompost", "bin")
	_box(W, c.x - 9.0 * INV, c.y + 14.0 * INV, Vector3(2.0, 0.8, 1.4), soil, 0.0, 0.2, 0.0)


# ---------------------------------------------------------------- małe sceny życia na pustych polach
## Podwórko z trzepakami i praniem na zachodnim polu: piaskownica, huśtawka, ławki, kosz.
static func _podworko(W) -> void:
	var c := Vector2(-132.0, -121.0)
	var tr1: Node3D = Props.trzepak()
	Props.set_range(W._place(tr1, c.x - 7.0, c.y - 5.0, 0.0, 1.3, 0.12, 2.0), 110.0)
	var tr2: Node3D = Props.trzepak()
	Props.set_range(W._place(tr2, c.x + 5.0, c.y - 5.0, 0.0, 1.3, 0.12, 2.0), 110.0)
	# pranie na sznurze między trzepakami (modele ubrań z Blendera)
	var cl := ["ciuch_koszula", "ciuch_spodnie", "ciuch_bluza", "ciuch_spodnie", "ciuch_koszula"]
	for i in range(cl.size()):
		var m: Node3D = Stations.model(String(cl[i]))
		if m == null:
			continue
		var px := c.x - 4.0 + float(i) * 2.3
		m.position = Vector3(px, W.hd(px, c.y - 5.0) + 1.9, c.y - 5.0)
		m.rotation.y = 0.2 * float(i)
		m.scale = Vector3(INV, 1.0, INV)
		W.city.add_child(m)
		Props.set_range(m, 55.0)
	var pk: Node3D = Stations.model("plac_piaskownica")
	if pk != null:
		Props.set_range(W._place(pk, c.x + 8.0, c.y + 6.0, 0.1, 1.55, 1.55, 0.3), 95.0)
	Props.set_range(W._place(Props.swing(), c.x - 8.0, c.y + 7.0, 0.0, 1.6, 0.9, 2.4), 110.0)
	W._bench(c.x - 1.0, c.y + 11.0, PI)
	W._bench(c.x + 3.0, c.y - 1.0, 0.0)
	W._bin(c.x + 12.0, c.y + 1.0, 0.0)
	_scatter(W, c, [["dirty_football", 2.0, 4.0, 0.0, 0.22], ["trashbag", 9.0, -4.0, 0.7, 0.5], ["plastic_crate_01", -3.0, -2.0, 0.4, 0.3], ["can_rusted", 4.0, 8.0, 0.2, 0.13]])
	_pole(W, c.x + 12.0, c.y + 6.0)
	_stash(W, "podworko_trzepak", c.x + 5.0 + 1.4 * INV, c.y - 5.0 + 0.5 * INV, "Zajrzyj za trzepak", 35, "Za trzepakiem ktoś schował słoik z drobnymi", 0.2)


## Obozowisko w kącie południowo-zachodnim: wiata, ognisko, legowiska, skrzynki.
static func _obozowisko(W) -> void:
	var c := Vector2(-180.0, 122.0)
	var wm: Node3D = Stations.model("ul_wiata")
	if wm != null:
		Props.set_range(W._place(wm, c.x, c.y, 0.3, 2.4, 1.2, 2.4), 130.0)
	for e in [["bezd_ognisko", 5.0, 3.0, 0.4, 0.55, 0.55, 0.4], ["bezd_legowisko", -4.0, 4.5, 0.6, 0.0, 0.0, 0.0], ["bezd_wozek", 8.5, -1.0, 2.2, 0.3, 0.45, 1.0]]:
		var m: Node3D = Stations.model(String(e[0]))
		if m != null:
			var p := _p(c, float(e[1]), float(e[2]))
			Props.set_range(W._place(m, p.x, p.y, float(e[3]), float(e[4]), float(e[5]), float(e[6])), 95.0)
	var fp := _p(c, 5.0, 3.0)
	Fx.fire(W, Vector3(fp.x * SC, W.hd(fp.x, fp.y) + 0.12, fp.y * SC), 0.28, W.lamps)
	_scatter(W, c, [["wooden_crate_02", 3.0, 5.5, 0.3, 0.42], ["wooden_crate_02", 7.0, 5.0, 1.1, 0.42], ["pallet", 2.0, 0.0, 0.6, 0.16], ["trashbag", -7.0, 0.5, 0.2, 0.5],
		["trashbag_1", -6.0, 2.0, 1.0, 0.6], ["old_tyre", 9.0, 4.0, 0.2, 0.16], ["can_rusted", 4.5, 4.5, 0.0, 0.13], ["barrel_01", -2.0, -3.5, 0.5, 0.9]])
	_stash(W, "oboz_zawiniatko", c.x - 5.5 * INV, c.y + 4.0 * INV, "Zajrzyj pod legowisko", 40, "Pod legowiskiem leżało zawiniątko z kilkoma banknotami", 0.2)


## Budka z kebabem i stragan przy pętli autobusowej: wieczorne życie obok pustego pasa południowego.
static func _kebab(W) -> void:
	var c := Vector2(-46.0, 153.0)
	# utwardzony plac z krawężnikiem (płyty chodnikowe w mapie nawierzchni, paint) i ścieżka do chodnika pętli
	_curb_run(W, -59.0, 143.6, -30.0, 143.6)
	_curb_run(W, -59.0, 167.4, -30.0, 167.4)
	_curb_run(W, -58.4, 142.8, -58.4, 168.2)
	_curb_run(W, -30.6, 142.8, -30.6, 150.8)
	_curb_run(W, -30.6, 155.2, -30.6, 168.2)
	var km: Node3D = Stations.model("kebab_budka")
	if km != null:
		var lens := Stations._find(km, "Swiatlo") as MeshInstance3D
		if lens != null:
			lens.material_override = W.lamp_mat
			lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Props.set_range(W._place(km, c.x, c.y, PI / 2.0, 1.2, 1.8, 2.5), 140.0)
	for tz in [-6.0, 6.0]:
		W._prop("painted_wooden_table", c.x + 10.0, c.y + tz, 0.0, 0.75, 1.0)
		W._prop("plastic_monobloc_chair_01", c.x + 10.0 - 1.4 * INV, c.y + tz, 1.6, 0.86, 0.0, false)
		W._prop("plastic_monobloc_chair_01", c.x + 10.0 + 1.4 * INV, c.y + tz, -1.6, 0.86, 0.0, false)
	var sm: Node3D = Stations.model("bazar_stoisko_2")
	if sm != null:
		Props.set_range(W._place(sm, c.x - 1.0, c.y + 11.5, 0.0, 1.8, 0.7, 0.9), 130.0)
	W._bin(c.x + 6.0, c.y + 11.0, 0.0)
	# menu na stojaku przy ladzie
	var post: Node3D = Stations.model("ul_slupek")
	if post != null:
		Props.set_range(W._place(post, c.x + 4.5, c.y - 3.5, 0.0, 0.15, 0.15, 1.2), 70.0)
	W._sign("MENU\nkebab 22 zł\nzapiekanka 14 zł", Vector3(c.x + 4.5, W.hd(c.x + 4.5, c.y - 3.5) + 1.3, c.y - 3.5 + 0.2), Color(0.95, 0.9, 0.75), 30, PI / 2.0, 0.004, 6)
	_scatter(W, c, [["cardboard_box_01", -5.0, 4.0, 0.4, 0.34], ["trashbag", -5.0, -5.0, 0.8, 0.5], ["can_rusted", 9.0, 0.0, 0.0, 0.13], ["plastic_crate_01", -4.0, -4.0, 0.3, 0.3]])
	# girlanda żarówek nad stolikami, na dwóch słupkach
	for gz in [-9.0, 9.0]:
		_pole(W, c.x + 10.0, c.y + gz, true)
	_garland(W, Vector2(c.x + 10.0, c.y - 9.0), Vector2(c.x + 10.0, c.y + 9.0), 4.9, 0.5, 18)
	_light(W, c.x + 4.0 * INV, c.y, 2.8, Color(1.0, 0.55, 0.35), 0.6, 10.0)
	_light(W, c.x + 4.0 * INV + 8.0, c.y, 3.0, Color(1.0, 0.78, 0.5), 0.45, 9.0)
	_dump(W, "poi_kebab_kosz", c.x + 6.0, c.y + 11.0, "Pogrzeb w koszu przy kebabie", "bin")
	_stash(W, "kebab_lada", c.x + 1.5 * INV, c.y - 2.0 * INV, "Zajrzyj za budkę", 50, "Za budką leżała reklamówka z utargiem sprzed zamknięcia", 0.2)


## Rząd blaszaków za stacją: żwirowy plac, polna droga od stacji, dwa rzędy garaży, wraki, beczki i lampa.
static func _blaszaki(W) -> void:
	var c := Vector2(176.0, 214.0)
	for row in [0, 1]:
		for i in range(3):
			var x := 163.0 + float(i) * 7.0
			var z := 207.0 if row == 0 else 225.0
			var bm: Node3D = Stations.model("blaszak_%d" % ((i + row * 2) % 3))
			if bm != null:
				Props.set_range(W._place(bm, x, z, 0.0 if row == 0 else PI, 1.45, 2.7, 2.6), 140.0)
	_wreck(W, 190.0, 214.0, 1.6, "sedan", "4a3a30")
	_wreck(W, 195.0, 224.0, 0.4, "hatch", "5a5a58", 0.0, Vector3(0.0, 0.0, 0.05))
	_wreck(W, 195.5, 224.2, 0.5, "maluch", "6a3a2a", 1.15, Vector3(0.0, 0.0, -0.06))
	W._prop("covered_car", 190.0, 203.0, 0.2, 0.0, 0.0)
	_scatter(W, c, [["barrel_01", 8.0, 2.0, 0.0, 0.9], ["barrel_01", 8.9, 2.4, 1.0, 0.9], ["old_tyre", 9.5, -4.0, 0.2, 0.16], ["old_tyre", 10.2, -3.4, 0.9, 0.16, 0.16],
		["wheels_stack", 12.0, 8.0, 0.4, 0.9], ["pallet", -6.0, 1.0, 0.5, 0.16], ["trashbag", 6.0, -1.0, 0.9, 0.5], ["can_rusted", 3.0, 3.0, 0.1, 0.13], ["plastic_crate_01", -2.0, 2.0, 0.3, 0.3]])
	_pole(W, c.x + 6.0, c.y - 6.0)
	_pole(W, c.x - 14.0, c.y + 14.0)
	_light(W, c.x, c.y + 2.0, 3.4, Color(1.0, 0.72, 0.42), 0.4, 11.0, true)
	_dump(W, "poi_blaszaki_wrak", 190.0, 214.0 + 3.4 * INV, "Przeszukaj wrak przy blaszakach")
	_stash(W, "blaszak_13", 170.0, 207.0 + 3.0 * INV, "Zajrzyj przez szparę w blaszaku nr 13", 85, "Przez szparę wyciągnąłeś zwiniętą kopertę z gotówką", 0.9)


## Trawnik między blokami 9 i 11: alejka z kostki od chodnika, trzepak z suszarką, piaskownica, huśtawka, ławki, kosze i latarnia.
static func _trawnik11(W) -> void:
	var c := Vector2(-3.0, -143.0)
	var tr: Node3D = Props.trzepak()
	Props.set_range(W._place(tr, c.x - 8.0, c.y - 3.0, 0.0, 1.3, 0.12, 2.0), 110.0)
	var su: Node3D = Stations.model("pod_suszarka")
	if su != null:
		Props.set_range(W._place(su, c.x - 8.5, c.y - 8.0, 0.4, 0.9, 0.9, 1.6), 80.0)
	var pk: Node3D = Stations.model("plac_piaskownica")
	if pk != null:
		Props.set_range(W._place(pk, c.x + 7.0, c.y - 6.0, 0.1, 1.55, 1.55, 0.3), 95.0)
	Props.set_range(W._place(Props.swing(), c.x + 7.0, c.y + 1.0, PI, 1.6, 0.9, 2.4), 110.0)
	W._bench(c.x - 6.0, c.y + 3.0, PI)
	W._bench(c.x + 3.5, c.y + 2.5, PI)
	W._bench(c.x - 3.5, c.y - 5.5, 0.0)
	W._bin(c.x - 5.0, c.y + 6.0, 0.0)
	W._bin(c.x + 3.5, c.y - 8.0, 0.0)
	_pole(W, c.x + 1.5, c.y - 1.0)
	_scatter(W, c, [["dirty_football", 4.0, -2.0, 0.0, 0.22], ["trashbag", -10.0, 4.0, 0.6, 0.5], ["can_rusted", 2.0, 1.0, 0.3, 0.13], ["plastic_crate_01", -6.0, -9.0, 0.4, 0.3]])
	_stash(W, "trawnik_suszarka", c.x - 8.5 + 1.2 * INV, c.y - 8.0, "Zajrzyj pod suszarkę", 30, "Pod suszarką ktoś zgubił zwitek drobnych", 0.2)
