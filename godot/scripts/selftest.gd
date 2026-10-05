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


func pack_all(room: String, hits := 3) -> void:
	for s in G.bench_bulk(room):
		var left := int(floor(float(s.n) + 0.001))
		var guard := 0
		while left > 0 and G.item_at(room, "woreczki") > 0 and guard < 60:
			guard += 1
			var n: int = mini(left, G.pack_session_max())
			var r: Dictionary = G.pack(room, s.p, int(s.pur), n, hits)
			if int(r.packed) + int(r.lost) <= 0:
				break
			left -= int(r.packed) + int(r.lost)


# ================================================================ test funkcjonalny
func run() -> void:
	await frames(20)
	var S: Dictionary = G.S
	ok(G.running, "gra wystartowała")
	ok(S.cash == float(D.START_CASH) and S.debt == float(D.START_DEBT), "stan początkowy: gotówka i dług")
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
	U.open_stash("safe")
	await frames(2)
	U.close_all()
	G.story_tick()
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
	for app in ["", "kontakty", "mapa", "hurt", "portfel", "rozwoj", "zadania", "lokale", "ustawienia"]:
		U.phone.go(app)
		await frames(2)
	ok(U.mode == "phone", "wszystkie aplikacje telefonu się rysują")
	U.close_all()
	S = G.S

	# --- pierwsza paczka
	G.story_tick()
	var d = G.ready_drop()
	ok(d != null, "pierwsza paczka czeka w skrytce")
	if d != null:
		ok(G.pickup_drop(d), "odbiór paczki")
	ok(G.goods_total(S.inv) == 5.0 and float(S.credit) == 105.0, "5 g luzem na zeszyt (105 zł)")
	ok(absf(G.carry_total() - 5.5) < 0.01, "zajęte miejsce: 5 g + 10 woreczków = 5,5")

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
	var r: Dictionary = G.pack("safe", "dym", 80, 3, 3)
	ok(int(r.packed) == 3 and G.item("woreczki") == 7, "zaporcjowane 3 g, ubyło 3 woreczków")
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
		G.deal_greet(U.deal, "luz")
		U._render_deal()
		await frames(3)
		ok(S.cust.dominik.known.get("like", "") == "luz", "trafiony styl zapisany w notatkach")
		G.deal_sell_agreed(U.deal)
		U._render_deal()
		await frames(3)
	ok(S.cash > cash0 and int(S.stats.deals) == 1, "sprzedaż po umówionej cenie (+%d zł)" % int(S.cash - cash0))
	ok(int(S.stats.sold) == 2, "pierwsze zamówienie Dominika to zawsze 2 g")
	U.close_all()
	await frames(5)

	# --- zeszyt
	S.cash = maxf(S.cash, 200.0)
	G.pay_credit(1e9)
	G.story_tick()
	G.story_tick()
	ok(float(S.credit) <= 0.0 and G.flag("hurt_on"), "zeszyt spłacony, hurt odblokowany")
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
	G.deal_greet(dp, "twardo")
	var mood_left: float = dp.mood
	G.deal_pause(dp)
	ok(G.find_order(op.id) != null and op.has("hold"), "„Zaraz wracam”: zamówienie nie przepada")
	var dp2: Dictionary = G.deal_start({"who": whop, "product": "dym", "grams": int(op.grams), "order": op, "street": false, "agreed": op.agreed})
	ok(float(dp2.mood) < mood_left + 0.01, "po powrocie klient pamięta nastrój rozmowy")
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
		if G.deal_quality_reject(dd):
			rejected += 1
		G.take_pack(S.inv, "dym", 40, 99)
	ok(rejected >= 8, "doświadczony klient odrzuca mieszankę (%d/40 prób)" % rejected)

	# --- umiejętności, wyposażenie
	S.lvl = 5
	S.sp = 3
	S.cash = 30000.0
	ok(G.learn_skill("gadka"), "nauka umiejętności")
	ok(G.upgrade_buy("plecak1") and G.capacity() == 40, "plecak szkolny: 40 miejsc")
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
	var placed := 0
	for fd in [["stol", -1.6, -3.6], ["regal", 2.3, -3.9], ["namiot", 2.2, -1.2], ["kanapa", -2.4, 0.6, 1]]:
		var rot: int = fd[3] if fd.size() > 3 else 0
		if G.furn_place("garage", fd[0], fd[1], fd[2], rot):
			placed += 1
	G.world.refresh_furniture("garage")
	await frames(5)
	ok(placed == 4, "wstawione 4 meble (%d)" % placed)
	ok(G.stash_cap("garage") == 150, "regał daje skrytkę na 150 miejsc")
	U.open_build("garage")
	await frames(3)
	U.close_all()
	M.build_begin("krzeslo")
	await frames(10)
	ok(M.build_active(), "tryb meblowania aktywny")
	M.build_cancel()
	G.story_tick()
	G.story_tick()
	S.items["nasiona"] = 1
	ok(G.grow_start("garage", 2, 3), "zasianie w namiocie")
	G.mods["sleeping"] = true
	G.add_minutes(36.5 * 60.0)
	G.mods.erase("sleeping")
	ok(G.grow_collect("garage", 2), "zbiór po 36 godzinach")
	ok(G.goods_total(S.stash.garage) > 15.0, "plon w skrytce garażu")
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
	var js := JSON.stringify(G.S)
	var data = JSON.parse_string(js)
	var base: Dictionary = G.new_state()
	G._merge(base, data)
	ok(int(base.lvl) == int(S.lvl) and absf(float(base.cash) - S.cash) < 1.0 and base.props.has("garaz"), "stan przechodzi przez zapis JSON")
	ok(int(base.stash.safe.get("items", {}).get("majeranek", 0)) == int(G.store_items(S.stash.safe).get("majeranek", 0)), "przedmioty w skrytkach zapisują się")
	ok(base.hide.garage.items.size() == 4, "meble zapisują się")

	# --- raty i zakończenia
	S = G.S
	S.cash = 30000.0
	G.pay_debt(1e9)
	ok(S.debt <= 0.0, "spłata całego długu")
	await get_tree().create_timer(1.0).timeout
	await frames(5)
	ok(U.mode == "end" or not G.running, "zakończenie po spłacie długu")
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
		if e.kind != "item":
			G.move_entry("safe", e, true, 1e9)


