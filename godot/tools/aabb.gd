extends SceneTree
## wymiary i ułożenie wybranych rekwizytów (czy model „leży”, czy „stoi”): Godot --headless --path . --script tools/aabb.gd
func _walk(n: Node, t: Transform3D, name: String) -> void:
	if n is Node3D:
		t = t * (n as Node3D).transform
	if n is MeshInstance3D and n.mesh != null:
		var ab: AABB = t * n.mesh.get_aabb()
		print("AABB %-24s pos=%s size=%s" % [name, ab.position, ab.size])
	for c in n.get_children():
		_walk(c, t, name)
func _init() -> void:
	for f in ["old_tyre/old_tyre", "rusted_wheel_rim_01/rusted_wheel_rim_01", "wheels_stack", "wheel", "water_manhole_cover/water_manhole_cover", "dirty_football/dirty_football", "pallet", "cement_bag/cement_bag", "can_rusted/can_rusted", "cigarette_pack/cigarette_pack", "wall_clock/wall_clock", "dartboard/dartboard"]:
		var p: String = "res://assets/props/" + String(f) + ".gltf"
		if not ResourceLoader.exists(p):
			print("BRAK ", p)
			continue
		var n: Node = load(p).instantiate()
		_walk(n, Transform3D.IDENTITY, String(f).get_file())
		n.free()
	quit()
