extends CanvasLayer
## Interfejs: HUD (kompas, minimapa, wskaźniki), dialogi, telefon, stół roboczy,
## skrytki, sklep, negocjacje, katalog mebli, ekrany tytułowy / pauzy / zakończenia.

const K = preload("res://scripts/uikit.gd")
const Trade = preload("res://scripts/trade.gd")
const Bench = preload("res://scripts/bench.gd")
const StationUI = preload("res://scripts/station_ui.gd")
const Shop = preload("res://scripts/shop_ui.gd")
const PhoneScript = preload("res://scripts/phone.gd")
const InvScript = preload("res://scripts/inventory.gd")
const OptsScript = preload("res://scripts/options.gd")
const Chars = preload("res://scripts/chars.gd")

var mode := "title"        # "" = rozgrywka; dialog | modal | phone | skill | pause | title | end
var root: Control
var hud: Control
var phone: Control
var l_cash: Label
var l_time: Label
var l_lvl: Label
var l_next: Label
var bar_xp: ProgressBar
var bar_stam: ProgressBar
var bar_susp: ProgressBar
var bar_heat: ProgressBar
var l_susp: Label
var l_heat: Label
var l_bag: Label
var ic_weather: TextureRect
var minimap: Control
var compass: Control
var l_nav: RichTextLabel
var last_job := ""             # podpis ostatnio pokazanego zlecenia dnia (żeby karta celu błysnęła przy zmianie)
var l_obj_t: Label
var l_obj: Label
var l_zone: Label
var l_zone_s: Label
var l_day: Label
var sms_banner: PanelContainer
var sms_name: Label
var sms_text: Label
var sms_t := 0.0
var zone_t := 0.0
var last_zone := ""
var prompt: PanelContainer
var l_prompt: RichTextLabel
var prompt_bar: ProgressBar
var chase: PanelContainer
var build_hint: PanelContainer
var l_build: RichTextLabel
var toasts: VBoxContainer
var toast_wrap: Control
var dialog_box: PanelContainer
var d_name: Label
var d_text: RichTextLabel
var d_choices: VBoxContainer
var d_hint: Label
var modal: Control
var cut: Control
var cut_sub: Label
var cut_tbox: VBoxContainer
var cut_title_l: Label
var cut_tsub_l: Label
var cut_tw: Tween = null
var cut_cards_box: VBoxContainer
var lids: Control = null
var lid_k := 0.0
var cross: Control
var aim_on := false
var aim_t := 0.0
var bar_bag: ProgressBar
var ic_next: TextureRect
var inv
var modal_box: PanelContainer
var modal_title: Label
var modal_sub: Label
var modal_scroll: ScrollContainer
var modal_body: VBoxContainer
var modal_v: VBoxContainer
var modal_head_extra: HBoxContainer
var modal_foot: VBoxContainer          # stopka pod przewijaną treścią (opis pozycji w sklepach)
var modal_close: Button
var shop_hint: Label = null
var modal_dock := "center"
var deal_said := ""
var deal_npc = null
var skill_box: PanelContainer
var skill_bar: Control
var l_skill_t: Label
var l_skill_p: Label
var l_skill_w: Label
var fade_rect: ColorRect
var hurt_rect: ColorRect
var screen: Control
var screen_box: VBoxContainer

var dlg := {}
var deal := {}
var sk := {}
var bench := {"room": "", "sel": {}, "g": 1, "n": 9999, "mixing": false, "filler": 1}
var station := {}
var hud_t := 0.0
var nav_info := {}
var cop_bar: ProgressBar = null
var deal_fill: ColorRect = null      # pasek przytrzymania przy podawaniu towaru
var deal_watch_l: Label = null
var deal_cop_l: Control = null
var deal_holding := false
var modal_hrow: HBoxContainer
var modal_head: HBoxContainer
var modal_inner: VBoxContainer
var deal_side: PanelContainer          # lewa strona okna wymiany: to, co masz przy sobie
var deal_side_body: VBoxContainer
var deal_zone: Control = null          # taca — pole zrzutu
var deal_zone_hot := false
var deal_ask := {}                     # okienko „ile paczek położyć”
var deal_ask_box: Control = null
var tip_box: Control = null          # karta „pierwszy raz” (najwyżej jedna naraz)
var waymark: Control
var mini_card: PanelContainer
var ic_stance: TextureRect
var shout_l: Label = null
var shout_tw: Tween = null
var flash_rect: ColorRect = null
var aware_cv: Control
var susp_box: VBoxContainer
var obj_card: PanelContainer
var sms_key: Label
var obj_t := 0.0
var last_obj := ""
var menu_root: Control = null
var controls_back := ""
var opts


# ================================================================ budowa
func build() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = K.theme()
	add_child(root)
	_build_hud()
	_build_dialog()
	phone = PhoneScript.new()
	root.add_child(phone)
	phone.build(self)
	_build_modal()
	inv = InvScript.new()
	root.add_child(inv)
	inv.build(self)
	_build_skill()
	hurt_rect = ColorRect.new()
	hurt_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_rect)
	screen = ColorRect.new()
	(screen as ColorRect).color = Color(0.02, 0.03, 0.05, 0.66)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(cc)
	screen_box = K.vbox(14)
	screen_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(screen_box)
	opts = OptsScript.new()
	root.add_child(opts)
	opts.build(self)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	_build_cut()
	G.toast.connect(toast_add)
	G.sms.connect(_on_sms)


func _ign(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ---------------------------------------------------------------- HUD
func _shadow(c: Control, size := 4) -> void:
	c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	c.add_theme_constant_override("shadow_offset_x", 1)
	c.add_theme_constant_override("shadow_offset_y", 1)
	c.add_theme_constant_override("shadow_outline_size", size)


## wspólny styl kart HUD-u: ciemne, półprzezroczyste, z delikatną ramką i cieniem
func _hud_card() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.078, 0.8)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.09)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.content_margin_left = 13
	sb.content_margin_right = 13
	sb.content_margin_top = 9
	sb.content_margin_bottom = 10
	return sb


func _thin_bar(color: Color, w := 0.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.custom_minimum_size = Vector2(w, 5)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("background", K.pill(Color(0, 0, 0, 0.55), 2))
	b.add_theme_stylebox_override("fill", K.pill(color, 2))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _bar_row(parent: Node, ic: String, color: Color) -> ProgressBar:
	var h := K.hbox(6)
	_ign(h)
	h.add_child(K.icon(ic, 13, Color(1, 1, 1, 0.85)))
	var b := _thin_bar(color)
	h.add_child(b)
	parent.add_child(h)
	return b


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	root.add_child(hud)

	# --- lewy dolny róg: tylko pasek kondycji (i minimapa, jeśli ktoś ją włączy w Opcjach)
	var bl := K.vbox(8)
	bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 22.0
	bl.offset_bottom = -20.0
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ign(bl)
	hud.add_child(bl)
	mini_card = K.panel(_hud_card())
	_ign(mini_card)
	mini_card.visible = false
	bl.add_child(mini_card)
	var mv := K.vbox(6)
	_ign(mv)
	mini_card.add_child(mv)
	var zrow := K.hbox(5)
	_ign(zrow)
	zrow.add_child(K.icon("map_pin", 12, K.C_ACC))
	l_zone_s = K.head("", 13, K.C_TXT)
	zrow.add_child(l_zone_s)
	mv.add_child(zrow)
	var mp := K.panel(K.sb(Color(0.03, 0.035, 0.05, 1.0), 10, Color(0, 0, 0, 0), 0, 0))
	mp.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_ign(mp)
	mv.add_child(mp)
	minimap = Control.new()
	minimap.custom_minimum_size = Vector2(190, 190)
	minimap.clip_contents = true
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_mini)
	mp.add_child(minimap)
	var strow := K.hbox(8)
	_ign(strow)
	ic_stance = K.icon("footprints", 16, Color(1, 1, 1, 0.9))
	strow.add_child(ic_stance)
	bar_stam = _thin_bar(Color(0.93, 0.95, 0.98))
	bar_stam.custom_minimum_size = Vector2(210, 6)
	bar_stam.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	strow.add_child(bar_stam)
	bl.add_child(strow)

	# --- środek u góry: „oko” — pojawia się dopiero, gdy patrol zaczyna się Tobie przyglądać
	susp_box = K.vbox(3)
	susp_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	susp_box.offset_left = -110.0
	susp_box.offset_right = 110.0
	susp_box.offset_top = 22.0
	susp_box.visible = false
	_ign(susp_box)
	hud.add_child(susp_box)
	var erow := K.hbox(8)
	erow.alignment = BoxContainer.ALIGNMENT_CENTER
	_ign(erow)
	erow.add_child(K.icon("eye", 18, K.C_WARN))
	bar_susp = _thin_bar(K.C_WARN)
	bar_susp.custom_minimum_size = Vector2(150, 6)
	bar_susp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	erow.add_child(bar_susp)
	susp_box.add_child(erow)
	l_susp = K.head("", 13, K.C_BAD)
	l_susp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadow(l_susp)
	susp_box.add_child(l_susp)
	l_zone = K.head("", 22, Color(1, 1, 1, 0.0))
	l_zone.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l_zone.offset_left = -300.0
	l_zone.offset_right = 300.0
	l_zone.offset_top = 74.0
	l_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadow(l_zone, 6)
	hud.add_child(l_zone)

	# --- lewy górny róg: cel — wysuwa się na kilka sekund, gdy się zmieni (albo na życzenie)
	obj_card = K.panel(_hud_card())
	obj_card.position = Vector2(22, 20)
	obj_card.visible = false
	_ign(obj_card)
	hud.add_child(obj_card)
	var ob := K.hbox(10)
	_ign(ob)
	obj_card.add_child(ob)
	var acc := ColorRect.new()
	acc.color = K.C_ACC
	acc.custom_minimum_size = Vector2(3, 0)
	acc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ob.add_child(acc)
	var opv := K.vbox(2)
	_ign(opv)
	l_obj_t = K.head("CEL", 12, K.C_ACC)
	l_obj = K.wrap("", 15, Color.WHITE, 360.0)
	l_nav = K.rich("", 12)
	l_nav.custom_minimum_size = Vector2(360, 0)
	opv.add_child(l_obj_t)
	opv.add_child(l_obj)
	opv.add_child(l_nav)
	ob.add_child(opv)

	# --- powiadomienie o wiadomości — jak na ekranie telefonu
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	sbox.set_corner_radius_all(16)
	sbox.set_border_width_all(1)
	sbox.border_color = Color(1, 1, 1, 0.1)
	sbox.shadow_color = Color(0, 0, 0, 0.45)
	sbox.shadow_size = 10
	sbox.content_margin_left = 12
	sbox.content_margin_right = 14
	sbox.content_margin_top = 9
	sbox.content_margin_bottom = 9
	sms_banner = K.panel(sbox)
	sms_banner.visible = false
	sms_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	sms_banner.offset_left = -338.0
	sms_banner.offset_right = -18.0
	sms_banner.offset_top = 20.0
	_ign(sms_banner)
	hud.add_child(sms_banner)
	var sh := K.hbox(11)
	sms_banner.add_child(sh)
	var app_ic := K.panel(K.sb(Color(0.2, 0.72, 0.38), 10, Color(0, 0, 0, 0), 0, 7))
	app_ic.custom_minimum_size = Vector2(36, 36)
	app_ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	app_ic.add_child(K.icon("message_circle", 20, Color.WHITE))
	sh.add_child(app_ic)
	var smv := K.vbox(1)
	smv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var srow := K.hbox(6)
	sms_name = K.lbl("", 14, Color.WHITE)
	srow.add_child(sms_name)
	srow.add_child(K.spacer())
	var kc := K.panel(K.sb(Color(1, 1, 1, 0.1), 5, Color(1, 1, 1, 0.2), 1, 6))
	sms_key = K.lbl("Tab", 10, K.C_TXT)
	kc.add_child(sms_key)
	srow.add_child(kc)
	smv.add_child(srow)
	sms_text = K.wrap("", 13, Color(0.82, 0.84, 0.88), 230.0)
	sms_text.max_lines_visible = 3
	smv.add_child(sms_text)
	sh.add_child(smv)

	# --- znacznik celu w świecie
	# łuki wokół celownika: z której strony patrol zaczyna Cię zauważać
	aware_cv = Control.new()
	aware_cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	aware_cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aware_cv.draw.connect(_draw_aware)
	hud.add_child(aware_cv)
	waymark = Control.new()
	waymark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waymark.draw.connect(_draw_way)
	waymark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(waymark)

	# --- celownik, podpowiedź
	cross = Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(_draw_cross)
	hud.add_child(cross)
	var pc := CenterContainer.new()
	pc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pc.offset_top = 150.0
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(pc)
	prompt = K.panel(K.sb(Color(0, 0, 0, 0.62), 10, Color(1, 1, 1, 0.12), 1, 14))
	prompt.visible = false
	_ign(prompt)
	pc.add_child(prompt)
	var pv := K.vbox(5)
	prompt.add_child(pv)
	l_prompt = K.rich("", 16)
	l_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	l_prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(l_prompt)
	prompt_bar = K.bar(0.0, 1.0, K.C_ACC, 5.0)
	prompt_bar.visible = false
	pv.add_child(prompt_bar)
	_build_aim_menu()

	var tc := CenterContainer.new()
	tc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tc.offset_top = 96.0
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tc)
	chase = K.panel(K.sb(Color(0.7, 0.1, 0.1, 0.9), 10, Color(1, 0.8, 0.8, 0.6), 1, 16))
	var chh := K.hbox(8)
	chh.add_child(K.icon("siren", 18, Color.WHITE))
	chh.add_child(K.head("POŚCIG — zgub policję albo schowaj się w budynku", 16, Color.WHITE))
	chase.add_child(chh)
	chase.visible = false
	tc.add_child(chase)

	var bc := CenterContainer.new()
	bc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bc.offset_top = -92.0
	bc.offset_bottom = -22.0
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bc)
	build_hint = K.panel(K.sb(Color(0.03, 0.04, 0.06, 0.9), 12, K.C_BLUE, 1, 14))
	build_hint.visible = false
	bc.add_child(build_hint)
	l_build = K.rich("", 14)
	l_build.autowrap_mode = TextServer.AUTOWRAP_OFF
	build_hint.add_child(l_build)

	var tcc := CenterContainer.new()
	tcc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tcc.offset_top = -230.0
	tcc.offset_bottom = -110.0
	tcc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# powiadomienia rysują się nad oknami (sprzedaż, plecak) — inaczej okno by je zasłoniło
	tcc.z_index = 55
	root.add_child(tcc)
	toast_wrap = tcc
	toasts = K.vbox(5)
	toasts.alignment = BoxContainer.ALIGNMENT_END
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tcc.add_child(toasts)


