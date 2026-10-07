extends Node
## Reżyser zwiastuna. Odtwarza zaplanowane ujęcia (kamera filmowa i prawdziwa rozgrywka),
## zapisuje każdą klatkę jako JPG i eksportuje podkład muzyczny. Uruchomienie:
##   Godot --path . --fixed-fps 30 --resolution 1920x1080 --audio-driver Dummy -- --autostart --trailer=/folder/na/klatki
## Cięcia wypadają na takty podkładu (140 BPM → 51,43 klatki na takt przy 30 kl./s).

const K = preload("res://scripts/uikit.gd")
const Chars = preload("res://scripts/chars.gd")
const BAR := 51.428571
const COP := {"kind": "police", "top": "c8e020", "top2": "141c30", "bottom": "141c30", "shoes": "0c0c0e", "hat": "police", "seed": 4}

var M
var U
var W
var out := ""
var n_saved := 0
var bar_acc := 0.0
var layer: CanvasLayer
var bar_t: ColorRect
var bar_b: ColorRect
var fade: ColorRect
var box: VBoxContainer
var accent: ColorRect
var l_big: Label
var l_sub: Label
var title_box: VBoxContainer
var actors: Array = []
var fx: Array = []
var gframe := 0
var deal_done := false
var last_press := -99
var shot_i := 0
var shot_f := 0


func _ready() -> void:
	M = G.main
	U = G.ui
	W = G.world
	out = String(M.args.trailer)
	DirAccess.make_dir_recursive_absolute(out)
	_overlay()
	run()


# ================================================================ nakładki: pasy kinowe, napisy, ściemnienia
func _font(name: String) -> Font:
	return load("res://assets/fonts/%s.ttf" % name)


func _overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	bar_t = ColorRect.new()
	bar_t.color = Color.BLACK
	bar_t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar_t.offset_bottom = 62.0
	root.add_child(bar_t)
	bar_b = ColorRect.new()
	bar_b.color = Color.BLACK
	bar_b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar_b.offset_top = -62.0
	root.add_child(bar_b)
	# napis ujęcia: zielona kreska + duży tekst + podpis
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	h.offset_left = 70.0
	h.offset_bottom = -104.0
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(h)
	accent = ColorRect.new()
	accent.color = K.C_ACC
	accent.custom_minimum_size = Vector2(5, 0)
	h.add_child(accent)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	h.add_child(box)
	l_big = Label.new()
	l_big.add_theme_font_override("font", _font("bebas"))
	l_big.add_theme_font_size_override("font_size", 58)
	l_big.add_theme_color_override("font_color", Color.WHITE)
	l_big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l_big.add_theme_constant_override("shadow_offset_y", 2)
	l_big.add_theme_constant_override("shadow_outline_size", 10)
	box.add_child(l_big)
	l_sub = Label.new()
	l_sub.add_theme_font_override("font", _font("barlowc"))
	l_sub.add_theme_font_size_override("font_size", 22)
	l_sub.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9))
	l_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l_sub.add_theme_constant_override("shadow_outline_size", 6)
	box.add_child(l_sub)
	h.name = "Caption"
	# plansza tytułowa
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	title_box = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	title_box.modulate.a = 0.0
	cc.add_child(title_box)
	var t1 := Label.new()
	t1.text = "CZARNY RYNEK"
	t1.add_theme_font_override("font", _font("bebas"))
	t1.add_theme_font_size_override("font_size", 150)
	t1.add_theme_color_override("font_color", Color.WHITE)
	t1.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	t1.add_theme_constant_override("shadow_offset_y", 4)
	t1.add_theme_constant_override("shadow_outline_size", 18)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(t1)
	var ln := ColorRect.new()
	ln.color = K.C_ACC
	ln.custom_minimum_size = Vector2(0, 4)
	title_box.add_child(ln)
	var t2 := Label.new()
	t2.text = "SPŁAĆ DŁUG.  ZBUDUJ IMPERIUM.  NIE DAJ SIĘ ZŁAPAĆ."
	t2.add_theme_font_override("font", _font("barlowc"))
	t2.add_theme_font_size_override("font_size", 30)
	t2.add_theme_color_override("font_color", Color(0.86, 0.9, 0.94))
	t2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	t2.add_theme_constant_override("shadow_outline_size", 8)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(t2)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	title_box.add_child(gap)
	var fv := FontVariation.new()
	fv.base_font = _font("barlowc")
	fv.spacing_glyph = 4
	var t3 := Label.new()
	t3.text = "A TEST GAME BY PIOTR PIŁKA"
	t3.add_theme_font_override("font", fv)
	t3.add_theme_font_size_override("font_size", 19)
	t3.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	t3.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	t3.add_theme_constant_override("shadow_outline_size", 6)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(t3)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)


