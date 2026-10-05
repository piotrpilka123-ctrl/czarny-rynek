extends SceneTree
func _init() -> void:
	var ps: PackedScene = load("res://assets/anim/ual1.glb")
	var n := ps.instantiate()
	var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
	var a := ap.get_animation("Walk")
	var names := []
	for t in range(a.get_track_count()):
		names.append("%s[%d,%dk]" % [String(a.track_get_path(t)).get_slice(":", 1), a.track_get_type(t), a.track_get_key_count(t)])
	print("TRACKS ", a.length, " ", ", ".join(names))
	n.free()
	quit()
