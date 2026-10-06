extends RefCounted
## GIEŁDA: zamawianie towaru u kilku dostawców (zaufanie, cena, czystość, ryzyko), trzy sposoby dostawy
## (skrytka, skrytkomat pod kod, kurier do ręki), okazja dnia i skup nadwyżek z własnej produkcji.
## Stan: S.vendors[id] = {trust, orders}, S.special = {…} albo null, S.sold_bulk = {day, g}.

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
	return int(G.S.lvl) >= int(v.lvl)


static func max_g(v: Dictionary) -> int:
	return mini(int(v.get("max", 250)), G.wholesale_max())


## cena całego zamówienia u danego dostawcy z wybraną dostawą
static func price(vid: String, p: String, g: int, method := "drop") -> float:
	var v := vendor(vid)
	var unit: float = float(D.PRODUCTS[p].cost) * float(G.S.cost_mult) * float(v.price) * (0.92 if G.has_skill("rabat") else 1.0)
	unit *= 1.0 - trust_discount(vid)
	var total := unit * g * (1.0 - float(D.WHOLESALE_DISC.get(g, 0.0)))
	return round(total * (1.0 + float(D.DELIVERY[method].fee)))


## dlaczego nie można zamówić ("" = można)
static func block(vid: String, p: String, g: int, method: String, on_credit: bool) -> String:
	var S: Dictionary = G.S
	var v := vendor(vid)
	if v.is_empty():
		return "Nie ma takiego dostawcy."
	if not G.flag("hurt_on"):
		return "Wiktor jeszcze Ci nie ufa."
	if not unlocked(v):
		return "Od poziomu %d." % int(v.lvl)
	if int(S.lvl) < int(D.PRODUCTS[p].lvl):
		return "%s od poziomu %d." % [String(D.PRODUCTS[p].name), int(D.PRODUCTS[p].lvl)]
	if g < int(v.min):
		return "Minimum %d g." % int(v.min)
	if g > max_g(v):
		return "Maks. %d g." % max_g(v)
	if S.drops.size() >= 3:
		return "Najpierw odbierz zamówione paczki."
	var cost := price(vid, p, g, method)
	if on_credit:
		if not v.get("credit", false):
			return "%s nie daje na zeszyt." % String(v.name)
		if G.credit_overdue():
			return "Spłać zaległy zeszyt."
		if float(S.credit) + cost > G.credit_limit():
			return "Przekroczysz limit zeszytu (%s)." % G.money(G.credit_limit())
	elif v.get("prepay", false) and S.cash < cost:
		return "Płatne z góry: brakuje %s." % G.money(cost - S.cash)
	if vid == "wiktor" and G.credit_overdue() and not on_credit:
		return "Spłać zaległy zeszyt."
	return ""


static func _code() -> String:
	return "%04d" % (randi() % 10000)


## składa zamówienie; zwraca paczkę (słownik z S.drops) albo {}
static func order(vid: String, p: String, g: int, method := "drop", on_credit := false) -> Dictionary:
	var S: Dictionary = G.S
	if block(vid, p, g, method, on_credit) != "":
		return {}
	var v := vendor(vid)
	var dl: Dictionary = D.DELIVERY[method]
	var spot_id := ""
	var used := []
	for d0 in S.drops:
		used.append(String(d0.spot))
	if method == "locker":
		var lk := []
		for dd in D.DROPS:
			if dd.get("locker", false) and not used.has(String(dd.id)):
				lk.append(dd)
		if lk.is_empty():
			return {}
		spot_id = String(lk.pick_random().id)
	elif method == "courier":
		var sp := []
		for s0 in D.SPOTS:
			if String(s0.id) != "huta" or int(S.lvl) >= 4:
				sp.append(s0)
		spot_id = "spot:" + String(sp.pick_random().id)
	else:
		var opts := []
		for dd in D.DROPS:
			if not dd.get("locker", false) and int(S.lvl) >= int(dd.lvl) and not used.has(String(dd.id)):
				opts.append(dd)
		if opts.is_empty():
			return {}
		spot_id = String(opts.pick_random().id)
	var cost := price(vid, p, g, method)
	var pur_lo: int = int(v.pur[0])
	var pur_hi: int = int(v.pur[1])
	var pur: int = G.qpure(randi_range(pur_lo, pur_hi))
	if randf() < float(v.get("mix", 0.0)):
		pur = G.qmix(pur - 8)
	var eta: float = randf_range(float(v.eta[0]), float(v.eta[1])) * float(dl.eta)
	var prepaid: bool = v.get("prepay", false) and not on_credit
	if prepaid:
		S.cash -= cost
		S.stats.spent = float(S.stats.spent) + cost
	var d := {"id": int(S.next_drop), "spot": spot_id, "p": p, "g": g, "pur": pur, "cost": cost, "credit": on_credit, "ready": S.t + eta, "expire": S.t + eta + float(dl.hold) * 60.0,
		"state": "wait", "vendor": vid, "method": method, "blind": v.get("blind", false), "prepaid": prepaid,
		"burned": method == "drop" and randf() < float(v.get("risk", 0.0)), "code": _code() if method == "locker" else ""}
	S.next_drop = int(S.next_drop) + 1
	S.drops.append(d)
	vstate(vid).orders = int(vstate(vid).orders) + 1
	var how := {"drop": "skrytka", "locker": "skrytkomat", "courier": "kurier"}
	G.chat(vid, "Zamawiam: %d g %s, %s, %s." % [g, String(D.PRODUCT_GEN[p]), String(how[method]), "na zeszyt" if on_credit else ("zapłacone z góry" if prepaid else "płatne przy odbiorze")], true)
	G.chat(vid, "Przyjąłem. %s — dam znać, jak będzie na miejscu (ok. %s)." % [spot_name(d), _eta_text(eta)], false, true)
	Sfx.play("select")
	return d


