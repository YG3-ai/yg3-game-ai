extends RefCounted

const EPISODE_SECONDS := 6.0
const DISTANCES := [3.6, 5.2, 7.0]

var level: Node3D
var vita: CharacterBody3D
var enemy: CharacterBody3D
var metrics: Dictionary
var results: Array = []


func bind_metrics() -> void:
	vita.weapon_actions.fired.connect(func(_a, _b, _c): metrics.shots += 1)
	vita.dodge_started.connect(func(_a, _b): metrics.vita_dodges += 1)
	enemy.dodge_started.connect(func(_a): metrics.enemy_dodges += 1)
	enemy.punch_attempted.connect(func(_a, connected: bool, _b): metrics.punches += 1; metrics.punch_hits += int(connected))


func reset_episode(distance: float) -> void:
	vita.clear_combat_command()
	vita.respawn(vita.spawn_position)
	enemy.reset_combat(vita.global_position + Vector3(0, 0, -distance), vita, 100.0)
	metrics = {"shots": 0, "vita_dodges": 0, "enemy_dodges": 0, "punches": 0, "punch_hits": 0}


func run_episode(kind: String, distance: float) -> void:
	reset_episode(distance)
	var policy: Node
	if kind == "neural_mlp":
		policy = load("res://scripts/neural_combat_policy.gd").new()
		policy.apply_artifact(JSON.parse_string(FileAccess.get_file_as_string("res://weights/combat_mlp.json")))
	else:
		policy = load("res://scripts/autonomous_combat_policy.gd").new()
	level.add_child(policy)
	policy.setup(vita, enemy)
	enemy.active = true
	await level.get_tree().create_timer(EPISODE_SECONDS).timeout
	policy.enabled = false
	enemy.active = false
	vita.clear_combat_command()
	var damage_dealt: float = enemy.max_health - enemy.health
	var damage_taken: float = vita.max_health - vita.health
	var score: float = damage_dealt - 1.5 * damage_taken + 4.0 * float(metrics.punches - metrics.punch_hits) + 2.0 * float(metrics.vita_dodges)
	results.append({"policy": kind, "start_distance_m": distance, "score": score, "damage_dealt": damage_dealt, "damage_taken": damage_taken, "metrics": metrics.duplicate(true)})
	print("EVAL ", kind, " distance=", distance, " score=", score)
	policy.queue_free()
	await level.get_tree().process_frame


func run(scene: Node3D) -> void:
	level = scene
	vita = level.get_node("Vita")
	enemy = level.get_node("Enemy")
	if not FileAccess.file_exists("res://weights/combat_mlp.json"):
		push_error("Run python3 train.py before --eval")
		level.get_tree().quit(2)
		return
	bind_metrics()
	for distance in DISTANCES:
		await run_episode("scripted_baseline", distance)
		await run_episode("neural_mlp", distance)
	var summary := {}
	for kind in ["scripted_baseline", "neural_mlp"]:
		var matching := results.filter(func(item): return item.policy == kind)
		summary[kind] = {"mean_score": matching.reduce(func(total, item): return total + item.score, 0.0) / matching.size(), "mean_damage_dealt": matching.reduce(func(total, item): return total + item.damage_dealt, 0.0) / matching.size(), "mean_damage_taken": matching.reduce(func(total, item): return total + item.damage_taken, 0.0) / matching.size()}
	print("YG3_GAME_AI_EVAL ", JSON.stringify({"schema": "yg3.game_ai.combat_eval.v1", "episodes": results, "summary": summary}))
	level.get_tree().quit()
