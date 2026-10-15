extends Node3D
## Widok z pierwszej osoby: ciało gracza (ten sam model i ubranie co w ekwipunku) z ukrytą głową.
## Ręce unoszą się przed kamerą (fps_arms_ik.gd), kołyszą się przy chodzie i nie wchodzą w ściany;
## przy spojrzeniu w dół widać tułów, nogi z animacją chodu i własny cień.

const Chars = preload("res://scripts/chars.gd")

var player
var rig: Dictionary = {}
var ik: Node
var _sig := ""
var _check := 0.0
var _lim := 0.0


func setup(p) -> void:
	player = p
	process_mode = Node.PROCESS_MODE_PAUSABLE
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
	if player.crouching:
		Chars.play(rig, "Crouch_Fwd" if player.moving else "Crouch_Idle")
	else:
		var sp := 0.0
		if player.moving:
			sp = 5.5 if player.sprinting else 2.6
		Chars.animate(rig, dt, sp, "")
