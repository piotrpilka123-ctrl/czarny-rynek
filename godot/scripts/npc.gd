extends Node3D
## Postacie: przechodnie, umówieni klienci, policja (piesze patrole i radiowóz),
## stali mieszkańcy osiedla, Wujek Staś, bezpański pies.

const Twist = preload("res://scripts/twist.gd")
const Props = preload("res://scripts/props.gd")
const Models = preload("res://scripts/models.gd")
const Chars = preload("res://scripts/chars.gd")

const COP_LOOK := {"kind": "police", "top": "c8e020", "top2": "141c30", "bottom": "141c30", "shoes": "0c0c0e", "hat": "police", "walk": "Walk_Formal"}
var _pool_m: Array = []
var _pool_f: Array = []
var _cop_i := 0
const CAR_ROUTE := [[-152.0, 20.0], [-106.0, 20.0], [-106.0, -130.0], [95.0, -130.0], [95.0, -66.0], [95.0, -130.0], [-106.0, -130.0], [-106.0, 20.0], [118.0, 20.0], [-106.0, 20.0], [-152.0, 20.0]]

var all: Array = []
var cops: Array = []
## strzały w pościgu: ile sekund uciekasz na widoku, etap (0 nic, 1 okrzyk, 2 po strzale ostrzegawczym), odstęp między strzałami
var flee_t := 0.0
var flee_stage := 0
var shot_cd := 0.0
var citizens: Array = []
var customers: Array = []
var statics: Array = []
var leavers: Array = []
var susp_mult := 0.0
var stasiu := {}
var car := {}
var dog := {}
var max_susp := 0.0          # najwyższe podejrzenie wśród widzących gracza (do HUD-u)
var aware: Array = []        # patrole, które właśnie zauważają gracza: {x, z, n, s, chase} (łuki na HUD-zie)


func build() -> void:
	for i in range(9):
		spawn_citizen(i)
	# patrole dochodzą z czasem gry (G.cop_quota) — pierwszego dnia ulice są puste
	_build_static()
	_build_outskirts()
	_build_car()
	_build_dog()


func _ang_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


func _h(x: float, z: float) -> float:
	return G.world.height(x, z)


# ---------------------------------------------------------------- przechodnie
func _roll_identity(n: Dictionary) -> void:
	n.name = (D.NAMES_F if n.female else D.NAMES_M).pick_random()
	n.user = randf() < 0.36
	n.wealth = randf_range(0.7, 1.2)
	n.ctype = ["luzak", "twardziel", "gadula", "konkret", "cwaniak", "impulsywny"].pick_random()
	n.loyalty = 0
	n.last_deal = -99999.0
	n.refused = false
	n.sting = false
	n.sting_rolled = false


func _random_node(public_only := true) -> int:
	var wp: Array = G.world.wp
	for _try in range(30):
		var i := randi_range(0, wp.size() - 1)
		if not public_only or not wp[i].quiet:
			return i
	return 0


## losuje model z puli tak, żeby się nie powtarzał, dopóki pula się nie wyczerpie
func _pick_model(female: bool) -> String:
	if _pool_m.is_empty():
		_pool_m = D.PEOPLE_M.duplicate()
		_pool_m.shuffle()
	if _pool_f.is_empty():
		_pool_f = D.PEOPLE_F.duplicate()
		_pool_f.shuffle()
	return String(_pool_f.pop_back()) if female else String(_pool_m.pop_back())


func spawn_citizen(idx := 0) -> Dictionary:
	var female := randf() < 0.42
	var o := {"female": female, "seed": randi(), "model": _pick_model(female)}
	var r := randf()
	if r < 0.4 and not female:
		o["kind"] = "dres"
		o["top"] = ["101114", "1c2330", "3a3f4a", "243a5e"].pick_random()
		o["bottom"] = o["top"] if randf() < 0.6 else "101114"
	if randf() < 0.3:
		o["hat"] = "beanie" if randf() < 0.5 else "cap"
	if not female and randf() < 0.25:
		o["beard"] = true
	var drunk := idx == 4
	if drunk:
		o["walk"] = "Zombie_Walk_Fwd"
		o["kind"] = "jacket"
	var rig: Dictionary = Chars.make(o)
	add_child(rig.root)
	var icon: Label3D = Models.label("●", Color(1.0, 0.85, 0.2), 40)
	icon.position = Vector3(0, rig.height + 0.3, 0)
	icon.visible = false
	rig.root.add_child(icon)
	var ni := _random_node()
	var w: Dictionary = G.world.wp[ni]
	var n := {
		"kind": "citizen", "loc": "out", "rig": rig, "node": rig.root, "female": female, "x": w.x, "z": w.z, "wi": ni, "pi": -1,
		"tx": w.x, "tz": w.z, "rot": 0.0, "speed": randf_range(1.05, 1.5) * (0.6 if drunk else 1.0), "idle": randf_range(0.0, 3.0), "state": "walk", "talk_t": 0.0,
		"idle_pose": "phone" if randf() < 0.35 else ("junkie" if drunk else ""), "reroll": randf_range(60.0, 160.0), "icon": icon, "active": true, "idx": idx, "drunk": drunk,
	}
	_roll_identity(n)
	n.interact = {"label": func(): return "Zagadaj: " + String(n.name), "range": 2.6, "act": func(): approach_citizen(n)}
	_pick_next(n, false)
	citizens.append(n)
	all.append(n)
	return n


func _pick_next(n: Dictionary, weighted: bool) -> void:
	var wp: Array = G.world.wp
	var cur: Dictionary = wp[n.wi]
	var opts := []
	for l in cur.links:
		if l == int(n.pi) and cur.links.size() > 1 and randf() < 0.9:
			continue
		if n.kind == "citizen" and wp[l].quiet and randf() < 0.8:
			continue
		opts.append(l)
	if opts.is_empty():
		opts = cur.links.duplicate()
	if opts.is_empty():
		return
	var pick: int = opts.pick_random()
	if weighted and opts.size() > 1:
		# policja chętniej patroluje „gorące” okolice
		var tot := 0.0
		var ws := []
		for op in opts:
			var w: float = 1.0 + G.zone_heat_at(wp[op].x, wp[op].z) / 18.0
			ws.append(w)
			tot += w
		var r := randf() * tot
		for i in range(opts.size()):
			r -= ws[i]
			if r <= 0.0:
				pick = opts[i]
				break
	n.pi = n.wi
	n.wi = pick
	n.tx = wp[pick].x + randf_range(-0.9, 0.9)
	n.tz = wp[pick].z + randf_range(-0.9, 0.9)


# ---------------------------------------------------------------- policja
func spawn_cop(at_station: bool) -> Dictionary:
	var look := COP_LOOK.duplicate()
	look["seed"] = randi()
	look["model"] = D.PEOPLE_COP[_cop_i % D.PEOPLE_COP.size()]
	_cop_i += 1
	var rig: Dictionary = Chars.make(look)
	add_child(rig.root)
	Chars.police_gear(rig)
	var alert: Label3D = Models.label("!", Color(1, 0.3, 0.3), 96)
	alert.position = Vector3(0, rig.height + 0.5, 0)
	alert.visible = false
	rig.root.add_child(alert)
	var ni = G.main.nav.nearest_node(-181.0 * D.SC, 13.5 * D.SC, false) if at_station else _random_node()
	var w: Dictionary = G.world.wp[ni]
	var c := {
		"kind": "cop", "loc": "out", "rig": rig, "node": rig.root, "x": w.x, "z": w.z, "wi": ni, "pi": -1, "tx": w.x, "tz": w.z,
		"rot": 0.0, "speed": 1.35, "state": "patrol", "side": 1.0, "susp": 0.0, "look_t": randf() * 0.2, "sees": false, "last_seen": 0.0, "idle": 0.0,
		"inv": null, "search_t": 0.0, "alert": alert, "post": false,
		"notice": 0.0, "lvl": 0.0, "hear_t": 0.0, "hear_rot": 0.0, "sp_wait": 0.0, "search_pts": [], "hunt": false, "lure": false, "know": false,
	}
	# latarka: nocą widać, gdzie patrol patrzy — i w jej snopie ciemność nie chroni
	# latarka wisi na szelce i z niej wychodzi snop; awaryjnie (inny szkielet) światło z wysokości piersi
	var torch: SpotLight3D = Chars.shoulder_torch(rig)
	var torch_own := torch == null
	if torch_own:
		torch = SpotLight3D.new()
		torch.position = Vector3(0.18, 1.32, 0.28)
		torch.rotation = Vector3(0.2, PI, 0.0)
	# światło słabnie z odległością jak prawdziwe (mocno przy latarce, resztka na końcu zasięgu), brzeg plamy jest miękki
	torch.spot_range = TORCH_RANGE + 7.0
	torch.spot_angle = rad_to_deg(TORCH_ANG)
	torch.spot_angle_attenuation = 0.85
	torch.spot_attenuation = 1.25
	torch.light_color = Color(0.9, 0.95, 1.0)
	torch.light_energy = 11.0
	torch.light_specular = 0.6
	torch.light_volumetric_fog_energy = 3.0
	torch.shadow_enabled = false
	torch.shadow_bias = 0.06
	torch.shadow_blur = 1.4
	Chars.torch_fx(torch, TORCH_ANG, TORCH_RANGE + 7.0)
	torch.distance_fade_enabled = true
	torch.distance_fade_begin = 60.0
	torch.distance_fade_length = 15.0
	torch.visible = false
	if torch_own:
		rig.root.add_child(torch)
	c["torch"] = torch
	c["torch_rot"] = torch.rotation
	# rozglądanie się: skręt barków i głowy (latarka na szelce idzie za nimi), każdy patrol we własnym rytmie
	var tw: SkeletonModifier3D = null
	if not torch_own and rig.get("skel") != null:
		tw = Twist.new()
		(rig.skel as Skeleton3D).add_child(tw)
		if not tw.bind(rig.skel):
			tw.queue_free()
			tw = null
	c["twist"] = tw
	c["scan"] = 0.0
	c["scan_amp"] = 0.0
	c["scan_ph"] = randf() * TAU
	c["scan_w"] = randf_range(0.8, 1.15)
	_pick_next(c, false)
	cops.append(c)
	all.append(c)
	return c


