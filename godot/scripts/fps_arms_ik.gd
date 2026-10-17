extends SkeletonModifier3D
## Ręce gracza w widoku z pierwszej osoby: dłonie przed kamerą, lekkie kołysanie przy chodzie,
## wysięg skracany tuż przy ścianie (promień z kamery), głowa zwinięta, żeby nie zasłaniała kadru.

var player


## tor prawej dłoni z telefonem w układzie kamery: z postawy luzem do kieszeni na biodrze (k 0→0,4), potem z kieszeni przed oczy
static func phone_path(k: float) -> Vector3:
	var rest := Vector3(0.28, -0.42, -0.3)
	var pocket := Vector3(0.27, -0.72, -0.04)
	var front := Vector3(0.1, -0.12, -0.33)
	if k < 0.4:
		return rest.lerp(pocket, smoothstep(0.0, 1.0, k / 0.4))
	return pocket.lerp(front, smoothstep(0.0, 1.0, (k - 0.4) / 0.6))


## środek telefonu w układzie kamery (fps_arms.gd stawia go tutaj)
static func phone_at(k: float) -> Vector3:
	return phone_path(k) + Vector3(-0.01, 0.02, 0.0)


## Nadgarstek trzymający telefon: pod dolną krawędzią i tuż za nim — palce idą w górę po pleckach telefonu,
## kciuk zostaje z przodu nad ekranem. Z kieszeni dłoń wychodzi zwykłym torem, chwyt wchodzi w drugiej połowie ruchu.
const PHONE_GRIP := Vector3(0.012, -0.095, -0.012)

static func phone_hand(k: float) -> Vector3:
	var g := smoothstep(0.0, 1.0, clampf((k - 0.4) / 0.6, 0.0, 1.0))
	return phone_path(k) + (Vector3(-0.01, 0.02, 0.0) + PHONE_GRIP) * g


var arms: Array = []     # [[ramię, przedramię, dłoń, palec], …] prawa i lewa
var thumb := -1          # kciuk prawej dłoni: przy telefonie obracamy dłoń tak, żeby był z przodu
var head := -1
var reach := 0.42
var sway := 0.0
var phone := 0.0    # 1 = prawa dłoń z telefonem przed oczami
var give_goals: Array = [Vector3(0.12, -0.22, -0.5), Vector3(-0.12, -0.22, -0.5)]
var give := 0.0     # 1 = obie dłonie wysunięte z paczką
var hold := 0.0     # 1 = dłonie na plecaku przed kamerą


func bind(sk: Skeleton3D, p) -> bool:
	player = p
	for side in ["R", "L"]:
		var chain: Array = []
		for part in ["UpperArm", "Forearm", "Hand", "Finger2"]:
			var id := sk.find_bone("Bip01 " + side + " " + part)
			if id < 0:
				return false
			chain.append(id)
		arms.append(chain)
	head = sk.find_bone("Bip01 Head")
	thumb = sk.find_bone("Bip01 R Finger01")
	if thumb < 0:
		thumb = sk.find_bone("Bip01 R Finger0")
	return true


