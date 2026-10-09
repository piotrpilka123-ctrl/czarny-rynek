extends RefCounted
## Klocki interfejsu: kolory, style, przyciski, ikony (Lucide, licencja ISC).

# tła okien: grafit bez granatowego odcienia (ten sam ton co panel sprzedaży i ekwipunek)
const C_BG := Color(0.036, 0.04, 0.05, 0.96)
const C_PANEL := Color(0.048, 0.053, 0.066, 0.95)
const C_CARD := Color(0.074, 0.08, 0.096, 1.0)
const C_CARD2 := Color(0.1, 0.107, 0.127, 1.0)
const C_LINE := Color(0.17, 0.18, 0.215)
const C_TXT := Color(0.9, 0.91, 0.94)
const C_DIM := Color(0.56, 0.59, 0.66)
const C_ACC := Color(0.29, 0.87, 0.5)
const C_WARN := Color(0.98, 0.75, 0.14)
const C_BAD := Color(0.94, 0.3, 0.3)
const C_BLUE := Color(0.38, 0.65, 0.98)
const C_GOLD := Color(0.98, 0.8, 0.3)
const C_PINK := Color(0.93, 0.35, 0.8)

static var _ico := {}


static func sb(bg: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 0, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s


static func theme() -> Theme:
	var th := Theme.new()
	var f := "res://assets/fonts/barlow.ttf"
	if ResourceLoader.exists(f):
		th.default_font = load(f)
	th.default_font_size = 15
	th.set_stylebox("normal", "Button", sb(Color(0.11, 0.135, 0.2), 8, Color(0.2, 0.23, 0.32), 1, 12))
	th.set_stylebox("hover", "Button", sb(Color(0.15, 0.185, 0.27), 8, Color(0.28, 0.32, 0.48), 1, 12))
	th.set_stylebox("pressed", "Button", sb(Color(0.09, 0.11, 0.16), 8, Color(0.28, 0.32, 0.48), 1, 12))
	th.set_stylebox("disabled", "Button", sb(Color(0.08, 0.09, 0.12), 8, Color(0.13, 0.15, 0.2), 1, 12))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C_TXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.4, 0.42, 0.48))
	th.set_stylebox("panel", "PanelContainer", sb(C_PANEL, 12, C_LINE, 1, 14))
	th.set_color("font_color", "Label", C_TXT)
	th.set_color("default_color", "RichTextLabel", C_TXT)
	th.set_stylebox("background", "ProgressBar", pill(Color(0.1, 0.12, 0.18), 3))
	th.set_stylebox("fill", "ProgressBar", pill(C_ACC, 3))
	th.set_stylebox("panel", "TooltipPanel", sb(Color(0.02, 0.025, 0.04, 0.97), 6, C_LINE, 1, 8))
	th.set_color("font_color", "TooltipLabel", C_TXT)
	return th


