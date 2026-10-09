extends RefCounted
## Płatna pomoc w doglądaniu, bez tworzenia surowców ani automatycznego zbioru.
const FEE := 450.0
const VISIT := 12.0
const DAILY_LIMIT := 48.0
const POSITION := Vector2(72,182)
static func near() -> bool:
	return G.player!=null and G.player.loc=="out" and Vector2(G.player.global_position.x,G.player.global_position.z).distance_to(POSITION*D.SC)<=3.0
static func requirement() -> String:
	if G.S.wanted: return "Najpierw zgub policję."
	if int(G.S.lvl)<8: return "Współpraca od poziomu 8."
	if not G.S.props.get("garaz",false): return "Najpierw kup własny garaż."
	if G.Reputation.score("garaze")<20: return "Zdobądź 20 reputacji w Garage Row: %d/20."%G.Reputation.score("garaze")
	if G.Prod.lamps("garage").is_empty(): return "Wyposaż garaż w lampę do uprawy."
	if G.S.cash<FEE: return "Potrzebujesz 450 zł na rozpoczęcie współpracy."
	return ""
static func hire() -> bool:
	if G.S.workers.has("roman") or not near() or requirement()!="": return false
	G.S.cash -= FEE
	G.S.stats.spent += FEE
	G.S.workers.roman = {"paused":false,"next":G.S.t+60.0,"day":G.day(),"paid":0.0,"visits":0,"watered":0,"status":"Czeka na obchód"}
	G.chat("info","Roman dogląda garażu 8–20. Podlewa do 2 potrzebujących roślin na godzinę: 12 zł za wizytę, najwyżej 48 zł dziennie. Zbiory i reszta produkcji pozostają po Twojej stronie.")
	return true
static func tick() -> void:
	if G.prologue!=null or not G.S.workers.has("roman"): return
	var state: Dictionary = G.S.workers.roman
	if G.S.t<float(state.next): return
	state.next = G.S.t+60.0
	if int(state.day)!=G.day():
		state.day = G.day()
		state.paid = 0.0
	if state.paused: state.status="Wstrzymane"; return
	if G.hour()<8.0 or G.hour()>=20.0: state.status="Poza godzinami pracy"; return
	if G.S.wanted or float(G.S.invest)>=65.0: state.status="Przeczekuje policję"; return
	if not G.S.props.get("garaz",false): state.status="Brak dostępu do garażu"; return
	var thirsty: Array = []
	var pots: Array = G.Prod.pots("garage")
	for i in range(pots.size()):
		var pot: Dictionary = pots[i]
		var plant = pot.pl
		if plant==null or float(plant.prog)>=1.0 or float(plant.health)<=0.0: continue
		if G.Prod.light_at("garage",float(pot.x),float(pot.z))<0: continue
		if float(plant.water)<=35.0: thirsty.append(plant)
		if thirsty.size()>=2: break
	if thirsty.is_empty(): state.status="Uprawa nie potrzebuje podlewania"; return
	if float(state.paid)+VISIT>DAILY_LIMIT: state.status="Wykorzystano dzienny limit 48 zł"; return
	if G.S.cash<VISIT: state.status="Brak 12 zł na wizytę"; return
	G.S.cash -= VISIT
	G.S.stats.spent += VISIT
	state.paid = float(state.paid)+VISIT
	state.visits = int(state.visits)+1
	state.watered = int(state.watered)+thirsty.size()
	for plant in thirsty: plant.water=100.0
	state.status="Podlano %d roślin • %s"%[thirsty.size(),G.clock()]
