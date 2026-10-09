extends RefCounted
## Lokalna znajomość: rzeczywiste dostawy, ograniczone tempo, niewielka korzyść dla sieci.
const DAILY_CAP := 12

static func score(zone: String) -> int:
	return clampi(int(G.S.reputation.get(zone, {}).get("score",0)),0,100)

static func title(zone: String) -> String:
	var value := score(zone)
	return "Ustawiony" if value>=80 else ("Zaufany" if value>=50 else ("Kojarzony" if value>=20 else "Nowa twarz"))

static func next_goal(zone: String) -> int:
	for goal in [20,50,80]:
		if score(zone)<goal: return goal
	return 100

static func discount(zone: String) -> float:
	var value := score(zone)
	return 0.03 if value>=80 else (0.02 if value>=50 else (0.01 if value>=20 else 0.0))

static func record(x: float,z: float,grams: int,purity: int,buyer: String) -> int:
	var zone: Dictionary = G.zone_at(x,z)
	if zone.is_empty() or grams<=0 or purity<55 or buyer.is_empty(): return 0
	var id: String = zone.id
	if not G.S.reputation.has(id):
		G.S.reputation[id] = {"score":0,"day":-1,"earned":0,"buyers":{}}
	var state: Dictionary = G.S.reputation[id]
	if int(state.day)!=G.day():
		state.day = G.day()
		state.earned = 0
		state.buyers = {}
	if state.buyers.has(buyer): return 0
	state.buyers[buyer] = true
	var gain := mini(2+mini(grams/10,1),mini(DAILY_CAP-int(state.earned),100-int(state.score)))
	if gain<=0: return 0
	var before := title(id)
	state.score = int(state.score)+gain
	state.earned = int(state.earned)+gain
	if title(id)!=before:
		G.chat("info","%s: %s (%d/100). Lokalni dealerzy obniżają prowizję o %d punktów procentowych." % [zone.name,title(id),score(id),int(round(discount(id)*100))])
	return gain

static func retail(ctx: Dictionary,grams: int,purity: int) -> void:
	if ctx.get("order")!=null:
		var order: Dictionary = ctx.order
		var spot: Dictionary = G.spot_def(String(order.spot))
		if not spot.is_empty(): record(float(spot.x),float(spot.z),grams,purity,String(order.cust))
	elif ctx.get("street",false) and G.player!=null and G.player.loc=="out":
		var buyer: String = String(ctx.who.get("name","klient"))
		record(G.player.global_position.x,G.player.global_position.z,grams,purity,buyer)
