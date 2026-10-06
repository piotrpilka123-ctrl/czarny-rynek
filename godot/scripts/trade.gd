extends RefCounted
## Okno wymiany przy sprzedaży — zamiast długiej rozmowy kładziesz towar „na ladę”:
## z lewej Twoje kieszenie (woreczki przeciągasz myszką), pośrodku lada z tym, co podajesz,
## z prawej gotówka klienta. Cenę ustalasz suwakiem albo trzymasz się tej umówionej przez telefon.
## Cała logika targów (nastrój, cierpliwość, kontroferty, zagrywki) zostaje w game.gd.

const K = preload("res://scripts/uikit.gd")


static func _tile_style(on: bool, hover := false) -> StyleBoxFlat:
	return K.sb(Color(0.13, 0.17, 0.24) if on else (Color(0.11, 0.135, 0.2) if hover else Color(0.085, 0.102, 0.15)), 10, K.C_ACC if on else Color(1, 1, 1, 0.16 if hover else 0.07), 1, 9)


## kafel towaru w kieszeni: da się go kliknąć albo przeciągnąć na ladę
static func _stack_tile(U, s: Dictionary, on: bool) -> Control:
	var p := K.panel(_tile_style(on))
	p.custom_minimum_size = Vector2(0, 58)
	p.mouse_default_cursor_shape = Control.CURSOR_DRAG
	p.mouse_entered.connect(func():
		if not on:
			p.add_theme_stylebox_override("panel", _tile_style(false, true)))
	p.mouse_exited.connect(func():
		if not on:
			p.add_theme_stylebox_override("panel", _tile_style(false)))
	var h := K.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(K.icon("pack_" + String(s.p), 42))
	var v := K.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(K.lbl(String(D.PRODUCTS[s.p].name), 14, K.C_TXT))
	var sub := K.rich(K.tier_bb(s.pur), 12)
	v.add_child(sub)
	h.add_child(v)
	var cnt := K.head("×%d" % int(s.n), 20, K.C_TXT)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(cnt)
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("click")
			U._deal_pick(s))
	var get_drag := func(_at: Vector2) -> Variant:
		var pv := K.panel(K.sb(Color(0.09, 0.11, 0.16, 0.95), 9, K.C_ACC, 1, 8))
		var ph := K.hbox(8)
		pv.add_child(ph)
		ph.add_child(K.icon("pack_" + String(s.p), 44))
		ph.add_child(K.lbl("%s  %d%%" % [String(D.PRODUCTS[s.p].name), int(s.pur)], 14, K.C_TXT))
		var holder := Control.new()
		holder.add_child(pv)
		pv.position = Vector2(10, 6)
		holder.z_index = 100
		p.set_drag_preview(holder)
		return {"stack": s}
	var no_drop := func(_at: Vector2, _data: Variant) -> bool: return false
	var drop_none := func(_at: Vector2, _data: Variant) -> void: pass
	p.set_drag_forwarding(get_drag, no_drop, drop_none)
	return p


static func _chip(text: String, cb: Callable, tip := "", on := true, kind := "") -> Button:
	var b := K.btn(text, cb, kind, true)
	b.disabled = not on
	b.tooltip_text = tip
	return b


