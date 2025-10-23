extends BulletBase
class_name ExplosiveBullet

@export var explosion_radius: float = 100.0
@export var explosion_damage: float = 15.0

func on_hit_enemy(enemy: Node2D) -> void:
	create_explosion()
	queue_free()

func on_hit_tile(tile: Node2D) -> void:
	create_explosion()
	queue_free()

func on_hit_obstacle(obstacle: Node2D) -> void:
	create_explosion()
	queue_free()

func create_explosion():
	var bodies = get_tree().get_nodes_in_group("enemies")
	for body in bodies:
		if body.has_method("take_damage"):
			var dist = global_position.distance_to(body.global_position)
			if dist <= explosion_radius:
				var explosion_dir = (body.global_position - global_position).normalized()
				body.take_damage(explosion_damage, explosion_dir, knockback_force * 1.5)
