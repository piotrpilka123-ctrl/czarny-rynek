extends Node3D
## Świat: Osiedle Hutnik i okolice. Teren ze skarpą, schodami, górką i nasypem,
## budynki, rekwizyty, graf ścieżek, wnętrza, kolizje i punkty interakcji.

const Models = preload("res://scripts/models.gd")
const Props = preload("res://scripts/props.gd")
const Stations = preload("res://scripts/stations.gd")
const Interior = preload("res://scripts/interior.gd")
const Signs = preload("res://scripts/signs.gd")
const Facade = preload("res://scripts/facade.gd")
const Details = preload("res://scripts/details.gd")

const X0 := -210.0
const Z0 := -171.0
const CELL := 1.5
const NX := 281
const NZ := 229
const MAP_W := 840
const MAP_H := 684
## Skala planu miasta: wszystko jest o 38% bliżej siebie niż w projekcie.
const SC := 0.56
const INV := 1.0 / 0.56
const PLATEAU := 5.0
const STAIRS := [-27.0, 60.0]
const RAMPS := [[-106.0, -12.0, -52.0], [166.0, -10.0, -48.0]]

var rects: Array = []          # wysokie przeszkody 2D (budynki): {x0,x1,z0,z1,h}
var blocks: Array = []         # wszystko, co ma kolizję: {x0,x1,z0,z1,h,op} — op: zasłania widok
var _bk := PackedFloat32Array()   # to samo spakowane do szybkiego sprawdzania linii wzroku
var _col_opaque := true
var grid: AStarGrid2D          # siatka przejść dla pościgu (policja omija płoty i mury)
var crawls: Array = []         # przełazy tylko dla kucającego gracza: {x, z}
const GCELL := 0.5
var inter: Array = []          # stałe punkty interakcji: {loc,x,z,range,label,act}
var inter_dyn := {}            # meble w kryjówkach: pokój -> Array
var zones: Array = []
var lamps: Array = []
var door_tape: Node3D = null    # taśmy na drzwiach laboratorium (po prologu)
var mill_burnt: Node3D = null   # okopcenia i gruz pod Starą Hutą (po prologu)
var lab_fx := {}                # światła i rekwizyty laboratorium sterowane przez prolog
var windows: Array = []         # okna wnętrz: {pane, light, base} — env.gd gasi je nocą
var covers: Array = []          # krzaki, za którymi da się przyczaić: Vector3(x, z, promień) w metrach świata
var hides: Array = []           # kryjówki na czas pościgu (altanki śmietnikowe): {x, z, rot, name}
var _lamp_pts: PackedVector3Array = PackedVector3Array()
var lamp_mat: StandardMaterial3D
var sirens: Array = []
var rooms := {}
## gdzie gracz budzi się po wypadku albo zatrzymaniu: pokój -> [pozycja, obrót]
var wake := {}
var club_spots: Array = []
var club_ball: Node3D = null
var furn := {}                 # pokój -> Node3D z meblami
var furn_body := {}
var body: StaticBody3D
var city: Node3D
var rng := RandomNumberGenerator.new()
var noise_tex: NoiseTexture2D
var hg := PackedFloat32Array()
var img1: Image
var img2: Image
var map_tex: ImageTexture
var wp: Array = []             # graf ścieżek: {x, z, links: Array[int], zone}
var club_player: AudioStreamPlayer3D
var club_door := Vector3(-7.0 * 0.56, 1.5, 128.0 * 0.56)
var fac := {}
var fac_cell := {}             # rozmiar pola okna dla danego materiału elewacji
var balc: Array = []           # loggie: {b, code, cx, fl} — do rozstawiania anten, prania itp.
var grow_nodes := {}
var radio_player: AudioStreamPlayer3D = null
var radio_led: Node3D = null
var pot_nodes := {}          # pokój -> [węzeł doniczki, ...] (kolejność jak w zapisie)
var lamp_nodes := {}         # pokój -> {nr mebla: węzeł lampy}
var _bal_slab: Array = []
var _bal_rail: Array = []
var _lines: Array = []
var blds: Array = []           # budynki do minimapy
var ctl1_tex: ImageTexture
var ctl2_tex: ImageTexture
var tree_pos: Array = []
var _curbs: Array = []
var train := {}

const SH_COMMON := """
global uniform float night;
global uniform float wet;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
"""

const SH_TERRAIN := """
shader_type spatial;
""" + SH_COMMON + """
uniform sampler2D ctl1 : filter_linear, repeat_disable;
uniform sampler2D ctl2 : filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 map_rect;
uniform sampler2D a_asph : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_asph : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D a_pave : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_pave : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D a_conc : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_conc : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D a_dirt : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_dirt : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D a_grav : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D a_grass : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_grass : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D a_grass2 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D a_leaf : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 wpos;
void vertex() { wpos = VERTEX; }
void fragment() {
	vec2 muv = (wpos.xz - map_rect.xy) * map_rect.zw;
	float nz = texture(noise_tex, wpos.xz * 0.23).r;
	float nzb = texture(noise_tex, wpos.zx * 0.19 + 0.37).r;
	float big = texture(noise_tex, wpos.xz * 0.021).r;
	float mid = texture(noise_tex, wpos.xz * 0.07 + 0.11).r;
	vec2 warp = (vec2(nz, nzb) - 0.5) * 0.4 * map_rect.zw;
	vec4 c1 = texture(ctl1, muv + warp);
	vec4 c2 = texture(ctl2, muv + warp);
	// ostrzejsze, postrzępione granice nawierzchni
	vec4 w = smoothstep(vec4(0.4 + (nz - 0.5) * 0.16), vec4(0.6 + (nz - 0.5) * 0.16), c1);
	float wg = smoothstep(0.35, 0.65, c2.r);
	float sum = w.r + w.g + w.b + w.a + wg;
	float grass = clamp(1.0 - sum, 0.0, 1.0);
	vec3 alb = vec3(0.0);
	vec3 nrm = vec3(0.0);
	float rgh = 0.0;
	vec2 uv = wpos.xz;
	// im dalej od kamery, tym gładsze próbkowanie: drobne jasne ziarna asfaltu i płyt
	// nie „iskrzą” wtedy przy ruchu kamery
	float vdist = length(VERTEX);
	float lodb = 0.55 + smoothstep(2.0, 18.0, vdist) * 0.9;
	if (w.r > 0.003) {
		vec3 a = texture(a_asph, uv * 0.3, lodb).rgb;
		a *= 0.7 + mid * 0.5;
		alb += a * w.r; nrm += texture(n_asph, uv * 0.3, lodb).rgb * w.r; rgh += 0.86 * w.r;
	}
	if (w.g > 0.003) {
		vec3 a = texture(a_pave, uv * 0.42, lodb).rgb * (0.72 + mid * 0.4);
		alb += a * w.g; nrm += texture(n_pave, uv * 0.42, lodb).rgb * w.g; rgh += 0.9 * w.g;
	}
	if (w.b > 0.003) {
		vec3 a = texture(a_conc, uv * 0.3, lodb).rgb * (0.7 + mid * 0.45);
		alb += a * w.b; nrm += texture(n_conc, uv * 0.3, lodb).rgb * w.b; rgh += 0.88 * w.b;
	}
	if (w.a > 0.003) {
		vec3 a = texture(a_dirt, uv * 0.33, lodb).rgb * (0.75 + mid * 0.4);
		alb += a * w.a; nrm += texture(n_dirt, uv * 0.33, lodb).rgb * w.a; rgh += 0.95 * w.a;
	}
	if (wg > 0.003) {
		vec3 a = texture(a_grav, uv * 0.4, lodb).rgb * (0.7 + mid * 0.3);
		alb += a * wg; nrm += vec3(0.5, 0.5, 1.0) * wg; rgh += 0.95 * wg;
	}
	if (grass > 0.003) {
		vec3 g1 = texture(a_grass, uv * 0.31, lodb).rgb;
		vec3 g2 = texture(a_grass2, uv * 0.27, lodb).rgb;
		vec3 a = mix(g1, g2, smoothstep(0.42, 0.62, big));
		a = mix(vec3(dot(a, vec3(0.3, 0.5, 0.2))), a, 0.55) * vec3(0.92, 0.95, 0.8) * (0.6 + mid * 0.42);
		float litter = smoothstep(0.25, 0.6, c2.b + (nz - 0.5) * 0.5 + (mid - 0.5) * 0.3);
		vec3 lf = texture(a_leaf, uv * 0.36, lodb).rgb;
		lf = mix(vec3(dot(lf, vec3(0.33))), lf, 0.6) * 0.72;
		a = mix(a, lf, litter * 0.9);
		alb += a * grass; nrm += texture(n_grass, uv * 0.31, lodb).rgb * grass; rgh += 0.97 * grass;
	}
	float tot = max(0.001, sum + grass);
	alb /= tot; nrm /= tot; rgh /= tot;
	// wytarte linie na jezdni
	float wear = smoothstep(0.3, 0.62, nz * 0.7 + mid * 0.5);
	float mark = smoothstep(0.45, 0.7, texture(ctl2, muv).g) * smoothstep(0.25, 0.5, nz) * smoothstep(0.3, 0.55, nzb);
	alb = mix(alb, vec3(0.6, 0.6, 0.56), mark * wear * 0.7);
	// kałuże i mokra nawierzchnia
	float hard = clamp(w.r + w.g + w.b, 0.0, 1.0);
	float puddle = smoothstep(0.56, 0.66, big * 0.6 + mid * 0.5) * hard * max(wet, 0.18 * w.r);
	alb *= 1.0 - wet * 0.3 - puddle * 0.35;
	ALBEDO = alb;
	NORMAL_MAP = mix(nrm, vec3(0.5, 0.5, 1.0), puddle);
	NORMAL_MAP_DEPTH = mix(0.85, 0.2, smoothstep(2.5, 20.0, vdist));
	ROUGHNESS = mix(min(1.0, rgh + 0.06) - wet * 0.25, 0.06, puddle);
	SPECULAR = 0.2 + wet * 0.15 + puddle * 0.4;
}
"""

# ================================================================ teren
static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _ha(x: float, z: float) -> float:
	var und := 0.2 * sin(x * 0.045 + 1.3) * cos(z * 0.052 - 0.4) + 0.1 * sin(x * 0.11 - z * 0.07)
	var h := PLATEAU * _ss(-18.0, -30.0, z)
	for sx in STAIRS:
		var w := 1.0 - _ss(1.7, 2.4, absf(x - sx))
		if w > 0.0:
			h = lerpf(h, PLATEAU * clampf((-18.0 - z) / 12.0, 0.0, 1.0), w)
	for r in RAMPS:
		var w2 := 1.0 - _ss(4.6, 9.0, absf(x - r[0]))
		if w2 > 0.0:
			h = lerpf(h, PLATEAU * _ss(r[1], r[2], z), w2)
			und *= 1.0 - w2 * 0.7
	var d := Vector2(x + 122.0, z - 104.0).length()
	h += 7.0 * pow(_ss(54.0, 6.0, d), 1.4)
	var gx := _ss(40.0, 46.0, x) * (1.0 - _ss(106.0, 112.0, x))
	var gz := _ss(58.0, 64.0, z) * (1.0 - _ss(104.0, 110.0, z))
	h -= 1.2 * gx * gz
	var e := 5.7 * (1.0 - _ss(4.0, 13.0, absf(x - 145.0)))
	if z > 12.0 and z < 28.0:
		e = 0.0
	return maxf(h + und, e + und * 0.4)


func _heights() -> void:
	hg.resize(NX * NZ)
	for j in range(NZ):
		var z := Z0 + j * CELL
		for i in range(NX):
			hg[j * NX + i] = _ha(X0 + i * CELL, z)


func height(x: float, z: float) -> float:
	if x > 500.0:
		return 0.0
	return hd(x * INV, z * INV)


func hd(x: float, z: float) -> float:
	var fx := clampf((x - X0) / CELL, 0.0, NX - 1.001)
	var fz := clampf((z - Z0) / CELL, 0.0, NZ - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var k := j * NX + i
	var a := lerpf(hg[k], hg[k + 1], tx)
	var b := lerpf(hg[k + NX], hg[k + NX + 1], tx)
	return lerpf(a, b, tz)


func ground_y(x: float, z: float) -> float:
	return height(x, z)


## rodzaj nawierzchni pod stopami (do dźwięku kroków)
func surface_at(x: float, z: float) -> String:
	var px := clampi(int((x * INV - X0) * 2.0), 0, MAP_W - 1)
	var pz := clampi(int((z * INV - Z0) * 2.0), 0, MAP_H - 1)
	var a := img1.get_pixel(px, pz)
	if a.r > 0.5 or a.g > 0.5 or a.b > 0.5:
		return "concrete"
	return "grass"


# ---------------------------------------------------------------- mapa nawierzchni
func _rc(x0: float, z0: float, x1: float, z1: float) -> Rect2i:
	var px := int(round((x0 - X0) * 2.0))
	var pz := int(round((z0 - Z0) * 2.0))
	return Rect2i(px, pz, max(1, int(round((x1 - x0) * 2.0))), max(1, int(round((z1 - z0) * 2.0))))


## warstwy: 0 asfalt, 1 płyty chodnikowe, 2 beton, 3 ziemia, 4 tłuczeń, 5 trawa (czyści)
func _pr(layer: int, x0: float, z0: float, x1: float, z1: float) -> void:
	var r := _rc(x0, z0, x1, z1)
	var c := Color(0, 0, 0, 0)
	if layer < 4:
		c[layer] = 1.0
	img1.fill_rect(r, c)
	img2.fill_rect(r, Color(1.0 if layer == 4 else 0.0, 0, 0, 1))


func _pl(layer: int, a: Vector2, b: Vector2, width: float) -> void:
	var hw := width * 0.5
	var x0 := int(floor((minf(a.x, b.x) - hw - X0) * 2.0))
	var x1 := int(ceil((maxf(a.x, b.x) + hw - X0) * 2.0))
	var z0 := int(floor((minf(a.y, b.y) - hw - Z0) * 2.0))
	var z1 := int(ceil((maxf(a.y, b.y) + hw - Z0) * 2.0))
	var ab := b - a
	var l2 := maxf(0.0001, ab.length_squared())
	var c := Color(0, 0, 0, 0)
	if layer < 4:
		c[layer] = 1.0
	var c2 := Color(1.0 if layer == 4 else 0.0, 0, 0, 1)
	for pz in range(max(0, z0), min(MAP_H, z1 + 1)):
		for px in range(max(0, x0), min(MAP_W, x1 + 1)):
			var p := Vector2(X0 + px * 0.5, Z0 + pz * 0.5)
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			if p.distance_to(a + ab * t) <= hw:
				img1.set_pixel(px, pz, c)
				img2.set_pixel(px, pz, c2)


func _path(layer: int, pts: Array, width: float) -> void:
	for i in range(pts.size() - 1):
		_pl(layer, Vector2(pts[i][0], pts[i][1]), Vector2(pts[i + 1][0], pts[i + 1][1]), width)


func _mark(x0: float, z0: float, x1: float, z1: float) -> void:
	var r := _rc(x0, z0, x1, z1)
	for pz in range(r.position.y, r.position.y + r.size.y):
		for px in range(r.position.x, r.position.x + r.size.x):
			if px >= 0 and pz >= 0 and px < MAP_W and pz < MAP_H:
				var c := img2.get_pixel(px, pz)
				c.g = 1.0
				img2.set_pixel(px, pz, c)


func _paint() -> void:
	img1 = Image.create(MAP_W, MAP_H, false, Image.FORMAT_RGBA8)
	img2 = Image.create(MAP_W, MAP_H, false, Image.FORMAT_RGBA8)
	img1.fill(Color(0, 0, 0, 0))
	img2.fill(Color(0, 0, 0, 1))
	# --- place, podwórka, zaułki
	_pr(2, -92.0, -17.0, 48.0, -10.0)
	_pr(1, 48.0, -17.0, 72.0, 11.5)
	for p in [[-60.0, -56.0], [-30.0, -24.0], [10.0, 16.0]]:
		_pr(1, p[0], -10.0, p[1], 11.5)
	_pr(3, -90.0, 50.0, 68.0, 57.0)
	_pr(2, 42.0, 72.0, 108.0, 96.0)
	_pr(3, 42.0, 102.0, 112.0, 114.0)
	_pr(2, -86.0, 118.0, -54.0, 138.0)
	_pr(1, 54.0, -47.0, 90.0, -36.0)
	_pr(3, -16.0, -117.0, 6.0, -105.0)
	_pr(2, 20.0, -126.5, 72.0, -115.0)
	_pr(1, -196.0, 8.0, -150.0, 11.5)
	_pr(2, -164.0, -8.0, -150.0, 8.0)
	_pr(2, 160.0, 28.5, 206.0, 90.0)
	_pr(3, 160.0, -17.0, 206.0, 11.5)
	_pr(2, 170.0, -52.0, 206.0, -44.0)
	_pr(3, 38.0, 126.0, 128.0, 168.0)
	_pr(4, 141.0, -171.0, 149.0, 171.0)
	_pr(2, -96.0, -56.0, -44.0, -50.0)
	_pr(2, 104.0, -126.0, 112.0, -68.0)
	_pr(3, -90.0, 57.0, -50.0, 62.0)
	_pr(3, 80.0, 74.0, 92.0, 86.0)
	_pr(3, 58.0, 130.0, 70.0, 142.0)
	_pr(2, -46.0, 84.0, -9.0, 100.0)
	# --- chodniki
	_pr(1, -208.0, 11.5, 208.0, 15.5)
	_pr(1, -208.0, 24.5, 208.0, 28.5)
	_pr(1, -7.0, 28.5, -3.5, 150.0)
	_pr(1, 3.5, 28.5, 7.0, 150.0)
	_pr(1, 7.0, 116.0, 14.0, 140.0)
	_pr(1, -102.5, -126.5, -99.5, 11.5)
	_pr(1, -102.5, -126.5, 91.5, -123.5)
	_pr(1, -109.5, -136.5, 98.5, -133.5)
	_pr(1, 88.5, -123.5, 91.5, -60.0)
	_pr(1, -28.2, -123.5, -25.8, -30.0)
	_pr(1, 58.8, -66.0, 61.2, -30.0)
	_pr(1, -99.5, -67.2, 88.5, -64.8)
	_pr(1, -99.5, -104.2, 88.5, -101.8)
	_pr(1, 6.8, -78.0, 9.2, -66.0)
	_pr(1, -61.2, -78.0, -58.8, -66.0)
	_pr(1, -51.2, -146.0, -48.8, -136.5)
	_pr(1, 38.8, -146.0, 41.2, -136.5)
	_pr(1, -119.0, -97.0, -109.5, -93.0)
	_pr(1, -119.0, -154.0, -109.5, -150.0)
	for sx in STAIRS:
		_pr(2, sx - 1.8, -30.5, sx + 1.8, -17.5)
	# --- ścieżki gruntowe i żwirowe
	_path(4, [[-96.0, 28.5], [-96.0, 56.0], [-88.0, 66.0], [-110.0, 70.0], [-150.0, 60.0], [-170.0, 90.0], [-160.0, 122.0], [-130.0, 150.0], [-90.0, 150.0], [-70.0, 140.0]], 2.6)
	_path(4, [[-88.0, 66.0], [-60.0, 100.0], [-70.0, 118.0]], 2.4)
	_path(4, [[-7.0, 100.0], [-60.0, 100.0]], 2.4)
	_path(3, [[-88.0, 66.0], [-105.0, 85.0], [-122.0, 104.0], [-140.0, 112.0], [-160.0, 122.0]], 1.8)
	_path(3, [[7.0, 84.0], [42.0, 84.0]], 2.6)
	_path(3, [[12.0, -30.0], [10.0, -17.0]], 1.4)
	_path(3, [[91.5, -66.0], [128.0, -66.0], [145.0, -66.0], [162.5, -66.0]], 1.6)
	_path(3, [[-27.0, -104.0], [-10.0, -110.0]], 1.5)
	_path(3, [[172.0, 30.0], [180.0, 56.0], [192.0, 62.0]], 2.4)
	_path(3, [[47.0, -111.5], [47.0, -104.0]], 1.2)
	_path(3, [[-84.0, -13.5], [-92.0, -13.5]], 1.4)
	# --- jezdnie
	_pr(0, -208.0, 15.5, 208.0, 24.5)
	_pr(0, -3.5, 24.5, 3.5, 150.0)
	_pr(0, -109.5, -133.5, -102.5, 15.5)
	_pr(0, -109.5, -133.5, 98.5, -126.5)
	_pr(0, 91.5, -126.5, 98.5, -60.0)
	_pr(0, 72.0, 24.5, 78.0, 72.0)
	_pr(0, 162.5, -100.0, 169.5, 15.5)
	# --- oznakowanie
	var x := -204.0
	while x < 204.0:
		_mark(x, 19.85, x + 3.0, 20.15)
		x += 9.0
	for zx in [-98.0, -11.0, 9.0, 64.0, 124.0]:
		for k in range(6):
			_mark(zx, 16.0 + k * 1.45, zx + 3.0, 16.7 + k * 1.45)
	for k in range(5):
		_mark(-3.0 + k * 1.3, 112.0, -2.3 + k * 1.3, 115.0)
	for k in range(9):
		_mark(22.0 + k * 5.6, -125.5, 22.2 + k * 5.6, -116.0)


func _terrain_mesh() -> void:
	var sh := Shader.new()
	sh.code = SH_TERRAIN
	var m := ShaderMaterial.new()
	m.shader = sh
	ctl1_tex = ImageTexture.create_from_image(img1)
	ctl2_tex = ImageTexture.create_from_image(img2)
	m.set_shader_parameter("ctl1", ctl1_tex)
	m.set_shader_parameter("ctl2", ctl2_tex)
	m.set_shader_parameter("noise_tex", noise_tex)
	m.set_shader_parameter("map_rect", Vector4(X0 * SC, Z0 * SC, 1.0 / (MAP_W * 0.5 * SC), 1.0 / (MAP_H * 0.5 * SC)))
	var T := "res://assets/tex/%s.jpg"
	for e in [["a_asph", "asphalt_02_diff"], ["n_asph", "asphalt_02_nor"], ["a_leaf", "leaves_forest_ground_diff"], ["a_pave", "concrete_pavement_02_diff"], ["n_pave", "concrete_pavement_02_nor"],
			["a_conc", "dirty_concrete_diff"], ["n_conc", "dirty_concrete_nor"], ["a_dirt", "dirt_diff"], ["n_dirt", "dirt_nor"], ["a_grav", "gravel_floor_diff"],
			["a_grass", "forrest_ground_01_diff"], ["n_grass", "forrest_ground_01_nor"], ["a_grass2", "brown_mud_leaves_01_diff"]]:
		m.set_shader_parameter(e[0], Props.tex(T % e[1]))
	# teren w kaflach: kamera rysuje tylko widoczne, a grunt nie trafia do map cieni
	var step := 40
	var cj := 0
	while cj < NZ - 1:
		var j1: int = mini(cj + step, NZ - 1)
		var ci := 0
		while ci < NX - 1:
			var i1: int = mini(ci + step, NX - 1)
			var mi := MeshInstance3D.new()
			mi.mesh = _terrain_chunk(ci, i1, cj, j1)
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			ci = i1
		cj = j1
	# daleki plan: płaska, ciemna ziemia poza mapą
	var far := Models.box(self, Vector3(1400.0, 0.2, 1400.0), Vector3(0, -0.4, 0), Props.pbr("withered_grass", 0.2, Color(0.5, 0.5, 0.45)), Vector3.ZERO, false)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## siatka fragmentu terenu: węzły siatki wysokości od (i0, j0) do (i1, j1) włącznie
func _terrain_chunk(i0: int, i1: int, j0: int, j1: int) -> ArrayMesh:
	var w := i1 - i0 + 1
	var h := j1 - j0 + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(w * h)
	norms.resize(w * h)
	uvs.resize(w * h)
	tans.resize(w * h * 4)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var k := j * NX + i
			var q := (j - j0) * w + (i - i0)
			var x := X0 + i * CELL
			var z := Z0 + j * CELL
			verts[q] = Vector3(x * SC, hg[k], z * SC)
			var hl := hg[k - 1] if i > 0 else hg[k]
			var hr := hg[k + 1] if i < NX - 1 else hg[k]
			var hu := hg[k - NX] if j > 0 else hg[k]
			var hdn := hg[k + NX] if j < NZ - 1 else hg[k]
			norms[q] = Vector3(hl - hr, CELL * SC * 2.0, hu - hdn).normalized()
			uvs[q] = Vector2(x * SC, z * SC)
			tans[q * 4] = 1.0
			tans[q * 4 + 1] = 0.0
			tans[q * 4 + 2] = 0.0
			tans[q * 4 + 3] = 1.0
	idx.resize((w - 1) * (h - 1) * 6)
	var n := 0
	for j in range(h - 1):
		for i in range(w - 1):
			var a := j * w + i
			idx[n] = a
			idx[n + 1] = a + 1
			idx[n + 2] = a + w
			idx[n + 3] = a + 1
			idx[n + 4] = a + w + 1
			idx[n + 5] = a + w
			n += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _map_texture() -> void:
	var m := Image.create(MAP_W / 2, MAP_H / 2, false, Image.FORMAT_RGB8)
	for pz in range(MAP_H / 2):
		for px in range(MAP_W / 2):
			var a := img1.get_pixel(px * 2, pz * 2)
			var b := img2.get_pixel(px * 2, pz * 2)
			var c := Color(0.085, 0.115, 0.09)
			if a.r > 0.5: c = Color(0.2, 0.21, 0.24)
			elif a.g > 0.5: c = Color(0.3, 0.31, 0.33)
			elif a.b > 0.5: c = Color(0.25, 0.25, 0.26)
			elif a.a > 0.5: c = Color(0.19, 0.16, 0.11)
			elif b.r > 0.5: c = Color(0.24, 0.21, 0.19)
			m.set_pixel(px, pz, c)
	for b2 in blds:
		var r := Rect2i(int((b2.x0 - X0)), int((b2.z0 - Z0)), max(1, int(b2.x1 - b2.x0)), max(1, int(b2.z1 - b2.z0)))
		m.fill_rect(r, Color(0.36, 0.4, 0.5) if not b2.get("low", false) else Color(0.3, 0.32, 0.38))
	map_tex = ImageTexture.create_from_image(m)


# ================================================================ budowa
## `loader` (opcjonalny ekran ładowania) dostaje opis kolejnych etapów budowy miasta
func build(loader = null) -> void:
	rng.seed = 20261005
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.012
	fn.fractal_octaves = 5
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.seamless = true
	noise_tex.noise = fn
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.9, 0.85, 0.7)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.72, 0.4)
	lamp_mat.emission_energy_multiplier = 0.0
	_facade_mats()
	zones = D.ZONES
	body = StaticBody3D.new()
	add_child(body)
	city = Node3D.new()
	city.scale = Vector3(SC, 1.0, SC)
	add_child(city)
	if loader != null:
		await loader.step(4.0, "Surveying the terrain")
	_heights()
	_paint()
	if loader != null:
		await loader.step(14.0, "Pouring asphalt")
	_terrain_mesh()
	_graph()
	if loader != null:
		await loader.step(22.0, "Raising the blocks")
	_buildings()
	_estate()
	if loader != null:
		await loader.step(32.0, "Opening the corner shops")
	_lower_town()
	if loader != null:
		await loader.step(38.0, "Planting what still grows")
	_park()
	if loader != null:
		await loader.step(44.0, "Laying the tracks")
	_rail()
	_industrial()
	if loader != null:
		await loader.step(52.0, "Spraying graffiti")
	_dense()
	_trap_houses()
	Details.entrances(self)
	Details.wall_art(self)
	Details.facade_props(self)
	Details.flush(self)
	if loader != null:
		await loader.step(58.0, "Building the overpass")
	_viaduct()
	_lamps()
	_backdrop()
	_curb_lines()
	_hide_spots()
	_lockers()
	_build_grid()
	if loader != null:
		await loader.step(66.0, "Furnishing the hideouts")
	_interiors()
	if loader != null:
		await loader.step(72.0, "Letting the weeds in")
	_ground_details()
	_flush_multimeshes()
	_map_texture()
	_club_audio()
	for id in D.DOORS:
		door(id)
	set_mill_burnt(true)
	_markers()


func _facade_mats() -> void:
	var sh := Shader.new()
	sh.code = Facade.SH
	# [tekstura, skala, styl, pole okna (m), tekstura pod tynkiem, ile tynku odpadło]
	var defs := {
		"plyta": ["concrete_wall_008", 0.2, 0, Vector2(3.6, 3.0), "", 0.0],
		"plyta2": ["grey_plaster_03", 0.22, 0, Vector2(3.6, 3.0), "", 0.0],
		"kamA": ["damaged_plaster", 0.2, 1, Vector2(3.2, 3.8), "factory_brick", 0.55],
		"kamB": ["grey_plaster_03", 0.25, 1, Vector2(3.2, 3.8), "brick_wall_10", 0.35],
		"kamC": ["peeling_painted_wall", 0.3, 1, Vector2(3.2, 3.8), "factory_brick", 0.6],
		"kamD": ["blue_plaster_weathered", 0.3, 1, Vector2(3.2, 3.8), "brick_wall_10", 0.45],
		"cegla": ["factory_brick", 0.28, 3, Vector2(5.0, 5.2), "", 0.0],
		"cegla2": ["brick_wall_10", 0.3, 1, Vector2(3.2, 3.8), "", 0.0],
		"klub": ["grey_plaster_03", 0.3, 4, Vector2(4.0, 2.5), "", 0.0],
		"urzad": ["concrete_wall_008", 0.25, 6, Vector2(3.0, 3.6), "", 0.0],
	}
	for k in defs:
		var d: Array = defs[k]
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("noise_tex", noise_tex)
		m.set_shader_parameter("wall_tex", Props.tex("res://assets/tex/%s_diff.jpg" % d[0]))
		m.set_shader_parameter("wall_nor", Props.tex("res://assets/tex/%s_nor.jpg" % d[0]))
		m.set_shader_parameter("alt_tex", Props.tex("res://assets/tex/%s_diff.jpg" % (d[4] if d[4] != "" else d[0])))
		m.set_shader_parameter("alt_amount", d[5])
		m.set_shader_parameter("tex_scale", d[1])
		m.set_shader_parameter("style", d[2])
		m.set_shader_parameter("cellsz", d[3])
		fac[k] = m
		fac_cell[k] = d[3]


## `blk_h`: wysokość przeszkody dla policji i linii wzroku, gdy sama bryła kolizji zaczyna się wyżej (przełaz)
func add_col(x0: float, x1: float, z0: float, z1: float, h := 4.0, solid := true, base := -999.0, blk_h := -1.0) -> void:
	var by := base
	if by < -900.0:
		by = minf(minf(hd(x0, z0), hd(x1, z1)), minf(hd(x0, z1), hd(x1, z0))) - 2.0 if x0 < 500.0 else -1.0
	if x0 < 500.0:
		x0 *= SC
		x1 *= SC
		z0 *= SC
		z1 *= SC
	rects.append({"x0": x0, "x1": x1, "z0": z0, "z1": z1, "h": h})
	if solid and x0 < 400.0:
		blocks.append({"x0": x0, "x1": x1, "z0": z0, "z1": z1, "h": blk_h if blk_h > 0.0 else h, "op": _col_opaque})
	if solid:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(x1 - x0, h + 4.0, z1 - z0)
		cs.shape = sh
		cs.position = Vector3((x0 + x1) * 0.5, by + (h + 4.0) * 0.5, (z0 + z1) * 0.5)
		body.add_child(cs)


func _base(x0: float, z0: float, x1: float, z1: float) -> float:
	return minf(minf(hd(x0, z0), hd(x1, z1)), minf(hd(x0, z1), hd(x1, z0)))


## Siatka okien na ścianie długości `ln` metrów: [margines, liczba pól]. Gdy podano `anchor`
## (metry od początku ściany), siatka przesuwa się tak, żeby środek jednego pola wypadł dokładnie tam.
static func grid_for(ln: float, cs: float, anchor := -1.0) -> Array:
	var n: int = maxi(1, int(floor((ln - 0.5) / cs)))
	var m := (ln - n * cs) * 0.5
	if anchor >= 0.0:
		var k := int(round((anchor - m) / cs - 0.5))
		m = anchor - (k + 0.5) * cs
		while m < 0.25:
			m += cs
		n = maxi(1, int(floor((ln - 0.25 - m) / cs)))
	return [m, n]


