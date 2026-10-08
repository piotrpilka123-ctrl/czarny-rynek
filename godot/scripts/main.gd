extends Node3D
## Scena główna: składa świat, gracza, postacie i interfejs; pętla rozgrywki,
## przejścia między lokacjami, skrytki, pościgi, nawigacja, meblowanie kryjówek.

const WorldScript = preload("res://scripts/world.gd")
const EnvScript = preload("res://scripts/env.gd")
const PlayerScript = preload("res://scripts/player.gd")
const NavScript = preload("res://scripts/nav.gd")
const NpcScript = preload("res://scripts/npc.gd")
const UiScript = preload("res://scripts/ui.gd")
const LoadingScript = preload("res://scripts/loading.gd")
const Models = preload("res://scripts/models.gd")
const Chars = preload("res://scripts/chars.gd")
const Props = preload("res://scripts/props.gd")
const CareScript = preload("res://scripts/care.gd")
const Stations = preload("res://scripts/stations.gd")
const K = preload("res://scripts/uikit.gd")

const C_ORDER := Color(0.29, 0.87, 0.5)
const C_STORY := Color(0.98, 0.75, 0.14)
const C_PLACE := Color(0.38, 0.65, 0.98)
const C_DROP := Color(0.93, 0.35, 0.8)
const TITLE_POS := Vector3(-14.0 * 0.56, 0.0, -58.0 * 0.56)
const TITLE_YAW := -2.2
const TITLE_HOUR := 18.8

var world: Node3D
var env: Node3D
var player: CharacterBody3D
var nav: Node3D
var npcs: Node3D
var ui: CanvasLayer
var beacon: Node3D
var beacon_mat: StandardMaterial3D
var cut_skip := false          # gracz pominął przerywnik
var skip_hold := 0.0           # jak długo trzymany jest Enter (pominięcie prologu)
var cut_hour := -1.0           # godzina wymuszona na czas przerywnika (-1 = czas gry)
var cut_nodes: Array = []
var cur_inter = null
var aim_hints: Array = []
var hold_inter = null
var hold_t := 0.0
var slow_t := 0.0
var nav_t := 0.0
var nav_force := true
var nav_last := Vector2(1e9, 1e9)
var nav_goal := Vector2(1e9, 1e9)
var cop_t := 0.0
var title_t := 0.0
var args := {}
var cine: Camera3D = null
var prof := [0, 0, 0, 0]
var ditch_hold := 0.0
var stones: Array = []          # lecące kamyki: {node, p, v, seen}
var throw_cd := 0.0
var hide_at := {}               # kryjówka, w której siedzi gracz
var drop_actors := {}           # kurierzy i zasadzki przy paczkach: id paczki → {static} albo {cop}
var way := {}                 # znacznik celu na ekranie: {pos, color, dist}
var build := {}               # tryb ustawiania mebla: {fid, room, r, ghost, mark, valid, x, z}
var care: Node3D = null       # animacje doglądania krzaków (scripts/care.gd)
var menu_id := ""             # cel, którego menu czynności jest na ekranie
var menu_sel := 0
var menu_opts: Array = []
var early_cut_t := 0.0        # potwierdzenie ścięcia niedojrzałej rośliny


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Props.shadow_proxy_on = not args.has("noproxy")
	G.main = self
	G.test_mode = args.has("shot") or args.has("test") or args.has("rec") or args.has("recklub") or args.has("tour") or args.has("trailer")
	if G.test_mode or args.has("mute"):
		Sfx.set_muted(true)
	if G.test_mode:
		# okno testowe nie zabiera klawiatury użytkownikowi
		get_window().unfocusable = true
		if args.has("hidden"):
			# Okno testowe poza ekranem: nie zasłania pracy użytkownikowi. System nie rysuje wtedy okna sam,
			# więc każdą klatkę wymuszamy ręcznie (bez wyświetlania) — obraz trafia tylko do zrzutów.
			var w := get_window()
			w.borderless = true
			w.position = Vector2i(-9000, -9000)
			get_tree().process_frame.connect(_force_frame)

	load_settings()
	# ekran ładowania (pomijany w testach, żeby start pozostał synchroniczny)
	var loader = null
	if not G.test_mode and not args.has("noload"):
		loader = LoadingScript.new()
		add_child(loader)
		loader.build()
		await get_tree().process_frame
		await get_tree().process_frame
	world = WorldScript.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	G.world = world
	await world.build(loader)
	if loader != null:
		await loader.step(80.0, "Setting the sun")
	env = EnvScript.new()
	env.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(env)
	G.env = env
	if args.has("quality"):
		settings.quality = String(args.quality)
	env.quality = String(settings.get("quality", "med"))
	env.build(world.noise_tex)
	get_window().size_changed.connect(env.apply_scale)
	_light_ranges(world)
	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	G.player = player
	nav = NavScript.new()
	nav.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(nav)
	if loader != null:
		await loader.step(86.0, "Waking up the neighbours")
	npcs = NpcScript.new()
	npcs.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(npcs)
	G.npcs = npcs
	care = CareScript.new()
	add_child(care)
	npcs.build()
	if loader != null:
		await loader.step(95.0, "Charging your phone")
	ui = UiScript.new()
	add_child(ui)
	G.ui = ui
	ui.build()
	apply_settings()
	_build_beacon()
	G.nav_dirty.connect(func(): nav_force = true)

	if args.has("autostart"):
		start_game(args.has("load"))
		_apply_test_args()
	else:
		to_title()
	if loader != null:
		await loader.finish()
		if args.has("loadshot"):
			get_tree().quit()
			return
	if args.has("mapdump"):
		# zrzut danych mapy do planowania (obraz minimapy + graf ścieżek + przeszkody)
		var md := String(args.mapdump)
		DirAccess.make_dir_recursive_absolute(md)
		world.map_tex.get_image().save_png(md + "/map.png")
		var edges := []
		for n in world.wp:
			for j in n.links:
				if int(j) > int(n.i):
					edges.append([n.x / D.SC, n.z / D.SC, world.wp[j].x / D.SC, world.wp[j].z / D.SC])
		var rc := []
		for c in world.rects:
			if float(c.x0) < 400.0:
				rc.append([c.x0 / D.SC, c.z0 / D.SC, c.x1 / D.SC, c.z1 / D.SC, c.h])
		var mf := FileAccess.open(md + "/map.json", FileAccess.WRITE)
		mf.store_string(JSON.stringify({"edges": edges, "rects": rc, "x0": world.X0, "z0": world.Z0}))
		mf.close()
		print("MAPDUMP ok")
		get_tree().quit()
		return
	if args.has("pts"):
		add_child(load("res://scripts/audit_pts.gd").new())
		return
	if args.has("audit"):
		var au: Node = load("res://scripts/audit.gd").new()
		au.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(au)
		return
	if args.has("trailer"):
		var tr: Node = load("res://scripts/trailer.gd").new()
		tr.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(tr)
		return
	if args.has("tour"):
		G.test_mode = true
		_tour()
		return
	if args.has("shot"):
		_shot()
	if args.has("rec"):
		_record()
	if args.has("recklub"):
		_record_klub()
	if args.has("glosy"):
		# kontrola głosów bez słuchania: czeka na wygenerowanie barw i wypisuje głośność oraz wysokość każdej z nich
		var tries := 0
		while Sfx._banks.size() < Sfx.VOICES.size() and tries < 1200:
			tries += 1
			await get_tree().process_frame
		for vn in Sfx.VOICES:
			var bank: Array = Sfx._banks.get(vn, [])
			if bank.is_empty():
				print("GLOS %-14s BRAK" % vn)
				continue
			var peak := 0.0
			var sq := 0.0
			var n := 0
			var cross := 0
			var secs := 0.0
			for st in bank:
				var data: PackedByteArray = (st as AudioStreamWAV).data
				var prev := 0.0
				for i in range(0, data.size() - 1, 2):
					var v := float(data.decode_s16(i)) / 32768.0
					peak = maxf(peak, absf(v))
					sq += v * v
					n += 1
					if prev <= 0.0 and v > 0.0:
						cross += 1
					prev = v
				secs += float(data.size() / 2.0) / float(Sfx.RATE)
			print("GLOS %-14s sylab %d  szczyt %.2f  rms %.3f  przejść przez zero %d/s  długość sylaby %.0f ms" % [vn, bank.size(), peak, sqrt(sq / maxf(1.0, n)), int(cross / maxf(0.01, secs)), secs / bank.size() * 1000.0])
		get_tree().quit()
		return
	if args.has("probe"):
		# wysokość terenu w punktach planu: --probe="x,z;x,z;…"
		for pt in String(args.probe).split(";", false):
			var xz := pt.split(",")
			print("HD %s = %.2f" % [pt, world.hd(float(xz[0]), float(xz[1]))])
		get_tree().quit()
		return
	if args.has("uiaudit"):
		# przegląd układu okna bez rysowania: --uiaudit=nazwa (te same nazwy co --ui=)
		_ui_audit(String(args.uiaudit))
		return
	if args.has("glb") and args.has("room"):
		# wnętrze do pliku GLB: --glb=ścieżka --room=safe [--paczka=k,k2] — z --paczka wypisuje też kadr scenki pod drzwiami
		if args.has("paczka"):
			var pk := String(args.paczka).split(",")
			G.S.flags["wiktor_sms"] = true
			G.S.flags.erase("got_first")
			world.refresh_starter()
			world.starter_rest(float(pk[0]), float(pk[1]) if pk.size() > 1 else -1.0)
			var dc := door_cam(float(args.get("kam", "1")))
			print("CAM %.3f %.3f %.3f %.3f %.3f %.3f %.1f" % [dc[0].x, dc[0].y, dc[0].z, dc[1].x, dc[1].y, dc[1].z, dc[2]])
		world.glb_people = args.has("ludzie")
		world.export_room_glb(String(args.glb), String(args.room))
		get_tree().quit()
		return
	if args.has("glb"):
		# wycinek świata do pliku GLB: --glb=ścieżka --at=x,z [--r=promień]
		var at := String(args.get("at", "0,0")).split(",")
		world.args_debug = args.has("dbg")
		world.glb_train_x = float(args.get("pociag", "-9999"))
		world.glb_people = args.has("ludzie")
		world.glb_anim = String(args.get("anim", ""))
		world.export_glb(String(args.glb), float(at[0]), float(at[1]), float(args.get("r", "70")))
		get_tree().quit()
		return
	if args.has("przeglad"):
		world.okolica = String(args.get("okolica", ""))
		world.audit()
		get_tree().quit()
		return
	if args.has("plan"):
		# plan miasta z góry do pliku (bez okna): --plan=ścieżka [--box=x0,z0,x1,z1]
		var pb: Array = []
		for v in String(args.get("box", "")).split(",", false):
			pb.append(float(v))
		world.dump_plan(String(args.plan), pb if pb.size() == 4 else [])
		get_tree().quit()
		return
	if args.has("test"):
		var t: Node = load("res://scripts/selftest.gd").new()
		t.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(t)


# ================================================================ start / menu / koniec
func to_title() -> void:
	if G.prologue != null:
		G.prologue.stage = "done"
		G.prologue.queue_free()
		G.prologue = null
		cut_hour = -1.0
		cine_off()
		ui.cut_end()
		ui.fade_rect.color.a = 0.0
		world.set_mill_burnt(true)
		for c in npcs.cops:
			c.idle = 0.0
			c.beat = null
	build_cancel()
	G.running = false
	G.busy = false
	G.arresting = false
	G.S.wanted = false
	Sfx.siren(false)
	npcs.clear_customers()
	ui.close_all()
	player.loc = "out"
	player.flash.light_energy = 0.0
	player.place(TITLE_POS, TITLE_YAW)
	_show_loc("out")
	nav.clear_path()
	beacon.visible = false
	ui.set_prompt("")
	ui.show_title()


## światła punktowe gasną z odległością, a cienie rzucają tylko te najbliższe
func _light_ranges(n: Node) -> void:
	if n is OmniLight3D or n is SpotLight3D:
		var l: Light3D = n
		l.distance_fade_enabled = true
		l.distance_fade_begin = 46.0
		l.distance_fade_length = 12.0
		l.distance_fade_shadow = 24.0
	for c in n.get_children():
		_light_ranges(c)


# ================================================================ ustawienia (osobny plik, niezależny od zapisu gry)
const SETTINGS_PATH := "user://ustawienia.json"
var settings := {"quality": "med", "fullscreen": true, "muted": false,
	"res_scale": 1.0, "dyn_res": true, "shadows": "", "fog": true, "ssao": true, "vsync": true, "fps_cap": 0, "fov": 70.0, "bright": 1.0,
	"vol_master": 0.8, "vol_music": 0.8, "vol_sfx": 1.0, "vol_ambient": 0.9, "vol_voice": 0.9,
	"sens": 1.0, "invert_y": false, "keys": {}, "minimap": false}


func load_settings() -> void:
	if G.test_mode:
		return
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(d) == TYPE_DICTIONARY:
				for k in d:
					settings[k] = d[k]
	else:
		# pierwsze uruchomienie: poziom jakości dobrany do sprzętu. Gra celuje w komputery z osobną kartą graficzną;
		# na układach zintegrowanych i przy małej pamięci startuje na „Niskiej”.
		var gpu := RenderingServer.get_video_adapter_name().to_lower()
		var ram_gb := float(OS.get_memory_info().get("physical", 0)) / 1073741824.0
		var dedicated := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
		if dedicated and ram_gb >= 15.0:
			settings.quality = "ultra" if (gpu.contains("rtx") or gpu.contains("rx 6") or gpu.contains("rx 7") or gpu.contains("rx 9") or gpu.contains("arc")) else "high"
		elif ram_gb >= 15.0:
			settings.quality = "med"
		else:
			settings.quality = "low"
	if not args.has("window"):
		set_fullscreen(bool(settings.fullscreen), false)
	if bool(settings.muted):
		Sfx.set_muted(true)


## przenosi ustawienia do gry: obraz, dźwięk, mysz i klawisze (wołane po starcie i po każdej zmianie w Opcjach)
func apply_settings() -> void:
	var ks := G.KEY_DEFAULTS.duplicate()
	if typeof(settings.keys) == TYPE_DICTIONARY:
		for a in settings.keys:
			if ks.has(a):
				ks[a] = int(settings.keys[a])
	G.keys = ks
	if env != null:
		env.res_mult = clampf(float(settings.res_scale), 0.5, 1.0)
		env.dyn_on = bool(settings.dyn_res)
		if not env.dyn_on:
			env.dyn = 1.0
		env.bright = clampf(float(settings.bright), 0.6, 1.6)
		env.opt_shadows = String(settings.shadows)
		env.opt_fog = bool(settings.fog)
		env.opt_ssao = bool(settings.ssao)
		env.set_quality(String(settings.quality))
	if player != null:
		player.base_fov = clampf(float(settings.fov), 55.0, 100.0)
		player.look_scale = clampf(float(settings.sens), 0.2, 3.0)
		player.invert_y = bool(settings.invert_y)
	if not G.test_mode:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.vsync) else DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = int(settings.fps_cap)
		for g in ["master", "music", "sfx", "ambient", "voice"]:
			Sfx.set_volume(g, float(settings["vol_" + g]))
		Sfx.set_muted(bool(settings.muted) or args.has("mute"))


func save_settings() -> void:
	if G.test_mode:
		return
	settings.quality = env.quality
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(settings))
		f.close()


func is_fullscreen() -> bool:
	return get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(on: bool, store := true) -> void:
	var w := get_window()
	if on:
		w.mode = Window.MODE_FULLSCREEN
	else:
		w.mode = Window.MODE_WINDOWED
		# okno na ok. 80% ekranu, wyśrodkowane
		var scr := DisplayServer.screen_get_usable_rect(w.current_screen)
		var hgt := int(scr.size.y * 0.8)
		var sz := Vector2i(int(hgt * 16.0 / 9.0), hgt)
		if sz.x > scr.size.x * 0.95:
			sz = Vector2i(int(scr.size.x * 0.9), int(scr.size.x * 0.9 * 9.0 / 16.0))
		w.size = sz
		w.position = scr.position + (scr.size - sz) / 2
	settings.fullscreen = on
	if store:
		save_settings()


func to_menu() -> void:
	to_title()


func start_game(from_save: bool) -> void:
	cine_off()
	var loaded := from_save and G.load_game()
	if not loaded:
		G.S = G.new_state()
	G.running = true
	G.busy = false
	G.arresting = false
	G.wanted_grace = 0.0
	G.now = 0.0
	Sfx.siren(false)
	npcs.clear_customers()
	for o in G.S.orders:
		if o.status == "accepted":
			npcs.spawn_customer(o)
	ui.close_all()
	ui.hud.visible = true
	ui.nav_info = {}
	ui.last_zone = ""
	for room in ["garage", "basement"]:
		world.refresh_furniture(room)
	# rzeczy na ziemi: nowa gra zaczyna z porannymi znaleziskami, wczytana odtwarza zapisane
	if not loaded and G.S.get("ground", []).is_empty():
		G.loot_spawn()
	world.refresh_ground()
	world.refresh_drops()
	world.refresh_starter()
	var R: Dictionary = D.ROOMS.safe
	if loaded and G.S.pos != null:
		teleport(String(G.S.pos.loc), Vector3(float(G.S.pos.x), 0.0, float(G.S.pos.z)), float(G.S.pos.yaw))
	else:
		teleport("safe", Vector3(float(R.cx) - 0.6, 0.0, 1.2), 0.0)
		if not args.has("autostart") or args.has("intro"):
			start_prologue()
		else:
			G.S.flags["prologue_done"] = true
			_intro_sms()
	nav_force = true


# ================================================================ wstęp fabularny
## Nowa gra zaczyna się grywalnym prologiem (scripts/prologue.gd): nalot na laboratorium w Starej Hucie.
func start_prologue() -> void:
	var pr: Node = load("res://scripts/prologue.gd").new()
	add_child(pr)
	pr.start()


## zdarzenia z interakcji w laboratorium (np. spakowanie torby)
func prologue_act(what: String) -> void:
	if G.prologue != null:
		G.prologue.act(what)


## Pierwszy telefon od Wiktora zastaje Kubę w łóżku: przez całą rozmowę leży (kamera patrzy w sufit, lekko „oddycha”),
## dopiero po rozłączeniu siada i wstaje. Do tego czasu nie da się chodzić.
## Przebudzenie w kawalerce: Kuba leży na boku (widać pokój, nie sufit), zaczyna wibrować telefon,
## półprzytomne „kto do mnie dzwoni?”, kilka mrugnięć — i dopiero wtedy pojawia się karta połączenia.
## Po rozmowie siada na brzegu łóżka i wstaje.
func _bed_call() -> void:
	if G.test_mode or player.loc != "safe":
		_intro_call()
		return
	var R: Dictionary = D.ROOMS.safe
	var bx: float = float(R.cx) - float(R.w) * 0.5 + 0.62
	var bz: float = -float(R.d) * 0.5 + 1.1
	G.busy = true
	ui.cut_begin()
	ui.set_lids(1.0)
	var t := 0.0
	var rang := false
	var said := false
	while t < BED_WAKE:
		t += get_process_delta_time()
		# spacja przewija przebudzenie (napis „Spacja — pomiń” jest na ekranie)
		if t > 0.4 and Input.is_key_pressed(KEY_SPACE):
			break
		bed_cam(t)
		ui.set_lids(bed_lids(t))
		if not rang and t > 0.7:
			rang = true
			Sfx.ring(true)
		if not said and t > 2.7:
			said = true
			ui.cut_line("…Kto do mnie dzwoni?")
			ui._mumble_burst("Ty", 3)
		await get_tree().process_frame
	ui.set_lids(0.0)
	ui.cut_line("")
	ui.cut_end()
	if not rang:
		Sfx.ring(true)
	# oczy otwarte: teraz dopiero widać, kto dzwoni i czym odebrać (karta celu podpowiada klawisz)
	_intro_call(false)
	await get_tree().process_frame
	while ui.call_active():
		t += get_process_delta_time()
		bed_cam(t)
		await get_tree().process_frame
	# koniec rozmowy: siada na brzegu łóżka, chwilę patrzy pod nogi i wstaje
	var tw := create_tween()
	tw.tween_method(bed_rise, 0.0, 1.0, 2.8)
	await tw.finished
	var stand := Vector3(bx + 0.95, 1.6, bz + 0.25)
	teleport("safe", Vector3(stand.x, 0.0, stand.z), -PI / 2.0)
	cine_off()
	G.busy = false
	# SMS od mamy i plansza ze sterowaniem dopiero teraz — wcześniej zasłaniałyby wstawanie
	_intro_sms()


const BED_WAKE := 5.4
## „góra” kamery, gdy głowa leży na poduszce na boku: prawie poziomo (czubek głowy w stronę ściany)
const BED_UP := Vector3(0.0, 0.6, -1.0)
## powieki przy przebudzeniu: [sekunda, zamknięcie 0–1] — pierwsze ospałe uchylenie, potem trzy mrugnięcia
const BED_LIDS := [[0.0, 1.0], [1.7, 1.0], [2.35, 0.52], [2.65, 0.55], [2.9, 1.0], [3.15, 1.0], [3.65, 0.22], [3.95, 0.2], [4.05, 1.0], [4.17, 0.1],
	[4.6, 0.07], [4.7, 1.0], [4.82, 0.03], [5.2, 0.0], [5.4, 0.0]]


## na ile zamknięte są powieki w sekundzie `t` przebudzenia (1 = ciemno, 0 = oczy otwarte)
func bed_lids(t: float) -> float:
	if t >= float(BED_LIDS[BED_LIDS.size() - 1][0]):
		return 0.0
	for i in range(BED_LIDS.size() - 1):
		var a: Array = BED_LIDS[i]
		var b: Array = BED_LIDS[i + 1]
		if t >= float(a[0]) and t < float(b[0]):
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, (t - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))))
	return 1.0


