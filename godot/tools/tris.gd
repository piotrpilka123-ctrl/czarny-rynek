extends SceneTree
## liczy trójkąty w modelach przyrody: Godot --headless --path . --script tools/tris.gd

func _count(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and n.mesh != null:
		for i in range(n.mesh.get_surface_count()):
			var a: Array = n.mesh.surface_get_arrays(i)
			var idx = a[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null else a[Mesh.ARRAY_VERTEX].size()) / 3
	for c in n.get_children():
		t += _count(c)
	return t


func _init() -> void:
	var d := DirAccess.open("res://assets/nature")
	for f in d.get_files():
		if f.ends_with(".gltf"):
			var ps: PackedScene = load("res://assets/nature/" + f)
			if ps != null:
				var n := ps.instantiate()
				print("TRIS %-28s %d" % [f, _count(n)])
				n.free()
	quit()
