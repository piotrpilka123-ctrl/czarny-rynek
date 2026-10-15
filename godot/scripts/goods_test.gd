extends RefCounted
## Testy nowych towarów: grzybki (szafa grzybowa) i ecstasy (stół laboratoryjny) — dane, produkcja, klienci, miejsca, rozmowy.

static func run(T) -> void:
	var saved: Dictionary = G.S
	var busy: bool = G.busy
	G.S = G.new_state()
	# --- dane: każdy towar ma komplet map i ikon
	var complete := true
	for p in ["grzyb", "tabs"]:
		complete = complete and D.PRODUCTS.has(p) and D.PRODUCT_GEN.has(p) and D.PRODUCT_ACC.has(p) and D.FILLER.has(p) and G.S.demand.has(p)
		complete = complete and ResourceLoader.exists("res://assets/items/%s.png" % String(D.PRODUCT_ICONS[p]))
		for pre in ["brick_", "kostka_", "bulk_"]:
			complete = complete and ResourceLoader.exists("res://assets/items/%s%s.png" % [pre, p])
	T.ok(complete, "grzybki i ecstasy mają nazwy, rozrabiacz, popyt i ikony paczek")
	T.ok(float(D.PRODUCTS.grzyb.base) > float(D.PRODUCTS.szron.base) and float(D.PRODUCTS.tabs.base) < float(D.PRODUCTS.krysztal.base) and float(D.PRODUCTS.grzyb.base) < float(D.PRODUCTS.tabs.base), "ceny wypełniają lukę między amfetaminą a metamfetaminą")
	T.ok(not D.WHOLESALE_PRODUCTS.has("grzyb") and not D.WHOLESALE_PRODUCTS.has("tabs"), "obu towarów nie ma w hurcie Wiktora")
	T.ok(D.RECIPES.grzybki.station == "mush" and D.RECIPES.ecstasy.station == "lab" and D.RECIPES.grzybki.product == "grzyb" and D.RECIPES.ecstasy.product == "tabs", "receptury wskazują właściwe stanowiska i towary")
	var inputs_ok := true
	for rid in ["grzybki", "ecstasy"]:
		for it in D.RECIPES[rid].input:
			inputs_ok = inputs_ok and D.ITEMS.has(it)
	var in_shop := false
	for e in D.SHOP:
		if e.id == "grzybnia":
			in_shop = true
	var in_furn: bool = G.furn_def("grzybnik").get("func", "") == "mush" and D.SUPPLY_GEAR.has("mush")
	T.ok(inputs_ok and in_shop and in_furn, "wsad jest przedmiotem, grzybnia leży u Stasia, a szafa w hurtowni")
	# opłacalność partii względem ceny wsadu (marża na gram musi przeważać nad kosztem)
	var gr_cost := float(D.SHOP.filter(func(e): return e.id == "grzybnia")[0].price)
	T.ok(float(D.RECIPES.grzybki.yield) * float(D.PRODUCTS.grzyb.base) > gr_cost * 6.0, "partia grzybków zarabia kilka razy więcej niż kosztuje grzybnia")
	# --- produkcja grzybków w szafie
	G.S.lvl = 5
	G.S.props["garaz"] = true
	G.S.hide.garage.items = [{"f": "grzybnik", "x": 0.0, "z": 0.0, "r": 0}]
	G.S.items["grzybnia"] = 1
	G.world.refresh_furniture("garage")
	var P = G.Prod
	var opts: Array = P.recipes_for("garage", 0)
	T.ok(opts.size() == 1 and opts[0].id == "grzybki" and String(opts[0].miss) == "", "szafa grzybowa oferuje tylko grzybki")
	T.ok(P.start("garage", 0, "grzybki") and G.S.items["grzybnia"] == 0 and not P.start("garage", 0, "grzybki"), "start zużywa grzybnię i nie da się załadować dwa razy")
	var j: Dictionary = P.job("garage", 0)
	var left := float(D.RECIPES.grzybki.hours) * 0.82 * 60.0
	while left > 0.0:
		P.tick(minf(10.0, left))
		left -= 10.0
	T.ok(int(j.hold) >= 0 and P.stage_name(j) == "Zbierz owocniki", "po owocowaniu szafa czeka na zbiór owocników")
	T.ok(P.proceed("garage", 0) and int(j.hold) == -1, "zbiór odblokowuje suszenie")
	left = float(D.RECIPES.grzybki.hours) * 0.3 * 60.0
	while left > 0.0:
		P.tick(minf(10.0, left))
		left -= 10.0
	T.ok(float(j.prog) >= 1.0, "partia grzybków gotowa")
	var fc: Dictionary = P.forecast(j)
	var before: float = G.goods_total(G.S.stash.garage)
	var res: Dictionary = P.collect("garage", 0)
	T.ok(String(res.p) == "grzyb" and absf(G.goods_total(G.S.stash.garage) - before - float(fc.g)) < 0.6 and float(fc.g) > 10.0, "grzybki trafiają do skrytki (%d g, %d%%)" % [int(fc.g), int(fc.pur)])
	T.ok(G.flag("had_grzyb"), "po pierwszej partii klienci zamawiają grzybki")
	G.S.items["grzybnia"] = 1
	T.ok(P.start("garage", 0, "grzybki"), "szafa przyjmuje kolejną partię")
	G.S.lvl = 3
	P.hide("garage").jobs.clear()
	G.S.items["grzybnia"] = 1
	T.ok(not P.start("garage", 0, "grzybki"), "poniżej poziomu 4 grzybków nie da się nastawić")
	# --- ecstasy przy stole laboratoryjnym
	G.S.lvl = 6
	G.S.items["chemia"] = 2
	G.S.hide.garage.items = [{"f": "lab", "x": 0.0, "z": 0.0, "r": 0}]
	P.hide("garage").jobs.clear()
	var names := []
	for e2 in P.recipes_for("garage", 0):
		if String(e2.miss) == "":
			names.append(String(e2.id))
	T.ok(names.has("ecstasy") and not names.has("metamfetamina"), "od poziomu 6 przy stole można nastawić ecstasy, ale jeszcze nie metamfetaminę")
	T.ok(P.start("garage", 0, "ecstasy") and G.S.items["chemia"] == 0, "ecstasy zużywa dwa zestawy chemikaliów")
	P.hide("garage").jobs.clear()
	# --- klienci, miejsca, skrytki i rozmowy
	var ids := ["tosia", "zdzislaw", "kaja", "bogdan"]
	var clients_ok := true
	var reach_ok := true
	for id in ids:
		var c: Dictionary = G.cust_def(id)
		clients_ok = clients_ok and not c.is_empty() and D.HOMES.has(c.home) and G.S.cust.has(id)
		for p2 in c.get("prods", [c.prod]):
			clients_ok = clients_ok and D.PRODUCTS.has(p2)
		for sid in c.spots:
			clients_ok = clients_ok and not G.spot_def(sid).is_empty()
		if String(c.via).begins_with("ref:"):
			clients_ok = clients_ok and not G.cust_def(String(c.via).split(":")[1]).is_empty()
		for sid2 in c.spots:
			if G.main != null and G.main.nav != null:
				var sp := G.spot_def(sid2)
				var path: Array = G.main.nav.path_between(Vector2(float(D.HOMES[c.home].x), float(D.HOMES[c.home].z)), Vector2(float(sp.x), float(sp.z)))
				reach_ok = reach_ok and path.size() >= 2
	T.ok(clients_ok, "nowi klienci mają dom, miejsca, towary i polecających")
	T.ok(reach_ok, "każdy nowy klient ma drogę z domu na swoje miejsca spotkań")
	var drops_ok := true
	for d in D.DROPS:
		drops_ok = drops_ok and (String(d.turf) == "dom" or not G.spot_def(String(d.turf)).is_empty())
	T.ok(drops_ok, "każda skrytka należy do istniejącego miejsca spotkań")
	var calls := 0
	for cd in D.CALLS:
		if ids.has(String(cd.id)):
			calls += 1
	T.ok(calls == ids.size(), "każdy nowy klient ma swoją rozmowę telefoniczną")
	# zamówienie: klient bierze towar ze swojej listy
	G.S.lvl = 9
	G.S.flags["had_grzyb"] = true
	G.S.flags["had_tabs"] = true
	var ord: Dictionary = G.make_order(G.cust_def("kaja"))
	T.ok(["tabs", "szron"].has(String(ord.product)) and int(ord.grams) >= 8, "Kaja zamawia ecstasy albo amfetaminę w grubszych ilościach (%s, %d g)" % [String(ord.product), int(ord.grams)])
	# stare zapisy: nowy popyt i grzybnia pojawiają się po wczytaniu
	var old := G.new_state()
	old.demand.erase("grzyb")
	old.items.erase("grzybnia")
	var loaded: Dictionary = G.state_from_save(JSON.parse_string(JSON.stringify(old)))
	T.ok(loaded.demand.has("grzyb") and loaded.demand.has("tabs") and loaded.items.has("grzybnia"), "stary zapis dostaje popyt na nowe towary i grzybnię")
	G.S = saved
	G.busy = busy
	G.world.refresh_furniture("garage")
