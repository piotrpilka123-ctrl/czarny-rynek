extends RefCounted
static func run(T) -> void:
	var saved: Dictionary=G.S
	var loc: String=G.player.loc
	var pos: Vector3=G.player.global_position
	G.S=G.new_state()
	G.S.cash=10000.0
	G.S.lvl=10
	G.S.props.garaz=true
	G.S.hide.garage.items=[{"f":"lab","x":0.0,"z":0.0,"r":0}]
	G.S.reputation.garaze={"score":50,"day":1,"earned":0,"buyers":{}}
	G.player.loc="out"
	G.player.global_position=Vector3(-55*D.SC,0,207*D.SC)
	T.ok(not G.LabStaff.hire(),"asystent wymaga dostępu do gangu, nie samych pieniędzy")
	G.S.track="lab_helper"
	T.ok(G.main.cur_target().z==179.0*D.SC,"bez przepustki telefon prowadzi do bramy, a nie przez mur gangu")
	G.S.flags.gang_pass=true
	T.ok(G.LabStaff.hire() and G.S.cash==8200.0 and not G.LabStaff.hire(),"Igor wymaga osobistej rekrutacji, 1800 zł płacone tylko raz")
	var state: Dictionary=G.S.labstaff
	var job: Dictionary=G.Prod.new_job("amfetamina",1)
	job.prog=0.45
	job.hold=0
	job.hold_t=30.0
	G.S.hide.garage.jobs["0"]=job
	G.S.t+=60.0
	var now: float=G.S.t
	G.LabStaff.tick()
	T.ok(job.hold==-1 and G.S.cash==8080.0 and state.actions==1,"asystent obsługuje rzeczywisty zatrzymany etap za 120 zł")
	T.ok(G.S.t==now and job.health==100.0 and G.goods_total(G.S.inv)==0,"pomoc nie przewija zegara, nie poprawia jakości i nie tworzy towaru")
	G.S.t+=60.0
	G.LabStaff.tick()
	T.ok(state.actions==1 and G.S.cash==8080.0,"brak etapu oznacza brak dodatkowej opłaty")
	job.hold=0
	job.hold_t=30.0
	state.paused=true
	G.S.t+=60.0
	G.LabStaff.tick()
	T.ok(job.hold==0 and G.S.cash==8080.0,"wstrzymany asystent pozostawia etap i pieniądze")
	state.paused=false
	G.S.cash=50.0
	G.S.t+=60.0
	G.LabStaff.tick()
	T.ok(job.hold==0 and G.S.cash==50.0,"brak płacy nie tworzy długu ani darmowej obsługi")
	G.S.cash=500.0
	G.S.t+=60.0
	G.LabStaff.tick()
	job.hold=0
	G.S.t+=60.0
	G.LabStaff.tick()
	T.ok(state.actions_today==2 and state.paid==240.0 and G.S.cash==380.0 and job.hold==0,"limit dwóch czynności dziennie pozostawia resztę linii graczowi")
	var copy: Dictionary=G.new_state()
	G._merge(copy,JSON.parse_string(JSON.stringify(G.S)))
	T.ok(copy.labstaff.actions_today==2 and copy.labstaff.paid==240.0,"zapis zachowuje umowę i dzienny limit asystenta")
	G.S=saved
	G.player.loc=loc
	G.player.global_position=pos
