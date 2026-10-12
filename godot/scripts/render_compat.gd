extends RefCounted
## OpenGL has a small shared buffer for instance uniforms. Use a private
## material per mesh in Compatibility; retain instance uniforms in Vulkan.

static func enabled() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"

static func shader_code(source: String) -> String:
	return source.replace("instance uniform", "uniform") if enabled() else source

static func set_parameter(mesh: MeshInstance3D, parameter: StringName, value: Variant) -> void:
	if not enabled():
		mesh.set_instance_shader_parameter(parameter, value)
		return
	if mesh.material_override is ShaderMaterial:
		mesh.material_override = _private_material(mesh.material_override, mesh.get_instance_id())
		(mesh.material_override as ShaderMaterial).set_shader_parameter(parameter, value)
	elif mesh.mesh != null:
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface)
			if material is ShaderMaterial:
				var own := _private_material(material, mesh.get_instance_id())
				mesh.set_surface_override_material(surface, own)
				own.set_shader_parameter(parameter, value)

static func _private_material(material: ShaderMaterial, owner_id: int) -> ShaderMaterial:
	if material.get_meta("compat_owner", 0) == owner_id:
		return material
	var own := material.duplicate() as ShaderMaterial
	own.set_meta("compat_owner", owner_id)
	return own