## Karta „pierwszy raz”: wysuwa się u góry ekranu ponad wszystkim (także nad plecakiem i telefonem),
## zostaje kilkanaście sekund albo do kliknięcia. Kolejna karta zastępuje poprzednią.
func tip_show(title: String, text: String, secs := 11.0) -> void:
	if tip_box != null and is_instance_valid(tip_box):
		tip_box.queue_free()
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cc.offset_top = 14.0
	cc.offset_bottom = 150.0
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.z_index = 60
	root.add_child(cc)
	tip_box = cc
	# podpowiedź to nie ostrzeżenie: grafitowa karta z cienką jasną ramką (bez niebieskiego i żółtego)
	var p := K.panel(K.sb(Color(0.04, 0.046, 0.058, 0.96), 12, Color(1, 1, 1, 0.24), 1, 14))
	p.custom_minimum_size = Vector2(620, 0)
	cc.add_child(p)
	var h := K.hbox(12)
	p.add_child(h)
	var ic := K.icon("lightbulb", 26.0, Color(0.82, 0.84, 0.88))
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var v := K.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(K.lbl("PIERWSZY RAZ  •  " + title.to_upper(), 11, K.C_DIM))
	v.add_child(K.wrap(text, 14, K.C_TXT, 540.0))
	var xb := K.btn("", func(): cc.queue_free(), "flat", true)
	xb.icon = K.tex("x")
	xb.add_theme_constant_override("icon_max_width", 13)
	xb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(xb)
	Sfx.play("open")
	cc.modulate.a = 0.0
	# przy otwartym ekwipunku karta siada na dole, żeby nie zasłaniać zakładek, nazw paneli i pojemności
	var low: bool = inv != null and inv.visible
	if low:
		cc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		cc.offset_bottom = -2.0
		cc.offset_top = -80.0
	else:
		cc.offset_top = -60.0
	# animacja należy do karty: gdy kartę zastąpi następna, ta po prostu znika razem z nią
	var tw := cc.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(cc, "modulate:a", 1.0, 0.25)
	tw.tween_property(cc, "offset_top", -124.0 if low else 14.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(secs)
	tw.chain().tween_property(cc, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(cc.queue_free)


## Powiadomienia idą po kolei, jedno naraz: ważniejsze wcześniej, a każde wisi tyle, ile trzeba na przeczytanie
## (dłuższy tekst — dłużej). Powtórki nie wchodzą do kolejki; gdy robi się tłok, wypadają najmniej ważne.
const TOAST_RANK := {"bad": 4, "level": 3, "warn": 2, "good": 1, "": 0}
var toast_q: Array = []
var toast_t := 0.0
var toast_now := ""

func toast_add(text: String, kind: String) -> void:
	if text == toast_now:
		return
	for q in toast_q:
		if String(q.text) == text:
			return
	toast_q.append({"text": text, "kind": kind})
	# kolejka ma najwyżej cztery pozycje: wypada najstarsza z najmniej ważnych
	while toast_q.size() > 4:
		var worst := 0
		for i in range(toast_q.size()):
			if int(TOAST_RANK.get(String(toast_q[i].kind), 0)) < int(TOAST_RANK.get(String(toast_q[worst].kind), 0)):
				worst = i
		toast_q.remove_at(worst)
	if kind == "bad":
		Sfx.play("bad")


func _toast_tick(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
		if toast_t <= 0.0:
			for c in toasts.get_children():
				c.queue_free()
			toast_now = ""
			toast_t = -0.25
		return
	if toast_t < 0.0:
		# krótki oddech między powiadomieniami
		toast_t = minf(0.0, toast_t + dt)
		return
	if toast_q.is_empty() or not toasts.visible:
		return
	var best := 0
	for i in range(toast_q.size()):
		if int(TOAST_RANK.get(String(toast_q[i].kind), 0)) > int(TOAST_RANK.get(String(toast_q[best].kind), 0)):
			best = i
	var t: Dictionary = toast_q[best]
	toast_q.remove_at(best)
	_toast_show(String(t.text), String(t.kind))
	toast_now = String(t.text)
	var secs := clampf(1.5 + String(t.text).length() * 0.05, 2.4, 7.0)
	if String(t.kind) == "bad" or String(t.kind) == "level":
		secs *= 1.2
	# gdy czekają następne, bieżące schodzi trochę szybciej
	toast_t = secs * (0.8 if not toast_q.is_empty() else 1.0)


func _toast_show(text: String, kind: String) -> void:
	var border := Color(1, 1, 1, 0.12)
	var fc := K.C_TXT
	var ic := "info"
	match kind:
		"good": border = Color(1, 1, 1, 0.32); fc = K.C_TXT; ic = "circle_check"
		"warn": border = K.C_WARN; fc = Color(0.99, 0.9, 0.55); ic = "triangle_alert"
		"bad": border = K.C_BAD; fc = Color(1.0, 0.8, 0.8); ic = "siren"
		"level": border = K.C_GOLD; fc = K.C_GOLD; ic = "award"
	var p := K.panel(K.sb(Color(0.036, 0.04, 0.05, 0.93) if kind != "level" else Color(0.14, 0.11, 0.03, 0.95), 10, border, 1, 14))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := K.hbox(8)
	h.add_child(K.icon(ic, 16, border if kind != "" else K.C_DIM))
	var l := K.lbl(text, 16 if kind == "level" else 13, fc)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(520.0, 30.0 + text.length() * 7.6), 0)
	h.add_child(l)
	p.add_child(h)
	toasts.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(p, "modulate:a", 1.0, 0.18)


func _on_sms(cid: String, text: String) -> void:
	sms_name.text = G.contact_name(cid)
	sms_text.text = text if text.length() < 110 else text.substr(0, 108) + "…"
	sms_banner.visible = true
	sms_banner.modulate.a = 0.0
	sms_banner.offset_left = -280.0
	sms_banner.offset_right = 40.0
	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sms_banner, "offset_left", -340.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sms_banner, "offset_right", -20.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sms_banner, "modulate:a", 1.0, 0.2)
	sms_t = 7.0
	if phone.visible:
		phone.refresh()


# ---------------------------------------------------------------- przerywnik filmowy (wstęp)
func _build_cut() -> void:
	cut = Control.new()
	cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.visible = false
	root.add_child(cut)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = 70.0
		else:
			bar.offset_top = -92.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut.add_child(bar)
	cut_sub = Label.new()
	cut_sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cut_sub.offset_top = -88.0
	cut_sub.offset_bottom = -6.0
	cut_sub.offset_left = 150.0
	cut_sub.offset_right = -150.0
	cut_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cut_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cut_sub.add_theme_font_size_override("font_size", 22)
	cut_sub.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))
	cut_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	cut_sub.add_theme_constant_override("shadow_outline_size", 8)
	cut_sub.modulate.a = 0.0
	cut.add_child(cut_sub)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.add_child(cc)
	cut_tbox = K.vbox(6)
	cut_tbox.modulate.a = 0.0
	cc.add_child(cut_tbox)
	cut_title_l = Label.new()
	cut_title_l.add_theme_font_override("font", load("res://assets/fonts/bebas.ttf"))
	cut_title_l.add_theme_font_size_override("font_size", 92)
	cut_title_l.add_theme_color_override("font_color", Color(0.96, 0.96, 0.94))
	cut_title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_tbox.add_child(cut_title_l)
	var ln := ColorRect.new()
	ln.color = K.C_ACC
	ln.custom_minimum_size = Vector2(0, 3)
	cut_tbox.add_child(ln)
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/barlowc.ttf")
	fv.spacing_glyph = 4
	cut_tsub_l = Label.new()
	cut_tsub_l.add_theme_font_override("font", fv)
	cut_tsub_l.add_theme_font_size_override("font_size", 19)
	cut_tsub_l.add_theme_color_override("font_color", Color(0.75, 0.79, 0.84))
	cut_tsub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_tbox.add_child(cut_tsub_l)
	cut_cards_box = K.vbox(8)
	cut_cards_box.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	cut_cards_box.offset_left = 48.0
	cut_cards_box.offset_right = 340.0
	cut_cards_box.offset_top = 86.0
	cut_cards_box.offset_bottom = -108.0
	cut_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cut_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.add_child(cut_cards_box)
	var skip := K.lbl("Spacja — pomiń", 12, Color(1, 1, 1, 0.38))
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -150.0
	skip.offset_right = -22.0
	skip.offset_top = -30.0
	skip.offset_bottom = -10.0
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cut.add_child(skip)


## Powieki bohatera (przebudzenie): k = 1 — oczy zamknięte, 0 — otwarte. Dwie czarne zasłony z miękką krawędzią
## schodzą się od góry i od dołu; rysują się pod pasami i napisami przerywnika.
func set_lids(k: float) -> void:
	if lids == null:
		if k <= 0.001:
			return
		lids = Control.new()
		lids.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lids.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lids)
		root.move_child(lids, cut.get_index())
		for top in [true, false]:
			var g := Gradient.new()
			g.set_color(0, Color.BLACK)
			g.set_color(1, Color(0, 0, 0, 0))
			g.set_offset(0, 0.76)
			g.set_offset(1, 1.0)
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.width = 4
			gt.height = 128
			gt.fill_from = Vector2(0, 0) if top else Vector2(0, 1)
			gt.fill_to = Vector2(0, 1) if top else Vector2(0, 0)
			var tr := TextureRect.new()
			tr.texture = gt
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
			lids.add_child(tr)
	lids.visible = k > 0.001
	lid_k = clampf(k, 0.0, 1.0)
	var h := root.size.y * 0.67 * lid_k
	(lids.get_child(0) as Control).offset_bottom = h
	(lids.get_child(1) as Control).offset_top = -h


func cut_begin() -> void:
	cut.visible = true
	hud.visible = false
	# powiadomienia nie zasłaniają kadru — to, co ważne, i tak trafia do telefonu
	toasts.visible = false
	cut_cards([])
	cut_sub.modulate.a = 0.0
	cut_sub.text = ""
	cut_tbox.modulate.a = 0.0


func cut_end() -> void:
	cut.visible = false
	toasts.visible = true
	cut_cards([])
	if G.running and not G.test_hide_hud:
		hud.visible = true


## napis narracji na dole; pusty tekst = wygaszenie
func cut_line(text: String) -> void:
	if cut_tw != null and cut_tw.is_valid():
		cut_tw.kill()
	cut_tw = create_tween()
	cut_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	cut_tw.tween_property(cut_sub, "modulate:a", 0.0, 0.3)
	if text != "":
		cut_tw.tween_callback(func(): cut_sub.text = text)
		cut_tw.tween_property(cut_sub, "modulate:a", 1.0, 0.5)


## Karty z boku kadru: co w pokazywanym miejscu kupisz albo załatwisz. Wjeżdżają jedna po drugiej;
## pusta lista = wygaszenie poprzednich. Karta: {"icon", "name", "sub"}.
func cut_cards(cards: Array) -> void:
	for old in cut_cards_box.get_children():
		var tw0 := old.create_tween()
		tw0.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw0.tween_property(old, "modulate:a", 0.0, 0.25)
		tw0.tween_callback(old.queue_free)
	var i := 0
	for c in cards:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(292, 62)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut_cards_box.add_child(slot)
		var p := K.panel(K.sb(Color(0.035, 0.045, 0.065, 0.9), 10, Color(1, 1, 1, 0.14), 1, 10))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size = Vector2(292, 62)
		p.position = Vector2(-70, 0)
		p.modulate.a = 0.0
		slot.add_child(p)
		var h := K.hbox(12)
		p.add_child(h)
		var ic := String(c.get("icon", "info"))
		var ibox := CenterContainer.new()
		ibox.custom_minimum_size = Vector2(42, 42)
		ibox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ibox.add_child(K.icon(ic, 42.0 if K.is_item(ic) else 28.0, K.C_ACC))
		h.add_child(ibox)
		var v := K.vbox(1)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var nl := K.lbl(String(c.get("name", "")), 16, Color(0.96, 0.96, 0.94))
		nl.clip_text = true
		v.add_child(nl)
		var sl := K.lbl(String(c.get("sub", "")), 12, Color(0.72, 0.77, 0.84))
		sl.clip_text = true
		v.add_child(sl)
		var tw := p.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(0.3 + 0.55 * i)
		tw.set_parallel(true)
		tw.tween_property(p, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 1.0, 0.3)
		i += 1


## plansza na środku ekranu; pusty tekst = wygaszenie
func cut_title(text: String, sub := "") -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if text == "":
		tw.tween_property(cut_tbox, "modulate:a", 0.0, 0.5)
		return
	cut_title_l.text = text
	cut_tsub_l.text = sub
	cut_tbox.scale = Vector2(1.06, 1.06)
	cut_tbox.pivot_offset = cut_tbox.size * 0.5
	tw.set_parallel(true)
	tw.tween_property(cut_tbox, "modulate:a", 1.0, 0.25)
	tw.tween_property(cut_tbox, "scale", Vector2.ONE, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## płynne ściemnienie / rozjaśnienie w zadanym czasie
func fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade_rect, "color:a", a, dur)
	await tw.finished


func fade(on: bool) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade_rect, "color:a", 1.0 if on else 0.0, 0.45)
	await tw.finished


## krótki okrzyk na środku ekranu (megafon policji)
func shout(text: String, secs := 3.2) -> void:
	if shout_l == null:
		shout_l = K.head("", 34, Color(1.0, 0.9, 0.85))
		shout_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		shout_l.offset_left = -600.0
		shout_l.offset_right = 600.0
		shout_l.offset_top = 150.0
		shout_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shout_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shadow(shout_l)
		root.add_child(shout_l)
	shout_l.text = text
	shout_l.modulate.a = 0.0
	if shout_tw != null and shout_tw.is_valid():
		shout_tw.kill()
	shout_tw = create_tween()
	shout_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shout_tw.tween_property(shout_l, "modulate:a", 1.0, 0.12)
	shout_tw.tween_interval(secs)
	shout_tw.tween_property(shout_l, "modulate:a", 0.0, 0.6)


## biały błysk (eksplozja)
func flash(a := 0.5) -> void:
	if flash_rect == null:
		flash_rect = ColorRect.new()
		flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_rect.color = Color(1.0, 0.92, 0.8, 0.0)
		root.add_child(flash_rect)
	flash_rect.color.a = a
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.9)


func hurt() -> void:
	hurt_rect.color.a = 0.45
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(hurt_rect, "color:a", 0.0, 0.6)
	if G.player != null:
		G.player.shake = 1.0


# ---------------------------------------------------------------- tryby
## tryby, w których gra naprawdę stoi; w pozostałych (dialog, phone, modal, skill, inv) czas płynie dalej
const HARD_PAUSE := ["pause", "options", "controls", "title", "end"]

func set_mode(m: String) -> void:
	mode = m
	if G.running and not G.test_hide_hud and m != "title" and m != "end":
		hud.visible = not (m in ["inv", "modal", "pause", "controls", "options"])
	# rozmowa, telefon, plecak i handel dzieją się w biegnącym świecie — gra staje tylko w menu
	get_tree().paused = m in HARD_PAUSE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (m != "" or G.test_mode) else Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return mode != ""


## Coś z zewnątrz przerywa to, co gracz ma otwarte (patrol, nalot): okno się zamyka,
## a rozmowa z umówionym klientem zostaje „na potem” — nic nie przepada.
func interrupt() -> void:
	if mode == "" or mode in HARD_PAUSE:
		return
	if not deal.is_empty() and not deal.get("over", false):
		G.deal_pause(deal)
	close_all()


