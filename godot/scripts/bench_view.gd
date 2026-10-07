extends Control
## Animowany blat stołu roboczego: tacka z towarem, waga, łyżka i rząd gotowych porcji.
## Widok sam niczego nie liczy — co woreczek woła `step` (logika w game.gd) i rysuje to, co z tego wyszło.

const K = preload("res://scripts/uikit.gd")

var product := "dym"
var pile_g := 0.0          # ile towaru leży na tacce
var pile_max := 1.0
var packs: Array = []      # porcje zrobione w tej sesji: {t} (t = postęp lotu z wagi na miejsce)
var packs_before := 0      # porcje, które leżały tu już wcześniej
var spills: Array = []     # rozsypane okruchy: {p, r}
var scale_name := "Waga kuchenna"
var job := {}              # {left, mode, sec, t, stepped, res, tgt, step, done, good, lost}
var reading := 0.0         # wskazanie wagi
var filler := ""           # ikona dodatku (majeranek / cukier), "" = brak słoika
var mix_t := -1.0          # animacja dosypywania 0..1, −1 = nic się nie dzieje
var mix_cb := Callable()
var mix_amount := 0.0      # ile dodatku wsypujemy (do rysowania strumienia)
var tint := 0.0            # jak bardzo stos jest „rozrobiony” (0..1)
var force_speed := -1.0     # testy/zrzuty: narzucone tempo (0 = stop-klatka)
var _clock := 0.0
var _font: Font
var _sb := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var f := "res://assets/fonts/barlowc.ttf"
	_font = load(f) if ResourceLoader.exists(f) else get_theme_default_font()


func busy() -> bool:
	return not job.is_empty() or mix_t >= 0.0


## zaczyna porcjowanie `count` gramów; `step` zwraca 1 (woreczek), 0 (rozsypane) albo −1 (koniec),
## `done` dostaje (gotowe, rozsypane)
func start(count: int, mode: int, sec: float, step: Callable, done: Callable) -> void:
	job = {"left": count, "mode": mode, "sec": sec, "t": 0.0, "stepped": false, "res": 1, "tgt": 1.0, "step": step, "done": done, "good": 0, "lost": 0}
	_next_target()


func stop() -> void:
	if job.is_empty():
		return
	var j := job
	job = {}
	reading = 0.0
	j.done.call(int(j.good), int(j.lost))


func mix(amount: float, cb: Callable) -> void:
	mix_t = 0.0
	mix_amount = amount
	mix_cb = cb


func _next_target() -> void:
	var spread: float = [0.0, 0.035, 0.11][clampi(int(job.mode), 0, 2)]
	job.tgt = 1.0 + randf_range(-spread * 0.6, spread)
	job.t = 0.0
	job.stepped = false


func _speed() -> float:
	if force_speed >= 0.0:
		return force_speed
	if G.test_mode:
		return 40.0
	return 3.5 if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)) else 1.0


func _process(dt: float) -> void:
	_clock += dt
	var sp := _speed()
	for p in packs:
		p.t = minf(1.0, float(p.t) + dt * 4.5 * sp)
	if mix_t >= 0.0:
		mix_t += dt * sp / 1.5
		tint = minf(1.0, tint + dt * sp * 0.5)
		if mix_t >= 1.0:
			mix_t = -1.0
			var cb := mix_cb
			mix_cb = Callable()
			if cb.is_valid():
				cb.call()
	elif not job.is_empty():
		job.t = float(job.t) + dt * sp / float(job.sec)
		var u := float(job.t)
		# ważenie: wskazanie rośnie i lekko drga, zanim się uspokoi
		var k := smoothstep(0.3, 0.62, u)
		reading = float(job.tgt) * k + sin(_clock * 38.0) * 0.03 * k * (1.0 - smoothstep(0.55, 0.72, u))
		if u >= 0.72 and not job.stepped:
			job.stepped = true
			var r: int = job.step.call()
			job.res = r
			if r < 0:
				stop()
				queue_redraw()
				return
			pile_g = maxf(0.0, pile_g - 1.0)
			if r == 1:
				job.good = int(job.good) + 1
				packs.append({"t": 0.0})
				Sfx.play("pack", -6.0)
			else:
				job.lost = int(job.lost) + 1
				var c := _scale_pos() + Vector2(0, -34)
				for i in range(9):
					spills.append({"p": c + Vector2(randf_range(-95, 95), randf_range(46, 78)), "r": randf_range(1.5, 3.4)})
				Sfx.play("miss", -4.0)
		if u >= 0.76:
			reading = lerpf(reading, 0.0, minf(1.0, dt * 14.0 * sp))
		if u >= 1.0:
			job.left = int(job.left) - 1
			if int(job.left) <= 0:
				stop()
			else:
				_next_target()
	if is_visible_in_tree():
		queue_redraw()


