extends SceneTree
## poziomy szczegółowości modeli rekwizytów: Godot --headless --path . --script tools/lods.gd

func _walk(n: Node, name: String) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var m: Mesh = n.mesh
		for i in range(m.get_surface_count()):
			var d: Dictionary = RenderingServer.mesh_get_surface(m.get_rid(), i)
			var base := int(d.get("index_count", 0) / 3.0)
			var parts: Array = []
			for l in d.get("lods", []):
				parts.append("%.3f:%d" % [float(l.edge_length), int((l.index_data as PackedByteArray).size() / (2.0 if int(d.vertex_count) <= 65536 else 4.0) / 3.0)])
			var ab: AABB = m.get_aabb()
			print("LOD %-28s tris=%-6d size=%.2f lods=[%s]" % [name, base, maxf(ab.size.x, maxf(ab.size.y, ab.size.z)), ", ".join(parts)])
	for c in n.get_children():
		_walk(c, name)


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_scan(dir + "/" + sub)
	for f in d.get_files():
		if f.ends_with(".gltf"):
			var ps: PackedScene = load(dir + "/" + f)
			if ps != null:
				var n := ps.instantiate()
				_walk(n, f.get_basename())
				n.free()


func _init() -> void:
	_scan("res://assets/props")
	_scan("res://assets/nature")
	quit()