## budynek-prostopadłościan z elewacją; key: materiał z `fac`.
## opt: blind (0|1|2), pattern (0..4), stair (co ile pól klatka schodowa), front (ściana z wejściami: 1 = +Z, 2 = -Z, 3 = +X, 4 = -X),
## door_at (współrzędna planu, w której ma wypaść klatka), no (numer bloku), balc (false = bez balkonów)
func building(x0: float, z0: float, x1: float, z1: float, h: float, key: String, wall := Color(0.8, 0.8, 0.78), accent := Color(0.8, 0.55, 0.3), dead := 0.0, _balconies_unused := false, opt := {}) -> void:
	var by := _base(x0, z0, x1, z1) - 0.6
	var w := x1 - x0
	var d := z1 - z0
	var plyta := key.begins_with("plyta")
	var old := key.begins_with("kam") or key == "cegla2"
	var cs: Vector2 = fac_cell[key]
	# ściany szczytowe bloków i ściany ogniowe kamienic (krótsze boki) są ślepe
	var blind: int = opt.get("blind", (1 if w >= d else 2) if (old or (plyta and (w > d * 1.5 or d > w * 1.5))) else 0)
	var stair: int = opt.get("stair", 3 if (plyta and maxf(w, d) * SC > 12.0) else 0)
	var pattern: int = opt.get("pattern", rng.randi_range(0, 4) if plyta else 0)
	var front: int = opt.get("front", 1 if w >= d else 3)
	var ax := -1.0
	var az := -1.0
	if opt.has("door_at"):
		if front <= 2:
			ax = (float(opt.door_at) - x0) * SC
		else:
			az = (float(opt.door_at) - z0) * SC
	var gx := grid_for(w * SC, cs.x, ax)
	var gz := grid_for(d * SC, cs.x, az)
	# kolumna klatki schodowej: ta, w którą celuje door_at; inaczej środkowa w każdym segmencie
	var st_off := 1
	if stair > 0 and opt.has("door_at"):
		var g: Array = gx if front <= 2 else gz
		var a := ax if front <= 2 else az
		st_off = posmod(int(floor((a - float(g[0])) / cs.x)), stair)
	var mi := Models.box(city, Vector3(w, h + 0.6, d), Vector3((x0 + x1) * 0.5, by + (h + 0.6) * 0.5, (z0 + z1) * 0.5), fac[key])
	mi.set_instance_shader_parameter("b_origin", Vector3(x0 * SC, by + 0.6, z0 * SC))
	mi.set_instance_shader_parameter("b_size", Vector3(w * SC, h, d * SC))
	mi.set_instance_shader_parameter("b_wall", wall)
	mi.set_instance_shader_parameter("b_accent", accent)
	mi.set_instance_shader_parameter("b_seed", rng.randf() * 10.0)
	mi.set_instance_shader_parameter("b_dead", dead)
	mi.set_instance_shader_parameter("b_opts", Vector4(float(blind), float(pattern), float(stair) + float(st_off) / 16.0, 0.0))
	mi.set_instance_shader_parameter("b_grid", Vector4(gx[0], gx[1], gz[0], gz[1]))
	add_col(x0, x1, z0, z1, h)
	blds.append({"x0": x0, "x1": x1, "z0": z0, "z1": z1, "h": h, "by": by + 0.6, "key": key, "blind": blind, "stair": stair, "st_off": st_off, "front": front,
		"gx": gx, "gz": gz, "accent": accent, "wall": wall, "node": mi, "no": String(opt.get("no", "")), "plyta": plyta, "old": old, "dead": dead})
	var top := by + 0.6 + h
	# attyka i nadbudówki
	var rm := Models.mat("1a1a1c", 0.95)
	Models.box(city, Vector3(w + 0.3, 0.35, d + 0.3), Vector3((x0 + x1) * 0.5, top + 0.1, (z0 + z1) * 0.5), rm)
	if key.begins_with("kam") or key == "cegla2":
		var pm := PrismMesh.new()
		pm.size = Vector3(d + 0.8, 3.6, w + 0.8)
		var roof := MeshInstance3D.new()
		roof.mesh = pm
		roof.material_override = Props.pbr("asbestos_sheet", 0.35, Color(0.55, 0.5, 0.5))
		roof.position = Vector3((x0 + x1) * 0.5, top + 2.0, (z0 + z1) * 0.5)
		roof.rotation.y = PI / 2.0
		city.add_child(roof)
		var px2 := x0 + 4.0
		while px2 < x1 - 2.0:
			Models.box(city, Vector3(0.9, 2.4, 0.9), Vector3(px2, top + 2.6, (z0 + z1) * 0.5 + rng.randf_range(-3.0, 3.0)), Props.pbr("factory_brick", 0.5, Color(0.7, 0.6, 0.55)))
			px2 += rng.randf_range(7.0, 12.0)
	elif h > 12.0:
		var k := 0
		var px := x0 + 6.0
		while px < x1 - 4.0:
			Models.box(city, Vector3(3.2, 2.2, 3.4), Vector3(px, top + 1.2, (z0 + z1) * 0.5), Props.pbr("concrete_wall_008", 0.3, Color(0.7, 0.7, 0.7)))
			if k % 2 == 0:
				Models.cyl(city, 0.03, 0.04, 5.0, Vector3(px + 1.0, top + 4.5, (z0 + z1) * 0.5), rm, Vector3.ZERO, 5)
			px += 14.0
			k += 1
	if plyta and opt.get("balc", true):
		_balconies(blds.back())


## Płyty i balustrady loggii — dokładnie tam, gdzie shader elewacji rysuje wnęki balkonowe.
func _balconies(b: Dictionary) -> void:
	var cs: Vector2 = fac_cell[b.key]
	var floors := int(floor((float(b.h) + 0.3) / cs.y))
	var stair: int = b.stair
	for code in range(1, 5):
		var xface := code >= 3                    # ściana prostopadła do osi X
		if (int(b.blind) == 1 and xface) or (int(b.blind) == 2 and not xface):
			continue
		var g: Array = b.gz if xface else b.gx
		var out := 1.0 if code % 2 == 1 else -1.0
		var wall_c: float = [b.z1, b.z0, b.x1, b.x0][code - 1]
		for cx in range(int(g[1])):
			var is_stair := stair > 0 and posmod(cx - int(b.st_off), stair) == 0
			if is_stair or cx % 2 == 0:
				continue
			var along := (float(g[0]) + (cx + 0.5) * cs.x) * INV
			for fl in range(1, floors):
				var y := float(b.by) + fl * cs.y + 0.09
				var col: Color = (b.accent as Color).lerp(Color(0.6, 0.6, 0.57), rng.randf_range(0.0, 0.85)) * rng.randf_range(0.55, 1.0)
				if rng.randf() < 0.12:
					col = Color(0.75, 0.74, 0.7)
				var basis := Basis(Vector3.UP, PI / 2.0) if xface else Basis.IDENTITY
				var ps := Vector3(wall_c + out * 0.34 * INV, y, float(b.z0) + along) if xface else Vector3(float(b.x0) + along, y, wall_c + out * 0.34 * INV)
				var pr := Vector3(wall_c + out * 0.7 * INV, y + 0.56, float(b.z0) + along) if xface else Vector3(float(b.x0) + along, y + 0.56, wall_c + out * 0.7 * INV)
				_bal_slab.append(Transform3D(basis, ps))
				_bal_rail.append([Transform3D(basis, pr), col])
				balc.append({"b": b, "code": code, "cx": cx, "fl": fl})


func _sign(text: String, pos: Vector3, color: Color, size := 120, rot_y := 0.0, px := 0.006, outline := 14) -> Label3D:
	var l := Signs.text(text, "bebas", size, color, px, outline, Color(0, 0, 0, 0.75))
	l.position = pos
	l.rotation.y = rot_y
	l.scale = Vector3(INV, 1.0, INV)
	city.add_child(l)
	return l


## graffiti na murze, płocie albo garażu (kalkomania wtopiona w powierzchnię); im większy `size`, tym większa forma
func _graffiti(_text: String, x: float, z: float, y: float, rot_y: float, _color: Color, size := 200) -> void:
	var kind := "tag"
	var width := rng.randf_range(0.9, 1.4)
	if size >= 190:
		kind = "piece" if rng.randf() < 0.5 else "throw"
		width = rng.randf_range(2.6, 3.6)
	elif size >= 140:
		kind = "throw" if rng.randf() < 0.6 else "slogan"
		width = rng.randf_range(1.8, 2.6)
	elif size >= 105 and rng.randf() < 0.4:
		kind = "slogan"
		width = rng.randf_range(1.8, 2.4)
	var n := Vector3(sin(rot_y), 0.0, cos(rot_y))
	Details.decal(self, Details.pick(kind), Vector3(x * SC, hd(x, z) + y, z * SC) + n * 0.02, rot_y, width)


## element przyklejony do ściany (szyld, plakat, mural) — bez ściskania
func _wall(n: Node3D, x: float, y: float, z: float, rot_y: float) -> void:
	n.position = Vector3(x, hd(x, z) + y, z)
	n.rotation.y = rot_y
	n.scale = Vector3(INV, 1.0, INV)
	city.add_child(n)


func _prop(name: String, x: float, z: float, ry := 0.0, h := 0.0, solid := 0.0, shadows := true, yoff := 0.0) -> Node3D:
	var n := Props.make(name, h, 0.0, shadows)
	n.position = Vector3(x, hd(x, z) + yoff, z)
	n.rotation.y = ry
	n.scale = Vector3(INV, 1.0, INV)
	city.add_child(n)
	Props.set_range(n, 90.0)
	if not (name in SOFT_PROPS):
		_auto_col(n)
	return n


## rekwizyty, przez które wolno przejść (miękkie albo leżące płasko)
const SOFT_PROPS := ["trashbag", "trashbag_1", "trashbag_2", "cardboard_box_01", "old_tyre", "dirty_football", "can_rusted", "pallet", "pallet_broken", "cement_bag",
	"water_manhole_cover", "cigarette_pack", "spray_paint_bottles", "plastic_bottle_gallon", "rusted_wheel_rim_01"]

## Kolizja z rzeczywistych brył modelu: każda część wyższa niż kolano dostaje własne pudełko.
## Dzięki temu nie da się przejść przez kosz, krzesło czy beczkę, a pokrywa leżąca obok kosza nie blokuje.
func _auto_col(n: Node3D) -> void:
	var boxes: Array = []
	_mesh_boxes(n, boxes)
	for bb in boxes:
		var a: AABB = bb
		var gy := height(a.get_center().x, a.get_center().z)
		if a.end.y - gy < 0.55 or a.position.y - gy > 0.7 or maxf(a.size.x, a.size.z) > 12.0 or minf(a.size.x, a.size.z) < 0.12:
			continue
		var k := 0.42
		var cx := a.get_center().x * INV
		var cz := a.get_center().z * INV
		add_col(cx - a.size.x * k * INV, cx + a.size.x * k * INV, cz - a.size.z * k * INV, cz + a.size.z * k * INV, minf(2.6, a.end.y - gy))
		rects.pop_back()


func _mesh_boxes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi: MeshInstance3D = n
		out.append(mi.global_transform * mi.mesh.get_aabb())
	for c in n.get_children():
		_mesh_boxes(c, out)


func _place(n: Node3D, x: float, z: float, ry := 0.0, solid_x := 0.0, solid_z := 0.0, h := 1.2, keep := true) -> Node3D:
	n.position = Vector3(x, hd(x, z), z)
	n.rotation.y = ry
	var k := INV if keep else 1.0
	if keep:
		n.scale = Vector3(INV, 1.0, INV)
	city.add_child(n)
	if solid_x > 0.0:
		add_col(x - solid_x * k, x + solid_x * k, z - solid_z * k, z + solid_z * k, h)
		if h < 3.0:
			rects.pop_back()
	return n


## Stara Huta po prologu: okopcone ściany nad wybitymi oknami, gruz, taśmy. W czasie prologu ukryte.
func set_mill_burnt(on: bool) -> void:
	if mill_burnt == null:
		mill_burnt = Node3D.new()
		city.add_child(mill_burnt)
		var soot := StandardMaterial3D.new()
		soot.albedo_color = Color(0.02, 0.02, 0.02, 0.78)
		soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		soot.albedo_texture = Props._soft_tex()
		soot.cull_mode = BaseMaterial3D.CULL_DISABLED
		soot.roughness = 1.0
		var by := hd(176.0, -90.0)
		var r2 := RandomNumberGenerator.new()
		r2.seed = 4477
		# zachodnia i północna ściana: jęzory sadzy od okien w górę
		for i in range(11):
			var z := -108.0 + i * 5.2 + r2.randf_range(-0.8, 0.8)
			var hh := r2.randf_range(3.5, 7.5)
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(r2.randf_range(3.0, 5.5) * INV, hh)
			q.mesh = qm
			q.material_override = soot
			q.position = Vector3(175.9, by + r2.randf_range(3.5, 9.0) + hh * 0.5, z)
			q.rotation.y = -PI / 2.0
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mill_burnt.add_child(q)
		for i in range(5):
			var x := 178.0 + i * 5.5 + r2.randf_range(-0.8, 0.8)
			var hh2 := r2.randf_range(3.0, 6.5)
			var q2 := MeshInstance3D.new()
			var qm2 := QuadMesh.new()
			qm2.size = Vector2(r2.randf_range(3.0, 5.0) * INV, hh2)
			q2.mesh = qm2
			q2.material_override = soot
			q2.position = Vector3(x, by + r2.randf_range(3.0, 8.0) + hh2 * 0.5, -112.1)
			q2.rotation.y = PI
			q2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mill_burnt.add_child(q2)
		# gruz pod ścianą i taśma na słupkach
		var rub := Props.pbr("rubble", 0.5, Color(0.5, 0.48, 0.46))
		for i in range(9):
			var rz := -106.0 + i * 5.0 + r2.randf_range(-1.5, 1.5)
			var rx := 174.0 + r2.randf_range(-2.0, 0.6)
			Models.box(mill_burnt, Vector3(r2.randf_range(0.5, 1.6) * INV, r2.randf_range(0.2, 0.55), r2.randf_range(0.5, 1.4) * INV), Vector3(rx, hd(rx, rz) + 0.15, rz), rub, Vector3(r2.randf_range(-0.3, 0.3), r2.randf() * TAU, r2.randf_range(-0.3, 0.3)))
		var tape := Models.mat("f2d21a", 0.6, 0.0, 0.3)
		for i in range(6):
			var z0 := -110.0 + i * 9.0
			Models.cyl(mill_burnt, 0.03 * INV, 0.03 * INV, 1.1, Vector3(171.0, hd(171.0, z0) + 0.55, z0), Models.mat("c8c8c8", 0.6, 0.3), Vector3.ZERO, 6)
			if i < 5:
				Models.box(mill_burnt, Vector3(0.012 * INV, 0.07, 9.0), Vector3(171.0, hd(171.0, z0 + 4.5) + 0.95, z0 + 4.5), tape, Vector3.ZERO, false)
	mill_burnt.visible = on


## czy prostokąt (współrzędne projektu) jest wolny: żadnych brył, budynków ani ścieżek
func _area_free(x: float, z: float, hx: float, hz: float, path_keep := 2.6) -> bool:
	for b in blocks:
		if x + hx > float(b.x0) * INV and x - hx < float(b.x1) * INV and z + hz > float(b.z0) * INV and z - hz < float(b.z1) * INV:
			return false
	for b in blds:
		if x + hx > float(b.x0) - 0.6 and x - hx < float(b.x1) + 0.6 and z + hz > float(b.z0) - 0.6 and z - hz < float(b.z1) + 0.6:
			return false
	for dx in [-hx, 0.0, hx]:
		for dz in [-hz, 0.0, hz]:
			if not wp.is_empty() and _path_dist(x + dx, z + dz) < path_keep:
				return false
			var px := clampi(int((x + dx - X0) * 2.0), 0, MAP_W - 1)
			var pz := clampi(int((z + dz - Z0) * 2.0), 0, MAP_H - 1)
			if img2.get_pixel(px, pz).r > 0.25:
				return false
	return absf(hd(x - hx, z) - hd(x + hx, z)) < 0.5 and absf(hd(x, z - hz) - hd(x, z + hz)) < 0.5


## Altanka śmietnikowa = kryjówka na czas pościgu. Gdy `search`, szuka wolnego miejsca w pobliżu
## (żeby nie stanęła na ścieżce, w budynku ani na torach); jak go nie ma, nie stawia nic.
func _hide_shed(x: float, z: float, ry: float, search := true) -> bool:
	var hx := 2.9 * INV if absf(sin(ry)) < 0.5 else 2.0 * INV
	var hz := 2.0 * INV if absf(sin(ry)) < 0.5 else 2.9 * INV
	if search:
		var found := false
		for rad in [0.0, 3.0, 6.0, 9.0, 12.0]:
			for k in range(8 if rad > 0.0 else 1):
				var nx: float = x + cos(k * PI / 4.0) * rad
				var nz: float = z + sin(k * PI / 4.0) * rad
				if _area_free(nx, nz, hx + 1.0, hz + 2.2):
					x = nx
					z = nz
					found = true
					break
			if found:
				break
		if not found:
			return false
	if absf(sin(ry)) < 0.5:
		_place(Props.trash_shed(), x, z, ry, 2.6, 1.7, 2.0)
	else:
		_place(Props.trash_shed(), x, z, ry, 1.7, 2.6, 2.0)
	# wejście od otwartej strony; w środku kucasz między kontenerami
	var f := Vector2(sin(ry), cos(ry))
	var front := Vector2(x, z) + f * 2.6 * INV
	var inside := Vector2(x, z) + f * 0.75 * INV
	var h := {"x": inside.x * SC, "z": inside.y * SC, "ox": front.x * SC, "oz": front.y * SC, "rot": ry + PI, "name": "altanka śmietnikowa"}
	hides.append(h)
	inter.append({"loc": "out", "x": front.x * SC, "z": front.y * SC, "ax": (x + f.x * 1.4 * INV) * SC, "az": (z + f.y * 1.4 * INV) * SC, "y0": 0.2, "y1": 1.7, "r": 1.5, "reach": 3.4, "id": "hide",
		"label": func(): return "[E] Schowaj się między kontenerami", "act": func(): G.main.hide_enter(h)})
	return true


## Skrytkomat: ściana żółtych schowków z ekranem. Punkt odbioru paczek „pod kod”.
func _locker_model() -> Node3D:
	var g := Node3D.new()
	var body_m := Models.mat("25282d", 0.5, 0.4)
	var door_m := Models.mat("e8b820", 0.45, 0.2)
	Models.box(g, Vector3(2.5, 2.05, 0.56), Vector3(0, 1.025, 0), body_m)
	Models.box(g, Vector3(2.7, 0.08, 0.95), Vector3(0, 2.12, 0.18), body_m)
	Models.box(g, Vector3(2.4, 0.03, 0.06), Vector3(0, 2.07, 0.58), Models.mat("fff4d6", 0.4, 0.0, 3.0), Vector3.ZERO, false)
	for col in range(6):
		if col == 3:
			continue
		for row in range(4):
			var dw := 0.38
			var dh := 0.44 if row > 0 else 0.5
			Models.box(g, Vector3(dw - 0.03, dh - 0.03, 0.02), Vector3(-1.05 + col * 0.42, 0.26 + row * 0.47 + (0.03 if row > 0 else 0.0), 0.285), door_m, Vector3.ZERO, false)
			Models.box(g, Vector3(0.05, 0.02, 0.015), Vector3(-1.05 + col * 0.42 + 0.12, 0.3 + row * 0.47, 0.3), Models.mat("1a1a1a", 0.6), Vector3.ZERO, false)
	# panel: ekran i klawiatura
	Models.box(g, Vector3(0.36, 1.9, 0.02), Vector3(0.21, 1.0, 0.285), Models.mat("1c1f24", 0.5, 0.3), Vector3.ZERO, false)
	Models.box(g, Vector3(0.28, 0.2, 0.01), Vector3(0.21, 1.42, 0.3), Models.mat("3a9aff", 0.3, 0.0, 2.2), Vector3.ZERO, false)
	for k in range(12):
		Models.box(g, Vector3(0.05, 0.04, 0.012), Vector3(0.13 + (k % 3) * 0.08, 1.2 - int(k / 3.0) * 0.06, 0.3), Models.mat("9aa0a6", 0.5, 0.4), Vector3.ZERO, false)
	var lb := Models.label("PARCEL LOCKER 24/7", Color(0.95, 0.8, 0.2), 30)
	lb.position = Vector3(0, 2.3, 0.2)
	lb.visibility_range_end = 26.0
	g.add_child(lb)
	var li := OmniLight3D.new()
	li.position = Vector3(0, 1.95, 0.9)
	li.light_color = Color(1.0, 0.95, 0.8)
	li.light_energy = 1.2
	li.omni_range = 6.5
	li.shadow_enabled = false
	li.set_meta("always", true)
	g.add_child(li)
	lamps.append(li)
	return g


## stawia skrytkomaty w pobliżu punktów zapisanych w D.DROPS (szuka wolnego miejsca) i poprawia ich współrzędne
func _lockers() -> void:
	for dd in D.DROPS:
		if not dd.get("locker", false):
			continue
		var x: float = float(dd.x) * INV
		var z: float = float(dd.z) * INV
		var ok := false
		for rad in [0.0, 3.0, 6.0, 9.0, 13.0, 17.0]:
			for k in range(8 if rad > 0.0 else 1):
				var nx: float = x + cos(k * PI / 4.0) * rad
				var nz: float = z + sin(k * PI / 4.0) * rad
				# na trawie, z dala od jezdni i ścieżek — żeby nie stanął na środku ulicy
				if _area_free(nx, nz, 2.6 * INV, 2.4 * INV, 1.6) and _soft_ground(nx, nz) and _soft_ground(nx - 2.0, nz + 2.0) and _soft_ground(nx + 2.0, nz + 2.0):
					x = nx
					z = nz
					ok = true
					break
			if ok:
				break
		if G.test_mode:
			print("SKRYTKOMAT %s -> (%.1f, %.1f) %s" % [String(dd.id), x, z, "ok" if ok else "BRAK MIEJSCA"])
		_place(_locker_model(), x, z, 0.0, 1.25, 0.3, 2.1)
		dd.x = x * SC
		dd.z = (z + 1.3 * INV) * SC


## dodatkowe altanki rozsiane po osiedlu — w każdej da się przeczekać pościg
func _hide_spots() -> void:
	for e in [[-84.0, 57.0, PI], [-128.0, -42.0, PI / 2.0], [104.0, 88.0, PI], [100.0, -58.0, 0.0], [-26.0, 96.0, -PI / 2.0], [36.0, 52.0, PI], [-150.0, 44.0, 0.0], [150.0, -8.0, -PI / 2.0], [-20.0, -52.0, 0.0], [-112.0, 98.0, 0.0]]:
		if not _hide_shed(e[0], e[1], e[2]):
			continue
		var hd0: Dictionary = hides[hides.size() - 1]
		var cx: float = (float(hd0.x) - sin(float(e[2])) * 0.75) * INV
		var cz: float = (float(hd0.z) - cos(float(e[2])) * 0.75) * INV
		_prop("trashbag", cx + 3.4 * INV * cos(float(e[2])), cz - 3.4 * INV * sin(float(e[2])), rng.randf() * TAU, 0.5, 0.0, false)


## wolny punkt (w metrach świata) w pobliżu podanego — do przeszukiwania okolicy przez patrol
func near_free(x: float, z: float) -> Vector2:
	if grid == null:
		return Vector2(x, z)
	var c := _free_cell(_cell(x, z))
	return Vector2(X0 * SC + (c.x + 0.5) * GCELL, Z0 * SC + (c.y + 0.5) * GCELL)


## Zaparkowane auta: parking pod blokami, wzdłuż krawężników Hutniczej i Robotniczej, pod garażami.
## Stare, różne, brudne — za autem można się schować na kucaka przed patrolem.
func _parked_cars() -> void:
	var types := ["sedan", "hatch", "maluch", "kombi", "sedan", "hatch", "maluch", "van", "kombi", "sedan"]
	var k := 0
	var spots := []
	# parking osiedlowy: auta w wymalowanych zatokach (prostopadle)
	for x in [24.8, 30.4, 41.6, 52.8, 64.0]:
		spots.append([x, -119.9, 0.0 if rng.randf() < 0.6 else PI])
	# Hutnicza: po polsku, dwoma kołami na chodniku — środek jezdni zostaje wolny dla radiowozu
	for x in [-124.0, -86.0, -70.0, -15.0, 22.0, 47.0, 98.0, 117.0]:
		if rng.randf() < 0.8:
			spots.append([x, 16.3, PI / 2.0])
	for x in [-112.0, -80.0, -45.0, -14.0, 36.0, 90.0, 110.0]:
		if rng.randf() < 0.8:
			spots.append([x, 23.7, -PI / 2.0])
	# Robotnicza: raz z jednej, raz z drugiej strony
	for z in [44.0, 66.0, 104.0, 140.0]:
		spots.append([1.9, z, 0.0])
	for z in [55.0, 92.0]:
		spots.append([-1.9, z, PI])
	for sp in spots:
		var x: float = sp[0] + rng.randf_range(-0.3, 0.3)
		var z: float = sp[1] + rng.randf_range(-0.1, 0.1)
		_car(x, z, float(sp[2]) + rng.randf_range(-0.05, 0.05), types[k % types.size()])
		k += 1
	# wrak na cegłach pod garażami i dostawczak pod bramą huty
	_car(74.0, 88.5, 1.2, "maluch", "7a6a3a")
	_car(181.0, 22.6, -PI / 2.0 + 0.1, "van", "5a6068")


## ławka osiedlowa (betonowe nogi, drewniane szczeble)
func _bench(x: float, z: float, ry := 0.0) -> void:
	var bcol := Color(0.2, 0.36, 0.26) if rng.randf() < 0.6 else Color(0.5, 0.28, 0.2)
	var b: Node3D = Stations.model("ul_lawka")
	if b != null:
		Interior._tint(b, bcol.lightened(0.25))
		Props.set_range(b, 110.0)
	else:
		b = Details.bench(bcol)
	b.position = Vector3(x, hd(x, z), z)
	b.rotation.y = ry
	b.scale = Vector3(INV, 1.0, INV)
	city.add_child(b)
	add_col(x - 0.9 * INV, x + 0.9 * INV, z - 0.35 * INV, z + 0.35 * INV, 0.9)
	rects.pop_back()


func _car(x: float, z: float, ry: float, type := "", color = null, police := false) -> void:
	var t: String = type if type != "" else ["sedan", "hatch", "maluch", "kombi"][rng.randi_range(0, 3)]
	var c = color if color != null else Models.CARCOLS[rng.randi_range(0, Models.CARCOLS.size() - 1)]
	var car: Node3D = Models.car(t, c, police)
	car.position = Vector3(x, hd(x, z), z)
	car.rotation.y = ry
	car.scale = Vector3(INV, 1.0, INV)
	city.add_child(car)
	var L: float = Models.CAR_TYPES[t].L * 0.5 * INV
	var W: float = Models.CAR_TYPES[t].W * 0.5 * INV
	var ex := absf(sin(ry)) * L + absf(cos(ry)) * W
	var ez := absf(cos(ry)) * L + absf(sin(ry)) * W
	add_col(x - ex, x + ex, z - ez, z + ez, 1.5)
	rects.pop_back()
	if car.has_meta("siren"):
		sirens.append(car.get_meta("siren"))


func _tree(x: float, z: float, s := 1.0, leaves := 0.5) -> void:
	# drzewo nie może wyrosnąć na jezdni, chodniku ani w budynku — szukamy najbliższego trawnika
	if not _soft_ground(x, z):
		var found := false
		for rad in [3.0, 6.0, 9.0]:
			for k in range(8):
				var nx: float = x + cos(k * PI / 4.0) * rad
				var nz: float = z + sin(k * PI / 4.0) * rad
				if _soft_ground(nx, nz):
					x = nx
					z = nz
					found = true
					break
			if found:
				break
		if not found:
			return
	var op := _off_path(x, z, 2.2)
	x = op.x
	z = op.y
	var t := Props.tree(rng.randi(), s * rng.randf_range(0.85, 1.2), leaves)
	t.position = Vector3(x, hd(x, z) - 0.15, z)
	t.scale *= Vector3(INV, 1.0, INV)
	city.add_child(t)
	tree_pos.append(Vector2(x, z))
	add_col(x - 0.3 * INV, x + 0.3 * INV, z - 0.3 * INV, z + 0.3 * INV, 3.0)
	rects.pop_back()


## odległość (w jednostkach planu) od najbliższej ścieżki przechodniów
func _path_dist(x: float, z: float) -> float:
	var p := Vector2(x, z) * SC
	var best := 1e9
	for n in wp:
		for j in n.links:
			if int(j) <= int(n.i):
				continue
			var a := Vector2(n.x, n.z)
			var b := Vector2(wp[j].x, wp[j].z)
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best * INV


## odsuwa punkt od ścieżki na co najmniej `keep` jednostek planu
func _off_path(x: float, z: float, keep: float) -> Vector2:
	if wp.is_empty() or _path_dist(x, z) >= keep:
		return Vector2(x, z)
	for rad in [keep, keep * 1.6, keep * 2.4]:
		for k in range(8):
			var nx: float = x + cos(k * PI / 4.0 + 0.4) * rad
			var nz: float = z + sin(k * PI / 4.0 + 0.4) * rad
			if _path_dist(nx, nz) >= keep:
				return Vector2(nx, nz)
	return Vector2(x, z)


## czy w tym miejscu jest trawa albo ziemia (nie asfalt, płyty, beton) i nie stoi tam budynek
func _soft_ground(x: float, z: float) -> bool:
	var px := clampi(int((x - X0) * 2.0), 0, MAP_W - 1)
	var pz := clampi(int((z - Z0) * 2.0), 0, MAP_H - 1)
	var a := img1.get_pixel(px, pz)
	if a.r + a.g + a.b + a.a > 0.25 or img2.get_pixel(px, pz).r > 0.25:
		return false
	for b in blds:
		if x > float(b.x0) - 1.5 and x < float(b.x1) + 1.5 and z > float(b.z0) - 1.5 and z < float(b.z1) + 1.5:
			return false
	return true


func _bush(x: float, z: float, s := 1.0) -> void:
	var op := _off_path(x, z, 3.2)
	x = op.x
	z = op.y
	var b := Props.bush(rng.randi(), s)
	b.position = Vector3(x, hd(x, z) - 0.05, z)
	b.scale *= Vector3(INV, 1.0, INV)
	city.add_child(b)
	# gęsty krzak: nie da się przez niego przejść, za to można się za nim schować
	var sz: Vector3 = b.get_meta("size", Vector3(1.4, 1.2, 1.4))
	if sz.x > 1.3:
		var r := sz.x * 0.3
		add_col(x - r * INV, x + r * INV, z - r * INV, z + r * INV, clampf(sz.y, 1.0, 2.0))
		rects.pop_back()
		covers.append(Vector3(x * SC, z * SC, sz.x * 0.5))


