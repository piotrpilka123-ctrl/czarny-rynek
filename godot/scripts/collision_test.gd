extends RefCounted
static func run(T) -> void:
	var world=G.world
	var solid:=true
	var no_invisible_height:=true
	for point in [Vector2(-150,-150),Vector2(-86.8,133),Vector2(14.6,-73.7-1.0/D.SC)]:
		var middle: Vector2=point*D.SC
		var y: float=world.height(middle.x,middle.y)
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(middle.x-0.6,y+0.45,middle.y),Vector3(middle.x+0.6,y+0.45,middle.y))
		ray.exclude=[G.player.get_rid()]
		solid=solid and not G.main.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		if point.x==14.6:
			ray.from.y=y+1.2
			ray.to.y=y+1.2
			no_invisible_height=G.main.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	T.ok(solid,"płoty działek, boiska i boczne płotki ogródków mają rzeczywistą kolizję")
	T.ok(no_invisible_height,"niski płotek nie tworzy niewidzialnej ściany ponad swoją wysokością")
	var saved: Dictionary=G.S
	G.S=G.new_state()
	G.S.props.garaz=true
	G.S.hide.garage.pots=[{"x":0.0,"z":0.0,"pl":null}]
	world.refresh_furniture("garage")
	await T.frames(3)
	var cx: float=D.ROOMS.garage.cx
	T.ok(not G.player.fits_at(Vector3(cx,0,0),false) and G.player.fits_at(Vector3(cx+0.8,0,0),false),"doniczka blokuje wejście w jej podstawę, ale nie wolne miejsce obok")
	G.S=saved
	world.refresh_furniture("garage")
	await T.frames(3)
