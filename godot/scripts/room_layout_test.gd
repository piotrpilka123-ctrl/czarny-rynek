extends RefCounted
## Chodzenie po wnętrzach z przegrodami: przez każdy otwór drzwiowy i próg oraz w ściany działowe (bez okna).
## Trasa = lista punktów [x, z] względem środka pokoju; "ok" = gracz ma dojść do końca, "stop" = ma zatrzymać się przed ścianą.

static func walk(T, room: String, pts: Array) -> Vector3:
	var player = G.player
	var cx: float = D.ROOMS[room].cx
	player.loc = room
	player.velocity = Vector3.ZERO
	player.place(Vector3(cx + float(pts[0][0]), 0.0, float(pts[0][1])), 0.0)
	await player.get_tree().physics_frame
	await player.get_tree().physics_frame
	player.velocity = Vector3.ZERO
	if not player.fits_at(player.global_position, false):
		print("ROOM start w bryle: ", pts[0], " pos ", player.global_position)
	for k in range(1, pts.size()):
		var target := Vector3(cx + float(pts[k][0]), 0.0, float(pts[k][1]))
		for i in range(260):
			await player.get_tree().physics_frame
			var d: Vector3 = target - player.global_position
			d.y = 0.0
			if d.length() < 0.12:
				break
			if absf(player.global_position.x - cx) > 20.0:
				print("ROOM wyrzucony: leg ", k, " i=", i, " pos ", player.global_position, " loc ", player.loc, " main.loc ", G.player.loc)
				return player.global_position
			player.velocity = d.normalized() * 3.9
			player.walk_slide()
	return player.global_position


static func reach(T, room: String, label: String, pts: Array) -> void:
	var cx: float = D.ROOMS[room].cx
	var end: Array = pts[pts.size() - 1]
	var p: Vector3 = await walk(T, room, pts)
	var dist := Vector2(p.x - cx - float(end[0]), p.z - float(end[1])).length()
	T.ok(dist < 0.2 and is_zero_approx(p.y), "%s: gracz przechodzi trasę do końca (zostało %.2f m, y=%.3f, x=%.2f z=%.2f)" % [label, dist, p.y, p.x - cx, p.z])


## gracz idzie w ścianę: nie może się znaleźć po jej drugiej stronie (end_z/end_x = granica, której nie wolno przekroczyć)
static func blocked(T, room: String, label: String, from: Array, to: Array, axis: String, limit: float, below: bool) -> void:
	var cx: float = D.ROOMS[room].cx
	var p: Vector3 = await walk(T, room, [from, to])
	var v: float = (p.x - cx) if axis == "x" else p.z
	T.ok((v < limit) if below else (v > limit), "%s: ściana zatrzymuje gracza (%s=%.2f, granica %.2f)" % [label, axis, v, limit])


