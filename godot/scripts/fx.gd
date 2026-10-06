extends RefCounted
## Efekty specjalne: eksplozja (błysk, kula ognia, dym, iskry, fala uderzeniowa) i pożar.

const Props = preload("res://scripts/props.gd")
const Models = preload("res://scripts/models.gd")


## jednorazowy wyrzut cząstek we wszystkie strony
static func _burst(amount: int, life: float, size: float, additive: bool, ramp: Array, speed: Vector2, radius: float, gravity: Vector3, grow: Vector2, damp := 2.5) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.94
	p.randomness = 0.4
	p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 70, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = gravity
	pm.damping_min = damp
	pm.damping_max = damp * 1.6
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, grow.x))
	sc.add_point(Vector2(1.0, grow.y))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	gr.colors = PackedColorArray(ramp)
	var grt := GradientTexture1D.new()
	grt.gradient = gr
	pm.color_ramp = grt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Props._soft_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = true
	return p


## Eksplozja w punkcie `pos` (skala 1 = wybuch butli, 3 = pół hali w powietrze). Sama się sprząta.
static func explosion(parent: Node, pos: Vector3, s := 1.0, sound := true) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	g.global_position = pos
	# błysk
	var li := OmniLight3D.new()
	li.light_color = Color(1.0, 0.72, 0.38)
	li.light_energy = 42.0 * s
	li.omni_range = 46.0 * s
	li.omni_attenuation = 0.9
	li.shadow_enabled = false
	li.position = Vector3(0, 1.0, 0)
	g.add_child(li)
	var tw := g.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(li, "light_energy", 6.0 * s, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(li, "light_energy", 0.0, 2.2)
	# kula ognia, jej ciemniejący płaszcz, dym, iskry i odłamki
	g.add_child(_burst(int(46 * minf(s, 2.5)), 1.1, 3.2 * s, true, [Color(1.0, 0.98, 0.85, 1.0), Color(1.0, 0.72, 0.22, 0.95), Color(0.9, 0.28, 0.05, 0.6), Color(0.2, 0.03, 0.0, 0.0)], Vector2(3.0, 11.0) * s, 0.8 * s, Vector3(0, 3.0, 0), Vector2(0.5, 1.9)))
	g.add_child(_burst(int(30 * minf(s, 2.5)), 2.4, 4.4 * s, false, [Color(0.5, 0.2, 0.05, 0.0), Color(0.22, 0.1, 0.05, 0.8), Color(0.08, 0.07, 0.07, 0.6), Color(0.1, 0.1, 0.1, 0.0)], Vector2(2.0, 8.0) * s, 1.0 * s, Vector3(0, 2.6, 0), Vector2(0.6, 2.2)))
	g.add_child(_burst(int(40 * minf(s, 2.5)), 6.5, 6.0 * s, false, [Color(0.05, 0.05, 0.05, 0.0), Color(0.07, 0.07, 0.07, 0.75), Color(0.14, 0.14, 0.14, 0.45), Color(0.2, 0.2, 0.2, 0.0)], Vector2(1.0, 5.0) * s, 1.6 * s, Vector3(0.6, 3.4, 0.2), Vector2(0.7, 2.6), 1.2))
	g.add_child(_burst(int(120 * minf(s, 2.0)), 1.9, 0.16 * (0.7 + s * 0.3), true, [Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.7, 0.25, 1.0), Color(1.0, 0.35, 0.08, 0.8), Color(0.5, 0.1, 0.0, 0.0)], Vector2(9.0, 26.0) * (0.6 + s * 0.4), 0.5 * s, Vector3(0, -11.0, 0), Vector2(1.0, 0.3), 0.6))
	g.add_child(_burst(int(26 * minf(s, 2.0)), 2.6, 0.34 * (0.7 + s * 0.3), false, [Color(0.1, 0.08, 0.07, 1.0), Color(0.12, 0.1, 0.09, 1.0), Color(0.1, 0.09, 0.08, 1.0), Color(0.1, 0.09, 0.08, 0.0)], Vector2(7.0, 19.0) * (0.6 + s * 0.4), 0.6 * s, Vector3(0, -13.0, 0), Vector2(1.0, 0.8), 0.3))
	# fala uderzeniowa: rozszerzający się pierścień nad ziemią
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 28
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(1.0, 0.85, 0.6, 0.5)
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.25, 1.0)
	ring.position = Vector3(0, 0.6, 0)
	g.add_child(ring)
	var tr := g.create_tween()
	tr.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tr.set_parallel(true)
	tr.tween_property(ring, "scale", Vector3(30.0 * s, 0.25, 30.0 * s), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tr.tween_property(rm, "albedo_color:a", 0.0, 0.7)
	if sound:
		Sfx.boom(-2.0 + s * 2.0)
	var tree := parent.get_tree()
	if tree != null:
		tree.create_timer(9.0, true, false, true).timeout.connect(func():
			if is_instance_valid(g):
				g.queue_free())
	return g


## pożar po wybuchu: płomienie, słup dymu i migające światło (zostaje, dopóki ktoś go nie usunie)
static func fire(parent: Node, pos: Vector3, s := 1.0, lights: Array = []) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	g.global_position = pos
	var fl := Props._particles(int(34 * s), 0.9, 1.5 * s, true, [Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.7, 0.2, 0.9), Color(1.0, 0.3, 0.05, 0.6), Color(0.4, 0.05, 0.0, 0.0)], Vector2(1.6, 3.4) * s, 0.9 * s, false)
	fl.visibility_aabb = AABB(Vector3(-8, -2, -8) * s, Vector3(16, 30, 16) * s)
	g.add_child(fl)
	var sm := Props._particles(int(22 * s), 7.0, 3.4 * s, false, [Color(0.06, 0.06, 0.06, 0.0), Color(0.08, 0.08, 0.08, 0.7), Color(0.15, 0.15, 0.15, 0.4), Color(0.25, 0.25, 0.25, 0.0)], Vector2(2.0, 3.6) * s, 0.8 * s, true)
	sm.position = Vector3(0, 1.5 * s, 0)
	sm.visibility_aabb = AABB(Vector3(-14, -2, -14) * s, Vector3(28, 60, 28) * s)
	g.add_child(sm)
	var li := OmniLight3D.new()
	li.position = Vector3(0, 1.2, 0)
	li.light_color = Color(1.0, 0.5, 0.18)
	li.light_energy = 5.0 * s
	li.omni_range = 22.0 * s
	li.shadow_enabled = false
	li.set_meta("fire", lights.size() * 1.3 + pos.x)
	li.set_meta("always", true)
	g.add_child(li)
	lights.append(li)
	return g
