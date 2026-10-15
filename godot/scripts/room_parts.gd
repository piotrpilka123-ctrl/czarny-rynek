extends RefCounted
const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")
const Interior = preload("res://scripts/interior.gd")
const Stations = preload("res://scripts/stations.gd")
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
	var m := Props.pbr("old_wood_floor", 1.6, Color(1.45, 1.38, 1.25))
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
	var m := Props.pbr("old_wood_floor", 1.6, Color(1.5, 1.4, 1.25))
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
	var m := Props.pbr("old_wood_floor", 1.5, Color(0.85, 0.75, 0.65))
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


static func _fixture(g: Node3D, name: String, at: Vector3, ry: float) -> void:
	var n: Node3D = Stations.model(name)
	if n == null:
		return
	n.position = at
	n.rotation.y = ry
	g.add_child(n)


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
	var tile_f := Props.pbr("plytki_biale", 1.0)
	# ściany działowe
	wall(W, g, cx, Vector2(2.05, -2.8), Vector2(2.05, 2.8), h, plaster, [[-1.95, -0.95], [1.4, 2.4]])    # kuchnia | łazienka od reszty
	wall(W, g, cx, Vector2(2.05, 0.2), Vector2(3.6, 0.2), h, plaster)                    # kuchnia | łazienka
	wall(W, g, cx, Vector2(-1.3, 0.7), Vector2(2.05, 0.7), h, plaster, [[-0.5, 0.5]])                      # przedpokój od pokoju
	wall(W, g, cx, Vector2(-1.3, 0.7), Vector2(-1.3, 2.8), h, plaster, [[1.0, 2.0]])                       # przedpokój od salonu
	# podłogi pomieszczeń
	floor_patch(g, cx, HALL[0], HALL[1], HALL[2], HALL[3], Props.pbr("plytki_terakota", 0.85))
	floor_patch(g, cx, KITCHEN[0], KITCHEN[1], KITCHEN[2], KITCHEN[3], Props.pbr("plytki_kremowe", 0.85))
	floor_patch(g, cx, BATH[0], BATH[1], BATH[2], BATH[3], tile_f, 0.001)
	# kafle w łazience (od wewnątrz) i nad blatem kuchni
	tiles(g, cx, Vector2(2.1, 0.25), Vector2(3.6, 0.25), Vector2(0, 1), tile_f)
	tiles(g, cx, Vector2(3.6, 0.2), Vector2(3.6, 2.8), Vector2(-1, 0), tile_f)
	tiles(g, cx, Vector2(2.1, 2.4), Vector2(2.1, 2.8), Vector2(1, 0), tile_f)
	tiles(g, cx, Vector2(2.1, 0.25), Vector2(2.1, 1.4), Vector2(1, 0), tile_f)
	tiles(g, cx, Vector2(2.05, 2.8), Vector2(3.6, 2.8), Vector2(0, -1), tile_f)
	# listwy przypodłogowe wzdłuż zewnętrznych ścian pomieszczeń (kuchnia, łazienka)
	# łazienka: modele z Blendera (brodzik z zasłoną, sedes, umywalka na kolumnie, szafka z lustrem)
	_fixture(g, "lazienka_prysznic", Vector3(cx + 2.83, 0.0, 0.65), 0.0)
	_fixture(g, "lazienka_sedes", Vector3(cx + 3.25, 0.0, 1.3), -PI / 2.0)
	_fixture(g, "lazienka_umywalka", Vector3(cx + 3.33, 0.0, 2.35), -PI / 2.0)
	_fixture(g, "lazienka_lustro", Vector3(cx + 3.456, 1.15, 2.35), -PI / 2.0)
	solid(W, cx, 2.97, 3.58, 1.1, 1.5, 0.85)
	solid(W, cx, 3.18, 3.58, 2.08, 2.62, 0.95)
	# światła pomieszczeń
	var hl: OmniLight3D = W._room_light(g, cx + 0.45, 1.75, h, 0.9, Color(1.0, 0.92, 0.8), 4.2)
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


