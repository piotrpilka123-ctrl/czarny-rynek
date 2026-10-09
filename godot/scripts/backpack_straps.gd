extends SkeletonModifier3D
## Miękkie szelki: końce na plecaku, odcinek przedni dopasowany do barków i klatki.
var bag: Node3D
var skeleton: Skeleton3D
var arms: Array = []
var chest := -1
var ribbons: Array = []
var buckles: Array = []
var control_points: Array = []
var material: StandardMaterial3D
var front_depth:=0.13
var shoulder_raise:=0.05

func bind(sk: Skeleton3D, backpack: Node3D) -> bool:
	skeleton=sk
	bag=backpack
	chest=sk.find_bone("Bip01 Spine2")
	if chest<0: return false
	for side in ["R", "L"]:
		var upper:=sk.find_bone("Bip01 "+side+" UpperArm")
		var fore:=sk.find_bone("Bip01 "+side+" Forearm")
		if min(upper,fore)<0: return false
		arms.append([upper,fore])
	process_mode=Node.PROCESS_MODE_ALWAYS
	return true

func _ready() -> void:
	fit_clothes()
	material=StandardMaterial3D.new()
	material.albedo_color=Color("252c30").srgb_to_linear()
	material.roughness=0.95
	material.metallic_specular=0.15
	material.normal_enabled=true
	material.normal_texture=load("res://assets/wear/plotno_n.png")
	material.normal_scale=0.3
	for side in range(2):
		var ribbon:=MeshInstance3D.new()
		ribbon.mesh=ArrayMesh.new()
		ribbon.material_override=material
		ribbon.layers=2
		ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(ribbon)
		ribbons.append(ribbon)
		buckles.append(bag.shell.find_child("Regulator_L" if side==0 else "Regulator_P",true,false))
	call_deferred("fit_after_pose")

func fit_after_pose() -> void:
	await get_tree().process_frame
	fit_clothes()

func fit_clothes() -> void:
	var center:=skeleton.to_global(skeleton.get_bone_global_pose(chest).origin)
	var r:=skeleton.to_global(skeleton.get_bone_global_pose(arms[0][0]).origin)
	var l:=skeleton.to_global(skeleton.get_bone_global_pose(arms[1][0]).origin)
	var right:Vector3=(r-l).normalized()
	var width:float=r.distance_to(l)
	var front:=Vector3.UP.cross(right).normalized()
	var depth:=0.0
	var top:float=(r.y+l.y)*0.5
	for node in skeleton.get_children():
		if not node is MeshInstance3D: continue
		var hidden_parts=node.get_instance_shader_parameter("w_hide")
		# Oryginalny gruby strój znika pod nowym ubraniem; nie mierzymy ukrytej siatki.
		if hidden_parts is Vector4 and hidden_parts.x>0.5: continue
		var mesh:Mesh=node.mesh
		var skin:Skin=node.skin
		var transforms:Array=[]
		if skin!=null:
			for bind_index in range(skin.get_bind_count()):
				var bone:int=skin.get_bind_bone(bind_index)
				var bone_name:String=skin.get_bind_name(bind_index)
				if not bone_name.is_empty(): bone=skeleton.find_bone(bone_name)
				transforms.append(skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind_index) if bone>=0 else Transform3D.IDENTITY)
		for surface in range(mesh.get_surface_count()):
			var mat:Material=mesh.surface_get_material(surface)
			if mat!=null and (mat.resource_name.to_lower().ends_with("head") or mat.resource_name.to_lower().ends_with("opacity")): continue
			var arrays:Array=mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones=arrays[Mesh.ARRAY_BONES]
			var weights=arrays[Mesh.ARRAY_WEIGHTS]
			var stride:int=bones.size()/maxi(1,vertices.size()) if bones!=null else 0
			for vertex_index in range(vertices.size()):
				var posed:Vector3=vertices[vertex_index]
				if stride>0 and not transforms.is_empty():
					posed=Vector3.ZERO
					for slot in range(stride):
						var bone_index:int=bones[vertex_index*stride+slot]
						var weight:float=weights[vertex_index*stride+slot]
						if weight>0.0 and bone_index<transforms.size(): posed+=(transforms[bone_index]*vertices[vertex_index])*weight
				var point:Vector3=skeleton.to_global(posed) if stride>0 and skin!=null else node.to_global(posed)
				var offset:Vector3=point-center
				var side:float=absf(offset.dot(right))
				if offset.y> -width*0.7 and offset.y<width*0.3 and side>width*0.20 and side<width*0.40:
					depth=maxf(depth,offset.dot(front))
				if side>width*0.25 and side<width*0.47 and point.y<maxf(r.y,l.y)+width*0.4:
					top=maxf(top,point.y)
	front_depth=clampf(depth+0.012,width*0.12,width*0.6)
	shoulder_raise=clampf(top-(r.y+l.y)*0.5+0.008,width*0.03,width*0.25)

