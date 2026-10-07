extends Node

const Prod = preload("res://scripts/production.gd")
const Market = preload("res://scripts/market.gd")
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
var prologue = null         # reżyser prologu (scripts/prologue.gd), gdy trwa
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


# ================================================================ sterowanie
## akcja -> klawisz (kod fizyczny); zmieniane w Opcjach i zapisywane w ustawieniach
const KEY_DEFAULTS := {"fwd": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "crouch": KEY_C,
	"use": KEY_E, "phone": KEY_TAB, "inv": KEY_I, "map": KEY_M, "flash": KEY_F, "nav": KEY_N, "track": KEY_Q,
	"build": KEY_B, "rotate": KEY_R, "ditch": KEY_X, "throw": KEY_G}
const KEY_ACTIONS := [["fwd", "Do przodu"], ["back", "Do tyłu"], ["left", "W lewo"], ["right", "W prawo"], ["sprint", "Bieg"], ["crouch", "Kucanie"],
	["use", "Użyj / rozmawiaj"], ["phone", "Telefon"], ["inv", "Ekwipunek"], ["map", "Mapa"], ["flash", "Latarka"], ["throw", "Rzut kamykiem (odciąga patrol)"], ["nav", "Trasa do celu"],
	["track", "Następny cel"], ["ditch", "Wyrzuć towar (przytrzymaj)"], ["build", "Meblowanie kryjówki"], ["rotate", "Obrót mebla"]]
var keys := KEY_DEFAULTS.duplicate()


func key_down(a: String) -> bool:
	return Input.is_physical_key_pressed(int(keys.get(a, 0)))


func key_action(kc: int) -> String:
	for a in keys:
		if int(keys[a]) == kc:
			return a
	return ""


## nazwa klawisza do podpowiedzi na ekranie
func kn(a: String) -> String:
	return key_label(int(keys.get(a, 0)))


static func key_label(kc: int) -> String:
	match kc:
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_META: return "Cmd"
		KEY_TAB: return "Tab"
		KEY_SPACE: return "Spacja"
		KEY_ESCAPE: return "Esc"
		KEY_ENTER: return "Enter"
		KEY_BACKSPACE: return "Backspace"
		KEY_CAPSLOCK: return "Caps Lock"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
	var n := OS.get_keycode_string(kc)
	return n if n != "" else "?"


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
		"heat": 0.0, "invest": 0.0, "strikes": 0, "arrests": 0, "step": 0, "flags": {}, "mlog": {}, "ground": [], "bins": {},
		"inv": new_store(), "stash": {"safe": new_store(), "garage": new_store(), "basement": new_store(), "wiktor": new_store(), "loot": new_store()},
		"items": {"woreczki": 0, "majeranek": 0, "cukier": 0, "nasiona": 0, "burner": 0, "nawoz": 0, "chemia": 0, "doniczka": 0, "kastet": 0}, "upg": {}, "pockets": [null, null, null, null],
		"cust": cust, "orders": [], "next_order": 1, "chats": {}, "unread": {},
		"track": null, "nav_on": true, "wanted": false,
		"demand": {"dym": 1.0, "szron": 1.0, "krysztal": 1.0, "snieg": 1.0}, "cost_mult": 1.0, "zheat": {}, "weather": null,
		"credit": 0.0, "credit_due": 0.0, "drops": [], "next_drop": 1, "vendors": {}, "sold_bulk": {}, "outfit": "dres", "outfits": {}, "gear": {},
		"props": {}, "hide": {"garage": {"items": [], "grow": {}, "jobs": {}, "wet": [], "pots": []}, "basement": {"items": [], "grow": {}, "jobs": {}, "wet": [], "pots": []}},
		"stats": {"earned": 0.0, "sold": 0, "deals": 0, "walked": 0, "escapes": 0, "packed": 0, "wasted": 0, "pickups": 0, "spent": 0.0, "best": 0.0, "grown": 0, "cooked": 0, "raids": 0, "hospital": 0, "box_paid": 0.0},
		"pos": null, "mom_day": 0, "scale": 0, "owned": {},
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
	var f := snappedf(float(g), 0.5)
	if absf(f - round(f)) < 0.05:
		return "%d g" % int(round(f))
	return ("%.1f g" % f).replace(".", ",")


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


## teren: okolica mieszkania i miejsca spotkań klientów, których już masz
func turf() -> Array:
	var out := ["dom"]
	for c in D.CLIENTS:
		if S.cust[c.id].unlocked:
			for sid in c.spots:
				if not out.has(sid):
					out.append(sid)
	return out


## skrytka leży na Twoim terenie (skrytkomaty rządzą się swoimi prawami)
func drop_open(dd: Dictionary, held: Array = []) -> bool:
	if dd.get("locker", false):
		return false
	return (turf() if held.is_empty() else held).has(String(dd.get("turf", "dom")))


func drops_open() -> Array:
	var held := turf()
	var out := []
	for dd in D.DROPS:
		if drop_open(dd, held):
			out.append(String(dd.id))
	return out


## nazwa znaku, którym oznaczona jest skrytka („czaszka”, „liść”…)
func drop_mark(dd: Dictionary) -> String:
	return String(D.DROP_MARKS[int(dd.get("mark", 0)) % D.DROP_MARKS.size()]) if dd.has("mark") else ""


## odległość skrytki od mieszkania (metry)
func drop_dist(dd: Dictionary) -> float:
	return Vector2(float(dd.x) - float(D.DOORS.safe.x), float(dd.z) - float(D.DOORS.safe.z)).length()


## losuje wolną skrytkę z terenu; im dalej sięga teren, tym częściej wypada dalsza
func drop_pick(used: Array = []) -> String:
	var held := turf()
	var opts := []
	var far := 1.0
	for dd in D.DROPS:
		if drop_open(dd, held):
			far = maxf(far, drop_dist(dd))
			if not used.has(String(dd.id)):
				opts.append(dd)
	if opts.is_empty():
		return ""
	var w := []
	var total := 0.0
	for dd in opts:
		var k: float = 0.35 + pow(drop_dist(dd) / far, 2.0) * 1.65
		w.append(k)
		total += k
	var r := randf() * total
	for i in range(opts.size()):
		r -= float(w[i])
		if r <= 0.0:
			return String(opts[i].id)
	return String(opts.back().id)


func notify(text: String, kind := "") -> void:
	toast.emit(text, kind)


## „Pierwszy raz”: duża karta z wyjaśnieniem mechaniki, pokazywana tylko raz na zapis gry.
## Zwraca true, jeśli karta właśnie się pokazała.
func tip(key: String, title: String, text: String, secs := 11.0) -> bool:
	if S.flags.get("tip_" + key, false) or test_hide_hud:
		return false
	S.flags["tip_" + key] = true
	if ui != null:
		ui.tip_show(title, text, secs)
	return true


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


## ================================================================ stroje
func outfit() -> String:
	var o := String(S.get("outfit", "dres"))
	return o if D.OUTFITS.has(o) else "dres"


## cecha aktualnego stroju: "speed", "stamina", "vis", "vis_night", "noise", "attention", "witness", "charm", "cap"
## cecha z ubioru: cały strój (zmienia wygląd) razem z ubraniami założonymi w polach wokół postaci.
## „cap” (kieszenie) się sumuje, pozostałe cechy to mnożniki.
func outfit_stat(key: String, def := 1.0) -> float:
	var v := float(D.OUTFITS[outfit()].get(key, def))
	for slot in S.get("gear", {}):
		var id := String(S.gear[slot])
		if id == "" or not D.ITEMS.has(id):
			continue
		var st: Dictionary = D.ITEMS[id].get("stats", {})
		if st.has(key):
			v = (v + float(st[key])) if key == "cap" else (v * float(st[key]))
	# po szpitalu: obolały szybciej się męczy i wolniej biega
	if hurt():
		if key == "speed":
			v *= 0.93
		elif key == "stamina":
			v *= 0.75
	return v


# ---------------------------------------------------------------- ubrania w polach wokół postaci
func gear(slot: String) -> String:
	var id := String(S.get("gear", {}).get(slot, ""))
	return id if D.ITEMS.has(id) else ""


func is_gear(id: String) -> bool:
	return D.ITEMS.has(id) and D.ITEMS[id].has("slot")


## zakłada ubranie z plecaka; to, co było na tym miejscu, wraca do plecaka
func gear_wear(id: String) -> bool:
	if not is_gear(id) or item(id) <= 0:
		return false
	if not S.has("gear"):
		S["gear"] = {}
	var slot := String(D.ITEMS[id].slot)
	var old := gear(slot)
	S.items[id] = item(id) - 1
	if old != "":
		S.items[old] = item(old) + 1
	S.gear[slot] = id
	Sfx.play("pickup")
	return true


## zdejmuje ubranie do plecaka (jeśli jest w nim miejsce)
func gear_off(slot: String) -> bool:
	var id := gear(slot)
	if id == "":
		return false
	var lost_cap := float(D.ITEMS[id].get("stats", {}).get("cap", 0.0))
	if carry_total() + float(D.ITEMS[id].size) > float(capacity()) - lost_cap + 0.01:
		notify("Nie masz gdzie tego schować — %s pełne." % ("kieszenie" if bag_name() == "Kieszenie" else "plecak"), "warn")
		return false
	S.gear[slot] = ""
	S.items[id] = item(id) + 1
	Sfx.play("pickup")
	return true


func gear_buy(id: String) -> bool:
	if not is_gear(id):
		return false
	var d: Dictionary = D.ITEMS[id]
	if S.cash < float(d.price) or int(S.lvl) < int(d.lvl):
		notify("Nie stać Cię albo to jeszcze nie ten poziom.", "warn")
		return false
	S.cash -= float(d.price)
	S.stats.spent = float(S.stats.spent) + float(d.price)
	# kupione ubranie od razu ląduje na Tobie, jeśli pole jest wolne; inaczej w plecaku
	S.items[id] = item(id) + 1
	if gear(String(d.slot)) == "":
		gear_wear(id)
	Sfx.play("cash")
	return true


## opis cech jak w strojach: [{text, good}]
func stat_traits(o: Dictionary) -> Array:
	var out := []
	var pct := func(v: float) -> String: return "%+d%%" % int(round((v - 1.0) * 100.0))
	for e in [["speed", "szybkość", true], ["stamina", "kondycja", true], ["noise", "hałas kroków", false], ["vis", "widoczność", false], ["vis_night", "widoczność nocą", false],
			["attention", "podejrzliwość patroli", false], ["witness", "świadkowie i śledztwo", false], ["charm", "ceny u klientów", true],
			["conceal", "kontrola przy wejściu", false]]:
		if o.has(e[0]):
			var v := float(o[e[0]])
			out.append({"text": "%s %s" % [e[1], pct.call(v)], "good": (v > 1.0) == bool(e[2])})
	if o.has("cap"):
		out.append({"text": "kieszenie %+d" % int(o.cap), "good": int(o.cap) > 0})
	return out


const STAT_MARKS := [["speed", "gauge", "szybkość", true], ["stamina", "dumbbell", "kondycja", true], ["noise", "footprints", "hałas kroków", false],
	["vis", "eye", "widoczność", false], ["vis_night", "moon", "widoczność nocą", false], ["attention", "siren", "podejrzliwość patroli", false],
	["witness", "fingerprint", "świadkowie i śledztwo", false], ["charm", "hand_coins", "ceny u klientów", true], ["conceal", "scan_eye", "kontrola przy wejściu", false]]

## cechy ubrania jako znaczniki z ikoną: [{icon, text, good, tip}] — np. „+6%” z ikoną stóp i kolorem zależnym od tego, czy to zaleta
func stat_marks(o: Dictionary) -> Array:
	var out := []
	for e in STAT_MARKS:
		if o.has(e[0]):
			var v := float(o[e[0]])
			var txt := "%+d%%" % int(round((v - 1.0) * 100.0))
			out.append({"icon": e[1], "text": txt, "good": (v > 1.0) == bool(e[3]), "tip": "%s %s" % [e[2], txt]})
	if o.has("cap"):
		out.append({"icon": "backpack", "text": "%+d" % int(o.cap), "good": int(o.cap) > 0, "tip": "kieszenie %+d" % int(o.cap)})
	return out


## łączne cechy tego, co masz na sobie (strój + ubrania)
func worn_traits() -> Array:
	var tot := {}
	for key in ["speed", "stamina", "noise", "vis", "vis_night", "attention", "witness", "charm", "conceal"]:
		var v := outfit_stat(key, 1.0)
		if absf(v - 1.0) > 0.004:
			tot[key] = v
	var c := int(outfit_stat("cap", 0.0))
	if c != 0:
		tot["cap"] = c
	return stat_traits(tot)


func outfit_masked() -> bool:
	return bool(D.OUTFITS[outfit()].get("masked", false)) or gear("glowa") == "kominiarka"


func outfit_owned(id: String) -> bool:
	return id == "dres" or bool(S.get("outfits", {}).get(id, false))


## czy tu można się przebrać (sklep z ubraniami albo dowolna kryjówka)
func can_change_here() -> bool:
	if player == null:
		return true
	var loc: String = player.loc
	return loc == "ciuchy" or loc == "safe" or ((loc == "garage" or loc == "basement") and room_owned(loc))


func outfit_buy(id: String) -> bool:
	if not D.OUTFITS.has(id) or outfit_owned(id):
		return false
	var o: Dictionary = D.OUTFITS[id]
	if S.cash < float(o.price) or int(S.lvl) < int(o.lvl):
		notify("Nie stać Cię albo to jeszcze nie ten poziom.", "warn")
		return false
	S.cash -= float(o.price)
	S.stats.spent = float(S.stats.spent) + float(o.price)
	if not S.has("outfits"):
		S["outfits"] = {}
	S.outfits[id] = true
	Sfx.play("cash")
	outfit_wear(id)
	return true


func outfit_wear(id: String) -> bool:
	if not outfit_owned(id) or not D.OUTFITS.has(id):
		return false
	S["outfit"] = id
	# zmiana kieszeni może sprawić, że coś się nie mieści — nic nie znika, po prostu trzeba odłożyć
	if player != null:
		player.stamina = minf(player.stamina, player.max_stamina())
	notify("Masz na sobie: %s." % String(D.OUTFITS[id].name), "good")
	Sfx.play("pickup")
	return true


