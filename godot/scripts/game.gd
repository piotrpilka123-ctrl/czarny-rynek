extends Node
## Rdzeń rozgrywki: stan, czas, towar (hurt → skrytka → porcjowanie → sprzedaż),
## klienci i negocjacje, policja, dług, rozwój postaci, kryjówki, fabuła, zapis.

signal toast(text, kind)
signal nav_dirty
signal sms(contact, text)
signal level_up(lvl)

const SAVE_PATH := "user://zapis_v3.json"

var S := {}                 # cały stan gry (zapisywany do JSON)
var running := false
var busy := false           # przejścia (drzwi, sen, areszt)
var arresting := false
var now := 0.0              # sekundy rozgrywki
var night := 0.0            # 0..1, ustawia env.gd
var rain := 0.0
var zone_name := ""
var zone_id := ""
var wanted_grace := 0.0
var mods := {}
var test_mode := false      # zrzuty ekranu i testy: bez przechwytywania myszy, bez zapisu
var test_hide_hud := false

var main = null
var player = null
var world = null
var npcs = null
var ui = null
var env = null
var story: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	S = new_state()
	_build_story()


# ================================================================ stan
static func new_store() -> Dictionary:
	var st := {"bulk": {}, "pack": {}, "cash": 0.0}
	for p in D.PRODUCTS:
		st.bulk[p] = {}
		st.pack[p] = {}
	return st


func new_state() -> Dictionary:
	var cust := {}
	for c in D.CLIENTS:
		cust[c.id] = {"unlocked": false, "loy": 0.0, "sat": 60.0, "hunger": 0.35, "deals": 0, "grams": 0, "next": 0.0, "owes": 0.0, "known": {}, "declines": 0, "lost_until": 0.0}
	return {
		"v": 3, "t": 9.0 * 60.0, "cash": float(D.START_CASH), "debt": float(D.START_DEBT), "paid": 0.0,
		"xp": 0.0, "lvl": 1, "sp": 0, "skills": {},
		"heat": 0.0, "invest": 0.0, "strikes": 0, "arrests": 0, "step": 0, "flags": {},
		"inv": new_store(), "stash": {"safe": new_store(), "garage": new_store(), "basement": new_store()},
		"items": {"woreczki": 10, "majeranek": 0, "cukier": 0, "nasiona": 0, "burner": 0}, "upg": {}, "pockets": [null, null, null, null],
		"cust": cust, "orders": [], "next_order": 1, "chats": {}, "unread": {},
		"track": null, "nav_on": true, "wanted": false,
		"demand": {"dym": 1.0, "szron": 1.0, "krysztal": 1.0, "snieg": 1.0}, "cost_mult": 1.0, "zheat": {}, "weather": null,
		"credit": 0.0, "credit_due": 0.0, "drops": [], "next_drop": 1,
		"props": {}, "hide": {"garage": {"items": [], "grow": {}}, "basement": {"items": [], "grow": {}}},
		"stats": {"earned": 0.0, "sold": 0, "deals": 0, "walked": 0, "escapes": 0, "packed": 0, "wasted": 0, "pickups": 0, "spent": 0.0, "best": 0.0, "grown": 0},
		"pos": null, "mom_day": 0,
	}


func money(n) -> String:
	var v := int(round(float(n)))
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out + " zł"


func grams(g) -> String:
	var f := float(g)
	if absf(f - round(f)) < 0.05:
		return "%d g" % int(round(f))
	return "%.1f g" % f


func flag(k: String) -> bool:
	return bool(S.flags.get(k, false))


func cust_def(id: String) -> Dictionary:
	for c in D.CLIENTS:
		if c.id == id:
			return c
	return {}


func spot_def(id: String) -> Dictionary:
	for s in D.SPOTS:
		if s.id == id:
			return s
	return {}


func drop_def(id: String) -> Dictionary:
	for s in D.DROPS:
		if s.id == id:
			return s
	return {}


func notify(text: String, kind := "") -> void:
	toast.emit(text, kind)


# ================================================================ czas
func day() -> int:
	return int(floor(S.t / 1440.0)) + 1


func minute() -> float:
	return fmod(S.t, 1440.0)


func hour() -> float:
	return minute() / 60.0


func clock(t = null) -> String:
	var m := int(fmod(S.t if t == null else float(t), 1440.0))
	return "%02d:%02d" % [int(m / 60.0), m % 60]


func is_night() -> bool:
	var h := hour()
	return h >= 22.0 or h < 5.0


func add_minutes(m: float) -> void:
	if m > 5.0 and main != null and main.args.has("trailer"):
		print("ADDMIN ", m, " t=", S.t)
		print_stack()
	var left := m
	while left > 0.0:
		var st: float = minf(left, 10.0)
		left -= st
		var prev: float = S.t
		S.t += st
		if int(prev / 10.0) != int(S.t / 10.0):
			on_tick()
		if int(prev / 60.0) != int(S.t / 60.0):
			on_hour()
		if int(prev / 1440.0) != int(S.t / 1440.0):
			on_day()


# ================================================================ towar i ekwipunek
static func qpur(pur) -> int:
	return clampi(int(round(float(pur) / 5.0)) * 5, 5, 100)


static func tier(pur) -> int:
	var p := float(pur)
	var t := 0
	for i in range(4):
		if p >= float(D.TIER_MIN[i]):
			t = i
	return t


static func tier_name(pur) -> String:
	return D.TIER_NAMES[tier(pur)]


## wpływ czystości na cenę
static func price_factor(pur) -> float:
	return 0.7 + (clampf(float(pur), 30.0, 100.0) - 40.0) * 0.008


## sam towar (gramy): luzem + porcje
func goods_total(st: Dictionary) -> float:
	var n := 0.0
	for p in st.bulk:
		for k in st.bulk[p]:
			n += float(st.bulk[p][k])
	for p in st.pack:
		for k in st.pack[p]:
			n += float(st.pack[p][k])
	return n


## drobne przedmioty danego schowka (plecak gracza trzyma je w S.items)
func store_items(st: Dictionary) -> Dictionary:
	if is_same(st, S.inv):
		return S.items
	if not st.has("items"):
		st["items"] = {}
	return st.items


## zajęte miejsce: towar + przedmioty według rozmiaru
func store_total(st: Dictionary) -> float:
	var n := 0.0
	for p in st.bulk:
		for k in st.bulk[p]:
			n += float(st.bulk[p][k]) * D.SIZE_BULK
	for p in st.pack:
		for k in st.pack[p]:
			n += float(st.pack[p][k]) * D.SIZE_PACK
	var its := store_items(st)
	for id in its:
		if D.ITEMS.has(id):
			n += float(its[id]) * float(D.ITEMS[id].size)
	return n


## waga schowka w gramach
func store_weight(st: Dictionary) -> float:
	var w := 0.0
	for p in st.bulk:
		for k in st.bulk[p]:
			w += float(st.bulk[p][k]) * D.W_BULK
	for p in st.pack:
		for k in st.pack[p]:
			w += float(st.pack[p][k]) * D.W_PACK
	var its := store_items(st)
	for id in its:
		if D.ITEMS.has(id):
			w += float(its[id]) * float(D.ITEMS[id].w)
	return w


func carry_total() -> float:
	return store_total(S.inv)


func carry_goods() -> float:
	return goods_total(S.inv)


func units(v) -> String:
	var f := float(v)
	if absf(f - round(f)) < 0.05:
		return str(int(round(f)))
	return ("%.1f" % f).replace(".", ",")


func weight_text(g: float) -> String:
	if g >= 1000.0:
		return ("%.2f kg" % (g / 1000.0)).replace(".", ",")
	return "%d g" % int(round(g))


func bag_name() -> String:
	if upg("plecak2"):
		return "Plecak turystyczny"
	if upg("plecak1"):
		return "Plecak szkolny"
	return "Kieszenie"


## lista pozycji schowka do ekranu ekwipunku
func entries(st: Dictionary) -> Array:
	var out := []
	for kind in ["pack", "bulk"]:
		for s in stacks(st, kind):
			var pd: Dictionary = D.PRODUCTS[s.p]
			var us: float = D.SIZE_PACK if kind == "pack" else D.SIZE_BULK
			var uw: float = D.W_PACK if kind == "pack" else D.W_BULK
			out.append({"kind": kind, "p": s.p, "pur": int(s.pur), "id": "", "n": float(s.n), "name": pd.name,
				"sub": ("porcje 1 g" if kind == "pack" else "luzem"), "icon": D.PRODUCT_ICONS.get(s.p, "leaf"), "tier": tier(s.pur),
				"qty": ("%d szt." % int(s.n)) if kind == "pack" else grams(s.n), "usize": us, "size": float(s.n) * us, "weight": float(s.n) * uw,
				"desc": ("Zaporcjowany towar gotowy do sprzedaży." if kind == "pack" else "Towar luzem. Zanim sprzedasz, zaporcjuj go na stole z wagą.")})
	var its := store_items(st)
	for id in D.ITEMS:
		var n := int(its.get(id, 0))
		if n <= 0:
			continue
		var d: Dictionary = D.ITEMS[id]
		out.append({"kind": "item", "p": "", "pur": 0, "id": id, "n": float(n), "name": d.name, "sub": "", "icon": d.icon, "tier": -1,
			"qty": "%d %s" % [n, d.unit], "usize": float(d.size), "size": n * float(d.size), "weight": n * float(d.w), "desc": d.desc})
	return out


## przenosi pozycję między plecakiem a skrytką; zwraca przeniesioną ilość
func move_entry(room: String, e: Dictionary, to_stash: bool, amount: float) -> float:
	if e.kind != "item":
		return move_stack(room, to_stash, e.kind, e.p, int(e.pur), amount)
	var from: Dictionary = store_items(S.inv if to_stash else S.stash[room])
	var to: Dictionary = store_items(S.stash[room] if to_stash else S.inv)
	var id: String = e.id
	var usz := float(D.ITEMS[id].size)
	var space: float = (float(stash_cap(room)) - store_total(S.stash[room])) if to_stash else (float(capacity()) - carry_total())
	var n: int = mini(mini(int(amount), int(from.get(id, 0))), int(floor(maxf(0.0, space) / usz + 0.001)))
	if n <= 0:
		notify("Brak miejsca w %s." % ("skrytce" if to_stash else "plecaku"), "warn")
		return 0.0
	from[id] = int(from.get(id, 0)) - n
	to[id] = int(to.get(id, 0)) + n
	return float(n)


## wyrzuca pozycję z plecaka (bezpowrotnie)
func discard_entry(e: Dictionary, amount: float) -> void:
	if e.kind == "pack":
		take_pack(S.inv, e.p, int(e.pur), int(amount))
	elif e.kind == "bulk":
		take_bulk(S.inv, e.p, int(e.pur), amount)
	else:
		S.items[e.id] = maxi(0, item(e.id) - int(amount))
	notify("Wyrzucono: %s." % e.name, "warn")


## paniczne pozbycie się całego towaru (podczas pościgu)
func ditch_goods() -> bool:
	var g := carry_goods()
	if g < 0.01:
		return false
	S.inv.bulk = new_store().bulk
	S.inv.pack = new_store().pack
	S.stats["ditched"] = float(S.stats.get("ditched", 0.0)) + g
	notify("Wyrzuciłeś %s towaru w krzaki. Przepadło — ale przy kontroli jesteś czysty." % grams(g), "warn")
	return true


## przedmiot dostępny przy stole: plecak + skrytka w tym pomieszczeniu
func item_at(room: String, id: String) -> int:
	var n := item(id)
	if room != "" and S.stash.has(room):
		n += int(store_items(S.stash[room]).get(id, 0))
	return n


