extends Node
## Autotest rozgrywki i symulator ekonomii. Bez okna i bez dźwięku:
##   Godot --headless --audio-driver Dummy --path . -- --autostart --test
##   Godot --headless --audio-driver Dummy --path . -- --autostart --test --sim=36

var fails := 0
var M
var U


func ok(cond: bool, what: String) -> void:
	if cond:
		print("TEST ok    ", what)
	else:
		fails += 1
		print("TEST FAIL  ", what)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func wait_busy() -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while G.busy and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame


## przeklikuje dialog; zatrzymuje się, gdy czeka on na wybór opcji
func skip_dialog() -> void:
	var guard := 0
	while U.mode == "dialog" and guard < 80:
		guard += 1
		var d: Dictionary = U.dlg
		if not d.is_empty() and d.done and int(d.i) == d.lines.size() - 1 and not d.choices.is_empty():
			return
		U.advance()
		await get_tree().process_frame


func _ready() -> void:
	M = G.main
	U = G.ui
	if M.args.has("sim"):
		sim(int(M.args.sim))
	else:
		run()


func pack_all(room: String, mode := 0) -> void:
	for s in G.bench_bulk(room):
		var left := int(floor(float(s.n) + 0.001))
		var guard := 0
		while left > 0 and guard < 60:
			guard += 1
			var n: int = mini(left, 20)
			var r: Dictionary = G.pack(room, s.p, int(s.pur), n, mode)
			if M.args.has("simdbg") and int(G.S.stats.pickups) <= 1:
				print("PACKDBG n=%d mode=%d wynik=%s waste=%.3f wasted=%d packed=%d bulk=%s paczki=%d/%d" % [n, mode, str(r), G.pack_waste(mode), int(G.S.stats.wasted), int(G.S.stats.packed), str(s), G.packed_total(G.S.inv), G.packed_total(G.S.stash.safe)])
			if int(r.packed) + int(r.lost) <= 0:
				break
			left -= int(r.packed) + int(r.lost)


