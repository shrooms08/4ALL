extends Node2D
class_name AudienceEnemySpawner

# Enemy pool that audience can spawn
@export var audience_enemy_scenes: Dictionary = {
	"slimeskull": preload("res://Enemies/Crawling Enemies/SlimeSkull/slime_skull.tscn"),
	"flameshkull": preload("res://Enemies/Flyin' Enemies/FlameSkull/flame_skull.tscn")
}

# Max audience enemies allowed on screen
@export var max_audience_enemies: int = 8

# Cooldown time between spawns (in seconds)
@export var spawn_cooldown: float = 3.0
var can_spawn: bool = true

# Spawn distance settings
@export var min_spawn_distance: float = 100.0  # Minimum distance from player
@export var max_spawn_distance: float = 300.0  # Maximum distance from player
@export var max_spawn_attempts: int = 20  # How many times to try finding a valid spot

# TileMap reference for collision checking
@export var tilemap: TileMap = null
@export var tilemap_layer: int = 0  # Which layer to check

# Use physics raycast for more reliable collision detection
@export var use_raycast_check: bool = true
@export var check_radius: float = 16.0  # Check area around spawn point

# Optional: set to false if you want the audience spawns disabled temporarily
var spawns_enabled: bool = true

# Reference to player
var player: Node2D = null


func _ready():
	# Try to find the player automatically
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	# Try to find tilemap automatically if not set
	if not tilemap:
		tilemap = get_tree().get_first_node_in_group("tilemap")
		if not tilemap:
			# Try finding any TileMap in the scene
			tilemap = get_tree().current_scene.find_child("*", true, false) as TileMap
	
	if tilemap:
		print("TileMap found: ", tilemap.name)
	else:
		print("Warning: No TileMap found for spawn validation")


func spawn_audience_enemy(enemy_name: String, spawn_position: Vector2 = Vector2.ZERO):
	# Stop if audience spawns are disabled
	if not spawns_enabled:
		print("Audience spawns are currently disabled.")
		return

	# Check cooldown
	if not can_spawn:
		print("Spawn on cooldown. Please wait.")
		return

	# Validate enemy type
	if not audience_enemy_scenes.has(enemy_name):
		print("Invalid enemy type:", enemy_name)
		return

	# Check limit
	var current_count = get_tree().get_nodes_in_group("audience_enemies").size()
	if current_count >= max_audience_enemies:
		print("Too many audience enemies active:", current_count)
		return

	# If no position given, find one around the player
	if spawn_position == Vector2.ZERO:
		spawn_position = _find_valid_spawn_position()
		if spawn_position == Vector2.ZERO:
			print("Could not find valid spawn position after all attempts")
			return

	# Spawn enemy
	var enemy_scene = audience_enemy_scenes[enemy_name]
	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_position
	enemy.add_to_group("audience_enemies")

	# Optional: spawn animation
	if enemy.has_method("play_spawn_animation"):
		enemy.play_spawn_animation()

	print("Audience spawned:", enemy_name, "at", spawn_position)

	# Start cooldown
	_start_cooldown()


func spawn_random_audience_enemy(spawn_position: Vector2 = Vector2.ZERO):
	if audience_enemy_scenes.size() == 0:
		return
	var enemy_name = audience_enemy_scenes.keys().pick_random()
	spawn_audience_enemy(enemy_name, spawn_position)


func _find_valid_spawn_position() -> Vector2:
	if not player:
		print("No player found for spawning around")
		return Vector2.ZERO
	
	var player_pos = player.global_position
	
	# Try multiple times to find a valid position
	for i in range(max_spawn_attempts):
		# Generate random angle (only lower half - below and sides of player)
		# Range from PI/4 to 3*PI/4 and from 5*PI/4 to 7*PI/4 (excludes top half)
		var angle = randf_range(PI * 0.25, PI * 1.75)  # Bottom half circle
		var distance = randf_range(min_spawn_distance, max_spawn_distance)
		
		# Calculate potential spawn position
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var potential_pos = player_pos + offset
		
		# Additional check: ensure spawn is below or at same level as player
		if potential_pos.y < player_pos.y:
			print("Attempt ", i + 1, " failed - spawn would be above player")
			continue
		
		# Check if position is valid
		if _is_position_valid(potential_pos):
			print("Found valid spawn position at attempt ", i + 1)
			return potential_pos
		else:
			print("Attempt ", i + 1, " failed - position has collision")
	
	# If no valid position found after all attempts
	return Vector2.ZERO


func _is_position_valid(pos: Vector2) -> bool:
	# Method 1: Check using physics raycast (more reliable)
	if use_raycast_check:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = pos
		query.collision_mask = 1  # Adjust collision layer as needed
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_point(query, 1)
		if result.size() > 0:
			print("Physics collision detected at ", pos)
			return false
	
	# Method 2: Check tilemap
	if tilemap:
		# Check the center point
		var tile_pos = tilemap.local_to_map(tilemap.to_local(pos))
		var tile_data = tilemap.get_cell_tile_data(tilemap_layer, tile_pos)
		
		if tile_data != null:
			print("Tile detected at ", tile_pos, " (world: ", pos, ")")
			return false
		
		# Also check surrounding tiles for safety
		var offsets = [
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(0, -1), Vector2i(0, 1)
		]
		
		for offset in offsets:
			var check_pos = tile_pos + offset
			var check_data = tilemap.get_cell_tile_data(tilemap_layer, check_pos)
			if check_data != null:
				# Check if we're too close to this tile
				var tile_world_pos = tilemap.to_global(tilemap.map_to_local(check_pos))
				if pos.distance_to(tile_world_pos) < check_radius:
					print("Too close to tile at ", check_pos)
					return false
	
	return true


func _start_cooldown():
	can_spawn = false
	await get_tree().create_timer(spawn_cooldown).timeout
	can_spawn = true


# Helper function to set player reference manually if needed
func set_player(p_player: Node2D):
	player = p_player


# Helper function to set tilemap reference manually if needed
func set_tilemap(p_tilemap: TileMap):
	tilemap = p_tilemap


# Debug function to visualize spawn attempts
func debug_spawn_area():
	if not player:
		return
	
	print("=== Debug Spawn Area ===")
	print("Player position: ", player.global_position)
	print("Min distance: ", min_spawn_distance)
	print("Max distance: ", max_spawn_distance)
	print("TileMap: ", tilemap)
	
	# Test a few positions
	for i in range(5):
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, max_spawn_distance)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var test_pos = player.global_position + offset
		var valid = _is_position_valid(test_pos)
		print("Test ", i, ": ", test_pos, " - Valid: ", valid)
