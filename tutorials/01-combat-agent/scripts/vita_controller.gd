extends CharacterBody3D

signal damaged(amount: float, remaining_health: float)
signal defeated
signal hit_reaction_started
signal dodge_started(kind: String, direction: Vector3)
signal damage_avoided(amount: float)

@export var walk_speed := 2.0
@export var run_speed := 4.5
@export var acceleration := 14.0
@export var jump_velocity := 6.2
@export var gravity := 18.0
@export var turn_speed := 12.0
@export var max_health := 100.0

@onready var visual: Node3D=$VisualPivot
@onready var model: Node3D=$VisualPivot/Model
@onready var camera_rig: Node3D=$CameraRig
@onready var pitch: Node3D=$CameraRig/Pitch
@onready var arm: SpringArm3D=$CameraRig/Pitch/SpringArm3D
@onready var camera: Camera3D=$CameraRig/Pitch/SpringArm3D/Camera3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var hips := -1
var rest_hips := Vector3.ZERO
var spawn_position := Vector3.ZERO
var orbiting := false
var movement_enabled := false
var animation_state := ""
var selected_clip := ""
var landed_time := 0.0
var jumped := false
var jump_clock := 0.0
var airborne_clock := 0.0
var weapon_actions: Node
var equipped := false
var action := ""
var action_left := 0.0
var action_duration := 0.0
var dodge_direction := Vector3.ZERO
var dodge_cooldown := 0.0
var health := 100.0
var damage_events := 0
var hit_reaction_left := 0.0
var external_control := false
var combat_target: Node3D
var combat_move_world := Vector3.ZERO
var combat_fire := false
var combat_dodge_request := Vector3.ZERO

func _ready() -> void:
	player=model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	skeleton=model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	hips=skeleton.find_bone("mixamorig_Hips")
	rest_hips=skeleton.get_bone_global_rest(hips).origin
	for clip in ["Short_Breathe_and_Look_Around","Walking_Woman","Running","Jump_Run","Roll_Dodge_1","_360_Power_Spin_Jump","Walk_Forward_While_Shooting","Walk_Backward_While_Shooting_inplace","Run_and_Shoot","Hit_Reaction"]:
		assert(player.has_animation(clip),"Missing required Vita animation: "+clip)
	for clip in ["Short_Breathe_and_Look_Around","Walking_Woman","Running","Walk_Forward_While_Shooting","Walk_Backward_While_Shooting_inplace","Run_and_Shoot"]:player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	for clip in ["Jump_Run","Roll_Dodge_1","_360_Power_Spin_Jump","Hit_Reaction"]:player.get_animation(clip).loop_mode=Animation.LOOP_NONE
	arm.add_excluded_object(get_rid())
	apply_cel()
	weapon_actions=load("res://scripts/rifle_actions.gd").new()
	weapon_actions.name="RifleActions"
	add_child(weapon_actions)
	weapon_actions.setup(self,skeleton,model)
	camera_rig.global_position=global_position+Vector3.UP*1.30
	play_clip("Short_Breathe_and_Look_Around","IDLE")
	print("VITA READY: ",player.get_animation_list().size()," clips, ",skeleton.get_bone_count()," bones")

func apply_cel() -> void:
	for node in model.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		for i in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(i) as BaseMaterial3D
			assert(original!=null)
			var mat := ShaderMaterial.new()
			mat.shader=load("res://shaders/eden_toon.gdshader")
			mat.set_shader_parameter("base_color",original.albedo_color)
			var texture_: Texture2D=original.albedo_texture
			if texture_==null:
				var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
				image.fill(Color.WHITE)
				texture_=ImageTexture.create_from_image(image)
			mat.set_shader_parameter("base_texture",texture_)
			var outline := ShaderMaterial.new()
			outline.shader=load("res://shaders/outline.gdshader")
			outline.set_shader_parameter("width",.00015)
			mat.next_pass=outline
			mesh.set_surface_override_material(i,mat)

func play_clip(clip: String,state: String,blend := .16) -> void:
	animation_state=state
	if selected_clip!=clip:
		selected_clip=clip
		player.play(clip,blend)
	elif not player.is_playing():player.play()

