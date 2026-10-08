extends RefCounted

static func run(T) -> void:
	var saved: Dictionary = G.S
	var busy: bool = G.busy
	G.S = G.new_state()
	G.S.lvl = 10
	G.S.props["garaz"] = true
	G.S.hide.garage.items = [{"f": "lab", "x": 0.0, "z": 0.0, "r": 0}]
	G.S.items["chemia"] = 4
	G.S.items["pakiet_procesowy"] = 0
	G.world.refresh_furniture("garage")
	G.busy = false
	var lab = G.main.lab_care
	var target_exists := false
	for target in G.world.inter_dyn.garage:
		if target.has("station") and target.has("menu"): target_exists = true
	T.ok(target_exists and G.main.lab_menu("garage", 0).size() == 4, "laboratorium ma własne menu czynności przy celowniku")
	T.ok(not lab.play("load", "garage", 0, "metamfetamina") and G.S.items.chemia == 4, "brak drugiego slotu blokuje wsad bez zabierania pierwszego")
	G.S.items.pakiet_procesowy = 1
	T.ok(lab.play("load", "garage", 0, "metamfetamina") and G.S.items.chemia == 2 and G.S.items.pakiet_procesowy == 0, "czynność wsadu zużywa wszystkie wymagane sloty tylko raz")
	T.ok(not lab.play("load", "garage", 0, "amfetamina") and G.S.items.chemia == 2, "pracującego laboratorium nie da się ponownie załadować")
	var job: Dictionary = G.Prod.job("garage", 0)
	T.ok(not lab.play("continue", "garage", 0), "czynność etapu jest zablokowana podczas pracy")
	job.prog = 0.4
	job.hold = 0
	T.ok(lab.play("continue", "garage", 0) and int(job.hold) == -1 and not lab.play("continue", "garage", 0), "czynność kontynuacji odblokowuje jeden etap i nie powtarza skutku")
	T.ok(not lab.play("collect", "garage", 0), "niedokończonej partii nie da się odebrać")
	job.prog = 1.0
	var forecast: Dictionary = G.Prod.forecast(job)
	T.ok(lab.play("collect", "garage", 0) and absf(G.goods_total(G.S.stash.garage) - float(forecast.g)) < 0.01 and not lab.play("collect", "garage", 0), "odbiór laboratoryjny dodaje partię do skrytki dokładnie raz")
	G.busy = true
	T.ok(not lab.play("load", "garage", 0, "amfetamina"), "trwająca czynność gracza blokuje uruchomienie drugiej")
	G.S = saved
	G.busy = busy
	G.world.refresh_furniture("garage")