## opis zalet i wad stroju jako lista {text, good}
func outfit_traits(id: String) -> Array:
	var o: Dictionary = D.OUTFITS[id]
	var out := []
	var pct := func(v: float) -> String: return "%+d%%" % int(round((v - 1.0) * 100.0))
	if o.has("speed"):
		out.append({"text": "szybkość " + pct.call(float(o.speed)), "good": float(o.speed) > 1.0})
	if o.has("stamina"):
		out.append({"text": "kondycja " + pct.call(float(o.stamina)), "good": float(o.stamina) > 1.0})
	if o.has("noise"):
		out.append({"text": "hałas kroków " + pct.call(float(o.noise)), "good": float(o.noise) < 1.0})
	if o.has("vis"):
		out.append({"text": "widoczność " + pct.call(float(o.vis)), "good": float(o.vis) < 1.0})
	if o.has("vis_night"):
		out.append({"text": "widoczność nocą " + pct.call(float(o.vis_night)), "good": float(o.vis_night) < 1.0})
	if o.has("attention"):
		out.append({"text": "podejrzliwość patroli " + pct.call(float(o.attention)), "good": float(o.attention) < 1.0})
	if o.has("witness"):
		out.append({"text": "świadkowie i śledztwo " + pct.call(float(o.witness)), "good": float(o.witness) < 1.0})
	if o.has("charm"):
		out.append({"text": "ceny u klientów " + pct.call(float(o.charm)), "good": float(o.charm) > 1.0})
	if o.has("cap"):
		out.append({"text": "kieszenie %+d" % int(o.cap), "good": int(o.cap) > 0})
	if o.get("masked", false):
		out.append({"text": "zamaskowany: patrol reaguje zawsze", "good": false})
	return out


# ================================================================ towar i ekwipunek
## Czystość zapisujemy w krokach co 5%. Mieszanki (towar rozrobiony wypełniaczem) mają końcówkę 2 albo 7
## (np. 62%, 67%) — dzięki temu NIGDY nie układają się w jeden stos z czystym towarem o podobnej mocy.
static func qpur(pur) -> int:
	var v := int(round(float(pur)))
	if v % 5 == 2:
		return clampi(v, 7, 97)
	return clampi(int(round(float(pur) / 5.0)) * 5, 5, 100)


## czystość towaru prosto od dostawcy albo z własnej produkcji (zawsze „czysty” krok)
static func qpure(pur) -> int:
	return clampi(int(round(float(pur) / 5.0)) * 5, 5, 100)


## czystość mieszanki (z zachowaniem znacznika)
static func qmix(pur) -> int:
	return clampi(int(round((float(pur) - 2.0) / 5.0)) * 5 + 2, 7, 97)


static func is_mix(pur) -> bool:
	return int(round(float(pur))) % 5 == 2


static func tier(pur) -> int:
	var p := float(pur)
	var t := 0
	for i in range(4):
		if p >= float(D.TIER_MIN[i]):
			t = i
	return t


static func tier_name(pur) -> String:
	return D.TIER_NAMES[tier(pur)]


## dawniej czystość zmieniała cenę; teraz cena jest jedna, a słabszy towar klient może po prostu odrzucić
static func price_factor(_pur) -> float:
	return 1.0


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
			n += half_up(float(its[id]) * float(D.ITEMS[id].size))
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
	var f := half_up(float(v))
	if absf(f - round(f)) < 0.05:
		return str(int(round(f)))
	return ("%.1f" % f).replace(".", ",")


## zaokrąglenie w górę do połówki: miejsce w plecaku liczymy „1, 1,5, 2…”, bez ułamków typu 0,7
static func half_up(v: float) -> float:
	return ceil(v * 2.0 - 0.0001) / 2.0


func weight_text(g: float) -> String:
	if g >= 1000.0:
		return ("%.2f kg" % (g / 1000.0)).replace(".", ",")
	if g < 50.0 and absf(g * 2.0 - round(g * 2.0)) < 0.05 and absf(g - round(g)) > 0.2:
		return ("%.1f g" % g).replace(".", ",")
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
				"sub": ("gotowe porcje" if kind == "pack" else ("cegła" if float(s.n) >= 100.0 else "luzem")),
				"icon": ("pack_" if kind == "pack" else ("brick_" if float(s.n) >= 100.0 else "bulk_")) + String(s.p), "tier": tier(s.pur),
				"qty": ("%d szt." % int(s.n)) if kind == "pack" else grams(s.n), "usize": us, "uw": uw, "step": 1.0 if kind == "pack" else 0.5,
				"unit": "szt." if kind == "pack" else "g", "size": half_up(float(s.n) * us), "weight": float(s.n) * uw,
				"desc": ("Zaporcjowany towar gotowy do sprzedaży." if kind == "pack" else "Towar luzem. Zanim sprzedasz, zaporcjuj go na stole z wagą.")})
	var its := store_items(st)
	for id in D.ITEMS:
		var n := int(its.get(id, 0))
		if n <= 0:
			continue
		var d: Dictionary = D.ITEMS[id]
		out.append({"kind": "item", "p": "", "pur": 0, "id": id, "n": float(n), "name": d.name, "sub": "ubranie" if d.has("slot") else "", "icon": d.icon, "tier": -1,
			"qty": "%d %s" % [n, d.unit], "usize": float(d.size), "uw": float(d.w), "step": 1.0, "unit": d.unit,
			"size": half_up(n * float(d.size)), "weight": n * float(d.w), "desc": d.desc})
	# gotówka to też przedmiot: nic nie waży, nie zajmuje miejsca, przenosi się jak wszystko inne
	var money_n := float(S.cash) if is_same(st, S.inv) else float(st.get("cash", 0.0))
	if money_n >= 1.0:
		out.append({"kind": "cash", "p": "", "pur": 0, "id": "cash", "n": floorf(money_n), "name": "Gotówka", "sub": "nic nie waży", "icon": "cash", "tier": -1,
			"qty": money(money_n), "usize": 0.0, "uw": 0.0, "step": 1.0, "unit": "zł", "size": 0.0, "weight": 0.0,
			"desc": "Banknoty. Nie zajmują miejsca w plecaku. Na komendzie stracisz z nich grzywnę, w szpitalu 20–70%%. Powyżej %s przy sobie policja uzna Cię za hurtownika i zacznie węszyć po kryjówkach — nadwyżkę trzymaj w skrytce." % money(big_cash())})
	return out


## przenosi pozycję między plecakiem a skrytką; zwraca przeniesioną ilość
func move_entry(room: String, e: Dictionary, to_stash: bool, amount: float) -> float:
	if e.kind == "cash":
		var before := float(S.cash)
		move_cash(room, to_stash, amount)
		return absf(float(S.cash) - before)
	if e.kind != "item":
		return move_stack(room, to_stash, e.kind, e.p, int(e.pur), amount)
	var from: Dictionary = store_items(S.inv if to_stash else S.stash[room])
	var to: Dictionary = store_items(S.stash[room] if to_stash else S.inv)
	var id: String = e.id
	var n: int = mini(mini(int(amount), int(from.get(id, 0))), int(move_limit(room, e, to_stash)))
	if n <= 0:
		notify("Brak miejsca w %s." % ("skrytce" if to_stash else "plecaku"), "warn")
		return 0.0
	from[id] = int(from.get(id, 0)) - n
	to[id] = int(to.get(id, 0)) + n
	return float(n)


## ile najwięcej tej pozycji da się przenieść (ogranicza wolne miejsce po drugiej stronie)
func move_limit(room: String, e: Dictionary, to_stash: bool) -> float:
	if e.kind == "cash":
		return float(e.n)
	if room == "wiktor" and to_stash:
		# skrzynka Wiktora jest tylko na pieniądze
		return 0.0
	if room == "loot" and to_stash and String(loot.get("kind", "")) != "ground":
		# z paczki i ze skrytki Wiktora tylko się wyjmuje; odkładać można jedynie na ziemię
		return 0.0
	var space: float = (float(stash_cap(room)) - store_total(S.stash[room])) if to_stash else (float(capacity()) - carry_total())
	var step: float = e.get("step", 1.0)
	var fit := floorf(maxf(0.0, space) / maxf(0.001, float(e.usize)) / step + 0.001) * step
	if e.kind == "item":
		# dokładanie do istniejącego stosu może nie zająć nowej połówki miejsca
		var its := store_items(S.stash[room] if to_stash else S.inv)
		var have := float(its.get(e.id, 0))
		var slack := half_up(have * float(e.usize)) - have * float(e.usize)
		fit = floorf((maxf(0.0, space) + slack) / maxf(0.001, float(e.usize)) + 0.001)
	return minf(float(e.n), fit)


## wyrzuca pozycję z plecaka (bezpowrotnie)
## wyrzucenie z plecaka: rzecz ląduje na ziemi u Twoich stóp i leży tam, dopóki jej ktoś nie podniesie
func discard_entry(e: Dictionary, amount: float) -> void:
	if e.kind == "cash":
		return
	if e.kind == "pack":
		take_pack(S.inv, e.p, int(e.pur), int(amount))
	elif e.kind == "bulk":
		take_bulk(S.inv, e.p, int(e.pur), amount)
	else:
		S.items[e.id] = maxi(0, item(e.id) - int(amount))
	if player != null:
		var f: Vector2 = player.forward()
		var pp: Vector3 = player.global_position
		ground_add(String(player.loc), pp.x + f.x * 0.7, pp.z + f.y * 0.7, {"kind": String(e.kind), "p": String(e.p), "pur": int(e.pur), "id": String(e.id), "n": amount, "name": String(e.name)})
	notify("Upuszczono na ziemię: %s." % e.name, "warn")


# ================================================================ pojemnik „z ręki”: paczka, skrytka Wiktora, rzeczy na ziemi
## Jedno naciśnięcie [E] otwiera ekwipunek, a po prawej widać, co leży w środku — przeciągasz do siebie to, co chcesz.
## Na czas oglądania zawartość siedzi w S.stash.loot; przy zamknięciu to, co zostało, wraca tam, skąd przyszło
## (paczka spod drzwi i rzeczy z ziemi — na ziemię, towar Wiktora — do jego skrytki, płacisz tylko za to, co wziąłeś).
var loot := {}


func loot_store() -> Dictionary:
	if not S.stash.has("loot"):
		S.stash["loot"] = new_store()
	return S.stash.loot


func _loot_put(rec: Dictionary) -> void:
	var st := loot_store()
	var n := float(rec.n)
	match String(rec.kind):
		"cash": st.cash = float(st.cash) + n
		"pack": add_pack(st, String(rec.p), int(rec.pur), int(n))
		"bulk": add_bulk(st, String(rec.p), int(rec.pur), n)
		_:
			if D.ITEMS.has(String(rec.id)):
				var its := store_items(st)
				its[String(rec.id)] = int(its.get(String(rec.id), 0)) + int(n)


## otwiera pojemnik: {kind: "starter"} / {kind: "drop", d} / {kind: "ground", rec}
func loot_open(src: Dictionary) -> bool:
	if not loot.is_empty():
		loot_close()
	S.stash["loot"] = new_store()
	var kind := String(src.get("kind", ""))
	match kind:
		"starter":
			if flag("got_first"):
				return false
			for e in D.STARTER_PACK:
				add_bulk(loot_store(), String(e[0]), D.PURITY_STD, float(e[1]))
			loot = {"kind": kind, "title": "PACZKA OD WIKTORA", "note": "pierwsza za darmo",
				"empty": "Paczka jest pusta.", "hint": "Przeciągnij towar z paczki (po prawej) do swoich kieszeni (po lewej)."}
		"drop":
			var d: Dictionary = src.d
			for it in d.get("items", [{"p": d.p, "g": d.g}]):
				add_bulk(loot_store(), String(it.p), int(d.get("pur", D.PURITY_STD)), float(it.g))
			loot = {"kind": kind, "d": d, "title": "SKRYTKA — TOWAR OD WIKTORA", "note": "na zeszyt: %s" % money(float(d.cost)),
				"empty": "Skrytka jest pusta.", "hint": "Przeciągnij towar ze skrytki do plecaka. Na zeszyt idzie tylko to, co zabierzesz — reszta poczeka w skrytce."}
		"ground":
			var rec: Dictionary = src.rec
			var loc := String(rec.loc)
			var x := float(rec.x)
			var z := float(rec.z)
			for r in S.get("ground", []).duplicate():
				if String(r.loc) == loc and Vector2(float(r.x) - x, float(r.z) - z).length() <= 1.6:
					_loot_put(r)
					S.ground.erase(r)
			loot = {"kind": kind, "loc": loc, "x": x, "z": z, "title": "NA ZIEMI", "note": "",
				"empty": "Nic tu już nie leży. Możesz coś odłożyć: przeciągnij rzecz z plecaka.", "hint": "Przeciągnij rzecz z ziemi do plecaka — albo z plecaka na ziemię, jeśli chcesz ją tu zostawić."}
			if world != null:
				world.refresh_ground()
		_:
			return false
	loot["total"] = goods_total(loot_store())
	loot["value"] = _loot_value()
	return true


## hurtowa wartość towaru w pojemniku (do rozliczenia części paczki: droższy towar waży w rachunku więcej)
func _loot_value() -> float:
	var v := 0.0
	for sx in stacks(loot_store(), "bulk"):
		v += float(sx.n) * float(D.PRODUCTS[sx.p].cost)
	return v


## przenosi do plecaka wszystko, co się zmieści; zwraca, ile pozycji ruszyło
func loot_take_all() -> int:
	var moved := 0
	for e in entries(loot_store()):
		var lim := move_limit("loot", e, false)
		if lim > 0.0 and move_entry("loot", e, false, lim) > 0.0:
			moved += 1
	return moved


## to, co zostało w pojemniku, jako rekordy „na ziemię”
func _loot_left() -> Array:
	var out := []
	var st := loot_store()
	for kind in ["pack", "bulk"]:
		for sx in stacks(st, kind):
			out.append({"kind": kind, "p": String(sx.p), "pur": int(sx.pur), "id": "", "n": float(sx.n), "name": String(D.PRODUCTS[sx.p].name)})
	var its := store_items(st)
	for id in its:
		if int(its[id]) > 0 and D.ITEMS.has(id):
			out.append({"kind": "item", "p": "", "pur": 0, "id": String(id), "n": float(its[id]), "name": String(D.ITEMS[id].name)})
	if float(st.get("cash", 0.0)) >= 1.0:
		out.append({"kind": "cash", "p": "", "pur": 0, "id": "cash", "n": floorf(float(st.cash)), "name": "Gotówka"})
	return out


