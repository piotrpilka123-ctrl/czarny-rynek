extends RefCounted
## Realistyczne postacie z biblioteki Microsoft Rocketbox (licencja MIT): gotowe modele ludzi w ubraniach.
## Animacje z „Universal Animation Library” (CC0) są przenoszone na ich szkielet (3ds Max Biped):
## dla każdej kości liczymy obrót w przestrzeni modelu względem pozy spoczynkowej źródła
## i nakładamy go na pozę spoczynkową celu, wcześniej „ustawioną” jak źródło (ręce z pozy A do T).

const DIR := "res://assets/people/"

## kość celu <- kość źródła
const BODY := {
	"Bip01 Pelvis": "pelvis", "Bip01 Spine": "spine_01", "Bip01 Spine1": "spine_02", "Bip01 Spine2": "spine_03", "Bip01 Neck": "neck_01", "Bip01 Head": "Head",
	"Bip01 L Clavicle": "clavicle_l", "Bip01 L UpperArm": "upperarm_l", "Bip01 L Forearm": "lowerarm_l", "Bip01 L Hand": "hand_l",
	"Bip01 R Clavicle": "clavicle_r", "Bip01 R UpperArm": "upperarm_r", "Bip01 R Forearm": "lowerarm_r", "Bip01 R Hand": "hand_r",
	"Bip01 L Thigh": "thigh_l", "Bip01 L Calf": "calf_l", "Bip01 L Foot": "foot_l", "Bip01 L Toe0": "ball_l",
	"Bip01 R Thigh": "thigh_r", "Bip01 R Calf": "calf_r", "Bip01 R Foot": "foot_r", "Bip01 R Toe0": "ball_r",
}
const FINGER_SRC := ["thumb", "index", "middle", "ring", "pinky"]
## kości, których kierunek w pozie spoczynkowej wyrównujemy do źródła: kość -> jej „dziecko” wyznaczające kierunek
const ALIGN := {
	"Bip01 L UpperArm": "Bip01 L Forearm", "Bip01 L Forearm": "Bip01 L Hand", "Bip01 L Hand": "Bip01 L Finger2",
	"Bip01 R UpperArm": "Bip01 R Forearm", "Bip01 R Forearm": "Bip01 R Hand", "Bip01 R Hand": "Bip01 R Finger2",
	"Bip01 L Thigh": "Bip01 L Calf", "Bip01 L Calf": "Bip01 L Foot",
	"Bip01 R Thigh": "Bip01 R Calf", "Bip01 R Calf": "Bip01 R Foot",
}
const RATE := 30.0
const HIP := 0.895
const ARM_IN := 13.0         # o ile stopni dociągnąć wiszące ramię do tułowia
const FINGER_OPEN := 0.5     # rozluźnienie dłoni (0 = pięść z animacji, 1 = płaska dłoń)

static var _scene := {}
static var _info := {}
static var _mats := {}
static var _libs := {}


static func exists(model: String) -> bool:
	return ResourceLoader.exists(DIR + "%s/%s.fbx" % [model, model])


static func _load(model: String) -> PackedScene:
	if not _scene.has(model):
		_scene[model] = load(DIR + "%s/%s.fbx" % [model, model])
	return _scene[model]


static func _tex(model: String, file: String) -> Texture2D:
	var p := DIR + "%s/%s" % [model, file]
	return load(p) if ResourceLoader.exists(p) else null


## materiał dla powierzchni siatki; nazwa materiału w pliku kończy się nazwą części (body, head, opacity, …)
static func _material(model: String, surf_name: String) -> Material:
	var part := surf_name.substr(surf_name.find("_") + 1).to_lower()
	if part == "equpiment":      # literówka w jednym z plików źródłowych
		part = "equipment"
	var key := model + "|" + part
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var is_hair := part.ends_with("opacity")
	m.albedo_texture = _tex(model, "%s_%s.%s" % [model, part, "png" if is_hair else "jpg"])
	if m.albedo_texture == null:
		m.albedo_color = Color(0.2, 0.2, 0.22)
	var nt := _tex(model, "%s_%s_n.jpg" % [model, part])
	if nt != null:
		m.normal_enabled = true
		m.normal_texture = nt
	m.roughness = 0.82 if part == "body" else 0.7
	m.metallic_specular = 0.3
	if is_hair:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.42
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.6
	_mats[key] = m
	return m


