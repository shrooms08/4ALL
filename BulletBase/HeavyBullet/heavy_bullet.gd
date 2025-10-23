extends BulletBase
class_name HeavyBullet

func get_bullet_speed() -> float:
	return SPEED * 0.6

func on_setup_complete() -> void:
	damage *= 2.0
	knockback_force *= 2.0
