extends Node3D
var shell:Node3D
var load_ratio:=0.0
var phase:=0.0
var motion:=0.0
var base_scale:=Vector3.ONE
var opened:=false
var opening:=0.0
var lid:Node3D
var zipper:Node3D
var zipper_start:=Vector3.ZERO
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	shell=Node3D.new()
	add_child(shell)
	var model=load("res://assets/models/gracz_plecak.glb").instantiate()
	shell.add_child(model)
	lid=model.find_child("Klapa_kieszeni",true,false)
	zipper=model.find_child("Suwak_glowny",true,false)
	if zipper!=null: zipper_start=zipper.position
	set_layer(self)
func set_layer(n:Node):
	if n is VisualInstance3D: n.layers=2
	for c in n.get_children(): set_layer(c)
func configure(big:bool,ratio:float):
	base_scale=Vector3(1.12,1.2,1.12) if big else Vector3.ONE
	load_ratio=clampf(ratio,0,1)
func _process(dt:float):
	if shell==null: return
	phase+=dt
	opening=move_toward(opening,1.0 if opened else 0.0,dt*2.4)
	# Najpierw jedzie suwak, dopiero potem uchyla się klapa; zamknięcie w odwrotnej kolejności.
	if zipper!=null: zipper.position=zipper_start-Vector3(0.192*minf(1.0,opening*1.8),0,0)
	if lid!=null: lid.rotation.x=-0.65*clampf((opening-0.45)/0.55,0,1)
	# Pełniejszy plecak jest grubszy i porusza się wolniej, bez zmiany pojemności ekwipunku.
	shell.scale=base_scale*Vector3(1,1,1+load_ratio*0.28)
	shell.rotation.z=sin(phase*(2.3+motion*2.0-load_ratio*0.5))*(0.018+motion*0.012)
	shell.rotation.x=sin(phase*(1.6+motion*1.2))*(0.012+motion*0.009)
