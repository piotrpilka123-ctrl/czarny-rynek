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

	var shore_a: Vector2 = (W.LAKE_CENTER + Vector2(-1.1, -0.45) * W.LAKE_RADII) * D.SC
	var shore_b: Vector2 = (W.LAKE_CENTER + Vector2(1.1, -0.45) * W.LAKE_RADII) * D.SC
	T.ok(not W.grid_clear(shore_a, shore_b), "kontrola trasy jeziora obejmuje odcinek przecinający głęboką wodę")
	var walking: Array = M.nav.find(shore_a.x, shore_a.y, shore_b.x, shore_b.y)
	var dry_route := walking.size() > 1
	for i in range(walking.size()-1):
		for step in range(11):
			var point: Vector2 = (walking[i] as Vector2).lerp(walking[i+1], float(step)/10.0)
			dry_route = dry_route and W.water_depth(point.x, point.y) <= 0.4
	T.ok(dry_route, "trasa minimapy wokół jeziora nie ścina drogi przez głęboką wodę")

	var pass_before: bool = G.flag("gang_pass")
	var paid_before: float = G.S.paid
	var lvl_before: int = G.S.lvl
	var wanted_before: bool = G.S.wanted
	G.S.flags["gang_pass"] = false
	G.S.paid = 0.0
	G.S.lvl = 1
	G.S.wanted = false
	W.gang_sync(true)
	var entry := Vector2(-60,178)*D.SC
	var courtyard := Vector2(-60,207)*D.SC
	P.loc = "out"
	P.global_position = Vector3(-66*D.SC,W.height(-66*D.SC,179*D.SC),179*D.SC)
	T.ok(not W.gang_admit() and not G.flag("gang_pass"), "początkujący nie dostaje dostępu do osiedla gangu")
	T.ok(not W.grid_clear(entry,courtyard), "zamknięta brama fizycznie blokuje trasę do dziedzińca")
	var perimeter := true
	for point in [Vector2(-90,183),Vector2(-110,210),Vector2(-16,210),Vector2(-60,240)]:
		perimeter = perimeter and W.grid.is_point_solid(W._cell(point.x*D.SC,point.y*D.SC))
	T.ok(perimeter, "osiedle ma szczelny obwód z jednym wejściem")
	G.S.paid = 3500.0
	G.S.lvl = 7
	G.S.wanted = true
	T.ok(not W.gang_admit(), "gang nie wpuszcza gracza podczas pościgu")
	G.S.wanted = false
	P.global_position = saved_pos
	T.ok(not W.gang_admit(), "polecenie Wiktora wymaga osobistej rozmowy przy bramie")
	P.global_position = Vector3(-66*D.SC,W.height(-66*D.SC,179*D.SC),179*D.SC)
	T.ok(W.gang_admit() and G.flag("gang_pass"), "polecenie Wiktora i poziom odblokowują dostęp do osiedla")
	T.ok(W.grid_clear(entry,courtyard) and not W.gang_block.op, "otwarta brama odblokowuje siatkę i linię widzenia")
	T.ok(String(G.zone_at(courtyard.x,courtyard.y).get("id","")) == "black_court", "gang ma odrębną strefę terytorialną")
	G.S.track = "gang"
	T.ok(M.cur_target().id == "gang", "telefon prowadzi do strażnika przy bramie gangu")
	G.S.track = saved_track
	G.S.flags["gang_pass"] = pass_before
	G.S.paid = paid_before
	G.S.lvl = lvl_before
	G.S.wanted = wanted_before
	P.global_position = saved_pos
	P.loc = saved_loc
	W.gang_sync(true)


	# Naprawiony odcinek musi mieć kolizję, a istniejąca furtka zapewniać obejście.
	var closed_holes := [[Vector2(-66,-31.6),Vector2(-86,-31.6),true],[Vector2(37,-31.6),Vector2(23,-31.6),true],[Vector2(88,-31.6),Vector2(74,-31.6),true],[Vector2(-48.5,123),Vector2(-48.5,146),false],[Vector2(128.6,78),Vector2(128.6,104),false],[Vector2(128.6,-40),Vector2(128.6,-52),false],[Vector2(71,127),Vector2(92,127),true]]
	var repaired := true
	var detours := true
	var map_detours := true
	for entry_def in closed_holes:
		var middle: Vector2 = entry_def[0]*D.SC
		var across := Vector2.DOWN if entry_def[2] else Vector2.RIGHT
		repaired = repaired and W.grid.is_point_solid(W._cell(middle.x,middle.y))
		var gate_center: Vector2 = entry_def[1]*D.SC
		detours = detours and W.grid_clear(gate_center-across*1.5,gate_center+across*1.5)
		var from: Vector2 = W.near_free(middle.x-across.x*1.8,middle.y-across.y*1.8)
		var to: Vector2 = W.near_free(middle.x+across.x*1.8,middle.y+across.y*1.8)
		var around: PackedVector2Array = W.grid_path(from,to)
		var prev := from
		if around.is_empty(): detours = false
		for step in around:
			detours = detours and W.grid_clear(prev,step)
			prev = step
		detours = detours and prev.distance_to(to)<0.8
		var plotted: Array = M.nav.find(from.x,from.y,to.x,to.y)
		map_detours = map_detours and plotted.size()>1
		for i in range(plotted.size()-1):
			map_detours = map_detours and W.grid_clear(plotted[i],plotted[i+1])
	T.ok(repaired,"siedem nadmiarowych wyrw w płotach ma ponownie zamkniętą kolizję")
	T.ok(detours,"po zamknięciu wyrw nadal można przejść przez istniejące furtki i obejść płoty")

	T.ok(map_detours,"trasy telefonu omijają zamknięte wyrwy zamiast prowadzić przez naprawiony płot")
