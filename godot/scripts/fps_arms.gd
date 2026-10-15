extends Node3D
## Widok z pierwszej osoby: ciało gracza (ten sam model i ubranie co w ekwipunku) z ukrytą głową.
## Ręce unoszą się przed kamerą (fps_arms_ik.gd), kołyszą się przy chodzie i nie wchodzą w ściany;
## przy spojrzeniu w dół widać tułów, nogi z animacją chodu i własny cień.

const Chars = preload("res://scripts/chars.gd")
const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")

var player
var rig: Dictionary = {}
var ik: Node
var _sig := ""
var _check := 0.0
var _lim := 0.0
var bag: Node3D = null      # plecak trzymany przed sobą, gdy otwarty jest ekwipunek
var hold := 0.0             # 0 = ręce luzem, 1 = plecak w rękach
var _opened := false


func setup(p) -> void:
	player = p
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	if not rig.is_empty() and is_instance_valid(rig.root):
		rig.root.queue_free()
	rig = {}
	if G.S == null:
		return
	var oid: String = G.outfit()
	var od: Dictionary = D.OUTFITS[oid]
	var look: Dictionary = D.PLAYER_LOOK.duplicate()
	for k in od:
		if k in ["model", "kind", "top", "top2", "bottom", "shoes", "hat", "hat_color", "stripes", "logo", "sleeve", "shorts", "mask"]:
			look[k] = od[k]
	look["no_blob"] = true
	look["model"] = String(od.model)
	look["face"] = String(D.PLAYER_LOOK.get("face", D.PLAYER_LOOK.model))
	look["mask"] = bool(od.get("mask", false))
	look["tall"] = 1.0
	look["build"] = 1.0
	rig = Chars.make(look)
	add_child(rig.root)
	rig.root.rotation.y = PI
	rig.root.position = Vector3(0.0, 0.0, 0.13)
	_sig = _signature()
	Chars.dress(rig, G.S.get("gear", {}))
	ik = load("res://scripts/fps_arms_ik.gd").new()
	ik.name = "FpsArmsIK"
	if ik.bind(rig.skel, player):
		rig.skel.add_child(ik)
	else:
		ik.free()
		ik = null


func _signature() -> String:
	return G.outfit() + "|" + JSON.stringify(G.S.get("gear", {}))


func _process(dt: float) -> void:
	if rig.is_empty():
		_check -= dt
		if _check <= 0.0:
			_check = 1.0
			_build()
		return
	_check -= dt
	if _check <= 0.0:
		_check = 0.5
		if _signature() != _sig:
			_build()
			return
	rig.root.visible = not player.hidden
	_hold_bag(dt)
	if player.crouching:
		Chars.play(rig, "Crouch_Fwd" if player.moving else "Crouch_Idle")
	else:
		var sp := 0.0
		if player.moving:
			sp = 5.5 if player.sprinting else 2.6
		Chars.animate(rig, dt, sp, "")


## Otwarty ekwipunek: plecak zsuwa się z ramienia do rąk, a suwak i klapa otwierają się przed oczami (bez opóźniania okna).
func _hold_bag(dt: float) -> void:
	if OS.get_cmdline_user_args().has("--fpsbag") and G.S != null and G.S.has("upg"):
		G.S.upg["plecak1"] = true   # tylko do zrzutów
	var want: bool = ((G.ui != null and (G.ui.mode == "inv" or G.ui.inv_pre > 0.0)) or OS.get_cmdline_user_args().has("--fpsbag")) and G.S.has("upg") and G.upg("plecak1") and not player.hidden
	hold = move_toward(hold, 1.0 if want else 0.0, dt * 3.2)
	if ik != null:
		ik.hold = hold
	if hold <= 0.001:
		if bag != null:
			bag.visible = false
			bag.opened = false
			_opened = false
		return
	if bag == null:
		bag = load("res://scripts/player_backpack.gd").new()
		player.cam.add_child(bag)
		_set_layer(bag, 1)
		_brighten(bag)
		Props._no_shadow(bag)
		bag.scale = Vector3.ONE * 0.62
		bag.position = Vector3(0.0, -0.31, -0.5)
		bag.rotation = Vector3(-0.55, PI, 0.0)
	bag.visible = true
	bag.configure(G.upg("plecak2"), float(G.carry_total()) / maxf(1.0, float(G.capacity())))
	var k := smoothstep(0.0, 1.0, hold)
	bag.position = Vector3(0.0, lerpf(-0.75, -0.2, k), lerpf(-0.15, -0.46, k))
	if hold > 0.95 and not _opened:
		_opened = true
		bag.inspect()


func _set_layer(n: Node, bit: int) -> void:
	if n is VisualInstance3D:
		n.layers = bit
	for c in n.get_children():
		_set_layer(c, bit)


## ciemny nylon plecaka pod światłem pokoju wychodzi czarny: własne kopie materiałów, rozjaśnione tylko w widoku FPS
func _brighten(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			var m := mi.mesh.surface_get_material(i)
			if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
				var d: BaseMaterial3D = m.duplicate()
				d.albedo_color = Color(1.45, 1.45, 1.45)
				d.roughness = maxf(d.roughness, 0.85)
				mi.set_surface_override_material(i, d)
	for c in n.get_children():
		_brighten(c)
