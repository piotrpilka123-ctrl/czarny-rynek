extends RefCounted
## PRODUKCJA w kryjówkach. Wszystko sterowane danymi z D.RECIPES: uprawa konopi na regałach pod LED-ami,
## suszenie zbioru, syntezy przy stole laboratoryjnym. Do tego zapach, prąd i RYZYKO NALOTU na kryjówkę.
##
## Zadanie na stanowisku (S.hide[pokój].jobs[nr mebla]):
##   {r, prog 0..1, water 0..100, health 0..100, fert, trim, mode, hold (-1 albo nr etapu), hold_t, ripe_t, pots, burnt}
## Suszarka: {r: "_dry", p, g, pur, prog}. Mokry zbiór czeka w S.hide[pokój].wet = [{p, g, pur}].
##
## UPRAWA W DONICZKACH (S.hide[pokój].pots): każda doniczka to osobny krzak, doglądany osobno:
##   {x, z, pl: null albo {prog 0..1, water 0..100, health 0..100, fert, trim, ripe_t, lit_t, grow_t, t0}}
## Doniczki, nasiona i nawóz to przedmioty ze sklepu. Lampa LED (mebel „lampa_led”) oświetla doniczki pod sobą.

const ROOMS := ["garage", "basement"]


static func hide(room: String) -> Dictionary:
	var h: Dictionary = G.S.hide[room]
	if not h.has("jobs"):
		h["jobs"] = {}
	if not h.has("wet"):
		h["wet"] = []
	if not h.has("pots"):
		h["pots"] = []
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
		_migrate_racks(room)


## stare namioty i regały uprawowe zamieniają się w lampę LED i doniczki pod nią (rośliny zachowują postęp)
static func _migrate_racks(room: String) -> void:
	var h := hide(room)
	var items: Array = G.S.hide[room].items
	var changed := false
	for it in items:
		if String(it.f) == "namiot" or String(it.f) == "regal_led":
			changed = true
	if not changed:
		return
	var out: Array = []
	var jobs := {}
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var fid := String(it.f)
		var j = h.jobs.get(str(i))
		if fid != "namiot" and fid != "regal_led":
			if j != null:
				jobs[str(out.size())] = j
			out.append(it)
			continue
		var n := 2 if fid == "namiot" else 4
		out.append({"f": "lampa_led", "x": float(it.x), "z": float(it.z), "r": int(it.r), "mode": int(j.mode) if j != null and j.has("mode") else 0})
		for k in range(n):
			var off := (k - (n - 1) * 0.5) * 0.4
			var px := float(it.x) + (off if int(it.r) % 2 == 0 else 0.0)
			var pz := float(it.z) + (off if int(it.r) % 2 == 1 else 0.0)
			var pt := {"x": px, "z": pz, "pl": null}
			if j != null and String(j.get("r", "")) == "konopie":
				var pl := plant_new()
				for key in ["prog", "water", "health", "fert", "trim", "ripe_t"]:
					pl[key] = j.get(key, pl[key])
				pl.lit_t = 1.0
				pl.grow_t = 1.0
				pt.pl = pl
			h.pots.append(pt)
	G.S.hide[room].items = out
	h.jobs = jobs


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
		plants_tick(room, minutes, tank)
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


# ---------------------------------------------------------------- uprawa w doniczkach
const POT_R := 0.17          # promień doniczki
const POT_GAP := 0.4         # najmniejszy odstęp między środkami doniczek


static func pots(room: String) -> Array:
	return hide(room).pots if G.S.hide.has(room) else []


static func pot(room: String, i: int) -> Dictionary:
	var ps := pots(room)
	return ps[i] if i >= 0 and i < ps.size() else {}


static func plant_of(room: String, i: int) -> Variant:
	var pt := pot(room, i)
	return pt.get("pl") if not pt.is_empty() else null


static func plant_new() -> Dictionary:
	return {"prog": 0.0, "water": 70.0, "health": 100.0, "fert": false, "trim": false, "ripe_t": 0.0, "lit_t": 0.0, "grow_t": 0.0, "t0": G.S.t}


static func plant_count(room: String) -> int:
	var n := 0
	for pt in pots(room):
		if pt.pl != null:
			n += 1
	return n


static func lamps(room: String) -> Array:
	var out := []
	if not G.S.hide.has(room):
		return out
	for it in G.S.hide[room].items:
		if String(G.furn_def(String(it.f)).get("func", "")) == "growlight":
			out.append(it)
	return out


