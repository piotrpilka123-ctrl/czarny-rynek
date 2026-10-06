extends Node
## PROLOG: ostatnia noc w laboratorium w Starej Hucie.
## Pakowanie partii → nalot (megafon, koguty, łomot w bramę) → ucieczka tylnymi drzwiami, na kucaka
## obok patroli z latarkami, pod siatką za torami → bieg między garaże → eksplozje → „Trzy tygodnie później”.
## Po drodze uczy: ruchu i rozglądania, [E], kucania, trzymania się cienia i biegu.

const Fx = preload("res://scripts/fx.gd")
const Models = preload("res://scripts/models.gd")

var M                       # main
var stage := "intro"        # intro → lab → raid → escape → run → boom → done
var t := 0.0                # czas w etapie
var tries := 0
var nodes: Array = []       # rekwizyty do posprzątania
var flashes: Array = []     # koguty radiowozów przed hutą
var fire_lights: Array = [] # światła pożaru po wybuchach
var cop_a = null
var cop_b = null
var siwy = null
var _bang := 0.0
var _shout := 0.0
var _hinted := {}
var _nav_was := true
var _finishing := false
var _jumped := false        # testy: przeskok do etapu, start() ma się już nie wtrącać
var _packed := false        # towar przeniesiony ze stołu do torby
var _party_fx: ColorRect = null
const BATCH_G := 500.0

const SH_PARTY := """
shader_type canvas_item;
uniform float k = 1.0;
void fragment() {
	// rozmyte światła imprezy: kilka kolorowych plam pulsujących w rytm basu
	vec2 uv = UV;
	float beat = pow(abs(sin(TIME * 6.6)), 6.0);
	vec3 c = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		vec2 p = vec2(0.5 + 0.42 * sin(TIME * (0.31 + fi * 0.07) + fi * 2.1), 0.5 + 0.36 * cos(TIME * (0.27 + fi * 0.05) + fi * 1.3));
		float d = distance(uv, p);
		vec3 col = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + fi * 1.9 + TIME * 0.4);
		c += col * exp(-d * d * (9.0 - beat * 3.0)) * (0.35 + 0.25 * beat);
	}
	// zataczanie się: obraz „pływa” i ciemnieje na brzegach
	float vig = smoothstep(0.95, 0.2, distance(uv, vec2(0.5 + 0.04 * sin(TIME * 1.3), 0.5)));
	COLOR = vec4(c * vig * 0.8, k);
}
"""


static func P(x: float, z: float) -> Vector2:
	return Vector2(x * D.SC, z * D.SC)


func gap() -> Vector2:
	return P(130.6, -90.0)


func run_end() -> Vector2:
	return P(122.5, -77.0)


func exit_pos() -> Vector2:
	var dd: Dictionary = D.DOORS.lab
	return Vector2(float(dd.x), float(dd.z) + float(dd.dz) * 1.2)


## cel i znacznik dla HUD-u (podmienia zwykłe zadania fabularne)
func step() -> Dictionary:
	var R: Dictionary = D.ROOMS.lab
	match stage:
		"lab":
			return {"text": func(): return ("Chodź klawiszami [%s][%s][%s][%s], rozglądaj się myszą. Podejdź do stołu z cegłami, naceluj i naciśnij [%s] — a potem spakuj partię: przeciągnij kokainę ze stołu do swojej torby." % [G.kn("fwd"), G.kn("left"), G.kn("back"), G.kn("right"), G.kn("use")]) if not _packed else "Odbierz telefon.",
				"done": func(): return false, "marker": func(): return {"loc": "lab", "x": float(R.cx) + 1.6, "z": 2.4}}
		"raid":
			return {"text": func(): return "NALOT! Uciekaj tylnymi drzwiami — naceluj na nie i naciśnij [%s]." % G.kn("use"),
				"done": func(): return false, "marker": func(): return {"loc": "lab", "x": float(R.cx), "z": float(R.d) * 0.5 - 0.3}}
		"escape":
			return {"text": func(): return "Kucnij [%s] i trzymaj się cienia. Omijaj snopy latarek, poczekaj, aż patrol się odwróci. Dojdź do dziury w siatce za torami." % G.kn("crouch"),
				"done": func(): return false, "marker": func(): return {"loc": "out", "x": gap().x, "z": gap().y}}
		"run":
			return {"text": func(): return "Jesteś za siatką. Teraz biegiem [%s] między garaże!" % G.kn("sprint"),
				"done": func(): return false, "marker": func(): return {"loc": "out", "x": run_end().x, "z": run_end().y}}
	return {"text": func(): return "", "done": func(): return false}


