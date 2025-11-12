extends Node2D

# Chunk scenes
@export var start_chunk_scene: PackedScene
@export var chunk_scenes: Array[PackedScene]
@export var special_chunk_scenes: Array[PackedScene]
@export var powerup_chunk_scene: PackedScene

# Spawning settings
@export_group("Chunk Spawning")
@export var initial_chunks: int = 8
@export var chunk_spacing: float = 600.0
@export var despawn_distance: float = 2400.0
@export var spawn_ahead_distance: float = 1200.0

# Special chunks
@export_group("Special Chunks")
@export var special_chance: float = 0.2
@export var special_cooldown_chunks: int = 8

# Powerup system
@export_group("Powerup Chunks")
@export var powerup_spawn_interval: int = 25  # INCREASED from 10 to 25 - spawn every 25 chunks
@export var min_chunks_before_first_powerup: int = 15  # NEW - minimum chunks before first powerup appears
@export var powerup_spawn_mode: SpawnMode = SpawnMode.INTERVAL
@export var sync_with_game_manager: bool = true  # Sync with depth milestones

enum SpawnMode {
	INTERVAL,       # Every X chunks
	DEPTH_BASED,    # Based on GameManager depth milestones
	RANDOM          # Random with weighted chance
}

# Internals
var chunks: Array[Node2D] = []
var last_exit_y: float = 0.0
var chunks_since_special: int = 0
var chunks_since_powerup: int = 0
var total_chunks_spawned: int = 0
var powerup_chunks_spawned: int = 0


func _ready() -> void:
	print("🌍 LevelGenerator initializing...")
	
	# Validate setup
	if not _validate_scene_setup():
		push_error("LevelGenerator: Missing required scenes!")
		return
	
	# Connect to GameManager if available
	_connect_game_manager()
	
	# Start generation
	spawn_start_chunk()
	spawn_initial_chunks()
	
	print("LevelGenerator ready! Generated", chunks.size(), "initial chunks")


func _validate_scene_setup() -> bool:
	"""Ensure all required scenes are assigned"""
	var valid = true
	
	if not start_chunk_scene:
		push_warning("⚠️ No start_chunk_scene assigned!")
		valid = false
	
	if chunk_scenes.is_empty():
		push_warning("⚠️ No chunk_scenes assigned!")
		valid = false
	
	if not powerup_chunk_scene:
		push_warning("⚠️ No powerup_chunk_scene assigned!")
	
	return valid


func _connect_game_manager() -> void:
	"""Connect to GameManager signals for depth-based spawning"""
	if not sync_with_game_manager or not GameManager:
		return
	
	if GameManager.has_signal("powerup_available"):
		if not GameManager.is_connected("powerup_available", _on_powerup_milestone_reached):
			GameManager.powerup_available.connect(_on_powerup_milestone_reached)
			print("🔗 Connected to GameManager powerup milestones")


# === Initial Setup ===

func spawn_start_chunk() -> void:
	"""Spawn the initial starting chunk"""
	if not start_chunk_scene:
		push_error("Cannot spawn start chunk - scene not assigned!")
		return
	
	var start_chunk = start_chunk_scene.instantiate()
	add_child(start_chunk)
	start_chunk.position = Vector2.ZERO
	
	# Find exit marker
	var exit_marker = start_chunk.get_node_or_null("Exit")
	if exit_marker:
		last_exit_y = start_chunk.position.y + exit_marker.position.y
	else:
		# Fallback if no exit marker
		last_exit_y = chunk_spacing
		push_warning("Start chunk missing Exit marker!")
	
	chunks.append(start_chunk)
	_spawn_chunk_enemies(start_chunk)
	total_chunks_spawned += 1
	
	print("🏁 Start chunk spawned at Y:", start_chunk.position.y)