func take_item(room: String, id: String, n: int) -> void:
	var a: int = mini(n, item(id))
	S.items[id] = item(id) - a
	if n - a > 0 and room != "" and S.stash.has(room):
		var its := store_items(S.stash[room])
		its[id] = maxi(0, int(its.get(id, 0)) - (n - a))


func packed_total(st: Dictionary, product := "") -> int:
	var n := 0
	for p in st.pack:
		if product != "" and p != product:
			continue
		for k in st.pack[p]:
			n += int(st.pack[p][k])
	return n


func carry_value() -> float:
	var v := 0.0
	for p in S.inv.pack:
		for k in S.inv.pack[p]:
			v += float(S.inv.pack[p][k]) * float(D.PRODUCTS[p].base) * price_factor(int(k))
	for p in S.inv.bulk:
		for k in S.inv.bulk[p]:
			v += float(S.inv.bulk[p][k]) * float(D.PRODUCTS[p].base) * price_factor(int(k)) * 0.8
	return v


func capacity() -> int:
	if upg("plecak2"):
		return 90
	if upg("plecak1"):
		return 40
	return D.CAP_BASE


func upg(id: String) -> bool:
	return bool(S.upg.get(id, false))


func stash_cap(room: String) -> int:
	if room == "safe":
		return 150 if upg("szafka") else D.STASH_BASE
	var cap := 0
	for it in S.hide.get(room, {}).get("items", []):
		for f in D.FURNITURE:
			if f.id == it.f and f["func"] == "stash":
				cap += int(f.cap)
	return cap


## lista stosów: [{p, pur, n}] posortowana od najlepszej czystości
func stacks(st: Dictionary, kind: String) -> Array:
	var out := []
	for p in st[kind]:
		for k in st[kind][p]:
			var n := float(st[kind][p][k])
			if n > 0.001:
				out.append({"p": p, "pur": int(k), "n": n})
	out.sort_custom(func(a, b): return (String(a.p) + "%03d" % (100 - int(a.pur))) < (String(b.p) + "%03d" % (100 - int(b.pur))))
	return out


func add_bulk(st: Dictionary, p: String, pur, g: float) -> void:
	if g <= 0.0:
		return
	var k := str(qpur(pur))
	st.bulk[p][k] = float(st.bulk[p].get(k, 0.0)) + g


func take_bulk(st: Dictionary, p: String, pur, g: float) -> float:
	var k := str(qpur(pur))
	var have := float(st.bulk[p].get(k, 0.0))
	var n: float = minf(have, g)
	if n <= 0.0:
		return 0.0
	st.bulk[p][k] = have - n
	if float(st.bulk[p][k]) < 0.001:
		st.bulk[p].erase(k)
	return n


func add_pack(st: Dictionary, p: String, pur, n: int) -> void:
	if n <= 0:
		return
	var k := str(qpur(pur))
	st.pack[p][k] = int(st.pack[p].get(k, 0)) + n


func take_pack(st: Dictionary, p: String, pur, n: int) -> int:
	var k := str(qpur(pur))
	var have := int(st.pack[p].get(k, 0))
	var t: int = mini(have, n)
	if t <= 0:
		return 0
	st.pack[p][k] = have - t
	if int(st.pack[p][k]) <= 0:
		st.pack[p].erase(k)
	return t


func item(id: String) -> int:
	return int(S.items.get(id, 0))


# ================================================================ rozwój
func next_xp() -> float:
	return float(D.XP_LEVELS[mini(int(S.lvl), D.XP_LEVELS.size() - 1)])


func prev_xp() -> float:
	return float(D.XP_LEVELS[mini(int(S.lvl) - 1, D.XP_LEVELS.size() - 1)])


func level_title() -> String:
	return D.LEVEL_TITLES[mini(int(S.lvl) - 1, D.LEVEL_TITLES.size() - 1)]


func add_xp(n: float) -> void:
	S.xp = float(S.xp) + n
	while int(S.lvl) < D.XP_LEVELS.size() and float(S.xp) >= float(D.XP_LEVELS[int(S.lvl)]):
		S.lvl = int(S.lvl) + 1
		S.sp = int(S.sp) + 1
		notify("POZIOM %d — %s! +1 punkt umiejętności." % [int(S.lvl), level_title()], "level")
		if D.LEVEL_UNLOCKS.has(int(S.lvl)):
			notify("Odblokowano: " + String(D.LEVEL_UNLOCKS[int(S.lvl)]), "good")
		Sfx.play("level")
		level_up.emit(int(S.lvl))
		check_unlocks()
		nav_dirty.emit()


func has_skill(id: String) -> bool:
	return bool(S.skills.get(id, false))


func skill_def(id: String) -> Dictionary:
	for s in D.SKILLS:
		if s.id == id:
			return s
	return {}


func can_learn(id: String) -> bool:
	var s := skill_def(id)
	if s.is_empty() or has_skill(id) or int(S.sp) <= 0:
		return false
	if s.has("req") and not has_skill(s.req):
		return false
	return int(S.lvl) >= int(s.get("lvl", 1))


func learn_skill(id: String) -> bool:
	if not can_learn(id):
		return false
	S.skills[id] = true
	S.sp = int(S.sp) - 1
	Sfx.play("good")
	notify("Nowa umiejętność: " + String(skill_def(id).name), "good")
	return true


# ================================================================ wiadomości (czaty)
func contact_name(cid: String) -> String:
	match cid:
		"wiktor": return "Wiktor"
		"stas": return "Wujek Staś"
		"mama": return "Mama"
		"info": return "POLTEL"
	var d := cust_def(cid)
	return String(d.name) if not d.is_empty() else cid


func chat(cid: String, text: String, me := false, quiet := false) -> void:
	if not S.chats.has(cid):
		S.chats[cid] = []
	S.chats[cid].append({"me": me, "text": text, "day": day(), "time": clock(), "t": S.t})
	if S.chats[cid].size() > 40:
		S.chats[cid].pop_front()
	if not me:
		S.unread[cid] = int(S.unread.get(cid, 0)) + 1
		if not quiet:
			sms.emit(cid, text)
			Sfx.play("sms")


func mark_read(cid: String) -> void:
	S.unread[cid] = 0
	if cid == "wiktor":
		S.flags["read_wiktor"] = true


func unread_total() -> int:
	var n := 0
	for k in S.unread:
		n += int(S.unread[k])
	return n


# ================================================================ uwaga policji
func zone_at(x: float, z: float) -> Dictionary:
	for zn in D.ZONES:
		if x >= float(zn.x0) and x <= float(zn.x1) and z >= float(zn.z0) and z <= float(zn.z1):
			return zn
	return {}


func zone_heat_at(x: float, z: float) -> float:
	var zn := zone_at(x, z)
	return float(S.zheat.get(zn.id, 0.0)) if not zn.is_empty() else 0.0


func add_heat(n: float, local := true) -> void:
	S.heat = clampf(S.heat + n, 0.0, 100.0)
	if local and player != null and player.loc == "out":
		var zn := zone_at(player.global_position.x, player.global_position.z)
		if not zn.is_empty():
			S.zheat[zn.id] = clampf(float(S.zheat.get(zn.id, 0.0)) + n * 1.6, 0.0, 100.0)


func add_invest(n: float) -> void:
	S.invest = clampf(S.invest + n, 0.0, 100.0)


func eff_heat() -> float:
	if player == null:
		return S.heat
	return clampf(S.heat + zone_heat_at(player.global_position.x, player.global_position.z) * 0.6, 0.0, 100.0)


## mnożnik narastania podejrzeń u policjantów, którzy widzą gracza
func compute_susp() -> float:
	var carry := carry_goods() > 0.01
	var eh := eff_heat()
	var m := 0.0
	if S.wanted:
		return 3.0
	if carry and eh >= 45.0: m = 0.9
	if carry and player.sprinting: m = maxf(m, 0.5)
	if eh >= 80.0: m = maxf(m, 1.2)
	if S.invest >= 85.0: m = maxf(m, 0.7)
	if carry and S.invest >= 60.0: m = maxf(m, 0.3)
	if carry and night > 0.6:
		m = maxf(m, (0.28 + eh / 220.0) * (0.65 if has_skill("duch") else 1.0))
	if has_skill("cichy"):
		m *= 0.8
	return m


func on_chase_start() -> void:
	if not S.wanted:
		S.wanted = true
		notify("Policja Cię ściga! Uciekaj albo schowaj się w budynku!", "bad")
		Sfx.play("alert")
		Sfx.siren(true)
	add_heat(12.0)
	if S.heat < 45.0:
		S.heat = 45.0
	wanted_grace = 0.0


func bribe_chance(a: float) -> float:
	return clampf(0.08 + a / 5500.0 - S.invest / 400.0 - (0.1 if carry_value() > 3000.0 else 0.0) + (0.15 if has_skill("uklad") else 0.0), 0.04, 0.9)


func arrest(_cop) -> void:
	if arresting or busy:
		return
	arresting = true
	var carry := carry_goods()
	if carry < 0.01 and S.invest < 85.0:
		ui.dialog({"name": "Policjant", "lines": ["Stój! Policja! Ręce na widoku!", "…Nic przy tobie nie ma. Tym razem cię puszczam, ale mam cię na oku."],
			"on_end": _release_clean})
		return
	var choices := [{"label": "Poddaję się.", "act": func(): surrender()}]
	for a in [600, 1800, 4500]:
		var amt: int = a
		choices.append({"label": "Zaproponuj „prezent” za %s (szansa ok. %d%%)" % [money(amt), int(round(bribe_chance(amt) * 100.0))],
			"disabled": S.cash < amt, "kind": "warn", "act": func(): bribe(amt)})
	ui.dialog({"name": "Policjant", "lines": ["Stój! Policja! Ręce na widoku!", "Kontrola osobista. Co tam masz w plecaku? (%s towaru)" % grams(carry)], "choices": choices})


func bribe(a: int) -> void:
	S.cash -= a
	if randf() < bribe_chance(a):
		ui.dialog({"name": "Policjant", "lines": ["*rozgląda się, chowa banknoty do kieszeni*", "Nic nie widziałem. Zjeżdżaj."], "on_end": _bribe_ok})
	else:
		ui.dialog({"name": "Policjant", "lines": ["Próba przekupstwa funkcjonariusza? Zakuć go!"], "on_end": _bribe_fail})


func _release_clean() -> void:
	npcs.end_chase()
	S.wanted = false
	Sfx.siren(false)
	add_heat(-10.0)
	add_invest(3.0)
	arresting = false


func _bribe_ok() -> void:
	npcs.end_chase()
	S.wanted = false
	Sfx.siren(false)
	add_heat(-20.0)
	arresting = false


func _bribe_fail() -> void:
	add_invest(8.0)
	surrender()


func surrender() -> void:
	busy = true
	await ui.fade(true)
	var fine: float = minf(S.cash, round(S.cash * 0.35 + 200.0))
	S.cash -= fine
	var lost := carry_goods()
	S.inv.bulk = new_store().bulk
	S.inv.pack = new_store().pack
	S.arrests = int(S.arrests) + 1
	S.heat = 25.0
	S.wanted = false
	Sfx.siren(false)
	npcs.end_chase()
	add_invest(10.0)
	add_minutes(360.0)
	main.teleport("out", Vector3(-181.0 * D.SC, 0.0, 12.6 * D.SC), PI)
	notify("Zatrzymany (%d/%d)! Konfiskata: %s, grzywna %s." % [int(S.arrests), D.MAX_ARRESTS, grams(lost), money(fine)], "bad")
	await get_tree().create_timer(0.7).timeout
	await ui.fade(false)
	busy = false
	arresting = false
	if int(S.arrests) >= D.MAX_ARRESTS:
		main.ending("wyrok")