func _lamp(x: float, z: float, ry: float, broken := false) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, hd(x, z), z)
	g.rotation.y = ry
	g.scale = Vector3(INV, 1.0, INV)
	city.add_child(g)
	add_col(x - 0.16 * INV, x + 0.16 * INV, z - 0.16 * INV, z + 0.16 * INV, 3.0)
	rects.pop_back()
	var lm: Node3D = Stations.model("ul_latarnia")
	if lm != null:
		# słup z modelu; klosz dostaje wspólny materiał latarni, który rozpala się po zmroku
		g.add_child(lm)
		Props.set_range(lm, 150.0)
		var lens := Stations._find(lm, "Swiatlo") as MeshInstance3D
		if lens != null:
			lens.visible = not broken
			lens.material_override = lamp_mat
			lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if broken:
			return
	else:
		var pole := Props.pbr("concrete_wall_008", 0.6, Color(0.75, 0.75, 0.72))
		Models.cyl(g, 0.09, 0.15, 7.2, Vector3(0, 3.6, 0), pole, Vector3.ZERO, 8)
		Models.cyl(g, 0.035, 0.04, 1.6, Vector3(0, 7.2, 0.75), Models.mat("3a3d42", 0.5, 0.6), Vector3(PI / 2.0 - 0.15, 0, 0), 6)
		Models.box(g, Vector3(0.26, 0.1, 0.6), Vector3(0, 7.3, 1.6), Models.mat("2a2c30", 0.5, 0.5))
		if broken:
			return
		Models.box(g, Vector3(0.2, 0.03, 0.46), Vector3(0, 7.24, 1.6), lamp_mat, Vector3.ZERO, false)
	# reflektor w dół: plama światła na ziemi i widoczny snop we mgle
	var li := SpotLight3D.new()
	li.position = Vector3(0, 7.15, 1.6)
	li.rotation.x = -PI / 2.0
	li.light_color = Color(1.0, 0.72, 0.42)
	li.spot_range = 15.0
	li.spot_angle = 58.0
	li.spot_angle_attenuation = 0.9
	li.spot_attenuation = 0.85
	li.light_energy = 0.0
	li.light_volumetric_fog_energy = 2.2
	li.shadow_enabled = true
	li.visible = false
	li.distance_fade_enabled = true
	li.distance_fade_begin = 55.0
	li.distance_fade_length = 20.0
	li.distance_fade_shadow = 26.0
	g.add_child(li)
	lamps.append(li)
	if rng.randf() < 0.22:
		li.set_meta("flicker", rng.randf() * 10.0)


## drzwi budynku, do którego da się wejść (współrzędne świata)
func door(id: String) -> void:
	var dd: Dictionary = D.DOORS[id]
	if dd.get("custom", false):
		return
	var dz: float = dd.dz
	var x: float = dd.x
	var z: float = float(dd.z) - dz * 1.4 * SC
	var gy := height(x, dd.z)
	var c := Models.col(dd.color)
	var g := Node3D.new()
	g.position = Vector3(x, gy, z)
	add_child(g)
	if id == "garage":
		Models.box(g, Vector3(2.5, 2.25, 0.14), Vector3(0, 1.12, dz * 0.08), Props.pbr("painted_metal_shutter", 0.5, Color(0.75, 0.8, 0.85)))
		Models.box(g, Vector3(2.7, 0.14, 0.2), Vector3(0, 2.32, dz * 0.1), Models.mat("2a2c30", 0.6, 0.4))
	else:
		Models.box(g, Vector3(1.9, 2.5, 0.3), Vector3(0, 1.25, dz * 0.05), Models.mat("15161a", 0.6))
		Models.box(g, Vector3(1.1, 2.1, 0.1), Vector3(0, 1.08, dz * 0.2), Props.pbr("rusty_painted_metal", 0.6, Color(0.6, 0.62, 0.6)) if id != "shop" else Models.mat("2a3d33", 0.5, 0.2))
		Models.box(g, Vector3(0.3, 0.9, 0.04), Vector3(0.2, 1.4, dz * 0.26), Models.mat("0c1014", 0.1, 0.4))
		Models.box(g, Vector3(2.6, 0.14, 1.3), Vector3(0, 2.75, dz * 0.6), Props.pbr("concrete_wall_008", 0.4))
		Models.box(g, Vector3(2.4, 0.16, 1.0), Vector3(0, 0.08, dz * 0.5), Props.pbr("concrete_wall_008", 0.4))
		Models.box(g, Vector3(0.16, 0.3, 0.05), Vector3(0.85, 1.4, dz * 0.2), Models.mat("9aa3ab", 0.4, 0.6))
	if String(dd.title) != "":
		var lb := Signs.plate(String(dd.title), c)
		lb.position = Vector3(0, 3.2 if id != "garage" else 2.75, dz * 0.22)
		lb.rotation.y = 0.0 if dz > 0.0 else PI
		g.add_child(lb)
		var li := OmniLight3D.new()
		li.light_color = Color(1.0, 0.85, 0.6)
		li.light_energy = 0.7
		li.omni_range = 5.0
		li.position = Vector3(0, 2.5, dz * 1.0)
		g.add_child(li)
	if dd.get("sealed", false):
		# policyjne taśmy na krzyż — widoczne dopiero po prologu
		var tape := Node3D.new()
		tape.name = "Tape"
		g.add_child(tape)
		for a in [0.5, -0.5]:
			Models.box(tape, Vector3(1.9, 0.09, 0.012), Vector3(0, 1.15, dz * 0.27), Models.mat("f2d21a", 0.6, 0.0, 0.25), Vector3(0, 0, a), false)
		door_tape = tape
	inter.append({"loc": "out", "x": x, "z": dd.z, "y0": 0.0, "y1": 2.3, "r": 1.3 if id == "garage" else 0.7, "reach": 2.7, "id": "door_" + id,
		"label": func(): return G.door_label(id), "act": func(): G.main.enter(id)})


# ---------------------------------------------------------------- budynki
func _buildings() -> void:
	var P := "plyta"
	# osiedle: wielka płyta
	# Niska zabudowa, za to każdy blok inny: numer na szczycie, własny kolor i wzór malowania.
	building(-2.0, -90.0, 42.0, -78.0, 18.0, P, Color(0.78, 0.77, 0.72), Color(0.82, 0.56, 0.24), 0.0, true, {"no": "7", "door_at": 8.0, "pattern": 4})
	building(-82.0, -90.0, -38.0, -78.0, 15.0, "plyta2", Color(0.8, 0.8, 0.78), Color(0.4, 0.62, 0.45), 0.0, true, {"no": "5", "door_at": -60.0, "pattern": 1})
	building(-80.0, -158.0, -20.0, -146.0, 12.0, P, Color(0.8, 0.76, 0.74), Color(0.75, 0.48, 0.5), 0.05, true, {"no": "9", "pattern": 0, "door_at": -50.0})
	building(15.0, -158.0, 65.0, -146.0, 12.0, "plyta2", Color(0.76, 0.78, 0.8), Color(0.36, 0.56, 0.76), 0.0, true, {"no": "11", "pattern": 3, "door_at": 40.0})
	building(-137.0, -104.0, -119.0, -86.0, 24.0, P, Color(0.75, 0.75, 0.73), Color(0.78, 0.7, 0.34), 0.02, true, {"no": "13", "front": 3, "pattern": 2, "door_at": -95.0})
	building(-137.0, -161.0, -119.0, -143.0, 24.0, "plyta2", Color(0.78, 0.75, 0.72), Color(0.52, 0.5, 0.72), 0.02, true, {"no": "3", "front": 3, "pattern": 3, "door_at": -152.0})
	# kamienice przy Hutniczej (strona północna)
	building(-90.0, -10.0, -60.0, 10.0, 15.2, "kamA", Color(0.86, 0.8, 0.7), Color(0.8, 0.74, 0.62), 0.12)
	building(-56.0, -10.0, -30.0, 10.0, 19.0, "kamB", Color(0.82, 0.72, 0.5), Color(0.86, 0.82, 0.7), 0.06)
	building(-24.0, -10.0, 10.0, 10.0, 15.2, "kamC", Color(0.74, 0.8, 0.7), Color(0.85, 0.82, 0.72), 0.04)
	building(16.0, -10.0, 46.0, 10.0, 19.0, "kamD", Color(0.75, 0.78, 0.8), Color(0.78, 0.76, 0.72), 0.15)
	# strona południowa
	building(-90.0, 30.0, -50.0, 50.0, 15.2, "kamB", Color(0.8, 0.62, 0.55), Color(0.84, 0.78, 0.7), 0.1)
	building(-44.0, 30.0, -8.0, 50.0, 19.0, "kamA", Color(0.8, 0.8, 0.76), Color(0.72, 0.7, 0.64), 0.08)
	building(8.0, 30.0, 40.0, 50.0, 15.2, "kamC", Color(0.84, 0.78, 0.6), Color(0.84, 0.8, 0.72), 0.2)
	building(46.0, 30.0, 68.0, 46.0, 7.8, "cegla", Color(0.75, 0.72, 0.7), Color(0.5, 0.5, 0.5), 0.6)
	# Robotnicza
	building(-32.0, 58.0, -8.0, 80.0, 11.4, "cegla2", Color(0.7, 0.68, 0.66), Color(0.6, 0.58, 0.54), 0.55)
	building(8.0, 58.0, 34.0, 78.0, 11.4, "cegla2", Color(0.76, 0.72, 0.7), Color(0.62, 0.6, 0.56), 0.3)
	building(-44.0, 116.0, -8.0, 140.0, 10.0, "klub", Color(0.22, 0.2, 0.3), Color(1.0, 0.23, 0.82), 0.0)
	# komisariat
	building(-196.0, -10.0, -166.0, 8.0, 10.8, "urzad", Color(0.8, 0.82, 0.86), Color(0.25, 0.35, 0.6), 0.0)
	# Stara Huta
	building(176.0, -112.0, 206.0, -52.0, 15.6, "cegla", Color(0.74, 0.7, 0.68), Color(0.5, 0.5, 0.5), 0.75)
	building(178.0, -16.0, 196.0, -2.0, 5.2, "cegla", Color(0.7, 0.66, 0.64), Color(0.5, 0.5, 0.5), 0.9)
	# pawilon i garaże (niskie)
	_pavilion()
	_garages()
	# napisy, szyldy
	var gy := hd(8.0, -77.0)
	# komenda: podświetlany kaseton nad wejściem
	var ks := _place(Stations.model("kom_szyld"), -181.0, 8.0, 0.0)
	ks.position.y += 4.3
	_sign("3RD PRECINCT", Vector3(-181.0, 7.3, 8.12), Color(0.75, 0.8, 0.9), 60, 0.0, 0.006, 6)
	# szpital po drugiej stronie ulicy: daszek izby przyjęć i kaseton z krzyżem
	building(-200.0, 33.0, -162.0, 51.0, 11.4, "urzad", Color(0.88, 0.9, 0.88), Color(0.72, 0.22, 0.22), 0.0)
	_place(Stations.model("szp_wiata"), -181.0, 33.0, PI)
	var hs := _place(Stations.model("szp_szyld"), -172.0, 33.0, PI)
	hs.position.y += 5.6
	for e in [[-177.8, 30.3], [-184.2, 30.3]]:
		add_col(e[0] - 0.2, e[0] + 0.2, e[1] - 0.2, e[1] + 0.2, 3.0)
		rects.pop_back()
	var hl := OmniLight3D.new()
	hl.position = Vector3(-181.0, hd(-181.0, 31.0) + 2.7, 31.0)
	hl.light_color = Color(0.9, 0.95, 1.0)
	hl.light_energy = 1.4
	hl.omni_range = 8.0
	hl.distance_fade_enabled = true
	hl.distance_fade_begin = 45.0
	hl.distance_fade_length = 15.0
	city.add_child(hl)
	var ne := _sign("NEON", Vector3(-7.85, 8.0, 128.0), Color(1.0, 0.3, 0.85), 330, PI / 2.0, 0.01, 10)
	ne.shaded = false
	var ne2 := _sign("CLUB • DISCO • BAR", Vector3(-7.85, 5.6, 128.0), Color(0.3, 0.95, 1.0), 70, PI / 2.0, 0.008, 6)
	ne2.shaded = false
	# wejście do klubu: stalowy portal z neonowym łukiem, chodnik i słupki z liną
	if Stations.model("klub_drzwi") != null:
		_place(Stations.model("klub_drzwi"), -8.0, 128.0, PI / 2.0)
		for e in [[-6.9, 125.85], [-6.9, 130.15], [-3.2, 125.85], [-3.2, 130.15]]:
			add_col(e[0] - 0.25, e[0] + 0.25, e[1] - 0.25, e[1] + 0.25, 1.0)
			rects.pop_back()
	else:
		Models.box(city, Vector3(0.3, 2.6, 2.2), Vector3(-7.9, 1.3, 128.0), Models.mat("0c0c10", 0.4, 0.3))
		Models.box(city, Vector3(0.1, 0.25, 2.4), Vector3(-7.7, 2.85, 128.0), Models.mat("ff3bd0", 0.4, 0.0, 4.0))
	inter.append({"loc": "out", "x": -7.6 * SC, "z": 128.0 * SC, "y0": 0.0, "y1": 2.5, "r": 1.1, "reach": 3.0, "id": "door_club",
		"label": func(): return "Klub Neon — wejście (kontrola osobista)" if G.club_open() else "Klub Neon — otwarte od %d:00" % int(D.CLUB_OPEN),
		"act": func(): G.main.club_door()})
	var cl := OmniLight3D.new()
	cl.position = Vector3(-6.2, 3.2, 128.0)
	cl.light_color = Color(1.0, 0.25, 0.8)
	cl.light_energy = 1.8
	cl.omni_range = 9.0
	city.add_child(cl)
	# szyldy przy Hutniczej
	_shopfront(-75.0, 10.0, "PAWN SHOP", Color(0.95, 0.8, 0.2), "rusted_shutter", true)
	_shopfront(-43.0, 10.0, "KEBAB", Color(0.95, 0.35, 0.2), "painted_metal_shutter", true)
	_shopfront(31.0, 10.0, "LIQUOR 24H", Color(0.4, 0.9, 0.5), "rusted_shutter", false)
	_shopfront(-70.0, 30.0, "SCRAP YARD", Color(0.8, 0.8, 0.8), "rusted_shutter", true, -1.0)
	_shopfront(-26.0, 30.0, "ELA'S HAIR SALON", Color(0.9, 0.5, 0.7), "painted_metal_shutter", true, -1.0)
	_shopfront(24.0, 30.0, "FUNERAL HOME", Color(0.75, 0.75, 0.8), "rusted_shutter", true, -1.0)
	_sign("COAL DEPOT", Vector3(57.0, 6.2, 29.9), Color(0.8, 0.78, 0.7), 110, PI, 0.007, 8)
	_sign("HALL NO. 2", Vector3(175.9, hd(176.0, -80.0) + 11.0, -80.0), Color(0.7, 0.68, 0.62), 220, -PI / 2.0, 0.01, 8)
	_sign("FOR SALE\ncall 600 100 …", Vector3(190.0, hd(190.0, -51.0) + 4.6, -51.9), Color(0.95, 0.85, 0.2), 90, 0.0, 0.007, 10)


func _shopfront(x: float, zw: float, title: String, color: Color, shutter: String, closed: bool, dz := 1.0) -> void:
	var z := zw + dz * 0.06
	var gy := hd(x, zw + dz)
	Models.box(city, Vector3(5.2, 2.5, 0.12), Vector3(x, gy + 1.4, z), Props.pbr(shutter, 0.5, Color(0.8, 0.8, 0.8)) if closed else Models.mat("0c1216", 0.1, 0.4))
	_wall(Signs.shop(title, color, 2.9, not closed), x, 3.05, z + dz * 0.1, 0.0 if dz > 0.0 else PI)
	if not closed:
		var li := OmniLight3D.new()
		li.position = Vector3(x, gy + 2.4, z + dz * 1.6)
		li.light_color = color
		li.light_energy = 1.1
		li.omni_range = 6.0
		city.add_child(li)


func _pavilion() -> void:
	var by := _base(63.0, -57.0, 93.0, -47.0)
	Models.box(city, Vector3(30.0, 4.2, 10.0), Vector3(78.0, by + 2.1, -52.0), Props.pbr("concrete_slab_wall", 0.3, Color(0.8, 0.78, 0.74)))
	Models.box(city, Vector3(31.0, 0.3, 12.4), Vector3(78.0, by + 4.3, -51.2), Models.mat("1a1a1c", 0.95))
	add_col(63.0, 93.0, -57.0, -47.0, 4.2)
	blds.append({"x0": 63.0, "x1": 93.0, "z0": -57.0, "z1": -47.0, "low": true})
	var names := [["KEBAB U MIRKA", Color(0.95, 0.4, 0.2), false], ["WARZYWA", Color(0.4, 0.8, 0.4), true], ["TOTO-LOTEK", Color(0.95, 0.85, 0.2), true], ["SERWIS GSM", Color(0.4, 0.7, 0.95), true], ["PIWO • WINO", Color(0.9, 0.3, 0.3), false]]
	for i in range(5):
		var x := 66.5 + i * 5.8
		var e: Array = names[i]
		Models.box(city, Vector3(4.6, 2.5, 0.1), Vector3(x, by + 1.45, -46.94), Props.pbr("rusted_shutter" if i % 2 == 0 else "painted_metal_shutter", 0.5) if e[2] else Models.mat("0c1216", 0.1, 0.4))
		_wall(Signs.shop(e[0], e[1], 2.3, not e[2]), x, 3.3, -46.88, 0.0)
		if not e[2]:
			var li := OmniLight3D.new()
			li.position = Vector3(x, by + 2.6, -45.0)
			li.light_color = e[1]
			li.light_energy = 1.0
			li.omni_range = 6.0
			city.add_child(li)
	_sign("FOR SALE", Vector3(66.5, by + 2.2, -46.86), Color(0.95, 0.85, 0.2), 44, 0.0, 0.006, 8)


func _garages() -> void:
	var cols := ["8a8f94", "6a7a6a", "7a6a5a", "5a6a7a", "8a7a5a", "767676", "5f6f66", "8a6a5a", "6a6a7a", "7f8a8a"]
	for row in range(2):
		var z0 := 66.0 if row == 0 else 96.0
		# północny rząd ma przerwę na wjazd z ulicy (x 72–78) — wcześniej droga kończyła się na ścianie garażu
		var parts := [[44.0, 72.0], [78.0, 104.0]] if row == 0 else [[44.0, 104.0]]
		for pt in parts:
			var xa: float = pt[0]
			var xb: float = pt[1]
			var by0 := _base(xa, z0, xb, z0 + 6.0)
			Models.box(city, Vector3(xb - xa, 2.9, 6.0), Vector3((xa + xb) * 0.5, by0 + 1.2, z0 + 3.0), Props.pbr("rusty_corrugated_iron", 0.5, Color(0.72, 0.74, 0.72)))
			Models.box(city, Vector3(xb - xa + 0.6, 0.12, 6.6), Vector3((xa + xb) * 0.5, by0 + 2.72, z0 + 3.0), Props.pbr("asbestos_sheet", 0.5), Vector3(0.03 if row == 0 else -0.03, 0, 0))
			add_col(xa, xb, z0, z0 + 6.0, 3.0)
			blds.append({"x0": xa, "x1": xb, "z0": z0, "z1": z0 + 6.0, "low": true})
		var by := _base(44.0, z0, 104.0, z0 + 6.0)
		var fz := z0 + 6.06 if row == 0 else z0 - 0.06
		for i in range(10):
			var x := 47.0 + i * 6.0
			if row == 1 and i == 3:
				continue
			if row == 0 and (i == 4 or i == 5):
				continue
			var c := Models.col(cols[(i + row * 3) % 10])
			Models.box(city, Vector3(2.9, 2.2, 0.08), Vector3(x, by + 1.1, fz), Props.pbr("painted_metal_shutter" if (i + row) % 3 != 0 else "rusted_shutter", 0.5, c * 1.5))
			_sign(str(i + 1 + row * 11), Vector3(x + 1.0, by + 2.3, fz + (0.06 if row == 0 else -0.06)), Color(0.9, 0.9, 0.85), 40, 0.0 if row == 0 else PI, 0.006, 6)


func _stairs(sx: float) -> void:
	var m := Props.pbr("concrete_wall_008", 0.45, Color(0.8, 0.8, 0.78))
	var n := 30
	for k in range(n):
		var z := -18.0 - (k + 0.5) * 12.0 / n
		var y := PLATEAU * (k + 1.0) / n
		Models.box(city, Vector3(3.3, 0.4, 12.0 / n + 0.02), Vector3(sx, y - 0.2 + hd(sx, -17.0), z), m, Vector3.ZERO, k % 3 == 0)
	for side in [-1.0, 1.0]:
		Models.box(city, Vector3(0.3, 1.0, 12.9), Vector3(sx + side * 1.8, PLATEAU * 0.5 + 0.2 + hd(sx, -17.0), -24.0), m, Vector3(atan2(PLATEAU, 12.0), 0, 0))
		var rail := Models.mat("3a4a42", 0.5, 0.6)
		Models.cyl(city, 0.03, 0.03, 13.0, Vector3(sx + side * 1.8, PLATEAU * 0.5 + 1.25 + hd(sx, -17.0), -24.0), rail, Vector3(PI / 2.0 + atan2(PLATEAU, 12.0), 0, 0), 6)
		for k in range(5):
			var zz := -18.5 - k * 2.8
			Models.cyl(city, 0.025, 0.025, 1.0, Vector3(sx + side * 1.8, hd(sx, zz) + 0.95, zz), rail, Vector3.ZERO, 5)
		add_col(sx + side * 1.8 - 0.2, sx + side * 1.8 + 0.2, -30.0, -18.0, 1.4)
		rects.pop_back()


# ---------------------------------------------------------------- osiedle (góra)
func _estate() -> void:
	for sx in STAIRS:
		_stairs(sx)
	# mur oporowy przy rampie
	for r in RAMPS:
		for side in [-1.0, 1.0]:
			var x: float = r[0] + side * (6.9 if (float(r[0]) < 0.0 and side > 0.0) else 5.2)
			Models.box(city, Vector3(0.4, 1.2, 30.0), Vector3(x, hd(x + side * 2.5, -35.0) - 0.2, -36.0), Props.pbr("concrete_wall_008", 0.4, Color(0.75, 0.75, 0.72)), Vector3(-0.1, 0, 0))
			add_col(x - 0.3, x + 0.3, -51.0, -21.0, 6.5)
			rects.pop_back()
	# parking — mało aut, stare
	var cc := _prop("covered_car", 47.2, -119.9, PI, 0.0, 0.0)
	cc.scale = Vector3(1.0, 1.0, 1.0)
	# altanki śmietnikowe
	_hide_shed(53.0, -108.0, 0.0, false)
	_hide_shed(-70.0, -110.0, 0.0, false)
	for e in [[56.6, -106.5, 0.4], [50.4, -106.4, 1.9], [55.2, -111.6, 2.6], [-66.8, -108.2, 1.0], [-72.5, -107.8, 0.2]]:
		_prop("trashbag", e[0], e[1], e[2], 0.5, 0.0, false)
	_prop("old_tyre", 51.2, -111.8, 0.3, 0.16, 0.0, false)
	_prop("cardboard_box_01", 56.0, -110.6, 0.8, 0.34, 0.0, false)
	# plac zabaw i trzepak
	_place(Props.swing(), -9.0, -111.0, 0.3, 1.6, 0.9, 2.4)
	_place(Props.slide(), 1.0, -110.5, -0.5, 0.6, 1.8, 1.7)
	_place(Props.trzepak(), -33.0, -108.5, 0.1, 1.3, 0.1, 2.0)
	_bench(-14.5, -104.6, PI)
	_bench(4.0, -104.6, PI)
	_prop("dirty_football", -4.0, -108.2, 0.0, 0.22, 0.0, false)
	_prop("plastic_monobloc_chair_01", -31.0, -106.5, 2.2, 0.86, 0.0, false)
	# ławki pod klatkami, śmietniki, krzesła
	_bench(12.5, -76.2, 0.0)
	_bench(-55.5, -76.2, 0.0)
	_prop("metal_trash_can", 4.6, -76.8, 0.5, 0.9, 0.3)
	_prop("metal_trash_can", -64.2, -76.8, 1.5, 0.9, 0.3)
	_prop("can_rusted", 13.6, -75.4, 0.4, 0.13, 0.0, false)
	_prop("plastic_crate_01", -53.4, -75.6, 0.3, 0.28, 0.0, false)
	# trafostacja
	var tb := _base(108.0, -140.0, 113.0, -135.0)
	Models.box(city, Vector3(5.0, 3.4, 5.0), Vector3(110.5, tb + 1.7, -137.5), Props.pbr("concrete_slab_wall", 0.3))
	add_col(108.0, 113.0, -140.0, -135.0, 3.4)
	_sign("DANGER!\nHIGH VOLTAGE", Vector3(110.5, tb + 2.2, -134.95), Color(0.95, 0.85, 0.2), 30, 0.0, 0.006, 6)
	# plac przed pawilonem
	_prop("plastic_monobloc_chair_01", 65.0, -45.9, 0.4, 0.86, 0.0, false)
	_prop("plastic_monobloc_chair_01", 66.6, -46.1, -0.9, 0.86, 0.0, false)
	_prop("metal_trash_can", 86.5, -45.5, 0.0, 0.9, 0.3)
	_bench(78.0, -37.5, PI)
	# zieleń — rzadka, zaniedbana
	for e in [[-90.0, -72.0], [-20.0, -72.0], [50.0, -72.0], [70.0, -84.0], [-100.0, -112.0], [-50.0, -112.0], [14.0, -112.0], [78.0, -108.0], [-95.0, -142.0], [-8.0, -142.0], [80.0, -142.0],
			[-140.0, -122.0], [-150.0, -70.0], [-170.0, -100.0], [-185.0, -140.0], [-160.0, -150.0], [105.0, -90.0], [115.0, -110.0], [120.0, -45.0], [100.0, -40.0], [-15.0, -40.0], [-60.0, -42.0], [30.0, -38.0],
			[-140.0, -40.0], [-175.0, -50.0], [-190.0, -75.0]]:
		_tree(e[0], e[1], 1.0, 0.45)
	for e in [[-44.0, -72.0], [44.0, -73.0], [-12.0, -98.0], [66.0, -98.0], [-90.0, -98.0], [-70.0, -36.0], [0.0, -34.0], [40.0, -33.0], [84.0, -33.0], [-120.0, -34.0], [118.0, -70.0], [124.0, -62.0], [126.0, -72.0]]:
		_bush(e[0], e[1], rng.randf_range(0.8, 1.4))
	# ogrodzenie działek na zachodzie
	for k in range(6):
		_place(Props.fence(20.0, 1.5, "mesh"), -150.0, -160.0 + k * 20.0 + 10.0, PI / 2.0)


func _fake_entrance(x: float, zw: float, facing: float) -> void:
	var g := Node3D.new()
	var px := x if facing > 0.5 else x + 0.1
	g.position = Vector3(px, hd(px, zw + 1.0 if facing > 0.5 else zw), zw)
	if facing < 0.5:
		g.rotation.y = PI / 2.0
	g.scale = Vector3(INV, 1.0, INV)
	city.add_child(g)
	Models.box(g, Vector3(1.9, 2.5, 0.3), Vector3(0, 1.25, 0.05), Models.mat("15161a", 0.6))
	Models.box(g, Vector3(1.1, 2.1, 0.1), Vector3(0, 1.08, 0.2), Props.pbr("rusty_painted_metal", 0.6, Color(0.55, 0.6, 0.58)))
	Models.box(g, Vector3(2.6, 0.14, 1.5), Vector3(0, 2.75, 0.75), Props.pbr("concrete_wall_008", 0.4))
	Models.box(g, Vector3(2.4, 0.16, 1.3), Vector3(0, 0.08, 0.65), Props.pbr("concrete_wall_008", 0.4))


# ---------------------------------------------------------------- dolne miasto
func _lower_town() -> void:
	_place(Props.bus_stop(), 66.2, 9.4, 0.0, 2.0, 0.3, 2.4)
	rects.pop_back()
	_sign("HUTNICZA ST. 02", Vector3(62.0, 2.2, 8.75), Color(0.9, 0.9, 0.9), 34, 0.0, 0.006, 6)
	_place(Models.kiosk(), 52.5, -4.0, PI / 2.0, 1.1, 1.4, 2.4)
	_sign("KIOSK", Vector3(53.6, 2.7, -4.0), Color(0.95, 0.9, 0.5), 60, PI / 2.0, 0.006, 8)
	_prop("metal_trash_can", 66.0, 9.6, 0.0, 0.9, 0.3)
	_bench(56.0, -13.0, 0.0)
	# auta: prawie brak ruchu
	_car(-40.0, 17.2, PI / 2.0, "sedan", "28424f")
	_car(22.0, 22.8, -PI / 2.0, "hatch", "8a1c1c")
	_car(-156.0, 2.0, 0.0, "sedan", "ffffff", true)
	_car(-160.5, 2.5, 0.0, "suv", "ffffff", true)
	_car(-1.6, 96.0, 0.0, "sedan", "15171a")
	# wrak na cegłach przy garażach
	var wr: Node3D = Models.car("hatch", "5a6068")
	wr.position = Vector3(98.0, hd(98.0, 88.0) + 0.12, 88.0)
	wr.rotation = Vector3(0.0, 0.5, 0.05)
	wr.scale = Vector3(INV, 1.0, INV)
	city.add_child(wr)
	add_col(96.3, 99.7, 86.3, 89.7, 1.4)
	rects.pop_back()
	# zaułek za kamienicami
	for e in [[-88.0, -15.5, 0.2], [-70.0, -16.0, 1.2], [-50.0, -15.8, 2.0], [-12.0, -16.2, 0.6], [22.0, -15.6, 2.8], [40.0, -16.0, 1.6]]:
		_prop("trashbag", e[0], e[1], e[2], 0.5, 0.0, false)
	_prop("metal_trash_can", -62.0, -11.0, 0.4, 0.9, 0.3)
	_prop("metal_trash_can", 5.0, -11.0, 0.0, 0.9, 0.3)
	_prop("old_tyre", -86.0, -12.2, 0.0, 0.16, 0.0, false)
	_prop("cardboard_box_01", -82.0, -11.2, 0.5, 0.34, 0.0, false)
	_prop("cardboard_box_01", -83.0, -11.6, 1.1, 0.3, 0.0, false)
	_prop("plastic_crate_01", -8.0, -11.0, 0.2, 0.28, 0.0, false)
	_prop("wooden_crate_02", 20.0, -11.4, 0.3, 0.5, 0.5)
	_prop("exterior_aircon_unit", -6.0, -10.3, 0.0, 0.8, 0.0, false, 2.6)
	_prop("utility_box_01", 14.6, -10.5, 0.0, 1.1, 0.3)
	_prop("power_box_01", -57.0, -10.12, 0.0, 0.5, 0.0, false, 1.2)
	_prop("water_manhole_cover", -27.0, -14.0, 0.0, 0.0, 0.0, false, 0.01)
	_prop("water_manhole_cover", 30.0, 20.0, 0.0, 0.0, 0.0, false, 0.01)
	_prop("water_manhole_cover", -80.0, 20.5, 0.0, 0.0, 0.0, false, 0.01)
	# przed sklepem Stasia
	_prop("plastic_crate_01", -9.5, 10.5, 0.2, 0.28, 0.0, false)
	_prop("plastic_crate_01", -9.5, 10.5, 0.9, 0.28, 0.0, false, 0.28)
	_prop("metal_trash_can", -2.5, 10.7, 0.0, 0.9, 0.3)
	# podwórka południowe
	for e in [[-80.0, 53.0], [-30.0, 54.0], [20.0, 53.5], [58.0, 52.0]]:
		_prop("trashbag", e[0], e[1], rng.randf() * 6.0, 0.5, 0.0, false)
	_place(Props.trzepak(), -66.0, 54.0, 0.0, 1.3, 0.1, 2.0)
	_prop("plastic_monobloc_chair_01", 14.0, 54.0, 1.0, 0.86, 0.0, false)
	# garaże: życie i graty
	_prop("old_tyre", 107.0, 109.2, 0.0, 0.16, 0.0, false)
	_prop("old_tyre", 107.1, 109.25, 0.5, 0.16, 0.0, false, 0.17)
	_prop("old_tyre", 106.9, 109.1, 1.1, 0.16, 0.0, false, 0.34)
	_prop("old_tyre", 107.05, 109.2, 1.7, 0.16, 0.0, false, 0.51)
	# jedna oparta na sztorc o stos
	_prop("old_tyre^", 107.72, 109.2, PI / 2.0, 0.6, 0.0, true).rotation.z = 0.2
	_prop("barrel_01", 104.6, 108.0, 0.0, 0.9, 0.3)
	_prop("barrel_01", 45.2, 73.4, 0.0, 0.9, 0.3)
	_prop("plastic_monobloc_chair_01", 80.0, 74.2, 2.8, 0.86, 0.0, false)
	_prop("plastic_monobloc_chair_01", 81.4, 73.8, 3.6, 0.86, 0.0, false)
	_prop("wooden_crate_02", 80.8, 75.4, 0.2, 0.45, 0.4)
	_prop("rusted_wheel_rim_01", 96.0, 90.4, 0.0, 0.15, 0.0, false)
	_prop("propane_tank", 100.2, 74.0, 0.0, 0.55, 0.2)
	_prop("pallet", 52.0, 94.4, 0.2, 0.16, 0.0, false)
	_prop("pallet_broken", 88.0, 94.6, 1.2, 0.16, 0.0, false)
	_prop("cement_bag", 53.0, 73.6, 0.4, 0.18, 0.0, false)
	_place(Props.fence(64.0, 1.8, "sheet"), 75.0, 113.5, 0.0, 32.0, 0.15, 1.8)
	rects.pop_back()
	# nieużytki
	_prop("container_red", 70.0, 146.0, 0.3, 2.6, 0.0)
	add_col(66.8, 73.2, 144.4, 147.6, 2.6)
	_prop("wheels_stack", 84.0, 138.0, 0.0, 1.2, 0.5)
	_prop("pipes", 96.0, 150.0, 0.8, 1.0, 1.0)
	_prop("cinderblock", 60.0, 132.0, 0.2, 0.3, 0.0, false)
	_prop("trashbag_1", 62.0, 131.0, 0.0, 0.6, 0.0, false)
	for e in [[50.0, 140.0], [110.0, 135.0], [90.0, 160.0], [118.0, 155.0], [45.0, 160.0]]:
		_bush(e[0], e[1], rng.randf_range(0.9, 1.6))
	# drzewa przy ulicy (kilka ocalałych)
	for e in [[-112.0, 10.5], [-100.0, 29.5], [78.0, 9.0], [-8.5, 54.0], [9.0, 100.0], [-12.0, 112.0], [20.0, 96.0], [-14.0, 148.0], [12.0, 150.0], [128.0, 9.0], [128.0, 31.0]]:
		_tree(e[0], e[1], 1.0, 0.35)
	# skarpa: krzaki i śmieci
	for k in range(22):
		var x := -200.0 + k * 15.0 + rng.randf_range(-4.0, 4.0)
		if absf(x + 27.0) < 5.0 or absf(x - 60.0) < 5.0 or absf(x + 106.0) < 11.0 or x > 126.0:
			continue
		_bush(x, -24.0 + rng.randf_range(-3.0, 3.0), rng.randf_range(0.8, 1.5))
	# okolice komisariatu
	_place(Props.fence(14.0, 2.0, "mesh"), -157.0, -8.4, 0.0, 7.0, 0.1, 2.0)
	rects.pop_back()
	_prop("security_camera_01", -170.0, 8.2, 0.0, 0.3, 0.0, false, 4.0)


