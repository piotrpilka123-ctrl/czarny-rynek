extends RefCounted
## Postacie: realistyczne sylwetki (Quaternius „Universal Base Characters”, CC0)
## z ubraniami nakładanymi shaderem i animacjami z „Universal Animation Library” (CC0).
## Maska ubrań jest zapisana w kolorach wierzchołków (patrz tools/README).

const People = preload("res://scripts/people.gd")

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
	"sit": "Sitting_Idle", "sit_talk": "Sitting_Talking", "dance": "Dance", "junkie": "Zombie_Idle", "kneel": "Fixing_Kneeling", "no": "Idle_No",
	"crouch": "Crouch_Idle", "handsup": "Idle", "lantern": "Idle_Lantern", "drive": "Driving"}

const USED := ["Idle", "Idle_Talking", "Idle_FoldArms", "Idle_TalkingPhone", "Idle_Rail", "Idle_No", "Yes", "Interact", "PickUp_Table", "Sitting_Idle", "Sitting_Talking",
	"Dance", "Zombie_Idle", "Zombie_Walk_Fwd", "Walk", "Walk_Formal", "Walk_Carry", "Jog_Fwd", "Sprint", "Crouch_Idle", "Fixing_Kneeling", "Consume", "Hit_Chest",
	"Idle_Lantern", "Driving", "Push", "Sitting_Enter", "Sitting_Exit"]
const LOOPED := ["Idle", "Idle_Talking", "Idle_FoldArms", "Idle_TalkingPhone", "Idle_Rail", "Sitting_Idle", "Sitting_Talking", "Dance", "Zombie_Idle", "Idle_No",
	"Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Zombie_Walk_Fwd", "Walk_Carry", "Crouch_Idle", "Fixing_Kneeling", "Idle_Lantern", "Driving", "Push"]
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
		_mix_cycle(made["Walk_Hunched"], lib.get_animation("Zombie_Walk_Fwd"), TORSO, 0.5)
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
	return rig


## postać z gotowego, realistycznego modelu (people.gd); animacje wspólne z resztą gry
static func _make_person(o: Dictionary, rng: RandomNumberGenerator, female: bool) -> Dictionary:
	var model := String(o.model)
	var p: Dictionary = People.instance(model)
	var inst: Node3D = p.model
	var skel: Skeleton3D = p.skel
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
		"walk": o.get("walk", pick_walk(rng, female, kind_name)), "idle_t": 0.0, "person": true}
	play(rig, "Idle")
	ap.seek(rng.randf() * 3.0, true)
	return rig


static func play(rig: Dictionary, anim: String, speed := 1.0, blend := -1.0) -> void:
	var ap: AnimationPlayer = rig.anim
	if rig.cur != anim:
		if not ap.has_animation(anim):
			return
		rig.cur = anim
		ap.play(anim, blend)
	ap.speed_scale = speed


## animacja zależna od prędkości i pozy (odpowiednik dawnego Models.animate)
static func animate(rig: Dictionary, _dt: float, speed: float, pose := "") -> void:
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