func _caption() -> Control:
	return layer.get_child(0).get_node("Caption")


func letterbox(on: bool) -> void:
	bar_t.visible = on
	bar_b.visible = on


## napis pojawia się od `t0` (ułamek ujęcia) i gaśnie pod koniec
func _text_tick(f: int, n: int, s: Dictionary) -> void:
	var cap := _caption()
	var big := String(s.get("big", ""))
	var sub := String(s.get("sub", ""))
	if big == "" and sub == "":
		cap.modulate.a = 0.0
		return
	l_big.text = big
	l_big.visible = big != ""
	l_sub.text = sub
	l_sub.visible = sub != ""
	var corner: bool = s.get("top", false)      # ujęcia z HUD-em: napis w wolnym, prawym dolnym rogu
	var f0 := int(float(s.get("t0", 0.12)) * n)
	var a := clampf(float(f - f0) / 9.0, 0.0, 1.0) * clampf(float(n - 4 - f) / 8.0, 0.0, 1.0)
	var slide := (1.0 - clampf(float(f - f0) / 14.0, 0.0, 1.0)) * 26.0
	cap.modulate.a = a
	if corner:
		cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		cap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		cap.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cap.offset_right = -44.0 + slide
		cap.offset_bottom = -40.0
		cap.offset_left = cap.offset_right
		cap.offset_top = cap.offset_bottom
	else:
		cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		cap.grow_horizontal = Control.GROW_DIRECTION_END
		cap.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cap.offset_left = 70.0 - slide
		cap.offset_right = cap.offset_left
		cap.offset_bottom = -104.0 if bar_b.visible else -150.0
		cap.offset_top = cap.offset_bottom


func _fade_tick(f: int, n: int, s: Dictionary) -> void:
	var a := 0.0
	if s.get("fade_in", 0) > 0:
		a = maxf(a, 1.0 - float(f) / float(s.fade_in))
	if s.get("fade_out", 0) > 0:
		a = maxf(a, 1.0 - float(n - 1 - f) / float(s.fade_out))
	fade.color.a = clampf(a, 0.0, 1.0)


# ================================================================ narzędzia ujęć
func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func clock(h: float, day := 12) -> void:
	G.S.t = (day - 1) * 1440.0 + h * 60.0


func weather(r: float) -> void:
	G.S.weather = {"start": 0.0, "end": 1e12, "power": r} if r > 0.0 else null
	M.env.rain = r
	M.env.rain_target = r
	M.env.wet = 1.0 if r > 0.0 else 0.0


func hud(on: bool, toasts := true) -> void:
	G.test_hide_hud = not on
	U.hud.visible = on
	U.toasts.visible = on and toasts
	K.clear(U.toasts)
	U.sms_banner.visible = false
	U.sms_t = 0.0


## kamera filmowa: a, b = [x, z, wysokość, cel_x, cel_z, cel_wysokość] w układzie projektu
func cam(k: float, a: Array, b: Array, fov := 58.0) -> void:
	var e := k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65
	var v := []
	for i in range(6):
		v.append(lerpf(float(a[i]), float(b[i]), e))
	M.cine_cam(M._cine_pt(v[0], v[1], v[2]), M._cine_pt(v[3], v[4], v[5]), fov)
	# gracz stoi pod kamerą: od niego liczą się zasięgi widoczności, deszcz i aktywność postaci
	var px: float = v[0] * D.SC
	var pz: float = v[1] * D.SC
	if M.player.loc != "out":
		M.teleport("out", Vector3(px, 0.0, pz), 0.0)
	M.player.global_position = Vector3(px, W.height(px, pz), pz)


func first_person(loc: String, x: float, z: float, yaw_deg: float, pitch_deg := 0.0) -> void:
	M.cine_off()
	var pos := Vector3(x * D.SC, 0.0, z * D.SC) if loc == "out" else Vector3(x, 0.0, z)
	M.teleport(loc, pos, deg_to_rad(yaw_deg))
	M.player.pitch = deg_to_rad(pitch_deg)
	M.player.cam.fov = 70.0


