extends SceneTree
# porównanie wszystkich modeli z assets/people: trójkąty, powierzchnie, biodra, kierunki rąk
func _init() -> void:
	var da := DirAccess.open("res://assets/people")
	var names := []
	for d in da.get_directories():
		names.append(d)
	names.sort()
	var ref := {}
	for m in names:
		var ps: PackedScene = load("res://assets/people/%s/%s.fbx" % [m, m])
		var n := ps.instantiate()
		var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
		var tris := 0
		var surfs := []
		for c in sk.get_children():
			if c is MeshInstance3D:
				for s in range(c.mesh.get_surface_count()):
					tris += (c.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
					var mt: Material = c.mesh.surface_get_material(s)
					surfs.append(mt.resource_name if mt != null else "-")
		var hip := sk.get_bone_global_rest(sk.find_bone("Bip01")).origin.y
		var head := sk.get_bone_global_rest(sk.find_bone("Bip01 Head")).origin.y
		var ua := sk.get_bone_global_rest(sk.find_bone("Bip01 L UpperArm")).basis.x.normalized()
		var th := sk.get_bone_global_rest(sk.find_bone("Bip01 L Thigh")).basis.x.normalized()
		var maxd := 0.0
		for b in ["Bip01 Pelvis", "Bip01 Spine", "Bip01 L Clavicle", "Bip01 L UpperArm", "Bip01 L Forearm", "Bip01 L Hand", "Bip01 L Thigh", "Bip01 L Calf", "Bip01 L Foot", "Bip01 Head", "Bip01 L Finger1"]:
			var q := sk.get_bone_global_rest(sk.find_bone(b)).basis.orthonormalized().get_rotation_quaternion()
			if ref.has(b):
				maxd = maxf(maxd, rad_to_deg((ref[b] as Quaternion).angle_to(q)))
			else:
				ref[b] = q
		print("%-4s bones=%d tris=%d hip=%.3f head=%.3f arm=(%.2f,%.2f,%.2f) thigh=(%.2f,%.2f,%.2f) odchył=%.1f° %s" % [m, sk.get_bone_count(), tris, hip, head, ua.x, ua.y, ua.z, th.x, th.y, th.z, maxd, str(surfs)])
		n.free()
	quit()
