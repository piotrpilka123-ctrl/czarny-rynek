extends SceneTree
## 7 dób, rzeczywisty wzrost/zdrowie/plon, suszenie 8 h i sprzedaż Matiego.
## Bez nalotów, zmiany popytu i czasu podróży; sprzęt/lokal poza wynikiem operacyjnym.
func _initialize(): call_deferred("check")
func check():
	root.add_child(load("res://scenes/main.tscn").instantiate())
	var game = root.get_node("G")
	while not game.running: await process_frame
	game.test_mode=true
	var rows: Array = []
	for count in [2,6,10]:
		for mode in [0,1]:
			for policy in ["recznie","12_zl","60_zl"]:
				rows.append(simulate(game,count,mode,policy))
	for row in rows: print("WORKER_BALANCE ",JSON.stringify(row))
	quit()
func simulate(game,count: int,mode: int,policy: String) -> Dictionary:
	game.S=game.new_state()
	game.S.lvl=8
	game.S.cash=50000.0
	game.S.props.garaz=true
	game.S.hide.garage.items=[]
	for i in range(int(ceil(count/4.0))): game.S.hide.garage.items.append({"f":"lampa_led","x":0.0,"z":-2.0+i*2.0,"r":0,"mode":mode})
	for i in range(count): game.S.hide.garage.pots.append({"x":-0.6+(i%4)*0.4,"z":-2.0+int(i/4)*2.0,"pl":game.Prod.plant_new()})
	game.S.cash-=15.0*count
	game.S.workers.roman={"paused":false,"next":540.0,"day":1,"paid":0.0,"visits":0,"watered":0,"status":""}
	game.S.dealers.mati={"stock":game.new_store(),"cash":0.0,"sold":0,"paused":false,"next":540.0,"empty_notified":true}
	var at: Vector2 = game.Dealers.position("mati")
	game.player.loc="out"
	game.player.global_position=Vector3(at.x,game.world.height(at.x,at.y),at.y)
	var wages := 0.0
	var bills := 0.0
	var manual_actions := 0
	var grams := 0.0
	var dry_queue: Array = []
	var drying: Dictionary = {}
	var previous_day := 1
	for minute in range(540,540+7*1440,10):
		game.S.t=float(minute)
		if game.day()!=previous_day:
			previous_day=game.day()
			var bill: float = round(float(game.Prod.stats("garage").power))
			game.S.cash-=bill
			bills+=bill
		if policy=="recznie":
			for pot in game.S.hide.garage.pots:
				if float(pot.pl.prog)<1.0 and float(pot.pl.water)<=35.0:
					pot.pl.water=100.0
					manual_actions+=1
		else:
			var before: int = game.S.workers.roman.visits
			game.Workers.tick()
			var new_visits: int = int(game.S.workers.roman.visits)-before
			if new_visits>0:
				wages+=new_visits*(60.0 if policy=="60_zl" else 12.0)
				# Dodatkowa stawka nie zmienia przepustowości ani zasad pielęgnacji.
				game.S.cash-=new_visits*((60.0 if policy=="60_zl" else 12.0)-game.Workers.VISIT)
		game.Prod.plants_tick("garage",10.0,false)
		if game.hour()>=8.0 and game.hour()<22.0:
			for i in range(count):
				var pot: Dictionary = game.S.hide.garage.pots[i]
				if float(pot.pl.prog)<1.0: continue
				var harvest: Dictionary = game.Prod.plant_forecast("garage",i)
				grams+=float(harvest.g)
				dry_queue.append({"g":float(harvest.g),"pur":int(harvest.pur)})
				pot.pl=game.Prod.plant_new()
				game.S.cash-=15.0
		if drying.is_empty() and not dry_queue.is_empty():
			drying=dry_queue.pop_front()
			for index in range(dry_queue.size()-1,-1,-1):
				if int(dry_queue[index].pur)==int(drying.pur) and float(drying.g)+float(dry_queue[index].g)<=90.0:
					drying.g=float(drying.g)+float(dry_queue[index].g)
					dry_queue.remove_at(index)
			drying["end"]=game.S.t+480.0
		if not drying.is_empty() and game.S.t>=float(drying.end):
			game.add_bulk(game.S.inv,"dym",int(drying.pur),float(drying.g))
			drying={}
		for batch in game.stacks(game.S.inv,"bulk"):
			var packs: int = int(float(batch.n)/5.0)
			if packs>0:
				game.take_bulk(game.S.inv,"dym",int(batch.pur),packs*5.0)
				game.add_pack(game.S.inv,"dym",int(batch.pur),packs,5)
				game.S.cash-=packs*0.6
		game.Dealers.supply("mati","dym",40)
		game.Dealers.tick()
		game.Dealers.collect("mati")
	var waiting_g := float(drying.get("g",0.0))
	for batch in dry_queue: waiting_g+=float(batch.g)
	return {"pots":count,"mode":mode,"policy":policy,"harvest_g":grams,"sold_g":game.S.dealers.mati.sold,"wages":wages,"electricity":bills,"manual_minutes":manual_actions*2,"worker_waterings":game.S.workers.roman.watered,"operating_net":snappedf(game.S.cash-50000.0,0.01),"stock_g":game.goods_total(game.S.inv)+game.Dealers.stock("mati"),"dry_queue_g":waiting_g}
