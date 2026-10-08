extends Node3D
## Czynności przy prawdziwym stanowisku. Fikcyjny wsad, bez rzeczywistych receptur.
const Models = preload("res://scripts/models.gd")
var active := false
var kind := ""
var room := ""
var idx := -1
var recipe_id := ""
var variant := "pour"
var drops: CPUParticles3D
var elapsed := 0.0
var duration := 2.6
var applied := false
var tool: Node3D
var station: Node3D
var target := Vector3.ZERO
var start_yaw := 0.0
var start_pitch := 0.0
var end_yaw := 0.0
var end_pitch := 0.0
var result := {}

func allowed(what: String, at_room: String, index: int, rid := "") -> bool:
	var furniture: Dictionary = G.Prod.furn(at_room, index)
	if furniture.is_empty() or String(furniture["func"]) != "lab": return false
	var job = G.Prod.job(at_room, index)
	match what:
		"load":
			if job != null: return false
			for option in G.Prod.recipes_for(at_room, index):
				if String(option.id) == rid: return String(option.miss) == ""
		"continue": return job != null and int(job.hold) >= 0 and float(job.prog) < 1.0
		"collect": return job != null and float(job.prog) >= 1.0
	return false

func play(what: String, at_room: String, index: int, rid := "") -> bool:
	if active or G.busy or not allowed(what, at_room, index, rid): return false
	kind = what
	room = at_room
	idx = index
	recipe_id = rid
	result = {}
	applied = false
	if G.test_mode:
		return _apply()
	if G.player.loc != room: return false
	station = G.world.grow_nodes.get(room, {}).get(idx)
	if not is_instance_valid(station): return false
	active = true
	G.busy = true
	elapsed = 0.0
	duration = 3.0 if what == "load" else 2.6
	variant = "pour"
	if what == "continue":
		var action: String = G.Prod.stage_name(G.Prod.job(room, idx)).to_lower()
		variant = "filter" if action.contains("filtr") else ("scoop" if action.contains("zbierz") else "pour")
	var work_point := Vector3(0.25, 1.1, 0.45) if what == "load" else Vector3(0.2, 1.42, 0.05)
	if what == "collect" or variant == "scoop": work_point = Vector3(0.2, 1.1, 0.35)
	if variant == "filter": work_point.y = 1.32
	target = station.global_transform * work_point
	start_yaw = G.player.yaw
	start_pitch = G.player.pitch
	var direction: Vector3 = target - G.player.cam.global_position
	end_yaw = start_yaw + wrapf(atan2(-direction.x, -direction.z) - start_yaw, -PI, PI)
	end_pitch = clampf(atan2(direction.y, Vector2(direction.x, direction.z).length()), -1.3, 0.6)
	tool = Node3D.new()
	add_child(tool)
	var cardboard := Models.mat("968269", 0.96)
	var bottle := Models.mat("876042", 0.8)
	if what == "load":
		var count: int = D.RECIPES[rid].input.size()
		for slot in range(count):
			var box := Models.box(tool, Vector3(0.09, 0.14, 0.07), Vector3(float(slot) * 0.1, 0, 0), cardboard)
			Models.box(box, Vector3(0.075, 0.025, 0.073), Vector3(0, 0.025, 0), Models.mat(["788573", "6b7b8d", "96755a"][slot], 0.9))
	elif what == "continue" and variant == "filter":
		Models.cyl(tool, 0.065, 0.014, 0.11, Vector3.ZERO, Models.mat("d4ccbb", 0.97), Vector3.ZERO, 16)
	elif what == "continue" and variant == "scoop":
		var steel := Models.mat("a8aba8", 0.45, 0.6)
		Models.box(tool, Vector3(0.16, 0.012, 0.012), Vector3.ZERO, steel)
		Models.sphere(tool, 0.035, Vector3(0.1, 0, 0), steel, Vector3(1, 0.18, 0.7))
	elif what == "continue":
		Models.cyl(tool, 0.055, 0.045, 0.17, Vector3.ZERO, bottle, Vector3.ZERO, 16)
		Models.cyl(tool, 0.022, 0.022, 0.04, Vector3(0, 0.1, 0), Models.mat("c5c5bd", 0.65), Vector3.ZERO, 12)
	else:
		Models.box(tool, Vector3(0.24, 0.025, 0.18), Vector3.ZERO, Models.mat("b6b7b0", 0.5, 0.35))
		Models.box(tool, Vector3(0.12, 0.03, 0.08), Vector3(0, 0.02, 0), Models.mat("d4d0c5", 0.98))
	if what == "continue" and variant == "pour":
		drops = CPUParticles3D.new()
		drops.emitting = false
		drops.local_coords = false
		drops.amount = 18
		drops.lifetime = 0.3
		drops.direction = Vector3.DOWN
		drops.spread = 8.0
		drops.gravity = Vector3(0, -2.0, 0)
		drops.initial_velocity_min = 0.12
		drops.initial_velocity_max = 0.22
		var mesh := SphereMesh.new()
		mesh.radius = 0.003
		mesh.height = 0.006
		mesh.radial_segments = 6
		mesh.rings = 3
		mesh.material = Models.mat("d5c393", 0.5)
		drops.mesh = mesh
		add_child(drops)
		drops.top_level = true
	tool.global_position = _hand()
	Sfx.play("pack")
	return true

