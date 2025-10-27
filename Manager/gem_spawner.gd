extends Node

const GEM_SCENE := preload("res://Gem/gem.tscn")
const  MAX_GEMS: int = 100

# Default settings (can be overridden per spawn)
var default_drop_chance: float = 1.0
var default_min_gems: int = 1
var default_max_gems: int = 3
var default_spawn_force_min: float = 150.0
var default_spawn_force_max: float = 250.0
var default_small_gem_chance: float = 0.7
var default_exp_per_bonus_gem: int = 20
var default_max_bonus_gems: int = 3

# Gem container for organization
var gem_container: Node = null


func _ready() -> void:
	# Try to find or create gem container
	call_deferred("_setup_gem_container")


func _setup_gem_container() -> void:
	var scene_root = get_tree().current_scene
	if scene_root:
		# Look for existing container
		gem_container = scene_root.get_node_or_null("Gems")
		
		# Create if doesn't exist
		if not gem_container:
			gem_container = Node2D.new()
			gem_container.name = "Gems"
			scene_root.add_child(gem_container)


# Main spawn function - call this from enemy die()
func spawn_gems_from_enemy(
	enemy: BaseEnemy,
	drop_chance: float = -1.0,
	min_gems: int = -1,
	max_gems: int = -1,
	force_min: float = -1.0,
	force_max: float = -1.0
) -> void:
	var current_gems = get_tree().get_nodes_in_group("gems").size()
	if current_gems > MAX_GEMS:
		return
	
	
	if not enemy:
		return
	
	# Use defaults if not specified
	var actual_drop_chance = drop_chance if drop_chance >= 0 else default_drop_chance
	var actual_min = min_gems if min_gems >= 0 else default_min_gems
	var actual_max = max_gems if max_gems >= 0 else default_max_gems
	var actual_force_min = force_min if force_min >= 0 else default_spawn_force_min
	var actual_force_max = force_max if force_max >= 0 else default_spawn_force_max
	
	# Check drop chance
	if randf() > actual_drop_chance:
		return
	
	# Calculate gem count with scaling
	var base_count = randi_range(actual_min, actual_max)
	var scale = 0
	
	if "exp_value" in enemy:
		scale = clamp(int(enemy.exp_value / default_exp_per_bonus_gem), 0, default_max_bonus_gems)
	
	var gem_count = base_count + scale
	var spawn_pos = enemy.global_position
	
	# Spawn gems with stagger
	_spawn_gems_staggered(spawn_pos, gem_count, actual_force_min, actual_force_max)


# Spawn with staggered timing for visual effect
func _spawn_gems_staggered(
	pos: Vector2,
	count: int,
	force_min: float,
	force_max: float
) -> void:
	for i in range(count):
		_spawn_gem(pos, force_min, force_max)
		
		# Stagger spawns
		if i < count - 1:
			await get_tree().create_timer(0.05).timeout


# Core gem spawning logic
func _spawn_gem(
	pos: Vector2,
	force_min: float,
	force_max: float,
	gem_type: Gem.GemType = Gem.GemType.SMALL,
	force_type: bool = false
) -> void:
	if not GEM_SCENE:
		return
	
	# Ensure container exists
	if not gem_container or not gem_container.is_inside_tree():
		gem_container = get_tree().current_scene
	
	if not gem_container:
		return
	
	var gem = GEM_SCENE.instantiate() as Gem
	gem_container.add_child(gem)
	
	# Add slight random offset
	var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
	gem.global_position = pos + offset
	
	# Set gem type
	if force_type:
		gem.gem_type = gem_type
	else:
		gem.gem_type = _get_random_gem_type()
	
	# Apply burst effect
	if gem.has_method("spawn_with_force"):
		var random_direction = Vector2(
			randf_range(-1, 1),
			randf_range(-1.5, -0.5)  # Bias upward
		).normalized()
		var force = randf_range(force_min, force_max)
		gem.spawn_with_force(random_direction, force)


func _get_random_gem_type() -> Gem.GemType:
	return Gem.GemType.SMALL if randf() < default_small_gem_chance else Gem.GemType.LARGE


# Manual spawn - for specific positions (bosses, destructibles, etc.)
func spawn_gems_at_position(
	position: Vector2,
	count: int = 3,
	force_min: float = -1.0,
	force_max: float = -1.0,
	gem_type: Gem.GemType = Gem.GemType.SMALL,
	force_specific_type: bool = false
) -> void:
	var actual_force_min = force_min if force_min >= 0 else default_spawn_force_min
	var actual_force_max = force_max if force_max >= 0 else default_spawn_force_max
	
	for i in range(count):
		_spawn_gem(position, actual_force_min, actual_force_max, gem_type, force_specific_type)
		
		if i < count - 1:
			await get_tree().create_timer(0.05).timeout


# Gem burst pattern (circular) - good for bosses
func spawn_gem_burst(
	position: Vector2,
	count: int = 20,
	force_min: float = -1.0,
	force_max: float = -1.0
) -> void:
	var actual_force_min = force_min if force_min >= 0 else default_spawn_force_min
	var actual_force_max = force_max if force_max >= 0 else default_spawn_force_max
	
	if not gem_container or not gem_container.is_inside_tree():
		gem_container = get_tree().current_scene
	
	for i in range(count):
		var gem = GEM_SCENE.instantiate() as Gem
		gem_container.add_child(gem)
		gem.global_position = position
		gem.gem_type = _get_random_gem_type()
		
		# Circular burst pattern
		var angle = (TAU / count) * i
		var direction = Vector2(cos(angle), sin(angle))
		var force = randf_range(actual_force_min, actual_force_max * 1.5)
		
		if gem.has_method("spawn_with_force"):
			gem.spawn_with_force(direction, force)
