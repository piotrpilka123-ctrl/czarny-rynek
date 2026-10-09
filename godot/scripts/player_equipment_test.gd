extends RefCounted
static func run(T) -> void:
	var saved:Dictionary=G.S
	G.S=G.new_state()
	var inv=G.ui.inv
	G.ui.open_inventory("","char")
	await T.frames(3)
	T.ok(not inv.bag_mesh.visible,"gracz: bez kupionego plecaka nie ma modelu ani darmowej pojemności")
	G.S.upg.plecak1=true
	inv.render()
	await T.frames(3)
	T.ok(inv.bag_mesh.visible and inv.bag_mesh.lid!=null and inv.bag_mesh.zipper!=null,"gracz: plecak ma osobną klapę i ruchomy suwak")
	var store:=JSON.stringify(G.S)
	inv.inspect_backpack()
	inv.bag_mesh._process(0.6)
	T.ok(inv.preview_motion==0 and is_equal_approx(inv.spin_rest,PI) and inv.bag_mesh.opening==1.0 and inv.bag_mesh.lid.rotation.x< -0.5,"gracz: obejrzenie plecaka obraca postać, rozsuwa zamek i uchyla kieszeń")
	T.ok(JSON.stringify(G.S)==store,"gracz: animacja kieszeni nie zmienia towaru, zakupów ani pieniędzy")
	inv.inspect_backpack()
	inv.bag_mesh._process(0.6)
	T.ok(is_zero_approx(inv.bag_mesh.lid.rotation.x) and inv.bag_mesh.zipper.position.is_equal_approx(inv.bag_mesh.zipper_start),"gracz: zamknięcie kieszeni przywraca suwak i klapę")
	var before_load:float=inv.bag_mesh.load_ratio
	G.add_pack(G.S.inv,"dym",75,15)
	inv.render()
	T.ok(inv.bag_mesh.load_ratio>before_load,"gracz: zapełnienie plecaka odświeża się po zmianie zawartości")
	for i in range(3):
		inv.preview_pose(i)
		T.ok(String(inv.rig.cur)==["Idle","Walk","Jog_Fwd"][i],"gracz: przycisk podglądu przełącza animację %d"%i)
	inv.preview_pose(0)
	G.ui.close_all()
	G.S=saved
