extends RefCounted
## Okno wymiany przy sprzedaży — małe i spokojne. Po lewej to, co masz przy sobie; paczki przeciągasz na TACĘ
## (pole zrzutu) i w małym okienku wybierasz, ile ich kładziesz. Pod tacą jeden rząd: suma za całość
## (−10 / −1 / +1 / +10 zł) z ceną za gram, a po prawej „Poczekaj”, „Odwołaj” i „Potwierdź” (przytrzymaj).
## Możesz dać więcej, niż klient zamówił (doceni to), albo mniej — wtedy taca pokazuje w procentach,
## jaka jest szansa, że weźmie towar i zapłaci pełną sumę. Świat się w tym czasie nie zatrzymuje.
## Wygląd: szarości i biel, bez kolorowych wypełnień; kolor zostaje tylko dla ostrzeżeń (patrol, wpadka).
## Logika siedzi w game.gd: deal_start / deal_offer_add / deal_short_chance / deal_hand.

const K = preload("res://scripts/uikit.gd")

const C_HI := Color(0.94, 0.95, 0.97)          # to, co ważne
const C_MID := Color(0.66, 0.69, 0.74)         # zwykły tekst pomocniczy
const C_LOW := Color(1, 1, 1, 0.36)            # podpisy
const C_ALERT := Color(0.9, 0.52, 0.5)         # jedyny kolor: ostrzeżenie
const C_PANEL := Color(0.04, 0.046, 0.058, 0.95)
const C_EDGE := Color(1, 1, 1, 0.09)


static func panel_style(pad := 10) -> StyleBoxFlat:
	return K.sb(C_PANEL, 10, C_EDGE, 1, pad)


static func _flat(bg_a: float, edge_a: float, pad_x := 8, pad_y := 3, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, bg_a)
	s.set_corner_radius_all(radius)
	if edge_a > 0.0:
		s.border_color = Color(1, 1, 1, edge_a)
		s.set_border_width_all(1)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


## mały, płaski przycisk: "box" — cienka ramka, "text" — sam napis, "strong" — jaśniejsza ramka (akcja główna)
static func _mini(text: String, cb: Callable, kind := "box") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_font_size_override("font_size", 12)
	var edge := 0.0 if kind == "text" else (0.34 if kind == "strong" else 0.13)
	var base := 0.0 if kind == "text" else (0.07 if kind == "strong" else 0.035)
	b.add_theme_stylebox_override("normal", _flat(base, edge))
	b.add_theme_stylebox_override("hover", _flat(base + 0.06, edge + 0.1))
	b.add_theme_stylebox_override("pressed", _flat(base + 0.11, edge + 0.16))
	b.add_theme_stylebox_override("disabled", _flat(0.0 if kind == "text" else 0.02, 0.0 if kind == "text" else 0.07))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var fc: Color = C_MID if kind == "text" else C_HI
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.28))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func _zone_style(hot: bool, filled: bool) -> StyleBoxFlat:
	if hot:
		return _flat(0.07, 0.55, 10, 7, 8)
	return _flat(0.02, 0.2 if filled else 0.13, 10, 7, 8)


## „kto patrzy”: świadkowie w pobliżu i patrol, który ma Was na oku (szare, dopóki nic nie grozi)
static func watch_row(U) -> Control:
	var h := K.hbox(6)
	var w: Dictionary = G.deal_watchers()
	var n := int(w.witnesses)
	U.deal_cop_l = K.icon_label("siren", "patrol patrzy", 11, C_ALERT, 12.0)
	U.deal_cop_l.visible = float(U.deal.cop_t) > 0.05
	h.add_child(U.deal_cop_l)
	U.cop_bar = K.bar(float(U.deal.cop_t), float(U.deal.cop_max), C_ALERT, 4.0)
	U.cop_bar.custom_minimum_size = Vector2(60, 4)
	U.cop_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	U.cop_bar.visible = U.deal_cop_l.visible
	h.add_child(U.cop_bar)
	U.deal_watch_l = K.lbl(watch_text(n), 11, watch_color(n))
	h.add_child(U.deal_watch_l)
	return h