# ================================================================ zdarzenia czasowe
## co 10 minut gry: terminy zamówień i paczki w skrytkach
func on_tick() -> void:
	for o in S.orders.duplicate():
		var st: Dictionary = S.cust[o.cust]
		if o.status == "new" and S.t > float(o.respond_by):
			drop_order(o)
			st.sat = maxf(0.0, float(st.sat) - 2.0)
			chat(o.cust, "Nie odpisujesz, to szukam gdzie indziej.", false, true)
		elif S.t > float(o.deadline):
			drop_order(o)
			if o.status == "accepted":
				st.sat = maxf(0.0, float(st.sat) - 14.0)
				st.loy = maxf(0.0, float(st.loy) - 6.0)
				chat(o.cust, "Czekałem godzinę, a ciebie nie było. Słabo.")
	# paczki w skrytkach
	for d in S.drops.duplicate():
		if d.state == "wait" and S.t >= float(d.ready):
			d.state = "ready"
			chat("wiktor", "Paczka czeka: %s. Masz 16 godzin, potem znika." % drop_def(d.spot).name)
			if S.track == null:
				S.track = "drop"
			nav_dirty.emit()
		elif d.state == "ready" and S.t > float(d.expire):
			S.drops.erase(d)
			chat("wiktor", "Paczka przepadła. Następnym razem rusz się szybciej — za straty i tak płacisz.")
			S.credit = float(S.credit) + float(d.cost) * 0.5
			if float(S.credit_due) < S.t:
				S.credit_due = S.t + D.CREDIT_DAYS * 1440.0
			add_invest(3.0)
			nav_dirty.emit()


func on_hour() -> void:
	var h := int(hour())
	# nowe zamówienia od stałych klientów
	if not mods.get("sleeping", false):
		var max_orders: int = clampi(1 + int(S.lvl), 2, 5)
		for c in D.CLIENTS:
			if S.orders.size() >= max_orders:
				break
			var cs: Dictionary = S.cust[c.id]
			if not cs.unlocked or _has_order(c.id) or S.t < float(cs.next):
				continue
			var club: bool = c.prod != "dym"
			var ok_hour: bool = (h >= 17 or h < 3) if club else (h >= 8 and h <= 23)
			if not ok_hour or int(S.lvl) < int(D.PRODUCTS[c.prod].lvl):
				continue
			make_order(c)
	for id in S.cust:
		var cs2: Dictionary = S.cust[id]
		if cs2.unlocked:
			cs2.hunger = clampf(float(cs2.hunger) + 0.035, 0.0, 1.0)
	if h == 8:
		daily_costs()
	if not mods.get("sleeping", false) and h >= 10 and h <= 20 and int(S.mom_day) != day() and randf() < 0.1 and day() > 1:
		S.mom_day = day()
		chat("mama", D.MOM.pick_random())


func _has_order(cid: String) -> bool:
	for o in S.orders:
		if o.cust == cid:
			return true
	return false


func on_day() -> void:
	var d := day()
	for p in S.demand:
		S.demand[p] = snappedf(randf_range(0.88, 1.2), 0.01)
	S.cost_mult = snappedf(randf_range(0.92, 1.12), 0.01)
	if flag("hurt_on"):
		var prices := []
		for p in D.PRODUCTS:
			if int(S.lvl) >= int(D.PRODUCTS[p].lvl):
				prices.append("%s %d zł/g" % [D.PRODUCTS[p].name, int(round(wholesale_unit(p, false)))])
		chat("wiktor", "Cennik na dziś: %s." % ", ".join(prices), false, true)
	if d > 1 and d % 2 == 0:
		notify("Wskazówka: " + String(D.HINTS.pick_random()))
	S.weather = null
	if randf() < 0.34:
		var st: float = S.t + randf_range(2.0, 14.0) * 60.0
		S.weather = {"start": st, "end": st + randf_range(2.0, 7.0) * 60.0, "power": randf_range(0.5, 1.0)}
	# odsetki i raty
	if S.debt > 0.0 and d > 1 and (d - 1) % 7 == 0:
		var add: float = round(S.debt * D.DEBT_INTEREST)
		S.debt += add
		chat("wiktor", "Tygodniowe odsetki od długu: %s. Zostało %s." % [money(add), money(S.debt)], false, true)
	for r in D.DEBT_SCHEDULE:
		if S.debt <= 0.0:
			break
		if d == int(r.day):
			notify("Dziś mija termin raty: łącznie %s spłaconych (masz %s)." % [money(r.due), money(S.paid)], "warn")
		if d == int(r.day) + 1:
			if S.paid >= float(r.due):
				chat("wiktor", "Rata zaliczona. Tak trzymaj.")
			else:
				missed_payment(float(r.due) - S.paid, "Rata nie wpłynęła.")
	# zeszyt u Wiktora
	if float(S.credit) > 0.0 and S.t > float(S.credit_due):
		var over := int((S.t - float(S.credit_due)) / 1440.0)
		var pen: float = round(float(S.credit) * 0.1)
		S.credit = float(S.credit) + pen
		if over >= 2:
			missed_payment(float(S.credit), "Zeszyt nie został spłacony.")
			S.credit_due = S.t + 2.0 * 1440.0
		else:
			chat("wiktor", "Zeszyt po terminie. Doliczam %s. Spłać, zanim przyjadę osobiście." % money(pen))
	for id in S.cust:
		var cs: Dictionary = S.cust[id]
		cs.sat = clampf(float(cs.sat) + (1.2 if float(cs.sat) < 60.0 else -0.4), 0.0, 100.0)
	for k in S.zheat:
		S.zheat[k] = maxf(0.0, float(S.zheat[k]) - 14.0)
	add_invest(-4.0 if S.heat < 25.0 else -1.0)
	S.heat = maxf(0.0, S.heat - 6.0)
	check_unlocks()
	save_game(false)


func missed_payment(short: float, why: String) -> void:
	S.strikes = int(S.strikes) + 1
	var penalty: float = round(short * 0.15)
	S.debt += penalty
	var l1: float = round(S.cash * 0.4)
	var l2: float = round(float(S.stash.safe.cash) * 0.2)
	S.cash -= l1
	S.stash.safe.cash = float(S.stash.safe.cash) - l2
	chat("wiktor", "%s Doliczam %s kary. Moi ludzie właśnie byli u ciebie. (%d/%d)" % [why, money(penalty), int(S.strikes), D.MAX_STRIKES])
	if ui != null:
		ui.hurt()
	notify("Ludzie Wiktora zabrali %s!" % money(l1 + l2), "bad")
	if int(S.strikes) >= D.MAX_STRIKES and main != null:
		get_tree().create_timer(1.0).timeout.connect(func(): main.ending("dlug"))


func daily_costs() -> void:
	var left := float(D.LIVING_COST)
	var c: float = minf(S.cash, left)
	S.cash -= c
	left -= c
	c = minf(float(S.stash.safe.cash), left)
	S.stash.safe.cash = float(S.stash.safe.cash) - c
	left -= c
	if left > 0.0:
		S.debt += round(left * 1.5)
		notify("Nie stać Cię na życie. Wiktor „pożyczył” %s — dopisane do długu." % money(round(left * 1.5)), "bad")
	else:
		notify("Koszty życia: −%s" % money(D.LIVING_COST))


# ================================================================ zamówienia (SMS)
## maksymalna cena za gram, jaką klient zapłaci
func max_price(def: Dictionary, st: Dictionary, p: String, pur, g: int, o := {}) -> float:
	var m: float = float(D.PRODUCTS[p].base) * price_factor(pur) * float(S.demand[p]) * float(def.wealth)
	m *= 1.0 + minf(100.0, float(st.get("loy", 0.0))) / 100.0 * 0.12
	m *= 0.88 + float(st.get("hunger", 0.4)) * 0.28
	if float(pur) < float(o.get("minpur", def.get("minpur", 0))):
		m *= 0.72
	m *= 1.0 - minf(0.18, (g - 1) * 0.02)
	if has_skill("twarda"):
		m *= 1.06
	if o.has("mood"):
		m *= 0.94 + float(o.mood) / 100.0 * 0.12
	return m * float(o.get("noise", 1.0)) * float(o.get("boost", 1.0))


func make_order(c: Dictionary, force_g := 0) -> Dictionary:
	var st: Dictionary = S.cust[c.id]
	var product: String = c.prod
	var g := randi_range(int(c.grams[0]), int(c.grams[1])) + (1 if float(st.loy) >= 40.0 else 0) + (1 if float(st.loy) >= 80.0 else 0)
	if force_g > 0:
		g = force_g
	var spots: Array = []
	for sid in c.spots:
		if sid != "huta" or int(S.lvl) >= 4:
			spots.append(sid)
	var spot := spot_def(spots.pick_random())
	var noise := randf_range(0.94, 1.06)
	var mx := max_price(c, st, product, maxi(int(c.minpur), 60), g, {"noise": noise})
	var stated: int = maxi(5, int(round(mx * float(c.honesty) * randf_range(0.86, 0.95))))
	# spotkanie o konkretnej godzinie: za 1,5–4 h, zaokrąglone do pół godziny
	var meet: float = ceil((S.t + randf_range(90.0, 240.0)) / 30.0) * 30.0
	var o := {
		"id": int(S.next_order), "cust": c.id, "product": product, "grams": g, "minpur": int(c.minpur), "spot": spot.id,
		"meet": meet, "deadline": meet + 60.0, "respond_by": minf(meet - 25.0, S.t + 120.0), "status": "new",
		"stated": stated, "noise": noise, "agreed": null, "counter": null, "countered": false, "resched": false, "t0": S.t, "text": "",
	}
	S.next_order = int(S.next_order) + 1
	var pn: String = D.PRODUCTS[product].name
	var at := clock(meet)
	var sn: String = spot.name
	var lines := {
		"luzak": ["Siema, ogarniesz %d g %s? Dam %d za gram. %s, o %s." % [g, pn, stated, sn, at], "Ej, masz coś? %d g po %d zł. Będę: %s, %s." % [g, stated, sn, at]],
		"twardziel": ["%d g. %d za gram. %s, %s." % [g, stated, sn, at], "Potrzebuję %d g. Daję %d. %s o %s. Nie spóźnij się." % [g, stated, sn, at]],
		"gadula": ["Dzień dobry, panie kolego! Potrzebowałbym %d g, po %d złotych. Spotkajmy się: %s, godzina %s." % [g, stated, sn, at]],
		"konkret": ["%d g %s, %d zł/g. Miejsce: %s. Godzina: %s. Potwierdź." % [g, pn, stated, sn, at]],
		"cwaniak": ["Słuchaj, biorę %d g, ale więcej niż %d za gram nie dam, bo krucho. %s, o %s." % [g, stated, sn, at]],
		"impulsywny": ["%d g! %d zł/g. %s, %s. Bądź!!" % [g, stated, sn, at]],
	}
	var opts: Array = lines.get(c.type, lines.luzak)
	o.text = opts.pick_random()
	S.orders.append(o)
	st.next = S.t + next_gap(c, st)
	chat(c.id, o.text)
	return o


func next_gap(c: Dictionary, st: Dictionary) -> float:
	var gap := randf_range(float(c.every[0]), float(c.every[1])) * 60.0
	gap *= 1.0 - minf(100.0, float(st.loy)) / 250.0
	if has_skill("siec"):
		gap *= 0.85
	return gap


