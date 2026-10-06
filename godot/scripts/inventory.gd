extends Control
## Ekran ekwipunku: zawartość plecaka z rozmiarem i wagą każdej rzeczy, podgląd postaci
## ze slotami, skrytka albo kosz po prawej. Przeciągnij i upuść albo kliknij i przenieś.

const K = preload("res://scripts/uikit.gd")
const Chars = preload("res://scripts/chars.gd")

const W_SIDE := 404.0
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
var bag_mesh: MeshInstance3D
var rig_outfit := ""          # strój pokazany na podglądzie postaci
var wear_sel := ""            # strój oglądany w zakładce „Ubrania”
var spin := 0.0
var spin_drag := false
var ask := {}                # otwarte okno wyboru ilości: {e, from, to, max, step, v}
var ask_box: Control = null
var ask_big: Label
var ask_sub: Label
var ask_slider: HSlider
var ask_edit: LineEdit
var ask_go: Button


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
	var top := K.hbox(6)
	top.custom_minimum_size = Vector2(W_SIDE * 2.0 + W_MID + 24.0, 40)
	v.add_child(top)
	tabs_box = K.hbox(4)
	top.add_child(tabs_box)
	top.add_child(K.spacer())
	var cash_box := K.hbox(6)
	cash_box.add_child(K.icon("banknote", 18, K.C_ACC))
	l_cash = K.head("0 zł", 22, K.C_ACC)
	cash_box.add_child(l_cash)
	top.add_child(cash_box)
	top.add_child(K.gap(0))
	var sep := K.lbl("  ", 12)
	top.add_child(sep)
	top.add_child(K.icon("clock", 15, K.C_DIM))
	l_clock = K.head("09:00", 17, K.C_TXT)
	top.add_child(l_clock)
	top.add_child(K.lbl("   ", 12))
	top.add_child(K.btn("Zamknij  [Esc]", func(): ui.close_all(), "", true))
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	content = Control.new()
	content.custom_minimum_size = Vector2(W_SIDE * 2.0 + W_MID + 24.0, H_BODY)
	v.add_child(content)
	hint = K.lbl("", 12, K.C_DIM)
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
	look["face"] = String(D.PLAYER_LOOK.model)
	look["mask"] = bool(od.get("mask", false))
	look["tall"] = 1.0
	look["build"] = 1.0
	rig = Chars.make(look)
	pivot.add_child(rig.root)
	rig.anim.process_mode = Node.PROCESS_MODE_ALWAYS
	Chars.animate(rig, 0.0, 0.0, "")
	# plecak na plecach (widoczny po zakupie)
	bag_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.4, 0.16)
	bag_mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.2, 0.17)
	mat.roughness = 0.9
	bag_mesh.material_override = mat
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
			bm.size = Vector3(0.4, 0.16, 0.3)
			bag_mesh.position = Vector3(0.04, -0.18, 0)
		else:
			bag_mesh.position = Vector3(0, 0.02, -0.17)
	else:
		rig.root.add_child(bag_mesh)
		bag_mesh.position = Vector3(0, 1.2, -0.2)
	_bag_refresh()


## ubrania z pól ekwipunku na postaci w podglądzie (przebudowa tylko wtedy, gdy coś się zmieniło)
var _dress_sig := ""

func _dress(force := false) -> void:
	if rig.is_empty() or G.S == null:
		return
	var gear: Dictionary = G.S.get("gear", {})
	var sig := rig_outfit + "|" + JSON.stringify(gear)
	if sig == _dress_sig and not force:
		return
	_dress_sig = sig
	Chars.dress(rig, gear)


func _bag_refresh() -> void:
	_dress(true)
	bag_mesh.visible = G.S != null and G.S.has("upg") and G.upg("plecak1")
	var big: bool = G.S != null and G.S.has("upg") and G.upg("plecak2")
	var bmesh := bag_mesh.mesh as BoxMesh
	if bmesh.size.x > 0.39:
		bmesh.size = Vector3(0.5, 0.2, 0.34) if big else Vector3(0.4, 0.16, 0.3)
	else:
		bmesh.size = Vector3(0.34, 0.5, 0.2) if big else Vector3(0.3, 0.4, 0.16)


func _char_view(w: float, h: float) -> Control:
	if vpc != null and is_instance_valid(vpc):
		vpc.queue_free()
	var holder := Control.new()
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
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		spin_drag = ev.pressed
	elif ev is InputEventMouseMotion and spin_drag:
		spin += ev.relative.x * 0.012


func _process(dt: float) -> void:
	if not visible:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		spin_drag = false
	if not spin_drag:
		spin = lerpf(spin, sin(Time.get_ticks_msec() * 0.0005) * 0.35, minf(1.0, dt * 1.2))
	pivot.rotation.y = spin


