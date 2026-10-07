extends RefCounted
## Testy hurtu: jeden dostawca (Wiktor), czysty towar, koszyk, zeszyt z limitem i terminem, skrzynka na pieniądze,
## spalona skrytka przy zaawansowanym śledztwie, skup nadwyżek, sklep w obróconym telefonie.


static func run(T) -> void:
	var M = G.Market
	var keep: Dictionary = G.S
	G.S = G.new_state()
	var S: Dictionary = G.S
	S.flags["got_first"] = true
	S.lvl = 1
	S.cash = 5000.0
	S.cost_mult = 1.0
	T.ok(D.VENDORS.size() == 1 and String(D.VENDORS[0].id) == "wiktor" and D.DELIVERY.size() == 1, "dostawca jest jeden — Wiktor, a paczki trafiają tylko do skrytek")
	T.ok(M.cart_block([{"p": "dym", "g": 5}]).contains("ufa"), "dopóki nie wrzucisz pierwszych pieniędzy do skrzynki, Wiktor nie przyjmuje zamówień")
	S.flags["hurt_on"] = true
	T.ok(M.block("wiktor", "dym", 5) == "" and M.block("wiktor", "szron", 5) == "" and M.block("wiktor", "krysztal", 5).contains("poziomu") and M.block("wiktor", "snieg", 5).contains("poziomu"),
		"od początku marihuana i amfetamina, mocniejszy towar z poziomem")
	T.ok(M.sizes() == [5, 10] and M.block("wiktor", "dym", 20).contains("najwyżej"), "na 1. poziomie paczki do 10 g")
	var c7: Array = []
	M.cart_add(c7, "dym", 7)
	M.cart_add(c7, "dym", 2)
	T.ok(c7.size() == 1 and int(c7[0].g) == 9 and M.cart_block(c7) == "" and M.cart_cost(c7) == M.price("wiktor", "dym", 9), "do koszyka wchodzi dowolna liczba gramów, a ten sam towar się sumuje (9 g za %d zł)" % int(M.cart_cost(c7)))
	T.ok(G.wholesale_disc(19) == 0.0 and G.wholesale_disc(20) == 0.04 and G.wholesale_disc(120) == 0.12 and G.wholesale_disc(250) == 0.16, "rabat za ilość liczy się progami: od 20, 50, 100 i 250 g")
	# ceny: uliczna marihuana ok. 50 zł/g, hurt ok. połowę; rabat za ilość i za zaufanie
	var pw: float = M.price("wiktor", "dym", 10)
	T.ok(int(D.PRODUCTS.dym.base) == 50 and pw == 260.0 and G.market_price("dym") == 50.0 and G.market_price("dym", 100) == G.market_price("dym", 42), "marihuana: 26 zł/g w hurcie, 50 zł/g na ulicy — czysta i rozrobiona kosztują tyle samo")
	S.lvl = 6
	T.ok(M.price("wiktor", "dym", 100) < 26.0 * 100.0 * 0.9, "większa paczka = rabat (100 g za %d zł)" % int(M.price("wiktor", "dym", 100)))
	M.add_trust("wiktor", 100.0)
	T.ok(M.price("wiktor", "dym", 10) < pw * 0.93 and M.trust_discount("wiktor") <= 0.0801, "pełne zaufanie = 8%% rabatu (%d → %d zł)" % [int(pw), int(M.price("wiktor", "dym", 10))])
	M.vstate("wiktor").trust = 0.0
	S.lvl = 1
	# limit zeszytu rośnie z poziomem: starcza na największą paczkę najdroższego towaru
	var lim1: float = G.credit_limit()
	S.lvl = 9
	var lim9: float = G.credit_limit()
	S.lvl = 1
	T.ok(lim1 >= 700.0 and lim1 < 1200.0 and lim9 > G.wholesale_price("snieg", 250), "limit zeszytu: %d zł na 1. poziomie, %d zł na 9." % [int(lim1), int(lim9)])
	# koszyk: kilka towarów w jednej paczce, wszystko na zeszyt, towar czysty
	var cart := []
	M.cart_add(cart, "dym", 5)
	M.cart_add(cart, "dym", 5)
	M.cart_add(cart, "szron", 10)
	T.ok(cart.size() == 2 and int(cart[0].g) == 10 and M.cart_cost(cart) == 260.0 + 320.0 and M.cart_grams(cart) == 20, "koszyk łączy paczki tego samego towaru (%d zł)" % int(M.cart_cost(cart)))
	var d1: Dictionary = M.order_cart(cart)
	T.ok(not d1.is_empty() and d1.credit and int(d1.pur) == 100 and d1.state == "wait" and S.cash == 5000.0 and float(S.credit) == 0.0 and not M.spot(d1).is_empty() and M.spot(d1).has("mark"),
		"zamówienie przyjęte: nic nie płacisz z góry, paczka pójdzie do skrytki ze znakiem (%s)" % G.drop_mark(M.spot(d1)))
	T.ok(M.contents(d1) == "10 g marihuany + 10 g amfetaminy" and G.drops_owed() == 580.0, "paczka: " + M.contents(d1))
	T.ok(M.cart_block([{"p": "dym", "g": 10}]).contains("limit"), "kolejne zamówienie nie mieści się w limicie zeszytu")
	S.t = float(d1.ready) + 1.0
	G.on_tick()
	T.ok(d1.state == "ready" and (S.chats.wiktor as Array).back().text.contains("znaku"), "gdy paczka jest na miejscu, Wiktor pisze, jakiego znaku szukać")
	S.upg["plecak1"] = true
	var t_pick: float = S.t
	# skrytka otwiera się jak pojemnik: bierzesz część, płacisz tylko za nią, reszta czeka
	T.ok(G.loot_open({"kind": "drop", "d": d1}) and G.goods_total(S.stash.loot) == 20.0, "skrytka Wiktora: po otwarciu leży w niej cała paczka (20 g)")
	for le in G.entries(S.stash.loot):
		if String(le.p) == "dym":
			G.move_entry("loot", le, false, 4.0)
	G.loot_close()
	T.ok(float(S.credit) == 104.0 and S.drops.has(d1) and float(d1.g) == 16.0 and float(d1.cost) == 476.0 and M.contents(d1) == "6 g marihuany + 10 g amfetaminy",
		"wzięte 4 g marihuany: na zeszyt 104 zł, w skrytce czeka reszta (%s, zeszyt %d)" % [M.contents(d1), int(S.credit)])
	T.ok(G.pickup_block(d1) == "" and G.pickup_drop(d1) and float(S.credit) == 580.0 and S.cash == 5000.0, "odbiór nic nie kosztuje na miejscu — 580 zł idzie na zeszyt")
	T.ok(float(S.inv.bulk.dym.get("100", 0.0)) == 10.0 and float(S.inv.bulk.szron.get("100", 0.0)) == 10.0, "w plecaku czysty towar: 10 g + 10 g")
	T.ok(absf(float(S.credit_due) - (t_pick + D.CREDIT_DAYS_EARLY * 1440.0)) < 1.0 and G.credit_days() == D.CREDIT_DAYS_EARLY, "na początku Wiktor jest wyrozumiały: %d dni na spłatę" % G.credit_days())
	T.ok(M.trust("wiktor") > 0.0, "po odbiorze rośnie zaufanie (%d)" % int(M.trust("wiktor")))
	# skrzynka Wiktora: najpierw zeszyt, reszta na wkład i awanse
	var debt0: float = S.debt
	G.move_cash("wiktor", true, 300.0)
	T.ok(G.box_settle() == 300.0 and S.paid == 0.0 and float(S.credit) == 280.0 and S.debt == debt0 and float(S.stash.wiktor.cash) == 0.0,
		"300 zł w skrzynce: najpierw schodzi zeszyt za towar (zostaje %d zł)" % int(S.credit))
	var owed1: float = S.credit
	G.move_cash("wiktor", true, 500.0)
	T.ok(G.box_settle() == 500.0 and float(S.credit) == 0.0 and absf(S.paid - (500.0 - owed1)) < 0.01 and absf(S.debt - (debt0 - (500.0 - owed1))) < 0.01 and G.rank() == 0,
		"kolejne 500 zł: reszta zeszytu, nadwyżka (%d zł) na wkład — jeszcze bez awansu" % int(S.paid))
	# awans: próg 300 zł wkładu = Goniec; plecak już jest, więc Wiktor oddaje jego równowartość, a za tempo dokłada premię
	var cash_r: float = S.cash
	var lim_r: float = G.credit_limit()
	G.move_cash("wiktor", true, 100.0)
	G.box_settle()
	var bonus_r: float = float(D.RANKS[1].bonus) if G.day() <= int(D.RANKS[1].day) else 0.0
	T.ok(int(S.rank) == 1 and G.rank_def().name == "Goniec" and G.has_perk("plecak") and not G.has_perk("limit") and absf(S.cash - (cash_r - 100.0 + 380.0 + bonus_r)) < 0.01,
		"300 zł wkładu: awans na Gońca, plecak (albo jego równowartość) i premia za tempo %d zł" % int(bonus_r))
	T.ok((S.chats.wiktor as Array).back().text.contains("Awans"), "Wiktor pisze o awansie")
	var unit_r: float = G.wholesale_unit("dym")
	var gar_r: float = float(G.prop_def("garaz").price)
	var paid_keep: float = S.paid
	var debt_keep: float = S.debt
	var rank_keep: int = S.rank
	var cash_keep2: float = S.cash
	S.cash = 30000.0
	G.pay_debt(8000.0 - S.paid)
	T.ok(int(S.rank) == 4 and G.has_perk("limit") and G.credit_limit() > lim_r * 1.3 and absf(G.wholesale_unit("dym") - unit_r * 0.95) < 0.001 and absf(float(G.prop_def("garaz").price) - gar_r * 0.5) < 0.01,
		"Zaufany: zeszyt większy o połowę, hurt −5%%, garaż za pół ceny (%d zł)" % int(G.prop_def("garaz").price))
	T.ok(G.next_installment().due == 15000.0 and String(G.rank_next().name) == "Prawa ręka", "następny szczebel: Prawa ręka przy 15 000 zł")
	S.paid = paid_keep
	S.debt = debt_keep
	S["rank"] = rank_keep
	S.cash = cash_keep2
	# zeszyt po terminie: żadnych „wpadek” ani końca gry — ludzie Wiktora biorą gotówkę na poczet towaru
	var cr_keep: float = S.credit
	var due_keep: float = S.credit_due
	S.credit = 400.0
	S.cash = 500.0
	var safe_keep: float = S.stash.safe.cash
	S.stash.safe.cash = 0.0
	G.collectors()
	T.ok(S.cash == 300.0 and float(S.credit) == 200.0 and int(S.strikes) == 0, "zeszyt po terminie: 40%% gotówki idzie na poczet towaru, bez kar i liczenia wpadek")
	S.credit = cr_keep
	S.credit_due = due_keep
	S.cash = cash_keep2
	S.stash.safe.cash = safe_keep
	M.add_trust("wiktor", 8.0)
	T.ok(G.box_settle() == 0.0 and float(S.stats.box_paid) == 900.0, "pusta skrzynka nic nie zmienia")
	# po terminie: blokada zamówień, a bez towaru — deska ratunku
	S.inv = G.new_store()
	S.credit = 400.0
	S.credit_due = S.t - 10.0
	T.ok(G.credit_overdue() and M.cart_block([{"p": "szron", "g": 5}]).contains("terminie"), "zeszyt po terminie blokuje zamówienia")
	var dr: Dictionary = M.order_cart([{"p": "dym", "g": 5}])
	T.ok(not dr.is_empty() and float(dr.cost) > G.wholesale_price("dym", 5) * 1.2, "bez towaru i z zaległym zeszytem Wiktor da jeszcze 5 g marihuany, ćwierć drożej")
	S.drops.clear()
	S.credit = 0.0
	S.lvl = 4
	# nieodebrana paczka przepada, a połowa jej ceny i tak ląduje na zeszycie
	var d3: Dictionary = M.order_cart([{"p": "dym", "g": 10}])
	S.t = float(d3.ready) + 1.0
	G.on_tick()
	var tr0: float = M.trust("wiktor")
	S.t = float(d3.expire) + 1.0
	G.on_tick()
	T.ok(S.drops.is_empty() and float(S.credit) == float(d3.cost) * 0.5 and M.trust("wiktor") < tr0, "nieodebrana paczka: przepada, połowa ceny na zeszycie, zaufanie spada")
	S.credit = 0.0
	# spalona skrytka: przy paczce czai się patrol (zdarza się dopiero, gdy policja prowadzi śledztwo)
	S.invest = 0.0
	var burned0 := 0
	for i in range(60):
		var dx: Dictionary = M.order_cart([{"p": "dym", "g": 5}])
		if dx.burned:
			burned0 += 1
		S.drops.clear()
	S.invest = 90.0
	var burned1 := 0
	for i in range(200):
		var dy: Dictionary = M.order_cart([{"p": "dym", "g": 5}])
		if dy.burned:
			burned1 += 1
		S.drops.clear()
	S.invest = 0.0
	T.ok(burned0 == 0 and burned1 > 8 and burned1 < 90, "skrytka bywa obserwowana dopiero przy zaawansowanym śledztwie (%d/200)" % burned1)
	var d5: Dictionary = M.order_cart([{"p": "dym", "g": 5}])
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
	S.drops.clear()
	# skup nadwyżek
	S.lvl = 4
	S.cash = 0.0
	var store: Dictionary = G.new_store()
	G.add_bulk(store, "dym", 100, 120.0)
	G.add_bulk(store, "dym", 67, 60.0)
	T.ok(M.bulk_buyer().id == "wiktor" and M.bulk_block(store, "dym", 100, 10.0).contains("od") and M.bulk_block(store, "dym", 67, 60.0).contains("Rozrobionego"), "skup: minimum 20 g, rozrobionego nie biorą")
	var pay: float = M.bulk_sell(store, "dym", 100, 100.0)
	var street: float = G.market_price("dym") * 100.0
	T.ok(pay > street * 0.3 and pay < street * 0.5 and S.cash == pay and absf(float(store.bulk.dym["100"]) - 20.0) < 0.01, "skup u Wiktora: 100 g za %d zł (ulica dałaby %d zł)" % [int(pay), int(street)])
	T.ok(M.bulk_left_today() == D.BULK_SELL_DAY * 4 - 100 and M.bulk_block(store, "dym", 100, 20.0) == "", "dzienny limit skupu maleje (zostało %d g)" % M.bulk_left_today())
	G.add_bulk(store, "dym", 100, 200.0)
	T.ok(M.bulk_block(store, "dym", 100, 100.0).contains("limit"), "ponad dzienny limit skup nie weźmie")
	var rate4: float = M.bulk_buyer().rate
	S.lvl = 6
	T.ok(float(M.bulk_buyer().rate) > rate4 + 0.05, "od 6. poziomu Wiktor płaci za nadwyżki lepiej (%d%% zamiast %d%% ceny ulicznej)" % [int(float(M.bulk_buyer().rate) * 100.0), int(rate4 * 100.0)])
	# sklep w telefonie: rozmowa z Wiktorem → telefon na bok → koszyk → powrót do rozmowy
	S.cash = 3000.0
	T.ok(G.order_goods("dym", 5) and String(S.drops[0].vendor) == "wiktor", "proste zamówienie jednej paczki dalej działa")
	G.chat("wiktor", "Pisz, co ci potrzeba.", false, true)
	G.ui.open_phone("sms")
	G.ui.phone.chat_id = "wiktor"
	G.ui.phone.render()
	await T.frames(2)
	var apps := []
	for a in G.ui.phone.APPS:
		apps.append(String(a[0]))
	T.ok(not apps.has("hurt") and G.ui.phone.hot.size() >= 2, "Giełdy już nie ma — pod rozmową z Wiktorem są kafle „Zamów towar” i „Skrzynka”")
	G.ui.phone.hotkey(1)
	await T.frames(3)
	T.ok(G.ui.mode == "phone" and G.ui.phone.app == "sklep" and G.ui.phone._landscape, "„Zamów towar” kładzie telefon na bok i pokazuje sklep")
	G.ui.phone.shop.tab = "sell"
	G.add_bulk(S.inv, "dym", 100, 40.0)
	G.ui.phone.render()
	await T.frames(2)
	G.ui.phone.shop.tab = "buy"
	G.ui.phone.shop.cart = [{"p": "krysztal", "g": 20}]
	G.ui.phone.render()
	await T.frames(2)
	var n0: int = S.drops.size()
	G.ui.phone.shop_send()
	await T.frames(2)
	T.ok(S.drops.size() == n0 + 1 and G.ui.phone.app == "sms" and G.ui.phone.chat_id == "wiktor" and not G.ui.phone._landscape, "wysłane zamówienie wraca do rozmowy, telefon staje pionowo")
	G.ui.phone.shop_open()
	await T.frames(2)
	G.ui.phone.back()
	await T.frames(2)
	T.ok(G.ui.phone.app == "sms" and not G.ui.phone._landscape, "„wstecz” w sklepie wraca do rozmowy")
	G.ui.close_all()
	G.ui.open_phone("")
	await T.frames(2)
	T.ok(G.ui.phone.cc.visible and not G.ui.phone.cc2.visible, "ponownie otwarty telefon stoi pionowo")
	G.ui.close_all()
	for a in G.main.drop_actors.keys():
		G.main.drop_gone({"id": a})
	G.S = keep
