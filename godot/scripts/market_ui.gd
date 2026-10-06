extends RefCounted
## „Giełda” w telefonie jako szyfrowany komunikator: lista rozmów z dostawcami (każdy pisze po swojemu),
## a w rozmowie cennik w dymku, okazja dnia, historia zamówień i odpowiedź składana z gotowych kawałków
## („Biorę 50 g… Skrytkomat… płacę przy odbiorze”). Zeszyt i paczki w drodze są przypięte na górze listy.

const K = preload("res://scripts/uikit.gd")

## jak kto pisze: powitanie zależy od zaufania (chłodno → normalnie → po swojemu), potwierdzenia losowe
const SAY := {
	"wiktor": {"hi": ["Kuba. Mów, ile bierzesz, nie mam całego dnia.", "Jesteś. Zeszyt pamięta wszystko, ja też. Ile tym razem?", "Dla ciebie zawsze coś się znajdzie. Ile?"],
		"ok": ["Będzie. Nie spóźnij się po odbiór.", "Załatwione. Miejsce dostaniesz SMS-em.", "Dobra. I pamiętaj o zeszycie."], "list": "Dziś mam tak:"},
	"zbyszek": {"hi": ["siema szefie, co potrzeba? tanio i od ręki", "elo, mam świeży rzut. nie pytaj skąd", "ooo mój najlepszy klient!! dla ciebie cena specjalna (ta sama co zawsze)"],
		"ok": ["leci. jak coś nie halo z towarem to nie do mnie pretensje", "ok pakuję, będzie raz dwa", "git. tylko odbierz szybko bo różnie bywa"], "list": "cennik na dziś:"},
	"chemik": {"hi": ["Dzień dobry. Proszę podać ilość. Płatność z góry, bez wyjątków.", "Witam ponownie. Partia z tego tygodnia wyszła powyżej 90%.", "Dla stałych odbiorców odkładam najlepsze frakcje. Słucham."],
		"ok": ["Przyjąłem. Synteza i pakowanie potrwają kilka godzin.", "Zamówienie potwierdzone. Proszę o cierpliwość.", "Zapisane. Towar zostanie sprawdzony przed wysyłką."], "list": "Aktualna oferta:"},
	"port": {"hi": ["Hurt. Od pięćdziesięciu gram. Mniejszych nie pakujemy.", "Kontener stoi. Ile cegieł?", "Dla ciebie wyciągniemy z dna, gdzie nie zamokło."],
		"ok": ["Idzie. Statek to nie taksówka, poczekasz.", "Zapisane. Odbiór, jak dostaniesz sygnał.", "Dobra. Kasa przyszła, towar wychodzi."], "list": "Stawki za cegłę:"},
}


static func _time_left(m: float) -> String:
	if m < 90.0:
		return "%d min" % int(maxf(0.0, m))
	return ("%.1f godz." % (m / 60.0)).replace(".", ",")


static func _say(vid: String, key: String) -> Variant:
	return SAY.get(vid, SAY.wiktor)[key]


static func _hello(vid: String) -> String:
	var t: float = G.Market.trust(vid)
	return String(_say(vid, "hi")[0 if t < 25.0 else (1 if t < 60.0 else 2)])


static func _log(vid: String) -> Array:
	if not G.S.has("mlog"):
		G.S["mlog"] = {}
	if not G.S.mlog.has(vid):
		G.S.mlog[vid] = []
	return G.S.mlog[vid]


static func _log_add(vid: String, me: bool, text: String) -> void:
	var lg := _log(vid)
	lg.append({"me": me, "t": text, "at": G.S.t})
	while lg.size() > 10:
		lg.pop_front()


## dymek rozmowy: cudze po lewej (z kolorem rozmówcy), własne po prawej
static func _bubble(body: Control, bb: String, me: bool, color := K.C_BLUE, extra: Control = null) -> VBoxContainer:
	var row := K.hbox(0)
	body.add_child(row)
	var bg := Color(0.1, 0.2, 0.16) if me else Color(0.11, 0.13, 0.19)
	var p := K.panel(K.sb(bg, 13, Color(K.C_ACC.r, K.C_ACC.g, K.C_ACC.b, 0.35) if me else Color(color.r, color.g, color.b, 0.4), 1, 9))
	p.custom_minimum_size = Vector2(258, 0)
	var v := K.vbox(5)
	p.add_child(v)
	var r := K.rich(bb, 13)
	v.add_child(r)
	if extra != null:
		v.add_child(extra)
	if me:
		row.add_child(K.spacer())
		row.add_child(p)
	else:
		row.add_child(p)
		row.add_child(K.spacer())
	return v


static func _note(body: Control, text: String, color := K.C_DIM) -> void:
	var l := K.wrap(text, 11, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)


