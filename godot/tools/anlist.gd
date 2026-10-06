extends SceneTree
func _init() -> void:
	for f in ["res://assets/anim/ual1.glb", "res://assets/anim/ual2.glb"]:
		if not ResourceLoader.exists(f):
			continue
		var n: Node = load(f).instantiate()
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		print("ANIMS ", f, " ", ", ".join(ap.get_animation_list()))
		n.free()
	quit()