## SKLEP U STASIA: zaplecze za ladą (wschodni narożnik, drzwi od strony kasy) i dwa wolnostojące regały w sali sprzedaży
static func shop_layout(W: Node3D, g: Node3D, cx: float, w: float, d: float, h: float) -> void:
	var plaster := Props.pbr("beige_wall_001", 0.45, Color(1.2, 1.18, 1.1))
	# zaplecze: x ∈ [2.7, 4.5], z ∈ [-3.5, -0.9]; wejście z zaplecza-za-ladą przez otwór w ścianie x = 2.7
	wall(W, g, cx, Vector2(2.7, -3.5), Vector2(2.7, -0.9), h, plaster, [[-3.05, -2.05]])
	wall(W, g, cx, Vector2(2.7, -0.9), Vector2(4.5, -0.9), h, plaster)
	floor_patch(g, cx, 2.7, -3.5, 4.5, -0.9, Props.pbr("concrete_floor_worn_001", 0.5, Color(0.85, 0.85, 0.82)))
	var bl: OmniLight3D = W._room_light(g, cx + 3.6, -2.2, h, 0.9, Color(1.0, 0.9, 0.7), 3.4)
	bl.shadow_enabled = false
	bl.name = "BackroomLight"
	Interior.ceiling_lamp(g, Vector3(cx + 3.6, h, -2.2), "bulb")
	# wyposażenie zaplecza: regał stalowy, skrzynki, kartony, wiadro z mopem, tabliczka na drzwiach
	W._rp(g, "steel_frame_shelves_01", cx + 4.2, -2.1, -PI / 2.0, 1.9, 0.0, 0.3, 0.8)
	W._rp(g, "plastic_crate_01", cx + 3.2, -1.3, 0.2, 0.28, 0.0, 0.3, 0.3)
	W._rp(g, "plastic_crate_01", cx + 3.2, -1.3, 0.9, 0.28, 0.28)
	W._rp(g, "cardboard_box_01", cx + 3.9, -1.3, 0.5, 0.4, 0.0, 0.3, 0.3)
	W._rp(g, "cardboard_box_01", cx + 4.2, -1.2, 1.2, 0.34, 0.0, 0.3, 0.3)
	Models.cyl(g, 0.15, 0.12, 0.28, Vector3(cx + 3.15, 0.14, -3.2), Models.mat("3a6ea5", 0.5), Vector3.ZERO, 10)
	Models.cyl(g, 0.012, 0.012, 1.3, Vector3(cx + 3.15, 0.8, -3.2), Models.mat("8a6a3a", 0.8), Vector3(0.12, 0, 0.05), 5)
	Interior.note(g, Vector3(cx + 2.64, 1.55, -2.55), -PI / 2.0, "ZAPLECZE\nTylko dla personelu", 0.3, 0.2)
	# dwa wolnostojące regały w sali: alejka przy drzwiach zostaje wolna
	for gx in [-1.6, 1.3]:
		gondola(W, g, cx, gx, 0.6)


static func gondola(W: Node3D, g: Node3D, cx: float, x: float, z: float) -> void:
	W._rp(g, "wooden_display_shelves_01", cx + x, z, PI / 2.0, 1.9, 0.0, 0.66, 0.25)
	for row in range(1, 3):
		for cell in range(3):
			for side in [-1.0, 1.0]:
				var tm: Node3D = Stations.model(["sklep_polka_pudelka", "sklep_polka_puszki", "sklep_polka_sloiki", "sklep_polka_chemia"][(int(x * 3.0) + row * 2 + cell + (0 if side < 0.0 else 1)) & 3])
				if tm != null:
					tm.position = Vector3(cx + x + (cell - 1) * 0.438, 0.03 + row * 0.633, z + side * 0.09)
					tm.rotation.y = 0.0 if side < 0.0 else PI
					g.add_child(tm)


## ŚCIANY DZIAŁOWE LOKALI DO KUPIENIA (współrzędne środkowe jak w meblach: x względem cx, z od środka pokoju)
## {"a": początek, "b": koniec, "gaps": [[od, do]…] w metrach wzdłuż ściany}. Ta sama lista rysuje ściany i zamyka miejsce meblom.
const PARTS := {
	"garage": [
		{"a": Vector2(-3.0, -2.3), "b": Vector2(3.0, -2.3), "gaps": [[1.3, 2.4]]},
	],
	"basement": [
		{"a": Vector2(-4.5, -1.9), "b": Vector2(0.5, -1.9), "gaps": [[-3.2, -2.2]]},
		{"a": Vector2(0.5, -5.0), "b": Vector2(0.5, -1.9), "gaps": [[-3.9, -2.9]]},
	],
}


