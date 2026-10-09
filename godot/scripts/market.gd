extends RefCounted
## HURT: jeden dostawca — Wiktor. Towar zawsze czysty (100%), zamówienie składa się SMS-em jako koszyk,
## paczka trafia do skrytki oznaczonej sprejem, a zapłata idzie „na zeszyt”: gotówkę wrzuca się potem
## do skrzynki Wiktora (G.box_settle). Tu także skup nadwyżek z własnej produkcji.
## Stan: S.vendors.wiktor = {trust, orders}, S.sold_bulk = {day, g}.

const VID := "wiktor"


static func vendor(id: String) -> Dictionary:
	for v in D.VENDORS:
		if String(v.id) == id:
			return v
	return {}


static func vstate(id: String) -> Dictionary:
	var S: Dictionary = G.S
	if not S.has("vendors"):
		S["vendors"] = {}
	if not S.vendors.has(id):
		S.vendors[id] = {"trust": 0.0, "orders": 0}
	return S.vendors[id]


static func trust(id: String) -> float:
	return float(vstate(id).trust)


static func add_trust(id: String, n: float) -> void:
	var st := vstate(id)
	st.trust = clampf(float(st.trust) + n, 0.0, 100.0)


## stały klient płaci mniej: do 8% rabatu przy pełnym zaufaniu
static func trust_discount(id: String) -> float:
	return minf(0.08, trust(id) / 1250.0)


static func unlocked(v: Dictionary) -> bool:
	return int(G.S.lvl) >= int(v.get("lvl", 1))


static func max_g(v: Dictionary) -> int:
	return mini(int(v.get("max", 250)), G.wholesale_max())


## cena jednej pozycji (towar × gramy) z rabatem za ilość i za zaufanie
static func price(_vid: String, p: String, g: int, _method := "drop") -> float:
	var unit: float = G.wholesale_unit(p, false) * (1.0 - trust_discount(VID))
	return round(unit * g * (1.0 - G.wholesale_disc(g)))


## produkty, które Wiktor w ogóle pokazuje w sklepie (zablokowane też — z poziomem, od którego będą)
static func catalog() -> Array:
	var out := []
	for p in D.WHOLESALE_PRODUCTS:
		out.append({"p": p, "name": String(D.PRODUCTS[p].name), "lvl": int(D.PRODUCTS[p].lvl), "open": int(G.S.lvl) >= int(D.PRODUCTS[p].lvl),
			"unit": int(round(G.wholesale_unit(p, false) * (1.0 - trust_discount(VID))))})
	return out


## rozmiary paczek dostępne na tym poziomie
static func sizes() -> Array:
	var out := []
	for g in D.WHOLESALE_SIZES:
		if int(g) <= G.wholesale_max():
			out.append(int(g))
	return out


static func cart_cost(cart: Array) -> float:
	var n := 0.0
	for it in cart:
		n += price(VID, String(it.p), int(it.g))
	return n


static func cart_grams(cart: Array) -> int:
	var n := 0
	for it in cart:
		n += int(it.g)
	return n


## dokłada pozycję do koszyka: ten sam towar zbiera się w jednej pozycji (do limitu na zamówienie)
static func cart_add(cart: Array, p: String, g: int) -> void:
	g = maxi(1, g)
	for it in cart:
		if String(it.p) == p:
			it.g = mini(G.wholesale_max(), int(it.g) + g)
			return
	cart.append({"p": p, "g": mini(G.wholesale_max(), g)})


