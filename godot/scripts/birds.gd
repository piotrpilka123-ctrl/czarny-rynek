extends Node
## Gołębie na chodnikach przed klatkami: dziobią, drepczą, a gdy gracz podejdzie albo podbiegnie, zrywają się do lotu
## (machają skrzydłami, wznoszą się łukiem i siadają kilkanaście metrów dalej, po czasie wracają). Proste węzły bez szkieletu,
## tylko w dzień i do 70 m od gracza.

const SPOOK := 3.2           # szybki krok / stanie: spłoszenie z tej odległości
const SPOOK_RUN := 7.5       # bieg płoszy z dalszej odległości

var npc
var birds: Array = []
var crows: Array = []
var cats: Array = []
var _cat_spawn := 20.0 if not OS.get_cmdline_user_args().has("--catnow") else 0.3   # --catnow: tylko do zrzutów
var _cat_near := OS.get_cmdline_user_args().has("--catnow")


var _built := false
var _off := OS.get_cmdline_user_args().has("--nobirds")   # przełącznik do pomiarów wydajności


func setup(n) -> void:
	npc = n


## wejścia do klatek powstają razem ze światem, więc ptaki stawiamy przy pierwszej klatce gry
func _build() -> void:
	_built = true
	_build_crows()
	var spots: Array = G.world.entrance_spots
	if spots.is_empty():
		return
	var rg := RandomNumberGenerator.new()
	rg.seed = 2024
	var step := maxi(1, int(spots.size() / 5))
	var ps: PackedScene = load("res://assets/models/golab.glb")
	if ps == null:
		return
	var gi := 0
	while gi < spots.size() and birds.size() < 18:
		var sp: Dictionary = spots[gi]
		gi += step
		var rot: float = sp.rot
		var nrm := Vector3(sin(rot), 0.0, cos(rot))
		var home: Vector3 = sp.p + nrm * 2.4
		for k in range(rg.randi_range(3, 5)):
			var node: Node3D = ps.instantiate()
			add_child(node)
			node.scale = Vector3.ONE * rg.randf_range(0.95, 1.1)
			var off := Vector3(rg.randf_range(-1.4, 1.4), 0.0, rg.randf_range(-1.0, 1.0))
			var pos := home + off
			var b := {"node": node, "x": pos.x, "z": pos.z, "home": Vector2(home.x, home.z), "yaw": rg.randf() * TAU, "state": "peck",
				"t": rg.randf_range(0.2, 2.0), "head": node.find_child("Glowa", true, false), "wl": node.find_child("SkrzydloL", true, false),
				"wr": node.find_child("SkrzydloP", true, false), "air": 0.0, "from": Vector2.ZERO, "to": Vector2.ZERO, "h": 0.0, "bob": rg.randf() * 6.0,
				"back_t": 0.0, "dest": Vector2(pos.x, pos.z)}
			node.position = Vector3(pos.x, npc._h(pos.x, pos.z), pos.z)
			node.rotation.y = b.yaw
			node.visible = false
			_no_shadow(node)
			b["gy"] = npc._h(pos.x, pos.z)
			birds.append(b)


