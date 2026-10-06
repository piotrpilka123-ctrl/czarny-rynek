extends RefCounted
## Modele stanowisk produkcyjnych: regały uprawowe pod fioletowymi LED-ami, namiot, suszarka,
## zbiornik z pompą, filtr węglowy, stół laboratoryjny, cegły towaru. Kryjówki i laboratorium z prologu.

const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")

static var _plant_mats := {}
static var _plant_mesh: ArrayMesh = null
static var _mats := {}


static func _m(key: String, c: String, rough := 0.8, metal := 0.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	if not _mats.has(key):
		_mats[key] = Models.mat(c, rough, metal, emit, alpha)
	return _mats[key]


## karta rośliny: dwa skrzyżowane prostokąty wysokości 1 m, początek układu u podstawy łodygi
static func plant_mesh() -> ArrayMesh:
	if _plant_mesh != null:
		return _plant_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(2):
		var a := k * PI / 2.0 + 0.4
		var dx := cos(a) * 0.34
		var dz := sin(a) * 0.34
		var p := [Vector3(-dx, 0, -dz), Vector3(dx, 0, dz), Vector3(dx, 1, dz), Vector3(-dx, 1, -dz)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3(0, 1, 0))
			st.set_uv(uv[i])
			st.add_vertex(p[i])
	_plant_mesh = st.commit()
	return _plant_mesh


static func plant_material(stage: int) -> StandardMaterial3D:
	stage = clampi(stage, 1, 3)
	if not _plant_mats.has(stage):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/nature/gen_konopie_%d.png" % stage)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.45
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.85
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.albedo_color = Color(0.78, 0.8, 0.78)
		m.backlight_enabled = true
		m.backlight = Color(0.12, 0.2, 0.08)
		# odrobina własnego światła: pod fioletowymi LED-ami liście nie robią się czarne
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = 0.22
		_plant_mats[stage] = m
	return _plant_mats[stage]


## zwiędła wersja materiału rośliny (susza albo marna kondycja): pożółkła, przygaszona
static func plant_material_wilt(stage: int) -> StandardMaterial3D:
	stage = clampi(stage, 1, 3)
	var key := stage + 10
	if not _plant_mats.has(key):
		var m: StandardMaterial3D = plant_material(stage).duplicate()
		m.albedo_color = Color(0.82, 0.7, 0.36)
		m.backlight = Color(0.14, 0.12, 0.03)
		_plant_mats[key] = m
	return _plant_mats[key]


# ---------------------------------------------------------------- doniczka z krzakiem
const POT_H := 0.27

## Doniczka: „Soil” (ziemia, własny materiał — ciemnieje po podlaniu), „Plant” (krzak), „Fert” (granulki nawozu).
static func pot_node() -> Node3D:
	var g := Node3D.new()
	var plastic := _m("pot2", "9a5a3c", 0.85)
	Models.cyl(g, 0.165, 0.125, POT_H, Vector3(0, POT_H * 0.5, 0), plastic, Vector3.ZERO, 24)
	Models.cyl(g, 0.178, 0.172, 0.035, Vector3(0, POT_H - 0.012, 0), _m("potrim2", "a8674a", 0.8), Vector3.ZERO, 24)
	Models.cyl(g, 0.19, 0.2, 0.014, Vector3(0, 0.007, 0), _m("saucer2", "7c4630", 0.85), Vector3.ZERO, 24)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("3a2a1e")
	sm.roughness = 1.0
	var soil := Models.cyl(g, 0.15, 0.15, 0.02, Vector3(0, POT_H, 0), sm, Vector3.ZERO, 20)
	soil.name = "Soil"
	soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# grudki ziemi, żeby powierzchnia nie była płaskim krążkiem
	for k in range(7):
		var a := k * 0.9 + 0.3
		var rr := 0.04 + (k % 3) * 0.035
		Models.sphere(g, 0.014 + (k % 2) * 0.006, Vector3(cos(a) * rr, POT_H + 0.012, sin(a) * rr), _m("clod", "2a1d14", 1.0), Vector3(1, 0.5, 1), false, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fert := Node3D.new()
	fert.name = "Fert"
	g.add_child(fert)
	for k in range(9):
		var a2 := k * 2.4
		var r2 := 0.03 + (k % 4) * 0.028
		Models.sphere(fert, 0.007, Vector3(cos(a2) * r2, POT_H + 0.014, sin(a2) * r2), _m("granule" + str(k % 2), "8fc7ff" if k % 2 == 0 else "f2f2ea", 0.5), Vector3.ONE, false, 5).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fert.visible = false
	var pl := plant(1, 0.2)
	pl.name = "Plant"
	pl.position = Vector3(0, POT_H + 0.005, 0)
	pl.visible = false
	g.add_child(pl)
	return g


## wysokość krzaka (m) przy danym postępie
static func plant_height(prog: float, seed_k := 0.0) -> float:
	return lerpf(0.1, 1.12, clampf(prog, 0.0, 1.0)) * (0.93 + 0.07 * sin(seed_k * 2.1))


static func refresh_pot(n: Node3D, pl, seed_k := 0.0) -> void:
	var plant_n: MeshInstance3D = n.get_node_or_null("Plant")
	var soil: MeshInstance3D = n.get_node_or_null("Soil")
	var fert: Node3D = n.get_node_or_null("Fert")
	if plant_n == null:
		return
	plant_n.visible = pl != null
	if fert != null:
		fert.visible = pl != null and bool(pl.fert)
	var wet := float(pl.water) / 100.0 if pl != null else 0.3
	if soil != null:
		(soil.material_override as StandardMaterial3D).albedo_color = Color("4a3828").lerp(Color("1e150e"), clampf(wet, 0.0, 1.0))
		(soil.material_override as StandardMaterial3D).roughness = lerpf(1.0, 0.55, clampf(wet, 0.0, 1.0))
	if pl == null:
		return
	var prog := float(pl.prog)
	var stage := 1 if prog < 0.2 else (2 if prog < 0.6 else 3)
	var dry: bool = float(pl.water) <= 5.0
	var weak: bool = dry or float(pl.health) < 45.0
	plant_n.material_override = plant_material_wilt(stage) if weak else plant_material(stage)
	var hgt := plant_height(prog, seed_k)
	var slim := 0.88 if bool(pl.trim) else 1.0
	plant_n.scale = Vector3(hgt * slim, hgt * (0.8 if dry else 1.0), hgt * slim)
	plant_n.rotation.y = seed_k * 1.3
	plant_n.rotation.z = 0.12 if dry else 0.0


## Lampa LED do uprawy: panel na łańcuchach pod sufitem. „Bars” (świecące listwy) i „Led” (światło).
static func grow_lamp() -> Node3D:
	var g := Node3D.new()
	var h := 1.98
	var steel := _m("steel", "2b2e33", 0.45, 0.7)
	Models.box(g, Vector3(1.5, 0.05, 0.62), Vector3(0, h, 0), _m("ledbody", "17181b", 0.5, 0.4), Vector3.ZERO, false)
	# żebra radiatora na wierzchu
	for k in range(7):
		Models.box(g, Vector3(1.4, 0.03, 0.012), Vector3(0, h + 0.04, -0.24 + k * 0.08), _m("fins", "24262a", 0.4, 0.6), Vector3.ZERO, false)
	var bars := Node3D.new()
	bars.name = "Bars"
	g.add_child(bars)
	for sz in [-0.2, 0.0, 0.2]:
		Models.box(bars, Vector3(1.36, 0.02, 0.07), Vector3(0, h - 0.035, sz), _m("led", "e24bff", 0.4, 0.0, 4.5), Vector3.ZERO, false)
	var off := Node3D.new()
	off.name = "BarsOff"
	g.add_child(off)
	for sz in [-0.2, 0.0, 0.2]:
		Models.box(off, Vector3(1.36, 0.02, 0.07), Vector3(0, h - 0.035, sz), _m("ledoff", "3a2a40", 0.5), Vector3.ZERO, false)
	# łańcuchy do sufitu i przewód zasilania
	for sx in [-0.62, 0.62]:
		for sz in [-0.22, 0.22]:
			Models.cyl(g, 0.006, 0.006, 0.9, Vector3(sx, h + 0.47, sz), steel, Vector3.ZERO, 4).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Models.cyl(g, 0.008, 0.008, 0.9, Vector3(0.7, h + 0.47, 0.0), _m("cable", "0c0c0e", 0.8), Vector3(0, 0, 0.05), 4).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var led := OmniLight3D.new()
	led.name = "Led"
	led.position = Vector3(0, h - 0.3, 0)
	led.light_color = Color(0.86, 0.36, 1.0)
	led.light_energy = 0.6
	led.omni_range = 3.6
	led.omni_attenuation = 0.9
	led.shadow_enabled = false
	g.add_child(led)
	return g


static func refresh_lamp(n: Node3D, on: bool, mode := 0) -> void:
	var led: Light3D = n.get_node_or_null("Led")
	var bars: Node3D = n.get_node_or_null("Bars")
	var off: Node3D = n.get_node_or_null("BarsOff")
	if led != null:
		led.visible = on
		led.light_energy = 0.85 if mode == 1 else 0.6
	if bars != null:
		bars.visible = on
	if off != null:
		off.visible = not on


# ---------------------------------------------------------------- narzędzia ogrodnika (animacje doglądania)
## konewka: wylot „Spout” to punkt, z którego leci woda (oś −X to kierunek lania)
static func watering_can() -> Node3D:
	var g := Node3D.new()
	var body := _m("can", "3f7a4a", 0.45, 0.2)
	var dark := _m("can_dark", "2c5a36", 0.5, 0.2)
	Models.cyl(g, 0.085, 0.095, 0.17, Vector3(0, 0.085, 0), body, Vector3.ZERO, 14)
	Models.cyl(g, 0.088, 0.088, 0.012, Vector3(0, 0.172, 0), dark, Vector3.ZERO, 14)
	# dzióbek pod kątem i sitko
	Models.cyl(g, 0.014, 0.022, 0.24, Vector3(-0.17, 0.12, 0), body, Vector3(0, 0, -1.05), 8)
	Models.cyl(g, 0.034, 0.016, 0.03, Vector3(-0.285, 0.185, 0), dark, Vector3(0, 0, -1.05), 10)
	# ucho z tyłu i pałąk u góry
	for e in [[0.115, 0.15, 0.1, 0.0], [0.15, 0.1, 0.012, PI / 2.0 - 0.2], [0.115, 0.05, 0.1, 0.0]]:
		Models.box(g, Vector3(0.012 if e[2] > 0.05 else 0.07, e[2] if e[2] > 0.05 else 0.012, 0.022), Vector3(e[0], e[1], 0), dark, Vector3.ZERO, false)
	Models.box(g, Vector3(0.012, 0.11, 0.022), Vector3(0.15, 0.1, 0), dark, Vector3.ZERO, false)
	Models.box(g, Vector3(0.13, 0.012, 0.02), Vector3(-0.01, 0.215, 0), dark, Vector3.ZERO, false)
	for sx in [-0.07, 0.05]:
		Models.box(g, Vector3(0.012, 0.045, 0.02), Vector3(sx, 0.195, 0), dark, Vector3.ZERO, false)
	var sp := Node3D.new()
	sp.name = "Spout"
	sp.position = Vector3(-0.3, 0.195, 0)
	g.add_child(sp)
	return g


## butelka nawozu z nakrętką; „Mouth” to wylot
static func fert_bottle() -> Node3D:
	var g := Node3D.new()
	Models.cyl(g, 0.045, 0.05, 0.15, Vector3(0, 0.075, 0), _m("fertb", "2f8f4e", 0.4), Vector3.ZERO, 12)
	Models.cyl(g, 0.02, 0.045, 0.035, Vector3(0, 0.167, 0), _m("fertb", "2f8f4e", 0.4), Vector3.ZERO, 12)
	Models.cyl(g, 0.022, 0.022, 0.03, Vector3(0, 0.198, 0), _m("fertcap", "e8e4d6", 0.5), Vector3.ZERO, 10)
	Models.cyl(g, 0.0505, 0.0505, 0.07, Vector3(0, 0.08, 0), _m("fertlab", "f0ead2", 0.7), Vector3.ZERO, 12).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Models.box(g, Vector3(0.05, 0.02, 0.004), Vector3(0, 0.09, 0.051), _m("fertlab2", "2f8f4e", 0.6), Vector3.ZERO, false)
	var m := Node3D.new()
	m.name = "Mouth"
	m.position = Vector3(0, 0.215, 0)
	g.add_child(m)
	return g


## sekator: dwa ramiona („A” i „B”) obracane wokół nitu
static func shears() -> Node3D:
	var g := Node3D.new()
	var blade := _m("blade", "b9bec6", 0.25, 0.85)
	var grip := _m("grip", "c2302a", 0.6)
	for k in [0, 1]:
		var arm := Node3D.new()
		arm.name = "A" if k == 0 else "B"
		g.add_child(arm)
		var sgn := 1.0 if k == 0 else -1.0
		Models.box(arm, Vector3(0.11, 0.004, 0.02), Vector3(-0.06, 0.003 * sgn, 0.004 * sgn), blade, Vector3(0, 0.08 * sgn, 0), false)
		Models.box(arm, Vector3(0.12, 0.014, 0.018), Vector3(0.07, 0.0, -0.012 * sgn), grip, Vector3(0, -0.16 * sgn, 0), false)
	Models.cyl(g, 0.008, 0.008, 0.016, Vector3.ZERO, _m("rivet", "6a6e75", 0.3, 0.8), Vector3.ZERO, 8)
	return g


static func plant(stage: int, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = plant_mesh()
	mi.material_override = plant_material(stage)
	mi.scale = Vector3(h, h, h)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Regał uprawowy: stalowa rama, kuweta z doniczkami, dwie listwy LED. `tent` = czarny namiot dookoła.
## Dzieci: „Plants” (po jednej roślinie na doniczkę), „Led” (światło), „Bars” (świecące listwy).
static func rack(pots := 4, tent := false) -> Node3D:
	var g := Node3D.new()
	var w := 0.42 * pots + 0.1
	var dp := 0.72 if not tent else 1.2
	var h := 2.05
	if tent:
		w = 1.2
	var steel := _m("steel", "2b2e33", 0.45, 0.7)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Models.box(g, Vector3(0.045, h, 0.045), Vector3(sx * w * 0.5, h * 0.5, sz * dp * 0.5), steel)
	for sz in [-1.0, 1.0]:
		Models.box(g, Vector3(w, 0.04, 0.04), Vector3(0, h, sz * dp * 0.5), steel, Vector3.ZERO, false)
		Models.box(g, Vector3(w, 0.04, 0.04), Vector3(0, 0.3, sz * dp * 0.5), steel, Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		Models.box(g, Vector3(0.04, 0.04, dp), Vector3(sx * w * 0.5, h, 0), steel, Vector3.ZERO, false)
		Models.box(g, Vector3(0.04, 0.04, dp), Vector3(sx * w * 0.5, 0.3, 0), steel, Vector3.ZERO, false)
	# kuweta
	Models.box(g, Vector3(w - 0.06, 0.05, dp - 0.08), Vector3(0, 0.335, 0), _m("tray", "0e0f11", 0.6, 0.1))
	# listwy LED i ich światło
	var bars := Node3D.new()
	bars.name = "Bars"
	g.add_child(bars)
	for sz in [-0.17, 0.17]:
		Models.box(bars, Vector3(w - 0.2, 0.03, 0.1), Vector3(0, h - 0.13, sz), _m("led", "e24bff", 0.4, 0.0, 4.5), Vector3.ZERO, false)
		Models.box(g, Vector3(w - 0.16, 0.035, 0.14), Vector3(0, h - 0.1, sz), _m("ledbody", "17181b", 0.5, 0.4), Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		Models.cyl(g, 0.004, 0.004, 0.1, Vector3(sx * (w * 0.5 - 0.25), h - 0.05, 0), steel, Vector3.ZERO, 4)
	var led := OmniLight3D.new()
	led.name = "Led"
	led.position = Vector3(0, h - 0.22, 0)
	led.light_color = Color(0.86, 0.36, 1.0)
	led.light_energy = 0.55
	led.omni_range = 3.8
	led.omni_attenuation = 0.85
	led.shadow_enabled = false
	g.add_child(led)
	# doniczki i rośliny
	var plants := Node3D.new()
	plants.name = "Plants"
	g.add_child(plants)
	var pot := _m("pot", "141414", 0.7)
	var soil := _m("soil", "2e2118", 1.0)
	for k in range(pots):
		var px := (k - (pots - 1) * 0.5) * 0.42
		var pz := 0.0
		if tent:
			px = -0.28 + (k % 2) * 0.56
			pz = -0.2 + int(k / 2.0) * 0.4 if pots > 2 else 0.0
		Models.cyl(g, 0.15, 0.115, 0.27, Vector3(px, 0.36 + 0.135, pz), pot, Vector3.ZERO, 10)
		Models.cyl(g, 0.135, 0.135, 0.02, Vector3(px, 0.36 + 0.262, pz), soil, Vector3.ZERO, 10)
		var pl := plant(2, 0.8)
		pl.position = Vector3(px, 0.36 + 0.26, pz)
		pl.rotation.y = k * 1.3
		pl.visible = false
		plants.add_child(pl)
	if tent:
		var cloth := _m("tentcloth", "0b0b0d", 0.85)
		var silver := _m("tentin", "9aa0a8", 0.35, 0.6)
		for e in [[0.0, -dp * 0.5 - 0.02, w + 0.06, 0.02], [-w * 0.5 - 0.02, 0.0, 0.02, dp + 0.06], [w * 0.5 + 0.02, 0.0, 0.02, dp + 0.06]]:
			Models.box(g, Vector3(e[2], h, e[3]), Vector3(e[0], h * 0.5, e[1]), cloth)
		Models.box(g, Vector3(w + 0.06, 0.025, dp + 0.06), Vector3(0, h + 0.02, 0), cloth)
		Models.box(g, Vector3(w - 0.02, h - 0.4, 0.008), Vector3(0, h * 0.5 + 0.15, -dp * 0.5), silver, Vector3.ZERO, false)
		# odpięta klapa z przodu
		Models.box(g, Vector3(0.36, h, 0.02), Vector3(-w * 0.5 + 0.16, h * 0.5, dp * 0.5 + 0.02), cloth, Vector3(0, 0.5, 0))
	g.set_meta("pots", pots)
	return g


## stan regału na podstawie zadania (null = pusty)
static func refresh_rack(n: Node3D, j) -> void:
	var plants: Node3D = n.get_node_or_null("Plants")
	var led: Light3D = n.get_node_or_null("Led")
	var bars: Node3D = n.get_node_or_null("Bars")
	var on: bool = j != null
	if led != null:
		led.visible = on
	if bars != null:
		bars.visible = on
	if plants == null:
		return
	var i := 0
	for c in plants.get_children():
		var pl := c as MeshInstance3D
		pl.visible = on
		if on:
			var prog := float(j.prog)
			var stage := 1 if prog < 0.2 else (2 if prog < 0.6 else 3)
			pl.material_override = plant_material(stage)
			var hgt := lerpf(0.2, 1.22, clampf(prog, 0.0, 1.0)) * (0.92 + 0.08 * sin(i * 2.1))
			var dry: bool = j.has("water") and float(j.water) <= 5.0
			pl.scale = Vector3(hgt, hgt * (0.82 if dry else 1.0), hgt)
		i += 1


## Suszarka siatkowa: wiszące piętra z siatki; „Load” = susz na siatkach
static func dryer() -> Node3D:
	var g := Node3D.new()
	var steel := _m("steel", "2b2e33", 0.45, 0.7)
	var net := _m("net", "20242a", 0.9, 0.0, 0.0, 0.55)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Models.box(g, Vector3(0.035, 1.85, 0.035), Vector3(sx * 0.4, 0.925, sz * 0.4), steel)
	for sz in [-1.0, 1.0]:
		Models.box(g, Vector3(0.84, 0.035, 0.035), Vector3(0, 1.85, sz * 0.4), steel, Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		Models.box(g, Vector3(0.035, 0.035, 0.84), Vector3(sx * 0.4, 1.85, 0), steel, Vector3.ZERO, false)
	var load := Node3D.new()
	load.name = "Load"
	g.add_child(load)
	for t in range(4):
		var y := 0.45 + t * 0.36
		Models.cyl(g, 0.37, 0.37, 0.012, Vector3(0, y, 0), net, Vector3.ZERO, 14)
		Models.cyl(g, 0.375, 0.375, 0.03, Vector3(0, y + 0.01, 0), _m("netrim", "3a3f46", 0.6, 0.3, 0.0, 0.9), Vector3.ZERO, 14).scale = Vector3(1, 1, 1)
		for k in range(4):
			var a := k * PI / 2.0 + 0.5
			Models.cyl(g, 0.003, 0.003, 0.37, Vector3(cos(a) * 0.33, y + 0.19, sin(a) * 0.33), steel, Vector3.ZERO, 3)
		for k in range(7):
			var a2 := k * 0.9 + t
			var r := 0.08 + (k % 3) * 0.1
			Models.sphere(load, 0.05, Vector3(cos(a2) * r, y + 0.04, sin(a2) * r), _m("bud%d" % (k % 2), "5a7a34" if k % 2 == 0 else "6b8a3a", 0.95), Vector3(1.3, 0.6, 1.0), false, 6)
	load.visible = false
	return g


## Zbiornik z pompą: niebieska beczka, pompa i wąż
static func tank() -> Node3D:
	var g := Node3D.new()
	var blue := _m("tank", "23508c", 0.45, 0.1)
	Models.cyl(g, 0.3, 0.3, 0.92, Vector3(0, 0.46, 0), blue, Vector3.ZERO, 16)
	for y in [0.2, 0.46, 0.72]:
		Models.cyl(g, 0.312, 0.312, 0.035, Vector3(0, y, 0), _m("tankrib", "1c4274", 0.5, 0.1), Vector3.ZERO, 16)
	Models.cyl(g, 0.31, 0.31, 0.04, Vector3(0, 0.94, 0), _m("tanklid", "14161a", 0.5, 0.2), Vector3.ZERO, 16)
	Models.box(g, Vector3(0.2, 0.14, 0.16), Vector3(0.05, 1.03, 0.0), _m("pump", "d98a1e", 0.5, 0.2))
	Models.cyl(g, 0.045, 0.045, 0.12, Vector3(-0.12, 1.02, 0.0), _m("steel", "2b2e33", 0.45, 0.7), Vector3(0, 0, PI / 2.0), 8)
	var hose := _m("hose", "1a1c1f", 0.7)
	Models.cyl(g, 0.018, 0.018, 0.9, Vector3(0.3, 0.6, 0.14), hose, Vector3(0, 0, 0.12), 6)
	Models.cyl(g, 0.018, 0.018, 0.5, Vector3(0.52, 0.03, 0.2), hose, Vector3(PI / 2.0, 0.6, 0), 6)
	return g


## Filtr węglowy: bęben na stojaku, wentylator i rura do sufitu
static func carbon_filter() -> Node3D:
	var g := Node3D.new()
	var steel := _m("steel", "2b2e33", 0.45, 0.7)
	for sx in [-1.0, 1.0]:
		Models.box(g, Vector3(0.04, 1.0, 0.04), Vector3(sx * 0.22, 0.5, 0), steel)
	Models.box(g, Vector3(0.5, 0.04, 0.4), Vector3(0, 0.02, 0), steel)
	Models.cyl(g, 0.19, 0.19, 0.62, Vector3(0, 1.05, 0), _m("filt", "b8bcc2", 0.35, 0.7), Vector3(0, 0, PI / 2.0), 14)
	Models.cyl(g, 0.2, 0.2, 0.5, Vector3(0, 1.05, 0), _m("filtmesh", "55595f", 0.7, 0.5), Vector3(0, 0, PI / 2.0), 14)
	Models.cyl(g, 0.15, 0.15, 0.2, Vector3(0.4, 1.05, 0), _m("fan", "1b1d21", 0.5, 0.3), Vector3(0, 0, PI / 2.0), 12)
	Models.cyl(g, 0.1, 0.1, 0.62, Vector3(0.52, 1.4, 0), _m("duct", "9da2a8", 0.4, 0.6), Vector3.ZERO, 10)
	return g


## Stół laboratoryjny: palnik, kolba, chłodnica, zlewki, butle. „Glow” świeci, gdy coś się gotuje.
static func lab_table() -> Node3D:
	var g := Node3D.new()
	var steel := _m("labsteel", "8d9299", 0.35, 0.8)
	var dark := _m("steel", "2b2e33", 0.45, 0.7)
	Models.box(g, Vector3(2.0, 0.05, 0.9), Vector3(0, 0.9, 0), steel)
	Models.box(g, Vector3(1.9, 0.03, 0.8), Vector3(0, 0.3, 0), dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Models.box(g, Vector3(0.05, 0.9, 0.05), Vector3(sx * 0.95, 0.45, sz * 0.4), dark)
	var glass := _m("glass", "cfe6ee", 0.08, 0.0, 0.0, 0.28)
	# płyta grzejna i kolba okrągłodenna
	Models.box(g, Vector3(0.34, 0.07, 0.34), Vector3(-0.55, 0.96, 0.0), _m("hot", "1a1b1e", 0.5, 0.3))
	Models.cyl(g, 0.12, 0.12, 0.01, Vector3(-0.55, 1.0, 0.0), _m("hotplate", "3a2a26", 0.5, 0.4), Vector3.ZERO, 12)
	Models.sphere(g, 0.15, Vector3(-0.55, 1.16, 0.0), glass, Vector3.ONE, false, 12)
	Models.cyl(g, 0.04, 0.045, 0.22, Vector3(-0.55, 1.37, 0.0), glass, Vector3.ZERO, 8)
	# statyw i chłodnica
	Models.cyl(g, 0.012, 0.012, 0.9, Vector3(-0.28, 1.38, -0.25), dark, Vector3.ZERO, 6)
	Models.box(g, Vector3(0.22, 0.02, 0.16), Vector3(-0.28, 0.935, -0.25), dark)
	Models.cyl(g, 0.035, 0.035, 0.7, Vector3(-0.18, 1.4, 0.0), glass, Vector3(0, 0, -1.05), 8)
	Models.cyl(g, 0.012, 0.012, 0.74, Vector3(-0.18, 1.4, 0.0), _m("coil", "9fd0e0", 0.2, 0.0, 0.0, 0.5), Vector3(0, 0, -1.05), 6)
	# odbieralnik, zlewki, butelki
	Models.cyl(g, 0.09, 0.07, 0.2, Vector3(0.2, 1.03, 0.05), glass, Vector3.ZERO, 10)
	Models.cyl(g, 0.06, 0.06, 0.14, Vector3(0.48, 1.0, -0.2), glass, Vector3.ZERO, 10)
	Models.cyl(g, 0.045, 0.045, 0.2, Vector3(0.6, 1.03, 0.18), glass, Vector3.ZERO, 8)
	Models.cyl(g, 0.055, 0.055, 0.2, Vector3(0.82, 1.03, -0.1), _m("brownbottle", "5a3414", 0.25, 0.0, 0.0, 0.85), Vector3.ZERO, 8)
	Models.cyl(g, 0.02, 0.02, 0.06, Vector3(0.82, 1.16, -0.1), _m("cap", "111111", 0.6), Vector3.ZERO, 6)
	Models.box(g, Vector3(0.26, 0.02, 0.36), Vector3(0.72, 0.94, 0.22), _m("trayw", "e8e6e0", 0.6))
	# zawartość naczyń: widoczna i świecąca tylko w trakcie syntezy
	var glow := Node3D.new()
	glow.name = "Glow"
	g.add_child(glow)
	Models.sphere(glow, 0.125, Vector3(-0.55, 1.13, 0.0), _m("liq", "9be35a", 0.3, 0.0, 1.4, 0.85), Vector3(1, 0.7, 1), false, 10)
	Models.cyl(glow, 0.078, 0.062, 0.1, Vector3(0.2, 0.99, 0.05), _m("liq2", "e9e2b8", 0.4, 0.0, 0.5, 0.9), Vector3.ZERO, 10)
	Models.cyl(glow, 0.1, 0.1, 0.012, Vector3(-0.55, 1.005, 0.0), _m("heat", "ff5a1e", 0.5, 0.0, 3.0), Vector3.ZERO, 12)
	var li := OmniLight3D.new()
	li.position = Vector3(-0.5, 1.3, 0.1)
	li.light_color = Color(0.65, 1.0, 0.5)
	li.light_energy = 0.7
	li.omni_range = 2.6
	li.shadow_enabled = false
	glow.add_child(li)
	glow.visible = false
	# produkt na tacce
	var out := Node3D.new()
	out.name = "Out"
	g.add_child(out)
	for k in range(6):
		Models.box(out, Vector3(0.05, 0.02, 0.04), Vector3(0.66 + (k % 3) * 0.06, 0.96, 0.14 + int(k / 3.0) * 0.1), _m("cryst", "f1ecd0", 0.5), Vector3(0, k * 0.7, 0), false)
	out.visible = false
	# pod blatem: butla, kanistry
	var pt := Props.make("propane_tank", 0.62)
	pt.position = Vector3(-0.6, 0.32, 0.0)
	g.add_child(pt)
	for k in range(2):
		var bt := Props.make("plastic_bottle_gallon", 0.3)
		bt.position = Vector3(0.3 + k * 0.32, 0.32, -0.1 + k * 0.12)
		bt.rotation.y = k * 1.1
		g.add_child(bt)
	return g


static func refresh_lab(n: Node3D, j) -> void:
	var glow: Node3D = n.get_node_or_null("Glow")
	var out: Node3D = n.get_node_or_null("Out")
	if glow != null:
		glow.visible = j != null and float(j.prog) < 1.0
	if out != null:
		out.visible = j != null and float(j.prog) >= 1.0


## owinięta taśmą cegła towaru (kolor zależy od rodzaju) i stos takich cegieł
static func brick(product := "dym") -> Node3D:
	var g := Node3D.new()
	var wrap := {"dym": "4a5a2c", "szron": "d9d2b0", "krysztal": "9ec4dc", "snieg": "eef1f4"}
	Models.box(g, Vector3(0.24, 0.07, 0.15), Vector3(0, 0.035, 0), _m("brick_" + product, String(wrap.get(product, "888888")), 0.45))
	Models.box(g, Vector3(0.245, 0.072, 0.035), Vector3(0, 0.035, 0), _m("tape", "8a6a3a", 0.6), Vector3.ZERO, false)
	Models.box(g, Vector3(0.035, 0.072, 0.152), Vector3(0, 0.035, 0), _m("tape", "8a6a3a", 0.6), Vector3.ZERO, false)
	return g


static func brick_stack(product: String, n: int) -> Node3D:
	var g := Node3D.new()
	for i in range(n):
		var b := brick(product)
		var layer := int(i / 4.0)
		var k := i % 4
		b.position = Vector3((k % 2) * 0.26 - 0.13 + (0.02 if layer % 2 == 1 else 0.0), layer * 0.072, int(k / 2.0) * 0.17 - 0.085)
		b.rotation.y = 0.04 * sin(i * 3.7)
		g.add_child(b)
	return g


## sportowa torba (prolog: ostatnia partia i gotówka)
static func duffel() -> Node3D:
	var g := Node3D.new()
	Models.capsule(g, 0.17, 0.74, Vector3(0, 0.17, 0), _m("duffel", "1d2330", 0.9), Vector3(0, 0, PI / 2.0))
	Models.box(g, Vector3(0.5, 0.012, 0.03), Vector3(0, 0.335, 0), _m("zip", "8a8f96", 0.4, 0.7), Vector3.ZERO, false)
	for sx in [-0.16, 0.16]:
		Models.cyl(g, 0.012, 0.012, 0.3, Vector3(sx, 0.38, 0), _m("strap", "0f1218", 0.9), Vector3(0, 0, PI / 2.0), 5)
	return g