static func watch_text(n: int) -> String:
	return "nikt nie patrzy" if n == 0 else ("w pobliżu: %d %s" % [n, "osoba" if n == 1 else ("osoby" if n < 5 else "osób")])


static func watch_color(n: int) -> Color:
	return C_LOW if n == 0 else (C_HI if n <= 2 else C_ALERT)


# ---------------------------------------------------------------- przeciąganie
static func _can_drop(data: Variant, to_tray: bool) -> bool:
	if not (data is Dictionary) or not data.has("deal"):
		return false
	return String(data.from) == ("bag" if to_tray else "tray")


## upuszczenie na tacę: jedna paczka idzie od razu, przy większej liczbie pojawia się okienko „ile”
static func _drop_tray(U, data: Variant) -> void:
	var e: Dictionary = data.deal
	place(U, String(e.p), int(e.pur), int(e.g))


static func place(U, p: String, pur: int, g: int) -> void:
	var deal: Dictionary = U.deal
	var have: int = G.deal_have(deal, p, pur, g)
	if have <= 1:
		var why: String = G.deal_offer_add(deal, p, pur, g, 1)
		if why != "":
			G.notify(why, "warn")
			Sfx.play("error")
		else:
			Sfx.play("tick")
		U._render_deal()
		return
	if p != String(deal.ctx.product) and not deal.ctx.get("sting", false):
		G.notify(G.deal_offer_add(deal, p, pur, g, 1), "warn")
		Sfx.play("error")
		return
	ask(U, p, pur, g, have)


static func _drag_preview(icon: String, text: String) -> Control:
	var st := _flat(0.0, 0.4, 7, 4)
	st.bg_color = Color(0.06, 0.07, 0.09, 0.96)
	var pv := K.panel(st)
	var h := K.hbox(6)
	pv.add_child(h)
	h.add_child(K.icon(icon, 26))
	h.add_child(K.lbl(text, 13, C_HI))
	var holder := Control.new()
	holder.add_child(pv)
	pv.position = Vector2(12, 8)
	holder.z_index = 100
	return holder


# ---------------------------------------------------------------- lewa strona: co masz przy sobie
static func _bag_row(U, e: Dictionary, left: int, fits: bool) -> Control:
	var kind := String(e.kind)
	var live: bool = fits and left > 0 and kind == "pack"
	var p := K.panel(_flat(0.03, 0.0, 8, 5, 6))
	p.modulate.a = 1.0 if live else 0.4
	var h := K.hbox(9)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic := String(e.icon)
	var ib := CenterContainer.new()
	ib.custom_minimum_size = Vector2(32, 32)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.add_child(K.icon(ic, 32.0 if K.is_item(ic) else 20.0, C_MID))
	h.add_child(ib)
	var v := K.vbox(-2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := K.lbl(String(e.name), 14, C_HI)
	nl.clip_text = true
	v.add_child(nl)
	var sub := String(e.sub)
	if kind == "pack":
		sub = "%d%%%s  •  %s" % [int(e.pur), " mieszanka" if G.is_mix(e.pur) else "", String(e.sub)]
		if left <= 0:
			sub = "wszystko na tacy"
	elif kind == "bulk":
		sub = "%d%%  •  luzem — najpierw zapakuj" % int(e.pur)
	elif sub == "":
		sub = "przedmiot"
	var sl := K.lbl(sub, 11, C_LOW)
	sl.clip_text = true
	v.add_child(sl)
	h.add_child(v)
	var cnt := K.head(("× %d" % left) if kind == "pack" else String(e.qty), 15 if kind == "pack" else 12, C_HI if live else C_MID)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(cnt)
	if kind != "pack":
		p.tooltip_text = "Towar luzem. Klientowi podajesz tylko paczki — zapakuj go przy wadze." if kind == "bulk" else String(e.name)
		return p
	if not fits:
		p.tooltip_text = "%s chce %s." % [String(U.deal.who.name), String(D.PRODUCT_GEN[U.deal.ctx.product])]
	if not live:
		return p
	p.mouse_default_cursor_shape = Control.CURSOR_DRAG
	p.tooltip_text = "Przeciągnij na tacę (albo kliknij)."
	p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", _flat(0.08, 0.18, 8, 5, 6)))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", _flat(0.03, 0.0, 8, 5, 6)))
	p.set_drag_forwarding(func(_at: Vector2) -> Variant:
		p.set_drag_preview(_drag_preview(String(e.icon), "%s  •  %d%%" % [String(e.name), int(e.pur)]))
		return {"deal": {"p": String(e.p), "pur": int(e.pur), "g": int(e.g)}, "from": "bag"},
		func(_at: Vector2, data: Variant) -> bool: return _can_drop(data, false),
		func(_at: Vector2, data: Variant) -> void: _drop_bag(U, data))
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not U.get_viewport().gui_is_dragging():
			place(U, String(e.p), int(e.pur), int(e.g)))
	return p


