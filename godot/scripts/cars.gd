extends RefCounted
## Samochody: nadwozia rozpinane na przekrojach (maska, szyba, dach, bagażnik zwężają się jak w prawdziwym aucie),
## koła z kołpakami, zderzaki, lampy, lusterka, szczeliny drzwi. Całe auto to JEDNA siatka i jedno wywołanie
## rysowania — rodzaj powierzchni (lakier, szkło, guma, chrom, lampa) siedzi w drugim kanale UV.
## Kształty są własne, kanciaste jak auta z blokowisk lat 80. i 90.; żadna marka nie jest odwzorowana.

const M_PAINT := 0.0
const M_GLASS := 1.0
const M_DARK := 2.0
const M_CHROME := 3.0
const M_HEAD := 4.0
const M_TAIL := 5.0

## L, W: długość i szerokość, wb: rozstaw osi, wr: promień koła, belt: linia okien,
## top: profil górnej krawędzi od tyłu (x ujemne) do przodu, roof: [początek, koniec] dachu
const TYPES := {
	"sedan": {"L": 4.36, "W": 1.68, "wb": 2.52, "wr": 0.3, "belt": 0.92, "roof": [-0.78, 0.32],
		"top": [[-2.18, 0.66], [-2.12, 0.9], [-1.38, 0.95], [-0.78, 1.36], [0.32, 1.38], [1.02, 0.94], [1.98, 0.84], [2.18, 0.62]]},
	"hatch": {"L": 3.92, "W": 1.64, "wb": 2.42, "wr": 0.29, "belt": 0.92, "roof": [-1.5, 0.22],
		"top": [[-1.96, 0.66], [-1.9, 0.94], [-1.5, 1.37], [0.22, 1.4], [0.94, 0.95], [1.78, 0.86], [1.96, 0.64]]},
	"maluch": {"L": 3.06, "W": 1.38, "wb": 1.84, "wr": 0.25, "belt": 0.86, "roof": [-0.74, 0.2],
		"top": [[-1.53, 0.56], [-1.48, 0.84], [-1.12, 0.98], [-0.74, 1.3], [0.2, 1.32], [0.74, 0.88], [1.4, 0.8], [1.53, 0.56]]},
	"kombi": {"L": 4.5, "W": 1.7, "wb": 2.6, "wr": 0.3, "belt": 0.93, "roof": [-2.0, 0.38],
		"top": [[-2.25, 0.66], [-2.2, 0.95], [-2.0, 1.4], [0.38, 1.42], [1.08, 0.95], [2.05, 0.85], [2.25, 0.62]]},
	"suv": {"L": 4.5, "W": 1.82, "wb": 2.62, "wr": 0.36, "belt": 1.08, "roof": [-2.0, 0.36],
		"top": [[-2.25, 0.8], [-2.2, 1.1], [-2.0, 1.68], [0.36, 1.7], [1.0, 1.1], [2.05, 1.0], [2.25, 0.76]]},
	"van": {"L": 4.7, "W": 1.84, "wb": 2.76, "wr": 0.33, "belt": 1.14, "roof": [-2.28, 1.12],
		"top": [[-2.35, 0.72], [-2.32, 1.5], [-2.28, 1.92], [1.12, 1.94], [1.78, 1.16], [2.26, 1.06], [2.35, 0.7]]},
}

const SH := """
shader_type spatial;
render_mode cull_disabled;
global uniform float night;
global uniform float wet;
instance uniform vec3 paint : source_color = vec3(0.5);
instance uniform float dirt = 0.35;
instance uniform float lamps = 0.0;
varying float mid;
varying vec3 lp;
void vertex() {
	mid = UV2.x;
	lp = VERTEX;
}
void fragment() {
	int m = int(mid + 0.5);
	vec3 col = COLOR.rgb;
	float rough = 0.75;
	float metal = 0.0;
	vec3 emi = vec3(0.0);
	if (m == 0) {
		col = paint * COLOR.rgb;
		rough = 0.34 - wet * 0.15;
		metal = 0.45;
		// kurz i błoto od dołu, matowy lakier starych aut
		float d = smoothstep(0.8, 0.22, lp.y) * dirt;
		float blot = fract(sin(dot(floor(lp.xz * 9.0), vec2(12.9, 78.2))) * 43758.5);
		col = mix(col, vec3(0.22, 0.2, 0.17), d * (0.55 + blot * 0.3));
		rough = mix(rough, 0.92, d + dirt * 0.25);
	} else if (m == 1) {
		col = vec3(0.025, 0.035, 0.045);
		rough = 0.06;
		metal = 0.55;
	} else if (m == 3) {
		rough = 0.28;
		metal = 0.9;
	} else if (m == 4) {
		emi = COLOR.rgb * (0.1 + lamps * 2.6);
		rough = 0.15;
	} else if (m == 5) {
		emi = COLOR.rgb * (0.12 + lamps * 1.4);
		rough = 0.25;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emi;
	SPECULAR = 0.5;
}
"""

