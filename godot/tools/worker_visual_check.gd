extends SceneTree
## Bez okna: --autostart --noload --mute --prod --loc=garage --pos=0.2,-2.7.
## CR_OUT wybiera folder wyjściowy. Sprawdza opłaconą wizytę i eksportuje pozę.
var output_dir := OS.get_environment("CR_OUT")
func _initialize(): call_deferred("check")
func check():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var game = root.get_node("G")
	while not game.running: await process_frame
	game.test_mode=true
	game.ui.close_controls()
	main._apply_test_args()
	await physics_frame
	await physics_frame
	game.S.workers.roman={"paused":false,"next":game.S.t,"day":game.day(),"paid":0.0,"day_visits":0,"visits":0,"watered":0,"status":""}
	for pot in game.Prod.pots("garage"):
		if pot.pl != null and pot.pl.prog>0.3 and pot.pl.prog<0.6: pot.pl.water=20.0
	var before: float = game.S.cash
	game.Workers.tick()
	var paid_correctly: bool = game.S.cash==before-game.Workers.VISIT and game.S.workers.roman.visits==1
	var actor = null
	for node in main.get_children():
		if node.get_script()==load("res://scripts/worker_visual.gd"): actor=node
	var cash: float = game.S.cash
	var visits: int = game.S.workers.roman.visits
	actor._process(0.016)
	await process_frame
	actor.rig.anim.advance(2.5)
	await process_frame
	var good: bool = paid_correctly and actor.visible and game.player.fits_at(actor.global_position,true) and game.S.cash==cash and game.S.workers.roman.visits==visits
	var exported := Node3D.new()
	var room = game.world.rooms.garage.duplicate()
	room.visible=true
	game.world._glb_fix(room)
	exported.add_child(room)
	var person = actor.duplicate()
	bake_actor(actor,person,actor.rig.skel)
	person.visible=true
	game.world._glb_fix(person)
	exported.add_child(person)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(exported,state)
	if output_dir.is_empty(): output_dir=(OS.get_environment("TMPDIR") if not OS.get_environment("TMPDIR").is_empty() else "/tmp").path_join("czarny-rynek")
	DirAccess.make_dir_recursive_absolute(output_dir)
	if err==OK: err=doc.write_to_filesystem(state,output_dir.path_join("roman-praca.glb"))
	game.S.t=game.S.workers.roman.visual_until+1.0
	actor._process(0.016)
	good=good and not actor.visible and err==OK
	print("WORKER VISUAL CHECK ","OK" if good else "FAIL", " CX=",root.get_node("D").ROOMS.garage.cx)
	exported.free()
	quit(0 if good else 1)

func bake_actor(source: Node,copy: Node,skel: Skeleton3D) -> void:
	if copy==null: return
	if source is MeshInstance3D and source.mesh!=null and source.skin!=null:
		var baked := ArrayMesh.new()
		var skin: Skin = source.skin
		var transforms: Array = []
		for bind in range(skin.get_bind_count()):
			var bone := skin.get_bind_bone(bind)
			if bone<0: bone=skel.find_bone(skin.get_bind_name(bind))
			transforms.append(source.global_transform.affine_inverse()*skel.global_transform*skel.get_bone_global_pose(bone)*skin.get_bind_pose(bind))
		for surface in range(source.mesh.get_surface_count()):
			var arrays: Array = source.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences := int(bones.size()/verts.size())
			for i in range(verts.size()):
				var vertex := Vector3.ZERO
				var normal := Vector3.ZERO
				for j in range(influences):
					var offset := i*influences+j
					var weight := weights[offset]
					if weight<=0: continue
					var xf: Transform3D = transforms[bones[offset]]
					vertex+=(xf*verts[i])*weight
					normal+=(xf.basis*normals[i])*weight
				verts[i]=vertex
				normals[i]=normal.normalized()
			arrays[Mesh.ARRAY_VERTEX]=verts
			arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_BONES]=null
			arrays[Mesh.ARRAY_WEIGHTS]=null
			baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			baked.surface_set_material(surface,source.mesh.surface_get_material(surface))
		copy.mesh=baked
		copy.skin=null
		copy.skeleton=NodePath()
	for child in source.get_children(): bake_actor(child,copy.get_node_or_null(NodePath(child.name)),skel)
