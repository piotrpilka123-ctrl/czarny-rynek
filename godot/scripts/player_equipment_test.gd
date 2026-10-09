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
	inv.bag_mesh._process(0.3)
	T.ok(inv.bag_mesh.reach_weight>0.99 and inv.bag_mesh.opening<0.01,"gracz: ręce dosięgają plecaka zanim zacznie się otwieranie")
	var reach=inv.rig.skel.find_child("BackpackReach",true,false)
	# Modyfikator działa na rzeczywistym szkielecie, nie na zapisanym stanie ekwipunku.
	if reach==null:
		for child in inv.rig.skel.get_children():
			if child.get_script()==load("res://scripts/backpack_reach.gd"): reach=child
	T.ok(reach!=null and reach.arms.size()==2,"gracz: obie ręce mają poprawne łańcuchy kości do obsługi plecaka")
	if reach!=null:
		reach._process_modification_with_delta(0.0)
		T.ok(reach.last_error<0.02,"gracz: dłonie dosięgają elementów plecaka z dokładnością do dwóch centymetrów")
	inv.inspect_backpack()
	T.ok(inv.bag_mesh.opened,"gracz: wielokrotne kliknięcie nie przerywa trwającego ruchu rąk")
	inv.bag_mesh._process(1.0)
	T.ok(inv.preview_motion==0 and is_equal_approx(inv.spin_rest,PI) and inv.bag_mesh.opening==1.0 and inv.bag_mesh.lid.rotation.x< -0.5,"gracz: obejrzenie plecaka obraca postać, rozsuwa zamek i uchyla kieszeń")
	T.ok(JSON.stringify(G.S)==store,"gracz: animacja kieszeni nie zmienia towaru, zakupów ani pieniędzy")
	inv.inspect_backpack()
	inv.bag_mesh._process(1.3)
	T.ok(is_zero_approx(inv.bag_mesh.lid.rotation.x) and inv.bag_mesh.zipper.position.is_equal_approx(inv.bag_mesh.zipper_start),"gracz: zamknięcie kieszeni przywraca suwak i klapę")
	var before_load:float=inv.bag_mesh.load_ratio
	G.add_pack(G.S.inv,"dym",75,15)
	inv.render()
	T.ok(inv.bag_mesh.load_ratio>before_load,"gracz: zapełnienie plecaka odświeża się po zmianie zawartości")
	for i in range(3):
		inv.preview_pose(i)
		T.ok(String(inv.rig.cur)==["Idle","Walk","Jog_Fwd"][i],"gracz: przycisk podglądu przełącza animację %d"%i)
	inv.inspect_backpack()
	inv.bag_mesh._process(0.3)
	inv.preview_pose(1)
	T.ok(not inv.bag_mesh.interacting and inv.bag_mesh.reach_weight==0.0,"gracz: przejście do chodu zwalnia ręce i przywraca animację ciała")
	inv.set_rig("garnitur")
	await T.frames(3)
	reach=inv.rig.skel.find_child("BackpackReach",true,false)
	inv.inspect_backpack()
	inv.bag_mesh._process(0.3)
	if reach!=null: reach._process_modification_with_delta(0.0)
	T.ok(reach!=null and reach.last_error<0.02,"gracz: zasięg rąk dopasowuje się także do innej sylwetki ubioru")
	inv.set_rig("dres")
	inv.preview_pose(0)
	G.ui.close_all()
	G.S=saved
