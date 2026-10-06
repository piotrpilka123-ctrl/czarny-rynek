extends Node
## PROLOG: ostatnia noc w laboratorium w Starej Hucie.
## Pakowanie partii → nalot (megafon, koguty, łomot w bramę) → ucieczka tylnymi drzwiami, na kucaka
## obok patroli z latarkami, pod siatką za torami → bieg między garaże → eksplozje → „Trzy tygodnie później”.
## Po drodze uczy: ruchu i rozglądania, [E], kucania, trzymania się cienia i biegu.

const Fx = preload("res://scripts/fx.gd")
const Models = preload("res://scripts/models.gd")
const Chars = preload("res://scripts/chars.gd")
const Stations = preload("res://scripts/stations.gd")

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
uniform float k = 0.0;        // wyłanianie się z czerni
uniform float drive = 0.3;    // jak mocno światła biją w rytm
uniform float rush = 0.0;     // uderzenie po kresce: jaskrawo, szybko, wszystko się rozjeżdża
uniform float sick = 0.0;     // koniec: zielonkawo, mętnie, obraz pływa
uniform float bpm = 143.0;
void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float beat = pow(abs(sin(t * 3.14159 * bpm / 60.0)), 5.0);
	// zataczanie: cały obraz faluje, po kresce pulsuje od środka
	uv += vec2(sin(t * 1.3 + uv.y * 3.0), cos(t * 1.1 + uv.x * 2.5)) * (0.012 + 0.05 * sick);
	uv = (uv - 0.5) * (1.0 - 0.07 * rush * beat - 0.03 * drive * beat) + 0.5;
	vec3 c = vec3(0.0);
	float speed = 0.3 + 1.6 * rush + 0.4 * drive;
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		vec2 p = vec2(0.5 + 0.44 * sin(t * speed * (0.31 + fi * 0.07) + fi * 2.1), 0.5 + 0.38 * cos(t * speed * (0.27 + fi * 0.05) + fi * 1.3));
		float d = distance(uv, p);
		vec3 col = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + fi * 1.9 + t * (0.4 + 2.0 * rush));
		float sz = 10.0 - 4.0 * drive * beat - 3.0 * rush;
		c += col * exp(-d * d * sz) * (0.22 + 0.5 * drive * beat + 0.45 * rush);
	}
	// stroboskop na mocnych uderzeniach
	c += vec3(0.9, 0.95, 1.0) * pow(beat, 6.0) * 0.35 * drive * step(0.6, drive + rush);
	// rozszczepienie barw po kresce
	c.r *= 1.0 + 0.5 * rush * sin(uv.x * 30.0 + t * 20.0);
	c.b *= 1.0 + 0.5 * rush * cos(uv.y * 24.0 - t * 17.0);
	// miękkie przycięcie: nawet w szczycie zostają kolory, a nie biała plama
	c = 1.35 * c / (1.0 + 0.75 * c);
	c = mix(c, vec3(dot(c, vec3(0.3, 0.6, 0.1))) * vec3(0.55, 0.75, 0.35), sick * 0.8);
	float vig = smoothstep(1.0, 0.15 + 0.2 * rush, distance(UV, vec2(0.5)));
	COLOR = vec4(c * vig * k * (1.0 - 0.45 * sick), 1.0);
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
			return {"text": func(): return ("Chodź klawiszami [%s][%s][%s][%s], rozglądaj się myszą. Podejdź do stołu z cegłami, naceluj i naciśnij [%s] — a potem spakuj partię: przeciągnij kokainę ze stołu do swojej torby." % [G.kn("fwd"), G.kn("left"), G.kn("back"), G.kn("right"), G.kn("use")]) if not _packed else "Dzwoni telefon — odbierz: [%s]." % G.kn("phone"),
				"done": func(): return false, "marker": func(): return {"loc": "lab", "x": float(R.cx) + 1.6, "z": 2.4}}
		"raid":
			return {"text": func(): return "NALOT! Uciekaj tylnymi drzwiami — naceluj na nie i naciśnij [%s]." % G.kn("use"),
				"done": func(): return false, "marker": func(): return {"loc": "lab", "x": M.world.lab_exit.x, "z": M.world.lab_exit.y}}
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
	Sfx.score("napiecie", 1.5, 3.0, 0.0)
	M.ui.dialog({"name": "Siwy", "lines": [
		"No, wreszcie. Za kwadrans piąta, Kuba. Trzy dni cię nie było.",
		"Pół kilo stoi na stole — najczystszy śnieg, jaki z tej huty wyszedł. Wiktor zapłacił z góry i czeka do szóstej.",
		{"n": "Ty", "t": "Dowieziemy to i robimy przerwę. Długą."},
		"Ty i przerwa. Pakuj torbę, ja doglądam kolby.",
	]})


