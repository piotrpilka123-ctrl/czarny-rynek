extends RefCounted
## Okno wymiany przy sprzedaży. Po lewej to, co masz przy sobie; paczki przeciągasz na TACĘ (pole zrzutu)
## i w małym okienku wybierasz, ile ich kładziesz. Pod tacą jest SUMA za całość (−10 / −1 / +1 / +10 zł) i cena za gram,
## niżej trzy przyciski: potwierdzenie (przytrzymaj), „poczekaj chwilę" i odwołanie.
## Możesz dać więcej, niż klient zamówił (doceni to), albo mniej — wtedy taca pokazuje w procentach,
## jaka jest szansa, że weźmie towar i zapłaci pełną sumę. Świat się w tym czasie nie zatrzymuje,
## więc pasek u góry pokazuje, ilu ludzi może Was widzieć i czy patrzy patrol.
## Logika siedzi w game.gd: deal_start / deal_offer_add / deal_short_chance / deal_hand.

const K = preload("res://scripts/uikit.gd")

const C_ROW := Color(0.085, 0.102, 0.15)
const C_ROW_HOVER := Color(0.11, 0.135, 0.2)


static func _zone_style(hot: bool, filled: bool) -> StyleBoxFlat:
	if hot:
		return K.sb(Color(0.08, 0.2, 0.13, 0.9), 12, K.C_ACC, 2, 12)
	return K.sb(Color(0.06, 0.075, 0.115), 12, Color(1, 1, 1, 0.2 if filled else 0.12), 1, 12)


## pasek „kto patrzy”: świadkowie w pobliżu i patrol, który ma Was na oku
static func watch_row(U) -> Control:
	var h := K.hbox(6)
	var w: Dictionary = G.deal_watchers()
	var n := int(w.witnesses)
	var col: Color = K.C_ACC if n == 0 else (K.C_WARN if n <= 2 else K.C_BAD)
	U.deal_cop_l = K.icon_label("siren", "Patrol patrzy!", 11, Color(1, 0.7, 0.7), 13.0)
	U.deal_cop_l.visible = float(U.deal.cop_t) > 0.05
	h.add_child(U.deal_cop_l)
	U.cop_bar = K.bar(float(U.deal.cop_t), float(U.deal.cop_max), K.C_BAD, 6.0)
	U.cop_bar.custom_minimum_size = Vector2(70, 6)
	U.cop_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	U.cop_bar.visible = U.deal_cop_l.visible
	h.add_child(U.cop_bar)
	var ic := K.icon("eye" if n > 0 else "eye_off", 14, col)
	h.add_child(ic)
	var txt := "Nikt nie patrzy" if n == 0 else ("W pobliżu: %d %s" % [n, "osoba" if n == 1 else ("osoby" if n < 5 else "osób")])
	U.deal_watch_l = K.lbl(txt, 11, col)
	h.add_child(U.deal_watch_l)
	return h


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
	var pv := K.panel(K.sb(Color(0.09, 0.11, 0.16, 0.96), 9, K.C_ACC, 1, 8))
	var h := K.hbox(8)
	pv.add_child(h)
	h.add_child(K.icon(icon, 26))
	h.add_child(K.lbl(text, 13, K.C_TXT))
	var holder := Control.new()
	holder.add_child(pv)
	pv.position = Vector2(12, 8)
	holder.z_index = 100
	return holder


# ---------------------------------------------------------------- lewa strona: co masz przy sobie
static func _bag_row(U, e: Dictionary, left: int, fits: bool) -> Control:
	var live: bool = fits and left > 0 and String(e.kind) == "pack"
	var p := K.panel(K.sb(C_ROW, 8, Color(1, 1, 1, 0.06), 1, 5))
	p.modulate.a = 1.0 if live else 0.42
	var h := K.hbox(7)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(K.icon(String(e.icon), 24))
	var nl := K.lbl(String(e.name), 13, K.C_TXT)
	nl.clip_text = true
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nl)
	var pl := K.lbl("%d%%" % int(e.pur), 11, K.C_WARN if G.is_mix(e.pur) else K.C_DIM)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pl)
	var cnt := K.head(("×%d" % left) if String(e.kind) == "pack" else "luzem", 14 if String(e.kind) == "pack" else 11, K.C_TXT if live else K.C_DIM)
	cnt.custom_minimum_size = Vector2(30, 0)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(cnt)
	if String(e.kind) != "pack":
		p.tooltip_text = "%s luzem. Klientowi podajesz tylko paczki — zapakuj towar przy wadze." % G.grams(e.n)
		return p
	if not fits:
		p.tooltip_text = "%s chce %s." % [String(U.deal.who.name), String(D.PRODUCT_GEN[U.deal.ctx.product])]
	elif left <= 0:
		p.tooltip_text = "Wszystko leży już na tacy."
	if not live:
		return p
	p.mouse_default_cursor_shape = Control.CURSOR_DRAG
	p.tooltip_text = "Przeciągnij na tacę (albo kliknij)."
	p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", K.sb(C_ROW_HOVER, 8, Color(1, 1, 1, 0.18), 1, 5)))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", K.sb(C_ROW, 8, Color(1, 1, 1, 0.06), 1, 5)))
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