# ---------------------------------------------------------------- otwieranie
func open(room_id := "", start_tab := "inv") -> void:
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


func close() -> void:
	ask_close()
	visible = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func has_stash() -> bool:
	return room != "" and G.S.stash.has(room) and G.stash_cap(room) > 0


func render() -> void:
	var S: Dictionary = G.S
	_dress()
	l_cash.text = G.money(S.cash)
	l_clock.text = "%s  •  dzień %d" % [G.clock(), G.day()]
	K.clear(tabs_box)
	for t in TABS:
		var id: String = t[0]
		var on := id == tab
		var b := Button.new()
		b.text = "  " + String(t[1])
		b.icon = K.tex(t[2])
		b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_constant_override("h_separation", 2)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", load("res://assets/fonts/barlowc.ttf"))
		b.add_theme_font_size_override("font_size", 19)
		var st := K.sb(Color(0.16, 0.6, 0.33, 0.22) if on else Color(1, 1, 1, 0.03), 8, K.C_ACC if on else Color(1, 1, 1, 0.08), 1, 14)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", K.sb(Color(0.16, 0.6, 0.33, 0.3) if on else Color(1, 1, 1, 0.08), 8, K.C_ACC if on else Color(1, 1, 1, 0.16), 1, 14))
		b.add_theme_stylebox_override("pressed", st)
		b.add_theme_color_override("font_color", Color.WHITE if on else K.C_DIM)
		for cn in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			b.add_theme_color_override(cn, K.C_ACC if on else K.C_DIM)
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
	var p := K.panel(K.sb(Color(0.05, 0.062, 0.088, 0.96), 12, Color(1, 1, 1, 0.09), 1, pad))
	p.custom_minimum_size = Vector2(w, h)
	return p


func _title(parent: Node, ic: String, text: String, right := "", rcol := K.C_TXT) -> void:
	var h := K.hbox(8)
	h.add_child(K.icon(ic, 18, K.C_ACC))
	h.add_child(K.head(text, 19, K.C_TXT))
	h.add_child(K.spacer())
	if right != "":
		h.add_child(K.head(right, 19, rcol))
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
	_title(lv, "backpack", G.bag_name().to_upper(), "%s / %d" % [G.units(used), int(cap)], K.C_BAD if used > cap - 0.5 else K.C_TXT)
	_list(lv, S.inv, "bag", "Pusto. Towar zamówisz u Wiktora (telefon → Giełda).")
	lv.add_child(_cap_bar(used, cap, K.C_BLUE))
	lv.add_child(_foot("Waga: %s" % G.weight_text(G.store_weight(S.inv)), "Przy zatrzymaniu tracisz wszystko, co masz przy sobie."))
	left.set_drag_forwarding(Callable(), _can_drop.bind("bag"), _drop.bind("bag"))
	# --- środek: postać i szczegóły
	var mid := K.vbox(8)
	mid.custom_minimum_size = Vector2(W_MID, H_BODY)
	row.add_child(mid)
	var view := _char_view(W_MID, 318.0)
	mid.add_child(view)
	_gear_slots(view, W_MID, 318.0)
	mid.add_child(_detail())
	# --- prawa strona: skrytka albo kosz
	if has_stash():
		var st: Dictionary = S.stash[room]
		var scap := float(G.stash_cap(room))
		var sused := G.store_total(st)
		var right := _frame(W_SIDE, H_BODY)
		row.add_child(right)
		var rv := K.vbox(8)
		right.add_child(rv)
		_title(rv, "warehouse", "SKRYTKA — " + String(D.ROOMS[room].name).to_upper(), "%s / %d" % [G.units(sused), int(scap)])
		_list(rv, st, "stash", "Skrytka jest pusta. Przeciągnij tu rzeczy z plecaka.")
		rv.add_child(_cap_bar(sused, scap, K.C_GOLD))
		right.set_drag_forwarding(Callable(), _can_drop.bind("stash"), _drop.bind("stash"))
		hint.text = "Przeciągnij rzecz na drugą stronę i wybierz ilość   •   ubranie przeciągnij na pole przy postaci"
	else:
		var right2 := K.vbox(10)
		right2.custom_minimum_size = Vector2(W_SIDE, H_BODY)
		row.add_child(right2)
		var bin := _DropBox.new()
		bin.custom_minimum_size = Vector2(W_SIDE, 250)
		bin.set_drag_forwarding(Callable(), _can_drop.bind("bin"), _drop.bind("bin"))
		right2.add_child(bin)
		var info := _frame(W_SIDE, 0)
		info.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right2.add_child(info)
		var iv := K.vbox(8)
		info.add_child(iv)
		_title(iv, "info", "JAK TO DZIAŁA")
		iv.add_child(K.rich("• Każda rzecz zajmuje [b]miejsce[/b] — porcja i gram luzem po 1, woreczki prawie nic, telefon na kartę aż 2.\n• Rzeczy tego samego rodzaju [b]układają się w stos[/b].\n• W kryjówce podejdź do [b]skrytki[/b] — otworzy się po prawej i przeciągniesz do niej towar oraz gotówkę.\n• Podczas pościgu przytrzymaj [b][X][/b], żeby wyrzucić cały towar. Przepada, ale przy kontroli jesteś czysty.", 13))
		iv.add_child(K.spacer())
		var nb := _nearest_stash()
		if nb != "":
			iv.add_child(K.rich(K.col("Najbliższa skrytka: ", K.C_DIM) + "[b]%s[/b]" % nb, 13))
		hint.text = "Ubranie przeciągnij na pole przy postaci (albo kliknij dwa razy)   •   do kosza — wyrzucasz   •   kliknięcie — opis"