## zamknięcie pojemnika: rozlicza, co zabrano, i odkłada resztę na miejsce
func loot_close() -> void:
	if loot.is_empty():
		return
	var L: Dictionary = loot
	loot = {}
	var left: Array = _loot_left()
	var left_g: float = goods_total(loot_store())
	var left_v: float = _loot_value()
	var taken: float = maxf(0.0, float(L.get("total", 0.0)) - left_g)
	match String(L.kind):
		"starter":
			if taken > 0.01:
				S.flags["got_first"] = true
				S.stats.pickups = int(S.stats.pickups) + 1
				add_xp(6.0)
				# czego nie wziąłeś, zostaje na wycieraczce jako zwykłe rzeczy na ziemi
				if not left.is_empty() and D.ROOMS.has("safe"):
					var R: Dictionary = D.ROOMS.safe
					for i in range(left.size()):
						ground_add("safe", float(R.cx) - 0.04 + 0.16 * i, float(R.d) * 0.5 - 0.62, left[i])
					notify("Paczka od Wiktora: wziąłeś %s, reszta leży przy drzwiach. Ta pierwsza jest za darmo." % grams(taken), "good")
				else:
					notify("Paczka od Wiktora: %s czystego towaru. Ta pierwsza jest za darmo." % grams(taken), "good")
				Sfx.play("pickup")
				if world != null:
					world.refresh_starter()
				nav_dirty.emit()
		"drop":
			var d: Dictionary = L.d
			var total_v: float = maxf(0.001, float(L.get("value", 0.0)))
			if taken > 0.01 and S.drops.has(d):
				var part: float = round(float(d.cost) * (total_v - left_v) / total_v)
				if left_g <= 0.01:
					part = float(d.cost)
				_credit_add(part)
				S.flags["got_first"] = true
				if not d.get("touched", false):
					d["touched"] = true
					S.stats.pickups = int(S.stats.pickups) + 1
					add_xp(6.0)
				Sfx.play("pickup")
				if left_g <= 0.01:
					S.drops.erase(d)
					notify("Zabrano całą paczkę (czysty towar). Na zeszycie: %s, termin: dzień %d." % [money(S.credit), int(float(S.credit_due) / 1440.0) + 1], "good")
					Market.add_trust("wiktor", 3.0 + float(d.g) / 12.0)
					if main != null:
						main.drop_gone(d)
					if S.track is String and S.track == "drop":
						S.track = null
				else:
					# reszta czeka w skrytce: paczka robi się mniejsza i tańsza o to, co już wziąłeś
					var items := []
					for sx in stacks(loot_store(), "bulk"):
						items.append({"p": String(sx.p), "g": float(sx.n)})
					d["items"] = items
					d["p"] = String(items[0].p)
					d["g"] = left_g
					d["cost"] = maxf(0.0, float(d.cost) - part)
					notify("Wziąłeś %s (na zeszyt +%s). W skrytce czeka jeszcze %s." % [grams(taken), money(part), grams(left_g)], "good")
				nav_dirty.emit()
		"ground":
			for i in range(left.size()):
				var a := float(i) * 2.4
				var rr := 0.0 if left.size() == 1 else 0.22
				ground_add(String(L.loc), float(L.x) + cos(a) * rr, float(L.z) + sin(a) * rr, left[i])
			if left.is_empty() and world != null:
				world.refresh_ground()
	S.stash["loot"] = new_store()


# ================================================================ rzeczy na ziemi, śmietniki, lombard
func ground_add(loc: String, x: float, z: float, rec: Dictionary, found := false) -> void:
	if not S.has("ground"):
		S["ground"] = []
	rec["loc"] = loc
	rec["x"] = x
	rec["z"] = z
	rec["found"] = found
	S.ground.append(rec)
	if world != null:
		world.refresh_ground()


## podniesienie rzeczy z ziemi; zwraca false, gdy nie ma na nią miejsca
func ground_take(rec: Dictionary) -> bool:
	var n := float(rec.n)
	match String(rec.kind):
		"cash":
			S.cash += n
		"pack":
			if float(capacity()) - carry_total() < n * D.SIZE_PACK - 0.01:
				notify("Brak miejsca w plecaku.", "warn")
				return false
			add_pack(S.inv, String(rec.p), int(rec.pur), int(n))
		"bulk":
			if float(capacity()) - carry_total() < n * D.SIZE_BULK - 0.01:
				notify("Brak miejsca w plecaku.", "warn")
				return false
			add_bulk(S.inv, String(rec.p), int(rec.pur), n)
		_:
			var id := String(rec.id)
			if not D.ITEMS.has(id):
				S.ground.erase(rec)
				return false
			if float(capacity()) - carry_total() < float(D.ITEMS[id].size) * n - 0.01:
				notify("Brak miejsca w plecaku.", "warn")
				return false
			S.items[id] = item(id) + int(n)
	S.ground.erase(rec)
	Sfx.play("good")
	notify("Podniesiono: %s." % ground_name(rec), "good")
	if world != null:
		world.refresh_ground()
	return true


func ground_name(rec: Dictionary) -> String:
	var n := float(rec.n)
	match String(rec.kind):
		"cash": return money(n)
		"pack": return "%s — %d szt." % [String(D.PRODUCTS[rec.p].name), int(n)]
		"bulk": return "%s — %s" % [String(D.PRODUCTS[rec.p].name), grams(n)]
	var id := String(rec.id)
	var nm := String(D.ITEMS[id].name) if D.ITEMS.has(id) else "coś"
	return nm if n <= 1.0 else "%s × %d" % [nm, int(n)]


## jedno losowanie z tabeli znalezisk: {} = nic, {"cash": n} albo {"id": …, "n": …}
func loot_roll(source: String, r: RandomNumberGenerator = null) -> Dictionary:
	var tab: Array = D.LOOT_CLOTHES if source == "clothes" else D.LOOT.get(source, [])
	var total := 0.0
	for e in tab:
		total += float(e[3])
	var x := (r.randf() if r != null else randf()) * total
	for e in tab:
		x -= float(e[3])
		if x <= 0.0:
			if String(e[0]) == "":
				return {}
			var n := (r.randi_range(int(e[1]), int(e[2])) if r != null else randi_range(int(e[1]), int(e[2])))
			return {"cash": n} if String(e[0]) == "cash" else {"id": String(e[0]), "n": n}
	return {}


## czy ten śmietnik był już dziś przeszukany
func bin_used(id: String) -> bool:
	return int(S.get("bins", {}).get(id, -1)) == day()


## przeszukanie śmietnika: zwraca listę opisów tego, co wpadło w ręce (pusta = same śmieci). Raz na dobę na każdy śmietnik.
func bin_search(id: String, source := "bin", r: RandomNumberGenerator = null) -> Array:
	if not S.has("bins"):
		S["bins"] = {}
	if bin_used(id):
		return []
	S.bins[id] = day()
	add_minutes(D.BIN_MINUTES)
	var out := []
	for k in range(int(D.BIN_ROLLS.get(source, 1))):
		var l := loot_roll(source, r)
		if l.is_empty():
			continue
		if l.has("cash"):
			S.cash += float(l.cash)
			out.append(money(l.cash))
			continue
		var id2 := String(l.id)
		var rec := {"kind": "item", "p": "", "pur": 0, "id": id2, "n": float(l.n), "name": String(D.ITEMS[id2].name)}
		if float(capacity()) - carry_total() >= float(D.ITEMS[id2].size) * float(l.n) - 0.01:
			S.items[id2] = item(id2) + int(l.n)
			out.append(ground_name(rec))
		elif player != null:
			# nie mieści się w plecaku: zostaje na ziemi obok śmietnika
			var pp: Vector3 = player.global_position
			ground_add(String(player.loc), pp.x + randf_range(-0.5, 0.5), pp.z + randf_range(-0.5, 0.5), rec, true)
			out.append(ground_name(rec) + " (leży obok — brak miejsca)")
	S.stats["found"] = int(S.stats.get("found", 0)) + out.size()
	return out


## cena skupu w lombardzie: waha się z dnia na dzień, każda rzecz po swojemu
func pawn_price(id: String) -> float:
	if not D.ITEMS.has(id) or not D.ITEMS[id].has("pawn"):
		return 0.0
	var h := float(absi(("%s|%d" % [id, day()]).hash()) % 1000) / 1000.0
	return maxf(1.0, round(float(D.ITEMS[id].pawn) * (1.0 + (h * 2.0 - 1.0) * D.PAWN_SWING)))


func pawn_open() -> bool:
	var h := hour()
	return h >= float(D.PAWN_OPEN[0]) and h < float(D.PAWN_OPEN[1])


## co z plecaka weźmie lombard: [{id, n, price, total}]
func pawn_list() -> Array:
	var out := []
	for id in D.ITEMS:
		if D.ITEMS[id].has("pawn") and item(id) > 0:
			out.append({"id": id, "n": item(id), "price": pawn_price(id), "total": pawn_price(id) * float(item(id))})
	return out


func pawn_sell(id: String) -> float:
	var n := item(id)
	if n <= 0 or pawn_price(id) <= 0.0:
		return 0.0
	var got := pawn_price(id) * float(n)
	S.items[id] = 0
	S.cash += got
	S.stats["earned"] = float(S.stats.get("earned", 0.0)) + got
	return got


func pawn_sell_all() -> float:
	var got := 0.0
	for e in pawn_list():
		got += pawn_sell(String(e.id))
	return got


## co rano na mieście leży kilka nowych znalezisk (wczorajszych nikt nie pilnuje)
func loot_spawn(r: RandomNumberGenerator = null) -> int:
	if world == null or world.wp.is_empty():
		return 0
	if not S.has("ground"):
		S["ground"] = []
	for rec in S.ground.duplicate():
		if rec.get("found", false):
			S.ground.erase(rec)
	var count := (r.randi_range(int(D.LOOT_DAILY[0]), int(D.LOOT_DAILY[1])) if r != null else randi_range(int(D.LOOT_DAILY[0]), int(D.LOOT_DAILY[1])))
	var made := 0
	for k in range(count * 4):
		if made >= count:
			break
		var w: Dictionary = world.wp[(r.randi() if r != null else randi()) % world.wp.size()]
		var ox := (r.randf_range(-1.6, 1.6) if r != null else randf_range(-1.6, 1.6))
		var oz := (r.randf_range(-1.6, 1.6) if r != null else randf_range(-1.6, 1.6))
		var x: float = float(w.x) + ox
		var z: float = float(w.z) + oz
		if not world.is_free(x, z, 0.5):
			continue
		var l := loot_roll("ground", r)
		if l.is_empty():
			continue
		var rec := {"kind": "cash", "p": "", "pur": 0, "id": "", "n": float(l.cash), "name": "Banknot"} if l.has("cash") else {"kind": "item", "p": "", "pur": 0, "id": String(l.id), "n": float(l.n), "name": String(D.ITEMS[l.id].name)}
		rec["loc"] = "out"
		rec["x"] = x
		rec["z"] = z
		rec["found"] = true
		S.ground.append(rec)
		made += 1
	world.refresh_ground()
	return made



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
			v += float(S.inv.pack[p][k]) * float(D.PRODUCTS[p].base)
	for p in S.inv.bulk:
		for k in S.inv.bulk[p]:
			v += float(S.inv.bulk[p][k]) * float(D.PRODUCTS[p].base) * 0.8
	return v


func capacity() -> int:
	# prolog: sportowa torba na całą ostatnią partię
	if prologue != null:
		return 600
	var extra := int(outfit_stat("cap", 0.0)) + (8 if has_skill("kieszenie") else 0)
	# pojemność plecaków stoi w D.UPGRADES (cap), żeby opis w sklepie i gra zawsze mówiły to samo
	for id in ["plecak2", "plecak1"]:
		if upg(id):
			for u in D.UPGRADES:
				if String(u.id) == id:
					return int(u.cap) + extra
	return maxi(5, D.CAP_BASE + extra)


func upg(id: String) -> bool:
	return bool(S.upg.get(id, false))


func stash_cap(room: String) -> int:
	if room == "lab":
		return 1000
	if room == "wiktor":
		return 100000
	if room == "loot":
		return 0 if loot.is_empty() else 100000
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


## towar luzem liczymy w połówkach grama (1 g, 2,5 g, 10 g…), nigdy 0,7 g
func add_bulk(st: Dictionary, p: String, pur, g: float) -> void:
	g = snappedf(g, 0.5)
	if g <= 0.0:
		return
	var k := str(qpur(pur))
	st.bulk[p][k] = float(st.bulk[p].get(k, 0.0)) + g


func take_bulk(st: Dictionary, p: String, pur, g: float) -> float:
	var k := str(qpur(pur))
	var have := float(st.bulk[p].get(k, 0.0))
	var n: float = minf(have, snappedf(g, 0.5))
	if n <= 0.0:
		return 0.0
	st.bulk[p][k] = snappedf(have - n, 0.5)
	if float(st.bulk[p][k]) < 0.25:
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
	var vd: Dictionary = Market.vendor(cid)
	if not vd.is_empty():
		return String(vd.name)
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
	if cid == "wiktor" and flag("wiktor_sms"):
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
	# w kominiarce nikt Cię nie rozpozna: z tego, co widzieli świadkowie, do akt trafia tylko część
	if n > 0.0:
		n *= outfit_stat("witness", 1.0)
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
	# zamaskowany człowiek na ulicy to podejrzany z definicji — nawet z pustymi kieszeniami
	if outfit_masked():
		m = maxf(m, 0.55)
	return m * outfit_stat("attention", 1.0)


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


## Ilu pieszych patroli krąży po mieście. W pierwszych dniach prawie nikogo — policja nie wie, że istniejesz.
## Potem obecność rośnie z czasem gry, a doraźnie z hałasem (uwaga), śledztwem i porą nocy.
func cop_quota() -> int:
	var d := day()
	var base := 0
	if d >= 3:
		base = 1
	if d >= 8:
		base = 2
	if d >= 16:
		base = 3
	var extra := int(S.heat / 30.0) + (1 if S.invest >= 40.0 else 0)
	if is_night() and d >= 5:
		extra += 1
	if S.wanted:
		return clampi(maxi(2, base + extra), 2, 6)
	return clampi(base + extra, 0, 6)


## radiowóz: w pierwszych dniach przejeżdża rzadko, z czasem coraz częściej
func car_pause() -> float:
	var d := day()
	return 5.0 if d <= 2 else (2.4 if d <= 7 else (1.4 if d <= 15 else 1.0))


func bribe_chance(a: float) -> float:
	return clampf(0.08 + a / 5500.0 - S.invest / 400.0 - (0.1 if carry_value() > 3000.0 else 0.0) + (0.15 if has_skill("uklad") else 0.0), 0.04, 0.9)


func arrest(_cop) -> void:
	if arresting or busy:
		return
	arresting = true
	# patrol nie czeka, aż skończysz pisać SMS-a: otwarte okno się zamyka
	if ui != null:
		ui.interrupt()
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
	var res := arrest_apply()
	var txt := "Zatrzymany (%d/%d)! Konfiskata: %s, grzywna %s." % [int(S.arrests), D.MAX_ARRESTS, loot_text(res), money(res.fine)]
	main.wake_in("komisariat")
	notify(txt, "bad")
	if res.big:
		notify("Tyle gotówki przy sobie? Policja bierze Cię za hurtownika — przez %d dni będą węszyć po Twoich kryjówkach." % int(D.WATCH_DAYS), "bad")
	await get_tree().create_timer(0.7).timeout
	await ui.fade(false)
	busy = false
	arresting = false
	if int(S.arrests) >= D.MAX_ARRESTS:
		main.ending("wyrok")
		return
	main.release_talk(res)