static func side(U) -> void:
	var deal: Dictionary = U.deal
	var body: VBoxContainer = U.deal_side_body
	var sting: bool = deal.ctx.get("sting", false)
	var head := K.hbox(6)
	head.add_child(K.head("PRZY SOBIE", 13, K.C_DIM))
	head.add_child(K.spacer())
	head.add_child(K.lbl("%d g" % G.packed_total(G.S.inv), 11, K.C_DIM))
	body.add_child(head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(210, 90)
	body.add_child(sc)
	var rows := K.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	for target in [sc, rows]:
		(target as Control).set_drag_forwarding(Callable(),
			func(_at: Vector2, data: Variant) -> bool: return _can_drop(data, false),
			func(_at: Vector2, data: Variant) -> void: _drop_bag(U, data))
	var list: Array = []
	for e in G.entries(G.S.inv):
		if String(e.kind) == "pack" or String(e.kind) == "bulk":
			list.append(e)
	# najpierw to, o co klient prosi; paczki przed towarem luzem
	var want_p := String(deal.ctx.product)
	list.sort_custom(func(a, b):
		var ka := (0 if String(a.p) == want_p else 2) + (0 if String(a.kind) == "pack" else 1)
		var kb := (0 if String(b.p) == want_p else 2) + (0 if String(b.kind) == "pack" else 1)
		if ka != kb:
			return ka < kb
		if String(a.p) != String(b.p):
			return String(a.p) < String(b.p)
		if int(a.g) != int(b.g):
			return int(a.g) < int(b.g)
		return int(a.pur) > int(b.pur))
	for e in list:
		var fits: bool = String(e.p) == want_p or sting
		var left := int(e.n)
		if String(e.kind) == "pack":
			left = G.deal_have(deal, String(e.p), int(e.pur), int(e.g))
		rows.add_child(_bag_row(U, e, left, fits))
	if list.is_empty():
		rows.add_child(K.wrap("Nie masz przy sobie towaru.", 12, K.C_DIM, 200.0))


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
		cc.offset_top = mb.position.y
		cc.offset_bottom = -(full.y - mb.end.y)
	dim.add_child(cc)
	var box := K.panel(K.sb(Color(0.055, 0.068, 0.096, 0.99), 12, Color(K.C_ACC.r, K.C_ACC.g, K.C_ACC.b, 0.7), 1, 12))
	box.custom_minimum_size = Vector2(300, 0)
	cc.add_child(box)
	var v := K.vbox(6)
	box.add_child(v)
	var hd := K.hbox(8)
	hd.add_child(K.icon(G.pack_icon(p, g), 26))
	hd.add_child(K.head("%s %d g" % [String(D.PRODUCTS[p].name), g], 15, K.C_TXT))
	hd.add_child(K.spacer())
	hd.add_child(K.lbl("%d%%  •  masz %d" % [pur, have], 11, K.C_DIM))
	v.add_child(hd)
	var big := K.head("", 24, Color.WHITE)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var sub := K.lbl("", 11, K.C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var go := K.btn("", func(): ask_ok(U), "go", true)
	var slider := HSlider.new()
	var apply := func(val: float) -> void:
		var n := clampi(int(round(val)), 1, have)
		U.deal_ask.v = n
		big.text = "%d szt.  =  %d g" % [n, n * g]
		var after: int = int(deal.qty) + n * g
		var want: int = int(deal.want)
		sub.text = ("na tacy będzie %d g z %d g" % [after, want]) if after != want else ("na tacy będzie %d g — komplet" % after)
		sub.add_theme_color_override("font_color", K.C_ACC if after >= want else K.C_DIM)
		go.text = "Połóż %d g" % (n * g)
		if absf(slider.value - n) > 0.001:
			slider.set_value_no_signal(n)
	U.deal_ask["apply"] = apply
	var row := K.hbox(8)
	v.add_child(row)
	var minus := K.btn("−", func(): apply.call(float(U.deal_ask.v) - 1.0), "", true)
	minus.custom_minimum_size = Vector2(32, 28)
	row.add_child(minus)
	slider.min_value = 1
	slider.max_value = have
	slider.step = 1
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 22)
	slider.value_changed.connect(func(val: float): apply.call(val))
	row.add_child(slider)
	var plus := K.btn("+", func(): apply.call(float(U.deal_ask.v) + 1.0), "", true)
	plus.custom_minimum_size = Vector2(32, 28)
	row.add_child(plus)
	var all := K.btn("wszystko", func(): apply.call(float(have)), "", true)
	row.add_child(all)
	var bh := K.hbox(8)
	v.add_child(bh)
	var bc := K.btn("Anuluj", func(): ask_close(U), "", true)
	bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bc)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var c := K.panel(K.sb(Color(0.12, 0.15, 0.22), 8, Color(1, 1, 1, 0.14), 1, 5))
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.tooltip_text = "Kliknij, żeby zdjąć jedną paczkę. Możesz też przeciągnąć z powrotem na listę."
	var h := K.hbox(5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	h.add_child(K.icon(G.pack_icon(p, int(b.g)), 22))
	h.add_child(K.head("%d × %d g" % [int(b.n), int(b.g)], 14, K.C_TXT))
	h.add_child(K.lbl("%d%%" % int(b.pur), 10, K.C_WARN if G.is_mix(b.pur) else K.C_DIM))
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


## Werdykt przy tacy: {big, text, color}. `big` to krótki, duży znak (procent albo ilość), `text` — jedno zdanie.
static func verdict(deal: Dictionary) -> Dictionary:
	var given := int(deal.qty)
	var want := int(deal.want)
	if given <= 0:
		return {"big": "%d g" % want, "text": "tyle zamówił", "color": K.C_DIM}
	if given == want:
		return {"big": "%d g" % given, "text": "komplet", "color": K.C_ACC}
	if given > want:
		var gift: float = G.deal_gift(deal)
		if gift > 0.01:
			return {"big": "+%s g" % G.units(gift), "text": "gratis — doceni to", "color": Color(0.45, 0.78, 1.0)}
		return {"big": "+%d g" % (given - want), "text": "ponad zamówienie", "color": K.C_TXT}
	var ch: float = G.deal_short_chance(deal)
	if ch >= 0.999:
		return {"big": "%d g" % given, "text": "mniej, ale uczciwie", "color": K.C_ACC}
	var col: Color = K.C_ACC if ch >= 0.8 else (K.C_WARN if ch >= 0.5 else K.C_BAD)
	return {"big": "%d%%" % int(round(ch * 100.0)), "text": "szans, że weźmie" if ch > 0.0 else "już się zorientował", "color": col}


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
	zone.custom_minimum_size = Vector2(0, 58)
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
		var hint := K.hbox(8)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.add_child(K.icon("package_open", 20, Color(1, 1, 1, 0.4)))
		hint.add_child(K.lbl("Przeciągnij tutaj to, co dajesz", 13, Color(1, 1, 1, 0.6)))
		zh.add_child(hint)
		var auto := K.btn("dobierz %d g" % int(deal.want), func():
			G.deal_autofill(deal)
			Sfx.play("tick")
			U._render_deal(), "", true)
		auto.tooltip_text = "Gra sama ułoży paczki na zamówioną ilość."
		auto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zh.add_child(auto)
	else:
		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_theme_constant_override("h_separation", 5)
		flow.add_theme_constant_override("v_separation", 5)
		for b in deal.give:
			flow.add_child(_chip(U, b))
		zh.add_child(flow)
		var clr := K.btn("", func():
			G.deal_offer_clear(deal)
			Sfx.play("tick")
			U._render_deal(), "flat", true)
		clr.icon = K.tex("x")
		clr.add_theme_constant_override("icon_max_width", 12)
		clr.tooltip_text = "Zdejmij wszystko z tacy"
		clr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zh.add_child(clr)
	var vd := verdict(deal)
	var vb := K.vbox(-4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.custom_minimum_size = Vector2(112, 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var big := K.head(String(vd.big), 22, vd.color)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(big)
	var vt := K.lbl(String(vd.text), 10, vd.color)
	vt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(vt)
	zh.add_child(vb)
	if given > 0 and int(deal.sel.pur) < int(who.minpur) and (int(deal.st.get("deals", 9)) >= 3 or not deal.st.has("deals")) and not sting:
		body.add_child(K.icon_label("triangle_alert", "Zwykle bierze towar od %d%% w górę — może to wyczuć." % int(who.minpur), 11, K.C_WARN, 13.0))
	# --- cena: SUMA za całość na środku, po bokach dwa małe przyciski — w lewo taniej (−10, −1), w prawo drożej (+1, +10)
	var ph := K.hbox(5)
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(ph)
	var ref_sum: int = G.deal_ref_sum(deal)
	var step_btn := func(delta: int) -> Button:
		var sb := K.btn(("%+d" % delta), func():
			if G.deal_shift(deal, delta):
				Sfx.play("tick")
			else:
				Sfx.play("error")
			U._render_deal(), "", true)
		sb.custom_minimum_size = Vector2(42, 32)
		sb.disabled = deal.over or (delta > 0 and deal.pushed) or (sting and delta < 0)
		sb.tooltip_text = "Po odmowie nie da się już podbić ceny." if (delta > 0 and deal.pushed) else ("Taniej o %d zł" % -delta if delta < 0 else "Drożej o %d zł" % delta)
		return sb
	ph.add_child(step_btn.call(-10))
	ph.add_child(step_btn.call(-1))
	var mid := K.vbox(-4)
	mid.custom_minimum_size = Vector2(210, 0)
	var sum_l := K.head(G.money(int(deal.sum)), 24, K.C_ACC)
	sum_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(sum_l)
	var diff: int = int(deal.sum) - ref_sum
	var read: String = G.deal_read(deal, float(deal.pct))
	var tips := {"sure": "weźmie", "ok": "raczej weźmie", "risk": "ryzykowne", "no": "nie przejdzie", "": ""}
	var tcol := {"sure": K.C_ACC, "ok": K.C_ACC, "risk": K.C_WARN, "no": K.C_BAD, "": K.C_DIM}
	var per := ("%s za gram" % G.money(round(float(deal.sum) / float(maxi(1, given if given > 0 else int(deal.want))))))
	var tag := ("umówione" if not street else "cena uliczna") if diff == 0 else ("%+d zł" % diff)
	var priced: bool = float(deal.pct) > 0.5 and read != ""
	var sub_l := K.lbl("%s  •  %s%s" % [per, tag, (" • " + String(tips[read])) if priced else ""], 10, tcol[read] if priced else K.C_DIM)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(sub_l)
	ph.add_child(mid)
	ph.add_child(step_btn.call(1))
	ph.add_child(step_btn.call(10))
	# --- trzy przyciski: potwierdzenie (przytrzymaj — pasek rośnie, puszczenie go cofa), „poczekaj chwilę”, odwołanie
	var foot := K.hbox(6)
	body.add_child(foot)
	var hb := Button.new()
	hb.focus_mode = Control.FOCUS_NONE
	hb.custom_minimum_size = Vector2(0, 36)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.text = ("POTWIERDŹ  —  przytrzymaj tutaj albo [%s]" % G.kn("use")) if given > 0 else "Połóż towar na tacy"
	hb.add_theme_font_size_override("font_size", 13)
	if given > 0:
		hb.add_theme_stylebox_override("normal", K.sb(Color(0.1, 0.36, 0.2), 9, K.C_ACC, 1, 8))
		hb.add_theme_stylebox_override("hover", K.sb(Color(0.12, 0.42, 0.24), 9, K.C_ACC, 2, 8))
		hb.add_theme_stylebox_override("pressed", K.sb(Color(0.14, 0.5, 0.28), 9, Color.WHITE, 2, 8))
	else:
		hb.disabled = true
		hb.add_theme_stylebox_override("disabled", K.sb(Color(0.09, 0.11, 0.15), 9, Color(1, 1, 1, 0.1), 1, 8))
	hb.button_down.connect(func(): U.deal_holding = true)
	hb.button_up.connect(func(): U.deal_holding = false)
	hb.mouse_exited.connect(func(): U.deal_holding = false)
	var fill := ColorRect.new()
	fill.color = Color(1, 1, 1, 0.22)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	fill.anchor_right = float(deal.hold)
	hb.add_child(fill)
	U.deal_fill = fill
	foot.add_child(hb)
	U._deal_exit_buttons(foot, true)


## podświetlenie tacy, gdy coś jest przeciągane (wołane co klatkę z ui._deal_tick)
static func tick(U) -> void:
	if U.deal_zone == null or not is_instance_valid(U.deal_zone):
		return
	var hot: bool = U.get_viewport().gui_is_dragging()
	if hot != U.deal_zone_hot:
		U.deal_zone_hot = hot
		U.deal_zone.add_theme_stylebox_override("panel", _zone_style(hot, int(U.deal.qty) > 0))
