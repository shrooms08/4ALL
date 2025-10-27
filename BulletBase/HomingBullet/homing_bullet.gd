extends BulletBase
class_name HomingBullet

@export var turn_speed: float = 5.0
@export var detection_radius: float = 200.0

var target_enemy: Node2D = null

func _init():
	max_ammo = 6  # Low ammo for homing capability
	damage = 12.0
	knockback_force = 10.0

func on_bullet_ready() -> void:
	set_meta("display_name", "Homing")
	_find_nearest_enemy()

func update_bullet_physics(delta: float) -> void:
	# Update target if lost
	if not is_instance_valid(target_enemy):
		_find_nearest_enemy()
	
	# Home towards target
	if target_enemy:
		var target_direction = (target_enemy.global_position - global_position).normalized()
		direction = direction.lerp(target_direction, turn_speed * delta).normalized()
		velocity = direction * get_bullet_speed()
		rotation = direction.angle()

func _find_nearest_enemy() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_distance = detection_radius
	target_enemy = null
	
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			target_enemy = enemy
