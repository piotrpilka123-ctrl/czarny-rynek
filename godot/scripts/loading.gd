extends CanvasLayer
## Ekran ładowania: ta sama plansza co obraz startowy silnika (assets/splash.png),
## z paskiem postępu i opisem tego, co właśnie powstaje.

const K = preload("res://scripts/uikit.gd")

var root: Control
var bar: ProgressBar
var l_status: Label
var l_pct: Label
var target := 0.0
var shown := 0.0
var t := 0.0
var t0_ms := 0
var _shot_done := false


## grafiki z gry (assets/loading) z podpisami; kolejność losowana przy każdym uruchomieniu
const ART := [["klub", "CLUB NEON"], ["osiedle", "STEEL BLOCKS"], ["blok", "BLOCK 7  •  21:00"], ["huta", "DEAD MILL"], ["policja", "COP CORNER"],
	["hutnicza", "OLD TOWN"], ["lab", "THE LAB  •  BEFORE"], ["wybuch", "04:47"]]
const TIPS := [
	"Po zmroku trzymaj się z dala od latarni — w cieniu patrol widzi Cię z połowy odległości.",
	"Kucanie wycisza kroki do zera. Bieg słychać z dziewięciu metrów.",
	"Rzucony kamyk odciąga spokojny patrol — na przykład od skrytki z paczką.",
	"W altance śmietnikowej przeczekasz pościg, o ile nikt nie widział, jak się chowasz.",
	"Mieszanka ma znacznik przy czystości i nigdy nie łączy się z czystym towarem.",
	"Tani Zbyszek sprzedaje kota w worku. Skrytkomat kosztuje więcej, ale nigdy nie jest spalony.",
	"Filtr węglowy zbija zapach kryjówki o 60%. Mniej zapachu to mniejsze ryzyko nalotu.",
	"Kominiarka chroni przed świadkami, ale patrol reaguje na nią natychmiast.",
	"Zeszyt u Wiktora ma termin. Po terminie rośnie z każdym dniem.",
	"Nadwyżki z własnej uprawy sprzedasz hurtem na Giełdzie — od 20 gramów.",
	"Przy stole roboczym wybierasz tempo: spokojna robota zabiera czas, pośpiech zabiera towar.",
	"Towar w skrytce jest bezpieczny podczas zatrzymania. Noś tylko tyle, ile sprzedasz.",
	"Każdy klient lubi inny ton rozmowy. Raz odkryty zapisuje się w Kontaktach.",
	"Garnitur podnosi ceny u klientów. W lakierkach za to nie uciekniesz.",
]

var slides: Array = []          # dwa obrazy, między którymi przenikamy
var slide_i := 0
var slide_start := 0.0         # sekunda (od startu ekranu), w której weszła aktualna grafika
var order: Array = []
var l_cap: Label
var l_tip: Label
var plate: TextureRect          # plansza startowa silnika — wygasza się po chwili
var tip_i := 0


func _tex(name: String) -> Texture2D:
	var p := "res://assets/loading/%s.jpg" % name
	return load(p) if ResourceLoader.exists(p) else null


