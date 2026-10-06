extends RefCounted
## Test prologu: ustawienie sceny, pakowanie, nalot, wyjście, trasa ucieczki (czy da się przejść
## na kucaka i czy na stojąco wpada się w oczy), złapanie i powtórka, bieg, eksplozje, sprzątanie.


static func run(T) -> void:
	var M = G.main
	var N = G.npcs
	var W = G.world
	var P = G.player
	var U = G.ui
	G.S = G.new_state()
	G.running = true
	G.busy = false
	N.clear_customers()
	U.close_all()
	M.start_prologue()
	await T.frames(3)
	var pr = G.prologue
	T.ok(pr != null and P.loc == "lab" and M.cut_hour > 4.0 and M.cut_hour < 5.5, "prolog startuje w laboratorium, przed świtem")
	T.ok(W.mill_burnt != null and not W.mill_burnt.visible and not W.door_tape.visible, "w prologu huta jeszcze stoi nietknięta")
	T.ok(pr.cop_a != null and pr.cop_b != null and pr.cop_b.beat != null and pr.flashes.size() == 4, "dwa patrole z latarkami i radiowozy z kogutami na miejscach")
	pr.jump("lab")
	await T.frames(2)
	T.ok(pr.stage == "lab" and String(G.cur_step().text.call()).contains("spakuj") and G.chapter().begins_with("Prolog"), "cel prologu zastępuje zwykłe zadania")
	var t0: float = G.S.t
	await T.frames(20)
	T.ok(G.S.t == t0, "w prologu zegar gry stoi")
	var mk: Dictionary = G.cur_step().marker.call()
	T.ok(String(mk.loc) == "lab", "znacznik prowadzi do stołu z cegłami")
	await M.exit_room()
	T.ok(P.loc == "lab", "przed nalotem tylne drzwi nie puszczą (najpierw torba)")
	await pr.act("pack")
	T.ok(pr.stage == "raid" and not W.lab_fx.bag.visible and U.mode == "dialog", "spakowanie torby zaczyna nalot")
	await T.skip_dialog()
	U.close_all()
	await T.frames(12)
	var lit := 0.0
	for l in W.lab_fx.flash:
		lit += float(l.light_energy)
	T.ok(lit > 3.0 and pr.can_exit(), "koguty biją po hali, tylne drzwi otwarte")
	await M.exit_room()
	var e: Vector2 = pr.exit_pos()
	T.ok(P.loc == "out" and pr.stage == "escape" and Vector2(P.global_position.x - e.x, P.global_position.z - e.y).length() < 0.5, "wyjście tyłem huty: etap ucieczki")
	await T.frames(3)
	T.ok(G.night > 0.6, "na zewnątrz jest jeszcze ciemno (noc %.2f)" % G.night)

	# --- trasa: da się dojść, na kucaka bezpiecznie, na stojąco i biegiem — wpadka
	var gp: Vector2 = pr.gap()
	var path: PackedVector2Array = W.grid_path(e, gp + Vector2(1.2, 0.0))
	var plen := 0.0
	for i in range(path.size() - 1):
		plen += path[i].distance_to(path[i + 1])
	T.ok(path.size() >= 2 and plen < 55.0 and path[path.size() - 1].distance_to(gp + Vector2(1.2, 0.0)) < 1.5, "od drzwi do dziury w siatce jest przejście (%d m)" % int(plen))
	var gap_free: bool = not W.grid.is_point_solid(W._cell(gp.x - 2.4, gp.y)) and not W.grid.is_point_solid(W._cell(pr.run_end().x, pr.run_end().y))
	T.ok(gap_free and W.grid_path(gp + Vector2(-2.4, 0.0), pr.run_end()).size() >= 1, "za siatką jest wolna droga między garaże")
	var crawl_ok := false
	for cr in W.crawls:
		if Vector2(float(cr.x) - 128.6 * D.SC, float(cr.z) - (-90.0 * D.SC)).length() < 1.0:
			crawl_ok = true
	T.ok(crawl_ok, "w siatce za torami jest przełaz na kucaka")
	# bezpieczna trasa: łukiem na południowy zachód, na kucaka, gdy patrol B idzie plecami
	var a: Dictionary = pr.cop_a
	var b: Dictionary = pr.cop_b
	var route := [e, pr.P(176.0, -113.5), pr.P(166.0, -106.0), pr.P(153.0, -97.0), pr.P(142.0, -93.0), gp + Vector2(1.0, 0.0)]
	var seen_sneak := 0
	var seen_run := 0
	G.night = 1.0
	b.node.rotation.y = 0.0          # patrol B patrzy na południe (plecami do trasy)
	for i in range(route.size() - 1):
		for k in range(8):
			var q: Vector2 = (route[i] as Vector2).lerp(route[i + 1], k / 8.0)
			P.global_position = Vector3(q.x, W.height(q.x, q.y), q.y)
			P.hidden = false
			P.crouching = true
			P.sprinting = false
			P.moving = true
			P.velocity = Vector3(1.5, 0, 0)
			if N.see_level(a.x, a.z, a.node.rotation.y, N.VIEW, true) > 0.0 or N.see_level(b.x, b.z, b.node.rotation.y, N.VIEW, true) > 0.0:
				seen_sneak += 1
	# a teraz na wprost, biegiem, prosto na patrol A
	var direct := [e, pr.P(160.0, -113.0), pr.P(146.0, -112.0)]
	for i in range(direct.size() - 1):
		for k in range(8):
			var q2: Vector2 = (direct[i] as Vector2).lerp(direct[i + 1], k / 8.0)
			P.global_position = Vector3(q2.x, W.height(q2.x, q2.y), q2.y)
			P.crouching = false
			P.sprinting = true
			P.moving = true
			P.velocity = Vector3(6.0, 0, 0)
			if N.see_level(a.x, a.z, a.node.rotation.y, N.VIEW, true) > 0.0:
				seen_run += 1
	T.ok(seen_sneak == 0, "na kucaka, łukiem i za plecami patrolu da się przejść niezauważonym (%d wpadek)" % seen_sneak)
	T.ok(seen_run >= 2, "biegiem prosto pod latarkę — widzą od razu (%d razy)" % seen_run)
	P.crouching = false
	P.sprinting = false

	# --- wpadka: powrót pod drzwi i druga próba
	P.global_position = Vector3(e.x - 6.0, W.height(e.x - 6.0, e.y), e.y)
	a.sees = true
	var guard := 0
	while pr.tries == 0 and guard < 60:
		guard += 1
		await T.frames(1)
	guard = 0
	while G.busy and guard < 40:
		guard += 1
		await T.get_tree().create_timer(0.15).timeout
	T.ok(pr.tries == 1 and pr.stage == "escape" and Vector2(P.global_position.x - e.x, P.global_position.z - e.y).length() < 0.6 and not a.sees, "złapany wraca pod drzwi i próbuje jeszcze raz")

	# --- za siatką: bieg, potem eksplozje
	P.global_position = Vector3(gp.x - 2.6, W.height(gp.x - 2.6, gp.y), gp.y)
	await T.frames(3)
	T.ok(pr.stage == "run" and String(G.cur_step().text.call()).contains("biegiem"), "po przejściu pod siatką: komenda do biegu")
	var re: Vector2 = pr.run_end()
	P.global_position = Vector3(re.x, W.height(re.x, re.y), re.y)
	await T.frames(4)
	T.ok(pr.stage == "boom" and G.busy and U.cut.visible, "między garażami zaczyna się finał")
	guard = 0
	while pr.fire_lights.size() < 3 and guard < 900:
		guard += 1
		await T.frames(1)
	var bursts := 0
	for ch in M.get_children():
		if ch is Node3D and ch.get_child_count() >= 6 and ch.get_child(0) is OmniLight3D and ch.get_child(1) is GPUParticles3D:
			bursts += 1
	T.ok(pr.fire_lights.size() >= 3 and bursts >= 2, "huta wylatuje w powietrze: %d eksplozje naraz w kadrze, %d ognisk pożaru" % [bursts, pr.fire_lights.size()])
	M.cut_skip = true
	guard = 0
	while G.prologue != null and guard < 1500:
		guard += 1
		await T.frames(1)
	guard = 0
	while G.busy and guard < 600:
		guard += 1
		await T.frames(1)
	T.ok(G.prologue == null and P.loc == "safe" and G.flag("prologue_done") and M.cut_hour < 0.0, "po prologu: kawalerka, trzy tygodnie później")
	T.ok(W.mill_burnt.visible and W.door_tape.visible and G.door_label("lab").contains("Zaplombowane"), "huta okopcona, drzwi laboratorium zaplombowane")
	var clean := true
	for c in N.cops:
		if c.get("beat") != null or float(c.idle) > 100.0:
			clean = false
	T.ok(clean and pr.nodes.is_empty() if is_instance_valid(pr) else clean, "patrole wracają do zwykłej służby, rekwizyty posprzątane")
	T.ok(U.mode == "dialog" and String(U.dlg.lines[0].t).contains("Wiktor"), "dzwoni Wiktor: dług za spaloną partię")
	await T.skip_dialog()
	U.close_all()
	T.ok(G.chapter().contains("Po nalocie") and String(G.cur_step().text.call()).contains("laptopa"), "rozdział 1 „Po nalocie”: samouczek w kawalerce")
	await M.enter("lab")
	T.ok(P.loc == "safe", "do zaplombowanego laboratorium nie da się wrócić")
