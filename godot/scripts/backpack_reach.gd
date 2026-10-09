extends SkeletonModifier3D
## Ręce dosięgają rzeczywistych ruchomych części plecaka; modyfikacja tylko podglądu.
var bag: Node3D
var arms: Array = []
var right := Vector3.RIGHT
var width := 0.3
var last_error := 0.0

func bind(sk: Skeleton3D, backpack: Node3D) -> bool:
	bag = backpack
	for side in ["R", "L"]:
		var chain: Array = []
		for part in ["UpperArm", "Forearm", "Hand"]:
			var id := sk.find_bone("Bip01 " + side + " " + part)
			if id < 0: return false
			chain.append(id)
		chain.append(sk.find_bone("Bip01 " + side + " Finger2"))
		arms.append(chain)
	var across := sk.get_bone_global_rest(arms[0][0]).origin - sk.get_bone_global_rest(arms[1][0]).origin
	width = across.length()
	right = across.normalized()
	process_mode = Node.PROCESS_MODE_ALWAYS
	return true

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or not is_instance_valid(bag) or not bag.visible or bag.reach_weight <= 0.0: return
	last_error = 0.0
	for side in range(2):
		var target: Node3D = bag.zipper if side == 0 else bag.lid
		if target == null: continue
		var goal := sk.to_local(target.global_position)
		# Lewa ręka przytrzymuje krawędź klapy, prawa prowadzi suwak.
		if side == 1: goal += right * -width * 0.28
		var grip := goal
		var finger: int = arms[side][3]
		if finger >= 0:
			var palm := sk.get_bone_global_rest(finger).origin.distance_to(sk.get_bone_global_rest(arms[side][2]).origin)
			goal += right * palm * (1.0 if side == 0 else -1.0)
		var shoulder: Vector3 = sk.get_bone_global_pose(arms[side][0]).origin
		var back := sk.to_local(bag.global_position) - shoulder
		back.y = 0.0
		var pole := shoulder + right * width * (1.3 if side == 0 else -1.3) + back.normalized() * width * 0.6 - Vector3.UP * width * 0.25
		solve(sk, arms[side], goal, pole, bag.reach_weight)
		if finger >= 0:
			var hand: Transform3D = sk.get_bone_global_pose(arms[side][2])
			var pointing := sk.get_bone_global_pose(finger).origin - hand.origin
			var toward := grip - hand.origin
			if minf(pointing.length(), toward.length()) > 0.001:
				var turn := Quaternion(pointing.normalized(), toward.normalized())
				hand.basis = Basis(Quaternion.IDENTITY.slerp(turn, bag.reach_weight)) * hand.basis
				sk.set_bone_global_pose(arms[side][2], hand)

func solve(sk: Skeleton3D, chain: Array, goal: Vector3, pole: Vector3, weight: float) -> void:
	var a: Transform3D = sk.get_bone_global_pose(chain[0])
	var b: Transform3D = sk.get_bone_global_pose(chain[1])
	var c: Transform3D = sk.get_bone_global_pose(chain[2])
	var l1 := a.origin.distance_to(b.origin)
	var l2 := b.origin.distance_to(c.origin)
	if minf(l1, l2) < 0.001: return
	var wanted := c.origin.lerp(goal, clampf(weight, 0.0, 1.0))
	var direction := (wanted - a.origin).normalized()
	var distance := clampf(a.origin.distance_to(wanted), absf(l1-l2)+0.001, l1+l2-0.001)
	var bend := pole - a.origin
	bend = (bend - direction * bend.dot(direction)).normalized()
	if bend.length_squared() < 0.5: return
	var along := (l1*l1 - l2*l2 + distance*distance) / (2.0*distance)
	var elbow := a.origin + direction*along + bend*sqrt(maxf(0.0,l1*l1-along*along))
	var rotation := Quaternion((b.origin-a.origin).normalized(), (elbow-a.origin).normalized())
	a.basis = Basis(rotation) * a.basis
	sk.set_bone_global_pose(chain[0], a)
	b = sk.get_bone_global_pose(chain[1])
	c = sk.get_bone_global_pose(chain[2])
	var tip := a.origin + direction*distance
	rotation = Quaternion((c.origin-b.origin).normalized(), (tip-b.origin).normalized())
	b.basis = Basis(rotation) * b.basis
	sk.set_bone_global_pose(chain[1], b)
	last_error = maxf(last_error, (sk.global_basis * (sk.get_bone_global_pose(chain[2]).origin - wanted)).length())