func _wait(sec: float) -> void:
	var left := sec
	while left > 0.0 and not M.cut_skip:
		await get_tree().process_frame
		left -= get_process_delta_time()


# ---------------------------------------------------------------- start
func start() -> void:
	M = G.main
	G.prologue = self
	G.busy = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	M.cut_skip = false
	M.cut_hour = 4.8
	_nav_was = bool(G.S.nav_on)
	G.S.nav_on = false
	Sfx.boom_prepare()
	_setup_world()
	var R: Dictionary = D.ROOMS.lab
	M.ui.fade_rect.color.a = 1.0
	M.teleport("lab", Vector3(float(R.cx) - 1.2, 0.0, 3.9), -0.75)
	M.ui.cut_begin()
	# ostatnia partia leży na stole — do torby przenosi ją gracz
	G.S.stash["lab"] = G.new_store()
	G.add_bulk(G.S.stash.lab, "snieg", 90, BATCH_G)
	await _party()
	if _jumped:
		return
	if M.cut_skip:
		_finish()
		return
	M.ui.cut_title("STARA HUTA  •  04:47", "OSTATNIA PARTIA PRZED ŚWITEM")
	await _wait(3.0)
	if _jumped:
		return
	if M.cut_skip:
		_finish()
		return
	M.ui.cut_title("")
	await M.ui.fade_to(0.0, 1.4)
	if _jumped:
		return
	M.ui.cut_end()
	G.busy = false
	stage = "lab"
	t = 0.0
	M.nav_force = true
	M.ui.dialog({"name": "Siwy", "lines": [
		"No, wreszcie. Śpiąca królewna raczyła zejść do piwnicy. Wiesz, która godzina? Za kwadrans piąta, Kuba.",
		{"n": "Ty", "t": "Wiem. Trzy dni mnie nie było."},
		"Trzy dni. Ja tu od trzech dni oddycham acetonem, a ty wracasz z miną, jakbyś pił z diabłem na umór. Dobra, nie moja sprawa.",
		"Pół kilo stoi na stole. Najczystszy śnieg, jaki z tej huty wyszedł. Wiktor zapłacił z góry i czeka do szóstej — a Wiktor nie lubi czekać.",
		{"n": "Ty", "t": "Trzy lata bez jednej wpadki. Dowieziemy to i robimy przerwę. Długą."},
		"Ty i przerwa. Pakuj torbę, ja doglądam kolby. I Kuba — umyj twarz, zanim pójdziesz do ludzi.",
	]})


## Otwarcie: nieprzerwany melanż widziany przez mgłę — plamy świateł, bas zza ściany, strzępy głosów.
## Potem nagle czarny ekran i jedno zdanie.
func _party() -> void:
	var U = M.ui
	_party_fx = ColorRect.new()
	_party_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_party_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SH_PARTY
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_party_fx.material = sm
	U.cut.add_child(_party_fx)
	U.cut.move_child(_party_fx, 0)
	Sfx.party_play()
	var bits := [[0.8, "— Jeszcze jedną, Kuba! Jeszcze jedną!"], [3.0, "(ktoś wciąga kreskę z blatu)"], [5.2, "— Która to doba? Trzecia? Czwarta?"], [7.3, "(ktoś wymiotuje w łazience)"],
		[9.4, "— Nie odbieraj. To znowu Siwy."], [11.6, "— Stary, ty w ogóle śpisz?"]]
	var bi := 0
	var tt := 0.0
	while tt < 13.6 and not M.cut_skip and not _jumped:
		tt += get_process_delta_time()
		if bi < bits.size() and tt >= float(bits[bi][0]):
			U.cut_line(String(bits[bi][1]))
			bi += 1
		await get_tree().process_frame
	# cięcie: cisza i czerń
	Sfx.party_stop()
	if is_instance_valid(_party_fx):
		_party_fx.queue_free()
	_party_fx = null
	U.cut_line("")
	if M.cut_skip or _jumped:
		return
	await _wait(1.3)
	U.cut_title("WSZYSTKO SIĘ KIEDYŚ KOŃCZY.", "")
	await _wait(3.4)
	U.cut_title("")
	await _wait(0.9)