func _nearest_stash() -> String:
	var names := []
	for r in G.S.stash:
		if G.stash_cap(r) > 0 and (r == "safe" or G.room_owned(r)):
			names.append(String(D.ROOMS[r].name))
	return ", ".join(names)


func _cap_bar(used: float, cap: float, color: Color) -> Control:
	var full := used > cap - 0.5 and cap > 0.0
	var b := K.bar(used, maxf(1.0, cap), K.C_BAD if full else color, 6.0)
	return b


func _foot(left: String, right: String) -> Control:
	var h := K.hbox(8)
	h.add_child(K.lbl(left, 12, K.C_TXT))
	h.add_child(K.spacer())
	h.add_child(K.lbl(right, 11, K.C_DIM))
	return h


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
	var p := K.panel(K.sb(Color(0.05, 0.062, 0.088, 0.9), 9, Color(1, 1, 1, 0.1), 1, 8))
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
	h.add_child(K.icon(ic, 13, K.C_ACC))
	h.add_child(K.lbl(cap, 9, K.C_DIM))
	v.add_child(h)
	v.add_child(K.head(val, 15, K.C_TXT))
	v.add_child(K.lbl(sub, 10, K.C_DIM))


# ---------------------------------------------------------------- lista pozycji
func _list(parent: Node, st: Dictionary, side: String, empty: String) -> void:
	var hd := K.hbox(0)
	var c1 := K.lbl("PRZEDMIOT", 10, K.C_DIM)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(c1)
	for e in [["ILOŚĆ", 68.0], ["MIEJSCE", 46.0], ["WAGA", 52.0]]:
		var l := K.lbl(e[0], 10, K.C_DIM)
		l.custom_minimum_size = Vector2(e[1], 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hd.add_child(l)
	hd.add_child(K.gap(0))
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 8)
	hm.add_theme_constant_override("margin_right", 12)
	hm.add_child(hd)
	parent.add_child(hm)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.set_drag_forwarding(Callable(), _can_drop.bind(side), _drop.bind(side))
	parent.add_child(sc)
	var rows := K.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.set_drag_forwarding(Callable(), _can_drop.bind(side), _drop.bind(side))
	rows.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(rows)
	var list := G.entries(st)
	if list.is_empty():
		var l2 := K.wrap(empty, 13, K.C_DIM)
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
	return not sel.is_empty() and sel.side == side and sel.kind == e.kind and sel.p == e.p and int(sel.pur) == int(e.pur) and sel.id == e.id


func _ecolor(e: Dictionary) -> Color:
	if int(e.tier) >= 0:
		return Color("#" + String(D.TIER_COLOR[int(e.tier)]))
	return Color(0.62, 0.66, 0.74)


