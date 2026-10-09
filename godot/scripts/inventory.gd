extends Control
## Ekran ekwipunku: zawartość plecaka z rozmiarem i wagą każdej rzeczy, podgląd postaci
## ze slotami, skrytka albo kosz po prawej. Przeciągnij i upuść albo kliknij i przenieś.

const K = preload("res://scripts/uikit.gd")
const Chars = preload("res://scripts/chars.gd")
## paleta i małe płaskie przyciski wspólne z oknem wymiany: szarości i biel, kolor tylko dla ostrzeżeń
const T = preload("res://scripts/trade.gd")

const W_SIDE := 380.0
const W_MID := 356.0
const H_BODY := 548.0
const TABS := [["inv", "EKWIPUNEK", "backpack"], ["char", "POSTAĆ", "user"], ["wear", "UBRANIA", "store"], ["org", "ORGANIZER", "notebook_pen"]]

var ui
var room := ""
var tab := "inv"
var sel := {}               # zaznaczona pozycja: {side, kind, p, pur, id}
var tabs_box: HBoxContainer
var l_cash: Label
var l_clock: Label
var content: Control
var hint: Label
var vp: SubViewport
var vpc: SubViewportContainer
var rig := {}
var pivot: Node3D
var bag_mesh: Node3D
var rig_outfit := ""          # strój pokazany na podglądzie postaci
var wear_sel := ""            # strój oglądany w zakładce „Ubrania”
var spin := 0.0
var spin_rest:=0.0
var spin_drag := false
var preview_motion:=0
var backpack_button:Button
var ask := {}                # otwarte okno wyboru ilości: {e, from, to, max, step, v}
var ask_box: Control = null
var ask_big: Label
var ask_sub: Label
var ask_slider: HSlider
var ask_edit: LineEdit
var ask_go: Button
var demo: Control = null
var demo_tween: Tween


func build(ui_ref) -> void:
	ui = ui_ref
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.012, 0.016, 0.026, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var v := K.vbox(10)
	cc.add_child(v)
	# pasek z zakładkami
	var top := K.hbox(14)
	top.custom_minimum_size = Vector2(W_SIDE * 2.0 + W_MID + 24.0, 30)
	v.add_child(top)
	tabs_box = K.hbox(18)
	top.add_child(tabs_box)
	top.add_child(K.spacer())
	l_clock = K.lbl("09:00", 12, T.C_LOW)
	l_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(l_clock)
	l_cash = K.head("0 zł", 18, T.C_HI)
	top.add_child(l_cash)
	var xb: Button = T._mini("Esc", func(): ui.close_all(), "box")
	xb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xb.tooltip_text = "Zamknij"
	top.add_child(xb)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	content = Control.new()
	content.custom_minimum_size = Vector2(W_SIDE * 2.0 + W_MID + 24.0, H_BODY)
	v.add_child(content)
	hint = K.lbl("", 11, T.C_LOW)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_build_viewport()


# ---------------------------------------------------------------- podgląd postaci
func _build_viewport() -> void:
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(600, 880)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.72)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 35, 0)
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.93, 0.82)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -150, 0)
	rim.light_energy = 1.1
	rim.light_color = Color(0.45, 0.7, 1.0)
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 0.98, 3.75)
	cam.look_at_from_position(cam.position, Vector3(0, 0.93, 0))
	vp.add_child(cam)
	pivot = Node3D.new()
	vp.add_child(pivot)
	set_rig("dres")


## ubiera postać z podglądu w podany strój (inna sylwetka, ta sama twarz)
func set_rig(outfit_id: String) -> void:
	if not D.OUTFITS.has(outfit_id):
		outfit_id = "dres"
	if rig_outfit == outfit_id and not rig.is_empty():
		return
	if not rig.is_empty() and is_instance_valid(rig.root):
		pivot.remove_child(rig.root)
		rig.root.queue_free()
	rig_outfit = outfit_id
	var od: Dictionary = D.OUTFITS[outfit_id]
	var look: Dictionary = D.PLAYER_LOOK.duplicate()
	look["no_blob"] = true
	look["model"] = String(od.model)
	look["face"] = String(D.PLAYER_LOOK.get("face",D.PLAYER_LOOK.model))
	look["mask"] = bool(od.get("mask", false))
	look["tall"] = 1.0
	look["build"] = 1.0
	rig = Chars.make(look)
	pivot.add_child(rig.root)
	rig.anim.process_mode = Node.PROCESS_MODE_ALWAYS
	Chars.animate(rig, 0.0, [0.0,2.4,5.5][preview_motion], "")
	# plecak na plecach (widoczny po zakupie)
	bag_mesh = load("res://scripts/player_backpack.gd").new()
	var skel: Skeleton3D = rig.skel
	var bone := ""
	for cand in ["Bip01 Spine2", "spine_03", "spine_02", "Spine2", "Chest", "spine_01"]:
		if skel.find_bone(cand) >= 0:
			bone = cand
			break
	if bone != "":
		var ba := BoneAttachment3D.new()
		ba.bone_name = bone
		skel.add_child(ba)
		ba.add_child(bag_mesh)
		if bone.begins_with("Bip01"):
			# kość szkieletu Biped: oś X w górę kręgosłupa, Y do przodu, Z w bok
			bag_mesh.basis=Basis(Vector3(0,0,-1),Vector3(1,0,0),Vector3(0,-1,0))
			bag_mesh.position = Vector3(-0.12, -0.145, 0)
		else:
			bag_mesh.position = Vector3(0, 0.02, -0.17)
	else:
		rig.root.add_child(bag_mesh)
		bag_mesh.position = Vector3(0, 1.2, -0.2)
	_bag_refresh()


## ubrania z pól ekwipunku na postaci w podglądzie (przebudowa tylko wtedy, gdy coś się zmieniło)
var _dress_sig := ""
var try_on := {}                # przymierzana rzecz: {pole: id} — tylko w podglądzie, nic nie zmienia w ekwipunku


func try_set(slot: String, id: String) -> void:
	if String(try_on.get(slot, "")) == id and try_on.size() == 1:
		return
	try_on = {slot: id}
	_dress()


func try_clear(id := "") -> void:
	if try_on.is_empty() or (id != "" and not try_on.values().has(id)):
		return
	try_on = {}
	_dress()

func _dress(force := false) -> void:
	if rig.is_empty() or G.S == null:
		return
	var gear: Dictionary = G.S.get("gear", {})
	if not try_on.is_empty():
		# przymiarka: rzecz spod kursora na liście sklepu zastępuje na chwilę to, co jest w danym polu
		gear = gear.duplicate()
		gear.merge(try_on, true)
	var sig := rig_outfit + "|" + JSON.stringify(gear)
	if sig == _dress_sig and not force:
		return
	_dress_sig = sig
	Chars.dress(rig, gear)


func _bag_refresh() -> void:
	_dress()
	bag_mesh.visible = G.S != null and G.S.has("upg") and G.upg("plecak1")
	var big: bool = G.S != null and G.S.has("upg") and G.upg("plecak2")
	bag_mesh.configure(big,float(G.carry_total())/maxf(1.0,float(G.capacity())))


