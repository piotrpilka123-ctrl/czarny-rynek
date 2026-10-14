extends RefCounted
const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")
const Interior = preload("res://scripts/interior.gd")
## Ściany działowe, futryny, progi, listwy i podłogi pomieszczeń WEWNĄTRZ jednego wnętrza (mieszkanie, lokale).
## Współrzędne lokalne: x względem środka wnętrza (cx), z jak w pokoju. W — świat (world.gd): kolizje przez W.add_col.

const THICK := 0.1       # grubość ściany działowej
const DOOR_H := 2.05     # wysokość otworu drzwiowego
const TRIM := 0.05       # szerokość obramowania futryny


## ściana działowa od (x0,z0) do (x1,z1) — pionowa albo pozioma. gaps: [[od, do], …] w metrach wzdłuż ściany (otwory drzwiowe)
static func wall(W: Node3D, g: Node3D, cx: float, a: Vector2, b: Vector2, h: float, mat: Material, gaps: Array = [], thick := THICK, base_color := "cfc8b6") -> void:
	var along_z := absf(a.x - b.x) < 0.001
	var lo := minf(a.y, b.y) if along_z else minf(a.x, b.x)
	var hi := maxf(a.y, b.y) if along_z else maxf(a.x, b.x)
	var fixed := a.x if along_z else a.y
	var segs: Array = []
	var cur := lo
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
	for gp in sorted:
		if float(gp[0]) > cur + 0.001:
			segs.append([cur, float(gp[0])])
		cur = float(gp[1])
	if hi > cur + 0.001:
		segs.append([cur, hi])
	for s in segs:
		_slab(W, g, cx, along_z, fixed, float(s[0]), float(s[1]), 0.0, h, thick, mat, true)
		_baseboard(g, cx, along_z, fixed, float(s[0]), float(s[1]), thick, base_color)
	for gp in sorted:
		var g0 := float(gp[0])
		var g1 := float(gp[1])
		# nadproże nad otworem, futryna z trzech listew, próg
		_slab(W, g, cx, along_z, fixed, g0, g1, DOOR_H, h, thick, mat, false)
		_frame(g, cx, along_z, fixed, g0, g1, thick)
		_threshold(g, cx, along_z, fixed, g0, g1, thick)


static func _slab(W: Node3D, g: Node3D, cx: float, along_z: bool, fixed: float, s0: float, s1: float, y0: float, y1: float, thick: float, mat: Material, collide: bool) -> void:
	var l := s1 - s0
	var hh := y1 - y0
	var mid := (s0 + s1) * 0.5
	if along_z:
		Models.box(g, Vector3(thick, hh, l), Vector3(cx + fixed, y0 + hh * 0.5, mid), mat)
		if collide:
			W.add_col(cx + fixed - thick * 0.5, cx + fixed + thick * 0.5, s0, s1, y1, true, -1.0)
			W.rects.pop_back()
	else:
		Models.box(g, Vector3(l, hh, thick), Vector3(cx + mid, y0 + hh * 0.5, fixed), mat)
		if collide:
			W.add_col(cx + s0, cx + s1, fixed - thick * 0.5, fixed + thick * 0.5, y1, true, -1.0)
			W.rects.pop_back()


static func _baseboard(g: Node3D, cx: float, along_z: bool, fixed: float, s0: float, s1: float, thick: float, color: String) -> void:
	var m := Models.mat(color, 0.7)
	var l := s1 - s0
	var mid := (s0 + s1) * 0.5
	for side in [-1.0, 1.0]:
		var off: float = side * (thick * 0.5 + 0.0125)
		if along_z:
			Models.box(g, Vector3(0.025, 0.09, l), Vector3(cx + fixed + off, 0.045, mid), m, Vector3.ZERO, false)
		else:
			Models.box(g, Vector3(l, 0.09, 0.025), Vector3(cx + mid, 0.045, fixed + off), m, Vector3.ZERO, false)


