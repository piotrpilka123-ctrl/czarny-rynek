extends Node3D
## Krótka prezentacja opłaconej wizyty; nie wykonuje ponownie pielęgnacji ani opłat.
const Chars = preload("res://scripts/chars.gd")
const Stations = preload("res://scripts/stations.gd")
var rig: Dictionary = {}
var work_event := -1.0
func _process(dt: float) -> void:
	var state: Dictionary = G.S.get("workers",{}).get("roman",{})
	var working: bool = G.running and G.player!=null and G.player.loc=="garage" and not state.is_empty() and G.S.t<float(state.get("visual_until",0.0))
	visible=working
	if not working:
		if not rig.is_empty(): Chars.set_active(rig,false)
		return
	if rig.is_empty():
		rig=Chars.make({"model":"m09","seed":94})
		add_child(rig.root)
		var can := Stations.watering_can()
		can.scale=Vector3.ONE*0.7
		can.position=Vector3(0.28,0.02,0.38)
		rig.root.add_child(can)
	if work_event!=float(state.get("last_work",-1.0)):
		var target: Dictionary = state.get("work_at",{})
		var pot := Vector2(float(D.ROOMS.garage.cx)+float(target.get("x",0.0)),float(target.get("z",0.0)))
		var candidate := pot+Vector2(0,0.8)
		var found := false
		for offset in [Vector2(0,0.8),Vector2(0.8,0),Vector2(0,-0.8),Vector2(-0.8,0),Vector2(0,1.2),Vector2(1.2,0),Vector2(0,-1.2),Vector2(-1.2,0),Vector2(0.8,0.8),Vector2(0.8,-0.8)]:
			var at: Vector2 = pot+offset
			if G.player.fits_at(Vector3(at.x,0,at.y),true) and Vector2(G.player.global_position.x,G.player.global_position.z).distance_to(at)>0.85:
				candidate=at
				found=true
				break
		if not found:
			visible=false
			Chars.set_active(rig,false)
			return
		work_event=float(state.last_work)
		position=Vector3(candidate.x,0,candidate.y)
		rotation.y=atan2(pot.x-candidate.x,pot.y-candidate.y)
	Chars.set_active(rig,true)
	Chars.animate(rig,dt,0.0,"kneel")
