extends RefCounted
## Okno wymiany przy sprzedaży — bez gadania. Wybierasz porcję, ewentualnie zmieniasz SUMĘ za całość (−10 / −1 / +1 / +10 zł)
## i PODAJESZ towar: przytrzymujesz przycisk (albo [E] / spację). Świat się w tym czasie nie zatrzymuje,
## więc pasek u góry pokazuje, ilu ludzi może Was widzieć i czy patrzy patrol.
## Logika (próg klienta, ocena towaru, sprzedaż) siedzi w game.gd: deal_start / deal_set / deal_hand.

const K = preload("res://scripts/uikit.gd")


static func _tile_style(on: bool, hover := false) -> StyleBoxFlat:
	return K.sb(Color(0.13, 0.17, 0.24) if on else (Color(0.11, 0.135, 0.2) if hover else Color(0.085, 0.102, 0.15)), 10, K.C_ACC if on else Color(1, 1, 1, 0.16 if hover else 0.07), 1, 9)


## kafel woreczka w kieszeni: kliknięcie wybiera, co podajesz
static func _stack_tile(U, s: Dictionary, on: bool, fits: bool) -> Control:
	var p := K.panel(_tile_style(on))
	p.custom_minimum_size = Vector2(196, 54)
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.mouse_entered.connect(func():
		if not on:
			p.add_theme_stylebox_override("panel", _tile_style(false, true)))
	p.mouse_exited.connect(func():
		if not on:
			p.add_theme_stylebox_override("panel", _tile_style(false)))
	var h := K.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(K.icon("pack_" + String(s.p), 38))
	var v := K.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(K.lbl(String(D.PRODUCTS[s.p].name), 13, K.C_TXT if fits else K.C_DIM))
	var pure: bool = not G.is_mix(s.pur) and int(s.pur) >= 95
	v.add_child(K.lbl("czystość %d%%%s" % [int(s.pur), "" if pure or not G.is_mix(s.pur) else " • mieszanka"], 11, Color(0.6, 0.64, 0.7)))
	h.add_child(v)
	var cnt := K.head("×%d" % int(s.n), 18, K.C_TXT)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(cnt)
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("click")
			U._deal_pick(s))
	return p


## pasek „kto patrzy”: świadkowie w pobliżu i patrol, który ma Was na oku
static func watch_row(U) -> Control:
	var h := K.hbox(8)
	var w: Dictionary = G.deal_watchers()
	var n := int(w.witnesses)
	var col: Color = K.C_ACC if n == 0 else (K.C_WARN if n <= 2 else K.C_BAD)
	h.add_child(K.icon("eye" if n > 0 else "eye_off", 15, col))
	var txt := "Nikt nie patrzy" if n == 0 else ("W pobliżu: %d %s" % [n, "osoba" if n == 1 else ("osoby" if n < 5 else "osób")])
	U.deal_watch_l = K.lbl(txt, 12, col)
	h.add_child(U.deal_watch_l)
	h.add_child(K.spacer())
	U.cop_bar = K.bar(float(U.deal.cop_t), float(U.deal.cop_max), K.C_BAD, 7.0)
	U.cop_bar.custom_minimum_size = Vector2(190, 7)
	U.cop_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	U.deal_cop_l = K.icon_label("siren", "Patrol patrzy!", 12, Color(1, 0.7, 0.7), 14.0)
	U.deal_cop_l.visible = float(U.deal.cop_t) > 0.05
	U.cop_bar.visible = U.deal_cop_l.visible
	h.add_child(U.deal_cop_l)
	h.add_child(U.cop_bar)
	return h


