extends SceneTree
## wypisuje nazwy animacji w bibliotekach: Godot --headless --path . --script tools/anims.gd

func _init() -> void:
	for f in ["ual1", "ual2"]:
		var ps: PackedScene = load("res://assets/anim/%s.glb" % f)
		var n := ps.instantiate()
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		var names := []
		for a in ap.get_animation_list():
			names.append("%s(%.1fs)" % [a, ap.get_animation(a).length])
		print("ANIMS ", f, ": ", ", ".join(names))
		n.free()
	quit()