## ustawia patrole, radiowozy i wspólnika na czas prologu
func _setup_world() -> void:
	var N = M.npcs
	var W = M.world
	while N.cops.size() < 2:
		N.spawn_cop(false)
	cop_a = N.cops[0]
	cop_b = N.cops[1]
	for i in range(N.cops.size()):
		var c: Dictionary = N.cops[i]
		c.state = "patrol"
		c.post = false
		c.susp = 0.0
		c.notice = 0.0
		c.sees = false
		c.idle = 99999.0
		c.beat = null
		if i >= 2:
			var far := P(-181.0 + i * 3.0, 14.0)
			c.x = far.x
			c.z = far.y
	_reset_cops()
	# radiowóz z patrolu staje pod bramą huty; drugi dostawiamy jako rekwizyt
	var car: Dictionary = N.car
	var cp := P(163.0, -47.0)
	car.x = cp.x
	car.z = cp.y
	car.rot = 0.9
	car.wait = 99999.0
	car.speed = 0.0
	car.node.position = Vector3(cp.x, W.height(cp.x, cp.y), cp.y)
	car.node.rotation.y = 0.9
	var car2: Node3D = Models.car("sedan", "ffffff", true)
	M.add_child(car2)
	nodes.append(car2)
	var c2 := P(170.5, -58.0)
	car2.position = Vector3(c2.x, W.height(c2.x, c2.y), c2.y)
	car2.rotation.y = -0.5
	for e in [[cp, Color(0.15, 0.35, 1.0)], [c2, Color(1.0, 0.12, 0.1)], [cp + Vector2(0.6, 0.4), Color(1.0, 0.12, 0.1)], [c2 + Vector2(0.5, -0.4), Color(0.15, 0.35, 1.0)]]:
		var li := OmniLight3D.new()
		li.light_color = e[1]
		li.omni_range = 24.0
		li.light_energy = 0.0
		li.shadow_enabled = false
		var lp: Vector2 = e[0]
		li.position = Vector3(lp.x, W.height(lp.x, lp.y) + 1.8, lp.y)
		M.add_child(li)
		nodes.append(li)
		flashes.append(li)
	for st in N.statics:
		if String(st.name) == "Siwy":
			siwy = st
	if siwy != null:
		siwy.lines = ["Pakuj torbę i spadamy. Wiktor czeka do szóstej.", "Nie lubię tej huty po nocy. Za cicho."]
	if W.door_tape != null:
		W.door_tape.visible = false
	W.set_mill_burnt(false)
	if not W.lab_fx.is_empty():
		W.lab_fx.bag.visible = true
		for b in W.lab_fx.bricks:
			b.visible = true


func _reset_cops() -> void:
	var W = M.world
	if cop_a != null:
		var a := P(134.0, -112.0)
		cop_a.x = a.x
		cop_a.z = a.y
		cop_a.idle = 99999.0
		cop_a.beat = null
		cop_a.notice = 0.0
		cop_a.sees = false
		cop_a.hear_t = 0.0
		# patrzy na północny róg huty: snop latarki zamyka drogę prosto na zachód, łuk na południe zostaje wolny
		cop_a.node.rotation.y = atan2(42.0, -8.0)
		cop_a.node.position = Vector3(a.x, W.height(a.x, a.y), a.y)
	if cop_b != null:
		var b := P(168.0, -100.0)
		cop_b.x = b.x
		cop_b.z = b.y
		cop_b.idle = 0.0
		cop_b.beat = [P(168.0, -60.0), P(168.0, -101.0)]
		cop_b.beat_i = 0
		cop_b.notice = 0.0
		cop_b.sees = false
		cop_b.hear_t = 0.0
		cop_b.node.rotation.y = 0.0
		cop_b.node.position = Vector3(b.x, W.height(b.x, b.y), b.y)


