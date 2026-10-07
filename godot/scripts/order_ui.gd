extends RefCounted
## Zamawianie u Wiktora: telefon obrócony bokiem, a na ekranie sklep — kafle towarów z rysunkami
## (odblokowują się z poziomem), wybór paczki i koszyk. Zamówienie idzie jednym SMS-em, na zeszyt.
## Druga zakładka („Skup”) sprzedaje Wiktorowi nadwyżki z własnej produkcji.
## PH = phone.gd; stan w PH.shop = {p, g, cart, tab}.

const K = preload("res://scripts/uikit.gd")

const W_SCREEN := 760.0
const H_SCREEN := 372.0
const W_CART := 262.0


## buduje poziomy telefon (raz); zwraca jego ramkę
static func build(PH) -> Control:
	var bezel := K.panel(K.sb(Color(0.02, 0.02, 0.025), 34, Color(0.22, 0.23, 0.26), 2, 12))
	var h := K.hbox(6)
	bezel.add_child(h)
	# głośnik po lewej, jak w telefonie położonym na boku
	var ear := K.panel(K.sb(Color(0.1, 0.1, 0.12), 3, Color(0, 0, 0, 0), 0, 0))
	ear.custom_minimum_size = Vector2(5, 56)
	ear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ear)
	var sp := K.panel(K.sb(Color(0.05, 0.06, 0.085), 18, Color(0, 0, 0, 0), 0, 12))
	sp.custom_minimum_size = Vector2(W_SCREEN, H_SCREEN)
	sp.clip_contents = true
	h.add_child(sp)
	PH.shop_root = K.vbox(8)
	sp.add_child(PH.shop_root)
	# przycisk „dom” po prawej
	var hb := Button.new()
	hb.focus_mode = Control.FOCUS_NONE
	hb.custom_minimum_size = Vector2(34, 34)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.tooltip_text = "Wróć do rozmowy"
	hb.add_theme_stylebox_override("normal", K.sb(Color(0.05, 0.05, 0.06), 17, Color(0.3, 0.31, 0.35), 2, 0))
	hb.add_theme_stylebox_override("hover", K.sb(Color(0.1, 0.1, 0.12), 17, Color(0.5, 0.52, 0.58), 2, 0))
	hb.add_theme_stylebox_override("pressed", K.sb(Color(0.14, 0.14, 0.17), 17, Color(0.6, 0.62, 0.7), 2, 0))
	hb.pressed.connect(func(): PH.shop_close())
	h.add_child(hb)
	return bezel


