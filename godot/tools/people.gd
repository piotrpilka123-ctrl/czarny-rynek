extends SceneTree
# podgląd zaimportowanej postaci: drzewo węzłów, siatki, kości i poza spoczynkowa
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		var m: Mesh = n.mesh
		var tris := 0
		var mats := []
		for s in range(m.get_surface_count()):
			var arr := m.surface_get_arrays(s)
			tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var mt := m.surface_get_material(s)
			mats.append(mt.resource_name if mt != null else "-")
		extra = " surf=%d tris=%d mats=%s aabb=%s" % [m.get_surface_count(), tris, str(mats), str(m.get_aabb())]
	if n is Node3D:
		extra += " pos=%s rot=%s scl=%s" % [str(n.position), str(n.rotation_degrees), str(n.scale)]
	print("  ".repeat(d), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		if not (n is Skeleton3D) or c is MeshInstance3D:
			_dump(c, d + 1)

func _init() -> void:
	var path := "res://assets/people/male_10.fbx"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--file="):
			path = String(a).trim_prefix("--file=")
	var n: Node = (load(path) as PackedScene).instantiate()
	_dump(n, 0)
	var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
	if sk == null:
		for c in n.find_children("*", "Skeleton3D", true, false):
			sk = c
	print("SKEL ", sk.get_path() if sk.is_inside_tree() else sk.name, " bones=", sk.get_bone_count(), " xf=", sk.transform)
	for i in range(sk.get_bone_count()):
		var nm := sk.get_bone_name(i)
		if nm.contains("Finger") or nm.length() > 22:
			continue
		var g := sk.get_bone_global_rest(i)
		var par := sk.get_bone_parent(i)
		print("B %-22s par=%-18s gpos=(%.3f, %.3f, %.3f) x=%s y=%s z=%s" % [nm, sk.get_bone_name(par) if par >= 0 else "-", g.origin.x, g.origin.y, g.origin.z,
			str(g.basis.x.snappedf(0.01)), str(g.basis.y.snappedf(0.01)), str(g.basis.z.snappedf(0.01))])
	var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
	print("ANIMS ", ap.get_animation_list() if ap != null else "brak")
	n.free()
	quit()