# ================================================================ test funkcjonalny
func run() -> void:
	await frames(20)
	var S: Dictionary = G.S
	ok(G.running, "gra wystartowała")
	ok(S.cash == float(D.START_CASH) and S.debt == float(D.START_DEBT), "stan początkowy: gotówka i pełny wkład do zebrania")
	ok(G.client_count() == 0, "na starcie nie ma żadnego klienta")
	ok(G.world.wp.size() > 40, "graf ścieżek zbudowany (%d węzłów)" % G.world.wp.size())
	if U.mode == "dialog":
		await skip_dialog()
	U.close_all()

	# --- oprowadzenie po kawalerce: zapis przy laptopie, skrytka, waga
	ok(G.cur_step().id == "room_save", "samouczek zaczyna od pokoju, nie od paczki")
	ok(not G.S.chats.has("wiktor") or G.S.chats.wiktor.is_empty(), "Wiktor nie pisze o paczce przed obejrzeniem pokoju")
	var lap = null
	for it in G.world.inter:
		if String(it.get("id", "")) == "save_safe":
			lap = it
	ok(lap != null, "w kawalerce stoi laptop do zapisu gry")
	if lap != null:
		lap.act.call()
	G.story_tick()
	ok(G.flag("tut_save") and G.cur_step().id == "room_stash", "zapis przy laptopie zalicza pierwszy krok")
	# na start w kieszeni leży notes z numerami: samouczek każe przenieść go do szafy (samo otwarcie nie wystarcza)
	ok(G.item("notes") == 1 and absf(G.carry_total() - 1.0) < 0.01 and String(G.cur_step().text.call()).contains("notes"), "na start: notes z numerami w kieszeni, samouczek każe go schować")
	U.open_stash("safe")
	await frames(2)
	G.story_tick()
	ok(G.cur_step().id == "room_stash" and U.inv.room == "safe", "samo otwarcie szafy nie zalicza kroku")
	var note_e := {}
	for en0 in G.entries(S.inv):
		if String(en0.id) == "notes":
			note_e = en0
	ok(not note_e.is_empty() and G.move_entry("safe", note_e, true, 1.0) == 1.0 and G.item("notes") == 0 and int(G.store_items(S.stash.safe).get("notes", 0)) == 1, "notes przeciągnięty do szafy")
	U.close_all()
	G.story_tick()
	ok(G.cur_step().id == "room_bench" and G.carry_total() < 0.01, "krok ze skrytką zaliczony, kieszenie puste")
	U.open_pack("safe")
	await frames(2)
	U.close_all()
	G.story_tick()
	ok(G.cur_step().id == "phone" and G.flag("wiktor_sms"), "po oprowadzeniu Wiktor wysyła wiadomość o paczce")
	S = G.S
	# --- telefon: wiadomość od Wiktora
	U.open_phone("sms")
	await frames(3)
	U.phone.chat_id = "wiktor"
	U.phone.render()
	await frames(3)
	G.story_tick()
	ok(G.flag("read_wiktor"), "przeczytana wiadomość od Wiktora")
	for app in ["", "kontakty", "mapa", "portfel", "rozwoj", "zadania", "lokale", "ustawienia"]:
		U.phone.go(app)
		await frames(2)
	ok(U.mode == "phone", "wszystkie aplikacje telefonu się rysują")
	U.close_all()
	S = G.S

	# --- pierwsza paczka
	G.story_tick()
	var d = null
	G.world.refresh_starter()
	ok(G.world.starter != null and G.cur_step().id == "drop1", "paczka na start leży przy drzwiach kawalerki")
	# paczka otwiera się jednym naciśnięciem: ekwipunek, a po prawej jej zawartość do przeciągnięcia
	var st_i = null
	for it_s in G.world.inter:
		if String(it_s.get("id", "")) == "starter":
			st_i = it_s
	ok(st_i != null and not st_i.has("hold"), "paczka pod drzwiami: zwykłe naciśnięcie, bez przytrzymywania")
	st_i.act.call()
	await frames(3)
	ok(U.mode == "inv" and U.inv.room == "loot" and String(G.loot.get("kind", "")) == "starter" and G.goods_total(S.stash.loot) > 0.0, "paczka otwiera się jako prawa strona ekwipunku (%s g)" % str(G.goods_total(S.stash.loot)))
	ok(G.goods_total(S.inv) == 0.0 and not G.flag("got_first"), "samo otwarcie niczego nie zabiera")
	var le: Array = G.entries(S.stash.loot)
	ok(G.move_limit("loot", le[0], true) == 0.0, "do paczki nic się nie odkłada")
	ok(G.move_entry("loot", le[0], false, 2.0) == 2.0, "z paczki da się wziąć część (2 g)")
	U.close_all()
	await frames(2)
	ok(G.flag("got_first") and G.loot.is_empty() and G.goods_total(S.stash.loot) == 0.0, "po zamknięciu paczka jest rozliczona")
	var on_floor := 0.0
	for gr in S.get("ground", []):
		if String(gr.loc) == "safe":
			on_floor += float(gr.n)
	var pack_g := 0.0
	for e0 in D.STARTER_PACK:
		pack_g += float(e0[1])
	ok(absf(on_floor - (pack_g - 2.0)) < 0.01 and G.world.starter == null, "czego nie wziąłeś, leży dalej przy drzwiach (%s g)" % str(on_floor))
	# reszta z ziemi: znów jedno naciśnięcie i „Zabierz wszystko”
	var gi = null
	for it_g in G.world.inter:
		if String(it_g.get("id", "")).begins_with("ziemia_"):
			gi = it_g
	ok(gi != null and not gi.has("hold"), "rzeczy na ziemi też otwiera zwykłe naciśnięcie")
	gi.act.call()
	await frames(3)
	ok(U.mode == "inv" and String(G.loot.get("kind", "")) == "ground" and absf(G.goods_total(S.stash.loot) - on_floor) < 0.01, "ziemia: w oknie leży wszystko, co było obok siebie")
	ok(G.loot_take_all() >= 1 and G.goods_total(S.stash.loot) == 0.0, "„Zabierz wszystko” przenosi resztę do kieszeni")
	U.close_all()
	await frames(2)
	var still := 0
	for gr2 in S.get("ground", []):
		if String(gr2.loc) == "safe":
			still += 1
	ok(still == 0 and absf(G.goods_total(S.inv) - pack_g) < 0.01, "na podłodze nic nie zostało, cała paczka w kieszeniach")
	ok(not G.starter_pickup(), "paczkę spod drzwi bierze się raz")
	var start_g := 0.0
	for e in D.STARTER_PACK:
		start_g += float(e[1])
	ok(G.goods_total(S.inv) == start_g and float(S.credit) == 0.0 and float(S.inv.bulk["szron"].get("100", 0.0)) > 0.0, "na start czysta marihuana i amfetamina — pierwsza paczka jest za darmo (zeszyt %d zł)" % int(S.credit))
	ok(absf(G.carry_total() - start_g) < 0.01 and G.carry_total() <= float(G.capacity()) and G.capacity() >= 30, "paczka mieści się w kieszeniach (%s / %d)" % [str(G.carry_total()), G.capacity()])
	ok(G.credit_days() >= 7, "na początku Wiktor daje tydzień na spłatę zeszytu (%d dni)" % G.credit_days())
	# dalej test idzie jak dawniej z 5 g marihuany przy sobie — reszta paczki ląduje w szafie
	G.add_bulk(S.stash.safe, "szron", 100, G.take_bulk(S.inv, "szron", 100, 99.0))
	G.add_bulk(S.stash.safe, "dym", 100, G.take_bulk(S.inv, "dym", 100, start_g - 10.0 if start_g > 15.0 else maxf(0.0, float(S.inv.bulk["dym"].get("100", 0.0)) - 5.0)))
	ok(absf(G.carry_total() - 5.0) < 0.01, "zajęte miejsce: 5 g luzem = 5")

	# --- stół: porcjowanie
	M.enter("safe")
	await wait_busy()
	# interakcje wymagają nacelowania: drzwi wyjściowe są za plecami gracza
	var RS: Dictionary = D.ROOMS.safe
	M.teleport("safe", Vector3(float(RS.cx), 0.0, float(RS.d) * 0.5 - 1.5), 0.0)
	await frames(4)
	var it0 = M._find_interact()
	ok(it0 == null or String(it0.get("id", "")) != "exit_safe", "tyłem do drzwi nie ma podpowiedzi „Wyjdź”")
	M.teleport("safe", Vector3(float(RS.cx), 0.0, float(RS.d) * 0.5 - 1.5), PI)
	await frames(4)
	var it1 = M._find_interact()
	ok(it1 != null and String(it1.get("id", "")) == "exit_safe", "po nacelowaniu na drzwi można wyjść (kanapa ich nie zasłania)")
	M.teleport("safe", Vector3(float(RS.cx) - 0.6, 0.0, 1.2), 0.0)
	await frames(2)
	U.open_pack("safe")
	await frames(3)
	ok(U.mode == "modal", "stół roboczy otwarty")
	# stół roboczy: animowana robota gram po gramie (w teście przyspieszona)
	var t_before: float = S.t
	ok(G.scale() == 0 and G.pack_waste() == 0.0, "pierwsze gramy w życiu zawsze się udają (samouczek nie może stracić towaru)")
	var packed_keep: int = S.stats.packed
	S.stats.packed = 50
	var w0: float = G.pack_waste()
	var pm0: float = G.pack_minutes()
	ok(w0 > 0.0 and w0 < 0.12, "waga kuchenna: zawsze coś się rozsypie (%.0f%%)" % (w0 * 100.0))
	var cash_keep: float = S.cash
	var lvl_keep: int = S.lvl
	S.cash = 100.0
	ok(G.scale_block(1) != "" and not G.scale_buy(1), "na wagę jubilerską trzeba mieć pieniądze i poziom")
	S.cash = 20000.0
	S.lvl = 2
	ok(G.scale_buy(1) and G.scale() == 1 and absf(S.cash - (20000.0 - 650.0)) < 0.01, "lombard: waga jubilerska kupiona za 650 zł")
	ok(G.pack_waste() < w0 and G.pack_minutes() < pm0, "lepsza waga: mniej strat i szybsza robota")
	ok(not G.scale_buy(1) and not G.scale_buy(0) and not G.scale_buy(3), "tej samej, gorszej ani za wysokiej poziomem wagi nie kupisz")
	S.lvl = 8
	ok(G.scale_buy(3) and G.pack_waste() == 0.0 and G.pack_minutes() <= 0.11, "waga z dozownikiem: bez strat, sześć sekund gry na gram")
	var prev_w := 1.0
	var prev_m := 99.0
	var mono := true
	for sc in D.SCALES:
		if float(sc.waste) > prev_w or float(sc.min) >= prev_m:
			mono = false
		prev_w = float(sc.waste)
		prev_m = float(sc.min)
	ok(mono, "każda następna waga jest szybsza i nie gubi więcej niż poprzednia")
	# rysunek wagi w oknie stołu zmienia się z klasą: każda musi się narysować bez błędów
	for tier in range(D.SCALES.size()):
		U.bench.view.scale_tier = tier
		U.bench.view.reading = 0.62
		U.bench.view.queue_redraw()
		await frames(2)
	ok(U.bench.view.SCALE_LOOK.size() == D.SCALES.size(), "każda klasa wagi ma swój wygląd na blacie")
	U.bench.view.reading = 0.0
	U.bench.view.scale_tier = 0
	var top_scale: Node3D = null
	for sp in G.world.scale_spots:
		if is_instance_valid(sp.node):
			top_scale = sp.node
	ok(top_scale != null and top_scale.get_child_count() > 0 and G.world.scale_spots.size() >= 1, "po zakupie na stole staje model nowej wagi (%d stołów)" % G.world.scale_spots.size())
	S["scale"] = 0
	G.world.refresh_scales()
	S.cash = cash_keep
	S.lvl = lvl_keep
	S.stats.packed = packed_keep
	var lim0: int = G.pack_limit("safe", "dym", 100)
	G.add_bulk(S.stash.safe, "dym", 100, 4.0)
	ok(G.pack_limit("safe", "dym", 100) == lim0 + 4, "stół liczy towar z kieszeni i ze skrytki razem (%d → %d g)" % [lim0, lim0 + 4])
	G.add_bulk(S.inv, "dym", 100, G.take_bulk(S.stash.safe, "dym", 100, 4.0) - 4.0)
	var bv = U.bench.view
	var got := [-1, -1]
	bv.start(3, 0, 0.9, func() -> int: return G.pack_one("safe", "dym", 100), func(a: int, b: int): got[0] = a; got[1] = b)
	var bg := 0
	while got[0] < 0 and bg < 400:
		bg += 1
		await frames(1)
	ok(got[0] == 3 and got[1] == 0 and G.item("woreczki") == 0, "zaporcjowane 3 g — bez woreczków i bez wybierania trybu")
	ok(S.t - t_before >= 3.5, "porcjowanie zabiera czas gry (%.0f min)" % (S.t - t_before))
	ok(G.pack_one("safe", "dym", 35) == -1, "nie da się porcjować towaru, którego nie ma")
	# wspólna pula: stół widzi luz i porcje z kieszeni i ze skrytki jako jedną pozycję
	var pool_e := {}
	for pe in G.bench_pool("safe"):
		if String(pe.p) == "dym" and int(pe.pur) == 100:
			pool_e = pe
	var loose0: float = float(S.inv.bulk.dym.get("100", 0.0)) + float(S.stash.safe.bulk.dym.get("100", 0.0))
	ok(not pool_e.is_empty() and int(pool_e.k) == 3 and absf(float(pool_e.n) - loose0) < 0.01, "pula przy stole: %s g luzem + %d porcje w jednym wierszu" % [str(pool_e.get("n", 0)), int(pool_e.get("k", 0))])
	ok(G.unpack("safe", "dym", 100, 2) == 2 and G.packed_total(S.inv, "dym") + G.packed_total(S.stash.safe, "dym") == 1, "porcje da się rozsypać z powrotem (2 z 3)")
	ok(absf(float(S.inv.bulk.dym.get("100", 0.0)) + float(S.stash.safe.bulk.dym.get("100", 0.0)) - (loose0 + 2.0)) < 0.01, "…i wracają do towaru luzem")
	G.pack("safe", "dym", 100, 2)
	U.close_all()
	G.story_tick()
	G.story_tick()
	ok(S.cust.dominik.unlocked and S.orders.size() == 1, "Dominik pisze pierwsze zamówienie")

	# --- mini-gra z wagą
	var hits_got := [-1]
	U.skill_check("Test wagi", 1.0, func(h): hits_got[0] = h)
	await frames(3)
	for i in range(3):
		U._skill_press()
		await frames(50)
	var guard := 0
	while hits_got[0] < 0 and guard < 200:
		guard += 1
		await frames(1)
	ok(hits_got[0] >= 0, "mini-gra z wagą kończy się wynikiem (%d/3)" % hits_got[0])
	U.close_all()

	# --- SMS: zgoda, klient idzie na spotkanie
	var o: Dictionary = S.orders[0]
	U.open_phone("sms")
	U.phone.chat_id = "dominik"
	U.phone.render()
	await frames(3)
	U.close_all()
	G.reply_order(o.id, "accept")
	ok(o.status == "accepted" and o.agreed != null, "zamówienie przyjęte po cenie klienta (%s zł/g)" % str(o.agreed))
	ok(float(o.meet) - S.t > 50.0 and float(o.meet) - S.t < 70.0, "spotkanie wypada ok. godzinę po potwierdzeniu (%d min)" % int(float(o.meet) - S.t))
	ok(G.npcs.customers.size() == 1, "klient zaplanowany na spotkanie")
	ok(G.npcs.customers[0].node == null, "klient jeszcze nie wyszedł z domu")
	# pojawia się na krótko przed umówioną godziną i idzie pieszo
	G.add_minutes(maxf(0.0, float(o.meet) - S.t - 2.0))
	await frames(30)
	var cn: Dictionary = G.npcs.customers[0]
	ok(cn.node != null, "klient wyszedł z domu przed spotkaniem")
	G.add_minutes(maxf(0.0, float(o.meet) - S.t))
	# przenieś klienta na miejsce i podejdź
	if cn.node == null:
		G.npcs._customer_enter(cn, true)
	cn.state = "wait"
	cn.x = cn.goal.x
	cn.z = cn.goal.y
	cn.node.position = Vector3(cn.x, G.world.height(cn.x, cn.z), cn.z)
	M.exit_room()
	await wait_busy()
	M.teleport("out", Vector3(cn.x + 1.5, 0, cn.z), 0.0)
	await frames(10)
	var cash0: float = S.cash
	G.npcs.deal_with_customer(cn)
	await frames(5)
	ok(not U.deal.is_empty() and U.mode == "modal", "rozmowa z klientem otwarta")
	if not U.deal.is_empty():
		U.deal.cop = null
		U.deal.cop_t = 0.0
		ok(int(U.deal.base) == int(o.agreed) and int(U.deal.pct) == 0 and G.deal_read(U.deal, 0) == "sure", "wymiana zaczyna się od umówionej ceny — bez przywitań i gadek")
		ok(not G.deal_set(U.deal, 15) == false and int(U.deal.price) > int(o.agreed) and G.deal_set(U.deal, 0), "cenę można lekko podbić albo wrócić do umówionej")
		# podanie towaru: przytrzymanie napełnia pasek, puszczenie go cofa
		U.deal_holding = true
		await frames(6)
		var held: float = U.deal.hold
		U.deal_holding = false
		await frames(40)
		ok(held > 0.0 and float(U.deal.hold) == 0.0 and not U.deal.over, "puszczony przycisk cofa podanie (%.2f → 0)" % held)
		U.deal_holding = true
		var hg := 0
		while not U.deal.over and hg < 400:
			hg += 1
			await frames(1)
		ok(U.deal.sold, "przytrzymanie do końca = towar podany, pieniądze w kieszeni")
		await frames(3)
	ok(S.cash > cash0 and int(S.stats.deals) == 1, "sprzedaż po umówionej cenie (+%d zł)" % int(S.cash - cash0))
	ok(int(S.stats.sold) == 2, "pierwsze zamówienie Dominika to zawsze 2 g")
	U.close_all()
	await frames(5)

	# --- zeszyt
	ok(not G.flag("hurt_on") and G.Market.cart_block([{"p": "dym", "g": 5}]) != "", "przed pierwszą wpłatą Wiktor nie przyjmuje zamówień")
	S.cash = maxf(S.cash, float(S.credit) + 50.0)
	var debt0: float = S.debt
	var cash1: float = S.cash
	var owed0: float = S.credit
	M.open_box()
	await frames(3)
	ok(U.mode == "inv" and U.inv.room == "wiktor" and G.move_limit("wiktor", {"kind": "bulk", "p": "dym", "pur": 100, "n": 2.0, "usize": 1.0}, true) == 0.0, "skrzynka Wiktora otwiera się jak skrytka, ale przyjmuje tylko gotówkę")
	S.cash += 200.0
	cash1 = S.cash
	var rate0: float = 100.0
	G.move_cash("wiktor", true, owed0 + rate0 + 20.0)
	U.close_all()
	await frames(2)
	ok(float(S.credit) <= 0.0 and absf(S.debt - (debt0 - rate0 - 20.0)) < 0.01 and absf(S.cash - (cash1 - owed0 - rate0 - 20.0)) < 0.01 and float(S.stash.wiktor.cash) < 0.01, "pieniądze ze skrzynki: najpierw zeszyt, cała nadwyżka na wkład")
	G.story_tick()
	G.story_tick()
	ok(float(S.credit) <= 0.0 and G.flag("hurt_on"), "zeszyt spłacony, zamówienia odblokowane")
	# zamówienie: rozmowa z Wiktorem → telefon kładzie się na bok → koszyk
	U.open_phone("sms")
	U.phone.chat_id = "wiktor"
	U.phone.render()
	await frames(2)
	U.phone.shop_open()
	await frames(2)
	ok(U.phone.app == "sklep" and U.phone._landscape, "„Zamów towar” obraca telefon na bok i otwiera sklep")
	var cat: Array = G.Market.catalog()
	ok(cat.size() == 4 and cat[0].open and cat[1].open and not cat[2].open and not cat[3].open, "w sklepie od początku marihuana i amfetamina, reszta odblokuje się z poziomem")
	G.Market.cart_add(U.phone.shop.cart, "dym", 5)
	G.Market.cart_add(U.phone.shop.cart, "szron", 5)
	U.phone.render()
	await frames(2)
	ok(U.phone.shop.cart.size() == 2 and G.Market.cart_cost(U.phone.shop.cart) == G.wholesale_price("dym", 5) + G.wholesale_price("szron", 5), "koszyk liczy cenę obu pozycji")
	var credit0: float = S.credit
	U.phone.shop_send()
	await frames(2)
	ok(S.drops.size() == 1 and U.phone.app == "sms" and not U.phone._landscape and U.phone.shop.cart.is_empty(), "zamówienie wysłane: telefon wraca do rozmowy z Wiktorem")
	U.close_all()
	ok(float(S.credit) == credit0 and G.ready_drop() == null, "nic nie płacisz z góry, paczka nie jest gotowa od razu")
	G.add_minutes(100.0)
	d = G.ready_drop()
	ok(d != null and int(d.pur) == 100 and (d.items as Array).size() == 2, "paczka gotowa po ok. godzinie, towar czysty")
	if d != null:
		var cost_d: float = d.cost
		var inv_keep: Dictionary = S.inv
		S.inv = G.new_store()
		ok(G.pickup_drop(d) and float(S.credit) == credit0 + cost_d and float(S.inv.bulk["szron"].get("100", 0.0)) >= 5.0, "odbiór: obie pozycje w plecaku, należność na zeszycie")
		S.inv = inv_keep
		S.credit = 0.0
	ok(G.order_goods("dym", 5, false, true), "zamówienie 5 g u Wiktora na zeszyt")
	ok(G.ready_drop() == null, "paczka nie jest gotowa od razu")
	G.add_minutes(100.0)
	d = G.ready_drop()
	ok(d != null, "paczka gotowa po ok. godzinie")
	if d != null:
		G.pickup_drop(d)

	# --- sklep i mieszanie
	S.cash += 100.0
	ok(G.shop_buy("majeranek"), "zakup majeranku w spożywczym")
	ok(G.item("majeranek") == 20, "majeranek w plecaku (zajmuje miejsce)")
	var before := G.goods_total(S.inv) + G.goods_total(S.stash.safe)
	var src = null
	for s in G.bench_bulk("safe"):
		if s.p == "dym":
			src = s
	ok(src != null, "jest towar luzem do rozrobienia")
	if src != null:
		var np: int = G.mix("safe", "dym", int(src.pur), float(src.n), 4)
		ok(np < int(src.pur), "mieszanie obniża czystość (%d%% → %d%%)" % [int(src.pur), np])
		ok(absf(G.goods_total(S.inv) + G.goods_total(S.stash.safe) - before - 4.0) < 0.2, "mieszanka waży o 4 g więcej")

	# --- samouczek nie zakleszcza się, gdy pierwszy towar przepadł
	var tut_S: Dictionary = G.S
	G.S = G.new_state()
	G.S.flags["got_first"] = true
	G.S.stats.packed = 2
	G.S.stats.wasted = 3
	G.add_pack(G.S.inv, "dym", 80, 2)
	ok(G._tutorial_dry(), "samouczek widzi, że towaru luzem już nie ma")
	G.S.step = 0
	var pack_i := -1
	var sell_i := -1
	for i in range(G.story.size()):
		if String(G.story[i].get("id", "")) == "pack1":
			pack_i = i
		if String(G.story[i].get("id", "")) == "sell1":
			sell_i = i
	ok(pack_i >= 0 and G.story[pack_i].done.call(), "krok „zaporcjuj 3 g” zalicza się, gdy z pierwszej paczki zostały tylko 2 porcje")
	ok(not G.story[sell_i].done.call(), "krok sprzedaży czeka, dopóki są porcje do sprzedania")
	G.take_pack(G.S.inv, "dym", 80, 2)
	ok(G.story[sell_i].done.call(), "…a gdy towar przepadł całkiem, samouczek idzie dalej")
	G.on_hour()
	ok(G.flag("hurt_on"), "bez towaru i bez Hurtu Wiktor sam otwiera zamówienia")
	G.S.cash = 0.0
	G.add_bulk(G.S.inv, "dym", 80, 5.0)
	ok(G.pack_limit("safe", "dym", 80) == 5 and G.pack_one("safe", "dym", 80) >= 0, "spłukany też porcjuje: do roboty wystarcza waga, niczego nie trzeba dokupować")
	G.S = tut_S

	# --- mieszanki nigdy nie układają się w jeden stos z czystym towarem
	var keep_inv: Dictionary = S.inv
	var keep_safe: Dictionary = S.stash.safe
	var keep_items: Dictionary = S.items.duplicate()
	S.inv = G.new_store()
	S.stash.safe = G.new_store()
	var both: Array = [S.inv, S.stash.safe]
	S.items["majeranek"] = 400
	var mix_ok := true
	var mix_seen := 0
	for base in [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50]:
		for fg in [1, 2, 3, 5, 8]:
			G.add_bulk(S.stash.safe, "dym", base, 12.0)
			var np: int = G.mix("safe", "dym", base, 12.0, fg)
			mix_seen += 1
			if not G.is_mix(np) or np % 5 == 0 or G.qpure(np) == np or G.qpur(np) != np:
				mix_ok = false
	ok(mix_ok, "każda mieszanka dostaje znacznik (%d prób) i nie zaokrągla się do czystego kroku" % mix_seen)
	var pure_g := 0.0
	var mixed_g := 0.0
	for st0 in both:
		for k in st0.bulk.dym:
			if G.is_mix(int(k)):
				mixed_g += float(st0.bulk.dym[k])
			else:
				pure_g += float(st0.bulk.dym[k])
	ok(pure_g < 0.01 and mixed_g > 100.0, "po mieszaniu nic nie trafia do „czystych” stosów (mieszanek %d g)" % int(mixed_g))
	# czysty towar o podobnej mocy leży osobno
	G.add_bulk(S.stash.safe, "dym", 75, 7.0)
	ok(absf(float(S.stash.safe.bulk.dym.get("75", 0.0)) - 7.0) < 0.01, "czyste 75% nie zlało się z mieszanką 72/77%")
	# ponowne rozrabianie mieszanki dalej daje mieszankę
	var anyk := 0
	for k in S.stash.safe.bulk.dym:
		if G.is_mix(int(k)) and float(S.stash.safe.bulk.dym[k]) >= 6.0 and int(k) > anyk:
			anyk = int(k)
	var again: int = G.mix("safe", "dym", anyk, 6.0, 2)
	ok(anyk > 0 and G.is_mix(again) and again < anyk, "rozrobiona mieszanka dalej jest mieszanką (%d%% → %d%%)" % [anyk, again])
	# porcjowanie zachowuje znacznik, a woreczki z mieszanki nie mieszają się z czystymi
	G.pack("safe", "dym", again, 3)
	G.pack("safe", "dym", 75, 3)
	var packs_pure := 0
	var packs_mix := 0
	var stack_n := 0
	for st0 in both:
		for st2 in G.stacks(st0, "pack"):
			if G.is_mix(int(st2.pur)):
				packs_mix += int(st2.n)
			else:
				packs_pure += int(st2.n)
		stack_n += G.stacks(st0, "pack").size() + G.stacks(st0, "bulk").size()
	ok(packs_mix >= 1 and packs_pure >= 1 and packs_mix + packs_pure <= 6, "porcje: mieszanka (%d) i czysty (%d) w osobnych stosach" % [packs_mix, packs_pure])
	var labels := 0
	for st0 in both:
		for e2 in G.entries(st0):
			if e2.kind != "item" and e2.kind != "cash":
				labels += 1
	ok(labels == stack_n and labels >= 4, "ekwipunek pokazuje każdy stos osobno (%d pozycji)" % labels)
	# zapis i odczyt nie gubi znacznika
	var mjs = JSON.parse_string(JSON.stringify(S.stash.safe))
	var lost_mark := false
	for k in mjs.bulk.dym:
		if not S.stash.safe.bulk.dym.has(k):
			lost_mark = true
	ok(not lost_mark and mjs.bulk.dym.size() == S.stash.safe.bulk.dym.size(), "znacznik mieszanki przechodzi przez zapis gry")
	S.inv = keep_inv
	S.stash.safe = keep_safe
	S.items = keep_items

	# --- ekwipunek: przenoszenie do skrytki, zakładki
	M.enter("safe")
	await wait_busy()
	U.open_inventory("safe")
	await frames(4)
	ok(U.mode == "inv" and U.inv.visible, "ekwipunek otwarty ze skrytką")
	var ents: Array = G.entries(S.inv)
	ok(ents.size() >= 2, "plecak ma pozycje z rozmiarem i wagą")
	var tot0 := G.carry_total()
	for e in ents:
		if e.kind == "item" and e.id == "majeranek":
			G.move_entry("safe", e, true, 1e9)
	ok(G.item("majeranek") == 0 and int(G.store_items(S.stash.safe).get("majeranek", 0)) == 16, "majeranek przeniesiony do skrytki")
	ok(G.carry_total() < tot0, "w plecaku zwolniło się miejsce")
	for t in ["char", "org", "inv"]:
		U.inv.tab = t
		U.inv.render()
		await frames(3)
	U.close_all()
	ok(G.item_at("safe", "majeranek") == 16, "stół widzi majeranek ze skrytki")
	pack_all("safe")
	ok(G.packed_total(S.inv) + G.packed_total(S.stash.safe) >= 6, "wszystko zaporcjowane")

	# --- telefon: negocjacja ceny i zmiana godziny
	S.orders.clear()
	G.npcs.clear_customers()
	var o2: Dictionary = G.make_order(G.cust_def("dominik"))
	G.reply_order(o2.id, "price", int(o2.stated) + 1)
	ok(G.find_order(o2.id) != null, "negocjacja przez telefon nie zrywa rozmowy przy +1 zł")
	var o3 = G.find_order(o2.id)
	if o3 != null and o3.status == "new" and o3.counter != null:
		G.reply_order(o3.id, "counterok")
	o3 = G.find_order(o2.id)
	if o3 != null and o3.status == "new":
		G.reply_order(o3.id, "accept")
	o3 = G.find_order(o2.id)
	ok(o3 != null and o3.status == "accepted", "zamówienie umówione")
	if o3 != null:
		var m0: float = o3.meet
		var tries := 0
		while float(o3.meet) == m0 and tries < 12 and G.find_order(o3.id) != null:
			tries += 1
			o3.resched = false
			G.reply_order(o3.id, "time", m0 + 60.0)
		ok(float(o3.meet) == m0 + 60.0, "zmiana godziny spotkania")
		G.reply_order(o3.id, "decline")
		ok(G.find_order(o3.id) == null, "odwołanie spotkania")

	# --- „Zaraz wracam”: klient czeka, zamówienie zostaje; „Rezygnuję” je odwołuje
	S.orders.clear()
	G.npcs.clear_customers()
	G.add_pack(S.inv, "dym", 80, 6)
	var op: Dictionary = G.make_order(G.cust_def("dominik"))
	G.reply_order(op.id, "accept")
	var whop: Dictionary = G.cust_def("dominik").duplicate()
	whop["st"] = S.cust.dominik
	var dp: Dictionary = G.deal_start({"who": whop, "product": "dym", "grams": int(op.grams), "order": op, "street": false, "agreed": op.agreed})
	dp.tol = 3.0
	G.deal_set(dp, 15)
	G.deal_hand(dp)
	ok(not dp.over and dp.pushed and int(dp.pct) == 0 and not G.deal_set(dp, 5), "za wysoka cena: klient odmawia, wraca cena umówiona i drugi raz podbić się nie da")
	G.deal_pause(dp)
	ok(G.find_order(op.id) != null and op.has("hold"), "„Zaraz wracam”: zamówienie nie przepada")
	var dp2: Dictionary = G.deal_start({"who": whop, "product": "dym", "grams": int(op.grams), "order": op, "street": false, "agreed": op.agreed})
	ok(dp2.pushed, "po powrocie klient pamięta, że już próbowałeś podbić cenę")
	G.deal_cancel(dp2)
	ok(G.find_order(op.id) == null, "„Rezygnuję” odwołuje transakcję")
	G.take_pack(S.inv, "dym", 80, 99)

	# --- ilości: gramy w połówkach, sztuki całe, miejsce w połówkach
	var tmp: Dictionary = G.new_store()
	G.add_bulk(tmp, "dym", 75, 3.7)
	ok(absf(G.goods_total(tmp) - 3.5) < 0.001, "towar luzem zaokrągla się do połówek grama (3,7 → 3,5)")
	ok(G.grams(3.5) == "3,5 g" and G.grams(10.0) == "10 g" and G.units(1.7) == "2", "zapis ilości: 3,5 g, 10 g, miejsce 2")

	# --- policjant widzi do przodu i trochę na boki, ale nie za plecami
	var NS = G.npcs.get_script()
	ok(NS.sight(0.0) == 1.0 and NS.sight(1.2) > 0.0 and NS.sight(1.2) < 1.0 and NS.sight(2.4) == 0.0, "pole widzenia policji: przód tak, boki słabiej, tył wcale")

	# --- skradanie: widoczność, wzrok i słuch patroli, odciąganie, przeczesywanie, kryjówki
	await load("res://scripts/stealth_test.gd").run(self)

	# --- doświadczony klient rozpoznaje mieszankę
	var rejected := 0
	for i in range(40):
		var who: Dictionary = G.cust_def("kasia").duplicate()
		who["st"] = {"sat": 60.0, "loy": 50.0, "hunger": 0.5, "grams": 60, "deals": 20, "known": {}, "owes": 0.0}
		G.add_pack(S.inv, "dym", 40, 3)
		var dd: Dictionary = G.deal_start({"who": who, "product": "dym", "grams": 2, "order": null, "street": false, "agreed": 40})
		for st in G.stacks(S.inv, "pack"):
			if int(st.pur) == 40:
				dd.sel = st
		if i == 0:
			ok(int(dd.price) == 40 and G.market_price("dym", 40) == G.market_price("dym", 100), "mieszanka kosztuje tyle samo, co czysty towar")
		G.deal_hand(dd)
		if dd.over and not dd.sold:
			rejected += 1
		G.take_pack(S.inv, "dym", 40, 99)
	ok(rejected >= 30, "mocno rozrobionego towaru doświadczony klient nie bierze (%d/40 prób)" % rejected)
	# lekko rozrobiony towar: klient bierze, ale bywa niezadowolony
	var meh := 0
	var sat_sum := 0.0
	for i in range(40):
		var who2: Dictionary = G.cust_def("kasia").duplicate()
		who2["st"] = {"sat": 60.0, "loy": 50.0, "hunger": 0.5, "grams": 60, "deals": 20, "known": {}, "owes": 0.0}
		G.add_pack(S.inv, "dym", 62, 3)
		var d6: Dictionary = G.deal_start({"who": who2, "product": "dym", "grams": 2, "order": null, "street": false, "agreed": 40})
		G.deal_hand(d6)
		if d6.sold and float(who2.st.sat) < 60.0:
			meh += 1
		sat_sum += float(who2.st.sat)
		G.take_pack(S.inv, "dym", 62, 99)
	ok(meh >= 4 and meh < 40, "towar tuż poniżej oczekiwań: sprzedaje się, ale część klientów jest niezadowolona (%d/40)" % meh)

	# --- umiejętności, wyposażenie
	S.lvl = 5
	S.sp = 3
	S.cash = 30000.0
	ok(G.learn_skill("reka2") and G.deal_hand_time() < 1.0, "nauka umiejętności: szybka wymiana skraca podanie towaru")
	var sk_names := []
	for sk0 in D.SKILLS:
		sk_names.append(String(sk0.id))
	ok(not sk_names.has("gadka") and not sk_names.has("rekin") and sk_names.has("kieszenie") and sk_names.has("klientela"), "drzewko nie ma już umiejętności „gadanych”")
	ok(G.upgrade_buy("plecak1") and G.capacity() == 60 and G.capacity() >= D.CAP_BASE * 2, "plecak szkolny: 60 miejsc — dwa razy tyle co kieszenie")
	U.open_shop()
	await frames(3)
	U.close_all()

	# --- kryjówka, meble, uprawa
	ok(G.buy_property("garaz"), "kupno garażu")
	M.exit_room()
	await wait_busy()
	M.enter("garage")
	await wait_busy()
	ok(G.player.loc == "garage", "wejście do garażu")
	ok(G.stash_cap("garage") == 0, "pusty garaż nie ma skrytki")
	# sprzęt: najpierw hurtownia (rzecz trafia na stan), potem ustawienie w kryjówce, dopiero potem działa
	var sup_i = null
	for it_h in G.world.inter:
		if String(it_h.get("id", "")) == "hurtownia":
			sup_i = it_h
	ok(sup_i != null and absf(float(sup_i.x) - float(D.SUPPLY_AT.x)) < 0.5 and absf(float(sup_i.z) - float(D.SUPPLY_AT.z)) < 0.5, "hurtownia budowlana stoi przy Hutniczej i ma swoje okienko")
	var cash_f: float = S.cash
	var lvl_f: int = S.lvl
	S.cash = 100.0
	ok(not G.furn_place("garage", "stol", -1.6, -3.6, 0), "mebla, którego nie masz na stanie, nie ustawisz")
	ok(G.furn_block("stol") != "" and not G.furn_buy("stol"), "bez pieniędzy hurtownia nie sprzeda")
	S.cash = 9000.0
	S.lvl = 1
	ok(G.furn_block("lab").contains("poziom") and not G.furn_buy("lab"), "stół laboratoryjny dopiero od wyższego poziomu")
	ok(G.furn_buy("stol") and G.owned("stol") == 1 and absf(S.cash - (9000.0 - float(G.furn_def("stol").price))) < 0.01 and not G._has_furn("garage", "pack"), "kupiony stół czeka na stanie — jeszcze nie działa")
	var cash_p: float = S.cash
	ok(G.furn_place("garage", "stol", -1.6, -3.6, 0) and G.owned("stol") == 0 and S.cash == cash_p and G._has_furn("garage", "pack"), "ustawienie nic nie kosztuje, a stół zaczyna działać")
	U.open_supply()
	await frames(3)
	ok(U.mode == "modal", "okno hurtowni się rysuje")
	U.close_all()
	S.cash = cash_f + float(G.furn_def("stol").price)
	S.lvl = lvl_f
	var placed := 1
	for fd in [["regal", 2.3, -3.9], ["lampa_led", 2.0, -1.2], ["kanapa", -2.4, 0.6, 1]]:
		var rot: int = fd[3] if fd.size() > 3 else 0
		if G.furn_buy_place("garage", fd[0], fd[1], fd[2], rot):
			placed += 1
	G.world.refresh_furniture("garage")
	await frames(5)
	ok(placed == 4, "wstawione 4 meble (%d)" % placed)
	ok(G.stash_cap("garage") == 150, "regał daje skrytkę na 150 miejsc")
	U.open_build("garage")
	await frames(3)
	U.close_all()
	S.owned["krzeslo"] = 1
	M.build_begin("krzeslo")
	await frames(10)
	ok(M.build_active(), "tryb meblowania aktywny")
	S.owned.erase("krzeslo")
	M.build_cancel()
	G.story_tick()
	G.story_tick()
	# --- produkcja: uprawa, suszenie, synteza, ryzyko nalotu
	await load("res://scripts/production_test.gd").run(self)
	U.open_inventory("garage")
	await frames(3)
	U.close_all()

	# --- sen, pogoda, kolejka
	await M._do_sleep(60.0)
	ok(not G.busy, "sen kończy się poprawnie")
	G.world.tick_train(0.5, 0.0)
	G.world.train.wait = 0.0
	G.world.tick_train(0.5, 1.0)
	G.world.tick_train(0.5, 1.0)
	ok(G.world.train.active, "kolejka rusza po estakadzie")

	# --- ruch gracza i przechodnie
	M.exit_room()
	await wait_busy()
	M.teleport("out", Vector3(0.0, 0.0, 20.0 * D.SC), 0.0)
	await frames(5)
	var p0: Vector3 = G.player.global_position
	Input.action_press("ui_accept")
	Input.action_release("ui_accept")
	var c0: Array = []
	for cz in G.npcs.citizens:
		c0.append(Vector2(cz.x, cz.z))
	await frames(120)
	var moved := 0
	for ci in range(G.npcs.citizens.size()):
		if Vector2(G.npcs.citizens[ci].x, G.npcs.citizens[ci].z).distance_to(c0[ci]) > 0.2:
			moved += 1
	ok(moved >= 2, "przechodnie chodzą po mieście (%d w ruchu)" % moved)
	var path: Array = M.nav.find(p0.x, p0.z, float(D.SPOTS[0].x), float(D.SPOTS[0].z))
	ok(path.size() >= 2, "nawigacja znajduje trasę (%d punktów)" % path.size())
	var pb: Array = M.nav.path_between(Vector2(float(D.HOMES.blok5.x), float(D.HOMES.blok5.z)), Vector2(float(D.SPOTS[3].x), float(D.SPOTS[3].z)))
	ok(pb.size() >= 3, "klient ma drogę z domu na spotkanie (%d punktów)" % pb.size())

	# --- policja: wyrzucenie towaru, zatrzymanie
	G.add_pack(S.inv, "dym", 75, 4)
	ok(G.ditch_goods() and G.carry_goods() < 0.01, "wyrzucenie towaru w pościgu")
	G.arrest(null)
	await frames(3)
	await skip_dialog()
	await frames(3)
	ok(not G.arresting or U.mode == "dialog", "kontrola bez towaru kończy się puszczeniem wolno")
	if U.mode == "dialog":
		await skip_dialog()
	U.close_all()
	G.arresting = false
	G.add_pack(S.inv, "dym", 75, 4)
	var arrests0 := int(S.arrests)
	G.arrest(null)
	await frames(3)
	await skip_dialog()
	if U.mode == "dialog":
		U.pick_choice(0)
	await wait_busy()
	await frames(5)
	if U.mode == "dialog":
		await skip_dialog()
	await wait_busy()
	ok(int(S.arrests) == arrests0 + 1 and G.carry_goods() < 0.01, "zatrzymanie: towar przepada, licznik rośnie")
	U.close_all()
	G.arresting = false

	# --- zapis i odczyt (bez dotykania prawdziwego pliku zapisu)
	S.items["nasiona"] = 1
	S.items["doniczka"] = 1
	G.Prod.hide("garage").pots.clear()
	G.Prod.pot_place("garage", 1.7, -1.2)
	G.Prod.plant_seed("garage", 0)
	G.Prod.plant_of("garage", 0).prog = 0.37
	var js := JSON.stringify(G.S)
	var data = JSON.parse_string(js)
	var base: Dictionary = G.new_state()
	G._merge(base, data)
	ok(int(base.lvl) == int(S.lvl) and absf(float(base.cash) - S.cash) < 1.0 and base.props.has("garaz"), "stan przechodzi przez zapis JSON")
	ok(int(base.stash.safe.get("items", {}).get("majeranek", 0)) == int(G.store_items(S.stash.safe).get("majeranek", 0)), "przedmioty w skrytkach zapisują się")
	ok(base.hide.garage.items.size() == S.hide.garage.items.size() and base.hide.garage.items.size() >= 4, "meble zapisują się (%d)" % base.hide.garage.items.size())
	var sj = base.hide.garage.pots[0].pl if base.hide.garage.pots.size() == 1 else null
	ok(sj != null and absf(float(sj.prog) - 0.37) < 0.001 and absf(float(base.hide.garage.pots[0].x) - 1.7) < 0.001, "doniczka z krzakiem zapisuje się razem z postępem")
	G.Prod.hide("garage").pots.clear()
	G.world.refresh_furniture("garage")

	# --- stroje: sklep z ubraniami, cechy, kominiarka
	await load("res://scripts/outfit_test.gd").run(self)

	# --- klub, szpital, komenda
	await load("res://scripts/services_test.gd").run(self)

	# --- Giełda: dostawcy, dostawy, okazje, skup
	await load("res://scripts/market_test.gd").run(self)

	# --- prolog: nalot na laboratorium, ucieczka, eksplozje
	if not M.args.has("noprologue"):
		var keep_state: Dictionary = G.S
		await load("res://scripts/prologue_test.gd").run(self)
		G.S = keep_state
		U.close_all()

	# --- raty i zakończenia
	S = G.S
	S.cash = 30000.0
	G.pay_debt(1e9)
	ok(S.debt <= 0.0 and int(S.rank) == D.RANKS.size() - 1 and G.rank_next().is_empty() and G.has_perk("wolny"), "pełny wkład: Kuba zostaje wspólnikiem (%s)" % String(G.rank_def().name))
	await get_tree().create_timer(1.0).timeout
	await frames(5)
	ok(U.mode == "end" or not G.running, "zakończenie po zebraniu pełnego wkładu")
	print("TEST PODSUMOWANIE: %s (%d błędów)" % ["WSZYSTKO OK" if fails == 0 else "SĄ BŁĘDY", fails])
	get_tree().quit(1 if fails > 0 else 0)


