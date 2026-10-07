extends Node3D
## Niebo z panoram HDR (Poly Haven, CC0), słońce i księżyc zgodne z niebem,
## mgła objętościowa (snopy światła), deszcz, latarnie — cykl dnia i nocy.

const SH_SKY := """
shader_type sky;
uniform sampler2D tex_a : filter_linear, repeat_enable;
uniform sampler2D tex_b : filter_linear, repeat_enable;
uniform sampler2D tex_r : filter_linear, repeat_enable;
uniform float mix_k = 0.0;
uniform float rot_a = 0.0;
uniform float rot_b = 0.0;
uniform float en_a = 1.0;
uniform float en_b = 1.0;
uniform float en_r = 0.5;
uniform float rain = 0.0;
void sky() {
	vec3 d = normalize(EYEDIR);
	float u = atan(d.x, -d.z) / TAU + 0.5;
	float v = min(acos(clamp(d.y, -1.0, 1.0)) / PI, 0.498);
	vec3 a = min(textureLod(tex_a, vec2(u + rot_a, v), 0.0).rgb, vec3(30.0)) * en_a;
	vec3 b = min(textureLod(tex_b, vec2(u + rot_b, v), 0.0).rgb, vec3(30.0)) * en_b;
	vec3 c = mix(a, b, mix_k);
	c = mix(c, textureLod(tex_r, vec2(u, v), 0.0).rgb * en_r, rain);
	if (d.y < 0.0) {
		c *= mix(1.0, 0.2, clamp(-d.y * 5.0, 0.0, 1.0));
	}
	COLOR = c;
}
"""

## położenie słońca / księżyca na panoramie: [u, wysokość w stopniach]
const SUN_UV := {"day": [0.5996, 38.0], "late": [0.6, 7.7], "dusk": [0.6, 2.4], "night": [0.143, 33.8]}
## klatki kluczowe doby: [godzina, niebo, azymut słońca (°), energia światła, barwa, jasność nieba, gęstość mgły]
const KEYS := [
	[0.0, "night", 150.0, 0.17, Color(0.55, 0.65, 1.0), 0.045, 0.022],
	[4.6, "night", 215.0, 0.17, Color(0.55, 0.65, 1.0), 0.045, 0.026],
	[6.0, "dusk", 92.0, 0.55, Color(1.0, 0.6, 0.38), 0.55, 0.03],
	[7.6, "late", 108.0, 1.25, Color(1.0, 0.82, 0.58), 0.75, 0.018],
	[9.8, "day", 135.0, 1.55, Color(1.0, 0.95, 0.88), 0.8, 0.0038],
	[15.2, "day", 228.0, 1.55, Color(1.0, 0.95, 0.88), 0.8, 0.0038],
	[17.0, "late", 250.0, 1.3, Color(1.0, 0.8, 0.55), 0.75, 0.012],
	[18.7, "dusk", 268.0, 0.6, Color(1.0, 0.56, 0.34), 0.6, 0.02],
	[20.3, "night", 120.0, 0.17, Color(0.55, 0.65, 1.0), 0.045, 0.024],
	[24.0, "night", 150.0, 0.17, Color(0.55, 0.65, 1.0), 0.045, 0.022],
]

var we: WorldEnvironment
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var rain_fx: GPUParticles3D
var rain := 0.0
var rain_target := 0.0
var wet := 0.0
var night := 0.0
var t := 0.0
var inside := false
var quality := "med"
var tex := {}
var _sky_t := 0.0
var _sky_key := ""