## rozliczenie zatrzymania (bez ekranu): grzywna, konfiskata, śledztwo. Duża gotówka = podejrzenie hurtu i naloty.
func arrest_apply() -> Dictionary:
	var cash0 := float(S.cash)
	var fine: float = minf(S.cash, round(S.cash * 0.35 + 200.0))
	S.cash -= fine
	var res := confiscate()
	res["fine"] = fine
	res["big"] = cash0 >= big_cash()
	S.arrests = int(S.arrests) + 1
	S.heat = 25.0
	S.wanted = false
	Sfx.siren(false)
	if npcs != null:
		npcs.end_chase()
	add_invest(10.0 + (5.0 if res.weapon else 0.0))
	if res.big:
		add_invest(D.CASH_SUSPECT_INVEST)
		S.flags["watch_until"] = S.t + D.WATCH_DAYS * 1440.0
	add_minutes(360.0)
	return res


# ================================================================ telefony od postaci
## czy spełnione są warunki rozmowy (dzień, pora, poziom, zdarzenia)
func call_ready(c: Dictionary) -> bool:
	if flag("call_" + String(c.id)):
		return false
	var h := hour()
	var hr: Array = c.get("hour", [8.0, 23.0])
	if h < float(hr[0]) or h >= float(hr[1]):
		return false
	if day() < int(c.get("day", 0)) or int(S.lvl) < int(c.get("lvl", 0)) or int(S.arrests) < int(c.get("arrests", 0)):
		return false
	if int(S.stats.get("hospital", 0)) < int(c.get("hospital", 0)) or float(S.paid) < float(c.get("paid", 0.0)):
		return false
	return true


## raz na godzinę gry: jeśli ktoś ma powód zadzwonić, a telefon jest wolny — dzwoni
func calls_tick() -> void:
	if test_mode or ui == null or main == null or prologue != null or not running or busy or arresting or S.wanted:
		return
	if not ui.call.is_empty() or ui.mode != "" or mods.get("sleeping", false):
		return
	for c in D.CALLS:
		if call_ready(c):
			S.flags["call_" + String(c.id)] = true
			ui.call_start(String(c.who), c.lines)
			return


# ================================================================ klub, szpital, komenda
## czy pozycja z plecaka jest nielegalna: towar i mieszanki, chemia, nasiona, broń
func is_illegal(e: Dictionary) -> bool:
	if e.kind == "pack" or e.kind == "bulk":
		return true
	return e.kind == "item" and bool(D.ITEMS[e.id].get("illegal", false))


func illegal_entries() -> Array:
	var out := []
	for e in entries(S.inv):
		if is_illegal(e):
			out.append(e)
	return out


## ile miejsca w kieszeniach zajmuje kontrabanda
func illegal_size() -> float:
	var n := 0.0
	for e in illegal_entries():
		n += float(e.size)
	return n


func has_weapon() -> bool:
	for id in D.ITEMS:
		if D.ITEMS[id].get("weapon", false) and int(S.items.get(id, 0)) > 0:
			return true
	return false


## policja zabiera wszystko, co nielegalne. Zwraca {goods: gramy, items: sztuki, weapon}
func confiscate() -> Dictionary:
	var res := {"goods": carry_goods(), "items": 0, "weapon": has_weapon()}
	S.inv.bulk = new_store().bulk
	S.inv.pack = new_store().pack
	for id in D.ITEMS:
		if D.ITEMS[id].get("illegal", false) and int(S.items.get(id, 0)) > 0:
			res.items = int(res.items) + int(S.items[id])
			S.items[id] = 0
	return res


func loot_text(res: Dictionary) -> String:
	var parts := []
	if float(res.goods) > 0.0:
		parts.append(grams(res.goods) + " towaru")
	if int(res.items) > 0:
		parts.append("%d szt. nielegalnych rzeczy" % int(res.items))
	return ", ".join(parts) if not parts.is_empty() else "nic"


## próg gotówki przy sobie, od którego policja widzi w Tobie hurtownika (rośnie z poziomem, czyli z obrotem)
func big_cash() -> float:
	return D.CASH_SUSPECT + D.CASH_SUSPECT_LVL * float(int(S.lvl) - 1)


## czy policja po dużej wpadce węszy po kryjówkach
func watched() -> bool:
	return S.t < float(S.flags.get("watch_until", 0.0))


func hurt() -> bool:
	return S.t < float(S.flags.get("hurt_until", 0.0))


func club_open() -> bool:
	var h := hour()
	return h >= D.CLUB_OPEN or h < D.CLUB_CLOSE


## numer „nocy klubowej” (zmienia się w południe, żeby noc po północy była tą samą nocą)
func club_night() -> int:
	return int(floor((S.t - 720.0) / 1440.0))


## ile razy tej nocy ochroniarz coś przy Tobie znalazł
func club_tries() -> int:
	var c: Dictionary = S.flags.get("club", {})
	return int(c.get("n", 0)) if int(c.get("night", -99)) == club_night() else 0


## szansa, że ochroniarz wymaca kontrabandę. Broń piszczy na bramce zawsze; małą paczkę da się przemycić.
func frisk_chance() -> float:
	var sz := illegal_size()
	if sz <= 0.0:
		return 0.0
	if has_weapon():
		return 1.0
	var c := (0.2 + sz * 0.05) * outfit_stat("conceal", 1.0) * (1.0 + 0.2 * float(club_tries())) * (0.7 if has_skill("kieszenie") else 1.0)
	return clampf(c, 0.12, 0.97)


## kontrola przy wejściu do klubu: {ok, why, found, tries, beaten, chance}
func club_frisk(roll := -1.0) -> Dictionary:
	var res := {"ok": true, "why": "", "found": "", "tries": club_tries(), "beaten": false, "chance": frisk_chance()}
	if outfit_masked():
		res.ok = false
		res.why = "mask"
		return res
	var r := randf() if roll < 0.0 else roll
	if r >= float(res.chance):
		return res
	res.ok = false
	res.why = "found"
	var best = null
	for e in illegal_entries():
		if best == null or (e.kind == "item" and D.ITEMS[e.id].get("weapon", false)) or float(e.size) > float(best.size):
			best = e
			if e.kind == "item" and D.ITEMS[e.id].get("weapon", false):
				break
	res.found = String(best.name) if best != null else "coś"
	var n := club_tries() + 1
	S.flags["club"] = {"night": club_night(), "n": n}
	res.tries = n
	res.beaten = n >= D.CLUB_TRIES
	return res


## ile gotówki z kieszeni znika w szpitalu (20–70 %)
func hospital_loss(roll := -1.0) -> float:
	var r := randf() if roll < 0.0 else roll
	return roundf(float(S.cash) * lerpf(float(D.HOSPITAL_LOSS[0]), float(D.HOSPITAL_LOSS[1]), clampf(r, 0.0, 1.0)))


## rozliczenie pobytu w szpitalu (bez ekranu). reason: "beaten" (ochrona klubu) albo "shot" (policja).
## Pobity: znika część gotówki, towar zostaje w kieszeniach. Postrzelony przez policję: dodatkowo wszystko jak przy zatrzymaniu.
func hospital_apply(reason: String, roll := -1.0) -> Dictionary:
	var res := {"reason": reason, "cash": hospital_loss(roll), "goods": 0.0, "items": 0, "weapon": false, "fine": 0.0, "big": false}
	S.cash -= float(res.cash)
	S.wanted = false
	Sfx.siren(false)
	if npcs != null:
		npcs.end_chase()
	if reason == "shot":
		var cash0 := float(S.cash)
		res.merge(confiscate(), true)
		res.big = cash0 >= big_cash()
		S.arrests = int(S.arrests) + 1
		S.heat = 25.0
		add_invest(12.0 + (5.0 if res.weapon else 0.0))
		if res.big:
			add_invest(D.CASH_SUSPECT_INVEST)
			S.flags["watch_until"] = S.t + D.WATCH_DAYS * 1440.0
		add_minutes(20.0 * 60.0)
		S.flags["hurt_until"] = S.t + 36.0 * 60.0
	else:
		S.heat = maxf(0.0, float(S.heat) - 10.0)
		add_minutes(9.0 * 60.0)
		S.flags["hurt_until"] = S.t + 12.0 * 60.0
	S.flags["club"] = {"night": club_night(), "n": 0}
	S.stats["hospital"] = int(S.stats.get("hospital", 0)) + 1
	return res


## utrata przytomności i pobudka na sali
func hospitalize(reason: String) -> void:
	if busy and not arresting:
		return
	busy = true
	arresting = true
	ui.close_all()
	await main.blackout(reason)
	var res := hospital_apply(reason)
	main.wake_in("szpital")
	await get_tree().create_timer(1.0).timeout
	await ui.fade(false)
	busy = false
	arresting = false
	if reason == "shot" and int(S.arrests) >= D.MAX_ARRESTS:
		main.ending("wyrok")
		return
	main.hospital_talk(res)


## zamówienie, o które właśnie toczy się rozmowa przy otwartym oknie handlu
func order_in_talk(o: Dictionary) -> bool:
	if ui == null or ui.deal.is_empty() or ui.deal.get("over", false):
		return false
	var cur = ui.deal.get("ctx", {}).get("order")
	return cur != null and int(cur.get("id", -1)) == int(o.get("id", -2))


# ================================================================ zdarzenia czasowe
## co 10 minut gry: terminy zamówień i paczki w skrytkach
func on_tick() -> void:
	Prod.tick(10.0)
	Prod.raid_tick()
	Prod.flat_raid_tick()
	for o in S.orders.duplicate():
		var st: Dictionary = S.cust[o.cust]
		# czas płynie także w trakcie rozmowy — klient, z którym właśnie stoisz, nie może w jej połowie zniknąć
		if order_in_talk(o):
			continue
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
			chat("wiktor", "Paczka czeka: %s. Szukaj znaku sprejem: %s. Masz 16 godzin, potem znika." % [Market.spot_name(d), drop_mark(Market.spot(d))])
			if S.track == null:
				S.track = "drop"
			if main != null:
				main.drop_ready(d)
			nav_dirty.emit()
		elif d.state == "ready" and S.t > float(d.expire):
			S.drops.erase(d)
			Market.add_trust("wiktor", -15.0)
			chat("wiktor", "Paczka przepadła. Następnym razem rusz się szybciej — za straty i tak płacisz połowę.")
			_credit_add(float(d.cost) * 0.5)
			add_invest(3.0)
			if main != null:
				main.drop_gone(d)
			nav_dirty.emit()


func on_hour() -> void:
	var h := int(hour())
	calls_tick()
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
			cs2.hunger = clampf(float(cs2.hunger) + 0.012, 0.0, 1.0)
	if h == 8:
		daily_costs()
	# samouczek nie może utknąć: dopóki uczysz się pierwszej sprzedaży, Dominik odzywa się znowu najdalej po 40 minutach
	if String(cur_step().get("id", "")) == "sell1" and S.cust.dominik.unlocked and not _has_order("dominik"):
		S.cust.dominik.next = minf(float(S.cust.dominik.next), S.t + 40.0)
	# pierwszy towar przepadł (rozsypany, skonfiskowany, oddany za bezcen)? Wiktor i tak otwiera Giełdę,
	# żeby dało się odrobić — zeszyt dalej trzeba spłacić
	if flag("got_first") and not flag("hurt_on") and all_goods() < 1.0 and S.drops.is_empty():
		S.flags["hurt_on"] = true
		chat("wiktor", "Słyszę, że zostałeś z niczym. Dobra — pisz do mnie, co ci potrzeba („Zamów towar” pod tą rozmową). Ale to, co wisisz na zeszycie, dalej wisisz.")
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
	loot_spawn()
	Prod.daily()
	for p in S.demand:
		S.demand[p] = snappedf(randf_range(0.94, 1.1), 0.01)
	S.cost_mult = snappedf(randf_range(0.96, 1.06), 0.01)
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
		var pen: float = round(float(S.credit) * 0.06)
		S.credit = float(S.credit) + pen
		if over >= 3:
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


func missed_payment(short: float, why: String) -> void:
	# drobny niedobór (do 12% raty) to jeszcze nie „wpadka”: Wiktor dopisuje brakujące z procentem
	var due := 0.0
	for r in D.DEBT_SCHEDULE:
		if S.paid < float(r.due):
			due = float(r.due)
			break
	if why.begins_with("Rata") and due > 0.0 and short <= due * 0.12:
		S.debt += round(short * 0.25)
		chat("wiktor", "Brakuje %s do raty. Tym razem przymknę oko, ale dopisuję %s. Dopłać dziś." % [money(short), money(round(short * 0.25))])
		notify("Rata prawie pełna — brakujące %s musisz dopłacić." % money(short), "warn")
		return
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
	var m: float = float(D.PRODUCTS[p].base) * float(S.demand[p]) * float(def.wealth)
	m *= 1.0 + minf(100.0, float(st.get("loy", 0.0))) / 100.0 * 0.12
	m *= 0.88 + float(st.get("hunger", 0.4)) * 0.28
	m *= 1.0 - minf(0.12, (g - 1) * 0.008)
	if has_skill("twarda"):
		m *= 1.06
	m *= outfit_stat("charm", 1.0)
	if o.has("mood"):
		m *= 0.94 + float(o.mood) / 100.0 * 0.12
	return m * float(o.get("noise", 1.0)) * float(o.get("boost", 1.0))


