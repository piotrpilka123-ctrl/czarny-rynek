extends RefCounted
## Testy Giełdy: dostawcy i poziomy, ceny i rabat za zaufanie, przedpłata, zeszyt tylko u Wiktora,
## kot w worku, skrytkomat z kodem, kurier, spalona skrytka, okazja dnia, skup nadwyżek.


static func run(T) -> void:
	var M = G.Market
	var keep: Dictionary = G.S
	G.S = G.new_state()
	var S: Dictionary = G.S
	S.flags["hurt_on"] = true
	S.flags["got_first"] = true
	S.lvl = 1
	S.cash = 5000.0
	T.ok(M.block("wiktor", "dym", 5, "drop", true) == "" and M.block("zbyszek", "dym", 5, "drop", false).contains("poziomu"), "na 1. poziomie handluje tylko Wiktor")
	S.lvl = 6
	S.cost_mult = 1.0
	var pw: float = M.price("wiktor", "dym", 10)
	var pz: float = M.price("zbyszek", "dym", 10)
	var pc: float = M.price("chemik", "dym", 10)
	T.ok(pz < pw * 0.8 and pc > pw * 1.25, "ceny za 10 g marihuany: Zbyszek %d zł, Wiktor %d zł, Chemik %d zł" % [int(pz), int(pw), int(pc)])
	T.ok(M.price("wiktor", "dym", 10, "locker") > pw * 1.07 and M.price("wiktor", "dym", 10, "courier") > pw * 1.14, "skrytkomat i kurier kosztują dopłatę")
	T.ok(M.block("zbyszek", "dym", 10, "drop", true).contains("zeszyt") and M.block("chemik", "dym", 5, "drop", false).contains("Minimum"), "zeszyt tylko u Wiktora, Chemik od 10 g")
	T.ok(M.block("port", "dym", 20, "drop", false).contains("Minimum") and M.block("port", "dym", 50, "drop", false) == "", "Port sprzedaje od 50 g")
	# zaufanie daje rabat
	M.add_trust("wiktor", 100.0)
	T.ok(M.price("wiktor", "dym", 10) < pw * 0.93 and M.trust_discount("wiktor") <= 0.0801, "pełne zaufanie = 8%% rabatu (%d → %d zł)" % [int(pw), int(M.price("wiktor", "dym", 10))])
	M.vstate("wiktor").trust = 0.0
	# zamówienie u Wiktora na zeszyt, do skrytki
	var d1: Dictionary = M.order("wiktor", "dym", 10, "drop", true)
	T.ok(not d1.is_empty() and d1.credit and not d1.prepaid and d1.state == "wait" and S.cash == 5000.0 and not M.spot(d1).is_empty(), "Wiktor: zamówienie na zeszyt, płatne przy odbiorze")
	# Chemik: płatne z góry, wysoka czystość, długo
	var d2: Dictionary = M.order("chemik", "szron", 10, "locker", false)
	T.ok(not d2.is_empty() and d2.prepaid and S.cash < 5000.0 and int(d2.pur) >= 85 and String(d2.code).length() == 4 and M.spot(d2).get("locker", false), "Chemik: przedpłata, czystość %d%%, skrytkomat z kodem %s" % [int(d2.pur), String(d2.code)])
	T.ok(float(d2.ready) - S.t > float(d1.ready) - S.t, "Chemik dowozi dłużej niż Wiktor")
	# kot w worku u Zbyszka: czystość ukryta, czasem rozrobiony, czasem spalony
	var mixes := 0
	var burned := 0
	var low := 100
	var high := 0
	for i in range(200):
		S.drops.clear()
		S.cash = 5000.0
		var dz: Dictionary = M.order("zbyszek", "dym", 5, "drop", false)
		if G.is_mix(dz.pur):
			mixes += 1
		if dz.burned:
			burned += 1
		low = mini(low, int(dz.pur))
		high = maxi(high, int(dz.pur))
		if i == 0:
			T.ok(dz.blind and M.pur_text(dz) == "??%", "Zbyszek: czystość nieznana do odbioru")
	T.ok(mixes > 30 and mixes < 95 and burned > 6 and burned < 40 and low < 55 and high > 70, "kot w worku: %d/200 rozrobionych, %d/200 spalonych, czystość %d–%d%%" % [mixes, burned, low, high])
	var never := true
	for i in range(60):
		S.drops.clear()
		var dl: Dictionary = M.order("zbyszek", "dym", 5, "locker", false)
		if dl.burned:
			never = false
	T.ok(never, "skrytkomat nigdy nie jest spalony")
	S.drops.clear()
	# odbiór: przedpłacona paczka nie kosztuje drugi raz, zaufanie rośnie, kot w worku się ujawnia
	S.cash = 1000.0
	var d3: Dictionary = M.order("chemik", "dym", 10, "drop", false)
	var after_order: float = S.cash
	d3.state = "ready"
	T.ok(G.pickup_block(d3) == "" and G.pickup_drop(d3) and S.cash == after_order and float(S.credit) == 0.0, "odbiór przedpłaconej paczki nic nie kosztuje")
	T.ok(M.trust("chemik") > 3.0 and S.drops.is_empty(), "po odbiorze rośnie zaufanie dostawcy (%d)" % int(M.trust("chemik")))
	# kurier: stoi w miejscu spotkań, czeka krótko; spóźnienie = strata przedpłaty i zaufania
	S.inv = G.new_store()
	var d4: Dictionary = M.order("chemik", "dym", 10, "courier", false)
	T.ok(String(d4.spot).begins_with("spot:") and M.spot_name(d4).begins_with("Kurier") and float(d4.expire) - float(d4.ready) < 40.0, "kurier czeka w miejscu spotkań tylko %d min" % int(float(d4.expire) - float(d4.ready)))
	var statics0: int = G.npcs.statics.size()
	S.t = float(d4.ready) + 1.0
	G.on_tick()
	T.ok(d4.state == "ready" and G.npcs.statics.size() == statics0 + 1 and G.main.drop_actors.has(int(d4.id)), "o umówionej porze kurier staje na miejscu")
	var tr0: float = M.trust("chemik")
	S.t = float(d4.expire) + 1.0
	G.on_tick()
	T.ok(S.drops.is_empty() and G.npcs.statics.size() == statics0 and M.trust("chemik") < tr0 and float(S.credit) == 0.0, "spóźnienie: kurier odchodzi, przedpłata i zaufanie przepadają")
	# spalona skrytka: przy paczce czai się patrol
	var d5: Dictionary = M.order("wiktor", "dym", 5, "drop", false)
	d5.burned = true
	var cops0: int = G.npcs.cops.size()
	S.t = float(d5.ready) + 1.0
	G.on_tick()
	var actor = G.main.drop_actors.get(int(d5.id))
	T.ok(actor != null and actor.has("cop") and G.npcs.cops.size() == cops0 + 1, "spalona skrytka: w pobliżu staje zasadzka")
	if actor != null and actor.has("cop"):
		var sp5: Dictionary = M.spot(d5)
		var c5: Dictionary = actor.cop
		var dist5 := Vector2(c5.x - float(sp5.x), c5.z - float(sp5.z)).length()
		T.ok(dist5 > 4.0 and dist5 < 16.0 and c5.get("temp", false), "tajniak stoi %d m od skrytki i na nią patrzy" % int(dist5))
	S.t = float(d5.expire) + 1.0
	G.on_tick()
	T.ok(G.npcs.cops.size() == cops0 and not G.main.drop_actors.has(int(d5.id)), "nieodebrana spalona paczka: zasadzka się zwija")
	S.credit = 0.0
	# okazja dnia
	var found := false
	for i in range(20):
		M.roll_special()
		if M.special() != null:
			found = true
			break
	var sp = M.special()
	T.ok(found and sp != null and float(sp.off) >= 0.15 and float(sp.until) > S.t - 1440.0, "okazja dnia: %s" % (("%d g %s −%d%%" % [int(sp.g), String(sp.p), int(float(sp.off) * 100.0)]) if sp != null else "brak"))
	if sp != null:
		sp.until = S.t + 300.0
		S.cash = 90000.0
		var full: float = M.price(String(sp.vendor), String(sp.p), int(sp.g))
		var ds: Dictionary = M.buy_special()
		T.ok(not ds.is_empty() and ds.prepaid and absf(90000.0 - S.cash - float(sp.price)) < 0.5 and float(sp.price) < full * 0.86 and M.special() == null, "okazja kupiona za %d zł zamiast %d zł" % [int(sp.price), int(full)])
	S.drops.clear()
	# skup nadwyżek
	S.lvl = 4
	S.cash = 0.0
	var store: Dictionary = G.new_store()
	G.add_bulk(store, "dym", 70, 120.0)
	G.add_bulk(store, "dym", 67, 60.0)
	T.ok(M.bulk_buyer().id == "wiktor" and M.bulk_block(store, "dym", 70, 10.0).contains("od") and M.bulk_block(store, "dym", 67, 60.0).contains("Rozrobionego"), "skup: minimum 20 g, rozrobionego nie biorą")
	var pay: float = M.bulk_sell(store, "dym", 70, 100.0)
	var street: float = G.market_price("dym", 70) * 100.0
	T.ok(pay > street * 0.35 and pay < street * 0.55 and S.cash == pay and absf(float(store.bulk.dym["70"]) - 20.0) < 0.01, "skup u Wiktora: 100 g za %d zł (ulica dałaby %d zł)" % [int(pay), int(street)])
	T.ok(M.bulk_left_today() == D.BULK_SELL_DAY * 4 - 100 and M.bulk_block(store, "dym", 70, 20.0) == "", "dzienny limit skupu maleje (zostało %d g)" % M.bulk_left_today())
	G.add_bulk(store, "dym", 70, 200.0)
	T.ok(M.bulk_block(store, "dym", 70, 100.0).contains("limit"), "ponad dzienny limit skup nie weźmie")
	S.lvl = 6
	T.ok(M.bulk_buyer().id == "port" and float(M.bulk_buyer().rate) > 0.49, "od 6. poziomu skupuje Port — lepiej płaci")
	# stare wejście (Hurt) dalej działa: zwykłe = Wiktor, czyste = Chemik
	S.cash = 3000.0
	T.ok(G.order_goods("dym", 5, false, true) and String(S.drops[0].vendor) == "wiktor", "stare zamówienie „standard” idzie do Wiktora")
	T.ok(G.order_goods("dym", 10, true, false) and String(S.drops[1].vendor) == "chemik" and int(S.drops[1].pur) >= 85, "stare zamówienie „czyste” idzie do Chemika")
	# okno w telefonie
	G.ui.open_phone("hurt")
	await T.frames(3)
	T.ok(G.ui.mode == "phone", "Giełda otwiera się w telefonie")
	G.ui.phone.hurt.v = "zbyszek"
	G.ui.phone.hurt.m = "courier"
	G.ui.phone.render()
	await T.frames(2)
	G.ui.close_all()
	for a in G.main.drop_actors.keys():
		G.main.drop_gone({"id": a})
	G.S = keep
