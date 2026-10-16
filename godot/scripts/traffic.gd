extends Node
## Ruch uliczny w tle: cztery zwykłe auta jadą prawym pasem głównymi ulicami (po dwa w każdą stronę), skręcają kołami przednimi,
## hamują ze światłami stopu przed człowiekiem i przed autem z przodu, nocą zapalają reflektory (jedno światło na auto,
## tylko dla najbliższych). Poza zasięgiem 170 m stoją schowane, żeby nie kosztowały nic.

const Models = preload("res://scripts/models.gd")
const LANE := 1.05
const ROUTES := [
	[[-152.0, 20.0], [-106.0, 20.0], [-106.0, -130.0], [95.0, -130.0]],
	[[95.0, -130.0], [-106.0, -130.0], [-106.0, 20.0], [-152.0, 20.0]]]
const COLORS := ["8a2b2b", "2b4a7a", "c9c6bc", "3d3f44", "5a6a3a", "7a6a3a"]

var npc
var cars: Array = []


func setup(n) -> void:
	npc = n
	var rg := RandomNumberGenerator.new()
	rg.seed = 4711
	for k in range(4):
		var route: int = k % 2
		var node: Node3D = Models.car(["sedan", "hatch", "kombi", "hatch"][k], COLORS[rg.randi() % COLORS.size()])
		add_child(node)
		var head := SpotLight3D.new()
		head.position = Vector3(0.0, 0.7, 2.2)
		head.rotation = Vector3(-0.07, PI, 0.0)
		head.spot_range = 22.0
		head.spot_angle = 38.0
		head.spot_attenuation = 1.1
		head.light_color = Color(1.0, 0.95, 0.82)
		head.light_energy = 4.0
		head.shadow_enabled = false
		head.visible = false
		node.add_child(head)
		var c := {"node": node, "route": route, "seg": 0, "speed": 0.0, "head": head, "wheels": node.get_meta("wheels", []),
			"x": 0.0, "z": 0.0, "rot": 0.0, "start_t": float(k) * 22.0 + 6.0, "acc": 0.0, "steer": 0.0, "braking": false, "on_road": false}
		cars.append(c)
		node.visible = false


func _spawn(c: Dictionary) -> void:
	var r: Array = ROUTES[int(c.route)]
	var a := Vector2(r[0][0], r[0][1]) * D.SC
	var b := Vector2(r[1][0], r[1][1]) * D.SC
	var dirv := (b - a).normalized()
	var right := Vector2(-dirv.y, dirv.x)
	var p := a + right * LANE
	c.x = p.x
	c.z = p.y
	c.rot = atan2(dirv.x, dirv.y)
	c.seg = 0
	c.speed = 0.0
	c.on_road = true


func update(dt: float, pp: Vector3, outside: bool) -> void:
	for c in cars:
		var node: Node3D = c.node
		if not outside:
			node.visible = false
			continue
		if not c.on_road:
			c.start_t = float(c.start_t) - dt
			if float(c.start_t) > 0.0:
				continue
			_spawn(c)
			var far := Vector2(pp.x - c.x, pp.z - c.z).length()
			if far < 60.0:
				c.on_road = false
				c.start_t = 8.0          # gracz stoi przy początku trasy: spróbuj później
				continue
		var dist := Vector2(pp.x - c.x, pp.z - c.z).length()
		node.visible = dist < 170.0
		if not node.visible:
			continue
		_drive(c, dt, pp)
		var night: bool = G.night > 0.35
		if bool(c.get("lamps", false)) != night or not c.has("lamps"):
			Models.Cars.lamps_on(node, night)
			c["lamps"] = night
		(c.head as Light3D).visible = night and dist < 60.0