static var _hide_mat: StandardMaterial3D = null

static func _hidden() -> StandardMaterial3D:
	if _hide_mat == null:
		_hide_mat = StandardMaterial3D.new()
		_hide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hide_mat.albedo_color = Color(0, 0, 0, 0)
		_hide_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _hide_mat


static func _q(b: Basis) -> Quaternion:
	return b.orthonormalized().get_rotation_quaternion()


static func _dir(sk: Skeleton3D, a: String, b: String) -> Vector3:
	var ia := sk.find_bone(a)
	var ib := sk.find_bone(b)
	if ia < 0 or ib < 0:
		return Vector3.ZERO
	var d := sk.get_bone_global_rest(ib).origin - sk.get_bone_global_rest(ia).origin
	return d.normalized() if d.length() > 0.0001 else Vector3.ZERO


static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	if from == Vector3.ZERO or to == Vector3.ZERO or from.dot(to) > 0.99999:
		return Quaternion.IDENTITY
	return Quaternion(from, to)


## mapa kości (z palcami) dla danego szkieletu celu
static func _bone_map(tgt: Skeleton3D) -> Dictionary:
	var map := BODY.duplicate()
	for side in ["L", "R"]:
		for f in range(5):
			for j in range(3):
				var tn := "Bip01 %s Finger%d%s" % [side, f, "" if j == 0 else str(j)]
				if tgt.find_bone(tn) >= 0:
					map[tn] = "%s_0%d_%s" % [FINGER_SRC[f], j + 1, side.to_lower()]
	return map


