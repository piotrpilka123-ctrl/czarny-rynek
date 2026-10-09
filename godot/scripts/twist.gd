extends SkeletonModifier3D
## Skręt tułowia i głowy nałożony na animację: patrol rozgląda się na boki, a latarka na szelce idzie za barkami.

var yaw := 0.0            # skręt barków w radianach (dodatni = w lewo)
var head := 0.55          # o ile dalej niż barki skręca się głowa (ułamek yaw)
var _chain: Array = []    # [[kość, udział], …] od bioder w górę; udział < 0 = głowa


func bind(sk: Skeleton3D) -> bool:
	_chain.clear()
	for e in [["Bip01 Spine", 0.25], ["Bip01 Spine1", 0.35], ["Bip01 Spine2", 0.4], ["Bip01 Head", -1.0]]:
		var i := sk.find_bone(String(e[0]))
		if i < 0:
			return false
		_chain.append([i, float(e[1])])
	return true


func _process_modification_with_delta(_delta: float) -> void:
	if absf(yaw) < 0.002:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	var axis := (sk.global_transform.basis.orthonormalized().inverse() * Vector3.UP).normalized()
	for e in _chain:
		var w: float = e[1]
		var g := sk.get_bone_global_pose(int(e[0]))
		g.basis = Basis(axis, yaw * (w if w >= 0.0 else head)) * g.basis
		sk.set_bone_global_pose(int(e[0]), g)