## kadr wstawania z łóżka: k = 0 leży na boku, ok. 0,45 siedzi na brzegu (patrzy pod nogi), 1 stoi przy łóżku
func bed_rise(k: float) -> void:
	var R: Dictionary = D.ROOMS.safe
	var bx: float = float(R.cx) - float(R.w) * 0.5 + 0.62
	var bz: float = -float(R.d) * 0.5 + 1.1
	var head := bed_head()
	var sit := Vector3(bx + 0.55, 1.05, bz + 0.1)
	var stand := Vector3(bx + 0.95, 1.6, bz + 0.25)
	# trzy fazy: podniesienie się do siadu, krótkie przysiedzenie, wstanie (z lekkim pochyleniem do przodu)
	var up_k := smoothstep(0.0, 0.42, k)
	var stand_k := smoothstep(0.58, 1.0, k)
	var pos := head.lerp(sit, up_k).lerp(stand, stand_k)
	pos.y -= sin(stand_k * PI) * 0.07
	pos.x += sin(stand_k * PI) * 0.1
	# wzrok: z kadru „na boku” na pokój przed sobą; w siadzie na chwilę opada na podłogę
	var nod := sin(clampf((k - 0.3) / 0.42, 0.0, 1.0) * PI) * 0.42
	var look := (head + BED_LOOK).lerp(pos + Vector3(1.0, -0.12 - nod, 0.0), smoothstep(0.0, 0.5, k))
	cine_cam(pos, look, 64.0)
	cine.look_at(look, BED_UP.normalized().slerp(Vector3.UP, smoothstep(0.0, 0.36, k)))


## gdzie leży głowa Kuby na łóżku w kawalerce
func bed_head() -> Vector3:
	var R: Dictionary = D.ROOMS.safe
	return Vector3(float(R.cx) - float(R.w) * 0.5 + 0.62, 0.72, -float(R.d) * 0.5 + 1.1 - 0.72)


## dokąd patrzy, leżąc na boku: przez pokój, w stronę biurka i drzwi
const BED_LOOK := Vector3(1.0, 0.1, 0.55)


## kadr „leżę na boku”: głowa na poduszce, obraz przechylony, lekki oddech i błądzenie oczu
func bed_cam(t: float) -> void:
	var head := bed_head() + Vector3(0, 0.03 + sin(t * 1.5) * 0.008, 0)
	var look := bed_head() + BED_LOOK + Vector3(0.0, sin(t * 0.31) * 0.02, cos(t * 0.23) * 0.04)
	cine_cam(head, look, 64.0)
	cine.look_at(look, BED_UP.normalized())


func _intro() -> void:
	_bed_call()


## pierwsza rozmowa z Wiktorem (po przebudzeniu); `then_sms` = false, gdy SMS i sterowanie przyjdą dopiero po wstaniu
func _intro_call(then_sms := true) -> void:
	ui.call_start("Nieznany numer", [
		"Kuba. Żyjesz. To dobrze. Tu Wiktor.",
		"Wiem, co się stało w hucie i za garażami. Ktoś nas sprzedał — i to nie byłeś ty. Partia przepadła, trudno. Żalu do ciebie nie mam.",
		{"n": "Ty", "t": "Nie mam laboratorium, nie mam ludzi, nie mam nic, Wiktor. Siwy siedzi."},
		"Masz głowę i nie sypnąłeś. Takich ludzi mi trzeba. Biorę cię do siebie — zaczynasz od dołu, jako chłopak od wszystkiego. Dostajesz Hutniczą i osiedle.",
		"Pierwszą paczkę masz ode mnie za darmo, na rozruch. Następne idą na zeszyt. Co zarobisz ponad towar, odnoś do skrzynki — to twój wkład. Im większy, tym wyżej u mnie stoisz: plecak, większy zeszyt, tańszy hurt, garaż. A jak dobijesz do dwudziestu pięciu tysięcy, robimy to razem, jako wspólnicy.",
		"Zaraz wyślę ci SMS-em, co dalej. I Kuba — tego, kto nas sprzedał, znajdziemy. Powoli.",
	], _intro_sms if then_sms else Callable(), "Wiktor")


func _intro_sms() -> void:
	G.chat("mama", "Kubuś, gdzie ty się podziewasz? W telewizji mówili o wybuchu w starej hucie. Zadzwoń do matki.", false, true)
	# sterowanie pokazuje się raz, gdy gracz pierwszy raz dostaje otwarty świat
	if not G.flag("seen_keys") and not G.test_mode:
		ui.show_controls()


## zapis gry przy laptopie w kryjówce — jedyny sposób zapisu
func save_here() -> void:
	if G.S.wanted or npcs.any_chase():
		G.notify("Nie teraz — policja depcze Ci po piętach.", "warn")
		return
	G.save_game(true)
	Sfx.play("good")


func ending(kind: String) -> void:
	if not G.running:
		return
	build_cancel()
	G.running = false
	G.busy = false
	Sfx.siren(false)
	if not G.test_mode and kind != "wolnosc":
		G.delete_save()
	var S: Dictionary = G.S
	var stats := "Dni: [b]%d[/b] • Poziom: [b]%d[/b] • Zarobiono: [b]%s[/b] • Sprzedano: [b]%d g[/b] • Zatrzymania: [b]%d[/b] • Ucieczki: [b]%d[/b]" % [G.day(), int(S.lvl), G.money(S.stats.earned), int(S.stats.sold), int(S.arrests), int(S.stats.escapes)]
	ui.set_prompt("")
	match kind:
		"wolnosc":
			ui.show_ending("WSPÓLNIK", "Dwadzieścia pięć tysięcy wkładu. Wiktor przysłał jedno słowo: „Wspólnik”. Zaczynałeś jako chłopak od wszystkiego — teraz dzielnica jest tak samo Twoja, jak jego. W skrzynce zamiast pieniędzy leżała koperta. W środku jedno nazwisko. Znasz je. Co z tym zrobisz?", stats, true)
		"wyrok":
			ui.show_ending("WYROK", "Piąte zatrzymanie. Tym razem prokurator nie miał litości — a Wiktor znalazł sobie nowego chłopaka od wszystkiego.", stats)
		_:
			ui.show_ending("KONIEC", "Tym razem się nie udało. Dzielnica ma już nowego chłopaka od wszystkiego.", stats)


func resume_free() -> void:
	G.running = true
	ui.close_all()
	ui.hud.visible = true
	G.notify("Jesteś wspólnikiem. Gra toczy się dalej — na Twoich warunkach.", "level")


# ================================================================ lokacje
func _show_loc(loc: String) -> void:
	var room_nodes: Array = world.rooms.values()
	for c in world.get_children():
		if not (c is Node3D):
			continue
		if room_nodes.has(c):
			c.visible = world.rooms.get(loc) == c
		else:
			c.visible = loc == "out"
	# radio gra tylko wtedy, gdy jesteś w mieszkaniu
	if world.radio_player != null:
		if loc == "safe":
			radio_apply()
		else:
			world.radio_player.stop()


func teleport(loc: String, pos: Vector3, yaw: float) -> void:
	build_cancel()
	player.loc = loc
	_show_loc(loc)
	player.place(pos, yaw)
	nav_force = true


func enter(id: String) -> void:
	if G.busy:
		return
	var dd: Dictionary = D.DOORS[id]
	if dd.get("sealed", false):
		G.notify("Drzwi zaspawane i oklejone policyjną taśmą. Tam nie ma już czego szukać.", "warn")
		return
	if dd.has("prop") and not G.owns(dd.prop):
		ui.open_property(dd.prop)
		return
	if dd.has("locked"):
		G.notify(String(dd.locked), "warn")
		return
	var pp: Vector3 = player.global_position
	if G.S.wanted:
		for c in npcs.cops:
			if c.state == "chase" and c.sees and Vector2(c.x - pp.x, c.z - pp.z).length() < 12.0:
				G.notify("Policja jest za blisko — nie zdążysz się schować!", "bad")
				return
		G.add_invest(5.0 if id == "safe" else 2.0)
	G.busy = true
	Sfx.play("door")
	await ui.fade(true)
	var R: Dictionary = D.ROOMS[id]
	teleport(id, Vector3(float(R.cx), 0.0, float(R.d) * 0.5 - 1.5), 0.0)
	await ui.fade(false)
	G.busy = false


func exit_room() -> void:
	if G.busy or player.loc == "out":
		return
	var id: String = player.loc
	var dd: Dictionary = D.DOORS[id]
	if G.prologue != null and not G.prologue.can_exit():
		G.notify("Najpierw spakuj partię — torba leży przy stole.", "warn")
		return
	var why_not: String = G.exit_block(id)
	if why_not != "":
		G.notify(why_not, "warn")
		Sfx.play("error")
		return
	G.busy = true
	Sfx.play("door_close")
	await ui.fade(true)
	var out_pos := Vector3(dd.x, 0.0, float(dd.z) + float(dd.dz) * 1.2)
	if dd.get("custom", false):
		out_pos = Vector3(dd.x, 0.0, dd.z)
	teleport("out", out_pos, deg_to_rad(float(dd.yaw_out)) if dd.has("yaw_out") else (PI if float(dd.dz) > 0.0 else 0.0))
	if G.prologue != null:
		player.yaw = PI / 2.0
		G.prologue.on_outside()
	await ui.fade(false)
	G.busy = false
	# pierwsze wyjście w miasto: bohater staje, kamera pokazuje miejsca, które już teraz się liczą
	if id == "safe" and G.prologue == null and G.flag("got_first") and not G.flag("tour_out") and not G.test_mode:
		city_tour()


## Miejsca pokazywane przy pierwszym wyjściu z bloku: [{title, sub, text, at, from, to}] w metrach świata.
## Kamera zaczyna dalej i wyżej, a kończy bliżej wejścia — spokojny najazd z lekkim łukiem.
## ile przeszkód (budynki, pnie, słupy, korony drzew) zasłania widok z punktu `cam` na miejsce `at`
func _view_hits(cam: Vector3, at: Vector3, near: Array, crowns: Array) -> int:
	if world.in_building(cam.x / D.SC, cam.z / D.SC, 0.6):
		return 9
	var tgt := at + Vector3(0, 1.5, 0)
	var flat := Vector2(tgt.x - cam.x, tgt.z - cam.z)
	var ln := maxf(flat.length(), 0.01)
	# sam cel (ściana z drzwiami, skrzynka) zasłoną nie jest: promień kończy się półtora metra przed nim
	var k_end := clampf(1.0 - 1.6 / ln, 0.1, 1.0)
	var ex := cam.x + flat.x * k_end
	var ez := cam.z + flat.y * k_end
	var hits := 0
	for b in near:
		if not world._seg_box(cam.x, cam.z, ex, ez, float(b.x0), float(b.x1), float(b.z0), float(b.z1)):
			continue
		var cx := (float(b.x0) + float(b.x1)) * 0.5
		var cz := (float(b.z0) + float(b.z1)) * 0.5
		var t := clampf(Vector2(cx - cam.x, cz - cam.z).dot(flat) / (ln * ln), 0.0, 1.0)
		if lerpf(cam.y, tgt.y, t) < world.height(cx, cz) + float(b.h) + 0.2:
			hits += 1
	for c in crowns:
		var v := Vector2(float(c.x) - cam.x, float(c.y) - cam.z)
		var t2 := clampf(v.dot(flat) / (ln * ln), 0.0, k_end)
		var y := lerpf(cam.y, tgt.y, t2)
		var g = world.height(float(c.x), float(c.y))
		if (v - flat * t2).length() < 2.1 and y > g + 2.3 and y < g + 9.0:
			hits += 1
	return hits


## Ujęcie na miejsce `at`: kamera zaczyna dalej i wyżej, kończy bliżej. `n` to kierunek „sprzed" miejsca,
## `turn` — o ile stopni wolno go obrócić w poszukiwaniu kąta, którego nic nie zasłania, `k` — skala odległości.
## Każde miejsce pokazu ma inny ruch kamery: [odległość, przesunięcie w bok, wysokość] na początku i na końcu.
## 0 najazd z prawej z góry, 1 niski kadr z lewej z odjazdem w górę, 2 zjazd żurawiem z wysoka,
## 3 przejazd bokiem wzdłuż ściany, 4 szeroki plan z daleka do zbliżenia
const TOUR_STYLES := [
	[10.0, 4.0, 4.6, 5.5, -1.5, 2.3],
	[5.2, -3.6, 1.2, 8.6, -0.8, 3.3],
	[6.5, 1.2, 6.4, 3.4, -0.6, 1.7],
	[7.4, -5.5, 2.3, 7.0, 4.2, 2.0],
	[14.0, -3.0, 7.0, 6.0, 1.6, 2.4],
]

func _tour_view(at: Vector3, n: Vector3, turn: float, k: float, style := 0) -> Dictionary:
	var ts: Array = TOUR_STYLES[posmod(style, TOUR_STYLES.size())]
	var near := []
	for b in world.blocks:
		if float(b.h) >= 1.0 and float(b.x1) > at.x - 18.0 and float(b.x0) < at.x + 18.0 and float(b.z1) > at.z - 18.0 and float(b.z0) < at.z + 18.0:
			near.append(b)
	var crowns := []
	for tp in world.tree_pos:
		var w := Vector2(float(tp.x) * D.SC, float(tp.y) * D.SC)
		if absf(w.x - at.x) < 18.0 and absf(w.y - at.z) < 18.0:
			crowns.append(w)
	var best := {}
	var best_score := 999.0
	for deg in [0.0, 18.0, -18.0, 36.0, -36.0, 54.0, -54.0, 80.0, -80.0, 110.0, -110.0, 145.0, -145.0, 180.0]:
		if absf(deg) > turn + 0.1:
			continue
		var d := n.rotated(Vector3.UP, deg_to_rad(deg))
		var r := Vector3(d.z, 0.0, -d.x)
		var from := at + d * float(ts[0]) * k + r * float(ts[1]) * k + Vector3(0, maxf(1.1, float(ts[2]) * (0.5 + 0.5 * k)), 0)
		var to := at + d * float(ts[3]) * k + r * float(ts[4]) * k + Vector3(0, maxf(1.1, float(ts[5]) * (0.5 + 0.5 * k)), 0)
		var score := float(_view_hits(from, at, near, crowns) + _view_hits(to, at, near, crowns) + _view_hits(from.lerp(to, 0.5), at, near, crowns)) + absf(deg) * 0.004
		if score < best_score:
			best_score = score
			best = {"from": from, "to": to}
		if score < 0.9:
			break
	var from: Vector3 = best.from
	var to: Vector3 = best.to
	# kamera nie może wejść w ścianę po drugiej stronie ulicy: w razie czego przysuwa się do celu
	for i in range(8):
		if world.in_building(from.x / D.SC, from.z / D.SC, 0.6):
			var fy := from.y
			from = at + (from - at) * 0.85
			from.y = fy
		if world.in_building(to.x / D.SC, to.z / D.SC, 0.6):
			var ty := to.y
			to = at + (to - at) * 0.85
			to.y = ty
	return {"from": from, "to": to, "clear": best_score < 0.9}


func tour_shots() -> Array:
	var out := []
	var add := func(title: String, sub: String, text: String, x: float, z: float, nx: float, nz: float, turn: float, k: float, cards: Array) -> void:
		var at := Vector3(x, world.height(x, z), z)
		var v := _tour_view(at, Vector3(nx, 0.0, nz).normalized(), turn, k, out.size())
		out.append({"title": title, "sub": sub, "text": text, "at": at, "from": v.from, "to": v.to, "clear": v.clear, "cards": cards})
	var sh: Dictionary = D.DOORS.shop
	add.call("SKLEP U STASIA", "woreczki • dodatki do mieszanek", "Wujek Staś. Tu kupisz woreczki, kiedy się skończą, a także majeranek i cukier puder, jeśli zechcesz robić mieszanki. Później — doniczki, nasiona i nawóz.", float(sh.x), float(sh.z), 0.0, float(sh.dz), 54.0, 1.0, [
		{"icon": "woreczki", "name": "Woreczki strunowe", "sub": "%d szt. za %d zł" % [int(D.SHOP[0].n), int(D.SHOP[0].price)]},
		{"icon": "majeranek", "name": "Majeranek", "sub": "domieszka do marihuany"},
		{"icon": "cukier", "name": "Cukier puder", "sub": "domieszka do proszków"},
		{"icon": "doniczka", "name": "Doniczki i nasiona", "sub": "własna uprawa — później"}])
	var cl: Dictionary = D.DOORS.ciuchy
	add.call("TANIA ODZIEŻ", "ubranie zmienia statystyki", "Każda rzecz coś daje: jedne przyspieszają bieg, inne dodają kieszeni albo mniej rzucają się w oczy patrolom. W kominiarce nikt Cię nie opisze — ale policja zauważy od razu.", float(cl.x), float(cl.z), 0.0, float(cl.dz), 54.0, 1.0, [
		{"icon": "ub_buty_bieg", "name": "Buty do biegania", "sub": "szybszy bieg, więcej tchu"},
		{"icon": "ub_bojowki", "name": "Bojówki", "sub": "trzy miejsca więcej w kieszeniach"},
		{"icon": "ub_czapka_daszek", "name": "Czapka z daszkiem", "sub": "trudniej Cię opisać"},
		{"icon": "ub_kominiarka", "name": "Kominiarka", "sub": "nikt Cię nie rozpozna — patrol tak"}])
	add.call("SKRZYNKA WIKTORA", "zeszyt • wkład • awanse", "Stara skrzynka gazowa na tyłach pawilonu. Tu zanosisz pieniądze: najpierw schodzi zeszyt za towar, reszta to Twój wkład — a z wkładu biorą się awanse u Wiktora.", float(D.WIKTOR_BOX.x), float(D.WIKTOR_BOX.z), 0.0, -1.0, 180.0, 1.0, [
		{"icon": "notes", "name": "Zeszyt", "sub": "najpierw spłata za wzięty towar"},
		{"icon": "cash", "name": "Wkład", "sub": "reszta zostaje na Twoim koncie"},
		{"icon": "award", "name": "Awans", "sub": "%s od %d zł wkładu" % [String(D.RANKS[1].name), int(D.RANKS[1].at)]}])
	add.call("LOMBARD", "skup znalezisk • lepsze wagi", "Zenek skupuje to, co znajdziesz w śmietnikach, i sprzedaje dokładniejsze wagi: pakujesz na nich szybciej i nic się nie rozsypuje.", float(D.PAWN_AT.x), float(D.PAWN_AT.z), 0.0, 1.0, 54.0, 1.0, [
		{"icon": "scale", "name": String(D.SCALES[1].name), "sub": "%d zł • od poziomu %d" % [int(D.SCALES[1].price), int(D.SCALES[1].lvl)]},
		{"icon": "coins", "name": "Skup znalezisk", "sub": "Zenek płaci gotówką od ręki"},
		{"icon": "clock", "name": "Otwarte %d:00–%d:00" % [int(D.PAWN_OPEN[0]), int(D.PAWN_OPEN[1])], "sub": "w nocy zamknięte na kratę"}])
	var o = G.next_meeting()
	if o != null:
		var t := _order_target(o)
		var d := Vector2(player.global_position.x - float(t.x), player.global_position.z - float(t.z))
		if d.length() < 1.0:
			d = Vector2(0, 1)
		d = d.normalized()
		add.call("MIEJSCE SPOTKANIA", String(G.spot_def(o.spot).name), "Tu będzie czekał %s. Klient zjawia się godzinę po potwierdzeniu i poczeka kilka godzin — ale kto zdąży w godzinę, zastaje go w dobrym humorze." % String(G.cust_def(o.cust).name), float(t.x), float(t.z), d.x, d.y, 180.0, 0.8, [
		{"icon": "clock", "name": "Spotkanie o %s" % G.clock(o.meet), "sub": "klient poczeka do %s" % G.clock(o.deadline)},
		{"icon": "smile", "name": "Zdążysz w godzinę?", "sub": "klient jest w dobrym humorze"},
		{"icon": "navigation", "name": "[%s] trasa do celu" % G.kn("nav"), "sub": "strzałki poprowadzą Cię na miejsce"}])
	return out


## strzałka nad pokazywanym miejscem: świecący stożek, który lekko się kołysze
func _tour_marker(at: Vector3) -> Node3D:
	var g := Node3D.new()
	add_child(g)
	g.global_position = at + Vector3(0, 4.4, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.82, 0.3)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.34
	cone.bottom_radius = 0.0
	cone.height = 0.7
	cone.radial_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	var li := OmniLight3D.new()
	li.light_color = Color(1.0, 0.82, 0.4)
	li.light_energy = 1.6
	li.omni_range = 7.0
	li.position = Vector3(0, -1.2, 0)
	g.add_child(li)
	return g


## Pierwsze wyjście z bloku: bohater zatrzymuje się, a kamera odwiedza po kolei najważniejsze miejsca i je opisuje.
## Spacja przewija do następnego miejsca, przytrzymana — kończy pokaz. Potem miasto jest otwarte.
func city_tour() -> void:
	if G.flag("tour_out") or G.prologue != null:
		return
	G.S.flags["tour_out"] = true
	G.busy = true
	ui.close_all()
	ui.cut_begin()
	var shots := tour_shots()
	# zrzuty ekranu: --tourshot=N zaczyna pokaz od N-tego miejsca
	if args.has("tourshot"):
		shots = shots.slice(clampi(int(args.tourshot), 0, shots.size() - 1))
	var held := 0.0
	var quit := false
	for sh in shots:
		if quit:
			break
		ui.cut_title(String(sh.title), String(sh.sub))
		ui.cut_line(String(sh.text))
		var mark := _tour_marker(sh.at)
		var t := 0.0
		var dur := 8.5
		var was_down := true
		var title_on := true
		while t < dur:
			var dt := get_process_delta_time()
			t += dt
			# tytuł miejsca tylko na początku ujęcia — potem ma być widać samo miejsce i opis na dole
			if title_on and t > 2.3:
				title_on = false
				ui.cut_title("")
				ui.cut_cards(sh.cards)
			var e := smoothstep(0.0, 1.0, t / dur)
			cine_cam((sh.from as Vector3).lerp(sh.to, e), (sh.at as Vector3) + Vector3(0, 1.5, 0), lerpf(60.0, 48.0, e))
			mark.position.y = float(sh.at.y) + 4.4 + sin(t * 3.2) * 0.22
			mark.rotation.y = t * 1.6
			var down := Input.is_key_pressed(KEY_SPACE)
			held = held + dt if down else 0.0
			if held > 1.0:
				quit = true
				break
			if down and not was_down and t > 0.5:
				break
			was_down = down
			await get_tree().process_frame
		mark.queue_free()
		ui.cut_title("")
		ui.cut_cards([])
	ui.cut_line("")
	await get_tree().create_timer(0.35).timeout
	cine_off()
	ui.cut_end()
	G.busy = false
	G.notify("Miasto jest Twoje. [%s] włącza trasę do celu, [%s] otwiera mapę." % [G.kn("nav"), G.kn("map")], "good")
	nav_force = true


