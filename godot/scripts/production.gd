extends RefCounted
## PRODUKCJA w kryjówkach. Wszystko sterowane danymi z D.RECIPES: uprawa konopi na regałach pod LED-ami,
## suszenie zbioru, syntezy przy stole laboratoryjnym. Do tego zapach, prąd i RYZYKO NALOTU na kryjówkę.
##
## Zadanie na stanowisku (S.hide[pokój].jobs[nr mebla]):
##   {r, prog 0..1, water 0..100, health 0..100, fert, trim, mode, hold (-1 albo nr etapu), hold_t, ripe_t, pots, burnt}
## Suszarka: {r: "_dry", p, g, pur, prog}. Mokry zbiór czeka w S.hide[pokój].wet = [{p, g, pur}].

const ROOMS := ["garage", "basement"]


static func hide(room: String) -> Dictionary:
	var h: Dictionary = G.S.hide[room]
	if not h.has("jobs"):
		h["jobs"] = {}
	if not h.has("wet"):
		h["wet"] = []
	return h


## stare zapisy: uprawa w namiocie zapisana jako {start, end, hits}
static func migrate() -> void:
	for room in ROOMS:
		if not G.S.hide.has(room):
			continue
		var h := hide(room)
		var old: Dictionary = h.get("grow", {})
		for k in old.keys():
			var j: Dictionary = old[k]
			var total: float = maxf(1.0, float(j.end) - float(j.start))
			h.jobs[k] = new_job("konopie", 2)
			h.jobs[k].prog = clampf((G.S.t - float(j.start)) / total, 0.0, 1.0)
		h["grow"] = {}


static func furn(room: String, idx: int) -> Dictionary:
	var items: Array = G.S.hide[room].items
	if idx < 0 or idx >= items.size():
		return {}
	return G.furn_def(String(items[idx].f))


static func kind(room: String, idx: int) -> String:
	var f := furn(room, idx)
	return String(f.get("func", "")) if not f.is_empty() else ""


static func has_station(room: String, fn: String) -> bool:
	for it in G.S.hide[room].items:
		if String(G.furn_def(String(it.f)).get("func", "")) == fn:
			return true
	return false


static func job(room: String, idx: int) -> Variant:
	return hide(room).jobs.get(str(idx))


static func recipe(j: Dictionary) -> Dictionary:
	return D.RECIPES.get(String(j.r), {})


static func new_job(rid: String, pots: int) -> Dictionary:
	return {"r": rid, "prog": 0.0, "water": 100.0, "health": 100.0, "fert": false, "trim": false, "mode": 0 if rid == "konopie" else 1,
		"hold": -1, "hold_t": 0.0, "ripe_t": 0.0, "pots": pots, "burnt": false, "t0": G.S.t}


## przepisy, które da się nastawić na tym stanowisku (z informacją, czego brakuje)
static func recipes_for(room: String, idx: int) -> Array:
	var out := []
	var k := kind(room, idx)
	for rid in D.RECIPES:
		var r: Dictionary = D.RECIPES[rid]
		if String(r.station) != k:
			continue
		var miss := ""
		if int(G.S.lvl) < int(r.lvl):
			miss = "od poziomu %d" % int(r.lvl)
		else:
			for it in r.input:
				if G.item_at(room, it) < int(r.input[it]):
					miss = "brakuje: %s ×%d" % [String(D.ITEMS[it].name).to_lower(), int(r.input[it])]
		out.append({"id": rid, "r": r, "miss": miss})
	return out


static func start(room: String, idx: int, rid: String) -> bool:
	if job(room, idx) != null or not D.RECIPES.has(rid):
		return false
	var r: Dictionary = D.RECIPES[rid]
	if String(r.station) != kind(room, idx) or int(G.S.lvl) < int(r.lvl):
		return false
	for it in r.input:
		if G.item_at(room, it) < int(r.input[it]):
			return false
	for it in r.input:
		G.take_item(room, it, int(r.input[it]))
	hide(room).jobs[str(idx)] = new_job(rid, int(furn(room, idx).get("pots", 1)))
	G.add_minutes(6.0)
	G.notify("%s: nastawione." % String(r.name), "good")
	return true


static func stage_index(j: Dictionary) -> int:
	var st: Array = recipe(j).stages
	for i in range(st.size()):
		if float(j.prog) < float(st[i].to) - 0.00001:
			return i
	return st.size() - 1


static func stage_name(j: Dictionary) -> String:
	if String(j.r) == "_dry":
		return "Suszenie" if float(j.prog) < 1.0 else "Wysuszone"
	if float(j.prog) >= 1.0:
		return "Gotowe"
	if int(j.hold) >= 0:
		return String(recipe(j).stages[int(j.hold)].hold)
	return String(recipe(j).stages[stage_index(j)].name)