func _drive(c: Dictionary, dt: float, pp: Vector3) -> void:
	var r: Array = ROUTES[int(c.route)]
	var n := r.size()
	var i := int(c.seg)
	var a := Vector2(r[i][0], r[i][1]) * D.SC
	var b := Vector2(r[i + 1][0], r[i + 1][1]) * D.SC
	var seg_len := maxf(0.01, (b - a).length())
	var dirv := (b - a) / seg_len
	var right := Vector2(-dirv.y, dirv.x)
	var pos := Vector2(c.x, c.z)
	var done: float = (pos - a).dot(dirv)
	if seg_len - done < 2.4:
		c.seg = i + 1
		if int(c.seg) >= n - 1:
			c.on_road = false
			c.start_t = randf_range(18.0, 40.0)
			c.node.visible = false
			return
		return
	var aim: Vector2 = a + dirv * clampf(done + 5.5, 0.0, seg_len) + right * LANE
	var diff: float = npc._ang_diff(atan2(aim.x - pos.x, aim.y - pos.y), float(c.rot))
	var fwd := Vector2(sin(float(c.rot)), cos(float(c.rot)))
	var vmax := 7.0 * clampf(1.0 - absf(diff) * 0.9, 0.35, 1.0)
	vmax = minf(vmax, 2.4 + (seg_len - done) * 0.5)
	# przeszkody przed maską: gracz, przechodnie, inne auta
	var blockers: Array = [Vector2(pp.x, pp.z)]
	for p in npc.citizens:
		if p.node.visible:
			blockers.append(Vector2(p.x, p.z))
	for o in cars:
		if o != c and o.node.visible:
			blockers.append(Vector2(o.x, o.z))
	for bl in blockers:
		var to: Vector2 = bl - pos
		var d := to.length()
		if d < 8.5 and d > 0.1 and to.normalized().dot(fwd) > 0.85:
			vmax = 0.0
			break
	var sp := float(c.speed)
	var newsp := move_toward(sp, vmax, dt * (2.4 if vmax > sp else 6.0))
	c.rot = float(c.rot) + clampf(diff * 2.4, -1.1, 1.1) * clampf(absf(newsp) / 4.0, 0.12, 1.0) * dt
	c.speed = newsp
	c.acc = lerpf(float(c.acc), (newsp - sp) / maxf(dt, 0.001), minf(1.0, dt * 6.0))
	c.x += sin(float(c.rot)) * newsp * dt
	c.z += cos(float(c.rot)) * newsp * dt
	var node: Node3D = c.node
	var fx := sin(float(c.rot))
	var fz := cos(float(c.rot))
	var yf: float = npc._h(c.x + fx * 1.3, c.z + fz * 1.3)
	var yb: float = npc._h(c.x - fx * 1.3, c.z - fz * 1.3)
	var yl: float = npc._h(c.x + fz * 0.75, c.z - fx * 0.75)
	var yr: float = npc._h(c.x - fz * 0.75, c.z + fx * 0.75)
	node.position = Vector3(c.x, (yf + yb) * 0.5, c.z)
	node.rotation = Vector3(-atan2(yf - yb, 2.6) + clampf(-float(c.acc) * 0.006, -0.05, 0.05) * clampf(absf(newsp) / 3.0, 0.0, 1.0), float(c.rot), atan2(yr - yl, 1.5) * 0.6)
	var steer_t := clampf(clampf(diff * 2.4, -1.1, 1.1) * 0.5, -0.5, 0.5)
	c.steer = lerpf(float(c.steer), steer_t, minf(1.0, dt * 8.0))
	for w in c.wheels:
		var wn := w as Node3D
		if not wn.has_meta("b0"):
			wn.set_meta("b0", wn.basis)
			wn.set_meta("spin", 0.0)
		var spin := float(wn.get_meta("spin")) + newsp * dt / 0.31
		wn.set_meta("spin", spin)
		var sb := Basis(Vector3.UP, float(c.steer)) if wn.position.z > 0.0 else Basis.IDENTITY
		wn.basis = sb * (wn.get_meta("b0") as Basis) * Basis(Vector3.UP, spin)
	var braking: bool = float(c.acc) < -0.8 or (vmax <= 0.01 and newsp < 0.3)
	if braking != bool(c.braking):
		c.braking = braking
		Models.Cars.brake_lamps(node, braking)