# ================================================================ klub, szpital, komenda
## kontrola przy wejściu do klubu Neon: ochroniarz nie wpuści nikogo, przy kim coś znajdzie
func club_door() -> void:
	if G.busy or ui.mode != "":
		return
	if not G.club_open():
		G.notify("Klub Neon wpuszcza od %d:00 do %d:00." % [int(D.CLUB_OPEN), int(D.CLUB_CLOSE)], "warn")
		return
	if G.S.wanted:
		G.notify("Z policją na karku nikt Cię tu nie wpuści.", "bad")
		return
	var ch := G.frisk_chance()
	var tries := G.club_tries()
	var line: String = ["Stop. Ręce na boki, kontrola.", "Znowu ty? Ręce na boki.", "Ostatni raz Cię sprawdzam. Ręce."][mini(tries, 2)]
	var risk := "nic przy sobie nie masz" if ch <= 0.0 else ("bramka zapiszczy na pewno" if ch >= 1.0 else "ryzyko wpadki ok. %d%%" % int(round(ch * 100.0)))
	ui.dialog({"name": "Ochroniarz", "lines": [line], "choices": [
		{"label": "Wchodzę (%s)" % risk, "kind": "warn" if ch > 0.0 else "", "act": club_try},
		{"label": "Jednak nie.", "act": func(): pass}]})


func club_try() -> void:
	var res: Dictionary = G.club_frisk()
	if res.ok:
		G.notify("Ochroniarz kiwa głową: wchodź.", "good")
		enter("club")
		return
	if res.why == "mask":
		ui.dialog({"name": "Ochroniarz", "lines": ["W kominiarce? Zdejmij to z gęby albo spadaj."]})
		return
	Sfx.play("alert")
	if res.beaten:
		ui.dialog({"name": "Ochroniarz", "lines": ["%s. Trzeci raz tej nocy." % String(res.found), "Mówiłem, że to ostatnie ostrzeżenie."], "on_end": func(): G.hospitalize("beaten")})
		return
	var said: String = ["A to co? %s. Z tym nie wejdziesz. Zostaw to gdzieś i wróć — albo nie wracaj.", "Znowu? %s. Jeszcze jeden numer i wyniosą Cię stąd na noszach."][mini(int(res.tries) - 1, 1)] % String(res.found)
	G.notify("Wpadka przy kontroli (%d/%d tej nocy)." % [int(res.tries), D.CLUB_TRIES], "bad")
	ui.dialog({"name": "Ochroniarz", "lines": [said]})


