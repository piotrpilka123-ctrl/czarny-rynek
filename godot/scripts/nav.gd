extends Node3D
## Nawigacja: trasa po grafie ścieżek (chodniki, schody, przejścia)
## i świecąca wstęga na ziemi prowadząca do celu.

const SH_RIBBON := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.3, 1.0, 0.5);
void fragment() {
	float v = abs(UV.y - 0.5) * 2.0;
	float k = fract(UV.x - TIME * 1.1 + v * 0.32);
	float a = smoothstep(0.0, 0.07, k) * smoothstep(0.36, 0.26, k) * (1.0 - smoothstep(0.8, 1.0, v));
	ALBEDO = tint * 2.2;
	ALPHA = a * 0.9;
}
"""

var path: Array = []           # Array[Vector2] (x, z)
var length := 0.0
var ribbon: MeshInstance3D
var mat: ShaderMaterial
var _goal_node := -1
var _next := PackedInt32Array()
var _dist := PackedFloat32Array()


func _ready() -> void:
	var sh := Shader.new()
	sh.code = SH_RIBBON
	mat = ShaderMaterial.new()
	mat.shader = sh
	ribbon = MeshInstance3D.new()
	ribbon.material_override = mat
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.visible = false
	add_child(ribbon)


func nearest_node(x: float, z: float, need_los := true) -> int:
	var wp: Array = G.world.wp
	var best := -1
	var bd := 1e9
	var any := -1
	var ad := 1e9
	for n in wp:
		var d := Vector2(n.x - x, n.z - z).length()
		if d < ad:
			ad = d
			any = n.i
		if d < bd and d < 80.0 and (not need_los or G.world.los(x, z, n.x, n.z)):
			bd = d
			best = n.i
	return best if best >= 0 else any


## najkrótsze drogi do węzła docelowego (kolejkowy Bellman-Ford)
func _solve(goal: int) -> void:
	var wp: Array = G.world.wp
	var n := wp.size()
	_dist.resize(n)
	_next.resize(n)
	for i in range(n):
		_dist[i] = 1e9
		_next[i] = -1
	_dist[goal] = 0.0
	var queue: Array = [goal]
	var head := 0
	while head < queue.size():
		var u: int = queue[head]
		head += 1
		var nu: Dictionary = wp[u]
		for v in nu.links:
			var nv: Dictionary = wp[v]
			var w := Vector2(nv.x - nu.x, nv.z - nu.z).length()
			if _dist[u] + w < _dist[v] - 0.01:
				_dist[v] = _dist[u] + w
				_next[v] = u
				queue.append(v)
	_goal_node = goal


func find(ax: float, az: float, bx: float, bz: float) -> Array:
	var W = G.world
	var direct := Vector2(bx - ax, bz - az).length()
	if direct < 40.0 and W.los(ax, az, bx, bz) and absf(W.height(ax, az) - W.height(bx, bz)) < 1.5:
		return [Vector2(ax, az), Vector2(bx, bz)]
	var e := nearest_node(bx, bz)
	if e < 0:
		return [Vector2(ax, az), Vector2(bx, bz)]
	if e != _goal_node:
		_solve(e)
	# start: widoczny węzeł o najmniejszym koszcie łącznym
	var wp: Array = W.wp
	var s := -1
	var sc := 1e9
	for n in wp:
		var d := Vector2(n.x - ax, n.z - az).length()
		if d > 60.0 or _dist[n.i] > 1e8:
			continue
		var c := d * 1.15 + _dist[n.i]
		if c < sc and W.los(ax, az, n.x, n.z):
			sc = c
			s = n.i
	if s < 0:
		s = nearest_node(ax, az, false)
	var pts: Array = [Vector2(ax, az)]
	var cur := s
	var guard := 0
	while cur >= 0 and guard < 400:
		guard += 1
		pts.append(Vector2(wp[cur].x, wp[cur].z))
		cur = _next[cur]
	pts.append(Vector2(bx, bz))
	# wygładzanie: usuń punkty pośrednie na prostych, płaskich odcinkach
	for _pass in range(2):
		var i := 1
		while i < pts.size() - 1:
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i + 1]
			if a.distance_to(b) < 46.0 and W.los(a.x, a.y, b.x, b.y) and absf(W.height(a.x, a.y) - W.height(b.x, b.y)) < 1.0:
				pts.remove_at(i)
			else:
				i += 1
	return pts


## trasa jest rysowana tylko na minimapie i w aplikacji Mapa (bez wstęgi na ziemi)
func set_path(pts: Array, _color: Color, _indoor := false) -> void:
	path = pts
	length = 0.0
	for i in range(pts.size() - 1):
		length += (pts[i + 1] as Vector2).distance_to(pts[i])


## droga pieszego między dwoma punktami po grafie ścieżek (dla klientów idących na spotkanie)
func path_between(a: Vector2, b: Vector2) -> Array:
	var wp: Array = G.world.wp
	var s := nearest_node(a.x, a.y, false)
	var e := nearest_node(b.x, b.y, false)
	if s < 0 or e < 0:
		return [a, b]
	var dist := PackedFloat32Array()
	var nxt := PackedInt32Array()
	dist.resize(wp.size())
	nxt.resize(wp.size())
	for i in range(wp.size()):
		dist[i] = 1e9
		nxt[i] = -1
	dist[e] = 0.0
	var queue: Array = [e]
	var head := 0
	while head < queue.size():
		var u: int = queue[head]
		head += 1
		for v in wp[u].links:
			var w := Vector2(wp[v].x - wp[u].x, wp[v].z - wp[u].z).length()
			if dist[u] + w < dist[v] - 0.01:
				dist[v] = dist[u] + w
				nxt[v] = u
				queue.append(v)
	var pts: Array = [a]
	var cur := s
	var guard := 0
	while cur >= 0 and guard < 400:
		guard += 1
		pts.append(Vector2(wp[cur].x, wp[cur].z))
		cur = nxt[cur]
	pts.append(b)
	return pts


func clear_path() -> void:
	path = []
	length = 0.0
	ribbon.visible = false
