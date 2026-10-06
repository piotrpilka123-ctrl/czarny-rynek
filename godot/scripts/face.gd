extends SkeletonModifier3D
## Mimika na kościach twarzy (modele Rocketbox): mruganie, ruch gałek ocznych, poruszanie ustami przy mówieniu
## i miny mieszane wagami — nakładane na animację ciała, więc działają w każdej pozie.
## Te same przesunięcia sprawdza poza grą tools/blender/twarz_test.py (wartości: tools/blender/miny.json).
## Liczy się tylko z bliska: dalej niż NEAR metrów od kamery twarzy i tak nie widać.

const NEAR := 15.0
## przesunięcia kości w ułamkach rozstawu oczu: [na zewnątrz (kości z gwiazdką) albo w prawo, w górę, do przodu]; jaw = stopnie
const MINY := {
	"usmiech": {"jaw": 2.0, "bones": {"*MouthCorner": [0.1, 0.11, -0.03], "*Cheek": [0.03, 0.07, 0.01], "*Caninus": [0.02, 0.05, 0.0], "*EyeBlinkBottom": [0.0, 0.035, 0.0], "*Upperlip": [0.01, 0.02, 0.0], "*OuterEyebrow": [0.0, 0.015, 0.0]}},
	"zlosc": {"jaw": 0.0, "bones": {"*InnerEyebrow": [-0.045, -0.085, 0.01], "MMiddleEyebrow": [0.0, -0.06, 0.01], "*OuterEyebrow": [0.0, 0.02, 0.0], "*MouthCorner": [-0.02, -0.045, 0.0], "*Upperlip": [0.0, 0.025, 0.0], "*EyeBlinkTop": [0.0, -0.03, 0.0]}},
	"smutek": {"jaw": 0.0, "bones": {"*InnerEyebrow": [0.0, 0.085, 0.0], "MMiddleEyebrow": [0.0, 0.04, 0.0], "*OuterEyebrow": [0.0, -0.035, 0.0], "*MouthCorner": [0.0, -0.065, 0.0], "*EyeBlinkTop": [0.0, -0.04, 0.0]}},
	"zdziwienie": {"jaw": 6.0, "bones": {"*InnerEyebrow": [0.0, 0.11, 0.0], "MMiddleEyebrow": [0.0, 0.1, 0.0], "*OuterEyebrow": [0.0, 0.1, 0.0], "*EyeBlinkTop": [0.0, 0.04, 0.0]}},
	"mowa": {"jaw": 8.0, "bones": {"*MouthCorner": [-0.03, 0.0, 0.01], "*Upperlip": [0.0, 0.02, 0.0]}},
}

var base := {}            # mina „na stałe”: nazwa → waga (charakter postaci, nastrój)
var emote := {}           # mina chwilowa: nazwa → [waga, ile sekund zostało]
var chatter := 0.0        # stałe gadanie (pozy rozmowy): 0…1
var say_t := 0.0          # ile sekund jeszcze mówi (po zagadaniu)
var _w := {}              # bieżące wagi min
var _bones := {}          # nazwa kości → indeks
var _terms := {}          # mina → [[indeks kości, Vector3 w osiach twarzy (prawo, góra, przód)], …]
var _head := -1
var _jaw := -1
var _jaw_sign := 1.0
var _ax := Basis()        # osie twarzy (prawo, góra, przód) w układzie kości głowy
var _ied := 0.06
var _blink_in := 2.0
var _blink := -1.0        # < 0 = oczy otwarte; inaczej faza mrugnięcia 0…1
var _gaze := Vector2.ZERO
var _gaze_to := Vector2.ZERO
var _gaze_in := 1.0
var _ph := 0.0
var _lids := []           # [[górna, dolna], [górna, dolna]]
var _eyes := []


func bind(sk: Skeleton3D) -> bool:
	for nm in ["Bip01 Head", "Bip01 REye", "Bip01 LEye", "Bip01 MJaw", "Bip01 MBottomLip", "Bip01 MUpperLip", "Bip01 MMiddleEyebrow", "Bip01 MNose",
			"Bip01 REyeBlinkTop", "Bip01 LEyeBlinkTop", "Bip01 REyeBlinkBottom", "Bip01 LEyeBlinkBottom"]:
		var i := sk.find_bone(nm)
		if i < 0:
			return false
		_bones[nm] = i
	_head = _bones["Bip01 Head"]
	_jaw = _bones["Bip01 MJaw"]
	var r := sk.get_bone_global_rest(_bones["Bip01 REye"]).origin
	var l := sk.get_bone_global_rest(_bones["Bip01 LEye"]).origin
	var mid := (r + l) * 0.5
	var right := (r - l).normalized()
	var up := sk.get_bone_global_rest(_bones["Bip01 MMiddleEyebrow"]).origin - sk.get_bone_global_rest(_bones["Bip01 MUpperLip"]).origin
	up = (up - right * up.dot(right)).normalized()
	var fwd := right.cross(up)
	if (sk.get_bone_global_rest(_bones["Bip01 MNose"]).origin - mid).dot(fwd) < 0.0:
		fwd = -fwd
	_ied = (r - l).length()
	var hb := sk.get_bone_global_rest(_head).basis.orthonormalized()
	_ax = hb.inverse() * Basis(right, up, fwd)
	# w którą stronę obraca się żuchwa, żeby broda poszła w dół
	var jo := sk.get_bone_global_rest(_jaw).origin
	var chin := sk.get_bone_global_rest(_bones["Bip01 MBottomLip"]).origin - jo
	_jaw_sign = -1.0 if chin.rotated(right, 0.2).dot(up) > chin.dot(up) else 1.0
	for mina in MINY:
		var list := []
		var bs: Dictionary = MINY[mina].bones
		for key in bs:
			var off: Array = bs[key]
			if String(key).begins_with("*"):
				for side in ["R", "L"]:
					var bi := sk.find_bone("Bip01 " + side + String(key).substr(1))
					if bi >= 0:
						list.append([bi, Vector3(float(off[0]) * (1.0 if side == "R" else -1.0), float(off[1]), float(off[2]))])
			else:
				var bi2 := sk.find_bone("Bip01 " + String(key))
				if bi2 >= 0:
					list.append([bi2, Vector3(float(off[0]), float(off[1]), float(off[2]))])
		_terms[mina] = list
		_w[mina] = 0.0
	_lids = [[_bones["Bip01 REyeBlinkTop"], _bones["Bip01 REyeBlinkBottom"]], [_bones["Bip01 LEyeBlinkTop"], _bones["Bip01 LEyeBlinkBottom"]]]
	_eyes = [_bones["Bip01 REye"], _bones["Bip01 LEye"]]
	_blink_in = randf_range(0.5, 4.0)
	_ph = randf() * 10.0
	return true