## Rozglądanie się patrolu: `amp` to połowa kąta, o jaki odwraca barki (i snop latarki) od kierunku marszu.
func _scan(c: Dictionary, dt: float, amp: float) -> void:
	c.scan_amp = lerpf(float(c.scan_amp), amp, minf(1.0, dt * 1.8))
	var a: float = float(c.scan_amp)
	var st: float = G.now * float(c.scan_w) + float(c.scan_ph)
	# dwa nałożone rytmy: wolny przegląd terenu i krótsze zerknięcia, żeby ruch nie był mechaniczny
	var yaw: float = a * (sin(st) * 0.78 + sin(st * 2.3 + 1.1) * 0.22)
	c.scan = yaw
	var base: Vector3 = c.torch_rot
	var tw = c.get("twist")
	if tw != null:
		tw.yaw = yaw
		# sama latarka kiwa się lekko góra–dół: raz świeci pod nogi, raz dalej
		c.torch.rotation = Vector3(base.x + sin(st * 1.6 + 0.5) * a * 0.14, base.y, base.z)
	else:
		c.torch.rotation = Vector3(base.x + sin(st * 1.6 + 0.5) * a * 0.14, base.y + yaw, base.z)


func remove_cop(c: Dictionary) -> void:
	cops.erase(c)
	all.erase(c)
	c.node.queue_free()


# ---------------------------------------------------------------- stali mieszkańcy
func _static(o: Dictionary) -> Dictionary:
	var look: Dictionary = o.get("look", {}).duplicate()
	if not look.has("seed"):
		look["seed"] = randi()
	var rig: Dictionary = Chars.make(look)
	add_child(rig.root)
	var loc: String = o.get("loc", "out")
	var x: float = float(o.x) * (D.SC if loc == "out" else 1.0)
	var z: float = float(o.z) * (D.SC if loc == "out" else 1.0)
	rig.root.position = Vector3(x, (0.0 if loc != "out" else _h(x, z)) + float(o.get("y", 0.0)), z)
	rig.root.rotation.y = o.get("rot", 0.0)
	var n := {"kind": "static", "loc": loc, "rig": rig, "node": rig.root, "x": x, "z": z, "name": o.get("name", ""), "pose": o.get("pose", ""), "track": o.get("track", false),
		"hours": o.get("hours", []), "rot0": float(o.get("rot", 0.0)), "lines": o.get("lines", [])}
	if o.has("label"):
		var lb: Label3D = Models.label(o.label, Color(1, 0.9, 0.55), 36)
		lb.position = Vector3(0, rig.height + 0.25, 0)
		lb.visibility_range_end = 9.0
		rig.root.add_child(lb)
	if o.has("act"):
		n.interact = {"label": func(): return "Zagadaj: " + String(n.name), "range": o.get("range", 2.6), "act": o.act}
	elif not n.lines.is_empty():
		n.interact = {"label": func(): return "Zagadaj: " + String(n.name), "range": 2.6, "act": func(): G.ui.dialog({"name": n.name, "lines": [n.lines.pick_random()]})}
	Chars.animate(rig, 0.0, 0.0, n.pose)
	statics.append(n)
	all.append(n)
	return n


## życie podwórka: sąsiad przy grillu (po południu), chłopaki na kanapie pod blokiem (wieczorem)
func _build_yard() -> void:
	var grill := _static({"x": 31.9, "z": -74.6, "rot": -2.2, "pose": "talk", "name": "Pan Rysiek", "label": "Pan Rysiek", "hours": [14.0, 21.0],
		"look": {"model": "m14", "kind": "tshirt", "top": "e8e4d8", "bottom": "3a4a5a", "seed": 501, "build": 1.15},
		"lines": ["Kiełbaska dochodzi, sąsiad. Jeszcze pięć minut i będzie w sam raz.", "Wiosna przyszła, to się grilluje. Żona mówi, że dymię — a co mam robić?",
			"Ty z siódemki? Spokojny chłopak. Tylko późno wracasz.", "Widziałeś tych nowych spod trójki? Kręcą się tu nocami. Uważaj na nich."]})
	# dym z grilla idzie w górę razem z sąsiadem (znika, kiedy on znika)
	var smoke = Props._particles(10, 3.0, 0.5, false, [Color(1, 1, 1, 0.0), Color(0.9, 0.9, 0.9, 0.22), Color(0.8, 0.8, 0.8, 0.1), Color(0.7, 0.7, 0.7, 0.0)], Vector2(0.3, 0.7), 0.12, true)
	grill.node.add_child(smoke)
	smoke.global_position = Vector3(31.0 * D.SC, _h(31.0 * D.SC, -75.4 * D.SC) + 0.85, -75.4 * D.SC)
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.45, 0.15)
	gl.light_energy = 0.7
	gl.omni_range = 2.6
	gl.shadow_enabled = false
	grill.node.add_child(gl)
	gl.global_position = smoke.global_position
	# (siedzą bliżej przedniej krawędzi kanapy — wcześniej nogi wchodziły im w siedzisko)
	for e in [[21.4, -69.38, "sit_talk", "Łysy", "m02"], [22.6, -69.36, "sit", "Młody", "m16"]]:
		_static({"x": float(e[0]), "z": float(e[1]), "rot": 0.08, "pose": String(e[2]), "name": String(e[3]), "hours": [17.0, 2.0],
			"look": {"model": String(e[4]), "seed": 510 + int(float(e[0]) * 3.0)},
			"lines": ["Siema. Siadaj, miejsce jest.", "Masz ognia? Nie? To po co podchodzisz.", "Ta kanapa stoi tu dłużej niż ty żyjesz, szanuj.", "Jak coś ci zginie spod klatki, to nie my. My tu tylko siedzimy.",
				"Psy jeździły godzinę temu. Dwa kółka i pojechali."]})


## Obozowisko bezdomnych za garażami i posterunek przy zamkniętym tunelu.
func _build_outskirts() -> void:
	var cx: float = G.world.CAMP.x
	var cz: float = G.world.CAMP.y
	_static({"x": cx - 1.9, "z": cz + 0.9, "y": 0.02, "rot": 2.0, "pose": "sit_talk", "name": "Pan Tadek", "label": "Pan Tadek",
		"look": {"model": "m11", "kind": "hoodie", "top": "4a4436", "bottom": "2c2a28", "seed": 811, "build": 0.95},
		"lines": ["Siadaj, młody, ogień jest dla wszystkich. Tylko nie stój pod wiatr, bo ten plastik gryzie w oczy.", "Trzydzieści lat na walcowni. Hutę zamknęli, mieszkanie poszło za długi. Teraz mam ognisko i widok na garaże.",
			"Policja? Przyjeżdżają raz na tydzień, popatrzą i jadą. Dopóki się nie bijemy, mają nas gdzieś.", "Jak masz butelki, to zostaw przy wózku. Skup bierze po trzydzieści groszy.",
			"Widziałem tych, co kręcą się nocą przy skrytkach. Ja nic nie mówię. Ja tylko patrzę w ogień."]})
	_static({"x": cx + 1.3, "z": cz - 1.0, "rot": -2.2, "pose": "arms", "name": "Mietek", "label": "Mietek", "hours": [15.0, 9.0],
		"look": {"model": "m05", "kind": "hoodie", "top": "3a3f4a", "bottom": "33302c", "seed": 823, "build": 1.05},
		"lines": ["Zimno, nie? Fotel ogrodowy pali się dłużej niż deska. Tylko śmierdzi.", "Nie mam nic, szefie. Ale jak coś znajdziesz w śmietniku i ci niepotrzebne — wiesz, gdzie mieszkam.",
			"Ten wózek to cały mój dom. Nie ruszaj.", "W nocy lepiej tędy nie chodź z pełnymi kieszeniami. Nie wszyscy tu są tacy mili jak Tadek."]})
	_static({"x": cx + 4.1, "z": cz + 2.7, "rot": 0.5, "pose": "kneel", "name": "Baśka", "hours": [20.0, 7.0],
		"look": {"model": "f08", "female": true, "seed": 837},
		"lines": ["Ciszej. Niektórzy tu próbują spać.", "Daj spokój. Jutro też jest dzień."]})
	# posterunek przy zamkniętym tunelu: droga nieprzejezdna, trwają prace
	_static({"x": -194.6, "z": 20.6, "rot": PI / 2.0, "pose": "arms", "name": "Posterunkowy Wrona", "label": "Posterunkowy Wrona", "track": true,
		"look": COP_LOOK.merged({"seed": 905, "model": D.PEOPLE_COP[0]}), "cop": true,
		"lines": ["Droga zamknięta. W tunelu trwają prace — zawalił się kanał wentylacyjny.", "Nie wiem, do kiedy. Miesiąc, może dwa. Proszę zawrócić.",
			"Objazdu nie ma. Kto chce wyjechać z dzielnicy, ten poczeka jak wszyscy.", "Nie kręć się tu. Za barierki wstęp wzbroniony."]})


