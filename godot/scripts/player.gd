extends CharacterBody3D
## Gracz: widok z pierwszej osoby, ruch po nierównym terenie, sprint, latarka.

const WALK := 3.9
const SPRINT := 6.5
const SNEAK := 2.0
const BASE_STAMINA := 6.0
const EYE := 1.66
const EYE_LOW := 0.92
const BODY_H := 1.75
const BODY_LOW := 1.0

var yaw := 0.0
var pitch := 0.0
var loc := "safe"
var stamina := BASE_STAMINA
var sprinting := false
var tired := false
var moving := false
var bob := 0.0
var step_t := 0.0
var shake := 0.0
var cam: Camera3D
var flash: SpotLight3D
var look_scale := 1.0
var invert_y := false
var base_fov := 70.0
var crouching := false
var hidden := false          # siedzi w kryjówce (altanka śmietnikowa): niewidoczny, dopóki nikt nie widział, jak wchodzi
var vis_now := 1.0           # ostatnio policzona widoczność (HUD)
var eye_y := EYE
var _cs: CollisionShape3D
var _cap: CapsuleShape3D
var _stand_msg := 0.0


func _ready() -> void:
	_cs = CollisionShape3D.new()
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.34
	_cap.height = BODY_H
	_cs.shape = _cap
	_cs.position = Vector3(0, 0.9, 0)
	add_child(_cs)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.06
	cam.far = 900.0
	cam.position = Vector3(0, 1.66, 0)
	add_child(cam)
	cam.current = true
	flash = SpotLight3D.new()
	flash.light_energy = 0.0
	flash.spot_range = 36.0
	flash.spot_angle = 28.0
	flash.light_color = Color(1.0, 0.96, 0.86)
	flash.shadow_enabled = true
	flash.spot_angle_attenuation = 0.7
	flash.spot_attenuation = 0.7
	flash.light_volumetric_fog_energy = 3.5
	# plama latarki: jasny środek, ciemniejsza obwódka i lekki pierścień
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.42, 0.72, 0.86, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1), Color(0.9, 0.9, 0.9), Color(0.42, 0.42, 0.42), Color(0.6, 0.6, 0.6), Color(0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 256
	gt.height = 256
	flash.light_projector = gt
	flash.position = Vector3(0.25, -0.15, 0)
	cam.add_child(flash)


func max_stamina() -> float:
	return BASE_STAMINA * (1.3 if G.has_skill("kondycja1") else 1.0) * G.outfit_stat("stamina", 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and G.running and not G.busy:
		yaw -= event.relative.x * 0.0022 * look_scale
		pitch = clampf(pitch - event.relative.y * 0.0022 * look_scale * (-1.0 if invert_y else 1.0), -1.45, 1.45)


# ---------------------------------------------------------------- kucanie
## czy nad głową jest miejsce, żeby wstać
func can_stand() -> bool:
	if not is_inside_tree():
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = BODY_H - 0.06
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.92, 0))
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## czy sylwetka (stojąca albo skulona) mieści się w danym miejscu — używane w testach przełazów
func fits_at(pos: Vector3, crouched: bool) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = BODY_LOW if crouched else BODY_H
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, (0.52 if crouched else 0.9), 0))
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func set_crouch(on: bool) -> bool:
	if on == crouching:
		return true
	if not on and not can_stand():
		if G.now - _stand_msg > 2.5:
			_stand_msg = G.now
			G.notify("Tu się nie wyprostujesz.")
		return false
	crouching = on
	_cap.height = BODY_LOW if on else BODY_H
	_cs.position.y = 0.52 if on else 0.9
	return true


func toggle_crouch() -> void:
	set_crouch(not crouching)


func place(pos: Vector3, new_yaw: float) -> void:
	global_position = pos
	yaw = new_yaw
	pitch = 0.0
	velocity = Vector3.ZERO
	rotation = Vector3(0, yaw, 0)
	cam.rotation = Vector3.ZERO
	if crouching:
		crouching = false
		_cap.height = BODY_H
		_cs.position.y = 0.9
	hidden = false
	eye_y = EYE
	if G.world != null and loc == "out":
		global_position.y = G.world.height(pos.x, pos.z)