# ---------------------------------------------------------------- park
func _park() -> void:
	for e in [[-88.0, 64.0, 0.4], [-124.0, 101.0, 2.4], [-150.0, 62.5, 0.2], [-128.0, 148.0, 3.0], [-62.0, 102.0, 1.6]]:
		_bench(e[0], e[1], e[2])
	_prop("metal_trash_can", -90.5, 64.6, 0.0, 0.9, 0.3)
	_prop("metal_trash_can", -121.0, 101.5, 0.0, 0.9, 0.3)
	_prop("can_rusted", -123.0, 102.6, 0.0, 0.13, 0.0, false)
	_prop("wooden_picnic_table", -146.0, 96.0, 0.6, 0.75, 1.2)
	# stary dąb ze skrytką
	var oak := Props.tree(777, 1.9, 0.7)
	oak.position = Vector3(-161.5, hd(-161.5, 123.5) - 0.2, 123.5)
	city.add_child(oak)
	add_col(-162.2, -160.8, 122.8, 124.2, 3.0)
	rects.pop_back()
	for k in range(46):
		var a := rng.randf() * TAU
		var d := rng.randf_range(10.0, 62.0)
		var x := clampf(-122.0 + cos(a) * d * 1.3, -204.0, -52.0)
		var z := clampf(104.0 + sin(a) * d, 46.0, 166.0)
		if z > 114.0 and z < 142.0 and x > -90.0 and x < -50.0:
			continue
		_tree(x, z, 1.1, 0.6)
	for k in range(18):
		_bush(rng.randf_range(-200.0, -55.0), rng.randf_range(48.0, 165.0), rng.randf_range(0.8, 1.5))
	# boisko: bramki i resztki ogrodzenia
	var gm := Models.mat("b8b8b0", 0.6, 0.4)
	for gx in [-85.0, -55.0]:
		var gy := hd(gx, 128.0)
		for dz in [-2.0, 2.0]:
			Models.cyl(city, 0.05, 0.05, 2.0, Vector3(gx, gy + 1.0, 128.0 + dz), gm, Vector3.ZERO, 6)
		Models.cyl(city, 0.05, 0.05, 4.0, Vector3(gx, gy + 2.0, 128.0), gm, Vector3(PI / 2.0, 0, 0), 6)
	_place(Props.fence(32.0, 3.0, "mesh"), -70.0, 139.0, 0.0, 16.0, 0.1, 3.0)
	rects.pop_back()
	_place(Props.fence(10.0, 3.0, "mesh"), -86.8, 133.0, PI / 2.0)


# ---------------------------------------------------------------- nasyp i tunel
func _rail() -> void:
	var steel := Models.mat("4a4038", 0.5, 0.7)
	var wood := Models.mat("2f2620", 0.95)
	var z := -168.0
	while z < 168.0:
		for rx in [143.6, 146.4]:
			var y0 := maxf(hd(rx, z), 5.6 if (z > 4.0 and z < 36.0) else -99.0)
			var y1 := maxf(hd(rx, z + 8.0), 5.6 if (z + 8.0 > 4.0 and z + 8.0 < 36.0) else -99.0)
			var r := Models.box(city, Vector3(0.08, 0.14, 8.05), Vector3(rx, (y0 + y1) * 0.5 + 0.12, z + 4.0), steel, Vector3(-atan2(y1 - y0, 8.0), 0, 0), false)
			r.visibility_range_end = 140.0
		z += 8.0
	var xs: Array = []
	z = -168.0
	while z < 168.0:
		var y := maxf(hd(145.0, z), 5.6 if (z > 6.0 and z < 34.0) else -99.0)
		xs.append(Transform3D(Basis.IDENTITY, Vector3(145.0, y + 0.03, z)))
		z += 0.85
	_multimesh(xs, Vector3(4.0, 0.12, 0.26), wood, false)
	# tunel: przyczółki i płyta
	var cm := Props.pbr("concrete_wall_008", 0.3, Color(0.7, 0.7, 0.68))
	Models.box(city, Vector3(29.0, 8.0, 2.4), Vector3(145.0, 3.0, 11.0), cm)
	Models.box(city, Vector3(29.0, 8.0, 2.4), Vector3(145.0, 3.0, 29.0), cm)
	add_col(130.5, 159.5, 9.8, 12.2, 7.0, true, -1.0)
	add_col(130.5, 159.5, 27.8, 30.2, 7.0, true, -1.0)
	Models.box(city, Vector3(19.0, 1.2, 16.4), Vector3(145.0, 5.2, 20.0), cm)
	for sx in [135.8, 154.2]:
		Models.box(city, Vector3(0.3, 1.2, 16.4), Vector3(sx, 6.3, 20.0), Models.mat("3a4a42", 0.5, 0.6))
	var tl := OmniLight3D.new()
	tl.position = Vector3(145.0, 4.2, 20.0)
	tl.light_color = Color(1.0, 0.75, 0.45)
	tl.light_energy = 1.2
	tl.omni_range = 13.0
	tl.set_meta("flicker", 3.0)
	tl.set_meta("always", true)
	city.add_child(tl)
	lamps.append(tl)
	# słupy trakcyjne
	z = -160.0
	while z < 165.0:
		if z < 2.0 or z > 38.0:
			var gy := hd(149.6, z)
			Models.cyl(city, 0.09, 0.12, 7.5, Vector3(149.6, gy + 3.7, z), steel, Vector3.ZERO, 6)
			Models.box(city, Vector3(4.6, 0.1, 0.1), Vector3(147.5, gy + 7.0, z), steel)
		z += 40.0
	for e in [[127.0, -64.0], [129.0, -68.5], [126.0, -70.0], [128.0, 40.0], [163.0, -30.0], [161.0, 60.0], [129.0, 90.0], [128.5, -120.0]]:
		_bush(e[0], e[1], rng.randf_range(1.0, 1.7))


# ---------------------------------------------------------------- Stara Huta
func _industrial() -> void:
	var gy := hd(198.0, -124.0)
	Models.cyl(city, 1.6, 2.6, 46.0, Vector3(198.0, gy + 23.0, -124.0), Props.pbr("factory_brick", 0.3, Color(0.8, 0.75, 0.72)), Vector3.ZERO, 14)
	add_col(195.5, 200.5, -126.5, -121.5, 46.0)
	# brama i ogrodzenie
	_place(Props.fence(6.0, 2.2, "sheet"), 165.0, 29.6, 0.0, 3.0, 0.15, 2.2)
	rects.pop_back()
	_place(Props.fence(30.0, 2.2, "sheet"), 191.0, 29.6, 0.0, 15.0, 0.15, 2.2)
	rects.pop_back()
	_sign("OLD STEELWORKS\nPRIVATE PROPERTY", Vector3(180.0, 2.6, 29.4), Color(0.85, 0.8, 0.6), 46, PI, 0.006, 8)
	_prop("container_green", 182.0, 62.0, 0.2, 2.6, 0.0)
	add_col(178.9, 185.1, 60.5, 63.5, 2.6)
	_prop("container_red", 184.0, 70.0, 1.7, 2.6, 0.0)
	add_col(182.6, 185.4, 66.9, 73.1, 2.6)
	# zbiornik ze skrytką
	var ty := hd(196.0, 58.0)
	Models.cyl(city, 2.4, 2.4, 5.0, Vector3(196.0, ty + 2.5, 58.0), Props.pbr("rusty_painted_metal", 0.3), Vector3.ZERO, 16)
	add_col(193.8, 198.2, 55.8, 60.2, 5.0)
	Models.cyl(city, 1.6, 1.6, 7.0, Vector3(200.0, ty + 1.6, 66.0), Props.pbr("rusty_corrugated_iron", 0.3), Vector3(0, 0.3, PI / 2.0), 14)
	add_col(196.4, 203.6, 64.4, 67.6, 3.2)
	for e in [["barrel_01", 190.0, 55.0, 0.9], ["barrel_01", 190.8, 55.6, 0.9], ["pallet", 176.0, 48.0, 0.16], ["wheels_stack", 204.0, 84.0, 1.2], ["pipes", 170.0, 80.0, 1.0],
			["cinderblock", 174.0, 40.0, 0.3], ["trafficbarrier_1", 166.0, -2.0, 1.0], ["plasticbarrier", 168.0, 34.0, 0.9], ["old_tyre", 188.0, 40.0, 0.16], ["cement_bag", 189.0, 48.0, 0.18]]:
		_prop(e[0], e[1], e[2], rng.randf() * 6.0, e[3], 0.0, false)
	_prop("hand_truck", 177.0, -46.0, 0.5, 1.3, 0.0, false)
	for e in [[172.0, -30.0], [200.0, -30.0], [204.0, 10.0], [170.0, 110.0], [200.0, 120.0], [185.0, 150.0], [172.0, -130.0], [190.0, -150.0]]:
		_bush(e[0], e[1], rng.randf_range(1.0, 1.8))
	for e in [[202.0, 40.0], [168.0, 130.0], [204.0, 150.0], [172.0, -150.0]]:
		_tree(e[0], e[1], 1.1, 0.3)


# ---------------------------------------------------------------- zagęszczenie: zabudowa, mury, plakaty, ogień
func _garage_row_ns(x0: float, z0: float, z1: float, west: bool, first_no: int) -> void:
	var by := _base(x0, z0, x0 + 6.0, z1)
	Models.box(city, Vector3(6.0, 2.9, z1 - z0), Vector3(x0 + 3.0, by + 1.2, (z0 + z1) * 0.5), Props.pbr("rusty_corrugated_iron", 0.5, Color(0.7, 0.72, 0.7)))
	Models.box(city, Vector3(6.6, 0.12, z1 - z0 + 0.6), Vector3(x0 + 3.0, by + 2.72, (z0 + z1) * 0.5), Props.pbr("asbestos_sheet", 0.5), Vector3(0, 0, 0.03 if west else -0.03))
	add_col(x0, x0 + 6.0, z0, z1, 3.0)
	blds.append({"x0": x0, "x1": x0 + 6.0, "z0": z0, "z1": z1, "low": true})
	var fx := x0 - 0.06 if west else x0 + 6.06
	var n := int((z1 - z0) / 6.0)
	var cols := ["8a8f94", "6a7a6a", "7a6a5a", "5a6a7a", "8a7a5a", "767676"]
	for i in range(n):
		var z := z0 + 3.0 + i * 6.0
		Models.box(city, Vector3(0.08, 2.2, 4.2), Vector3(fx, by + 1.1, z), Props.pbr("painted_metal_shutter" if i % 3 != 0 else "rusted_shutter", 0.5, Models.col(cols[i % 6]) * 1.5))
		_sign(str(first_no + i), Vector3(fx + (-0.06 if west else 0.06), by + 2.3, z + 1.4), Color(0.9, 0.9, 0.85), 40, -PI / 2.0 if west else PI / 2.0, 0.006, 6)


func _garage_row_ew(x0: float, x1: float, z0: float, north: bool, first_no: int) -> void:
	var by := _base(x0, z0, x1, z0 + 6.0)
	Models.box(city, Vector3(x1 - x0, 2.9, 6.0), Vector3((x0 + x1) * 0.5, by + 1.2, z0 + 3.0), Props.pbr("rusty_corrugated_iron", 0.5, Color(0.72, 0.74, 0.72)))
	Models.box(city, Vector3(x1 - x0 + 0.6, 0.12, 6.6), Vector3((x0 + x1) * 0.5, by + 2.72, z0 + 3.0), Props.pbr("asbestos_sheet", 0.5), Vector3(-0.03 if north else 0.03, 0, 0))
	add_col(x0, x1, z0, z0 + 6.0, 3.0)
	blds.append({"x0": x0, "x1": x1, "z0": z0, "z1": z0 + 6.0, "low": true})
	var fz := z0 - 0.06 if north else z0 + 6.06
	var cols := ["8a8f94", "6a7a6a", "7a6a5a", "5a6a7a", "8a7a5a", "767676"]
	for i in range(int((x1 - x0) / 6.0)):
		var x := x0 + 3.0 + i * 6.0
		Models.box(city, Vector3(4.2, 2.2, 0.08), Vector3(x, by + 1.1, fz), Props.pbr("painted_metal_shutter" if i % 3 != 1 else "rusted_shutter", 0.5, Models.col(cols[(i + 2) % 6]) * 1.5))
		_sign(str(first_no + i), Vector3(x + 1.4, by + 2.3, fz + (-0.06 if north else 0.06)), Color(0.9, 0.9, 0.85), 40, PI if north else 0.0, 0.006, 6)


## mur lub płot z kolizją; kind: "mur" | "siatka" | "blacha"
## Ogrodzenie z dziurami: `holes` to współrzędne (x dla płotu wschód–zachód, z dla północ–południe),
## w których zostaje przejście szerokie na człowieka, z odgiętą siatką i wydeptaną ścieżką.
## `holes`: miejsca, w których da się przejść normalnie; `crawl`: przełazy tylko na kucaka
func _fence_run(ax: float, az: float, bx: float, bz: float, kind: String, h: float, holes: Array, crawl: Array = []) -> void:
	var ew := absf(bx - ax) > absf(bz - az)
	var lo := minf(ax, bx) if ew else minf(az, bz)
	var hi := maxf(ax, bx) if ew else maxf(az, bz)
	var cuts: Array = []
	for c in holes:
		cuts.append([float(c), false])
	for c in crawl:
		cuts.append([float(c), true])
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var from := lo
	for c in cuts:
		var cc: float = c[0]
		var gap := 1.0 if c[1] else 1.35
		if cc - gap <= from + 1.0 or cc + gap >= hi - 1.0:
			continue
		if ew:
			_barrier(from, az, cc - gap, az, kind, h)
		else:
			_barrier(ax, from, ax, cc - gap, kind, h)
		if c[1]:
			_crawl_hole(cc if ew else ax, az if ew else cc, ew, kind, h, gap)
		else:
			_fence_hole(cc if ew else ax, az if ew else cc, ew, kind, h, gap)
		from = cc + gap
	if ew:
		_barrier(from, az, hi, az, kind, h)
	else:
		_barrier(ax, from, ax, hi, kind, h)


## Przełaz: dół płotu jest podwinięty (albo mur ma wyrwę przy ziemi). Gracz przejdzie tylko na kucaka,
## policja wcale — dla niej to dalej pełny płot.
const CRAWL_H := 1.22

func _crawl_hole(x: float, z: float, ew: bool, kind: String, h: float, gap: float) -> void:
	var along := Vector2(1, 0) if ew else Vector2(0, 1)
	var across := Vector2(0, 1) if ew else Vector2(1, 0)
	var by := hd(x, z)
	var ry := 0.0 if ew else PI / 2.0
	var w := gap * 2.0
	var steel := Models.mat("4a4f4a", 0.6, 0.5)
	if kind == "mur":
		var cm := Props.pbr("dirty_concrete", 0.35, Color(0.7, 0.7, 0.68))
		Models.box(city, Vector3(w + 0.1, h - CRAWL_H, 0.3), Vector3(x, by + CRAWL_H + (h - CRAWL_H) * 0.5 - 0.2, z), cm, Vector3(0, ry, 0))
		Models.box(city, Vector3(w + 0.14, 0.1, 0.42), Vector3(x, by + h - 0.18, z), Models.mat("5a5a58", 0.9), Vector3(0, ry, 0), false)
		# poszarpana krawędź wyrwy i gruz po bokach
		for sd in [-1.0, 1.0]:
			var pp = Vector2(x, z) + along * sd * (gap - 0.08)
			Models.box(city, Vector3(0.34, 0.5, 0.3), Vector3(pp.x, by + CRAWL_H - 0.34, pp.y), cm, Vector3(0, ry, 0.5 * sd))
		for k in range(3):
			var rp := Vector2(x, z) + along * rng.randf_range(-gap, gap) * 1.6 + across * rng.randf_range(0.7, 1.8) * (1.0 if k % 2 == 0 else -1.0)
			_prop("cinderblock", rp.x, rp.y, rng.randf() * TAU, 0.2)
	else:
		for sd in [-1.0, 1.0]:
			var pp2 = Vector2(x, z) + along * sd * gap
			var pn := Node3D.new()
			pn.position = Vector3(pp2.x, by, pp2.y)
			city.add_child(pn)
			Props.fence_post(pn, 0.0, h)
		var up := Props.fence_panel(w, h - CRAWL_H, "mesh" if kind == "siatka" else "sheet")
		up.position = Vector3(x, by + CRAWL_H, z)
		up.rotation.y = ry
		city.add_child(up)
		# podwinięty dół: płat odgięty do góry po jednej stronie
		var fl := Props.fence_panel(w * 0.92, 0.75, "mesh" if kind == "siatka" else "sheet")
		fl.position = Vector3(x, by + CRAWL_H - 0.04, z)
		fl.rotation = Vector3(0.0, ry, 0.0)
		fl.rotate_object_local(Vector3(1, 0, 0), -1.2)
		city.add_child(fl)
	var pad := 0.25
	_col_opaque = kind != "siatka"
	if ew:
		add_col(x - gap, x + gap, z - pad, z + pad, h - CRAWL_H, true, by + CRAWL_H, h)
	else:
		add_col(x - pad, x + pad, z - gap, z + gap, h - CRAWL_H, true, by + CRAWL_H, h)
	_col_opaque = true
	rects.pop_back()
	# bez interakcji: kto kucnie [C], ten przejdzie. Gra podpowiada to raz, przy pierwszym przełazie (main._slow)
	crawls.append({"x": x * SC, "z": z * SC})
	# wydeptana ścieżka
	_pl(3, Vector2(x, z) - across * 3.5, Vector2(x, z) + across * 3.5, 1.1)


func _fence_hole(x: float, z: float, ew: bool, kind: String, h: float, gap: float) -> void:
	var along := Vector2(1, 0) if ew else Vector2(0, 1)
	var across := Vector2(0, 1) if ew else Vector2(1, 0)
	var by := hd(x, z)
	var steel := Models.mat("4a4f4a", 0.6, 0.5)
	if kind == "mur":
		# wyrwa w murze: poszarpane krawędzie i gruz
		var cm := Props.pbr("dirty_concrete", 0.35, Color(0.7, 0.7, 0.68))
		for sd in [-1.0, 1.0]:
			var pp = Vector2(x, z) + along * sd * (gap + 0.25)
			Models.box(city, Vector3(0.5, h * 0.55, 0.3) if ew else Vector3(0.3, h * 0.55, 0.5), Vector3(pp.x, by + h * 0.27 - 0.2, pp.y), cm, Vector3(0, 0, 0.08 * sd))
		for k in range(4):
			var rp := Vector2(x, z) + along * rng.randf_range(-gap, gap) + across * rng.randf_range(-1.6, 1.6)
			_prop("cinderblock", rp.x, rp.y, rng.randf() * TAU, 0.2)
	else:
		# słupki po obu stronach i odgięty płat siatki / blachy
		for sd in [-1.0, 1.0]:
			var pp2 = Vector2(x, z) + along * sd * gap
			Models.cyl(city, 0.03, 0.03, h, Vector3(pp2.x, by + h * 0.5, pp2.y), steel, Vector3(0, 0, 0.06 * sd), 5)
		var flap_mat: Material
		if kind == "siatka":
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(0.45, 0.48, 0.45, 0.42)
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.cull_mode = BaseMaterial3D.CULL_DISABLED
			fm.roughness = 0.6
			fm.metallic = 0.4
			flap_mat = fm
		else:
			flap_mat = Props.pbr("rusty_corrugated_iron", 0.5)
		var fp := Vector2(x, z) + along * (gap - 0.1) + across * 0.55
		var flap := Models.box(city, Vector3(1.6, h * 0.8, 0.02), Vector3(fp.x, by + h * 0.42, fp.y), flap_mat,
			Vector3(0.18, (0.0 if ew else PI / 2.0) + 1.05, 0.0), false)
		flap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# wydeptana ścieżka przez dziurę
	var a := Vector2(x, z) - across * 4.5
	var b := Vector2(x, z) + across * 4.5
	_pl(3, a, b, 1.5)


func _barrier(ax: float, az: float, bx: float, bz: float, kind := "mur", h := 2.0) -> void:
	var a := Vector2(ax, az)
	var b := Vector2(bx, bz)
	var ln := a.distance_to(b)
	var mid := (a + b) * 0.5
	var ry := atan2(-(bz - az), bx - ax)
	if kind == "mur":
		var m := Props.pbr("concrete_wall_008" if rng.randf() < 0.6 else "dirty_concrete", 0.35, Color(0.72, 0.72, 0.7))
		var segs: int = max(1, int(ln / 6.0))
		for i in range(segs):
			var t := (i + 0.5) / segs
			var p := a.lerp(b, t)
			Models.box(city, Vector3(ln / segs - 0.06, h, 0.3), Vector3(p.x, hd(p.x, p.y) + h * 0.5 - 0.2, p.y), m, Vector3(0, ry, 0))
			Models.box(city, Vector3(ln / segs + 0.04, 0.1, 0.42), Vector3(p.x, hd(p.x, p.y) + h - 0.18, p.y), Models.mat("5a5a58", 0.9), Vector3(0, ry, 0), false)
	else:
		var segs2: int = max(1, int(ln / 12.0))
		for i in range(segs2):
			var t2 := (i + 0.5) / segs2
			var p2 := a.lerp(b, t2)
			var f := Props.fence(ln / segs2, h, "mesh" if kind == "siatka" else "sheet")
			f.position = Vector3(p2.x, hd(p2.x, p2.y), p2.y)
			f.rotation.y = ry
			city.add_child(f)
	var pad := 0.25
	_col_opaque = kind != "siatka"
	if absf(bx - ax) > absf(bz - az):
		add_col(minf(ax, bx), maxf(ax, bx), mid.y - pad, mid.y + pad, h, true)
	else:
		add_col(mid.x - pad, mid.x + pad, minf(az, bz), maxf(az, bz), h, true)
	_col_opaque = true
	if h < 3.0:
		rects.pop_back()


func _fire(x: float, z: float) -> void:
	var f := Props.fire_barrel(lamps)
	f.position = Vector3(x, hd(x, z), z)
	f.scale = Vector3(INV, 1.0, INV)
	city.add_child(f)
	add_col(x - 0.35 * INV, x + 0.35 * INV, z - 0.35 * INV, z + 0.35 * INV, 1.0)
	rects.pop_back()


func _dense() -> void:
	var GC := [Color(0.9, 0.9, 0.9), Color(0.85, 0.2, 0.2), Color(0.25, 0.5, 0.9), Color(0.95, 0.8, 0.2), Color(0.3, 0.8, 0.4), Color(0.9, 0.4, 0.75)]
	# --- zabudowa uzupełniająca
	building(-146.0, -10.0, -116.0, 10.0, 15.2, "kamB", Color(0.78, 0.74, 0.6), Color(0.84, 0.8, 0.7), 0.2)
	building(-146.0, 30.0, -104.0, 50.0, 11.4, "cegla2", Color(0.74, 0.7, 0.68), Color(0.6, 0.58, 0.54), 0.4)
	building(84.0, -10.0, 124.0, 10.0, 11.4, "cegla2", Color(0.78, 0.72, 0.68), Color(0.62, 0.6, 0.56), 0.25)
	building(84.0, 32.0, 124.0, 52.0, 7.8, "cegla", Color(0.72, 0.7, 0.68), Color(0.5, 0.5, 0.5), 0.5)
	building(15.0, 104.0, 38.0, 128.0, 11.4, "cegla2", Color(0.7, 0.66, 0.64), Color(0.6, 0.58, 0.54), 0.75)
	building(-32.0, 86.0, -9.0, 96.0, 4.4, "kamC", Color(0.8, 0.7, 0.55), Color(0.84, 0.8, 0.72), 0.0)
	building(62.0, -100.0, 86.0, -86.0, 7.6, "cegla", Color(0.76, 0.7, 0.66), Color(0.5, 0.5, 0.5), 0.3)
	var chy := hd(84.0, -106.0)
	Models.cyl(city, 0.9, 1.4, 24.0, Vector3(84.0, chy + 12.0, -106.0), Props.pbr("factory_brick", 0.3, Color(0.8, 0.74, 0.7)), Vector3.ZERO, 12)
	add_col(82.4, 85.6, -107.6, -104.4, 24.0)
	_shopfront(104.0, 10.0, "BAKERY", Color(0.95, 0.75, 0.35), "rusted_shutter", true)
	_shopfront(104.0, 32.0, "BUILDING SUPPLIES", Color(0.85, 0.85, 0.8), "painted_metal_shutter", true, -1.0)
	_shopfront(-131.0, 10.0, "SECOND HAND", Color(0.9, 0.5, 0.6), "painted_metal_shutter", true)
	_wall(Signs.shop("BAR JAGODA", Color(0.95, 0.4, 0.5), 3.0, true), -8.86, 3.2, 91.0, PI / 2.0)
	Models.box(city, Vector3(0.14, 2.3, 1.6), Vector3(-8.95, hd(-8.0, 91.0) + 1.15, 91.0), Models.mat("1a120e", 0.6))
	var bl := OmniLight3D.new()
	bl.position = Vector3(-7.4, hd(-7.4, 91.0) + 2.6, 91.0)
	bl.light_color = Color(1.0, 0.45, 0.5)
	bl.light_energy = 1.1
	bl.omni_range = 6.0
	city.add_child(bl)
	_garage_row_ew(-96.0, -44.0, -50.0, true, 31)
	_garage_row_ns(112.0, -124.0, -70.0, true, 41)
	# --- działkowe altanki na zachodzie
	var hc := ["5a7a5a", "7a5a4a", "5a6a8a", "8a7a4a", "6a4a5a", "4a6a6a", "7a7a6a"]
	for k in range(7):
		var x := rng.randf_range(-200.0, -160.0)
		var z := -160.0 + k * 19.0 + rng.randf_range(-3.0, 3.0)
		var by := hd(x, z)
		Models.box(city, Vector3(4.6, 2.3, 3.6), Vector3(x, by + 1.1, z), Models.mat(hc[k], 0.9), Vector3(0, rng.randf_range(-0.2, 0.2), 0))
		var roof := PrismMesh.new()
		roof.size = Vector3(5.2, 1.1, 4.2)
		var rm := MeshInstance3D.new()
		rm.mesh = roof
		rm.material_override = Props.pbr("asbestos_sheet", 0.4, Color(0.6, 0.55, 0.52))
		rm.position = Vector3(x, by + 2.8, z)
		city.add_child(rm)
		add_col(x - 2.4, x + 2.4, z - 1.9, z + 1.9, 2.4)
		rects.pop_back()
	# --- mury i płoty: ciasne podwórka, mniej otwartej przestrzeni
	# Płoty mają dziury: GPS prowadzi oficjalnymi przejściami (schody, tunel, bramy),
	# ale kto zna teren, przejdzie na skróty przez wyrwę w siatce.
	_fence_run(-98.0, -31.6, -34.0, -31.6, "siatka", 1.8, [-66.0])
	_fence_run(-20.0, -31.6, 9.0, -31.6, "siatka", 1.8, [], [-6.0])
	_fence_run(15.0, -31.6, 54.0, -31.6, "siatka", 1.8, [37.0], [22.0])
	_fence_run(66.0, -31.6, 104.0, -31.6, "siatka", 1.8, [88.0], [74.0])
	_fence_run(-90.0, 57.6, -50.0, 57.6, "mur", 2.2, [], [-70.0])
	_barrier(-44.0, 57.6, -9.0, 57.6, "mur", 2.2)
	_fence_run(8.0, 57.6, 40.0, 57.6, "mur", 2.2, [], [24.0])
	_barrier(46.0, 52.0, 68.0, 52.0, "blacha", 2.0)
	_barrier(-48.5, 60.0, -48.5, 96.0, "siatka", 1.8)
	_fence_run(-48.5, 104.0, -48.5, 160.0, "siatka", 1.8, [123.0], [142.0])
	_barrier(-92.0, -17.6, -62.0, -17.6, "mur", 2.0)
	_fence_run(-54.0, -17.6, -31.0, -17.6, "mur", 2.0, [], [-42.0])
	_barrier(-23.0, -17.6, 8.0, -17.6, "mur", 2.0)
	_fence_run(16.0, -17.6, 46.0, -17.6, "mur", 2.0, [31.0])
	_barrier(40.0, 100.0, 40.0, 130.0, "blacha", 2.0)
	_fence_run(128.6, 32.0, 128.6, 120.0, "siatka", 1.8, [78.0], [50.0, 104.0])
	_fence_run(128.6, -160.0, 128.6, -72.0, "siatka", 1.8, [-112.0], [-90.0])
	_fence_run(128.6, -60.0, 128.6, -20.0, "siatka", 1.8, [-40.0])
	# nowe ogrodzenia w miejscach, gdzie dało się biegać na przełaj
	_fence_run(44.0, 127.0, 104.0, 127.0, "blacha", 2.0, [71.0], [92.0])  # garaże / wysypisko
	_fence_run(-146.0, 57.6, -113.0, 57.6, "siatka", 1.8, [-130.0])       # tyły kamienicy od strony parku
	_fence_run(104.0, -60.0, 104.0, -34.0, "siatka", 1.8, [])             # skarpa przy nasypie
	ctl1_tex.update(img1)
	_barrier(-112.0, 52.0, -112.0, 60.0, "mur", 2.2)
	_barrier(10.0, 80.0, 34.0, 80.0, "mur", 2.2)
	# --- graffiti na murach i płotach (na budynkach rozkłada je Details.wall_art)
	Details.decal(self, "piece_04", Vector3(145.0 * SC, hd(145.0, 12.26) + 2.6, 12.26 * SC), 0.0, 4.4)
	Details.decal(self, "piece_05", Vector3(145.0 * SC, hd(145.0, 27.74) + 2.5, 27.74 * SC), PI, 4.2)
	Details.decal(self, "piece_07", Vector3(78.0 * SC, hd(78.0, -57.08) + 1.7, -57.08 * SC), PI, 3.0)
	var tags := ["DBS", "SKERO", "MZK", "HWK", "ZGR", "KSH", "1986", "ACAB?", "STAL", "BLOKI", "JARA", "ELO", "NIE UFAJ", "TU RZĄDZĄ BLOKI", "LOVE", "KUBA TU BYŁ", "PUNK", "HIP-HOP", "WOLNOŚĆ", "ZOSTAŃ"]
	var walls := [[-70.0, 57.45, PI], [-30.0, 57.45, PI], [20.0, 57.45, PI], [-80.0, -17.45, 0.0], [-45.0, -17.45, 0.0], [-10.0, -17.45, 0.0], [30.0, -17.45, 0.0],
		[-75.0, -17.75, PI], [-40.0, -17.75, PI], [0.0, -17.75, PI], [28.0, -17.75, PI], [-70.0, -50.12, PI], [-56.0, -43.88, 0.0], [-80.0, -43.88, 0.0],
		[52.0, 72.1, 0.0], [70.0, 72.1, 0.0], [92.0, 72.1, 0.0], [58.0, 95.9, PI], [82.0, 95.9, PI], [100.0, 95.9, PI], [20.0, 79.85, PI], [26.0, 80.15, 0.0]]
	for w in walls:
		_graffiti(tags[rng.randi_range(0, tags.size() - 1)], w[0] + rng.randf_range(-3.0, 3.0), w[1], rng.randf_range(0.9, 1.5), w[2], GC[rng.randi_range(0, 5)], rng.randi_range(70, 130))
	# --- słupy ogłoszeniowe w ruchliwych miejscach
	for e in [[52.0, 6.4], [68.0, -39.0], [-22.0, -98.6], [10.5, 118.5]]:
		Details.ad_pillar(self, e[0], e[1], int(e[0] * 13.0 + e[1]))
	_parked_cars()
	# --- ogień i życie
	_fire(86.0, 80.0)
	_fire(64.0, 136.0)
	_fire(-41.0, -14.2)
	_fire(133.5, 26.6)
	_fire(186.0, 44.0)
	# --- graty
	for e in [["sofa_01", 50.0, -106.0, 0.3, 0.8], ["television_01", 43.6, -108.6, 1.0, 0.46], ["sofa_01", 88.5, 78.6, 2.6, 0.8], ["plastic_monobloc_chair_01", 84.2, 81.6, 0.6, 0.86],
			["wooden_crate_02", 87.6, 81.8, 0.2, 0.45], ["armchair_01", 62.0, 138.4, 4.0, 1.0], ["plastic_monobloc_chair_01", 65.8, 137.8, 2.3, 0.86], ["old_tyre", 61.5, 134.2, 0.0, 0.16],
			["plastic_crate_01", -43.0, -15.2, 0.4, 0.28], ["wooden_crate_02", -38.8, -15.6, 1.1, 0.45], ["barrel_01", -47.0, -16.2, 0.0, 0.9], ["cardboard_box_01", -36.0, -16.4, 0.7, 0.34],
			["trashbag", -99.0, -52.0, 0.5, 0.5], ["old_tyre", -60.0, -51.5, 0.0, 0.16], ["pallet", -72.0, -52.6, 0.4, 0.16], ["barrel_01", -47.6, -52.4, 0.0, 0.9],
			["cement_bag", 110.0, -96.0, 0.3, 0.18], ["old_tyre", 110.6, -118.0, 0.0, 0.16], ["plastic_monobloc_chair_01", 110.2, -84.0, 1.2, 0.86], ["trashbag", 110.4, -72.0, 0.2, 0.5],
			["trashbag", 131.0, 14.0, 0.4, 0.5], ["cardboard_box_01", 131.4, 25.8, 0.9, 0.34], ["trashbag", 157.0, 26.0, 2.0, 0.5], ["can_rusted", 134.2, 25.6, 0.0, 0.13],
			["metal_trash_can", -9.5, 97.4, 0.0, 0.9], ["plastic_monobloc_chair_01", -6.8, 88.2, 1.6, 0.86], ["plastic_crate_01", -6.9, 94.6, 0.3, 0.28], ["trashbag", 16.0, 102.6, 1.0, 0.5],
			["metal_trash_can", 82.0, 11.2, 0.3, 0.9], ["trashbag", 125.0, 11.0, 1.3, 0.5], ["wooden_crate_02", 126.0, 31.0, 0.5, 0.45], ["hand_truck", 86.4, 30.6, 0.4, 1.3]]:
		_prop(e[0], e[1], e[2], e[3], e[4], 0.3 if float(e[4]) > 0.6 else 0.0, false)
	# --- dodatkowe drzewa przy ulicach i na podwórkach
	for e in [[-80.0, 12.6], [-40.0, 27.4], [20.0, 12.6], [50.0, 27.6], [-110.0, -40.0], [-70.0, -38.0], [-45.0, -60.0], [-10.0, -60.0], [30.0, -60.0], [50.0, -60.0], [-90.0, -95.0], [-36.0, -94.0], [46.0, -96.0],
			[100.0, -60.0], [104.0, -30.0], [-20.0, -120.0], [10.0, -118.0], [-60.0, -138.5], [10.0, -138.5], [70.0, -138.5], [-104.0, 70.0], [-56.0, 70.0], [60.0, 56.0], [100.0, 60.0], [36.0, 90.0], [-20.0, 112.0],
			[8.5, 140.0], [-8.5, 70.0], [124.0, 60.0], [124.0, 100.0], [170.0, 100.0], [180.0, -40.0], [-160.0, 20.0], [-150.0, 40.0], [-170.0, -30.0]]:
		_tree(e[0], e[1], rng.randf_range(0.8, 1.1), 0.45)
	# --- chwasty przy murach i w szczelinach
	for b in blds:
		var per := int(((b.x1 - b.x0) + (b.z1 - b.z0)) / 9.0)
		for i in range(per):
			var side := rng.randi_range(0, 3)
			var t3 := rng.randf()
			var wx: float = lerpf(b.x0, b.x1, t3) if side < 2 else (b.x0 - 0.5 if side == 2 else b.x1 + 0.5)
			var wz: float = (b.z0 - 0.5 if side == 0 else b.z1 + 0.5) if side < 2 else lerpf(b.z0, b.z1, t3)
			var wd := Props.weeds(rng.randi(), rng.randf_range(0.7, 1.2))
			wd.position = Vector3(wx, hd(wx, wz) - 0.03, wz)
			wd.scale *= Vector3(INV, 1.0, INV)
			city.add_child(wd)
	for k in range(90):
		var wx2 := rng.randf_range(-200.0, 200.0)
		var wz2 := rng.randf_range(-160.0, 160.0)
		if img1.get_pixel(clampi(int((wx2 - X0) * 2.0), 0, MAP_W - 1), clampi(int((wz2 - Z0) * 2.0), 0, MAP_H - 1)).r > 0.5:
			continue
		var wd2 := Props.weeds(rng.randi(), rng.randf_range(0.8, 1.4))
		wd2.position = Vector3(wx2, hd(wx2, wz2) - 0.03, wz2)
		wd2.scale *= Vector3(INV, 1.0, INV)
		city.add_child(wd2)