## prostokąty, na których nie wolno stawiać mebli i doniczek: litera ścian działowych oraz wolna strefa przy otworach drzwiowych
static func blocks(room: String) -> Array:
	var out: Array = []
	for p in PARTS.get(room, []):
		var a: Vector2 = p.a
		var b: Vector2 = p.b
		var along_z: bool = absf(a.x - b.x) < 0.001
		var lo: float = minf(a.y, b.y) if along_z else minf(a.x, b.x)
		var hi: float = maxf(a.y, b.y) if along_z else maxf(a.x, b.x)
		var fixed: float = a.x if along_z else a.y
		var cuts: Array = [[lo, lo]]
		for gp in p.gaps:
			cuts.append(gp)
		cuts.append([hi, hi])
		cuts.sort_custom(func(m, n): return float(m[0]) < float(n[0]))
		for i in range(cuts.size() - 1):
			var s0: float = float(cuts[i][1])
			var s1: float = float(cuts[i + 1][0])
			if s1 - s0 > 0.001:
				out.append(Rect2(fixed - 0.06, s0, 0.12, s1 - s0) if along_z else Rect2(s0, fixed - 0.06, s1 - s0, 0.12))
		for gp in p.gaps:
			var g0: float = float(gp[0])
			var g1: float = float(gp[1])
			out.append(Rect2(fixed - 0.6, g0, 1.2, g1 - g0) if along_z else Rect2(g0, fixed - 0.6, g1 - g0, 1.2))
	return out


static func build(W: Node3D, g: Node3D, cx: float, room: String, h: float, mat: Material) -> void:
	for p in PARTS.get(room, []):
		wall(W, g, cx, p.a, p.b, h, mat, p.gaps, THICK, "9a968c")
	# osobne podłogi pomieszczeń dobudowanych ścianami (inna faktura niż w hali / sali głównej)
	var fl: Dictionary = {"garage": [-3.0, -4.5, 3.0, -2.3, "dirty_concrete", Color(0.8, 0.8, 0.78)], "basement": [-4.5, -5.0, 0.5, -1.9, "concrete_floor_worn_001", Color(0.7, 0.68, 0.64)]}
	if fl.has(room):
		var f: Array = fl[room]
		floor_patch(g, cx, f[0], f[1], f[2], f[3], Props.pbr(f[4], 0.5, f[5]))