## klub Neon od środka: barman, DJ i imprezowicze na parkiecie, którzy kupują od ręki
func _build_club() -> void:
	var R: Dictionary = D.ROOMS.club
	var cx: float = R.cx
	var fx := cx - 2.2
	var fz := -1.2
	_static({"loc": "club", "x": cx + float(R.w) * 0.5 - 0.95, "z": -1.3, "rot": -PI / 2.0, "pose": "arms", "name": "Barman Igor", "label": "Barman Igor", "track": true, "range": 3.2,
		"look": {"model": "m07", "kind": "shirt", "top": "101014", "bottom": "101014", "beard": true, "seed": 61}, "act": func(): G.main.club_bar()})
	_static({"loc": "club", "x": fx, "z": -float(R.d) * 0.5 + 0.5, "rot": 0.0, "pose": "dance", "name": "DJ Mrok",
		"look": {"model": "m11", "kind": "tshirt", "top": "1a1a1e", "bottom": "15151a", "hat": "cap", "seed": 62},
		"lines": ["*pokazuje na słuchawki i kręci głową*", "Nie teraz, leci set!", "Zagadaj po trzeciej, jak zejdę z konsolety."]})
	var names := ["Kinga", "Patryk", "Sandra", "Dawid", "Oliwia", "Kamil", "Wera", "Bartek", "Julka", "Mati"]
	var spots := [[-2.0, -1.0], [-0.6, 0.4], [1.2, -0.8], [2.2, 0.9], [-1.4, 1.2], [0.4, -1.6], [0.9, 1.5], [-2.4, 0.3], [2.4, -1.5], [-0.2, -0.5]]
	# każdy tańczy po swojemu: inna odmiana kroku, inne tempo, inny moment taktu
	var moves := ["dance", "dance3", "dance5", "dance2", "dance4", "dance", "dance6", "dance3", "dance5", "dance2"]
	var rg := RandomNumberGenerator.new()
	rg.seed = 9041
	for k in range(spots.size()):
		var fem: bool = k % 2 == 0
		var n := _static({"loc": "club", "x": fx + float(spots[k][0]), "z": fz + float(spots[k][1]), "rot": rg.randf() * TAU, "pose": moves[k], "name": names[k], "range": 2.4,
			"look": {"model": (D.PEOPLE_F if fem else D.PEOPLE_M)[rg.randi() % 11], "female": fem, "seed": 300 + k}, "act": func(): pass})
		n["wealth"] = rg.randf_range(1.15, 1.5)
		n["want"] = ["szron", "snieg", "dym", "krysztal"][rg.randi() % 4]
		n["user"] = true
		n["anim_speed"] = rg.randf_range(0.82, 1.22)
		n.rig.anim.seek(rg.randf() * 4.0, true)
		n.interact.act = func(): G.main.club_buyer(n)
	# ludzie przy stolikach: stoją z drinkiem, gadają
	for e in [[2.9, 2.6, 2.4, "talk", "Seba z ekipą"], [1.9, 2.3, -0.7, "dance4", "Paula"], [5.1, 3.5, 2.9, "arms", "Rysiek"], [-3.7, 4.3, 0.9, "talk", "Aga"], [-4.7, 4.1, -1.2, "dance4", "Ziomek Agi"]]:
		var s2 := _static({"loc": "club", "x": cx + float(e[0]), "z": float(e[1]), "rot": float(e[2]), "pose": String(e[3]), "name": String(e[4]),
			"look": {"model": (D.PEOPLE_F if String(e[4]).ends_with("a") else D.PEOPLE_M)[rg.randi() % 11], "female": String(e[4]).ends_with("a"), "seed": 340 + rg.randi() % 50},
			"lines": ["Co?! Nie słyszę!", "Najlepsza impreza w mieście, mówię ci.", "Stary, widziałeś, kto siedzi w loży? Sama śmietanka.", "Postaw kolejkę, to pogadamy."]})
		s2["anim_speed"] = rg.randf_range(0.85, 1.1)
	# loża VIP: szychy na kanapach, ochroniarz przy linie
	var xw := cx - float(R.w) * 0.5
	var vx := xw + 1.45
	var vz := -float(R.d) * 0.5 + 1.7
	var vips := [
		[vx - 0.94, vz + 0.95, PI / 2.0, "sit_talk", "Prezes Malinowski", "mb4", false],
		[vx - 0.94, vz + 0.1, PI / 2.0, "sit", "Mecenas Wrona", "mb7", false],
		[vx + 0.0, vz - 1.19, 0.0, "sit_talk", "Pani Ilona", "fb2", true],
		[vx + 0.9, vz - 1.19, 0.0, "sit", "Radny Koziej", "mg1", false],
	]
	for e in vips:
		var v := _static({"loc": "club", "x": float(e[0]), "z": float(e[1]), "y": 0.25, "rot": float(e[2]), "pose": String(e[3]), "name": String(e[4]), "label": String(e[4]), "range": 3.8,
			"look": {"model": String(e[5]), "female": bool(e[6]), "seed": 400 + rg.randi() % 50}, "act": func(): pass})
		v["wealth"] = rg.randf_range(1.9, 2.3)
		v["want"] = "snieg"
		v["vip"] = true
		v["user"] = true
		v["anim_speed"] = rg.randf_range(0.8, 1.0)
		v.interact.act = func(): G.main.club_buyer(v)
	_static({"loc": "club", "x": vx + 1.9, "z": vz + 1.95, "rot": PI * 0.75, "pose": "arms", "name": "Ochroniarz loży",
		"look": {"model": "sm1", "tall": 1.06, "bald": true, "build": 1.2, "seed": 77},
		"lines": ["Loża tylko dla gości. Gadaj zza liny, jak chcą z tobą gadać.", "Ręce przy sobie i żadnych numerów.", "Prezes nie lubi, jak mu się przeszkadza. Chyba że masz coś dobrego."]})

func remove_static(n: Dictionary) -> void:
	statics.erase(n)
	all.erase(n)
	if n.get("node") != null and is_instance_valid(n.node):
		n.node.queue_free()


func _build_static() -> void:
	var sx: float = D.ROOMS.shop.cx
	stasiu = _static({"x": sx, "z": -2.3, "loc": "shop", "name": "Wujek Staś", "label": "Wujek Staś", "track": true, "range": 3.4,
		"look": {"model": "m03", "kind": "shirt", "top": "5b6b4a", "bottom": "2b2622", "hair": "hair_simpleparted", "hair_color": "9a9a9a", "beard": true, "skin": 0.85, "build": 1.15, "height": 1.74, "seed": 3},
		"act": func(): G.main.talk_stasiu()})
	# ochroniarze klubu
	for z in [124.9, 131.1]:
		_static({"x": -6.2, "z": z, "rot": PI / 2.0, "pose": "arms", "name": "Ochroniarz", "hours": [D.CLUB_OPEN - 0.5, D.CLUB_CLOSE + 0.5],
			"look": {"model": "sm1", "tall": 1.07, "kind": "jacket", "top": "0b0b0d", "bottom": "0b0b0d", "shoes": "0c0c0e", "bald": true, "build": 1.2, "height": 1.93, "seed": int(z)},
			"range": 3.0, "act": func(): G.main.club_door()})
	_build_club()
	_build_yard()
	# szpital i komenda
	var hx: float = D.ROOMS.szpital.cx
	_static({"loc": "szpital", "x": hx + 1.25, "z": 0.2, "rot": PI * 1.2, "pose": "arms", "name": "Pielęgniarka", "label": "Pielęgniarka", "track": true,
		"look": {"model": "f07", "female": true, "kind": "shirt", "top": "e8f0ee", "bottom": "dfe8e6", "shoes": "f0f0f0", "seed": 41},
		"lines": ["Leż spokojnie, dopóki nie zakręci Ci się w głowie.", "Następnym razem może nie być tyle szczęścia.", "Wyjście korytarzem prosto. I uważaj na siebie."]})
	var kx: float = D.ROOMS.komisariat.cx
	var duty := COP_LOOK.duplicate()
	duty["model"] = D.PEOPLE_COP[1]
	duty["seed"] = 52
	duty.erase("hat")
	_static({"loc": "komisariat", "x": kx + 1.9, "z": -float(D.ROOMS.komisariat.d) * 0.5 + 0.75, "rot": 0.0, "pose": "arms", "name": "Dyżurny", "label": "Dyżurny", "track": true, "look": duty,
		"lines": ["Wypuszczony? To zjeżdżaj, zanim się rozmyślę.", "Jeszcze się zobaczymy. Zawsze się widzimy.", "Depozytu nie wydajemy. Zwłaszcza takiego."]})
	# sprzedawczyni w „Taniej Odzieży”
	_static({"loc": "ciuchy", "x": float(D.ROOMS.ciuchy.cx) + float(D.ROOMS.ciuchy.w) * 0.5 - 1.3, "z": -float(D.ROOMS.ciuchy.d) * 0.5 + 0.55, "rot": 0.0, "pose": "arms", "name": "Pani Grażyna",
		"label": "Pani Grażyna", "look": {"model": "f12", "female": true, "seed": 77}, "range": 3.2, "act": func(): G.main.talk_clothes()})
	# wspólnik w laboratorium (prolog)
	_static({"loc": "lab", "x": float(D.ROOMS.lab.cx) + 4.6, "z": -3.1, "rot": PI * 0.9, "pose": "arms", "name": "Siwy", "look": D.SIWY_LOOK, "track": true,
		"lines": ["Pakuj torbę i spadamy. Wiktor czeka do szóstej."]})
	# ekipa spod klatki bloku 5
	_static({"x": -55.5, "z": -76.05, "rot": 0.0, "pose": "sit", "name": "Młody", "y": 0.0,
		"look": {"model": "m16", "kind": "dres", "top": "1c2330", "top2": "e8e6e0", "bottom": "1c2330", "stripes": true, "hat": "cap", "hat_color": "101114", "seed": 31},
		"lines": ["Słyszałeś, jak huta poszła w powietrze? Szyby leciały na pół osiedla.", "Podobno Siwego zgarnęli pod hutą. Uważaj na psy, kręcą się tu co wieczór.", "Masz szluga?"]})
	_static({"x": -57.6, "z": -75.0, "rot": 0.9, "pose": "arms", "name": "Łysy",
		"look": {"model": "mb7", "kind": "dres", "top": "101114", "top2": "b0382c", "bottom": "101114", "stripes": true, "bald": true, "build": 1.12, "seed": 32},
		"lines": ["Czego?", "Tu się nie stoi bez powodu.", "Jak będziesz coś miał, to wiesz, gdzie nas szukać."]})
	_static({"x": -54.1, "z": -74.6, "rot": -0.7, "pose": "crouch", "name": "Mati",
		"look": {"model": "m09", "kind": "hoodie", "top": "3a3f4a", "bottom": "101114", "hat": "beanie", "hat_color": "101114", "seed": 33},
		"lines": ["Ej, ty, nowy. Podobno Wiktor ci daje towar?", "Słonecznika chcesz?", "Radiowóz jeździ w kółko: Hutnicza, rampa, osiedle. Zapamiętaj."]})
	# emeryt w parku
	_static({"x": -88.0, "z": 63.85, "rot": 0.4, "pose": "sit", "name": "Pan Henryk",
		"look": {"model": "mg1", "kind": "jacket", "top": "55504a", "bottom": "3b3630", "hair": "hair_buzzed", "hair_color": "d8d2c4", "hat": "cap", "hat_color": "3a3530", "build": 1.05, "height": 1.7, "seed": 34},
		"lines": ["Jak huta stała, to tu było życie. A teraz? Sam pan widzi.", "Trzydzieści lat przy piecu. I co mi z tego zostało?", "Kiedyś to na tej górce saneczki, festyny… Dziś strach wieczorem wyjść."]})
	# pijaczek pod monopolowym
	_static({"x": 33.4, "z": 11.2, "rot": 0.3, "pose": "junkie", "name": "Zdzichu",
		"look": {"model": "m07", "kind": "jacket", "top": "4a4538", "bottom": "2b2622", "beard": true, "hair": "hair_simpleparted", "hair_color": "7a7a7a", "seed": 35},
		"lines": ["Kierowniku… poratuj złotówką…", "Ja tu wszystko widzę. Wszyściutko. Ale nic nie mówię.", "Zimno dziś, co?"]})
	# potencjalni klienci „z rozmowy”
	_static({"x": 96.2, "z": 86.2, "rot": 1.2, "pose": "kneel", "name": "Marek", "label": "Marek — mechanik",
		"look": G.cust_def("marek").look, "act": func(): _talk_meet("marek")})
	_static({"x": 170.6, "z": 31.6, "rot": -2.4, "pose": "arms", "name": "Kowal", "label": "Kowal — stróż",
		"look": G.cust_def("kowal").look, "act": func(): _talk_meet("kowal")})
	_static({"x": -6.4, "z": 133.4, "rot": 1.4, "pose": "phone", "name": "Ola", "label": "Ola — barmanka", "hours": [17, 4],
		"look": G.cust_def("ola").look, "act": func(): _talk_meet("ola")})
	# towarzystwo pod klubem (tylko nocą)
	var cl := [[8.2, 120.6, -2.2, "talk"], [9.4, 121.9, -1.2, ""], [8.0, 122.8, -0.4, "talk"], [10.6, 133.0, 2.9, "phone"]]
	for i in range(cl.size()):
		_static({"x": cl[i][0], "z": cl[i][1], "rot": cl[i][2], "pose": cl[i][3], "name": ["Imprezowicz", "Imprezowiczka"][i % 2], "hours": [20, 4],
			"look": {"model": ["m06", "fp1", "m12", "f17"][i], "female": i % 2 == 1, "kind": ["jacket", "tank", "hoodie", "jacket"][i], "seed": 40 + i},
			"lines": ["Ale dziś gra!", "Masz ogień?", "Znasz kogoś, kto coś ma? …A, nieważne.", "Ochrona dziś nie w humorze."]})
	# kobieta na przystanku
	_static({"x": 67.6, "z": 10.9, "rot": 0.2, "pose": "phone", "name": "Kobieta na przystanku", "hours": [6, 21],
		"look": {"model": "fb3", "female": true, "kind": "coat", "top": "5a2f52", "bottom": "101114", "seed": 46},
		"lines": ["Sto dwójka znowu spóźniona.", "Przepraszam, śpieszę się.", "Tu od tygodnia nie świeci latarnia. I komu to zgłosić?"]})