## futryna: dwa ościeża i nadproże z listew, wystające z obu stron ściany
static func _frame(g: Node3D, cx: float, along_z: bool, fixed: float, g0: float, g1: float, thick: float) -> void:
	var m := Models.mat("e9e5da", 0.55)
	var dep := thick + 0.04
	for e in [g0 + TRIM * 0.5, g1 - TRIM * 0.5]:
		if along_z:
			Models.box(g, Vector3(dep, DOOR_H, TRIM), Vector3(cx + fixed, DOOR_H * 0.5, e), m, Vector3.ZERO, false)
		else:
			Models.box(g, Vector3(TRIM, DOOR_H, dep), Vector3(cx + e, DOOR_H * 0.5, fixed), m, Vector3.ZERO, false)
	var mid := (g0 + g1) * 0.5
	var l := g1 - g0
	if along_z:
		Models.box(g, Vector3(dep, TRIM, l), Vector3(cx + fixed, DOOR_H - TRIM * 0.5, mid), m, Vector3.ZERO, false)
	else:
		Models.box(g, Vector3(l, TRIM, dep), Vector3(cx + mid, DOOR_H - TRIM * 0.5, fixed), m, Vector3.ZERO, false)


## próg: niska listwa w poprzek otworu — tylko wizualna, bez kolizji (gracz przechodzi bez podskoku)
static func _threshold(g: Node3D, cx: float, along_z: bool, fixed: float, g0: float, g1: float, thick: float) -> void:
	var m := Models.mat("8a7a62", 0.45, 0.35)
	var l := g1 - g0 - TRIM * 2.0
	var mid := (g0 + g1) * 0.5
	if along_z:
		Models.box(g, Vector3(thick + 0.02, 0.02, l), Vector3(cx + fixed, 0.01, mid), m, Vector3.ZERO, false)
	else:
		Models.box(g, Vector3(l, 0.02, thick + 0.02), Vector3(cx + mid, 0.01, fixed), m, Vector3.ZERO, false)


## podłoga jednego pomieszczenia: cienka nakładka na wspólnej płycie
static func floor_patch(g: Node3D, cx: float, x0: float, z0: float, x1: float, z1: float, mat: Material, lift := 0.0) -> void:
	Models.box(g, Vector3(x1 - x0, 0.012, z1 - z0), Vector3(cx + (x0 + x1) * 0.5, 0.004 + lift, (z0 + z1) * 0.5), mat, Vector3.ZERO, false)


## bryła z kolizją (urządzenia łazienkowe itp.)
static func solid(W: Node3D, cx: float, x0: float, x1: float, z0: float, z1: float, h: float) -> void:
	W.add_col(cx + x0, cx + x1, z0, z1, h, true, -1.0)
	W.rects.pop_back()


static var _tile_cache := {}


## kafle z fugą: procedurowa tekstura 2×2 pola, w świecie jedno pole = `cell` m
static func tile_mat(c: Color, cell := 0.25, grout := Color(0.62, 0.62, 0.6)) -> StandardMaterial3D:
	var key := "%s|%.2f" % [c.to_html(), cell]
	if _tile_cache.has(key):
		return _tile_cache[key]
	var img := Image.create(128, 128, true, Image.FORMAT_RGB8)
	img.fill(c)
	for i in range(128):
		for t in [0, 1, 63, 64, 127]:
			img.set_pixel(i, t, grout)
			img.set_pixel(t, i, grout)
	for i in range(0, 128, 1):
		var n := 0.97 + 0.03 * sin(float(i) * 1.7)
		for j in range(0, 128, 9):
			var px := img.get_pixel(i, j)
			img.set_pixel(i, j, px * n if px != grout else px)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.35
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * (0.5 / cell)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_tile_cache[key] = m
	return m