## tryb lampy nad punktem: -1 = poza światłem, 0 = cykl 18/6, 1 = cykl 24/0
static func light_at(room: String, x: float, z: float) -> int:
	var best := -1
	for it in lamps(room):
		var rc: Rect2 = G.furn_rect(G.furn_def(String(it.f)), float(it.x), float(it.z), int(it.r)).grow(0.12)
		if rc.has_point(Vector2(x, z)):
			best = maxi(best, int(it.get("mode", 0)))
	return best


static func lamp_mode(m: int) -> Dictionary:
	var md: Array = D.RECIPES.konopie.modes
	return md[clampi(m, 0, md.size() - 1)]


## czy doniczka zmieści się w tym miejscu (ściany, drzwi, meble stojące na podłodze, inne doniczki)
static func pot_valid(room: String, x: float, z: float, ignore := -1) -> bool:
	if not G.S.hide.has(room):
		return false
	var R: Dictionary = D.ROOMS[room]
	var m := POT_R + 0.06
	if absf(x) > float(R.w) * 0.5 - m or absf(z) > float(R.d) * 0.5 - m:
		return false
	if Rect2(-1.0, float(R.d) * 0.5 - 1.5, 2.0, 1.5).grow(POT_R).has_point(Vector2(x, z)):
		return false
	for it in G.S.hide[room].items:
		var f: Dictionary = G.furn_def(String(it.f))
		if f.is_empty() or f.get("hang", false):
			continue
		if G.furn_rect(f, float(it.x), float(it.z), int(it.r)).grow(POT_R).has_point(Vector2(x, z)):
			return false
	var ps := pots(room)
	for i in range(ps.size()):
		if i != ignore and Vector2(float(ps[i].x) - x, float(ps[i].z) - z).length() < POT_GAP:
			return false
	return true


static func pot_place(room: String, x: float, z: float) -> bool:
	if not G.room_owned(room) or G.item_at(room, "doniczka") <= 0:
		return false
	if pots(room).size() >= int(D.POT_MAX.get(room, 8)):
		G.notify("Więcej doniczek się tu nie zmieści (%d)." % int(D.POT_MAX.get(room, 8)), "warn")
		return false
	if not pot_valid(room, x, z):
		return false
	G.take_item(room, "doniczka", 1)
	hide(room).pots.append({"x": snappedf(x, 0.05), "z": snappedf(z, 0.05), "pl": null})
	Sfx.play("place")
	if G.world != null:
		G.world.refresh_furniture(room)
	return true


## pustą doniczkę można zabrać z powrotem do plecaka
static func pot_take(room: String, i: int) -> bool:
	var pt := pot(room, i)
	if pt.is_empty() or pt.pl != null:
		return false
	hide(room).pots.remove_at(i)
	G.S.items["doniczka"] = G.item("doniczka") + 1
	Sfx.play("pickup")
	if G.world != null:
		G.world.refresh_furniture(room)
	return true


static func plant_seed(room: String, i: int) -> bool:
	var pt := pot(room, i)
	if pt.is_empty() or pt.pl != null or G.item_at(room, "nasiona") <= 0 or int(G.S.lvl) < int(D.RECIPES.konopie.lvl):
		return false
	G.take_item(room, "nasiona", 1)
	pt.pl = plant_new()
	G.add_minutes(2.0)
	return true


static func plant_stage(pl: Dictionary) -> String:
	var prog := float(pl.prog)
	if prog >= 1.0:
		return "Dojrzała" if float(pl.ripe_t) <= 18.0 * 60.0 else "Przejrzała"
	for st in D.RECIPES.konopie.stages:
		if prog < float(st.to) - 0.00001:
			return String(st.name)
	return "Kwitnienie"


static func plant_water(room: String, i: int) -> bool:
	var pl = plant_of(room, i)
	if pl == null:
		return false
	pl.water = 100.0
	G.add_minutes(2.0)
	return true


static func plant_can_fert(room: String, i: int) -> bool:
	var pl = plant_of(room, i)
	return pl != null and not pl.fert and float(pl.prog) < 0.6 and G.item_at(room, "nawoz") > 0


static func plant_fert(room: String, i: int) -> bool:
	if not plant_can_fert(room, i):
		return false
	G.take_item(room, "nawoz", 1)
	plant_of(room, i).fert = true
	G.add_minutes(2.0)
	return true


## co zrobi sekator: "harvest" (zbiór), "trim" (przycięcie liści), "early" (ścięcie przed czasem), "" (nic)
static func plant_cut_kind(room: String, i: int) -> String:
	var pl = plant_of(room, i)
	if pl == null:
		return ""
	var prog := float(pl.prog)
	if prog >= 1.0:
		return "harvest"
	if prog >= 0.2 and prog < 0.6 and not pl.trim:
		return "trim"
	return "early"