static func _eta_text(m: float) -> String:
	return ("%d min" % (int(m / 10.0) * 10)) if m < 100.0 else ("%.1f godz." % (m / 60.0)).replace(".", ",")


## punkt odbioru paczki: {name, x, z} (skrytka, skrytkomat albo miejsce spotkania z kurierem)
static func spot(d: Dictionary) -> Dictionary:
	var sid := String(d.spot)
	if sid.begins_with("spot:"):
		var sp: Dictionary = G.spot_def(sid.trim_prefix("spot:"))
		return {"name": "Kurier: " + String(sp.get("name", "?")), "x": float(sp.get("x", 0.0)), "z": float(sp.get("z", 0.0))}
	return G.drop_def(sid)


static func spot_name(d: Dictionary) -> String:
	return String(spot(d).get("name", "?"))


## napis o czystości: przy „kocie w worku” nie wiadomo, co jest w środku
static func pur_text(d: Dictionary) -> String:
	return "??%" if d.get("blind", false) else "%d%%" % int(d.pur)


# ---------------------------------------------------------------- okazja dnia
static func roll_special() -> void:
	var S: Dictionary = G.S
	S["special"] = null
	if not G.flag("hurt_on") or int(S.lvl) < 2:
		return
	var vs := []
	for v in D.VENDORS:
		if unlocked(v) and String(v.id) != "wiktor":
			vs.append(v)
	if vs.is_empty():
		return
	var v: Dictionary = vs.pick_random()
	var ps := []
	for p in D.PRODUCTS:
		if int(S.lvl) >= int(D.PRODUCTS[p].lvl):
			ps.append(p)
	var p: String = ps.pick_random()
	var sizes := []
	for sz in D.WHOLESALE_SIZES:
		if sz >= int(v.min) and sz <= max_g(v):
			sizes.append(sz)
	if sizes.is_empty():
		return
	var g: int = sizes.pick_random()
	var off := randf_range(0.16, 0.3)
	var until: float = floor(S.t / 1440.0) * 1440.0 + randf_range(14.0, 21.0) * 60.0
	S.special = {"vendor": String(v.id), "p": p, "g": g, "off": off, "until": until, "price": round(price(String(v.id), p, g) * (1.0 - off))}
	G.chat(String(v.id), "Okazja tylko dziś do %s: %d g %s, %d%% taniej. Kto pierwszy, ten lepszy." % [G.clock(until), g, String(D.PRODUCT_GEN[p]), int(round(off * 100.0))], false, true)


static func special() -> Variant:
	var sp = G.S.get("special")
	if sp == null or G.S.t > float(sp.until):
		return null
	return sp


static func buy_special() -> Dictionary:
	var S: Dictionary = G.S
	var sp = special()
	if sp == null or S.cash < float(sp.price) or S.drops.size() >= 3:
		return {}
	var keep: float = S.cash
	var vid := String(sp.vendor)
	var v := vendor(vid)
	# okazja zawsze jest płatna z góry i przychodzi do skrytki
	var d := order(vid, String(sp.p), int(sp.g), "drop", false)
	if d.is_empty():
		return {}
	if d.prepaid:
		S.cash = keep
	S.cash -= float(sp.price)
	if not d.prepaid:
		S.stats.spent = float(S.stats.spent) + float(sp.price)
	d.cost = float(sp.price)
	d.prepaid = true
	S.special = null
	return d


# ---------------------------------------------------------------- skup nadwyżek
static func bulk_buyer() -> Dictionary:
	# Port skupuje od poziomu 6; wcześniej nadwyżki bierze Wiktor, tylko taniej
	var port := vendor("port")
	if unlocked(port):
		return {"id": "port", "name": "Port", "rate": D.BULK_SELL + trust("port") / 1000.0}
	return {"id": "wiktor", "name": "Wiktor", "rate": D.BULK_SELL - 0.08 + trust("wiktor") / 1500.0}


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
	var by := bulk_buyer()
	G.take_bulk(store, p, pur, g)
	S.cash += pay
	S.stats.earned = float(S.stats.earned) + pay
	S.stats["bulk_sold"] = int(S.stats.get("bulk_sold", 0)) + int(g)
	var sb: Dictionary = S.get("sold_bulk", {})
	if int(sb.get("day", -1)) != G.day():
		sb = {"day": G.day(), "g": 0}
	sb.g = int(sb.g) + int(g)
	S["sold_bulk"] = sb
	add_trust(String(by.id), g / 25.0)
	G.add_heat(1.0 + g / 60.0, false)
	G.add_xp(g * 0.4)
	G.chat(String(by.id), "Biorę %s %s. %s zostawiam tam, gdzie zawsze." % [G.grams(g), String(D.PRODUCT_GEN[p]), G.money(pay)], false, true)
	G.notify("Skup: +%s za %s %s." % [G.money(pay), G.grams(g), String(D.PRODUCT_GEN[p])], "good")
	Sfx.play("cash")
	return pay
