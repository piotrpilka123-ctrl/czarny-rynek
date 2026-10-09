extends RefCounted
static func run(T) -> void:
	var cx: float=D.ROOMS.club.cx
	var player=G.player
	var entrance_clear:=true
	for z in [4.4,5.0,6.0,6.6,7.4,8.0]:
		entrance_clear=entrance_clear and player.fits_at(Vector3(cx,0,z),false)
	T.ok(entrance_clear,"klub: kapsuła gracza mieści się w całym neonowym wejściu i bramce")
	var bathrooms_clear:=true
	for x in [-5.4,-3.4]:
		for z in [4.6,5.0,5.4,6.0,7.0]:
			bathrooms_clear=bathrooms_clear and player.fits_at(Vector3(cx+x,0,z),false)
	T.ok(bathrooms_clear,"klub: obie łazienki mają dostępne wejścia i miejsce do chodzenia")
	T.ok(not player.fits_at(Vector3(cx+1.45,0,7.0),false) and not player.fits_at(Vector3(cx-4.65,0,7.0),false),"klub: ściany korytarza i podział łazienek rzeczywiście blokują gracza")

	T.ok(not player.fits_at(Vector3(cx-6.05,0,8.35),false) and not player.fits_at(Vector3(cx-3.25,0,8.35),false),"klub: wyposażenie łazienek ma kolizję zamiast przenikania")
	var B=load("res://scripts/club_balcony.gd")
	var saved_pos:Vector3=player.global_position
	var saved_loc:String=player.loc
	var saved_yaw:float=player.yaw
	var saved_pitch:float=player.pitch
	var was_crouched:bool=player.crouching
	var was_physics:bool=player.is_physics_processing()
	player.set_physics_process(false)
	player.loc="club"
	player.place(Vector3(cx-6.7,0,-3.8),PI)
	for i in range(155):
		await player.get_tree().physics_frame
		player.velocity=Vector3(0,0,3.9)
		player.walk_slide()
	if player.global_position.z<=5.6: print("CLUB WALK up stopped at ",player.global_position)
	T.ok(player.global_position.z>5.6 and is_equal_approx(player.global_position.y,B.LEVEL),"klub: rzeczywisty ruch kapsuły wchodzi po schodach na górny balkon")
	player.place(Vector3(cx,3.2,6.1),0)
	for i in range(45):
		await player.get_tree().physics_frame
		player.velocity=Vector3(0,0,-3.9)
		player.walk_slide()
	T.ok(player.global_position.z>5.5 and is_equal_approx(player.global_position.y,B.LEVEL),"klub: balustrada zatrzymuje gracza przed krawędzią piętra")
	player.set_crouch(true)
	for i in range(30):
		await player.get_tree().physics_frame
		player.velocity=Vector3(0,0,-6.5)
		player.walk_slide()
	T.ok(player.global_position.z>5.5 and is_equal_approx(player.global_position.y,B.LEVEL),"klub: kucanie i sprint nie pozwalają przejść przez balustradę")
	player.place(Vector3(cx-6.7,3.2,5.9),0)
	for i in range(155):
		await player.get_tree().physics_frame
		player.velocity=Vector3(0,0,-3.9)
		player.walk_slide()
	T.ok(player.global_position.z< -3.5 and is_zero_approx(player.global_position.y),"klub: po zejściu schodami gracz wraca na parter")
	T.ok(player.fits_at(Vector3(cx,0,6.0),false) and is_zero_approx(B.floor_height(Vector3(cx,0,6.0))),"klub: można przejść pod balkonem bez przenoszenia na piętro")
	T.ok(player.fits_at(Vector3(cx,3.2,6.0),false) and not player.fits_at(Vector3(cx+0.9,3.2,8.3),false),"klub: górny korytarz jest wolny, kanapy mają kolizje na właściwej wysokości")
	player.place(Vector3(cx,3.2,6.0),0)
	T.ok(is_equal_approx(player.global_position.y,3.2),"klub: wznowienie pozycji na piętrze zachowuje wysokość")
	player.place(Vector3(cx,0,6.0),0)
	T.ok(is_zero_approx(player.global_position.y),"klub: starszy zapis bez wysokości pozostaje na parterze")
	G.main.teleport("club",Vector3(cx-3.3,3.2,5.95),PI)
	await T.frames(3)
	var hit=G.main._find_interact()
	T.ok(hit!=null and String(hit.label.call()).contains("Nadia"),"klub: celownik trafia rozmówcę na piętrze na jego rzeczywistej wysokości")
	player.place(Vector3(cx-3.3,0,5.95),PI)
	hit=G.main._find_interact()
	T.ok(hit==null or not String(hit.label.call()).contains("Nadia"),"klub: rozmówca z piętra nie staje się celem na parterze")
	G.main.teleport(saved_loc,saved_pos,saved_yaw)
	player.pitch=saved_pitch
	if was_crouched: player.set_crouch(true)
	player.set_physics_process(was_physics)