func _row(e: Dictionary, side: String) -> Control:
	var on := _is_sel(e, side)
	var col := _ecolor(e)
	var p := K.panel(K.sb(Color(0.13, 0.17, 0.24) if on else Color(0.085, 0.102, 0.15), 9, K.C_ACC if on else Color(1, 1, 1, 0.06), 1, 8))
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.mouse_entered.connect(func():
		if not _is_sel(e, side):
			p.add_theme_stylebox_override("panel", K.sb(Color(0.11, 0.135, 0.2), 9, Color(1, 1, 1, 0.16), 1, 8)))
	p.mouse_exited.connect(func():
		if not _is_sel(e, side):
			p.add_theme_stylebox_override("panel", K.sb(Color(0.085, 0.102, 0.15), 9, Color(1, 1, 1, 0.06), 1, 8)))
	var h := K.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ib := K.panel(K.sb(Color(col.r, col.g, col.b, 0.16), 8, Color(col.r, col.g, col.b, 0.55), 1, 0))
	ib.custom_minimum_size = Vector2(36, 36)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := K.icon(e.icon, 40 if K.is_item(e.icon) else 20, col)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ib.add_child(ic)
	h.add_child(ib)
	var nv := K.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := K.lbl(e.name, 14 if String(e.name).length() <= 16 else 13, K.C_TXT)
	nl.clip_text = true
	nv.add_child(nl)
	var sub := String(e.sub)
	if int(e.tier) >= 0:
		sub = "%s %d%%%s  •  %s" % [D.TIER_NAMES[int(e.tier)], int(e.pur), " (mieszanka)" if (String(e.kind) != "item" and G.is_mix(e.pur)) else "", e.sub]
	elif sub == "":
		sub = "przedmiot"
	nv.add_child(K.lbl(sub, 11, col if int(e.tier) >= 0 else K.C_DIM))
	h.add_child(nv)
	for cell in [[e.qty, 68.0, K.C_TXT, 16], [G.units(e.size), 46.0, K.C_DIM, 14], [G.weight_text(e.weight), 52.0, K.C_DIM, 14]]:
		var l := K.head(String(cell[0]), int(cell[3]), cell[2])
		l.custom_minimum_size = Vector2(cell[1], 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
	p.gui_input.connect(_row_input.bind(e, side))
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
	sel = {"side": side, "kind": e.kind, "p": e.p, "pur": int(e.pur), "id": e.id}
	render()


# ---------------------------------------------------------------- przenoszenie: przeciągnij i wybierz ilość
func _drag(_at: Vector2, e: Dictionary, side: String) -> Variant:
	var col := _ecolor(e)
	var pv := K.panel(K.sb(Color(0.09, 0.11, 0.16, 0.95), 9, K.C_ACC, 1, 8))
	var h := K.hbox(8)
	pv.add_child(h)
	h.add_child(K.icon(e.icon, 40 if K.is_item(e.icon) else 20, col))
	h.add_child(K.lbl("%s  •  %s" % [e.name, e.qty], 14, K.C_TXT))
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
		var p := K.panel(K.sb(Color(0.07, 0.1, 0.13, 0.94) if id != "" else Color(0.04, 0.05, 0.07, 0.88), 8, K.C_ACC if on else (Color(0.3, 0.9, 0.55, 0.45) if id != "" else Color(1, 1, 1, 0.14)), 1, 6))
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
		vb.add_child(K.lbl(String(e[1]).to_upper(), 9, K.C_ACC if id != "" else K.C_DIM))
		var marks_fx: Array = G.stat_marks(D.ITEMS[id].get("stats", {})) if id != "" else []
		var nl := K.wrap(String(D.ITEMS[id].name) if id != "" else "puste", 11, K.C_TXT if id != "" else Color(1, 1, 1, 0.35), sw - (48.0 + (44.0 if not marks_fx.is_empty() else 0.0) if id != "" else 16.0))
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
				var mc: Color = K.C_ACC if mk.good else K.C_BAD
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
			lines.draw_line(m[0], m[1], Color(1, 1, 1, 0.22), 1.0, true)
			lines.draw_rect(Rect2(m[1] - Vector2(2, 2), Vector2(4, 4)), Color(0.3, 0.9, 0.55, 0.8)))
	# plecak: decyduje o tym, ile się zmieści (kupujesz u Stasia)
	var bp := K.panel(K.sb(Color(0.05, 0.062, 0.088, 0.9), 8, Color(1, 1, 1, 0.1), 1, 6))
	bp.custom_minimum_size = Vector2(sw, sh)
	bp.size = Vector2(sw, sh)
	bp.position = Vector2(w - sw, h - sh)
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(bp)
	var bh := K.hbox(6)
	bp.add_child(bh)
	bh.add_child(K.icon("backpack", 18, K.C_BLUE))
	var bv := K.vbox(0)
	bv.add_child(K.lbl("PLECAK • %d MIEJSC" % int(G.capacity()), 9, K.C_DIM))
	var bl := K.lbl(G.bag_name(), 11, K.C_TXT)
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
	var pv := K.panel(K.sb(Color(0.09, 0.11, 0.16, 0.95), 9, K.C_ACC, 1, 8))
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
	var step: float = e.get("step", 1.0)
	var limit: float = float(e.n) if to == "bin" else G.move_limit(room, e, to == "stash")
	if limit < step - 0.001:
		G.notify("Brak miejsca w %s." % ("skrytce" if to == "stash" else "plecaku"), "warn")
		Sfx.play("error")
		return
	if float(e.n) <= step + 0.001:
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
	var col := _ecolor(e)
	var bin := to == "bin"
	var edge := K.C_BAD if bin else K.C_ACC
	var p := K.panel(K.sb(Color(0.055, 0.068, 0.096, 0.99), 16, Color(edge.r, edge.g, edge.b, 0.7), 1, 22))
	p.custom_minimum_size = Vector2(520, 0)
	cc.add_child(p)
	var v := K.vbox(10)
	p.add_child(v)
	# co i dokąd
	var hd := K.hbox(10)
	var ib := K.panel(K.sb(Color(col.r, col.g, col.b, 0.16), 9, Color(col.r, col.g, col.b, 0.55), 1, 0))
	ib.custom_minimum_size = Vector2(42, 42)
	var ic := K.icon(e.icon, 40 if K.is_item(e.icon) else 24, col)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ib.add_child(ic)
	hd.add_child(ib)
	var hv := K.vbox(-2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(K.head(e.name, 22, K.C_TXT))
	var sub := String(e.sub)
	if int(e.tier) >= 0:
		sub = "%s %d%%  •  %s" % [D.TIER_NAMES[int(e.tier)], int(e.pur), e.sub]
	hv.add_child(K.lbl(sub if sub != "" else "przedmiot", 12, col if int(e.tier) >= 0 else K.C_DIM))
	hd.add_child(hv)
	var route := K.hbox(6)
	route.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var names := {"bag": G.bag_name(), "stash": "Skrytka", "bin": "Kosz"}
	route.add_child(K.lbl(String(names[from]), 12, K.C_DIM))
	route.add_child(K.icon("chevron_right", 14, edge))
	route.add_child(K.lbl(String(names[to]), 13, edge))
	hd.add_child(route)
	v.add_child(hd)
	# wybrana ilość, a pod nią waga i miejsce
	ask_big = K.head("", 46, Color.WHITE)
	ask_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ask_big)
	ask_sub = K.lbl("", 14, K.C_DIM)
	ask_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ask_sub)
	# suwak z przyciskami − / + i polem do wpisania liczby
	var row := K.hbox(8)
	v.add_child(row)
	var minus := K.btn("−", func(): _ask_set(float(ask.v) - step), "", true)
	minus.custom_minimum_size = Vector2(36, 34)
	row.add_child(minus)
	ask_slider = HSlider.new()
	ask_slider.min_value = step
	ask_slider.max_value = limit
	ask_slider.step = step
	ask_slider.value = limit
	ask_slider.focus_mode = Control.FOCUS_NONE
	ask_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ask_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ask_slider.custom_minimum_size = Vector2(0, 26)
	ask_slider.value_changed.connect(func(val): _ask_set(val, false))
	row.add_child(ask_slider)
	var plus := K.btn("+", func(): _ask_set(float(ask.v) + step), "", true)
	plus.custom_minimum_size = Vector2(36, 34)
	row.add_child(plus)
	ask_edit = LineEdit.new()
	ask_edit.custom_minimum_size = Vector2(84, 34)
	ask_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask_edit.max_length = 6
	ask_edit.select_all_on_focus = true
	ask_edit.tooltip_text = "Wpisz ilość"
	ask_edit.add_theme_stylebox_override("normal", K.sb(Color(0.03, 0.04, 0.06), 8, Color(1, 1, 1, 0.18), 1, 8))
	ask_edit.add_theme_stylebox_override("focus", K.sb(Color(0.03, 0.04, 0.06), 8, K.C_ACC, 1, 8))
	ask_edit.text_changed.connect(_ask_typed)
	ask_edit.text_submitted.connect(func(_t): ask_ok())
	row.add_child(ask_edit)
	var mm := K.hbox(0)
	mm.add_child(K.lbl(_fmt_amount(e, step), 11, K.C_DIM))
	mm.add_child(K.spacer())
	var cap_note := "wszystko" if limit >= float(e.n) - 0.001 else "tyle się zmieści"
	mm.add_child(K.lbl("%s  (%s)" % [_fmt_amount(e, limit), cap_note], 11, K.C_DIM if limit >= float(e.n) - 0.001 else K.C_WARN))
	v.add_child(mm)
	v.add_child(K.lbl("Przesuń suwak albo wpisz liczbę.  Enter — zatwierdź,  Esc — anuluj.", 11, Color(1, 1, 1, 0.35)))
	var bh := K.hbox(8)
	v.add_child(bh)
	var bc := K.btn("Anuluj", ask_close)
	bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bc)
	ask_go = K.btn("", ask_ok, "bad" if bin else "go")
	ask_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(ask_go)
	_ask_set(limit)
	Sfx.play("open")
	p.pivot_offset = Vector2(260, 120)
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
	ask_sub.text = "waga %s   •   miejsce %s" % [G.weight_text(v2 * float(e.uw)), G.units(v2 * float(e.usize))]
	var verb := "Wyrzuć" if ask.to == "bin" else "Przenieś"
	ask_go.text = "%s %s" % [verb, _fmt_amount(e, v2)]
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


