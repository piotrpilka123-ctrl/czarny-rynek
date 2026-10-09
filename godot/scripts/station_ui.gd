extends RefCounted
## Panel stanowiska produkcyjnego (regał, suszarka, stół laboratoryjny) i ekran stanu kryjówki.
## Żadnych zręcznościówek: decyzje (tryb lamp / temperatura, nawóz, przycinanie, pilnowanie wody
## i etapów) plus animowany podgląd tego, co się dzieje.

const K = preload("res://scripts/uikit.gd")
const View = preload("res://scripts/station_view.gd")


static func _time(m: float) -> String:
	return "%dh %02dm" % [int(m / 60.0), int(m) % 60]


static func _stat(parent: Node, ic: String, label: String, value: String, col := K.C_TXT) -> void:
	var h := K.hbox(6)
	h.add_child(K.icon(ic, 15, K.C_DIM))
	h.add_child(K.lbl(label, 12, K.C_DIM))
	h.add_child(K.spacer())
	h.add_child(K.head(value, 16, col))
	parent.add_child(h)


static func _bar_row(parent: Node, ic: String, label: String, v: float, col: Color) -> void:
	var h := K.hbox(6)
	h.add_child(K.icon(ic, 15, col))
	var l := K.lbl(label, 12, K.C_DIM)
	l.custom_minimum_size = Vector2(74, 0)
	h.add_child(l)
	var b := K.bar(v, 100.0, col, 8.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	var n := K.head("%d%%" % int(round(v)), 15, col)
	n.custom_minimum_size = Vector2(44, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	parent.add_child(h)


## pasek z podsumowaniem kryjówki: zapach, prąd, ryzyko nalotu
static func hide_strip(U, room: String, with_button := true) -> Control:
	var st: Dictionary = G.Prod.stats(room)
	var p := K.panel(K.sb(Color(0.066, 0.071, 0.086), 9, K.C_LINE, 1, 10))
	var h := K.hbox(16)
	p.add_child(h)
	h.add_child(K.icon_label("house", String(D.ROOMS[room].name), 13, K.C_TXT, 15))
	h.add_child(K.icon_label("wind", "Zapach: %d%s" % [int(round(float(st.smell))), "  (filtr)" if st.filter else ""], 13, K.C_WARN if float(st.smell) > 35.0 else K.C_DIM, 15))
	h.add_child(K.icon_label("zap", "Prąd: %s / dobę" % G.money(round(float(st.power))), 13, K.C_DIM, 15))
	var risk := float(st.risk)
	var rc := K.C_ACC if risk < 30.0 else (K.C_WARN if risk < 55.0 else K.C_BAD)
	h.add_child(K.icon_label("siren", "Ryzyko nalotu: %s" % G.Prod.risk_name(risk), 13, rc, 15))
	h.add_child(K.spacer())
	if with_button:
		h.add_child(K.btn("Stan kryjówki", func(): U.open_hideout(room), "", true))
	return p


static func build(U, room: String, idx: int) -> void:
	var P = G.Prod
	var f: Dictionary = P.furn(room, idx)
	if f.is_empty():
		return
	var kind := String(f["func"])
	var sub := {"grow": "Uprawa pod lampami. Pilnuj wody — reszta to Twoje decyzje.", "dry": "Świeży zbiór schnie tu 8 godzin, zanim trafi na wagę.", "lab": "Synteza z zestawu chemikaliów. Niektóre etapy czekają na Ciebie."}
	U._open_modal(String(f.name), String(sub.get(kind, "")), "center", 1000.0)
	U.station = {"room": room, "idx": idx}
	var body: VBoxContainer = U.modal_body
	body.add_child(hide_strip(U, room))
	var view := View.new()
	view.kind = kind
	view.room = room
	view.idx = idx
	view.pots = int(f.get("pots", 1))
	view.custom_minimum_size = Vector2(0, 310)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(view)
	U.station["view"] = view
	var j = P.job(room, idx)
	var again := func() -> void:
		if U.mode == "modal" and U.deal.is_empty():
			G.world.update_stations()
			build(U, room, idx)
	if j == null:
		_empty_ui(U, body, view, room, idx, kind, again)
	elif String(j.r) == "_dry":
		_dry_ui(U, body, view, room, idx, j, again)
	else:
		_job_ui(U, body, view, room, idx, j, again)


static func _empty_ui(_U, body: VBoxContainer, view, room: String, idx: int, kind: String, again: Callable) -> void:
	var P = G.Prod
	if kind == "dry":
		var wet: float = P.wet_total(room)
		var c := K.card(body)
		if wet <= 0.0:
			c.add_child(K.wrap("Nie masz świeżego zbioru. Najpierw zetnij dojrzały krzak.", 13, K.C_DIM))
			return
		var parts: Array = []
		for w in P.hide(room).wet:
			parts.append("%s %s (%d%%)" % [G.grams(w.g), String(D.PRODUCT_GEN[w.p]), int(w.pur)])
		c.add_child(K.rich("Czeka na suszenie: [b]%s[/b]" % ", ".join(parts), 14))
		var cap := int(P.furn(room, idx).get("cap", 90))
		c.add_child(K.wrap("Suszarka mieści %d g naraz. Po 8 godzinach susz trafia do skrytki w tej kryjówce." % cap, 12, K.C_DIM))
		var b := K.btn("  Rozłóż na siatkach  ", func(): pass, "go")
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func():
			if view.busy():
				return
			Sfx.play("pack")
			P.dry_start(room, idx)
			again.call())
		c.add_child(b)
		return
	var c2 := K.card(body)
	c2.add_child(K.lbl("CO NASTAWIĆ?", 10, K.C_DIM))
	for e in P.recipes_for(room, idx):
		var r: Dictionary = e.r
		var rid: String = e.id
		var row := K.hbox(12)
		c2.add_child(row)
		row.add_child(K.icon("bulk_" + String(r.product), 44))
		var v := K.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(K.head(String(r.name), 18, K.C_TXT))
		var need: Array = []
		for it in r.input:
			need.append("%s ×%d" % [String(D.ITEMS[it].name).to_lower(), int(r.input[it])])
		var slots := K.hbox(6)
		v.add_child(slots)
		for ingredient in r.input:
			var slot := K.panel(K.sb(K.C_BG, 6, K.C_LINE, 1, 8))
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slots.add_child(slot)
			var contents := K.vbox(3)
			slot.add_child(contents)
			contents.add_child(K.icon(String(D.ITEMS[ingredient].icon), 22))
			contents.add_child(K.wrap(String(D.ITEMS[ingredient].name), 11, K.C_TXT))
			contents.add_child(K.lbl("%d / %d" % [G.item_at(room, ingredient), int(r.input[ingredient])], 12, K.C_DIM if G.item_at(room, ingredient) >= int(r.input[ingredient]) else K.C_WARN))
		var pots := int(P.furn(room, idx).get("pots", 1))
		var yld: float = float(r["yield"]) * (pots if r.has("water") else 1)
		v.add_child(K.rich("Wsad: [b]%s[/b]  •  czas: ok. [b]%d godz.[/b]  •  plon: ok. [b]%d g[/b]  •  czystość od [b]%d%%[/b]" % [", ".join(need), int(r.hours), int(yld), int(r.pur)], 12))
		if String(e.miss) != "":
			v.add_child(K.lbl(String(e.miss).capitalize(), 12, K.C_WARN))
		var b2 := K.btn("  Nastaw  ", func(): pass, "go")
		b2.disabled = String(e.miss) != ""
		b2.pressed.connect(func():
			if view.busy():
				return
			Sfx.play("place")
			P.start(room, idx, rid)
			again.call())
		row.add_child(b2)
	if kind == "grow":
		c2.add_child(K.wrap("Nasiona i nawóz kupisz u Stasia. Suszarkę, zbiornik z pompą i filtr węglowy — w hurtowni budowlanej przy Hutniczej; ustawiasz je klawiszem [%s]." % G.kn("build"), 12, K.C_DIM))
	else:
		c2.add_child(K.wrap("Zestawy chemikaliów kupisz u Stasia. Synteza śmierdzi — bez filtra węglowego ryzyko nalotu szybko rośnie.", 12, K.C_DIM))


static func _dry_ui(_U, body: VBoxContainer, view, room: String, idx: int, j: Dictionary, again: Callable) -> void:
	var P = G.Prod
	var c := K.card(body)
	c.add_child(K.rich("Na siatkach: [b]%s %s[/b]  %s" % [G.grams(j.g), String(D.PRODUCT_GEN[j.p]), K.tier_bb(j.pur)], 15))
	if float(j.prog) >= 1.0:
		c.add_child(K.rich(K.col("Wysuszone — gotowe do zebrania.", K.C_ACC), 14))
		var b := K.btn("  Zbierz do skrytki  ", func(): pass, "go")
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func():
			if view.busy():
				return
			Sfx.play("pack")
			P.collect(room, idx)
			again.call())
		c.add_child(b)
	else:
		c.add_child(K.rich("Schnie… jeszcze [b]%s[/b]." % _time(P.minutes_left(j)), 14))


