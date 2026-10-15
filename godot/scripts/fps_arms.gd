extends Node3D
## Widok z pierwszej osoby: ciało gracza (ten sam model i ubranie co w ekwipunku) z ukrytą głową.
## Ręce unoszą się przed kamerą (fps_arms_ik.gd), kołyszą się przy chodzie i nie wchodzą w ściany;
## przy spojrzeniu w dół widać tułów, nogi z animacją chodu i własny cień.

const Chars = preload("res://scripts/chars.gd")
const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")
const Stations = preload("res://scripts/stations.gd")

var player
var rig: Dictionary = {}
var ik: Node
var _sig := ""
var _check := 0.0
var _lim := 0.0
var bag: Node3D = null      # plecak trzymany przed sobą, gdy otwarty jest ekwipunek
var hold := 0.0             # 0 = ręce luzem, 1 = plecak w rękach
var _opened := false
var phone: Node3D = null    # telefon w prawej ręce, gdy otwarta jest aplikacja telefonu
var phone_hold := 0.0
var pack: Node3D = null     # paczka w wyciągniętych dłoniach przy wymianie z klientem
var give := 0.0
var _spd := 0.0
var _ang := 0.0


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
	rig.root.position = Vector3(0.0, -0.03, 0.26)
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
	_hold_phone(dt)
	_hold_give(dt)
	# prędkość i kierunek ruchu bierzemy z faktycznego ruchu gracza (wygładzone, żeby chwilowe zatrzymania o ścianę nie przeskakiwały w idle)
	var vel := Vector2(player.velocity.x, player.velocity.z)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fpswalk="):   # tylko do zrzutów: sztuczna prędkość i kierunek (m/s, stopnie względem patrzenia)
			var q := a.substr(10).split(",")
			vel = Vector2(0.0, -1.0).rotated(deg_to_rad(float(q[1])) - player.rotation.y) * float(q[0])
	_spd = lerpf(_spd, vel.length(), minf(1.0, dt * 10.0))
	var ang := 0.0
	var rev := false
	if vel.length() > 0.3:
		var lv: Vector3 = player.global_transform.basis.inverse() * Vector3(vel.x, 0.0, vel.y)
		ang = atan2(lv.x, -lv.z)
		if absf(ang) > 2.0:
			rev = true
			ang -= signf(ang) * PI
	_ang = lerp_angle(_ang, ang, minf(1.0, dt * 8.0))
	rig.root.rotation.y = PI - _ang * 0.55
	if player.crouching:
		if _spd > 0.4:
			Chars.play(rig, "Crouch_Fwd", clampf(_spd / float(Chars.ANIM_SPEED["Crouch_Fwd"]), 0.6, 2.0))
		else:
			Chars.play(rig, "Crouch_Idle")
	else:
		Chars.animate(rig, dt, _spd if _spd > 0.5 else 0.0, "")
	if rev and _spd > 0.5:
		rig.anim.speed_scale = -absf(rig.anim.speed_scale)


## plecak w rękach tylko wtedy, gdy gracz sam otworzył ekwipunek klawiszem w świecie (nie przy interakcjach: waga, stół, skrytka, szafa)
func bag_wanted() -> bool:
	if G.ui == null or G.S == null or not G.S.has("upg") or not G.upg("plecak1") or player.hidden:
		return OS.get_cmdline_user_args().has("--fpsbag")
	return G.ui.inv_pre > 0.0 or (G.ui.mode == "inv" and G.ui.inv_held) or OS.get_cmdline_user_args().has("--fpsbag")


## Otwarty ekwipunek: plecak zsuwa się z ramienia do rąk, a suwak i klapa otwierają się przed oczami (bez opóźniania okna).
func _hold_bag(dt: float) -> void:
	if OS.get_cmdline_user_args().has("--fpsbag") and G.S != null and G.S.has("upg"):
		G.S.upg["plecak1"] = true   # tylko do zrzutów
	var want := bag_wanted()
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


## Otwarty telefon: prawa dłoń unosi smartfon ekranem do oczu (lewa zostaje luzem).
func _hold_phone(dt: float) -> void:
	var want: bool = (G.ui != null and G.ui.mode == "phone") or OS.get_cmdline_user_args().has("--fpsphone")
	phone_hold = move_toward(phone_hold, 1.0 if (want and not player.hidden and hold < 0.5) else 0.0, dt * 4.0)
	if ik != null:
		ik.phone = phone_hold
	if phone_hold <= 0.001:
		if phone != null:
			phone.visible = false
		return
	if phone == null:
		var ps: PackedScene = load("res://assets/models/gracz_telefon.glb")
		if ps == null:
			return
		phone = ps.instantiate()
		player.cam.add_child(phone)
		Props._no_shadow(phone)
	phone.visible = true
	var k := smoothstep(0.0, 1.0, phone_hold)
	phone.position = Vector3(lerpf(0.2, 0.09, k), lerpf(-0.5, -0.1, k), lerpf(-0.3, -0.33, k))
	phone.rotation = Vector3(lerpf(0.0, 0.32, k), 0.0, lerpf(0.0, -0.06, k))


## Wymiana z klientem: obie dłonie wysuwają się do przodu z paczką, jak przy podaniu z ręki do ręki.
func _hold_give(dt: float) -> void:
	var want: bool = (G.ui != null and G.ui.deal_npc != null and G.ui.mode == "modal") or OS.get_cmdline_user_args().has("--fpsdeal")
	give = move_toward(give, 1.0 if (want and not player.hidden) else 0.0, dt * 3.0)
	if ik != null:
		ik.give = give
	if give <= 0.001:
		if pack != null:
			pack.visible = false
		return
	if pack == null:
		pack = Stations.brick("dym")
		player.cam.add_child(pack)
		Props._no_shadow(pack)
	pack.visible = true
	var k := smoothstep(0.0, 1.0, give)
	pack.position = Vector3(0.0, -0.255, -0.52)
	pack.rotation = Vector3(-0.1, 0.35, 0.0)
	pack.scale = Vector3.ONE * lerpf(0.85, 1.0, k)