static func plant_forecast(room: String, i: int) -> Dictionary:
	var pt := pot(room, i)
	if pt.is_empty() or pt.pl == null:
		return {}
	var pl: Dictionary = pt.pl
	var r: Dictionary = D.RECIPES.konopie
	var hl := float(pl.health) / 100.0
	var g: float = float(r["yield"]) * (0.55 + 0.45 * hl) * (1.25 if pl.fert else 1.0) * (1.35 if G.has_skill("ogrodnik") else 1.0)
	var lit: float = clampf(float(pl.lit_t) / maxf(1.0, float(pl.grow_t)), 0.0, 1.0) if float(pl.grow_t) > 0.0 else (1.0 if light_at(room, float(pt.x), float(pt.z)) >= 0 else 0.0)
	var lm := light_at(room, float(pt.x), float(pt.z))
	var pur: float = float(r.pur) + hl * 16.0 + (8.0 if pl.trim else 0.0) + float(D.POT_UNLIT_PUR) * (1.0 - lit) + (float(lamp_mode(lm).pur) if lm >= 0 else 0.0)
	return {"g": maxf(1.0, round(g)), "pur": G.qpure(clampf(pur, 20.0, 95.0)), "lit": lit}


## ile minut gry do dojrzałości przy obecnym świetle (bez wody = nie rośnie)
static func plant_minutes_left(room: String, i: int) -> float:
	var pt := pot(room, i)
	if pt.is_empty() or pt.pl == null or float(pt.pl.prog) >= 1.0:
		return 0.0
	var lm := light_at(room, float(pt.x), float(pt.z))
	var sp: float = float(lamp_mode(lm).speed) if lm >= 0 else float(D.POT_UNLIT_SPEED)
	return (1.0 - float(pt.pl.prog)) * float(D.RECIPES.konopie.hours) * 60.0 / sp


## sekator: zbiór dojrzałej rośliny, przycięcie liści w fazie wzrostu albo ścięcie przed czasem
static func plant_cut(room: String, i: int) -> Dictionary:
	var kind := plant_cut_kind(room, i)
	var pt := pot(room, i)
	if kind == "":
		return {}
	var pl: Dictionary = pt.pl
	if kind == "trim":
		pl.trim = true
		G.add_minutes(4.0)
		return {"kind": kind}
	var f := plant_forecast(room, i)
	var g := float(f.g)
	if kind == "early":
		# niedojrzała roślina: po kwitnieniu trochę słabego suszu, wcześniej nic
		var prog := float(pl.prog)
		g = floorf(g * prog * prog * 0.5) if prog >= 0.6 else 0.0
	pt.pl = null
	G.add_minutes(4.0)
	if g > 0.0:
		var pur := int(f.pur) if kind == "harvest" else G.qpure(maxf(20.0, float(f.pur) - 15.0))
		_wet_add(room, "dym", g, pur)
		return {"kind": kind, "g": g, "pur": pur}
	return {"kind": kind, "g": 0.0, "pur": 0}


## świeży zbiór o tej samej czystości trafia na jedną kupkę
static func _wet_add(room: String, p: String, g: float, pur: int) -> void:
	var h := hide(room)
	for w in h.wet:
		if String(w.p) == p and int(w.pur) == pur:
			w.g = float(w.g) + g
			return
	h.wet.append({"p": p, "g": g, "pur": pur})


## opis krzaka do karty „Sprawdź”
static func plant_info(room: String, i: int) -> Dictionary:
	var pt := pot(room, i)
	if pt.is_empty() or pt.pl == null:
		return {}
	var pl: Dictionary = pt.pl
	var f := plant_forecast(room, i)
	var lm := light_at(room, float(pt.x), float(pt.z))
	var notes: Array = []
	if float(pl.water) <= 0.0:
		notes.append(["Sucha ziemia — nie rośnie i marnieje!", "bad"])
	elif float(pl.water) < 25.0:
		notes.append(["Ziemia przesycha — podlej.", "warn"])
	if lm < 0:
		notes.append(["Bez lampy rośnie 2,5 raza wolniej i wyjdzie słabsza.", "warn"])
	elif lm == 1:
		notes.append(["Lampa 24/0: szybciej, ale słabszy towar i więcej wody.", "dim"])
	if pl.fert:
		notes.append(["Nawieziona: plon +25%.", "good"])
	elif float(pl.prog) < 0.6:
		notes.append(["Można jeszcze nawieźć (plon +25%).", "dim"])
	if pl.trim:
		notes.append(["Przycięta: lepsza jakość.", "good"])
	elif float(pl.prog) >= 0.2 and float(pl.prog) < 0.6:
		notes.append(["Teraz najlepszy moment na przycięcie liści (jakość +8).", "good"])
	if float(pl.prog) >= 1.0:
		notes.append(["Gotowa do ścięcia." if float(pl.ripe_t) <= 18.0 * 60.0 else "Przejrzewa — tnij, bo traci jakość!", "good" if float(pl.ripe_t) <= 18.0 * 60.0 else "bad"])
	return {"stage": plant_stage(pl), "prog": float(pl.prog), "water": float(pl.water), "health": float(pl.health), "g": float(f.g), "pur": int(f.pur),
		"left": plant_minutes_left(room, i), "lit": lm, "notes": notes, "fert": bool(pl.fert), "trim": bool(pl.trim)}