## dlaczego nie można zamówić koszyka ("" = można)
static func cart_block(cart: Array) -> String:
	var S: Dictionary = G.S
	if not G.flag("hurt_on"):
		return "Wiktor jeszcze Ci nie ufa."
	if cart.is_empty():
		return "Koszyk jest pusty."
	var per := {}
	for it in cart:
		var p := String(it.p)
		if not D.PRODUCTS.has(p):
			return "Nie ma takiego towaru."
		if int(S.lvl) < int(D.PRODUCTS[p].lvl):
			return "%s od poziomu %d." % [String(D.PRODUCTS[p].name), int(D.PRODUCTS[p].lvl)]
		if int(it.g) < 1:
			return "Minimum 1 g."
		per[p] = int(per.get(p, 0)) + int(it.g)
	for p in per:
		if int(per[p]) > G.wholesale_max():
			return "%s: najwyżej %d g na jedno zamówienie." % [String(D.PRODUCTS[p].name), G.wholesale_max()]
	if S.drops.size() >= D.DROPS_MAX:
		return "Najpierw odbierz zamówione paczki."
	var cost := cart_cost(cart)
	if G.credit_overdue() and not G.rescue_cart(cart):
		return "Zeszyt po terminie. Wrzuć pieniądze do skrzynki." if (G.all_goods() >= 1.0 or not S.drops.is_empty()) else "Zeszyt po terminie: Wiktor da najwyżej 5 g marihuany."
	if not G.rescue_cart(cart) and float(S.credit) + G.drops_owed() + cost > G.credit_limit():
		return "Za dużo na zeszycie (limit %s). Najpierw oddaj część do skrzynki." % G.money(G.credit_limit())
	if G.drop_pick(_used()) == "":
		return "Wszystkie skrytki zajęte."
	return ""


static func _used() -> Array:
	var used := []
	for d0 in G.S.drops:
		used.append(String(d0.spot))
	return used


## składa zamówienie całego koszyka; zwraca paczkę (słownik z S.drops) albo {}
static func order_cart(cart: Array) -> Dictionary:
	var S: Dictionary = G.S
	if cart_block(cart) != "":
		return {}
	var rescue: bool = G.rescue_cart(cart)
	var spot_id := G.drop_pick(_used())
	var v := vendor(VID)
	var cost := cart_cost(cart) * (1.25 if rescue else 1.0)
	var eta: float = randf_range(float(v.eta[0]), float(v.eta[1]))
	var items := []
	var parts := []
	for it in cart:
		items.append({"p": String(it.p), "g": int(it.g)})
		parts.append("%d g %s" % [int(it.g), String(D.PRODUCT_GEN[it.p])])
	# im dłużej policja prowadzi śledztwo, tym częściej skrytkę ktoś obserwuje
	var burned: bool = randf() < clampf((float(S.invest) - 25.0) / 300.0, 0.0, 0.22)
	var d := {"id": int(S.next_drop), "spot": spot_id, "items": items, "p": String(items[0].p), "g": cart_grams(cart), "pur": D.PURITY_STD, "cost": round(cost),
		"credit": true, "ready": S.t + eta, "expire": S.t + eta + float(D.DELIVERY.drop.hold) * 60.0, "state": "wait", "vendor": VID, "method": "drop",
		"blind": false, "prepaid": false, "burned": burned, "code": ""}
	S.next_drop = int(S.next_drop) + 1
	S.drops.append(d)
	vstate(VID).orders = int(vstate(VID).orders) + 1
	G.chat(VID, "Zamawiam: %s." % ", ".join(parts), true)
	if rescue:
		G.chat(VID, "Wisisz mi, a chcesz jeszcze? Ostatni raz. Pięć gramów, ćwierć drożej. Sprzedaj i wrzuć kasę do skrzynki.", false, true)
	else:
		G.chat(VID, "Przyjąłem, %s na zeszyt. %s — dam znać, jak będzie na miejscu (ok. %s)." % [G.money(d.cost), spot_name(d), _eta_text(eta)], false, true)
	Sfx.play("select")
	return d


## stare, proste wejście (jedna pozycja) — dla testów i symulacji
static func block(_vid: String, p: String, g: int, _method := "drop", _on_credit := true) -> String:
	return cart_block([{"p": p, "g": g}])


static func order(_vid: String, p: String, g: int, _method := "drop", _on_credit := true) -> Dictionary:
	return order_cart([{"p": p, "g": g}])


