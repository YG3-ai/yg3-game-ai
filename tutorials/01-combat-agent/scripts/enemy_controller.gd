extends CharacterBody3D

signal state_changed(previous: String, current: String)
signal punch_attempted(target: Node3D, connected: bool, distance: float)
signal damaged(amount: float, remaining_health: float)
signal defeated
signal dodge_started(direction: Vector3)
signal damage_avoided(amount: float)

@export var target_path: NodePath
@export var active := true
@export var walk_speed := 1.7
@export var run_speed := 3.6
@export var acceleration := 12.0
@export var gravity := 18.0
@export var chase_range := 22.0
@export var run_distance := 6.0
@export var punch_range := 1.65
@export var punch_damage := 10.0
@export var punch_contact_time := 0.72
@export var max_health := 30.0
@export var dodge_duration := 0.85
@export var dodge_speed := 4.8

@onready var visual: Node3D = $VisualPivot
@onready var model: Node3D = $VisualPivot/Model

var target: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var hips := -1
var rest_hips := Vector3.ZERO
var health := 0.0
var state := "SPAWNING"
var selected_clip := ""
var attack_clock := 0.0
var attack_committed := false
var cooldown := 0.0
var defensive_cooldown := 0.0
var dodge_clock := 0.0
var dodge_direction := Vector3.ZERO
var dodge_side := 1.0


func _ready() -> void:
	player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	hips = skeleton.find_bone("mixamorig_Hips")
	assert(hips >= 0, "Enemy Mixamo hips bone is missing")
	rest_hips = skeleton.get_bone_global_rest(hips).origin
	for clip in ["Walking", "Running", "Punch_Combo", "Roll_Dodge"]:
		assert(player.has_animation(clip), "Missing enemy animation: " + clip)
	for clip in ["Walking", "Running"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip in ["Punch_Combo", "Roll_Dodge"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_NONE
	health = max_health
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	set_state("IDLE")


func set_target(value: Node3D) -> void:
	target = value


func reset_combat(point: Vector3, target_: Node3D, health_: float = -1.0) -> void:
	active = false
	global_position = point
	velocity = Vector3.ZERO
	target = target_
	if health_ > 0.0:
		max_health = health_
	health = max_health
	attack_clock = 0.0
	attack_committed = false
	cooldown = 0.0
	defensive_cooldown = 0.0
	dodge_clock = 0.0
	dodge_direction = Vector3.ZERO
	player.speed_scale = 1.0
	selected_clip = ""
	set_state("IDLE")
	play_clip("Walking", 0.0)
	player.pause()


func set_state(value: String) -> void:
	if state == value:
		return
	var previous := state
	state = value
	state_changed.emit(previous, state)


func play_clip(clip: String, blend := 0.14) -> void:
	if selected_clip == clip and player.is_playing():
		return
	selected_clip = clip
	player.play(clip, blend)


func horizontal_distance_to(value: Node3D) -> float:
	return Vector2(global_position.x - value.global_position.x, global_position.z - value.global_position.z).length()


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() <= 0.001:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-10.0 * delta))


func start_punch() -> void:
	set_state("PUNCH")
	attack_clock = 0.0
	attack_committed = false
	velocity.x = 0.0
	velocity.z = 0.0
	selected_clip = ""
	play_clip("Punch_Combo", 0.08)


func request_dodge_away(threat: Node3D) -> bool:
	if state in ["PUNCH", "DODGE", "DEFEATED"] or defensive_cooldown > 0.0 or not is_on_floor() or not is_instance_valid(threat):
		return false
	var away := global_position - threat.global_position
	away.y = 0.0
	if away.length_squared() <= 0.001:
		away = Vector3.FORWARD
	away = away.normalized()
	var lateral := Vector3(-away.z, 0.0, away.x) * dodge_side
	dodge_side *= -1.0
	dodge_direction = (away * 0.35 + lateral).normalized()
	dodge_clock = dodge_duration
	defensive_cooldown = dodge_duration + 1.5
	velocity = Vector3.ZERO
	set_state("DODGE")
	selected_clip = ""
	play_clip("Roll_Dodge", 0.05)
	player.speed_scale = player.get_animation("Roll_Dodge").length / dodge_duration
	dodge_started.emit(dodge_direction)
	return true


func process_dodge(delta: float) -> void:
	dodge_clock = maxf(0.0, dodge_clock - delta)
	velocity.x = dodge_direction.x * dodge_speed
	velocity.z = dodge_direction.z * dodge_speed
	face_direction(dodge_direction, delta)
	move_and_slide()
	if dodge_clock <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		player.speed_scale = 1.0
		selected_clip = ""
		set_state("IDLE")


func resolve_punch() -> void:
	attack_committed = true
	if not is_instance_valid(target):
		punch_attempted.emit(null, false, INF)
		return
	var distance := horizontal_distance_to(target)
	var connected := distance <= punch_range + 0.25
	if connected and target.has_method("apply_damage"):
		target.call("apply_damage", punch_damage)
	punch_attempted.emit(target, connected, distance)


func process_punch(delta: float) -> void:
	attack_clock += delta
	if is_instance_valid(target):
		var direction := target.global_position - global_position
		direction.y = 0.0
		face_direction(direction.normalized(), delta)
	if not attack_committed and attack_clock >= punch_contact_time:
		resolve_punch()
	if attack_clock >= player.get_animation("Punch_Combo").length:
		cooldown = 0.45
		set_state("IDLE")
		selected_clip = ""


func apply_damage(amount: float) -> void:
	if state == "DEFEATED" or amount <= 0.0:
		return
	if state == "DODGE":
		damage_avoided.emit(amount)
		return
	health = maxf(0.0, health - amount)
	damaged.emit(amount, health)
	if health <= 0.0:
		set_state("DEFEATED")
		velocity = Vector3.ZERO
		player.pause()
		defeated.emit()


func _physics_process(delta: float) -> void:
	if state == "DEFEATED":
		return
	cooldown = maxf(0.0, cooldown - delta)
	defensive_cooldown = maxf(0.0, defensive_cooldown - delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	if state == "DODGE":
		process_dodge(delta)
		return
	if state == "PUNCH":
		process_punch(delta)
		move_and_slide()
		return
	if not active or not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		set_state("IDLE")
		if not player.is_playing():
			play_clip("Walking")
			player.pause()
		move_and_slide()
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= punch_range and cooldown <= 0.0:
		start_punch()
		move_and_slide()
		return
	if distance > chase_range:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		set_state("IDLE")
		if player.is_playing():
			player.pause()
		move_and_slide()
		return
	var direction := offset.normalized()
	var speed := run_speed if distance > run_distance else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	face_direction(direction, delta)
	if speed == run_speed:
		set_state("RUN")
		play_clip("Running")
	else:
		set_state("WALK")
		play_clip("Walking")
	move_and_slide()


func _process(_delta: float) -> void:
	if not is_instance_valid(skeleton):
		return
	var pose := skeleton.get_bone_global_pose(hips).origin
	model.position.x = rest_hips.x - pose.x
	model.position.z = rest_hips.z - pose.z
