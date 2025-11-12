extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var level_generator: Node2D = $LevelGenerator
@onready var game_title: Label = $CanvasLayer/GameTitle
@onready var audience_spawner: AudienceEnemySpawner = $AudienceEnemySpawner
@onready var music_player: AudioStreamPlayer = $MusicPlayer

@export var game_musics: Array[AudioStream] = []

static var has_shown_title: bool = false
var selected_music: AudioStream = null

func _ready():
	# Give browser time to render the first frame
	await get_tree().process_frame
	
	# Preload music early
	if not game_musics.is_empty():
		selected_music = game_musics.pick_random()
		music_player.stream = selected_music
	
	# Small delay to let everything initialize
	await get_tree().process_frame
	
	var start_chunk = level_generator.get_node_or_null("StartChunk")
	if start_chunk:
		start_chunk.player_left_start.connect(_on_player_left_start)

func _on_player_left_start():
	player.set_physics_process(false)
	
	if not has_shown_title:
		has_shown_title = true
		_show_title_with_overlay()
	else:
		player.set_physics_process(true)
		_play_music()

func _show_title_with_overlay():
	var overlay = $CanvasLayer/BlackOverlay
	var title = $CanvasLayer/GameTitle
	
	overlay.visible = true
	title.visible = true
	overlay.modulate.a = 0.0
	title.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	tween.tween_property(title, "modulate:a", 1.0, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.5)
	tween.tween_property(title, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	
	overlay.visible = false
	title.visible = false
	
	player.set_physics_process(true)
	_play_music()

func _play_music():
	if music_player.stream:
		music_player.play()