func _sim_one(days: int, run_i: int) -> String:
	var S: Dictionary = G.S
	var skill: float = [0.5, 0.7, 0.9][run_i % 3]      # jak dobrze gracz się targuje i waży
	var invest: bool = M.args.has("invest")
	for fk in ["tut_save", "tut_stash", "tut_bench", "wiktor_sms"]:
		S.flags[fk] = true
	S.flags["read_wiktor"] = true
	var lazy := float(M.args.get("lazy", "0"))  # jaka część zamówień przepada (gracz nie zdąża)
	var free: bool = M.args.has("free")       # bez długu: mierzymy sam zysk
	if free:
		S.debt = 0.0
	var last_day := 0
	var lost := ""
	var guard := 0
	var missed := 0
	while G.day() <= days and guard < 300000:
		guard += 1
		G.story_tick()
		# paczki: po odbiorze prosto do domu
		var d = G.ready_drop()
		if d != null:
			_stash_all()
			if G.pickup_block(d) == "":
				G.add_minutes(22.0)
				G.pickup_drop(d)
		# porcjowanie w domu
		if not G.bench_bulk("safe").is_empty():
			if G.item_at("safe", "woreczki") < 25 and S.cash >= 12.0:
				G.shop_buy("woreczki")
			if G.item_at("safe", "woreczki") > 0:
				G.add_minutes(8.0)
				pack_all("safe", 3 if randf() < skill else 2)
		_stash_all()
		# SMS-y
		for o in S.orders.duplicate():
			if o.status != "new":
				continue
			if randf() < lazy:
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
					var known: Dictionary = S.cust[m.cust].get("known", {})
					var styles := ["luz", "konkret", "twardo"]
					if known.has("hate"):
						styles.erase(known.hate)
					G.deal_greet(dd, known.get("like", styles.pick_random()))
					if randf() < skill * 0.35:
						G.deal_haggle(dd)
						G.deal_offer(dd)
						if not dd.over and dd.counter != null:
							G.deal_accept(dd)
						if not dd.over:
							dd.price = int(m.agreed)
							G.deal_offer(dd)
							if not dd.over and dd.counter != null:
								G.deal_accept(dd)
					elif not dd.over:
						G.deal_sell_agreed(dd)
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
		# zamówienia u Wiktora: towar pod aktualnych klientów
		if G.flag("hurt_on") and S.drops.size() < 2:
			var need := {}
			for c in D.CLIENTS:
				if S.cust[c.id].unlocked and int(S.lvl) >= int(D.PRODUCTS[c.prod].lvl):
					var per_day: float = (float(c.grams[0]) + float(c.grams[1])) * 0.5 * 16.0 / ((float(c.every[0]) + float(c.every[1])) * 0.5)
					need[c.prod] = float(need.get(c.prod, 0.0)) + per_day
			for p in need:
				var pending := false
				for dr in S.drops:
					if dr.p == p:
						pending = true
				if pending or _stock(p) > float(need[p]) * 0.45:
					continue
				var want := 5
				for sz in D.WHOLESALE_SIZES:
					if sz <= G.wholesale_max() and sz <= maxf(5.0, float(need[p]) * 1.6) and sz + 2 <= G.capacity():
						want = sz
				var high: bool = int(S.lvl) >= 5 and p != "dym"
				var cost := G.wholesale_price(p, want, high)
				var credit: bool = S.cash < cost + 50.0
				if G.order_block(p, want, credit, high) == "":
					G.order_goods(p, want, high, credit)
				elif G.order_block(p, 5, S.cash < G.wholesale_price(p, 5, high) + 30.0, high) == "":
					G.order_goods(p, 5, high, S.cash < G.wholesale_price(p, 5, high) + 30.0)
		# pieniądze: zeszyt przed terminem, rata w dniu spłaty (albo wcześniej, gdy jest zapas)
		if float(S.credit) > 0.0:
			var due_in = (float(S.credit_due) - S.t) / 1440.0
			if S.cash >= float(S.credit) + 20.0 and (due_in < 1.2 or S.cash > float(S.credit) + 250.0):
				G.pay_credit(1e9)
			elif due_in < 0.3 and S.cash > 40.0:
				G.pay_credit(S.cash - 20.0)
		var ni: Dictionary = G.next_installment()
		if not ni.is_empty() and S.debt > 0.0:
			var need_r: float = float(ni.due) - S.paid
			var days_left := int(ni.day) - G.day()
			var reserve := 200.0 + int(S.lvl) * 150.0
			if need_r > 0.0 and days_left <= 0 and G.hour() > 20.0:
				G.pay_debt(minf(need_r, maxf(0.0, S.cash - 25.0)))
			elif need_r > 0.0 and S.cash > need_r + reserve + float(S.credit):
				G.pay_debt(need_r)
		# rozwój
		if int(S.sp) > 0:
			for sk in D.SKILLS:
				if G.can_learn(sk.id):
					G.learn_skill(sk.id)
					break
		if int(S.lvl) >= 2 and not G.upg("plecak1") and S.cash > 380.0 + 150.0:
			G.upgrade_buy("plecak1")
		if invest:
			if int(S.lvl) >= 3 and not G.upg("szafka") and S.cash > 2200.0:
				G.upgrade_buy("szafka")
			if int(S.lvl) >= 4 and not G.owns("garaz") and S.cash > 9000.0:
				G.buy_property("garaz")
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
			print("SIM %d d%02d | poz %2d | gotówka %5d | spłacono %5d | dług %5d | zeszyt %4d | klienci %2d | transakcje %3d | zarobione %6d | wpadki %d | przegapione %d" % [
				run_i + 1, last_day, int(S.lvl), int(S.cash + stash_cash), int(S.paid), int(S.debt), int(S.credit), G.client_count(), int(S.stats.deals), int(S.stats.earned), int(S.strikes), missed])
		if int(S.strikes) >= D.MAX_STRIKES:
			lost = "PRZEGRANA (dług) w dniu %d" % G.day()
			break
		if S.debt <= 0.0 and not free:
			lost = "DŁUG SPŁACONY w dniu %d" % G.day()
			break
		if guard % 400 == 0:
			await get_tree().process_frame
	if lost == "":
		lost = "koniec symulacji: dzień %d, dług %d, spłacono %d" % [G.day(), int(S.debt), int(S.paid)]
	return "umiejętność gracza %.2f → %s, poziom %d, klienci %d, transakcje %d, zarobione %d" % [skill, lost, int(S.lvl), G.client_count(), int(S.stats.deals), int(S.stats.earned)]