## krótki napis przy celowniku
static func pot_label(room: String, i: int) -> String:
	var pl = plant_of(room, i)
	if pl == null:
		return "Pusta doniczka"
	var thirsty := float(pl.water) < 25.0
	return "Konopie — %s%s" % [plant_stage(pl).to_lower(), " • SUCHO!" if thirsty else ""]


static func plants_tick(room: String, minutes: float, tank: bool) -> void:
	var h := hide(room)
	var r: Dictionary = D.RECIPES.konopie
	var ripe_now := 0
	var dry_now := 0
	for pt in h.pots:
		if pt.pl == null:
			continue
		var pl: Dictionary = pt.pl
		if float(pl.prog) >= 1.0:
			pl.ripe_t = float(pl.ripe_t) + minutes
			if float(pl.ripe_t) > 18.0 * 60.0:
				pl.health = maxf(20.0, float(pl.health) - minutes * 2.0 / 60.0)
			continue
		var lm := light_at(room, float(pt.x), float(pt.z))
		var md := lamp_mode(lm) if lm >= 0 else {"speed": float(D.POT_UNLIT_SPEED), "water": 0.7}
		var had_water := float(pl.water) > 0.0
		if tank:
			pl.water = maxf(float(pl.water), 70.0)
		else:
			pl.water = maxf(0.0, float(pl.water) - float(r.water) * float(md.get("water", 1.0)) * (1.25 if pl.fert else 1.0) * minutes / 60.0)
		if float(pl.water) <= 0.0:
			if had_water:
				dry_now += 1
			pl.health = maxf(0.0, float(pl.health) - minutes * 7.0 / 60.0)
			continue
		if float(pl.water) > 25.0:
			pl.health = minf(100.0, float(pl.health) + minutes * 1.2 / 60.0)
		pl.grow_t = float(pl.grow_t) + minutes
		if lm >= 0:
			pl.lit_t = float(pl.lit_t) + minutes
		pl.prog = minf(1.0, float(pl.prog) + minutes / (float(r.hours) * 60.0) * float(md.speed))
		if float(pl.prog) >= 1.0:
			ripe_now += 1
	var nm := String(D.ROOMS[room].name)
	if ripe_now > 0:
		G.notify("%s: %s do ścięcia." % [nm, "krzak dojrzał" if ripe_now == 1 else "%d krzaki dojrzały" % ripe_now], "good")
	if dry_now > 0:
		G.notify("%s: %s — podlej!" % [nm, "krzak ma sucho" if dry_now == 1 else "%d krzaki mają sucho" % dry_now], "warn")