static func _avatar(name: String, color: Color, open := true, size := 34.0) -> Control:
	var dot := K.panel(K.sb(color if open else Color(0.22, 0.23, 0.27), int(size / 2.0), Color(0, 0, 0, 0), 0, 0))
	dot.custom_minimum_size = Vector2(size, size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := K.head(name.substr(0, 1).to_upper(), int(size * 0.5), Color(0.05, 0.06, 0.08) if open else K.C_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_child(l)
	return dot


static func build(PH) -> void:
	var st: Dictionary = PH.hurt
	if not st.has("chat"):
		st["chat"] = ""
	var chat := String(st.chat)
	if chat != "" and G.flag("hurt_on"):
		if chat == "skup":
			_buyer(PH)
			return
		var v: Dictionary = G.Market.vendor(chat)
		if not v.is_empty() and G.Market.unlocked(v):
			_talk(PH, v)
			return
	st["chat"] = ""
	_list(PH)


# ================================================================ lista rozmów
static func _list(PH) -> void:
	var S: Dictionary = G.S
	var M = G.Market
	var body: VBoxContainer = PH.body
	var st: Dictionary = PH.hurt
	PH._header("Giełda", "Szyfrowany komunikator • %d kontaktów" % _open_vendors())
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
	# ---------------------------------------------------------------- rozmowy
	body.add_child(K.lbl("ROZMOWY", 10, K.C_DIM))
	var sp = M.special()
	for v in D.VENDORS:
		var vid: String = v.id
		var open: bool = M.unlocked(v)
		var vc := Color.html(String(v.color))
		var preview := "Nie odpisuje nieznajomym (od poziomu %d)." % int(v.lvl)
		var hot := false
		if open:
			var lg := _log(vid)
			preview = String(lg[-1].t) if not lg.is_empty() else _hello(vid)
			if not lg.is_empty() and bool(lg[-1].me):
				preview = "Ty: " + preview
			for d in S.drops:
				if String(d.get("vendor", "")) == vid:
					preview = "Paczka czeka na odbiór." if d.state == "ready" else "Paczka w drodze, ok. %s." % _time_left(float(d.ready) - S.t)
			if sp != null and String(sp.vendor) == vid:
				preview = "Okazja: %d g %s za %s (−%d%%), do %s" % [int(sp.g), D.PRODUCT_GEN[sp.p], G.money(sp.price), int(round(float(sp.off) * 100.0)), G.clock(sp.until)]
				hot = true
		_row(body, String(v.name), String(v.tag), preview, vc, open, hot, M.trust(vid) if open else -1.0, func():
			st["chat"] = vid
			st["v"] = vid
			st["credit"] = false
			PH.render())
	var by: Dictionary = M.bulk_buyer()
	_row(body, "Skup — %s" % String(by.name), "Bierze nadwyżki", "Luzem z własnej roboty: %d%% ceny ulicy, dziś jeszcze %d g." % [int(round(float(by.rate) * 100.0)), M.bulk_left_today()],
		Color(0.55, 0.6, 0.68), true, false, -1.0, func():
			st["chat"] = "skup"
			PH.render())


## wiersz rozmowy: awatar z inicjałem, nazwa i dopisek, ostatnia wiadomość, pasek zaufania albo kropka okazji
static func _row(body: Control, name: String, tag: String, preview: String, color: Color, open: bool, hot: bool, trust: float, cb: Callable) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 58)
	b.disabled = not open
	b.add_theme_stylebox_override("normal", K.sb(Color(0.16, 0.13, 0.06) if hot else Color(0.085, 0.102, 0.15), 10, K.C_GOLD if hot else Color(1, 1, 1, 0.07), 1, 8))
	b.add_theme_stylebox_override("hover", K.sb(Color(0.13, 0.16, 0.23), 10, color, 1, 8))
	b.add_theme_stylebox_override("pressed", K.sb(Color(0.07, 0.085, 0.12), 10, color, 1, 8))
	b.add_theme_stylebox_override("disabled", K.sb(Color(0.06, 0.07, 0.1), 10, Color(1, 1, 1, 0.04), 1, 8))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	var h := K.hbox(9)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(_avatar(name, color, open))
	var vb := K.vbox(0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := K.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(K.lbl(name, 14, K.C_TXT if open else K.C_DIM))
	top.add_child(K.lbl(tag, 10, color if open else K.C_DIM))
	vb.add_child(top)
	var pl := K.lbl(preview, 11, K.C_GOLD if hot else K.C_DIM)
	pl.clip_text = true
	pl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(pl)
	h.add_child(vb)
	if hot:
		h.add_child(K.icon("flame", 16, K.C_GOLD))
	elif trust >= 0.0:
		var tb := K.bar(trust, 100.0, color, 5.0)
		tb.custom_minimum_size = Vector2(40, 5)
		tb.size_flags_horizontal = Control.SIZE_SHRINK_END
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tb.tooltip_text = "Zaufanie"
		h.add_child(tb)
	body.add_child(b)


# ================================================================ rozmowa z dostawcą
static func _talk(PH, cur: Dictionary) -> void:
	var S: Dictionary = G.S
	var M = G.Market
	var body: VBoxContainer = PH.body
	var st: Dictionary = PH.hurt
	var vid := String(cur.id)
	var vc := Color.html(String(cur.color))
	var tr: float = M.trust(vid)
	var sub := "%s  •  zaufanie %d/100" % [String(cur.tag), int(tr)]
	if M.trust_discount(vid) > 0.001:
		sub += "  •  rabat %s%%" % ("%.1f" % (M.trust_discount(vid) * 100.0)).replace(".", ",")
	PH._header(String(cur.name), sub)
	st["v"] = vid
	if int(S.lvl) < int(D.PRODUCTS[String(st.p)].lvl):
		st.p = "dym"
	var sizes := []
	for g in D.WHOLESALE_SIZES:
		if g >= int(cur.min):
			sizes.append(g)
	if not sizes.has(int(st.g)) or int(st.g) > M.max_g(cur):
		st.g = sizes[0]
	var method := String(st.get("m", "drop"))
	if cur.get("prepay", false) or not cur.get("credit", false):
		st["credit"] = false
	# --- powitanie i cennik
	_bubble(body, _hello(vid), false, vc)
	var lines := [String(_say(vid, "list"))]
	for p in D.PRODUCTS:
		if int(S.lvl) < int(D.PRODUCTS[p].lvl):
			continue
		var per: float = M.price(vid, p, int(st.g), "drop") / float(st.g)
		lines.append("%s — [b]%s[/b]/g" % [String(D.PRODUCTS[p].name), G.money(per)])
	lines.append(K.col("czystość %s, od %d do %d g" % [("niespodzianka" if cur.get("blind", false) else "%d–%d%%" % [int(cur.pur[0]), int(cur.pur[1])]), int(cur.min), M.max_g(cur)], K.C_DIM))
	_bubble(body, "\n".join(lines), false, vc)
	_note(body, String(cur.desc))
	# --- okazja dnia od tego dostawcy
	var sp = M.special()
	if sp != null and String(sp.vendor) == vid:
		var bb := K.btn("Biorę (%s, płatne z góry)" % G.money(sp.price), func(): M.buy_special(); _log_add(vid, true, "Biorę okazję."); PH.render(), "go", true)
		bb.disabled = S.cash < float(sp.price) or S.drops.size() >= 3
		_bubble(body, "%s do %s: [b]%d g %s[/b] za [b]%s[/b] %s" % [K.col("Okazja", K.C_GOLD), G.clock(sp.until), int(sp.g), D.PRODUCT_GEN[sp.p], K.col(G.money(sp.price), K.C_GOLD),
			K.col("(−%d%%)" % int(round(float(sp.off) * 100.0)), K.C_ACC)], false, K.C_GOLD, bb)
	# --- historia i paczki od niego
	for e in _log(vid):
		_bubble(body, String(e.t), bool(e.me), vc)
	for d in S.drops:
		if String(d.get("vendor", "")) == vid:
			_note(body, ("Paczka czeka: %s" % M.spot_name(d)) if d.state == "ready" else ("Paczka w drodze: %d g %s, ok. %s" % [int(d.g), D.PRODUCT_GEN[d.p], _time_left(float(d.ready) - S.t)]), K.C_ACC)
	# --- odpowiedź składana z kawałków
	var co := K.card(body)
	co.add_child(K.lbl("TWOJA ODPOWIEDŹ", 10, K.C_DIM))
	var pf := K.flow(5)
	co.add_child(pf)
	for p in D.PRODUCTS:
		var pid: String = p
		var locked: bool = int(S.lvl) < int(D.PRODUCTS[p].lvl)
		var b := K.btn(D.PRODUCTS[p].name + ((" (poz. %d)" % int(D.PRODUCTS[p].lvl)) if locked else ""), func(): st.p = pid; PH.render(), "go" if st.p == p else "", true)
		b.disabled = locked
		pf.add_child(b)
	var qf := K.flow(5)
	co.add_child(qf)
	for g in sizes:
		var gg: int = g
		var b := K.btn("%d g" % g, func(): st.g = gg; PH.render(), "go" if int(st.g) == g else "", true)
		b.disabled = g > M.max_g(cur)
		qf.add_child(b)
	var df := K.flow(5)
	co.add_child(df)
	for mid in D.DELIVERY:
		var mm: String = mid
		var md: Dictionary = D.DELIVERY[mid]
		var b := K.btn(String(md.name) + ((" +%d%%" % int(float(md.fee) * 100.0)) if float(md.fee) > 0.0 else ""), func(): st["m"] = mm; PH.render(), "go" if method == mid else "", true)
		b.icon = K.tex(String(md.icon))
		b.add_theme_constant_override("icon_max_width", 13)
		b.tooltip_text = String(md.desc)
		df.add_child(b)
	var pay := "płatne z góry"
	if not cur.get("prepay", false):
		var pmf := K.flow(5)
		co.add_child(pmf)
		pmf.add_child(K.btn("Płacę przy odbiorze", func(): st.credit = false; PH.render(), "go" if not st.credit else "", true))
		var bc := K.btn("Na zeszyt", func(): st.credit = true; PH.render(), "go" if st.credit else "", true)
		bc.disabled = not cur.get("credit", false)
		bc.tooltip_text = "Na zeszyt daje tylko Wiktor."
		pmf.add_child(bc)
		pay = "na zeszyt" if st.credit else "płacę przy odbiorze"
	var cost: float = M.price(vid, String(st.p), int(st.g), method)
	var eta_lo: float = float(cur.eta[0]) * float(D.DELIVERY[method].eta)
	var eta_hi: float = float(cur.eta[1]) * float(D.DELIVERY[method].eta)
	var avg_pur := (int(cur.pur[0]) + int(cur.pur[1])) / 2
	var draft := "Biorę %d g %s. %s, %s." % [int(st.g), D.PRODUCT_GEN[String(st.p)], String(D.DELIVERY[method].name), pay]
	_bubble(co, "„%s”\n%s" % [draft, K.col("Razem [b]%s[/b] (%s/g)  •  dostawa %s–%s\nulica płaci ok. %s/g" % [G.money(cost), G.money(cost / float(st.g)), _time_left(eta_lo), _time_left(eta_hi),
		G.money(G.market_price(String(st.p), avg_pur))], K.C_DIM)], true)
	if float(cur.get("risk", 0.0)) > 0.0 and method == "drop":
		co.add_child(K.wrap("Uwaga: ok. %d%% skrytek od tego dostawcy jest spalonych. Skrytkomat i kurier są czyste." % int(float(cur.risk) * 100.0), 11, K.C_BAD))
	var why: String = M.block(vid, String(st.p), int(st.g), method, bool(st.credit))
	var ob := K.btn("Wyślij zamówienie" if why == "" else why, func():
		var res: Dictionary = M.order(vid, String(st.p), int(st.g), method, bool(st.credit))
		if not res.is_empty():
			_log_add(vid, true, draft)
			_log_add(vid, false, String((_say(vid, "ok") as Array).pick_random()))
		PH.render(), "go")
	ob.icon = K.tex("send")
	ob.add_theme_constant_override("icon_max_width", 14)
	ob.disabled = why != ""
	co.add_child(ob)


# ================================================================ skup nadwyżek
static func _buyer(PH) -> void:
	var S: Dictionary = G.S
	var M = G.Market
	var body: VBoxContainer = PH.body
	var by: Dictionary = M.bulk_buyer()
	var vc := Color(0.55, 0.6, 0.68)
	PH._header("Skup — %s" % String(by.name), "Bierze nadwyżki z własnej produkcji")
	_bubble(body, "Biorę towar luzem z własnej roboty. Płacę [b]%d%%[/b] ceny ulicy, od %d g. Dziś wezmę jeszcze [b]%d g[/b]." % [int(round(float(by.rate) * 100.0)), D.BULK_SELL_MIN, M.bulk_left_today()], false, vc)
	_bubble(body, "Rozrobionego nie ruszam. I nie przynoś mi cudzego — poznam.", false, vc)
	var loc: String = G.player.loc if G.player != null else "out"
	var stores := [[S.inv, "plecak"]]
	if S.stash.has(loc):
		stores.append([S.stash[loc], "skrytka"])
	var any := false
	var cb := K.card(body)
	cb.add_child(K.lbl("TWOJA ODPOWIEDŹ", 10, K.C_DIM))
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
			var sb2 := K.btn("„Mam %s — biorę %s”" % [G.grams(amt), G.money(M.bulk_price(sp2, spur, amt))], func(): M.bulk_sell(store, sp2, spur, amt); PH.render(), "go", true)
			sb2.disabled = M.bulk_block(store, sp2, spur, amt) != ""
			cb.add_child(sb2)
	if not any:
		cb.add_child(K.wrap("Nie masz tu nic na sprzedaż: potrzeba co najmniej %d g towaru luzem w plecaku albo w skrytce, przy której stoisz." % D.BULK_SELL_MIN, 11, K.C_DIM))


static func _open_vendors() -> int:
	var n := 0
	for v in D.VENDORS:
		if G.Market.unlocked(v):
			n += 1
	return n