func _talk_meet(id: String) -> void:
	var line := String(G.meet(id))
	G.ui.dialog({"name": G.cust_def(id).name, "lines": [line]})


# ---------------------------------------------------------------- radiowóz
func _build_car() -> void:
	var node: Node3D = Models.car("sedan", "d9dde2", true)
	add_child(node)
	var blue := OmniLight3D.new()
	blue.light_color = Color(0.2, 0.4, 1.0)
	blue.light_energy = 3.0
	blue.omni_range = 16.0
	blue.position = Vector3(0, 1.8, 0)
	blue.visible = false
	node.add_child(blue)
	# reflektory: dwa snopy przed maską, zapalane po zmroku
	var heads: Array = []
	for sx in [-0.55, 0.55]:
		var hl := SpotLight3D.new()
		hl.position = Vector3(sx, 0.68, 2.1)
		hl.rotation = Vector3(-0.06, PI, 0.0)
		hl.spot_range = 26.0
		hl.spot_angle = 30.0
		hl.spot_attenuation = 1.1
		hl.light_color = Color(1.0, 0.95, 0.82)
		hl.light_energy = 5.0
		hl.shadow_enabled = false
		hl.visible = false
		node.add_child(hl)
		heads.append(hl)
	car = {"node": node, "x": CAR_ROUTE[0][0] * D.SC, "z": CAR_ROUTE[0][1] * D.SC, "rot": PI / 2.0, "seg": 0, "wait": 30.0, "susp": 0.0, "sees": false, "alarm": false, "light": blue, "look_t": 0.0, "speed": 0.0,
		"heads": heads, "wheels": node.get_meta("wheels", []), "domes": node.get_meta("siren", []), "kturn": 0.0}
	node.position = Vector3(car.x, _h(car.x, car.z), car.z)


## koguty na dachu: klosze migają na zmianę, niebieska poświata razem z nimi
func _car_flash(on: bool) -> void:
	var ph := fmod(G.now * 4.0, 1.0) < 0.5
	car.light.visible = on and ph
	var domes: Array = car.domes
	for i in range(domes.size()):
		(domes[i] as Node3D).visible = on and (ph if i == 0 else not ph)


func _update_car(dt: float, pp: Vector3, outside: bool) -> void:
	var node: Node3D = car.node
	node.visible = outside
	if not outside:
		return
	var dist := Vector2(pp.x - car.x, pp.z - car.z).length()
	car.look_t = float(car.look_t) - dt
	if float(car.look_t) <= 0.0:
		car.look_t = 0.25
		car.sees = see_level(car.x, car.z, float(car.rot), 30.0, true) > 0.0
	for hl in car.heads:
		(hl as Light3D).visible = G.night > 0.35
	if car.alarm:
		_car_flash(true)
		if not G.S.wanted:
			car.alarm = false
			_car_flash(false)
			car.wait = 4.0
		return
	if car.sees and susp_mult > 0.0:
		car.susp = float(car.susp) + susp_mult * dt * 0.7
		max_susp = maxf(max_susp, float(car.susp))
		if float(car.susp) >= 1.0:
			car.alarm = true
			car.susp = 0.0
			Sfx.play("door")
			for i in range(2):
				var c := spawn_cop(false)
				c.x = car.x + (1.6 if i == 0 else -1.6) * cos(float(car.rot))
				c.z = car.z - (1.6 if i == 0 else -1.6) * sin(float(car.rot))
				c.temp = true
				c.susp = 1.0
				start_chase(c)
			return
	else:
		car.susp = maxf(0.0, float(car.susp) - dt * 0.3)
	if float(car.wait) > 0.0:
		car.wait = float(car.wait) - dt
		car.speed = move_toward(float(car.speed), 0.0, dt * 5.0)
		_car_move(dt)
		return
	# Jazda jak autem, nie jak pionkiem po sznurku: radiowóz jedzie tam, dokąd patrzy maska, skręca stopniowo,
	# trzyma się prawego pasa, zwalnia przed zakrętem i przed człowiekiem, a na końcu trasy zawraca „na trzy”.
	var n := CAR_ROUTE.size()
	var pa: Array = CAR_ROUTE[int(car.seg) % n]
	var pb: Array = CAR_ROUTE[(int(car.seg) + 1) % n]
	var a := Vector2(pa[0], pa[1]) * D.SC
	var b := Vector2(pb[0], pb[1]) * D.SC
	var seg_len := maxf(0.01, (b - a).length())
	var dirv := (b - a) / seg_len
	var right := Vector2(-dirv.y, dirv.x)
	var pos := Vector2(car.x, car.z)
	var done: float = (pos - a).dot(dirv)
	if seg_len - done < 2.4:
		car.seg = (int(car.seg) + 1) % n
		if int(car.seg) == 0 or int(car.seg) == n - 1:
			car.wait = randf_range(50.0, 110.0) * G.car_pause()
		elif int(car.seg) == 4:
			car.wait = randf_range(8.0, 20.0)
		return
	var aim: Vector2 = a + dirv * clampf(done + 5.5, 0.0, seg_len) + right * CAR_LANE
	var diff := _ang_diff(atan2(aim.x - pos.x, aim.y - pos.y), float(car.rot))
	var fwd_v := Vector2(sin(float(car.rot)), cos(float(car.rot)))
	if absf(diff) > 1.9 or (float(car.kturn) > 0.0 and absf(diff) > 0.45):
		# cel jest za plecami: zawracanie na trzy, na przemian do przodu i do tyłu — aż maska spojrzy wzdłuż ulicy
		car.kturn = float(car.kturn) + dt
		var ahead: bool = fmod(float(car.kturn), 3.0) < 1.6
		car.speed = lerpf(float(car.speed), 1.5 if ahead else -1.5, minf(1.0, dt * 3.5))
		car.rot = float(car.rot) + signf(diff) * dt * 0.8
	else:
		car.kturn = 0.0
		var vmax := 7.2 * clampf(1.0 - absf(diff) * 0.9, 0.32, 1.0)
		vmax = minf(vmax, 2.2 + (seg_len - done) * 0.5)
		# człowiek tuż przed maską: hamuje, nie rozjeżdża
		var top := Vector2(pp.x - car.x, pp.z - car.z)
		if top.length() < 7.0 and top.normalized().dot(fwd_v) > 0.8:
			vmax = 0.0
		var sp := float(car.speed)
		car.speed = move_toward(sp, vmax, dt * (2.4 if vmax > sp else 6.0))
		car.rot = float(car.rot) + clampf(diff * 2.4, -1.1, 1.1) * clampf(absf(float(car.speed)) / 4.0, 0.12, 1.0) * dt
	_car_move(dt)


const CAR_LANE := 1.05        # metr z hakiem w prawo od osi jezdni

func _car_move(dt: float) -> void:
	var node: Node3D = car.node
	var sp := float(car.speed)
	car.x += sin(float(car.rot)) * sp * dt
	car.z += cos(float(car.rot)) * sp * dt
	var fx := sin(float(car.rot))
	var fz := cos(float(car.rot))
	var yf := _h(car.x + fx * 1.3, car.z + fz * 1.3)
	var yb := _h(car.x - fx * 1.3, car.z - fz * 1.3)
	var yl := _h(car.x + fz * 0.75, car.z - fx * 0.75)
	var yr := _h(car.x - fz * 0.75, car.z + fx * 0.75)
	node.position = Vector3(car.x, (yf + yb) * 0.5, car.z)
	node.rotation = Vector3(-atan2(yf - yb, 2.6), float(car.rot), atan2(yr - yl, 1.5) * 0.6)
	for w in car.wheels:
		(w as Node3D).rotate_object_local(Vector3.UP, sp * dt / 0.31)


# ---------------------------------------------------------------- pies
func _build_dog() -> void:
	var ps: PackedScene = load("res://assets/props/dog.gltf")
	if ps == null:
		return
	var node: Node3D = ps.instantiate()
	add_child(node)
	var ap: AnimationPlayer = node.find_child("AnimationPlayer", true, false)
	if ap != null:
		for nm in ["Walk", "Idle", "Idle_2", "Eating", "Run"]:
			if ap.has_animation(nm):
				ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
	var ni = G.main.nav.nearest_node(-20.0 * D.SC, -104.0 * D.SC, false)
	var w: Dictionary = G.world.wp[ni]
	dog = {"kind": "dog", "node": node, "anim": ap, "x": w.x, "z": w.z, "wi": ni, "pi": -1, "tx": w.x, "tz": w.z, "rot": 0.0, "idle": 2.0, "cur": ""}
	node.scale = Vector3(0.9, 0.9, 0.9)


func _dog_play(a: String) -> void:
	if dog.cur != a and dog.anim != null and dog.anim.has_animation(a):
		dog.cur = a
		dog.anim.play(a, 0.3)