## przełącznik cyklu światła na lampie (18/6 ↔ 24/0)
static func lamp_toggle(room: String, idx: int) -> int:
	var items: Array = G.S.hide[room].items
	if idx < 0 or idx >= items.size():
		return 0
	var it: Dictionary = items[idx]
	it["mode"] = (int(it.get("mode", 0)) + 1) % int(D.RECIPES.konopie.modes.size())
	return int(it.mode)


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
	# krzaki w doniczkach: pachną tym mocniej, im bliżej kwitnienia; prąd żrą lampy, pod którymi coś rośnie
	var rk: Dictionary = D.RECIPES.konopie
	var lit_by := {}
	for pt in h.pots:
		if pt.pl == null:
			continue
		active += 1
		var prog := float(pt.pl.prog)
		var bloom := 1.0 if prog >= 0.6 else (0.45 if prog >= 0.2 else 0.15)
		var lm := light_at(room, float(pt.x), float(pt.z))
		smell += float(rk.smell) * bloom * (float(lamp_mode(lm).smell) if lm >= 0 else 1.0)
		if lm >= 0:
			power += float(rk.power) * 0.5 * float(lamp_mode(lm).power)
			lit_by[lm] = true
	for it in lamps(room):
		if lit_by.has(int(it.get("mode", 0))):
			power += 4.0 * float(lamp_mode(int(it.get("mode", 0))).power)
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
				G._credit_add(round((bill - paid) * 1.5))
			G.notify("Prąd w kryjówce (%s): −%s" % [String(D.ROOMS[room].name), G.money(bill)])
		if h.has("raid_at"):
			continue
		# po wpadce z dużą gotówką policja sprawdza kryjówki niezależnie od zapachu i prądu
		if randf() < maxf(raid_chance(float(st.risk)), D.WATCH_RAID if G.watched() else 0.0):
			h["raid_at"] = G.S.t + randf_range(7.0, 15.0) * 60.0
			h["raid_warned"] = false
	if G.watched() and not G.S.flags.has("flat_raid_at") and randf() < D.WATCH_RAID:
		G.S.flags["flat_raid_at"] = G.S.t + randf_range(7.0, 15.0) * 60.0
		G.S.flags["flat_raid_warned"] = false


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


## przeszukanie mieszkania (tylko gdy policja węszy po wpadce z dużą gotówką): przepada zawartość skrytki w szafie
static func flat_raid_tick() -> void:
	if not G.S.flags.has("flat_raid_at"):
		return
	var at := float(G.S.flags.flat_raid_at)
	if not G.S.flags.get("flat_raid_warned", false) and G.S.t >= at - 180.0:
		G.S.flags["flat_raid_warned"] = true
		G.chat("stas", "Kuba, pod Twoim blokiem stoi nieoznakowany. Jak masz coś w szafie — masz ze trzy godziny, żeby to wynieść.")
	if G.S.t >= at:
		G.S.flags.erase("flat_raid_at")
		G.S.flags.erase("flat_raid_warned")
		flat_raid()


static func flat_raid() -> Dictionary:
	var st: Dictionary = G.S.stash.safe
	var goods := G.goods_total(st)
	var its: Dictionary = G.store_items(st)
	var bad_items := 0
	for id in its:
		if D.ITEMS.has(id) and D.ITEMS[id].get("illegal", false):
			bad_items += int(its[id])
	var cash := float(st.get("cash", 0.0))
	var res := {"room": "safe", "found": false, "lost_g": 0.0, "lost_cash": 0.0}
	if goods < 1.0 and bad_items == 0 and cash < G.big_cash() * 0.5:
		G.add_invest(-8.0)
		G.S.flags.erase("watch_until")
		G.chat("stas", "Przetrzepali Ci mieszkanie i wyszli z niczym. Chyba dadzą Ci spokój.")
		G.notify("Przeszukanie mieszkania — nic nie znaleźli.", "good")
		return res
	res.found = true
	res.lost_g = goods
	res.lost_cash = cash
	var fresh := G.new_store()
	var keep := {}
	for id in its:
		if not (D.ITEMS.has(id) and D.ITEMS[id].get("illegal", false)):
			keep[id] = its[id]
	fresh["items"] = keep
	G.S.stash["safe"] = fresh
	G.add_heat(20.0, false)
	G.add_invest(18.0)
	G.S.stats["raids"] = int(G.S.stats.get("raids", 0)) + 1
	G.chat("stas", "Weszli do Ciebie z nakazem. Szafa pusta — towar i gotówka pojechały na komendę.")
	G.notify("PRZESZUKANIE mieszkania! Straciłeś %s towaru i %s." % [G.grams(res.lost_g), G.money(res.lost_cash)], "bad")
	if G.player != null and G.player.loc == "safe" and G.main != null:
		G.main.raided_inside()
	return res


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
	for pt in h.pots:
		pt.pl = null
	G.add_heat(25.0, false)
	G.add_invest(20.0)
	G.S.stats["raids"] = int(G.S.stats.get("raids", 0)) + 1
	G.chat("stas", "Wyłamali drzwi i wynieśli wszystko: rośliny, towar, kasę. Sprzęt zostawili. Nie pokazuj się tam przez parę dni.")
	G.notify("NALOT na: %s! Straciłeś %s towaru i %s." % [String(D.ROOMS[room].name), G.grams(res.lost_g), G.money(res.lost_cash)], "bad")
	# złapany na miejscu
	if G.player != null and G.player.loc == room and G.main != null:
		G.main.raided_inside()
	return res