## zdjęcie z tacy przez przeciągnięcie z powrotem na listę
static func _drop_bag(U, data: Variant) -> void:
	var e: Dictionary = data.deal
	G.deal_offer_take(U.deal, int(e.pur), int(e.g), int(e.get("n", 9999)))
	Sfx.play("tick")
	U._render_deal()


## Lewa strona: cały ekwipunek, jak w plecaku — duże, czytelne wiersze. Paczki zamówionego towaru da się przeciągać,
## reszta (inny towar, towar luzem, przedmioty, gotówka) jest przygaszona.
static func side(U) -> void:
	var deal: Dictionary = U.deal
	var body: VBoxContainer = U.deal_side_body
	var sting: bool = deal.ctx.get("sting", false)
	var head := K.hbox(6)
	head.add_child(K.head("EKWIPUNEK", 14, C_HI))
	head.add_child(K.spacer())
	var hl := K.lbl("%d g w %d paczkach" % [G.packed_total(G.S.inv), G.packed_bags(G.S.inv)], 11, C_LOW)
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hl)
	body.add_child(head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(288, 120)
	body.add_child(sc)
	var rows := K.vbox(3)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	for target in [sc, rows]:
		(target as Control).set_drag_forwarding(Callable(),
			func(_at: Vector2, data: Variant) -> bool: return _can_drop(data, false),
			func(_at: Vector2, data: Variant) -> void: _drop_bag(U, data))
	var list: Array = G.entries(G.S.inv)
	# najpierw to, o co klient prosi; potem inne paczki, towar luzem, przedmioty i gotówka
	var want_p := String(deal.ctx.product)
	var rank := func(e: Dictionary) -> int:
		match String(e.kind):
			"pack": return 0 if String(e.p) == want_p else 1
			"bulk": return 2
			"item": return 3
		return 4
	var keyed: Array = []
	for i in range(list.size()):
		keyed.append([int(rank.call(list[i])), int(list[i].get("g", 1)), i])
	keyed.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[0] <= 1 and a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	for k in keyed:
		var e: Dictionary = list[k[2]]
		var fits: bool = String(e.kind) == "pack" and (String(e.p) == want_p or sting)
		var left := int(e.n)
		if String(e.kind) == "pack":
			left = G.deal_have(deal, String(e.p), int(e.pur), int(e.g))
		rows.add_child(_bag_row(U, e, left, fits))
	if list.is_empty():
		rows.add_child(K.wrap("Nie masz nic przy sobie.", 12, C_MID, 270.0))
	body.add_child(K.lbl("przeciągnij paczkę na tacę  •  kliknięcie też działa", 10, C_LOW))


# ---------------------------------------------------------------- okienko „ile”
static func ask(U, p: String, pur: int, g: int, have: int) -> void:
	ask_close(U)
	var deal: Dictionary = U.deal
	var need := maxi(0, int(deal.want) - int(deal.qty))
	var start := clampi(int(ceil(float(need) / float(g))), 1, have)
	U.deal_ask = {"p": p, "pur": pur, "g": g, "max": have, "v": start}
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# nad powiadomieniami, pod kartą „pierwszy raz”
	dim.z_index = 58
	U.modal.add_child(dim)
	U.deal_ask_box = dim
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# okienko wyskakuje nad samym oknem wymiany (tam, gdzie upuściłeś paczkę), nie na środku ekranu
	var mb: Rect2 = U.modal_box.get_global_rect()
	var full: Vector2 = U.root.size
	if mb.size.y > 40.0:
		cc.offset_left = mb.position.x
		cc.offset_right = -(full.x - mb.end.x)
		cc.offset_top = mb.position.y - 30.0
		cc.offset_bottom = -(full.y - mb.end.y)
	dim.add_child(cc)
	var box := K.panel(K.sb(Color(0.05, 0.057, 0.072, 0.99), 10, Color(1, 1, 1, 0.26), 1, 12))
	box.custom_minimum_size = Vector2(264, 0)
	cc.add_child(box)
	var v := K.vbox(6)
	box.add_child(v)
	var hd := K.hbox(6)
	hd.add_child(K.icon(G.pack_icon(p, g), 20))
	hd.add_child(K.lbl("%s %d g" % [String(D.PRODUCTS[p].name), g], 13, C_HI))
	hd.add_child(K.spacer())
	hd.add_child(K.lbl("%d%%  •  masz %d" % [pur, have], 10, C_LOW))
	v.add_child(hd)
	var big := K.head("", 20, C_HI)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var go := _mini("", func(): ask_ok(U), "strong")
	var slider := HSlider.new()
	var apply := func(val: float) -> void:
		var n := clampi(int(round(val)), 1, have)
		U.deal_ask.v = n
		var after: int = int(deal.qty) + n * g
		big.text = "%d szt.  =  %d g" % [n, n * g]
		go.text = "Połóż  (na tacy %d z %d g)" % [after, int(deal.want)]
		if absf(slider.value - n) > 0.001:
			slider.set_value_no_signal(n)
	U.deal_ask["apply"] = apply
	var row := K.hbox(6)
	v.add_child(row)
	var minus := _mini("−", func(): apply.call(float(U.deal_ask.v) - 1.0))
	minus.custom_minimum_size = Vector2(28, 24)
	row.add_child(minus)
	slider.min_value = 1
	slider.max_value = have
	slider.step = 1
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 18)
	slider.add_theme_stylebox_override("slider", _flat(0.12, 0.0, 0, 2, 2))
	slider.add_theme_stylebox_override("grabber_area", _flat(0.5, 0.0, 0, 2, 2))
	slider.add_theme_stylebox_override("grabber_area_highlight", _flat(0.7, 0.0, 0, 2, 2))
	slider.value_changed.connect(func(val: float): apply.call(val))
	row.add_child(slider)
	var plus := _mini("+", func(): apply.call(float(U.deal_ask.v) + 1.0))
	plus.custom_minimum_size = Vector2(28, 24)
	row.add_child(plus)
	var bh := K.hbox(6)
	v.add_child(bh)
	bh.add_child(_mini("Anuluj", func(): ask_close(U), "text"))
	bh.add_child(K.spacer())
	bh.add_child(go)
	apply.call(float(start))
	Sfx.play("open")
	dim.modulate.a = 0.0
	var tw := dim.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(dim, "modulate:a", 1.0, 0.1)