static func _eta_text(m: float) -> String:
	return ("%d min" % (int(m / 10.0) * 10)) if m < 100.0 else ("%.1f godz." % (m / 60.0)).replace(".", ",")


## punkt odbioru paczki: {name, x, z, mark}
static func spot(d: Dictionary) -> Dictionary:
	return G.drop_def(String(d.spot))


static func spot_name(d: Dictionary) -> String:
	return String(spot(d).get("name", "?"))


## co jest w paczce: „10 g marihuany + 5 g amfetaminy”
static func contents(d: Dictionary) -> String:
	var parts := []
	for it in d.get("items", [{"p": d.get("p", "dym"), "g": d.get("g", 0)}]):
		parts.append("%d g %s" % [int(it.g), String(D.PRODUCT_GEN[it.p])])
	return " + ".join(parts)


# ---------------------------------------------------------------- skup nadwyżek
## Wiktor bierze nadwyżki z własnej produkcji; od 6. poziomu płaci lepiej (większe partie idą dalej, do portu)
static func bulk_buyer() -> Dictionary:
	var rate: float = D.BULK_SELL - (0.0 if int(G.S.lvl) >= 6 else 0.08) + trust(VID) / 1500.0
	return {"id": VID, "name": "Wiktor", "rate": rate}


static func bulk_left_today() -> int:
	var S: Dictionary = G.S
	var sb: Dictionary = S.get("sold_bulk", {})
	var used: int = int(sb.get("g", 0)) if int(sb.get("day", -1)) == G.day() else 0
	return maxi(0, D.BULK_SELL_DAY * int(S.lvl) - used)


static func bulk_price(p: String, pur: int, g: float) -> float:
	return round(G.market_price(p, pur) * float(bulk_buyer().rate) * g)


## dlaczego nie można sprzedać hurtem ("" = można)
static func bulk_block(store: Dictionary, p: String, pur: int, g: float) -> String:
	if not G.flag("hurt_on"):
		return "Najpierw rozlicz się z Wiktorem."
	if g < float(D.BULK_SELL_MIN):
		return "Skup bierze od %d g." % D.BULK_SELL_MIN
	if float(store.bulk[p].get(str(pur), 0.0)) < g - 0.01:
		return "Nie masz tyle towaru w tym miejscu."
	if g > bulk_left_today() + 0.01:
		return "Dzienny limit skupu: zostało %d g." % bulk_left_today()
	if G.is_mix(pur):
		return "Rozrobionego towaru skup nie bierze."
	return ""


## sprzedaje towar luzem ze wskazanego schowka (plecak albo skrytka kryjówki)
static func bulk_sell(store: Dictionary, p: String, pur: int, g: float) -> float:
	var S: Dictionary = G.S
	if bulk_block(store, p, pur, g) != "":
		return 0.0
	var pay := bulk_price(p, pur, g)
	G.take_bulk(store, p, pur, g)
	S.cash += pay
	S.stats.earned = float(S.stats.earned) + pay
	S.stats["bulk_sold"] = int(S.stats.get("bulk_sold", 0)) + int(g)
	var sb: Dictionary = S.get("sold_bulk", {})
	if int(sb.get("day", -1)) != G.day():
		sb = {"day": G.day(), "g": 0}
	sb.g = int(sb.g) + int(g)
	S["sold_bulk"] = sb
	add_trust(VID, g / 25.0)
	G.add_heat(1.0 + g / 60.0, false)
	G.add_xp(g * 0.4)
	G.chat(VID, "Biorę %s %s. %s zostawiam tam, gdzie zawsze." % [G.grams(g), String(D.PRODUCT_GEN[p]), G.money(pay)], false, true)
	G.notify("Skup: +%s za %s %s." % [G.money(pay), G.grams(g), String(D.PRODUCT_GEN[p])], "good")
	Sfx.play("cash")
	return pay