# ---------------------------------------------------------------- zdarzenia z gry
## czy wolno już wyjść tylnymi drzwiami
func can_exit() -> bool:
	return stage == "raid"


func act(what: String) -> void:
	if what != "pack" or stage != "lab" or G.busy or _packed:
		return
	if G.test_mode:
		# testy: cała partia od razu ląduje w torbie
		G.take_bulk(G.S.stash.lab, "snieg", 90, BATCH_G)
		G.add_bulk(G.S.inv, "snieg", 90, BATCH_G)
		_on_packed(true)
		return
	# stół otwiera się jak każda skrytka: po lewej torba, po prawej towar — przeciągasz go do siebie
	M.ui.open_inventory("lab")
	G.notify("Przeciągnij kokainę ze stołu (po prawej) do swojej torby (po lewej) i wybierz całą ilość.")


func _on_packed(instant := false) -> void:
	_packed = true
	Sfx.play("pack")
	var fxd: Dictionary = M.world.lab_fx
	if not fxd.is_empty():
		fxd.bag.visible = false
		for b in fxd.bricks:
			b.visible = false
	if instant:
		_begin_raid()
		return
	# telefon od Wiktora — przerywa go megafon
	Sfx.play("sms")
	M.ui.dialog({"name": "Wiktor (telefon)", "lines": [
		"Kuba. Za kwadrans piąta, a ja jeszcze nie śpię — zgadnij przez kogo.",
		"Zapłaciłem ci z góry dwadzieścia pięć tysięcy, bo twoje słowo było dotąd warte tyle, co gotówka. Dotąd.",
		{"n": "Ty", "t": "Pół kilo jest spakowane. Za godzinę masz je u siebie."},
		"Za godzinę. Dobrze. Bo wiesz, co mówią o ludziach, którzy znikają na trzy dni z cudzymi pieniędzmi? Nic nie mówią. Nie ma komu.",
		"Dowieź towar, Kuba. I odeśpij to, co tam robiłeś. Wyglądasz podobno jak —",
	], "on_end": _begin_raid})


func _begin_raid() -> void:
	stage = "raid"
	t = 0.0
	_bang = 0.4
	_shout = 5.5
	M.nav_force = true
	Sfx.siren(true)
	Sfx.megaphone()
	Sfx.play("alert")
	M.ui.shout("POLICJA! BUDYNEK JEST OTOCZONY!")
	M.player.shake = 0.7
	if siwy != null:
		siwy.lines = ["Leć, do cholery! Ja to odpalam!"]
	M.ui.dialog({"name": "Siwy", "lines": [
		"Psy?! Skąd oni… Trzy lata nikt o nas nie wiedział. Ktoś sypnął, Kuba. Ktoś z twoich.",
		{"n": "Ty", "t": "Siwy, chodź ze mną. Tyłem, przez tory."},
		"A kto odpali zabezpieczenie? Jak to znajdą, obaj dostaniemy po piętnaście lat. Ja zostaję. Ty masz torbę — torba ma dojść do Wiktora.",
		"Tylne drzwi. Na kucaka, cieniem, pod siatką za torami. No leć, do cholery!",
	]})


## gracz wyszedł tylnymi drzwiami na zewnątrz
func on_outside() -> void:
	stage = "escape"
	t = 0.0
	M.nav_force = true
	_reset_cops()
	for l in M.world.lab_fx.get("flash", []):
		l.light_energy = 0.0
	G.notify("Radiowozy stoją od frontu. Z tyłu kręcą się tylko dwa patrole z latarkami.", "warn")


