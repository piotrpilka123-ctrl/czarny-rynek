extends RefCounted
## Testy strojów: kupno i zakładanie, wpływ na szybkość, kondycję, kieszenie, widoczność,
## podejrzliwość patroli (w tym kominiarka), świadków, ceny u klientów; szafa w ekwipunku; zapis.


const Chars = preload("res://scripts/chars.gd")
const Models = preload("res://scripts/models.gd")


static func run(T) -> void:
	var keep: Dictionary = G.S
	G.S = G.new_state()
	var S: Dictionary = G.S
	var P = G.player
	var back_loc: String = P.loc
	var back_pos: Vector3 = P.global_position
	T.ok(G.outfit() == "dres" and G.outfit_stat("speed") == 1.0 and not G.outfit_masked() and G.outfit_owned("dres"), "na start stary dres bez zalet i wad")
	S.cash = 100.0
	S.lvl = 1
	T.ok(not G.outfit_buy("biegacz") and G.outfit() == "dres", "bez pieniędzy i poziomu nic nie kupisz")
	S.cash = 20000.0
	S.lvl = 8
	var cap0: int = G.capacity()
	var stam0: float = P.max_stamina()
	T.ok(G.outfit_buy("biegacz") and G.outfit() == "biegacz" and S.cash == 20000.0 - 320.0, "kupiony strój od razu ląduje na grzbiecie")
	T.ok(absf(P.max_stamina() - stam0 * 1.3) < 0.01 and G.capacity() == cap0 - 5 and G.outfit_stat("speed") > 1.05, "biegacz: szybciej, więcej kondycji, mniej kieszeni")
	T.ok(not G.outfit_buy("biegacz"), "tego samego stroju nie kupuje się drugi raz")
	G.outfit_buy("robotnik")
	T.ok(G.capacity() == cap0 + 10 and G.outfit_stat("speed") < 1.0, "kombinezon: pojemniejsze kieszenie, wolniejszy bieg")
	T.ok(G.outfit_wear("dres") and G.outfit() == "dres" and not G.outfit_wear("garnitur"), "przebrać się można tylko w to, co jest w szafie")
	# widoczność: czarna kurtka nocą, jaskrawy biegacz w dzień
	G.main.teleport("out", Vector3(-37.0 * 0.56, 0.0, 20.0 * 0.56), 0.0)
	await T.frames(2)
	G.rain = 0.0
	G.night = 1.0
	P.crouching = false
	P.hidden = false
	P.velocity = Vector3.ZERO
	P.flash.light_energy = 0.0
	var v_dres: float = P.visibility()
	G.outfit_buy("czarny")
	var v_black: float = P.visibility()
	G.night = 0.0
	var v_black_day: float = P.visibility()
	G.outfit_wear("biegacz")
	var v_run_day: float = P.visibility()
	G.outfit_wear("dres")
	var v_dres_day: float = P.visibility()
	T.ok(v_black < v_dres * 0.75 and absf(v_black_day - v_dres_day) < 0.01 and v_run_day > v_dres_day * 1.1, "czarna kurtka chowa nocą (%.2f zamiast %.2f), strój biegacza w dzień widać z daleka" % [v_black, v_dres])
	# podejrzliwość patroli
	S.inv = G.new_store()
	S.heat = 0.0
	S.invest = 0.0
	S.wanted = false
	T.ok(G.compute_susp() == 0.0, "czysty i w dresie: patrol nie ma się do czego przyczepić")
	G.outfit_buy("kominiarka")
	var m_mask: float = G.compute_susp()
	T.ok(G.outfit_masked() and m_mask >= 1.0, "kominiarka: patrol reaguje, nawet gdy nic nie niesiesz (mnożnik %.2f)" % m_mask)
	G.add_pack(S.inv, "dym", 80, 5)
	S.heat = 60.0
	var m_mask_carry: float = G.compute_susp()
	G.outfit_wear("dres")
	var m_plain: float = G.compute_susp()
	G.outfit_buy("garnitur")
	var m_suit: float = G.compute_susp()
	T.ok(m_mask_carry > m_plain * 1.9 and m_suit < m_plain * 0.75 and m_plain > 0.0, "z towarem przy gorącej ulicy: kominiarka %.2f, dres %.2f, garnitur %.2f" % [m_mask_carry, m_plain, m_suit])
	# świadkowie i śledztwo
	S.invest = 10.0
	G.add_invest(10.0)
	var inv_suit: float = S.invest
	G.outfit_wear("kominiarka")
	S.invest = 10.0
	G.add_invest(10.0)
	var inv_mask: float = S.invest
	G.add_invest(-5.0)
	T.ok(absf(inv_suit - 20.0) < 0.01 and absf(inv_mask - 13.0) < 0.01 and absf(float(S.invest) - 8.0) < 0.01, "w kominiarce do akt trafia 30% tego, co widzieli świadkowie (spadki śledztwa bez zmian)")
	# ceny u klientów
	var def: Dictionary = G.cust_def("dominik")
	var st := {"loy": 0.0, "hunger": 0.4}
	G.outfit_wear("dres")
	var price0: float = G.max_price(def, st, "dym", 80, 5)
	G.outfit_wear("garnitur")
	var price_suit: float = G.max_price(def, st, "dym", 80, 5)
	G.outfit_wear("kominiarka")
	var price_mask: float = G.max_price(def, st, "dym", 80, 5)
	T.ok(price_suit > price0 * 1.05 and price_mask < price0 * 0.96, "klient da %.0f zł w dresie, %.0f w garniturze, %.0f zamaskowanemu" % [price0, price_suit, price_mask])
	# cechy do pokazania w sklepie
	var tr: Array = G.outfit_traits("kominiarka")
	var has_warn := false
	for t in tr:
		if String(t.text).contains("zamaskowany") and not t.good:
			has_warn = true
	T.ok(tr.size() >= 5 and has_warn and G.outfit_traits("dres").is_empty(), "sklep pokazuje zalety i wady każdego stroju")
	# gdzie można się przebrać
	T.ok(not G.can_change_here(), "na ulicy się nie przebierzesz")
	G.main.teleport("ciuchy", Vector3(float(D.ROOMS.ciuchy.cx), 0.0, 1.5), 0.0)
	await T.frames(2)
	T.ok(G.can_change_here(), "w „Taniej Odzieży” można")
	# wieszak w sklepie: same ubrania na sztuki, żadnych całych strojów; lepsze rzeczy od wyższego poziomu
	G.ui.open_inventory("", "wear")
	await T.frames(2)
	var pieces := 0
	for iid0 in D.ITEMS:
		if D.ITEMS[iid0].has("slot"):
			pieces += 1
	var offer: Array = G.ui.inv.wear_offer
	var only_pieces := true
	for oid0 in offer:
		if not D.ITEMS.has(oid0) or not D.ITEMS[oid0].has("slot") or D.OUTFITS.has(oid0) and not D.ITEMS.has(oid0):
			only_pieces = false
	T.ok(offer.size() == pieces and only_pieces, "na wieszaku wisi %d ubrań na sztuki i ani jednego całego stroju" % offer.size())
	var lvl_keep := int(S.lvl)
	var cash_keep := float(S.cash)
	S.lvl = 1
	S.cash = 5000.0
	T.ok(not G.gear_buy("kurtka_kieszenie") and G.gear_buy("dresy"), "poziom 1: kurtki z kieszeniami jeszcze nie sprzedadzą, dresy tak")
	S.lvl = int(D.ITEMS.kurtka_kieszenie.lvl)
	T.ok(G.gear_buy("kurtka_kieszenie"), "na poziomie %d kurtka jest już do kupienia" % int(S.lvl))
	var top_lvl := 0
	for iid1 in D.ITEMS:
		if D.ITEMS[iid1].has("slot"):
			top_lvl = maxi(top_lvl, int(D.ITEMS[iid1].lvl))
	T.ok(top_lvl >= 4 and top_lvl <= 6, "najlepsze ubrania odblokowują się w środku gry (poziom %d)" % top_lvl)
	G.gear_wear("kominiarka") if G.gear_buy("kominiarka") else null
	T.ok(G.gear("glowa") == "kominiarka" and G.outfit_masked(), "kominiarka jako część garderoby maskuje tak samo jak dawny strój")
	G.gear_off("glowa")
	S.lvl = lvl_keep
	S.cash = cash_keep
	G.ui.inv.tab = "char"
	G.ui.inv.render()
	await T.frames(1)
	T.ok(G.ui.inv.rig_outfit == G.outfit(), "po wyjściu z szafy postać wraca do tego, co ma na sobie")
	G.ui.close_all()
	G.main.talk_clothes()
	await T.frames(2)
	T.ok(G.ui.mode == "dialog" and String(G.ui.dlg.lines[0].n) == "Pani Grażyna", "sprzedawczyni zagaduje przy ladzie")
	G.ui.close_all()
	# zapis
	var base: Dictionary = G.new_state()
	G._merge(base, JSON.parse_string(JSON.stringify(S)))
	T.ok(String(base.outfit) == "kominiarka" and base.outfits.has("garnitur") and base.outfits.has("biegacz"), "strój i szafa zapisują się")
	# ---------------------------------------------------------------- ubrania na sztuki: pola wokół postaci
	S.outfit = "dres"
	S.gear = {}
	S.lvl = 5
	S.cash = 2000.0
	S.inv = G.new_store()
	for k in S.items:
		S.items[k] = 0
	var gcap0: int = G.capacity()
	var gsp0: float = G.outfit_stat("speed", 1.0)
	T.ok(D.GEAR_SLOTS.size() == 6 and G.is_gear("bluza_kaptur") and not G.is_gear("woreczki"), "sześć pól ubioru; ubranie to przedmiot z polem")
	S.lvl = maxi(int(S.lvl), int(D.ITEMS.bluza_kaptur.lvl))
	var gcash0 := float(S.cash)
	T.ok(G.gear_buy("bluza_kaptur") and G.gear("gora") == "bluza_kaptur" and G.item("bluza_kaptur") == 0 and absf(S.cash - (gcash0 - float(D.ITEMS.bluza_kaptur.price))) < 0.01, "kupione ubranie ląduje od razu na postaci")
	T.ok(G.capacity() == gcap0 + 2 and G.carry_total() < 0.01, "bluza daje dwie kieszenie, a założona nic nie waży i nie zajmuje miejsca")
	T.ok(G.gear_buy("kurtka_kieszenie") and G.item("kurtka_kieszenie") == 1 and G.gear("gora") == "bluza_kaptur", "drugie ubranie na zajęte pole trafia do plecaka")
	T.ok(G.carry_total() > 0.9 and G.store_weight(S.inv) > 300.0 and G.store_weight(S.inv) < 500.0, "ubranie w plecaku waży mało (%d g)" % int(G.store_weight(S.inv)))
	T.ok(G.gear_wear("kurtka_kieszenie") and G.gear("gora") == "kurtka_kieszenie" and G.item("bluza_kaptur") == 1 and G.capacity() == gcap0 + 4, "przebranie: stara góra wraca do plecaka")
	S.items["buty_bieg"] = 1
	S.items["dresy"] = 1
	G.gear_wear("buty_bieg")
	G.gear_wear("dresy")
	var gsp1: float = G.outfit_stat("speed", 1.0)
	T.ok(gsp1 > gsp0 * 1.02 and gsp1 < gsp0 * 1.08, "ubrania zmieniają cechy, ale niewiele (szybkość %+d%%)" % int(round((gsp1 / gsp0 - 1.0) * 100.0)))
	var gworst := 1.0
	for gid in D.ITEMS:
		for sk in D.ITEMS[gid].get("stats", {}):
			if sk != "cap":
				gworst = maxf(gworst, maxf(float(D.ITEMS[gid].stats[sk]), 1.0 / float(D.ITEMS[gid].stats[sk])))
	T.ok(gworst <= 1.12, "żadne pojedyncze ubranie nie zmienia cechy o więcej niż 12%")
	T.ok(G.gear_off("buty") and G.gear("buty") == "" and G.item("buty_bieg") == 1, "zdjęte buty wracają do plecaka")
	T.ok(not G.gear_wear("woreczki") and not G.gear_wear("trampki"), "nie założysz czegoś, co nie jest ubraniem albo czego nie masz")
	T.ok(not G.worn_traits().is_empty(), "karta postaci podaje łączne cechy ubioru")
	# gotówka jako przedmiot
	S.cash = 500.0
	S.stash.safe.cash = 0.0
	var cash_e := {}
	for e in G.entries(S.inv):
		if String(e.kind) == "cash":
			cash_e = e
	T.ok(not cash_e.is_empty() and float(cash_e.n) == 500.0 and float(cash_e.size) == 0.0 and float(cash_e.weight) == 0.0, "gotówka jest w plecaku przedmiotem, który nic nie waży i nie zajmuje miejsca")
	T.ok(absf(G.move_entry("safe", cash_e, true, 200.0) - 200.0) < 0.01 and S.cash == 300.0 and float(S.stash.safe.cash) == 200.0, "gotówkę przenosi się do skrytki jak każdą rzecz")
	var st_cash := false
	for e in G.entries(S.stash.safe):
		if String(e.kind) == "cash" and float(e.n) == 200.0:
			st_cash = true
	T.ok(st_cash, "w skrytce gotówka też jest pozycją na liście")
	G.ui.open_inventory("safe")
	await T.frames(2)
	T.ok(G.ui.mode == "inv", "ekwipunek z polami ubioru otwiera się bez błędów")
	G.ui.close_all()
	var gbase: Dictionary = G.new_state()
	G._merge(gbase, JSON.parse_string(JSON.stringify(S)))
	T.ok(String(gbase.gear.get("gora", "")) == "kurtka_kieszenie" and int(gbase.items.get("bluza_kaptur", 0)) == 1, "założone ubrania i te w plecaku zapisują się")
	_cut_tests(T)
	G.S = keep
	G.main.teleport(back_loc, back_pos, 0.0)
	await T.frames(2)


