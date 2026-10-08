extends SceneTree
## Ostrożny audyt marży: jedna partia, 7 dni, regularne uzupełnianie i odbiór.
## Koszt wsadu, woreczków i rekrutacji; bez prądu, lokalu, podróży i wpadek.
func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var game = root.get_node("G")
	var data = root.get_node("D")
	while not game.running: await process_frame
	game.test_mode = true
	for case in [["amfetamina", "mati"], ["metamfetamina", "darek"], ["kokaina", "darek"]]:
		game.S = game.new_state()
		game.S.lvl = 10
		game.S.stats.deals = 6
		game.S.stats.sold = 30
		game.S.cash = 50000.0
		var at: Vector2 = game.Dealers.position(case[1])
		game.player.loc = "out"
		game.player.global_position = Vector3(at.x, game.world.height(at.x, at.y), at.y)
		game.Dealers.hire(case[1])
		var recipe: Dictionary = data.RECIPES[case[0]]
		var cost := 0.0
		for ingredient in recipe.input:
			for item in data.SHOP:
				if item.id == ingredient: cost += float(item.price) * int(recipe.input[ingredient]) / int(item.n)
		var bags_cost := 0.0
		for item in data.SHOP:
			if item.id == "woreczki": bags_cost = ceil(float(recipe["yield"]) / int(item.n)) * float(item.price)
		game.S.cash -= cost + bags_cost
		game.add_pack(game.S.inv, recipe.product, int(recipe.pur), int(recipe["yield"]))
		var sold_day := 0
		for hour in range(8, 8 + 7 * 24):
			game.S.t = float(hour) * 60.0
			if hour % 24 >= 8 and hour % 24 < 23:
				game.Dealers.supply(case[1], recipe.product, 20)
			game.Dealers.tick()
			game.Dealers.collect(case[1])
			if sold_day == 0 and game.Dealers.stock(case[1]) + game.packed_total(game.S.inv) == 0: sold_day = hour / 24 + 1
		print("SIEC_BALANS ", case[0], " partia=", int(recipe["yield"]), " sprzedano=", game.S.dealers[case[1]].sold,
			" zapas=", game.Dealers.stock(case[1]) + game.packed_total(game.S.inv), " zysk_po_wsadzie_bagach_rekrutacji=", game.S.cash - 50000.0, " partia_skonczona_dnia=", sold_day)
	quit()