static func build(U) -> void:
	var deal: Dictionary = U.deal
	var S: Dictionary = G.S
	var who: Dictionary = deal.who
	var ctx: Dictionary = deal.ctx
	var body: VBoxContainer = U.modal_body
	var live := G.stacks(S.inv, "pack")
	if live.is_empty():
		deal.over = true
		deal.speech = "„Nie masz już towaru? To po co stoimy.”"
		G.deal_finish(deal, {"sold": 0})
		U._render_deal()
		return
	var sel: Dictionary = deal.sel
	var have := int(S.inv.pack[sel.p].get(str(int(sel.pur)), 0))
	if have <= 0:
		deal.sel = live[0]
		sel = deal.sel
		have = int(sel.n)
	var street: bool = ctx.get("agreed") == null
	var max_q: int = maxi(1, mini(have, int(deal.want)))
	deal.qty = clampi(int(deal.qty), 1, max_q)
	var sting: bool = ctx.get("sting", false)
	# --- co podajesz: woreczki z kieszeni (tylko właściwy towar się nadaje)
	var top := K.hbox(10)
	body.add_child(top)
	var tiles := K.hbox(6)
	top.add_child(tiles)
	var shown := 0
	for s in live:
		if shown >= 3:
			break
		var fits: bool = String(s.p) == String(ctx.product) or sting
		if not fits and shown >= 2:
			continue
		tiles.add_child(_stack_tile(U, s, s.p == sel.p and int(s.pur) == int(sel.pur), fits))
		shown += 1
	top.add_child(K.spacer())
	# ile gramów: przy zamówieniu z góry wiadomo, na ulicy możesz dać mniej
	if max_q > 1 and street:
		var qh := K.hbox(4)
		qh.add_child(K.lbl("ile:", 11, K.C_DIM))
		for q0 in range(1, max_q + 1):
			var q: int = q0
			qh.add_child(K.btn("%d g" % q, func(): G.deal_qty(deal, q); U._render_deal(), "go" if int(deal.qty) == q else "", true))
		top.add_child(qh)
	if int(sel.pur) < int(who.minpur) and (int(deal.st.get("deals", 9)) >= 3 or not deal.st.has("deals")) and not sting:
		body.add_child(K.icon_label("triangle_alert", "Ten klient zwykle bierze towar od %d%% w górę — może to wyczuć i odmówić." % int(who.minpur), 11, K.C_WARN, 13.0))
	# --- cena: SUMA za całość na środku, po bokach dwa małe przyciski — w lewo taniej (−10, −1), w prawo drożej (+1, +10)
	var ph := K.hbox(6)
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(ph)
	var base_sum: int = G.deal_base_sum(deal)
	var step_btn := func(delta: int) -> Button:
		var sb := K.btn(("%+d" % delta), func():
			if G.deal_shift(deal, delta):
				Sfx.play("tick")
			else:
				Sfx.play("error")
			U._render_deal(), "", true)
		sb.custom_minimum_size = Vector2(52, 40)
		sb.add_theme_font_size_override("font_size", 15)
		sb.disabled = deal.over or (delta > 0 and deal.pushed) or (sting and delta < 0)
		sb.tooltip_text = "Po odmowie nie da się już podbić ceny." if (delta > 0 and deal.pushed) else ("Taniej o %d zł" % -delta if delta < 0 else "Drożej o %d zł" % delta)
		return sb
	ph.add_child(step_btn.call(-10))
	ph.add_child(step_btn.call(-1))
	var mid := K.vbox(-2)
	mid.custom_minimum_size = Vector2(250, 0)
	var sum_l := K.head(G.money(int(deal.sum)), 30, K.C_ACC)
	sum_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(sum_l)
	var diff: int = int(deal.sum) - base_sum
	var read: String = G.deal_read(deal, float(deal.pct))
	var tips := {"sure": "weźmie", "ok": "raczej weźmie", "risk": "ryzykowne", "no": "nie przejdzie", "": ""}
	var tcol := {"sure": K.C_ACC, "ok": K.C_ACC, "risk": K.C_WARN, "no": K.C_BAD, "": K.C_DIM}
	var tag := ("umówione" if not street else "cena uliczna") if diff == 0 else ("%s %s (%+d zł)" % ["umówione" if not street else "uliczna", G.money(base_sum), diff])
	var sub_l := K.lbl("za %d g  •  %s%s" % [int(deal.qty), tag, (" • " + String(tips[read])) if read != "" and diff != 0 else ""], 11, tcol[read] if diff != 0 else K.C_DIM)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(sub_l)
	ph.add_child(mid)
	ph.add_child(step_btn.call(1))
	ph.add_child(step_btn.call(10))
	# --- podanie: przytrzymaj. Pasek rośnie, puszczenie go cofa.
	var foot := K.hbox(8)
	body.add_child(foot)
	var hb := Button.new()
	hb.focus_mode = Control.FOCUS_NONE
	hb.custom_minimum_size = Vector2(0, 46)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.text = "PODAJ TOWAR  —  przytrzymaj tutaj albo [%s]" % G.kn("use")
	hb.add_theme_font_size_override("font_size", 15)
	hb.add_theme_stylebox_override("normal", K.sb(Color(0.1, 0.36, 0.2), 10, K.C_ACC, 1, 10))
	hb.add_theme_stylebox_override("hover", K.sb(Color(0.12, 0.42, 0.24), 10, K.C_ACC, 2, 10))
	hb.add_theme_stylebox_override("pressed", K.sb(Color(0.14, 0.5, 0.28), 10, Color.WHITE, 2, 10))
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