func build() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	t0_ms = Time.get_ticks_msec()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.clip_contents = true
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.027, 0.035, 0.051)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# --- pokaz grafik: dwa obrazy na zmianę, każdy powoli „najeżdża”
	order = range(ART.size())
	order.shuffle()
	for i in range(2):
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.modulate.a = 0.0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tr)
		slides.append(tr)
	# przyciemnienie: od dołu i od lewej, żeby napisy były czytelne na każdym kadrze
	for e in [[Vector2(0.5, 0.0), Vector2(0.5, 1.0), [0.0, 0.45, 1.0], [0.5, 0.12, 0.92]], [Vector2(0.0, 0.5), Vector2(1.0, 0.5), [0.0, 0.5, 1.0], [0.6, 0.1, 0.0]]]:
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array(e[2])
		gr.colors = PackedColorArray([Color(0.01, 0.015, 0.03, e[3][0]), Color(0.01, 0.015, 0.03, e[3][1]), Color(0.01, 0.015, 0.03, e[3][2])])
		var gt := GradientTexture2D.new()
		gt.gradient = gr
		gt.fill_from = e[0]
		gt.fill_to = e[1]
		gt.width = 64
		gt.height = 64
		var sh := TextureRect.new()
		sh.texture = gt
		sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sh.stretch_mode = TextureRect.STRETCH_SCALE
		sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(sh)
	var f: Font = load("res://assets/fonts/barlowc.ttf")
	var fv := FontVariation.new()
	fv.base_font = f
	fv.spacing_glyph = 2
	var fwide := FontVariation.new()
	fwide.base_font = f
	fwide.spacing_glyph = 5
	# --- podpis kadru (prawy górny róg)
	l_cap = Label.new()
	l_cap.add_theme_font_override("font", fwide)
	l_cap.add_theme_font_size_override("font_size", 17)
	l_cap.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	l_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l_cap.anchor_left = 0.5
	l_cap.anchor_right = 0.965
	l_cap.anchor_top = 0.05
	l_cap.anchor_bottom = 0.05
	root.add_child(l_cap)
	# --- tytuł, kreska, podpis autora (lewy dół)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.anchor_left = 0.045
	col.anchor_right = 0.6
	col.anchor_top = 0.9
	col.anchor_bottom = 0.9
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(col)
	var title := Label.new()
	title.text = "CZARNY RYNEK"
	title.add_theme_font_override("font", load("res://assets/fonts/bebas.ttf") if ResourceLoader.exists("res://assets/fonts/bebas.ttf") else f)
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.97))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)
	var line := ColorRect.new()
	line.color = K.C_ACC
	line.custom_minimum_size = Vector2(430, 4)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(line)
	var credit := Label.new()
	credit.text = "A TEST GAME BY PIOTR PIŁKA"
	credit.add_theme_font_override("font", fwide)
	credit.add_theme_font_size_override("font_size", 19)
	credit.add_theme_color_override("font_color", Color(0.74, 0.78, 0.86))
	col.add_child(credit)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	col.add_child(gap)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.custom_minimum_size = Vector2(430, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.add_theme_stylebox_override("background", K.sb(Color(1, 1, 1, 0.14), 2, Color(0, 0, 0, 0), 0, 0))
	bar.add_theme_stylebox_override("fill", K.sb(K.C_ACC, 2, Color(0, 0, 0, 0), 0, 0))
	col.add_child(bar)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(430, 0)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(row)
	l_status = Label.new()
	l_status.add_theme_font_override("font", fv)
	l_status.add_theme_font_size_override("font_size", 15)
	l_status.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8))
	l_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_status.text = "LOADING"
	row.add_child(l_status)
	l_pct = Label.new()
	l_pct.add_theme_font_override("font", fv)
	l_pct.add_theme_font_size_override("font_size", 15)
	l_pct.add_theme_color_override("font_color", K.C_ACC)
	l_pct.text = "0%"
	row.add_child(l_pct)
	# --- wskazówka (prawy dół)
	var tipbox := VBoxContainer.new()
	tipbox.add_theme_constant_override("separation", 4)
	tipbox.anchor_left = 0.62
	tipbox.anchor_right = 0.965
	tipbox.anchor_top = 0.9
	tipbox.anchor_bottom = 0.9
	tipbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(tipbox)
	var th := Label.new()
	th.text = "WSKAZÓWKA"
	th.add_theme_font_override("font", fwide)
	th.add_theme_font_size_override("font_size", 13)
	th.add_theme_color_override("font_color", K.C_ACC)
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tipbox.add_child(th)
	l_tip = Label.new()
	l_tip.add_theme_font_size_override("font_size", 17)
	l_tip.add_theme_color_override("font_color", Color(0.9, 0.91, 0.94))
	l_tip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l_tip.add_theme_constant_override("shadow_offset_y", 1)
	l_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tipbox.add_child(l_tip)
	var foot := Label.new()
	foot.add_theme_font_override("font", fv)
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	foot.text = "EARLY TEST BUILD  •  EVERYTHING HERE IS FICTIONAL"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.anchor_left = 0.0
	foot.anchor_right = 1.0
	foot.anchor_top = 0.955
	foot.anchor_bottom = 0.955
	root.add_child(foot)
	# --- plansza startowa silnika na wierzchu: znika po chwili, odsłaniając grafiki
	var arc := AspectRatioContainer.new()
	arc.ratio = 16.0 / 9.0
	arc.stretch_mode = AspectRatioContainer.STRETCH_FIT
	arc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arc)
	plate = TextureRect.new()
	plate.texture = load("res://assets/splash.png")
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arc.add_child(plate)
	tip_i = randi() % TIPS.size()
	_show_slide(0, true)


