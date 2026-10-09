extends RefCounted
static func run(T) -> void:
	var saved: Dictionary = G.S
	var pos: Vector3 = G.player.global_position
	var loc: String = G.player.loc
	G.S = G.new_state()
	G.player.loc="out"
	G.player.global_position = Vector3(72*D.SC,0,182*D.SC)
	G.S.lvl=8
	G.S.cash=1000.0
	T.ok(not G.Workers.hire(),"pomocnik wymaga własnego garażu i lokalnego zaufania")
	G.S.props.garaz=true
	G.S.reputation.garaze={"score":20,"day":1,"earned":0,"buyers":{}}
	G.S.hide.garage.items=[{"f":"lampa_led","x":0.0,"z":0.0,"r":0,"mode":1}]
	G.player.loc="safe"
	T.ok(not G.Workers.hire(),"pomocnika rekrutuje się osobiście, nie przez telefon")
	G.player.loc="out"
	T.ok(G.Workers.hire() and G.S.cash==550.0 and not G.Workers.hire(),"rekrutacja Romana kosztuje 450 zł tylko raz")
	for x in [-0.6,-0.2,0.2]:
		var plant: Dictionary = G.Prod.plant_new()
		plant.prog=0.3
		plant.water=20.0
		G.S.hide.garage.pots.append({"x":x,"z":0.0,"pl":plant})
	G.S.t+=60.0
	G.Workers.tick()
	var state: Dictionary = G.S.workers.roman
	var pots: Array = G.Prod.pots("garage")
	T.ok(G.S.cash==490.0 and pots[0].pl.water==100.0 and pots[1].pl.water==100.0 and pots[2].pl.water==20.0,"płatna wizyta podlewa najwyżej dwie istniejące rośliny")
	T.ok(pots[0].pl.prog==0.3 and pots[0].pl.health==100.0 and G.goods_total(G.S.inv)==0,"pomocnik nie przyspiesza wzrostu ani nie tworzy towaru")
	pots[2].pl.water=100.0
	G.S.t+=60.0
	G.Workers.tick()
	T.ok(G.S.cash==490.0 and state.visits==1,"brak potrzebnej pracy oznacza brak opłaty")
	state.paused=true
	pots[0].pl.water=20.0
	G.S.t+=60.0
	G.Workers.tick()
	T.ok(pots[0].pl.water==20.0 and G.S.cash==490.0,"wstrzymany pomocnik nie pobiera pieniędzy ani nie pracuje")
	state.paused=false
	G.S.cash=5.0
	G.S.t+=60.0
	G.Workers.tick()
	T.ok(G.S.cash==5.0 and pots[0].pl.water==20.0,"brak gotówki zatrzymuje pracę bez długu i darmowego podlewania")
	G.S.cash=500.0
	G.S.wanted=true
	G.S.t+=60.0
	G.Workers.tick()
	T.ok(G.S.cash==500.0 and pots[0].pl.water==20.0,"pomocnik przeczekuje aktywny pościg")
	G.S.wanted=false
	for i in range(5):
		pots[0].pl.water=20.0
		G.S.t+=60.0
		G.Workers.tick()
	T.ok(float(state.paid)==240.0 and G.S.cash==320.0,"dzienny limit zatrzymuje opłaty po czterech wizytach")
	var copy: Dictionary = G.new_state()
	G._merge(copy,JSON.parse_string(JSON.stringify(G.S)))
	T.ok(copy.workers.roman.paid==240.0 and copy.workers.roman.visits==4,"zapis zachowuje umowę, wykonane wizyty i limit płac")
	# Stara stawka nie daje po aktualizacji dodatkowych wizyt ani dopłaty za przeszłość.
	state.erase("day_visits")
	state.paid=48.0
	state.day=G.day()
	state.next=G.S.t
	var old_cash: float = G.S.cash
	pots[0].pl.water=20.0
	G.Workers.tick()
	T.ok(state.day_visits==4 and G.S.cash==old_cash,"stara umowa zachowuje cztery wykorzystane wizyty bez dopłaty wstecz")
	G.S=G.new_state()
	G._merge(G.S,{"lvl":8})
	T.ok(G.S.workers.is_empty(),"starszy zapis nie zatrudnia pomocnika automatycznie")
	G.S.track="worker_roman"
	T.ok(G.main.cur_target().get("id","")=="worker_roman","telefon prowadzi do rzeczywistego kontaktu pomocnika")
	G.S=saved
	G.player.global_position=pos
	G.player.loc=loc