func make_order(c: Dictionary, force_g := 0, force_p := "") -> Dictionary:
	var st: Dictionary = S.cust[c.id]
	var product: String = c.prod
	var wants := []
	for p0 in c.get("prods", [c.prod]):
		if int(S.lvl) >= int(D.PRODUCTS[p0].lvl):
			wants.append(p0)
	if not wants.is_empty():
		# ulubiony towar zamawia dwa razy częściej niż drugi
		product = String(wants[0]) if (wants.size() == 1 or randf() < 0.62) else String(wants[randi_range(1, wants.size() - 1)])
	if force_p != "":
		product = force_p
	var g := randi_range(int(c.grams[0]), int(c.grams[1])) + (1 if float(st.loy) >= 40.0 else 0) + (1 if float(st.loy) >= 80.0 else 0) + (1 if has_skill("klientela") else 0)
	if force_g > 0:
		g = force_g
	var spots: Array = []
	for sid in c.spots:
		if sid != "huta" or int(S.lvl) >= 4:
			spots.append(sid)
	var spot := spot_def(spots.pick_random())
	var noise := randf_range(0.94, 1.06)
	var mx := max_price(c, st, product, maxi(int(c.minpur), 60), g, {"noise": noise})
	var stated: int = maxi(5, int(round(mx * float(c.honesty) * randf_range(0.9, 0.98))))
	# klient nie narzuca godziny: będzie na miejscu ok. godzinę po potwierdzeniu
	# (chyba że gracz zaproponuje inną porę — wtedy `fixed` = true)
	var meet: float = default_meet()
	var o := {
		"id": int(S.next_order), "cust": c.id, "product": product, "grams": g, "minpur": int(c.minpur), "spot": spot.id,
		"meet": meet, "fixed": false, "deadline": meet + 60.0, "respond_by": S.t + 180.0, "status": "new",
		"stated": stated, "noise": noise, "agreed": null, "counter": null, "countered": false, "resched": false, "t0": S.t, "text": "",
	}
	S.next_order = int(S.next_order) + 1
	var pn: String = D.PRODUCT_GEN[product]
	var sn: String = spot.name
	var lines := {
		"luzak": ["Siema, ogarniesz %d g %s? Dam %d za gram. %s, za godzinkę?" % [g, pn, stated, sn], "Ej, masz coś? %d g po %d zł. Mogę być za godzinę: %s." % [g, stated, sn]],
		"twardziel": ["%d g. %d za gram. %s. Potwierdź, będę za godzinę." % [g, stated, sn], "Potrzebuję %d g. Daję %d. %s, godzina od twojego „ok”. Nie spóźnij się." % [g, stated, sn]],
		"gadula": ["Dzień dobry, panie kolego! Potrzebowałbym %d g, po %d złotych. Spotkajmy się: %s — będę godzinę po pańskiej odpowiedzi." % [g, stated, sn]],
		"konkret": ["%d g %s, %d zł/g. Miejsce: %s. Czas: godzina od potwierdzenia." % [g, pn, stated, sn]],
		"cwaniak": ["Słuchaj, biorę %d g, ale więcej niż %d za gram nie dam, bo krucho. %s, godzinę po twoim „ok”." % [g, stated, sn]],
		"impulsywny": ["%d g! %d zł/g. %s. Odpisz, to lecę!!" % [g, stated, sn]],
	}
	var opts: Array = lines.get(c.type, lines.luzak)
	o.text = opts.pick_random()
	S.orders.append(o)
	st.next = S.t + next_gap(c, st)
	chat(c.id, o.text)
	return o


## domyślna pora spotkania: ok. godzinę od teraz, zaokrąglona w górę do 5 minut
func default_meet() -> float:
	return ceil((S.t + 58.0) / 5.0) * 5.0


## pora spotkania, jaka wyjdzie po potwierdzeniu zamówienia w tej chwili
func meet_if_accepted(o: Dictionary) -> float:
	if o.get("fixed", false) and float(o.meet) > S.t + 12.0:
		return float(o.meet)
	return default_meet()


func next_gap(c: Dictionary, st: Dictionary) -> float:
	var gap := randf_range(float(c.every[0]), float(c.every[1])) * 60.0
	gap *= 1.0 - minf(100.0, float(st.loy)) / 600.0
	if has_skill("siec"):
		gap *= 0.85
	if has_skill("klientela"):
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
		o.meet = meet_if_accepted(o)
		chat(o.cust, "Pasuje. %d zł za gram, będę o %s." % [int(o.stated), clock(o.meet)], true)
		_accept_order(o, int(o.stated), ["Ok, czekam.", "Dobra. Do zobaczenia.", "Super, będę."].pick_random())
	elif kind == "counterok":
		o.meet = meet_if_accepted(o)
		chat(o.cust, "Niech będzie %d zł za gram." % int(o.counter), true)
		_accept_order(o, o.counter, "Stoi, %d za gram. Czekam o %s." % [int(o.counter), clock(o.meet)])
	elif kind == "price":
		var price := value
		chat(o.cust, "%d zł za gram i jestem." % price, true)
		# przez telefon klient jest mniej skłonny do ustępstw niż twarzą w twarz
		var mx := max_price(def, st, o.product, maxi(int(o.minpur), 60), int(o.grams), {"noise": o.noise}) * 0.94
		if price <= mx:
			o.meet = meet_if_accepted(o)
			_accept_order(o, price, ["Ok, %d za gram. Będę o %s." % [price, clock(o.meet)], "Niech będzie %d. Do zobaczenia o %s." % [price, clock(o.meet)]].pick_random())
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
		var was_new: bool = o.status == "new"
		chat(o.cust, ("Możemy się spotkać o %s?" % clock(meet)) if was_new else ("Możemy o %s zamiast o %s?" % [clock(meet), clock(o.meet)]), true)
		var odds := {"impulsywny": 0.35, "konkret": 0.55, "twardziel": 0.6, "cwaniak": 0.7}
		var p: float = odds.get(def.type, 0.85)
		if o.resched:
			p *= 0.4
		o.resched = true
		if randf() < p:
			o.meet = meet
			o["fixed"] = true
			o.deadline = meet + 60.0
			o.respond_by = maxf(float(o.respond_by), minf(meet - 10.0, S.t + 120.0))
			chat(o.cust, ["Ok, %s." % clock(meet), "Dobra, niech będzie %s." % clock(meet)].pick_random())
			if npcs != null:
				npcs.reschedule(int(o.id))
			nav_dirty.emit()
		else:
			st.sat = maxf(0.0, float(st.sat) - 2.0)
			chat(o.cust, "Nie da rady. Godzinę po twoim „ok” albo wcale." if was_new else ("Nie da rady. O %s albo wcale." % clock(o.meet)))
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
	o.deadline = float(o.meet) + 60.0
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
	var before := drops_open()
	st.unlocked = true
	st.next = S.t + randf_range(1.0, 3.0) * 60.0
	chat(id, text)
	notify("Nowy klient: %s" % cust_def(id).name, "good")
	add_xp(10.0)
	# nowy klient = nowy teren: dostawcy zaczynają zostawiać towar dalej
	var fresh := []
	for sid in drops_open():
		if not before.has(sid):
			fresh.append(String(drop_def(sid).name))
	if not fresh.is_empty():
		if world != null:
			world.refresh_drops()
		if flag("got_first"):
			chat("wiktor", "Kręcisz się już dalej, to i towar będę zostawiał dalej. Nowe skrytki: %s. Każda ma swój mały znak sprejem pod ścianą." % ", ".join(fresh))
			notify("Teren rośnie: %d nowe skrytki." % fresh.size() if fresh.size() > 1 else "Teren rośnie: nowa skrytka.", "good")
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
## cena uliczna za gram — taka sama dla czystego towaru i dla mieszanki
func market_price(p: String, _pur = 100) -> float:
	return float(D.PRODUCTS[p].base) * float(S.demand[p])


## ================================================================ WYMIANA Z RĘKI DO RĘKI
## Sprzedaż bez gadania: wybierasz woreczek, ewentualnie lekko podbijasz albo opuszczasz cenę i PODAJESZ towar
## (przytrzymanie). Świat się nie zatrzymuje — liczy się, kto w tym czasie patrzy.
## Klient ma ukryty próg, o ile da się go podbić (głód, lojalność, portfel, spóźnienie). Stałych klientów znasz,
## więc widzisz, czy podbicie przejdzie; u obcych zgadujesz. Odmowa nie kończy wymiany — wraca cena wyjściowa.
const DEAL_LEVELS := [-10, 0, 5, 10, 15]

## zaczyna wymianę; zwraca {} gdy nie można
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
	var d := {"ctx": ctx, "who": who, "st": st, "product": ctx.product, "want": int(ctx.grams), "qty": int(ctx.grams), "sel": {}, "price": 0, "base": 0, "pct": 0,
		"tol": 0.0, "pushed": false, "hold": 0.0, "speech": "", "over": false, "sold": false, "late": late, "credit": false,
		"cop": null, "cop_t": 0.0, "cop_max": 6.0, "notes": []}
	var best = null
	for s in st_list:
		if s.p != ctx.product:
			continue
		if best == null or (int(s.pur) >= int(who.minpur) and (int(best.pur) < int(who.minpur) or int(s.pur) < int(best.pur))):
			best = s
	if o != null and o.has("hold"):
		d.pushed = bool(o.hold.get("pushed", false))
		d.notes.append("Wróciłeś — klient dalej czeka.")
	d.sel = best if best != null else st_list[0]
	d.qty = clampi(int(d.want), 1, int(d.sel.n))
	d.base = int(ctx.agreed) if ctx.get("agreed") != null else int(round(market_price(d.sel.p)))
	d.price = d.base
	# o ile procent ponad cenę wyjściową klient jeszcze zapłaci
	var tol := 2.0 + float(st.get("hunger", 0.4)) * 10.0 + minf(100.0, float(st.get("loy", 0.0))) / 100.0 * 6.0 + (float(who.get("wealth", 1.0)) - 1.0) * 20.0
	tol += (float(st.get("sat", 55.0)) - 50.0) / 50.0 * 4.0 - late * 0.6 - (3.0 if rain > 0.3 else 0.0)
	if o != null:
		# cena z SMS-a była już blisko jego granicy
		tol -= 3.0
		tol += (float(o.noise) - 1.0) * 60.0
	else:
		tol += randf_range(-3.0, 3.0)
	if has_skill("twarda"):
		tol += 4.0
	tol += (outfit_stat("charm", 1.0) - 1.0) * 40.0
	d.tol = clampf(tol, -12.0, 18.0) if not ctx.get("sting", false) else 99.0
	if ctx.get("sting", false):
		d.speech = "„Dawaj, co masz. Biorę wszystko!”"
	else:
		var hello := {
			"luzak": ["„Siema. Masz?”", "„Elo, dawaj.”"], "twardziel": ["„Jesteś. Dawaj.”", "„No.”"], "gadula": ["„O, pan kolega. To co, do rzeczy?”"],
			"konkret": ["„Dzień dobry. Szybko.”"], "cwaniak": ["„No proszę. Pokaż, co masz.”"], "impulsywny": ["„Wreszcie! Dawaj, dawaj.”"],
		}
		var hl: Array = hello.get(who.get("type", "luzak"), hello.luzak)
		d.speech = hl.pick_random()
		if late > 8.0:
			d.speech = String(d.speech) + " „Ile można czekać?”"
			d.notes.append("Spóźniłeś się — trudniej będzie coś ugrać.")
	if float(st.get("owes", 0.0)) > 0.0:
		if randf() < float(who.get("reliable", 0.8)) + (0.25 if has_weapon() else 0.0):
			S.cash += float(st.owes)
			d.notes.append("Oddał dług: +%s" % money(st.owes))
			st.owes = 0.0
		else:
			d.notes.append("Wciąż wisi Ci %s („następnym razem…”)" % money(st.owes))
	return d


## cena za gram przy danym podbiciu / opuście (w procentach od ceny wyjściowej)
func deal_price_at(d: Dictionary, pct: int) -> int:
	return maxi(1, int(round(float(d.base) * (1.0 + float(pct) / 100.0))))


## ustawia poziom ceny; po jednej odmowie podbić już się nie da
func deal_set(d: Dictionary, pct: int) -> bool:
	if d.over or (pct > 0 and d.pushed):
		return false
	d.pct = pct
	d.price = deal_price_at(d, pct)
	return true


## Co wiesz o szansie przy danej cenie: "sure" | "ok" | "risk" | "no" | "" (nie wiesz — obcy albo mało transakcji).
## Im więcej razy handlowałeś z klientem, tym pewniejsza ocena.
func deal_read(d: Dictionary, pct: int) -> String:
	if pct <= 0 and float(d.tol) >= float(pct):
		return "sure"
	var known := int(d.st.get("deals", 0)) if d.st.has("deals") else 0
	if has_skill("oko1"):
		known += 3
	if known < 3:
		return ""
	var fuzz := 0.0 if known >= 8 else 3.0 * (float(int(float(d.tol) * 37.0) % 7) / 3.0 - 1.0)
	var t: float = float(d.tol) + fuzz
	if float(pct) <= t - 4.0:
		return "sure"
	if float(pct) <= t:
		return "ok"
	if float(pct) <= t + 5.0:
		return "risk"
	return "no"


## ilu ludzi może widzieć wymianę: {witnesses, cop} — na ulicy liczą się przechodnie w pobliżu i patrol, który patrzy
func deal_watchers() -> Dictionary:
	if player == null or npcs == null or player.loc != "out":
		return {"witnesses": 0, "cop": null}
	var pp: Vector3 = player.global_position
	var skip := 1 if (ui != null and ui.deal_npc != null and ui.deal_npc is Dictionary and String(ui.deal_npc.get("kind", "")) == "citizen") else 0
	return {"witnesses": maxi(0, npcs.citizens_near(pp.x, pp.z, 11.0) - skip), "cop": npcs.watcher(22.0)}


## czas przytrzymania przy podawaniu towaru (s)
func deal_hand_time() -> float:
	return 0.8 if has_skill("reka2") else 1.3


## Klient ogląda to, co dostał. Zwraca "" (bierze bez słowa), "meh" (bierze, ale kręci nosem) albo "no" (nie bierze).
## Mieszanka kosztuje tyle samo, co czysty towar — ryzykujesz właśnie tę chwilę.
func deal_quality(d: Dictionary) -> String:
	if d.ctx.get("sting", false):
		return ""
	var who: Dictionary = d.who
	var gap := int(who.minpur) - int(d.sel.pur)
	if gap <= 0:
		return ""
	var experience := clampf(0.35 + float(d.st.get("grams", 0)) / 40.0, 0.0, 1.0)
	if who.has("grams") and int(who.grams[1]) >= 5:
		experience = maxf(experience, 0.7)
	var p := experience * clampf(float(gap) / 18.0, 0.25, 1.0) * (0.7 if has_skill("czysta") else 1.0)
	if randf() >= p:
		return ""
	return "no" if gap >= 14 else "meh"


