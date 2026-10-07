extends RefCounted
## Szyldy, tabliczki, graffiti, plakaty i murale (czcionki z Google Fonts, licencje OFL / Apache).

const Models = preload("res://scripts/models.gd")

static var _fonts := {}


static func font(name: String) -> Font:
	if not _fonts.has(name):
		var p := "res://assets/fonts/%s.ttf" % name
		_fonts[name] = load(p) if ResourceLoader.exists(p) else null
	return _fonts[name]


static func text(t: String, font_name: String, size: int, color: Color, px := 0.005, outline := 0, outline_color := Color(0, 0, 0, 0.85)) -> Label3D:
	var l := Label3D.new()
	l.text = t
	var f := font(font_name)
	if f != null:
		l.font = f
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = outline_color
	l.double_sided = false
	l.shaded = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	return l


## tabliczka nad drzwiami: ciemna blacha z napisem
static func plate(t: String, color: Color, w := 0.0) -> Node3D:
	var g := Node3D.new()
	var width := w if w > 0.0 else maxf(1.2, t.length() * 0.115 + 0.4)
	Models.box(g, Vector3(width, 0.34, 0.04), Vector3.ZERO, Models.mat("17191d", 0.6, 0.3))
	Models.box(g, Vector3(width + 0.06, 0.03, 0.05), Vector3(0, 0.185, 0), Models.mat("2c3036", 0.5, 0.5))
	var l := text(t, "barlowc", 44, color, 0.0045)
	l.position = Vector3(0, -0.01, 0.026)
	g.add_child(l)
	return g


## szyld sklepu: kaseton z podświetleniem albo wyblakła tablica
static func shop(t: String, color: Color, width: float, lit: bool) -> Node3D:
	var g := Node3D.new()
	var bg := color.darkened(0.72) if lit else Color(0.2, 0.2, 0.2)
	Models.box(g, Vector3(width, 0.62, 0.12), Vector3.ZERO, Models.mat(bg, 0.7))
	Models.box(g, Vector3(width + 0.08, 0.05, 0.14), Vector3(0, 0.33, 0), Models.mat("101114", 0.6, 0.4))
	Models.box(g, Vector3(width + 0.08, 0.05, 0.14), Vector3(0, -0.33, 0), Models.mat("101114", 0.6, 0.4))
	var fs := 96
	var l := text(t, "bebas", fs, color if lit else color.lerp(Color(0.6, 0.6, 0.6), 0.5), 0.0045)
	# dopasuj szerokość napisu do kasetonu
	var est := t.length() * fs * 0.0045 * 0.42
	if est > width * 0.9:
		l.pixel_size = 0.0045 * width * 0.9 / est
	l.position = Vector3(0, -0.01, 0.066)
	l.shaded = not lit
	g.add_child(l)
	return g


## graffiti: tag markerem albo sprayem
static func graffiti(t: String, color: Color, size := 1.0, kind := "sedgwick") -> Label3D:
	var l := text(t, kind, 140, Color(color.r, color.g, color.b, 0.9), 0.0052 * size, 14 if kind != "spray" else 0, Color(0.04, 0.04, 0.05, 0.9))
	return l


## duży napis-mural z cieniem
static func mural(t: String, fill: Color, edge: Color, size := 1.0) -> Node3D:
	var g := Node3D.new()
	var sh := text(t, "sedgwick", 200, Color(0.03, 0.03, 0.04, 0.8), 0.006 * size)
	sh.position = Vector3(0.07 * size, -0.07 * size, 0.0)
	g.add_child(sh)
	var l := text(t, "sedgwick", 200, fill, 0.006 * size, 26, edge)
	l.position = Vector3(0, 0, 0.004)
	g.add_child(l)
	return g


## plakat na murze: papier, nagłówek, drobny druk
static func poster(seed_v: int, s := 1.0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var kinds := [
		["CONCERT", "SCHOOL GYM • 7 PM", "e8dcc0", "8a1c1c"], ["LOST DOG", "answers to Reks • reward", "f0ece0", "15171a"], ["CARS WANTED", "cash on the spot", "e8d040", "15171a"],
		["ELECTIONS", "your vote counts", "d8dce4", "1c3f8a"], ["0% LOAN", "no checks • no questions", "e8e0d0", "b0492c"], ["DISCO NEON", "friday / saturday", "1a1420", "ff3bd0"],
		["TUTORING", "maths • cheap", "f0f0e8", "23402e"], ["RUBBLE REMOVAL", "call 600 200 …", "d8d0b8", "3b3630"], ["HUTNIK — STAL", "derby • sunday", "c9c4b8", "8a1c1c"],
	]
	var k: Array = kinds[rng.randi_range(0, kinds.size() - 1)]
	var g := Node3D.new()
	var w := 0.6 * s
	var h := 0.85 * s
	var paper := Models.col(k[2]) * rng.randf_range(0.75, 1.0)
	paper.a = 1.0
	Models.box(g, Vector3(w, h, 0.006), Vector3.ZERO, Models.mat(paper, 0.95), Vector3(0, 0, rng.randf_range(-0.05, 0.05)), false)
	# nagłówek mieści najdłuższe słowo w szerokości plakatu
	var longest := 1
	for word in String(k[0]).split(" "):
		longest = maxi(longest, word.length())
	var hpx := minf(0.0036 * s, w * 0.86 / (longest * 72.0 * 0.4))
	var head := text(k[0], "bebas", 72, Models.col(k[3]), hpx)
	head.position = Vector3(0, h * 0.2, 0.006)
	head.width = w / hpx * 0.96
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.add_child(head)
	var sub := text(k[1], "barlowc", 40, Models.col(k[3]).lerp(Color(0.2, 0.2, 0.2), 0.4), 0.0026 * s)
	sub.position = Vector3(0, -h * 0.22, 0.006)
	sub.width = w / (0.0026 * s) * 0.9
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.add_child(sub)
	# oddarty róg
	if rng.randf() < 0.5:
		Models.box(g, Vector3(w * 0.3, h * 0.18, 0.008), Vector3(w * 0.36, -h * 0.42, 0.001), Models.mat("6a6a66", 0.95), Vector3(0, 0, 0.5), false)
	return g