func _physics_process(dt: float) -> void:
	if not G.running or G.busy:
		return
	if hidden:
		# w kryjówce można się tylko rozglądać
		velocity = Vector3.ZERO
		moving = false
		sprinting = false
		stamina = minf(max_stamina(), stamina + dt)
		rotation = Vector3(0, yaw, 0)
		cam.rotation = Vector3(pitch, 0, 0)
		return
	# rozglądanie strzałkami (alternatywa dla myszy)
	yaw += (float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))) * 1.9 * dt
	pitch = clampf(pitch + (float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))) * 1.4 * dt, -1.45, 1.45)
	var mx := float(G.key_down("right")) - float(G.key_down("left"))
	var mz := float(G.key_down("back")) - float(G.key_down("fwd"))
	moving = mx != 0.0 or mz != 0.0
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := (right * mx - fwd * mz)
	if dir.length() > 0.01:
		dir = dir.normalized()
	var want_sprint := G.key_down("sprint") and moving
	var ms := max_stamina()
	if stamina <= 0.05:
		tired = true
	if stamina > ms * 0.3:
		tired = false
	# bieg podrywa z kucek (o ile jest miejsce nad głową)
	if want_sprint and crouching and not tired:
		set_crouch(false)
	sprinting = want_sprint and not tired and not crouching
	if sprinting:
		stamina = maxf(0.0, stamina - dt)
	else:
		stamina = minf(ms, stamina + dt * (0.5 if moving else 1.0))
	var sp := (SPRINT * (1.08 if G.has_skill("kondycja2") else 1.0)) if sprinting else (SNEAK if crouching else WALK)
	sp *= G.outfit_stat("speed", 1.0)
	var gp := global_position
	var outside := loc == "out" and G.world != null
	# pod górę wolniej
	if outside and moving:
		var h0: float = G.world.height(gp.x, gp.z)
		var h1: float = G.world.height(gp.x + dir.x * 0.8, gp.z + dir.z * 0.8)
		var grade := (h1 - h0) / 0.8
		sp *= clampf(1.0 - maxf(0.0, grade) * 0.75, 0.45, 1.0)
	velocity = Vector3(dir.x * sp, 0.0, dir.z * sp)
	# ciężki plecak męczy szybciej podczas biegu
	if sprinting:
		stamina = maxf(0.0, stamina - dt * 0.3 * clampf(G.carry_total() / maxf(1.0, float(G.capacity())), 0.0, 1.0))
	move_and_slide()
	G.S.stats["dist"] = float(G.S.stats.get("dist", 0.0)) + Vector2(global_position.x - gp.x, global_position.z - gp.z).length()
	gp = global_position
	if outside:
		gp.x = clampf(gp.x, -208.4 * D.SC, 208.4 * D.SC)
		gp.z = clampf(gp.z, -168.8 * D.SC, 168.8 * D.SC)
		gp.y = G.world.height(gp.x, gp.z)
	else:
		gp.y = 0.0
	global_position = gp
	if moving:
		step_t -= dt
		if step_t <= 0.0:
			var surf := "wood" if not outside else String(G.world.surface_at(gp.x, gp.z))
			if loc == "garage" or loc == "basement" or loc == "shop":
				surf = "concrete"
			# na kucaka idzie się cicho
			if not crouching:
				Sfx.step(surf, sprinting)
			step_t = 0.3 if sprinting else 0.48
		bob += dt * (12.0 if sprinting else (5.2 if crouching else 7.6))
	shake = maxf(0.0, shake - dt * 1.6)
	eye_y = lerpf(eye_y, EYE_LOW if crouching else EYE, minf(1.0, dt * 9.0))
	var by := sin(bob) * (0.06 if sprinting else (0.018 if crouching else 0.03)) if moving else 0.0
	cam.position = Vector3(cos(bob * 0.5) * 0.018 if moving else 0.0, eye_y + by, 0)
	rotation = Vector3(0, yaw + randf_range(-1.0, 1.0) * shake * 0.02, 0)
	cam.rotation = Vector3(pitch + randf_range(-1.0, 1.0) * shake * 0.02, 0, 0)
	var fov := base_fov + (5.0 if sprinting else 0.0)
	cam.fov = lerpf(cam.fov, fov, minf(1.0, dt * 8.0))


## Jak dobrze widać gracza: 1 = zwykły przechodzień w dzień. Przez to mnożony jest zasięg wzroku patroli.
## Liczy się postawa, ruch, ciemność (i to, czy stoisz w świetle latarni), deszcz, krzaki i ubranie.
func visibility() -> float:
	if hidden:
		vis_now = 0.0
		return 0.0
	var v := 1.0
	if crouching:
		v *= 0.6
	if sprinting:
		v *= 1.25
	elif Vector2(velocity.x, velocity.z).length() < 0.3:
		v *= 0.85
	if loc == "out" and G.world != null:
		var gp := global_position
		var dark: float = G.night * (1.0 - G.world.light_at(gp.x, gp.z))
		if flash.light_energy > 0.05 and G.night > 0.3:
			# latarka nocą: świecisz jak choinka
			dark = 0.0
			v *= 1.2
		v *= 1.0 - dark * 0.5
		v *= 1.0 - G.rain * 0.18
		if crouching and G.world.cover_at(gp.x, gp.z):
			v *= 0.55
	v *= G.outfit_stat("vis", 1.0) * lerpf(1.0, G.outfit_stat("vis_night", 1.0), clampf(G.night, 0.0, 1.0))
	vis_now = clampf(v, 0.12, 1.5)
	return vis_now


## z jakiej odległości słychać kroki (0 = cisza)
func noise() -> float:
	if hidden or not moving or crouching or loc != "out":
		return 0.0
	var r := 9.0 if sprinting else 3.2
	if G.world != null:
		var surf := String(G.world.surface_at(global_position.x, global_position.z))
		if surf == "grass":
			r *= 0.7
		elif surf == "gravel":
			r *= 1.2
	return r * (1.0 + G.night * 0.25 - G.rain * 0.4) * G.outfit_stat("noise", 1.0)


func forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))
