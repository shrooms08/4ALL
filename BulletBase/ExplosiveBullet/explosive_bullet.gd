extends BulletBase
class_name ExplosiveBullet

@export var explosion_radius: float = 100.0
@export var explosion_scene: PackedScene

func _init():
	# Set bullet-specific properties
	max_ammo = 4  # Low ammo for powerful bullets
	damage = 25.0
	knockback_force = 15.0

func on_bullet_ready() -> void:
	# Set display name for UI
	set_meta("display_name", "Explosive")

func on_hit_enemy(enemy: Node2D) -> void:
	_create_explosion()
	queue_free()

func on_hit_tile(tile: Node2D) -> void:
	_create_explosion()
	queue_free()

func on_hit_obstacle(obstacle: Node2D) -> void:
	_create_explosion()
	queue_free()

func _create_explosion() -> void:
	# Create explosion effect and damage nearby enemies
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
	
	# Damage all enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= explosion_radius:
				var explosion_damage = damage * (1.0 - distance / explosion_radius)
				var knockback_dir = (enemy.global_position - global_position).normalized()
				enemy.take_damage(explosion_damage, knockback_dir, knockback_force * 2)
