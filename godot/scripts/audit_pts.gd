extends Node
## pomocniczo: co blokuje wskazane punkty planu (--pts=x:z;x:z)
func _ready() -> void:
	var W = G.world
	for s in String(G.main.args.get("pts", "")).split(";", false):
		var xz := s.split(":")
		var p := Vector2(float(xz[0]), float(xz[1])) * D.SC
		var hits := []
		for b in W.blocks:
			if p.x > float(b.x0) - 0.3 and p.x < float(b.x1) + 0.3 and p.y > float(b.z0) - 0.3 and p.y < float(b.z1) + 0.3:
				hits.append("[%.1f..%.1f, %.1f..%.1f h=%.1f]" % [float(b.x0) / D.SC, float(b.x1) / D.SC, float(b.z0) / D.SC, float(b.z1) / D.SC, float(b.h)])
		print("PKT (%s): %s" % [s, ", ".join(hits)])
	get_tree().quit()