func _update_dog(dt: float, pp: Vector3, outside: bool) -> void:
	if dog.is_empty():
		return
	dog.node.visible = outside
	if not outside:
		return
	if float(dog.idle) > 0.0:
		dog.idle = float(dog.idle) - dt
		_dog_play("Eating" if int(dog.wi) % 3 == 0 else "Idle")
	else:
		var to := Vector2(float(dog.tx) - float(dog.x), float(dog.tz) - float(dog.z))
		var d := to.length()
		if d < 0.4:
			if randf() < 0.4:
				dog.idle = randf_range(3.0, 9.0)
			var wp: Array = G.world.wp
			var links: Array = wp[dog.wi].links
			var opts := []
			for l in links:
				if l != int(dog.pi) and wp[l].z < -20.0 * D.SC:
					opts.append(l)
			if opts.is_empty():
				opts = links
			dog.pi = dog.wi
			dog.wi = opts.pick_random()
			dog.tx = wp[dog.wi].x + randf_range(-2.5, 2.5)
			dog.tz = wp[dog.wi].z + randf_range(-2.5, 2.5)
		else:
			dog.x = float(dog.x) + to.x / d * 1.5 * dt
			dog.z = float(dog.z) + to.y / d * 1.5 * dt
			dog.rot = atan2(to.x, to.y)
			_dog_play("Walk")
	dog.node.rotation.y += _ang_diff(float(dog.rot), dog.node.rotation.y) * minf(1.0, dt * 5.0)
	dog.node.position = Vector3(float(dog.x), _h(float(dog.x), float(dog.z)), float(dog.z))
	if dog.anim != null:
		dog.anim.active = Vector2(pp.x - float(dog.x), pp.z - float(dog.z)).length() < 60.0


# ---------------------------------------------------------------- klienci umówieni
static func _path_len(pts: Array) -> float:
	var l := 0.0
	for i in range(pts.size() - 1):
		l += (pts[i + 1] as Vector2).distance_to(pts[i])
	return l


func _home_of(def: Dictionary) -> Vector2:
	var h: Dictionary = D.HOMES.get(def.get("home", "blok5"), D.HOMES.blok5)
	return Vector2(float(h.x), float(h.z))


## Klient wychodzi z domu tak, żeby dojść na miejsce parę minut przed umówioną godziną.
func spawn_customer(order: Dictionary) -> void:
	for c in customers:
		if int(c.order.id) == int(order.id):
			return
	var def := G.cust_def(order.cust)
	var spot := G.spot_def(order.spot)
	var goal := Vector2(float(spot.x) + randf_range(-0.5, 0.5), float(spot.z) + randf_range(-0.5, 0.5))
	var path: Array = G.main.nav.path_between(_home_of(def), goal)
	var n := {"kind": "customer", "loc": "out", "rig": null, "node": null, "x": goal.x, "z": goal.y, "rot": randf() * TAU, "order": order, "def": def, "name": def.name,
		"state": "pending", "path": path, "pi": 1, "goal": goal, "idle": 0.0, "pose": "phone" if randf() < 0.5 else ("arms" if randf() < 0.4 else ""), "marker": null, "speed": randf_range(1.25, 1.45)}
	customers.append(n)
	reschedule(int(order.id))
	if G.S.t >= float(order.meet) - 3.0:
		_customer_enter(n, true)


func reschedule(order_id: int) -> void:
	for n in customers:
		if int(n.order.id) == order_id:
			if n.node != null:
				continue
			# gdy do spotkania jest mniej czasu niż trwa droga z domu, klient „jest już w drodze”:
			# zaczyna z takiego miejsca trasy, żeby dojść kilka minut przed czasem
			var avail := maxf(6.0, float(n.order.meet) - G.S.t - 6.0)
			var keep := float(n.speed) * avail / D.TIME_SCALE
			if _path_len(n.path) > keep:
				n.path = _path_tail(n.path, keep)
				n.pi = 1
			var travel := _path_len(n.path) / float(n.speed) * D.TIME_SCALE
			n.spawn_at = float(n.order.meet) - travel - randf_range(3.0, 7.0)


## końcówka trasy o zadanej długości (punkt startu wypada w środku odcinka)
static func _path_tail(pts: Array, keep: float) -> Array:
	var out: Array = [pts[pts.size() - 1]]
	var left := keep
	var i := pts.size() - 1
	while i > 0 and left > 0.0:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i - 1]
		var d := a.distance_to(b)
		if d >= left:
			out.push_front(a.lerp(b, left / maxf(0.001, d)))
			return out
		out.push_front(b)
		left -= d
		i -= 1
	return out


func _customer_enter(n: Dictionary, at_spot := false) -> void:
	var def: Dictionary = n.def
	var look: Dictionary = def.get("look", {}).duplicate()
	var rig: Dictionary = Chars.make(look)
	add_child(rig.root)
	var start: Vector2 = n.goal if at_spot else n.path[0]
	n.x = start.x
	n.z = start.y
	rig.root.position = Vector3(n.x, _h(n.x, n.z), n.z)
	var lb: Label3D = Models.label(def.name, Color(0.6, 1.0, 0.7), 38)
	lb.position = Vector3(0, rig.height + 0.25, 0)
	lb.visibility_range_end = 26.0
	rig.root.add_child(lb)
	var mk := Models.sphere(rig.root, 0.09, Vector3(0, rig.height + 0.55, 0), Models.mat("4ade80", 0.3, 0.0, 4.0), Vector3(1, 1.5, 1), false, 6)
	mk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.rig = rig
	n.node = rig.root
	n.marker = mk
	n.state = "wait" if at_spot else "walk"
	n.pi = 1
	n.interact = {"label": func(): return "Porozmawiaj: " + String(def.name), "range": 2.9, "act": func(): deal_with_customer(n)}
	all.append(n)


## po transakcji albo odwołaniu klient wraca do domu
func remove_customer(order_id: int) -> void:
	for n in customers.duplicate():
		if int(n.order.id) == order_id:
			customers.erase(n)
			if n.node == null:
				continue
			n.erase("interact")
			if n.marker != null:
				n.marker.visible = false
			n.state = "leave"
			n.path = G.main.nav.path_between(Vector2(n.x, n.z), _home_of(n.def))
			n.pi = 1
			leavers.append(n)


func clear_customers() -> void:
	for n in customers + leavers:
		all.erase(n)
		if n.node != null:
			n.node.queue_free()
	customers.clear()
	leavers.clear()
	for c in cops.duplicate():
		if c.post or c.get("temp", false):
			remove_cop(c)
	end_chase()
	if not car.is_empty():
		car.alarm = false
		car.light.visible = false


## idzie po kolejnych punktach trasy; zwraca true po dojściu do końca
func _walk_path(n: Dictionary, dt: float) -> bool:
	var path: Array = n.path
	if int(n.pi) >= path.size():
		return true
	var tgt: Vector2 = path[int(n.pi)]
	var to := tgt - Vector2(n.x, n.z)
	var d := to.length()
	if d < 0.4:
		n.pi = int(n.pi) + 1
		return int(n.pi) >= path.size()
	var sp: float = n.speed
	n.x += to.x / d * sp * dt
	n.z += to.y / d * sp * dt
	n.rot = atan2(to.x, to.y)
	return false


## Pole widzenia policjanta: pełny zasięg na wprost (do ok. 35° od kierunku patrzenia),
## coraz krótszy na boki (do ok. 85°) i nic za plecami. Zwraca ułamek zasięgu dla danego kąta.
const SIGHT_FULL := 0.6
const SIGHT_SIDE := 1.48

static func sight(ang: float) -> float:
	if ang <= SIGHT_FULL:
		return 1.0
	if ang >= SIGHT_SIDE:
		return 0.0
	return lerpf(1.0, 0.3, (ang - SIGHT_FULL) / (SIGHT_SIDE - SIGHT_FULL))


const VIEW := 27.0          # zasięg wzroku patrolu: dzień, na wprost, gracz stoi
const TORCH_ANG := 0.36     # połowa kąta snopu latarki patrolu
const TORCH_RANGE := 15.0

## Jak wyraźnie patrzący z punktu (x, z) w kierunku `rot` widzi gracza: 0 = wcale, 1 = z bliska na wprost.
## Jedyna droga, którą policja „widzi”. Liczy się kierunek patrzenia, odległość, zasłony po drodze
## i WIDOCZNOŚĆ gracza (postawa, ruch, ciemność, światło latarni, krzaki, strój — patrz player.visibility()).
## `torch`: patrzący świeci latarką — nocą w snopie światła ciemność nie pomaga.
func see_level(x: float, z: float, rot: float, view_range: float, torch := false) -> float:
	var P = G.player
	if P.hidden:
		return 0.0
	var pp: Vector3 = P.global_position
	var dx := pp.x - x
	var dz := pp.z - z
	var dist := sqrt(dx * dx + dz * dz)
	var crouch: bool = P.crouching
	var ang := absf(_ang_diff(atan2(dx, dz), rot))
	var vis: float = P.visibility()
	if torch and G.night > 0.35 and ang < TORCH_ANG and dist < TORCH_RANGE:
		vis = maxf(vis, 0.7 if crouch else 1.0)
	var r := view_range * sight(ang) * vis
	if dist >= r or not G.world.los(x, z, pp.x, pp.z, crouch):
		return 0.0
	return clampf(1.0 - dist / r, 0.04, 1.0)


func can_see(x: float, z: float, rot: float, view_range: float) -> bool:
	return see_level(x, z, rot, view_range) > 0.0


## czy któryś patrol akurat patrzy na gracza z odległości do `r` metrów
func watcher(r: float) -> Variant:
	for c in cops:
		if see_level(c.x, c.z, c.node.rotation.y, r, true) > 0.0:
			return c
	return null


## Hałas w świecie (rzucony kamień, trzask): patrole w zasięgu idą sprawdzić, co to było.
## Zwraca liczbę patroli, które dały się odciągnąć.
func noise_at(x: float, z: float, r: float) -> int:
	var n := 0
	for c in cops:
		if c.state != "patrol" and c.state != "post" and c.state != "search":
			continue
		if Vector2(c.x - x, c.z - z).length() > r:
			continue
		c.state = "investigate"
		c.inv = Vector2(x, z)
		c.lure = true
		c.back = Vector2(c.x, c.z)
		c.alert.visible = true
		c.alert.modulate = Color(1.0, 0.8, 0.2)
		n += 1
	return n