func respawn(point: Vector3) -> void:
	global_position=point
	spawn_position=point
	velocity=Vector3.ZERO
	visual.rotation.y=PI
	camera_rig.rotation.y=0
	camera_rig.global_position=point+Vector3.UP*1.30
	jumped=false
	landed_time=0
	airborne_clock=0
	action=""
	action_left=0
	dodge_cooldown=0
	health=max_health
	damage_events=0
	hit_reaction_left=0
	external_control=false
	combat_target=null
	combat_move_world=Vector3.ZERO
	combat_fire=false
	combat_dodge_request=Vector3.ZERO
	player.speed_scale=1
	equipped=false
	weapon_actions.set_drawn(false)
	selected_clip=""
	play_clip("Short_Breathe_and_Look_Around","IDLE",0)
	model.position=Vector3.ZERO
	movement_enabled=true

func apply_damage(amount: float) -> void:
	if amount<=0 or health<=0:return
	if action in ["ROLL","SPIN DODGE"]:
		damage_avoided.emit(amount)
		return
	health=maxf(0,health-amount)
	damage_events+=1
	damaged.emit(amount,health)
	if health<=0:
		movement_enabled=false
		velocity=Vector3.ZERO
		defeated.emit()
	else:
		start_hit_reaction()

func start_hit_reaction() -> void:
	hit_reaction_left=player.get_animation("Hit_Reaction").length
	action=""
	action_left=0
	player.speed_scale=1
	selected_clip=""
	play_clip("Hit_Reaction","HIT",.04)
	weapon_actions.set_drawn(false)
	hit_reaction_started.emit()

func process_hit_reaction(delta: float) -> void:
	hit_reaction_left=maxf(0,hit_reaction_left-delta)
	velocity.x=move_toward(velocity.x,0.0,acceleration*delta)
	velocity.z=move_toward(velocity.z,0.0,acceleration*delta)
	if not is_on_floor():velocity.y-=gravity*delta
	elif velocity.y<0:velocity.y=-.1
	animation_state="HIT"
	move_and_slide()
	if hit_reaction_left<=0:
		selected_clip=""
		weapon_actions.set_drawn(equipped)

func start_dodge(kind: String,direction: Vector3) -> void:
	action=kind
	action_duration=.78 if kind=="ROLL" else 1.20
	action_left=action_duration
	dodge_cooldown=action_duration+.20
	dodge_direction=direction if direction.length_squared()>.01 else visual.global_basis.z
	dodge_direction.y=0
	dodge_direction=dodge_direction.normalized()
	visual.rotation.y=atan2(dodge_direction.x,dodge_direction.z)
	var clip := "Roll_Dodge_1" if kind=="ROLL" else "_360_Power_Spin_Jump"
	selected_clip=""
	play_clip(clip,kind,.06)
	player.speed_scale=player.get_animation(clip).length/action_duration
	weapon_actions.set_drawn(false)
	jumped=false
	if kind=="SPIN DODGE":velocity.y=6.0
	dodge_started.emit(kind,dodge_direction)

func set_combat_command(move_world: Vector3,target_: Node3D,fire_: bool,dodge_: Vector3=Vector3.ZERO) -> void:
	external_control=true
	combat_move_world=move_world
	combat_target=target_
	combat_fire=combat_fire or fire_
	if dodge_.length_squared()>.01:
		combat_dodge_request=dodge_.normalized()

func clear_combat_command() -> void:
	external_control=false
	combat_target=null
	combat_move_world=Vector3.ZERO
	combat_fire=false
	combat_dodge_request=Vector3.ZERO

func process_dodge(delta: float) -> void:
	action_left-=delta
	velocity.x=dodge_direction.x*(4.2 if action=="ROLL" else 3.0)
	velocity.z=dodge_direction.z*(4.2 if action=="ROLL" else 3.0)
	if not is_on_floor():velocity.y-=(10.0 if action=="SPIN DODGE" else gravity)*delta
	elif velocity.y<0:velocity.y=-.1
	animation_state=action
	move_and_slide()
	if action_left<=0:
		action=""
		player.speed_scale=1
		selected_clip=""
		weapon_actions.set_drawn(equipped)

