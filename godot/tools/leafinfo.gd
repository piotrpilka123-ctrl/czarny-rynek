extends SceneTree
## topologia liści drzew: Godot --headless --path . --script tools/leafinfo.gd

func _walk(n: Node, name: String) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var m: Mesh = n.mesh
		for i in range(m.get_surface_count()):
			var a: Array = m.surface_get_arrays(i)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var mat: Material = m.surface_get_material(i)
			# czy kolejne pary trójkątów dzielą 2 wierzchołki (czworokąty)?
			var quads := 0
			for t in range(0, idx.size() - 5, 6):
				var s1 := {idx[t]: 1, idx[t + 1]: 1, idx[t + 2]: 1}
				var sh := 0
				for k in range(3):
					if s1.has(idx[t + 3 + k]):
						sh += 1
				if sh == 2:
					quads += 1
			var area := 0.0
			for t in range(0, idx.size() - 2, 3):
				area += (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]]).length() * 0.5
			print("LEAF %-16s surf=%d mat=%-14s verts=%d tris=%d quadpairs=%d area=%.1f aabb=%s" % [name, i, mat.resource_name if mat != null else "-", v.size(), idx.size() / 3, quads, area, m.get_aabb().size])
	for c in n.get_children():
		_walk(c, name)


func _init() -> void:
	for f in ["commontree_1", "commontree_2", "commontree_3", "commontree_4", "commontree_5", "twistedtree_1", "twistedtree_2", "bush_common", "deadtree_1"]:
		var ps: PackedScene = load("res://assets/nature/" + f + ".gltf")
		var n := ps.instantiate()
		_walk(n, f)
		n.free()
	quit()