func update(dt: float, pp: Vector3, outside: bool) -> void:
	if _off:
		return
	_update_crows(dt, pp, outside)
	_update_cats(dt, pp, outside)
	if not _built and not G.world.entrance_spots.is_empty():
		_build()
	var day: bool = G.night < 0.5
	for b in birds:
		var node: Node3D = b.node
		var dist := Vector2(pp.x - b.x, pp.z - b.z).length()
		if not outside or not day or dist > 70.0:
			node.visible = false
			if b.state == "air":
				b.state = "peck"
			continue
		node.visible = true
		var running: bool = G.player != null and G.player.moving and G.player.sprinting
		match String(b.state):
			"peck":
				b.t = float(b.t) - dt
				b.bob = float(b.bob) + dt * 9.0
				# głowa w dół i w górę (dziobanie), co chwilę krok albo kilka drobnych kroków w nowe miejsce
				if b.head != null:
					var dip: float = maxf(0.0, sin(float(b.bob))) * 0.9 if float(b.t) > 0.0 else 0.0
					(b.head as Node3D).rotation.x = lerpf((b.head as Node3D).rotation.x, -dip, minf(1.0, dt * 14.0))
				if float(b.t) <= 0.0:
					var home: Vector2 = b.home
					var tgt := home + Vector2(randf_range(-1.6, 1.6), randf_range(-1.2, 1.2))
					b.dest = tgt
					b.state = "walk"
					b.t = randf_range(0.5, 1.1)
				if dist < (SPOOK_RUN if running else SPOOK):
					_flee(b, pp)
			"walk":
				b.t = float(b.t) - dt
				var d: Vector2 = (b.dest as Vector2) - Vector2(b.x, b.z)
				if d.length() > 0.05:
					var stp: Vector2 = d.normalized() * minf(d.length(), 0.9 * dt)
					b.x += stp.x
					b.z += stp.y
					b.yaw = lerp_angle(float(b.yaw), atan2(d.x, d.y), minf(1.0, dt * 10.0))
					b.bob = float(b.bob) + dt * 16.0
					if b.head != null:
						(b.head as Node3D).rotation.x = sin(float(b.bob)) * 0.18
				if float(b.t) <= 0.0 or d.length() <= 0.05:
					b.state = "peck"
					b.t = randf_range(1.0, 3.2)
				if dist < (SPOOK_RUN if running else SPOOK):
					_flee(b, pp)
			"air":
				b.air = float(b.air) + dt
				var k := clampf(float(b.air) / 2.4, 0.0, 1.0)
				var from: Vector2 = b.from
				var to: Vector2 = b.to
				var p := from.lerp(to, smoothstep(0.0, 1.0, k))
				b.x = p.x
				b.z = p.y
				var ground: float = float(b.gy) if float(b.air) < 0.1 else npc._h(p.x, p.y) if int(float(b.air) * 20.0) % 4 == 0 else float(b.get("gy_air", b.gy))
				b.gy_air = ground
				node.position = Vector3(p.x, ground + sin(k * PI) * float(b.h) + (1.0 - k) * 0.0, p.y)
				node.rotation = Vector3(-0.25 * sin(k * PI), float(b.yaw), 0.0)
				var flap := sin(float(b.air) * 62.0)
				if b.wl != null:
					(b.wl as Node3D).rotation.z = 0.3 + flap * 0.9
					(b.wr as Node3D).rotation.z = -0.3 - flap * 0.9
				if k >= 1.0:
					b.state = "peck"
					b.t = randf_range(1.0, 3.0)
					b.home = Vector2(b.x, b.z) if randf() < 0.5 else b.home
					if b.wl != null:
						(b.wl as Node3D).rotation.z = 0.0
						(b.wr as Node3D).rotation.z = 0.0
		if b.state != "air":
			if b.state == "walk":
				b.gy = npc._h(b.x, b.z)      # wysokość terenu liczymy tylko ptakom, które się ruszają
			node.position = Vector3(b.x, float(b.gy), b.z)
			node.rotation = Vector3(0.0, float(b.yaw), 0.0)


func _flee(b: Dictionary, pp: Vector3) -> void:
	var away := Vector2(b.x - pp.x, b.z - pp.z)
	if away.length() < 0.01:
		away = Vector2(1.0, 0.0)
	away = away.normalized().rotated(randf_range(-0.7, 0.7))
	b.from = Vector2(b.x, b.z)
	b.to = Vector2(b.x, b.z) + away * randf_range(9.0, 14.0)
	b.h = randf_range(3.5, 7.0)
	b.air = 0.0
	b.yaw = atan2(away.x, away.y)
	b.state = "air"
	b.home = b.to


func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


# ---------------------------------------------------------------- wrony na latarniach
func _build_crows() -> void:
	var ps: PackedScene = load("res://assets/models/golab.glb")
	if ps == null or G.world.lamp_list.is_empty():
		return
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.17, 0.18, 0.2)
	dark.roughness = 0.7
	var lamps: Array = G.world.lamp_list
	var step := maxi(1, int(lamps.size() / 7))
	var i := 0
	while i < lamps.size() and crows.size() < 7:
		var node: Node3D = ps.instantiate()
		add_child(node)
		node.scale = Vector3.ONE * 1.45
		for m in node.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = dark
		_no_shadow(node)
		node.visible = false
		crows.append({"node": node, "lamp": i, "state": "perch", "t": randf_range(8.0, 50.0), "air": 0.0, "dur": 2.0, "from": Vector3.ZERO, "to": Vector3.ZERO,
			"head": node.find_child("Glowa", true, false), "wl": node.find_child("SkrzydloL", true, false), "wr": node.find_child("SkrzydloP", true, false),
			"yaw": 0.0, "look_t": randf_range(2.0, 6.0), "pos": Vector3.ZERO})
		_perch(crows[crows.size() - 1], i)
		i += step