## cios albo strzał: obraz przechyla się i gaśnie
func blackout(reason: String) -> void:
	if reason == "shot":
		Sfx.gunshot()
	else:
		Sfx.knock()
	if not G.test_mode:
		player.shake = 1.0
		var tw := create_tween()
		tw.tween_property(player, "fall", 1.0, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await ui.fade(true)
	player.fall = 0.0


## pobudka w łóżku szpitalnym albo na pryczy w celi
func wake_in(room: String) -> void:
	ui.close_all()
	var wk: Array = world.wake.get(room, [Vector3(float(D.ROOMS[room].cx), 0.0, 0.0), 0.0])
	teleport(room, wk[0], float(wk[1]))
	player.pitch = 0.0


func hospital_talk(res: Dictionary) -> void:
	var lines := []
	if String(res.reason) == "shot":
		lines.append("Spokojnie, nie wstawaj tak szybko. Kula przeszła przez udo, miałeś szczęście.")
		lines.append("Policjant siedział tu przy łóżku całą noc. Wszystko, co miałeś w kieszeniach, zabrali na komendę: %s." % G.loot_text(res))
	else:
		lines.append("No, wróciłeś do nas. Ktoś Cię przywiózł spod Neonu i zostawił na izbie przyjęć.")
		lines.append("Wstrząśnienie mózgu, dwa żebra stłuczone. Pożyjesz.")
	if float(res.cash) > 0.0:
		lines.append("Aha — w kieszeniach miałeś tylko %s. Jak było więcej, to ktoś Ci pomógł, zanim trafiłeś na oddział." % G.money(G.S.cash))
	lines.append("Przez najbliższą dobę będziesz obolały: wolniej biegasz i szybciej łapiesz zadyszkę. Wyjście prosto korytarzem.")
	ui.dialog({"name": "Pielęgniarka", "lines": lines})
	if float(res.cash) > 0.0:
		G.notify("W szpitalu zniknęło Ci z kieszeni %s." % G.money(res.cash), "bad")
	if bool(res.big):
		G.notify("Policja znalazła przy Tobie dużą gotówkę — przez %d dni będą węszyć po kryjówkach." % int(D.WATCH_DAYS), "bad")


func release_talk(res: Dictionary) -> void:
	var lines := ["Wstawaj. Prokurator nie ma dziś na Ciebie czasu, więc wychodzisz."]
	if float(res.goods) > 0.0 or int(res.items) > 0:
		lines.append("To, co przy Tobie znaleźliśmy, zostaje w depozycie: %s. Na zawsze." % G.loot_text(res))
	if bool(res.weapon):
		lines.append("Za kastet masz osobny zarzut. Jeszcze o nim usłyszysz.")
	if bool(res.big):
		lines.append("I jeszcze jedno. Skąd bezrobotny ma w kieszeni tyle gotówki? Przyjrzymy się, gdzie mieszkasz i gdzie bywasz.")
	lines.append("Zatrzymanie numer %d. Przy piątym nikt Cię już nie wypuści." % int(G.S.arrests))
	ui.dialog({"name": "Dyżurny", "lines": lines})


## imprezowicz w klubie: bierze od ręki i płaci lepiej niż ulica — o ile przemyciłeś towar przez bramkę
func club_buyer(n: Dictionary) -> void:
	if G.busy or ui.mode != "":
		return
	var vip: bool = n.get("vip", false)
	if vip and int(G.S.lvl) < D.CLUB_VIP_LVL:
		ui.dialog({"name": n.name, "lines": [["Nie znam cię. A ja nie rozmawiam z ludźmi, których nie znam.", "Chłopcze, wróć, jak ktoś za ciebie poręczy.", "Ochrona? Ten pan się zgubił."].pick_random()]})
		G.notify("Goście loży VIP rozmawiają dopiero z kimś, o kim słyszeli (poziom %d)." % D.CLUB_VIP_LVL, "warn")
		return
	if vip and G.packed_total(G.S.inv, "snieg") <= 0:
		ui.dialog({"name": n.name, "lines": [["Biorę tylko śnieg. Czysty. Reszty nie tykam.", "Jak będziesz miał coś białego i porządnego — wiesz, gdzie siedzę.", "Trawę zostaw dzieciakom na parkiecie."].pick_random()]})
		return
	if G.packed_total(G.S.inv) <= 0:
		ui.dialog({"name": n.name, "lines": [["Masz coś? Nie? To nie zawracaj głowy, leci mój kawałek!", "Co?! Nie słyszę! Chodź tańczyć!", "Stary, jak nie masz nic na rozkręcenie, to stawiaj kolejkę."].pick_random()]})
		return
	if G.S.t - float(n.get("last_deal", -9999.0)) < 300.0:
		ui.dialog({"name": n.name, "lines": ["Mam jeszcze z tamtego. Wróć za parę godzin."]})
		return
	var prods := []
	for p in G.S.inv.pack:
		if G.packed_total(G.S.inv, p) > 0:
			prods.append(p)
	var prod: String = n.want if prods.has(n.want) else prods.pick_random()
	var who := {"name": n.name, "bio": "Imprezowicz z Neonu. Płaci za to, że nie musi wychodzić z klubu.", "wealth": float(n.wealth) * D.CLUB_PREMIUM, "patience": 3, "minpur": 50, "nerv": 0.05,
		"type": ["luzak", "impulsywny", "gadula"].pick_random(), "like": "luz", "hate": "", "reliable": 0.0, "st": {"loy": 10.0, "sat": 70.0, "hunger": 0.8}}
	var hello: String = ["Ej, ty jesteś ten od towaru? Dawaj, zanim ochrona spojrzy.", "No w końcu ktoś z czymś konkretnym. Ile za to chcesz?", "Słyszałam, że coś masz. Pokaż."].pick_random()
	var amount := randi_range(1, 3)
	if vip:
		# szychy z loży: tylko czysty śnieg, za to dużo i bez targowania się o grosze
		who.bio = "Gość loży VIP. Bierze tylko czysty śnieg, płaci jak za zboże i nie lubi czekać."
		who.minpur = 80
		who.patience = 2
		who.type = "konkret"
		who.like = "konkret"
		amount = randi_range(3, 6)
		hello = ["Podejdź bliżej. Podobno masz coś, co nie jest mąką.", "Siadać nie proponuję. Pokaż towar i mów cenę.", "Mam gości z Warszawy. Potrzebuję czegoś, czego nie będę się wstydził."].pick_random()
	var ctx := {"who": who, "product": prod, "grams": amount, "street": true, "npc": n, "on_done": func(r: Dictionary): _club_sold(n, r)}
	ui.dialog({"name": n.name, "lines": [hello], "on_end": func(): ui.open_deal(ctx)})


func _club_sold(n: Dictionary, res: Dictionary) -> void:
	if int(res.get("sold", 0)) > 0:
		n["last_deal"] = G.S.t


func club_bar() -> void:
	if G.busy or ui.mode != "":
		return
	var price := 25.0
	ui.dialog({"name": "Barman Igor", "lines": [["Co podać?", "Siema. To co zwykle?", "Mów głośniej, nic nie słyszę!"].pick_random()], "choices": [
		{"label": "Piwo (%s)" % G.money(price), "disabled": G.S.cash < price, "act": func(): _club_drink(price)},
		{"label": "Nic, dzięki.", "act": func(): pass}]})


func _club_drink(price: float) -> void:
	G.S.cash -= price
	G.add_minutes(20.0)
	Sfx.play("good")
	ui.dialog({"name": "Barman Igor", "lines": [[
		"Jak chcesz tu coś sprzedać, to nie przy barze. Ci na parkiecie biorą wszystko i nie pytają o cenę.",
		"Ochrona maca kieszenie, ale w kurtce z wewnętrznymi kieszeniami mało co znajdą. Tak tylko mówię.",
		"Trzy razy Cię złapią z towarem jednej nocy i wyjedziesz stąd karetką. Bogdan nie żartuje.",
		"W piątki i soboty schodzi tu wszystko. Szron i śnieg najlepiej.",
		"Jak masz przy sobie za dużo gotówki, a zgarną Cię psy, to zaczną grzebać głębiej. Trzymaj kasę w domu."].pick_random()]})


# ================================================================ śmietniki, lombard
## grzebanie w śmietniku: kwadrans roboty, raz na dobę; patrol, który to widzi, zapamięta Cię
func search_bin(id: String, source: String) -> void:
	if G.busy or ui.mode != "":
		return
	if G.bin_used(id):
		G.notify("Tu już dziś grzebałeś. Jutro ktoś znowu coś wyrzuci.", "warn")
		return
	G.busy = true
	Sfx.play("open")
	await ui.fade(true)
	var got: Array = G.bin_search(id, source)
	if npcs.watcher(18.0) != null:
		G.add_heat(2.0)
		G.notify("Patrol patrzył, jak grzebiesz w śmieciach.", "warn")
	await get_tree().create_timer(0.35).timeout
	await ui.fade(false)
	G.busy = false
	if got.is_empty():
		G.notify("Same śmieci. Nic, co dałoby się sprzedać.")
	else:
		Sfx.play("good")
		G.notify("Znalezione: %s. Lombard przy Hutniczej to kupi." % ", ".join(got), "good")


## hurtownia budowlana: sprzęt do produkcji i meble (kupione czekają na stanie, ustawia się je w kryjówce)
func supply_talk() -> void:
	if G.busy or ui.mode != "":
		return
	if not G.supply_open():
		G.notify("Hurtownia otwarta od %d:00 do %d:00." % [int(D.SUPPLY_OPEN[0]), int(D.SUPPLY_OPEN[1])], "warn")
		return
	if not G.flag("met_rysiek"):
		G.S.flags["met_rysiek"] = true
		ui.dialog({"name": "Pan Rysiek", "lines": [
			"Dzień dobry. Regały, stoły, lampy, a jak trzeba — to i szkło laboratoryjne się znajdzie. Do szkoły, ma się rozumieć.",
			"Pan płaci, ja ładuję na pakę i chłopaki dowożą pod adres. Potem pan sobie ustawia, jak panu wygodnie.",
		], "on_end": func(): ui.open_supply()})
		return
	ui.dialog({"name": "Pan Rysiek", "lines": [["Co dziś ładujemy?", "Mam świeżą dostawę regałów. Stal, nie żadna płyta.", "Lampy LED schodzą jak ciepłe bułki. Ciekawe, co ludzie tak hodują."].pick_random()], "choices": [
		{"label": "Pokaż cennik", "kind": "go", "act": func(): ui.open_supply()},
		{"label": "Na razie nic."},
	]})


func pawn_talk() -> void:
	if G.busy or ui.mode != "":
		return
	if not G.pawn_open():
		G.notify("Lombard otwarty od %d:00 do %d:00." % [int(D.PAWN_OPEN[0]), int(D.PAWN_OPEN[1])], "warn")
		return
	var list: Array = G.pawn_list()
	# wagi: Zenek trzyma je pod ladą — to jedyny sklep w mieście, który sprzedaje coś dokładniejszego niż kuchenna
	var scales := {"label": "Masz jakąś wagę?", "kind": "go", "act": func(): ui.open_scales()}
	if list.is_empty():
		ui.dialog({"name": "Pan Zenek", "lines": [["Z pustymi rękami? Przynieś coś, to pogadamy. Biorę wszystko, co ludzie wyrzucają.", "Telefony, zegarki, miedź, butelki. Co znajdziesz, to przynoś.", "Dziś nic? Poszukaj po śmietnikach, młody. Ludzie wyrzucają skarby."].pick_random()], "choices": [scales, {"label": "Na razie nic."}]})
		return
	var total := 0.0
	var choices := []
	for e in list:
		total += float(e.total)
	choices.append({"label": "Sprzedaj wszystko — %s" % G.money(total), "kind": "go", "act": func():
		var got: float = G.pawn_sell_all()
		Sfx.play("good")
		G.notify("Lombard: +%s." % G.money(got), "good")})
	for e in list:
		if choices.size() >= 4:
			break
		var iid: String = e.id
		choices.append({"label": "%s × %d — %s" % [String(D.ITEMS[iid].name), int(e.n), G.money(e.total)], "act": func():
			var got2: float = G.pawn_sell(iid)
			Sfx.play("good")
			G.notify("Lombard: +%s." % G.money(got2), "good")
			pawn_talk()})
	choices.append(scales)
	choices.append({"label": "Na razie nic."})
	ui.dialog({"name": "Pan Zenek", "lines": [["Pokaż, co tam masz. Dziś płacę uczciwie — jak na mnie.", "No, no. Ktoś miał dobry dzień na śmietnikach.", "Ceny mam inne co dzień. Jak ci nie pasuje, przyjdź jutro."].pick_random()], "choices": choices})


func sleep() -> void:
	if G.S.wanted:
		G.notify("Nie zaśniesz, gdy szuka Cię policja.", "warn")
		return
	var accepted := 0
	for o in G.S.orders:
		if o.status == "accepted":
			accepted += 1
	var to_morning: float = fmod(7.0 - G.hour() + 24.0, 24.0) * 60.0
	if to_morning < 60.0:
		to_morning += 1440.0
	var line := "Położyć się? Czas popłynie, a gorąco na mieście opadnie. (Grę zapisujesz przy laptopie.)"
	if accepted > 0:
		line = "Masz umówionych klientów (%d). Jeśli zaśpisz, nie będą czekać." % accepted
	elif G.ready_drop() != null:
		line = "W skrytce czeka paczka od Wiktora. Jeśli przepadnie, i tak za nią zapłacisz."
	ui.dialog({"name": "Łóżko", "lines": [line], "choices": [
		{"label": "Śpij do 7:00 (%d h)" % int(round(to_morning / 60.0)), "kind": "go", "act": func(): _do_sleep(to_morning)},
		{"label": "Drzemka — 3 godziny", "act": func(): _do_sleep(180.0)},
		{"label": "Jeszcze nie"},
	]})


func _do_sleep(minutes: float) -> void:
	G.busy = true
	await ui.fade(true)
	G.mods["sleeping"] = true
	G.add_minutes(minutes)
	G.mods.erase("sleeping")
	if G.running:
		G.S.heat = maxf(0.0, G.S.heat - minutes / 60.0 * 2.5)
		world.update_stations()
		G.notify("Dzień %d, %s." % [G.day(), G.clock()], "good")
	await get_tree().create_timer(0.5).timeout
	await ui.fade(false)
	G.busy = false


func talk_stasiu() -> void:
	if not G.flag("met_stasiu"):
		ui.dialog({"name": "Wujek Staś", "lines": [
			"Kuba! Chłopcze… Słyszałem, co się stało w hucie. Dobrze, że żyjesz. U mnie nikt nic nie widział i nic nie słyszał.",
			"Wiem, w czym siedzisz, i nie będę cię pouczał. U mnie kupisz plecak, doniczki, nasiona — a o nic nie pytam. Po porządną wagę idź do Zenka, do lombardu.",
			"Jedna rada od starego: nie noś przy sobie więcej, niż sprzedasz. I nie handluj pod nosem policji — radiowóz kręci się po Hutniczej i po osiedlu.",
		], "on_end": _stasiu_met})
		return
	ui.dialog({"name": "Wujek Staś", "lines": [["Co podać?", "Znowu ty. Czego potrzebujesz?", "Interes się kręci?"].pick_random()], "choices": [
		{"label": "Pokaż, co masz", "kind": "go", "act": func(): ui.open_shop()},
		{"label": "Masz jakąś radę?", "act": func(): ui.dialog({"name": "Wujek Staś", "lines": [D.HINTS.pick_random()]})},
		{"label": "Na razie nic."},
	]})


func talk_clothes() -> void:
	var first := not G.flag("met_grazyna")
	G.S.flags["met_grazyna"] = true
	var lines := ["Dzień dobry, kochaniutki. Wszystko po praniu, wszystko z Zachodu.", "Ubranie robi człowieka: w koszuli patrol patrzy na ciebie łaskawiej, w kominiarce — wręcz przeciwnie. Lepsze rzeczy odkładam dla stałych klientów, więc zaglądaj, jak się dorobisz."] if first else [["Co podać, kochaniutki?", "Nowa dostawa przyszła, sam zobacz.", "Dla ciebie zawsze coś się znajdzie."].pick_random()]
	ui.dialog({"name": "Pani Grażyna", "lines": lines, "choices": [
		{"label": "Pokaż, co masz na wieszakach", "kind": "go", "act": func(): ui.open_inventory("", "wear")},
		{"label": "Tylko się rozglądam."},
	]})


func _stasiu_met() -> void:
	G.S.flags["met_stasiu"] = true
	G.add_xp(10.0)
	ui.open_shop()


# ================================================================ interakcje
func _drop_inter() -> Variant:
	if player.loc != "out":
		return null
	var pp: Vector3 = player.global_position
	for d in G.S.drops:
		if d.state != "ready":
			continue
		var dd: Dictionary = G.Market.spot(d)
		if Vector2(float(dd.x) - pp.x, float(dd.z) - pp.z).length() < 3.6:
			var drop: Dictionary = d
			return {"loc": "out", "x": float(dd.x), "z": float(dd.z), "id": "drop", "y0": 0.0, "y1": 1.2, "r": 0.85, "reach": 2.8,
				"label": func(): return "Skrytka: otwórz (%s)" % G.Market.contents(drop), "act": func(): _take_drop(drop)}
	return null


## Skrytka Wiktora otwiera się jednym naciśnięciem: po prawej stronie ekwipunku leży paczka, bierzesz z niej, ile chcesz.
func _take_drop(d: Dictionary) -> void:
	if G.busy or ui.mode != "":
		return
	# grzebanie w skrytce na oczach policji: przy „spalonej” skrytce tajniak rusza od razu
	var pp: Vector3 = player.global_position
	for c in npcs.cops:
		if (c.sees or float(c.get("lvl", 0.0)) > 0.0) and Vector2(c.x - pp.x, c.z - pp.z).length() < 16.0:
			G.add_heat(8.0)
			if d.get("burned", false):
				G.notify("To była zasadzka! Tajniak tylko czekał, aż sięgniesz do skrytki.", "bad")
				c.idle = 0.0
				npcs.start_chase(c)
			else:
				c.susp = minf(1.0, float(c.susp) + 0.6)
				G.notify("Policjant widział, jak grzebiesz w skrytce!", "bad")
			break
	Sfx.play("open")
	ui.open_loot({"kind": "drop", "d": d})


## Interakcja wymaga nacelowania: promień wzroku musi przejść przez obiekt z normalnej odległości.
## Każdy obiekt to pionowy „słupek” (x, z, y0..y1) o promieniu r; reach = zasięg ręki.
const AIM_REACH := 2.6

## zwraca (odległość promienia od osi obiektu, odległość wzdłuż promienia)
func _aim_at(o: Vector3, d: Vector3, x: float, z: float, y0: float, y1: float) -> Vector2:
	var b := Vector3(x, y0, z)
	var hgt := maxf(0.01, y1 - y0)
	var w0 := o - b
	var den := 1.0 - d.y * d.y
	var t := clampf((w0.y - d.y * d.dot(w0)) / den, 0.0, hgt) if den > 0.0001 else clampf(w0.y, 0.0, hgt)
	var sdist := maxf(0.0, (b + Vector3(0, t, 0) - o).dot(d))
	var q := o + d * sdist
	t = clampf(q.y - y0, 0.0, hgt)
	return Vector2(q.distance_to(b + Vector3(0, t, 0)), sdist)


## wszystkie obiekty w zasięgu kilku metrów: [{it, pos (punkt celowania), miss, dist, hit}]
func _aim_scan() -> Array:
	var out := []
	var cam: Camera3D = player.cam
	var o := cam.global_position
	var dir := -cam.global_transform.basis.z
	var pp: Vector3 = player.global_position
	var outside: bool = player.loc == "out"
	var cands: Array = []
	var di = _drop_inter()
	if di != null:
		cands.append(di)
	for it in world.inter:
		if it.loc == player.loc:
			cands.append(it)
	if world.inter_dyn.has(player.loc):
		for it in world.inter_dyn[player.loc]:
			cands.append(it)
	for n in npcs.all:
		if n.has("interact") and n.loc == player.loc and n.node != null and n.node.visible:
			var ni: Dictionary = n.interact
			cands.append({"x": n.x, "z": n.z, "y0": 0.0, "y1": 1.85, "r": 0.5, "reach": minf(float(ni.get("range", 2.9)), 3.0), "label": ni.label, "act": ni.act, "id": "npc"})
	for it in cands:
		var ax: float = it.get("ax", it.x)
		var az: float = it.get("az", it.z)
		if absf(ax - pp.x) > 5.0 or absf(az - pp.z) > 5.0:
			continue
		# rzeczy pod sufitem (lampa) łapią celownik tylko wtedy, gdy patrzysz w górę
		if it.get("up", false) and dir.y < 0.3:
			continue
		var gy: float = world.height(ax, az) if outside else 0.0
		var y0: float = gy + float(it.get("y0", 0.0))
		var y1: float = gy + float(it.get("y1", 1.9))
		var res := _aim_at(o, dir, ax, az, y0, y1)
		var reach: float = it.get("reach", AIM_REACH)
		out.append({"it": it, "pos": Vector3(ax, (y0 + y1) * 0.5, az), "miss": res.x, "dist": res.y,
			"hit": res.x <= float(it.get("r", 0.6)) and res.y <= reach, "near": Vector2(ax - pp.x, az - pp.z).length() <= reach + 1.4})
	return out


func _find_interact() -> Variant:
	var best = null
	var bd := 1e9
	var scan := _aim_scan()
	for c in scan:
		if c.hit and float(c.dist) < bd:
			bd = c.dist
			best = c
	# znaczniki pobliskich obiektów: gracz widzi, na co może nacelować
	aim_hints.clear()
	for c in scan:
		if c.near:
			aim_hints.append({"pos": c.pos, "on": best != null and is_same(c, best)})
	return best.it if best != null else null


func interact() -> void:
	if player.hidden:
		hide_leave()
		return
	cur_inter = _find_interact()
	if cur_inter == null:
		return
	if cur_inter.has("menu"):
		menu_pick()
		return
	if cur_inter.has("hold"):
		hold_inter = cur_inter
		hold_t = 0.0
		return
	cur_inter.act.call()


## Skrzynka Wiktora: drzwiczki się uchylają, otwiera się plecak ze skrzynką po prawej (tylko gotówka).
func open_box() -> void:
	if G.busy:
		return
	Sfx.play("door")
	if world.box_door != null:
		var tw := create_tween()
		tw.tween_property(world.box_door, "rotation:y", -1.9, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	G.S.flags["tut_box"] = true
	ui.open_inventory("wiktor")


func close_box() -> void:
	if world.box_door != null:
		var tw := create_tween()
		tw.tween_property(world.box_door, "rotation:y", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	Sfx.play("door_close")


## Paczka na start: pukanie, kamera schodzi do podłogi przy drzwiach kawalerki, spod drzwi wsuwają się
## dwa woreczki — zioło i strunowy z amfetaminą. Potem paczka leży i czeka, aż gracz ją podniesie.
## kamera scenki z paczką pod drzwiami: [skąd, na co patrzy, kąt] dla postępu najazdu k = 0…1
## (osobno, bo tym samym kadrem podgląd bez okna sprawdza, czy paczkę w ogóle widać)
## k = 0…1: kamera przy podłodze dojeżdża do drzwi, spod których wysuwają się woreczki;
## k = 1…2: unosi się i powoli zbliża z góry, żeby było widać, co w nich jest.
func door_cam(k: float) -> Array:
	var R: Dictionary = D.ROOMS.safe
	var cx := float(R.cx)
	var ez := float(R.d) * 0.5
	# pierwsze ujęcie: z boku na drzwi, na wysokości szczeliny na listy — widać, jak paczka się przeciska i spada
	var from := Vector3(cx + 0.95, 0.8, ez - 1.55)
	var to := Vector3(cx + 0.7, 0.55, ez - 1.25)
	var look := Vector3(cx - 0.04, 0.8, ez - 0.2)
	var look2 := Vector3(cx - 0.02, 0.12, ez - 0.5)
	if k <= 1.0:
		return [from.lerp(to, k), look.lerp(look2, smoothstep(0.35, 0.9, k)), lerpf(40.0, 36.0, k)]
	var k2 := clampf(k - 1.0, 0.0, 1.0)
	k2 = k2 * k2 * (3.0 - 2.0 * k2)
	# drugie ujęcie: kamera schodzi nad paczkę leżącą na wycieraczce
	var top := Vector3(cx + 0.24, 0.36, ez - 0.98)
	var bags := Vector3(cx - 0.02, 0.03, ez - 0.6)
	return [to.lerp(top, k2), look2.lerp(bags, k2), lerpf(36.0, 28.0, k2)]


func door_package() -> void:
	if not world.rooms.has("safe"):
		world.refresh_starter()
		return
	world.refresh_starter()
	if world.starter == null or player.loc != "safe" or G.test_mode:
		return
	G.busy = true
	ui.close_all()
	var R: Dictionary = D.ROOMS.safe
	var cx := float(R.cx)
	var ez := float(R.d) * 0.5
	world.starter_rest(0.0, 0.0)
	Sfx.play("pukanie")
	await get_tree().create_timer(0.9).timeout
	ui.cut_begin()
	var c0 := door_cam(0.0)
	cine_cam(c0[0], c0[1], c0[2])
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(k: float):
		var ck := door_cam(k)
		cine_cam(ck[0], ck[1], ck[2]), 0.0, 1.0, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# klapka szczeliny na listy uchyla się, paczka przeciska się na sztorc i spada na wycieraczkę
	tw.tween_callback(func(): Sfx.play("cloth")).set_delay(0.7)
	tw.tween_method(func(k: float): world.starter_rest(k * 0.3), 0.0, 1.0, 0.9).set_delay(0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float): world.starter_rest(0.3 + k * 0.7), 0.0, 1.0, 0.75).set_delay(1.7)
	tw.tween_callback(func(): Sfx.play("thud", -4.0)).set_delay(2.1)
	ui.cut_line("Ktoś puka. Klapka na listy uchyla się i na wycieraczkę spada paczka.")
	await get_tree().create_timer(3.9).timeout
	# drugie ujęcie: kamera unosi się i zbliża — worek zielonego i strunowy woreczek białego
	ui.cut_line("Czarna folia, szara taśma. W środku towar na rozruch — od Wiktora.")
	var tw2 := create_tween()
	tw2.tween_method(func(k: float):
		var ck2 := door_cam(1.0 + k)
		cine_cam(ck2[0], ck2[1], ck2[2]), 0.0, 1.0, 3.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(4.6).timeout
	ui.cut_line("")
	world.starter_rest(1.0)
	cine_off()
	ui.cut_end()
	G.busy = false


## Paczka gotowa do odbioru: kurier staje w umówionym miejscu, a przy „spalonej” skrytce czai się tajniak.
func drop_ready(d: Dictionary) -> void:
	var sp: Dictionary = G.Market.spot(d)
	var at := Vector2(float(sp.x), float(sp.z))
	if d.get("burned", false):
		# tajniak w cywilu… w mundurze, bo to prosta gra: stoi kilkanaście metrów od skrytki i na nią patrzy
		var a := randf() * TAU
		var cp: Vector2 = world.near_free(at.x + cos(a) * 9.0, at.y + sin(a) * 9.0)
		var c: Dictionary = npcs.spawn_cop(false)
		c["temp"] = true
		c.x = cp.x
		c.z = cp.y
		c.state = "patrol"
		c.idle = 99999.0
		c.node.rotation.y = atan2(at.x - cp.x, at.y - cp.y)
		c.node.position = Vector3(cp.x, world.height(cp.x, cp.y), cp.y)
		drop_actors[int(d.id)] = {"cop": c}


## Paczka odebrana albo przepadła: sprzątamy kuriera / zasadzkę.
func drop_gone(d: Dictionary) -> void:
	var a = drop_actors.get(int(d.id))
	if a == null:
		return
	drop_actors.erase(int(d.id))
	if a.has("static"):
		npcs.remove_static(a.static)
	elif a.has("cop"):
		var c: Dictionary = a.cop
		if npcs.cops.has(c):
			if c.state == "chase":
				c.idle = 0.0
			else:
				npcs.remove_cop(c)


## nalot na kryjówkę, w której akurat siedzi gracz
func raided_inside() -> void:
	ui.close_all()
	G.notify("Drzwi wylatują z zawiasów!", "bad")
	Sfx.play("alert")
	G.arrest(null)


# ================================================================ skradanie: kryjówki i odciąganie patroli
## Chowa gracza w altance. Patrol, który to widział, wie, gdzie szukać.
func hide_enter(h: Dictionary) -> void:
	if player.hidden or G.busy:
		return
	var seen := false
	for c in npcs.cops:
		if c.sees or float(c.get("lvl", 0.0)) > 0.0:
			c.know = true
			c.inv = Vector2(float(h.x), float(h.z))
			seen = true
	hide_at = h
	player.global_position = Vector3(float(h.x), world.height(float(h.x), float(h.z)), float(h.z))
	player.yaw = float(h.rot) + PI
	player.pitch = -0.05
	player.set_crouch(true)
	player.crouching = true
	player.hidden = true
	player.velocity = Vector3.ZERO
	if player.flash.light_energy > 0.0:
		player.flash.light_energy = 0.0
	Sfx.play("pickup")
	if seen:
		G.notify("Widzieli, gdzie się chowasz!", "bad")
	elif G.S.wanted:
		G.notify("Schowany. Siedź cicho, aż odpuszczą.", "good")


func hide_leave(_forced := false) -> void:
	if not player.hidden:
		return
	player.hidden = false
	var h := hide_at
	hide_at = {}
	if not h.is_empty():
		player.global_position = Vector3(float(h.ox), world.height(float(h.ox), float(h.oz)), float(h.oz))
	player.crouching = true
	player.set_crouch(false)
	for c in npcs.cops:
		c.know = false


## Rzut kamykiem: tam, gdzie spadnie, robi się hałas i spokojne patrole idą to sprawdzić.
## Patrol, który akurat na Ciebie patrzy, nie da się nabrać.
func throw_stone() -> void:
	if throw_cd > 0.0 or player.loc != "out" or player.hidden or G.busy:
		return
	throw_cd = 2.2
	var cam: Camera3D = player.cam
	var dir := -cam.global_transform.basis.z
	var node := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.075
	sm.radial_segments = 8
	sm.rings = 4
	node.mesh = sm
	node.material_override = Models.mat("6b6862", 0.95)
	add_child(node)
	var p0 := cam.global_position + dir * 0.5 + Vector3(0, -0.2, 0)
	node.global_position = p0
	var seen := false
	for c in npcs.cops:
		if float(c.get("lvl", 0.0)) > 0.0:
			seen = true
			if npcs.susp_mult > 0.0:
				c.susp += 0.25
	stones.append({"node": node, "p": p0, "v": dir * 13.5 + Vector3(0, 3.2, 0), "seen": seen, "t": 0.0})
	Sfx.play("pickup", -6.0)
	G.S.stats["thrown"] = int(G.S.stats.get("thrown", 0)) + 1


func _stones_tick(dt: float) -> void:
	throw_cd = maxf(0.0, throw_cd - dt)
	for st in stones.duplicate():
		st.t = float(st.t) + dt
		if st.has("rest"):
			if float(st.t) > 25.0:
				st.node.queue_free()
				stones.erase(st)
			continue
		var p: Vector3 = st.p
		var v: Vector3 = st.v
		v.y -= 16.0 * dt
		var np := p + v * dt
		# mury i auta zatrzymują kamyk
		if np.y < 3.0 and not world.los(p.x, p.z, np.x, np.z, np.y < 1.0):
			v.x *= -0.25
			v.z *= -0.25
			np = p + Vector3(v.x, v.y, v.z) * dt
		var gy: float = world.height(np.x, np.z)
		if np.y <= gy + 0.04 or float(st.t) > 4.0:
			np.y = gy + 0.04
			st["rest"] = true
			st.t = 0.0
			Sfx.play("drop", -2.0)
			if not st.seen:
				var n: int = npcs.noise_at(np.x, np.z, 13.0)
				if n > 0:
					G.S.stats["lured"] = int(G.S.stats.get("lured", 0)) + n
		st.p = np
		st.v = v
		st.node.global_position = np


func toggle_flash() -> void:
	player.flash.light_energy = 0.0 if player.flash.light_energy > 0.0 else 7.0
	Sfx.play("toggle")


# ================================================================ cele i trasa
func _order_target(o: Dictionary) -> Dictionary:
	var spot := G.spot_def(o.spot)
	return {"id": int(o.id), "label": "%s  %s — %s" % [G.clock(o.meet) if o.status == "accepted" else "?", String(G.cust_def(o.cust).name), spot.name], "loc": "out", "x": float(spot.x), "z": float(spot.z), "color": C_ORDER}


func _place_target(id: String) -> Dictionary:
	if id == "box":
		return {"id": id, "label": "Skrzynka Wiktora", "loc": "out", "x": float(D.WIKTOR_BOX.x), "z": float(D.WIKTOR_BOX.z), "color": C_PLACE}
	if id == "pawn":
		return {"id": id, "label": "Lombard (skup, wagi)", "loc": "out", "x": float(D.PAWN_AT.x), "z": float(D.PAWN_AT.z), "color": C_PLACE}
	if id == "supply":
		return {"id": id, "label": "Hurtownia budowlana", "loc": "out", "x": float(D.SUPPLY_AT.x), "z": float(D.SUPPLY_AT.z), "color": C_PLACE}
	if id == "home" or id == "shop":
		var room := "safe" if id == "home" else "shop"
		return {"id": id, "label": "Kawalerka" if id == "home" else "Sklep u Stasia", "loc": room, "x": float(D.ROOMS[room].cx), "z": 0.0, "color": C_PLACE}
	var pid := id.trim_prefix("prop:")
	var p := G.prop_def(pid)
	if p.is_empty() or String(p.room) == "":
		return {}
	var dd: Dictionary = D.DOORS[p.room]
	if G.owns(pid):
		return {"id": id, "label": String(p.name), "loc": String(p.room), "x": float(D.ROOMS[p.room].cx), "z": 0.0, "color": C_PLACE}
	return {"id": id, "label": String(p.name), "loc": "out", "x": float(dd.x), "z": float(dd.z), "color": C_PLACE}


func _drop_target() -> Dictionary:
	var d = G.ready_drop()
	if d == null:
		return {}
	var dd: Dictionary = G.Market.spot(d)
	var mark: String = G.drop_mark(dd)
	return {"id": "drop", "label": "Skrytka: " + String(dd.name) + (" (znak: %s)" % mark if mark != "" else ""), "loc": "out", "x": float(dd.x), "z": float(dd.z), "color": C_DROP}


func _story_target() -> Dictionary:
	var st := G.cur_step()
	if st.has("marker"):
		var m = st.marker.call()
		if m != null:
			return {"id": "story", "label": "Cel", "loc": m.loc, "x": float(m.x), "z": float(m.z), "color": C_STORY}
	return {}


func cur_target() -> Dictionary:
	var S: Dictionary = G.S
	var t = S.track
	if t is int or t is float:
		var o = G.find_order(t)
		if o != null and o.status == "accepted":
			return _order_target(o)
		S.track = null
		t = null
	if t is String:
		if t == "drop":
			var dt := _drop_target()
			if not dt.is_empty():
				return dt
			S.track = null
		elif t == "home" or t == "shop" or t == "box" or t == "pawn" or t == "supply" or String(t).begins_with("prop:"):
			var pt := _place_target(t)
			if not pt.is_empty():
				return pt
			S.track = null
	var st := _story_target()
	if not st.is_empty():
		return st
	for o in S.orders:
		if o.status == "accepted":
			return _order_target(o)
	return _drop_target()


## lista celów do wyboru w telefonie
func nav_targets() -> Array:
	var out := []
	if not _story_target().is_empty():
		out.append({"id": "story", "label": "Cel fabularny"})
	for o in G.S.orders:
		if o.status == "accepted":
			var t := _order_target(o)
			out.append({"id": t.id, "label": "Klient: " + String(t.label)})
	var dt := _drop_target()
	if not dt.is_empty():
		out.append({"id": "drop", "label": String(dt.label)})
	out.append({"id": "home", "label": "Kawalerka"})
	out.append({"id": "box", "label": "Skrzynka Wiktora"})
	out.append({"id": "shop", "label": "Sklep u Stasia"})
	out.append({"id": "pawn", "label": "Lombard (skup, wagi)"})
	out.append({"id": "supply", "label": "Hurtownia budowlana"})
	for p in D.PROPERTIES:
		if G.owns(p.id):
			out.append({"id": "prop:" + String(p.id), "label": String(p.name)})
	return out


## cele rysowane na mapie i kompasie (aktualnie prowadzony)
func targets() -> Array:
	var t := cur_target()
	if t.is_empty():
		return []
	if t.loc != "out":
		if t.loc == player.loc:
			return [t]
		var dd: Dictionary = D.DOORS[t.loc]
		t = t.duplicate()
		t.x = float(dd.x)
		t.z = float(dd.z)
		t.loc = "out"
	return [t]


func track_key() -> String:
	var t := cur_target()
	return "" if t.is_empty() else str(t.id)


func set_track(id) -> void:
	G.S.track = null if (id is String and id == "story") else id
	G.S.nav_on = true
	nav_force = true
	if G.running:
		refresh_nav()


func toggle_nav() -> void:
	G.S.nav_on = not G.S.nav_on
	nav_force = true
	G.notify("Trasa: " + ("włączona" if G.S.nav_on else "wyłączona"))


func cycle_track() -> void:
	var list := nav_targets()
	if list.is_empty():
		return
	var key := track_key()
	var idx := -1
	for i in range(list.size()):
		if str(list[i].id) == key:
			idx = i
	var nx: Dictionary = list[(idx + 1) % list.size()]
	set_track(nx.id)
	G.notify("Prowadzę do: " + String(nx.label))


func refresh_nav() -> void:
	nav_t = 0.5
	var T := cur_target()
	if T.is_empty() or not G.running:
		nav.clear_path()
		ui.nav_info = {}
		way = {}
		nav_force = false
		return
	var pp: Vector3 = player.global_position
	var goal := Vector2(T.x, T.z)
	var indoor: bool = player.loc != "out"
	if T.loc != player.loc:
		if indoor:
			var R: Dictionary = D.ROOMS[player.loc]
			goal = Vector2(float(R.cx), float(R.d) * 0.5 - 0.8)
		else:
			var dd: Dictionary = D.DOORS[T.loc]
			goal = Vector2(float(dd.x), float(dd.z))
	var here := Vector2(pp.x, pp.z)
	var direct := here.distance_to(goal)
	if not way.is_empty():
		way.dist = direct
	if not nav_force and here.distance_to(nav_last) < 1.5 and goal.distance_to(nav_goal) < 1.0:
		return
	nav_force = false
	nav_last = here
	nav_goal = goal
	var pts: Array = [here, goal] if indoor else nav.find(here.x, here.y, goal.x, goal.y)
	var dist := 0.0
	for i in range(pts.size() - 1):
		dist += (pts[i + 1] as Vector2).distance_to(pts[i])
	if G.S.nav_on and direct > 2.0:
		nav.set_path(pts, T.color, indoor)
	else:
		nav.clear_path()
	ui.nav_info = {"label": T.label, "dist": dist, "color": T.color}
	way = {"pos": Vector3(goal.x, (0.0 if indoor else world.height(goal.x, goal.y)) + 1.5, goal.y), "color": T.color, "dist": direct}


func _build_beacon() -> void:
	beacon = Node3D.new()
	beacon.visible = false
	add_child(beacon)
	beacon_mat = StandardMaterial3D.new()
	beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beacon_mat.albedo_color = Color(0.3, 1.0, 0.5, 0.28)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.3
	cm.height = 34.0
	cm.radial_segments = 10
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = Vector3(0, 17.0, 0)
	mi.material_override = beacon_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(mi)


# ================================================================ meblowanie kryjówek
func build_active() -> bool:
	return not build.is_empty()


func build_menu() -> void:
	if build_active():
		build_cancel()
		return
	var loc: String = player.loc
	if loc == "safe":
		G.notify("Kawalerka jest za mała na przemeblowanie. Kup własną kryjówkę (telefon → Lokale).", "warn")
	elif loc == "garage" or loc == "basement":
		ui.open_build(loc)
	else:
		G.notify("Meblować możesz tylko we własnej kryjówce.", "warn")


func build_begin(fid: String) -> void:
	build_cancel()
	var loc: String = player.loc
	if not world.furn.has(loc):
		return
	var f := G.furn_def(fid)
	var ghost: Node3D = world.furn_model(fid)
	add_child(ghost)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.3, 1.0, 0.5, 0.3)
	var mark := Models.box(ghost, Vector3(float(f.size[0]), 0.04, float(f.size[1])), Vector3(0, 0.03, 0), mm, Vector3.ZERO, false)
	build = {"fid": fid, "room": loc, "r": 0, "ghost": ghost, "mark": mark, "mat": mm, "valid": false, "x": 0.0, "z": 0.0}


func build_rotate() -> void:
	if build_active():
		build.r = (int(build.r) + 1) % 4
		Sfx.play("tick")


func build_cancel() -> void:
	if build.is_empty():
		return
	if is_instance_valid(build.ghost):
		build.ghost.queue_free()
	build = {}
	if ui != null:
		ui.set_build_hint("")


func build_confirm() -> void:
	if not build_active():
		return
	if not build.valid:
		Sfx.play("error")
		G.notify("Tu się nie zmieści.", "warn")
		return
	var fid: String = build.fid
	var room: String = build.room
	if build.get("pot", false):
		if G.Prod.pot_place(room, float(build.x), float(build.z)):
			var left: int = G.item_at(room, "doniczka")
			G.notify("Doniczka stoi. %s" % (("Zostało: %d." % left) if left > 0 else "Posadź w niej nasiono."), "good")
			if left > 0 and G.Prod.pots(room).size() < int(D.POT_MAX.get(room, 8)):
				return
		build_cancel()
		return
	if G.furn_place(room, fid, float(build.x), float(build.z), int(build.r)):
		var more: int = G.owned(fid)
		G.notify("Ustawiono: %s.%s" % [String(G.furn_def(fid).name), (" Na stanie jeszcze %d." % more) if more > 0 else ""], "good")
		# kolejna sztuka tego samego od razu pod ręką
		if more > 0:
			return
	build_cancel()


func _build_tick() -> void:
	var room: String = build.room
	if player.loc != room:
		build_cancel()
		return
	var pp: Vector3 = player.global_position
	var fw: Vector2 = player.forward()
	if build.get("pot", false):
		# doniczka: bliżej gracza i z drobniejszą siatką; pod lampą znacznik robi się fioletowy
		var pr: float = clampf(1.15 + clampf(-player.pitch, -0.5, 0.9) * 1.1, 0.6, 2.4)
		var pcx: float = D.ROOMS[room].cx
		var px := snappedf(pp.x + fw.x * pr - pcx, 0.1)
		var pz := snappedf(pp.z + fw.y * pr, 0.1)
		build.x = px
		build.z = pz
		build.valid = G.Prod.pot_valid(room, px, pz)
		(build.ghost as Node3D).position = Vector3(pcx + px, 0.0, pz)
		var lit: bool = G.Prod.light_at(room, px, pz) >= 0
		build.mat.albedo_color = (Color(0.8, 0.4, 1.0, 0.4) if lit else Color(0.3, 1.0, 0.5, 0.32)) if build.valid else Color(1.0, 0.25, 0.25, 0.4)
		ui.set_build_hint("[b]Doniczka[/b] (masz %d)      %s      [b][LPM / E][/b] postaw   [b][PPM / Esc][/b] koniec" % [G.item_at(room, "doniczka"),
			("[color=#d28cff]pod lampą[/color]" if lit else "[color=#facc15]bez lampy — będzie rosła wolno[/color]") if build.valid else "[color=#f05050]tu się nie zmieści[/color]"])
		return
	var f := G.furn_def(build.fid)
	var reach: float = 1.5 + maxf(float(f.size[0]), float(f.size[1])) * 0.5 + clampf(-player.pitch, -0.4, 0.8) * 1.2
	var cx: float = D.ROOMS[room].cx
	var x := snappedf(pp.x + fw.x * reach - cx, 0.25)
	var z := snappedf(pp.z + fw.y * reach, 0.25)
	build.x = x
	build.z = z
	build.valid = G.furn_valid(room, build.fid, x, z, int(build.r))
	var g: Node3D = build.ghost
	g.position = Vector3(cx + x, 0.0, z)
	g.rotation.y = int(build.r) * PI / 2.0
	build.mat.albedo_color = Color(0.3, 1.0, 0.5, 0.32) if build.valid else Color(1.0, 0.25, 0.25, 0.4)
	ui.set_build_hint("[b]%s[/b] — %s      %s      [b][LPM / E][/b] postaw   [b][R][/b] obróć   [b][PPM / Esc][/b] anuluj" % [
		f.name, G.money(f.price), "[color=#4ade80]pasuje[/color]" if build.valid else "[color=#f05050]nie zmieści się[/color]"])


# ================================================================ pętla
func _process(dt: float) -> void:
	if ui == null:
		return
	if ui.mode == "title":
		title_t += dt
		# powolny przelot kamery nad miastem o zmierzchu
		var ang := 4.04 + title_t * 0.01
		var cp := _cine_pt(sin(ang) * 196.0, cos(ang) * -158.0, 40.0)
		cine_cam(cp, _cine_pt(0.0, 0.0, 10.0), 54.0)
		env.update(TITLE_HOUR, dt, "out", cp, world)
		npcs.susp_mult = 0.0
		npcs.update(dt)
		world.tick_train(dt, G.night)
		return
	if get_tree().paused or not G.running:
		return
	_tick(dt)


func _tick(dt: float) -> void:
	# po dłuższym przycięciu (uśpienie Maca, przeciągnięcie okna) czas gry nie może skoczyć o godziny
	dt = minf(dt, 0.25)
	var S: Dictionary = G.S
	G.now += dt
	if not G.busy and G.prologue == null:
		G.add_minutes(dt * D.TIME_SCALE)
		if not G.running:
			return
	var w = S.weather
	env.rain_target = float(w.power) if (w != null and S.t >= float(w.start) and S.t < float(w.end)) else 0.0
	var t0 := Time.get_ticks_usec()
	var eye: Vector3 = cine.global_position if (cine != null and cine.current) else player.cam.global_position
	env.update(cut_hour if cut_hour >= 0.0 else G.hour(), dt, player.loc, eye, world)
	if not G.test_mode:
		env.auto_scale(dt)
	var t1 := Time.get_ticks_usec()
	npcs.susp_mult = 0.0 if G.busy else G.compute_susp()
	npcs.update(dt)
	var t2 := Time.get_ticks_usec()
	world.tick_train(dt, G.night)
	prof[0] += t1 - t0
	prof[1] += t2 - t1
	prof[2] += 1
	if S.wanted:
		_wanted_tick(dt)
	else:
		S.heat = maxf(0.0, S.heat - dt * (0.25 if player.loc != "out" else 0.1))
	_stones_tick(dt)
	slow_t -= dt
	if slow_t <= 0.0:
		slow_t = 0.25
		_slow()
	nav_t -= dt
	if nav_force or nav_t <= 0.0:
		refresh_nav()
	if ui.is_open():
		# otwarte okno: czas, ludzie i patrole idą dalej, ale nie celujemy i niczego nie przytrzymujemy
		hold_inter = null
		cur_inter = null
		aim_hints.clear()
		ui.set_prompt("")
		ui.set_aim(false)
		return
	if build_active():
		_build_tick()
		ui.set_prompt("")
		aim_hints.clear()
		ui.set_aim(false)
		return
	if G.busy:
		ui.set_prompt("")
		ui.set_aim_menu("", [], 0)
		hold_inter = null
		aim_hints.clear()
		ui.set_aim(false)
		return
	early_cut_t = maxf(0.0, early_cut_t - dt)
	if player.hidden:
		cur_inter = null
		hold_inter = null
		aim_hints.clear()
		ui.set_aim(false)
		ui.set_prompt("[%s] Wyjdź z kryjówki" % G.kn("use"))
		return
	cur_inter = _find_interact()
	ui.set_aim(cur_inter != null)
	if hold_inter != null:
		if cur_inter == null or cur_inter.get("id", "") != hold_inter.get("id", "?") or not G.key_down("use"):
			hold_inter = null
		else:
			hold_t += dt
			if hold_t >= float(hold_inter.hold):
				var act: Callable = hold_inter.act
				hold_inter = null
				act.call()
				return
	if cur_inter != null and cur_inter.has("menu"):
		# cel z własnym menu czynności (krzak w doniczce): lista obok celownika zamiast podpowiedzi
		menu_opts = cur_inter.menu.call()
		if String(cur_inter.id) != menu_id:
			menu_id = String(cur_inter.id)
			menu_sel = 0
			ui.hide_plant_card()
		menu_sel = clampi(menu_sel, 0, maxi(0, menu_opts.size() - 1))
		ui.set_prompt("")
		ui.set_aim_menu(cur_inter.label.call(), menu_opts, menu_sel)
	else:
		if menu_id != "":
			menu_id = ""
			menu_opts = []
			ui.set_aim_menu("", [], 0)
			ui.hide_plant_card()
		if cur_inter != null:
			ui.set_prompt(cur_inter.label.call(), (hold_t / float(hold_inter.hold)) if hold_inter != null else -1.0)
		else:
			ui.set_prompt("")


# ================================================================ radio w kawalerce
func radio_name() -> String:
	var st := clampi(int(G.S.get("radio", 0)), 0, 2)
	if st == 0:
		return "wyłączone"
	var nm: String = Sfx.radio_track_name(st - 1)
	return ("Blok FM" if st == 1 else "Radio Impreza") + ((" — " + nm) if nm != "" else "")


## klik 1: pierwsza stacja, klik 2: druga, klik 3: cisza, klik 4: znów pierwsza
func radio_click() -> void:
	G.S["radio"] = (int(G.S.get("radio", 0)) + 1) % 3
	Sfx.play("toggle")
	radio_apply()
	G.notify("Radio: " + radio_name())


func radio_apply() -> void:
	var rp: AudioStreamPlayer3D = world.radio_player
	if rp == null:
		return
	var st := int(G.S.get("radio", 0))
	if world.radio_led != null:
		world.radio_led.visible = st > 0
	if st == 0 or Sfx.muted or Sfx.radio_streams.size() < st:
		rp.stop()
		return
	rp.stream = Sfx.radio_streams[st - 1]
	rp.play()


# ================================================================ krzaki w doniczkach
func menu_active() -> bool:
	return menu_id != "" and not menu_opts.is_empty() and not G.busy


func menu_scroll(d: int) -> void:
	if menu_active():
		menu_sel = wrapi(menu_sel + d, 0, menu_opts.size())
		Sfx.play("tick")


## wykonuje pozycję z menu przy celowniku (numer albo zaznaczoną)
func menu_pick(i := -1) -> void:
	if not menu_active() or cur_inter == null or not cur_inter.has("pot"):
		return
	if i < 0:
		i = menu_sel
	if i >= menu_opts.size():
		return
	menu_sel = i
	var o: Dictionary = menu_opts[i]
	if not o.ok:
		Sfx.play("error")
		if String(o.get("why", "")) != "":
			G.notify(String(o.why), "warn")
		return
	pot_do(player.loc, int(cur_inter.pot), String(o.id))


func pot_menu(room: String, i: int) -> Array:
	var P = G.Prod
	var pl = P.plant_of(room, i)
	if pl == null:
		var seeds: int = G.item_at(room, "nasiona")
		return [{"id": "seed", "label": "Posadź nasiono", "icon": "sprout", "ok": seeds > 0, "note": ("masz %d" % seeds) if seeds > 0 else "brak nasion", "why": "Nie masz nasion — kup u Stasia."},
			{"id": "take", "label": "Zabierz doniczkę", "icon": "package_open", "ok": true, "note": ""}]
	var ck: String = P.plant_cut_kind(room, i)
	var ripe := float(pl.prog) >= 1.0
	var fert_n: int = G.item_at(room, "nawoz")
	var fert_why := "Ten krzak już dostał nawóz." if pl.fert else ("Za późno na nawóz — krzak już kwitnie." if float(pl.prog) >= 0.6 else "Nie masz nawozu — kup u Stasia.")
	return [{"id": "check", "label": "Sprawdź", "icon": "search", "ok": true, "note": ""},
		{"id": "water", "label": "Podlej", "icon": "droplets", "ok": not ripe and float(pl.water) < 96.0, "note": "%d%%" % int(pl.water), "why": "Dojrzałej rośliny nie trzeba już podlewać." if ripe else "Ziemia jest mokra."},
		{"id": "fert", "label": "Nawóz", "icon": "flask_conical", "ok": P.plant_can_fert(room, i), "note": "dano" if pl.fert else ("masz %d" % fert_n), "why": fert_why},
		{"id": "cut", "label": {"harvest": "Zetnij — zbiór", "trim": "Przytnij liście", "early": "Zetnij"}.get(ck, "Zetnij"), "icon": "leaf", "ok": true,
			"note": {"harvest": "gotowa", "trim": "jakość +8", "early": "za wcześnie!"}.get(ck, "")}]


func pot_do(room: String, i: int, what: String) -> void:
	var P = G.Prod
	match what:
		"check":
			ui.show_plant_card(room, i)
			Sfx.play("select")
		"take":
			if P.pot_take(room, i):
				G.notify("Doniczka wraca do plecaka.")
		"cut":
			if P.plant_cut_kind(room, i) == "early" and early_cut_t <= 0.0:
				early_cut_t = 4.0
				G.notify("Ta roślina nie jest jeszcze dojrzała — stracisz ją. Wybierz „Zetnij” jeszcze raz, żeby potwierdzić.", "warn")
				return
			early_cut_t = 0.0
			ui.hide_plant_card()
			care.play("cut", room, i)
		_:
			ui.hide_plant_card()
			care.play(what, room, i)


func lamp_toggle(room: String, idx: int) -> void:
	var m: int = G.Prod.lamp_toggle(room, idx)
	var md: Dictionary = G.Prod.lamp_mode(m)
	Sfx.play("toggle")
	G.notify("%s. %s" % [String(md.name), String(md.desc)])
	world.update_stations()


## stawianie doniczek z plecaka (tryb jak przy meblach, ale bez kosztu — płacisz w sklepie)
func build_begin_pot() -> void:
	build_cancel()
	var loc: String = player.loc
	if not world.furn.has(loc):
		return
	if G.item_at(loc, "doniczka") <= 0:
		G.notify("Nie masz doniczek. Kup je u Stasia.", "warn")
		return
	var ghost: Node3D = Stations.pot_node()
	add_child(ghost)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.3, 1.0, 0.5, 0.3)
	var mark := Models.cyl(ghost, 0.24, 0.24, 0.02, Vector3(0, 0.015, 0), mm, Vector3.ZERO, 16)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	build = {"fid": "", "pot": true, "room": loc, "r": 0, "ghost": ghost, "mark": mark, "mat": mm, "valid": false, "x": 0.0, "z": 0.0}


func _wanted_tick(dt: float) -> void:
	if G.key_down("ditch") and G.carry_goods() > 0.01 and not G.arresting and not ui.is_open():
		ditch_hold += dt
		ui.set_prompt("Wyrzucasz towar…", ditch_hold / 0.9)
		if ditch_hold >= 0.9:
			ditch_hold = 0.0
			if G.ditch_goods():
				Sfx.play("drop")
	else:
		ditch_hold = 0.0
	var chasing := false
	var seen := false
	var hunting := false
	var known := false
	for c in npcs.cops:
		if c.state == "chase":
			chasing = true
			if c.sees:
				seen = true
			if c.know:
				known = true
		elif c.state == "search" and c.hunt:
			hunting = true
	if player.loc != "out":
		G.wanted_grace += dt * 1.5
	elif player.hidden and not known:
		G.wanted_grace += dt * 0.9
	elif not chasing:
		# patrole przeczesują okolicę: jeszcze nie odpuścili
		G.wanted_grace += dt * (0.45 if hunting else 1.0)
	elif not seen:
		G.wanted_grace += dt * 0.25
	else:
		G.wanted_grace = 0.0
	if G.wanted_grace > 6.0 and not G.arresting:
		G.S.wanted = false
		G.wanted_grace = 0.0
		npcs.end_chase()
		Sfx.siren(false)
		G.S.stats.escapes = int(G.S.stats.escapes) + 1
		G.add_invest(2.0)
		G.add_xp(8.0)
		G.notify("Zgubiłeś policję. Przez jakiś czas lepiej się nie wychylaj.", "good")


func _slow() -> void:
	# pierwszy przełaz pod ogrodzeniem: jednorazowa podpowiedź, jak się schylić
	if player.loc == "out" and not G.flag("crawl_hint") and not player.crouching:
		var pc: Vector3 = player.global_position
		for cr in world.crawls:
			if absf(float(cr.x) - pc.x) < 2.6 and absf(float(cr.z) - pc.z) < 2.6:
				G.S.flags["crawl_hint"] = true
				G.notify("Siatka jest tu podwinięta. Naciśnij [%s], żeby kucnąć, i przejdź pod nią." % G.kn("crouch"), "good")
				break
	var pp: Vector3 = player.global_position
	G.zone_name = ""
	G.zone_id = ""
	if player.loc == "out":
		var zn := G.zone_at(pp.x, pp.z)
		if not zn.is_empty():
			G.zone_name = zn.name
			G.zone_id = zn.id
	G.story_tick()
	G.tips_tick()
	world.update_stations()
	world.club_tick()
	world.shops_tick()
	var club_d := pp.distance_to(world.club_door) if player.loc == "out" else 999.0
	if world.club_player != null:
		# w środku klubu muzyka gra znad parkietu, na ulicy dudni zza drzwi
		var in_club: bool = player.loc == "club"
		var want: Vector3 = Vector3(float(D.ROOMS.club.cx), 2.5, 0.0) if in_club else world.club_door
		if world.club_player.position.distance_to(want) > 0.1:
			world.club_player.position = want
			world.club_player.unit_size = 22.0 if in_club else 10.0
		if in_club:
			club_d = 0.0
			world.club_lights(G.now)
	Sfx.set_club_open(clampf(1.0 - (club_d - 3.0) / 16.0, 0.0, 1.0))
	Sfx.ambient(player.loc == "out", G.night, G.rain)
	cop_t -= 0.25
	if cop_t <= 0.0 and G.prologue == null:
		cop_t = 4.0
		_cop_population()


## liczba patroli rośnie z uwagą policji; przy zaawansowanym śledztwie
## jeden funkcjonariusz obserwuje wejście do bloku
func _cop_population() -> void:
	var S: Dictionary = G.S
	var pp: Vector3 = player.global_position
	var want: int = G.cop_quota()
	var cnt := 0
	var post = null
	for c in npcs.cops:
		if c.post:
			post = c
		elif not c.get("temp", false):
			cnt += 1
	if cnt < want:
		npcs.spawn_cop(true)
	elif cnt > want and not S.wanted and want == 0 and player.loc != "out":
		# pierwsze dni: po wezwaniu patrol wraca na komendę, gdy tylko gracz zejdzie z ulicy
		for c in npcs.cops:
			if not c.post and not c.get("temp", false) and c.state == "patrol":
				npcs.remove_cop(c)
				break
	elif cnt > want and not S.wanted:
		for c in npcs.cops:
			if not c.post and not c.get("temp", false) and c.state == "patrol" and (player.loc != "out" or Vector2(c.x - pp.x, c.z - pp.z).length() > 70.0):
				npcs.remove_cop(c)
				break
	if S.invest >= 60.0 and post == null and not S.wanted:
		var c: Dictionary = npcs.spawn_cop(false)
		c.post = true
		c.state = "post"
		c.x = 15.5 * D.SC
		c.z = -69.5 * D.SC
		c.node.rotation.y = atan2(float(D.DOORS.safe.x) - float(c.x), float(D.DOORS.safe.z) - float(c.z))
		G.chat("stas", "Kuba, uważaj. Pod twoją klatką stoi mundurowy i się rozgląda. Nie wynoś nic, póki nie odpuszczą.")
	elif S.invest < 45.0 and post != null and post.state == "post":
		npcs.remove_cop(post)
		G.notify("Policja zdjęła obserwację Twojego bloku.", "good")


# ================================================================ narzędzia testowe
## argumenty po „--”: --autostart --loc=out --pos=x,z --yaw=stopnie --hour=22 --shot=plik.png …
## kamera filmowa (zwiastun, zrzuty): punkt w układzie projektu + wysokość nad terenem
func _cine_pt(x: float, z: float, h: float) -> Vector3:
	return Vector3(x * D.SC, world.height(x * D.SC, z * D.SC) + h, z * D.SC)


func cine_cam(pos: Vector3, target: Vector3, fov := 62.0) -> void:
	if cine == null:
		cine = Camera3D.new()
		cine.far = 700.0
		cine.near = 0.08
		add_child(cine)
	cine.fov = fov
	cine.global_position = pos
	if pos.distance_to(target) > 0.01:
		cine.look_at(target, Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	cine.current = true


## czy obraz idzie z kamery filmowej (przerywnik, scena w łóżku), a nie z oczu gracza
func cine_active() -> bool:
	return cine != null and cine.current


func cine_off() -> void:
	if cine != null:
		cine.current = false
		player.cam.current = true


func _apply_test_args() -> void:
	var S: Dictionary = G.S
	if args.has("hour"):
		S.t = float(args.hour) * 60.0
	if args.has("cash"):
		S.cash = float(args.cash)
	if args.has("heat"):
		S.heat = float(args.heat)
	if args.has("lvl"):
		S.lvl = int(args.lvl)
		S.xp = float(D.XP_LEVELS[int(args.lvl) - 1]) + 5.0
		S.sp = int(args.lvl) - 1
	if args.has("step"):
		S.step = int(args.step) + G.TOUR_STEPS
		G.tour_skip()
		S.flags["wiktor_sms"] = true
		S.flags["read_wiktor"] = true
		S.flags["got_first"] = true
		S.flags["hurt_on"] = true
		S.flags["met_stasiu"] = true
		S.cust.dominik.unlocked = true
	if args.has("give"):
		G.add_pack(S.inv, "dym", 80, int(args.give))
		G.add_bulk(S.inv, "dym", 75, 6.0)
	if args.has("own"):
		S.props["garaz"] = true
		S.hide.garage.items = [{"f": "stol", "x": -1.6, "z": -3.6, "r": 0}, {"f": "regal", "x": 2.3, "z": -3.9, "r": 0}, {"f": "lampa_led", "x": 2.0, "z": -1.2, "r": 0}, {"f": "kanapa", "x": -2.4, "z": 0.6, "r": 1}, {"f": "lampa", "x": 0.2, "z": -4.1, "r": 0}]
		S.hide.garage["pots"] = [{"x": 1.6, "z": -1.2, "pl": null}, {"x": 2.1, "z": -1.2, "pl": null}]
		world.refresh_furniture("garage")
	if args.has("prod"):
		# kryjówka z pełną linią produkcyjną w różnych fazach (zrzuty ekranu)
		S.props["garaz"] = true
		S.lvl = maxi(int(S.lvl), 8)
		S.items["nasiona"] = 3
		S.items["nawoz"] = 2
		S.items["chemia"] = 2
		S.items["doniczka"] = 2
		S.hide.garage.items = [{"f": "lampa_led", "x": -1.9, "z": -3.7, "r": 0}, {"f": "lampa_led", "x": -1.9, "z": -2.3, "r": 0}, {"f": "lampa_led", "x": -1.9, "z": -0.9, "r": 0, "mode": 1},
			{"f": "lab", "x": 1.8, "z": -3.8, "r": 0}, {"f": "suszarka", "x": 2.4, "z": -1.9, "r": 0}, {"f": "zbiornik", "x": 2.5, "z": -0.6, "r": 0}, {"f": "filtr", "x": 2.5, "z": 0.6, "r": 0},
			{"f": "stol", "x": -1.9, "z": 1.2, "r": 0}, {"f": "regal", "x": 2.4, "z": 2.2, "r": 1}]
		var PR = G.Prod
		var hd0: Dictionary = PR.hide("garage")
		hd0.pots.clear()
		# trzy rzędy pod lampami w różnych fazach + dwie doniczki bez światła
		var rows := [[-3.7, 0.97, false, 64.0], [-2.3, 0.42, true, 40.0], [-0.9, 0.1, false, 85.0]]
		for ri in range(rows.size()):
			for k in range(4):
				var pl0: Dictionary = PR.plant_new()
				pl0.prog = minf(1.0, float(rows[ri][1]) + k * 0.015)
				pl0.fert = bool(rows[ri][2])
				pl0.water = float(rows[ri][3]) - k * 12.0
				pl0.lit_t = 1.0
				pl0.grow_t = 1.0
				hd0.pots.append({"x": -2.5 + k * 0.42, "z": float(rows[ri][0]) + (0.2 if k % 2 == 0 else -0.2), "pl": pl0})
		hd0.pots.append({"x": 0.4, "z": 3.0, "pl": null})
		var plx: Dictionary = PR.plant_new()
		plx.prog = 0.5
		plx.water = 0.0
		plx.health = 38.0
		hd0.pots.append({"x": 1.0, "z": 3.0, "pl": plx})
		hd0.jobs["3"] = PR.new_job("amfetamina", 1)
		hd0.jobs["3"].prog = 0.3
		hd0.jobs["4"] = {"r": "_dry", "p": "dym", "g": 34.0, "pur": 75, "prog": 0.6}
		if args.has("care"):
			# podgląd animacji doglądania: --care=water|fert|cut|seed  --carepot=nr
			get_tree().create_timer(float(args.get("carewait", "0.6"))).timeout.connect(func():
				G.test_mode = false
				care.play(String(args.care), "garage", int(args.get("carepot", "5")))
				G.test_mode = true)
		world.refresh_furniture("garage")
	if args.has("rain"):
		S.weather = {"start": 0.0, "end": 1e12, "power": float(args.rain)}
		env.rain = float(args.rain)
		env.wet = 1.0
	var loc := String(args.get("loc", player.loc))
	if args.has("pos") or args.has("loc"):
		var pos := player.global_position
		if args.has("pos"):
			var p := String(args.pos).split(",")
			pos = Vector3(float(p[0]) * D.SC, 0.0, float(p[1]) * D.SC)
			if loc != "out":
				# we wnętrzach: metry względem środka pokoju
				pos = Vector3(float(D.ROOMS[loc].cx) + float(p[0]), 0.0, float(p[1]))
		elif loc == "out":
			pos = Vector3(float(D.DOORS.safe.x), 0.0, float(D.DOORS.safe.z) + 2.0)
		else:
			pos = Vector3(float(D.ROOMS[loc].cx), 0.0, float(D.ROOMS[loc].d) * 0.5 - 1.5)
		teleport(loc, pos, deg_to_rad(float(args.get("yaw", "0"))))
		# zrzuty: --pitch=stopnie (ujemne = w dół), --waga=0…3 (klasa wagi na stołach)
		if args.has("pitch"):
			player.pitch = deg_to_rad(float(args.pitch))
		if args.has("waga"):
			G.S["scale"] = int(args.waga)
			world.refresh_scales()
	elif args.has("yaw"):
		player.place(player.global_position, deg_to_rad(float(args.yaw)))
	if args.has("pitch"):
		player.pitch = deg_to_rad(float(args.pitch))
	if args.has("flash"):
		player.flash.light_energy = 5.0
	# strojenie grafiki z wiersza poleceń (pomiary wydajności)
	var vp0 := get_viewport()
	if args.has("scale"):
		vp0.scaling_3d_scale = float(args.scale)
	if args.has("fsr"):
		vp0.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if int(args.fsr) == 1 else Viewport.SCALING_3D_MODE_BILINEAR
	if args.has("msaa"):
		vp0.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(int(args.msaa), 0, 2)]
	if args.has("fxaa"):
		vp0.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if int(args.fxaa) == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	if args.has("ssao"):
		env.env.ssao_enabled = int(args.ssao) == 1
	if args.has("vfog"):
		env.env.volumetric_fog_enabled = int(args.vfog) == 1
	if args.has("glow"):
		env.env.glow_enabled = int(args.glow) == 1
	if args.has("splits"):
		env.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(args.splits) == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if args.has("resmult"):
		env.res_mult = float(args.resmult)
		env.apply_scale()
	if args.has("nosky"):
		env.env.background_mode = Environment.BG_COLOR
	if args.has("hideterrain"):
		for tn in get_tree().get_nodes_in_group("terrain"):
			(tn as Node3D).visible = false
	if args.has("treelod"):
		var st5: Array = [self]
		while not st5.is_empty():
			var n5: Node = st5.pop_back()
			for ch5 in n5.get_children():
				st5.append(ch5)
			if n5 is MeshInstance3D and (n5 as MeshInstance3D).mesh != null and (n5 as MeshInstance3D).mesh.resource_path.contains("/nature/commontree"):
				(n5 as MeshInstance3D).lod_bias = float(args.treelod)
	if args.has("sunang"):
		env.sun.light_angular_distance = float(args.sunang)
	if args.has("shadowsize"):
		RenderingServer.directional_shadow_atlas_set_size(int(args.shadowsize), true)
	if args.has("shadowdist"):
		env.sun.directional_shadow_max_distance = float(args.shadowdist)
	if args.has("blend"):
		env.sun.directional_shadow_blend_splits = int(args.blend) == 1
	if args.has("softq"):
		RenderingServer.directional_soft_shadow_filter_set_quality(int(args.softq))
	if args.has("treeshadow"):
		var st4: Array = [self]
		while not st4.is_empty():
			var n4: Node = st4.pop_back()
			for ch4 in n4.get_children():
				st4.append(ch4)
			if n4 is MeshInstance3D and (n4 as MeshInstance3D).mesh != null and (n4 as MeshInstance3D).mesh.resource_path.contains("/nature/" + ("" if String(args.treeshadow) == "0" else String(args.treeshadow))):
				(n4 as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if args.has("sunshadow"):
		env.sun.shadow_enabled = int(args.sunshadow) == 1
	if args.has("nolights") or args.has("nolabels") or args.has("noparticles") or args.has("nomm"):
		var st3: Array = [self]
		while not st3.is_empty():
			var nd3: Node = st3.pop_back()
			if args.has("nolights") and nd3 is Light3D and not (nd3 is DirectionalLight3D):
				nd3.visible = false
			if args.has("nolabels") and nd3 is Label3D:
				nd3.visible = false
			if args.has("noparticles") and nd3 is GPUParticles3D:
				nd3.visible = false
			if args.has("nomm") and nd3 is MultiMeshInstance3D:
				nd3.visible = false
			for ch3 in nd3.get_children():
				st3.append(ch3)
	if args.has("noanim"):
		var st2: Array = [self]
		while not st2.is_empty():
			var nd2: Node = st2.pop_back()
			if nd2 is AnimationPlayer:
				nd2.process_mode = Node.PROCESS_MODE_DISABLED
			for ch2 in nd2.get_children():
				st2.append(ch2)
	if args.has("cam"):
		var c := String(args.cam).split(",")
		cine_cam(_cine_pt(float(c[0]), float(c[1]), float(c[2])), _cine_pt(float(c[3]), float(c[4]), float(c[5])), float(args.get("fov", "62")))
	if args.has("nohud"):
		G.test_hide_hud = true
		ui.hud.visible = false
	if args.has("proplod") or args.has("hideprops") or args.has("proprange"):
		# eksperymenty wydajności: ostrzejsze upraszczanie / ukrycie / zasięg modeli z plików
		var st2: Array = [self]
		while not st2.is_empty():
			var n2: Node = st2.pop_back()
			for ch2 in n2.get_children():
				st2.append(ch2)
			var which := String(args.get("hideprops", ""))
			if n2 is MeshInstance3D and (n2 as MeshInstance3D).mesh != null and (n2 as MeshInstance3D).mesh.resource_path.contains(".gltf") and (which == "" or (n2 as MeshInstance3D).mesh.resource_path.contains("/" + which + "/")):
				if args.has("proplod"):
					(n2 as MeshInstance3D).lod_bias = float(args.proplod)
				if args.has("hideprops"):
					(n2 as MeshInstance3D).visible = false
				if args.has("proprange"):
					(n2 as MeshInstance3D).visibility_range_end = float(args.proprange)
	if args.has("wearshot"):
		# podgląd ubrań z bliska: ta sama postać z przodu, z boku i z tyłu (albo zbliżenie: --wearzoom=wysokość)
		var R: Dictionary = D.ROOMS.safe
		teleport("safe", Vector3(float(R.cx), 0.0, 1.5), 0.0)
		var gear := {}
		for gid in String(args.wearshot).split(","):
			if D.ITEMS.has(gid):
				gear[String(D.ITEMS[gid].slot)] = gid
		var zoom_y := float(args.get("wearzoom", "0"))
		var k := 0
		for ry in [0.0, 1.15, PI]:
			var look: Dictionary = D.PLAYER_LOOK.duplicate()
			look["no_blob"] = true
			look["model"] = String(D.OUTFITS[String(args.get("outfit", "dres"))].model)
			look["face"] = String(D.PLAYER_LOOK.model)
			look["tall"] = 1.0
			look["build"] = 1.0
			var rg: Dictionary = Chars.make(look)
			world.rooms.safe.add_child(rg.root)
			rg.root.position = Vector3(float(R.cx) + (k - 1) * (0.5 if zoom_y > 0.0 else 0.85), 0.0, -1.0)
			rg.root.rotation.y = ry
			# --wearspeed=1.4 (chód) / 5 (bieg), --wearpose=sit|crouch… — ubranie w ruchu, nie tylko na stojąco
			Chars.animate(rg, 0.0, float(args.get("wearspeed", "0")), String(args.get("wearpose", "")))
			Chars.dress(rg, gear)
			k += 1
		for lx in [-1.6, 1.6]:
			var wl := OmniLight3D.new()
			wl.position = Vector3(float(R.cx) + lx, 1.9, 1.2)
			wl.light_energy = 1.6
			wl.omni_range = 7.0
			wl.shadow_enabled = false
			world.rooms.safe.add_child(wl)
		if zoom_y > 0.0:
			cine_cam(Vector3(float(R.cx), zoom_y, 0.75), Vector3(float(R.cx), zoom_y, -1.0), 28.0)
		else:
			cine_cam(Vector3(float(R.cx), 1.0, 2.5), Vector3(float(R.cx), 0.93, -1.0), 32.0)
	if args.has("showmodel"):
		# podgląd modeli z Blendera: rząd przed kamerą, z neutralnym światłem (--showmodel=radio,pistolet --showscale=2)
		var names := String(args.showmodel).split(",")
		var fwm: Vector2 = player.forward()
		var rightm := Vector2(-fwm.y, fwm.x)
		var basem: Vector3 = player.global_position + Vector3(fwm.x, 0, fwm.y) * float(args.get("showdist", "1.2"))
		var sc0 := float(args.get("showscale", "1"))
		for mi0 in range(names.size()):
			var mdl: Node3D = Stations.model(names[mi0])
			if mdl == null:
				print("BRAK MODELU ", names[mi0])
				continue
			add_child(mdl)
			var offm := (mi0 - (names.size() - 1) * 0.5) * float(args.get("showgap", "0.6"))
			mdl.global_position = basem + Vector3(rightm.x, 0, rightm.y) * offm + Vector3(0, float(args.get("showy", "1.1")), 0)
			mdl.rotation.y = player.yaw + float(args.get("showrot", "0.6"))
			mdl.scale = Vector3.ONE * sc0
		var lm := OmniLight3D.new()
		lm.light_energy = 2.2
		lm.omni_range = 5.0
		add_child(lm)
		lm.global_position = player.global_position + Vector3(0, 1.9, 0)
	if args.has("treelist"):
		# najbliższe drzewa z liśćmi (pozycje w jednostkach projektu, do --pos)
		var found: Array = []
		var st6: Array = [self]
		while not st6.is_empty():
			var n6: Node = st6.pop_back()
			for ch6 in n6.get_children():
				st6.append(ch6)
			if n6 is MeshInstance3D and String(n6.name) == "cien":
				var gp: Vector3 = (n6 as MeshInstance3D).global_position
				found.append([gp.distance_to(player.global_position), gp])
		found.sort_custom(func(a, b): return a[0] < b[0])
		for i6 in range(mini(12, found.size())):
			print("TREE %.1f m  pos=%.1f,%.1f" % [found[i6][0], found[i6][1].x / D.SC, found[i6][1].z / D.SC])
	if args.has("tridump"):
		# co w promieniu `tridump` metrów od kamery ma najwięcej trójkątów (szukanie ciężkich miejsc)
		var rad := float(args.tridump)
		var cp: Vector3 = player.global_position
		var agg := {}
		var cache := {}
		var stack: Array = [self]
		while not stack.is_empty():
			var nd: Node = stack.pop_back()
			for ch in nd.get_children():
				stack.append(ch)
			var mesh: Mesh = null
			var inst := 1
			var pos := Vector3.ZERO
			if nd is MeshInstance3D and (nd as MeshInstance3D).is_visible_in_tree():
				mesh = (nd as MeshInstance3D).mesh
				pos = (nd as MeshInstance3D).global_position
			elif nd is MultiMeshInstance3D and (nd as MultiMeshInstance3D).is_visible_in_tree() and (nd as MultiMeshInstance3D).multimesh != null:
				mesh = (nd as MultiMeshInstance3D).multimesh.mesh
				inst = (nd as MultiMeshInstance3D).multimesh.instance_count
				pos = (nd as MultiMeshInstance3D).global_position
			if mesh == null:
				continue
			if not (nd is MultiMeshInstance3D) and Vector2(pos.x - cp.x, pos.z - cp.z).length() > rad:
				continue
			var id := mesh.get_instance_id()
			if not cache.has(id):
				cache[id] = int(mesh.get_faces().size() / 3.0)
			var owner_name := String(nd.name)
			var par := nd.get_parent()
			var key := "%s <%s> %s" % [mesh.resource_path.get_file() if mesh.resource_path != "" else mesh.get_class(), owner_name.left(24), String(par.name).left(18) if par != null else ""]
			if nd is MultiMeshInstance3D:
				key = "MM " + key
			if not agg.has(key):
				agg[key] = [0, 0]
			agg[key][0] += int(cache[id]) * inst
			agg[key][1] += inst
		var rows: Array = []
		for k2 in agg:
			rows.append([agg[k2][0], agg[k2][1], k2])
		rows.sort_custom(func(a, b): return a[0] > b[0])
		for i2 in range(mini(28, rows.size())):
			print("TRI %8d  x%-5d %s" % [rows[i2][0], rows[i2][1], rows[i2][2]])
	if args.has("uidump"):
		# duże, widoczne elementy interfejsu (szukanie kosztownego nakładania się warstw)
		await get_tree().create_timer(1.0).timeout
		var scr: Vector2 = get_viewport().get_visible_rect().size
		var st7: Array = [ui]
		var total := 0.0
		while not st7.is_empty():
			var n7: Node = st7.pop_back()
			if n7 is CanvasItem and not (n7 as CanvasItem).visible:
				continue
			for ch7 in n7.get_children():
				st7.append(ch7)
			if n7 is Control:
				var c7: Control = n7
				var ar := c7.get_global_rect().size.x * c7.get_global_rect().size.y / (scr.x * scr.y)
				var draws := c7 is ColorRect or c7 is Panel or c7 is PanelContainer or c7 is TextureRect or c7 is NinePatchRect or c7.material != null or c7.clip_contents
				if ar > 0.15 and draws:
					total += ar
					var extra := ""
					if c7 is ColorRect:
						extra = " color=%s" % (c7 as ColorRect).color
					if c7 is TextureRect and (c7 as TextureRect).texture != null:
						extra = " tex=%s" % (c7 as TextureRect).texture.get_size()
					print("UIBIG %.2f %s <%s> mod=%s mat=%s clip=%s%s  %s" % [ar, c7.get_class(), c7.name, c7.modulate, c7.material != null, c7.clip_contents, extra, String(c7.get_path()).right(70)])
		print("UIBIG total area = %.1f screens" % total)
		var st8: Array = [[ui, 0]]
		while not st8.is_empty():
			var e8: Array = st8.pop_back()
			var n8: Node = e8[0]
			if n8 is CanvasItem and not (n8 as CanvasItem).visible:
				continue
			var info := ""
			if n8 is Control:
				info = " %s mat=%s" % [(n8 as Control).get_global_rect().size, (n8 as Control).material != null]
			print("UITREE %s%s <%s>%s" % ["  ".repeat(int(e8[1])), n8.get_class(), n8.name, info])
			if int(e8[1]) < 4:
				for ch8 in n8.get_children():
					st8.append([ch8, int(e8[1]) + 1])
	if args.has("drawtest"):
		# który rodzaj rysowania 2D co klatkę wstrzymuje kartę graficzną (pomiar: --bench)
		var kind := String(args.drawtest)
		var cv := Control.new()
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex0: Texture2D = load("res://assets/icons/eye.png") if ResourceLoader.exists("res://assets/icons/eye.png") else null
		cv.draw.connect(func():
			var c := Vector2(300, 300)
			match kind:
				"circle": cv.draw_circle(c, 6.0, Color.WHITE)
				"circle_aa": cv.draw_circle(c, 6.0, Color.WHITE, true, -1.0, true)
				"arc": cv.draw_arc(c, 20.0, 0.0, 2.0, 14, Color.WHITE, 3.0, false)
				"arc_aa": cv.draw_arc(c, 20.0, 0.0, 2.0, 14, Color.WHITE, 3.0, true)
				"line": cv.draw_line(c, c + Vector2(40, 10), Color.WHITE, 3.0, false)
				"line_aa": cv.draw_line(c, c + Vector2(40, 10), Color.WHITE, 3.0, true)
				"rect": cv.draw_rect(Rect2(c, Vector2(20, 20)), Color.WHITE)
				"rect_out": cv.draw_rect(Rect2(c, Vector2(20, 20)), Color.WHITE, false, 2.0)
				"poly": cv.draw_colored_polygon(PackedVector2Array([c, c + Vector2(20, 0), c + Vector2(10, 20)]), Color.WHITE)
				"polyline": cv.draw_polyline(PackedVector2Array([c, c + Vector2(20, 0), c + Vector2(10, 20)]), Color.WHITE, 2.0)
				"polyline1": cv.draw_polyline(PackedVector2Array([c, c + Vector2(20, 0), c + Vector2(10, 20)]), Color.WHITE)
				"multiline": cv.draw_multiline(PackedVector2Array([c, c + Vector2(20, 0), c + Vector2(10, 20), c + Vector2(30, 20)]), Color.WHITE, 2.0)
				"primitive": cv.draw_primitive(PackedVector2Array([c, c + Vector2(20, 0), c + Vector2(10, 20)]), PackedColorArray([Color.WHITE]), PackedVector2Array())
				"string": cv.draw_string(ThemeDB.fallback_font, c, "Test %d" % Engine.get_frames_drawn())
				"tex":
					if tex0 != null:
						cv.draw_texture(tex0, c)
				"stylebox":
					var sbx := StyleBoxFlat.new()
					sbx.bg_color = Color.WHITE
					sbx.set_corner_radius_all(6)
					cv.draw_style_box(sbx, Rect2(c, Vector2(60, 30)))
				"stylebox0":
					var sb0 := StyleBoxFlat.new()
					sb0.bg_color = Color.WHITE
					sb0.anti_aliasing = false
					cv.draw_style_box(sb0, Rect2(c, Vector2(60, 30)))
				"kit":
					# wszystkie zamienniki z uikit naraz, ze zmiennymi rozmiarami
					var ph := float(Engine.get_frames_drawn() % 60) / 60.0
					K.circle(cv, c, 4.0 + ph * 30.0, Color(1, 1, 1, 0.5))
					K.ring(cv, c + Vector2(80, 0), 4.5, Color.WHITE, 1.4)
					K.arc(cv, c + Vector2(160, 0), 30.0, 0.0, TAU * ph, 20, Color.WHITE, 4.0)
					K.polyline(cv, PackedVector2Array([c + Vector2(0, 80), c + Vector2(60, 90 + ph * 20.0), c + Vector2(120, 80)]), Color.WHITE, 5.0)
					K.poly(cv, PackedVector2Array([c + Vector2(200, 80), c + Vector2(240, 90), c + Vector2(215, 100), c + Vector2(230, 130)]), Color.WHITE)
					K.rbox(cv, Rect2(c + Vector2(0, 150), Vector2(120 + ph * 80.0, 40)), Color(0.1, 0.1, 0.14), 8, Color.WHITE, 1)
				"ninepatch":
					cv.draw_style_box(K.pill(Color.WHITE, 4), Rect2(c, Vector2(60 + Engine.get_frames_drawn() % 30, 8)))
				_: pass
		)
		ui.hud.add_child(cv)
		set_meta("drawtest", cv)
		if kind == "progress":
			var pb := K.bar(0.0, 100.0)
			pb.custom_minimum_size = Vector2(200, 8)
			pb.position = Vector2(300, 300)
			pb.size = Vector2(200, 8)
			cv.add_child(pb)
			set_meta("drawtest_pb", pb)
	if args.has("uilist"):
		var rc: Node = ui.get_child(0) if ui.get_child_count() > 0 else ui
		for i9 in range(rc.get_child_count()):
			var c9: Node = rc.get_child(i9)
			print("UICH %d %s <%s> vis=%s kids=%d script=%s" % [i9, c9.get_class(), c9.name, (c9 as CanvasItem).visible if c9 is CanvasItem else true, c9.get_child_count(), c9.get_script() != null])
			if c9.get_child_count() > 4 and c9 is Control and (c9 as Control).visible:
				for j9 in range(c9.get_child_count()):
					var d9: Node = c9.get_child(j9)
					print("UICH    %d.%d %s <%s> vis=%s kids=%d" % [i9, j9, d9.get_class(), d9.name, (d9 as CanvasItem).visible if d9 is CanvasItem else true, d9.get_child_count()])
	if args.has("uihide"):
		# ukrywa wskazane (numerami) dzieci głównego kontenera interfejsu — do szukania kosztownego elementu
		var root_c: Node = ui.get_child(0) if ui.get_child_count() > 0 else ui
		for part in String(args.uihide).split(","):
			var seg := part.split(".")
			var ix := int(seg[0])
			if ix >= 0 and ix < root_c.get_child_count() and root_c.get_child(ix) is CanvasItem:
				var tgt: Node = root_c.get_child(ix)
				if seg.size() > 1 and int(seg[1]) < tgt.get_child_count():
					tgt = tgt.get_child(int(seg[1]))
				if tgt is CanvasItem:
					(tgt as CanvasItem).visible = false
	if args.has("noui"):
		# czysty kadr do grafik: bez całego interfejsu (także pasów przerywnika)
		G.test_hide_hud = true
		ui.visible = false
	if args.has("train"):
		world.train.wait = 0.0
		world.tick_train(0.01, env.night if "night" in env else 0.0)
		world.train.x = float(args.train) * float(world.train.dir)
	if args.has("walkers"):
		var fw: Vector2 = player.forward()
		var rt := Vector2(-fw.y, fw.x)
		var pp0 := player.global_position
		var looks := [{"kind": "dres", "top": "101114", "top2": "e8e6e0", "bottom": "101114", "stripes": true, "seed": 1}, {"kind": "jacket", "top": "6b5a45", "bottom": "3b3630", "seed": 2},
			{"female": true, "kind": "jacket", "top": "3a3f4a", "bottom": "101114", "seed": 3}, {"kind": "hoodie", "top": "3a3f4a", "bottom": "1b2538", "seed": 4},
			{"kind": "tshirt", "top": "c9c4b8", "bottom": "2e3440", "seed": 5}, {"female": true, "kind": "hoodie", "top": "5a2f52", "bottom": "232a36", "seed": 6}, {"kind": "jacket", "top": "23402e", "bottom": "45423c", "seed": 7}]
		var wl := ["Walk_Swagger", "Walk_Hunched", "Walk_Phone", "Walk_Folded", "Walk_Stiff", "Walk_Loose", "Walk"]
		for i in range(wl.size()):
			var lk: Dictionary = looks[i].duplicate()
			lk["walk"] = wl[i]
			var wr: Dictionary = Chars.make(lk)
			add_child(wr.root)
			var p3 := Vector2(pp0.x, pp0.z) + fw * float(args.walkers) + rt * (i - 3.0) * 0.95
			wr.root.position = Vector3(p3.x, world.height(p3.x, p3.y), p3.y)
			wr.root.rotation.y = atan2(pp0.x - p3.x, pp0.z - p3.y) + 0.5
			Chars.animate(wr, 0.0, 1.2, "")
			wr.anim.seek(0.35 + i * 0.07, true)
	if args.has("cop"):
		# patrol przed graczem (--cop=odległość, --copturn=obrót względem „twarzą do gracza”) — do oglądania latarki i łuków
		while npcs.cops.is_empty():
			npcs.spawn_cop(false)
		var tc: Dictionary = npcs.cops[0]
		var fw2: Vector2 = player.forward()
		var side := Vector2(-fw2.y, fw2.x) * float(args.get("copside", "0"))
		tc.x = player.global_position.x + fw2.x * float(args.cop) + side.x
		tc.z = player.global_position.z + fw2.y * float(args.cop) + side.y
		tc.idle = 9999.0
		tc.state = "patrol"
		tc.node.rotation.y = atan2(-fw2.x, -fw2.y) + float(args.get("copturn", "0"))
		if args.has("coparmed"):
			# podgląd uzbrojonego patrolu: stan przeszukiwania trzyma broń w dłoni
			tc.hunt = true
		if args.has("mult"):
			G.add_pack(G.S.inv, "dym", 80, 5)
			G.S.heat = 90.0
	if args.has("doorpack"):
		# podgląd paczki na start: 0…1 = ile wsunięta pod drzwi kawalerki
		G.S.flags["wiktor_sms"] = true
		world.refresh_starter()
		var kk := float(args.doorpack)
		world.starter_rest(minf(1.0, kk * 1.4), clampf(kk * 2.0 - 1.0, 0.0, 1.0))
		var RD: Dictionary = D.ROOMS.safe
		var dcx := float(RD.cx)
		var dez := float(RD.d) * 0.5
		cine_cam(Vector3(dcx + 0.46, 0.13, dez - 1.38).lerp(Vector3(dcx + 0.27, 0.085, dez - 1.02), kk), Vector3(dcx + 0.03, 0.03, dez - 0.52), lerpf(34.0, 30.0, kk))
	if args.has("hide"):
		var hh: Dictionary = world.hides[int(args.hide) % world.hides.size()]
		var hf := Vector2(sin(float(hh.rot) + PI), cos(float(hh.rot) + PI))
		teleport("out", Vector3(float(hh.ox) + hf.x * 5.0 + 2.0, 0.0, float(hh.oz) + hf.y * 5.0), atan2(hf.x, hf.y) + 0.3)
		print("HIDES ", world.hides.size(), " ", hh)
	if args.has("cars"):
		# rząd aut każdego rodzaju przed graczem (do oglądania modeli)
		var pp0 := player.global_position
		var f0: Vector2 = player.forward()
		var r0 := Vector2(-f0.y, f0.x)
		var types := ["maluch", "hatch", "sedan", "kombi", "van", "sedan"]
		var cols := ["c9a23a", "8a1c1c", "28424f", "d9dcdf", "5a6068", "ffffff"]
		for i in range(types.size()):
			var cn: Node3D = Models.car(types[i], cols[i], i == 5)
			add_child(cn)
			var off := (i - 2.5) * 2.6
			var p2 := Vector2(pp0.x, pp0.z) + f0 * float(args.cars) + r0 * off
			cn.position = Vector3(p2.x, world.height(p2.x, p2.y), p2.y)
			cn.rotation.y = float(args.get("turn", "0.6")) + atan2(f0.x, f0.y) + PI
	if args.has("chars"):
		var Chars = load("res://scripts/chars.gd")
		var pp := player.global_position
		var f: Vector2 = player.forward()
		var r := Vector2(-f.y, f.x)
		var defs := [
			{"kind": "dres", "top": "101114", "top2": "e8e6e0", "bottom": "101114", "stripes": true, "hair": "hair_buzzed", "seed": 1},
			{"kind": "hoodie", "top": "3a3f4a", "bottom": "1b2538", "hat": "beanie", "beard": true, "seed": 2},
			{"female": true, "kind": "jacket", "top": "5a2f52", "bottom": "101114", "seed": 3},
			{"kind": "police", "top": "c8e020", "top2": "141c30", "bottom": "141c30", "shoes": "0c0c0e", "hat": "police", "seed": 4},
			{"kind": "tshirt", "top": "c9c4b8", "bottom": "2e3440", "hat": "cap", "seed": 5, "build": 1.15},
			{"female": true, "kind": "hoodie", "top": "23402e", "bottom": "232a36", "hair": "hair_buns", "seed": 6},
		]
		var poses := ["", "arms", "phone", "arms", "talk", ""]
		var anims: PackedStringArray = String(args.get("anims", "")).split(",", false)
		if args.has("models"):
			# rząd wskazanych modeli (people.gd), każdy z wybraną animacją: --models=m10,m10 --anims=Idle,Walk --seek=0.4
			defs = []
			var k := 0
			for m in String(args.models).split(",", false):
				defs.append({"model": m, "seed": 10 + k, "female": m.begins_with("f")})
				k += 1
		var turn := float(args.get("turn", "0"))
		for i in range(defs.size()):
			var rig: Dictionary = Chars.make(defs[i])
			add_child(rig.root)
			var off := (i - (defs.size() - 1) * 0.5) * float(args.get("gap", "0.85"))
			var p2 := Vector2(pp.x, pp.z) + f * (float(args.chars) + absf(off) * 0.2) + r * off
			rig.root.position = Vector3(p2.x, world.height(p2.x, p2.y), p2.y)
			rig.root.rotation.y = atan2(pp.x - p2.x, pp.z - p2.y) + turn
			if i < anims.size():
				rig.cur = anims[i]
				rig.anim.play(anims[i], 0.0)
				rig.anim.seek(float(args.get("seek", "0.4")) * rig.anim.current_animation_length, true)
				if args.has("freeze"):
					rig.anim.speed_scale = 0.0
			else:
				Chars.animate(rig, 0.0, 0.0, poses[i % poses.size()])


func _test_order(cid: String, accept := true) -> Dictionary:
	G.unlock_client(cid)
	var o: Dictionary = G.make_order(G.cust_def(cid))
	if accept:
		G.reply_order(o.id, "accept")
	return o


## Przegląd układu interfejsu bez okna. Silnik liczy rozmiary i pozycje kontrolek także bez karty graficznej, więc
## da się sprawdzić, czy coś nie wychodzi poza ekran, nie wystaje z panelu albo czy tekst nie jest ucięty.
func _ui_audit(what: String) -> void:
	# bez okna ekran bywa kwadratowy — układ ma być liczony dla zwykłego 16:9
	var res := String(args.get("res", "1280x720")).split("x")
	get_window().size = Vector2i(int(res[0]), int(res[1]))
	for i in range(8):
		await get_tree().process_frame
	_test_ui(what)
	for i in range(int(args.get("frames", "10"))):
		await get_tree().process_frame
	var vp := get_viewport().get_visible_rect()
	var out: Array = []
	var stats := {"n": 0, "text": 0}
	_ui_walk(ui, vp, out, false, stats)
	for l in out:
		print("UI %s: %s" % [what, l])
	if args.has("uitekst"):
		_ui_list(ui, 0)
	print("UI %s: %d uwag (%d kontrolek, %d z tekstem, ekran %dx%d, otwarte: %s)" % [what, out.size(), stats.n, stats.text, int(vp.size.x), int(vp.size.y), str(ui.is_open())])
	get_tree().quit()


## wypisuje wszystkie widoczne napisy okna z pozycjami (--uitekst) — tak „czyta się” interfejs bez ekranu
func _ui_list(n: Node, depth: int) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control:
		var c := n as Control
		var txt := _ui_text(c).strip_edges().replace("\n", " / ")
		if txt != "":
			var r := c.get_global_rect()
			print("UI-L %4d,%4d %4dx%-3d %s: %s" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y), c.get_class(), txt.left(90)])
	for ch in n.get_children():
		_ui_list(ch, depth + 1)