static var _mesh := {}
static var _mat: ShaderMaterial = null


static func _top(T: Dictionary, x: float) -> float:
	var k: Array = T.top
	if x <= float(k[0][0]):
		return k[0][1]
	for i in range(k.size() - 1):
		if x <= float(k[i + 1][0]):
			var t := (x - float(k[i][0])) / maxf(0.0001, float(k[i + 1][0]) - float(k[i][0]))
			return lerpf(k[i][1], k[i + 1][1], t)
	return k[k.size() - 1][1]


## przekrój nadwozia w miejscu x: 8 punktów od środka podłogi do środka dachu (strona +Z)
static func _section(T: Dictionary, x: float) -> Array:
	var hl: float = float(T.L) * 0.5
	var top := _top(T, x)
	var belt: float = T.belt
	var cabin := clampf((top - belt) / 0.22, 0.0, 1.0)
	var e := absf(x) / hl
	var nose := smoothstep(0.72, 1.0, e)
	var w: float = float(T.W) * 0.5 * (1.0 - 0.13 * nose * nose)
	var bot := 0.25 + 0.1 * nose
	var shoulder := lerpf(top - 0.09, belt, cabin)
	var w_roof := w * lerpf(0.965, 0.8, cabin)
	return [Vector3(x, bot, 0.0), Vector3(x, bot, w * 0.88), Vector3(x, bot + 0.12, w), Vector3(x, shoulder, w), Vector3(x, shoulder + 0.035, w - 0.012 * cabin),
		Vector3(x, top - 0.035 - 0.03 * cabin, w_roof), Vector3(x, top, w_roof * 0.84), Vector3(x, top + 0.018, 0.0)]


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, mid: float, col := Color.WHITE) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_uv2(Vector2(mid, 0.0))
		st.add_vertex(v)


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, mid: float, col := Color.WHITE) -> void:
	var h := s * 0.5
	var p := [c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)]
	for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		_quad(st, p[f[0]], p[f[1]], p[f[2]], p[f[3]], mid, col)


## walec o osi Z (koło, kołpak, nadkole)
static func _disc(st: SurfaceTool, c: Vector3, r: float, width: float, mid: float, col: Color, seg := 14, arc := TAU) -> void:
	for i in range(seg):
		var a0 := arc * i / seg
		var a1 := arc * (i + 1) / seg
		var p0 := Vector3(cos(a0) * r, sin(a0) * r, 0.0)
		var p1 := Vector3(cos(a1) * r, sin(a1) * r, 0.0)
		var zf := Vector3(0, 0, width * 0.5)
		_quad(st, c + p0 - zf, c + p1 - zf, c + p1 + zf, c + p0 + zf, mid, col)
		for sd in [-1.0, 1.0]:
			for v in [c + zf * sd, c + p0 + zf * sd, c + p1 + zf * sd]:
				st.set_color(col)
				st.set_uv2(Vector2(mid, 0.0))
				st.add_vertex(v)


