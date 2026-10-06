extends Control
## Opcje: obraz, dźwięk, sterowanie (z własnymi klawiszami) i interfejs.
## Każda zmiana działa od razu i zapisuje się w ustawieniach.

const K = preload("res://scripts/uikit.gd")

var ui
var tab := "video"
var body: VBoxContainer
var tabs_box: HBoxContainer
var rebind := ""            # akcja, która czeka na nowy klawisz
var back_to := "title"
var hint: Label


func build(u) -> void:
	ui = u
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.025, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var box := K.panel(K.sb(Color(0.045, 0.055, 0.078, 0.98), 16, Color(1, 1, 1, 0.1), 1, 22))
	box.custom_minimum_size = Vector2(820, 560)
	cc.add_child(box)
	var v := K.vbox(12)
	box.add_child(v)
	var top := K.hbox(10)
	top.add_child(K.icon("settings", 22, K.C_ACC))
	top.add_child(K.head("OPCJE", 26, Color.WHITE))
	top.add_child(K.spacer())
	top.add_child(K.btn("Zamknij  [Esc]", close, "", true))
	v.add_child(top)
	tabs_box = K.hbox(6)
	v.add_child(tabs_box)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 392)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	body = K.vbox(4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	hint = K.lbl("", 12, K.C_DIM)
	v.add_child(hint)


func open(from: String) -> void:
	back_to = from
	rebind = ""
	visible = true
	render()


func close() -> void:
	rebind = ""
	visible = false
	G.main.save_settings()
	ui.options_closed(back_to)


func _put(key: String, value) -> void:
	G.main.settings[key] = value
	G.main.apply_settings()
	G.main.save_settings()


# ---------------------------------------------------------------- wiersze
func _row(label: String, sub := "") -> HBoxContainer:
	var p := K.panel(K.sb(Color(1, 1, 1, 0.03), 9, Color(0, 0, 0, 0), 0, 12))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(p)
	var h := K.hbox(12)
	p.add_child(h)
	var lv := K.vbox(0)
	lv.custom_minimum_size = Vector2(300, 0)
	lv.add_child(K.lbl(label, 15, K.C_TXT))
	if sub != "":
		var s := K.wrap(sub, 11, K.C_DIM, 300.0)
		lv.add_child(s)
	h.add_child(lv)
	h.add_child(K.spacer())
	return h


func _choice(label: String, key: String, opts: Array, sub := "") -> void:
	var h := _row(label, sub)
	var cur = G.main.settings.get(key)
	for o in opts:
		var val = o[0]
		var on: bool = str(cur) == str(val)
		var b := K.btn(String(o[1]), func(): _put(key, val); render(), "go" if on else "", true)
		b.custom_minimum_size = Vector2(74, 30)
		h.add_child(b)


func _toggle(label: String, key: String, sub := "") -> void:
	_choice(label, key, [[true, "Wł."], [false, "Wył."]], sub)


func _slider(label: String, key: String, lo: float, hi: float, step: float, fmt: Callable, sub := "") -> void:
	var h := _row(label, sub)
	var val := K.head(String(fmt.call(float(G.main.settings.get(key, lo)))), 16, K.C_ACC)
	val.custom_minimum_size = Vector2(64, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(G.main.settings.get(key, lo))
	sl.custom_minimum_size = Vector2(250, 22)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = K.C_ACC
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	sl.value_changed.connect(func(x: float):
		val.text = String(fmt.call(x))
		G.main.settings[key] = x
		G.main.apply_settings())
	sl.drag_ended.connect(func(_c): G.main.save_settings())
	h.add_child(sl)
	h.add_child(val)


func _section(title: String) -> void:
	body.add_child(K.gap(4))
	body.add_child(K.head(title, 13, K.C_ACC))


func render() -> void:
	K.clear(tabs_box)
	for t in [["video", "Obraz", "monitor"], ["audio", "Dźwięk", "volume_2"], ["keys", "Sterowanie", "keyboard"], ["game", "Interfejs", "layout_dashboard"]]:
		var id: String = t[0]
		var b := K.btn("  " + String(t[1]) + "  ", func(): tab = id; rebind = ""; render(), "go" if tab == id else "")
		b.custom_minimum_size = Vector2(150, 36)
		tabs_box.add_child(b)
	K.clear(body)
	hint.text = ""
	match tab:
		"video": _video()
		"audio": _audio()
		"keys": _keys()
		"game": _game()


func _pct(x: float) -> String:
	return "%d%%" % int(round(x * 100.0))


func _video() -> void:
	_choice("Jakość obrazu", "quality", [["low", "Niska"], ["med", "Średnia"], ["high", "Wysoka"], ["ultra", "Ultra"]], "„Ultra” jest dla mocnych kart graficznych: globalne oświetlenie, odbicia, cienie 8K, pełna rozdzielczość. Na laptopach bez osobnej karty wybierz „Niska” albo „Średnia”.")
	_slider("Skala rozdzielczości", "res_scale", 0.5, 1.0, 0.05, _pct, "Niższa wartość = więcej klatek, mniej ostry obraz 3D. Napisy i menu zostają ostre.")
	_toggle("Dynamiczna rozdzielczość", "dyn_res", "Gra sama lekko obniża ostrość, gdy brakuje klatek.")
	_choice("Cienie", "shadows", [["", "Auto"], ["low", "Niskie"], ["med", "Średnie"], ["high", "Wysokie"]])
	_toggle("Mgła i snopy światła", "fog")
	_toggle("Cieniowanie zakamarków (SSAO)", "ssao")
	_slider("Pole widzenia", "fov", 60.0, 95.0, 1.0, func(x: float): return "%d°" % int(x))
	_slider("Jasność", "bright", 0.7, 1.5, 0.05, _pct, "Podbij, jeśli noc jest dla Ciebie za ciemna.")
	_section("EKRAN")
	var h := _row("Pełny ekran", "Skrót: F11")
	for o in [[true, "Wł."], [false, "Wył."]]:
		var val: bool = o[0]
		var b := K.btn(String(o[1]), func(): G.main.set_fullscreen(val); render(), "go" if G.main.is_fullscreen() == val else "", true)
		b.custom_minimum_size = Vector2(74, 30)
		h.add_child(b)
	_toggle("Synchronizacja pionowa (VSync)", "vsync", "Wyłącz, jeśli wolisz więcej klatek kosztem rwania obrazu.")
	_choice("Limit klatek", "fps_cap", [[0, "Brak"], [30, "30"], [60, "60"], [90, "90"], [120, "120"]])


func _audio() -> void:
	_choice("Dźwięk", "muted", [[false, "Wł."], [true, "Wył."]])
	_slider("Głośność ogólna", "vol_master", 0.0, 1.0, 0.05, _pct)
	_slider("Muzyka", "vol_music", 0.0, 1.0, 0.05, _pct, "Klub, muzyka z okien bloków, wstęp.")
	_slider("Efekty", "vol_sfx", 0.0, 1.0, 0.05, _pct, "Kroki, drzwi, syrena, dźwięki telefonu i menu.")
	_slider("Otoczenie", "vol_ambient", 0.0, 1.0, 0.05, _pct, "Szum miasta, deszcz, kolejka.")
	_slider("Głosy", "vol_voice", 0.0, 1.0, 0.05, _pct, "Mamrotanie rozmówców.")


func _keys() -> void:
	_slider("Czułość myszy", "sens", 0.3, 2.5, 0.05, _pct)
	_toggle("Odwrócona oś Y", "invert_y")
	_section("KLAWISZE  —  kliknij przycisk, potem naciśnij nowy klawisz")
	for a in G.KEY_ACTIONS:
		var id: String = a[0]
		var h := _row(String(a[1]))
		var waiting := rebind == id
		var b := K.btn("naciśnij klawisz…" if waiting else G.kn(id), func(): rebind = id; render(), "warn" if waiting else "", true)
		b.custom_minimum_size = Vector2(170, 30)
		h.add_child(b)
	body.add_child(K.gap(6))
	var rh := K.hbox(8)
	rh.add_child(K.spacer())
	rh.add_child(K.btn("Przywróć domyślne klawisze", func(): _put("keys", {}); render(), "", true))
	body.add_child(rh)
	hint.text = "Stałe: Esc — pauza / wstecz, Spacja i Enter — dalej w rozmowie, 1–9 — wybór odpowiedzi, strzałki — rozglądanie, F11 — pełny ekran."


func _game() -> void:
	_toggle("Minimapa na ekranie", "minimap", "Domyślnie wyłączona: na ekranie zostaje tylko pasek kondycji. Mapę z trasą masz w telefonie (klawisz %s)." % G.kn("map"))
	var h := _row("Ściąga sterowania", "Pokaż jeszcze raz okno z klawiszami.")
	h.add_child(K.btn("Pokaż", func(): close(); ui.show_controls(), "", true))


## nowy klawisz dla akcji; zwraca true, jeśli zdarzenie zostało zużyte
func take_key(kc: int) -> bool:
	if rebind == "":
		return false
	if kc == KEY_ESCAPE:
		rebind = ""
		render()
		return true
	if kc == KEY_F11 or (kc >= KEY_0 and kc <= KEY_9) or kc == KEY_ENTER or kc == KEY_KP_ENTER:
		hint.text = "Ten klawisz jest zajęty na stałe — wybierz inny."
		return true
	var ks: Dictionary = G.keys.duplicate()
	# klawisz zajęty przez inną akcję: zamiana miejscami
	for a in ks:
		if int(ks[a]) == kc and a != rebind:
			ks[a] = int(ks[rebind])
	ks[rebind] = kc
	var diff := {}
	for a in ks:
		if int(ks[a]) != int(G.KEY_DEFAULTS[a]):
			diff[a] = int(ks[a])
	rebind = ""
	_put("keys", diff)
	render()
	return true