func key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func train(x_world: float, dir: float) -> void:
	W.train.active = false
	W.train.wait = 0.0
	W.train.dir = -dir
	W.tick_train(0.001, G.night)
	W.train.x = x_world


func lights_far(on: bool) -> void:
	var st: Array = [W]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is OmniLight3D or n is SpotLight3D:
			(n as Light3D).distance_fade_enabled = not on
		for c in n.get_children():
			st.append(c)


## statysta: idzie z a do b (układ projektu) przez całe ujęcie albo stoi w pozie
func actor(look: Dictionary, a: Vector2, b: Vector2, pose := "", anim := "", rate := 1.0) -> Dictionary:
	var rig: Dictionary = Chars.make(look)
	M.add_child(rig.root)
	var act := {"rig": rig, "a": a * D.SC, "b": b * D.SC, "pose": pose, "anim": anim, "rate": rate, "face": null}
	actors.append(act)
	return act


func _actors_tick(k: float, n: int) -> void:
	for act in actors:
		var rig: Dictionary = act.rig
		var a: Vector2 = act.a
		var b: Vector2 = act.b
		var p: Vector2 = a.lerp(b, k)
		rig.root.position = Vector3(p.x, W.height(p.x, p.y), p.y)
		var moving := a.distance_to(b) > 0.05
		if moving:
			rig.root.rotation.y = atan2(b.x - a.x, b.y - a.y)
		elif act.face != null:
			var fp: Vector2 = act.face
			rig.root.rotation.y = atan2(fp.x * D.SC - p.x, fp.y * D.SC - p.y)
		if String(act.anim) != "":
			Chars.play(rig, act.anim, float(act.rate))
		else:
			var speed := a.distance_to(b) / (float(n) / 30.0) if moving else 0.0
			Chars.animate(rig, 1.0 / 30.0, speed, act.pose)


func _clear() -> void:
	for act in actors:
		act.rig.root.queue_free()
	actors.clear()
	for n in fx:
		if is_instance_valid(n):
			n.queue_free()
	fx.clear()
	for code in [KEY_W, KEY_SHIFT, KEY_A, KEY_D]:
		key(code, false)


func _save() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() != 1920 or img.get_height() != 1080:
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg("%s/s%02d_%04d.jpg" % [out, shot_i, shot_f], 0.93)
	shot_f += 1
	n_saved += 1


func play(s: Dictionary) -> void:
	var f0 := int(round(bar_acc * BAR))
	bar_acc += float(s.bars)
	var n := int(round(bar_acc * BAR)) - f0
	_clear()
	shot_f = 0
	_caption().modulate.a = 0.0
	letterbox(s.get("box", true))
	print("TRAILER przed %s: t=%.1f cash=%.0f loc=%s mode=%s" % [s.get("name", "?"), G.S.t, G.S.cash, M.player.loc, U.mode])
	if s.has("setup"):
		await s.setup.call()
	print("TRAILER po setup %s: t=%.1f cash=%.0f" % [s.get("name", "?"), G.S.t, G.S.cash])
	if s.has("tick"):
		s.tick.call(0.0, 0)
	_actors_tick(0.0, n)
	await frames(int(s.get("warm", 8)))
	if s.has("ready"):
		await s.ready.call()
	for f in range(n):
		var k := float(f) / float(maxi(1, n - 1))
		gframe = f
		if s.has("h"):
			clock(float(s.h), int(s.get("day", 12)))
		if s.has("tick"):
			s.tick.call(k, f)
		_actors_tick(k, n)
		_text_tick(f, n, s)
		_fade_tick(f, n, s)
		if s.get("title", false):
			title_box.modulate.a = clampf(float(f - int(n * 0.14)) / 16.0, 0.0, 1.0)
			title_box.scale = Vector2.ONE * (1.0 + 0.04 * (1.0 - k))
			title_box.pivot_offset = title_box.size * 0.5
		await get_tree().process_frame
		await _save()
	if s.has("end"):
		s.end.call()
	print("TRAILER ujęcie %s: %d klatek (razem %d)" % [s.get("name", "?"), n, n_saved])