static func mode_def(j: Dictionary) -> Dictionary:
	var m: Array = recipe(j).get("modes", [])
	return m[clampi(int(j.mode), 0, m.size() - 1)] if not m.is_empty() else {"speed": 1.0, "smell": 1.0, "power": 1.0, "water": 1.0, "pur": 0}


## ile minut gry zostało do końca (albo do najbliższej czynności gracza)
static func minutes_left(j: Dictionary) -> float:
	if float(j.prog) >= 1.0 or int(j.get("hold", -1)) >= 0:
		return 0.0
	if String(j.r) == "_dry":
		return (1.0 - float(j.prog)) * D.DRY_HOURS * 60.0
	var r := recipe(j)
	var target := 1.0
	for st in r.stages:
		if float(j.prog) < float(st.to) - 0.00001 and st.has("hold"):
			target = float(st.to)
			break
	return (target - float(j.prog)) * float(r.hours) * 60.0 / float(mode_def(j).speed)


## upływ czasu na wszystkich stanowiskach (wołane co 10 minut gry)
static func tick(minutes: float) -> void:
	for room in ROOMS:
		if not G.S.hide.has(room):
			continue
		var h := hide(room)
		var tank := has_station(room, "tank")
		for k in h.jobs.keys():
			var j: Dictionary = h.jobs[k]
			if String(j.r) == "_dry":
				j.prog = minf(1.0, float(j.prog) + minutes / (D.DRY_HOURS * 60.0))
				continue
			var r := recipe(j)
			if r.is_empty():
				h.jobs.erase(k)
				continue
			var md := mode_def(j)
			if float(j.prog) >= 1.0:
				# przestane: konopie przejrzewają, chemia wietrzeje
				j.ripe_t = float(j.ripe_t) + minutes
				if float(j.ripe_t) > 18.0 * 60.0:
					j.health = maxf(20.0, float(j.health) - minutes * 2.0 / 60.0)
				continue
			if int(j.hold) >= 0:
				j.hold_t = float(j.hold_t) + minutes
				if float(j.hold_t) > 120.0:
					j.health = maxf(10.0, float(j.health) - minutes * 6.0 / 60.0)
				continue
			var grows := true
			if r.has("water"):
				if tank:
					j.water = maxf(float(j.water), 70.0)
				else:
					j.water = maxf(0.0, float(j.water) - float(r.water) * float(md.get("water", 1.0)) * (1.25 if j.fert else 1.0) * minutes / 60.0)
				if float(j.water) <= 0.0:
					grows = false
					j.health = maxf(0.0, float(j.health) - minutes * 7.0 / 60.0)
				elif float(j.water) > 25.0:
					j.health = minf(100.0, float(j.health) + minutes * 1.2 / 60.0)
			if not grows:
				continue
			var before := float(j.prog)
			var after := before + minutes / (float(r.hours) * 60.0) * float(md.speed)
			for i in range(r.stages.size()):
				var st: Dictionary = r.stages[i]
				if st.has("hold") and before < float(st.to) - 0.00001 and after >= float(st.to):
					after = float(st.to)
					j.hold = i
					j.hold_t = 0.0
					G.notify("%s: trzeba teraz — %s." % [String(r.name), String(st.hold).to_lower()], "warn")
					break
			if after >= 1.0:
				after = 1.0
				if randf() < float(md.get("burn", 0.0)):
					j.burnt = true
				G.notify("%s (%s): gotowe do zebrania." % [String(r.name), String(D.ROOMS[room].name)], "good")
			j.prog = after


# ---------------------------------------------------------------- czynności gracza
static func water(room: String, idx: int) -> bool:
	var j = job(room, idx)
	if j == null or not recipe(j).has("water") or float(j.prog) >= 1.0:
		return false
	j.water = 100.0
	G.add_minutes(4.0)
	return true


static func can_fert(room: String, idx: int) -> bool:
	var j = job(room, idx)
	return j != null and recipe(j).has("water") and not j.fert and float(j.prog) < 0.6 and G.item_at(room, "nawoz") > 0


static func fertilize(room: String, idx: int) -> bool:
	if not can_fert(room, idx):
		return false
	G.take_item(room, "nawoz", 1)
	job(room, idx).fert = true
	G.add_minutes(3.0)
	return true


static func can_trim(room: String, idx: int) -> bool:
	var j = job(room, idx)
	return j != null and recipe(j).has("water") and not j.trim and float(j.prog) >= 0.2 and float(j.prog) < 0.6


static func trim(room: String, idx: int) -> bool:
	if not can_trim(room, idx):
		return false
	job(room, idx).trim = true
	G.add_minutes(10.0)
	return true


static func set_mode(room: String, idx: int, m: int) -> void:
	var j = job(room, idx)
	if j != null and float(j.prog) < 1.0:
		j.mode = clampi(m, 0, recipe(j).modes.size() - 1)