# ---------------------------------------------------------------- rysowanie
func _box(r: Rect2, c: Color, rad := 8, border := Color(0, 0, 0, 0), bw := 0) -> void:
	K.rbox(self, r, c, rad, border, bw)


func _tray_pos() -> Vector2:
	return Vector2(size.x * 0.165, size.y * 0.6)


func _scale_pos() -> Vector2:
	return Vector2(size.x * 0.46, size.y * 0.62)


func _slot(i: int) -> Vector2:
	var x0 := size.x * 0.635
	var per: int = maxi(4, int((size.x - x0 - 16.0) / 38.0))
	return Vector2(x0 + 19.0 + (i % per) * 38.0, size.y * 0.34 + int(i / float(per)) * 46.0)


func _slots_max() -> int:
	var per: int = maxi(4, int((size.x - size.x * 0.635 - 16.0) / 38.0))
	return per * 4


func _text(pos: Vector2, s: String, sz: int, c: Color, w := 200.0, al := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(_font, pos - Vector2(w * 0.5 if al == HORIZONTAL_ALIGNMENT_CENTER else 0.0, 0), s, al, w, sz, c)


func _tex(t: Texture2D, center: Vector2, sz: float, mod := Color.WHITE) -> void:
	if t != null:
		draw_texture_rect(t, Rect2(center - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, mod)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# blat: ciemne deski
	_box(Rect2(0, 0, w, h), Color(0.105, 0.082, 0.064), 12, Color(0, 0, 0, 0.5), 1)
	for i in range(1, 6):
		draw_line(Vector2(8, h * i / 6.0), Vector2(w - 8, h * i / 6.0), Color(0, 0, 0, 0.16), 1.0)
	for i in range(14):
		var kx := fmod(i * 173.3, w - 60.0) + 30.0
		var ky := fmod(i * 61.7, h - 20.0) + 10.0
		draw_line(Vector2(kx, ky), Vector2(kx + 26.0, ky), Color(1, 1, 1, 0.018), 1.0)
	# światło lampki nad wagą
	var sp := _scale_pos()
	for i in range(6):
		K.circle(self, sp + Vector2(0, -20), 250.0 - i * 34.0, Color(1.0, 0.86, 0.6, 0.012 + i * 0.004))

	# --- tacka z towarem
	var tp := _tray_pos()
	_box(Rect2(tp + Vector2(-122, -50), Vector2(244, 112)), Color(0, 0, 0, 0.3), 14)
	_box(Rect2(tp + Vector2(-118, -56), Vector2(236, 108)), Color(0.2, 0.215, 0.24), 12, Color(0.36, 0.38, 0.42), 2)
	_box(Rect2(tp + Vector2(-108, -47), Vector2(216, 90)), Color(0.13, 0.14, 0.16), 8)
	var frac := clampf(pile_g / maxf(1.0, pile_max), 0.0, 1.0)
	if pile_g > 0.01:
		var ps := lerpf(46.0, 104.0, sqrt(frac))
		var pc := Color(1, 1, 1).lerp(Color(0.86, 0.84, 0.7), tint * 0.8)
		_tex(K.tex("bulk_" + product), tp + Vector2(0, 4 - ps * 0.12), ps, pc)
	_text(tp + Vector2(0, -66), "TOWAR LUZEM", 12, K.C_DIM)
	_text(tp + Vector2(0, 76), "%s" % G.grams(pile_g), 22, K.C_TXT)

	# --- słoik z dodatkiem (tylko przy mieszaniu)
	if filler != "":
		var jp := tp + Vector2(96, -70)
		var rot := 0.0
		if mix_t >= 0.0:
			rot = -1.15 * sin(clampf(mix_t, 0.0, 1.0) * PI)
			var n := 14
			for i in range(n):
				var ph := fmod(_clock * 2.6 + i / float(n), 1.0)
				var a := jp + Vector2(-22, 6)
				var b := tp + Vector2(randf_range(-6, 6) + 10, 0)
				K.circle(self, a.lerp(b, ph) + Vector2(0, -sin(ph * PI) * 8.0), 2.2, Color(0.93, 0.92, 0.82, 0.9 * sin(clampf(mix_t, 0.0, 1.0) * PI)))
		draw_set_transform(jp, rot, Vector2.ONE)
		_tex(K.tex(filler), Vector2.ZERO, 58.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- waga
	_box(Rect2(sp + Vector2(-98, -18), Vector2(196, 84)), Color(0, 0, 0, 0.32), 14)
	_box(Rect2(sp + Vector2(-94, -24), Vector2(188, 80)), Color(0.74, 0.75, 0.78), 12, Color(0.5, 0.51, 0.55), 2)
	_box(Rect2(sp + Vector2(-70, 14), Vector2(140, 34)), Color(0.07, 0.13, 0.09), 5, Color(0.2, 0.3, 0.22), 1)
	var lcd := Color(0.45, 1.0, 0.62) if absf(reading - 1.0) < 0.045 or reading < 0.02 else Color(1.0, 0.82, 0.3)
	_text(sp + Vector2(0, 40), "%.2f g" % maxf(0.0, reading), 24, lcd, 136.0)
	# szalka
	draw_set_transform(sp + Vector2(0, -34), 0.0, Vector2(1.0, 0.36))
	K.circle(self, Vector2(0, 8), 80.0, Color(0, 0, 0, 0.28))
	K.circle(self, Vector2.ZERO, 78.0, Color(0.56, 0.58, 0.62))
	K.circle(self, Vector2.ZERO, 72.0, Color(0.82, 0.83, 0.86))
	K.circle(self, Vector2(-14, -10), 46.0, Color(0.9, 0.91, 0.93, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text(sp + Vector2(0, -78), scale_name.to_upper(), 12, K.C_DIM, 200.0)

	# --- rozsypane okruchy
	var pcol := Color.html(String(D.PRODUCTS[product].color))
	for s in spills:
		K.circle(self, s.p, float(s.r), pcol.darkened(0.15))

	# --- łyżka i towar na szalce
	var pan := sp + Vector2(0, -36)
	if not job.is_empty():
		var u := float(job.t)
		var top := tp + Vector2(10, -18)
		var pos := top
		var loaded := false
		if u < 0.36:
			var q := smoothstep(0.0, 0.36, u)
			pos = top.lerp(pan, q) + Vector2(0, -sin(q * PI) * 52.0)
			loaded = true
		elif u < 0.7:
			var q2 := smoothstep(0.36, 0.7, u)
			pos = pan.lerp(top + Vector2(34, -30), q2) + Vector2(0, -sin(q2 * PI) * 30.0)
		else:
			pos = top + Vector2(34, -30)
		if u >= 0.3 and u < 0.74:
			draw_set_transform(pan, 0.0, Vector2(1.0, 0.5))
			K.circle(self, Vector2.ZERO, 17.0 * smoothstep(0.3, 0.4, u), pcol)
			K.circle(self, Vector2(-4, -4), 9.0 * smoothstep(0.3, 0.4, u), pcol.lightened(0.18))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# łyżka: trzonek i miseczka
		draw_line(pos + Vector2(8, -6), pos + Vector2(58, -40), Color(0.2, 0.2, 0.22), 6.0, true)
		draw_line(pos + Vector2(8, -6), pos + Vector2(58, -40), Color(0.72, 0.73, 0.77), 4.0, true)
		K.circle(self, pos, 13.0, Color(0.2, 0.2, 0.22))
		K.circle(self, pos, 11.5, Color(0.78, 0.79, 0.82))
		if loaded:
			K.circle(self, pos + Vector2(0, -2), 8.5, pcol)

	# --- gotowe porcje
	var x0 := w * 0.635
	_box(Rect2(x0, h * 0.12, w - x0 - 12.0, h * 0.8), Color(0, 0, 0, 0.2), 10, Color(1, 1, 1, 0.05), 1)
	_text(Vector2(x0 + 12, h * 0.12 + 20), "GOTOWE WORECZKI", 12, K.C_DIM, 200.0, HORIZONTAL_ALIGNMENT_LEFT)
	var total := packs_before + packs.size()
	_text(Vector2(w - 24 - 100, h * 0.12 + 22), "×%d" % total, 18, K.C_ACC if total > 0 else K.C_DIM, 100.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var mx := _slots_max()
	var ptex := K.tex("pack_" + product)
	var first: int = maxi(0, total - mx)
	for i in range(first, total):
		var dst := _slot(i - first)
		var ni := i - packs_before
		if ni >= 0 and float(packs[ni].t) < 1.0:
			var q3 := float(packs[ni].t)
			var e := 1.0 - pow(1.0 - q3, 3.0)
			var fp := pan.lerp(dst, e) + Vector2(0, -sin(q3 * PI) * 40.0)
			_tex(ptex, fp, lerpf(52.0, 38.0, e))
		else:
			_tex(ptex, dst, 38.0)
	if first > 0:
		_text(Vector2(x0 + 12, h * 0.9), "+ %d wcześniejszych" % first, 12, K.C_DIM, 220.0, HORIZONTAL_ALIGNMENT_LEFT)