func _ui_text(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is LineEdit:
		return (c as LineEdit).text
	return ""


func _ui_walk(n: Node, vp: Rect2, out: Array, scrolled: bool, stats: Dictionary) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control:
		var c := n as Control
		if c.modulate.a < 0.05 or c.self_modulate.a < 0.02 and c.get_child_count() == 0:
			return
		stats.n = int(stats.n) + 1
		var r := c.get_global_rect()
		var txt := _ui_text(c).strip_edges().replace("\n", " / ")
		var name_s := "%s „%s”" % [c.get_class(), txt.left(40)] if txt != "" else "%s %s" % [c.get_class(), String(c.name)]
		var where := "(%d,%d %dx%d)" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]
		if txt != "":
			stats.text = int(stats.text) + 1
			if not scrolled and r.size.x > 0.0 and (r.position.x < vp.position.x - 2.0 or r.end.x > vp.end.x + 2.0 or r.position.y < vp.position.y - 2.0 or r.end.y > vp.end.y + 2.0):
				out.append("POZA EKRANEM %s %s" % [name_s, where])
			if c is Label:
				var lb := c as Label
				if lb.autowrap_mode == TextServer.AUTOWRAP_OFF and not lb.clip_text and lb.get_minimum_size().x > lb.size.x + 1.5:
					out.append("TEKST SZERSZY NIŻ POLE %s %s potrzeba %d" % [name_s, where, int(lb.get_minimum_size().x)])
				if lb.get_line_count() > lb.get_visible_line_count() and lb.max_lines_visible < 0:
					out.append("TEKST UCIĘTY (%d z %d wierszy) %s %s" % [lb.get_visible_line_count(), lb.get_line_count(), name_s, where])
			elif c is Button:
				var bt := c as Button
				var f := bt.get_theme_font("font")
				var fs := bt.get_theme_font_size("font_size")
				var widest := 0.0
				for line in bt.text.split("\n"):
					widest = maxf(widest, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				if widest > bt.size.x - 4.0 and bt.autowrap_mode == TextServer.AUTOWRAP_OFF:
					out.append("NAPIS NIE MIEŚCI SIĘ W PRZYCISKU %s %s napis %d" % [name_s, where, int(widest)])
			elif c is RichTextLabel:
				var rt := c as RichTextLabel
				if not rt.scroll_active and not rt.fit_content and rt.get_content_height() > rt.size.y + 2.0:
					out.append("TEKST WYŻSZY NIŻ POLE %s %s treść %d" % [name_s, where, rt.get_content_height()])
		# zawartość wystająca z panelu z tłem
		var par := c.get_parent()
		if not scrolled and par is PanelContainer and r.size.x > 0.0:
			var pr := (par as Control).get_global_rect()
			if r.position.x < pr.position.x - 3.0 or r.end.x > pr.end.x + 3.0 or r.position.y < pr.position.y - 3.0 or r.end.y > pr.end.y + 3.0:
				out.append("WYSTAJE Z PANELU %s %s, panel (%d,%d %dx%d)" % [name_s, where, int(pr.position.x), int(pr.position.y), int(pr.size.x), int(pr.size.y)])
	var sc := scrolled or n is ScrollContainer or (n is Control and (n as Control).clip_contents)
	for ch in n.get_children():
		_ui_walk(ch, vp, out, sc, stats)


func _test_ui(what: String) -> void:
	if what == "call" or what == "call2":
		G.test_mode = false
		ui.call_start("Wiktor", ["Kuba. Za kwadrans piąta, a ja jeszcze nie śpię — zgadnij przez kogo.", {"n": "Ty", "t": "Pół kilo jest spakowane."}])
		G.test_mode = true
		if what == "call2":
			get_tree().create_timer(1.0).timeout.connect(ui.call_answer)
		return
	match what:
		"home": ui.open_phone("")
		"gielda", "gielda_chat", "sklep":
			G.S.flags["hurt_on"] = true
			G.S.lvl = int(args.get("lvl", "3"))
			G.chat("wiktor", "Pisz, co ci potrzeba.", false, true)
			ui.open_phone("sms")
			ui.phone.chat_id = "wiktor"
			ui.phone.render()
			if what != "gielda_chat":
				ui.phone.shop.cart = [{"p": "dym", "g": 10}, {"p": "szron", "g": 5}]
				ui.phone.shop_open()
		"options": ui.open_options("pause")
		"options_audio":
			ui.opts.tab = "audio"
			ui.open_options("pause")
		"options_keys":
			ui.opts.tab = "keys"
			ui.open_options("pause")
		"controls": ui.show_controls()
		"pause": ui.show_pause()
		"sms":
			_test_order("dominik", false)
			ui.open_phone("sms")
		"chat":
			_test_order("dominik", false)
			ui.open_phone("sms")
			ui.phone.chat_id = "dominik"
			ui.phone.render()
		"mapa_route":
			var mo := _test_order("dominik")
			if args.has("spot"):
				mo.spot = String(args.spot)
			set_track(int(mo.id))
			refresh_nav()
			ui.open_phone("mapa")
		"chat_nego", "chat_time", "chat_ok", "chat_swap":
			var co := _test_order("dominik", what == "chat_ok")
			ui.open_phone("sms")
			ui.phone.chat_id = "dominik"
			if what == "chat_nego":
				ui.phone.nego = int(co.id)
				ui.phone.nego_price = G.order_sum(co) + 20
			elif what == "chat_time":
				ui.phone.retime = int(co.id)
			elif what == "chat_swap":
				G.S.lvl = maxi(int(G.S.lvl), 4)
				G.add_pack(G.S.inv, "szron", 100, 6)
				ui.phone.swap = int(co.id)
			ui.phone.render()
		"kontakty":
			G.unlock_client("seba")
			G.S.cust.dominik.deals = 4
			G.S.cust.dominik.known = {"like": "luz"}
			ui.open_phone("kontakty")
			ui.phone.contact_id = "dominik"
			ui.phone.render()
		"mapa", "portfel", "rozwoj", "zadania", "lokale", "plecak", "ustawienia": ui.open_phone(what)
		"gielda", "gielda2":
			G.S.flags["hurt_on"] = true
			G.S.lvl = 6
			G.Market.add_trust("wiktor", 46.0)
			G.add_bulk(G.S.inv, "dym", 100, 64.0)
			ui.open_phone("sms")
			ui.phone.chat_id = "wiktor"
			ui.phone.shop_open()
			if what == "gielda2":
				ui.phone.shop.tab = "sell"
				ui.phone.render()
		"bench":
			if G.pack_limit("safe", "dym", 100) <= 0:
				G.add_bulk(G.S.inv, "dym", 100, 8.0)
			ui.open_pack(player.loc if player.loc != "out" else "safe")
		"station0", "station1", "station2", "station3", "station4", "station9": ui.open_station("garage", int(what.trim_prefix("station")))
		"hideout": ui.open_hideout("garage")
		"kryjowka", "labui":
			# zrzut: urządzony garaż z laboratorium (stół roboczy, stół laboratoryjny, regał, lampa, filtr, suszarka);
			# "labui" otwiera od razu okno stołu laboratoryjnego
			G.S.lvl = 10
			G.S.cash = 90000.0
			G.buy_property("garaz")
			for fd in [["stol", -1.6, -3.6, 0], ["lab", 1.4, -3.5, 0], ["regal", 2.3, 1.6, 1], ["filtr", 2.3, -0.9, 0], ["suszarka", -2.2, 1.4, 0], ["lampa", 0.0, -1.0, 0], ["zbiornik", -2.3, -0.9, 0]]:
				G.furn_buy_place("garage", String(fd[0]), float(fd[1]), float(fd[2]), int(fd[3]))
			G.S.items["chemia"] = 6
			# --grow=0..1: lampa LED i pięć doniczek z krzakami na danym etapie wzrostu
			if args.has("grow"):
				G.furn_buy_place("garage", "lampa_led", -0.2, 2.2, 0)
				G.S.items["doniczka"] = 5
				G.S.items["nasiona"] = 5
				for pi in range(5):
					if G.Prod.pot_place("garage", -1.0 + pi * 0.42, 2.2 + (0.25 if pi % 2 == 0 else -0.2)):
						G.Prod.plant_seed("garage", pi)
						var pl: Dictionary = G.Prod.plant_of("garage", pi)
						pl.prog = clampf(float(args.grow) - pi * 0.04, 0.02, 1.0)
						pl.water = 80.0
			world.refresh_furniture("garage")
			var kp := String(args.get("kpos", "-0.4,2.6,0,-8")).split(",")
			teleport("garage", Vector3(float(D.ROOMS.garage.cx) + float(kp[0]), 0.0, float(kp[1])), deg_to_rad(float(kp[2])))
			player.pitch = deg_to_rad(float(kp[3]))
			var its: Array = G.S.hide.garage.items
			for li in range(its.size()):
				if String(its[li].f) == "lab":
					# --cook: synteza w toku (zawartość naczyń i żar pod kolbą)
					if args.has("cook"):
						G.Prod.start("garage", li, "amfetamina")
						world.refresh_furniture("garage")
					if what == "labui":
						ui.open_station("garage", li)
		"bench_work", "bench_mix":
			G.add_bulk(G.S.inv, "dym", 80, 18.0)
			G.S.items["majeranek"] = 6
			ui.open_pack(player.loc if player.loc != "out" else "safe")
			if what == "bench_mix":
				ui.bench.mixing = true
				ui.bench.filler = 4
				ui._render_bench()
			var bv = ui.bench.view
			bv.force_speed = 0.0
			if what == "bench_mix":
				bv.mix(4.0, func(): pass)
				bv.mix_t = 0.45
			else:
				bv.start(8, 1, 0.58, func() -> int: return 1, func(_a: int, _b: int): pass)
				bv.packs = [{"t": 1.0}, {"t": 1.0}, {"t": 1.0}, {"t": 1.0}, {"t": 0.45}]
				bv.pile_g -= 5.0
				bv.spills = [{"p": Vector2(380, 200), "r": 2.5}, {"p": Vector2(402, 208), "r": 2.0}, {"p": Vector2(520, 205), "r": 3.0}]
				bv.job.t = 0.22
				bv.reading = 0.0
		"stash": ui.open_stash("safe")
		"skrzynka":
			# skrzynka Wiktora: gotówka w kieszeni, towar na zeszycie
			G.S.cash = 640.0
			G.S.credit = 420.0
			open_box()
		"inv": ui.open_inventory("")
		"gear":
			# podgląd pól ubioru: część ubrań na postaci, część w plecaku, gotówka w skrytce
			for gid in ["czapka_daszek", "bluza_kaptur", "trampki", "lancuch", "jeansy", "rekawiczki", "okulary", "bojowki"]:
				G.S.items[gid] = 1
			var wear_ids: Array = Array(String(args.wear).split(",")) if args.has("wear") else ["czapka_daszek", "bluza_kaptur", "trampki", "lancuch"]
			for gid2 in wear_ids:
				G.S.items[gid2] = 1
				G.gear_wear(gid2)
			G.S.cash = 1840.0
			G.S.stash.safe.cash = 600.0
			ui.open_inventory("safe")
			# --tab=wear|char: większy podgląd postaci (do oceny ubrań)
			if args.has("tab"):
				ui.inv.tab = String(args.tab)
				ui.inv.render()
				if ui.tip_box != null and is_instance_valid(ui.tip_box):
					ui.tip_box.queue_free()
		"invsel":
			ui.open_stash("safe")
			ui.inv.sel = {"side": "bag", "kind": "pack", "p": "dym", "pur": 80, "id": ""}
			ui.inv.render()
		"invask":
			G.add_bulk(G.S.inv, "dym", 75, 3.5)
			ui.open_stash("safe")
			for te in G.entries(G.S.inv):
				if te.kind == "bulk":
					ui.inv.ask_amount(te, "bag", "stash")
					ui.inv._ask_set(5.5)
		"char": ui.open_inventory("", "char")
		"wear", "wear2", "wear3":
			G.S.cash = 2500.0
			G.S.lvl = 7
			G.S["outfits"] = {"szary": true}
			ui.open_inventory("", "wear")
			ui.inv.wear_sel = {"wear": "biegacz", "wear2": "kominiarka", "wear3": "garnitur"}[what]
			ui.inv.render()
		"czat", "czat2":
			# zrzut: rozmowa z klientem w telefonie — nowe zamówienie z kaflami odpowiedzi ("czat2": negocjacja sumy)
			var co := _test_order("dominik", false)
			ui.open_phone("sms")
			ui.phone.chat_id = "dominik"
			ui.phone.render()
			if what == "czat2" and ui.phone.has_method("reply_mode"):
				ui.phone.reply_mode(String(co.id), "price")
			if ui.tip_box != null and is_instance_valid(ui.tip_box):
				ui.tip_box.queue_free()
		"ciuchy":
			# zrzut: lista zakupów przy lustrze w „Taniej Odzieży” (--lvl=N, --cash=N)
			G.S.cash = float(args.get("cash", "2500"))
			G.S.lvl = int(args.get("lvl", "4"))
			teleport("ciuchy", Vector3(float(D.ROOMS.ciuchy.cx) - 2.0, 0.0, 1.2), 0.0)
			ui.open_inventory("", "wear")
			if ui.tip_box != null and is_instance_valid(ui.tip_box):
				ui.tip_box.queue_free()
			# --try=pole:rzecz,pole:rzecz — przymiarka jak po najechaniu myszą
			for tp in String(args.get("try", "")).split(",", false):
				ui.inv.try_on[tp.get_slice(":", 0)] = tp.get_slice(":", 1)
			ui.inv._dress()
		"org":
			_test_order("dominik")
			ui.open_inventory("", "org")
		"shop": ui.open_shop()
		"wagi": ui.open_scales()
		"lozko":
			# zrzut: kadr z pierwszej rozmowy telefonicznej (Kuba leży w łóżku); --k=0..1 — kadr wstawania
			# --wake=sekunda — kadr przebudzenia (powieki, myśl bohatera)
			if args.has("k"):
				bed_rise(float(args.k))
			elif args.has("wake"):
				ui.cut_begin()
				bed_cam(float(args.wake))
				ui.set_lids(bed_lids(float(args.wake)))
				if float(args.wake) > 2.7:
					ui.cut_line("…Kto do mnie dzwoni?")
			else:
				bed_cam(1.0)
		"tour":
			G.S.flags["got_first"] = true
			G.S.flags["tour_out"] = false
			if G.next_meeting() == null:
				_test_order("dominik")
			teleport("out", Vector3(float(D.DOORS.safe.x), 0.0, float(D.DOORS.safe.z) + 1.2), PI)
			city_tour()
		"paczki":
			# zrzut: ekwipunek z paczkami różnej wagi (woreczki, kostka, cegła)
			G.S.upg["plecak2"] = true
			G.add_pack(G.S.inv, "dym", 100, 6)
			G.add_pack(G.S.inv, "dym", 100, 2, 5)
			G.add_pack(G.S.inv, "szron", 100, 1, 13)
			G.add_pack(G.S.stash.safe, "dym", 100, 1, 250)
			G.add_pack(G.S.stash.safe, "snieg", 90, 1, 500)
			G.add_bulk(G.S.stash.safe, "dym", 100, 40.0)
			ui.open_inventory("safe")
		"zlecenie":
			G.job_new("utarg")
			G.S.stats.earned = float(G.S.stats.earned) + 60.0
			ui.open_phone("zadania")
		"paczka3d":
			# zrzut: paczka od Wiktora na wycieraczce, widziana z góry oczami gracza
			G.S.flags["wiktor_sms"] = true
			G.S.flags["got_first"] = false
			world.refresh_starter()
			teleport("safe", Vector3(float(D.ROOMS.safe.cx) - 0.04, 0.0, float(D.ROOMS.safe.d) * 0.5 - 1.15), PI)
			player.pitch = deg_to_rad(-62.0)
			player.set_crouch(true)
			# --drop=0..1: kadr scenki z klapką na listy (paczka w szczelinie, w locie, na wycieraczce)
			if args.has("drop"):
				world.starter_rest(float(args.drop))
				var dc := door_cam(clampf(float(args.drop) * 1.4, 0.0, 1.0))
				cine_cam(dc[0], dc[1], dc[2])
		"galeria":
			# zrzut: wszyscy mężczyźni z biblioteki postaci w rzędzie na boisku (do wybierania modeli po wyglądzie)
			var ids := ["m01", "m02", "m03", "m04", "m05", "m06", "m07", "m08", "m09", "m10", "m11", "m12", "m13", "m14", "m16", "m17", "m18", "m20", "mb4", "mb7", "mc2", "md1", "mg1"]
			var from := int(args.get("od", "0"))
			for i in range(from, mini(ids.size(), from + 8)):
				var rg: Dictionary = npcs.Chars.make({"model": ids[i], "seed": 5})
				add_child(rg.root)
				var gx := (12.0 + (i - from) * 1.6) * D.SC
				rg.root.position = Vector3(gx, world.height(gx, -52.0 * D.SC), -52.0 * D.SC)
				var gl := Label3D.new()
				gl.text = ids[i]
				gl.font_size = 64
				gl.pixel_size = 0.004
				gl.position = Vector3(0, 2.05, 0)
				gl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				rg.root.add_child(gl)
			teleport("out", Vector3((12.0 + 5.6) * D.SC, 0.0, -52.0 * D.SC + 4.6), 0.0)
			player.pitch = deg_to_rad(-2.0)
		"hurtownia":
			G.S.owned = {"regal": 1}
			ui.open_supply()
		"paczka":
			G.S.flags["got_first"] = false
			ui.open_loot({"kind": "starter"})
		"ziemia":
			G.S.ground = []
			G.ground_add("out", player.global_position.x, player.global_position.z + 0.5, {"kind": "item", "p": "", "pur": 0, "id": "zegarek", "n": 1.0, "name": "Zegarek"})
			G.ground_add("out", player.global_position.x + 0.3, player.global_position.z + 0.5, {"kind": "bulk", "p": "dym", "pur": 100, "id": "", "n": 6.0, "name": "Marihuana"})
			ui.open_loot({"kind": "ground", "rec": G.S.ground[0]})
		"build":
			G.S["owned"] = {"regal": 2, "lampa_led": 1}
			ui.open_build("garage")
		"ghost":
			G.S["owned"] = {"regal": 1}
			build_begin("regal")
		"pause": ui.show_pause()
		"skill": ui.skill_check("Ważenie: 5 g marihuany", 1.0, func(_h): pass)
		"dialog": talk_stasiu()
		"property": ui.open_property("garaz")
		"deal", "deal2", "deal3", "deal4", "deal5", "deal6":
			G.add_pack(G.S.inv, "dym", 100, 6)
			G.add_pack(G.S.inv, "szron", 100, 2)
			if what != "deal" and what != "deal2":
				# zrzut: paczki różnej wagi przy kliencie (woreczki 1, 2 i 5 g, inna czystość, drugi towar)
				G.add_pack(G.S.inv, "dym", 100, 2, 2)
				G.add_pack(G.S.inv, "dym", 100, 1, 5)
				G.add_pack(G.S.inv, "dym", 70, 3, 3)
				G.add_pack(G.S.inv, "szron", 100, 1, 4)
			var o := _test_order("dominik")
			var n: Dictionary = npcs.customers[0]
			if n.node == null:
				npcs._customer_enter(n, true)
				var fw: Vector2 = player.forward()
				n.x = player.global_position.x + fw.x * 1.9
				n.z = player.global_position.z + fw.y * 1.9
				n.node.position = Vector3(n.x, world.height(n.x, n.z), n.z)
			var who: Dictionary = n.def.duplicate()
			who["st"] = G.S.cust[n.def.id]
			ui.open_deal({"who": who, "product": "dym", "grams": int(o.grams), "order": o, "street": true, "npc": n, "agreed": null})
			# deal — pusta taca; deal3 — część towaru na tacy (mniej, niż zamówił); deal4 — z górką; deal2 — po odmowie ceny
			if what == "deal3" and not ui.deal.is_empty():
				G.deal_offer_add(ui.deal, "dym", 100, 2, 1)
				G.deal_offer_add(ui.deal, "dym", 100, 1, 1)
				ui._render_deal()
			if what == "deal4" and not ui.deal.is_empty():
				G.deal_offer_add(ui.deal, "dym", 100, 5, 1)
				G.deal_offer_add(ui.deal, "dym", 100, 1, 1)
				ui._render_deal()
			if what == "deal5" and not ui.deal.is_empty():
				ui.Trade.place(ui, "dym", 100, 1)
			if what == "deal6" and not ui.deal.is_empty():
				_test_drag()
			if what == "deal2" and not ui.deal.is_empty():
				G.deal_autofill(ui.deal)
				G.deal_set(ui.deal, 15)
				G.deal_hand(ui.deal)
				ui._render_deal()


## zrzut/test: prawdziwe przeciągnięcie myszą pierwszej paczki z listy „przy sobie” na tacę (sztuczne zdarzenia wejścia)
func _test_drag() -> void:
	for i in range(6):
		await get_tree().process_frame
	var row: Control = null
	for c in ui.deal_side_body.get_child(1).get_child(0).get_children():
		if c is PanelContainer and (c as Control).modulate.a > 0.9:
			row = c
			break
	if row == null or ui.deal_zone == null:
		print("DRAG brak wiersza albo tacy")
		return
	var a: Vector2 = row.get_global_rect().get_center()
	var b: Vector2 = ui.deal_zone.get_global_rect().get_center() - Vector2(120, 0)
	var k: Vector2 = Vector2(get_window().size) / get_viewport().get_visible_rect().size
	var send := func(ev: InputEvent) -> void:
		Input.parse_input_event(ev)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = a * k
	mb.global_position = a * k
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT
	send.call(mb)
	await get_tree().process_frame
	for i in range(1, 13):
		var mm := InputEventMouseMotion.new()
		var pos := a.lerp(b, i / 12.0) * k
		mm.position = pos
		mm.global_position = pos
		mm.relative = (b - a) * k / 12.0
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		send.call(mm)
		await get_tree().process_frame
	print("DRAG w trakcie: przeciąganie=%s taca_podświetlona=%s" % [str(get_viewport().gui_is_dragging()), str(ui.deal_zone_hot)])
	var mu := InputEventMouseButton.new()
	mu.button_index = MOUSE_BUTTON_LEFT
	mu.pressed = false
	mu.position = b * k
	mu.global_position = b * k
	send.call(mu)
	for i in range(4):
		await get_tree().process_frame
	print("DRAG po upuszczeniu: okienko=%s na_tacy=%d g" % [str(not ui.deal_ask.is_empty()), int(ui.deal.qty)])


## seria kadrów kamery filmowej w jednym uruchomieniu (do wybierania ujęć zwiastuna)
func _force_frame() -> void:
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)


