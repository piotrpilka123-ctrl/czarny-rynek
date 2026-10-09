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
var _goal_key := Vector2(1e9, 1e9)
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


## Najbliższy punkt na sieci dróg i ścieżek (na krawędzi grafu, nie tylko w węźle):
## {a, b — węzły krawędzi, p — punkt na krawędzi, d — odległość}
func _nearest_edge(x: float, z: float) -> Dictionary:
	var wp: Array = G.world.wp
	var P := Vector2(x, z)
	var best := {}
	var bd := 1e9
	var any := {}
	var ad := 1e9
	for n in wp:
		var A := Vector2(n.x, n.z)
		for j in n.links:
			if int(j) <= int(n.i):
				continue
			var B := Vector2(wp[j].x, wp[j].z)
			var ab := B - A
			var t := clampf((P - A).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
			var q := A + ab * t
			var d := P.distance_to(q)
			if d < ad:
				ad = d
				any = {"a": int(n.i), "b": int(j), "p": q, "d": d}
			if d < bd and (d < 1.2 or (G.world.los(x, z, q.x, q.y) and G.world.grid_clear(Vector2(x, z), q))):
				bd = d
				best = {"a": int(n.i), "b": int(j), "p": q, "d": d}
	# krawędź widoczna z punktu ma pierwszeństwo, o ile nie jest dużo dalej niż najbliższa
	return best if (not best.is_empty() and bd < ad + 30.0) else any


## najkrótsze drogi po sieci do punktu leżącego na krawędzi (kolejkowy Bellman-Ford)
func _solve_edge(ge: Dictionary) -> void:
	var wp: Array = G.world.wp
	var n := wp.size()
	_dist.resize(n)
	_next.resize(n)
	for i in range(n):
		_dist[i] = 1e9
		_next[i] = -1
	var queue: Array = []
	for e in [int(ge.a), int(ge.b)]:
		_dist[e] = Vector2(wp[e].x, wp[e].z).distance_to(ge.p)
		queue.append(e)
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


## Trasa prowadzi po drogach, chodnikach i wydeptanych ścieżkach: z miejsca gracza najkrótszym
## dojściem do sieci, dalej wyłącznie po jej krawędziach (bez ścinania po przekątnej przez trawniki)
## i na końcu krótkim dojściem do celu.
func find(ax: float, az: float, bx: float, bz: float) -> Array:
	var W = G.world
	var A := Vector2(ax, az)
	var B := Vector2(bx, bz)
	if A.distance_to(B) < 12.0 and W.los(ax, az, bx, bz) and W.grid_clear(A, B) and absf(W.height(ax, az) - W.height(bx, bz)) < 1.5:
		return [A, B]
	var ge := _nearest_edge(bx, bz)
	var se := _nearest_edge(ax, az)
	if ge.is_empty() or se.is_empty():
		var fallback: Array = [A]
		fallback.append_array(Array(W.grid_path(A, B)))
		return fallback
	var gkey := Vector2(snappedf(ge.p.x, 0.5), snappedf(ge.p.y, 0.5))
	if gkey != _goal_key:
		_solve_edge(ge)
		_goal_key = gkey
	var wp: Array = W.wp
	var pts: Array = [A, se.p]
	var same: bool = (int(se.a) == int(ge.a) and int(se.b) == int(ge.b)) or (int(se.a) == int(ge.b) and int(se.b) == int(ge.a))
	if not same:
		var pa := Vector2(wp[se.a].x, wp[se.a].z)
		var pb := Vector2(wp[se.b].x, wp[se.b].z)
		var ca: float = se.p.distance_to(pa) + _dist[se.a]
		var cb: float = se.p.distance_to(pb) + _dist[se.b]
		var cur: int = int(se.a) if ca <= cb else int(se.b)
		var guard := 0
		while cur >= 0 and guard < 400:
			guard += 1
			pts.append(Vector2(wp[cur].x, wp[cur].z))
			cur = _next[cur]
	pts.append(ge.p)
	pts.append(B)
	# porządki: usuń powtórzenia i punkty leżące na jednej prostej
	var out: Array = [pts[0]]
	for i in range(1, pts.size()):
		if (pts[i] as Vector2).distance_to(out[out.size() - 1]) > 0.35:
			out.append(pts[i])
	var i2 := 1
	while i2 < out.size() - 1:
		var u: Vector2 = (out[i2] as Vector2) - (out[i2 - 1] as Vector2)
		var v: Vector2 = (out[i2 + 1] as Vector2) - (out[i2] as Vector2)
		if absf(u.normalized().cross(v.normalized())) < 0.03 and u.dot(v) > 0.0:
			out.remove_at(i2)
		else:
			i2 += 1
	return out


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