# ================================================================ scenariusz
func run() -> void:
	seed(20261005)
	await frames(30)
	if U.mode == "dialog":
		U.close_all()
	for fk in ["tut_save", "tut_stash", "tut_bench"]:
		G.S.flags[fk] = true
	G._on_tour_done()
	G.mods["sleeping"] = true          # żadnych losowych SMS-ów w trakcie nagrania
	U.sms_banner.visible = false
	U.sms_t = 0.0
	# podkład muzyczny: ta sama pętla, która gra w klubie Neon
	var wav: AudioStreamWAV = Sfx._wav(Sfx._gen_trap(), false)
	wav.save_to_wav(out + "/beat.wav")
	var only := String(M.args.get("only", ""))
	var shots := [
		{"name": "swit", "bars": 4, "fade_in": 26, "sub": "ZAGŁĘBIE  •  6:40", "big": "BRAT ZNIKNĄŁ.", "t0": 0.38, "setup": s1_setup, "ready": s1_ready, "tick": s1_tick},
		{"name": "blokowisko", "bars": 2, "big": "ZOSTAWIŁ CI KLUCZE DO KAWALERKI", "setup": s2_setup, "ready": s2_ready, "tick": s2_tick},
		{"name": "klatka", "bars": 2, "big": "I 25 000 ZŁ DŁUGU.", "setup": s3_setup, "tick": s3_tick},
		{"name": "telefon", "bars": 3, "box": false, "h": 9.4, "day": 1, "setup": s4_setup, "tick": s4_tick, "end": ui_end},
		{"name": "skrytka", "bars": 1, "big": "TOWAR CZEKA W SKRYTCE.", "t0": 0.05, "setup": s5_setup, "tick": s5_tick},
		{"name": "waga", "bars": 2, "box": false, "h": 10.6, "day": 1, "setup": s6_setup, "tick": s6_tick, "end": s6_end},
		{"name": "klient", "bars": 1, "big": "PIERWSZY KLIENT.", "t0": 0.05, "setup": s7_setup, "tick": s7_tick},
		{"name": "transakcja", "bars": 4, "box": false, "h": 17.15, "day": 1, "setup": s8_setup, "ready": s8_ready, "tick": s8_tick, "end": s8_end},
		{"name": "ekwipunek", "bars": 2, "box": false, "h": 20.2, "day": 3, "setup": s9_setup, "tick": s9_tick, "end": ui_end},
		{"name": "ulica", "bars": 2, "box": false, "sub": "MIASTO ŻYJE WŁASNYM ŻYCIEM", "top": true, "setup": s10_setup, "ready": walk_on, "tick": s10_tick, "end": walk_off},
		{"name": "pawilon", "bars": 1, "setup": s11_setup, "tick": s11_tick},
		{"name": "przystanek", "bars": 1, "setup": s12_setup, "tick": s12_tick},
		{"name": "kolejka", "bars": 2, "big": "KAŻDY TU COŚ KOMBINUJE.", "setup": s13_setup, "ready": s13_ready, "tick": s13_tick},
		{"name": "latarka", "bars": 2, "box": false, "setup": s14_setup, "ready": walk_on, "tick": s14_tick, "end": s14_end},
		{"name": "neon", "bars": 2, "big": "NOC NALEŻY DO NEONU.", "setup": s15_setup, "tick": s15_tick},
		{"name": "poscig", "bars": 2, "big": "POLICJA NIE ŚPI.", "setup": s16_setup, "tick": s16_tick},
		{"name": "kryjowka", "bars": 2, "box": false, "sub": "URZĄDŹ WŁASNĄ KRYJÓWKĘ", "top": true, "setup": s17_setup, "tick": s17_tick, "end": s17_end},
		{"name": "umiejetnosci", "bars": 2, "box": false, "h": 14.3, "day": 16, "setup": s18_setup, "tick": s18_tick, "end": ui_end},
		{"name": "park", "bars": 2, "big": "SPŁAĆ DŁUG.", "setup": s19_setup, "tick": s19_tick},
		{"name": "noc", "bars": 2, "big": "ALBO MIASTO CIĘ POŻRE.", "setup": s20_setup, "ready": s20_ready, "tick": s20_tick},
		{"name": "tytul", "bars": 4, "title": true, "fade_out": 30, "setup": s21_setup, "ready": s21_ready, "tick": s21_tick},
	]
	for i in range(shots.size()):
		var s: Dictionary = shots[i]
		shot_i = i
		if only != "" and not only.split(",").has(String(s.name)):
			bar_acc += float(s.bars)
			continue
		await play(s)
	var info := FileAccess.open(out + "/info.txt", FileAccess.WRITE)
	info.store_string("%d\n30\n%f\n" % [n_saved, BAR])
	info.close()
	print("TRAILER KONIEC: %d klatek" % n_saved)
	get_tree().quit()


