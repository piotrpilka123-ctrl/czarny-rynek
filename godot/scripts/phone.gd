extends Control
## Telefon gracza: ekran główny z aplikacjami (Wiadomości, Kontakty, Mapa, Hurt,
## Portfel, Rozwój, Zadania, Lokale, Plecak, Ustawienia).

const K = preload("res://scripts/uikit.gd")
const OrderUI = preload("res://scripts/order_ui.gd")

const APPS := [
	["sms", "Wiadomości", "message_circle", Color(0.2, 0.72, 0.38)],
	["kontakty", "Kontakty", "users", Color(0.25, 0.5, 0.9)],
	["dealerzy", "Dealerzy", "users", Color(0.4, 0.55, 0.35)],
	["dostawy", "Dostawy", "list_checks", Color(0.65, 0.43, 0.2)],
	["mapa", "Mapa", "map", Color(0.15, 0.6, 0.62)],
	["portfel", "Portfel", "wallet", Color(0.8, 0.62, 0.15)],
	["rozwoj", "Rozwój", "brain", Color(0.55, 0.35, 0.85)],
	["zadania", "Zadania", "list_checks", Color(0.85, 0.45, 0.15)],
	["lokale", "Lokale", "building_2", Color(0.35, 0.42, 0.55)],
	["plecak", "Plecak", "backpack", Color(0.5, 0.38, 0.25)],
	["ustawienia", "Ustawienia", "settings", Color(0.35, 0.37, 0.42)],
]
const AV_COLORS := [Color(0.25, 0.5, 0.9), Color(0.75, 0.35, 0.3), Color(0.3, 0.65, 0.45), Color(0.7, 0.55, 0.2), Color(0.55, 0.35, 0.8), Color(0.2, 0.6, 0.65), Color(0.8, 0.4, 0.6)]

var ui
var app := ""
var chat_id := ""
var contact_id := ""
var skill_sel := ""
## zamawianie u Wiktora: wybrany towar i paczka, koszyk, zakładka (buy | sell)
var shop := {"p": "dym", "g": 5, "cart": [], "tab": "buy"}
var shop_edit: LineEdit = null      # pole „ile gramów” w sklepie Wiktora
var bezel: PanelContainer        # telefon trzymany pionowo
var land: Control                # ten sam telefon położony na boku (sklep Wiktora)
var cc2: CenterContainer
var shop_root: VBoxContainer
var _landscape := false
var l_clock: Label
var screen: Control
var head: HBoxContainer
var l_title: Label
var scroll: ScrollContainer
var body: VBoxContainer
var footer: VBoxContainer
var home: Control
var cc: CenterContainer
var dim: ColorRect
var sv: VBoxContainer
var wall: TextureRect
var _dir := 1.0
var nego := -1
var nego_price := 0             # negocjowana SUMA za całość (zł)
var retime := -1
var retime_t := 0.0             # pora wskazana na tarczy zegara
var swap := -1                  # zamówienie, przy którym wybierasz inny towar
const Dial = preload("res://scripts/clock_dial.gd")
var hot: Array = []          # akcje kafli pod rozmową (klawisze 1–4)


func build(ui_ref) -> void:
	ui = ui_ref
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	cc = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	bezel = K.panel(K.sb(Color(0.02, 0.02, 0.025), 34, Color(0.22, 0.23, 0.26), 2, 12))
	cc.add_child(bezel)
	cc2 = CenterContainer.new()
	cc2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc2.visible = false
	add_child(cc2)
	land = OrderUI.build(self)
	cc2.add_child(land)
	var v := K.vbox(0)
	bezel.add_child(v)
	# pasek stanu
	var sbar := K.hbox(6)
	sbar.custom_minimum_size = Vector2(372, 26)
	v.add_child(sbar)
	sbar.add_child(K.gap(0))
	l_clock = K.lbl("09:00", 13, K.C_TXT)
	sbar.add_child(l_clock)
	sbar.add_child(K.lbl("POLTEL", 11, K.C_DIM))
	sbar.add_child(K.spacer())
	sbar.add_child(K.icon("signal", 14, K.C_TXT))
	sbar.add_child(K.icon("wifi", 14, K.C_TXT))
	sbar.add_child(K.icon("battery_medium", 16, K.C_TXT))
	# ekran
	var sp := K.panel(K.sb(Color(0.046, 0.05, 0.062), 18, Color(0, 0, 0, 0), 0, 0))
	sp.custom_minimum_size = Vector2(372, 600)
	sp.clip_contents = true
	v.add_child(sp)
	screen = Control.new()
	screen.clip_contents = true
	sp.add_child(screen)
	# tapeta ekranu głównego
	var gr := Gradient.new()
	gr.set_color(0, Color(0.16, 0.1, 0.24))
	gr.set_color(1, Color(0.03, 0.05, 0.09))
	gr.add_point(0.45, Color(0.07, 0.12, 0.2))
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_from = Vector2(0.2, 0.0)
	gt.fill_to = Vector2(0.8, 1.0)
	gt.width = 64
	gt.height = 128
	wall = TextureRect.new()
	wall.texture = gt
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(wall)
	sv = K.vbox(0)
	sv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(sv)
	var hp := K.panel(K.sb(Color(0.066, 0.071, 0.086), 0, Color(0, 0, 0, 0), 0, 10))
	sv.add_child(hp)
	head = K.hbox(8)
	hp.add_child(head)
	l_title = K.lbl("", 17)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(scroll)
	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(mc)
	body = K.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_child(body)
	var fm := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		fm.add_theme_constant_override("margin_" + side, 10)
	sv.add_child(fm)
	footer = K.vbox(6)
	fm.add_child(footer)
	# pasek nawigacji
	var nav := K.hbox(0)
	nav.custom_minimum_size = Vector2(0, 40)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(nav)
	var bb := K.btn("", back, "flat")
	bb.icon = K.tex("chevron_left")
	bb.custom_minimum_size = Vector2(90, 34)
	bb.expand_icon = true
	nav.add_child(bb)
	var hb := K.btn("", func(): go(""), "flat")
	hb.icon = K.tex("house")
	hb.custom_minimum_size = Vector2(90, 34)
	hb.expand_icon = true
	nav.add_child(hb)
	var xb := K.btn("", func(): ui.close_all(), "flat")
	xb.icon = K.tex("x")
	xb.custom_minimum_size = Vector2(90, 34)
	xb.expand_icon = true
	nav.add_child(xb)


func _tw() -> Tween:
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return t


