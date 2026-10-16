extends Node
## Mieszkańcy wchodzą do klatek i z nich wychodzą: drzwi (skrzydło na zawiasie z details.gd) otwierają się przed człowiekiem
## i zamykają za nim, przy drzwiach zwalnia. Trzech lokatorów na zmianę; rzadziej nocą; tylko przy klatkach 14–70 m od gracza.

var npc
var folks: Array = []
var _t := 3.0 if OS.get_cmdline_user_args().has("--tenantsnow") else 8.0
var _near := OS.get_cmdline_user_args().has("--tenantsnow")   # tylko do zrzutów: klatka najbliżej gracza
var _snd := {}
var _angle := {}            # drzwi -> aktualny kąt (rad)
var _hold := {}             # drzwi -> sekundy do zamknięcia


func setup(n) -> void:
	npc = n


func _build() -> void:
	var rg := RandomNumberGenerator.new()
	rg.seed = 3131
	for k in range(3):
		var fem: bool = k == 1
		var st: Dictionary = npc._static({"x": 0.0, "z": 0.0, "rot": 0.0, "pose": "", "name": ["Lokator", "Lokatorka", "Sąsiad"][k], "hours": [0.0, 24.0],
			"look": {"model": (D.PEOPLE_F if fem else D.PEOPLE_M)[rg.randi() % 11], "female": fem, "seed": 700 + k},
			"lines": ["Dzień dobry.", "Spieszę się, przepraszam.", "Zimno dzisiaj."]})
		st["hide"] = true
		st["pose0"] = "tenant"
		st["tstate"] = "idle"
		st["tspot"] = -1
		folks.append(st)


func update(dt: float, pp: Vector3, outside: bool) -> void:
	var spots: Array = G.world.entrance_spots
	if spots.is_empty():
		return
	if folks.is_empty():
		_build()
	_animate_doors(dt, spots)
	if not outside:
		return
	_t -= dt
	for f in folks:
		_step(f, dt, spots)
	if _t > 0.0:
		return
	_t = randf_range(10.0, 25.0) * (2.5 if G.night > 0.4 else 1.0)
	for f in folks:
		if f.tstate != "idle":
			continue
		# klatka w zasięgu wzroku, ale nie tuż przy graczu
		var cand: Array = []
		for i in range(spots.size()):
			if spots[i].door == null:
				continue
			var d := Vector2(spots[i].p.x - pp.x, spots[i].p.z - pp.z).length()
			if d > 14.0 and d < 70.0:
				cand.append(i)
		if cand.is_empty():
			return
		var si: int = cand.pick_random()
		if _near:
			var bd := 1e9
			for ci in cand:
				var dd := Vector2(spots[ci].p.x - pp.x, spots[ci].p.z - pp.z).length()
				if dd < bd:
					bd = dd
					si = ci
		var sp: Dictionary = spots[si]
		var nrm := Vector3(sin(float(sp.rot)), 0.0, cos(float(sp.rot)))
		var tng := Vector3(cos(float(sp.rot)), 0.0, -sin(float(sp.rot)))
		f.tspot = si
		if randf() < 0.5:
			# wychodzi: staje w drzwiach, drzwi się otwierają, idzie chodnikiem
			f.tstate = "opening_out"
			f.tt = 0.0
			f.x = sp.p.x + nrm.x * 0.1
			f.z = sp.p.z + nrm.z * 0.1
			f.node.position = Vector3(f.x, npc._h(f.x, f.z), f.z)
			f.node.rotation.y = float(sp.rot)
			f.hide = true
		else:
			# wraca: zjawia się 9 m z boku, idzie do drzwi, zwalnia
			var side := 1.0 if randf() < 0.5 else -1.0
			f.x = sp.p.x + nrm.x * 3.0 + tng.x * side * 9.0
			f.z = sp.p.z + nrm.z * 3.0 + tng.z * side * 9.0
			f.node.position = Vector3(f.x, npc._h(f.x, f.z), f.z)
			f.hide = false
			f.goto_speed = 1.5
			f.goto = [Vector2(sp.p.x + nrm.x * 1.6, sp.p.z + nrm.z * 1.6)]
			f.arrive_hide = false
			f.pose_end = ""
			f.tstate = "approach"
		return


func _step(f: Dictionary, dt: float, spots: Array) -> void:
	if f.tstate == "idle":
		return
	var sp: Dictionary = spots[int(f.tspot)]
	var nrm := Vector3(sin(float(sp.rot)), 0.0, cos(float(sp.rot)))
	var tng := Vector3(cos(float(sp.rot)), 0.0, -sin(float(sp.rot)))
	var door: Node3D = sp.door
	match String(f.tstate):
		"opening_out":
			_hold[door] = 3.0
			f.tt = float(f.tt) + dt
			if float(f.tt) > 0.55:
				f.hide = false
				var side := 1.0 if randf() < 0.5 else -1.0
				f.goto_speed = 1.2
				f.goto = [Vector2(sp.p.x + nrm.x * 1.8, sp.p.z + nrm.z * 1.8), Vector2(sp.p.x + nrm.x * 3.2 + tng.x * side * 10.0, sp.p.z + nrm.z * 3.2 + tng.z * side * 10.0)]
				f.arrive_hide = true         # po dojściu znika z widoku (poszedł na zakupy)
				f.pose_end = ""
				f.tstate = "leaving"
		"leaving":
			if not f.has("goto"):
				f.tstate = "idle"
		"approach":
			if not f.has("goto"):
				# przed drzwiami: drzwi się otwierają, wchodzi powoli
				f.tstate = "entering"
				f.tt = 0.0
				_hold[door] = 3.0
		"entering":
			_hold[door] = 3.0
			f.tt = float(f.tt) + dt
			if float(f.tt) > 0.5 and not f.has("goto") and not bool(f.get("arrive_hide", false)):
				f.goto_speed = 0.8
				f.goto = [Vector2(sp.p.x + nrm.x * 0.2, sp.p.z + nrm.z * 0.2)]
				f.arrive_hide = true
			elif f.has("goto") == false and bool(f.get("arrive_hide", false)):
				f.tstate = "idle"


func _animate_doors(dt: float, spots: Array) -> void:
	for sp in spots:
		var door = sp.door
		if door == null or not is_instance_valid(door):
			continue
		var h: float = float(_hold.get(door, 0.0))
		var ang: float = float(_angle.get(door, 0.0))
		if h > 0.0:
			_hold[door] = h - dt
			if not bool(_snd.get(door, false)):
				_snd[door] = true
				if Vector2(G.player.global_position.x - sp.p.x, G.player.global_position.z - sp.p.z).length() < 22.0:
					Sfx.play("door")
		if h <= 0.0 and ang > -0.05:
			_snd[door] = false
		var want := -1.45 if h > 0.0 else 0.0
		if absf(ang - want) > 0.001:
			ang = lerpf(ang, want, minf(1.0, dt * 4.0))
			_angle[door] = ang
			door.rotation.y = ang
