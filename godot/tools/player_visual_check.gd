extends SceneTree
func _initialize(): call_deferred("check")
func frames(n:int):
	for i in range(n): await process_frame
func check():
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var g=root.get_node("G")
	while not g.running: await process_frame
	g.test_mode=true
	g.ui.close_controls()
	g.S.upg.plecak1=true
	g.S.upg.plecak2=true
	g.ui.open_inventory("","char")
	await frames(30)
	var inv=g.ui.inv
	inv.set_process(false)
	var out:=OS.get_environment("CR_OUT")
	if out.is_empty(): out=OS.get_environment("TMPDIR").path_join("czarny-rynek")
	DirAccess.make_dir_recursive_absolute(out)
	for angle in [0.0,PI]:
		inv.pivot.rotation.y=angle
		await frames(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("gracz-przod.png" if angle==0.0 else "gracz-plecak.png"))
		inv.vp.get_texture().get_image().save_png(out.path_join("gracz-przod-detal.png" if angle==0.0 else "gracz-plecak-detal.png"))
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_RIGHT
	event.pressed=true
	inv._spin_input(event)
	var valid:bool=inv.preview_motion==1 and inv.bag_mesh.visible and inv.bag_mesh.get_parent() is BoneAttachment3D
	inv._spin_input(event)
	valid=valid and inv.preview_motion==2 and String(inv.rig.cur)=="Jog_Fwd"
	inv.inspect_backpack()
	for i in range(35): await physics_frame
	await RenderingServer.frame_post_draw
	inv.vp.get_texture().get_image().save_png(out.path_join("gracz-kieszen-otwarta.png"))
	root.get_texture().get_image().save_png(out.path_join("gracz-kontrolki.png"))
	valid=valid and inv.bag_mesh.lid!=null and inv.bag_mesh.zipper!=null and inv.bag_mesh.opening>0.99
	inv.inspect_backpack()
	for i in range(35): await physics_frame
	valid=valid and inv.bag_mesh.opening<0.01
	print("PLAYER_VISUAL animation=",inv.rig.cur," bone_attachment=",valid)
	quit(0 if valid else 1)
