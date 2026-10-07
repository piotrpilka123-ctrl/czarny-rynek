extends RefCounted
## Stół roboczy: porcjowanie i mieszanie. Nie ma zręcznościówki ani trybów pracy — o tempie i stratach
## decyduje sama WAGA (kuchenna, jubilerska, laboratoryjna…). Wpisujesz, ile gramów, i patrzysz,
## jak robota idzie gram po gramie. Można przerwać w dowolnej chwili.

const K = preload("res://scripts/uikit.gd")
const View = preload("res://scripts/bench_view.gd")


static func _packed_here(room: String, p: String) -> int:
	return G.packed_total(G.S.inv, p) + G.packed_total(G.S.stash[room], p)


static func _tile(U, s: Dictionary, on: bool) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_stylebox_override("normal", K.sb(Color(0.13, 0.17, 0.24) if on else Color(0.085, 0.102, 0.15), 9, K.C_ACC if on else Color(1, 1, 1, 0.07), 1, 8))
	b.add_theme_stylebox_override("hover", K.sb(Color(0.13, 0.16, 0.23), 9, K.C_ACC if on else Color(1, 1, 1, 0.2), 1, 8))
	b.add_theme_stylebox_override("pressed", K.sb(Color(0.07, 0.085, 0.12), 9, K.C_ACC, 1, 8))
	b.pressed.connect(func():
		Sfx.play("click")
		U.bench.sel = s
		U.bench.mixing = false
		U._render_bench())
	var h := K.hbox(9)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(K.icon("bulk_" + String(s.p), 36))
	var v := K.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(K.lbl(String(D.PRODUCTS[s.p].name), 14, K.C_TXT))
	v.add_child(K.rich(K.tier_bb(s.pur), 12))
	h.add_child(v)
	# po prawej: ile luzem, a pod spodem ile już zaporcjowane
	var q := K.vbox(0)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.alignment = BoxContainer.ALIGNMENT_CENTER
	var big := K.head(G.grams(s.n) if float(s.n) > 0.0 or int(s.get("k", 0)) <= 0 else "%d porcji" % int(s.k), 18 if float(s.n) > 0.0 else 15, K.C_TXT)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	q.add_child(big)
	if float(s.n) > 0.0 and int(s.get("k", 0)) > 0:
		var small := K.lbl("+ %d porcji" % int(s.k), 11, K.C_ACC)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		q.add_child(small)
	elif float(s.n) > 0.0:
		var small2 := K.lbl("luzem", 11, K.C_DIM)
		small2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		q.add_child(small2)
	h.add_child(q)
	return b