func _caught() -> void:
	if G.busy:
		return
	G.busy = true
	tries += 1
	Sfx.megaphone()
	M.ui.shout("STÓJ! POLICJA! NA ZIEMIĘ!")
	await M.ui.fade(true)
	var e := exit_pos()
	M.player.place(Vector3(e.x, 0.0, e.y), PI / 2.0)
	_reset_cops()
	await get_tree().create_timer(0.5).timeout
	await M.ui.fade(false)
	G.busy = false
	G.notify("Zobaczyli Cię. Jeszcze raz: na kucaka [%s], bokiem od światła latarek, i dopiero gdy patrol idzie plecami do Ciebie." % G.kn("crouch"), "warn")


func _process(dt: float) -> void:
	if M == null or stage == "done" or _finishing:
		return
	t += dt
	var pl = M.player
	var pp: Vector3 = pl.global_position
	# koguty: przed hutą cały czas, w hali dopiero po rozpoczęciu nalotu
	var k := int(G.now / 0.28)
	for i in range(flashes.size()):
		# przy każdym radiowozie niebieski i czerwony migają na zmianę
		flashes[i].light_energy = 9.0 if (k + int(i / 2.0)) % 2 == 0 else 0.25
	if get_tree().paused:
		return
	# pominięcie: przytrzymany Enter
	if stage in ["lab", "raid", "escape", "run"] and not G.busy and Input.is_physical_key_pressed(KEY_ENTER):
		M.skip_hold += dt
		if M.skip_hold > 0.9:
			skip()
			return
	else:
		M.skip_hold = 0.0
	match stage:
		"lab":
			if not _packed and M.ui.mode == "" and not G.busy and G.goods_total(G.S.stash.get("lab", {"bulk": {}, "pack": {}})) < 0.5:
				_on_packed()
				return
			if t > 20.0 and not _hinted.has("table"):
				_hinted["table"] = true
				G.notify("Stół z cegłami stoi pod lampką. Podejdź, naceluj na niego i naciśnij [%s]." % G.kn("use"))
		"raid":
			var fl: Array = M.world.lab_fx.get("flash", [])
			for i in range(fl.size()):
				fl[i].light_energy = 7.0 if (k + i) % 2 == 0 else 0.2
			_bang -= dt
			if _bang <= 0.0:
				_bang = randf_range(0.9, 1.6)
				Sfx.play("door", 4.0)
				pl.shake = maxf(pl.shake, 0.35)
			_shout -= dt
			if _shout <= 0.0:
				_shout = 6.5
				Sfx.megaphone()
				M.ui.shout(["WYCHODZIĆ Z RĘKAMI W GÓRZE!", "OTWIERAĆ! POLICJA!", "OSTATNIE OSTRZEŻENIE!"].pick_random())
		"escape":
			if G.busy:
				return
			if not pl.crouching and t > 3.5 and not _hinted.has("crouch"):
				_hinted["crouch"] = true
				G.notify("Naciśnij [%s], żeby kucnąć. Na kucaka jesteś cichy i dużo mniej widoczny." % G.kn("crouch"), "warn")
			if t > 9.0 and not _hinted.has("eye"):
				_hinted["eye"] = true
				G.notify("Ikona oka przy pasku kondycji pokazuje, jak bardzo rzucasz się w oczy. Łuk przy celowniku — z której strony ktoś Cię zauważa.")
			for c in [cop_a, cop_b]:
				if c != null and c.sees:
					_caught()
					return
			if pp.x < 128.2 * D.SC and absf(pp.z - gap().y) < 12.0:
				stage = "run"
				t = 0.0
				M.nav_force = true
				Sfx.play("good")
		"run":
			if Vector2(pp.x, pp.z).distance_to(run_end()) < 3.4 or pp.x < 119.0 * D.SC:
				_boom()