func ui_end() -> void:
	U.close_all()


func walk_on() -> void:
	key(KEY_W, true)


func walk_off() -> void:
	key(KEY_W, false)


# --- 1. świt nad Old Town
const C1A := [-150, 20, 34, 40, 15, 8]
const C1B := [-105, 20, 28, 40, 15, 8]

func s1_setup() -> void:
	hud(false)
	lights_far(true)
	weather(0.0)
	clock(6.3)
	cam(0.0, C1A, C1B)


func s1_ready() -> void:
	train(-52.0, 1.0)


func s1_tick(k: float, _f: int) -> void:
	clock(6.3 + k * 0.22)
	cam(k, C1A, C1B, 56.0)


# --- 2. blokowisko z góry, kolejka na estakadzie
const C2A := [110, -150, 46, -20, -40, 5]
const C2B := [74, -160, 42, -20, -40, 5]

func s2_setup() -> void:
	hud(false)
	clock(17.6)
	cam(0.0, C2A, C2B)


func s2_ready() -> void:
	train(38.0, -1.0)


func s2_tick(k: float, _f: int) -> void:
	clock(17.6)
	cam(k, C2A, C2B, 54.0)


# --- 3. klatka B
const C3A := [17, -63, 1.75, 8, -76, 1.7]
const C3B := [11.5, -69.5, 1.7, 8, -76, 1.6]

func s3_setup() -> void:
	hud(false)
	lights_far(false)
	clock(9.2)
	cam(0.0, C3A, C3B)
	actor(D.CLIENTS[2].look, Vector2(1.0, -70.0), Vector2(-5.0, -68.0))


func s3_tick(k: float, _f: int) -> void:
	clock(9.2)
	cam(k, C3A, C3B, 60.0)


# --- 4. telefon: wiadomość od Wiktora
func s4_setup() -> void:
	hud(true)
	G.S.step = 0 + G.TOUR_STEPS
	G.S.cash = 60.0
	G.S.flags.erase("read_wiktor")
	clock(9.4, 1)
	first_person("safe", float(D.ROOMS.safe.cx) - 0.6, 1.2, 0.0)


func s4_tick(_k: float, f: int) -> void:
	if f == 10:
		U.open_phone("")
	elif f == 52:
		U.phone.go("sms")
	elif f == 92:
		U.phone._dir = 1.0
		U.phone.chat_id = "wiktor"
		U.phone.render()


# --- 5. skrytka za altanką
const C5A := [36, -97, 1.9, 47, -111.5, 1.0]
const C5B := [40.5, -102.5, 1.6, 47, -111.5, 0.9]

func s5_setup() -> void:
	hud(false)
	clock(17.4)
	cam(0.0, C5A, C5B)


func s5_tick(k: float, _f: int) -> void:
	clock(17.4)
	cam(k, C5A, C5B, 56.0)


# --- 6. waga: porcjowanie
func s6_setup() -> void:
	hud(true)
	G.S.step = 2 + G.TOUR_STEPS
	G.S.cash = 60.0
	G.add_bulk(G.S.inv, "dym", 80, 5.0)
	clock(10.6, 1)
	first_person("safe", float(D.ROOMS.safe.cx) + 0.9, -float(D.ROOMS.safe.d) * 0.5 + 2.4, 0.0, -18.0)
	U.fake_ms = 0
	last_press = -99
	U.skill_check("Ważenie: 3 g Green", 1.0, _noop)


func _noop(_h) -> void:
	pass


func s6_tick(_k: float, f: int) -> void:
	U.fake_ms = int(f * 1000.0 / 30.0)
	if U.sk.is_empty() or U.sk.ending:
		return
	var p: float = U._skill_pos(U.fake_ms)
	var mid: float = (float(U.sk.z0) + float(U.sk.z1)) * 0.5
	if f > 16 and f - last_press > 22 and absf(p - mid) < 0.035:
		last_press = f
		U._skill_press()


func s6_end() -> void:
	U.fake_ms = -1
	U.close_all()
	G.take_bulk(G.S.inv, "dym", 80, 99.0)