## Karta pod postacią: bez przycisków przenoszenia. Pokazuje opis klikniętej rzeczy
## albo podsumowanie tego, co gracz ma przy sobie.
func _detail() -> Control:
	var p := _frame(W_MID, 0, 12)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := K.vbox(5)
	p.add_child(v)
	var S: Dictionary = G.S
	var e := _find_sel()
	if e.is_empty():
		v.add_child(K.lbl("CO MASZ PRZY SOBIE", 10, K.C_DIM))
		var goods := G.carry_goods()
		_stat(v, "banknote", "Wartość towaru na ulicy", "ok. " + G.money(G.carry_value()), K.C_ACC if goods > 0.0 else K.C_DIM)
		_stat(v, "package", "Porcje gotowe do sprzedaży", str(G.packed_total(S.inv)))
		_stat(v, "weight", "Waga ładunku", G.weight_text(G.store_weight(S.inv)))
		_stat(v, "shield_alert", "Przy kontroli stracisz", G.grams(goods) if goods > 0.0 else "nic", K.C_WARN if goods > 0.0 else K.C_ACC)
		v.add_child(K.spacer())
		v.add_child(K.wrap("Przeciągnij rzecz na drugą stronę — pojawi się suwak z wyborem ilości. Kliknięcie pokazuje opis.", 11, K.C_DIM))
		return p
	var col := _ecolor(e)
	var h := K.hbox(8)
	h.add_child(K.icon(e.icon, 40 if K.is_item(e.icon) else 22, col))
	var nm := K.head(e.name, 20, K.C_TXT)
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	v.add_child(h)
	if int(e.tier) >= 0:
		v.add_child(K.rich("%s  •  %s" % [K.tier_bb(e.pur), e.sub], 12))
	v.add_child(K.wrap(e.desc, 12, K.C_DIM))
	# ubranie: co daje i gdzie się je nosi
	if e.kind == "item" and G.is_gear(String(e.id)):
		var parts: Array = []
		for t in G.stat_traits(D.ITEMS[String(e.id)].get("stats", {})):
			parts.append(K.col(String(t.text), K.C_ACC if t.good else K.C_WARN))
		v.add_child(K.rich("   ".join(parts) if not parts.is_empty() else K.col("bez zalet i wad", K.C_DIM), 12))
	_stat(v, "layers", "Ilość", String(e.qty))
	_stat(v, "box", "Miejsce / waga", "%s  /  %s" % [G.units(e.size), G.weight_text(e.weight)])
	if e.kind != "item" and e.kind != "cash":
		_stat(v, "banknote", "Na ulicy", "ok. %s/g" % G.money(G.market_price(e.p, e.pur)), K.C_ACC)
	v.add_child(K.spacer())
	if sel.side == "bag" and e.kind == "item" and e.id == "burner":
		v.add_child(K.btn("Użyj — zmień numer", func(): G.use_burner(); render(), "go", true))
	elif String(sel.side) == "gear":
		v.add_child(K.wrap("Założone ubranie nic nie waży. Dwuklik na polu albo przeciągnięcie do plecaka je zdejmuje.", 11, K.C_DIM))
	elif sel.side == "bag" and e.kind == "item" and G.is_gear(String(e.id)):
		var gid2 := String(e.id)
		v.add_child(K.btn("Załóż", func(): G.gear_wear(gid2); sel = {}; render(), "go", true))
	else:
		v.add_child(K.wrap("Przeciągnij na skrytkę%s, żeby wybrać ilość." % ("" if has_stash() else " (w kryjówce)") if sel.side == "bag" else "Przeciągnij do plecaka, żeby wybrać ilość.", 11, K.C_DIM))
	return p


