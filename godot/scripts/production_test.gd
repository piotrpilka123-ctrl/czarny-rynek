extends RefCounted
## Testy produkcji: uprawa (woda, nawóz, przycinanie, tryby lamp), suszenie, synteza z etapami
## wymagającymi gracza, zapach / prąd / ryzyko, nalot, meble ze stanowiskami, stare zapisy, okna.
## Wołane z selftest.gd (T = węzeł testu). Zakłada kupiony garaż z namiotem na pozycji 2.


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
	var tent := -1
	for i in range(S.hide[room].items.size()):
		if String(S.hide[room].items[i].f) == "namiot":
			tent = i
	T.ok(tent >= 0 and P.kind(room, tent) == "grow", "namiot jest stanowiskiem uprawy")

	# ---------------------------------------------------------------- uprawa: woda i czas
	T.ok(P.recipes_for(room, tent).size() == 1 and String(P.recipes_for(room, tent)[0].miss) == "", "w namiocie da się nastawić konopie")
	T.ok(P.start(room, tent, "konopie") and S.items["nasiona"] == 5, "zasianie zużywa paczkę nasion")
	T.ok(not P.start(room, tent, "konopie"), "zajętego stanowiska nie da się nastawić drugi raz")
	var j: Dictionary = P.job(room, tent)
	T.ok(int(j.pots) == 2 and P.stage_name(j) == "Sadzonki" and G.station_label(room, tent).contains("sadzonki"), "start: 2 doniczki, etap „Sadzonki”")
	T.ok(not P.can_trim(room, tent) and P.can_fert(room, tent), "sadzonek się nie przycina, nawozić można")
	_run(P, 600.0)
	T.ok(absf(float(j.prog) - 10.0 / 30.0) < 0.02 and absf(float(j.water) - 58.0) < 3.0, "po 10 h: 1/3 cyklu, wody ubyło do %d%%" % int(j.water))
	T.ok(P.stage_name(j) == "Wzrost" and P.can_trim(room, tent), "faza wzrostu: można przyciąć")
	var f0: Dictionary = P.forecast(j)
	T.ok(P.trim(room, tent) and not P.can_trim(room, tent) and int(P.forecast(j).pur) > int(f0.pur), "przycięcie raz na cykl podnosi czystość (%d%% → %d%%)" % [int(f0.pur), int(P.forecast(j).pur)])
	T.ok(P.fertilize(room, tent) and S.items["nawoz"] == 1 and float(P.forecast(j).g) > float(f0.g) * 1.2, "nawóz: plon %d g → %d g" % [int(f0.g), int(P.forecast(j).g)])
	T.ok(not P.fertilize(room, tent), "drugiej dawki nawozu nie przyjmie")
	# bez podlewania ziemia wysycha: wzrost staje, kondycja leci
	_run(P, 14.0 * 60.0)
	var stuck := float(j.prog)
	T.ok(float(j.water) <= 0.0 and stuck < 0.8, "bez podlewania woda się kończy (postęp stanął na %d%%)" % int(stuck * 100.0))
	_run(P, 4.0 * 60.0)
	T.ok(absf(float(j.prog) - stuck) < 0.001 and float(j.health) < 85.0, "na sucho rośliny nie rosną i marnieją (kondycja %d%%)" % int(j.health))
	T.ok(G.station_label(room, tent).contains("SUCHO"), "napis nad namiotem krzyczy, że sucho")
	var dry_fc: Dictionary = P.forecast(j)
	T.ok(P.water(room, tent) and float(j.water) == 100.0, "podlanie napełnia do pełna")
	_run(P, 9.0 * 60.0)
	T.ok(float(j.prog) > stuck + 0.2, "po podlaniu znowu rośnie")
	T.ok(P.stage_name(j) == "Kwitnienie" and not P.can_fert(room, tent), "kwitnienie: na nawóz już za późno")
	P.water(room, tent)
	_run(P, 12.0 * 60.0)
	T.ok(float(j.prog) >= 1.0 and P.stage_name(j) == "Gotowe" and G.station_label(room, tent).contains("zbierz"), "plon gotowy do zbioru")
	T.ok(float(dry_fc.g) < float(f0.g) * 1.25 and int(P.forecast(j).pur) % 5 == 0, "zaniedbanie kosztuje plon; czystość własnej uprawy to zawsze „czysty” krok")
	# przejrzewanie
	var h_ready: float = j.health
	_run(P, 30.0 * 60.0)
	T.ok(float(j.health) < h_ready, "zostawiony za długo plon traci na jakości")

	# ---------------------------------------------------------------- zbiór i suszenie
	var fc: Dictionary = P.forecast(j)
	var res: Dictionary = P.collect(room, tent)
	T.ok(res.get("wet", false) and absf(P.wet_total(room) - float(fc.g)) < 0.01 and P.job(room, tent) == null, "zbiór: %d g świeżego suszu czeka na suszarkę" % int(fc.g))
	T.ok(G.goods_total(S.stash[room]) < 0.01, "niewysuszony zbiór nie jest jeszcze towarem")
	T.ok(G.furn_place(room, "suszarka", -2.3, -1.6, 0) and G.furn_place(room, "filtr", -2.4, 3.2, 0), "wstawiona suszarka i filtr węglowy")
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
	T.ok(P.start(room, tent, "konopie"), "drugi cykl")
	j = P.job(room, tent)
	var st_a: Dictionary = P.stats(room)
	P.set_mode(room, tent, 1)
	var st_b: Dictionary = P.stats(room)
	T.ok(float(st_b.power) > float(st_a.power) * 1.5 and float(st_b.smell) > float(st_a.smell), "lampy 24/0: więcej prądu (%d → %d zł) i zapachu" % [int(st_a.power), int(st_b.power)])
	var t_slow: float = 30.0 * 60.0
	T.ok(P.minutes_left(j) < t_slow * 0.8, "lampy 24/0 skracają cykl do %d h" % int(P.minutes_left(j) / 60.0))
	T.ok(G.furn_place(room, "zbiornik", -2.4, 2.2, 0), "wstawiony zbiornik z pompą")
	_run(P, 23.0 * 60.0)
	T.ok(float(j.water) >= 70.0 and float(j.prog) >= 1.0 and float(j.health) > 95.0, "z pompą uprawa sama dochodzi do końca w dobrej kondycji")
	T.ok(int(P.forecast(j).pur) < int(fc.pur) + 20, "mocne lampy dają trochę słabszy towar")

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
	T.ok(absf(float(with_f.smell) - float(no_f.smell) * 0.4) < 0.01 and float(with_f.risk) < float(no_f.risk), "filtr węglowy: zapach %d → %d, ryzyko %d → %d" % [int(no_f.smell), int(with_f.smell), int(no_f.risk), int(with_f.risk)])
	T.ok(P.raid_chance(5.0) == 0.0 and P.raid_chance(40.0) > 0.05 and P.raid_chance(90.0) > P.raid_chance(40.0) * 2.0 and P.raid_chance(95.0) < 0.36, "szansa nalotu rośnie z ryzykiem (40 → %d%%, 90 → %d%% na dobę)" % [int(P.raid_chance(40.0) * 100.0), int(P.raid_chance(90.0) * 100.0)])
	P.collect(room, tent)
	P.hide(room).wet.clear()
	var idle: Dictionary = P.stats(room)
	T.ok(float(idle.risk) == 0.0 and float(idle.smell) == 0.0, "pusta kryjówka nie ściąga uwagi")

	# ---------------------------------------------------------------- stół laboratoryjny
	T.ok(G.furn_place(room, "lab", 2.5, 2.9, 1), "wstawiony stół laboratoryjny")
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
	T.ok(not G.furn_remove(room, lab), "stanowiska z wsadem nie da się sprzedać")
	var lab_job: Dictionary = P.job(room, lab)
	var chair := -1
	for i in range(S.hide[room].items.size()):
		if String(S.hide[room].items[i].f) == "kanapa":
			chair = i
	T.ok(chair >= 0 and chair < lab and G.furn_remove(room, chair), "sprzedaż wcześniejszego mebla")
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
	P.start(room, tent, "konopie")
	var bill: float = round(float(P.stats(room).power))
	S.cash = 1000.0
	P.hide(room).erase("raid_at")
	P.daily()
	P.hide(room).erase("raid_at")
	P.hide(room).erase("raid_warned")
	T.ok(bill > 5.0 and absf(S.cash - (1000.0 - bill)) < 0.01, "doba pracy kryjówki kosztuje %d zł prądu" % int(bill))

	# ---------------------------------------------------------------- okna
	U.open_station(room, tent)
	await T.frames(3)
	T.ok(U.mode == "modal" and U.station.view != null, "okno regału z rosnącą uprawą")
	U.station.view.play("water", func(): pass)
	await T.frames(4)
	T.ok(not U.station.view.busy(), "animacja czynności kończy się sama")
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
	S.hide[room]["grow"] = {str(tent): {"start": S.t - 600.0, "end": S.t + 600.0, "hits": 2}}
	P.migrate()
	var mig = P.job(room, tent)
	T.ok(mig != null and absf(float(mig.prog) - 0.5) < 0.01 and S.hide[room].grow.is_empty(), "uprawa ze starego zapisu przechodzi do nowego systemu")
	P.hide(room).jobs.clear()
	G.world.update_stations()
	S.cash = keep_cash
	S.t = keep_t
	S.stash[room].cash = 0.0