# --- 7. pierwszy klient idzie na spotkanie
const C7A := [-50, -66, 1.6, -60, -76, 1.3]
const C7B := [-51, -67, 1.6, -57.5, -72.5, 1.3]

func s7_setup() -> void:
	hud(false)
	clock(17.1)
	cam(0.0, C7A, C7B)
	actor(D.CLIENTS[0].look, Vector2(-60.5, -75.6), Vector2(-55.0, -70.2))


func s7_tick(k: float, _f: int) -> void:
	clock(17.1)
	cam(k, C7A, C7B, 50.0)


# --- 8. rozmowa i targowanie
func s8_setup() -> void:
	hud(true)
	G.S.step = 3 + G.TOUR_STEPS
	G.S.cash = 60.0
	clock(17.15, 1)
	G.add_pack(G.S.inv, "dym", 80, 5)
	first_person("out", -51.0, -66.6, 0.0)


func s8_ready() -> void:
	var o: Dictionary = M._test_order("dominik")
	o.grams = 2
	var n: Dictionary = G.npcs.customers[0]
	if n.node == null:
		G.npcs._customer_enter(n, true)
	n.state = "wait"
	n.x = -53.6 * D.SC
	n.z = -68.8 * D.SC
	n.node.position = Vector3(n.x, W.height(n.x, n.z), n.z)
	var who: Dictionary = n.def.duplicate()
	who["st"] = G.S.cust.dominik
	U.open_deal({"who": who, "product": "dym", "grams": 2, "order": o, "street": true, "npc": n, "agreed": o.agreed})
	if not U.deal.is_empty():
		U.deal.cop = null
		U.deal.cop_t = 0.0
		U._render_deal()


func s8_tick(_k: float, f: int) -> void:
	if U.deal.is_empty():
		return
	var d: Dictionary = U.deal
	if f == 58:
		G.deal_set(d, 10)
		U._render_deal()
	elif f == 104 and not d.over:
		d.hold = 0.5
		U._render_deal()
	elif f == 146 and not d.over:
		G.deal_hand(d)
		U._render_deal()
	elif f == 176 and not d.over:
		G.deal_set(d, 0)
		G.deal_hand(d)
		U._render_deal()


func s8_end() -> void:
	U.close_all()
	G.npcs.clear_customers()
	G.S.orders.clear()


# --- 9. ekwipunek i skrytka
func s9_setup() -> void:
	var S: Dictionary = G.S
	hud(true)
	clock(20.2, 3)
	S.cash = 412.0
	S.inv = G.new_store()
	G.add_pack(S.inv, "dym", 80, 6)
	G.add_bulk(S.inv, "dym", 75, 4.0)
	S.items = {"woreczki": 34, "majeranek": 12, "cukier": 0, "nasiona": 0, "burner": 0}
	S.stash.safe = G.new_store()
	G.add_pack(S.stash.safe, "dym", 75, 9)
	G.add_pack(S.stash.safe, "dym", 60, 4)
	S.stash.safe.cash = 300.0
	first_person("safe", float(D.ROOMS.safe.cx) - 0.6, 1.2, 0.0)


func s9_tick(_k: float, f: int) -> void:
	var S: Dictionary = G.S
	if f == 6:
		U.open_stash("safe")
	elif f == 36:
		U.inv.sel = {"side": "bag", "kind": "pack", "p": "dym", "pur": 80, "id": ""}
		U.inv.render()
	elif f == 60:
		for e in G.entries(S.inv):
			if e.kind == "pack":
				G.move_entry("safe", e, true, 4.0)
		U.inv.render()
	elif f == 82:
		for e in G.entries(S.inv):
			if e.kind == "item" and e.id == "majeranek":
				G.move_entry("safe", e, true, 1e9)
		U.inv.sel = {}
		U.inv.render()


# --- 10. ulica z perspektywy gracza
func s10_setup() -> void:
	hud(true)
	G.S.step = 6 + G.TOUR_STEPS
	clock(16.4, 4)
	G.S.inv = G.new_store()
	G.add_pack(G.S.inv, "dym", 80, 6)
	hud(true, false)
	first_person("out", 46.0, 15.0, 90.0, -2.0)
	actor(D.CLIENTS[3].look, Vector2(10, 14.6), Vector2(18, 14.4))
	actor({"kind": "jacket", "top": "3d3326", "bottom": "2e3440", "hat": "cap", "seed": 31}, Vector2(4, 26.2), Vector2(-5, 26.2))
	actor({"female": true, "kind": "hoodie", "top": "6b1f24", "bottom": "232a36", "seed": 32}, Vector2(-14, 14.6), Vector2(-6, 14.6))