# ================================================================ symulator ekonomii
## Bot gra jak rozsądny gracz: trzyma towar w skrytce, bierze na spotkanie tyle, ile trzeba,
## zamawia towar pod swoich klientów, pilnuje zeszytu i rat. Dojścia są doliczane ryczałtem.
func sim(days: int) -> void:
	await frames(10)
	if U.mode == "dialog":
		await skip_dialog()
	U.close_all()
	var runs := int(M.args.get("runs", "3"))
	for run_i in range(runs):
		G.S = G.new_state()
		G.npcs.clear_customers()
		var res := await _sim_one(days, run_i)
		print("SIM WYNIK przebieg %d: %s" % [run_i + 1, res])
	get_tree().quit(0)


func _stock(p: String) -> float:
	var n := 0.0
	for st in [G.S.inv, G.S.stash.safe]:
		for k in st.bulk[p]:
			n += float(st.bulk[p][k])
		for k in st.pack[p]:
			n += float(st.pack[p][k])
	return n


func _stash_all() -> void:
	for e in G.entries(G.S.inv):
		# gotówkę bot nosi przy sobie (wpłaca ją do skrzynki Wiktora), do szafy idzie tylko towar
		if e.kind != "item" and e.kind != "cash":
			G.move_entry("safe", e, true, 1e9)


