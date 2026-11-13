extends Node3D

@onready var vita: CharacterBody3D=$Vita
@onready var enemy: CharacterBody3D=$Enemy
var status: Label
var reticle: Label
var vita_hp_label: Label
var enemy_hp_label: Label
var vita_hp_fill: ColorRect
var enemy_hp_fill: ColorRect
var state_rail: ColorRect
const HUD_BAR_WIDTH := 236.0

func _ready() -> void:
	make_hud()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var spawn: Vector3 = $PlayerSpawn.global_position
	var ray := PhysicsRayQueryParameters3D.create(Vector3(spawn.x,80,spawn.z),Vector3(spawn.x,-20,spawn.z),1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():spawn.y=hit.position.y+.025
	else:spawn.y=1
	vita.respawn(spawn)
	place_enemy()
	print("YG3 GAME AI TUTORIAL: Vita ready in the desert; spawn=",spawn)
	var arguments := OS.get_cmdline_user_args()
	if "--eval" in arguments:
		await load("res://scripts/evaluate.gd").new().run(self)
	elif "--neural-combat" in arguments and FileAccess.file_exists("res://weights/combat_mlp.json"):
		start_neural_combat()
	elif "--scripted-combat" in arguments:
		start_autonomous_combat()

func start_autonomous_combat() -> void:
	enemy.reset_combat(vita.global_position+Vector3(0,0,-4.5),vita,100.0)
	var policy: Node=load("res://scripts/autonomous_combat_policy.gd").new()
	policy.name="AutonomousCombatPolicy"
	add_child(policy)
	policy.setup(vita,enemy)
	enemy.active=true


func start_neural_combat() -> void:
	enemy.reset_combat(vita.global_position+Vector3(0,0,-4.5),vita,100.0)
	var policy: Node=load("res://scripts/neural_combat_policy.gd").new()
	policy.name="NeuralCombatPolicy"
	add_child(policy)
	var artifact: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://weights/combat_mlp.json"))
	policy.apply_artifact(artifact)
	policy.setup(vita,enemy)
	enemy.active=true

func place_enemy() -> void:
	var point: Vector3=enemy.global_position
	var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x,80,point.z),Vector3(point.x,-20,point.z),1)
	ray.exclude=[enemy.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty(),"No ground under enemy")
	enemy.global_position.y=hit.position.y+.025
	enemy.set_target(vita)

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var font: Font=load("res://assets/fonts/ZenAntique-Regular.ttf")
	var header := Control.new()
	header.position=Vector2.ZERO
	header.size=Vector2(540,92)
	header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(header)
	var title_back := ColorRect.new()
	title_back.position=Vector2.ZERO
	title_back.size=Vector2(540,92)
	title_back.color=Color("d9171512")
	title_back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	header.add_child(title_back)
	state_rail=ColorRect.new()
	state_rail.position=Vector2(20,18)
	state_rail.size=Vector2(7,56)
	state_rail.color=Color("e83b2f")
	state_rail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	header.add_child(state_rail)
	status=Label.new()
	status.position=Vector2(43,18)
	status.size=Vector2(560,62)
	status.scale=Vector2(.82,1)
	status.add_theme_font_override("font",font)
	status.add_theme_font_size_override("font_size",20)
	status.add_theme_color_override("font_color",Color("ffb000"))
	status.add_theme_constant_override("line_spacing",2)
	header.add_child(status)
	var pre_alpha := Label.new()
	pre_alpha.name="BuildState"
	pre_alpha.text="PRE-ALPHA"
	pre_alpha.position=Vector2(1100,22)
	pre_alpha.size=Vector2(154,34)
	pre_alpha.scale=Vector2(.82,1)
	pre_alpha.add_theme_font_override("font",font)
	pre_alpha.add_theme_font_size_override("font_size",22)
	pre_alpha.add_theme_color_override("font_color",Color("e83b2f"))
	layer.add_child(pre_alpha)
	var combat_readout := Control.new()
	combat_readout.position=Vector2(1284,22)
	combat_readout.size=Vector2(286,132)
	combat_readout.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(combat_readout)
	var readout_back := ColorRect.new()
	readout_back.position=Vector2.ZERO
	readout_back.size=Vector2(286,132)
	readout_back.color=Color("c9171512")
	readout_back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	combat_readout.add_child(readout_back)
	vita_hp_label=Label.new()
	vita_hp_label.position=Vector2(20,12)
	vita_hp_label.add_theme_font_override("font",font)
	vita_hp_label.size=Vector2(252,28)
	vita_hp_label.scale=Vector2(.86,1)
	vita_hp_label.add_theme_font_size_override("font_size",21)
	vita_hp_label.add_theme_color_override("font_color",Color("f1ebdd"))
	combat_readout.add_child(vita_hp_label)
	var vita_bar_back := ColorRect.new()
	vita_bar_back.position=Vector2(20,46)
	vita_bar_back.size=Vector2(HUD_BAR_WIDTH,8)
	vita_bar_back.color=Color("5c5550")
	combat_readout.add_child(vita_bar_back)
	vita_hp_fill=ColorRect.new()
	vita_hp_fill.position=vita_bar_back.position
	vita_hp_fill.size=vita_bar_back.size
	vita_hp_fill.color=Color("f1ebdd")
	combat_readout.add_child(vita_hp_fill)
	enemy_hp_label=Label.new()
	enemy_hp_label.position=Vector2(20,66)
	enemy_hp_label.add_theme_font_override("font",font)
	enemy_hp_label.add_theme_font_size_override("font_size",21)
	enemy_hp_label.add_theme_color_override("font_color",Color("e83b2f"))
	combat_readout.add_child(enemy_hp_label)
	var enemy_bar_back := ColorRect.new()
	enemy_bar_back.position=Vector2(20,100)
	enemy_bar_back.size=Vector2(HUD_BAR_WIDTH,8)
	enemy_bar_back.color=Color("5c5550")
	combat_readout.add_child(enemy_bar_back)
	enemy_hp_fill=ColorRect.new()
	enemy_hp_fill.position=enemy_bar_back.position
	enemy_hp_fill.size=enemy_bar_back.size
	enemy_hp_fill.color=Color("e83b2f")
	combat_readout.add_child(enemy_hp_fill)
	var command_strip := Control.new()
	command_strip.position=Vector2(0,846)
	command_strip.size=Vector2(1600,54)
	command_strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(command_strip)
	var help_back := ColorRect.new()
	help_back.position=Vector2.ZERO
	help_back.size=Vector2(1600,54)
	help_back.color=Color("d9171512")
	command_strip.add_child(help_back)
	var help := Label.new()
	help.text="MOVE  W A S D     EVADE  C / Q     RIFLE  F / LMB     VIEW  RMB     RESET  R"
	help.position=Vector2(30,8)
	help.scale=Vector2(.84,1)
	help.add_theme_font_override("font",font)
	help.add_theme_font_size_override("font_size",22)
	help.add_theme_color_override("font_color",Color("f1ebdd"))
	command_strip.add_child(help)
	var credit := Label.new()
	credit.name="DevelopmentCredit"
	credit.text="GAME IN DEVELOPMENT BY OTR HVN."
	credit.position=Vector2(1020,8)
	credit.size=Vector2(550,36)
	credit.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	credit.scale=Vector2(.84,1)
	credit.add_theme_font_override("font",font)
	credit.add_theme_font_size_override("font_size",22)
	credit.add_theme_color_override("font_color",Color("ffb000"))
	command_strip.add_child(credit)
	reticle=Label.new()
	reticle.text="+"
	reticle.add_theme_font_override("font",font)
	reticle.add_theme_font_size_override("font_size",28)
	reticle.modulate=Color("ffb000")
	reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reticle.visible=false
	layer.add_child(reticle)