## czynność kończąca etap (przelanie, filtrowanie…)
static func proceed(room: String, idx: int) -> bool:
	var j = job(room, idx)
	if j == null or int(j.hold) < 0:
		return false
	j.hold = -1
	j.hold_t = 0.0
	j.prog = float(j.prog) + 0.0001
	G.add_minutes(8.0)
	return true


## przewidywany plon i czystość przy obecnym stanie
static func forecast(j: Dictionary) -> Dictionary:
	var r := recipe(j)
	var md := mode_def(j)
	var hl := float(j.health) / 100.0
	var g := 0.0
	var pur := 0.0
	if r.has("water"):
		g = float(j.pots) * float(r["yield"]) * (0.55 + 0.45 * hl) * (1.25 if j.fert else 1.0) * (1.35 if G.has_skill("ogrodnik") else 1.0)
		pur = float(r.pur) + hl * 16.0 + (8.0 if j.trim else 0.0) + float(md.get("pur", 0))
	else:
		g = float(r["yield"]) * (0.6 + 0.4 * hl) * (0.7 if j.burnt else 1.0)
		pur = float(r.pur) + float(md.get("pur", 0)) + hl * 8.0 - (12.0 if j.burnt else 0.0)
	return {"g": maxf(1.0, round(g)), "pur": G.qpure(clampf(pur, 20.0, 95.0))}


static func collect(room: String, idx: int) -> Dictionary:
	var j = job(room, idx)
	if j == null or float(j.prog) < 1.0:
		return {}
	var h := hide(room)
	if String(j.r) == "_dry":
		G.add_bulk(G.S.stash[room], String(j.p), int(j.pur), float(j.g))
		G.S.stats.grown = int(G.S.stats.grown) + int(j.g)
		G.add_xp(float(j.g) * 0.5)
		G.notify("Wysuszone: %s %s (%d%%) — w skrytce kryjówki." % [G.grams(j.g), String(D.PRODUCT_GEN[j.p]), int(j.pur)], "good")
		h.jobs.erase(str(idx))
		return {"g": float(j.g), "pur": int(j.pur), "p": String(j.p)}
	var r := recipe(j)
	var f := forecast(j)
	var p := String(r.product)
	h.jobs.erase(str(idx))
	G.add_minutes(6.0)
	if r.get("wet", false):
		h.wet.append({"p": p, "g": float(f.g), "pur": int(f.pur)})
		G.notify("Zebrano %s świeżego suszu (%d%%). Teraz do suszarki." % [G.grams(f.g), int(f.pur)], "good")
	else:
		G.add_bulk(G.S.stash[room], p, int(f.pur), float(f.g))
		G.S.stats["cooked"] = int(G.S.stats.get("cooked", 0)) + int(f.g)
		G.add_xp(float(f.g) * 0.9)
		G.notify("%s: %s (%d%%)%s — w skrytce kryjówki." % [String(r.name), G.grams(f.g), int(f.pur), " • partia przypalona" if j.burnt else ""], "warn" if j.burnt else "good")
	return {"g": float(f.g), "pur": int(f.pur), "p": p, "wet": r.get("wet", false)}


static func discard(room: String, idx: int) -> void:
	hide(room).jobs.erase(str(idx))


static func wet_total(room: String) -> float:
	var n := 0.0
	for w in hide(room).wet:
		n += float(w.g)
	return n


## wkłada mokry zbiór do suszarki (najpierw najlepszy; jedna czystość na raz)
static func dry_start(room: String, idx: int) -> bool:
	var h := hide(room)
	if kind(room, idx) != "dry" or job(room, idx) != null or h.wet.is_empty():
		return false
	var cap := float(furn(room, idx).get("cap", 90))
	var w: Dictionary = h.wet[0]
	var g := minf(cap, float(w.g))
	w.g = float(w.g) - g
	if float(w.g) <= 0.01:
		h.wet.remove_at(0)
	h.jobs[str(idx)] = {"r": "_dry", "p": String(w.p), "g": g, "pur": int(w.pur), "prog": 0.0}
	G.add_minutes(5.0)
	return true