static func _build(type: String) -> ArrayMesh:
	var T: Dictionary = TYPES[type]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hl: float = float(T.L) * 0.5
	var r0: float = T.roof[0]
	var r1: float = T.roof[1]
	var midx := (r0 + r1) * 0.5
	# stacje przekrojów: punkty profilu, słupki dachu i zagęszczenie na końcach
	var xs: Array = []
	for k in T.top:
		xs.append(float(k[0]))
	for x in [r0 + 0.07, r1 - 0.07, midx - 0.04, midx + 0.04, -hl + 0.25, hl - 0.25, hl - 0.5, -hl + 0.5]:
		xs.append(x)
	if type == "van" or type == "kombi" or type == "suv":
		xs.append(lerpf(r0, midx, 0.5) - 0.04)
		xs.append(lerpf(r0, midx, 0.5) + 0.04)
	xs.sort()
	var uniq: Array = []
	for x in xs:
		if uniq.is_empty() or absf(float(x) - float(uniq.back())) > 0.012:
			uniq.append(x)
	var secs: Array = []
	for x in uniq:
		secs.append(_section(T, x))
	var white := Color.WHITE
	for i in range(secs.size() - 1):
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		var xa: float = uniq[i]
		var xb: float = uniq[i + 1]
		var in_roof := xa >= r0 - 0.001 and xb <= r1 + 0.001
		# słupki: przy końcach dachu i w środku (w kombi i dostawczaku jeszcze jeden z tyłu)
		var pillar := xb <= r0 + 0.071 or xa >= r1 - 0.071 or (xa >= midx - 0.041 and xb <= midx + 0.041)
		if (type == "van" or type == "kombi" or type == "suv") and xa >= lerpf(r0, midx, 0.5) - 0.041 and xb <= lerpf(r0, midx, 0.5) + 0.041:
			pillar = true
		var blind_side := type == "van" and xb <= midx
		var front_glass := xa >= r1 - 0.001 and _top(T, xb) < _top(T, xa) - 0.05 and _top(T, xa) > float(T.belt) + 0.1
		var rear_glass := xb <= r0 + 0.001 and _top(T, xa) < _top(T, xb) - 0.05 and _top(T, xb) > float(T.belt) + 0.1 and type != "van"
		for sd in [1.0, -1.0]:
			var m := Vector3(1, 1, sd)
			for k in range(7):
				var mid := M_PAINT
				if k == 4 and in_roof and not pillar and not blind_side:
					mid = M_GLASS
				if k == 6 and (front_glass or rear_glass):
					mid = M_GLASS
				if k == 0:
					mid = M_DARK
				var p0: Vector3 = a[k] * m
				var p1: Vector3 = a[k + 1] * m
				var p2: Vector3 = b[k + 1] * m
				var p3: Vector3 = b[k] * m
				if sd > 0.0:
					_quad(st, p0, p3, p2, p1, mid, white if mid != M_DARK else Color(0.06, 0.06, 0.07))
				else:
					_quad(st, p0, p1, p2, p3, mid, white if mid != M_DARK else Color(0.06, 0.06, 0.07))
	# zaślepki z przodu i z tyłu
	for e in [[secs[0], -1.0], [secs[secs.size() - 1], 1.0]]:
		var s: Array = e[0]
		for sd in [1.0, -1.0]:
			var m2 := Vector3(1, 1, sd)
			for k in range(1, 6):
				for v in [s[0] * m2, s[k] * m2, s[k + 1] * m2]:
					st.set_color(white)
					st.set_uv2(Vector2(M_PAINT, 0.0))
					st.add_vertex(v)
	var W: float = T.W
	var wr: float = T.wr
	var wb: float = T.wb
	var tire := Color(0.045, 0.045, 0.05)
	var plastic := Color(0.07, 0.07, 0.08)
	var old := type == "maluch"
	# koła, kołpaki, nadkola
	for wx in [-wb * 0.5, wb * 0.5]:
		for sd in [-1.0, 1.0]:
			var zc: float = sd * (W * 0.5 - 0.11)
			_disc(st, Vector3(wx, wr, zc), wr, 0.2, M_DARK, tire, 16)
			_disc(st, Vector3(wx, wr, zc + sd * 0.1), wr * 0.62, 0.02, M_CHROME, Color(0.6, 0.62, 0.64), 10)
			_disc(st, Vector3(wx, wr + 0.02, sd * (W * 0.5 - 0.004)), wr + 0.07, 0.012, M_DARK, Color(0.02, 0.02, 0.025), 10, PI)
	# zderzaki, atrapa, tablice
	var fy := _top(T, hl - 0.05)
	var ry := _top(T, -hl + 0.05)
	var bump := M_CHROME if old else M_DARK
	var bcol := Color(0.62, 0.63, 0.65) if old else plastic
	_box(st, Vector3(hl - 0.02, 0.4, 0), Vector3(0.12, 0.15, W - 0.1), bump, bcol)
	_box(st, Vector3(-hl + 0.02, 0.42, 0), Vector3(0.12, 0.15, W - 0.1), bump, bcol)
	if not old:
		_box(st, Vector3(hl - 0.012, fy + 0.02, 0), Vector3(0.05, 0.13, W * 0.4), M_DARK, Color(0.03, 0.03, 0.035))
	_box(st, Vector3(hl + 0.045, 0.42, 0), Vector3(0.012, 0.11, 0.48), M_DARK, Color(0.88, 0.88, 0.84))
	_box(st, Vector3(-hl - 0.045, 0.46 if type != "van" else 0.9, 0), Vector3(0.012, 0.11, 0.48), M_DARK, Color(0.88, 0.88, 0.84))
	# lampy
	for sd in [-1.0, 1.0]:
		var lz: float = sd * (W * 0.5 - 0.3)
		if old:
			_box(st, Vector3(hl - 0.03, fy + 0.02, lz), Vector3(0.07, 0.15, 0.15), M_HEAD, Color(1.0, 0.96, 0.84))
		else:
			_box(st, Vector3(hl - 0.03, fy + 0.02, lz), Vector3(0.08, 0.13, 0.36), M_HEAD, Color(1.0, 0.96, 0.84))
			_box(st, Vector3(hl - 0.03, fy + 0.02, sd * (W * 0.5 - 0.09)), Vector3(0.08, 0.13, 0.1), M_HEAD, Color(1.0, 0.6, 0.15))
		_box(st, Vector3(-hl + 0.03, ry - 0.12 if type != "van" else 1.0, lz), Vector3(0.08, 0.14 if type != "van" else 0.3, 0.34 if type != "van" else 0.12), M_TAIL, Color(1.0, 0.1, 0.06))
		# lusterko, klamki, szczeliny drzwi, listwa
		var side = sd * (W * 0.5 + 0.004)
		_box(st, Vector3(r1 + 0.16, float(T.belt) + 0.08, sd * (W * 0.5 + 0.07)), Vector3(0.1, 0.09, 0.16), M_DARK, plastic)
		_box(st, Vector3(midx - 0.04, 0.6, side), Vector3(0.008, float(T.belt) - 0.42, 0.006), M_DARK, Color(0.02, 0.02, 0.02))
		_box(st, Vector3(r1 + 0.1, 0.6, side), Vector3(0.008, float(T.belt) - 0.42, 0.006), M_DARK, Color(0.02, 0.02, 0.02))
		_box(st, Vector3(midx + 0.5, float(T.belt) - 0.12, side), Vector3(0.14, 0.025, 0.012), M_CHROME if old else M_DARK, Color(0.5, 0.5, 0.52) if old else plastic)
		if type != "maluch" and type != "van":
			_box(st, Vector3(r0 + 0.02, 0.6, side), Vector3(0.008, float(T.belt) - 0.42, 0.006), M_DARK, Color(0.02, 0.02, 0.02))
			_box(st, Vector3(midx - 0.55, float(T.belt) - 0.12, side), Vector3(0.14, 0.025, 0.012), M_DARK, plastic)
		_box(st, Vector3(0.0, 0.52, side), Vector3(float(T.L) * 0.62, 0.035, 0.008), M_DARK, plastic)
	st.generate_normals()
	return st.commit()