func build(_noise_tex: Texture2D) -> void:
	for n in ["day", "late", "dusk", "night", "rain"]:
		tex[n] = load("res://assets/sky/%s.hdr" % n)
	var sh := Shader.new()
	sh.code = SH_SKY
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = sh
	sky_mat.set_shader_parameter("tex_r", tex.rain)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.fog_enabled = true
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.7
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = Color(0.86, 0.88, 0.92)
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_detail_spread = 2.2
	env.volumetric_fog_ambient_inject = 0.35
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.94
	we = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.0
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.4
	sun.light_angular_distance = 0.8
	sun.light_volumetric_fog_energy = 1.6
	add_child(sun)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)

	# deszcz
	rain_fx = GPUParticles3D.new()
	rain_fx.amount = 1500
	rain_fx.lifetime = 0.75
	rain_fx.preprocess = 0.6
	rain_fx.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22.0, 0.5, 22.0)
	pm.direction = Vector3(0.04, -1.0, 0.0)
	pm.spread = 2.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 27.0
	pm.gravity = Vector3(0, -6.0, 0)
	rain_fx.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.02, 0.7)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.75, 0.82, 0.95, 0.34)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rm.billboard_keep_scale = true
	qm.material = rm
	rain_fx.draw_pass_1 = qm
	rain_fx.emitting = false
	add_child(rain_fx)
	set_quality(quality)


## Docelowa wysokość obrazu 3D (w pikselach) dla każdego ustawienia. Interfejs zawsze
## rysuje się w pełnej rozdzielczości ekranu, a scena 3D jest skalowana (FSR 1.0),
## dzięki czemu ekran Retina nie zarzyna karty graficznej.
const TARGET_H := {"ultra": 4320.0, "high": 1260.0, "med": 940.0, "low": 740.0}


## dodatkowe ustawienia z menu Opcje (nakładane na wybrany poziom jakości)
var res_mult := 1.0
var bright := 1.0
var opt_shadows := ""       # "" = jak w poziomie jakości, "low" | "med" | "high"
var opt_fog := true
var opt_ssao := true
var fog_on := true


func set_quality(q: String) -> void:
	quality = q
	var vp := get_viewport()
	if env == null or vp == null:
		return
	var ultra := q == "ultra"
	var high := q == "high" or ultra
	# „Ultra” — dla mocnych kart graficznych: globalne oświetlenie (SDFGI), odbite światło i odbicia w przestrzeni
	# ekranu, pełna rozdzielczość, cienie 8K. Na zintegrowanych układach to pokaz slajdów — stąd osobny poziom.
	env.sdfgi_enabled = ultra
	if ultra:
		env.sdfgi_cascades = 6
		env.sdfgi_min_cell_size = 0.2
		env.sdfgi_use_occlusion = true
		env.sdfgi_read_sky_light = true
		env.sdfgi_energy = 1.0
		env.ssr_max_steps = 96
		env.ssr_fade_in = 0.15
		env.ssr_fade_out = 2.0
		env.ssil_radius = 5.0
		env.ssil_intensity = 1.0
	RenderingServer.directional_shadow_atlas_set_size(8192 if ultra else 4096, true)
	RenderingServer.environment_glow_set_use_bicubic_upscale(high)
	RenderingServer.environment_set_volumetric_fog_filter_active(true)
	RenderingServer.environment_set_volumetric_fog_volume_size(160 if ultra else 64, 128 if ultra else 64)
	env.ssao_enabled = q != "low" and opt_ssao
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA if ultra else (RenderingServer.ENV_SSAO_QUALITY_MEDIUM if high else RenderingServer.ENV_SSAO_QUALITY_LOW), true, 0.5, 3, 50.0, 300.0)
	env.glow_enabled = true
	fog_on = q != "low" and opt_fog
	env.volumetric_fog_enabled = fog_on and not inside
	env.ssr_enabled = ultra
	env.ssil_enabled = ultra
	vp.msaa_3d = Viewport.MSAA_4X if ultra else (Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED)
	vp.mesh_lod_threshold = 0.5 if ultra else (1.0 if high else (1.5 if q == "med" else 2.5))
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if high else Viewport.SCREEN_SPACE_AA_FXAA
	apply_scale()
	var sq := opt_shadows if opt_shadows != "" else ("high" if ultra else q)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if sq == "high" else (RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if sq == "med" else RenderingServer.SHADOW_QUALITY_SOFT_LOW))
	if sun != null:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sq != "low" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = (170.0 if ultra else 110.0) if sq == "high" else (80.0 if sq == "med" else 60.0)
		# półcień zależny od odległości (PCSS) kosztuje ok. 2 ms na klatkę w 1440p — tylko na najwyższym poziomie
		sun.light_angular_distance = 0.8 if sq == "high" else 0.0
		sun.shadow_blur = 1.0 if sq == "high" else 1.4