# ---------------------------------------------------------------- zakładka: postać
func _stat(parent: Node, ic: String, name: String, val: String, color := K.C_TXT) -> void:
	var h := K.hbox(8)
	h.add_child(K.icon(ic, 15, K.C_DIM))
	h.add_child(K.lbl(name, 13, K.C_DIM))
	h.add_child(K.spacer())
	h.add_child(K.head(val, 16, color))
	parent.add_child(h)


func _tab_char() -> void:
	var S: Dictionary = G.S
	var row := K.hbox(12)
	content.add_child(row)
	var left := K.vbox(8)
	left.custom_minimum_size = Vector2(W_MID + 60.0, H_BODY)
	row.add_child(left)
	var view := _char_view(W_MID + 60.0, 430.0)
	left.add_child(view)
	var idc := _frame(W_MID + 60.0, 0, 12)
	idc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(idc)
	var iv := K.vbox(4)
	idc.add_child(iv)
	var lvl := int(S.lvl)
	iv.add_child(K.head("KUBA", 26, K.C_TXT))
	iv.add_child(K.lbl("poz. %d  •  %s" % [lvl, D.LEVEL_TITLES[mini(lvl - 1, D.LEVEL_TITLES.size() - 1)]], 13, K.C_GOLD))
	var lo := float(D.XP_LEVELS[mini(lvl - 1, D.XP_LEVELS.size() - 1)])
	var hi := float(D.XP_LEVELS[mini(lvl, D.XP_LEVELS.size() - 1)])
	iv.add_child(K.bar(float(S.xp) - lo, maxf(1.0, hi - lo), K.C_GOLD, 6.0))
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
	mv.add_child(K.gap(4))
	_title(mv, "siren", "POLICJA")
	_stat(mv, "flame", "Gorąco", "%d%%" % int(S.heat), K.C_BAD if float(S.heat) > 60.0 else K.C_TXT)
	_stat(mv, "search", "Śledztwo", "%d%%" % int(S.invest), K.C_BAD if float(S.invest) > 60.0 else K.C_TXT)
	_stat(mv, "shield_alert", "Zatrzymania", "%d / %d" % [int(S.strikes), D.MAX_STRIKES], K.C_WARN if int(S.strikes) > 0 else K.C_TXT)
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
	var anyu := false
	for u in D.UPGRADES:
		if G.upg(u.id):
			anyu = true
			rv.add_child(K.rich("[b]%s[/b]\n%s" % [u.name, K.col(u.desc, K.C_DIM)], 12))
	if not anyu:
		rv.add_child(K.wrap("Nic. Plecak, lepszą wagę i skrytkę w podłodze kupisz w Sklepie u Stasia.", 13, K.C_DIM))
	rv.add_child(K.spacer())
	rv.add_child(K.btn("Otwórz drzewko umiejętności", func(): ui.open_phone("rozwoj"), "", true))
	hint.text = "Przeciągnij postać myszą, żeby ją obrócić"


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
	iv.add_child(K.lbl("MASZ NA SOBIE", 10, K.C_DIM))
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
	# prawa strona: wieszak
	var right := _frame(W_SIDE * 2.0 - 48.0, H_BODY)
	row.add_child(right)
	var rv := K.vbox(8)
	right.add_child(rv)
	_title(rv, "store", "TANIA ODZIEŻ — WIESZAK" if in_shop else "UBRANIA", G.money(S.cash) if in_shop else "", K.C_ACC)
	if not in_shop:
		rv.add_child(K.wrap("Ubrania kupisz w „Taniej Odzieży” przy Hutniczej. Zakładasz je w zakładce Ekwipunek, przeciągając na pole przy postaci — albo przyciskiem tutaj (w kryjówce lub w sklepie).", 12, K.C_DIM))
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
		list.add_child(K.lbl(String(se[1]).to_upper(), 10, K.C_BLUE))
		for gid in ids:
			var iid: String = gid
			var gd: Dictionary = D.ITEMS[iid]
			var worn: bool = G.gear(slot) == iid
			var have: bool = worn or G.item(iid) > 0
			if not in_shop and not have:
				continue
			wear_offer.append(iid)
			var glocked: bool = int(S.lvl) < int(gd.lvl)
			var gc := K.panel(K.sb(Color(0.1, 0.16, 0.14) if worn else Color(0.085, 0.102, 0.15), 10, Color(K.C_ACC.r, K.C_ACC.g, K.C_ACC.b, 0.5) if worn else Color(1, 1, 1, 0.07), 1, 8))
			list.add_child(gc)
			var gh := K.hbox(10)
			gc.add_child(gh)
			var gi := K.icon(String(gd.icon), 44, K.C_TXT)
			gi.modulate.a = 0.45 if (glocked and not have) else 1.0
			gh.add_child(gi)
			var gv := K.vbox(1)
			gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gh.add_child(gv)
			gv.add_child(K.rich("[b]%s[/b]%s" % [String(gd.name), K.col("   ● na sobie", K.C_ACC) if worn else (K.col("   ● w plecaku", K.C_DIM) if have else "")], 14))
			gv.add_child(K.wrap(String(gd.desc), 11, K.C_DIM))
			gh.add_child(_marks(G.stat_marks(gd.get("stats", {})), true))
			var gb: Button
			if worn:
				gb = K.btn("Zdejmij", func(): G.gear_off(slot); render(), "", true)
				gb.disabled = not can_change
			elif have:
				gb = K.btn("Załóż", func(): G.gear_wear(iid); render(), "go", true)
				gb.disabled = not can_change
			else:
				gb = K.btn(("od poz. %d" % int(gd.lvl)) if glocked else ("Kup — %s" % G.money(gd.price)), func(): G.gear_buy(iid); render(), "go", true)
				gb.disabled = glocked or S.cash < float(gd.price)
			gb.custom_minimum_size = Vector2(108, 0)
			gb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			gh.add_child(gb)
	if wear_offer.is_empty():
		list.add_child(K.wrap("Nie masz jeszcze żadnych ubrań na zmianę.", 12, K.C_DIM))
	hint.text = "Zielone cechy pomagają, czerwone szkodzą  •  lepsze rzeczy odblokowują kolejne poziomy"