## pokazuje kolejną grafikę (przenikanie) i zmienia wskazówkę
func _show_slide(n: int, instant := false) -> void:
	slide_i = n
	slide_start = float(Time.get_ticks_msec() - t0_ms) / 1000.0
	var art: Array = ART[order[n % order.size()]]
	var tex := _tex(String(art[0]))
	var front: TextureRect = slides[n % 2]
	var back: TextureRect = slides[(n + 1) % 2]
	front.texture = tex
	front.scale = Vector2.ONE
	root.move_child(front, 2)
	l_cap.text = String(art[1])
	l_tip.text = TIPS[(tip_i + n) % TIPS.size()]
	if tex == null:
		return
	if instant:
		front.modulate.a = 1.0
		back.modulate.a = 0.0
		return
	front.modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(front, "modulate:a", 1.0, 1.1)
	tw.tween_property(back, "modulate:a", 0.0, 1.1).set_delay(0.2)
	l_cap.modulate.a = 0.0
	l_tip.modulate.a = 0.0
	tw.tween_property(l_cap, "modulate:a", 1.0, 0.8).set_delay(0.4)
	tw.tween_property(l_tip, "modulate:a", 1.0, 0.8).set_delay(0.4)


func _process(dt: float) -> void:
	t += dt
	shown = move_toward(shown, target, dt * 90.0)
	bar.value = shown
	l_pct.text = "%d%%" % int(shown)
	# Świat buduje się na głównym wątku, więc klatek jest mało i są nierówne — wszystko liczymy z zegara.
	var now := float(Time.get_ticks_msec() - t0_ms) / 1000.0
	if plate != null:
		plate.modulate.a = clampf(1.0 - (now - 0.45) / 0.6, 0.0, 1.0)
	# powolny najazd na aktualną grafikę i zmiana co kilka sekund
	for i in range(slides.size()):
		var tr: TextureRect = slides[i]
		tr.pivot_offset = tr.size * (Vector2(0.4, 0.55) if i == 0 else Vector2(0.62, 0.45))
		if i == slide_i % 2:
			tr.scale = Vector2.ONE * (1.0 + (now - slide_start) * 0.012)
	if now - slide_start > 4.6 and target < 99.0:
		_show_slide(slide_i + 1)


## kolejny etap: ustawia opis i postęp, po czym oddaje jedną klatkę, żeby ekran się odświeżył
func step(pct: float, label: String) -> void:
	target = pct
	shown = maxf(shown, pct - 6.0)
	bar.value = shown
	l_pct.text = "%d%%" % int(shown)
	l_status.text = label.to_upper()
	await get_tree().process_frame
	# zrzut ekranu ładowania do podglądu: --loadshot=plik.png
	if G.main != null and G.main.args.has("loadshot") and pct >= 52.0 and not _shot_done:
		_shot_done = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(String(G.main.args.loadshot))


## dopełnia pasek, trzyma planszę co najmniej chwilę i płynnie ją wygasza
func finish() -> void:
	target = 100.0
	l_status.text = "READY"
	while shown < 99.5 or Time.get_ticks_msec() - t0_ms < 1600:
		await get_tree().process_frame
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(root, "modulate:a", 0.0, 0.55)
	await tw.finished
	queue_free()