## Otwarcie: nieprzerwany melanż widziany przez mgłę. Z czerni wyłaniają się rozmyte światła i bas zza ściany,
## filtr się otwiera, muzyka wybucha, kreska za kreską — aż wszystko zielenieje i głuchnie. Potem czerń i jedno zdanie.
func _party() -> void:
	var U = M.ui
	_party_fx = ColorRect.new()
	_party_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_party_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_fx.color = Color.BLACK
	var sh := Shader.new()
	sh.code = SH_PARTY
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_party_fx.material = sm
	U.cut.add_child(_party_fx)
	U.cut.move_child(_party_fx, 0)
	Sfx.party_play()
	Sfx.party_sfx("gwar_baru", -6.0)
	# [czas, co] — "T:tekst" = napis, reszta to zdarzenia dźwięku i obrazu
	var ev := [
		[2.6, "T:— Kuba! Kuba, chodź tu! Polej mu!"],
		[4.6, "okrzyki_1"], [6.6, "smiech_1"],
		[7.2, "T:— Jeszcze jedną. Ostatnią. Słowo."],
		[11.4, "brawa_bar"], [12.0, "DROP"], [12.1, "okrzyki_2"],
		[13.4, "T:(ktoś sypie kreskę na blat)"],
		[14.6, "SNIFF1"],
		[16.4, "T:— O kurwa. O, tak. Podgłośnij to!"],
		[17.2, "spiew"], [18.6, "smiech_2"],
		[20.4, "T:— Która to doba? Trzecia? Czwarta?"],
		[22.4, "okrzyki_1"],
		[24.2, "T:— Kuba, telefon. To znowu Siwy. Odbierzesz w końcu?"],
		[24.4, "wibracja"],
		[25.6, "SICK"],
		[26.4, "T:— Zaraz. Zaraz, tylko —"],
		# bieg do łazienki, drzwi, dopiero potem torsje
		[26.8, "STEPS"], [28.0, "DOOR"],
		[28.7, "wymioty_1"],
		[30.9, "wymioty_2"],
		[32.6, "T:— Stary, ty w ogóle jeszcze żyjesz? Siwy mówi, że partia czeka."],
		[35.4, "T:— …Żyję. Powiedz mu, że jadę."],
	]
	var ei := 0
	var tt := 0.0
	var cut_hz := 180.0
	var cut_to := 180.0
	var drive := 0.3
	var drive_to := 0.3
	var rush := 0.0
	var sick := 0.0
	var sick_to := 0.0
	while tt < 38.6 and not M.cut_skip and not _jumped:
		var dt := get_process_delta_time()
		tt += dt
		while ei < ev.size() and tt >= float(ev[ei][0]):
			var what := String(ev[ei][1])
			ei += 1
			if what.begins_with("T:"):
				U.cut_line(what.substr(2))
			elif what == "DROP":
				cut_to = 19000.0
				drive_to = 1.0
				U.flash(0.5)
			elif what == "SNIFF1":
				# jedno wciągnięcie, nie cała seria z nagrania
				Sfx.party_sfx("wciaganie_1", 7.0, 1.0, true, 0.15, 1.25)
				rush = 1.0
				U.flash(0.3)
			elif what == "STEPS":
				Sfx.party_steps(6, 0.18)
			elif what == "DOOR":
				Sfx.play("door", 6.0)
			elif what == "SICK":
				cut_to = 320.0
				drive_to = 0.25
				sick_to = 1.0
			elif what == "wibracja":
				Sfx.party_sfx(what, -2.0)
			elif what == "wymioty_1" or what == "wymioty_2":
				Sfx.party_sfx(what, 9.0, 1.0, true)
				cut_to = 220.0
			elif what == "spiew":
				Sfx.party_sfx(what, -5.0, 1.04)
			else:
				Sfx.party_sfx(what, -1.0)
		# filtr: najpierw powoli uchyla się sam, potem skacze do zadanej wartości
		if tt < 11.8:
			cut_to = lerpf(180.0, 2400.0, clampf((tt - 2.0) / 9.8, 0.0, 1.0) * clampf((tt - 2.0) / 9.8, 0.0, 1.0))
		cut_hz = lerpf(cut_hz, cut_to, minf(1.0, dt * (9.0 if cut_to > cut_hz else 1.1)))
		Sfx.party_cut(cut_hz)
		Sfx.party_vol(lerpf(-26.0, 5.0, clampf(tt / 5.0, 0.0, 1.0)) - sick * 5.0)
		drive = lerpf(drive, drive_to, minf(1.0, dt * 4.0))
		rush = maxf(0.0, rush - dt / 2.6)
		sick = lerpf(sick, sick_to, minf(1.0, dt * 0.6))
		sm.set_shader_parameter("k", clampf((tt - 0.6) / 4.5, 0.0, 1.0))
		sm.set_shader_parameter("drive", drive)
		sm.set_shader_parameter("rush", rush)
		sm.set_shader_parameter("sick", sick)
		await get_tree().process_frame
	# cięcie: cisza i czerń
	Sfx.party_stop()
	if is_instance_valid(_party_fx):
		_party_fx.queue_free()
	_party_fx = null
	U.cut_line("")
	if M.cut_skip or _jumped:
		return
	await _wait(1.6)
	U.cut_title("WSZYSTKO SIĘ KIEDYŚ KOŃCZY.", "")
	await _wait(3.8)
	U.cut_title("")
	await _wait(1.0)


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
	# telefon od Wiktora: dzwoni, dopóki nie odbierzesz; rozmawiasz, chodząc po hali — przerywa go megafon
	M.ui.call_start("Wiktor", [
		"Kuba. Za kwadrans piąta, a ja jeszcze nie śpię — zgadnij przez kogo.",
		"Zapłaciłem z góry dwadzieścia pięć tysięcy, bo twoje słowo było dotąd warte tyle, co gotówka. Dotąd.",
		{"n": "Ty", "t": "Pół kilo jest spakowane. Za godzinę masz je u siebie."},
		"Dowieź towar, Kuba. Bo o ludziach, którzy znikają z cudzymi pieniędzmi, nikt potem nie opowiada. Nie ma —",
	], _begin_raid)


