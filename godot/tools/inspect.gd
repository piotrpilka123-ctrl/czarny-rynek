extends SceneTree

func _init() -> void:
	var a: Node = load("res://assets/chars/male.gltf").instantiate()
	var b: Node = load("res://assets/anim/ual1.glb").instantiate()
	var c: Node = load("res://assets/chars/female.gltf").instantiate()
	var sa: Skeleton3D = a.find_child("Skeleton3D", true, false)
	var sb: Skeleton3D = b.find_child("Skeleton3D", true, false)
	var sc: Skeleton3D = c.find_child("Skeleton3D", true, false)
	var worst := 0.0
	for i in range(sa.get_bone_count()):
		var nm := sa.get_bone_name(i)
		var j := sb.find_bone(nm)
		var k := sc.find_bone(nm)
		var ra := sa.get_bone_rest(i)
		var rb := sb.get_bone_rest(j)
		var rc := sc.get_bone_rest(k)
		var ang := rad_to_deg(ra.basis.get_rotation_quaternion().angle_to(rb.basis.get_rotation_quaternion()))
		var angf := rad_to_deg(rc.basis.get_rotation_quaternion().angle_to(rb.basis.get_rotation_quaternion()))
		var dpos := ra.origin.distance_to(rb.origin)
		if ang > 1.0 or dpos > 0.01 or angf > 1.0:
			print("%-16s rot_diff_m %.1f°  rot_diff_f %.1f°  pos_m %s pos_ual %s pos_f %s" % [nm, ang, angf, str(ra.origin.snapped(Vector3(0.001,0.001,0.001))), str(rb.origin.snapped(Vector3(0.001,0.001,0.001))), str(rc.origin.snapped(Vector3(0.001,0.001,0.001)))])
	var ap: AnimationPlayer = b.find_child("AnimationPlayer", true, false)
	var an := ap.get_animation("Idle")
	var types := {}
	for t in range(an.get_track_count()):
		var ty := an.track_get_type(t)
		types[ty] = int(types.get(ty, 0)) + 1
		if ty == Animation.TYPE_POSITION_3D:
			print("pos track ", an.track_get_path(t), " key0=", an.track_get_key_value(t, 0))
	print("track types ", types, " (1=pos,2=rot,3=scale)")
	for nm in ["thigh_l", "calf_l", "upperarm_l"]:
		for t in range(an.get_track_count()):
			if String(an.track_get_path(t)).ends_with(":" + nm) and an.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = an.track_get_key_value(t, 0)
				print(nm, " idle key0 vs UAL rest: %.1f°, vs UBC rest: %.1f°" % [rad_to_deg(q.angle_to(sb.get_bone_rest(sb.find_bone(nm)).basis.get_rotation_quaternion())), rad_to_deg(q.angle_to(sa.get_bone_rest(sa.find_bone(nm)).basis.get_rotation_quaternion()))])
	quit()
