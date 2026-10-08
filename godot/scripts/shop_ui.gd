extends RefCounted
## Okna sklepów w tym samym oszczędnym stylu co sprzedaż i ekwipunek: nazwa, jedna linijka stanu, mały przycisk z ceną.
## Opis pozycji pojawia się dopiero po najechaniu (w stopce okna) — na ekranie nie stoi ściana tekstu.

const K = preload("res://scripts/uikit.gd")
const T = preload("res://scripts/trade.gd")


## nagłówek okna i linijka z gotówką; `note` = dopisek obok (np. ile rzeczy czeka na stanie)
static func begin(U, title: String, sub: String, note := "", width := 640.0) -> void:
	U._open_modal(title, sub, "center", width, true)
	var top := K.hbox(8)
	top.add_child(K.lbl(G.money(G.S.cash), 17, T.C_HI))
	var l := K.lbl("przy sobie" + (("   •   " + note) if note != "" else ""), 11, T.C_LOW)
	l.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(l)
	U.modal_body.add_child(top)


## krótka uwaga pod nagłówkiem (jedyny kolor w oknie: ostrzeżenie)
static func alert(U, text: String) -> void:
	U.modal_body.add_child(K.wrap(text, 12, T.C_ALERT))


static func section(U, caption: String) -> VBoxContainer:
	var l := K.lbl(caption, 10, T.C_LOW)
	U.modal_body.add_child(l)
	var v := K.vbox(1)
	U.modal_body.add_child(v)
	return v


## Wiersz sklepu. o: name, sub, desc, icon, dim (bool: już niedostępne), alert (bool: sub na czerwono),
## price (napis na przycisku), block (powód blokady zamiast ceny albo "-" = sama cena, ale nieaktywna), cb,
## extra = [[napis, wywołanie], …] — dodatkowe małe przyciski tekstowe.
static func row(U, box: Node, o: Dictionary) -> void:
	var p := PanelContainer.new()
	var idle := T._flat(0.0, 0.0, 8, 4, 6)
	var hot := T._flat(0.045, 0.1, 8, 4, 6)
	p.add_theme_stylebox_override("panel", idle)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := K.hbox(10)
	p.add_child(h)
	var ic_name := String(o.get("icon", ""))
	if ic_name != "":
		var ic := K.icon(ic_name, 26.0 if K.is_item(ic_name) else 16.0, T.C_MID)
		ic.custom_minimum_size = Vector2(28, 26)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var v := K.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(K.lbl(String(o.name), 14, T.C_MID if o.get("dim", false) else T.C_HI))
	var sub := String(o.get("sub", ""))
	if sub != "":
		v.add_child(K.lbl(sub, 11, T.C_ALERT if o.get("alert", false) else (T.C_LOW if o.get("dim", false) else T.C_MID)))
	h.add_child(v)
	var name := String(o.name)
	var desc := String(o.get("desc", ""))
	var show := func():
		p.add_theme_stylebox_override("panel", hot)
		hint(U, name, desc)
	var hide := func():
		if not p.get_global_rect().has_point(p.get_global_mouse_position()):
			p.add_theme_stylebox_override("panel", idle)
	p.mouse_entered.connect(show)
	p.mouse_exited.connect(hide)
	for e in o.get("extra", []):
		var xb: Button = T._mini(String(e[0]), _click(e[1]), "text")
		xb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		xb.mouse_entered.connect(show)
		h.add_child(xb)
	if o.has("price"):
		var block := String(o.get("block", ""))
		var b: Button = T._mini(String(o.price) if (block == "" or block == "-") else block, _click(o.get("cb", Callable())), "strong" if block == "" else "box")
		b.disabled = block != ""
		b.custom_minimum_size.x = 78
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.mouse_entered.connect(show)
		h.add_child(b)
	box.add_child(p)


static func _click(cb: Callable) -> Callable:
	if not cb.is_valid():
		return Callable()
	return func():
		Sfx.play("click")
		cb.call()


## stopka okna: opis pozycji pod kursorem; na początku krótka wskazówka
static func foot(U, text: String) -> void:
	var line := ColorRect.new()
	line.color = T.C_EDGE
	line.custom_minimum_size = Vector2(0, 1)
	U.modal_foot.add_child(line)
	var l := K.wrap(text, 12, T.C_MID)
	l.custom_minimum_size.y = 36
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	U.modal_foot.add_child(l)
	U.shop_hint = l


static func hint(U, name: String, desc: String) -> void:
	if U.shop_hint != null and is_instance_valid(U.shop_hint) and desc != "":
		U.shop_hint.text = "%s — %s" % [name, desc]