static func run(T) -> void:
	var player = G.player
	var saved_pos: Vector3 = player.global_position
	var saved_loc: String = player.loc
	var saved_yaw: float = player.yaw
	var was_physics: bool = player.is_physics_processing()
	player.set_physics_process(false)
	var r := "safe"
	# przedpokój → pokój → biurko
	await reach(T, r, "kawalerka: drzwi wejściowe → pokój", [[-0.6, 1.3], [0.0, 1.6], [0.0, 0.0], [0.9, -0.9]])
	# pokój → aneks kuchenny i z powrotem
	await reach(T, r, "kawalerka: pokój → kuchnia → pokój", [[1.0, -0.7], [1.9, -1.45], [2.7, -1.45], [1.0, -0.7]])
	# przedpokój → łazienka
	await reach(T, r, "kawalerka: przedpokój → łazienka", [[1.5, 1.9], [2.95, 2.0], [2.95, 0.9]])
	# przedpokój → salon (kanapa)
	await reach(T, r, "kawalerka: przedpokój → salon", [[-0.6, 1.5], [-1.6, 1.5], [-1.6, 0.4]])
	# pełny obchód: salon → pokój (obok przegrody) → przedpokój
	await reach(T, r, "kawalerka: salon → pokój → przedpokój", [[-2.4, 0.4], [-1.0, 0.2], [0.2, 0.2], [0.0, 1.5]])
	# ściany działowe naprawdę blokują
	await blocked(T, r, "kawalerka: ściana przedpokoju od pokoju", [1.5, 1.4], [1.5, -0.3], "z", 0.9, false)
	await blocked(T, r, "kawalerka: ściana kuchni od pokoju", [1.5, -0.6], [3.0, -0.6], "x", 2.1, true)
	await blocked(T, r, "kawalerka: ściana łazienki od kuchni", [2.5, -0.7], [2.5, 0.6], "z", -0.1, true)
	await blocked(T, r, "kawalerka: ściana łazienki od przedpokoju", [1.5, 1.2], [3.0, 1.2], "x", 2.2, true)
	# sklep u Stasia: sala → alejka → za ladą → zaplecze
	r = "shop"
	await reach(T, r, "sklep: drzwi → alejka → za ladą → zaplecze", [[0.0, 2.0], [0.3, 1.5], [-2.79, 1.5], [-2.79, 0.6], [-3.4, 0.0], [-3.4, -2.3], [2.2, -2.3], [3.3, -2.55]])
	await reach(T, r, "sklep: zaplecze → za ladą → sala", [[3.3, -2.55], [2.2, -2.3], [-3.4, -2.3], [-3.4, 0.0], [-2.79, 0.6], [0.3, 1.5], [0.0, 2.0]])
	await blocked(T, r, "sklep: ściana zaplecza od sali", [3.0, 0.5], [3.0, -0.3], "z", -0.55, false)
	await blocked(T, r, "sklep: regał w sali", [-1.6, 1.5], [-1.6, 0.0], "z", 1.1, false)
	await blocked(T, r, "sklep: lada", [0.0, 0.2], [0.0, -2.3], "z", -0.5, false)
	# garaż i piwnica: tylne pomieszczenia
	r = "garage"
	await reach(T, r, "garaż: brama → hala → tylne pomieszczenie", [[0.0, 3.0], [0.0, 0.0], [1.95, -1.4], [1.95, -3.4], [0.8, -3.4]])
	await blocked(T, r, "garaż: ściana tylnego pomieszczenia", [-1.5, -1.0], [-1.5, -3.0], "z", -2.0, false)
	r = "basement"
	await reach(T, r, "piwnica: wejście → komórka → przejście na drugą stronę", [[0.0, 4.0], [-2.7, 0.5], [-2.7, -1.0], [-2.7, -3.4], [1.8, -3.4], [1.8, -1.0]])
	await blocked(T, r, "piwnica: ściana komórki od środka", [-1.0, -1.0], [-1.0, -3.0], "z", -1.6, false)
	await blocked(T, r, "piwnica: ściana boczna komórki", [-1.0, -4.4], [1.5, -4.4], "x", 0.2, true)
	# laboratorium w hucie: magazyn chemii za ścianą z dwoma otworami
	r = "lab"
	await reach(T, r, "lab: hala → magazyn (otwór wschodni)", [[-1.5, -1.5], [-1.5, -4.0], [-3.6, -4.0]])
	await reach(T, r, "lab: hala → magazyn (otwór południowy)", [[-5.5, -1.5], [-5.5, -3.2]])
	await blocked(T, r, "lab: ściana magazynu", [-1.5, -3.0], [-4.0, -3.0], "x", -2.2, false)
	# rekwizyty w labie: żadne dwa obrysy się nie przenikają i żaden nie stoi w przejściu
	var RP = load("res://scripts/room_parts.gd")
	var names: Array = RP.LAB_FOOTPRINTS.keys()
	var bad := ""
	for i in range(names.size()):
		var a: Rect2 = RP.LAB_FOOTPRINTS[names[i]]
		for k in range(i + 1, names.size()):
			if a.grow(-0.01).intersects((RP.LAB_FOOTPRINTS[names[k]] as Rect2).grow(-0.01)):
				bad += "%s×%s " % [names[i], names[k]]
		for pn in RP.LAB_PASSAGES:
			if a.grow(-0.01).intersects(RP.LAB_PASSAGES[pn]):
				bad += "%s w przejściu %s " % [names[i], pn]
	T.ok(bad == "", "lab: rekwizyty się nie przenikają i nie stoją w przejściach (%s)" % bad)
	player.place(saved_pos, saved_yaw)
	player.loc = saved_loc
	player.set_physics_process(was_physics)