func _process_modification_with_delta(dt: float) -> void:
	var sk := get_skeleton()
	if sk == null or player == null or not is_instance_valid(player.cam):
		return
	var cam: Camera3D = player.cam
	# wysięg: przy ścianie dłonie się cofają
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 0.75
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	var want := 0.42
	if not hit.is_empty():
		want = clampf(from.distance_to(hit.position) - 0.2, 0.1, 0.42)
	reach = lerpf(reach, want, minf(1.0, dt * 10.0))
	sway = lerpf(sway, 1.0 if player.moving else 0.0, minf(1.0, dt * 6.0))
	var amp := (0.05 if player.sprinting else 0.025) * sway
	for s in range(2):
		var side := 1.0 if s == 0 else -1.0
		var ph: float = player.bob * 0.5 + (0.0 if s == 0 else PI)
		# w spoczynku ręce zwisają luźno poza kadrem (widać je dopiero po spojrzeniu w dół); pełne ręce tylko przy akcjach
		var lp := Vector3(side * 0.28 + cos(ph) * amp * 0.5, -0.42 - absf(sin(ph)) * amp + (0.05 if player.sprinting else 0.0), -0.3 * reach / 0.42)
		if hold > 0.0:
			lp = lp.lerp(Vector3(side * 0.15, -0.2 if s == 0 else -0.26, -0.43), smoothstep(0.0, 1.0, hold))
		if give > 0.0:
			lp = lp.lerp(give_goals[s], smoothstep(0.0, 1.0, give))
		var grip := 0.0
		if phone > 0.0 and s == 0:
			lp = phone_hand(phone)
			grip = smoothstep(0.0, 1.0, clampf((phone - 0.4) / 0.6, 0.0, 1.0))
		var goal := sk.to_local(cam.to_global(lp))
		var shoulder: Vector3 = sk.get_bone_global_pose(arms[s][0]).origin
		var pole := sk.to_local(cam.to_global(Vector3(side * 0.55, -0.6, 0.2)))
		_solve(sk, arms[s], goal, pole)
		# dłoń skierowana palcami do przodu
		var hand: Transform3D = sk.get_bone_global_pose(arms[s][2])
		var pointing := sk.get_bone_global_pose(arms[s][3]).origin - hand.origin
		var toward := sk.to_local(cam.to_global(lp + Vector3(0, 0.02, -0.2))) - hand.origin
		if grip > 0.0:
			# z telefonem palce idą w górę po jego pleckach, a nie prosto przed siebie
			var up := sk.to_local(cam.to_global(phone_at(phone) + Vector3(0.0, 0.07, -0.03))) - hand.origin
			toward = toward.normalized().lerp(up.normalized(), grip)
		if minf(pointing.length(), toward.length()) > 0.001:
			hand.basis = Basis(Quaternion(pointing.normalized(), toward.normalized())) * hand.basis
			sk.set_bone_global_pose(arms[s][2], hand)
		if grip > 0.0 and thumb >= 0:
			# obrót dłoni wokół palców: kciuk ma wskazywać kamerę (leży na ekranie), wtedy wnętrze dłoni obejmuje telefon od tyłu
			hand = sk.get_bone_global_pose(arms[s][2])
			var axis := (sk.get_bone_global_pose(arms[s][3]).origin - hand.origin)
			var th := sk.get_bone_global_pose(thumb).origin - hand.origin
			var eye := sk.to_local(cam.global_position) - hand.origin
			if axis.length() > 0.001:
				axis = axis.normalized()
				th -= axis * th.dot(axis)
				eye -= axis * eye.dot(axis)
				if th.length() > 0.001 and eye.length() > 0.001:
					var ang := th.signed_angle_to(eye, axis)
					hand.basis = Basis(axis, ang * grip) * hand.basis
					sk.set_bone_global_pose(arms[s][2], hand)
		if shoulder.length() < 0.0:
			return
	if head >= 0:
		var h: Transform3D = sk.get_bone_global_pose(head)
		h.basis = h.basis.scaled(Vector3.ONE * 0.001)
		sk.set_bone_global_pose(head, h)


func _solve(sk: Skeleton3D, chain: Array, goal: Vector3, pole: Vector3) -> void:
	var a: Transform3D = sk.get_bone_global_pose(chain[0])
	var b: Transform3D = sk.get_bone_global_pose(chain[1])
	var c: Transform3D = sk.get_bone_global_pose(chain[2])
	var l1 := a.origin.distance_to(b.origin)
	var l2 := b.origin.distance_to(c.origin)
	if minf(l1, l2) < 0.001:
		return
	var direction := (goal - a.origin).normalized()
	var distance := clampf(a.origin.distance_to(goal), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var bend := pole - a.origin
	bend = (bend - direction * bend.dot(direction)).normalized()
	if bend.length_squared() < 0.5:
		return
	var along := (l1 * l1 - l2 * l2 + distance * distance) / (2.0 * distance)
	var elbow := a.origin + direction * along + bend * sqrt(maxf(0.0, l1 * l1 - along * along))
	a.basis = Basis(Quaternion((b.origin - a.origin).normalized(), (elbow - a.origin).normalized())) * a.basis
	sk.set_bone_global_pose(chain[0], a)
	b = sk.get_bone_global_pose(chain[1])
	c = sk.get_bone_global_pose(chain[2])
	var tip := a.origin + direction * distance
	b.basis = Basis(Quaternion((c.origin - b.origin).normalized(), (tip - b.origin).normalized())) * b.basis
	sk.set_bone_global_pose(chain[1], b)