## znaczniki cech: wartość z ikoną, jedna pod drugą (zielone pomagają, czerwone szkodzą)
func _marks(marks: Array, tall: bool) -> Control:
	var fx: BoxContainer = K.vbox(-1) if tall else K.hbox(8)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.alignment = BoxContainer.ALIGNMENT_CENTER
	if tall:
		fx.custom_minimum_size = Vector2(62, 0)
	for mk in marks:
		var mc: Color = K.C_ACC if mk.good else K.C_BAD
		var mr := K.hbox(3)
		mr.alignment = BoxContainer.ALIGNMENT_END
		mr.tooltip_text = String(mk.tip)
		mr.add_child(K.lbl(String(mk.text), 12, mc))
		mr.add_child(K.icon(String(mk.icon), 14, mc))
		fx.add_child(mr)
	return fx


func _note(parent: Node, ic: String, color: Color, title: String, text: String, right := "") -> void:
	var p := K.panel(K.sb(Color(0.085, 0.102, 0.15), 9, Color(1, 1, 1, 0.06), 1, 9))
	parent.add_child(p)
	var h := K.hbox(10)
	p.add_child(h)
	var ib := K.panel(K.sb(Color(color.r, color.g, color.b, 0.16), 8, Color(color.r, color.g, color.b, 0.5), 1, 0))
	ib.custom_minimum_size = Vector2(34, 34)
	ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icn := K.icon(ic, 18, color)
	icn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ib.add_child(icn)
	h.add_child(ib)
	var v := K.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(K.lbl(title, 14, K.C_TXT))
	v.add_child(K.wrap(text, 11, K.C_DIM))
	h.add_child(v)
	if right != "":
		h.add_child(K.head(right, 18, color))


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
	var ni := G.next_installment()
	if float(S.debt) > 0.0:
		var txt := "Spłacono %s." % G.money(S.paid)
		if not ni.is_empty():
			var dl := int(ni.day) - G.day()
			txt = "Rata: łącznie %s do końca dnia %d (%s)." % [G.money(ni.due), int(ni.day), "za %d dni" % dl if dl > 0 else ("DZIŚ" if dl == 0 else "PO TERMINIE")]
		_note(bv, "skull", K.C_BAD, "Dług u Wiktora", txt, G.money(S.debt))
	else:
		_note(bv, "circle_check", K.C_ACC, "Dług u Wiktora", "Spłacony co do złotówki.", "0 zł")
	if float(S.credit) > 0.0:
		_note(bv, "truck", K.C_WARN, "Towar na zeszyt u Wiktora", "Oddaj do końca dnia %d. Limit: %s." % [int(float(S.credit_due) / 1440.0) + 1, G.money(G.credit_limit())], G.money(S.credit))
	else:
		_note(bv, "truck", K.C_DIM, "Towar na zeszyt u Wiktora", "Nic nie wisisz. Limit: %s." % G.money(G.credit_limit()), "0 zł")
	_note(bv, "house", K.C_DIM, "Koszty życia", "Czynsz i jedzenie schodzą co noc.", G.money(D.LIVING_COST))
	bv.add_child(K.gap(2))
	_title(bv, "package", "PACZKI")
	if S.drops.is_empty():
		bv.add_child(K.wrap("Żadnej paczki w drodze. Zamów towar: telefon → Giełda.", 13, K.C_DIM))
	for d in S.drops:
		var spot := "?"
		for ds in D.DROPS:
			if ds.id == d.spot:
				spot = ds.name
		var rdy: bool = d.state == "ready" or float(d.ready) <= S.t
		_note(bv, "package_open" if rdy else "timer", K.C_ACC if rdy else K.C_BLUE, "%d g %s" % [int(d.g), D.PRODUCT_GEN[d.p]],
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
	hint.text = "Organizer zbiera to, co łatwo przegapić: godziny spotkań, długi i paczki do odbioru"


## kosz: przerywana ramka, na którą upuszcza się rzeczy do wyrzucenia
class _DropBox:
	extends Control
	const KK = preload("res://scripts/uikit.gd")

	func _ready() -> void:
		var v := KK.vbox(6)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		var ic := KK.icon("trash_2", 44, Color(0.94, 0.3, 0.3, 0.85))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var t := KK.head("WYRZUĆ", 26, Color(0.9, 0.91, 0.94))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var s := KK.lbl("Przeciągnij tutaj rzecz, której chcesz się pozbyć.\nNie da się jej potem odzyskać.", 12, Color(0.56, 0.59, 0.66))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.062, 0.088, 0.7), true)
		var col := Color(0.94, 0.3, 0.3, 0.55)
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		for seg in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
			draw_dashed_line(seg[0], seg[1], col, 2.0, 10.0)