func _char_view(w: float, h: float) -> Control:
	if vpc != null and is_instance_valid(vpc):
		vpc.queue_free()
	var holder := Control.new()
	holder.tooltip_text="Przeciągnij: obrót postaci. Prawy przycisk: stanie / chód / bieg."
	holder.custom_minimum_size = Vector2(w, h)
	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(0, 0, 0, 0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	tr.mouse_default_cursor_shape = Control.CURSOR_DRAG
	tr.gui_input.connect(_spin_input)
	holder.add_child(tr)
	return holder


func _spin_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index==MOUSE_BUTTON_RIGHT and ev.pressed:
		preview_pose((preview_motion+1)%3)
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		spin_drag = ev.pressed
	elif ev is InputEventMouseMotion and spin_drag:
		spin += ev.relative.x * 0.012
		spin_rest=spin

func preview_pose(mode:int) -> void:
	preview_motion=clampi(mode,0,2)
	Chars.animate(rig,0.0,[0.0,2.4,5.5][preview_motion])
	if bag_mesh!=null: bag_mesh.motion=float(preview_motion)

func inspect_backpack() -> void:
	if bag_mesh==null or not bag_mesh.visible: return
	preview_pose(0)
	spin_rest=PI
	bag_mesh.opened=not bag_mesh.opened
	if is_instance_valid(backpack_button):
		backpack_button.text="Zamknij kieszeń" if bag_mesh.opened else "Obejrzyj plecak"


func _process(dt: float) -> void:
	if not visible:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		spin_drag = false
	if not spin_drag:
		spin = lerpf(spin, spin_rest+sin(Time.get_ticks_msec() * 0.0005) * 0.08, minf(1.0, dt * 1.2))
	pivot.rotation.y = spin
	if bag_mesh!=null:
		bag_mesh.motion=float(preview_motion)


# ---------------------------------------------------------------- otwieranie
func open(room_id := "", start_tab := "inv") -> void:
	# otwarty pojemnik „z ręki” (paczka, skrytka Wiktora, ziemia) rozlicza się, zanim okno pokaże coś innego
	if room == "loot" and room_id != "loot":
		G.loot_close()
	room = room_id
	tab = start_tab
	sel = {}
	visible = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	wear_sel = G.outfit()
	set_rig(G.outfit())
	_bag_refresh()
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate:a", 1.0, 0.14)
	render()
	_first_time()


## Pierwsze otwarcie plecaka ze schowkiem obok: karta z wyjaśnieniem i „ręka”, która pokazuje przeciąganie.
func _first_time() -> void:
	var shown := false
	if G.prologue != null and room == "lab":
		shown = G.tip("torba", "Pakowanie torby", "Po prawej leży towar ze stołu, po lewej Twoja torba. Złap kokainę lewym przyciskiem myszy, przeciągnij na lewą stronę i puść. W oknie ilości kliknij „Wszystko”, potem „Przenieś wszystko” albo [Enter].")
		if shown:
			drag_demo(false)
	elif room == "loot":
		shown = G.tip("pojemnik", "Zabieranie rzeczy", "Po prawej widzisz, co tu leży, po lewej swój plecak. Złap rzecz lewym przyciskiem myszy, przeciągnij na lewą stronę i puść — przy większej ilości wybierasz, ile bierzesz. Przycisk „Zabierz wszystko” bierze naraz tyle, ile się zmieści. Czego nie weźmiesz, zostaje na miejscu.")
		if shown:
			drag_demo(false)
	elif room == "wiktor":
		shown = G.tip("skrzynka", "Skrzynka Wiktora", "Przeciągnij gotówkę z plecaka (po lewej) do skrzynki (po prawej) i wybierz kwotę. Gdy zamkniesz okno, Wiktor zabierze najpierw to, co wisisz za towar (zeszyt), a całą resztę zaliczy na Twój wkład — z wkładu biorą się awanse w jego ekipie.")
		if shown:
			drag_demo(true)
	elif has_stash():
		if G.item("notes") > 0 and room == "safe":
			shown = G.tip("skrytka_notes", "Schowaj notes", "Po lewej masz kieszenie, po prawej szafę. Złap NOTES Z NUMERAMI lewym przyciskiem myszy, przeciągnij na prawą stronę i puść. Kliknij „Wszystko”, potem „Przenieś wszystko”. Chodzi o notes, nie o gotówkę — pieniądze zostaw przy sobie, przydadzą się na mieście.")
			if shown:
				drag_demo(true)
				return
		shown = G.tip("skrytka_eq", "Przenoszenie rzeczy", "Po lewej masz plecak, po prawej skrytkę. Złap rzecz lewym przyciskiem myszy, przeciągnij na drugą stronę i puść — przy większej ilości wybierasz, ile przenosisz. Ubranie przeciągasz na pole przy postaci. Towar w skrytce jest bezpieczny, przy sobie — nie.")
		if shown:
			drag_demo(true)
	else:
		G.tip("plecak", "Plecak", "Tu widzisz wszystko, co masz przy sobie, i ile to zajmuje. Kliknięcie pokazuje opis. Przeciągnięcie rzeczy na pole po prawej wyrzuca ją na ziemię — ktoś inny może ją potem znaleźć. Zakładki u góry: postać, ubrania, notatki.")


## Pokaz nie przenosi przedmiotów: klik, trzymanie, upuszczenie, wybór i potwierdzenie.
func demo_stop() -> void:
	if demo_tween != null and demo_tween.is_valid():
		demo_tween.kill()
	if is_instance_valid(demo):
		demo.queue_free()
	demo = null


func _demo_find(n: Node, side: String, preferred := "") -> Control:
	if n is Control and n.has_meta("demo_entry") and String(n.get_meta("demo_side")) == side:
		var entry: Dictionary = n.get_meta("demo_entry")
		if preferred == "" or String(entry.get("id", "")) == preferred or String(entry.get("p", "")) == preferred:
			return n as Control
	for child in n.get_children():
		var found := _demo_find(child, side, preferred)
		if found != null:
			return found
	return null


func drag_demo(to_right: bool) -> void:
	demo_stop()
	# Wiersze i kolumny muszą mieć rzeczywiste rozmiary, również po zmianie rozdzielczości.
	var active_room := room
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible or room != active_room or asking():
		return
	var side := "bag" if to_right else "stash"
	var preferred := "notes" if to_right and room == "safe" and G.item("notes") > 0 else ("snieg" if room == "lab" else "")
	var source := _demo_find(content, side, preferred)
	if source == null:
		source = _demo_find(content, side)
	if source == null:
		return
	var entry: Dictionary = source.get_meta("demo_entry")
	var inv_transform := get_global_transform().affine_inverse()
	var start := inv_transform * source.get_global_rect().get_center()
	var target := Vector2(size.x * (0.83 if to_right else 0.17), start.y)
	demo = Control.new()
	demo.name = "DragTutorial"
	demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo.z_index = 80
	demo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(demo)
	var cursor := Control.new()
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.z_index = 1
	cursor.position = start
	cursor.set_meta("held", false)
	demo.add_child(cursor)
	var hand := K.icon("hand", 34.0, T.C_HI)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.add_child(hand)
	var held_item := K.icon(String(entry.icon), 30.0, T.C_HI)
	held_item.position = Vector2(40, -8)
	held_item.visible = false
	held_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.add_child(held_item)
	cursor.draw.connect(func():
		# Schemat myszy: lewy przycisk wypełniony przez cały czas trzymania.
		cursor.draw_style_box(K.sb(Color(0.08, 0.09, 0.1, 0.96), 8, Color.WHITE, 1, 0), Rect2(-25, -16, 18, 28))
		if bool(cursor.get_meta("held")):
			cursor.draw_rect(Rect2(-23, -14, 6, 11), Color.WHITE)
			cursor.draw_arc(Vector2(9, 12), 25.0, 0, TAU, 32, Color(1, 1, 1, 0.65), 2, true))
	var label := K.lbl("", 13, T.C_HI)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(-30, 42)
	cursor.add_child(label)
	# Demonstracyjne okno: nie przechwytuje myszy i nie modyfikuje prawdziwego schowka.
	var confirm := K.panel(K.sb(Color(0.05, 0.057, 0.072, 0.99), 10, Color(1, 1, 1, 0.4), 1, 16))
	confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm.position = size * 0.5 - Vector2(170, 95)
	confirm.size = Vector2(340, 190)
	confirm.visible = false
	demo.add_child(confirm)
	var cv := K.vbox(12)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm.add_child(cv)
	cv.add_child(K.head("POKAZ — %s" % String(entry.name), 16, T.C_HI))
	cv.add_child(K.lbl("Ile chcesz przenieść?", 13, T.C_MID))
	var all := K.lbl("Wszystko", 15, T.C_HI)
	all.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(all)
	var go := K.head("Przenieś wszystko  [Enter]", 16, T.C_HI)
	go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(go)
	var phase := func(text: String, held: bool):
		label.text = text
		held_item.visible = held and (text.begins_with("2.") or text.begins_with("3."))
		cursor.set_meta("held", held)
		cursor.queue_redraw()
	demo_tween = create_tween()
	demo_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	demo_tween.tween_callback(func(): phase.call("1. Kliknij", false))
	demo_tween.tween_interval(0.55)
	demo_tween.tween_callback(func(): phase.call("2. Trzymaj LPM", true))
	demo_tween.tween_property(cursor, "scale", Vector2(0.88, 0.88), 0.18)
	demo_tween.tween_interval(0.4)
	demo_tween.tween_callback(func(): phase.call("3. Przeciągnij", true))
	demo_tween.tween_property(cursor, "position", target, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	demo_tween.tween_callback(func(): phase.call("4. Puść LPM", false))
	demo_tween.tween_property(cursor, "scale", Vector2.ONE, 0.18)
	demo_tween.tween_interval(0.55)
	demo_tween.tween_callback(func(): confirm.show(); phase.call("5. Wybierz wszystko", false))
	demo_tween.tween_interval(0.2)
	demo_tween.tween_property(cursor, "position", confirm.position + Vector2(35, 85), 0.5)
	demo_tween.tween_callback(func(): phase.call("5. Kliknij: Wszystko", true); all.modulate = Color(0.7, 1.0, 0.8))
	demo_tween.tween_interval(0.4)
	demo_tween.tween_callback(func(): phase.call("6. Potwierdź", false))
	demo_tween.tween_property(cursor, "position", confirm.position + Vector2(35, 125), 0.5)
	demo_tween.tween_callback(func(): phase.call("6. Kliknij lub Enter", true); go.modulate = Color(0.7, 1.0, 0.8))
	demo_tween.tween_interval(0.4)
	demo_tween.tween_callback(func(): confirm.hide(); phase.call("✓ Teraz Twoja kolej", false))
	demo_tween.tween_interval(1.8)
	demo_tween.tween_callback(demo_stop)


func close() -> void:
	demo_stop()
	ask_close()
	try_on = {}
	if visible and room == "wiktor":
		G.box_settle()
		if G.main != null:
			G.main.close_box()
	if room == "loot":
		# paczka, skrytka Wiktora albo rzeczy z ziemi: rozliczenie tego, co zabrano, i odłożenie reszty
		room = ""
		G.loot_close()
	visible = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func has_stash() -> bool:
	return room != "" and G.S.stash.has(room) and G.stash_cap(room) > 0


func render() -> void:
	demo_stop()
	var S: Dictionary = G.S
	_bag_refresh()
	l_cash.text = G.money(S.cash)
	l_clock.text = "%s  •  dzień %d" % [G.clock(), G.day()]
	K.clear(tabs_box)
	for t in TABS:
		var id: String = t[0]
		var on := id == tab
		var b := Button.new()
		b.text = String(t[1])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", load("res://assets/fonts/barlowc.ttf"))
		b.add_theme_font_size_override("font_size", 16)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0)
		st.border_color = Color(1, 1, 1, 0.85 if on else 0.0)
		st.border_width_bottom = 2
		st.content_margin_bottom = 4
		st.content_margin_top = 2
		st.content_margin_left = 3
		st.content_margin_right = 3
		for sn in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(sn, st)
		b.add_theme_color_override("font_color", T.C_HI if on else T.C_LOW)
		b.add_theme_color_override("font_hover_color", Color.WHITE if on else T.C_MID)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.pressed.connect(func():
			Sfx.play("click")
			tab = id
			sel = {}
			render())
		tabs_box.add_child(b)
	K.clear(content)
	if tab != "wear" and rig_outfit != G.outfit():
		set_rig(G.outfit())
	match tab:
		"char": _tab_char()
		"wear": _tab_wear()
		"org": _tab_org()
		_: _tab_inv()


func _frame(w: float, h: float, pad := 14) -> PanelContainer:
	var p := K.panel(T.panel_style(pad))
	p.custom_minimum_size = Vector2(w, h)
	return p


## tytuł panelu: sama nazwa, po prawej krótka liczba (czerwonawa tylko wtedy, gdy coś jest nie tak)
func _title(parent: Node, _ic: String, text: String, right := "", rcol := K.C_TXT) -> void:
	var h := K.hbox(8)
	h.add_child(K.head(text, 15, T.C_HI))
	h.add_child(K.spacer())
	if right != "":
		var rl := K.lbl(right, 12, T.C_ALERT if rcol == K.C_BAD else T.C_MID)
		rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(rl)
	parent.add_child(h)


# ---------------------------------------------------------------- zakładka: ekwipunek
func _tab_inv() -> void:
	var S: Dictionary = G.S
	var row := K.hbox(12)
	content.add_child(row)
	# --- lewa strona: plecak
	var cap := float(G.capacity())
	var used := G.carry_total()
	var left := _frame(W_SIDE, H_BODY)
	row.add_child(left)
	var lv := K.vbox(8)
	left.add_child(lv)
	_title(lv, "", G.bag_name().to_upper(), "%s / %d" % [G.units(used), int(cap)], K.C_BAD if used > cap - 0.5 else K.C_TXT)
	lv.add_child(_cap_bar(used, cap, K.C_BLUE))
	_list(lv, S.inv, "bag", "Pusto.")
	left.tooltip_text = "Przy zatrzymaniu tracisz wszystko, co masz przy sobie."
	left.set_drag_forwarding(Callable(), _can_drop.bind("bag"), _drop.bind("bag"))
	# --- środek: postać i szczegóły
	var mid := K.vbox(8)
	mid.custom_minimum_size = Vector2(W_MID, H_BODY)
	row.add_child(mid)
	var view := _char_view(W_MID, 396.0)
	mid.add_child(view)
	_gear_slots(view, W_MID, 396.0)
	mid.add_child(_detail())
	# --- prawa strona: skrytka albo ziemia
	if has_stash():
		var st: Dictionary = S.stash[room]
		var scap := float(G.stash_cap(room))
		var sused := G.store_total(st)
		var right := _frame(W_SIDE, H_BODY)
		row.add_child(right)
		var rv := K.vbox(8)
		right.add_child(rv)
		if room == "wiktor":
			# skrzynka Wiktora: tylko gotówka; po zamknięciu schodzi z zeszytu, a nadwyżka idzie na wkład
			_title(rv, "", "SKRZYNKA WIKTORA", "tylko gotówka")
			var due := ("po terminie" if G.credit_overdue() else "do dnia %d" % (int(float(S.credit_due) / 1440.0) + 1)) if float(S.credit) > 0.0 else ""
			var nxr: Dictionary = G.rank_next()
			var box := K.hbox(18)
			_num(box, G.money(S.credit), ("zeszyt • " + due) if due != "" else "zeszyt", G.credit_overdue())
			_num(box, G.money(S.paid), "Twój wkład")
			if not nxr.is_empty():
				_num(box, G.money(maxf(0.0, float(nxr.at) - S.paid)), "do awansu: %s" % String(nxr.name))
			rv.add_child(box)
			_list(rv, st, "stash", "Przeciągnij tu gotówkę.")
		elif room == "loot":
			# paczka / skrytka Wiktora / rzeczy na ziemi: bierzesz stąd do plecaka (na ziemię można też odkładać)
			var L: Dictionary = G.loot
			_title(rv, "", String(L.get("title", "POJEMNIK")), String(L.get("note", "")), K.C_DIM)
			var all: Button = T._mini("Zabierz wszystko", func():
				if G.loot_take_all() > 0:
					Sfx.play("pickup")
				else:
					G.notify("Nic więcej się nie zmieści w %s." % ("kieszeniach" if G.bag_name() == "Kieszenie" else "plecaku"), "warn")
					Sfx.play("error")
				sel = {}
				render(), "strong")
			all.disabled = G.entries(st).is_empty()
			all.custom_minimum_size = Vector2(0, 32)
			all.tooltip_text = String(L.get("hint", ""))
			rv.add_child(all)
			_list(rv, st, "stash", String(L.get("empty", "Pusto.")))
		else:
			_title(rv, "", String(D.ROOMS[room].name).to_upper(), "%s / %d" % [G.units(sused), int(scap)], K.C_BAD if sused > scap - 0.5 and scap > 0.0 else K.C_TXT)
			rv.add_child(_cap_bar(sused, scap, K.C_GOLD))
			_list(rv, st, "stash", "Pusto.")
		right.set_drag_forwarding(Callable(), _can_drop.bind("stash"), _drop.bind("stash"))
		hint.text = "przeciągnij rzecz na drugą stronę  •  kliknięcie pokazuje opis"
	else:
		# bez skrytki: po prawej „ziemia” — przerywana ramka, na którą upuszcza się to, co chcesz zostawić
		var right2 := _frame(W_SIDE, H_BODY)
		row.add_child(right2)
		var gv := K.vbox(8)
		right2.add_child(gv)
		var nb := _nearest_stash()
		_title(gv, "", "ZIEMIA", ("skrytka: " + nb) if nb != "" else "")
		var bin := _DropBox.new()
		bin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bin.set_drag_forwarding(Callable(), _can_drop.bind("bin"), _drop.bind("bin"))
		gv.add_child(bin)
		hint.text = "przeciągnij ubranie na pole przy postaci  •  kliknięcie pokazuje opis"


## duża liczba z drobnym podpisem (podsumowania zamiast zdań)
func _num(parent: Node, big: String, small: String, alert := false) -> void:
	var v := K.vbox(-2)
	v.add_child(K.head(big, 17, T.C_ALERT if alert else T.C_HI))
	v.add_child(K.lbl(small, 10, T.C_ALERT if alert else T.C_LOW))
	parent.add_child(v)


func _nearest_stash() -> String:
	var names := []
	for r in G.S.stash:
		if G.stash_cap(r) > 0 and (r == "safe" or G.room_owned(r)):
			names.append(String(D.ROOMS[r].name))
	return ", ".join(names)


func _cap_bar(used: float, cap: float, _color: Color) -> Control:
	var full := used > cap - 0.5 and cap > 0.0
	var b := K.bar(used, maxf(1.0, cap), T.C_ALERT if full else Color(1, 1, 1, 0.55), 3.0)
	b.add_theme_stylebox_override("background", K.pill(Color(1, 1, 1, 0.07), 1))
	return b


func _cash_row(st: Dictionary) -> Control:
	var S: Dictionary = G.S
	var v := K.vbox(6)
	var h := K.hbox(6)
	h.add_child(K.icon("banknote", 16, K.C_ACC))
	h.add_child(K.rich("Gotówka w skrytce: [b]%s[/b]" % G.money(st.cash), 13))
	v.add_child(h)
	var hb := K.hbox(6)
	var b1 := K.btn("Wpłać 500", func(): G.move_cash(room, true, 500.0); render(), "", true)
	b1.disabled = S.cash < 1.0
	var b2 := K.btn("Wpłać wszystko", func(): G.move_cash(room, true, 1e12); render(), "", true)
	b2.disabled = S.cash < 1.0
	var b3 := K.btn("Wypłać 500", func(): G.move_cash(room, false, 500.0); render(), "", true)
	b3.disabled = float(st.cash) < 1.0
	var b4 := K.btn("Wypłać wszystko", func(): G.move_cash(room, false, 1e12); render(), "", true)
	b4.disabled = float(st.cash) < 1.0
	for b in [b1, b2, b3, b4]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(b)
	v.add_child(hb)
	return v


## slot wyposażenia przy postaci (kolumna 0/1, wiersz 0/1)
func _slot(view: Control, cx: int, cy: int, ic: String, cap: String, val: String, sub: String) -> void:
	var p := K.panel(K.sb(Color(0.048, 0.053, 0.066, 0.9), 9, Color(1, 1, 1, 0.1), 1, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(112, 0)
	view.add_child(p)
	p.anchor_left = float(cx)
	p.anchor_right = float(cx)
	p.anchor_top = float(cy)
	p.anchor_bottom = float(cy)
	p.grow_horizontal = Control.GROW_DIRECTION_END if cx == 0 else Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_END if cy == 0 else Control.GROW_DIRECTION_BEGIN
	var v := K.vbox(1)
	p.add_child(v)
	var h := K.hbox(5)
	h.add_child(K.icon(ic, 13, T.C_LOW))
	h.add_child(K.lbl(cap, 9, K.C_DIM))
	v.add_child(h)
	v.add_child(K.head(val, 15, K.C_TXT))
	v.add_child(K.lbl(sub, 10, K.C_DIM))


# ---------------------------------------------------------------- lista pozycji
func _list(parent: Node, st: Dictionary, side: String, empty: String) -> void:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.set_drag_forwarding(Callable(), _can_drop.bind(side), _drop.bind(side))
	parent.add_child(sc)
	var rows := K.vbox(3)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.set_drag_forwarding(Callable(), _can_drop.bind(side), _drop.bind(side))
	rows.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(rows)
	var list := G.entries(st)
	if list.is_empty():
		var l2 := K.wrap(empty, 12, T.C_LOW)
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mg := MarginContainer.new()
		mg.add_theme_constant_override("margin_left", 8)
		mg.add_theme_constant_override("margin_top", 10)
		mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mg.add_child(l2)
		rows.add_child(mg)
	for e in list:
		rows.add_child(_row(e, side))


func _is_sel(e: Dictionary, side: String) -> bool:
	return not sel.is_empty() and sel.side == side and sel.kind == e.kind and sel.p == e.p and int(sel.pur) == int(e.pur) and sel.id == e.id and int(sel.get("g", 1)) == int(e.get("g", 1))


func _ecolor(e: Dictionary) -> Color:
	# towar nie ma już kolorów jakości: każda pozycja jest szara, a czystość stoi w opisie
	return Color(0.62, 0.66, 0.74)


## wiersz: ikona, nazwa, krótki opis i ilość. Miejsce i waga są w podpowiedzi oraz w karcie po kliknięciu.
func _row(e: Dictionary, side: String) -> Control:
	var on := _is_sel(e, side)
	var p := K.panel(T._flat(0.09 if on else 0.03, 0.4 if on else 0.0, 9, 5, 7))
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.tooltip_text = "miejsce %s  •  waga %s" % [G.units(e.size), G.weight_text(e.weight)]
	p.mouse_entered.connect(func():
		if not _is_sel(e, side):
			p.add_theme_stylebox_override("panel", T._flat(0.07, 0.16, 9, 5, 7)))
	p.mouse_exited.connect(func():
		if not _is_sel(e, side):
			p.add_theme_stylebox_override("panel", T._flat(0.03, 0.0, 9, 5, 7)))
	var h := K.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ib := CenterContainer.new()
	ib.custom_minimum_size = Vector2(34, 34)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.add_child(K.icon(e.icon, 34 if K.is_item(e.icon) else 20, T.C_MID))
	h.add_child(ib)
	var nv := K.vbox(-2)
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := K.lbl(e.name, 14, T.C_HI)
	nl.clip_text = true
	nv.add_child(nl)
	var sub := String(e.sub)
	if int(e.tier) >= 0:
		sub = "%d%%%s  •  %s" % [int(e.pur), " mieszanka" if (String(e.kind) != "item" and G.is_mix(e.pur)) else "", e.sub]
	if sub != "":
		nv.add_child(K.lbl(sub, 11, T.C_LOW))
	h.add_child(nv)
	var ql := K.head(String(e.qty), 15, T.C_HI)
	ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ql)
	p.gui_input.connect(_row_input.bind(e, side))
	p.set_meta("demo_entry", e)
	p.set_meta("demo_side", side)
	p.set_drag_forwarding(_drag.bind(e, side), _can_drop.bind(side), _drop.bind(side))
	return p


func _row_input(ev: InputEvent, e: Dictionary, side: String) -> void:
	if not (ev is InputEventMouseButton) or ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	Sfx.play("click")
	if ev.double_click and side == "bag" and e.kind == "item" and G.is_gear(String(e.id)):
		G.gear_wear(String(e.id))
		sel = {}
		render()
		return
	if ev.double_click and has_stash():
		ask_amount(e, side, "stash" if side == "bag" else "bag")
		return
	sel = {"side": side, "kind": e.kind, "p": e.p, "pur": int(e.pur), "id": e.id, "g": int(e.get("g", 1))}
	render()


# ---------------------------------------------------------------- przenoszenie: przeciągnij i wybierz ilość
func _drag(_at: Vector2, e: Dictionary, side: String) -> Variant:
	var pv := K.panel(K.sb(Color(0.06, 0.07, 0.09, 0.96), 7, Color(1, 1, 1, 0.4), 1, 8))
	var h := K.hbox(8)
	pv.add_child(h)
	h.add_child(K.icon(e.icon, 30 if K.is_item(e.icon) else 18, T.C_MID))
	h.add_child(K.lbl("%s  •  %s" % [e.name, e.qty], 13, T.C_HI))
	var holder := Control.new()
	holder.add_child(pv)
	pv.position = Vector2(12, 8)
	holder.z_index = 100
	set_drag_preview(holder)
	return {"e": e, "side": side}


func _can_drop(_at: Vector2, data: Variant, side: String) -> bool:
	if not (data is Dictionary):
		return false
	# ubranie zdejmowane z postaci wraca tylko do plecaka
	if data.has("gear"):
		return side == "bag"
	if not data.has("e"):
		return false
	if side == "bin":
		return data.side == "bag" and String(data.e.kind) != "cash"
	return data.side != side and has_stash()


func _drop(_at: Vector2, data: Variant, side: String) -> void:
	if data.has("gear"):
		G.gear_off(String(data.gear))
		sel = {}
		render()
		return
	ask_amount(data.e, data.side, side)


# ---------------------------------------------------------------- ubrania: pola wokół postaci
## Sześć pól jak na szkicu: po prawej czapka, góra i rękawiczki, po lewej dodatek, spodnie i buty — każde na wysokości
## swojej części ciała, połączone z nią kreską. Ubranie zakłada się, przeciągając je z plecaka na pole.
func _gear_slots(view: Control, w: float, h: float) -> void:
	var lines := Control.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(lines)
	var marks: Array = []
	var sw := 152.0
	var sh := 52.0
	for e in D.GEAR_SLOTS:
		var slot: String = e[0]
		var side: int = e[2]
		var y := clampf(float(e[3]) * h - sh * 0.5, 0.0, h - sh)
		var id: String = G.gear(slot)
		var on: bool = not sel.is_empty() and String(sel.side) == "gear" and String(sel.id) == id and id != ""
		var p := K.panel(K.sb(Color(0.05, 0.057, 0.072, 0.94) if id != "" else Color(0.04, 0.046, 0.058, 0.8), 7, Color(1, 1, 1, 0.6 if on else (0.26 if id != "" else 0.1)), 1, 6))
		p.custom_minimum_size = Vector2(sw, sh)
		p.size = Vector2(sw, sh)
		p.position = Vector2(0.0 if side < 0 else w - sw, y)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.tooltip_text = "%s — przeciągnij tu ubranie z plecaka" % String(e[1]) if id == "" else "Dwuklik albo przeciągnięcie do plecaka zdejmuje."
		view.add_child(p)
		var hb := K.hbox(6)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(hb)
		if id != "":
			var ic := K.icon(String(D.ITEMS[id].icon), 28, K.C_TXT)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(ic)
		var vb := K.vbox(0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(K.lbl(String(e[1]).to_upper(), 9, T.C_LOW))
		var marks_fx: Array = G.stat_marks(D.ITEMS[id].get("stats", {})) if id != "" else []
		# puste pole to sama nazwa miejsca — bez słowa „puste”
		if id != "":
			var nl := K.wrap(String(D.ITEMS[id].name), 11, T.C_HI, sw - (48.0 + (44.0 if not marks_fx.is_empty() else 0.0)))
			nl.max_lines_visible = 2
			nl.add_theme_constant_override("line_spacing", -2)
			nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(nl)
		hb.add_child(vb)
		# cechy ubrania: wartość z ikoną po prawej stronie pola, jedna pod drugą; zielone pomagają, czerwone szkodzą
		if not marks_fx.is_empty():
			var fx := K.vbox(-1)
			fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fx.alignment = BoxContainer.ALIGNMENT_CENTER
			var tips: Array = []
			for mk in marks_fx:
				var mc: Color = T.C_MID if mk.good else T.C_ALERT
				var mr := K.hbox(2)
				mr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mr.alignment = BoxContainer.ALIGNMENT_END
				var big: bool = marks_fx.size() <= 2
				var ml := K.lbl(String(mk.text), 11 if big else 10, mc)
				ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mr.add_child(ml)
				var mi := K.icon(String(mk.icon), 14 if big else 12, mc)
				mi.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mr.add_child(mi)
				fx.add_child(mr)
				tips.append(String(mk.tip))
			hb.add_child(fx)
			p.tooltip_text = "%s\n%s" % [", ".join(tips), p.tooltip_text]
		p.set_drag_forwarding(_drag_gear.bind(slot), _can_drop_gear.bind(slot), _drop_gear.bind(slot))
		p.gui_input.connect(_gear_input.bind(slot))
		# kreska od pola do sylwetki
		var x0 := sw if side < 0 else w - sw
		var x1 := w * 0.5 + side * (26.0 if slot != "dlonie" else 52.0)
		marks.append([Vector2(x0, y + sh * 0.5), Vector2(x1, float(e[3]) * h)])
	lines.draw.connect(func():
		for m in marks:
			lines.draw_line(m[0], m[1], Color(1, 1, 1, 0.16), 1.0, true)
			lines.draw_rect(Rect2(m[1] - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 1, 1, 0.6)))
	# plecak: decyduje o tym, ile się zmieści (kupujesz u Stasia)
	var bp := K.panel(K.sb(Color(0.04, 0.046, 0.058, 0.8), 7, Color(1, 1, 1, 0.1), 1, 6))
	bp.custom_minimum_size = Vector2(sw, sh)
	bp.size = Vector2(sw, sh)
	bp.position = Vector2(w - sw, h - sh)
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(bp)
	var bh := K.hbox(6)
	bp.add_child(bh)
	bh.add_child(K.icon("backpack", 18, T.C_MID))
	var bv := K.vbox(0)
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_child(K.lbl("%d MIEJSC" % int(G.capacity()), 9, T.C_LOW))
	var bl := K.lbl(G.bag_name(), 11, T.C_HI)
	bl.clip_text = true
	bl.custom_minimum_size = Vector2(sw - 36.0, 0)
	bv.add_child(bl)
	bh.add_child(bv)


func _gear_input(ev: InputEvent, slot: String) -> void:
	if not (ev is InputEventMouseButton) or ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	var id: String = G.gear(slot)
	if id == "":
		return
	Sfx.play("click")
	if ev.double_click:
		G.gear_off(slot)
		sel = {}
	else:
		sel = {"side": "gear", "kind": "item", "p": "", "pur": 0, "id": id}
	render()


func _drag_gear(_at: Vector2, slot: String) -> Variant:
	var id: String = G.gear(slot)
	if id == "":
		return null
	var pv := K.panel(K.sb(Color(0.06, 0.07, 0.09, 0.96), 7, Color(1, 1, 1, 0.4), 1, 8))
	var h := K.hbox(8)
	pv.add_child(h)
	h.add_child(K.icon(String(D.ITEMS[id].icon), 40, K.C_TXT))
	h.add_child(K.lbl(String(D.ITEMS[id].name), 14, K.C_TXT))
	var holder := Control.new()
	holder.add_child(pv)
	pv.position = Vector2(12, 8)
	holder.z_index = 100
	set_drag_preview(holder)
	return {"gear": slot}


func _can_drop_gear(_at: Vector2, data: Variant, slot: String) -> bool:
	return data is Dictionary and data.has("e") and String(data.side) == "bag" and String(data.e.kind) == "item" \
		and G.is_gear(String(data.e.id)) and String(D.ITEMS[String(data.e.id)].slot) == slot


func _drop_gear(_at: Vector2, data: Variant, _slot: String) -> void:
	G.gear_wear(String(data.e.id))
	sel = {}
	render()


func _fmt_amount(e: Dictionary, v: float) -> String:
	if String(e.kind) == "cash":
		return G.money(v)
	if String(e.unit) == "g":
		return G.grams(v)
	return "%d %s" % [int(round(v)), e.unit]


## Okno wyboru ilości po upuszczeniu przedmiotu: suwak, pole do wpisania liczby
## oraz podgląd, ile to waży i ile miejsca zajmie. `to` = "stash" | "bag" | "bin".
func ask_amount(e: Dictionary, from: String, to: String) -> void:
	demo_stop()
	var step: float = e.get("step", 1.0)
	var limit: float = float(e.n) if to == "bin" else G.move_limit(room, e, to == "stash")
	if limit < step - 0.001:
		if room == "loot" and to == "stash":
			G.notify("Tu tylko wyjmujesz — do tej skrytki nic się nie odkłada.", "warn")
		else:
			G.notify("Brak miejsca w %s." % ("skrytce" if to == "stash" else "plecaku"), "warn")
		Sfx.play("error")
		return
	if float(e.n) <= step + 0.001 and not (room == "safe" and String(e.get("id", "")) == "notes" and to == "stash"):
		_apply_move(e, to, float(e.n))
		return
	ask_close()
	ask = {"e": e, "from": from, "to": to, "max": limit, "step": step, "v": limit}
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	ask_box = dim
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var bin := to == "bin"
	var edge: Color = T.C_ALERT if bin else Color(1, 1, 1, 0.75)
	var p := K.panel(K.sb(Color(0.05, 0.057, 0.072, 0.99), 10, Color(edge.r, edge.g, edge.b, 0.4), 1, 16))
	p.custom_minimum_size = Vector2(420, 0)
	cc.add_child(p)
	var v := K.vbox(10)
	p.add_child(v)
	# co i dokąd
	var hd := K.hbox(10)
	hd.add_child(K.icon(e.icon, 34 if K.is_item(e.icon) else 20, T.C_MID))
	var hv := K.vbox(-2)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(K.head(e.name, 17, T.C_HI))
	var sub := String(e.sub)
	if int(e.tier) >= 0:
		sub = "%d%%  •  %s" % [int(e.pur), e.sub]
	if sub != "":
		hv.add_child(K.lbl(sub, 11, T.C_LOW))
	hd.add_child(hv)
	var route := K.hbox(6)
	route.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var names := {"bag": G.bag_name(), "stash": "Skrytka", "bin": "Na ziemię"}
	route.add_child(K.lbl(String(names[from]), 11, T.C_LOW))
	route.add_child(K.icon("chevron_right", 13, T.C_MID))
	route.add_child(K.lbl(String(names[to]), 12, T.C_ALERT if bin else T.C_HI))
	hd.add_child(route)
	v.add_child(hd)
	# wybrana ilość, a pod nią waga i miejsce
	ask_big = K.head("", 30, T.C_HI)
	ask_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ask_big)
	ask_sub = K.lbl("", 11, T.C_LOW)
	ask_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ask_sub)
	# suwak z przyciskami − / + i polem do wpisania liczby
	var row := K.hbox(8)
	v.add_child(row)
	var minus: Button = T._mini("−", func(): _ask_set(float(ask.v) - step))
	minus.custom_minimum_size = Vector2(30, 28)
	row.add_child(minus)
	ask_slider = HSlider.new()
	ask_slider.min_value = step
	ask_slider.max_value = limit
	ask_slider.step = step
	ask_slider.value = limit
	ask_slider.focus_mode = Control.FOCUS_NONE
	ask_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ask_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ask_slider.custom_minimum_size = Vector2(0, 20)
	ask_slider.add_theme_stylebox_override("slider", T._flat(0.12, 0.0, 0, 2, 2))
	ask_slider.add_theme_stylebox_override("grabber_area", T._flat(0.5, 0.0, 0, 2, 2))
	ask_slider.add_theme_stylebox_override("grabber_area_highlight", T._flat(0.7, 0.0, 0, 2, 2))
	ask_slider.value_changed.connect(func(val): _ask_set(val, false))
	row.add_child(ask_slider)
	var plus: Button = T._mini("+", func(): _ask_set(float(ask.v) + step))
	plus.custom_minimum_size = Vector2(30, 28)
	row.add_child(plus)
	ask_edit = LineEdit.new()
	ask_edit.custom_minimum_size = Vector2(70, 28)
	ask_edit.add_theme_font_size_override("font_size", 13)
	ask_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask_edit.max_length = 6
	ask_edit.select_all_on_focus = true
	ask_edit.tooltip_text = "Wpisz ilość"
	ask_edit.add_theme_stylebox_override("normal", K.sb(Color(0.03, 0.035, 0.045), 6, Color(1, 1, 1, 0.16), 1, 6))
	ask_edit.add_theme_stylebox_override("focus", K.sb(Color(0.03, 0.035, 0.045), 6, Color(1, 1, 1, 0.5), 1, 6))
	ask_edit.text_changed.connect(_ask_typed)
	ask_edit.text_submitted.connect(func(_t): ask_ok())
	row.add_child(ask_edit)
	var mm := K.hbox(0)
	mm.add_child(K.lbl(_fmt_amount(e, step), 10, T.C_LOW))
	mm.add_child(K.spacer())
	var cap_note := "wszystko" if limit >= float(e.n) - 0.001 else "tyle się zmieści"
	mm.add_child(K.lbl("%s  (%s)" % [_fmt_amount(e, limit), cap_note], 10, T.C_LOW if limit >= float(e.n) - 0.001 else T.C_ALERT))
	v.add_child(mm)
	var bh := K.hbox(8)
	v.add_child(bh)
	bh.add_child(T._mini("Anuluj  [Esc]", ask_close, "text"))
	bh.add_child(K.spacer())
	bh.add_child(T._mini("Wszystko", func(): _ask_set(float(ask.max))))
	ask_go = T._mini("", ask_ok, "strong")
	ask_go.custom_minimum_size = Vector2(150, 28)
	bh.add_child(ask_go)
	_ask_set(limit)
	Sfx.play("open")
	p.pivot_offset = Vector2(210, 90)
	p.scale = Vector2(0.94, 0.94)
	dim.modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.12)
	tw.tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func asking() -> bool:
	return not ask.is_empty()


