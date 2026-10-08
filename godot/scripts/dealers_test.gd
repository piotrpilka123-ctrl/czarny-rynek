extends RefCounted

static func run(T) -> void:
	var saved: Dictionary = G.S
	var player_pos: Vector3 = G.player.global_position
	var player_loc: String = G.player.loc
	G.S = G.new_state()
	G.player.loc = "out"
	var at: Vector2 = G.Dealers.position("mati")
	G.player.global_position = Vector3(at.x, G.world.height(at.x, at.y), at.y)
	T.ok(not G.Dealers.hire("mati"), "dealer nie dołącza na pierwszym poziomie")
	G.S.lvl = 10
	G.S.stats.deals = 6
	G.S.stats.sold = 30
	G.S.cash = 15000.0
	T.ok(G.Dealers.hire("mati") and G.S.cash == 14750.0 and not G.Dealers.hire("mati"), "rekrutacja kosztuje 250 zł i nie może być wykonana dwa razy")
	G.add_pack(G.S.inv, "dym", 100, 2, 5)
	T.ok(G.Dealers.supply("mati", "dym") == 10 and G.packed_total(G.S.inv) == 0 and G.Dealers.stock("mati") == 10, "dealer dostaje faktyczne całe paczki i sam dzieli je na małe sprzedaże")
	T.ok(G.Dealers.collect("mati") == 0.0, "przekazanie zapasu nie tworzy od razu pieniędzy")
	var state: Dictionary = G.S.dealers.mati
	G.S.t = 11.0 * 60.0
	G.Dealers.tick()
	var earned: float = state.cash
	T.ok(G.Dealers.stock("mati") == 6 and earned > 0.0 and earned < 200.0, "po upływie czasu sprzedaje do 4 g, potrącając prowizję")
	G.Dealers.tick()
	T.ok(G.Dealers.stock("mati") == 6 and state.cash == earned, "powtórzona aktualizacja nie podwaja sprzedaży ani pieniędzy")
	G.player.global_position.x += 50.0
	T.ok(G.Dealers.collect("mati") == 0.0 and state.cash == earned, "gotówki nie da się odebrać zdalnie")
	G.player.global_position.x -= 50.0
	T.ok(G.Dealers.collect("mati") == earned and G.Dealers.collect("mati") == 0.0 and G.S.cash == 14750.0 + earned, "odbiór gotówki rozlicza zarobek dokładnie raz")
	state.paused = true
	G.S.t = 12.0 * 60.0
	G.Dealers.tick()
	T.ok(G.Dealers.stock("mati") == 6, "wstrzymany dealer nie rusza zapasu")
	state.paused = false
	G.S.invest = 70.0
	G.S.t = 13.0 * 60.0
	G.Dealers.tick()
	T.ok(G.Dealers.stock("mati") == 6, "duże śledztwo wstrzymuje sprzedaż sieci")
	G.S.invest = 0.0
	G.S.t = 23.0 * 60.0
	G.Dealers.tick()
	T.ok(G.Dealers.stock("mati") == 6, "dealer nie sprzedaje po godzinach")
	G.add_pack(G.S.inv, "dym", 10, 5)
	T.ok(G.Dealers.supply("mati", "dym") == 0 and G.packed_total(G.S.inv) == 5, "dealer odmawia zbyt słabego towaru bez zabierania paczek")
	var restored: Dictionary = G.new_state()
	G._merge(restored, JSON.parse_string(JSON.stringify(G.S)))
	T.ok(int(G.goods_total(restored.dealers.mati.stock)) == 6 and restored.dealers.mati.cash == state.cash, "zapas dealera i rozliczenie przechodzą przez zapis JSON")
	var slots_ok := true
	for pair in [["amfetamina", 1], ["metamfetamina", 2], ["kokaina", 3]]:
		var recipe: Dictionary = D.RECIPES[pair[0]]
		var cost := 0.0
		for ingredient in recipe.input:
			for item in D.SHOP:
				if String(item.id) == String(ingredient):
					cost += float(item.price) * int(recipe.input[ingredient]) / int(item.n)
		var unit: float = cost / float(recipe["yield"])
		var retailer: float = float(D.PRODUCTS[recipe.product].base) * (0.65 if pair[0] == "amfetamina" else 0.6)
		T.ok(unit > 0.0 and unit < retailer and unit > float(D.PRODUCTS[recipe.product].base) * 0.3, "ekonomia %s: wsad %d zł, partia %d g, koszt %.2f zł/g, przed prądem i prowizją" % [recipe.name, int(cost), int(recipe["yield"]), unit])
		slots_ok = slots_ok and recipe.input.size() == int(pair[1])
	T.ok(slots_ok, "produkcja amfetaminy, mety i kokainy wymaga odpowiednio 1, 2 i 3 slotów wsadu")
	G.S = saved
	G.player.loc = player_loc
	G.player.global_position = player_pos