func find_order(id) -> Variant:
	for o in S.orders:
		if int(o.id) == int(id):
			return o
	return null


func drop_order(o: Dictionary) -> void:
	S.orders.erase(o)
	if npcs != null:
		npcs.remove_customer(int(o.id))
	if (S.track is int or S.track is float) and int(S.track) == int(o.id):
		S.track = null
	nav_dirty.emit()


## odpowiedź na SMS: accept (zgoda na cenę klienta) | price (negocjacja) | counterok | time (zmiana godziny) | decline
func reply_order(id, kind: String, value := 0) -> void:
	var o = find_order(id)
	if o == null:
		return
	var def := cust_def(o.cust)
	var st: Dictionary = S.cust[o.cust]
	if kind == "accept":
		chat(o.cust, "Pasuje. %d zł za gram, będę o %s." % [int(o.stated), clock(o.meet)], true)
		_accept_order(o, int(o.stated), ["Ok, czekam.", "Dobra. Do zobaczenia.", "Super, będę."].pick_random())
	elif kind == "counterok":
		chat(o.cust, "Niech będzie %d zł za gram." % int(o.counter), true)
		_accept_order(o, o.counter, "Stoi, %d za gram. Czekam o %s." % [int(o.counter), clock(o.meet)])
	elif kind == "price":
		var price := value
		chat(o.cust, "%d zł za gram i jestem." % price, true)
		# przez telefon klient jest mniej skłonny do ustępstw niż twarzą w twarz
		var mx := max_price(def, st, o.product, maxi(int(o.minpur), 60), int(o.grams), {"noise": o.noise}) * 0.94
		if price <= mx:
			_accept_order(o, price, ["Ok, %d za gram. Czekam." % price, "Niech będzie %d. Do zobaczenia." % price].pick_random())
		elif price <= mx * 1.2 and not o.countered:
			o.counter = maxi(int(o.stated), int(round(mx * randf_range(0.93, 0.99))))
			o.countered = true
			chat(o.cust, "%d? Za drogo. Mogę dać %d za gram, nie więcej." % [price, int(o.counter)])
		else:
			drop_order(o)
			st.sat = maxf(0.0, float(st.sat) - 6.0)
			chat(o.cust, ["Chyba żartujesz. Szukam gdzie indziej.", "Za takie pieniądze? Nie, dzięki."].pick_random())
	elif kind == "time":
		var meet := float(value)
		chat(o.cust, "Możemy o %s zamiast o %s?" % [clock(meet), clock(o.meet)], true)
		var odds := {"impulsywny": 0.35, "konkret": 0.55, "twardziel": 0.6, "cwaniak": 0.7}
		var p: float = odds.get(def.type, 0.85)
		if o.resched:
			p *= 0.4
		o.resched = true
		if randf() < p:
			o.meet = meet
			o.deadline = meet + 60.0
			o.respond_by = maxf(float(o.respond_by), minf(meet - 25.0, S.t + 120.0))
			chat(o.cust, ["Ok, %s." % clock(meet), "Dobra, niech będzie %s." % clock(meet)].pick_random())
			if npcs != null:
				npcs.reschedule(int(o.id))
			nav_dirty.emit()
		else:
			st.sat = maxf(0.0, float(st.sat) - 2.0)
			chat(o.cust, "Nie da rady. O %s albo wcale." % clock(o.meet))
	elif kind == "decline":
		chat(o.cust, "Nie tym razem." if o.status == "new" else "Muszę odwołać. Sorry.", true)
		var was_accepted: bool = o.status == "accepted"
		drop_order(o)
		st.declines = int(st.declines) + 1
		st.sat = maxf(0.0, float(st.sat) - (8.0 if was_accepted else 2.0))
		if int(st.declines) >= 3:
			st.loy = maxf(0.0, float(st.loy) - 5.0)
			st.declines = 0
		chat(o.cust, ["Szkoda. Następnym razem.", "Ok, rozumiem."].pick_random() if not was_accepted else "Serio? Już się zbierałem. Słabo.", false, true)


func _accept_order(o: Dictionary, agreed, line: String) -> void:
	var def := cust_def(o.cust)
	o.status = "accepted"
	o.agreed = agreed
	o.counter = null
	o.t0 = S.t
	S.cust[o.cust].declines = 0
	if npcs != null:
		npcs.spawn_customer(o)
	S.track = int(o.id)
	S.nav_on = true
	chat(o.cust, line, false, true)
	notify("Spotkanie o %s: %s — %s." % [clock(o.meet), def.name, spot_def(o.spot).name], "good")
	nav_dirty.emit()


## najbliższe umówione spotkanie
func next_meeting() -> Variant:
	var best = null
	for o in S.orders:
		if o.status == "accepted" and (best == null or float(o.meet) < float(best.meet)):
			best = o
	return best


func client_count() -> int:
	var n := 0
	for id in S.cust:
		if S.cust[id].unlocked:
			n += 1
	return n


func client_cap() -> int:
	return int(D.MAX_CLIENTS[mini(int(S.lvl), D.MAX_CLIENTS.size() - 1)]) + (2 if has_skill("siec") else 0)


func check_unlocks() -> void:
	for c in D.CLIENTS:
		var st: Dictionary = S.cust[c.id]
		if st.unlocked or int(S.lvl) < int(c.lvl) or S.t < float(st.lost_until) or client_count() >= client_cap():
			continue
		var via: String = c.via
		if via.begins_with("ref:"):
			var parts := via.split(":")
			var src: Dictionary = S.cust[parts[1]]
			var need := int(parts[2])
			if has_skill("slowo"):
				need = maxi(1, int(ceil(need * 0.65)))
			if src.unlocked and int(src.deals) >= need and float(src.sat) >= 55.0:
				unlock_client(c.id, "Cześć. Mam numer od: %s — podobno można na tobie polegać. Odezwę się." % cust_def(parts[1]).name)
	for c in D.CLIENTS:
		var st2: Dictionary = S.cust[c.id]
		if st2.unlocked and c.id != "dominik" and float(st2.sat) < 15.0:
			st2.unlocked = false
			st2.sat = 45.0
			st2.lost_until = S.t + 4.0 * 1440.0
			for o in S.orders.duplicate():
				if o.cust == c.id:
					drop_order(o)
			chat(c.id, "Wiesz co? Znalazłem kogoś lepszego. Nie pisz do mnie.")
			notify("Straciłeś klienta: " + String(c.name), "bad")


func unlock_client(id: String, text := "Cześć, słyszałem o tobie.") -> bool:
	var st: Dictionary = S.cust[id]
	if st.unlocked:
		return false
	st.unlocked = true
	st.next = S.t + randf_range(1.0, 3.0) * 60.0
	chat(id, text)
	notify("Nowy klient: %s" % cust_def(id).name, "good")
	add_xp(10.0)
	return true


## rozmowa z postacią w świecie, która może zostać klientem (via: talk)
func meet(id: String) -> String:
	var c := cust_def(id)
	var st: Dictionary = S.cust[id]
	if st.unlocked:
		return "Pisz, jak będziesz coś miał. Znasz numer."
	if int(S.lvl) < int(c.lvl):
		return "Nie znam cię. Spadaj."
	if client_count() >= client_cap():
		return "Słyszałem o tobie… ale podobno ledwo ogarniasz tych, których już masz. Może kiedyś."
	unlock_client(id, "To ja, %s. Zapisz numer. Odezwę się, jak będę czegoś potrzebować." % c.name)
	return "A, to ty jesteś ten nowy od Wiktora? Dobra. Daj numer, odezwę się."


# ================================================================ negocjacje
func market_price(p: String, pur) -> float:
	return float(D.PRODUCTS[p].base) * price_factor(pur) * float(S.demand[p])


## zaczyna rozmowę handlową; zwraca {} gdy nie można
func deal_start(ctx: Dictionary) -> Dictionary:
	var st_list := stacks(S.inv, "pack")
	if st_list.is_empty():
		notify("Nie masz przy sobie zaporcjowanego towaru.", "warn")
		return {}
	if npcs != null and npcs.any_chase():
		notify("Nie teraz! Policja depcze Ci po piętach!", "bad")
		return {}
	var who: Dictionary = ctx.who
	var st: Dictionary = who.st
	var o = ctx.get("order")
	var late := 0.0
	if o != null:
		late = clampf((S.t - float(o.meet) - 5.0) * 0.45, 0.0, 25.0)
	var mood := clampf(45.0 + (float(st.get("sat", 55.0)) - 50.0) * 0.5 - late - (8.0 if rain > 0.3 else 0.0), 5.0, 95.0)
	var pat := int(who.patience) + (1 if has_skill("gadka") else 0) + (1 if mood >= 75.0 else 0) - (1 if mood < 30.0 else 0)
	var d := {"ctx": ctx, "who": who, "st": st, "product": ctx.product, "want": int(ctx.grams), "qty": int(ctx.grams), "sel": {}, "price": 0,
		"patience": maxi(1, pat), "max_patience": maxi(1, pat), "mood": mood, "noise": (float(o.noise) if o != null else randf_range(0.93, 1.07)), "boost": 1.0,
		"used": {}, "counter": null, "speech": "", "over": false, "sold": false, "phase": "greet", "late": late, "credit": false, "upsold": 0,
		"haggle": ctx.get("agreed") == null, "last_ratio": 0.0, "cop": null, "cop_t": 0.0, "cop_max": 0.0, "notes": []}
	var best = null
	for s in st_list:
		if s.p != ctx.product:
			continue
		if best == null or (int(s.pur) >= int(who.minpur) and (int(best.pur) < int(who.minpur) or int(s.pur) < int(best.pur))):
			best = s
	d.sel = best if best != null else st_list[0]
	d.qty = clampi(int(d.want), 1, int(d.sel.n))
	d.price = int(ctx.agreed) if ctx.get("agreed") != null else int(round(market_price(d.sel.p, d.sel.pur)))
	if ctx.get("sting", false):
		d.speech = "„Dawaj, co masz. Biorę wszystko!”"
		d.phase = "offer"
	else:
		var hello := {
			"luzak": ["„Siema! No w końcu.”", "„Elo, masz to?”"], "twardziel": ["„Jesteś. Dobra.”", "„No.”"], "gadula": ["„O, pan kolega! A już myślałem, że pan nie przyjdzie.”"],
			"konkret": ["„Dzień dobry. Nie mam dużo czasu.”"], "cwaniak": ["„No proszę, kto przyszedł. Mam nadzieję, że z dobrą ceną.”"], "impulsywny": ["„Wreszcie! Dawaj, dawaj.”"],
		}
		var hl: Array = hello.get(who.get("type", "luzak"), hello.luzak)
		d.speech = hl.pick_random()
		if late > 8.0:
			d.speech = String(d.speech) + " „Ile można czekać?”"
			d.notes.append("Spóźnienie: nastrój −%d" % int(late))
	if float(st.get("owes", 0.0)) > 0.0:
		if randf() < float(who.get("reliable", 0.8)):
			S.cash += float(st.owes)
			d.notes.append("Oddał dług: +%s" % money(st.owes))
			st.owes = 0.0
		else:
			d.notes.append("Wciąż wisi Ci %s („następnym razem…”)" % money(st.owes))
	if player != null and player.loc == "out" and npcs != null:
		var pp: Vector3 = player.global_position
		for c in npcs.cops:
			if Vector2(c.x - pp.x, c.z - pp.z).length() < 22.0 and world.los(c.x, c.z, pp.x, pp.z):
				d.cop = c
				d.cop_t = 16.0
				d.cop_max = 16.0
				d.mood = maxf(5.0, float(d.mood) - 30.0 * float(who.get("nerv", 0.1)))
				break
	return d