func _sim_one(days: int, run_i: int) -> String:
	var S: Dictionary = G.S
	var skill: float = [0.5, 0.7, 0.9][run_i % 3]      # jak dobrze gracz się targuje i waży
	var invest: bool = M.args.has("invest")
	G.tour_skip()
	S.flags["wiktor_sms"] = true
	S.flags["read_wiktor"] = true
	var lazy := float(M.args.get("lazy", "0"))  # jaka część zamówień przepada (gracz nie zdąża)
	var free: bool = M.args.has("free")       # bez wkładu do zebrania: mierzymy sam zysk
	if free:
		S.debt = 0.0
	var last_day := 0
	var lost := ""
	var guard := 0
	var missed := 0
	var prod_visit := 0.0
	while G.day() <= days and guard < 300000:
		guard += 1
		G.story_tick()
		if not G.flag("got_first"):
			G.starter_pickup()
		# paczki: po odbiorze prosto do domu
		var d = G.ready_drop()
		if d != null:
			_stash_all()
			if G.pickup_block(d) == "":
				G.add_minutes(22.0)
				G.pickup_drop(d)
		# porcjowanie w domu
		if not G.bench_bulk("safe").is_empty():
			pack_all("safe")
		_stash_all()
		# SMS-y
		for o in S.orders.duplicate():
			if o.status != "new":
				continue
			if randf() < lazy and G.flag("hurt_on"):
				G.reply_order(o.id, "decline")
				continue
			if _stock(o.product) < 1.0 and S.drops.is_empty():
				G.reply_order(o.id, "decline")
				continue
			if randf() < skill * 0.5:
				G.reply_order(o.id, "price", int(round(float(o.stated) * 1.08)))
				var o2 = G.find_order(o.id)
				if o2 != null and o2.status == "new" and o2.counter != null:
					G.reply_order(o.id, "counterok")
			else:
				G.reply_order(o.id, "accept")
		# spotkania
		var m = G.next_meeting()
		if m != null and S.t >= float(m.meet) - 2.0:
			var def: Dictionary = G.cust_def(m.cust)
			# weź ze skrytki najlepiej pasujący towar
			var best = null
			for st in G.stacks(S.stash.safe, "pack"):
				if st.p != m.product:
					continue
				if best == null or (int(st.pur) >= int(def.minpur) and (int(best.pur) < int(def.minpur) or int(st.pur) < int(best.pur))):
					best = st
			if best != null:
				G.move_stack("safe", false, "pack", best.p, int(best.pur), float(int(m.grams) + 1))
			var have := 0
			for st in G.stacks(S.inv, "pack"):
				if st.p == m.product:
					have += int(st.n)
			if have > 0:
				var who: Dictionary = def.duplicate()
				who["st"] = S.cust[m.cust]
				var dd: Dictionary = G.deal_start({"who": who, "product": m.product, "grams": int(m.grams), "order": m, "street": false, "agreed": m.agreed})
				if not dd.is_empty():
					# wprawny gracz podbija cenę tam, gdzie zna klienta; reszta bierze umówioną
					var pct := 0
					if randf() < skill * 0.6:
						for lv in G.DEAL_LEVELS:
							if int(lv) > 0 and G.deal_read(dd, int(lv)) in ["sure", "ok"]:
								pct = int(lv)
						if pct == 0 and randf() < 0.3:
							pct = 5
					G.deal_set(dd, pct)
					G.deal_hand(dd)
					if not dd.over:
						G.deal_hand(dd)
				G.add_minutes(14.0)
			else:
				missed += 1
			if G.find_order(m.id) != null and (have <= 0 or S.t > float(m.meet) + 50.0):
				G.reply_order(m.id, "decline")
			_stash_all()
		# nowi klienci „z ulicy”
		for c in D.CLIENTS:
			if c.via == "talk" and not S.cust[c.id].unlocked and int(S.lvl) >= int(c.lvl) and G.client_count() < G.client_cap():
				G.add_minutes(25.0)
				G.meet(c.id)
		# zamówienia u Wiktora: towar pod aktualnych klientów, wszystko jednym koszykiem
		if G.flag("hurt_on") and S.drops.size() < 2:
			var need := {}
			for c in D.CLIENTS:
				if not S.cust[c.id].unlocked:
					continue
				var per_day: float = (float(c.grams[0]) + float(c.grams[1])) * 0.5 * 16.0 / ((float(c.every[0]) + float(c.every[1])) * 0.5)
				var ps: Array = []
				for p0 in c.get("prods", [c.prod]):
					if int(S.lvl) >= int(D.PRODUCTS[p0].lvl):
						ps.append(p0)
				for i in range(ps.size()):
					var share: float = 1.0 if ps.size() == 1 else (0.62 if i == 0 else 0.38 / float(ps.size() - 1))
					need[ps[i]] = float(need.get(ps[i], 0.0)) + per_day * share
			var MK = G.Market
			var cart := []
			var room := float(G.capacity()) - 2.0
			for p in need:
				var pending := false
				for dr in S.drops:
					for it in dr.get("items", []):
						if String(it.p) == String(p):
							pending = true
				if pending or _stock(p) > float(need[p]) * 0.45:
					continue
				var want := 5
				for sz in D.WHOLESALE_SIZES:
					if sz <= G.wholesale_max() and sz <= maxf(5.0, float(need[p]) * 1.6) and float(sz) <= room:
						want = sz
				if float(want) > room:
					continue
				cart.append({"p": p, "g": want})
				room -= float(want)
			while not cart.is_empty() and MK.cart_block(cart) != "":
				# za dużo na zeszyt: najpierw mniejsze paczki, potem mniej pozycji
				var shrunk := false
				for it in cart:
					if int(it.g) > 5:
						it.g = int(D.WHOLESALE_SIZES[maxi(0, D.WHOLESALE_SIZES.find(int(it.g)) - 1)])
						shrunk = true
						break
				if not shrunk:
					cart.pop_back()
			if not cart.is_empty():
				MK.order_cart(cart)
		# pieniądze: wszystko przez skrzynkę Wiktora (schodzi to, co ma bliższy termin: zeszyt albo rata)
		var put := 0.0
		if float(S.credit) > 0.0:
			var due_in = (float(S.credit_due) - S.t) / 1440.0
			if not G.flag("hurt_on") and S.cash >= float(D.BOX_FIRST):
				put = minf(S.cash, float(S.credit))
			elif S.cash >= float(S.credit) + 20.0 and (due_in < 1.2 or S.cash > float(S.credit) + 250.0):
				put = float(S.credit)
			elif due_in < 0.3 and S.cash > 40.0:
				put = minf(float(S.credit), S.cash - 20.0)
		var ni: Dictionary = G.next_installment()
		if not ni.is_empty() and S.debt > 0.0:
			var need_r: float = float(ni.due) - S.paid
			var days_left := int(ni.day) - G.day()
			var reserve := 200.0 + int(S.lvl) * 150.0
			if invest and int(S.lvl) >= 4:
				# odkłada na garaż i sprzęt, o ile do terminu raty zostało jeszcze trochę czasu
				reserve = (float(G.prop_def("garaz").price) + 900.0 if not G.owns("garaz") else 2600.0) if days_left > 1 else reserve
			if need_r > 0.0 and days_left <= 0 and G.hour() > 20.0:
				put += minf(need_r, maxf(0.0, S.cash - put - 25.0))
			elif need_r > 0.0 and S.cash > need_r + reserve + float(S.credit):
				put += need_r
		elif ni.is_empty() and S.debt > 0.0 and S.cash > S.debt + float(S.credit) + 300.0:
			put = S.debt + float(S.credit)
		if M.args.has("simdbg") and guard % 40 == 0:
			print("DBG d%d h%.1f cash %d credit %d hurt %s put %d step %s drops %d stock %.0f/%.0f orders %d" % [G.day(), G.hour(), int(S.cash), int(S.credit), str(G.flag("hurt_on")), int(put), String(G.cur_step().get("id", "")), S.drops.size(), _stock("dym"), _stock("szron"), S.orders.size()])
		if put >= 1.0:
			G.add_minutes(12.0)
			G.move_cash("wiktor", true, put)
			G.box_settle()
		# rozwój
		if int(S.sp) > 0:
			for sk in D.SKILLS:
				if G.can_learn(sk.id):
					G.learn_skill(sk.id)
					break
		if int(S.lvl) >= 2 and not G.upg("plecak1") and S.cash > 380.0 + 150.0:
			G.upgrade_buy("plecak1")
		# lepsza waga z lombardu, gdy już na nią stać (bez ruszania pieniędzy odłożonych na ratę)
		if G.scale() + 1 < D.SCALES.size() and G.scale_block(G.scale() + 1) == "" and S.cash > float(D.SCALES[G.scale() + 1].price) * 1.6 + 400.0 + float(S.credit):
			G.scale_buy(G.scale() + 1)
		if invest:
			if int(S.lvl) >= 3 and not G.upg("szafka") and S.cash > 2200.0:
				G.upgrade_buy("szafka")
			if int(S.lvl) >= 4 and not G.owns("garaz") and S.cash > float(G.prop_def("garaz").price) + 600.0:
				G.buy_property("garaz")
			if G.owns("garaz") and S.t - prod_visit > 300.0:
				prod_visit = S.t
				_sim_production(skill)
		# noc
		var h := G.hour()
		if h >= 23.5 or h < 7.0:
			G.mods["sleeping"] = true
			G.add_minutes(fmod(7.0 - h + 24.0, 24.0) * 60.0 + 1.0)
			G.mods.erase("sleeping")
		else:
			G.add_minutes(10.0)
		if G.day() != last_day:
			last_day = G.day()
			var stash_cash := 0.0
			for rr in S.stash:
				stash_cash += float(S.stash[rr].cash)
			var stock_v := 0.0
			for pp in D.PRODUCTS:
				stock_v += _stock(pp) * float(D.PRODUCTS[pp].cost)
			if free:
				print("ZYSK %d d%02d | poz %2d | majątek %6d | klienci %2d | transakcje %3d | przychód %6d" % [run_i + 1, last_day, int(S.lvl), int(S.cash + stash_cash + stock_v - float(S.credit) - 60.0), G.client_count(), int(S.stats.deals), int(S.stats.earned)])
			if M.args.has("simdbg"):
				print("SIMDBG %d d%02d krok=%s packed=%d sold=%d woreczki=%d bulk=%s drops=%d zam=%d flagi=%s" % [run_i + 1, last_day, String(G.cur_step().get("id", "?")), int(S.stats.packed), int(S.stats.sold), G.item_at("safe", "woreczki"), str(G.bench_bulk("safe")), S.drops.size(), S.orders.size(), str(S.flags.keys())])
			print("SIM %d d%02d | poz %2d | gotówka %5d | wkład %5d | brakuje %5d | zeszyt %4d | klienci %2d | transakcje %3d | zarobione %6d | wpadki %d | przegapione %d | uprawa %4d g | synteza %4d g | naloty %d" % [
				run_i + 1, last_day, int(S.lvl), int(S.cash + stash_cash), int(S.paid), int(S.debt), int(S.credit), G.client_count(), int(S.stats.deals), int(S.stats.earned), int(S.strikes), missed,
				int(S.stats.get("grown", 0)), int(S.stats.get("cooked", 0)), int(S.stats.get("raids", 0))] + " | skup %4d g" % int(S.stats.get("bulk_sold", 0)))
		if S.debt <= 0.0 and not free:
			lost = "WSPÓLNIK w dniu %d" % G.day()
			break
		if guard % 400 == 0:
			await get_tree().process_frame
	if lost == "":
		lost = "koniec symulacji: dzień %d, ranga %s, wkład %d z %d" % [G.day(), String(G.rank_def().name), int(S.paid), int(D.START_DEBT)]
	return "umiejętność gracza %.2f → %s, poziom %d, klienci %d, transakcje %d, zarobione %d" % [skill, lost, int(S.lvl), G.client_count(), int(S.stats.deals), int(S.stats.earned)]


