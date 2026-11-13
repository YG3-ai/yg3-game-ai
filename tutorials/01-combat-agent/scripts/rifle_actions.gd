extends Node

signal fired(origin: Vector3,direction: Vector3,hit_position: Vector3)

var wielder: CharacterBody3D
var skeleton: Skeleton3D
var rifle: Node3D
var muzzle: Node3D
var hand_socket: BoneAttachment3D
var back_parent: Node3D
var back_transform := Transform3D.IDENTITY
var drawn := false
var cooldown := 0.0
var shots_fired := 0
var last_origin := Vector3.ZERO
var last_direction := Vector3.ZERO
var last_hit: Dictionary={}
var aim_point := Vector3.ZERO
var effects: Array=[]

func setup(character: CharacterBody3D,rig: Skeleton3D,model: Node3D) -> void:
	wielder=character
	skeleton=rig
	rifle=model.find_child("eden_rifle_v001",true,false) as Node3D
	assert(rifle!=null)
	muzzle=rifle.find_child("Muzzle",true,false) as Node3D
	assert(muzzle!=null)
	back_parent=rifle.get_parent()
	back_transform=rifle.transform
	hand_socket=BoneAttachment3D.new()
	hand_socket.name="RifleHandSocket"
	hand_socket.bone_name="mixamorig_RightHand"
	skeleton.add_child(hand_socket)

func set_drawn(value: bool) -> void:
	if value==drawn:return
	drawn=value
	if drawn:
		rifle.reparent(hand_socket,false)
		rifle.transform=Transform3D(Basis(Vector3.LEFT,Vector3.BACK,Vector3.UP).scaled(Vector3.ONE*.82),Vector3(0,.065,.020))
	else:
		rifle.reparent(back_parent,false)
		rifle.transform=back_transform

func _physics_process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	if drawn:
		var origin := muzzle.global_position
		aim_point=origin+muzzle.global_basis.z.normalized()*300
		var query := PhysicsRayQueryParameters3D.create(origin,aim_point,1)
		query.exclude=[wielder.get_rid()]
		var hit := wielder.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():aim_point=hit.position
	for i in range(effects.size()-1,-1,-1):
		effects[i].life-=delta
		if effects[i].life<=0:
			effects[i].node.queue_free()
			effects.remove_at(i)

func spark(point: Vector3,radius: float,life: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius=radius
	mesh.height=radius*2
	node.mesh=mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(1,.68,.18)
	mat.emission_enabled=true
	mat.emission=Color(1,.4,.06)
	node.material_override=mat
	wielder.get_tree().current_scene.add_child(node)
	node.global_position=point
	effects.append({"node":node,"life":life})

func shoot() -> bool:
	return shoot_direction(muzzle.global_basis.z.normalized())

func shoot_at(point: Vector3) -> bool:
	return shoot_direction((point-muzzle.global_position).normalized())

func shoot_direction(direction: Vector3) -> bool:
	if not drawn or cooldown>0:return false
	cooldown=.16
	shots_fired+=1
	last_origin=muzzle.global_position
	last_direction=direction.normalized()
	var endpoint := last_origin+last_direction*300
	var ray := PhysicsRayQueryParameters3D.create(last_origin,endpoint,1)
	ray.exclude=[wielder.get_rid()]
	last_hit=wielder.get_world_3d().direct_space_state.intersect_ray(ray)
	if not last_hit.is_empty():
		endpoint=last_hit.position
		var collider: Object=last_hit.collider
		if collider.has_method("apply_damage"):collider.call("apply_damage",10)
		spark(endpoint,.04,.35)
	spark(last_origin,.045,.055)
	var tracer := MeshInstance3D.new()
	var line := CylinderMesh.new()
	line.top_radius=.005
	line.bottom_radius=.005
	line.height=last_origin.distance_to(endpoint)
	tracer.mesh=line
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(1,.85,.35)
	tracer.material_override=material
	wielder.get_tree().current_scene.add_child(tracer)
	tracer.look_at_from_position((last_origin+endpoint)*.5,endpoint,Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT,PI/2)
	effects.append({"node":tracer,"life":.065})
	fired.emit(last_origin,last_direction,endpoint)
	return true