static func build(U) -> void:
	var B: Dictionary = U.bench
	var room: String = B.room
	var S: Dictionary = G.S
	U._open_modal("Stół roboczy", "Waga i towar. Luzem nikt nie kupi — najpierw porcjuj.", "center", 1000.0)
	var body: VBoxContainer = U.modal_body
	var stacks := G.bench_pool(room)
	# zaznaczony stos: odśwież ilość albo wybierz pierwszy z brzegu
	var sel := {}
	for s in stacks:
		if not B.sel.is_empty() and s.p == B.sel.p and int(s.pur) == int(B.sel.pur):
			sel = s
	if sel.is_empty() and not stacks.is_empty():
		sel = stacks[0]
		B.mixing = false
	B.sel = sel

	var top := K.hbox(16)
	body.add_child(top)
	var sc: Dictionary = G.scale_def()
	# strata „z metki” wagi (pierwsze gramy w życiu i tak się udają — tego tu nie pokazujemy)
	var nominal: float = float(sc.waste) * (0.6 if G.has_skill("reka") else 1.0)
	var sc_l := K.icon_label("scale", "%s — gram w %s min, %s" % [String(sc.name), ("%.1f" % G.pack_minutes()).replace(".", ","), "bez strat" if nominal <= 0.0 else "straty ok. %d%%" % int(round(nominal * 100.0))], 13, K.C_TXT, 16)
	sc_l.tooltip_text = String(sc.desc) + ("
Lepszą wagę kupisz w lombardzie przy Hutniczej." if G.scale() < D.SCALES.size() - 1 else "")
	top.add_child(sc_l)
	top.add_child(K.icon_label("majeranek", "Majeranek: %d g" % G.item_at(room, "majeranek"), 13, K.C_TXT, 20))
	if int(S.lvl) >= 4:
		top.add_child(K.icon_label("cukier", "Cukier puder: %d g" % G.item_at(room, "cukier"), 13, K.C_TXT, 20))
	top.add_child(K.spacer())
	top.add_child(K.icon_label("backpack", "%s: %s / %d" % [G.bag_name(), G.units(G.carry_total()), G.capacity()], 13, K.C_DIM, 15))
	top.add_child(K.icon_label("clock", G.clock(), 13, K.C_DIM, 15))

	var view := View.new()
	view.custom_minimum_size = Vector2(0, 236)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(view)
	B["view"] = view
	if not sel.is_empty():
		view.product = String(sel.p)
		view.pile_g = float(sel.n)
		view.pile_max = maxf(20.0, float(sel.n))
		view.packs_before = _packed_here(room, sel.p)
		view.tint = 0.6 if G.is_mix(sel.pur) else 0.0
	view.scale_name = String(sc.name)
	view.scale_tier = G.scale()

	var cols := K.hbox(12)
	body.add_child(cols)
	# ---------------------------------------------------------------- towar luzem
	var left := K.panel(K.sb(K.C_CARD, 12, K.C_LINE, 1, 12))
	left.custom_minimum_size = Vector2(300, 0)
	cols.add_child(left)
	var lv := K.vbox(6)
	left.add_child(lv)
	lv.add_child(K.lbl("TOWAR NA STOLE (plecak i skrytka razem)", 10, K.C_DIM))
	if stacks.is_empty():
		lv.add_child(K.wrap("Nie masz towaru. Zamów przez telefon i odbierz paczkę.", 13, K.C_DIM))
	for s in stacks:
		lv.add_child(_tile(U, s, not sel.is_empty() and s.p == sel.p and int(s.pur) == int(sel.pur)))

	# ---------------------------------------------------------------- robota
	var right := K.panel(K.sb(K.C_CARD, 12, K.C_LINE, 1, 14))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rv := K.vbox(8)
	right.add_child(rv)
	if sel.is_empty():
		rv.add_child(K.wrap("Połóż towar na stole, żeby zacząć.", 13, K.C_DIM))
	elif B.mixing:
		_mix_ui(U, rv, view, sel)
	else:
		_pack_ui(U, rv, view, sel)


static func _pack_ui(U, rv: VBoxContainer, view, sel: Dictionary) -> void:
	var B: Dictionary = U.bench
	var room: String = B.room
	var maxg := G.pack_limit(room, sel.p, int(sel.pur))
	rv.add_child(K.rich("[b]Porcjowanie:[/b] %s %s  →  gotowe porcje" % [D.PRODUCTS[sel.p].name, K.tier_bb(sel.pur)], 14))
	var kpacks := int(sel.get("k", 0))
	# gotowe porcje można rozsypać z powrotem — pula towaru jest jedna, opakowanie niczego nie blokuje
	var unpack_btn := func() -> Button:
		var ub := K.btn("Rozsyp porcje (%d)" % kpacks, func():
			Sfx.play("pack")
			G.unpack(room, sel.p, int(sel.pur), kpacks)
			U._render_bench(), "", true)
		ub.tooltip_text = "Gotowe porcje wracają do towaru luzem — możesz je domieszać albo zważyć od nowa."
		return ub
	if maxg <= 0:
		if kpacks > 0:
			rv.add_child(K.rich("Wszystko zważone: [b]%d porcji[/b] gotowych do sprzedaży." % kpacks, 13))
		else:
			rv.add_child(K.lbl("Potrzebujesz co najmniej 1 g towaru.", 12, K.C_WARN))
		var a0 := K.hbox(8)
		rv.add_child(a0)
		var mx0 := K.btn("Domieszaj…", func(): B.mixing = true; B.filler = 1; U._render_bench(), "warn", true)
		mx0.disabled = G.item_at(room, G.filler_for(sel.p)) <= 0 or float(sel.n) + kpacks < 1.0
		a0.add_child(mx0)
		if kpacks > 0:
			a0.add_child(unpack_btn.call())
		return
	B.g = clampi(int(B.g), 1, maxg)
	var g := int(B.g)
	# ile
	var qh := K.hbox(6)
	rv.add_child(qh)
	qh.add_child(K.lbl("ILE:", 11, K.C_DIM))
	for st in [-5, -1]:
		var d1: int = st
		var b1 := K.btn(str(st), func(): B.g = clampi(int(B.g) + d1, 1, maxg); U._render_bench(), "", true)
		b1.disabled = g <= 1
		qh.add_child(b1)
	var ge := LineEdit.new()
	ge.text = str(g)
	ge.custom_minimum_size = Vector2(70, 34)
	ge.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ge.max_length = 4
	ge.select_all_on_focus = true
	ge.tooltip_text = "Wpisz, ile gramów zaporcjować, i naciśnij Enter"
	ge.add_theme_font_size_override("font_size", 18)
	ge.add_theme_stylebox_override("normal", K.sb(Color(0.03, 0.04, 0.06), 8, Color(1, 1, 1, 0.18), 1, 8))
	ge.add_theme_stylebox_override("focus", K.sb(Color(0.03, 0.04, 0.06), 8, K.C_ACC, 1, 8))
	ge.text_submitted.connect(func(t: String): B.g = clampi(int(t), 1, maxg); U._render_bench())
	qh.add_child(ge)
	qh.add_child(K.lbl("g", 13, K.C_DIM))
	for st in [1, 5]:
		var d2: int = st
		var b2 := K.btn("+%d" % st, func(): B.g = clampi(int(B.g) + d2, 1, maxg); U._render_bench(), "", true)
		b2.disabled = g >= maxg
		qh.add_child(b2)
	var ball := K.btn("wszystko (%d)" % maxg, func(): B.g = maxg; U._render_bench(), "", true)
	ball.disabled = g >= maxg
	qh.add_child(ball)
	# szacunek
	var waste := G.pack_waste()
	var est_of := func(n: int) -> String:
		var mins := G.pack_minutes() * n
		var est := "Zajmie ok. [b]%s[/b] gry" % (("%d min" % int(ceil(mins))) if mins < 90.0 else ("%.1f godz." % (mins / 60.0)))
		if waste <= 0.0:
			return est + "  •  [color=#4ade80]bez strat[/color]"
		return est + "  •  straty ok. [color=#fbbf24]%d%%[/color] (średnio %s g z tej partii)" % [int(round(waste * 100.0)), ("%.1f" % (waste * n)).replace(".", ",")]
	var est_l := K.rich(est_of.call(g), 13)
	rv.add_child(est_l)
	# przyciski / pasek roboty
	var acts := K.hbox(8)
	rv.add_child(acts)
	var status := K.rich("", 13)
	status.visible = false
	rv.add_child(status)
	var go := K.btn("  Porcjuj %d g  " % g, func(): pass, "go")
	go.custom_minimum_size = Vector2(0, 40)
	acts.add_child(go)
	# wpisywana liczba od razu zmienia przycisk i szacunek (bez Entera)
	ge.text_changed.connect(func(t: String):
		var digits := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits != t:
			var cc := ge.caret_column
			ge.text = digits
			ge.caret_column = mini(cc, digits.length())
		if digits == "":
			return
		B.g = clampi(int(digits), 1, maxg)
		go.text = "  Porcjuj %d g  " % int(B.g)
		est_l.text = est_of.call(int(B.g)))
	var mixb := K.btn("Domieszaj…", func(): B.mixing = true; B.filler = 1; U._render_bench(), "warn")
	mixb.disabled = G.item_at(room, G.filler_for(sel.p)) <= 0
	mixb.tooltip_text = "Rozrabianie towaru. Potrzebny dodatek ze sklepu: " + String(D.FILLER_NAMES[G.filler_for(sel.p)]).to_lower()
	acts.add_child(mixb)
	var unb: Button = null
	if kpacks > 0:
		unb = unpack_btn.call()
		acts.add_child(unb)
	var stopb := K.btn("Przerwij", func(): view.stop(), "bad")
	stopb.visible = false
	acts.add_child(stopb)
	go.pressed.connect(func():
		if view.busy():
			return
		go.visible = false
		mixb.visible = false
		if unb != null:
			unb.visible = false
		stopb.visible = true
		status.visible = true
		var done_n := [0, 0]
		var upd := func():
			status.text = "Gotowe [b]%d[/b] z %d%s   [color=#8f96a8]przytrzymaj SPACJĘ, żeby przyspieszyć[/color]" % [done_n[0], int(B.g), ("  •  [color=#fbbf24]rozsypano %d g[/color]" % done_n[1]) if done_n[1] > 0 else ""]
		upd.call()
		var step := func() -> int:
			var r := G.pack_one(room, sel.p, int(sel.pur))
			if r == 1:
				done_n[0] += 1
			elif r == 0:
				done_n[1] += 1
			upd.call()
			return r
		var done := func(good: int, lost: int) -> void:
			G.pack_report(good, lost)
			if U.mode == "modal" and U.deal.is_empty():
				U._render_bench()
		# im gorsza waga, tym bardziej towar pryska na boki
		view.start(int(B.g), 2 if waste > 0.04 else (1 if waste > 0.0 else 0), float(G.scale_def().sec), step, done))


static func _mix_ui(U, rv: VBoxContainer, view, sel: Dictionary) -> void:
	var B: Dictionary = U.bench
	var room: String = B.room
	# do mieszanki idzie cała pula tego towaru: luzem i w porcjach
	var have := float(sel.n) + float(int(sel.get("k", 0)))
	var fid: String = G.filler_for(sel.p)
	var fname: String = D.FILLER_NAMES[fid]
	view.filler = fid
	rv.add_child(K.rich("[b]Mieszanka:[/b] %s %s — %s  +  %s" % [D.PRODUCTS[sel.p].name, K.tier_bb(sel.pur), G.grams(have), fname.to_lower()], 14))
	var maxf_g: int = mini(G.item_at(room, fid), int(floor(have)))
	if maxf_g <= 0:
		rv.add_child(K.lbl("Brak dodatku (%s) — kupisz go w sklepie u Stasia." % fname.to_lower(), 12, K.C_WARN))
		rv.add_child(K.btn("Wróć", func(): B.mixing = false; U._render_bench(), "", true))
		return
	B.filler = clampi(int(B.filler), 1, maxf_g)
	var info := K.rich("", 13)
	var upd := func(f: int):
		var eff := float(f) * (0.8 if G.has_skill("mieszanie") else 1.0)
		var np: int = G.qmix(float(sel.pur) * have / (have + eff))
		info.text = "%s: [b]%d g[/b]  →  razem [b]%s[/b], %s\nCena uliczna: %s → %s za gram" % [fname, f, G.grams(have + f), K.tier_bb(np), G.money(G.market_price(sel.p, sel.pur)), G.money(G.market_price(sel.p, np))]
	upd.call(int(B.filler))
	rv.add_child(info)
	var sl := HSlider.new()
	sl.min_value = 1
	sl.max_value = maxf_g
	sl.step = 1
	sl.value = int(B.filler)
	sl.focus_mode = Control.FOCUS_NONE
	sl.editable = maxf_g > 1
	sl.value_changed.connect(func(v: float):
		B.filler = int(v)
		upd.call(int(v)))
	rv.add_child(sl)
	rv.add_child(K.wrap("Więcej gramów to więcej pieniędzy — dopóki klienci nie poczują różnicy. Stali klienci, którzy biorą dużo, rozpoznają mieszankę i po prostu odmówią. Mieszanka nigdy nie łączy się z czystym towarem.", 12, K.C_DIM))
	var acts := K.hbox(8)
	rv.add_child(acts)
	var go := K.btn("  Zmieszaj  ", func(): pass, "warn")
	go.custom_minimum_size = Vector2(0, 40)
	acts.add_child(go)
	var back := K.btn("Wróć", func(): B.mixing = false; U._render_bench())
	acts.add_child(back)
	go.pressed.connect(func():
		if view.busy():
			return
		go.disabled = true
		back.disabled = true
		sl.editable = false
		var f := int(B.filler)
		Sfx.play("pack")
		var after := func() -> void:
			G.add_minutes(4.0)
			var np := G.mix(room, sel.p, int(sel.pur), have, f)
			B.mixing = false
			B.sel = {"p": sel.p, "pur": np, "n": have + f, "k": 0}
			if U.mode == "modal" and U.deal.is_empty():
				U._render_bench()
		view.mix(float(f), after))