# ---------------------------------------------------------------- finał: eksplozje
func _boom() -> void:
	stage = "boom"
	G.busy = true
	M.cut_skip = false
	var pl = M.player
	var W = M.world
	M.ui.cut_begin()
	var eye: Vector3 = pl.cam.global_position
	var fw: Vector2 = pl.forward()
	var look0 := eye + Vector3(fw.x, 0.0, fw.y) * 10.0
	var mill := P(186.0, -86.0)
	var mill_pt := Vector3(mill.x, W.height(mill.x, mill.y) + 7.0, mill.y)
	var cam_end := eye + Vector3(1.2, 0.5, 0.4)
	var lines := [
		[2.9, "Zabezpieczenie. Wiedziałem o nim tylko ja i Siwy."],
		[7.2, "Trzy lata roboty i całe laboratorium — w sześć sekund."],
		[11.2, "Ale ostatnia partia jest w torbie. Pół kilo. Wystarczy, żeby zacząć od no—"],
	]
	var hit_at := 14.6
	var hit := false
	var fall := 0.0
	var booms := [
		[1.9, P(177.0, -96.0), 2.5, 2.4],
		[2.8, P(186.0, -84.0), 9.0, 3.4],
		[3.5, P(181.0, -108.0), 4.0, 2.2],
		[5.2, P(192.0, -70.0), 11.0, 2.8],
	]
	var fires := [[2.2, P(175.2, -96.0), 2.0, 1.6], [3.1, P(186.0, -84.0), 15.8, 2.6], [5.5, P(192.0, -70.0), 15.8, 2.0], [3.9, P(175.2, -106.0), 3.0, 1.2]]
	var bi := 0
	var fi := 0
	var li := 0
	var tt := 0.0
	var shake := 0.0
	var faded := false
	while tt < 24.0 and not M.cut_skip:
		var dt := get_process_delta_time()
		tt += dt
		# cios w tył głowy zza garaży: błysk, kamera wali się na ziemię, obraz gaśnie
		if not hit and tt >= hit_at:
			hit = true
			Sfx.knock()
			M.ui.flash(0.9)
			M.ui.cut_line("")
			shake = 1.6
		if hit:
			fall = minf(1.0, fall + dt / 0.55)
			if tt >= hit_at + 1.6 and li == 3:
				M.ui.cut_line("— Leż, leż. Torbę biorę ja. Pozdrów Wiktora.")
				li = 4
			if tt >= hit_at + 5.4 and li == 4:
				M.ui.cut_line("Kiedy się ocknąłem, nie było torby, Siwego ani laboratorium. Został dług.")
				li = 5
		var e := clampf(tt / 1.5, 0.0, 1.0)
		e = e * e * (3.0 - 2.0 * e)
		var zoom := clampf((tt - 6.0) / 12.0, 0.0, 1.0)
		shake = maxf(0.0, shake - dt * 1.4)
		var target := look0.lerp(mill_pt, e) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 1.4
		var fe := fall * fall * (3.0 - 2.0 * fall)
		var cam_pos := eye.lerp(cam_end, zoom)
		cam_pos.y = lerpf(cam_pos.y, W.height(cam_pos.x, cam_pos.z) + 0.22, fe)
		target = target.lerp(cam_pos + Vector3(fw.x, 0.25, fw.y) * 4.0, fe)
		M.cine_cam(cam_pos, target, lerpf(float(pl.cam.fov), 46.0, e * 0.6 + zoom * 0.4) + fe * 18.0)
		if fe > 0.0:
			pl.cam.rotation.z = fe * 1.25
		while bi < booms.size() and tt >= float(booms[bi][0]):
			var bp: Vector2 = booms[bi][1]
			Fx.explosion(M, Vector3(bp.x, W.height(bp.x, bp.y) + float(booms[bi][2]), bp.y), float(booms[bi][3]))
			shake = 1.0
			M.ui.flash(0.55 if bi == 1 else 0.3)
			bi += 1
		while fi < fires.size() and tt >= float(fires[fi][0]):
			var fp: Vector2 = fires[fi][1]
			nodes.append(Fx.fire(M, Vector3(fp.x, W.height(fp.x, fp.y) + float(fires[fi][2]), fp.y), float(fires[fi][3]), fire_lights))
			fi += 1
		for i in range(fire_lights.size()):
			fire_lights[i].light_energy = (4.0 + i) * (0.7 + 0.5 * absf(sin(tt * 9.0 + i * 2.0) * sin(tt * 5.3 + i)))
		if li < lines.size() and tt >= float(lines[li][0]) and not hit:
			M.ui.cut_line(String(lines[li][1]))
			li += 1
		if not faded and tt >= hit_at + 0.9:
			faded = true
			M.ui.fade_to(1.0, 1.6)
		await get_tree().process_frame
	_finish()


