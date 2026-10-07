extends RefCounted
## Testy produkcji: uprawa (woda, nawóz, przycinanie, tryby lamp), suszenie, synteza z etapami
## wymagającymi gracza, zapach / prąd / ryzyko, nalot, meble ze stanowiskami, stare zapisy, okna.
## Wołane z selftest.gd (T = węzeł testu). Zakłada kupiony garaż z lampą LED.


static func _run(P, minutes: float) -> void:
	var left := minutes
	while left > 0.0:
		P.tick(minf(10.0, left))
		left -= 10.0


static func run(T) -> void:
	var P = G.Prod
	var S: Dictionary = G.S
	var U = G.ui
	var room := "garage"
	var keep_cash: float = S.cash
	var keep_t: float = S.t
	S.lvl = maxi(int(S.lvl), 8)
	S.cash = 50000.0
	S.items["nasiona"] = 6
	S.items["nawoz"] = 2
	S.items["chemia"] = 5
	S.items["doniczka"] = 3
	var lamp := -1
	for i in range(S.hide[room].items.size()):
		if String(S.hide[room].items[i].f) == "lampa_led":
			lamp = i
	var tent := lamp
	T.ok(lamp >= 0 and P.lamps(room).size() == 1, "lampa LED wisi w garażu")
	P.hide(room).pots.clear()

	# ---------------------------------------------------------------- doniczki: przedmiot ze sklepu, stawiany w kryjówce
	var lx: float = S.hide[room].items[lamp].x
	var lz: float = S.hide[room].items[lamp].z
	T.ok(P.pot_valid(room, lx - 0.4, lz) and not P.pot_valid(room, 99.0, 0.0) and not P.pot_valid(room, 0.0, 4.2), "doniczka mieści się pod lampą, ale nie w ścianie ani w drzwiach")
	T.ok(P.pot_place(room, lx - 0.4, lz) and S.items["doniczka"] == 2 and P.pots(room).size() == 1, "postawienie zużywa doniczkę z plecaka")
	T.ok(not P.pot_valid(room, lx - 0.3, lz) and P.pot_place(room, lx + 0.3, lz), "doniczki nie wchodzą jedna w drugą; druga staje obok")
	T.ok(P.pot_place(room, -0.4, 1.9) and S.items["doniczka"] == 0 and not P.pot_place(room, -1.0, 1.9), "trzecia poza lampą; bez doniczek nic nie postawisz")
	T.ok(P.light_at(room, lx - 0.4, lz) == 0 and P.light_at(room, -0.4, 1.9) == -1, "światło: pod lampą tak, w kącie nie")
	T.ok(not G.furn_valid(room, "skrzynia", lx - 0.4, lz, 0), "mebla nie postawisz na doniczce")
	T.ok(G.world.pot_nodes[room].size() == 3, "doniczki stoją w świecie gry")
	var menu0: Array = G.main.pot_menu(room, 0)
	T.ok(menu0.size() == 2 and String(menu0[0].id) == "seed" and menu0[0].ok, "pusta doniczka: posadź albo zabierz")

	# ---------------------------------------------------------------- krzak: sadzenie, woda, czas
	T.ok(P.plant_seed(room, 0) and S.items["nasiona"] == 5 and not P.plant_seed(room, 0), "jedno nasiono = jeden krzak; zajętej doniczki nie obsadzisz drugi raz")
	T.ok(P.plant_seed(room, 2), "drugi krzak rośnie bez lampy")
	var j: Dictionary = P.plant_of(room, 0)
	var dark: Dictionary = P.plant_of(room, 2)
	T.ok(P.plant_stage(j) == "Sadzonki" and P.pot_label(room, 0).contains("sadzonki") and P.pot_label(room, 1) == "Pusta doniczka", "start: etap „Sadzonki”")
	var menu1: Array = G.main.pot_menu(room, 0)
	var ids: Array = []
	for o in menu1:
		ids.append(String(o.id))
	T.ok(ids == ["check", "water", "fert", "cut"], "krzak ma cztery czynności: sprawdź, podlej, nawóz, zetnij")
	T.ok(P.plant_cut_kind(room, 0) == "early" and P.plant_can_fert(room, 0), "sadzonki się nie przycina, nawozić można")
	j.water = 100.0
	dark.water = 100.0
	_run(P, 600.0)
	T.ok(absf(float(j.prog) - 10.0 / 30.0) < 0.02 and absf(float(j.water) - 58.0) < 3.0, "po 10 h pod lampą: 1/3 cyklu, wody ubyło do %d%%" % int(j.water))
	T.ok(absf(float(dark.prog) - float(j.prog) * 0.4) < 0.01, "bez lampy krzak rośnie 2,5 raza wolniej (%d%% wobec %d%%)" % [int(float(dark.prog) * 100.0), int(float(j.prog) * 100.0)])
	T.ok(P.plant_stage(j) == "Wzrost" and P.plant_cut_kind(room, 0) == "trim", "faza wzrostu: sekator przycina liście")
	var f0: Dictionary = P.plant_forecast(room, 0)
	T.ok(P.plant_cut(room, 0).kind == "trim" and P.plant_cut_kind(room, 0) == "early" and int(P.plant_forecast(room, 0).pur) > int(f0.pur), "przycięcie raz na krzak podnosi czystość (%d%% → %d%%)" % [int(f0.pur), int(P.plant_forecast(room, 0).pur)])
	T.ok(P.plant_fert(room, 0) and S.items["nawoz"] == 1 and float(P.plant_forecast(room, 0).g) > float(f0.g) * 1.2, "nawóz: plon %d g → %d g" % [int(f0.g), int(P.plant_forecast(room, 0).g)])
	T.ok(not P.plant_fert(room, 0), "drugiej dawki nawozu nie przyjmie")
	T.ok(int(P.plant_forecast(room, 2).pur) < int(f0.pur), "krzak bez światła wyjdzie słabszy")
	# bez podlewania ziemia wysycha: wzrost staje, kondycja leci
	_run(P, 14.0 * 60.0)
	var stuck := float(j.prog)
	T.ok(float(j.water) <= 0.0 and stuck < 0.8, "bez podlewania woda się kończy (postęp stanął na %d%%)" % int(stuck * 100.0))
	_run(P, 4.0 * 60.0)
	T.ok(absf(float(j.prog) - stuck) < 0.001 and float(j.health) < 85.0, "na sucho rośliny nie rosną i marnieją (kondycja %d%%)" % int(j.health))
	T.ok(P.pot_label(room, 0).contains("SUCHO"), "napis przy celowniku krzyczy, że sucho")
	var info: Dictionary = P.plant_info(room, 0)
	T.ok(not info.is_empty() and String(info.notes[0][1]) == "bad" and bool(info.fert) and bool(info.trim), "karta „Sprawdź” pokazuje stan krzaka i ostrzega o suszy")
	var dry_fc: Dictionary = P.plant_forecast(room, 0)
	T.ok(P.plant_water(room, 0) and float(j.water) == 100.0, "podlanie napełnia do pełna")
	# 8 godzin, nie 9: postęp po suszy stoi na 69–70% i przy dziewięciu krzak potrafił dojrzeć co do minuty
	_run(P, 8.0 * 60.0)
	T.ok(float(j.prog) > stuck + 0.2, "po podlaniu znowu rośnie")
	T.ok(P.plant_stage(j) == "Kwitnienie" and not P.plant_can_fert(room, 0), "kwitnienie: na nawóz już za późno (%s, %d%%)" % [P.plant_stage(j), int(float(j.prog) * 100.0)])
	P.plant_water(room, 0)
	_run(P, 12.0 * 60.0)
	T.ok(float(j.prog) >= 1.0 and P.plant_stage(j) == "Dojrzała" and P.plant_cut_kind(room, 0) == "harvest", "krzak dojrzały: sekator robi zbiór")
	T.ok(float(dry_fc.g) < float(f0.g) * 1.25 and int(P.plant_forecast(room, 0).pur) % 5 == 0, "zaniedbanie kosztuje plon; czystość własnej uprawy to zawsze „czysty” krok")
	# przejrzewanie
	var h_ready: float = j.health
	_run(P, 30.0 * 60.0)
	T.ok(float(j.health) < h_ready and P.plant_stage(j) == "Przejrzała", "zostawiony za długo krzak traci na jakości")
	# ścięcie przed czasem: młody krzak przepada
	dark.prog = 0.1
	T.ok(float(P.plant_cut(room, 2).g) == 0.0 and P.plant_of(room, 2) == null and P.wet_total(room) < 0.01, "ścięty przed kwitnieniem krzak nic nie daje")
	T.ok(P.pot_take(room, 2) and S.items["doniczka"] == 1 and P.pots(room).size() == 2 and not P.pot_take(room, 0), "pustą doniczkę można zabrać, obsadzonej nie")

	# ---------------------------------------------------------------- zbiór i suszenie
	var fc: Dictionary = P.plant_forecast(room, 0)
	var res: Dictionary = P.plant_cut(room, 0)
	T.ok(String(res.kind) == "harvest" and absf(P.wet_total(room) - float(fc.g)) < 0.01 and P.plant_of(room, 0) == null, "zbiór: %d g świeżego suszu czeka na suszarkę" % int(fc.g))
	T.ok(G.goods_total(S.stash[room]) < 0.01, "niewysuszony zbiór nie jest jeszcze towarem")
	T.ok(G.furn_buy_place(room, "suszarka", -2.3, -1.6, 0) and G.furn_buy_place(room, "filtr", -2.4, 3.2, 0), "wstawiona suszarka i filtr węglowy")
	var dryer: int = S.hide[room].items.size() - 2
	T.ok(P.kind(room, dryer) == "dry" and P.dry_start(room, dryer) and P.wet_total(room) < 0.01, "suszarka przyjmuje cały zbiór")
	T.ok(not P.dry_start(room, dryer), "zajęta suszarka nie przyjmie drugiej partii")
	_run(P, 4.0 * 60.0)
	T.ok(P.collect(room, dryer).is_empty(), "po 4 h susz jeszcze mokry")
	_run(P, 4.1 * 60.0)
	var dried: Dictionary = P.collect(room, dryer)
	T.ok(not dried.is_empty() and absf(G.goods_total(S.stash[room]) - float(fc.g)) < 0.6, "po 8 h: %d g marihuany w skrytce garażu" % int(G.goods_total(S.stash[room])))
	var mixed := false
	for k in S.stash[room].bulk.dym:
		if G.is_mix(int(k)):
			mixed = true
	T.ok(not mixed and int(dried.pur) == int(fc.pur), "własny towar nie ma znacznika mieszanki")

	# ---------------------------------------------------------------- tryb lamp, pompa
	T.ok(P.plant_seed(room, 0), "drugi krzak w tej samej doniczce")
	j = P.plant_of(room, 0)
	var st_a: Dictionary = P.stats(room)
	T.ok(P.lamp_toggle(room, lamp) == 1 and P.light_at(room, lx - 0.4, lz) == 1, "lampa przełącza się na cykl 24/0")
	var st_b: Dictionary = P.stats(room)
	T.ok(float(st_b.power) > float(st_a.power) * 1.5 and float(st_b.smell) > float(st_a.smell), "lampy 24/0: więcej prądu (%d → %d zł) i zapachu" % [int(st_a.power), int(st_b.power)])
	var t_slow: float = 30.0 * 60.0
	T.ok(P.plant_minutes_left(room, 0) < t_slow * 0.8, "lampy 24/0 skracają cykl do %d h" % int(P.plant_minutes_left(room, 0) / 60.0))
	T.ok(G.furn_buy_place(room, "zbiornik", -2.4, 2.2, 0), "wstawiony zbiornik z pompą")
	_run(P, 23.0 * 60.0)
	T.ok(float(j.water) >= 70.0 and float(j.prog) >= 1.0 and float(j.health) > 95.0, "z pompą krzak sam dochodzi do końca w dobrej kondycji")
	T.ok(int(P.plant_forecast(room, 0).pur) < int(fc.pur) + 20, "mocne lampy dają trochę słabszy towar")

	# ---------------------------------------------------------------- zapach, filtr, ryzyko
	var with_f: Dictionary = P.stats(room)
	var fi := -1
	for i in range(S.hide[room].items.size()):
		if String(S.hide[room].items[i].f) == "filtr":
			fi = i
	var filt_item: Dictionary = S.hide[room].items[fi]
	S.hide[room].items[fi] = {"f": "krzeslo", "x": filt_item.x, "z": filt_item.z, "r": 0}
	var no_f: Dictionary = P.stats(room)
	S.hide[room].items[fi] = filt_item
	T.ok(absf(float(with_f.smell) - float(no_f.smell) * 0.4) < 0.01 and float(with_f.risk) <= float(no_f.risk), "filtr węglowy: zapach %d → %d, ryzyko %d → %d" % [int(no_f.smell), int(with_f.smell), int(no_f.risk), int(with_f.risk)])
	T.ok(P.raid_chance(5.0) == 0.0 and P.raid_chance(40.0) > 0.05 and P.raid_chance(90.0) > P.raid_chance(40.0) * 2.0 and P.raid_chance(95.0) < 0.36, "szansa nalotu rośnie z ryzykiem (40 → %d%%, 90 → %d%% na dobę)" % [int(P.raid_chance(40.0) * 100.0), int(P.raid_chance(90.0) * 100.0)])
	P.plant_cut(room, 0)
	P.hide(room).wet.clear()
	var idle: Dictionary = P.stats(room)
	T.ok(float(idle.risk) == 0.0 and float(idle.smell) == 0.0, "pusta kryjówka nie ściąga uwagi")

	# ---------------------------------------------------------------- stół laboratoryjny
	T.ok(G.furn_buy_place(room, "lab", 2.5, 2.9, 1), "wstawiony stół laboratoryjny")
	var lab: int = S.hide[room].items.size() - 1
	var names: Array = []
	for e in P.recipes_for(room, lab):
		names.append(String(e.id))
	T.ok(names.has("amfetamina") and names.has("metamfetamina") and not names.has("konopie"), "przy stole: amfetamina i metamfetamina (z danych, nie z kodu)")
	T.ok(P.start(room, lab, "amfetamina") and S.items["chemia"] == 4, "synteza zużywa zestaw chemikaliów")
	j = P.job(room, lab)
	T.ok(int(j.mode) == 1 and P.stage_name(j) == "Reakcja", "start w średniej temperaturze, etap „Reakcja”")
	_run(P, 3.0 * 60.0)
	T.ok(int(j.hold) == 0 and absf(float(j.prog) - 0.45) < 0.001 and P.stage_name(j) == "Przelej i schłodź", "po reakcji synteza czeka na gracza")
	T.ok(G.station_label(room, lab).contains("przelej"), "napis nad stołem woła do roboty")
	_run(P, 60.0)
	T.ok(absf(float(j.prog) - 0.45) < 0.001 and float(j.health) == 100.0, "godzina zwłoki nic nie psuje, ale nic się też nie dzieje")
	_run(P, 3.0 * 60.0)
	T.ok(float(j.health) < 100.0, "zostawiona na 4 godziny — jakość spada (kondycja %d%%)" % int(j.health))
	T.ok(P.proceed(room, lab) and int(j.hold) == -1, "przelanie odblokowuje kolejny etap")
	_run(P, 3.0 * 60.0)
	T.ok(float(j.prog) >= 1.0, "synteza skończona")
	var lf: Dictionary = P.forecast(j)
	var before: float = G.goods_total(S.stash[room])
	res = P.collect(room, lab)
	T.ok(String(res.p) == "szron" and not res.get("wet", false) and absf(G.goods_total(S.stash[room]) - before - float(lf.g)) < 0.6, "amfetamina: %d g (%d%%) prosto do skrytki" % [int(lf.g), int(lf.pur)])
	# temperatura: jakość kontra czas i smród
	P.start(room, lab, "amfetamina")
	j = P.job(room, lab)
	P.set_mode(room, lab, 0)
	var cold: Dictionary = P.forecast(j)
	var cold_t: float = P.minutes_left(j)
	var cold_s: float = P.stats(room).smell
	P.set_mode(room, lab, 2)
	var hot: Dictionary = P.forecast(j)
	T.ok(int(cold.pur) > int(hot.pur) + 10 and cold_t > P.minutes_left(j) * 1.8 and cold_s < float(P.stats(room).smell) * 0.6, "temperatura: niska %d%% w %d min, wysoka %d%% w %d min i dwa razy większy smród" % [int(cold.pur), int(cold_t), int(hot.pur), int(P.minutes_left(j))])
	# przypalenie przy wysokiej temperaturze zdarza się, ale nie zawsze
	var burnt := 0
	for i in range(60):
		P.discard(room, lab)
		S.items["chemia"] = 3
		P.start(room, lab, "amfetamina")
		P.set_mode(room, lab, 2)
		var jj: Dictionary = P.job(room, lab)
		jj.prog = 0.99
		P.tick(10.0)
		if jj.burnt:
			burnt += 1
	T.ok(burnt >= 3 and burnt <= 25, "wysoka temperatura: przypalona mniej więcej co szósta partia (%d/60)" % burnt)

	# ---------------------------------------------------------------- meble ze stanowiskami
	T.ok(not G.furn_remove(room, lab), "stanowiska z wsadem nie da się zdjąć")
	var lab_job: Dictionary = P.job(room, lab)
	var chair := -1
	for i in range(S.hide[room].items.size()):
		if String(S.hide[room].items[i].f) == "kanapa":
			chair = i
	var cash_rm: float = S.cash
	T.ok(chair >= 0 and chair < lab and G.furn_remove(room, chair) and G.owned("kanapa") == 1 and S.cash == cash_rm, "zdjęty mebel wraca na stan (bez pieniędzy)")
	T.ok(G.furn_sell("kanapa") and G.owned("kanapa") == 0 and S.cash == cash_rm + round(float(G.furn_def("kanapa").price) * 0.5) and not G.furn_sell("kanapa"), "ze stanu można go odsprzedać w hurtowni za połowę ceny")
	T.ok(is_same(P.job(room, lab - 1), lab_job) and P.kind(room, lab - 1) == "lab" and P.job(room, lab) == null, "zadania przesuwają się razem z numeracją mebli")
	lab -= 1
	G.world.refresh_furniture(room)

	# ---------------------------------------------------------------- nalot
	G.add_bulk(S.stash[room], "dym", 70, 40.0)
	S.stash[room].cash = 1200.0
	var heat0: float = S.heat
	var inv0: float = S.invest
	var seat: String = G.player.loc
	G.player.loc = "out"
	res = P.raid(room)
	G.player.loc = seat
	T.ok(res.found and float(res.lost_g) > 40.0 and float(res.lost_cash) == 1200.0, "nalot zabiera towar (%d g) i gotówkę" % int(res.lost_g))
	T.ok(G.goods_total(S.stash[room]) < 0.01 and float(S.stash[room].cash) == 0.0 and P.hide(room).jobs.is_empty(), "po nalocie skrytka i stanowiska są puste")
	T.ok(S.hide[room].items.size() >= 5 and S.heat > heat0 and S.invest > inv0, "sprzęt zostaje, a policja ma Cię mocniej na oku")
	S.heat = heat0
	S.invest = 0.0
	res = P.raid(room)
	T.ok(not res.found, "nalot na pustą kryjówkę niczego nie znajduje")
	# zapowiedź: ostrzeżenie SMS-em trzy godziny wcześniej
	var chats0: int = S.chats.get("stas", []).size()
	P.hide(room)["raid_at"] = S.t + 200.0
	P.hide(room)["raid_warned"] = false
	P.raid_tick()
	T.ok(not P.hide(room).raid_warned and S.chats.get("stas", []).size() == chats0, "na ponad 3 godziny przed nalotem cisza")
	S.t += 30.0
	P.raid_tick()
	T.ok(P.hide(room).raid_warned and S.chats.get("stas", []).size() == chats0 + 1, "trzy godziny przed nalotem Staś ostrzega SMS-em")
	S.t += 175.0
	P.raid_tick()
	T.ok(not P.hide(room).has("raid_at"), "nalot odbywa się o zapowiedzianej porze")
	S.invest = 0.0

	# ---------------------------------------------------------------- rachunek za prąd
	P.plant_seed(room, 0)
	var bill: float = round(float(P.stats(room).power))
	S.cash = 1000.0
	P.hide(room).erase("raid_at")
	P.daily()
	P.hide(room).erase("raid_at")
	P.hide(room).erase("raid_warned")
	T.ok(bill > 5.0 and absf(S.cash - (1000.0 - bill)) < 0.01, "doba pracy kryjówki kosztuje %d zł prądu" % int(bill))

	# ---------------------------------------------------------------- okna
	# menu przy celowniku i karta krzaka
	U.set_aim_menu("Konopie — sadzonki", G.main.pot_menu(room, 0), 1)
	await T.frames(2)
	T.ok(U.aim_menu.visible and U.aim_rows[3].row.visible, "przy celowniku widać listę czterech czynności")
	U.show_plant_card(room, 0)
	await T.frames(2)
	T.ok(U.plant_card.visible, "„Sprawdź” otwiera kartę krzaka")
	U.hide_plant_card()
	U.set_aim_menu("", [], 0)
	T.ok(not U.aim_menu.visible and not U.plant_card.visible, "menu i karta znikają, gdy odwracasz wzrok")
	# czynności z animacją: w testach skutek jest natychmiastowy
	P.plant_of(room, 0).water = 30.0
	T.ok(G.main.care.play("water", room, 0) and float(P.plant_of(room, 0).water) == 100.0 and not G.main.care.busy(), "konewka podlewa wskazany krzak")
	U.open_station(room, lab)
	await T.frames(2)
	P.start(room, lab, "metamfetamina")
	var mj: Dictionary = P.job(room, lab)
	mj.prog = 0.4
	mj.hold = 0
	U.open_station(room, lab)
	await T.frames(2)
	mj.hold = -1
	mj.prog = 1.0
	U.open_station(room, lab)
	await T.frames(2)
	U.open_station(room, dryer if dryer < chair else dryer - 1)
	await T.frames(2)
	U.open_hideout(room)
	await T.frames(2)
	T.ok(U.mode == "modal", "okna stanowisk i stanu kryjówki otwierają się w każdym stanie")
	U.close_all()

	# ---------------------------------------------------------------- stary zapis
	P.hide(room).jobs.clear()
	P.hide(room).pots.clear()
	var n_items: int = S.hide[room].items.size()
	S.hide[room].items.append({"f": "regal_led", "x": 0.0, "z": -1.0, "r": 0})
	var oj: Dictionary = P.new_job("konopie", 4)
	oj.prog = 0.5
	oj.fert = true
	P.hide(room).jobs[str(n_items)] = oj
	P.migrate()
	T.ok(String(S.hide[room].items[n_items].f) == "lampa_led" and P.pots(room).size() == 4 and absf(float(P.plant_of(room, 3).prog) - 0.5) < 0.001 and P.plant_of(room, 0).fert and P.job(room, n_items) == null,
		"regał ze starego zapisu zamienia się w lampę i cztery doniczki z tym samym postępem")
	S.hide[room].items.remove_at(n_items)
	P.hide(room).pots.clear()
	G.world.refresh_furniture(room)
	P.hide(room).jobs.clear()
	G.world.update_stations()
	S.cash = keep_cash
	S.t = keep_t
	S.stash[room].cash = 0.0