func s10_tick(_k: float, _f: int) -> void:
	clock(16.4, 4)


# --- 11–12. pawilon i przystanek
const C11A := [60, -34, 1.8, 72, -44, 2]
const C11B := [63, -36.5, 1.8, 72, -44, 2]

func s11_setup() -> void:
	hud(false)
	clock(12.5)
	cam(0.0, C11A, C11B)
	actor({"kind": "tshirt", "top": "8a2a22", "bottom": "283b2e", "bald": true, "seed": 17, "build": 1.3}, Vector2(74, -39), Vector2(69, -39.5))


func s11_tick(k: float, _f: int) -> void:
	clock(12.5)
	cam(k, C11A, C11B, 62.0)


const C12A := [48, 22, 1.8, 62, 12, 1.5]
const C12B := [51.5, 20.5, 1.8, 62, 12, 1.5]

func s12_setup() -> void:
	clock(7.5)
	cam(0.0, C12A, C12B)


func s12_tick(k: float, _f: int) -> void:
	clock(7.5)
	cam(k, C12A, C12B, 60.0)


# --- 13. kolejka nad głową
const C13A := [-10, -44, 2, 10, -24, 14]
const C13B := [-6, -42, 2.2, 14, -24, 14]

func s13_setup() -> void:
	hud(false)
	clock(18.3)
	cam(0.0, C13A, C13B)
	actor(D.CLIENTS[1].look, Vector2(-4, -38), Vector2(-4, -38), "phone")


func s13_ready() -> void:
	train(-22.0, 1.0)


func s13_tick(k: float, _f: int) -> void:
	clock(18.3)
	cam(k, C13A, C13B, 62.0)


# --- 14. noc z latarką
func s14_setup() -> void:
	hud(true)
	clock(22.6, 6)
	weather(0.0)
	hud(true, false)
	first_person("out", float(M.args.get("fx", "50")), float(M.args.get("fz", "88.6")), float(M.args.get("fyaw", "266")), -2.0)
	M.player.flash.light_energy = 7.0


func s14_tick(_k: float, _f: int) -> void:
	clock(22.6, 6)


func s14_end() -> void:
	key(KEY_W, false)
	M.player.flash.light_energy = 0.0


# --- 15. klub Neon w deszczu
const C15A := [9, 103, 1.8, -8, 128, 6]
const C15B := [4.5, 111, 2.0, -8, 128, 5.5]

func s15_setup() -> void:
	hud(false)
	clock(22.9)
	weather(0.55)
	cam(0.0, C15A, C15B)
	actor({"female": true, "kind": "tank", "top": "c0306a", "bottom": "101114", "hair": "hair_long", "seed": 41}, Vector2(-1.5, 121.5), Vector2(-1.5, 121.5), "dance")
	actor({"kind": "hoodie", "top": "101114", "bottom": "1b2538", "hat": "cap", "seed": 42}, Vector2(0.2, 123.4), Vector2(0.2, 123.4), "dance")
	actor({"female": true, "kind": "jacket", "top": "23402e", "bottom": "101114", "hair": "hair_buns", "seed": 43}, Vector2(-2.6, 124.6), Vector2(-2.6, 124.6), "dance")


func s15_tick(k: float, _f: int) -> void:
	clock(22.9)
	cam(k, C15A, C15B, 60.0)


# --- 16. pościg
func s16_setup() -> void:
	hud(false)
	clock(21.2)
	weather(0.0)
	cam(0.0, [-38, 21, 1.45, -80, 21, 1.4], [-25, 21, 1.5, -80, 21, 1.4])
	actor(D.PLAYER_LOOK, Vector2(-80, 21), Vector2(-30, 21), "", "Sprint", 1.0)
	actor(COP, Vector2(-93, 19.6), Vector2(-41, 19.8), "", "Sprint", 1.0)
	actor(COP, Vector2(-98, 22.6), Vector2(-45, 22.4), "", "Sprint", 1.02)
	for c in [Color(1.0, 0.1, 0.1), Color(0.15, 0.3, 1.0)]:
		var li := OmniLight3D.new()
		li.light_color = c
		li.omni_range = 26.0
		li.light_energy = 0.0
		M.add_child(li)
		fx.append(li)