func deal_max(d: Dictionary) -> float:
	return max_price(d.who, d.st, d.sel.p, d.sel.pur, int(d.qty), {"noise": d.noise, "boost": d.boost, "minpur": d.who.minpur, "mood": d.mood})


## podpowiedź ceny zależna od umiejętności: {lo, hi} albo {}
func deal_hint(d: Dictionary) -> Dictionary:
	var err := 0.0
	if has_skill("oko2"):
		err = 0.06
	elif has_skill("oko1"):
		err = 0.15
	else:
		return {}
	var mx := deal_max(d)
	var seed_f := float(int(float(d.noise) * 1000.0) % 17) / 17.0 - 0.5
	var mid := mx * (1.0 + seed_f * err)
	return {"lo": mid * (1.0 - err), "hi": mid * (1.0 + err)}


func deal_greet(d: Dictionary, style: String) -> void:
	var who: Dictionary = d.who
	var known: Dictionary = d.st.get("known", {})
	var good := {"luz": "„Hehe, no i git. Z tobą to się da pogadać.”", "konkret": "„Dobrze. Lubię, jak ktoś nie marnuje mojego czasu.”", "twardo": "„No. Tak się rozmawia.”"}
	var bad := {"luz": "„Nie jesteśmy kolegami. Do rzeczy.”", "konkret": "„A co tak sztywno? Wyluzuj trochę…”", "twardo": "„Ej, spokojnie! Nie tym tonem.”"}
	if style == String(who.get("like", "")):
		d.mood = minf(95.0, float(d.mood) + 14.0)
		d.speech = good[style]
		known["like"] = style
		d.notes.append("Trafiony styl: nastrój +14")
	elif style == String(who.get("hate", "")):
		d.mood = maxf(5.0, float(d.mood) - 14.0)
		d.patience = maxi(1, int(d.patience) - 1)
		d.speech = bad[style]
		known["hate"] = style
		d.notes.append("Zły styl: nastrój −14, cierpliwość −1")
	else:
		d.mood = minf(95.0, float(d.mood) + 3.0)
		d.speech = "„No dobra. Co masz?”"
	if d.st.has("known"):
		d.st.known = known
	d.phase = "offer"


func deal_agreed_price(d: Dictionary) -> int:
	var a := float(d.ctx.agreed)
	var mq := int(d.who.minpur)
	if d.sel.p != d.ctx.product:
		return 0
	if int(d.sel.pur) < mq - 15:
		return 0
	if int(d.sel.pur) < mq:
		return int(round(a * 0.72))
	return int(round(a * (1.0 + 0.004 * (int(d.sel.pur) - maxi(60, mq)))))


## Doświadczony klient (kupił już sporo albo bierze duże ilości) może rozpoznać
## rozrobiony towar i odmówić. Zwraca true, jeśli rozmowa się na tym kończy.
func deal_quality_reject(d: Dictionary) -> bool:
	if d.over or d.used.has("qcheck_" + str(int(d.sel.pur))) or d.ctx.get("sting", false):
		return false
	d.used["qcheck_" + str(int(d.sel.pur))] = true
	var who: Dictionary = d.who
	var gap := int(who.minpur) - int(d.sel.pur)
	if gap <= 0:
		return false
	var experience := clampf(float(d.st.get("grams", 0)) / 40.0, 0.0, 1.0)
	if who.has("grams") and int(who.grams[1]) >= 5:
		experience = maxf(experience, 0.6)
	var p := experience * clampf(gap / 20.0, 0.25, 1.0) * (0.7 if has_skill("czysta") else 1.0)
	if randf() >= p:
		return false
	d.over = true
	d.counter = null
	var what: String = D.FILLER_NAMES.get(D.FILLER.get(d.sel.p, ""), "wypełniacz").to_lower()
	d.speech = "„Czekaj… co to ma być? Czuję tu %s. Nie rób ze mnie idioty — tego nie biorę.”" % what
	d.notes.append("Klient rozpoznał mieszankę (czystość %d%%, oczekuje min. %d%%)." % [int(d.sel.pur), int(who.minpur)])
	if d.st.has("sat"):
		d.st.sat = maxf(0.0, float(d.st.sat) - 10.0)
		d.st.loy = maxf(0.0, float(d.st.get("loy", 0.0)) - 4.0)
		if d.st.has("known"):
			d.st.known["minpur"] = true
	if d.ctx.get("order") != null:
		drop_order(d.ctx.order)
	deal_finish(d, {"sold": 0, "rejected": true})
	return true


func deal_offer(d: Dictionary) -> void:
	if d.over or deal_quality_reject(d):
		return
	var P := float(d.price)
	var mx := deal_max(d)
	var r := P / mx
	var who: Dictionary = d.who
	var typ: String = who.get("type", "luzak")
	d.last_ratio = r
	d.counter = null
	if d.ctx.get("sting", false):
		deal_sell(d, P, "„Biorę! Trzymaj kasę.”")
		return
	var low_pur := int(d.sel.pur) < int(who.minpur)
	if r <= 0.9:
		deal_sell(d, P, "„Stoi! Uczciwa cena.”" if not low_pur else "„Słabizna, ale za tyle wezmę.”")
		return
	if r <= 1.0:
		if randf() < 1.0 - ((r - 0.9) / 0.1) * 0.65:
			deal_sell(d, P, ["„No dobra, niech stracę.”", "„Okej, biorę.”", "„Niech ci będzie.”"].pick_random())
			return
	var lo := 0.9 if has_skill("rekin") else 0.86
	var hi := 0.98 if has_skill("rekin") else 0.95
	if r <= 1.12:
		d.patience = int(d.patience) - 1
		d.counter = int(round(mx * randf_range(lo, hi)))
		d.speech = ["„Trochę drogo. %s i po sprawie.”" % money(d.counter), "„Mogę dać %s za gram.”" % money(d.counter), "„Hmm… prawie. %s, nie więcej.”" % money(d.counter)].pick_random()
	elif r <= 1.4:
		d.patience = int(d.patience) - (2 if typ in ["twardziel", "cwaniak", "impulsywny"] else 1)
		d.mood = maxf(5.0, float(d.mood) - 5.0)
		d.counter = int(round(mx * randf_range(lo - 0.06, hi - 0.05)))
		d.speech = ["„Przesadzasz. Góra %s.”" % money(d.counter), "„Za drogo! %s, bo idę gdzie indziej.”" % money(d.counter)].pick_random()
	else:
		d.patience = int(d.patience) - 2
		d.mood = maxf(5.0, float(d.mood) - 12.0)
		d.speech = ["„Chyba żartujesz?!”", "„Ile?! Pogięło cię?”", "„Za kogo ty mnie masz?”"].pick_random()
		if int(d.patience) > 0:
			d.counter = int(round(mx * randf_range(0.74, 0.84)))
	if low_pur and not d.used.has("lowpur"):
		d.used["lowpur"] = true
		d.speech = String(d.speech) + " „I co to za syf? Ostatnio było lepsze.”"
	_deal_check_walk(d)


func _deal_check_walk(d: Dictionary) -> void:
	if int(d.patience) > 0 or d.over:
		return
	d.over = true
	d.counter = null
	S.stats.walked = int(S.stats.walked) + 1
	var who: Dictionary = d.who
	if d.st.has("sat"):
		d.st.sat = maxf(0.0, float(d.st.sat) - 8.0)
	var snitch := randf() < float(who.get("nerv", 0.1)) * 0.5 + (0.15 if float(d.last_ratio) > 1.4 else 0.03)
	if snitch:
		d.speech = "„Mam dość! Dzwonię na policję!” — odchodzi, wściekły."
		add_heat(12.0)
		add_invest(3.0)
		if player != null and npcs != null:
			var pp: Vector3 = player.global_position
			npcs.dispatch_to(pp.x, pp.z, 2)
		notify("Klient wezwał policję!", "bad")
	else:
		d.speech = ["„Tracę czas. Cześć.” — odchodzi.", "„Nie dogadamy się.” — odwraca się plecami."].pick_random()
	if d.ctx.get("order") != null:
		drop_order(d.ctx.order)
	deal_finish(d, {"sold": 0, "walked": true})


func deal_sell(d: Dictionary, price: float, line: String) -> void:
	var mx := deal_max(d)
	var res := complete_sale(d.ctx, d.sel.p, int(d.sel.pur), int(d.qty), price, mx, d.credit)
	d.over = true
	d.sold = true
	d.counter = null
	var fb := ""
	if not d.ctx.get("sting", false):
		if mx - price > mx * 0.22:
			fb = "\n[color=#fbbf24]Mogłeś wziąć więcej — był gotów dać ok. %s za gram.[/color]" % money(mx)
		elif mx - price < mx * 0.07:
			fb = "\n[color=#4ade80]Świetny interes — prawie jego maksimum![/color]"
	var pay := "[color=#4ade80]+%s[/color]" % money(res.paid)
	if d.credit:
		pay += " teraz, reszta (%s) na zeszyt" % money(res.owed)
	d.speech = "%s\n[b]%s[/b] za %d g %s.%s" % [line, pay, int(d.qty), D.PRODUCTS[d.sel.p].name, fb]
	deal_finish(d, res)


func deal_accept(d: Dictionary) -> void:
	if d.counter != null and not d.over and not deal_quality_reject(d):
		deal_sell(d, float(d.counter), "„Dobra, tak wygląda uczciwa cena.”")


func deal_sell_agreed(d: Dictionary) -> void:
	var ap := deal_agreed_price(d)
	if ap > 0 and not d.over and not deal_quality_reject(d):
		deal_sell(d, float(ap), ["„Tak jak się umawialiśmy. Dzięki.”", "„Słowo to słowo. Trzymaj.”"].pick_random())


func deal_haggle(d: Dictionary) -> void:
	d.haggle = true
	d.patience = maxi(1, int(d.patience) - 1)
	d.price = int(round(float(d.ctx.agreed) * 1.1))
	d.mood = maxf(5.0, float(d.mood) - 8.0)
	d.speech = "„Ej, umawialiśmy się inaczej… No dobra, mów.”"


## dostępne taktyki: [{id, label, tip, on}]
func deal_tactics(d: Dictionary) -> Array:
	var u: Dictionary = d.used
	var have := int(S.inv.pack[d.sel.p].get(str(int(d.sel.pur)), 0))
	return [
		{"id": "pogadaj", "label": "Zagadaj", "tip": "Luźna gadka poprawia nastrój (gaduły to kochają, konkretni nie).", "on": not u.has("pogadaj")},
		{"id": "zachwal", "label": "Zachwal towar", "tip": "Działa, jeśli czystość wyraźnie przewyższa oczekiwania klienta.", "on": not u.has("zachwal")},
		{"id": "probka", "label": "Daj spróbować (−1 g)", "tip": "Klient zapłaci więcej i zyska cierpliwość.", "on": not u.has("probka") and have > int(d.qty)},
		{"id": "ostatnie", "label": "„Ostatnie sztuki”", "tip": "Blef. Na impulsywnych działa, cwaniak Cię przejrzy.", "on": not u.has("ostatnie")},
		{"id": "ilosc", "label": "Rabat za ilość", "tip": "+1–2 g w pakiecie, 7% taniej za gram.", "on": not u.has("ilosc") and have >= int(d.qty) + 1 and not d.ctx.get("sting", false)},
		{"id": "zeszyt", "label": "Na zeszyt", "tip": "Połowa teraz, reszta +10% przy następnym spotkaniu. Nie każdy oddaje.", "on": not u.has("zeszyt") and d.st.has("owes") and float(d.st.get("loy", 0.0)) >= 15.0},
		{"id": "odejdz", "label": "Udaj, że odchodzisz", "tip": "Głodny klient zmięknie. Syty po prostu pozwoli Ci odejść.", "on": not u.has("odejdz") and d.counter != null},
	]


