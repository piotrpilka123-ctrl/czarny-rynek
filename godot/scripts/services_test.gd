extends RefCounted
## Testy klubu, szpitala i komendy: nielegalne rzeczy, kontrola ochroniarza, trzy wpadki = szpital,
## utrata gotówki w szpitalu, konfiskata na komendzie, duża gotówka = węszenie po kryjówkach.


static func run(T) -> void:
	var keep: Dictionary = G.S
	G.S = G.new_state()
	var S: Dictionary = G.S
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
	N.remove_cop(cp)
	G.ui.close_all()
	G.S = keep
	M.teleport(back_loc, back_pos, 0.0)
	await T.frames(2)
