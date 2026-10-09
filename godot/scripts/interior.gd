extends RefCounted
## Klocki do urządzania wnętrz: listwy, okna ze światłem dziennym, lampy, obrazy i plakaty, aneks kuchenny,
## drobiazgi (butelki, puszki, pudełka po pizzy, gazety, buty), rury, zacieki. Wszystko z prostych brył
## i gotowych tekstur — bez kolizji, chyba że budujący doda ją sam.

const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")
const Stations = preload("res://scripts/stations.gd")

static var _mats := {}
static var _pane_tex: ImageTexture = null
static var _blob: GradientTexture2D = null


static func _m(key: String, c: String, rough := 0.8, metal := 0.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	if not _mats.has(key):
		_mats[key] = Models.mat(c, rough, metal, emit, alpha)
	return _mats[key]


static func _tex_mat(path: String, unshaded := false, alpha := false) -> StandardMaterial3D:
	var key := "tex:" + path + ("u" if unshaded else "") + ("a" if alpha else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(path) if ResourceLoader.exists(path) else null
		m.roughness = 0.9
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if alpha:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[key] = m
	return _mats[key]


## listwy przypodłogowe dookoła pokoju; `door_w` = przerwa na drzwi w ścianie południowej
static var _tint_mats := {}

## model z Blendera postawiony w `pos` (null, gdy pliku nie ma — wtedy zostaje stara wersja z brył)
static func _model(g: Node3D, name: String, pos: Vector3, rot_y := 0.0, scl := Vector3.ONE) -> Node3D:
	var n: Node3D = Stations.model(name)
	if n == null:
		return null
	n.position = pos
	n.rotation.y = rot_y
	n.scale = scl
	g.add_child(n)
	return n


## barwi części modelu o nazwach zaczynających się od „Tint” (jasne w modelu, kolor nadaje gra)
static func _tint(n: Node, color: Color, emit := false) -> void:
	if n is MeshInstance3D and (String(n.name).begins_with("Tint") or (emit and String(n.name).begins_with("Swiatlo"))):
		var mi: MeshInstance3D = n
		for i in range(mi.mesh.get_surface_count()):
			var src: Material = mi.mesh.surface_get_material(i)
			var key := "%d|%s|%s" % [src.get_instance_id() if src != null else 0, color.to_html(), emit]
			if not _tint_mats.has(key):
				var m: StandardMaterial3D = (src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new())
				if emit:
					m.emission_enabled = true
					m.emission = color
					m.albedo_color = color
				else:
					m.albedo_color = Color(color.r, color.g, color.b, m.albedo_color.a)
				_tint_mats[key] = m
			mi.set_surface_override_material(i, _tint_mats[key])
	for c in n.get_children():
		_tint(c, color, emit)


## lampa nie rzuca cienia od własnego światła (druty przy żarówce zaciemniały cały klosz i ściany)
static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


static func _hide(n: Node, prefix: String) -> void:
	if n is Node3D and String(n.name).begins_with(prefix):
		(n as Node3D).visible = false
	for c in n.get_children():
		_hide(c, prefix)


static func baseboards(g: Node3D, cx: float, w: float, d: float, color := "d9d4c8", h := 0.09, door_w := 1.2) -> void:
	var m := _m("bb_" + color, color, 0.7)
	Models.box(g, Vector3(w, h, 0.025), Vector3(cx, h * 0.5, -d * 0.5 + 0.012), m, Vector3.ZERO, false)
	Models.box(g, Vector3(0.025, h, d), Vector3(cx - w * 0.5 + 0.012, h * 0.5, 0), m, Vector3.ZERO, false)
	Models.box(g, Vector3(0.025, h, d), Vector3(cx + w * 0.5 - 0.012, h * 0.5, 0), m, Vector3.ZERO, false)
	var side := (w - door_w) * 0.5
	for sx in [-1.0, 1.0]:
		Models.box(g, Vector3(side, h, 0.025), Vector3(cx + sx * (door_w * 0.5 + side * 0.5), h * 0.5, d * 0.5 - 0.012), m, Vector3.ZERO, false)


## wzór szyb do rzucania plamy światła na podłogę (2×2 pola)
static func pane_texture() -> ImageTexture:
	if _pane_tex == null:
		var im := Image.create(64, 64, false, Image.FORMAT_RGB8)
		im.fill(Color(0, 0, 0))
		for y in range(64):
			for x in range(64):
				var inx := (x > 5 and x < 30) or (x > 34 and x < 59)
				var iny := (y > 5 and y < 30) or (y > 34 and y < 59)
				if inx and iny:
					im.set_pixel(x, y, Color(1, 1, 1))
		_pane_tex = ImageTexture.create_from_image(im)
	return _pane_tex


## Okno w ścianie północnej (z = −d/2) albo wschodniej/zachodniej. `wall`: "n", "e", "w".
## Zwraca {pane: materiał szyby, light: światło dzienne} — env.gd ściemnia je nocą.
static func window(g: Node3D, at: Vector3, w: float, h: float, wall := "n", curtain := "sheer", radiator := true) -> Dictionary:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = {"n": 0.0, "e": -PI / 2.0, "w": PI / 2.0}.get(wall, 0.0)
	g.add_child(n)
	var frame := _m("winframe", "e6e3da", 0.6)
	var pane := StandardMaterial3D.new()
	pane.albedo_color = Color(0.55, 0.66, 0.78)
	pane.emission_enabled = true
	pane.emission = Color(0.72, 0.82, 0.95)
	pane.emission_energy_multiplier = 1.0
	pane.roughness = 0.15
	Models.box(n, Vector3(w, h, 0.03), Vector3(0, 0, 0.02), pane, Vector3.ZERO, false)
	# rama, parapet, klamki i firanki z modelu (okno 1,5 × 1,2 m skalowane do zadanego otworu)
	var wm: Node3D = Stations.model("dom_okno")
	if wm != null:
		wm.scale = Vector3(w / 1.5, h / 1.2, 1.0)
		n.add_child(wm)
		if curtain != "sheer" and curtain != "drapes":
			_hide(wm, "Firanka")
			_hide(wm, "Karnisz")
		elif curtain == "drapes":
			_tint(wm, Color(0.42, 0.29, 0.23))
		if curtain == "blinds":
			var bm0 := _m("blind", "d8d2c2", 0.6)
			var rows0 := int(h / 0.07)
			for k0 in range(rows0):
				if k0 > rows0 * 0.72:
					break
				Models.box(n, Vector3(w - 0.04, 0.012, 0.05), Vector3(0, h * 0.5 - 0.04 - k0 * 0.07, 0.085), bm0, Vector3(0.5, 0, 0), false)
		curtain = "model"
	# rama: obwód, słupek i ślemię
	if curtain != "model":
		for sx in [-1.0, 1.0]:
			Models.box(n, Vector3(0.07, h + 0.1, 0.09), Vector3(sx * (w * 0.5 + 0.01), 0, 0.05), frame, Vector3.ZERO, false)
		for sy in [-1.0, 1.0]:
			Models.box(n, Vector3(w + 0.1, 0.07, 0.09), Vector3(0, sy * (h * 0.5 + 0.01), 0.05), frame, Vector3.ZERO, false)
		Models.box(n, Vector3(0.055, h, 0.07), Vector3(0, 0, 0.05), frame, Vector3.ZERO, false)
		Models.box(n, Vector3(w, 0.045, 0.07), Vector3(0, h * 0.18, 0.05), frame, Vector3.ZERO, false)
		Models.box(n, Vector3(w + 0.24, 0.045, 0.2), Vector3(0, -h * 0.5 - 0.05, 0.11), frame)
		for sx in [-0.5, 0.5]:
			Models.box(n, Vector3(0.03, 0.09, 0.02), Vector3(sx * 0.12, -h * 0.1, 0.09), _m("handle", "b8b0a0", 0.4, 0.6), Vector3.ZERO, false)
	# zasłony
	if curtain == "sheer" or curtain == "drapes":
		Models.cyl(n, 0.012, 0.012, w + 0.5, Vector3(0, h * 0.5 + 0.16, 0.14), _m("rod", "5a4a3a", 0.5, 0.3), Vector3(0, 0, PI / 2.0), 6)
		var cm := _m("sheer", "efe9dc", 0.95, 0.0, 0.0, 0.5) if curtain == "sheer" else _m("drape", "6a4a3a", 0.95)
		var folds := 5
		for sx in [-1.0, 1.0]:
			for k in range(folds):
				var cw := (w * 0.24) / folds
				var x = sx * (w * 0.5 + 0.1 - (k + 0.5) * cw)
				Models.box(n, Vector3(cw * 0.9, h + 0.34, 0.03), Vector3(x, -0.02, 0.13 + (0.018 if k % 2 == 0 else 0.0)), cm, Vector3(0, 0.25 if k % 2 == 0 else -0.25, 0), false)
	elif curtain == "blinds":
		var bm := _m("blind", "d8d2c2", 0.6)
		var rows := int(h / 0.07)
		for k in range(rows):
			if k > rows * 0.72:
				break
			Models.box(n, Vector3(w - 0.04, 0.012, 0.05), Vector3(0, h * 0.5 - 0.04 - k * 0.07, 0.085), bm, Vector3(0.5, 0, 0), false)
	# grzejnik pod parapetem
	if radiator:
		var rm := _m("radiator", "dcd8cc", 0.5, 0.2)
		var rw := minf(w, 1.3)
		for k in range(int(rw / 0.09)):
			Models.box(n, Vector3(0.07, 0.56, 0.1), Vector3(-rw * 0.5 + 0.045 + k * 0.09, -h * 0.5 - 0.42, 0.1), rm, Vector3.ZERO, false)
		Models.cyl(n, 0.018, 0.018, 0.5, Vector3(rw * 0.5 + 0.06, -h * 0.5 - 0.9, 0.1), _m("pipe", "b9b4a6", 0.5, 0.3), Vector3.ZERO, 6)
	# światło dzienne: plama o kształcie szyb na podłodze
	var li := SpotLight3D.new()
	li.position = Vector3(0, h * 0.2, 0.2)
	li.rotation = Vector3(-0.72, PI, 0.0)
	li.spot_range = 8.5
	li.spot_angle = 34.0
	li.spot_angle_attenuation = 0.5
	li.spot_attenuation = 0.6
	li.light_color = Color(1.0, 0.95, 0.86)
	li.light_energy = 2.4
	li.shadow_enabled = true
	li.light_projector = pane_texture()
	n.add_child(li)
	return {"pane": pane, "light": li, "base": 2.4}


## lampa sufitowa: "shade" (klosz), "bulb" (goła żarówka na kablu), "tube" (świetlówka)
static func ceiling_lamp(g: Node3D, pos: Vector3, kind := "shade", color := Color(1.0, 0.84, 0.6)) -> void:
	var lm := _model(g, {"shade": "dom_lampa_klosz", "bulb": "dom_lampa_zarowka", "tube": "dom_lampa_swietlowka"}.get(kind, ""), pos)
	if lm != null:
		_tint(lm, color, true)
		_no_shadow(lm)
		return
	var c := "%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
	if kind == "tube":
		Models.box(g, Vector3(1.24, 0.05, 0.14), Vector3(pos.x, pos.y - 0.025, pos.z), _m("tubebody", "c8c8c4", 0.5, 0.3), Vector3.ZERO, false)
		Models.cyl(g, 0.018, 0.018, 1.16, Vector3(pos.x, pos.y - 0.07, pos.z), Models.mat(c, 0.4, 0.0, 4.0), Vector3(0, 0, PI / 2.0), 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	Models.cyl(g, 0.006, 0.006, 0.36, Vector3(pos.x, pos.y - 0.18, pos.z), _m("cable", "1a1a1a", 0.8), Vector3.ZERO, 5).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Models.cyl(g, 0.05, 0.05, 0.02, Vector3(pos.x, pos.y - 0.01, pos.z), _m("rose", "d8d4c8", 0.7), Vector3.ZERO, 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb := Models.sphere(g, 0.045, Vector3(pos.x, pos.y - 0.4, pos.z), Models.mat(c, 0.3, 0.0, 5.0), Vector3(1, 1.25, 1), false, 8)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "shade":
		var sh := Models.cyl(g, 0.09, 0.24, 0.2, Vector3(pos.x, pos.y - 0.36, pos.z), _m("shade", "c9b98f", 0.9, 0.0, 0.25, 0.9), Vector3.ZERO, 14)
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## plakat albo obraz w ramce na ścianie; `rot_y` = obrót tak, by przód patrzył do pokoju
static func picture(g: Node3D, pos: Vector3, rot_y: float, h: float, tex: String, frame := "") -> void:
	var path := ("res://assets/pictures/%s.png" if tex.begins_with("pic_") else "res://assets/graffiti/%s.png") % tex
	var w := h * 0.706
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	g.add_child(n)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	q.mesh = qm
	q.material_override = _tex_mat(path)
	q.position = Vector3(0, 0, 0.012)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(q)
	if frame != "":
		var fm := _m("frame_" + frame, frame, 0.6)
		for sx in [-1.0, 1.0]:
			Models.box(n, Vector3(0.03, h + 0.06, 0.03), Vector3(sx * (w * 0.5 + 0.015), 0, 0.012), fm, Vector3.ZERO, false)
		for sy in [-1.0, 1.0]:
			Models.box(n, Vector3(w + 0.06, 0.03, 0.03), Vector3(0, sy * (h * 0.5 + 0.015), 0.012), fm, Vector3.ZERO, false)
	else:
		# plakat przyklejony taśmą: cztery skrawki w rogach
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				Models.box(n, Vector3(0.06, 0.025, 0.002), Vector3(sx * w * 0.46, sy * h * 0.47, 0.015), _m("tapebit", "d8cfa8", 0.6, 0.0, 0.0, 0.85), Vector3(0, 0, 0.6 * sx * sy), false)


## kartka / wycinek z napisem na ścianie (zamiast lewitującego tekstu)
static func note(g: Node3D, pos: Vector3, rot_y: float, text: String, w := 0.42, h := 0.3, paper := "e8e2cf") -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	g.add_child(n)
	Models.box(n, Vector3(w, h, 0.004), Vector3(0, 0, 0.004), _m("paper_" + paper, paper, 0.95), Vector3(0, 0, 0.03), false)
	Models.box(n, Vector3(0.05, 0.02, 0.002), Vector3(0, h * 0.5 - 0.01, 0.008), _m("tapebit", "d8cfa8", 0.6, 0.0, 0.0, 0.85), Vector3.ZERO, false)
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = 28
	lb.pixel_size = 0.0016
	lb.modulate = Color(0.12, 0.12, 0.14)
	lb.outline_size = 0
	lb.width = w / 0.0016 * 0.9
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.position = Vector3(0, 0, 0.009)
	lb.rotation.z = 0.03
	lb.double_sided = false
	n.add_child(lb)


static func rug(g: Node3D, pos: Vector3, size: Vector2, rot_y := 0.0, tint := Color(0.62, 0.36, 0.3)) -> void:
	Models.box(g, Vector3(size.x, 0.014, size.y), Vector3(pos.x, 0.008, pos.z), Props.pbr("dirty_carpet", 0.7, tint), Vector3(0, rot_y, 0), false)
	Models.box(g, Vector3(size.x + 0.06, 0.01, size.y + 0.06), Vector3(pos.x, 0.005, pos.z), _m("rugedge", "3a2a24", 0.95), Vector3(0, rot_y, 0), false)


## półka ścienna z książkami i drobiazgami
static func wall_shelf(g: Node3D, pos: Vector3, rot_y: float, w := 0.9, seed_v := 1) -> void:
	var sm := _model(g, "dom_polka", pos, rot_y, Vector3(w / 1.0, 1.0, 1.0))
	if sm != null:
		mug(sm, Vector3(0.42, 0.0125, 0.1), "c9c4b6")
		return
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	g.add_child(n)
	Models.box(n, Vector3(w, 0.025, 0.2), Vector3(0, 0, 0.1), _m("shelfwood", "6b5238", 0.7))
	for sx in [-1.0, 1.0]:
		Models.box(n, Vector3(0.02, 0.12, 0.16), Vector3(sx * (w * 0.5 - 0.08), -0.07, 0.08), _m("bracket", "2a2c30", 0.5, 0.5), Vector3.ZERO, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cols := ["7a2a2a", "2a4a6a", "3a5a3a", "8a6a2a", "4a3a5a", "c9c4b6", "1c1c20"]
	var x := -w * 0.5 + 0.06
	while x < w * 0.5 - 0.3:
		var bw := rng.randf_range(0.022, 0.05)
		var bh := rng.randf_range(0.16, 0.24)
		Models.box(n, Vector3(bw, bh, 0.14), Vector3(x + bw * 0.5, 0.0125 + bh * 0.5, 0.09), _m("book" + cols[rng.randi() % cols.size()], cols[rng.randi() % cols.size()], 0.8), Vector3(0, 0, rng.randf_range(-0.03, 0.03)), false)
		x += bw + 0.004
	mug(n, Vector3(w * 0.5 - 0.12, 0.0125, 0.1), "c9c4b6")


static func bottle(g: Node3D, pos: Vector3, color := "3a6a3a", lying := false) -> void:
	var bm := _model(g, "dom_butelka", pos + (Vector3(0, 0.032, 0) if lying else Vector3.ZERO))
	if bm != null:
		if lying:
			bm.rotation = Vector3(0, float(absi(color.hash()) % 60) * 0.1, PI / 2.0)
		_tint(bm, Models.col(color))
		return
	var m := _m("bottle_" + color, color, 0.15, 0.0, 0.0, 0.75)
	var rot := Vector3(0, 0, PI / 2.0) if lying else Vector3.ZERO
	var p := pos + (Vector3(0, 0.032, 0) if lying else Vector3(0, 0.09, 0))
	Models.cyl(g, 0.03, 0.032, 0.18, p, m, rot, 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var np := pos + (Vector3(0.13, 0.032, 0) if lying else Vector3(0, 0.22, 0))
	Models.cyl(g, 0.011, 0.02, 0.08, np, m, rot, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func can(g: Node3D, pos: Vector3, color := "b0382c", crushed := false) -> void:
	var cm0 := _model(g, "dom_puszka", pos)
	if cm0 != null:
		if crushed:
			cm0.scale = Vector3(1.05, 0.5, 1.0)
			cm0.rotation = Vector3(0.22, float(absi(color.hash()) % 60) * 0.1, 0.08)
		_tint(cm0, Models.col(color))
		return
	var c := Models.cyl(g, 0.032, 0.032, 0.07 if crushed else 0.12, pos + Vector3(0, 0.035 if crushed else 0.06, 0), _m("can_" + color, color, 0.35, 0.7), Vector3(0.2 if crushed else 0.0, 0, 0), 8)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func mug(g: Node3D, pos: Vector3, color := "d9d4c8") -> void:
	var mm := _model(g, "dom_kubek", pos, float(absi(color.hash()) % 60) * 0.1)
	if mm != null:
		_tint(mm, Models.col(color))
		return
	Models.cyl(g, 0.04, 0.035, 0.09, pos + Vector3(0, 0.045, 0), _m("mug_" + color, color, 0.5), Vector3.ZERO, 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func pizza_box(g: Node3D, pos: Vector3, rot_y := 0.0, n := 1) -> void:
	if Stations.model("dom_pizza") != null:
		for i0 in range(n):
			_model(g, "dom_pizza", pos + Vector3(0, i0 * 0.046, 0), rot_y + i0 * 0.2)
		return
	for i in range(n):
		Models.box(g, Vector3(0.33, 0.04, 0.33), pos + Vector3(0, 0.02 + i * 0.041, 0), _m("pizza", "b89a6a", 0.9), Vector3(0, rot_y + i * 0.2, 0), false)
		Models.box(g, Vector3(0.18, 0.002, 0.18), pos + Vector3(0, 0.041 + i * 0.041, 0), _m("pizzalogo", "a8322a", 0.9), Vector3(0, rot_y + i * 0.2, 0), false)


static func papers(g: Node3D, pos: Vector3, rot_y := 0.0, n := 3) -> void:
	for i in range(n):
		Models.box(g, Vector3(0.3, 0.004, 0.42), pos + Vector3(i * 0.03, 0.003 + i * 0.005, i * 0.02), _m("newsp%d" % (i % 2), "d9d4c4" if i % 2 == 0 else "cfc8b4", 0.95), Vector3(0, rot_y + i * 0.35, 0), false)


static func shoes(g: Node3D, pos: Vector3, rot_y := 0.0, color := "1c1c20") -> void:
	var sh0 := _model(g, "dom_buty", pos, rot_y + PI)
	if sh0 != null:
		_tint(sh0, Models.col(color))
		return
	for sx in [-0.07, 0.07]:
		var n := Node3D.new()
		n.position = pos + Vector3(cos(rot_y) * sx, 0, -sin(rot_y) * sx)
		n.rotation.y = rot_y + sx * 2.0
		g.add_child(n)
		Models.box(n, Vector3(0.1, 0.06, 0.27), Vector3(0, 0.03, 0), _m("shoe_" + color, color, 0.8), Vector3.ZERO, false)
		Models.box(n, Vector3(0.095, 0.07, 0.12), Vector3(0, 0.085, -0.07), _m("shoe_" + color, color, 0.8), Vector3.ZERO, false)
		Models.box(n, Vector3(0.105, 0.02, 0.28), Vector3(0, 0.01, 0), _m("sole", "d8d4c8", 0.8), Vector3.ZERO, false)


static func ashtray(g: Node3D, pos: Vector3) -> void:
	if _model(g, "dom_popielniczka", pos) != null:
		return
	Models.cyl(g, 0.06, 0.05, 0.025, pos + Vector3(0, 0.0125, 0), _m("ashtray", "5a6a72", 0.2, 0.0, 0.0, 0.7), Vector3.ZERO, 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in range(3):
		Models.cyl(g, 0.004, 0.004, 0.05, pos + Vector3(-0.02 + k * 0.02, 0.03, 0.01 * k), _m("butt", "d8c8a8", 0.9), Vector3(1.2, k * 1.1, 0), 4).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## rura (pozioma albo pionowa) między dwoma punktami
static func pipe(g: Node3D, a: Vector3, b: Vector3, r := 0.04, color := "6a5a4a", metal := 0.4) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 0.01:
		return
	var mi := Models.cyl(g, r, r, ln, (a + b) * 0.5, _m("pipe_" + color, color, 0.55, metal), Vector3.ZERO, 8)
	# walec stoi wzdłuż osi Y: obracamy go najkrótszym łukiem na kierunek rury
	var dn := d / ln
	if absf(dn.y) < 0.999:
		mi.quaternion = Quaternion(Vector3.UP, dn)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## zaciek / plama na ścianie albo podłodze (półprzezroczysta, miękka)
static func stain(g: Node3D, pos: Vector3, rot: Vector3, size: Vector2, color := Color(0.12, 0.1, 0.07, 0.4)) -> void:
	if _blob == null:
		_blob = Props._soft_tex()
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _blob
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material_override = m
	q.position = pos
	q.rotation = rot
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(q)


## Aneks kuchenny wzdłuż ściany (oś X), frontem do +Z: szafki, blat, zlew, płytki, szafki wiszące.
## Zwraca szerokość zabudowy (do kolizji).
static func kitchenette(g: Node3D, at: Vector3, w: float, rot_y := 0.0) -> void:
	if _model(g, "dom_aneks", at, rot_y, Vector3(w / 1.3, 1.0, 1.0)) != null:
		return
	var n := Node3D.new()
	n.position = at
	n.rotation.y = rot_y
	g.add_child(n)
	var cab := _m("kcab", "cfc9b8", 0.6)
	var top := _m("ktop", "4a4640", 0.45)
	var handle := _m("handle", "b8b0a0", 0.4, 0.6)
	# płytki nad blatem
	Models.box(n, Vector3(w, 0.62, 0.012), Vector3(0, 1.2, -0.29), Props.pbr("dirty_tiles", 0.35, Color(0.95, 0.95, 0.9)), Vector3.ZERO, false)
	var doors := maxi(2, int(w / 0.5))
	var dw := w / doors
	Models.box(n, Vector3(w, 0.84, 0.56), Vector3(0, 0.43, 0), cab)
	Models.box(n, Vector3(w + 0.03, 0.04, 0.6), Vector3(0, 0.87, 0.01), top)
	Models.box(n, Vector3(w, 0.08, 0.5), Vector3(0, 0.04, -0.02), _m("kplinth", "2a2826", 0.8), Vector3.ZERO, false)
	for k in range(doors):
		var x := -w * 0.5 + (k + 0.5) * dw
		Models.box(n, Vector3(dw - 0.02, 0.7, 0.015), Vector3(x, 0.46, 0.287), _m("kdoor", "d9d3c2", 0.55), Vector3.ZERO, false)
		Models.box(n, Vector3(0.012, 0.11, 0.02), Vector3(x + dw * 0.36, 0.62, 0.3), handle, Vector3.ZERO, false)
	# zlew z baterią
	var sx0 := -w * 0.5 + dw * 0.5 + (dw if doors > 2 else 0.0)
	Models.box(n, Vector3(0.42, 0.012, 0.36), Vector3(sx0, 0.893, 0.02), _m("sink", "aeb4ba", 0.25, 0.85), Vector3.ZERO, false)
	Models.box(n, Vector3(0.34, 0.1, 0.28), Vector3(sx0, 0.845, 0.02), _m("sinkin", "7c8288", 0.3, 0.8), Vector3.ZERO, false)
	Models.cyl(n, 0.012, 0.012, 0.2, Vector3(sx0, 0.99, -0.14), _m("tap", "c8ccd0", 0.2, 0.9), Vector3.ZERO, 6)
	Models.cyl(n, 0.01, 0.01, 0.13, Vector3(sx0, 1.08, -0.08), _m("tap", "c8ccd0", 0.2, 0.9), Vector3(PI / 2.0, 0, 0), 6)
	# szafki wiszące
	Models.box(n, Vector3(w, 0.56, 0.32), Vector3(0, 1.84, -0.13), cab)
	for k in range(doors):
		var x2 := -w * 0.5 + (k + 0.5) * dw
		Models.box(n, Vector3(dw - 0.02, 0.52, 0.015), Vector3(x2, 1.84, 0.035), _m("kdoor", "d9d3c2", 0.55), Vector3.ZERO, false)
		Models.box(n, Vector3(0.012, 0.09, 0.02), Vector3(x2 + dw * 0.36, 1.66, 0.05), handle, Vector3.ZERO, false)


## lodówka: biała bryła z uszczelką, uchwytami i magnesami
static func fridge(g: Node3D, at: Vector3, rot_y := 0.0, h := 1.62) -> void:
	if _model(g, "dom_lodowka", at, rot_y, Vector3(1.0, h / 1.62, 1.0)) != null:
		return
	var n := Node3D.new()
	n.position = at
	n.rotation.y = rot_y
	g.add_child(n)
	var body := _m("fridge", "e4e2dc", 0.4, 0.1)
	Models.box(n, Vector3(0.58, h, 0.58), Vector3(0, h * 0.5, 0), body)
	Models.box(n, Vector3(0.56, 0.012, 0.02), Vector3(0, h * 0.68, 0.292), _m("gasket", "8a8a86", 0.8), Vector3.ZERO, false)
	for e in [[h * 0.82, 0.22], [h * 0.52, 0.3]]:
		Models.box(n, Vector3(0.025, e[1], 0.03), Vector3(-0.22, e[0], 0.305), _m("handle", "b8b0a0", 0.4, 0.6), Vector3.ZERO, false)
	for k in range(3):
		Models.box(n, Vector3(0.05, 0.05, 0.006), Vector3(0.05 + k * 0.08, h * 0.86 - k * 0.07, 0.294), _m("magnet%d" % k, ["c8322a", "2a6ac8", "e8c22a"][k], 0.6), Vector3(0, 0, k * 0.4), false)
	Models.box(n, Vector3(0.16, 0.2, 0.004), Vector3(0.14, h * 0.5, 0.293), _m("paper_e8e2cf", "e8e2cf", 0.95), Vector3(0, 0, -0.06), false)


## wieszak z kurtką przy drzwiach
static func coat_rack(g: Node3D, pos: Vector3, rot_y: float, jacket := "34455a") -> void:
	var cr := _model(g, "dom_wieszak", pos, rot_y)
	if cr != null:
		_tint(cr, Models.col(jacket))
		return
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	g.add_child(n)
	Models.box(n, Vector3(0.6, 0.08, 0.02), Vector3(0, 0, 0.01), _m("shelfwood", "6b5238", 0.7), Vector3.ZERO, false)
	for k in range(4):
		Models.cyl(n, 0.008, 0.008, 0.06, Vector3(-0.22 + k * 0.15, -0.01, 0.04), _m("handle", "b8b0a0", 0.4, 0.6), Vector3(PI / 2.0, 0, 0), 5).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# kurtka: korpus zwężony ku górze, rękawy wiszą wzdłuż boków, kaptur przy haczyku
	var jm := _m("jacket_" + jacket, jacket, 0.95)
	Models.box(n, Vector3(0.36, 0.62, 0.09), Vector3(-0.07, -0.42, 0.075), jm)
	Models.box(n, Vector3(0.28, 0.12, 0.085), Vector3(-0.07, -0.07, 0.075), jm)
	Models.box(n, Vector3(0.09, 0.56, 0.08), Vector3(-0.29, -0.4, 0.07), jm, Vector3(0, 0, 0.06))
	Models.box(n, Vector3(0.09, 0.56, 0.08), Vector3(0.15, -0.4, 0.07), jm, Vector3(0, 0, -0.06))
	Models.box(n, Vector3(0.2, 0.16, 0.1), Vector3(-0.07, -0.02, 0.085), _m("jackethood", "1a1e28", 0.95))
	Models.box(n, Vector3(0.012, 0.56, 0.005), Vector3(-0.07, -0.44, 0.123), _m("zip", "8a8f96", 0.4, 0.7), Vector3.ZERO, false)


## włącznik światła / gniazdko
static func switch_plate(g: Node3D, pos: Vector3, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	g.add_child(n)
	Models.box(n, Vector3(0.08, 0.08, 0.012), Vector3(0, 0, 0.006), _m("switch", "e8e4da", 0.5), Vector3.ZERO, false)
	Models.box(n, Vector3(0.03, 0.045, 0.008), Vector3(0, 0, 0.014), _m("switchk", "d4d0c4", 0.5), Vector3(0.15, 0, 0), false)


## tablica z narzędziami na ścianie garażu
static func pegboard(g: Node3D, pos: Vector3, rot_y: float, w := 1.5, h := 0.9) -> void:
	if _model(g,"garaz_narzedzia",pos,rot_y,Vector3(w/1.6,h/0.9,1.0)) != null:
		return
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	g.add_child(n)
	Models.box(n, Vector3(w, h, 0.02), Vector3(0, 0, 0.01), _m("peg", "8a6f4a", 0.9), Vector3.ZERO, false)
	var steel := _m("toolsteel", "9aa0a6", 0.35, 0.8)
	var grip := _m("toolgrip", "a8322a", 0.7)
	# klucze płaskie, młotek, piła, śrubokręty
	for k in range(5):
		var x := -w * 0.42 + k * 0.11
		Models.box(n, Vector3(0.022, 0.2 + k * 0.03, 0.008), Vector3(x, h * 0.18, 0.03), steel, Vector3(0, 0, 0.05), false)
	Models.box(n, Vector3(0.03, 0.3, 0.02), Vector3(0.05, h * 0.05, 0.035), _m("shelfwood", "6b5238", 0.7), Vector3.ZERO, false)
	Models.box(n, Vector3(0.12, 0.05, 0.04), Vector3(0.05, h * 0.05 + 0.16, 0.04), steel, Vector3.ZERO, false)
	Models.box(n, Vector3(0.42, 0.1, 0.006), Vector3(w * 0.26, h * 0.26, 0.03), steel, Vector3(0, 0, -0.1), false)
	Models.box(n, Vector3(0.1, 0.09, 0.02), Vector3(w * 0.26 - 0.24, h * 0.3, 0.035), grip, Vector3.ZERO, false)
	for k in range(4):
		var x2 := w * 0.12 + k * 0.08
		Models.cyl(n, 0.006, 0.006, 0.16, Vector3(x2, -h * 0.2, 0.03), steel, Vector3.ZERO, 5).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Models.cyl(n, 0.016, 0.016, 0.09, Vector3(x2, -h * 0.2 + 0.12, 0.03), grip if k % 2 == 0 else _m("toolgrip2", "e8c22a", 0.7), Vector3.ZERO, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Models.cyl(n, 0.11, 0.11, 0.03, Vector3(-w * 0.3, -h * 0.22, 0.03), _m("tapeblack", "141414", 0.8), Vector3(PI / 2.0, 0, 0), 14).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## kartonowe pudła do przeprowadzki ustawione w stos
static func moving_boxes(g: Node3D, pos: Vector3, seed_v := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var m := _m("cardboard", "a88a5e", 0.95)
	var tape := _m("tapebit", "d8cfa8", 0.6, 0.0, 0.0, 0.85)
	var spots := [Vector3(0, 0, 0), Vector3(0.52, 0, 0.06), Vector3(0.2, 0.38, 0.03)]
	for i in range(spots.size()):
		var s := Vector3(rng.randf_range(0.4, 0.5), rng.randf_range(0.3, 0.38), rng.randf_range(0.34, 0.42))
		var p: Vector3 = pos + spots[i] + Vector3(0, s.y * 0.5, 0)
		var ry := rng.randf_range(-0.25, 0.25)
		Models.box(g, s, p, m, Vector3(0, ry, 0))
		Models.box(g, Vector3(s.x + 0.004, 0.004, 0.06), p + Vector3(0, s.y * 0.5, 0), tape, Vector3(0, ry, 0), false)