## Dynamiczna rozdzielczość: gdy klatek jest za mało, obraz 3D rysuje się w nieco niższej
## rozdzielczości (do 62%), a gdy jest zapas — wraca do pełnej. Interfejsu to nie dotyczy.
var dyn := 1.0
var dyn_t := 0.0
var dyn_on := true

func auto_scale(dt: float) -> void:
	if not dyn_on:
		return
	dyn_t += dt
	if dyn_t < 1.5:
		return
	dyn_t = 0.0
	var fps := Engine.get_frames_per_second()
	var goal := minf(60.0, DisplayServer.screen_get_refresh_rate() if DisplayServer.screen_get_refresh_rate() > 1.0 else 60.0)
	var prev := dyn
	if fps < goal * 0.86:
		dyn = maxf(0.62, dyn - 0.07)
	elif fps > goal * 0.97 and dyn < 1.0:
		dyn = minf(1.0, dyn + 0.035)
	if absf(dyn - prev) > 0.001:
		apply_scale()


## przelicza skalę renderowania 3D do aktualnego rozmiaru okna
func apply_scale() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var h := maxf(1.0, float(vp.size.y))
	var sc := clampf(float(TARGET_H.get(quality, 940.0)) * dyn * res_mult / h, 0.3, 1.0)
	vp.scaling_3d_scale = sc
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if sc < 0.97 else Viewport.SCALING_3D_MODE_BILINEAR
	# łagodne wyostrzanie i lekko dodatnie przesunięcie mipmap: mniej „piasku” na drobnych teksturach w ruchu
	vp.fsr_sharpness = 1.2
	# tekstury mają mipmapy, więc przy skalowaniu w górę wybieramy poziom o ułamek ostrzejszy (jak zaleca FSR)
	vp.texture_mipmap_bias = clampf(log(sc) / log(2.0), -1.0, 0.0) * 0.6


static func _dir(az_deg: float, el_deg: float) -> Vector3:
	var a := deg_to_rad(az_deg)
	var e := deg_to_rad(el_deg)
	return Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))


static func _rot(sky: String, az_deg: float) -> float:
	return float(SUN_UV[sky][0]) - (az_deg / 360.0 + 0.5)


