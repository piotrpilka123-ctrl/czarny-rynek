extends RefCounted
static func run(T) -> void:
	var cx: float=D.ROOMS.club.cx
	var player=G.player
	var entrance_clear:=true
	for z in [4.4,5.0,6.0,6.6,7.4,8.0]:
		entrance_clear=entrance_clear and player.fits_at(Vector3(cx,0,z),false)
	T.ok(entrance_clear,"klub: kapsuła gracza mieści się w całym neonowym wejściu i bramce")
	var bathrooms_clear:=true
	for x in [-6.05,-3.4]:
		for z in [4.6,5.0,5.4,6.0,7.0]:
			bathrooms_clear=bathrooms_clear and player.fits_at(Vector3(cx+x,0,z),false)
	T.ok(bathrooms_clear,"klub: obie łazienki mają dostępne wejścia i miejsce do chodzenia")
	T.ok(not player.fits_at(Vector3(cx+1.45,0,7.0),false) and not player.fits_at(Vector3(cx-4.65,0,7.0),false),"klub: ściany korytarza i podział łazienek rzeczywiście blokują gracza")

	T.ok(not player.fits_at(Vector3(cx-6.05,0,8.35),false) and not player.fits_at(Vector3(cx-3.25,0,8.35),false),"klub: wyposażenie łazienek ma kolizję zamiast przenikania")
