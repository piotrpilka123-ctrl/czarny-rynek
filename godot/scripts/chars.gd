extends RefCounted
## Postacie: realistyczne sylwetki (Quaternius „Universal Base Characters”, CC0)
## z ubraniami nakładanymi shaderem i animacjami z „Universal Animation Library” (CC0).
## Maska ubrań jest zapisana w kolorach wierzchołków (patrz tools/README).

const Face = preload("res://scripts/face.gd")
const Stations = preload("res://scripts/stations.gd")
const People = preload("res://scripts/people.gd")
const Models = preload("res://scripts/models.gd")

const SH_BODY := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D tex_dark : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_light : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D tex_rough : filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float waist = 1.0;
uniform float neck = 1.5;
uniform float wrist = 0.69;
uniform float shoulder = 0.205;
uniform float ankle = 0.115;
// top_col.a: rodzaj góry (x10): 0 koszulka, 1 bluza, 2 dres, 3 kurtka, 4 podkoszulek, 5 kamizelka policyjna, 6 koszula
instance uniform vec4 top_col : source_color = vec4(0.2, 0.25, 0.35, 0.1);
instance uniform vec4 top2_col : source_color = vec4(0.85, 0.85, 0.85, 0.0);   // a: paski na nogawkach
instance uniform vec4 bot_col : source_color = vec4(0.1, 0.12, 0.18, 1.0);     // a: długość nogawek 0..1
instance uniform vec4 shoe_col : source_color = vec4(0.9, 0.9, 0.9, 0.0);      // a: logo na piersi
instance uniform vec4 fit = vec4(1.0, 0.93, 0.5, 1.0);                         // rękaw 0..1, dół bluzy (m), odcień skóry, grubość
varying vec4 vc;
varying vec3 masks;

vec3 calc(vec4 c, vec4 f, float kind, float leg_len) {
	float y = c.r * 2.0;
	float ax = c.g;
	float arm = step(shoulder, ax) * step(1.2, y);
	float sleeve_end = mix(shoulder + 0.02, wrist, f.x);
	if (kind > 3.5 && kind < 5.5) { sleeve_end = shoulder - 0.03; }
	float neck_y = neck + (kind > 0.5 && kind < 3.5 ? 0.012 : -0.025) - (kind > 3.5 && kind < 4.5 ? 0.03 : 0.0);
	float torso = (1.0 - arm) * step(f.y, y) * step(y, neck_y + smoothstep(0.045, 0.1, ax) * 0.16);
	float top = max(torso, arm * step(ax, sleeve_end));
	if (kind > 3.5 && kind < 4.5) { top *= step(ax, shoulder - 0.04 + (neck_y - y) * 0.35); }
	float shoe = step(y, ankle);
	float leg_cut = mix(0.62, ankle, leg_len);
	float bot = (1.0 - top) * step(y, waist) * step(leg_cut, y) * (1.0 - arm) * (1.0 - shoe);
	return vec3(top, bot, shoe);
}

void vertex() {
	vc = COLOR;
	float kind = round(top_col.a * 10.0);
	masks = calc(COLOR, fit, kind, bot_col.a);
	float thick = masks.x * (kind > 0.5 && kind < 3.5 ? 0.017 : (kind > 4.5 && kind < 5.5 ? 0.02 : 0.007)) + masks.y * 0.011 + masks.z * 0.012;
	// policjant: rękawy munduru pod kamizelką
	if (kind > 4.5 && kind < 5.5) {
		float y = COLOR.r * 2.0;
		thick = max(thick, step(shoulder, COLOR.g) * step(COLOR.g, wrist) * step(1.2, y) * 0.008);
	}
	VERTEX += NORMAL * thick * fit.w;
}

