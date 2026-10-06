extends SceneTree
## kości modelu postaci i ich ułożenie w spoczynku: Godot --headless --path . --script tools/bones.gd
func _init() -> void:
	var People = load("res://scripts/people.gd")
	var p: Dictionary = People.instance("pm3", "")
	var sk: Skeleton3D = p.skel
	for nm in ["Bip01 Pelvis", "Bip01 Spine", "Bip01 Spine1", "Bip01 Spine2", "Bip01 Neck", "Bip01 Head", "Bip01 R Thigh", "Bip01 R Hand", "Bip01 R Forearm"]:
		var i := sk.find_bone(nm)
		if i < 0:
			print("BONE brak ", nm)
			continue
		var t := sk.get_bone_global_rest(i)
		print("BONE %-16s pos=%s  X=%s Y=%s Z=%s" % [nm, t.origin.snapped(Vector3.ONE * 0.01), t.basis.x.snapped(Vector3.ONE * 0.1), t.basis.y.snapped(Vector3.ONE * 0.1), t.basis.z.snapped(Vector3.ONE * 0.1)])
	print("BONE skala modelu ", (p.model as Node3D).scale, " skel ", sk.global_transform.basis.get_scale() if sk.is_inside_tree() else sk.transform.basis.get_scale(), " top ", p.top)
	quit()