func close_all() -> void:
	dialog_box.visible = false
	modal.visible = false
	skill_box.visible = false
	screen.visible = false
	phone.visible = false
	if inv.visible:
		inv.close()
	opts.visible = false
	if menu_root != null and is_instance_valid(menu_root):
		menu_root.queue_free()
		menu_root = null
	_deal_unstage()
	dlg = {}
	deal = {}
	sk = {}
	cop_bar = null
	set_mode("")


# ---------------------------------------------------------------- dialog
func _build_dialog() -> void:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	c.offset_top = -300.0
	c.offset_bottom = -30.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	dialog_box = K.panel(K.sb(K.C_PANEL, 14, K.C_LINE, 1, 22))
	dialog_box.custom_minimum_size = Vector2(800, 0)
	dialog_box.visible = false
	c.add_child(dialog_box)
	var v := K.vbox(8)
	dialog_box.add_child(v)
	d_name = K.lbl("", 13, K.C_WARN)
	v.add_child(d_name)
	d_text = K.rich("", 19)
	d_text.custom_minimum_size = Vector2(760, 56)
	v.add_child(d_text)
	d_choices = K.vbox(6)
	v.add_child(d_choices)
	d_hint = K.lbl("Spacja / Enter — dalej", 11, K.C_DIM)
	d_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(d_hint)


## d: {name, lines: [String | {n,t}], choices: [{label, act, disabled, kind}], on_end: Callable}
func dialog(d: Dictionary) -> void:
	var lines := []
	for l in d.lines:
		if l is String:
			lines.append({"n": d.get("name", ""), "t": l})
		else:
			lines.append({"n": l.get("n", d.get("name", "")), "t": l.t})
	var nm := String(d.get("name", ""))
	# każdy rozmówca ma własną wysokość głosu (z imienia); kobiece imiona brzmią wyżej
	var last := nm.get_slice(" ", nm.get_slice_count(" ") - 1).to_lower()
	var fem: bool = last.ends_with("a") and not last in ["kuba", "numer"]
	var voice: float = d.get("voice", (1.26 if fem else 0.8) + float(absi(nm.hash()) % 30) / 100.0)
	dlg = {"lines": lines, "i": 0, "choices": d.get("choices", []), "on_end": d.get("on_end", Callable()), "typed": 0.0, "done": false, "voice": voice, "said": 0}
	modal.visible = false
	skill_box.visible = false
	phone.visible = false
	dialog_box.visible = true
	set_mode("dialog")
	Sfx.play("open")
	_show_line()


func _show_line() -> void:
	var l: Dictionary = dlg.lines[dlg.i]
	d_name.text = String(l.n).to_upper()
	d_text.text = l.t
	d_text.visible_characters = 0
	dlg.typed = 0.0
	dlg.said = 0
	dlg.done = false
	K.clear(d_choices)
	d_hint.visible = true


func _line_done() -> void:
	dlg.done = true
	d_text.visible_characters = -1
	if int(dlg.i) == dlg.lines.size() - 1 and not dlg.choices.is_empty():
		d_hint.visible = false
		var idx := 0
		for c in dlg.choices:
			var i := idx
			var b := K.btn("%d. %s" % [idx + 1, c.label], func(): pick_choice(i), c.get("kind", ""))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = c.get("disabled", false)
			d_choices.add_child(b)
			idx += 1


func advance() -> void:
	if dlg.is_empty():
		return
	if not dlg.done:
		_line_done()
		return
	if int(dlg.i) < dlg.lines.size() - 1:
		dlg.i = int(dlg.i) + 1
		_show_line()
		return
	if not dlg.choices.is_empty():
		return
	var cb: Callable = dlg.on_end
	close_all()
	if cb.is_valid():
		cb.call()


func pick_choice(i: int) -> void:
	if dlg.is_empty() or not dlg.done or i >= dlg.choices.size():
		return
	var c: Dictionary = dlg.choices[i]
	if c.get("disabled", false):
		return
	close_all()
	if c.has("act"):
		c.act.call()


# ---------------------------------------------------------------- okno modalne
func _build_modal() -> void:
	modal = ColorRect.new()
	(modal as ColorRect).color = Color(0, 0, 0, 0.5)
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	root.add_child(modal)
	var mg := MarginContainer.new()
	mg.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 22)
	modal.add_child(mg)
	modal_v = K.vbox(0)
	modal_v.alignment = BoxContainer.ALIGNMENT_CENTER
	mg.add_child(modal_v)
	var hrow := K.hbox(14)
	hrow.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_v.add_child(hrow)
	modal_hrow = hrow
	deal_side = K.panel(Trade.panel_style(12))
	deal_side.custom_minimum_size = Vector2(312, 400)
	deal_side.visible = false
	hrow.add_child(deal_side)
	deal_side_body = K.vbox(8)
	deal_side.add_child(deal_side_body)
	modal_box = K.panel(K.sb(Color(0.045, 0.055, 0.08, 0.97), 16, Color(1, 1, 1, 0.1), 1, 20))
	modal_box.custom_minimum_size = Vector2(900, 0)
	hrow.add_child(modal_box)
	var v := K.vbox(10)
	modal_box.add_child(v)
	modal_inner = v
	var head := K.hbox()
	modal_head = head
	var hv := K.vbox(0)
	modal_title = K.head("", 26)
	modal_sub = K.lbl("", 12, K.C_DIM)
	hv.add_child(modal_title)
	hv.add_child(modal_sub)
	head.add_child(hv)
	head.add_child(K.spacer())
	modal_head_extra = K.hbox(14)
	head.add_child(modal_head_extra)
	modal_close = K.btn("Zamknij  [Esc]", _modal_close, "", true)
	head.add_child(modal_close)
	v.add_child(head)
	modal_scroll = ScrollContainer.new()
	modal_scroll.custom_minimum_size = Vector2(856, 120)
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(modal_scroll)
	modal_body = K.vbox(8)
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_scroll.add_child(modal_body)
	modal_foot = K.vbox(6)
	v.add_child(modal_foot)


## okno dopasowuje wysokość do treści (do maksimum zależnego od ekranu)
func _fit_modal() -> void:
	var max_h := root.size.y - (150.0 if modal_dock == "center" else 170.0) - modal_foot.get_combined_minimum_size().y
	var want := clampf(modal_body.get_combined_minimum_size().y, 60.0, max_h)
	if absf(modal_scroll.custom_minimum_size.y - want) > 0.5:
		modal_scroll.custom_minimum_size.y = want


func _modal_close() -> void:
	if not deal.is_empty():
		# zamknięcie okna rozmowy z umówionym klientem = „zaraz wracam” (nic nie przepada)
		G.deal_pause(deal)
	close_all()


func _open_modal(title: String, sub := "", dock := "center", width := 900.0, minimal := false) -> void:
	dialog_box.visible = false
	skill_box.visible = false
	phone.visible = false
	modal.visible = true
	modal_dock = dock
	# "bottom" — okno przy dolnej krawędzi; "deal" — to samo plus lista „przy sobie” po lewej
	var low := dock == "bottom" or dock == "deal"
	modal_v.alignment = BoxContainer.ALIGNMENT_END if low else BoxContainer.ALIGNMENT_CENTER
	(modal as ColorRect).color = Color(0, 0, 0, 0.16 if low else 0.6)
	deal_side.visible = dock == "deal"
	K.clear(deal_side_body)
	Trade.ask_close(self)
	deal_zone = null
	# okno wymiany jest ciasne: bez dużego tytułu, z wąskimi marginesami i mniejszymi odstępami
	var tight := dock == "deal"
	modal_head.visible = not tight
	modal_box.add_theme_stylebox_override("panel", Trade.panel_style(12) if tight else (Trade.panel_style(18) if minimal else K.sb(Color(0.042, 0.047, 0.059, 0.97), 16, Color(1, 1, 1, 0.1), 1, 20)))
	# okna sklepów: mniejszy tytuł i mały przycisk zamknięcia, jak w ekwipunku
	modal_title.add_theme_font_size_override("font_size", 19 if minimal else 26)
	modal_close.text = "Esc" if minimal else "Zamknij  [Esc]"
	for st in ["normal", "hover", "pressed"]:
		if minimal:
			modal_close.add_theme_stylebox_override(st, Trade._flat(0.035 if st == "normal" else 0.09, 0.13 if st == "normal" else 0.24))
		else:
			modal_close.remove_theme_stylebox_override(st)
	if not minimal:
		modal_close.add_theme_stylebox_override("normal", K.sb(Color(1, 1, 1, 0.04), 7, Color(1, 1, 1, 0.13), 1, 8))
		modal_close.add_theme_stylebox_override("hover", K.sb(Color(1, 1, 1, 0.09), 7, Color(1, 1, 1, 0.24), 1, 8))
	K.clear(modal_foot)
	shop_hint = null
	modal_inner.add_theme_constant_override("separation", 0 if tight else 10)
	modal_body.add_theme_constant_override("separation", 6 if tight else 8)
	modal_hrow.add_theme_constant_override("separation", 10 if tight else 14)
	# ekwipunek po lewej jest wysoki, panel sprzedaży mały — siedzi przy dolnej krawędzi i nie rozciąga się za nim
	modal_box.size_flags_vertical = Control.SIZE_SHRINK_END if tight else Control.SIZE_FILL
	modal_box.custom_minimum_size.x = width
	modal_scroll.custom_minimum_size.x = width - (26.0 if dock == "deal" else 44.0)
	modal_title.text = title
	modal_sub.text = sub
	modal_sub.visible = sub != ""
	K.clear(modal_head_extra)
	K.clear(modal_body)
	if mode != "modal":
		Sfx.play("open")
	set_mode("modal")


func _row(parent: Node, bb: String, buttons: Array, size := 14) -> void:
	var h := K.hbox()
	h.add_child(K.rich(bb, size))
	for b in buttons:
		h.add_child(b)
	parent.add_child(h)


# ---------------------------------------------------------------- telefon
func open_phone(app := "") -> void:
	dialog_box.visible = false
	modal.visible = false
	skill_box.visible = false
	if mode != "phone":
		Sfx.play("open")
	set_mode("phone")
	G.tip("telefon", "Telefon", "[%s] otwiera i chowa telefon. W Wiadomościach piszą klienci i Wiktor — pod rozmową są duże kafle odpowiedzi (klawisze 1–5): zgoda, negocjacja sumy, inna godzina na zegarze, inny towar, odmowa. [Esc] cofa o ekran. Uwaga: świat się nie zatrzymuje, kiedy patrzysz w telefon." % G.kn("phone"))
	phone.open(app)


func help_text() -> String:
	return "[b]%s %s %s %s[/b] ruch   [b]Mysz[/b] rozglądanie   [b]%s[/b] bieg   [b]%s[/b] kucanie\n[b]%s[/b] użyj   [b]%s[/b] telefon   [b]%s[/b] ekwipunek   [b]%s[/b] mapa   [b]%s[/b] latarka   [b]Esc[/b] pauza i opcje" % [
		G.kn("fwd"), G.kn("left"), G.kn("back"), G.kn("right"), G.kn("sprint"), G.kn("crouch"), G.kn("use"), G.kn("phone"), G.kn("inv"), G.kn("map"), G.kn("flash")]


# ---------------------------------------------------------------- stół roboczy: porcjowanie i mieszanie
func open_pack(room: String) -> void:
	G.S.flags["tut_bench"] = true
	bench.room = room
	bench.sel = {}
	bench.mixing = false
	_render_bench()


func _render_bench() -> void:
	Bench.build(self)


# ---------------------------------------------------------------- minimap-gra: waga
func _build_skill() -> void:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	skill_box = K.panel(K.sb(K.C_PANEL, 16, K.C_LINE, 1, 26))
	skill_box.visible = false
	c.add_child(skill_box)
	var v := K.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_box.add_child(v)
	l_skill_t = K.lbl("", 20)
	l_skill_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l_skill_t)
	var hl := K.lbl("Naciśnij SPACJĘ, gdy wskazówka wagi jest w zielonej strefie.", 13, K.C_DIM)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hl)
	var disp := K.panel(K.sb(Color(0.02, 0.05, 0.03), 8, Color(0.1, 0.3, 0.15), 1, 12))
	disp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l_skill_w = K.lbl("0.00 g", 30, Color(0.5, 1.0, 0.65))
	l_skill_w.custom_minimum_size = Vector2(150, 0)
	l_skill_w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disp.add_child(l_skill_w)
	v.add_child(disp)
	skill_bar = Control.new()
	skill_bar.custom_minimum_size = Vector2(560, 46)
	skill_bar.draw.connect(_draw_skill)
	v.add_child(skill_bar)
	l_skill_p = K.lbl("", 20)
	l_skill_p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l_skill_p)
	var b := K.btn("STOP (spacja)", _skill_press, "go")
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)


func skill_check(title: String, widen: float, cb: Callable) -> void:
	modal.visible = false
	dialog_box.visible = false
	phone.visible = false
	skill_box.visible = true
	l_skill_t.text = title
	sk = {"round": 0, "hits": 0, "cb": cb, "res": [], "widen": widen, "t0": _now_ms(), "speed": 0.8, "z0": 0.0, "z1": 0.0, "lock": 0, "flash": 0.0, "flash_ok": false, "ending": false}
	_skill_round()
	set_mode("skill")


## zegar mini-gry; w nagraniu zwiastuna podmieniany na zegar klatek
var fake_ms := -1

func _now_ms() -> int:
	return fake_ms if fake_ms >= 0 else Time.get_ticks_msec()


func _skill_pos(now_ms: int) -> float:
	var u := fmod((now_ms - int(sk.t0)) / 1000.0 * float(sk.speed), 2.0)
	return u if u < 1.0 else 2.0 - u


func _skill_marks() -> String:
	var marks := ""
	for r in sk.res:
		marks += ("●  " if r else "○  ")
	for i in range(3 - sk.res.size()):
		marks += "·  "
	return marks.strip_edges()


func _skill_round() -> void:
	# każda z trzech prób jest taka sama: stałe tempo wskazówki i stała szerokość zielonej strefy
	# (odrobinę trudniej niż dawna pierwsza próba, ale bez przyspieszania)
	var w: float = minf(0.5, 0.165 * float(sk.widen))
	var start := randf_range(0.08, 0.92 - w)
	sk.z0 = start
	sk.z1 = start + w
	sk.speed = 0.92
	sk.t0 = _now_ms() - randi_range(0, 600)
	l_skill_p.text = _skill_marks()


func _skill_press() -> void:
	if sk.is_empty() or sk.ending:
		return
	var now := _now_ms()
	if now < int(sk.lock):
		return
	sk.lock = now + 120
	var pos := _skill_pos(now)
	var hit: bool = pos >= float(sk.z0) and pos <= float(sk.z1)
	sk.res.append(hit)
	if hit:
		sk.hits = int(sk.hits) + 1
		Sfx.play("hit")
	else:
		Sfx.play("miss")
	sk.flash = 1.0
	sk.flash_ok = hit
	sk.round = int(sk.round) + 1
	l_skill_p.text = _skill_marks()
	if int(sk.round) >= 3:
		sk.ending = true
		get_tree().create_timer(0.38).timeout.connect(_skill_finish)
	else:
		_skill_round()