func _ask_set(val: float, move_slider := true, from_edit := false) -> void:
	if ask.is_empty():
		return
	var step: float = ask.step
	var v2 := clampf(snappedf(val, step), step, float(ask.max))
	ask.v = v2
	var e: Dictionary = ask.e
	ask_big.text = _fmt_amount(e, v2)
	ask_sub.text = "miejsce %s  •  %s" % [G.units(v2 * float(e.usize)), G.weight_text(v2 * float(e.uw))]
	var verb := "Wyrzuć" if ask.to == "bin" else "Przenieś"
	ask_go.text = "Przenieś wszystko  [Enter]" if ask.to != "bin" and v2 >= float(e.n) - 0.001 else "%s %s  [Enter]" % [verb, _fmt_amount(e, v2)]
	if move_slider and absf(ask_slider.value - v2) > 0.001:
		ask_slider.set_value_no_signal(v2)
	if not from_edit:
		ask_edit.text = G.units(v2) if step < 1.0 else str(int(v2))


func _ask_typed(t: String) -> void:
	var clean := t.strip_edges().replace(",", ".")
	if clean.is_valid_float():
		_ask_set(clean.to_float(), true, true)


func ask_ok() -> void:
	if ask.is_empty():
		return
	var e: Dictionary = ask.e
	var to: String = ask.to
	var amount: float = ask.v
	ask_close()
	_apply_move(e, to, amount)