## PODANIE TOWARU: najpierw klient ocenia towar, potem cenę. Sprzedaż, odmowa ceny (wraca cena wyjściowa) albo koniec.
func deal_hand(d: Dictionary) -> void:
	if d.over:
		return
	d.hold = 0.0
	var who: Dictionary = d.who
	if d.sel.p != d.ctx.product and not d.ctx.get("sting", false):
		d.speech = "„To nie to. Chciałem %s.”" % String(D.PRODUCT_GEN[d.ctx.product])
		return
	var q := deal_quality(d)
	if q == "no":
		d.over = true
		var what: String = D.FILLER_NAMES.get(D.FILLER.get(d.sel.p, ""), "wypełniacz").to_lower()
		d.speech = "„Co to ma być? Czuję tu %s. Tego nie biorę.” — odchodzi." % what
		d.notes.append("Klient rozpoznał mieszankę (%d%%, a oczekuje co najmniej %d%%)." % [int(d.sel.pur), int(who.minpur)])
		if d.st.has("sat"):
			d.st.sat = maxf(0.0, float(d.st.sat) - 10.0)
			d.st.loy = maxf(0.0, float(d.st.get("loy", 0.0)) - 4.0)
			if d.st.has("known"):
				d.st.known["minpur"] = true
		S.stats.walked = int(S.stats.walked) + 1
		if d.ctx.get("order") != null:
			drop_order(d.ctx.order)
		deal_finish(d, {"sold": 0, "rejected": true})
		return
	if float(d.pct) > float(d.tol):
		# za drogo: nie obraża się, ale drugi raz podbić się nie da
		var was := int(d.pct)
		d.pushed = true
		var back := mini(0, int(floor(float(d.tol) / 5.0)) * 5)
		back = maxi(-10, back)
		d.pct = back
		d.price = deal_price_at(d, back)
		if d.st.has("sat"):
			d.st.sat = maxf(0.0, float(d.st.sat) - (3.0 if was >= 15 else 1.5))
		if back < 0:
			d.speech = ["„Spóźniony i jeszcze drożej? %s i ani grosza więcej.”" % money(d.price), "„Nie dziś. %s albo idę.”" % money(d.price)].pick_random()
		else:
			d.speech = ["„Nie przesadzaj. %s, jak było.”" % money(d.price), "„Za drogo. %s albo nic.”" % money(d.price), "„Umawialiśmy się na %s.”" % money(d.price)].pick_random()
		Sfx.play("error")
		return
	var line := "„Stoi.”"
	if q == "meh":
		line = ["„Słabe jakieś… Ostatni raz biorę coś takiego.”", "„Hm. Ostatnio było lepsze.”"].pick_random()
		d.notes.append("Klient wyczuł, że towar jest rozrobiony — jest niezadowolony.")
		if d.st.has("sat"):
			d.st.sat = maxf(0.0, float(d.st.sat) - 7.0)
			d.st.loy = maxf(0.0, float(d.st.get("loy", 0.0)) - 2.0)
			if d.st.has("known"):
				d.st.known["minpur"] = true
	elif int(d.pct) < 0:
		line = ["„O, dzięki. Zapamiętam.”", "„Uczciwie. Wrócę.”"].pick_random()
		if d.st.has("sat"):
			d.st.sat = minf(100.0, float(d.st.sat) + 3.0)
			d.st.loy = minf(100.0, float(d.st.get("loy", 0.0)) + 1.5)
	elif int(d.pct) > 0:
		line = ["„…Niech ci będzie.”", "„Drogo, ale biorę.”"].pick_random()
	deal_sell(d, float(d.price), line)


func deal_sell(d: Dictionary, price: float, line: String) -> void:
	var ref: float = float(d.base) * (1.0 + maxf(0.0, float(d.tol)) / 100.0)
	var res := complete_sale(d.ctx, d.sel.p, int(d.sel.pur), int(d.qty), price, ref, d.credit)
	d.over = true
	d.sold = true
	d.speech = "%s\n[b][color=#4ade80]+%s[/color][/b] za %d g %s." % [line, money(res.paid), int(d.qty), D.PRODUCT_GEN[d.sel.p]]
	deal_finish(d, res)


## stare nazwy — zostają dla testów i narzędzi
func deal_sell_agreed(d: Dictionary) -> void:
	deal_set(d, 0)
	deal_hand(d)


func deal_max(d: Dictionary) -> float:
	return float(d.base) * (1.0 + float(d.tol) / 100.0)


## „Zaraz wracam”: klient zostaje na miejscu i czeka, zamówienie nie przepada.
## Rozmowa zostaje zapamiętana (nastrój trochę siada), więc wyjście nie resetuje targów.
func deal_pause(d: Dictionary) -> void:
	var o = d.ctx.get("order")
	if o == null or d.over:
		deal_leave(d)
		return
	o["hold"] = {"pushed": bool(d.pushed)}
	o.deadline = maxf(float(o.deadline), S.t + 45.0)
	d.over = true
	notify("%s: „Dobra, czekam. Tylko się streszczaj.”" % String(d.who.name))
	deal_finish(d, {"sold": 0, "left": true, "paused": true})


## rezygnacja z transakcji w trakcie rozmowy: zamówienie przepada, klient jest zły
func deal_cancel(d: Dictionary) -> void:
	var o = d.ctx.get("order")
	d.over = true
	deal_finish(d, {"sold": 0, "left": true})
	if o != null and find_order(o.id) != null:
		reply_order(o.id, "decline")


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
	notify("+%s  (%d g %s)" % [money(paid), g, D.PRODUCT_GEN[p]], "good")
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
		# po zakupie klient odzywa się najwcześniej za ok. 5 godzin (spotkania są teraz godzinę
		# po potwierdzeniu, więc bez tej przerwy zamawiałby dużo częściej niż dawniej)
		cs.next = maxf(float(cs.next), S.t + 240.0)
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
func wholesale_unit(p: String, _high := false) -> float:
	return float(D.PRODUCTS[p].cost) * float(S.cost_mult) * (0.92 if has_skill("rabat") else 1.0)


func wholesale_price(p: String, g: int, _high := false) -> float:
	return round(wholesale_unit(p) * g * (1.0 - wholesale_disc(g)))


## rabat za ilość dla zamówienia na `g` gramów jednego towaru (progi: D.WHOLESALE_TIERS)
func wholesale_disc(g: int) -> float:
	for t in D.WHOLESALE_TIERS:
		if g >= int(t[0]):
			return float(t[1])
	return 0.0


func wholesale_max() -> int:
	return int(D.WHOLESALE_MAX[mini(int(S.lvl), D.WHOLESALE_MAX.size() - 1)])


## Ile Wiktor da „na zeszyt”: tyle, żeby starczyło na największą paczkę najdroższego towaru z Twojego poziomu
## (z zapasem). Rośnie z poziomem, bo rosną paczki i towar.
func credit_limit() -> float:
	var top := 0.0
	for p in D.PRODUCTS:
		if int(S.lvl) >= int(D.PRODUCTS[p].lvl):
			top = maxf(top, float(D.PRODUCTS[p].cost) * wholesale_max() * (1.0 - wholesale_disc(wholesale_max())))
	return maxf(float(D.CREDIT_BASE), round(top * 1.35 / 50.0) * 50.0) * (1.5 if has_skill("kredyt") else 1.0)


## termin spłaty zeszytu w dniach — na początku Wiktor jest wyrozumiały
func credit_days() -> int:
	return (D.CREDIT_DAYS_EARLY if int(S.lvl) <= D.CREDIT_EARLY_LVL else D.CREDIT_DAYS) + (2 if has_skill("kredyt") else 0)


func credit_overdue() -> bool:
	return float(S.credit) > 0.0 and S.t > float(S.credit_due)


## za paczki, które jeszcze leżą w skrytkach, też trzeba będzie zapłacić
func drops_owed() -> float:
	var n := 0.0
	for d in S.drops:
		n += float(d.get("cost", 0.0))
	return n


## podpowiedzi „pierwszy raz” zależne od tego, co się właśnie dzieje (wołane co ćwierć sekundy z main._slow)
func tips_tick() -> void:
	if ui == null or player == null or not running or prologue != null:
		return
	if npcs != null and not npcs.aware.is_empty() and player.loc == "out":
		tip("patrol", "Ktoś Cię zauważa", "Łuk przy celowniku pokazuje, z której strony patrzy patrol. Ikona oka przy pasku kondycji mówi, jak bardzo rzucasz się w oczy. Kucnij [%s], zejdź z widoku albo po prostu idź spokojnie — bez towaru i bez biegania policja nie ma powodu Cię zatrzymać." % kn("crouch"))
	if player.tired:
		tip("zadyszka", "Zadyszka", "Pasek kondycji spadł do zera: przez chwilę nie pobiegniesz i idziesz wolniej. Oddech wraca po sekundzie przerwy — najszybciej, gdy stoisz albo kucasz. W pościgu adrenalina pozwala biec dłużej.")
	if night > 0.6 and player.loc == "out":
		tip("noc", "Noc", "Po ciemku trudniej Cię zauważyć, ale snop latarki patrolu odbiera tę przewagę. Własną latarkę włączasz klawiszem [%s] — świeci tylko Tobie pod nogi, nie zdradza Cię bardziej." % kn("flash"))
	if ready_drop() != null and flag("hurt_on"):
		tip("skrytka", "Paczka w skrytce", "Wiktor zostawił towar. Idź do miejsca z wiadomości, znajdź mały biały znak sprejem i naciśnij [%s] — skrytka otworzy się obok plecaka, towar przeciągasz do siebie. Nic nie płacisz na miejscu — należność idzie na zeszyt, a gotówkę zanosisz do skrzynki Wiktora." % kn("use"))
	if carry_total() > float(capacity()) - 0.6 and carry_total() > 3.0:
		tip("pelny", "Pełne kieszenie", "Każdy gram i każdy woreczek zajmuje miejsce. Nadmiar odłóż do szafy w kawalerce albo kup u Stasia plecak. Z dużą ilością towaru kontrola osobista kończy się gorzej.")


func _credit_add(n: float) -> void:
	if n <= 0.0:
		return
	if float(S.credit) <= 0.0 or float(S.credit_due) < S.t:
		S.credit_due = S.t + credit_days() * 1440.0
	S.credit = float(S.credit) + n


## dlaczego nie można zamówić ("" = można) — stare, proste wejście na jedną pozycję
func order_block(p: String, g: int, _on_credit := true, _high := false) -> String:
	return Market.cart_block([{"p": p, "g": g}])


## cały towar gracza: plecak i wszystkie skrytki
func all_goods() -> float:
	var n := goods_total(S.inv)
	for r in S.stash:
		n += goods_total(S.stash[r])
	return n


## deska ratunku: bez towaru, z zaległym zeszytem, Wiktor da 5 g marihuany ćwierć drożej — żeby gra się nie zakleszczyła
func rescue_cart(cart: Array) -> bool:
	return credit_overdue() and cart.size() == 1 and String(cart[0].p) == "dym" and int(cart[0].g) == 5 and all_goods() < 1.0 and S.drops.is_empty()


func rescue_order(p: String, g: int, _on_credit := true, _high := false) -> bool:
	return rescue_cart([{"p": p, "g": g}])


func order_goods(p: String, g: int, _high := false, _on_credit := true) -> bool:
	return not Market.order_cart([{"p": p, "g": g}]).is_empty()


func ready_drop() -> Variant:
	for d in S.drops:
		if d.state == "ready":
			return d
	return null


## dlaczego nie można zabrać paczki ("" = można)
func pickup_block(d: Dictionary) -> String:
	if carry_total() + float(d.g) > float(capacity()) + 0.01:
		return "Za mało miejsca: paczka %d g, wolne %s." % [int(d.g), grams(maxf(0.0, capacity() - carry_total()))]
	return ""


## Zabiera paczkę ze skrytki. Nic nie płacisz na miejscu: należność idzie na zeszyt,
## a gotówkę zanosisz potem do skrzynki Wiktora.
func pickup_drop(d: Dictionary) -> bool:
	var why := pickup_block(d)
	if why != "":
		notify(why, "warn")
		return false
	_credit_add(float(d.cost))
	for it in d.get("items", [{"p": d.p, "g": d.g}]):
		add_bulk(S.inv, String(it.p), int(d.get("pur", D.PURITY_STD)), float(it.g))
	S.drops.erase(d)
	S.stats.pickups = int(S.stats.pickups) + 1
	S.flags["got_first"] = true
	Sfx.play("pickup")
	notify("Zabrano: %s (czysty towar). Na zeszycie: %s, termin: dzień %d." % [Market.contents(d), money(S.credit), int(float(S.credit_due) / 1440.0) + 1], "good")
	Market.add_trust("wiktor", 3.0 + float(d.g) / 12.0)
	if main != null:
		main.drop_gone(d)
	add_xp(6.0)
	if S.track is String and S.track == "drop":
		S.track = null
	nav_dirty.emit()
	return true


## Paczka na start, wsunięta pod drzwi kawalerki: czysta marihuana i amfetamina. Wiktor daje ją za darmo, na rozruch —
## na zeszyt idą dopiero następne zamówienia. (Ile byłaby warta w hurcie — do komunikatów.)
func starter_cost() -> float:
	var n := 0.0
	for e in D.STARTER_PACK:
		n += float(D.PRODUCTS[e[0]].cost) * int(e[1])
	return n


func starter_pickup() -> bool:
	if flag("got_first"):
		return false
	var parts := []
	for e in D.STARTER_PACK:
		add_bulk(S.inv, String(e[0]), D.PURITY_STD, float(e[1]))
		parts.append("%d g %s" % [int(e[1]), String(D.PRODUCT_GEN[e[0]])])
	S.flags["got_first"] = true
	S.stats.pickups = int(S.stats.pickups) + 1
	Sfx.play("pickup")
	notify("Paczka od Wiktora: %s — czysty towar. Ta pierwsza jest za darmo." % " i ".join(parts), "good")
	add_xp(6.0)
	nav_dirty.emit()
	return true


## Skrzynka Wiktora: z gotówki, która w niej leży, schodzi najpierw to, co ma bliższy termin — zeszyt za towar
## albo najbliższa rata długu — potem drugie z nich, a nadwyżka idzie na resztę długu.
## Woła się to przy zamykaniu skrzynki. Zwraca, ile Wiktor zabrał.
func box_settle() -> float:
	var st: Dictionary = S.stash.wiktor
	var have := float(st.cash)
	if have < 1.0:
		return 0.0
	var ni := next_installment()
	var rate: float = maxf(0.0, float(ni.get("due", 0.0)) - S.paid) if (not ni.is_empty() and S.debt > 0.0) else 0.0
	rate = minf(rate, float(S.debt))
	var rate_first: bool = rate > 0.0 and (float(S.credit) <= 0.0 or float(ni.day) * 1440.0 < float(S.credit_due))
	var a := 0.0       # na zeszyt
	var b := 0.0       # na dług
	var left := have
	for step in (["rate", "credit"] if rate_first else ["credit", "rate"]):
		if step == "credit":
			a = minf(left, float(S.credit))
			left -= a
		else:
			b = minf(left, rate)
			left -= b
	# nadwyżka: reszta długu
	var extra: float = minf(left, float(S.debt) - b)
	b += maxf(0.0, extra)
	S.credit = float(S.credit) - a
	S.debt -= b
	S.paid += b
	st.cash = have - a - b
	var took := a + b
	if took <= 0.0:
		return 0.0
	S.stats.spent = float(S.stats.spent) + a
	S.stats["box_paid"] = float(S.stats.get("box_paid", 0.0)) + took
	Sfx.play("cash")
	var parts := []
	if a > 0.0:
		parts.append("%s za towar" % money(a))
	if b > 0.0:
		parts.append("%s na dług" % money(b))
	notify("Skrzynka Wiktora: %s. Zeszyt: %s, dług: %s." % [", ".join(parts), money(S.credit), money(S.debt)], "good")
	chat("wiktor", "Odebrałem %s. Zeszyt: %s. Dług: %s." % [money(took), money(S.credit), money(S.debt)], false, true)
	Market.add_trust("wiktor", took / 400.0)
	if S.debt <= 0.0 and not flag("free"):
		S.flags["free"] = true
		if ui != null:
			ui.close_all()
		get_tree().create_timer(0.4).timeout.connect(func(): main.ending("wolnosc"))
	return took


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