func _lamp_seat(idx: int) -> Vector3:
	var l: Dictionary = G.world.lamp_list[idx]
	var x: float = float(l.x) * D.SC
	var z: float = float(l.z) * D.SC
	var ry: float = float(l.ry)
	return Vector3(x + sin(ry) * 0.9, npc._h(x, z) + 7.35, z + cos(ry) * 0.9)


func _perch(c: Dictionary, idx: int) -> void:
	c.lamp = idx
	c.pos = _lamp_seat(idx)
	c.state = "perch"
	c.t = randf_range(25.0, 70.0)
	c.yaw = float(G.world.lamp_list[idx].ry) + PI * 0.5 * (1.0 if randf() < 0.5 else -1.0)


func _update_crows(dt: float, pp: Vector3, outside: bool) -> void:
	var day: bool = G.night < 0.55
	for c in crows:
		var node: Node3D = c.node
		var cp: Vector3 = c.pos
		var dist := Vector2(pp.x - cp.x, pp.z - cp.z).length()
		if not outside or not day or dist > 90.0:
			node.visible = false
			continue
		node.visible = true
		if c.state == "perch":
			c.t = float(c.t) - dt
			c.look_t = float(c.look_t) - dt
			if float(c.look_t) <= 0.0:
				c.look_t = randf_range(2.0, 7.0)
				c.yaw = float(c.yaw) + randf_range(-0.9, 0.9)
			node.position = cp
			node.rotation = Vector3(0.0, lerp_angle(node.rotation.y, float(c.yaw), minf(1.0, dt * 6.0)), 0.0)
			if c.head != null:
				(c.head as Node3D).rotation.x = sin(G.now * 1.7 + cp.x) * 0.12
			if float(c.t) <= 0.0 or dist < 9.0 and G.player != null and G.player.moving:
				var pick: int = randi() % G.world.lamp_list.size()
				var to := _lamp_seat(pick)
				if Vector2(to.x - cp.x, to.z - cp.z).length() < 6.0:
					c.t = 6.0
					continue
				c.from = cp
				c.to = to
				c.dur = clampf(Vector2(to.x - cp.x, to.z - cp.z).length() / 7.0, 1.5, 6.0)
				c.air = 0.0
				c.state = "air"
				c.lamp = pick
		else:
			c.air = float(c.air) + dt
			var k := clampf(float(c.air) / float(c.dur), 0.0, 1.0)
			var from: Vector3 = c.from
			var to: Vector3 = c.to
			var p := from.lerp(to, smoothstep(0.0, 1.0, k))
			p.y += sin(k * PI) * 2.2
			node.position = p
			var dv := Vector2(to.x - from.x, to.z - from.z)
			node.rotation = Vector3(-0.2 * sin(k * PI), atan2(dv.x, dv.y), 0.0)
			var flap := sin(float(c.air) * 38.0)
			if c.wl != null:
				(c.wl as Node3D).rotation.z = 0.3 + flap * 0.9
				(c.wr as Node3D).rotation.z = -0.3 - flap * 0.9
			if k >= 1.0:
				if c.wl != null:
					(c.wl as Node3D).rotation.z = 0.0
					(c.wr as Node3D).rotation.z = 0.0
				_perch(c, int(c.lamp))


