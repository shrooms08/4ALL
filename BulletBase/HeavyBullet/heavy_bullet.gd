extends BulletBase
class_name HeavyBullet

# Penetration settings
@export var max_penetrations: int = 3
@export var damage_falloff_per_hit: float = 0.15  # 15% damage loss per penetration
@export var speed_multiplier: float = 0.6  # 60% of base speed

var penetration_count: int = 0
var original_damage: float = 0.0

func _init():
	max_ammo = 6  # Medium-low ammo for powerful bullets
	damage = 20.0  # High base damage
	knockback_force = 25.0  # Strong knockback

func on_bullet_ready() -> void:
	set_meta("display_name", "Heavy")
	
	# Store original damage for falloff calculation
	original_damage = damage
	
	# Visual distinction - make it larger and darker
	scale = Vector2(1.3, 1.3)
	modulate = Color(0.8, 0.8, 0.9)  # Slightly blue tint
	
	# Add trail effect if you have particles
	_setup_trail_effect()

func on_setup_complete() -> void:
	# Apply damage multiplier after setup
	damage *= 2.0
	knockback_force *= 2.0
	original_damage = damage

func get_bullet_speed() -> float:
	return SPEED * speed_multiplier

func get_max_distance() -> float:
	return MAX_DISTANCE * 1.5  # Travel 50% further

func on_hit_enemy(enemy: Node2D) -> void:
	penetration_count += 1
	
	# Apply damage falloff
	if damage_falloff_per_hit > 0:
		damage = original_damage * (1.0 - damage_falloff_per_hit * penetration_count)
	
	# Visual feedback for penetration
	_create_impact_effect()
	
	# Check if we can still penetrate
	if penetration_count >= max_penetrations:
		_on_penetration_exhausted()
		queue_free()
	else:
		# Continue through the enemy
		has_been_destroyed = false
		_show_penetration_feedback()

func on_hit_tile(tile: Node2D) -> void:
	# Check if it's a breakable tile
	if tile.has_method("break_tile_at"):
		# It's a breakable tilemap - destroy tile but stop bullet
		_create_impact_effect()
		queue_free()
	else:
		# Solid platform - stop immediately
		_create_impact_effect()
		queue_free()

func on_hit_obstacle(obstacle: Node2D) -> void:
	# Stop at solid obstacles
	_create_impact_effect()
	queue_free()

func on_max_distance_reached() -> void:
	# Fade out instead of instant disappear
	_fade_out()

# Visual Effects
func _setup_trail_effect() -> void:
	# Add a trail particle effect if available
	var trail = CPUParticles2D.new()
	add_child(trail)
	
	trail.emitting = true
	trail.amount = 8
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	
	# Trail appearance
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.0
	trail.color = Color(0.7, 0.7, 1.0, 0.6)
	
	# Trail physics
	trail.direction = Vector2.ZERO
	trail.spread = 0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 0
	trail.initial_velocity_max = 0

func _create_impact_effect() -> void:
	# Create small impact particles
	var impact = CPUParticles2D.new()
	get_parent().add_child(impact)
	impact.global_position = global_position
	
	impact.emitting = true
	impact.one_shot = true
	impact.amount = 12
	impact.lifetime = 0.4
	impact.explosiveness = 0.8
	
	# Impact appearance
	impact.scale_amount_min = 0.5
	impact.scale_amount_max = 1.5
	impact.color = Color(0.9, 0.9, 1.0)
	
	# Impact physics
	impact.direction = Vector2(cos(rotation), sin(rotation))
	impact.spread = 45
	impact.gravity = Vector2(0, 200)
	impact.initial_velocity_min = 50
	impact.initial_velocity_max = 150
	
	# Auto cleanup
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(impact):
		impact.queue_free()

func _show_penetration_feedback() -> void:
	# Flash briefly when penetrating
	var original_modulate = modulate
	modulate = Color(1.5, 1.5, 1.5)
	
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(self):
		modulate = original_modulate

func _on_penetration_exhausted() -> void:
	# Final impact when penetration runs out
	_create_large_impact_effect()

func _create_large_impact_effect() -> void:
	# Larger effect when bullet is exhausted
	var impact = CPUParticles2D.new()
	get_parent().add_child(impact)
	impact.global_position = global_position
	
	impact.emitting = true
	impact.one_shot = true
	impact.amount = 20
	impact.lifetime = 0.6
	impact.explosiveness = 1.0
	
	impact.scale_amount_min = 1.0
	impact.scale_amount_max = 2.0
	impact.color = Color(0.8, 0.8, 1.0)
	
	impact.direction = Vector2.ZERO
	impact.spread = 180
	impact.gravity = Vector2(0, 300)
	impact.initial_velocity_min = 100
	impact.initial_velocity_max = 250
	
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(impact):
		impact.queue_free()

func _fade_out() -> void:
	# Smooth fade out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	if is_instance_valid(self):
		queue_free()

# Debug helper
func get_debug_info() -> String:
	return "Penetrations: %d/%d | Damage: %.1f" % [penetration_count, max_penetrations, damage]
