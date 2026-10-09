extends Node
## Przegląd świata uruchamiany z --audit: ścieżki przechodniów wchodzące w przeszkody,
## bryły bez kolizji (da się przez nie przejść) i przedmioty wiszące nad ziemią.

var W
var out: Array = []


func _ready() -> void:
	W = G.world
	for i in range(4):
		await get_tree().physics_frame
	_paths()
	_meshes()
	for l in out:
		print(l)
	print("AUDIT koniec")
	get_tree().quit()


func _paths() -> void:
	var bad := 0
	for n in W.wp:
		for j in n.links:
			if int(j) <= int(n.i):
				continue
			var a := Vector2(n.x, n.z)
			var b := Vector2(W.wp[j].x, W.wp[j].z)
			var steps := int(ceil(a.distance_to(b) / 0.4))
			var hit := 0
			var at := Vector2.ZERO
			for s in range(1, steps):
				var p := a.lerp(b, float(s) / steps)
				if W.grid.is_point_solid(W._cell(p.x, p.y)):
					hit += 1
					at = p
			if hit > 1:
				bad += 1
				out.append("ŚCIEŻKA w przeszkodzie: (%.1f, %.1f) -> (%.1f, %.1f), %d próbek, np. przy (%.1f, %.1f) [plan]" % [a.x / D.SC, a.y / D.SC, b.x / D.SC, b.y / D.SC, hit, at.x / D.SC, at.y / D.SC])
	out.append("ŚCIEŻKI: %d odcinków z przeszkodą" % bad)


func _walk(n: Node, list: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as Node3D).is_visible_in_tree():
		list.append(n)
	for c in n.get_children():
		_walk(c, list)


func _meshes() -> void:
	var list: Array = []
	_walk(W, list)
	var space = W.get_world_3d().direct_space_state
	var groups := {}
	var floats := {}
	for mi in list:
		var m: MeshInstance3D = mi
		var bb: AABB = m.global_transform * m.mesh.get_aabb()
		var c := bb.get_center()
		if absf(c.x) > 125.0 or absf(c.z) > 100.0:
			continue
		var gy: float = W.height(c.x, c.z)
		var bottom := bb.position.y - gy
		var sx := bb.size.x
		var sz := bb.size.z
		var sy := bb.size.y
		if maxf(sx, sz) > 28.0 or sy < 0.55 or minf(sx, sz) < 0.2:
			continue
		var nm := String(m.name)
		var mat := m.material_override if m.material_override != null else m.mesh.surface_get_material(0)
		var mn := mat.resource_name if mat != null else ""
		var key := "%s|%s|%.1fx%.1fx%.1f" % [nm.rstrip("0123456789@"), mn, snappedf(sx, 0.2), snappedf(sy, 0.2), snappedf(sz, 0.2)]
		if bottom > 0.3 and bottom < 2.2 and sy < 3.0:
			if not floats.has(key):
				floats[key] = []
			floats[key].append(Vector3(c.x / D.SC, bottom, c.z / D.SC))
			continue
		if bottom > 0.5:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(0.1, sx * 0.5), 0.5, maxf(0.1, sz * 0.5))
		q.shape = box
		q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, gy + 0.75, c.z))
		if space.intersect_shape(q, 1).is_empty():
			if not groups.has(key):
				groups[key] = []
			groups[key].append(Vector2(c.x / D.SC, c.z / D.SC))
	var keys := groups.keys()
	keys.sort()
	out.append("BEZ KOLIZJI: %d rodzajów" % keys.size())
	for k in keys:
		var arr: Array = groups[k]
		var ex := ""
		for i in range(mini(3, arr.size())):
			ex += " (%.0f, %.0f)" % [arr[i].x, arr[i].y]
		out.append("  %3d x %s  np.%s" % [arr.size(), k, ex])
	var fk := floats.keys()
	fk.sort()
	out.append("NAD ZIEMIĄ (0,3–2,2 m): %d rodzajów" % fk.size())
	for k in fk:
		var arr2: Array = floats[k]
		var ex2 := ""
		for i in range(mini(3, arr2.size())):
			ex2 += " (%.0f, %.0f, +%.1f m)" % [arr2[i].x, arr2[i].z, arr2[i].y]
		out.append("  %3d x %s  np.%s" % [arr2.size(), k, ex2])