func ask_close() -> void:
	ask = {}
	if ask_box != null and is_instance_valid(ask_box):
		ask_box.queue_free()
	ask_box = null


func _apply_move(e: Dictionary, to: String, amount: float) -> void:
	if to == "bin":
		G.discard_entry(e, amount)
		Sfx.play("drop")
		sel = {}
	else:
		var moved := G.move_entry(room, e, to == "stash", amount)
		if moved > 0.0:
			Sfx.play("select")
	render()


func _find_sel() -> Dictionary:
	if sel.is_empty():
		return {}
	if String(sel.side) == "gear":
		var gid := String(sel.id)
		if not D.ITEMS.has(gid):
			return {}
		var gd: Dictionary = D.ITEMS[gid]
		return {"kind": "item", "p": "", "pur": 0, "id": gid, "n": 1.0, "name": gd.name, "sub": "na sobie", "icon": gd.icon, "tier": -1, "qty": "na sobie",
			"usize": 0.0, "uw": 0.0, "step": 1.0, "unit": "szt.", "size": 0.0, "weight": 0.0, "desc": gd.desc}
	var st: Dictionary = G.S.inv if sel.side == "bag" else G.S.stash.get(room, {})
	if st.is_empty():
		return {}
	for e in G.entries(st):
		if _is_sel(e, sel.side):
			return e
	return {}