func spawn_initial_chunks() -> void:
	"""Generate the initial set of chunks"""
	var current_y = last_exit_y
	
	for i in range(initial_chunks):
		var chunk = _get_next_chunk_scene().instantiate()
		add_child(chunk)
		
		# Align entrance to previous exit
		var entrance = chunk.get_node_or_null("Entrance")
		if entrance:
			chunk.position.y = current_y - entrance.position.y
		else:
			chunk.position.y = current_y
			push_warning("Chunk missing Entrance marker:", chunk.name)
		
		# Update exit position
		var exit_marker = chunk.get_node_or_null("Exit")
		if exit_marker:
			last_exit_y = chunk.position.y + exit_marker.position.y
		else:
			last_exit_y = chunk.position.y + chunk_spacing
		
		chunks.append(chunk)
		current_y = last_exit_y
		total_chunks_spawned += 1
		
		# Setup chunk
		_setup_chunk(chunk)


# === Runtime Chunk Management ===

func spawn_next_chunk() -> void:
	"""Spawn the next chunk in the sequence"""
	var chunk_scene = _get_next_chunk_scene()
	if not chunk_scene:
		push_error("Failed to get next chunk scene!")
		return
	
	var new_chunk = chunk_scene.instantiate()
	add_child(new_chunk)
	
	# Position chunk
	var entrance = new_chunk.get_node_or_null("Entrance")
	if entrance:
		new_chunk.position.y = last_exit_y - entrance.position.y
	else:
		new_chunk.position.y = last_exit_y
	
	# Update exit position
	var exit_marker = new_chunk.get_node_or_null("Exit")
	if exit_marker:
		last_exit_y = new_chunk.position.y + exit_marker.position.y
	else:
		last_exit_y = new_chunk.position.y + chunk_spacing
	
	chunks.append(new_chunk)
	total_chunks_spawned += 1
	
	# Setup chunk
	_setup_chunk(new_chunk)


func _setup_chunk(chunk: Node2D) -> void:
	"""Initialize a newly spawned chunk"""
	# Spawn enemies
	_spawn_chunk_enemies(chunk)
	
	# Connect powerup portal if this is a powerup chunk
	if chunk.is_in_group("powerup_chunk"):
		_connect_powerup_chunk(chunk)
		powerup_chunks_spawned += 1
		print("⚡ PowerupChunk spawned! (#", powerup_chunks_spawned, ") at total chunk:", total_chunks_spawned)


func _connect_powerup_chunk(chunk: Node2D) -> void:
	"""Connect signals from powerup chunk"""
	if not chunk.has_signal("portal_entered"):
		push_warning("PowerupChunk missing portal_entered signal!")
		return
	
	# Connect with parameter binding
	if not chunk.is_connected("portal_entered", _on_powerup_portal_entered):
		chunk.portal_entered.connect(_on_powerup_portal_entered)
		print("🔗 Connected PowerupChunk portal")


func _spawn_chunk_enemies(chunk: Node2D) -> void:
	"""Spawn enemies in a chunk via its EnemySpawner"""
	var spawner = chunk.get_node_or_null("EnemySpawner")
	if spawner and spawner.has_method("spawn_enemies"):
		spawner.call_deferred("spawn_enemies")


func _cleanup_chunk_enemies(chunk: Node2D) -> void:
	"""Clean up enemies in a despawning chunk"""
	var spawner = chunk.get_node_or_null("EnemySpawner")
	if spawner and spawner.has_method("cleanup_enemies"):
		spawner.cleanup_enemies()
	
	print("🧹 Cleaned up chunk:", chunk.name)


# === Chunk Selection Logic ===

func _get_next_chunk_scene() -> PackedScene:
	"""Determine which chunk type to spawn next"""
	chunks_since_powerup += 1
	
	# Check if we should spawn a powerup chunk
	if _should_spawn_powerup_chunk():
		chunks_since_powerup = 0
		return powerup_chunk_scene
	
	# Check for special chunk
	if can_spawn_special():
		return _get_random_special_chunk()
	
	# Default to normal chunk
	return _get_random_normal_chunk()


func _should_spawn_powerup_chunk() -> bool:
	"""Determine if the next chunk should be a powerup chunk"""
	if not powerup_chunk_scene:
		return false
	
	# NEW: Enforce minimum chunks before first powerup
	if total_chunks_spawned < min_chunks_before_first_powerup:
		return false
	
	match powerup_spawn_mode:
		SpawnMode.INTERVAL:
			return chunks_since_powerup >= powerup_spawn_interval
		
		SpawnMode.DEPTH_BASED:
			# Only spawn if GameManager says so
			return false  # Handled via signal
		
		SpawnMode.RANDOM:
			var chance = 0.05  # REDUCED from 0.1 to 0.05 - now 5% chance
			var min_spacing = 8  # INCREASED from 3 to 8 - minimum chunks between powerups
			return randf() < chance and chunks_since_powerup >= min_spacing
		
		_:
			return false


