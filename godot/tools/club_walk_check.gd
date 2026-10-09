extends SceneTree
## Celowa kontrola kolizji i chodzenia w klubie, bez okna i dźwięku.
var failed:=0
func _initialize(): call_deferred("check")
func frames(n:int):
	for i in range(n): await process_frame
func ok(pass_test:bool, message:String):
	print("CLUB ","OK " if pass_test else "FAIL ",message)
	if not pass_test: failed+=1
func check():
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var game=root.get_node("G")
	while not game.running: await process_frame
	game.test_mode=true
	game.ui.close_controls()
	await frames(3)
	await load("res://scripts/club_layout_test.gd").run(self)
	quit(0 if failed==0 else 1)
