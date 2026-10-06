extends RefCounted
## Testy strojów: kupno i zakładanie, wpływ na szybkość, kondycję, kieszenie, widoczność,
## podejrzliwość patroli (w tym kominiarka), świadków, ceny u klientów; szafa w ekwipunku; zapis.


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
	# szafa w ekwipunku: podgląd każdego stroju, kominiarka na głowie
	G.ui.open_inventory("", "wear")
	await T.frames(2)
	var shown := 0
	var masked_ok := false
	for id in D.OUTFITS:
		G.ui.inv.wear_sel = id
		G.ui.inv.render()
		await T.frames(1)
		if G.ui.inv.rig_outfit == id and is_instance_valid(G.ui.inv.rig.root):
			shown += 1
		if id == "kominiarka":
			for ch in G.ui.inv.rig.skel.get_children():
				if ch is BoneAttachment3D and String(ch.bone_name) == "Bip01 Head" and ch.get_child_count() >= 3:
					masked_ok = true
	T.ok(shown == D.OUTFITS.size() and masked_ok, "szafa pokazuje wszystkie %d strojów na postaci, kominiarka siedzi na głowie" % shown)
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
	G.S = keep
	G.main.teleport(back_loc, back_pos, 0.0)
	await T.frames(2)
