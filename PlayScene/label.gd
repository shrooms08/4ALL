extends Label

# Add this as a CanvasLayer > Label node in your scene
# Set it to top-left corner

var update_timer: float = 0.0

func _process(delta):
	update_timer += delta
	if update_timer < 0.5:  # Update twice per second
		return
	update_timer = 0.0
	
	# Gather performance data
	var fps = Engine.get_frames_per_second()
	var total_nodes = get_tree().get_node_count()
	var enemies = get_tree().get_nodes_in_group("enemies")
	var chunks = get_tree().get_nodes_in_group("chunks")
	
	# Count active (processing) enemies
	var active_enemies = 0
	var frozen_enemies = 0
	var dead_enemies = 0
	for enemy in enemies:
		if enemy.has_method("is_alive"):
			if not enemy.is_alive():
				dead_enemies += 1
			elif enemy.is_physics_processing():
				active_enemies += 1
			else:
				frozen_enemies += 1
	
	# Count other common culprits
	var particles = get_tree().get_nodes_in_group("particles")
	var projectiles = get_tree().get_nodes_in_group("projectiles")
	var gems = get_tree().get_nodes_in_group("gems")
	var timers = _count_nodes_of_type("Timer")
	var tweens = _count_nodes_of_type("Tween")
	var area2ds = _count_nodes_of_type("Area2D")
	var collision_shapes = _count_nodes_of_type("CollisionShape2D")
	
	# Memory info
	var static_memory = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	var physics_2d_active = Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	
	# Build debug text
	text = "=== PERFORMANCE DEBUG ===\n"
	text += "FPS: %d %s\n" % [fps, _get_fps_color(fps)]
	text += "Frame Time: %.1f ms\n" % (delta * 1000.0)
	text += "\n--- CRITICAL COUNTS ---\n"
	text += "Total Nodes: %d %s\n" % [total_nodes, _flag_if_high(total_nodes, 2000)]
	text += "Active Enemies: %d %s\n" % [active_enemies, _flag_if_high(active_enemies, 30)]
	text += "Frozen Enemies: %d\n" % frozen_enemies
	text += "Dead Enemies: %d %s\n" % [dead_enemies, _flag_if_high(dead_enemies, 5)]
	text += "Chunks: %d %s\n" % [chunks.size(), _flag_if_high(chunks.size(), 15)]
	text += "\n--- POTENTIAL CULPRITS ---\n"
	text += "Gems: %d %s\n" % [gems.size(), _flag_if_high(gems.size(), 100)]
	text += "Projectiles: %d %s\n" % [projectiles.size(), _flag_if_high(projectiles.size(), 50)]
	text += "Particles: %d %s\n" % [particles.size(), _flag_if_high(particles.size(), 20)]
	text += "Area2Ds: %d %s\n" % [area2ds, _flag_if_high(area2ds, 100)]
	text += "CollisionShapes: %d %s\n" % [collision_shapes, _flag_if_high(collision_shapes, 150)]
	text += "Timers: %d %s\n" % [timers, _flag_if_high(timers, 50)]
	text += "Tweens: %d %s\n" % [tweens, _flag_if_high(tweens, 20)]
	text += "\n--- PHYSICS ---\n"
	text += "Active Physics Bodies: %d\n" % physics_2d_active
	text += "Memory: %.1f MB\n" % static_memory
	
	# Color code by performance
	if fps < 30:
		modulate = Color.RED
	elif fps < 50:
		modulate = Color.YELLOW
	else:
		modulate = Color.GREEN

func _count_nodes_of_type(type_name: String) -> int:
	var count = 0
	var all_nodes = get_tree().root.get_children()
	while all_nodes.size() > 0:
		var node = all_nodes.pop_back()
		if node.get_class() == type_name:
			count += 1
		all_nodes.append_array(node.get_children())
	return count

func _flag_if_high(value: int, threshold: int) -> String:
	if value > threshold:
		return "⚠️ HIGH!"
	elif value > threshold * 0.7:
		return "⚠"
	return "✓"

func _get_fps_color(fps: int) -> String:
	if fps < 30:
		return "🔴 CRITICAL"
	elif fps < 50:
		return "🟡 LOW"
	return "🟢 GOOD"