static func mesh(type: String) -> ArrayMesh:
	if not _mesh.has(type):
		_mesh[type] = _build(type)
	return _mesh[type]


static func material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SH
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat


## Zwraca Node3D; przód auta = +Z. Kolor: Color albo napis hex.
## modele z Blendera (tools/blender/make_auta.py); typ „suv” korzysta z kombi
const MODELS := {"sedan": "auto_sedan", "hatch": "auto_hatch", "kombi": "auto_kombi", "suv": "auto_kombi", "maluch": "auto_maluch", "van": "auto_van", "swat": "auto_swat"}
static var _glb := {}
static var _paint := {}
static var _soft := {}
## Szyby, plastiki i opony modeli są prawie czarne (szyba 070e15 z metalicznością 0,6) — na ulicy wychodziły smoliste plamy.
## Zamienniki: ciemne, ale czytelne (grafitowa guma, szaroniebieskie szkło, które łapie odbicie nieba).
const SOFT := {"szyba": [Color(0.17, 0.21, 0.26), 0.1, 0.25], "plastik": [Color(0.17, 0.175, 0.19), 0.75, 0.0], "guma": [Color(0.15, 0.15, 0.16), 0.9, 0.0]}


static func _soften(root: Node) -> void:
	for ch in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = ch
		if mi.mesh == null:
			continue
		for sf in range(mi.mesh.get_surface_count()):
			var src := mi.mesh.surface_get_material(sf)
			if src == null or not SOFT.has(String(src.resource_name)) or mi.get_surface_override_material(sf) != null:
				continue
			var nm := String(src.resource_name)
			if not _soft.has(nm):
				var m: BaseMaterial3D = src.duplicate()
				m.albedo_color = SOFT[nm][0]
				m.roughness = SOFT[nm][1]
				m.metallic = SOFT[nm][2]
				_soft[nm] = m
			mi.set_surface_override_material(sf, _soft[nm])



