extends Node3D
## DOGLĄDANIE KRZAKA: krótkie animacje nad doniczką — sadzenie, podlewanie z konewki, nawożenie, cięcie sekatorem.
## Narzędzie pojawia się nad doniczką, kamera sama patrzy na roślinę, a skutek (woda, nawóz, zbiór) wchodzi
## w połowie animacji. W testach (G.test_mode) wszystko dzieje się natychmiast.

const Stations = preload("res://scripts/stations.gd")
const Models = preload("res://scripts/models.gd")

const DUR := {"seed": 1.6, "water": 2.8, "fert": 2.4, "cut": 2.6}

var active := false
var kind := ""
var room := ""
var idx := -1
var t := 0.0
var dur := 1.0
var applied := false
var tool: Node3D = null
var fx: CPUParticles3D = null
var fx2: CPUParticles3D = null
var base := Vector3.ZERO       # środek ziemi w doniczce
var side := Vector3.RIGHT      # w prawo od gracza
var from_yaw := 0.0
var from_pitch := 0.0
var to_yaw := 0.0
var to_pitch := 0.0
var cut_kind := ""
var result := {}
var snips := 0
var h0 := 0.0                  # wysokość krzaka na początku cięcia


func busy() -> bool:
	return active


func play(what: String, in_room: String, i: int) -> bool:
	if active or not DUR.has(what):
		return false
	var P = G.Prod
	var pt: Dictionary = P.pot(in_room, i)
	if pt.is_empty():
		return false
	kind = what
	room = in_room
	idx = i
	cut_kind = P.plant_cut_kind(room, i) if what == "cut" else ""
	result = {}
	if G.test_mode or G.player == null:
		_apply()
		_finish_msg()
		return true
	active = true
	applied = false
	t = 0.0
	snips = 0
	dur = float(DUR[what])
	G.busy = true
	var pl = pt.pl
	h0 = Stations.plant_height(float(pl.prog), float(i)) if pl != null else 0.0
	var cx: float = D.ROOMS[room].cx
	base = Vector3(cx + float(pt.x), Stations.POT_H, float(pt.z))
	var P3 = G.player
	var cam: Camera3D = P3.cam
	var eye := cam.global_position
	var to := base + Vector3(0, minf(0.35, h0 * 0.45), 0) - eye
	from_yaw = P3.yaw
	from_pitch = P3.pitch
	to_yaw = from_yaw + wrapf(atan2(-to.x, -to.z) - from_yaw, -PI, PI)
	to_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.3, 0.6)
	var fwd := Vector3(to.x, 0, to.z).normalized()
	side = Vector3(-fwd.z, 0, fwd.x)
	_make_tool()
	return true


func _make_tool() -> void:
	if tool != null and is_instance_valid(tool):
		tool.queue_free()
	tool = null
	match kind:
		"water": tool = Stations.watering_can()
		"fert": tool = Stations.fert_bottle()
		"cut": tool = Stations.shears()
		"seed":
			tool = Node3D.new()
			Models.sphere(tool, 0.012, Vector3.ZERO, Models.mat("6b5a3a", 0.6), Vector3(1.0, 0.7, 0.8), false, 6)
	if tool != null:
		add_child(tool)
		tool.top_level = true
		tool.scale = Vector3.ONE * 1.25
		tool.global_position = _hand()
	fx = _particles()
	fx2 = null


## punkt przy dolnej prawej krawędzi kadru, skąd narzędzie „wjeżdża” w pole widzenia
func _hand() -> Vector3:
	var cam: Camera3D = G.player.cam
	var b := cam.global_transform.basis
	return cam.global_position + b.x * 0.3 - b.y * 0.34 - b.z * 0.45


func _particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = false
	p.local_coords = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh: Mesh
	match kind:
		"water":
			var sm := SphereMesh.new()
			sm.radius = 0.008
			sm.height = 0.022
			sm.radial_segments = 5
			sm.rings = 3
			mesh = sm
			m.albedo_color = Color(0.72, 0.86, 1.0, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			p.amount = 90
			p.lifetime = 0.42
			p.spread = 7.0
			p.initial_velocity_min = 0.9
			p.initial_velocity_max = 1.2
			p.gravity = Vector3(0, -6.5, 0)
		"fert":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.008, 0.008, 0.008)
			mesh = bm
			m.albedo_color = Color(0.62, 0.82, 1.0)
			p.amount = 34
			p.lifetime = 0.5
			p.spread = 14.0
			p.initial_velocity_min = 0.25
			p.initial_velocity_max = 0.5
			p.gravity = Vector3(0, -5.0, 0)
		_:
			var qm := QuadMesh.new()
			qm.size = Vector2(0.05, 0.022)
			mesh = qm
			m.albedo_color = Color(0.3, 0.5, 0.2)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			p.amount = 26
			p.lifetime = 0.9
			p.one_shot = true
			p.explosiveness = 0.92
			p.spread = 70.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.3
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
			p.gravity = Vector3(0, -3.2, 0)
	mesh.surface_set_material(0, m)
	p.mesh = mesh
	add_child(p)
	p.top_level = true
	return p


