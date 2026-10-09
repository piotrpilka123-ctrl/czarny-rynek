extends RefCounted
static func run(T) -> void:
	var saved: Dictionary = G.S
	G.S = G.new_state()
	var at: Vector2 = G.Dealers.position("mati")
	var zone: String = G.Dealers.zone("mati").id
	var cash: float = G.S.cash
	T.ok(G.Reputation.record(at.x,at.y,10,80,"ala")==3 and G.Reputation.score(zone)==3,"udana dostawa buduje reputację w rzeczywistej dzielnicy")
	T.ok(G.Reputation.record(at.x,at.y,10,80,"ala")==0,"dzielenie dostawy temu samemu klientowi nie powiela reputacji")
	T.ok(G.Reputation.record(at.x,at.y,0,80,"pusty")==0 and G.Reputation.record(at.x,at.y,10,30,"slaby")==0,"puste dostawy i zbyt słaby towar nie budują lokalnego zaufania")
	for i in range(10): G.Reputation.record(at.x,at.y,20,80,"klient_%d"%i)
	T.ok(G.Reputation.score(zone)==12,"dzienny limit hamuje szybkie farmienie reputacji")
	var migrated: Dictionary = G.new_state()
	G._merge(migrated,JSON.parse_string(JSON.stringify(G.S)))
	G.S = migrated
	T.ok(G.Reputation.score(zone)==12 and G.Reputation.record(at.x,at.y,10,80,"ala")==0,"zapis zachowuje reputację i dzienną pamięć klientów")
	G.S.t += 1440.0
	T.ok(G.Reputation.record(at.x,at.y,10,80,"ala")==3,"nowy dzień pozwala ponownie budować zaufanie stałych klientów")
	for i in range(40):
		G.S.t += 1440.0
		G.Reputation.record(at.x,at.y,20,80,"ala")
	T.ok(G.Reputation.score(zone)==100 and absf(G.Dealers.commission("mati")-0.32)<0.001,"maksymalna reputacja obniża prowizję tylko o trzy punkty procentowe")
	T.ok(absf(G.Dealers.commission("darek")-0.4)<0.001 and G.S.cash==cash,"reputacja nie daje gotówki ani bonusu w innej dzielnicy")
	G.S = G.new_state()
	G._merge(G.S,{"cash":200.0,"lvl":4})
	T.ok(G.S.reputation.is_empty(),"starszy zapis bez reputacji otrzymuje bezpieczny pusty stan")
	G.S = saved