## Wizyta bota w garażu (co ok. 5 godzin): dokupuje stanowiska, dogląda upraw i syntez,
## wynosi gotowy towar do kawalerki. Dojazd w obie strony doliczany ryczałtem.
func _sim_production(skill: float) -> void:
	var S: Dictionary = G.S
	var P = G.Prod
	var room := "garage"
	G.add_minutes(24.0)
	var have := {}
	for it in S.hide[room].items:
		have[String(it.f)] = int(have.get(String(it.f), 0)) + 1
	# zakupy: najpierw regał na towar, potem uprawa, suszarka, filtr, kolejne regały, na końcu chemia
	var plan := [["regal", 2.3, -3.9, 0, 1, 200.0], ["lampa_led", 2.0, -1.9, 0, 4, 300.0], ["suszarka", -2.4, -3.8, 0, 4, 200.0],
		["lampa_led", -1.9, -2.3, 0, 6, 900.0], ["filtr", -2.5, 3.6, 0, 4, 900.0], ["zbiornik", -2.5, 2.5, 0, 6, 900.0],
		["lab", 2.5, 1.2, 1, 5, 2000.0]]
	var seen := {}
	for e in plan:
		var fid: String = e[0]
		seen[fid] = int(seen.get(fid, 0)) + 1
		if int(have.get(fid, 0)) >= int(seen[fid]) or int(S.lvl) < int(e[4]):
			continue
		if S.cash > float(G.furn_def(fid).price) + float(e[5]):
			if G.furn_buy_place(room, fid, float(e[1]), float(e[2]), int(e[3])):
				have[fid] = int(have.get(fid, 0)) + 1
	# doniczki pod lampami: bot dokupuje je po trochu, sadzi, podlewa, a staranny także nawozi i przycina
	var spots: Array = []
	for it in P.lamps(room):
		for k in range(6):
			spots.append(Vector2(float(it.x) - 0.5 + (k % 3) * 0.5, float(it.z) - 0.25 + int(k / 3.0) * 0.5))
	var pots: Array = P.pots(room)
	var want: int = mini(spots.size(), 2 + int(S.lvl) - 3)
	var bought := 0
	while pots.size() < want and bought < 2 and S.cash > 400.0:
		if G.item_at(room, "doniczka") <= 0 and not G.shop_buy("doniczka"):
			break
		var placed := false
		for sp in spots:
			if P.pot_valid(room, sp.x, sp.y) and P.pot_place(room, sp.x, sp.y):
				placed = true
				break
		if not placed:
			break
		bought += 1
	for i in range(pots.size()):
		var pl = pots[i].pl
		if pl == null:
			if G.item_at(room, "nasiona") <= 0 and S.cash > 150.0:
				G.shop_buy("nasiona")
			P.plant_seed(room, i)
		elif float(pl.prog) >= 1.0:
			P.plant_cut(room, i)
		else:
			if float(pl.water) < 60.0:
				P.plant_water(room, i)
			if skill > 0.6:
				if P.plant_cut_kind(room, i) == "trim":
					P.plant_cut(room, i)
				if not pl.fert and float(pl.prog) < 0.6:
					if G.item_at(room, "nawoz") <= 0 and S.cash > 200.0:
						G.shop_buy("nawoz")
					P.plant_fert(room, i)
	var items: Array = S.hide[room].items
	for i in range(items.size()):
		var kind: String = P.kind(room, i)
		var j = P.job(room, i)
		if kind == "grow":
			pass
		elif kind == "dry":
			if j != null and float(j.prog) >= 1.0:
				P.collect(room, i)
				j = null
			if j == null:
				P.dry_start(room, i)
		elif kind == "lab":
			if j == null:
				var rid := "metamfetamina" if (int(S.lvl) >= 8 and randf() < 0.5) else "amfetamina"
				var need: int = int(D.RECIPES[rid].input.chemia)
				while G.item_at(room, "chemia") < need and S.cash > 1400.0:
					if not G.shop_buy("chemia"):
						break
				if P.start(room, i, rid):
					P.set_mode(room, i, 0 if skill > 0.8 else 1)
			elif float(j.prog) >= 1.0:
				P.collect(room, i)
			elif int(j.hold) >= 0:
				P.proceed(room, i)
	# nadwyżki marihuany idą do skupu prosto z garażu (zostaje zapas na własnych klientów)
	var need_d := 0.0
	for c in D.CLIENTS:
		if S.cust[c.id].unlocked and String(c.prod) == "dym":
			need_d += (float(c.grams[0]) + float(c.grams[1])) * 0.5 * 16.0 / ((float(c.every[0]) + float(c.every[1])) * 0.5)
	for st in G.stacks(S.stash[room], "bulk"):
		if String(st.p) != "dym" or G.is_mix(st.pur):
			continue
		var spare: float = floorf(minf(float(st.n) + _stock("dym") - need_d * 2.5, minf(float(st.n), float(G.Market.bulk_left_today()))))
		if spare >= float(D.BULK_SELL_MIN):
			G.Market.bulk_sell(S.stash[room], "dym", int(st.pur), spare)
	# gotowy towar jedzie do kawalerki (tyle, ile wejdzie do plecaka)
	for e in G.entries(S.stash[room]):
		if e.kind != "item":
			G.move_entry(room, e, false, 1e9)
	G.add_minutes(22.0)
	_stash_all()
