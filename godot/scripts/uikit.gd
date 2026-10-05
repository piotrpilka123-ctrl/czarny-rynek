extends RefCounted
## Klocki interfejsu: kolory, style, przyciski, ikony (Lucide, licencja ISC).

const C_BG := Color(0.035, 0.043, 0.062, 0.96)
const C_PANEL := Color(0.055, 0.067, 0.094, 0.95)
const C_CARD := Color(0.085, 0.102, 0.15, 1.0)
const C_CARD2 := Color(0.11, 0.13, 0.19, 1.0)
const C_LINE := Color(0.17, 0.2, 0.27)
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
	th.set_stylebox("background", "ProgressBar", sb(Color(0.1, 0.12, 0.18), 4, Color(0, 0, 0, 0), 0, 0))
	th.set_stylebox("fill", "ProgressBar", sb(C_ACC, 4, Color(0, 0, 0, 0), 0, 0))
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
		b.add_theme_stylebox_override("normal", sb(Color(0.13, 0.62, 0.3), r, Color(0.09, 0.5, 0.25), 1, pad))
		b.add_theme_stylebox_override("hover", sb(Color(0.18, 0.75, 0.38), r, Color(0.09, 0.5, 0.25), 1, pad))
		b.add_theme_stylebox_override("pressed", sb(Color(0.1, 0.5, 0.25), r, Color(0.09, 0.5, 0.25), 1, pad))
		b.add_theme_color_override("font_color", Color(0.02, 0.1, 0.04))
		b.add_theme_color_override("font_hover_color", Color(0.02, 0.1, 0.04))
		b.add_theme_color_override("font_pressed_color", Color(0.02, 0.1, 0.04))
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
	elif small:
		b.add_theme_stylebox_override("normal", sb(Color(0.11, 0.135, 0.2), r, Color(0.2, 0.23, 0.32), 1, pad))
		b.add_theme_stylebox_override("hover", sb(Color(0.15, 0.185, 0.27), r, Color(0.28, 0.32, 0.48), 1, pad))
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
		var p := "res://assets/icons/%s.svg" % name
		_ico[name] = load(p) if ResourceLoader.exists(p) else null
	return _ico[name]


static func icon(name: String, size := 18.0, color := C_TXT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


static func bar(value: float, maxv: float, color := C_ACC, h := 7.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = maxv
	b.value = value
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("fill", sb(color, 4, Color(0, 0, 0, 0), 0, 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func hexc(c: Color) -> String:
	return "#" + c.to_html(false)


static func col(text: String, c: Color) -> String:
	return "[color=%s]%s[/color]" % [hexc(c), text]


static func tier_bb(pur) -> String:
	var t: int = G.tier(pur)
	return "[color=#%s]%s %d%%[/color]%s" % [D.TIER_COLOR[t], D.TIER_NAMES[t], int(pur), " [color=#c98a3a](mieszanka)[/color]" if int(pur) < 65 else ""]


static func icon_label(ic: String, text: String, size := 14, color := C_TXT, isize := 16.0) -> HBoxContainer:
	var h := hbox(5)
	h.add_child(icon(ic, isize, color))
	h.add_child(lbl(text, size, color))
	return h