func deal_tactic(d: Dictionary, id: String) -> void:
	if d.over or d.used.has(id):
		return
	d.used[id] = true
	var who: Dictionary = d.who
	var typ: String = who.get("type", "luzak")
	match id:
		"pogadaj":
			var dm := {"gadula": 15.0, "luzak": 9.0, "impulsywny": -6.0, "konkret": -7.0, "twardziel": 2.0, "cwaniak": 5.0}
			var v: float = dm.get(typ, 4.0)
			d.mood = clampf(float(d.mood) + v, 5.0, 95.0)
			add_minutes(12.0)
			if v > 0.0:
				d.speech = "„A wiesz, co ostatnio…” — gadacie chwilę. Nastrój wyraźnie lepszy."
			else:
				d.speech = "„Możemy bez pogaduszek? Śpieszę się.”"
				d.patience = int(d.patience) - 1
		"zachwal":
			if int(d.sel.pur) >= int(who.minpur) + 12:
				d.boost = float(d.boost) * 1.06
				d.mood = minf(95.0, float(d.mood) + 4.0)
				d.speech = ["„Hmm, faktycznie pachnie jak trzeba.”", "„No, nie powiem, wygląda czysto.”"].pick_random()
			else:
				d.mood = maxf(5.0, float(d.mood) - 8.0)
				d.patience = int(d.patience) - 1
				d.speech = ["„Sam widzę, co to jest. Nie wciskaj mi kitu.”", "„Mniej gadania, więcej konkretów.”"].pick_random()
		"probka":
			take_pack(S.inv, d.sel.p, d.sel.pur, 1)
			d.boost = float(d.boost) * 1.05
			d.patience = int(d.patience) + 1
			d.max_patience = maxi(int(d.max_patience), int(d.patience))
			if d.st.has("loy"):
				d.st.loy = minf(100.0, float(d.st.loy) + 2.0)
			d.speech = ["„O… nieźle. Dobra, gadajmy.”", "„Hmm! Dobre. To ile za to chcesz?”"].pick_random()
		"ostatnie":
			if randf() < float(D.SCARCITY.get(typ, 0.5)):
				d.boost = float(d.boost) * 1.08
				d.speech = ["„Ostatnie? Dobra, dobra, biorę — tylko nie przesadzaj z ceną.”", "„Kurde… No to dawaj, zanim ktoś inny weźmie.”"].pick_random()
			else:
				d.mood = maxf(5.0, float(d.mood) - 10.0)
				d.patience = int(d.patience) - 1
				d.speech = ["„Ostatnie, jasne. Co tydzień masz ostatnie.”", "„Nie rób ze mnie frajera.”"].pick_random()
		"ilosc":
			var have := int(S.inv.pack[d.sel.p].get(str(int(d.sel.pur)), 0))
			var extra: int = clampi(have - int(d.qty), 1, 2)
			if float(d.st.get("hunger", 0.4)) > 0.35 or float(who.wealth) >= 1.1 or randf() < 0.4:
				d.qty = int(d.qty) + extra
				d.upsold = extra
				d.price = int(round(float(d.price) * 0.93))
				d.speech = "„Dobra, dorzuć %d g. Ale po %s.”" % [extra, money(d.price)]
			else:
				d.speech = "„Nie, tyle mi wystarczy.”"
		"zeszyt":
			d.credit = true
			d.boost = float(d.boost) * 1.1
			d.speech = "„Na zeszyt? No to mogę dać więcej. Oddam przy następnej okazji, słowo.”"
		"odejdz":
			if float(d.st.get("hunger", 0.4)) > 0.5 or typ == "impulsywny":
				d.counter = int(round(deal_max(d) * 0.97))
				d.speech = "„Ej, czekaj, czekaj! Dobra — %s. Ale to moje ostatnie słowo.”" % money(d.counter)
			else:
				d.over = true
				d.speech = "„No to idź.” — wzrusza ramionami."
				if d.st.has("sat"):
					d.st.sat = maxf(0.0, float(d.st.sat) - 3.0)
				deal_finish(d, {"sold": 0, "left": true})
				return
	_deal_check_walk(d)


func deal_leave(d: Dictionary) -> void:
	if not d.over:
		d.over = true
	deal_finish(d, {"sold": 0, "left": true})


func deal_finish(d: Dictionary, res: Dictionary) -> void:
	var ctx: Dictionary = d.ctx
	if ctx.has("on_done") and ctx.on_done != null:
		var cb: Callable = ctx.on_done
		ctx.on_done = null
		cb.call(res)


# ================================================================ sprzedaż
func complete_sale(ctx: Dictionary, p: String, pur: int, g: int, price: float, mx: float, credit := false) -> Dictionary:
	var total: float = round(price * g)
	take_pack(S.inv, p, pur, g)
	var paid := total
	var owed := 0.0
	var st = ctx.who.get("st")
	if credit and st != null and st.has("owes"):
		paid = round(total * 0.5)
		owed = round((total - paid) * 1.1)
		st.owes = float(st.owes) + owed
	S.cash += paid
	S.stats.earned = float(S.stats.earned) + paid
	S.stats.sold = int(S.stats.sold) + g
	S.stats.deals = int(S.stats.deals) + 1
	S.stats.best = maxf(float(S.stats.best), total)
	Sfx.play("cash")
	notify("+%s  (%d g %s)" % [money(paid), g, D.PRODUCTS[p].name], "good")
	var xp := g * 3.4 * (0.8 + tier(pur) * 0.22) * (1.8 if p != "dym" else 1.0) + 2.0
	if price >= mx * 0.9:
		xp += 2.0
	if ctx.has("order") and ctx.order != null:
		var o: Dictionary = ctx.order
		var cs: Dictionary = S.cust[o.cust]
		var def := cust_def(o.cust)
		o.grams = int(o.grams) - g
		cs.loy = minf(100.0, float(cs.loy) + 1.5 + g * 0.6)
		cs.deals = int(cs.deals) + 1
		cs.grams = int(cs.grams) + g
		var ds := 3.0 if price < mx * 0.8 else (-2.0 if price > mx * 0.97 else 1.0)
		ds += clampf((pur - int(def.minpur)) / 6.0, -8.0, 5.0)
		cs.sat = clampf(float(cs.sat) + ds, 0.0, 100.0)
		cs.hunger = 0.05
		cs.next = maxf(float(cs.next), S.t + 120.0)
		if int(cs.deals) >= 5:
			cs.known["budget"] = true
		if int(o.grams) <= 0:
			drop_order(o)
		xp += 3.0
	if ctx.get("npc") != null and ctx.npc.kind == "citizen":
		ctx.npc.loyalty += 1
		ctx.npc.last_deal = S.t
	add_xp(xp)
	add_minutes(4.0)
	if ctx.get("street", false) and player != null and player.loc == "out":
		after_deal_risk(ctx, g)
	check_unlocks()
	return {"sold": g, "revenue": total, "paid": paid, "owed": owed}


func after_deal_risk(ctx: Dictionary, g: int) -> void:
	add_heat(2.0 + g * 0.6)
	var pp: Vector3 = player.global_position
	var w: int = npcs.citizens_near(pp.x, pp.z, 13.0) - (1 if (ctx.get("npc") != null and ctx.npc.kind == "citizen") else 0)
	if w > 0:
		var chance := w * (0.05 if is_night() else 0.11)
		if randf() < chance:
			notify("Ktoś z przechodniów mógł zadzwonić na policję…", "warn")
			add_heat(9.0)
			add_invest(3.0)
			npcs.dispatch_to(pp.x, pp.z, 2)


func sting_chance() -> float:
	if int(S.stats.deals) < 8:
		return 0.0
	return clampf(0.02 + S.invest / 350.0, 0.0, 0.3)


# ================================================================ hurt u Wiktora i skrytki
func wholesale_unit(p: String, high: bool) -> float:
	return float(D.PRODUCTS[p].cost) * float(S.cost_mult) * (1.35 if high else 1.0) * (0.92 if has_skill("rabat") else 1.0)


func wholesale_price(p: String, g: int, high: bool) -> float:
	return round(wholesale_unit(p, high) * g * (1.0 - float(D.WHOLESALE_DISC.get(g, 0.0))))


func wholesale_max() -> int:
	return int(D.WHOLESALE_MAX[mini(int(S.lvl), D.WHOLESALE_MAX.size() - 1)])


func credit_limit() -> float:
	return float(D.CREDIT_BASE) + (int(S.lvl) - 1) * 150.0 + (600.0 if has_skill("kredyt") else 0.0)


func credit_overdue() -> bool:
	return float(S.credit) > 0.0 and S.t > float(S.credit_due)


## dlaczego nie można zamówić ("" = można)
func order_block(p: String, g: int, on_credit: bool, high: bool) -> String:
	if not flag("hurt_on"):
		return "Wiktor jeszcze Ci nie ufa."
	if int(S.lvl) < int(D.PRODUCTS[p].lvl):
		return "Od poziomu %d." % int(D.PRODUCTS[p].lvl)
	if g > wholesale_max():
		return "Maks. %d g na Twoim poziomie." % wholesale_max()
	if high and int(S.lvl) < 5:
		return "Czysty towar od poziomu 5."
	if S.drops.size() >= 2:
		return "Najpierw odbierz zamówione paczki."
	if credit_overdue():
		if rescue_order(p, g, on_credit, high):
			return ""
		return "Spłać zaległy zeszyt." if all_goods() >= 1.0 or not S.drops.is_empty() else "Zeszyt po terminie: Wiktor da najwyżej 5 g Greena na zeszyt, 25% drożej."
	var cost := wholesale_price(p, g, high)
	if on_credit and float(S.credit) + cost > credit_limit():
		return "Przekroczysz limit zeszytu (%s)." % money(credit_limit())
	return ""


## cały towar gracza: plecak i wszystkie skrytki
func all_goods() -> float:
	var n := goods_total(S.inv)
	for r in S.stash:
		n += goods_total(S.stash[r])
	return n


## deska ratunku: bez towaru, z zaległym zeszytem, Wiktor da 5 g Greena drożej — żeby gra się nie zakleszczyła
func rescue_order(p: String, g: int, on_credit: bool, high: bool) -> bool:
	return credit_overdue() and p == "dym" and g == 5 and on_credit and not high and all_goods() < 1.0 and S.drops.is_empty()


func order_goods(p: String, g: int, high: bool, on_credit: bool) -> bool:
	if order_block(p, g, on_credit, high) != "":
		return false
	var used := []
	for d in S.drops:
		used.append(d.spot)
	var opts := []
	for dd in D.DROPS:
		if int(S.lvl) >= int(dd.lvl) and not used.has(dd.id):
			opts.append(dd)
	if opts.is_empty():
		return false
	var spot: Dictionary = opts.pick_random()
	var ready: float = S.t + randf_range(40.0, 90.0)
	var pur: int = D.PURITY_HIGH if high else D.PURITY_STD + randi_range(-1, 1) * 5
	var rescue := rescue_order(p, g, on_credit, high)
	var d := {"id": int(S.next_drop), "spot": spot.id, "p": p, "g": g, "pur": pur, "cost": round(wholesale_price(p, g, high) * (1.25 if rescue else 1.0)),
		"credit": on_credit, "ready": ready, "expire": ready + 16.0 * 60.0, "state": "wait"}
	S.next_drop = int(S.next_drop) + 1
	S.drops.append(d)
	chat("wiktor", "Zamawiam: %d g %s%s, %s." % [g, D.PRODUCTS[p].name, " (czysty)" if high else "", "na zeszyt" if on_credit else "płatne przy odbiorze"], true)
	if rescue:
		chat("wiktor", "Wisisz mi, a chcesz jeszcze? Ostatni raz. Pięć gramów, ćwierć drożej. Sprzedaj i oddaj.", false, true)
	chat("wiktor", "Przyjąłem. Skrytka: %s. Dam znać, jak paczka będzie na miejscu (ok. %d min)." % [spot.name, int((ready - S.t) / 10.0) * 10], false, true)
	Sfx.play("select")
	return true