func update(hour: float, dt: float, loc: String, cam_pos: Vector3, world) -> void:
	t += dt
	rain += (rain_target - rain) * minf(1.0, dt * 0.25)
	wet += ((1.0 if rain > 0.15 else 0.0) - wet) * minf(1.0, dt * (0.12 if rain > 0.15 else 0.03))
	G.rain = rain
	# --- klatki kluczowe doby
	var i := 0
	for k in range(KEYS.size() - 1):
		if hour >= float(KEYS[k][0]) and hour <= float(KEYS[k + 1][0]):
			i = k
			break
	var A: Array = KEYS[i]
	var B: Array = KEYS[i + 1]
	var k := clampf((hour - float(A[0])) / maxf(0.001, float(B[0]) - float(A[0])), 0.0, 1.0)
	var same: bool = A[1] == B[1]
	var both_sun: bool = A[1] != "night" and B[1] != "night"
	var az := lerpf(A[2], B[2], k)
	var sky_e := lerpf(A[5], B[5], k)
	night = clampf(1.0 - (sky_e - 0.045) / 0.4, 0.0, 1.0)
	G.night = night
	var ov := rain
	# --- kierunek, barwa i siła głównego światła
	var el_a: float = SUN_UV[A[1]][1]
	var el_b: float = SUN_UV[B[1]][1]
	var sun_dir: Vector3
	var sun_e: float
	var sun_c: Color
	if same or both_sun:
		sun_dir = _dir(az, lerpf(el_a, el_b, k))
		sun_e = lerpf(A[3], B[3], k)
		sun_c = (A[4] as Color).lerp(B[4], k)
	elif k < 0.5:
		# zmiana źródła (słońce ↔ księżyc): stare gaśnie, potem nowe się rozjaśnia
		sun_dir = _dir(A[2], el_a)
		sun_e = float(A[3]) * (1.0 - k * 2.0)
		sun_c = A[4]
	else:
		sun_dir = _dir(B[2], el_b)
		sun_e = float(B[3]) * (k * 2.0 - 1.0)
		sun_c = B[4]
	# --- niebo (aktualizowane co chwilę, żeby oświetlenie otoczenia nadążało)
	_sky_t -= dt
	var key := "%s%s" % [A[1], B[1]]
	if _sky_t <= 0.0 or key != _sky_key or dt == 0.0:
		_sky_t = 1.2
		_sky_key = key
		sky_mat.set_shader_parameter("tex_a", tex[A[1]])
		sky_mat.set_shader_parameter("tex_b", tex[B[1]])
		sky_mat.set_shader_parameter("mix_k", k)
		var ra := az if (same or both_sun) else float(A[2])
		var rb := az if (same or both_sun) else float(B[2])
		sky_mat.set_shader_parameter("rot_a", _rot(A[1], ra))
		sky_mat.set_shader_parameter("rot_b", _rot(B[1], rb))
		sky_mat.set_shader_parameter("en_a", A[5])
		sky_mat.set_shader_parameter("en_b", B[5])
		sky_mat.set_shader_parameter("en_r", lerpf(0.5, 0.03, night))
		sky_mat.set_shader_parameter("rain", clampf(ov * 1.1, 0.0, 0.95))

	var now_inside := loc != "out"
	if now_inside != inside:
		inside = now_inside
		if inside:
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(1.0, 0.9, 0.78)
			env.ambient_light_energy = 0.16
			env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
		else:
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
			env.fog_enabled = true
			env.volumetric_fog_enabled = fog_on
	if inside:
		sun.light_energy = 0.0
		env.tonemap_exposure = 1.0 * bright
		env.glow_hdr_threshold = 1.0
		# okna: w dzień jasne szyby i plama światła na podłodze, nocą granat i łuna miasta
		var day := clampf(1.0 - night, 0.0, 1.0) * (1.0 - ov * 0.5)
		for wn in world.windows:
			var pane: StandardMaterial3D = wn.pane
			pane.emission = Color(0.1, 0.14, 0.26).lerp(sun_c.lerp(Color(0.78, 0.86, 0.98), 0.6), day)
			pane.emission_energy_multiplier = lerpf(0.22, 1.25, day)
			var wl: Light3D = wn.light
			wl.light_energy = float(wn.base) * day
			wl.light_color = sun_c.lerp(Color(1.0, 0.96, 0.9), 0.5)
			wl.visible = day > 0.03
	else:
		sun.look_at_from_position(sun_dir * 100.0, Vector3.ZERO, Vector3.UP)
		sun.light_color = sun_c.lerp(Color(0.8, 0.84, 0.9), ov * 0.7)
		sun.light_energy = sun_e * (1.0 - ov * 0.8)
		sun.light_volumetric_fog_energy = lerpf(1.25, 0.6, night)
		# nocą do światła nieba dochodzi słabe, niebieskawe wypełnienie — cienie nie są smoliście czarne
		env.ambient_light_sky_contribution = lerpf(1.0, 0.5, night)
		# (dawniej mocno niebieskie i jasne: dalekie budynki świeciły granatem na tle brunatnego nieba)
		env.ambient_light_color = Color(0.15, 0.17, 0.23)
		env.ambient_light_energy = lerpf(0.9, 1.05, night)
		env.tonemap_exposure = lerpf(0.92, 1.2, night) * bright
		env.glow_hdr_threshold = lerpf(1.2, 0.85, night)
		env.fog_light_color = (sun_c * 0.5 + Color(0.4, 0.45, 0.5) * 0.5) * lerpf(1.0, 0.08, night)
		env.fog_light_energy = lerpf(0.8, 0.3, night)
		# Nocą mgła bierze kolor z samego nieba i gęstnieje: dalekie bloki wtapiają się w łunę miasta,
		# zamiast odcinać się jaśniejszą, niebieską plamą. Mgła objętościowa nie dostaje już nocnego światła otoczenia.
		env.fog_aerial_perspective = lerpf(0.7, 1.0, night)
		env.fog_density = lerpf(0.002, 0.0042, night) + ov * 0.006
		env.volumetric_fog_ambient_inject = lerpf(0.35, 0.03, night)
		env.volumetric_fog_density = lerpf(A[6], B[6], k) + ov * 0.02
		env.volumetric_fog_albedo = Color(0.86, 0.88, 0.92).lerp(Color(0.52, 0.54, 0.58), night)
	RenderingServer.global_shader_parameter_set("night", 0.0 if inside else night)
	RenderingServer.global_shader_parameter_set("wet", wet)

	# --- latarnie, ogniska, telewizory
	var on := night > 0.08 and not inside
	for l in world.lamps:
		if l.has_meta("tv"):
			# telewizor nie migocze jak stroboskop: jasność zmienia się wraz z ujęciami (co parę sekund)
			# i lekko faluje w ich trakcie; barwa przechodzi między chłodną a cieplejszą
			var shot := floorf(t / 2.9)
			var k0 := fmod(absf(sin(shot * 12.9898) * 43758.5453), 1.0)
			var k1 := fmod(absf(sin((shot + 1.0) * 12.9898) * 43758.5453), 1.0)
			var kk := lerpf(k0, k1, smoothstep(0.92, 1.0, fmod(t / 2.9, 1.0)))
			l.light_energy = 0.28 + 0.34 * kk + 0.04 * sin(t * 1.7)
			l.light_color = Color(0.55, 0.68, 1.0).lerp(Color(1.0, 0.86, 0.7), clampf(kk * 1.4 - 0.5, 0.0, 0.7))
			continue
		if l.has_meta("fire"):
			var fp := float(l.get_meta("fire"))
			l.light_energy = (1.6 + 0.9 * absf(sin(t * 9.0 + fp) * sin(t * 5.3 + fp * 2.0)) + night * 1.6)
			continue
		var always: bool = l.has_meta("always")
		var e := 2.0 if always else night * 9.0
		if l.has_meta("gain"):
			e *= float(l.get_meta("gain"))
		if l.has_meta("flicker"):
			var ph := float(l.get_meta("flicker"))
			if sin(t * 11.0 + ph) > 0.93 or fmod(t + ph, 9.0) < 0.18:
				e *= 0.12
		l.visible = (on or (always and not inside)) and e > 0.01
		l.light_energy = e
	world.lamp_mat.emission_energy_multiplier = night * 9.0
	# dym z kominów: w dzień jasny, po zmroku ledwie widoczny na tle nieba (materiał nie łapie światła, więc gasimy go sami)
	var smk := lerpf(1.0, 0.2, night)
	for sm in world.smoke_mats:
		(sm as StandardMaterial3D).albedo_color = Color(smk, smk, smk * 1.04)
	for s in world.sirens:
		var kk := sin(t * 9.0) > 0.0
		s[0].visible = kk
		s[1].visible = not kk

	# --- deszcz
	var raining := rain > 0.04 and not inside
	rain_fx.emitting = raining
	rain_fx.visible = raining
	if raining:
		rain_fx.global_position = cam_pos + Vector3(0, 11.0, 0)
		rain_fx.amount_ratio = clampf(rain + 0.15, 0.1, 1.0)