## LABORATORIUM W HUCIE: ściana działowa magazynu chemii z folią, folia na wschodniej ścianie i podłodze linii syntezy,
## suszarnia z lampami, wyciąg, maski, kable i narożnik z chemią (modele skr_* z make_skrytka.py)
static func lab_decor(W: Node3D, g: Node3D, cx: float, w: float, d: float, h: float) -> void:
	var brick := Props.pbr("factory_brick", 0.5, Color(0.55, 0.5, 0.46))
	# magazyn chemii w NW rogu: dwie ściany z otworami 1,2 m
	wall(W, g, cx, Vector2(-2.5, -d * 0.5), Vector2(-2.5, -2.6), h, brick, [[-4.6, -3.4]], THICK + 0.08, "5a544e")
	wall(W, g, cx, Vector2(-w * 0.5, -2.6), Vector2(-2.5, -2.6), h, brick, [[-6.1, -4.9]], THICK + 0.08, "5a544e")
	floor_patch(g, cx, -w * 0.5, -d * 0.5, -2.5, -2.6, Props.pbr("dirty_concrete", 0.5, Color(0.7, 0.68, 0.64)))
	var dec := Node3D.new()
	dec.name = "LabDecor"
	g.add_child(dec)
	# folia na wschodniej ścianie za stołami i na podłodze linii syntezy
	for k in range(3):
		var sh: Node3D = Stations.model("skr_folia_sciana")
		if sh != null:
			sh.position = Vector3(cx + w * 0.5 - 0.03, 0.0, -3.9 + k * 2.3)
			sh.rotation.y = -PI / 2.0
			sh.scale = Vector3(1.04, (h - 0.15) / 2.55, 1.0)
			dec.add_child(sh)
	var fp: Node3D = Stations.model("skr_folia_podloga")
	if fp != null:
		fp.position = Vector3(cx + 4.3, 0.005, -1.0)
		fp.rotation.y = PI / 2.0
		dec.add_child(fp)
	# kotara z folii na południowej stronie przegrody magazynu (widać ją z hali)
	for k in range(2):
		var sh2: Node3D = Stations.model("skr_folia_sciana")
		if sh2 != null:
			sh2.position = Vector3(cx - 6.0 + k * 2.2, 0.0, -2.52)
			sh2.scale = Vector3(1.0, (h - 0.15) / 2.55, 1.0)
			sh2.rotation.y = 0.0
			dec.add_child(sh2)
	# suszarnia z lampami grzewczymi pod północną ścianą
	for sx in [-1.2, 0.05]:
		var sz: Node3D = Stations.model("skr_susz")
		if sz != null:
			sz.position = Vector3(cx + sx, 0.0, -d * 0.5 + 0.5)
			dec.add_child(sz)
	W.add_col(cx - 1.85, cx + 0.7, -d * 0.5, -d * 0.5 + 0.9, 1.0, true, -1.0)
	W.rects.pop_back()
	var hl := OmniLight3D.new()
	hl.position = Vector3(cx - 0.55, 1.3, -d * 0.5 + 0.9)
	hl.light_color = Color(1.0, 0.38, 0.16)
	hl.light_energy = 1.2
	hl.omni_range = 2.8
	hl.shadow_enabled = false
	dec.add_child(hl)
	# wyciąg nad magazynem, maski przy tylnych drzwiach, kable nad linią syntezy, narożnik z chemią w SW
	var wy: Node3D = Stations.model("skr_wyciag")
	if wy != null:
		wy.position = Vector3(cx - w * 0.5 + 0.03, h - 1.78, -3.0)
		wy.rotation.y = PI / 2.0
		dec.add_child(wy)
	var mk: Node3D = Stations.model("skr_maski")
	if mk != null:
		mk.position = Vector3(cx - w * 0.5 + 0.04, 0.55, 1.8)
		mk.rotation.y = PI / 2.0
		dec.add_child(mk)
	var kb: Node3D = Stations.model("skr_kable")
	if kb != null:
		kb.position = Vector3(cx + 5.2, h - 0.31, -0.8)
		dec.add_child(kb)
	var ch: Node3D = Stations.model("skr_chemia")
	if ch != null:
		ch.position = Vector3(cx - 6.1, 0.0, 4.55)
		ch.rotation.y = PI / 2.0
		ch.scale = Vector3.ONE * 0.9
		dec.add_child(ch)
		W.add_col(cx - 6.9, cx - 5.3, 3.8, 5.3, 1.0, true, -1.0)
		W.rects.pop_back()
	# zimne światło nad linią syntezy (kontrast z ciepłymi halogenami magazynu)
	var cold := OmniLight3D.new()
	cold.position = Vector3(cx + 5.0, h - 0.7, -1.3)
	cold.light_color = Color(0.82, 0.92, 1.0)
	cold.light_energy = 0.9
	cold.omni_range = 4.5
	cold.shadow_enabled = false
	dec.add_child(cold)
	# podłoga: oleiste plamy, kałuże odczynników, ślady wózka i zacieki (zużyty beton zamiast czystej płyty)
	var fl := Vector3(-PI / 2.0, 0, 0)
	for e in [[-1.0, 0.5, 1.8, 1.2, 0.3], [3.2, 1.6, 1.3, 0.9, 1.1], [-2.6, 2.4, 1.5, 1.0, 2.0], [-3.0, -0.6, 1.4, 1.0, 0.7], [1.2, -2.8, 1.1, 0.8, 0.5], [5.4, 2.2, 0.9, 1.3, 0.2], [-2.0, -4.0, 1.2, 0.9, 1.8], [0.0, 3.2, 1.6, 1.0, 0.4]]:
		Interior.stain(dec, Vector3(cx + e[0], 0.006, e[1]), Vector3(-PI / 2.0, 0.0, e[4]), Vector2(e[2] * 1.4, e[3] * 1.4), Color(0.02, 0.02, 0.02, 0.8))
	for e in [[2.4, -1.0, 1.3, 0.9], [-3.4, -1.6, 1.1, 0.8], [0.2, 3.8, 1.4, 0.9], [-1.6, 0.9, 1.0, 0.7], [-3.8, 0.4, 0.9, 0.6]]:
		Interior.stain(dec, Vector3(cx + e[0], 0.008, e[1]), Vector3(-PI / 2.0, 0.0, e[2] * 3.0), Vector2(e[2], e[3]), Color(0.34, 0.5, 0.42, 0.42))
		_puddle(dec, Vector3(cx + e[0], 0.011, e[1]), Vector2(e[2] * 0.8, e[3] * 0.8), e[2] * 3.0)
	for e in [[-1.3, 1.2, 0.0, 0.17, 8.0], [-0.7, 1.5, 0.0, 0.17, 8.0], [3.8, 0.8, 0.12, 0.2, 6.0]]:
		Interior.stain(dec, Vector3(cx + e[0], 0.007, e[1]), Vector3(-PI / 2.0, 0.0, PI / 2.0 + e[2]), Vector2(e[4], e[3]), Color(0.04, 0.04, 0.04, 0.28))
	# bałagan przy ścianach: palety, worki, wiadra, skrzynie, opony (większe sztuki z kolizją, drobiazgi bez)
	var pal: Node3D = W._rp(dec, "pallet", cx - 6.1, 0.5, 0.15, 0.16)
	_age(pal, Color(0.42, 0.37, 0.32))
	for j in range(2):
		W._rp(dec, "cement_bag", cx - 6.2 + j * 0.28, 0.5 - j * 0.08, 0.4 + j, 0.2, 0.16 + j * 0.12)
	W.add_col(cx - 6.7, cx - 5.5, -0.1, 1.1, 0.6, true, -1.0)
	W.rects.pop_back()
	for j in range(3):
		W._rp(dec, "plastic_crate_01", cx + 6.4, -5.0 + (0.0 if j < 2 else 0.1), 0.1 * j, 0.28, 0.28 * (1 if j == 2 else 0) + 0.0, 0.0, 0.0)
	W.add_col(cx + 6.0, cx + 6.8, -5.4, -4.6, 0.9, true, -1.0)
	W.rects.pop_back()
	for e in [[2.9, -5.1, 0.3], [3.2, -4.9, 1.2], [2.6, -4.8, 2.0]]:
		W._rp(dec, "trashbag_1", cx + e[0] - 0.9, e[1], e[2], 0.5)
	W._rp(dec, "wooden_crate_02", cx + 6.4, 2.9, 0.2, 0.5, 0.0, 0.35, 0.35)
	W._rp(dec, "old_tyre", cx - 3.2, 3.3, 0.3, 0.16)
	W._rp(dec, "old_tyre", cx - 3.1, 3.35, 0.9, 0.16, 0.16)
	W._rp(dec, "plastic_container", cx - 0.2, -3.9, 0.4, 0.4, 0.0, 0.3, 0.3)
	W._rp(dec, "can_rusted", cx + 1.0, 0.9, 0.5, 0.2)
	W._rp(dec, "can_rusted", cx - 1.9, 1.9, 2.1, 0.2)
	W._rp(dec, "plastic_bottle_gallon", cx + 3.2, 1.0, 0.3, 0.32)
	W._rp(dec, "plastic_bottle_gallon", cx - 4.9, 0.4, 1.0, 0.32)
	W._rp(dec, "cardboard_box_01", cx - 2.2, 1.0, 0.7, 0.4)
	W._rp(dec, "trashbag", cx - 1.5, 4.0, 0.2, 0.5)
	# prowizoryczny stół ze sklejki i przedłużacze po podłodze
	W._rp(dec, "metal_stool_01", cx - 4.7, 1.9, 0.5, 0.6)
	for e in [[-4.1, 0.7, -3.3, 2.6, 0.0], [0.4, 1.0, 1.7, 2.3, 0.0]]:
		var a := Vector2(e[0], e[1])
		var b := Vector2(e[2], e[3])
		var cord: MeshInstance3D = Models.cyl(dec, 0.012, 0.012, a.distance_to(b), Vector3(cx + (a.x + b.x) * 0.5, 0.014, (a.y + b.y) * 0.5), Models.mat("c46a1e", 0.6), Vector3(PI / 2.0, atan2(b.x - a.x, b.y - a.y), 0.0), 6)
		cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ścianka magazynu: zacieki i ogłoszenia
	for e in [[-6.0, 1.3, 0.6, 1.5], [-4.3, 1.1, 0.5, 1.8], [-3.2, 1.4, 0.7, 1.4]]:
		Interior.stain(dec, Vector3(cx + e[0], e[1], -2.54), Vector3.ZERO, Vector2(e[2], e[3]), Color(0.1, 0.07, 0.04, 0.45))
	Interior.stain(dec, Vector3(cx - 2.44, 0.9, -3.0), Vector3(0, PI / 2.0, 0), Vector2(1.4, 1.6), Color(0.08, 0.06, 0.04, 0.4))
	Interior.stain(dec, Vector3(cx - 4.0, 0.3, -2.54), Vector3.ZERO, Vector2(3.2, 0.6), Color(0.05, 0.05, 0.04, 0.5))
	Interior.note(dec, Vector3(cx - 3.0, 1.5, -2.55), 0.0, "HALL 2\nAUTHORISED ONLY", 0.42, 0.3, "e8e2cf")
	Interior.note(dec, Vector3(cx - 2.43, 1.4, -4.9), PI / 2.0, "NO NAKED FLAMES\nVENTILATE!", 0.4, 0.28, "f2e8a8")
	W._skr_shadows(dec)


