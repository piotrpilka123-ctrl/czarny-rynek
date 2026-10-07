extends RefCounted
## Testy klubu, szpitala i komendy: nielegalne rzeczy, kontrola ochroniarza, trzy wpadki = szpital,
## utrata gotówki w szpitalu, konfiskata na komendzie, duża gotówka = węszenie po kryjówkach.


static func run(T) -> void:
	var keep: Dictionary = G.S
	G.S = G.new_state()
	var S: Dictionary = G.S

	# --- stary zapis sprzed zmian w pakowaniu i meblach wczytuje się i przelicza
	var old_save := {"cash": 1234.0, "lvl": 3, "items": {"woreczki": 37, "majeranek": 5}, "upg": {"waga": true, "plecak1": true},
		"stash": {"safe": {"bulk": {"dym": {"100": 12.0}}, "pack": {"dym": {"100": 4}}, "cash": 50.0, "items": {"woreczki": 20, "cukier": 3}}},
		"hide": {"garage": {"items": [{"f": "stol", "x": -1.6, "z": -3.6, "r": 0}], "jobs": {}}}}
	var mig: Dictionary = G.state_from_save(old_save)
	T.ok(int(mig.items.woreczki) == 0 and not mig.stash.safe.items.has("woreczki") and int(mig.stash.safe.items.cukier) == 3 and int(mig.items.majeranek) == 5, "stary zapis: woreczki znikają, reszta rzeczy zostaje")
	T.ok(int(mig.scale) == 1 and not mig.upg.has("waga") and bool(mig.upg.get("plecak1", false)), "stary zapis: kupiona „waga jubilerska” staje się wagą drugiej klasy, plecak zostaje")
	T.ok(mig.owned is Dictionary and mig.owned.is_empty() and mig.stash.has("loot") and G.goods_total(mig.stash.loot) == 0.0, "stary zapis: pusty stan sprzętu i pusty pojemnik podręczny")
	T.ok(float(mig.cash) == 1234.0 and float(mig.stash.safe.bulk.dym["100"]) == 12.0 and int(mig.stash.safe.pack.dym["100"]) == 4 and mig.hide.garage.items.size() == 1, "stary zapis: gotówka, towar i ustawione meble bez zmian")
	var P = G.player
	var back_loc: String = P.loc
	var back_pos: Vector3 = P.global_position
	var M = G.main

	# --- co jest nielegalne
	T.ok(G.illegal_size() == 0.0 and G.frisk_chance() == 0.0, "czyste kieszenie: woreczki to nie kontrabanda, kontrola nic nie znajdzie")
	G.add_pack(S.inv, "dym", 75, 3)
	var small := G.frisk_chance()
	T.ok(G.illegal_size() > 0.0 and small > 0.1 and small < 0.6, "trzy porcje w kieszeni: da się przemycić (ryzyko %d%%)" % int(small * 100.0))
	G.add_pack(S.inv, "dym", 75, 12)
	var big := G.frisk_chance()
	T.ok(big > small + 0.3, "więcej towaru = większe ryzyko wpadki (%d%%)" % int(big * 100.0))
	S.items["kurtka_kieszenie"] = 1
	G.gear_wear("kurtka_kieszenie")
	T.ok(G.frisk_chance() < big - 0.05, "kurtka z wewnętrznymi kieszeniami utrudnia kontrolę")
	G.gear_off("gora")
	S.items["kastet"] = 1
	T.ok(G.has_weapon() and G.frisk_chance() == 1.0, "broń piszczy na bramce zawsze")
	S.items["kastet"] = 0

	# --- klub: godziny, trzy wpadki jednej nocy
	S.t = 2.0 * 1440.0 + 13.0 * 60.0
	T.ok(not G.club_open(), "w południe klub jest zamknięty")
	S.t = 2.0 * 1440.0 + 22.0 * 60.0
	T.ok(G.club_open() and G.club_tries() == 0, "o 22:00 klub wpuszcza")
	var r0: Dictionary = G.club_frisk(0.999)
	T.ok(r0.ok and G.club_tries() == 0, "udany przemyt: wchodzisz, licznik wpadek stoi")
	var r1: Dictionary = G.club_frisk(0.0)
	T.ok(not r1.ok and int(r1.tries) == 1 and not r1.beaten and String(r1.found) != "", "wpadka: ochroniarz mówi, co znalazł, i nie wpuszcza")
	T.ok(G.carry_goods() > 0.0, "ochroniarz niczego nie zabiera")
	var r2: Dictionary = G.club_frisk(0.0)
	S.t += 180.0
	var r3: Dictionary = G.club_frisk(0.0)
	T.ok(int(r2.tries) == 2 and not r2.beaten and r3.beaten and int(r3.tries) == 3, "trzecia wpadka tej samej nocy (także po północy) kończy się pobiciem")
	S.t += 1440.0
	T.ok(G.club_tries() == 0, "następnej nocy ochroniarz zaczyna liczyć od nowa")

	# --- szpital: znika 20–70% gotówki, towar zostaje, postać jest obolała
	S.cash = 1000.0
	T.ok(G.hospital_loss(0.0) == 200.0 and G.hospital_loss(1.0) == 700.0, "szpital: strata od 20 do 70% gotówki przy sobie")
	var goods0 := G.carry_goods()
	var sp0: float = G.outfit_stat("speed", 1.0)
	var arr0 := int(S.arrests)
	var t0: float = S.t
	var hres: Dictionary = G.hospital_apply("beaten", 0.5)
	T.ok(float(S.cash) <= 550.0 and float(hres.cash) == 450.0, "pobity: z kieszeni zniknęło 45%% (%s)" % G.money(hres.cash))
	T.ok(G.carry_goods() == goods0 and int(S.arrests) == arr0, "pobity: towar zostaje, to nie zatrzymanie")
	T.ok(G.hurt() and G.outfit_stat("speed", 1.0) < sp0 and S.t > t0 + 300.0, "po szpitalu: kilka godzin w plecy i obolała postać biega wolniej")
	S.t += 3.0 * 1440.0
	T.ok(not G.hurt() and G.outfit_stat("speed", 1.0) == sp0, "po dobie–dwóch wraca do formy")
	S.items["nasiona"] = 3
	var sres: Dictionary = G.hospital_apply("shot", 0.0)
	T.ok(G.carry_goods() < 0.01 and int(S.items.nasiona) == 0 and int(S.arrests) == arr0 + 1 and float(sres.goods) > 0.0, "postrzelony przez policję: szpital i konfiskata jak przy zatrzymaniu")

	# --- komenda: wszystko nielegalne przepada, legalne zostaje
	S.flags.erase("watch_until")
	S.cash = 500.0
	S.invest = 0.0
	G.add_pack(S.inv, "szron", 80, 5)
	G.add_bulk(S.inv, "dym", 70, 10.0)
	S.items["chemia"] = 1
	S.items["kastet"] = 1
	var bags := int(S.items.woreczki)
	var ares: Dictionary = G.arrest_apply()
	T.ok(G.carry_goods() < 0.01 and int(S.items.chemia) == 0 and int(S.items.kastet) == 0 and int(S.items.woreczki) == bags, "zatrzymanie: towar, chemia i kastet przepadają, woreczki zostają")
	# notes z numerami przy sobie w chwili zatrzymania: trafia do akt i przyspiesza śledztwo
	var inv_keep_n: float = S.invest
	var cash_keep_n: float = S.cash
	var t_keep_n: float = S.t
	S.items["notes"] = 1
	var inv_n: float = S.invest
	var ares_n: Dictionary = G.arrest_apply()
	var with_notes: float = S.invest - inv_n
	S.arrests = int(S.arrests) - 1
	inv_n = S.invest
	G.arrest_apply()
	S.arrests = int(S.arrests) - 1
	T.ok(bool(ares_n.notes) and G.item("notes") == 0 and G.loot_text(ares_n).contains("notes") and with_notes > S.invest - inv_n + 5.0, "notes znaleziony przy zatrzymaniu: przepada i śledztwo rusza szybciej (+%d wobec +%d)" % [int(with_notes), int(S.invest - inv_n)])
	S.invest = inv_keep_n
	S.cash = cash_keep_n
	S.t = t_keep_n
	T.ok(float(ares.fine) > 0.0 and not ares.big and not G.watched() and ares.weapon, "mała gotówka: grzywna, zarzut za broń, bez węszenia")
	var inv_small: float = S.invest
	S.invest = 0.0
	S.cash = G.big_cash() + 500.0
	var bres: Dictionary = G.arrest_apply()
	T.ok(bres.big and G.watched() and float(S.invest) > inv_small - 5.0 + D.CASH_SUSPECT_INVEST - 0.1, "duża gotówka przy zatrzymaniu: śledztwo rośnie mocniej i policja węszy po kryjówkach")
	S.lvl = 6
	T.ok(G.big_cash() > D.CASH_SUSPECT * 2.0, "próg „dużej gotówki” rośnie z poziomem (%s na 6. poziomie)" % G.money(G.big_cash()))
	S.lvl = 1

	# --- przeszukanie mieszkania podczas węszenia
	G.add_pack(S.stash.safe, "dym", 75, 20)
	S.stash.safe.cash = 900.0
	G.store_items(S.stash.safe)["woreczki"] = 7
	var fr: Dictionary = G.Prod.flat_raid()
	T.ok(fr.found and G.goods_total(S.stash.safe) < 0.01 and float(S.stash.safe.cash) == 0.0 and int(G.store_items(S.stash.safe).get("woreczki", 0)) == 7, "przeszukanie mieszkania: towar i gotówka ze skrytki przepadają, legalne rzeczy zostają")
	var fr2: Dictionary = G.Prod.flat_raid()
	T.ok(not fr2.found and not G.watched(), "pusta skrytka: nic nie znaleźli i dają spokój")

	# --- świat: wnętrza, pobudka, wyjście
	T.ok(G.world.rooms.has("club") and G.world.rooms.has("szpital") and G.world.rooms.has("komisariat"), "klub, szpital i komenda mają wnętrza")
	for room in ["szpital", "komisariat"]:
		M.wake_in(room)
		await T.frames(3)
		var R: Dictionary = D.ROOMS[room]
		var pp: Vector3 = P.global_position
		T.ok(P.loc == room and absf(pp.x - float(R.cx)) < float(R.w) * 0.5 and absf(pp.z) < float(R.d) * 0.5 and P.fits_at(pp, false), "pobudka: %s — stoisz w wolnym miejscu w środku" % String(R.name))
		M.exit_room()
		await T.wait_busy()
		await T.frames(3)
		var dd: Dictionary = D.DOORS[room]
		T.ok(P.loc == "out" and Vector2(P.global_position.x - float(dd.x), P.global_position.z - float(dd.z)).length() < 3.0, "wyjście: %s — lądujesz pod drzwiami" % String(R.name))
	M.enter("szpital")
	await T.frames(3)
	T.ok(P.loc == "out", "do szpitala nie wchodzi się z ulicy")
	# wejście do klubu bez kontrabandy
	S.inv = G.new_store()
	S.items["nasiona"] = 0
	S.flags.erase("club")
	S.t = 5.0 * 1440.0 + 22.0 * 60.0
	G.ui.close_all()
	M.club_try()
	await T.wait_busy()
	await T.frames(3)
	T.ok(P.loc == "club", "czysty wchodzi do klubu")
	var buyers := 0
	for n in G.npcs.statics:
		if n.loc == "club" and n.has("want"):
			buyers += 1
	T.ok(buyers >= 6, "na parkiecie są imprezowicze, którzy kupują (%d)" % buyers)
	M.exit_room()
	await T.wait_busy()
	await T.frames(3)
	T.ok(P.loc == "out" and P.global_position.distance_to(G.world.club_door) < 4.0, "wyjście z klubu prowadzi przed wejście")
	# --- skrytki: znak sprejem, teren rośnie z klientami, dostawy wypadają dalej
	for c0 in D.CLIENTS:
		S.cust[c0.id].unlocked = c0.id == "dominik"
	var open0: Array = G.drops_open()
	T.ok(open0.has("smietnik") and open0.has("trzepak") and open0.has("zaulek") and open0.has("pawilon") and not open0.has("zbiornik") and not open0.has("zaklub"), "na początku skrytki są tylko w okolicy bloku i miejsc Dominika (%d)" % open0.size())
	var marks: int = 0
	var shown: int = 0
	G.world.refresh_drops()
	for id0 in G.world.drop_marks:
		marks += 1
		if G.world.drop_marks[id0].visible:
			shown += 1
	var plain: int = 0
	for dd0 in D.DROPS:
		if not dd0.get("locker", false):
			plain += 1
			if not G.world.is_free(float(dd0.x), float(dd0.z), 0.3):
				T.ok(false, "skrytka %s stoi w ścianie" % String(dd0.id))
	T.ok(plain >= 18 and marks == plain and shown == open0.size(), "każda skrytka ma znak sprejem, widać tylko te z terenu (%d z %d)" % [shown, marks])
	T.ok(G.drop_mark(G.drop_def("smietnik")) == "liść" and G.drop_mark(G.drop_def("zaulek")) != G.drop_mark(G.drop_def("smietnik")), "skrytki mają różne znaki (liść, czaszka…)")
	S.flags["got_first"] = true
	var chats0: int = (S.chats.get("wiktor", []) as Array).size()
	S.cust["kowal"].unlocked = false
	G.unlock_client("kowal")
	var open1: Array = G.drops_open()
	T.ok(open1.has("zbiornik") and open1.has("portiernia") and open1.has("nasyp") and open1.size() > open0.size() and G.world.drop_marks["zbiornik"].visible, "klient w hucie otwiera skrytki w hucie i pod nasypem (%d)" % open1.size())
	T.ok((S.chats.get("wiktor", []) as Array).size() == chats0 + 1, "Wiktor daje znać o nowych skrytkach")
	var near_n: int = 0
	var far_n: int = 0
	for i in range(600):
		var pk: Dictionary = G.drop_def(G.drop_pick())
		if G.drop_dist(pk) > 60.0:
			far_n += 1
		else:
			near_n += 1
	var near_c: int = 0
	var far_c: int = 0
	for sid0 in open1:
		if G.drop_dist(G.drop_def(sid0)) > 60.0:
			far_c += 1
		else:
			near_c += 1
	T.ok(far_c > 0 and near_c > 0 and float(far_n) / float(far_c) > 1.5 * float(near_n) / float(near_c), "im większy teren, tym częściej towar czeka daleko (%d daleko / %d blisko)" % [far_n, near_n])
	T.ok(G.drop_pick(open1) == "", "zajęte skrytki nie wypadają drugi raz")
	S.cust["kowal"].unlocked = false
	G.world.refresh_drops()
	# --- znaleziska: rzeczy na ziemi, śmietniki, lombard
	var cash_g := float(S.cash)
	S.items["telefon_stary"] = 2
	S.items["butelki"] = 5
	T.ok(G.pawn_list().size() == 2 and G.pawn_price("telefon_stary") > 40.0 and G.pawn_price("telefon_stary") < 70.0, "lombard wycenia znaleziska (stary telefon: %s)" % G.money(G.pawn_price("telefon_stary")))
	var pv: float = G.pawn_price("telefon_stary") * 2.0 + G.pawn_price("butelki") * 5.0
	T.ok(absf(G.pawn_sell_all() - pv) < 0.01 and G.item("telefon_stary") == 0 and absf(float(S.cash) - cash_g - pv) < 0.01, "sprzedaż w lombardzie: rzeczy znikają, gotówka rośnie")
	T.ok(G.pawn_price("woreczki") == 0.0, "lombard nie bierze zwykłych rzeczy")
	var rl := RandomNumberGenerator.new()
	rl.seed = 7
	var got_any := 0
	for i in range(40):
		if not G.loot_roll("dumpster", rl).is_empty():
			got_any += 1
	T.ok(got_any > 15 and got_any < 40, "kontener: czasem coś jest, czasem same śmieci (%d/40)" % got_any)
	S.bins = {}
	var t_bin: float = S.t
	G.bin_search("test_kosz", "dumpster", rl)
	T.ok(G.bin_used("test_kosz") and S.t > t_bin and G.bin_search("test_kosz", "dumpster", rl).is_empty(), "śmietnik da się przeszukać raz na dobę i zajmuje to czas")
	S.t += 1440.0
	T.ok(not G.bin_used("test_kosz"), "następnego dnia w śmietniku znowu coś może być")
	S.ground = []
	S.items["zegarek"] = 1
	var ents: Array = G.entries(S.inv)
	for en in ents:
		if String(en.id) == "zegarek":
			G.discard_entry(en, 1.0)
	T.ok(G.item("zegarek") == 0 and S.ground.size() == 1 and String(S.ground[0].id) == "zegarek", "wyrzucona rzecz leży na ziemi, a nie znika")
	T.ok(G.world.ground_nodes.size() == 1, "na ziemi widać zawiniątko do podniesienia")
	# ziemia otwiera się jak skrytka: można brać i odkładać, a to, co zostaje, leży dalej
	T.ok(G.loot_open({"kind": "ground", "rec": S.ground[0]}) and S.ground.is_empty() and int(G.store_items(S.stash.loot).get("zegarek", 0)) == 1, "ziemia otwarta jak pojemnik: zegarek po prawej stronie")
	G.loot_close()
	T.ok(S.ground.size() == 1 and String(S.ground[0].id) == "zegarek" and G.item("zegarek") == 0, "zamknięcie bez brania: rzecz leży dalej")
	G.loot_open({"kind": "ground", "rec": S.ground[0]})
	S.items["majeranek"] = 4
	var maj = null
	for en2 in G.entries(S.inv):
		if String(en2.id) == "majeranek":
			maj = en2
	T.ok(maj != null and G.move_limit("loot", maj, true) >= 4.0 and G.move_entry("loot", maj, true, 4.0) == 4.0, "na ziemię można też coś odłożyć z plecaka")
	T.ok(G.loot_take_all() == 2 and G.item("zegarek") == 1 and G.item("majeranek") == 4, "„Zabierz wszystko” bierze z ziemi obie rzeczy")
	G.loot_close()
	T.ok(S.ground.is_empty() and G.world.ground_nodes.is_empty(), "po zabraniu wszystkiego zawiniątko znika")
	S.items["majeranek"] = 0
	S.items["zegarek"] = 1
	for en3 in G.entries(S.inv):
		if String(en3.id) == "zegarek":
			G.discard_entry(en3, 1.0)
	T.ok(G.ground_take(S.ground[0]) and G.item("zegarek") == 1 and S.ground.is_empty(), "podniesiona rzecz wraca do plecaka")
	S.items["zegarek"] = 0
	var spawned: int = G.loot_spawn(rl)
	T.ok(spawned >= int(D.LOOT_DAILY[0]) and S.ground.size() == spawned, "rano na mieście leży kilka znalezisk (%d)" % spawned)
	S.ground = []
	G.world.refresh_ground()
	# --- telefony od postaci: każdy dzwoni raz, gdy ma powód
	var mama: Dictionary = D.CALLS[0]
	var adw: Dictionary = {}
	for cdef in D.CALLS:
		if cdef.id == "adwokat":
			adw = cdef
	S.t = 1440.0 + 12.0 * 60.0
	S.flags.erase("call_mama")
	T.ok(G.day() >= 2 and G.call_ready(mama), "drugiego dnia w południe mama ma powód zadzwonić")
	S.t = 1440.0 + 3.0 * 60.0
	T.ok(not G.call_ready(mama), "nikt nie dzwoni w środku nocy")
	S.t = 1440.0 + 12.0 * 60.0
	S.flags["call_mama"] = true
	T.ok(not G.call_ready(mama), "ta sama rozmowa nie powtarza się")
	S.arrests = 0
	var before_arrest: bool = G.call_ready(adw)
	S.arrests = 1
	T.ok(not before_arrest and G.call_ready(adw), "adwokat dzwoni dopiero po pierwszym zatrzymaniu")
	var long_line := 0
	for cdef in D.CALLS:
		for ln in cdef.lines:
			long_line = maxi(long_line, String(ln if ln is String else ln.t).length())
	T.ok(D.CALLS.size() >= 6 and long_line < 260, "rozmowy są krótkimi monologami (najdłuższa kwestia: %d znaków)" % long_line)
	# --- ubrania widać na postaci w ekwipunku
	for gid in ["czapka_daszek", "lancuch", "bluza_kaptur", "bojowki"]:
		S.items[gid] = 1
		G.gear_wear(gid)
	G.ui.open_inventory("")
	await T.frames(3)
	var rg: Dictionary = G.ui.inv.rig
	var worn: int = rg.get("wear", []).size()
	T.ok(worn >= 4, "założone ubrania widać na postaci (dodatki na kościach: %d)" % worn)
	G.gear_off("glowa")
	G.ui.inv.render()
	await T.frames(2)
	T.ok(G.ui.inv.rig.get("wear", []).size() < worn, "zdjęta czapka znika z postaci")
	G.ui.close_all()
	# --- strzały przy długiej ucieczce na widoku
	var N = G.npcs
	var cp: Dictionary = N.spawn_cop(false)
	var here: Vector3 = P.global_position
	cp.x = here.x + 12.0
	cp.z = here.z
	cp.state = "chase"
	cp.sees = true
	S.wanted = true
	N.flee_t = 0.0
	N.flee_stage = 0
	for i in range(5):
		N.update_shots(1.0, here, true)
	T.ok(N.flee_stage == 0, "krótka ucieczka: policja nie sięga po broń")
	for i in range(2):
		N.update_shots(1.0, here, true)
	T.ok(N.flee_stage == 1, "po kilku sekundach ucieczki na widoku: okrzyk „stój, bo strzelam”")
	for i in range(3):
		N.update_shots(1.0, here, true)
	T.ok(N.flee_stage == 2 and float(cp.get("aim_t", 0.0)) > 0.0, "potem strzał ostrzegawczy — policjant staje i mierzy")
	T.ok(N.shot_chance(8.0) > N.shot_chance(25.0) and N.shot_chance(8.0) <= 0.5, "z bliska trafić łatwiej niż z daleka (%d%% / %d%%)" % [int(N.shot_chance(8.0) * 100.0), int(N.shot_chance(25.0) * 100.0)])
	for i in range(20):
		N.update_shots(1.0, here, false)
	T.ok(N.flee_stage == 0 and N.flee_t == 0.0, "zatrzymanie się cofa licznik strzałów")
	S.wanted = false
	# --- latarka patrolu: stojąc rozgląda się na boki, a snop idzie za barkami
	cp.state = "patrol"
	cp.idle = 999.0
	cp.hear_t = 0.0
	cp.susp = 0.0
	var s_lo := 9.0
	var s_hi := -9.0
	var b_lo := 0.0
	var b_hi := 0.0
	for i in range(900):
		await T.frames(1)
		var fw: Vector3 = -(cp.torch as Node3D).global_transform.basis.z
		var beam: float = atan2(fw.x, fw.z)
		if float(cp.scan) < s_lo:
			s_lo = float(cp.scan)
			b_lo = beam
		if float(cp.scan) > s_hi:
			s_hi = float(cp.scan)
			b_hi = beam
		if s_hi - s_lo > 0.7:
			break
	T.ok(s_hi - s_lo > 0.7 and absf(angle_difference(b_lo, b_hi)) > (s_hi - s_lo) * 0.6, "patrol rozgląda się z latarką: barki %d°, snop %d°" % [int(rad_to_deg(s_hi - s_lo)), int(rad_to_deg(absf(angle_difference(b_lo, b_hi))))])
	N.remove_cop(cp)
	G.ui.close_all()
	# --- policja: na początku prawie jej nie ma, z czasem coraz więcej; wezwana przyjeżdża z komendy
	var t_keep: float = S.t
	var heat_keep: float = S.heat
	var inv_keep: float = S.invest
	S.heat = 0.0
	S.invest = 0.0
	S.wanted = false
	var q := []
	for dd9 in [0, 2, 8, 20]:
		S.t = float(dd9) * 1440.0 + 12.0 * 60.0
		q.append(G.cop_quota())
	T.ok(q == [0, 1, 2, 3], "patrole przybywają z czasem gry: dzień 1 — %d, dzień 3 — %d, dzień 9 — %d, dzień 21 — %d" % [q[0], q[1], q[2], q[3]])
	S.t = 12.0 * 60.0
	S.heat = 65.0
	S.invest = 50.0
	var q_hot: int = G.cop_quota()
	S.wanted = true
	T.ok(q_hot == 3 and G.cop_quota() >= 2 and G.car_pause() > 3.0, "hałas i śledztwo ściągają patrole nawet pierwszego dnia (%d), a radiowóz na początku jeździ rzadko" % q_hot)
	S.wanted = false
	S.heat = 0.0
	S.invest = 0.0
	for c9 in N.cops.duplicate():
		N.remove_cop(c9)
	var pp0: Vector3 = G.player.global_position
	N.dispatch_to(pp0.x + 30.0, pp0.z, 2)
	T.ok(N.cops.size() == 2 and N.cops[0].state == "investigate" and N.cops[0].get("resp", false), "zgłoszenie, gdy nikogo nie ma w okolicy: dwóch policjantów wychodzi z komendy")
	if N.cops.size() == 2:
		var ca: Dictionary = N.cops[0]
		var cb: Dictionary = N.cops[1]
		ca.x = pp0.x + 5.0
		ca.z = pp0.z
		cb.x = pp0.x + 30.0
		cb.z = pp0.z + 30.0
		for cc in [ca, cb]:
			cc.state = "chase"
			cc.look_t = 9.0
			cc.last_seen = G.now
			cc.inv = Vector2(float(cc.x), float(cc.z))
		ca.sees = true
		cb.sees = false
		S.wanted = true
		N._update_cops(0.05, pp0, true)
		T.ok((cb.inv as Vector2).distance_to(Vector2(pp0.x, pp0.z)) < 0.1, "radio: gdy jeden ścigający Cię widzi, drugi też wie, gdzie biec")
		cb["flee_dir"] = Vector2(1.0, 0.0)
		cb.inv = Vector2(pp0.x, pp0.z)
		N._begin_search(cb, 15.0, true)
		var ahead := false
		if not (cb.search_pts as Array).is_empty():
			ahead = (cb.search_pts[0] as Vector2).x > pp0.x + 1.0
		T.ok(cb.state == "search" and ahead, "zgubiony trop: patrol szuka najpierw tam, dokąd uciekałeś")
		S.wanted = false
	for c9 in N.cops.duplicate():
		N.remove_cop(c9)
	S.t = t_keep
	S.heat = heat_keep
	S.invest = inv_keep
	# --- mimika: każda postać mruga, mówi ustami i potrafi zmienić minę
	var Chars = load("res://scripts/chars.gd")
	var frig: Dictionary = Chars.make({"model": "m02", "seed": 4})
	G.main.add_child(frig.root)
	var cam3: Camera3D = G.main.get_viewport().get_camera_3d()
	frig.root.global_position = cam3.global_position + Vector3(0.0, -1.6, -2.0) if cam3 != null else Vector3.ZERO
	T.ok(frig.has("face") and frig.face != null, "postać ma kości twarzy podpięte pod mimikę")
	if frig.has("face"):
		var fsk: Skeleton3D = frig.skel
		var corner := fsk.find_bone("Bip01 RMouthCorner")
		Chars.mood(frig, "", 0.0)
		await T.frames(8)
		var p_neutral: Vector3 = fsk.get_bone_global_pose(corner).origin - fsk.get_bone_global_pose(fsk.find_bone("Bip01 Head")).origin
		Chars.emote(frig, "usmiech", 1.0, 4.0)
		Chars.say(frig, 2.0)
		var jaw_moved := false
		for i in range(400):
			# mowa ma pauzy między słowami — czekamy, aż padnie sylaba
			await T.frames(1)
			Chars.say(frig, 2.0)
			if float(frig.face._w.mowa) > 0.2:
				jaw_moved = true
				break
		# czekanie na sylabę bywa długie i mina zdąży zgasnąć — odpalamy ją jeszcze raz tuż przed pomiarem
		frig.face.flash("usmiech", 1.0, 4.0)
		for i in range(45):
			await T.frames(1)
		var p_smile: Vector3 = fsk.get_bone_global_pose(corner).origin - fsk.get_bone_global_pose(fsk.find_bone("Bip01 Head")).origin
		# (samo przesunięcie kości widać tylko w trakcie rysowania klatki — sprawdza je tools/blender/twarz_test.py)
		T.ok(float(frig.face._w.usmiech) > 0.7 and p_smile.is_finite() and p_neutral.is_finite() and float(frig.face._ied) > 0.01, "chwilowa mina narasta płynnie (uśmiech %.2f)" % float(frig.face._w.usmiech))
		T.ok(jaw_moved, "przy mówieniu postać porusza ustami")
		frig.face._blink_in = 0.0
		var blinked := false
		for i in range(30):
			await T.frames(1)
			if float(frig.face._blink) >= 0.0:
				blinked = true
		T.ok(blinked, "postać mruga")
	frig.root.queue_free()
	var People = load("res://scripts/people.gd")
	var with_face := 0
	var all_models: Array = D.PEOPLE_M + D.PEOPLE_F + D.PEOPLE_COP
	for mid0 in all_models:
		var pi: Dictionary = People.instance(String(mid0), "")
		if not pi.is_empty() and (pi.skel as Skeleton3D).find_bone("Bip01 MJaw") >= 0:
			with_face += 1
		if not pi.is_empty():
			(pi.model as Node).free()
	T.ok(with_face == all_models.size(), "wszystkie modele ludzi mają kości twarzy (%d z %d)" % [with_face, all_models.size()])
	# --- obrzeża: obozowisko bezdomnych, zamknięty tunel, plac zabaw
	var names := {}
	for st0 in N.statics:
		names[String(st0.name)] = st0
	T.ok(names.has("Pan Tadek") and names.has("Mietek") and G.world.camp_fire != null and is_instance_valid(G.world.camp_fire), "za garażami jest obozowisko: bezdomni przy ognisku, które się pali")
	var camp_w: Vector2 = G.world.CAMP * D.SC
	T.ok(Vector2(float(names["Pan Tadek"].x), float(names["Pan Tadek"].z)).distance_to(camp_w) < 2.5 and names["Pan Tadek"].has("interact"), "z bezdomnym przy ogniu da się pogadać")
	var wrona = names.get("Posterunkowy Wrona")
	T.ok(wrona != null and absf(float(wrona.x) - G.world.TUNNEL_X * D.SC) < 8.0 and not G.world.is_free(G.world.TUNNEL_X * D.SC, 8.0 * D.SC, 0.3), "na końcu Hutniczej stoi portal tunelu, a przy barierach policjant")
	var has_play := 0
	for ch0 in G.world.city.get_children():
		if String(ch0.name).begins_with("plac_") or String(ch0.scene_file_path).contains("plac_"):
			has_play += 1
	T.ok(has_play >= 20, "plac zabaw: piaskownica, karuzela, ważka, drabinka i płotek (%d elementów)" % has_play)
	T.ok(G.world.litter_count > 300 and G.world.litter_count < 900, "na mieście leżą drobne śmieci (%d sztuk)" % G.world.litter_count)
	# --- granice mapy: kolizja dookoła bez dziur, a tam, gdzie coś dochodzi do muru, stoi zamknięcie
	var space: PhysicsDirectSpaceState3D = G.world.get_world_3d().direct_space_state
	var bq := PhysicsPointQueryParameters3D.new()
	var edge: Array = []
	var ea := -206.0
	while ea <= 206.0:
		edge.append(Vector2(ea, -171.0))
		edge.append(Vector2(ea, 171.0))
		ea += 3.0
	ea = -168.0
	while ea <= 168.0:
		edge.append(Vector2(-210.5, ea))
		edge.append(Vector2(210.5, ea))
		ea += 3.0
	var holes := 0
	for ep in edge:
		bq.position = Vector3(ep.x * D.SC, G.world.hd(clampf(ep.x, -208.0, 208.0), clampf(ep.y, -169.0, 169.0)) + 1.2, ep.y * D.SC)
		if space.intersect_point(bq, 1).is_empty():
			holes += 1
	T.ok(holes == 0, "mur graniczny jest szczelny dookoła mapy (%d punktów, %d bez kolizji)" % [edge.size(), holes])
	var portals := 0
	var gates := 0
	for ch1 in G.world.city.get_children():
		if String(ch1.scene_file_path).contains("portal_kolejowy"):
			portals += 1
		elif String(ch1.scene_file_path).contains("brama_huty"):
			gates += 1
	T.ok(portals == 2 and gates == 1, "tory wchodzą na obu końcach w zamknięty portal, a Hutnicza kończy się bramą huty (%d portale, %d brama)" % [portals, gates])
	var ge: Vector2 = G.world.GATE_E
	T.ok(not G.world.is_free((ge.x - 3.0) * D.SC, (ge.y + 8.0) * D.SC, 0.2) and G.world.is_free((ge.x - 14.0) * D.SC, 20.0 * D.SC, 0.5), "przy bramie huty stoi portiernia, a dojazd do szlabanu jest wolny")
	var lp: Array = G.world.LOOP
	var bus_n := 0
	for ch2 in G.world.city.get_children():
		if String(ch2.scene_file_path).contains("autobus"):
			bus_n += 1
	T.ok(bus_n == 1 and G.world.surface_at(0.0, (float(lp[3]) - 1.0) * D.SC) == "concrete" and G.world.surface_at(0.0, 151.0 * D.SC) == "grass" and not G.world.is_free(G.world.BUS.x * D.SC, G.world.BUS.y * D.SC, 0.2),
		"Robotnicza kończy się pętlą: jezdnia dookoła wysepki i autobus przy peronie")
	T.ok(G.world.is_free(-12.0 * D.SC, 156.0 * D.SC, 0.8) and G.world.is_free(12.0 * D.SC, 156.0 * D.SC, 0.8) and G.world.is_free(0.0, 145.5 * D.SC, 0.8), "pętlę da się objechać: obok autobusu zostaje wolny pas")
	T.ok(names.has("Pan Mirek") and names.has("Pan Bogdan") and names["Pan Mirek"].has("interact") and G.world.is_free(float(names["Pan Bogdan"].x), float(names["Pan Bogdan"].z), 0.3) and G.world.is_free(float(names["Pan Mirek"].x), float(names["Pan Mirek"].z), 0.3),
		"na pętli stoi kierowca, a przy bramie huty stróż — z oboma da się pogadać")
	# --- przegląd mapy: nic nie rośnie w budynkach, a każde przejście w płocie dokądś prowadzi
	var in_bld := 0
	for tp0 in G.world.tree_pos:
		for b0 in G.world.blds:
			if tp0.x > float(b0.x0) and tp0.x < float(b0.x1) and tp0.y > float(b0.z0) and tp0.y < float(b0.z1):
				in_bld += 1
	T.ok(in_bld == 0 and G.world.greens_evicted > 0, "żadne drzewo nie rośnie w budynku ani w garażu (usunięte: %d)" % G.world.greens_evicted)
	var blocked_pass := 0
	for pg0 in G.world.passages:
		for sd0 in [-1.0, 1.0]:
			var qx0: float = float(pg0[0]) + (0.0 if pg0[2] else sd0 * 1.5)
			var qz0: float = float(pg0[1]) + (sd0 * 1.5 if pg0[2] else 0.0)
			if not G.world.is_free(qx0 * D.SC, qz0 * D.SC, 0.25):
				blocked_pass += 1
	T.ok(blocked_pass == 0 and G.world.passages.size() >= 15, "każda dziura, przełaz i furtka w płocie ma wolne przejście po obu stronach (%d przejść)" % G.world.passages.size())
	var CarsT = load("res://scripts/cars.gd")
	var parked: Node3D = CarsT.car("sedan", "8a8f96")
	var lit := 0
	for lm0 in parked.get_meta("lamps", []):
		var mo0 := (lm0 as MeshInstance3D).material_override as StandardMaterial3D
		if mo0 == null or mo0.emission_enabled:
			lit += 1
	T.ok((parked.get_meta("lamps", []) as Array).size() >= 4 and lit == 0, "zaparkowane auto ma zgaszone reflektory i lampy tylne (%d kloszy)" % (parked.get_meta("lamps", []) as Array).size())
	CarsT.lamps_on(parked, true)
	T.ok(((parked.get_meta("lamps")[0] as MeshInstance3D).material_override) == null, "jadący radiowóz zapala klosze świateł")
	parked.free()
	T.ok(G.world.road_signs >= 25, "przy przejściach i na skrzyżowaniach stoją znaki drogowe (%d)" % G.world.road_signs)
	T.ok(G.world.drains >= 40, "w jezdniach są kratki ściekowe przy krawężnikach (%d)" % G.world.drains)
	T.ok(G.world.ring2 >= 40, "za murem stoi drugi rząd bloków, który zasłania przerwy w pierwszym (%d)" % G.world.ring2)
	# --- radiowóz: jedzie prawym pasem, skręca stopniowo, na końcu trasy zawraca
	var car: Dictionary = N.car
	var car_keep := {"seg": car.seg, "x": car.x, "z": car.z, "rot": car.rot, "wait": car.wait, "speed": car.speed}
	car.seg = 3
	car.x = float(N.CAR_ROUTE[3][0]) * D.SC
	car.z = float(N.CAR_ROUTE[3][1]) * D.SC
	car.rot = 0.0
	car.speed = 0.0
	car.alarm = false
	var far_pp := Vector3(car.x - 900.0, 0.0, car.z)
	var max_off := 0.0
	var max_v := 0.0
	var seen_segs := {}
	var turned := false
	var wheel0 := 0.0
	if not (car.wheels as Array).is_empty():
		wheel0 = (car.wheels[0] as Node3D).rotation.length()
	for i in range(3600):
		car.wait = 0.0
		N._update_car(0.05, far_pp, true)
		seen_segs[int(car.seg)] = true
		max_v = maxf(max_v, absf(float(car.speed)))
		if float(car.kturn) > 0.0:
			turned = true
		else:
			var ra: Vector2 = Vector2(float(N.CAR_ROUTE[int(car.seg)][0]), float(N.CAR_ROUTE[int(car.seg)][1])) * D.SC
			var rb: Vector2 = Vector2(float(N.CAR_ROUTE[(int(car.seg) + 1) % N.CAR_ROUTE.size()][0]), float(N.CAR_ROUTE[(int(car.seg) + 1) % N.CAR_ROUTE.size()][1])) * D.SC
			var ab := (rb - ra).normalized()
			var rel := Vector2(float(car.x), float(car.z)) - ra
			# tuż po zawróceniu auto dopiero wraca na swój pas — liczymy odchyłkę, gdy już jedzie
			if absf(float(car.speed)) > 4.0:
				max_off = maxf(max_off, absf(rel.x * -ab.y + rel.y * ab.x))
	var wheel1 := 0.0
	if not (car.wheels as Array).is_empty():
		wheel1 = (car.wheels[0] as Node3D).rotation.length()
	T.ok(seen_segs.size() >= 3 and turned and max_v > 5.0 and max_v <= 7.3 and max_off < 2.6, "radiowóz przejeżdża kolejne odcinki, nie zjeżdża z jezdni (najdalej %.1f m od osi) i zawraca na końcu ulicy" % max_off)
	T.ok((car.wheels as Array).size() == 4 and wheel0 != wheel1 and (car.domes as Array).size() == 2, "nowy model radiowozu: cztery obracające się koła i dwa klosze na dachu")
	# człowiek przed maską: hamuje
	car.speed = 6.0
	var front_pp := Vector3(float(car.x) + sin(float(car.rot)) * 4.0, 0.0, float(car.z) + cos(float(car.rot)) * 4.0)
	for i in range(40):
		car.wait = 0.0
		N._update_car(0.05, front_pp, true)
	T.ok(absf(float(car.speed)) < 0.3 or float(car.kturn) > 0.0, "radiowóz hamuje przed pieszym (%.1f m/s)" % float(car.speed))
	for kk in car_keep:
		car[kk] = car_keep[kk]
	car.alarm = false
	car.susp = 0.0
	N._car_move(0.0)
	# --- kondycja: większy zapas, chwila na złapanie oddechu, adrenalina w pościgu
	var PL = G.player
	var st_keep: float = PL.stamina
	S.wanted = false
	PL.stamina = PL.max_stamina()
	PL.sprinting = true
	PL.moving = true
	for i in range(100):
		PL.stamina_tick(0.1)
	T.ok(PL.BASE_STAMINA >= 11.0 and absf(PL.stamina - maxf(0.0, PL.max_stamina() - 10.0)) < 0.05, "kondycja: %d s biegu bez przerwy (w tym stroju %.1f s)" % [int(PL.BASE_STAMINA), PL.max_stamina()])
	S.wanted = true
	PL.stamina = PL.max_stamina()
	for i in range(100):
		PL.stamina_tick(0.1)
	T.ok(absf(PL.stamina - maxf(0.0, PL.max_stamina() - 7.5)) < 0.05, "w pościgu adrenalina oszczędza oddech (po 10 s biegu zostaje %.1f s)" % PL.stamina)
	S.wanted = false
	PL.stamina = 2.0
	PL.sprinting = false
	PL.moving = false
	PL.rest_t = 0.0
	for i in range(8):
		PL.stamina_tick(0.1)
	var after_pause: float = PL.stamina
	for i in range(40):
		PL.stamina_tick(0.1)
	var rest_stand: float = PL.stamina - after_pause
	PL.stamina = 2.0
	PL.moving = true
	PL.rest_t = 0.0
	for i in range(48):
		PL.stamina_tick(0.1)
	T.ok(after_pause == 2.0 and rest_stand > 4.0 and PL.stamina - 2.0 < rest_stand * 0.7, "po biegu chwila bez oddechu, potem wraca — stojąc szybciej niż idąc (+%.1f / +%.1f s)" % [rest_stand, PL.stamina - 2.0])
	PL.stamina = st_keep
	PL.sprinting = false
	PL.moving = false
	# --- karty „pierwszy raz”: każda mechanika tłumaczona raz
	S.flags.erase("tip_test1")
	var hide_keep: bool = G.test_hide_hud
	G.test_hide_hud = false
	T.ok(G.tip("test1", "Tytuł", "Treść") and not G.tip("test1", "Tytuł", "Treść") and G.ui.tip_box != null and is_instance_valid(G.ui.tip_box), "karta „pierwszy raz” pokazuje się tylko raz")
	S.flags.erase("tip_skrytka_eq")
	G.ui.open_inventory("safe")
	await T.frames(3)
	T.ok(S.flags.get("tip_skrytka_eq", false), "pierwsze otwarcie skrytki tłumaczy przeciąganie rzeczy (z ręką pokazującą ruch)")
	G.ui.close_all()
	G.test_hide_hud = hide_keep
	# --- otwarte okna nie zatrzymują świata: telefon, rozmowa; staje tylko menu pauzy
	G.arresting = false
	var t_a := float(S.t)
	G.ui.open_phone("")
	await T.frames(20)
	T.ok(not M.get_tree().paused and float(S.t) > t_a and G.ui.mode == "phone", "telefon nie zatrzymuje czasu (+%.2f min)" % (float(S.t) - t_a))
	G.ui.dialog({"name": "Test", "lines": ["Raz.", "Dwa."]})
	var t_b := float(S.t)
	await T.frames(20)
	T.ok(not M.get_tree().paused and float(S.t) > t_b and G.ui.mode == "dialog", "rozmowa nie zatrzymuje czasu")
	G.ui.close_all()
	G.ui.show_pause()
	var t_c := float(S.t)
	await T.frames(10)
	T.ok(M.get_tree().paused and float(S.t) == t_c, "menu pauzy dalej zatrzymuje grę")
	G.ui.close_all()
	T.ok(not M.get_tree().paused, "po zamknięciu menu gra rusza")
	G.ui.open_phone("")
	G.arrest(null)
	T.ok(G.ui.mode == "dialog" and not G.ui.phone.visible, "patrol przerywa telefon: okno znika i zaczyna się kontrola")
	G.ui.close_all()
	G.arresting = false
	var o_t := {"id": 9991, "cust": "dominik", "status": "accepted", "deadline": float(S.t) - 1.0, "respond_by": float(S.t) - 1.0}
	G.ui.deal = {"ctx": {"order": o_t}, "over": false}
	T.ok(G.order_in_talk(o_t) and not G.order_in_talk({"id": 5}), "zamówienie, o które trwa rozmowa, nie przepada w jej trakcie")
	G.ui.deal = {}
	G.S = keep
	M.teleport(back_loc, back_pos, 0.0)
	await T.frames(2)