func _process_modification_with_delta(_dt: float) -> void:
	update_straps()

func update_straps() -> void:
	if not is_instance_valid(bag): return
	var viewport:=get_viewport() as SubViewport
	if viewport!=null and viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED: return
	visible=bag.visible
	if not visible: return
	var center:=skeleton.to_global(skeleton.get_bone_global_pose(chest).origin)
	var shoulder_r:=skeleton.to_global(skeleton.get_bone_global_pose(arms[0][0]).origin)
	var shoulder_l:=skeleton.to_global(skeleton.get_bone_global_pose(arms[1][0]).origin)
	var across:=shoulder_r-shoulder_l
	var width:=across.length()
	var right:=across.normalized()
	var front:=center-bag.global_position
	front.y=0.0
	front=front.normalized()
	control_points.clear()
	for side in range(2):
		var sign_side:=1.0 if side==0 else -1.0
		var shoulder:=shoulder_r if side==0 else shoulder_l
		var elbow:=skeleton.to_global(skeleton.get_bone_global_pose(arms[side][1]).origin)
		var alignment:=1.0 if bag.shell.global_basis.x.dot(right)>0.0 else -1.0
		var x:float=sign_side*alignment*0.10
		var start:Vector3=bag.shell.to_global(Vector3(x,0.16,-0.067))
		var end:Vector3=bag.shell.to_global(Vector3(x,-0.175,-0.075))
		var top:=shoulder-right*sign_side*width*0.15+Vector3.UP*(shoulder_raise+0.015)+(elbow-shoulder).normalized()*width*0.02
		var chest_front:=center+right*sign_side*width*0.30+front*front_depth-Vector3.UP*width*0.08
		var lower:=center+right*sign_side*width*0.35+front*front_depth-Vector3.UP*width*0.55
		var flank:=center+right*sign_side*width*0.48-Vector3.UP*width*0.66
		var points: Array = [start, top-front*front_depth*0.3, top+front*front_depth*0.6, chest_front, lower, flank, end]
		control_points.append(points)
		build(ribbons[side],points,right,width*0.09)
		var buckle: Node3D=buckles[0 if x<0.0 else 1]
		if buckle!=null:
			var up:Vector3=(chest_front-lower).normalized()
			var normal:=right.cross(up).normalized()
			buckle.global_transform=Transform3D(Basis(right,up,normal).orthonormalized(),lower)

func build(ribbon: MeshInstance3D, points: Array, right: Vector3, strap_width: float) -> void:
	var path:=Curve3D.new()
	for i in range(points.size()):
		var point:Vector3=points[i]
		var before:Vector3=points[maxi(0,i-1)]
		var after:Vector3=points[mini(points.size()-1,i+1)]
		var tangent:Vector3=(after-before)*0.15
		path.add_point(point,-tangent if i>0 else Vector3.ZERO,tangent if i<points.size()-1 else Vector3.ZERO)
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var tangents:=PackedFloat32Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	var length:=path.get_baked_length()
	for i in range(25):
		var t:=float(i)/24.0
		var point:=path.sample_baked(t*length,true)
		var tangent:Vector3=path.sample_baked(minf(length,(t+0.01)*length),true)-path.sample_baked(maxf(0,(t-0.01)*length),true)
		tangent=tangent.normalized()
		var across:Vector3=(right-tangent*right.dot(tangent)).normalized()
		var normal:=across.cross(tangent).normalized()
		for corner in range(4):
			var offset:=across*strap_width*(0.5 if corner%2==0 else -0.5)+normal*(0.002 if corner<2 else -0.002)
			vertices.append(to_local(point+offset))
			normals.append(global_basis.inverse()*(normal if corner<2 else -normal))
			var local_tangent:Vector3=(global_basis.inverse()*-across).normalized()
			tangents.append_array(PackedFloat32Array([local_tangent.x,local_tangent.y,local_tangent.z,-1.0 if corner<2 else 1.0]))
			uv.append(Vector2(float(corner%2),t*6.0))
		if i>0:
			var a: int=(i-1)*4
			var b: int=i*4
			for edge in [[0,1],[1,3],[3,2],[2,0]]:
				indices.append_array(PackedInt32Array([a+edge[0],b+edge[0],a+edge[1],a+edge[1],b+edge[0],b+edge[1]]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TANGENT]=tangents
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh: ArrayMesh=ribbon.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