func ready_drop() -> Variant:
	for d in S.drops:
		if d.state == "ready":
			return d
	return null


## dlaczego nie można zabrać paczki ("" = można)
func pickup_block(d: Dictionary) -> String:
	if carry_total() + float(d.g) > float(capacity()) + 0.01:
		return "Za mało miejsca: paczka %d g, wolne %s." % [int(d.g), grams(maxf(0.0, capacity() - carry_total()))]
	if not d.credit and S.cash < float(d.cost):
		if float(S.credit) + float(d.cost) <= credit_limit() and not credit_overdue():
			return ""
		return "Brakuje %s — Wiktor nie daje za darmo." % money(float(d.cost) - S.cash)
	return ""


func pickup_drop(d: Dictionary) -> bool:
	var why := pickup_block(d)
	if why != "":
		notify(why, "warn")
		return false
	var on_credit: bool = d.credit or S.cash < float(d.cost)
	if on_credit:
		if float(S.credit) <= 0.0:
			S.credit_due = S.t + D.CREDIT_DAYS * 1440.0
		S.credit = float(S.credit) + float(d.cost)
		notify("Paczka na zeszyt: %s do oddania do dnia %d." % [money(d.cost), int(float(S.credit_due) / 1440.0) + 1], "warn")
	else:
		S.cash -= float(d.cost)
		S.stats.spent = float(S.stats.spent) + float(d.cost)
		notify("Zostawiasz %s w skrytce." % money(d.cost))
	add_bulk(S.inv, d.p, d.pur, float(d.g))
	S.drops.erase(d)
	S.stats.pickups = int(S.stats.pickups) + 1
	S.flags["got_first"] = true
	Sfx.play("pickup")
	notify("Zabrano: %d g %s (%d%%, %s)" % [int(d.g), D.PRODUCTS[d.p].name, int(d.pur), tier_name(d.pur)], "good")
	add_xp(6.0)
	if S.track is String and S.track == "drop":
		S.track = null
	nav_dirty.emit()
	return true


func pay_credit(amount: float) -> void:
	var n: float = minf(amount, minf(S.cash, float(S.credit)))
	if n <= 0.0:
		return
	S.cash -= n
	S.credit = float(S.credit) - n
	S.stats.spent = float(S.stats.spent) + n
	Sfx.play("cash")
	notify("Oddano Wiktorowi %s. Zeszyt: %s" % [money(n), money(S.credit)], "good")


# ================================================================ porcjowanie, mieszanie, uprawa
## stosy luzem dostępne przy stole: plecak + skrytka danej kryjówki
func bench_bulk(room: String) -> Array:
	var m := {}
	for src in [S.inv, S.stash[room]]:
		for s in stacks(src, "bulk"):
			var k := "%s:%d" % [s.p, int(s.pur)]
			if not m.has(k):
				m[k] = {"p": s.p, "pur": int(s.pur), "n": 0.0}
			m[k].n = float(m[k].n) + float(s.n)
	return m.values()


func pack_session_max() -> int:
	return 20 if has_skill("paczki") else 10


## porcjuje `g` gramów; hits = trafienia na wadze (0..3)
func pack(room: String, p: String, pur: int, g: int, hits: int) -> Dictionary:
	var n: int = mini(g, item_at(room, "woreczki"))
	var have := 0.0
	for src in [S.inv, S.stash[room]]:
		have += float(src.bulk[p].get(str(pur), 0.0))
	n = mini(n, int(floor(have + 0.001)))
	if n <= 0:
		return {"packed": 0, "lost": 0}
	var waste: float = [0.16, 0.08, 0.03, 0.0][clampi(hits, 0, 3)]
	var lost := 0
	for i in range(n):
		if randf() < waste:
			lost += 1
	var from_inv: float = take_bulk(S.inv, p, pur, float(n))
	take_bulk(S.stash[room], p, pur, float(n) - from_inv)
	var good := n - lost
	var to_inv: int = mini(good, int(round(from_inv)))
	add_pack(S.inv, p, pur, to_inv)
	add_pack(S.stash[room], p, pur, good - to_inv)
	take_item(room, "woreczki", n)
	S.stats.packed = int(S.stats.packed) + good
	S.stats.wasted = int(S.stats.wasted) + lost
	add_xp(good * 0.3)
	if lost > 0:
		notify("Zaporcjowano %d g, rozsypano %d g." % [good, lost], "warn")
	else:
		notify("Zaporcjowano %d g bez strat." % good, "good")
	return {"packed": good, "lost": lost}


func filler_for(p: String) -> String:
	return D.FILLER.get(p, "majeranek")


## rozrabia towar dodatkiem ze sklepu (majeranek, cukier puder); zwraca nową czystość
func mix(room: String, p: String, pur: int, g: float, filler_g: int) -> int:
	var fid := filler_for(p)
	if filler_g <= 0 or item_at(room, fid) < filler_g:
		return pur
	var from_inv: float = take_bulk(S.inv, p, pur, g)
	var from_stash: float = take_bulk(S.stash[room], p, pur, g - from_inv)
	var tot := from_inv + from_stash
	if tot <= 0.0:
		return pur
	var eff := float(filler_g) * (0.8 if has_skill("mieszanie") else 1.0)
	var np := qpur(float(pur) * tot / (tot + eff))
	var share := from_inv / tot
	take_item(room, fid, filler_g)
	var inv_room := maxf(0.0, float(capacity()) - carry_total())
	var to_inv: float = minf(snappedf((tot + filler_g) * share, 0.1), inv_room)
	add_bulk(S.inv, p, np, to_inv)
	add_bulk(S.stash[room], p, np, tot + filler_g - to_inv)
	notify("Mieszanka: %s → %s, czystość %d%% (%s)." % [grams(tot), grams(tot + filler_g), np, tier_name(np)], "warn" if np < 60 else "good")
	return np


func grow_job(room: String, idx: int) -> Variant:
	return S.hide[room].grow.get(str(idx))


func grow_label(room: String, idx: int) -> String:
	var j = grow_job(room, idx)
	if j == null:
		return "Namiot uprawowy — zasiej nasiona"
	if S.t >= float(j.end):
		return "Namiot uprawowy — zbierz plon"
	var left = float(j.end) - S.t
	return "Namiot uprawowy — rośnie (jeszcze %dh %02dm)" % [int(left / 60.0), int(left) % 60]


func grow_start(room: String, idx: int, hits: int) -> bool:
	if item_at(room, "nasiona") <= 0 or grow_job(room, idx) != null:
		return false
	take_item(room, "nasiona", 1)
	S.hide[room].grow[str(idx)] = {"start": S.t, "end": S.t + 36.0 * 60.0, "hits": hits}
	notify("Zasiane. Plon za 36 godzin — jakość zależy od tego, jak Ci poszło (%d/3)." % hits, "good" if hits >= 2 else "warn")
	return true


func grow_collect(room: String, idx: int) -> bool:
	var j = grow_job(room, idx)
	if j == null or S.t < float(j.end):
		return false
	var g: float = round(18.0 * (1.35 if has_skill("ogrodnik") else 1.0) * (0.8 + int(j.hits) * 0.1))
	var pur := 60 + int(j.hits) * 8
	add_bulk(S.stash[room], "dym", pur, g)
	S.hide[room].grow.erase(str(idx))
	S.stats.grown = int(S.stats.grown) + int(g)
	notify("Zebrano %s Greena (%d%%) — trafiło do skrytki w kryjówce." % [grams(g), qpur(pur)], "good")
	add_xp(g * 0.5)
	return true


# ================================================================ skrytki w kryjówkach
func move_stack(room: String, to_stash: bool, kind: String, p: String, pur: int, amount: float) -> float:
	var from: Dictionary = S.inv if to_stash else S.stash[room]
	var to: Dictionary = S.stash[room] if to_stash else S.inv
	var have := float(from[kind][p].get(str(pur), 0.0))
	var n: float = minf(amount, have)
	var space: float = (float(stash_cap(room)) - store_total(S.stash[room])) if to_stash else (float(capacity()) - carry_total())
	n = minf(n, maxf(0.0, space))
	if kind == "pack":
		n = floor(n + 0.001)
	if n <= 0.0:
		notify("Brak miejsca w %s." % ("skrytce" if to_stash else "plecaku"), "warn")
		return 0.0
	if kind == "pack":
		take_pack(from, p, pur, int(n))
		add_pack(to, p, pur, int(n))
	else:
		take_bulk(from, p, pur, n)
		add_bulk(to, p, pur, n)
	return n


func move_cash(room: String, deposit: bool, amount: float) -> void:
	var st: Dictionary = S.stash[room]
	if deposit:
		var n: float = minf(amount, S.cash)
		S.cash -= n
		st.cash = float(st.cash) + n
	else:
		var n2: float = minf(amount, float(st.cash))
		st.cash = float(st.cash) - n2
		S.cash += n2


# ================================================================ sklep, nieruchomości, meble, dług
func shop_buy(id: String) -> bool:
	for it in D.SHOP:
		if it.id == id:
			if S.cash < float(it.price) or int(S.lvl) < int(it.lvl):
				notify("Nie stać Cię albo to jeszcze nie ten poziom.", "warn")
				return false
			if it.has("skill") and not has_skill(it.skill):
				notify("Najpierw naucz się: %s." % skill_def(it.skill).name, "warn")
				return false
			if D.ITEMS.has(id) and carry_total() + float(D.ITEMS[id].size) * int(it.n) > float(capacity()) + 0.01:
				notify("Nie zmieścisz tego — %s pełne. Odłóż coś do skrytki." % ("kieszenie" if bag_name() == "Kieszenie" else "plecak"), "warn")
				return false
			S.cash -= float(it.price)
			S.stats.spent = float(S.stats.spent) + float(it.price)
			S.items[id] = item(id) + int(it.n)
			Sfx.play("cash")
			return true
	return false


func upgrade_buy(id: String) -> bool:
	for it in D.UPGRADES:
		if it.id == id:
			if upg(id) or S.cash < float(it.price) or int(S.lvl) < int(it.lvl) or (it.has("req") and not upg(it.req)):
				return false
			S.cash -= float(it.price)
			S.stats.spent = float(S.stats.spent) + float(it.price)
			S.upg[id] = true
			Sfx.play("good")
			notify("Kupiono: " + String(it.name), "good")
			return true
	return false


func use_burner() -> void:
	if item("burner") <= 0:
		return
	S.items["burner"] = item("burner") - 1
	add_invest(-25.0)
	Sfx.play("good")
	notify("Nowy numer. Stara karta w rzece — śledztwo −25.", "good")


func prop_def(id: String) -> Dictionary:
	for p in D.PROPERTIES:
		if p.id == id:
			return p
	return {}


func owns(id: String) -> bool:
	return bool(S.props.get(id, false))


