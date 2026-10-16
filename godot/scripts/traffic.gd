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
# autobus linii 12: stoi na pętli, co kilka minut jedzie na przystanek, stoi 11 s (ludzie wsiadają i wysiadają), objeżdża wysepkę i wraca
const BUS_PATH := [[9.0, 161.2], [13.5, 158.0], [13.5, 146.0], [-13.5, 146.0], [-13.5, 158.0], [-8.0, 161.2], [-2.5, 161.2]]
var bus: Node3D = null
var bus_state := "depot"
var bus_t := 40.0
var bus_i := 0
var bus_speed := 0.0
var bus_x := 0.0
var bus_z := 0.0
var bus_rot := PI / 2.0


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
	_bus(dt, pp, outside)
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


func _bus(dt: float, pp: Vector3, outside: bool) -> void:
	if bus == null:
		if G.world.bus_node == null:
			return
		bus = G.world.bus_node
		var gp := bus.global_position
		var gr := bus.global_rotation.y
		bus.reparent(self, true)
		if OS.get_cmdline_user_args().has("--busnow"):
			bus_t = 2.0      # tylko do zrzutów
		bus_x = gp.x
		bus_z = gp.z
		bus_rot = gr
	if not outside:
		return
	var people: Dictionary = npc.bus_people
	var door := Vector2(9.0 + 1.2, 162.95) * D.SC
	match bus_state:
		"depot":
			bus_t -= dt
			if bus_t <= 0.0 and Vector2(pp.x - bus_x, pp.z - bus_z).length() > 14.0:
				bus_state = "go"
				bus_i = 0
				if people.has("driver"):
					people.driver["hide"] = true
		"dwell":
			bus_t -= dt
			if bus_t > 9.5 and not bus.has_meta("opened"):
				bus.set_meta("opened", true)
				if people.has("boarder"):
					var b: Dictionary = people.boarder
					b["goto"] = [door]
					b["goto_speed"] = 1.6
					b["arrive_hide"] = true
					b["pose_end"] = ""
				var k := 0
				for a in people.get("alight", []):
					a["hide"] = false
					a["x"] = door.x + 0.2 * k
					a["z"] = door.y
					a.node.position = Vector3(a.x, npc._h(a.x, a.z), a.z)
					a["goto"] = [Vector2(door.x + 1.8 + 1.1 * k, door.y + 2.6), Vector2(door.x + 5.0 + 2.0 * k, door.y + 3.4)]
					a["goto_speed"] = 1.5
					a["arrive_hide"] = true      # po dojściu do końca chodnika znikają z widoku (poszli do domu)
					a["pose_end"] = ""
					k += 1
			if bus_t <= 0.0:
				bus.remove_meta("opened")
				bus_state = "go"
				bus_i += 1
		"go":
			_bus_drive(dt, pp)
	bus.global_position = Vector3(bus_x, npc._h(bus_x, bus_z), bus_z)
	bus.rotation.y = bus_rot


func _bus_drive(dt: float, pp: Vector3) -> void:
	var tgt := Vector2(BUS_PATH[bus_i][0], BUS_PATH[bus_i][1]) * D.SC
	var pos := Vector2(bus_x, bus_z)
	var to := tgt - pos
	var dist := to.length()
	var last: bool = bus_i == BUS_PATH.size() - 1
	var stop_here: bool = bus_i == 0 or last
	if dist < (0.6 if stop_here else 3.0):
		if bus_i == 0:
			bus_state = "dwell"
			bus_t = 11.0
			bus_speed = 0.0
			return
		if last:
			bus_state = "depot"
			bus_t = randf_range(90.0, 150.0)
			bus_speed = 0.0
			bus_rot = PI / 2.0
			var people: Dictionary = npc.bus_people
			if people.has("driver"):
				people.driver["hide"] = false
			# pasażer znów czeka na przystanku
			if people.has("boarder"):
				var b: Dictionary = people.boarder
				b["hide"] = false
				b["arrive_hide"] = false
				b["x"] = 11.6 * D.SC
				b["z"] = 164.55 * D.SC
				b.node.position = Vector3(b.x, npc._h(b.x, b.z), b.z)
				b["pose"] = "phone"
			return
		bus_i += 1
		return
	var aim := pos + to.normalized() * minf(dist, 6.0)
	var want: float = atan2(aim.x - pos.x, aim.y - pos.y)
	var diff: float = npc._ang_diff(want, bus_rot)
	var vmax := 3.4 * clampf(1.0 - absf(diff) * 0.7, 0.35, 1.0)
	if stop_here:
		vmax = minf(vmax, 0.5 + dist * 0.6)
	var fwd := Vector2(sin(bus_rot), cos(bus_rot))
	var to_p := Vector2(pp.x, pp.z) - pos
	if to_p.length() < 9.0 and to_p.normalized().dot(fwd) > 0.8:
		vmax = 0.0
	bus_speed = move_toward(bus_speed, vmax, dt * (1.2 if vmax > bus_speed else 3.0))
	bus_rot += clampf(diff * 1.6, -0.6, 0.6) * clampf(bus_speed / 2.5, 0.0, 1.0) * dt
	bus_x += sin(bus_rot) * bus_speed * dt
	bus_z += cos(bus_rot) * bus_speed * dt