## pasek „ile klient zniesie”: zielono do ceny, którą weźmie w ciemno, żółto do progu, czerwono dalej.
## Bez umiejętności „Czytanie ludzi” widać tylko rynek i własną cenę.
static func _gauge(deal: Dictionary, lo_v: float, hi_v: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 26)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var w := c.size.x
		var mk := G.market_price(deal.sel.p, deal.sel.pur)
		var X := func(v: float) -> float: return clampf((v - lo_v) / maxf(1.0, hi_v - lo_v), 0.0, 1.0) * w
		c.draw_rect(Rect2(0, 8, w, 8), Color(1, 1, 1, 0.08))
		var hint := G.deal_hint(deal)
		if not hint.is_empty():
			c.draw_rect(Rect2(0, 8, X.call(float(hint.lo) * 0.9), 8), Color(0.29, 0.87, 0.5, 0.7))
			c.draw_rect(Rect2(X.call(float(hint.lo) * 0.9), 8, X.call(float(hint.hi)) - X.call(float(hint.lo) * 0.9), 8), Color(0.98, 0.75, 0.14, 0.7))
			c.draw_rect(Rect2(X.call(float(hint.hi)), 8, w - X.call(float(hint.hi)), 8), Color(0.94, 0.3, 0.3, 0.45))
		# rynek i Twoja cena
		var xm: float = X.call(mk)
		c.draw_line(Vector2(xm, 4), Vector2(xm, 20), Color(1, 1, 1, 0.7), 2.0)
		var xp: float = X.call(float(deal.price))
		K.poly(c, PackedVector2Array([Vector2(xp, 8), Vector2(xp - 6, 0), Vector2(xp + 6, 0)]), K.C_ACC)
		K.poly(c, PackedVector2Array([Vector2(xp, 16), Vector2(xp - 6, 24), Vector2(xp + 6, 24)]), K.C_ACC))
	return c