static func _job_ui(_U, body: VBoxContainer, view, room: String, idx: int, j: Dictionary, again: Callable) -> void:
	var P = G.Prod
	var r: Dictionary = P.recipe(j)
	var is_grow: bool = r.has("water")
	var done: bool = float(j.prog) >= 1.0
	var cols := K.hbox(12)
	body.add_child(cols)
	# ---------------------------------------------------------------- stan
	var left := K.panel(K.sb(K.C_CARD, 12, K.C_LINE, 1, 12))
	left.custom_minimum_size = Vector2(380, 0)
	cols.add_child(left)
	var lv := K.vbox(7)
	left.add_child(lv)
	var stage: String = P.stage_name(j)
	var scol := K.C_ACC if done else (K.C_BAD if int(j.hold) >= 0 else K.C_TXT)
	_stat(lv, "flask_conical" if not is_grow else "sprout", "Etap", stage, scol)
	if not done and int(j.hold) < 0:
		var more := ""
		for st in r.stages:
			if st.has("hold") and float(j.prog) < float(st.to) - 0.00001:
				more = "  (do: %s)" % String(st.hold).to_lower()
				break
		_stat(lv, "timer", "Zostało" + more, _time(P.minutes_left(j)))
	if is_grow:
		_bar_row(lv, "droplets", "Woda", float(j.water), K.C_BLUE if float(j.water) > 25.0 else K.C_BAD)
	_bar_row(lv, "heart", "Kondycja", float(j.health), K.C_ACC if float(j.health) > 60.0 else (K.C_WARN if float(j.health) > 30.0 else K.C_BAD))
	var fc: Dictionary = P.forecast(j)
	_stat(lv, "scale", "Prognoza", "ok. %d g  •  %d%%" % [int(fc.g), int(fc.pur)], K.C_ACC)
	var tags: Array = []
	if is_grow:
		tags.append(K.col("nawóz ✓", K.C_ACC) if j.fert else K.col("bez nawozu", K.C_DIM))
		tags.append(K.col("przycięte ✓", K.C_ACC) if j.trim else K.col("nieprzycięte", K.C_DIM))
		if P.has_station(room, "tank"):
			tags.append(K.col("pompa podlewa sama", K.C_BLUE))
	if j.burnt and done:
		tags.append(K.col("partia przypalona", K.C_BAD))
	if not tags.is_empty():
		lv.add_child(K.rich("   ".join(tags), 12))
	# ---------------------------------------------------------------- decyzje
	var right := K.panel(K.sb(K.C_CARD, 12, K.C_LINE, 1, 14))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rv := K.vbox(8)
	right.add_child(rv)
	var act := func(anim: String, sound: String, what: Callable) -> void:
		if view.busy():
			return
		Sfx.play(sound)
		view.play(anim, func():
			what.call()
			again.call())
	if done:
		rv.add_child(K.rich(K.col("Gotowe.", K.C_ACC) + (" Świeży zbiór trzeba jeszcze wysuszyć w suszarce." if r.get("wet", false) else " Towar trafi do skrytki w tej kryjówce."), 14))
		if float(j.ripe_t) > 12.0 * 60.0:
			rv.add_child(K.lbl("Stoi już długo — z każdą godziną traci na jakości.", 12, K.C_WARN))
		if r.get("wet", false) and not P.has_station(room, "dry"):
			rv.add_child(K.lbl("Nie masz suszarki — kup ją w hurtowni budowlanej i ustaw, inaczej zbiór zgnije.", 12, K.C_WARN))
		var hb := K.btn("  Zbierz  ", func(): act.call("harvest", "pack", func(): P.collect(room, idx)), "go")
		hb.custom_minimum_size = Vector2(0, 42)
		hb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rv.add_child(hb)
		return
	if int(j.hold) >= 0:
		rv.add_child(K.rich("Etap zakończony. Reakcja czeka na Ciebie: [b]%s[/b]." % String(r.stages[int(j.hold)].hold).to_lower(), 14))
		rv.add_child(K.lbl("Im dłużej czeka (ponad 2 godziny), tym gorszy wyjdzie towar.", 12, K.C_WARN if float(j.hold_t) > 60.0 else K.C_DIM))
		var pb := K.btn("  %s  " % String(r.stages[int(j.hold)].hold), func(): act.call("pour", "place", func(): P.proceed(room, idx)), "go")
		pb.custom_minimum_size = Vector2(0, 42)
		pb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rv.add_child(pb)
	# tryb: lampy albo temperatura
	var mh := K.hbox(6)
	rv.add_child(mh)
	mh.add_child(K.lbl("LAMPY:" if is_grow else "TEMPERATURA:", 11, K.C_DIM))
	for i in range(r.modes.size()):
		var mi := i
		var mb := K.btn(String(r.modes[i].name), func(): P.set_mode(room, idx, mi); again.call(), "go" if i == int(j.mode) else "", true)
		mb.tooltip_text = String(r.modes[i].desc)
		mh.add_child(mb)
	rv.add_child(K.wrap(String(P.mode_def(j).desc), 12, K.C_DIM))
	if is_grow:
		var ah := K.flow(8)
		rv.add_child(ah)
		var wb := K.btn("Podlej", func(): act.call("water", "drop", func(): P.water(room, idx)), "go" if float(j.water) < 40.0 else "")
		wb.icon = K.tex("droplets")
		wb.add_theme_constant_override("icon_max_width", 15)
		wb.disabled = float(j.water) >= 95.0
		ah.add_child(wb)
		var fb := K.btn("Nawóz (masz %d)" % G.item_at(room, "nawoz"), func(): act.call("fert", "pack", func(): P.fertilize(room, idx)))
		fb.disabled = not P.can_fert(room, idx)
		fb.tooltip_text = "Plon +25%, ale rośliny piją o 1/4 więcej. Raz na cykl, zanim zaczną kwitnąć."
		ah.add_child(fb)
		var tb := K.btn("Przytnij", func(): act.call("trim", "pack", func(): P.trim(room, idx)))
		tb.disabled = not P.can_trim(room, idx)
		tb.tooltip_text = "Tylko w fazie wzrostu, raz na cykl: czystość +8%. Zajmuje 10 minut."
		ah.add_child(tb)
		if float(j.water) <= 0.0:
			rv.add_child(K.lbl("Sucho! Rośliny nie rosną i marnieją — podlej je.", 12, K.C_BAD))
		elif float(j.water) < 25.0:
			rv.add_child(K.lbl("Ziemia przesycha. Poniżej zera rośliny przestaną rosnąć.", 12, K.C_WARN))
	var db := K.btn("Wyrzuć wszystko", func(): P.discard(room, idx); again.call(), "bad", true)
	db.size_flags_horizontal = Control.SIZE_SHRINK_END
	db.tooltip_text = "Opróżnia stanowisko. Wsad przepada — przydaje się, gdy zbliża się nalot."
	rv.add_child(db)