static func ask_close(U) -> void:
	U.deal_ask = {}
	if U.deal_ask_box != null and is_instance_valid(U.deal_ask_box):
		U.deal_ask_box.queue_free()
	U.deal_ask_box = null


static func ask_ok(U) -> void:
	if U.deal_ask.is_empty():
		return
	var a: Dictionary = U.deal_ask
	ask_close(U)
	var why: String = G.deal_offer_add(U.deal, String(a.p), int(a.pur), int(a.g), int(a.v))
	if why != "":
		G.notify(why, "warn")
		Sfx.play("error")
	else:
		Sfx.play("tick")
	U._render_deal()


## strzałki i +/− w okienku „ile”
static func ask_step(U, delta: int) -> void:
	if not U.deal_ask.is_empty():
		(U.deal_ask.apply as Callable).call(float(U.deal_ask.v) + float(delta))


# ---------------------------------------------------------------- taca i werdykt
static func _chip(U, b: Dictionary) -> Control:
	var deal: Dictionary = U.deal
	var p := String(deal.sel.p)
	var c := K.panel(_flat(0.05, 0.14, 6, 3, 5))
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.tooltip_text = "Kliknij, żeby zdjąć jedną paczkę. Możesz też przeciągnąć z powrotem na listę."
	var h := K.hbox(5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	h.add_child(K.icon(G.pack_icon(p, int(b.g)), 18))
	h.add_child(K.lbl("%d × %d g" % [int(b.n), int(b.g)], 12, C_HI))
	h.add_child(K.lbl("%d%%" % int(b.pur), 10, C_LOW))
	c.set_drag_forwarding(func(_at: Vector2) -> Variant:
		c.set_drag_preview(_drag_preview(G.pack_icon(p, int(b.g)), "%d × %d g" % [int(b.n), int(b.g)]))
		return {"deal": {"p": p, "pur": int(b.pur), "g": int(b.g), "n": int(b.n)}, "from": "tray"},
		func(_at: Vector2, data: Variant) -> bool: return _can_drop(data, true),
		func(_at: Vector2, data: Variant) -> void: _drop_tray(U, data))
	c.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not U.get_viewport().gui_is_dragging():
			G.deal_offer_take(deal, int(b.pur), int(b.g), 1)
			Sfx.play("tick")
			U._render_deal())
	return c