## mina chwilowa (po kilku sekundach sama gaśnie)
func flash(mina: String, weight := 1.0, secs := 2.5) -> void:
	if MINY.has(mina):
		emote[mina] = [weight, secs]


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _head < 0:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and cam.global_position.distance_squared_to(sk.global_position + Vector3(0, 1.6, 0)) > NEAR * NEAR:
		return
	_ph += delta
	# --- wagi min: stały nastrój + to, co postać właśnie przeżywa + mówienie
	say_t = maxf(0.0, say_t - delta)
	var speak := maxf(chatter, 1.0 if say_t > 0.0 else 0.0)
	for mina in _w:
		var target: float = float(base.get(mina, 0.0))
		if emote.has(mina):
			var e: Array = emote[mina]
			e[1] = float(e[1]) - delta
			if float(e[1]) <= 0.0:
				emote.erase(mina)
			else:
				target = maxf(target, float(e[0]) * minf(1.0, float(e[1]) / 0.6))
		if mina == "mowa":
			# usta ruszają się sylabami: szybkie otwarcia o różnej wielkości, z pauzami między słowami
			var syl := maxf(0.0, sin(_ph * 13.0) * 0.5 + 0.5) * (0.55 + 0.45 * sin(_ph * 3.1 + 1.0))
			var pause := 1.0 if sin(_ph * 0.9) > -0.55 else 0.0
			target = speak * syl * pause
			_w[mina] = lerpf(float(_w[mina]), target, minf(1.0, delta * 22.0))
		else:
			_w[mina] = lerpf(float(_w[mina]), target, minf(1.0, delta * 5.0))
	# --- mruganie
	_blink_in -= delta
	if _blink < 0.0 and _blink_in <= 0.0:
		_blink = 0.0
	var lid := 0.0
	if _blink >= 0.0:
		_blink += delta / 0.16
		lid = sin(clampf(_blink, 0.0, 1.0) * PI)
		if _blink >= 1.0:
			_blink = -1.0
			_blink_in = randf_range(0.25, 0.5) if randf() < 0.12 else randf_range(2.2, 5.6)
	# --- wzrok: krótkie skoki, potem chwila spokoju
	_gaze_in -= delta
	if _gaze_in <= 0.0:
		_gaze_in = randf_range(0.7, 2.6)
		_gaze_to = Vector2(randf_range(-0.12, 0.12), randf_range(-0.05, 0.06)) if randf() < 0.75 else Vector2.ZERO
	_gaze = _gaze.lerp(_gaze_to, minf(1.0, delta * 14.0))
	var hb := sk.get_bone_global_pose(_head).basis.orthonormalized() * _ax
	var right := hb.x
	var up := hb.y
	var fwd := hb.z
	# --- żuchwa (najpierw, bo dolna warga jest jej dzieckiem)
	var jaw := 0.0
	for mina in _w:
		jaw += float(MINY[mina].jaw) * float(_w[mina])
	if absf(jaw) > 0.05:
		var gj := sk.get_bone_global_pose(_jaw)
		gj.basis = Basis(right, deg_to_rad(jaw) * _jaw_sign) * gj.basis
		sk.set_bone_global_pose(_jaw, gj)
	# --- miny: przesunięcia kości w osiach twarzy
	var moved := {}
	for mina in _w:
		var w: float = _w[mina]
		if w < 0.01:
			continue
		for t in _terms[mina]:
			var o: Vector3 = t[1]
			moved[t[0]] = (moved.get(t[0], Vector3.ZERO) as Vector3) + (right * o.x + up * o.y + fwd * o.z) * (_ied * w)
	for bi in moved:
		var g := sk.get_bone_global_pose(int(bi))
		g.origin += moved[bi]
		sk.set_bone_global_pose(int(bi), g)
	# --- powieki: górna schodzi do dolnej
	if lid > 0.01:
		for pair in _lids:
			var gt := sk.get_bone_global_pose(int(pair[0]))
			var gb := sk.get_bone_global_pose(int(pair[1]))
			var d := gb.origin - gt.origin
			gt.origin += d * 0.82 * lid
			gb.origin -= d * 0.1 * lid
			sk.set_bone_global_pose(int(pair[0]), gt)
			sk.set_bone_global_pose(int(pair[1]), gb)
	# --- gałki oczne
	if _gaze.length() > 0.005:
		var rot := Basis(up, _gaze.x) * Basis(right, _gaze.y)
		for ei in _eyes:
			var ge := sk.get_bone_global_pose(int(ei))
			ge.basis = rot * ge.basis
			sk.set_bone_global_pose(int(ei), ge)
