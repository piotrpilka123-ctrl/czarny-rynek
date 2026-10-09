extends RefCounted
## Odpłatne doglądanie istniejącej partii; bez wsadu, startowania i odbioru towaru.
const FEE := 1800.0
const ACTION := 120.0
const AT := Vector2(-55,207)
static func near() -> bool:
	return G.player!=null and G.player.loc=="out" and Vector2(G.player.global_position.x,G.player.global_position.z).distance_to(AT*D.SC)<=3.0
static func requirement() -> String:
	if G.S.wanted: return "Najpierw zgub policję."
	if not G.flag("gang_pass"): return "Najpierw uzyskaj dostęp do Black Court."
	if G.S.lvl<10: return "Współpraca od poziomu 10."
	if G.Reputation.score("garaze")<50: return "Zdobądź 50 reputacji w Garage Row."
	if not G.S.props.get("garaz",false) or not G.Prod.has_station("garage","lab"): return "Potrzebujesz własnego garażu ze stołem laboratoryjnym."
	if G.S.cash<FEE: return "Rekrutacja kosztuje 1800 zł."
	return ""
static func hire() -> bool:
	if not G.S.labstaff.is_empty() or not near() or requirement()!="": return false
	G.S.cash-=FEE
	G.S.stats.spent+=FEE
	G.S.labstaff={"paused":false,"next":G.S.t+60.0,"day":G.day(),"actions_today":0,"actions":0,"paid":0.0,"status":"Czeka na etap wymagający obsługi"}
	G.chat("info","Igor przejmuje doglądanie etapów przy laboratorium w garażu: 120 zł za wykonaną czynność, maksymalnie 2 na dobę. Sam dostarczasz wsad, startujesz partie i odbierasz produkt. Dyżur całodobowy, kontrole co godzinę; podczas pościgu przeczekuje.")
	return true
static func tick() -> void:
	if G.prologue!=null or G.S.labstaff.is_empty(): return
	var state: Dictionary = G.S.labstaff
	if G.S.t<float(state.next): return
	state.next=G.S.t+60.0
	if state.day!=G.day(): state.day=G.day(); state.actions_today=0; state.paid=0.0
	if state.paused: state.status="Wstrzymane"; return
	if G.S.wanted or G.S.invest>=65.0: state.status="Przeczekuje policję"; return
	if not G.S.props.get("garaz",false): state.status="Brak dostępu do garażu"; return
	if state.actions_today>=2: state.status="Wykorzystano dwie dzienne czynności"; return
	for key in G.Prod.hide("garage").jobs:
		var idx := int(key)
		var furniture: Dictionary = G.Prod.furn("garage",idx)
		var job = G.Prod.job("garage",idx)
		if furniture.get("func","")!="lab" or job==null or int(job.hold)<0 or float(job.prog)>=1.0: continue
		if float(job.hold_t)<8.0: continue
		if G.S.cash<ACTION: state.status="Brak 120 zł na czynność"; return
		if not G.Prod.proceed("garage",idx,false): continue
		G.S.cash-=ACTION
		G.S.stats.spent+=ACTION
		state.actions_today+=1
		state.actions+=1
		state.paid+=ACTION
		state.status="Obsłużono etap: %s • %s"%[G.Prod.recipe(job).get("name",""),G.clock()]
		return
	state.status="Brak etapu do obsługi"
