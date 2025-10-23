extends BulletBase
class_name HomingBullet

@export var turn_speed: float = 5.0
@export var detection_radius: float = 300.0

var target: Node2D = null

func update_bullet_physics(delta: float) -> void:
	find_target()
	
	if target and is_instance_valid(target):
		var target_dir = (target.global_position - global_position).normalized()
		direction = direction.lerp(target_dir, turn_speed * delta).normalized()
		velocity = direction * get_bullet_speed()
		rotation = direction.angle()

func find_target():
	if target and is_instance_valid(target):
		return
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_dist = detection_radius
	target = null
	
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			target = enemy