# ---------------------------------------------------------------- krawężniki, ściółka, kępy trawy
func _curb(ax: float, az: float, bx: float, bz: float) -> void:
	var a := Vector2(ax, az)
	var b := Vector2(bx, bz)
	var ln := a.distance_to(b)
	var n: int = max(1, int(ln / (2.0 * INV)))
	var ry := atan2(-(bz - az), bx - ax)
	for i in range(n):
		var p := a.lerp(b, (i + 0.5) / n)
		var bs := Basis(Vector3.UP, ry + rng.randf_range(-0.015, 0.015))
		_curbs.append(Transform3D(bs, Vector3(p.x, hd(p.x, p.y) + rng.randf_range(-0.05, -0.02), p.y)))


func _curb_lines() -> void:
	# Hutnicza
	for seg in [[-208.0, -109.5], [-102.5, 131.0], [159.0, 162.5], [169.5, 208.0]]:
		_curb(seg[0], 15.4, seg[1], 15.4)
	for seg in [[-208.0, -3.5], [3.5, 72.0], [78.0, 131.0], [159.0, 208.0]]:
		_curb(seg[0], 24.6, seg[1], 24.6)
	# Robotnicza, rampa, drogi osiedlowe
	_curb(-3.6, 24.6, -3.6, 150.0)
	_curb(3.6, 24.6, 3.6, 150.0)
	_curb(-109.6, -133.5, -109.6, 15.4)
	_curb(-102.4, -126.5, -102.4, 15.4)
	_curb(-109.6, -133.6, 98.6, -133.6)
	_curb(-102.4, -126.4, 20.0, -126.4)
	_curb(72.0, -126.4, 91.4, -126.4)
	_curb(91.4, -126.4, 91.4, -60.0)
	_curb(98.6, -133.6, 98.6, -60.0)
	_curb(71.9, 24.6, 71.9, 72.0)
	_curb(78.1, 24.6, 78.1, 72.0)
	_curb(162.4, -100.0, 162.4, 15.4)
	_curb(169.6, -100.0, 169.6, 15.4)


## ściółka z liści pod drzewami (warstwa w mapie nawierzchni) i trójwymiarowe kępy trawy
func _ground_details() -> void:
	for tp in tree_pos:
		var r := rng.randf_range(2.6, 4.4)
		var cx := int((tp.x - X0) * 2.0)
		var cz := int((tp.y - Z0) * 2.0)
		var pr := int(r * 2.0)
		for dz in range(-pr, pr + 1):
			for dx in range(-pr, pr + 1):
				var px := cx + dx
				var pz := cz + dz
				if px < 0 or pz < 0 or px >= MAP_W or pz >= MAP_H:
					continue
				var d := Vector2(dx, dz).length() / float(pr)
				if d > 1.0:
					continue
				var c := img2.get_pixel(px, pz)
				c.b = maxf(c.b, 1.0 - d * d)
				img2.set_pixel(px, pz, c)
	ctl2_tex.update(img2)
	# kępy trawy: lekka siatka proceduralna, fragmenty z własnym zasięgiem widoczności
	var gmesh: Mesh = Props.grass_mesh()
	var tall := 1.0
	var gmat: Material = Props.grass_material(tall)
	var chunk := 32.0
	var cells := {}
	var count := 0
	for k in range(9000):
		var cx0 := rng.randf_range(-206.0, 206.0)
		var cz0 := rng.randf_range(-166.0, 166.0)
		# kępa: kilka źdźbeł obok siebie, wyższe w środku
		for j in range(rng.randi_range(2, 6)):
			var x := cx0 + rng.randf_range(-1.6, 1.6)
			var z := cz0 + rng.randf_range(-1.6, 1.6)
			var px2 := clampi(int((x - X0) * 2.0), 0, MAP_W - 1)
			var pz2 := clampi(int((z - Z0) * 2.0), 0, MAP_H - 1)
			var a := img1.get_pixel(px2, pz2)
			if a.r + a.g + a.b + a.a > 0.1 or img2.get_pixel(px2, pz2).r > 0.1:
				continue
			if not is_free(x * SC, z * SC, 0.15):
				continue
			var key := Vector2i(int(floor(x / chunk)), int(floor(z / chunk)))
			if not cells.has(key):
				cells[key] = []
			var hgt := rng.randf_range(0.22, 0.5)
			var wid := hgt * rng.randf_range(1.2, 2.0)
			var bs := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(wid * INV, hgt, wid * INV))
			cells[key].append(Transform3D(bs, Vector3(x, hd(x, z) - 0.03, z)))
			count += 1
	for key in cells:
		var arr: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = gmesh
		mm.instance_count = arr.size()
		for i in range(arr.size()):
			mm.set_instance_transform(i, arr[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = gmat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 64.0
		mi.visibility_range_end_margin = 2.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		city.add_child(mi)


# ---------------------------------------------------------------- estakada kolejki nad miastem
func _viaduct() -> void:
	var cm := Props.pbr("concrete_wall_008", 0.25, Color(0.66, 0.66, 0.64))
	var dark := Props.pbr("dirty_concrete", 0.3, Color(0.55, 0.55, 0.54))
	var zc := -24.0
	var top := 14.2
	var GC := [Color(0.9, 0.9, 0.9), Color(0.85, 0.2, 0.2), Color(0.25, 0.5, 0.9), Color(0.95, 0.8, 0.2), Color(0.3, 0.8, 0.4)]
	# płyta toru, belki i bariery
	Models.box(city, Vector3(430.0, 0.9, 7.6), Vector3(0.0, top - 0.45, zc), cm)
	Models.box(city, Vector3(430.0, 1.3, 1.6), Vector3(0.0, top - 1.5, zc), dark)
	for sz in [-3.6, 3.6]:
		Models.box(city, Vector3(430.0, 1.0, 0.3), Vector3(0.0, top + 0.5, zc + sz), dark)
	var steel := Models.mat("3a3632", 0.5, 0.7)
	for rz in [-1.3, 1.3]:
		Models.box(city, Vector3(430.0, 0.12, 0.14), Vector3(0.0, top + 0.08, zc + rz), steel, Vector3.ZERO, false)
	var tags := ["DBS", "SKERO", "STAL", "HWK", "86", "ELO", "KSH", "OLD TOWN", "BLOKI"]
	var x := -204.0
	var k := 0
	while x <= 204.0:
		var blocked := false
		for bx in [[-106.0, 9.0], [-27.0, 5.0], [60.0, 5.0], [12.0, 4.0], [166.0, 8.0], [145.0, 13.0]]:
			if absf(x - bx[0]) < bx[1]:
				blocked = true
		if not blocked:
			var gy := hd(x, zc)
			var h := top - 1.9 - gy + 1.0
			Models.box(city, Vector3(2.8, h, 2.8), Vector3(x, gy - 1.0 + h * 0.5, zc), cm)
			Models.box(city, Vector3(4.2, 1.1, 8.4), Vector3(x, top - 2.6, zc), cm)
			add_col(x - 1.4, x + 1.4, zc - 1.4, zc + 1.4, 12.0)
			if k % 2 == 0:
				_graffiti(tags[rng.randi_range(0, tags.size() - 1)], x, zc + 1.45, 1.6, 0.0, GC[rng.randi_range(0, 4)], rng.randi_range(60, 100))
			# słup trakcyjny co drugi filar
			if k % 2 == 1:
				Models.box(city, Vector3(0.3, 5.0, 0.3), Vector3(x, top + 2.5, zc + 3.5), steel)
				Models.box(city, Vector3(0.2, 0.2, 7.0), Vector3(x, top + 4.8, zc), steel, Vector3.ZERO, false)
		x += 24.0
		k += 1
	# pociąg (w metrach świata, poza skalowanym węzłem miasta)
	var tr := Node3D.new()
	add_child(tr)
	var body := Models.mat("d8d6cc", 0.5, 0.3)
	var stripe := Models.mat("b0281e", 0.5, 0.2)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.1, 0.12)
	glass.roughness = 0.15
	glass.metallic = 0.4
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.86, 0.6)
	glass.emission_energy_multiplier = 0.0
	for i in range(3):
		var cx := (i - 1) * 13.4
		Models.box(tr, Vector3(13.0, 2.9, 2.7), Vector3(cx, 2.05, 0), body)
		Models.box(tr, Vector3(13.02, 0.5, 2.72), Vector3(cx, 1.2, 0), stripe, Vector3.ZERO, false)
		Models.box(tr, Vector3(11.6, 0.95, 2.74), Vector3(cx, 2.55, 0), glass, Vector3.ZERO, false)
		Models.box(tr, Vector3(13.0, 0.3, 2.3), Vector3(cx, 3.6, 0), Models.mat("5a5c60", 0.6, 0.3), Vector3.ZERO, false)
		for bx2 in [-4.4, 4.4]:
			Models.box(tr, Vector3(2.2, 0.6, 2.2), Vector3(cx + bx2, 0.45, 0), Models.mat("1c1c1e", 0.7, 0.4), Vector3.ZERO, false)
	var snd := AudioStreamPlayer3D.new()
	snd.unit_size = 14.0
	snd.max_distance = 110.0
	snd.volume_db = -4.0
	tr.add_child(snd)
	var head := SpotLight3D.new()
	head.light_color = Color(1.0, 0.95, 0.8)
	head.light_energy = 3.0
	head.spot_range = 30.0
	head.spot_angle = 24.0
	head.light_volumetric_fog_energy = 2.0
	head.position = Vector3(20.2, 2.0, 0)
	head.rotation.y = -PI / 2.0
	tr.add_child(head)
	tr.visible = false
	train = {"node": tr, "x": 0.0, "dir": 1.0, "wait": 25.0, "active": false, "snd": snd, "glass": glass, "y": top + 0.15, "z": zc * SC, "head": head}


## kolejka przejeżdża estakadą co minutę–dwie
func tick_train(dt: float, night_f: float) -> void:
	if train.is_empty():
		return
	var tr: Node3D = train.node
	if not train.active:
		train.wait = float(train.wait) - dt
		if float(train.wait) <= 0.0:
			train.active = true
			train.dir = -float(train.dir)
			train.x = -150.0 * float(train.dir)
			tr.visible = true
			tr.rotation.y = 0.0 if float(train.dir) > 0.0 else PI
			train.glass.emission_energy_multiplier = night_f * 2.2
			train.head.visible = night_f > 0.2
			var st: AudioStream = Sfx.train_stream()
			if st != null and not Sfx.muted:
				train.snd.stream = st
				train.snd.play()
		return
	train.x = float(train.x) + float(train.dir) * 15.0 * dt
	tr.position = Vector3(float(train.x), float(train.y), float(train.z))
	if absf(float(train.x)) > 152.0:
		train.active = false
		train.wait = randf_range(55.0, 120.0)
		tr.visible = false
		train.snd.stop()


func _lamps() -> void:
	var x := -190.0
	var k := 0
	while x < 200.0:
		if absf(x - 145.0) > 16.0:
			_lamp(x, 12.2 if k % 2 == 0 else 27.8, 0.0 if k % 2 == 0 else PI, k % 5 == 3)
		x += 34.0
		k += 1
	for e in [[6.7, 62.0, PI / 2.0, false], [-6.7, 98.0, -PI / 2.0, true], [6.7, 134.0, PI / 2.0, false], [-99.3, -30.0, -PI / 2.0, false], [-99.3, -80.0, -PI / 2.0, true],
			[-70.0, -123.6, PI, false], [-10.0, -123.6, PI, false], [50.0, -123.6, PI, true], [88.7, -90.0, -PI / 2.0, false], [-25.4, -68.0, PI / 2.0, false],
			[30.0, -67.6, 0.0, false], [-60.0, -101.5, 0.0, true], [20.0, -101.5, 0.0, false], [61.7, -40.0, PI, false], [76.7, 76.0, PI, false], [170.2, -30.0, PI / 2.0, true], [175.8, 33.0, 0.0, false]]:
		_lamp(e[0], e[1], e[2], e[3])