func _begin_raid() -> void:
	stage = "raid"
	t = 0.0
	_bang = 0.4
	_shout = 5.5
	M.nav_force = true
	Sfx.score("akcja", 2.5, 0.6, 3.0)
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
	Sfx.score("skradanie", 2.5, 1.5, 3.0)
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


# ---------------------------------------------------------------- finał: eksplozje i cios zza garaży
var attacker := {}
var boom_car: Node3D = null
var drop_bag: Node3D = null

## Przerywnik: huta wylatuje w powietrze (szyby, gruz, ogień z okien), fala odrzuca patrol, radiowóz staje w ogniu.
## Potem kroki za plecami, czyjś głos, obrót — i rurka. Kamera pada na ziemię, napastnik zabiera torbę.
func _boom() -> void:
	stage = "boom"
	G.busy = true
	M.cut_skip = false
	var pl = M.player
	var W = M.world
	M.ui.cut_begin()
	# skradanie powoli cichnie; odwracasz się na hutę w ciszy i dopiero wybuch przynosi muzykę
	Sfx.score("", 2.5)
	var eye: Vector3 = pl.cam.global_position
	var fw: Vector2 = pl.forward()
	var look0 := eye + Vector3(fw.x, 0.0, fw.y) * 10.0
	var mill := P(186.0, -86.0)
	var mill_pt := Vector3(mill.x, W.height(mill.x, mill.y) + 7.0, mill.y)
	var cam_end := eye + Vector3(1.2, 0.5, 0.4)
	# --- obsada: dwóch policjantów i radiowóz między garażami a hutą
	var actors: Array = []
	var cop_at := [P(160.0, -80.5), P(164.5, -90.0)]
	for i in range(2):
		var c = [cop_a, cop_b][i]
		if c == null:
			continue
		c["scripted"] = true
		c.x = cop_at[i].x
		c.z = cop_at[i].y
		c.node.position = Vector3(c.x, W.height(c.x, c.z), c.z)
		c.node.rotation.y = atan2(mill.x - c.x, mill.y - c.z)
		c.node.visible = true
		Chars.set_active(c.rig, true)
		Chars.set_armed(c.rig, true)
		Chars.play(c.rig, "Pistol_Idle")
		actors.append({"c": c, "kb": -1.0, "from": Vector3.ZERO})
	var cpos := P(168.5, -76.0)
	boom_car = Models.car("sedan", "ffffff", true)
	M.add_child(boom_car)
	nodes.append(boom_car)
	var car_y: float = W.height(cpos.x, cpos.y)
	boom_car.position = Vector3(cpos.x, car_y, cpos.y)
	boom_car.rotation.y = 2.3
	var car_lights: Array = []
	for k in range(2):
		var cl := OmniLight3D.new()
		cl.light_color = Color(0.15, 0.35, 1.0) if k == 0 else Color(1.0, 0.12, 0.1)
		cl.omni_range = 16.0
		cl.shadow_enabled = false
		cl.position = Vector3(cpos.x + k * 0.4, car_y + 1.7, cpos.y)
		M.add_child(cl)
		nodes.append(cl)
		car_lights.append(cl)
	# --- napastnik czeka za plecami (poza kadrem)
	var md := Vector2(mill.x - eye.x, mill.y - eye.z).normalized()
	var rgt := Vector2(-md.y, md.x)
	# napastnik staje za plecami tam, gdzie jest wolne miejsce, i odejdzie w stronę, na której nic nie stoi
	var here := Vector2(eye.x, eye.z)
	var apos := here - md * 1.9 + rgt * 0.55
	for ang in [0.0, 0.5, -0.5, 0.95, -0.95, 1.4, -1.4]:
		var cand: Vector2 = here + (-md).rotated(ang) * 1.9
		if not W.grid.is_point_solid(W._cell(cand.x, cand.y)) and not W.grid.is_point_solid(W._cell((here.x + cand.x) * 0.5, (here.y + cand.y) * 0.5)):
			apos = cand
			break
	var ground: float = W.height(eye.x, eye.z)
	var arig: Dictionary = Chars.make({"model": "m09", "kind": "hoodie", "seed": 77, "top": "15161a", "bottom": "101114", "tall": 1.04})
	M.add_child(arig.root)
	nodes.append(arig.root)
	arig.root.position = Vector3(apos.x, W.height(apos.x, apos.y), apos.y)
	arig.root.rotation.y = atan2(eye.x - apos.x, eye.z - apos.y)
	arig.root.visible = false
	# bandyta w prawdziwych ciuchach: czarna bluza, bojówki, skórzane rękawiczki, robocze buty, kominiarka
	Chars.dress(arig, {"glowa": "kominiarka", "gora": "bluza_kaptur", "spodnie": "bojowki", "dlonie": "rekawiczki_skora", "buty": "buty_robocze"},
		{"gora": Color(0.2, 0.2, 0.22), "spodnie": Color(0.28, 0.28, 0.3), "buty": Color(0.35, 0.33, 0.32)})
	Chars.hold(arig, "rurka", Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3(0.09, 0.03, 0.0)))
	Chars.play(arig, "Idle")
	attacker = arig
	drop_bag = Stations.duffel()
	M.add_child(drop_bag)
	nodes.append(drop_bag)
	drop_bag.visible = false
	# łuna pożaru: ciepłe, migające światło od strony huty — to ono wydobywa napastnika z ciemności
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.22)
	glow.omni_range = 9.0
	glow.omni_attenuation = 0.8
	glow.light_energy = 0.0
	glow.shadow_enabled = false
	M.add_child(glow)
	nodes.append(glow)
	glow.global_position = eye + Vector3(md.x, 0.0, md.y) * 2.6 + Vector3(0, 1.2, 0)
	# --- rozkład zdarzeń
	var lines := [
		[2.9, "Zabezpieczenie. Wiedziałem o nim tylko ja i Siwy."],
		[7.6, "Trzy lata roboty i całe laboratorium — w sześć sekund."],
		[10.8, "Ale ostatnia partia jest w torbie. Pół kilo. Wystarczy, żeby zacząć od no—"],
	]
	# zanim cokolwiek wybuchnie: kilka sekund ciszy i myśli o wspólniku, który został w środku
	var S0 := 7.2
	var thoughts := [
		[1.2, "Siwy został w środku. Sam. „Ja to odpalam” — tak powiedział."],
		[4.2, "Zdążył wyjść? Powinien już być za torami. No dalej, stary…"],
	]
	var thi := 0
	var booms := [
		[1.9, P(177.0, -96.0), 2.5, 2.4],
		[2.8, P(186.0, -84.0), 9.0, 3.4],
		[3.5, P(181.0, -108.0), 4.0, 2.2],
		[5.2, P(192.0, -70.0), 11.0, 2.8],
		[8.6, P(178.0, -74.0), 3.0, 1.3],
		[10.1, P(176.5, -101.0), 6.0, 1.1],
	]
	var fires := [[1.92, P(175.2, -96.0), 2.0, 1.6], [2.82, P(186.0, -84.0), 15.8, 2.6], [5.22, P(192.0, -70.0), 15.8, 2.0], [3.52, P(175.2, -106.0), 3.0, 1.2],
		[2.0, P(175.3, -88.0), 6.5, 1.5], [2.3, P(175.3, -80.0), 4.2, 1.3], [2.9, P(175.3, -100.0), 8.0, 1.4], [3.7, P(175.3, -72.0), 7.0, 1.2]]
	# pożary odpalają się w kolejności czasu (wcześniej późniejszy wpis blokował wcześniejsze i ogień się spóźniał)
	fires.sort_custom(func(a, b): return a[0] < b[0])
	# okna zachodniej ściany: z każdego lecą szyby i bucha ogień
	var wins: Array = []
	for wi in range(7):
		for hy in [4.4, 8.2]:
			wins.append([1.9 + wi * 0.07 + (0.5 if hy > 6.0 else 0.0) + randf() * 0.15, P(175.4, -104.0 + wi * 5.6), hy])
	wins.sort_custom(func(a, b): return a[0] < b[0])
	var steps_at := [12.4, 12.85, 13.25]
	var t_voice := 13.35
	var t_turn := 13.55
	var t_swing := 14.05
	var hit_at := 14.5
	var bi := 0
	var fi := 0
	var li := 0
	var wi2 := 0
	var si := 0
	var tt := 0.0
	var shake := 0.0
	var hit := false
	var fall := 0.0
	var car_done := false
	var car_v := 0.0
	var car_t := -1.0
	var voiced := false
	var swung := false
	var grabbed := 0
	var out_dir := (Vector2(apos.x - eye.x, apos.y - eye.z)).normalized()
	var best_free := -1
	for ang2 in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, 2.4, -2.4, PI]:
		var dd := (apos - here).normalized().rotated(ang2)
		var free := 0
		for st2 in range(1, 9):
			var q: Vector2 = apos + dd * (st2 * 0.8)
			if W.grid.is_point_solid(W._cell(q.x, q.y)):
				break
			free += 1
		if free > best_free:
			best_free = free
			out_dir = dd
		if free >= 8:
			break
	# testy i zrzuty: --boomt=sekundy przeskakuje zegar przerywnika
	tt = float(M.args.get("boomt", "0"))
	var tm := -S0
	var said := false
	var bent := false
	while tm < 24.2 and not M.cut_skip:
		var dt := get_process_delta_time()
		tt += dt
		if M.args.has("boomhold"):
			# zrzuty: zegar staje w wybranej chwili po ciosie
			tt = minf(tt, S0 + hit_at + float(M.args.boomhold))
		# tm: czas od chwili, w której kończą się myśli (ujemny = jeszcze cisza przed wybuchem)
		tm = tt - S0
		if thi < thoughts.size() and tt >= float(thoughts[thi][0]):
			M.ui.cut_line(String(thoughts[thi][1]))
			thi += 1
		if thi == thoughts.size() and tm > -0.5:
			thi += 1
			M.ui.cut_line("")
		var e := clampf(tt / 1.5, 0.0, 1.0)
		e = e * e * (3.0 - 2.0 * e)
		var zoom := clampf((tm - 6.0) / 12.0, 0.0, 1.0)
		shake = maxf(0.0, shake - dt * 1.4)
		# --- wybuchy, ogień, szyby
		while bi < booms.size() and tm >= float(booms[bi][0]):
			var bp: Vector2 = booms[bi][1]
			var bpos := Vector3(bp.x, W.height(bp.x, bp.y) + float(booms[bi][2]), bp.y)
			Fx.explosion(M, bpos, float(booms[bi][3]))
			# pierwszy wybuch: po ciszy i myślach o Siwym wchodzi motyw utraty wszystkiego
			Sfx.score("dramat", 0.05, 0.05, 0.0)
			Fx.shards(M, bpos, Vector3(-0.5, 1.0, 0.1), "debris", int(60 * float(booms[bi][3])), 20.0, 55.0, 0.2)
			shake = maxf(shake, 0.5 + float(booms[bi][3]) * 0.25)
			M.ui.flash(0.6 if bi == 1 else 0.28)
			if bi == 1:
				# główny wybuch: fala uderzeniowa zwala patrol z nóg
				for a in actors:
					a.kb = 0.0
					a.from = a.c.node.position
					Chars.one_shot(a.c.rig, "Hit_Knockback")
			bi += 1
		while wi2 < wins.size() and tm >= float(wins[wi2][0]):
			var wp: Vector2 = wins[wi2][1]
			var wpos := Vector3(wp.x, W.height(wp.x, wp.y) + float(wins[wi2][2]), wp.y)
			Fx.shards(M, wpos, Vector3(-1.0, 0.25, 0.0), "glass", 110, 15.0, 26.0, 0.075)
			Fx.jet(M, wpos, Vector3(-1.0, 0.35, 0.0), 1.0)
			wi2 += 1
		while fi < fires.size() and tm >= float(fires[fi][0]):
			var fp: Vector2 = fires[fi][1]
			nodes.append(Fx.fire(M, Vector3(fp.x, W.height(fp.x, fp.y) + float(fires[fi][2]), fp.y), float(fires[fi][3]), fire_lights))
			fi += 1
		for i in range(fire_lights.size()):
			fire_lights[i].light_energy = (4.0 + (i % 5)) * (0.7 + 0.5 * absf(sin(tt * 9.0 + i * 2.0) * sin(tt * 5.3 + i)))
		glow.light_energy = clampf((tm - 1.9) / 0.9, 0.0, 1.0) * (2.6 + 1.1 * absf(sin(tt * 7.3) * sin(tt * 4.1 + 1.0)))
		# --- patrol: odrzut, potem kuli się za osłoną
		for a in actors:
			if float(a.kb) < 0.0:
				continue
			a.kb = float(a.kb) + dt
			var c = a.c
			var away := Vector3(c.x - mill.x, 0.0, c.z - mill.y).normalized()
			var kq := clampf(float(a.kb) / 0.55, 0.0, 1.0)
			var np: Vector3 = a.from + away * 2.4 * (1.0 - (1.0 - kq) * (1.0 - kq))
			c.x = np.x
			c.z = np.z
			c.node.position = Vector3(np.x, W.height(np.x, np.z), np.z)
			if float(a.kb) > 1.7 and c.rig.cur != "Crouch_Idle":
				Chars.play(c.rig, "Crouch_Idle", 1.0, 0.4)
		# --- radiowóz: koguty, potem zbiornik paliwa
		if not car_done:
			var kf := int(tt / 0.28)
			for k in range(car_lights.size()):
				car_lights[k].light_energy = 7.0 if (kf + k) % 2 == 0 else 0.2
			if tm >= 6.7:
				car_done = true
				car_t = 0.0
				car_v = 7.5
				for cl2 in car_lights:
					cl2.light_energy = 0.0
				var cp3 := boom_car.position + Vector3(0, 0.8, 0)
				Fx.explosion(M, cp3, 1.7)
				Fx.shards(M, cp3, Vector3(0, 1, 0), "glass", 120, 13.0, 75.0, 0.09)
				Fx.shards(M, cp3, Vector3(0, 1, 0), "debris", 60, 16.0, 70.0, 0.22)
				shake = 1.2
				M.ui.flash(0.45)
				_char(boom_car)
		elif car_t >= 0.0:
			# podrzucony wrak koziołkuje i spada
			car_t += dt
			car_v -= 12.0 * dt
			boom_car.position.y += car_v * dt
			boom_car.rotation.x += dt * 2.6
			boom_car.rotation.z += dt * 1.1
			if boom_car.position.y <= car_y + 0.35 and car_v < 0.0:
				boom_car.position.y = car_y + 0.35
				boom_car.rotation.x = PI * 0.92
				car_t = -1.0
				shake = maxf(shake, 0.5)
				Sfx.play("door", 6.0)
				nodes.append(Fx.fire(M, boom_car.position + Vector3(0, 0.4, 0), 1.4, fire_lights))
		# --- narracja
		if li < lines.size() and tm >= float(lines[li][0]) and not hit:
			M.ui.cut_line(String(lines[li][1]))
			li += 1
		# --- ktoś idzie od tyłu
		if si < steps_at.size() and tm >= float(steps_at[si]):
			Sfx.step("gravel", false)
			si += 1
			arig.root.visible = true
		if not voiced and tm >= t_voice:
			voiced = true
			Sfx.mumble(0.8)
			M.ui.cut_line("— Kuba.")
		if not swung and tm >= t_swing:
			swung = true
			Chars.one_shot(arig, "Melee_Hook")
		if not hit and tm >= hit_at:
			hit = true
			Sfx.knock()
			M.ui.flash(0.95)
			M.ui.cut_line("")
			shake = 1.8
			var bp2 := Vector2(eye.x, eye.z) + out_dir * 0.75 - md * 0.25
			drop_bag.position = Vector3(bp2.x, W.height(bp2.x, bp2.y), bp2.y)
			drop_bag.rotation.y = 0.9
			drop_bag.visible = true
		# --- kamera: huta → obrót na głos → upadek
		var cam_pos := eye.lerp(cam_end, zoom)
		var dir_m := (mill_pt - cam_pos).normalized()
		var dir_l := (look0 - cam_pos).normalized()
		var dir := dir_l.slerp(dir_m, e)
		var head: Vector3 = arig.root.position + Vector3(0, 1.6, 0)
		var turn := clampf((tm - t_turn) / 0.55, 0.0, 1.0)
		turn = turn * turn * (3.0 - 2.0 * turn)
		if turn > 0.0:
			dir = dir.slerp((head - cam_pos).normalized(), turn)
		var fov := lerpf(float(pl.cam.fov), 46.0, e * 0.6 + zoom * 0.4)
		fov = lerpf(fov, 64.0, turn)
		if hit:
			fall = minf(1.0, fall + dt / 0.5)
			var fe := 1.0 - (1.0 - fall) * (1.0 - fall)
			cam_pos = cam_pos.lerp(Vector3(cam_pos.x - md.x * 0.35, ground + 0.2, cam_pos.z - md.y * 0.35), fe)
			var low: Vector3 = (drop_bag.position.lerp(arig.root.position, 0.5) + Vector3(0, 0.55, 0)) if grabbed < 2 else (arig.root.position + Vector3(0, 0.9, 0))
			dir = dir.slerp((low - cam_pos).normalized(), fe)
			fov = lerpf(fov, 78.0, fe)
		var target := cam_pos + dir * 6.0 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.25
		M.cine_cam(cam_pos, target, fov)
		if hit:
			M.cine.rotate_object_local(Vector3(0, 0, 1), (1.0 - (1.0 - fall) * (1.0 - fall)) * 1.15)
			# powieki: cios → ciemność → mrugnięcie (torba i bandyta nad nią) → ciemność → mrugnięcie (odchodzi, torby już nie ma) → ciemność
			var ht := tm - hit_at
			var open := 0.0
			if ht < 0.45:
				open = 1.0 - ht / 0.45
			elif ht >= 1.7 and ht < 3.1:
				open = minf(1.0, (ht - 1.7) / 0.28) * (1.0 - clampf((ht - 2.85) / 0.25, 0.0, 1.0))
			elif ht >= 4.3 and ht < 6.7:
				open = minf(1.0, (ht - 4.3) / 0.3) * (1.0 - clampf((ht - 5.9) / 0.8, 0.0, 1.0))
			_lids(open)
			M.ui.fade_rect.color.a = (0.2 + 0.07 * sin(ht * 2.4)) if open > 0.02 else 0.0
			if grabbed == 0 and ht >= 0.6:
				grabbed = 1
				# w ciemności bandyta staje nad torbą, twarzą do leżącego
				var bpos2: Vector3 = drop_bag.position
				var side := Vector3(out_dir.x, 0.0, out_dir.y) * 0.55
				arig.root.position = Vector3(bpos2.x + side.x, W.height(bpos2.x + side.x, bpos2.z + side.z), bpos2.z + side.z)
				arig.root.rotation.y = atan2(cam_pos.x - arig.root.position.x, cam_pos.z - arig.root.position.z)
				Chars.play(arig, "Idle", 1.0, 0.0)
			if grabbed == 1 and not said and ht >= 1.9:
				said = true
				Sfx.mumble(0.8)
				M.ui.cut_line("— Leż, leż. Torbę biorę ja. Pozdrów Wiktora.")
			if grabbed == 1 and not bent and ht >= 2.25:
				bent = true
				var bd := Vector2(drop_bag.position.x - arig.root.position.x, drop_bag.position.z - arig.root.position.z)
				arig.root.rotation.y = atan2(bd.x, bd.y)
				Chars.one_shot(arig, "PickUp_Table")
			if grabbed == 1 and ht >= 3.3:
				grabbed = 2
				# oczy zamknięte: torba znika, bandyta jest już kilka kroków dalej, plecami do nas
				drop_bag.visible = false
				M.ui.cut_line("")
				var far: Vector3 = drop_bag.position + Vector3(out_dir.x, 0.0, out_dir.y) * 2.4
				arig.root.position = Vector3(far.x, W.height(far.x, far.z), far.z)
				arig.root.rotation.y = atan2(out_dir.x, out_dir.y)
				Chars.play(arig, "Walk", 1.0, 0.0)
			if grabbed == 2:
				arig.root.position += Vector3(out_dir.x, 0.0, out_dir.y) * 1.25 * dt
				arig.root.position.y = W.height(arig.root.position.x, arig.root.position.z)
			if li == 3 and ht >= 7.0:
				li = 4
				M.ui.cut_line("Kiedy się ocknąłem, nie było torby, Siwego ani laboratorium. Został dług.")
		await get_tree().process_frame
	M.ui.fade_rect.color.a = 1.0
	_lids(-1.0)
	_finish()


