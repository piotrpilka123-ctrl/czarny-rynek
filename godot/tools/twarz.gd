extends SceneTree
## co model postaci ma do mimiki: kości twarzy i kształty (blend shapes): Godot --headless --path . --script tools/twarz.gd -- m02
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var People = load("res://scripts/people.gd")
	var p: Dictionary = People.instance(args[0] if args.size() > 0 else "m02", "")
	var sk: Skeleton3D = p.skel
	var face := []
	for i in range(sk.get_bone_count()):
		var nm := sk.get_bone_name(i)
		var par := sk.get_bone_parent(i)
		var pn := sk.get_bone_name(par) if par >= 0 else ""
		if pn.contains("Head") or nm.contains("Eye") or nm.contains("Jaw") or nm.contains("Lid") or nm.contains("Brow") or nm.contains("Lip") or nm.contains("Cheek") or nm.contains("Tongue") or nm.contains("Mouth"):
			face.append(nm)
	print("TWARZ kości (%d z %d): " % [face.size(), sk.get_bone_count()], ", ".join(face))
	for mi in (p.model as Node).find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m is ArrayMesh:
			var n := (m as ArrayMesh).get_blend_shape_count()
			var names := []
			for i in range(mini(n, 80)):
				names.append(String((m as ArrayMesh).get_blend_shape_name(i)))
			print("TWARZ siatka ", mi.name, " kształty: ", n, " ", ", ".join(names))
	quit()