void fragment() {
	float kind = round(top_col.a * 10.0);
	vec3 m = calc(vc, fit, kind, bot_col.a);
	float y = vc.r * 2.0;
	float ax = vc.g;
	float side = vc.b * 2.0 - 1.0;
	float front = step(0.5, vc.a);
	float n1 = texture(noise_tex, UV * 9.0).r;
	float n2 = texture(noise_tex, UV * 2.3 + vec2(0.37, 0.11)).r;
	vec3 skin = mix(texture(tex_dark, UV).rgb, texture(tex_light, UV).rgb, fit.z);
	vec3 col = skin;
	float rough = texture(tex_rough, UV).g;
	float cloth = 0.0;
	float arm = step(shoulder, ax) * step(1.2, y);

	if (kind > 4.5 && kind < 5.5) {
		// mundur: granatowe rękawy, kamizelka odblaskowa z pasami
		float slv = arm * step(ax, wrist);
		if (slv > 0.5) { col = top2_col.rgb * (0.85 + n1 * 0.3); cloth = 1.0; rough = 0.85; }
	}
	if (m.x > 0.5) {
		cloth = 1.0;
		vec3 c = top_col.rgb * (0.86 + n1 * 0.22) * (0.92 + n2 * 0.16);
		float sleeve_end = mix(shoulder + 0.02, wrist, fit.x);
		float hem = smoothstep(fit.y + 0.035, fit.y + 0.025, y);
		float cuff = arm * smoothstep(sleeve_end - 0.035, sleeve_end - 0.025, ax);
		rough = 0.9;
		if (kind > 0.5 && kind < 3.5) {
			c *= 1.0 - (hem + cuff) * 0.22;
			float zip = step(ax, 0.007) * front * (1.0 - arm);
			c = mix(c, top2_col.rgb * 0.8, zip * (kind > 1.5 ? 1.0 : 0.6));
			float collar = smoothstep(neck - 0.03, neck - 0.02, y) * (1.0 - arm);
			c *= 1.0 - collar * 0.18;
		}
		if (kind > 1.5 && kind < 2.5) {
			float st = arm * (smoothstep(0.80, 0.83, side) * smoothstep(0.88, 0.85, side) + smoothstep(0.91, 0.94, side) * smoothstep(0.985, 0.965, side));
			c = mix(c, top2_col.rgb, clamp(st, 0.0, 1.0));
		}
		if (kind > 2.5 && kind < 3.5) { rough = 0.62; c *= 0.94; }
		if (kind > 4.5 && kind < 5.5) {
			float band = smoothstep(1.17, 1.18, y) * smoothstep(1.235, 1.225, y) + smoothstep(1.03, 1.04, y) * smoothstep(1.095, 1.085, y);
			c = mix(top_col.rgb * (0.9 + n1 * 0.2), vec3(0.78, 0.8, 0.82), clamp(band, 0.0, 1.0));
			rough = mix(0.7, 0.35, clamp(band, 0.0, 1.0));
		}
		if (kind > 5.5) {
			float btn = step(ax, 0.012) * front * (1.0 - arm);
			c = mix(c, c * 0.8, btn);
			rough = 0.75;
		}
		// nadruk: na koszulce pośrodku piersi, na bluzie pas w poprzek klatki
		float logo = shoe_col.a * front * (1.0 - arm) * (kind < 0.5
			? step(1.26, y) * step(y, 1.36) * step(ax, 0.075)
			: step(1.285, y) * step(y, 1.33) * step(0.012, ax));
		c = mix(c, top2_col.rgb, logo * 0.85);
		col = c;
	} else if (m.y > 0.5) {
		cloth = 1.0;
		vec3 c = bot_col.rgb * (0.82 + n1 * 0.3) * (0.9 + n2 * 0.2);
		float belt = smoothstep(waist - 0.035, waist - 0.025, y);
		c *= 1.0 - belt * 0.3;
		float wear = front * smoothstep(0.75, 0.55, abs(y - 0.72) * 4.0) * 0.12;
		c += wear * bot_col.rgb;
		float st = top2_col.a * (smoothstep(0.86, 0.89, side) * smoothstep(0.97, 0.95, side)) * step(y, waist - 0.05);
		c = mix(c, top2_col.rgb, clamp(st, 0.0, 1.0));
		col = c;
		rough = 0.88;
	} else if (m.z > 0.5) {
		cloth = 1.0;
		float sole = smoothstep(0.03, 0.02, y);
		col = mix(shoe_col.rgb * (0.9 + n1 * 0.2), vec3(0.82, 0.8, 0.76), sole * 0.85);
		rough = 0.6;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(0.4, 0.25, cloth);
	NORMAL_MAP = mix(texture(tex_normal, UV).rgb, vec3(0.5, 0.5, 1.0), cloth * 0.82);
	// lekkie rozproszenie podpowierzchniowe skóry
	RIM = (1.0 - cloth) * 0.12;
}
"""

const SKINS := [0.92, 0.8, 0.7, 0.55, 0.85, 0.75, 0.62, 0.3]
const HAIR_COLORS := ["2a1d14", "3d2a1c", "6b4a2e", "a07a45", "c9a86a", "1a1a1c", "7a7a7a", "8a3a22", "d8d2c4"]
const TOPS := ["1c2330", "3a3f4a", "6b1f24", "23402e", "101114", "4a4f58", "7c7466", "243a5e", "5a2f52", "8a8d92", "c9c4b8", "3d3326", "0f2b3d", "55606e"]
const BOTTOMS := ["1b2538", "232a36", "101114", "2e3440", "3b3f48", "45423c", "1f2a22", "5a6270"]
const SHOES := ["e6e4de", "151517", "2a2c33", "7a4a2a", "b8b8b8", "3a1c1c"]
const HAIR_M := ["hair_buzzed", "hair_simpleparted", "hair_buzzed", "hair_simpleparted", ""]
const HAIR_F := ["hair_long", "hair_buns", "hair_long", "hair_buzzedfemale", "hair_long"]
## naturalna prędkość animacji (m/s) do synchronizacji kroków
const ANIM_SPEED := {"Walk_Swagger": 0.97, "Walk_Hunched": 0.9, "Walk_Phone": 0.97, "Walk_Folded": 0.97, "Walk_Stiff": 0.97, "Walk_Loose": 0.97, "Walk": 0.97, "Walk_Formal": 0.97, "Jog_Fwd": 5.36, "Sprint": 8.25, "Zombie_Walk_Fwd": 1.05, "Walk_Carry": 0.65, "Crouch_Fwd": 0.75}
const POSES := {"": "Idle", "phone": "Idle_TalkingPhone", "talk": "Idle_Talking", "arms": "Idle_FoldArms", "lean": "Idle_Rail", "smoke": "Idle",
	"sit": "Sitting_Idle", "sit_talk": "Sitting_Talking", "sit_sip": "Sitting_Sip", "dance": "Dance", "dance2": "Dance_Sway", "dance3": "Dance_Wild", "dance4": "Dance_Drink", "dance5": "Dance_Hips", "dance6": "Dance_Cool", "junkie": "Zombie_Idle", "kneel": "Fixing_Kneeling", "no": "Idle_No",
	"crouch": "Crouch_Idle", "handsup": "Idle", "lantern": "Idle_Lantern", "drive": "Driving", "gun": "Pistol_Idle", "aim": "Pistol_Aim_Neutral"}

const USED := ["Idle", "Idle_Talking", "Idle_FoldArms", "Idle_TalkingPhone", "Idle_Rail", "Idle_No", "Yes", "Interact", "PickUp_Table", "Sitting_Idle", "Sitting_Talking",
	"Dance", "Zombie_Idle", "Zombie_Walk_Fwd", "Walk", "Walk_Formal", "Walk_Carry", "Jog_Fwd", "Sprint", "Crouch_Idle", "Fixing_Kneeling", "Consume", "Hit_Chest",
	"Idle_Lantern", "Driving", "Push", "Sitting_Enter", "Sitting_Exit", "Pistol_Idle", "Pistol_Aim_Neutral", "Hit_Knockback", "Melee_Hook", "Sword_Attack", "Death01",
	"Sword_Regular_A", "Sword_Regular_B", "Sword_Heavy_Combo", "TreeChopping", "OverhandThrow", "Hit_Head"]
const LOOPED := ["Idle", "Idle_Talking", "Idle_FoldArms", "Idle_TalkingPhone", "Idle_Rail", "Sitting_Idle", "Sitting_Talking", "Dance", "Zombie_Idle", "Idle_No",
	"Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Zombie_Walk_Fwd", "Walk_Carry", "Crouch_Idle", "Fixing_Kneeling", "Idle_Lantern", "Driving", "Push", "Pistol_Idle", "Pistol_Aim_Neutral"]
## o ile wyprostować nogi w pozach stojących (0 = oryginał)
const RELAX := {"Idle": 0.7, "Idle_Talking": 0.7, "Idle_FoldArms": 0.7, "Idle_TalkingPhone": 0.7, "Idle_No": 0.7, "Yes": 0.7, "Consume": 0.6, "Interact": 0.5, "Idle_Lantern": 0.6}
const LEGS := ["thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"]

static var _scene := {}
static var _mat := {}
static var _lib := {}
static var _hair_mat := {}
static var _noise: Texture2D = null
static var _shader: Shader = null
static var _hat_mesh := {}


static func col(c) -> Color:
	return c if c is Color else Color.html("#" + String(c))


static func _load_scene(path: String) -> PackedScene:
	if not _scene.has(path):
		_scene[path] = load(path)
	return _scene[path]


## Animacje są przeliczane na szkielet danej sylwetki (różnice pozy spoczynkowej),
## a stojące pozy „cywilne” dostają wyprostowane nogi zamiast bojowego rozkroku.
static func _library(female: bool) -> AnimationLibrary:
	var key := "f" if female else "m"
	if _lib.has(key):
		return _lib[key]
	var lib := AnimationLibrary.new()
	var tgt: Node = _load_scene("res://assets/chars/%s.gltf" % ("female" if female else "male")).instantiate()
	var st: Skeleton3D = tgt.find_child("Skeleton3D", true, false)
	for p in ["res://assets/anim/ual1.glb", "res://assets/anim/ual2.glb"]:
		var inst: Node = _load_scene(p).instantiate()
		var ss: Skeleton3D = inst.find_child("Skeleton3D", true, false)
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if ap != null and ss != null:
			for nm in ap.get_animation_list():
				if lib.has_animation(nm) or not USED.has(String(nm)):
					continue
				var a: Animation = ap.get_animation(nm).duplicate(true)
				if LOOPED.has(String(nm)):
					a.loop_mode = Animation.LOOP_LINEAR
				var relax: float = RELAX.get(String(nm), 0.0)
				for t in range(a.get_track_count()):
					var bone := String(a.track_get_path(t)).get_slice(":", 1)
					var bs := ss.find_bone(bone)
					var bt := st.find_bone(bone)
					if bs < 0 or bt < 0:
						continue
					var rs := ss.get_bone_rest(bs)
					var rt := st.get_bone_rest(bt)
					var ty := a.track_get_type(t)
					if ty == Animation.TYPE_ROTATION_3D:
						var qt := rt.basis.get_rotation_quaternion()
						var fix := qt * rs.basis.get_rotation_quaternion().inverse()
						var leg := relax > 0.0 and LEGS.has(bone)
						for k in range(a.track_get_key_count(t)):
							var q: Quaternion = a.track_get_key_value(t, k)
							q = (fix * q).normalized()
							if leg:
								q = q.slerp(qt, relax)
							a.track_set_key_value(t, k, q)
					elif ty == Animation.TYPE_POSITION_3D:
						var ratio: float = rt.origin.length() / maxf(0.001, rs.origin.length())
						for k in range(a.track_get_key_count(t)):
							var v: Vector3 = a.track_get_key_value(t, k)
							v *= ratio
							if relax > 0.0:
								v = Vector3(v.x * (1.0 - relax * 0.5), v.y, lerpf(v.z, rt.origin.z, relax))
							a.track_set_key_value(t, k, v)
				lib.add_animation(nm, a)
		inst.free()
	tgt.free()
	_walk_variants(lib)
	_dance_variants(lib)
	_sit_variants(lib)
	_lib[key] = lib
	return lib


# ---------------------------------------------------------------- odmiany chodu
## Z jednego cyklu „Walk” powstaje kilka charakterów: kołysanie się dresa, przygarbiony emeryt,
## spacer z telefonem przy uchu, ze skrzyżowanymi rękami, sztywny krok i miękki chód z biodra.
## Nogi i miednica zostają z oryginału, zmienia się góra ciała — stopy dalej trafiają w ziemię.
const WALKS := ["Walk", "Walk_Formal", "Walk_Swagger", "Walk_Hunched", "Walk_Phone", "Walk_Folded", "Walk_Stiff", "Walk_Loose"]
const ARMS := ["clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
const TORSO := ["spine_02", "spine_03", "neck_01", "Head"]

static func _bone(a: Animation, t: int) -> String:
	return String(a.track_get_path(t)).get_slice(":", 1)


static func _rot_track(a: Animation, bone: String) -> int:
	for t in range(a.get_track_count()):
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D and _bone(a, t) == bone:
			return t
	return -1


## wzmacnia (f > 1) albo tłumi (f < 1) ruch kości wokół jej średniego ustawienia
static func _scale_motion(a: Animation, bones: Array, f: float) -> void:
	for bone in bones:
		var t := _rot_track(a, bone)
		if t < 0 or a.track_get_key_count(t) < 2:
			continue
		var first: Quaternion = a.track_get_key_value(t, 0)
		var acc := Vector4.ZERO
		for k in range(a.track_get_key_count(t)):
			var q: Quaternion = a.track_get_key_value(t, k)
			if q.dot(first) < 0.0:
				q = -q
			acc += Vector4(q.x, q.y, q.z, q.w)
		var mean := Quaternion(acc.x, acc.y, acc.z, acc.w).normalized()
		for k in range(a.track_get_key_count(t)):
			var q2: Quaternion = a.track_get_key_value(t, k)
			var d := (mean.inverse() * q2).normalized()
			if d.w < 0.0:
				d = -d
			var ang := d.get_angle()
			if ang > 0.0005:
				d = Quaternion(d.get_axis().normalized(), ang * f)
			a.track_set_key_value(t, k, (mean * d).normalized())


## kości (i wszystkie palce po danej stronie) przejmują ustawienie z innej animacji; w = siła mieszania
static func _take_pose(a: Animation, src: Animation, bones: Array, side: String, at: float, w := 1.0) -> void:
	for t in range(a.get_track_count()):
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := _bone(a, t)
		var finger := side != "" and bone.ends_with(side) and not ARMS.has(bone) and not LEGS.has(bone)
		if not bones.has(bone) and not finger:
			continue
		var ts := _rot_track(src, bone)
		if ts < 0:
			continue
		var pose: Quaternion = src.rotation_track_interpolate(ts, minf(at, src.length))
		for k in range(a.track_get_key_count(t)):
			var q: Quaternion = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, q.slerp(pose, w).normalized())


## miesza klatka po klatce z innym cyklem chodu (czas przeskalowany do długości cyklu)
static func _mix_cycle(a: Animation, src: Animation, bones: Array, w: float) -> void:
	for bone in bones:
		var t := _rot_track(a, bone)
		var ts := _rot_track(src, bone)
		if t < 0 or ts < 0:
			continue
		for k in range(a.track_get_key_count(t)):
			var tt := a.track_get_key_time(t, k) / maxf(0.01, a.length) * src.length
			var q: Quaternion = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, q.slerp(src.rotation_track_interpolate(ts, tt), w).normalized())


## Jedna animacja tańca to za mało na cały parkiet: z tego samego cyklu powstaje kilka odmian
## (kołysanie, szaleństwo, taniec z drinkiem, biodra, „za fajny, żeby tańczyć”), a każdy tancerz dostaje też własne tempo.
static func _dance_variants(lib: AnimationLibrary) -> void:
	if not lib.has_animation("Dance"):
		return
	var base: Animation = lib.get_animation("Dance")
	var made := {}
	for nm in ["Dance_Sway", "Dance_Wild", "Dance_Drink", "Dance_Hips", "Dance_Cool"]:
		var a: Animation = base.duplicate(true)
		a.loop_mode = Animation.LOOP_LINEAR
		made[nm] = a
	_scale_motion(made["Dance_Sway"], ARMS, 0.4)
	_scale_motion(made["Dance_Sway"], ["spine_02", "spine_03", "pelvis"], 0.6)
	_scale_motion(made["Dance_Sway"], LEGS, 0.55)
	_scale_motion(made["Dance_Wild"], ARMS, 1.55)
	_scale_motion(made["Dance_Wild"], ["spine_02", "spine_03", "clavicle_l", "clavicle_r"], 1.5)
	_scale_motion(made["Dance_Wild"], ["pelvis", "Head", "neck_01"], 1.35)
	if lib.has_animation("Consume"):
		_take_pose(made["Dance_Drink"], lib.get_animation("Consume"), ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"], "_r", 0.25, 0.8)
	_scale_motion(made["Dance_Drink"], ["upperarm_l", "lowerarm_l"], 0.7)
	_scale_motion(made["Dance_Drink"], LEGS, 0.7)
	_scale_motion(made["Dance_Hips"], ["pelvis"], 1.9)
	_scale_motion(made["Dance_Hips"], ["spine_02", "spine_03"], 1.3)
	_scale_motion(made["Dance_Hips"], ARMS, 0.65)
	if lib.has_animation("Idle_FoldArms"):
		var fa: Animation = lib.get_animation("Idle_FoldArms")
		_take_pose(made["Dance_Cool"], fa, ["clavicle_l", "upperarm_l", "lowerarm_l", "hand_l"], "_l", 0.4, 0.75)
		_take_pose(made["Dance_Cool"], fa, ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"], "_r", 0.4, 0.75)
	_scale_motion(made["Dance_Cool"], LEGS, 0.5)
	_scale_motion(made["Dance_Cool"], ["Head", "neck_01"], 1.6)
	for nm in made:
		if not lib.has_animation(nm):
			lib.add_animation(nm, made[nm])


## Siedzenie z piwem: ten sam siad, ale prawa ręka idzie z butelką do ust (poza z animacji „Consume”).
## Postać przełącza się między zwykłym siadem a łykiem (npc.gd), przejście wygładza mieszanie animacji.
static func _sit_variants(lib: AnimationLibrary) -> void:
	if not lib.has_animation("Sitting_Idle") or not lib.has_animation("Consume") or lib.has_animation("Sitting_Sip"):
		return
	var a: Animation = lib.get_animation("Sitting_Idle").duplicate(true)
	a.loop_mode = Animation.LOOP_LINEAR
	_take_pose(a, lib.get_animation("Consume"), ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"], "_r", 0.25, 0.9)
	lib.add_animation("Sitting_Sip", a)


static func _walk_variants(lib: AnimationLibrary) -> void:
	if not lib.has_animation("Walk"):
		return
	var base: Animation = lib.get_animation("Walk")
	var made := {}
	for nm in ["Walk_Swagger", "Walk_Hunched", "Walk_Phone", "Walk_Folded", "Walk_Stiff", "Walk_Loose"]:
		var a: Animation = base.duplicate(true)
		a.loop_mode = Animation.LOOP_LINEAR
		made[nm] = a
	# dres: szerokie barki, mocne kołysanie tułowia i rąk
	_scale_motion(made["Walk_Swagger"], ["spine_02", "spine_03", "clavicle_l", "clavicle_r"], 1.9)
	_scale_motion(made["Walk_Swagger"], ["upperarm_l", "upperarm_r"], 1.35)
	_scale_motion(made["Walk_Swagger"], ["pelvis"], 1.4)
	# przygarbiony: plecy i głowa pochylone jak w „zombie”, ręce prawie nie pracują
	if lib.has_animation("Zombie_Walk_Fwd"):
		# (tylko domieszka — przy połowie wychodził krok żywego trupa)
		_mix_cycle(made["Walk_Hunched"], lib.get_animation("Zombie_Walk_Fwd"), TORSO, 0.25)
	_scale_motion(made["Walk_Hunched"], ARMS, 0.45)
	# z telefonem przy uchu: prawa ręka i głowa z rozmowy telefonicznej
	if lib.has_animation("Idle_TalkingPhone"):
		var ph: Animation = lib.get_animation("Idle_TalkingPhone")
		_take_pose(made["Walk_Phone"], ph, ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"], "_r", 0.6)
		_take_pose(made["Walk_Phone"], ph, ["neck_01", "Head"], "", 0.6, 0.6)
		_scale_motion(made["Walk_Phone"], ["upperarm_l", "lowerarm_l"], 0.7)
	# ze skrzyżowanymi rękami (zimno, nieufność)
	if lib.has_animation("Idle_FoldArms"):
		var fa: Animation = lib.get_animation("Idle_FoldArms")
		_take_pose(made["Walk_Folded"], fa, ["clavicle_l", "upperarm_l", "lowerarm_l", "hand_l"], "_l", 0.4)
		_take_pose(made["Walk_Folded"], fa, ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"], "_r", 0.4)
		_scale_motion(made["Walk_Folded"], ["spine_02", "spine_03"], 0.7)
	# sztywny krok: ręce przy ciele, mało ruchu w barkach
	_scale_motion(made["Walk_Stiff"], ARMS, 0.18)
	_scale_motion(made["Walk_Stiff"], ["spine_02", "spine_03"], 0.6)
	# miękki chód z biodra
	_scale_motion(made["Walk_Loose"], ["pelvis"], 1.7)
	_scale_motion(made["Walk_Loose"], ["spine_02", "spine_03"], 1.35)
	_scale_motion(made["Walk_Loose"], ["upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"], 0.8)
	for nm in made:
		if not lib.has_animation(nm):
			lib.add_animation(nm, made[nm])


## dobiera chód do postaci (los z ziarna, z uwzględnieniem płci i ubrania)
static func pick_walk(rng: RandomNumberGenerator, female: bool, kind: String) -> String:
	var pool: Array = ["Walk", "Walk", "Walk_Formal", "Walk_Stiff", "Walk_Phone", "Walk_Folded"]
	if female:
		pool += ["Walk_Loose", "Walk_Loose", "Walk_Formal"]
	else:
		pool += ["Walk_Swagger"]
		if kind == "dres" or kind == "hoodie":
			pool += ["Walk_Swagger", "Walk_Swagger"]
	if kind == "jacket":
		pool += ["Walk_Hunched"]
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _body_material(female: bool) -> ShaderMaterial:
	var key := "f" if female else "m"
	if _mat.has(key):
		return _mat[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SH_BODY
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.03
		fn.fractal_octaves = 4
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.noise = fn
		_noise = nt
	var m := ShaderMaterial.new()
	m.shader = _shader
	var s := "female" if female else "male"
	m.set_shader_parameter("tex_dark", load("res://assets/chars/%s_dark.png" % s))
	m.set_shader_parameter("tex_light", load("res://assets/chars/%s_light.png" % s))
	m.set_shader_parameter("tex_normal", load("res://assets/chars/%s_normal.png" % s))
	m.set_shader_parameter("tex_rough", load("res://assets/chars/%s_rough.png" % s))
	m.set_shader_parameter("noise_tex", _noise)
	if female:
		m.set_shader_parameter("waist", 0.99)
		m.set_shader_parameter("neck", 1.455)
		m.set_shader_parameter("wrist", 0.665)
		m.set_shader_parameter("shoulder", 0.175)
		m.set_shader_parameter("ankle", 0.105)
	_mat[key] = m
	return m


static func _hair_material(src: Material, color: Color) -> Material:
	var key := str(src.get_instance_id()) + color.to_html(false)
	if _hair_mat.has(key):
		return _hair_mat[key]
	var m: Material = src.duplicate()
	if m is BaseMaterial3D:
		var bm: BaseMaterial3D = m
		bm.albedo_color = color
		bm.roughness = 0.75
	_hair_mat[key] = m
	return m


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _first_mesh(c)
		if r != null:
			return r
	return null


static func _attach_hair(skel: Skeleton3D, name: String, color: Color) -> MeshInstance3D:
	var inst: Node = _load_scene("res://assets/chars/%s.gltf" % name).instantiate()
	var hm := _first_mesh(inst)
	if hm == null:
		inst.free()
		return null
	hm.get_parent().remove_child(hm)
	hm.owner = null
	skel.add_child(hm)
	hm.skeleton = NodePath("..")
	var src: Material = hm.mesh.surface_get_material(0)
	if src != null:
		hm.material_override = _hair_material(src, color)
	inst.free()
	return hm


static func _hat(kind: String, color: Color) -> Node3D:
	var g := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	var key := kind
	if not _hat_mesh.has(key):
		var sm := SphereMesh.new()
		sm.radius = 0.112
		sm.height = 0.112
		sm.is_hemisphere = true
		sm.radial_segments = 20
		sm.rings = 8
		_hat_mesh[key] = sm
	var dome := MeshInstance3D.new()
	dome.mesh = _hat_mesh[key]
	dome.material_override = m
	dome.position = Vector3(0, 0.0, 0)
	g.add_child(dome)
	var band := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.113
	cm.bottom_radius = 0.109
	cm.height = 0.045 if kind == "beanie" else 0.03
	cm.radial_segments = 20
	band.mesh = cm
	band.material_override = m
	band.position = Vector3(0, -cm.height * 0.5 + 0.004, 0)
	g.add_child(band)
	if kind == "beanie":
		dome.scale = Vector3(1.0, 1.08, 1.04)
	else:
		dome.scale = Vector3(1.0, 0.8, 1.05)
		var visor := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.15, 0.012, 0.1)
		visor.mesh = bx
		visor.material_override = m
		visor.position = Vector3(0, -0.022, 0.135)
		visor.rotation.x = 0.12
		g.add_child(visor)
		if kind == "police":
			var badge := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.05, 0.03, 0.01)
			badge.mesh = bb
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.85, 0.85, 0.88)
			wm.metallic = 0.6
			wm.roughness = 0.4
			badge.material_override = wm
			badge.position = Vector3(0, 0.02, 0.108)
			g.add_child(badge)
			var stripe := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 0.115
			sc.bottom_radius = 0.115
			sc.height = 0.016
			sc.radial_segments = 20
			stripe.mesh = sc
			stripe.material_override = wm
			stripe.position = Vector3(0, -0.006, 0)
			g.add_child(stripe)
	for c in g.get_children():
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


static var _blob_tex: GradientTexture2D = null

static func _set_layer(n: Node, layer_bits: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layer_bits
	for c in n.get_children():
		_set_layer(c, layer_bits)


## Miękka plama cienia rzutowana na ziemię pod postacią. Dzięki niej ludzie „stoją” na ulicy
## także w cieniu budynków i nocą, kiedy słońce nie daje wyraźnego cienia.
static func _blob(width := 1.0) -> Decal:
	if _blob_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.34), Color(0, 0, 0, 0.0)])
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = g
		_blob_tex.width = 128
		_blob_tex.height = 128
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(0.5, 0.0)
	var d := Decal.new()
	d.texture_albedo = _blob_tex
	d.size = Vector3(1.05 * width, 1.4, 0.95 * width)
	d.position = Vector3(0, 0.35, 0)
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.normal_fade = 0.4
	d.cull_mask = 1
	d.distance_fade_enabled = true
	d.distance_fade_begin = 30.0
	d.distance_fade_length = 8.0
	return d


## Buduje postać. Opcje: female, skin (0..1), kind, top, top2, bottom, shoes, hair (nazwa lub ""),
## hair_color, beard, hat ("cap" | "beanie" | "police"), hat_color, height, build, stripes, logo, sleeve, shorts, seed
static func make(o: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o.get("seed", randi()))
	var female: bool = o.get("female", false)
	if o.has("model") and People.exists(String(o.model)):
		return _make_person(o, rng, female)
	var inst: Node3D = _load_scene("res://assets/chars/%s.gltf" % ("female" if female else "male")).instantiate()
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var body: MeshInstance3D = null
	var brows: MeshInstance3D = null
	for c in skel.get_children():
		if c is MeshInstance3D:
			if c.name == "Eyebrows":
				brows = c
			elif c.name != "Eyes":
				body = c
	body.material_override = _body_material(female)
	body.extra_cull_margin = 0.6
	var kinds := {"tshirt": 0, "hoodie": 1, "dres": 2, "jacket": 3, "tank": 4, "uniform": 5, "police": 5, "shirt": 6, "suit": 6, "coat": 3, "dress": 0}
	var kind_name: String = o.get("kind", ["hoodie", "hoodie", "dres", "jacket", "tshirt", "jacket"][rng.randi_range(0, 5)])
	var kind: int = kinds.get(kind_name, 1)
	var top: Color = col(o.get("top", TOPS[rng.randi_range(0, TOPS.size() - 1)]))
	var top2: Color = col(o.get("top2", ["e8e6e0", "c9c4b8", "101114", "b0382c"][rng.randi_range(0, 3)]))
	var bottom: Color = col(o.get("bottom", BOTTOMS[rng.randi_range(0, BOTTOMS.size() - 1)]))
	var shoes: Color = col(o.get("shoes", SHOES[rng.randi_range(0, SHOES.size() - 1)]))
	var skin: float = o.get("skin", SKINS[rng.randi_range(0, SKINS.size() - 1)])
	var sleeve: float = o.get("sleeve", 0.42 if kind == 0 else 1.0)
	var hem: float = 1.0 if kind == 6 else (0.9 if (kind >= 1 and kind <= 3) else 0.96)
	if kind_name == "coat":
		hem = 0.62
	if kind_name == "dress":
		hem = 0.6
		sleeve = 0.5
	var stripes: float = 1.0 if (o.get("stripes", kind == 2 and rng.randf() < 0.8)) else 0.0
	var shorts: float = 0.0 if o.get("shorts", false) else 1.0
	var logo: float = 1.0 if o.get("logo", (kind == 0 or kind == 1) and rng.randf() < 0.3) else 0.0
	body.set_instance_shader_parameter("top_col", Color(top.r, top.g, top.b, kind / 10.0))
	body.set_instance_shader_parameter("top2_col", Color(top2.r, top2.g, top2.b, stripes))
	body.set_instance_shader_parameter("bot_col", Color(bottom.r, bottom.g, bottom.b, shorts))
	body.set_instance_shader_parameter("shoe_col", Color(shoes.r, shoes.g, shoes.b, logo))
	body.set_instance_shader_parameter("fit", Vector4(sleeve, hem, skin, float(o.get("thick", 1.0))))

	var hair_color: Color = col(o.get("hair_color", HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)]))
	var hat: String = o.get("hat", "")
	var hair_name: String = o.get("hair", (HAIR_F if female else HAIR_M)[rng.randi_range(0, 4)])
	if o.get("bald", false):
		hair_name = ""
	if hat != "" and hair_name != "hair_long" and hair_name != "":
		hair_name = "hair_buzzedfemale" if female else "hair_buzzed"
	if hair_name != "":
		_attach_hair(skel, hair_name, hair_color)
	if o.get("beard", false) and not female:
		_attach_hair(skel, "hair_beard", hair_color)
	if brows != null:
		var bsrc: Material = brows.mesh.surface_get_material(0)
		if bsrc != null:
			brows.material_override = _hair_material(bsrc, hair_color.darkened(0.25))
	if hat != "":
		var ba := BoneAttachment3D.new()
		skel.add_child(ba)
		ba.bone_name = "Head"
		var h := _hat(hat, col(o.get("hat_color", "15171c" if hat == "police" else TOPS[rng.randi_range(0, TOPS.size() - 1)])))
		h.position = Vector3(0, 0.155 if not female else 0.15, 0.022)
		ba.add_child(h)

	var height: float = o.get("height", (rng.randf_range(1.6, 1.74) if female else rng.randf_range(1.7, 1.9)))
	var base_h := 1.767 if female else 1.81
	var sy := height / base_h
	var build: float = o.get("build", rng.randf_range(0.9, 1.06))
	# sylwetka bazowa jest bardzo umięśniona — domyślnie lekko ją wyszczuplamy
	var sx := sy * build * (0.9 if not female else 0.95)
	var root := Node3D.new()
	inst.scale = Vector3(sx, sy, sx * (1.0 + (build - 1.0) * 0.6))
	root.add_child(inst)
	var ap := AnimationPlayer.new()
	inst.add_child(ap)
	ap.add_animation_library("", _library(female))
	ap.playback_default_blend_time = 0.28
	# postać rysuje się na osobnej warstwie, żeby jej własny cień-plama nie przyciemniał butów
	_set_layer(inst, 2)
	if not o.get("no_blob", false):
		root.add_child(_blob(sx))
	var rig := {"root": root, "model": inst, "skel": skel, "body": body, "anim": ap, "height": height, "cur": "", "female": female, "phase": rng.randf(),
		"walk": o.get("walk", pick_walk(rng, female, kind_name)), "idle_t": 0.0}
	play(rig, "Idle")
	ap.seek(rng.randf() * 3.0, true)
	add_face(rig, rng)
	return rig


## postać z gotowego, realistycznego modelu (people.gd); animacje wspólne z resztą gry
static func _make_person(o: Dictionary, rng: RandomNumberGenerator, female: bool) -> Dictionary:
	var model := String(o.model)
	var p: Dictionary = People.instance(model, String(o.get("face", "")))
	var inst: Node3D = p.model
	var skel: Skeleton3D = p.skel
	if o.get("player",false):
		for mi in skel.get_children():
			if not mi is MeshInstance3D: continue
			for sf in range(mi.mesh.get_surface_count()):
				var src:Material=mi.mesh.surface_get_material(sf)
				var cur:Material=mi.get_surface_override_material(sf)
				if src!=null and String(src.resource_name).to_lower().ends_with("head") and cur is StandardMaterial3D:
					var skin_mat:StandardMaterial3D=cur.duplicate()
					skin_mat.roughness=0.65
					skin_mat.normal_scale=0.7
					skin_mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					mi.set_surface_override_material(sf,skin_mat)
	female = People.is_female(model)
	var k: float = float(o.get("tall", rng.randf_range(0.97, 1.045)))
	var build: float = o.get("build", rng.randf_range(0.97, 1.04))
	inst.scale = Vector3(k * build, k, k * build)
	var root := Node3D.new()
	root.add_child(inst)
	var ap := AnimationPlayer.new()
	inst.add_child(ap)
	ap.add_animation_library("", People.library(model, _library(false), _load_scene("res://assets/chars/male.gltf"), female))
	ap.playback_default_blend_time = 0.28
	_set_layer(inst, 2)
	if not o.get("no_blob", false):
		root.add_child(_blob(k))
	var kind_name: String = o.get("kind", "hoodie")
	var rig := {"root": root, "model": inst, "skel": skel, "body": p.body, "anim": ap, "height": float(p.top) * k, "cur": "", "female": female, "phase": rng.randf(),
		"walk": o.get("walk", pick_walk(rng, female, kind_name)), "idle_t": 0.0, "person": true,"player":o.get("player",false)}
	play(rig, "Idle")
	ap.seek(rng.randf() * 3.0, true)
	add_face(rig, rng)
	if o.get("mask", false):
		# kominiarka uszyta na głowę; prosta bryła tylko awaryjnie
		rig["wear"] = []
		if _wear_skinned(rig, "kominiarka"):
			_hair_cards(rig, false)
		else:
			_balaclava(skel)
	return rig


## Wyposażenie policjanta: mundur ma własny pas z kaburą, więc dokładamy tylko pistolet w dłoni (przy `armed`). Kości szkieletu Biped: oś X wzdłuż kości, Y do przodu, Z w bok.
static func police_gear(rig: Dictionary, armed := false) -> void:
	var skel: Skeleton3D = rig.get("skel")
	if skel == null:
		return
	rig["armed"] = false
	set_armed(rig, armed)


## przedmiot z modeli Blendera w prawej dłoni (rurka napastnika w prologu)
static func hold(rig: Dictionary, model_name: String, xf: Transform3D) -> Node3D:
	var skel: Skeleton3D = rig.get("skel")
	if skel == null or skel.find_bone("Bip01 R Hand") < 0:
		return null
	var St = load("res://scripts/stations.gd")
	var it: Node3D = St.model(model_name)
	if it == null:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Bip01 R Hand"
	skel.add_child(ba)
	it.transform = xf
	ba.add_child(it)
	return it


# ================================================================ ubrania na postaci
## Realistyczne modele mają ubranie namalowane na teksturze. Założone rzeczy pokazujemy dwojako:
## 1) cieniowanie przebarwia tułów z rękawami, nogi, stopy i dłonie (rozpoznane po kościach) na kolor ubrania,
## 2) dodatki (czapka, okulary, łańcuch, komin, kaptur, kołnierz, kieszenie bojówek) wiszą na kościach.
const SH_WEAR := """shader_type spatial;
uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap;
uniform float normal_on = 0.0;
uniform int bone_region[128];
instance uniform vec4 w_top = vec4(0.0);
instance uniform vec4 w_pants = vec4(0.0);
instance uniform vec4 w_shoes = vec4(0.0);
instance uniform vec4 w_gloves = vec4(0.0);
instance uniform float w_plaid = 0.0;
instance uniform vec4 w_hide = vec4(0.0);
instance uniform vec4 w_plastic = vec4(0.0);   // manekin: całe ciało w kolorze tworzywa
instance uniform vec4 w_skin = vec4(0.0);
varying vec4 reg;
varying float neck_w;
void vertex() {
	vec4 r = vec4(0.0);
	float nk = 0.0;
	for (int i = 0; i < 4; i++) {
		int rg = bone_region[int(BONE_INDICES[i])];
		float w = BONE_WEIGHTS[i];
		if (rg == 1) { r.x += w; } else if (rg == 2) { r.y += w; } else if (rg == 3) { r.z += w; } else if (rg == 4) { r.w += w; } else if (rg == 5) { nk += w; }
	}
	reg = r;
	neck_w = nk;
}
vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }
void fragment() {
	// ciało pod uszytym ubraniem nie jest rysowane (nic nie przebija przez materiał)
	if (dot(step(vec4(0.5), reg), w_hide) > 0.5) {
		discard;
	}
	// podstawa szyi: punkty, które choć trochę idą za tułowiem, też znikają pod górą — granica widocznej skóry
	// wypada wtedy wyżej, pod wykończeniem dekoltu, a nie poszarpana w środku kołnierza
	if (w_hide.x > 0.5 && reg.x + neck_w * 0.45 >= 0.5) {
		discard;
	}
	vec3 base = texture(tex_albedo, UV).rgb;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	// fałdy i szwy z oryginalnej tekstury zostają jako delikatne cieniowanie nowego materiału
	float shade = mix(0.72, 1.18, smoothstep(0.0, 0.35, lum));
	vec3 c = base;
	vec3 top = srgb(w_top.rgb);
	if (w_plaid > 0.5) {
		vec2 g = fract(UV * 46.0);
		float bars = step(0.5, g.x) * 0.5 + step(0.5, g.y) * 0.5;
		float thin = step(0.92, fract(UV.x * 23.0)) + step(0.92, fract(UV.y * 23.0));
		top = mix(top, top * 0.32, bars) + vec3(0.5, 0.45, 0.3) * clamp(thin, 0.0, 1.0) * 0.22;
	}
	c = mix(c, top * shade, smoothstep(0.42, 0.58, reg.x) * w_top.a);
	c = mix(c, srgb(w_pants.rgb) * shade, smoothstep(0.42, 0.58, reg.y) * w_pants.a);
	c = mix(c, srgb(w_shoes.rgb) * shade, smoothstep(0.72, 0.9, reg.z) * w_shoes.a);
	c = mix(c, srgb(w_skin.rgb)*shade, clamp(reg.w+neck_w,0.0,1.0)*w_skin.a);
	c = mix(c, srgb(w_gloves.rgb) * shade, smoothstep(0.42, 0.58, reg.w) * w_gloves.a);
	ALBEDO = mix(c, srgb(w_plastic.rgb), w_plastic.a);
	ROUGHNESS = mix(0.84, 0.42, w_plastic.a);
	SPECULAR = 0.3;
	if (normal_on > 0.5 && w_plastic.a < 0.5) {
		NORMAL_MAP = texture(tex_normal, UV).rgb;
	}
}
"""

static var _wear_shader: Shader = null
static var _wear_mats := {}


static func _bone_region(bone: String) -> int:
	var b := bone.to_lower()
	if b.contains("finger") or b.contains("hand"):
		return 4
	if b.contains("foot") or b.contains("toe"):
		return 3
	if b.contains("thigh") or b.contains("calf") or b.contains("pelvis") or b == "bip01":
		return 2
	if b.contains("spine") or b.contains("clavicle") or b.contains("upperarm") or b.contains("forearm"):
		return 1
	if b.contains("neck"):
		return 5
	return 0


static func _wear_material(src: StandardMaterial3D, mi: MeshInstance3D, skel: Skeleton3D) -> ShaderMaterial:
	var key := src.get_instance_id()
	if _wear_mats.has(key):
		return _wear_mats[key]
	if _wear_shader == null:
		_wear_shader = Shader.new()
		_wear_shader.code = SH_WEAR
	var m := ShaderMaterial.new()
	m.shader = _wear_shader
	m.set_shader_parameter("tex_albedo", src.albedo_texture)
	if src.normal_enabled and src.normal_texture != null:
		m.set_shader_parameter("tex_normal", src.normal_texture)
		m.set_shader_parameter("normal_on", 1.0)
	# numery kości w siatce to numery powiązań skóry, nie kości szkieletu
	var regs := PackedInt32Array()
	regs.resize(128)
	var n := mi.skin.get_bind_count() if mi.skin != null else skel.get_bone_count()
	for i in range(mini(n, 128)):
		var bn := ""
		if mi.skin != null:
			bn = String(mi.skin.get_bind_name(i))
			if bn == "" and mi.skin.get_bind_bone(i) >= 0:
				bn = skel.get_bone_name(mi.skin.get_bind_bone(i))
		else:
			bn = skel.get_bone_name(i)
		regs[i] = _bone_region(bn)
	m.set_shader_parameter("bone_region", regs)
	_wear_mats[key] = m
	return m


const FABRIC_REPEAT := {"dzianina": 34.0, "dzins": 22.0, "plotno": 20.0, "skora": 12.0, "sciagacz": 14.0, "guma": 14.0}
const SH_PLAID := """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 base : source_color = vec3(0.6, 0.2, 0.18);
void fragment() {
	// krata z rzutu (UV2 w metrach): szerokie pasy co 6 cm i cienkie nitki między nimi
	vec2 g = UV2 / 0.06;
	vec2 f = fract(g);
	float bx = step(0.5, f.x);
	float by = step(0.5, f.y);
	vec3 c = base * mix(1.0, 0.34, bx * 0.5 + by * 0.5);
	float thin = max(step(0.94, fract(g.x * 0.5 + 0.2)), step(0.94, fract(g.y * 0.5 + 0.2)));
	c = mix(c, vec3(0.86, 0.8, 0.62), thin * 0.55);
	float white = max(step(0.965, fract(g.x * 0.5 + 0.7)), step(0.965, fract(g.y * 0.5 + 0.7)));
	c = mix(c, vec3(0.05, 0.05, 0.06), white * 0.6);
	ALBEDO = c * texture(tex_a, UV * 18.0).r;
	NORMAL_MAP = texture(tex_n, UV * 18.0).rgb;
	ROUGHNESS = 0.92;
}
"""

static var _wear_scene := {}
static var _fabric_mats := {}
static var _plaid_shader: Shader = null


static var _fabric_tex := {}

## faktura tkaniny z mipmapami (bez nich drobny splot mieni się morą z każdej odległości)
static func _ftex(name: String) -> Texture2D:
	if not _fabric_tex.has(name):
		var src: Texture2D = load("res://assets/wear/%s.png" % name)
		var img: Image = src.get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps(name.ends_with("_n"))
		_fabric_tex[name] = ImageTexture.create_from_image(img)
	return _fabric_tex[name]


static func _wear_load(id: String) -> PackedScene:
	if not _wear_scene.has(id):
		var path := "res://assets/wear/%s.glb" % id
		_wear_scene[id] = load(path) if ResourceLoader.exists(path) else null
	return _wear_scene[id]


## materiał ubrania: kolor z modelu, faktura tkaniny rozpoznana po początku nazwy (dzianina_, dzins_, plotno_, skora_, sciagacz_, guma_, krata_)
static func _fabric_mat(src: Material, dye := Color.WHITE, main := Color.WHITE) -> Material:
	if src == null:
		return null
	if dye != Color.WHITE:
		# wariant kolorystyczny: główna tkanina (kolor `main`) dostaje barwę `dye`, reszta zachowuje swój stosunek jasności
		var tk := "%s|%s|%s" % [String(src.resource_name), dye.to_html(), main.to_html()]
		if not _fabric_mats.has(tk):
			var base: Material = _fabric_mat(src).duplicate()
			if base is BaseMaterial3D and _dyeable(String(src.resource_name)):
				var c := (base as BaseMaterial3D).albedo_color
				var k := c.get_luminance() / maxf(0.02, main.get_luminance())
				# białe lampasy, sznurówki i nici zostają sobą; farbuje się tkanina zbliżona jasnością do głównej
				if k < 2.0 and not (c.s < 0.14 and c.v > 0.62):
					k = clampf(k, 0.62, 1.7)
					(base as BaseMaterial3D).albedo_color = Models.no_vanta(Color(dye.r * k, dye.g * k, dye.b * k, c.a))
			_fabric_mats[tk] = base
		return _fabric_mats[tk]
	var nm := String(src.resource_name)
	if _fabric_mats.has(nm):
		return _fabric_mats[nm]
	var kind := nm.get_slice("_", 0)
	var out: Material = src
	if kind == "krata" and src is BaseMaterial3D:
		if _plaid_shader == null:
			_plaid_shader = Shader.new()
			_plaid_shader.code = SH_PLAID
		var pm := ShaderMaterial.new()
		pm.shader = _plaid_shader
		pm.set_shader_parameter("tex_a", _ftex("plotno_a"))
		pm.set_shader_parameter("tex_n", _ftex("plotno_n"))
		pm.set_shader_parameter("base", (src as BaseMaterial3D).albedo_color)
		out = pm
	elif src is BaseMaterial3D:
		var m: BaseMaterial3D = src.duplicate()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Models.no_vanta(m.albedo_color)
		if FABRIC_REPEAT.has(kind):
			m.albedo_texture = _ftex(kind + "_a")
			m.normal_enabled = true
			m.normal_texture = _ftex(kind + "_n")
			m.normal_scale = 0.7
			var k: float = FABRIC_REPEAT[kind]
			m.uv1_scale = Vector3(k, k, k)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		out = m
	_fabric_mats[nm] = out
	return out


## guma podeszew, metal, skarpety i futerko nie zmieniają koloru razem z tkaniną
static func _dyeable(nm: String) -> bool:
	if nm.begins_with("metal") or nm.begins_with("guma"):
		return false
	for part in ["skarpeta", "futerko", "nic", "guzik"]:
		if nm.contains(part):
			return false
	return true


## kolor głównej tkaniny uszytej rzeczy (pierwsza powierzchnia siatki)
static func _main_color(mesh: Mesh) -> Color:
	var m := mesh.surface_get_material(0) if mesh != null and mesh.get_surface_count() > 0 else null
	return (m as BaseMaterial3D).albedo_color if m is BaseMaterial3D else Color(0.5, 0.5, 0.5)


## ubranie szyte na szkielet: siatka z pliku przechodzi na szkielet postaci i dostaje skórę liczoną z jego pozy spoczynkowej
static func _wear_skinned(rig: Dictionary, id: String, tint := Color.WHITE) -> bool:
	var ps := _wear_load(id)
	if ps == null:
		return false
	var skel: Skeleton3D = rig.skel
	var inst: Node = ps.instantiate()
	var ok := false
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var src: Skin = mi.skin
		var gskel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if src == null:
			continue
		var sk := Skin.new()
		for i in range(src.get_bind_count()):
			var bn := String(src.get_bind_name(i))
			if bn == "" and gskel != null and src.get_bind_bone(i) >= 0:
				bn = gskel.get_bone_name(src.get_bind_bone(i))
			var bi := skel.find_bone(bn)
			if bi >= 0:
				sk.add_named_bind(bn, skel.get_bone_global_rest(bi).affine_inverse())
			else:
				sk.add_named_bind(bn, src.get_bind_pose(i))
		mi.get_parent().remove_child(mi)
		mi.owner = null
		skel.add_child(mi)
		mi.transform = Transform3D.IDENTITY
		mi.skeleton = NodePath("..")
		mi.skin = sk
		mi.extra_cull_margin = 0.6
		var main := _main_color(mi.mesh)
		for sf in range(mi.mesh.get_surface_count()):
			mi.set_surface_override_material(sf, _fabric_mat(mi.mesh.surface_get_material(sf), tint, main))
		_set_layer(mi, 2)
		rig.wear.append(mi)
		ok = true
	inst.free()
	return ok


## sztywny dodatek (czapka, okulary, łańcuch): model zapisany względem początku kości
static func _wear_rigid(rig: Dictionary, id: String, bone: String, tint := Color.WHITE) -> bool:
	var ps := _wear_load(id)
	if ps == null:
		return false
	var inst: Node3D = ps.instantiate()
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var main := _main_color(mi.mesh)
		for sf in range(mi.mesh.get_surface_count()):
			mi.set_surface_override_material(sf, _fabric_mat(mi.mesh.surface_get_material(sf), tint, main))
	_on_bone(rig, bone, inst, Transform3D())
	return true


## zawiesza `node` na kości; `xf` to położenie w osiach postaci (X w lewo, Y w górę, Z do przodu) względem początku kości
static func _on_bone(rig: Dictionary, bone: String, node: Node3D, xf: Transform3D) -> void:
	var skel: Skeleton3D = rig.skel
	var bi := skel.find_bone(bone)
	if bi < 0:
		node.free()
		return
	var rest := skel.get_bone_global_rest(bi)
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	node.transform = rest.affine_inverse() * Transform3D(xf.basis, rest.origin + xf.origin)
	ba.add_child(node)
	_set_layer(ba, 2)
	rig.wear.append(ba)


static func _wmesh(mesh: Mesh, color: Color, rough := 0.9, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	mi.material_override = m
	return mi


## sterczące kosmyki (osobna, półprzezroczysta powierzchnia modelu) przebijałyby przez czapkę — pod nakryciem głowy je chowamy
static func _hair_cards(rig: Dictionary, show: bool) -> void:
	var skel: Skeleton3D = rig.skel
	var keep: Dictionary = rig.get("hair_src", {})
	for c in skel.get_children():
		if not (c is MeshInstance3D) or rig.wear.has(c):
			continue
		var mi: MeshInstance3D = c
		for sf in range(mi.mesh.get_surface_count()):
			var src: Material = mi.mesh.surface_get_material(sf)
			if src == null or not String(src.resource_name).to_lower().ends_with("opacity"):
				continue
			var key := "%d|%d" % [mi.get_instance_id(), sf]
			if not keep.has(key):
				keep[key] = mi.get_surface_override_material(sf)
			mi.set_surface_override_material(sf, keep[key] if show else People._hidden())
	rig["hair_src"] = keep


## Manekin sklepowy: sylwetka z gładkiego tworzywa, zastygła w pozie, ubrana w rzeczy uszyte tak samo jak na bohaterze —
## w sklepie widać dokładnie to, co się kupuje.
static func mannequin(gear: Dictionary, pose := "", plastic := Color(0.80, 0.78, 0.73)) -> Dictionary:
	var rig := make({"model": String(D.PLAYER_LOOK.model), "seed": 11, "no_blob": true})
	if rig.is_empty() or not rig.get("person", false):
		return rig
	dress(rig, gear)
	_hair_cards(rig, false)
	var skel: Skeleton3D = rig.skel
	var pm := StandardMaterial3D.new()
	pm.albedo_color = plastic
	pm.roughness = 0.42
	for c in skel.get_children():
		if not (c is MeshInstance3D) or rig.wear.has(c):
			continue
		var mi: MeshInstance3D = c
		for sf in range(mi.mesh.get_surface_count()):
			var cur: Material = mi.get_surface_override_material(sf)
			var src: Material = mi.mesh.surface_get_material(sf)
			var nm := (src.resource_name if src != null else "").to_lower()
			if nm.ends_with("opacity"):
				continue
			if not (cur is ShaderMaterial):
				mi.set_surface_override_material(sf, pm)
		mi.set_instance_shader_parameter("w_plastic", Color(plastic.r, plastic.g, plastic.b, 1.0))
	# zastygła poza: bez mrugania, oddechu i gadania
	var fc = rig.get("face")
	if fc != null and is_instance_valid(fc):
		(fc as Node).process_mode = Node.PROCESS_MODE_DISABLED
	rig["pose"] = pose
	return rig


## zatrzymuje postać w pozie (manekin). Wołać po dodaniu do sceny — poza drzewem animacja nie ustawia kości.
static func freeze(rig: Dictionary, at := 0.4) -> void:
	if rig.is_empty() or not rig.has("anim"):
		return
	var ap: AnimationPlayer = rig.anim
	var anim: String = POSES.get(String(rig.get("pose", "")), "Idle")
	if not ap.has_animation(anim):
		return
	rig.cur = anim
	ap.play(anim, 0.0)
	ap.advance(at)
	ap.pause()


## ubiera postać w rzeczy z pól ekwipunku: gear = {pole: id przedmiotu}
static func dress(rig: Dictionary, gear: Dictionary, tints := {}) -> void:
	if rig.is_empty() or not rig.get("person", false):
		return
	for n in rig.get("wear", []):
		if is_instance_valid(n):
			n.queue_free()
	rig["wear"] = []
	var skel: Skeleton3D = rig.skel
	var look := {}
	for slot in gear:
		var id := String(gear[slot])
		if id != "" and D.ITEMS.has(id):
			look[slot] = D.ITEMS[id].get("look", {})
	# uszyte ubrania i dodatki z plików; czego nie ma w plikach, to po staremu (przebarwienie i proste bryły)
	var made := {}
	for slot in look:
		# wariant kolorystyczny korzysta z wykroju innej rzeczy (look.model) i farbuje główną tkaninę na look.tint
		var gid := String(look[slot].get("model", gear[slot]))
		var bone := String(look[slot].get("bone", ""))
		var tn: Color = tints.get(slot, col(look[slot].tint) if look[slot].has("tint") else Color.WHITE)
		made[slot] = _wear_rigid(rig, gid, bone, tn) if bone != "" else _wear_skinned(rig, gid, tn)
	_hair_cards(rig, not made.get("glowa", false))
	var hide := Vector4(1.0 if made.get("gora", false) else 0.0, 1.0 if made.get("spodnie", false) else 0.0,
		1.0 if made.get("buty", false) else 0.0, 1.0 if made.get("dlonie", false) else 0.0)
	for slot in made:
		if made[slot]:
			look[slot] = {}
	var none := Color(0, 0, 0, 0)
	var tint := func(slot: String) -> Color:
		if not look.has(slot) or not look[slot].has("color"):
			return none
		var c := col(look[slot].color)
		return Color(c.r, c.g, c.b, 0.94)
	for c in skel.get_children():
		if not (c is MeshInstance3D) or rig.wear.has(c):
			continue
		var mi: MeshInstance3D = c
		for s in range(mi.mesh.get_surface_count()):
			var cur: Material = mi.get_surface_override_material(s)
			var src: Material = mi.mesh.surface_get_material(s)
			var nm := (src.resource_name if src != null else "").to_lower()
			if cur is StandardMaterial3D and nm.ends_with("body"):
				mi.set_surface_override_material(s, _wear_material(cur, mi, skel))
		mi.set_instance_shader_parameter("w_top", tint.call("gora"))
		mi.set_instance_shader_parameter("w_pants", tint.call("spodnie"))
		mi.set_instance_shader_parameter("w_shoes", tint.call("buty"))
		mi.set_instance_shader_parameter("w_gloves", tint.call("dlonie"))
		mi.set_instance_shader_parameter("w_plaid", 1.0 if look.get("gora", {}).get("plaid", false) else 0.0)
		mi.set_instance_shader_parameter("w_hide", hide)
		mi.set_instance_shader_parameter("w_skin",Color(0.82,0.73,0.66,1.0) if rig.get("player",false) else Color(0,0,0,0))
	# --- głowa: czapka z daszkiem albo zimowa
	var head: Dictionary = look.get("glowa", {})
	if head.has("hat"):
		var h := _hat(String(head.hat), col(head.get("color", "15171c")))
		var beanie: bool = String(head.hat) == "beanie"
		h.scale = Vector3(1.1, 1.12, 1.14) if beanie else Vector3(1.12, 1.5, 1.16)
		_on_bone(rig, "Bip01 Head", h, Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0, 0.152 if beanie else 0.135, 0.03)))
	# --- szyja: okulary, komin, łańcuch
	var neck: Dictionary = look.get("szyja", {})
	match String(neck.get("acc", "")):
		"glasses":
			var g := Node3D.new()
			var dark := Color(0.03, 0.03, 0.04)
			for sx in [-1.0, 1.0]:
				var lm := BoxMesh.new()
				lm.size = Vector3(0.05, 0.034, 0.006)
				var lens := _wmesh(lm, dark, 0.15, 0.4)
				lens.position = Vector3(sx * 0.033, 0.0, 0.0)
				g.add_child(lens)
				var tm := BoxMesh.new()
				tm.size = Vector3(0.004, 0.006, 0.12)
				var temple := _wmesh(tm, dark, 0.4)
				temple.position = Vector3(sx * 0.068, 0.006, -0.058)
				g.add_child(temple)
			var bm := BoxMesh.new()
			bm.size = Vector3(0.018, 0.006, 0.006)
			var bridge := _wmesh(bm, dark, 0.4)
			bridge.position = Vector3(0, 0.008, 0)
			g.add_child(bridge)
			_on_bone(rig, "Bip01 Head", g, Transform3D(Basis(), Vector3(0, 0.088, 0.147)))
		"gaiter":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.072
			cm.bottom_radius = 0.088
			cm.height = 0.14
			cm.radial_segments = 20
			var ga := _wmesh(cm, col(neck.get("color", "2a2d33")))
			ga.scale = Vector3(1.0, 1.0, 1.32)
			_on_bone(rig, "Bip01 Neck", ga, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 0.055, 0.04)))
		"chain":
			var g2 := Node3D.new()
			var tm2 := TorusMesh.new()
			tm2.inner_radius = 0.094
			tm2.outer_radius = 0.101
			tm2.rings = 28
			tm2.ring_segments = 6
			var ring := _wmesh(tm2, Color(0.86, 0.68, 0.24), 0.3, 0.9)
			ring.scale = Vector3(1.0, 1.0, 1.35)
			g2.add_child(ring)
			var pm := BoxMesh.new()
			pm.size = Vector3(0.022, 0.006, 0.03)
			var pend := _wmesh(pm, Color(0.9, 0.72, 0.28), 0.25, 0.9)
			pend.position = Vector3(0, 0.0, 0.145)
			g2.add_child(pend)
			_on_bone(rig, "Bip01 Neck", g2, Transform3D(Basis(Vector3.RIGHT, 1.02), Vector3(0, -0.02, 0.035)))
	# --- góra: kaptur bluzy albo postawiony kołnierz kurtki
	var top: Dictionary = look.get("gora", {})
	if top.get("hood", false):
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.2
		sm.radial_segments = 16
		sm.rings = 8
		var hood := _wmesh(sm, col(top.color).darkened(0.12))
		hood.scale = Vector3(1.3, 0.95, 0.62)
		_on_bone(rig, "Bip01 Neck", hood, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.0, -0.085)))
	if top.get("collar", false):
		var tc := TorusMesh.new()
		tc.inner_radius = 0.066
		tc.outer_radius = 0.1
		tc.rings = 20
		tc.ring_segments = 8
		var collar := _wmesh(tc, col(top.color).darkened(0.18))
		collar.scale = Vector3(1.0, 2.1, 1.12)
		_on_bone(rig, "Bip01 Neck", collar, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.015, 0.012)))
	# --- spodnie: kieszenie bojówek na udach
	var pants: Dictionary = look.get("spodnie", {})
	if pants.get("cargo", false):
		for b in ["Bip01 L Thigh", "Bip01 R Thigh"]:
			var bi := skel.find_bone(b)
			if bi < 0:
				continue
			var side := signf(skel.get_bone_global_rest(bi).origin.x)
			var pk := BoxMesh.new()
			pk.size = Vector3(0.018, 0.13, 0.1)
			var pocket := _wmesh(pk, col(pants.color).darkened(0.1))
			var fm := BoxMesh.new()
			fm.size = Vector3(0.022, 0.04, 0.104)
			var flap := _wmesh(fm, col(pants.color).darkened(0.22))
			flap.position = Vector3(0, 0.05, 0)
			pocket.add_child(flap)
			_on_bone(rig, b, pocket, Transform3D(Basis(), Vector3(side * 0.07, -0.25, 0.012)))


## Latarka kątowa przypięta do szelki na lewej piersi; snop wychodzi z jej szybki i kołysze się razem z tułowiem.
## Zwraca światło (z szybką jako dzieckiem — gaśnie i znika razem z nim) albo null, gdy postać nie ma takiego szkieletu.
static func shoulder_torch(rig: Dictionary) -> SpotLight3D:
	var skel: Skeleton3D = rig.skel
	if skel == null or skel.find_bone("Bip01 Spine2") < 0:
		return null
	var ps := Stations.model("pol_latarka")
	if ps == null:
		return null
	if not rig.has("wear"):
		rig["wear"] = []
	var holder := Node3D.new()
	holder.add_child(ps)
	var sp := SpotLight3D.new()
	sp.position = Vector3(0, 0.045, 0.055)
	sp.rotation = Vector3(0.16, PI, 0.0)
	holder.add_child(sp)
	var lens := Stations._find(ps, "Swiatlo") as Node3D
	if lens != null:
		var gx := lens.transform
		lens.get_parent().remove_child(lens)
		lens.owner = null
		sp.add_child(lens)
		lens.transform = sp.transform.affine_inverse() * gx
		if lens is GeometryInstance3D:
			(lens as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_on_bone(rig, "Bip01 Spine2", holder, Transform3D(Basis(), Vector3(0.105, 0.085, 0.142)))
	return sp


## Snop latarki w powietrzu: miękki stożek, najjaśniejszy przy szkle, gasnący z odległością i przy krawędzi.
const SH_BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.85, 0.92, 1.0);
uniform float power = 0.055;
uniform float len = 8.0;
varying float along;
void vertex() {
	along = 0.5 - VERTEX.y / len;
}
void fragment() {
	float edge = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = tint;
	// przy samym szkle snop jest wąski i ostry, dalej rozmywa się w powietrzu
	ALPHA = pow(edge, 1.8) * pow(1.0 - along, 2.6) * power;
}
"""

