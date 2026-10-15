extends RefCounted
## Własna sieć: fizyczny zapas, prowizja, ograniczone tempo i odbiór pieniędzy.
const DEFS := [
	{"id": "mati", "name": "Mati", "x": 65.0, "z": 84.0, "lvl": 4, "fee": 250, "commission": 0.35, "cap": 40, "minpur": 55, "products": ["dym", "szron"], "pace": 4, "client": "heniek"},
	{"id": "darek", "name": "Darek", "x": -75.0, "z": -13.5, "lvl": 8, "fee": 900, "commission": 0.4, "cap": 80, "minpur": 65, "products": ["krysztal", "snieg"], "pace": 1, "client": "rysiek"},
]

static func definition(id: String) -> Dictionary:
	for dealer in DEFS:
		if String(dealer.id) == id:
			return dealer
	return {}

static func position(id: String) -> Vector2:
	var dealer := definition(id)
	return G.world.near_free(float(dealer.x) * D.SC, float(dealer.z) * D.SC) if not dealer.is_empty() else Vector2.ZERO

static func zone(id: String) -> Dictionary:
	var dealer := definition(id)
	return G.zone_at(float(dealer.x)*D.SC,float(dealer.z)*D.SC) if not dealer.is_empty() else {}

static func commission(id: String) -> float:
	var dealer := definition(id)
	if dealer.is_empty(): return 0.0
	var territory := zone(id)
	return float(dealer.commission)-G.Reputation.discount(String(territory.get("id","")))

static func near(id: String) -> bool:
	return G.player != null and G.player.loc == "out" and Vector2(G.player.global_position.x, G.player.global_position.z).distance_to(position(id)) <= 3.0

## dealer stoi na ulicy dopiero, gdy duży klient go poleci (albo gdy już z nim współpracujesz)
static func offered(id: String) -> bool:
	return G.S.dealers.has(id) or bool(G.S.flags.get("dealer_offer_" + id, false))


## duży, stały klient (kilka transakcji i trochę wziętego towaru) sam proponuje: „znam kogoś, kto sprzeda to dla ciebie”
static func check_offers() -> void:
	for dealer in DEFS:
		var id := String(dealer.id)
		if offered(id): continue
		var cs: Dictionary = G.S.cust.get(String(dealer.client), {})
		if cs.is_empty() or not bool(cs.get("unlocked", false)): continue
		if int(cs.get("deals", 0)) < 3 or int(cs.get("grams", 0)) < 30 or int(G.S.lvl) < int(dealer.lvl) - 1: continue
		G.S.flags["dealer_offer_" + id] = true
		G.chat(String(dealer.client), "Słuchaj, biorę od ciebie regularnie. Znam %s — sprzedaje swoim, tylko potrzebuje towaru od kogoś pewnego. Pogadaj z nim, stoi na osiedlu." % dealer.name)
		G.notify("%s poleca Ci dealera: %s. Zaznaczony na mapie." % [String(G.cust_def(String(dealer.client)).name), dealer.name], "good")


static func requirement(id: String) -> String:
	var dealer := definition(id)
	if dealer.is_empty(): return "Nieznany kontakt."
	if not offered(id): return "Nikt jeszcze Cię temu człowiekowi nie polecił."
	if int(G.S.lvl) < int(dealer.lvl): return "Współpraca od poziomu %d." % int(dealer.lvl)
	if int(G.S.stats.deals) < 6 or int(G.S.stats.sold) < 30: return "Najpierw zrób 6 transakcji i sprzedaj 30 g — pokaż, że umiesz utrzymać zapas."
	if G.S.cash < float(dealer.fee): return "Potrzebujesz %s na rozpoczęcie współpracy." % G.money(dealer.fee)
	return ""

static func hire(id: String) -> bool:
	if G.S.dealers.has(id) or not near(id) or requirement(id) != "": return false
	var dealer := definition(id)
	G.S.cash -= float(dealer.fee)
	G.S.stats.spent += float(dealer.fee)
	G.S.dealers[id] = {"stock": G.new_store(), "cash": 0.0, "sold": 0, "paused": false, "next": G.S.t + 120.0, "empty_notified": false}
	G.chat("info", "%s dołącza do Twojej sieci. Przyjdź z zapakowanym towarem; prowizja %d%%. Pieniądze odbierasz u niego osobiście." % [dealer.name, int(round(commission(id)*100))])
	G.tip("dealerzy", "Własna sieć", "Mati i Darek sprzedają przekazane paczki w godzinach pracy. W telefonie → Dealerzy sprawdzisz zapas i rozliczenie oraz włączysz trasę. Towar i pieniądze przekazuj osobiście; prowizja jest już potrącona z rozliczenia.", 15.0)
	return true

static func stock(id: String) -> int:
	return int(G.goods_total(G.S.dealers[id].stock)) if G.S.dealers.has(id) else 0

static func supply(id: String, product: String, limit := 20) -> int:
	var dealer := definition(id)
	if dealer.is_empty() or not G.S.dealers.has(id) or not near(id) or not (product in dealer.products) or int(G.S.lvl) < int(D.PRODUCTS[product].lvl): return 0
	var state: Dictionary = G.S.dealers[id]
	var remaining: int = mini(limit, int(dealer.cap) - stock(id))
	var supplied := 0
	for pack in G.stacks(G.S.inv, "pack"):
		if String(pack.p) != product or int(pack.pur) < int(dealer.minpur): continue
		var amount: int = mini(int(pack.n), int(remaining / int(pack.g)))
		if amount <= 0: continue
		var taken: int = G.take_pack(G.S.inv, product, int(pack.pur), amount, int(pack.g))
		var grams: int = taken * int(pack.g)
		G.add_bulk(state.stock, product, int(pack.pur), grams)
		remaining -= grams
		supplied += grams
	if supplied > 0:
		state.empty_notified = false
		state.next = maxf(float(state.next), G.S.t + 60.0)
	return supplied

static func collect(id: String) -> float:
	if not G.S.dealers.has(id) or not near(id): return 0.0
	var state: Dictionary = G.S.dealers[id]
	var amount: float = state.cash
	state.cash = 0.0
	G.S.cash += amount
	G.S.stats.earned += amount
	return amount

static func tick() -> void:
	if G.prologue != null: return
	check_offers()
	for id in G.S.dealers:
		var dealer := definition(String(id))
		if dealer.is_empty(): continue
		var state: Dictionary = G.S.dealers[id]
		if G.S.t < float(state.next): continue
		state.next = G.S.t + 60.0
		if state.paused or G.hour() < 8.0 or G.hour() >= 23.0 or float(G.S.invest) >= 65.0: continue
		var left: int = int(dealer.pace)
		for batch in G.stacks(state.stock, "bulk"):
			var sold: float = G.take_bulk(state.stock, String(batch.p), int(batch.pur), minf(float(left), float(batch.n)))
			var quality: float = clampf(0.85 + float(batch.pur) * 0.0015, 0.85, 1.0)
			state.cash += round(G.market_price(String(batch.p), int(batch.pur)) * sold * quality * (1.0 - commission(String(id))))
			state.sold += int(sold)
			G.S.stats.sold += int(sold)
			left -= int(sold)
			if left <= 0: break
		if stock(String(id)) <= 0 and not state.empty_notified:
			state.empty_notified = true
			G.chat("info", "%s: zapas się skończył. Do odbioru %s — podejdź i donieś paczki." % [dealer.name, G.money(state.cash)])
