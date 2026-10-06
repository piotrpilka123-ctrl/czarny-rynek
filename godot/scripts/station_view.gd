extends Control
## Animowany podgląd stanowiska produkcyjnego: regał z roślinami pod LED-ami, suszarka albo stół laboratoryjny.
## Rysuje stan zadania z G.Prod i krótkie animacje czynności (podlewanie, nawóz, przycinanie, przelewanie).

const K = preload("res://scripts/uikit.gd")

var kind := "grow"          # grow / dry / lab
var room := ""
var idx := 0
var pots := 4
var fx := ""                # trwająca animacja czynności
var fx_t := 0.0
var fx_cb := Callable()
var _clock := 0.0
var _font: Font
var _sb := {}
var _plants: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var f := "res://assets/fonts/barlowc.ttf"
	_font = load(f) if ResourceLoader.exists(f) else get_theme_default_font()
	for i in range(3):
		_plants.append(load("res://assets/nature/gen_konopie_%d.png" % (i + 1)))


func busy() -> bool:
	return fx != ""


## odgrywa animację czynności i dopiero potem woła `cb`
func play(what: String, cb: Callable) -> void:
	fx = what
	fx_t = 0.0
	fx_cb = cb


func _process(dt: float) -> void:
	_clock += dt
	if fx != "":
		fx_t += dt * (30.0 if G.test_mode else 1.0) / 0.95
		if fx_t >= 1.0:
			fx = ""
			var cb := fx_cb
			fx_cb = Callable()
			if cb.is_valid():
				cb.call()
	if is_visible_in_tree():
		queue_redraw()


func _box(r: Rect2, c: Color, rad := 8, border := Color(0, 0, 0, 0), bw := 0) -> void:
	K.rbox(self, r, c, rad, border, bw)