func room_owned(room: String) -> bool:
	if room == "safe" or room == "shop":
		return true
	return owns(String(D.DOORS[room].get("prop", "")))


func buy_property(id: String) -> bool:
	var p := prop_def(id)
	if p.is_empty() or owns(id) or String(p.room) == "" or int(S.lvl) < int(p.lvl) or S.cash < float(p.price):
		return false
	S.cash -= float(p.price)
	S.stats.spent = float(S.stats.spent) + float(p.price)
	S.props[id] = true
	Sfx.play("level")
	notify("Kupiono: %s. Wejdź i urządź się — w środku naciśnij [B]." % p.name, "level")
	add_xp(40.0)
	nav_dirty.emit()
	return true


func door_label(id: String) -> String:
	var dd: Dictionary = D.DOORS[id]
	if not dd.has("prop"):
		return "Wejdź: " + String(D.ROOMS[id].name)
	var p := prop_def(dd.prop)
	if owns(dd.prop):
		return "Wejdź: " + String(p.name)
	return "%s — na sprzedaż: %s (poziom %d)" % [p.name, money(p.price), int(p.lvl)]


func furn_def(fid: String) -> Dictionary:
	for f in D.FURNITURE:
		if f.id == fid:
			return f
	return {}


static func furn_rect(f: Dictionary, x: float, z: float, r: int) -> Rect2:
	var sx: float = f.size[0]
	var sz: float = f.size[1]
	if r % 2 == 1:
		var t := sx
		sx = sz
		sz = t
	return Rect2(x - sx * 0.5, z - sz * 0.5, sx, sz)


func furn_valid(room: String, fid: String, x: float, z: float, r: int, ignore := -1) -> bool:
	var f := furn_def(fid)
	var R: Dictionary = D.ROOMS[room]
	var rc := furn_rect(f, x, z, r)
	if rc.position.x < -float(R.w) * 0.5 + 0.02 or rc.end.x > float(R.w) * 0.5 - 0.02 or rc.position.y < -float(R.d) * 0.5 + 0.02 or rc.end.y > float(R.d) * 0.5 - 0.02:
		return false
	if rc.intersects(Rect2(-1.0, float(R.d) * 0.5 - 1.5, 2.0, 1.5)):
		return false
	var items: Array = S.hide[room].items
	for i in range(items.size()):
		if i == ignore:
			continue
		var o: Dictionary = items[i]
		if rc.grow(-0.03).intersects(furn_rect(furn_def(o.f), float(o.x), float(o.z), int(o.r))):
			return false
	return true


func furn_place(room: String, fid: String, x: float, z: float, r: int) -> bool:
	var f := furn_def(fid)
	if f.is_empty() or not room_owned(room) or int(S.lvl) < int(f.lvl) or S.cash < float(f.price) or not furn_valid(room, fid, x, z, r):
		return false
	S.cash -= float(f.price)
	S.stats.spent = float(S.stats.spent) + float(f.price)
	S.hide[room].items.append({"f": fid, "x": snappedf(x, 0.05), "z": snappedf(z, 0.05), "r": r})
	Sfx.play("place")
	if world != null:
		world.refresh_furniture(room)
	return true


func furn_remove(room: String, idx: int) -> bool:
	var items: Array = S.hide[room].items
	if idx < 0 or idx >= items.size():
		return false
	var f := furn_def(items[idx].f)
	if f["func"] == "grow" and grow_job(room, idx) != null:
		notify("Najpierw zbierz plon z namiotu.", "warn")
		return false
	if f["func"] == "stash" and store_total(S.stash[room]) > float(stash_cap(room) - int(f.cap)):
		notify("Skrytka jest zbyt pełna, by usunąć ten mebel.", "warn")
		return false
	items.remove_at(idx)
	var ng := {}
	for k in S.hide[room].grow:
		var ki := int(k)
		ng[str(ki - 1 if ki > idx else ki)] = S.hide[room].grow[k]
	S.hide[room].grow = ng
	S.cash += round(float(f.price) * 0.5)
	notify("Sprzedano mebel za %s." % money(round(float(f.price) * 0.5)))
	if world != null:
		world.refresh_furniture(room)
	return true


func pay_debt(amount: float) -> void:
	var n: float = minf(amount, minf(S.cash, S.debt))
	if n <= 0.0:
		return
	S.cash -= n
	S.debt -= n
	S.paid += n
	Sfx.play("cash")
	notify("Spłacono %s. Zostało: %s" % [money(n), money(S.debt)], "good")
	if S.debt <= 0.0 and not flag("free"):
		S.flags["free"] = true
		if ui != null:
			ui.close_all()
		get_tree().create_timer(0.4).timeout.connect(func(): main.ending("wolnosc"))


func next_installment() -> Dictionary:
	for r in D.DEBT_SCHEDULE:
		if S.paid < float(r.due):
			return r
	return {}


# ================================================================ fabuła
func _build_story() -> void:
	story = [
		{"ch": "Rozdział 1: Dług brata", "id": "phone", "text": func(): return "Przeczytaj wiadomość od Wiktora: [Tab] → Wiadomości.",
			"done": func(): return flag("read_wiktor"), "on_done": _on_phone_done},
		{"id": "drop1", "text": func(): return "Idź do skrytki za altanką śmietnikową i zabierz paczkę (przytrzymaj [E]).",
			"done": func(): return flag("got_first"), "marker": _drop_marker},
		{"id": "pack1", "text": func(): return "Wróć do kawalerki i zaporcjuj towar na wadze. (%d/3 g)" % mini(3, int(S.stats.packed)),
			"done": func(): return int(S.stats.packed) >= 3, "marker": _bench_marker, "on_done": _on_pack_done},
		{"id": "sell1", "text": func(): return "Odpisz Dominikowi (Wiadomości) i dostarcz mu towar. (%d/2 g)" % mini(2, int(S.stats.sold)),
			"done": func(): return int(S.stats.sold) >= 2, "marker": _buyer_marker},
		{"id": "repay1", "text": func(): return "Oddaj Wiktorowi za pierwszą paczkę: telefon → Hurt → Spłać zeszyt. (%s)" % money(S.credit),
			"done": func(): return float(S.credit) <= 0.0, "on_done": _on_repay_done},
		{"ch": "Rozdział 2: Na swoim", "id": "order1", "text": func(): return "Zamów własny towar w aplikacji Hurt i odbierz go ze skrytki.",
			"done": func(): return int(S.stats.pickups) >= 2, "marker": _drop_marker},
		{"id": "lvl2", "text": func(): return "Zdobądź poziom 2. Zadowolony Dominik poleci Cię dalej. (%d/%d PD)" % [int(S.xp), int(D.XP_LEVELS[1])],
			"done": func(): return int(S.lvl) >= 2},
		{"id": "rata1", "text": func(): return "Spłać pierwszą ratę długu: %s do końca %d. dnia (telefon → Portfel). Spłacono: %s" % [money(D.DEBT_SCHEDULE[0].due), int(D.DEBT_SCHEDULE[0].day), money(S.paid)],
			"done": func(): return S.paid >= float(D.DEBT_SCHEDULE[0].due)},
		{"id": "lvl3", "text": func(): return "Zdobądź poziom 3 i wybierz pierwszą umiejętność (telefon → Rozwój).",
			"done": func(): return int(S.lvl) >= 3 and not S.skills.is_empty()},
		{"ch": "Rozdział 3: Kryjówka", "id": "garaz", "text": func(): return "Kup Garaż nr 14 (%s, poziom %d) — pierwszą własną kryjówkę." % [money(prop_def("garaz").price), int(prop_def("garaz").lvl)],
			"done": func(): return owns("garaz"), "marker": _garage_marker},
		{"id": "meble", "text": func(): return "Urządź garaż: w środku naciśnij [B] i wstaw stół roboczy oraz regał.",
			"done": func(): return _has_furn("garage", "pack") and _has_furn("garage", "stash")},
		{"ch": "Wolna gra", "id": "free", "text": func(): return "Rozwijaj interes i spłacaj raty. Dług: %s" % money(S.debt), "done": func(): return false},
	]


func _has_furn(room: String, fn: String) -> bool:
	for it in S.hide[room].items:
		if furn_def(it.f)["func"] == fn:
			return true
	return false


func _on_phone_done() -> void:
	S.drops.append({"id": int(S.next_drop), "spot": "smietnik", "p": "dym", "g": 5, "pur": 80, "cost": 105.0, "credit": true, "ready": S.t, "expire": S.t + 99999.0, "state": "ready"})
	S.next_drop = int(S.next_drop) + 1
	S.track = "drop"
	nav_dirty.emit()


func _on_pack_done() -> void:
	S.cust.dominik.unlocked = true
	S.cust.dominik.hunger = 0.6
	chat("wiktor", "Dominik z bloku 5 brał od twojego brata. Dałem mu twój numer.", false, true)
	make_order(D.CLIENTS[0], 2)


func _on_repay_done() -> void:
	S.flags["hurt_on"] = true
	chat("wiktor", "Uczciwy. Od teraz zamawiasz sam: aplikacja Hurt w telefonie. Płacisz przy odbiorze albo bierzesz na zeszyt — ale zeszyt ma termin.")
	add_xp(20.0)


func _garage_marker() -> Variant:
	return {"loc": "out", "x": D.DOORS.garage.x, "z": D.DOORS.garage.z}


func _bench_marker() -> Variant:
	return {"loc": "safe", "x": float(D.ROOMS.safe.cx) + 0.9, "z": -float(D.ROOMS.safe.d) * 0.5 + 1.5}


func _drop_marker() -> Variant:
	var d = ready_drop()
	if d == null:
		return null
	var dd := drop_def(d.spot)
	return {"loc": "out", "x": dd.x, "z": dd.z}


func _buyer_marker() -> Variant:
	if packed_total(S.inv) <= 0:
		return _bench_marker()
	var o = next_meeting()
	if o == null:
		return null
	var sp := spot_def(o.spot)
	return {"loc": "out", "x": sp.x, "z": sp.z}


func cur_step() -> Dictionary:
	var i := int(S.step)
	return story[i] if i < story.size() else {}


func chapter() -> String:
	var i: int = mini(int(S.step), story.size() - 1)
	while i >= 0:
		if story[i].has("ch"):
			return story[i].ch
		i -= 1
	return ""


func story_tick() -> void:
	var st := cur_step()
	if st.is_empty():
		return
	if st.done.call():
		notify("Cel ukończony!", "good")
		if st.has("on_done"):
			st.on_done.call()
		S.step = int(S.step) + 1
		add_xp(10.0)
		var nx := cur_step()
		if nx.has("ch"):
			notify(nx.ch, "level")
		nav_dirty.emit()


# ================================================================ zapis
func save_game(manual := true) -> void:
	if test_mode:
		return
	if player != null:
		S.pos = {"loc": player.loc, "x": player.global_position.x, "z": player.global_position.z, "yaw": player.yaw}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		if manual:
			notify("Nie udało się zapisać.", "bad")
		return
	f.store_string(JSON.stringify(S))
	f.close()
	if manual:
		notify("Gra zapisana.", "good")


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func _merge(base: Dictionary, data: Dictionary) -> void:
	for k in data:
		if base.has(k) and base[k] is Dictionary and data[k] is Dictionary and not (k in ["chats", "unread", "zheat", "flags", "skills", "upg", "props", "items"]):
			_merge(base[k], data[k])
		else:
			base[k] = data[k]


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var base := new_state()
	_merge(base, data)
	for k in ["woreczki", "majeranek", "cukier", "nasiona", "burner"]:
		if not base.items.has(k):
			base.items[k] = 0
	base.wanted = false
	S = base
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