static func lbl(text: String, size := 15, color := C_TXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## nagłówek / liczby: czcionka Barlow Condensed
static func head(text: String, size := 16, color := C_TXT) -> Label:
	var l := lbl(text, size, color)
	var f := "res://assets/fonts/barlowc.ttf"
	if ResourceLoader.exists(f):
		l.add_theme_font_override("font", load(f))
	return l


static func wrap(text: String, size := 14, color := C_TXT, width := 0.0) -> Label:
	var l := lbl(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
	return l


static func rich(bb: String, size := 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.text = bb
	return r


static func btn(text: String, cb: Callable, kind := "", small := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if small:
		b.add_theme_font_size_override("font_size", 13)
	var pad := 8 if small else 12
	var r := 7 if small else 8
	if kind == "go":
		# główna czynność: jasna obwódka i biały napis zamiast zielonej plamy (kolor zostaje dla ostrzeżeń)
		b.add_theme_stylebox_override("normal", sb(Color(1, 1, 1, 0.09), r, Color(1, 1, 1, 0.38), 1, pad))
		b.add_theme_stylebox_override("hover", sb(Color(1, 1, 1, 0.16), r, Color(1, 1, 1, 0.52), 1, pad))
		b.add_theme_stylebox_override("pressed", sb(Color(1, 1, 1, 0.22), r, Color(1, 1, 1, 0.6), 1, pad))
		b.add_theme_stylebox_override("disabled", sb(Color(1, 1, 1, 0.02), r, Color(1, 1, 1, 0.08), 1, pad))
		b.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	elif kind == "bad":
		b.add_theme_stylebox_override("normal", sb(Color(0.4, 0.11, 0.11), r, Color(0.6, 0.15, 0.15), 1, pad))
		b.add_theme_stylebox_override("hover", sb(Color(0.52, 0.14, 0.14), r, Color(0.6, 0.15, 0.15), 1, pad))
	elif kind == "warn":
		b.add_theme_stylebox_override("normal", sb(Color(0.4, 0.2, 0.05), r, Color(0.65, 0.33, 0.05), 1, pad))
		b.add_theme_stylebox_override("hover", sb(Color(0.5, 0.26, 0.07), r, Color(0.65, 0.33, 0.05), 1, pad))
	elif kind == "flat":
		b.add_theme_stylebox_override("normal", sb(Color(0, 0, 0, 0), r, Color(0, 0, 0, 0), 0, pad))
		b.add_theme_stylebox_override("hover", sb(Color(1, 1, 1, 0.06), r, Color(0, 0, 0, 0), 0, pad))
		b.add_theme_stylebox_override("pressed", sb(Color(1, 1, 1, 0.1), r, Color(0, 0, 0, 0), 0, pad))
	else:
		# zwykły przycisk (także duży, np. odpowiedź w rozmowie): grafit bez granatowego odcienia
		b.add_theme_stylebox_override("normal", sb(Color(1, 1, 1, 0.04), r, Color(1, 1, 1, 0.13), 1, pad))
		b.add_theme_stylebox_override("hover", sb(Color(1, 1, 1, 0.09), r, Color(1, 1, 1, 0.24), 1, pad))
		b.add_theme_stylebox_override("pressed", sb(Color(1, 1, 1, 0.14), r, Color(1, 1, 1, 0.3), 1, pad))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func flow(sep := 6) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


static func panel(style: StyleBox = null) -> PanelContainer:
	var p := PanelContainer.new()
	if style != null:
		p.add_theme_stylebox_override("panel", style)
	return p


static func card(parent: Node, pad := 12, bg := C_CARD) -> VBoxContainer:
	var p := panel(sb(bg, 12, C_LINE, 1, pad))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := vbox(5)
	p.add_child(v)
	return v


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func tex(name: String) -> Texture2D:
	if not _ico.has(name):
		# rysowane ikony przedmiotów (assets/items) mają pierwszeństwo przed prostymi ikonami interfejsu
		var pi := "res://assets/items/%s.png" % name
		var p := "res://assets/icons/%s.svg" % name
		_ico[name] = load(pi) if ResourceLoader.exists(pi) else (load(p) if ResourceLoader.exists(p) else null)
	return _ico[name]


## czy to kolorowa ikona przedmiotu (nie barwimy jej)
static func is_item(name: String) -> bool:
	return ResourceLoader.exists("res://assets/items/%s.png" % name)


static func icon(name: String, size := 18.0, color := C_TXT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = Color.WHITE if is_item(name) else color
	if is_item(name):
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## Zaokrąglony pasek z tekstury (dziewięć pól) zamiast StyleBoxFlat. Powód: StyleBoxFlat z zaokrągleniem,
## koła, łuki i wielokąty to dla karty graficznej nowe bufory przy każdym przerysowaniu — rysowane co klatkę
## wstrzymują ją i czas klatki rośnie dwukrotnie. Prostokąty, linie, tekst i tekstury tego nie robią.
static var _pill_tex := {}
static var _pill_sb := {}

static func pill_tex(radius: int) -> ImageTexture:
	if _pill_tex.has(radius):
		return _pill_tex[radius]
	var n := radius * 2 + 2
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n * 0.5, n * 0.5)
	for y in range(n):
		for x in range(n):
			# odległość od środkowego kwadratu 2×2 — wygładzona krawędź koła
			var d := (Vector2(x + 0.5, y + 0.5) - c).abs() - Vector2(1.0, 1.0)
			var dist := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(float(radius) - dist + 0.5, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_pill_tex[radius] = t
	return t


static func pill(color: Color, radius := 4) -> StyleBoxTexture:
	var key := "%s|%d" % [color.to_html(), radius]
	if _pill_sb.has(key):
		return _pill_sb[key]
	var s := StyleBoxTexture.new()
	s.texture = pill_tex(radius)
	s.set_texture_margin_all(float(radius))
	s.modulate_color = color
	_pill_sb[key] = s
	return s


# ---------------------------------------------------------------- rysowanie, które nie wstrzymuje karty graficznej
# Zamienniki draw_circle / draw_arc / draw_polyline / draw_colored_polygon / zaokrąglonych ramek dla wszystkiego,
# co przerysowuje się co klatkę (celownik, znaczniki, mapa, animowane panele).
static var _disc := {}
static var _ringt := {}

static func _bucket(r: float) -> int:
	for b in [4, 8, 16, 32, 64, 128]:
		if r * 2.0 <= float(b):
			return b
	return 128


## białe koło (promień `px` tekseli) albo pierścień o grubości `tpx`
static func disc_tex(px: int, tpx := 0) -> ImageTexture:
	var key := px * 1000 + tpx
	var store: Dictionary = _disc if tpx == 0 else _ringt
	if store.has(key):
		return store[key]
	var n := px * 2
	var data := PackedByteArray()
	data.resize(n * n * 4)
	data.fill(255)
	for y in range(px):
		var dy := float(px) - (y + 0.5)
		for x in range(px):
			var dx := float(px) - (x + 0.5)
			var dist := sqrt(dx * dx + dy * dy)
			var a := clampf(float(px) - dist + 0.5, 0.0, 1.0)
			if tpx > 0:
				a *= clampf(dist - float(px - tpx) + 0.5, 0.0, 1.0)
			var v := int(a * 255.0)
			# cztery ćwiartki naraz
			data[(y * n + x) * 4 + 3] = v
			data[(y * n + (n - 1 - x)) * 4 + 3] = v
			data[((n - 1 - y) * n + x) * 4 + 3] = v
			data[((n - 1 - y) * n + (n - 1 - x)) * 4 + 3] = v
	var t := ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data))
	store[key] = t
	return t


static func circle(cv: CanvasItem, pos: Vector2, r: float, color: Color) -> void:
	if r <= 0.05 or color.a <= 0.0:
		return
	cv.draw_texture_rect(disc_tex(_bucket(r)), Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, color)


## pierścień o stałym rozmiarze (tekstura); do zmiennych promieni lepszy jest `arc`
static func ring(cv: CanvasItem, pos: Vector2, r: float, color: Color, w := 1.5) -> void:
	var outer := r + w * 0.5
	var px := _bucket(outer)
	var t := disc_tex(px, maxi(1, int(round(w / outer * float(px)))))
	cv.draw_texture_rect(t, Rect2(pos - Vector2(outer, outer), Vector2(outer, outer) * 2.0), false, color)


static func arc(cv: CanvasItem, c: Vector2, r: float, a0: float, a1: float, n: int, color: Color, w := 1.0) -> void:
	var prev := c + Vector2(cos(a0), sin(a0)) * r
	for i in range(1, n + 1):
		var a := lerpf(a0, a1, float(i) / float(n))
		var pt := c + Vector2(cos(a), sin(a)) * r
		cv.draw_line(prev, pt, color, w, true)
		prev = pt


static func polyline(cv: CanvasItem, pts: PackedVector2Array, color: Color, w := 1.0) -> void:
	for i in range(pts.size() - 1):
		cv.draw_line(pts[i], pts[i + 1], color, w, true)
	if w >= 3.0 and color.a >= 0.99:
		for i in range(1, pts.size() - 1):
			circle(cv, pts[i], w * 0.5, color)


static func poly(cv: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	var cols := PackedColorArray([color])
	var no_uv := PackedVector2Array()
	if pts.size() == 3:
		cv.draw_primitive(pts, cols, no_uv)
		return
	var tri := Geometry2D.triangulate_polygon(pts)
	for i in range(0, tri.size() - 2, 3):
		cv.draw_primitive(PackedVector2Array([pts[tri[i]], pts[tri[i + 1]], pts[tri[i + 2]]]), cols, no_uv)


static func _corners(cv: CanvasItem, t: Texture2D, r: Rect2, q: float, c: Color) -> void:
	var px := float(t.get_width()) * 0.5
	cv.draw_texture_rect_region(t, Rect2(r.position, Vector2(q, q)), Rect2(0, 0, px, px), c)
	cv.draw_texture_rect_region(t, Rect2(r.position + Vector2(r.size.x - q, 0), Vector2(q, q)), Rect2(px, 0, px, px), c)
	cv.draw_texture_rect_region(t, Rect2(r.position + Vector2(0, r.size.y - q), Vector2(q, q)), Rect2(0, px, px, px), c)
	cv.draw_texture_rect_region(t, Rect2(r.end - Vector2(q, q), Vector2(q, q)), Rect2(px, px, px, px), c)


## zaokrąglona ramka z wypełnieniem i obwódką (jak StyleBoxFlat, ale z prostokątów i ćwiartek koła z tekstury)
static func rbox(cv: CanvasItem, r: Rect2, c: Color, rad := 8, border := Color(0, 0, 0, 0), bw := 0) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var q := minf(float(rad), minf(r.size.x, r.size.y) * 0.5)
	if q < 0.75:
		if c.a > 0.0:
			cv.draw_rect(r, c)
		q = 0.0
	elif c.a > 0.0:
		_corners(cv, disc_tex(_bucket(q)), r, q, c)
		cv.draw_rect(Rect2(r.position + Vector2(q, 0), Vector2(r.size.x - 2.0 * q, r.size.y)), c)
		cv.draw_rect(Rect2(r.position + Vector2(0, q), Vector2(q, r.size.y - 2.0 * q)), c)
		cv.draw_rect(Rect2(r.position + Vector2(r.size.x - q, q), Vector2(q, r.size.y - 2.0 * q)), c)
	if bw > 0 and border.a > 0.0:
		var b := float(bw)
		if q > 0.0:
			var px := _bucket(q)
			_corners(cv, disc_tex(px, maxi(1, int(round(b / q * float(px))))), r, q, border)
		cv.draw_rect(Rect2(r.position + Vector2(q, 0), Vector2(r.size.x - 2.0 * q, b)), border)
		cv.draw_rect(Rect2(r.position + Vector2(q, r.size.y - b), Vector2(r.size.x - 2.0 * q, b)), border)
		cv.draw_rect(Rect2(r.position + Vector2(0, q), Vector2(b, r.size.y - 2.0 * q)), border)
		cv.draw_rect(Rect2(r.position + Vector2(r.size.x - b, q), Vector2(b, r.size.y - 2.0 * q)), border)


static func bar(value: float, maxv: float, color := C_ACC, h := 7.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = maxv
	b.value = value
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("fill", pill(color, clampi(int(h * 0.5), 1, 4)))
	b.add_theme_stylebox_override("background", pill(Color(0.1, 0.12, 0.18), clampi(int(h * 0.5), 1, 4)))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func hexc(c: Color) -> String:
	return "#" + c.to_html(false)


static func col(text: String, c: Color) -> String:
	return "[color=%s]%s[/color]" % [hexc(c), text]


## opis jakości towaru: bez kolorów i nazw klas — zawsze ten sam szary napis z czystością w procentach
static func tier_bb(pur) -> String:
	return "[color=#9aa3b2]czystość %d%%%s[/color]" % [int(pur), " • mieszanka" if G.is_mix(pur) else ""]


## „Łapka” samouczka: kołysząca się dłoń przy kontrolce, którą trzeba teraz kliknąć (znika razem z nią)
static func point_hand(target: Control, offset := Vector2(-34, 4)) -> void:
	var hnd := icon("hand", 26.0, Color(1.0, 0.86, 0.35))
	hnd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hnd.z_index = 30
	hnd.position = offset
	hnd.rotation = -0.5
	target.add_child(hnd)
	var tw := hnd.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_loops()
	tw.tween_property(hnd, "position:x", offset.x + 9.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hnd, "position:x", offset.x, 0.45).set_trans(Tween.TRANS_SINE)


static func icon_label(ic: String, text: String, size := 14, color := C_TXT, isize := 16.0) -> HBoxContainer:
	var h := hbox(5)
	h.add_child(icon(ic, isize, color))
	h.add_child(lbl(text, size, color))
	return h