static func render(PH) -> void:
	var S: Dictionary = G.S
	var M = G.Market
	var root: VBoxContainer = PH.shop_root
	K.clear(root)
	var st: Dictionary = PH.shop
	if not D.PRODUCTS.has(String(st.get("p", ""))) or int(S.lvl) < int(D.PRODUCTS[st.p].lvl):
		st.p = "dym"
	var max_g: int = G.wholesale_max()
	st.g = clampi(int(st.get("g", 5)), 1, max_g)
	# --- nagłówek: powrót, tytuł, zakładki, stan zeszytu
	var head := K.hbox(8)
	root.add_child(head)
	var bb := K.btn("", func(): PH.shop_close(), "flat", true)
	bb.icon = K.tex("chevron_left")
	bb.expand_icon = true
	bb.custom_minimum_size = Vector2(30, 30)
	bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bb)
	head.add_child(PH._avatar("wiktor", 30.0))
	var tv := K.vbox(-2)
	tv.add_child(K.lbl("Wiktor", 15))
	tv.add_child(K.lbl("czysty towar • na zeszyt • odbiór ze skrytki", 10, K.C_DIM))
	head.add_child(tv)
	head.add_child(K.spacer())
	for e in [["buy", "Zamów"], ["sell", "Skup"]]:
		var tab_id: String = e[0]
		var tb := K.btn(String(e[1]), func(): st.tab = tab_id; render(PH), "go" if String(st.get("tab", "buy")) == tab_id else "", true)
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(tb)
	var over: bool = G.credit_overdue()
	var owed: float = float(S.credit) + G.drops_owed()
	var due := ""
	if float(S.credit) > 0.0:
		due = K.col("  PO TERMINIE", K.C_BAD) if over else K.col("  do dnia %d" % (int(float(S.credit_due) / 1440.0) + 1), K.C_DIM)
	var tab_l := K.rich("Zeszyt: [b]%s[/b] / %s%s" % [K.col(G.money(owed), K.C_BAD if over else (K.C_WARN if owed > 0.0 else K.C_ACC)), G.money(G.credit_limit()), due], 12)
	tab_l.custom_minimum_size = Vector2(250, 0)
	tab_l.fit_content = true
	tab_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tab_l)
	if String(st.get("tab", "buy")) == "sell":
		_sell(PH, root)
		return
	var row := K.hbox(10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	# --- lewa strona: kafle towarów, wybór paczki
	var left := K.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var tiles := K.hbox(8)
	left.add_child(tiles)
	for c in M.catalog():
		tiles.add_child(_tile(PH, c, String(st.p) == String(c.p)))
	var pd: Dictionary = D.PRODUCTS[st.p]
	var info := K.wrap(String(pd.desc), 11, K.C_DIM, 470.0)
	left.add_child(info)
	# ile gramów: wpisujesz liczbę (albo −/+); rabat za ilość liczy się progami
	var sz := K.hbox(6)
	left.add_child(sz)
	sz.add_child(K.lbl("Ile gramów:", 12, K.C_DIM))
	var minus := K.btn("−", func(): st.g = maxi(1, int(st.g) - 1); render(PH), "", true)
	minus.custom_minimum_size = Vector2(30, 30)
	sz.add_child(minus)
	var ed := LineEdit.new()
	ed.text = str(int(st.g))
	ed.custom_minimum_size = Vector2(72, 30)
	ed.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ed.max_length = 3
	ed.select_all_on_focus = true
	ed.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	ed.tooltip_text = "Wpisz, ile gramów chcesz zamówić"
	ed.add_theme_font_size_override("font_size", 14)
	ed.add_theme_stylebox_override("normal", K.sb(Color(0.03, 0.04, 0.06), 8, Color(1, 1, 1, 0.18), 1, 8))
	ed.add_theme_stylebox_override("focus", K.sb(Color(0.03, 0.04, 0.06), 8, K.C_ACC, 1, 8))
	sz.add_child(ed)
	sz.add_child(K.lbl("g", 12, K.C_DIM))
	var plus := K.btn("+", func(): st.g = mini(max_g, int(st.g) + 1); render(PH), "", true)
	plus.custom_minimum_size = Vector2(30, 30)
	sz.add_child(plus)
	var lim := K.lbl("najwyżej %d g na raz%s" % [max_g, "" if max_g >= 250 else " (więcej z poziomem)"], 10, K.C_DIM)
	lim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sz.add_child(lim)
	var add := K.btn("", func(): M.cart_add(st.cart, String(st.p), int(st.g)); Sfx.play("select"); render(PH), "go")
	var relabel := func():
		var cost: float = M.price("wiktor", String(st.p), int(st.g))
		var disc2: float = G.wholesale_disc(int(st.g))
		add.text = "Dodaj do koszyka:  %d g %s  —  %s%s" % [int(st.g), String(D.PRODUCT_GEN[st.p]), G.money(cost), ("  (rabat −%d%%)" % int(round(disc2 * 100.0))) if disc2 > 0.0 else ""]
	relabel.call()
	# pisanie w polu od razu przelicza cenę (bez przerysowania okna — pole nie traci kursora)
	ed.text_changed.connect(func(t: String):
		var digits := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				digits += ch
		var v := clampi(int(digits) if digits != "" else 1, 1, max_g)
		st.g = v
		if digits != t or (digits != "" and int(digits) != v):
			ed.text = str(v) if digits != "" else ""
			ed.caret_column = ed.text.length()
		relabel.call())
	ed.text_submitted.connect(func(_t: String): M.cart_add(st.cart, String(st.p), int(st.g)); Sfx.play("select"); render(PH))
	PH.shop_edit = ed
	add.icon = K.tex("shopping_cart")
	add.add_theme_constant_override("icon_max_width", 16)
	left.add_child(add)
	left.add_child(K.spacer())
	left.add_child(K.wrap("Paczka trafi do skrytki oznaczonej sprejem — Wiktor napisze, do której i jakiego znaku szukać. Nie płacisz przy odbiorze: należność idzie na zeszyt, a gotówkę wrzucasz do jego skrzynki za pawilonem.", 10, K.C_DIM, 470.0))
	# --- prawa strona: koszyk
	var cart_p := K.panel(K.sb(K.C_CARD, 12, K.C_LINE, 1, 10))
	cart_p.custom_minimum_size = Vector2(W_CART, 0)
	row.add_child(cart_p)
	var cv := K.vbox(6)
	cart_p.add_child(cv)
	cv.add_child(K.icon_label("shopping_cart", "KOSZYK", 11, K.C_DIM, 13.0))
	var cart: Array = st.cart
	if cart.is_empty():
		cv.add_child(K.wrap("Pusty. Wybierz towar i rozmiar paczki, potem „Dodaj do koszyka”.", 11, K.C_DIM, W_CART - 30.0))
	for i in range(cart.size()):
		var it: Dictionary = cart[i]
		var idx := i
		var r := K.hbox(6)
		var ic := K.icon("bulk_" + String(it.p), 26.0, Color.WHITE)
		r.add_child(ic)
		var rl := K.lbl("%d g %s" % [int(it.g), String(D.PRODUCT_GEN[it.p])], 12)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rl.clip_text = true
		r.add_child(rl)
		r.add_child(K.lbl(G.money(M.price("wiktor", String(it.p), int(it.g))), 12, K.C_GOLD))
		var xb := K.btn("", func(): cart.remove_at(idx); render(PH), "flat", true)
		xb.icon = K.tex("x")
		xb.add_theme_constant_override("icon_max_width", 12)
		r.add_child(xb)
		cv.add_child(r)
	# paczki, które już są w drodze albo czekają
	if not S.drops.is_empty():
		cv.add_child(K.gap(2))
		cv.add_child(K.icon_label("package", "ZAMÓWIONE", 10, K.C_DIM, 12.0))
		for d in S.drops:
			var rdy: bool = d.state == "ready"
			cv.add_child(K.wrap("%s — %s" % [M.contents(d), ("czeka: %s" % M.spot_name(d)) if rdy else ("będzie ok. %s" % G.clock(d.ready))], 10, K.C_ACC if rdy else K.C_BLUE, W_CART - 30.0))
	cv.add_child(K.spacer())
	var total: float = M.cart_cost(cart)
	var why: String = M.cart_block(cart) if not cart.is_empty() else ""
	cv.add_child(K.rich("Razem: [b]%s[/b]  %s" % [G.money(total), K.col("(%d g)" % M.cart_grams(cart), K.C_DIM)], 14))
	if why != "":
		cv.add_child(K.wrap(why, 11, K.C_WARN, W_CART - 30.0))
	var send := K.btn("Wyślij zamówienie", func(): PH.shop_send(), "go")
	send.icon = K.tex("send")
	send.add_theme_constant_override("icon_max_width", 15)
	send.disabled = cart.is_empty() or why != ""
	cv.add_child(send)


## kafel towaru: rysunek, nazwa, cena za gram albo kłódka z poziomem
static func _tile(PH, c: Dictionary, on: bool) -> Control:
	var st: Dictionary = PH.shop
	var open: bool = c.open
	var pc: Color = Color(String(D.PRODUCTS[c.p].color))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(110, 132)
	b.disabled = not open
	var base := Color(pc.r, pc.g, pc.b, 0.2 if on else 0.08)
	b.add_theme_stylebox_override("normal", K.sb(base, 12, pc if on else Color(pc.r, pc.g, pc.b, 0.3), 2 if on else 1, 6))
	b.add_theme_stylebox_override("hover", K.sb(Color(pc.r, pc.g, pc.b, 0.26), 12, pc, 2 if on else 1, 6))
	b.add_theme_stylebox_override("pressed", K.sb(Color(pc.r, pc.g, pc.b, 0.32), 12, pc, 2, 6))
	b.add_theme_stylebox_override("disabled", K.sb(Color(0.08, 0.09, 0.12), 12, K.C_LINE, 1, 6))
	var pid: String = c.p
	b.pressed.connect(func():
		Sfx.play("click")
		st.p = pid
		render(PH))
	var v := K.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var img := K.icon("bulk_" + pid, 70.0, Color.WHITE if open else Color(0.35, 0.35, 0.4, 0.6))
	img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(img)
	var nl := K.lbl(String(c.name), 12, Color.WHITE if open else K.C_DIM)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nl)
	if open:
		var pl := K.lbl("%d zł/g" % int(c.unit), 13, K.C_GOLD)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pl)
	else:
		var lk := K.icon_label("lock", "od poziomu %d" % int(c.lvl), 10, K.C_DIM, 11.0)
		lk.alignment = BoxContainer.ALIGNMENT_CENTER
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(lk)
	return b