func can_spawn_special() -> bool:
	"""Check if a special chunk can spawn"""
	if special_chunk_scenes.is_empty():
		return false
	
	if chunks_since_special >= special_cooldown_chunks and randf() < special_chance:
		chunks_since_special = 0
		return true
	else:
		chunks_since_special += 1
		return false


func _get_random_normal_chunk() -> PackedScene:
	"""Get a random normal chunk"""
	if chunk_scenes.is_empty():
		push_error("No normal chunk scenes available!")
		return null
	return chunk_scenes.pick_random()


func _get_random_special_chunk() -> PackedScene:
	"""Get a random special chunk"""
	if special_chunk_scenes.is_empty():
		return _get_random_normal_chunk()
	return special_chunk_scenes.pick_random()


# === Runtime Updates ===

func _process(_delta: float) -> void:
	handle_chunk_spawning()
	cleanup_old_chunks()


func handle_chunk_spawning() -> void:
	"""Spawn new chunks when player gets close to the end"""
	if chunks.is_empty():
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var last_chunk = chunks.back()
	if player.global_position.y > last_chunk.global_position.y - spawn_ahead_distance:
		spawn_next_chunk()


func cleanup_old_chunks() -> void:
	"""Remove chunks that are far behind the player"""
	if chunks.is_empty():
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var top_chunk = chunks[0]
	if player.global_position.y - top_chunk.global_position.y > despawn_distance:
		_cleanup_chunk_enemies(top_chunk)
		
		# Disconnect signals before freeing
		if top_chunk.is_in_group("powerup_chunk"):
			if top_chunk.is_connected("portal_entered", _on_powerup_portal_entered):
				top_chunk.portal_entered.disconnect(_on_powerup_portal_entered)
		
		top_chunk.queue_free()
		chunks.pop_front()


# === Event Handlers ===

func _on_powerup_portal_entered(chunk: Node2D) -> void:
	"""Handle player entering a powerup portal"""
	print("Powerup portal entered at chunk:", chunk.name if chunk else "unknown")
	
	# Trigger powerup selection via GameManager
	if GameManager:
		GameManager.trigger_powerup_selection()
	else:
		push_warning("⚠️ GameManager not found - cannot trigger powerup selection!")


func _on_powerup_milestone_reached() -> void:
	"""Handle GameManager powerup milestone signal"""
	print("🎯 Powerup milestone reached - will spawn PowerupChunk soon")
	# Force next chunk to be a powerup chunk
	chunks_since_powerup = powerup_spawn_interval


# === Public API ===

func force_spawn_powerup_chunk() -> void:
	"""Manually trigger a powerup chunk spawn"""
	chunks_since_powerup = powerup_spawn_interval
	print("⚡ Forced PowerupChunk spawn on next generation")


func get_total_chunks_spawned() -> int:
	"""Get total number of chunks spawned"""
	return total_chunks_spawned


func get_active_chunk_count() -> int:
	"""Get number of currently active chunks"""
	return chunks.size()


func get_powerup_chunks_spawned() -> int:
	"""Get number of powerup chunks spawned"""
	return powerup_chunks_spawned


func get_stats() -> Dictionary:
	"""Get level generation statistics"""
	return {
		"total_chunks": total_chunks_spawned,
		"active_chunks": chunks.size(),
		"powerup_chunks": powerup_chunks_spawned,
		"chunks_since_powerup": chunks_since_powerup,
		"last_exit_y": last_exit_y
	}


# === Debug ===

func print_stats() -> void:
	"""Print current level generation stats"""
	print("""
	=== LEVEL GENERATOR STATS ===
	Total Chunks Spawned: %d
	Active Chunks: %d
	Powerup Chunks: %d
	Chunks Since Powerup: %d
	Last Exit Y: %.1f
	=============================
	""" % [
		total_chunks_spawned,
		chunks.size(),
		powerup_chunks_spawned,
		chunks_since_powerup,
		last_exit_y
	])