# ---------------------------------------------------------------- koty
func _update_cats(dt: float, pp: Vector3, outside: bool) -> void:
	var night: bool = G.night > 0.4 or _cat_near
	if cats.is_empty():
		var ps: PackedScene = load("res://assets/models/kot.glb")
		if ps == null:
			return
		for col in [Color(0.34, 0.32, 0.3), Color(0.58, 0.36, 0.17)]:
			var node: Node3D = ps.instantiate()
			add_child(node)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mat.roughness = 0.9
			for m in node.find_children("*", "MeshInstance3D", true, false):
				var nm := String((m as MeshInstance3D).name)
				if not nm.begins_with("Glowa") or true:
					(m as MeshInstance3D).material_override = mat
			_no_shadow(node)
			node.visible = false
			cats.append({"node": node, "active": false, "x": 0.0, "z": 0.0, "wi": 0, "pi": -1, "tx": 0.0, "tz": 0.0, "state": "walk", "t": 0.0, "ph": 0.0, "yaw": 0.0,
				"legs": [node.find_child("LapaFL", true, false), node.find_child("LapaFR", true, false), node.find_child("LapaBL", true, false), node.find_child("LapaBR", true, false)],
				"tail": node.find_child("Ogon", true, false), "flee": 0.0})
	_cat_spawn -= dt
	for c in cats:
		var node: Node3D = c.node
		if not outside or not night:
			node.visible = false
			c.active = false
			continue
		if not c.active:
			if _cat_spawn > 0.0:
				continue
			_cat_spawn = randf_range(15.0, 40.0)
			var wps: Array = G.world.wp
			for tries in range(200):
				var wi: int = randi() % wps.size()
				var d: float = Vector2(wps[wi].x - pp.x, wps[wi].z - pp.z).length()
				if d > (7.0 if _cat_near else 18.0) and d < (22.0 if _cat_near else 55.0) and not wps[wi].links.is_empty():
					c.active = true
					c.wi = wi
					c.pi = -1
					c.x = wps[wi].x
					c.z = wps[wi].z
					c.tx = c.x
					c.tz = c.z
					c.state = "walk"
					if _cat_near:
						var fw: Vector2 = G.player.forward()      # zrzuty: kot 5 m przed graczem
						c.x = pp.x + fw.x * 5.0
						c.z = pp.z + fw.y * 5.0
						c.tx = c.x + fw.y * 6.0
						c.tz = c.z - fw.x * 6.0
					break
			if not c.active:
				continue
		var dist := Vector2(pp.x - c.x, pp.z - c.z).length()
		if dist > 85.0:
			c.active = false
			node.visible = false
			continue
		node.visible = true
		var wps2: Array = G.world.wp
		if c.state != "flee" and dist < 4.5:
			c.state = "flee"
			c.flee = 3.0
			c.t = 0.0
			_cat_next(c, wps2, pp, true)
		var sp := 0.0
		if c.state == "sit":
			c.t = float(c.t) - dt
			if float(c.t) <= 0.0:
				c.state = "walk"
				_cat_next(c, wps2, pp, false)
		else:
			sp = 4.8 if c.state == "flee" else 1.3
			var to := Vector2(c.tx - c.x, c.tz - c.z)
			var dl := to.length()
			if dl < 0.3:
				if c.state == "flee":
					c.flee = float(c.flee) - 0.5
					if float(c.flee) <= 0.0:
						c.state = "walk"
				elif randf() < 0.3:
					c.state = "sit"
					c.t = randf_range(3.0, 7.0)
					sp = 0.0
				if c.state != "sit":
					_cat_next(c, wps2, pp, c.state == "flee")
			else:
				var stp: Vector2 = to.normalized() * minf(dl, sp * dt)
				c.x += stp.x
				c.z += stp.y
				c.yaw = lerp_angle(float(c.yaw), atan2(to.x, to.y), minf(1.0, dt * 9.0))
		c.ph = float(c.ph) + dt * (sp * 6.0)
		var amp := 0.55 if sp < 2.0 else 0.95
		var legs: Array = c.legs
		for li in range(legs.size()):
			if legs[li] != null:
				(legs[li] as Node3D).rotation.x = (sin(float(c.ph) + (PI if li == 1 or li == 2 else 0.0)) * amp) if sp > 0.0 else 0.0
		if c.tail != null:
			(c.tail as Node3D).rotation.z = sin(G.now * (3.0 if c.state == "sit" else 1.4)) * (0.5 if c.state == "sit" else 0.2)
		node.position = Vector3(c.x, npc._h(c.x, c.z), c.z)
		node.rotation = Vector3(-0.25 if c.state == "sit" else 0.0, float(c.yaw), 0.0)


func _cat_next(c: Dictionary, wps: Array, pp: Vector3, away: bool) -> void:
	var cur: Dictionary = wps[int(c.wi)]
	var best := -1
	var best_score := -1e9
	for l in cur.links:
		var sc := randf()
		if int(l) == int(c.pi) and cur.links.size() > 1:
			sc -= 0.8
		if away:
			sc += Vector2(wps[l].x - pp.x, wps[l].z - pp.z).length() * 0.2
		if sc > best_score:
			best_score = sc
			best = int(l)
	if best < 0:
		return
	c.pi = c.wi
	c.wi = best
	c.tx = wps[best].x
	c.tz = wps[best].z