## zakładka „Skup”: Wiktor bierze czysty towar luzem z własnej produkcji
static func _sell(PH, root: VBoxContainer) -> void:
	var S: Dictionary = G.S
	var M = G.Market
	var by: Dictionary = M.bulk_buyer()
	root.add_child(K.wrap("Wiktor skupuje nadwyżki z Twojej produkcji: czysty towar luzem, od %d g, po %d%% ceny ulicznej. Dziś weźmie jeszcze %d g. Rozrobionego nie bierze." % [D.BULK_SELL_MIN, int(round(float(by.rate) * 100.0)), M.bulk_left_today()], 11, K.C_DIM, W_SCREEN - 30.0))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var lv := K.vbox(6)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	var room: String = G.player.loc if (G.player != null and S.stash.has(G.player.loc) and G.player.loc != "wiktor") else ""
	var srcs := [["Plecak", S.inv]]
	if room != "":
		srcs.append(["Skrytka", S.stash[room]])
	var any := false
	for e in srcs:
		var store: Dictionary = e[1]
		for s in G.stacks(store, "bulk"):
			if G.is_mix(s.pur) or float(s.n) < 1.0:
				continue
			any = true
			var r := K.hbox(8)
			r.add_child(K.icon("bulk_" + String(s.p), 30.0, Color.WHITE))
			var l := K.lbl("%s: %s %s" % [String(e[0]), G.grams(s.n), String(D.PRODUCT_GEN[s.p])], 13)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			for amt in [float(D.BULK_SELL_MIN), 50.0, floorf(float(s.n))]:
				var g: float = minf(amt, floorf(float(s.n)))
				if g < float(D.BULK_SELL_MIN) or (amt == 50.0 and g < 50.0):
					continue
				var sp: String = s.p
				var spur: int = int(s.pur)
				var why: String = M.bulk_block(store, sp, spur, g)
				var b := K.btn("%d g → %s" % [int(g), G.money(M.bulk_price(sp, spur, g))], func(): M.bulk_sell(store, sp, spur, g); render(PH), "", true)
				b.disabled = why != ""
				b.tooltip_text = why
				r.add_child(b)
			lv.add_child(r)
	if not any:
		lv.add_child(K.wrap("Nie masz przy sobie czystego towaru luzem. Skup ma sens dopiero przy własnej uprawie albo syntezie.", 12, K.C_DIM, W_SCREEN - 40.0))