## Przenosi bibliotekę animacji `src_lib` (dla szkieletu `src`) na szkielet `tgt`.
static func retarget(src_lib: AnimationLibrary, src: Skeleton3D, tgt: Skeleton3D, skel_path := "Skeleton3D") -> AnimationLibrary:
	var map := _bone_map(tgt)
	var ns := src.get_bone_count()
	var nt := tgt.get_bone_count()
	# --- stałe dla źródła
	var s_parent := PackedInt32Array()
	var s_rest_q: Array = []
	var s_grest_q: Array = []
	for i in range(ns):
		s_parent.append(src.get_bone_parent(i))
		s_rest_q.append(_q(src.get_bone_rest(i).basis))
		s_grest_q.append(_q(src.get_bone_global_rest(i).basis))
	# --- stałe dla celu
	var t_parent := PackedInt32Array()
	var t_rest_q: Array = []
	var t_src := PackedInt32Array()      # indeks kości źródła albo -1
	var t_c: Array = []                  # stała korekta: R_s^-1 * A * R_t
	var t_finger := PackedByteArray()
	var t_arm := PackedInt32Array()      # +1 lewe ramię, -1 prawe, 0 reszta
	for i in range(nt):
		var nm := tgt.get_bone_name(i)
		t_arm.append(1 if nm == "Bip01 L UpperArm" else (-1 if nm == "Bip01 R UpperArm" else 0))
		t_parent.append(tgt.get_bone_parent(i))
		t_rest_q.append(_q(tgt.get_bone_rest(i).basis))
		var si := src.find_bone(String(map[nm])) if map.has(nm) else -1
		t_src.append(si)
		t_finger.append(1 if nm.contains("Finger") else 0)
		if si < 0:
			t_c.append(Quaternion.IDENTITY)
			continue
		var a := Quaternion.IDENTITY
		var sn := String(map[nm])
		if ALIGN.has(nm):
			a = _arc(_dir(tgt, nm, ALIGN[nm]), _dir(src, sn, String(map.get(ALIGN[nm], ""))))
		elif t_finger[i] == 1:
			# palec: kierunek do następnego paliczka; ostatni paliczek dziedziczy korektę po poprzednim
			var kids := tgt.get_bone_children(i)
			var skids := src.get_bone_children(si)
			if kids.size() > 0 and skids.size() > 0:
				a = _arc(_dir(tgt, nm, tgt.get_bone_name(kids[0])), _dir(src, sn, src.get_bone_name(skids[0])))
			else:
				var pi := t_parent[i]
				var psi := s_parent[si]
				a = _arc(_dir(tgt, tgt.get_bone_name(pi), nm), _dir(src, src.get_bone_name(psi), sn))
		t_c.append((s_grest_q[si] as Quaternion).inverse() * a * _q(tgt.get_bone_global_rest(i).basis))
	var bip := tgt.find_bone("Bip01")
	var bip_rest := tgt.get_bone_global_rest(bip).origin if bip >= 0 else Vector3(0, HIP, 0)
	var s_root := src.find_bone("root")
	var s_pel := src.find_bone("pelvis")
	var o_rest := src.get_bone_global_rest(s_pel).origin
	var ratio := bip_rest.y / maxf(0.01, o_rest.y)
	var out := AnimationLibrary.new()
	for an in src_lib.get_animation_list():
		var a: Animation = src_lib.get_animation(an)
		# ścieżki źródła według kości
		var rt := PackedInt32Array()
		rt.resize(ns)
		rt.fill(-1)
		var pt_root := -1
		var pt_pel := -1
		for t in range(a.get_track_count()):
			var bn := String(a.track_get_path(t)).get_slice(":", 1)
			var bi := src.find_bone(bn)
			if bi < 0:
				continue
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rt[bi] = t
			elif a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				if bi == s_root:
					pt_root = t
				elif bi == s_pel:
					pt_pel = t
		var na := Animation.new()
		na.length = a.length
		na.loop_mode = a.loop_mode
		var tr := PackedInt32Array()
		tr.resize(nt)
		tr.fill(-1)
		for i in range(nt):
			if t_src[i] >= 0:
				var ti := na.add_track(Animation.TYPE_ROTATION_3D)
				na.track_set_path(ti, NodePath("%s:%s" % [skel_path, tgt.get_bone_name(i)]))
				tr[i] = ti
		var ptrack := -1
		if bip >= 0:
			ptrack = na.add_track(Animation.TYPE_POSITION_3D)
			na.track_set_path(ptrack, NodePath("%s:Bip01" % skel_path))
		var steps: int = maxi(1, int(ceil(a.length * RATE)))
		var gs: Array = []
		gs.resize(ns)
		var gt: Array = []
		gt.resize(nt)
		for k in range(steps + 1):
			var tm := minf(a.length, float(k) / float(steps) * a.length)
			for i in range(ns):
				var ql: Quaternion = a.rotation_track_interpolate(rt[i], tm) if rt[i] >= 0 else s_rest_q[i]
				gs[i] = ql if s_parent[i] < 0 else (gs[s_parent[i]] as Quaternion) * ql
			for i in range(nt):
				if k > 0 and t_finger[i] == 1:
					continue
				var pg: Quaternion = Quaternion.IDENTITY if t_parent[i] < 0 else gt[t_parent[i]]
				if t_src[i] >= 0:
					var g: Quaternion = (gs[t_src[i]] as Quaternion) * (t_c[i] as Quaternion)
					if t_arm[i] != 0:
						# animacje powstały dla barczystego manekina, który trzyma ręce daleko od tułowia;
						# gdy ramię wisi w dół, dociągamy je do ciała (uniesionych rąk to nie rusza)
						var dir := g * Vector3.RIGHT
						var w := smoothstep(0.62, 0.93, -dir.y)
						if w > 0.001:
							g = Quaternion(Vector3.BACK, deg_to_rad(ARM_IN) * w * float(-t_arm[i])) * g
					gt[i] = g
					var lq := (pg.inverse() * g).normalized()
					if t_finger[i] == 1:
						lq = lq.slerp(t_rest_q[i], FINGER_OPEN)
					na.rotation_track_insert_key(tr[i], tm, lq)
				else:
					gt[i] = pg * (t_rest_q[i] as Quaternion)
			if ptrack >= 0:
				var rq: Quaternion = a.rotation_track_interpolate(rt[s_root], tm) if rt[s_root] >= 0 else s_rest_q[s_root]
				var rp: Vector3 = a.position_track_interpolate(pt_root, tm) if pt_root >= 0 else src.get_bone_rest(s_root).origin
				var pp: Vector3 = a.position_track_interpolate(pt_pel, tm) if pt_pel >= 0 else src.get_bone_rest(s_pel).origin
				var o := rp + rq * pp
				na.position_track_insert_key(ptrack, tm, bip_rest + (o - o_rest) * ratio)
		out.add_animation(an, na)
	return out


