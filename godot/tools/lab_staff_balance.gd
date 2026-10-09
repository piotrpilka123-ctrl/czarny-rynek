extends SceneTree
## Jedna partia + sprzedaż przez dealera; bez sprzętu, rekrutacji, podróży i nalotów.
func _initialize(): call_deferred("check")
func check():
	root.add_child(load("res://scenes/main.tscn").instantiate())
	var game=root.get_node("G")
	var data=root.get_node("D")
	while not game.running: await process_frame
	game.test_mode=true
	for rid in ["amfetamina","metamfetamina","kokaina"]:
		for assisted in [false,true]:
			game.S=game.new_state()
			game.S.cash=50000.0
			game.S.lvl=10
			game.S.props.garaz=true
			game.S.hide.garage.items=[{"f":"lab","x":0.0,"z":0.0,"r":0}]
			var recipe: Dictionary=data.RECIPES[rid]
			var cost:=0.0
			for ingredient in recipe.input:
				game.S.items[ingredient]=recipe.input[ingredient]
				for item in data.SHOP:
					if item.id==ingredient: cost+=float(item.price)*int(recipe.input[ingredient])/int(item.n)
			game.S.cash-=cost
			if assisted: game.S.labstaff={"paused":false,"next":540.0,"day":1,"actions_today":0,"actions":0,"paid":0.0,"status":""}
			if not game.Prod.start("garage",0,rid): print("LAB_BALANCE FAIL start ",rid); quit(1); return
			var start: float=game.S.t
			for step in range(500):
				game.S.t=start+step*10.0
				var job=game.Prod.job("garage",0)
				if assisted: game.LabStaff.tick()
				elif int(job.hold)>=0 and float(job.hold_t)>=8.0: game.Prod.proceed("garage",0,false)
				game.Prod.tick(10.0)
				if float(job.prog)>=1.0: break
			var finish: float=game.S.t
			var result: Dictionary=game.Prod.collect("garage",0)
			var id: String="mati" if rid=="amfetamina" else "darek"
			game.S.dealers[id]={"stock":game.new_store(),"cash":0.0,"sold":0,"paused":false,"next":game.S.t,"empty_notified":true}
			var at: Vector2=game.Dealers.position(id)
			game.player.loc="out"
			game.player.global_position=Vector3(at.x,0,at.y)
			var moved: float=game.take_bulk(game.S.stash.garage,result.p,result.pur,result.g)
			game.add_pack(game.S.inv,result.p,result.pur,int(moved))
			game.S.cash-=ceil(moved/20.0)*12.0
			var sold_day:=0
			for hour in range(int(ceil(game.S.t/60.0)),int(ceil(game.S.t/60.0))+7*24):
				game.S.t=hour*60.0
				game.Dealers.supply(id,result.p,40)
				game.Dealers.tick()
				game.Dealers.collect(id)
				if game.Dealers.stock(id)+game.packed_total(game.S.inv)==0: sold_day=game.day(); break
			print("LAB_BALANCE ",JSON.stringify({"recipe":rid,"assisted":assisted,"production_hours":snappedf((finish-start)/60.0,0.01),"g":result.g,"pur":result.pur,"labor":int(game.S.labstaff.get("actions",0))*120,"sold_g":game.S.dealers[id].sold,"sold_day":sold_day,"net":game.S.cash-50000.0}))
	quit()