## wysunięcie telefonu od dołu
func _anim_open() -> void:
	cc.offset_top = 520.0
	cc.offset_bottom = 520.0
	cc.modulate.a = 0.0
	dim.modulate.a = 0.0
	var t := _tw().set_parallel(true)
	t.tween_property(cc, "offset_top", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(cc, "offset_bottom", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(cc, "modulate:a", 1.0, 0.18)
	t.tween_property(dim, "modulate:a", 1.0, 0.25)


## przejście między ekranami: wsunięcie z boku i rozjaśnienie
func _anim_screen() -> void:
	sv.offset_left = 46.0 * _dir
	sv.offset_right = 46.0 * _dir
	sv.offset_top = 0.0
	sv.offset_bottom = 0.0
	sv.modulate.a = 0.0
	var t := _tw().set_parallel(true)
	t.tween_property(sv, "offset_left", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(sv, "offset_right", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(sv, "modulate:a", 1.0, 0.16)


func _pop(c: Control, delay: float, from := 0.6) -> void:
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	var t := _tw().set_parallel(true)
	t.tween_property(c, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(c, "modulate:a", 1.0, 0.14).set_delay(delay)


## Telefon obraca się na bok i odsuwa (sklep Wiktora) albo wraca do pionu.
func _orient(sideways: bool, animate := true) -> void:
	if sideways == _landscape and animate:
		return
	_landscape = sideways
	bezel.pivot_offset = bezel.size * 0.5
	land.pivot_offset = land.size * 0.5
	if not animate:
		cc.visible = not sideways
		cc2.visible = sideways
		bezel.rotation = 0.0
		bezel.scale = Vector2.ONE
		bezel.modulate.a = 1.0
		land.rotation = 0.0
		land.scale = Vector2.ONE
		land.modulate.a = 1.0
		cc.offset_left = 0.0
		cc.offset_right = 0.0
		return
	var t := _tw()
	if sideways:
		# pionowy telefon kładzie się w lewo i zjeżdża w bok, w jego miejscu pojawia się poziomy
		cc2.visible = true
		land.modulate.a = 0.0
		land.rotation = PI * 0.5
		land.scale = Vector2(0.62, 0.62)
		t.set_parallel(true)
		t.tween_property(bezel, "rotation", -PI * 0.5, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(bezel, "scale", Vector2(1.12, 1.12), 0.3)
		t.tween_property(cc, "offset_left", -120.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(cc, "offset_right", -120.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(bezel, "modulate:a", 0.0, 0.12).set_delay(0.2)
		t.tween_property(land, "modulate:a", 1.0, 0.14).set_delay(0.2)
		t.tween_property(land, "rotation", 0.0, 0.26).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(land, "scale", Vector2.ONE, 0.26).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.chain().tween_callback(func(): cc.visible = not _landscape)
	else:
		cc.visible = true
		bezel.modulate.a = 0.0
		t.set_parallel(true)
		t.tween_property(land, "modulate:a", 0.0, 0.12)
		t.tween_property(land, "scale", Vector2(0.7, 0.7), 0.16)
		t.tween_property(bezel, "modulate:a", 1.0, 0.12).set_delay(0.06)
		t.tween_property(bezel, "rotation", 0.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(bezel, "scale", Vector2.ONE, 0.26)
		t.tween_property(cc, "offset_left", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(cc, "offset_right", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.chain().tween_callback(func(): cc2.visible = _landscape)


## „Zamów towar” w rozmowie z Wiktorem: telefon kładzie się na bok i pokazuje sklep
func shop_open() -> void:
	if not G.flag("hurt_on"):
		return
	_dir = 1.0
	app = "sklep"
	render()


func shop_close() -> void:
	_dir = -1.0
	app = "sms"
	chat_id = "wiktor"
	render()


## wysyła koszyk jednym SMS-em i wraca do rozmowy, żeby było widać odpowiedź
func shop_send() -> void:
	var d: Dictionary = G.Market.order_cart(shop.cart)
	if d.is_empty():
		Sfx.play("error")
		render()
		return
	shop.cart = []
	shop_close()


func open(a := "") -> void:
	var was := visible
	visible = true
	if a != "sklep":
		_orient(false, false)
	if not was:
		_anim_open()
	_dir = 1.0
	app = a
	if a != "sms":
		chat_id = ""
	if a != "kontakty":
		contact_id = ""
	render()


func go(a: String) -> void:
	_dir = 1.0 if a != "" else -1.0
	app = a
	chat_id = ""
	contact_id = ""
	skill_sel = ""
	render()


func back() -> void:
	_dir = -1.0
	if app == "sms" and chat_id != "":
		chat_id = ""
		render()
	elif app == "kontakty" and contact_id != "":
		contact_id = ""
		render()
	elif app == "sklep":
		shop_close()
	elif app != "":
		go("")
	else:
		ui.close_all()


func refresh() -> void:
	if visible:
		render()


func _header(title: String, sub := "") -> void:
	K.clear(head)
	head.get_parent().visible = true
	var v := K.vbox(0)
	v.add_child(K.lbl(title, 17))
	if sub != "":
		v.add_child(K.lbl(sub, 11, K.C_DIM))
	head.add_child(v)


func render() -> void:
	if app == "sklep":
		_orient(true)
		OrderUI.render(self)
		return
	_orient(false)
	K.clear(body)
	K.clear(footer)
	l_clock.text = G.clock()
	scroll.scroll_vertical = 0
	wall.visible = app == ""
	_anim_screen()
	match app:
		"sms":
			if chat_id != "":
				_chat()
			else:
				_sms_list()
		"kontakty":
			if contact_id != "":
				_contact()
			else:
				_contacts()
		"dealerzy": _dealers()
		"dostawy": _deliveries()
		"mapa": _map()
		"portfel": _wallet()
		"rozwoj": _skills()
		"zadania": _tasks()
		"lokale": _props()
		"plecak":
			app = ""
			ui.open_inventory("")
			return
		"ustawienia": _settings()
		_: _home()


# ---------------------------------------------------------------- ekran główny
func _badge(a: String) -> int:
	match a:
		"sms": return G.unread_total()
		"rozwoj": return int(G.S.sp)
		"hurt":
			var n := 0
			for d in G.S.drops:
				if d.state == "ready":
					n += 1
			return n
	return 0


func _home() -> void:
	head.get_parent().visible = false
	body.add_child(K.gap(14))
	var t := K.lbl(G.clock(), 54)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(t)
	var dl := K.lbl("Dzień %d • %s" % [G.day(), "deszcz" if G.rain > 0.2 else ("noc" if G.night > 0.6 else "pochmurno")], 13, K.C_DIM)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(dl)
	body.add_child(K.gap(18))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(grid)
	for a in APPS:
		var id: String = a[0]
		var cell := K.vbox(4)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(62, 62)
		var c: Color = a[3]
		b.add_theme_stylebox_override("normal", K.sb(c, 16, c.lightened(0.15), 1, 12))
		b.add_theme_stylebox_override("hover", K.sb(c.lightened(0.12), 16, c.lightened(0.3), 1, 12))
		b.add_theme_stylebox_override("pressed", K.sb(c.darkened(0.15), 16, c, 1, 12))
		b.icon = K.tex(a[2])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(func():
			Sfx.play("select")
			go(id))
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(62, 62)
		holder.add_child(b)
		b.pivot_offset = Vector2(31, 31)
		_pop(b, 0.03 * grid.get_child_count())
		var n := _badge(id)
		if n > 0:
			var bp := K.panel(K.sb(K.C_BAD, 9, Color(0.046, 0.05, 0.062), 2, 5))
			bp.position = Vector2(42, -6)
			bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bp.add_child(K.lbl(str(n), 11, Color.WHITE))
			holder.add_child(bp)
		cell.add_child(holder)
		var l := K.lbl(a[1], 11, K.C_TXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		grid.add_child(cell)
	body.add_child(K.gap(10))
	var st := G.cur_step()
	if not st.is_empty():
		var c2 := K.card(body, 10, Color(0.08, 0.1, 0.14, 0.9))
		c2.add_child(K.lbl(G.chapter().to_upper(), 10, K.C_ACC))
		c2.add_child(K.wrap(st.text.call(), 12, K.C_TXT))


# ---------------------------------------------------------------- wiadomości
func _avatar(cid: String, size := 38.0) -> Control:
	var p := K.panel(K.sb(AV_COLORS[absi(cid.hash()) % AV_COLORS.size()] if cid != "wiktor" else Color(0.25, 0.08, 0.08), int(size / 2.0), Color(0, 0, 0, 0), 0, 0))
	p.custom_minimum_size = Vector2(size, size)
	var l := K.lbl(G.contact_name(cid).substr(0, 1), int(size * 0.45), Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _sms_list() -> void:
	_header("Wiadomości")
	var ids := []
	for cid in G.S.chats:
		if not G.S.chats[cid].is_empty():
			ids.append(cid)
	ids.sort_custom(func(a, b): return float(G.S.chats[a][-1].t) > float(G.S.chats[b][-1].t))
	if ids.is_empty():
		body.add_child(K.lbl("Brak wiadomości.", 13, K.C_DIM))
	for cid in ids:
		var id: String = cid
		var last: Dictionary = G.S.chats[cid][-1]
		var unread := int(G.S.unread.get(cid, 0))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_stylebox_override("normal", K.sb(K.C_CARD if unread == 0 else Color(0.09, 0.14, 0.13), 12, K.C_LINE, 1, 8))
		b.add_theme_stylebox_override("hover", K.sb(K.C_CARD2, 12, K.C_LINE, 1, 8))
		b.pressed.connect(func():
			Sfx.play("click")
			_dir = 1.0
			chat_id = id
			render())
		var h := K.hbox(10)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		h.add_child(_avatar(cid))
		var v := K.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var top := K.hbox(6)
		top.add_child(K.lbl(G.contact_name(cid), 14, Color.WHITE if unread > 0 else K.C_TXT))
		top.add_child(K.spacer())
		top.add_child(K.lbl("%s" % last.time, 10, K.C_DIM))
		v.add_child(top)
		var pv := K.lbl(("Ty: " if last.me else "") + String(last.text), 12, K.C_TXT if unread > 0 else K.C_DIM)
		pv.clip_text = true
		pv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pv.custom_minimum_size = Vector2(230, 0)
		v.add_child(pv)
		h.add_child(v)
		if unread > 0:
			var bp := K.panel(K.sb(K.C_ACC, 9, Color(0, 0, 0, 0), 0, 6))
			bp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bp.add_child(K.lbl(str(unread), 11, Color(0.02, 0.1, 0.04)))
			h.add_child(bp)
		body.add_child(b)


func _chat() -> void:
	var def := G.cust_def(chat_id)
	_header(G.contact_name(chat_id), ("„%s”" % def.nick) if not def.is_empty() else ("Kontakt z Grupy" if chat_id == "wiktor" else ""))
	G.mark_read(chat_id)
	var msgs: Array = G.S.chats.get(chat_id, [])
	var last_day := -1
	for m in msgs:
		if int(m.day) != last_day:
			last_day = int(m.day)
			var dl := K.lbl("Dzień %d" % last_day, 10, K.C_DIM)
			dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.add_child(dl)
		var row := K.hbox(0)
		var me: bool = m.me
		var p := K.panel(K.sb(Color(0.12, 0.42, 0.26) if me else Color(0.13, 0.15, 0.2), 14, Color(0, 0, 0, 0), 0, 10))
		var txt := String(m.text)
		var l := K.lbl(txt, 13, Color.WHITE if me else K.C_TXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(minf(250.0, 24.0 + txt.length() * 7.4), 0)
		var pv := K.vbox(1)
		pv.add_child(l)
		var tl := K.lbl(String(m.time), 9, Color(1, 1, 1, 0.45))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pv.add_child(tl)
		p.add_child(pv)
		if me:
			row.add_child(K.spacer())
		row.add_child(p)
		if not me:
			row.add_child(K.spacer())
		body.add_child(row)
		if msgs.size() - msgs.find(m) <= 2:
			p.pivot_offset = Vector2(250.0 if me else 0.0, 20.0)
			_pop(p, 0.12 + 0.12 * (2 - (msgs.size() - msgs.find(m))), 0.7)
	# odpowiedzi: karta zamówienia i duże kafle pod rozmową
	hot = []
	var order = null
	for o in G.S.orders:
		if o.cust == chat_id:
			order = o
	if order != null:
		_order_footer(order)
	elif chat_id == "wiktor":
		_wiktor_footer()
	_scroll_end()


## wiersz karty zamówienia: ikona + tekst
func _fact(parent: Node, ic: String, text: String, color := K.C_TXT) -> void:
	var h := K.hbox(6)
	h.add_child(K.icon(ic, 14, K.C_DIM))
	var l := K.lbl(text, 13, color)
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	parent.add_child(h)


## duży kafel odpowiedzi: ikona w kółku, nazwa (maks. 2 słowa) i krótka liczba/podpowiedź pod spodem
func _tile(ic: String, label: String, sub: String, color: Color, cb: Callable, key := 0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", K.sb(Color(color.r, color.g, color.b, 0.13), 12, Color(color.r, color.g, color.b, 0.5), 1, 8))
	b.add_theme_stylebox_override("hover", K.sb(Color(color.r, color.g, color.b, 0.26), 12, color, 1, 8))
	b.add_theme_stylebox_override("pressed", K.sb(Color(color.r, color.g, color.b, 0.36), 12, color, 1, 8))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	var h := K.hbox(8)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var dot := K.panel(K.sb(Color(color.r, color.g, color.b, 0.22), 15, Color(0, 0, 0, 0), 0, 0))
	dot.custom_minimum_size = Vector2(30, 30)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := K.icon(ic, 16, color.lightened(0.25))
	i.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.add_child(i)
	h.add_child(dot)
	var v := K.vbox(-2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := K.lbl(label, 14, Color.WHITE)
	l.clip_text = true
	v.add_child(l)
	if sub != "":
		var sl := K.lbl(sub, 11, color.lightened(0.35))
		sl.clip_text = true
		v.add_child(sl)
	h.add_child(v)
	if key > 0:
		var kl := K.lbl(str(key), 10, Color(1, 1, 1, 0.3))
		kl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(kl)
		while hot.size() < key:
			hot.append(Callable())
		hot[key - 1] = cb
	return b


## skrót klawiszowy 1–4 do kafli pod rozmową
func hotkey(n: int) -> bool:
	if app != "sms" or chat_id == "" or n < 1 or n > hot.size() or not (hot[n - 1] as Callable).is_valid():
		return false
	Sfx.play("click")
	(hot[n - 1] as Callable).call()
	return true


func _order_footer(order: Dictionary) -> void:
	var oid := int(order.id)
	var S: Dictionary = G.S
	var accepted: bool = order.status == "accepted"
	var grams := int(order.grams)
	var sum: int = G.order_sum(order)
	var per := float(sum) / float(maxi(1, grams))
	var per_txt := ("%d" % int(round(per))) if absf(per - round(per)) < 0.05 else ("%.1f" % per).replace(".", ",")
	# --- karta: co, za ile, gdzie, kiedy
	var edge := K.C_ACC if accepted else K.C_WARN
	var card := K.panel(K.sb(Color(0.07, 0.076, 0.092), 14, Color(edge.r, edge.g, edge.b, 0.55), 1, 10))
	footer.add_child(card)
	var cv := K.vbox(4)
	card.add_child(cv)
	var top := K.hbox(6)
	top.add_child(K.icon("circle_check" if accepted else "package", 14, edge))
	top.add_child(K.lbl("UMÓWIONE" if accepted else "ZAMÓWIENIE", 10, edge))
	top.add_child(K.spacer())
	if not accepted:
		var rl := int(float(order.respond_by) - S.t)
		top.add_child(K.lbl("czeka na odpowiedź jeszcze %d min" % maxi(0, rl), 10, K.C_DIM))
	cv.add_child(top)
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 10)
	g2.add_theme_constant_override("v_separation", 3)
	cv.add_child(g2)
	var c1 := K.vbox(3)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c2 := K.vbox(3)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g2.add_child(c1)
	g2.add_child(c2)
	_fact(c1, D.PRODUCT_ICONS.get(order.product, "leaf"), "%d g %s" % [int(order.grams), D.PRODUCT_GEN[order.product]])
	_fact(c1, "map_pin", String(G.spot_def(order.spot).name))
	_fact(c2, "banknote", "%s  •  %s zł/g" % [G.money(sum), per_txt], K.C_ACC)
	if accepted:
		var left: float = float(order.meet) - S.t
		# klient czeka ok. 5 godzin i się nie zraża; do godziny po umówionej porze jest wręcz zadowolony
		var wait_txt := ("za %d min" % int(left)) if left > 0.0 else ("czeka • jeszcze %d min na premię" % int(D.CLIENT_EARLY + left) if left > -D.CLIENT_EARLY else "czeka do %s" % G.clock(order.deadline))
		_fact(c2, "clock", "%s  •  %s" % [G.clock(order.meet), wait_txt], K.C_TXT if left > 10.0 else (K.C_ACC if left > -D.CLIENT_EARLY else K.C_WARN))
	elif order.get("fixed", false) and float(order.meet) > S.t + 12.0:
		_fact(c2, "clock", "%s  •  ustalone" % G.clock(order.meet))
	else:
		_fact(c2, "clock", "ok. %s  •  za godzinę" % G.clock(G.default_meet()))

	# --- wybór nowej godziny: tarcza zegara — wskazówkę ustawiasz kliknięciem albo przeciąganiem (tylko dziś)
	if retime == oid:
		var rng: Vector2 = G.meet_range()
		if retime_t < rng.x or retime_t > rng.y:
			retime_t = clampf(float(order.meet) + (60.0 if accepted else 0.0), rng.x, rng.y)
		footer.add_child(K.lbl("O KTÓREJ SIĘ SPOTKACIE?  (wskaż na zegarze — tylko dziś)", 10, K.C_DIM))
		var dial := Dial.new()
		var dc := CenterContainer.new()
		dc.add_child(dial)
		footer.add_child(dc)
		dial.setup(S.t, rng.x, rng.y, retime_t)
		var send_t := _tile("send", "Zaproponuj %s" % G.clock(retime_t), "poczeka do %s" % G.clock(retime_t + D.CLIENT_WAIT), K.C_BLUE, func(): var tt := int(retime_t); retime = -1; _reply(oid, "time", tt), 1)
		var send_l: Label = send_t.find_children("", "Label", true, false)[0]
		var send_s: Label = send_t.find_children("", "Label", true, false)[1]
		dial.changed.connect(func(t: float):
			retime_t = t
			send_l.text = "Zaproponuj %s" % G.clock(t)
			send_s.text = "poczeka do %s" % G.clock(t + D.CLIENT_WAIT))
		var fine := K.hbox(6)
		fine.alignment = BoxContainer.ALIGNMENT_CENTER
		for dm in [-30, -5, 5, 30]:
			var dmin: int = dm
			var fb := _chip(("%+d min" % dmin), func(): dial.nudge(float(dmin)), "")
			fb.custom_minimum_size = Vector2(62, 28)
			fine.add_child(fb)
		footer.add_child(fine)
		var trow := K.hbox(6)
		trow.add_child(send_t)
		trow.add_child(_tile("arrow_left", "Wróć", "", Color(0.6, 0.64, 0.72), func(): retime = -1; _dir = 0.0; render(), 2))
		footer.add_child(trow)
		return

	# --- inny towar zamiast zamówionego
	if swap == oid and not accepted:
		var opts2: Array = G.swap_options(order)
		footer.add_child(K.lbl("CO PROPONUJESZ ZAMIAST %s?" % String(D.PRODUCT_GEN[order.product]).to_upper(), 10, K.C_DIM))
		if opts2.is_empty():
			footer.add_child(K.wrap("Nie masz zaporcjowanego innego towaru — ani przy sobie, ani w skrytkach.", 12, K.C_WARN))
		var k2 := 1
		for e2 in opts2.slice(0, 3):
			var np: String = e2.p
			footer.add_child(_tile(D.PRODUCT_ICONS.get(np, "leaf"), String(e2.name), "masz %d porcji • klient może odmówić" % int(e2.have), K.C_GOLD, func(): swap = -1; _reply(oid, "swap", np), k2))
			k2 += 1
		footer.add_child(_tile("arrow_left", "Wróć", "", Color(0.6, 0.64, 0.72), func(): swap = -1; _dir = 0.0; render(), k2))
		return

	# --- negocjacja: SUMA za całość, po bokach małe przyciski — w lewo taniej (−10, −1), w prawo drożej (+1, +10)
	if nego == oid and not accepted:
		var base := int(order.stated) * grams
		nego_price = clampi(nego_price, maxi(1, int(base * 0.5)), int(base * 1.8))
		var up := (float(nego_price) / maxf(1.0, float(base)) - 1.0) * 100.0
		var risk := "klient da tyle od ręki — i to zapamięta" if up < -0.5 else ("tyle sam proponuje" if up < 0.5 else ("raczej się zgodzi" if up <= 8.0 else ("może odbić własną sumą" if up <= 28.0 else "może zerwać rozmowę")))
		var rc := K.C_ACC if up <= 8.0 else (K.C_WARN if up <= 28.0 else K.C_BAD)
		footer.add_child(K.lbl("ILE CHCESZ ZA CAŁOŚĆ  (%d g)" % grams, 10, K.C_DIM))
		var nrow := K.hbox(5)
		nrow.alignment = BoxContainer.ALIGNMENT_CENTER
		for step in [-10, -1]:
			var st: int = step
			var mb := _chip(str(st), func(): nego_price += st; _dir = 0.0; render(), "")
			mb.custom_minimum_size = Vector2(42, 36)
			nrow.add_child(mb)
		var pv := K.vbox(-3)
		pv.custom_minimum_size = Vector2(116, 0)
		var pl := K.head(G.money(nego_price), 26, K.C_ACC)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(pl)
		var dl := K.lbl("klient daje %s  (%+d zł)" % [G.money(base), nego_price - base], 10, K.C_DIM)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(dl)
		nrow.add_child(pv)
		for step in [1, 10]:
			var st2: int = step
			var pb := _chip("+" + str(st2), func(): nego_price += st2; _dir = 0.0; render(), "")
			pb.custom_minimum_size = Vector2(42, 36)
			nrow.add_child(pb)
		footer.add_child(nrow)
		var rl2 := K.lbl(risk, 11, rc)
		rl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.add_child(rl2)
		var row := K.hbox(6)
		row.add_child(_tile("send", "Wyślij", G.money(nego_price), K.C_ACC, func(): nego = -1; _reply(oid, "price", nego_price), 1))
		row.add_child(_tile("arrow_left", "Wróć", "", Color(0.6, 0.64, 0.72), func(): nego = -1; _dir = 0.0; render(), 2))
		footer.add_child(row)
		return

	# --- odpowiedzi
	var grid2 := GridContainer.new()
	grid2.columns = 2
	grid2.add_theme_constant_override("h_separation", 6)
	grid2.add_theme_constant_override("v_separation", 6)
	footer.add_child(grid2)
	var nego_open := func(): nego = oid; nego_price = G.order_sum(order) + maxi(5, int(round(G.order_sum(order) * 0.06))); _dir = 0.0; render()
	var time_open := func(): retime = oid; retime_t = 0.0; _dir = 0.0; render()
	if accepted:
		grid2.add_child(_tile("navigation", "Prowadź", "trasa na mapie", K.C_ACC, func(): G.main.set_track(oid); ui.close_all(), 1))
		grid2.add_child(_tile("clock", "Zmień godzinę", "teraz %s" % G.clock(order.meet), K.C_BLUE, time_open, 2))
		if order.has("time_offer"):
			grid2.add_child(_tile("check", "Zgoda na %s" % G.clock(order.time_offer), "pora klienta", K.C_ACC, func(): _reply(oid, "timeok"), 3))
		grid2.add_child(_tile("x", "Anuluj", "odwołaj spotkanie", K.C_BAD, func(): _reply(oid, "decline"), 4 if order.has("time_offer") else 3))
	else:
		var kk := 1
		if order.counter != null:
			grid2.add_child(_tile("check", "Zgoda", G.money(sum), K.C_ACC, func(): _reply(oid, "counterok"), kk))
		else:
			grid2.add_child(_tile("check", "Zgoda", G.money(sum), K.C_ACC, func(): _reply(oid, "accept"), kk))
			kk += 1
			grid2.add_child(_tile("hand_coins", "Negocjuj", "zmień sumę", K.C_GOLD, nego_open, kk))
		kk += 1
		if order.has("time_offer"):
			grid2.add_child(_tile("check", "Pora %s" % G.clock(order.time_offer), "zgoda na jego godzinę", K.C_BLUE, func(): _reply(oid, "timeok"), kk))
			kk += 1
		grid2.add_child(_tile("clock", "Zmień godzinę", "wskaż na zegarze", K.C_BLUE, time_open, kk))
		kk += 1
		if not order.get("swapped", false) and order.counter == null:
			grid2.add_child(_tile("boxes", "Inny towar", "zaproponuj zamianę", Color(0.75, 0.6, 0.95), func(): swap = oid; _dir = 0.0; render(), kk))
			kk += 1
		grid2.add_child(_tile("x", "Anuluj", "odmów", K.C_BAD, func(): _reply(oid, "decline"), kk))


func _pair(a: Button, b: Button) -> HBoxContainer:
	var h := K.hbox(4)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(b)
	return h


func _chip(text: String, cb: Callable, kind: String) -> Button:
	var b := K.btn(text, cb, kind, true)
	b.custom_minimum_size = Vector2(0, 30)
	return b


func _reply(oid: int, kind: String, value: Variant = 0) -> void:
	G.reply_order(oid, kind, value)
	_dir = 0.0
	render()


func _scroll_end() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = 999999


# ---------------------------------------------------------------- kontakty
func _contacts() -> void:
	_header("Kontakty", "Stali klienci: %d / %d" % [G.client_count(), G.client_cap()])
	var locked := 0
	for d in D.CLIENTS:
		var st: Dictionary = G.S.cust[d.id]
		if not st.unlocked:
			locked += 1
			continue
		var id: String = d.id
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 62)
		b.add_theme_stylebox_override("normal", K.sb(K.C_CARD, 12, K.C_LINE, 1, 8))
		b.add_theme_stylebox_override("hover", K.sb(K.C_CARD2, 12, K.C_LINE, 1, 8))
		b.pressed.connect(func():
			Sfx.play("click")
			contact_id = id
			render())
		var h := K.hbox(10)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		h.add_child(_avatar(d.id))
		var v := K.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(K.lbl("%s  „%s”" % [d.name, d.nick], 14))
		var sat: float = st.sat
		var row := K.hbox(6)
		row.add_child(K.icon("smile" if sat > 60.0 else ("meh" if sat > 30.0 else "frown"), 13, K.C_ACC if sat > 60.0 else (K.C_WARN if sat > 30.0 else K.C_BAD)))
		row.add_child(K.lbl("%d%%" % int(sat), 11, K.C_DIM))
		row.add_child(K.icon("heart", 13, K.C_PINK))
		row.add_child(K.lbl("%d" % int(st.loy), 11, K.C_DIM))
		if float(st.owes) > 0.0:
			row.add_child(K.lbl("wisi %s" % G.money(st.owes), 11, K.C_WARN))
		v.add_child(row)
		h.add_child(v)
		body.add_child(b)
	if locked > 0:
		body.add_child(K.wrap("Nieznane kontakty: %d. Nowi klienci przychodzą z polecenia zadowolonych, z poziomem — albo trzeba ich znaleźć na mieście." % locked, 12, K.C_DIM))


func _contact() -> void:
	var d := G.cust_def(contact_id)
	var st: Dictionary = G.S.cust[contact_id]
	_header(d.name, "„%s”" % d.nick)
	var c := K.card(body)
	c.add_child(K.wrap(d.bio, 13, K.C_DIM))
	var c2 := K.card(body)
	for e in [["Zadowolenie", float(st.sat), K.C_ACC if float(st.sat) > 55.0 else K.C_WARN], ["Lojalność", float(st.loy), K.C_PINK]]:
		var h := K.hbox(8)
		var l := K.lbl(e[0], 12, K.C_DIM)
		l.custom_minimum_size = Vector2(96, 0)
		h.add_child(l)
		h.add_child(K.bar(e[1], 100.0, e[2]))
		c2.add_child(h)
	if int(st.deals) >= 5 or G.has_skill("oko1"):
		var h2 := K.hbox(8)
		var l2 := K.lbl("Głód", 12, K.C_DIM)
		l2.custom_minimum_size = Vector2(96, 0)
		h2.add_child(l2)
		h2.add_child(K.bar(float(st.hunger) * 100.0, 100.0, K.C_BAD))
		c2.add_child(h2)
	var c3 := K.card(body)
	c3.add_child(K.lbl("NOTATKI", 10, K.C_DIM))
	var known: Dictionary = st.known
	var deals := int(st.deals)
	var notes := "Transakcje: [b]%d[/b] • sprzedane: [b]%d g[/b]\n" % [deals, int(st.grams)]
	notes += "Bierze: [b]%s[/b], zwykle %d–%d g\n" % [D.PRODUCTS[d.prod].name, int(d.grams[0]), int(d.grams[1])]
	notes += "Charakter: %s\n" % (("[b]%s[/b]" % D.TYPE_NAMES[d.type]) if deals >= 2 else K.col("? (poznasz po 2 transakcjach)", K.C_DIM))
	notes += "Lubi rozmowę: %s\n" % (("[b]%s[/b]" % D.STYLE_NAMES[known.like]) if known.has("like") else K.col("? (odkryj przy powitaniu)", K.C_DIM))
	if known.has("hate"):
		notes += "Nie znosi: [b]%s[/b]\n" % D.STYLE_NAMES[known.hate]
	notes += "Minimalna czystość: %s\n" % (("[b]%d%%[/b]" % int(d.minpur)) if deals >= 3 else K.col("? (po 3 transakcjach)", K.C_DIM))
	if known.has("budget"):
		var mx := G.max_price(d, st, d.prod, maxi(int(d.minpur), 70), int(d.grams[0]))
		notes += "Zwykle płaci do ok. [b]%s[/b] za gram\n" % G.money(mx)
	if float(st.owes) > 0.0:
		notes += K.col("Wisi Ci %s" % G.money(st.owes), K.C_WARN)
	c3.add_child(K.rich(notes.strip_edges(), 13))
	var id := contact_id
	footer.add_child(K.btn("Napisz", func(): app = "sms"; chat_id = id; render(), "go"))


# ---------------------------------------------------------------- mapa
func _map() -> void:
	_header("Mapa", "Steel Blocks i okolice")
	var cv := Control.new()
	cv.custom_minimum_size = Vector2(350, 285)
	cv.clip_contents = true
	cv.draw.connect(func(): ui.draw_map(cv, Vector2(0.0, 0.0), 420.0 * D.SC, true))
	body.add_child(cv)
	body.add_child(K.lbl("PROWADŹ DO", 10, K.C_DIM))
	for t in G.main.nav_targets():
		var tid = t.id
		var b := K.btn(t.label, func(): G.main.set_track(tid); render(), "go" if G.main.track_key() == str(tid) else "", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(b)
	body.add_child(K.btn("Trasa na mapie: " + ("włączona" if G.S.nav_on else "wyłączona"), func(): G.main.toggle_nav(); render(), "", true))


# ---------------------------------------------------------------- Wiktor: zamówienie i skrzynka
## kafle pod rozmową z Wiktorem: zamówienie (telefon kładzie się na bok) i droga do skrzynki na pieniądze
func _wiktor_footer() -> void:
	var S: Dictionary = G.S
	var owed := float(S.credit)
	var sub := "zeszyt czysty" if owed <= 0.0 else ("zeszyt: %s — PO TERMINIE" % G.money(owed) if G.credit_overdue() else "zeszyt: %s, do dnia %d" % [G.money(owed), int(float(S.credit_due) / 1440.0) + 1])
	var t1 := _tile("package", "Zamów towar", "czysty, na zeszyt" if G.flag("hurt_on") else "Wiktor jeszcze Ci nie ufa", Color(0.85, 0.62, 0.2), shop_open, 1)
	t1.disabled = not G.flag("hurt_on")
	if String(G.cur_step().get("id", "")) == "order1" and G.flag("hurt_on") and G.S.drops.is_empty():
		K.point_hand(t1, Vector2(6, -22))
	var t2 := _tile("banknote", "Skrzynka Wiktora", sub, Color(0.3, 0.75, 0.45), func():
		G.main.set_track("box")
		ui.close_all()
		G.notify("Prowadzę do skrzynki Wiktora. Włóż do niej gotówkę — najpierw schodzi zeszyt, reszta idzie na Twój wkład."), 2)
	footer.add_child(_pair(t1, t2))


func _wallet() -> void:
	var S: Dictionary = G.S
	_header("Portfel")
	var c := K.card(body)
	c.add_child(K.lbl("GOTÓWKA PRZY SOBIE", 10, K.C_DIM))
	c.add_child(K.lbl(G.money(S.cash), 30, K.C_ACC))
	var stash_cash := 0.0
	for r in S.stash:
		stash_cash += float(S.stash[r].cash)
	c.add_child(K.rich("W skrytkach: [b]%s[/b]   •   Zeszyt u Wiktora: [b]%s[/b]" % [G.money(stash_cash), G.money(S.credit)], 12))
	# ekipa Wiktora: ranga, postęp do awansu i to, co za niego dostaniesz
	var cd := K.card(body)
	cd.add_child(K.lbl("EKIPA WIKTORA", 10, K.C_DIM))
	var rk: Dictionary = G.rank_def()
	cd.add_child(K.rich("[b]%s[/b]   %s" % [K.col(String(rk.name), K.C_ACC), K.col("wkład %s z %s" % [G.money(S.paid), G.money(D.START_DEBT)], K.C_DIM)], 17))
	var nx: Dictionary = G.rank_next()
	if not nx.is_empty():
		cd.add_child(K.rich("Następny awans: [b]%s[/b] — przy %s wkładu (brakuje %s)" % [String(nx.name), G.money(nx.at), G.money(maxf(0.0, float(nx.at) - S.paid))], 12))
		cd.add_child(K.bar(S.paid - float(rk.at), float(nx.at) - float(rk.at), K.C_ACC))
		cd.add_child(K.wrap("Nagroda: " + String(nx.desc), 12, K.C_TXT))
		var left := int(nx.day) - G.day()
		if int(nx.bonus) > 0:
			cd.add_child(K.rich("Premia za tempo: [b]%s[/b], jeśli zdążysz do końca dnia %d  (%s)" % [G.money(nx.bonus), int(nx.day), K.col("za %d dni" % left if left > 0 else ("DZIŚ" if left == 0 else "termin minął — awans i tak dostaniesz"), K.C_WARN if left <= 1 and left >= 0 else K.C_DIM)], 12))
	else:
		cd.add_child(K.wrap("Jesteś wspólnikiem. Wiktor bierze już tylko za towar.", 12, K.C_TXT))
	cd.add_child(K.wrap("Pieniądze zanosisz do skrzynki Wiktora na tyłach pawilonu. Najpierw schodzi z nich zeszyt za towar, a cała reszta idzie na Twój wkład. Nie ma odsetek ani kar — wkład rośnie w Twoim tempie.", 12, K.C_DIM))
	var bbx := K.btn("Prowadź do skrzynki", func(): G.main.set_track("box"); ui.close_all(), "go", true)
	bbx.icon = K.tex("map_pin")
	bbx.add_theme_constant_override("icon_max_width", 14)
	cd.add_child(bbx)
	var cs := K.card(body)
	cs.add_child(K.lbl("SZCZEBLE", 10, K.C_DIM))
	var txt := ""
	for i in range(1, D.RANKS.size()):
		var rr: Dictionary = D.RANKS[i]
		var got: bool = int(S.get("rank", 0)) >= i
		txt += "%s [b]%s[/b] — %s  %s\n" % [K.col("✓", K.C_ACC) if got else "•", String(rr.name), G.money(rr.at), K.col(String(rr.desc), K.C_DIM)]
	cs.add_child(K.rich(txt.strip_edges(), 12))
	var ct := K.card(body)
	ct.add_child(K.lbl("BILANS", 10, K.C_DIM))
	ct.add_child(K.rich("Zarobione: [b]%s[/b]\nWydane: [b]%s[/b]\nKoszty życia: %s dziennie\nNajlepsza transakcja: %s" % [G.money(S.stats.earned), G.money(S.stats.spent), G.money(D.LIVING_COST), G.money(S.stats.best)], 12))


# ---------------------------------------------------------------- rozwój
func _skills() -> void:
	var S: Dictionary = G.S
	_header("Rozwój", "Poziom %d — %s" % [int(S.lvl), G.level_title()])
	var c := K.card(body, 10)
	var h := K.hbox(8)
	h.add_child(K.lbl("PD %d / %d" % [int(S.xp), int(G.next_xp())], 12, K.C_DIM))
	h.add_child(K.spacer())
	h.add_child(K.lbl("Punkty: %d" % int(S.sp), 13, K.C_GOLD if int(S.sp) > 0 else K.C_DIM))
	c.add_child(h)
	c.add_child(K.bar(float(S.xp) - G.prev_xp(), maxf(1.0, G.next_xp() - G.prev_xp()), K.C_GOLD))
	if D.LEVEL_UNLOCKS.has(int(S.lvl) + 1):
		c.add_child(K.wrap("Poziom %d: %s" % [int(S.lvl) + 1, D.LEVEL_UNLOCKS[int(S.lvl) + 1]], 11, K.C_DIM))
	var grid := K.hbox(6)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(grid)
	var bcol := {"Handel": K.C_GOLD, "Ulica": K.C_BLUE, "Towar": K.C_ACC, "Kontakty": K.C_PINK}
	for br in D.BRANCHES:
		var col := K.vbox(0)
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		var bl := K.lbl(String(br).to_upper(), 10, bcol[br])
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(bl)
		col.add_child(K.gap(4))
		var first := true
		for row in range(5):
			for s in D.SKILLS:
				if s.branch != br or int(s.row) != row:
					continue
				var sid: String = s.id
				var learned := G.has_skill(sid)
				var can := G.can_learn(sid)
				if not first:
					var ln := ColorRect.new()
					ln.color = bcol[br] if learned else K.C_LINE
					ln.custom_minimum_size = Vector2(3, 12)
					ln.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					col.add_child(ln)
				first = false
				var b := Button.new()
				b.focus_mode = Control.FOCUS_NONE
				b.custom_minimum_size = Vector2(82, 50)
				b.text = String(s.name)
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.add_theme_font_size_override("font_size", 11)
				var c0: Color = bcol[br]
				var bg := c0.darkened(0.45) if learned else (Color(0.13, 0.16, 0.22) if can else Color(0.07, 0.08, 0.11))
				var bd := c0 if (learned or skill_sel == sid) else (c0.darkened(0.3) if can else K.C_LINE)
				b.add_theme_stylebox_override("normal", K.sb(bg, 10, bd, 2 if (skill_sel == sid or learned) else 1, 5))
				b.add_theme_stylebox_override("hover", K.sb(bg.lightened(0.08), 10, c0, 2, 5))
				b.add_theme_color_override("font_color", Color.WHITE if learned else (K.C_TXT if can else K.C_DIM))
				b.pressed.connect(func():
					Sfx.play("click")
					skill_sel = sid
					render())
				col.add_child(b)
		grid.add_child(col)
	if skill_sel != "":
		var s := G.skill_def(skill_sel)
		footer.add_child(K.lbl(String(s.name), 14, bcol[s.branch]))
		footer.add_child(K.wrap(s.desc, 12, K.C_TXT))
		if G.has_skill(skill_sel):
			footer.add_child(K.lbl("Opanowane", 12, K.C_ACC))
		else:
			var why := ""
			if s.has("req") and not G.has_skill(s.req):
				why = "Wymaga: " + String(G.skill_def(s.req).name)
			elif int(S.lvl) < int(s.get("lvl", 1)):
				why = "Wymaga poziomu %d" % int(s.lvl)
			elif int(S.sp) <= 0:
				why = "Brak punktów umiejętności"
			var sid2 := skill_sel
			var lb := K.btn("Naucz się (1 punkt)" if why == "" else why, func(): G.learn_skill(sid2); render(), "go")
			lb.disabled = why != ""
			footer.add_child(lb)
	else:
		footer.add_child(K.wrap("Punkt umiejętności dostajesz za każdy poziom. Wybierz umiejętność, żeby zobaczyć opis.", 11, K.C_DIM))


# ---------------------------------------------------------------- zadania
func _tasks() -> void:
	_header("Zadania", G.chapter())
	var cur := int(G.S.step)
	# zlecenie dnia od Wiktora: mały cel na dziś, premia idzie na wkład
	if G.job_active():
		var jb: Dictionary = G.S.job
		var jc := K.card(body)
		var jh := K.hbox(6)
		jh.add_child(K.lbl("ZLECENIE DNIA", 10, K.C_GOLD))
		jh.add_child(K.spacer())
		jh.add_child(K.lbl("seria: %d" % int(G.S.get("job_streak", 0)), 10, K.C_DIM))
		jc.add_child(jh)
		jc.add_child(K.wrap(G.job_text(), 13, K.C_TXT))
		if jb.get("done", false):
			jc.add_child(K.rich("%s  premia %s" % [K.col("Zrobione.", K.C_ACC), G.money(float(jb.get("reward", 0.0)))], 12))
		else:
			jc.add_child(K.bar(G.job_progress(), float(jb.need), K.C_GOLD))
			var jd: Dictionary = G.job_def(String(jb.kind))
			jc.add_child(K.rich("%s z %s  •  premia: [b]%s[/b] do wkładu%s" % [G._job_amount(jd, G.job_progress()), G._job_amount(jd, float(jb.need)), G.money(G.job_reward()), K.col("  (trzecie z rzędu — podwójna)", K.C_GOLD) if (int(G.S.get("job_streak", 0)) + 1) % 3 == 0 else ""], 12))
		jc.add_child(K.wrap("Do północy. Nie zdążysz — nic się nie dzieje, jutro będzie następne.", 11, K.C_DIM))
	var c := K.card(body)
	for i in range(G.story.size()):
		var st: Dictionary = G.story[i]
		if st.has("ch"):
			c.add_child(K.lbl(String(st.ch).to_upper(), 10, K.C_ACC if i <= cur else K.C_DIM))
		if i > cur + 1:
			continue
		var h := K.hbox(8)
		h.add_child(K.icon("circle_check" if i < cur else ("target" if i == cur else "lock"), 15, K.C_ACC if i < cur else (K.C_WARN if i == cur else K.C_DIM)))
		var txt: String = st.text.call() if i <= cur else "???"
		h.add_child(K.wrap(txt, 12, K.C_DIM if i < cur else (K.C_TXT if i == cur else K.C_DIM)))
		c.add_child(h)
	var cs := K.card(body)
	cs.add_child(K.lbl("STATYSTYKI", 10, K.C_DIM))
	var T: Dictionary = G.S.stats
	cs.add_child(K.rich("Sprzedane: [b]%d g[/b] w %d transakcjach\nZaporcjowane: %d g (rozsypane: %d g)\nOdebrane paczki: %d • własny plon: %d g\nUcieczki: %d • zatrzymania: %d/%d" % [
		int(T.sold), int(T.deals), int(T.packed), int(T.wasted), int(T.pickups), int(T.grown), int(T.escapes), int(G.S.arrests), D.MAX_ARRESTS], 12))
	var ch := K.card(body)
	ch.add_child(K.lbl("RADA NA DZIŚ", 10, K.C_DIM))
	ch.add_child(K.wrap(D.HINTS[G.day() % D.HINTS.size()], 12, K.C_TXT))


# ---------------------------------------------------------------- lokale
func _props() -> void:
	_header("Lokale", "Kryjówki i interesy")
	var c0 := K.card(body, 10)
	c0.add_child(K.rich("[b]Kawalerka w bloku 7[/b]  %s\nWaga, szafa-skrytka (%d miejsc), łóżko. Na więcej nie ma miejsca." % [K.col("Twoja", K.C_ACC), G.stash_cap("safe")], 12))
	for p0 in D.PROPERTIES:
		var pid: String = p0.id
		# cena z uwzględnieniem awansu w ekipie (garaż za pół ceny dla Zaufanego)
		var p: Dictionary = G.prop_def(pid)
		var c := K.card(body, 10)
		var own := G.owns(pid)
		var soon: bool = String(p.room) == ""
		c.add_child(K.rich("[b]%s[/b]  %s" % [p.name, K.col("Kupione", K.C_ACC) if own else K.col(G.money(p.price), K.C_WARN)], 14))
		c.add_child(K.lbl(p.where, 11, K.C_DIM))
		c.add_child(K.wrap(p.desc, 12, K.C_TXT))
		if own:
			var room: String = p.room
			c.add_child(K.rich("Meble: %d • skrytka: %s / %d" % [G.S.hide[room].items.size(), G.units(G.store_total(G.S.stash[room])), G.stash_cap(room)], 11))
			c.add_child(K.btn("Prowadź", func(): G.main.set_track("prop:" + pid); ui.close_all(), "", true))
		elif soon:
			c.add_child(K.lbl("Od poziomu %d • w przygotowaniu" % int(p.lvl), 11, K.C_DIM))
		else:
			var why := ""
			if int(G.S.lvl) < int(p.lvl):
				why = "Wymaga poziomu %d" % int(p.lvl)
			elif G.S.cash < float(p.price):
				why = "Brakuje %s (gotówka przy sobie)" % G.money(float(p.price) - G.S.cash)
			var f := K.flow(5)
			c.add_child(f)
			var b := K.btn("Kup" if why == "" else why, func(): G.buy_property(pid); render(), "go", true)
			b.disabled = why != ""
			f.add_child(b)
			f.add_child(K.btn("Pokaż na mapie", func(): G.main.set_track("prop:" + pid); ui.close_all(), "", true))


# ---------------------------------------------------------------- plecak
func _bag() -> void:
	var S: Dictionary = G.S
	_header("Plecak", "%s / %d g" % [G.grams(G.carry_total()), G.capacity()])
	body.add_child(K.bar(G.carry_total(), float(G.capacity()), K.C_BLUE))
	var c := K.card(body)
	c.add_child(K.lbl("ZAPAKOWANE (gotowe do sprzedaży)", 10, K.C_DIM))
	var ps := G.stacks(S.inv, "pack")
	if ps.is_empty():
		c.add_child(K.lbl("Nic. Zapakuj towar w woreczki przy wadze.", 12, K.C_DIM))
	for s in ps:
		c.add_child(K.rich("%s  %s   [b]%d × %d g[/b]" % [D.PRODUCTS[s.p].name, K.tier_bb(s.pur), int(s.n), int(s.g)], 13))
	var c2 := K.card(body)
	c2.add_child(K.lbl("LUZEM (do porcjowania)", 10, K.C_DIM))
	var bs := G.stacks(S.inv, "bulk")
	if bs.is_empty():
		c2.add_child(K.lbl("Nic.", 12, K.C_DIM))
	for s in bs:
		c2.add_child(K.rich("%s  %s   [b]%s[/b]" % [D.PRODUCTS[s.p].name, K.tier_bb(s.pur), G.grams(s.n)], 13))
	var c3 := K.card(body)
	c3.add_child(K.lbl("RZECZY", 10, K.C_DIM))
	c3.add_child(K.rich("Waga: [b]%s[/b]\nMajeranek: [b]%d g[/b] • cukier puder: [b]%d g[/b]\nNasiona: [b]%d[/b]\nTelefony na kartę: [b]%d[/b]" % [String(G.scale_def().name), G.item("majeranek"), G.item("cukier"), G.item("nasiona"), G.item("burner")], 13))
	if G.item("burner") > 0:
		c3.add_child(K.btn("Zmień numer (śledztwo −25)", func(): G.use_burner(); render(), "", true))
	body.add_child(K.wrap("Przy zatrzymaniu tracisz cały towar z plecaka i część gotówki. To, co w skrytkach, jest bezpieczne.", 11, K.C_DIM))


# ---------------------------------------------------------------- ustawienia
func _settings() -> void:
	_header("Ustawienia")
	var c := K.card(body)
	c.add_child(K.rich("Ostatni zapis: [b]%s[/b]\nGrę zapisujesz tylko przy [b]laptopie w kryjówce[/b]. Niezapisany postęp przepada." % G.last_save_text(), 12))
	var f := K.flow(5)
	c.add_child(f)
	f.add_child(K.btn("Opcje: obraz, dźwięk, klawisze", func(): ui.open_options("game"), "go", true))
	f.add_child(K.btn("Sterowanie", func(): ui.show_controls(), "", true))
	f.add_child(K.btn("Menu główne (bez zapisu)", func(): G.main.to_menu(), "bad", true))
	var m := K.card(body)
	m.add_child(K.lbl("MUZYKA W KLUBIE NEON", 10, K.C_DIM))
	m.add_child(K.rich("Teraz gra: [b]%s[/b]\nWłasna muzyka: wrzuć pliki MP3 do folderu [b]muzyka[/b] w folderze gry — klub będzie je odtwarzał." % Sfx.club_track_name(), 12))


func _deliveries() -> void:
	_header("Dostawy", "Zaplanuj jedną wyprawę po osiedlu")
	body.add_child(K.wrap("Liczymy tylko paczki w kieszeni, o jakości odpowiedniej dla klienta. Ta sama paczka nie jest przypisana do dwóch spotkań.", 12, K.C_DIM))
	var plan: Array = G.delivery_plan()
	if plan.is_empty():
		body.add_child(K.wrap("Nie masz umówionych dostaw. Przyjmij zamówienie w Wiadomościach.", 13, K.C_TXT))
	for delivery in plan:
		var card := K.card(body)
		card.add_child(K.head(String(delivery.name), 17))
		card.add_child(K.wrap("%s • %s" % [G.clock(delivery.meet), delivery.where], 12, K.C_DIM))
		card.add_child(K.wrap("%s: %d / %d g gotowe" % [D.PRODUCTS[delivery.p].name, int(delivery.ready), int(delivery.want)], 13, K.C_TXT))
		if int(delivery.missing) > 0:
			card.add_child(K.wrap("Przepakuj przy wadze — masz za duże paczki." if delivery.repack else "Brakuje %d g odpowiedniego towaru w kieszeni." % int(delivery.missing), 12, K.C_WARN))
		else:
			card.add_child(K.wrap("Możesz ruszać. Klient czeka do %s." % G.clock(delivery.deadline), 12, K.C_DIM))
		var order_id := int(delivery.id)
		card.add_child(K.btn("Prowadź do klienta", func():
			G.S.track = order_id
			G.S.nav_on = true
			G.nav_dirty.emit()
			ui.close_all()))


func _dealers() -> void:
	_header("Dealerzy", "Twoja sieć sprzedaży")
	body.add_child(K.wrap("Udane dostawy w dzielnicy budują reputację: do 12 pkt dziennie, raz na klienta. Progi 20 / 50 / 80 zmniejszają prowizję lokalnej sieci o 1 / 2 / 3 punkty procentowe.",12,K.C_DIM))
	body.add_child(K.wrap("Spotkaj się osobiście, donieś paczki i odbierz zarobek. Sprzedaż 8–23, po prowizji. Przy śledztwie 65+ wstrzymują pracę.", 12, K.C_DIM))
	for dealer in G.Dealers.DEFS:
		var id: String = dealer.id
		var card := K.card(body)
		card.add_child(K.head(String(dealer.name), 17))
		var zone: Dictionary = G.Dealers.zone(id)
		var zone_id: String = zone.get("id","")
		card.add_child(K.wrap("%s: %s • reputacja %d/100" % [zone.get("name",""),G.Reputation.title(zone_id),G.Reputation.score(zone_id)],12,K.C_TXT))
		card.add_child(K.wrap("Pełny rabat lokalnej sieci" if G.Reputation.score(zone_id)>=80 else "Kolejny rabat przy %d pkt (brakuje %d)." % [G.Reputation.next_goal(zone_id),G.Reputation.next_goal(zone_id)-G.Reputation.score(zone_id)],12,K.C_DIM))
		card.add_child(K.wrap("Prowizja %d%% • zapas do %d g • do %d g na godzinę" % [int(round(G.Dealers.commission(id)*100)), int(dealer.cap), int(dealer.pace)], 12, K.C_DIM))
		if G.S.dealers.has(id):
			var state: Dictionary = G.S.dealers[id]
			card.add_child(K.wrap("Zapas: %d g • do odbioru: %s" % [G.Dealers.stock(id), G.money(state.cash)], 13, K.C_TXT))
			card.add_child(K.wrap("Wstrzymane" if state.paused else ("Brak zapasu" if G.Dealers.stock(id) == 0 else "Sprzedaje w godzinach pracy"), 12, K.C_WARN if state.paused or G.Dealers.stock(id) == 0 else K.C_DIM))
		else:
			card.add_child(K.wrap(G.Dealers.requirement(id) if G.Dealers.requirement(id) != "" else "Podejdź i zaproponuj współpracę: %s." % G.money(dealer.fee), 12, K.C_DIM))
		card.add_child(K.btn("Prowadź do %s" % dealer.name, func():
			G.S.track = "dealer_" + id
			G.S.nav_on = true
			G.nav_dirty.emit()
			ui.close_all()))