## biblioteka animacji dla modeli Rocketbox (wspólna dla wszystkich — ten sam szkielet); `src_*` z chars.gd
static func is_female(model: String) -> bool:
	return model.begins_with("f")


static func library(model: String, src_lib: AnimationLibrary, src_scene: PackedScene, _female := false) -> AnimationLibrary:
	var key := "f" if is_female(model) else "m"
	if _libs.has(key):
		return _libs[key]
	var baked := DIR + "anim_%s.res" % key
	if ResourceLoader.exists(baked):
		_libs[key] = load(baked)
		return _libs[key]
	var si: Node = src_scene.instantiate()
	var ti: Node = _load(model).instantiate()
	var lib := retarget(src_lib, si.find_child("Skeleton3D", true, false), ti.find_child("Skeleton3D", true, false))
	si.free()
	ti.free()
	_libs[key] = lib
	return lib


## Tworzy postać z gotowego modelu. Zwraca {model, skel, body, hip} albo {} gdy modelu nie ma.
## `face`: model, z którego bierzemy twarz (tekstury głowy) — strój zmienia sylwetkę i ubranie, twarz zostaje ta sama.
## Awatary mają wspólny układ UV głowy, więc wystarczy podmienić materiał; włosy z kart (opacity) cudzego modelu chowamy.
static func instance(model: String, face := "") -> Dictionary:
	if not exists(model):
		return {}
	if face == model or not exists(face):
		face = ""
	var inst: Node3D = _load(model).instantiate()
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var old: Node = inst.find_child("AnimationPlayer", true, false)
	if old != null:
		inst.remove_child(old)
		old.free()
	var body: MeshInstance3D = null
	for c in skel.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			if body == null:
				body = mi
			for s in range(mi.mesh.get_surface_count()):
				var src: Material = mi.mesh.surface_get_material(s)
				var nm := src.resource_name if src != null else "x_body"
				var part := nm.substr(nm.find("_") + 1).to_lower()
				if face != "" and part == "head":
					mi.set_surface_override_material(s, _material(face, "x_head"))
				elif face != "" and part.ends_with("opacity"):
					mi.set_surface_override_material(s, _hidden())
				else:
					mi.set_surface_override_material(s, _material(model, nm))
			mi.extra_cull_margin = 0.6
	var bip := skel.find_bone("Bip01")
	var hip := skel.get_bone_global_rest(bip).origin.y if bip >= 0 else HIP
	var head := skel.find_bone("Bip01 Head")
	var top := (skel.get_bone_global_rest(head).origin.y + 0.2) if head >= 0 else 1.78
	return {"model": inst, "skel": skel, "body": body, "hip": hip, "top": top}
