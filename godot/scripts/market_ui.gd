extends RefCounted
## Ekran „Giełda” w telefonie: zeszyt, paczki w drodze, okazja dnia, dostawcy z zaufaniem,
## formularz zamówienia (towar, ilość, dostawa, płatność) i skup nadwyżek.

const K = preload("res://scripts/uikit.gd")


static func _time_left(m: float) -> String:
	if m < 90.0:
		return "%d min" % int(maxf(0.0, m))
	return ("%.1f godz." % (m / 60.0)).replace(".", ",")


static func build(PH) -> void:
	var S: Dictionary = G.S
	var M = G.Market
	var body: VBoxContainer = PH.body
	var st: Dictionary = PH.hurt
	PH._header("Giełda", "Szyfrowany kanał • %d dostawców" % _open_vendors())
	if not G.flag("hurt_on"):
		var c0 := K.card(body)
		c0.add_child(K.icon("lock", 28, K.C_DIM))
		c0.add_child(K.wrap("Wiktor jeszcze Ci nie ufa. Odbierz pierwszą paczkę, sprzedaj towar i spłać zeszyt — wtedy wpuści Cię na Giełdę.", 13, K.C_DIM))
	# ---------------------------------------------------------------- zeszyt
	var c := K.card(body)
	c.add_child(K.lbl("ZESZYT U WIKTORA", 10, K.C_DIM))
	var due := ""
	if float(S.credit) > 0.0:
		due = ("  •  " + K.col("PO TERMINIE", K.C_BAD)) if G.credit_overdue() else ("  •  do dnia %d" % (int(float(S.credit_due) / 1440.0) + 1))
	c.add_child(K.rich("[b]%s[/b] / %s%s" % [K.col(G.money(S.credit), K.C_WARN if float(S.credit) > 0.0 else K.C_TXT), G.money(G.credit_limit()), due], 15))
	c.add_child(K.bar(float(S.credit), G.credit_limit(), K.C_WARN))
	if float(S.credit) > 0.0:
		var f := K.flow(5)
		c.add_child(f)
		var b1 := K.btn("Spłać 100 zł", func(): G.pay_credit(100.0); PH.render(), "", true)
		b1.disabled = S.cash < 1.0
		f.add_child(b1)
		var b2 := K.btn("Spłać zeszyt (%s)" % G.money(minf(S.cash, float(S.credit))), func(): G.pay_credit(1e12); PH.render(), "go", true)
		b2.disabled = S.cash < 1.0
		f.add_child(b2)
	# ---------------------------------------------------------------- paczki
	if not S.drops.is_empty():
		var cd := K.card(body)
		cd.add_child(K.lbl("PACZKI", 10, K.C_DIM))
		for d in S.drops:
			var v: Dictionary = M.vendor(String(d.get("vendor", "wiktor")))
			var method := String(d.get("method", "drop"))
			var row := K.hbox(8)
			cd.add_child(row)
			row.add_child(K.icon("brick_" + String(d.p) if int(d.g) >= 50 else "bulk_" + String(d.p), 34))
			var txt := "[b]%d g %s[/b] (%s) — %s\n" % [int(d.g), D.PRODUCT_GEN[d.p], M.pur_text(d), String(v.get("name", "?"))]
			txt += K.col(M.spot_name(d), K.C_TXT) + "\n"
			if d.state == "ready":
				var left: float = maxf(0.0, float(d.expire) - S.t)
				txt += K.col("Czeka" if method != "courier" else "Kurier czeka", K.C_ACC) + " • jeszcze %s" % _time_left(left)
				if method == "locker":
					txt += "  •  kod [b]%s[/b]" % String(d.get("code", ""))
			else:
				txt += K.col("W drodze, ok. %s" % _time_left(float(d.ready) - S.t), K.C_DIM)
			txt += "  •  %s" % ("zapłacone" if d.get("prepaid", false) else ("na zeszyt" if d.credit else "do zapłaty: " + G.money(d.cost)))
			var rl := K.rich(txt, 12)
			rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(rl)
		cd.add_child(K.btn("Prowadź do odbioru", func(): G.main.set_track("drop"); PH.ui.close_all(), "", true))
	if not G.flag("hurt_on"):
		return
	# ---------------------------------------------------------------- okazja dnia
	var sp = M.special()
	if sp != null:
		var sv: Dictionary = M.vendor(String(sp.vendor))
		var cs := K.panel(K.sb(Color(0.16, 0.12, 0.04), 12, K.C_GOLD, 1, 12))
		body.add_child(cs)
		var sb := K.vbox(4)
		cs.add_child(sb)
		sb.add_child(K.icon_label("flame", "OKAZJA DNIA — do %s" % G.clock(sp.until), 11, K.C_GOLD, 14))
		var sr := K.hbox(8)
		sb.add_child(sr)
		sr.add_child(K.icon("brick_" + String(sp.p) if int(sp.g) >= 50 else "bulk_" + String(sp.p), 40))
		var srt := K.rich("[b]%d g %s[/b] od: %s\n[b]%s[/b]  %s" % [int(sp.g), D.PRODUCT_GEN[sp.p], String(sv.name), K.col(G.money(sp.price), K.C_GOLD), K.col("−%d%%" % int(round(float(sp.off) * 100.0)), K.C_ACC)], 13)
		srt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sr.add_child(srt)
		var bb := K.btn("Biorę (płatne z góry)", func(): M.buy_special(); PH.render(), "go", true)
		bb.disabled = S.cash < float(sp.price) or S.drops.size() >= 3
		sb.add_child(bb)
	# ---------------------------------------------------------------- dostawcy
	var cv := K.card(body)
	cv.add_child(K.lbl("DOSTAWCY", 10, K.C_DIM))
	var cur: Dictionary = M.vendor(String(st.get("v", "wiktor")))
	if cur.is_empty() or not M.unlocked(cur):
		cur = M.vendor("wiktor")
		st["v"] = "wiktor"
	for v in D.VENDORS:
		var vid: String = v.id
		var open: bool = M.unlocked(v)
		var on: bool = vid == String(cur.id)
		var vc := Color.html(String(v.color))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 52)
		b.disabled = not open
		b.add_theme_stylebox_override("normal", K.sb(Color(0.13, 0.17, 0.24) if on else Color(0.085, 0.102, 0.15), 9, vc if on else Color(1, 1, 1, 0.07), 1, 8))
		b.add_theme_stylebox_override("hover", K.sb(Color(0.13, 0.16, 0.23), 9, vc, 1, 8))
		b.add_theme_stylebox_override("pressed", K.sb(Color(0.07, 0.085, 0.12), 9, vc, 1, 8))
		b.add_theme_stylebox_override("disabled", K.sb(Color(0.06, 0.07, 0.1), 9, Color(1, 1, 1, 0.04), 1, 8))
		b.pressed.connect(func():
			Sfx.play("click")
			st["v"] = vid
			st["credit"] = false
			PH.render())
		var h := K.hbox(8)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var dot := K.panel(K.sb(vc if open else Color(0.25, 0.26, 0.3), 14, Color(0, 0, 0, 0), 0, 0))
		dot.custom_minimum_size = Vector2(28, 28)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(dot)
		var vb := K.vbox(0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(K.lbl(String(v.name), 14, K.C_TXT if open else K.C_DIM))
		var pm := int(round((float(v.price) * (1.0 - M.trust_discount(vid)) - 1.0) * 100.0))
		var sub := "%s  •  %s  •  %d–%d%%" % [String(v.tag), ("cena %+d%%" % pm) if pm != 0 else "cena bazowa", int(v.pur[0]), int(v.pur[1])] if open else "od poziomu %d" % int(v.lvl)
		vb.add_child(K.lbl(sub, 11, K.C_DIM))
		h.add_child(vb)
		if open:
			var tb := K.bar(M.trust(vid), 100.0, vc, 5.0)
			tb.custom_minimum_size = Vector2(46, 5)
			tb.size_flags_horizontal = Control.SIZE_SHRINK_END
			tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tb.tooltip_text = "Zaufanie"
			h.add_child(tb)
		cv.add_child(b)
	cv.add_child(K.wrap(String(cur.desc), 11, K.C_DIM))
	if M.trust(String(cur.id)) > 1.0:
		cv.add_child(K.lbl("Zaufanie %d/100 — rabat %s%%" % [int(M.trust(String(cur.id))), ("%.1f" % (M.trust_discount(String(cur.id)) * 100.0)).replace(".", ",")], 11, K.C_ACC))
	# ---------------------------------------------------------------- zamówienie
	var co := K.card(body)
	co.add_child(K.lbl("ZAMÓWIENIE U: %s" % String(cur.name).to_upper(), 10, K.C_DIM))
	var pf := K.flow(5)
	co.add_child(pf)
	if int(S.lvl) < int(D.PRODUCTS[String(st.p)].lvl):
		st.p = "dym"
	for p in D.PRODUCTS:
		var pid: String = p
		var locked: bool = int(S.lvl) < int(D.PRODUCTS[p].lvl)
		var b := K.btn(D.PRODUCTS[p].name + ((" (poz. %d)" % int(D.PRODUCTS[p].lvl)) if locked else ""), func(): st.p = pid; PH.render(), "go" if st.p == p else "", true)
		b.disabled = locked
		pf.add_child(b)
	var qf := K.flow(5)
	co.add_child(qf)
	var sizes := []
	for g in D.WHOLESALE_SIZES:
		if g >= int(cur.min):
			sizes.append(g)
	if not sizes.has(int(st.g)) or int(st.g) > M.max_g(cur):
		st.g = sizes[0]
	for g in sizes:
		var gg: int = g
		var b := K.btn("%d g" % g, func(): st.g = gg; PH.render(), "go" if int(st.g) == g else "", true)
		b.disabled = g > M.max_g(cur)
		qf.add_child(b)
	# dostawa
	var method := String(st.get("m", "drop"))
	var df := K.flow(5)
	co.add_child(df)
	for mid in D.DELIVERY:
		var mm: String = mid
		var md: Dictionary = D.DELIVERY[mid]
		var b := K.btn(String(md.name) + ((" +%d%%" % int(float(md.fee) * 100.0)) if float(md.fee) > 0.0 else ""), func(): st["m"] = mm; PH.render(), "go" if method == mid else "", true)
		b.icon = K.tex(String(md.icon))
		b.add_theme_constant_override("icon_max_width", 13)
		df.add_child(b)
	co.add_child(K.wrap(String(D.DELIVERY[method].desc), 11, K.C_DIM))
	# płatność
	var pmf := K.flow(5)
	co.add_child(pmf)
	if cur.get("prepay", false):
		st["credit"] = false
		pmf.add_child(K.lbl("Płatne z góry.", 12, K.C_WARN))
	else:
		pmf.add_child(K.btn("Płacę przy odbiorze", func(): st.credit = false; PH.render(), "go" if not st.credit else "", true))
		var bc := K.btn("Na zeszyt", func(): st.credit = true; PH.render(), "go" if st.credit else "", true)
		bc.disabled = not cur.get("credit", false)
		bc.tooltip_text = "Na zeszyt daje tylko Wiktor."
		pmf.add_child(bc)
		if not cur.get("credit", false):
			st["credit"] = false
	var cost: float = M.price(String(cur.id), String(st.p), int(st.g), method)
	var eta_lo: float = float(cur.eta[0]) * float(D.DELIVERY[method].eta)
	var eta_hi: float = float(cur.eta[1]) * float(D.DELIVERY[method].eta)
	var avg_pur := (int(cur.pur[0]) + int(cur.pur[1])) / 2
	co.add_child(K.rich("Razem: [b]%s[/b]  (%s/g)\nDostawa: %s–%s  •  ulica płaci ok. %s/g" % [K.col(G.money(cost), K.C_WARN), G.money(cost / float(st.g)), _time_left(eta_lo), _time_left(eta_hi),
		G.money(G.market_price(String(st.p), avg_pur))], 13))
	if float(cur.get("risk", 0.0)) > 0.0 and method == "drop":
		co.add_child(K.wrap("Uwaga: ok. %d%% skrytek od tego dostawcy jest spalonych. Skrytkomat i kurier są czyste." % int(float(cur.risk) * 100.0), 11, K.C_BAD))
	var why: String = M.block(String(cur.id), String(st.p), int(st.g), method, bool(st.credit))
	var ob := K.btn("Zamów" if why == "" else why, func(): M.order(String(cur.id), String(st.p), int(st.g), method, bool(st.credit)); PH.render(), "go")
	ob.disabled = why != ""
	co.add_child(ob)
	# ---------------------------------------------------------------- skup
	var by: Dictionary = M.bulk_buyer()
	var cb := K.card(body)
	cb.add_child(K.lbl("SKUP NADWYŻEK — %s" % String(by.name).to_upper(), 10, K.C_DIM))
	cb.add_child(K.wrap("Towar luzem z własnej produkcji: %d%% ceny ulicznej, od %d g, dziś jeszcze %d g. Rozrobionego nie biorą." % [int(round(float(by.rate) * 100.0)), D.BULK_SELL_MIN, M.bulk_left_today()], 11, K.C_DIM))
	var loc: String = G.player.loc if G.player != null else "out"
	var stores := [[S.inv, "plecak"]]
	if S.stash.has(loc):
		stores.append([S.stash[loc], "skrytka"])
	var any := false
	for e in stores:
		var store: Dictionary = e[0]
		for s in G.stacks(store, "bulk"):
			if float(s.n) < float(D.BULK_SELL_MIN) or G.is_mix(s.pur):
				continue
			any = true
			var amt: float = floorf(minf(float(s.n), float(M.bulk_left_today())))
			var sp2: String = s.p
			var spur: int = int(s.pur)
			var row2 := K.hbox(8)
			cb.add_child(row2)
			row2.add_child(K.icon("brick_" + sp2 if float(s.n) >= 100.0 else "bulk_" + sp2, 30))
			var l2 := K.rich("%s %s — [b]%s[/b] (%s)" % [D.PRODUCTS[sp2].name, K.tier_bb(spur), G.grams(s.n), String(e[1])], 12)
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(l2)
			var sb2 := K.btn("Sprzedaj %s za %s" % [G.grams(amt), G.money(M.bulk_price(sp2, spur, amt))], func(): M.bulk_sell(store, sp2, spur, amt); PH.render(), "go", true)
			sb2.disabled = M.bulk_block(store, sp2, spur, amt) != ""
			cb.add_child(sb2)
	if not any:
		cb.add_child(K.lbl("Nic do sprzedania tutaj (min. %d g luzem w plecaku albo w skrytce, przy której stoisz)." % D.BULK_SELL_MIN, 11, K.C_DIM))


static func _open_vendors() -> int:
	var n := 0
	for v in D.VENDORS:
		if G.Market.unlocked(v):
			n += 1
	return n
