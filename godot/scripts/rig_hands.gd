extends SkeletonModifier3D
## Dłonie postaci sięgają do punktów w świecie (np. Siwy przy panelu ładunku): obie ręce na wysokości panelu,
## drobne ruchy palców i nadgarstków jak przy łączeniu przewodów. Wagę 0→1 ustawia wołający.

var goals: Array = []        # dwa punkty globalne: prawa i lewa dłoń
var weight := 0.0
var arms: Array = []
var _t := 0.0


func bind(sk: Skeleton3D) -> bool:
	for side in ["R", "L"]:
		var chain: Array = []
		for part in ["UpperArm", "Forearm", "Hand", "Finger2"]:
			var id := sk.find_bone("Bip01 " + side + " " + part)
			if id < 0:
				return false
			chain.append(id)
		arms.append(chain)
	process_mode = Node.PROCESS_MODE_ALWAYS
	return true


func _process_modification_with_delta(dt: float) -> void:
	var sk := get_skeleton()
	if sk == null or goals.size() < 2 or weight <= 0.001:
		return
	_t += dt
	for s in range(2):
		var sway := Vector3(0.0, sin(_t * (5.0 + s * 1.7)) * 0.012, cos(_t * (4.0 + s * 2.3)) * 0.015)
		var goal := sk.to_local(goals[s] + sway)
		var a: Transform3D = sk.get_bone_global_pose(arms[s][0])
		var pole := sk.to_local(sk.to_global(a.origin) + Vector3(0.0, -0.5, 0.0))
		_solve(sk, arms[s], goal, pole)
		var hand: Transform3D = sk.get_bone_global_pose(arms[s][2])
		var pointing := sk.get_bone_global_pose(arms[s][3]).origin - hand.origin
		var toward := goal + (goal - a.origin).normalized() * 0.1 - hand.origin
		if minf(pointing.length(), toward.length()) > 0.001:
			hand.basis = Basis(Quaternion(pointing.normalized(), toward.normalized())) * hand.basis
			sk.set_bone_global_pose(arms[s][2], hand)


func _solve(sk: Skeleton3D, chain: Array, goal: Vector3, pole: Vector3) -> void:
	var a: Transform3D = sk.get_bone_global_pose(chain[0])
	var b: Transform3D = sk.get_bone_global_pose(chain[1])
	var c: Transform3D = sk.get_bone_global_pose(chain[2])
	var l1 := a.origin.distance_to(b.origin)
	var l2 := b.origin.distance_to(c.origin)
	if minf(l1, l2) < 0.001:
		return
	var wanted := c.origin.lerp(goal, clampf(weight, 0.0, 1.0))
	var direction := (wanted - a.origin).normalized()
	var distance := clampf(a.origin.distance_to(wanted), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
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