## krój uszytych ubrań (assets/wear): każda rzecz ma wykrój, nogawki sięgają buta, rękawy nadgarstka, buty mają rozmiar buta,
## warianty kolorystyczne farbują tkaninę (a nie gumę i lampasy) i nic nie jest smoliście czarne
static func _wear_box(id: String) -> AABB:
	var ps: PackedScene = Chars._wear_load(id)
	var box := AABB()
	if ps == null:
		return box
	var inst: Node = ps.instantiate()
	var first := true
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (n as MeshInstance3D).mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	inst.free()
	return box


static func _cut_tests(T) -> void:
	var slots := {}
	for gs in D.GEAR_SLOTS:
		slots[String(gs[0])] = true
	var missing: Array = []
	var patterns := {}
	for id in D.ITEMS:
		var it: Dictionary = D.ITEMS[id]
		if not slots.has(String(it.get("slot", ""))):
			continue
		var gid := String(it.get("look", {}).get("model", id))
		patterns[gid] = String(it.slot)
		if Chars._wear_load(gid) == null:
			missing.append(id)
	T.ok(missing.is_empty() and patterns.size() >= 20, "każde ubranie ma swój wykrój w plikach (brak: %s)" % str(missing))
	var legs_bad: Array = []
	var tops_bad: Array = []
	var shoes_bad: Array = []
	for gid in patterns:
		var b := _wear_box(gid)
		match String(patterns[gid]):
			"spodnie":
				# nogawka kończy się przy bucie (nie nad kostką i nie w podłodze), pas powyżej bioder
				if b.position.y > 0.13 or b.position.y < 0.05 or b.end.y < 0.95:
					legs_bad.append("%s %.2f–%.2f" % [gid, b.position.y, b.end.y])
			"gora":
				# rękawy sięgają za nadgarstki (dłonie w pozie spoczynkowej są ok. 0,6 m od osi ciała), dół zakrywa pas spodni
				if b.size.x < 1.2 or b.position.y > 0.9:
					tops_bad.append("%s %.2f %.2f" % [gid, b.size.x, b.position.y])
			"buty":
				# para butów: podeszwa na ziemi, długość buta 27–33 cm, niskie do kostki, robocze za kostkę (ze skarpetą pod nogawką)
				if b.position.y < -0.005 or b.position.y > 0.02 or b.size.z < 0.27 or b.size.z > 0.34 or b.end.y > 0.3:
					shoes_bad.append("%s %.3f %.2f %.2f" % [gid, b.position.y, b.size.z, b.end.y])
	T.ok(legs_bad.is_empty(), "nogawki spodni sięgają buta (%s)" % str(legs_bad))
	T.ok(tops_bad.is_empty(), "rękawy sięgają za nadgarstki, a dół góry zakrywa pas (%s)" % str(tops_bad))
	T.ok(shoes_bad.is_empty(), "buty stoją na ziemi i mają rozmiar buta (%s)" % str(shoes_bad))
	# farbowanie wariantów
	var dye := Color("2a2b2f")
	var ps: PackedScene = Chars._wear_load("dresy")
	var inst: Node = ps.instantiate()
	var mesh: Mesh = (inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var main := Chars._main_color(mesh)
	var knit_ok := false
	var stripe_ok := false
	for sf in range(mesh.get_surface_count()):
		var src := mesh.surface_get_material(sf)
		var out := Chars._fabric_mat(src, dye, main) as BaseMaterial3D
		var nm := String(src.resource_name)
		if nm == "dzianina_dresy":
			knit_ok = absf(out.albedo_color.r - dye.r) < 0.02 and absf(out.albedo_color.b - dye.b) < 0.02
		if nm == "dzianina_lampas":
			stripe_ok = out.albedo_color.v > 0.8
	inst.free()
	T.ok(knit_ok and stripe_ok, "czarne dresy: tkanina dostaje barwę wariantu, białe lampasy zostają białe")
	ps = Chars._wear_load("buty_bieg")
	inst = ps.instantiate()
	mesh = (inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	main = Chars._main_color(mesh)
	var upper_ok := false
	var foam_ok := false
	for sf in range(mesh.get_surface_count()):
		var src2 := mesh.surface_get_material(sf)
		var out2 := Chars._fabric_mat(src2, Color("2c2c31"), main) as BaseMaterial3D
		if String(src2.resource_name) == "plotno_bieg":
			upper_ok = out2.albedo_color.s < 0.15 and out2.albedo_color.v < 0.3
		if String(src2.resource_name) == "guma_pianka":
			foam_ok = out2.albedo_color.v > 0.85
	inst.free()
	T.ok(upper_ok and foam_ok, "czarne buty do biegania: cholewka grafitowa (bez rudego odcienia), pianka podeszwy zostaje biała")
	var vanta: Array = []
	for gid in patterns:
		var ps3: PackedScene = Chars._wear_load(gid)
		var inst3: Node = ps3.instantiate()
		for n in inst3.find_children("*", "MeshInstance3D", true, false):
			var m3: Mesh = (n as MeshInstance3D).mesh
			for sf in range(m3.get_surface_count()):
				var fm := Chars._fabric_mat(m3.surface_get_material(sf))
				if fm is BaseMaterial3D and maxf((fm as BaseMaterial3D).albedo_color.r, maxf((fm as BaseMaterial3D).albedo_color.g, (fm as BaseMaterial3D).albedo_color.b)) < Models.BLACK_FLOOR - 0.001:
					vanta.append("%s/%s" % [gid, m3.surface_get_material(sf).resource_name])
		inst3.free()
	T.ok(vanta.is_empty(), "żadna tkanina nie jest smoliście czarna (%s)" % str(vanta))