## Cały towar przy stole jako jedna pula — luzem i w porcjach, z plecaka i ze skrytki razem.
## Nie ma znaczenia, jak jest popakowany ani gdzie leży: stół widzi {p, pur, n = gramy luzem, k = gotowe porcje}.
func bench_pool(room: String) -> Array:
	var m := {}
	for src in [S.inv, S.stash[room]]:
		for kind in ["bulk", "pack"]:
			for sx in stacks(src, kind):
				var key := "%s:%d" % [sx.p, int(sx.pur)]
				if not m.has(key):
					m[key] = {"p": sx.p, "pur": int(sx.pur), "n": 0.0, "k": 0}
				if kind == "bulk":
					m[key].n = float(m[key].n) + float(sx.n)
				else:
					m[key].k = int(m[key].k) + int(sx.n)
	return m.values()


## rozsypuje gotowe porcje z powrotem do luzu (żeby je domieszać albo zważyć od nowa); zwraca, ile porcji poszło
func unpack(room: String, p: String, pur: int, n: int) -> int:
	var done := 0
	for src in [S.inv, S.stash[room]]:
		var t: int = take_pack(src, p, pur, n - done)
		if t > 0:
			add_bulk(src, p, pur, float(t))
			done += t
	if done > 0:
		add_minutes(0.1 * done)
	return done


## Porcjowanie zależy tylko od wagi, którą masz (D.SCALES): im lepsza, tym szybciej i z mniejszą stratą.
## Nie ma trybów pracy ani woreczków do kupowania — towar po zważeniu jest po prostu gotowy do sprzedaży.
func scale() -> int:
	return clampi(int(S.get("scale", 0)), 0, D.SCALES.size() - 1)


func scale_def() -> Dictionary:
	return D.SCALES[scale()]


## dlaczego nie da się kupić tej wagi ("" = można)
func scale_block(i: int) -> String:
	if i < 0 or i >= D.SCALES.size():
		return "Nie ma takiej wagi."
	if i <= scale():
		return "Masz już taką albo lepszą."
	var sc: Dictionary = D.SCALES[i]
	if int(S.lvl) < int(sc.lvl):
		return "Od poziomu %d." % int(sc.lvl)
	if S.cash < float(sc.price):
		return "Brakuje %s." % money(float(sc.price) - S.cash)
	return ""


func scale_buy(i: int) -> bool:
	if scale_block(i) != "":
		return false
	var sc: Dictionary = D.SCALES[i]
	S.cash -= float(sc.price)
	S.stats.spent = float(S.stats.spent) + float(sc.price)
	S["scale"] = i
	if world != null:
		world.refresh_scales()
	Sfx.play("good")
	notify("Kupiono: %s. Stoi już na Twoim stole." % String(sc.name), "good")
	return true


func pack_waste(_mode := 1) -> float:
	if int(S.stats.packed) + int(S.stats.wasted) < 5:
		return 0.0
	return float(scale_def().waste) * (0.6 if has_skill("reka") else 1.0)


func pack_minutes(_mode := 1) -> float:
	return float(scale_def().min) * (0.5 if has_skill("paczki") else 1.0)


## ile gramów danego towaru da się teraz zaporcjować przy tym stole (towar z plecaka i ze skrytki liczy się razem)
func pack_limit(room: String, p: String, pur: int) -> int:
	var have := 0.0
	for src in [S.inv, S.stash[room]]:
		have += float(src.bulk[p].get(str(pur), 0.0))
	return int(floor(have + 0.001))


## porcjuje JEDEN gram: 1 = porcja gotowa, 0 = gram rozsypany, -1 = nie ma z czego
func pack_one(room: String, p: String, pur: int, _mode := 1) -> int:
	if pack_limit(room, p, pur) <= 0:
		return -1
	var from_inv: float = take_bulk(S.inv, p, pur, 1.0)
	if from_inv < 0.999:
		take_bulk(S.stash[room], p, pur, 1.0 - from_inv)
	add_minutes(pack_minutes())
	if randf() < pack_waste():
		S.stats.wasted = int(S.stats.wasted) + 1
		# pierwszy rozsypany gram na kuchennej: podpowiedź, gdzie kupić lepszą wagę (raz)
		if scale() == 0 and not flag("tip_waga"):
			S.flags["tip_waga"] = true
			notify("Gram poszedł na blat. Stara waga kuchenna tak ma — dokładniejszą sprzedaje Zenek w lombardzie przy Hutniczej.", "warn")
		return 0
	# porcja wraca tam, skąd wzięto towar (plecak albo skrytka)
	add_pack(S.inv if from_inv >= 0.5 else S.stash[room], p, pur, 1)
	S.stats.packed = int(S.stats.packed) + 1
	add_xp(0.3)
	return 1


## porcjuje `g` gramów naraz (testy, symulacje); przy stole robi to animacja, gram po gramie
func pack(room: String, p: String, pur: int, g: int, _mode := 1) -> Dictionary:
	var good := 0
	var lost := 0
	for i in range(g):
		var r := pack_one(room, p, pur)
		if r < 0:
			break
		if r == 1:
			good += 1
		else:
			lost += 1
	if good + lost > 0:
		pack_report(good, lost)
	return {"packed": good, "lost": lost}


func pack_report(good: int, lost: int) -> void:
	if lost > 0:
		notify("Zaporcjowano %d g, rozsypano %d g." % [good, lost], "warn")
	elif good > 0:
		notify("Zaporcjowano %d g bez strat." % good, "good")


func filler_for(p: String) -> String:
	return D.FILLER.get(p, "majeranek")


## rozrabia towar dodatkiem ze sklepu (majeranek, cukier puder); zwraca nową czystość
func mix(room: String, p: String, pur: int, g: float, filler_g: int) -> int:
	var fid := filler_for(p)
	if filler_g <= 0 or item_at(room, fid) < filler_g:
		return pur
	# pula jest wspólna: jeśli luzem jest za mało, do mieszanki idą też gotowe porcje
	var loose := 0.0
	for src in [S.inv, S.stash[room]]:
		loose += float(src.bulk[p].get(str(pur), 0.0))
	if loose < g - 0.001:
		unpack(room, p, pur, int(ceil(g - loose - 0.001)))
	var from_inv: float = take_bulk(S.inv, p, pur, g)
	var from_stash: float = take_bulk(S.stash[room], p, pur, g - from_inv)
	var tot := from_inv + from_stash
	if tot <= 0.0:
		return pur
	var eff := float(filler_g) * (0.8 if has_skill("mieszanie") else 1.0)
	var np := qmix(float(pur) * tot / (tot + eff))
	var share := from_inv / tot
	take_item(room, fid, filler_g)
	var inv_room := maxf(0.0, float(capacity()) - carry_total())
	var to_inv: float = minf(snappedf((tot + filler_g) * share, 0.5), floorf(inv_room * 2.0) / 2.0)
	add_bulk(S.inv, p, np, to_inv)
	add_bulk(S.stash[room], p, np, tot + filler_g - to_inv)
	notify("Mieszanka: %s → %s, czystość %d%% (%s)." % [grams(tot), grams(tot + filler_g), np, tier_name(np)], "warn" if np < 60 else "good")
	return np


## napis nad stanowiskiem produkcyjnym (regał, suszarka, stół laboratoryjny…)
func station_label(room: String, idx: int) -> String:
	var f: Dictionary = Prod.furn(room, idx)
	var nm := String(f.get("name", "Stanowisko"))
	var j = Prod.job(room, idx)
	if j == null:
		match String(f.get("func", "")):
			"dry": return nm + (" — włóż świeży zbiór" if Prod.wet_total(room) > 0.0 else " — pusta")
			"tank": return nm + " — podlewa uprawy"
			"filter": return nm + " — tłumi zapach"
		return nm + " — nastaw"
	if float(j.prog) >= 1.0:
		return nm + " — gotowe, zbierz"
	if int(j.get("hold", -1)) >= 0:
		return "%s — %s!" % [nm, Prod.stage_name(j).to_lower()]
	var left: float = Prod.minutes_left(j)
	var thirsty: bool = Prod.recipe(j).has("water") and float(j.water) < 25.0
	return "%s — %s (%dh %02dm)%s" % [nm, Prod.stage_name(j).to_lower(), int(left / 60.0), int(left) % 60, " • SUCHO!" if thirsty else ""]


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
	else:
		n = floorf(n * 2.0 + 0.001) / 2.0
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
	if not D.DOORS.has(room):
		# skrzynka Wiktora i inne schowki, które nie są pokojami
		return false
	return owns(String(D.DOORS[room].get("prop", "")))


func buy_property(id: String) -> bool:
	var p := prop_def(id)
	if p.is_empty() or owns(id) or String(p.room) == "" or int(S.lvl) < int(p.lvl) or S.cash < float(p.price):
		return false
	S.cash -= float(p.price)
	S.stats.spent = float(S.stats.spent) + float(p.price)
	S.props[id] = true
	Sfx.play("level")
	notify("Kupiono: %s. Sprzęt i meble kupisz w hurtowni budowlanej przy Hutniczej, a w środku ustawisz je klawiszem [B]." % p.name, "level")
	add_xp(40.0)
	nav_dirty.emit()
	return true


func door_label(id: String) -> String:
	var dd: Dictionary = D.DOORS[id]
	if dd.get("sealed", false):
		return "Zaplombowane przez policję"
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
	var hang: bool = f.get("hang", false)
	if rc.position.x < -float(R.w) * 0.5 + 0.02 or rc.end.x > float(R.w) * 0.5 - 0.02 or rc.position.y < -float(R.d) * 0.5 + 0.02 or rc.end.y > float(R.d) * 0.5 - 0.02:
		return false
	if not hang and rc.intersects(Rect2(-1.0, float(R.d) * 0.5 - 1.5, 2.0, 1.5)):
		return false
	var items: Array = S.hide[room].items
	for i in range(items.size()):
		if i == ignore:
			continue
		var o: Dictionary = items[i]
		var of := furn_def(o.f)
		if of.is_empty():
			continue
		# lampa pod sufitem koliduje tylko z inną lampą i z wysokimi meblami
		var oh: bool = of.get("hang", false)
		if hang != oh and float((of if hang else f).h) <= 1.6:
			continue
		if rc.grow(-0.03).intersects(furn_rect(of, float(o.x), float(o.z), int(o.r))):
			return false
	if not hang:
		for pt in Prod.pots(room):
			if rc.grow(Prod.POT_R).has_point(Vector2(float(pt.x), float(pt.z))):
				return false
	return true


## --- Sprzęt i meble: najpierw kupujesz w hurtowni budowlanej (trafiają „na stan”), potem ustawiasz w kryjówce [B],
## a dopiero ustawione działają. Zdjęty mebel wraca na stan; odsprzedać go można w hurtowni za połowę ceny.
func supply_open() -> bool:
	var h := hour()
	return h >= float(D.SUPPLY_OPEN[0]) and h < float(D.SUPPLY_OPEN[1])


func owned(fid: String) -> int:
	return int(S.get("owned", {}).get(fid, 0))


func owned_total() -> int:
	var n := 0
	for k in S.get("owned", {}):
		n += int(S.owned[k])
	return n


## ile sztuk tego mebla stoi już w kryjówkach
func furn_count(fid: String) -> int:
	var n := 0
	for r in S.hide:
		for it in S.hide[r].get("items", []):
			if String(it.f) == fid:
				n += 1
	return n


## dlaczego nie da się kupić ("" = można)
func furn_block(fid: String) -> String:
	var f := furn_def(fid)
	if f.is_empty():
		return "Nie ma takiego towaru."
	if int(S.lvl) < int(f.lvl):
		return "Od poziomu %d." % int(f.lvl)
	if S.cash < float(f.price):
		return "Brakuje %s." % money(float(f.price) - S.cash)
	return ""


func furn_buy(fid: String) -> bool:
	if furn_block(fid) != "":
		return false
	var f := furn_def(fid)
	S.cash -= float(f.price)
	S.stats.spent = float(S.stats.spent) + float(f.price)
	if not S.has("owned"):
		S["owned"] = {}
	S.owned[fid] = owned(fid) + 1
	Sfx.play("cash")
	return true


## odsprzedaż rzeczy ze stanu (nieustawionej) za połowę ceny
func furn_sell(fid: String) -> bool:
	if owned(fid) <= 0:
		return false
	var f := furn_def(fid)
	S.owned[fid] = owned(fid) - 1
	if int(S.owned[fid]) <= 0:
		S.owned.erase(fid)
	S.cash += round(float(f.price) * 0.5)
	Sfx.play("cash")
	return true


## ustawia w kryjówce rzecz, którą masz na stanie
func furn_place(room: String, fid: String, x: float, z: float, r: int) -> bool:
	var f := furn_def(fid)
	if f.is_empty() or not room_owned(room) or owned(fid) <= 0 or not furn_valid(room, fid, x, z, r):
		return false
	S.owned[fid] = owned(fid) - 1
	if int(S.owned[fid]) <= 0:
		S.owned.erase(fid)
	S.hide[room].items.append({"f": fid, "x": snappedf(x, 0.05), "z": snappedf(z, 0.05), "r": r})
	Sfx.play("place")
	if world != null:
		world.refresh_furniture(room)
	return true


## zakup z dowozem i od razu ustawienie (testy, bot symulacji): nic nie kupuje, jeśli miejsce jest złe
func furn_buy_place(room: String, fid: String, x: float, z: float, r: int) -> bool:
	if not room_owned(room) or not furn_valid(room, fid, x, z, r):
		return false
	if owned(fid) <= 0 and not furn_buy(fid):
		return false
	return furn_place(room, fid, x, z, r)