func _skill_finish() -> void:
	if sk.is_empty():
		return
	var cb: Callable = sk.cb
	var hits := int(sk.hits)
	skill_box.visible = false
	sk = {}
	set_mode("")
	cb.call(hits)


func _draw_skill() -> void:
	if sk.is_empty():
		return
	var w := skill_bar.size.x
	var h := skill_bar.size.y
	skill_bar.draw_rect(Rect2(0, 8, w, h - 16), Color(0.09, 0.11, 0.16))
	for i in range(21):
		var tx := i * w / 20.0
		skill_bar.draw_line(Vector2(tx, 8), Vector2(tx, 14 if i % 5 != 0 else 20), Color(1, 1, 1, 0.25), 1.0)
	skill_bar.draw_rect(Rect2(float(sk.z0) * w, 8, (float(sk.z1) - float(sk.z0)) * w, h - 16), Color(0.29, 0.87, 0.5, 0.5))
	skill_bar.draw_rect(Rect2(float(sk.z0) * w, 8, 2, h - 16), K.C_ACC)
	skill_bar.draw_rect(Rect2(float(sk.z1) * w - 2, 8, 2, h - 16), K.C_ACC)
	var p := _skill_pos(_now_ms())
	var x := p * (w - 4.0)
	skill_bar.draw_rect(Rect2(x, 0, 4, h), Color.WHITE)
	if float(sk.flash) > 0.0:
		var fc := K.C_ACC if sk.flash_ok else K.C_BAD
		skill_bar.draw_rect(Rect2(0, 8, w, h - 16), Color(fc.r, fc.g, fc.b, float(sk.flash) * 0.35))
	var mid := (float(sk.z0) + float(sk.z1)) * 0.5
	l_skill_w.text = "%.2f g" % (1.0 + (p - mid) * 0.9)


# ---------------------------------------------------------------- skrytka
func open_stash(room: String) -> void:
	G.S.flags["tut_stash"] = true
	open_inventory(room)


## ekwipunek: plecak, postać, organizer; `room` = skrytka otwarta po prawej stronie
func open_inventory(room := "", tab := "inv") -> void:
	dialog_box.visible = false
	modal.visible = false
	skill_box.visible = false
	phone.visible = false
	if mode != "inv":
		Sfx.play("open")
	set_mode("inv")
	inv.open(room, tab)


## paczka, skrytka Wiktora, rzeczy na ziemi: ekwipunek z zawartością po prawej stronie
func open_loot(src: Dictionary) -> bool:
	if not G.loot_open(src):
		return false
	open_inventory("loot")
	return true


# ---------------------------------------------------------------- sklep u Stasia
func open_shop() -> void:
	Shop.begin(self, "Sklep u Stasia", "„Wszystko, czego trzeba. O nic nie pytam.”")
	var S: Dictionary = G.S
	var box := Shop.section(self, "TOWARY")
	for it in D.SHOP:
		var id: String = it.id
		var block := ""
		var desc := String(it.desc)
		if int(S.lvl) < int(it.lvl):
			block = "poz. %d" % int(it.lvl)
		elif it.has("skill") and not G.has_skill(it.skill):
			block = "umiejętność"
			desc += " Wymaga umiejętności: %s." % G.skill_def(it.skill).name
		elif S.cash < float(it.price):
			block = "-"
		Shop.row(self, box, {"name": it.name, "sub": "masz %d" % G.item(id), "desc": desc, "icon": String(D.ITEMS[id].icon) if D.ITEMS.has(id) else "",
			"price": G.money(it.price), "block": block, "dim": block != "" and block != "-", "cb": func(): G.shop_buy(id); open_shop()})
	var box2 := Shop.section(self, "WYPOSAŻENIE")
	for it in D.UPGRADES:
		var id2: String = it.id
		if G.upg(id2):
			Shop.row(self, box2, {"name": it.name, "sub": "kupione", "desc": it.desc, "dim": true})
			continue
		var why := ""
		if int(S.lvl) < int(it.lvl):
			why = "poz. %d" % int(it.lvl)
		elif it.has("req") and not G.upg(it.req):
			why = "po poprzednim"
		elif S.cash < float(it.price):
			why = "-"
		Shop.row(self, box2, {"name": it.name, "desc": it.desc, "price": G.money(it.price), "block": why, "dim": why != "" and why != "-",
			"cb": func(): G.upgrade_buy(id2); open_shop()})
	Shop.foot(self, "Najedź na pozycję, żeby zobaczyć, do czego służy.")


## lombard: wagi. Każda następna jest szybsza i gubi mniej towaru; stara idzie w rozliczeniu, więc płacisz tylko raz.
func open_scales() -> void:
	Shop.begin(self, "Lombard — wagi", "„Dokładna waga to uczciwy interes. Dla obu stron.”")
	var S: Dictionary = G.S
	var box := Shop.section(self, "WAGI")
	for i in range(D.SCALES.size()):
		var sc: Dictionary = D.SCALES[i]
		var idx := i
		var stats := "gram w %s min • %s" % [("%.1f" % float(sc.min)).replace(".", ","), "bez strat" if float(sc.waste) <= 0.0 else "straty ok. %d%%" % int(round(float(sc.waste) * 100.0))]
		if i == G.scale():
			Shop.row(self, box, {"name": sc.name, "sub": stats + " • stoi na Twoim stole", "desc": sc.desc})
		elif i < G.scale():
			Shop.row(self, box, {"name": sc.name, "sub": "oddana w rozliczeniu", "desc": sc.desc, "dim": true})
		else:
			var why := ""
			if int(S.lvl) < int(sc.lvl):
				why = "poz. %d" % int(sc.lvl)
			elif G.scale_block(i) != "":
				why = "-"
			Shop.row(self, box, {"name": sc.name, "sub": stats, "desc": sc.desc, "price": G.money(sc.price), "block": why, "dim": why != "" and why != "-",
				"cb": func(): G.scale_buy(idx); open_scales()})
	Shop.foot(self, "Wagi nie trzeba nosić ani ustawiać: po zakupie stoi na każdym Twoim stole roboczym.")


# ---------------------------------------------------------------- namiot uprawowy
## stanowisko produkcyjne (regał, suszarka, stół laboratoryjny) i stan kryjówki
func open_station(room: String, idx: int) -> void:
	StationUI.build(self, room, idx)


func open_hideout(room: String) -> void:
	StationUI.build_hideout(self, room)


# ---------------------------------------------------------------- nieruchomość / meble
func open_property(pid: String) -> void:
	var p := G.prop_def(pid)
	_open_modal(p.name, p.where)
	var c := K.card(modal_body)
	c.add_child(K.wrap(p.desc, 14))
	c.add_child(K.rich("Cena: [b]%s[/b]   •   wymagany poziom: [b]%d[/b]   •   masz przy sobie: %s" % [K.col(G.money(p.price), K.C_WARN), int(p.lvl), G.money(G.S.cash)], 14))
	var why := ""
	if int(G.S.lvl) < int(p.lvl):
		why = "Wymaga poziomu %d" % int(p.lvl)
	elif G.S.cash < float(p.price):
		why = "Brakuje %s" % G.money(float(p.price) - G.S.cash)
	var b := K.btn("Kup" if why == "" else why, func(): G.buy_property(pid); close_all(), "go")
	b.disabled = why != ""
	c.add_child(b)
	c.add_child(K.wrap("Kryjówkę urządzasz samodzielnie: stół roboczy, regały na towar, łóżko, a z czasem namiot uprawowy.", 12, K.C_DIM))


const FURN_KINDS := {"pack": "stanowisko", "stash": "skrytka", "growlight": "światło do uprawy", "dry": "suszenie", "lab": "synteza", "tank": "podlewanie", "filter": "zapach", "bed": "sen", "save": "zapis gry", "light": "światło", "decor": "wystrój"}


## Meblowanie [B]: ustawiasz to, co masz „na stanie” — kupione wcześniej w hurtowni budowlanej. Tu nic nie kosztuje.
func open_build(room: String) -> void:
	Shop.begin(self, "Urządzanie — " + String(D.ROOMS[room].name), "Ustawiasz sprzęt i meble kupione w hurtowni budowlanej.")
	var S: Dictionary = G.S
	# doniczki to przedmioty ze sklepu: stawiasz te, które masz przy sobie albo w skrytce
	var cp := Shop.section(self, "UPRAWA")
	var have: int = G.item_at(room, "doniczka")
	var placed: int = G.Prod.pots(room).size()
	var pmax := int(D.POT_MAX.get(room, 8))
	Shop.row(self, cp, {"name": "Doniczka z ziemią", "sub": "masz %d • stoi %d/%d" % [have, placed, pmax], "icon": "doniczka" if K.is_item("doniczka") else "",
		"desc": "Kupujesz u Stasia razem z nasionami i nawozem. Każdy krzak doglądasz osobno: celujesz w niego i wybierasz czynność. Najlepiej rośnie pod lampą LED.",
		"price": "Postaw", "block": "" if (have > 0 and placed < pmax) else ("brak" if have <= 0 else "brak miejsca"), "cb": func(): close_all(); G.main.build_begin_pot()})
	var c := Shop.section(self, "NA STANIE — DO USTAWIENIA")
	var any := false
	for f in D.FURNITURE:
		var fid: String = f.id
		var n: int = G.owned(fid)
		if n <= 0:
			continue
		any = true
		Shop.row(self, c, {"name": f.name, "sub": "× %d • %s" % [n, FURN_KINDS.get(f["func"], "")], "desc": f.desc, "price": "Ustaw", "cb": func(): close_all(); G.main.build_begin(fid)})
	if not any:
		Shop.alert(self, "Nic do ustawienia. Sprzęt i meble kupisz w hurtowni budowlanej przy Hutniczej (szyld BUILDING SUPPLIES, %d:00–%d:00) — telefon: Mapa → Hurtownia budowlana." % [int(D.SUPPLY_OPEN[0]), int(D.SUPPLY_OPEN[1])])
	var items: Array = S.hide[room].items
	if not items.is_empty():
		var c2 := Shop.section(self, "USTAWIONE")
		for i in range(items.size()):
			var idx := i
			var f := G.furn_def(items[i].f)
			Shop.row(self, c2, {"name": String(f.name), "sub": String(FURN_KINDS.get(f["func"], "")), "desc": String(f.desc) + " Zdjęte wraca na stan.",
				"extra": [["Zdejmij", func(): G.furn_remove(room, idx); open_build(room)]]})
	Shop.foot(self, "Ustawienie nic nie kosztuje. Sprzęt działa dopiero wtedy, gdy stoi w kryjówce.")


## Hurtownia budowlana: sprzęt do produkcji i meble. Kupione rzeczy czekają „na stanie”, aż ustawisz je w kryjówce [B].
func open_supply() -> void:
	Shop.begin(self, "Hurtownia budowlana", "„Dowozimy pod wskazany adres. Faktury nie wystawiamy, jak pan nie chce.”", "na stanie %d szt." % G.owned_total())
	var S: Dictionary = G.S
	var hide_n := 0
	for pr in D.PROPERTIES:
		if String(pr.room) != "" and G.owns(pr.id):
			hide_n += 1
	if hide_n <= 0:
		Shop.alert(self, "Nie masz jeszcze kryjówki — kupione rzeczy poczekają na stanie (telefon → Lokale).")
	for grp in [["SPRZĘT DO PRODUKCJI", true], ["MEBLE DO KRYJÓWKI", false]]:
		var c := Shop.section(self, String(grp[0]))
		for f in D.FURNITURE:
			if (String(f["func"]) in D.SUPPLY_GEAR) != bool(grp[1]):
				continue
			var fid: String = f.id
			var why := ""
			if int(S.lvl) < int(f.lvl):
				why = "poz. %d" % int(f.lvl)
			elif G.furn_block(fid) != "":
				why = "-"
			var own: int = G.owned(fid)
			var sub := String(FURN_KINDS.get(f["func"], ""))
			if own > 0 or G.furn_count(fid) > 0:
				sub += " • na stanie %d • ustawione %d" % [own, G.furn_count(fid)]
			var extra: Array = []
			if own > 0:
				extra.append(["Odsprzedaj +%s" % G.money(round(float(f.price) * 0.5)), func(): G.furn_sell(fid); open_supply()])
			Shop.row(self, c, {"name": f.name, "sub": sub, "desc": f.desc, "price": G.money(f.price), "block": why, "dim": why != "" and why != "-",
				"extra": extra, "cb": func(): G.furn_buy(fid); open_supply()})
	Shop.foot(self, "Kupione rzeczy ustawisz w swojej kryjówce klawiszem [%s]. Dopiero ustawione działają." % G.kn("build"))


# ---------------------------------------------------------------- NEGOCJACJE
func open_deal(ctx: Dictionary) -> bool:
	var d: Dictionary = G.deal_start(ctx)
	if d.is_empty():
		return false
	deal = d
	deal_said = ""
	# gracz sam kładzie towar na tacę — zaczyna z pustą, suma stoi na umówionej
	G.deal_offer_clear(deal)
	_deal_stage(ctx)
	_render_deal()
	G.tip("wymiana", "Wymiana z ręki do ręki", "Przeciągnij paczki z listy na tacę. Więcej, niż zamówił — doceni; mniej — taca pokaże szansę, że i tak zapłaci całość. Potem przytrzymaj POTWIERDŹ albo [%s]." % G.kn("use"), 12.0)
	return true


## kadr rozmowy: gracz patrzy na klienta, klient gestykuluje mimo pauzy
func _deal_stage(ctx: Dictionary) -> void:
	deal_npc = ctx.get("npc")
	if deal_npc == null or not (deal_npc is Dictionary) or deal_npc.get("node") == null:
		deal_npc = null
		return
	var node: Node3D = deal_npc.node
	for ch in node.get_children():
		if ch is Label3D:
			ch.visible = false
	var P = G.player
	var np := node.global_position
	var pp: Vector3 = P.global_position
	node.rotation.y = atan2(pp.x - np.x, pp.z - np.z)
	if deal_npc.get("rig") != null:
		var rig: Dictionary = deal_npc.rig
		rig.anim.process_mode = Node.PROCESS_MODE_ALWAYS
		Chars.animate(rig, 0.0, 0.0, "talk")
	var y0: float = P.yaw
	var p0: float = P.pitch
	var d := np + Vector3(0, 1.02, 0) - (pp + Vector3(0, 1.66, 0))
	var y1 := atan2(-d.x, -d.z)
	var p1 := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.0, 0.6)
	var f0: float = P.cam.fov
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(k: float):
		P.yaw = lerp_angle(y0, y1, k)
		P.pitch = lerpf(p0, p1, k)
		P.rotation = Vector3(0, P.yaw, 0)
		P.cam.rotation = Vector3(P.pitch, 0, 0)
		P.cam.fov = lerpf(f0, 56.0, k), 0.0, 1.0, 0.35)