## postarza model z assets: mnoży kolory materiałów (np. jaskrawa paleta → szare stare drewno)
static func _age(n: Node, tint: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		for si in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_active_material(si)
			if m is BaseMaterial3D:
				var m2: BaseMaterial3D = (m as BaseMaterial3D).duplicate()
				m2.albedo_color = m2.albedo_color * tint
				mi.set_surface_override_material(si, m2)
	for c in n.get_children():
		_age(c, tint)


## kałuża odczynnika: ciemna, gładka, odbija światło lamp
static func _puddle(g: Node3D, pos: Vector3, size: Vector2, rot: float) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.1, 0.09, 0.78)
	m.albedo_texture = Props._soft_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04
	m.metallic = 0.25
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	q.material_override = m
	q.position = pos
	q.rotation = Vector3(-PI / 2.0, 0.0, rot)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(q)


## obrysy (x, z lokalne) rekwizytów z kolizją w labie oraz strefy przejść — dla testu przenikania
const LAB_FOOTPRINTS := {
	"paleta": Rect2(-6.7, -0.1, 1.2, 1.2), "skrzynie_ne": Rect2(6.0, -5.4, 0.8, 0.8),
	"skrzynia_e": Rect2(6.05, 2.55, 0.7, 0.7), "pojemnik": Rect2(-0.5, -4.2, 0.6, 0.6), "suszarnia": Rect2(-1.85, -5.5, 2.55, 0.9),
	"chemia_sw": Rect2(-6.9, 3.8, 1.6, 1.5), "reaktor": Rect2(3.28, -4.92, 1.24, 1.24), "stol_pakowanie": Rect2(0.58, 1.95, 2.04, 0.9),
	"stol_synt1": Rect2(6.0, -4.52, 0.9, 2.04), "stol_synt2": Rect2(6.0, -2.32, 0.9, 2.04), "stol_synt3": Rect2(6.0, -0.12, 0.9, 2.04)}
const LAB_PASSAGES := {
	"otwor_wschodni": Rect2(-3.7, -4.6, 2.2, 1.2), "otwor_poludniowy": Rect2(-6.1, -3.6, 1.2, 2.2), "tylne_drzwi": Rect2(-6.8, 2.2, 1.8, 1.6)}
