extends RefCounted
## Testy wymiany z klientem: taca (to, co kładziesz), mniej albo więcej towaru, niż zamówił,
## szansa w procentach przy brakującym gramie, wpadka i jej skutki, dokładka gratis.


static func _deal(want: int, agreed: float, st: Dictionary) -> Dictionary:
	var who: Dictionary = G.cust_def("dominik").duplicate()
	who["st"] = st
	var d: Dictionary = G.deal_start({"who": who, "product": "dym", "grams": want, "order": null, "street": false, "agreed": agreed})
	d.tol = 5.0
	G.deal_offer_clear(d)
	return d


static func _st() -> Dictionary:
	return {"sat": 60.0, "loy": 40.0, "hunger": 0.5, "grams": 10, "deals": 6, "known": {}, "owes": 0.0}


static func run(T) -> void:
	var keep: Dictionary = G.S
	G.S = G.new_state()
	var S: Dictionary = G.S
	S.cash = 0.0
	G.add_pack(S.inv, "dym", 100, 6)
	G.add_pack(S.inv, "dym", 100, 2, 2)
	G.add_pack(S.inv, "dym", 70, 1, 3)
	G.add_pack(S.inv, "szron", 100, 2)

	# --- taca: pusta na start, przyjmuje tylko zamówiony towar, pilnuje stanu kieszeni
	var d: Dictionary = _deal(4, 50.0, _st())
	T.ok(int(d.qty) == 0 and int(d.sum) == 200 and G.deal_ref_sum(d) == 200 and G.deal_short_chance(d) == 0.0, "taca: na start pusta, suma stoi na umówionej (4 g × 50 zł)")
	T.ok(G.deal_offer_add(d, "szron", 100, 1, 1) != "" and int(d.qty) == 0, "taca: innego towaru, niż klient zamówił, położyć się nie da")
	T.ok(G.deal_offer_add(d, "dym", 100, 2, 5) == "" and int(d.qty) == 4 and G.deal_have(d, "dym", 100, 2) == 0, "taca: kładzie najwyżej tyle paczek, ile masz (2 × 2 g)")
	T.ok(G.deal_offer_add(d, "dym", 100, 2, 1) != "", "taca: gdy paczki się skończyły, kolejnej nie dołożysz")
	G.deal_offer_take(d, 100, 2, 1)
	T.ok(int(d.qty) == 2 and G.deal_have(d, "dym", 100, 2) == 1 and int(d.sum) == 200, "taca: zdjęta paczka wraca do kieszeni, suma zostaje")
	G.deal_offer_add(d, "dym", 100, 1, 1)
	# --- mniej, niż zamówił: 3 g z 4 g = 75% szans, że zapłaci całość
	T.ok(int(d.qty) == 3 and absf(G.deal_short_chance(d) - 0.75) < 0.001, "3 g z 4 g przy pełnej sumie: 75%% szans (jest %d%%)" % int(round(G.deal_short_chance(d) * 100.0)))
	G.deal_set_sum(d, 150)
	T.ok(G.deal_short_chance(d) == 1.0 and int(d.pct) == 0, "3 g i suma za 3 g: uczciwie, żadnego ryzyka")
	G.deal_set_sum(d, 175)
	T.ok(absf(G.deal_short_chance(d) - 3.0 / 3.5) < 0.001, "suma pośrednia — szansa pośrednia (3 g za cenę 3,5 g: %d%%)" % int(round(G.deal_short_chance(d) * 100.0)))
	G.deal_set_sum(d, 200)
	d.st["shorted"] = 2
	T.ok(absf(G.deal_short_chance(d) - 0.75 * 0.85 * 0.85) < 0.001, "klient, który dwa razy Cię złapał, patrzy na ręce (szansa %d%%)" % int(round(G.deal_short_chance(d) * 100.0)))
	G.deal_offer_clear(d)
	G.deal_autofill(d)
	T.ok(int(d.qty) == 4 and int(d.sum) == 200 and G.deal_short_chance(d) == 1.0, "„dobierz” układa komplet i liczy umówioną sumę")
	G.deal_leave(d)

	# --- rzut: w wielu próbach udaje się mniej więcej trzy razy na cztery
	var won := 0
	var caught := 0
	var cash0 := float(S.cash)
	for i in range(300):
		G.add_pack(S.inv, "dym", 100, 3)
		var st: Dictionary = _st()
		var d2: Dictionary = _deal(4, 50.0, st)
		G.deal_offer_add(d2, "dym", 100, 1, 3)
		var packs0: int = G.packed_total(S.inv)
		G.deal_hand(d2)
		if d2.sold:
			won += 1
			if G.packed_total(S.inv) != packs0 - 3:
				won = -9999
		else:
			caught += 1
			if d2.over or not d2.caught or float(st.sat) >= 60.0 or int(st.get("shorted", 0)) != 1 or G.deal_short_chance(d2) != 0.0:
				caught = -9999
			G.take_pack(S.inv, "dym", 100, 3)
			G.deal_leave(d2)
	T.ok(won > 195 and won < 255 and caught > 0, "3 g z 4 g: udaje się około 75%% razy (%d z 300), wpadka zostawia rozmowę otwartą i psuje zadowolenie" % won)
	T.ok(absf(float(S.cash) - cash0 - float(won) * 200.0) < 0.5, "udana próba: klient płaci pełną umówioną sumę (200 zł za 3 g)")

	# --- wpadka: drugi raz ten sam numer nie przejdzie, ale można dołożyć albo zejść z ceny
	S.cash = 0.0
	var st3: Dictionary = _st()
	var d3: Dictionary = _deal(4, 50.0, st3)
	G.deal_offer_add(d3, "dym", 100, 1, 3)
	d3["caught"] = true
	var sat3 := float(st3.sat)
	G.deal_hand(d3)
	T.ok(not d3.over and not d3.sold and float(st3.sat) == sat3, "po wpadce kolejna próba z tym samym brakiem nie przechodzi (i nie karze drugi raz)")
	G.deal_set_sum(d3, G.deal_fair_sum(d3))
	G.deal_hand(d3)
	T.ok(d3.sold and absf(float(S.cash) - 150.0) < 0.5, "zejście do sumy za 3 g załatwia sprawę: 150 zł")

	# --- więcej, niż zamówił: zadowolenie i lojalność rosną wyraźniej niż przy zwykłej wymianie
	var o_a: Dictionary = G.make_order(G.cust_def("dominik"))
	G.unlock_client("dominik")
	G.reply_order(o_a.id, "accept")
	var want_a := int(o_a.grams)
	G.take_pack(S.inv, "dym", 100, 99)
	G.take_pack(S.inv, "dym", 100, 99, 2)
	G.add_pack(S.inv, "dym", 100, want_a * 2 + 4)
	var cs: Dictionary = S.cust.dominik
	cs.sat = 50.0
	cs.loy = 20.0
	var who_a: Dictionary = G.cust_def("dominik").duplicate()
	who_a["st"] = cs
	var da: Dictionary = G.deal_start({"who": who_a, "product": "dym", "grams": want_a, "order": o_a, "street": false, "agreed": o_a.agreed})
	G.deal_hand(da)
	var sat_plain := float(cs.sat) - 50.0
	var loy_plain := float(cs.loy) - 20.0
	T.ok(da.sold and G.find_order(o_a.id) == null, "zwykła wymiana: komplet z automatu, zamówienie zamknięte")
	var o_b: Dictionary = G.make_order(G.cust_def("dominik"))
	G.reply_order(o_b.id, "accept")
	var want_b := int(o_b.grams)
	cs.sat = 50.0
	cs.loy = 20.0
	var db: Dictionary = G.deal_start({"who": who_a, "product": "dym", "grams": want_b, "order": o_b, "street": false, "agreed": o_b.agreed})
	G.deal_offer_clear(db)
	G.deal_offer_add(db, "dym", 100, 1, want_b + 2)
	var gift: float = G.deal_gift(db)
	G.deal_hand(db)
	T.ok(db.sold and absf(gift - 2.0) < 0.01 and float(cs.sat) - 50.0 > sat_plain + 1.0 and float(cs.loy) - 20.0 > loy_plain, "dwa gramy gratis: zadowolenie +%.1f (zwykle +%.1f), lojalność rośnie mocniej" % [float(cs.sat) - 50.0, sat_plain])
	# nadwyżka, za którą każesz dopłacić w całości, prezentem nie jest — i klient może nie chcieć tyle wydać
	var dc: Dictionary = _deal(4, 50.0, _st())
	G.add_pack(S.inv, "dym", 100, 8)
	G.deal_offer_add(dc, "dym", 100, 1, 6)
	T.ok(int(dc.sum) == 200 and G.deal_gift(dc) == 2.0 and int(dc.pct) < 0, "6 g za umówione 200 zł: dwa gramy w prezencie, cena poniżej oczekiwań")
	G.deal_set_sum(dc, 300)
	T.ok(G.deal_gift(dc) == 0.0 and float(dc.pct) > float(dc.tol), "6 g za 300 zł: żadnego prezentu, a suma ponad to, co klient chciał wydać")
	G.deal_hand(dc)
	T.ok(not dc.sold and dc.pushed and int(dc.sum) <= 250, "za drogo — klient wraca do sumy, którą przełknie (%d zł)" % int(dc.sum))
	G.deal_leave(dc)

	# --- pusta taca: nie ma czego podać
	var de: Dictionary = _deal(2, 50.0, _st())
	G.deal_hand(de)
	T.ok(not de.over and not de.sold and String(de.speech) != "", "pusta taca: klient pyta o towar, nic się nie dzieje")
	G.deal_leave(de)
	S.orders.clear()
	G.S = keep