func _deal_anim_done() -> void:
	if deal_npc != null and deal_npc is Dictionary and deal_npc.get("rig") != null and mode == "modal":
		Chars.animate(deal_npc.rig, 0.0, 0.0, "talk")


func _deal_unstage() -> void:
	if deal_npc != null and deal_npc is Dictionary and deal_npc.get("rig") != null and is_instance_valid(deal_npc.rig.anim):
		deal_npc.rig.anim.process_mode = Node.PROCESS_MODE_INHERIT
	if deal_npc != null and deal_npc is Dictionary and deal_npc.get("node") != null and is_instance_valid(deal_npc.node):
		for ch in deal_npc.node.get_children():
			if ch is Label3D:
				ch.visible = true
	deal_npc = null


## kilka sylab mamrotania po nowej kwestii klienta
func _mumble_burst(who: String, n: int) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in range(n):
		tw.tween_callback(Sfx.say.bind(who))
		tw.tween_interval(randf_range(0.12, 0.2))


func _meter(parent: Node, ic: String, label: String, value: float, color: Color) -> void:
	var h := K.hbox(6)
	h.add_child(K.icon(ic, 15, color))
	h.add_child(K.lbl(label, 11, K.C_DIM))
	var b := K.bar(value, 100.0, color, 7.0)
	b.custom_minimum_size = Vector2(110, 7)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	parent.add_child(h)


func _render_deal() -> void:
	var saved := deal
	var who: Dictionary = saved.who
	var ctx: Dictionary = saved.ctx
	# co zamówił: nazwa towaru w pełnym brzmieniu, żeby nie trzeba było zgadywać z ikony
	var wants := "%s  •  %d g" % [String(D.PRODUCTS[saved.product].name), int(saved.want)]
	_open_modal("", "", "deal", 540.0)
	deal = saved
	deal_side.visible = not saved.over
	deal_npc = ctx.get("npc") if (ctx.get("npc") is Dictionary and ctx.get("npc").get("node") != null) else null
	deal_fill = null
	deal_watch_l = null
	deal_cop_l = null
	cop_bar = null
	if String(deal.speech) != deal_said:
		# gest klienta: podanie ręki przy sprzedaży, kręcenie głową przy odmowie
		if deal_npc != null and deal_npc.get("rig") != null:
			# twarz klienta: mówi swoje zdanie, po udanej wymianie się uśmiecha, po odmowie krzywi
			Chars.say(deal_npc.rig, clampf(float(String(deal.speech).length()) / 18.0, 1.0, 3.5))
			if deal.sold:
				Chars.emote(deal_npc.rig, "usmiech", 0.9, 3.0)
			elif deal.over or deal.pushed:
				Chars.emote(deal_npc.rig, "zlosc", 0.9, 3.0)
		if deal_said != "" and deal_npc != null and deal_npc.get("rig") != null:
			if deal.sold:
				Chars.one_shot(deal_npc.rig, "Interact")
			elif deal.over or deal.pushed:
				Chars.one_shot(deal_npc.rig, "Idle_No")
			else:
				Chars.one_shot(deal_npc.rig, "Yes")
			var gt := create_tween()
			gt.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			gt.tween_interval(1.7)
			gt.tween_callback(_deal_anim_done)
		deal_said = String(deal.speech)
		var fem: bool = who.get("look", {}).get("female", false)
		_mumble_burst(String(who.name), clampi(int(deal_said.length() / 14.0), 1, 3))
	# nagłówek w jednej linii: kto, czego chce, kto patrzy, zamknięcie
	var hd := K.hbox(8)
	hd.add_child(K.head(String(who.name), 15, Trade.C_HI))
	var zl := K.lbl("zamówił", 11, Trade.C_LOW)
	zl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hd.add_child(zl)
	hd.add_child(K.icon("pack_" + String(saved.product), 20))
	var wl := K.lbl(wants, 13, Trade.C_HI)
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hd.add_child(wl)
	hd.add_child(K.spacer())
	if not deal.over:
		hd.add_child(Trade.watch_row(self))
	modal_body.add_child(hd)
	# jedno zdanie klienta — sam tekst, bez ramek; pod nim najwyżej dwie ostatnie uwagi
	var sp := K.rich("[color=#c9ced6]%s[/color]" % String(deal.speech), 12)
	modal_body.add_child(sp)
	var notes: Array = deal.notes
	if not notes.is_empty():
		var last: Array = notes.slice(maxi(0, notes.size() - 2))
		modal_body.add_child(K.wrap("  •  ".join(last), 10, Trade.C_LOW, 500.0))
	if deal.over:
		deal_holding = false
		var ch := K.hbox(0)
		ch.add_child(K.spacer())
		ch.add_child(Trade._mini("Zamknij  [Esc]", close_all, "box"))
		modal_body.add_child(ch)
		# po udanej wymianie nie ma na co czekać: okno samo znika
		if deal.sold:
			var me := deal
			var ct := create_tween()
			ct.tween_interval(1.6)
			ct.tween_callback(func():
				if mode == "modal" and is_same(deal, me):
					close_all())
		return
	Trade.build(self)


## Wymiana trwa: przytrzymany przycisk napełnia pasek podania, a patrol, który patrzy, napełnia swój.
func _deal_tick(dt: float) -> void:
	if deal.is_empty() or deal.over or mode != "modal":
		deal_holding = false
		return
	Trade.tick(self)
	# z otwartym okienkiem „ile” albo pustą tacą niczego się nie podaje
	var holding: bool = (deal_holding or G.key_down("use") or Input.is_physical_key_pressed(KEY_SPACE)) and deal_ask.is_empty() and int(deal.qty) > 0
	var t: float = G.deal_hand_time()
	deal.hold = clampf(float(deal.hold) + (dt / t if holding else -dt * 2.5), 0.0, 1.0)
	if deal_fill != null and is_instance_valid(deal_fill):
		deal_fill.anchor_right = float(deal.hold)
	# kto patrzy: liczba przechodniów odświeża się na bieżąco, patrol napełnia czerwony pasek
	var w: Dictionary = G.deal_watchers()
	if deal_watch_l != null and is_instance_valid(deal_watch_l):
		var n := int(w.witnesses)
		deal_watch_l.text = Trade.watch_text(n)
		deal_watch_l.add_theme_color_override("font_color", Trade.watch_color(n))
	var cop = w.cop
	if cop != null:
		deal.cop = cop
		# samo stanie obok klienta budzi podejrzenia powoli; podawanie towaru na oczach patrolu — szybko
		deal.cop_t = minf(float(deal.cop_max), float(deal.cop_t) + dt * (2.6 if holding else 1.0))
	else:
		deal.cop_t = maxf(0.0, float(deal.cop_t) - dt * 0.8)
	if cop_bar != null and is_instance_valid(cop_bar):
		cop_bar.value = float(deal.cop_t)
		cop_bar.visible = float(deal.cop_t) > 0.05
		if deal_cop_l != null and is_instance_valid(deal_cop_l):
			deal_cop_l.visible = cop_bar.visible
	if float(deal.cop_t) >= float(deal.cop_max):
		var c2 = deal.cop
		G.deal_finish(deal, {"sold": 0, "interrupted": true})
		close_all()
		G.notify("Policjant zauważył wymianę!", "bad")
		G.add_heat(18.0)
		G.add_invest(4.0)
		if c2 != null and G.npcs.cops.has(c2):
			c2.susp = 1.0
			G.npcs.start_chase(c2)
		return
	if float(deal.hold) >= 1.0:
		deal_holding = false
		G.deal_hand(deal)
		_render_deal()


# ---------------------------------------------------------------- ekrany
func _screen(title: String, title_color: Color, text: String, buttons: Array, extra := "") -> void:
	K.clear(screen_box)
	if menu_root != null and is_instance_valid(menu_root):
		menu_root.queue_free()
		menu_root = null
	dialog_box.visible = false
	modal.visible = false
	skill_box.visible = false
	phone.visible = false
	(screen as ColorRect).color = Color(0.02, 0.03, 0.05, 0.66)
	var t := K.lbl(title, 64, title_color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	t.add_theme_constant_override("outline_size", 10)
	screen_box.add_child(t)
	if text != "":
		var p := K.lbl(text, 17, Color(0.85, 0.87, 0.9))
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.custom_minimum_size = Vector2(720, 0)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		screen_box.add_child(p)
	var h := K.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in buttons:
		h.add_child(b)
	screen_box.add_child(h)
	if extra != "":
		var e := K.rich("[center]%s[/center]" % extra, 13)
		e.custom_minimum_size = Vector2(720, 0)
		screen_box.add_child(e)
	screen.visible = true


## przycisk menu głównego: duży napis z zieloną kreską po najechaniu
func _menu_btn(text: String, cb: Callable, sub := "", enabled := true) -> Control:
	var v := K.vbox(0)
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(360, 52)
	b.add_theme_font_override("font", load("res://assets/fonts/bebas.ttf"))
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 0.88))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", K.C_ACC)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0)
	n.content_margin_left = 18
	var h := StyleBoxFlat.new()
	h.bg_color = Color(1, 1, 1, 0.07)
	h.border_color = K.C_ACC
	h.border_width_left = 4
	h.content_margin_left = 26
	h.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	b.mouse_entered.connect(func():
		if not b.disabled:
			Sfx.play("tick"))
	v.add_child(b)
	if sub != "":
		var sl := K.lbl(sub, 12, Color(1, 1, 1, 0.5))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 20)
		m.add_child(sl)
		v.add_child(m)
	return v


