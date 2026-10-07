extends RefCounted
## Testy skradania: widoczność gracza, wzrok i słuch patroli, zauważanie w czasie, odciąganie,
## przeczesywanie okolicy po zgubieniu tropu, kryjówki. Wołane z selftest.gd (T = węzeł testu).

const SC := 0.56
# środek jezdni ul. Hutniczej: pod latarnią i w połowie drogi między latarniami
const LIT := Vector2(-54.0 * SC, 20.0 * SC)
const DARK := Vector2(-37.0 * SC, 20.0 * SC)


static func _put(P, at: Vector2, crouch := false, moving := false, sprint := false) -> void:
	P.global_position = Vector3(at.x, G.world.height(at.x, at.y), at.y)
	P.hidden = false
	P.crouching = crouch
	P.moving = moving
	P.sprinting = sprint
	P.velocity = Vector3(3.0, 0, 0) if moving else Vector3.ZERO
	P.flash.light_energy = 0.0


static func _cop_at(c: Dictionary, at: Vector2, look_at: Vector2) -> void:
	c.x = at.x
	c.z = at.y
	# stoi w miejscu i patrzy w jedną stronę (patrol na „przerwie”)
	c.post = false
	c.state = "patrol"
	c.idle = 9999.0
	c.lvl = 0.0
	c.susp = 0.0
	c.notice = 0.0
	c.sees = false
	c.hear_t = 0.0
	c.inv = null
	c.lure = false
	c.hunt = false
	c.know = false
	c.look_t = 0.0
	c.node.rotation.y = atan2(look_at.x - at.x, look_at.y - at.y)
	c.node.position = Vector3(at.x, G.world.height(at.x, at.y), at.y)


static func _ticks(N, pp: Vector3, n: int, step := 0.2) -> void:
	for i in range(n):
		G.now += step
		N._update_cops(step, pp, true)