## zaczyna przeszukiwanie okolicy punktu `c.inv`: rozgląda się, potem sprawdza 2–3 miejsca w pobliżu
func _begin_search(c: Dictionary, secs: float, hunt := false) -> void:
	c.state = "search"
	c.search_t = secs
	c.sp_wait = 1.6
	c.hunt = hunt
	var pts: Array = []
	var o: Vector2 = c.inv if c.inv != null else Vector2(c.x, c.z)
	# po zgubionym pościgu nie krąży na ślepo: idzie tam, dokąd uciekałeś, potem sprawdza boki
	var dir: Vector2 = c.get("flee_dir", Vector2.ZERO)
	var a0 := atan2(dir.y, dir.x) if (hunt and dir.length() > 0.3) else randf() * TAU
	for k in range(3 if hunt else 1):
		var a = a0 + [0.0, 1.15, -1.15][k] + randf_range(-0.3, 0.3)
		var q: Vector2 = G.world.near_free(o.x + cos(a) * randf_range(5.0, 9.0), o.y + sin(a) * randf_range(5.0, 9.0))
		if q.distance_to(o) < 14.0:
			pts.append(q)
	if hunt:
		# altanka śmietnikowa tuż obok? Doświadczony patrol do niej zajrzy
		for h in G.world.hides:
			var hp := Vector2(float(h.get("ox", h.get("x", 0.0))), float(h.get("oz", h.get("z", 0.0))))
			if hp.distance_to(o) < 13.0 and randf() < 0.45:
				pts.insert(mini(1, pts.size()), G.world.near_free(hp.x, hp.y))
				c["check_hide"] = h
				break
	c.search_pts = pts


func _end_search(c: Dictionary) -> void:
	c.state = "post" if c.post else "patrol"
	c.susp = 0.0
	c.hunt = false
	c.lure = false
	c.alert.visible = false
	if not c.post:
		_snap_to_node(c)


func nearest_interact(px: float, pz: float, fwd: Vector2, loc: String) -> Variant:
	var best = null
	var bd := 1e9
	for n in all:
		if not n.has("interact") or n.loc != loc or not n.node.visible:
			continue
		var dx: float = n.x - px
		var dz: float = n.z - pz
		var d := sqrt(dx * dx + dz * dz)
		if d > float(n.interact.range):
			continue
		if d > 0.9 and (dx * fwd.x + dz * fwd.y) / d < 0.25:
			continue
		if d < bd:
			bd = d
			best = n
	return best


## najbliższy klient obecny na ulicy (czekający albo w drodze)
func nearest_buyer() -> Variant:
	var pp: Vector3 = G.player.global_position
	var best = null
	var bd := 1e9
	for c in customers:
		if c.node == null:
			continue
		var d := Vector2(c.x - pp.x, c.z - pp.z).length()
		if d < bd:
			bd = d
			best = c
	return best


# ---------------------------------------------------------------- pościgi
func dispatch_to(x: float, z: float, count: int) -> void:
	var avail := cops.filter(func(c): return c.state == "patrol" or c.state == "search")
	# nikogo w okolicy (pierwsze dni gry)? Zgłoszenie i tak ktoś przyjmie — patrol wyjeżdża z komendy
	while avail.size() < count and cops.size() < 6 and G.prologue == null:
		var nc: Dictionary = spawn_cop(true)
		nc["resp"] = true
		avail.append(nc)
	avail.sort_custom(func(a, b): return Vector2(a.x - x, a.z - z).length() < Vector2(b.x - x, b.z - z).length())
	for i in range(mini(count, avail.size())):
		avail[i].state = "investigate"
		avail[i].inv = Vector2(x, z)
		avail[i].lure = false
		avail[i].alert.visible = true


func start_chase(c: Dictionary) -> void:
	if c.state == "chase":
		return
	var pp: Vector3 = G.player.global_position
	c.state = "chase"
	c.alert.visible = true
	c.last_seen = G.now
	c.notice = 1.0
	c.lure = false
	c.know = false
	c.inv = Vector2(pp.x, pp.z)
	G.on_chase_start()
	for o in cops:
		if o != c and o.state != "chase" and not o.post and Vector2(o.x - c.x, o.z - c.z).length() < 55.0:
			o.state = "chase"
			o.last_seen = G.now
			o.lure = false
			o.know = false
			o.alert.visible = true
			o.inv = Vector2(pp.x, pp.z)


func _snap_to_node(c: Dictionary) -> void:
	c.wi = G.main.nav.nearest_node(c.x, c.z, false)
	c.pi = -1
	c.tx = G.world.wp[c.wi].x
	c.tz = G.world.wp[c.wi].z


func end_chase() -> void:
	for c in cops.duplicate():
		if c.get("temp", false):
			remove_cop(c)
			continue
		if c.state != "patrol" and c.state != "post":
			c.state = "post" if c.post else "patrol"
			c.susp = 0.0
			c.notice = 0.0
			c.hunt = false
			c.lure = false
			c.know = false
			c.alert.visible = false
			c.inv = null
			if not c.post:
				_snap_to_node(c)


func any_chase() -> bool:
	for c in cops:
		if c.state == "chase":
			return true
	return false


func citizens_near(x: float, z: float, r: float) -> int:
	var n := 0
	for c in citizens:
		if c.active and c.state != "talk" and Vector2(c.x - x, c.z - z).length() < r * clampf(float(G.player.vis_now), 0.35, 1.0) and G.world.los(c.x, c.z, x, z):
			n += 1
	return n


## przesuwa okrąg z poślizgiem po przeszkodach (2D)
func _resolve(x: float, z: float, r: float, vx: float, vz: float) -> Vector2:
	var nx := x + vx
	var nz := z
	for c in G.world.rects:
		if nx > c.x0 - r and nx < c.x1 + r and nz > c.z0 - r and nz < c.z1 + r:
			if vx > 0.0:
				nx = c.x0 - r
			elif vx < 0.0:
				nx = c.x1 + r
	nz = z + vz
	for c in G.world.rects:
		if nx > c.x0 - r and nx < c.x1 + r and nz > c.z0 - r and nz < c.z1 + r:
			if vz > 0.0:
				nz = c.z0 - r
			elif vz < 0.0:
				nz = c.z1 + r
	return Vector2(nx, nz)


# ---------------------------------------------------------------- aktualizacja
func _hours_ok(hours: Array, h: float) -> bool:
	if hours.is_empty():
		return true
	var a: float = hours[0]
	var b: float = hours[1]
	return (h >= a and h < b) if a < b else (h >= a or h < b)


func update(dt: float) -> void:
	var P = G.player
	var pp: Vector3 = P.global_position
	var outside: bool = P.loc == "out"
	var h := G.hour()
	var want_active := 9
	if h >= 22.5 or h < 5.5:
		want_active = 3
	elif h < 7.0 or h >= 20.5:
		want_active = 6
	if G.rain > 0.4:
		want_active = mini(want_active, 4)
	var can_street: bool = outside and int(G.S.lvl) >= 3 and G.packed_total(G.S.inv) > 0 and not G.S.wanted
	max_susp = 0.0
	for n in citizens:
		var dp := Vector2(pp.x - n.x, pp.z - n.z).length()
		var act: bool = int(n.idx) < want_active
		if act != n.active and dp > 45.0:
			n.active = act
		n.node.visible = outside and n.active
		if not n.node.visible:
			continue
		n.reroll -= dt
		if n.reroll <= 0.0:
			n.reroll = randf_range(70.0, 180.0)
			if dp > 55.0 and n.state != "talk":
				_roll_identity(n)
		n.icon.visible = can_street and n.user and dp < 16.0 and not n.refused and G.S.t - float(n.last_deal) > 240.0
		var sp := 0.0
		var pose := ""
		if n.state == "talk":
			# dopóki okno rozmowy jest otwarte, rozmówca stoi i słucha (czas już się nie zatrzymuje)
			if not G.ui.is_open():
				n.talk_t -= dt
			if n.talk_t <= 0.0:
				n.state = "walk"
			n.node.rotation.y += _ang_diff(atan2(pp.x - n.x, pp.z - n.z), n.node.rotation.y) * minf(1.0, dt * 6.0)
			pose = "talk"
		elif n.idle > 0.0:
			n.idle -= dt
			pose = n.idle_pose
		else:
			var dx: float = n.tx - n.x
			var dz: float = n.tz - n.z
			var d := sqrt(dx * dx + dz * dz)
			if d < 0.35:
				if randf() < 0.22:
					n.idle = randf_range(2.0, 8.0)
				_pick_next(n, false)
			else:
				sp = n.speed * (1.3 if G.rain > 0.3 else 1.0)
				n.x += dx / d * sp * dt
				n.z += dz / d * sp * dt
				n.rot = atan2(dx, dz)
			n.node.rotation.y += _ang_diff(n.rot, n.node.rotation.y) * minf(1.0, dt * 8.0)
		n.node.position = Vector3(n.x, _h(n.x, n.z), n.z)
		var near := dp < 70.0
		Chars.set_active(n.rig, near)
		if near:
			Chars.animate(n.rig, dt, sp, pose)

	for n in customers:
		if n.state == "pending":
			if G.S.t >= float(n.spawn_at):
				_customer_enter(n)
			continue
		n.node.visible = outside
		if not outside:
			# czas płynie także wtedy, gdy gracz siedzi w mieszkaniu
			if n.state == "walk" and _walk_path(n, dt):
				n.state = "wait"
			continue
		var dp2 := Vector2(pp.x - n.x, pp.z - n.z).length()
		var csp := 0.0
		if n.state == "walk":
			csp = n.speed
			if _walk_path(n, dt):
				n.state = "wait"
				n.x = n.goal.x
				n.z = n.goal.y
		else:
			n.idle -= dt
			if n.idle <= 0.0:
				n.idle = randf_range(2.0, 5.0)
				n.rot = atan2(pp.x - n.x, pp.z - n.z) if dp2 < 14.0 else n.rot + randf_range(-1.2, 1.2)
		n.node.rotation.y += _ang_diff(n.rot, n.node.rotation.y) * minf(1.0, dt * (7.0 if csp > 0.0 else 3.0))
		n.node.position = Vector3(n.x, _h(n.x, n.z), n.z)
		Chars.set_active(n.rig, dp2 < 70.0)
		if dp2 < 70.0:
			Chars.animate(n.rig, dt, csp, "talk" if (dp2 < 4.0 and csp == 0.0) else n.pose)
		n.marker.position.y = n.rig.height + 0.55 + sin(G.now * 3.0) * 0.05
	for n in leavers.duplicate():
		n.node.visible = outside
		var done := _walk_path(n, dt)
		if outside:
			n.node.rotation.y += _ang_diff(n.rot, n.node.rotation.y) * minf(1.0, dt * 7.0)
			n.node.position = Vector3(n.x, _h(n.x, n.z), n.z)
			var dl := Vector2(pp.x - n.x, pp.z - n.z).length()
			Chars.set_active(n.rig, dl < 70.0)
			if dl < 70.0:
				Chars.animate(n.rig, dt, n.speed, "")
		if done:
			leavers.erase(n)
			all.erase(n)
			n.node.queue_free()

	for n in statics:
		var vis: bool = n.loc == P.loc and _hours_ok(n.hours, h)
		n.node.visible = vis
		if not vis:
			# postać w innym miejscu (klub, szpital, komenda…) nie może mielić animacji, gdy nikt jej nie widzi
			Chars.set_active(n.rig, false)
			continue
		var dp3 := Vector2(pp.x - n.x, pp.z - n.z).length()
		if n.track and dp3 < 10.0:
			n.node.rotation.y += _ang_diff(atan2(pp.x - n.x, pp.z - n.z), n.node.rotation.y) * minf(1.0, dt * 3.0)
		Chars.set_active(n.rig, dp3 < 60.0)
		if dp3 < 60.0:
			Chars.animate(n.rig, dt, 0.0, "talk" if (n.track and dp3 < 3.4) else n.pose)
			if n.has("anim_speed"):
				n.rig.anim.speed_scale = float(n.anim_speed)

	_update_cops(dt, pp, outside)
	if outside:
		update_shots(dt, pp, P.moving)
	_update_car(dt, pp, outside)
	_update_dog(dt, pp, outside)