func _physics_process(delta: float) -> void:
	if not movement_enabled:return
	dodge_cooldown=maxf(0,dodge_cooldown-delta)
	if hit_reaction_left>0:
		process_hit_reaction(delta)
		return
	var grounded := is_on_floor()
	var input := Input.get_vector("move_left","move_right","move_forward","move_backward") if not external_control else Vector2.ZERO
	var direction := camera_rig.global_basis.x*input.x+camera_rig.global_basis.z*input.y if not external_control else combat_move_world
	direction.y=0
	if direction.length_squared()>1.0:direction=direction.normalized()
	if not external_control and Input.is_action_just_pressed("equip_weapon"):equipped=not equipped
	if action.is_empty() and grounded and dodge_cooldown<=0:
		if external_control and combat_dodge_request.length_squared()>.01:
			start_dodge("ROLL",combat_dodge_request)
			combat_dodge_request=Vector3.ZERO
		elif Input.is_action_just_pressed("dodge_roll"):start_dodge("ROLL",direction)
		elif Input.is_action_just_pressed("spin_dodge"):start_dodge("SPIN DODGE",direction)
	if not action.is_empty():
		process_dodge(delta)
		return
	var fire_requested := combat_fire if external_control else Input.is_action_pressed("fire")
	var armed := external_control or equipped or Input.is_action_pressed("aim") or fire_requested
	weapon_actions.set_drawn(armed)
	var speed := run_speed if (not external_control and Input.is_action_pressed("sprint")) else walk_speed
	velocity.x=move_toward(velocity.x,direction.x*speed,acceleration*delta)
	velocity.z=move_toward(velocity.z,direction.z*speed,acceleration*delta)
	var facing := -camera_rig.global_basis.z if armed else direction
	if external_control and is_instance_valid(combat_target):
		facing=combat_target.global_position-global_position
		facing.y=0
	if facing.length_squared()>.01:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(facing.x,facing.z),1-exp(-turn_speed*delta))
	if not grounded:velocity.y-=gravity*delta
	elif velocity.y<0:velocity.y=-.1
	if grounded and Input.is_action_just_pressed("jump"):
		velocity.y=jump_velocity
		jumped=true
		jump_clock=0
		selected_clip=""
		play_clip("Jump_Run","JUMP",.08)
		player.seek(.40,true)
	if not grounded:airborne_clock+=delta
	else:airborne_clock=0
	if jumped:jump_clock+=delta
	move_and_slide()
	if is_on_floor() and not grounded and jumped:
		jumped=false
		landed_time=.16
		player.play("Jump_Run",.06)
		player.seek(1.55,true)
		selected_clip="Jump_Run"
		animation_state="LAND"
	elif not is_on_floor() and (jumped or airborne_clock>.10):
		if not jumped and selected_clip!="Jump_Run":
			play_clip("Jump_Run","FALL",.10)
			player.seek(.90,true)
		animation_state="JUMP" if velocity.y>0 else "FALL"
		if player.current_animation_position>1.18:player.pause()
	elif landed_time>0:
		landed_time-=delta
	else:
		var horizontal_speed := Vector2(velocity.x,velocity.z).length()
		if armed:
			if horizontal_speed<.15:
				play_clip("Walk_Forward_While_Shooting","AIM")
				player.seek(.30,true)
				player.pause()
			elif not external_control and Input.is_action_pressed("sprint"):play_clip("Run_and_Shoot","RUN / RIFLE")
			elif input.y>.15:play_clip("Walk_Backward_While_Shooting_inplace","BACKWARD / RIFLE")
			else:play_clip("Walk_Forward_While_Shooting","WALK / RIFLE")
		else:
			if horizontal_speed<.15:play_clip("Short_Breathe_and_Look_Around","IDLE")
			elif Input.is_action_pressed("sprint"):play_clip("Running","RUN")
			else:play_clip("Walking_Woman","WALK")
	if armed and grounded and fire_requested:
		skeleton.force_update_all_bone_transforms()
		var fired: bool
		if external_control and is_instance_valid(combat_target):
			fired=weapon_actions.shoot_at(combat_target.global_position+Vector3.UP*.85)
		else:
			fired=weapon_actions.shoot()
		if external_control and fired:
			combat_fire=false
	if global_position.y < -15:respawn(spawn_position)

func _process(delta: float) -> void:
	if not is_instance_valid(skeleton):return
	var pose := skeleton.get_bone_global_pose(hips).origin
	# Physics owns travel. Remove imported horizontal root motion from the visual only.
	model.position.x=rest_hips.x-pose.x
	model.position.z=rest_hips.z-pose.z
	model.position.y=rest_hips.y-pose.y if jumped or action=="SPIN DODGE" or animation_state in ["FALL","LAND"] else 0.0
	camera_rig.global_position=camera_rig.global_position.lerp(global_position+Vector3.UP*1.30,1-exp(-12*delta))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:orbiting=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:arm.spring_length=max(2.0,arm.spring_length-.35)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:arm.spring_length=min(8.0,arm.spring_length+.35)
	if event is InputEventMouseMotion and orbiting:
		camera_rig.rotation.y-=event.relative.x*.004
		pitch.rotation.x=clampf(pitch.rotation.x-event.relative.y*.003,-.65,.12)
	if event.is_action_pressed("reset_player"):respawn(spawn_position)
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:orbiting=false
