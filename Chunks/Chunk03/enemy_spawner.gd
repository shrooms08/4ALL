extends Node2D

@export var enemy_scenes: Array[PackedScene]
@export var spawn_chance: float = 0.6  # 🔥 High chance for endless fall
@export var max_enemies_per_chunk: int = 15  # 🔥 More enemies
@export var respawn_on_reuse: bool = true

var spawned_enemies: Array[WeakRef] = []

func spawn_enemies():
	"""Spawn or respawn enemies in this chunk"""
	
	# ✅ Clean up any remaining enemies from previous use
	cleanup_enemies()
	
	if not enemy_scenes or enemy_scenes.is_empty():
		push_warning("No enemy scenes assigned to spawner in: ", get_parent().name)
		return
	
	var spawn_points = $SpawnPoints.get_children()
	
	if spawn_points.is_empty():
		push_warning("No spawn points found in: ", get_parent().name)
		return
	
	var spawned_count = 0
	
	for point in spawn_points:
		if spawned_count >= max_enemies_per_chunk:
			break
		
		if randf() < spawn_chance:
			var enemy_scene = enemy_scenes.pick_random()
			var enemy = enemy_scene.instantiate()
			enemy.global_position = point.global_position
			
			# ✅ Add to scene tree (deferred to avoid issues)
			get_tree().current_scene.call_deferred("add_child", enemy)
			
			# Store weak reference
			spawned_enemies.append(weakref(enemy))
			spawned_count += 1
	
	print("✅ SPAWNED ", spawned_count, " enemies in chunk: ", get_parent().name, " at Y: ", global_position.y)

func cleanup_enemies():
	"""Remove all spawned enemies from this chunk"""
	var cleaned = 0
	
	for weak_ref in spawned_enemies:
		var enemy = weak_ref.get_ref()
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()
			cleaned += 1
	
	spawned_enemies.clear()
	
	if cleaned > 0:
		print("Cleaned up ", cleaned, " enemies from chunk: ", get_parent().name)

func _exit_tree():
	"""Cleanup when chunk is freed"""
	cleanup_enemies()
