extends Node2D

@export var enemy_scenes: Array[PackedScene] = []
@export var spawn_count: int = 10
@export var spawn_radius: float = 500.0  # Spawn within this radius
@export var min_distance_from_player: float = 150.0  # Don't spawn too close
@export_group("Advanced")
@export var use_custom_spawn_area: bool = false
@export var custom_spawn_area: Rect2 = Rect2(Vector2.ZERO, Vector2(1000, 1000))

var player: Node2D = null

func _ready():
	randomize()
	
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_warning("EnemySpawner: No player found, using spawner position as center")
	
	spawn_enemies()

func spawn_enemies():
	print("=== SPAWNER DEBUG ===")
	print("Spawn count: ", spawn_count)
	print("Enemy scenes available: ", enemy_scenes.size())
	
	if enemy_scenes.is_empty():
		push_error("EnemySpawner: No enemy scenes assigned!")
		return
	
	var spawn_center = player.global_position if player else global_position
	print("Spawn center: ", spawn_center)
	
	for i in range(spawn_count):
		var scene = enemy_scenes.pick_random()
		
		if not scene:
			push_error("EnemySpawner: Null scene in array")
			continue
		
		var enemy = scene.instantiate()
		var spawn_pos = get_valid_spawn_position(spawn_center)
		
		enemy.global_position = spawn_pos
		print("Spawned ", enemy.name, " at ", spawn_pos)
		get_parent().add_child(enemy)
	
	print("=== SPAWN COMPLETE ===")

func get_valid_spawn_position(center: Vector2) -> Vector2:
	var max_attempts = 10
	
	for attempt in range(max_attempts):
		var pos: Vector2
		
		if use_custom_spawn_area:
			# Use custom rect
			pos = Vector2(
				randf_range(custom_spawn_area.position.x, custom_spawn_area.position.x + custom_spawn_area.size.x),
				randf_range(custom_spawn_area.position.y, custom_spawn_area.position.y + custom_spawn_area.size.y)
			)
		else:
			# Spawn in circle around center
			var angle = randf() * TAU
			var distance = randf_range(min_distance_from_player, spawn_radius)
			pos = center + Vector2(cos(angle), sin(angle)) * distance
		
		# Check if far enough from player
		if not player or pos.distance_to(player.global_position) >= min_distance_from_player:
			return pos
	
	# Fallback: just return something
	return center + Vector2(spawn_radius, 0)
