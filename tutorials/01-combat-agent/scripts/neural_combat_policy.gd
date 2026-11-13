extends Node

signal decision(actor: String, action: String, context: Dictionary)

var vita: CharacterBody3D
var enemy: CharacterBody3D
var weights: Dictionary
var fire_clock := 0.0
var enemy_aim_clock := 0.0
var strafe_side := 1.0
var enabled := false


func apply_artifact(artifact: Dictionary) -> void:
	assert(artifact.get("schema", "") == "yg3.game_ai.combat_mlp.v1")
	weights = artifact.weights


func setup(vita_: CharacterBody3D, enemy_: CharacterBody3D) -> void:
	assert(not weights.is_empty(), "Neural combat weights were not loaded")
	vita = vita_
	enemy = enemy_
	vita.equipped = true
	enabled = true


func sigmoid(value: float) -> float:
	return 1.0 / (1.0 + exp(-clampf(value, -30.0, 30.0)))


func infer(features: Array) -> Array:
	var hidden: Array = []
	for h in range(weights.b1.size()):
		var value: float = float(weights.b1[h])
		for i in range(features.size()):
			value += float(weights.w1[h][i]) * float(features[i])
		hidden.append(tanh(value))
	var output: Array = []
	for o in range(weights.b2.size()):
		var value: float = float(weights.b2[o])
		for h in range(hidden.size()):
			value += float(weights.w2[o][h]) * float(hidden[h])
		output.append(value)
	return output


func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(vita) or not is_instance_valid(enemy):
		return
	if vita.health <= 0.0 or enemy.health <= 0.0:
		vita.set_combat_command(Vector3.ZERO, enemy, false)
		return
	var offset := enemy.global_position - vita.global_position
	offset.y = 0.0
	var distance := offset.length()
	var toward := offset.normalized() if distance > 0.001 else Vector3.FORWARD
	var lateral := Vector3(-toward.z, 0.0, toward.x) * strafe_side
	fire_clock += delta
	if enemy.state == "PUNCH":
		enemy_aim_clock = 0.0
	elif vita.weapon_actions.drawn and vita.action.is_empty() and vita.hit_reaction_left <= 0.0:
		enemy_aim_clock += delta
	else:
		enemy_aim_clock = 0.0
	var features := [
		clampf(distance / 9.0, 0.0, 1.0),
		clampf(enemy.attack_clock / 1.5, 0.0, 1.0),
		clampf(vita.dodge_cooldown / 2.0, 0.0, 1.0),
		clampf(fire_clock / 1.2, 0.0, 1.0),
		clampf(enemy_aim_clock, 0.0, 1.0),
		float(enemy.state == "PUNCH"),
		float(enemy.state == "DODGE"),
		vita.health / vita.max_health,
		enemy.health / enemy.max_health,
	]
	var output := infer(features)
	var movement: int = 0
	for index in range(1, 3):
		if float(output[index]) > float(output[movement]):
			movement = index
	var move := lateral * 0.35
	if movement == 0:
		move = (-toward * 0.8 + lateral * 0.6).normalized()
	elif movement == 2:
		move = (toward * 0.75 + lateral * 0.35).normalized()
	var fire_now := sigmoid(float(output[3])) >= 0.5
	if fire_now:
		fire_clock = 0.0
		decision.emit("vita", "fire", {"distance_m": distance, "confidence": sigmoid(float(output[3]))})
	var dodge := Vector3.ZERO
	if sigmoid(float(output[4])) >= 0.5 and vita.dodge_cooldown <= 0.0:
		dodge = (-toward + lateral * 0.8).normalized()
		strafe_side *= -1.0
		decision.emit("vita", "dodge", {"distance_m": distance, "confidence": sigmoid(float(output[4]))})
	vita.set_combat_command(move, enemy, fire_now, dodge)
	if enemy_aim_clock >= 0.28 and enemy.request_dodge_away(vita):
		enemy_aim_clock = 0.0
		decision.emit("enemy", "dodge", {"distance_m": distance})