## Werdykt przy tacy: {big, text, color}. `big` to krótki, duży znak (procent albo ilość), `text` — podpis.
static func verdict(deal: Dictionary) -> Dictionary:
	var given := int(deal.qty)
	var want := int(deal.want)
	if given <= 0:
		return {"big": "%d g" % want, "text": "zamówił", "color": C_MID}
	if given == want:
		return {"big": "%d g" % given, "text": "komplet", "color": C_HI}
	if given > want:
		var gift: float = G.deal_gift(deal)
		if gift > 0.01:
			return {"big": "+%s g" % G.units(gift), "text": "gratis — doceni", "color": C_HI}
		return {"big": "+%d g" % (given - want), "text": "ponad zamówienie", "color": C_HI}
	var ch: float = G.deal_short_chance(deal)
	if ch >= 0.999:
		return {"big": "%d g" % given, "text": "mniej, ale uczciwie", "color": C_HI}
	if ch <= 0.0:
		return {"big": "0%", "text": "zorientował się", "color": C_ALERT}
	return {"big": "%d%%" % int(round(ch * 100.0)), "text": "szans, że weźmie", "color": C_HI}


static func _status_line(deal: Dictionary) -> String:
	var given := int(deal.qty)
	var want := int(deal.want)
	var prod := String(D.PRODUCT_GEN[deal.ctx.product])
	if given <= 0:
		return "Klient czeka na %d g %s. Przeciągnij paczki z listy po lewej." % [want, prod]
	if given == want:
		return "Dajesz dokładnie tyle, ile zamówił."
	if given > want:
		if G.deal_gift(deal) > 0.01:
			return "Dajesz %d g zamiast %d g i nie liczysz za nadwyżkę — zadowolenie i lojalność klienta wzrosną." % [given, want]
		return "Dajesz %d g zamiast %d g i liczysz za nadwyżkę — klient musi się jeszcze zgodzić na cenę." % [given, want]
	var ch: float = G.deal_short_chance(deal)
	if ch >= 0.999:
		return "Dajesz %d g z %d g i liczysz tylko za tyle — weźmie, choć liczył na więcej." % [given, want]
	if ch <= 0.0:
		return "Zorientował się. Dołóż %d g albo zejdź z sumy do %s." % [want - given, G.money(G.deal_fair_sum(deal))]
	var tail := ""
	if int(deal.st.get("shorted", 0)) > 0:
		tail = " Już raz go tak złapałeś — patrzy Ci na ręce."
	return "Dajesz %d g z %d g, a liczysz jak za więcej. Uda się — płaci całość; nie uda — spada zadowolenie.%s" % [given, want, tail]