func _text(pos: Vector2, s: String, sz: int, c: Color, w := 240.0, al := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(_font, pos - Vector2(w * 0.5 if al == HORIZONTAL_ALIGNMENT_CENTER else 0.0, 0), s, al, w, sz, c)


func _draw() -> void:
	var w := size.x
	var h := size.y
	_box(Rect2(0, 0, w, h), Color(0.045, 0.04, 0.06), 12, Color(0, 0, 0, 0.5), 1)
	# posadzka i ściana
	draw_rect(Rect2(1, h - 46, w - 2, 45), Color(0.09, 0.085, 0.1))
	for i in range(12):
		draw_line(Vector2(w * i / 12.0, h - 46), Vector2(w * i / 12.0 - 30, h - 1), Color(0, 0, 0, 0.18), 1.0)
	var j = G.Prod.job(room, idx)
	match kind:
		"grow": _draw_grow(j, w, h)
		"dry": _draw_dry(j, w, h)
		"lab": _draw_lab(j, w, h)
	if j != null and String(j.r) != "_dry":
		_timeline(j, w, h)


# ---------------------------------------------------------------- regał
func _draw_grow(j, w: float, h: float) -> void:
	var rw := minf(w - 180.0, 150.0 * pots + 60.0)
	var x0 := (w - rw) * 0.5
	var top := 26.0
	var floor_y := h - 46.0
	var on: bool = j != null
	# poświata LED-ów
	if on:
		var pulse := 0.92 + 0.08 * sin(_clock * 2.2)
		for i in range(9):
			var k := i / 8.0
			draw_rect(Rect2(x0 - 30.0 * k, top + 14 + k * 20.0, rw + 60.0 * k, (floor_y - top - 60.0) * (0.25 + k * 0.75)), Color(0.72, 0.25, 0.95, 0.028 * pulse))
	# rama
	var steel := Color(0.2, 0.21, 0.24)
	for sx in [x0, x0 + rw - 7.0]:
		draw_rect(Rect2(sx, top, 7, floor_y - top), steel)
	draw_rect(Rect2(x0, top, rw, 7), steel)
	# listwy LED
	draw_rect(Rect2(x0 + 18, top + 12, rw - 36, 10), Color(0.07, 0.07, 0.08))
	if on:
		draw_rect(Rect2(x0 + 24, top + 20, rw - 48, 4), Color(0.93, 0.45, 1.0))
		for i in range(int((rw - 48) / 14.0)):
			K.circle(self, Vector2(x0 + 30 + i * 14.0, top + 22), 2.2, Color(1.0, 0.82, 1.0))
	# kuweta
	var tray_y := floor_y - 22.0
	draw_rect(Rect2(x0 + 4, tray_y, rw - 8, 9), Color(0.05, 0.05, 0.06))
	draw_rect(Rect2(x0, tray_y + 9, rw, 5), steel)
	# doniczki i rośliny
	var prog := float(j.prog) if on else 0.0
	var stage := 0 if prog < 0.2 else (1 if prog < 0.6 else 2)
	var max_h := tray_y - top - 66.0
	var dry: bool = on and float(j.water) <= 5.0
	for k in range(pots):
		var cx := x0 + rw * (k + 0.5) / pots
		var pot_w := 58.0
		var pot_h := 32.0
		var py := tray_y - pot_h
		if on:
			var ph := lerpf(0.2, 1.0, prog) * max_h * (0.94 + 0.06 * sin(k * 2.3))
			var sway := sin(_clock * 1.3 + k * 1.7) * 0.012
			var pw := ph * 0.667
			var tint := Color(0.96, 0.9, 1.0)
			if dry:
				tint = Color(0.86, 0.8, 0.5)
				ph *= 0.88
			elif float(j.health) < 50.0:
				tint = Color(0.9, 0.9, 0.62)
			if fx == "trim":
				sway += sin(fx_t * 34.0) * 0.03
			draw_set_transform(Vector2(cx, py + 6), sway, Vector2.ONE)
			draw_texture_rect(_plants[stage], Rect2(-pw * 0.5, -ph, pw, ph), false, tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		K.poly(self, PackedVector2Array([Vector2(cx - pot_w * 0.5, py), Vector2(cx + pot_w * 0.5, py), Vector2(cx + pot_w * 0.4, py + pot_h), Vector2(cx - pot_w * 0.4, py + pot_h)]), Color(0.085, 0.085, 0.09))
		draw_rect(Rect2(cx - pot_w * 0.5 - 2, py - 3, pot_w + 4, 7), Color(0.12, 0.12, 0.13))
		draw_rect(Rect2(cx - pot_w * 0.5 + 3, py - 1, pot_w - 6, 4), Color(0.2, 0.14, 0.1) if not on or float(j.water) > 25.0 else Color(0.36, 0.3, 0.24))
		# czynności
		if fx == "water":
			for d in range(7):
				var q := fmod(fx_t * 2.2 + d * 0.17 + k * 0.31, 1.0)
				K.circle(self, Vector2(cx - 22 + d * 7.5, lerpf(top + 40, py - 4, q)), 2.4, Color(0.45, 0.75, 1.0, 0.9))
		if fx == "fert":
			for d in range(6):
				var q2 := fmod(fx_t * 1.6 + d * 0.2, 1.0)
				K.circle(self, Vector2(cx - 18 + d * 7.0, lerpf(py - 60, py - 2, q2)), 2.0, Color(0.95, 0.85, 0.4, 0.95))
		if fx == "harvest" and on:
			draw_line(Vector2(cx - 34, py - 30 + sin(fx_t * 20.0) * 6.0), Vector2(cx + 34, py - 18 + sin(fx_t * 20.0) * 6.0), Color(0.9, 0.92, 0.95), 3.0)
	if fx == "trim":
		var sx2 := x0 + rw * fmod(fx_t * 1.4, 1.0)
		draw_line(Vector2(sx2 - 12, top + 80), Vector2(sx2 + 12, top + 104), Color(0.9, 0.92, 0.95), 3.0)
		draw_line(Vector2(sx2 + 12, top + 80), Vector2(sx2 - 12, top + 104), Color(0.9, 0.92, 0.95), 3.0)
	# wskaźnik wody z boku
	if on:
		var gx := x0 + rw + 30.0
		var gh := floor_y - top - 50.0
		_box(Rect2(gx, top + 30, 16, gh), Color(0.1, 0.12, 0.16), 6, Color(1, 1, 1, 0.15), 1)
		var wl := clampf(float(j.water) / 100.0, 0.0, 1.0)
		var wc := Color(0.35, 0.65, 1.0) if wl > 0.25 else Color(0.94, 0.3, 0.3)
		if wl > 0.0:
			_box(Rect2(gx + 2, top + 32 + (gh - 4) * (1.0 - wl), 12, (gh - 4) * wl), wc, 4)
		_text(Vector2(gx + 8, top + 22), "WODA", 11, K.C_DIM, 60.0)
		_text(Vector2(gx + 8, floor_y - 2), "%d%%" % int(round(float(j.water))), 15, wc, 60.0)
	else:
		_text(Vector2(w * 0.5, h * 0.5), "PUSTE DONICZKI", 20, Color(1, 1, 1, 0.25), 400.0)


# ---------------------------------------------------------------- suszarka
func _draw_dry(j, w: float, h: float) -> void:
	var cx := w * 0.5
	var top := 22.0
	var floor_y := h - 46.0
	var steel := Color(0.2, 0.21, 0.24)
	draw_line(Vector2(cx, top), Vector2(cx, top + 16), steel, 3.0)
	var tiers := 4
	var gap := (floor_y - top - 40.0) / tiers
	for t in range(tiers):
		var y := top + 34 + t * gap
		draw_line(Vector2(cx, y - gap + 10 if t > 0 else top + 16), Vector2(cx - 150, y), Color(1, 1, 1, 0.12), 1.0)
		draw_line(Vector2(cx, y - gap + 10 if t > 0 else top + 16), Vector2(cx + 150, y), Color(1, 1, 1, 0.12), 1.0)
		draw_set_transform(Vector2(cx, y), 0.0, Vector2(1.0, 0.22))
		K.circle(self, Vector2.ZERO, 156.0, Color(0.16, 0.18, 0.21))
		K.circle(self, Vector2.ZERO, 150.0, Color(0.08, 0.09, 0.11))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if j != null:
			var dryk := float(j.prog)
			var col := Color(0.36, 0.56, 0.24).lerp(Color(0.5, 0.46, 0.24), dryk)
			var n: int = clampi(int(float(j.g) / 4.0), 4, 16)
			for k in range(n):
				var a := k * 2.4 + t * 1.1
				var r := 30.0 + fmod(k * 37.0, 100.0)
				var bp := Vector2(cx + cos(a) * r, y + sin(a) * r * 0.22 - 4)
				K.circle(self, bp, 9.0, col.darkened(0.2))
				K.circle(self, bp + Vector2(-2, -2), 6.0, col)
	if j != null and float(j.prog) < 1.0:
		for k in range(8):
			var q := fmod(_clock * 0.25 + k * 0.125, 1.0)
			K.circle(self, Vector2(cx - 120 + k * 34.0 + sin(_clock + k) * 8.0, lerpf(floor_y - 30, top + 20, q)), 5.0 + q * 6.0, Color(1, 1, 1, 0.05 * (1.0 - q)))
	if j == null:
		_text(Vector2(cx, h - 16), "SUSZARKA PUSTA", 16, Color(1, 1, 1, 0.3), 400.0)
	else:
		_box(Rect2(cx - 180, h - 30, 360, 10), Color(1, 1, 1, 0.08), 5)
		_box(Rect2(cx - 180, h - 30, 360 * clampf(float(j.prog), 0.02, 1.0), 10), K.C_ACC if float(j.prog) >= 1.0 else K.C_WARN, 5)


# ---------------------------------------------------------------- stół laboratoryjny
func _draw_lab(j, w: float, h: float) -> void:
	var floor_y := h - 46.0
	var ty := floor_y - 54.0
	var x0 := w * 0.5 - 280.0
	# blat
	draw_rect(Rect2(x0, ty, 560, 9), Color(0.55, 0.57, 0.6))
	for sx in [x0 + 8, x0 + 544]:
		draw_rect(Rect2(sx, ty + 9, 8, floor_y - ty - 9), Color(0.17, 0.18, 0.2))
	var on: bool = j != null and float(j.prog) < 1.0
	var cooking: bool = on and int(j.hold) < 0
	var mode: int = int(j.mode) if j != null else 1
	var glass := Color(0.8, 0.92, 0.96, 0.3)
	# płyta grzejna
	var fx0 := x0 + 120.0
	draw_rect(Rect2(fx0 - 46, ty - 14, 92, 14), Color(0.1, 0.1, 0.12))
	if cooking:
		draw_rect(Rect2(fx0 - 36, ty - 17, 72, 4), Color(1.0, 0.36 + 0.1 * mode, 0.12, 0.6 + 0.3 * sin(_clock * 7.0)))
	# kolba
	var fc := Vector2(fx0, ty - 62)
	K.circle(self, fc, 46.0, glass)
	draw_rect(Rect2(fx0 - 11, ty - 150, 22, 50), glass)
	if j != null:
		var liq := Color(0.6, 0.9, 0.36, 0.85) if float(j.prog) < 0.45 else Color(0.92, 0.9, 0.7, 0.85)
		draw_set_transform(fc + Vector2(0, 12), 0.0, Vector2(1.0, 0.72))
		K.circle(self, Vector2.ZERO, 41.0, liq)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if cooking:
			for k in range(9 + mode * 5):
				var q := fmod(_clock * (0.7 + mode * 0.5) + k * 0.173, 1.0)
				K.circle(self, fc + Vector2(-28 + fmod(k * 13.7, 56.0), 34 - q * 52.0), 2.0 + fmod(k * 1.3, 3.0), Color(1, 1, 1, 0.55 * (1.0 - q)))
			for k in range(5):
				var q2 := fmod(_clock * 0.4 + k * 0.2, 1.0)
				K.circle(self, Vector2(fx0 + sin(_clock + k) * 6.0, ty - 150 - q2 * 44.0), 7.0 + q2 * 12.0, Color(1, 1, 1, 0.08 * (1.0 - q2)))
	# chłodnica do odbieralnika
	var a := Vector2(fx0 + 12, ty - 144)
	var b := Vector2(x0 + 330, ty - 60)
	draw_line(a, b, Color(0.8, 0.92, 0.96, 0.35), 14.0)
	draw_line(a, b, Color(0.5, 0.8, 0.95, 0.6), 3.0)
	if cooking:
		var q3 := fmod(_clock * 0.8, 1.0)
		K.circle(self, a.lerp(b, q3), 3.0, Color(0.95, 0.95, 0.8))
	# odbieralnik: napełnia się z postępem
	var bx := x0 + 340.0
	K.poly(self, PackedVector2Array([Vector2(bx - 34, ty - 70), Vector2(bx + 34, ty - 70), Vector2(bx + 28, ty), Vector2(bx - 28, ty)]), glass)
	if j != null:
		var fill := clampf(float(j.prog), 0.0, 1.0)
		var fy := ty - 66.0 * fill
		K.poly(self, PackedVector2Array([Vector2(bx - 28 - 5 * fill, fy), Vector2(bx + 28 + 5 * fill, fy), Vector2(bx + 28, ty), Vector2(bx - 28, ty)]), Color(0.95, 0.93, 0.78, 0.9))
	if fx == "pour":
		draw_line(Vector2(bx - 60 + fx_t * 40.0, ty - 120), Vector2(bx, ty - 40), Color(0.92, 0.9, 0.7, 0.9), 5.0)
	# butelki
	for k in range(3):
		var bxx := x0 + 430 + k * 40.0
		draw_rect(Rect2(bxx - 12, ty - 50 - k * 6, 24, 50 + k * 6), Color(0.36, 0.2, 0.09, 0.9) if k != 1 else glass)
		draw_rect(Rect2(bxx - 5, ty - 60 - k * 6, 10, 10), Color(0.08, 0.08, 0.09))
	# termometr = wybrana temperatura
	var tx := x0 + 30.0
	_box(Rect2(tx, ty - 120, 12, 106), Color(0.1, 0.12, 0.16), 6, Color(1, 1, 1, 0.2), 1)
	var lvl: float = [0.35, 0.6, 0.92][clampi(mode, 0, 2)] if on else 0.12
	_box(Rect2(tx + 3, ty - 17 - 100.0 * lvl, 6, 100.0 * lvl), Color(0.4, 0.7, 1.0).lerp(Color(1.0, 0.3, 0.2), lvl), 3)
	_text(Vector2(tx + 6, ty - 128), "TEMP.", 11, K.C_DIM, 60.0)
	if j == null:
		_text(Vector2(w * 0.5, 40), "STÓŁ CZEKA NA WSAD", 18, Color(1, 1, 1, 0.3), 400.0)
	elif j.burnt and float(j.prog) >= 1.0:
		_text(Vector2(w * 0.5, 40), "PARTIA PRZYPALONA", 18, K.C_BAD, 400.0)


# ---------------------------------------------------------------- oś etapów
func _timeline(j, w: float, h: float) -> void:
	var r: Dictionary = G.Prod.recipe(j)
	var x0 := 26.0
	var x1 := w - 26.0
	var y := h - 26.0
	var prev := 0.0
	var prog := clampf(float(j.prog), 0.0, 1.0)
	for i in range(r.stages.size()):
		var st: Dictionary = r.stages[i]
		var a := x0 + (x1 - x0) * prev
		var b := x0 + (x1 - x0) * float(st.to)
		var done: bool = prog >= float(st.to) - 0.0001
		var cur: bool = prog >= prev and not done
		_box(Rect2(a + 2, y, b - a - 4, 8), Color(1, 1, 1, 0.09), 4)
		if prog > prev:
			var c := K.C_ACC if done else K.C_WARN
			_box(Rect2(a + 2, y, (b - a - 4) * clampf((prog - prev) / (float(st.to) - prev), 0.03, 1.0), 8), c, 4)
		_text(Vector2((a + b) * 0.5, y + 22), String(st.name).to_upper(), 12, Color.WHITE if cur else K.C_DIM, b - a)
		if st.has("hold"):
			K.circle(self, Vector2(b, y + 4), 6.0, K.C_BAD if int(j.hold) == i else Color(0.3, 0.32, 0.38))
			K.circle(self, Vector2(b, y + 4), 2.5, Color.WHITE)
		prev = float(st.to)