## lewa kolumna menu na tle miasta: tytuł, pozycje, podpis
func _menu_column(title_size: int, title: String, tag: String, items: Array, foot: String) -> void:
	if menu_root != null and is_instance_valid(menu_root):
		menu_root.queue_free()
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(menu_root)
	# przyciemnienie z lewej, żeby napisy były czytelne na każdym tle
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.42, 0.78])
	gr.colors = PackedColorArray([Color(0.01, 0.015, 0.03, 0.9), Color(0.01, 0.015, 0.03, 0.55), Color(0.01, 0.015, 0.03, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.width = 256
	gt.height = 4
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(shade)
	var col := K.vbox(4)
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 84.0
	col.offset_right = 620.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_root.add_child(col)
	var bebas: Font = load("res://assets/fonts/bebas.ttf")
	var spaced := FontVariation.new()
	spaced.base_font = load("res://assets/fonts/barlowc.ttf")
	spaced.spacing_glyph = 4
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", bebas)
	t.add_theme_font_size_override("font_size", title_size)
	t.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 3)
	t.add_theme_constant_override("line_spacing", -18)
	col.add_child(t)
	var ln := ColorRect.new()
	ln.color = K.C_ACC
	ln.custom_minimum_size = Vector2(120, 5)
	ln.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(ln)
	col.add_child(K.gap(8))
	if tag != "":
		var tg := Label.new()
		tg.text = tag
		tg.add_theme_font_override("font", spaced)
		tg.add_theme_font_size_override("font_size", 17)
		tg.add_theme_color_override("font_color", Color(0.84, 0.88, 0.92, 0.85))
		col.add_child(tg)
	col.add_child(K.gap(26))
	for it in items:
		col.add_child(it)
	if foot != "":
		var by := Label.new()
		by.text = foot
		by.add_theme_font_override("font", spaced)
		by.add_theme_font_size_override("font_size", 13)
		by.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		by.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		by.offset_left = 86.0
		by.offset_top = -44.0
		by.offset_bottom = -22.0
		by.offset_right = 700.0
		menu_root.add_child(by)


func show_title() -> void:
	hud.visible = false
	K.clear(screen_box)
	dialog_box.visible = false
	modal.visible = false
	skill_box.visible = false
	phone.visible = false
	opts.visible = false
	(screen as ColorRect).color = Color(0.02, 0.03, 0.05, 0.12)
	var sv := G.save_summary()
	_menu_column(118, "CZARNY\nRYNEK", "WEJDŹ DO EKIPY.  ZBUDUJ IMPERIUM.  NIE DAJ SIĘ ZŁAPAĆ.", [
		_menu_btn("Kontynuuj", func(): G.main.start_game(true), ("Dzień %d  •  %s  •  zapis: %s" % [int(sv.day), G.money(sv.cash), String(sv.when)]) if not sv.is_empty() else "Brak zapisu", not sv.is_empty()),
		_menu_btn("Nowa gra", func(): G.main.start_game(false)),
		_menu_btn("Opcje", func(): open_options("title")),
		_menu_btn("Wyjdź", func(): get_tree().quit()),
	], "A TEST GAME BY PIOTR PIŁKA")
	var note := K.lbl("Fikcyjna gra. Wszystkie postacie i miejsca są zmyślone.\nGra nie zachęca do łamania prawa ani zażywania narkotyków.", 11, Color(1, 1, 1, 0.4))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	note.offset_left = -520.0
	note.offset_right = -30.0
	note.offset_top = -62.0
	note.offset_bottom = -26.0
	menu_root.add_child(note)
	screen.visible = true
	set_mode("title")


func show_pause() -> void:
	K.clear(screen_box)
	dialog_box.visible = false
	modal.visible = false
	skill_box.visible = false
	phone.visible = false
	opts.visible = false
	(screen as ColorRect).color = Color(0.02, 0.03, 0.05, 0.5)
	var btns := [
		_menu_btn("Wróć do gry", close_all),
		_menu_btn("Opcje", func(): open_options("pause")),
		_menu_btn("Sterowanie", func(): show_controls("pause")),
		_menu_btn("Menu główne", func(): G.main.to_menu(), "Niezapisany postęp przepadnie."),
	]
	if G.prologue != null:
		btns.insert(1, _menu_btn("Pomiń prolog", func(): close_all(); G.prologue.skip(), "Od razu „trzy tygodnie później”."))
	_menu_column(96, "PAUZA", "Ostatni zapis: %s.  Grę zapisujesz przy laptopie w kryjówce." % G.last_save_text(), btns, "")
	screen.visible = true
	set_mode("pause")


func open_options(from: String) -> void:
	screen.visible = false
	phone.visible = false
	opts.open(from)
	set_mode("options")


func options_closed(back: String) -> void:
	match back:
		"title": show_title()
		"pause": show_pause()
		_: close_all()


# ---------------------------------------------------------------- ściąga sterowania
func _keycap(text: String) -> Control:
	var p := K.panel(K.sb(Color(1, 1, 1, 0.1), 6, Color(1, 1, 1, 0.28), 1, 9))
	p.custom_minimum_size = Vector2(46, 30)
	var l := K.head(text, 15, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Okno z klawiszami na środku ekranu. Pojawia się, gdy gracz pierwszy raz dostaje sterowanie,
## i zamyka je dopiero gracz. `back`: dokąd wrócić po zamknięciu ("" = do gry).
func show_controls(back := "") -> void:
	K.clear(screen_box)
	if menu_root != null and is_instance_valid(menu_root):
		menu_root.queue_free()
		menu_root = null
	(screen as ColorRect).color = Color(0.02, 0.03, 0.05, 0.62)
	controls_back = back
	var box := K.panel(K.sb(Color(0.045, 0.055, 0.078, 0.97), 16, Color(1, 1, 1, 0.1), 1, 24))
	screen_box.add_child(box)
	var v := K.vbox(12)
	box.add_child(v)
	var hd := K.hbox(10)
	hd.add_child(K.icon("info", 20, K.C_ACC))
	hd.add_child(K.head("STEROWANIE", 26, Color.WHITE))
	v.add_child(hd)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 44)
	grid.add_theme_constant_override("v_separation", 9)
	v.add_child(grid)
	var rows := [
		[[G.kn("fwd"), G.kn("left"), G.kn("back"), G.kn("right")], "Chodzenie"],
		[["Mysz"], "Rozglądanie się"],
		[[G.kn("sprint")], "Bieg (zużywa kondycję)"],
		[[G.kn("crouch")], "Kucanie — bezgłośnie, trudniej Cię zauważyć, przełazy w płotach"],
		[[G.kn("use")], "Użyj / rozmawiaj (naceluj na coś z bliska)"],
		[[G.kn("phone")], "Telefon: wiadomości, klienci, mapa"],
		[[G.kn("inv")], "Ekwipunek: towar, gotówka, cel, stan"],
		[[G.kn("map")], "Mapa z trasą do celu"],
		[[G.kn("flash")], "Latarka (nocą widać Cię z daleka)"],
		[[G.kn("throw")], "Rzut kamykiem — hałas odciąga patrol"],
		[[G.kn("ditch")], "Wyrzuć towar (przytrzymaj w pościgu)"],
		[["Esc"], "Pauza, opcje, zmiana klawiszy"],
	]
	for r in rows:
		var kh := K.hbox(5)
		kh.custom_minimum_size = Vector2(220, 0)
		kh.alignment = BoxContainer.ALIGNMENT_END
		for k in r[0]:
			kh.add_child(_keycap(String(k)))
		grid.add_child(kh)
		var dl := K.lbl(String(r[1]), 15, Color(0.88, 0.9, 0.93))
		dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(dl)
	v.add_child(K.wrap("Na ekranie zostaje tylko pasek kondycji. Gotówkę, godzinę, cel i uwagę policji sprawdzisz w ekwipunku, a klawisze zmienisz w Opcjach.", 13, K.C_DIM, 560.0))
	var bh := K.hbox(8)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := K.btn("Jasne, gramy   [Enter]", close_controls, "go")
	go.custom_minimum_size = Vector2(240, 44)
	go.add_theme_font_size_override("font_size", 17)
	bh.add_child(go)
	v.add_child(bh)
	screen.visible = true
	set_mode("controls")


func close_controls() -> void:
	G.S.flags["seen_keys"] = true
	if controls_back == "pause":
		show_pause()
	else:
		close_all()


func show_ending(title: String, text: String, stats: String, can_continue := false) -> void:
	hud.visible = false
	var btns := [K.btn("Menu główne", func(): G.main.to_menu(), "go")]
	if can_continue:
		btns.push_front(K.btn("Graj dalej", func(): G.main.resume_free(), "go"))
	_screen(title, K.C_WARN, text, btns, stats)
	set_mode("end")


# ---------------------------------------------------------------- pętla i HUD
var prof_us := 0.0
var prof_n := 0.0

func _process(dt: float) -> void:
	var pt0 := Time.get_ticks_usec()
	_process_ui(dt)
	prof_us += Time.get_ticks_usec() - pt0
	prof_n += 1.0


func _process_ui(dt: float) -> void:
	_call_tick(dt)
	_toast_tick(dt)
	# okno przyklejone do dołu ekranu (wymiana, rozmowa): powiadomienia wędrują tuż nad nie
	var lift := 110.0
	var t_left := 0.0
	var t_right := 0.0
	if modal != null and modal.visible and modal_box != null and modal_box.is_visible_in_tree():
		var vh := root.size.y
		if modal_box.global_position.y + modal_box.size.y > vh - 150.0 and modal_box.global_position.y > 170.0:
			lift = vh - modal_box.global_position.y + 10.0
			if modal_dock == "deal":
				# przy wymianie powiadomienia stają nad panelem sprzedaży, a nie na ekwipunku obok
				t_left = modal_box.global_position.x
				t_right = -(root.size.x - modal_box.global_position.x - modal_box.size.x)
	# karta „pierwszy raz" nie nachodzi na przypięty cel w lewym górnym rogu: środkuje się w wolnej części ekranu
	if tip_box != null and is_instance_valid(tip_box):
		var left := 0.0
		if hud.visible and obj_card.visible:
			left = obj_card.position.x + obj_card.size.x + 14.0
		tip_box.offset_left = left
	# otwarty telefon zajmuje prawą stronę — powiadomienia przesuwają się na lewą część ekranu
	if mode == "phone" and t_left == 0.0:
		t_right = -430.0
	if absf(toast_wrap.offset_left - t_left) > 0.5 or absf(toast_wrap.offset_right - t_right) > 0.5:
		toast_wrap.offset_left = t_left
		toast_wrap.offset_right = t_right
	if absf(toast_wrap.offset_bottom + lift) > 0.5:
		toast_wrap.offset_bottom = -lift
		toast_wrap.offset_top = -lift - 120.0
	if mode == "dialog" and not dlg.is_empty() and not dlg.done:
		dlg.typed = float(dlg.typed) + dt * 55.0
		d_text.visible_characters = int(dlg.typed)
		# co kilka liter jedna sylaba mamrotania (narrator i gracz milczą)
		# każda postać mówi swoją barwą; Kuba („Ty”) też ma głos — ciszej, bo to my
		var speaker := String(dlg.lines[dlg.i].n)
		if int(dlg.typed) >= int(dlg.said) + 7 and speaker != "" and speaker != "Łóżko":
			dlg.said = int(dlg.typed)
			# po znaku przestankowym krótka pauza, żeby brzmiało jak mowa, a nie terkot
			var ch := String(dlg.lines[dlg.i].t).substr(maxi(0, int(dlg.typed) - 2), 2)
			if not (ch.contains(".") or ch.contains(",") or ch.contains("?") or ch.contains("!") or ch.contains("…")):
				Sfx.say(speaker)
		if int(dlg.typed) >= String(dlg.lines[dlg.i].t).length():
			_line_done()
	if mode == "modal":
		_fit_modal()
	if mode == "skill":
		if not sk.is_empty():
			sk.flash = maxf(0.0, float(sk.flash) - dt * 4.0)
		skill_bar.queue_redraw()
	if mode == "modal" and not deal.is_empty():
		_deal_tick(dt)
	if sms_t > 0.0:
		sms_t -= dt
		if sms_t <= 0.0:
			sms_banner.visible = false
	if zone_t > 0.0:
		zone_t -= dt
		l_zone.add_theme_color_override("font_color", Color(1, 1, 1, clampf(zone_t / 1.2, 0.0, 0.85)))
		l_zone.add_theme_color_override("font_shadow_color", Color(0, 0, 0, clampf(zone_t / 1.2, 0.0, 0.7)))
	if not G.running:
		return
	hud_t -= dt
	if hud_t <= 0.0:
		hud_t = 0.1
		update_hud()
		if not plant_ref.is_empty():
			plant_t -= 0.1
			if plant_t <= 0.0:
				hide_plant_card()
			else:
				_plant_card_fill()
	waymark.queue_redraw()
	aim_t += dt
	if aim_on and aim_t < 0.25:
		cross.queue_redraw()


func update_hud() -> void:
	var S: Dictionary = G.S
	var P = G.player
	if P == null:
		return
	bar_stam.max_value = P.max_stamina()
	bar_stam.value = P.stamina
	bar_stam.modulate.a = 0.55 if (P.stamina >= P.max_stamina() - 0.01 and not P.crouching) else 1.0
	# zadyszka: pasek czerwienieje, dopóki nie da się znów biec
	bar_stam.self_modulate = Color(1.0, 0.45, 0.4) if P.tired else Color.WHITE
	# „oko”: jak bardzo rzucasz się w oczy (postawa, ruch, ciemność, światło latarni, krzaki)
	var vis: float = P.visibility() if P.loc == "out" else 1.0
	ic_stance.texture = K.tex("eye_off" if vis < 0.5 else "eye")
	ic_stance.modulate = K.C_ACC if vis < 0.5 else (K.C_WARN if vis > 1.05 else Color(1, 1, 1, 0.5 if vis < 0.8 else 0.9))
	aware_cv.queue_redraw()
	var su: float = clampf(G.npcs.max_susp, 0.0, 1.0)
	bar_susp.value = su
	susp_box.visible = su > 0.04 and not G.npcs.any_chase()
	l_susp.text = "POLICJA CIĘ OBSERWUJE" if su > 0.3 else ""
	chase.visible = G.npcs.any_chase()
	# cel: karta pokazuje się na chwilę, gdy treść się zmieni
	var st := G.cur_step()
	var txt: String = st.text.call() if not st.is_empty() else ""
	var in_call := call_active() and G.prologue == null
	if in_call:
		if String(call.state) == "talk":
			txt = "Rozmowa: %s. [Spacja] — następna kwestia." % String(call.get("voice_as", call.name))
		else:
			txt = "Dzwoni telefon. Naciśnij [%s], żeby odebrać." % G.kn("phone")
	if txt != last_obj:
		last_obj = txt
		if txt != "":
			obj_t = 9.0
	if G.prologue != null and txt != "":
		obj_t = maxf(obj_t, 1.0)
	l_obj_t.text = G.chapter().to_upper()
	l_obj.text = txt
	var lines := ""
	# w scenie (kamera filmowa, rozmowa z łóżka) nie ma dokąd iść — odległość do celu znika
	var staged: bool = G.main.cine_active() or in_call
	if not nav_info.is_empty() and not staged:
		lines = "%s  %s • %d m" % [K.col("◆", nav_info.get("color", K.C_ACC)), nav_info.label, int(round(nav_info.dist))]
	var nm = G.next_meeting()
	if nm != null and not staged:
		var left = float(nm.meet) - S.t
		lines += ("\n" if lines != "" else "") + K.col("%s: %d g %s  •  %s — %s" % [String(G.cust_def(nm.cust).name), int(nm.grams), String(D.PRODUCT_GEN[nm.product]), G.clock(nm.meet), ("za %d min" % int(left)) if left > 0.0 else ("czeka od %d min" % int(-left))], K.C_ACC if left > 0.0 else K.C_WARN)
	# zlecenie dnia: postęp pod celem; karta wraca na chwilę, gdy zlecenie się pojawi albo zostanie wykonane
	if G.job_active() and G.prologue == null:
		var jb: Dictionary = S.job
		var jd: Dictionary = G.job_def(String(jb.kind))
		var jdone: bool = jb.get("done", false)
		lines += ("\n" if lines != "" else "") + K.col("Zlecenie dnia: %s" % ("zrobione ✓" if jdone else "%s z %s" % [G._job_amount(jd, G.job_progress()), G._job_amount(jd, float(jb.need))]), K.C_GOLD)
		var sig := "%s|%s|%s" % [String(jb.kind), str(jb.need), str(jdone)]
		if sig != last_job:
			last_job = sig
			obj_t = maxf(obj_t, 6.0)
	l_nav.text = lines
	obj_t = maxf(0.0, obj_t - 0.1)
	# cel zostaje na ekranie, dopóki gracz go nie wykona (tak samo niewykonane zlecenie dnia);
	# tylko otwarta „wolna gra”, której nie da się skończyć, pokazuje się na chwilę i znika
	var pinned: bool = txt != "" and (in_call or String(st.get("id", "")) != "free" or (G.job_active() and not S.job.get("done", false)))
	obj_card.visible = txt != "" and (pinned or obj_t > 0.0)
	obj_card.modulate.a = 1.0 if pinned else clampf(obj_t / 0.8, 0.0, 1.0)
	sms_key.text = G.kn("phone")
	var mm: bool = bool(G.main.settings.get("minimap", false))
	mini_card.visible = mm
	if mm:
		l_zone_s.text = (G.zone_name.to_upper() if P.loc == "out" else String(D.ROOMS[P.loc].name).to_upper())
		minimap.queue_redraw()
	if G.zone_id != last_zone and P.loc == "out":
		last_zone = G.zone_id
		if G.zone_name != "":
			l_zone.text = G.zone_name.to_upper()
			zone_t = 3.2


## pokazuje kartę z celem jeszcze raz (np. po zmianie śledzonego celu)
func flash_objective() -> void:
	obj_t = 7.0


## celownik: kropka, a po nacelowaniu na coś, czego można użyć — zielony pierścień
func set_aim(on: bool) -> void:
	if on != aim_on:
		aim_on = on
		aim_t = 0.0
		cross.queue_redraw()


func _draw_cross() -> void:
	if aim_on:
		var k := clampf(aim_t / 0.12, 0.0, 1.0)
		K.arc(cross, Vector2.ZERO, lerpf(3.0, 8.0, k), 0.0, TAU, 28, Color(0, 0, 0, 0.45), 3.5)
		K.arc(cross, Vector2.ZERO, lerpf(3.0, 8.0, k), 0.0, TAU, 28, K.C_ACC, 1.8)
		K.circle(cross, Vector2.ZERO, 1.6, Color.WHITE)
	else:
		K.circle(cross, Vector2.ZERO, 2.6, Color(0, 0, 0, 0.35))
		K.circle(cross, Vector2.ZERO, 1.6, Color(1, 1, 1, 0.85))


var test_prompt_lock := false
# menu czynności przy celowniku (krzak w doniczce) i karta „Sprawdź”
var aim_menu: VBoxContainer
var aim_title: Label
var aim_rows: Array = []
var aim_key := ""
var plant_card: PanelContainer
var plant_body: VBoxContainer
var plant_ref := {}
var plant_t := 0.0
var plant_sig := ""


# ---------------------------------------------------------------- rozmowa telefoniczna (nie zatrzymuje świata)
## Telefon wysuwa się z prawej krawędzi ekranu. Dzwoni, dopóki nie odbierzesz; odrzucony — oddzwoni po chwili.
## W trakcie rozmowy chodzisz i robisz swoje, a czas gry płynie.
var call := {}
var call_card: PanelContainer
var call_ic: TextureRect
var call_name: Label
var call_state_l: Label
var call_text: RichTextLabel
var call_hint: RichTextLabel
var call_slide := 0.0

func _build_call() -> void:
	call_card = K.panel(K.sb(Color(0.03, 0.04, 0.06, 0.96), 18, Color(0.3, 0.9, 0.55, 0.5), 1, 14))
	call_card.custom_minimum_size = Vector2(330, 0)
	call_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_card.visible = false
	root.add_child(call_card)
	var v := K.vbox(8)
	call_card.add_child(v)
	var h := K.hbox(10)
	v.add_child(h)
	var av := K.panel(K.sb(Color(0.12, 0.5, 0.28), 22, Color(0, 0, 0, 0), 0, 9))
	av.custom_minimum_size = Vector2(44, 44)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_ic = K.icon("phone_call", 24, Color.WHITE)
	av.add_child(call_ic)
	h.add_child(av)
	var hv := K.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_name = K.head("", 18)
	hv.add_child(call_name)
	call_state_l = K.lbl("", 12, K.C_DIM)
	hv.add_child(call_state_l)
	h.add_child(hv)
	call_text = K.rich("", 15)
	call_text.custom_minimum_size = Vector2(300, 0)
	call_text.fit_content = true
	call_text.visible = false
	v.add_child(call_text)
	call_hint = K.rich("", 12)
	call_hint.fit_content = true
	v.add_child(call_hint)


func call_active() -> bool:
	return not call.is_empty()


## ktoś dzwoni: `lines` jak w dialog() — napisy albo {"n": "Ty", "t": "…"}
## voice_as: czyim głosem mówi dzwoniący, gdy na ekranie jest np. „Nieznany numer”, a w słuchawce — Wiktor
func call_start(caller: String, lines: Array, on_end := Callable(), voice_as := "") -> void:
	if G.test_mode:
		dialog({"name": caller, "lines": lines, "on_end": on_end})
		return
	if call_card == null:
		_build_call()
	var ls := []
	for l in lines:
		ls.append({"n": caller, "t": l} if l is String else {"n": l.get("n", caller), "t": l.t})
	var last := caller.get_slice(" ", 0).to_lower()
	var fem: bool = last.ends_with("a") and not last in ["kuba"]
	call = {"name": caller, "lines": ls, "i": 0, "state": "ring", "t": 0.0, "typed": 0.0, "hold": 0.0, "again": 0.0, "said": 0, "on_end": on_end,
		"voice": (1.26 if fem else 0.8) + float(absi(caller.hash()) % 30) / 100.0}
	if voice_as != "":
		call["voice_as"] = voice_as
	_call_ring()


func _call_ring() -> void:
	call.state = "ring"
	call.t = 0.0
	call_name.text = String(call.name)
	call_state_l.text = "dzwoni…"
	call_text.visible = false
	call_hint.text = "[b][color=#4ade80][%s][/color][/b] odbierz      [b][color=#f05050][Backspace][/color][/b] odrzuć" % G.kn("phone")
	call_card.visible = true
	Sfx.ring(true)


## odbiera połączenie (klawisz telefonu), a w rozmowie przewija do następnej kwestii (spacja)
func call_answer() -> void:
	if call.is_empty():
		return
	if call.state == "ring":
		Sfx.ring(false)
		Sfx.play("open")
		call.state = "talk"
		call.i = 0
		call.t = 0.0
		_call_line()
	elif call.state == "talk":
		var full: int = String(call.lines[call.i].t).length()
		if int(call.typed) < full:
			call.typed = float(full)
		else:
			_call_next()


func call_reject() -> void:
	if call.is_empty() or call.state != "ring":
		return
	Sfx.ring(false)
	Sfx.play("back")
	call.state = "wait"
	call.again = 7.0


func _call_line() -> void:
	var l: Dictionary = call.lines[call.i]
	var me := String(l.n) == "Ty"
	call.typed = 0.0
	call.hold = 0.0
	call.said = 0
	call_text.text = ("[color=#7ee0a0][b]Ty:[/b][/color] " if me else "") + String(l.t)
	call_text.visible_characters = 0
	call_text.visible = true
	call_hint.text = "[color=#8a93a6][Spacja] dalej[/color]"


func _call_next() -> void:
	call.i = int(call.i) + 1
	if int(call.i) >= (call.lines as Array).size():
		_call_end()
	else:
		_call_line()


func _call_end() -> void:
	var cb: Callable = call.on_end
	call = {}
	Sfx.ring(false)
	Sfx.play("close")
	if cb.is_valid():
		cb.call()


func _call_tick(dt: float) -> void:
	if call_card == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var show: bool = not call.is_empty() and call.state != "wait" and not cut.visible
	call_slide = clampf(call_slide + (dt if show else -dt) / 0.28, 0.0, 1.0)
	var e := 1.0 - (1.0 - call_slide) * (1.0 - call_slide)
	call_card.visible = call_slide > 0.0
	call_card.position = Vector2(vs.x - (call_card.size.x + 26.0) * e, vs.y * 0.5 - call_card.size.y * 0.5 - 40.0)
	if call.is_empty() or get_tree().paused:
		return
	call.t = float(call.t) + dt
	match String(call.state):
		"ring":
			# słuchawka podskakuje w rytm dzwonka
			var k := absf(sin(float(call.t) * 11.0)) * (1.0 if fmod(float(call.t), 2.0) < 1.2 else 0.0)
			call_ic.rotation = k * 0.35
			call_ic.pivot_offset = call_ic.size * 0.5
			call_card.position.x += sin(float(call.t) * 40.0) * 2.0 * (1.0 if fmod(float(call.t), 2.0) < 1.2 else 0.0)
		"wait":
			call.again = float(call.again) - dt
			if float(call.again) <= 0.0:
				_call_ring()
		"talk":
			call_ic.rotation = 0.0
			call_state_l.text = "rozmowa %d:%02d" % [int(float(call.t) / 60.0), int(call.t) % 60]
			var l: Dictionary = call.lines[call.i]
			var body := String(l.t)
			var pre := 4 if String(l.n) == "Ty" else 0
			if int(call.typed) < body.length():
				call.typed = float(call.typed) + dt * 42.0
				call_text.visible_characters = int(call.typed) + pre
				if int(call.typed) >= int(call.said) + 7:
					call.said = int(call.typed)
					# rozmówca brzmi jak w słuchawce, Kuba — normalnie
					var spk := String(l.n) if String(l.n) != "" else String(call.name)
					Sfx.say(String(call.get("voice_as", spk)) if spk == String(call.name) else spk, true)
			else:
				call_text.visible_characters = -1
				# kwestia zostaje na ekranie tym dłużej, im jest dłuższa
				call.hold = float(call.hold) + dt
				if float(call.hold) > 2.0 + body.length() * 0.05:
					_call_next()


func _build_aim_menu() -> void:
	aim_menu = K.vbox(3)
	aim_menu.set_anchors_preset(Control.PRESET_CENTER)
	aim_menu.position = Vector2(30, -52)
	aim_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_menu.visible = false
	hud.add_child(aim_menu)
	aim_title = K.lbl("", 12, Color(1, 1, 1, 0.75))
	aim_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	aim_title.add_theme_constant_override("shadow_offset_y", 1)
	aim_menu.add_child(aim_title)
	for i in range(4):
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hb := K.hbox(8)
		row.add_child(hb)
		var key := K.lbl(str(i + 1), 11, K.C_DIM)
		key.custom_minimum_size = Vector2(12, 0)
		hb.add_child(key)
		var ic := K.icon("leaf", 15, K.C_TXT)
		hb.add_child(ic)
		var tx := K.lbl("", 14, K.C_TXT)
		tx.custom_minimum_size = Vector2(118, 0)
		hb.add_child(tx)
		var note := K.lbl("", 11, K.C_DIM)
		hb.add_child(note)
		aim_menu.add_child(row)
		aim_rows.append({"row": row, "key": key, "icon": ic, "text": tx, "note": note})
	var hint := K.lbl("kółko myszy / 1–4 • [%s] wykonaj" % G.kn("use"), 10, Color(1, 1, 1, 0.5))
	aim_menu.add_child(hint)
	plant_card = K.panel(K.sb(Color(0.03, 0.04, 0.06, 0.9), 10, Color(1, 1, 1, 0.12), 1, 12))
	plant_card.set_anchors_preset(Control.PRESET_CENTER)
	plant_card.position = Vector2(-300, -110)
	plant_card.custom_minimum_size = Vector2(250, 0)
	plant_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plant_card.visible = false
	hud.add_child(plant_card)
	plant_body = K.vbox(5)
	plant_card.add_child(plant_body)


## lista czynności obok celownika; przebudowuje się tylko wtedy, gdy coś się zmieniło
func set_aim_menu(title: String, opts: Array, sel: int) -> void:
	if aim_menu == null:
		return
	if opts.is_empty():
		if aim_menu.visible:
			aim_menu.visible = false
			aim_key = ""
		return
	var key := "%s|%d" % [title, sel]
	for o in opts:
		key += "|%s:%s:%s:%s" % [o.id, o.label, o.ok, o.get("note", "")]
	if key == aim_key:
		return
	aim_key = key
	aim_menu.visible = true
	aim_title.text = title.to_upper()
	for i in range(aim_rows.size()):
		var r: Dictionary = aim_rows[i]
		var on := i < opts.size()
		(r.row as Control).visible = on
		if not on:
			continue
		var o: Dictionary = opts[i]
		var cur := i == sel
		var col: Color = (Color.WHITE if cur else K.C_TXT) if o.ok else Color(0.55, 0.57, 0.62)
		(r.row as PanelContainer).add_theme_stylebox_override("panel", K.sb(Color(0.1, 0.42, 0.24, 0.92) if (cur and o.ok) else (Color(0.2, 0.2, 0.24, 0.9) if cur else Color(0, 0, 0, 0.55)), 7, Color(0.3, 0.9, 0.55, 0.9) if cur else Color(1, 1, 1, 0.07), 1, 6))
		(r.icon as TextureRect).texture = K.tex(String(o.icon))
		(r.icon as TextureRect).modulate = col
		(r.text as Label).text = String(o.label)
		(r.text as Label).add_theme_color_override("font_color", col)
		(r.note as Label).text = String(o.get("note", ""))
		(r.note as Label).add_theme_color_override("font_color", K.C_WARN if String(o.get("note", "")).contains("!") else (Color(0.8, 0.95, 0.85) if cur else K.C_DIM))


func show_plant_card(room: String, i: int) -> void:
	plant_ref = {"room": room, "i": i}
	plant_t = 8.0
	plant_sig = ""
	_plant_card_fill()


func hide_plant_card() -> void:
	if plant_card != null and plant_card.visible:
		plant_card.visible = false
	plant_ref = {}


func _plant_card_fill() -> void:
	if plant_ref.is_empty():
		return
	var info: Dictionary = G.Prod.plant_info(String(plant_ref.room), int(plant_ref.i))
	if info.is_empty():
		hide_plant_card()
		return
	var sig := "%s|%d|%d|%d|%d|%d|%d" % [info.stage, int(float(info.prog) * 100.0), int(info.water), int(info.health), int(info.g), int(info.pur), (info.notes as Array).size()]
	if sig == plant_sig:
		return
	plant_sig = sig
	for c in plant_body.get_children():
		plant_body.remove_child(c)
		c.queue_free()
	var head := K.hbox(8)
	head.add_child(K.icon("sprout", 18, K.C_ACC))
	head.add_child(K.head("Konopie — " + String(info.stage).to_lower(), 16))
	plant_body.add_child(head)
	for e in [["Wzrost", float(info.prog), K.C_ACC, "%d%%" % int(float(info.prog) * 100.0)], ["Woda", float(info.water) / 100.0, K.C_BLUE if float(info.water) >= 25.0 else K.C_BAD, "%d%%" % int(info.water)],
			["Kondycja", float(info.health) / 100.0, K.C_ACC if float(info.health) >= 60.0 else K.C_WARN, "%d%%" % int(info.health)]]:
		var row := K.hbox(8)
		var l := K.lbl(String(e[0]), 12, K.C_DIM)
		l.custom_minimum_size = Vector2(62, 0)
		row.add_child(l)
		var b := K.bar(float(e[1]), 1.0, e[2], 6.0)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		var v := K.lbl(String(e[3]), 12, K.C_TXT)
		v.custom_minimum_size = Vector2(36, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		plant_body.add_child(row)
	var left := float(info.left)
	var fc := "Plon: [b]ok. %d g[/b] • jakość [b]%d%%[/b]" % [int(info.g), int(info.pur)]
	if float(info.prog) < 1.0:
		fc += "\nDojrzeje za [b]%dh %02dm[/b]%s" % [int(left / 60.0), int(left) % 60, "" if float(info.water) > 0.0 else " (stoi — sucho)"]
	plant_body.add_child(K.rich(fc, 13))
	for nt in info.notes:
		var colr: Color = {"bad": K.C_BAD, "warn": K.C_WARN, "good": K.C_ACC}.get(String(nt[1]), K.C_DIM)
		plant_body.add_child(K.wrap("• " + String(nt[0]), 11, colr, 226.0))
	plant_card.visible = true
   # pomiary wydajności: podpowiedź zostaje na ekranie

func set_prompt(text: String, progress := -1.0) -> void:
	if test_prompt_lock and text == "":
		return
	if text == "":
		prompt.visible = false
		return
	var bb := "[b][color=#4ade80][%s][/color][/b]  %s" % [G.kn("use"), text]
	if l_prompt.text != bb:
		l_prompt.text = bb
	prompt_bar.visible = progress >= 0.0
	prompt_bar.value = clampf(progress, 0.0, 1.0)
	prompt.visible = true


func set_build_hint(text: String) -> void:
	build_hint.visible = text != ""
	if text != "" and l_build.text != text:
		l_build.text = text


## Łuk dla każdego patrolu, który właśnie Ci się przygląda: wypełnia się w miarę zauważania,
## potem żółknie i czerwienieje razem z podejrzeniem. Kierunek łuku = kierunek do patrolu.
func _draw_aware() -> void:
	if not G.running or G.player == null or G.player.loc != "out" or G.test_hide_hud:
		return
	var P = G.player
	var c0 := aware_cv.size * 0.5
	var pp: Vector3 = P.global_position
	var f: Vector2 = P.forward()
	var base := atan2(f.x, f.y)
	for a in G.npcs.aware:
		if a.chase:
			continue
		var rel := wrapf(atan2(float(a.x) - pp.x, float(a.z) - pp.z) - base, -PI, PI)
		var mid := -PI / 2.0 - rel
		var half := 0.34
		var n: float = clampf(float(a.n), 0.0, 1.0)
		var sus: float = float(a.s)
		K.arc(aware_cv, c0, 86.0, mid - half, mid + half, 14, Color(0, 0, 0, 0.35), 7.0)
		K.arc(aware_cv, c0, 86.0, mid - half, mid + half, 14, Color(1, 1, 1, 0.16), 4.0)
		var col := Color(1, 1, 1, 0.9)
		if n >= 1.0:
			col = K.C_WARN.lerp(K.C_BAD, sus)
		var fill := n if n < 1.0 else 1.0
		K.arc(aware_cv, c0, 86.0, mid - half * fill, mid + half * fill, 14, col, 4.0)
		if n >= 1.0 and sus > 0.0:
			K.arc(aware_cv, c0, 94.0, mid - half * sus, mid + half * sus, 14, K.C_BAD, 3.0)


func _draw_way() -> void:
	var M = G.main
	if M == null or not G.running or mode != "" or G.player == null:
		return
	_draw_hints(M)
	if M.way.is_empty() or M.cine_active():
		return
	var cam: Camera3D = G.player.cam
	var pos: Vector3 = M.way.pos
	if float(M.way.dist) < (3.0 if G.player.loc == "out" else 1.3) or cam.is_position_behind(pos):
		return
	var sp := cam.unproject_position(pos)
	var vs := get_viewport().get_visible_rect().size
	sp = Vector2(clampf(sp.x, 30.0, vs.x - 30.0), clampf(sp.y, 70.0, vs.y - 120.0))
	var c: Color = M.way.color
	var a := 0.9 if float(M.way.dist) > 12.0 else 0.55
	K.poly(waymark, PackedVector2Array([sp + Vector2(0, -9), sp + Vector2(7, 0), sp + Vector2(0, 9), sp + Vector2(-7, 0)]), Color(c.r, c.g, c.b, a))
	K.polyline(waymark, PackedVector2Array([sp + Vector2(0, -9), sp + Vector2(7, 0), sp + Vector2(0, 9), sp + Vector2(-7, 0), sp + Vector2(0, -9)]), Color(0, 0, 0, a), 1.5)
	var font := ThemeDB.fallback_font
	var txt := "%d m" % int(round(float(M.way.dist)))
	waymark.draw_string_outline(font, sp + Vector2(-40, 26), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, 4, Color(0, 0, 0, 0.8))
	waymark.draw_string(font, sp + Vector2(-40, 26), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(1, 1, 1, a))


## małe znaczniki na pobliskich rzeczach, których można użyć (trzeba na nie nacelować)
func _draw_hints(M) -> void:
	if G.busy or not hud.visible:
		return
	var cam: Camera3D = G.player.cam
	for h in M.aim_hints:
		var pos: Vector3 = h.pos
		if h.on or cam.is_position_behind(pos):
			continue
		var sp := cam.unproject_position(pos)
		var d := cam.global_position.distance_to(pos)
		var a := clampf(1.0 - (d - 1.5) / 3.0, 0.25, 0.8)
		K.circle(waymark, sp, 5.5, Color(0, 0, 0, 0.3 * a))
		K.ring(waymark, sp, 4.5, Color(1, 1, 1, a), 1.4)
		K.circle(waymark, sp, 1.4, Color(1, 1, 1, a))


func _draw_mini() -> void:
	if G.player == null or not G.running:
		return
	var pp: Vector3 = G.player.global_position
	draw_map(minimap, Vector2(pp.x, pp.z), 90.0, false)


## wspólne rysowanie mapy (minimapa i aplikacja Mapa)
func draw_map(cv: Control, center: Vector2, span: float, big: bool) -> void:
	var w: float = cv.size.x
	var hgt: float = cv.size.y
	var k := w / span
	var S: Dictionary = G.S
	var P = G.player
	var W = G.world
	var half := Vector2(w * 0.5, hgt * 0.5)
	var tr := func(x: float, z: float) -> Vector2: return (Vector2(x, z) - center) * k + half
	var font := ThemeDB.fallback_font
	cv.draw_rect(Rect2(0, 0, w, hgt), Color(0.03, 0.035, 0.05))
	if P.loc != "out" and not big:
		cv.draw_string(font, Vector2(0, hgt * 0.5), String(D.ROOMS[P.loc].name).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w, 15, K.C_TXT)
		cv.draw_string(font, Vector2(0, hgt * 0.5 + 20), "wyjście: drzwi za plecami", HORIZONTAL_ALIGNMENT_CENTER, w, 11, K.C_DIM)
		return
	if W.map_tex != null:
		var src := Rect2((center.x - span * 0.5) * W.INV - W.X0, (center.y - (hgt / k) * 0.5) * W.INV - W.Z0, span * W.INV, hgt / k * W.INV)
		cv.draw_texture_rect_region(W.map_tex, Rect2(0, 0, w, hgt), src)
	# „gorące” strefy
	for zn in D.ZONES:
		var hz := float(S.zheat.get(zn.id, 0.0))
		if hz >= 8.0:
			var a: Vector2 = tr.call(zn.x0, zn.z0)
			var b: Vector2 = tr.call(zn.x1, zn.z1)
			cv.draw_rect(Rect2(a, b - a), Color(0.94, 0.27, 0.27, minf(0.28, hz / 300.0)))
	# trasa
	var path: Array = G.main.nav.path
	if S.nav_on and path.size() > 1 and P.loc == "out":
		var pts := PackedVector2Array()
		for p in path:
			pts.append(tr.call(p.x, p.y))
		var rc: Color = nav_info.get("color", K.C_ACC)
		K.polyline(cv, pts, Color(0, 0, 0, 0.45), 6.0 if big else 5.0)
		K.polyline(cv, pts, rc, 3.2 if big else 2.6)
		for pt in pts:
			K.circle(cv, pt, 1.6 if big else 1.3, rc)
	# drzwi
	for id in D.DOORS:
		var dd: Dictionary = D.DOORS[id]
		if dd.has("prop") and not G.owns(dd.prop) and not big:
			continue
		var dp: Vector2 = tr.call(dd.x, dd.z)
		var dc := K.C_WARN if not dd.has("prop") else (K.C_BLUE if G.owns(dd.prop) else Color(0.5, 0.5, 0.55))
		cv.draw_rect(Rect2(dp - Vector2(3.5, 3.5), Vector2(7, 7)), dc)
		if big:
			cv.draw_string(font, dp + Vector2(-50, -7), {"safe": "Dom", "shop": "Sklep", "garage": "Garaż 14", "basement": "Piwnica"}.get(id, ""), HORIZONTAL_ALIGNMENT_CENTER, 100, 10, Color(0.99, 0.92, 0.6))
	# sklepy „z okienkiem”: lombard (skup znalezisk, wagi) i hurtownia budowlana (sprzęt, meble)
	for shop_e in [[D.PAWN_AT, "Lombard"], [D.SUPPLY_AT, "Hurtownia"]]:
		var shp: Vector2 = tr.call(float(shop_e[0].x), float(shop_e[0].z))
		cv.draw_rect(Rect2(shp - Vector2(3.5, 3.5), Vector2(7, 7)), K.C_WARN)
		if big:
			cv.draw_string(font, shp + Vector2(-50, -7), String(shop_e[1]), HORIZONTAL_ALIGNMENT_CENTER, 100, 10, Color(0.99, 0.92, 0.6))
	if big:
		for e in [[-181.0, -1.0, "Cop Corner"], [-26.0, 128.0, "Club Neon"], [70.0, -52.0, "Pawilon"], [-122.0, 104.0, "The Hill"], [74.0, 84.0, "Garage Row"], [190.0, -82.0, "Dead Mill"], [145.0, -110.0, "The Tracks"], [10.0, -110.0, "Steel Blocks"], [-30.0, 0.0, "Old Town"]]:
			var lp: Vector2 = tr.call(e[0] * D.SC, e[1] * D.SC)
			cv.draw_string(font, lp + Vector2(-50, 4), e[2], HORIZONTAL_ALIGNMENT_CENTER, 100, 10, Color(0.75, 0.8, 0.9, 0.8))
		for d in S.drops:
			if d.state == "ready":
				var dd2: Dictionary = G.Market.spot(d)
				var p2: Vector2 = tr.call(dd2.x, dd2.z)
				K.circle(cv, p2, 5.0, K.C_PINK)
	if P.loc == "out":
		var pp: Vector3 = P.global_position
		var see_all := G.has_skill("teren")
		var vr: float = 27.0 - G.night * 6.0 - G.rain * 5.0
		for c in G.npcs.cops:
			var dist := Vector2(c.x - pp.x, c.z - pp.z).length()
			if c.state != "patrol" or (see_all and dist < 60.0) or big or dist < 24.0:
				var cc: Color = K.C_BAD if c.state == "chase" else (K.C_WARN if c.state != "patrol" else K.C_BLUE)
				K.circle(cv, tr.call(c.x, c.z), 4.0, cc)
		var car: Dictionary = G.npcs.car
		if not car.is_empty() and (see_all or car.alarm or big or Vector2(car.x - pp.x, car.z - pp.z).length() < 45.0):
			var cp: Vector2 = tr.call(car.x, car.z)
			cv.draw_rect(Rect2(cp - Vector2(4, 4), Vector2(8, 8)), K.C_BAD if car.alarm else K.C_BLUE)
		for c in G.npcs.citizens:
			if c.icon.visible:
				K.circle(cv, tr.call(c.x, c.z), 2.6, Color(0.98, 0.8, 0.08))
	for c in G.npcs.customers:
		if c.node == null:
			continue
		var cpos: Vector2 = tr.call(c.x, c.z)
		K.circle(cv, cpos, 5.0, K.C_ACC)
		cv.draw_string(font, cpos + Vector2(-50, -8), String(c.def.name).split(" ")[0], HORIZONTAL_ALIGNMENT_CENTER, 100, 10, Color(0.75, 0.97, 0.82))
	for t in G.main.targets():
		var tp: Vector2 = tr.call(t.x, t.z)
		tp = Vector2(clampf(tp.x, 6.0, w - 6.0), clampf(tp.y, 6.0, hgt - 6.0))
		var tc: Color = t.color
		K.poly(cv, PackedVector2Array([tp + Vector2(0, -7), tp + Vector2(6, 0), tp + Vector2(0, 7), tp + Vector2(-6, 0)]), tc)
		K.polyline(cv, PackedVector2Array([tp + Vector2(0, -7), tp + Vector2(6, 0), tp + Vector2(0, 7), tp + Vector2(-6, 0), tp + Vector2(0, -7)]), Color.BLACK, 1.0)
	# gracz
	var gx: float = P.global_position.x
	var gz: float = P.global_position.z
	if P.loc != "out":
		gx = D.DOORS[P.loc].x
		gz = D.DOORS[P.loc].z
	var c0: Vector2 = tr.call(gx, gz)
	c0 = Vector2(clampf(c0.x, 6.0, w - 6.0), clampf(c0.y, 6.0, hgt - 6.0))
	var f: Vector2 = P.forward()
	var r := Vector2(-f.y, f.x)
	K.poly(cv, PackedVector2Array([c0 + f * 9.0, c0 - f * 6.0 + r * 5.5, c0 - f * 2.5, c0 - f * 6.0 - r * 5.5]), Color.WHITE)


func _input(event: InputEvent) -> void:
	if G.test_mode:
		return
	if event is InputEventMouseButton and event.pressed and mode == "" and G.running and not G.busy and G.main.build_active():
		if event.button_index == MOUSE_BUTTON_LEFT:
			G.main.build_confirm()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			G.main.build_cancel()
			get_viewport().set_input_as_handled()
		return
	# kółko myszy przewija menu czynności przy celowniku
	if event is InputEventMouseButton and event.pressed and mode == "" and G.running and G.main.menu_active():
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			G.main.menu_scroll(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			get_viewport().set_input_as_handled()
			return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var kc: int = event.physical_keycode
	if cut.visible:
		if kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_KP_ENTER or kc == KEY_ESCAPE:
			G.main.cut_skip = true
		get_viewport().set_input_as_handled()
		return
	if kc == KEY_F11:
		G.main.set_fullscreen(not G.main.is_fullscreen())
		get_viewport().set_input_as_handled()
		return
	var act := G.key_action(kc)
	var used := true
	match mode:
		"options":
			if not opts.take_key(kc):
				if kc == KEY_ESCAPE:
					opts.close()
				else:
					used = false
		"controls":
			if kc == KEY_ENTER or kc == KEY_KP_ENTER or kc == KEY_ESCAPE or kc == KEY_SPACE:
				close_controls()
			else:
				used = false
		"dialog":
			if kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_KP_ENTER or act == "use":
				advance()
			elif kc >= KEY_1 and kc <= KEY_9:
				pick_choice(kc - KEY_1)
			else:
				used = false
		"skill":
			if kc == KEY_SPACE:
				_skill_press()
			else:
				used = false
		"phone":
			if act == "phone" or act == "map":
				close_all()
			elif kc == KEY_ESCAPE or kc == KEY_BACKSPACE:
				phone.back()
			elif kc >= KEY_1 and kc <= KEY_5:
				used = phone.hotkey(kc - KEY_1 + 1)
			elif act == "inv":
				close_all()
				open_inventory("")
			else:
				used = false
		"modal":
			if not deal_ask.is_empty():
				# okienko „ile paczek”: Esc zamyka, Enter kładzie, strzałki zmieniają liczbę
				if kc == KEY_ESCAPE:
					Trade.ask_close(self)
				elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
					Trade.ask_ok(self)
				elif kc == KEY_LEFT or kc == KEY_DOWN or kc == KEY_MINUS or kc == KEY_KP_SUBTRACT:
					Trade.ask_step(self, -1)
				elif kc == KEY_RIGHT or kc == KEY_UP or kc == KEY_EQUAL or kc == KEY_KP_ADD:
					Trade.ask_step(self, 1)
				else:
					used = false
			elif kc == KEY_ESCAPE:
				_modal_close()
			else:
				used = false
		"inv":
			if inv.asking():
				# okno wyboru ilości: Esc zamyka, Enter zatwierdza, cyfry trafiają do pola
				if kc == KEY_ESCAPE:
					inv.ask_close()
				elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
					inv.ask_ok()
				else:
					used = false
			elif kc == KEY_ESCAPE or act == "inv":
				close_all()
			elif act == "phone":
				close_all()
				open_phone("sms" if G.unread_total() > 0 else "")
			elif kc >= KEY_1 and kc <= KEY_4:
				inv.tab = ["inv", "char", "wear", "org"][kc - KEY_1]
				inv.sel = {}
				inv.render()
			else:
				used = false
		"pause":
			if kc == KEY_ESCAPE:
				close_all()
			else:
				used = false
		"":
			if not G.running:
				return
			# Telefon dzwoni albo trwa rozmowa: te klawisze działają zawsze — także gdy bohater leży w łóżku
			# i reszta sterowania jest zablokowana. Odbiera klawisz telefonu, kwestie przewija spacja.
			if call_active() and not G.main.build_active():
				var took := true
				if call.state == "ring" and (act == "phone" or kc == KEY_ENTER or kc == KEY_KP_ENTER):
					call_answer()
				elif call.state == "ring" and kc == KEY_BACKSPACE:
					call_reject()
				elif call.state == "talk" and (kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_KP_ENTER):
					call_answer()
				elif call.state == "talk" and act == "phone":
					# w rozmowie klawisz telefonu nic nie robi (kiedyś przewijał — teraz spacja)
					pass
				else:
					took = false
				if took:
					get_viewport().set_input_as_handled()
					return
			if G.busy:
				return
			if G.main.build_active():
				if act == "rotate":
					G.main.build_rotate()
				elif act == "use" or kc == KEY_ENTER:
					G.main.build_confirm()
				elif kc == KEY_ESCAPE or act == "build":
					G.main.build_cancel()
				else:
					used = false
			elif kc == KEY_ESCAPE:
				show_pause()
			elif G.main.menu_active() and kc >= KEY_1 and kc <= KEY_4:
				G.main.menu_pick(kc - KEY_1)
			else:
				match act:
					"phone": open_phone("sms" if G.unread_total() > 0 else "")
					"inv": open_inventory("")
					"map": open_phone("mapa")
					"use": G.main.interact()
					"flash": G.main.toggle_flash()
					"throw": G.main.throw_stone()
					"nav": G.main.toggle_nav()
					"track":
						G.main.cycle_track()
						flash_objective()
					"build": G.main.build_menu()
					"crouch": G.player.toggle_crouch()
					_: used = false
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()