## testy i zrzuty ekranu: od razu ustawia wskazany etap
func jump(to: String) -> void:
	_jumped = true
	M.cut_skip = false
	if M.ui.mode != "":
		M.ui.close_all()
	M.ui.cut_title("")
	M.ui.cut_end()
	M.ui.fade_rect.color.a = 0.0
	G.busy = false
	stage = "lab"
	t = 0.0
	if to == "lab":
		return
	var fxd: Dictionary = M.world.lab_fx
	fxd.bag.visible = false
	for b in fxd.bricks:
		b.visible = false
	_begin_raid()
	M.ui.close_all()
	if to == "raid":
		return
	var e := exit_pos()
	M.teleport("out", Vector3(e.x, 0.0, e.y), PI / 2.0)
	on_outside()
	if to == "escape":
		return
	var g := gap() + Vector2(-2.6, 0.0)
	M.player.place(Vector3(g.x, 0.0, g.y), PI / 2.0)
	stage = "run"
	if to == "boom":
		var re := run_end()
		M.player.place(Vector3(re.x, 0.0, re.y), 2.4)


func skip() -> void:
	if _finishing:
		return
	M.cut_skip = true
	if stage != "boom" and stage != "intro":
		_finish()


## sprzątanie i przejście do właściwej gry (także po pominięciu)
func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	stage = "done"
	G.busy = true
	if M.ui.mode != "":
		M.ui.close_all()
	M.ui.cut_begin()
	if M.ui.fade_rect.color.a < 0.99:
		await M.ui.fade_to(1.0, 0.35)
	M.ui.cut_line("")
	Sfx.siren(false)
	Sfx.intro_stop(1.0)
	Sfx.party_stop()
	if _party_fx != null and is_instance_valid(_party_fx):
		_party_fx.queue_free()
	M.player.cam.rotation.z = 0.0
	# torba z ostatnią partią przepadła za garażami
	G.S.inv = G.new_store()
	G.S.stash.erase("lab")
	var W = M.world
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes.clear()
	flashes.clear()
	fire_lights.clear()
	for l in W.lab_fx.get("flash", []):
		l.light_energy = 0.0
	var N = M.npcs
	for c in N.cops:
		c.idle = 0.0
		c.beat = null
		c.notice = 0.0
		c.sees = false
		c.susp = 0.0
		c.state = "patrol"
		N._snap_to_node(c)
	N.car.wait = 4.0
	N.car.seg = 0
	N.car.x = N.CAR_ROUTE[0][0] * D.SC
	N.car.z = N.CAR_ROUTE[0][1] * D.SC
	if W.door_tape != null:
		W.door_tape.visible = true
	W.set_mill_burnt(true)
	M.cut_hour = -1.0
	M.cine_off()
	G.S.nav_on = _nav_was
	G.S.flags["prologue_done"] = true
	var skipped: bool = M.cut_skip
	M.cut_skip = false
	M.ui.cut_title("TRZY TYGODNIE PÓŹNIEJ", "WYNAJĘTA KAWALERKA  •  BLOK 7, KLATKA B")
	var R: Dictionary = D.ROOMS.safe
	M.teleport("safe", Vector3(float(R.cx) - 0.6, 0.0, 1.2), 0.0)
	await _wait(1.2 if skipped else 3.4)
	M.cut_skip = false
	M.ui.cut_title("")
	await get_tree().create_timer(0.5).timeout
	M.ui.cut_end()
	G.prologue = null
	await M.ui.fade_to(0.0, 1.1)
	G.busy = false
	M.nav_force = true
	if G.running:
		M._intro()
	queue_free()