static func _scene(name: String) -> PackedScene:
	if not _glb.has(name):
		var path := "res://assets/models/%s.glb" % name
		_glb[name] = load(path) if ResourceLoader.exists(path) else null
	return _glb[name]


static func _find(n: Node, name: String) -> Node:
	if String(n.name) == name:
		return n
	for c in n.get_children():
		var r := _find(c, name)
		if r != null:
			return r
	return null


## Auto z modelu: lakier w zadanym kolorze (z brudem i przetarciami z wypalonej tekstury), koła jako osobne węzły
## (meta "wheels" — można nimi kręcić), przy radiowozie klosze belki (meta "siren"). Przód auta = +Z.
static func car(type := "", color = null, police := false) -> Node3D:
	if type == "" or not TYPES.has(type) and type != "swat":
		type = ["sedan", "sedan", "hatch", "hatch", "maluch", "kombi", "van"].pick_random()
	var T: Dictionary = TYPES["van" if type == "swat" else type]
	var ps := _scene("auto_policja" if (police and type != "swat") else String(MODELS.get(type, "auto_sedan")))
	if ps == null:
		return _car_old(type if type != "swat" else "van", color, police)
	var root: Node3D = ps.instantiate()
	var c: Color = color if color is Color else Color.html("#" + String(color if color != null else "8a8f96"))
	if type == "swat":
		c = Color(0.15, 0.18, 0.26)
	var body := _find(root, "TintKaroseria") as MeshInstance3D
	if body != null:
		var key := "%s|%s|%s" % [type, c.to_html(false), str(police)]
		if not _paint.has(key):
			var src := body.mesh.surface_get_material(0)
			var m: StandardMaterial3D = (src.duplicate() as StandardMaterial3D) if src is StandardMaterial3D else StandardMaterial3D.new()
			m.albedo_color = c
			m.metallic = 0.25
			m.roughness = 0.42
			m.clearcoat_enabled = true
			m.clearcoat = 0.5
			m.clearcoat_roughness = 0.25
			_paint[key] = m
		body.material_override = _paint[key]
		root.set_meta("body", body)
	_soften(root)
	if type == "suv":
		root.scale = Vector3(1.06, 1.12, 1.0)
	var wheels: Array = []
	for i in range(1, 5):
		var w := _find(root, "Kolo%d" % i)
		if w != null:
			wheels.append(w)
	root.set_meta("wheels", wheels)
	var lights: Array = []
	for nm in ["KogutL", "KogutP"]:
		var l := _find(root, nm)
		if l != null:
			l.visible = false
			lights.append(l)
	if not lights.is_empty():
		root.set_meta("siren", lights)
	for ch in root.find_children("*", "GeometryInstance3D", true, false):
		(ch as GeometryInstance3D).visibility_range_end = 150.0
	# reflektory i lampy tylne: model ma je lekko świecące, a zaparkowane auto stoi ciemne — zapala je dopiero jadący radiowóz
	var lamps: Array = []
	for ch in root.find_children("*", "MeshInstance3D", true, false):
		var nm := String(ch.name)
		if nm.begins_with("Reflektor") or nm.begins_with("LampaTyl"):
			lamps.append(ch)
	root.set_meta("lamps", lamps)
	lamps_on(root, false)
	root.set_meta("car", T)
	return root


