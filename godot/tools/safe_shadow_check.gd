extends SceneTree
## Natywny renderer, bez dźwięku; najpierw tools/wolne.sh.
## --script res://tools/safe_shadow_check.gd -- --autostart --noload --quality=med
var output_dir := OS.get_environment("CR_OUT")
func _initialize():
	call_deferred("check")
func frames(n:int):
	for i in range(n): await process_frame
func meshes(n:Node, out:Array):
	if n is GeometryInstance3D: out.append(n)
	for c in n.get_children(): meshes(c,out)
func check():
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var game=root.get_node("G")
	while not game.running: await process_frame
	game.test_mode=true
	game.ui.close_controls()
	if output_dir.is_empty(): output_dir=OS.get_environment("TMPDIR").path_join("czarny-rynek")
	DirAccess.make_dir_recursive_absolute(output_dir)
	await frames(12)
	main.teleport("safe",Vector3(D.ROOMS.safe.cx+1.9,0,0.55),0)
	main.set_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	var cx:float=D.ROOMS.safe.cx
	game.player.cam.global_position=Vector3(cx+1.9,1.15,0.55)
	game.player.cam.look_at(Vector3(cx+0.7,0.4,-1.43))
	var nodes:Array=[]
	meshes(game.world.rooms.safe.get_node("SafeChair"),nodes)
	for n in nodes: n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	await frames(40)
	await RenderingServer.frame_post_draw
	var on=root.get_texture().get_image()
	on.save_png(output_dir.path_join("safe-cienie-on.png"))
	for n in nodes: n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await frames(25)
	await RenderingServer.frame_post_draw
	var off=root.get_texture().get_image()
	off.save_png(output_dir.path_join("safe-cienie-off.png"))
	var changed:=0
	var delta:=0.0
	for y in range(int(on.get_height()*0.48),int(on.get_height()*0.9),2):
		for x in range(int(on.get_width()*0.2),int(on.get_width()*0.8),2):
			var a=on.get_pixel(x,y)
			var b=off.get_pixel(x,y)
			var d=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
			delta+=d
			if d>0.035: changed+=1
	print("SHADOW_RENDER chair_meshes=",nodes.size()," changed_floor_pixels=",changed," delta=",delta)
	quit(0 if changed>50 else 1)
