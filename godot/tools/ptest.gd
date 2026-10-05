extends SceneTree
func _init() -> void:
	var Chars = load("res://scripts/chars.gd")
	var t0 := Time.get_ticks_msec()
	var rig: Dictionary = Chars.make({"model": "m10", "seed": 1})
	print("make ms=", Time.get_ticks_msec() - t0)
	root.add_child(rig.root)
	var ap: AnimationPlayer = rig.anim
	print("anims ", ap.get_animation_list().size(), " root_node=", ap.root_node, " cur=", ap.current_animation)
	var a: Animation = ap.get_animation("Walk")
	print("Walk len=", a.length, " tracks=", a.get_track_count())
	for t in range(mini(4, a.get_track_count())):
		print("  ", a.track_get_path(t), " type=", a.track_get_type(t), " keys=", a.track_get_key_count(t))
	var sk: Skeleton3D = rig.skel
	var b := sk.find_bone("Bip01 L UpperArm")
	print("rest ", sk.get_bone_rest(b).basis.get_rotation_quaternion(), " pose0 ", sk.get_bone_pose_rotation(b))
	ap.play("Walk")
	ap.seek(0.4, true)
	ap.advance(0.0)
	print("pose1 ", sk.get_bone_pose_rotation(b), " skel path from ap root: ", ap.get_node(ap.root_node).get_path_to(sk))
	quit()