## Karta pod postacią. Nic nie zaznaczone: trzy liczby o tym, co niesiesz. Zaznaczona rzecz: nazwa, opis
## i jedna linijka danych. Żadnych instrukcji — od nich są podpowiedzi „pierwszy raz”.
func _detail() -> Control:
	var p := _frame(W_MID, 0, 12)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := K.vbox(6)
	p.add_child(v)
	var S: Dictionary = G.S
	var e := _find_sel()
	if e.is_empty():
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var goods := G.carry_goods()
		var box := K.hbox(0)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 26)
		_num(box, ("ok. " + G.money(G.carry_value())) if goods > 0.0 else "—", "wartość na ulicy")
		_num(box, "%d g" % G.packed_total(S.inv), "w %d paczkach" % G.packed_bags(S.inv))
		_num(box, G.weight_text(G.store_weight(S.inv)), "waga")
		v.add_child(box)
		p.tooltip_text = "Przy kontroli stracisz: %s. Przy zatrzymaniu — wszystko, co masz przy sobie." % (G.grams(goods) if goods > 0.0 else "nic")
		return p
	var h := K.hbox(10)
	h.add_child(K.icon(e.icon, 38 if K.is_item(e.icon) else 22, T.C_MID))
	var hv := K.vbox(-2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := K.head(e.name, 17, T.C_HI)
	nm.clip_text = true
	hv.add_child(nm)
	var bits: Array = [String(e.qty)]
	if int(e.tier) >= 0:
		bits.append("%d%%" % int(e.pur))
	if float(e.size) > 0.0:
		bits.append("miejsce %s" % G.units(e.size))
	if float(e.weight) > 0.0:
		bits.append(G.weight_text(e.weight))
	if e.kind != "item" and e.kind != "cash":
		bits.append("ok. %s/g" % G.money(G.market_price(e.p, e.pur)))
	hv.add_child(K.lbl("  •  ".join(bits), 11, T.C_LOW))
	h.add_child(hv)
	v.add_child(h)
	var dl := K.wrap(e.desc, 12, T.C_MID)
	dl.max_lines_visible = 3
	v.add_child(dl)
	# ubranie: co daje
	if e.kind == "item" and G.is_gear(String(e.id)):
		var parts: Array = []
		for t in G.stat_traits(D.ITEMS[String(e.id)].get("stats", {})):
			parts.append(K.col(String(t.text), T.C_HI if t.good else T.C_ALERT))
		if not parts.is_empty():
			v.add_child(K.rich("   ".join(parts), 12))
	v.add_child(K.spacer())
	var act := K.hbox(0)
	act.add_child(K.spacer())
	if sel.side == "bag" and e.kind == "item" and e.id == "burner":
		act.add_child(T._mini("Użyj — zmień numer", func(): G.use_burner(); render(), "strong"))
		v.add_child(act)
	elif sel.side == "bag" and e.kind == "item" and G.is_gear(String(e.id)):
		var gid2 := String(e.id)
		act.add_child(T._mini("Załóż", func(): G.gear_wear(gid2); sel = {}; render(), "strong"))
		v.add_child(act)
	return p


# ---------------------------------------------------------------- zakładka: postać
func _stat(parent: Node, ic: String, name: String, val: String, color := K.C_TXT) -> void:
	var h := K.hbox(8)
	h.add_child(K.icon(ic, 14, T.C_LOW))
	h.add_child(K.lbl(name, 12, T.C_MID))
	h.add_child(K.spacer())
	h.add_child(K.head(val, 15, T.C_ALERT if (color == K.C_BAD or color == K.C_WARN) else T.C_HI))
	parent.add_child(h)


func _tab_char() -> void:
	var S: Dictionary = G.S
	var row := K.hbox(12)
	content.add_child(row)
	var left := K.vbox(8)
	left.custom_minimum_size = Vector2(W_MID + 60.0, H_BODY)
	row.add_child(left)
	var view := _char_view(W_MID + 60.0, 398.0)
	left.add_child(view)
	var poses:=K.hbox(4)
	left.add_child(poses)
	for i in range(3):
		var pose_index:int=i
		poses.add_child(K.btn(["Stanie","Chód","Bieg"][i],func(): preview_pose(pose_index),"",true))
	var idc := _frame(W_MID + 60.0, 0, 12)
	idc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(idc)
	var iv := K.vbox(4)
	idc.add_child(iv)
	var lvl := int(S.lvl)
	iv.add_child(K.head("KUBA", 26, K.C_TXT))
	iv.add_child(K.lbl("poz. %d  •  %s" % [lvl, D.LEVEL_TITLES[mini(lvl - 1, D.LEVEL_TITLES.size() - 1)]], 13, T.C_MID))
	var lo := float(D.XP_LEVELS[mini(lvl - 1, D.XP_LEVELS.size() - 1)])
	var hi := float(D.XP_LEVELS[mini(lvl, D.XP_LEVELS.size() - 1)])
	iv.add_child(K.bar(float(S.xp) - lo, maxf(1.0, hi - lo), Color(1, 1, 1, 0.6), 4.0))
	iv.add_child(K.lbl("%d / %d PD" % [int(S.xp), int(hi)], 11, K.C_DIM))
	# środek: statystyki
	var mid := _frame(W_SIDE - 30.0, H_BODY)
	row.add_child(mid)
	var mv := K.vbox(7)
	mid.add_child(mv)
	_title(mv, "trending_up", "DOROBEK")
	_stat(mv, "banknote", "Zarobione", G.money(S.stats.earned), K.C_ACC)
	_stat(mv, "receipt", "Wydane", G.money(S.stats.spent))
	_stat(mv, "handshake", "Transakcje", str(int(S.stats.deals)))
	_stat(mv, "weight", "Sprzedane gramy", str(int(S.stats.sold)))
	_stat(mv, "star", "Najlepsza transakcja", G.money(S.stats.best))
	_stat(mv, "users", "Klienci", "%d / %d" % [G.client_count(), D.CLIENTS.size()])
	mv.add_child(K.gap(4))
	_title(mv, "footprints", "ULICA")
	_stat(mv, "route", "Przebyte", ("%.1f km" % (float(S.stats.get("dist", 0.0)) / 1000.0)).replace(".", ","))
	_stat(mv, "frown", "Zerwane rozmowy", str(int(S.stats.walked)))
	_stat(mv, "package_open", "Odebrane paczki", str(int(S.stats.pickups)))
	_stat(mv, "scale", "Zaporcjowane / rozsypane", "%d / %d g" % [int(S.stats.packed), int(S.stats.wasted)])
	_stat(mv, "sprout", "Wyhodowane", "%d g" % int(S.stats.grown))
	if G.fed():
		# po kebabie albo drożdżówce: do której trzyma dodatkowa kondycja
		_stat(mv, "wind", "Najedzony (+20% kondycji)", "do " + G.clock(float(S.fed_until)))
	mv.add_child(K.gap(4))
	_title(mv, "siren", "POLICJA")
	_stat(mv, "flame", "Gorąco", "%d%%" % int(S.heat), K.C_BAD if float(S.heat) > 60.0 else K.C_TXT)
	_stat(mv, "search", "Śledztwo", "%d%%" % int(S.invest), K.C_BAD if float(S.invest) > 60.0 else K.C_TXT)
	_stat(mv, "shield_alert", "Zatrzymania", "%d / %d" % [int(S.arrests), D.MAX_ARRESTS], K.C_WARN if int(S.arrests) > 0 else K.C_TXT)
	_stat(mv, "users", "U Wiktora", String(G.rank_def().name), K.C_ACC)
	_stat(mv, "wind", "Udane ucieczki", str(int(S.stats.escapes)))
	# prawa: umiejętności i wyposażenie
	var right := _frame(W_SIDE - 30.0, H_BODY)
	row.add_child(right)
	var rv := K.vbox(7)
	right.add_child(rv)
	_title(rv, "brain", "UMIEJĘTNOŚCI", "%d pkt" % int(S.sp) if int(S.sp) > 0 else "", K.C_GOLD)
	var any := false
	for sk in D.SKILLS:
		if G.has_skill(sk.id):
			any = true
			rv.add_child(K.rich("[b]%s[/b]  %s\n%s" % [sk.name, K.col(sk.branch, K.C_DIM), K.col(sk.desc, K.C_DIM)], 12))
	if not any:
		rv.add_child(K.wrap("Jeszcze żadnej. Punkty dostajesz za poziomy — wydasz je w telefonie, w aplikacji Rozwój.", 13, K.C_DIM))
	rv.add_child(K.gap(4))
	_title(rv, "wrench", "WYPOSAŻENIE")
	if G.upg("plecak1"):
		backpack_button=K.btn("Zamknij kieszeń" if bag_mesh.opened else "Obejrzyj plecak",inspect_backpack,"",true)
		rv.add_child(backpack_button)
		rv.add_child(K.lbl("Zapełnienie: %s / %s miejsc" %[G.units(G.carry_total()),G.units(G.capacity())],11,T.C_MID))
	var anyu := false
	for u in D.UPGRADES:
		if G.upg(u.id):
			anyu = true
			rv.add_child(K.rich("[b]%s[/b]\n%s" % [u.name, K.col(u.desc, K.C_DIM)], 12))
	if not anyu:
		rv.add_child(K.wrap("Nic. Plecak, lepszą wagę i skrytkę w podłodze kupisz w Sklepie u Stasia.", 13, K.C_DIM))
	rv.add_child(K.spacer())
	rv.add_child(K.btn("Otwórz drzewko umiejętności", func(): ui.open_phone("rozwoj"), "", true))
	hint.text = "Przeciągnij, żeby obrócić  •  przyciski pod postacią pokazują ubrania podczas ruchu"


# ---------------------------------------------------------------- zakładka: ubrania
## Ubrania na sztuki: po lewej postać w tym, co ma na sobie, po prawej wieszak pogrupowany polami (czapka, dodatek, góra…).
## Kupować można tylko w „Taniej Odzieży”; lepsze rzeczy sklep odkłada dla klientów z wyższym poziomem.
var wear_offer: Array = []      # co aktualnie wisi na wieszaku (do testów)

func _tab_wear() -> void:
	var S: Dictionary = G.S
	var in_shop: bool = G.player != null and G.player.loc == "ciuchy"
	var can_change: bool = G.can_change_here()
	set_rig(G.outfit())
	_dress()
	var row := K.hbox(12)
	content.add_child(row)
	var left := K.vbox(8)
	left.custom_minimum_size = Vector2(W_MID + 60.0, H_BODY)
	row.add_child(left)
	left.add_child(_char_view(W_MID + 60.0, 400.0))
	var idc := _frame(W_MID + 60.0, 0, 12)
	idc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(idc)
	var iv := K.vbox(3)
	idc.add_child(iv)
	iv.add_child(K.lbl("MASZ NA SOBIE", 10, T.C_LOW))
	for se in D.GEAR_SLOTS:
		var wid: String = G.gear(String(se[0]))
		var wr := K.hbox(6)
		iv.add_child(wr)
		var sl := K.lbl(String(se[1]), 11, K.C_DIM)
		sl.custom_minimum_size = Vector2(84, 0)
		wr.add_child(sl)
		var wn := K.lbl(String(D.ITEMS[wid].name) if wid != "" else "—", 12, K.C_TXT if wid != "" else K.C_DIM)
		wn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wn.clip_text = true
		wr.add_child(wn)
		if wid != "":
			wr.add_child(_marks(G.stat_marks(D.ITEMS[wid].get("stats", {})), false))
	# komplet: aktywny (z premią) albo ten, do którego brakuje jednej rzeczy
	var sets: Array = G.gear_sets()
	var near: Dictionary = G.gear_set_near()
	if not sets.is_empty() or not near.is_empty():
		var kr := K.hbox(6)
		iv.add_child(kr)
		var kl := K.lbl("Komplet", 11, K.C_DIM)
		kl.custom_minimum_size = Vector2(84, 0)
		kr.add_child(kl)
		var kn := K.lbl("", 12, K.C_TXT)
		kn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kn.clip_text = true
		kr.add_child(kn)
		if not sets.is_empty():
			var names: Array = []
			var sum := {}
			for gs in sets:
				names.append(String(gs.name))
				for sk in gs.stats:
					sum[sk] = (float(sum.get(sk, 0.0)) + float(gs.stats[sk])) if sk == "cap" else (float(sum.get(sk, 1.0)) * float(gs.stats[sk]))
			kn.text = ", ".join(names)
			kr.tooltip_text = String(sets[0].desc)
			kr.add_child(_marks(G.stat_marks(sum), false))
		else:
			var slot_name := ""
			for se2 in D.GEAR_SLOTS:
				if String(se2[0]) == String(near.slot):
					slot_name = String(se2[1]).to_lower()
			kn.text = "%s — brakuje: %s" % [String(near.set.name), slot_name]
			kn.add_theme_color_override("font_color", K.C_DIM)
			kr.tooltip_text = String(near.set.desc)
	# prawa strona: wieszak
	var right := _frame(W_SIDE * 2.0 - 48.0, H_BODY)
	row.add_child(right)
	var rv := K.vbox(8)
	right.add_child(rv)
	_title(rv, "store", "TANIA ODZIEŻ — WIESZAK" if in_shop else "UBRANIA", G.money(S.cash) if in_shop else "", K.C_ACC)
	if not in_shop:
		rv.add_child(K.wrap("Kupisz je w Taniej Odzieży przy Hutniczej.", 12, T.C_LOW))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(sc)
	var list := K.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	wear_offer.clear()
	for se in D.GEAR_SLOTS:
		var slot := String(se[0])
		var ids: Array = []
		for gid in D.ITEMS:
			if String(D.ITEMS[gid].get("slot", "")) == slot:
				ids.append(gid)
		ids.sort_custom(func(a, b): return int(D.ITEMS[a].lvl) * 100000 + int(D.ITEMS[a].price) < int(D.ITEMS[b].lvl) * 100000 + int(D.ITEMS[b].price))
		var head_done := false
		for gid in ids:
			var iid: String = gid
			var gd: Dictionary = D.ITEMS[iid]
			var worn: bool = G.gear(slot) == iid
			var have: bool = worn or G.item(iid) > 0
			if not in_shop and not have:
				continue
			if not head_done:
				head_done = true
				list.add_child(K.lbl(String(se[1]).to_upper(), 10, T.C_LOW))
			wear_offer.append(iid)
			var glocked: bool = int(S.lvl) < int(gd.lvl)
			var gc := K.panel(T._flat(0.07 if worn else 0.03, 0.4 if worn else 0.0, 9, 6, 7))
			list.add_child(gc)
			var in_sets: Array = G.gear_sets_of(iid)
			if not in_sets.is_empty():
				# dymek: do jakiego kompletu należy ta rzecz i co daje cały komplet
				var tips: Array = []
				for gs2 in in_sets:
					var marks: Array = []
					for mk2 in G.stat_marks(gs2.stats):
						marks.append(String(mk2.tip))
					tips.append("Część kompletu „%s” (%s). %s" % [String(gs2.name), ", ".join(marks), String(gs2.desc)])
				gc.tooltip_text = "\n".join(tips)
			if not worn:
				# najechanie = przymiarka na postaci obok (bez kupowania i bez zakładania)
				gc.mouse_entered.connect(func(): try_set(slot, iid))
				gc.mouse_exited.connect(func():
					if not gc.get_global_rect().has_point(gc.get_global_mouse_position()):
						try_clear(iid))
			var gh := K.hbox(10)
			gc.add_child(gh)
			var gi := K.icon(String(gd.icon), 44, K.C_TXT)
			gi.modulate.a = 0.45 if (glocked and not have) else 1.0
			gh.add_child(gi)
			var gv := K.vbox(1)
			gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gh.add_child(gv)
			gv.add_child(K.rich("[b]%s[/b]%s" % [String(gd.name), K.col("   na sobie", T.C_HI) if worn else (K.col("   w plecaku", K.C_DIM) if have else "")], 14))
			var gdl := K.wrap(String(gd.desc), 11, T.C_LOW)
			gdl.max_lines_visible = 2
			gv.add_child(gdl)
			gh.add_child(_marks(G.stat_marks(gd.get("stats", {})), true))
			var gb: Button
			if worn:
				gb = T._mini("Zdejmij", func(): G.gear_off(slot); render())
				gb.disabled = not can_change
			elif have:
				gb = T._mini("Załóż", func(): G.gear_wear(iid); render(), "strong")
				gb.disabled = not can_change
			else:
				gb = T._mini(("od poz. %d" % int(gd.lvl)) if glocked else ("Kup — %s" % G.money(gd.price)), func(): G.gear_buy(iid); render(), "strong")
				gb.disabled = glocked or S.cash < float(gd.price)
			gb.custom_minimum_size = Vector2(96, 26)
			gb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			gh.add_child(gb)
	if wear_offer.is_empty():
		list.add_child(K.wrap("Nie masz jeszcze ubrań na zmianę.", 12, T.C_LOW))
	hint.text = "najedź na rzecz, żeby ją przymierzyć  •  cechy na czerwono szkodzą  •  lepsze rzeczy odblokowują kolejne poziomy"


## znaczniki cech: wartość z ikoną, jedna pod drugą (zielone pomagają, czerwone szkodzą)
func _marks(marks: Array, tall: bool) -> Control:
	var fx: BoxContainer = K.vbox(-1) if tall else K.hbox(8)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.alignment = BoxContainer.ALIGNMENT_CENTER
	if tall:
		fx.custom_minimum_size = Vector2(62, 0)
	for mk in marks:
		var mc: Color = T.C_MID if mk.good else T.C_ALERT
		var mr := K.hbox(3)
		mr.alignment = BoxContainer.ALIGNMENT_END
		mr.tooltip_text = String(mk.tip)
		mr.add_child(K.lbl(String(mk.text), 12, mc))
		mr.add_child(K.icon(String(mk.icon), 14, mc))
		fx.add_child(mr)
	return fx


func _note(parent: Node, ic: String, color: Color, title: String, text: String, right := "") -> void:
	var warn: bool = color == K.C_WARN or color == K.C_BAD
	var p := K.panel(T._flat(0.03, 0.0, 10, 7, 7))
	parent.add_child(p)
	var h := K.hbox(10)
	p.add_child(h)
	var icn := K.icon(ic, 18, T.C_ALERT if warn else T.C_MID)
	icn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icn)
	var v := K.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(K.lbl(title, 14, T.C_HI))
	var tl := K.wrap(text, 11, T.C_LOW)
	tl.max_lines_visible = 2
	v.add_child(tl)
	h.add_child(v)
	if right != "":
		h.add_child(K.head(right, 16, T.C_ALERT if warn else T.C_HI))