static func build(U) -> void:
	var deal: Dictionary = U.deal
	var ctx: Dictionary = deal.ctx
	var who: Dictionary = deal.who
	var body: VBoxContainer = U.modal_body
	var street: bool = ctx.get("agreed") == null
	var sting: bool = ctx.get("sting", false)
	var given := int(deal.qty)
	side(U)
	# --- TACA: pole zrzutu z tym, co dajesz, i werdyktem po prawej; pełny opis sytuacji siedzi w podpowiedzi
	var zone := K.panel(_zone_style(false, given > 0))
	zone.custom_minimum_size = Vector2(0, 54)
	zone.tooltip_text = _status_line(deal)
	body.add_child(zone)
	U.deal_zone = zone
	U.deal_zone_hot = false
	zone.set_drag_forwarding(Callable(),
		func(_at: Vector2, data: Variant) -> bool: return _can_drop(data, true),
		func(_at: Vector2, data: Variant) -> void: _drop_tray(U, data))
	var zh := K.hbox(8)
	zh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(zh)
	if given <= 0:
		var hint := K.lbl("przeciągnij tutaj to, co dajesz", 12, C_LOW)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zh.add_child(hint)
		var auto := _mini("dobierz %d g" % int(deal.want), func():
			G.deal_autofill(deal)
			Sfx.play("tick")
			U._render_deal(), "text")
		auto.tooltip_text = "Gra sama ułoży paczki na zamówioną ilość."
		auto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zh.add_child(auto)
	else:
		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		for b in deal.give:
			flow.add_child(_chip(U, b))
		zh.add_child(flow)
		var clr := _mini("zdejmij", func():
			G.deal_offer_clear(deal)
			Sfx.play("tick")
			U._render_deal(), "text")
		clr.tooltip_text = "Zdejmij wszystko z tacy"
		clr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zh.add_child(clr)
	var vd := verdict(deal)
	var vb := K.vbox(-1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.custom_minimum_size = Vector2(96, 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var big := K.head(String(vd.big), 18, vd.color)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_constant_override("line_spacing", 0)
	vb.add_child(big)
	var vt := K.lbl(String(vd.text), 10, C_ALERT if vd.color == C_ALERT else C_LOW)
	vt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(vt)
	zh.add_child(vb)
	if given > 0 and int(deal.sel.pur) < int(who.minpur) and (int(deal.st.get("deals", 9)) >= 3 or not deal.st.has("deals")) and not sting:
		body.add_child(K.lbl("zwykle bierze towar od %d%% w górę — może to wyczuć" % int(who.minpur), 10, C_ALERT))
	# --- jeden rząd: suma z małymi przyciskami po bokach (taniej −10, −1 | drożej +1, +10), a po prawej trzy akcje
	var row := K.hbox(4)
	body.add_child(row)
	var ref_sum: int = G.deal_ref_sum(deal)
	var step_btn := func(delta: int) -> Button:
		var sb := _mini(("%+d" % delta), func():
			if G.deal_shift(deal, delta):
				Sfx.play("tick")
			else:
				Sfx.play("error")
			U._render_deal())
		sb.custom_minimum_size = Vector2(32, 26)
		sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sb.disabled = deal.over or (delta > 0 and deal.pushed) or (sting and delta < 0)
		sb.tooltip_text = "Po odmowie nie da się już podbić ceny." if (delta > 0 and deal.pushed) else ("Taniej o %d zł" % -delta if delta < 0 else "Drożej o %d zł" % delta)
		return sb
	row.add_child(step_btn.call(-10))
	row.add_child(step_btn.call(-1))
	var mid := K.vbox(-1)
	mid.custom_minimum_size = Vector2(116, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var sum_l := K.head(G.money(int(deal.sum)), 18, C_HI)
	sum_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(sum_l)
	var diff: int = int(deal.sum) - ref_sum
	var read: String = G.deal_read(deal, float(deal.pct))
	var tips := {"sure": "weźmie", "ok": "raczej weźmie", "risk": "ryzykowne", "no": "nie przejdzie", "": ""}
	var per := "%s/g" % G.money(round(float(deal.sum) / float(maxi(1, given if given > 0 else int(deal.want)))))
	var priced: bool = float(deal.pct) > 0.5 and read != ""
	var tag := String(tips[read]) if priced else (("umówione" if not street else "uliczna") if diff == 0 else ("%+d zł" % diff))
	var sub_l := K.lbl("%s  •  %s" % [per, tag], 10, C_ALERT if (priced and (read == "risk" or read == "no")) else C_LOW)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(sub_l)
	row.add_child(mid)
	row.add_child(step_btn.call(1))
	row.add_child(step_btn.call(10))
	row.add_child(K.spacer())
	# wyjścia: przy zamówieniu „Poczekaj” (klient zostaje) i „Odwołaj”; na ulicy samo „Odejdź”
	if ctx.get("order") != null:
		var bw := _mini("Poczekaj", func(): G.deal_pause(deal); U.close_all(), "text")
		bw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bw.tooltip_text = "Poczekaj chwilę — klient zostaje na miejscu, zamówienie nie przepada."
		row.add_child(bw)
		var bx := _mini("Odwołaj", func(): G.deal_cancel(deal); U.close_all(), "text")
		bx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bx.tooltip_text = "Odwołujesz transakcję. Klient będzie zły."
		row.add_child(bx)
	else:
		row.add_child(_mini("Odejdź", U._modal_close, "text"))
	# potwierdzenie: przytrzymaj — pasek rośnie, puszczenie go cofa
	var hb := _mini("Potwierdź  [%s]" % G.kn("use"), Callable(), "strong")
	hb.custom_minimum_size = Vector2(112, 26)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.disabled = given <= 0
	hb.tooltip_text = "Przytrzymaj przycisk albo klawisz, aż pasek się napełni." if given > 0 else "Najpierw połóż towar na tacy."
	hb.button_down.connect(func():
		U.deal_holding = true
		hb.text = "trzymaj…")
	hb.button_up.connect(func():
		U.deal_holding = false
		hb.text = "Potwierdź  [%s]" % G.kn("use"))
	hb.mouse_exited.connect(func(): U.deal_holding = false)
	var fill := ColorRect.new()
	fill.color = Color(1, 1, 1, 0.2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	fill.anchor_right = float(deal.hold)
	hb.add_child(fill)
	U.deal_fill = fill
	row.add_child(hb)


## podświetlenie tacy, gdy coś jest przeciągane (wołane co klatkę z ui._deal_tick)
static func tick(U) -> void:
	if U.deal_zone == null or not is_instance_valid(U.deal_zone):
		return
	var hot: bool = U.get_viewport().gui_is_dragging()
	if hot != U.deal_zone_hot:
		U.deal_zone_hot = hot
		U.deal_zone.add_theme_stylebox_override("panel", _zone_style(hot, int(U.deal.qty) > 0))
