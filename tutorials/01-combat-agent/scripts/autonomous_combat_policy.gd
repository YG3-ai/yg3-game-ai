extends Node

signal decision(actor: String, action: String, context: Dictionary)

@export var vita_fire_interval := 0.55
@export var vita_dodge_trigger := 0.18
@export var enemy_aim_tolerance := 0.28
@export var preferred_distance := 2.2

var vita: CharacterBody3D
var enemy: CharacterBody3D
var fire_clock := 0.0
var enemy_aim_clock := 0.0
var strafe_side := 1.0
var enabled := false


func setup(vita_: CharacterBody3D, enemy_: CharacterBody3D) -> void:
	vita = vita_
	enemy = enemy_
	enabled = true
	vita.equipped = true


func apply_parameters(parameters: Dictionary) -> void:
	vita_fire_interval = float(parameters.get("vita_fire_interval", vita_fire_interval))
	vita_dodge_trigger = float(parameters.get("vita_dodge_trigger", vita_dodge_trigger))
	enemy_aim_tolerance = float(parameters.get("enemy_aim_tolerance", enemy_aim_tolerance))
	preferred_distance = float(parameters.get("preferred_distance", preferred_distance))


func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(vita) or not is_instance_valid(enemy):
		return
	if vita.health <= 0.0 or enemy.health <= 0.0:
		vita.set_combat_command(Vector3.ZERO, enemy, false)
		return
	var to_enemy := enemy.global_position - vita.global_position
	to_enemy.y = 0.0
	var distance := to_enemy.length()
	var toward := to_enemy.normalized() if distance > 0.001 else Vector3.FORWARD
	var lateral := Vector3(-toward.z, 0.0, toward.x) * strafe_side
	var move := lateral * 0.35
	if distance < preferred_distance - 0.6:
		move = (-toward * 0.8 + lateral * 0.6).normalized()
	elif distance > preferred_distance + 1.0:
		move = (toward * 0.75 + lateral * 0.35).normalized()
	var dodge := Vector3.ZERO
	if enemy.state == "PUNCH" and enemy.attack_clock >= vita_dodge_trigger and distance <= enemy.punch_range + 0.65 and vita.dodge_cooldown <= 0.0:
		dodge = (-toward + lateral * 0.8).normalized()
		strafe_side *= -1.0
		decision.emit("vita", "dodge", {"distance_m": distance, "enemy_attack_time": enemy.attack_clock})
	fire_clock += delta
	var fire_now := fire_clock >= vita_fire_interval
	if fire_now:
		fire_clock = 0.0
		decision.emit("vita", "fire", {"distance_m": distance})
	vita.set_combat_command(move, enemy, fire_now, dodge)
	if vita.weapon_actions.drawn and vita.action.is_empty() and vita.hit_reaction_left <= 0.0:
		enemy_aim_clock += delta
	else:
		enemy_aim_clock = 0.0
	if enemy_aim_clock >= enemy_aim_tolerance and enemy.request_dodge_away(vita):
		enemy_aim_clock = 0.0
		decision.emit("enemy", "dodge", {"distance_m": distance})