var _lid: Array = []

## powieki: dwa czarne pasy schodzące się z góry i z dołu. open = 1 oczy otwarte, 0 zamknięte, ujemne = sprzątnij
func _lids(open: float) -> void:
	if open < 0.0:
		for l in _lid:
			if is_instance_valid(l):
				l.queue_free()
		_lid.clear()
		return
	if _lid.is_empty():
		var host: Node = M.ui.fade_rect.get_parent()
		for k in range(2):
			var r := ColorRect.new()
			r.color = Color.BLACK
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.anchor_left = 0.0
			r.anchor_right = 1.0
			host.add_child(r)
			host.move_child(r, M.ui.fade_rect.get_index() + 1)
			_lid.append(r)
	var cover := 0.52 * (1.0 - clampf(open, 0.0, 1.0))
	var top: ColorRect = _lid[0]
	top.anchor_top = 0.0
	top.anchor_bottom = cover
	top.offset_top = 0.0
	top.offset_bottom = 0.0
	var bot: ColorRect = _lid[1]
	bot.anchor_top = 1.0 - cover
	bot.anchor_bottom = 1.0
	bot.offset_top = 0.0
	bot.offset_bottom = 0.0


## zwęglony wrak: wszystkie części dostają czarny, matowy lakier
func _char(n: Node) -> void:
	var burnt := Models.mat("0c0b0a", 0.95)
	var stack: Array = [n]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
		if nd is MeshInstance3D:
			(nd as MeshInstance3D).material_override = burnt
		elif nd is Light3D:
			(nd as Light3D).visible = false


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
	Sfx.score("", 3.0)
	Sfx.intro_stop(1.0)
	Sfx.party_stop()
	if _party_fx != null and is_instance_valid(_party_fx):
		_party_fx.queue_free()
	for c in [cop_a, cop_b]:
		if c != null:
			c["scripted"] = false
			Chars.set_armed(c.rig, false)
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