func furn_remove(room: String, idx: int) -> bool:
	var items: Array = S.hide[room].items
	if idx < 0 or idx >= items.size():
		return false
	var f := furn_def(items[idx].f)
	if Prod.job(room, idx) != null:
		notify("Najpierw opróżnij to stanowisko.", "warn")
		return false
	if f["func"] == "stash" and store_total(S.stash[room]) > float(stash_cap(room) - int(f.cap)):
		notify("Skrytka jest zbyt pełna, by zdjąć ten mebel.", "warn")
		return false
	items.remove_at(idx)
	var nj := {}
	var jobs: Dictionary = Prod.hide(room).jobs
	for k in jobs:
		var ki := int(k)
		nj[str(ki - 1 if ki > idx else ki)] = jobs[k]
	S.hide[room].jobs = nj
	# zdjęty mebel wraca na stan: można go postawić gdzie indziej albo odsprzedać w hurtowni
	if not S.has("owned"):
		S["owned"] = {}
	var fid := String(f.id)
	S.owned[fid] = owned(fid) + 1
	notify("Zdjęto: %s. Czeka na stanie — ustawisz go ponownie [%s] albo odsprzedasz w hurtowni." % [String(f.name), kn("build")])
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
		# najpierw oprowadzenie po kawalerce: zapis gry, skrytka, waga — dopiero potem pierwsza paczka
		{"ch": "Rozdział 1: Po nalocie", "id": "room_save", "text": func(): return "Rozejrzyj się po wynajętej kawalerce. Podejdź do laptopa na stole, naceluj na niego i naciśnij [E] — tylko tak zapisujesz grę.",
			"done": func(): return flag("tut_save"), "marker": _laptop_marker},
		{"id": "room_stash", "text": func(): return "Szafa pod ścianą to Twoja skrytka — towar i gotówka są w niej bezpieczne. Otwórz ją [E].",
			"done": func(): return flag("tut_stash"), "marker": _stash_marker},
		{"id": "room_bench", "text": func(): return "Na stole stoi waga kuchenna. Kiedyś robili to za Ciebie inni — teraz porcjujesz sam. Obejrzyj ją [E].",
			"done": func(): return flag("tut_bench"), "marker": _bench_marker, "on_done": _on_tour_done},
		{"id": "phone", "text": func(): return "Ktoś wsunął paczkę pod drzwi. Przeczytaj wiadomość od Wiktora: [Tab] → Wiadomości.",
			"done": func(): return flag("read_wiktor") or flag("got_first"), "on_done": _on_phone_done},
		{"id": "drop1", "text": func(): return "Przy drzwiach kawalerki leży paczka od Wiktora. Otwórz ją [E] i przeciągnij towar do swoich kieszeni.",
			"done": func(): return flag("got_first"), "marker": _starter_marker},
		{"id": "pack1", "text": func(): return "Wróć do kawalerki i zaporcjuj towar na wadze. (%d/3 g)" % mini(3, int(S.stats.packed)),
			"done": func(): return int(S.stats.packed) >= 3 or _tutorial_dry(), "marker": _bench_marker, "on_done": _on_pack_done},
		{"id": "sell1", "text": func(): return "Odpisz Dominikowi (Wiadomości) i dostarcz mu towar. (%d/2 g)" % mini(2, int(S.stats.sold)),
			"done": func(): return int(S.stats.sold) >= 2 or (_tutorial_dry() and packed_total(S.inv) + packed_total(S.stash.safe) <= 0), "marker": _buyer_marker},
		{"id": "repay1", "text": func(): return "Zanieś pierwsze pieniądze do skrzynki Wiktora — to stara skrzynka gazowa na tyłach pawilonu. Otwórz ją [E] i przeciągnij do niej gotówkę. (%s / %s)" % [money(minf(float(D.BOX_FIRST), float(S.stats.get("box_paid", 0.0)))), money(D.BOX_FIRST)],
			"done": func(): return float(S.stats.get("box_paid", 0.0)) >= float(D.BOX_FIRST), "marker": _box_marker, "on_done": _on_repay_done},
		{"ch": "Rozdział 2: Na swoim", "id": "order1", "text": func(): return "Zamów towar u Wiktora: telefon → Wiadomości → Wiktor → „Zamów towar”. Paczkę odbierz ze skrytki oznaczonej sprejem.",
			"done": func(): return int(S.stats.pickups) >= 2, "marker": _drop_marker},
		{"id": "lvl2", "text": func(): return "Zdobądź poziom 2. Zadowolony Dominik poleci Cię dalej. (%d/%d PD)" % [int(S.xp), int(D.XP_LEVELS[1])],
			"done": func(): return int(S.lvl) >= 2},
		{"id": "rata1", "text": func(): return "Spłać pierwszą ratę długu: %s do końca %d. dnia (telefon → Portfel). Spłacono: %s" % [money(D.DEBT_SCHEDULE[0].due), int(D.DEBT_SCHEDULE[0].day), money(S.paid)],
			"done": func(): return S.paid >= float(D.DEBT_SCHEDULE[0].due)},
		{"id": "lvl3", "text": func(): return "Zdobądź poziom 3 i wybierz pierwszą umiejętność (telefon → Rozwój).",
			"done": func(): return int(S.lvl) >= 3 and not S.skills.is_empty()},
		{"id": "teren1", "text": func(): return "Każdy nowy klient to nowy teren, a z terenem przybywa skrytek. Zdobądź kolejnego klienta — Wiktor zacznie zostawiać paczki dalej. (skrytki: %d)" % drops_open().size(),
			"done": func(): return drops_open().size() > 4},
		{"id": "ciuchy1", "text": func(): return "Zajrzyj do „Taniej Odzieży” przy Hutniczej i kup strój pasujący do roboty: szybszy, mniej rzucający się w oczy albo… kominiarkę.",
			"done": func(): return not S.get("outfits", {}).is_empty(), "marker": func(): return {"loc": "out", "x": D.DOORS.ciuchy.x, "z": D.DOORS.ciuchy.z}},
		{"ch": "Rozdział 3: Kryjówka", "id": "garaz", "text": func(): return "Kup Garaż nr 14 (%s, poziom %d) — pierwszą własną kryjówkę." % [money(prop_def("garaz").price), int(prop_def("garaz").lvl)],
			"done": func(): return owns("garaz"), "marker": _garage_marker},
		{"id": "meble", "text": func(): return "Urządź garaż: kup w hurtowni budowlanej przy Hutniczej (otwarta %d:00–%d:00) stół roboczy i regał, a potem w garażu naciśnij [B] i je ustaw." % [int(D.SUPPLY_OPEN[0]), int(D.SUPPLY_OPEN[1])],
			"done": func(): return _has_furn("garage", "pack") and _has_furn("garage", "stash"), "marker": _furnish_marker},
		{"id": "uprawa1", "text": func(): return "Czas znów produkować. Kup u Stasia doniczki i nasiona, postaw doniczki w kryjówce [B] (najlepiej pod lampą LED) i posadź pierwszy krzak — celujesz w doniczkę i wybierasz czynność.",
			"done": func(): return _any_job() or Prod.plant_count("garage") + Prod.plant_count("basement") > 0 or int(S.stats.grown) > 0, "marker": _garage_marker},
		{"id": "zbior1", "text": func(): return "Doglądaj krzaków: podlewaj, nawoź, przytnij liście. Dojrzałe zetnij, wysusz w suszarce (kupisz ją w hurtowni) i zważ. Nadwyżki sprzedasz hurtem na Giełdzie. (%d g)" % int(S.stats.grown),
			"done": func(): return int(S.stats.grown) > 0, "marker": _garage_marker},
		{"ch": "Wolna gra", "id": "free", "text": func(): return "Rozwijaj interes i spłacaj raty. Dług: %s" % money(S.debt), "done": func(): return false},
	]


func _any_job() -> bool:
	for room in Prod.ROOMS:
		if S.hide.has(room) and not Prod.hide(room).jobs.is_empty():
			return true
	return false


## samouczek: pierwsza paczka odebrana, a towaru luzem już nie ma (zaporcjowany, rozsypany albo stracony)
func _tutorial_dry() -> bool:
	if not flag("got_first") or not S.drops.is_empty():
		return false
	for src in [S.inv, S.stash.safe]:
		for p in src.bulk:
			for k in src.bulk[p]:
				if float(src.bulk[p][k]) >= 1.0:
					return false
	return true


func _has_furn(room: String, fn: String) -> bool:
	for it in S.hide[room].items:
		if furn_def(it.f)["func"] == fn:
			return true
	return false


## liczba kroków oprowadzenia przed krokiem „phone” (do przeliczania starych numerów kroków)
const TOUR_STEPS := 3


func _laptop_marker() -> Variant:
	return {"loc": "safe", "x": float(D.ROOMS.safe.cx) + 1.45, "z": -float(D.ROOMS.safe.d) * 0.5 + 0.67}


func _stash_marker() -> Variant:
	return {"loc": "safe", "x": float(D.ROOMS.safe.cx) + float(D.ROOMS.safe.w) * 0.5 - 0.42, "z": 0.6}


## po obejrzeniu pokoju odzywa się Wiktor z pierwszą paczką
func _on_tour_done() -> void:
	if flag("wiktor_sms"):
		return
	S.flags["wiktor_sms"] = true
	var parts := []
	for e in D.STARTER_PACK:
		parts.append("%d g %s" % [int(e[1]), String(D.PRODUCT_GEN[e[0]])])
	chat("wiktor", "Wsunąłem ci pod drzwi paczkę na start: %s. Czyste, nierozrabiane. Ta jedna jest ode mnie, za darmo — na rozruch, bo wiem, że zaczynasz od zera. Za następne płacisz. Zaporcjuj na wadze i czekaj na klienta. A dług brata sam się nie spłaci: pierwszą stówę wrzuć do mojej skrzynki gazowej na tyłach pawilonu, nigdzie indziej." % " i ".join(parts), false, true)
	if main != null:
		main.door_package()


func last_save_text() -> String:
	if not S.has("saved_at"):
		return "jeszcze nie zapisano"
	var t := float(S.saved_at)
	return "dzień %d, %s" % [int(floor(t / 1440.0)) + 1, clock(t)]


func _on_phone_done() -> void:
	nav_dirty.emit()


func _starter_marker() -> Variant:
	return {"loc": "safe", "x": float(D.ROOMS.safe.cx), "z": float(D.ROOMS.safe.d) * 0.5 - 0.62}


func _box_marker() -> Variant:
	return {"loc": "out", "x": float(D.WIKTOR_BOX.x), "z": float(D.WIKTOR_BOX.z)}


func _on_pack_done() -> void:
	S.cust.dominik.unlocked = true
	S.cust.dominik.hunger = 0.6
	chat("wiktor", "Dominik z bloku 5 brał od twoich chłopaków. Dałem mu twój numer.", false, true)
	# pierwsze zamówienie w życiu: Dominik chce tego, co właśnie zaporcjowałeś
	var have := "dym"
	var best := 0
	for src in [S.inv, S.stash.safe]:
		for p in src.pack:
			var n := 0
			for k in src.pack[p]:
				n += int(src.pack[p][k])
			if n > best:
				best = n
				have = String(p)
	make_order(D.CLIENTS[0], 2, have)


func _on_repay_done() -> void:
	S.flags["hurt_on"] = true
	chat("wiktor", "Uczciwy. Od teraz piszesz do mnie, co ci potrzeba — „Zamów towar” pod tą rozmową. Paczkę zostawię w skrytce z moim znakiem, wszystko idzie na zeszyt. Kasę wrzucasz do skrzynki; na początek masz na to %d dni." % credit_days())
	add_xp(20.0)
	# to, co zostało po dawnej sieci: paru detalistów z osiedla, którzy brali od Twoich ludzi
	chat("wiktor", "I jeszcze jedno. Puściłem twój numer dwóm detalistom, którzy brali od twoich chłopaków: Sebie spod bloku 9 i staremu Zenonowi. Drobnica, ale od czegoś trzeba zacząć.", false, true)
	unlock_client("seba", "Ty jesteś ten od Wiktora? Dobra. Odezwę się, jak będę coś potrzebował.")
	unlock_client("zenon", "Dzień dobry, panie kolego. Podobno teraz u pana się zaopatrujemy. Będę pisał.")


## urządzanie garażu: najpierw do hurtowni po stół i regał, potem z nimi do garażu
func _furnish_marker() -> Variant:
	var need_table: bool = not _has_furn("garage", "pack") and owned("stol") <= 0
	var need_shelf: bool = not _has_furn("garage", "stash") and owned("regal") + owned("skrzynia") <= 0
	if need_table or need_shelf:
		return {"loc": "out", "x": float(D.SUPPLY_AT.x), "z": float(D.SUPPLY_AT.z)}
	return _garage_marker()


func _garage_marker() -> Variant:
	return {"loc": "out", "x": D.DOORS.garage.x, "z": D.DOORS.garage.z}


func _bench_marker() -> Variant:
	return {"loc": "safe", "x": float(D.ROOMS.safe.cx) + 0.9, "z": -float(D.ROOMS.safe.d) * 0.5 + 1.5}


func _drop_marker() -> Variant:
	var d = ready_drop()
	if d == null:
		return null
	var dd: Dictionary = Market.spot(d)
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
	if prologue != null:
		return prologue.step()
	var i := int(S.step)
	return story[i] if i < story.size() else {}


func chapter() -> String:
	if prologue != null:
		return "Prolog: Ostatnia noc"
	var i: int = mini(int(S.step), story.size() - 1)
	while i >= 0:
		if story[i].has("ch"):
			return story[i].ch
		i -= 1
	return ""


func story_tick() -> void:
	if prologue != null:
		return
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
## Zapis jest możliwy tylko przy laptopie w kryjówce (main.save_here). Nie ma zapisów automatycznych.
func save_game(manual := true) -> void:
	S.flags["tut_save"] = true
	S["saved_at"] = S.t
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


## krótki opis zapisu do menu głównego: {day, cash, when} albo {} gdy zapisu nie ma
func save_summary() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var when := "—"
	var mt := FileAccess.get_modified_time(SAVE_PATH)
	if mt > 0:
		var dt := Time.get_datetime_dict_from_unix_time(mt + Time.get_time_zone_from_system().bias * 60)
		when = "%02d.%02d, %02d:%02d" % [int(dt.day), int(dt.month), int(dt.hour), int(dt.minute)]
	return {"day": int(float(d.get("t", 0.0)) / 1440.0) + 1, "cash": float(d.get("cash", 0.0)), "when": when}


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
	for k in ["woreczki", "majeranek", "cukier", "nasiona", "burner", "nawoz", "chemia", "doniczka"]:
		if not base.items.has(k):
			base.items[k] = 0
	if not base.flags.has("tut_save") and (int(base.step) > 0 or base.flags.has("read_wiktor")):
		base.step = int(base.step) + TOUR_STEPS
		base.flags["wiktor_sms"] = true
	for k in ["tut_save", "tut_stash", "tut_bench"]:
		if int(base.step) >= TOUR_STEPS:
			base.flags[k] = true
	base.wanted = false
	base.stash["loot"] = new_store()
	# woreczków do kupowania już nie ma, a „ulepszenie” wagi stało się po prostu lepszą wagą
	base.items["woreczki"] = 0
	for st0 in base.stash.values():
		if st0 is Dictionary and st0.has("items") and st0.items is Dictionary:
			st0.items.erase("woreczki")
	if bool(base.upg.get("waga", false)):
		base["scale"] = maxi(int(base.get("scale", 0)), 1)
	base.upg.erase("waga")
	# stare umiejętności „gadane” zamieniają się na nowe z tej samej gałęzi
	for pair in [["gadka", "reka2"], ["oko2", "kieszenie"], ["rekin", "klientela"]]:
		if base.skills.has(pair[0]):
			base.skills.erase(pair[0])
			base.skills[pair[1]] = true
	S = base
	Prod.migrate()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
