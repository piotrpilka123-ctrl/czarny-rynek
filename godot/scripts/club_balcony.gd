extends RefCounted
const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")
const Signs = preload("res://scripts/signs.gd")
## Wspólne wymiary schodów, brył i powierzchni chodzenia. Parter pod balkonem pozostaje dostępny.
const LEVEL := 3.2
const X0 := -7.4
const X1 := -6.0
const Z0 := -3.2
const Z1 := 5.2
const STEPS := 21
const TREAD := (Z1-Z0)/STEPS
const RISE := LEVEL/STEPS
const FOOT_REACH := 0.3

static func floor_height(pos: Vector3) -> float:
	var x: float=pos.x-float(D.ROOMS.club.cx)
	# Przednia część kapsuły dotyka stopnia przed dotarciem jej środka do podstopnicy.
	if x>=X0 and x<=X1 and pos.z>Z0-FOOT_REACH and pos.z<Z1:
		return minf(LEVEL, (floorf((pos.z-Z0+FOOT_REACH)/TREAD)+1.0)*RISE)
	if pos.y>LEVEL-0.3 and absf(x)<7.5 and pos.z>=Z1 and pos.z<=9.0:
		return LEVEL
	return 0.0

static func restore(pos: Vector3) -> Vector3:
	var h:=floor_height(pos)
	if absf(h-pos.y)>0.3:
		return Vector3(D.ROOMS.club.cx,0,7.4)
	return Vector3(pos.x,h,pos.z)

static func rail(world, g: Node3D, a: Vector3, b: Vector3, material: Material) -> void:
	var d:=b-a
	var length:=d.length()
	var bar:=Models.box(g,Vector3(0.055,0.055,length), (a+b)*0.5+Vector3.UP*1.07,material)
	bar.look_at(b+Vector3.UP*1.07)
	var count:=maxi(1,int(ceil(length/0.7)))
	for i in range(count+1):
		var p:=a.lerp(b,float(i)/count)
		Models.cyl(g,0.024,0.024,1.05,p+Vector3.UP*0.525,material,Vector3.ZERO,8)
	# Kolizja wypełnia odstępy pomiędzy słupkami i zatrzymuje również kucającego gracza.
	for i in range(count):
		var p:=a.lerp(b,float(i)/count)
		var q:=a.lerp(b,float(i+1)/count)
		world.add_col(minf(p.x,q.x)-0.04,maxf(p.x,q.x)+0.04,minf(p.z,q.z)-0.04,maxf(p.z,q.z)+0.04,maxf(p.y,q.y)+1.1,true,minf(p.y,q.y))
		world.rects.pop_back()

static func build(world, room: Node3D, cx: float) -> void:
	var g:=Node3D.new()
	g.name="UpperLounges"
	room.add_child(g)
	var stone:=Props.pbr("concrete_floor_worn_001",0.5,Color(0.5,0.5,0.57))
	var carpet:=Models.mat("301627",0.95)
	var brass:=Models.mat("b29465",0.3,0.75)
	var edge:=Models.mat("3be8ff",0.4,0.0,1.5)
	# Pełne stopnie: wejście wyłącznie od dołu, brak przechodzenia przez schody z boku.
	for i in range(STEPS):
		var h:float=(i+1)*RISE
		var z:float=Z0+(i+0.5)*TREAD
		world._club_partition(g,Vector3(X1-X0,h,TREAD),Vector3(cx+(X0+X1)*0.5,h*0.5,z),stone)
		Models.box(g,Vector3(X1-X0-0.08,0.012,0.045),Vector3(cx+(X0+X1)*0.5,h+0.006,z-TREAD*0.5+0.024),edge,Vector3.ZERO,false)
	for x in [X0,X1]:
		rail(world,g,Vector3(cx+x,RISE,Z0),Vector3(cx+x,LEVEL,Z1),brass)
	world._club_partition(g,Vector3(15.0,0.18,9.0-Z1),Vector3(cx,LEVEL-0.09,(9.0+Z1)*0.5),stone)
	Models.box(g,Vector3(14.8,0.015,9.0-Z1-0.08),Vector3(cx,LEVEL+0.008,(9.0+Z1)*0.5),carpet,Vector3.ZERO,false)
	rail(world,g,Vector3(cx+X1,LEVEL,Z1),Vector3(cx+7.4,LEVEL,Z1),brass)
	Models.box(g,Vector3(7.4-X1,0.025,0.035),Vector3(cx+(X1+7.4)*0.5,LEVEL+0.12,Z1),edge,Vector3.ZERO,false)
	# Trzy osobne loże z wolnym ciągiem komunikacyjnym przy balustradzie.
	for x in [-3.3,0.9,5.1]:
		world._lm(g,"klub_kanapa",cx+x,8.35,PI,LEVEL)
		world._lm(g,"klub_stolik",cx+x,7.25,0.0,LEVEL)
		world.add_col(cx+x-1.04,cx+x+1.04,7.94,8.76,LEVEL+1.0,true,LEVEL)
		world.rects.pop_back()
		world.add_col(cx+x-0.35,cx+x+0.35,6.9,7.6,LEVEL+1.09,true,LEVEL)
		world.rects.pop_back()
		var li=world._room_light(g,cx+x,7.1,5.75,0.65,Color(1.0,0.56,0.32),3.5)
		li.shadow_enabled=true
	for x in [-1.2,3.0]:
		world._club_partition(g,Vector3(0.1,1.2,2.0),Vector3(cx+x,LEVEL+0.6,8.0),Models.mat("21141e",0.8))
	var sign:=Signs.text("LOŻE  ↑", "bebas",80,Color(1.0,0.8,0.4),0.007)
	sign.position=Vector3(cx-7.37,1.9,Z0-0.7)
	sign.rotation.y=PI/2.0
	g.add_child(sign)
	var vip:=Signs.text("NEON  /  LOUNGE", "bebas",100,Color(1.0,0.3,0.75),0.007)
	vip.position=Vector3(cx+0.9,5.25,8.93)
	vip.rotation.y=PI
	g.add_child(vip)