## Odblask szkła latarki: mały punkt z boku, oślepiająca plama, gdy latarka świeci prosto w patrzącego.
const SH_GLARE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.9, 0.95, 1.0);
uniform float size = 0.3;
varying float k;
void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz;
	vec3 fwd = normalize((MODEL_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - org);
	k = pow(max(dot(fwd, to_cam), 0.0), 6.0);
	vec4 vc = VIEW_MATRIX * vec4(org, 1.0);
	// przed sylwetką policjanta (żeby nie wcinała się w mundur), ale za ścianami dalej jej nie widać
	vc.z += 0.3;
	vc.xy += VERTEX.xy * mix(0.14, size, k);
	POSITION = PROJECTION_MATRIX * vc;
}
void fragment() {
	vec2 d = UV - 0.5;
	float r = clamp(1.0 - length(d) * 2.0, 0.0, 1.0);
	// krótkie promienie na krzyż, jak w prawdziwym obiektywie
	float rays = pow(max(0.0, 1.0 - abs(d.y) * 26.0), 2.0) * r + pow(max(0.0, 1.0 - abs(d.x) * 34.0), 2.0) * r * 0.6;
	ALBEDO = tint;
	// odblask szkła: wyraźny punkt, ale bez wielkiej białej plamy, gdy latarka świeci prosto w kamerę
	ALPHA = clamp(pow(r, 4.0) * (0.1 + k * 0.28) + pow(r, 16.0) * 0.9 + rays * k * 0.14, 0.0, 1.0);
}
"""

static var _torch_cookie: GradientTexture2D = null
static var _beam_mat: ShaderMaterial = null
static var _glare_mat: ShaderMaterial = null

## Dodatki, dzięki którym latarka wygląda jak latarka: plama z jasnym środkiem i obwódką (rzutnik),
## stożek światła w powietrzu i odblask szkła. `half_angle` w radianach, `reach` w metrach.
static func torch_fx(sp: SpotLight3D, half_angle: float, reach: float) -> void:
	if _torch_cookie == null:
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 0.85, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1), Color(0.92, 0.92, 0.92), Color(0.5, 0.5, 0.5), Color(0.16, 0.16, 0.16), Color(0, 0, 0)])
		_torch_cookie = GradientTexture2D.new()
		_torch_cookie.gradient = gr
		_torch_cookie.fill = GradientTexture2D.FILL_RADIAL
		_torch_cookie.fill_from = Vector2(0.5, 0.5)
		_torch_cookie.fill_to = Vector2(0.5, 0.0)
		_torch_cookie.width = 256
		_torch_cookie.height = 256
		var bs := Shader.new()
		bs.code = SH_BEAM
		_beam_mat = ShaderMaterial.new()
		_beam_mat.shader = bs
		var gs := Shader.new()
		gs.code = SH_GLARE
		_glare_mat = ShaderMaterial.new()
		_glare_mat.shader = gs
	sp.light_projector = _torch_cookie
	# Stożek w powietrzu i duży odblask dawały z bliska białe obręcze — zostaje samo światło
	# (snop w mgle rysuje silnik) i mały punkt szkła, który nie rośnie.
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var gl := MeshInstance3D.new()
	gl.name = "Odblask"
	gl.mesh = q
	gl.material_override = _glare_mat
	gl.extra_cull_margin = 1.0
	gl.position = Vector3(0, 0, -0.03)
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.add_child(gl)


## pistolet w dłoni (wyjęty z kabury) albo schowany
static func set_armed(rig: Dictionary, on: bool) -> void:
	var skel: Skeleton3D = rig.get("skel")
	if skel == null or bool(rig.get("armed", false)) == on:
		return
	rig["armed"] = on
	if on and not rig.has("gun") and skel.find_bone("Bip01 R Hand") >= 0:
		var St = load("res://scripts/stations.gd")
		var gun: Node3D = St.model("pistolet")
		if gun != null:
			var bg := BoneAttachment3D.new()
			bg.bone_name = "Bip01 R Hand"
			skel.add_child(bg)
			gun.transform = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1)), Vector3(0.09, 0.075, 0.0))
			bg.add_child(gun)
			rig["gun"] = gun
	if rig.has("gun"):
		(rig.gun as Node3D).visible = on


## kominiarka: czarna czapa na całą głowę ze szparą na oczy (przypięta do kości głowy)
static func _balaclava(skel: Skeleton3D) -> void:
	if skel.find_bone("Bip01 Head") < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Bip01 Head"
	skel.add_child(ba)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.11, 0.11, 0.12)
	cloth.roughness = 0.95
	# kość szkieletu Biped: oś X w górę, Y do przodu, Z w bok
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.118
	sm.height = 0.236
	sm.radial_segments = 16
	sm.rings = 10
	m.mesh = sm
	m.material_override = cloth
	m.scale = Vector3(1.0, 1.24, 1.08)
	m.rotation = Vector3(0, 0, PI / 2.0)
	m.position = Vector3(0.095, 0.012, 0.0)
	ba.add_child(m)
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.075
	cm.bottom_radius = 0.085
	cm.height = 0.12
	neck.mesh = cm
	neck.material_override = cloth
	neck.rotation = Vector3(0, 0, PI / 2.0)
	neck.position = Vector3(-0.02, 0.0, 0.0)
	ba.add_child(neck)
	var slit := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.032, 0.03, 0.125)
	slit.mesh = bm
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.56, 0.46)
	skin.roughness = 0.7
	slit.material_override = skin
	slit.position = Vector3(0.105, 0.112, 0.0)
	ba.add_child(slit)
	for sz in [-0.03, 0.03]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.011
		em.height = 0.022
		eye.mesh = em
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(0.11, 0.11, 0.12)
		eye.material_override = emat
		eye.position = Vector3(0.106, 0.126, sz)
		ba.add_child(eye)


static func play(rig: Dictionary, anim: String, speed := 1.0, blend := -1.0) -> void:
	var ap: AnimationPlayer = rig.anim
	if rig.cur != anim:
		if not ap.has_animation(anim):
			return
		rig.cur = anim
		ap.play(anim, blend)
	ap.speed_scale = speed


## animacja zależna od prędkości i pozy (odpowiednik dawnego Models.animate)
## Mimika: mruganie, wzrok, usta przy mówieniu, miny. Każda postać dostaje też własny „wyraz twarzy na co dzień”.
static func add_face(rig: Dictionary, rng: RandomNumberGenerator = null) -> void:
	var sk: Skeleton3D = rig.get("skel")
	if sk == null or sk.find_bone("Bip01 MJaw") < 0:
		return
	var f = Face.new()
	sk.add_child(f)
	if not f.bind(sk):
		f.queue_free()
		return
	rig["face"] = f
	var r := rng.randf() if rng != null else randf()
	# większość ludzi ma twarz obojętną; część lekko się uśmiecha, część chodzi skwaszona albo zmęczona
	if r < 0.2:
		f.base = {"usmiech": 0.3}
	elif r < 0.36:
		f.base = {"zlosc": 0.3}
	elif r < 0.48:
		f.base = {"smutek": 0.4}


## stały wyraz twarzy postaci (zastępuje poprzedni): mood(rig, "usmiech", 0.5); pusta nazwa = twarz obojętna
static func mood(rig: Dictionary, mina := "", weight := 0.5) -> void:
	var f = rig.get("face")
	if f != null and is_instance_valid(f):
		f.base = {mina: weight} if mina != "" else {}


## chwilowa mina (uśmiech po udanej wymianie, złość po odmowie) — sama gaśnie
static func emote(rig: Dictionary, mina: String, weight := 1.0, secs := 2.5) -> void:
	var f = rig.get("face")
	if f != null and is_instance_valid(f):
		f.flash(mina, weight, secs)


## postać mówi przez `secs` sekund (porusza ustami)
static func say(rig: Dictionary, secs := 2.5) -> void:
	var f = rig.get("face")
	if f != null and is_instance_valid(f):
		f.say_t = maxf(float(f.say_t), secs)


static func animate(rig: Dictionary, _dt: float, speed: float, pose := "") -> void:
	var fc = rig.get("face")
	if fc != null and is_instance_valid(fc):
		# w pozach rozmowy usta się ruszają, przy telefonie trochę rzadziej
		fc.chatter = 0.75 if (speed <= 0.15 and pose in ["talk", "sit_talk"]) else (0.45 if (speed <= 0.15 and pose == "phone") else 0.0)
	if speed > 4.2:
		play(rig, "Jog_Fwd", clampf(speed / 5.36, 0.8, 1.35))
	elif speed > 0.15:
		var w: String = rig.walk
		play(rig, w, clampf(speed / float(ANIM_SPEED.get(w, 1.0)), 0.6, 1.9))
	else:
		play(rig, POSES.get(pose, "Idle"), 1.0)


static func one_shot(rig: Dictionary, anim: String) -> void:
	var ap: AnimationPlayer = rig.anim
	if ap.has_animation(anim):
		rig.cur = anim
		ap.speed_scale = 1.0
		ap.play(anim, 0.15)


static func set_active(rig: Dictionary, on: bool) -> void:
	var ap: AnimationPlayer = rig.anim
	ap.active = on