func _process(dt: float) -> void:
	if not active:
		return
	t += dt
	var u := clampf(t / dur, 0.0, 1.0)
	# kamera sama ustawia się na doniczkę
	var P3 = G.player
	var k := smoothstep(0.0, 1.0, clampf(t / 0.35, 0.0, 1.0))
	P3.yaw = lerpf(from_yaw, to_yaw, k)
	P3.pitch = lerpf(from_pitch, to_pitch, k)
	P3.rotation = Vector3(0, P3.yaw, 0)
	P3.cam.rotation = Vector3(P3.pitch, 0, 0)
	var e_in := smoothstep(0.0, 1.0, clampf(t / 0.4, 0.0, 1.0))
	var e_out := smoothstep(0.0, 1.0, clampf((t - (dur - 0.35)) / 0.35, 0.0, 1.0))
	var face := atan2(side.x, side.z) - PI / 2.0
	match kind:
		"water": _anim_water(u, e_in, e_out, face)
		"fert": _anim_fert(u, e_in, e_out, face)
		"cut": _anim_cut(u, e_in, e_out, face)
		"seed": _anim_seed(u, e_in, e_out)
	if t >= dur:
		_end()


func _pose(work: Vector3, e_in: float, e_out: float) -> void:
	var hand := _hand()
	tool.global_position = hand.lerp(work, e_in).lerp(hand, e_out)


func _anim_water(u: float, e_in: float, e_out: float, face: float) -> void:
	var work := base + side * 0.36 + Vector3(0, 0.3 + h0 * 0.35, 0)
	_pose(work, e_in, e_out)
	var pour := smoothstep(0.14, 0.3, u) * (1.0 - smoothstep(0.8, 0.9, u))
	# oś −X konewki celuje w doniczkę; przechył wokół osi poprzecznej
	tool.global_rotation = Vector3(0, face, 0)
	tool.rotate_object_local(Vector3(0, 0, 1), pour * 0.62 + sin(t * 9.0) * 0.015 * pour)
	var spout := Stations._find(tool, "Spout") as Node3D
	fx.global_position = spout.global_position
	var dir := (base + Vector3(0, 0.05, 0) - spout.global_position).normalized()
	fx.direction = (dir + Vector3(0, 0.25, 0)).normalized()
	fx.emitting = pour > 0.6
	if pour > 0.6 and not applied:
		_apply()
		Sfx.care("water")
	# ziemia ciemnieje stopniowo, w miarę lania
	if applied:
		var n: Node3D = _pot_node()
		if n != null:
			var soil := Stations._find(n, "Soil") as MeshInstance3D
			if soil != null:
				var w := smoothstep(0.3, 0.85, u)
				(soil.material_override as StandardMaterial3D).albedo_color = Color("4a3828").lerp(Color("1e150e"), w)


func _anim_fert(u: float, e_in: float, e_out: float, face: float) -> void:
	var work := base + side * 0.2 + Vector3(0, 0.42 + h0 * 0.3, 0)
	_pose(work, e_in, e_out)
	var tip := smoothstep(0.14, 0.3, u) * (1.0 - smoothstep(0.82, 0.92, u))
	tool.global_rotation = Vector3(0, face, 0)
	# butelka do góry dnem nad doniczką, potrząsana
	tool.rotate_object_local(Vector3(0, 0, 1), tip * 2.3 + sin(t * 26.0) * 0.12 * tip)
	var mouth := Stations._find(tool, "Mouth") as Node3D
	fx.global_position = mouth.global_position
	fx.direction = Vector3(0, -1, 0)
	fx.emitting = tip > 0.8
	if tip > 0.8 and not applied:
		_apply()
		Sfx.care("shake")


