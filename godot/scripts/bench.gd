extends RefCounted
## Stół roboczy: porcjowanie i mieszanie. Zamiast zręcznościówki wybierasz TRYB PRACY
## (dokładnie / normalnie / na szybko) i patrzysz, jak robota idzie gram po gramie —
## płacisz czasem gry albo rozsypanym towarem. Można przerwać w dowolnej chwili.

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
	h.add_child(K.head(G.grams(s.n), 18, K.C_TXT))
	return b


static func build(U) -> void:
	var B: Dictionary = U.bench
	var room: String = B.room
	var S: Dictionary = G.S
	U._open_modal("Stół roboczy", "Waga, woreczki i towar. Luzem nikt nie kupi — najpierw porcjuj.", "center", 1000.0)
	var body: VBoxContainer = U.modal_body
	var stacks := G.bench_bulk(room)
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
	var bags := G.item_at(room, "woreczki")
	top.add_child(K.icon_label("woreczki", "Woreczki: %d" % bags, 13, K.C_TXT if bags > 0 else K.C_BAD, 20))
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
	view.bags_left = bags

	var cols := K.hbox(12)
	body.add_child(cols)
	# ---------------------------------------------------------------- towar luzem
	var left := K.panel(K.sb(K.C_CARD, 12, K.C_LINE, 1, 12))
	left.custom_minimum_size = Vector2(300, 0)
	cols.add_child(left)
	var lv := K.vbox(6)
	left.add_child(lv)
	lv.add_child(K.lbl("TOWAR LUZEM (plecak + skrytka)", 10, K.C_DIM))
	if stacks.is_empty():
		lv.add_child(K.wrap("Nie masz towaru luzem. Zamów przez telefon i odbierz paczkę.", 13, K.C_DIM))
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
	if bags <= 0:
		body.add_child(K.wrap("Brak woreczków — kupisz je w sklepie u Stasia (ul. Hutnicza).", 12, K.C_WARN))


static func _pack_ui(U, rv: VBoxContainer, view, sel: Dictionary) -> void:
	var B: Dictionary = U.bench
	var room: String = B.room
	var mode: int = clampi(int(B.get("mode", 1)), 0, 2)
	var maxg := G.pack_limit(room, sel.p, int(sel.pur))
	rv.add_child(K.rich("[b]Porcjowanie:[/b] %s %s  →  woreczki po 1 g" % [D.PRODUCTS[sel.p].name, K.tier_bb(sel.pur)], 14))
	# tryb pracy
	var mh := K.hbox(6)
	rv.add_child(mh)
	mh.add_child(K.lbl("TEMPO:", 11, K.C_DIM))
	for i in range(G.PACK_MODES.size()):
		var mi := i
		var md: Dictionary = G.PACK_MODES[i]
		var mb := K.btn(String(md.name), func(): B["mode"] = mi; U._render_bench(), "go" if i == mode else "", true)
		mb.tooltip_text = String(md.desc)
		mh.add_child(mb)
	rv.add_child(K.wrap(String(G.PACK_MODES[mode].desc), 12, K.C_DIM))
	if maxg <= 0:
		rv.add_child(K.lbl("Potrzebujesz co najmniej 1 g towaru i 1 woreczka.", 12, K.C_WARN))
		var mx0 := K.btn("Domieszaj…", func(): B.mixing = true; B.filler = 1; U._render_bench(), "warn", true)
		mx0.disabled = G.item_at(room, G.filler_for(sel.p)) <= 0 or float(sel.n) < 1.0
		rv.add_child(mx0)
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
	var gl := K.head("%d g" % g, 24, Color.WHITE)
	gl.custom_minimum_size = Vector2(66, 0)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qh.add_child(gl)
	for st in [1, 5]:
		var d2: int = st
		var b2 := K.btn("+%d" % st, func(): B.g = clampi(int(B.g) + d2, 1, maxg); U._render_bench(), "", true)
		b2.disabled = g >= maxg
		qh.add_child(b2)
	var ball := K.btn("wszystko (%d)" % maxg, func(): B.g = maxg; U._render_bench(), "", true)
	ball.disabled = g >= maxg
	qh.add_child(ball)
	# szacunek
	var mins := G.pack_minutes(mode) * g
	var waste := G.pack_waste(mode)
	var est := "Zajmie ok. [b]%s[/b] gry" % (("%d min" % int(ceil(mins))) if mins < 90.0 else ("%.1f godz." % (mins / 60.0)))
	if waste <= 0.0:
		est += "  •  [color=#4ade80]bez strat[/color]"
	else:
		est += "  •  straty ok. [color=#fbbf24]%d%%[/color] (średnio %s g z tej partii)" % [int(round(waste * 100.0)), ("%.1f" % (waste * g)).replace(".", ",")]
	rv.add_child(K.rich(est, 13))
	# przyciski / pasek roboty
	var acts := K.hbox(8)
	rv.add_child(acts)
	var status := K.rich("", 13)
	status.visible = false
	rv.add_child(status)
	var go := K.btn("  Porcjuj %d g  " % g, func(): pass, "go")
	go.custom_minimum_size = Vector2(0, 40)
	acts.add_child(go)
	var mixb := K.btn("Domieszaj…", func(): B.mixing = true; B.filler = 1; U._render_bench(), "warn")
	mixb.disabled = G.item_at(room, G.filler_for(sel.p)) <= 0
	mixb.tooltip_text = "Rozrabianie towaru. Potrzebny dodatek ze sklepu: " + String(D.FILLER_NAMES[G.filler_for(sel.p)]).to_lower()
	acts.add_child(mixb)
	var stopb := K.btn("Przerwij", func(): view.stop(), "bad")
	stopb.visible = false
	acts.add_child(stopb)
	go.pressed.connect(func():
		if view.busy():
			return
		go.visible = false
		mixb.visible = false
		stopb.visible = true
		status.visible = true
		var done_n := [0, 0]
		var upd := func():
			status.text = "Gotowe [b]%d[/b] z %d%s   [color=#8f96a8]przytrzymaj SPACJĘ, żeby przyspieszyć[/color]" % [done_n[0], g, ("  •  [color=#fbbf24]rozsypano %d g[/color]" % done_n[1]) if done_n[1] > 0 else ""]
		upd.call()
		var step := func() -> int:
			var r := G.pack_one(room, sel.p, int(sel.pur), mode)
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
		view.start(g, mode, float(G.PACK_MODES[mode].sec), step, done))


static func _mix_ui(U, rv: VBoxContainer, view, sel: Dictionary) -> void:
	var B: Dictionary = U.bench
	var room: String = B.room
	var have := float(sel.n)
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
		info.text = "%s: [b]%d g[/b]  →  razem [b]%s[/b], czystość %s\nCena uliczna: %s → %s za gram" % [fname, f, G.grams(have + f), K.tier_bb(np), G.money(G.market_price(sel.p, sel.pur)), G.money(G.market_price(sel.p, np))]
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
			B.sel = {"p": sel.p, "pur": np, "n": have + f}
			if U.mode == "modal" and U.deal.is_empty():
				U._render_bench()
		view.mix(float(f), after))