## kafle na ścianie: pas od podłogi do 1,6 m (kolor jak fuga, reszta ściany zostaje tynkiem)
static func tiles(g: Node3D, cx: float, a: Vector2, b: Vector2, normal: Vector2, mat: Material, h := 1.6) -> void:
	var l := a.distance_to(b)
	var mid := (a + b) * 0.5 + normal * 0.024
	if absf(normal.x) > 0.5:
		Models.box(g, Vector3(0.012, h, l), Vector3(cx + mid.x, h * 0.5, mid.y), mat, Vector3.ZERO, false)
	else:
		Models.box(g, Vector3(l, h, 0.012), Vector3(cx + mid.x, h * 0.5, mid.y), mat, Vector3.ZERO, false)


## KAWALERKA: przedpokój, aneks kuchenny, łazienka i salon wydzielone ścianami działowymi (układ w lokalnych współrzędnych pokoju)
const HALL := [-1.3, 0.7, 2.05, 2.8]       # x0, z0, x1, z1
const KITCHEN := [2.05, -2.8, 3.6, 0.2]
const BATH := [2.05, 0.2, 3.6, 2.8]

static func safe_flat(W: Node3D, g: Node3D, cx: float, w: float, d: float, h: float) -> void:
	var plaster := Props.pbr("beige_wall_001", 0.45, Color(1.3, 1.28, 1.2))
	var tile_f := tile_mat(Color(0.86, 0.9, 0.92), 0.25)
	# ściany działowe
	wall(W, g, cx, Vector2(2.05, -2.8), Vector2(2.05, 2.8), h, plaster, [[-1.95, -0.95], [1.4, 2.4]])    # kuchnia | łazienka od reszty
	wall(W, g, cx, Vector2(2.05, 0.2), Vector2(3.6, 0.2), h, plaster)                    # kuchnia | łazienka
	wall(W, g, cx, Vector2(-1.3, 0.7), Vector2(2.05, 0.7), h, plaster, [[-0.5, 0.5]])                      # przedpokój od pokoju
	wall(W, g, cx, Vector2(-1.3, 0.7), Vector2(-1.3, 2.8), h, plaster, [[1.0, 2.0]])                       # przedpokój od salonu
	# podłogi pomieszczeń
	floor_patch(g, cx, HALL[0], HALL[1], HALL[2], HALL[3], tile_mat(Color(0.66, 0.4, 0.3), 0.3, Color(0.4, 0.3, 0.26)))
	floor_patch(g, cx, KITCHEN[0], KITCHEN[1], KITCHEN[2], KITCHEN[3], tile_mat(Color(0.84, 0.8, 0.68), 0.3, Color(0.55, 0.52, 0.45)))
	floor_patch(g, cx, BATH[0], BATH[1], BATH[2], BATH[3], tile_f, 0.001)
	# kafle w łazience (od wewnątrz) i nad blatem kuchni
	tiles(g, cx, Vector2(2.1, 0.25), Vector2(3.6, 0.25), Vector2(0, 1), tile_f)
	tiles(g, cx, Vector2(3.6, 0.2), Vector2(3.6, 2.8), Vector2(-1, 0), tile_f)
	tiles(g, cx, Vector2(2.1, 2.4), Vector2(2.1, 2.8), Vector2(1, 0), tile_f)
	tiles(g, cx, Vector2(2.1, 0.25), Vector2(2.1, 1.4), Vector2(1, 0), tile_f)
	tiles(g, cx, Vector2(2.05, 2.8), Vector2(3.6, 2.8), Vector2(0, -1), tile_f)
	# listwy przypodłogowe wzdłuż zewnętrznych ścian pomieszczeń (kuchnia, łazienka)
	# łazienka: sprzęty
	var cer := Models.mat("e9ece8", 0.18, 0.0)
	var chrome := Models.mat("b8bcc0", 0.2, 0.9)
	# prysznic w północnym rogu: brodzik, kabina z zasłonką, słuchawka
	Models.box(g, Vector3(1.4, 0.07, 0.8), Vector3(cx + 2.9, 0.035, 0.66), cer)
	Models.box(g, Vector3(0.7, 0.012, 0.7), Vector3(cx + 3.1, 0.074, 0.66), Models.mat("c9ced0", 0.3, 0.2), Vector3.ZERO, false)
	Models.cyl(g, 0.012, 0.012, 1.25, Vector3(cx + 3.45, 1.35, 0.3), chrome, Vector3.ZERO, 6)
	Models.cyl(g, 0.07, 0.07, 0.015, Vector3(cx + 3.38, 1.98, 0.32), chrome, Vector3(0.4, 0, 0), 10)
	Models.box(g, Vector3(0.012, 1.9, 0.8), Vector3(cx + 2.18, 1.0, 0.66), Models.mat("9ab8c8", 0.4, 0.0, 0.0, 0.35), Vector3.ZERO, false)
	Models.box(g, Vector3(0.7, 1.85, 0.02), Vector3(cx + 2.62, 1.0, 1.06), Models.mat("a9c6d4", 0.7, 0.0, 0.0, 0.55), Vector3(0, 0.08, 0), false)
	Models.cyl(g, 0.012, 0.012, 1.4, Vector3(cx + 2.9, 1.95, 1.06), chrome, Vector3(0, 0, PI / 2.0), 6)
	# sedes: zbiornik przy wschodniej ścianie, miska, deska
	Models.box(g, Vector3(0.2, 0.4, 0.38), Vector3(cx + 3.48, 0.68, 1.3), cer)
	Models.box(g, Vector3(0.46, 0.4, 0.36), Vector3(cx + 3.2, 0.2, 1.3), cer)
	Models.box(g, Vector3(0.42, 0.03, 0.36), Vector3(cx + 3.2, 0.42, 1.3), Models.mat("f1f2ee", 0.25), Vector3.ZERO, false)
	Models.cyl(g, 0.02, 0.02, 0.02, Vector3(cx + 3.48, 0.89, 1.3), chrome, Vector3.ZERO, 8)
	solid(W, cx, 2.97, 3.58, 1.1, 1.5, 0.85)
	# umywalka na wschodniej ścianie, szafka i lustro
	Models.box(g, Vector3(0.4, 0.14, 0.5), Vector3(cx + 3.38, 0.82, 2.35), cer)
	Models.box(g, Vector3(0.36, 0.66, 0.4), Vector3(cx + 3.4, 0.4, 2.35), Models.mat("d8d4c8", 0.6), Vector3.ZERO, false)
	Models.cyl(g, 0.012, 0.012, 0.12, Vector3(cx + 3.52, 0.95, 2.35), chrome, Vector3.ZERO, 6)
	Models.box(g, Vector3(0.02, 0.62, 0.5), Vector3(cx + 3.59, 1.5, 2.35), Models.mat("b4c6ce", 0.1, 0.1), Vector3.ZERO, false)
	solid(W, cx, 3.18, 3.58, 2.08, 2.62, 0.95)
	# światła pomieszczeń
	var hl: OmniLight3D = W._room_light(g, cx + 0.45, 1.75, h, 0.9, Color(1.0, 0.85, 0.62), 4.2)
	hl.shadow_enabled = false
	hl.name = "HallLight"
	Interior.ceiling_lamp(g, Vector3(cx + 0.45, h, 1.75), "bulb")
	var kl: OmniLight3D = W._room_light(g, cx + 2.9, -1.3, h, 1.0, Color(0.92, 0.96, 1.0), 3.0)
	kl.shadow_enabled = false
	kl.name = "KitchenLight"
	Interior.ceiling_lamp(g, Vector3(cx + 2.9, h, -1.3), "tube", Color(0.92, 0.96, 1.0))
	var bl: OmniLight3D = W._room_light(g, cx + 2.9, 1.5, h, 0.9, Color(0.95, 0.98, 1.0), 2.6)
	bl.shadow_enabled = false
	bl.name = "BathLight"
	Interior.ceiling_lamp(g, Vector3(cx + 2.9, h, 1.5), "bulb", Color(0.95, 0.98, 1.0))
	# okno kuchenne
	var kw: Dictionary = Interior.window(g, Vector3(cx + 2.95, 1.5, -d * 0.5), 0.9, 1.0, "n", "sheer", false)
	kw.light.shadow_enabled = false
	W.windows.append(kw)
