extends RefCounted

static func run(T) -> void:
	var W = G.world
	var M = G.main
	var P = G.player
	var goal: Vector2 = W.BACKYARD_AT * D.SC
	var origin: Vector2 = W.near_free(float(D.DOORS.garage.x), float(D.DOORS.garage.z) - 1.2)
	var path: PackedVector2Array = W.grid_path(origin, goal)
	var reachable: bool = not path.is_empty() and path[path.size()-1].distance_to(goal) < 1.0
	var previous: Vector2 = origin
	for point in path:
		reachable = reachable and W.grid_clear(previous, point)
		previous = point
	T.ok(reachable and not W.grid.is_point_solid(W._cell(goal.x, goal.y)), "z garażu istnieje przejście do zaplecza poza dawną granicą mapy")
	var connections := 0
	var graph_ok := true
	for node in W.wp:
		if not node.get("extension", false): continue
		for link in node.links:
			connections += 1
			graph_ok = graph_ok and W.grid_clear(Vector2(node.x, node.z), Vector2(W.wp[link].x, W.wp[link].z))
	T.ok(connections > 0 and graph_ok, "nowe połączenia nawigacji omijają fizyczne kolizje")
	var saved_pos: Vector3 = P.global_position
	var saved_loc: String = P.loc
	var saved_busy: bool = G.busy
	G.busy = false
	P.loc = "out"
	P.global_position = Vector3(goal.x, W.height(goal.x, goal.y), goal.y)
	P._physics_process(0.016)
	T.ok(absf(P.global_position.z - goal.y) < 0.02, "ruch gracza nie cofa go na starą granicę terenu")
	P.global_position = saved_pos
	P.loc = saved_loc
	G.busy = saved_busy
	var saved_track = G.S.track
	G.S.track = "backyards"
	T.ok(M.cur_target().id == "backyards", "telefon i kompas rozpoznają cel w nowej części mapy")
	G.S.track = "dealer_mati"
	T.ok(M.cur_target().id == "dealer_mati", "wybrana trasa dealera prowadzi do niego zamiast do celu fabularnego")
	G.S.track = saved_track
	T.ok(String(G.zone_at(goal.x, goal.y).get("id", "")) == "zaplecze", "nowy teren ma własną strefę lokalnej uwagi policji")

	var center: Vector2 = W.LAKE_CENTER * D.SC
	T.ok(W.lake_surface != null and W.water_depth(center.x, center.y) > 1.0, "jezioro ma powierzchnię wody i zagłębione dno")
	var gate := Vector2(83,193) * D.SC
	T.ok(W.water_depth(gate.x, gate.y) == 0.0 and not W.grid.is_point_solid(W._cell(gate.x, gate.y)), "jezioro nie zalewa ani nie blokuje furtki zaplecza")
	T.ok(W.grid.is_point_solid(W._cell(center.x, center.y)), "nawigacja nie prowadzi NPC przez głęboką wodę")
	G.busy = false
	P.loc = "out"
	P.global_position = Vector3(center.x, W.height(center.x, center.y), center.y)
	P._physics_process(0.016)
	T.ok(W.water_depth(P.global_position.x, P.global_position.z) < 0.01, "stara pozycja zapisu w miejscu nowego dna jest przenoszona na brzeg")
	P.global_position = saved_pos
	P.loc = saved_loc
	G.busy = saved_busy
	G.S.track = "lake"
	T.ok(M.cur_target().id == "lake", "jezioro można wybrać jako cel trasy w telefonie")
	G.S.track = saved_track