static var _lamp_off := {}

## gasi wszystko, co w modelu świeci samo z siebie (zaparkowany autobus, wrak) — materiały z wyłączoną emisją
static func dim(root: Node) -> void:
	for ch in root.find_children("*", "MeshInstance3D", true, false):
		var mi := ch as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null or not src.emission_enabled:
				continue
			var id := src.get_instance_id()
			if not _lamp_off.has(id):
				var m := src.duplicate() as StandardMaterial3D
				m.emission_enabled = false
				_lamp_off[id] = m
			mi.set_surface_override_material(i, _lamp_off[id])

## zapala albo gasi klosze świateł auta (same klosze — snopy światła to osobne lampy)
static func lamps_on(car_node: Node, on: bool) -> void:
	var list: Array = car_node.get_meta("lamps", [])
	if list.is_empty():
		for ch in car_node.find_children("*", "MeshInstance3D", true, false):
			if String(ch.name).begins_with("Reflektor") or String(ch.name).begins_with("LampaTyl"):
				list.append(ch)
	for l in list:
		var mi := l as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if on:
			mi.material_override = null
			continue
		var src := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if src == null:
			continue
		var id := src.get_instance_id()
		if not _lamp_off.has(id):
			var m := src.duplicate() as StandardMaterial3D
			m.emission_enabled = false
			_lamp_off[id] = m
		mi.material_override = _lamp_off[id]


## dawna bryła z przekrojów — zostaje jako zapas, gdyby zabrakło modeli
static func _car_old(type := "", color = null, police := false) -> Node3D:
	if type == "" or not TYPES.has(type):
		type = ["sedan", "sedan", "hatch", "hatch", "maluch", "kombi", "van"].pick_random()
	var T: Dictionary = TYPES[type]
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(type)
	mi.material_override = material()
	mi.rotation.y = -PI / 2.0                 # kształt ma przód w +X
	var c: Color = color if color is Color else Color.html("#" + String(color if color != null else "8a8f96"))
	mi.set_instance_shader_parameter("paint", c)
	mi.set_instance_shader_parameter("dirt", 0.12 if police else randf_range(0.2, 0.75))
	mi.visibility_range_end = 150.0
	root.add_child(mi)
	root.set_meta("body", mi)
	if police:
		var g := Node3D.new()
		g.rotation.y = -PI / 2.0
		root.add_child(g)
		var W: float = T.W
		var blue := StandardMaterial3D.new()
		blue.albedo_color = Color(0.1, 0.2, 0.62)
		blue.roughness = 0.5
		var roof_y: float = _top(T, 0.0)
		for sd in [-1.0, 1.0]:
			var stripe := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(float(T.L) * 0.8, 0.2, 0.01)
			stripe.mesh = bm
			stripe.material_override = blue
			stripe.position = Vector3(0, 0.7, sd * (W * 0.5 + 0.006))
			g.add_child(stripe)
			var lb := Label3D.new()
			lb.text = "POLICE"
			lb.font_size = 40
			lb.pixel_size = 0.004
			lb.modulate = Color.WHITE
			lb.outline_size = 0
			lb.position = Vector3(0.2, 0.7, sd * (W * 0.5 + 0.014))
			lb.rotation.y = 0.0 if sd > 0 else PI
			g.add_child(lb)
		var bar := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.28, 0.06, 1.0)
		bar.mesh = bb
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.11, 0.11, 0.12)
		bar.material_override = dm
		bar.position = Vector3(-0.15, roof_y + 0.05, 0)
		g.add_child(bar)
		var lights: Array = []
		for e in [[-0.26, Color(1.0, 0.12, 0.12)], [0.26, Color(0.12, 0.25, 1.0)]]:
			var l := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.24, 0.11, 0.42)
			l.mesh = lm
			var em := StandardMaterial3D.new()
			em.albedo_color = e[1]
			em.emission_enabled = true
			em.emission = e[1]
			em.emission_energy_multiplier = 3.0
			l.material_override = em
			l.position = Vector3(-0.15, roof_y + 0.13, float(e[0]))
			g.add_child(l)
			lights.append(l)
		root.set_meta("siren", lights)
	root.set_meta("car", T)
	return root
