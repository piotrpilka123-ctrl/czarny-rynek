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
		for offset in [Vector2(0,1.45),Vector2(0.65,1.5)]:
			M.teleport("safe",Vector3(float(lap.x)+offset.x,0,float(lap.z)+offset.y),0)
			await frames(4)
			G.player.cam.look_at(Vector3(lap.x,0.96,lap.z),Vector3.UP)
			var actual = M._find_interact()
			ok(actual != null and String(actual.get("id",""))=="save_safe","celownik trafia laptop z normalnej pozycji gracza — stół nie blokuje zapisu")
		M.interact()
	G.story_tick()
	ok(G.flag("tut_save") and G.cur_step().id == "room_stash", "zapis przy laptopie zalicza pierwszy krok")
	for case in [["radio",Vector2(0,1.4),0.95],["pack_safe",Vector2(0,1.4),0.88],["stash_safe",Vector2(-1.3,0),1.0],["bed",Vector2(1.3,0),0.6]]:
		for item in G.world.inter:
			if item.get("id","")!=case[0]: continue
			M.teleport("safe",Vector3(float(item.x)+case[1].x,0,float(item.z)+case[1].y),0)
			await frames(3)
			G.player.cam.look_at(Vector3(item.x,case[2],item.z),Vector3.UP)
			var selected = M._find_interact()
			ok(selected != null and selected.get("id","")==case[0],"celownik wybiera rzeczywisty obiekt w kawalerce: %s"%case[0])
	# na start w kieszeni leży notes z numerami: samouczek każe przenieść go do szafy (samo otwarcie nie wystarcza)
	var bag_sp: float = float(D.START_BAGS) * float(D.ITEMS.woreczki.size)
	ok(G.item("notes") == 1 and G.item("woreczki") == D.START_BAGS and absf(G.carry_total() - (1.0 + bag_sp)) < 0.01 and String(G.cur_step().text.call()).contains("notes"), "na start: notes z numerami i %d woreczków w kieszeni; samouczek każe schować notes" % D.START_BAGS)
	U.open_stash("safe")
	await frames(2)
	G.story_tick()
	ok(G.cur_step().id == "room_stash" and U.inv.room == "safe", "samo otwarcie szafy nie zalicza kroku")
	var note_e := {}
	for en0 in G.entries(S.inv):
		if String(en0.id) == "notes":
			note_e = en0
	U.inv.drag_demo(true)
	await frames(4)
	ok(is_instance_valid(U.inv.demo) and U.inv.demo.mouse_filter == Control.MOUSE_FILTER_IGNORE and G.item("notes") == 1, "pokaz przeciągania wskazuje notes, nie blokuje myszy i sam niczego nie przenosi")
	U.inv.ask_amount(note_e, "bag", "stash")
	ok(U.inv.asking() and G.item("notes") == 1 and U.inv.demo == null, "upuszczenie notesu kończy pokaz i prosi o potwierdzenie, zanim go przeniesie")
	U.inv.ask_close()
	ok(G.item("notes") == 1, "anulowanie przeniesienia zostawia notes w kieszeni")
	U.inv.ask_amount(note_e, "bag", "stash")
	ok(U.inv.ask_go.text.contains("wszystko"), "samouczek pokazuje potwierdzenie przeniesienia wszystkiego")
	U.inv.ask_ok()
	ok(G.item("notes") == 0 and int(G.store_items(S.stash.safe).get("notes", 0)) == 1, "notes przeciągnięty do szafy po potwierdzeniu")
	U.close_all()
	G.story_tick()
	ok(G.cur_step().id == "room_bench" and absf(G.carry_total() - bag_sp) < 0.01, "krok ze skrytką zaliczony, w kieszeniach zostały tylko woreczki")
	# cel w lewym górnym rogu zostaje na ekranie, dopóki zadanie nie jest wykonane (nie gaśnie po kilku sekundach)
	U.obj_t = 0.0
	U.update_hud()
	ok(U.obj_card.visible and U.obj_card.modulate.a > 0.99 and U.l_obj.text.contains("waga"), "karta celu jest przypięta do końca zadania")
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
	# karta „pierwszy raz” nie zasłania telefonu trzymanego pionowo: staje w lewej kolumnie, obok niego
	U.tip_show("Telefon", "Tekst podpowiedzi na próbę, wystarczająco długi, żeby zawinął się w kilka linijek wąskiej karty obok telefonu.", 30.0)
	await frames(4)
	var tip_r: Rect2 = U.tip_panel.get_global_rect()
	var ph_left := 99999.0
	for pc in U.phone.find_children("*", "PanelContainer", true, false):
		if (pc as Control).is_visible_in_tree() and (pc as Control).size.y > 400.0:
			ph_left = minf(ph_left, (pc as Control).global_position.x)
	ok(U.tip_narrow and tip_r.size.x < 420.0 and tip_r.end.x <= ph_left + 1.0, "podpowiedź przy pionowym telefonie stoi w lewej kolumnie i go nie zasłania (%d ≤ %d)" % [int(tip_r.end.x), int(ph_left)])
	U.tip_box.queue_free()
	# powiadomienie przy pionowym telefonie też mieści się obok niego, a nie na kaflach odpowiedzi
	U._toast_show("Nowy klient: Dominik. Teren rośnie: Pawilon i okolice są teraz Twoje.", "good")
	await frames(4)
	var toast_end := 0.0
	for tp0 in U.toasts.get_children():
		toast_end = maxf(toast_end, (tp0 as Control).get_global_rect().end.x)
	ok(toast_end > 10.0 and toast_end <= ph_left + 1.0, "powiadomienie przy pionowym telefonie stoi obok niego (%d ≤ %d)" % [int(toast_end), int(ph_left)])
	for tp1 in U.toasts.get_children():
		tp1.queue_free()
	await frames(2)
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
	ok(absf(G.carry_total() - start_g - bag_sp) < 0.01 and G.carry_total() <= float(G.capacity()) and G.capacity() >= 30, "paczka mieści się w kieszeniach (%s / %d)" % [str(G.carry_total()), G.capacity()])
	ok(G.credit_days() >= 7, "na początku Wiktor daje tydzień na spłatę zeszytu (%d dni)" % G.credit_days())
	# dalej test idzie jak dawniej z 5 g marihuany przy sobie — reszta paczki ląduje w szafie
	G.add_bulk(S.stash.safe, "szron", 100, G.take_bulk(S.inv, "szron", 100, 99.0))
	G.add_bulk(S.stash.safe, "dym", 100, G.take_bulk(S.inv, "dym", 100, start_g - 10.0 if start_g > 15.0 else maxf(0.0, float(S.inv.bulk["dym"].get("100", 0.0)) - 5.0)))
	ok(absf(G.carry_total() - 5.0 - bag_sp) < 0.01, "zajęte miejsce: 5 g luzem i paczka woreczków")

	# Promień interakcji nie przechodzi przez fizyczną przeszkodę.
	var ray_from := Vector3(5000, 20, 0)
	ok(M._aim_clear(ray_from, Vector3.FORWARD, 2.0), "interakcja ma wolną linię wzroku w pustym miejscu")
	var aim_wall := StaticBody3D.new()
	var aim_collision := CollisionShape3D.new()
	var aim_box := BoxShape3D.new()
	aim_box.size = Vector3(1, 2, 0.2)
	aim_collision.shape = aim_box
	aim_wall.add_child(aim_collision)
	M.add_child(aim_wall)
	aim_wall.global_position = ray_from + Vector3.FORWARD
	await frames(4)
	ok(not M._aim_clear(ray_from, Vector3.FORWARD, 2.0), "ściana przed celem blokuje interakcję")
	ok(M._aim_clear(ray_from,Vector3.FORWARD,2.0,aim_collision),"kolizja wybranego przedmiotu nie blokuje jego własnej interakcji")
	var other_shape := CollisionShape3D.new()
	other_shape.shape = aim_box
	other_shape.position.z = 0.5
	aim_wall.add_child(other_shape)
	await frames(3)
	ok(not M._aim_clear(ray_from,Vector3.FORWARD,2.0,aim_collision),"inny mebel we wspólnym body nadal zasłania wybrany przedmiot")
	aim_wall.queue_free()
	await frames(3)
	ok(M._aim_clear(ray_from, Vector3.FORWARD, 2.0), "po usunięciu przeszkody interakcja znów ma linię wzroku")

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
	ok(got[0] == 3 and got[1] == 0 and G.item("woreczki") == D.START_BAGS - 3, "zaporcjowane 3 g w trzy woreczki — ubyło trzech pustych")
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
	ok(G.cur_step().id == "pack1" and S.orders.is_empty() and G.loose_left() > 0 and G.exit_block("safe").contains("zapakuj"), "dopóki część towaru leży luzem (%d g), samouczek czeka, a z mieszkania nie da się wyjść" % G.loose_left())
	# reszta idzie w paczki: amfetamina w jedną paczkę 5 g, marihuana w woreczki po 1 g
	var bags_b: int = G.bags_at("safe")
	# na czas tej paczki waga bez strat, żeby rozsypany gram nie zmieniał rachunku
	S["scale"] = 2
	var pbag: Dictionary = G.pack_bag("safe", "szron", 100, 5)
	S["scale"] = 0
	ok(pbag.ok and G.bags_at("safe") == bags_b - 1 and G.packed_total(S.stash.safe, "szron") + G.packed_total(S.inv, "szron") == 5, "pięć gramów amfetaminy w jednej paczce: jeden woreczek mniej")
	ok(not G.pack_bag("safe", "szron", 100, 3).ok, "na paczkę 3 g nie ma już towaru")
	pack_all("safe")
	G.story_tick()
	G.story_tick()
	ok(G.loose_left() == 0 and S.cust.dominik.unlocked and S.orders.size() == 1, "po zapakowaniu całego towaru Dominik pisze pierwsze zamówienie")
	var fo: Dictionary = S.orders[0]
	ok(int(fo.grams) >= 1 and int(fo.grams) <= 6 and G.exit_block("safe").contains("Dominik"), "prosi o tyle, ile da się złożyć z paczek (%d g); zanim mu nie odpiszesz, drzwi dalej są zamknięte" % int(fo.grams))

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
	# test niesie tylko marihuanę: gdy klient wylosował amfetaminę, zamówienie zamienia się na to, co jest w kieszeni
	# (to losowanie sprawiało, że co kilkanaście przebiegów cała seria testów sprzedaży padała)
	if String(o.product) != "dym":
		o.product = "dym"
		o.grams = 3
	U.open_phone("sms")
	U.phone.chat_id = "dominik"
	U.phone.render()
	await frames(3)
	U.close_all()
	G.reply_order(o.id, "accept")
	ok(o.status == "accepted" and o.agreed != null, "zamówienie przyjęte po cenie klienta (%s zł/g)" % str(o.agreed))
	ok(float(o.meet) - S.t > 50.0 and float(o.meet) - S.t < 70.0, "spotkanie wypada ok. godzinę po potwierdzeniu (%d min)" % int(float(o.meet) - S.t))
	ok(G._first_delivery_text().contains(G.clock(o.meet)) and not G._first_delivery_text().contains("czeka do"), "cel pierwszej dostawy pokazuje umówioną godzinę, zanim klient przyjdzie")
	ok(G.flag("tip_pierwsze_spotkanie"), "pierwsze spotkanie wyjaśnia mapę, czas gry i oczekiwanie klienta")
	ok(G.npcs.customers.size() == 1, "klient zaplanowany na spotkanie")
	ok(G.npcs.customers[0].node == null, "klient jeszcze nie wyszedł z domu")
	# pojawia się na krótko przed umówioną godziną i idzie pieszo
	G.add_minutes(maxf(0.0, float(o.meet) - S.t - 2.0))
	await frames(30)
	var cn: Dictionary = G.npcs.customers[0]
	ok(cn.node != null, "klient wyszedł z domu przed spotkaniem")
	G.add_minutes(maxf(0.0, float(o.meet) - S.t))
	ok(G._first_delivery_text().contains(G.clock(o.deadline)) and G._first_delivery_text().contains("czeka do"), "po umówionej godzinie cel pierwszej dostawy pokazuje czas oczekiwania")
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
		ok(int(U.deal.qty) == 0 and (U.deal.give as Array).is_empty() and int(U.deal.sum) == G.deal_ref_sum(U.deal) and U.deal_side.visible, "okno wymiany: pusta taca, suma umówiona, po lewej lista tego, co masz przy sobie")
		U.deal_holding = true
		await frames(8)
		U.deal_holding = false
		ok(float(U.deal.hold) <= 0.001 and not U.deal.over, "z pustą tacą nie da się niczego podać")
		# okienko „ile paczek” wyskakuje nad panelem sprzedaży, nawet gdy otworzy się je tuż po przebudowie okna
		U._render_deal()
		U.Trade.ask(U, "dym", 100, 1, 3)
		await frames(3)
		var ask_ok := false
		if U.deal_ask_box != null and is_instance_valid(U.deal_ask_box):
			var acc: Control = U.deal_ask_box.get_meta("cc")
			var abox: Rect2 = (acc.get_child(0) as Control).get_global_rect()
			var mbox: Rect2 = U.modal_box.get_global_rect()
			ask_ok = abox.position.y > 80.0 and abox.intersects(mbox.grow(40.0)) and abox.end.y <= U.root.size.y
		ok(ask_ok, "okienko ilości stoi przy panelu sprzedaży, a nie pod górną krawędzią ekranu")
		U.Trade.ask_close(U)
		G.deal_autofill(U.deal)
		U._render_deal()
		ok(int(U.deal.base) == int(o.agreed) and int(U.deal.pct) == 0 and G.deal_read(U.deal, 0) == "sure", "wymiana zaczyna się od umówionej ceny — bez przywitań i gadek")
		ok(not G.deal_set(U.deal, 15) == false and int(U.deal.price) > int(o.agreed) and G.deal_set(U.deal, 0), "cenę można lekko podbić albo wrócić do umówionej")
		# podanie towaru: przytrzymanie napełnia pasek, puszczenie go cofa
		# (najpierw kilka klatek na ułożenie świeżo zbudowanego okna — „zjechanie myszy z przycisku” tuż po przebudowie
		# potrafiło w teście skasować przytrzymanie, zanim pasek ruszył)
		await frames(4)
		var held := 0.0
		for _try in range(3):
			U.deal_holding = true
			await frames(6)
			held = maxf(held, float(U.deal.hold))
			if held > 0.0:
				break
		U.deal_holding = false
		await frames(40)
		ok(held > 0.0 and float(U.deal.hold) == 0.0 and not U.deal.over, "puszczony przycisk cofa podanie (%.2f → 0; na tacy %d g, tryb %s, okienko %s, koniec %s, hold %.2f)" % [held, int(U.deal.qty), U.mode, str(not U.deal_ask.is_empty()), str(U.deal.over), float(U.deal.hold)] + " paczki=%s chce=%s %d" % [str(G.stacks(S.inv, "pack")), String(U.deal.ctx.product), int(U.deal.want)])
		U.deal_holding = true
		var hg := 0
		while not U.deal.over and hg < 400:
			hg += 1
			await frames(1)
		ok(U.deal.sold, "przytrzymanie do końca = towar podany, pieniądze w kieszeni")
		await frames(3)
	ok(S.cash > cash0 and int(S.stats.deals) == 1, "sprzedaż po umówionej cenie (+%d zł)" % int(S.cash - cash0))
	ok(int(S.stats.sold) == 3, "pierwsze zamówienie Dominika: 3 g złożone z woreczków po 1 g (sprzedane %d g)" % int(S.stats.sold))
	U.close_all()
	await frames(5)

	# --- zeszyt
	if String(G.cur_step().id) == "sell1":
		G.story_tick()
	ok(G.flag("hurt_on") and String(G.cur_step().id) == "order1" and String(G.cur_step().text.call()).contains("10 g marihuany i 10 g amfetaminy") and (S.chats.wiktor as Array).any(func(m): return String(m.text).contains("10 g zioła")),
		"po pierwszej sprzedaży Wiktor otwiera zamówienia, a cel każe zamówić 10 g marihuany i 10 g amfetaminy")
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
	ok(cat.size() == 2 and cat[0].open and cat[1].open and String(cat[0].p) == "dym" and String(cat[1].p) == "szron", "w sklepie Wiktora są tylko marihuana i amfetamina — metę i kokainę robi się samemu")
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
	ok(G.pack_limit("safe", "dym", 80) == 5 and G.pack_one("safe", "dym", 80) >= 0, "spłukany też porcjuje, dopóki ma woreczki")
	var bags_k: int = G.item("woreczki")
	G.S.items["woreczki"] = 0
	G.store_items(G.S.stash.safe)["woreczki"] = 0
	ok(G.pack_one("safe", "dym", 80) == -1 and not G.pack_bag("safe", "dym", 80, 2).ok, "bez pustych woreczków nic się nie zapakuje")
	ok(G.shop_buy("woreczki") and G.item("woreczki") == 20, "spłukany i bez woreczków: Staś daje paczkę na krechę")
	ok(not G.shop_buy("woreczki"), "…ale tylko wtedy, gdy naprawdę nie ma w co pakować")
	G.S.items["woreczki"] = bags_k
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
	ok(G.item("majeranek") == 0 and int(G.store_items(S.stash.safe).get("majeranek", 0)) == 16, "majeranek przeniesiony do skrytki (w plecaku %d, w skrytce %d, skrytka %s / %d)" % [G.item("majeranek"), int(G.store_items(S.stash.safe).get("majeranek", 0)), G.units(G.store_total(S.stash.safe)), int(G.stash_cap("safe"))])
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
	var sum2: int = G.order_sum(o2)
	ok(sum2 == int(o2.stated) * int(o2.grams) and String(o2.text).contains(str(sum2)) and absf(float(o2.deadline) - float(o2.meet) - D.CLIENT_WAIT) < 0.1, "klient podaje sumę za całość (%d zł) i jest gotów czekać 5 godzin" % sum2)
	G.reply_order(o2.id, "price", sum2 + 1)
	ok(G.find_order(o2.id) != null, "negocjacja przez telefon nie zrywa rozmowy przy +1 zł do sumy")
	var o3 = G.find_order(o2.id)
	if o3 != null and o3.status == "new" and o3.counter != null:
		G.reply_order(o3.id, "counterok")
	o3 = G.find_order(o2.id)
	if o3 != null and o3.status == "new":
		G.reply_order(o3.id, "accept")
	o3 = G.find_order(o2.id)
	ok(o3 != null and o3.status == "accepted" and G.order_sum(o3) >= sum2, "zamówienie umówione (%d zł za %d g)" % [G.order_sum(o3) if o3 != null else 0, int(o2.grams)])
	if o3 != null:
		# inna godzina: klient zgadza się albo sam proponuje porę obok — bez fochów i bez utraty zadowolenia
		var m0: float = o3.meet
		var rng_m: Vector2 = G.meet_range()
		var tgt: float = clampf(m0 + 60.0, rng_m.x, rng_m.y)
		var sat_t: float = S.cust[o3.cust].sat
		var tries := 0
		var offered := false
		while float(o3.meet) != tgt and tries < 20 and G.find_order(o3.id) != null:
			tries += 1
			o3.resched = false
			G.reply_order(o3.id, "time", tgt)
			if o3.has("time_offer"):
				offered = true
				ok(absf(float(o3.time_offer) - tgt) >= 20.0 and float(o3.time_offer) >= rng_m.x and float(o3.time_offer) <= rng_m.y, "gdy pora nie pasuje, klient proponuje własną, dziś i niedaleko (%s)" % G.clock(o3.time_offer)) if tries == 1 else null
		ok(float(o3.meet) == tgt and float(S.cust[o3.cust].sat) == sat_t and absf(float(o3.deadline) - tgt - D.CLIENT_WAIT) < 0.1, "zmiana godziny spotkania (kontrpropozycja po drodze: %s)" % str(offered))
		o3["time_offer"] = clampf(tgt + 45.0, rng_m.x, rng_m.y)
		var want_t: float = o3.time_offer
		G.reply_order(o3.id, "timeok")
		ok(float(o3.meet) == want_t and not o3.has("time_offer"), "zgoda na porę zaproponowaną przez klienta")
		ok(G.meet_range().y < floorf(S.t / 1440.0) * 1440.0 + 1440.0 + 91.0 and G.meet_range().x >= S.t + 20.0, "na zegarze da się wskazać tylko dzisiejszą porę, najwcześniej za 20 minut")
		G.reply_order(o3.id, "decline")
		ok(G.find_order(o3.id) == null, "odwołanie spotkania")
	# zejście z ceny: klient bierze od ręki i jest zadowolony
	S.orders.clear()
	var od: Dictionary = G.make_order(G.cust_def("dominik"))
	var sat_d: float = S.cust.dominik.sat
	G.reply_order(od.id, "price", G.order_sum(od) - 10)
	ok(od.status == "accepted" and absf(float(od.agreed) * int(od.grams) - float(int(od.stated) * int(od.grams) - 10)) < 0.01 and float(S.cust.dominik.sat) > sat_d, "suma niższa o 10 zł: zgoda od razu i zadowolony klient")
	G.reply_order(od.id, "decline")
	# zamiana towaru: klient, który lubi też amfetaminę, zwykle się zgadza; sumę i gramy liczy na nowo
	S.orders.clear()
	var lvl_s: int = S.lvl
	S.lvl = maxi(int(S.lvl), int(D.PRODUCTS.szron.lvl))
	G.add_pack(S.inv, "szron", 100, 4)
	var cs = null
	for cd0 in D.CLIENTS:
		if "szron" in cd0.get("prods", [cd0.prod]) and String(cd0.prod) == "dym":
			cs = cd0
	ok(cs != null, "jest klient, który bierze trawę, ale lubi też amfetaminę")
	if cs != null:
		var swapped_ok := false
		for tr in range(12):
			S.orders.clear()
			var os: Dictionary = G.make_order(cs, 0, "dym")
			var opts_s: Array = G.swap_options(os)
			if tr == 0:
				ok(opts_s.size() >= 1 and String(opts_s[0].p) == "szron" and int(opts_s[0].have) >= 4, "zamiana towaru: do wyboru to, co masz zaporcjowane (amfetamina, %d porcji)" % int(opts_s[0].have))
			G.reply_order(os.id, "swap", "szron")
			if String(os.product) == "szron":
				swapped_ok = int(os.grams) >= 1 and G.order_sum(os) == int(os.stated) * int(os.grams) and bool(os.swapped)
				G.reply_order(os.id, "swap", "dym")
				swapped_ok = swapped_ok and String(os.product) == "szron"
				break
		ok(swapped_ok, "klient zgadza się na inny towar, podaje nową sumę; drugi raz przy tym zamówieniu pytać nie można")
	G.take_pack(S.inv, "szron", 100, 99)
	S.lvl = lvl_s
	# pięć godzin czekania bez żalu: po terminie zamówienie znika, ale zadowolenie i lojalność zostają
	S.orders.clear()
	var ow: Dictionary = G.make_order(G.cust_def("dominik"))
	G.reply_order(ow.id, "accept")
	var sat_w: float = S.cust.dominik.sat
	var loy_w: float = S.cust.dominik.loy
	var t_w: float = S.t
	S.t = float(ow.meet) + D.CLIENT_WAIT - 20.0
	G.on_tick()
	ok(G.find_order(ow.id) != null, "cztery i pół godziny po umówionej porze klient dalej czeka")
	S.t = float(ow.meet) + D.CLIENT_WAIT + 5.0
	G.on_tick()
	ok(G.find_order(ow.id) == null and float(S.cust.dominik.sat) == sat_w and float(S.cust.dominik.loy) == loy_w, "po pięciu godzinach odpuszcza, ale się nie zraża")
	S.t = t_w
	S.orders.clear()
	G.npcs.clear_customers()

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
	ok(absf(G.goods_total(tmp) - 4.0) < 0.001, "towar liczymy tylko w całych gramach (3,7 → 4)")
	# paczki o różnej wadze: woreczek, kostka, cegła; każda zajmuje tyle miejsca, ile waży
	G.add_pack(tmp, "dym", 75, 3, 5)
	G.add_pack(tmp, "dym", 75, 1, 250)
	G.add_pack(tmp, "dym", 75, 1, 500)
	G.add_pack(tmp, "dym", 75, 2)
	var kinds_t := {}
	for te in G.entries(tmp):
		if String(te.kind) == "pack":
			kinds_t[int(te.g)] = te
	ok(G.packed_total(tmp) == 15 + 250 + 500 + 2 and G.packed_bags(tmp) == 7 and kinds_t.size() == 4, "paczki: 3×5 g, kostka 250 g, cegła 500 g i 2×1 g to %d g w %d sztukach" % [G.packed_total(tmp), G.packed_bags(tmp)])
	ok(String(kinds_t[5].name).contains("5 g") and String(kinds_t[5].sub) == "woreczek" and String(kinds_t[250].sub) == "kostka" and String(kinds_t[500].sub) == "cegła" and String(kinds_t[500].name).contains("500 g") and String(kinds_t[250].icon) == "kostka_dym" and String(kinds_t[500].icon) == "brick_dym", "w ekwipunku każda paczka ma swoją wagę i nazwę: woreczek, kostka od 200 g, cegła od 500 g")
	ok(absf(float(kinds_t[5].size) - 15.0) < 0.01 and absf(float(kinds_t[5].weight) - 15.0 * D.W_PACK) < 0.01 and G.take_pack(tmp, "dym", 75, 2, 5) == 2 and G.packed_total(tmp) == 5 + 250 + 500 + 2, "trzy woreczki po 5 g zajmują 15 miejsc; zabranie dwóch zostawia jeden")
	var cb1: Dictionary = G.bag_combo([{"g": 5, "n": 1}, {"g": 2, "n": 2}, {"g": 1, "n": 3}], 8)
	var cb2: Dictionary = G.bag_combo([{"g": 5, "n": 2}], 8)
	var cb3: Dictionary = G.bag_combo([{"g": 13, "n": 4}], 8)
	ok(int(cb1.sum) == 8 and int(cb2.sum) == 5 and int(cb3.sum) == 0 and G.bag_sums([{"g": 5, "n": 1}, {"g": 2, "n": 1}], 9) == [2, 5, 7], "dobór paczek: 8 g z 5+2+1, z samych piątek tylko 5 g, z trzynastek nic")
	ok(G.grams(3.5) == "3,5 g" and G.grams(10.0) == "10 g" and G.units(1.7) == "2", "zapis ilości: 3,5 g, 10 g, miejsce 2")

	# --- policjant widzi do przodu i trochę na boki, ale nie za plecami
	var NS = G.npcs.get_script()
	ok(NS.sight(0.0) == 1.0 and NS.sight(1.2) > 0.0 and NS.sight(1.2) < 1.0 and NS.sight(2.4) == 0.0, "pole widzenia policji: przód tak, boki słabiej, tył wcale")

	# --- skradanie: widoczność, wzrok i słuch patroli, odciąganie, przeczesywanie, kryjówki
	await load("res://scripts/stealth_test.gd").run(self)

	# --- wymiana: taca, mniej/więcej towaru, szansa w procentach
	load("res://scripts/trade_test.gd").run(self)

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
	# okno sklepu w oszczędnym stylu: wiersz = nazwa + mały przycisk z ceną, opis dopiero w stopce po najechaniu
	var shop_btns: Array = U.modal_body.find_children("*", "Button", true, false)
	var buy_b: Button = null
	for sb0 in shop_btns:
		if String((sb0 as Button).text) == G.money(D.SHOP[0].price) and not (sb0 as Button).disabled:
			buy_b = sb0
	var had_bags: int = G.item(String(D.SHOP[0].id))
	var long_txt := 0
	for sl0 in U.modal_body.find_children("*", "Label", true, false):
		if String((sl0 as Label).text).length() > 60:
			long_txt += 1
	ok(shop_btns.size() >= D.SHOP.size() and buy_b != null and long_txt == 0, "sklep: każda pozycja ma mały przycisk z ceną, a na liście nie ma długich opisów (%d)" % long_txt)
	ok(U.shop_hint != null and not String(U.shop_hint.text).contains(String(D.SHOP[0].desc)), "sklep: stopka zaczyna od krótkiej wskazówki")
	U.Shop.hint(U, String(D.SHOP[0].name), String(D.SHOP[0].desc))
	ok(String(U.shop_hint.text).contains(String(D.SHOP[0].desc)), "sklep: opis pozycji pojawia się w stopce po najechaniu")
	if buy_b != null:
		buy_b.pressed.emit()
		await frames(2)
	ok(G.item(String(D.SHOP[0].id)) == had_bags + int(D.SHOP[0].n), "sklep: przycisk z ceną kupuje (%d → %d)" % [had_bags, G.item(String(D.SHOP[0].id))])
	U.close_all()
	U.open_scales()
	await frames(2)
	ok(U.mode == "modal" and U.shop_hint != null, "lombard: okno wag w tym samym stylu")
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
	# godziny otwarcia widać w świecie: po zamknięciu opada roleta i gaśnie światło
	var t_shop: float = S.t
	var pawn_f := {}
	for sf0 in G.world.shop_fronts:
		if (sf0.open as Array) == D.PAWN_OPEN:
			pawn_f = sf0
	S.t = floorf(S.t / 1440.0) * 1440.0 + 12.0 * 60.0
	G.world.shops_tick()
	var open_ok: bool = not pawn_f.is_empty() and not (pawn_f.shutter as Node3D).visible and G.pawn_open()
	S.t = floorf(S.t / 1440.0) * 1440.0 + 21.0 * 60.0
	G.world.shops_tick()
	ok(G.world.shop_fronts.size() >= 4 and open_ok and (pawn_f.shutter as Node3D).visible and not G.pawn_open() and (pawn_f.light == null or (pawn_f.light as OmniLight3D).light_energy == 0.0),
		"lombard, hurtownia, piekarnia i kebab mają godziny otwarcia: w południe witryna, wieczorem roleta i zgaszone światło (%d)" % G.world.shop_fronts.size())
	# mapa w telefonie zna godziny: wieczorem przy lombardzie stoi „zamknięte do 9:00”, w południe „do 19:00”
	var pawn_night := ""
	for nt0 in M.nav_targets():
		if String(nt0.id) == "pawn":
			pawn_night = String(nt0.label)
	S.t = floorf(S.t / 1440.0) * 1440.0 + 12.0 * 60.0
	var pawn_day := ""
	var has_clothes := false
	for nt1 in M.nav_targets():
		if String(nt1.id) == "pawn":
			pawn_day = String(nt1.label)
		if String(nt1.id) == "ciuchy":
			has_clothes = true
	ok(pawn_night.contains("zamknięte do 9:00") and pawn_day.contains("do 19:00") and not pawn_day.contains("zamknięte"), "mapa w telefonie podaje godziny lombardu (%s / %s)" % [pawn_night, pawn_day])
	var track_keep = S.track
	var nav_keep: bool = S.nav_on
	M.set_track("ciuchy")
	var ct: Dictionary = M.cur_target()
	ok(has_clothes and String(ct.get("id", "")) == "ciuchy" and String(ct.get("loc", "")) == "ciuchy", "Tania Odzież jest na liście celów i da się do niej poprowadzić trasę")
	S.track = track_keep
	S.nav_on = nav_keep
	# jedzenie na mieście: kebab nocą zamknięty; w dzień kosztuje, a najedzony Kuba ma więcej kondycji — do czasu
	var cash_sn: float = S.cash
	S.cash = 100.0
	S.t = floorf(S.t / 1440.0) * 1440.0 + 2.0 * 60.0
	var sn_closed: bool = not G.snack_buy("kebab") and S.cash == 100.0 and not G.fed() and G.snack_label("kebab").contains("otwarte 11:00")
	S.t = floorf(S.t / 1440.0) * 1440.0 + 13.0 * 60.0
	var stam0: float = G.player.max_stamina()
	var sn_ok: bool = G.snack_buy("kebab") and S.cash == 100.0 - float(D.SNACKS.kebab.price) and G.fed() and absf(G.player.max_stamina() - stam0 * D.SNACK_STAMINA) < 0.01
	var full_no: bool = not G.snack_buy("kebab") and S.cash == 100.0 - float(D.SNACKS.kebab.price)
	ok(full_no, "po kebabie drugi od razu nie wejdzie — na zapas się nie najesz")
	S.t += float(D.SNACKS.kebab.hours) * 60.0 + 1.0
	var sn_point := false
	for it_s in G.world.inter:
		if String(it_s.get("id", "")) == "snack_kebab":
			sn_point = true
	ok(sn_closed and sn_ok and not G.fed() and absf(G.player.max_stamina() - stam0) < 0.01 and sn_point, "kebab: zamknięty w nocy, w dzień za %d zł daje +20%% kondycji na %d godz. (potem mija)" % [int(D.SNACKS.kebab.price), int(D.SNACKS.kebab.hours)])
	S.cash = 1.0
	S.t = floorf(S.t / 1440.0) * 1440.0 + 8.0 * 60.0
	ok(not G.snack_buy("bulka") and S.cash == 1.0, "bez gotówki piekarnia nic nie sprzeda")
	S.erase("fed_until")
	# kod na gotówkę: wpisanie hasła litera po literze daje 1000 zł, niepełne hasło nic
	var cash_c: float = S.cash
	U.cheat_buf = ""
	for ch0 in "jebacmazu":
		U.cheat_key(KEY_A + (ch0.unicode_at(0) - 97))
	var half_ok: bool = S.cash == cash_c
	U.cheat_key(KEY_R)
	ok(half_ok and S.cash == cash_c + 1000.0 and U.cheat_buf == "", "kod „jebacmazur” dokłada 1000 zł do kieszeni")
	# Prawdziwa ścieżka wejścia: E/C/M nie mogą otworzyć drzwi, kucania ani mapy.
	U.close_all()
	var crouch_c: bool = G.player.crouching
	var test_c: bool = G.test_mode
	G.test_mode = false
	for ch0 in U.CHEAT_CASH:
		var ev_c := InputEventKey.new()
		ev_c.keycode = KEY_A + (ch0.unicode_at(0) - 97)
		ev_c.physical_keycode = ev_c.keycode
		ev_c.pressed = true
		U._input(ev_c)
	G.test_mode = test_c
	ok(S.cash == cash_c + 2000.0 and U.mode == "" and G.player.crouching == crouch_c, "kod wpisany przez obsługę klawiatury działa ponownie i nie otwiera mapy ani nie włącza kucania")
	U.open_inventory("")
	for ch0 in U.CHEAT_CASH:
		U.cheat_key(KEY_A + ch0.unicode_at(0) - 97)
	ok(U.inv.l_cash.text == G.money(S.cash) and U.mode == "inv", "po kodzie otwarty ekwipunek od razu pokazuje nową gotówkę")
	U.close_all()
	U.cheat_key(KEY_J, 10000)
	U.cheat_key(KEY_E, 10000 + U.CHEAT_TIMEOUT_MS + 1)
	ok(U.cheat_buf.is_empty(), "przerwa ponad pięć sekund przerywa wpisywanie kodu")
	U.cheat_key(KEY_J)
	U.cheat_key(KEY_SPACE)
	ok(U.cheat_buf.is_empty(), "spacja przerywa kod — zwykłe klawisze działają dalej")
	var field_c := LineEdit.new()
	U.add_child(field_c)
	field_c.grab_focus()
	var ev_text := InputEventKey.new()
	ev_text.keycode = KEY_J
	ev_text.pressed = true
	ok(not U.cheat_input(ev_text) and U.cheat_buf.is_empty(), "pisanie w polu tekstowym nie uruchamia kodu ani nie zabiera liter")
	field_c.release_focus()
	field_c.queue_free()
	U.cheat_reset()
	S.cash = cash_c
	# Zdzichu: piwo raz dziennie studzi śledztwo
	var inv_b: float = S.invest
	S.invest = 30.0
	S.cash = 50.0
	S.erase("beer_day")
	var beer1: bool = G.beer_ready() and G.beer_give() and absf(S.invest - (30.0 - G.BEER_INVEST)) < 0.01 and S.cash == 50.0 - float(G.BEER_PRICE)
	ok(beer1 and not G.beer_ready() and not G.beer_give() and S.cash == 50.0 - float(G.BEER_PRICE), "piwo dla Zdzicha: śledztwo −%d, ale tylko raz na dzień" % int(G.BEER_INVEST))
	S.t += 1440.0
	ok(G.beer_ready(), "następnego dnia Zdzichu znów ma pragnienie")
	S.t -= 1440.0
	S.erase("beer_day")
	S.invest = inv_b
	S.cash = cash_sn
	S.t = t_shop
	G.world.shops_tick()
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
	load("res://scripts/dealers_test.gd").run(self)
	load("res://scripts/reputation_test.gd").run(self)
	load("res://scripts/workers_test.gd").run(self)
	load("res://scripts/lab_care_test.gd").run(self)
	load("res://scripts/extension_test.gd").run(self)

	# --- prolog: nalot na laboratorium, ucieczka, eksplozje
	if not M.args.has("noprologue"):
		var keep_state: Dictionary = G.S
		await load("res://scripts/prologue_test.gd").run(self)
		G.S = keep_state
		U.close_all()

	# Dostawy: jedna paczka nie może być przydzielona dwa razy, nie wolno zmieniać zapasu.
	var real_state: Dictionary = G.S
	G.S = G.new_state()
	G.S.orders = [
		{"id": 901, "cust": "dominik", "product": "dym", "grams": 3, "meet": 600.0, "deadline": 900.0, "status": "accepted", "spot": D.SPOTS[0].id},
		{"id": 902, "cust": "dominik", "product": "dym", "grams": 3, "meet": 660.0, "deadline": 960.0, "status": "accepted", "spot": D.SPOTS[0].id}]
	G.add_pack(G.S.inv, "dym", 100, 3)
	var inventory_before := JSON.stringify(G.S.inv)
	var deliveries: Array = G.delivery_plan()
	ok(deliveries.size() == 2 and int(deliveries[0].ready) == 3 and int(deliveries[1].missing) == 3 and JSON.stringify(G.S.inv) == inventory_before, "plan dostaw rezerwuje paczki tylko raz i nie zmienia kieszeni")
	G.S.inv = G.new_store()
	G.add_pack(G.S.inv, "dym", 100, 1, 5)
	deliveries = G.delivery_plan()
	ok(deliveries[0].repack and int(deliveries[0].ready) == 0, "plan ostrzega, że woreczka 5 g nie podzielisz na ulicy na zamówienie 3 g")
	G.S.inv = G.new_store()
	G.add_pack(G.S.inv, "dym", 10, 6)
	deliveries = G.delivery_plan()
	ok(int(deliveries[0].ready) == 0, "plan nie oznacza słabego towaru jako gotowego dla wymagającego klienta")
	G.S.t = 1000.0
	ok(G.delivery_plan().is_empty(), "plan pomija spotkania, których czas już minął")
	G.S = real_state

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
			# woreczki: bot dokupuje paczkę u Stasia, gdy zapas spada (bez nich nic nie zapakuje)
			if G.bags_at("safe") < 25:
				G.shop_buy("woreczki")
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
				G.reply_order(o.id, "price", int(round(float(G.order_sum(o)) * 1.08)))
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
				for ingredient in D.RECIPES[rid].input:
					var need: int = int(D.RECIPES[rid].input[ingredient])
					while G.item_at(room, ingredient) < need and S.cash > 350.0:
						if not G.shop_buy(ingredient):
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