func _anim_cut(u: float, e_in: float, e_out: float, face: float) -> void:
	# trzy cięcia coraz niżej; przy zbiorze krzak znika po kawałku
	var n_cuts := 3
	var seg := clampf((u - 0.16) / 0.66, 0.0, 0.999)
	var ci := int(seg * n_cuts)
	var cu := fmod(seg * n_cuts, 1.0)
	var hy := h0 * (0.8 - ci * 0.28) if cut_kind != "trim" else h0 * (0.3 + ci * 0.08)
	var work := base + side * 0.2 + Vector3(0, maxf(0.06, hy), 0)
	_pose(work, e_in, e_out)
	tool.global_rotation = Vector3(0, face + 0.2, 0.15)
	var open := 0.5 * (1.0 - smoothstep(0.35, 0.55, cu)) + 0.5 * smoothstep(0.75, 1.0, cu)
	if u < 0.16 or u > 0.84:
		open = 0.5
	(Stations._find(tool, "A") as Node3D).rotation.y = open * 0.5
	(Stations._find(tool, "B") as Node3D).rotation.y = -open * 0.5
	if u >= 0.16 and u <= 0.84 and cu > 0.5 and snips <= ci:
		snips = ci + 1
		Sfx.care("snip")
		fx.global_position = base + Vector3(0, maxf(0.06, hy), 0)
		fx.direction = Vector3(0, 1, 0)
		fx.restart()
		fx.emitting = true
		var n: Node3D = _pot_node()
		var pn: MeshInstance3D = n.get_node_or_null("Plant") if n != null else null
		if pn != null:
			if cut_kind == "trim":
				pn.scale = Vector3(h0 * lerpf(1.0, 0.88, snips / 3.0), h0, h0 * lerpf(1.0, 0.88, snips / 3.0))
			else:
				var left := maxf(0.02, 1.0 - snips / 3.0)
				pn.scale = Vector3(h0 * (0.6 + 0.4 * left), h0 * left, h0 * (0.6 + 0.4 * left))
		if snips >= n_cuts and not applied:
			_apply()


func _anim_seed(u: float, e_in: float, _e_out: float) -> void:
	# nasiono leci łukiem z ręki do ziemi, potem palec je wciska (ziemia lekko „siada”)
	var hand := _hand()
	var k := smoothstep(0.1, 0.55, u)
	var p := hand.lerp(base + Vector3(0, 0.01, 0), k)
	p.y += sin(k * PI) * 0.12
	tool.global_position = p
	tool.visible = u < 0.6 and e_in > 0.0
	if u >= 0.6 and not applied:
		_apply()
		Sfx.play("place", -6.0)
		fx.global_position = base
		fx.direction = Vector3(0, 1, 0)
		(fx.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(0.23, 0.16, 0.1)
		fx.amount = 12
		fx.restart()
		fx.emitting = true


func _pot_node() -> Node3D:
	var arr: Array = G.world.pot_nodes.get(room, []) if G.world != null else []
	return arr[idx] if idx >= 0 and idx < arr.size() and is_instance_valid(arr[idx]) else null


## skutek w grze (raz na animację)
func _apply() -> void:
	applied = true
	var P = G.Prod
	match kind:
		"seed": result = {"ok": P.plant_seed(room, idx)}
		"water": result = {"ok": P.plant_water(room, idx)}
		"fert": result = {"ok": P.plant_fert(room, idx)}
		"cut": result = P.plant_cut(room, idx)
	if G.world != null and kind != "cut":
		G.world.update_stations()


func _finish_msg() -> void:
	match kind:
		"seed":
			if result.get("ok", false):
				G.notify("Posadzone. Podlewaj i trzymaj pod lampą.", "good")
		"fert":
			if result.get("ok", false):
				G.notify("Nawóz wsypany: plon tego krzaka +25%.", "good")
		"cut":
			match String(result.get("kind", "")):
				"trim": G.notify("Przycięte: mniej liści, lepsze kwiaty (jakość +8).", "good")
				"harvest": G.notify("Ścięte: %s świeżego suszu (%d%%). Teraz do suszarki." % [G.grams(result.g), int(result.pur)], "good")
				"early":
					if float(result.get("g", 0.0)) > 0.0:
						G.notify("Ścięte przed czasem: tylko %s słabego suszu (%d%%)." % [G.grams(result.g), int(result.pur)], "warn")
					else:
						G.notify("Wyrwane. Z takiej rośliny nic nie będzie.", "warn")
	if G.world != null:
		G.world.update_stations()


func _end() -> void:
	active = false
	G.busy = false
	if not applied:
		_apply()
	if tool != null and is_instance_valid(tool):
		tool.queue_free()
	tool = null
	for p in [fx, fx2]:
		if p != null and is_instance_valid(p):
			p.emitting = false
			get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	fx = null
	_finish_msg()