func s16_tick(k: float, f: int) -> void:
	clock(21.2)
	var dx := lerpf(-80.0, -30.0, k)
	cam(k, [-38, 21.6, 1.45, dx, 21, 1.35], [-25.5, 21.8, 1.5, dx, 21, 1.35], 50.0)
	var cx := lerpf(-97.0, -45.0, k) * D.SC
	for i in range(fx.size()):
		var li: OmniLight3D = fx[i]
		li.position = Vector3(cx - 3.0, 2.6, 21.0 * D.SC + (i - 0.5) * 2.0)
		li.light_energy = 7.0 if (int(f / 5.0) % 2 == i) else 0.3


# --- 17. meblowanie kryjówki
func s17_setup() -> void:
	var S: Dictionary = G.S
	hud(true)
	S.step = 10 + G.TOUR_STEPS
	S.lvl = 5
	S.cash = 2840.0
	clock(14.2, 16)
	S.props["garaz"] = true
	S.hide.garage.items = [{"f": "stol", "x": -1.6, "z": -3.6, "r": 0}, {"f": "namiot", "x": 2.2, "z": -1.2, "r": 0}, {"f": "kanapa", "x": -2.4, "z": 0.6, "r": 1}, {"f": "lampa", "x": 0.2, "z": -4.1, "r": 0}]
	W.refresh_furniture("garage")
	first_person("garage", float(D.ROOMS.garage.cx) + 0.4, 2.6, 8.0, -14.0)
	S["owned"] = {"regal": 1}
	M.build_begin("regal")


func s17_tick(k: float, f: int) -> void:
	clock(14.2, 16)
	if f < 64:
		M.player.yaw = deg_to_rad(lerpf(8.0, -30.0, clampf(k / 0.6, 0.0, 1.0)))
		M.player.pitch = deg_to_rad(-14.0)
	if f == 66:
		if not M.build.is_empty() and not M.build.valid:
			for dx in [0.0, 0.25, -0.25, 0.5, -0.5, 0.75, -0.75]:
				if G.furn_valid("garage", "regal", float(M.build.x) + dx, float(M.build.z), 0):
					M.build.x = float(M.build.x) + dx
					M.build.valid = true
					break
		M.build_confirm()
		W.refresh_furniture("garage")


func s17_end() -> void:
	M.build_cancel()


# --- 18. drzewko umiejętności
func s18_setup() -> void:
	G.S.sp = 2
	G.S.skills = {"gadka": true, "oko1": true, "kondycja1": true, "reka": true}
	first_person("garage", float(D.ROOMS.garage.cx) + 0.4, 2.6, -20.0, -6.0)


func s18_tick(_k: float, f: int) -> void:
	if f == 6:
		U.open_phone("rozwoj")
	elif f == 48:
		U.phone.skill_sel = "twarda"
		U.phone.render()
	elif f == 78:
		G.learn_skill("twarda")
		U.phone.render()


# --- 19. park o poranku
const C19A := [-172, 93, 1.8, -140, 125, 3]
const C19B := [-166, 99, 1.9, -140, 125, 3]

func s19_setup() -> void:
	hud(false)
	clock(8.0)
	cam(0.0, C19A, C19B)
	actor(D.CLIENTS[2].look, Vector2(-150, 108), Vector2(-157, 104))


func s19_tick(k: float, _f: int) -> void:
	clock(8.0)
	cam(k, C19A, C19B, 58.0)


# --- 20. miasto nocą
const C20A := [60, 120, 50, 0, 0, 5]
const C20B := [44, 104, 46, 0, 0, 5]

func s20_setup() -> void:
	hud(false)
	lights_far(true)
	clock(23.2)
	cam(0.0, C20A, C20B)


func s20_ready() -> void:
	train(-40.0, 1.0)


func s20_tick(k: float, _f: int) -> void:
	clock(23.2)
	cam(k, C20A, C20B, 56.0)


# --- 21. tytuł
const C21A := [-190, 150, 40, 0, 0, 10]
const C21B := [-168, 138, 37, 0, 0, 10]

func s21_setup() -> void:
	hud(false)
	clock(18.8)
	cam(0.0, C21A, C21B)


func s21_ready() -> void:
	train(30.0, -1.0)


func s21_tick(k: float, _f: int) -> void:
	clock(18.8)
	cam(k, C21A, C21B, 54.0)
