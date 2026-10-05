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


func build() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	t0_ms = Time.get_ticks_msec()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.027, 0.035, 0.051)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# plansza 16:9 wpasowana w ekran — dokładnie tak, jak silnik rysuje obraz startowy
	var arc := AspectRatioContainer.new()
	arc.ratio = 16.0 / 9.0
	arc.stretch_mode = AspectRatioContainer.STRETCH_FIT
	arc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(arc)
	var frame := Control.new()
	arc.add_child(frame)
	var pic := TextureRect.new()
	pic.texture = load("res://assets/splash.png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(pic)
	# pasek postępu pod podpisem
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.anchor_left = 0.36
	col.anchor_right = 0.64
	col.anchor_top = 0.685
	col.anchor_bottom = 0.685
	col.grow_vertical = Control.GROW_DIRECTION_END
	frame.add_child(col)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.custom_minimum_size = Vector2(0, 4)
	bar.add_theme_stylebox_override("background", K.sb(Color(1, 1, 1, 0.08), 2, Color(0, 0, 0, 0), 0, 0))
	bar.add_theme_stylebox_override("fill", K.sb(K.C_ACC, 2, Color(0, 0, 0, 0), 0, 0))
	col.add_child(bar)
	var row := HBoxContainer.new()
	col.add_child(row)
	var f: Font = load("res://assets/fonts/barlowc.ttf")
	var fv := FontVariation.new()
	fv.base_font = f
	fv.spacing_glyph = 2
	l_status = Label.new()
	l_status.add_theme_font_override("font", fv)
	l_status.add_theme_font_size_override("font_size", 15)
	l_status.add_theme_color_override("font_color", Color(0.58, 0.62, 0.68))
	l_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_status.text = "LOADING"
	row.add_child(l_status)
	l_pct = Label.new()
	l_pct.add_theme_font_override("font", fv)
	l_pct.add_theme_font_size_override("font_size", 15)
	l_pct.add_theme_color_override("font_color", K.C_ACC)
	l_pct.text = "0%"
	row.add_child(l_pct)
	var foot := Label.new()
	foot.add_theme_font_override("font", fv)
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
	foot.text = "EARLY TEST BUILD  •  EVERYTHING HERE IS FICTIONAL"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.anchor_left = 0.0
	foot.anchor_right = 1.0
	foot.anchor_top = 0.93
	foot.anchor_bottom = 0.93
	frame.add_child(foot)


func _process(dt: float) -> void:
	t += dt
	shown = move_toward(shown, target, dt * 90.0)
	bar.value = shown
	l_pct.text = "%d%%" % int(shown)


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