# ================================================================ stan kryjówki
static func build_hideout(U, room: String) -> void:
	var P = G.Prod
	U._open_modal("Stan kryjówki", String(D.ROOMS[room].name) + " — produkcja, zapach, prąd i ryzyko nalotu", "center", 900.0)
	var body: VBoxContainer = U.modal_body
	var st: Dictionary = P.stats(room)
	var h := P.hide(room)
	body.add_child(hide_strip(U, room, false))
	var risk := float(st.risk)
	var rc := K.C_ACC if risk < 30.0 else (K.C_WARN if risk < 55.0 else K.C_BAD)
	var c := K.card(body)
	_bar_row(c, "siren", "Ryzyko", risk, rc)
	var ch: float = P.raid_chance(risk) * 100.0
	c.add_child(K.rich("Szansa nalotu w ciągu doby: [b]%s[/b]. Na ryzyko składają się zapach, pobór prądu i to, jak mocno interesuje się Tobą policja." % ("praktycznie zero" if ch < 0.5 else "ok. %d%%" % int(ceil(ch))), 13))
	if h.has("raid_at") and h.get("raid_warned", false):
		c.add_child(K.rich(K.col("Staś ostrzegał: ktoś tu węszy. Nalot może być lada chwila — wynieś towar albo opróżnij stanowiska.", K.C_BAD), 13))
	var tips: Array = []
	if not st.filter and float(st.smell) > 12.0:
		tips.append("filtr węglowy zbije zapach o 60%")
	if float(st.power) > 30.0:
		tips.append("lampy w trybie 18/6 biorą połowę prądu")
	if float(G.S.invest) > 40.0:
		tips.append("telefon na kartę zbija śledztwo")
	if not tips.is_empty():
		c.add_child(K.wrap("Co pomoże: " + "; ".join(tips) + ".", 12, K.C_DIM))
	var c2 := K.card(body)
	c2.add_child(K.lbl("STANOWISKA", 10, K.C_DIM))
	var items: Array = G.S.hide[room].items
	var any := false
	for i in range(items.size()):
		var f: Dictionary = G.furn_def(String(items[i].f))
		var fn := String(f.get("func", ""))
		if not fn in ["grow", "dry", "lab", "tank", "filter"]:
			continue
		any = true
		var ii := i
		var row := K.hbox(10)
		c2.add_child(row)
		row.add_child(K.icon({"grow": "sprout", "dry": "wind", "lab": "flask_conical", "tank": "droplets", "filter": "wind"}.get(fn, "box"), 16, K.C_DIM))
		var lab := K.lbl(G.station_label(room, i), 13, K.C_TXT)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var j = P.job(room, i)
		if j != null and String(j.r) != "_dry":
			var fc: Dictionary = P.forecast(j)
			row.add_child(K.lbl("ok. %d g • %d%%" % [int(fc.g), int(fc.pur)], 12, K.C_DIM))
		if fn in ["grow", "dry", "lab"]:
			row.add_child(K.btn("Otwórz", func(): U.open_station(room, ii), "", true))
	if not any:
		c2.add_child(K.wrap("Brak stanowisk. W kryjówce naciśnij [%s], żeby postawić doniczki, lampę LED, suszarkę albo stół laboratoryjny." % G.kn("build"), 13, K.C_DIM))
	var wet: float = P.wet_total(room)
	if wet > 0.0:
		c2.add_child(K.rich("Świeży zbiór czekający na suszarkę: [b]%s[/b]" % G.grams(wet), 13))