static func build(U) -> void:
	var deal: Dictionary = U.deal
	var S: Dictionary = G.S
	var who: Dictionary = deal.who
	var ctx: Dictionary = deal.ctx
	var body: VBoxContainer = U.modal_body
	var live := G.stacks(S.inv, "pack")
	if live.is_empty():
		deal.over = true
		deal.speech = "„Nie masz już towaru? No to nie ma o czym gadać.”"
		G.deal_finish(deal, {"sold": 0})
		U._render_deal()
		return
	var sel: Dictionary = deal.sel
	var have := int(S.inv.pack[sel.p].get(str(int(sel.pur)), 0))
	if have <= 0:
		deal.sel = live[0]
		sel = deal.sel
		have = int(sel.n)
		deal.price = int(round(G.market_price(sel.p, sel.pur)))
	var max_q: int = maxi(1, mini(have, int(deal.want) + int(deal.upsold)))
	deal.qty = clampi(int(deal.qty), 1, max_q)
	var sting: bool = ctx.get("sting", false)

	# --- przywitanie: jeden wybór tonu na początku rozmowy
	if not sting and deal.phase == "greet":
		var gh := K.hbox(8)
		body.add_child(gh)
		gh.add_child(K.lbl("PRZYWITANIE:", 11, K.C_DIM))
		var known: Dictionary = deal.st.get("known", {})
		for o in [["luz", "Na luzie"], ["konkret", "Konkretnie"], ["twardo", "Twardo"]]:
			var style: String = o[0]
			var mark := "  ★" if known.get("like", "") == style else ("  ✕" if known.get("hate", "") == style else "")
			gh.add_child(_chip(String(o[1]) + mark, func():
				G.deal_greet(deal, style)
				U._render_deal(), "Każdy klient lubi inny ton. Trafiony poprawia nastrój, chybiony go psuje.", true, "go" if mark == "  ★" else ""))
		gh.add_child(K.lbl("albo od razu kładź towar na ladę", 11, K.C_DIM))

	var cols := K.hbox(12)
	body.add_child(cols)

	# ---------------------------------------------------------------- 1. kieszenie
	var left := K.panel(K.sb(K.C_CARD, 12, K.C_LINE, 1, 12))
	left.custom_minimum_size = Vector2(300, 0)
	cols.add_child(left)
	var lv := K.vbox(6)
	left.add_child(lv)
	lv.add_child(K.icon_label("backpack", "TWOJE KIESZENIE", 11, K.C_DIM, 13))
	for s in live:
		lv.add_child(_stack_tile(U, s, s.p == sel.p and int(s.pur) == int(sel.pur)))
	lv.add_child(K.wrap("Przeciągnij woreczki na ladę albo kliknij, żeby zmienić towar.", 11, K.C_DIM))

	# ---------------------------------------------------------------- 2. lada
	var mid_sb := K.sb(Color(0.06, 0.075, 0.11), 12, K.C_ACC, 2, 14)
	mid_sb.border_color = Color(0.29, 0.87, 0.5, 0.55)
	var mid := K.panel(mid_sb)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var no_drag := func(_at: Vector2) -> Variant: return null
	var can_drop := func(_at: Vector2, data: Variant) -> bool: return data is Dictionary and data.has("stack")
	var do_drop := func(_at: Vector2, data: Variant) -> void:
		Sfx.play("place")
		deal.phase = "offer"
		U._deal_pick(data.stack)
	mid.set_drag_forwarding(no_drag, can_drop, do_drop)
	var mv := K.vbox(6)
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(mv)
	mv.add_child(K.icon_label("handshake", "LADA — TO PODAJESZ", 11, K.C_DIM, 13))
	var row := K.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_child(row)
	row.add_child(K.icon("pack_" + String(sel.p), 84))
	var qv := K.vbox(2)
	qv.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(qv)
	var ql := K.head("%d × 1 g" % int(deal.qty), 34, Color.WHITE)
	qv.add_child(ql)
	qv.add_child(K.rich("%s  %s" % [String(D.PRODUCTS[sel.p].name), K.tier_bb(sel.pur)], 13))
	var qb := K.hbox(6)
	qb.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_child(qb)
	var set_q := func(q: int):
		deal.qty = clampi(q, 1, max_q)
		U._render_deal()
	var minus := K.btn("−", func(): set_q.call(int(deal.qty) - 1), "", true)
	minus.custom_minimum_size = Vector2(44, 32)
	minus.disabled = int(deal.qty) <= 1
	qb.add_child(minus)
	var plus := K.btn("+", func(): set_q.call(int(deal.qty) + 1), "", true)
	plus.custom_minimum_size = Vector2(44, 32)
	plus.disabled = int(deal.qty) >= max_q
	qb.add_child(plus)
	var full := K.btn("tyle, ile chce (%d)" % max_q, func(): set_q.call(max_q), "", true)
	full.disabled = int(deal.qty) == max_q
	qb.add_child(full)
	# ocena tego, co leży na ladzie
	var minp := int(who.minpur)
	var note := ""
	var ncol := K.C_DIM
	if sel.p != deal.product:
		note = "Prosił o coś innego (%s)." % String(D.PRODUCT_GEN.get(deal.product, ""))
		ncol = K.C_BAD
	elif int(sel.pur) < minp - 15:
		note = "Dużo słabszy towar, niż oczekuje — może się obrazić."
		ncol = K.C_BAD
	elif int(sel.pur) < minp:
		note = "Słabszy towar, niż oczekuje — zapłaci mniej."
		ncol = K.C_WARN
	elif int(sel.pur) >= minp + 12:
		note = "Wyraźnie lepszy, niż oczekuje — doceni."
		ncol = K.C_ACC
	else:
		note = "Taki towar, jakiego oczekuje."
	if int(deal.qty) < int(deal.want):
		note += "  Mniej, niż zamawiał (%d z %d g)." % [int(deal.qty), int(deal.want)]
	var nl := K.wrap(note, 12, ncol)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(nl)

	# ---------------------------------------------------------------- 3. zapłata
	var right := K.panel(K.sb(K.C_CARD, 12, K.C_LINE, 1, 12))
	right.custom_minimum_size = Vector2(330, 0)
	cols.add_child(right)
	var rv := K.vbox(5)
	right.add_child(rv)
	rv.add_child(K.icon_label("banknote", "KASA KLIENTA", 11, K.C_DIM, 13))
	var mk := G.market_price(sel.p, sel.pur)
	var acts := K.flow()
	var pay := K.hbox(10)
	pay.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_child(pay)
	pay.add_child(K.icon("cash", 58))
	var pv2 := K.vbox(0)
	pay.add_child(pv2)
	var total_l := K.head("", 32, K.C_ACC)
	pv2.add_child(total_l)
	var per_l := K.lbl("", 12, K.C_DIM)
	pv2.add_child(per_l)
	if not deal.haggle:
		# cena umówiona przez telefon — wystarczy podać towar
		var ap := G.deal_agreed_price(deal)
		total_l.text = G.money(ap * int(deal.qty)) if ap > 0 else "—"
		per_l.text = ("%s za gram (umówione)" % G.money(ap)) if ap > 0 else "tego nie weźmie"
		var ba := K.btn("  Dobij targu  ", func(): deal.phase = "offer"; G.deal_sell_agreed(deal); U._render_deal(), "go")
		ba.custom_minimum_size = Vector2(0, 40)
		ba.disabled = ap <= 0
		acts.add_child(ba)
		acts.add_child(_chip("Podbij cenę", func(): deal.phase = "offer"; G.deal_haggle(deal); U._render_deal(), "Zrywasz umowę z telefonu i targujesz się od nowa. Klientowi się to nie spodoba.", true, "warn"))
	else:
		var lo_v := maxf(1.0, roundf(mk * 0.4))
		var hi_v := roundf(mk * 2.0)
		total_l.text = G.money(int(deal.price) * int(deal.qty))
		per_l.text = "%s za gram%s" % [G.money(deal.price), "  •  połowa teraz, reszta na zeszyt" if deal.credit else ""]
		var gauge := _gauge(deal, lo_v, hi_v)
		rv.add_child(gauge)
		var ps := HSlider.new()
		ps.min_value = lo_v
		ps.max_value = hi_v
		ps.step = 1
		ps.value = int(deal.price)
		ps.focus_mode = Control.FOCUS_NONE
		rv.add_child(ps)
		var hint := G.deal_hint(deal)
		var ht := "biała kreska = cena rynkowa (%s)" % G.money(mk)
		if not hint.is_empty():
			ht += "\nzielone: weźmie bez gadania • żółte: będzie się targował"
		rv.add_child(K.lbl(ht, 11, K.C_DIM))
		ps.value_changed.connect(func(v: float):
			deal.price = int(v)
			total_l.text = G.money(int(v) * int(deal.qty))
			per_l.text = "%s za gram" % G.money(v)
			gauge.queue_redraw())
		if deal.counter != null:
			var bc := K.btn("  Bierz %s za gram  " % G.money(deal.counter), func(): deal.phase = "offer"; G.deal_accept(deal); U._render_deal(), "go")
			bc.custom_minimum_size = Vector2(0, 40)
			acts.add_child(bc)
		var bo := K.btn("  Podaj cenę  ", func(): deal.phase = "offer"; G.deal_offer(deal); U._render_deal(), "go" if deal.counter == null else "")
		bo.custom_minimum_size = Vector2(0, 40)
		acts.add_child(bo)

	# ---------------------------------------------------------------- zagrywki (każda raz)
	if not sting:
		var tips := {"pogadaj": "message_circle", "zachwal": "star", "probka": "gift", "ostatnie": "flame", "ilosc": "boxes", "zeszyt": "notebook_pen", "odejdz": "log_out"}
		var th := K.hbox(6)
		body.add_child(th)
		th.add_child(K.lbl("ZAGRYWKI:", 11, K.C_DIM))
		for t in G.deal_tactics(deal):
			var tid: String = t.id
			if tid == "zeszyt" and not deal.haggle:
				continue
			var b := _chip(String(t.label), func(): deal.phase = "offer"; G.deal_tactic(deal, tid); U._render_deal(), String(t.tip), bool(t.on))
			b.icon = K.tex(tips.get(tid, "info"))
			b.add_theme_constant_override("icon_max_width", 14)
			th.add_child(b)
	var foot := K.hbox(8)
	body.add_child(foot)
	foot.add_child(acts)
	foot.add_child(K.spacer())
	U._deal_exit_buttons(foot, true)