func _update_cops(dt: float, pp: Vector3, outside: bool) -> void:
	var mult := susp_mult
	var torch_on: bool = G.night > 0.35
	var P = G.player
	var noise_r: float = P.noise() if outside else 0.0
	aware.clear()
	# radio: gdy choć jeden ścigający Cię widzi, wszyscy ścigający wiedzą, gdzie jesteś;
	# najbliższy goni wprost, reszta odcina drogę
	var radio_seen := false
	var lead_cop = null
	var lead_d := 1e9
	for c0 in cops:
		if c0.state == "chase":
			if c0.sees:
				radio_seen = true
			var d0 := Vector2(pp.x - float(c0.x), pp.z - float(c0.z)).length()
			if d0 < lead_d:
				lead_d = d0
				lead_cop = c0
	var pv := Vector2(P.velocity.x, P.velocity.z)
	pv = pv.normalized() if pv.length() > 0.3 else Vector2.ZERO
	if lead_cop != null and outside:
		Sfx.siren_dist(lead_d)
	for c in cops.duplicate():
		c.node.visible = outside
		if not outside:
			continue
		# w przerywniku patrolem steruje scena (prolog: odrzut przy wybuchu)
		if c.get("scripted", false):
			c.torch.visible = torch_on
			c.torch.shadow_enabled = true
			_scan(c, dt, 0.0)
			continue
		var dx: float = pp.x - c.x
		var dz: float = pp.z - c.z
		var dist := sqrt(dx * dx + dz * dz)
		c.torch.visible = torch_on and dist < 95.0
		# z bliska snop rzuca cienie (i dopiero wtedy działa plama z jasnym środkiem); dalekim patrolom szkoda na to mocy
		c.torch.shadow_enabled = dist < 32.0
		# przeczesuje teren: stojąc rozgląda się szeroko, idąc omiata drogę przed sobą; w pościgu patrzy prosto
		var amp := 0.0
		if float(c.hear_t) <= 0.0:
			match c.state:
				"patrol", "post":
					amp = 0.62 if (float(c.idle) > 0.0 or c.state == "post") else 0.36
				"search":
					amp = 0.7
		_scan(c, dt, amp)
		c.look_t -= dt
		if c.look_t <= 0.0:
			c.look_t = 0.2
			# w pościgu patrzy uważniej (dalej), ale dalej tylko przed siebie
			var lvl := see_level(c.x, c.z, c.node.rotation.y + float(c.scan), VIEW * (1.4 if c.state == "chase" else 1.0), torch_on)
			c.lvl = lvl
			if c.state == "chase":
				c.notice = 1.0 if lvl > 0.0 else maxf(0.0, float(c.notice) - 0.1)
				c.sees = lvl > 0.0
			else:
				# zauważanie trwa: kątem oka i z daleka ponad sekundę, z bliska ułamek sekundy
				if lvl > 0.0:
					c.notice = minf(1.0, float(c.notice) + 0.2 * (0.55 + lvl * 3.2) * (1.6 if G.S.wanted else 1.0))
				else:
					c.notice = maxf(0.0, float(c.notice) - 0.2 * 0.4)
				c.sees = lvl > 0.0 and float(c.notice) >= 1.0
				var calm: bool = c.state == "patrol" or c.state == "post"
				# coś mignęło na skraju pola widzenia: odwraca się w tę stronę
				if calm and lvl > 0.0 and float(c.notice) > 0.3 and (mult > 0.0 or G.S.wanted or G.prologue != null):
					c.hear_t = maxf(float(c.hear_t), 0.7)
					c.hear_rot = atan2(dx, dz)
				# słuch: kroki za plecami (bieg słychać z daleka, skradania wcale)
				if calm and lvl <= 0.0 and noise_r > 0.0 and dist < noise_r:
					c.hear_t = 1.8
					c.hear_rot = atan2(dx, dz)
		if (mult > 0.0 or G.S.wanted or G.prologue != null) and (float(c.notice) > 0.02 or c.susp > 0.02 or c.state == "chase"):
			aware.append({"x": c.x, "z": c.z, "n": float(c.notice), "s": clampf(c.susp, 0.0, 1.0), "chase": c.state == "chase"})
		var move_speed := 0.0
		var has_tgt := false
		var tgt := Vector2.ZERO
		var pose := ""
		match c.state:
			"patrol", "post":
				if c.sees and mult > 0.0:
					c.susp += mult * dt * (1.6 if dist < 10.0 else 0.8) * 0.65
				else:
					c.susp = maxf(0.0, c.susp - dt * 0.3)
				if c.sees:
					max_susp = maxf(max_susp, c.susp)
				c.alert.visible = c.susp > 0.25
				if c.alert.visible:
					c.alert.modulate = Color(1.0, 0.8, 0.2)
				if c.susp >= 1.0:
					start_chase(c)
				if float(c.hear_t) > 0.0:
					c.hear_t = float(c.hear_t) - dt
					c.node.rotation.y += _ang_diff(float(c.hear_rot), c.node.rotation.y) * minf(1.0, dt * 4.0)
				elif c.state == "post":
					pose = "arms"
					c.node.rotation.y += sin(G.now * 0.4 + c.x) * dt * 0.5
				elif c.idle > 0.0:
					c.idle -= dt
					pose = "arms"
				elif c.get("beat") != null:
					# stały odcinek do obchodzenia tam i z powrotem (posterunki z prologu)
					var bt: Array = c.beat
					var bp: Vector2 = bt[int(c.get("beat_i", 0)) % bt.size()]
					if Vector2(bp.x - c.x, bp.y - c.z).length() < 0.5:
						c.beat_i = int(c.get("beat_i", 0)) + 1
						c.idle = randf_range(1.5, 2.6)
					else:
						move_speed = 1.15
						tgt = bp
						has_tgt = true
				else:
					var d2 := Vector2(c.tx - c.x, c.tz - c.z).length()
					if d2 < 0.4:
						if randf() < 0.18:
							c.idle = randf_range(3.0, 8.0)
						_pick_next(c, true)
					else:
						move_speed = c.speed
						tgt = Vector2(c.tx, c.tz)
						has_tgt = true
			"investigate":
				if c.sees and mult > 0.0:
					c.susp += mult * dt * 1.2
					max_susp = maxf(max_susp, c.susp)
				if c.susp >= 1.0:
					start_chase(c)
				elif Vector2(c.inv.x - c.x, c.inv.y - c.z).length() < 2.2:
					_begin_search(c, 7.0 if c.lure else 14.0)
				else:
					move_speed = 2.2 if c.lure else 3.6
					tgt = c.inv
					has_tgt = true
			"search":
				c.search_t -= dt
				if c.sees and (mult > 0.0 or G.S.wanted):
					c.susp += maxf(mult, 1.0) * dt
					max_susp = maxf(max_susp, c.susp)
					if c.susp >= 1.0:
						start_chase(c)
				if c.state == "search":
					if c.search_t <= 0.0:
						_end_search(c)
					elif float(c.sp_wait) > 0.0:
						# stoi i omiata okolicę wzrokiem (i latarką)
						c.sp_wait = float(c.sp_wait) - dt
						c.node.rotation.y += sin(G.now * 1.9 + c.x) * dt * 2.4
					elif c.search_pts.is_empty():
						c.sp_wait = 2.0
					else:
						var sp0: Vector2 = c.search_pts[0]
						if sp0.distance_to(Vector2(c.x, c.z)) < 0.9:
							c.search_pts.remove_at(0)
							c.sp_wait = 2.4
							# doszedł do kryjówki, do której miał zajrzeć: jeśli tam siedzisz, już wie
							var ch = c.get("check_hide")
							if ch != null and P.hidden and is_same(G.main.hide_at, ch) and dist < 4.5:
								c.know = true
								c.erase("check_hide")
								start_chase(c)
						else:
							move_speed = 2.5
							tgt = sp0
							has_tgt = true
			"chase":
				max_susp = 1.0
				c.alert.visible = true
				c.alert.modulate = Color(1.0, 0.25, 0.25)
				if c.sees:
					c.last_seen = G.now
					c.inv = Vector2(pp.x, pp.z)
					c["flee_dir"] = pv
				elif radio_seen:
					# ktoś z patrolu ma Cię na oku i podaje przez radio — pozostali wiedzą, gdzie biec
					c.last_seen = G.now
					c.inv = Vector2(pp.x, pp.z)
					c["flee_dir"] = pv
				if c.inv == null:
					c.inv = Vector2(pp.x, pp.z)
				var at_last: bool = not c.sees and Vector2(c.inv.x - c.x, c.inv.y - c.z).length() < 1.6
				if P.hidden and c.know and dist < 2.4:
					# widział, gdzie się schowałeś: wyciąga Cię z kryjówki
					G.main.hide_leave(true)
					G.arrest(c)
				elif G.now - float(c.last_seen) > 7.5 or (at_last and G.now - float(c.last_seen) > 1.2):
					# zgubił trop: przeczesuje okolicę ostatniego miejsca, w którym Cię widział
					_begin_search(c, 15.0, true)
				elif float(c.get("aim_t", 0.0)) > 0.0:
					# staje i mierzy: strzał kosztuje go kilka metrów dystansu
					c.aim_t = float(c.aim_t) - dt
					c.node.rotation.y += _ang_diff(atan2(pp.x - c.x, pp.z - c.z), c.node.rotation.y) * minf(1.0, dt * 9.0)
				else:
					var goal: Vector2 = Vector2(pp.x, pp.z) if c.sees else c.inv
					# najbliższy biegnie prosto za Tobą, pozostali odcinają drogę: celują w miejsce, do którego zmierzasz
					if (c.sees or radio_seen) and not is_same(c, lead_cop) and pv.length() > 0.3 and dist > 6.0:
						var cut: Vector2 = G.world.near_free(pp.x + pv.x * clampf(dist * 0.55, 4.0, 14.0), pp.z + pv.y * clampf(dist * 0.55, 4.0, 14.0))
						goal = cut
					if (goal - Vector2(c.x, c.z)).length() > 0.5:
						move_speed = 5.5 + minf(1.0, G.S.heat / 100.0) * 0.5
						tgt = goal
						has_tgt = true
				if c.sees and dist < 1.5:
					G.arrest(c)
		if has_tgt:
			var to := tgt - Vector2(c.x, c.z)
			var face := atan2(to.x, to.y)
			if c.state == "chase" or c.state == "investigate" or c.state == "search":
				# biegnie trasą omijającą płoty, mury i auta; pod górę wolniej — tak jak gracz
				var here := Vector2(c.x, c.z)
				var path: PackedVector2Array = c.get("path", PackedVector2Array())
				c.path_t = float(c.get("path_t", 0.0)) - dt
				if c.path_t <= 0.0 or path.is_empty() or (Vector2(c.get("path_goal", tgt)) - tgt).length() > 1.5:
					path = G.world.grid_path(here, tgt)
					c.path_t = 0.4
					c.path_goal = tgt
				while path.size() > 1 and here.distance_to(path[0]) < 0.45:
					path.remove_at(0)
				c.path = path
				var nxt: Vector2 = path[0] if not path.is_empty() else tgt
				var dv := nxt - here
				var ln0: float = maxf(0.001, dv.length())
				var h0 := _h(c.x, c.z)
				var h1 := _h(c.x + dv.x / ln0 * 0.8, c.z + dv.y / ln0 * 0.8)
				var step := minf(ln0, move_speed * dt * clampf(1.0 - maxf(0.0, (h1 - h0) / 0.8) * 0.75, 0.45, 1.0))
				c.x += dv.x / ln0 * step
				c.z += dv.y / ln0 * step
				if ln0 > 0.05:
					face = atan2(dv.x, dv.y)
			else:
				var ln: float = maxf(0.001, to.length())
				c.x += to.x / ln * move_speed * dt
				c.z += to.y / ln * move_speed * dt
			c.node.rotation.y += _ang_diff(face, c.node.rotation.y) * minf(1.0, dt * 7.0)
		c.node.position = Vector3(c.x, _h(c.x, c.z), c.z)
		Chars.set_active(c.rig, dist < 90.0)
		# broń: wyjęta w pościgu i przy przeszukiwaniu okolicy (w prologu przez cały czas), schowana na zwykłym patrolu
		var armed: bool = c.state == "chase" or c.get("hunt", false) or G.prologue != null
		if armed != bool(c.rig.get("armed", false)):
			Chars.set_armed(c.rig, armed)
		if armed and move_speed <= 0.15:
			pose = "aim" if (c.sees and c.state == "chase") else "gun"
		if dist < 90.0:
			Chars.animate(c.rig, dt, move_speed, pose)