func _process(_delta: float) -> void:
	if is_instance_valid(status):
		status.text="VITA  /  "+vita.animation_state+"  /  "+str(snappedf(Vector2(vita.velocity.x,vita.velocity.z).length(),.1))+" M/S\nHOSTILE  /  "+enemy.state
		state_rail.color=Color("e83b2f") if vita.animation_state=="HIT" or vita.health<=30 else Color("ffb000")
	if is_instance_valid(vita_hp_label):
		vita_hp_label.text="VITA / "+str(int(vita.health))+" HP     RIFLE / ∞"
		vita_hp_fill.size.x=HUD_BAR_WIDTH*clampf(vita.health/vita.max_health,0,1)
		vita_hp_fill.color=Color("e83b2f") if vita.health<=30 else Color("f1ebdd")
	if is_instance_valid(enemy_hp_label):
		enemy_hp_label.text="HOSTILE / "+str(int(enemy.health))
		enemy_hp_fill.size.x=HUD_BAR_WIDTH*clampf(enemy.health/enemy.max_health,0,1)
	if is_instance_valid(reticle) and is_instance_valid(vita.weapon_actions):
		var point: Vector3=vita.weapon_actions.aim_point
		reticle.visible=vita.weapon_actions.drawn and vita.action.is_empty() and not vita.camera.is_position_behind(point)
		if reticle.visible:reticle.position=vita.camera.unproject_position(point)-Vector2(8,18)
