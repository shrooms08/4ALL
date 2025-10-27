extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var level_generator: Node2D = $LevelGenerator
@onready var game_title: Label = $CanvasLayer/GameTitle
@onready var audience_spawner: AudienceEnemySpawner = $AudienceEnemySpawner


func _ready():
	var start_chunk = level_generator.get_node_or_null("StartChunk") # or store a reference when spawned
	if start_chunk:
		start_chunk.player_left_start.connect(_on_player_left_start)


func _process(_delta):
	if Input.is_action_just_pressed("spawn_audience_enemy"):
		var spawn_pos = player.global_position + Vector2(randf_range(-200, 200), -100)
		audience_spawner.spawn_random_audience_enemy(spawn_pos)


func _on_player_left_start():
	# Freeze player
	player.set_physics_process(false)

	_show_title_with_overlay()

func _show_title_with_overlay():
	var overlay = $CanvasLayer/BlackOverlay
	var title = $CanvasLayer/GameTitle

	overlay.visible = true
	title.visible = true

	overlay.modulate.a = 0.0
	title.modulate.a = 0.0

	var tween = create_tween()
	# Fade in both
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	tween.tween_property(title, "modulate:a", 1.0, 0.5)

	# Hold for a few seconds
	tween.tween_interval(2.0)

	# Fade out both
	tween.tween_property(overlay, "modulate:a", 0.0, 0.5)
	tween.tween_property(title, "modulate:a", 0.0, 0.5)

	# After finished, hide and unfreeze player
	await tween.finished
	overlay.visible = false
	title.visible = false
	player.set_physics_process(true)