static func run(T) -> void:
	var M = G.main
	var N = G.npcs
	var P = G.player
	var W = G.world
	var S: Dictionary = G.S
	var back_loc: String = P.loc
	G.strict_stealth = true
	var back_pos: Vector3 = P.global_position
	var back_yaw: float = P.yaw
	M.teleport("out", Vector3(DARK.x, 0.0, DARK.y), 0.0)
	await T.frames(3)
	while N.cops.size() < 2:
		N.spawn_cop(false)
	var c: Dictionary = N.cops[0]
	# pozostałe patrole daleko, żeby nie mieszały
	for i in range(1, N.cops.size()):
		_cop_at(N.cops[i], Vector2(96.0 + i * 3.0, 84.0), Vector2(300.0, 84.0))
	var keep_wanted: bool = S.wanted
	var keep_heat: float = S.heat
	var keep_invest: float = S.invest
	var keep_inv: Dictionary = S.inv
	S.inv = G.new_store()
	S.wanted = false
	N.susp_mult = 0.0

	# ---------------------------------------------------------------- światło i widoczność
	T.ok(W.light_at(LIT.x, LIT.y) > 0.6 and W.light_at(DARK.x, DARK.y) < 0.12, "latarnie: pod lampą jasno (%.2f), między lampami ciemno (%.2f)" % [W.light_at(LIT.x, LIT.y), W.light_at(DARK.x, DARK.y)])
	G.rain = 0.0
	G.night = 0.0
	_put(P, DARK)
	var v_day: float = P.visibility()
	_put(P, DARK, true)
	var v_day_crouch: float = P.visibility()
	_put(P, DARK, false, true, true)
	var v_day_sprint: float = P.visibility()
	T.ok(v_day_crouch < v_day * 0.75 and v_day_sprint > v_day * 1.2, "widoczność w dzień: kucanie %.2f < stanie %.2f < bieg %.2f" % [v_day_crouch, v_day, v_day_sprint])
	G.night = 1.0
	_put(P, DARK)
	var v_dark: float = P.visibility()
	_put(P, LIT)
	var v_lit: float = P.visibility()
	T.ok(v_dark < v_day * 0.62 and v_lit > v_dark * 1.5, "noc: w cieniu %.2f, pod latarnią %.2f (dzień %.2f)" % [v_dark, v_lit, v_day])
	_put(P, DARK)
	P.flash.light_energy = 5.0
	var v_flash: float = P.visibility()
	P.flash.light_energy = 0.0
	T.ok(absf(v_flash - v_dark) < 0.001, "włączona latarka gracza nie zmienia tego, jak łatwo go zauważyć (%.2f i %.2f)" % [v_flash, v_dark])
	G.rain = 1.0
	_put(P, DARK)
	T.ok(P.visibility() < v_dark, "deszcz dodatkowo zasłania")
	G.rain = 0.0
	if not W.covers.is_empty():
		var cv: Vector3 = W.covers[0]
		var by := Vector2(cv.x + cv.z + 0.4, cv.y)
		G.night = 0.0
		_put(P, by, true)
		var v_bush: float = P.visibility()
		T.ok(W.cover_at(by.x, by.y) and v_bush < v_day_crouch * 0.6, "przykucnięcie przy krzaku chowa (%.2f zamiast %.2f)" % [v_bush, v_day_crouch])
		_put(P, by, false)
		T.ok(P.visibility() >= v_day - 0.001, "krzak nie zasłania stojącego")
	T.ok(W.covers.size() >= 5, "na mapie są krzaki do chowania się (%d)" % W.covers.size())

	# ---------------------------------------------------------------- hałas kroków
	G.night = 0.0
	_put(P, DARK, false, true, true)
	var n_sprint: float = P.noise()
	_put(P, DARK, false, true, false)
	var n_walk: float = P.noise()
	_put(P, DARK, true, true, false)
	var n_sneak: float = P.noise()
	_put(P, DARK)
	T.ok(n_sprint > 7.0 and n_walk > 2.0 and n_walk < n_sprint * 0.5 and n_sneak == 0.0 and P.noise() == 0.0, "hałas: bieg %.1f m, chód %.1f m, skradanie i stanie 0 m" % [n_sprint, n_walk])

	# ---------------------------------------------------------------- wzrok patrolu
	var east := Vector2(1.0, 0.0)
	G.night = 0.0
	_put(P, DARK)
	_cop_at(c, DARK + east * 18.0, DARK)
	var rot: float = c.node.rotation.y
	T.ok(W.los(c.x, c.z, DARK.x, DARK.y), "między patrolem a graczem nic nie stoi (warunek testów)")
	T.ok(N.see_level(c.x, c.z, rot, N.VIEW) > 0.0, "dzień: patrol widzi stojącego z 18 m")
	T.ok(N.see_level(c.x, c.z, rot + PI, N.VIEW) == 0.0, "patrol odwrócony plecami nie widzi nic")
	T.ok(N.see_level(c.x, c.z, rot + 1.3, N.VIEW) == 0.0 and N.see_level(c.x, c.z, rot + 0.5, N.VIEW) > 0.0, "kątem oka zasięg jest krótszy niż na wprost")
	G.night = 1.0
	T.ok(N.see_level(c.x, c.z, rot, N.VIEW) == 0.0, "noc: z 18 m w cieniu Cię nie widzi")
	_put(P, LIT)
	_cop_at(c, LIT + east * 18.0, LIT)
	T.ok(N.see_level(c.x, c.z, c.node.rotation.y, N.VIEW) > 0.0, "noc: pod latarnią widzi z 18 m")
	_put(P, DARK)
	_cop_at(c, DARK + east * 12.5, DARK)
	rot = c.node.rotation.y
	T.ok(N.see_level(c.x, c.z, rot, N.VIEW) == 0.0 and N.see_level(c.x, c.z, rot, N.VIEW, true) > 0.0, "noc: 12 m w cieniu — bez latarki nic, w snopie latarki widzi")
	T.ok(N.see_level(c.x, c.z, rot + 0.6, N.VIEW, true) == 0.0, "latarka pomaga tylko tam, gdzie świeci")
	_cop_at(c, DARK + east * 7.5, DARK)
	rot = c.node.rotation.y
	var st_lvl: float = N.see_level(c.x, c.z, rot, N.VIEW)
	_put(P, DARK, true)
	T.ok(st_lvl > 0.0 and N.see_level(c.x, c.z, rot, N.VIEW) == 0.0, "noc, 7,5 m: stojącego widzi, przykucniętego w cieniu nie")
	P.hidden = true
	T.ok(N.see_level(c.x, c.z, rot, N.VIEW, true) == 0.0 and P.visibility() == 0.0, "schowanego w kryjówce nie widzi nawet z latarką")
	P.hidden = false

	# ---------------------------------------------------------------- zauważanie trwa
	G.night = 0.0
	_put(P, DARK)
	_cop_at(c, DARK + east * 21.0, DARK)
	var pp: Vector3 = P.global_position
	_ticks(N, pp, 1)
	var n1: float = c.notice
	T.ok(n1 > 0.0 and n1 < 0.6 and not c.sees, "z daleka patrol nie zauważa od razu (po 0,2 s: %.2f)" % n1)
	var t_far := 1
	while not c.sees and t_far < 40:
		_ticks(N, pp, 1)
		t_far += 1
	T.ok(c.sees and t_far >= 4 and t_far <= 12, "z 21 m zauważenie trwa ok. %.1f s" % (t_far * 0.2))
	_cop_at(c, DARK + east * 4.0, DARK)
	var t_near := 0
	while not c.sees and t_near < 40:
		_ticks(N, pp, 1)
		t_near += 1
	T.ok(c.sees and t_near <= 2, "z 4 m zauważa w ułamku sekundy (%.1f s)" % (t_near * 0.2))
	# gracz znika za plecami: uwaga opada
	c.node.rotation.y += PI
	_ticks(N, pp, 16)
	T.ok(not c.sees and float(c.notice) <= 0.01, "gdy znikasz z pola widzenia, uwaga opada do zera")
	# łuk na HUD-zie pojawia się tylko wtedy, gdy bycie widzianym coś znaczy
	_cop_at(c, DARK + east * 21.0, DARK)
	N.susp_mult = 1.0
	_ticks(N, pp, 2)
	var arcs: int = N.aware.size()
	N.susp_mult = 0.0
	_cop_at(c, DARK + east * 21.0, DARK)
	_ticks(N, pp, 2)
	T.ok(arcs >= 1 and N.aware.is_empty(), "łuk zauważania: jest, gdy niesiesz coś podejrzanego; nie ma, gdy jesteś czysty")

	# ---------------------------------------------------------------- słuch
	_cop_at(c, DARK + east * 6.0, DARK + east * 30.0)
	_put(P, DARK, false, true, true)
	_ticks(N, P.global_position, 1)
	var heard_sprint: bool = float(c.hear_t) > 0.0
	_cop_at(c, DARK + east * 6.0, DARK + east * 30.0)
	_put(P, DARK + east * 4.0, true, true, false)
	_ticks(N, P.global_position, 1)
	var heard_sneak: bool = float(c.hear_t) > 0.0
	_cop_at(c, DARK + east * 6.0, DARK + east * 30.0)
	_put(P, DARK + east * 1.0, false, true, false)
	_ticks(N, P.global_position, 1)
	var heard_walk_far: bool = float(c.hear_t) > 0.0
	T.ok(heard_sprint and not heard_sneak and not heard_walk_far, "słuch: bieg 6 m za plecami słyszy, skradania 2 m za plecami nie, chodu z 5 m nie")
	# po usłyszeniu odwraca się i wtedy widzi
	_cop_at(c, DARK + east * 6.0, DARK + east * 30.0)
	_put(P, DARK, false, true, true)
	pp = P.global_position
	_ticks(N, pp, 1)
	for i in range(30):
		P.moving = true
		P.sprinting = true
		_ticks(N, pp, 1, 0.1)
	T.ok(c.sees, "usłyszał bieg, odwrócił się i zobaczył")

	# ---------------------------------------------------------------- odciąganie hałasem
	_put(P, DARK)
	pp = P.global_position
	_cop_at(c, DARK + east * 30.0, DARK + east * 60.0)
	var lure_pt: Vector2 = DARK + east * 38.0
	var lured: int = N.noise_at(lure_pt.x, lure_pt.y, 13.0)
	T.ok(lured == 1 and c.state == "investigate" and c.lure, "hałas odciąga patrol (idzie sprawdzić)")
	T.ok(N.noise_at(lure_pt.x + 80.0, lure_pt.y, 13.0) == 0, "hałas daleko od patrolu nikogo nie rusza")
	var steps := 0
	while c.state == "investigate" and steps < 200:
		_ticks(N, pp, 1)
		steps += 1
	T.ok(c.state == "search" and Vector2(c.x, c.z).distance_to(lure_pt) < 3.5, "patrol doszedł do miejsca hałasu i się rozgląda (%.1f s)" % (steps * 0.2))
	steps = 0
	while c.state == "search" and steps < 200:
		_ticks(N, pp, 1)
		steps += 1
	T.ok(c.state == "patrol" and steps * 0.2 < 9.0, "po chwili wraca na trasę (%.1f s)" % (steps * 0.2))
	# rzut kamykiem
	_cop_at(c, DARK + east * 19.0, DARK + east * 80.0)
	_put(P, DARK)
	P.yaw = -PI / 2.0       # patrzy na wschód
	P.pitch = 0.2
	P.rotation = Vector3(0, P.yaw, 0)
	P.cam.rotation = Vector3(P.pitch, 0, 0)
	M.throw_cd = 0.0
	var st0: int = M.stones.size()
	await T.frames(2)
	_put(P, DARK)
	M.throw_stone()
	T.ok(M.stones.size() == st0 + 1, "kamyk poleciał")
	M.throw_stone()
	T.ok(M.stones.size() == st0 + 1, "drugi rzut dopiero po chwili")
	var guard := 0
	while guard < 300 and not M.stones[M.stones.size() - 1].has("rest"):
		M._stones_tick(0.02)
		guard += 1
	var land: Vector3 = M.stones[M.stones.size() - 1].p
	var fly := Vector2(land.x - DARK.x, land.z - DARK.y)
	T.ok(fly.x > 8.0 and fly.x < 34.0 and absf(fly.y) < 4.0, "kamyk spada %d m przed graczem" % int(fly.x))
	T.ok(c.state == "investigate" and c.lure, "kamyk, który spadł %d m od patrolu, ściąga jego uwagę" % int(Vector2(land.x - c.x, land.z - c.z).length()))

	# ---------------------------------------------------------------- pościg, zgubienie tropu, przeczesywanie
	G.night = 0.0
	_put(P, DARK)
	_cop_at(c, DARK + east * 10.0, DARK)
	N.start_chase(c)
	T.ok(c.state == "chase" and S.wanted, "pościg ruszył")
	# gracz znika: daleko za budynkami
	var away := Vector2(-150.0 * SC, -100.0 * SC)
	_put(P, away)
	pp = P.global_position
	steps = 0
	while c.state == "chase" and steps < 100:
		_ticks(N, pp, 1)
		steps += 1
	T.ok(c.state == "search" and c.hunt and steps * 0.2 <= 8.0, "zgubił trop po %.1f s i przeczesuje okolicę" % (steps * 0.2))
	T.ok(c.search_pts.size() >= 1 and Vector2(c.x, c.z).distance_to(DARK) < 6.0, "szuka wokół miejsca, gdzie Cię ostatnio widział (%d punkty)" % c.search_pts.size())
	var moved := 0.0
	var last := Vector2(c.x, c.z)
	steps = 0
	while c.state == "search" and steps < 200:
		_ticks(N, pp, 1)
		moved += last.distance_to(Vector2(c.x, c.z))
		last = Vector2(c.x, c.z)
		steps += 1
	T.ok(c.state == "patrol" and moved > 4.0 and steps * 0.2 <= 16.0, "przeszukał %.0f m okolicy i po %.0f s odpuścił" % [moved, steps * 0.2])
	# gracz wraca pod nos przeczesującemu: pościg od nowa
	_cop_at(c, DARK + east * 6.0, DARK)
	c.inv = DARK
	N._begin_search(c, 15.0, true)
	c.node.rotation.y = atan2(DARK.x - c.x, DARK.y - c.z)
	c.sp_wait = 0.0
	c.search_pts = []
	S.wanted = true
	N.susp_mult = 3.0
	_put(P, DARK)
	pp = P.global_position
	steps = 0
	while c.state == "search" and steps < 30:
		c.node.rotation.y = atan2(DARK.x - c.x, DARK.y - c.z)
		_ticks(N, pp, 1)
		steps += 1
	T.ok(c.state == "chase", "wejście pod nos szukającemu patrolowi wznawia pościg (%.1f s)" % (steps * 0.2))
	N.end_chase()
	S.wanted = false
	N.susp_mult = 0.0

	# ---------------------------------------------------------------- kryjówki
	T.ok(W.hides.size() >= 6, "kryjówki rozsiane po osiedlu (%d altanek)" % W.hides.size())
	var bad_exit := 0
	for h in W.hides:
		if W.grid.is_point_solid(W._cell(float(h.ox), float(h.oz))):
			bad_exit += 1
	T.ok(bad_exit == 0, "przed każdą kryjówką jest wolne miejsce na wyjście")
	var h0: Dictionary = W.hides[0]
	_cop_at(c, Vector2(float(h0.ox) + 40.0, float(h0.oz) + 40.0), Vector2(900.0, 900.0))
	_put(P, Vector2(float(h0.ox), float(h0.oz)))
	M.hide_enter(h0)
	T.ok(P.hidden and P.crouching and not c.know and Vector2(P.global_position.x - float(h0.x), P.global_position.z - float(h0.z)).length() < 0.1, "schowanie się w altance")
	_cop_at(c, Vector2(float(h0.ox), float(h0.oz)) + Vector2(sin(float(h0.rot) + PI), cos(float(h0.rot) + PI)) * 3.0, Vector2(float(h0.x), float(h0.z)))
	T.ok(N.see_level(c.x, c.z, c.node.rotation.y, N.VIEW, true) == 0.0, "patrol stojący 3 m przed kryjówką Cię nie widzi")
	M.interact()
	T.ok(not P.hidden and Vector2(P.global_position.x - float(h0.ox), P.global_position.z - float(h0.oz)).length() < 0.1, "[E] wychodzi z kryjówki przed altankę")
	# patrol, który widzi wejście, wie, gdzie szukać
	_put(P, Vector2(float(h0.ox), float(h0.oz)))
	c.lvl = 0.5
	c.sees = true
	M.hide_enter(h0)
	T.ok(P.hidden and c.know and c.inv != null, "patrol, który widział wejście, idzie prosto do kryjówki")
	c.state = "chase"
	c.last_seen = G.now
	G.arresting = false
	var was_busy: bool = G.busy
	_cop_at(c, Vector2(float(h0.x), float(h0.z)) + Vector2(1.2, 0.0), Vector2(float(h0.x), float(h0.z)))
	c.state = "chase"
	c.know = true
	c.last_seen = G.now
	_ticks(N, P.global_position, 1)
	T.ok(not P.hidden and G.arresting, "wyciąga z kryjówki i zatrzymuje")
	# sprzątanie po teście
	if G.ui.mode == "dialog":
		await T.skip_dialog()
	G.arresting = false
	G.busy = was_busy
	G.ui.close_all()
	N.end_chase()
	Sfx.siren(false)
	S.wanted = keep_wanted
	S.heat = keep_heat
	S.invest = keep_invest
	S.inv = keep_inv
	for cc in N.cops:
		cc.idle = 0.0
		cc.post = false
		cc.state = "patrol"
		cc.susp = 0.0
		cc.notice = 0.0
		cc.know = false
		N._snap_to_node(cc)
	P.hidden = false
	P.crouching = false
	P.moving = false
	P.sprinting = false
	M.hide_at = {}
	G.strict_stealth = false
	P.sprinting = true
	P.moving = true
	T.ok(absf(P.noise() - 3.2 * (1.0 + G.night * 0.25 - G.rain * 0.4) * G.outfit_stat("noise", 1.0)) < 1.6 or P.loc != "out", "w zwykłej grze bieg nie robi więcej hałasu niż chód — patrole nie reagują na bieganie")
	P.sprinting = false
	P.moving = false
	M.teleport(back_loc, back_pos, back_yaw)
	await T.frames(2)
