extends Control
## Tarcza zegara do wyboru pory spotkania: cała doba na obwodzie (góra = północ, dół = południe, noc ciemna,
## dzień jasny). Wskazówkę ustawia się kliknięciem albo przeciąganiem. Dozwolony jest tylko jasny łuk
## „dziś, od teraz” — następnego dnia wybrać się nie da.

const K = preload("res://scripts/uikit.gd")

signal changed(t: float)

var now := 0.0          # bieżący czas gry (minuty od początku gry)
var lo := 0.0           # najwcześniejsza dozwolona pora
var hi := 0.0           # najpóźniejsza dozwolona pora
var value := 0.0        # wybrana pora
var step := 10.0        # co ile minut skacze wskazówka przy przeciąganiu
var _drag := false
var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(216, 216)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var f := "res://assets/fonts/barlowc.ttf"
	_font = load(f) if ResourceLoader.exists(f) else get_theme_default_font()


func setup(now_t: float, lo_t: float, hi_t: float, start_t: float) -> void:
	now = now_t
	lo = lo_t
	hi = maxf(hi_t, lo_t)
	value = clampf(start_t, lo, hi)
	queue_redraw()


## przesuwa wybraną porę o `delta` minut (przyciski pod tarczą)
func nudge(delta: float) -> void:
	set_value(value + delta)


func set_value(t: float) -> void:
	var v := clampf(t, lo, hi)
	if absf(v - value) > 0.01:
		value = v
		changed.emit(value)
	queue_redraw()


## kąt na tarczy dla minuty doby: 0:00 u góry, zgodnie z ruchem wskazówek
static func angle_of(minute_of_day: float) -> float:
	return fposmod(minute_of_day, 1440.0) / 1440.0 * TAU - PI * 0.5


## pora (czas gry) dla punktu na tarczy: najbliższa dozwolona, zaokrąglona do kroku
func time_at(pos: Vector2) -> float:
	var c := size * 0.5
	var a := (pos - c).angle() + PI * 0.5
	var m := fposmod(a, TAU) / TAU * 1440.0
	var day0 := floorf(lo / 1440.0) * 1440.0
	var t := day0 + m
	# późny wieczór: dozwolony łuk może przechodzić przez północ
	if t < lo - 720.0:
		t += 1440.0
	t = roundf(t / step) * step
	# punkt poza dozwolonym łukiem: bliższy z jego końców
	if t < lo or t > hi:
		var d_lo := absf(angle_difference(angle_of(t), angle_of(lo)))
		var d_hi := absf(angle_difference(angle_of(t), angle_of(hi)))
		t = lo if d_lo <= d_hi else hi
	return clampf(t, lo, hi)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		if ev.pressed:
			set_value(time_at(ev.position))
		accept_event()
	elif ev is InputEventMouseMotion and _drag:
		set_value(time_at(ev.position))
		accept_event()


func _arc(c: Vector2, r: float, m0: float, m1: float, col: Color, w: float) -> void:
	if m1 <= m0:
		return
	var n := maxi(4, int((m1 - m0) / 12.0))
	draw_arc(c, r, angle_of(m0), angle_of(m0) + (m1 - m0) / 1440.0 * TAU, n, col, w, true)


func _text(pos: Vector2, s: String, sz: int, col: Color, w := 120.0) -> void:
	draw_string(_font, pos - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_CENTER, w, sz, col)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 6.0
	# tarcza: noc (21–6) granatowa, dzień jaśniejszy
	draw_circle(c, r, Color(0.06, 0.075, 0.11))
	_arc(c, r - 9.0, 360.0, 1260.0, Color(0.35, 0.42, 0.52, 0.5), 14.0)
	_arc(c, r - 9.0, 1260.0, 1440.0 + 360.0, Color(0.12, 0.15, 0.26, 0.9), 14.0)
	draw_arc(c, r, 0.0, TAU, 96, Color(1, 1, 1, 0.16), 1.5, true)
	# dozwolony łuk: dziś, od teraz
	var m_lo := fposmod(lo, 1440.0)
	_arc(c, r - 9.0, m_lo, m_lo + (hi - lo), K.C_ACC, 5.0)
	# godziny
	for h in range(24):
		var a := angle_of(h * 60.0)
		var dir := Vector2(cos(a), sin(a))
		var major := h % 3 == 0
		draw_line(c + dir * (r - (22.0 if major else 19.0)), c + dir * (r - 16.5), Color(1, 1, 1, 0.55 if major else 0.22), 1.6 if major else 1.0, true)
		if major:
			_text(c + dir * (r - 33.0) + Vector2(0, 4.5), str(h), 12, Color(0.86, 0.89, 0.95, 0.9), 30.0)
	# znaczek „teraz”
	var an := angle_of(now)
	var dn := Vector2(cos(an), sin(an))
	draw_circle(c + dn * (r - 9.0), 4.0, Color(1.0, 0.82, 0.3))
	# wskazówka
	var av := angle_of(value)
	var dv := Vector2(cos(av), sin(av))
	draw_line(c + dv * 34.0, c + dv * (r - 13.0), Color(0, 0, 0, 0.5), 6.0, true)
	draw_line(c + dv * 34.0, c + dv * (r - 13.0), Color.WHITE, 3.0, true)
	draw_circle(c + dv * (r - 9.0), 8.0, Color(0, 0, 0, 0.45))
	draw_circle(c + dv * (r - 9.0), 6.5, K.C_ACC)
	draw_circle(c + dv * (r - 9.0), 2.5, Color.WHITE)
	# środek: wybrana pora i za ile to jest
	draw_circle(c, 33.0, Color(0.09, 0.11, 0.16))
	draw_arc(c, 33.0, 0.0, TAU, 48, Color(1, 1, 1, 0.14), 1.0, true)
	var mod := int(fposmod(value, 1440.0))
	_text(c + Vector2(0, 4.0), "%d:%02d" % [int(mod / 60.0), mod % 60], 22, Color.WHITE, 66.0)
	var ahead := int(round(value - now))
	var in_txt := ("za %d min" % ahead) if ahead < 60 else ("za %d h %02d" % [int(ahead / 60.0), ahead % 60])
	_text(c + Vector2(0, 19.0), in_txt, 10, Color(0.75, 0.8, 0.9, 0.85), 66.0)