func _hand() -> Vector3:
	var camera: Camera3D = G.player.cam
	return camera.global_position + camera.global_transform.basis * Vector3(0.28, -0.28, -0.42)

func _process(dt: float) -> void:
	if not active: return
	if not G.running or G.player.loc != room or not is_instance_valid(station):
		_end()
		return
	if has_meta("preview_phase"):
		elapsed = duration * float(get_meta("preview_phase"))
	else:
		elapsed += dt
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var look := smoothstep(0.0, 0.4, elapsed)
	G.player.yaw = lerpf(start_yaw, end_yaw, look)
	G.player.pitch = lerpf(start_pitch, end_pitch, look)
	G.player.rotation.y = G.player.yaw
	G.player.cam.rotation.x = G.player.pitch
	var arrive := smoothstep(0.0, 0.3, progress)
	var leave := smoothstep(0.78, 1.0, progress)
	tool.global_position = _hand().lerp(target, arrive).lerp(_hand(), leave)
	tool.global_rotation = Vector3(0, G.player.yaw, sin(progress * PI) * (-0.7 if kind == "continue" and variant == "pour" else 0.08))
	if kind == "collect": tool.global_position.y += sin(progress * PI) * 0.06
	if kind == "continue" and variant == "scoop":
		tool.global_position += station.global_transform.basis.x * sin(progress * PI * 4.0) * 0.045
	if kind == "continue" and variant == "filter":
		tool.global_rotation.z = sin(progress * PI * 6.0) * 0.12
	if is_instance_valid(drops):
		drops.global_position = tool.global_transform * Vector3(0, 0.12, 0)
		drops.emitting = progress > 0.35 and progress < 0.72
	G.ui.set_prompt({"load": "Układasz wsad", "continue": "Pracujesz przy stanowisku", "collect": "Zbierasz partię"}[kind], progress, false)
	if progress >= 0.58 and not applied: _apply()
	if progress >= 1.0: _end()

func _apply() -> bool:
	if applied: return false
	applied = true
	if not allowed(kind, room, idx, recipe_id): return false
	var success := false
	match kind:
		"load": success = G.Prod.start(room, idx, recipe_id)
		"continue": success = G.Prod.proceed(room, idx)
		"collect":
			result = G.Prod.collect(room, idx)
			success = not result.is_empty()
	if success:
		G.world.update_stations()
		Sfx.play("pickup" if kind == "collect" else "place")
	return success

func _end() -> void:
	active = false
	G.busy = false
	if is_instance_valid(tool): tool.queue_free()
	tool = null
	if is_instance_valid(drops): drops.queue_free()
	drops = null
	G.ui.set_prompt("")