# ---------------------------------------------------------------- kryjówka: zapach, prąd, ryzyko
static func stats(room: String) -> Dictionary:
	var h := hide(room)
	var smell := 0.0
	var power := 0.0
	var active := 0
	var items: Array = G.S.hide[room].items
	for i in range(items.size()):
		var f := G.furn_def(String(items[i].f))
		var fn := String(f.get("func", ""))
		if fn == "tank":
			power += 2.0
		elif fn == "filter":
			power += 3.0
		var j = h.jobs.get(str(i))
		if j == null:
			continue
		active += 1
		if String(j.r) == "_dry":
			if float(j.prog) < 1.0:
				smell += 8.0
				power += 1.0
			continue
		var r := recipe(j)
		var md := mode_def(j)
		if r.has("water"):
			var bloom := 1.0 if float(j.prog) >= 0.6 else (0.45 if float(j.prog) >= 0.2 else 0.15)
			smell += float(r.smell) * float(j.pots) * bloom * float(md.smell)
			power += float(r.power) * float(j.pots) * float(md.power)
		elif float(j.prog) < 1.0:
			smell += float(r.smell) * float(md.smell) * (0.5 if int(j.hold) >= 0 else 1.0)
			power += float(r.power) * float(md.power)
		else:
			smell += float(r.smell) * 0.25
	smell += wet_total(room) * 0.12
	var filt := has_station(room, "filter")
	if filt:
		smell *= 0.4
	var risk := clampf(smell * 0.7 + power * 0.25 + float(G.S.invest) * 0.25 - 10.0, 0.0, 95.0) if active > 0 or wet_total(room) > 0.0 else 0.0
	return {"smell": smell, "power": power, "risk": risk, "active": active, "filter": filt, "tank": has_station(room, "tank")}


static func risk_name(risk: float) -> String:
	return "znikome" if risk < 12.0 else ("niskie" if risk < 30.0 else ("średnie" if risk < 55.0 else ("wysokie" if risk < 75.0 else "bardzo wysokie")))


## dzienne szanse nalotu przy danym ryzyku
static func raid_chance(risk: float) -> float:
	if risk < 12.0:
		return 0.0
	return pow(risk / 100.0, 1.5) * 0.35


## rozliczenie doby: prąd i losowanie nalotu (ostrzeżenie przychodzi SMS-em kilka godzin wcześniej)
static func daily() -> void:
	for room in ROOMS:
		if not G.room_owned(room):
			continue
		var h := hide(room)
		var st := stats(room)
		var bill: float = round(float(st.power))
		if bill > 0.0:
			var paid := minf(G.S.cash, bill)
			G.S.cash -= paid
			if paid < bill:
				G.S.debt += round((bill - paid) * 1.5)
			G.notify("Prąd w kryjówce (%s): −%s" % [String(D.ROOMS[room].name), G.money(bill)])
		if h.has("raid_at"):
			continue
		if randf() < raid_chance(float(st.risk)):
			h["raid_at"] = G.S.t + randf_range(7.0, 15.0) * 60.0
			h["raid_warned"] = false


## nalot: 3 godziny wcześniej ostrzeżenie; w chwili nalotu liczy się AKTUALNE ryzyko
static func raid_tick() -> void:
	for room in ROOMS:
		if not G.S.hide.has(room):
			continue
		var h := hide(room)
		if not h.has("raid_at"):
			continue
		var at := float(h.raid_at)
		if not h.get("raid_warned", false) and G.S.t >= at - 180.0:
			h["raid_warned"] = true
			G.chat("stas", "Kuba, koło: %s kręci się nieoznakowany i węszy. Jak masz tam coś, czego nie powinni znaleźć — masz ze trzy godziny." % String(D.ROOMS[room].name))
		if G.S.t >= at:
			h.erase("raid_at")
			h.erase("raid_warned")
			raid(room)


static func raid(room: String) -> Dictionary:
	var h := hide(room)
	var st := stats(room)
	var goods := G.goods_total(G.S.stash[room])
	var res := {"room": room, "found": false, "lost_g": 0.0, "lost_cash": 0.0}
	if float(st.risk) < 20.0 and goods < 1.0:
		G.add_invest(-8.0)
		G.chat("stas", "Byli, pokręcili się, nic nie znaleźli i pojechali. Tym razem.")
		G.notify("Nalot na: %s — nic nie znaleźli." % String(D.ROOMS[room].name), "good")
		return res
	res.found = true
	res.lost_g = goods + wet_total(room)
	res.lost_cash = float(G.S.stash[room].cash)
	var fresh := G.new_store()
	fresh["items"] = G.store_items(G.S.stash[room])
	G.S.stash[room] = fresh
	h.jobs.clear()
	h.wet.clear()
	G.add_heat(25.0, false)
	G.add_invest(20.0)
	G.S.stats["raids"] = int(G.S.stats.get("raids", 0)) + 1
	G.chat("stas", "Wyłamali drzwi i wynieśli wszystko: rośliny, towar, kasę. Sprzęt zostawili. Nie pokazuj się tam przez parę dni.")
	G.notify("NALOT na: %s! Straciłeś %s towaru i %s." % [String(D.ROOMS[room].name), G.grams(res.lost_g), G.money(res.lost_cash)], "bad")
	# złapany na miejscu
	if G.player != null and G.player.loc == room and G.main != null:
		G.main.raided_inside()
	return res