func _backdrop() -> void:
	var m: ShaderMaterial = fac["plyta"]
	for e in [[-170.0, -230.0, 50.0, 14.0, 33.0], [-90.0, -240.0, 60.0, 14.0, 39.0], [0.0, -228.0, 46.0, 14.0, 33.0], [80.0, -244.0, 60.0, 14.0, 45.0], [170.0, -232.0, 40.0, 14.0, 30.0],
			[-270.0, -90.0, 14.0, 60.0, 36.0], [-262.0, 40.0, 14.0, 50.0, 30.0], [-275.0, 140.0, 14.0, 60.0, 39.0], [-120.0, 232.0, 60.0, 14.0, 33.0], [20.0, 240.0, 50.0, 14.0, 39.0], [130.0, 230.0, 46.0, 14.0, 27.0]]:
		var mi := Models.box(city, Vector3(e[2], e[4], e[3]), Vector3(e[0], e[4] * 0.5 - 0.5, e[1]), m)
		mi.set_instance_shader_parameter("b_origin", Vector3(e[0] - e[2] * 0.5, 0.0, e[1] - e[3] * 0.5))
		mi.set_instance_shader_parameter("b_wall", Color(0.72, 0.72, 0.7))
		mi.set_instance_shader_parameter("b_accent", Color(0.6, 0.55, 0.45))
		mi.set_instance_shader_parameter("b_seed", rng.randf() * 10.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for e in [[262.0, -60.0, 3.0, 60.0], [280.0, 40.0, 2.4, 48.0], [250.0, 120.0, 2.0, 40.0]]:
		var c := Models.cyl(city, e[2] * 0.6, e[2], e[3], Vector3(e[0], e[3] * 0.5, e[1]), Models.mat("5a4f4a", 0.9), Vector3.ZERO, 10)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Models.box(city, Vector3(60.0, 18.0, 120.0), Vector3(262.0, 9.0, 10.0), Models.mat("3a3836", 0.95), Vector3.ZERO, false)
	# granice mapy: kolizja, wysoki mur i gęsta zabudowa tuż za nim — żadnych pustych pól po horyzont
	add_col(-214.0, -209.0, -175.0, 175.0, 6.0)
	add_col(209.0, 214.0, -175.0, 175.0, 6.0)
	add_col(-214.0, 214.0, -175.0, -169.5, 6.0)
	add_col(-214.0, 214.0, 169.5, 175.0, 6.0)
	for i in range(4):
		rects.pop_back()
	var wm := Props.pbr("dirty_concrete", 0.22, Color(0.62, 0.62, 0.6))
	var wtop := Models.mat("4a4a48", 0.9)
	var xw := -204.0
	while xw < 204.0:
		for zz in [-169.2, 169.2]:
			var gy := hd(xw + 6.0, zz)
			Models.box(city, Vector3(11.9, 4.6, 0.4), Vector3(xw + 6.0, gy + 1.9, zz), wm)
			Models.box(city, Vector3(12.0, 0.14, 0.56), Vector3(xw + 6.0, gy + 4.25, zz), wtop, Vector3.ZERO, false)
		xw += 12.0
	var zw := -168.0
	while zw < 168.0:
		for xx in [-208.8, 208.8]:
			var gy2 := hd(xx, zw + 6.0)
			Models.box(city, Vector3(0.4, 4.6, 11.9), Vector3(xx, gy2 + 1.9, zw + 6.0), wm)
			Models.box(city, Vector3(0.56, 0.14, 12.0), Vector3(xx, gy2 + 4.25, zw + 6.0), wtop, Vector3.ZERO, false)
		zw += 12.0
	var GC := [Color(0.9, 0.9, 0.9), Color(0.85, 0.2, 0.2), Color(0.25, 0.5, 0.9), Color(0.95, 0.8, 0.2), Color(0.3, 0.8, 0.4), Color(0.9, 0.4, 0.75)]
	var tags := ["DBS", "SKERO", "STAL TO MY", "HWK", "KONIEC ŚWIATA", "BLOKI", "ZOSTAŃ TU", "NIE MA WYJŚCIA", "ELO", "86", "KSH", "DEAD END"]
	for k in range(26):
		var side := k % 4
		var t := rng.randf_range(-0.9, 0.9)
		match side:
			0: _graffiti(tags[rng.randi_range(0, 11)], t * 200.0, -168.95, rng.randf_range(1.2, 2.4), 0.0, GC[rng.randi_range(0, 5)], rng.randi_range(110, 220))
			1: _graffiti(tags[rng.randi_range(0, 11)], t * 200.0, 168.95, rng.randf_range(1.2, 2.4), PI, GC[rng.randi_range(0, 5)], rng.randi_range(110, 220))
			2: _graffiti(tags[rng.randi_range(0, 11)], -208.55, t * 160.0, rng.randf_range(1.2, 2.4), PI / 2.0, GC[rng.randi_range(0, 5)], rng.randi_range(110, 220))
			_: _graffiti(tags[rng.randi_range(0, 11)], 208.55, t * 160.0, rng.randf_range(1.2, 2.4), -PI / 2.0, GC[rng.randi_range(0, 5)], rng.randi_range(110, 220))
	# pierścień zabudowy za murem
	var keys := ["plyta", "plyta2", "kamA", "kamB", "cegla2", "kamC", "plyta", "cegla"]
	var px := -230.0
	while px < 230.0:
		for zz2 in [-190.0, 190.0]:
			var w := rng.randf_range(24.0, 38.0)
			var hh := rng.randf_range(4.0, 11.0) * 3.0
			var kk: String = keys[rng.randi_range(0, keys.size() - 1)]
			var bz = zz2 + rng.randf_range(-6.0, 6.0)
			var mi2 := Models.box(city, Vector3(w, hh, 16.0), Vector3(px + w * 0.5, hd(px, zz2 * 0.88) + hh * 0.5 - 0.5, bz), fac[kk])
			mi2.set_instance_shader_parameter("b_origin", Vector3(px * SC, hd(px, zz2 * 0.88), (bz - 8.0) * SC))
			mi2.set_instance_shader_parameter("b_wall", Color(0.74, 0.72, 0.68) * rng.randf_range(0.85, 1.1))
			mi2.set_instance_shader_parameter("b_accent", Color(0.65, 0.58, 0.48))
			mi2.set_instance_shader_parameter("b_seed", rng.randf() * 10.0)
			mi2.set_instance_shader_parameter("b_dead", rng.randf_range(0.0, 0.4))
		px += rng.randf_range(34.0, 46.0)
	var pz := -190.0
	while pz < 190.0:
		for xx2 in [-230.0, 230.0]:
			var d2 := rng.randf_range(24.0, 38.0)
			var hh2 := rng.randf_range(4.0, 11.0) * 3.0
			var kk2: String = keys[rng.randi_range(0, keys.size() - 1)]
			var bx3 = xx2 + rng.randf_range(-6.0, 6.0)
			var mi3 := Models.box(city, Vector3(16.0, hh2, d2), Vector3(bx3, hd(xx2 * 0.9, pz) + hh2 * 0.5 - 0.5, pz + d2 * 0.5), fac[kk2])
			mi3.set_instance_shader_parameter("b_origin", Vector3((bx3 - 8.0) * SC, hd(xx2 * 0.9, pz), pz * SC))
			mi3.set_instance_shader_parameter("b_wall", Color(0.74, 0.72, 0.68) * rng.randf_range(0.85, 1.1))
			mi3.set_instance_shader_parameter("b_accent", Color(0.65, 0.58, 0.48))
			mi3.set_instance_shader_parameter("b_seed", rng.randf() * 10.0)
			mi3.set_instance_shader_parameter("b_dead", rng.randf_range(0.0, 0.4))
		pz += rng.randf_range(34.0, 46.0)


func _flush_multimeshes() -> void:
	_multimesh(_curbs, Vector3(2.0 * INV, 0.26, 0.2 * INV), Props.pbr("concrete_wall_008", 0.5, Color(0.62, 0.62, 0.6)), false)
	_curbs.clear()
	_multimesh(_bal_slab, Vector3(3.2 * INV, 0.14, 0.8 * INV), Props.pbr("concrete_wall_008", 0.4, Color(0.7, 0.7, 0.68)), true)
	if not _bal_rail.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var bm := BoxMesh.new()
		bm.size = Vector3(3.2 * INV, 1.0, 0.06 * INV)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		bm.material = m
		mm.mesh = bm
		mm.instance_count = _bal_rail.size()
		for i in range(_bal_rail.size()):
			mm.set_instance_transform(i, _bal_rail[i][0])
			mm.set_instance_color(i, _bal_rail[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city.add_child(mi)
	_bal_slab.clear()
	_bal_rail.clear()


func _multimesh(xforms: Array, size: Vector3, material: Material, shadow: bool) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = material
	mm.mesh = bm
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	city.add_child(mi)


## znaczniki skrytek (dyskretne: kreda na murze) — widoczne tylko z bliska
func _markers() -> void:
	for d in D.DROPS:
		var dx: float = float(d.x) * INV
		var dz: float = float(d.z) * INV
		var l := _sign("x", Vector3(dx, hd(dx, dz) + 0.12, dz), Color(0.9, 0.9, 0.85, 0.7), 60, 0.0, 0.006, 4)
		l.rotation.x = -PI / 2.0
		l.visibility_range_end = 14.0


# ================================================================ graf ścieżek
func _graph() -> void:
	var lines := [
		[[-200.0, 13.5], [-150.0, 13.5], [-101.0, 13.5], [-58.0, 13.5], [-27.0, 13.5], [-6.0, 13.5], [13.0, 13.5], [60.0, 13.5], [75.0, 13.5], [126.0, 13.5], [145.0, 13.5], [166.0, 13.5], [200.0, 13.5]],
		[[-200.0, 26.5], [-150.0, 26.5], [-96.0, 26.5], [-58.0, 26.5], [-5.3, 26.5], [5.3, 26.5], [60.0, 26.5], [75.0, 26.5], [126.0, 26.5], [145.0, 26.5], [172.0, 26.5], [200.0, 26.5]],
		[[-101.0, 13.5], [-96.0, 26.5]], [[-58.0, 13.5], [-58.0, 26.5]], [[-6.0, 13.5], [-5.3, 26.5]], [[13.0, 13.5], [5.3, 26.5]], [[60.0, 13.5], [60.0, 26.5]], [[126.0, 13.5], [126.0, 26.5]], [[166.0, 13.5], [172.0, 26.5]],
		[[-5.3, 26.5], [-5.3, 56.0], [-5.3, 84.0], [-5.3, 100.0], [-5.3, 124.0], [-5.3, 148.0]],
		[[5.3, 26.5], [5.3, 56.0], [5.3, 84.0], [5.3, 124.0], [5.3, 148.0]],
		[[-5.3, 84.0], [5.3, 84.0]], [[-5.3, 124.0], [5.3, 124.0]],
		[[-101.0, 13.5], [-101.0, -12.0], [-101.0, -52.0], [-101.0, -66.0], [-101.0, -103.0], [-101.0, -125.0]],
		[[-101.0, -125.0], [-60.0, -125.0], [-27.0, -125.0], [8.0, -125.0], [47.0, -125.0], [90.0, -125.0]],
		[[90.0, -125.0], [90.0, -103.0], [90.0, -66.0]],
		[[-27.0, -125.0], [-27.0, -103.0], [-27.0, -66.0], [-27.0, -31.0], [-27.0, -17.0], [-27.0, 13.5]],
		[[60.0, -66.0], [60.0, -44.0], [60.0, -31.0], [60.0, -17.0], [60.0, 13.5]],
		[[-101.0, -66.0], [-60.0, -66.0], [-27.0, -66.0], [8.0, -66.0], [60.0, -66.0], [90.0, -66.0]],
		[[-101.0, -103.0], [-60.0, -103.0], [-27.0, -103.0], [20.0, -103.0], [47.0, -103.0], [90.0, -103.0]],
		[[8.0, -66.0], [8.0, -76.6]], [[-60.0, -66.0], [-60.0, -76.2]],
		[[47.0, -103.0], [47.0, -111.5]], [[60.0, -44.0], [72.0, -43.5]],
		[[-27.0, -103.0], [-10.0, -109.0]],
		[[-92.0, -13.5], [-84.0, -13.5], [-58.0, -13.5], [-27.0, -17.0], [13.0, -13.5], [48.0, -13.5], [60.0, -17.0]],
		[[-58.0, -13.5], [-58.0, 13.5]], [[13.0, -13.5], [13.0, 13.5]], [[-75.0, -11.6], [-75.0, -13.5]],
		[[-96.0, 26.5], [-96.0, 56.0], [-88.0, 66.0], [-110.0, 70.0], [-150.0, 60.0], [-170.0, 90.0], [-160.0, 122.0], [-130.0, 150.0], [-90.0, 150.0], [-70.0, 140.0]],
		[[-88.0, 66.0], [-60.0, 100.0], [-70.0, 118.0], [-70.0, 128.0]],
		[[-5.3, 100.0], [-60.0, 100.0]],
		[[-88.0, 66.0], [-105.0, 85.0], [-122.0, 104.0], [-140.0, 112.0], [-160.0, 122.0]],
		[[75.0, 26.5], [75.0, 60.0], [75.0, 84.0]], [[5.3, 84.0], [42.0, 84.0], [58.0, 84.0], [75.0, 84.0], [100.0, 84.0]],
		[[65.0, 84.0], [65.0, 94.4]], [[100.0, 84.0], [108.0, 98.0], [108.5, 110.0]],
		[[166.0, 13.5], [166.0, -10.0], [166.0, -48.0], [166.0, -66.0], [166.0, -98.0]],
		[[172.0, 26.5], [172.0, 30.0], [180.0, 56.0], [192.0, 61.0]],
		[[90.0, -66.0], [128.0, -66.0], [145.0, -66.0], [166.0, -66.0]],
		[[-101.0, -125.0], [-101.0, -135.0], [-50.0, -135.0], [40.0, -135.0], [90.0, -135.0], [90.0, -125.0]],
		[[-50.0, -135.0], [-50.0, -145.6]], [[40.0, -135.0], [40.0, -145.6]],
		[[-200.0, 13.5], [-181.0, 9.6]],
	]
	for ln in lines:
		var prev := -1
		for i in range(ln.size()):
			var p := Vector2(ln[i][0], ln[i][1]) * SC
			if i > 0:
				var q := Vector2(ln[i - 1][0], ln[i - 1][1]) * SC
				var n: int = max(1, int(ceil(q.distance_to(p) / 12.0)))
				for s in range(1, n):
					var mid := q.lerp(p, float(s) / n)
					var mi := _wp_add(mid)
					_wp_link(prev, mi)
					prev = mi
			var id := _wp_add(p)
			if prev >= 0:
				_wp_link(prev, id)
			prev = id


func _wp_add(p: Vector2) -> int:
	for i in range(wp.size()):
		if Vector2(wp[i].x, wp[i].z).distance_to(p) < 1.1:
			return i
	wp.append({"x": p.x, "z": p.y, "links": [], "i": wp.size(), "quiet": p.x > 128.0 * SC or p.y > 112.0 * SC and p.x > 20.0 * SC})
	return wp.size() - 1


func _wp_link(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0:
		return
	if not wp[a].links.has(b):
		wp[a].links.append(b)
	if not wp[b].links.has(a):
		wp[b].links.append(a)


# ================================================================ dźwięk klubu, linia wzroku
func _club_audio() -> void:
	club_player = AudioStreamPlayer3D.new()
	club_player.position = club_door
	club_player.bus = "Klub"
	club_player.unit_size = 10.0
	club_player.max_distance = 75.0
	club_player.volume_db = 0.0
	club_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(club_player)
	club_player.finished.connect(_club_next)


func _club_next() -> void:
	var st: AudioStream = Sfx.next_club_stream()
	if st != null:
		club_player.stream = st
		club_player.play()


# ---------------------------------------------------------------- „meliny”: muzyka z okien bloków
var traps: Array = []

## Kilka mieszkań, z których wieczorami dudni bit (własna synteza, jak w klubie). Okno pulsuje fioletem
## (shader elewacji), a dźwięk jest przytłumiony jak zza szyby i słychać go z kilkudziesięciu metrów.
func _trap_houses() -> void:
	var want := [["7", 1, 4, 3], ["5", 2, 0, 2], ["13", 3, 0, 5], ["11", 1, 6, 2]]
	for wdef in want:
		for b in blds:
			if not b.has("key") or String(b.no) != String(wdef[0]):
				continue
			var code: int = wdef[1]
			if Details.is_blind(b, code):
				code = 1 if code >= 3 else 3
			var g: Array = b.gx if code <= 2 else b.gz
			var cs: Vector2 = fac_cell[b.key]
			# szukamy zwykłego okna (nie loggii i nie klatki) najbliżej wskazanej kolumny
			var cx := -1
			for d in range(int(g[1])):
				for cand in [int(wdef[2]) + d, int(wdef[2]) - d]:
					if cand >= 0 and cand < int(g[1]) and cand % 2 == 0 and not (int(b.stair) > 0 and posmod(cand - int(b.st_off), int(b.stair)) == 0):
						cx = cand
						break
				if cx >= 0:
					break
			if cx < 0:
				continue
			var fl := mini(int(wdef[3]), int(floor((float(b.h) + 0.3) / cs.y)) - 1)
			(b.node as MeshInstance3D).set_instance_shader_parameter("b_trap", Vector3(cx, fl, code))
			var pl := AudioStreamPlayer3D.new()
			pl.position = Details.face_pos(b, code, float(g[0]) + (cx + 0.5) * cs.x, fl * cs.y + 1.6, 0.4)
			pl.bus = "Blok"
			pl.unit_size = 5.0
			pl.max_distance = 38.0
			pl.volume_db = -3.0
			pl.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			add_child(pl)
			traps.append({"player": pl, "i": traps.size(), "from": 16.5 + traps.size() * 1.3, "to": 3.5 - traps.size() * 0.5})


func _trap_tick() -> void:
	if traps.is_empty() or Sfx.muted:
		return
	var h := G.hour()
	for t in traps:
		var pl: AudioStreamPlayer3D = t.player
		var on: bool = h >= float(t.from) or h < float(t.to)
		if on and not pl.playing and Sfx.trap_streams.size() > 0:
			pl.stream = Sfx.trap_streams[int(t.i) % Sfx.trap_streams.size()]
			pl.play(randf() * 6.0)
		elif not on and pl.playing:
			pl.stop()


func club_tick() -> void:
	_trap_tick()
	if club_player != null and not club_player.playing and not Sfx.muted:
		_club_next()


## Linia wzroku między dwoma punktami. Zasłaniają ją budynki, mury i blaszane płoty;
## gdy cel kuca (`low`), wystarczy coś do pasa: auto, murek, śmietnik.
## Jak jasno jest w danym miejscu od latarni i ognisk (0 = ciemno, 1 = pod samą lampą).
## Liczy się tylko nocą: patrol widzi wtedy daleko tylko to, co stoi w świetle.
func light_at(x: float, z: float) -> float:
	if _lamp_pts.is_empty():
		for l in lamps:
			if not is_instance_valid(l) or l.has_meta("tv") or not l.is_inside_tree():
				continue
			var gp: Vector3 = l.global_position
			_lamp_pts.append(Vector3(gp.x, gp.z, 9.5 if l is SpotLight3D else float(l.omni_range) * 0.75))
	var best := 0.0
	for p in _lamp_pts:
		var dx := p.x - x
		var dz := p.y - z
		if absf(dx) < p.z and absf(dz) < p.z:
			best = maxf(best, 1.0 - sqrt(dx * dx + dz * dz) / p.z)
	return clampf(best * 1.7, 0.0, 1.0)


## czy tuż obok jest gęsty krzak, przy którym można się przyczaić
func cover_at(x: float, z: float) -> bool:
	for c in covers:
		var dx: float = c.x - x
		var dz: float = c.y - z
		var r: float = c.z + 0.85
		if dx * dx + dz * dz < r * r:
			return true
	return false


func los(ax: float, az: float, bx: float, bz: float, low := false) -> bool:
	if _bk.is_empty() and not blocks.is_empty():
		_pack_blocks()
	var thr := 1.0 if low else 1.8
	var lx0 := minf(ax, bx)
	var lx1 := maxf(ax, bx)
	var lz0 := minf(az, bz)
	var lz1 := maxf(az, bz)
	var n := _bk.size()
	var i := 0
	while i < n:
		if _bk[i + 4] >= thr and _bk[i] <= lx1 and _bk[i + 1] >= lx0 and _bk[i + 2] <= lz1 and _bk[i + 3] >= lz0:
			if _seg_box(ax, az, bx, bz, _bk[i], _bk[i + 1], _bk[i + 2], _bk[i + 3]):
				return false
		i += 5
	return true


func _pack_blocks() -> void:
	_bk = PackedFloat32Array()
	for b in blocks:
		if b.op:
			_bk.append_array([b.x0, b.x1, b.z0, b.z1, b.h])


# ---------------------------------------------------------------- siatka przejść (pościg)
func _build_grid() -> void:
	grid = AStarGrid2D.new()
	var w := int(ceil(float(NX - 1) * CELL * SC / GCELL))
	var hh := int(ceil(float(NZ - 1) * CELL * SC / GCELL))
	grid.region = Rect2i(0, 0, w, hh)
	grid.cell_size = Vector2(GCELL, GCELL)
	grid.offset = Vector2(X0 * SC + GCELL * 0.5, Z0 * SC + GCELL * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var pad := 0.22
	for b in blocks:
		if float(b.h) < 0.7:
			continue
		var a := _cell(float(b.x0) - pad, float(b.z0) - pad)
		var c := _cell(float(b.x1) + pad, float(b.z1) + pad)
		grid.fill_solid_region(Rect2i(a, c - a + Vector2i.ONE), true)
	# strome zbocza: da się wejść, ale to droga na skróty tylko w ostateczności
	for j in range(0, hh, 2):
		for i in range(0, w, 2):
			var px := X0 * SC + (i + 1) * GCELL
			var pz := Z0 * SC + (j + 1) * GCELL
			var g := maxf(absf(height(px + 1.0, pz) - height(px - 1.0, pz)), absf(height(px, pz + 1.0) - height(px, pz - 1.0))) * 0.5
			if g > 0.42:
				grid.fill_weight_scale_region(Rect2i(i, j, 2, 2), 1.0 + minf(4.0, g * 4.0))


func _cell(x: float, z: float) -> Vector2i:
	var r := grid.region
	return Vector2i(clampi(int(floor((x - X0 * SC) / GCELL)), 0, r.size.x - 1), clampi(int(floor((z - Z0 * SC) / GCELL)), 0, r.size.y - 1))


## najbliższa wolna kratka (gdy punkt wypada w ścianie albo tuż przy niej)
func _free_cell(c: Vector2i) -> Vector2i:
	if not grid.is_point_solid(c):
		return c
	var r := grid.region
	for rad in range(1, 9):
		for dz in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if maxi(absi(dx), absi(dz)) != rad:
					continue
				var q := c + Vector2i(dx, dz)
				if q.x >= 0 and q.y >= 0 and q.x < r.size.x and q.y < r.size.y and not grid.is_point_solid(q):
					return q
	return c


## czy po prostej da się przejść (bez wchodzenia w przeszkody)
func grid_clear(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var n := int(ceil(d / (GCELL * 0.6)))
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		if grid.is_point_solid(_cell(p.x, p.y)):
			return false
	return true


## trasa pieszo z a do b z ominięciem płotów, murów i aut (punkty w metrach świata)
func grid_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	if grid == null:
		return PackedVector2Array([b])
	var ca := _free_cell(_cell(a.x, a.y))
	var cb := _free_cell(_cell(b.x, b.y))
	var raw := grid.get_point_path(ca, cb, true)
	if raw.size() < 2:
		return PackedVector2Array([b])
	# wygładzenie: pomijamy punkty pośrednie, jeśli da się iść na wprost
	var out := PackedVector2Array()
	var cur := a
	var i := 0
	while i < raw.size() - 1:
		var j := mini(raw.size() - 1, i + 24)
		while j > i + 1 and not grid_clear(cur, raw[j]):
			j -= 1
		out.append(raw[j])
		cur = raw[j]
		i = j
	if grid_clear(cur, b) and cur.distance_to(b) > 0.2:
		out.append(b)
	return out


func _seg_box(ax: float, az: float, bx: float, bz: float, x0: float, x1: float, z0: float, z1: float) -> bool:
	if maxf(ax, bx) < x0 or minf(ax, bx) > x1 or maxf(az, bz) < z0 or minf(az, bz) > z1:
		return false
	var t0 := 0.0
	var t1 := 1.0
	var dx := bx - ax
	var dz := bz - az
	for e in [[-dx, ax - x0], [dx, x1 - ax], [-dz, az - z0], [dz, z1 - az]]:
		var p: float = e[0]
		var q: float = e[1]
		if absf(p) < 1e-9:
			if q < 0.0:
				return false
		else:
			var r := q / p
			if p < 0.0:
				if r > t1:
					return false
				t0 = maxf(t0, r)
			else:
				if r < t0:
					return false
				t1 = minf(t1, r)
	return true


func is_free(x: float, z: float, pad := 0.6) -> bool:
	for c in rects:
		if x > c.x0 - pad and x < c.x1 + pad and z > c.z0 - pad and z < c.z1 + pad:
			return false
	return true


# ================================================================ WNĘTRZA
func _room(id: String, floor_tex: String, wall_tex: String, ceil_c: String, wall_tint := Color(1, 1, 1), floor_scale := 0.5) -> Node3D:
	var R: Dictionary = D.ROOMS[id]
	var cx: float = R.cx
	var w: float = R.w
	var d: float = R.d
	var h: float = R.h
	var g := Node3D.new()
	add_child(g)
	rooms[id] = g
	Models.box(g, Vector3(w, 0.1, d), Vector3(cx, -0.05, 0), Props.pbr(floor_tex, floor_scale))
	Models.box(g, Vector3(w, 0.1, d), Vector3(cx, h + 0.05, 0), Models.mat(ceil_c, 1.0))
	var wm := Props.pbr(wall_tex, 0.45, wall_tint)
	var t := 0.4
	for e in [[w + t * 2.0, t, cx, -d * 0.5 - t * 0.5], [w + t * 2.0, t, cx, d * 0.5 + t * 0.5], [t, d, cx - w * 0.5 - t * 0.5, 0.0], [t, d, cx + w * 0.5 + t * 0.5, 0.0]]:
		Models.box(g, Vector3(e[0], h, e[1]), Vector3(e[2], h * 0.5, e[3]), wm)
		add_col(e[2] - e[0] * 0.5, e[2] + e[0] * 0.5, e[3] - e[1] * 0.5, e[3] + e[1] * 0.5, h, true, -1.0)
	# drzwi wyjściowe na południowej ścianie
	var ez := d * 0.5
	if id == "garage":
		Models.box(g, Vector3(2.9, 2.3, 0.08), Vector3(cx, 1.15, ez - 0.05), Props.pbr("painted_metal_shutter", 0.5, Color(0.7, 0.75, 0.8)))
	else:
		Models.box(g, Vector3(1.0, 2.05, 0.08), Vector3(cx, 1.03, ez - 0.05), Props.pbr("wooden_garage_door", 0.6, Color(0.8, 0.75, 0.7)))
		Models.box(g, Vector3(1.16, 0.08, 0.12), Vector3(cx, 2.1, ez - 0.06), Models.mat("3a3027", 0.8))
		Models.cyl(g, 0.02, 0.02, 0.12, Vector3(cx + 0.38, 1.0, ez - 0.1), Models.mat("b8a070", 0.4, 0.8), Vector3(PI / 2.0, 0, 0), 6)
	inter.append({"loc": id, "x": cx, "z": ez - 0.06, "y0": 0.0, "y1": 2.1, "r": 1.4 if id == "garage" else 0.62, "reach": 2.6, "id": "exit_" + id,
		"label": func(): return "Wyjdź", "act": func(): G.main.exit_room()})
	return g


func _room_light(g: Node3D, x: float, z: float, h: float, energy := 1.4, color := Color(1.0, 0.86, 0.66), rng_m := 9.0) -> OmniLight3D:
	var li := OmniLight3D.new()
	li.position = Vector3(x, h - 0.35, z)
	li.light_color = color
	li.light_energy = energy
	li.omni_range = rng_m
	li.omni_attenuation = 1.1
	li.shadow_enabled = true
	g.add_child(li)
	return li


func _rp(g: Node3D, name: String, x: float, z: float, ry := 0.0, h := 0.0, y := 0.0, col_x := 0.0, col_z := 0.0) -> Node3D:
	var n := Props.make(name, h)
	n.position = Vector3(x, y, z)
	n.rotation.y = ry
	g.add_child(n)
	if col_x > 0.0:
		add_col(x - col_x, x + col_x, z - col_z, z + col_z, 1.0, true, -1.0)
		rects.pop_back()
	return n


func _interiors() -> void:
	# ---------------- KAWALERKA ----------------
	# Wynajęta dziupla: stół z wagą, łóżko polowe, kanapa po poprzednim lokatorze, pudła, których nikt nie rozpakował.
	var R: Dictionary = D.ROOMS.safe
	var cx: float = R.cx
	var h: float = R.h
	var w: float = R.w
	var d: float = R.d
	var g := _room("safe", "old_linoleum_flooring_01", "decrepit_wallpaper", "d6d2c8", Color(0.95, 0.92, 0.85), 0.7)
	Interior.baseboards(g, cx, w, d, "cfc8b6")
	Interior.ceiling_lamp(g, Vector3(cx, h, 0.2), "shade")
	_room_light(g, cx, 0.2, h - 0.1, 1.35, Color(1.0, 0.82, 0.58), 8.0)
	Interior.rug(g, Vector3(cx - 1.7, 0, 0.75), Vector2(2.4, 1.6), 0.04)
	# łóżko pod zachodnią ścianą
	_rp(g, "old_bed_frame", cx - w * 0.5 + 0.62, -d * 0.5 + 1.1, 0.0, 1.0, 0.0, 0.55, 1.05)
	var bedding: Node3D = Stations.model("dom_posciel")
	if bedding != null:
		# materac, skotłowana kołdra i poduszka z modelu (poduszka od strony ściany)
		bedding.position = Vector3(cx - w * 0.5 + 0.62, 0.0, -d * 0.5 + 1.1)
		bedding.rotation.y = PI
		g.add_child(bedding)
	else:
		Models.box(g, Vector3(0.84, 0.16, 1.86), Vector3(cx - w * 0.5 + 0.62, 0.42, -d * 0.5 + 1.1), Models.mat("b9b4a6", 0.95))
		Models.box(g, Vector3(0.8, 0.07, 1.2), Vector3(cx - w * 0.5 + 0.62, 0.52, -d * 0.5 + 1.4), Models.mat("3d4f66", 0.95), Vector3(0, 0.05, 0))
		Models.box(g, Vector3(0.55, 0.1, 0.36), Vector3(cx - w * 0.5 + 0.62, 0.54, -d * 0.5 + 0.42), Models.mat("d8d4c8", 0.95), Vector3(0, -0.1, 0.04))
	inter.append({"loc": "safe", "x": cx - w * 0.5 + 0.62, "z": -d * 0.5 + 1.1, "y0": 0.1, "y1": 0.75, "r": 0.9, "reach": 2.5, "id": "bed",
		"label": func(): return "Łóżko — sen", "act": func(): G.main.sleep()})
	Interior.picture(g, Vector3(cx - w * 0.5 + 0.01, 1.55, -d * 0.5 + 1.0), PI / 2.0, 0.7, "pic_koncert")
	Interior.picture(g, Vector3(cx - w * 0.5 + 0.01, 1.62, -d * 0.5 + 1.75), PI / 2.0, 0.5, "pic_boks")
	Interior.bottle(g, Vector3(cx - w * 0.5 + 1.25, 0, -d * 0.5 + 0.5), "5a3414")
	Interior.bottle(g, Vector3(cx - w * 0.5 + 1.38, 0, -d * 0.5 + 0.62), "3a6a3a", true)
	Interior.papers(g, Vector3(cx - w * 0.5 + 1.3, 0, -d * 0.5 + 1.5), 0.4, 2)
	# stół roboczy z wagą (jedyne stanowisko w mieszkaniu)
	var tx := cx + 0.9
	var tz := -d * 0.5 + 0.62
	_rp(g, "painted_wooden_table", tx, tz, 0.0, 0.8, 0.0, 1.0, 0.5)
	_scale_set(g, Vector3(tx - 0.35, 0.8, tz))
	_rp(g, "desk_lamp_arm_01", tx + 0.75, tz - 0.15, 0.6, 0.55, 0.8)
	_rp(g, "cigarette_pack", tx + 0.08, tz + 0.26, 0.4, 0.09, 0.8)
	Interior.ashtray(g, Vector3(tx + 0.22, 0.8, tz + 0.3))
	Interior.mug(g, Vector3(tx - 0.3, 0.8, tz + 0.3), "8a3a2a")
	# radio na stole: każde kliknięcie zmienia stację, trzecie wyłącza
	var radio: Node3D = Stations.model("radio")
	if radio != null:
		radio.position = Vector3(tx - 0.62, 0.8, tz - 0.08)
		radio.rotation.y = 0.2
		g.add_child(radio)
		radio_led = Stations._find(radio, "Lampka") as Node3D
		radio_player = AudioStreamPlayer3D.new()
		radio_player.bus = "Muzyka" if AudioServer.get_bus_index("Muzyka") >= 0 else "Master"
		radio_player.position = Vector3(tx - 0.62, 0.95, tz - 0.08)
		radio_player.unit_size = 3.2
		radio_player.max_distance = 14.0
		radio_player.volume_db = -7.0
		g.add_child(radio_player)
		inter.append({"loc": "safe", "x": tx - 0.62, "z": tz - 0.08, "y0": 0.8, "y1": 1.1, "r": 0.3, "reach": 2.6, "id": "radio",
			"label": func(): return "Radio — %s" % G.main.radio_name(), "act": func(): G.main.radio_click()})
	# laptop: jedyne miejsce zapisu gry w mieszkaniu
	_rp(g, "classic_laptop", tx + 0.55, tz + 0.05, 0.0, 0.24, 0.8)
	inter.append({"loc": "safe", "x": tx + 0.55, "z": tz + 0.05, "y0": 0.78, "y1": 1.08, "r": 0.3, "reach": 2.5, "id": "save_safe",
		"label": func(): return "Laptop — zapisz grę", "act": func(): G.main.save_here()})
	var dl := _room_light(g, tx + 0.4, tz + 0.1, 1.75, 0.8, Color(1.0, 0.9, 0.7), 2.6)
	dl.shadow_enabled = false
	_rp(g, "painted_wooden_chair_01", tx - 0.1, tz + 0.85, PI, 0.92)
	inter.append({"loc": "safe", "x": tx - 0.38, "z": tz, "y0": 0.6, "y1": 1.05, "r": 0.5, "reach": 2.5, "id": "pack_safe",
		"label": func(): return "Waga i woreczki — porcjowanie towaru", "act": func(): G.ui.open_pack("safe")})
	Interior.wall_shelf(g, Vector3(tx + 0.1, 1.72, -d * 0.5 + 0.01), 0.0, 1.0, 7)
	_rp(g, "wall_clock", cx + 2.35, -d * 0.5 + 0.04, 0.0, 0.3, 1.82)
	# skrytka: szafa
	_rp(g, "painted_wooden_cabinet", cx + w * 0.5 - 0.42, 0.6, -PI / 2.0, 1.75, 0.0, 0.4, 0.65)
	inter.append({"loc": "safe", "x": cx + w * 0.5 - 0.42, "z": 0.6, "y0": 0.1, "y1": 1.7, "r": 0.62, "reach": 2.5, "id": "stash_safe",
		"label": func(): return "Skrytka w szafie", "act": func(): G.ui.open_stash("safe")})
	Interior.note(g, Vector3(cx + w * 0.5 - 0.01, 1.62, 1.75), -PI / 2.0, "WYBUCH W STAREJ HUCIE\nPolicja szuka świadków. Jedna osoba zatrzymana.", 0.46, 0.3)
	Interior.picture(g, Vector3(cx + w * 0.5 - 0.01, 1.55, 2.35), -PI / 2.0, 0.46, "pic_kalendarz")
	# kanapa, ława, telewizor
	_rp(g, "sofa_02", cx - 2.05, d * 0.5 - 0.55, PI, 0.72, 0.0, 0.95, 0.45)
	_rp(g, "throw_pillows_01", cx - 2.5, d * 0.5 - 0.6, 2.6, 0.3, 0.42)
	_rp(g, "coffeetable_01", cx - 2.05, d * 0.5 - 1.5, 0.0, 0.4, 0.0, 0.5, 0.3)
	Interior.pizza_box(g, Vector3(cx - 2.25, 0.4, d * 0.5 - 1.5), 0.3, 2)
	Interior.can(g, Vector3(cx - 1.82, 0.4, d * 0.5 - 1.42), "b0382c")
	Interior.can(g, Vector3(cx - 1.72, 0.4, d * 0.5 - 1.6), "2a6ac8", true)
	Interior.can(g, Vector3(cx - 1.3, 0.0, d * 0.5 - 1.1), "b0382c", true)
	_rp(g, "side_table_01", cx - 1.55, -d * 0.5 + 0.4, 0.0, 0.5, 0.0, 0.3, 0.3)
	_rp(g, "television_02", cx - 1.55, -d * 0.5 + 0.4, 0.0, 0.42, 0.5)
	var tvl := _room_light(g, cx - 1.55, -d * 0.5 + 0.9, 1.3, 0.35, Color(0.5, 0.65, 1.0), 3.0)
	tvl.shadow_enabled = false
	tvl.set_meta("tv", true)
	lamps.append(tvl)
	# aneks kuchenny pod wschodnią ścianą: szafki ze zlewem, kuchenka, lodówka
	Interior.kitchenette(g, Vector3(cx + w * 0.5 - 0.3, 0.0, -d * 0.5 + 0.72), 1.3, -PI / 2.0)
	_rp(g, "vintage_microwave", cx + w * 0.5 - 0.32, -d * 0.5 + 0.42, -PI / 2.0, 0.3, 0.89)
	Interior.mug(g, Vector3(cx + w * 0.5 - 0.42, 0.89, -d * 0.5 + 1.2), "d9d4c8")
	Interior.bottle(g, Vector3(cx + w * 0.5 - 0.2, 0.89, -d * 0.5 + 1.28), "c9c4b6")
	_rp(g, "electric_stove", cx + w * 0.5 - 0.4, -d * 0.5 + 1.72, -PI / 2.0, 0.86)
	Interior.fridge(g, Vector3(cx + w * 0.5 - 0.33, 0.0, -d * 0.5 + 2.36), -PI / 2.0)
	add_col(cx + w * 0.5 - 0.72, cx + w * 0.5, -d * 0.5 + 0.05, -d * 0.5 + 2.66, 1.0, true, -1.0)
	rects.pop_back()
	# przy drzwiach: wieszak, buty, włącznik, nierozpakowane pudła
	Interior.coat_rack(g, Vector3(cx + 1.0, 1.7, d * 0.5 - 0.01), PI)
	Interior.shoes(g, Vector3(cx + 0.95, 0, d * 0.5 - 0.22), 0.3)
	Interior.shoes(g, Vector3(cx + 1.3, 0, d * 0.5 - 0.2), -0.2, "6a4a2a")
	Interior.switch_plate(g, Vector3(cx - 0.75, 1.25, d * 0.5 - 0.01), PI)
	Models.box(g, Vector3(0.9, 0.012, 0.5), Vector3(cx, 0.007, d * 0.5 - 0.45), Models.mat("3a3630", 0.95), Vector3.ZERO, false)
	_rp(g, "cardboard_box_01", cx + 2.6, d * 0.5 - 0.5, 0.4, 0.34)
	_rp(g, "cardboard_box_01", cx + 2.2, d * 0.5 - 0.42, 1.2, 0.3)
	Interior.moving_boxes(g, Vector3(cx + 2.75, 0, d * 0.5 - 1.25), 3)
	_rp(g, "vintage_suitcase", cx + 3.25, d * 0.5 - 0.35, 0.2, 0.5)
	# okno z firanką: w dzień rzuca plamę światła na podłogę
	windows.append(Interior.window(g, Vector3(cx - 1.4, 1.55, -d * 0.5), 1.5, 1.2, "n", "sheer", false))
	Interior.picture(g, Vector3(cx - 2.75, 1.6, -d * 0.5 + 0.01), 0.0, 0.52, "pic_jelen", "5a4326")
	# zacieki na ścianach i suficie
	Interior.stain(g, Vector3(cx + 2.9, h - 0.01, 1.6), Vector3(PI / 2.0, 0, 0), Vector2(1.6, 1.2), Color(0.3, 0.24, 0.14, 0.28))
	Interior.stain(g, Vector3(cx - 3.0, h - 0.01, -1.9), Vector3(PI / 2.0, 0, 0), Vector2(1.2, 1.0), Color(0.3, 0.24, 0.14, 0.22))
	Interior.stain(g, Vector3(cx + 0.2, 1.9, -d * 0.5 + 0.012), Vector3.ZERO, Vector2(0.9, 1.4), Color(0.14, 0.1, 0.06, 0.25))
	Interior.stain(g, Vector3(cx + w * 0.5 - 0.012, 0.5, 1.9), Vector3(0, -PI / 2.0, 0), Vector2(1.3, 0.9), Color(0.1, 0.08, 0.05, 0.3))

	# ---------------- SKLEP U STASIA ----------------
	var R2: Dictionary = D.ROOMS.shop
	var sx2: float = R2.cx
	var h2: float = R2.h
	var d2: float = R2.d
	var w2: float = R2.w
	var g2 := _room("shop", "dirty_tiles", "beige_wall_001", "d0ccc2", Color(0.9, 0.9, 0.85), 0.6)
	Interior.baseboards(g2, sx2, w2, d2, "8a8272", 0.12)
	_room_light(g2, sx2 - 2.0, 0.0, h2, 1.5, Color(0.9, 0.95, 1.0), 9.0)
	_room_light(g2, sx2 + 2.0, 0.0, h2, 1.3, Color(0.9, 0.95, 1.0), 9.0).shadow_enabled = false
	for lx in [-2.0, 2.0]:
		Props._no_shadow(_rp(g2, "mounted_fluorescent_lights", sx2 + lx, 0.0, PI / 2.0, 0.0, h2 - 0.08))
	# lada z gablotą, kasą i wagą
	Models.box(g2, Vector3(5.0, 1.0, 0.7), Vector3(sx2, 0.5, -1.2), Props.pbr("old_wood_floor", 0.6, Color(0.7, 0.6, 0.5)))
	Models.box(g2, Vector3(5.2, 0.05, 0.8), Vector3(sx2, 1.02, -1.2), Models.mat("2a2a2c", 0.5))
	add_col(sx2 - 2.6, sx2 + 2.6, -1.6, -0.8, 1.1, true, -1.0)
	rects.pop_back()
	_rp(g2, "cashregister_01", sx2 + 1.3, -1.2, PI, 0.45, 1.05)
	Models.box(g2, Vector3(1.3, 0.32, 0.5), Vector3(sx2 - 1.4, 1.21, -1.2), Models.mat("cfe6ee", 0.08, 0.0, 0.0, 0.25), Vector3.ZERO, false)
	for k in range(9):
		Models.box(g2, Vector3(0.1, 0.05 + (k % 3) * 0.03, 0.14), Vector3(sx2 - 1.92 + k * 0.13, 1.08 + (k % 3) * 0.015, -1.2), Models.mat(["c8322a", "e8c22a", "2a6ac8", "3a8a4a"][k % 4], 0.6), Vector3(0, k * 0.2, 0), false)
	_scale_set(g2, Vector3(sx2 + 0.35, 1.045, -1.15))
	Interior.papers(g2, Vector3(sx2 - 0.3, 1.045, -1.05), 0.2, 3)
	Interior.mug(g2, Vector3(sx2 + 2.1, 1.045, -1.3), "3a5a8a")
	# regały za ladą: towar stoi rzędami w przegródkach
	var cols := ["a16207", "15803d", "1d4ed8", "be123c", "d9d4c8", "c2410c", "7c3aed", "0f766e"]
	for k in range(4):
		var shx := sx2 - 3.3 + k * 2.2
		_rp(g2, "wooden_display_shelves_01", shx, -d2 * 0.5 + 0.3, PI / 2.0, 1.9)
		for row in range(1, 3):
			for cell in range(3):
				var cxs := shx + (cell - 1) * 0.438
				var y0 := 0.03 + row * 0.633
				var kind := (k * 7 + row * 3 + cell) % 4
				var n_items := 3 if kind != 3 else 2
				for i in range(n_items):
					var px := cxs - 0.12 + i * (0.24 / maxi(1, n_items - 1))
					var col: String = cols[(k + row * 2 + cell + i) % cols.size()]
					if kind == 0:
						Models.box(g2, Vector3(0.1, 0.22 + (i % 2) * 0.05, 0.18), Vector3(px, y0 + 0.11 + (i % 2) * 0.025, -d2 * 0.5 + 0.32), Models.mat(col, 0.8), Vector3.ZERO, false)
					elif kind == 1:
						Models.cyl(g2, 0.04, 0.04, 0.16, Vector3(px, y0 + 0.08, -d2 * 0.5 + 0.36), Models.mat(col, 0.35, 0.6), Vector3.ZERO, 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						Models.cyl(g2, 0.04, 0.04, 0.16, Vector3(px, y0 + 0.08, -d2 * 0.5 + 0.26), Models.mat(col, 0.35, 0.6), Vector3.ZERO, 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					elif kind == 2:
						Interior.bottle(g2, Vector3(px, y0, -d2 * 0.5 + 0.32), ["3a6a3a", "5a3414", "c9c4b6"][i % 3])
					else:
						Models.box(g2, Vector3(0.17, 0.12, 0.2), Vector3(px, y0 + 0.06, -d2 * 0.5 + 0.32), Models.mat(col, 0.85), Vector3(0, 0.1 * i, 0), false)
						Models.box(g2, Vector3(0.17, 0.12, 0.2), Vector3(px, y0 + 0.182, -d2 * 0.5 + 0.32), Models.mat(cols[(k + cell + i + 3) % cols.size()], 0.85), Vector3(0, -0.08 * i, 0), false)
	add_col(sx2 - 4.4, sx2 + 4.4, -d2 * 0.5, -d2 * 0.5 + 0.6, 2.0, true, -1.0)
	rects.pop_back()
	# stojak z papierosami i tablica z cenami nad ladą
	Models.box(g2, Vector3(1.6, 0.6, 0.12), Vector3(sx2 + 1.5, 2.25, -d2 * 0.5 + 0.08), Models.mat("2a2c30", 0.6), Vector3.ZERO, false)
	for k in range(24):
		Models.box(g2, Vector3(0.055, 0.085, 0.02), Vector3(sx2 + 0.78 + (k % 12) * 0.13, 2.12 + int(k / 12.0) * 0.26, -d2 * 0.5 + 0.15), Models.mat(["d9d4c8", "b0382c", "1d4ed8", "e8c22a"][k % 4], 0.6), Vector3.ZERO, false)
	# chłodziarka z napojami pod zachodnią ścianą
	var fx := sx2 - w2 * 0.5 + 0.42
	Models.box(g2, Vector3(0.7, 1.95, 1.2), Vector3(fx, 0.975, 1.2), Models.mat("d8d8d4", 0.4, 0.2))
	Models.box(g2, Vector3(0.03, 1.6, 1.08), Vector3(fx + 0.35, 0.95, 1.2), Models.mat("bfe0ee", 0.08, 0.0, 0.35, 0.3), Vector3.ZERO, false)
	Models.box(g2, Vector3(0.6, 0.22, 1.16), Vector3(fx + 0.02, 1.82, 1.2), Models.mat("c8322a", 0.5, 0.0, 0.6), Vector3.ZERO, false)
	for sy in range(4):
		Models.box(g2, Vector3(0.56, 0.015, 1.06), Vector3(fx, 0.22 + sy * 0.38, 1.2), Models.mat("9aa0a6", 0.4, 0.6), Vector3.ZERO, false)
		for k in range(7):
			Interior.bottle(g2, Vector3(fx + 0.12, 0.228 + sy * 0.38, 0.75 + k * 0.15), ["3a6a3a", "c8322a", "e8a22a", "2a6ac8"][(k + sy) % 4])
	var cool := _room_light(g2, fx + 0.5, 1.2, 1.6, 0.5, Color(0.75, 0.9, 1.0), 2.4)
	cool.shadow_enabled = false
	add_col(fx - 0.38, fx + 0.38, 0.58, 1.82, 2.0, true, -1.0)
	rects.pop_back()
	# skrzynki, kartony, wycieraczka, stojak z gazetami
	_rp(g2, "plastic_crate_01", sx2 - 3.6, 2.6, 0.3, 0.28, 0.0, 0.3, 0.3)
	_rp(g2, "plastic_crate_01", sx2 - 3.6, 2.6, 0.7, 0.28, 0.28)
	_rp(g2, "plastic_crate_01", sx2 - 2.95, 2.75, 1.1, 0.28)
	_rp(g2, "cardboard_box_01", sx2 + 3.6, 2.2, 0.2, 0.4, 0.0, 0.3, 0.3)
	_rp(g2, "cardboard_box_01", sx2 + 3.5, 1.5, 1.4, 0.34)
	_rp(g2, "plastic_container", sx2 + 3.7, -0.4, PI / 2.0, 0.42, 0.0, 0.35, 0.5)
	Models.box(g2, Vector3(1.3, 0.014, 0.7), Vector3(sx2, 0.008, d2 * 0.5 - 0.55), Models.mat("2f3a2f", 0.95), Vector3.ZERO, false)
	Models.box(g2, Vector3(0.5, 0.9, 0.3), Vector3(sx2 + 1.5, 0.45, d2 * 0.5 - 0.25), Models.mat("3a3d42", 0.6, 0.4))
	Interior.papers(g2, Vector3(sx2 + 1.45, 0.9, d2 * 0.5 - 0.27), 0.1, 4)
	# reklamy i ogłoszenia na ścianach
	Interior.picture(g2, Vector3(sx2 + w2 * 0.5 - 0.01, 1.7, 0.6), -PI / 2.0, 0.9, "poster_01")
	Interior.picture(g2, Vector3(sx2 + w2 * 0.5 - 0.01, 1.75, 1.6), -PI / 2.0, 0.7, "poster_07")
	Interior.picture(g2, Vector3(sx2 + w2 * 0.5 - 0.01, 1.6, -0.6), -PI / 2.0, 0.8, "poster_12")
	Interior.picture(g2, Vector3(sx2 - w2 * 0.5 + 0.01, 1.75, -0.6), PI / 2.0, 0.8, "poster_04")
	Interior.picture(g2, Vector3(sx2 - 1.6, 1.7, d2 * 0.5 - 0.01), PI, 0.7, "poster_10")
	Interior.note(g2, Vector3(sx2 + 1.3, 1.5, d2 * 0.5 - 0.01), PI, "NA KRESKĘ NIE DAJEMY\n(chyba że Kubie)", 0.4, 0.26, "f2e8a8")
	windows.append(Interior.window(g2, Vector3(sx2 + 2.9, 1.55, d2 * 0.5), 1.6, 1.3, "n", "blinds", false))
	var win_n: Node3D = g2.get_child(g2.get_child_count() - 1)
	win_n.rotation.y = PI
	var ns := Label3D.new()
	ns.text = "STAŚ'S — EVERYTHING YOU NEED"
	ns.font_size = 40
	ns.pixel_size = 0.005
	ns.modulate = Color(0.25, 0.5, 0.3)
	ns.position = Vector3(sx2 - 1.2, h2 - 0.32, -d2 * 0.5 + 0.03)
	g2.add_child(ns)

	# ---------------- GARAŻ ----------------
	# Detale tylko na ścianach i suficie — podłoga zostaje wolna na meble gracza.
	var R3: Dictionary = D.ROOMS.garage
	var g3 := _room("garage", "garage_floor", "concrete_wall_008", "5a5a58", Color(0.75, 0.75, 0.72), 0.5)
	var c3: float = R3.cx
	_room_light(g3, c3, 0.0, R3.h, 1.2, Color(1.0, 0.85, 0.6), 9.0)
	Interior.ceiling_lamp(g3, Vector3(c3, R3.h, 0.0), "bulb")
	Interior.ceiling_lamp(g3, Vector3(c3, R3.h, -3.0), "tube", Color(0.9, 0.95, 1.0))
	var tl3 := _room_light(g3, c3, -3.0, R3.h, 0.7, Color(0.85, 0.92, 1.0), 6.0)
	tl3.shadow_enabled = false
	Interior.pegboard(g3, Vector3(c3 + R3.w * 0.5 - 0.01, 1.55, -1.2), -PI / 2.0, 1.6, 0.9)
	Interior.picture(g3, Vector3(c3 - R3.w * 0.5 + 0.01, 1.6, 1.4), PI / 2.0, 0.8, "pic_auto")
	Interior.picture(g3, Vector3(c3 - R3.w * 0.5 + 0.01, 1.7, 2.3), PI / 2.0, 0.55, "pic_kalendarz")
	Interior.note(g3, Vector3(c3 + R3.w * 0.5 - 0.01, 1.5, 1.6), -PI / 2.0, "OLEJ 5W40 — 3 l\nKLOCKI PRZÓD\nODDAĆ KLUCZ 13", 0.3, 0.36)
	Interior.pipe(g3, Vector3(c3 - R3.w * 0.5 + 0.12, R3.h - 0.18, -R3.d * 0.5 + 0.1), Vector3(c3 - R3.w * 0.5 + 0.12, R3.h - 0.18, R3.d * 0.5 - 0.1), 0.035, "6a6a66", 0.5)
	Interior.pipe(g3, Vector3(c3 - R3.w * 0.5 + 0.12, 0.0, -R3.d * 0.5 + 0.12), Vector3(c3 - R3.w * 0.5 + 0.12, R3.h - 0.18, -R3.d * 0.5 + 0.12), 0.035, "6a6a66", 0.5)
	Interior.pipe(g3, Vector3(c3 - 1.0, R3.h - 0.08, -R3.d * 0.5 + 0.2), Vector3(c3 + R3.w * 0.5 - 0.1, R3.h - 0.08, -R3.d * 0.5 + 0.2), 0.02, "1a1a1a", 0.0)
	_rp(g3, "power_box_01", c3 + R3.w * 0.5 - 0.1, 3.1, -PI / 2.0, 0.5, 1.2)
	_rp(g3, "old_tyre", c3 - R3.w * 0.5 + 0.4, -R3.d * 0.5 + 0.4, 0.0, 0.16)
	_rp(g3, "old_tyre", c3 - R3.w * 0.5 + 0.42, -R3.d * 0.5 + 0.42, 0.6, 0.16, 0.16)
	_rp(g3, "old_tyre", c3 - R3.w * 0.5 + 0.4, -R3.d * 0.5 + 0.4, 1.3, 0.16, 0.32)
	Interior.stain(g3, Vector3(c3 + 0.4, 0.004, 0.8), Vector3(-PI / 2.0, 0, 0), Vector2(1.8, 1.3), Color(0.03, 0.03, 0.03, 0.55))
	Interior.stain(g3, Vector3(c3 - 0.9, 0.004, -1.6), Vector3(-PI / 2.0, 0, 0), Vector2(0.9, 0.7), Color(0.03, 0.03, 0.03, 0.45))
	Interior.stain(g3, Vector3(c3 + R3.w * 0.5 - 0.012, 0.6, 3.2), Vector3(0, -PI / 2.0, 0), Vector2(1.6, 1.2), Color(0.1, 0.09, 0.07, 0.35))
	Interior.stain(g3, Vector3(c3 - 1.6, R3.h - 0.012, 2.4), Vector3(PI / 2.0, 0, 0), Vector2(1.8, 1.4), Color(0.12, 0.1, 0.07, 0.35))

	# ---------------- PIWNICA ----------------
	var R4: Dictionary = D.ROOMS.basement
	var g4 := _room("basement", "concrete_floor_worn_001", "brick_wall_10", "4a4744", Color(0.8, 0.75, 0.72), 0.5)
	var c4: float = R4.cx
	_room_light(g4, c4 - 2.0, -1.5, R4.h, 1.9, Color(1.0, 0.8, 0.55), 9.5)
	_room_light(g4, c4 + 2.0, 2.0, R4.h, 1.7, Color(1.0, 0.8, 0.55), 9.5)
	Interior.ceiling_lamp(g4, Vector3(c4 - 2.0, R4.h, -1.5), "bulb")
	Interior.ceiling_lamp(g4, Vector3(c4 + 2.0, R4.h, 2.0), "bulb")
	Models.cyl(g4, 0.06, 0.06, R4.w, Vector3(c4, R4.h - 0.2, -R4.d * 0.5 + 0.5), Props.pbr("rusty_painted_metal", 0.5), Vector3(0, 0, PI / 2.0), 8)
	Models.cyl(g4, 0.04, 0.04, R4.d, Vector3(c4 + R4.w * 0.5 - 0.3, R4.h - 0.3, 0), Props.pbr("rusty_painted_metal", 0.5), Vector3(PI / 2.0, 0, 0), 8)
	Interior.pipe(g4, Vector3(c4 - R4.w * 0.5 + 0.14, 0.0, 3.0), Vector3(c4 - R4.w * 0.5 + 0.14, R4.h, 3.0), 0.07, "5a4a3a", 0.5)
	Interior.pipe(g4, Vector3(c4 - R4.w * 0.5 + 0.14, 0.0, 3.4), Vector3(c4 - R4.w * 0.5 + 0.14, R4.h, 3.4), 0.045, "6a3a2a", 0.5)
	Interior.pipe(g4, Vector3(c4 - R4.w * 0.5 + 0.1, R4.h - 0.5, -R4.d * 0.5 + 0.1), Vector3(c4 - R4.w * 0.5 + 0.1, R4.h - 0.5, R4.d * 0.5 - 0.1), 0.03, "8a8a86", 0.6)
	_rp(g4, "power_box_01", c4 + R4.w * 0.5 - 0.1, -3.2, -PI / 2.0, 0.6, 1.1)
	_rp(g4, "utility_box_01", c4 - 2.6, -R4.d * 0.5 + 0.1, 0.0, 0.5, 1.2)
	# piwniczne okienko z kratą: w dzień wpada przez nie smuga światła
	var bw: Dictionary = Interior.window(g4, Vector3(c4 + 2.4, R4.h - 0.42, -R4.d * 0.5), 0.9, 0.42, "n", "none", false)
	bw.base = 1.6
	windows.append(bw)
	for k in range(5):
		Models.cyl(g4, 0.012, 0.012, 0.5, Vector3(c4 + 2.04 + k * 0.18, R4.h - 0.42, -R4.d * 0.5 + 0.1), Models.mat("2a2c30", 0.5, 0.6), Vector3.ZERO, 5)
	Interior.stain(g4, Vector3(c4 + 1.2, 0.004, -2.6), Vector3(-PI / 2.0, 0, 0), Vector2(2.2, 1.5), Color(0.04, 0.05, 0.06, 0.5))
	Interior.stain(g4, Vector3(c4 - 2.8, 0.004, 2.2), Vector3(-PI / 2.0, 0, 0), Vector2(1.4, 1.1), Color(0.04, 0.05, 0.06, 0.4))
	Interior.stain(g4, Vector3(c4 - R4.w * 0.5 + 0.012, 0.7, -1.0), Vector3(0, PI / 2.0, 0), Vector2(2.2, 1.4), Color(0.05, 0.07, 0.05, 0.4))
	Interior.stain(g4, Vector3(c4, 0.9, R4.d * 0.5 - 0.012), Vector3(0, PI, 0), Vector2(2.6, 1.6), Color(0.05, 0.07, 0.05, 0.35))
	Interior.note(g4, Vector3(c4 + R4.w * 0.5 - 0.01, 1.4, 1.2), -PI / 2.0, "PIWNICA NR 4\nNIE ZASTAWIAĆ ZAWORU", 0.36, 0.22)
	_lab_room()
	_hospital_room()
	_station_room()
	_club_room()
	_clothes_room()
	for id in ["garage", "basement"]:
		var fg := Node3D.new()
		rooms[id].add_child(fg)
		furn[id] = fg
		var fb := StaticBody3D.new()
		rooms[id].add_child(fb)
		furn_body[id] = fb
		inter_dyn[id] = []


## „TANIA ODZIEŻ”: lumpeks przy Hutniczej. Wieszaki, kosze „wszystko po 5 zł”, przymierzalnia z lustrem.
func _clothes_room() -> void:
	var R: Dictionary = D.ROOMS.ciuchy
	var cx: float = R.cx
	var w: float = R.w
	var d: float = R.d
	var h: float = R.h
	var g := _room("ciuchy", "old_wood_floor", "peeling_painted_wall", "d8d2c4", Color(0.92, 0.88, 0.8), 0.6)
	Interior.baseboards(g, cx, w, d, "7a6a52", 0.1)
	for lx in [-1.9, 1.9]:
		Interior.ceiling_lamp(g, Vector3(cx + lx, h, 0.2), "tube", Color(1.0, 0.96, 0.88))
	_room_light(g, cx - 1.9, 0.2, h, 1.35, Color(1.0, 0.95, 0.85), 8.0)
	_room_light(g, cx + 1.9, 0.2, h, 1.2, Color(1.0, 0.95, 0.85), 8.0).shadow_enabled = false
	var steel := Models.mat("8a8f96", 0.35, 0.8)
	var cloth_cols := ["8a2a2a", "2a4a6a", "3a5a3a", "c9a23a", "1c1c20", "d9d4c8", "6a3a5a", "4a4a52", "b0582c", "2f6a6a", "e8e2d0", "5a4630"]
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 3107
	# trzy wieszaki z ubraniami
	for e in [[-2.3, -1.2, 0.0], [0.2, -1.2, 0.0], [-1.0, 1.0, 0.0]]:
		var rx: float = cx + e[0]
		var rz: float = e[1]
		var rl := 2.0
		for sx in [-1.0, 1.0]:
			Models.cyl(g, 0.02, 0.02, 1.6, Vector3(rx + sx * rl * 0.5, 0.8, rz), steel, Vector3.ZERO, 6)
			Models.box(g, Vector3(0.05, 0.03, 0.5), Vector3(rx + sx * rl * 0.5, 0.015, rz), steel, Vector3.ZERO, false)
		Models.cyl(g, 0.016, 0.016, rl, Vector3(rx, 1.58, rz), steel, Vector3(0, 0, PI / 2.0), 6)
		var x := -rl * 0.5 + 0.1
		while x < rl * 0.5 - 0.08:
			var col: String = cloth_cols[rng2.randi() % cloth_cols.size()]
			var len := rng2.randf_range(0.55, 1.05)
			var wd := rng2.randf_range(0.36, 0.48)
			# wieszak z haczykiem i wiszący ciuch
			Models.box(g, Vector3(0.012, 0.02, wd), Vector3(rx + x, 1.5, rz), Models.mat("3a3027", 0.7), Vector3.ZERO, false)
			Models.box(g, Vector3(0.035, len, wd), Vector3(rx + x, 1.49 - len * 0.5, rz), Models.mat(col, 0.95), Vector3(0, rng2.randf_range(-0.12, 0.12), 0))
			if rng2.randf() < 0.4:
				Models.box(g, Vector3(0.03, len * 0.75, 0.1), Vector3(rx + x, 1.42 - len * 0.4, rz + wd * 0.5 + 0.04), Models.mat(col, 0.95), Vector3(0.12, 0, 0), false)
				Models.box(g, Vector3(0.03, len * 0.75, 0.1), Vector3(rx + x, 1.42 - len * 0.4, rz - wd * 0.5 - 0.04), Models.mat(col, 0.95), Vector3(-0.12, 0, 0), false)
			x += rng2.randf_range(0.07, 0.12)
		add_col(rx - rl * 0.5 - 0.05, rx + rl * 0.5 + 0.05, rz - 0.3, rz + 0.3, 1.2, true, -1.0)
		rects.pop_back()
	# regał ze złożonymi ubraniami pod zachodnią ścianą
	for sz in [-1.9, -0.7]:
		_rp(g, "wooden_display_shelves_01", cx - w * 0.5 + 0.26, sz, 0.0, 1.9)
		for row in range(3):
			for cell in range(3):
				var py := 0.04 + row * 0.633
				var pz: float = sz + (cell - 1) * 0.438
				for k in range(rng2.randi_range(1, 4)):
					Models.box(g, Vector3(0.3, 0.07, 0.34), Vector3(cx - w * 0.5 + 0.27, py + 0.035 + k * 0.072, pz), Models.mat(cloth_cols[rng2.randi() % cloth_cols.size()], 0.95), Vector3(0, rng2.randf_range(-0.08, 0.08), 0), false)
	add_col(cx - w * 0.5, cx - w * 0.5 + 0.5, -2.6, 0.0, 2.0, true, -1.0)
	rects.pop_back()
	# kosze „wszystko po 5 zł”
	for e in [[1.9, 1.5], [2.7, 1.9]]:
		var bx: float = cx + e[0]
		Models.box(g, Vector3(0.8, 0.5, 0.6), Vector3(bx, 0.25, e[1]), Models.mat("a88a5e", 0.95))
		for k in range(9):
			Models.box(g, Vector3(rng2.randf_range(0.2, 0.4), 0.08, rng2.randf_range(0.2, 0.34)), Vector3(bx + rng2.randf_range(-0.2, 0.2), 0.52 + rng2.randf() * 0.1, e[1] + rng2.randf_range(-0.14, 0.14)), Models.mat(cloth_cols[rng2.randi() % cloth_cols.size()], 0.95), Vector3(rng2.randf_range(-0.3, 0.3), rng2.randf() * 3.0, rng2.randf_range(-0.3, 0.3)), false)
		add_col(bx - 0.42, bx + 0.42, e[1] - 0.32, e[1] + 0.32, 1.0, true, -1.0)
		rects.pop_back()
	Interior.note(g, Vector3(cx + 2.3, 1.25, d * 0.5 - 0.01), PI, "WSZYSTKO Z KOSZA\nPO 5 ZŁ", 0.5, 0.3, "f2e24a")
	# lada z kasą
	var lx := cx + w * 0.5 - 1.3
	Models.box(g, Vector3(1.9, 0.95, 0.6), Vector3(lx, 0.475, -d * 0.5 + 1.25), Props.pbr("old_wood_floor", 0.6, Color(0.62, 0.5, 0.4)))
	Models.box(g, Vector3(2.0, 0.04, 0.7), Vector3(lx, 0.97, -d * 0.5 + 1.25), Models.mat("3a3027", 0.6))
	_rp(g, "cashregister_01", lx + 0.5, -d * 0.5 + 1.25, PI, 0.42, 0.99)
	Interior.mug(g, Vector3(lx - 0.6, 0.99, -d * 0.5 + 1.15), "c85a8a")
	add_col(lx - 1.0, lx + 1.0, -d * 0.5 + 0.9, -d * 0.5 + 1.6, 1.1, true, -1.0)
	rects.pop_back()
	# przymierzalnia w rogu: zasłonka i lustro
	var bx2 := cx + w * 0.5 - 0.75
	var bz2 := d * 0.5 - 0.9
	Models.cyl(g, 0.014, 0.014, 1.4, Vector3(bx2 - 0.02, 2.1, bz2 - 0.85), steel, Vector3(0, 0, PI / 2.0), 6)
	for k in range(6):
		Models.box(g, Vector3(0.2, 1.95, 0.03), Vector3(bx2 - 0.62 + k * 0.2, 1.1, bz2 - 0.85 + (0.02 if k % 2 == 0 else -0.02)), Models.mat("7a2a4a", 0.95), Vector3(0, 0.3 if k % 2 == 0 else -0.3, 0))
	var mirror := StandardMaterial3D.new()
	mirror.albedo_color = Color(0.62, 0.7, 0.76)
	mirror.metallic = 0.55
	mirror.roughness = 0.12
	mirror.emission_enabled = true
	mirror.emission = Color(0.5, 0.58, 0.66)
	mirror.emission_energy_multiplier = 0.22
	var mz := 1.6
	Models.box(g, Vector3(0.03, 1.7, 0.7), Vector3(cx - w * 0.5 + 0.03, 1.1, mz), mirror, Vector3.ZERO, false)
	for e in [[0.0, 0.875, 0.76, 0.05], [0.0, -0.875, 0.76, 0.05]]:
		Models.box(g, Vector3(0.05, e[3], e[2]), Vector3(cx - w * 0.5 + 0.04, 1.1 + e[1], mz), Models.mat("5a4326", 0.6), Vector3.ZERO, false)
	for sz2 in [-0.375, 0.375]:
		Models.box(g, Vector3(0.05, 1.8, 0.05), Vector3(cx - w * 0.5 + 0.04, 1.1, mz + sz2), Models.mat("5a4326", 0.6), Vector3.ZERO, false)
	inter.append({"loc": "ciuchy", "x": cx - w * 0.5 + 0.1, "z": mz, "y0": 0.3, "y1": 1.9, "r": 0.7, "reach": 2.8, "id": "mirror",
		"label": func(): return "Lustro — przymierz i kup ubrania", "act": func(): G.ui.open_inventory("", "wear")})
	# plakaty, okno wystawowe, manekin z kapeluszem
	Interior.picture(g, Vector3(cx - 1.4, 1.75, -d * 0.5 + 0.01), 0.0, 0.8, "pic_boks")
	Interior.picture(g, Vector3(cx + 0.2, 1.8, -d * 0.5 + 0.01), 0.0, 0.6, "pic_kalendarz", "5a4326")
	Interior.note(g, Vector3(cx + 3.2, 1.7, -d * 0.5 + 0.01), 0.0, "ZWROTÓW NIE PRZYJMUJEMY\nPRZYMIERZALNIA ZA ZASŁONKĄ", 0.5, 0.26)
	var wn: Dictionary = Interior.window(g, Vector3(cx - 2.2, 1.6, d * 0.5), 1.8, 1.3, "n", "sheer", false)
	g.get_child(g.get_child_count() - 1).rotation.y = PI
	windows.append(wn)
	Interior.shoes(g, Vector3(cx + 0.9, 0.0, 2.6), 0.4, "5a3a1a")
	Interior.shoes(g, Vector3(cx + 1.3, 0.0, 2.7), -0.3, "1c1c20")
	Interior.shoes(g, Vector3(cx + 0.5, 0.0, 2.75), 0.1, "d8d4c8")
	Interior.stain(g, Vector3(cx + 1.2, h - 0.012, -1.4), Vector3(PI / 2.0, 0, 0), Vector2(1.5, 1.1), Color(0.3, 0.24, 0.14, 0.25))


## LABORATORIUM W STAREJ HUCIE (prolog): hala z rzędami regałów pod fioletowymi LED-ami,
## stołami do syntezy i paletą gotowych cegieł. Po prologu nie da się tu już wejść.
## model z Blendera ustawiony w pokoju (z opcjonalnym pudełkiem kolizji: połowa szerokości i głębokości)
func _lm(g: Node3D, name: String, x: float, z: float, ry := 0.0, y := 0.0, col := Vector2.ZERO) -> Node3D:
	var n: Node3D = Stations.model(name)
	if n == null:
		n = Node3D.new()
	n.position = Vector3(x, y, z)
	n.rotation.y = ry
	g.add_child(n)
	if col.x > 0.0:
		add_col(x - col.x, x + col.x, z - col.y, z + col.y, 1.2, true, -1.0)
		rects.pop_back()
	return n


## Laboratorium w Starej Hucie (prolog): linia syntezy pod wschodnią ścianą, reaktor, suszarnia i prasa,
## magazyn chemii, stół do pakowania pośrodku. Ciemna hala oświetlona lampami roboczymi; na ścianach ładunki.
# ---------------- SZPITAL: sala, na której budzisz się po pobiciu albo postrzale ----------------
func _hospital_room() -> void:
	var R: Dictionary = D.ROOMS.szpital
	var cx: float = R.cx
	var w: float = R.w
	var d: float = R.d
	var h: float = R.h
	var g := _room("szpital", "dirty_tiles", "beige_wall_001", "e4e6e2", Color(0.82, 0.92, 0.86), 0.6)
	Interior.baseboards(g, cx, w, d, "9fb4a8")
	# lamperia: pas olejnej farby do wysokości 1,3 m
	var lam := Models.mat("7fa89a", 0.5)
	Models.box(g, Vector3(w, 1.3, 0.012), Vector3(cx, 0.65, -d * 0.5 + 0.006), lam, Vector3.ZERO, false)
	Models.box(g, Vector3(0.012, 1.3, d), Vector3(cx - w * 0.5 + 0.006, 0.65, 0), lam, Vector3.ZERO, false)
	Models.box(g, Vector3(0.012, 1.3, d), Vector3(cx + w * 0.5 - 0.006, 0.65, 0), lam, Vector3.ZERO, false)
	for lx in [-1.9, 1.9]:
		Interior.ceiling_lamp(g, Vector3(cx + lx, h, 0.0), "tube", Color(0.9, 0.97, 1.0))
		var li := _room_light(g, cx + lx, 0.0, h - 0.15, 1.15, Color(0.86, 0.95, 1.0), 8.0)
		li.shadow_enabled = lx < 0.0
	var bz := -d * 0.5 + 1.1
	for k in range(3):
		var bx := cx + (k - 1) * 2.5
		_lm(g, "szp_lozko", bx, bz, 0.0, 0.0, Vector2(0.5, 1.05))
		_lm(g, "szp_szafka", bx + 0.78, -d * 0.5 + 0.3, 0.0, 0.0, Vector2(0.24, 0.22))
		if k < 2:
			var pw := _lm(g, "szp_parawan", bx + 1.25, bz + 0.2, PI / 2.0, 0.0, Vector2(0.06, 0.85))
			Interior._tint(pw, Color(0.72, 0.86, 0.82))
	# środkowe łóżko jest Twoje: kroplówka i monitor
	_lm(g, "szp_stojak", cx - 0.72, -d * 0.5 + 0.5, 0.6)
	_lm(g, "szp_monitor", cx - 0.75, -d * 0.5 + 1.5, PI * 0.6)
	var ml := _room_light(g, cx - 0.6, -d * 0.5 + 1.4, 1.2, 0.25, Color(0.4, 1.0, 0.55), 1.8)
	ml.shadow_enabled = false
	_lm(g, "szp_umywalka", cx + w * 0.5, 1.4, -PI / 2.0)
	_lm(g, "kom_lawka", cx - 2.2, d * 0.5 - 0.35, PI, 0.0, Vector2(0.9, 0.3))
	_rp(g, "wall_clock", cx, d * 0.5 - 0.04, PI, 0.3, 2.25)
	Interior.note(g, Vector3(cx - w * 0.5 + 0.01, 1.7, 1.2), PI / 2.0, "VISITING HOURS\n15:00 – 18:00", 0.42, 0.3)
	for wx in [-2.5, 2.5]:
		windows.append(Interior.window(g, Vector3(cx + wx, 1.85, -d * 0.5), 1.2, 0.9, "n", "blinds", false))
	wake["szpital"] = [Vector3(cx + 0.05, 0.0, -d * 0.5 + 2.75), PI]


# ---------------- KOMENDA: cela, z której wychodzisz po zatrzymaniu ----------------
func _station_room() -> void:
	var R: Dictionary = D.ROOMS.komisariat
	var cx: float = R.cx
	var w: float = R.w
	var d: float = R.d
	var h: float = R.h
	var g := _room("komisariat", "concrete_floor_worn_001", "blue_plaster_weathered", "d0d2d0", Color(0.8, 0.84, 0.9), 0.6)
	Interior.baseboards(g, cx, w, d, "4a5560")
	for lx in [-2.0, 2.0]:
		Interior.ceiling_lamp(g, Vector3(cx + lx, h, 0.3), "tube", Color(0.85, 0.92, 1.0))
		var li := _room_light(g, cx + lx, 0.3, h - 0.15, 1.0, Color(0.82, 0.9, 1.0), 8.0)
		li.shadow_enabled = lx < 0.0
	# cela w północno-zachodnim rogu: krata od południa, ściana od wschodu
	var x0 := cx - w * 0.5
	var kz := -d * 0.5 + 2.5
	var kr := _lm(g, "kom_krata", x0 + 1.6, kz, 0.0)
	var leaf := Stations._find(kr, "Drzwi") as Node3D
	if leaf != null:
		# skrzydło uchylone na oścież: obrót wokół zawiasu (oś modelu jest w zawiasie)
		leaf.rotation.y = -1.9
	add_col(x0, x0 + 1.95, kz - 0.06, kz + 0.06, h, true, -1.0)
	rects.pop_back()
	add_col(x0 + 2.9, x0 + 3.2, kz - 0.06, kz + 0.06, h, true, -1.0)
	rects.pop_back()
	Models.box(g, Vector3(0.14, h, 2.5), Vector3(x0 + 3.27, h * 0.5, -d * 0.5 + 1.25), Props.pbr("concrete_wall_008", 0.5, Color(0.7, 0.74, 0.8)))
	add_col(x0 + 3.2, x0 + 3.34, -d * 0.5, kz + 0.06, h, true, -1.0)
	rects.pop_back()
	_lm(g, "kom_prycza", x0, -d * 0.5 + 1.2, PI / 2.0, 0.0, Vector2(0.34, 0.95))
	Models.cyl(g, 0.16, 0.13, 0.3, Vector3(x0 + 2.8, 0.15, -d * 0.5 + 0.35), Models.mat("6a6e72", 0.4, 0.7), Vector3.ZERO, 12)
	# dyżurka: biurko, szafki depozytowe, tablica z listami gończymi, ławka dla czekających
	_lm(g, "kom_biurko", cx + 1.9, -d * 0.5 + 1.5, PI, 0.0, Vector2(0.82, 0.4))
	_lm(g, "kom_tablica", cx + 1.9, -d * 0.5, 0.0, 1.65)
	_lm(g, "kom_szafa", cx + w * 0.5 - 0.27, 1.3, -PI / 2.0, 0.0, Vector2(0.27, 0.56))
	_lm(g, "kom_lawka", cx - 2.4, d * 0.5 - 0.35, PI, 0.0, Vector2(0.9, 0.3))
	_rp(g, "wall_clock", cx + 3.4, -d * 0.5 + 0.04, 0.0, 0.3, 2.2)
	Interior.note(g, Vector3(cx + w * 0.5 - 0.01, 1.7, -1.2), -PI / 2.0, "NO SMOKING\nNO PHONES IN CELLS", 0.42, 0.3)
	wake["komisariat"] = [Vector3(x0 + 1.5, 0.0, -d * 0.5 + 1.3), PI * 1.15]


# ---------------- KLUB NEON: parkiet, bar, DJ, loże ----------------
const SH_DANCE := """shader_type spatial;
uniform float bpm = 124.0;
void fragment() {
	vec2 uv = UV * vec2(8.0, 6.0);
	vec2 id = floor(uv);
	vec2 f = fract(uv);
	float beat = floor(TIME * bpm / 120.0);
	float hh = fract(sin(dot(id + beat * 0.37, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 col = mix(vec3(1.0, 0.1, 0.7), vec3(0.1, 0.8, 1.0), step(0.5, hh));
	col = mix(col, vec3(0.55, 0.2, 1.0), step(0.8, hh));
	float on = step(0.4, fract(hh * 7.0));
	float edge = smoothstep(0.0, 0.05, f.x) * smoothstep(0.0, 0.05, f.y) * smoothstep(0.0, 0.05, 1.0 - f.x) * smoothstep(0.0, 0.05, 1.0 - f.y);
	float pulse = 0.65 + 0.35 * (1.0 - fract(TIME * bpm / 60.0));
	ALBEDO = vec3(0.03);
	ROUGHNESS = 0.2;
	METALLIC = 0.3;
	EMISSION = col * on * edge * pulse * 1.3 + vec3(0.02) * edge;
}
"""


func _club_room() -> void:
	var R: Dictionary = D.ROOMS.club
	var cx: float = R.cx
	var w: float = R.w
	var d: float = R.d
	var h: float = R.h
	var g := _room("club", "concrete_floor_worn_001", "concrete_wall_008", "08080b", Color(0.2, 0.17, 0.26), 0.5)
	# bramka z wykrywaczem tuż za drzwiami
	_lm(g, "klub_bramka", cx, d * 0.5 - 2.4, 0.0)
	for sx in [-1.0, 1.0]:
		add_col(cx + sx * 0.44 - 0.08, cx + sx * 0.44 + 0.08, d * 0.5 - 2.7, d * 0.5 - 2.1, 2.0, true, -1.0)
		rects.pop_back()
	# parkiet z podświetlanych płyt
	var fx := cx - 2.2
	var fz := -1.2
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6.4, 4.8)
	floor_mi.mesh = pm
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SH_DANCE
	sm.shader = sh
	floor_mi.material_override = sm
	floor_mi.position = Vector3(fx, 0.012, fz)
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(floor_mi)
	Models.box(g, Vector3(6.6, 0.02, 5.0), Vector3(fx, 0.0, fz), Models.mat("101014", 0.4, 0.6), Vector3.ZERO, false)
	# kratownica z reflektorami i kula lustrzana nad parkietem
	for tz in [fz - 1.6, fz + 1.6]:
		for tx in [fx - 1.5, fx + 1.5]:
			var tr := _lm(g, "klub_krata", tx, tz, 0.0, h - 0.35)
			Props._no_shadow(tr)
	var k := 0
	for e in [[-2.2, -1.6], [2.2, -1.6], [-2.2, 1.6], [2.2, 1.6]]:
		var rf := _lm(g, "klub_reflektor", fx + e[0], fz + e[1], atan2(-e[0], -e[1]), h - 0.5)
		Props._no_shadow(rf)
		var sp := SpotLight3D.new()
		sp.position = Vector3(fx + e[0], h - 0.8, fz + e[1])
		sp.rotation.x = -PI / 2.0
		sp.spot_range = 9.0
		sp.spot_angle = 26.0
		sp.spot_angle_attenuation = 0.7
		sp.light_energy = 5.0
		sp.light_volumetric_fog_energy = 3.0
		sp.shadow_enabled = false
		sp.set_meta("i", k)
		g.add_child(sp)
		club_spots.append(sp)
		k += 1
	var ball := _lm(g, "klub_kula", fx, fz, 0.0, h)
	Props._no_shadow(ball)
	club_ball = Stations._find(ball, "Kula") as Node3D
	# DJ pod północną ścianą, kolumny po bokach
	_lm(g, "klub_dj", fx, -d * 0.5 + 1.15, 0.0, 0.0, Vector2(1.16, 0.42))
	for sx in [-2.2, 2.2]:
		_lm(g, "klub_glosnik", fx + sx, -d * 0.5 + 0.55, -sx * 0.12, 0.0, Vector2(0.38, 0.34))
	var djl := _room_light(g, fx, -d * 0.5 + 1.2, 2.0, 0.7, Color(1.0, 0.25, 0.8), 4.5)
	djl.shadow_enabled = false
	# bar pod wschodnią ścianą
	var bxr := cx + w * 0.5
	_lm(g, "klub_regal", bxr, -1.0, -PI / 2.0, 0.0, Vector2(0.22, 2.1))
	_lm(g, "klub_bar", bxr - 1.75, -1.0, -PI / 2.0, 0.0, Vector2(0.34, 2.15))
	for bz in [-2.5, -1.5, -0.5, 0.5]:
		_lm(g, "klub_stolek", bxr - 2.45, bz, 0.0, 0.0, Vector2(0.17, 0.17))
	for bz in [-2.0, 0.0]:
		var bl := _room_light(g, bxr - 1.0, bz, 2.3, 0.75, Color(1.0, 0.45, 0.75), 4.5)
		bl.shadow_enabled = false
	inter.append({"loc": "club", "x": bxr - 1.75, "z": -1.0, "y0": 0.8, "y1": 1.5, "r": 1.6, "reach": 2.8, "id": "club_bar",
		"label": func(): return "Bar — zamów coś", "act": func(): G.main.club_bar()})
	# loże pod zachodnią ścianą i wysokie stoliki
	var xw := cx - w * 0.5
	for lz in [-3.6, -0.9, 1.8]:
		_lm(g, "klub_kanapa", xw + 0.42, lz, PI / 2.0, 0.0, Vector2(0.4, 1.02))
		_lm(g, "klub_stolik", xw + 1.5, lz, lz, 0.0, Vector2(0.24, 0.24))
	for e in [[2.4, 2.4], [4.6, 3.4], [-4.2, 4.2]]:
		_lm(g, "klub_stolik", cx + e[0], e[1], e[0], 0.0, Vector2(0.24, 0.24))
	var ll := _room_light(g, xw + 1.4, -0.9, 2.4, 0.5, Color(0.5, 0.3, 1.0), 6.0)
	ll.shadow_enabled = false
	# neony na ścianach i tabliczki
	var sg := Signs.text("NEON", "bebas", 220, Color(1.0, 0.3, 0.85), 0.008, 10, Color(0, 0, 0, 0.6))
	sg.position = Vector3(fx, 3.1, -d * 0.5 + 0.03)
	sg.shaded = false
	g.add_child(sg)
	var s2 := Signs.text("BAR", "bebas", 120, Color(0.3, 0.95, 1.0), 0.008, 8, Color(0, 0, 0, 0.6))
	s2.position = Vector3(bxr - 0.5, 3.2, 1.7)
	s2.rotation.y = -PI / 2.0
	s2.shaded = false
	g.add_child(s2)
	var s3 := Signs.text("EXIT", "bebas", 60, Color(0.3, 1.0, 0.5), 0.006, 6, Color(0, 0, 0, 0.6))
	s3.position = Vector3(cx, 2.45, d * 0.5 - 0.03)
	s3.rotation.y = PI
	s3.shaded = false
	g.add_child(s3)
	var fill := _room_light(g, cx, 1.5, h - 0.3, 0.3, Color(0.45, 0.3, 0.9), 13.0)
	fill.shadow_enabled = false


## światła klubu: reflektory krążą po parkiecie i zmieniają barwę, kula się kręci
func club_lights(t: float) -> void:
	for sp in club_spots:
		var i := float(sp.get_meta("i"))
		sp.rotation.x = -PI / 2.0 + sin(t * 1.3 + i * 1.7) * 0.42
		sp.rotation.z = cos(t * 0.9 + i * 2.1) * 0.42
		sp.light_color = Color.from_hsv(fmod(t * 0.07 + i * 0.25, 1.0), 0.85, 1.0)
	if club_ball != null:
		club_ball.rotation.y = t * 0.6


func _lab_room() -> void:
	var R: Dictionary = D.ROOMS.lab
	var cx: float = R.cx
	var w: float = R.w
	var d: float = R.d
	var h: float = R.h
	var g := _room("lab", "concrete_floor_worn_001", "factory_brick", "262423", Color(0.6, 0.56, 0.54), 0.5)
	var steel := Models.mat("2b2e33", 0.45, 0.7)
	# dwie słabe, zimne świetlówki — resztę światła dają halogeny na statywach
	for e in [[-1.0, 2.6], [3.6, -1.4]]:
		Props._no_shadow(_rp(g, "mounted_fluorescent_lights", cx + e[0], e[1], PI / 2.0, 0.0, h - 0.1))
		var fl := _room_light(g, cx + e[0], e[1], h, 0.85, Color(0.72, 0.86, 1.0), 10.5)
		fl.shadow_enabled = false
	# stalowe belki, kanały wentylacyjne, wentylator w zachodniej ścianie
	for z in [-3.6, 0.0, 3.6]:
		Models.box(g, Vector3(w, 0.22, 0.16), Vector3(cx, h - 0.16, z), Props.pbr("rusty_painted_metal", 0.5, Color(0.5, 0.48, 0.46)))
	Models.cyl(g, 0.2, 0.2, w - 1.0, Vector3(cx, h - 0.55, -4.9), Models.mat("9da2a8", 0.4, 0.6), Vector3(0, 0, PI / 2.0), 12)
	Models.cyl(g, 0.16, 0.16, 6.0, Vector3(cx - 6.2, h - 0.55, -1.9), Models.mat("9da2a8", 0.4, 0.6), Vector3(PI / 2.0, 0, 0), 12)
	_lm(g, "lab_wentylator", cx - w * 0.5 + 0.2, 1.0, PI / 2.0, h - 1.35)
	# --- linia syntezy: trzy stoły pod wschodnią ścianą, na nich aparatura
	var bz := [-3.5, -1.3, 0.9]
	for k in range(3):
		_lm(g, "lab_stol", cx + 6.45, bz[k], -PI / 2.0, 0.0, Vector2(0.45, 1.02))
		if k < 2:
			_lm(g, "lab_aparatura", cx + 6.5, float(bz[k]) + (0.25 if k == 0 else -0.2), -PI / 2.0, 0.9)
			var gl := _room_light(g, cx + 6.1, float(bz[k]), 1.35, 0.35, Color(1.0, 0.72, 0.35) if k == 0 else Color(0.6, 1.0, 0.6), 2.4)
			gl.shadow_enabled = false
	# trzeci stół: waga, tace z proszkiem, zgrzewarka
	_scale_set(g, Vector3(cx + 6.45, 0.9, 0.5))
	for e in [[0.9, 0.0], [1.35, 0.4]]:
		Models.box(g, Vector3(0.34, 0.02, 0.26), Vector3(cx + 6.45, 0.91, e[0]), Models.mat("9aa0a6", 0.35, 0.8), Vector3(0, e[1], 0), false)
		Models.box(g, Vector3(0.3, 0.025, 0.22), Vector3(cx + 6.45, 0.925, e[0]), Models.mat("f4f4f0", 0.95), Vector3(0, e[1], 0), false)
	# reaktor z parą nad pokrywą i tablica z rachunkiem partii
	var rk := _lm(g, "lab_reaktor", cx + 3.9, -4.3, 2.6, 0.0, Vector2(0.62, 0.62))
	var steam := Props._particles(9, 3.2, 0.7, false, [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.09), Color(1, 1, 1, 0.0)], Vector2(0.25, 0.55), 0.12, true)
	steam.position = Vector3(-0.18, 2.02, 0.24)
	rk.add_child(steam)
	var rkl := _room_light(g, cx + 3.9, -3.5, 1.4, 0.5, Color(1.0, 0.82, 0.55), 3.0)
	rkl.shadow_enabled = false
	_lm(g, "lab_tablica", cx + 1.5, -5.05, 0.0, 0.0, Vector2(0.75, 0.25))
	# --- magazyn chemii w północno-zachodnim rogu
	_lm(g, "lab_ibc", cx - 6.1, -4.5, 0.0, 0.0, Vector2(0.55, 0.65))
	_lm(g, "lab_ibc", cx - 4.9, -4.55, 0.06, 0.0, Vector2(0.55, 0.65))
	for e in [[-3.5, -4.9, 0.3], [-2.9, -4.75, 1.4], [-3.2, -4.2, 2.2], [-6.4, -3.3, 0.9], [-5.8, -3.25, 2.9]]:
		_lm(g, "lab_beczka", cx + e[0], e[1], e[2], 0.0, Vector2(0.3, 0.3))
	_lm(g, "lab_kanistry", cx - 4.5, -3.5, 0.8)
	_lm(g, "lab_butle", cx - w * 0.5 + 0.22, -1.6, PI / 2.0, 0.0, Vector2(0.2, 0.35))
	_lm(g, "lab_butle", cx - w * 0.5 + 0.22, -0.7, PI / 2.0, 0.0, Vector2(0.2, 0.35))
	# --- suszarnia i prasa pod zachodnią ścianą
	for z in [2.3, 3.3]:
		_lm(g, "lab_suszarnia", cx - 6.4, z, PI / 2.0, 0.0, Vector2(0.36, 0.48))
	var heat := _room_light(g, cx - 6.0, 2.8, 1.6, 0.4, Color(1.0, 0.5, 0.2), 2.6)
	heat.shadow_enabled = false
	_lm(g, "lab_prasa", cx - 4.4, 4.5, PI, 0.0, Vector2(0.4, 0.3))
	var pal := Props.make("pallet", 0.16)
	pal.position = Vector3(cx - 2.9, 0.0, 4.6)
	g.add_child(pal)
	for i in range(3):
		var ps := Stations.brick_stack("snieg", 12)
		ps.position = Vector3(cx - 3.25 + i * 0.36, 0.16, 4.55 + (i % 2) * 0.1)
		ps.rotation.y = i * 0.3
		g.add_child(ps)
	add_col(cx - 3.5, cx - 2.3, 4.0, 5.2, 1.0, true, -1.0)
	rects.pop_back()
	# --- lampy robocze: trzy plamy ciepłego światła w ciemnej hali
	for e in [[-1.3, 0.6, -2.2, 1.6, 2.4], [2.4, -1.6, 0.9, 4.6, -3.4], [-3.6, 1.4, 2.4, -5.8, 3.0]]:
		_lm(g, "lab_lampa", cx + e[0], e[1], atan2(float(e[3]) - float(e[0]), float(e[4]) - float(e[1])) + PI)
		# światło startuje tuż przed szybą halogenu (inaczej głowica lampy rzuca cień na wszystko)
		var aim := Vector3(cx + float(e[3]), 0.6, float(e[4]))
		var head := Vector3(cx + e[0], 1.78, e[1])
		var sp := SpotLight3D.new()
		sp.position = head + (aim - head).normalized() * 0.32
		sp.light_color = Color(1.0, 0.86, 0.62)
		sp.light_energy = 9.0
		sp.spot_range = 11.0
		sp.spot_angle = 52.0
		sp.spot_angle_attenuation = 0.6
		sp.spot_attenuation = 0.7
		sp.shadow_enabled = true
		sp.light_volumetric_fog_energy = 1.5
		g.add_child(sp)
		sp.look_at_from_position(sp.position, aim, Vector3.UP)
		# odbite światło: miękka poświata wokół oświetlonego miejsca
		var bounce := _room_light(g, aim.x, aim.z, 1.3, 0.55, Color(1.0, 0.84, 0.62), 5.5)
		bounce.shadow_enabled = false
	# --- „zabezpieczenie”: ładunki na ścianach, czerwone diody widać z daleka
	for e in [[-w * 0.5 + 0.06, -2.6, PI / 2.0], [w * 0.5 - 0.06, 2.4, -PI / 2.0], [-2.4, -d * 0.5 + 0.06, 0.0], [4.6, d * 0.5 - 0.06, PI]]:
		_lm(g, "lab_ladunek", cx + e[0], e[1], e[2], 1.5)
		var rl := _room_light(g, cx + float(e[0]) * 0.97, float(e[1]) * 0.97, 1.5, 0.22, Color(1.0, 0.1, 0.05), 1.6)
		rl.shadow_enabled = false
	# --- pakowanie: stół z ostatnią partią i torbą
	var tx := cx + 1.6
	var tz := 2.4
	_lm(g, "lab_stol", tx, tz, PI, 0.0, Vector2(1.02, 0.45))
	_scale_set(g, Vector3(tx - 0.62, 0.9, tz))
	var st1 := Stations.brick_stack("snieg", 6)
	st1.position = Vector3(tx + 0.0, 0.9, tz - 0.1)
	g.add_child(st1)
	var st2 := Stations.brick_stack("snieg", 4)
	st2.position = Vector3(tx + 0.5, 0.9, tz + 0.05)
	st2.rotation.y = 0.5
	g.add_child(st2)
	var bag := Stations.duffel()
	bag.position = Vector3(tx - 0.1, 0.0, tz + 0.95)
	bag.rotation.y = 0.4
	g.add_child(bag)
	_rp(g, "hand_truck", cx + 4.9, 4.4, 2.2, 1.3)
	_rp(g, "cardboard_box_01", cx - 1.2, 4.8, 0.3, 0.4, 0.0, 0.3, 0.3)
	_rp(g, "cardboard_box_01", cx - 0.5, 4.9, 1.1, 0.34)
	_rp(g, "wooden_crate_02", cx + 2.9, 4.8, 0.2, 0.5, 0.0, 0.35, 0.6)
	# plamy rozlanych odczynników na posadzce
	for e in [[2.6, -3.2, 1.3, 0.9], [-3.9, -3.0, 1.0, 0.7], [5.2, 0.2, 0.8, 1.2], [-5.2, 3.0, 0.9, 0.6]]:
		Interior.stain(g, Vector3(cx + e[0], 0.004, e[1]), Vector3(0, float(e[2]) * 2.0, 0), Vector2(float(e[2]), float(e[3])), Color(0.04, 0.05, 0.05, 0.55))
	inter.append({"loc": "lab", "x": tx, "z": tz, "y0": 0.6, "y1": 1.3, "r": 0.9, "reach": 2.8, "id": "pack_lab",
		"label": func(): return "Spakuj ostatnią partię do torby", "act": func(): G.main.prologue_act("pack")})
	# --- biurko z podglądem kamer
	_rp(g, "metal_office_desk", cx + 5.9, 4.2, -PI / 2.0, 0.76, 0.0, 0.45, 0.8)
	_rp(g, "television_01", cx + 6.0, 4.2, -PI / 2.0, 0.42, 0.76)
	_rp(g, "metal_stool_01", cx + 5.0, 4.2, 0.3, 0.6)
	var mon := _room_light(g, cx + 5.5, 4.2, 1.5, 0.3, Color(0.5, 0.8, 1.0), 2.6)
	mon.shadow_enabled = false
	# --- brama frontowa (północ): to w nią walą, przez świetliki wpada światło kogutów
	Models.box(g, Vector3(3.2, 2.9, 0.12), Vector3(cx + 4.4, 1.45, -d * 0.5 + 0.06), Props.pbr("rusted_shutter", 0.5, Color(0.7, 0.7, 0.72)))
	Models.box(g, Vector3(3.5, 0.18, 0.2), Vector3(cx + 4.4, 2.98, -d * 0.5 + 0.1), steel)
	var panes := []
	for sx in [-5.2, -3.4, 0.6, 2.2]:
		panes.append(Models.box(g, Vector3(1.3, 0.7, 0.05), Vector3(cx + sx, h - 0.75, -d * 0.5 + 0.03), Models.mat("131a26", 0.2, 0.0, 0.25), Vector3.ZERO, false))
		Models.box(g, Vector3(1.4, 0.06, 0.08), Vector3(cx + sx, h - 1.12, -d * 0.5 + 0.05), steel, Vector3.ZERO, false)
	var cops: Array = []
	for i in range(2):
		var cl := OmniLight3D.new()
		cl.position = Vector3(cx + (-3.6 if i == 0 else 3.6), h - 0.8, -d * 0.5 + 0.9)
		cl.light_color = Color(0.2, 0.4, 1.0) if i == 0 else Color(1.0, 0.15, 0.1)
		cl.light_energy = 0.0
		cl.omni_range = 11.0
		cl.shadow_enabled = false
		g.add_child(cl)
		cops.append(cl)
	lab_fx = {"flash": cops, "panes": panes, "bag": bag, "bricks": [st1, st2]}


## waga kuchenna, woreczki i towar na stole
func _scale_set(g: Node3D, at: Vector3) -> void:
	var wm: Node3D = Stations.model("dom_waga")
	if wm != null:
		# waga z wyświetlaczem, woreczki, pojemnik i łyżeczka z modelu; na szalce porcja towaru
		wm.position = at
		g.add_child(wm)
		Models.sphere(wm, 0.03, Vector3(0, 0.058, -0.03), Models.mat("3f7a3a", 0.95), Vector3(1.3, 0.55, 1.1), false, 8)
		return
	var s := Node3D.new()
	s.position = at
	g.add_child(s)
	Models.box(s, Vector3(0.2, 0.035, 0.26), Vector3(0, 0.018, 0), Models.mat("2a2c30", 0.4, 0.3), Vector3.ZERO, false)
	Models.cyl(s, 0.085, 0.085, 0.008, Vector3(0, 0.042, -0.03), Models.mat("c9ced4", 0.25, 0.9), Vector3.ZERO, 16)
	Models.box(s, Vector3(0.09, 0.004, 0.035), Vector3(0, 0.037, 0.09), Models.mat("7df0a0", 0.3, 0.0, 1.6), Vector3.ZERO, false)
	for k in range(5):
		Models.box(s, Vector3(0.07, 0.006, 0.1), Vector3(0.26 + (k % 2) * 0.02, 0.004 + k * 0.006, -0.05 + k * 0.012), Models.mat("dfe6ea", 0.3, 0.0, 0.0, 0.55), Vector3(0, k * 0.2, 0), false)
	Models.sphere(s, 0.035, Vector3(0, 0.06, -0.03), Models.mat("3f7a3a", 0.95), Vector3(1.2, 0.6, 1.1), false, 8)
	Models.box(s, Vector3(0.12, 0.05, 0.18), Vector3(-0.3, 0.025, 0.02), Models.mat("14161a", 0.6), Vector3(0, 0.3, 0), false)


# ================================================================ meble w kryjówkach
static func furn_def(fid: String) -> Dictionary:
	for f in D.FURNITURE:
		if f.id == fid:
			return f
	return {}


static func furn_rect(it: Dictionary) -> Rect2:
	var f := furn_def(it.f)
	var sx: float = f.size[0]
	var sz: float = f.size[1]
	if int(it.r) % 2 == 1:
		var t := sx
		sx = sz
		sz = t
	return Rect2(float(it.x) - sx * 0.5, float(it.z) - sz * 0.5, sx, sz)


func furn_model(fid: String) -> Node3D:
	var f := furn_def(fid)
	var n: Node3D
	if String(f.model) != "":
		n = Props.make(f.model, f.h)
		if fid == "tv":
			var base := Props.make("side_table_01", 0.5)
			n.position.y = 0.5
			var both := Node3D.new()
			both.add_child(base)
			both.add_child(n)
			n = both
		if fid == "stol":
			_scale_set(n, Vector3(-0.3, f.h, 0.0))
	else:
		n = Node3D.new()
		if fid == "laptop":
			n.add_child(Props.make("side_table_01", 0.5))
			var lap := Props.make("classic_laptop", 0.24)
			lap.position.y = 0.5
			n.add_child(lap)
		var made: Node3D = null
		match fid:
			"lampa_led": made = Stations.grow_lamp()
			"suszarka": made = Stations.dryer()
			"zbiornik": made = Stations.tank()
			"filtr": made = Stations.carbon_filter()
			"lab": made = Stations.lab_table()
		if made != null:
			n.free()
			n = made
		if fid == "lampa":
			Models.cyl(n, 0.02, 0.02, 2.0, Vector3(0, 1.0, 0), Models.mat("3a3d42", 0.5, 0.6), Vector3.ZERO, 6)
			Models.cyl(n, 0.18, 0.18, 0.03, Vector3(0, 0.015, 0), Models.mat("2a2c30", 0.5, 0.6), Vector3.ZERO, 10)
			Models.box(n, Vector3(0.9, 0.06, 0.1), Vector3(0, 2.02, 0), Models.mat("fff4d6", 0.4, 0.0, 5.0), Vector3.ZERO, false)
			var li := OmniLight3D.new()
			li.position = Vector3(0, 1.9, 0)
			li.light_color = Color(1.0, 0.95, 0.85)
			li.light_energy = 1.6
			li.omni_range = 7.0
			li.shadow_enabled = true
			n.add_child(li)
	return n


## odbudowuje meble kryjówki na podstawie zapisu gry
func refresh_furniture(room: String) -> void:
	if not furn.has(room):
		return
	var g: Node3D = furn[room]
	for c in g.get_children():
		g.remove_child(c)
		c.queue_free()
	var fb: StaticBody3D = furn_body[room]
	for c in fb.get_children():
		fb.remove_child(c)
		c.queue_free()
	inter_dyn[room] = []
	grow_nodes[room] = {}
	pot_nodes[room] = []
	lamp_nodes[room] = {}
	var hide: Dictionary = G.S.hide.get(room, {})
	var items: Array = hide.get("items", [])
	var cx: float = D.ROOMS[room].cx
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var f := furn_def(it.f)
		if f.is_empty():
			continue
		var n := furn_model(it.f)
		n.position = Vector3(cx + float(it.x), 0.0, float(it.z))
		n.rotation.y = int(it.r) * PI / 2.0
		g.add_child(n)
		var r := furn_rect(it)
		# to, co wisi pod sufitem (lampa LED), nie blokuje przejścia
		if not f.get("hang", false):
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(r.size.x, minf(float(f.h), 1.2), r.size.y)
			cs.shape = bs
			cs.position = Vector3(cx + float(it.x), bs.size.y * 0.5, float(it.z))
			fb.add_child(cs)
		var idx := i
		var ix: float = cx + float(it.x)
		var iz: float = float(it.z)
		var aim := {"loc": room, "x": ix, "z": iz, "y0": 0.1, "y1": maxf(0.6, float(f.h)), "reach": 2.6, "id": "furn_%d" % idx,
			"r": clampf(maxf(float(f.size[0]), float(f.size[1])) * 0.5, 0.45, 1.0)}
		match String(f["func"]):
			"pack":
				aim.merge({"label": func(): return "Stół roboczy — porcjowanie", "act": func(): G.ui.open_pack(room)})
				inter_dyn[room].append(aim)
			"stash":
				aim.merge({"label": func(): return "Skrytka: " + String(f.name), "act": func(): G.ui.open_stash(room)})
				inter_dyn[room].append(aim)
			"bed":
				aim.merge({"label": func(): return "Łóżko — sen", "act": func(): G.main.sleep()})
				inter_dyn[room].append(aim)
			"save":
				aim.merge({"label": func(): return "Laptop — zapisz grę", "act": func(): G.main.save_here()})
				inter_dyn[room].append(aim)
			"grow", "dry", "lab":
				aim.merge({"label": func(): return G.station_label(room, idx), "act": func(): G.ui.open_station(room, idx)})
				inter_dyn[room].append(aim)
				grow_nodes[room][idx] = n
			"tank", "filter":
				aim.merge({"label": func(): return G.station_label(room, idx), "act": func(): G.ui.open_hideout(room)})
				inter_dyn[room].append(aim)
			"growlight":
				aim.merge({"y0": 1.85, "y1": 2.05, "r": 0.6, "reach": 3.2, "up": true,
					"label": func(): return "Lampa LED — %s (przełącz)" % String(G.Prod.lamp_mode(int(G.S.hide[room].items[idx].get("mode", 0))).name).to_lower(),
					"act": func(): G.main.lamp_toggle(room, idx)})
				inter_dyn[room].append(aim)
				lamp_nodes[room][idx] = n
	# doniczki: każda to osobny cel z własnym menu czynności
	var pots: Array = G.Prod.pots(room)
	for i in range(pots.size()):
		var pt: Dictionary = pots[i]
		var pn := Stations.pot_node()
		pn.position = Vector3(cx + float(pt.x), 0.0, float(pt.z))
		g.add_child(pn)
		pot_nodes[room].append(pn)
		var pcs := CollisionShape3D.new()
		var pcy := CylinderShape3D.new()
		pcy.radius = 0.15
		pcy.height = 0.3
		pcs.shape = pcy
		pcs.position = Vector3(cx + float(pt.x), 0.15, float(pt.z))
		fb.add_child(pcs)
		var pi := i
		inter_dyn[room].append({"loc": room, "x": cx + float(pt.x), "z": float(pt.z), "y0": 0.0, "y1": 0.5, "r": 0.3, "reach": 2.6, "id": "pot_%d" % pi, "pot": pi,
			"label": func(): return G.Prod.pot_label(room, pi),
			"menu": func(): return G.main.pot_menu(room, pi),
			"act": func(): pass})
	update_stations()


## stanowiska produkcyjne pokazują swój stan: rośliny rosną, lampy świecą, w kolbach bulgocze
func update_stations() -> void:
	for room in grow_nodes:
		if not G.S.hide.has(room):
			continue
		var jobs: Dictionary = G.Prod.hide(room).jobs
		var items: Array = G.S.hide[room].items
		for idx in grow_nodes[room]:
			var n = grow_nodes[room][idx]
			if n == null or not is_instance_valid(n) or int(idx) >= items.size():
				continue
			var job = jobs.get(str(idx))
			match String(furn_def(String(items[int(idx)].f)).get("func", "")):
				"lab": Stations.refresh_lab(n, job)
				"dry":
					var ld: Node3D = n.get_node_or_null("Load")
					if ld != null:
						ld.visible = job != null
	for room in pot_nodes:
		if not G.S.hide.has(room):
			continue
		var pots: Array = G.Prod.pots(room)
		var nodes: Array = pot_nodes[room]
		for k in range(mini(pots.size(), nodes.size())):
			if is_instance_valid(nodes[k]):
				Stations.refresh_pot(nodes[k], pots[k].pl, float(k))
		# cel celownika rośnie razem z krzakiem
		for it in inter_dyn.get(room, []):
			if it.has("pot") and int(it.pot) < pots.size():
				var pl = pots[int(it.pot)].pl
				it.y1 = 0.5 if pl == null else maxf(0.5, 0.3 + Stations.plant_height(float(pl.prog), float(it.pot)))
		var items: Array = G.S.hide[room].items
		for idx in lamp_nodes.get(room, {}):
			var ln = lamp_nodes[room][idx]
			if ln == null or not is_instance_valid(ln) or int(idx) >= items.size():
				continue
			var it2: Dictionary = items[int(idx)]
			var rc: Rect2 = G.furn_rect(furn_def(String(it2.f)), float(it2.x), float(it2.z), int(it2.r)).grow(0.12)
			var any := false
			for k in range(pots.size()):
				if pots[k].pl != null and rc.has_point(Vector2(float(pots[k].x), float(pots[k].z))):
					any = true
			Stations.refresh_lamp(ln, any, int(it2.get("mode", 0)))

