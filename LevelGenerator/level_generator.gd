extends Node2D

@export var start_chunk_scene: PackedScene
@export var chunk_scenes: Array[PackedScene]            # Normal chunks
@export var special_chunk_scenes: Array[PackedScene]    # Special chunks
@export var initial_chunks: int = 8
@export var chunk_spacing: float = 600.0                # Distance between chunks
@export var special_chance: float = 0.2                 # 20% chance for special
@export var special_cooldown_chunks: int = 8           # Minimum normal chunks before another special
@export var despawn_distance: float = 2400.0

var chunks: Array[Node2D] = []
var last_exit_y: float = 0.0
var chunks_since_special: int = 0


func _ready():
	spawn_start_chunk()
	spawn_initial_chunks()


func spawn_start_chunk():
	if not start_chunk_scene:
		push_warning("No start chunk scene assigned!")
		return

	var start_chunk = start_chunk_scene.instantiate()
	add_child(start_chunk)
	start_chunk.position = Vector2.ZERO  # Start at the top of the level

	var exit_marker = start_chunk.get_node_or_null("Exit")
	if exit_marker:
		last_exit_y = start_chunk.position.y + exit_marker.position.y

	chunks.append(start_chunk)
	


func spawn_initial_chunks():
	var current_y = last_exit_y  # <-- start after the start chunk exit
	for i in range(initial_chunks):
		var is_special = can_spawn_special()
		var chunk_scene = special_chunk_scenes.pick_random() if is_special else chunk_scenes.pick_random()
		var chunk = chunk_scene.instantiate()
		add_child(chunk)

		# Align the entrance of the new chunk to current_y
		var entrance = chunk.get_node_or_null("Entrance")
		if entrance:
			chunk.position.y = current_y - entrance.position.y
		else:
			chunk.position.y = current_y

		# Update last_exit_y
		var exit_marker = chunk.get_node_or_null("Exit")
		if exit_marker:
			last_exit_y = chunk.position.y + exit_marker.position.y

		chunks.append(chunk)
		current_y = last_exit_y  # next chunk will start after this one



func spawn_next_chunk():
	var is_special = can_spawn_special()
	var chunk_scene = special_chunk_scenes.pick_random() if is_special else chunk_scenes.pick_random()
	var new_chunk = chunk_scene.instantiate()
	add_child(new_chunk)

	# Align entrance with previous exit
	var entrance = new_chunk.get_node_or_null("Entrance")
	if entrance:
		var offset = last_exit_y - entrance.position.y
		new_chunk.position.y = offset

	var exit_marker = new_chunk.get_node_or_null("Exit")
	if exit_marker:
		last_exit_y = new_chunk.position.y + exit_marker.position.y

	chunks.append(new_chunk)


func can_spawn_special() -> bool:
	# Only allow special if cooldown is complete and chance succeeds
	if chunks_since_special >= special_cooldown_chunks and randf() < special_chance:
		chunks_since_special = 0
		return true
	else:
		chunks_since_special += 1
		return false


func _process(_delta):
	cleanup_old_chunks()


func cleanup_old_chunks():
	if chunks.is_empty():
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
		
	var top_chunk = chunks[0]
	if player.global_position.y - top_chunk.global_position.y > despawn_distance:
		top_chunk.queue_free()
		chunks.pop_front()
		spawn_next_chunk()