# ---------------------------------------------------------------- strzały w pościgu
## szansa trafienia z danej odległości (kucanie i noc pomagają uciekającemu)
func shot_chance(dist: float) -> float:
	var p := clampf(0.55 - dist * 0.015 - (0.1 if G.player.crouching else 0.0), 0.08, 0.5)
	return p * (0.75 if G.is_night() else 1.0)


## Długa ucieczka na oczach patrolu: najpierw okrzyk, potem strzał ostrzegawczy, potem strzały celowane.
## Zatrzymanie się albo zniknięcie z widoku cofa licznik; trafienie kończy się w szpitalu pod strażą.
func update_shots(dt: float, pp: Vector3, moving: bool) -> void:
	if G.prologue != null or G.busy or G.arresting or not G.S.wanted:
		flee_t = 0.0
		flee_stage = 0
		return
	var best = null
	var bd := 999.0
	for c in cops:
		if c.state == "chase" and c.sees:
			var dd := Vector2(c.x - pp.x, c.z - pp.z).length()
			if dd < bd:
				bd = dd
				best = c
	var fleeing: bool = best != null and bd > 5.0 and bd < 28.0 and moving and not G.player.hidden
	if fleeing:
		flee_t += dt
	else:
		flee_t = maxf(0.0, flee_t - dt * 0.6)
		if flee_t <= 0.0:
			flee_stage = 0
	if not fleeing:
		return
	if flee_stage == 0 and flee_t > 6.0:
		flee_stage = 1
		G.ui.shout("STÓJ, BO STRZELAM!", 2.4)
		Sfx.play("alert")
	elif flee_stage == 1 and flee_t > 9.0:
		flee_stage = 2
		shot_cd = 2.6
		_fire(best)
		G.notify("Strzał ostrzegawczy! Następny będzie do Ciebie — stań albo zniknij im z oczu.", "bad")
	elif flee_stage >= 2:
		shot_cd -= dt
		if shot_cd <= 0.0:
			shot_cd = 2.4
			_fire(best)
			if randf() < shot_chance(bd):
				G.hospitalize("shot")
			else:
				G.player.shake = 0.5
				G.notify("Kula świsnęła tuż obok!", "bad")


func _fire(c: Dictionary) -> void:
	c.aim_t = 1.0
	Sfx.gunshot()
	if G.test_mode:
		return
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.85, 0.55)
	fl.light_energy = 7.0
	fl.omni_range = 9.0
	fl.shadow_enabled = false
	add_child(fl)
	fl.global_position = c.node.global_position + Vector3(0, 1.45, 0) + c.node.global_transform.basis.z * 0.6
	var tw := create_tween()
	tw.tween_property(fl, "light_energy", 0.0, 0.09)
	tw.tween_callback(fl.queue_free)


# ---------------------------------------------------------------- rozmowy
func approach_citizen(n: Dictionary) -> void:
	if any_chase():
		G.notify("Nie teraz!", "bad")
		return
	n.state = "talk"
	n.talk_t = 3.0
	if int(G.S.lvl) < 3:
		G.ui.dialog({"name": n.name, "lines": [["Znamy się?", "Nie mam czasu.", "Czego chcesz?", "Nie znam cię, kolego."].pick_random(), {"n": "", "t": "(Obcy zaczną z Tobą rozmawiać o interesach od poziomu 3.)"}]})
		return
	if G.packed_total(G.S.inv) <= 0:
		G.ui.dialog({"name": n.name, "lines": [["Co tam?", "No hej.", "Słucham?"].pick_random()]})
		return
	if G.S.t - float(n.last_deal) < 240.0:
		G.ui.dialog({"name": n.name, "lines": ["Już coś od ciebie brałem. Daj mi chwilę, dobra?"]})
		return
	if not n.user:
		var snitch: bool = (not n.refused) and randf() < (0.08 if G.is_night() else 0.16)
		n.refused = true
		G.ui.dialog({"name": n.name, "lines": [["Odczep się, nie interesuje mnie to.", "Co?! Nie, dziękuję.", "Przepraszam, śpieszę się.", "Nie wiem, o czym mówisz.", "Zostaw mnie w spokoju."].pick_random()],
			"on_end": _refusal_end.bind(snitch)})
		return
	if not n.sting_rolled:
		n.sting_rolled = true
		n.sting = randf() < G.sting_chance()
	var like: String = ["luz", "konkret", "twardo"].pick_random()
	var who := {"name": n.name, "bio": "Przechodzień. Czasem coś kupuje.", "wealth": n.wealth, "patience": 3 + randi_range(0, 1), "minpur": [40, 50, 55].pick_random(), "nerv": 0.2,
		"type": n.ctype, "like": like, "hate": "", "reliable": 0.0, "st": {"loy": float(n.loyalty) * 6.0, "sat": 55.0, "hunger": randf_range(0.3, 0.8)}}
	n.talk_t = 600.0
	var ctx := {"who": who, "product": "dym", "grams": randi_range(1, 2), "street": true, "npc": n, "sting": n.sting, "on_done": _citizen_done.bind(n)}
	var line: String
	if n.sting:
		line = ["Hej, stary! Masz coś mocnego? Biorę wszystko, cena nie gra roli, płacę od ręki!", "Słuchaj, potrzebuję towaru. Dużo. Kasa nie jest problemem. Masz przy sobie?"].pick_random()
	else:
		line = ["Hej… Szukam czegoś na wieczór. Masz coś?", "Podobno masz towar. Pokaż, co masz.", "Cześć. Cicho, ale… masz coś dla mnie?", "Ej, ty jesteś ten z huty? Potrzebuję czegoś."].pick_random()
	G.ui.dialog({"name": n.name, "lines": [line], "voice": _voice(n), "on_end": _open_citizen_deal.bind(n, ctx)})


func _voice(n: Dictionary) -> float:
	var base := 1.35 if n.get("female", false) else 0.88
	return base + float(absi(String(n.get("name", "x")).hash()) % 20) / 100.0


func _refusal_end(snitch: bool) -> void:
	if snitch:
		G.add_heat(10.0)
		G.add_invest(3.0)
		var pp: Vector3 = G.player.global_position
		dispatch_to(pp.x, pp.z, 2)
		G.notify("Ktoś zgłosił podejrzanego typa!", "bad")


func _open_citizen_deal(n: Dictionary, ctx: Dictionary) -> void:
	if not G.ui.open_deal(ctx):
		n.state = "walk"
		n.talk_t = 0.0


func _citizen_done(res: Dictionary, n: Dictionary) -> void:
	n.state = "walk"
	n.talk_t = 0.0
	if int(res.get("sold", 0)) > 0 and n.sting:
		sting_bust(n)


func sting_bust(n: Dictionary) -> void:
	G.add_invest(12.0)
	G.add_heat(25.0)
	G.ui.dialog({"name": n.name, "lines": ["…Policja! To był zakup kontrolowany. Nie ruszaj się!"], "on_end": _sting_chase.bind(n)})


func _sting_chase(n: Dictionary) -> void:
	var c := spawn_cop(false)
	c.x = n.x
	c.z = n.z
	c.temp = true
	n.active = false
	n.node.visible = false
	_roll_identity(n)
	var w: Dictionary = G.world.wp[_random_node()]
	n.x = w.x
	n.z = w.z
	c.susp = 1.0
	start_chase(c)
	G.notify("PROWOKACJA! Uciekaj!", "bad")


func deal_with_customer(n: Dictionary) -> void:
	if any_chase():
		G.notify("Nie teraz!", "bad")
		return
	var o: Dictionary = n.order
	var def: Dictionary = n.def
	var st: Dictionary = G.S.cust[def.id]
	var who: Dictionary = def.duplicate()
	who["st"] = st
	var ctx := {"who": who, "product": o.product, "grams": int(o.grams), "order": o, "street": true, "npc": n, "agreed": o.agreed}
	G.ui.open_deal(ctx)