func _tour() -> void:
	var f := FileAccess.open(String(args.tour), FileAccess.READ)
	var list = JSON.parse_string(f.get_as_text())
	f.close()
	var dir := String(args.get("out", "user://tour"))
	DirAccess.make_dir_recursive_absolute(dir)
	G.test_hide_hud = true
	ui.hud.visible = false
	for i in range(30):
		await get_tree().process_frame
	for e in list:
		var c: Array = e.cam
		G.S.t = float(e.get("hour", 14.0)) * 60.0
		var r := float(e.get("rain", 0.0))
		G.S.weather = {"start": 0.0, "end": 1e12, "power": r} if r > 0.0 else null
		env.rain = r
		env.wet = 1.0 if r > 0.0 else 0.0
		teleport("out", Vector3(float(c[0]) * D.SC, 0.0, float(c[1]) * D.SC), 0.0)
		cine_cam(_cine_pt(float(c[0]), float(c[1]), float(c[2])), _cine_pt(float(c[3]), float(c[4]), float(c[5])), float(e.get("fov", 60.0)))
		if e.has("train"):
			world.train.active = false
			world.train.wait = 0.0
			world.tick_train(0.01, G.night)
			world.train.x = float(e.train) * float(world.train.dir)
		for i in range(int(e.get("frames", 50))):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var tw := int(args.get("tourw", "640"))
		img.resize(tw, int(float(tw) * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
		img.save_jpg("%s/%s.jpg" % [dir, String(e.name)], 0.85)
		print("TOUR ", e.name)
	get_tree().quit()


func _shot() -> void:
	var frames := int(args.get("frames", "150"))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	# --bench: uczciwy pomiar — bez VSync i bez dynamicznej rozdzielczości, mediana czasu klatki po rozgrzewce
	var bench_on := args.has("bench")
	var times: Array = []
	if bench_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		env.dyn_on = false
		env.dyn = 1.0
		env.apply_scale()
	var last_us := Time.get_ticks_usec()
	for i in range(frames):
		await get_tree().process_frame
		var now_us := Time.get_ticks_usec()
		if has_meta("drawtest"):
			(get_meta("drawtest") as Control).queue_redraw()
		if has_meta("drawtest_pb"):
			(get_meta("drawtest_pb") as ProgressBar).value = float(i % 100)
		if args.has("hudstress"):
			# typowe zmiany interfejsu w ruchu: kondycja, podpowiedź z postępem, minimapa, cel w zasięgu wzroku
			var hs := String(args.hudstress)
			if hs == "1" or hs.contains("stam"):
				player.stamina = player.max_stamina() * (0.5 + 0.4 * sin(i * 0.2))
			if (hs == "1" or hs.contains("prompt")) and not has_meta("hs_prompt"):
				# po wszystkich _process, tuż przed rysowaniem (gra sama co klatkę chowa podpowiedź, gdy nie ma na co celować)
				set_meta("hs_prompt", true)
				ui.test_prompt_lock = true
				RenderingServer.frame_pre_draw.connect(func(): ui.set_prompt("Test", fmod(Engine.get_frames_drawn() * 0.02, 1.0)))
			if hs == "1" or hs.contains("mini"):
				settings.minimap = true
				G.S.nav_on = true
			ui.hud_t = 0.0
		if bench_on and i >= 60:
			times.append((now_us - last_us) / 1000.0)
		last_us = now_us
		if i == 30 and args.has("ui"):
			_test_ui(String(args.ui))
		if i == 30 and args.has("prostage") and G.prologue != null:
			G.prologue.jump(String(args.prostage))
			if args.has("pos"):
				var pq := String(args.pos).split(",")
				if player.loc != "out":
					player.place(Vector3(float(D.ROOMS[player.loc].cx) + float(pq[0]), 0.0, float(pq[1])), deg_to_rad(float(args.get("yaw", "0"))))
				else:
					player.place(Vector3(float(pq[0]) * D.SC, 0.0, float(pq[1]) * D.SC), deg_to_rad(float(args.get("yaw", "0"))))
				if args.has("pitch"):
					player.pitch = deg_to_rad(float(args.pitch))
			if args.has("crouch"):
				player.set_crouch(true)
	await RenderingServer.frame_post_draw
	if args.has("dbg"):
		var ph = ui.phone
		print("DBG screen=", ph.screen.size, " sv=", ph.sv.size, " svmin=", ph.sv.get_combined_minimum_size(), " pos=", ph.sv.position)
		for c in ph.sv.get_children():
			print("DBG   ", c.get_class(), " min=", (c as Control).get_combined_minimum_size(), " size=", (c as Control).size)
		for c in ph.body.get_children():
			print("DBG     body ", c.get_class(), " min=", (c as Control).get_combined_minimum_size())
		for c in ph.footer.get_children():
			print("DBG     foot ", c.get_class(), " min=", (c as Control).get_combined_minimum_size())
	var img := get_viewport().get_texture().get_image()
	print("RAW ", img.get_width(), "x", img.get_height(), " win=", get_window().size, " screen=", DisplayServer.window_get_current_screen(), " scale=", DisplayServer.screen_get_scale())
	if img.get_width() > 2000 and not args.has("raw"):
		img.resize(int(img.get_width() / 2.0), int(img.get_height() / 2.0), Image.INTERPOLATE_LANCZOS)
	img.save_png(String(args.shot))
	var vp_rid := get_viewport().get_viewport_rid()
	print("RENDER cpu_ms=%.2f gpu_ms=%.2f" % [RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu(), RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)])
	var cnt := {"anim": 0, "anim_on": 0, "cpu_part": 0, "gpu_part": 0, "nodes": 0, "lights": 0, "lights_shadow": 0, "label3d": 0}
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		cnt.nodes += 1
		if nd is AnimationPlayer:
			cnt.anim += 1
			if (nd as AnimationPlayer).is_playing() and nd.can_process():
				cnt.anim_on += 1
		elif nd is CPUParticles3D:
			cnt.cpu_part += 1
		elif nd is GPUParticles3D:
			cnt.gpu_part += 1
		elif nd is Label3D:
			cnt.label3d += 1
		elif nd is Light3D and (nd as Light3D).visible:
			cnt.lights += 1
			if (nd as Light3D).shadow_enabled:
				cnt.lights_shadow += 1
		for ch in nd.get_children():
			stack.append(ch)
	print("COUNT ", cnt)
	if prof[2] > 0:
		print("PROF env_ms=%.3f npc_ms=%.3f ui_ms=%.3f (średnio na klatkę)" % [prof[0] / 1000.0 / prof[2], prof[1] / 1000.0 / prof[2], ui.prof_us / 1000.0 / maxf(1.0, ui.prof_n)])
	if times.size() > 4:
		times.sort()
		print("BENCH med_ms=%.2f p90_ms=%.2f min_ms=%.2f scale=%.2f n=%d" % [times[int(times.size() / 2.0)], times[int(times.size() * 0.9)], times[0], get_viewport().scaling_3d_scale, times.size()])
	print("SHOT ", args.shot, " fps=", Engine.get_frames_per_second(), " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		" objects=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		" tris=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		" process_ms=%.2f physics_ms=%.2f" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	get_tree().quit()


## nagranie pokazu telefonu jako sekwencji klatek PNG (uruchamiać z --fixed-fps 30)
## Nagranie klatek do pokazowego GIF-a z klubu Neon: wejście nocą, kontrola, parkiet, bar, sprzedaż.
## Uruchamiać z --fixed-fps 30; klatki (co druga) trafiają do folderu z --recklub=…, z numerem ujęcia w nazwie.
func _record_klub() -> void:
	var dir := String(args.recklub)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in range(40):
		await get_tree().process_frame
	G.S.t = 22.6 * 60.0
	G.S.lvl = 6
	G.S.cash = 1840.0
	G.S.flags["hurt_on"] = true
	G.add_pack(G.S.inv, "szron", 82, 6)
	G.add_pack(G.S.inv, "snieg", 88, 4)
	var R: Dictionary = D.ROOMS.club
	var cx: float = R.cx
	var fx := cx - 2.2
	var door: Vector3 = world.club_door
	var n := 0
	var shot := 0
	# [ile klatek, przygotowanie, ruch kamery(k 0..1)]
	var plan := [
		{"len": 84, "setup": func():
			teleport("out", Vector3(door.x + 7.0, 0.0, door.z + 0.6), PI / 2.0),
			"cam": func(k: float):
				var e := k * k * (3.0 - 2.0 * k)
				cine_cam(Vector3(door.x + 11.0 - e * 6.2, 1.5 + e * 0.25, door.z + 1.9 - e * 1.7), Vector3(door.x - 0.8, 2.1, door.z), 50.0)},
		{"len": 66, "setup": func():
			cine_off()
			teleport("out", Vector3(door.x + 2.9, 0.0, door.z + 0.1), PI / 2.0)
			player.pitch = 0.04
			club_door(),
			"cam": func(_k: float): pass},
		{"len": 60, "setup": func():
			ui.close_all()
			ui.dialog({"name": "Ochroniarz", "lines": ["A to co? Amfetamina. Z tym nie wejdziesz. Zostaw to gdzieś i wróć — albo nie wracaj."]})
			G.notify("Wpadka przy kontroli (1/3 tej nocy).", "bad"),
			"cam": func(_k: float): pass},
		{"len": 110, "setup": func():
			ui.close_all()
			teleport("club", Vector3(cx, 0.0, 4.4), 0.0),
			"cam": func(k: float):
				var a := -0.5 + k * 1.5
				cine_cam(Vector3(fx + sin(a) * 6.2, 2.5 - k * 0.5, -1.2 + cos(a) * 5.6), Vector3(fx, 1.1, -1.4), 58.0)},
		{"len": 80, "setup": func(): pass,
			"cam": func(k: float):
				var a := 2.4 + k * 1.1
				cine_cam(Vector3(fx + sin(a) * 3.3, 0.9 + k * 0.5, -1.2 + cos(a) * 3.0), Vector3(fx, 1.45, -1.2), 66.0)},
		{"len": 66, "setup": func():
			cine_off()
			teleport("club", Vector3(cx + 4.0, 0.0, -0.9), -PI / 2.0)
			player.pitch = 0.02
			club_bar(),
			"cam": func(_k: float): pass},
		{"len": 40, "setup": func():
			ui.close_all()
			teleport("club", Vector3(fx + 0.6, 0.0, 1.9), 0.25)
			for st in npcs.statics:
				if st.loc == "club" and st.has("want"):
					st["want"] = "szron"
					club_buyer(st)
					break,
			"cam": func(_k: float): pass},
		{"len": 84, "setup": func():
			for k in range(3):
				if ui.mode == "dialog":
					ui.advance(),
			"cam": func(_k: float): pass},
	]
	for sh in plan:
		(sh.setup as Callable).call()
		for i in range(int(sh.len)):
			(sh.cam as Callable).call(float(i) / maxf(1.0, float(int(sh.len) - 1)))
			await get_tree().process_frame
			if i >= 6 and i % 2 == 0:
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.resize(640, int(640.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
				img.save_jpg("%s/s%d_%04d.jpg" % [dir, shot, n], 0.9)
				n += 1
		shot += 1
	print("RECKLUB ", n, " klatek")
	get_tree().quit()


func _record() -> void:
	var dir := String(args.rec)
	DirAccess.make_dir_recursive_absolute(dir)
	var o := _test_order("dominik", false)
	var plan := {20: "open", 70: "sms", 110: "chat", 170: "reply", 240: "back", 265: "home", 372: "rozwoj", 430: "home", 452: "mapa", 505: "home", 527: "kontakty", 570: "end"}
	var n := 0
	for i in range(575):
		await get_tree().process_frame
		if plan.has(i):
			match String(plan[i]):
				"open": ui.open_phone("")
				"chat":
					ui.phone._dir = 1.0
					ui.phone.chat_id = "dominik"
					ui.phone.render()
				"reply": ui.phone._reply(int(o.id), "accept")
				"back": ui.phone.back()
				"home": ui.phone.go("")
				"end": break
				_: ui.phone.go(String(plan[i]))
		if i >= 14 and i % 2 == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			if img.get_width() > 1400:
				img.resize(1280, int(1280.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
			img.save_png("%s/f_%04d.png" % [dir, n])
			n += 1
	print("REC ", n, " klatek")
	get_tree().quit()