func _tab_org() -> void:
	var S: Dictionary = G.S
	var row := K.hbox(12)
	content.add_child(row)
	var colw := (W_SIDE * 2.0 + W_MID) / 3.0
	# --- spotkania
	var a := _frame(colw, H_BODY)
	row.add_child(a)
	var av := K.vbox(7)
	a.add_child(av)
	_title(av, "calendar", "SPOTKANIA")
	var meets := []
	for o in S.orders:
		if o.status == "accepted" or o.status == "new":
			meets.append(o)
	meets.sort_custom(func(x, y): return float(x.meet) < float(y.meet))
	if meets.is_empty():
		av.add_child(K.wrap("Nic umówionego. Klienci piszą sami — zaglądaj do Wiadomości.", 13, K.C_DIM))
	for o in meets:
		var cd := G.cust_def(o.cust)
		var ok: bool = o.status == "accepted"
		var left := int(float(o.meet) - S.t)
		var when := "za %d min" % left if left > 0 else "TERAZ"
		var price := (" • %s/g" % G.money(o.agreed)) if o.get("agreed") != null else ""
		_note(av, "handshake" if ok else "message_circle", K.C_ACC if ok else K.C_WARN, "%s — %d g %s" % [cd.name, int(o.grams), D.PRODUCT_GEN[o.product]],
			"%s%s • %s" % [G.spot_def(o.spot).get("name", "?"), price, ("umówione, " + when) if ok else "czeka na odpowiedź"], G.clock(o.meet) if ok else "?")
	# --- zeszyt
	var b := _frame(colw, H_BODY)
	row.add_child(b)
	var bv := K.vbox(7)
	b.add_child(bv)
	_title(bv, "notebook_pen", "ZESZYT")
	if G.job_active():
		var jdone: bool = G.S.job.get("done", false)
		var jdef: Dictionary = G.job_def(String(G.S.job.kind))
		_note(bv, "target", K.C_ACC if jdone else K.C_GOLD, "Zlecenie dnia", G.job_text() + (" Zrobione." if jdone else " Premia: %s do wkładu." % G.money(G.job_reward())),
			"✓" if jdone else "%s / %s" % [G._job_amount(jdef, G.job_progress()), G._job_amount(jdef, float(G.S.job.need))])
	var nxo: Dictionary = G.rank_next()
	if not nxo.is_empty():
		var txt := "Do awansu na %s brakuje %s. Nagroda: %s" % [String(nxo.name), G.money(maxf(0.0, float(nxo.at) - S.paid)), String(nxo.desc)]
		var dl := int(nxo.day) - G.day()
		if int(nxo.bonus) > 0 and dl >= 0:
			txt += " Premia za tempo %s — %s." % [G.money(nxo.bonus), "za %d dni" % dl if dl > 0 else "DZIŚ"]
		_note(bv, "users", K.C_ACC, "Ekipa Wiktora: " + String(G.rank_def().name), txt, G.money(S.paid))
	else:
		_note(bv, "circle_check", K.C_ACC, "Ekipa Wiktora", "Jesteś wspólnikiem.", G.money(S.paid))
	if float(S.credit) > 0.0:
		_note(bv, "truck", K.C_WARN, "Towar na zeszyt u Wiktora", "Oddaj do końca dnia %d. Limit: %s." % [int(float(S.credit_due) / 1440.0) + 1, G.money(G.credit_limit())], G.money(S.credit))
	else:
		_note(bv, "truck", K.C_DIM, "Towar na zeszyt u Wiktora", "Nic nie wisisz. Limit: %s." % G.money(G.credit_limit()), "0 zł")
	_note(bv, "house", K.C_DIM, "Koszty życia", "Czynsz i jedzenie schodzą co noc.", G.money(D.LIVING_COST))
	bv.add_child(K.gap(2))
	_title(bv, "package", "PACZKI")
	if S.drops.is_empty():
		bv.add_child(K.wrap("Żadnej paczki w drodze. Zamów towar: telefon → Wiadomości → Wiktor.", 13, K.C_DIM))
	for d in S.drops:
		var spot := "?"
		for ds in D.DROPS:
			if ds.id == d.spot:
				spot = ds.name
		var rdy: bool = d.state == "ready" or float(d.ready) <= S.t
		_note(bv, "package_open" if rdy else "timer", K.C_ACC if rdy else K.C_BLUE, G.Market.contents(d),
			"%s • %s" % [spot, "czeka na odbiór" if rdy else "będzie o %s" % G.clock(d.ready)], "na zeszyt" if d.credit else G.money(d.cost))
	# --- notatki o klientach
	var c := _frame(colw, H_BODY)
	row.add_child(c)
	var cv := K.vbox(7)
	c.add_child(cv)
	_title(cv, "contact", "NOTATKI O KLIENTACH")
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(sc)
	var list := K.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var anyc := false
	for cdef in D.CLIENTS:
		var cs: Dictionary = S.cust[cdef.id]
		if not cs.unlocked:
			continue
		anyc = true
		var known: Dictionary = cs.get("known", {})
		var bits := []
		if known.has("like"):
			bits.append("lubi ton: " + String(D.STYLE_NAMES.get(known.like, known.like)).to_lower())
		if known.has("hate"):
			bits.append("nie znosi: " + String(D.STYLE_NAMES.get(known.hate, known.hate)).to_lower())
		if known.has("max"):
			bits.append("płaci do ok. %s/g" % G.money(known.max))
		if bits.is_empty():
			bits.append("jeszcze go nie rozgryzłeś")
		_note(list, "user", K.C_BLUE, "%s  •  %d transakcji" % [cdef.name, int(cs.get("deals", 0))], ", ".join(bits))
	if not anyc:
		list.add_child(K.wrap("Nie masz jeszcze żadnego klienta.", 13, K.C_DIM))
	hint.text = "Organizer zbiera to, co łatwo przegapić: godziny spotkań, zeszyt, awanse i paczki do odbioru"


## ziemia: przerywana ramka, na którą upuszcza się to, co chcesz zostawić (będzie leżeć u Twoich stóp)
class _DropBox:
	extends Control
	const KK = preload("res://scripts/uikit.gd")

	func _ready() -> void:
		tooltip_text = "Rzecz zostanie u Twoich stóp — możesz ją potem podnieść."
		var v := KK.vbox(4)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		var ic := KK.icon("package_open", 26, Color(1, 1, 1, 0.3))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var t := KK.lbl("upuść tutaj, żeby zostawić", 12, Color(1, 1, 1, 0.36))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)

	func _draw() -> void:
		var col := Color(1, 1, 1, 0.16)
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		for seg in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
			draw_dashed_line(seg[0], seg[1], col, 1.0, 8.0)
